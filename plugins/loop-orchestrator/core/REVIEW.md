# Review Rubric

Four-pillar rubric for the loop-orchestrator reviewer agent (cloud Routine).
Apply all four pillars on every non-trivial PR diff.

---

## Pillar 1: Security

- **Input validation**: Check that user-supplied values (task titles, IDs, status strings) are validated before being written to `queue.jsonl` or interpolated into shell commands.
- **Shell injection**: Flag any place where a task ID or payload field is used in a shell `eval`, unquoted variable expansion, or command substitution without sanitisation.
- **Secret exposure**: Confirm no credentials, tokens, or API keys appear in task payloads, commit messages, or `surface_profile.json`.
- **File path safety**: Verify that paths derived from queue data resolve inside the repo root (no `../` traversal).
- **Privilege**: Check that scripts do not request elevated privileges (`sudo`, `su`, `chmod 777`) unless explicitly required and documented.

---

## Pillar 2: Performance

- **Script latency**: `detect_surface.sh` must exit in < 30 s on a cold Web VM. Flag any probe without a timeout.
- **Queue scan**: `queue_eval.sh` is O(n) over `queue.jsonl`; flag any O(n²) or file-re-read patterns introduced inside the loop.
- **Commit churn**: Flag unnecessary `git add` / `git commit` calls that touch files outside `queue.jsonl` or task payloads.
- **Retry backoff**: Verify that retry loops (release.sh) use exponential backoff, not tight polling.

---

## Pillar 3: Test Coverage

- **Happy path**: Every new script must have at least one test covering the success path (e.g., `claim.sh` → `won`).
- **Sad path**: At least one test for the `lost`/failure path (e.g., push rejection in `claim.sh`).
- **Edge cases**: Flag missing tests for empty queue, missing `surface_profile.json`, corrupted `queue.jsonl` lines.
- **Contention**: For any change to `claim.sh` or `queue.jsonl` write logic, verify `tests/claim_contention.sh` still passes.

---

## Pillar 4: Documentation Completeness

- **Script headers**: Every `.sh` file must have a comment block explaining inputs, outputs, and exit codes.
- **Failure modes**: Gotchas in SKILL.md must describe what goes wrong AND why, not just what is prohibited.
- **AGENTS.md**: Any change to the worker loop algorithm must be reflected in `AGENTS.md`.
- **VERSION**: If any `core/` file is changed in a way that would break existing queues (schema change, renamed script), bump `core/VERSION` appropriately and document the migration.
