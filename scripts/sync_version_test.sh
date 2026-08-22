#!/usr/bin/env bash
# sync_version_test.sh — unit test for scripts/sync_version.py.
# Builds a fake repo tree (drifted versions) under a temp --repo-root and verifies:
#   --check exits 1 and names every drifted target; apply rewrites all targets to
#   the canonical .bundle-version while preserving surrounding formatting; a synced
#   tree then passes --check with exit 0.
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYNC="${SCRIPT_DIR}/sync_version.py"

if [[ ! -f "${SYNC}" ]]; then
    echo "SKIP: sync_version.py not found at ${SYNC}" >&2; exit 0
fi

tmp=$(mktemp -d)
cleanup() { rm -rf "${tmp}"; }
trap cleanup EXIT

# --- Build a fake repo tree with every version-bearing file, all drifted. ---
mkdir -p "${tmp}/plugins/core/skills/init/assets" \
         "${tmp}/plugins/core/.claude-plugin" \
         "${tmp}/plugins/skill-workshop/.claude-plugin" \
         "${tmp}/docs"

printf '0.15.0\n' > "${tmp}/plugins/core/skills/init/assets/.bundle-version"

cat > "${tmp}/plugins/core/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "core",
  "version": "0.4.0",
  "description": "x"
}
JSON

# skill-workshop uses a one-line author object — formatting must survive the sync.
cat > "${tmp}/plugins/skill-workshop/.claude-plugin/plugin.json" <<'JSON'
{
  "name": "skill-workshop",
  "version": "0.1.0",
  "author": { "name": "nuncaeslupus" }
}
JSON

cat > "${tmp}/plugins/core/skills/init/assets/AGENTS.md" <<'MD'
# Claude Arsenal

<!-- claude-arsenal v0.14.0 — imported via @claude-arsenal/AGENTS.md -->

body
MD

# INSTALL.md carries TWO tag-form pins — both must be checked and rewritten, so a
# regression back to a single-token (count=1 / .search) sync is caught here.
cat > "${tmp}/docs/INSTALL.md" <<'MD'
ARSENAL_REF     ?= v0.11.0   # pin to a tag
git commit -m "chore: vendor claude-arsenal skills @ v0.11.0"
MD

fail() { echo "FAIL: $1" >&2; exit 1; }

# --- Gate 1: --check reports drift on every target and exits 1. ---
out="$(python3 "${SYNC}" --repo-root "${tmp}" --check 2>&1)"; rc=$?
[[ "${rc}" -eq 1 ]] || fail "drifted tree should --check exit 1, got ${rc}: ${out}"
for label in "core/plugin.json" "skill-workshop/plugin.json" "AGENTS.md header" \
             "INSTALL.md ARSENAL_REF pin"; do
    printf '%s' "${out}" | grep -qF "${label}" || fail "--check did not name '${label}': ${out}"
done
echo "PASS: --check names every drifted target and exits 1"

# --- Gate 2: apply rewrites every target to 0.15.0. ---
python3 "${SYNC}" --repo-root "${tmp}" >/dev/null || fail "apply exited non-zero"
grep -q '"version": "0.15.0"' "${tmp}/plugins/core/.claude-plugin/plugin.json" \
    || fail "core/plugin.json not synced to 0.15.0"
grep -q '"version": "0.15.0"' "${tmp}/plugins/skill-workshop/.claude-plugin/plugin.json" \
    || fail "skill-workshop/plugin.json not synced to 0.15.0"
grep -q "<!-- claude-arsenal v0.15.0 " "${tmp}/plugins/core/skills/init/assets/AGENTS.md" \
    || fail "AGENTS.md header not synced to 0.15.0"
# Both INSTALL.md pins must land on the canonical version (no stale token left behind).
[[ "$(grep -c "v0.15.0" "${tmp}/docs/INSTALL.md")" -eq 2 ]] \
    || fail "INSTALL.md should have 2 pins synced to v0.15.0"
grep -q "v0.11.0" "${tmp}/docs/INSTALL.md" \
    && fail "INSTALL.md still has a stale v0.11.0 pin (count=1 regression?)"
echo "PASS: apply rewrites every target to the canonical version"

# --- Gate 3: formatting around the version token is preserved. ---
grep -qF '"author": { "name": "nuncaeslupus" }' \
    "${tmp}/plugins/skill-workshop/.claude-plugin/plugin.json" \
    || fail "apply reformatted the skill-workshop author line"
grep -qF "— imported via @claude-arsenal/AGENTS.md -->" \
    "${tmp}/plugins/core/skills/init/assets/AGENTS.md" \
    || fail "apply mangled the AGENTS.md header comment tail"
echo "PASS: surrounding formatting preserved"

# --- Gate 4: a synced tree passes --check with exit 0. ---
cout="$(python3 "${SYNC}" --repo-root "${tmp}" --check 2>&1)"; crc=$?
[[ "${crc}" -eq 0 ]] || fail "synced tree should --check exit 0, got ${crc}: ${cout}"
printf '%s' "${cout}" | grep -qi "all versions match" || fail "synced --check missing OK line: ${cout}"
echo "PASS: synced tree passes --check (exit 0)"

# --- Gate 5: a malformed .bundle-version is rejected (exit 2), not silently synced. ---
printf 'not-a-version\n' > "${tmp}/plugins/core/skills/init/assets/.bundle-version"
python3 "${SYNC}" --repo-root "${tmp}" --check >/dev/null 2>&1; brc=$?
[[ "${brc}" -eq 2 ]] || fail "malformed .bundle-version should exit 2, got ${brc}"
echo "PASS: malformed .bundle-version is rejected (exit 2)"

echo "PASS: sync_version_test — all gates passed"
exit 0
