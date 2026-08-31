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

## [2.16.0] - 2026-08-31

- **`compare_har.py` completes the toolkit: what changed between two captures.**
  The scraper's early-warning test — capture once, commit a derived fixture,
  and later ask whether the site moved. Non-zero exit means it did.
- Matching is one-to-one and deterministic, because a capture routinely repeats
  the same method and URL. The identity key is `(method, scheme, host, port,
  path, query pairs in captured order, request body)`; entries sharing a key
  pair in capture order, and anything left over is reported as an addition or a
  removal rather than paired with something that merely resembles it. A match
  made on order alone says so, so a reader can tell it from a real one.
- Two new references: `filters.md` (every selection flag, and the three that
  are not what they look like) and `recipes.md` (the whole path — capture, to
  the endpoint, to a request that runs in a loop).
- A test now asserts the sibling commands expose the same selection flags.
  Consistency across six scripts was a convention; it is now a contract.

## [2.15.0] - 2026-08-31

- **`create_repro.py` turns a found endpoint into a working request.**
  `--id N --format curl|python` emits a runnable reproduction with the method,
  URL, headers and body the capture recorded. Credentials are redacted by
  default; `--secrets` emits the real ones, which is what reproducing a login
  needs. Every value is escaped for where it is going — shell arguments quoted
  uniformly, Python values through `repr()`, bodies through `--data-raw` so one
  beginning with `@` stays data instead of becoming a local-file read.
- **`create_har.py` writes a derived capture.** Filtered by the same selection
  grammar, redacted, and **bodies dropped by default** — redaction covers named
  fields, and a response body is unbounded text that may carry a credential
  anywhere in it, so keeping them by default would hand back a file that looks
  sanitised and is not. `--keep-bodies` opts back in and says so. An `--output`
  that resolves to the input is refused before anything is opened, and every
  write is a same-directory temp plus an atomic rename.
- The derived file stays analysable: because redaction is the same salted
  fingerprint everywhere, `analyze_har.py --headers` still splits constant from
  varying on a redacted capture.

## [2.14.1] - 2026-08-31

- **The annotatable reader no longer loses notes quietly.** Two failure paths
  cleared the unsaved-work warning while the work was, in fact, unsaved: a
  `localStorage` write that threw (a private window, blocked site data) marked
  storage unusable but left the page thinking there was nothing to lose, and a
  blocked download was reported as `Backup saved`. In the no-storage mode that
  download is the *only* copy. Both now keep the warning armed and say what
  happened. Re-generate any reader you handed out before this version.

## [2.14.0] - 2026-08-30

- **`analyze_har.py` now reduces a capture to insight.** Nine modes, and the
  one worth running second is `--endpoints`: it collapses URL paths into
  templates and reports which parameters vary and over what range. Turning
  `?page=1&loc=NY`, `?page=2&loc=NY`, `?page=3&loc=NY` into one row saying
  `page` varies 1–3 while `loc` is constant is the difference between reading
  forty URLs and reading how to iterate the site.
- `--headers` finds the auth header: request headers grouped by host and split
  into constant across every request (candidate credential) versus varying.
- Also `--errors` (non-2xx with the body snippet that says how to fix the
  request), `--cookies`, `--stats FIELD`, `--redirects`, `--slowest`,
  `--largest` and `--websockets` — for sites that stream their data over a
  socket, where an HTTP body search finds nothing because there is no body.
- **Cookie redaction now keeps names and flags.** `Set-Cookie: sid=abc;
  HttpOnly` is stored as `sid=<redacted:ab12cd34>; HttpOnly` rather than being
  replaced wholesale. The name and the flags are what say which cookie
  authenticates and whether it is `HttpOnly`; losing them made cookie analysis
  a count of anonymous strings.

## [2.13.0] - 2026-08-30

- **`har` can now find things.** `query_har.py` selects entries, shows one in
  full, and gets data out. The two-command answer a scraping session actually
  wants: `--response-match "a string from the page"` names the request that
  returned it, then `--show N --schema` prints that body's shape — keys, types
  and array lengths, usually 100x smaller than the body and usually the real
  question.
- One selection grammar, shared: `--url`, `--host`, `--method`, `--status`
  (`200`, `4xx`, `400-499`), `--mime`, `--type`, `--min-size`/`--max-size`,
  `--slower-than`, `--param NAME[=REGEX]`, `--has-header NAME[=REGEX]`,
  `--body-match`, `--response-match`, `--page`, `--since`/`--until`,
  `--invert`. Every sibling command will spell them identically.
- **Three cache flags, not two.** `--no-cache` selects `_fromCache: false`
  only; `--unknown-cache` selects entries whose exporter never recorded it.
  Folding those together would make the same command mean different things on
  a Chrome capture and a Playwright one.
- Extraction: `--extract-body --output-dir`, `--json-path`, `--css`, `--xpath`.
  Filenames derived from a URL are flattened and the destination is verified
  inside the output directory before any write — a capture's URLs are as
  untrusted as its bodies. A selector the small CSS/XPath subset does not
  support is refused **by name**, never silently unmatched.
- Output is capped at 20 rows and 4096 bytes and says which cap dropped what.
  `--limit 0` removes both; `--output PATH` writes the complete result.
  `--json` stays parseable under the cap by dropping whole entries.

## [2.12.0] - 2026-08-30

- **New section `extract`, and its first skill `har`.** Off by default, so a
  repo that never scrapes pays nothing for it; `init.py --sections extract`
  turns it on, and `--list-sections` names it whether it is on or not.
- **`har` reads browser captures.** A HAR holds the complete network truth of a
  session and is also 5-500 MB of JSON, so the one thing nobody can do with it
  is read it. This release ships the foundation: `validate_har.py` (is this
  capture usable, and what did its exporter leave out) and `analyze_har.py`
  (what is in here, and `--index` to build the sidecar every later command
  reads). Searching, extraction and reproduction follow in the next releases.
- The index sidecar is redacted: auth headers, cookies and token-shaped
  parameters become `<redacted:ab12cd34>` — a salted fingerprint, so equal
  values stay equal and header analysis still works, while nothing about the
  original is recoverable. URL userinfo and fragments are dropped outright.
- Bodies are decoded before they are searched — base64, gzip, deflate, and
  charsets declared, undeclared or declared wrongly. A body that cannot be
  decoded is reported as undecodable, never returned as a mangled string.

## [2.11.0] - 2026-08-30

- **Every session now reads the capability map at start-up, and volunteers a
  skill you did not install when a task calls for it.** The session-start
  protocol gained step 0c: run `init.py --list-sections`. A discovery mechanism
  that waits to be invoked only serves people who already know the answer, and
  the failure here was never "the tool could not be found" — it was that nobody
  goes looking, because nothing said there was anything to look for.
- **What that changes in practice:** asked to do something a section this repo
  skipped would do properly, the session says so once — "this repo does not have
  `python` installed, which ships `coverage-gaps` for exactly this; enable it
  with `--sections python`, or say the word and I will carry on by hand" — and
  then does what was asked. The trigger is a task *squarely* covered by a skill,
  not one loosely related to it, and the answer is not re-litigated afterwards.
- New `claude-arsenal/references/capability-map.md` covers the map, when to
  volunteer a section and when not to, and how to enable one.

## [2.10.0] - 2026-08-30

- **A live issue now outranks a closed duplicate when reading the board.** A
  task can carry two handles — a duplicate created against a stale fetch, or a
  re-seeded board — and the state map took whichever GitHub returned last. With
  the open one listed first, an old closed duplicate made the task read `done`,
  so completion-drift checks went silent on a task that was still open.
  `issue_number_for` already preferred the open handle; the two now agree.
- **`query_status.py --pending-merge`, for auditing a branch rather than the
  default branch.** The completion protocol archives a task file in the same
  diff that closes its issue, so between opening a PR and merging it every task
  that PR finishes reads *archived, issue still open*. Reported as drift, that
  made the documented workflow unable to produce a green build on any PR. With
  the flag it is a note; without it, on the default branch, it is still the
  drift it was — a merge that did half its job.

- **New: `init.py --list-sections` prints the capability map.** Sections made
  the install set a choice, and a choice creates a thing nobody knows about — a
  repo without the `python` section has no way to learn `coverage-gaps` exists,
  because the only place a skill announces itself is the listing of the skills
  that *were* installed. The map is one short line per section: its name, what
  it is for, whether it is installed here, and — for the ones that are not — the
  skills it would bring. `--section NAME` prints those skills with their full
  descriptions, which is how to check whether one actually fits before enabling
  it. Both are read-only; neither installs anything.
- **Sections are enabled with `--sections a,b` or by editing `[skills]` in
  `arsenal/config.toml`**, unchanged — the map just makes it possible to know
  what to ask for.
- The map ships as data (`sections.json`) rather than being scanned from disk,
  because a vendored `init.py` can only see the skills its repo already
  installed. A bundle predating it falls back to what is on disk and says so.

## [2.9.1] - 2026-08-30

- **`query_status.py` no longer reports a missing issue handle it never looked
  for.** Run without `--issues`, it flagged every task as `no issue handle` —
  not an answer, since nothing was consulted. Any local audit of a board (no
  GitHub channel, no fetch) therefore failed on every task and could not be made
  to pass. The check is now skipped, and *reported* as skipped, when there is no
  issue data to check against; detail rows read `handle?` instead of
  `no-handle`. With `--issues` supplied, behaviour is unchanged — a genuinely
  missing handle is still a finding.

## [2.9.0] - 2026-08-30

- **The annotatable reader is now a gate, not a closing step.** `specify` and
  `design` already generated a reader; both now say that the work consuming the
  document waits for the annotations. No PR to merge a spec or plan, and no
  `design` off a spec or `execution` off a plan, until the reviewer's export has
  come back and been read. A document reviewed after it merged was ratified, not
  reviewed. A reviewer who says to proceed without annotating is making that
  call — it is not an assumption to act on while waiting.
- **The rule now covers any document that specifies or plans work**, not only
  `status/specification.md` and workspace specs, which are all that
  `create_reader.py` auto-discovers. Design documents, RFCs and proposals written into a docs tree
  get a reader too, named explicitly with `--output-dir` beside them. Publishing
  some other way — a chat summary, a hand-built page, a link to the raw file —
  does not satisfy it: the reader exists so notes attach to the section they are
  about, and a substitute that drops that property is not one.
- Guidance to rename the generated `spec-reader.html` / `spec-annotated.md` per
  document where several can share a directory — the names are fixed, so two
  design docs would otherwise overwrite each other's readers.
- **Every session will learn what the whole marketplace can do, not just what
  this repo installed.** Sections default off, so the failure worth designing
  against is not that a consumer cannot find a tool — it is that they never go
  looking. The session-start protocol will run `init.py --list-sections` every
  session: one short line per section, its skills, and whether it is on here.
  The commitment that follows is behavioural and general — whenever a task is
  squarely covered by a skill this repo did not install, the session says so
  before doing the work the long way. A repo handed an unexpected scraping task
  will say the `extract` section ships a HAR analyser for exactly this instead
  of reaching for a browser; a repo without the `python` section asked about
  coverage gaps will mention `coverage-gaps`. Specified in design 0002 § 5.5;
  shipping as delivery stage 0.
- The rules live in one place — `claude-arsenal/references/annotatable-reader.md`
  — rather than duplicated in both skill bodies, so they cannot drift apart and
  neither skill pays for them until it needs them.

## [2.8.0] - 2026-08-30

- **`/init` now asks what kind of project this is, and installs only those
  skills.** Vendoring used to be all-or-nothing: every repo carried all 17 shipped
  skills, and each one costs a row in the resident skills listing of every
  session forever, whether or not it ever triggers. Skills are now grouped into
  sections, chosen at install:
  - `core` — init, continue, queue-add, queue-status, github, session-end.
    Always installed; the vendored session protocol names these directly.
  - `workflow` — specify, design, execution, review, ship, gate-check.
  - `python` — python-bootstrap, pypi-release, coverage-gaps, dep-upgrade,
    mutmut-report.
- **New flags: `init.py --profile {minimal,general,python,all}` and
  `--sections a,b`.** The profile is a starting point, written out as an
  editable `[skills]` table in `arsenal/config.toml`. A misspelled section name
  is a hard error rather than a quietly smaller install.
- **Switching a section off is durable.** Set `python = false` under `[skills]`
  and the next `/init` prunes those skills and keeps them pruned — previously,
  deleting a vendored skill by hand was undone by the next session's
  `init.py --silent`.
- **Upgrading changes nothing on its own.** A repo whose `config.toml` predates
  `[skills]` keeps exactly the skills it already has: the sections in use are
  detected and recorded, and the shipped defaults (which have `python` off) are
  applied only to a genuinely fresh install. No skill disappears from an
  existing repo without someone editing the config.
- A repo that opts out of `python` drops 5 of 17 skills from its listing.

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
  - A missing verdict never passes: `verdict` exits 2 when the reviewer returned no
    `VERDICT:` line, and `check` exits 2 with nothing on record.
- **Task PRs now state whether anyone independent looked.** `open_task_pr.sh`
  runs the check and writes the outcome — CLEAR, BLOCK, stale, or never run —
  into the PR body, where whoever merges it will see it.
- **New setting `pre-pr-review`** in `arsenal/config.toml`: `warn` (default —
  the PR opens either way and the outcome is stated in its body), `required`
  (no CLEAR for this tree, no PR), or `off`. Existing repos are unaffected on
  upgrade beyond the new body line; set `required` to make it binding.
- **Where it is enforced.** On task PRs the check is mechanical: `open_task_pr.sh`
  runs it, `required` refuses, and the outcome reaches the PR body whether or not
  anyone remembered the step. On the `execution`, `github` and `ship` paths it is
  an instruction in the workflow — nothing wraps `gh pr create` — so a session
  that skips it opens a PR with no review and no record of the omission. Making
  those paths mechanical requires a `PreToolUse` hook over `gh pr create`, which changes
  every consumer session's ability to open a PR and belongs in its own change.
- The `execution` skill (Step 4b), the `github` skill (pre-PR gate) and the worker agent now run the
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
