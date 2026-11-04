"""F3 reboots: a battery shutdown from the boot-reason props, a system_server watchdog kill."""

from __future__ import annotations

import re
from collections.abc import Iterator
from typing import Any

from _detectors import Context, Finding, detector, view

_PROP = re.compile(
    r"^\[(sys\.boot\.reason\.last|sys\.boot\.reason|ro\.boot\.bootreason)\]: \[(.*)\]$", re.M
)
_WATCHDOG = re.compile(r"WATCHDOG KILLING SYSTEM PROCESS: (.*)")
_BLOCKED = re.compile(r"Blocked in (?:handler|monitor \S+) on (.+?) thread \(([^)]+)\)")


def boot_reasons(ctx: Context) -> dict[str, tuple[str, dict[str, Any]]]:
    sl = ctx.section("SYSTEM PROPERTIES")
    if sl is None:
        return {}
    return {m.group(1): (m.group(2), sl.at(m)) for m in _PROP.finditer(sl.text)}


def watchdogs(ctx: Context) -> list[dict[str, Any]]:
    log = ctx.section("SYSTEM LOG")
    out = []
    for row in ctx.log("SYSTEM LOG"):
        if row.tag == "Watchdog" and (m := _WATCHDOG.search(row.msg)):
            b = _BLOCKED.search(m.group(1))
            out.append(
                {
                    "thread": b.group(2) if b else None,
                    "reason": m.group(1)[:120],
                    "evidence": {"section": log.id if log else "SYSTEM LOG", "offset": row.offset},
                }
            )
    return out


@detector(
    id="reboots.reasons",
    family="F3",
    inputs=("SYSTEM PROPERTIES", "SYSTEM LOG"),
    findings={
        "reboots.battery_shutdown": "reboots.check-charging",
        "reboots.watchdog": "reboots.read-blocked-thread",
    },
)
def detect_reboots(ctx: Context) -> Iterator[Finding]:
    last = boot_reasons(ctx).get("sys.boot.reason.last")
    if last and last[0].startswith("shutdown,battery"):
        yield Finding(
            "reboots.battery_shutdown",
            "medium",
            0.5,
            f"The previous boot ended in a battery shutdown ({last[0]})",
            {"last_boot_reason": last[0]},
            [],
            [last[1]],
        )
    dogs = watchdogs(ctx)
    if dogs:
        thread = dogs[-1]["thread"] or "unknown"
        yield Finding(
            "reboots.watchdog",
            "critical",
            len(dogs) / 3,
            f"The watchdog killed system_server {len(dogs)}x; blocked thread: {thread}",
            {"kills": len(dogs), "thread": thread},
            [{"thread": thread, "role": "cause"}],
            [d["evidence"] for d in dogs[:3]],
        )


@view("reboots")
def reboots_view(ctx: Context) -> dict[str, Any]:
    return {
        "boot_reasons": {k: v for k, (v, _) in boot_reasons(ctx).items()},
        "watchdog_kills": [{k: d[k] for k in ("thread", "reason")} for d in watchdogs(ctx)],
    }
