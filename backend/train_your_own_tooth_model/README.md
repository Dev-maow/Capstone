# Train Your Own Tooth Segmentation Model

This folder is a starter pipeline for building a real tooth segmentation model
for the Flutter AR app.

Goal:
- train on RGB smile / intraoral photos
- export to ONNX
- plug the ONNX model into `backend/tooth_scan_api`

Recommended first milestone:
- segment `upper_teeth`
- segment `lower_teeth`

Do not start with individual tooth instances unless you already have a larger,
well-labeled dataset. Upper/lower masks are much easier to label and already
good enough for whitening, veneers, and braces alignment.

## Folder Layout

```text
backend/train_your_own_tooth_model/
  datasets/
    teeth_seg/
      images/
        train/
        val/
      labels/
        train/
        val/
  configs/
    teeth_seg.yaml
  scripts/
    validate_dataset.py
    train_yolo_seg.py
    export_onnx.py
  requirements.txt
  LABELING_GUIDE.md
```

## Model Choice

We use `YOLO segmentation` as the default starter choice because it is:
- easier to train than a custom research stack
- easier to export to ONNX
- practical for deployment

Starter model:
- `yolov8n-seg.pt`

If you want better quality later:
- `yolov8s-seg.pt`
- `yolo11n-seg.pt` or `yolo11s-seg.pt` if your Ultralytics version supports them

## Dataset Format

This scaffold expects Ultralytics segmentation labels.

Classes:
- `0`: `upper_teeth`
- `1`: `lower_teeth`

Each label file is a `.txt` with one object per line:

```text
<class_id> x1 y1 x2 y2 x3 y3 ...
```

Coordinates are normalized `0..1`.

Example:

```text
0 0.35 0.42 0.48 0.40 0.52 0.49 0.34 0.51
1 0.36 0.54 0.47 0.55 0.49 0.61 0.35 0.60
```

## Suggested Data Collection

Collect images with variation in:
- skin tones
- lighting
- camera distance
- head tilt
- smile width
- upper-only visible teeth
- upper and lower visible teeth
- partially visible teeth
- braces
- no visible teeth

Very important negative cases:
- big open mouth but no visible teeth
- lips covering lower teeth
- low light
- motion blur
- tongue visible

These negative cases are what stop the model from hallucinating teeth.

## Labeling Tips

Label only visible enamel, not:
- lips
- gums
- tongue
- mouth cavity

If lower teeth are not clearly visible:
- do not invent a lower label

If no teeth are visible:
- create an empty label file

## Install

From `backend/train_your_own_tooth_model`:

```powershell
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

## Validate Dataset

```powershell
python scripts/validate_dataset.py
```

## Train

```powershell
python scripts/train_yolo_seg.py
```

## Export ONNX

```powershell
python scripts/export_onnx.py
```

Expected ONNX output target:

```text
backend/tooth_scan_api/models/tooth_segmentation.onnx
```

## Backend Integration

The backend detector already supports an optional ONNX model:
- default path: `backend/tooth_scan_api/models/tooth_segmentation.onnx`
- or env var: `TOOTH_SEGMENTATION_MODEL`

Once an ONNX file exists there, restart the backend and it will try to use it.

## Realistic Roadmap

Phase 1:
- binary upper/lower tooth segmentation

Phase 2:
- confidence gating
- temporal smoothing across frames

Phase 3:
- individual tooth instance segmentation
- bracket-per-tooth fitting

