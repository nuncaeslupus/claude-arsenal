---
id: t-1acc8e0d
title: "review: test diet — tests to cut or move off every-push CI"
priority: 5
requires: [human:gate]
---

Imported from issue #622

From the test-diet pass of the repo review of 2026-11-11. Nothing was changed; tick or delete as triaged.

**Numbers:** test_files=148, tests=1230, test_lines=21905, source_lines=39938, suite_seconds=70, ci_jobs_per_push=8, ran_suite=True, detail=98 shell test files / 17,854 lines / ~701 PASS blocks vs 6,511 lines shipped shell (2.7:1); 50 pytest files / 4,051 lines / 529 tests vs ~33k lines py (0.12:1). Shell: 221s serial, 58s via `make test` (TEST_JOBS=4, 4 cores). pytest: 7.4s (12s with uv). CI: 7 jobs on a docs-only PR, 8 with the macOS leg, on every push to a PR.

**Estimated saving:** ~80-90% of billed CI minutes per multi-push PR, ~0-10% of wall time per run. Derived: a script-touching PR bills ~7 Linux job-minutes + macOS smoke (~2 min x10 = ~20) = ~27 min per push; a PR with 4 pushes = ~108 min; opened-only trigger + macOS on main only = ~7 min on open + ~27 on merge to main. Test cuts proper: ~450 lines (~2.5% of shell test lines), ~2s. Moving the top-4 slow files off PR path would cut `make test` from ~58s to ~35-40s but is not recommended as first move (sub-minute either way; job rounds to whole minutes).

- The suite itself is not the CI problem: the whole thing is ~58s (shell, 4-way parallel) + ~12s (pytest) on Linux. Everything passes; nothing is flaky in one run.
- The cost is in CI shape: ci.yml fires on every push to a PR (default synchronize), with no concurrency cancel, no paths-ignore, no timeout-minutes, 7-8 separate jobs each billed rounded up to a minute, and a macOS leg (10x billing) on any PR touching a .sh/.py — which is nearly every PR here. This contradicts every point of the repo's own shipped ci-minutes.md ('Host CI: once per PR, not per push').
- Time inside the suite is concentrated: 15 of 98 shell files take 134s of 221s serial; the top 4 (adversarial_review 25.7s, open_task_pr_gates 21.2s, har 14.3s, create_reader 14.1s) are 34%. They are subprocess/git-fixture heavy but test real money/data-loss-adjacent logic — keep, do not cut.
- The `meta` suspicion is only partly true: prose-pinning exists (~60-80 grep-the-SKILL.md assertions; 3 files are almost purely that) but it is ~5% of lines and ~2s of runtime. Cutting it is a maintenance win (fewer wording-change failures), not a speed win.
- pytest layer (529 tests, 7s, 0.12:1) is proportionate; no cuts.
- Single biggest win: change the ci.yml trigger to the block the repo itself recommends (opened/ready_for_review + workflow_dispatch + concurrency) and run macOS only on main; roughly 80-90% of billed minutes for a multi-push PR.

### Cuts and moves
- [ ] **[ci-config] CI runs the full suite on every push to a PR; repo's own ci-minutes.md says not to** (0 tests) — ci.yml uses bare `pull_request: branches:[main]` (opened+synchronize+reopened), so each fix push re-runs 7-8 jobs. The shipped reference plugins/core/skills/init/assets/references/ci-minutes.md prescribes `types: [opened, ready_for_review]`, `paths-ignore`, `concurrency` with cancel-in-progress, `timeout-minutes` and local gates per round; ci.yml has none of the four. `.github/workflows/ci.yml:3-11; plugins/core/skills/init/assets/references/ci-minutes.md (section 'Host CI: once per PR, not per push')`
  - Protection lost: small: pushes after open get no CI verdict until dispatch/merge; `make test` (58s) + `make test-changed` locally cover it, and push-to-main still runs everything before tag-release tags.
  - Action: Adopt the reference's trigger block verbatim: `pull_request: types:[opened, ready_for_review]` + workflow_dispatch (already present) + `concurrency: group: ci-${{ github.event.pull_request.number || github.ref }}, cancel-in-progress: true` + `timeout-minutes: 15` per job. If required checks must stay per-head, at minimum add the concurrency block (cancels superseded runs).
- [ ] **[ci-config] macOS leg (10x billing) runs on almost every PR** (0 tests) — The `changes` job enables macos-latest for any PR touching *.sh, *.py, bin/, scripts/, Makefile, workflows, pyproject or uv.lock — in a repo that is 40k lines of sh/py, that is nearly all PRs. The leg only runs smoke+lint+sync checks (not `make test`), i.e. mostly Python tooling that is OS-independent (ruff, mypy, context-budget, sync-version). `.github/workflows/ci.yml:17-116`
  - Protection lost: small: BSD-userland/bash-3.2 breakage would surface on push-to-main (before tagging, since tag-release requires green CI) instead of on the PR. Note the macOS leg does not run the shell behaviour tests at all, so it catches less of that than its comment claims.
  - Action: Run macOS only on push to main / workflow_dispatch (set mac=false for all pull_request events), or narrow the filter to shipped `plugins/*/skills/**/*.sh` and `**/bin/**`. On macOS run only `make smoke`; the lint/sync/budget steps add nothing a Linux run did not prove.
- [ ] **[ci-config] Three uv-toolchain jobs + two glue jobs could be one or two** (0 tests) — smoke, unit-tests and queue-doctor each check out, install uv, install Python 3.12 separately; unit-tests then runs 12s of pytest and queue-doctor a single script. With `changes`, `smoke-macos-skipped` and `version-bump` that is 6 Linux jobs billed >= 1 min each for ~2 min of real work beside the `core tests` job. `.github/workflows/ci.yml jobs smoke/unit-tests/queue-doctor/version-bump`
  - Protection lost: none — same commands, fewer runners. `core tests` must stay separate (bare python3, by design).
  - Action: Fold `make test-units` and `make queue-doctor` into the Linux smoke job as steps (needs issues:read on that job); fold version-bump into `changes` (already a PR-only job with the file list). 7 jobs -> 3-4.
- [ ] **[ci-config] No path filter: docs-only PRs still run the full shell + pytest suites** (98 tests) — A PR touching only docs/ or CLAUDE.md skips macOS but still runs `make test` (98 files) and pytest. The repo already ships select_tests.py and a `make test-changed` target that computes exactly the affected set, plus 22 tree-scanning tests it always includes — CI does not use it. `.github/workflows/ci.yml:118-141; Makefile:149-161`
  - Protection lost: small: select_tests.py cannot follow imports (documented); keep full `make test` on push to main as the bar.
  - Action: On pull_request run `make test-changed BASE=origin/${{ github.base_ref }}` (fetch-depth: 0); on push to main run `make test`. Or simply `paths-ignore: ['docs/**','*.md']` on the test jobs.
- [ ] **[slow-tier] Four subprocess-heavy files are a third of suite time** (85 tests) — adversarial_review_test.sh 25.7s (10 git inits, 78 bash launches, 41 cases), open_task_pr_gates_test.sh 21.2s (includes a signal test polling a `sleep 30` gate), har_test.sh 14.3s, create_reader_test.sh 14.1s = 75s of 221s serial. They set the floor for `make test` wall time on 4 cores. `plugins/core/tests/{adversarial_review,open_task_pr_gates,har,create_reader}_test.sh`
  - Protection lost: none if kept on main + path-triggered on PRs (they map 1:1 to adversarial_review.sh, open_task_pr.sh, capture_har.py, create_reader.py, which select_tests.py resolves by name).
  - Action: No cut. If PR CI switches to `make test-changed` these drop out automatically unless their script changed. Optionally reuse one git fixture across cases in adversarial_review_test.sh (10 `git init`s) and split the file in two so xargs -P balances better.
- [ ] **[meta] Pure prose-pinning tests: grep SKILL.md/reference wording and char ceilings** (9 tests) — instruction_economy_test.sh (77 lines) only greps three .md files for exact phrases ('Operational checklist applied at the gate', '### The two passes'), counts 9 list items and enforces hand-set char ceilings (12800/5000/4900) that duplicate `make context-budget`/`make audit`. spawned_worker_mode_test.sh (114 lines) greps a prompt template, worker.md and orchestrator-tick.md for words like 'spawned', 'separate', and greps open_task_pr.sh source for `^exit 0` after a line — no script is executed. Any rewording fails them; no behaviour bug can. `plugins/repo-audit/tests/instruction_economy_test.sh; plugins/core/tests/spawned_worker_mode_test.sh`
  - Protection lost: small: a future edit could drop a sentence telling spawned workers what to skip; that is a review question (and skill-workshop's rubric), not a CI one. The push-only `exit 0`/`branch:<name>` contract is already executed for real in open_task_pr_test.sh/open_task_pr_gates_test.sh.
  - Action: Delete both files (191 lines). Keep the size ceilings only in context_budget.py if wanted.
- [ ] **[meta] Prose-grep blocks appended to otherwise behavioural tests** (50 tests) — Several behaviour tests end with a block asserting that docs mention the feature: compact_resume_test.sh:26,133-135 ('Resume' in execution/SKILL.md, '## Resume' and 'After compaction mid-task' in AGENTS.md), merge_policy_routing_test.sh:58-107 (9 phrase greps such as 'counts as a review', 'cannot report', 'mergeStateStatus'), quota_seam_test.sh:129+ (doc mentions knobs), gate_bash_test.sh (2 SKILL greps), sync_plan_graph_test.sh (TEMPLATE greps). Roughly 40-60 assertions across ~10 files. `plugins/core/tests/compact_resume_test.sh:26,133-135; plugins/core/tests/merge_policy_routing_test.sh:58-107; plugins/core/tests/quota_seam_test.sh:129-147; others via grep below`
  - Protection lost: small: doc/implementation drift on wording. Keep the one genuinely structural check in merge_policy_routing_test.sh:67-92 (every config enum value parsed from arsenal_config.py has a row in the policy table) — that is a real sync check, not wording.
  - Action: Strip the phrase-grep tails (~250 lines); keep enum-vs-table and link/anchor checks. Do not add new ones: CLAUDE.md's 'write a test for the wording' habit is what the owner suspects, and here it is visible but small.
- [ ] **[meta] Doc linters run as tests in the bare-python job** (5 tests) — bundle_refs_test.sh (161), docs_anchors_test.sh (69), doc_script_paths_test.sh (67), section_listings_test.sh (67), generic_examples_test.sh (76) are tree-wide doc linters (dead links, anchors, script paths named in docs exist, AGENTS.md <= 250 lines, leaked private names). Useful and ~3s total, but they are lint, and they ride along with every `make test-changed` selection as TREE_TESTS. `plugins/core/tests/bundle_refs_test.sh; plugins/core/tests/generic_examples_test.sh; scripts/{docs_anchors,doc_script_paths,section_listings}_test.sh`
  - Protection lost: none — moved, not removed.
  - Action: Keep. Optionally move under a `make lint-docs` target called from the smoke job so `make test` means behaviour only. Lowest priority.
- [ ] **[ci-config] queue-doctor job is a whole runner for a near-empty backlog** (0 tests) — A dedicated job (uv install + python install + gh fetches) audits arsenal/tasks/, which holds one task file; CLAUDE.md itself notes the check passes vacuously when empty. `.github/workflows/ci.yml:209-end; arsenal/tasks/`
  - Protection lost: none if folded into smoke as a step.
  - Action: Make it a step of the Linux smoke job, or path-filter the job to `arsenal/tasks/**` + push-to-main.

### Keep
- pytest layer: 529 tests / 4,051 lines / 7.4s for ~33k lines of Python (har/, bugreport/, skill-workshop style rules) — proportionate, slowest test 0.71s
- adversarial_review_test.sh, open_task_pr_gates_test.sh, gate_run_test.sh, gate_integrity_test.sh, gate_evidence_test.sh — gate/receipt/archive-undo logic incl. the SIGTERM-mid-gate case; data-loss-adjacent (task file archived as merged with nothing merged)
- arsenal_migrate_test.sh / arsenal_migrate_safety_test.sh — verifies host files are not overwritten on migration (data loss)
- task_select_test.sh (772 lines, 2.5s) and queue_hooks_test.sh (822 lines, 3.9s) — large but fast; real branch logic in task ordering and the workflow planners that cannot run in this repo's Actions
- check_update_test.sh, rebase_stack_test.sh, init_test.sh, init_upgrade_test.sh — consumer-facing update/vendor paths against real temp git repos
- scripts/tag_guard_test.sh, sync_version_test.sh, context_budget_test.sh — release gate and budget tooling, sub-second
- skill-workshop gate_bash_test.sh / gate_failclosed_test.sh — security-ish pre-edit hook fail-closed behaviour
- merge_policy_routing_test.sh:67-92 enum-vs-doc-table sync check

## Acceptance gate

<!-- This task came from an issue, so its "gate" is prose. Write a real check
     below, then DELETE the `requires: [human:gate]` line in the front matter.
     Until that line is gone the selector will not offer this task, which is
     deliberate: a prose gate runs nothing, and a gate that runs nothing passes
     everything. -->

```bash
# arsenal:gate-placeholder — replace with the real check; it may land in this task's own PR
false
```
