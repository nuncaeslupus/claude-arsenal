"""F10 security: sideloaded access, debugging, VPN, boot state, patch age, user CAs."""

from __future__ import annotations


def _security(built, cli, scenarios, **kw):
    code, doc, _ = cli(
        "analyze_bugreport",
        "--input",
        str(built("modern", scenarios, **kw)),
        "--family",
        "security",
    )
    assert code == 0 and doc["not_parsed"] == []
    return doc


def test_sideloaded_app_with_accessibility_fires_high(built, cli):
    (f,) = _security(built, cli, ("sideloaded",))["findings"]
    assert f["id"] == "security.sideloaded_with_access" and f["severity"] == "high"
    assert f["facts"] == {
        "installer": "com.google.android.packageinstaller",
        "access": ["accessibility", "overlay"],
    }
    assert f["subjects"] == [{"package": "com.example.app", "role": "cause"}]


def test_store_installed_app_does_not_fire(built, cli):
    doc = _security(built, cli, ())
    assert doc["findings"] == []
    view = doc["views"]["security"]
    assert view["access"]["com.example.app"] == ["accessibility", "overlay"]
    assert view["access"]["com.example.notes"] == ["install_packages"]  # F-Droid is a store
    assert view["sideloaded"] == []


def test_patch_age_uses_report_date_not_today(built, cli):
    assert _security(built, cli, ())["views"]["security"]["patch_age_days"] == 29
    (f,) = _security(built, cli, ("old-patch",))["findings"]
    assert f["facts"] == {"security_patch": "2025-06-05", "patch_age_days": 516}
    assert f["severity"] == "medium"


def test_sideloaded_vpn_app_is_medium(built, cli):
    ids = {
        f["id"]: f["severity"]
        for f in _security(built, cli, ("sideloaded", "always-on-vpn"))["findings"]
    }
    assert ids["security.always_on_vpn"] == "medium"


def test_user_ca_member_fires_on_zip_only(built, cli):
    (f,) = _security(built, cli, ("user-ca",), container="zip")["findings"]
    assert f["id"] == "security.user_ca" and f["facts"] == {"user_ca_certs": 1}
    assert _security(built, cli, ("user-ca",))["findings"] == []
