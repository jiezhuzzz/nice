# tests/test_filer.py
from mediahub.filer import file_torrent, build_prompt
from mediahub.store import ReviewStore


def test_linked_result_no_review_row(tmp_path):
    store = ReviewStore(tmp_path / "r.db")
    agent = lambda prompt, cwd, env: "did work\nRESULT: linked 3\n"
    status = file_torrent("/dl/Foo", "Foo", "h1", "/tank/media", store, agent=agent)
    assert status == "linked"
    assert store.list_pending() == []


def test_review_result_creates_row_with_suggestion(tmp_path):
    store = ReviewStore(tmp_path / "r.db")
    out = "KIND: tv\nDEST: /tank/media/tv/Foo\nRESULT: review unknown season\n"
    agent = lambda prompt, cwd, env: out
    status = file_torrent("/dl/Foo", "Foo", "h2", "/tank/media", store, agent=agent)
    assert status == "review"
    p = store.list_pending()
    assert len(p) == 1
    assert p[0].suggested_kind == "tv"
    assert p[0].suggested_dest == "/tank/media/tv/Foo"
    assert "unknown season" in p[0].reason


def test_agent_error_enqueues_review(tmp_path):
    store = ReviewStore(tmp_path / "r.db")
    def boom(prompt, cwd, env):
        raise RuntimeError("claude exited 1")
    status = file_torrent("/dl/Foo", "Foo", "h3", "/tank/media", store, agent=boom)
    assert status == "review"
    assert "claude exited 1" in store.list_pending()[0].reason


def test_no_result_line_enqueues_review(tmp_path):
    store = ReviewStore(tmp_path / "r.db")
    agent = lambda prompt, cwd, env: "rambled but no verdict"
    status = file_torrent("/dl/Foo", "Foo", "h4", "/tank/media", store, agent=agent)
    assert status == "review"


def test_prompt_mentions_hardlink_only(tmp_path):
    p = build_prompt("/dl/Foo", "/tank/media")
    assert "/dl/Foo" in p and "/tank/media" in p
    assert "ln" in p and "never" in p.lower()


def test_dry_run_prompt_says_do_not_execute():
    p = build_prompt("/dl/Foo", "/tank/media", dry_run=True)
    assert "do not execute" in p.lower()
