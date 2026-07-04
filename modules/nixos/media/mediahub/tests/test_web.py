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


def _client_with_root(tmp_path, media_root):
    cfg = SimpleNamespace(downloads_dir="/dl", media_root=str(media_root))
    store = ReviewStore(tmp_path / "r.db")
    app = create_app(cfg, FakeProwlarr([]), FakeTransmission(), store)
    return TestClient(app), store


def test_place_hardlinks_and_marks_done(tmp_path):
    import os
    media_root = tmp_path / "lib"; media_root.mkdir()
    src = tmp_path / "dl" / "Show"; src.mkdir(parents=True)
    (src / "ep.mkv").write_text("data")
    client, store = _client_with_root(tmp_path, media_root)
    rid = store.add("h", "Show", str(src), "tv", "", "why")
    dest = media_root / "tv" / "Show"
    r = client.post("/api/place", data={"id": rid, "dest": str(dest)},
                    follow_redirects=False)
    assert r.status_code == 303
    linked = dest / "ep.mkv"
    assert linked.exists() and os.stat(linked).st_nlink == 2
    assert store.get(rid).status == "done"


def test_place_rejects_dest_outside_media_root(tmp_path):
    media_root = tmp_path / "lib"; media_root.mkdir()
    src = tmp_path / "dl" / "Show"; src.mkdir(parents=True)
    client, store = _client_with_root(tmp_path, media_root)
    rid = store.add("h", "Show", str(src), None, None, "why")
    r = client.post("/api/place", data={"id": rid, "dest": "/etc/evil"},
                    follow_redirects=False)
    assert r.status_code == 400
    assert store.get(rid).status == "pending"


def test_search_filters_by_hdr_and_codec(tmp_path):
    releases = [
        _release("A.2024.2160p.WEB-DL.H265.HDR.DV-X"),
        _release("B.2024.1080p.WEB-DL.H264-Y"),
    ]
    client, *_ = _client(tmp_path, releases)
    assert "A.2024" in client.get("/api/search", params={"q": "x", "codec": "H.265"}).text
    r2 = client.get("/api/search", params={"q": "x", "codec": "H.265"})
    assert "B.2024" not in r2.text
    r3 = client.get("/api/search", params={"q": "x", "hdr": "DV"})
    assert "A.2024" in r3.text and "B.2024" not in r3.text


def test_search_min_size_and_sort_by_size(tmp_path):
    big = _release("Big.2024.2160p.WEB-DL-X"); big.size = 30 * 1024 ** 3
    small = _release("Small.2024.1080p.WEB-DL-Y"); small.size = 2 * 1024 ** 3
    client, *_ = _client(tmp_path, [small, big])
    r = client.get("/api/search", params={"q": "x", "min_size_gb": 10})
    assert "Big.2024" in r.text and "Small.2024" not in r.text
    r2 = client.get("/api/search", params={"q": "x", "sort": "size", "order": "desc"})
    assert r2.text.index("Big.2024") < r2.text.index("Small.2024")


def test_search_filters_by_category_and_site(tmp_path):
    m = _release("Movie.2024.1080p-X")  # _release sets categories=[2000], indexer="M-Team"
    client, *_ = _client(tmp_path, [m])
    assert "Movie.2024" in client.get("/api/search", params={"q": "x", "category": "movies"}).text
    assert "Movie.2024" not in client.get("/api/search", params={"q": "x", "category": "tv"}).text
    assert "Movie.2024" in client.get("/api/search", params={"q": "x", "site": "team"}).text
    assert "Movie.2024" not in client.get("/api/search", params={"q": "x", "site": "hdsky"}).text


def test_search_tolerates_empty_numeric_filters(tmp_path):
    # htmx submits every field, so empty numeric boxes arrive as "" — FastAPI's
    # int/float coercion 422'd on those (the live "no response" bug). Must be 200.
    client, *_ = _client(tmp_path, [_release("Batman.Begins.2005.2160p.BluRay-X")])
    r = client.get("/api/search", params={
        "q": "batman", "resolution": "", "source": "", "codec": "", "hdr": "",
        "audio": "", "group": "", "site": "", "category": "",
        "min_seeders": "", "min_size_gb": "", "sort": "seeders", "order": "desc",
    })
    assert r.status_code == 200
    assert "Batman.Begins" in r.text
