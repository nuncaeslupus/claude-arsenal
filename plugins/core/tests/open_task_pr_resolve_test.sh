#!/usr/bin/env bash
# open_task_pr_resolve_test.sh — open_task_pr.sh resolves a task's issue over the
# API with the configured `task-label`, across pages, and refuses to cut a branch
# that would drop commits the session already made on its own branch.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="${SCRIPT_DIR}/../skills/init/assets"
[[ -f "${ASSETS}/bin/open_task_pr.sh" ]] || { echo "SKIP: open_task_pr.sh not found" >&2; exit 0; }
fail() { echo "FAIL: $1" >&2; exit 1; }

tmp=$(cd "$(mktemp -d)" && pwd -P)
trap 'cd /; rm -rf "${tmp}"' EXIT

# A real `gh` would open a PR; shadow it with one that is present but unusable.
mkdir -p "${tmp}/shim"
printf '#!/usr/bin/env bash\nexit 1\n' > "${tmp}/shim/gh"; chmod +x "${tmp}/shim/gh"
export PATH="${tmp}/shim:${PATH}"

# A bundle whose github_channel.sh is a stub: it logs each API path and serves
# issue pages — page 1 full of other tasks, the wanted one on page 2.
mkdir -p "${tmp}/bundle"
cp -r "${ASSETS}/bin" "${ASSETS}/scripts" "${tmp}/bundle/"
cat > "${tmp}/bundle/bin/github_channel.sh" <<'STUB'
#!/usr/bin/env bash
case "$1" in
    --slug) echo o/r ;;
    --api)
        echo "$3" >> "${CHANNEL_LOG}"
        if [[ "$3" == *"page=1" ]]; then
            python3 -c 'import json; print(json.dumps([{"number": 1000+i, "state": "open", "title": "x", "body": "`arsenal-task: other-%d`" % i, "labels": []} for i in range(100)]))'
        else
            echo '[{"number": 4242, "state": "open", "title": "t", "body": "`arsenal-task: lo-pg1`", "labels": []}]'
        fi ;;
esac
STUB
export CHANNEL_LOG="${tmp}/channel.log"

git init -q --bare -b main "${tmp}/remote.git"
git clone -q "${tmp}/remote.git" "${tmp}/work" 2>/dev/null
cd "${tmp}/work"
git config user.email t@e.x; git config user.name T; git config commit.gpgsign false
mkdir -p arsenal/tasks
for t in lo-pg1 lo-ahead; do
    printf '%s\n' "---" "id: ${t}" 'title: "fixture"' "priority: 1" "---" "" \
        "## Acceptance gate" '```bash' "true" '```' > "arsenal/tasks/${t}.md"
done
printf 'task-label = "team:task"\n' > arsenal/config.toml
git add -A && git commit -q -m seed && git push -q origin main

export ARSENAL_ISSUES_JSON="${tmp}/absent.json" ARSENAL_ALLOW_SHARED_ADD=1 ARSENAL_COAUTHOR=""

# --- the issue sits on page 2 and the configured label is the one queried ---
echo change > f.txt
err="${tmp}/err1"
bash "${tmp}/bundle/bin/open_task_pr.sh" lo-pg1 "Paged" >/dev/null 2>"${err}" \
    || fail "issue on page 2 was not resolved: $(cat "${err}")"
grep -q 'labels=team%3Atask&' "${CHANNEL_LOG}" || fail "the configured task-label was not queried: $(cat "${CHANNEL_LOG}")"
grep -q 'page=2' "${CHANNEL_LOG}" || fail "page 2 was never requested"
grep -q 'Closes #4242' "${err}" || fail "PR body does not close the page-2 issue: $(cat "${err}")"
echo "PASS: configured label and pagination reach the issue handle"

# --- commits made on the session's own branch must not be dropped ---
git checkout -q main
git checkout -q -b session/own
echo work > work.txt && git add work.txt && git commit -q -m "feat: committed work"
err="${tmp}/err2"
if ARSENAL_TASK_ISSUE=7 bash "${tmp}/bundle/bin/open_task_pr.sh" lo-ahead "Ahead" >/dev/null 2>"${err}"; then
    fail "a branch cut from main would have dropped the committed work"
fi
grep -q 'not on' "${err}" || fail "the refusal does not explain itself: $(cat "${err}")"
[[ "$(git rev-parse --abbrev-ref HEAD)" == "session/own" ]] || fail "refusal moved HEAD"
echo "PASS: committed work on another branch is refused, not dropped"

echo "PASS: open_task_pr_resolve_test — all gates passed"
