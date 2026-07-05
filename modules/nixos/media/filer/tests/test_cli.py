from pathlib import Path

from media_filer import cli


def test_drain_processes_and_deletes_jobs(tmp_path, monkeypatch):
    queue = tmp_path / "q"
    queue.mkdir()
    job = queue / "abc.job"
    job.write_text("TR_TORRENT_DIR=/dl\nTR_TORRENT_NAME=Movie.2020\nTR_TORRENT_LABELS=\n")

    seen = []
    monkeypatch.setattr(cli.filer, "process_job", lambda env, **k: seen.append(env) or [])

    cli.main([str(queue)])

    assert seen and seen[0]["TR_TORRENT_NAME"] == "Movie.2020"
    assert not job.exists()  # job removed after handling


def test_bad_job_is_removed_not_fatal(tmp_path, monkeypatch):
    queue = tmp_path / "q"
    queue.mkdir()
    (queue / "bad.job").write_text("TR_TORRENT_NAME=x\n")

    def boom(env, **k):
        raise RuntimeError("kaboom")

    monkeypatch.setattr(cli.filer, "process_job", boom)
    cli.main([str(queue)])  # must not raise
    assert not (queue / "bad.job").exists()
