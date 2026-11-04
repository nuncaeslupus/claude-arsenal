"""F8 peripherals: GPS held in the background, from the checkin `sr` rows."""

from __future__ import annotations

from collections.abc import Iterator
from typing import Any

from _det_battery import MS_H, SECTION, checkin, num, package
from _detectors import Context, Finding, detector, view

GPS = "-10000"  # BatteryStats.Uid.Sensor.GPS
BG_GPS_H = 0.5  # ponytail: starting value — background GPS hours worth a finding


def gps(ctx: Context) -> list[dict[str, Any]]:
    """`sr`: sensor, totalTime, count, bgCount, actualTime, bgActualTime per uid."""
    ck = checkin(ctx)
    if ck is None:
        return []
    out = [
        {
            "package": package(ck, uid),
            "uid": uid,
            "total_h": round(num(fields, 1) / MS_H, 2),
            "background_h": round(num(fields, 5) / MS_H, 2),
            "evidence": ev,
        }
        for uid, fields, ev in ck["rows"].get("sr", [])
        if fields and fields[0] == GPS
    ]
    return sorted(out, key=lambda r: -r["background_h"])


@detector(
    id="peripherals.gps",
    family="F8",
    inputs=(SECTION,),
    findings={"peripherals.gps_background": "peripherals.limit-location"},
)
def detect_gps(ctx: Context) -> Iterator[Finding]:
    for r in gps(ctx):
        if r["background_h"] < BG_GPS_H:
            continue
        yield Finding(
            "peripherals.gps_background",
            "medium",
            min(r["background_h"] / 4, 1.0),
            f"{r['package']} held GPS {r['background_h']}h in the background",
            {"total_h": r["total_h"], "background_h": r["background_h"]},
            [{"package": r["package"], "uid": r["uid"], "role": "holder"}],
            [r["evidence"]],
        )


@view("peripherals")
def peripherals_view(ctx: Context) -> dict[str, Any]:
    return {"gps": [{k: v for k, v in r.items() if k != "evidence"} for r in gps(ctx)]}
