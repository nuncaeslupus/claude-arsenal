#!/usr/bin/env python3
"""Measure the T4 index gates against generated bugreports of a stated size.

Wall-clock and RSS numbers mean nothing without saying where they ran, so this
prints the machine's provenance beside them. The reports come from
make_fixture.py, never from a real device (D-9).

    benchmark.py --target-mb 160 --zip-mb 234

index_build_s <= 3 and peak RSS <= 300 MB (txt); index_build_zip_s <= 6 and
peak RSS <= 300 MB (zip); index_reuse_s <= 0.5.
"""

from __future__ import annotations

import argparse
import json
import platform
import resource
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent / "skills" / "bugreport" / "scripts"))
sys.path.insert(0, str(HERE))

import _brlib as br  # noqa: E402
import make_fixture  # noqa: E402


def peak_rss_mb() -> float:
    """Peak RSS of this process. `ru_maxrss` is KB on Linux and bytes on macOS."""
    raw = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    return raw / 1024 if sys.platform != "darwin" else raw / (1024 * 1024)


def _phase(name: str, out: Path, args: argparse.Namespace) -> dict[str, float | int]:
    """One measured phase. Run in its own process — see `main`."""
    started = time.monotonic()
    if name == "generate":
        txt = make_fixture.build("modern", seed=args.seed, target_mb=args.target_mb, out_dir=out)
        zipped = make_fixture.build(
            "modern", seed=args.seed, target_mb=args.zip_mb, container="zip", out_dir=out
        )
        (out / "paths.json").write_text(json.dumps({"txt": str(txt), "zip": str(zipped)}))
        return {
            "seconds": time.monotonic() - started,
            "mb": txt.stat().st_size / 1e6,
            "zip_mb": zipped.stat().st_size / 1e6,
        }
    paths = json.loads((out / "paths.json").read_text())
    target = paths["zip" if name == "build-zip" else "txt"]
    rpt = br.open_report(target, output_dir=out / "cache", force=name != "reuse")
    return {"seconds": time.monotonic() - started, "rss_mb": peak_rss_mb(), "n": len(rpt.sections)}


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawTextHelpFormatter
    )
    parser.add_argument("--target-mb", type=float, default=160)
    parser.add_argument("--zip-mb", type=float, default=234, help="text size inside the zip")
    parser.add_argument("--seed", type=int, default=20261104)
    parser.add_argument("--output-dir", type=Path, default=None)
    parser.add_argument(
        "--phase",
        choices=("generate", "build", "build-zip", "reuse"),
        help="run one phase only. Without it, every phase runs in its own process",
    )
    parser.add_argument("--json", action="store_true", dest="as_json")
    args = parser.parse_args()

    out = args.output_dir or Path()
    out.mkdir(parents=True, exist_ok=True)
    if args.phase:
        print(json.dumps(_phase(args.phase, out, args)))
        return 0

    # `ru_maxrss` is a high-water mark that cannot be reset, so each phase gets
    # a fresh interpreter; one process would report the build's peak for all.
    def run(phase: str) -> dict[str, float]:
        argv = [
            sys.executable,
            __file__,
            "--phase",
            phase,
            "--output-dir",
            str(out),
            "--target-mb",
            str(args.target_mb),
            "--zip-mb",
            str(args.zip_mb),
            "--seed",
            str(args.seed),
        ]
        proc = subprocess.run(argv, capture_output=True, text=True, check=True)
        return json.loads(proc.stdout)

    gen = run("generate")
    build = run("build")
    build_zip = run("build-zip")
    reuse = run("reuse")
    result = {
        "machine": f"{platform.system()} {platform.machine()} python{platform.python_version()}",
        "seed": args.seed,
        "txt_mb": round(gen["mb"], 1),
        "zip_mb": round(gen["zip_mb"], 1),
        "sections": build["n"],
        "generate_s": round(gen["seconds"], 2),
        "index_build_s": round(build["seconds"], 2),
        "index_build_peak_rss_mb": round(build["rss_mb"], 1),
        "index_build_zip_s": round(build_zip["seconds"], 2),
        "index_build_zip_peak_rss_mb": round(build_zip["rss_mb"], 1),
        "index_reuse_s": round(reuse["seconds"], 3),
        "build_pass": build["seconds"] <= 3 and build["rss_mb"] <= 300,
        "build_zip_pass": build_zip["seconds"] <= 6 and build_zip["rss_mb"] <= 300,
        "reuse_pass": reuse["seconds"] <= 0.5,
    }
    print(json.dumps(result, indent=None if args.as_json else 2))
    return 0 if result["build_pass"] and result["build_zip_pass"] and result["reuse_pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
