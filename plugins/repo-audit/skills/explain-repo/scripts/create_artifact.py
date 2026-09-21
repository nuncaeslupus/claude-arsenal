#!/usr/bin/env python3
"""Render a repo-analysis artifact's HTML from structured content.

DUPLICATED ACROSS SKILLS:
- plugins/repo-audit/skills/repo-audit/scripts/create_artifact.py (canonical)
- plugins/repo-audit/skills/explain-repo/scripts/create_artifact.py

Keep both copies in sync. Update via skill-workshop's sync_duplicates.py

Takes the deterministic part of building a repo-audit or explain-repo
output — the page shell, theme tokens, Q&A accordion markup, tables, and
the findings ledger — off the model's plate, so a run doesn't re-derive
several hundred lines of CSS/HTML from scratch. The model still writes the
actual content (the `--input` JSON); this script only lays it out.

The default palette and type pairing are a sensible, theme-aware starting
point — swap the CSS constants below for something subject-specific when
the artifact's stakes call for real editorial design (see the
`artifact-design` skill). Structural correctness (responsive layout, light
+ dark tokens, balanced markup) is what this script guarantees; taste is
not.

Input JSON shape:
{
  "title": "Interviewing <repo>",
  "description": "one sentence for the gallery card",
  "sections": [
    {
      "id": "queue", "tag": "queue", "heading": "How work gets claimed",
      "subtitle": "optional one-line sub-head",
      "tone": "default" | "break",
      "qa": [{"q": "...", "a": ["paragraph one", "paragraph two"]}],
      "table": {"headers": [...], "rows": [[...], ...]}
    }
  ],
  "ledger": [
    {"finding": "...", "where": "path/or/component",
     "status": "fixed" | "queued" | "issue" | "flagged"}
  ]
}

`ledger` is optional and typically only present in a repo-audit report;
explain-repo's narrative documents usually omit it.

Exit codes:
  0 — written
  1 — input JSON invalid or missing required fields
  2 — error (bad paths, unreadable input)
"""

from __future__ import annotations

import argparse
import html
import json
import sys
from pathlib import Path

STATUS_LABEL = {
    "fixed": "fixed",
    "queued": "queued",
    "issue": "issue filed",
    "flagged": "flagged — your call",
}
REQUIRED_SECTION_KEYS = {"id", "tag", "heading"}

CSS = """
:root{
  --bg:#f4f4f2; --surface:#ffffff; --surface-2:#eaeae6;
  --ink:#1c1e1b; --ink-2:#585b56; --ink-3:#7c7f79;
  --border:#dadad4; --border-2:#c6c7c0;
  --accent:#3b6e5e; --accent-ink:#2a4f43;
  --good:#2c7a4e; --good-soft:#dcefe3;
  --warn:#96651b; --warn-soft:#f5e8cf;
  --bad:#ad3a30; --bad-soft:#f6e1de;
}
@media (prefers-color-scheme: dark){
  :root:not([data-theme="light"]){
    --bg:#15181a; --surface:#1b1f21; --surface-2:#23282a;
    --ink:#e9eae4; --ink-2:#b0b6ac; --ink-3:#868d86;
    --border:#343b3c; --border-2:#40484a;
    --accent:#5fa88f; --accent-ink:#8ecab5;
    --good:#5cbb8a; --good-soft:#1c2e26;
    --warn:#dba548; --warn-soft:#332a17;
    --bad:#e27b71; --bad-soft:#332120;
  }
}
:root[data-theme="dark"]{
  --bg:#15181a; --surface:#1b1f21; --surface-2:#23282a;
  --ink:#e9eae4; --ink-2:#b0b6ac; --ink-3:#868d86;
  --border:#343b3c; --border-2:#40484a;
  --accent:#5fa88f; --accent-ink:#8ecab5;
  --good:#5cbb8a; --good-soft:#1c2e26;
  --warn:#dba548; --warn-soft:#332a17;
  --bad:#e27b71; --bad-soft:#332120;
}
*{box-sizing:border-box;}
body{background:var(--bg); color:var(--ink); font-family:system-ui,sans-serif;
  padding-inline:16px;}
.page{max-width:1100px; margin:0 auto;}
header.hero{padding-block:2.2rem 1.4rem; border-bottom:1px solid var(--border);
  margin-bottom:1.6rem;}
h1.title{font-size:clamp(1.8rem,4.5vw,2.6rem); margin:0 0 .6rem;}
.dek{color:var(--ink-2); max-width:44rem; line-height:1.5; margin:0;}
.layout{display:grid; grid-template-columns:190px minmax(0,1fr); gap:2rem;
  align-items:start;}
@media (max-width:860px){ .layout{grid-template-columns:1fr;} }
nav.toc{position:sticky; top:14px; display:flex; flex-direction:column; gap:.15rem;
  font-size:.86rem;}
nav.toc a{color:var(--ink-2); text-decoration:none; padding:.35rem .55rem; border-radius:7px;}
nav.toc a:hover{background:var(--surface-2); color:var(--ink);}
@media (max-width:860px){
  nav.toc{position:sticky; top:0; background:var(--bg); z-index:5; flex-direction:row;
    overflow-x:auto; padding-block:.5rem; margin-bottom:.4rem;
    border-bottom:1px solid var(--border);}
  nav.toc a{white-space:nowrap;}
}
section.block{margin-bottom:2.2rem; scroll-margin-top:1rem;}
.tag{font-size:.7rem; font-weight:600; background:var(--surface-2); color:var(--ink-2);
  border:1px solid var(--border-2); border-radius:5px; padding:.15rem .45rem;}
.block.tone-break .tag{background:var(--warn-soft); color:var(--warn); border-color:var(--warn);}
.block.tone-break h2{color:var(--warn);}
h2.h{font-size:1.35rem; margin:.3rem 0 .3rem; display:inline-block;}
.block-sub{color:var(--ink-3); font-size:.9rem; margin:.3rem 0 1.1rem; max-width:44rem;}
details.qa{background:var(--surface); border:1px solid var(--border); border-radius:10px;
  padding:.9rem 1.05rem; margin-bottom:.7rem;}
summary.q{font-weight:600; cursor:pointer; list-style:none;}
summary.q::-webkit-details-marker{display:none;}
.a{padding-left:1.1rem; border-left:2px solid var(--border); margin-top:.55rem;}
.a p{margin:0 0 .6rem;} .a p:last-child{margin-bottom:0;}
.twrap{overflow-x:auto; margin:1rem 0; border:1px solid var(--border); border-radius:10px;}
table{border-collapse:collapse; width:100%; font-size:.85rem; min-width:420px;}
th,td{text-align:left; padding:.5rem .7rem; border-bottom:1px solid var(--border);
  vertical-align:top;}
thead th{background:var(--surface-2); font-size:.72rem; text-transform:uppercase;
  color:var(--ink-2);}
tbody tr:last-child td{border-bottom:none;}
.pill{display:inline-block; font-size:.7rem; font-weight:600; padding:.1rem .5rem;
  border-radius:99px;}
.pill.fixed{background:var(--good-soft); color:var(--good);}
.pill.queued{background:var(--warn-soft); color:var(--warn);}
.pill.issue{background:var(--warn-soft); color:var(--warn);}
.pill.flagged{background:var(--bad-soft); color:var(--bad);}
code{font-family:ui-monospace,monospace; background:var(--surface-2);
  border:1px solid var(--border-2); border-radius:4px; padding:.05em .35em;
  font-size:.87em; color:var(--accent-ink);}
"""


def esc(s: str) -> str:
    return html.escape(str(s), quote=False)


def render_qa(qa: list[dict]) -> str:
    parts = []
    for item in qa:
        paras = "".join(f"<p>{esc(p)}</p>" for p in item.get("a", []))
        parts.append(
            f'<details class="qa"><summary class="q">{esc(item["q"])}</summary>'
            f'<div class="a">{paras}</div></details>'
        )
    return "\n".join(parts)


def render_table(table: dict) -> str:
    heads = "".join(f"<th>{esc(h)}</th>" for h in table.get("headers", []))
    rows = "".join(
        "<tr>" + "".join(f"<td>{esc(c)}</td>" for c in row) + "</tr>"
        for row in table.get("rows", [])
    )
    return (
        f'<div class="twrap"><table><thead><tr>{heads}</tr></thead>'
        f"<tbody>{rows}</tbody></table></div>"
    )


def render_section(section: dict) -> str:
    tone = " tone-break" if section.get("tone") == "break" else ""
    sub = f'<p class="block-sub">{esc(section["subtitle"])}</p>' if section.get("subtitle") else ""
    body = render_qa(section.get("qa", []))
    table = render_table(section["table"]) if section.get("table") else ""
    return (
        f'<section class="block{tone}" id="{esc(section["id"])}">'
        f'<span class="tag">{esc(section["tag"])}</span> '
        f'<h2 class="h">{esc(section["heading"])}</h2>'
        f"{sub}{table}{body}</section>"
    )


def render_toc(sections: list[dict]) -> str:
    links = "".join(f'<a href="#{esc(s["id"])}">{esc(s["heading"])}</a>' for s in sections)
    return f'<nav class="toc">{links}</nav>'


def render_ledger(ledger: list[dict]) -> str:
    if not ledger:
        return ""

    def _row(row: dict) -> str:
        status = row["status"]
        label = esc(STATUS_LABEL.get(status, status))
        return (
            f"<tr><td>{esc(row['finding'])}</td>"
            f"<td><code>{esc(row['where'])}</code></td>"
            f'<td><span class="pill {esc(status)}">{label}</span></td></tr>'
        )

    rows = "".join(_row(row) for row in ledger)
    return (
        '<section class="block" id="ledger"><span class="tag">ledger</span> '
        '<h2 class="h">Findings</h2>'
        f'<div class="twrap"><table><thead><tr><th>Finding</th><th>Where</th><th></th></tr></thead>'
        f"<tbody>{rows}</tbody></table></div></section>"
    )


def validate(data: dict) -> list[str]:
    errors = []
    if not data.get("title"):
        errors.append("missing required field: title")
    if not data.get("sections"):
        errors.append("missing required field: sections (must be non-empty)")
    for i, section in enumerate(data.get("sections", [])):
        missing = REQUIRED_SECTION_KEYS - section.keys()
        if missing:
            errors.append(f"sections[{i}] missing keys: {sorted(missing)}")
    return errors


def render(data: dict) -> str:
    sections_html = "\n".join(render_section(s) for s in data["sections"])
    ledger_html = render_ledger(data.get("ledger", []))
    toc_html = render_toc(data["sections"])
    description = esc(data.get("description", ""))
    return f"""<title>{esc(data["title"])}</title>
<style>{CSS}</style>
<div class="page">
  <header class="hero">
    <h1 class="title">{esc(data["title"])}</h1>
    <p class="dek">{description}</p>
  </header>
  <div class="layout">
    {toc_html}
    <main>
      {sections_html}
      {ledger_html}
    </main>
  </div>
</div>
"""


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--input", required=True, help="structured findings JSON (see module docstring)")
    p.add_argument("--output", required=True, help="target HTML file path")
    args = p.parse_args()

    try:
        data = json.loads(Path(args.input).read_text())
    except (OSError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"✗ could not read {args.input}: {exc}\n")
        return 2

    errors = validate(data)
    if errors:
        for err in errors:
            sys.stderr.write(f"✗ {err}\n")
        return 1

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(render(data))
    n_sections = len(data["sections"])
    n_ledger = len(data.get("ledger", []))
    sys.stderr.write(f"✓ wrote {output} ({n_sections} sections, {n_ledger} ledger rows)\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
