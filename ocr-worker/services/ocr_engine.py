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

def sort_blocks_and_format_text(
    blocks: List[Dict[str, Any]], 
    filter_printed: bool = False
) -> Tuple[str, List[Dict[str, Any]]]:
    """
    1. Spatial topological sort: Groups lines by dynamic line height clustering, then sorts X.
    2. Directly format into clean 1:1 text lines separated by '\\n'.
    3. Calculate exact charStart and charEnd for bidirectional linking.
    """
    if not blocks:
        return "", []

    # Calculate median height
    heights = [b["bbox"]["height"] for b in blocks if b["bbox"].get("height", 0) > 0]
    median_h = float(np.median(heights)) if heights else 30.0
    line_cluster_threshold = max(10.0, median_h * 0.55)

    # 1. Spatial topological sorting (Top-to-Bottom, Left-to-Right)
    sorted_by_y = sorted(blocks, key=lambda b: (b["bbox"]["y"], b["bbox"]["x"]))
    
    # Cluster into visual lines
    lines: List[List[Dict[str, Any]]] = []
    for b in sorted_by_y:
        if not lines:
            lines.append([b])
            continue
        last_line = lines[-1]
        line_y = np.mean([item["bbox"]["y"] for item in last_line])
        if abs(b["bbox"]["y"] - line_y) <= line_cluster_threshold:
            last_line.append(b)
        else:
            lines.append([b])

    # Within each line, sort by X
    sorted_blocks: List[Dict[str, Any]] = []
    for line in lines:
        line_sorted = sorted(line, key=lambda b: b["bbox"]["x"])
        sorted_blocks.extend(line_sorted)

    # Filter out printed text if needed
    active_blocks = [b for b in sorted_blocks if not (filter_printed and b.get("type") == "printed")]

    if not active_blocks:
        for idx, b in enumerate(sorted_blocks):
            b["lineIndex"] = idx
            b["charStart"] = -1
            b["charEnd"] = -1
        return "", sorted_blocks

    output_lines: List[str] = []
    curr_offset = 0

    for i, b in enumerate(active_blocks):
        b["lineIndex"] = i
        text = b["text"]
        
        b["charStart"] = curr_offset
        b["charEnd"] = curr_offset + len(text)
        curr_offset += len(text) + 1  # account for '\n'
        output_lines.append(text)

    full_text = "\n".join(output_lines)

    # For any printed blocks that were filtered out, set charStart/charEnd = -1
    for b in sorted_blocks:
        if b.get("charStart") is None:
            b["charStart"] = -1
            b["charEnd"] = -1

    return full_text, sorted_blocks

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
            logger.info("Starting background PaddleOCR engine warmup...")
            from paddleocr import PaddleOCR
            self.ocr = PaddleOCR(
                lang="ch",
                use_doc_orientation_classify=False,
                use_doc_unwarping=False,
                use_textline_orientation=False
            )
            self.is_ready = True
            self._ready_event.set()
            logger.info("PaddleOCR engine loaded and warm ready!")
        except Exception as e:
            logger.error(f"Failed to initialize PaddleOCR engine in warmup: {e}", exc_info=True)
            self.is_ready = True
            self._ready_event.set()

    def check_health(self) -> Dict[str, Any]:
        return {
            "status": "ready" if self.is_ready else "warming_up",
            "engine": self.engine_name,
            "engine_version": self.engine_version,
            "gpu_available": self.gpu_available,
            "is_ready": self.is_ready
        }

    def recognize(
        self, 
        image_path: str, 
        detect_orientation: bool = True, 
        filter_printed_text: bool = False
    ) -> Dict[str, Any]:
        return self.predict(
            image_path=image_path, 
            detect_orientation=detect_orientation, 
            filter_printed_text=filter_printed_text
        )

    def predict(
        self, 
        image_path: str, 
        detect_orientation: bool = True, 
        filter_printed_text: bool = False
    ) -> Dict[str, Any]:
        # Wait for model warmup if a request arrives during the first 1-2 seconds
        if not self.is_ready:
            logger.info("OCR request received while warming up, waiting for model ready...")
            self._ready_event.wait(timeout=15.0)

        if not os.path.exists(image_path):
            raise FileNotFoundError(f"Image not found: {image_path}")

        pil_img = Image.open(image_path)
        orig_width, orig_height = pil_img.size

        # Load OpenCV BGR image for classification and scaling
        orig_cv_img = cv2.imread(image_path)
        if orig_cv_img is None:
            # Fallback for unicode filepaths on Windows
            orig_cv_img = cv2.imdecode(np.fromfile(image_path, dtype=np.uint8), cv2.IMREAD_COLOR)

        temp_file_to_clean = None
        infer_path = image_path

        # Downscale large mobile images (> 1920px) for high-speed inference
        MAX_INFER_DIM = 1920
        max_dim = max(orig_width, orig_height)
        scale_factor = 1.0
        if max_dim > MAX_INFER_DIM:
            scale_factor = MAX_INFER_DIM / float(max_dim)
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

            raw_blocks: List[Dict[str, Any]] = []
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
                        raw_blocks.append(block)

            # Spatial sort and direct 1:1 text line formatting
            formatted_text, sorted_blocks = sort_blocks_and_format_text(
                raw_blocks, filter_printed=filter_printed_text
            )

            return {
                "engine": self.engine_name,
                "engine_version": self.engine_version,
                "imageWidth": orig_width,
                "imageHeight": orig_height,
                "rawText": formatted_text,
                "blocks": sorted_blocks
            }
        finally:
            if temp_file_to_clean and os.path.exists(temp_file_to_clean):
                try:
                    os.remove(temp_file_to_clean)
                except Exception:
                    pass
