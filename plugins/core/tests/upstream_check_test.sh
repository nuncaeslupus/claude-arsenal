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

# A failed lookup is cached too (for an hour), so an offline machine does not pay
# the ls-remote timeout on every session start.
cache="$HOME/.cache/claude-arsenal/upstream-latest"
[ "$(cat "$cache" 2>/dev/null)" = "$ARSENAL_UPSTREAM_URL -" ] || fail "a failed lookup was not cached: $(cat "$cache" 2>/dev/null)"
git init -q "$ARSENAL_UPSTREAM_URL"
git -C "$ARSENAL_UPSTREAM_URL" -c user.name=t -c user.email=t@t commit -q --allow-empty -m x
git -C "$ARSENAL_UPSTREAM_URL" tag v999.0.0
out=$(python3 "$init_py" --repo-path "$repo2" --silent 2>&1)
case "$out" in *"ARSENAL OUTDATED"*) fail "a cached failure was retried at once: $out" ;; esac
python3 -c 'import os,sys,time; t=time.time()-2*3600; os.utime(sys.argv[1],(t,t))' "$cache"
out=$(python3 "$init_py" --repo-path "$repo2" --silent 2>&1)
case "$out" in *"ARSENAL OUTDATED"*"999.0.0"*) ;; *) fail "an expired failure was not retried: $out" ;; esac
echo "PASS: a failed lookup is cached, and retried once it expires"

# --workspace forwards --allow-stale to the base install it runs first.
repo3="$tmp/repo3"; git init -q "$repo3"
python3 "$init_py" --repo-path "$repo3" --workspace api --allow-stale >/dev/null 2>&1 \
    || fail "--workspace --allow-stale exited non-zero"
[ -f "$repo3/claude-arsenal/.bundle-version" ] || fail "--workspace dropped --allow-stale"
echo "PASS: --workspace forwards --allow-stale"

echo "=== upstream_check_test: all passed ==="
