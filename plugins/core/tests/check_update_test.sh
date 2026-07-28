#!/usr/bin/env bash
# check_update_test.sh — regression test for the "already current" false
# negative reported by a downstream consumer.
#
# A repo re-vendored the bundle, was told it was current, and ran a whole
# session on a stale copy. Two independent conditions both exited 0 without a
# word: no `arsenal` remote was configured (the bundle had been hand-copied,
# so there was nothing to compare against), and the newer upstream release was
# UNTAGGED (its tag workflow never ran during an Actions outage), so the
# tag-gated check could not see it either. Silence read as "up to date".
#
# Gates:
#   - no remote                         → says the check is inert, exit 0;
#   - newest tag == installed, but the default branch ships a newer
#     .bundle-version                   → names that untagged version;
#   - newest tag < installed            → refuses to downgrade (the old
#     `installed != latest` test would have subtree-merged backwards);
#   - genuinely current                 → says so rather than staying silent;
#   - newest tag > installed            → still takes the update path.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK="${SCRIPT_DIR}/../skills/init/assets/bin/check_update.sh"

[[ -f "${CHECK}" ]] || { echo "SKIP: check_update.sh not found at ${CHECK}" >&2; exit 0; }

fail() { echo "FAIL: $1" >&2; exit 1; }

tmp=$(mktemp -d)
tmp="$(cd "${tmp}" && pwd -P)"
cleanup() { cd /; rm -rf "${tmp}"; }
trap cleanup EXIT

UPSTREAM_VERSION_PATH="plugins/core/skills/init/assets/.bundle-version"
export ARSENAL_UPSTREAM_VERSION_PATH="${UPSTREAM_VERSION_PATH}"

# --- A stand-in marketplace repo, tagged v0.20.5, whose main later bumps to
#     0.21.0 WITHOUT a tag — exactly the upstream state that broke the consumer.
market="${tmp}/marketplace"
mkdir -p "${market}/$(dirname "${UPSTREAM_VERSION_PATH}")"
git init -q -b main "${market}"
git -C "${market}" config user.email "test@arsenal.example"
git -C "${market}" config user.name "Arsenal Test"
echo "0.20.5" > "${market}/${UPSTREAM_VERSION_PATH}"
git -C "${market}" add -A
git -C "${market}" commit -q -m "chore: release 0.20.5"
git -C "${market}" tag -a v0.20.5 -m "Release v0.20.5"

# The consumer: a repo with the bundle vendored at claude-arsenal/.
consumer="${tmp}/consumer"
mkdir -p "${consumer}/claude-arsenal"
git init -q -b main "${consumer}"
git -C "${consumer}" config user.email "test@arsenal.example"
git -C "${consumer}" config user.name "Arsenal Test"
echo "0.20.5" > "${consumer}/claude-arsenal/.bundle-version"
git -C "${consumer}" add -A
git -C "${consumer}" commit -q -m "chore: vendor bundle"

run_check() { (cd "${consumer}" && bash "${CHECK}" 2>"${tmp}/err.log"); }

# --- Gate 1: no `arsenal` remote — the check is inert and must say so. -------
out="$(run_check)" || fail "check_update.sh exited non-zero with no remote"
grep -qi "INERT" "${tmp}/err.log" \
    || fail "no-remote case stayed silent; stderr was: $(cat "${tmp}/err.log")"
grep -q "git remote add" "${tmp}/err.log" \
    || fail "no-remote case did not say how to fix it"
echo "PASS: a missing 'arsenal' remote is reported, not silently treated as current"

git -C "${consumer}" remote add arsenal "${market}"

# --- Gate 2: tag == installed and the branch is at that tag → genuinely
#     current, and it says so instead of exiting mute. ------------------------
out="$(run_check)" || fail "check_update.sh exited non-zero when current"
[[ "${out}" == *"current with the newest tag"* ]] \
    || fail "genuinely-current case did not report being current, stdout: '${out}'"
echo "PASS: a genuinely current bundle reports that it is current"

# --- Gate 3: main bumps to 0.21.0 but is NEVER tagged (the Actions outage).
#     The tag-gated path sees v0.20.5 == installed; the probe must still find
#     and name the untagged 0.21.0. -----------------------------------------
echo "0.21.0" > "${market}/${UPSTREAM_VERSION_PATH}"
git -C "${market}" add -A
git -C "${market}" commit -q -m "fix: ship 0.21.0 without a tag"

out="$(run_check)" || fail "check_update.sh exited non-zero on the untagged-upstream case"
grep -q "UNTAGGED UPSTREAM RELEASE" "${tmp}/err.log" \
    || fail "untagged upstream 0.21.0 was not reported; stderr: $(cat "${tmp}/err.log")"
grep -q "0\.21\.0" "${tmp}/err.log" \
    || fail "the warning does not name the newer version 0.21.0"
grep -q "make tag" "${tmp}/err.log" \
    || fail "the warning does not say how to fix it upstream"
echo "PASS: an untagged newer upstream release is detected and named"

# --- Gate 4: a consumer AHEAD of the newest tag (hand-vendored 0.21.0) must
#     never be downgraded. The old `installed != latest` test would have
#     subtree-merged v0.20.5 backwards over it. ------------------------------
echo "0.21.0" > "${consumer}/claude-arsenal/.bundle-version"
git -C "${consumer}" add -A
git -C "${consumer}" commit -q -m "chore: hand-vendor 0.21.0"

out="$(run_check)" || fail "check_update.sh exited non-zero when ahead of the newest tag"
[[ "${out}" != *"pulling update"* ]] \
    || fail "check_update.sh tried to DOWNGRADE to the older tag: '${out}'"
grep -q "not downgrading" "${tmp}/err.log" \
    || fail "ahead-of-tag case did not explain itself; stderr: $(cat "${tmp}/err.log")"
echo "PASS: a bundle ahead of the newest tag is never downgraded"

# --- Gate 5: a genuinely newer TAG still takes the update path. --------------
git -C "${market}" tag -a v0.22.0 -m "Release v0.22.0"
out="$(run_check)" || fail "check_update.sh exited non-zero on a real update"
[[ "${out}" == *"pulling update"* ]] \
    || fail "a newer tag (v0.22.0) did not trigger the update path, stdout: '${out}'"
echo "PASS: a strictly newer tag still triggers the update path"

echo "PASS: check_update_test — all gates passed"
exit 0
