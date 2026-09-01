#!/usr/bin/env bash
# skill_sections_test.sh — /init installs the skill sections a repo chose, and
# nothing else.
#
# Vendoring used to be all-or-nothing: every consumer carried all 17 core
# skills, paying for each one in the resident skills listing of every session
# forever. Sections make that a choice. The three cases with teeth:
#
#   fresh    — shipped defaults, and `python` is NOT among them.
#   upgrade  — a repo already using the Python skills, whose config predates
#              [skills], must keep them. Applying the fresh defaults here would
#              silently delete five skills from a working repo during the
#              `init.py --silent` the session protocol runs unattended.
#   opt-out  — flipping a section to false in config.toml prunes its skills and
#              STAYS pruned across the next init, which is the whole difference
#              between a setting and deleting a directory by hand.
#
# Exit: 0 PASS, 1 FAIL.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
init_py="$here/../skills/init/scripts/init.py"
tmp="$(mktemp -d)" || { echo "FAIL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

have() { [ -f "$1/.claude/skills/$2/SKILL.md" ]; }

# --- fresh install: defaults, python off ------------------------------------
repo="$tmp/fresh"; mkdir -p "$repo"
python3 "$init_py" --repo-path "$repo" >/dev/null 2>&1 || fail "fresh init exited non-zero"

have "$repo" init      || fail "fresh: core skill 'init' not installed"
have "$repo" github    || fail "fresh: core skill 'github' not installed"
have "$repo" specify   || fail "fresh: workflow section should default on"
have "$repo" dep-upgrade && fail "fresh: python section should default OFF"
grep -q '^\[skills\]' "$repo/arsenal/config.toml" || fail "fresh: no [skills] table recorded"
grep -q '^python = false' "$repo/arsenal/config.toml" || fail "fresh: python not recorded false"
grep -q '^workflow = true' "$repo/arsenal/config.toml" || fail "fresh: workflow not recorded true"
echo "PASS: fresh install — core + workflow, python off, decision recorded"

# --- a profile is an explicit answer ----------------------------------------
repo="$tmp/py"; mkdir -p "$repo"
python3 "$init_py" --repo-path "$repo" --profile python >/dev/null 2>&1 \
    || fail "--profile python exited non-zero"
have "$repo" dep-upgrade || fail "--profile python did not install the python section"
have "$repo" specify     || fail "--profile python should include workflow"

repo="$tmp/min"; mkdir -p "$repo"
python3 "$init_py" --repo-path "$repo" --profile minimal >/dev/null 2>&1 \
    || fail "--profile minimal exited non-zero"
have "$repo" init    || fail "--profile minimal must still install core"
have "$repo" specify && fail "--profile minimal installed the workflow section"
echo "PASS: --profile selects sections; core is never dropped"

# a typo must be loud — installing fewer skills than asked for is invisible
python3 "$init_py" --repo-path "$tmp/min" --sections pyhton >/dev/null 2>&1 \
    && fail "a misspelled section was accepted"
echo "PASS: unknown section is fatal"

# --- upgrade: a repo already using python skills keeps them -----------------
repo="$tmp/upgrade"; mkdir -p "$repo"
python3 "$init_py" --repo-path "$repo" --profile python >/dev/null 2>&1 \
    || fail "upgrade fixture init failed"
# rewind to a pre-sections world: the skills are on disk, the config has no table
python3 - "$repo/arsenal/config.toml" <<'PY'
import re, sys
p = sys.argv[1]
text = open(p).read()
open(p, "w").write(re.sub(r"^\[skills\]\n(?:[a-z-]+ = \w+\n)*", "", text, flags=re.M))
PY
grep -q '^\[skills\]' "$repo/arsenal/config.toml" && fail "fixture still has a [skills] table"

python3 "$init_py" --repo-path "$repo" --silent >/dev/null 2>&1 || fail "upgrade init exited non-zero"
have "$repo" dep-upgrade || fail "UPGRADE DELETED the python skills a repo was using"
have "$repo" specify     || fail "upgrade dropped the workflow skills"
grep -q '^python = true' "$repo/arsenal/config.toml" || fail "upgrade did not record what it found"
echo "PASS: upgrade preserves the sections already in use, and records them"

# --- opt-out is durable across the next init --------------------------------
repo="$tmp/optout"; mkdir -p "$repo"
python3 "$init_py" --repo-path "$repo" --profile python >/dev/null 2>&1 || fail "optout fixture failed"
have "$repo" mutmut-report || fail "optout fixture missing python skills"
sed -i 's/^python = true/python = false/' "$repo/arsenal/config.toml"

python3 "$init_py" --repo-path "$repo" --silent >/dev/null 2>&1 || fail "optout init exited non-zero"
have "$repo" mutmut-report && fail "a section switched off in config.toml was still installed"
have "$repo" specify       || fail "opting out of python removed the workflow skills too"

python3 "$init_py" --repo-path "$repo" --silent >/dev/null 2>&1 || fail "second init exited non-zero"
have "$repo" mutmut-report && fail "the opt-out did not survive the next init"
echo "PASS: opting a section out prunes it, and it stays pruned"

# --- an explicit --sections list wins outright over --profile ---------------
# The CLI documents --sections as overriding --profile. Unioning them instead
# means `--profile python --sections workflow` still installs python: skills the
# user did not ask for, which is the failure nobody notices because it is silent.
repo="$tmp/override"; mkdir -p "$repo"
python3 "$init_py" --repo-path "$repo" --profile python --sections workflow >/dev/null 2>&1 \
    || fail "--profile with --sections exited non-zero"
have "$repo" specify     || fail "--sections workflow did not install workflow"
have "$repo" dep-upgrade && fail "--sections did not override --profile python"
echo "PASS: --sections overrides --profile"

repo="$tmp/empty"; mkdir -p "$repo"
python3 "$init_py" --repo-path "$repo" --sections "" >/dev/null 2>&1 \
    || fail '--sections "" exited non-zero'
have "$repo" init    || fail '--sections "" dropped core'
have "$repo" specify && fail '--sections "" fell back to the defaults'
echo 'PASS: --sections "" means core only, not "unset"'

# --- a malformed [skills] value stops the install, it does not prune --------
# `workflow = treu` used to read as false and silently delete six skills.
repo="$tmp/malformed"; mkdir -p "$repo"
python3 "$init_py" --repo-path "$repo" --profile general >/dev/null 2>&1 || fail "fixture failed"
sed -i 's/^workflow = true/workflow = "treu"/' "$repo/arsenal/config.toml"
python3 "$init_py" --repo-path "$repo" --silent >/dev/null 2>&1 \
    && fail "a non-boolean [skills] value was accepted"
have "$repo" specify || fail "a refused install pruned skills anyway"
echo "PASS: non-boolean [skills] value is fatal, and prunes nothing"

# --- a misspelled KEY must not silently disable a section -------------------
# Unknown names stay tolerated (a repo that ran a newer bundle carries sections
# this one has not heard of), so the safety comes from the other side: a known
# name absent from the table falls back to its shipped default, not to off.
repo="$tmp/typokey"; mkdir -p "$repo"
python3 "$init_py" --repo-path "$repo" --profile general >/dev/null 2>&1 || fail "fixture failed"
sed -i 's/^workflow = true/worklfow = true/' "$repo/arsenal/config.toml"
python3 "$init_py" --repo-path "$repo" --silent >/dev/null 2>&1 || fail "typo key exited non-zero"
have "$repo" specify || fail "a misspelled key silently pruned the workflow skills"
echo "PASS: a misspelled [skills] key does not prune anything"

# --- invalid TOML is loud rather than treated as 'no table' -----------------
repo="$tmp/badtoml"; mkdir -p "$repo"
python3 "$init_py" --repo-path "$repo" --profile general >/dev/null 2>&1 || fail "fixture failed"
printf '\nthis is not = = toml\n' >> "$repo/arsenal/config.toml"
python3 "$init_py" --repo-path "$repo" --silent >/dev/null 2>&1 \
    && fail "invalid TOML was accepted"
echo "PASS: invalid config.toml stops the install"

# --- a skill the consumer wrote is still never touched ----------------------
repo="$tmp/mine"; mkdir -p "$repo/.claude/skills/mine"
echo "x" > "$repo/.claude/skills/mine/SKILL.md"
python3 "$init_py" --repo-path "$repo" --profile minimal >/dev/null 2>&1 || fail "init exited non-zero"
have "$repo" mine || fail "pruning removed a skill the consumer authored"
echo "PASS: consumer-authored skills survive section pruning"

# --- upgrade from a bundle that predates `section:` altogether ---------------
# The case above strips the [skills] table but leaves the metadata in the
# installed SKILL.md files, so section inference still has something to read. A
# bundle old enough to predate sections has no `section:` line anywhere: every
# directory then classified as `core`, the inferred set emptied, and the prune
# loop rmtree-d the consumer's workflow and python skills on the `--silent`
# upgrade the session protocol runs unattended.
repo="$tmp/presection"; mkdir -p "$repo"
python3 "$init_py" --repo-path "$repo" --profile python >/dev/null 2>&1 \
    || fail "pre-section fixture init failed"
python3 - "$repo/arsenal/config.toml" <<'PY'
import re, sys
p = sys.argv[1]
text = open(p).read()
open(p, "w").write(re.sub(r"^\[skills\]\n(?:[a-z-]+ = \w+\n)*", "", text, flags=re.M))
PY
# and rewind the skills themselves to a world with no section metadata
find "$repo/.claude/skills" -name SKILL.md -exec sed -i.bak '/^ *section: /d' {} \; \
    || fail "could not strip section metadata from the fixture"
find "$repo/.claude/skills" -name '*.bak' -delete
grep -rq '^ *section: ' "$repo/.claude/skills" && fail "fixture still carries section metadata"

python3 "$init_py" --repo-path "$repo" --silent >/dev/null 2>&1 \
    || fail "pre-section upgrade exited non-zero"
have "$repo" dep-upgrade || fail "PRE-SECTION UPGRADE DELETED the python skills"
have "$repo" specify     || fail "PRE-SECTION UPGRADE DELETED the workflow skills"
grep -q '^python = true' "$repo/arsenal/config.toml" \
    || fail "pre-section upgrade recorded no sections"
echo "PASS: an upgrade from a pre-section bundle keeps its skills"

# --- 'sections off' names the opt-in sections too ---------------------------
# A section that ships with no _SECTION_DEFAULTS entry is off by default —
# opt-in — and opt-in is what "new" looks like, so it is exactly what a
# consumer is most likely to be missing and least likely to know about.
repo="$tmp/offline"; mkdir -p "$repo"
out="$(python3 "$init_py" --repo-path "$repo" 2>&1)" || fail "init exited non-zero"
echo "$out" | grep -q 'sections off:.*extract' \
    || fail "the sections-off line omits the opt-in section 'extract': $out"
echo "$out" | grep -q 'sections off:.*python' || fail "the sections-off line lost 'python'"
echo "$out" | grep -q 'sections off:.*core' && fail "core is not an optional section"
echo "PASS: 'sections off' reports opt-in sections, not only default-off ones"

# --- --sections is honoured under --workspace -------------------------------
# Accepted-and-ignored is the expensive direction of silent: the caller believes
# the section is on and finds out when a skill they asked for is not there.
repo="$tmp/ws"; mkdir -p "$repo"
python3 "$init_py" --repo-path "$repo" --workspace demo --sections extract >/dev/null 2>&1 \
    || fail "--workspace with --sections exited non-zero"
have "$repo" har || fail "--sections extract was ignored under --workspace"
grep -q '^extract = true' "$repo/arsenal/config.toml" \
    || fail "--workspace did not record the sections it was given"

# and again on a repo that already has a bundle, where the base install is not
# re-run for its own sake
repo="$tmp/ws2"; mkdir -p "$repo"
python3 "$init_py" --repo-path "$repo" >/dev/null 2>&1 || fail "base init failed"
have "$repo" har && fail "fixture should not start with the extract section"
python3 "$init_py" --repo-path "$repo" --workspace demo --profile all >/dev/null 2>&1 \
    || fail "--workspace with --profile exited non-zero"
have "$repo" har || fail "--profile all was ignored under --workspace on an existing install"
echo "PASS: --sections and --profile take effect under --workspace"
