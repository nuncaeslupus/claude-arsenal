---
name: har
description: Use whenever a HAR capture has to be read, searched, filtered or turned into a scraper — which request returned a string seen on the page, which parameter pages the results, what to send to reproduce it. Triggers — "I have a HAR", "which request returns this". Do NOT use to capture a HAR (the browser's job) or to parse a JSON/HTML file with no capture around it.
argument-hint: "--input capture.har"
user-invocable: true
metadata:
  section: extract
  type: tool
---

# HAR analysis

CANARY: har-loaded-2026-08-30-7f3a91c4-2b6d4e8a1c9f0b73

A browser capture holds the complete network truth of a session: every request,
its headers and parameters, every response body. It is also 5–500 MB of JSON, so
the one thing nobody can do with it is read it. The few hundred bytes that
matter — which endpoint returns the data, which parameter pages it, which header
authenticates it — are reachable only through a script.

## When to load

Load this skill when:

- A `.har` file has to be searched, summarised, filtered or reduced.
- The question is "which request returned this?" — a string seen on a page, and
  no idea which of 400 requests produced it.
- A scraper is being built from a captured session, and what is needed is the
  endpoint, its parameters, and a working request.
- A capture has to be made small or safe enough to commit or hand over.

Do not load it to capture a HAR, or to parse a JSON/HTML file that did not come
out of one.

## Start here

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/analyze_har.py" --input capture.har
```

The overview says whether the site has an API worth reading at all — the
XHR/JSON count is the number that decides whether the next hour is spent on
endpoints or on rendered HTML.

## The scripts

| Script | What it answers |
|---|---|
| `analyze_har.py` | What is in here — entries, hosts, resource types, status histogram, and the API-shaped request count. `--index` builds the sidecar every other command reads |
| `validate_har.py` | Is this capture usable, and what did its exporter leave out |

Every script takes `--input`, accepts `--json` for chaining, and caps its own
output. Run `--help` on either for every flag.

Searching, extraction, reproduction and comparison are the next stages of
`docs/design/0002-har-analysis-toolkit-plan.md`; this bundle ships the two above
and the index they are built on. Nothing here promises a command it does not
carry — check `--help`.

## Build the index first

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/analyze_har.py" --input capture.har --index
```

It writes `capture.har.index.jsonl` beside the capture: one line per entry, no
bodies. Every filter, statistic and listing then runs against that alone, which
is what keeps a query on a 200 MB capture sub-second. It is rebuilt
automatically when the capture changes, and belongs in `.gitignore`.

Add `--verify-offsets` when a body ever looks like it belongs to a different
entry: it re-parses every entry from its recorded byte offset and reports any
that disagree.

## Two rules that shape every output

**Small by default, complete on request.** Every command caps its output at 20
rows and 4096 bytes, whichever binds first, and says which one did the dropping.
`--limit 0` removes both caps; `--output PATH` writes the complete result to a
file in full fidelity. A reduced answer that cannot be expanded is a tool that
decides what may be asked.

**Safe by default.** Anything written to disk — the index sidecar included —
has its auth headers, cookies and token-shaped parameters replaced with
`<redacted:ab12cd34>`, where the suffix is a salted fingerprint: equal values
stay equal so header analysis still works, and nothing about the original is
recoverable. URL userinfo and fragments are removed outright, because an OAuth
implicit flow puts a live token in a fragment and no name-matching rule would
ever look there.

**"No body captured" is not "no match".** Some exporters and some cached entries
save no body at all. The tool reports the two differently; treat a
`no body captured` as a reason to re-export, not as evidence the endpoint is
elsewhere.

## When a search finds nothing

Run `validate_har.py --input capture.har` before assuming the endpoint is not
there. It reports what the exporter actually recorded — whether bodies are
present, whether they are base64, whether `_resourceType` exists — which
separates a bad capture from a bad query. Bodies are frequently base64-encoded,
where a plain `grep` of the raw file silently misses every hit; every command
here decodes first.
