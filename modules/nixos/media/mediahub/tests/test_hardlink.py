# tests/test_hardlink.py
import os
from pathlib import Path
import pytest
from mediahub.hardlink import media_files, hardlink


def test_media_files_filters(tmp_path):
    (tmp_path / "a.mkv").write_text("x")
    (tmp_path / "b.nfo").write_text("x")
    sub = tmp_path / "extras"; sub.mkdir()
    (sub / "c.mp4").write_text("x")
    names = {p.name for p in media_files(tmp_path)}
    assert names == {"a.mkv", "c.mp4"}


def test_hardlink_creates_second_link(tmp_path):
    src = tmp_path / "a.mkv"; src.write_text("data")
    dest = tmp_path / "lib" / "a.mkv"
    assert hardlink(src, dest) is True
    assert dest.exists()
    assert os.stat(dest).st_nlink == 2
    assert os.stat(src).st_ino == os.stat(dest).st_ino


def test_hardlink_idempotent(tmp_path):
    src = tmp_path / "a.mkv"; src.write_text("data")
    dest = tmp_path / "lib" / "a.mkv"
    hardlink(src, dest)
    assert hardlink(src, dest) is False  # already linked, no error


def test_hardlink_collision_raises(tmp_path):
    src = tmp_path / "a.mkv"; src.write_text("data")
    dest = tmp_path / "lib" / "a.mkv"; dest.parent.mkdir(parents=True)
    dest.write_text("different")
    with pytest.raises(FileExistsError):
        hardlink(src, dest)
