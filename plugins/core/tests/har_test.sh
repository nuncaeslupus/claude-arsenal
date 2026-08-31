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

# --- query_har.py: SC4, the two-command answer ------------------------------
idx="$(py "$scripts/query_har.py" --input "$tmp/basic.har" \
    --response-match "Senior Rust Engineer 2" | awk 'NR==1{print $1}')"
[ -n "$idx" ] || fail "--response-match found nothing; it is the operation this toolkit is for"
py "$scripts/query_har.py" --input "$tmp/basic.har" --show "$idx" --schema | grep -q '"results"' \
    || fail "--schema on the located entry did not print the body shape"
echo "PASS: SC4 — two commands from a string on the page to the endpoint's shape"

# --- the output budget, every mode (SC1) ------------------------------------
for args in "" "--type xhr" "--json" "--show 1" "--limit 100"; do
    # shellcheck disable=SC2086
    bytes="$(py "$scripts/query_har.py" --input "$tmp/encodings.har" $args | wc -c)"
    [ "$bytes" -le 4096 ] || fail "query_har ${args:-default} produced $bytes bytes; cap is 4096"
done
py "$scripts/query_har.py" --input "$tmp/encodings.har" --json --limit 100 \
    | python3 -c 'import json,sys; json.load(sys.stdin)' \
    || fail "--json under the budget no longer parses — it must drop whole entries"
echo "PASS: SC1 — query_har within budget in every mode, --json still parses"

# --- extraction stays inside --output-dir -----------------------------------
mkdir -p "$tmp/out"
py "$scripts/query_har.py" --input "$tmp/hostile.har" --extract-body --output-dir "$tmp/out" \
    >/dev/null || fail "--extract-body exited non-zero on the hostile fixture"
escaped="$(find "$tmp" -maxdepth 1 -name '*passwd*' -o -maxdepth 1 -name 'CON*' | wc -l)"
[ "$escaped" -eq 0 ] || fail "extraction wrote outside --output-dir"
find "$tmp/out" -mindepth 2 | grep -q . && fail "extraction created nested paths from a URL"
echo "PASS: extraction — every body lands flat inside --output-dir"

# --- three-state cache ------------------------------------------------------
py "$scripts/query_har.py" --input "$tmp/traps.har" --unknown-cache | grep -q "unknown-cache" \
    || fail "--unknown-cache did not select the entry with no _fromCache"
py "$scripts/query_har.py" --input "$tmp/traps.har" --no-cache | grep -q "unknown-cache" \
    && fail "--no-cache selected an entry whose exporter never recorded _fromCache"
echo "PASS: _fromCache stays three-state across the CLI"

# --- analyze_har.py insight modes -------------------------------------------
out="$(py "$scripts/analyze_har.py" --input "$tmp/basic.har" --endpoints)"
rows="$(grep -c "api.example.com/api/jobs" <<<"$out")"
[ "$rows" -eq 1 ] || fail "--endpoints did not collapse the paginated API to one row"
grep -q "page varies over 4" <<<"$out" || fail "--endpoints did not report the varying parameter"
grep -q "loc = NY  (constant)" <<<"$out" || fail "--endpoints did not report the constant one"
echo "PASS: --endpoints — the paginated API collapses to one row"

py "$scripts/analyze_har.py" --input "$tmp/basic.har" --headers | grep -q "candidate auth" \
    || fail "--headers did not name the constant Authorization as a candidate"
py "$scripts/analyze_har.py" --input "$tmp/traps.har" --cookies | grep -q "sid \[HttpOnly\]" \
    || fail "--cookies lost the cookie name or its flags"
py "$scripts/analyze_har.py" --input "$tmp/traps.har" --websockets | grep -q "Rustacean" \
    || fail "--websockets did not show the frames a body search cannot find"
echo "PASS: --headers, --cookies, --websockets"

for mode in --errors --redirects --slowest --largest --cookies --headers --endpoints --websockets; do
    bytes="$(py "$scripts/analyze_har.py" --input "$tmp/encodings.har" $mode | wc -c)"
    [ "$bytes" -le 4096 ] || fail "analyze $mode produced $bytes bytes; cap is 4096"
done
py "$scripts/analyze_har.py" --input "$tmp/basic.har" --stats banana >/dev/null 2>&1 \
    && fail "--stats with an unknown field should be a usage error"
echo "PASS: every analyze mode within budget, unknown --stats refused"

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
