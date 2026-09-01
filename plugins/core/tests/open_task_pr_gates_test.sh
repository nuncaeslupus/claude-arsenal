#!/usr/bin/env bash
# open_task_pr_gates_test.sh — the PR helper refuses over a red repo.
#
# worker.md step 4 asked a worker to run the host lint gate and the payload gate
# and to open no PR if either failed, and AGENTS.md stated the payload gate was
# "a hard precondition" because this script re-runs it. Neither ran anything:
# both were instructions with no data path behind them, which this project
# already names as the thing that makes a step not happen. A worker that forgot
# step 4 — or ran only the `make lint` the prose gives as its example, in a repo
# whose real gate is five commands — opened a perfectly valid PR over a red repo.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${SCRIPT_DIR}/../skills/init/assets/bin"
HELPER="${BIN}/open_task_pr.sh"
[[ -f "${HELPER}" ]] || { echo "SKIP: open_task_pr.sh not found" >&2; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

REPO="${tmp}/repo"
mkdir -p "${REPO}/arsenal/tasks"
cd "${REPO}"
git init -q -b main .
git config user.email t@e.x; git config user.name T; git config commit.gpgsign false
git commit -q --allow-empty -m init
git remote add origin https://github.com/o/r.git

write_task() {  # $1 = id, $2 = gate command
    cat > "arsenal/tasks/$1.md" <<EOF
---
id: $1
title: "Gate fixture"
priority: 1
---

## Acceptance gate
\`\`\`bash
$2
\`\`\`
EOF
}

# The helper needs an uncommitted change to have something to open a PR for.
touch work.txt

# --- 1: a failing payload gate opens no PR ---
write_task t-gate-red "exit 7"
out=$(ARSENAL_COAUTHOR="" bash "${HELPER}" t-gate-red "Red gate" 2>&1); rc=$?
[[ ${rc} -ne 0 ]] || fail "a failing payload gate must stop the PR"
grep -q "no PR opened" <<<"${out}" || fail "the refusal should say no PR was opened: ${out}"
git rev-parse --verify --quiet "arsenal/t-gate-red" >/dev/null 2>&1 \
    && fail "no branch should exist after a refused gate"

# --- 2: a failing HOST gate opens no PR, and is named ---
#     This is the half that was prose only. The consumer whose real gate is
#     `make lint test evidence verify-subtree verify-gates` had four of five
#     enforced by nobody.
write_task t-gate-host "true"
mkdir -p arsenal
printf 'host-gate = "exit 3"\n' > arsenal/config.toml
out=$(ARSENAL_COAUTHOR="" bash "${HELPER}" t-gate-host "Host gate" 2>&1); rc=$?
[[ ${rc} -ne 0 ]] || fail "a failing host gate must stop the PR"
grep -q "host gate failed" <<<"${out}" || fail "the refusal should name the host gate: ${out}"

# --- 3: no host-gate configured is not a failure ---
#     A repo that declares none must be unaffected; the default is empty.
printf 'merge-policy = "after-ci"\n' > arsenal/config.toml
out=$(ARSENAL_COAUTHOR="" bash "${HELPER}" t-gate-host "No host gate" 2>&1); rc=$?
grep -q "host gate failed" <<<"${out}" && fail "an absent host-gate must not fail: ${out}"

# --- 4: the gate runs BEFORE git is touched ---
#     Refusing after a branch was cut would leave the worker's tree moved.
write_task t-gate-order "exit 1"
before="$(git rev-parse HEAD)"
ARSENAL_COAUTHOR="" bash "${HELPER}" t-gate-order "Order" >/dev/null 2>&1
[[ "$(git rev-parse HEAD)" == "${before}" ]] || fail "a refused gate must not move HEAD"
[[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || fail "a refused gate must not switch branches"

# --- 5: an unmeasured/could-not-run gate (exit 3) also refuses ---
#     Exit 3 means nothing was verified, which is not a pass.
write_task t-gate-127 "definitely-not-a-real-command-xyz"
out=$(ARSENAL_COAUTHOR="" bash "${HELPER}" t-gate-127 "Could not run" 2>&1); rc=$?
[[ ${rc} -ne 0 ]] || fail "a gate that could not run must not open a PR"
grep -q "nothing was verified" <<<"${out}" \
    || fail "exit 3 should be reported as nothing verified, not as a plain failure: ${out}"

# --- 6: there is no way to skip the gates ---
#     An escape hatch would be reached for exactly when the repo is red, which
#     is the case the refusal exists for.
out=$(ARSENAL_SKIP_GATES=1 ARSENAL_COAUTHOR="" bash "${HELPER}" t-gate-red "Try to skip" 2>&1); rc=$?
[[ ${rc} -ne 0 ]] || fail "no environment variable may skip a failing gate"
grep -q "no PR opened" <<<"${out}" || fail "a skip attempt must still be refused: ${out}"
grep -rq "ARSENAL_SKIP_GATES" "${HELPER}" && fail "the helper must carry no skip flag at all"

# --- 7: gate output never reaches stdout ---
#     This script's stdout is a contract — callers parse `branch:…` and the PR
#     URL out of it, and a `gate: passed` line in front of that breaks them.
write_task t-gate-out "true"
printf 'merge-policy = "after-ci"\n' > arsenal/config.toml
sout=$(ARSENAL_COAUTHOR="" bash "${HELPER}" t-gate-out "Clean stdout" 2>/dev/null || true)
grep -q "^gate:" <<<"${sout}" && fail "gate chatter must not appear on stdout: ${sout}"

# --- 8: a broken config refuses, rather than reading as "no gate declared" ---
#     Suppressing the config error would move the silent skip one layer out:
#     enforcement would quietly stop for a repo that declares a gate.
write_task t-gate-cfg "true"
printf 'merge-policy = "not-a-real-policy"\n' > arsenal/config.toml
out=$(ARSENAL_COAUTHOR="" bash "${HELPER}" t-gate-cfg "Broken config" 2>&1); rc=$?
[[ ${rc} -ne 0 ]] || fail "an unreadable config must not silently skip the host gate"
#     Asserted on the refusal and the underlying error rather than on which key
#     names it: arsenal_config.py validates the whole file on any read, so the
#     key that surfaces a bad value is whichever the helper reads first — and
#     that order is a real design decision (the review check moved ahead of both
#     gates so a gate's own artifacts cannot invalidate the review receipt).
#     Pinning the message to one key made this test fail for a reordering that
#     changed nothing it is here to protect.
grep -q "could not read" <<<"${out}" || fail "the refusal should say the config could not be read: ${out}"
grep -q "not-a-real-policy" <<<"${out}" \
    || fail "the refusal should carry the underlying config error, not just a generic failure: ${out}"
printf 'merge-policy = "after-ci"\n' > arsenal/config.toml

# --- 9: the config is found from a subdirectory ---
#     arsenal_config.py resolves the config relative to --repo-root, defaulting
#     to the cwd; this script is routinely run from a worktree or subdirectory.
mkdir -p sub/dir
printf 'host-gate = "exit 4"\n' > arsenal/config.toml
out=$(cd sub/dir && ARSENAL_COAUTHOR="" bash "${HELPER}" t-gate-cfg "From subdir" 2>&1); rc=$?
grep -q "host gate failed" <<<"${out}" \
    || fail "the host gate must be found when run from a subdirectory: ${out}"
printf 'merge-policy = "after-ci"\n' > arsenal/config.toml

# --- 9b: ...and it RUNS where it was read from ---
#     The read is anchored to the git root and the run was not, so a gate
#     written the way gates are written — `make lint`, `bash tests/foo.sh` —
#     was executed in the subdirectory instead, and a green repo was refused a
#     PR with `host gate failed (make lint)`.
mkdir -p sub/dir
: > root-marker
# A real task with a passing gate, so the run is not stopped by something else
# on its way past the two gates — the point is that BOTH clear from a
# subdirectory, and the task gate reads `${ARSENAL_HOME}/tasks/…`, itself a
# root-relative path.
write_task t-gate-cwd "test -f root-marker"
printf 'host-gate = "test -f root-marker"\n' > arsenal/config.toml
out=$(cd sub/dir && ARSENAL_COAUTHOR="" bash "${HELPER}" t-gate-cwd "Root-relative gate" 2>&1); rc=$?
grep -q "host gate failed" <<<"${out}" \
    && fail "a root-relative host gate must run at the root, not in the cwd: ${out}"
grep -q "gate: passed" <<<"${out}" \
    || fail "the task gate must also run at the root: ${out}"
# It gets past both gates and on to the work — the only thing that stops it here
# is the absent PR backend, which is not what this case is about.
grep -qE "gate failed|could not read|could not run" <<<"${out}" \
    && fail "a gate stopped a run that both gates should have cleared: ${out}"
rm -f root-marker arsenal/tasks/t-gate-cwd.md
printf 'merge-policy = "after-ci"\n' > arsenal/config.toml

# --- 10: the gate certifies the tree that is actually committed (#220) ---
#     The host gate ran, and THEN the task file was archived into _history/ —
#     so any host measurement over the repo's own files (a file count, a
#     coverage denominator) was stale by exactly that file in every PR this
#     script opened, and the host's next run failed on a branch whose gate had
#     just passed. The gate now re-runs over the archived tree; a refusal there
#     must leave the task file where it started.
# The earlier cases all refuse before git is touched; this one has to get as
# far as cutting a branch, which needs a default ref to branch off.
git update-ref refs/remotes/origin/main HEAD
write_task t-gate-archive "true"
# Committed, then edited without staging — the state a worker's tree is actually
# in. It is also what separates a real index restore from `git add -A`: the
# latter would turn these unstaged edits into staged ones on the way out.
git add arsenal/tasks/t-gate-archive.md && git commit -q -m "file the task"
printf '\n<!-- an unstaged edit the worker has not committed -->\n' >> arsenal/tasks/t-gate-archive.md
git update-ref refs/remotes/origin/main HEAD
printf 'host-gate = "test ! -e arsenal/tasks/_history"\n' > arsenal/config.toml
before_status="$(git status --porcelain)"
out=$(ARSENAL_TASK_ISSUE=42 ARSENAL_ALLOW_SHARED_ADD=1 ARSENAL_COAUTHOR="" bash "${HELPER}" t-gate-archive "Archived tree" 2>&1); rc=$?
[[ ${rc} -ne 0 ]] || fail "a host gate that fails over the archived tree must stop the PR"
grep -q "re-running host gate" <<<"${out}" \
    || fail "the host gate should re-run once the archive is in the tree: ${out}"
[[ -f "arsenal/tasks/t-gate-archive.md" ]] \
    || fail "the refused run left the task file archived: it must be restored"
[[ -e "arsenal/tasks/_history/t-gate-archive.md" ]] \
    && fail "the archived copy survived a refusal"
# The whole point of the undo: the tree AND the index come out exactly as they
# went in. `git add -A` as a rollback would turn this untracked task file into a
# staged addition the worker never made.
after_status="$(git status --porcelain)"
[[ "${after_status}" == "${before_status}" ]] \
    || fail "the refused run changed the index/worktree state:
before: ${before_status}
after:  ${after_status}"
printf 'merge-policy = "after-ci"\n' > arsenal/config.toml
git checkout -q main 2>/dev/null || true
echo "PASS: the host gate re-runs over the archived tree, and a refusal restores it"

# --- 11: an archive that cannot be completed leaves the task file live ---
#     `git mv` succeeds, then the stamp finds no front matter to write into and
#     the re-check refuses. That refusal returned without undoing the move, so
#     the run reported failure with the task file sitting in `_history/` —
#     where `task_select.py` reads it as finished work. The task then leaves the
#     queue with nothing merged, which is what the backup exists to prevent.
git checkout -q main 2>/dev/null || true
cat > arsenal/tasks/t-no-front.md <<'MD'
# A task file with no front matter for the stamp to write into

## Acceptance gate
```bash
true
```
MD
git add arsenal/tasks/t-no-front.md && git commit -q -m "file the unstampable task"
git update-ref refs/remotes/origin/main HEAD
before_status="$(git status --porcelain)"
# The bytes and the index entry, not just the porcelain summary: a rollback that
# restored a re-rendered file, or staged what was untracked, reads identical in
# `git status` and is not the tree the worker had.
before_blob="$(git hash-object arsenal/tasks/t-no-front.md)"
before_index="$(git ls-files -s -- arsenal/tasks/t-no-front.md)"
out=$(ARSENAL_TASK_ISSUE=42 ARSENAL_ALLOW_SHARED_ADD=1 ARSENAL_COAUTHOR="" bash "${HELPER}" t-no-front "Unstampable" 2>&1); rc=$?
[[ ${rc} -ne 0 ]] || fail "an archive that cannot be stamped must stop the PR"
grep -q "not a complete archive" <<<"${out}" || fail "the refusal should name what it could not verify: ${out}"
[[ -f "arsenal/tasks/t-no-front.md" ]] \
    || fail "the refused run left the task file archived: it must be restored"
[[ -e "arsenal/tasks/_history/t-no-front.md" ]] \
    && fail "the archived copy survived a refusal"
grep -q "has been restored" <<<"${out}" || fail "the refusal should say the file was put back: ${out}"
[[ "$(git hash-object arsenal/tasks/t-no-front.md)" == "${before_blob}" ]] \
    || fail "the restored task file is not byte-identical to the one that went in"
[[ "$(git ls-files -s -- arsenal/tasks/t-no-front.md)" == "${before_index}" ]] \
    || fail "the index entry for the task file was not restored as it was"
after_status="$(git status --porcelain)"
[[ "${after_status}" == "${before_status}" ]] \
    || fail "the refused run changed the index/worktree state:
before: ${before_status}
after:  ${after_status}"
git checkout -q main 2>/dev/null || true
echo "PASS: an archive that cannot be completed is undone, not left half-done"

# --- 12: a commit that FAILS must not leave the task archived (#302) ---------
#     The rescue backup was deleted before `git commit` ran, so a commit that
#     failed — a hook, a git-config problem, an unresolvable identity — exited 1
#     with the task file sitting in `_history/` stamped `status: merged`, which
#     `task_select.py` reads as finished work, and with nothing left to restore
#     it from. The message named the one cause that cannot apply: `git add -A`
#     had just staged the archive move, so the diff is never empty here.
git checkout -q main 2>/dev/null || true
cat > arsenal/tasks/t-commit-fails.md <<'MD'
---
id: t-commit-fails
title: "Commit fixture"
priority: 1
---

## Acceptance gate
```bash
true
```
MD
git add arsenal/tasks/t-commit-fails.md && git commit -q -m "file the task"
git update-ref refs/remotes/origin/main HEAD
before_blob="$(git hash-object arsenal/tasks/t-commit-fails.md)"
before_status="$(git status --porcelain)"

# The realistic mechanism the issue names: a hook that refuses the commit.
mkdir -p .git/hooks
printf '#!/bin/sh
exit 1
' > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit

out=$(ARSENAL_TASK_ISSUE=43 ARSENAL_ALLOW_SHARED_ADD=1 ARSENAL_COAUTHOR="" \
    bash "${HELPER}" t-commit-fails "Commit fixture" 2>&1); rc=$?
rm -f .git/hooks/pre-commit

[[ ${rc} -ne 0 ]] || fail "a refused commit must not report success"
[[ -f "arsenal/tasks/t-commit-fails.md" ]] \
    || fail "A FAILED COMMIT LEFT THE TASK ARCHIVED — the selector reads that as done"
[[ -e "arsenal/tasks/_history/t-commit-fails.md" ]] \
    && fail "the archived copy survived a failed commit"
[[ "$(git hash-object arsenal/tasks/t-commit-fails.md)" == "${before_blob}" ]] \
    || fail "the restored task file is not byte-identical to the one that went in"
grep -qi "could not commit" <<<"${out}" || fail "the failure must say what happened: ${out}"
grep -qi "empty diff" <<<"${out}" \
    && fail "the message still blames an empty diff, which cannot be the cause here: ${out}"
git checkout -q main 2>/dev/null || true
git status --porcelain >/dev/null
echo "PASS: a commit that fails restores the task file instead of stranding it"

# --- 9: outside a git repository the helper refuses, and runs no gate --------
#     Every path this script handles is repo-root-relative, so it anchored the
#     run at `git rev-parse --show-toplevel || pwd`. The fallback made "there is
#     no repository" indistinguishable from success: the `cd` into the caller's
#     own cwd always works, so the host gate and the task gate ran against
#     whatever tree the caller was standing in, and the operator got a gate
#     result rather than "you are not in a repository" (#244). The sentinel is
#     the assertion that matters — a refusal that still ran the gates would have
#     satisfied the exit code alone.
norepo="${tmp}/norepo"
mkdir -p "${norepo}/arsenal/tasks"
git -C "${norepo}" rev-parse --show-toplevel >/dev/null 2>&1 \
    && fail "fixture error: ${norepo} is inside a git repository"
cat > "${norepo}/arsenal/tasks/t-loose.md" <<EOF
---
id: t-loose
title: "Loose fixture"
priority: 1
---

## Acceptance gate
\`\`\`bash
touch "${norepo}/TASK_GATE_RAN"
\`\`\`
EOF
printf 'host-gate = "touch %s/HOST_GATE_RAN"\n' "${norepo}" > "${norepo}/arsenal/config.toml"
out=$( (cd "${norepo}" && ARSENAL_COAUTHOR="" bash "${HELPER}" t-loose "Loose" 2>&1) ); rc=$?
[[ ${rc} -ne 0 ]] || fail "running outside a repository must not succeed: ${out}"
grep -qi "not inside a git repository" <<<"${out}" \
    || fail "the refusal should say there is no repository, not something else: ${out}"
[[ -e "${norepo}/HOST_GATE_RAN" ]] \
    && fail "the host gate ran from a directory that is not a repository"
[[ -e "${norepo}/TASK_GATE_RAN" ]] \
    && fail "the task gate ran from a directory that is not a repository"
cd "${REPO}"
echo "PASS: outside a repository the helper refuses before running any gate"

echo "PASS: open_task_pr_gates_test — all gates passed"
