# tests/test_config.py
from mediahub.config import Config

def test_from_env_defaults(monkeypatch):
    for k in ("PROWLARR_URL","PROWLARR_API_KEY","TRANSMISSION_RPC_URL",
              "MEDIA_ROOT","DOWNLOADS_DIR","MEDIAHUB_DB"):
        monkeypatch.delenv(k, raising=False)
    c = Config.from_env()
    assert c.prowlarr_url == "http://127.0.0.1:9696"
    assert c.media_root == "/tank/media"
    assert c.db_path == "/var/lib/mediahub/review.db"

def test_from_env_overrides(monkeypatch):
    monkeypatch.setenv("PROWLARR_API_KEY", "abc123")
    monkeypatch.setenv("MEDIA_ROOT", "/mnt/x")
    c = Config.from_env()
    assert c.prowlarr_api_key == "abc123"
    assert c.media_root == "/mnt/x"
