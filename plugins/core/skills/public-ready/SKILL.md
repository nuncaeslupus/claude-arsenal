---
name: public-ready
description: Audits and hardens a public GitHub repo for strangers — security settings, risky workflows, release-tag rules, SECURITY and CONTRIBUTING files. Use when the user wants a repo safe or ready to share. Not for description, topics or packaging metadata.
argument-hint: "audit|fix|scaffold --repo OWNER/REPO"
user-invocable: true
effort: low
metadata:
  section: publish
---

# public-ready

Gets a public repository ready for people who do not know its owner: nobody can
run code with its secrets, rewrite its history or move a release tag, a
security reporter has a private channel, and a visitor knows whether pull
requests are wanted. One script, three subcommands, each one line per finding.

CANARY: public-ready-loaded-2026-11-26-fb78d23e-092c0fd2802d5512

## Step 1 — Audit

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/audit_public_repo.py" audit --repo OWNER/REPO [--repo OWNER/OTHER]
```

Each line is `PASS`, `GAP` (with the subcommand that closes it) or `NOTE` (a
judgement the script cannot make: a comment-triggered workflow, unpinned
actions, an enabled wiki). It needs `gh` logged in as someone who can read the
repo's settings — the owner or an admin; a cloud session's proxy usually cannot.
`--json` for a machine-readable report, `--fail-on-gaps` for CI.

Also run the bundle's `repo_health.py` (`claude-arsenal/scripts/`) for
description, topics, homepage, licence and releases; this skill does not repeat
those checks.

## Step 2 — Fix the settings

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/audit_public_repo.py" fix --repo OWNER/REPO --dry-run
python3 "${CLAUDE_SKILL_DIR}/scripts/audit_public_repo.py" fix --repo OWNER/REPO
```

Show the user the dry run before the real one: it turns on secret scanning,
push protection, Dependabot alerts and security updates and private
vulnerability reporting; makes fork pull requests wait for approval before
their workflows run; sets the Actions token default to read-only; and adds two
rulesets — no deletion or force-push on the default branch, no deletion or
moving of `v*` tags. The rulesets have no bypass, so they bind the owner too.

## Step 3 — Scaffold the community files

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/audit_public_repo.py" scaffold --repo OWNER/REPO --repo-root . --contributions issues
```

Writes `SECURITY.md`, `CONTRIBUTING.md` and `.github/ISSUE_TEMPLATE/` where
missing and never overwrites. Ask the user which policy applies before writing:
`issues` (default) says pull requests are not accepted for now, `pull-requests`
invites them with review. Commit the files through the normal PR flow.

## Gotchas

- **`fix` skips the read-only token default when a workflow has no
  `permissions:` key.** Such a workflow inherits the default, so switching it
  would break a release or deploy job silently. Add an explicit `permissions:`
  block to the files the skip names, then run `fix` again.
- **A workflow `audit` flags for checking out a pull request's code** on
  `pull_request_target` or `workflow_run` runs a stranger's code with a write
  token and the repo's secrets. Change it to check out the base ref.
- **The social preview image has no API.** `audit` reports it; the user uploads
  it under Settings → General → Social preview.
- **A private repo is skipped.** Secret scanning and rulesets on private repos
  need paid plans, and nothing here matters until strangers can see the repo.
