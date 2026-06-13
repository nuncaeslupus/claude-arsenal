#!/usr/bin/env bash
# gate_run.sh <task_id>
# Runs the mechanical acceptance gate for a task, if one is defined.
#
# Reads .loop/state/tasks/<task_id>.md and looks for the first ```bash (or
# ```sh) code block inside the ## Acceptance gate section. If found, executes
# it in the repo root; if absent (prose-only gate), exits 0 immediately.
#
# Exit: 0 gate passed or no mechanical gate defined
#       1 gate failed (command exited non-zero)
#       2 usage/setup error

set -euo pipefail

TASK_ID="${1:-}"
if [[ -z "${TASK_ID}" ]]; then
    echo "Usage: gate_run.sh <task_id>" >&2
    exit 2
fi

PAYLOAD=".loop/state/tasks/${TASK_ID}.md"
if [[ ! -f "${PAYLOAD}" ]]; then
    echo "gate_run: payload not found: ${PAYLOAD}" >&2
    exit 2
fi

python3 - "${PAYLOAD}" <<'PY'
import sys, re, subprocess, tempfile, os, pathlib

payload = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")

# Extract ## Acceptance gate section (up to next ## heading or EOF).
section_match = re.search(
    r'##\s+Acceptance gate\s*\n(.*?)(?=\n##\s|\Z)', payload, re.DOTALL | re.IGNORECASE
)
if not section_match:
    sys.exit(0)  # no gate section — nothing to run

section = section_match.group(1)

# Find first ```bash or ```sh code block inside the section.
block_match = re.search(r'```(?:bash|sh)\n(.*?)```', section, re.DOTALL)
if not block_match:
    sys.exit(0)  # prose-only gate — deferred to worker judgment

cmd = block_match.group(1).strip()
if not cmd:
    sys.exit(0)

with tempfile.NamedTemporaryFile(mode='w', suffix='.sh', delete=False) as f:
    f.write('#!/usr/bin/env bash\nset -euo pipefail\n')
    f.write(cmd + '\n')
    tmp = f.name

try:
    os.chmod(tmp, 0o700)
    result = subprocess.run(['bash', tmp])
    sys.exit(result.returncode)
finally:
    os.unlink(tmp)
PY
