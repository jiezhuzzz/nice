# tests/test_web.py
from types import SimpleNamespace
from fastapi.testclient import TestClient
from mediahub.web import create_app
from mediahub.prowlarr import Release
from mediahub.store import ReviewStore


def _release(title, seeders=10):
    return Release(title=title, size=1, seeders=seeders, indexer="M-Team",
                   categories=[2000], download_url="http://pl/dl?id=1", guid="g",
                   publish_date=None, info_url=None)


class FakeProwlarr:
    def __init__(self, releases): self._r = releases; self.fetched = None
    def search(self, query, indexer_ids=None, categories=None): return self._r
    def fetch_torrent(self, url): self.fetched = url; return b"torrentbytes"


class FakeTransmission:
    def __init__(self): self.added = None
    def add_torrent(self, data, download_dir): self.added = (data, download_dir); return "hash9"


def _client(tmp_path, releases):
    cfg = SimpleNamespace(downloads_dir="/dl", media_root="/tank/media")
    pl = FakeProwlarr(releases)
    tr = FakeTransmission()
    store = ReviewStore(tmp_path / "r.db")
    app = create_app(cfg, pl, tr, store)
    return TestClient(app), pl, tr, store


def test_search_returns_rows_and_filters_by_resolution(tmp_path):
    releases = [
        _release("A.Movie.2024.2160p.WEB-DL-X"),
        _release("B.Movie.2024.1080p.WEB-DL-Y"),
    ]
    client, *_ = _client(tmp_path, releases)
    r = client.get("/api/search", params={"q": "movie"})
    assert r.status_code == 200
    assert "A.Movie" in r.text and "B.Movie" in r.text
    r2 = client.get("/api/search", params={"q": "movie", "resolution": "2160p"})
    assert "A.Movie" in r2.text and "B.Movie" not in r2.text


def test_grab_fetches_and_adds(tmp_path):
    client, pl, tr, _ = _client(tmp_path, [])
    r = client.post("/api/grab", data={"downloadUrl": "http://pl/dl?id=1", "title": "A"})
    assert r.status_code == 200
    assert pl.fetched == "http://pl/dl?id=1"
    assert tr.added == (b"torrentbytes", "/dl")


def test_review_lists_pending(tmp_path):
    client, _, _, store = _client(tmp_path, [])
    store.add("h", "Pending.Thing", "/dl/Pending.Thing", "tv", "/tank/media/tv/X", "why")
    r = client.get("/review")
    assert r.status_code == 200
    assert "Pending.Thing" in r.text
