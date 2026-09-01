#!/usr/bin/env bash
# arsenal_config_test.sh — the model settings, and the table they live in.
#
# Which model runs the orchestrator and which runs the workers used to be a
# model id written into vendored protocol prose, so a consumer who wanted a
# different one had to edit a file the next upgrade overwrites. They are now
# `[models]` in the host-owned arsenal/config.toml.
#
# A TOML table is the first one this config has carried, which brings two
# things worth a test: dotted-key reads (`models.workers`), and the fact that a
# bare key appended after a table header is read as a member OF that table.
# init.py appends `queue-automation` that way, so the workflow opt-out would
# have silently stopped working the moment a repo set a model.
#
# Exit: 0 PASS, 1 FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CFG="${SCRIPT_DIR}/../skills/init/assets/scripts/arsenal_config.py"
INIT="${SCRIPT_DIR}/../skills/init/scripts/init.py"

[[ -f "${CFG}" ]] || { echo "SKIP: arsenal_config.py not found at ${CFG}" >&2; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
cd "${tmp}" || exit 1
mkdir -p arsenal

fail() { echo "FAIL: $1" >&2; exit 1; }
get() { python3 "${CFG}" --repo-root . --get "$1" 2>/dev/null; }
get_rc() { python3 "${CFG}" --repo-root . --get "$1" >/dev/null 2>&1; echo $?; }

# --- defaults: a repo that has said nothing still dispatches somewhere sane ---
[[ "$(get models.workers)" == "sonnet" ]] || fail "default models.workers should be sonnet"
[[ -z "$(get models.orchestrator)" ]] || fail "default models.orchestrator should be empty"
echo "PASS: defaults — workers=sonnet, orchestrator unset"

# --- a [models] table reads as dotted keys ---
cat > arsenal/config.toml <<'TOML'
merge-policy = "after-ci"

[models]
orchestrator = "opus"
workers = "sonnet"
TOML
[[ "$(get models.orchestrator)" == "opus" ]] || fail "models.orchestrator should read 'opus'"
[[ "$(get models.workers)" == "sonnet" ]] || fail "models.workers should read 'sonnet'"
[[ "$(get merge-policy)" == "after-ci" ]] || fail "a table must not shadow top-level keys"
echo "PASS: [models] table → models.orchestrator / models.workers"

# --- a full model id is as valid as an alias: this is not a closed enum ---
printf '[models]\nworkers = "claude-sonnet-4-6"\n' > arsenal/config.toml
[[ "$(get models.workers)" == "claude-sonnet-4-6" ]] || fail "a full model id must be accepted"
echo "PASS: full model id accepted (aliases are not an enum)"

# --- garbage is loud: this value is exported into the environment ---
printf '[models]\nworkers = "sonnet; rm -rf /"\n' > arsenal/config.toml
[[ "$(get_rc models.workers)" == "2" ]] || fail "a non-model value should exit 2"
echo "PASS: non-model value → exit 2"

# --- empty workers would export an empty var and silently take the default ---
printf '[models]\nworkers = ""\n' > arsenal/config.toml
[[ "$(get_rc models.workers)" == "2" ]] || fail "empty models.workers should exit 2"
# ...while an empty orchestrator is the documented way to say "no opinion".
printf '[models]\norchestrator = ""\n' > arsenal/config.toml
[[ "$(get_rc models.orchestrator)" == "0" ]] || fail "empty models.orchestrator is valid"
echo "PASS: empty workers rejected, empty orchestrator allowed"

# --- init.py's key upsert must land above the first table header ---
if [[ -f "${INIT}" ]]; then
    cat > arsenal/config.toml <<'TOML'
merge-policy = "after-ci"

[models]
workers = "opus"
TOML
    python3 - "${INIT}" <<'PY'
import importlib.util, pathlib, sys
spec = importlib.util.spec_from_file_location("init_mod", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
mod._record_queue_automation(pathlib.Path("arsenal/config.toml"), "false")
PY
    [[ "$(get queue-automation)" == "False" ]] \
        || fail "queue-automation written after a [models] table was swallowed by it"
    [[ "$(get models.workers)" == "opus" ]] || fail "the upsert damaged the [models] table"
    echo "PASS: queue-automation upsert lands above [models], not inside it"
fi

# --- a boolean is not a positive integer (#265) -----------------------------
# `bool` subclasses `int` in Python, so `isinstance(True, int)` is True and
# `listing-budget = true` sailed through validation as the value `True` — which
# behaves as the number 1 downstream, capping the skills listing at one
# character instead of being refused as the wrong type.
cat > arsenal/config.toml <<'TOML'
merge-policy = "after-ci"
listing-budget = true
TOML
[[ "$(get_rc listing-budget)" == "2" ]] \
    || fail "listing-budget = true must be refused, not read as the number 1"
out=$(python3 "${CFG}" --repo-root . --get listing-budget 2>&1 || true)
grep -qi "positive integer" <<<"${out}" || fail "the refusal must say what is wrong: ${out}"

# ...and a real integer still works, so this is a type check and not a blanket
# refusal of the key.
cat > arsenal/config.toml <<'TOML'
merge-policy = "after-ci"
listing-budget = 12000
TOML
[[ "$(get listing-budget)" == "12000" ]] || fail "a positive integer budget must still be read"
echo "PASS: listing-budget rejects a boolean and still accepts an integer"

echo "PASS: arsenal_config_test — model settings and table handling"
exit 0
