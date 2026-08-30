#!/usr/bin/env bash
# list_sections_test.sh — the capability map tells a repo about the skills it
# did NOT install.
#
# Sections made the install set a choice, and a choice creates a thing nobody
# knows about: the only place a skill announces itself is the resident skills
# listing, which lists exactly the skills that were installed. A consumer who
# never enabled `python` has no way to learn `coverage-gaps` exists.
#
# The constraint that shapes the whole design: a VENDORED init.py cannot see
# the skills it did not install. `_source_skills_dir()` resolves to the
# consumer's own `.claude/skills/`, already pruned. So the map is shipped data
# (`assets/sections.json`), and the case with teeth is the one this test runs
# from the vendored copy with no marketplace anywhere near it.
#
# Exit: 0 PASS, 1 FAIL.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
init_py="$here/../skills/init/scripts/init.py"
tmp="$(mktemp -d)" || { echo "FAIL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# --- SC5: a vendored copy names an uninstalled section's skills -------------
repo="$tmp/general"; mkdir -p "$repo"
python3 "$init_py" --repo-path "$repo" --profile general >/dev/null 2>&1 \
    || fail "install with --profile general exited non-zero"
vendored="$repo/.claude/skills/init/scripts/init.py"
[ -f "$vendored" ] || fail "init was not vendored into the consumer repo"
[ -f "$repo/.claude/skills/coverage-gaps/SKILL.md" ] \
    && fail "setup: python section should be off under --profile general"

out="$(python3 "$vendored" --repo-path "$repo" --list-sections 2>&1)" \
    || fail "--list-sections exited non-zero from the vendored copy"
grep -q "python" <<<"$out" || fail "vendored map does not name the uninstalled 'python' section"
grep -q "coverage-gaps" <<<"$out" \
    || fail "vendored map does not name coverage-gaps — the whole point is naming what is absent"
echo "PASS: SC5 — a vendored copy names the skills it did not install"

# --- SC2: on/off is truthful about this repo --------------------------------
grep -qE "^  python +off" <<<"$out" || fail "python not marked off in a repo that lacks it"
grep -qE "^  workflow +on" <<<"$out" || fail "workflow not marked on in a repo that has it"
grep -qE "^  core +on" <<<"$out" || fail "core not marked on"
grep -q "1 of 3 installed here\|2 of 3 installed here" <<<"$out" \
    || fail "header count does not match the sections: $out"

repo2="$tmp/all"; mkdir -p "$repo2"
python3 "$init_py" --repo-path "$repo2" --profile all >/dev/null 2>&1 \
    || fail "install with --profile all exited non-zero"
out2="$(python3 "$repo2/.claude/skills/init/scripts/init.py" --repo-path "$repo2" --list-sections 2>&1)"
grep -qE "^  python +on" <<<"$out2" || fail "python not marked on after --profile all"
grep -q "coverage-gaps" <<<"$out2" \
    && fail "installed section still lists its skills — they are already in the resident listing"
echo "PASS: SC2 — on/off matches what is on disk, both ways"

# --- writes nothing ---------------------------------------------------------
before="$(cd "$repo" && find . -type f | sort | xargs -r shasum | shasum)"
python3 "$vendored" --repo-path "$repo" --list-sections >/dev/null 2>&1
after="$(cd "$repo" && find . -type f | sort | xargs -r shasum | shasum)"
[ "$before" = "$after" ] || fail "--list-sections modified the repo; it must be read-only"
echo "PASS: --list-sections writes nothing"

# --- --section NAME: detail for a section this repo does not have -----------
detail="$(python3 "$vendored" --repo-path "$repo" --section python 2>&1)" \
    || fail "--section python exited non-zero"
grep -q "NOT installed here" <<<"$detail" || fail "--section did not report install state"
grep -q "coverage.py" <<<"$detail" \
    || fail "--section did not print the skill descriptions — that is what it is for"
python3 "$vendored" --repo-path "$repo" --section nosuch >/dev/null 2>&1 \
    && fail "--section with an unknown name should exit non-zero"
echo "PASS: --section NAME — per-skill detail for an absent section"

# --- degraded mode: a bundle that predates the shipped map ------------------
repo3="$tmp/old"; mkdir -p "$repo3"
python3 "$init_py" --repo-path "$repo3" --profile general >/dev/null 2>&1
rm -f "$repo3/.claude/skills/init/assets/sections.json"
out3="$(python3 "$repo3/.claude/skills/init/scripts/init.py" --repo-path "$repo3" --list-sections 2>&1)" \
    || fail "degraded mode exited non-zero; a missing manifest must not break a protocol step"
grep -q "predates the shipped map" <<<"$out3" \
    || fail "degraded mode did not say the map is partial — wrong-but-labelled beats silent"
echo "PASS: degraded mode — missing manifest reports itself instead of crashing"

# --- SC3: the map stays a map ----------------------------------------------
bytes="$(printf '%s' "$out" | wc -c)"
[ "$bytes" -le 1200 ] || fail "map is ${bytes} bytes; it is read once per session and must stay short"
lines="$(printf '%s\n' "$out" | wc -l)"
[ "$lines" -le 12 ] || fail "map is ${lines} lines; one line per section is the budget"
echo "PASS: SC3 — ${bytes} bytes, ${lines} lines"

echo "PASS: list_sections_test.sh"
