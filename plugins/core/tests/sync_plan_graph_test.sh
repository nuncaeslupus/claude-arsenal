#!/usr/bin/env bash
# sync_plan_graph_test.sh — a plan's dependency graph is a drawspec block generated
# from the task table, and validate_plan.py holds the two together (#506). A
# graph that is not drawspec (the old ASCII art) only warns; drift inside a
# drawspec graph fails.
#
# The template used to seed an ASCII ```text``` diagram: hand-drawn arrows that
# drifted from the Depends column the moment a task moved, and broke the rule
# that every diagram is a ```drawspec fence.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail
export PYTHONDONTWRITEBYTECODE=1

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
scripts="${here}/../skills/design/scripts"
GRAPH="${scripts}/sync_plan_graph.py"
PLAN_V="${scripts}/validate_plan.py"
TEMPLATE="${here}/../skills/design/references/template-plan.md"
READER="${here}/../skills/init/assets/scripts/create_reader.py"

tmp="$(mktemp -d)" || { echo "FAIL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# --- 1: the template seeds a drawspec graph, not ASCII art, and it agrees with its table ---
grep -q '^```text' "$TEMPLATE" && fail "the plan template still seeds a \`\`\`text diagram"
grep -q '^```drawspec$' "$TEMPLATE" || fail "the plan template has no drawspec dependency graph"
out="$(python3 "$PLAN_V" --input "$TEMPLATE" 2>&1)" || fail "the template fails its own validator: $out"
cp "$TEMPLATE" "$tmp/fresh.md"
python3 "$GRAPH" --input "$tmp/fresh.md" --apply >/dev/null || fail "plan_graph --apply failed on the template"
cmp -s "$TEMPLATE" "$tmp/fresh.md" || fail "the template's graph is not what sync_plan_graph.py generates: $(diff "$TEMPLATE" "$tmp/fresh.md")"
echo "PASS: the template's dependency graph is the generated drawspec block"

# --- 2: the generated block is a flow with one node per task and one edge per Depends ---
python3 "$GRAPH" --input "$TEMPLATE" > "$tmp/block.txt" || fail "plan_graph printed nothing"
python3 - "$tmp/block.txt" <<'PY' || fail "the generated block is not the expected drawspec document"
import json, sys
lines = open(sys.argv[1], encoding="utf-8").read().strip().splitlines()
assert lines[0] == "```drawspec" and lines[-1] == "```", lines
doc = json.loads("\n".join(lines[1:-1]))
assert doc["version"] == 1 and doc["kind"] == "flow", doc
assert [n["id"] for n in doc["nodes"]] == ["T1", "T2", "T3", "T4"], doc["nodes"]
edges = {(e["from"], e["to"]) for e in doc["edges"]}
assert edges == {("T1", "T2"), ("T1", "T3"), ("T2", "T4"), ("T3", "T4")}, edges
for n in doc["nodes"]:
    assert set(n) == {"id", "text"}, n  # no coordinates, no styling: drawspec refuses them
PY
echo "PASS: nodes are tasks, edges are the Depends column"

# --- 3: the validator names an edge the graph is missing, and one nobody declared ---
sed 's/^| T4 | <description> | <service> | S\/M\/L | T2, T3 |/| T4 | <description> | <service> | S\/M\/L | T2 |/' \
    "$TEMPLATE" > "$tmp/drift.md"
sed -i 's/^| T3 | <description> | <service> | S\/M\/L | T1 |/| T3 | <description> | <service> | S\/M\/L | T1, T2 |/' "$tmp/drift.md"
out="$(python3 "$PLAN_V" --input "$tmp/drift.md" 2>&1)" && fail "a graph that drifted from Depends passed: $out"
case "$out" in *"missing edge T2 → T3"*) ;; *) fail "the missing edge T2 → T3 was not named: $out" ;; esac
case "$out" in *"has edge T3 → T4, which no Depends cell declares"*) ;; *) fail "the extra edge T3 → T4 was not named: $out" ;; esac
python3 "$GRAPH" --input "$tmp/drift.md" --apply >/dev/null || fail "regenerating the drifted graph failed"
out="$(python3 "$PLAN_V" --input "$tmp/drift.md" 2>&1)" || fail "a regenerated graph still fails: $out"
echo "PASS: validate_plan names missing and extra edges, and plan_graph --apply fixes them"

# --- 4: an ASCII graph is a warning with the fix, not a failure; no graph section is not a problem ---
python3 - "$TEMPLATE" "$tmp/ascii.md" <<'PY'
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
t = re.sub(r"```drawspec\n.*?\n```", "```text\nT1 ──> T2\n```", t, flags=re.S)
open(sys.argv[2], "w", encoding="utf-8").write(t)
PY
out="$(python3 "$PLAN_V" --input "$tmp/ascii.md" 2>&1)" || fail "an ASCII dependency graph failed validation (it is a warning): $out"
case "$out" in *"  ! dependency graph is a \`\`\`text block, not a \`\`\`drawspec fence"*sync_plan_graph.py*--apply*) ;; *) fail "the ASCII graph warning does not name the fix: $out" ;; esac
case "$out" in *"✗"*) fail "an ASCII graph was reported as a problem: $out" ;; esac
python3 "$GRAPH" --input "$tmp/ascii.md" --apply >/dev/null || fail "plan_graph could not replace an ASCII graph"
grep -q '^```text' "$tmp/ascii.md" && fail "plan_graph --apply left the ASCII block in place"
out="$(python3 "$PLAN_V" --input "$tmp/ascii.md" 2>&1)" || fail "a replaced ASCII graph still fails: $out"
case "$out" in *"  ! "*) fail "a replaced ASCII graph still warns: $out" ;; esac

python3 - "$TEMPLATE" "$tmp/nograph.md" <<'PY'
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
t = re.sub(r"### Dependency graph\n.*?(?=\n## )", "", t, flags=re.S)
open(sys.argv[2], "w", encoding="utf-8").write(t)
PY
grep -q "Dependency graph" "$tmp/nograph.md" && fail "test setup: the graph section was not removed"
python3 "$PLAN_V" --input "$tmp/nograph.md" >/dev/null 2>&1 || fail "a plan with no graph section failed"
python3 "$GRAPH" --input "$tmp/nograph.md" --apply >/dev/null || fail "plan_graph could not add a missing graph"
python3 - "$tmp/nograph.md" <<'PY' || fail "the added graph section is not between the task table and the Evidence log"
import sys
t = open(sys.argv[1], encoding="utf-8").read()
assert t.index("| T# | Description") < t.index("### Dependency graph") < t.index("## Evidence log"), t
PY
python3 "$PLAN_V" --input "$tmp/nograph.md" >/dev/null 2>&1 || fail "the added graph does not validate"
echo "PASS: an ASCII graph warns with its fix (exit 0); a missing one is added in place"

# --- 5: a plan reader draws the graph (fake drawspec, no network) ---
if python3 -c "import markdown" 2>/dev/null; then PY=(python3)
elif command -v uv >/dev/null 2>&1; then PY=(uv run --quiet --with markdown python3)
else PY=(); fi
if [ ${#PY[@]} -gt 0 ]; then
    fake="$tmp/fake-drawspec"
    cat > "$fake" <<'EOF'
#!/usr/bin/env bash
doc=$(cat)
case "$1" in
  validate) python3 -c 'import json,sys; d=json.loads(sys.stdin.read()); assert d["kind"]=="flow"' <<<"$doc" || exit 1 ;;
  render) echo '<svg xmlns="http://www.w3.org/2000/svg" data-fake="plan-graph"><text>drawn</text></svg>' ;;
  *) exit 2 ;;
esac
EOF
    chmod +x "$fake"
    mkdir -p "$tmp/status"
    cp "$TEMPLATE" "$tmp/status/plan.md"
    out="$(cd "$tmp" && ARSENAL_DRAWSPEC="$fake" "${PY[@]}" "$READER" --input status/plan.md \
            --output-dir status --name yourproject 2>&1)" || fail "the plan reader failed: $out"
    html="$(find "$tmp/status" -name '*plan*reader.html' | head -1)"
    [ -n "$html" ] || fail "no plan reader was written: $out"
    grep -q 'data-fake="plan-graph"' "$html" || fail "the plan reader did not draw the dependency graph"
    echo "PASS: the plan reader renders the dependency graph through drawspec"
else
    echo "SKIP: plan reader render — no python3 with markdown, and no uv" >&2
fi

# --- 6: the real drawspec accepts the generated graph, when it can be had here ---
real=()
if command -v drawspec >/dev/null 2>&1; then real=(drawspec)
elif command -v uvx >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1 && \
        timeout 180 uvx --quiet --from 'drawspec>=0.2,<0.3' drawspec --version \
        >/dev/null 2>&1; then
    real=(uvx --quiet --from 'drawspec>=0.2,<0.3' drawspec)
fi
if [ ${#real[@]} -gt 0 ]; then
    sed '1d;$d' "$tmp/block.txt" > "$tmp/graph.json"
    out="$("${real[@]}" validate - < "$tmp/graph.json" 2>&1)" \
        || fail "drawspec refuses the generated dependency graph: $out"
    echo "PASS: drawspec validates the generated dependency graph"
else
    echo "SKIP: real drawspec check — no drawspec on PATH and no uvx/network to fetch it" >&2
fi

# --- 7: edges a longer path implies are left out, and a path satisfies the validator (#515) ---
# validate_plan.py demanded every Depends edge literally, sync_plan_graph.py drew
# them all, and drawspec refuses a flow past 16 edges — so a plan over the budget
# could pass validation or be drawn, never both.
mkplan() {  # mkplan <out> <python expr yielding (tid, deps) pairs>
    python3 - "$TEMPLATE" "$1" "$2" <<'PY'
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
rows = eval("(" + sys.argv[3] + ")")
table = "\n".join(
    f"| {tid} | task {tid} | svc | S | {', '.join(deps) or '—'} | `x >= 1` | `test_{tid}` in `t.py` — ok |"
    for tid, deps in rows
)
t = re.sub(r"^\| T1 \|.*?\| T4 \|[^\n]*", table, t, flags=re.S | re.M)
open(sys.argv[2], "w", encoding="utf-8").write(t)
PY
}
mkplan "$tmp/redux.md" '[("T1", []), ("T2", ["T1"]), ("T3", ["T1", "T2"])]'
python3 "$GRAPH" --input "$tmp/redux.md" --apply >/dev/null || fail "plan_graph --apply failed on the reduction plan"
python3 - "$tmp/redux.md" <<'PY' || fail "the implied edge T1 → T3 was drawn"
import json, re, sys
body = re.search(r"```drawspec\n(.*?)\n```", open(sys.argv[1], encoding="utf-8").read(), re.S).group(1)
edges = {(e["from"], e["to"]) for e in json.loads(body)["edges"]}
assert edges == {("T1", "T2"), ("T2", "T3")}, edges
PY
out="$(python3 "$PLAN_V" --input "$tmp/redux.md" 2>&1)" || fail "a reduced graph fails validation: $out"
# A hand-drawn graph that keeps the implied edge is also right.
python3 - "$tmp/redux.md" <<'PY'
import sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read()
t = t.replace('  {"from": "T2", "to": "T3"}', '  {"from": "T2", "to": "T3"},\n  {"from": "T1", "to": "T3"}')
open(p, "w", encoding="utf-8").write(t)
PY
grep -q '"from": "T1", "to": "T3"' "$tmp/redux.md" || fail "test setup: implied edge not added"
out="$(python3 "$PLAN_V" --input "$tmp/redux.md" 2>&1)" || fail "an implied edge drawn literally fails validation: $out"
echo "PASS: implied edges are reduced away, and a path satisfies validate_plan"

# --- 8: past drawspec's budget the graph splits by phase, each fence within it (#515) ---
# 13 tasks, 18 Depends edges, none implied by another: the case that left a host
# with a plan the reader could not be rebuilt from.
mkplan "$tmp/big.md" '[(f"T{i}", []) for i in range(1, 5)]
 + [(f"T{i}", [f"T{(i - 5) % 4 + 1}", f"T{(i - 4) % 4 + 1}"]) for i in range(5, 10)]
 + [(f"T{i}", [f"T{(i - 10) % 5 + 5}", f"T{(i - 9) % 5 + 5}"]) for i in range(10, 14)]'
out="$(python3 "$GRAPH" --input "$tmp/big.md" --apply 2>&1)" || fail "plan_graph --apply failed on the big plan: $out"
case "$out" in *"split into"*phases*) ;; *) fail "a plan past the budget was not split: $out" ;; esac
case "$out" in *"⚠"*) fail "a split graph still warns about the budget: $out" ;; esac
python3 - "$tmp/big.md" "$tmp" <<'PY' || fail "the split graph is not an overview plus phase graphs within the budget"
import json, re, sys
t = open(sys.argv[1], encoding="utf-8").read()
section = t[t.index("### Dependency graph"):t.index("## Evidence log")]
bodies = re.findall(r"```drawspec\n(.*?)\n```", section, re.S)
assert len(bodies) >= 3, len(bodies)
docs = [json.loads(b) for b in bodies]
assert not any(re.fullmatch(r"T\d+", n["id"]) for n in docs[0]["nodes"]), "first fence is the phase overview"
drawn = set()
for n, d in enumerate(docs):
    assert len(d["nodes"]) <= 15 and len(d.get("edges", [])) <= 16, (d["title"], len(d["nodes"]), len(d.get("edges", [])))
    open(f"{sys.argv[2]}/fence{n}.json", "w", encoding="utf-8").write(json.dumps(d))
    if n:
        for e in d.get("edges", []):
            assert (e["from"], e["to"]) not in drawn, f"edge drawn twice: {e}"
            drawn.add((e["from"], e["to"]))
assert len(drawn) == 18, len(drawn)
PY
out="$(python3 "$PLAN_V" --input "$tmp/big.md" 2>&1)" || fail "a split graph fails validation: $out"
case "$out" in *"  ! "*) fail "a split graph warns: $out" ;; esac
# Regenerating replaces every fence of the split graph, not just the first.
python3 "$GRAPH" --input "$tmp/big.md" --apply >/dev/null || fail "regenerating the split graph failed"
n1=$(grep -c '^```drawspec$' "$tmp/big.md")
python3 "$GRAPH" --input "$tmp/big.md" --apply >/dev/null
[[ "$(grep -c '^```drawspec$' "$tmp/big.md")" == "${n1}" ]] || fail "a second --apply duplicated fences"
# A drift across phases is still named (T3 reaches nothing in phase 3 before this).
sed -i 's/^| T13 | task T13 | svc | S | \([^|]*\) |/| T13 | task T13 | svc | S | \1, T3 |/' "$tmp/big.md"
grep -q '^| T13 .*, T3 |' "$tmp/big.md" || fail "test setup: T13 did not gain T3"
out="$(python3 "$PLAN_V" --input "$tmp/big.md" 2>&1)" && fail "a cross-phase dependency missing from the split graph passed: $out"
case "$out" in *"missing edge T3 → T13"*) ;; *) fail "the missing cross-phase edge was not named: $out" ;; esac
# One unsplit graph past the budget warns that the reader cannot be built.
python3 - "$tmp/big.md" "$tmp/flat.md" "$GRAPH" <<'PY'
import importlib.util, re, sys
spec = importlib.util.spec_from_file_location("g", sys.argv[3]); g = importlib.util.module_from_spec(spec); spec.loader.exec_module(g)
t = open(sys.argv[1], encoding="utf-8").read()
tasks, edges = g.task_edges(t)
start, end, _, _ = g.find_graph(t)
lines = t.splitlines()
flat = g._flow("Task dependencies", [(i, i) for i, _ in tasks], sorted(edges))
open(sys.argv[2], "w", encoding="utf-8").write("\n".join([*lines[:start], flat, *lines[end:]]) + "\n")
PY
out="$(python3 "$PLAN_V" --input "$tmp/flat.md" 2>&1)" || fail "an over-budget graph that agrees with Depends must not fail: $out"
case "$out" in *"  ! "*"past what drawspec draws"*"--apply"*) ;; *) fail "an over-budget graph did not warn with the fix: $out" ;; esac
echo "PASS: past the budget, an overview plus per-phase graphs, each drawable, validated as one"

if [ ${#real[@]} -gt 0 ]; then
    for f in "$tmp"/fence*.json; do
        out="$("${real[@]}" validate - < "$f" 2>&1)" || fail "drawspec refuses split fence $(basename "$f"): $out"
    done
    echo "PASS: drawspec validates every fence of the split graph"
fi

echo "PASS: sync_plan_graph_test — all gates passed"
