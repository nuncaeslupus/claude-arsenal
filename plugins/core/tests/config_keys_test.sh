#!/usr/bin/env bash
# config_keys_test.sh — every config key has something that reads it.
#
# arsenal_config.py scaffolded, validated and explained six keys that no
# consumer read. Each one round-tripped through `--explain` and changed
# nothing. The worst was `import-label`: AGENTS.md, resident in every session,
# documented it as what changes the import label, so a consumer who set it
# imported no issues and was told nothing.
#
# A key is a promise. This asserts every one in DEFAULTS names the file that
# keeps it, and that the file still mentions the key — so wiring a new key is
# part of adding it, not a discovery months later.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
CONFIG_PY="${REPO_ROOT}/plugins/core/skills/init/assets/scripts/arsenal_config.py"
[[ -f "${CONFIG_PY}" ]] || { echo "FAIL: ${CONFIG_PY} not found" >&2; exit 1; }

fail() { echo "FAIL: $1" >&2; exit 1; }

# --- 1: READERS covers DEFAULTS, and each named file names its key ----------
# stderr is folded in and the exit code checked: a traceback out of the probe
# below is not "no problems found".
problems=$(cd "${REPO_ROOT}" && python3 - 2>&1 <<'PY'
import sys
from pathlib import Path

sys.path.insert(0, "plugins/core/skills/init/assets/scripts")
import arsenal_config as cfg

problems = []
for key in cfg.DEFAULTS:
    if key not in cfg.READERS:
        problems.append(f"{key}: no entry in READERS — name the file that reads it, or drop the key")
        continue
    reader = cfg.READERS[key]
    if reader is None:
        # Deliberately unreadable from the file; FILE_ONLY_REJECTS covers it.
        if key not in cfg.FILE_ONLY_REJECTS:
            problems.append(f"{key}: READERS says None but FILE_ONLY_REJECTS does not refuse it in the file")
        continue
    path = Path(reader)
    if not path.is_file():
        problems.append(f"{key}: READERS points at {reader}, which does not exist")
    else:
        # A dotted key names a value inside a TOML table, and a table is read as
        # a table — the leaf is what the reader knows.
        needle = key.rsplit(".", 1)[-1] if "." in key else key
        if needle not in path.read_text(encoding="utf-8"):
            problems.append(f"{key}: {reader} no longer mentions it — the reader moved or went away")

for key in cfg.READERS:
    if key not in cfg.DEFAULTS:
        problems.append(f"{key}: in READERS but not in DEFAULTS")
print("\n".join(problems))
PY
)
probe=$?
[[ ${probe} -eq 0 ]] || fail "the reader probe itself failed (exit ${probe}):
${problems}"
[[ -z "${problems}" ]] || fail "config keys without a reader:
${problems}"
echo "PASS: every config key names the file that reads it"

# --- 2: the three that were dead now actually change behaviour --------------
tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
mkdir -p "${tmp}/arsenal"
cat > "${tmp}/arsenal/config.toml" <<'TOML'
import-label = "team:inbox"
task-label = "team:task"
claim-prefix = "team/locks"
TOML

read_key() {  # read_key <module> <constant>
    (cd "${tmp}" && python3 -c "
import sys; sys.path.insert(0, '${REPO_ROOT}/plugins/core/skills/init/assets/scripts')
import $1
print($1.$2)")
}
[[ "$(read_key issue_import DEFAULT_IMPORT_LABEL)" == "team:inbox" ]] \
    || fail "import-label is set in the config and issue_import.py still imports on the shipped default"
[[ "$(read_key queue_hooks TASK_LABEL)" == "team:task" ]] \
    || fail "task-label is set in the config and queue_hooks.py still uses the shipped default"
[[ "$(read_key queue_hooks DEFAULT_CLAIM_PREFIX)" == "team/locks" ]] \
    || fail "claim-prefix is set in the config and queue_hooks.py still uses the shipped default"

# ...and claim_task.sh, which writes the refs queue_hooks.py prunes, agrees.
prefix=$(cd "${tmp}" && python3 "${CONFIG_PY}" --get claim-prefix)
[[ "${prefix}" == "team/locks" ]] || fail "--get claim-prefix returned '${prefix}'"
grep -q 'arsenal_config.py" --get claim-prefix' "${REPO_ROOT}/plugins/core/skills/init/assets/bin/claim_task.sh" \
    || fail "claim_task.sh does not consult the config, so it can write refs queue_hooks.py will not prune"
echo "PASS: import-label, task-label and claim-prefix change what runs"

# --- 2b: review-bots reaches the loop that waits on them --------------------
#     The three bots were a hardcoded constant, so a repo watching a different
#     reviewer — or none — could only say so by passing --watch-bots at every
#     call. The flag still wins, and an empty one still means CI-only: that is
#     the distinction the resolver has to keep, so it is the one checked here.
PR_STATE="${REPO_ROOT}/plugins/core/skills/github/scripts/query_pr_state.py"
printf 'review-bots = ["reviewer[bot]"]\n' > "${tmp}/arsenal/config.toml"

resolve() {  # resolve <python expression for the flag argument>
    (cd "${tmp}" && python3 -c "
import sys; sys.path.insert(0, '$(dirname "${PR_STATE}")')
import query_pr_state as q
print(','.join(q._resolve_watch_bots($1)))")
}
[[ "$(resolve None)" == "reviewer[bot]" ]] \
    || fail "review-bots is set in the config and query_pr_state.py still watches the shipped bots"
[[ "$(resolve "'other[bot]'")" == "other[bot]" ]] \
    || fail "--watch-bots no longer overrides the configured list"
[[ -z "$(resolve "''")" ]] \
    || fail "an empty --watch-bots must stay distinguishable from an absent one (CI-only mode)"

printf 'review-bots = []\n' > "${tmp}/arsenal/config.toml"
[[ -z "$(resolve None)" ]] \
    || fail "review-bots = [] must mean 'no review bot here', not 'use the defaults'"
echo "PASS: review-bots is configurable and an empty list means CI-only"

# --- 3: a key that cannot work from the file is refused, not ignored --------
#     `home` names the directory holding config.toml, so the file cannot set
#     it. Accepting it looked like it worked and relocated nothing.
printf 'home = "host"\n' > "${tmp}/arsenal/config.toml"
out=$( (cd "${tmp}" && python3 "${CONFIG_PY}" --get merge-policy) 2>&1 ); code=$?
[[ "${code}" -ne 0 ]] || fail "'home' in the config file was accepted: ${out}"
grep -q "ARSENAL_HOME" <<<"${out}" || fail "the refusal must name the channel that works: ${out}"
echo "PASS: 'home' in the file is refused and points at ARSENAL_HOME"

echo "PASS: config_keys_test — all gates passed"
