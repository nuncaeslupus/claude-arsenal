#!/usr/bin/env python3
"""Read an Android bugreport section by section, without loading it into context.

    query_bugreport.py sections --input R [--grep RE]            # the section map
    query_bugreport.py locate   --input R --grep RE              # hits per section, no lines
    query_bugreport.py sample   --input R --section ID           # first lines + format + shape
    query_bugreport.py show     --input R --section ID [--grep RE] [--context N]
    query_bugreport.py timeline --input R --since T [--window D] # merged events, local time
    query_bugreport.py summary  --input R                        # device, build, coverage

Every command prints one JSON document, capped (4096 B; 2048 for sample, locate
and summary) by dropping whole rows; `--limit 0` or `--output FILE` gets all of
it. Identifiers are redacted unless `--no-redact`. Exit 0 ran, 1 the data cannot
answer, 2 bad usage or internal error.
"""

from __future__ import annotations

import argparse
import datetime as dt
import re
import sys
from typing import Any

import _brlib as br
import _console as console
import _summary

SAMPLE_LINES = 20
LINE_CHARS = 200
MARKERS = re.compile(
    r"ANR in|am_anr|am_kill|lowmemorykiller|FATAL EXCEPTION|am_crash|boot_progress|thermal",
    re.I,
)


def _emit(
    args: argparse.Namespace,
    rpt: br.Report,
    schema: str,
    rows: list[Any],
    cap: int,
    extra: dict[str, Any] | None = None,
) -> int:
    redact = rpt.redactor(not args.no_redact)
    rows = [redact(r) for r in rows]
    extra = redact(extra) if extra else extra  # type: ignore[assignment]
    limit = 0 if args.output else args.limit
    br.write_doc(br.budget(schema, rows, limit=limit, cap=cap, extra=extra), args.output)
    return 0


# --------------------------------------------------------------------------- sections / locate


def cmd_sections(args: argparse.Namespace, rpt: br.Report) -> int:
    pattern = re.compile(args.grep) if args.grep else None
    keys = ("id", "kind", "block", "start", "size", "timed_out")
    rows = [{k: s[k] for k in keys} for s in rpt.sections if not pattern or pattern.search(s["id"])]
    return _emit(args, rpt, "bugreport.query.sections/1", rows, br.OUTPUT_BUDGET)


def cmd_locate(args: argparse.Namespace, rpt: br.Report) -> int:
    pattern = re.compile(args.grep.encode())
    hits: dict[str, dict[str, Any]] = {}
    for m in pattern.finditer(rpt.mm):
        sec = rpt.section_at(m.start())
        sid = sec["id"] if sec else "(header)"
        row = hits.setdefault(sid, {"id": sid, "hits": 0, "first": m.start()})
        row["hits"] += 1
    rows = sorted(hits.values(), key=lambda r: -r["hits"])
    return _emit(args, rpt, "bugreport.query.locate/1", rows, br.SMALL_BUDGET)


# --------------------------------------------------------------------------- sample


_KV = re.compile(r"^\s*([A-Za-z_][\w .\-/\[\]]{0,60}?)\s*[:=]\s*\S")


def sniff(lines: list[str]) -> tuple[str, list[str]]:
    """(format, record shape) of a section's first lines; § 5.7 order, 0.6 threshold."""
    if not lines:
        return "unknown", []

    def share(pred: Any) -> float:
        return sum(1 for ln in lines if pred(ln)) / len(lines)

    def logline(ln: str) -> re.Match[str] | None:
        return br._LOGCAT_LINE.match(ln) or br._KERNEL_LINE.match(ln)

    if share(logline) >= 0.6:
        tags = [m.group(3) for ln in lines if (m := br._LOGCAT_LINE.match(ln))]
        return "log", _uniq(tags or ["kernel"])
    if share(lambda ln: ln.count(",") >= 3 and " " not in ln.strip()) >= 0.6:
        pairs = []
        for ln in lines:
            fields = [f for f in ln.split(",") if f and not f.lstrip("-").isdigit()]
            pairs.append(",".join(fields[:2]))
        return "csv", _uniq(pairs)
    indents = {len(ln) - len(ln.lstrip()) for ln in lines}
    if len(indents) >= 3:
        low = min(indents)
        tops = [ln.strip().split(":")[0][:60] for ln in lines if len(ln) - len(ln.lstrip()) == low]
        return "tree", _uniq(tops)
    if share(_KV.match) >= 0.6:
        return "kv", _uniq([m.group(1).strip() for ln in lines if (m := _KV.match(ln))])
    head = lines[0].split()
    if len(head) >= 3 and share(lambda ln: len(ln.split()) == len(head)) >= 0.6:
        return "table", head
    return "unknown", []


def _uniq(items: list[str]) -> list[str]:
    return list(dict.fromkeys(items))[:SAMPLE_LINES]


def cmd_sample(args: argparse.Namespace, rpt: br.Report) -> int:
    sec = rpt.select(args.section)
    lines: list[str] = []
    want = args.limit or SAMPLE_LINES
    for i, (_, line) in enumerate(rpt.lines(sec)):
        if i == 0 or not line.strip() or line.startswith("-" * 10):
            continue  # the opener and the dumpsys rule line
        lines.append(line[:LINE_CHARS])
        if len(lines) >= want:
            break
    fmt, shape = sniff(lines)
    extra = {"section": sec["id"], "format": fmt, "shape": shape}
    args.limit = None  # --limit chose how many lines to read; the byte cap still holds
    return _emit(args, rpt, "bugreport.query.sample/1", lines, br.SMALL_BUDGET, extra)


# --------------------------------------------------------------------------- show


def cmd_show(args: argparse.Namespace, rpt: br.Report) -> int:
    sec = rpt.select(args.section)
    pattern = re.compile(args.grep) if args.grep else None
    all_lines = list(rpt.lines(sec))
    keep: set[int] = set()
    for i, (_, line) in enumerate(all_lines):
        if pattern is None or pattern.search(line):
            keep.update(range(max(0, i - args.context), min(len(all_lines), i + args.context + 1)))
    rows = [{"offset": all_lines[i][0], "line": all_lines[i][1]} for i in sorted(keep)]
    return _emit(
        args, rpt, "bugreport.query.show/1", rows, br.OUTPUT_BUDGET, {"section": sec["id"]}
    )


# --------------------------------------------------------------------------- timeline

_DUR = re.compile(r"^(\d+)([smh])$")
_SINCE = re.compile(
    r"^(?:(?:(?P<y>\d{4})-)?(?P<mo>\d\d)-(?P<d>\d\d)\s+)?(?P<h>\d\d?):(?P<mi>\d\d)(?::(?P<s>\d\d))?$"
)
_UNIT = {"s": 1, "m": 60, "h": 3600}


def _duration(text: str, flag: str) -> dt.timedelta:
    m = _DUR.match(text.strip())
    if not m:
        raise br.UsageError(f"{flag} {text!r}: use a duration like 90s, 5m or 1h")
    return dt.timedelta(seconds=int(m.group(1)) * _UNIT[m.group(2)])


def resolve_since(
    text: str, span: tuple[dt.datetime, dt.datetime], captured: dt.datetime
) -> dt.datetime:
    """`--since` against the report span (§ 5.5): exit 2 ambiguous, exit 1 outside."""
    first, last = span
    text = text.strip()
    if text.startswith("-"):
        since = captured - _duration(text[1:], "--since")
    else:
        m = _SINCE.match(text)
        if not m:
            raise br.UsageError(
                f"--since {text!r}: use HH:MM[:SS], MM-DD HH:MM, YYYY-MM-DD HH:MM or -30m"
            )
        clock = dt.time(int(m["h"]), int(m["mi"]), int(m["s"] or 0))
        if m["mo"]:
            stamp = f"{m['mo']}-{m['d']} {clock:%H:%M:%S}.000"
            since = (
                dt.datetime(int(m["y"]), int(m["mo"]), int(m["d"])).replace(
                    hour=clock.hour, minute=clock.minute, second=clock.second
                )
                if m["y"]
                else br.logcat_time(stamp, captured)
            )
        else:
            days = (last.date() - first.date()).days
            cands = [
                dt.datetime.combine(first.date() + dt.timedelta(days=i), clock)
                for i in range(days + 1)
            ]
            inside = [c for c in cands if first <= c <= last]
            if len(inside) > 1:
                listing = ", ".join(f"{c:%Y-%m-%d %H:%M}" for c in inside)
                raise br.UsageError(
                    f"--since {text} is ambiguous: the logs cover {first:%Y-%m-%d %H:%M} … "
                    f"{last:%Y-%m-%d %H:%M}\n  candidates: {listing}\n"
                    f'  pass a date, e.g. --since "{inside[-1]:%Y-%m-%d %H:%M}"'
                )
            since = inside[0] if inside else cands[0]
    if not first <= since <= last:
        raise br.ReportError(
            f"--since {text}: time outside report span {br.fmt_ts(first)} … {br.fmt_ts(last)}"
        )
    return since


def _fold_note(since: dt.datetime, tz: str | None) -> None:
    if not tz:
        return
    try:
        from zoneinfo import ZoneInfo

        z = ZoneInfo(tz)
    except (ImportError, ValueError, KeyError, OSError):
        return
    if since.replace(tzinfo=z, fold=0).utcoffset() != since.replace(tzinfo=z, fold=1).utcoffset():
        console.warn(
            f"{since:%Y-%m-%d %H:%M} falls in a DST fold in {tz}; its first occurrence is used"
        )


def cmd_timeline(args: argparse.Namespace, rpt: br.Report) -> int:
    captured = rpt.captured
    if captured is None:
        raise br.ReportError("the report has no `== dumpstate:` capture time to anchor logcat")
    window = _duration(args.window, "--window")
    pattern = re.compile(args.grep) if args.grep else None

    def wanted(e: dict[str, Any]) -> bool:
        text = f"{e['tag']} {e['text']}"
        if pattern:
            return bool(pattern.search(text))
        return e["level"] in ("W", "E", "F", "A") or bool(MARKERS.search(text))

    timed: list[dict[str, Any]] = []
    elapsed: list[dict[str, Any]] = []
    for e in rpt.events():
        (timed if e["t"] is not None else elapsed).append(e)
    if not timed:
        raise br.ReportError("no timestamped log lines in the report")
    span = (min(e["t"] for e in timed), max(e["t"] for e in timed))
    since = resolve_since(args.since, span, captured)
    _fold_note(since, rpt.clock.get("tz"))
    until = since + window
    rows = [
        _row(e)
        for e in sorted(timed, key=lambda e: e["t"])
        if since <= e["t"] < until and wanted(e)
    ]
    extra_rows = [_row(e) for e in elapsed if wanted(e)]
    if elapsed:
        console.warn(
            f"{len(elapsed)} kernel lines have no local time (clock source: none); "
            f"{len(extra_rows)} matching ones are appended with elapsed seconds"
        )
    extra = {"since": br.fmt_ts(since), "until": br.fmt_ts(until), "clock": rpt.clock["source"]}
    return _emit(
        args, rpt, "bugreport.query.timeline/1", rows + extra_rows, br.OUTPUT_BUDGET, extra
    )


def _row(e: dict[str, Any]) -> dict[str, Any]:
    row: dict[str, Any] = {
        "t": br.fmt_ts(e["t"]) if e["t"] is not None else None,
        "src": e["src"],
        "tag": e["tag"],
        "level": e["level"],
        "text": e["text"][:LINE_CHARS],
        "offset": e["offset"],
    }
    if e["t"] is None:
        row.update(elapsed_s=e["elapsed_s"], clock="elapsed")
    return row


# --------------------------------------------------------------------------- summary


def cmd_summary(args: argparse.Namespace, rpt: br.Report) -> int:
    doc = rpt.redactor(not args.no_redact)(_summary.summarize(rpt))
    br.write_doc(doc, args.output)  # type: ignore[arg-type]
    return 0


# --------------------------------------------------------------------------- CLI


def _parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)

    def command(name: str, help_: str) -> argparse.ArgumentParser:
        c = sub.add_parser(name, help=help_)
        br.add_report_args(c)
        br.add_output_args(c)
        return c

    c = command("sections", "list every section: id, kind, block, offset, size")
    c.add_argument("--grep", help="regex over section ids")
    c = command("locate", "hit count and first byte offset per section")
    c.add_argument("--grep", required=True, help="regex over the raw bytes")
    c = command("sample", "first lines of one section, its format and record shape")
    c.add_argument("--section", required=True, help="id (meminfo#1) or a unique name")
    c = command("show", "lines of one section with byte offsets")
    c.add_argument("--section", required=True, help="id (meminfo#1) or a unique name")
    c.add_argument("--grep", help="regex; only matching lines (plus --context)")
    c.add_argument("--context", type=int, default=0, help="lines around each match")
    c = command("timeline", "merged log events in device local time")
    c.add_argument("--since", required=True, help="HH:MM[:SS], MM-DD HH:MM, YYYY-MM-DD HH:MM, -30m")
    c.add_argument("--window", default="5m", help="duration from --since: 90s, 5m, 1h")
    c.add_argument("--grep", help="regex over tag and message (default: level >= W + markers)")
    command("summary", "device, build, capture, coverage per source, file stats")
    return p


_COMMANDS = {
    "sections": cmd_sections,
    "locate": cmd_locate,
    "sample": cmd_sample,
    "show": cmd_show,
    "timeline": cmd_timeline,
    "summary": cmd_summary,
}


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    # argparse before 3.14 reads `--since -30m` as two flags; bind the value explicitly
    for i, a in enumerate(argv[:-1]):
        if a == "--since" and argv[i + 1].startswith("-"):
            argv[i : i + 2] = [f"--since={argv[i + 1]}"]
            break
    args = _parser().parse_args(argv)

    def go() -> int:
        rpt = br.open_report(args.input, output_dir=args.output_dir, force=args.force)
        return _COMMANDS[args.cmd](args, rpt)

    return br.run(go)


if __name__ == "__main__":
    # Windows consoles default to a legacy codepage; a non-ASCII line must
    # degrade to "?", never take the process down.
    for _stream in (sys.stdout, sys.stderr):
        if hasattr(_stream, "reconfigure"):
            _stream.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(main())
