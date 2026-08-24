#!/usr/bin/env bash
# gate_run_test.sh — unit tests for gate_run.sh
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE_RUN="${SCRIPT_DIR}/../skills/init/assets/bin/gate_run.sh"

if [[ ! -f "${GATE_RUN}" ]]; then
    echo "SKIP: gate_run.sh not found at ${GATE_RUN}" >&2
    exit 0
fi

tmpdir=$(mktemp -d)
cleanup() { rm -rf "${tmpdir}"; }
trap cleanup EXIT

mkdir -p "${tmpdir}/arsenal/tasks"

run_gate() {
    # Run gate_run.sh from tmpdir so relative paths work
    (cd "${tmpdir}" && bash "${GATE_RUN}" "$1")
}

# Gate 1: no payload file → exit 2
if (cd "${tmpdir}" && bash "${GATE_RUN}" "lo-missing" 2>/dev/null); then
    echo "FAIL: missing payload should exit non-zero" >&2; exit 1
fi

# Gate 2: payload with no ## Acceptance gate section → exit 0 (pass through)
cat > "${tmpdir}/arsenal/tasks/lo-no-gate.md" <<'EOF'
# T1: No gate

## Tests
None.
EOF
if ! run_gate "lo-no-gate"; then
    echo "FAIL: no gate section should exit 0" >&2; exit 1
fi

# Gate 3: prose-only gate (no bash block) → exit 0
cat > "${tmpdir}/arsenal/tasks/lo-prose.md" <<'EOF'
# T2: Prose gate

## Acceptance gate
All unit tests pass and the API returns 200.

## Tests
Manual.
EOF
if ! run_gate "lo-prose"; then
    echo "FAIL: prose-only gate should exit 0" >&2; exit 1
fi

# Gate 4: mechanical gate that passes → exit 0
cat > "${tmpdir}/arsenal/tasks/lo-pass.md" <<'EOF'
# T3: Passing gate

## Acceptance gate
The exit code must be 0.

```bash
exit 0
```
EOF
if ! run_gate "lo-pass"; then
    echo "FAIL: passing gate should exit 0" >&2; exit 1
fi

# Gate 5: mechanical gate that fails → exit 1
cat > "${tmpdir}/arsenal/tasks/lo-fail.md" <<'EOF'
# T4: Failing gate

## Acceptance gate
This will fail.

```bash
exit 1
```
EOF
if run_gate "lo-fail" 2>/dev/null; then
    echo "FAIL: failing gate should exit 1" >&2; exit 1
fi

# Gate 6: multi-line gate command → runs as a script
cat > "${tmpdir}/arsenal/tasks/lo-multi.md" <<'EOF'
# T5: Multi-line gate

## Acceptance gate
Creates a sentinel file.

```bash
touch .gate_sentinel
test -f .gate_sentinel
```
EOF
if ! run_gate "lo-multi"; then
    echo "FAIL: multi-line gate should exit 0" >&2; exit 1
fi
if [[ ! -f "${tmpdir}/.gate_sentinel" ]]; then
    echo "FAIL: multi-line gate did not create sentinel" >&2; exit 1
fi

# Gate 7: hardened-by-default env (CA-02) — the gate's $HOME is a throwaway dir,
# not the caller's real HOME. The gate writes its HOME to a file we inspect.
cat > "${tmpdir}/arsenal/tasks/lo-home.md" <<'EOF'
# T6: HOME isolation

## Acceptance gate
Records the gate's HOME.

```bash
printf '%s' "${HOME}" > home_seen.txt
```
EOF
run_gate "lo-home"
SEEN_HOME=$(cat "${tmpdir}/home_seen.txt" 2>/dev/null || echo "")
if [[ "${SEEN_HOME}" == "${HOME}" || -z "${SEEN_HOME}" ]]; then
    echo "FAIL: gate HOME should be a throwaway dir, got '${SEEN_HOME}'" >&2; exit 1
fi
echo "PASS: gate runs under a throwaway HOME by default"

# Gate 8: ARSENAL_GATE_INHERIT_ENV=1 restores the caller's real HOME.
rm -f "${tmpdir}/home_seen.txt"
(cd "${tmpdir}" && ARSENAL_GATE_INHERIT_ENV=1 bash "${GATE_RUN}" "lo-home")
SEEN_HOME=$(cat "${tmpdir}/home_seen.txt" 2>/dev/null || echo "")
if [[ "${SEEN_HOME}" != "${HOME}" ]]; then
    echo "FAIL: INHERIT_ENV gate HOME should equal '${HOME}', got '${SEEN_HOME}'" >&2; exit 1
fi
echo "PASS: ARSENAL_GATE_INHERIT_ENV=1 restores the caller environment"

# Gate 9: no persisted gate script orphaned in TMPDIR (CA-09 — piped via stdin).
before=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'arsenal-gate*' 2>/dev/null | wc -l)
run_gate "lo-pass"
after=$(find "${TMPDIR:-/tmp}" -maxdepth 1 -name 'arsenal-gate*' 2>/dev/null | wc -l)
if [[ "${after}" -gt "${before}" ]]; then
    echo "FAIL: gate left orphaned temp artifacts in TMPDIR" >&2; exit 1
fi
echo "PASS: no orphaned gate script left behind"

# --- A gate that ran nothing must not look like a pass -----------------------
# Regression for the downstream audit that found 0 of 70 payloads carrying a
# fenced block: every gate exited 0 in silence, and release.sh treated that as
# its `done` precondition, so the mechanical-gate layer was inert repo-wide
# without a word of warning.

# Gate 10: no ## Acceptance gate section → `gate: none` + a stderr warning.
out="$(cd "${tmpdir}" && bash "${GATE_RUN}" "lo-no-gate" 2>"${tmpdir}/err.log")"
if [[ "${out}" != *"gate: none"* ]]; then
    echo "FAIL: missing gate section should report 'gate: none', got '${out}'" >&2; exit 1
fi
if ! grep -q "NOTHING WAS EXECUTED" "${tmpdir}/err.log"; then
    echo "FAIL: missing gate section should warn on stderr, got: $(cat "${tmpdir}/err.log")" >&2; exit 1
fi
echo "PASS: a payload with no gate section reports 'gate: none', loudly"

# Gate 11: prose-only gate → `gate: prose-only` + a stderr warning that names
# the inline-backtick trap.
out="$(cd "${tmpdir}" && bash "${GATE_RUN}" "lo-prose" 2>"${tmpdir}/err.log")"
if [[ "${out}" != *"gate: prose-only"* ]]; then
    echo "FAIL: prose-only gate should report 'gate: prose-only', got '${out}'" >&2; exit 1
fi
if ! grep -q "NOTHING WAS EXECUTED" "${tmpdir}/err.log"; then
    echo "FAIL: prose-only gate should warn on stderr, got: $(cat "${tmpdir}/err.log")" >&2; exit 1
fi
echo "PASS: a prose-only gate reports 'gate: prose-only', loudly"

# Gate 12: a gate that really ran and passed says so — the two states are now
# distinguishable from each other, which is the whole point.
out="$(cd "${tmpdir}" && bash "${GATE_RUN}" "lo-pass" 2>/dev/null)"
if [[ "${out}" != *"gate: passed"* ]]; then
    echo "FAIL: an executed passing gate should report 'gate: passed', got '${out}'" >&2; exit 1
fi
echo "PASS: an executed gate reports 'gate: passed'"

# Gate 13: strict mode turns "nothing ran" into a hard failure.
if (cd "${tmpdir}" && ARSENAL_GATE_REQUIRE_BLOCK=1 bash "${GATE_RUN}" "lo-prose" >/dev/null 2>&1); then
    echo "FAIL: ARSENAL_GATE_REQUIRE_BLOCK=1 should fail a prose-only gate" >&2; exit 1
fi
if (cd "${tmpdir}" && ARSENAL_GATE_REQUIRE_BLOCK=1 bash "${GATE_RUN}" "lo-no-gate" >/dev/null 2>&1); then
    echo "FAIL: ARSENAL_GATE_REQUIRE_BLOCK=1 should fail a payload with no gate section" >&2; exit 1
fi
if ! (cd "${tmpdir}" && ARSENAL_GATE_REQUIRE_BLOCK=1 bash "${GATE_RUN}" "lo-pass" >/dev/null 2>&1); then
    echo "FAIL: ARSENAL_GATE_REQUIRE_BLOCK=1 must still pass a real mechanical gate" >&2; exit 1
fi
echo "PASS: ARSENAL_GATE_REQUIRE_BLOCK=1 fails vacuous gates and passes real ones"

# --- A gate that COULD NOT RUN is not a verdict ------------------------------
# Distinct from "ran and failed": exit 3, announced on stdout as well as stderr
# so a caller that pipes this script's output (`gate_run.sh <id> | tail`) — and
# thereby loses the exit status to the pipeline — still sees that nothing ran.

# Gate 14: a gate whose command does not exist → exit 3, banner on stdout.
cat > "${tmpdir}/arsenal/tasks/lo-cannotrun.md" <<'EOF'
# T7: Unrunnable gate

## Acceptance gate
The command does not exist.

```bash
definitely-not-a-real-command-xyz
```
EOF
set +e
out="$(cd "${tmpdir}" && bash "${GATE_RUN}" "lo-cannotrun" 2>"${tmpdir}/err.log")"
rc=$?
set -e
if [[ "${rc}" -ne 3 ]]; then
    echo "FAIL: unrunnable gate should exit 3 (not 0, not 1), got ${rc}" >&2; exit 1
fi
if [[ "${out}" != *"GATE COULD NOT RUN"* ]]; then
    echo "FAIL: unrunnable gate must announce itself on stdout, got '${out}'" >&2; exit 1
fi
if ! grep -q "GATE COULD NOT RUN" "${tmpdir}/err.log"; then
    echo "FAIL: unrunnable gate must also warn on stderr" >&2; exit 1
fi
echo "PASS: a gate that could not run exits 3 and says so on both streams"

# --- The hardened env must not make gates unrunnable -------------------------

# Gate 15: the package manager / runtime is reachable inside the hardened env.
# pnpm, node, uv & friends are routinely installed under $HOME (nvm, corepack,
# volta, asdf, rustup); stripping $HOME from PATH wholesale left every
# `pnpm test` gate at exit 127 — a gate that CANNOT run, which is worse than an
# unhardened one. Use a shim under a fake HOME so the check is hermetic.
mkdir -p "${tmpdir}/fakehome/bin"
cat > "${tmpdir}/fakehome/bin/node" <<'EOF'
#!/usr/bin/env bash
printf 'arsenal-shim'
EOF
chmod +x "${tmpdir}/fakehome/bin/node"
cat > "${tmpdir}/arsenal/tasks/lo-pkgmgr.md" <<'EOF'
# T8: Package manager on PATH

## Acceptance gate
Records what `node` resolved to.

```bash
node > node_seen.txt
```
EOF
rm -f "${tmpdir}/node_seen.txt"
set +e
(cd "${tmpdir}" && HOME="${tmpdir}/fakehome" PATH="${tmpdir}/fakehome/bin:${PATH}" \
    bash "${GATE_RUN}" "lo-pkgmgr" >/dev/null 2>&1)
set -e
if [[ "$(cat "${tmpdir}/node_seen.txt" 2>/dev/null || echo "")" != "arsenal-shim" ]]; then
    echo "FAIL: a \$HOME-installed runtime must stay on the hardened PATH" >&2; exit 1
fi
echo "PASS: the package manager / runtime dir survives PATH hardening"

# Gate 16: COREPACK_HOME points at the real corepack cache. A throwaway HOME
# makes corepack re-download the pinned package manager on every gate run, and
# fail outright offline. It is a package cache, not a credential store.
mkdir -p "${tmpdir}/corepack-cache"
cat > "${tmpdir}/arsenal/tasks/lo-corepack.md" <<'EOF'
# T9: corepack cache

## Acceptance gate
Records COREPACK_HOME.

```bash
printf '%s' "${COREPACK_HOME:-unset}" > corepack_seen.txt
```
EOF
(cd "${tmpdir}" && COREPACK_HOME="${tmpdir}/corepack-cache" bash "${GATE_RUN}" "lo-corepack" >/dev/null)
if [[ "$(cat "${tmpdir}/corepack_seen.txt" 2>/dev/null || echo "")" != "${tmpdir}/corepack-cache" ]]; then
    echo "FAIL: COREPACK_HOME should reach the gate, got '$(cat "${tmpdir}/corepack_seen.txt" 2>/dev/null)'" >&2
    exit 1
fi
echo "PASS: COREPACK_HOME is forwarded to the hardened gate env"

# --- Task-file resolution from the default branch ----------------------------
# Gate 17: a worktree cut from an older base may predate the commit that added
# the task file. Read it from the default branch — into a temp file OUTSIDE the
# repo, since open_task_pr.sh's `git add -A` would otherwise sweep it into the
# PR diff. (Under the coordination-branch design this fallback existed because
# the payload lived on a ref the worker was never on; now it is only about an
# out-of-date worktree.)
refrepo="${tmpdir}/refrepo"
git init -q -b main "${refrepo}"
git -C "${refrepo}" config user.email "test@arsenal.example"
git -C "${refrepo}" config user.name "Arsenal Test"
git -C "${refrepo}" config commit.gpgsign false
mkdir -p "${refrepo}/arsenal/tasks"
echo "seed" > "${refrepo}/README"
git -C "${refrepo}" add -A
git -C "${refrepo}" commit -q -m "seed default branch"
cat > "${refrepo}/arsenal/tasks/t-onref.md" <<'EOF'
---
id: t-onref
title: "Only on the default branch"
---

## Acceptance gate

```bash
true
```
EOF
git -C "${refrepo}" add -A
git -C "${refrepo}" commit -q -m "add the task"
# Simulate a stale worktree: the file is committed but absent from the checkout.
rm "${refrepo}/arsenal/tasks/t-onref.md"
if ! (cd "${refrepo}" && ARSENAL_DEFAULT_BRANCH=main bash "${GATE_RUN}" "t-onref" >/dev/null 2>&1); then
    echo "FAIL: a task file present only in the default branch should be resolved and run" >&2; exit 1
fi
# The property that matters: nothing was materialized INSIDE the repo, or
# open_task_pr.sh's `git add -A` would sweep it into the PR diff. (The deleted
# task file itself shows as a tracked deletion; that is the simulated staleness,
# not residue.)
if git -C "${refrepo}" status --porcelain --untracked-files=all | grep -q '^??'; then
    echo "FAIL: resolving the task file left an untracked file in the repo tree" >&2; exit 1
fi
echo "PASS: task file resolves from the default branch without dirtying the tree"

# Gate 18: the bootstrap case. A task filed from the template carries a gate
# command that fails on purpose, and open_task_pr.sh resolves the gate from the
# default branch — so the only PR that could replace the placeholder was the one
# the gate refused. The working copy's command runs instead when the default
# branch's is still the placeholder.
cat > "${refrepo}/arsenal/tasks/t-boot.md" <<'EOF'
---
id: t-boot
title: "Placeholder gate on the default branch"
---

## Acceptance gate

```bash
# arsenal:gate-placeholder — replace with the real check; it may land in this task's own PR
false
```
EOF
git -C "${refrepo}" add -A
git -C "${refrepo}" commit -q -m "file the task with the placeholder gate"
# The worker's branch replaces the placeholder with a real check.
cat > "${refrepo}/arsenal/tasks/t-boot.md" <<'EOF'
---
id: t-boot
title: "Placeholder gate on the default branch"
---

## Acceptance gate

```bash
true
```
EOF
if ! (cd "${refrepo}" && ARSENAL_DEFAULT_BRANCH=main ARSENAL_GATE_FROM_DEFAULT=1 bash "${GATE_RUN}" "t-boot" >/dev/null 2>&1); then
    echo "FAIL: a working copy replacing the placeholder gate command should run" >&2; exit 1
fi
# ...and the guard still holds: a real command on the default branch is the one
# that runs, not whatever the worker's branch says.
cat > "${refrepo}/arsenal/tasks/t-real.md" <<'EOF'
---
id: t-real
title: "Real gate on the default branch"
---

## Acceptance gate

```bash
false
echo replaced-by-worker
```
EOF
git -C "${refrepo}" add -A
git -C "${refrepo}" commit -q -m "file the task with a real gate"
cat > "${refrepo}/arsenal/tasks/t-real.md" <<'EOF'
---
id: t-real
title: "Real gate on the default branch"
---

## Acceptance gate

```bash
true
```
EOF
if (cd "${refrepo}" && ARSENAL_DEFAULT_BRANCH=main ARSENAL_GATE_FROM_DEFAULT=1 bash "${GATE_RUN}" "t-real" >/dev/null 2>&1); then
    echo "FAIL: the working copy must not override a real gate on the default branch" >&2; exit 1
fi
# A pre-marker placeholder (a lone `false` with an explanatory comment) counts too.
cat > "${refrepo}/arsenal/tasks/t-old.md" <<'EOF'
---
id: t-old
title: "Pre-marker placeholder"
---

## Acceptance gate

```bash
false  # fail until a real check replaces this
```
EOF
git -C "${refrepo}" add -A
git -C "${refrepo}" commit -q -m "file the task with the pre-marker placeholder"
cat > "${refrepo}/arsenal/tasks/t-old.md" <<'EOF'
---
id: t-old
title: "Pre-marker placeholder"
---

## Acceptance gate

```bash
true
```
EOF
if ! (cd "${refrepo}" && ARSENAL_DEFAULT_BRANCH=main ARSENAL_GATE_FROM_DEFAULT=1 bash "${GATE_RUN}" "t-old" >/dev/null 2>&1); then
    echo "FAIL: the pre-marker placeholder should be recognised too" >&2; exit 1
fi
# The marker counts only on a comment line. A real gate may well mention it as
# data — grepping for un-replaced placeholders is exactly the check someone
# writes — and matching that would hand the command back to the branch under review.
cat > "${refrepo}/arsenal/tasks/t-data.md" <<'EOF'
---
id: t-data
title: "Marker as command data"
---

## Acceptance gate

```bash
echo "arsenal:gate-placeholder" >/dev/null
false
```
EOF
git -C "${refrepo}" add -A
git -C "${refrepo}" commit -q -m "file the task whose real gate mentions the marker"
cat > "${refrepo}/arsenal/tasks/t-data.md" <<'EOF'
---
id: t-data
title: "Marker as command data"
---

## Acceptance gate

```bash
true
```
EOF
if (cd "${refrepo}" && ARSENAL_DEFAULT_BRANCH=main ARSENAL_GATE_FROM_DEFAULT=1 \
        bash "${GATE_RUN}" "t-data" >/dev/null 2>&1); then
    echo "FAIL: the marker as command data must not count as a placeholder" >&2; exit 1
fi
echo "PASS: a placeholder gate command on the default branch defers to the working copy"

echo "PASS: gate_run_test — all gates passed"
exit 0
