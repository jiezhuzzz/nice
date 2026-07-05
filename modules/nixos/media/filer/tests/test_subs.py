from pathlib import Path

from media_filer import subs


def test_find_subtitles_siblings_and_subfolder(tmp_path):
    (tmp_path / "movie.mkv").write_text("v")
    (tmp_path / "movie.en.srt").write_text("s")
    (tmp_path / "Subs").mkdir()
    (tmp_path / "Subs" / "French.srt").write_text("s")
    (tmp_path / "sample.srt").write_text("s")  # sample -> excluded
    found = {p.name for p in subs.find_subtitles(tmp_path)}
    assert found == {"movie.en.srt", "French.srt"}


def test_language_tail_from_code():
    assert subs.language_tail("The.Matrix.1999.en.srt") == ".en"


def test_language_tail_word_and_flag():
    assert subs.language_tail("The.Matrix.1999.eng.forced.srt") == ".en.forced"


def test_language_tail_none():
    assert subs.language_tail("The.Matrix.1999.srt") == ""


def test_matches_episode_exact():
    assert subs.matches_episode(Path("Show.S02E01.en.srt"), 2, 1) is True


def test_matches_episode_season_fallback():
    assert subs.matches_episode(Path("Show.E01.srt"), 2, 1) is True


def test_matches_episode_wrong_season():
    assert subs.matches_episode(Path("Show.S03E01.srt"), 2, 1) is False


def test_matches_episode_none():
    assert subs.matches_episode(Path("English.srt"), 2, 1) is False


def test_subtitle_dest_and_collision():
    vdest = Path("/lib/movies/The Matrix (1999)/The Matrix (1999).mkv")
    taken = set()
    d1 = subs.subtitle_dest(vdest, Path("The.Matrix.1999.en.srt"), taken)
    taken.add(d1)
    d2 = subs.subtitle_dest(vdest, Path("2_English.srt"), taken)
    taken.add(d2)
    assert d1.name == "The Matrix (1999).en.srt"
    assert d2.name == "The Matrix (1999).en.2.srt"


def test_subtitle_dest_no_language():
    vdest = Path("/lib/tv/Show/Season 02/Show - S02E01.mkv")
    d = subs.subtitle_dest(vdest, Path("Show.S02E01.srt"), set())
    assert d.name == "Show - S02E01.srt"


def test_vobsub_idx_sub_no_collision():
    vdest = Path("/lib/movies/M (2020)/M (2020).mkv")
    taken = set()
    d1 = subs.subtitle_dest(vdest, Path("m.en.idx"), taken)
    taken.add(d1)
    d2 = subs.subtitle_dest(vdest, Path("m.en.sub"), taken)
    taken.add(d2)
    assert d1.name == "M (2020).en.idx"
    assert d2.name == "M (2020).en.sub"  # different ext -> no collision
