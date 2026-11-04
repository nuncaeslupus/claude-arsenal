"""F10 security: sideloaded apps with sensitive access, debugging, boot state, patch age, user CAs.

"Sideloaded" means a non-system package whose `installerPackageName` is not an
app store. Sensitive access is read from five places: accessibility services
and notification listeners (`settings`), device admins (`device_policy`),
overlay and usage access (`appops`), and a granted `REQUEST_INSTALL_PACKAGES`
(`package`). Play Protect state is not in a bugreport's text, so it is not read.
"""

from __future__ import annotations

import datetime as dt
import re
from collections.abc import Iterator
from typing import Any

from _detectors import Context, Finding, NotParsed, detector, view

# ponytail: starting value — the installers counted as app stores; extend as reports show more
STORES = frozenset(
    {
        "com.android.vending",
        "com.amazon.venezia",
        "com.sec.android.app.samsungapps",
        "com.huawei.appmarket",
        "com.xiaomi.market",
        "com.xiaomi.mipicks",
        "com.heytap.market",
        "com.oppo.market",
        "org.fdroid.fdroid",
    }
)
PATCH_OLD_DAYS = 90  # ponytail: starting value — about one quarter of monthly bulletins missed
PATCH_STALE_DAYS = 365

_PKG = re.compile(r"^  Package \[([^\]]+)\]", re.M)
_INSTALLER = re.compile(r"^\s+installerPackageName=(\S+)", re.M)
_SETTING = re.compile(r"^_id:\d+ name:(\S+) pkg:\S+ value:(\S*)", re.M)
_ADMIN = re.compile(r"^\s+([\w.]+)/\S+:$", re.M)
_APPOP_PKG = re.compile(r"^\s+Package (\S+):$")
_APPOP = re.compile(r"^\s+(SYSTEM_ALERT_WINDOW|GET_USAGE_STATS) \(allow")
_PROP = re.compile(
    r"^\[(ro\.boot\.verifiedbootstate|ro\.boot\.vbmeta\.device_state|"
    r"ro\.build\.version\.security_patch)\]: \[(.*)\]$",
    re.M,
)


def packages(ctx: Context) -> dict[str, dict[str, Any]]:
    """Non-system packages: {name: {"installer", "install_packages", "evidence"}}."""
    sl = ctx.section("package")
    if sl is None:
        return {}
    starts = list(_PKG.finditer(sl.text))
    if not starts:
        raise NotParsed(sl.id, "no `Package [name]` blocks")
    out = {}
    for m, nxt in zip(starts, [*starts[1:], None], strict=True):
        block = sl.text[m.start() : nxt.start() if nxt else len(sl.text)]
        if "SYSTEM" in block.split("pkgFlags=", 1)[-1].split("\n", 1)[0]:
            continue
        inst = _INSTALLER.search(block)
        out[m.group(1)] = {
            "installer": inst.group(1) if inst else "null",
            "install_packages": "REQUEST_INSTALL_PACKAGES: granted=true" in block,
            "evidence": sl.at(m),
        }
    return out


def settings(ctx: Context) -> dict[str, tuple[str, dict[str, Any]]]:
    sl = ctx.section("settings")
    if sl is None:
        return {}
    return {m.group(1): (m.group(2), sl.at(m)) for m in _SETTING.finditer(sl.text)}


def _components(value: str) -> set[str]:
    """`a/.X:b/.Y` -> {"a", "b"}; `null` and empty -> set()."""
    return {c.split("/", 1)[0] for c in value.split(":") if "/" in c}


def access(ctx: Context) -> dict[str, list[str]]:
    """Package -> the sensitive accesses it holds, from every source present."""
    held: dict[str, set[str]] = {}
    s = settings(ctx)
    for key, kind in (
        ("enabled_accessibility_services", "accessibility"),
        ("enabled_notification_listeners", "notification_listener"),
    ):
        for pkg in _components(s.get(key, ("", {}))[0]):
            held.setdefault(pkg, set()).add(kind)
    if (dp := ctx.section("device_policy")) is not None:
        for m in _ADMIN.finditer(dp.text):
            held.setdefault(m.group(1), set()).add("device_admin")
    if (ao := ctx.section("appops")) is not None:
        owner: str | None = None
        for _, line in ao.lines():
            if head := _APPOP_PKG.match(line):
                owner = head.group(1)
            elif owner and (op := _APPOP.match(line)):
                kind = "overlay" if op.group(1) == "SYSTEM_ALERT_WINDOW" else "usage_access"
                held.setdefault(owner, set()).add(kind)
    for pkg, p in packages(ctx).items():
        if p["install_packages"]:
            held.setdefault(pkg, set()).add("install_packages")
    return {pkg: sorted(kinds) for pkg, kinds in sorted(held.items())}


def boot(ctx: Context) -> dict[str, Any]:
    """Verified-boot state and security patch age, measured against the capture date."""
    sl = ctx.section("SYSTEM PROPERTIES")
    if sl is None:
        return {}
    props = {m.group(1): (m.group(2), sl.at(m)) for m in _PROP.finditer(sl.text)}
    out: dict[str, Any] = {
        "verified_boot": props.get("ro.boot.verifiedbootstate", (None,))[0],
        "device_state": props.get("ro.boot.vbmeta.device_state", (None,))[0],
        "evidence": [ev for _, ev in props.values()],
    }
    patch = props.get("ro.build.version.security_patch", (None,))[0]
    captured = ctx.rpt.captured
    if patch and captured:
        try:
            out["patch_age_days"] = (captured.date() - dt.date.fromisoformat(patch)).days
            out["security_patch"] = patch
        except ValueError:
            pass
    return out


@detector(
    id="security.hygiene",
    family="F10",
    inputs=("package", "settings", "device_policy", "appops", "SYSTEM PROPERTIES"),
    findings={
        "security.sideloaded_with_access": "security.review-sideloaded-app",
        "security.debugging_enabled": "security.turn-off-debugging",
        "security.always_on_vpn": "security.check-vpn-app",
        "security.bootloader_unlocked": "security.relock-bootloader",
        "security.patch_old": "security.update-system",
        "security.user_ca": "security.review-user-certs",
    },
)
def detect_security(ctx: Context) -> Iterator[Finding]:
    pkgs = packages(ctx)
    sideloaded = {p for p, info in pkgs.items() if info["installer"] not in STORES}
    for pkg, kinds in access(ctx).items():
        if pkg in sideloaded:
            yield Finding(
                "security.sideloaded_with_access",
                "high",
                min(len(kinds) / 3, 1.0),
                f"{pkg} was not installed from an app store and holds {', '.join(kinds)}",
                {"installer": pkgs[pkg]["installer"], "access": kinds},
                [{"package": pkg, "role": "cause"}],
                [pkgs[pkg]["evidence"]],
            )
    s = settings(ctx)
    on = [k for k in ("adb_enabled", "development_settings_enabled") if s.get(k, ("",))[0] == "1"]
    if on:
        yield Finding(
            "security.debugging_enabled",
            "low",
            len(on) / 2,
            "USB debugging / developer options are on",
            {k: True for k in on},
            [],
            [s[k][1] for k in on],
        )
    vpn = s.get("always_on_vpn_app", ("null", {}))
    if vpn[0] not in ("null", ""):
        yield Finding(
            "security.always_on_vpn",
            "medium" if vpn[0] in sideloaded else "low",
            0.5,
            f"Always-on VPN routes all traffic through {vpn[0]}",
            {"vpn_app": vpn[0], "sideloaded": vpn[0] in sideloaded},
            [{"package": vpn[0], "role": "holder"}],
            [vpn[1]],
        )
    b = boot(ctx)
    if b.get("device_state") == "unlocked" or b.get("verified_boot") not in (None, "green"):
        yield Finding(
            "security.bootloader_unlocked",
            "medium",
            0.6,
            f"Bootloader {b.get('device_state') or 'state unknown'}, "
            f"verified boot {b.get('verified_boot') or 'unknown'}",
            {"device_state": b.get("device_state"), "verified_boot": b.get("verified_boot")},
            [],
            b["evidence"],
        )
    age = b.get("patch_age_days")
    if age is not None and age > PATCH_OLD_DAYS:
        yield Finding(
            "security.patch_old",
            "medium" if age > PATCH_STALE_DAYS else "low",
            min(age / (2 * PATCH_STALE_DAYS), 1.0),
            f"Security patch {b['security_patch']} is {age} days older than the report",
            {"security_patch": b["security_patch"], "patch_age_days": age},
            [],
            b["evidence"],
        )
    certs = list(ctx.fs("FS/data/misc/user/*/cacerts-added/*"))
    if certs:
        yield Finding(
            "security.user_ca",
            "medium",
            0.5,
            f"{len(certs)} user-installed CA certificate(s) can intercept TLS traffic",
            {"user_ca_certs": len(certs)},
            [],
            [{"member": c["path"]} for c in certs[:3]],
        )


@view("security")
def security_view(ctx: Context) -> dict[str, Any]:
    pkgs = packages(ctx)
    b = boot(ctx)
    return {
        "sideloaded": [
            {"package": p, "installer": i["installer"]}
            for p, i in sorted(pkgs.items())
            if i["installer"] not in STORES
        ],
        "access": access(ctx),
        **{k: v for k, v in b.items() if k != "evidence"},
    }
