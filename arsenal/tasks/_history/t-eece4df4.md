---
id: t-eece4df4
title: "review: repo_slug only understands four literal github.com URL shapes"
priority: 5
status: merged
---

Imported from issue #591

**Severity:** medium · **Confidence:** high · **Category:** security

**Where:** `plugins/core/skills/init/assets/bin/github_channel.sh:39-48, plugins/core/skills/init/assets/bin/claim_task.sh:91,136,145`

### Finding
github_channel.sh strips fixed prefixes; a remote such as https://x-access-token:TOKEN@github.com/o/r.git, an ssh host alias (git@gh-work:o/r.git) or a trailing slash is returned unchanged as the 'slug'. Every API path is then garbage, and claim_task.sh prints `manual POST /repos/<url-with-token>/git/refs` to the transcript.

### Evidence
Read the function: only `git@github.com:`, `ssh://git@github.com/`, `https://github.com/`, `http://github.com/` are stripped and no validation follows; `--slug` on this repo's plain https origin works.

### Suggested direction
Parse with a regex that drops userinfo and accepts any host, validate the result as owner/repo, and fail otherwise. branch_protection.py already has its own _slug_from_url; share one.

_From the full repo review of 2026-11-11 (finding #7). Not fixed yet; verify before acting._

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
