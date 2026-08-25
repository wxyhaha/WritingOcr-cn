import os
import sys
import logging
from typing import List, Optional
from fastapi import FastAPI, HTTPException, Body
from fastapi.middleware.cors import CORSMiddleware
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

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

engine = OCREngine()

class OcrRequest(BaseModel):
    image_path: str
    lang: Optional[str] = "ch"
    filter_printed_text: Optional[bool] = True

class OcrBatchRequest(BaseModel):
    image_paths: List[str]
    lang: Optional[str] = "ch"
    filter_printed_text: Optional[bool] = True

@app.get("/health")
def health():
    return engine.check_health()

@app.get("/capabilities")
def capabilities():
    return {
        "engine": "PaddleOCR",
        "version": "PP-OCRv5",
        "supported_languages": ["ch", "en"],
        "gpu_available": engine.gpu_available,
        "features": ["det", "rec", "cls", "confidence", "pixel_bbox", "filter_printed_text"]
    }

@app.post("/ocr")
def ocr(req: OcrRequest):
    try:
        norm_path = os.path.normpath(req.image_path)
        logger.info(f"Received OCR request for image: {norm_path}, filter_printed_text={req.filter_printed_text}")
        if not os.path.exists(norm_path):
            logger.error(f"Image not found at path: {norm_path}")
            raise HTTPException(status_code=404, detail=f"Image file not found: {norm_path}")
        result = engine.recognize(norm_path, filter_printed_text=bool(req.filter_printed_text))
        logger.info(f"OCR completed for {norm_path}, recognized {len(result.get('blocks', []))} blocks.")
        return result
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"OCR processing failed: {e}", exc_info=True)
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/ocr/batch")
def ocr_batch(req: OcrBatchRequest):
    results = []
    for path in req.image_paths:
        try:
            res = engine.recognize(path, filter_printed_text=bool(req.filter_printed_text))
            results.append({"image_path": path, "success": True, "result": res})
        except Exception as e:
            results.append({"image_path": path, "success": False, "error": str(e)})
    return {"results": results}

if __name__ == "__main__":
    port = int(os.environ.get("OCR_PORT", 8766))
    host = os.environ.get("OCR_HOST", "127.0.0.1")
    logger.info(f"Starting OCR Worker on http://{host}:{port}")
    uvicorn.run(app, host=host, port=port, log_level="info")
