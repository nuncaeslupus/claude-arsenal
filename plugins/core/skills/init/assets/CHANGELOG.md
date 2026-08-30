# Changelog

All notable **user-visible** changes to claude-arsenal are recorded here, one
`## [X.Y.Z]` section per version bump (see root `CLAUDE.md` § Versioning).
"User-visible" means what a downstream consumer would want to know about
before or after updating — a new skill, a new flag, a new option, a breaking
change — not an internal refactor, a doc fix, or a test.

CI's `version-bump` job requires a heading here matching the bumped
`.bundle-version` on every PR that changes a shipped file; it only checks that
the heading exists, not that the entry says anything useful, so write one a
consumer would actually want to read.

`/init`'s upgrade banner and `check_update.sh` print the entries between a
consumer's installed version and the one they're updating to, automatically,
every time they update — that's the whole reason this file exists instead of
being a changelog nobody reads.

Format: `## [X.Y.Z] - YYYY-MM-DD`, newest first, plain bullets below.

## [2.7.0] - 2026-08-30

- **New: a pre-PR adversarial review gate.** Before a PR is opened, the change
  is now read by a reviewer that has never seen it — spawned with only a case
  file, no conversation history. Until now every pre-PR check was run by the
  session that wrote the code, which catches what is broken but not what was
  built instead of what was asked for.
  - `claude-arsenal/bin/adversarial_review.sh emit` builds the case file
    (intent + the full diff, including uncommitted and untracked work + the
    rubric) into `tmp/arsenal-review/packet.md`; `verdict` records the answer;
    `check` asks whether *this* tree is cleared. The receipt is bound to a
    digest of the reviewed diff, so a CLEAR does not carry over to code written
    after it.
  - `claude-arsenal/agents/reviewer.md` is the reviewer's role and rubric.
  - No verdict is never a pass: `verdict` exits 2 when the reviewer returned no
    `VERDICT:` line, and `check` exits 2 with nothing on record.
- **Task PRs now state whether anyone independent looked.** `open_task_pr.sh`
  runs the check and writes the outcome — CLEAR, BLOCK, stale, or never run —
  into the PR body, where whoever merges it will see it.
- **New setting `pre-pr-review`** in `arsenal/config.toml`: `warn` (default —
  the PR opens either way and the outcome is stated in its body), `required`
  (no CLEAR for this tree, no PR), or `off`. Existing repos are unaffected on
  upgrade beyond the new body line; set `required` to make it binding.
- `execution` (Step 4b), `github` (pre-PR gate) and the worker agent now run the
  gate before opening a PR. `ship`'s adversarial gate (Step 7) now uses the same
  mechanism instead of its own inline prompt, so there is one rubric to improve.

## [2.6.0] - 2026-08-29

- Added this file. Every version-bump PR must now add a `## [X.Y.Z]` entry
  here describing what changed for a downstream consumer — enforced by CI's
  `version-bump` job (a missing heading fails the build).
- `/init`'s upgrade banner now prints the entries between your installed
  version and the new one. Re-running `/init` — or the automatic
  session-start refresh that already ran `init.py --silent` every session —
  now tells you what you just picked up, not only the version number.
- `check_update.sh` does the same for a subtree-remote install, printing the
  entries alongside its existing "UPDATE AVAILABLE" / "pulling update…"
  messages.
