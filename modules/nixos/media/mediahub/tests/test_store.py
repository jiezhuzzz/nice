# tests/test_store.py
from mediahub.store import ReviewStore


def test_add_and_list(tmp_path):
    s = ReviewStore(tmp_path / "r.db")
    rid = s.add("hash1", "Some.Release", "/dl/Some.Release", "movie",
                "/tank/media/movies/Some (2024)", "unknown year")
    assert isinstance(rid, int)
    pending = s.list_pending()
    assert len(pending) == 1
    assert pending[0].hash == "hash1"
    assert pending[0].suggested_kind == "movie"
    assert pending[0].status == "pending"


def test_get_and_mark_done(tmp_path):
    s = ReviewStore(tmp_path / "r.db")
    rid = s.add("h", "n", "/dl/n", None, None, "reason")
    item = s.get(rid)
    assert item.name == "n"
    s.mark_done(rid)
    assert s.list_pending() == []
    assert s.get(rid).status == "done"
