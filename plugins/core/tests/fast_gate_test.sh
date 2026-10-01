#!/usr/bin/env bash
# fast_gate_test.sh — bin/fast_gate.sh picks the gate level a step needs (#463).
#
# What must hold:
#   * the default level runs preflight-gate, scoped: it sees the merge-base and
#     exactly the files changed since it (committed, staged, untracked; not
#     deleted ones)
#   * --full runs host-gate
#   * no preflight-gate falls back to host-gate, and says so — never weaker
#   * neither declared is `gate: none`, exit 0; a failing gate's exit passes up
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAST="${SCRIPT_DIR}/../skills/init/assets/bin/fast_gate.sh"
[[ -f "${FAST}" ]] || { echo "SKIP: fast_gate.sh not found" >&2; exit 0; }

fail() { echo "FAIL: $1" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
repo="${tmp}/repo"
mkdir -p "${repo}/arsenal"
(
    cd "${repo}" && git init -q . && git config user.email t@example.com && git config user.name t
    printf 'a\n' > kept.txt; printf 'b\n' > gone.txt
    git add -A && git commit -qm base && git branch -q base
    printf 'a2\n' > kept.txt; git rm -q gone.txt; printf 'n\n' > new.txt
    git add -A && git commit -qm change
    printf 'u\n' > untracked.txt
) || fail "fixture"

cfg() { printf '%s\n' "$@" > "${repo}/arsenal/config.toml"; }
run() { (cd "${repo}" && bash "${FAST}" --base base "$@" 2>&1); }

cfg 'host-gate = "echo FULL"' \
    'preflight-gate = "echo FAST; printf \"%s\\n\" \"$ARSENAL_CHANGED_FILES\" > changed.out; echo \"$ARSENAL_GATE_BASE\" > base.out"'
out=$(run) || fail "fast level should pass: ${out}"
[[ "${out}" == *FAST* && "${out}" != *FULL* ]] || fail "default must run preflight-gate only: ${out}"
[[ "${out}" == *"gate: preflight-gate passed"* ]] || fail "no verdict line: ${out}"
got=$(tr '\n' ' ' < "${repo}/changed.out")
[[ "${got}" == "arsenal/config.toml kept.txt new.txt untracked.txt " ]] || fail "changed files wrong: '${got}'"
[[ "$(cat "${repo}/base.out")" == "$(git -C "${repo}" rev-parse base)" ]] || fail "base not exported"
echo "PASS: default runs preflight-gate over the changed files only"

out=$(run --full) || fail "--full should pass: ${out}"
[[ "${out}" == *FULL* && "${out}" != *FAST* ]] || fail "--full must run host-gate: ${out}"
echo "PASS: --full runs host-gate"

cfg 'host-gate = "echo FULL"'
out=$(run) || fail "fallback should pass"
[[ "${out}" == *FULL* && "${out}" == *"no preflight-gate declared"* ]] || fail "fallback not announced: ${out}"
echo "PASS: no preflight-gate falls back to host-gate, out loud"

cfg 'host-gate = "none"'
out=$(run) || fail "no gate must exit 0"
[[ "${out}" == *"gate: none"* ]] || fail "no gate must say so: ${out}"
cfg 'preflight-gate = "exit 7"'
run >/dev/null; rc=$?
(( rc == 7 )) || fail "a failing gate's exit must pass up, got ${rc}"
echo "PASS: nothing declared is gate: none; a failure keeps its exit"

# --- gate receipt: the full gate runs at most once per tree ------------------
counter="${tmp}/counter"
cfg "host-gate = \"echo x >> ${counter}\""
commit_all() { (cd "${repo}" && git add -A && git commit -qm "$1") || fail "commit: $1"; }
commit_all "receipt fixture"
runs() { [[ -f "${counter}" ]] && grep -c . "${counter}" || echo 0; }

test_full_gate_twice_same_tree_runs_once() {
    : > "${counter}"
    out=$(run --full) || fail "first --full should pass: ${out}"
    [[ "$(runs)" == 1 ]] || fail "first --full should run the gate once, ran $(runs)"
    out=$(run --full) || fail "second --full should pass: ${out}"
    [[ "${out}" == *"host-gate passed on this tree at "*" — reused"* ]] \
        || fail "second --full on the same clean tree should say reused: ${out}"
    [[ "$(runs)" == 1 ]] || fail "second --full re-ran the gate (counter $(runs))"
    [[ -z "$(git -C "${repo}" status --porcelain)" ]] || fail "the receipt dirtied the tree"
    echo "PASS: test_full_gate_twice_same_tree_runs_once"
}

test_receipt_ignored_after_edit() {
    : > "${counter}"
    printf 'edit\n' >> "${repo}/kept.txt"
    out=$(run --full) || fail "--full on a dirty tree should pass: ${out}"
    [[ "${out}" != *reused* && "$(runs)" == 1 ]] || fail "a dirty tree must run the gate: ${out}"
    commit_all "edit"
    out=$(run --full) || fail "--full after the edit should pass: ${out}"
    [[ "${out}" != *reused* && "$(runs)" == 2 ]] || fail "a new tree must run the gate: ${out}"
    cfg "host-gate = \"echo y >> ${counter}\""; commit_all "other gate"
    out=$(run --full) || fail "gate change, first run: ${out}"
    out=$(run --full) || fail "gate change, second run: ${out}"
    [[ "${out}" == *reused* && "$(runs)" == 3 ]] || fail "a changed gate command must run once, then reuse: ${out}"
    echo "PASS: test_receipt_ignored_after_edit"
}

test_full_gate_twice_same_tree_runs_once
test_receipt_ignored_after_edit

echo "PASS: fast_gate_test"
