# Adversarial checklist

Load before the break-it pass. Where the fan-out pass explains a design,
this pass tries to falsify it. Work through what's relevant to the target
repo — not every question fits every project.

## The questions

- **Deployment/runtime surface differences.** Does this behave the same
  everywhere it claims to run — a local machine, a hosted/cloud runner, CI,
  a fork of the repo? Name the specific capability that's missing on each
  surface, not just "it might differ."
- **The automation-off case.** What happens if the CI/automation layer is
  disabled, was never set up, or is down? Trace the cascade concretely:
  which specific thing silently stops happening, and would anyone notice
  before it caused a real problem?
- **Configuration completeness.** What's configurable, and is anything
  declared-but-dead — accepted by a config loader or schema but never
  actually read by the code path it's supposed to control? This is
  checkable, not just askable: grep for where a config key is *read*, not
  just where it's *declared*.
- **Lock-in.** What is this locked into — one vendor, one host, one OS, one
  language — and is that ever stated, or does the reader have to infer it
  from the absence of any alternative path?
- **Update/versioning footguns.** Does updating ever silently lose local
  work, or silently do nothing while reporting success? Read the update or
  migration doc's own "gotchas" section first if one exists — projects that
  are honest about this often already know more than the README admits.
- **Structurally missing pieces.** What would a mature, comparable project
  usually have that this one doesn't — ownership/contact files, a security
  policy, contribution templates, a cost model for anything that spends
  real money or API budget, populated release notes? Report absence
  plainly; don't guess at settings you can't see from the filesystem (e.g.
  branch protection rules) — say they're unverifiable from here instead.
- **Write-path failure behavior.** Read paths often fail gracefully by
  design. Check the *write* paths specifically — the calls that mutate
  external state — for timeouts, retries, and what happens on a partial
  failure mid-operation.
- **Claims about automatic behavior.** Any doc that says something happens
  "automatically" or "self-heals" is a claim to trace, not to repeat. Find
  the actual code path. If it only exists inside an optional component
  (an optional workflow, a feature flag, a plan tier), the claim is
  overstated for anyone without that component — say so precisely.

## What counts as a finding here

A genuine inconsistency between a doc's claim and the code, a real gap with
a concrete failure scenario, or an explicit "checked X, found no issue" —
each is worth reporting. A vague "this could theoretically be a problem"
with no trace to back it is not; either trace it or drop it.
