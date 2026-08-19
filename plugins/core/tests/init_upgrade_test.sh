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

cat > "${REPO}/CLAUDE.md" <<'EOF'
# My project

Host-owned notes that must survive.

<!-- claude-arsenal: auto-managed -->
## Automatic session protocol

1. Read `claude-arsenal/session/handover.md` for last session activity.
2. Run `claude-arsenal/bin/queue_eval.sh`.

@claude-arsenal/AGENTS.md

More host-owned content below the block.
EOF

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
