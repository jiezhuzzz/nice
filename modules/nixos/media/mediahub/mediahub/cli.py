# mediahub/cli.py
from __future__ import annotations
import os

from .config import Config
from .store import ReviewStore
from .prowlarr import ProwlarrClient
from .transmission import TransmissionClient


def web() -> None:
    """Entry point: `mediahub-web`. Serves the FastAPI app with uvicorn."""
    import uvicorn
    from .web import create_app

    cfg = Config.from_env()
    app = create_app(
        cfg,
        ProwlarrClient(cfg.prowlarr_url, cfg.prowlarr_api_key),
        TransmissionClient(cfg.transmission_rpc_url),
        ReviewStore(cfg.db_path),
    )
    uvicorn.run(app, host=os.environ.get("MEDIAHUB_HOST", "127.0.0.1"),
                port=int(os.environ.get("MEDIAHUB_PORT", "8083")))


def file_done() -> None:
    """Entry point: `mediahub-file`. Invoked by Transmission's script-torrent-done
    (as the transmission user) with TR_TORRENT_* env vars set."""
    from .filer import file_torrent

    cfg = Config.from_env()
    torrent_dir = os.path.join(
        os.environ["TR_TORRENT_DIR"], os.environ["TR_TORRENT_NAME"]
    )
    name = os.environ["TR_TORRENT_NAME"]
    thash = os.environ.get("TR_TORRENT_HASH", "")
    status = file_torrent(torrent_dir, name, thash, cfg.media_root, ReviewStore(cfg.db_path))
    print(f"mediahub-file: {name} -> {status}")
