# Repository housekeeping — licenses and published packages

Read this when `repo_health.py` reports a missing license or names a package
index, and before publishing a package for the first time. Everything else that
script reports carries its own fix command and needs nothing from here.

- [Choosing a license](#choosing-a-license)
- [Publishing a package](#publishing-a-package)

---

## Choosing a license

The owner chooses; the session's job is to ask the questions that decide it and
say what each answer costs. A repository with no license is not "free to use":
by default nobody may copy, modify or redistribute it, which is occasionally
what the owner wants and usually an accident.

Ask these, in order, and stop at the first that settles it:

1. **Should other people be able to reuse this at all?** No → add no license and
   say so in the README, so the gap is a recorded decision.
2. **Must anyone who distributes a changed version publish their changes too?**
   Yes → a copyleft license: GPL-3.0 for programs, AGPL-3.0 when it runs as a
   network service (GPL does not reach a hosted copy), LGPL-3.0 or MPL-2.0 for a
   library that closed-source programs may still link against.
3. **Does the project hold, or expect contributions that carry, patents?**
   Yes, or unsure and the project is substantial → Apache-2.0, which grants a
   patent license and ends it for anyone who sues. Otherwise → MIT, the shortest
   permissive license and the one most readers already know.

Then check two things before writing the file:

- **Dependencies.** A copyleft dependency constrains the license of what links
  it; a permissive project that vendors GPL code is not permissive any more.
- **Consistency.** The same owner's other repositories are a reasonable default,
  and a different choice here should be deliberate.

Write the full license text to `LICENSE` at the repository root with the year and
the copyright holder's name, and set the matching `license` field in the package
metadata. Content that is not code (documentation, data, artwork) is usually
better served by a Creative Commons license; say so when the repo is mostly that.

This is orientation, not legal advice — say that once when the project is
commercial or the answer to question 3 is unclear.

## Publishing a package

Before the first publish, which claims the name permanently:

- **The name is free.** Look it up on the index. A same-named project that does
  not link to this repository belongs to somebody else: pick another name and set
  it in `[project] name` (the import name need not change).
- **`[project]` is complete**: `description`, `readme`, `license`,
  `requires-python`, and `[project.urls]` with at least
  `Repository = "https://github.com/<owner>/<repo>"`. Without the URL the index
  page cannot link back, and `repo_health.py` cannot tell the package is yours.
- **A license file exists** — see above. An index will accept a package with
  none; its users cannot legally install it into anything.

On every release:

- **One version, three places.** The version in `pyproject.toml`, the git tag
  `v<version>` and the release on the repository page name the same commit.
  `repo_health.py` reports a published version with no tag and a tag with no
  release.
- **Publish from CI, not from a laptop.** Use the index's trusted publishing
  (OIDC) so no long-lived upload token is stored anywhere; build from the tagged
  commit so the artifact matches the source a reader can see.
- **Set the repository homepage** to the index page, or to the documentation
  site when there is one.
