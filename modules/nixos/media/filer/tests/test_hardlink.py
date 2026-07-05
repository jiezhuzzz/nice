import pytest

from media_filer.hardlink import hardlink, LinkConflict


def test_links_new_file(tmp_path):
    src = tmp_path / "src.mkv"
    src.write_text("data")
    dest = tmp_path / "lib" / "movie" / "m.mkv"
    assert hardlink(src, dest) == "linked"
    assert dest.exists()
    assert dest.samefile(src)


def test_second_link_is_idempotent(tmp_path):
    src = tmp_path / "src.mkv"
    src.write_text("data")
    dest = tmp_path / "m.mkv"
    hardlink(src, dest)
    assert hardlink(src, dest) == "exists"


def test_conflicting_dest_raises(tmp_path):
    src = tmp_path / "src.mkv"
    src.write_text("data")
    other = tmp_path / "other.mkv"
    other.write_text("different")
    dest = tmp_path / "m.mkv"
    hardlink(other, dest)  # dest now points at `other`
    with pytest.raises(LinkConflict):
        hardlink(src, dest)
