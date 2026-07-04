# mediahub/store.py
from __future__ import annotations
import sqlite3
import time
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Review:
    id: int
    hash: str
    name: str
    src_dir: str
    suggested_kind: str | None
    suggested_dest: str | None
    reason: str
    created_at: float
    status: str


class ReviewStore:
    def __init__(self, db_path):
        self.db_path = str(db_path)
        Path(self.db_path).parent.mkdir(parents=True, exist_ok=True)
        with self._conn() as c:
            c.execute(
                """CREATE TABLE IF NOT EXISTS review(
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    hash TEXT, name TEXT, src_dir TEXT,
                    suggested_kind TEXT, suggested_dest TEXT, reason TEXT,
                    created_at REAL, status TEXT NOT NULL DEFAULT 'pending')"""
            )

    def _conn(self):
        c = sqlite3.connect(self.db_path)
        c.row_factory = sqlite3.Row
        return c

    def add(self, hash, name, src_dir, suggested_kind, suggested_dest, reason) -> int:
        with self._conn() as c:
            cur = c.execute(
                """INSERT INTO review(hash,name,src_dir,suggested_kind,
                   suggested_dest,reason,created_at,status)
                   VALUES(?,?,?,?,?,?,?,'pending')""",
                (hash, name, src_dir, suggested_kind, suggested_dest, reason, time.time()),
            )
            return cur.lastrowid

    def _row(self, r) -> Review:
        return Review(**{k: r[k] for k in r.keys()})

    def list_pending(self) -> list[Review]:
        with self._conn() as c:
            rows = c.execute(
                "SELECT * FROM review WHERE status='pending' ORDER BY created_at DESC"
            ).fetchall()
        return [self._row(r) for r in rows]

    def get(self, rid) -> Review | None:
        with self._conn() as c:
            r = c.execute("SELECT * FROM review WHERE id=?", (rid,)).fetchone()
        return self._row(r) if r else None

    def mark_done(self, rid) -> None:
        with self._conn() as c:
            c.execute("UPDATE review SET status='done' WHERE id=?", (rid,))
