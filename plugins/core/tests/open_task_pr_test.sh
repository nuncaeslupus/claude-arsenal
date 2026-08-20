#!/usr/bin/env bash
# open_task_pr_test.sh — integration test for open_task_pr.sh (per-task PRs).
# Against a bare temp remote (no `gh` backend): asserts the helper cuts the
# feature branch off the host DEFAULT branch, writes a Conventional Commit with
# the dynamic Co-Authored-By trailer, pushes the branch, and reports branch:<name>.
# Also verifies the shared-checkout guard (#130 item 4): git add -A is refused
# on a plain (non-worktree) checkout, is NOT unlocked by the caller asserting
# ARSENAL_SURFACE=worktree about itself, and is allowed either by real worktree
# isolation, by the orchestrator's recorded serialized in-place mode, or by the
# explicit ARSENAL_ALLOW_SHARED_ADD operator override.
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

# Gate 0a: guard refuses on a plain checkout with nothing set.
if err=$(ARSENAL_COAUTHOR="" bash "${HELPER}" lo-guard-unset "Guard test" 2>&1); then
    echo "FAIL: expected non-zero exit on a shared checkout, got exit 0 with output: ${err}" >&2; exit 1
fi
if ! echo "${err}" | grep -q "git add -A refused on shared checkout"; then
    echo "FAIL: expected 'git add -A refused on shared checkout' in stderr, got: ${err}" >&2; exit 1
fi
echo "PASS: guard refuses git add -A on a shared checkout"

# Gate 0b (#130 item 4): the caller certifying its own isolation must NOT
# unlock the guard — that is the self-certification hole this closes.
if err=$(ARSENAL_SURFACE="worktree" ARSENAL_COAUTHOR="" bash "${HELPER}" lo-guard-selfcert "Guard test" 2>&1); then
    echo "FAIL: ARSENAL_SURFACE=worktree self-certification still unlocks the guard: ${err}" >&2; exit 1
fi
if ! echo "${err}" | grep -q "git add -A refused on shared checkout"; then
    echo "FAIL: expected 'git add -A refused on shared checkout' in stderr, got: ${err}" >&2; exit 1
fi
echo "PASS: guard is not unlocked by the caller's own ARSENAL_SURFACE claim"

# Gate 0c: the orchestrator's recorded serialized in-place mode unlocks it —
# that sentinel is written by worktree_probe.sh / worker_postcheck.sh and is
# what clamps the batch to a single worker, so no concurrent worker exists.
mkdir -p "${tmpwork}/arsenal/session"
echo "unavailable" > "${tmpwork}/arsenal/session/worktree_isolation"
if ! ARSENAL_TASK_ISSUE=41 ARSENAL_COAUTHOR="" bash "${HELPER}" lo-guard-inplace "Guard inplace" >/dev/null 2>&1; then
    echo "FAIL: recorded serialized in-place mode should permit git add -A" >&2; exit 1
fi
echo "PASS: recorded serialized in-place mode permits git add -A"
# Reset the tree for the main scenario below.
git checkout -q main 2>/dev/null || git checkout -q -B main origin/main
git branch -qD arsenal/lo-guard-inplace-guard-inplace 2>/dev/null || true
rm -rf "${tmpwork}/claude-arsenal"
echo "feature" > feature.txt

# Gate 0d: with no issue handle resolvable, the helper refuses BEFORE touching
# git. A PR that merges without closing its task is the drift the whole queue
# exists to avoid, and the worker's edits must survive the refusal intact.
before_head=$(git rev-parse HEAD)
if err=$(ARSENAL_ISSUES_JSON=/nonexistent-issues.json ARSENAL_ALLOW_SHARED_ADD=1 \
         ARSENAL_COAUTHOR="" bash "${HELPER}" lo-noissue "No handle" 2>&1); then
    echo "FAIL: expected refusal when no issue handle resolves, got exit 0: ${err}" >&2; exit 1
fi
if ! echo "${err}" | grep -q "cannot resolve the issue handle"; then
    echo "FAIL: expected 'cannot resolve the issue handle' in stderr, got: ${err}" >&2; exit 1
fi
if [[ "$(git rev-parse HEAD)" != "${before_head}" ]]; then
    echo "FAIL: refusal moved HEAD — the worker's edits must be left untouched" >&2; exit 1
fi
if [[ ! -f feature.txt ]]; then
    echo "FAIL: refusal discarded the worker's uncommitted edits" >&2; exit 1
fi
echo "PASS: refuses to open a PR that could not close its task"

# Gate 0e: the issue number is resolved from the session's saved issue list, so
# the caller does not have to know it — the same list the board already fetched.
cat > "${tmpwork}/issues.json" <<'JSON'
[{"number": 77, "state": "open", "body": "`arsenal-task: lo-x001`\n\nTask defined in `arsenal/tasks/lo-x001.md`"}]
JSON

# The task file the PR is expected to archive.
mkdir -p "${tmpwork}/arsenal/tasks"
cat > "${tmpwork}/arsenal/tasks/lo-x001.md" <<'MD'
---
id: lo-x001
title: "Add feature thing"
priority: 5
---

## Acceptance gate
```bash
true
```
MD
git add arsenal/tasks/lo-x001.md
git commit -q -m "chore: seed task file"
git push -q origin main
main_sha=$(git rev-parse HEAD)
echo "feature" > feature.txt

OUT=$(ARSENAL_ISSUES_JSON="${tmpwork}/issues.json" ARSENAL_ALLOW_SHARED_ADD=1 \
      ARSENAL_COAUTHOR="Test Bot <noreply@anthropic.com>" \
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

# Gate 4b: `Closes #<issue>` is in the commit message. The PR body carries it
# too, but only the commit form survives a squash merge and fires for a stacked
# PR whose base is not the default branch.
if ! git log -1 --format=%b | grep -q "Closes #77"; then
    echo "FAIL: commit message missing 'Closes #77' — merging would not close the task" >&2; exit 1
fi
echo "PASS: commit message carries Closes #<issue>"

# Gate 4c: the task file is archived by this PR's own diff, so the queue's
# record of finished work lands exactly when the merge does.
if [[ -f arsenal/tasks/lo-x001.md ]]; then
    echo "FAIL: arsenal/tasks/lo-x001.md still live — the PR did not archive it" >&2; exit 1
fi
if [[ ! -f arsenal/tasks/_history/lo-x001.md ]]; then
    echo "FAIL: arsenal/tasks/_history/lo-x001.md missing — task file was not archived" >&2; exit 1
fi
if ! grep -q "^status: merged$" arsenal/tasks/_history/lo-x001.md; then
    echo "FAIL: archived task file does not record 'status: merged'" >&2; exit 1
fi
if ! git log -1 --name-status | grep -q "_history/lo-x001.md"; then
    echo "FAIL: the archive is not part of the PR commit" >&2; exit 1
fi
echo "PASS: task file archived to _history with status: merged, inside the PR"

# Gate 5: the branch landed on the remote.
if ! git ls-remote --exit-code --heads origin "${EXPECT_BRANCH}" >/dev/null 2>&1; then
    echo "FAIL: ${EXPECT_BRANCH} was not pushed to the remote" >&2; exit 1
fi
echo "PASS: feature branch pushed to remote"

# Gate 6: an archive that cannot complete is fatal, not silent. The PR body
# tells a reader the gate lives at the archived path, and the whole point of
# this flow is that a merge never half-completes a task.
git checkout -q main 2>/dev/null || git checkout -q -B main origin/main
git branch -qD "${EXPECT_BRANCH}" 2>/dev/null || true
cat > "${tmpwork}/issues2.json" <<'JSON'
[{"number": 78, "state": "open", "body": "`arsenal-task: lo-x002`\n\nTask defined in `arsenal/tasks/lo-x002.md`"}]
JSON
mkdir -p arsenal/tasks
printf -- '---\nid: lo-x002\ntitle: "Blocked archive"\n---\n\n## Acceptance gate\n```bash\ntrue\n```\n' \
    > arsenal/tasks/lo-x002.md
git add arsenal/tasks/lo-x002.md && git commit -q -m "chore: seed second task"
# Push it: the helper cuts its branch off the REMOTE default branch, so a task
# file that exists only locally would not be in the tree it archives from.
git push -q origin main
# A regular file where the history DIRECTORY must go: mkdir -p fails, so the
# archive cannot happen.
rm -rf arsenal/tasks/_history
: > arsenal/tasks/_history
echo "feature2" > feature2.txt
before=$(git rev-parse HEAD)
if err=$(ARSENAL_ISSUES_JSON="${tmpwork}/issues2.json" ARSENAL_ALLOW_SHARED_ADD=1 \
         ARSENAL_COAUTHOR="" bash "${HELPER}" lo-x002 "Blocked archive" 2>&1); then
    echo "FAIL: expected a failed archive to abort, got exit 0: ${err}" >&2; exit 1
fi
if ! echo "${err}" | grep -q "could not be archived"; then
    echo "FAIL: expected a 'could not be archived' refusal, got: ${err}" >&2; exit 1
fi
if git log --oneline "${before}..HEAD" 2>/dev/null | grep -q .; then
    echo "FAIL: a commit was made despite the archive failing" >&2; exit 1
fi
echo "PASS: a task file that cannot be archived aborts before committing"

echo "PASS: open_task_pr_test — all gates passed"
exit 0
