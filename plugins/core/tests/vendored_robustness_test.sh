#!/usr/bin/env bash
# Four failure modes a consumer's CodeRabbit review found in 3.6.3, each one a
# case where a helper aborts or lies instead of degrading. They share a shape:
# the guard exists a line away, and the path that skipped it is the one nobody
# exercises. These pin the fixes so the guards cannot quietly come back off.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
A="${ROOT}/plugins/core/skills/init/assets"
fails=0
ok()   { echo "PASS: $1"; }
bad()  { echo "FAIL: $1"; fails=$((fails + 1)); }

# --- 1. open_task_pr.sh rejects an option-like value ------------------------
# `--title --body-file x.md` satisfied `$# -ge 2`, so TITLE became --body-file
# and x.md fell through to positional — the #352 subject bug, reachable again
# through the very option form added to fix it. The subject survives a squash,
# so a wrong one is only fixable by rewriting shared history.
S="${A}/bin/open_task_pr.sh"
for args in "--title --body-file x.md" "--type --title" "--body-file --title"; do
    # shellcheck disable=SC2086
    out="$(bash "$S" lo-cf3d $args 2>&1)"; rc=$?
    if [[ $rc -ne 0 && "$out" == *"looks like an option"* ]]; then
        ok "open_task_pr rejects an option-like value: $args"
    else
        bad "open_task_pr accepted '$args' (rc=$rc)"
    fi
done
out="$(bash "$S" lo-cf3d --title=--body-file 2>&1)"; rc=$?
if [[ $rc -ne 0 && "$out" == *"looks like an option"* ]]; then
    ok "open_task_pr rejects an option-like value in the = form"
else
    bad "open_task_pr accepted --title=--body-file (rc=$rc)"
fi
out="$(bash "$S" lo-cf3d --title= 2>&1)"; rc=$?
if [[ $rc -ne 0 && "$out" == *"non-empty"* ]]; then
    ok "open_task_pr rejects an empty value"
else
    bad "open_task_pr accepted an empty --title= (rc=$rc)"
fi
# The rejection must be an exit, not an empty variable: this script has no
# `set -e`, so a validator that ran inside $( ) would end its subshell only.
if grep -q '_reject_optionlike .* || exit 1' "$S"; then
    ok "the value check aborts the script, not just a subshell"
else
    bad "open_task_pr's value check is not paired with an exit"
fi

# --- 2. gate_run.sh survives a non-UTF-8 working task file ------------------
# UnicodeDecodeError derives from ValueError, so `except OSError` let it escape
# — as a traceback, from a branch that only prints a diagnostic, after the gate
# decision was already made.
if grep -q 'except (OSError, UnicodeDecodeError):' "${A}/bin/gate_run.sh"; then
    ok "gate_run's diagnostic read catches UnicodeDecodeError"
else
    bad "gate_run still catches only OSError around read_text"
fi

# --- 3. arsenal_migrate.py validates merge-policy BEFORE it writes ----------
# Raised from the config block, the MigrateError landed after the task files,
# the history files and _migrated-history.md were on disk — and main() then
# printed `nothing was written` over a half-migrated tree.
py="${A}/scripts/arsenal_migrate.py"
pre="$(grep -n 'payload_for(_row)' "$py" | tail -1 | cut -d: -f1)"
raise="$(grep -n 'has no `merge-policy' "$py" | head -1 | cut -d: -f1)"
write="$(grep -n 'target.write_text(task_markdown' "$py" | head -1 | cut -d: -f1)"
if [[ -n "$pre" && -n "$raise" && -n "$write" && "$raise" -gt "$pre" && "$raise" -lt "$write" ]]; then
    ok "the merge-policy check sits in pre-flight, before the first write"
else
    bad "merge-policy check at ${raise:-?} is not between pre-flight ${pre:-?} and first write ${write:-?}"
fi

# --- 4. init.py does not abort the install to tidy a shadow handover --------
# An unguarded unlink propagated out of init_base and ended the run before
# _vendor_skills, _register_gate_hook and _inject_claude_md had run.
if python3 - "$ROOT" <<'PY'
import ast, pathlib, sys
src = pathlib.Path(sys.argv[1], "plugins/core/skills/init/scripts/init.py").read_text()
fn = next(n for n in ast.walk(ast.parse(src))
          if isinstance(n, ast.FunctionDef) and n.name == "_retire_shadow_handover")
# every unlink() call must sit inside a Try that handles OSError
tries = [t for t in ast.walk(fn) if isinstance(t, ast.Try)]
def guarded(node):
    return any(node is d or node in list(ast.walk(t)) for t in tries for d in ast.walk(t))
unlinks = [c for c in ast.walk(fn)
           if isinstance(c, ast.Call) and getattr(c.func, "attr", None) == "unlink"]
sys.exit(0 if unlinks and all(guarded(u) for u in unlinks) else 1)
PY
then
    ok "init.py's shadow-handover unlink is guarded"
else
    bad "init.py's shadow-handover unlink can still abort the install"
fi

if [[ $fails -eq 0 ]]; then
    echo "PASS: vendored_robustness_test — all gates passed"
else
    echo "FAIL: vendored_robustness_test — $fails gate(s) failed"
fi
exit $((fails > 0))
