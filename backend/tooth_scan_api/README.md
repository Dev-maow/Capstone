# DentaLogic Tooth Scan API

This backend gives the Flutter AR screen a real `/scan/teeth` endpoint to call.

Important:
- This first version is a working backend scaffold with a model-free OpenCV detector.
- It is not orthodontic-grade segmentation yet.
- It is structured so we can swap in a proper tooth model later without changing the Flutter API contract.
- It now supports an optional ONNX tooth-segmentation model if you place one at `backend/tooth_scan_api/models/tooth_segmentation.onnx` or set `TOOTH_SEGMENTATION_MODEL`.

## What It Does

- Accepts live camera frames from the Flutter app
- Decodes NV21 frames
- Applies rotation and front-camera mirroring
- Runs a heuristic tooth detector
- Returns per-tooth polygons in the JSON shape already expected by Flutter

## API

`POST /scan/teeth`

Request body:

```json
{
  "encoding": "nv21",
  "imageWidth": 1280,
  "imageHeight": 720,
  "rotation": 90,
  "isFrontCamera": true,
  "bytesBase64": "..."
}
```

Response body:

```json
{
  "imageWidth": 720,
  "imageHeight": 1280,
  "confidence": 0.71,
  "teeth": [
    {
      "id": "upper_1",
      "jaw": "upper",
      "confidence": 0.83,
      "polygon": [
        { "x": 0.41, "y": 0.44 },
        { "x": 0.43, "y": 0.44 },
        { "x": 0.44, "y": 0.50 },
        { "x": 0.40, "y": 0.50 }
      ]
    }
  ]
}
```

## Local Setup

From `D:\Downloads\dentalogic_CLEAN_FINAL\dentalogic\backend\tooth_scan_api`:

```powershell
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

Then open these URLs:

- Local machine: `http://127.0.0.1:8000`
- Same Wi-Fi phone/device: `http://YOUR-PC-LAN-IP:8000`

Example:

```text
http://192.168.1.5:8000
```

Use that value inside the Flutter AR settings as the `Tooth Scan Backend` URL.

## Health Check

```powershell
curl http://127.0.0.1:8000/health
```

Expected:

```json
{"status":"ok"}
```

## Current Limits

- Works best with a well-lit close selfie and visible teeth
- Heuristic detection may miss teeth, merge teeth, or produce unstable counts
- Upper/lower jaw handling is intentionally simple in this first version
- Without a real segmentation model, the backend still uses a safer heuristic fallback

## Next Upgrade Path

To make this genuinely strong, use a real tooth segmentation model:

1. export or obtain an ONNX tooth segmentation model
2. place it at `backend/tooth_scan_api/models/tooth_segmentation.onnx`
3. or set `TOOTH_SEGMENTATION_MODEL=C:\full\path\to\model.onnx`
4. restart the backend

The detector will then:

1. run the segmentation model on the mouth ROI
2. per-tooth instance separation
3. jaw-aware ordering and tracking across frames
4. temporal smoothing for stable AR placement

The API contract can stay the same while we improve the detector.
