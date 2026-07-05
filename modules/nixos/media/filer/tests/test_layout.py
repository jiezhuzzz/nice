from pathlib import Path

from media_filer import layout

ROOT = Path("/tank/media")


def test_movie_dest():
    d = layout.movie_dest(ROOT, "The Matrix", 1999, ".mkv")
    assert d == ROOT / "movies" / "The Matrix (1999)" / "The Matrix (1999).mkv"


def test_tv_dest():
    d = layout.tv_dest(ROOT, "Severance", 2, 3, ".mkv", anime=False)
    assert d == ROOT / "tv" / "Severance" / "Season 02" / "Severance - S02E03.mkv"


def test_anime_season_dest():
    d = layout.tv_dest(ROOT, "Frieren", 1, 5, ".mkv", anime=True)
    assert d == ROOT / "anime" / "Frieren" / "Season 01" / "Frieren - S01E05.mkv"


def test_anime_absolute_dest():
    d = layout.anime_absolute_dest(ROOT, "One Piece", 1071, ".mkv")
    assert d == ROOT / "anime" / "One Piece" / "One Piece - 1071.mkv"


def test_sanitize_strips_path_hostile_chars():
    assert layout.sanitize('A/B:C?"D') == "ABCD"


def test_is_inside_true():
    assert layout.is_inside(ROOT / "movies" / "x" / "y.mkv", ROOT) is True


def test_is_inside_rejects_escape():
    assert layout.is_inside(ROOT / ".." / "etc" / "passwd", ROOT) is False
