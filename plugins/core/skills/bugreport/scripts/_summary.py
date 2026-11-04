"""The `summary` document (§ 5.7): every field present, `unknown` when absent."""

from __future__ import annotations

import re
from typing import Any

import _brlib as br

SCHEMA = "bugreport.query.summary/1"
UNKNOWN = "unknown"
_STATUS = {"1": "unknown", "2": "charging", "3": "discharging", "4": "not charging", "5": "full"}
_HEALTH = {
    "1": "unknown",
    "2": "good",
    "3": "overheat",
    "4": "dead",
    "5": "over voltage",
    "6": "failure",
    "7": "cold",
}


def _or(v: Any) -> Any:
    return UNKNOWN if v is None or v == "" else v


def _span(pair: Any) -> dict[str, str]:
    if not pair:
        return {"first": UNKNOWN, "last": UNKNOWN}
    return {"first": br.fmt_ts(pair[0]), "last": br.fmt_ts(pair[1])}


def _kernel_span(rpt: br.Report) -> dict[str, Any]:
    ts = [e["t"] for e in rpt.events() if e["src"] in br.KERNEL_SECTIONS and e["t"] is not None]
    return _span((min(ts), max(ts)) if ts else None)


def _grab(text: str | None, pattern: str) -> str | None:
    m = re.search(pattern, text or "", re.M)
    return m.group(1).strip() if m else None


def _fs_range(rpt: br.Report, prefix: str) -> dict[str, Any]:
    rows = [f for f in rpt.index["fs"] if f["path"].startswith(prefix)]
    if not rows:
        return {"count": 0, "first": UNKNOWN, "last": UNKNOWN}
    dates = sorted(f["date"] for f in rows)
    return {"count": len(rows), "first": dates[0], "last": dates[-1]}


def summarize(rpt: br.Report) -> dict[str, Any]:
    props = rpt.properties()
    head = rpt.header
    battery = rpt.first_text("battery")
    stats = rpt.first_text("batterystats")
    procstats = rpt.first_text("procstats")
    disk = rpt.first_text("diskstats")
    packages = rpt.first_text("package") or ""
    inp = rpt.index["input"]
    secs = rpt.sections
    largest = sorted(secs, key=lambda s: -s["size"])[:5]
    pkgs = re.findall(
        r"^  Package \[[^\]]+\][^\n]*\n(?:    [^\n]*\n)*?    pkgFlags=\[([^\]]*)\]", packages, re.M
    )
    temp = _grab(battery, r"^\s*temperature: (-?\d+)")
    windows = re.findall(
        r"^(COMMITTED STATS FROM \S+|AGGREGATED OVER LAST [^:]+):", procstats or "", re.M
    )
    return {
        "schema": SCHEMA,
        "truncated": False,
        "device": {
            "manufacturer": _or(head.get("oem")),
            "model": _or(head.get("model")),
            "codename": _or(props.get("ro.product.device")),
        },
        "build": {
            "release": _or(head.get("android_release")),
            "sdk": _or(head.get("sdk")),
            "build": _or(head.get("build_id")),
            "security_patch": _or(props.get("ro.build.version.security_patch")),
        },
        "capture": {
            "time": _or(head.get("captured_local")),
            "timezone": _or(rpt.clock.get("tz")),
            "clock": rpt.clock["source"],
        },
        "uptime_s": _or(head.get("uptime_s")),
        "boot_reason": _or(props.get("sys.boot.reason") or props.get("ro.boot.bootreason")),
        "coverage": {
            "system_log": _span(rpt.coverage(("SYSTEM LOG",))),
            "event_log": _span(rpt.coverage(("EVENT LOG",))),
            "kernel_log": _kernel_span(rpt),
            "batterystats_since_charge": _or(_grab(stats, r"^\s*Time on battery: ([^(]+)")),
            "procstats_windows": windows or UNKNOWN,
            "anr": _fs_range(rpt, "FS/data/anr/"),
            "tombstones": _fs_range(rpt, "FS/data/tombstones/"),
        },
        "file": {
            "input_bytes": rpt.path.stat().st_size,
            "text_bytes": len(rpt.mm),
            "sections": len(secs),
            "largest": [{"id": s["id"], "size": s["size"]} for s in largest],
            "proto_members": inp.get("proto_members", 0),
        },
        "battery": {
            "level": _or(_grab(battery, r"^\s*level: (\d+)")),
            "status": _STATUS.get(_grab(battery, r"^\s*status: (\d+)") or "", UNKNOWN),
            "health": _HEALTH.get(_grab(battery, r"^\s*health: (\d+)") or "", UNKNOWN),
            "temperature_c": int(temp) / 10 if temp else UNKNOWN,
        },
        "storage_free": _or(_grab(disk, r"^Data-Free: (.+)$")),
        "apps": {
            "installed": len(pkgs) if pkgs else UNKNOWN,
            "user": sum(1 for f in pkgs if "SYSTEM" not in f.split()) if pkgs else UNKNOWN,
        },
    }
