# mediahub/transmission.py
from __future__ import annotations
import base64

import httpx


class TransmissionClient:
    def __init__(self, rpc_url: str, client: httpx.Client | None = None):
        self.rpc_url = rpc_url
        self.client = client or httpx.Client(timeout=30)
        self._sid = ""

    def _rpc(self, method: str, arguments: dict) -> dict:
        for _ in range(2):
            r = self.client.post(
                self.rpc_url,
                json={"method": method, "arguments": arguments},
                headers={"X-Transmission-Session-Id": self._sid},
            )
            if r.status_code == 409:
                self._sid = r.headers.get("X-Transmission-Session-Id", "")
                continue
            r.raise_for_status()
            return r.json()
        raise RuntimeError("transmission session negotiation failed")

    def add_torrent(self, torrent_bytes: bytes, download_dir: str) -> str:
        res = self._rpc("torrent-add", {
            "metainfo": base64.b64encode(torrent_bytes).decode(),
            "download-dir": download_dir,
        })
        args = res.get("arguments", {})
        t = args.get("torrent-added") or args.get("torrent-duplicate")
        if not t:
            raise RuntimeError(f"torrent-add failed: {res}")
        return t["hashString"]

    def get_torrent(self, hash: str) -> dict | None:
        res = self._rpc("torrent-get", {
            "ids": [hash],
            "fields": ["hashString", "downloadDir", "name", "files"],
        })
        torrents = res.get("arguments", {}).get("torrents", [])
        return torrents[0] if torrents else None
