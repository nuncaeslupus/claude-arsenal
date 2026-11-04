"""Shared substrate of the bugreport scripts — no CLI.

Input resolution (txt / zip / UTF-16), the section scanner, the index and its
cache, bounded slice reads, tolerant numbers, the clock behind timestamps, and
the capped JSON output every script prints. Stdlib only.

Everything reads the report in binary mode: text mode turns a bare `\\r` into a
line break and shifts every offset after it.
"""

from __future__ import annotations

import argparse
import bisect
import codecs
import contextlib
import datetime as dt
import hashlib
import json
import mmap
import os
import re
import shutil
import sys
import tempfile
import zipfile
from collections.abc import Callable, Iterator, Sequence
from pathlib import Path
from typing import Any

import _console as console
import _redact

INDEX_SCHEMA = "bugreport.index/1"
KEEP_KEYS = 5  # cache entries kept per root; a starting value, not a measured one
EXTRACT_CEILING = 2 << 30  # decompressed bytes; a corrupt or hostile zip stops here
CHUNK = 1 << 20
HEAD = 64 << 10
OUTPUT_BUDGET = 4096
SMALL_BUDGET = 2048  # sample, locate, summary
FULL_HINT = "rerun with --limit 0 or --output FILE"

_HEADER_RE = re.compile(r"^(?:== dumpstate: \d{4}-\d{2}-\d{2}|Bugreport format version:)", re.M)
_SKIP_ENTRIES = {"version.txt", "main_entry.txt", "dumpstate_board.txt", "dumpstate_log.txt"}
_KEY_DIR = re.compile(r"^[0-9a-f]{16}$")


class ReportError(Exception):
    """The data cannot serve the request — exit 1."""


class NotABugreport(ReportError):
    """The input is readable but holds no dumpstate text — exit 1 with the reason."""


class UsageError(Exception):
    """A bad or ambiguous argument — exit 2."""


# --------------------------------------------------------------------------- cache


def cache_root() -> Path:
    if sys.platform == "win32":
        base = Path(os.environ.get("LOCALAPPDATA") or Path.home() / "AppData" / "Local")
        return base / "claude-arsenal" / "bugreport" / "Cache"
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Caches" / "claude-arsenal" / "bugreport"
    base = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    return base / "claude-arsenal" / "bugreport"


def input_key(path: Path) -> tuple[str, dict[str, Any]]:
    """Cheap identity: size, mtime and a hash of the first and last MiB."""
    st = path.stat()
    h = hashlib.sha256()
    with path.open("rb") as f:
        h.update(f.read(CHUNK))
        if st.st_size > CHUNK:
            f.seek(max(CHUNK, st.st_size - CHUNK))
            h.update(f.read(CHUNK))
    ht = h.hexdigest()
    key = hashlib.sha256(f"{st.st_size}:{st.st_mtime_ns}:{ht}".encode()).hexdigest()[:16]
    return key, {"size": st.st_size, "mtime_ns": st.st_mtime_ns, "head_tail_sha256": ht}


def _write_atomic(dest: Path, data: bytes) -> None:
    fd, tmp = tempfile.mkstemp(dir=dest.parent, prefix=".tmp-")  # created 0600
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
        Path(tmp).replace(dest)
    except BaseException:
        with contextlib.suppress(OSError):
            Path(tmp).unlink()
        raise


def _is_ours(d: Path) -> bool:
    if not _KEY_DIR.match(d.name) or not d.is_dir():
        return False
    try:
        return bool(json.loads((d / "index.json").read_text())["schema"] == INDEX_SCHEMA)
    except (OSError, ValueError, KeyError, TypeError):
        return False


def prune(root: Path, keep: str) -> None:
    """Keep the KEEP_KEYS most recently used entries this skill created."""
    entries = []
    for d in root.iterdir():
        if d.name != keep and _is_ours(d):
            entries.append(((d / "index.json").stat().st_mtime_ns, d))
    entries.sort(reverse=True)
    for _, d in entries[KEEP_KEYS - 1 :]:
        shutil.rmtree(d, ignore_errors=True)


# --------------------------------------------------------------------------- input


def _is_utf16(head: bytes) -> bool:
    if head[:2] in (codecs.BOM_UTF16_LE, codecs.BOM_UTF16_BE):
        return True
    if len(head) < 64:
        return False
    even, odd = head[0::2], head[1::2]
    return max(even.count(0) / len(even), odd.count(0) / len(odd)) >= 0.30


def _head_text(head: bytes) -> str:
    if _is_utf16(head):
        enc = "utf-16" if head[:2] in (codecs.BOM_UTF16_LE, codecs.BOM_UTF16_BE) else "utf-16-le"
        return head.decode(enc, "replace")
    return head.decode("utf-8", "replace")


def looks_like_bugreport(head: bytes) -> bool:
    return bool(_HEADER_RE.search(_head_text(head)))


def main_entry(zf: zipfile.ZipFile) -> zipfile.ZipInfo:
    """The zip member holding the dumpstate text (§ 5.2)."""
    names = {i.filename: i for i in zf.infolist()}
    if "main_entry.txt" in names:
        named = zf.read("main_entry.txt").decode("utf-8", "replace").strip()
        if named in names:
            return names[named]
    texts = [
        i
        for i in zf.infolist()
        if i.filename.endswith(".txt")
        and not i.filename.startswith(("FS/", "proto/"))
        and Path(i.filename).name not in _SKIP_ENTRIES
    ]
    hits = []
    for i in texts:
        with zf.open(i) as f:
            if looks_like_bugreport(f.read(HEAD)):
                hits.append(i)
    if hits:
        return max(hits, key=lambda i: (i.file_size, i.filename))
    largest = sorted(
        (i for i in zf.infolist() if i.filename.endswith(".txt")), key=lambda i: -i.file_size
    )[:5]
    listing = ", ".join(f"{i.filename} ({i.file_size} B)" for i in largest) or "none"
    raise NotABugreport(f"no dumpstate text in the zip; largest text members: {listing}")


def _extract(zf: zipfile.ZipFile, info: zipfile.ZipInfo, dest: Path) -> None:
    fd, tmp = tempfile.mkstemp(dir=dest.parent, prefix=".tmp-")
    try:
        written = 0
        with os.fdopen(fd, "wb") as out, zf.open(info) as src:
            while chunk := src.read(CHUNK):
                written += len(chunk)
                if written > EXTRACT_CEILING:
                    raise ReportError(
                        f"{info.filename} decompresses past {EXTRACT_CEILING} bytes; refused"
                    )
                out.write(chunk)
        Path(tmp).replace(dest)
    except BaseException:
        with contextlib.suppress(OSError):
            Path(tmp).unlink()
        raise


def _transcode(src: Path, dest: Path) -> None:
    with src.open("rb") as f:
        bom = f.read(2)
    enc = "utf-16" if bom in (codecs.BOM_UTF16_LE, codecs.BOM_UTF16_BE) else "utf-16-le"
    fd, tmp = tempfile.mkstemp(dir=dest.parent, prefix=".tmp-")
    try:
        dec = codecs.getincrementaldecoder(enc)("replace")
        with os.fdopen(fd, "wb") as out, src.open("rb") as f:
            while chunk := f.read(CHUNK):
                out.write(dec.decode(chunk).encode("utf-8"))
            out.write(dec.decode(b"", final=True).encode("utf-8"))
        Path(tmp).replace(dest)
    except BaseException:
        with contextlib.suppress(OSError):
            Path(tmp).unlink()
        raise


# --------------------------------------------------------------------------- scanner

_TOP_RE = re.compile(rb"\n------ ([^\n]*?) ------\r?(?=\n)")
_SVC_RE = re.compile(rb"\nDUMP OF SERVICE (?:(CRITICAL|HIGH) )?(\S+?):[ \t]*\r?(?=\n)")
_SVC_END_RE = re.compile(rb"\n--------- ([\d.]+)s was the duration of dumpsys (\S+?),")
_TIMEOUT_RE = re.compile(rb"\n\*\*\* command '[^\n]*' timed out")
_CLOSER_RE = re.compile(r"^([\d.]+)s was the duration of '(.*)'$")


def section_name(title: str) -> str:
    """`SYSTEM LOG (logcat -v …)` -> `SYSTEM LOG`: split on the last ` (`."""
    if title.endswith(")") and " (" in title:
        return title[: title.rindex(" (")]
    return title


def scan(buf: mmap.mmap | bytes) -> list[dict[str, Any]]:
    """Every section, in file order, with byte offsets of its opening line."""
    size = len(buf)
    tops: list[dict[str, Any]] = []
    closers: list[tuple[int, float]] = []
    for m in _TOP_RE.finditer(buf):
        title = m.group(1).decode("utf-8", "replace")
        c = _CLOSER_RE.match(title)
        if c:
            closers.append((m.start(), float(c.group(1))))
            continue
        tops.append(
            {"name": section_name(title), "kind": "top", "block": None, "start": m.start() + 1}
        )
    for i, s in enumerate(tops):
        s["end"] = tops[i + 1]["start"] if i + 1 < len(tops) else size
    top_starts = [s["start"] for s in tops]

    def parent(off: int) -> dict[str, Any] | None:
        i = bisect.bisect_right(top_starts, off) - 1
        return tops[i] if i >= 0 else None

    for off, secs in closers:
        p = parent(off)
        if p is not None:
            p["duration_s"] = secs

    svcs: list[dict[str, Any]] = []
    for m in _SVC_RE.finditer(buf):
        block = m.group(1).decode() if m.group(1) else None
        svcs.append(
            {
                "name": m.group(2).decode("utf-8", "replace"),
                "kind": "service",
                "block": block,
                "start": m.start() + 1,
            }
        )
    for i, s in enumerate(svcs):
        p = parent(s["start"])
        limit = p["end"] if p else size
        nxt = svcs[i + 1]["start"] if i + 1 < len(svcs) else size
        s["end"] = min(limit, nxt)

    sections = sorted(tops + svcs, key=lambda s: (s["start"], s["kind"] != "top"))
    starts = [s["start"] for s in sections]
    for m in _SVC_END_RE.finditer(buf):
        sec = _innermost(sections, starts, m.start() + 1)
        if sec is not None and sec["kind"] == "service":
            sec["duration_s"] = float(m.group(1))
            sec["end"] = buf.find(b"\n", m.start() + 1) + 1 or size
    for m in _TIMEOUT_RE.finditer(buf):
        sec = _innermost(sections, starts, m.start() + 1)
        if sec is not None:
            sec["timed_out"] = True

    seen: dict[str, int] = {}
    for s in sections:
        seen[s["name"]] = seen.get(s["name"], 0) + 1
        s["id"] = f"{s['name']}#{seen[s['name']]}"
        s["size"] = s["end"] - s["start"]
        s.setdefault("duration_s", None)
        s.setdefault("timed_out", False)
    keys = ("id", "name", "kind", "block", "start", "end", "size", "duration_s", "timed_out")
    return [{k: s[k] for k in keys} for s in sections]


def _innermost(
    sections: Sequence[dict[str, Any]], starts: Sequence[int], off: int
) -> dict[str, Any] | None:
    i = bisect.bisect_right(starts, off) - 1
    while i >= 0:
        if sections[i]["end"] > off:
            return sections[i]
        i -= 1
    return None


def _count(buf: mmap.mmap, needle: bytes) -> int:
    return sum(buf[i : i + (16 << 20)].count(needle) for i in range(0, len(buf), 16 << 20))


# --------------------------------------------------------------------------- numbers

_THOUSANDS = re.compile(r"^-?\d{1,3}(?:,\d{3})+(?:\.\d+)?$")
_SIZE_RE = re.compile(r"^\s*(-?[\d.,]+)\s*([KMGT]?)(i?B)?\s*$", re.I)
_UNITS = {"": 1, "K": 1 << 10, "M": 1 << 20, "G": 1 << 30, "T": 1 << 40}


def parse_number(text: str) -> float:
    """`12,345` (grouping), `1,9` and `0,00` (locale decimal comma), `1.5`."""
    s = text.strip()
    if _THOUSANDS.match(s):
        return float(s.replace(",", ""))
    if s.count(".") > 1 and "," not in s:  # `2.612.345`: dot grouping; one dot stays a decimal
        return float(s.replace(".", ""))
    if "," in s and "." in s:
        s = (
            s.replace(".", "").replace(",", ".")
            if s.rindex(",") > s.rindex(".")
            else s.replace(",", "")
        )
    return float(s.replace(",", "."))


def parse_size(text: str) -> float:
    """`1,9GB` -> bytes (binary units, as dumpsys prints them)."""
    m = _SIZE_RE.match(text)
    if not m:
        raise ValueError(f"not a size: {text!r}")
    return parse_number(m.group(1)) * _UNITS[m.group(2).upper()]


# --------------------------------------------------------------------------- clock

_LOGCAT_TS = re.compile(rb"^(\d\d)-(\d\d) (\d\d):(\d\d):(\d\d)\.(\d{3})", re.M)
_LOGCAT_LINE = re.compile(
    r"^(\d\d-\d\d \d\d:\d\d:\d\d\.\d{3})(?:\s+\S+)?\s+\d+\s+\d+\s+([VDIWEFA])\s+(.*?)\s*: (.*)$"
)
_KERNEL_LINE = re.compile(r"^(?:<\d+>)?\[\s*(\d+\.\d+)\]\s?(.*)$")
_ALARM_RE = re.compile(rb"nowRTC=(\d+)[^\n]*?nowELAPSED=(\d+)")
_PROP_RE = re.compile(r"^\[([^\]]+)\]: \[([^\]]*)\]", re.M)
LOGCAT_SECTIONS = ("SYSTEM LOG", "EVENT LOG", "RADIO LOG", "LAST LOGCAT")
KERNEL_SECTIONS = ("KERNEL LOG",)
TS_FMT = "%Y-%m-%d %H:%M:%S"


def fmt_ts(t: dt.datetime) -> str:
    return t.strftime(TS_FMT) + f".{t.microsecond // 1000:03d}"


def logcat_time(stamp: str, captured: dt.datetime) -> dt.datetime:
    """`MM-DD HH:MM:SS.mmm` -> local datetime; a later month is last year's."""
    month = int(stamp[:2])
    year = captured.year - 1 if month > captured.month else captured.year
    return dt.datetime.strptime(f"{year}-{stamp}", "%Y-%m-%d %H:%M:%S.%f")


def derive_clock(
    header: dict[str, Any], alarm: bytes | None, props: dict[str, str]
) -> dict[str, Any]:
    """alarm -> timezone -> none, as § 5.5 orders them."""
    captured = header.get("captured_local")
    if captured and alarm and (m := _ALARM_RE.search(alarm)):
        now_rtc, now_elapsed = int(m.group(1)), int(m.group(2))
        local = dt.datetime.strptime(captured, TS_FMT).replace(tzinfo=dt.UTC)
        offset = round((local.timestamp() - now_rtc / 1000) / 900) * 900
        return {
            "utc_offset_s": offset,
            "source": "alarm",
            "boot_rtc_ms": now_rtc - now_elapsed,
            "tz": props.get("persist.sys.timezone"),
        }
    tz_name = props.get("persist.sys.timezone")
    if captured and tz_name:
        try:
            from zoneinfo import ZoneInfo

            local = dt.datetime.strptime(captured, TS_FMT).replace(tzinfo=ZoneInfo(tz_name))
            off = local.utcoffset()
            if off is not None:
                return {
                    "utc_offset_s": int(off.total_seconds()),
                    "source": "timezone",
                    "boot_rtc_ms": None,
                    "tz": tz_name,
                }
        except (ImportError, ValueError, KeyError, OSError):
            pass  # no tz database here: fall through, guess nothing
    return {"utc_offset_s": None, "source": "none", "boot_rtc_ms": None, "tz": tz_name}


def parse_header(head: str) -> dict[str, Any]:
    def grab(pattern: str) -> str | None:
        m = re.search(pattern, head, re.M)
        return m.group(1).strip() if m else None

    up = re.search(r"^Uptime: up (?:(\d+) days?, )?\s*(\d+):(\d+)", head, re.M)
    uptime = None
    if up:
        uptime = int(up.group(1) or 0) * 86400 + int(up.group(2)) * 3600 + int(up.group(3)) * 60
    return {
        "format_version": grab(r"^Bugreport format version: (\S+)"),
        "build_id": grab(r"^Build: (\S+)"),
        "fingerprint_release": grab(r"^Build fingerprint: '[^:']*:([^/']+)/"),
        "captured_local": grab(r"^== dumpstate: (\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)"),
        "uptime_s": uptime,
    }


# --------------------------------------------------------------------------- report


class Report:
    """An opened bugreport: its reading target, index, and bounded reads."""

    def __init__(self, path: Path, keydir: Path, index: dict[str, Any]) -> None:
        self.path = path
        self.keydir = keydir
        self._rebuilt = False
        self._load(index)
        self._harvest: dict[str, str] | None = None
        self.salt = _redact.new_salt()

    def _load(self, index: dict[str, Any]) -> None:
        self.index = index
        self.sections: list[dict[str, Any]] = index["sections"]
        self._starts = [s["start"] for s in self.sections]
        rt = index["input"]["reading_target"]
        self.target = self.keydir / rt if rt else self.path
        with self.target.open("rb") as f:
            self.mm = mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ)

    @property
    def header(self) -> dict[str, Any]:
        h: dict[str, Any] = self.index["header"]
        return h

    @property
    def clock(self) -> dict[str, Any]:
        c: dict[str, Any] = self.index["clock"]
        return c

    @property
    def captured(self) -> dt.datetime | None:
        c = self.header.get("captured_local")
        return dt.datetime.strptime(c, TS_FMT) if c else None

    def find(self, name: str) -> list[dict[str, Any]]:
        return [s for s in self.sections if s["name"] == name]

    def select(self, sel: str) -> dict[str, Any]:
        """Exact id; bare name with one occurrence; unique case-insensitive match."""
        for s in self.sections:
            if s["id"] == sel:
                return s
        by_name = self.find(sel)
        if len(by_name) == 1:
            return by_name[0]
        if not by_name:
            low = sel.casefold()
            by_name = [
                s for s in self.sections if low in (s["id"].casefold(), s["name"].casefold())
            ]
            if len(by_name) == 1:
                return by_name[0]
        if by_name:
            ids = ", ".join(s["id"] for s in by_name[:20])
            raise UsageError(f"--section {sel!r} is ambiguous; candidates: {ids}")
        near = [s["id"] for s in self.sections if sel.casefold() in s["id"].casefold()][:10]
        hint = f"; did you mean: {', '.join(near)}" if near else ""
        raise UsageError(f"no section {sel!r}{hint} (list them with `sections`)")

    def section_at(self, off: int) -> dict[str, Any] | None:
        return _innermost(self.sections, self._starts, off)

    def raw(self, sec: dict[str, Any]) -> bytes:
        """The section's bytes, after checking they still open with its delimiter."""
        data = self.mm[sec["start"] : sec["end"]]
        first = data[: data.find(b"\n")] if b"\n" in data else data
        opener = b"------ " if sec["kind"] == "top" else b"DUMP OF SERVICE "
        if first.startswith(opener) and sec["name"].encode("utf-8", "replace") in first:
            return data
        if self._rebuilt:
            raise ReportError(
                f"index does not match {self.path} at {sec['id']}; rerun with --force"
            )
        console.warn(f"index stale at {sec['id']}; rebuilding once")
        self._rebuilt = True
        self.mm.close()
        self._load(_build(self.path, self.keydir))
        return self.raw(self.select(sec["id"]))

    def text(self, sec: dict[str, Any]) -> str:
        return self.raw(sec).decode("utf-8", "replace")

    def first_text(self, name: str) -> str | None:
        found = self.find(name)
        return self.text(found[0]) if found else None

    def properties(self) -> dict[str, str]:
        text = self.first_text("SYSTEM PROPERTIES") or ""
        return dict(_PROP_RE.findall(text))

    def redactor(self, enabled: bool) -> Callable[[object], object]:
        if not enabled:
            return lambda obj: obj
        if self._harvest is None:
            texts: list[str] = []
            for name in _redact.HARVEST_SECTIONS:
                texts.extend(self.text(s) for s in self.find(name))
            self._harvest = _redact.harvest(texts)
        harvested = self._harvest
        return lambda obj: _redact.walk(obj, self.salt, harvested)

    def lines(self, sec: dict[str, Any]) -> Iterator[tuple[int, str]]:
        """(byte offset, line) for every line of the section, `\\r\\n` aware."""
        data = self.raw(sec)
        off = sec["start"]
        for raw in data.split(b"\n"):
            yield off, raw.rstrip(b"\r").decode("utf-8", "replace")
            off += len(raw) + 1

    def events(self) -> Iterator[dict[str, Any]]:
        """Timed log lines from every logcat and kernel section, in section order."""
        captured = self.captured
        clock = self.clock
        boot = clock.get("boot_rtc_ms")
        offset = clock.get("utc_offset_s")
        for sec in self.sections:
            if sec["kind"] != "top":
                continue
            if sec["name"] in LOGCAT_SECTIONS and captured:
                for off, line in self.lines(sec):
                    m = _LOGCAT_LINE.match(line)
                    if m:
                        yield {
                            "t": logcat_time(m.group(1), captured),
                            "src": sec["name"],
                            "level": m.group(2),
                            "tag": m.group(3),
                            "text": m.group(4),
                            "offset": off,
                        }
            elif sec["name"] in KERNEL_SECTIONS:
                for off, line in self.lines(sec):
                    m = _KERNEL_LINE.match(line)
                    if not m:
                        continue
                    secs = float(m.group(1))
                    row: dict[str, Any] = {"src": sec["name"], "level": None, "tag": "kernel"}
                    if boot is not None and offset is not None:
                        row["t"] = dt.datetime.fromtimestamp(
                            boot / 1000 + secs + offset, dt.UTC
                        ).replace(tzinfo=None)
                    else:
                        row["t"] = None
                        row["elapsed_s"] = secs
                        row["clock"] = "elapsed"
                    row["text"] = m.group(2)
                    row["offset"] = off
                    yield row

    def coverage(self, names: Sequence[str]) -> tuple[dt.datetime, dt.datetime] | None:
        """First and last logcat timestamp across the named sections."""
        captured = self.captured
        if not captured:
            return None
        stamps: list[dt.datetime] = []
        for name in names:
            for sec in self.find(name):
                for m in _LOGCAT_TS.finditer(self.raw(sec)):
                    stamps.append(logcat_time(m.group(0).decode(), captured))
        return (min(stamps), max(stamps)) if stamps else None


def _build(path: Path, keydir: Path) -> dict[str, Any]:
    """Resolve the input, scan it, and write `index.json` atomically."""
    _, key_meta = input_key(path)
    with path.open("rb") as f:
        head = f.read(HEAD)
    meta: dict[str, Any] = {"kind": "txt", "main_entry": None, "reading_target": None}
    fs: list[dict[str, Any]] = []
    target = path
    if head[:4] == b"PK\x03\x04":
        try:
            zf = zipfile.ZipFile(path)
        except zipfile.BadZipFile as exc:
            raise ReportError(f"{path} is not a readable zip: {exc}") from exc
        with zf:
            info = main_entry(zf)
            keydir.mkdir(parents=True, exist_ok=True, mode=0o700)
            target = keydir / "main.txt"
            _extract(zf, info, target)
            meta.update(kind="zip", main_entry=info.filename, reading_target="main.txt")
            for i in zf.infolist():
                if i.filename.startswith("FS/") and not i.is_dir():
                    y, mo, d, hh, mi, ss = i.date_time
                    stamp = f"{y:04d}-{mo:02d}-{d:02d} {hh:02d}:{mi:02d}:{ss:02d}"
                    fs.append({"path": i.filename, "size": i.file_size, "date": stamp})
            meta["proto_members"] = sum(1 for n in zf.namelist() if n.startswith("proto/"))
        with target.open("rb") as f:
            head = f.read(HEAD)
    elif not looks_like_bugreport(head):
        raise NotABugreport(
            f"{path} is not a bugreport: no `== dumpstate:` or `Bugreport format version:` "
            "line in its first 64 KiB"
        )
    keydir.mkdir(parents=True, exist_ok=True, mode=0o700)
    with contextlib.suppress(OSError):
        keydir.chmod(0o700)
    meta["encoding"] = "utf-8"
    meta["transcoded"] = False
    if _is_utf16(head):
        dest = keydir / "main.txt"
        _transcode(target, dest)
        target = dest
        meta.update(encoding="utf-16", transcoded=True, reading_target="main.txt")
        with target.open("rb") as f:
            head = f.read(HEAD)
    with target.open("rb") as f, mmap.mmap(f.fileno(), 0, access=mmap.ACCESS_READ) as mm:
        sections = scan(mm)
        header = parse_header(head.decode("utf-8", "replace"))
        meta["cr_bytes"] = _count(mm, b"\r") - _count(mm, b"\r\n")
        meta["nul_bytes"] = _count(mm, b"\0")
        props_secs = [s for s in sections if s["name"] == "SYSTEM PROPERTIES"]
        props_text = (
            mm[props_secs[0]["start"] : props_secs[0]["end"]].decode("utf-8", "replace")
            if props_secs
            else ""
        )
        props = dict(_PROP_RE.findall(props_text))
        alarm_secs = [s for s in sections if s["name"] == "alarm"]
        alarm = mm[alarm_secs[0]["start"] : alarm_secs[0]["end"]] if alarm_secs else None
    clock = derive_clock(header, alarm, props)
    if alarm and (m := _ALARM_RE.search(alarm)):
        header["uptime_s"] = int(m.group(2)) // 1000
    header.update(
        android_release=props.get("ro.build.version.release") or header.pop("fingerprint_release"),
        sdk=int(props["ro.build.version.sdk"])
        if props.get("ro.build.version.sdk", "").isdigit()
        else None,
        oem=props.get("ro.product.manufacturer"),
        model=props.get("ro.product.model"),
    )
    header.pop("fingerprint_release", None)
    if not header.get("build_id"):
        header["build_id"] = props.get("ro.build.id")
    index = {
        "schema": INDEX_SCHEMA,
        "key": key_meta,
        "input": meta,
        "header": header,
        "clock": clock,
        "sections": sections,
        "fs": fs,
    }
    _write_atomic(keydir / "index.json", json.dumps(index).encode())
    return index


def _load_index(keydir: Path, key_meta: dict[str, Any]) -> dict[str, Any] | None:
    try:
        index: dict[str, Any] = json.loads((keydir / "index.json").read_text())
    except (OSError, ValueError):
        return None
    if index.get("schema") != INDEX_SCHEMA or index.get("key") != key_meta:
        return None
    rt = index["input"].get("reading_target")
    if rt and not (keydir / rt).is_file():
        return None
    return index


def open_report(
    path: str | Path, *, output_dir: str | Path | None = None, force: bool = False
) -> Report:
    path = Path(path)
    if not path.is_file():
        raise ReportError(f"no such file: {path}")
    key, key_meta = input_key(path)
    root = Path(output_dir) if output_dir else cache_root()
    keydir = root / key
    index = None if force else _load_index(keydir, key_meta)
    if index is None:
        index = _build(path, keydir)
        prune(root, keep=key)
    else:
        os.utime(keydir / "index.json")
    return Report(path, keydir, index)


# --------------------------------------------------------------------------- output


def budget(
    schema: str,
    rows: list[Any],
    *,
    limit: int | None,
    cap: int | None,
    extra: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """The capped envelope: whole rows dropped from the end, never bytes."""
    total = len(rows)
    if limit == 0:
        cap = None
    elif limit is not None:
        rows = rows[:limit]

    def doc(kept: list[Any]) -> dict[str, Any]:
        d: dict[str, Any] = {
            "schema": schema,
            "truncated": len(kept) < total,
            "shown": len(kept),
            "omitted": total - len(kept),
            "total": total,
        }
        if len(kept) < total:
            d["full"] = FULL_HINT
        d.update(extra or {})
        d["rows"] = kept
        return d

    if cap is None:
        return doc(rows)
    room = cap - len(json.dumps(doc([]), ensure_ascii=False).encode()) - len(FULL_HINT) - 16
    n = 0
    for r in rows:
        room -= len(json.dumps(r, ensure_ascii=False).encode()) + 2
        if room < 0:
            break
        n += 1
    while n and len(json.dumps(doc(rows[:n]), ensure_ascii=False).encode()) > cap:
        n -= 1
    return doc(rows[:n])


def write_doc(doc: dict[str, Any], output: str | None) -> None:
    """Print the document, or write it to `output` and print a one-line envelope."""
    text = json.dumps(doc, ensure_ascii=False)
    if output is None:
        print(text)
        return
    try:
        Path(output).write_text(text + "\n", encoding="utf-8")
    except OSError as exc:
        raise UsageError(f"cannot write --output {output}: {exc}") from exc
    print(
        json.dumps(
            {
                "schema": doc.get("schema"),
                "truncated": False,
                "total": doc.get("total"),
                "output": output,
            }
        )
    )


def add_report_args(p: argparse.ArgumentParser) -> None:
    p.add_argument("--input", required=True, help="bugreport .txt or .zip")
    p.add_argument("--output-dir", help="cache root for the index (default: the user cache dir)")
    p.add_argument("--force", action="store_true", help="rebuild the index")
    p.add_argument("--json", action="store_true", help="JSON only: no progress on stderr")


def add_output_args(
    p: argparse.ArgumentParser, *, limit_help: str = "max rows (0 = no caps)"
) -> None:
    p.add_argument("--limit", type=int, help=limit_help)
    p.add_argument("--output", help="write the full document here; print a one-line summary")
    p.add_argument("--no-redact", action="store_true", help="print identifiers unmasked")


def run(main: Callable[[], int]) -> int:
    """Map the two error classes and anything unexpected onto exit codes 1 and 2."""
    try:
        return main()
    except ReportError as exc:
        console.fail(str(exc))
        return 1
    except UsageError as exc:
        console.fail(str(exc))
        return 2
    except re.error as exc:
        console.fail(f"bad regular expression: {exc}")
        return 2
    except BrokenPipeError:
        return 0
    except Exception as exc:  # the never-fail-open rule: no half-redacted output
        console.fail(f"internal error: {type(exc).__name__}: {exc}")
        return 2
