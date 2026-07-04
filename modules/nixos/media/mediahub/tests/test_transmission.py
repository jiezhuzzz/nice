# tests/test_transmission.py
import httpx
import respx
from mediahub.transmission import TransmissionClient


@respx.mock
def test_add_torrent_negotiates_session_and_returns_hash():
    calls = {"n": 0}

    def responder(request):
        calls["n"] += 1
        if calls["n"] == 1:
            return httpx.Response(409, headers={"X-Transmission-Session-Id": "SID"})
        assert request.headers["X-Transmission-Session-Id"] == "SID"
        return httpx.Response(200, json={
            "result": "success",
            "arguments": {"torrent-added": {"hashString": "abc"}},
        })

    respx.post("http://tr/rpc").mock(side_effect=responder)
    c = TransmissionClient("http://tr/rpc")
    h = c.add_torrent(b"torrentbytes", "/tank/media/downloads")
    assert h == "abc"
    assert calls["n"] == 2
