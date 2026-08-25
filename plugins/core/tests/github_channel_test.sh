#!/usr/bin/env bash
# github_channel_test.sh — a channel that may read but not write is not a fault.
#
# On Claude Code on the web the REST probe (GET /rate_limit) answers 200 while a
# ref creation is refused 403 by the proxy. That made `detect` say `rest`, so the
# `none` branch never ran and the `manual` fallback — written for exactly this
# surface — was unreachable. claim_task.sh then exited 2 (`error:`), which
# AGENTS.md tells the orchestrator to stop the whole loop over.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${SCRIPT_DIR}/../skills/init/assets/bin"
[[ -f "${SRC}/github_channel.sh" ]] || { echo "SKIP: github_channel.sh not found" >&2; exit 0; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

BIN="${tmp}/bin"; mkdir -p "${BIN}"
cp "${SRC}/github_channel.sh" "${SRC}/claim_task.sh" "${BIN}/"

# A `gh` that is present but not authenticated. PATH below keeps /usr/bin — a
# developer machine has a real, logged-in `gh` there, so `detect` answered `gh`
# and none of the REST cases below ran. The suite passed in CI, where there is
# no such `gh`, and failed on the machine writing the code.
cat > "${BIN}/gh" <<'EOF'
#!/usr/bin/env bash
[[ "$1 $2" == "auth status" ]] && exit 1
exit 1
EOF
chmod +x "${BIN}/gh"

# A curl stub standing in for the proxy: 200 on the read probe, 403 on any
# write, and it records the Content-Type it was handed.
cat > "${BIN}/curl" <<'EOF'
#!/usr/bin/env bash
out=""; method="GET"; url=""; ctype=""
args=("$@")
for i in "${!args[@]}"; do
    case "${args[$i]}" in
        -o) out="${args[$((i+1))]}" ;;
        -X) method="${args[$((i+1))]}" ;;
        -H) [[ "${args[$((i+1))]}" == Content-Type:* ]] && ctype="${args[$((i+1))]}" ;;
        https://*) url="${args[$i]}" ;;
    esac
done
[[ -n "${ctype}" ]] && echo "${ctype}" >> "${CURL_LOG:-/dev/null}"
if [[ "${url}" == *"/user" || "${url}" == *"/rate_limit" ]]; then
    [[ -n "${out}" ]] && echo '{"ok":true}' > "${out}"
    printf '200'; exit 0
fi
[[ -n "${out}" ]] && echo '{"message":"Write access to this GitHub API path is not permitted through this proxy."}' > "${out}"
printf '403'; exit 0
EOF
chmod +x "${BIN}/curl"

REPO="${tmp}/repo"; mkdir -p "${REPO}"
cd "${REPO}"
git init -q -b main .
git config user.email t@e.x; git config user.name T; git config commit.gpgsign false
git commit -q --allow-empty -m init
git remote add origin https://github.com/o/r.git

# `gh` must not be picked up from the real environment; PATH is stubbed so the
# detector sees only our curl.
export PATH="${BIN}:/usr/bin:/bin"
export GITHUB_TOKEN=fake
export CURL_LOG="${tmp}/ctype.log"

# --- 1: the read probe still reports a reachable channel ---
[[ "$(bash "${BIN}/github_channel.sh" --detect)" == "rest" ]] \
    || fail "a 200 on the read probe should still detect 'rest'"

# --- 2: a refused WRITE hands the call back instead of reporting a fault ---
out=$(bash "${BIN}/github_channel.sh" --api POST "/repos/o/r/git/refs" '{"ref":"x"}' 2>/dev/null); rc=$?
[[ ${rc} -eq 5 ]] || fail "a refused write must exit 5 (hand back to the model), got ${rc}"
grep -q "channel:none" <<<"${out}" || fail "the handed-back call should name the none channel: ${out}"
grep -q "POST /repos/o/r/git/refs" <<<"${out}" || fail "the handed-back call must be fully formed: ${out}"

# --- 3: writes are sent as JSON, not form-encoded ---
#     curl -d defaults to application/x-www-form-urlencoded. github.com parses
#     the raw body as JSON anyway, so this stayed invisible until a proxy in
#     front of the API refused it.
grep -q "Content-Type: application/json" "${CURL_LOG}" \
    || fail "a request body must be sent as application/json, got: $(cat "${CURL_LOG}")"

# --- 4: claim_task.sh reaches `manual`, so the session continues ---
out=$(ARSENAL_DEFAULT_BRANCH=main bash "${BIN}/claim_task.sh" t-web1 2>/dev/null); rc=$?
[[ ${rc} -eq 5 ]] || fail "claim_task.sh must exit 5 (manual), not ${rc} — exit 2 stops the whole loop"
grep -q '^manual POST /repos/o/r/git/refs' <<<"${out}" \
    || fail "claim_task.sh should print the exact call to make: ${out}"

# --- 5: a genuine server error is still a fault, not a hand-back ---
cat > "${BIN}/curl" <<'EOF'
#!/usr/bin/env bash
out=""; url=""
args=("$@")
for i in "${!args[@]}"; do
    case "${args[$i]}" in
        -o) out="${args[$((i+1))]}" ;;
        https://*) url="${args[$i]}" ;;
    esac
done
if [[ "${url}" == *"/user" || "${url}" == *"/rate_limit" ]]; then
    [[ -n "${out}" ]] && echo '{"ok":true}' > "${out}"; printf '200'; exit 0
fi
[[ -n "${out}" ]] && echo '{"message":"boom"}' > "${out}"
printf '500'; exit 0
EOF
chmod +x "${BIN}/curl"
bash "${BIN}/github_channel.sh" --api POST "/repos/o/r/git/refs" '{"ref":"x"}' >/dev/null 2>&1; rc=$?
[[ ${rc} -eq 4 ]] || fail "a 500 must stay a fault (exit 4), got ${rc}"

# --- 6: a proxy that answers the reachability probe itself is not a channel ---
#     On Claude Code on the web the agent proxy answers GET /rate_limit 200
#     without the request reaching GitHub with the session's credential. The
#     probe printed `rest`, and every real call afterwards came back 403 —
#     which is neither `won` nor `lost` for a claim. `none` is a handled
#     outcome; a forged `rest` is not.
cat > "${BIN}/curl" <<'EOF'
#!/usr/bin/env bash
out=""; url=""
args=("$@")
for i in "${!args[@]}"; do
    case "${args[$i]}" in
        -o) out="${args[$((i+1))]}" ;;
        https://*) url="${args[$i]}" ;;
    esac
done
if [[ "${url}" == *"/rate_limit" ]]; then
    [[ -n "${out}" ]] && echo '{"ok":true}' > "${out}"; printf '200'; exit 0
fi
[[ -n "${out}" ]] && echo '{"message":"Resource not accessible"}' > "${out}"
printf '403'; exit 0
EOF
chmod +x "${BIN}/curl"
[[ "$(bash "${BIN}/github_channel.sh" --detect)" == "none" ]] \
    || fail "a proxy answering the reachability probe must not read as a usable channel"

echo "PASS: github_channel_test — all gates passed"
