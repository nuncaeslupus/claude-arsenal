#!/usr/bin/env bash
# host_setup_test.sh — unit tests for bin/host_setup.sh
#
# The behaviours pinned here are the ones the script exists for: an undeclared
# host-setup is an announced no-op rather than a silent one, a declared one runs
# in the repo root, its failure is loud, and the tracked-file churn it produces
# is reverted while a file the worker was already editing is not.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST_SETUP="${SCRIPT_DIR}/../skills/init/assets/bin/host_setup.sh"

if [[ ! -f "${HOST_SETUP}" ]]; then
    echo "SKIP: host_setup.sh not found at ${HOST_SETUP}" >&2
    exit 0
fi

tmpdir="$(mktemp -d)"
cleanup() { rm -rf "${tmpdir}"; }
trap cleanup EXIT

repo="${tmpdir}/repo"
mkdir -p "${repo}/arsenal"
(
    cd "${repo}"
    git init -q .
    git config user.email t@example.com
    git config user.name t
    printf 'v1\n' > package-lock.json
    printf 'src\n' > app.txt
    git add -A
    git commit -qm init
) || { echo "FAIL: could not build the fixture repo" >&2; exit 1; }

write_config() { printf '%s\n' "$1" > "${repo}/arsenal/config.toml"; }

run_setup() {
    # From a SUBDIRECTORY on purpose: a command written as `make bootstrap` has
    # to run where the Makefile is, not where the worker happened to stand.
    mkdir -p "${repo}/sub"
    (cd "${repo}/sub" && bash "${HOST_SETUP}" >"${tmpdir}/out" 2>"${tmpdir}/err")
}

# 1. No config file at all → announced no-op, exit 0.
rm -f "${repo}/arsenal/config.toml"
run_setup
code=$?
if [[ ${code} -ne 0 ]]; then
    # Captured before the test, not read as `$?` inside `if ! …` — there it is
    # the negation's status (0), and the message names the wrong exit code in
    # the one case anybody reads it.
    echo "FAIL: no config.toml should exit 0, got ${code} ($(cat "${tmpdir}/err"))" >&2; exit 1
fi
if [[ "$(cat "${tmpdir}/out")" != *"no host-setup declared"* ]]; then
    echo "FAIL: an undeclared host-setup must say so on stdout, got '$(cat "${tmpdir}/out")'" >&2; exit 1
fi
echo "PASS: no host-setup declared is an announced no-op, not a silent one"

# 2. A declared command runs, and runs in the repo root.
write_config 'host-setup = "pwd > setup_ran.txt"'
run_setup
code=$?
if [[ ${code} -ne 0 ]]; then
    echo "FAIL: a passing host-setup should exit 0, got ${code} ($(cat "${tmpdir}/err"))" >&2; exit 1
fi
if [[ ! -f "${repo}/setup_ran.txt" ]]; then
    echo "FAIL: host-setup never ran in the repo root" >&2; exit 1
fi
if [[ "$(cat "${repo}/setup_ran.txt")" != "$(cd "${repo}" && pwd -P)" ]]; then
    echo "FAIL: host-setup ran in '$(cat "${repo}/setup_ran.txt")', not the repo root" >&2; exit 1
fi
rm -f "${repo}/setup_ran.txt"
echo "PASS: a declared host-setup runs, anchored to the repo root"

# 3. Churn the install writes into a TRACKED file is reverted.
write_config 'host-setup = "printf v2 >> package-lock.json && mkdir -p node_modules"'
run_setup
code=$?
if [[ ${code} -ne 0 ]]; then
    echo "FAIL: setup should have succeeded, got ${code} ($(cat "${tmpdir}/err"))" >&2; exit 1
fi
if [[ "$(cat "${repo}/package-lock.json")" != "v1" ]]; then
    echo "FAIL: the install's lockfile churn was left in the tree: '$(cat "${repo}/package-lock.json")'" >&2; exit 1
fi
if [[ ! -d "${repo}/node_modules" ]]; then
    echo "FAIL: the install's untracked output must NOT be reverted — that is what the install is for" >&2; exit 1
fi
echo "PASS: tracked-file churn is reverted; untracked install output is left alone"

# 4. A file the caller was already editing is NOT reverted.
printf 'work in progress\n' > "${repo}/app.txt"
write_config 'host-setup = "printf v2 >> package-lock.json"'
run_setup
code=$?
if [[ ${code} -ne 0 ]]; then
    echo "FAIL: setup should have succeeded, got ${code} ($(cat "${tmpdir}/err"))" >&2; exit 1
fi
if [[ "$(cat "${repo}/app.txt")" != "work in progress" ]]; then
    echo "FAIL: a file dirty BEFORE the run was reverted — the script destroyed the worker's edit" >&2; exit 1
fi
if [[ "$(cat "${repo}/package-lock.json")" != "v1" ]]; then
    echo "FAIL: churn alongside a pre-existing edit was not reverted" >&2; exit 1
fi
git -C "${repo}" checkout -- app.txt
echo "PASS: only the files this run dirtied are reverted"

# 4b. The install rewriting a file the caller had ALREADY edited: the caller's
#     version survives, and the install's does not. Both halves matter — this is
#     the case where the path-set diff alone silently keeps the install's write
#     and drops the work.
printf 'worker edit\n' > "${repo}/package-lock.json"
write_config 'host-setup = "printf INSTALLED > package-lock.json"'
run_setup
code=$?
if [[ ${code} -ne 0 ]]; then
    echo "FAIL: setup should have succeeded, got ${code} ($(cat "${tmpdir}/err"))" >&2; exit 1
fi
if [[ "$(cat "${repo}/package-lock.json")" != "worker edit" ]]; then
    echo "FAIL: the install overwrote an edit that was already in the tree: '$(cat "${repo}/package-lock.json")'" >&2; exit 1
fi
git -C "${repo}" checkout -- package-lock.json
echo "PASS: an install that rewrites an already-edited file leaves the caller's version, not its own"

# 4c. Same, for a tracked file the caller DELETED and the install put back.
git -C "${repo}" rm -q --cached app.txt >/dev/null 2>&1 && git -C "${repo}" reset -q >/dev/null 2>&1
rm -f "${repo}/app.txt"
write_config 'host-setup = "printf resurrected > app.txt"'
run_setup
code=$?
if [[ ${code} -ne 0 ]]; then
    echo "FAIL: setup should have succeeded, got ${code} ($(cat "${tmpdir}/err"))" >&2; exit 1
fi
if [[ -e "${repo}/app.txt" ]]; then
    echo "FAIL: a file the caller deleted was resurrected by the install and left behind" >&2; exit 1
fi
git -C "${repo}" checkout -- app.txt
echo "PASS: a file the caller deleted stays deleted when the install recreates it"

# 5. A failing setup command exits 1 and says the tree is not ready.
write_config 'host-setup = "exit 7"'
run_setup
code=$?
if [[ ${code} -ne 1 ]]; then
    echo "FAIL: a failing host-setup must exit 1, got ${code}" >&2; exit 1
fi
if [[ "$(cat "${tmpdir}/err")" != *"host setup command failed"* ]]; then
    echo "FAIL: a failing host-setup must say so on stderr, got '$(cat "${tmpdir}/err")'" >&2; exit 1
fi
echo "PASS: a failing host-setup exits 1 rather than letting the next gate look like a verdict"

# 5b. A FAILING install still gets cleaned up after. This is the path where the
#     install is least trustworthy — a lockfile rewritten and then a resolution
#     error, a post-install script that exits non-zero, an interrupted network
#     install — and it was the one path that skipped both cleanup halves,
#     because the early `exit 1` sat lexically above them. The snapshot was
#     taken and never read, so the caller's overwritten edit survived only as an
#     unreferenced blob in the object database.
printf 'worker edit\n' > "${repo}/app.txt"
write_config 'host-setup = "printf INSTALLED > app.txt; printf LOCK > package-lock.json; exit 7"'
run_setup
code=$?
if [[ ${code} -ne 1 ]]; then
    echo "FAIL: a failing host-setup must still exit 1, got ${code}" >&2; exit 1
fi
if [[ "$(cat "${repo}/app.txt")" != "worker edit" ]]; then
    echo "FAIL: a failing install destroyed an edit already in the tree: '$(cat "${repo}/app.txt")'" >&2; exit 1
fi
if [[ "$(cat "${repo}/package-lock.json")" != "v1" ]]; then
    echo "FAIL: a failing install left its churn behind: '$(cat "${repo}/package-lock.json")'" >&2; exit 1
fi
git -C "${repo}" checkout -- app.txt package-lock.json
echo "PASS: a failing install is cleaned up after — the caller's edit survives and the churn does not"

# 6. A malformed config is exit 2, NOT "nothing declared".
write_config 'host-setup = '
run_setup
code=$?
if [[ ${code} -ne 2 ]]; then
    echo "FAIL: an unreadable config must exit 2 (not read as 'no setup declared'), got ${code}" >&2; exit 1
fi
echo "PASS: an unreadable config.toml is a setup error, not a silent skip"

# 7. Outside a git repository → exit 2 rather than running anything anywhere.
mkdir -p "${tmpdir}/nogit"
(cd "${tmpdir}/nogit" && GIT_CEILING_DIRECTORIES="${tmpdir}" bash "${HOST_SETUP}" >/dev/null 2>&1)
code=$?
if [[ ${code} -ne 2 ]]; then
    echo "FAIL: outside a git repo host_setup must exit 2, got ${code}" >&2; exit 1
fi
echo "PASS: outside a git repository the script refuses rather than guessing a root"

echo "PASS: host_setup_test — all gates passed"
exit 0
