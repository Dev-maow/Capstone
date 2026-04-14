from __future__ import annotations

import base64
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import cv2
import numpy as np

from schemas import ScanTeethRequest, ScanTeethResponse, ToothPoint, ToothPrediction


@dataclass(frozen=True)
class _Detection:
    jaw: str
    confidence: float
    polygon: list[tuple[float, float]]


class ToothDetector:
    """Backend tooth detector tuned for the Flutter AR flow.

    This version uses the mouth region already estimated by MediaPipe on-device,
    so the backend does not guess across the full face anymore. It is still a
    heuristic detector, but it is much better anchored to the actual mouth.

    When ``tooth_segmentation.onnx`` is a YOLOv8-seg export (Ultralytics), it is
    run via ONNX Runtime with full mask-prototype decoding. Otherwise the
    pipeline falls back to OpenCV heuristics only.
    """

    def __init__(self) -> None:
        self._yolo_onnx = self._load_yolo_seg_onnx()

    def scan(self, payload: ScanTeethRequest) -> ScanTeethResponse:
        image = self._decode_request_image(payload)
        detections = self._detect_from_image(image, payload)
        confidence = float(
            np.clip(
                np.mean([d.confidence for d in detections]) if detections else 0.0,
                0.0,
                1.0,
            )
        )

        teeth = [
            ToothPrediction(
                id=f"{det.jaw}_{index + 1}",
                jaw=det.jaw,
                confidence=round(det.confidence, 4),
                polygon=[ToothPoint(x=round(x, 6), y=round(y, 6)) for x, y in det.polygon],
            )
            for index, det in enumerate(detections)
        ]

        return ScanTeethResponse(
            imageWidth=image.shape[1],
            imageHeight=image.shape[0],
            confidence=round(confidence, 4),
            teeth=teeth,
        )

    def _load_yolo_seg_onnx(self):
        env_path = os.environ.get("TOOTH_SEGMENTATION_MODEL", "").strip()
        candidate = (
            Path(env_path)
            if env_path
            else Path(__file__).resolve().parent / "models" / "tooth_segmentation.onnx"
        )
        if not candidate.exists():
            return None
        try:
            from yolo_seg_onnx import YoloSegOnnx

            return YoloSegOnnx(str(candidate))
        except Exception:
            return None

    def _decode_request_image(self, payload: ScanTeethRequest) -> np.ndarray:
        if payload.encoding != "nv21":
            raise ValueError("Only NV21 payloads are supported")

        try:
            raw = base64.b64decode(payload.bytesBase64)
        except Exception as exc:
            raise ValueError("Invalid base64 image bytes") from exc

        width = payload.imageWidth
        height = payload.imageHeight
        expected = width * height * 3 // 2
        if len(raw) < expected:
            raise ValueError("NV21 payload is smaller than expected for frame size")

        yuv = np.frombuffer(raw[:expected], dtype=np.uint8).reshape((height * 3 // 2, width))
        bgr = cv2.cvtColor(yuv, cv2.COLOR_YUV2BGR_NV21)

        rotation = payload.rotation % 360
        if rotation == 90:
            bgr = cv2.rotate(bgr, cv2.ROTATE_90_CLOCKWISE)
        elif rotation == 180:
            bgr = cv2.rotate(bgr, cv2.ROTATE_180)
        elif rotation == 270:
            bgr = cv2.rotate(bgr, cv2.ROTATE_90_COUNTERCLOCKWISE)

        if payload.isFrontCamera:
            bgr = cv2.flip(bgr, 1)

        return bgr

    def _detect_from_image(self, image: np.ndarray, payload: ScanTeethRequest) -> list[_Detection]:
        h, w = image.shape[:2]
        detections: list[_Detection] = []

        for jaw, region in self._build_regions(payload, w, h).items():
            x0, y0, x1, y1 = region
            if x1 - x0 < 24 or y1 - y0 < 14:
                continue

            roi = image[y0:y1, x0:x1]
            if roi.size == 0:
                continue

            mask = self._build_tooth_mask(roi, jaw=jaw)
            components = self._extract_teeth_from_columns(mask, jaw=jaw)
            for component in components:
                polygon = [((x + x0) / w, (y + y0) / h) for x, y in component.polygon]
                detections.append(
                    _Detection(jaw=jaw, confidence=component.confidence, polygon=polygon)
                )

        detections = self._reject_implausible_detections(detections, payload)
        detections.sort(key=lambda d: (d.jaw, self._centroid_x(d.polygon)))
        return detections

    def _build_regions(self, payload: ScanTeethRequest, w: int, h: int) -> dict[str, tuple[int, int, int, int]]:
        if (
            payload.toothBboxX is None
            or payload.toothBboxY is None
            or payload.toothBboxW is None
            or payload.toothBboxH is None
        ):
            return {
                'upper': (int(w * 0.28), int(h * 0.40), int(w * 0.72), int(h * 0.54)),
                'lower': (int(w * 0.28), int(h * 0.52), int(w * 0.72), int(h * 0.68)),
            }

        mouth_left = min(
            [v for v in [payload.lipLeftX, payload.lipRightX, payload.toothBboxX] if v is not None]
        )
        mouth_right = max(
            [
                v
                for v in [
                    payload.lipLeftX,
                    payload.lipRightX,
                    payload.toothBboxX + payload.toothBboxW,
                ]
                if v is not None
            ]
        )
        upper_top = min(
            [v for v in [payload.upperLipTopY, payload.toothBboxY] if v is not None]
        )
        lower_bottom = max(
            [
                v
                for v in [
                    payload.lowerLipBottomY,
                    payload.toothBboxY + payload.toothBboxH,
                ]
                if v is not None
            ]
        )

        x0 = self._clamp_px((mouth_left - 0.08) * w, w)
        x1 = self._clamp_px((mouth_right + 0.08) * w, w)
        mid_y = payload.toothBboxY + payload.toothBboxH * 0.5

        upper = (
            x0,
            self._clamp_px((upper_top - 0.03) * h, h),
            x1,
            self._clamp_px((mid_y + payload.toothBboxH * 0.02) * h, h),
        )
        lower = (
            x0,
            self._clamp_px((mid_y - payload.toothBboxH * 0.02) * h, h),
            x1,
            self._clamp_px((lower_bottom + 0.03) * h, h),
        )
        return {'upper': upper, 'lower': lower}

    def _build_tooth_mask(self, roi: np.ndarray, jaw: str) -> np.ndarray:
        heuristic_mask = self._build_heuristic_tooth_mask(roi, jaw)
        if self._yolo_onnx is None:
            return heuristic_mask

        model_mask = self._build_model_tooth_mask(roi, jaw)
        if model_mask is None:
            return heuristic_mask

        # Use the trained segmentation mask as-is. The old heuristic AND often
        # ate real enamel pixels and shifted contours vs. what the ONNX model learned.
        if int(np.count_nonzero(model_mask)) > 0:
            return model_mask
        return heuristic_mask

    def _build_heuristic_tooth_mask(self, roi: np.ndarray, jaw: str) -> np.ndarray:
        hsv = cv2.cvtColor(roi, cv2.COLOR_BGR2HSV)
        lab = cv2.cvtColor(roi, cv2.COLOR_BGR2LAB)
        value = hsv[:, :, 2]
        saturation = hsv[:, :, 1]
        lightness = lab[:, :, 0]

        bright_thresh = int(np.percentile(lightness, 68 if jaw == 'upper' else 70))
        value_thresh = int(np.percentile(value, 62 if jaw == 'upper' else 64))
        sat_thresh = int(np.percentile(saturation, 55))
        mask = (
            (lightness >= max(125, bright_thresh))
            & (value >= max(105, value_thresh))
            & (saturation <= max(95, sat_thresh))
        ).astype(np.uint8) * 255

        kernel_open = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
        kernel_close = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5, 5))
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel_open)
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel_close)

        focus = np.zeros_like(mask)
        roi_h, roi_w = mask.shape
        cv2.rectangle(
            focus,
            (int(roi_w * 0.04), int(roi_h * 0.04)),
            (int(roi_w * 0.96), int(roi_h * 0.96)),
            255,
            thickness=-1,
        )
        mask = cv2.bitwise_and(mask, focus)
        return mask

    def _build_model_tooth_mask(self, roi: np.ndarray, jaw: str) -> np.ndarray | None:
        if self._yolo_onnx is None:
            return None
        try:
            mask = self._yolo_onnx.predict_roi_mask(roi, jaw)
        except Exception:
            return None
        if mask is None or mask.shape[:2] != roi.shape[:2]:
            return None
        kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (3, 3))
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
        return mask

    def _extract_teeth_from_columns(self, mask: np.ndarray, jaw: str) -> list[_Detection]:
        roi_h, roi_w = mask.shape
        column_scores = (mask > 0).sum(axis=0).astype(np.float32)
        if column_scores.size == 0 or float(np.max(column_scores)) <= 0:
            return []

        smooth = np.convolve(column_scores, np.ones(9, dtype=np.float32) / 9.0, mode='same')
        positive = smooth[smooth > 0]
        threshold = max(
            roi_h * 0.10,
            float(np.percentile(positive, 35)) if positive.size else 0.0,
        )
        active = self._fill_small_gaps(
            smooth >= threshold,
            max_gap=max(2, int(round(roi_w * 0.018))),
        )
        bands = self._find_active_bands(active)
        if not bands:
            return []

        detections: list[_Detection] = []
        max_band_width = max(10, int(roi_w * 0.12))
        min_band_width = max(6, int(roi_w * 0.045))
        for start, end in bands:
            for sub_start, sub_end in self._split_band_by_valleys(
                smooth,
                start,
                end,
                max_width=max_band_width,
                min_width=min_band_width,
            ):
                padded_start = max(0, sub_start - 2)
                padded_end = min(roi_w, sub_end + 2)
                band = mask[:, padded_start:padded_end]
                if band.size == 0:
                    continue

                contours, _ = cv2.findContours(band, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
                if not contours:
                    continue

                contour = max(contours, key=cv2.contourArea)
                contour_area = float(cv2.contourArea(contour))
                if contour_area < 20:
                    continue

                x, y, bw, bh = cv2.boundingRect(contour)
                if bw < roi_w * 0.03 or bh < roi_h * 0.16:
                    continue

                hull = cv2.convexHull(contour)
                polygon = [(float(pt[0][0] + padded_start), float(pt[0][1])) for pt in hull]
                if len(polygon) < 4:
                    polygon = [
                        (float(x + padded_start), float(y)),
                        (float(x + padded_start + bw), float(y)),
                        (float(x + padded_start + bw), float(y + bh)),
                        (float(x + padded_start), float(y + bh)),
                    ]

                fill_ratio = contour_area / max(float(bw * bh), 1.0)
                conf = float(np.clip(0.46 + fill_ratio * 0.40 + min(0.12, bw / max(roi_w, 1) * 0.35), 0.0, 0.96))
                detections.append(_Detection(jaw=jaw, confidence=conf, polygon=polygon))

        detections.sort(key=lambda d: self._centroid_x(d.polygon))
        return detections

    def _find_bands(self, scores: np.ndarray, threshold: float) -> list[tuple[int, int]]:
        bands: list[tuple[int, int]] = []
        start: int | None = None
        for index, value in enumerate(scores):
            if value >= threshold and start is None:
                start = index
            elif value < threshold and start is not None:
                if index - start >= 6:
                    bands.append((start, index))
                start = None
        if start is not None and len(scores) - start >= 6:
            bands.append((start, len(scores) - 1))
        return bands

    def _split_band(self, start: int, end: int, max_width: int) -> list[tuple[int, int]]:
        width = end - start
        if width <= max_width:
            return [(start, end)]
        pieces = max(2, int(round(width / max_width)))
        step = width / pieces
        bands = []
        for idx in range(pieces):
            seg_start = int(round(start + idx * step))
            seg_end = int(round(start + (idx + 1) * step))
            if seg_end - seg_start >= 6:
                bands.append((seg_start, seg_end))
        return bands or [(start, end)]

    def _find_active_bands(self, active: np.ndarray) -> list[tuple[int, int]]:
        bands: list[tuple[int, int]] = []
        start: int | None = None
        for index, value in enumerate(active):
            if value and start is None:
                start = index
            elif not value and start is not None:
                if index - start >= 6:
                    bands.append((start, index))
                start = None
        if start is not None and len(active) - start >= 6:
            bands.append((start, len(active) - 1))
        return bands

    def _fill_small_gaps(self, active: np.ndarray, max_gap: int) -> np.ndarray:
        if active.size == 0:
            return active
        out = active.copy()
        start: int | None = None
        for index, value in enumerate(active):
            if not value and start is None:
                start = index
            elif value and start is not None:
                if 0 < index - start <= max_gap:
                    left_on = start > 0 and active[start - 1]
                    right_on = active[index]
                    if left_on and right_on:
                        out[start:index] = True
                start = None
        return out

    def _split_band_by_valleys(
        self,
        smooth: np.ndarray,
        start: int,
        end: int,
        *,
        max_width: int,
        min_width: int,
    ) -> list[tuple[int, int]]:
        width = end - start
        if width <= max_width:
            return [(start, end)]

        segment = smooth[start:end]
        if segment.size < min_width * 2:
            return self._split_band(start, end, max_width)

        center_start = min_width
        center_end = segment.size - min_width
        if center_end <= center_start:
            return self._split_band(start, end, max_width)

        valley_rel = center_start + int(np.argmin(segment[center_start:center_end]))
        left_peak = float(np.max(segment[:valley_rel])) if valley_rel > 0 else 0.0
        right_peak = float(np.max(segment[valley_rel:])) if valley_rel < segment.size else 0.0
        valley = float(segment[valley_rel])

        if min(left_peak, right_peak) <= 0 or valley > min(left_peak, right_peak) * 0.72:
            return self._split_band(start, end, max_width)

        split = start + valley_rel
        parts: list[tuple[int, int]] = []
        if split - start >= min_width:
            parts.extend(
                self._split_band_by_valleys(
                    smooth,
                    start,
                    split,
                    max_width=max_width,
                    min_width=min_width,
                )
            )
        if end - split >= min_width:
            parts.extend(
                self._split_band_by_valleys(
                    smooth,
                    split,
                    end,
                    max_width=max_width,
                    min_width=min_width,
                )
        )
        return parts or [(start, end)]

    def _reject_implausible_detections(
        self,
        detections: list[_Detection],
        payload: ScanTeethRequest,
    ) -> list[_Detection]:
        if not detections:
            return detections

        opening = None
        if payload.upperLipTopY is not None and payload.lowerLipBottomY is not None:
            opening = max(0.0, payload.lowerLipBottomY - payload.upperLipTopY)

        filtered = [
            det
            for det in detections
            if det.confidence >= 0.48 and self._polygon_area(det.polygon) >= 0.00008
        ]
        if opening is not None and opening < 0.05:
            filtered = [det for det in filtered if det.jaw == "upper"]
        return filtered

    @staticmethod
    def _polygon_area(polygon: Iterable[tuple[float, float]]) -> float:
        pts = list(polygon)
        if len(pts) < 3:
            return 0.0
        area = 0.0
        for idx, (x1, y1) in enumerate(pts):
            x2, y2 = pts[(idx + 1) % len(pts)]
            area += x1 * y2 - x2 * y1
        return abs(area) * 0.5

    @staticmethod
    def _clamp_px(value: float, limit: int) -> int:
        return int(max(0, min(limit, round(value))))

    @staticmethod
    def _centroid_x(polygon: Iterable[tuple[float, float]]) -> float:
        points = list(polygon)
        if not points:
            return 0.0
        return sum(x for x, _ in points) / len(points)
