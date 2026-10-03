#!/usr/bin/env bash
# park_task_test.sh — a parked task's uncommitted work reaches the remote and
# comes back uncommitted on a fresh clone (#482).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARK="${SCRIPT_DIR}/../skills/init/assets/bin/park_task.sh"

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
pass() { echo "PASS: $1"; }

git init -q --bare -b main "${tmp}/remote.git"
git init -q -b main "${tmp}/work"
cd "${tmp}/work"
git config user.email "test@arsenal.example"
git config user.name "Arsenal Test"
git config commit.gpgsign false
printf 'keep\n' > kept.txt
printf 'gone\n' > deleted.txt
git add -A && git commit -q -m seed
git remote add origin "${tmp}/remote.git"
git push -q origin main 2>/dev/null

out="$(bash "${PARK}" t-abc123)" || fail "a clean tree should exit 0"
[[ "${out}" == "wip: none (clean tree)" ]] || fail "a clean tree should park nothing: ${out}"
pass "a clean tree parks nothing"

printf 'edited\n' > kept.txt
rm deleted.txt
printf 'new\n' > added.txt
out="$(bash "${PARK}" t-abc123 "round cap")" || fail "park failed: ${out}"
grep -qx 'wip: arsenal/wip/t-abc123' <<<"${out}" || fail "no wip line: ${out}"
git ls-remote --exit-code "${tmp}/remote.git" refs/heads/arsenal/wip/t-abc123 >/dev/null \
    || fail "the wip branch did not reach the remote"
[[ -z "$(git diff --cached --name-only)" ]] || fail "parking touched the index"
[[ "$(cat kept.txt)" == "edited" && -f added.txt && ! -e deleted.txt ]] \
    || fail "parking touched the working tree"
pass "the uncommitted work is pushed and the tree is left as it was"

# A fresh clone — the next container — restores it uncommitted.
git clone -q "${tmp}/remote.git" "${tmp}/next"
cd "${tmp}/next"
resume="$(sed -n 's/^resume: //p' <<<"${out}")"
bash -c "${resume}" >/dev/null 2>&1 || fail "the resume command failed: ${resume}"
[[ "$(cat kept.txt)" == "edited" ]] || fail "the edit did not come back"
[[ -f added.txt ]] || fail "the new file did not come back"
[[ ! -e deleted.txt ]] || fail "the deletion did not come back"
[[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || fail "resume moved HEAD"
[[ -z "$(git diff --cached --name-only)" ]] || fail "resume staged the work; open_task_pr.sh wants it uncommitted"
pass "a fresh clone restores the work uncommitted, deletions included"

bash "${PARK}" "bad..id" >/dev/null 2>&1 && fail "an id git cannot use as a branch must be refused"
pass "an unusable task id is refused"

echo "PASS: park_task_test — all gates passed"
