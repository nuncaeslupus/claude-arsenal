#!/usr/bin/env bash
# SessionStart hook, matcher `compact` — registered by /init and by the core plugin.
#
# Compaction replaces the transcript with a summary, and a summary drops exactly
# what a long task needs to continue: the decisions already taken, the approaches
# already ruled out, and the next command. `execution` keeps those in the Resume
# section of tmp/<task-id>-notes.md; this prints that section and a short
# `git status` so they land back in context right after compaction. (A PreCompact
# hook cannot do this — its output never reaches the model.)
#
# Silent when there is no recent notes file, so a repo that never uses them pays
# nothing. Never blocks: always exits 0.

cat >/dev/null 2>&1 || true   # the hook payload is not needed
root="${CLAUDE_PROJECT_DIR:-$(pwd)}"
cd "$root" 2>/dev/null || exit 0
[ -d tmp ] || exit 0

# Newest notes file touched in the last 7 days — an older one is a finished task.
recent="$(find tmp -maxdepth 1 -name '*-notes.md' -mtime -7 2>/dev/null)"
[ -n "$recent" ] || exit 0
# shellcheck disable=SC2086  # paths come from find over tmp/, no spaces by construction
notes="$(ls -t $recent 2>/dev/null | head -n 1)"
[ -f "$notes" ] || exit 0

resume="$(awk '
  /^## Resume[[:space:]]*$/ { on = 1; next }
  on && /^## /              { exit }
  on && !/^>/               { print }
' "$notes" | sed '/./,$!d')"

echo "arsenal: context was compacted. The task state is on disk, not in the summary."
echo "Notes: $notes — re-read it in full before changing anything."
if [ -n "$resume" ]; then
  echo "$resume"
else
  echo "(no Resume section — fill Decided / Ruled out / Next step before continuing)"
fi
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "git status:"
  git status --short --branch 2>/dev/null | head -n 15
fi
exit 0
