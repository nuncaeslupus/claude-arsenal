"""F4 ANR: blame the system when it is thrashing, the app's main thread when it is not."""

from __future__ import annotations


def test_input_dispatch_anr_under_pressure_marks_victim(built, cli):
    code, doc, _ = cli(
        "analyze_bugreport", "--input", str(built("modern", ("thrashing",))), "--family", "anr"
    )
    assert code == 0
    (f,) = doc["findings"]
    assert f["id"] == "anr.under_pressure"
    assert {(s["package"], s["role"]) for s in f["subjects"]} == {
        ("com.example.app", "victim"),
        ("com.android.phone", "victim"),
    }
    assert {a["kind"] for a in doc["views"]["anr"]["anrs"]} == {"input_dispatch"}


def test_anr_with_idle_system_blames_main_thread(built, cli):
    code, doc, _ = cli(
        "analyze_bugreport", "--input", str(built("modern", ("anr-idle",))), "--family", "anr"
    )
    assert code == 0
    (f,) = doc["findings"]
    assert f["id"] == "anr.main_thread"
    assert f["subjects"] == [{"package": "com.example.app", "pid": 4321, "role": "cause"}]
    assert f["facts"]["main_thread_state"] == "Blocked"
