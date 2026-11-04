"""F5 crashes: repeated Java crashes from `am_crash`, native crashes from `.pb` tombstones."""

from __future__ import annotations

from collections.abc import Iterator
from typing import Any

import _pbwire as pb
from _detectors import Context, Finding, detector, view

REPEAT = 3  # ponytail: starting value — crashes of one package that make a loop


def java_crashes(ctx: Context) -> dict[str, list[dict[str, Any]]]:
    """`am_crash` events by package: `[user,pid,process,flags,exception,message,...]`."""
    ev = ctx.section("EVENT LOG")
    out: dict[str, list[dict[str, Any]]] = {}
    for row in ctx.log("EVENT LOG"):
        if row.tag != "am_crash":
            continue
        parts = row.msg.strip("[]").split(",")
        if len(parts) < 6:
            continue
        out.setdefault(parts[2], []).append(
            {
                "exception": parts[4],
                "evidence": {"section": ev.id if ev else "EVENT LOG", "offset": row.offset},
            }
        )
    return out


def native_crashes(ctx: Context) -> list[dict[str, Any]]:
    out = []
    for member in ctx.fs("FS/data/tombstones/*.pb"):
        out.append({**pb.tombstone(ctx.read(member)), "evidence": {"member": member["path"]}})
    return out


@detector(
    id="crashes.events",
    family="F5",
    inputs=("EVENT LOG",),
    findings={
        "crashes.repeat_crash": "crashes.fix-top-exception",
        "crashes.native_crash": "crashes.read-tombstone",
    },
)
def detect_crashes(ctx: Context) -> Iterator[Finding]:
    for pkg, rows in sorted(java_crashes(ctx).items()):
        if len(rows) < REPEAT:
            continue
        top = max({r["exception"] for r in rows}, key=[r["exception"] for r in rows].count)
        yield Finding(
            "crashes.repeat_crash",
            "high",
            len(rows) / (REPEAT * 2),
            f"{pkg} crashed {len(rows)} times ({top})",
            {"crashes": len(rows), "exception": top},
            [{"package": pkg, "role": "victim"}],
            [r["evidence"] for r in rows[:3]],
        )
    for t in native_crashes(ctx):
        yield Finding(
            "crashes.native_crash",
            "high",
            0.5,
            f"{t['process']} died on {t['signal']}"
            + (f": {t['abort_message']}" if t["abort_message"] else ""),
            {"signal": t["signal"], "abort_message": t["abort_message"]},
            [{"package": t["process"], "pid": t["pid"], "role": "victim"}],
            [t["evidence"]],
        )


@view("crashes")
def crashes_view(ctx: Context) -> dict[str, Any]:
    return {
        "java": [
            {"package": pkg, "crashes": len(rows), "exception": rows[-1]["exception"]}
            for pkg, rows in sorted(java_crashes(ctx).items(), key=lambda kv: -len(kv[1]))
        ],
        "native": [{k: v for k, v in t.items() if k != "evidence"} for t in native_crashes(ctx)],
    }
