"""F2 thermal: throttling from thermalservice and the `thermal_changed` history."""

from __future__ import annotations

import re
from collections.abc import Iterator
from typing import Any

from _detectors import Context, Finding, NotParsed, detector, view

THROTTLING = 2  # ponytail: starting value — PowerManager THERMAL_STATUS_MODERATE
STATUS_MAX = 6  # THERMAL_STATUS_SHUTDOWN

_STATUS = re.compile(r"^Thermal Status: (\d+)", re.M)
_TEMP = re.compile(r"Temperature\{mValue=([-\d.]+), mType=\d+, mName=([^,]+), mStatus=(\d+)\}")
_CHANGED = re.compile(r"^\[([^,]+),\d+,([-\d.]+),(\d+),(\d+)\]$")


def thermal(ctx: Context) -> dict[str, Any] | None:
    sl = ctx.section("thermalservice")
    if sl is None:
        return None
    m = _STATUS.search(sl.text)
    if not m:
        raise NotParsed(sl.id, "no `Thermal Status:` line")
    ev = ctx.section("EVENT LOG")
    history: list[dict[str, Any]] = [
        {
            "sensor": c.group(1),
            "temp_c": float(c.group(2)),
            "status": int(c.group(3)),
            "evidence": {"section": ev.id if ev else "", "offset": row.offset},
        }
        for row in ctx.log("EVENT LOG")
        if row.tag == "thermal_changed" and (c := _CHANGED.match(row.msg))
    ]
    temps = [
        {"sensor": t.group(2), "temp_c": float(t.group(1)), "status": int(t.group(3))}
        for t in _TEMP.finditer(sl.text)
    ]
    return {
        "status": int(m.group(1)),
        "worst": max([int(m.group(1))] + [h["status"] for h in history]),
        "temps": temps,
        "history": history,
        "evidence": [sl.at(m)],
    }


@detector(
    id="thermal.status",
    family="F2",
    inputs=("thermalservice", "EVENT LOG"),
    findings={"thermal.throttling": "thermal.cool-down"},
)
def detect_thermal(ctx: Context) -> Iterator[Finding]:
    t = thermal(ctx)
    if t is None or t["worst"] < THROTTLING:
        return
    worst = t["worst"]
    hot = [h for h in t["history"] if h["status"] == worst]
    yield Finding(
        "thermal.throttling",
        "critical" if worst >= 4 else "high" if worst == 3 else "medium",
        worst / STATUS_MAX,
        f"Thermal status reached {worst} ({hot[0]['sensor'] if hot else 'device'}); "
        f"now {t['status']} — the device throttled",
        {"status_now": t["status"], "status_worst": worst, "changes": len(t["history"])},
        [{"sensor": h["sensor"], "role": "cause"} for h in hot[:1]],
        t["evidence"] + [h["evidence"] for h in hot[:2]],
    )


@view("thermal")
def thermal_view(ctx: Context) -> dict[str, Any]:
    t = thermal(ctx) or {"status": None, "worst": None, "temps": [], "history": []}
    return {
        "status_now": t["status"],
        "status_worst": t["worst"],
        "temps": t["temps"],
        "history": [{k: h[k] for k in ("sensor", "temp_c", "status")} for h in t["history"]],
    }
