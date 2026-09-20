import os
import sys
import logging
import hmac
from pathlib import Path
from typing import List, Optional
from fastapi import FastAPI, HTTPException, Header
from pydantic import BaseModel
import uvicorn

logging.basicConfig(
    level=logging.INFO,
    format="[%(asctime)s] [%(levelname)s] [%(name)s] %(message)s"
)
logger = logging.getLogger("ocr_worker")

# Validate Python version and architecture
if sys.version_info < (3, 10) or sys.version_info >= (3, 14):
    logger.warning("Running on Python %s. For best stability with PaddlePaddle 3.x, use Python 3.10 ~ 3.13 (64-bit).", sys.version.split()[0])
if sys.maxsize <= 2**32:
    logger.error("32-bit Python detected! PaddlePaddle & PaddleOCR strictly require 64-bit Python (win_amd64).")
    sys.exit(1)

# Add current dir to sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from services.ocr_engine import OCREngine

app = FastAPI(
    title="Handwriting Chinese OCR Worker",
    version="1.0.0",
    description="Local OCR Worker API for Handwriting Chinese Article Digitalization"
)

engine = OCREngine()
ocr_token = os.environ.get("OCR_TOKEN", "")
configured_roots = [p for p in os.environ.get("OCR_ALLOWED_ROOTS", "").split(os.pathsep) if p]
allowed_roots = [Path(p).expanduser().resolve() for p in configured_roots]
if not allowed_roots:
    allowed_roots = [(Path.home() / "Documents" / "HandwritingOCR" / "tasks").resolve()]

def authorize(x_ocr_token: Optional[str]) -> None:
    if ocr_token and not hmac.compare_digest(x_ocr_token or "", ocr_token):
        raise HTTPException(status_code=401, detail="Invalid OCR worker token")

def validate_image_path(image_path: str) -> str:
    try:
        resolved = Path(image_path).expanduser().resolve(strict=True)
    except (OSError, RuntimeError):
        raise HTTPException(status_code=404, detail="Image file not found")
    if not resolved.is_file():
        raise HTTPException(status_code=404, detail="Image file not found")
    if not any(resolved.is_relative_to(root) for root in allowed_roots):
        logger.warning("Rejected OCR path outside configured roots: %s", resolved)
        raise HTTPException(status_code=403, detail="Image path is outside the permitted task storage")
    return str(resolved)

class OcrRequest(BaseModel):
    image_path: str
    lang: Optional[str] = "ch"
    filter_printed_text: Optional[bool] = True

class OcrBatchRequest(BaseModel):
    image_paths: List[str]
    lang: Optional[str] = "ch"
    filter_printed_text: Optional[bool] = True

@app.get("/health")
def health(x_ocr_token: Optional[str] = Header(default=None)):
    authorize(x_ocr_token)
    return engine.check_health()

@app.get("/capabilities")
def capabilities(x_ocr_token: Optional[str] = Header(default=None)):
    authorize(x_ocr_token)
    return {
        "engine": "PaddleOCR",
        "version": "PP-OCRv5",
        "supported_languages": ["ch", "en"],
        "gpu_available": engine.gpu_available,
        "features": ["det", "rec", "cls", "confidence", "pixel_bbox", "filter_printed_text"]
    }

@app.post("/ocr")
def ocr(req: OcrRequest, x_ocr_token: Optional[str] = Header(default=None)):
    try:
        authorize(x_ocr_token)
        norm_path = validate_image_path(req.image_path)
        logger.info(f"Received OCR request for image: {norm_path}, filter_printed_text={req.filter_printed_text}")
        result = engine.recognize(norm_path, filter_printed_text=bool(req.filter_printed_text))
        logger.info(f"OCR completed for {norm_path}, recognized {len(result.get('blocks', []))} blocks.")
        return result
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"OCR processing failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/ocr/batch")
def ocr_batch(req: OcrBatchRequest, x_ocr_token: Optional[str] = Header(default=None)):
    authorize(x_ocr_token)
    if len(req.image_paths) > 10:
        raise HTTPException(status_code=422, detail="A batch may contain at most 10 images")
    results = []
    for path in req.image_paths:
        try:
            validated_path = validate_image_path(path)
            res = engine.recognize(validated_path, filter_printed_text=bool(req.filter_printed_text))
            results.append({"image_path": validated_path, "success": True, "result": res})
        except HTTPException as e:
            results.append({"image_path": path, "success": False, "error": e.detail})
        except Exception as e:
            results.append({"image_path": path, "success": False, "error": str(e)})
    return {"results": results}

if __name__ == "__main__":
    port = int(os.environ.get("OCR_PORT", 8766))
    host = os.environ.get("OCR_HOST", "127.0.0.1")
    logger.info(f"Starting OCR Worker on http://{host}:{port}")
    uvicorn.run(app, host=host, port=port, log_level="info")
