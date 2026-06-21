#!/usr/bin/env bash
# open_task_pr_test.sh — integration test for open_task_pr.sh (per-task PRs).
# Against a bare temp remote (no `gh` backend): asserts the helper cuts the
# feature branch off the host DEFAULT branch, writes a Conventional Commit with
# the dynamic Co-Authored-By trailer, pushes the branch, and reports branch:<name>.
# Also verifies the ARSENAL_SURFACE guard: git add -A must be refused when
# ARSENAL_SURFACE is unset or not 'worktree'.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="${SCRIPT_DIR}/../skills/init/assets/bin/open_task_pr.sh"

if [[ ! -f "${HELPER}" ]]; then
    echo "SKIP: open_task_pr.sh not found at ${HELPER}" >&2; exit 0
fi

# A real `gh` in PATH would try to hit GitHub; this test exercises the
# push-only (no-backend) path, so skip if gh is installed.
if command -v gh >/dev/null 2>&1; then
    echo "SKIP: gh present — this test exercises the no-PR-backend path" >&2; exit 0
fi

tmpremote=$(mktemp -d)
tmpseed=$(mktemp -d)
tmpwork=$(mktemp -d)
cleanup() { rm -rf "${tmpremote}" "${tmpseed}" "${tmpwork}"; }
trap cleanup EXIT

git init -q --bare "${tmpremote}"
git -C "${tmpremote}" symbolic-ref HEAD refs/heads/main

# Seed main with a base commit.
cd "${tmpseed}"
git init -q -b main
git config user.email "test@arsenal.example"
git config user.name "Arsenal Test"
git remote add origin "${tmpremote}"
echo "base" > base.txt
git add base.txt
git commit -q -m "chore: base"
git push -q -u origin main

# Worker clones (sets origin/HEAD + origin/main) and makes an uncommitted change.
git clone -q "${tmpremote}" "${tmpwork}"
cd "${tmpwork}"
git config user.email "test@arsenal.example"
git config user.name "Arsenal Test"
main_sha=$(git rev-parse origin/main)
echo "feature" > feature.txt

# Gate 0a: guard refuses when ARSENAL_SURFACE is unset.
if err=$(ARSENAL_SURFACE="" ARSENAL_COAUTHOR="" bash "${HELPER}" lo-guard-unset "Guard test" 2>&1); then
    echo "FAIL: expected non-zero exit when ARSENAL_SURFACE unset, got exit 0 with output: ${err}" >&2; exit 1
fi
if ! echo "${err}" | grep -q "git add -A refused on shared checkout"; then
    echo "FAIL: expected 'git add -A refused on shared checkout' in stderr, got: ${err}" >&2; exit 1
fi
echo "PASS: guard refuses git add -A when ARSENAL_SURFACE is unset"

# Gate 0b: guard refuses when ARSENAL_SURFACE is 'shared' (non-worktree).
if err=$(ARSENAL_SURFACE="shared" ARSENAL_COAUTHOR="" bash "${HELPER}" lo-guard-shared "Guard test" 2>&1); then
    echo "FAIL: expected non-zero exit when ARSENAL_SURFACE=shared, got exit 0 with output: ${err}" >&2; exit 1
fi
if ! echo "${err}" | grep -q "git add -A refused on shared checkout"; then
    echo "FAIL: expected 'git add -A refused on shared checkout' in stderr, got: ${err}" >&2; exit 1
fi
echo "PASS: guard refuses git add -A when ARSENAL_SURFACE=shared"

OUT=$(ARSENAL_SURFACE="worktree" ARSENAL_COAUTHOR="Test Bot <noreply@anthropic.com>" \
      bash "${HELPER}" lo-x001 "Add feature thing")

EXPECT_BRANCH="arsenal/lo-x001-add-feature-thing"

# Gate 1: stdout reports the pushed branch (no PR backend).
if [[ "${OUT}" != "branch:${EXPECT_BRANCH}" ]]; then
    echo "FAIL: expected 'branch:${EXPECT_BRANCH}' on stdout, got '${OUT}'" >&2; exit 1
fi
echo "PASS: reports branch:<name> when no PR backend exists"

# Gate 2: HEAD is the feature branch.
cur=$(git rev-parse --abbrev-ref HEAD)
if [[ "${cur}" != "${EXPECT_BRANCH}" ]]; then
    echo "FAIL: expected to be on ${EXPECT_BRANCH}, on ${cur}" >&2; exit 1
fi
echo "PASS: feature branch checked out"

# Gate 3: branch was cut off the default branch (commit parent == main tip).
parent=$(git rev-parse 'HEAD^')
if [[ "${parent}" != "${main_sha}" ]]; then
    echo "FAIL: branch not cut off main (parent ${parent} != main ${main_sha})" >&2; exit 1
fi
echo "PASS: branch cut off the host default branch"

# Gate 4: Conventional Commit subject + dynamic Co-Authored-By trailer.
subj=$(git log -1 --format=%s)
if [[ "${subj}" != "feat: Add feature thing" ]]; then
    echo "FAIL: expected Conventional subject 'feat: Add feature thing', got '${subj}'" >&2; exit 1
fi
if ! git log -1 --format=%b | grep -q "Co-Authored-By: Test Bot <noreply@anthropic.com>"; then
    echo "FAIL: Co-Authored-By trailer missing" >&2; exit 1
fi
echo "PASS: Conventional Commit message + Co-Authored-By trailer"

# Gate 5: the branch landed on the remote.
if ! git ls-remote --exit-code --heads origin "${EXPECT_BRANCH}" >/dev/null 2>&1; then
    echo "FAIL: ${EXPECT_BRANCH} was not pushed to the remote" >&2; exit 1
fi
echo "PASS: feature branch pushed to remote"

echo "PASS: open_task_pr_test — all gates passed"
exit 0
