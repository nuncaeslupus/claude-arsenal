"""F3 reboots: a battery shutdown and a watchdog kill each fire; a user reboot does not."""

from __future__ import annotations


def _reboots(built, cli, scenarios):
    code, doc, _ = cli(
        "analyze_bugreport", "--input", str(built("modern", scenarios)), "--family", "reboots"
    )
    assert code == 0 and doc["not_parsed"] == []
    return doc


def test_shutdown_battery_reason_fires_reboot_finding(built, cli):
    (f,) = _reboots(built, cli, ("battery-shutdown",))["findings"]
    assert f["id"] == "reboots.battery_shutdown"
    assert f["facts"] == {"last_boot_reason": "shutdown,battery"}


def test_watchdog_kill_names_blocked_thread(built, cli):
    (f,) = _reboots(built, cli, ("watchdog",))["findings"]
    assert f["id"] == "reboots.watchdog" and f["severity"] == "critical"
    assert f["subjects"] == [{"thread": "android.fg", "role": "cause"}]


def test_ordinary_reboot_fires_nothing(built, cli):
    doc = _reboots(built, cli, ())
    assert doc["findings"] == []
    assert doc["views"]["reboots"]["boot_reasons"]["sys.boot.reason.last"] == "reboot,ota"
