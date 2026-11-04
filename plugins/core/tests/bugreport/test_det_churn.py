"""Churn: a package killed and restarted again and again is a restart loop."""

from __future__ import annotations


def test_restart_loop_names_the_restarted_package(built, cli):
    path = str(built("modern", ("churn",)))
    code, doc, _ = cli("analyze_bugreport", "--input", path, "--family", "churn")
    assert code == 0
    (f,) = [f for f in doc["findings"] if f["id"] == "memory.restart_loop"]
    assert f["subjects"] == [{"package": "com.example.heavy", "role": "cause"}]
    assert f["facts"] == {"restarts": 4, "start_reason": "service"}
    assert doc["views"]["churn"]["restarts"][0]["package"] == "com.example.heavy"
