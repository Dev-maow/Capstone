from fastapi import FastAPI, HTTPException

from detector import ToothDetector
from schemas import ScanTeethRequest, ScanTeethResponse


app = FastAPI(
    title="DentaLogic Tooth Scan API",
    version="0.1.0",
    description=(
        "Backend service for Flutter AR tooth scanning. "
        "This first version uses a model-free OpenCV pipeline so the mobile app "
        "has a working real-time endpoint today."
    ),
)

detector = ToothDetector()


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/scan/teeth", response_model=ScanTeethResponse)
def scan_teeth(payload: ScanTeethRequest) -> ScanTeethResponse:
    try:
        return detector.scan(payload)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Tooth scan failed: {exc}",
        ) from exc
