#!/usr/bin/env python3
"""Measure SC2 and SC3 against a generated capture of a stated size.

Wall-clock and RSS numbers mean nothing without saying where they ran, so this
prints the machine's own provenance alongside them and the evidence log records
both. The capture is generated rather than captured for the same reason the
fixtures are: a 200 MB real HAR is somebody's session.

    benchmark.py --target-mb 200 --entries 50000

SC2: index build ≤ 30 s wall, ≤ 400 MB peak RSS.
SC3: any index-only query ≤ 1 s, ≤ 150 MB peak RSS.
"""

from __future__ import annotations

import argparse
import json
import platform
import random
import resource
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent / "skills" / "har" / "scripts"))

import analyze_har  # noqa: E402


def peak_rss_mb() -> float:
    """Peak RSS of this process. `ru_maxrss` is KB on Linux and bytes on macOS."""
    raw = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    return raw / 1024 if sys.platform != "darwin" else raw / (1024 * 1024)


def generate(path: Path, entries: int, target_mb: int, seed: int) -> None:
    """A capture with realistic body bulk: most bytes in bodies, not in metadata."""
    rng = random.Random(seed)
    body_bytes = max(200, (target_mb * 1_000_000) // max(entries, 1))
    hosts = ["api.example.com", "cdn.example.com", "jobs.example.com"]
    with path.open("w", encoding="utf-8") as out:
        out.write('{"log":{"version":"1.2","creator":{"name":"bench","version":"1"},"entries":[')
        for i in range(entries):
            if i:
                out.write(",")
            body = json.dumps(
                {"i": i, "pad": "".join(rng.choice("abcdefghij") for _ in range(body_bytes))}
            )
            entry = {
                "startedDateTime": "2026-08-30T12:00:00.000Z",
                "time": rng.uniform(10, 900),
                "pageref": "page_1",
                "request": {
                    "method": "GET",
                    "url": f"https://{rng.choice(hosts)}/api/items?page={i}&loc=NY",
                    "headers": [
                        {"name": "accept", "value": "application/json"},
                        {"name": "authorization", "value": f"Bearer tok-{i % 3}"},
                    ],
                    "queryString": [],
                    "cookies": [],
                    "bodySize": 0,
                },
                "response": {
                    "status": 200 if i % 20 else 404,
                    "statusText": "OK",
                    "headers": [{"name": "content-type", "value": "application/json"}],
                    "cookies": [],
                    "content": {
                        "size": len(body),
                        "mimeType": "application/json",
                        "text": body,
                    },
                    "redirectURL": "",
                },
                "_resourceType": "xhr",
                "_fromCache": False,
                "cache": {},
                "timings": {"wait": 1.0},
            }
            out.write(json.dumps(entry, separators=(",", ":")))
        out.write("]}}")


def _phase(name: str, har: Path) -> dict[str, float | int]:
    """One measured phase. Run in its own process — see `main`."""
    started = time.monotonic()
    if name == "build":
        _, count, _ = analyze_har.build_index(har)
        return {"seconds": time.monotonic() - started, "rss_mb": peak_rss_mb(), "n": count}
    opened = analyze_har.open_index(har)
    if opened is None:
        raise SystemExit("query phase: no current index — run the build phase first")
    _, rows = opened
    # Folded as they arrive. Materialising the rows first is what SC3's memory
    # bound exists to forbid: it is the index doing the thing it was built to
    # avoid, just against a smaller file.
    hits = sum(1 for r in rows if r["status"] == 404 and r["host"] == "api.example.com")
    return {"seconds": time.monotonic() - started, "rss_mb": peak_rss_mb(), "n": hits}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target-mb", type=int, default=200)
    parser.add_argument("--entries", type=int, default=50_000)
    parser.add_argument("--seed", type=int, default=20260830)
    parser.add_argument("--output-dir", type=Path, default=None)
    parser.add_argument(
        "--phase",
        choices=("generate", "build", "query"),
        help="run one phase only. Without it, every phase runs in its own process",
    )
    parser.add_argument("--json", action="store_true", dest="as_json")
    args = parser.parse_args()

    out_dir = args.output_dir or Path()
    out_dir.mkdir(parents=True, exist_ok=True)
    har = out_dir / "bench.har"

    if args.phase == "generate":
        started = time.monotonic()
        generate(har, args.entries, args.target_mb, args.seed)
        print(json.dumps({"seconds": time.monotonic() - started, "mb": har.stat().st_size / 1e6}))
        return 0
    if args.phase in {"build", "query"}:
        print(json.dumps(_phase(args.phase, har)))
        return 0

    # `ru_maxrss` is a high-water mark that cannot be reset, so measuring the
    # build and the query in one process reports the build's peak for both —
    # which would quietly satisfy SC3's memory bound with the wrong number.
    # Each phase gets a fresh interpreter.
    def run(phase: str) -> dict[str, float]:
        proc = subprocess.run(
            [sys.executable, __file__, "--phase", phase, "--output-dir", str(out_dir),
             "--target-mb", str(args.target_mb), "--entries", str(args.entries),
             "--seed", str(args.seed)],
            capture_output=True, text=True, check=True,
        )
        return json.loads(proc.stdout)

    gen = run("generate")
    build = run("build")
    query = run("query")

    result = {
        "machine": f"{platform.system()} {platform.machine()} python{platform.python_version()}",
        "seed": args.seed,
        "capture_mb": round(gen["mb"], 1),
        "entries": args.entries,
        "generate_s": round(gen["seconds"], 2),
        "index_build_s": round(build["seconds"], 2),
        "index_build_peak_rss_mb": round(build["rss_mb"], 1),
        "index_only_query_s": round(query["seconds"], 3),
        "index_only_query_peak_rss_mb": round(query["rss_mb"], 1),
        "query_hits": query["n"],
        "sc2_pass": build["seconds"] <= 30 and build["rss_mb"] <= 400,
        "sc3_pass": query["seconds"] <= 1.0 and query["rss_mb"] <= 150,
    }
    print(json.dumps(result, indent=None if args.as_json else 2))
    return 0 if result["sc2_pass"] and result["sc3_pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
