#!/usr/bin/env bash
# queue_workflow_refresh_test.sh — an installed arsenal-queue.yml that is an
# unedited older shipped version is refreshed; an edited one is left alone
# (#470). Also pins that the shipped-hash list includes the current workflow.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
init_py="$here/../skills/init/scripts/init.py"
wf_dir="$here/../skills/init/assets/workflows"
tmp="$(mktemp -d)" || { echo "FAIL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }
export ARSENAL_UPSTREAM_CHECK=0 ARSENAL_BRANCH_PROTECTION=0

sha() { python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read().replace(b"\r\n",b"\n")).hexdigest())' "$1"; }

current=$(sha "$wf_dir/arsenal-queue.yml")
grep -qx "$current" "$wf_dir/arsenal-queue.yml.shipped" \
    || fail "arsenal-queue.yml changed but its hash is not in arsenal-queue.yml.shipped — append: $current"
echo "PASS: the shipped-hash list includes the current workflow"

repo="$tmp/repo"; git init -q "$repo"
python3 "$init_py" --repo-path "$repo" --silent >/dev/null 2>&1 || fail "init exited non-zero"
target="$repo/.github/workflows/arsenal-queue.yml"
[ -f "$target" ] || fail "workflow not installed"

# An older shipped version, unedited. Stand in for it with a file whose hash a
# copy of the bundle lists as shipped; the refresh would restore the real list.
bundle="$tmp/bundle"; cp -R "$here/../skills/init/assets" "$bundle"
printf 'name: arsenal queue (old shipped)\n' > "$target"
sha "$target" >> "$bundle/workflows/arsenal-queue.yml.shipped"
out=$(python3 "$init_py" --repo-path "$repo" --bundle-dir "$bundle" --silent 2>&1)
case "$out" in *"arsenal-queue.yml: refreshed"*) ;; *) fail "an unedited older version was not refreshed: $out" ;; esac
[ "$(sha "$target")" = "$current" ] || fail "refresh did not install the current workflow"
echo "PASS: an unedited older shipped version is refreshed"

printf '# my local tweak\n' >> "$target"
edited=$(sha "$target")
out=$(python3 "$init_py" --repo-path "$repo" --bundle-dir "$bundle" --silent 2>&1)
case "$out" in *"left as is"*) ;; *) fail "an edited workflow was not reported: $out" ;; esac
[ "$(sha "$target")" = "$edited" ] || fail "an edited workflow was overwritten"
echo "PASS: an edited workflow is left alone"

echo "=== queue_workflow_refresh_test: all passed ==="
