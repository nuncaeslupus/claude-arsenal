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

echo "PASS: sync_plan_graph_test — all gates passed"
