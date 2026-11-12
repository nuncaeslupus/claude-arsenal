#!/usr/bin/env bash
# make_tag_main_test.sh — `make tag` only publishes the commit origin's default
# branch points at; from a feature branch it refuses and creates no tag.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
command -v make >/dev/null 2>&1 || { echo "SKIP: make not found" >&2; exit 0; }
fail() { echo "FAIL: $1" >&2; exit 1; }

tmp=$(mktemp -d); trap 'cd /; rm -rf "${tmp}"' EXIT
git init -q --bare -b main "${tmp}/remote.git"
git clone -q "${tmp}/remote.git" "${tmp}/w" 2>/dev/null
cd "${tmp}/w"
git config user.email t@e.x; git config user.name T; git config commit.gpgsign false
cp "${ROOT}/Makefile" .
mkdir -p plugins/core/skills/init/assets
echo 1.2.3 > plugins/core/skills/init/assets/.bundle-version
git add -A && git commit -q -m seed && git push -q origin main
git checkout -q -b feature
echo x > x && git add x && git commit -q -m "feat: unmerged"

out=$(make tag 2>&1) && fail "make tag published from a feature branch: ${out}"
grep -q 'not origin/main' <<<"${out}" || fail "refusal does not explain itself: ${out}"
git ls-remote --tags origin | grep -q v1.2.3 && fail "a tag reached origin from the feature branch"

git checkout -q main
make tag >/dev/null 2>&1 || fail "make tag must still publish from the default branch"
git ls-remote --tags origin | grep -q 'refs/tags/v1.2.3' || fail "the tag was not published from main"
echo "PASS: make_tag_main_test — all gates passed"
