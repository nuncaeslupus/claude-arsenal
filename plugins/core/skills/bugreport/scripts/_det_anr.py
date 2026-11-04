"""F4 ANR: each ANR blamed on system pressure or on its own main thread, and the `anr` view."""

from __future__ import annotations

import re
from collections.abc import Iterator
from typing import Any

from _det_memory import pressure, thrashing
from _detectors import Context, Finding, detector, view

BLOCK_S = 2  # the lines of one "ANR in" block land within this many seconds of it

_ANR_IN = re.compile(r"^ANR in (\S+)")
_PID = re.compile(r"^PID: (\d+)")
_REASON = re.compile(r"^Reason: (.*)")
_LOAD = re.compile(r"^Load: ([\d.]+)")
_AM_ANR = re.compile(r"^\[\d+,(\d+),([^,]+),\d+,(.*)\]$")
_TRACE_PID = re.compile(r"^----- pid (\d+) ")
_MAIN = re.compile(r'^"main" .*?tid=1 (\w+)')


def kind(reason: str) -> str:
    low = reason.lower()
    for needle, name in (
        ("input dispatching", "input_dispatch"),
        ("broadcast", "broadcast"),
        ("service", "service"),
    ):
        if needle in low:
            return name
    return "other"


def anrs(ctx: Context) -> list[dict[str, Any]]:
    """ActivityManager "ANR in" blocks; the `am_anr` events when the log has none."""
    out: list[dict[str, Any]] = []
    log = ctx.section("SYSTEM LOG")
    cur: dict[str, Any] | None = None
    for row in ctx.log("SYSTEM LOG"):
        if row.tag != "ActivityManager":
            continue
        msg = row.msg.strip()
        if m := _ANR_IN.match(msg):
            cur = {"package": m.group(1), "pid": None, "reason": "", "load": None, "t": row.t}
            cur["evidence"] = [{"section": log.id if log else "SYSTEM LOG", "offset": row.offset}]
            out.append(cur)
        elif cur and row.t and cur["t"] and (row.t - cur["t"]).total_seconds() <= BLOCK_S:
            if m := _PID.match(msg):
                cur["pid"] = int(m.group(1))
            elif m := _REASON.match(msg):
                cur["reason"] = m.group(1)
            elif m := _LOAD.match(msg):
                cur["load"] = float(m.group(1))
    if not out:
        ev = ctx.section("EVENT LOG")
        for row in ctx.log("EVENT LOG"):
            if row.tag == "am_anr" and (m := _AM_ANR.match(row.msg)):
                out.append(
                    {
                        "package": m.group(2),
                        "pid": int(m.group(1)),
                        "reason": m.group(3),
                        "load": None,
                        "t": row.t,
                        "evidence": [{"section": ev.id if ev else "", "offset": row.offset}],
                    }
                )
    states = main_states(ctx)
    for a in out:
        a["kind"] = kind(a["reason"])
        a["main_thread_state"] = states.get(a["pid"])
    return out


def main_states(ctx: Context) -> dict[int | None, str]:
    """pid -> state of its "main" thread in the last ANR's traces."""
    sl = ctx.section("VM TRACES AT LAST ANR")
    states: dict[int | None, str] = {}
    pid = None
    if sl is not None:
        for _, line in sl.lines():
            if m := _TRACE_PID.match(line):
                pid = int(m.group(1))
            elif (m := _MAIN.match(line)) and pid not in states:
                states[pid] = m.group(1)
    return states


@detector(
    id="anr.anr",
    family="F4",
    inputs=(
        "SYSTEM LOG",
        "EVENT LOG",
        "VM TRACES AT LAST ANR",
        "meminfo",
        "CPU INFO",
        "PSI memory",
        "PSI io",
    ),
    findings={"anr.under_pressure": "memory.free-ram", "anr.main_thread": "anr.main-thread"},
)
def detect_anr(ctx: Context) -> Iterator[Finding]:
    found = anrs(ctx)
    if not found:
        return
    facts, mem_evidence = pressure(ctx)
    traces = [{"section": "FS", "path": f["path"]} for f in ctx.fs("FS/data/anr/*")][:2]
    if thrashing(facts):
        yield Finding(
            "anr.under_pressure",
            "high",
            len(found) / 10 + 0.5,
            f"{len(found)} ANR(s) while the device was thrashing — the apps are victims, "
            "not the cause",
            {**facts, "anrs": len(found)},
            [{"package": a["package"], "pid": a["pid"], "role": "victim"} for a in found[:5]],
            [ev for a in found[:3] for ev in a["evidence"]] + mem_evidence[:2] + traces,
        )
        return
    for a in found:
        state = a["main_thread_state"]
        yield Finding(
            "anr.main_thread",
            "high",
            0.6,
            f"{a['package']} ANR ({a['kind']}) on an idle system; main thread "
            f"{state or 'state unknown'}",
            {"kind": a["kind"], "load": a["load"], "main_thread_state": state},
            [{"package": a["package"], "pid": a["pid"], "role": "cause"}],
            a["evidence"] + traces,
        )


@view("anr")
def anr_view(ctx: Context) -> dict[str, Any]:
    return {
        "anrs": [
            {k: a[k] for k in ("package", "pid", "kind", "load", "main_thread_state")}
            | {"evidence": a["evidence"][0]}
            for a in anrs(ctx)
        ]
    }
