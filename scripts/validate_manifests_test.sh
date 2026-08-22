#!/usr/bin/env bash
# validate_manifests_test.sh — unit test for scripts/validate_manifests.py.
# Builds fake plugin trees under a temp --repo-root and verifies that the exact
# shape v1.0.0 shipped (author as a bare string) is rejected, that the correct
# object form passes, and that a manifest naming the wrong directory is caught.
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="${SCRIPT_DIR}/validate_manifests.py"

if [[ ! -f "${VALIDATE}" ]]; then
    echo "SKIP: validate_manifests.py not found at ${VALIDATE}" >&2; exit 0
fi

tmp=$(mktemp -d)
cleanup() { rm -rf "${tmp}"; }
trap cleanup EXIT

fails=0
check() {  # check <label> <expected-exit> <actual-exit>
    if [[ "$2" == "$3" ]]; then echo "  PASS: $1"; else echo "  FAIL: $1 (expected exit $2, got $3)"; fails=$((fails + 1)); fi
}

write_plugin() {  # write_plugin <root> <dir> <json>
    mkdir -p "$1/plugins/$2/.claude-plugin"
    printf '%s\n' "$3" > "$1/plugins/$2/.claude-plugin/plugin.json"
}

# 1. the regression: author as a bare string, exactly as v1.0.0 shipped it
root="${tmp}/bad"
write_plugin "${root}" core '{"name":"core","version":"1.0.0","author":"nuncaeslupus"}'
python3 "${VALIDATE}" --repo-root "${root}" --quiet
check "a bare-string author is rejected" 1 $?

# Captured rather than piped: `pipefail` is on, so a pipeline would inherit the
# validator's exit 1 and the grep's verdict would never be read.
message=$(python3 "${VALIDATE}" --repo-root "${root}" 2>&1 || true)
grep -q "author: expected object, received str" <<< "${message}"
check "the message names the shape that was wrong" 0 $?

# 2. the correct form passes
root="${tmp}/good"
write_plugin "${root}" core '{"name":"core","version":"1.0.0","author":{"name":"nuncaeslupus"}}'
write_plugin "${root}" skill-workshop '{"name":"skill-workshop","version":"1.0.0","author":{"name":"nuncaeslupus"}}'
python3 "${VALIDATE}" --repo-root "${root}" --quiet
check "object author with a name passes" 0 $?

# 3. an author object with no usable name is not a pass
root="${tmp}/empty-name"
write_plugin "${root}" core '{"name":"core","author":{"email":"x@example.com"}}'
python3 "${VALIDATE}" --repo-root "${root}" --quiet
check "an author object without a name is rejected" 1 $?

# 4. a manifest naming a different directory than it lives in
root="${tmp}/misnamed"
write_plugin "${root}" core '{"name":"kore","version":"1.0.0","author":{"name":"n"}}'
python3 "${VALIDATE}" --repo-root "${root}" --quiet
check "a manifest naming the wrong directory is rejected" 1 $?

# 5. a non-semver version
root="${tmp}/badver"
write_plugin "${root}" core '{"name":"core","version":"1.0","author":{"name":"n"}}'
python3 "${VALIDATE}" --repo-root "${root}" --quiet
check "a non-semver version is rejected" 1 $?

# 6. no manifests at all is a failure, not a vacuous pass
python3 "${VALIDATE}" --repo-root "${tmp}/nothing-here" --quiet
check "an empty tree fails rather than passing vacuously" 1 $?

# 7. the real repository passes
python3 "${VALIDATE}" --repo-root "${SCRIPT_DIR}/.." --quiet
check "this repository's own manifests are valid" 0 $?

if [[ ${fails} -eq 0 ]]; then echo "PASS: validate_manifests_test.sh"; exit 0; fi
echo "FAIL: validate_manifests_test.sh (${fails} failure(s))"; exit 1
