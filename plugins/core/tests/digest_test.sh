#!/usr/bin/env bash
# digest_test.sh — the per-PR record and the digest page (review-digest P2, T2-T3).
#
# The digest is what a human decides from, so the failures that matter are a
# record that eats the PR body, a card that hides how risky a change is, a page
# too long to skim, and a decision that is not bound to the commit it was about.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DIGEST="${here}/../skills/init/assets/scripts/digest.py"
[[ -f "${DIGEST}" ]] || { echo "FAIL: ${DIGEST} not found" >&2; exit 1; }

tmp="$(mktemp -d)" || { echo "FAIL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "${tmp}"' EXIT
cd "${tmp}" || exit 1
mkdir -p arsenal
printf '[review]\npreset = "solo-trust"\n' > arsenal/config.toml
fail() { echo "FAIL: $1" >&2; exit 1; }

HEAD=1a2b3c4d5e6f
cat > pr.json <<JSON
{"number":42,"title":"Add login","state":"open","head":{"sha":"${HEAD}"},
 "body":"Closes #7\n\nHand-written context the record must not touch."}
JSON
printf '[{"filename":"src/app.py","additions":600,"deletions":20}]\n' > files.json
cat > notes.json <<'JSON'
{"summary":"Adds the login form and its handler. Sessions last one hour.",
 "undo":"revert the merge commit",
 "fixes":[{"what":"token logged in plain text","found_by":"cold-reviewer","fix":"redacted","commit":"9f8e7d6"}],
 "open":["RISK: no rate limit yet"]}
JSON

# --- record ---------------------------------------------------------------------
out="$(python3 "${DIGEST}" record --pr 42 --notes notes.json --pr-json pr.json --files-json files.json 2>/dev/null)"
[[ $? -eq 5 ]] || fail "record without a channel should print the body and exit 5"
grep -q "Hand-written context the record must not touch." <<<"${out}" \
    || fail "test_record_preserves_body_text_outside_block"
rec="$(python3 -c 'import re,sys; print(re.search(r"<!-- arsenal-digest\s*(\{.*?\})\s*-->", sys.stdin.read(), re.S).group(1))' <<<"${out}")"
field() { python3 -c "import json,sys; print(json.loads(sys.stdin.read())[sys.argv[1]])" "$1" <<<"${rec}"; }
[[ "$(field mark)" == "red" ]] || fail "test_mark_red_for_high_with_open_finding: $(field mark)"
[[ "$(field tier)" == "high" && "$(field head)" == "1a2b3c4" ]] || fail "tier and head should be recorded"
# Re-recording replaces the block instead of adding a second one.
python3 - "${out}" <<'PY' > pr2.json
import json, sys
print(json.dumps({"number": 42, "title": "Add login", "state": "open",
                  "head": {"sha": "1a2b3c4d5e6f"}, "body": sys.argv[1]}))
PY
out2="$(python3 "${DIGEST}" record --pr 42 --notes notes.json --pr-json pr2.json --files-json files.json 2>/dev/null)"
[[ "$(grep -c 'arsenal-digest' <<<"${out2}")" == "1" ]] || fail "a second record must replace the block, not add one"
echo "PASS: record keeps the body, replaces its own block, derives tier and mark"

# --- check ----------------------------------------------------------------------
long="$(python3 -c 'print(" ".join(["word"] * 61) + ".")')"
printf '{"summary":"%s"}\n' "${long}" > long.json
python3 "${DIGEST}" check --record long.json >/dev/null; [[ $? -eq 1 ]] || fail "test_check_rejects_61_words"
printf '{"summary":"One. Two. Three. Four."}\n' > four.json
python3 "${DIGEST}" check --record four.json >/dev/null; [[ $? -eq 1 ]] || fail "four sentences must be refused"
echo "PASS: check enforces 60 words and 3 sentences"

# --- render ---------------------------------------------------------------------
python3 - <<'PY' > prs.json
import json
words = "Changes the parser so quoted fields keep their commas and adds the regression test that failed before."
prs = []
for i, (tier, mark, state) in enumerate([("low", "green", "open")] * 7 + [("high", "red", "needs-decision"),
                                         ("medium", "amber", "awaiting-approval"), ("high", "amber", "merged")]):
    rec = {"v": 1, "pr": 100 + i, "head": f"{i:07d}", "tier": tier, "mark": mark, "state": state,
           "tier_reasons": ["x"], "summary": words, "deps": [100] if i == 9 else [],
           "size": {"add": 10, "del": 2, "files": 1}, "rounds": 1,
           "findings": [{"what": "w", "found_by": "self", "fix": "f", "commit": "c"}] * 5,
           "open": [], "undo": "revert", "questions": [], "ratified": None}
    prs.append({"number": 100 + i, "title": f"Change {i}", "state": "closed" if state == "merged" else "open",
                "closed_at": "2099-01-01T00:00:00Z", "html_url": "", "body": "<!-- arsenal-digest\n" + json.dumps(rec) + "\n-->"})
print(json.dumps(prs))
PY
python3 "${DIGEST}" render --since 2000-01-01 --format html --out out --prs-json prs.json >/dev/null \
    || fail "render failed"
page="$(ls out/*.html)"
words="$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import digest; print(digest.visible_words(open(sys.argv[2]).read()))' \
    "$(dirname "${DIGEST}")" "${page}")"
(( words <= 900 )) || fail "test_render_ten_records_fits_900_words: ${words}"
first="$(grep -o 'data-pr="[0-9]*"' "${page}" | head -1)"
[[ "${first}" == 'data-pr="107"' ]] || fail "test_render_sorts_red_first: ${first}"
[[ -f arsenal/session/digest.json ]] || fail "render should record when it ran"
md="$(python3 "${DIGEST}" render --since 2000-01-01 --format md --out out --prs-json prs.json)"
grep -q "^### 🔴 #107" <<<"${md}" || fail "the Markdown digest should lead with the red card"
echo "PASS: render — ${words} visible words for 10 PRs, red first, Markdown twin"

# --- export, in a browser where one is installed --------------------------------
if command -v node >/dev/null 2>&1 && node -e "require('playwright')" 2>/dev/null; then
    cat > exp.js <<'JS'
const {chromium}=require('playwright');
(async()=>{const b=await chromium.launch();const p=await (await b.newContext({acceptDownloads:true})).newPage();
 const errs=[];p.on('pageerror',e=>errs.push(e.message));
 await p.goto('file://'+process.argv[2]);
 await p.check('article[data-pr="107"] input[value="approve"]');
 await p.fill('article[data-pr="108"] textarea','why so big?');
 await p.check('article[data-pr="108"] input[value="question"]');
 const [dl]=await Promise.all([p.waitForEvent('download'),p.click('#dg-export')]);
 const out=require('fs').readFileSync(await dl.path(),'utf8');
 const data=JSON.parse(out.match(/ARSENAL-DECISIONS (\{.*\}) -->/)[1]);
 console.log(JSON.stringify({errs,d107:data["107"],q:data["108"].note}));await b.close();})();
JS
    res="$(node exp.js "${tmp}/${page}" 2>&1)" || fail "export check crashed: ${res}"
    [[ "${res}" == '{"errs":[],"d107":{"decision":"approve","head":"0000007","note":""},"q":"why so big?"}' ]] \
        || fail "test_export_carries_head_sha: ${res}"
    echo "PASS: export carries each decision with the head it was made on"
else
    echo "SKIP: digest export check — node with playwright not available" >&2
fi

echo "PASS: digest_test — all gates passed"
