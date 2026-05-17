#!/usr/bin/env bash
#
# Mechanical smoke test for the skill library.
#
# Runs audit_library.py over each discovered plugin's skill library:
#   - plugins/<plugin>/skills/ (auto-discovered)
#
# Each per-library audit invokes validate.py for every skill inside,
# plus library-level checks (overlap, canary uniqueness, listing
# budget, duplicate-group SHAs). Exits non-zero if any library
# reports a blocking issue.
#
# The cross-library aggregate budget is NOT enforced here — that
# check is owned by release-readiness and is invoked with the
# multi-path form of audit_library.py.
#
# Live-session probes (load_prompts / no_load_prompts from each
# skill's evals/loading_verification.json) are a deferred extension
# described in references/validation-and-evals.md; not implemented
# in this harness.
#
# Usage:
#   bash plugins/skill-creator/skills/skill-creator/tests/skills_smoke.sh
#   bash plugins/skill-creator/skills/skill-creator/tests/skills_smoke.sh --severity warn

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
AUDIT="$REPO_ROOT/plugins/skill-creator/skills/skill-creator/scripts/audit_library.py"

if [[ ! -f "$AUDIT" ]]; then
    echo "skills_smoke: audit_library.py not found at $AUDIT" >&2
    exit 2
fi

# Prefer `uv run python` so the script sees the locked dependency set
# (pyyaml is required by audit_library / validate). Fall back to bare
# python3 for environments without uv.
if command -v uv >/dev/null 2>&1; then
    PY_RUN=("uv" "run" "python")
else
    PY_RUN=("python3")
fi

LIBRARIES=()
shopt -s nullglob
for plugin_skills in "$REPO_ROOT"/plugins/*/skills; do
    [[ -d "$plugin_skills" ]] && LIBRARIES+=("$plugin_skills")
done
shopt -u nullglob

if [[ "${#LIBRARIES[@]}" -eq 0 ]]; then
    echo "skills_smoke: no skill libraries discovered" >&2
    exit 2
fi

overall=0
for lib in "${LIBRARIES[@]}"; do
    echo "=== audit: ${lib#$REPO_ROOT/} ==="
    "${PY_RUN[@]}" "$AUDIT" "$lib" "$@" || overall=1
done

if [[ "$overall" -eq 0 ]]; then
    echo "=== skills_smoke: clean ==="
else
    echo "=== skills_smoke: FAIL (one or more libraries reported issues) ===" >&2
fi
exit "$overall"
