#!/usr/bin/env bash
#
# Pre-commit driver for skill-validate.
#
# pre-commit passes each staged file under plugins/*/skills/*/** as an
# argument. This script derives the unique skill roots (depth-3 under
# plugins/) and invokes validate.py once per root, failing fast on the
# first non-zero exit.
#
# Usage:
#   precommit_validate.sh <file1> [<file2> ...]

set -euo pipefail

if [[ "$#" -eq 0 ]]; then
    exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"
VALIDATE="$REPO_ROOT/plugins/skill-creator/skills/skill-creator/scripts/validate.py"

declare -A SEEN=()
ROOTS=()

for path in "$@"; do
    # Expected shape: plugins/<plugin>/skills/<skill>/...
    if [[ "$path" =~ ^plugins/([^/]+)/skills/([^/]+) ]]; then
        root="plugins/${BASH_REMATCH[1]}/skills/${BASH_REMATCH[2]}"
        if [[ -z "${SEEN[$root]:-}" ]]; then
            SEEN[$root]=1
            ROOTS+=("$root")
        fi
    fi
done

if [[ "${#ROOTS[@]}" -eq 0 ]]; then
    exit 0
fi

for root in "${ROOTS[@]}"; do
    echo "=== validate: $root ==="
    uv run python "$VALIDATE" "$REPO_ROOT/$root"
done
