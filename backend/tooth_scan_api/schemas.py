from typing import Literal

from pydantic import BaseModel, Field


class ScanTeethRequest(BaseModel):
    encoding: Literal["nv21"] = "nv21"
    imageWidth: int = Field(..., gt=0)
    imageHeight: int = Field(..., gt=0)
    rotation: int = 0
    isFrontCamera: bool = True
    bytesBase64: str = Field(..., min_length=16)
    toothBboxX: float | None = Field(default=None, ge=0.0, le=1.0)
    toothBboxY: float | None = Field(default=None, ge=0.0, le=1.0)
    toothBboxW: float | None = Field(default=None, ge=0.0, le=1.0)
    toothBboxH: float | None = Field(default=None, ge=0.0, le=1.0)
    lipLeftX: float | None = Field(default=None, ge=0.0, le=1.0)
    lipRightX: float | None = Field(default=None, ge=0.0, le=1.0)
    upperLipTopY: float | None = Field(default=None, ge=0.0, le=1.0)
    lowerLipBottomY: float | None = Field(default=None, ge=0.0, le=1.0)


class ToothPoint(BaseModel):
    x: float = Field(..., ge=0.0, le=1.0)
    y: float = Field(..., ge=0.0, le=1.0)


class ToothPrediction(BaseModel):
    id: str
    jaw: Literal["upper", "lower"]
    confidence: float = Field(..., ge=0.0, le=1.0)
    polygon: list[ToothPoint]


class ScanTeethResponse(BaseModel):
    imageWidth: int
    imageHeight: int
    confidence: float = Field(..., ge=0.0, le=1.0)
    teeth: list[ToothPrediction]
