from media_filer import trackers
from media_filer.parse import Candidate


def test_tracker_for_hdsky_announce():
    env = "https://pt.hdsky.me/announce?passkey=SECRET"
    assert trackers.tracker_for(env) == "hdsky"


def test_tracker_for_multi_tracker_list_finds_known():
    env = "http://open.tracker.example/announce, https://pt.hdsky.me/announce?passkey=X"
    assert trackers.tracker_for(env) == "hdsky"


def test_tracker_for_unknown_host():
    assert trackers.tracker_for("https://tracker.example.org/announce") is None


def test_tracker_for_empty():
    assert trackers.tracker_for("") is None


def test_hdsky_movie():
    name = "满江红.Full.River.Red.2023.2160p.WEB-DL.H265.DDP5.1@HDSky"
    assert trackers.release("hdsky", name) == Candidate(
        type="movie", title="Full River Red", year=2023, season=None, episode=None
    )


def test_hdsky_tv_episode():
    name = "狂飙.The.Knockout.S01.E05.2023.1080p.WEB-DL.H264.AAC@HDSky"
    assert trackers.release("hdsky", name) == Candidate(
        type="episode", title="The Knockout", year=None, season=1, episode=5
    )


def test_hdsky_tv_season_pack_dir_has_no_episode():
    name = "狂飙.The.Knockout.S01.2023.1080p.WEB-DL.H264.AAC@HDSky"
    assert trackers.release("hdsky", name) == Candidate(
        type="episode", title="The Knockout", year=None, season=1, episode=None
    )


def test_hdsky_release_non_matching_returns_none():
    assert trackers.release("hdsky", "just-a-weird-name") is None


def test_release_unknown_tracker_returns_none():
    assert trackers.release("nope", "anything") is None


def test_hdsky_movie_with_number_in_title():
    name = "满江红.Blade.Runner.2049.2017.1080p.WEB-DL@HDSky"
    assert trackers.release("hdsky", name) == Candidate(
        type="movie", title="Blade Runner 2049", year=2017, season=None, episode=None
    )
