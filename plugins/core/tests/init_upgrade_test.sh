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
from pathlib import Path
block = m._claude_md_block(Path('${REPO}'))
print(block.replace(m.CLAUDE_MD_END_MARKER, '').rstrip())
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

# --- 6: a bundle NEWER than the skill is never overwritten (#220) ---
#     Step 0b runs `init.py --silent` before a session knows what kind of session
#     it is. On a host whose committed bundle is ahead of the skill's vendored
#     copies, the checksum refresh cannot tell forward from backward: it replaced
#     upstream fixes with the versions that predate them, silently, and the next
#     PR that session opened carried the revert.
newer="99.0.0"
echo "${newer}" > "${REPO}/claude-arsenal/.bundle-version"
canary="${REPO}/claude-arsenal/bin/gate_run.sh"
[[ -f "${canary}" ]] || fail "gate_run.sh missing — the fixture cannot detect a downgrade"
printf '#!/usr/bin/env bash
# newer than the skill ships
' > "${canary}"
out=$(python3 "${INIT_PY}" --repo-path "${REPO}" --bundle-dir "${BUNDLE}" --silent 2>&1)
[[ "$(cat "${REPO}/claude-arsenal/.bundle-version")" == "${newer}" ]] \
    || fail "the newer installed version was overwritten: ${out}"
grep -q "newer than the skill ships" "${canary}" \
    || fail "a newer installed bundle file was reverted to the skill's older copy"
grep -q "NEWER" <<<"${out}" || fail "--silent hid the downgrade refusal: ${out}"
# ...and the escape hatch still works, saying what it is doing.
out=$(python3 "${INIT_PY}" --repo-path "${REPO}" --bundle-dir "${BUNDLE}" --allow-downgrade 2>&1)
grep -q "DOWNGRADING" <<<"${out}" || fail "--allow-downgrade did not announce the downgrade: ${out}"
[[ "$(cat "${REPO}/claude-arsenal/.bundle-version")" != "${newer}" ]] \
    || fail "--allow-downgrade left the newer version in place"
echo "PASS: a newer installed bundle is reported, not reverted"

# --- 6b: and the refusal stops workspace registration too ---
#     init_workspace() installs the base when claude-arsenal/bin/ is absent and
#     then builds the workspace regardless, so a refusal would have reported a
#     workspace ready over a bundle that was never written.
WS="${tmpdir}/ws-repo"
mkdir -p "${WS}/claude-arsenal"
echo "99.0.0" > "${WS}/claude-arsenal/.bundle-version"
out=$(python3 "${INIT_PY}" --repo-path "${WS}" --bundle-dir "${BUNDLE}" --workspace demo 2>&1); rc=$?
[[ ${rc} -ne 0 ]] || fail "registering a workspace over a refused install should fail: ${out}"
[[ -d "${WS}/arsenal/project/demo" ]] \
    && fail "the workspace was registered even though the bundle refused to install"
echo "PASS: a refused install does not register a workspace"

# --- 7: CHANGELOG entries surface on the upgrade banner ---------------------
#     init.py used to print only "Upgrading bundle: X -> Y" — a version number
#     with no way to know what actually changed. A consumer three releases
#     behind had no signal that a feature they would want had even shipped,
#     short of reading the marketplace's own commit history by hand.
changelog_repo="${tmpdir}/changelog-repo"
changelog_bundle="${tmpdir}/changelog-bundle"
mkdir -p "${changelog_repo}/claude-arsenal" "${changelog_bundle}"
echo "1.0.0" > "${changelog_repo}/claude-arsenal/.bundle-version"
echo "1.2.0" > "${changelog_bundle}/.bundle-version"
cat > "${changelog_bundle}/CHANGELOG.md" <<'EOF'
# Changelog

## [1.2.0] - 2026-01-03

- Newest entry, should print.

## [1.1.0] - 2026-01-02

- Middle entry, should print.

## [1.0.0] - 2026-01-01

- Entry AT the installed version, already have it — must NOT print.

## [0.9.0] - 2025-12-01

- Entry BEFORE the installed version — must NOT print.
EOF

out=$(python3 "${INIT_PY}" --repo-path "${changelog_repo}" --bundle-dir "${changelog_bundle}" 2>&1) \
    || fail "init.py failed with a CHANGELOG.md present: ${out}"
grep -q "Upgrading claude-arsenal bundle: 1.0.0 → 1.2.0" <<<"${out}" \
    || fail "upgrade banner missing or wrong versions: ${out}"
grep -q "Newest entry, should print" <<<"${out}" || fail "the 1.2.0 changelog entry did not print: ${out}"
grep -q "Middle entry, should print" <<<"${out}" || fail "the 1.1.0 changelog entry did not print: ${out}"
grep -q "already have it" <<<"${out}" && fail "the entry AT the installed version must not print: ${out}"
grep -q "BEFORE the installed version" <<<"${out}" && fail "an entry older than installed must not print: ${out}"
newest_at=$(grep -n "Newest entry" <<<"${out}" | cut -d: -f1)
middle_at=$(grep -n "Middle entry" <<<"${out}" | cut -d: -f1)
[[ -n "${newest_at}" && -n "${middle_at}" && "${newest_at}" -lt "${middle_at}" ]] \
    || fail "changelog entries must print newest first: ${out}"
echo "PASS: the upgrade banner prints CHANGELOG entries strictly between installed and new"

# --- 7b: no CHANGELOG.md in the bundle — the banner still prints, just without it
no_changelog_repo="${tmpdir}/no-changelog-repo"
no_changelog_bundle="${tmpdir}/no-changelog-bundle"
mkdir -p "${no_changelog_repo}/claude-arsenal" "${no_changelog_bundle}"
echo "1.0.0" > "${no_changelog_repo}/claude-arsenal/.bundle-version"
echo "1.1.0" > "${no_changelog_bundle}/.bundle-version"
out=$(python3 "${INIT_PY}" --repo-path "${no_changelog_repo}" --bundle-dir "${no_changelog_bundle}" 2>&1) \
    || fail "init.py failed with no CHANGELOG.md present: ${out}"
grep -q "Upgrading claude-arsenal bundle: 1.0.0 → 1.1.0" <<<"${out}" \
    || fail "upgrade banner missing when there is no CHANGELOG.md: ${out}"
echo "PASS: a bundle with no CHANGELOG.md still upgrades cleanly"

# --- 7c: a CHANGELOG.md that is not valid UTF-8 must not crash /init --------
#     _changelog_since read the file with no guard; an unreadable or non-UTF-8
#     CHANGELOG.md raised out of _check_bundle_version, which runs
#     unconditionally at the top of every init_base() call — including the
#     silent session-start refresh every session performs automatically.
bad_encoding_repo="${tmpdir}/bad-encoding-repo"
bad_encoding_bundle="${tmpdir}/bad-encoding-bundle"
mkdir -p "${bad_encoding_repo}/claude-arsenal" "${bad_encoding_bundle}"
echo "1.0.0" > "${bad_encoding_repo}/claude-arsenal/.bundle-version"
echo "1.1.0" > "${bad_encoding_bundle}/.bundle-version"
printf '# Changelog\n\n## [1.1.0] - 2026-01-01\n\n- \xff\xfe invalid utf-8 bytes\n' > "${bad_encoding_bundle}/CHANGELOG.md"
out=$(python3 "${INIT_PY}" --repo-path "${bad_encoding_repo}" --bundle-dir "${bad_encoding_bundle}" 2>&1); rc=$?
[[ ${rc} -eq 0 ]] || fail "init.py exited ${rc} on a non-UTF-8 CHANGELOG.md: ${out}"
grep -q "Upgrading claude-arsenal bundle: 1.0.0 → 1.1.0" <<<"${out}" \
    || fail "upgrade banner missing when CHANGELOG.md is not valid UTF-8: ${out}"
echo "PASS: a CHANGELOG.md that is not valid UTF-8 does not crash init.py"

echo "PASS: init_upgrade_test — all gates passed"
