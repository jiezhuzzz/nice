from media_filer.parse import parse_name, confident, is_cjk


def test_movie_is_confident():
    c = parse_name("The.Matrix.1999.1080p.BluRay.x264-GROUP")
    assert c.type == "movie"
    assert c.title == "The Matrix"
    assert c.year == 1999
    assert confident(c) is True


def test_single_episode_is_confident():
    c = parse_name("Severance.S02E03.1080p.WEB-DL.DDP5.1.H264-GRP")
    assert c.type == "episode"
    assert c.title == "Severance"
    assert c.season == 2
    assert c.episode == 3
    assert confident(c) is True


def test_season_pack_name_has_no_episode():
    c = parse_name("Severance.S02.1080p.WEB-DL-GRP")
    assert c.type == "episode"
    assert c.season == 2
    assert c.episode is None  # per-file parsing supplies episodes later


def test_cjk_title_is_not_confident():
    c = parse_name("基督山伯爵.2024.1080p")
    assert confident(c) is False


def test_multi_year_title_does_not_crash():
    # guessit returns a list for year here; _scalar must collapse it
    c = parse_name("Some.Show.2020.2021.1080p.WEB-DL-GRP")
    assert isinstance(c.year, (int, type(None)))


def test_is_cjk():
    assert is_cjk("基督山伯爵") is True
    assert is_cjk("The Matrix") is False
    assert is_cjk("Amélie") is False  # accented latin is fine


def test_season_pack_is_confident():
    # a season-pack name has a season but no episode; still routable
    c = parse_name("Severance.S02.1080p.WEB-DL-GRP")
    assert confident(c) is True
