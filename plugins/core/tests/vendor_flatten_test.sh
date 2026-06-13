#!/usr/bin/env bash
# vendor_flatten_test.sh — guards the Claude Code web path: when the init skill
# is flattened into a consumer's .claude/skills/ (no plugins/ tree, no
# --bundle-dir override), init.py must still find its bundle via assets/ and
# bootstrap claude-arsenal/.
# Exit: 0 on PASS, 1 on FAIL.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
VENDOR="${REPO}/scripts/vendor-skills.sh"

if [[ ! -f "${VENDOR}" ]]; then
    echo "SKIP: vendor-skills.sh not found at ${VENDOR}" >&2
    exit 0
fi

tmpdir=$(mktemp -d)
cleanup() { cd "${REPO}"; rm -rf "${tmpdir}"; }
trap cleanup EXIT

# Flatten core skills the way a consumer would for Claude Code web.
# Keep stderr visible so a vendor failure surfaces in CI logs.
bash "${VENDOR}" --src "${REPO}" --dest "${tmpdir}/.claude/skills" --plugins core >/dev/null

# Gate 1: the init skill carries its bundle along (assets/ rode with the copy).
if [[ ! -f "${tmpdir}/.claude/skills/init/assets/bin/queue_eval.sh" ]]; then
    echo "FAIL: flattened init skill is missing assets/bin/queue_eval.sh" >&2; exit 1
fi

# Gate 2: run the flattened init.py with NO --bundle-dir override — it must
# resolve the bundle relative to its own location.
cd "${tmpdir}"
echo "# Test repo" > CLAUDE.md
python3 .claude/skills/init/scripts/init.py --repo-path "${tmpdir}" >/dev/null

# Gate 3: claude-arsenal/ was bootstrapped from the flattened bundle.
for f in claude-arsenal/bin/queue_eval.sh claude-arsenal/AGENTS.md \
         claude-arsenal/queue/tasks.jsonl claude-arsenal/session/handover.md; do
    if [[ ! -e "${tmpdir}/${f}" ]]; then
        echo "FAIL: flattened init did not create ${f}" >&2; exit 1
    fi
done

# Gate 4: CLAUDE.md got the session-protocol marker.
if ! grep -qF "<!-- claude-arsenal: auto-managed -->" "${tmpdir}/CLAUDE.md"; then
    echo "FAIL: session-protocol marker missing from CLAUDE.md" >&2; exit 1
fi

echo "PASS: vendor_flatten_test — all gates passed"
exit 0
