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

# --- 1b: every key is registered with a version and a description ----------
#     The session-start notice (#496) tells a downstream repo about a key a
#     release added. It can only do that for a key that says which release that
#     was and what it does — a key without either is announced as nothing, and
#     sits at its default everywhere until someone reads the changelog.
problems=$(cd "${REPO_ROOT}" && python3 - 2>&1 <<'PY'
import sys
sys.path.insert(0, "plugins/core/skills/init/assets/scripts")
import arsenal_config as cfg

problems = []
for key, entry in cfg.SETTINGS.items():
    if not isinstance(entry, cfg.Setting):
        problems.append(f"{key}: not a Setting(default, since, description)")
        continue
    if not isinstance(entry.since, str) or not cfg.VERSION_REGEX.match(entry.since):
        problems.append(f"{key}: since must be a version like 5.7.0, got {entry.since!r}")
    desc = entry.description
    if not isinstance(desc, str) or not desc.strip():
        problems.append(f"{key}: no description, so its NEW SETTING line would say nothing")
    elif "\n" in desc or len(desc) > 110:
        problems.append(f"{key}: the description must be one short line (it is printed per session)")
if set(cfg.DEFAULTS) != set(cfg.SETTINGS):
    problems.append("DEFAULTS is not derived from SETTINGS")
print("\n".join(problems))
PY
)
probe=$?
[[ ${probe} -eq 0 ]] || fail "the registry probe itself failed (exit ${probe}):
${problems}"
[[ -z "${problems}" ]] || fail "registry entries missing a version or description:
${problems}"
echo "PASS: every config key carries since and a one-line description"

# --- 1c: the session-start notice is derived from the registry --------------
#     A key newer than config-acknowledged and unset in the file is announced,
#     once per session, until the host sets it or acknowledges its version.
notice_dir=$(mktemp -d)
mkdir -p "${notice_dir}/arsenal"
notice() {  # notice <config.toml body> — prints the NEW SETTING lines
    printf '%b' "$1" > "${notice_dir}/arsenal/config.toml"
    (cd "${REPO_ROOT}" && python3 - "${notice_dir}" <<'PY'
import sys
from pathlib import Path
sys.path.insert(0, "plugins/core/skills/init/assets/scripts")
import arsenal_config as cfg
cfg.SETTINGS["probe-key"] = cfg.Setting(3, "9.1.0", "A key a future release adds.")
cfg.DEFAULTS["probe-key"] = 3
print("\n".join(cfg.new_settings(Path(sys.argv[1]))))
PY
)
}
out=$(notice '')
grep -q '^NEW SETTING probe-key (since v9.1.0, default 3): A key a future release adds.$' <<<"${out}" \
    || fail "an unset key newer than the host's acknowledged version must be announced:
${out}"
grep -q 'config-acknowledged = "9.1.0"' <<<"${out}" || fail "the notice must name how to acknowledge:
${out}"
grep -q 'NEW SETTING merge-policy' <<<"${out}" \
    && fail "a key from the baseline must not be announced to a host that predates the registry"
notice 'probe-key = 4\n' | grep >/dev/null 'probe-key' && fail "a key the host set is not new to it"
[[ -z "$(notice 'config-acknowledged = "9.1.0"\n')" ]] || fail "an acknowledged version silences its keys"
[[ -n "$(notice 'config-acknowledged = "9.0.9"\n')" ]] || fail "acknowledging an older version must not silence a newer key"
out=$(notice 'config-acknowledged = "soon"\n')
[[ -z "${out}" ]] || fail "an invalid file prints no notice (the loader reports it): ${out}"
printf 'config-acknowledged = "soon"\n' > "${notice_dir}/arsenal/config.toml"
(cd "${notice_dir}" && python3 "${CONFIG_PY}" --get merge-policy >/dev/null 2>&1); code=$?
[[ ${code} -eq 2 ]] || fail "config-acknowledged that is not a version must exit 2, got ${code}"
rm -rf "${notice_dir}"
echo "PASS: NEW SETTING lines come from the registry and stop once acknowledged"

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
