#!/usr/bin/env bash
# fence_language_test.sh — the untagged-fence check must be right about *where*.
#
# This check shipped two defects in one review cycle, both of the same kind: it
# was confidently wrong rather than silent. It reported the closing line of a
# ```` wrapper as an untagged block, and it counted lines from the body so every
# number came out short by the height of the frontmatter. A warning whose whole
# value is a line number has to get the line number right, so both properties
# are pinned here.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE="${SCRIPT_DIR}/../skills/skill-workshop/scripts/validate.py"
[[ -f "${VALIDATE}" ]] || { echo "SKIP: ${VALIDATE} not found" >&2; exit 0; }

fail() { echo "FAIL: $1" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
skill="${tmp}/demo"
mkdir -p "${skill}/evals"
# A complete-enough skill: without the evals file the validator reports that and
# stops short of the checks this test is about, so every assertion below would
# pass vacuously.
cat > "${skill}/evals/loading_verification.json" <<'EVALS'
{"canary": "demo-loaded-0000-00-00-0000000000000000", "negative_control": "unrelated prompt"}
EVALS

emit() {  # emit <fence-line-content>
    cat > "${skill}/SKILL.md" <<SKILL
---
name: demo
description: When the user needs a fixture skill for the fence check. Do NOT use for anything real.
metadata:
  type: capability
---

# demo

CANARY: demo-loaded-0000-00-00-0000000000000000

Body text.

$1
some content
\`\`\`
SKILL
}

checks() { python3 "${VALIDATE}" "${skill}" --severity warn --json 2>/dev/null; }

# --- an untagged fence is reported at its real line in the file --------------
emit '```'
line=$(checks | python3 -c 'import json,sys,re
issues=[i for i in json.load(sys.stdin)["issues"] if i["check"]=="body.fence-language"]
print(re.search(r"line (\d+)", issues[0]["message"]).group(1) if issues else "none")')
[[ "${line}" == "14" ]] \
    || fail "untagged fence is on line 14 of the file; the check said ${line}"

# --- a tagged fence is not reported ------------------------------------------
emit '```bash'
checks | grep -q "fence-language" && fail "a tagged fence must not be reported"

# --- a four-backtick wrapper closes on its own marker ------------------------
# The documented way to show a fenced block inside one. Counting bare "```"
# opens reads the wrapper's closing line as a fresh untagged block.
cat > "${skill}/SKILL.md" <<'SKILL'
---
name: demo
description: When the user needs a fixture skill for the fence check. Do NOT use for anything real.
metadata:
  type: capability
---

# demo

CANARY: demo-loaded-0000-00-00-0000000000000000

````markdown
```bash
echo hi
```
````
SKILL
checks | grep -q "fence-language" \
    && fail "a ````-wrapped example must not be reported as untagged"

# --- four spaces of indent is an indented code block, not a fence ------------
# CommonMark 4.5: at four spaces the backticks are literal content, so a block
# indented that far is not a fence and has no language to tag.
#
# Asserted against `untagged_fences` directly rather than through a fixture
# skill. The property is a property of that function, and routing it through
# the validator adds fixture plumbing that can swallow the signal — an earlier
# revision of this test did exactly that and passed while the rule was reverted.
python3 - "${VALIDATE}" <<'PY' || fail "indented-block handling is wrong"
import importlib.util, sys

spec = importlib.util.spec_from_file_location("_v", sys.argv[1])
mod = importlib.util.module_from_spec(spec)
sys.modules["_v"] = mod
spec.loader.exec_module(mod)

indented = "text\n\n    ```\n    not a fence\n    ```\n"
if mod.untagged_fences(indented):
    print("four-space-indented backticks reported as a fence", file=sys.stderr)
    raise SystemExit(1)

# Up to three spaces still opens a real fence, and an untagged one is reported.
for pad in ("", " ", "  ", "   "):
    if mod.untagged_fences(f"text\n\n{pad}```\n{pad}body\n{pad}```\n") != [3]:
        print(f"a fence indented {len(pad)} space(s) was not reported", file=sys.stderr)
        raise SystemExit(1)
PY

echo "PASS: fence_language_test — untagged fences reported at the right line"
