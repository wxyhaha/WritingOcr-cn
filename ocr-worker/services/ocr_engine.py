import os
import uuid
import tempfile
import logging
from typing import List, Dict, Any, Optional
from PIL import Image

logger = logging.getLogger("ocr_worker")

# Safely patch paddle inference to disable onednn on CPU if PIR attribute conversion issue occurs
try:
    import paddle.inference as paddle_inference
    orig_create_predictor = paddle_inference.create_predictor
    def safe_create_predictor(config):
        try:
            config.disable_onednn()
            config.disable_mkldnn()
        except Exception:
            pass
        return orig_create_predictor(config)
    paddle_inference.create_predictor = safe_create_predictor
except Exception as e:
    logger.debug(f"PIR predictor hook note: {e}")

class OCREngine:
    def __init__(self):
        self.ocr = None
        self.gpu_available = False
        self.engine_name = "PaddleOCR"
        self.engine_version = "PP-OCRv5"
        self.is_ready = False
        self._init_engine()

    def _init_engine(self):
        try:
            import paddle
            self.gpu_available = paddle.is_compiled_with_cuda() and paddle.device.cuda.device_count() > 0
        except Exception:
            self.gpu_available = False

        try:
            from paddleocr import PaddleOCR
            logger.info("Initializing PaddleOCR engine (lang=ch)...")
            self.ocr = PaddleOCR(
                lang="ch",
                use_doc_orientation_classify=False,
                use_doc_unwarping=False,
                use_textline_orientation=False
            )
            self.is_ready = True
            logger.info("PaddleOCR engine initialized successfully.")
        except Exception as e:
            logger.warning(f"PaddleOCR initial load failed: {e}. Will attempt on-demand load.")
            self.is_ready = False

    def check_health(self) -> Dict[str, Any]:
        return {
            "status": "ready" if self.is_ready else "not_ready",
            "engine": self.engine_name,
            "engine_version": self.engine_version,
            "gpu_available": self.gpu_available
        }

    def recognize(self, image_path: str) -> Dict[str, Any]:
        if not os.path.exists(image_path):
            raise FileNotFoundError(f"Image not found: {image_path}")

        # Open image with PIL to verify dimensions and optimize scale if needed
        with Image.open(image_path) as img:
            orig_width, orig_height = img.size

            # If image exceeds max inference dimension on CPU, scale down for 5x-10x faster inference
            max_dim = 1600
            scale_factor = min(1.0, max_dim / float(max(orig_width, orig_height)))
            
            infer_path = image_path
            temp_file_to_clean = None

            if scale_factor < 0.95:
                new_w = int(orig_width * scale_factor)
                new_h = int(orig_height * scale_factor)
                resized_img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
                fd, temp_infer_path = tempfile.mkstemp(suffix=".jpg")
                os.close(fd)
                resized_img.save(temp_infer_path, quality=95)
                infer_path = temp_infer_path
                temp_file_to_clean = temp_infer_path
                logger.info(f"Scaled image for fast OCR from ({orig_width}, {orig_height}) to ({new_w}, {new_h}), scale={scale_factor:.3f}")

        try:
            if not self.is_ready or self.ocr is None:
                from paddleocr import PaddleOCR
                self.ocr = PaddleOCR(
                    lang="ch",
                    use_doc_orientation_classify=False,
                    use_doc_unwarping=False,
                    use_textline_orientation=False
                )
                self.is_ready = True

            raw_result = self.ocr.predict(infer_path)

            blocks: List[Dict[str, Any]] = []
            raw_text_lines: List[str] = []

            coord_multiplier = 1.0 / scale_factor

            if raw_result is not None:
                if hasattr(raw_result, "__iter__") and not isinstance(raw_result, (list, tuple)):
                    raw_result = list(raw_result)

                for page_item in raw_result:
                    rec_texts = []
                    rec_scores = []
                    dt_polys = []

                    if isinstance(page_item, dict) or hasattr(page_item, "keys"):
                        rec_texts = page_item.get("rec_texts", page_item.get("rec_text", []))
                        rec_scores = page_item.get("rec_scores", page_item.get("rec_score", []))
                        dt_polys = page_item.get("dt_polys", page_item.get("dt_boxes", []))
                    elif isinstance(page_item, list):
                        for line_data in page_item:
                            if len(line_data) >= 2:
                                dt_polys.append(line_data[0])
                                rec_texts.append(line_data[1][0])
                                rec_scores.append(line_data[1][1])

                    for i in range(len(rec_texts)):
                        text = str(rec_texts[i])
                        score = float(rec_scores[i]) if i < len(rec_scores) else 1.0

                        poly = dt_polys[i] if i < len(dt_polys) else None
                        if poly is not None and hasattr(poly, "tolist"):
                            poly = poly.tolist()

                        if poly is not None and len(poly) >= 4 and isinstance(poly[0], (list, tuple)):
                            xs = [p[0] for p in poly]
                            ys = [p[1] for p in poly]
                            min_x, max_x = min(xs) * coord_multiplier, max(xs) * coord_multiplier
                            min_y, max_y = min(ys) * coord_multiplier, max(ys) * coord_multiplier
                        elif poly is not None and len(poly) == 4 and not isinstance(poly[0], (list, tuple)):
                            min_x, min_y = poly[0] * coord_multiplier, poly[1] * coord_multiplier
                            max_x, max_y = poly[2] * coord_multiplier, poly[3] * coord_multiplier
                        else:
                            min_x, min_y = 0, i * 40 * coord_multiplier
                            max_x, max_y = orig_width, (i + 1) * 40 * coord_multiplier

                        block = {
                            "id": f"blk_{uuid.uuid4().hex[:8]}",
                            "text": text,
                            "confidence": round(score, 4),
                            "bbox": {
                                "x": round(float(min_x), 2),
                                "y": round(float(min_y), 2),
                                "width": round(float(max_x - min_x), 2),
                                "height": round(float(max_y - min_y), 2)
                            },
                            "lineIndex": i,
                            "blockIndex": 0,
                            "type": "text",
                            "status": "raw"
                        }
                        blocks.append(block)
                        raw_text_lines.append(text)

            raw_text = "\n".join(raw_text_lines)

            return {
                "engine": self.engine_name,
                "engine_version": self.engine_version,
                "imageWidth": orig_width,
                "imageHeight": orig_height,
                "rawText": raw_text,
                "blocks": blocks
            }
        finally:
            if temp_file_to_clean and os.path.exists(temp_file_to_clean):
                try:
                    os.remove(temp_file_to_clean)
                except Exception:
                    pass
