#!/usr/bin/env bash
# sync_sections_test.sh — the shipped capability map cannot drift from the
# skills it describes, and a new section cannot ship without a description.
#
# `sections.json` is generated data that a consumer reads on every session. Two
# ways it goes wrong silently: it stops matching the skills after one is added
# or re-filed, and a section ships with no blurb, which is a blank row on every
# consumer's map rather than an error anyone sees. Both are checks, not habits.
#
# Exit: 0 PASS, 1 FAIL.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/.." && pwd)"
script="$root/scripts/sync_sections.py"
manifest="$root/plugins/core/skills/init/assets/sections.json"
fail() { echo "FAIL: $1" >&2; exit 1; }

# `python3`, not `uv run python`: the `core tests` job sets up bare python3 on
# purpose — it exists to prove the scripts work the way a consumer runs them —
# so `uv` is not on PATH there. Reaching for it turned a missing TOOL into a
# reported content failure, which is the same conflation this suite already
# fixed twice today.
run_check() { python3 "$script" "$@"; }

# --- the committed manifest matches the committed skills --------------------
# The checker's own output is shown on failure, not swallowed: "it has drifted"
# without the diff leaves nothing to act on. `--check` prints a unified diff.
check_out="$(run_check --check 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && [ "$rc" -ne 1 ]; then
    printf '%s\n' "$check_out" >&2
    fail "the drift checker could not run (exit $rc) — that is not the same as drift"
fi
if [ "$rc" -eq 1 ]; then
    printf '%s\n' "$check_out" >&2
    fail "committed sections.json has drifted; run 'make sync-sections'"
fi
echo "PASS: committed manifest matches the shipped skills"

# What the runner actually sees, for the same reason. A skill directory left
# behind by an earlier test, or one that never got committed, changes the
# answer and is invisible from the drift message alone.
echo "  skills on disk: $(find "$root/plugins/core/skills" -mindepth 2 -maxdepth 2 \
    -name SKILL.md | wc -l | tr -d ' ') SKILL.md files"

# --- drift is detected ------------------------------------------------------
backup="$(mktemp)"; cp "$manifest" "$backup"
restore() { cp "$backup" "$manifest"; rm -f "$backup"; }
trap restore EXIT

python3 - "$manifest" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d["sections"][0]["skills"].append({"name": "not-a-skill", "description": "invented"})
json.dump(d, open(p, "w"), indent=2, ensure_ascii=False)
PY
run_check --check >/dev/null 2>&1 \
    && fail "--check passed a manifest listing a skill that does not exist"
echo "PASS: drift between the manifest and the skills is detected"
restore; trap - EXIT

# --- a section with no blurb is an error, not a blank row -------------------
tmpskill="$root/plugins/core/skills/_sync_sections_probe"
cleanup() { rm -rf "$tmpskill"; cp "$backup" "$manifest" 2>/dev/null || true; rm -f "$backup"; }
backup="$(mktemp)"; cp "$manifest" "$backup"; trap cleanup EXIT
mkdir -p "$tmpskill"
cat > "$tmpskill/SKILL.md" <<'SKILL'
---
name: _sync_sections_probe
description: Temporary probe skill used by sync_sections_test.sh.
metadata:
  section: nosuchsection
---

# probe
SKILL

out="$(run_check 2>&1)"
rc=$?
[ "$rc" -eq 0 ] && fail "a section with no SECTION_BLURBS entry was accepted"
grep -q "SECTION_BLURBS" <<<"$out" \
    || fail "the failure did not name what to add: $out"
echo "PASS: a shipped section with no blurb fails the generator"

cleanup; trap - EXIT
run_check --check >/dev/null 2>&1 || fail "cleanup left the manifest drifted"
echo "PASS: sync_sections_test.sh"
