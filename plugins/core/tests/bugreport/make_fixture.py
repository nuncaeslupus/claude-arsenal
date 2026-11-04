#!/usr/bin/env python3
"""Build synthetic Android bugreports for the bugreport tests (spec 0005 § 5.11).

No real report, and no excerpt of one, is ever committed (D-9). Section bodies
come from `seeds/sections.tmpl`, written from field names and layouts; every
identifier is a reserved-range canary. The same arguments build the same bytes.

    python3 make_fixture.py --layout modern --seed 1 --out /tmp/x       # one report
    python3 make_fixture.py --layout modern --target-mb 160 --out /tmp  # benchmark size
"""

from __future__ import annotations

import argparse
import codecs
import datetime as dt
import io
import random
import re
import tempfile
import zipfile
from collections.abc import Iterable, Sequence
from pathlib import Path
from typing import Any

SEEDS = Path(__file__).resolve().parent / "seeds"

LAYOUTS = ("pre-p", "modern", "samsung", "xiaomi", "oneplus", "huawei", "android9")
CONTAINERS = ("txt", "zip", "zip-bare", "zip-text")
TRAPS = ("cr", "utf16", "nul", "locale", "unsampled-pss", "timeout", "dup-service")
SCENARIOS = ("multi-day", "new-year", "no-clock")

UTC_OFFSET_S = 3600  # Europe/Berlin in November and January
KERNEL_MARKER_AGO_S = 425  # the lowmemorykiller line sits this far before capture
QUIET = (dt.timedelta(minutes=22, seconds=5), dt.timedelta(minutes=17, seconds=5))


def _luhn_digit(body: str) -> str:
    total = 0
    for i, ch in enumerate(reversed(body)):
        d = int(ch)
        if i % 2 == 0:
            d *= 2
            if d > 9:
                d -= 9
        total += d
    return str((10 - total % 10) % 10)


# One identifier of every § 5.10 kind, each from a reserved range.
CANARIES = {
    "email": "canary.user@example.com",
    "account": "canary.user@example.com",
    "phone": "+12025550142",
    "mac": "00:00:5e:00:53:2a",
    "imei": "00100100424242" + _luhn_digit("00100100424242"),  # test TAC 001001
    "iccid": "899999000042424242" + _luhn_digit("899999000042424242"),  # 89 + test issuer 9999
    "imsi": "310999000000001",  # MCC 310, an MNC no carrier holds
    "serial": "EXAMPLE0SN0042",
    "ssid": "ExampleNet-Canary",
    "coord": "0.001234,-0.004567",
}

_LAYOUT = {
    "pre-p": ("8.1.0", 27, "Google", "Example Phone 1", "example1", False),
    "modern": ("14", 34, "Google", "Example Phone 8", "example8", True),
    "samsung": ("13", 33, "samsung", "Example Galaxy", "examplegx", True),
    "xiaomi": ("12", 31, "Xiaomi", "Example Mi", "examplemi", True),
    "oneplus": ("11", 30, "OnePlus", "Example One", "exampleone", True),
    "huawei": ("10", 29, "HUAWEI", "Example Hw", "examplehw", True),
    "android9": ("9", 28, "Google", "Example Phone 3", "example3", True),
}
_OEM_SECTIONS = {
    "samsung": ("AP RESET INFO EXTEND", "SEC_MEDIA", "End of OLOG"),
    "xiaomi": ("POWERUP_REASON", "qsee_log", "PERFLOCK HISTORY"),
    "oneplus": ("OMMSERVICE",),
    "huawei": ("KERNEL LIVE PATCH",),
    "android9": ("QTAGUID NETWORK INTERFACES INFO",),
}
_DUMPSYS = (
    "account",
    "alarm",
    "battery",
    "batterystats",
    "diskstats",
    "iphonesubinfo",
    "location",
    "meminfo",
    "package",
    "procstats",
    "telephony.registry",
    "wifi",
    "activity",
)
_RULE = "-" * 79


def seeds() -> dict[str, str]:
    """`@@ name` blocks of the seed file, by name."""
    blocks: dict[str, list[str]] = {}
    current: list[str] | None = None
    for line in (SEEDS / "sections.tmpl").read_text(encoding="utf-8").splitlines():
        if line.startswith("@@ "):
            current = blocks.setdefault(line[3:], [])
        elif current is not None:
            current.append(line)
    return {k: "\n".join(v) for k, v in blocks.items()}


def _check(name: str, options: Sequence[str], given: Iterable[str]) -> None:
    unknown = sorted(set(given) - set(options))
    if unknown:
        raise ValueError(f"unknown {name}: {', '.join(unknown)} (known: {', '.join(options)})")


def _ts(t: dt.datetime) -> str:
    return t.strftime("%m-%d %H:%M:%S") + f".{t.microsecond // 1000:03d}"


def _model(layout: str, scenarios: Sequence[str], seed: int) -> dict[str, Any]:
    """Every value and log line a build renders; `facts` reads the same dict."""
    if layout not in _LAYOUT:
        raise ValueError(f"unknown layout {layout!r} (known: {', '.join(LAYOUTS)})")
    _check("scenario", SCENARIOS, scenarios)
    rng = random.Random(seed)
    release, sdk, oem, model, device, priority = _LAYOUT[layout]
    captured = (
        dt.datetime(2027, 1, 1, 0, 10, 5)
        if "new-year" in scenarios
        else dt.datetime(2026, 11, 3, 14, 22, 5)
    )
    uptime_s = 3 * 86400 + 4 * 3600 + 12 * 60  # whole minutes: the header prints no seconds
    clock = "no-clock" not in scenarios
    seed_blocks = seeds()

    def logs(block: str, step: tuple[int, int]) -> list[tuple[dt.datetime, str]]:
        messages = seed_blocks[block].splitlines()
        start, end = captured - dt.timedelta(minutes=82, seconds=5), captured
        quiet = (captured - QUIET[0], captured - QUIET[1])
        out: list[tuple[dt.datetime, str]] = []
        if "multi-day" in scenarios and block == "log_messages":
            t = start - dt.timedelta(hours=29)  # the previous day, 09:00
            while t < start - dt.timedelta(minutes=30):
                out.append((t, messages[len(out) % len(messages)]))
                t += dt.timedelta(minutes=37)
        t = start
        while t < end - dt.timedelta(seconds=1):
            if not quiet[0] <= t < quiet[1]:
                out.append((t, rng.choice(messages)))
            t += dt.timedelta(seconds=rng.randint(*step), milliseconds=rng.randint(0, 999))
        last = end - dt.timedelta(seconds=1)
        out.append((last.replace(microsecond=rng.randint(0, 999) * 1000), messages[0]))
        return out

    kernel: list[tuple[float, str]] = []
    k_messages = seed_blocks["kernel_messages"].splitlines()
    secs = uptime_s - 3000.0
    while secs < uptime_s - 5:
        kernel.append((secs, rng.choice(k_messages)))
        secs += rng.randint(60, 90) + rng.randint(0, 999999) / 1e6
    marker = float(uptime_s - KERNEL_MARKER_AGO_S)
    kernel.append((marker, "lowmemorykiller: Killing 'com.example.heavy' (4400), adj 900"))
    kernel.sort()
    return {
        "layout": layout,
        "release": release,
        "sdk": sdk,
        "oem": oem,
        "model": model,
        "device": device,
        "priority": priority,
        "captured": captured,
        "uptime_s": uptime_s,
        "clock": clock,
        "system_log": logs("log_messages", (20, 40)),
        "event_log": logs("event_messages", (60, 120)),
        "kernel": kernel,
        "kernel_marker_s": marker,
    }


def facts(layout: str, scenarios: Sequence[str] = (), *, seed: int = 0) -> dict[str, Any]:
    """What a build of these arguments must report: the oracle the tests compare to."""
    m = _model(layout, scenarios, seed)

    def bounds(rows: list[tuple[dt.datetime, str]]) -> list[str]:
        stamps = sorted(t for t, _ in rows)
        return [_fmt(stamps[0]), _fmt(stamps[-1])]

    captured = m["captured"]
    to_local = (
        (lambda s: _fmt(captured - dt.timedelta(seconds=m["uptime_s"] - s)))
        if m["clock"]
        else (lambda s: None)
    )
    return {
        "android_release": m["release"],
        "sdk": m["sdk"],
        "oem": m["oem"],
        "model": m["model"],
        "captured": _fmt(captured)[:19],
        "uptime_s": m["uptime_s"],
        "utc_offset_s": UTC_OFFSET_S if m["clock"] else None,
        "bounds": {
            "SYSTEM LOG": bounds(m["system_log"]),
            "EVENT LOG": bounds(m["event_log"]),
            "KERNEL LOG": [to_local(m["kernel"][0][0]), to_local(m["kernel"][-1][0])],
        },
        "kernel_marker_local": to_local(m["kernel_marker_s"]),
    }


def _fmt(t: dt.datetime) -> str:
    return t.strftime("%Y-%m-%d %H:%M:%S") + f".{t.microsecond // 1000:03d}"


_VAR = re.compile(r"\{\{(\w+)\}\}")


def _fill(text: str, values: dict[str, str]) -> str:
    return _VAR.sub(lambda m: values[m.group(1)], text)


def render(
    layout: str,
    scenarios: Sequence[str] = (),
    *,
    seed: int = 0,
    traps: Sequence[str] = (),
    target_mb: float | None = None,
) -> str:
    """The dumpstate text of one fixture, before container and encoding traps."""
    _check("trap", TRAPS, traps)
    m = _model(layout, scenarios, seed)
    rng = random.Random(seed + 1)
    blocks = seeds()
    captured: dt.datetime = m["captured"]
    utc = (captured - dt.timedelta(seconds=UTC_OFFSET_S)).replace(tzinfo=dt.UTC)
    now_rtc = int(utc.timestamp()) * 1000
    locale = "locale" in traps
    values = {
        **CANARIES,
        "captured": captured.strftime("%Y-%m-%d %H:%M:%S"),
        "build": f"EX{m['sdk']}A.261005.042",
        "brand": m["oem"].lower(),
        "device": m["device"],
        "release": m["release"],
        "sdk": str(m["sdk"]),
        "oem": m["oem"],
        "model": m["model"],
        "timezone": "Europe/Berlin",
        "uptime_days": str(m["uptime_s"] // 86400),
        "uptime_hm": f"{m['uptime_s'] % 86400 // 3600}:{m['uptime_s'] % 3600 // 60:02d}",
        "now_rtc": str(now_rtc),
        "now_elapsed": str(m["uptime_s"] * 1000),
        "free_ram": "2.612.345K" if locale else "2,612,345K",
        "sys_total": "1,9GB" if locale else "1.9GB",
        "pct": "0,00%" if locale else "61%",
        "pss_triple": (
            ("0,00-0,00-0,00" if locale else "0.00-0.00-0.00")
            if "unsampled-pss" in traps
            else "45MB-52MB-60MB"
        ),
    }

    def body(name: str) -> str:
        return _fill(blocks[name], values)

    out: list[str] = []

    def top(title: str, text: str) -> None:
        out.append(f"------ {title} ------")
        if text:
            out.append(text)
        out.append(f"------ 0.{rng.randint(10, 999):03d}s was the duration of '{title}' ------")

    def services(title: str, names: Sequence[str], block: str | None) -> None:
        lines: list[str] = []
        for name in names:
            lines.append(_RULE)
            lines.append(f"DUMP OF SERVICE {block + ' ' if block else ''}{name}:")
            lines.append(
                _pad_body(name, rng) if name.startswith("example_pad") else body(f"svc_{name}")
            )
            stamp = captured.strftime("%Y-%m-%d %H:%M:%S")
            dur = f"0.{rng.randint(1, 999):03d}"
            lines.append(f"--------- {dur}s was the duration of dumpsys {name}, ending at: {stamp}")
        top(title, "\n".join(lines))

    out.append(body("header"))
    fill = blocks["header_fill"].splitlines()
    out.extend(f"{fill[i % len(fill)]} ({i})" for i in range(30))
    if m["priority"]:
        out.append(blocks["format_line"])
    out.append("")
    if m["priority"]:
        services(
            "DUMPSYS CRITICAL (/system/bin/dumpsys -T 10000 --priority CRITICAL)",
            ["power"],
            "CRITICAL",
        )
        high = ["thermalservice"] + (["meminfo"] if "dup-service" in traps else [])
        services("DUMPSYS HIGH (/system/bin/dumpsys -T 10000 --priority HIGH)", high, "HIGH")
    props = body("props")
    if not m["clock"]:
        props = "\n".join(ln for ln in props.splitlines() if "persist.sys.timezone" not in ln)
    top("SYSTEM PROPERTIES (getprop)", props)
    top(
        "SYSTEM LOG (logcat -v threadtime -v printable -v uid -d *:v)",
        _logcat(m["system_log"], traps, rng),
    )
    top(
        "EVENT LOG (logcat -b events -v threadtime -v printable -v uid -d *:v)",
        _logcat(m["event_log"], (), rng),
    )
    top("KERNEL LOG (dmesg)", "\n".join(f"<6>[{s:12.6f}] {msg}" for s, msg in m["kernel"]))
    top("CHECKIN BATTERYSTATS (/system/bin/dumpsys -T 30000 batterystats -c)", body("checkin"))
    top("PROCESSES AND THREADS (ps -A -T -Z -O pri,nice,rtprio,sched,pcy,time)", body("ps"))
    for name in _OEM_SECTIONS.get(layout, ()):
        top(f"{name} (/proc/example/{name.lower().replace(' ', '_')})", body(f"oem_{name}"))
    if "timeout" in traps:
        top(
            "EXAMPLE HAL DUMP (/vendor/bin/example_dump)",
            "*** command '/vendor/bin/example_dump' timed out after 10.000s (killing pid 4242)",
        )
    names = [n for n in _DUMPSYS if m["clock"] or n != "alarm"]
    if not m["priority"]:
        names = ["power", "thermalservice", *names]
    if target_mb:
        names += [f"example_pad{i}" for i in range(_pad_count(target_mb))]
    services(
        "DUMPSYS NORMAL (/system/bin/dumpsys)"
        if layout == "samsung"
        else "DUMPSYS (/system/bin/dumpsys)",
        names,
        None,
    )
    out.append("")
    return "\n".join(out)


def _logcat(rows: list[tuple[dt.datetime, str]], traps: Sequence[str], rng: random.Random) -> str:
    lines = []
    for i, (t, spec) in enumerate(rows):
        level, tag, msg = spec.split("|", 2)
        if "cr" in traps and i % 7 == 3:
            msg = msg.replace(" ", "\r", 1)  # same length: offsets must not move
        if "nul" in traps and i % 11 == 5:
            msg = msg[:-1] + "\0"
        uid, pid = rng.choice(((1000, 1234), (10234, 4321), (10211, 4400), (1001, 2100)))
        lines.append(
            f"{_ts(t)}  {uid:>5} {pid:>5} {pid + rng.randint(0, 40):>5} {level} {tag}: {msg}"
        )
    return "\n".join(lines)


_PAD_BYTES = 4 << 20


def _pad_count(target_mb: float) -> int:
    return max(1, int(target_mb * (1 << 20) / _PAD_BYTES))


def _pad_body(name: str, rng: random.Random) -> str:
    """About 4 MiB of package-shaped lines, the shape of the big real sections."""
    lines = []
    size = 0
    i = 0
    while size < _PAD_BYTES:
        line = (
            f"  Package [com.example.{name}.p{i}] ({rng.getrandbits(28):07x}):\n"
            f"    userId={10000 + i % 9000}\n"
            f"    versionCode={rng.randint(1, 99999)} minSdk=26 targetSdk=34\n"
            f"    lastUpdateTime=2026-10-{1 + i % 28:02d} 12:00:00"
        )
        lines.append(line)
        size += len(line) + 1
        i += 1
    return "\n".join(lines)


_ZIP_DATE = (2026, 11, 3, 14, 22, 5)


def _zip(members: list[tuple[str, bytes]]) -> bytes:
    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w") as zf:
        for name, data in members:
            info = zipfile.ZipInfo(name, date_time=_ZIP_DATE)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            zf.writestr(info, data)
    return buf.getvalue()


def build(
    layout: str,
    scenarios: Sequence[str] = (),
    *,
    seed: int = 0,
    target_mb: float | None = None,
    container: str = "txt",
    traps: Sequence[str] = (),
    main_name: str | None = None,
    out_dir: str | Path | None = None,
) -> Path:
    """Write one fixture and return its path. Same arguments, same bytes."""
    if container not in CONTAINERS:
        raise ValueError(f"unknown container {container!r} (known: {', '.join(CONTAINERS)})")
    text = render(layout, scenarios, seed=seed, traps=traps, target_mb=target_mb)
    if "utf16" in traps:
        data = codecs.BOM_UTF16_LE + text.encode("utf-16-le")
    else:
        data = text.encode("utf-8")
        if "nul" in traps:
            data = data.replace(b"Timeout reading", b"Timeout \xff\xfeading", 1)
    out = Path(out_dir) if out_dir else Path(tempfile.mkdtemp(prefix="bugreport-fixture-"))
    out.mkdir(parents=True, exist_ok=True)
    tag = "+".join([layout, *scenarios, *traps]) + f"-{seed}"
    if container == "txt":
        path = out / f"{tag}.txt"
        path.write_bytes(data)
        return path
    stamp = "2026-11-03-14-22-05"
    if container == "zip":
        name = main_name or f"bugreport-example-{stamp}.txt"
        members = [
            ("version.txt", b"2.0"),
            ("main_entry.txt", name.encode()),
            (name, data),
            ("dumpstate_board.txt", b"board: example\n"),
            (
                "FS/data/anr/anr_2026-11-03-14-10-00-123",
                b"----- pid 4321 at 2026-11-03 14:10:00 -----\n",
            ),
            ("FS/data/tombstones/tombstone_00", b"*** *** *** example tombstone\n"),
        ]
    elif container == "zip-bare":
        name = main_name or f"dumpstate-{stamp}.txt"
        members = [
            (name, data),
            ("dumpstate_board.txt", b"== dumpstate: board only\n"),
            ("FS/data/anr/anr_2026-11-03-14-10-00-123", b"----- pid 4321 -----\n"),
        ]
    else:
        members = [(main_name or "dumpstate.txt", data)]
    path = out / f"{tag}-{container}.zip"
    path.write_bytes(_zip(members))
    return path


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    p.add_argument("--layout", choices=LAYOUTS, default="modern")
    p.add_argument("--scenario", action="append", default=[], choices=SCENARIOS)
    p.add_argument("--trap", action="append", default=[], choices=TRAPS)
    p.add_argument("--container", choices=CONTAINERS, default="txt")
    p.add_argument("--seed", type=int, default=0)
    p.add_argument("--target-mb", type=float)
    p.add_argument("--out", required=True, help="directory to write into")
    a = p.parse_args(argv)
    path = build(
        a.layout,
        a.scenario,
        seed=a.seed,
        target_mb=a.target_mb,
        container=a.container,
        traps=a.trap,
        out_dir=a.out,
    )
    print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
