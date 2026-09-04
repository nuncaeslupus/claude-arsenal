#!/usr/bin/env bash
# init_shadow_sections_test.sh — the handover the bundle used to shadow (#353),
# and a section the bundle ships but a vendored init could not name (#354).
#
# Both are silent failures: an empty handover reads exactly like a fresh
# install, and a section dropped from `known` still prints the usual success
# line. Neither raises anything for a test to catch except the outcome itself.
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT="${SCRIPT_DIR}/../skills/init/scripts/init.py"
MANIFEST="${SCRIPT_DIR}/../skills/init/assets/sections.json"

[[ -f "${INIT}" ]] || { echo "SKIP: init.py not found" >&2; exit 0; }

fail() { echo "FAIL: $*" >&2; exit 1; }

tmp=$(mktemp -d)
cleanup() { cd /; rm -rf "${tmp}"; }
trap cleanup EXIT

# --- #353: the bundle must not ship a handover under its own prefix ----------
# The asset is what `_refresh_bundle` copied into `claude-arsenal/session/`,
# recreating it on every run after the host tree moved to `arsenal/`.
if [[ -f "${SCRIPT_DIR}/../skills/init/assets/session/handover.md" ]]; then
    fail "assets/session/handover.md is back — it shadows arsenal/session/handover.md"
fi
echo "PASS: the bundle ships no handover under its own prefix"

repo="${tmp}/repo"
mkdir -p "${repo}"
git init -q -b main "${repo}"
(cd "${repo}" && python3 "${INIT}" --repo-path . --silent >/dev/null 2>&1) \
    || fail "init failed on a fresh repo"

[[ -f "${repo}/arsenal/session/handover.md" ]] \
    || fail "the host handover was not scaffolded"
[[ -e "${repo}/claude-arsenal/session/handover.md" ]] \
    && fail "a fresh install created the shadow handover"
echo "PASS: a fresh install scaffolds one handover, in the host tree"

# An upgraded consumer carries the shadow. Untouched, it must be retired.
mkdir -p "${repo}/claude-arsenal/session"
printf '# Session Handover\n\n<!-- Written at session end. -->\n' \
    > "${repo}/claude-arsenal/session/handover.md"
out="$(cd "${repo}" && python3 "${INIT}" --repo-path . 2>&1)"
[[ -e "${repo}/claude-arsenal/session/handover.md" ]] \
    && fail "an untouched shadow handover survived: ${out}"
grep -q "removed:" <<<"${out}" || fail "the removal was not reported: ${out}"
echo "PASS: an untouched shadow handover is removed and reported"

# One somebody wrote into is data. It must survive, and be reported.
mkdir -p "${repo}/claude-arsenal/session"
printf '# Session Handover\n\nParser shipped; CLI half done.\n' \
    > "${repo}/claude-arsenal/session/handover.md"
out="$(cd "${repo}" && python3 "${INIT}" --repo-path . 2>&1)"
grep -qF "Parser shipped" "${repo}/claude-arsenal/session/handover.md" \
    || fail "a written shadow handover was DELETED — data loss"
grep -q "WARNING" <<<"${out}" || fail "a written shadow handover was not reported: ${out}"
echo "PASS: a written shadow handover is preserved and reported, never deleted"

# The host's own handover is never clobbered by any of this.
printf 'REAL HANDOVER CONTENT\n' > "${repo}/arsenal/session/handover.md"
(cd "${repo}" && python3 "${INIT}" --repo-path . --silent >/dev/null 2>&1)
grep -qF "REAL HANDOVER CONTENT" "${repo}/arsenal/session/handover.md" \
    || fail "init overwrote the host handover"
echo "PASS: the host handover is never overwritten"

# --- #354: every section the manifest ships is requestable --------------------
# A VENDORED init.py's source dir is the consumer's own .claude/skills/, which
# holds only what is installed — so a section whose skills are all un-vendored
# was invisible: unrequestable because uninstalled, uninstalled because
# unrequestable. sections.json ships beside the script and knows the full set.
[[ -f "${MANIFEST}" ]] || { echo "SKIP: sections.json not found" >&2; exit 0; }

vend="${tmp}/vendored/.claude/skills"
mkdir -p "${vend}/init/scripts" "${vend}/init/assets" "${tmp}/vendored/arsenal"
cp "${INIT}" "${vend}/init/scripts/"
cp "${MANIFEST}" "${vend}/init/assets/"
printf -- '---\nname: init\n---\nx\n' > "${vend}/init/SKILL.md"
for s in specify execution; do
    mkdir -p "${vend}/${s}"
    printf -- '---\nname: %s\nmetadata:\n  section: workflow\n---\nx\n' "${s}" \
        > "${vend}/${s}/SKILL.md"
done

# Pick a section the manifest ships that has no skill installed in this fixture.
absent="$(python3 - "${MANIFEST}" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
for entry in data["sections"]:
    if entry["name"] not in {"core", "workflow"}:
        print(entry["name"]); break
PY
)"
[[ -n "${absent}" ]] || { echo "SKIP: manifest ships no non-default section" >&2; exit 0; }

out="$(cd "${tmp}/vendored" && python3 "${vend}/init/scripts/init.py" \
    --repo-path . --sections "${absent}" 2>&1)"
grep -q "unknown section" <<<"${out}" \
    && fail "a section the manifest ships was rejected as unknown: ${out}"
grep -q "are enabled but no skill for them is installed" <<<"${out}" \
    || fail "the vendored no-op was not explained: ${out}"
echo "PASS: a manifest section is requestable, and the vendored no-op is explained"

# Via config.toml the same request used to be dropped in silence.
printf '[skills]\nworkflow = true\n%s = true\n' "${absent}" \
    > "${tmp}/vendored/arsenal/config.toml"
out="$(cd "${tmp}/vendored" && python3 "${vend}/init/scripts/init.py" --repo-path . 2>&1)"
grep -q "${absent}" <<<"${out}" \
    || fail "config.toml enabling '${absent}' was silently ignored: ${out}"
echo "PASS: a section enabled in config.toml is no longer dropped in silence"

# And a section that IS satisfied must not be reported as empty.
printf '[skills]\nworkflow = true\n%s = false\n' "${absent}" \
    > "${tmp}/vendored/arsenal/config.toml"
out="$(cd "${tmp}/vendored" && python3 "${vend}/init/scripts/init.py" --repo-path . 2>&1)"
grep -q "are enabled but no skill" <<<"${out}" \
    && fail "a satisfied section was reported as empty (false positive): ${out}"
echo "PASS: a satisfied section draws no warning"

echo "PASS: init_shadow_sections_test — all gates passed"
exit 0
