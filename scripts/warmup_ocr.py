"""Download and validate the PP-OCRv5 models for a release package."""

from __future__ import annotations

import os
import sys


def main() -> int:
    cache_home = os.environ.get("PADDLE_PDX_CACHE_HOME")
    if not cache_home:
        raise SystemExit("PADDLE_PDX_CACHE_HOME must point to the release model cache")

    os.makedirs(cache_home, exist_ok=True)

    from paddleocr import PaddleOCR

    print(f"[Warmup] Using PaddleX cache: {cache_home}", flush=True)
    PaddleOCR(
        lang="ch",
        use_doc_orientation_classify=False,
        use_doc_unwarping=False,
        use_textline_orientation=False,
    )
    print("[Warmup] PP-OCRv5 model cache is ready.", flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
