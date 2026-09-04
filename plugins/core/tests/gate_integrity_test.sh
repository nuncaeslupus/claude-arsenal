#!/usr/bin/env bash
# gate_integrity_test.sh — three ways a gate stopped being a gate.
#
#   * gate_evidence.py crashed on an out-of-range number, and the traceback's
#     exit 1 is gate_run.sh's "the assertion FAILED" — so an unusable gate was
#     scored as a failed one and exit 2 never fired (#346).
#   * gate_run.sh discarded a branch's edited gate command in silence, and its
#     one diagnostic said the file was "not on disk" when it was (#349).
#   * arsenal_migrate.py wrote a task file with no gate when a payload was
#     missing or escaped the queue dir, then exited 0 (#346).
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="${SCRIPT_DIR}/../skills/init/assets"
EVIDENCE="${ASSETS}/scripts/gate_evidence.py"
GATE_RUN="${ASSETS}/bin/gate_run.sh"
MIGRATE="${ASSETS}/scripts/arsenal_migrate.py"
INIT="${SCRIPT_DIR}/../skills/init/scripts/init.py"

for f in "${EVIDENCE}" "${GATE_RUN}" "${MIGRATE}"; do
    [[ -f "$f" ]] || { echo "SKIP: $f not found" >&2; exit 0; }
done

fail() { echo "FAIL: $*" >&2; exit 1; }

tmp=$(mktemp -d)
cleanup() { cd /; rm -rf "${tmp}"; }
trap cleanup EXIT

# --- gate_evidence: a number a float cannot hold ------------------------------
_task_with_gate() {  # $1 = evidence path
    printf -- '---\nid: t-of\ntitle: "x"\n---\n\n## Acceptance gate\n\n'
    printf '```gate\n'
    printf 'sharpe >= 1.0\nevidence: %s\nkey: metrics.sharpe\n' "$1"
    printf '```\n'
}
ev="${tmp}/ev.json"
_task_with_gate "${ev}" > "${tmp}/t-of.md"

python3 -c "
import pathlib, sys
pathlib.Path(sys.argv[1]).write_text('{\"metrics\": {\"sharpe\": ' + '9'*401 + '}}')
" "${ev}"
out="$(python3 "${EVIDENCE}" "${tmp}/t-of.md" 2>&1)"; rc=$?
[[ "${rc}" -eq 2 ]] || fail "an out-of-range evidence value exited ${rc}, expected 2 (unusable)"
grep -q "Traceback" <<<"${out}" && fail "an out-of-range evidence value still raises: ${out}"
grep -q "out of float range" <<<"${out}" || fail "the reason was not stated: ${out}"
echo "PASS: an out-of-range evidence value is 'unusable' (2), not 'failed' (1)"

# The ordinary verdicts must be untouched.
printf '{"metrics": {"sharpe": 2.5}}' > "${ev}"
python3 "${EVIDENCE}" "${tmp}/t-of.md" >/dev/null 2>&1
[[ $? -eq 0 ]] || fail "a passing evidence gate no longer passes"
printf '{"metrics": {"sharpe": 0.5}}' > "${ev}"
python3 "${EVIDENCE}" "${tmp}/t-of.md" >/dev/null 2>&1
[[ $? -eq 1 ]] || fail "a failing evidence gate no longer fails"
echo "PASS: pass and fail verdicts are unchanged"

# --- gate_run: a branch that edits the gate it is judged by -------------------
repo="${tmp}/repo"
mkdir -p "${repo}/arsenal/tasks"
git init -q -b main "${repo}"
git -C "${repo}" config user.email "test@arsenal.example"
git -C "${repo}" config user.name "Arsenal Test"
_mk_gate() {  # $1 = repo, $2 = command
    printf -- '---\nid: t-x\ntitle: "x"\n---\n\n## Acceptance gate\n```bash\n%s\n```\n' \
        "$2" > "$1/arsenal/tasks/t-x.md"
}
_mk_gate "${repo}" 'echo BOARD_GATE'
git -C "${repo}" add -A
git -C "${repo}" commit -q -m "chore: board gate"

_mk_gate "${repo}" 'echo BRANCH_GATE'
out="$(cd "${repo}" && ARSENAL_GATE_FROM_DEFAULT=1 bash "${GATE_RUN}" t-x 2>&1)"
grep -q "NOT used" <<<"${out}" \
    || fail "an overridden gate edit was discarded in silence: ${out}"
grep -q "BOARD_GATE" <<<"${out}" || fail "the board's gate did not run: ${out}"
grep -q "BRANCH_GATE" <<<"${out}" && fail "the branch's gate ran — self-certification"
grep -q "not on disk" <<<"${out}" \
    && fail "the misleading 'not on disk' diagnostic is back: ${out}"
echo "PASS: a branch's gate edit is refused, said out loud, and not run"

# An unedited working copy must stay quiet — this notice has to mean something.
_mk_gate "${repo}" 'echo BOARD_GATE'
out="$(cd "${repo}" && ARSENAL_GATE_FROM_DEFAULT=1 bash "${GATE_RUN}" t-x 2>&1)"
grep -q "NOT used" <<<"${out}" && fail "an unedited working copy drew the override notice"
echo "PASS: an unedited working copy draws no override notice"

# The bootstrap path is untouched: a placeholder on the board still hands the
# command to the working copy, with its own message and not this one.
marker="$(grep -oE 'PLACEHOLDER_MARKER *= *"[^"]+"' "${GATE_RUN}" | head -1 | sed 's/.*"\(.*\)"/\1/')"
if [[ -n "${marker}" ]]; then
    _mk_gate "${repo}" "# ${marker}"
    git -C "${repo}" add -A
    git -C "${repo}" commit -q -m "chore: placeholder"
    _mk_gate "${repo}" 'echo REAL_BRANCH_GATE'
    out="$(cd "${repo}" && ARSENAL_GATE_FROM_DEFAULT=1 bash "${GATE_RUN}" t-x 2>&1)"
    grep -q "REAL_BRANCH_GATE" <<<"${out}" || fail "the bootstrap path stopped working: ${out}"
    grep -q "NOT used" <<<"${out}" && fail "the bootstrap path drew the override notice: ${out}"
    echo "PASS: the placeholder bootstrap path is unaffected"
fi

# --- arsenal_migrate: a payload that cannot be read is not an empty gate ------
[[ -f "${INIT}" ]] || { echo "SKIP: init.py not found for the migrate case" >&2; exit 0; }
mrepo="${tmp}/mrepo"
mkdir -p "${mrepo}/claude-arsenal/queue" "${mrepo}/claude-arsenal/scripts" \
         "${mrepo}/.claude/skills/init/scripts"
cp "${MIGRATE}" "${mrepo}/claude-arsenal/scripts/"
cp "${INIT}" "${mrepo}/.claude/skills/init/scripts/"
printf '# Good\n\n## Acceptance gate\n```bash\ntrue\n```\n' \
    > "${mrepo}/claude-arsenal/queue/t-aaaa.md"

for bad in '"../../../outside.md"' '"t-missing.md"'; do
    {
        printf '%s\n' '{"id":"t-aaaa","title":"Good","status":"open","payload":"t-aaaa.md"}'
        printf '{"id":"t-bbbb","title":"Bad","status":"open","payload":%s}\n' "${bad}"
    } > "${mrepo}/claude-arsenal/queue/tasks.jsonl"
    rm -rf "${mrepo}/arsenal"
    out="$(cd "${mrepo}" && python3 claude-arsenal/scripts/arsenal_migrate.py --apply 2>&1)"; rc=$?
    [[ "${rc}" -eq 2 ]] || fail "payload ${bad} exited ${rc}, expected 2"
    [[ -e "${mrepo}/arsenal/tasks" ]] \
        && fail "payload ${bad} wrote task files before failing — a partial migration"
done
echo "PASS: a declared payload that cannot be read aborts the migration"

# The opposite policy, deliberately: a row that names NO payload, with no
# `<id>.md` beside the queue, is a task recorded without a body. The gateless
# fallback is the honest rendering of that and must keep working — otherwise
# the fix above turns every bodyless legacy row into a blocked migration.
printf '%s\n' '{"id":"t-aaaa","title":"Good","status":"open","payload":"t-aaaa.md"}' \
               '{"id":"t-nobody","title":"No payload key","status":"open"}' \
    > "${mrepo}/claude-arsenal/queue/tasks.jsonl"
rm -rf "${mrepo}/arsenal"
out="$(cd "${mrepo}" && python3 claude-arsenal/scripts/arsenal_migrate.py --apply 2>&1)"; rc=$?
[[ "${rc}" -eq 0 ]] || fail "a row with no payload key exited ${rc}, expected 0: ${out}"
grep -q "No gate was recorded" "${mrepo}/arsenal/tasks/t-nobody.md" \
    || fail "a row with no payload key lost its fallback body: ${out}"
grep -qF 'true' "${mrepo}/arsenal/tasks/t-aaaa.md" \
    || fail "the sibling row's gate was affected"
echo "PASS: a row that declares no payload still gets the gateless fallback"

# A clean queue still migrates, gate and all.
printf '%s\n' '{"id":"t-aaaa","title":"Good","status":"open","payload":"t-aaaa.md"}' \
    > "${mrepo}/claude-arsenal/queue/tasks.jsonl"
rm -rf "${mrepo}/arsenal"
out="$(cd "${mrepo}" && python3 claude-arsenal/scripts/arsenal_migrate.py --apply 2>&1)"; rc=$?
[[ "${rc}" -eq 0 ]] || fail "a clean queue exited ${rc}, expected 0: ${out}"
grep -qF 'true' "${mrepo}/arsenal/tasks/t-aaaa.md" \
    || fail "the gate was not carried across: ${out}"
grep -q "No gate was recorded" "${mrepo}/arsenal/tasks/t-aaaa.md" \
    && fail "a task with a payload got the gateless fallback"
echo "PASS: a clean queue still migrates with its gate intact"

echo "PASS: gate_integrity_test — all gates passed"
exit 0
