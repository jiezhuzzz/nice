# mediahub/prowlarr.py
from __future__ import annotations
from dataclasses import dataclass

import httpx


@dataclass
class Release:
    title: str
    size: int
    seeders: int
    indexer: str
    categories: list[int]
    download_url: str
    guid: str
    publish_date: str | None
    info_url: str | None


def _cat_ids(cats) -> list[int]:
    out = []
    for c in cats or []:
        cid = c.get("id") if isinstance(c, dict) else c
        if cid is not None:
            out.append(int(cid))
    return out


class ProwlarrClient:
    def __init__(self, base_url: str, api_key: str, client: httpx.Client | None = None):
        self.base_url = base_url.rstrip("/")
        self.api_key = api_key
        self.client = client or httpx.Client(timeout=30)

    def _headers(self):
        return {"X-Api-Key": self.api_key}

    def search(self, query, indexer_ids=None, categories=None) -> list[Release]:
        params: dict = {"query": query}
        if indexer_ids:
            params["indexerIds"] = indexer_ids
        if categories:
            params["categories"] = categories
        r = self.client.get(
            f"{self.base_url}/api/v1/search", params=params, headers=self._headers()
        )
        r.raise_for_status()
        return [
            Release(
                title=x.get("title", ""),
                size=int(x.get("size", 0) or 0),
                seeders=int(x.get("seeders", 0) or 0),
                indexer=x.get("indexer", ""),
                categories=_cat_ids(x.get("categories")),
                download_url=x.get("downloadUrl", ""),
                guid=x.get("guid", ""),
                publish_date=x.get("publishDate"),
                info_url=x.get("infoUrl"),
            )
            for x in r.json()
        ]

    def fetch_torrent(self, download_url: str) -> bytes:
        r = self.client.get(download_url, headers=self._headers())
        r.raise_for_status()
        return r.content
