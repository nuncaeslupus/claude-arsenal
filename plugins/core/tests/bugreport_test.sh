#!/usr/bin/env bash
# bugreport_test.sh — the Android bugreport toolkit, at the level a session uses it.
#
# Two layers, both run from here so `make test` discovers everything through one
# entry point:
#
#   * pytest over `bugreport/test_*.py` — scanner, input resolution, index,
#     redaction, clock, budget. Unit problems, asserted at unit level.
#   * the CLI assertions below — exit codes, the fallback route, the read-only
#     guarantee, and that every command SKILL.md shows runs as written.
#
# Fixtures are synthetic (make_fixture.py); no real report is ever used (D-9).
#
# Exit: 0 PASS, 1 FAIL.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
skill="$here/../skills/bugreport"
scripts="$skill/scripts"

tmp="$(mktemp -d)" || { echo "FAIL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
# Bare python3, like har_test.sh: the shipped scripts are stdlib-only and the
# `core tests` job proves it by running them without uv.
py() { (cd "$root" && python3 "$@"); }
q() { py "$scripts/query_bugreport.py" "$@" --output-dir "$tmp/cache"; }

py "$here/bugreport/make_fixture.py" --layout modern --container zip --seed 1 --out "$tmp" >/dev/null \
    || fail "fixture generation failed"
py "$here/bugreport/make_fixture.py" --layout xiaomi --seed 1 --out "$tmp" >/dev/null \
    || fail "OEM fixture generation failed"
zipfx="$tmp/modern-1-zip.zip"
oemfx="$tmp/xiaomi-1.txt"
[ -s "$zipfx" ] && [ -s "$oemfx" ] || fail "fixtures were not written"
echo "PASS: fixtures build"

# --- the unit layer ---------------------------------------------------------
# pytest is a dev dependency, absent from the bare-python job by design; the
# skip is reported by name, and `make test-units` runs this layer.
if python3 -c "import pytest" >/dev/null 2>&1; then
    (cd "$root" && python3 -m pytest plugins/core/tests/bugreport -q) || fail "pytest layer failed"
    echo "PASS: pytest — scanner, input, index, redaction, clock, budget"
else
    echo "SKIP: pytest not importable here — the unit layer runs in \`make test-units\`"
fi

# --- test_every_bugreport_script_answers_help -------------------------------
for script in "$scripts"/*.py; do
    case "$(basename "$script")" in _*) continue ;; esac
    py "$script" --help >/dev/null 2>&1 || fail "$(basename "$script") has no working --help"
done
echo "PASS: every bugreport script answers --help"

# --- test_unparsed_section_reaches_fields_in_two_commands -------------------
#     An OEM section no command parses: locate finds it, sample shows its keys.
out="$(q locate --input "$oemfx" --grep powerup_reason)" || fail "locate exited non-zero"
grep -q '"POWERUP_REASON#1"' <<<"$out" || fail "locate did not name the OEM section: $out"
out="$(q sample --input "$oemfx" --section POWERUP_REASON)" || fail "sample exited non-zero"
grep -q 'powerup_reason_name' <<<"$out" || fail "sample did not show the section's keys: $out"
grep -q '"format": "kv"' <<<"$out" || fail "sample did not sniff the kv shape: $out"
echo "PASS: an unparsed OEM section reaches its fields in two commands"

# --- test_query_never_writes_the_input --------------------------------------
before="$(sha256sum "$zipfx" | cut -d' ' -f1)"
q summary --input "$zipfx" >/dev/null || fail "summary exited non-zero"
q show --input "$zipfx" --section battery --force >/dev/null || fail "show exited non-zero"
[ "$(sha256sum "$zipfx" | cut -d' ' -f1)" = "$before" ] || fail "a query modified its input"
echo "PASS: queries never write the input"

# --- test_non_bugreport_exits_1 ---------------------------------------------
printf 'just some text\nnot a dumpstate\n' >"$tmp/not.txt"
py "$scripts/validate_bugreport.py" --input "$tmp/not.txt" --output-dir "$tmp/cache" >/dev/null 2>&1
[ $? -eq 1 ] || fail "validate did not exit 1 on a non-bugreport"
q summary --input "$tmp/not.txt" >/dev/null 2>&1
[ $? -eq 1 ] || fail "query did not exit 1 on a non-bugreport"
echo "PASS: a non-bugreport exits 1"

# --- test_skill_md_commands_resolve_to_existing_scripts_and_flags -----------
#     Every command in SKILL.md's bash block runs as written against the fixture.
n=0
while IFS= read -r line; do
    cmd="${line%%#*}"
    cmd="${cmd//\$\{CLAUDE_SKILL_DIR\}/$skill}"
    cmd="${cmd//bugreport.zip/$zipfx}"
    (cd "$root" && eval "$cmd --output-dir '$tmp/cache'") >/dev/null 2>"$tmp/err" \
        || fail "SKILL.md command failed: $line — $(cat "$tmp/err")"
    n=$((n + 1))
done < <(sed -n '/^```bash$/,/^```$/p' "$skill/SKILL.md" | grep '_bugreport.py')
[ "$n" -ge 5 ] || fail "found only $n SKILL.md commands — the block parser is broken"
echo "PASS: all $n SKILL.md commands run as written"

# --- the T4 index gates at a tenth of the scale ------------------------------
#     The full 160 MB run is bugreport-benchmark.yml (dispatch); this one keeps
#     a regression from waiting for someone to dispatch it.
bench="$(py "$here/bugreport/benchmark.py" --target-mb 16 --zip-mb 23.4 --output-dir "$tmp/bench" --json)" \
    || fail "benchmark missed a gate: $bench"
echo "PASS: index build, zip build and reuse within their gates at 1/10 scale"

# --- test_skill_folder_has_no_must_findings ---------------------------------
py "$root/plugins/skill-workshop/skills/skill-workshop/scripts/validate.py" "$skill" >"$tmp/val" 2>&1 \
    || fail "skill-workshop validate.py reported failures: $(cat "$tmp/val")"
echo "PASS: skill folder has no must findings"

echo "PASS: bugreport_test.sh"
