"""The detector registry, the read context, and the fail-soft run loop (spec 0005 § 5.8).

A detector is a function registered with `@detector(...)` that reads sections
through a `Context` and yields `Finding`s. The loop runs each one in isolation:
`NotParsed` and every other exception become a `not_parsed` row with a `query`
route, so one misread section never takes the checkup down with it.
"""

from __future__ import annotations

import dataclasses
import datetime as dt
import fnmatch
import importlib
import re
import zipfile
from collections.abc import Callable, Iterable, Iterator
from typing import Any

import _brlib as br

SEVERITIES = ("critical", "high", "medium", "low", "info")
FAMILIES = {
    "F1": "battery",
    "F2": "thermal",
    "F3": "reboots",
    "F4": "anr",
    "F5": "crashes",
    "F6": "memory",
    "F7": "network",
    "F8": "peripherals",
    "F9": "storage",
    "F10": "security",
    "F11": "battery-health",
}
# `churn` is a view over F6, not a family of its own (§ 5.8)
SLUGS = {**{slug: f for f, slug in FAMILIES.items()}, "churn": "F6"}
MODULES = (
    "_det_memory",
    "_det_anr",
    "_det_thermal",
    "_det_crashes",
    "_det_battery",
    "_det_reboots",
    "_det_network",
    "_det_peripherals",
    "_det_storage",
    "_det_battery_health",
    "_det_security",
)
CLAIM_CHARS = 160
MEMBER_CAP = 1 << 20  # ponytail: starting value — a tombstone .pb is tens of KiB


class NotParsed(Exception):
    """The section is there but its layout is not one the detector knows."""

    def __init__(self, section: str, reason: str) -> None:
        super().__init__(f"{section}: {reason}")
        self.section = section
        self.reason = reason


@dataclasses.dataclass
class Finding:
    id: str
    severity: str
    score: float
    claim: str
    facts: dict[str, Any]
    subjects: list[dict[str, Any]]
    evidence: list[dict[str, Any]]


@dataclasses.dataclass
class Slice:
    """One section, read once: its id, start offset and text."""

    id: str
    offset: int
    text: str

    def lines(self) -> Iterator[tuple[int, str]]:
        off = self.offset
        for raw in self.text.split("\n"):
            yield off, raw.rstrip("\r")
            off += len(raw.encode("utf-8", "replace")) + 1

    def at(self, m: re.Match[str]) -> dict[str, Any]:
        """An evidence pointer to a regex match inside this slice."""
        return {"section": self.id, "offset": self.offset + len(self.text[: m.start()].encode())}


@dataclasses.dataclass
class LogRow:
    offset: int
    t: dt.datetime | None
    level: str
    tag: str
    msg: str


class Context:
    """The only way a detector reads the report: bounded slices, cached per run."""

    def __init__(self, rpt: br.Report) -> None:
        self.rpt = rpt
        self._cache: dict[str, Slice | None] = {}

    def section(self, name: str) -> Slice | None:
        if name not in self._cache:
            found = self.rpt.find(name)
            self._cache[name] = (
                Slice(found[0]["id"], found[0]["start"], self.rpt.text(found[0])) if found else None
            )
        return self._cache[name]

    def log(self, name: str) -> Iterator[LogRow]:
        """Parsed logcat rows of a log section; nothing when it is absent."""
        sl = self.section(name)
        if sl is None:
            return
        captured = self.rpt.captured
        for off, line in sl.lines():
            m = br._LOGCAT_LINE.match(line)
            if m:
                t = br.logcat_time(m.group(1), captured) if captured else None
                yield LogRow(off, t, m.group(2), m.group(3), m.group(4))

    def fs(self, pattern: str) -> Iterator[dict[str, Any]]:
        """`FS/` members of a zip input whose path matches the glob."""
        for member in self.rpt.index.get("fs", []):
            if fnmatch.fnmatch(member["path"], pattern):
                yield member

    def read(self, member: dict[str, Any], cap: int = MEMBER_CAP) -> bytes:
        """The first `cap` bytes of one `FS/` member of the zip input."""
        with zipfile.ZipFile(self.rpt.path) as zf, zf.open(member["path"]) as f:
            return f.read(cap)


@dataclasses.dataclass
class Detector:
    id: str
    family: str
    inputs: tuple[str, ...]
    findings: dict[str, str]
    fn: Callable[[Context], Iterable[Finding]]


REGISTRY: dict[str, Detector] = {}
VIEWS: dict[str, Callable[[Context], dict[str, Any]]] = {}


def detector(
    *, id: str, family: str, inputs: tuple[str, ...], findings: dict[str, str]
) -> Callable[[Callable[[Context], Iterable[Finding]]], Callable[[Context], Iterable[Finding]]]:
    def register(fn: Callable[[Context], Iterable[Finding]]) -> Callable[..., Iterable[Finding]]:
        if id in REGISTRY:
            raise ValueError(f"detector {id!r} registered twice")
        REGISTRY[id] = Detector(id, family, inputs, findings, fn)
        return fn

    return register


def view(slug: str) -> Callable[[Callable[[Context], dict[str, Any]]], Any]:
    def register(fn: Callable[[Context], dict[str, Any]]) -> Callable[[Context], dict[str, Any]]:
        VIEWS[slug] = fn
        return fn

    return register


def load() -> None:
    """Import the detector modules, which register themselves."""
    for name in MODULES:
        importlib.import_module(name)


def parse_families(arg: str | None) -> tuple[set[str] | None, list[str]]:
    """`memory,F4` -> ({"F6", "F4"}, ["memory", "anr"]); None means every family."""
    if not arg:
        return None, []
    fams: set[str] = set()
    slugs: list[str] = []
    for raw in arg.split(","):
        word = raw.strip()
        if word.upper() in FAMILIES:
            fam, slug = word.upper(), FAMILIES[word.upper()]
        elif word.lower() in SLUGS:
            fam, slug = SLUGS[word.lower()], word.lower()
        else:
            known = ", ".join([*SLUGS, *FAMILIES])
            raise br.UsageError(f"unknown family {word!r} (known: {known})")
        fams.add(fam)
        if slug not in slugs:
            slugs.append(slug)
    return fams, slugs


def _route(ctx: Context, section: str) -> str:
    found = ctx.rpt.find(section)
    sid = found[0]["id"] if found else section
    return f"query_bugreport.py sample --input R --section {sid}"


def _row(det: Detector, f: Finding) -> dict[str, Any]:
    if f.id not in det.findings:
        raise KeyError(f"{det.id} emitted unregistered finding {f.id!r}")
    if f.severity not in SEVERITIES or not f.evidence:
        raise ValueError(f"{det.id}: {f.id} needs a known severity and evidence")
    return {
        "id": f.id,
        "family": det.family,
        "severity": f.severity,
        "score": round(f.score, 2),
        "claim": f.claim[:CLAIM_CHARS],
        "facts": f.facts,
        "subjects": f.subjects,
        "evidence": f.evidence,
        "advice_id": det.findings[f.id],
        "detector": det.id,
    }


def rank_key(row: dict[str, Any]) -> tuple[int, float, str]:
    return SEVERITIES.index(row["severity"]), -row["score"], row["id"]


def run(rpt: br.Report, families: set[str] | None = None) -> dict[str, Any]:
    """Every selected detector, each fail-soft; findings ranked, inputs classified."""
    load()
    ctx = Context(rpt)
    findings: list[dict[str, Any]] = []
    not_parsed: list[dict[str, Any]] = []
    inputs: dict[str, dict[str, Any]] = {}
    ran = 0
    for det in sorted(REGISTRY.values(), key=lambda d: d.id):
        if families is not None and det.family not in families:
            continue
        ran += 1
        status: dict[str, Any] = {
            name: "parsed" if rpt.find(name) else "absent" for name in det.inputs
        }
        try:
            findings.extend(_row(det, f) for f in det.fn(ctx))
        except NotParsed as exc:
            route = _route(ctx, exc.section)
            not_parsed.append(_skip(det, exc.section, exc.reason, route))
            status[exc.section] = {"status": "fallback", "route": route}
        except Exception as exc:  # fail soft: the run never dies on one detector
            section = det.inputs[0] if det.inputs else ""
            not_parsed.append(
                _skip(det, section, f"error: {type(exc).__name__}", _route(ctx, section))
            )
        inputs[det.id] = status
    findings.sort(key=rank_key)
    return {
        "ctx": ctx,
        "findings": findings,
        "not_parsed": not_parsed,
        "detectors_run": ran,
        "inputs": inputs,
    }


def _skip(det: Detector, section: str, reason: str, route: str) -> dict[str, Any]:
    return {
        "detector": det.id,
        "family": det.family,
        "section": section,
        "reason": reason,
        "route": route,
    }


def views(ctx: Context, slugs: list[str]) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    """The family tables `--family` asks for; a failing view is a `not_parsed` row."""
    load()
    out: dict[str, Any] = {}
    failed: list[dict[str, Any]] = []
    for slug in slugs:
        fn = VIEWS.get(slug)
        if fn is None:
            continue
        try:
            out[slug] = fn(ctx)
        except Exception as exc:  # same rule as detectors
            reason = exc.reason if isinstance(exc, NotParsed) else f"error: {type(exc).__name__}"
            section = exc.section if isinstance(exc, NotParsed) else ""
            failed.append(
                {
                    "detector": f"view.{slug}",
                    "family": SLUGS[slug],
                    "section": section,
                    "reason": reason,
                    "route": _route(ctx, section),
                }
            )
    return out, failed


def catalogue_md() -> str:
    """`references/detectors.md`, generated from the registry (`make sync-bugreport-detectors`)."""
    load()
    out = [
        "# Detector catalogue",
        "",
        "Generated from the detector registry by `make sync-bugreport-detectors`; do not edit.",
        "The advice column names the remedy's entry in `advice.md`.",
    ]
    for fam, slug in FAMILIES.items():
        dets = sorted((d for d in REGISTRY.values() if d.family == fam), key=lambda d: d.id)
        out += [
            "",
            f"## {fam} {slug}",
            "",
            "| detector | finding | advice | inputs |",
            "|---|---|---|---|",
        ]
        for d in dets:
            inputs = ", ".join(f"`{i}`" for i in d.inputs)
            for fid, aid in d.findings.items():
                out.append(f"| `{d.id}` | `{fid}` | `{aid}` | {inputs} |")
    return "\n".join(out) + "\n"
