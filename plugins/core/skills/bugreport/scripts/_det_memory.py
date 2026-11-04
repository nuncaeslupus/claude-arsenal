"""F6 memory: swap thrashing, restart loops, and the `memory` / `churn` views."""

from __future__ import annotations

import re
from collections import defaultdict
from collections.abc import Iterator
from typing import Any

import _brlib as br
from _detectors import Context, Finding, NotParsed, Slice, detector, view

SWAP_FULL_PCT = 90  # ponytail: starting value, not measured on a fleet
KSWAPD_BUSY_PCT = 20  # ponytail: starting value
PSI_BUSY_AVG10 = 20  # ponytail: starting value
RESTARTS = 3  # ponytail: starting value — restarts within RESTART_WINDOW_S of a death
RESTART_WINDOW_S = 60

_ZRAM = re.compile(r"ZRAM:.*? for ([\d,.]+K) in swap \(([\d,.]+K) total swap\)")
_PSS_ROW = re.compile(r"^\s*([\d.,]+K): (\S+) \(pid (\d+)")
_KSWAPD_LOG = re.compile(r"([\d.]+)% \d+/kswapd")
_FLOAT = re.compile(r"\d+\.\d+")
_PSI = re.compile(r"^some avg10=([\d.]+)", re.M)
_PROC_HEAD = re.compile(r"^\s*\* (\S+) / ")
_PROC_TOTAL = re.compile(r"TOTAL: ([\d.,]+)% \(([^/]+)/[^/]+/([^ ]+) over")
_LMK = re.compile(r"Killing '(.+?)' \((\d+)\), adj (\d+)")
_EVENT = re.compile(r"^\[(.*)\]$")


def _avg(triple: str) -> float:
    """`45MB-52MB-60MB` -> the middle value in MB."""
    parts = triple.split("-")
    return br.parse_size(parts[1] if len(parts) == 3 else parts[0]) / (1 << 20)


def _psi(ctx: Context, name: str) -> tuple[float | None, list[dict[str, Any]]]:
    sl = ctx.section(name)
    if sl is None:
        return None, []
    m = _PSI.search(sl.text)
    if not m:
        raise NotParsed(sl.id, "no `some avg10=` line")
    return float(m.group(1)), [sl.at(m)]


def holders(sl: Slice | None, n: int) -> list[dict[str, Any]]:
    """The top `n` rows of meminfo's "Total PSS by process" block."""
    if sl is None:
        return []
    rows: list[dict[str, Any]] = []
    inside = False
    for _, line in sl.lines():
        if line.startswith("Total PSS by process"):
            inside = True
        elif inside and not line.strip():
            break
        elif inside and (m := _PSS_ROW.match(line)):
            rows.append(
                {
                    "package": m.group(2),
                    "pid": int(m.group(3)),
                    "role": "holder",
                    "pss_mb": round(br.parse_size(m.group(1)) / (1 << 20)),
                }
            )
    return sorted(rows, key=lambda r: -r["pss_mb"])[:n]


def pressure(ctx: Context) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    """Swap fill, kswapd CPU and PSI avg10, each None when its section is absent."""
    facts: dict[str, Any] = {"swap_pct": None, "kswapd_cpu_pct": None}
    evidence: list[dict[str, Any]] = []
    mem = ctx.section("meminfo")
    if mem and (m := _ZRAM.search(mem.text)):
        used, total = br.parse_size(m.group(1)), br.parse_size(m.group(2))
        if total:
            facts["swap_pct"] = round(100 * used / total, 1)
            evidence.append(mem.at(m))
    cpu = ctx.section("CPU INFO")
    if cpu:
        for _, line in cpu.lines():
            if "kswapd" in line:
                tok = _FLOAT.search(line)
                if tok is None:
                    raise NotParsed(cpu.id, "kswapd row has no %CPU column")
                facts["kswapd_cpu_pct"] = max(facts["kswapd_cpu_pct"] or 0.0, float(tok.group()))
    log = ctx.section("SYSTEM LOG")
    if log:
        for m in _KSWAPD_LOG.finditer(log.text):
            facts["kswapd_cpu_pct"] = max(facts["kswapd_cpu_pct"] or 0.0, float(m.group(1)))
    for key, name in (("psi_mem_avg10", "PSI memory"), ("psi_io_avg10", "PSI io")):
        facts[key], ev = _psi(ctx, name)
        evidence += ev
    return facts, evidence


def thrashing(facts: dict[str, Any]) -> bool:
    busy = (
        (facts["kswapd_cpu_pct"] or 0) >= KSWAPD_BUSY_PCT
        or (facts["psi_io_avg10"] or 0) >= PSI_BUSY_AVG10
        or (facts["psi_mem_avg10"] or 0) >= PSI_BUSY_AVG10
    )
    return (facts["swap_pct"] or 0) >= SWAP_FULL_PCT and busy


@detector(
    id="memory.pressure",
    family="F6",
    inputs=("meminfo", "CPU INFO", "PSI memory", "PSI io"),
    findings={"memory.swap_thrashing": "memory.free-ram"},
)
def detect_pressure(ctx: Context) -> Iterator[Finding]:
    facts, evidence = pressure(ctx)
    if not thrashing(facts):
        return
    yield Finding(
        "memory.swap_thrashing",
        "critical",
        facts["swap_pct"] / 100,
        f"Swap {facts['swap_pct']:.0f}% full with kswapd at {facts['kswapd_cpu_pct'] or 0:.0f}% "
        f"CPU and IO pressure {facts['psi_io_avg10'] or 0:.0f} — the device is thrashing",
        facts,
        holders(ctx.section("meminfo"), 3),
        evidence,
    )


def procstats_24h(sl: Slice | None) -> list[dict[str, Any]]:
    """Per-package 24 h memory: PSS average, or RSS when PSS was never sampled."""
    if sl is None:
        return []
    rows: list[dict[str, Any]] = []
    inside, pkg = False, None
    for _, line in sl.lines():
        if line.startswith("AGGREGATED OVER LAST"):
            inside = "24 HOURS" in line
        elif inside and (m := _PROC_HEAD.match(line)):
            pkg = m.group(1)
        elif inside and pkg and (m := _PROC_TOTAL.search(line)):
            pct = br.parse_number(m.group(1))
            pss, rss = _avg(m.group(2)), _avg(m.group(3))
            mem, metric = (pss, "pss") if pss else (rss, "rss")
            rows.append(
                {
                    "package": pkg,
                    "pct": pct,
                    "mem_mb": round(mem),
                    "metric": metric,
                    "mem_x_time": round(mem * pct / 100),
                }
            )
            pkg = None
    return sorted(rows, key=lambda r: -r["mem_x_time"])


def lmk_kills(ctx: Context) -> list[dict[str, Any]]:
    kills: list[dict[str, Any]] = []
    for name in ("KERNEL LOG", "SYSTEM LOG"):
        sl = ctx.section(name)
        if sl is not None:
            kills += [
                {"package": m.group(1), "pid": int(m.group(2)), "adj": int(m.group(3))}
                for m in _LMK.finditer(sl.text)
            ]
    return kills


@view("memory")
def memory_view(ctx: Context) -> dict[str, Any]:
    facts, _ = pressure(ctx)
    return {
        **facts,
        "holders": holders(ctx.section("meminfo"), 5),
        "procstats_24h": procstats_24h(ctx.section("procstats")),
        "lmk_kills": lmk_kills(ctx),
    }


def restarts(ctx: Context) -> dict[str, dict[str, Any]]:
    """Per package: deaths followed by a start within the window, from the event log."""
    died: dict[str, Any] = {}
    out: dict[str, dict[str, Any]] = defaultdict(
        lambda: {"restarts": 0, "start_reason": None, "evidence": []}
    )
    sl = ctx.section("EVENT LOG")
    for row in ctx.log("EVENT LOG"):
        m = _EVENT.match(row.msg)
        if not m or row.t is None:
            continue
        fields = m.group(1).split(",")
        if row.tag == "am_proc_died" and len(fields) >= 3:
            died[fields[2]] = row.t
        elif row.tag == "am_proc_start" and len(fields) >= 5:
            pkg = fields[3]
            since = died.pop(pkg, None)
            if since is not None and (row.t - since).total_seconds() <= RESTART_WINDOW_S:
                entry = out[pkg]
                entry["restarts"] += 1
                entry["start_reason"] = fields[4]
                if sl is not None:
                    entry["evidence"].append({"section": sl.id, "offset": row.offset})
    return dict(out)


@detector(
    id="memory.churn",
    family="F6",
    inputs=("EVENT LOG",),
    findings={"memory.restart_loop": "memory.restart-loop"},
)
def detect_churn(ctx: Context) -> Iterator[Finding]:
    for pkg, entry in sorted(restarts(ctx).items()):
        if entry["restarts"] < RESTARTS:
            continue
        yield Finding(
            "memory.restart_loop",
            "medium",
            min(1.0, entry["restarts"] / 10),
            f"{pkg} was restarted {entry['restarts']} times within {RESTART_WINDOW_S}s of "
            f"being killed (start: {entry['start_reason']})",
            {"restarts": entry["restarts"], "start_reason": entry["start_reason"]},
            [{"package": pkg, "role": "cause"}],
            entry["evidence"][:3],
        )


@view("churn")
def churn_view(ctx: Context) -> dict[str, Any]:
    rows = [
        {"package": pkg, "restarts": e["restarts"], "start_reason": e["start_reason"]}
        for pkg, e in restarts(ctx).items()
    ]
    return {"restarts": sorted(rows, key=lambda r: (-r["restarts"], r["package"]))}
