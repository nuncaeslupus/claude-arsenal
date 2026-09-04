#!/usr/bin/env bash
# github_channel_status_test.sh — a permission failure and a transport failure
# are different answers (#342).
#
# The `gh` write path matched a bare `403|404` anywhere in gh's combined
# stdout+stderr, so an HTTP 500 whose body carried a `#404` doc link, or a
# connection reset with `403` inside a trace id, came back as `channel:none` —
# and `claim_task.sh` maps that to `manual`, sending a human after a token
# problem that does not exist while a real outage goes unreported.
#
# The existing github_channel_test.sh installs a `gh` stub that always fails
# `auth status`, so detection answers `rest` and the `gh` branch is never
# reached. This suite authenticates the stub, which is why the bug shipped.
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHANNEL="${SCRIPT_DIR}/../skills/init/assets/bin/github_channel.sh"

[[ -f "${CHANNEL}" ]] || { echo "SKIP: github_channel.sh not found" >&2; exit 0; }

fail() { echo "FAIL: $*" >&2; exit 1; }

tmp=$(mktemp -d)
cleanup() { rm -rf "${tmp}"; }
trap cleanup EXIT

mkdir -p "${tmp}/bin"
cat > "${tmp}/bin/gh" <<'STUB'
#!/usr/bin/env bash
# Authenticates, so the gh write branch is actually exercised; every api call
# fails with whatever GH_FAKE_OUT holds.
if [[ "${1:-} ${2:-}" == "auth status" ]]; then exit 0; fi
if [[ "${1:-}" == "api" ]]; then printf '%s\n' "${GH_FAKE_OUT}"; exit 1; fi
exit 0
STUB
chmod +x "${tmp}/bin/gh"
export PATH="${tmp}/bin:${PATH}"

_run() {  # $1 = fake gh output; echoes "rc|stdout"
    local out rc
    out="$(GH_FAKE_OUT="$1" bash "${CHANNEL}" --api POST /repos/o/r/git/refs \
        '{"ref":"refs/heads/x"}' 2>/dev/null)"
    rc=$?
    printf '%s|%s' "${rc}" "${out}"
}

# A real permission refusal: hand the call back (5 / channel:none).
res="$(_run 'gh: HTTP 403: Resource not accessible by integration (https://api.github.com/x)')"
[[ "${res%%|*}" -eq 5 ]] || fail "a real HTTP 403 exited ${res%%|*}, expected 5"
grep -q "channel:none" <<<"${res#*|}" || fail "a real HTTP 403 did not hand the call back"
echo "PASS: a real HTTP 403 is still a permission failure"

res="$(_run 'gh: HTTP 404: Not Found (https://api.github.com/y)')"
[[ "${res%%|*}" -eq 5 ]] || fail "a real HTTP 404 exited ${res%%|*}, expected 5"
echo "PASS: a real HTTP 404 is still a permission failure"

# A server error whose BODY mentions 404. This is an outage, not a token problem.
res="$(_run 'gh: HTTP 500: Internal Server Error (x) {"documentation_url":"https://docs.github.com/rest/git/refs#404"}')"
[[ "${res%%|*}" -eq 4 ]] || fail "an HTTP 500 with #404 in the body exited ${res%%|*}, expected 4"
grep -q "channel:none" <<<"${res#*|}" \
    && fail "an HTTP 500 was reported as a permission failure"
echo "PASS: an HTTP 500 whose body mentions 404 is an error, not a permission failure"

# A transport failure with 403 inside a trace id.
res="$(_run 'gh: error connecting to api.github.com: connection reset by peer; x-trace: ab403cd')"
[[ "${res%%|*}" -eq 4 ]] || fail "a connection reset exited ${res%%|*}, expected 4"
grep -q "channel:none" <<<"${res#*|}" \
    && fail "a connection reset was reported as a permission failure"
echo "PASS: a transport failure carrying '403' in a trace id is an error"

# A GET is unaffected: the hand-back is a write-path answer only.
out="$(GH_FAKE_OUT='gh: HTTP 403: Resource not accessible by integration (x)' \
    bash "${CHANNEL}" --api GET /repos/o/r 2>/dev/null)"; rc=$?
[[ "${rc}" -eq 4 ]] || fail "a GET returning 403 exited ${rc}, expected 4"
echo "PASS: a GET returning 403 is unchanged"

echo "PASS: github_channel_status_test — all gates passed"
exit 0
