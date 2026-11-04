"""F7 network: Wi-Fi scan storms from the checkin `wfl` rows, named by requester.

Only per-uid counters are read; no SSID, BSSID or address ever reaches a claim.
"""

from __future__ import annotations

from collections.abc import Iterator
from typing import Any

from _det_battery import MS_H, SECTION, checkin, num, package
from _detectors import Context, Finding, detector, view

SCANS_H = 100.0  # ponytail: starting value — Wi-Fi scans per battery hour that make a storm


def scans(ctx: Context) -> list[dict[str, Any]]:
    """`wfl`: fullLockTime, scanTime, runningTime, scanCount, ... per uid, busiest first."""
    ck = checkin(ctx)
    if ck is None or not ck["rows"].get("bt"):
        return []
    on_battery_h = num(ck["rows"]["bt"][0][1], 1) / MS_H  # batteryRealtime
    out = [
        {
            "package": package(ck, uid),
            "uid": uid,
            "scans": int(num(fields, 3)),
            "per_h": round(num(fields, 3) / on_battery_h, 1) if on_battery_h else None,
            "evidence": ev,
        }
        for uid, fields, ev in ck["rows"].get("wfl", [])
    ]
    return sorted(out, key=lambda r: -r["scans"])


@detector(
    id="network.wifi_scans",
    family="F7",
    inputs=(SECTION,),
    findings={"network.scan_storm": "network.throttle-scans"},
)
def detect_scan_storm(ctx: Context) -> Iterator[Finding]:
    for r in scans(ctx):
        if r["per_h"] is None or r["per_h"] < SCANS_H:
            continue
        yield Finding(
            "network.scan_storm",
            "medium",
            min(r["per_h"] / (10 * SCANS_H), 1.0),
            f"{r['package']} requested {r['scans']} Wi-Fi scans ({r['per_h']}/h on battery)",
            {"scans": r["scans"], "per_h": r["per_h"]},
            [{"package": r["package"], "uid": r["uid"], "role": "cause"}],
            [r["evidence"]],
        )


@view("network")
def network_view(ctx: Context) -> dict[str, Any]:
    return {"wifi_scans": [{k: v for k, v in r.items() if k != "evidence"} for r in scans(ctx)]}
