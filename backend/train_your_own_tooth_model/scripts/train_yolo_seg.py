from __future__ import annotations

from pathlib import Path

import torch
from ultralytics import YOLO


ROOT = Path(__file__).resolve().parents[1]
CONFIG = ROOT / "configs" / "teeth_seg.yaml"


def main() -> None:
    if not CONFIG.exists():
        raise SystemExit(f"Missing config: {CONFIG}")

    device = "0" if torch.cuda.is_available() else "cpu"
    batch = 8 if device != "cpu" else 4

    model = YOLO("yolov8n-seg.pt")
    model.train(
        data=str(CONFIG),
        imgsz=640,
        epochs=100,
        batch=batch,
        device=device,
        project=str(ROOT / "runs"),
        name="teeth_seg",
        patience=20,
        hsv_h=0.01,
        hsv_s=0.30,
        hsv_v=0.20,
        degrees=8.0,
        translate=0.04,
        scale=0.20,
        fliplr=0.0,
        mosaic=0.10,
    )


if __name__ == "__main__":
    main()

