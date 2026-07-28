#!/usr/bin/env bash
# gate_run.sh <task_id>
# Runs the mechanical acceptance gate for a task, if one is defined.
#
# Reads claude-arsenal/queue/<task_id>.md and looks for the first ```bash (or
# ```sh) code block inside the ## Acceptance gate section. If found, executes
# it in the repo root; if absent (prose-only gate), nothing is executed.
#
# A GATE THAT RAN NOTHING IS NOT A PASS, and it no longer looks like one. The
# no-block case used to exit 0 in silence, indistinguishable from a real pass —
# and since release.sh re-runs this script as its hard precondition for `done`,
# a repo whose payloads all write gates as prose (or as inline single-backtick
# commands, which the fence regex does not match) had an inert gate layer for
# every task without a word of warning. One consumer audit found 0 of 70
# payloads carrying a fenced block. Every outcome is now announced on stdout as
# a `gate:` line and, when nothing ran, warned about on stderr:
#
#   gate: passed      a block was found and it exited 0
#   gate: prose-only  an ## Acceptance gate section exists with no fenced block
#   gate: none        no ## Acceptance gate section at all
#
# Set ARSENAL_GATE_REQUIRE_BLOCK=1 to make the two nothing-ran outcomes a hard
# failure (exit 1) — the right setting for a repo that intends every task to
# carry a mechanical gate.
#
# SECURITY: the gate block runs VERBATIM in the caller's working tree — it is
# code, not data. A plan/payload an attacker can influence is therefore
# RCE-from-data; review gate blocks before running. To limit the blast radius
# the gate runs under a throwaway HOME and a PATH stripped of $HOME-local shims
# by default, so $HOME-keyed secrets (~/.ssh, ~/.aws, ~/.netrc, ~/.config/gh)
# and user-writable shim dirs are out of reach. This is NOT a sandbox. Set
# ARSENAL_GATE_INHERIT_ENV=1 to run with the caller's full environment for
# gates that genuinely need the real HOME/PATH (caches, pyenv/cargo shims).
#
# Exit: 0 gate passed, or nothing mechanical was defined (see the `gate:` line)
#       1 gate failed (command exited non-zero), or nothing ran under
#         ARSENAL_GATE_REQUIRE_BLOCK=1
#       2 usage/setup error

set -euo pipefail

TASK_ID="${1:-}"
if [[ -z "${TASK_ID}" ]]; then
    echo "Usage: gate_run.sh <task_id>" >&2
    exit 2
fi

PAYLOAD="claude-arsenal/queue/${TASK_ID}.md"
if [[ ! -f "${PAYLOAD}" ]]; then
    echo "gate_run: payload not found: ${PAYLOAD}" >&2
    exit 2
fi

# Enforce a structured numeric evidence gate first, if the payload declares one.
# A declared evidence gate can never pass vacuously (CA-12): a missing evidence
# file or a measurement that violates the threshold fails the gate right here,
# before the prose/bash-block path can let it through.
GATE_EVIDENCE_PY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../scripts/gate_evidence.py"
if [[ -f "${GATE_EVIDENCE_PY}" ]] && ! python3 "${GATE_EVIDENCE_PY}" "${PAYLOAD}"; then
    echo "gate_run: evidence gate failed for ${TASK_ID}" >&2
    exit 1
fi

python3 - "${PAYLOAD}" <<'PY'
import os
import pathlib
import re
import subprocess
import sys
import tempfile

payload_path = pathlib.Path(sys.argv[1])
payload = payload_path.read_text(encoding="utf-8")
task_id = payload_path.stem

# `strict` turns "nothing executable was found" into a hard failure, for repos
# that intend every task to carry a mechanical gate.
strict = os.environ.get("ARSENAL_GATE_REQUIRE_BLOCK", "") not in ("", "0", "false")


def nothing_ran(kind, detail):
    """Announce that no command was executed. Never silent: this is the state
    that used to be indistinguishable from a real pass."""
    print(f"gate: {kind}")
    print(
        f"gate_run: {task_id} — NOTHING WAS EXECUTED ({detail}). "
        "This is not a mechanical pass; whatever verification happened was a human's "
        "or an agent's judgment, not this gate's.",
        file=sys.stderr,
    )
    if strict:
        print(
            "gate_run: ARSENAL_GATE_REQUIRE_BLOCK=1 — failing because the payload "
            "defines no runnable ```bash block under '## Acceptance gate'.",
            file=sys.stderr,
        )
        sys.exit(1)
    sys.exit(0)


# Extract ## Acceptance gate section (up to next ## heading or EOF).
section_match = re.search(
    r'##\s+Acceptance gate\s*\n(.*?)(?=\n##\s|\Z)', payload, re.DOTALL | re.IGNORECASE
)
if not section_match:
    nothing_ran("none", "the payload has no '## Acceptance gate' section")

section = section_match.group(1)

# Find first ```bash or ```sh code block inside the section. An inline
# single-backtick command does NOT match and never has — that is the most
# common way a gate ends up inert, so name it in the message.
block_match = re.search(r'```(?:bash|sh)\s*\n(.*?)```', section, re.DOTALL)
if not block_match:
    nothing_ran(
        "prose-only",
        "the '## Acceptance gate' section has no fenced ```bash/```sh block — "
        "prose and inline `single-backtick` commands are not executed",
    )

cmd = block_match.group(1).strip().replace('\r', '')
if not cmd:
    nothing_ran("prose-only", "the fenced gate block is empty")

script = "#!/usr/bin/env bash\nset -euo pipefail\n" + cmd + "\n"


def _run(env):
    # Pipe the script to `bash -s` over stdin: nothing is ever written to a
    # persisted temp file, so a hard kill leaves no orphaned 0700 script behind.
    return subprocess.run(["bash", "-s"], input=script, text=True, env=env).returncode


def _finish(rc):
    if rc == 0:
        print("gate: passed")
    sys.exit(1 if rc != 0 else 0)


inherit = os.environ.get("ARSENAL_GATE_INHERIT_ENV", "") not in ("", "0", "false")
if inherit:
    _finish(_run(None))

# Hardened-by-default environment: throwaway HOME + PATH with $HOME-local shim
# dirs stripped. Keeps system + non-home tooling on PATH so common gates still
# resolve `python3`/`make`/etc., while removing user-writable shim dirs and
# $HOME-keyed credential lookups from the gate's reach.
real_home = os.path.abspath(os.path.expanduser("~"))


def _under_home(d):
    # A directory IS the home dir, or sits beneath it. Guard against HOME="/"
    # (minimal/root containers), where everything would otherwise count as
    # "under home" and the whole inherited PATH would be dropped.
    if real_home == os.sep:
        return False
    ad = os.path.abspath(d)
    return ad == real_home or ad.startswith(real_home + os.sep)


safe_path = os.pathsep.join(
    d for d in os.environ.get("PATH", "").split(os.pathsep) if d and not _under_home(d)
)
for system_dir in ("/usr/local/sbin", "/usr/local/bin", "/usr/sbin", "/usr/bin", "/sbin", "/bin"):
    if system_dir not in safe_path.split(os.pathsep):
        safe_path = f"{safe_path}{os.pathsep}{system_dir}" if safe_path else system_dir

with tempfile.TemporaryDirectory(prefix="arsenal-gate-home-") as gate_home:
    env = {
        "PATH": safe_path,
        "HOME": gate_home,
        "PWD": os.getcwd(),
        "LANG": os.environ.get("LANG", "C.UTF-8"),
        "LC_ALL": os.environ.get("LC_ALL", "C.UTF-8"),
        "TERM": os.environ.get("TERM", "dumb"),
    }
    rc = _run(env)
_finish(rc)
PY
