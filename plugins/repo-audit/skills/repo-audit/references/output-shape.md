# Output shape

## Contents

- [Deliverables](#deliverables)
- [Destination — who each document is for](#destination--who-each-document-is-for)
- [The fix / queue / issue / ledger decision](#the-fix--queue--issue--ledger-decision)
- [What never goes into the target repo](#what-never-goes-into-the-target-repo)

Load before the act pass — the fix/queue/issue/ledger decision, the
write-up's destination, and the validator/task-creation scripts' exact
contracts.

## Deliverables

1. **The audit report.** A compact, factual artifact — what was understood
   (briefly) plus the full findings ledger, built with
   `${CLAUDE_SKILL_DIR}/scripts/create_artifact.py` (see that script's module
   docstring for the input JSON shape). This is repo-audit's own output:
   user-facing, never committed to the target repo. For a fuller narrative
   treatment — interview prep, onboarding, a pitch, a deep-dive — hand the
   same findings JSON to the `explain-repo` skill rather than growing this
   one into a second narrative generator.
2. **Verified, low-risk doc fixes.** A stale number, a broken cross-link, a
   factual claim the code contradicts — corrected directly in the target
   repo, through its own normal contribution path (its branch naming,
   commit style, version-bump rules — read them first, don't assume this
   repo's conventions). Run `${CLAUDE_SKILL_DIR}/scripts/validate_markdown.py`
   against any new or changed `.md` files before proposing them.
3. **The findings ledger.** Every CONFIRMED finding, one row each, with a
   `status` of `fixed`, `queued`, `issue`, or `flagged` (see the decision
   below). Build it as JSON matching
   `${CLAUDE_SKILL_DIR}/scripts/validate_findings.py`'s input shape, run the
   validator, then feed the same structure into `create_artifact.py`'s
   `ledger` field.

## Destination — who each document is for

State this plainly to the user every time; don't assume it's obvious.

- **Default: user-only.** The audit report, and anything `explain-repo`
  produces from it, are for the person who asked — published as an Artifact
  when the tool is available, otherwise a local file. Say so explicitly
  when handing one over: "this is for you, not committed to the repo."
- **Narrow exception: specific content that helps everyone working in the
  target repo.** A corrected number in an existing doc, or a new reference
  page for a subsystem that's genuinely undocumented anywhere — these go
  into the repo, and only as deliverable 2 above (a small, specific fix),
  never as a wholesale copy of a narrative document.
- **If a request is ambiguous** ("document this repo," "add docs for X"),
  ask which is meant rather than guessing: a fix to the repo's own docs
  (small, specific, goes in the repo) or an explanatory document about the
  repo for the user (full narrative scope, stays out).

## The fix / queue / issue / ledger decision

Every CONFIRMED finding lands in exactly one bucket, in this preference
order:

1. **Fix directly** — mechanically verifiable and low-risk: a count that's
   provably wrong, a link that's provably broken, a claim the code provably
   contradicts. No design judgment involved.
2. **Queue as an arsenal task** — needs real implementation work, and the
   target repo has `arsenal/tasks/` (check for the directory before
   attempting this). Use
   `${CLAUDE_SKILL_DIR}/scripts/create_task.py --title "<finding, as a job>"
   --tag <category> --body "<failure scenario + suggested direction>"
   --tasks-dir <target-repo>/arsenal/tasks`. The task's acceptance gate can
   name a test that doesn't exist yet — writing it is the executing
   session's own RED step, per this repo's own test-first discipline. Print
   the created task id and file path; queuing the GitHub issue handle for it
   needs whatever GitHub access the session has, same as `queue-add`.
3. **File as a GitHub issue** — needs real work, but the target repo has no
   `arsenal/tasks/` (or the user prefers issues). Only with write access to
   the target repo; otherwise falls through to the ledger.
4. **Ledger row only** — a design trade-off, a judgment call, or no write
   access anywhere. This is the floor: every finding gets at least a ledger
   row, even one that's also queued or filed, so nothing is silently
   dropped.

Never open a pull request for any of these unasked, regardless of bucket —
queuing or filing is the actionable-but-reviewable middle ground; an
unsupervised fleet of fixes is not the goal.

## What never goes into the target repo

The audit methodology itself — this skill's references, the issue taxonomy,
a findings scratch file, the raw research-agent transcripts. Those are this
skill's working material, not the target repo's documentation. If a
genuinely new subsystem turns out to be undocumented anywhere, the fix is a
new reference page describing *that subsystem*, in the target repo's own
doc conventions — never a copy of this skill's process.
