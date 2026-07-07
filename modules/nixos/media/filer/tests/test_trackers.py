from media_filer import trackers


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
