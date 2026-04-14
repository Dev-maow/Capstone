"""YOLOv8-seg ONNX inference (Ultralytics export) for tooth ROI masks.

Expects export from Ultralytics segment models, e.g.:
  output0: (1, 4 + nc + nm, anchors)  — boxes xywh, class logits, mask coeffs
  output1: (1, 32, mh, mw)            — mask prototypes

Class ids must match training: 0 = upper_teeth, 1 = lower_teeth.
"""

from __future__ import annotations

import logging
from typing import Any

import cv2
import numpy as np

logger = logging.getLogger(__name__)

try:
    import onnxruntime as ort
except ImportError:
    ort = None

IMGSZ = 640
CONF_THRES = 0.25
IOU_THRES = 0.45
MAX_DET = 24
NC = 2
NM = 32


def _sigmoid(x: np.ndarray) -> np.ndarray:
    x = np.clip(x, -80.0, 80.0)
    return 1.0 / (1.0 + np.exp(-x))


def _letterbox(
    img: np.ndarray, new_shape: tuple[int, int] = (IMGSZ, IMGSZ)
) -> tuple[np.ndarray, dict[str, Any]]:
    shape = img.shape[:2]
    r = min(new_shape[0] / shape[0], new_shape[1] / shape[1])
    new_unpad_w = int(round(shape[1] * r))
    new_unpad_h = int(round(shape[0] * r))
    dw, dh = new_shape[1] - new_unpad_w, new_shape[0] - new_unpad_h
    dw, dh = dw / 2.0, dh / 2.0
    if (shape[1], shape[0]) != (new_unpad_w, new_unpad_h):
        img = cv2.resize(img, (new_unpad_w, new_unpad_h), interpolation=cv2.INTER_LINEAR)
    top, bottom = int(round(dh - 0.1)), int(round(dh + 0.1))
    left, right = int(round(dw - 0.1)), int(round(dw + 0.1))
    img = cv2.copyMakeBorder(img, top, bottom, left, right, cv2.BORDER_CONSTANT, value=(114, 114, 114))
    meta = {
        "orig_h": shape[0],
        "orig_w": shape[1],
        "top": top,
        "left": left,
        "unpad_h": new_unpad_h,
        "unpad_w": new_unpad_w,
    }
    return img, meta


def _xywh2xyxy(x: np.ndarray) -> np.ndarray:
    y = np.empty_like(x, dtype=np.float32)
    xy = x[..., :2]
    wh = x[..., 2:] / 2.0
    y[..., :2] = xy - wh
    y[..., 2:] = xy + wh
    return y


def _nms(xyxy: np.ndarray, scores: np.ndarray, iou_thres: float, max_det: int) -> np.ndarray:
    if len(xyxy) == 0:
        return np.array([], dtype=np.int64)
    x1, y1, x2, y2 = xyxy.T.astype(np.float32)
    areas = np.clip(x2 - x1, 0, None) * np.clip(y2 - y1, 0, None)
    order = scores.argsort()[::-1]
    keep: list[int] = []
    while order.size > 0 and len(keep) < max_det:
        i = int(order[0])
        keep.append(i)
        if order.size == 1:
            break
        rest = order[1:]
        xx1 = np.maximum(x1[i], x1[rest])
        yy1 = np.maximum(y1[i], y1[rest])
        xx2 = np.minimum(x2[i], x2[rest])
        yy2 = np.minimum(y2[i], y2[rest])
        inter = np.clip(xx2 - xx1, 0, None) * np.clip(yy2 - yy1, 0, None)
        union = areas[i] + areas[rest] - inter + 1e-6
        iou = inter / union
        inds = np.where(iou <= iou_thres)[0]
        order = rest[inds]
    return np.array(keep, dtype=np.int64)


def _crop_mask(masks: np.ndarray, boxes: np.ndarray, ratios: tuple[float, float, float, float]) -> np.ndarray:
    n, h, w = masks.shape
    rw, rh, _, _ = ratios
    out = masks.copy()
    boxes_s = boxes * np.array([rw, rh, rw, rh], dtype=np.float32)
    boxes_s = np.clip(np.round(boxes_s), 0, None).astype(np.int32)
    for i in range(n):
        x1, y1, x2, y2 = boxes_s[i]
        x1, y1 = max(0, x1), max(0, y1)
        x2, y2 = min(w, x2), min(h, y2)
        out[i, :y1] = 0
        out[i, y2:] = 0
        out[i, :, :x1] = 0
        out[i, :, x2:] = 0
    return out


def _process_masks(
    protos: np.ndarray,
    mask_coef: np.ndarray,
    boxes_xyxy: np.ndarray,
    shape_hw: tuple[int, int],
) -> np.ndarray:
    """Return (N, H, W) bool masks at letterbox resolution."""
    c, mh, mw = protos.shape
    protos_flat = protos.reshape(c, -1).astype(np.float32)
    logits = (mask_coef @ protos_flat).reshape(-1, mh, mw)
    width_ratio = mw / shape_hw[1]
    height_ratio = mh / shape_hw[0]
    ratios = (width_ratio, height_ratio, width_ratio, height_ratio)
    logits = _crop_mask(logits, boxes_xyxy.astype(np.float32), ratios)
    n = logits.shape[0]
    ups = np.zeros((n, shape_hw[0], shape_hw[1]), dtype=np.float32)
    for i in range(n):
        ups[i] = cv2.resize(logits[i], (shape_hw[1], shape_hw[0]), interpolation=cv2.INTER_LINEAR)
    return ups > 0.0


def _warp_mask_to_roi(binary_lb: np.ndarray, meta: dict[str, Any]) -> np.ndarray:
    top, left = meta["top"], meta["left"]
    uh, uw = meta["unpad_h"], meta["unpad_w"]
    oh, ow = meta["orig_h"], meta["orig_w"]
    crop = binary_lb[top : top + uh, left : left + uw].astype(np.float32)
    return cv2.resize(crop, (ow, oh), interpolation=cv2.INTER_LINEAR)


def _split_pred_proto(outs: list[np.ndarray]) -> tuple[np.ndarray, np.ndarray] | None:
    """Pick prediction (C, N) and proto (32, H, W) from ONNX outputs."""
    pred = None
    proto = None
    expect_c = 4 + NC + NM
    for t in outs:
        a = np.asarray(t, dtype=np.float32)
        if a.ndim == 4 and a.shape[1] == 32:
            proto = a[0]
        elif a.ndim == 3:
            b0 = a[0]
            if b0.shape[0] == expect_c:
                pred = b0
            elif b0.shape[1] == expect_c:
                pred = b0.T
        elif a.ndim == 2:
            if a.shape[0] == expect_c:
                pred = a
            elif a.shape[1] == expect_c:
                pred = a.T
    if pred is None or proto is None:
        return None
    if pred.shape[0] != expect_c:
        return None
    return pred, proto


class YoloSegOnnx:
    def __init__(self, path: str) -> None:
        if ort is None:
            raise RuntimeError("onnxruntime is required for YOLO segmentation models")
        providers = ["CPUExecutionProvider"]
        try:
            if "CUDAExecutionProvider" in ort.get_available_providers():
                providers = ["CUDAExecutionProvider", "CPUExecutionProvider"]
        except Exception:
            pass
        self.session = ort.InferenceSession(path, providers=providers)
        self.input_name = self.session.get_inputs()[0].name

    def predict_roi_mask(self, roi_bgr: np.ndarray, jaw: str) -> np.ndarray | None:
        """Binary mask (uint8 0/255) for teeth in this ROI, or None on failure."""
        if roi_bgr.size == 0:
            return None
        h0, w0 = roi_bgr.shape[:2]
        if h0 < 8 or w0 < 8:
            return None

        lb, meta = _letterbox(roi_bgr)
        rgb = cv2.cvtColor(lb, cv2.COLOR_BGR2RGB)
        blob = rgb.astype(np.float32) / 255.0
        blob = np.transpose(blob, (2, 0, 1))[None, ...]

        try:
            outs = self.session.run(None, {self.input_name: blob})
        except Exception as e:
            logger.debug("ONNX run failed: %s", e)
            return None

        split = _split_pred_proto(list(outs))
        if split is None:
            logger.debug("Unexpected ONNX outputs: %s", [o.shape for o in outs])
            return None

        pred_cn, protos = split
        pred = pred_cn.T.astype(np.float32)

        boxes_xywh = pred[:, :4]
        cls_logits = pred[:, 4 : 4 + NC]
        mask_coef = pred[:, 4 + NC : 4 + NC + NM]

        cls_prob = _sigmoid(cls_logits)
        cls_idx = cls_prob.argmax(axis=1)
        conf = cls_prob.max(axis=1)

        want_cls = 0 if jaw == "upper" else 1
        valid = (conf > CONF_THRES) & (cls_idx == want_cls)
        boxes_xyxy = _xywh2xyxy(boxes_xywh[valid])
        conf = conf[valid]
        mask_coef = mask_coef[valid]

        if len(boxes_xyxy) == 0:
            return np.zeros((h0, w0), dtype=np.uint8)

        keep = _nms(boxes_xyxy, conf, IOU_THRES, MAX_DET)
        boxes_xyxy = boxes_xyxy[keep]
        mask_coef = mask_coef[keep]

        if len(boxes_xyxy) == 0:
            return np.zeros((h0, w0), dtype=np.uint8)

        shape_hw = (IMGSZ, IMGSZ)
        masks_lb = _process_masks(protos, mask_coef, boxes_xyxy, shape_hw)
        combined = masks_lb.any(axis=0)

        warped = _warp_mask_to_roi(combined, meta)
        return ((warped > 0.5).astype(np.uint8)) * 255
