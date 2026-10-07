import importlib
import sys
from unittest.mock import Mock, patch

from fastapi.testclient import TestClient


def test_serving_endpoints_and_s3_download(tmp_path, monkeypatch):
    monkeypatch.setenv("ARTIFACT_BUCKET", "test-bucket")
    monkeypatch.setenv("MODEL_PATH", str(tmp_path / "model.joblib"))
    sys.modules.pop("src.serve", None)

    fake_model = Mock()
    fake_model.predict.return_value = [1]

    with patch("boto3.client") as client_factory, patch(
        "joblib.load", return_value=fake_model
    ):
        serve = importlib.import_module("src.serve")

    client_factory.return_value.download_file.assert_called_once_with(
        "test-bucket",
        "artifacts/current/model.joblib",
        str(tmp_path / "model.joblib"),
    )

    client = TestClient(serve.app)
    health = client.get("/healthz")
    score = client.post(
        "/score",
        json={"features": [28, 2, 14, 2, 11, 0, 1, 0, 0, 45]},
    )
    invalid = client.post("/score", json={"features": [1, 2]})

    assert health.status_code == 200
    assert health.json() == {"status": "ok"}
    assert score.status_code == 200
    assert score.json() == {"prediction": 1, "label": "thu_nhap_cao"}
    assert invalid.status_code == 400
