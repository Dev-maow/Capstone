from __future__ import annotations

import shutil
from pathlib import Path

from ultralytics import YOLO


ROOT = Path(__file__).resolve().parents[1]
RUNS = ROOT / "runs" / "teeth_seg"
BACKEND_MODELS = ROOT.parents[1] / "tooth_scan_api" / "models"


def _best_weights() -> Path:
    direct = RUNS / "weights" / "best.pt"
    if direct.exists():
        return direct

    candidates = sorted(ROOT.glob("runs/**/weights/best.pt"))
    if candidates:
        return candidates[-1]
    raise SystemExit("Could not find best.pt. Train the model first.")


def main() -> None:
    weights = _best_weights()
    model = YOLO(str(weights))
    exported = model.export(format="onnx", imgsz=640, opset=12)
    exported_path = Path(exported)

    BACKEND_MODELS.mkdir(parents=True, exist_ok=True)
    target = BACKEND_MODELS / "tooth_segmentation.onnx"
    shutil.copy2(exported_path, target)
    print(f"Exported ONNX copied to: {target}")


if __name__ == "__main__":
    main()

