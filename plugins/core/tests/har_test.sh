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

# --- create_repro.py: nothing the capture did not contain -------------------
repro="$(py "$scripts/create_repro.py" --input "$tmp/hostile.har" --id 2 --format curl)"
grep -q -- "--data-raw" <<<"$repro" || fail "the reproduction used --data instead of --data-raw"
grep -q -- " --data " <<<"$repro" && fail "--data would read a local file for a body starting with @"
# The assertion is a script, not an inline snippet: writing it inline means
# interpolating the fixture's `; rm -rf / #` header into a shell, which is the
# very thing the command under test exists to make impossible.
printf '%s\n' "$repro" | py "$here/har/assert_repro_safe.py" \
    || fail "an adversarial header or body did not survive shell quoting intact"
grep -q "live-aaaa" <<<"$repro" && fail "the reproduction leaked a credential without --secrets"
py "$scripts/create_repro.py" --input "$tmp/basic.har" --id 2 --format python \
    | python3 -c 'import sys; compile(sys.stdin.read(), "<repro>", "exec")' \
    || fail "the python reproduction is not valid Python"
echo "PASS: create_repro — adversarial values stay data, in both formats"

# --- create_har.py: safe to commit, honest when it is not -------------------
py "$scripts/create_har.py" --input "$tmp/hostile.har" --output "$tmp/derived.har" >/dev/null \
    || fail "create_har exited non-zero"
for secret in live-aaaa live-bbbb live-cccc live-dddd hunter2; do
    grep -q "$secret" "$tmp/derived.har" && fail "SC5: $secret survived into the derived HAR"
done
py "$here/har/assert_no_bodies.py" "$tmp/derived.har" || fail "bodies are not dropped by default"
py "$scripts/validate_har.py" --input "$tmp/derived.har" >/dev/null \
    || fail "the derived file is not a valid HAR"
out="$(py "$scripts/create_har.py" --input "$tmp/basic.har" --keep-bodies --output "$tmp/fix.har")"
grep -q "as sensitive as the capture" <<<"$out" \
    || fail "--keep-bodies did not declare the result sensitive"
py "$scripts/analyze_har.py" --input "$tmp/derived.har" --headers >/dev/null \
    || fail "--headers cannot read a derived HAR"
py "$scripts/create_har.py" --input "$tmp/basic.har" --output "$tmp/basic.har" >/dev/null 2>&1 \
    && fail "writing the derived HAR over its own input was not refused"
echo "PASS: create_har — SC5, bodies dropped by default, --keep-bodies declares itself"

# --- compare_har.py: never invent a change that did not happen --------------
py "$scripts/compare_har.py" --input "$tmp/compare_a.har" --against "$tmp/compare_a.har" \
    >/dev/null || fail "identical captures did not compare clean (exit must be 0)"
out="$(py "$scripts/compare_har.py" --input "$tmp/compare_a.har" --against "$tmp/compare_b.har")" \
    || true
changes="$(grep -c "status .* → " <<<"$out")"
[ "$changes" -eq 1 ] \
    || fail "expected exactly one status change; a URL-only matcher reports three ($changes)"
grep -q "positional match" <<<"$out" \
    || fail "a match made on capture order alone was not reported as one"
grep -q "parameters added: expand" <<<"$out" \
    || fail "a changed parameter set was paired instead of reported"
echo "PASS: compare_har — one real change found, none invented"

# --- the sibling scripts have not drifted apart -----------------------------
for script in query_har.py create_har.py compare_har.py; do
    for flag in --url --host --status --type --param --has-header --unknown-cache --invert; do
        py "$scripts/$script" --help 2>/dev/null | grep -q -- "$flag" \
            || fail "$script no longer offers the shared selection flag $flag"
    done
done
echo "PASS: one selection grammar, spelled the same in every sibling"

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

# --- capture_har.py: the caller's robots identity, not ours -----------------
# playwright is not installed in either CI job, and this assertion is not about
# playwright — it is about which string reaches `new_context(user_agent=…)`.
# A stub module on PYTHONPATH gets at exactly that seam and nothing else, so
# the check runs under the same bare interpreter as everything above.
mkdir -p "$tmp/stub/playwright"
: > "$tmp/stub/playwright/__init__.py"
cat > "$tmp/stub/playwright/sync_api.py" <<'STUB'
"""The smallest playwright that capture_har.py can drive, recording the UA."""
import contextlib
import json
import os

REAL_UA = "StubBrowser/1.0"


class TimeoutError(Exception):
    """playwright ships its own, distinct from the builtin of the same name."""


class _Page:
    def evaluate(self, expr):
        return REAL_UA

    def goto(self, url, **kw):
        mode = os.environ.get("CAPTURE_HAR_STUB_GOTO", "")
        if mode == "timeout":
            raise TimeoutError("Timeout 30000ms exceeded.")
        if mode == "error":
            raise RuntimeError("net::ERR_NAME_NOT_RESOLVED")

    def wait_for_timeout(self, ms):
        pass


class _Context:
    def __init__(self, **kw):
        self._kw = kw

    def new_page(self):
        return _Page()

    def close(self):
        # Only the recording context has a path — the UA probe context does not,
        # which is the real script's shape too.
        path = self._kw.get("record_har_path")
        if not path:
            return
        with open(os.environ["CAPTURE_HAR_STUB_RECORD"], "w") as fh:
            json.dump({"user_agent": self._kw.get("user_agent")}, fh)
        with open(path, "w") as fh:
            fh.write('{"log": {"version": "1.2", "creator": {}, "entries": []}}')


class _Browser:
    def new_context(self, **kw):
        return _Context(**kw)

    def close(self):
        pass


class _Chromium:
    def launch(self, **kw):
        return _Browser()


class _Play:
    chromium = _Chromium()


@contextlib.contextmanager
def sync_playwright():
    yield _Play()
STUB

capture() {
    # $1 = label for the recorded UA, remaining args passed through.
    local label="$1"; shift
    CAPTURE_HAR_STUB_RECORD="$tmp/ua-$label.json" \
    PYTHONPATH="$tmp/stub" python3 "$scripts/capture_har.py" \
        --url https://example.com --output "$tmp/cap-$label.har" "$@" >/dev/null \
        || fail "capture_har.py exited non-zero for $label"
    python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["user_agent"])' \
        "$tmp/ua-$label.json"
}

ua="$(capture default)"
[ "$ua" = "StubBrowser/1.0 claude-arsenal-har/1.0" ] \
    || fail "the default suffix is no longer appended to the real UA: '$ua'"

ua="$(capture mine --ua-suffix " integral-job-search/0.1")"
[ "$ua" = "StubBrowser/1.0 integral-job-search/0.1" ] \
    || fail "--ua-suffix did not reach the recording context: '$ua'"

# An empty suffix is an answer, not a missing one. `default=` plus a falsy
# check would silently substitute ours here, which is the one case a consumer
# capturing a token-sensitive page cannot work around.
ua="$(capture empty --ua-suffix "")"
[ "$ua" = "StubBrowser/1.0" ] \
    || fail "--ua-suffix '' appended something anyway: '$ua'"
echo "PASS: capture_har.py announces the caller's identity, including none"

# A navigation that never settles is the partial capture this script exists for,
# so it stays a success. Anything else -- DNS failure, refused connection -- is a
# real error, and reporting 0 for it made a capture of nothing indistinguishable
# from a good one to every caller that checks the exit status.
CAPTURE_HAR_STUB_RECORD="$tmp/ua-timeout.json" CAPTURE_HAR_STUB_GOTO=timeout \
    PYTHONPATH="$tmp/stub" python3 "$scripts/capture_har.py" \
    --url https://example.com --output "$tmp/cap-timeout.har" >/dev/null 2>&1 \
    || fail "a navigation timeout should still be a successful partial capture"

CAPTURE_HAR_STUB_RECORD="$tmp/ua-error.json" CAPTURE_HAR_STUB_GOTO=error \
    PYTHONPATH="$tmp/stub" python3 "$scripts/capture_har.py" \
    --url https://example.com --output "$tmp/cap-error.har" >/dev/null 2>&1 \
    && fail "a failed navigation reported success"
[ -f "$tmp/cap-error.har" ] \
    || fail "the HAR was not written on the failure path — the partial capture is lost"
echo "PASS: capture_har.py separates a timeout from a failed navigation"

# --- --help on every shipped script -----------------------------------------
for script in "$scripts"/*.py; do
    case "$(basename "$script")" in _*) continue ;; esac
    py "$script" --help >/dev/null 2>&1 || fail "$(basename "$script") has no working --help"
done
echo "PASS: every shipped script answers --help"

echo "PASS: har_test.sh (stage ${stage})"
