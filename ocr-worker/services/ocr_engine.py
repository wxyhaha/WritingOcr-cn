import os
import re
import uuid
import tempfile
import logging
import threading
import warnings
from typing import List, Dict, Any, Tuple, Optional
import cv2
import numpy as np
from PIL import Image

# Suppress non-critical library warnings
warnings.filterwarnings("ignore")

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

WATERMARK_KEYWORDS = [
    'xiaomi', 'leica', 'ultra', 'huawei', 'iphone', 'vivo', 'oppo', 
    'honor', 'redmi', 'galaxy', 'shot on', 'dual camera', 'ai camera', 
    'hasselblad', 'zeiss', 'matrix camera', 'sony', 'canon', 'nikon',
    'fujifilm', 'lumix', 'panasonic', 'realme', 'oneplus', 'meizu',
    'samsung', 'apple'
]

PRINTED_HEADERS = [
    r'^no\.?$', r'^date:?$', r'^page:?$', r'^date\s*[\/:\.\-]*',
    r'^no\s*[\.:\-]*', r'^page\s*[\.:\-]*',
    r'^(姓名|日期|班级|学号|科目|考号|页码|得分|评卷人|批阅人|签字)[：:\s]*$',
    r'^(年\s*月\s*日|第\s*页\s*共\s*页|题目|注意事项|绝密★启用前)$'
]

def classify_crop_handwriting_vs_printed(crop_bgr: np.ndarray, text: str, bbox: Dict[str, float], img_w: int, img_h: int) -> Tuple[float, str]:
    """
    Classify a cropped textline image as Handwriting vs. Printed Font
    using Computer Vision morphological features, gradient distributions,
    and structural priors.

    Returns:
        (handwriting_score: float in [0.0, 1.0], classification: "handwriting" | "printed")
    """
    clean_text = text.strip().lower()

    # 1. Immediate Lexical & Camera Watermark Prior Check
    for kw in WATERMARK_KEYWORDS:
        if kw in clean_text:
            return 0.05, "printed"

    for pat in PRINTED_HEADERS:
        if re.search(pat, clean_text, re.IGNORECASE):
            return 0.08, "printed"

    # Date / Time string at extreme margins (e.g. 2026/08/24 11:30)
    if re.search(r'^\d{4}[\.\-\/]\d{1,2}[\.\-\/]\d{1,2}(\s+\d{1,2}:\d{1,2}(:\d{1,2})?)?$', clean_text):
        y_c = bbox.get("y", 0) + bbox.get("height", 0) / 2.0
        if y_c > img_h * 0.85 or y_c < img_h * 0.15:
            return 0.08, "printed"

    if crop_bgr is None or crop_bgr.size == 0 or crop_bgr.shape[0] < 6 or crop_bgr.shape[1] < 6:
        return 0.70, "handwriting"

    try:
        gray = cv2.cvtColor(crop_bgr, cv2.COLOR_BGR2GRAY) if len(crop_bgr.shape) == 3 else crop_bgr

        # 2. Otsu Binarization
        _, binary = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)
        
        total_pixels = binary.size
        fg_pixels = np.count_nonzero(binary)
        fg_ratio = fg_pixels / float(total_pixels)
        if fg_ratio < 0.01 or fg_ratio > 0.95:
            return 0.70, "handwriting"

        # 3. CV Feature 1: Stroke Width Variation via Distance Transform
        dist = cv2.distanceTransform(binary, cv2.DIST_L2, 3)
        stroke_vals = dist[binary > 0]
        if len(stroke_vals) > 10:
            mean_w = float(np.mean(stroke_vals))
            std_w = float(np.std(stroke_vals))
            stroke_cv = std_w / (mean_w + 1e-5)
        else:
            stroke_cv = 0.40

        # Printed digital font has extremely low stroke width variation (std/mean < 0.25)
        if stroke_cv < 0.25:
            return round(stroke_cv, 3), "printed"

        # 4. CV Feature 2: Axial Gradient Ratio (Horizontal & Vertical mechanical lines)
        gx = cv2.Sobel(gray, cv2.CV_32F, 1, 0, ksize=3)
        gy = cv2.Sobel(gray, cv2.CV_32F, 0, 1, ksize=3)
        mag, ang = cv2.cartToPolar(gx, gy, angleInDegrees=True)

        valid_grad = mag > 20
        if np.count_nonzero(valid_grad) > 30:
            angles = ang[valid_grad] % 180.0
            is_axial = ((angles < 10) | (angles > 170) | ((angles > 80) & (angles < 100)))
            axial_ratio = float(np.mean(is_axial))
        else:
            axial_ratio = 0.45

        # Printed font has high axial gradient ratio (> 0.62)
        if axial_ratio > 0.62 and stroke_cv < 0.35:
            return 0.15, "printed"

        # Natural handwriting score calculation
        handwriting_score = round(float(np.clip(0.50 + 0.80 * (stroke_cv - 0.30) - 0.40 * (axial_ratio - 0.40), 0.10, 0.98)), 3)
        label = "handwriting" if handwriting_score >= 0.50 else "printed"
        return handwriting_score, label

    except Exception as e:
        logger.debug(f"Crop classification fallback: {e}")
        return 0.70, "handwriting"

class OCREngine:
    def __init__(self):
        self.ocr = None
        self.gpu_available = False
        self.engine_name = "PaddleOCR"
        self.engine_version = "PP-OCRv5"
        self.is_ready = False
        self._ready_event = threading.Event()
        
        # Asynchronous background model warmup so HTTP server starts instantly (<0.2s)
        self._warmup_thread = threading.Thread(target=self._init_engine, daemon=True)
        self._warmup_thread.start()

    def _init_engine(self):
        try:
            import paddle
            self.gpu_available = paddle.is_compiled_with_cuda() and paddle.device.cuda.device_count() > 0
        except Exception:
            self.gpu_available = False

        try:
            from paddleocr import PaddleOCR
            logger.info("Initializing PaddleOCR engine in background (lang=ch)...")
            self.ocr = PaddleOCR(
                lang="ch",
                use_doc_orientation_classify=False,
                use_doc_unwarping=False,
                use_textline_orientation=False
            )
            self.is_ready = True
            self._ready_event.set()
            logger.info("PaddleOCR engine initialized and ready.")
        except Exception as e:
            logger.warning(f"PaddleOCR background load failed: {e}.")
            self.is_ready = False
            self._ready_event.set()

    def check_health(self) -> Dict[str, Any]:
        return {
            "status": "ready" if self.is_ready else "loading",
            "message": "OCR Worker 就绪 (PP-OCRv5)" if self.is_ready else "正在后台预热 OCR 模型...",
            "engine": self.engine_name,
            "engine_version": self.engine_version,
            "gpu_available": self.gpu_available
        }

    def recognize(self, image_path: str, filter_printed_text: bool = True) -> Dict[str, Any]:
        if not os.path.exists(image_path):
            raise FileNotFoundError(f"Image not found: {image_path}")

        # Wait for model warmup if recognition is triggered within first ~2 seconds of app launch
        if not self.is_ready:
            logger.info("Waiting for background OCR model warmup to finish...")
            self._ready_event.wait(timeout=30)

        # Load full image via OpenCV for pixel crop classification
        orig_cv_img = cv2.imdecode(np.fromfile(image_path, dtype=np.uint8), cv2.IMREAD_COLOR)
        if orig_cv_img is None:
            with Image.open(image_path) as pil_img:
                orig_cv_img = cv2.cvtColor(np.array(pil_img.convert("RGB")), cv2.COLOR_RGB2BGR)

        orig_height, orig_width = orig_cv_img.shape[:2]

        # If image exceeds max inference dimension on CPU, scale down for fast inference
        max_dim = 1600
        scale_factor = min(1.0, max_dim / float(max(orig_width, orig_height)))
        
        infer_path = image_path
        temp_file_to_clean = None

        if scale_factor < 0.95:
            new_w = int(orig_width * scale_factor)
            new_h = int(orig_height * scale_factor)
            resized_cv = cv2.resize(orig_cv_img, (new_w, new_h), interpolation=cv2.INTER_AREA)
            fd, temp_infer_path = tempfile.mkstemp(suffix=".jpg")
            os.close(fd)
            cv2.imwrite(temp_infer_path, resized_cv, [cv2.IMWRITE_JPEG_QUALITY, 95])
            infer_path = temp_infer_path
            temp_file_to_clean = temp_infer_path
            logger.info(f"Scaled image for fast OCR from ({orig_width}, {orig_height}) to ({new_w}, {new_h}), scale={scale_factor:.3f}")

        try:
            if self.ocr is None:
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

                        # Clamp pixel coordinates
                        ix1 = max(0, min(orig_width - 1, int(min_x)))
                        iy1 = max(0, min(orig_height - 1, int(min_y)))
                        ix2 = max(ix1 + 1, min(orig_width, int(max_x)))
                        iy2 = max(iy1 + 1, min(orig_height, int(max_y)))

                        bbox_dict = {
                            "x": round(float(min_x), 2),
                            "y": round(float(min_y), 2),
                            "width": round(float(max_x - min_x), 2),
                            "height": round(float(max_y - min_y), 2)
                        }

                        # Crop the exact textline region from original image for CV handwriting classification
                        crop_patch = orig_cv_img[iy1:iy2, ix1:ix2]
                        handwriting_score, font_type = classify_crop_handwriting_vs_printed(
                            crop_patch, text, bbox_dict, orig_width, orig_height
                        )

                        block = {
                            "id": f"blk_{uuid.uuid4().hex[:8]}",
                            "text": text,
                            "confidence": round(score, 4),
                            "bbox": bbox_dict,
                            "lineIndex": i,
                            "blockIndex": 0,
                            "type": font_type,
                            "handwritingScore": handwriting_score,
                            "status": "raw"
                        }
                        blocks.append(block)

                        # Filter out printed font from rawText if filter_printed_text is True
                        if not (filter_printed_text and font_type == "printed"):
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
