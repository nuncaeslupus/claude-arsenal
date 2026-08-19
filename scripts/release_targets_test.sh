#!/usr/bin/env bash
# release_targets_test.sh — behaviour tests for `make tag` and `make release-check`.
#
# These two decide what consumers see. `check_update.sh` in every consuming repo
# gates on the newest tag published to the remote and then fetches the exact
# commit that tag names, so a wrong answer here does not stay here: it either
# hides a release from everyone, or ships them a commit nobody meant to release.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MAKEFILE="${REPO_ROOT}/Makefile"
[[ -f "${MAKEFILE}" ]] || { echo "SKIP: ${MAKEFILE} not found" >&2; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

setup_repo() {  # $1 = version
    rm -rf "${tmp}/origin.git" "${tmp}/work"
    git init -q --bare "${tmp}/origin.git"
    git init -q -b main "${tmp}/work"
    cd "${tmp}/work"
    git config user.email "test@arsenal.example"
    git config user.name "Arsenal Test"
    git config commit.gpgsign false
    mkdir -p plugins/core/skills/init/assets
    printf '%s\n' "$1" > plugins/core/skills/init/assets/.bundle-version
    cp "${MAKEFILE}" .
    git add -A && git commit -q -m "release commit"
    git remote add origin "${tmp}/origin.git"
    git push -q origin main
}

# --- 1: an unpublished version is reported as such, and tagging publishes it ---
setup_repo 1.0.0
make release-check >/dev/null 2>&1 && fail "release-check should fail when the tag is not published"
make tag >/dev/null 2>&1 || fail "make tag should publish v1.0.0"
make release-check >/dev/null 2>&1 || fail "release-check should pass once the tag is on the remote"

published=$(git ls-remote --tags origin 'refs/tags/v1.0.0^{}' | cut -f1)
[[ "${published}" == "$(git rev-parse HEAD)" ]] \
    || fail "the published tag must point at HEAD, got ${published}"

# --- 2: re-running is a no-op decided by the REMOTE, not a local tag ---
out=$(make tag 2>&1)
grep -q "already published" <<<"${out}" || fail "a second run should be a no-op: ${out}"

# --- 3: a local-only tag must NOT be reported as published ---
#     This is the bug that made release-check useless: a push that never reached
#     the remote left a local tag, and the check believed it.
setup_repo 2.0.0
git tag -a v2.0.0 -m "local only" >/dev/null
if make release-check >/dev/null 2>&1; then
    fail "a local-only tag must not count as published — consumers cannot see it"
fi

# --- 4: a stale local tag is refused rather than published ---
#     Consumers fetch the exact commit the tag names, so pushing a tag that
#     points somewhere other than the release commit ships the wrong code.
setup_repo 3.0.0
stale=$(git rev-parse HEAD)
git tag -a v3.0.0 -m "stale" >/dev/null
echo "later work" > later.txt && git add -A && git commit -q -m "the actual release commit"
out=$(make tag 2>&1)
grep -q "points at ${stale}" <<<"${out}" || fail "should refuse a stale tag and say where it points: ${out}"
git ls-remote --exit-code --tags origin 'refs/tags/v3.0.0' >/dev/null 2>&1 \
    && fail "a stale tag must never reach the remote"

# --- 5: after removing the stale tag, HEAD is what gets published ---
git tag -d v3.0.0 >/dev/null
make tag >/dev/null 2>&1 || fail "make tag should publish after the stale tag is removed"
published=$(git ls-remote --tags origin 'refs/tags/v3.0.0^{}' | cut -f1)
[[ "${published}" == "$(git rev-parse HEAD)" ]] || fail "must publish HEAD, not the stale commit"

# --- 6: an unreachable remote is NOT reported as "no tag" ---
#     Otherwise a network blip tells the operator to re-tag a release that is
#     already published, which is the opposite of what they should do.
setup_repo 4.0.0
git remote set-url origin "${tmp}/nonexistent-remote.git"
out=$(make release-check 2>&1)
grep -q "could not query origin" <<<"${out}" \
    || fail "an unreachable remote must be distinguished from a missing tag: ${out}"
grep -q "NO TAG" <<<"${out}" && fail "an unreachable remote must not be reported as a missing tag"
out=$(make tag 2>&1)
grep -q "refusing to guess" <<<"${out}" || fail "make tag must refuse when it cannot query the remote: ${out}"

echo "PASS: release_targets_test — all gates passed"
