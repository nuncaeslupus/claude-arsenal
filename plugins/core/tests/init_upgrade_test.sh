#!/usr/bin/env bash
# init_upgrade_test.sh — what an UPGRADE does, as opposed to a fresh install.
#
# A consumer upgrading v0.23.1 → v0.26.0 followed the documented steps and still
# ran the old protocol afterwards: init.py skipped the CLAUDE.md block it labels
# "auto-managed" because a marker was already there, and it never removed the
# retired coordination-branch scripts, which stayed installed and executable.
# Fresh-install tests could not see either — both need a repo that already has
# a previous version in it.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INIT_PY="${SCRIPT_DIR}/../skills/init/scripts/init.py"
BUNDLE="${SCRIPT_DIR}/../skills/init/assets"
[[ -f "${INIT_PY}" ]] || { echo "SKIP: ${INIT_PY} not found" >&2; exit 0; }

tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

REPO="${tmpdir}/repo"
mkdir -p "${REPO}/claude-arsenal/bin" "${REPO}/claude-arsenal/scripts"

# A repo carrying the previous release: retired scripts, and a CLAUDE.md whose
# managed block predates the end marker and names the old paths.
for old in claim.sh release.sh queue_eval.sh queue_batch.sh; do
    printf '#!/usr/bin/env bash\necho "old architecture"\n' > "${REPO}/claude-arsenal/bin/${old}"
    chmod +x "${REPO}/claude-arsenal/bin/${old}"
done
printf '#!/usr/bin/env python3\n' > "${REPO}/claude-arsenal/scripts/queue_doctor.py"

# The legacy block is DERIVED from what init.py itself writes, minus the end
# marker that older releases had no concept of. A hand-written stub was what let
# a corruption bug ship: the real block mentions `@claude-arsenal/AGENTS.md`
# inline in step 4 as well as standalone at the end, and a fixture that omitted
# the inline mention could not exercise the case that broke.
legacy_block=$(python3 -c "
import importlib.util
s = importlib.util.spec_from_file_location('m', '${INIT_PY}')
m = importlib.util.module_from_spec(s); s.loader.exec_module(m)
print(m.CLAUDE_MD_BLOCK.replace(m.CLAUDE_MD_END_MARKER, '').rstrip())
") || fail "could not derive the legacy block from init.py"

{
    printf '# My project\n\nHost-owned notes that must survive.\n\n'
    printf '%s\n' "${legacy_block}"
    printf '\nMore host-owned content below the block.\n'
} > "${REPO}/CLAUDE.md"

python3 "${INIT_PY}" --repo-path "${REPO}" --bundle-dir "${BUNDLE}" >"${tmpdir}/out.txt" 2>&1 \
    || fail "init.py failed: $(cat "${tmpdir}/out.txt")"

# --- 1: the managed block is actually managed ---
grep -q 'queue_eval.sh' "${REPO}/CLAUDE.md" && fail "the stale protocol block survived the upgrade"
grep -q 'task_select.py' "${REPO}/CLAUDE.md" || fail "the current protocol was not written"
grep -q 'arsenal/session/handover.md' "${REPO}/CLAUDE.md" || fail "handover path not updated"

# --- 2: host-owned content around the block is untouched ---
grep -q 'Host-owned notes that must survive' "${REPO}/CLAUDE.md" || fail "content above the block was lost"
grep -q 'More host-owned content below the block' "${REPO}/CLAUDE.md" \
    || fail "content below the block was eaten — the legacy tail match ran too far"

# --- 2b: and the opposite failure — a tail match that stops too EARLY ---
#     `@claude-arsenal/AGENTS.md` appears inline inside step 4 as well as
#     standalone at the end. Matching the first occurrence cut the block in half
#     and stranded steps 5 and 6 below the closing marker, where they read as
#     host content and were duplicated on the next upgrade.
for step in '5\. Open each task' '6\. After any session'; do
    n=$(grep -c "^${step}" "${REPO}/CLAUDE.md")
    [[ "${n}" -eq 1 ]] || fail "protocol step matching /${step}/ appears ${n} times — the block was duplicated into host content"
done
n=$(grep -c '^@claude-arsenal/AGENTS.md$' "${REPO}/CLAUDE.md")
[[ "${n}" -eq 1 ]] || fail "the AGENTS.md import appears ${n} times after the upgrade"
n=$(grep -c 'claude-arsenal: auto-managed' "${REPO}/CLAUDE.md")
[[ "${n}" -eq 2 ]] || fail "expected exactly one open+close marker pair, found ${n} marker lines"

# --- 3: retired scripts are gone, current ones are present ---
for gone in claim.sh release.sh queue_eval.sh queue_batch.sh; do
    [[ -e "${REPO}/claude-arsenal/bin/${gone}" ]] \
        && fail "${gone} is retired upstream but still installed and executable"
done
[[ -e "${REPO}/claude-arsenal/scripts/queue_doctor.py" ]] && fail "retired queue_doctor.py still installed"
[[ -f "${REPO}/claude-arsenal/bin/claim_task.sh" ]] || fail "current claim_task.sh missing"
[[ -f "${REPO}/claude-arsenal/scripts/task_select.py" ]] || fail "current task_select.py missing"

# --- 4: host state is never pruned ---
[[ -d "${REPO}/arsenal/tasks" ]] || fail "arsenal/tasks not scaffolded"
echo "mine" > "${REPO}/arsenal/tasks/t-keepme.md"
echo "mine" > "${REPO}/arsenal/session/handover.md"
python3 "${INIT_PY}" --repo-path "${REPO}" --bundle-dir "${BUNDLE}" --silent >/dev/null 2>&1
[[ -f "${REPO}/arsenal/tasks/t-keepme.md" ]] || fail "a host task file was deleted"
grep -q mine "${REPO}/arsenal/session/handover.md" || fail "host handover was clobbered"

# --- 5: re-running is a no-op on the block, and says so ---
out=$(python3 "${INIT_PY}" --repo-path "${REPO}" --bundle-dir "${BUNDLE}" 2>&1)
grep -q "up to date" <<<"${out}" || fail "a second run should report the block up to date: ${out}"
grep -q "refreshed (was out of date)" <<<"${out}" && fail "the block was rewritten on an idempotent re-run"

echo "PASS: init_upgrade_test — all gates passed"
