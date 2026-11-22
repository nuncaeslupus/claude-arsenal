#!/usr/bin/env bash
# reader_pictures_browser_test.sh — runs reader_pictures_browser.js under `make test`.
#
# The browser half of the reader-pictures tests needs Node with Playwright and a
# Chromium it can launch. Where either is missing (CI installs neither) this says
# so loudly and exits 0: the Python half, reader_pictures_test.sh, still runs.
#
# Exit: 0 on PASS or SKIP, 1 on FAIL.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
skip() {
    echo "SKIP: reader_pictures_browser.js NOT RUN — $1; paste, drop, export, import and" \
        "quota behaviour of reader pictures is untested here" >&2
    exit 0
}
command -v node >/dev/null 2>&1 || skip "no node"
node -e "require('playwright')" >/dev/null 2>&1 || skip "node cannot load playwright"
node -e "require('playwright').chromium.launch().then(b => b.close())" >/dev/null 2>&1 \
    || skip "playwright cannot launch chromium"

out=$(node "${here}/reader_pictures_browser.js" 2>&1)
status=$?
if [[ ${status} -ne 0 ]]; then
    echo "${out}" >&2
    echo "FAIL: reader_pictures_browser.js" >&2
    exit 1
fi
echo "PASS: reader pictures in a real browser ($(grep -c '^ok ' <<<"${out}") checks)"
