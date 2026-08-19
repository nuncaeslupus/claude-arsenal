#!/usr/bin/env bash
# gate_run.sh <task_id>
# Runs the mechanical acceptance gate for a task, if one is defined.
#
# Reads claude-arsenal/queue/<task_id>.md — falling back to the coordination
# branch (`git show <default>:…`) when the file is not on disk, so a caller
# whose tree predates the payload's seeding commit (the orchestrator sitting on
# the default branch, a worker on an older base) never has to materialize one —
# and looks for the first ```bash (or ```sh) code block inside the
# ## Acceptance gate section. If found, executes it in the repo root; if absent
# (prose-only gate), nothing is executed.
#
# A GATE THAT RAN NOTHING IS NOT A PASS, and it no longer looks like one. The
# no-block case used to exit 0 in silence, indistinguishable from a real pass —
# and since a worker opens no PR when this script fails,
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
# and user-writable shim dirs are out of reach — except the directories holding
# the package manager / language runtime (pnpm, npm, node, uv, cargo …), which
# are re-admitted because they are commonly $HOME-installed and without them
# every `pnpm …` gate dies with exit 127 instead of running. This is NOT a
# sandbox. Set ARSENAL_GATE_INHERIT_ENV=1 to run with the caller's full
# environment for gates that genuinely need the real HOME (build caches,
# credentials).
#
# Exit: 0 gate passed, or nothing mechanical was defined (see the `gate:` line)
#       1 gate failed (command exited non-zero), or nothing ran under
#         ARSENAL_GATE_REQUIRE_BLOCK=1
#       2 usage/setup error — including "no payload on disk NOR on the
#         coordination ref", i.e. the task declares no gate at all
#       3 gate COULD NOT RUN (command/interpreter not found, 126/127). Distinct
#         from 1 so "the gate never executed" is never mistaken for a verdict.
#         Also printed loudly on stdout, so a caller that pipes this script's
#         output (`gate_run.sh <id> | tail`) — and thereby loses the exit status
#         to the pipeline — still sees that nothing was verified.

set -euo pipefail

TASK_ID="${1:-}"
if [[ -z "${TASK_ID}" ]]; then
    echo "Usage: gate_run.sh <task_id>" >&2
    exit 2
fi

PAYLOAD_TMP=""
# `return 0` matters: under `set -e` a non-zero status out of an EXIT trap
# becomes the script's exit status, which would report every clean run as failed.
cleanup() { [[ -n "${PAYLOAD_TMP}" ]] && rm -f "${PAYLOAD_TMP}"; return 0; }
trap cleanup EXIT

# The task file is ordinary versioned content on the default branch, so any
# worktree cut from there already has it. That is a direct consequence of tasks
# being repository files rather than rows on a coordination branch: the old code
# needed a `git show <branch>:…` fallback and a temp file outside the tree,
# because the payload only existed on a ref the worker was not on.
HOME_DIR="${ARSENAL_HOME:-arsenal}"
PAYLOAD="${HOME_DIR}/tasks/${TASK_ID}.md"

if [[ ! -f "${PAYLOAD}" ]]; then
    # Fall back to reading it from the default branch: a worktree cut from an
    # older base can predate the commit that added the task.
    REMOTE="${ARSENAL_QUEUE_REMOTE:-origin}"
    DEFAULT_BRANCH="${ARSENAL_DEFAULT_BRANCH:-}"
    if [[ -z "${DEFAULT_BRANCH}" ]]; then
        DEFAULT_BRANCH="$(git symbolic-ref --short "refs/remotes/${REMOTE}/HEAD" 2>/dev/null | sed "s#^${REMOTE}/##")"
    fi
    DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
    # Materialize OUTSIDE the repo tree: a file written inside it would be swept
    # into the feature branch by open_task_pr.sh's `git add -A`.
    PAYLOAD_TMP="$(mktemp -t "arsenal-task-${TASK_ID}-XXXXXX.md")"
    found=0
    for ref in "${REMOTE}/${DEFAULT_BRANCH}" "${DEFAULT_BRANCH}"; do
        if git show "${ref}:${HOME_DIR}/tasks/${TASK_ID}.md" >"${PAYLOAD_TMP}" 2>/dev/null; then
            echo "gate_run: task file read from ${ref} (not on disk)" >&2
            PAYLOAD="${PAYLOAD_TMP}"
            found=1
            break
        fi
    done
    if [[ ${found} -eq 0 ]]; then
        echo "gate_run: task file not found: ${HOME_DIR}/tasks/${TASK_ID}.md" >&2
        exit 2
    fi
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

python3 - "${PAYLOAD}" "${TASK_ID}" <<'PY'
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

payload = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
# Passed explicitly: the payload path is a temp file when it was resolved from
# the coordination ref, so its stem is not the task id.
task_id = sys.argv[2]

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
        sys.exit(0)
    if rc in (126, 127):
        # The gate never executed — a missing/non-executable command, not a
        # verdict on the work. Say so on BOTH streams: a caller piping this
        # script's stdout keeps the message even when the pipeline eats the
        # exit status, which is how a never-run gate came to read as a pass.
        msg = (
            f"gate_run: {task_id} — GATE COULD NOT RUN (exit {rc}: command not found "
            "or not executable). This is NOT a pass — nothing was verified. If the "
            "gate needs a $HOME-installed tool the hardened PATH does not carry, run "
            "with ARSENAL_GATE_INHERIT_ENV=1."
        )
        print(msg, flush=True)
        print(msg, file=sys.stderr)
        sys.exit(3)
    sys.exit(1)


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

# Re-admit the directories holding the project's package manager / language
# runtime. These are routinely installed under $HOME (nvm, corepack, volta,
# asdf, pyenv, uv, rustup), so stripping $HOME wholesale leaves `pnpm test` and
# friends with exit 127 — a gate that CANNOT RUN, which is worse than an
# unhardened one: it verifies nothing, and every caller has to work around it
# with ARSENAL_GATE_INHERIT_ENV=1, which hands the gate the *entire* real
# HOME/PATH. Admitting just these dirs keeps the rest of $HOME off PATH, and
# HOME itself stays a throwaway.
for tool in ("pnpm", "npm", "yarn", "bun", "node", "corepack", "uv", "poetry", "cargo"):
    found = shutil.which(tool, path=os.environ.get("PATH", ""))
    tool_dir = os.path.dirname(os.path.abspath(found)) if found else None
    if tool_dir and tool_dir not in safe_path.split(os.pathsep):
        safe_path = f"{tool_dir}{os.pathsep}{safe_path}" if safe_path else tool_dir

with tempfile.TemporaryDirectory(prefix="arsenal-gate-home-") as gate_home:
    env = {
        "PATH": safe_path,
        "HOME": gate_home,
        "PWD": os.getcwd(),
        "LANG": os.environ.get("LANG", "C.UTF-8"),
        "LC_ALL": os.environ.get("LC_ALL", "C.UTF-8"),
        "TERM": os.environ.get("TERM", "dumb"),
    }
    # A repo pinning "packageManager" makes corepack resolve that version out of
    # its own cache; keyed to HOME, a throwaway one re-downloads the package
    # manager on every gate run and fails outright offline. Point it at the real
    # cache — a package cache, not a credential store.
    corepack_home = os.environ.get("COREPACK_HOME") or os.path.join(
        real_home, ".cache", "node", "corepack"
    )
    if os.path.isdir(corepack_home):
        env["COREPACK_HOME"] = corepack_home
    rc = _run(env)
_finish(rc)
PY
