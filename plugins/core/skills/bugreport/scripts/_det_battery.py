"""F1 battery: screen-off drain from the batterystats checkin, blamed on the top wakelock.

`checkin()` is the shared reader of `CHECKIN BATTERYSTATS`, which F7 and F8 use too.
A row is `9,<uid>,<category>,<type>,<fields...>`; only `i` (info) and `l` (since
last charge) rows are kept.
"""

from __future__ import annotations

from collections.abc import Iterator
from typing import Any

from _detectors import Context, Finding, NotParsed, detector, view

SECTION = "CHECKIN BATTERYSTATS"
DRAIN_PCT_H = 4.0  # ponytail: starting value — screen-off drain worth a finding
MIN_OFF_H = 0.5  # a shorter screen-off window is too noisy to rate
MS_H = 3_600_000


def checkin(ctx: Context) -> dict[str, Any] | None:
    """{"vers", "uids": {uid: package}, "rows": {type: [(uid, fields, evidence)]}}."""
    sl = ctx.section(SECTION)
    if sl is None:
        return None
    vers = None
    uids: dict[int, str] = {}
    rows: dict[str, list[tuple[int, list[str], dict[str, Any]]]] = {}
    for off, line in sl.lines():
        parts = line.split(",")
        if len(parts) < 4 or parts[2] not in ("i", "l") or not parts[1].lstrip("-").isdigit():
            continue
        uid, kind, fields = int(parts[1]), parts[3], parts[4:]
        if kind == "vers" and fields and fields[0].isdigit():
            vers = int(fields[0])
        elif kind == "uid" and len(fields) >= 2 and fields[0].isdigit():
            uids[int(fields[0])] = fields[1]
        else:
            rows.setdefault(kind, []).append((uid, fields, {"section": sl.id, "offset": off}))
    if vers is None:
        raise NotParsed(sl.id, "no `vers` row")
    return {"vers": vers, "uids": uids, "rows": rows}


def package(ck: dict[str, Any], uid: int) -> str:
    return str(ck["uids"].get(uid, f"uid {uid}"))


def num(fields: list[str], i: int) -> float:
    try:
        return float(fields[i])
    except (IndexError, ValueError):
        return 0.0


def drain(ctx: Context) -> dict[str, Any] | None:
    ck = checkin(ctx)
    if ck is None or not ck["rows"].get("bt") or not ck["rows"].get("dc"):
        return None
    _, bt, bt_ev = ck["rows"]["bt"][0]
    _, dc, dc_ev = ck["rows"]["dc"][0]
    off_h = num(bt, 6) / MS_H  # screenOffRealtime
    off_pct = num(dc, 3)  # dischargeAmountScreenOff
    held: dict[int, float] = {}
    for uid, fields, _ in ck["rows"].get("wl", []):
        if "p" in fields:  # name, full, f, count, partial, p, count, ...
            held[uid] = held.get(uid, 0.0) + num(fields, fields.index("p") - 1)
    wakelocks = [
        {"package": package(ck, uid), "uid": uid, "partial_h": round(ms / MS_H, 2)}
        for uid, ms in sorted(held.items(), key=lambda kv: -kv[1])
    ]
    return {
        "screen_off_h": round(off_h, 2),
        "screen_off_drain_pct": off_pct,
        "rate_pct_h": round(off_pct / off_h, 2) if off_h >= MIN_OFF_H else None,
        "wakelocks": wakelocks,
        "evidence": [bt_ev, dc_ev],
    }


@detector(
    id="battery.drain",
    family="F1",
    inputs=(SECTION,),
    findings={"battery.screen_off_drain": "battery.find-wakelock"},
)
def detect_drain(ctx: Context) -> Iterator[Finding]:
    d = drain(ctx)
    if d is None or d["rate_pct_h"] is None or d["rate_pct_h"] < DRAIN_PCT_H:
        return
    top = d["wakelocks"][:1]
    yield Finding(
        "battery.screen_off_drain",
        "high" if d["rate_pct_h"] >= 2 * DRAIN_PCT_H else "medium",
        min(d["rate_pct_h"] / (4 * DRAIN_PCT_H), 1.0),
        f"Screen-off drain {d['rate_pct_h']}%/h over {d['screen_off_h']}h"
        + (f"; {top[0]['package']} held a partial wakelock {top[0]['partial_h']}h" if top else ""),
        {k: d[k] for k in ("screen_off_h", "screen_off_drain_pct", "rate_pct_h")},
        [{**w, "role": "cause"} for w in top],
        d["evidence"],
    )


@view("battery")
def battery_view(ctx: Context) -> dict[str, Any]:
    d = drain(ctx) or {"wakelocks": []}
    return {k: v for k, v in d.items() if k != "evidence"}
