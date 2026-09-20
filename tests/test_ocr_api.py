import importlib.util
import os
import sys
import tempfile
import types
from pathlib import Path

from fastapi.testclient import TestClient


class FakeEngine:
    gpu_available = False

    def check_health(self):
        return {"status": "ready", "engine": "Fake", "is_ready": True}

    def recognize(self, image_path, filter_printed_text=False):
        return {
            "engine": "Fake",
            "engine_version": "test",
            "imageWidth": 1,
            "imageHeight": 1,
            "rawText": Path(image_path).name,
            "blocks": [],
        }


def load_worker(worker_dir: Path):
    services_package = types.ModuleType("services")
    services_package.__path__ = [str(worker_dir / "services")]
    fake_engine_module = types.ModuleType("services.ocr_engine")
    fake_engine_module.OCREngine = FakeEngine
    sys.modules["services"] = services_package
    sys.modules["services.ocr_engine"] = fake_engine_module

    spec = importlib.util.spec_from_file_location("ocr_worker_api_test", worker_dir / "main.py")
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    with tempfile.TemporaryDirectory(prefix="handwriting_ocr_api_") as temp_dir:
        allowed_root = Path(temp_dir) / "tasks"
        allowed_root.mkdir()
        inside_image = allowed_root / "page.png"
        inside_image.write_bytes(b"test")
        outside_image = Path(temp_dir) / "outside.png"
        outside_image.write_bytes(b"test")

        os.environ["OCR_TOKEN"] = "unit-test-token"
        os.environ["OCR_ALLOWED_ROOTS"] = str(allowed_root)
        worker = load_worker(repo_root / "ocr-worker")
        client = TestClient(worker.app)
        headers = {"X-OCR-Token": "unit-test-token"}

        assert client.get("/health").status_code == 401
        health = client.get("/health", headers=headers)
        assert health.status_code == 200
        assert health.json()["status"] == "ready"
        assert "access-control-allow-origin" not in health.headers

        accepted = client.post("/ocr", headers=headers, json={"image_path": str(inside_image)})
        assert accepted.status_code == 200
        assert accepted.json()["rawText"] == "page.png"

        rejected = client.post("/ocr", headers=headers, json={"image_path": str(outside_image)})
        assert rejected.status_code == 403

        oversized_batch = client.post(
            "/ocr/batch",
            headers=headers,
            json={"image_paths": [str(inside_image)] * 11},
        )
        assert oversized_batch.status_code == 422

    print("OCR API security tests passed successfully!")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
