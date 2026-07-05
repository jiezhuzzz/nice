import json

from media_filer.agent import classify, AgentResult


def fake_runner_returning(payload):
    def _run(argv, timeout):
        # sanity: the release name must reach the CLI
        assert any("MyShow" in a for a in argv)
        return payload
    return _run


def test_parses_clean_json():
    payload = json.dumps({
        "type": "anime", "title": "My Show", "year": 2024,
        "season": 1, "episode": 5, "confident": True,
    })
    r = classify("MyShow.S01E05", ["MyShow.S01E05.mkv"],
                 runner=fake_runner_returning(payload))
    assert isinstance(r, AgentResult)
    assert r.type == "anime"
    assert r.title == "My Show"
    assert r.confident is True


def test_extracts_json_amid_prose():
    payload = 'Here is the result:\n{"type":"movie","title":"MyShow","year":1999,' \
              '"season":null,"episode":null,"confident":true}\nDone.'
    r = classify("MyShow.1999", ["MyShow.1999.mkv"],
                 runner=fake_runner_returning(payload))
    assert r.type == "movie"
    assert r.year == 1999


def test_malformed_output_is_not_confident():
    r = classify("MyShow", ["MyShow.mkv"],
                 runner=fake_runner_returning("sorry, I can't help"))
    assert r.confident is False


def test_unknown_type_is_not_confident():
    payload = json.dumps({"type": "unknown", "title": None, "year": None,
                          "season": None, "episode": None, "confident": True})
    r = classify("MyShow", ["MyShow.mkv"], runner=fake_runner_returning(payload))
    assert r.confident is False  # type unknown overrides claimed confidence


def test_forbids_all_mutating_and_task_tools():
    seen = {}

    def runner(argv, timeout):
        seen["argv"] = argv
        return '{"type":"movie","title":"X","year":2020,"season":null,"episode":null,"confident":true}'

    from media_filer.agent import classify
    classify("MyShow.X", ["MyShow.X.mkv"], runner=runner)
    idx = seen["argv"].index("--disallowedTools")
    disallowed = seen["argv"][idx + 1]
    for tool in ("Write", "Edit", "MultiEdit", "NotebookEdit", "Bash", "Task"):
        assert tool in disallowed, f"{tool} must be disallowed"
