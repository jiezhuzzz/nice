# tests/test_prowlarr.py
import httpx
import respx
from mediahub.prowlarr import ProwlarrClient, Release


@respx.mock
def test_search_parses_releases():
    payload = [{
        "title": "Some.Movie.2024.1080p.WEB-DL-GRP",
        "size": 12345, "seeders": 42, "indexer": "M-Team",
        "categories": [{"id": 2000, "name": "Movies"}],
        "downloadUrl": "http://pl/dl?id=1", "guid": "g1",
        "publishDate": "2024-01-01T00:00:00Z", "infoUrl": "http://pl/info/1",
    }]
    respx.get("http://pl/api/v1/search").mock(
        return_value=httpx.Response(200, json=payload)
    )
    c = ProwlarrClient("http://pl", "KEY")
    rels = c.search("some movie")
    assert len(rels) == 1
    r = rels[0]
    assert isinstance(r, Release)
    assert r.seeders == 42
    assert r.categories == [2000]
    assert r.download_url == "http://pl/dl?id=1"


@respx.mock
def test_fetch_torrent_returns_bytes():
    respx.get("http://pl/dl").mock(return_value=httpx.Response(200, content=b"d8:announce"))
    c = ProwlarrClient("http://pl", "KEY")
    assert c.fetch_torrent("http://pl/dl") == b"d8:announce"
