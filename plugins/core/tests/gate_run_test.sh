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

mkdir -p "${tmpdir}/claude-arsenal/queue"

run_gate() {
    # Run gate_run.sh from tmpdir so relative paths work
    (cd "${tmpdir}" && bash "${GATE_RUN}" "$1")
}

# Gate 1: no payload file → exit 2
if (cd "${tmpdir}" && bash "${GATE_RUN}" "lo-missing" 2>/dev/null); then
    echo "FAIL: missing payload should exit non-zero" >&2; exit 1
fi

# Gate 2: payload with no ## Acceptance gate section → exit 0 (pass through)
cat > "${tmpdir}/claude-arsenal/queue/lo-no-gate.md" <<'EOF'
# T1: No gate

## Tests
None.
EOF
if ! run_gate "lo-no-gate"; then
    echo "FAIL: no gate section should exit 0" >&2; exit 1
fi

# Gate 3: prose-only gate (no bash block) → exit 0
cat > "${tmpdir}/claude-arsenal/queue/lo-prose.md" <<'EOF'
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
cat > "${tmpdir}/claude-arsenal/queue/lo-pass.md" <<'EOF'
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
cat > "${tmpdir}/claude-arsenal/queue/lo-fail.md" <<'EOF'
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
cat > "${tmpdir}/claude-arsenal/queue/lo-multi.md" <<'EOF'
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
cat > "${tmpdir}/claude-arsenal/queue/lo-home.md" <<'EOF'
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

echo "PASS: gate_run_test — all gates passed"
exit 0
