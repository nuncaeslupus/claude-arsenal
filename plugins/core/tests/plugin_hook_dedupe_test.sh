#!/usr/bin/env bash
# plugin_hook_dedupe_test.sh — a plugin hook stands down when /init's copy runs.
#
# `/init` registers the same scripts in .claude/settings.json (the only hooks a
# cloud session gets), and a machine with the plugin installed too would run
# each twice: the resume block injected twice after compaction, the gate paid
# twice per call. Each duplicated plugin entry skips itself when the project's
# settings.json names its script, and runs otherwise.
#
# Exit: 0 on PASS, 1 on FAIL.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
root="$(cd "$here/../../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $1" >&2; exit 1; }

# Every guarded command, with the plugin root swapped for stubs that leave a trace.
python3 - "$root" > "$tmp/commands" <<'PY'
import json, re, sys
root = sys.argv[1]
for p in ("plugins/core/hooks/hooks.json", "plugins/skill-workshop/hooks/hooks.json"):
    for entries in json.load(open(f"{root}/{p}"))["hooks"].values():
        for e in entries:
            for h in e["hooks"]:
                m = re.match(r"grep -qsF (\S+) ", h["command"])
                if m:
                    print(m.group(1) + "\t" + h["command"])
PY
[[ -s "$tmp/commands" ]] || fail "no guarded plugin hook found"

mkdir -p "$tmp/project/.claude" "$tmp/plugin"
while IFS=$'\t' read -r script cmd; do
    for d in hooks skills/init/assets/bin; do
        mkdir -p "$tmp/plugin/$d"
        printf '#!/bin/bash\ntouch "%s/ran"\n' "$tmp" > "$tmp/plugin/$d/$script"
    done
    run() { rm -f "$tmp/ran"; CLAUDE_PROJECT_DIR="$tmp/project" CLAUDE_PLUGIN_ROOT="$tmp/plugin" \
        sh -c "$cmd" </dev/null >/dev/null 2>&1; }

    rm -f "$tmp/project/.claude/settings.json"
    run; [[ -f "$tmp/ran" ]] || fail "$script: plugin hook did not run with no settings.json"

    printf '{"hooks":{"X":[{"hooks":[{"command":"bash claude-arsenal/bin/%s"}]}]}}' "$script" \
        > "$tmp/project/.claude/settings.json"
    run; [[ -f "$tmp/ran" ]] && fail "$script: plugin hook ran although settings.json registers it"
done < "$tmp/commands"
echo "PASS: $(wc -l < "$tmp/commands" | tr -d ' ') plugin hooks stand down when settings.json runs the same script"
