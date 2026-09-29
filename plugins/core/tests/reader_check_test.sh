#!/usr/bin/env bash
# reader_check_test.sh — every spec and plan stays paired with a current reader,
# whichever skill wrote it (#464), and its review record names only notes the
# repo actually holds (#468).
#
# Covers: the PostToolUse hook's warning, the `branch` gate, the Downloads
# warning, init registering the hook, and validate_spec / validate_plan
# refusing a notes file that is not committed or an approval that is unbacked.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
assets="${here}/../skills/init/assets"
CHECK="${assets}/scripts/reader_check.py"
HOOK="${assets}/bin/reader_hook.sh"
SPEC_V="${here}/../skills/specify/scripts/validate_spec.py"
PLAN_V="${here}/../skills/design/scripts/validate_plan.py"
init_py="${here}/../skills/init/scripts/init.py"

tmp="$(mktemp -d)" || { echo "FAIL: mktemp -d failed" >&2; exit 1; }
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

repo="$tmp/yourproject"
mkdir -p "$repo/status" "$repo/src"
git -C "$repo" init -q -b main
git -C "$repo" config user.email t@example.com
git -C "$repo" config user.name t
git -C "$repo" config commit.gpgsign false
echo base > "$repo/src/app.txt"
git -C "$repo" add -A && git -C "$repo" commit -qm base

# --- 1: the hook warns on a spec/plan path, from any writer, and only there ---
hook() { printf '%s' "$1" | CLAUDE_PROJECT_DIR="$repo" bash "$HOOK"; }
out="$(hook "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$repo/status/plan.md\"}}")"
case "$out" in *additionalContext*status/plan.md*create_reader.py*) ;; *) fail "hook silent on status/plan.md: $out" ;; esac
out="$(hook "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$repo/docs/brainstorm/specs/2026-01-01-thing-design.md\"}}")"
case "$out" in *create_reader.py*specify*) ;; *) fail "hook silent on another plugin's docs/**/specs path: $out" ;; esac
out="$(hook "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$repo/arsenal/project/API/spec.md\"}}")"
[ -n "$out" ] || fail "hook silent on a workspace spec"
for quiet in "$repo/src/app.txt" "$repo/status/spec-annotated.md" "$repo/status/yourproject-spec-notes-2026-01-01-r1.md" "$repo/docs/plan-of-record.txt"; do
    out="$(hook "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$quiet\"}}")"
    [ -z "$out" ] || fail "hook fired on a non-spec path $quiet: $out"
done
printf 'not json' | bash "$HOOK" >/dev/null 2>&1 || fail "hook exits non-zero on a bad payload"
echo "PASS: the hook warns on every spec/plan path and nowhere else"

# --- 2: the branch gate ---
gate() { (cd "$repo" && python3 "$CHECK" branch --base main "$@"); }
git -C "$repo" checkout -qb feature
printf '# Plan\n\n**Revision**: 1\n\n## Technical solution\n\nx\n' > "$repo/status/plan.md"
gate >/dev/null 2>&1 && fail "gate passed a plan with no reader"
digest="$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],encoding="utf-8").read().encode()).hexdigest())' "$repo/status/plan.md")"
printf '<meta name="arsenal-source-sha256" content="%s">\n' "$digest" > "$repo/status/plan-reader.html"
gate >/dev/null 2>&1 || fail "gate refused a plan whose reader carries its digest"
git -C "$repo" add -A && git -C "$repo" commit -qm plan
gate >/dev/null 2>&1 || fail "gate refused a committed plan with a current reader"
echo "more" >> "$repo/status/plan.md"
out="$(gate 2>&1)" && fail "gate passed a plan edited after its reader was built"
case "$out" in *status/plan.md*create_reader.py*) ;; *) fail "gate did not name the stale plan: $out" ;; esac
git -C "$repo" checkout -q -- status/plan.md
echo "x" >> "$repo/src/app.txt"
gate >/dev/null 2>&1 || fail "gate refused a branch whose spec/plan did not change"
git -C "$repo" checkout -q -- src/app.txt
echo "PASS: the gate fails a spec/plan changed without a reader built from it"

# a real reader, when create_reader can run here
if python3 -c "import markdown" 2>/dev/null; then PY=(python3)
elif command -v uv >/dev/null 2>&1; then PY=(uv run --quiet --with markdown python3)
else PY=(); fi
if [ ${#PY[@]} -gt 0 ]; then
    echo "edited" >> "$repo/status/plan.md"
    (cd "$repo" && "${PY[@]}" "$assets/scripts/create_reader.py" --input status/plan.md \
        --output-dir status --name yourproject >/dev/null 2>&1) || fail "create_reader failed"
    gate >/dev/null 2>&1 || fail "gate refused the reader create_reader just built"
    grep -q "yourproject-plan-notes-'+today()+'-r1.md" "$repo/status/plan-reader.html" \
        || fail "#468: the export name does not carry the plan's revision"
    echo "PASS: create_reader's reader satisfies the gate and names its export -r<N>"

    # Two design docs in one docs/**/specs/ folder each get their own reader;
    # a shared spec-reader.html left one of them stale forever.
    d="docs/brainstorm/specs"
    mkdir -p "$repo/$d"
    printf '# A\n\n## One\n\na\n' > "$repo/$d/2026-01-01-a-design.md"
    printf '# B\n\n## One\n\nb\n' > "$repo/$d/2026-01-02-b-design.md"
    for f in a b; do
        (cd "$repo" && "${PY[@]}" "$assets/scripts/create_reader.py" --input "$d"/2026-*-"$f"-design.md \
            --output-dir "$d" --name yourproject >/dev/null 2>&1) || fail "create_reader failed on $f"
    done
    [ -f "$repo/$d/2026-01-01-a-design-reader.html" ] && [ -f "$repo/$d/2026-01-02-b-design-reader.html" ] \
        || fail "a non-canonical doc's reader is not named for its stem: $(ls "$repo/$d")"
    [ ! -e "$repo/$d/spec-reader.html" ] || fail "a non-canonical doc still writes spec-reader.html"
    ns_a=$(grep -o "var NS = '[^']*'" "$repo/$d/2026-01-01-a-design-reader.html")
    ns_b=$(grep -o "var NS = '[^']*'" "$repo/$d/2026-01-02-b-design-reader.html")
    [ -n "$ns_a" ] && [ "$ns_a" != "$ns_b" ] \
        || fail "two readers in one folder share a notes namespace: $ns_a"
    (cd "$repo" && python3 "$CHECK" branch --all >/dev/null 2>&1) \
        || fail "two specs sharing a folder cannot both have a current reader"
    rm -rf "$repo/docs"
    echo "PASS: design docs sharing a folder keep separate, current readers"
fi

# --- 3: validate_spec / validate_plan and the review record ---
spec="$repo/status/specification.md"
write_spec() {
    cat > "$spec" <<EOF
# Specification: thing

**Revision**: 2
**Status**: $1
**Revision log**:
- r1 — first draft
- r2 — applied \`yourproject-spec-notes-2026-01-02-r1.md\`

## 1. Problem statement

It is slow.

**Success criteria (measurable)**:

- [ ] \`p95_ms <= 200\`

## 2. Systems & Impact

The API.

## 3. Options

Cache it.

## 4. Recommendation

Cache it.
EOF
}
write_spec "draft"
python3 "$SPEC_V" --input "$spec" >/dev/null 2>&1 && fail "validate_spec passed a header naming a notes file that does not exist"
echo "notes" > "$repo/status/yourproject-spec-notes-2026-01-02-r1.md"
out="$(python3 "$SPEC_V" --input "$spec" 2>&1)" && fail "validate_spec passed a notes file that is not committed"
case "$out" in *"not committed"*) ;; *) fail "validate_spec did not say the notes are uncommitted: $out" ;; esac
git -C "$repo" add status/yourproject-spec-notes-2026-01-02-r1.md
python3 "$SPEC_V" --input "$spec" >/dev/null 2>&1 || fail "validate_spec refused a committed notes file"
python3 "$SPEC_V" --input "$spec" --require-approved >/dev/null 2>&1 && fail "--require-approved passed a draft"
write_spec "approved (2026-01-03, revision 1)"
python3 "$SPEC_V" --input "$spec" --require-approved >/dev/null 2>&1 && fail "--require-approved passed an approval of an older revision"
write_spec "approved (2026-01-03, revision 2)"
python3 "$SPEC_V" --input "$spec" --require-approved >/dev/null 2>&1 \
    || fail "--require-approved refused revision 2, whose log names a committed export"
sed -i 's/^- r2 .*/- r2 — reworded/' "$spec"
python3 "$SPEC_V" --input "$spec" --require-approved >/dev/null 2>&1 && fail "--require-approved passed an approval backed by nothing"
sed -i 's/^\*\*Status\*\*: .*/**Status**: approved (2026-01-03, revision 2) — without annotations/' "$spec"
python3 "$SPEC_V" --input "$spec" --require-approved >/dev/null 2>&1 || fail "--require-approved refused an explicit 'without annotations'"
printf '# Plan\n\n**Revision**: 1\n**Status**: draft\n**Revision log**:\n- r1 — applied `yourproject-plan-notes-2026-01-04-r1.md`\n\n## Technical solution\n' > "$repo/status/plan2.md"
out="$(python3 "$PLAN_V" --input "$repo/status/plan2.md" 2>&1)"
case "$out" in *"yourproject-plan-notes-2026-01-04-r1.md"*) ;; *) fail "validate_plan did not flag a missing plan notes file: $out" ;; esac
echo "PASS: the validators refuse notes the repo does not hold and approvals that are not backed"

# --- 4: the Downloads warning, localized folder included ---
fake_home="$tmp/home"; mkdir -p "$fake_home/Descargas"
echo n > "$fake_home/Descargas/yourproject-spec-notes-2026-01-05-r2.md"
echo n > "$fake_home/Descargas/otherproject-spec-notes-2026-01-05-r1.md"
cp "$fake_home/Descargas/yourproject-spec-notes-2026-01-05-r2.md" "$fake_home/Descargas/yourproject-spec-notes-2026-01-02-r1.md"
out="$(cd "$repo" && HOME="$fake_home" XDG_DOWNLOAD_DIR= python3 "$CHECK" downloads)"
case "$out" in *"yourproject-spec-notes-2026-01-05-r2.md"*) ;; *) fail "downloads missed an uncommitted export in ~/Descargas: $out" ;; esac
case "$out" in *otherproject*) fail "downloads reported another project's export: $out" ;; esac
case "$out" in *"2026-01-02-r1"*) fail "downloads reported an export the repo already tracks: $out" ;; esac
echo "PASS: an uncommitted export left in a Downloads folder is named"

# --- 5: init registers the hook and scaffolds no unused specs/ plans/ ---
target="$tmp/consumer"; mkdir -p "$target"; git -C "$target" init -q
ARSENAL_UPSTREAM_CHECK=0 python3 "$init_py" --repo-path "$target" >/dev/null 2>&1 || fail "init exited non-zero"
python3 - "$target/.claude/settings.json" <<'PY' || fail "reader hook not registered"
import json, sys
post = json.load(open(sys.argv[1]))["hooks"]["PostToolUse"]
hit = [e for e in post if "reader_hook.sh" in json.dumps(e)]
assert hit and hit[0]["matcher"] == "Write|Edit|MultiEdit", post
assert "CLAUDE_PROJECT_DIR" in hit[0]["hooks"][0]["command"], hit
PY
[ -x "$target/claude-arsenal/bin/reader_hook.sh" ] || fail "reader_hook.sh not installed"
[ ! -d "$target/arsenal/specs" ] && [ ! -d "$target/arsenal/plans" ] || fail "init still scaffolds arsenal/specs or arsenal/plans"
grep -q "status/specification.md" "$target/CLAUDE.md" || fail "CLAUDE.md does not name where specs go"
ARSENAL_UPSTREAM_CHECK=0 python3 "$init_py" --repo-path "$target" >/dev/null 2>&1 || fail "init re-run failed"
n="$(python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))).count("reader_hook.sh"))' "$target/.claude/settings.json")"
[ "$n" = 1 ] || fail "re-running init registered the reader hook $n times"
echo "PASS: init registers the reader hook once and names the spec/plan locations"
