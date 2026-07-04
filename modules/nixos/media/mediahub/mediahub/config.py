# mediahub/config.py
from __future__ import annotations
import os
from dataclasses import dataclass


@dataclass
class Config:
    prowlarr_url: str
    prowlarr_api_key: str
    transmission_rpc_url: str
    media_root: str
    downloads_dir: str
    db_path: str

    @classmethod
    def from_env(cls) -> "Config":
        return cls(
            prowlarr_url=os.environ.get("PROWLARR_URL", "http://127.0.0.1:9696"),
            prowlarr_api_key=os.environ.get("PROWLARR_API_KEY", ""),
            transmission_rpc_url=os.environ.get(
                "TRANSMISSION_RPC_URL", "http://127.0.0.1:9091/transmission/rpc"
            ),
            media_root=os.environ.get("MEDIA_ROOT", "/tank/media"),
            downloads_dir=os.environ.get("DOWNLOADS_DIR", "/tank/media/downloads"),
            db_path=os.environ.get("MEDIAHUB_DB", "/var/lib/mediahub/review.db"),
        )
