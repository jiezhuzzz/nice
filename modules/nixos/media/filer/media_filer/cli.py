"""Entry point: drain a queue directory of .job files."""
from __future__ import annotations

import logging
import sys
from pathlib import Path

from . import filer


def _parse_job(text: str) -> dict:
    env = {}
    for line in text.splitlines():
        if "=" in line:
            key, _, value = line.partition("=")
            env[key.strip()] = value
    return env


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    argv = list(sys.argv[1:] if argv is None else argv)
    queue = Path(argv[0]) if argv else Path("/tank/media/downloads/.filer-queue")

    for job in sorted(queue.glob("*.job")):
        try:
            env = _parse_job(job.read_text())
            if env.get("TR_TORRENT_NAME") and env.get("TR_TORRENT_DIR"):
                filer.process_job(env)
        except Exception:  # never let one job wedge the queue
            logging.exception("failed handling %s", job.name)
        finally:
            job.unlink(missing_ok=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
