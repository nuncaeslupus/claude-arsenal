#!/usr/bin/env bash
# upstream_check_test.sh — init warns when it is older than the newest release,
# and refuses to bootstrap a NEW repo from a stale copy unless --allow-stale
# (#462). Upstream is a local repo, so the test needs no network.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
init_py="$here/../skills/init/scripts/init.py"
tmp="$(mktemp -d)" || { echo "FAIL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

export HOME="$tmp/home" ARSENAL_UPSTREAM_CHECK=1 ARSENAL_UPSTREAM_URL="$tmp/upstream"
git init -q "$ARSENAL_UPSTREAM_URL"
git -C "$ARSENAL_UPSTREAM_URL" -c user.name=t -c user.email=t@t commit -q --allow-empty -m x
git -C "$ARSENAL_UPSTREAM_URL" tag v999.0.0

repo="$tmp/repo"; git init -q "$repo"
out=$(python3 "$init_py" --repo-path "$repo" --silent 2>&1)
case "$out" in *"ARSENAL OUTDATED"*"999.0.0"*) ;; *) fail "no OUTDATED banner: $out" ;; esac
[ ! -d "$repo/claude-arsenal" ] || fail "a stale first install wrote the bundle anyway"
echo "PASS: a stale first install is refused with the update commands"

python3 "$init_py" --repo-path "$repo" --silent --allow-stale >/dev/null 2>&1 || fail "--allow-stale exited non-zero"
[ -f "$repo/claude-arsenal/.bundle-version" ] || fail "--allow-stale did not install"
out=$(python3 "$init_py" --repo-path "$repo" --silent 2>&1)
case "$out" in *"ARSENAL OUTDATED"*) ;; *) fail "no banner on an existing repo: $out" ;; esac
case "$out" in *refusing*) fail "an existing repo was refused, not warned: $out" ;; esac
echo "PASS: an existing repo gets the banner, not a refusal"

export ARSENAL_UPSTREAM_URL="$tmp/nowhere" HOME="$tmp/home2"
repo2="$tmp/repo2"; git init -q "$repo2"
python3 "$init_py" --repo-path "$repo2" --silent >/dev/null 2>&1 || fail "an unreachable upstream blocked init"
[ -f "$repo2/claude-arsenal/.bundle-version" ] || fail "an unreachable upstream blocked the install"
echo "PASS: an unreachable upstream never blocks an install"

echo "=== upstream_check_test: all passed ==="
