from pathlib import Path

import pytest

from media_filer import filer
from media_filer.agent import AgentResult
from media_filer.hardlink import LinkConflict


@pytest.fixture(autouse=True)
def _low_threshold(monkeypatch):
    # Production threshold is 100MB; shrink it so tests use tiny files instead
    # of writing hundreds of MB to tmp.
    monkeypatch.setattr(filer, "MIN_VIDEO_BYTES", 100)


def _job(dir_, name, labels=""):
    return {"TR_TORRENT_DIR": str(dir_), "TR_TORRENT_NAME": name, "TR_TORRENT_LABELS": labels}


def _mk(path: Path, size: int = 4096):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"\0" * size)


def never_agent(*a, **k):
    raise AssertionError("agent should not be called for a confident release")


def test_movie_deterministic(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "The.Matrix.1999.1080p.BluRay.x264-GRP"
    _mk(src / "the.matrix.1999.1080p.mkv", 8192)   # feature (largest)
    _mk(src / "the.matrix.1999.sample.mkv", 4096)  # sample by name -> ignored
    results = filer.process_job(_job(dl, src.name), root=root, classify=never_agent)
    dest = root / "movies" / "The Matrix (1999)" / "The Matrix (1999).mkv"
    assert dest.exists()
    assert any(r.action == "linked" for r in results)


def test_small_sample_excluded_by_size(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "The.Matrix.1999.1080p.BluRay-GRP"
    _mk(src / "the.matrix.1999.mkv", 8192)  # real feature
    _mk(src / "junk.mkv", 10)               # below threshold -> ignored
    filer.process_job(_job(dl, src.name), root=root, classify=never_agent)
    assert (root / "movies" / "The Matrix (1999)" / "The Matrix (1999).mkv").exists()


def test_season_pack_deterministic(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "Severance.S02.1080p.WEB-DL-GRP"
    _mk(src / "Severance.S02E01.1080p.mkv")
    _mk(src / "Severance.S02E02.1080p.mkv")
    filer.process_job(_job(dl, src.name), root=root, classify=never_agent)
    tv = root / "tv" / "Severance" / "Season 02"
    assert (tv / "Severance - S02E01.mkv").exists()
    assert (tv / "Severance - S02E02.mkv").exists()


def test_cjk_uses_agent(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "基督山伯爵.2024.1080p.WEB-DL"
    _mk(src / "基督山伯爵.2024.1080p.mkv", 8192)

    def stub(name, files, **k):
        return AgentResult("movie", "The Count of Monte Cristo", 2024, None, None, True)

    filer.process_job(_job(dl, src.name), root=root, classify=stub)
    assert (root / "movies" / "The Count of Monte Cristo (2024)"
            / "The Count of Monte Cristo (2024).mkv").exists()


def test_label_forces_anime(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "Frieren.S01E05.1080p-GRP"
    _mk(src / "Frieren.S01E05.1080p.mkv")
    filer.process_job(_job(dl, src.name, labels="anime"), root=root, classify=never_agent)
    assert (root / "anime" / "Frieren" / "Season 01" / "Frieren - S01E05.mkv").exists()


def test_agent_unsure_leaves_unfiled(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "未知资源.XYZ"
    _mk(src / "未知资源.mkv", 8192)

    def unsure(name, files, **k):
        return AgentResult("unknown", None, None, None, None, False)

    results = filer.process_job(_job(dl, src.name), root=root, classify=unsure)
    assert results and all(r.action == "unfiled" for r in results)
    assert not list(root.rglob("*.mkv"))


def test_no_video_files_unfiled(tmp_path):
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "Some.Artist.Discography.FLAC"
    _mk(src / "01.track.flac")  # not a video extension
    results = filer.process_job(_job(dl, src.name), root=root, classify=never_agent)
    assert results and all(r.action == "unfiled" for r in results)


def test_anime_absolute_episode(tmp_path):
    # agent resolves anime; file uses absolute numbering (no season) -> anime/Show/Show - N.ext
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "[SubsPlease] One Piece - 1071 (1080p)"
    _mk(src / "[SubsPlease] One Piece - 1071 (1080p).mkv", 8192)

    def stub(name, files, **k):
        return AgentResult("anime", "One Piece", None, None, None, True)

    filer.process_job(_job(dl, src.name), root=root, classify=stub)
    assert (root / "anime" / "One Piece" / "One Piece - 1071.mkv").exists()


def test_partial_unfiled_in_batch(tmp_path):
    # one good episode links; a file with no episode number is left unfiled
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "Severance.S02.1080p.WEB-DL-GRP"
    _mk(src / "Severance.S02E01.1080p.mkv")
    _mk(src / "Severance.Recap.Special.mkv")
    results = filer.process_job(_job(dl, src.name), root=root, classify=never_agent)
    assert (root / "tv" / "Severance" / "Season 02" / "Severance - S02E01.mkv").exists()
    assert any(r.action == "unfiled" for r in results)


def test_link_conflict_reported(tmp_path):
    # a LinkConflict from the linker surfaces as Result(action="conflict"), not a crash
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "The.Matrix.1999.1080p-GRP"
    _mk(src / "the.matrix.1999.mkv", 8192)

    def boom(s, d):
        raise LinkConflict("boom")

    results = filer.process_job(_job(dl, src.name), root=root, classify=never_agent, link=boom)
    assert any(r.action == "conflict" for r in results)


def test_movie_without_year_unfiled(tmp_path):
    # a confident-movie decision with no year must NOT build a "Title (None)" path
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "Some.Mystery.Movie.1080p-GRP"
    _mk(src / "some.mystery.movie.1080p.mkv", 8192)

    def stub(name, files, **k):
        return AgentResult("movie", "Some Mystery Movie", None, None, None, True)

    results = filer.process_job(_job(dl, src.name), root=root, classify=stub)
    assert results and all(r.action == "unfiled" for r in results)
    assert not list(root.rglob("*.mkv"))


def test_link_oserror_reported_not_crash(tmp_path):
    # a real os.link failure (e.g. EPERM from protected_hardlinks) surfaces as
    # Result(action="error") and never crashes the drain
    root = tmp_path / "media"
    dl = tmp_path / "dl"
    src = dl / "The.Matrix.1999.1080p-GRP"
    _mk(src / "the.matrix.1999.mkv", 8192)

    def boom(s, d):
        raise PermissionError(1, "Operation not permitted")

    results = filer.process_job(_job(dl, src.name), root=root, classify=never_agent, link=boom)
    assert any(r.action == "error" for r in results)
