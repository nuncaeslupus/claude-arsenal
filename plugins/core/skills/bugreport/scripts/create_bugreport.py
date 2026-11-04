#!/usr/bin/env python3
"""Write a redacted copy of an Android bugreport that is safe to share.

    create_bugreport.py --redact --input R.zip --output shared.zip
    create_bugreport.py --redact --input R.txt --output shared.txt

Every identifier the redaction filter knows (email, phone, IMEI, IMSI, ICCID,
MAC, SSID, account, coordinates, serial, plus this device's own harvested
values) becomes a salted `<kind:xxxxxxxx>` token. A zip input with a `.zip`
output keeps its layout: the main entry and every text member are redacted,
binary members (`.pb`, `proto/`, nested zips, anything not UTF-8) are dropped
and listed, because binary cannot be scrubbed reliably. Any other output is
the redacted main text. Stdout is one JSON line: counts per kind, dropped members.

Refuses an output that is the input, or that exists without `--force`.
Exit 0 written, 1 not a bugreport, 2 bad usage or internal error.
"""

from __future__ import annotations

import argparse
import contextlib
import json
import os
import re
import sys
import tempfile
import zipfile
from collections import Counter
from collections.abc import Callable
from pathlib import Path

import _brlib as br

SCHEMA = "bugreport.create/1"
LISTED = 20  # dropped members named on stdout; the count covers the rest
_TOKEN = re.compile(r"<(\w+):[0-9a-f]{8}>")
_BINARY = re.compile(r"(\.pb|\.proto|\.zip|\.gz|\.png|\.jpg)$|(^|/)proto/")


def _scrub(text: str, redact: Callable[[str], str]) -> str:
    """Redact on line boundaries in ~1 MiB pieces, so a huge report never sits twice in memory."""
    out = []
    pos = 0
    while pos < len(text):
        end = text.find("\n", pos + br.CHUNK)
        end = len(text) if end < 0 else end + 1
        out.append(redact(text[pos:end]))
        pos = end
    return "".join(out)


def _text(data: bytes) -> str | None:
    """The member as text, or None when it is binary."""
    if b"\0" in data:
        return None
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError:
        return None


def _write(dest: Path, fill: Callable[[Path], None]) -> None:
    fd, tmp = tempfile.mkstemp(dir=dest.parent, prefix=".tmp-")
    os.close(fd)
    try:
        fill(Path(tmp))
        Path(tmp).replace(dest)
    except BaseException:
        with contextlib.suppress(OSError):
            Path(tmp).unlink()
        raise


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    p.add_argument("--redact", action="store_true", required=True, help="scrub identifiers")
    p.add_argument("--input", required=True, help="bugreport .txt or .zip")
    p.add_argument("--output", required=True, help="where to write the scrubbed copy")
    p.add_argument("--output-dir", help="cache root for the index (default: the user cache dir)")
    p.add_argument("--force", action="store_true", help="overwrite --output / rebuild the index")
    p.add_argument("--json", action="store_true", help="JSON only: no progress on stderr")
    args = p.parse_args(argv)

    def go() -> int:
        src, dest = Path(args.input), Path(args.output)
        if dest.resolve() == src.resolve():
            raise br.UsageError("--output is the input; write the copy somewhere else")
        if dest.exists() and not args.force:
            raise br.UsageError(f"{dest} exists; pass --force to overwrite")
        if not dest.parent.is_dir():
            raise br.UsageError(f"cannot write --output {dest}: no such directory")
        rpt = br.open_report(src, output_dir=args.output_dir, force=args.force)
        walk = rpt.redactor(True)  # harvests this device's own identifiers once

        def redact(s: str) -> str:
            return str(walk(s))

        counts: Counter[str] = Counter()

        def scrub(text: str) -> bytes:
            out = _scrub(text, redact)
            counts.update(_TOKEN.findall(out))
            return out.encode("utf-8")

        main_text = rpt.target.read_bytes().decode("utf-8", "replace")
        dropped: list[str] = []
        main_entry = rpt.index["input"]["main_entry"]
        if main_entry and dest.suffix.lower() == ".zip":

            def fill(tmp: Path) -> None:
                with zipfile.ZipFile(src) as zin, zipfile.ZipFile(tmp, "w") as zout:
                    for info in zin.infolist():
                        if info.is_dir():
                            continue
                        if info.filename == main_entry:
                            data = scrub(main_text)
                        else:
                            with zin.open(info) as f:
                                raw = f.read(br.EXTRACT_CEILING + 1)
                            text = None if _BINARY.search(info.filename) else _text(raw)
                            if text is None or len(raw) > br.EXTRACT_CEILING:
                                dropped.append(info.filename)
                                continue
                            data = scrub(text)
                        zout.writestr(
                            zipfile.ZipInfo(redact(info.filename), info.date_time),
                            data,
                            compress_type=zipfile.ZIP_DEFLATED,
                        )
        else:

            def fill(tmp: Path) -> None:
                tmp.write_bytes(scrub(main_text))

        _write(dest, fill)
        print(
            json.dumps(
                {
                    "schema": SCHEMA,
                    "truncated": len(dropped) > LISTED,
                    "output": str(dest),
                    "redacted": dict(sorted(counts.items())),
                    "dropped": dropped[:LISTED],
                    "dropped_total": len(dropped),
                }
            )
        )
        return 0

    return br.run(go)


if __name__ == "__main__":
    # Windows consoles default to a legacy codepage; a non-ASCII line must
    # degrade to "?", never take the process down.
    for _stream in (sys.stdout, sys.stderr):
        if hasattr(_stream, "reconfigure"):
            _stream.reconfigure(encoding="utf-8", errors="replace")
    sys.exit(main())
