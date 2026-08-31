#!/usr/bin/env bash
# har_test.sh — the HAR toolkit, at the level a session actually uses it.
#
# Two layers, both run from here so `make test` discovers everything through one
# entry point:
#
#   * pytest over `har/test_*.py` — the scanner, the encoding matrix, the index.
#     Those are unit problems: asserting them through a CLI would test less and
#     cost more.
#   * the CLI assertions below — exit codes, output budgets, and the fact that a
#     command a consumer is told to run does what the SKILL.md says it does.
#
# `--stage N` runs only the assertions for one delivery stage, which is what the
# task gates in `arsenal/tasks/` call.
#
# Exit: 0 PASS, 1 FAIL.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
scripts="$here/../skills/har/scripts"
stage="${2:-all}"
[ "${1:-}" = "--stage" ] || stage="all"

tmp="$(mktemp -d)" || { echo "FAIL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
# `python3`, not `uv run python`: the `core tests` job sets up bare python3 on
# purpose — it exists to prove the shipped scripts work the way a consumer runs
# them, with no `uv` and no installed packages. Every har script is stdlib-only
# precisely so that holds, and reaching for `uv` here would report a missing
# tool as a failing toolkit.
py() { (cd "$root" && python3 "$@"); }

py "$here/har/fixtures.py" --output-dir "$tmp" >/dev/null || fail "fixture generation failed"
for name in basic traps encodings hostile compare_a compare_b; do
    [ -s "$tmp/$name.har" ] || fail "fixture $name.har was not written"
done
echo "PASS: fixtures build"

# --- the unit layer ---------------------------------------------------------
# pytest is a dev dependency, so it is absent from the bare-python job by
# design. Skipping is reported by name, never silently: `make test-units` runs
# this layer in the `unit tests` job, which has the dev toolchain, and a skip
# that does not say so is how 100 assertions quietly stop running.
if python3 -c "import pytest" >/dev/null 2>&1; then
    (cd "$root" && python3 -m pytest plugins/core/tests/har -q) || fail "pytest layer failed"
    echo "PASS: pytest — scanner, encodings, index, validate"
else
    echo "SKIP: pytest not importable here — the unit layer runs in \`make test-units\`"
fi

# --- validate_har.py --------------------------------------------------------
out="$(py "$scripts/validate_har.py" --input "$tmp/basic.har")" \
    || fail "validate_har exited non-zero on a good capture"
grep -q "usable HAR" <<<"$out" || fail "validate_har did not report the capture usable"

echo '{"not": "a har"}' > "$tmp/bad.json"
py "$scripts/validate_har.py" --input "$tmp/bad.json" >/dev/null 2>&1 \
    && fail "validate_har accepted a file that is not a HAR"
py "$scripts/validate_har.py" --input "$tmp/nope.har" >/dev/null 2>&1
[ "$?" -eq 2 ] || fail "a missing input must exit 2 (usage), not 1"
py "$scripts/validate_har.py" --input "$tmp/basic.har" --json | python3 -c 'import json,sys; json.load(sys.stdin)' \
    || fail "--json did not emit parseable JSON"
echo "PASS: validate_har — usable, not-a-HAR, missing file, --json"

# --- analyze_har.py --index -------------------------------------------------
out="$(py "$scripts/analyze_har.py" --input "$tmp/basic.har" --index --verify-offsets)" \
    || fail "index build with --verify-offsets exited non-zero"
grep -q "offsets verified" <<<"$out" || fail "--verify-offsets did not report verifying: $out"
[ -s "$tmp/basic.har.index.jsonl" ] || fail "no sidecar written next to the capture"

head -1 "$tmp/basic.har.index.jsonl" | grep -q '"digest"' \
    || fail "the index header carries no content digest"
grep -q "live-token-aaaa" "$tmp/basic.har.index.jsonl" \
    && fail "the sidecar carries a live token — it sits on disk beside the capture"
grep -q '"text"' "$tmp/basic.har.index.jsonl" \
    && fail "the sidecar carries body text; it is a metadata index"
echo "PASS: analyze_har --index — sidecar written, verified, redacted, bodyless"

# --- the output budget (SC1) ------------------------------------------------
for target in basic traps encodings hostile; do
    bytes="$(py "$scripts/analyze_har.py" --input "$tmp/$target.har" | wc -c)"
    [ "$bytes" -le 4096 ] || fail "overview of $target is $bytes bytes; the cap is 4096"
    bytes="$(py "$scripts/validate_har.py" --input "$tmp/$target.har" | wc -c)"
    [ "$bytes" -le 4096 ] || fail "validate of $target is $bytes bytes; the cap is 4096"
done
echo "PASS: SC1 — every default output within the 4096-byte budget"

# --- the capture is never written -------------------------------------------
before="$(python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$tmp/basic.har")"
py "$scripts/analyze_har.py" --input "$tmp/basic.har" >/dev/null
py "$scripts/validate_har.py" --input "$tmp/basic.har" >/dev/null
after="$(python3 -c 'import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$tmp/basic.har")"
[ "$before" = "$after" ] || fail "a command modified the input capture"
echo "PASS: the input capture is never written"

# --- SC2/SC3 at reduced scale ----------------------------------------------
# The recorded evidence is a 200 MB / 50k-entry run, which takes ~45 s to
# generate and does not belong in every CI run. This is the same benchmark at
# a tenth of it, whose job is to catch the regression that matters: a reader
# that materialises the index instead of streaming it. That mistake cost 12x
# the memory and 4.5x the time at full scale and passed every functional test.
bench="$(py "$here/har/benchmark.py" --target-mb 20 --entries 5000 --output-dir "$tmp" --json)" \
    || fail "benchmark exited non-zero: $bench"
python3 -c 'import json,sys; r=json.loads(sys.argv[1]); sys.exit(0 if r["index_only_query_peak_rss_mb"] <= 80 and r["index_only_query_s"] <= 1.0 else 1)' "$bench" \
    || fail "SC3 regression — the index-only query is no longer flat: $bench"
rss="$(python3 -c 'import json,sys; print(json.loads(sys.argv[1])["index_only_query_peak_rss_mb"])' "$bench")"
echo "PASS: SC3 at reduced scale — index-only query stays flat (${rss} MB peak)"

# --- --help on every shipped script -----------------------------------------
for script in "$scripts"/*.py; do
    case "$(basename "$script")" in _*) continue ;; esac
    py "$script" --help >/dev/null 2>&1 || fail "$(basename "$script") has no working --help"
done
echo "PASS: every shipped script answers --help"

echo "PASS: har_test.sh (stage ${stage})"
