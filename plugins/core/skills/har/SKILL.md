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

## The two-command answer

Almost every session here is the same shape. Paste a string that was visible on
the page; get back the request that returned it, and its shape.

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/query_har.py" --input capture.har \
    --response-match "Senior Rust Engineer"
python3 "${CLAUDE_SKILL_DIR}/scripts/query_har.py" --input capture.har --show 4 --schema
```

The first names the entry. The second prints the body's *shape* — keys, types,
array lengths — which is usually the actual question and is often 100× smaller
than the body.

Before either, when the capture is unfamiliar:

```bash
python3 "${CLAUDE_SKILL_DIR}/scripts/analyze_har.py" --input capture.har
```

The overview's XHR/JSON count is the number that decides whether the next hour
is spent on endpoints or on rendered HTML.

## The scripts

| Script | What it answers |
|---|---|
| `query_har.py` | Which entries match, what one of them contains, and getting bodies out |
| `analyze_har.py` | What is in here. `--index` builds the sidecar every other command reads |
| `validate_har.py` | Is this capture usable, and what did its exporter leave out |

Every script takes `--input`, accepts `--json` for chaining, and caps its own
output. Run `--help` for every flag.

Reproduction (`create_repro.py`), derived captures (`create_har.py`) and
comparison (`compare_har.py`) are later stages of
`docs/design/0002-har-analysis-toolkit-plan.md`. Nothing here promises a command
it does not carry — check `--help`.

## Selecting entries

One grammar, shared by every command that picks entries. All of it composes as
AND, and `--invert` negates the whole selection.

```bash
--url REGEX  --host REGEX  --method GET  --status 2xx|404|400-499  --mime REGEX
--type xhr   --min-size N  --max-size N  --slower-than MS  --page ID
--param NAME[=REGEX]       --has-header NAME[=REGEX]
--body-match REGEX         --response-match REGEX
--since ISO  --until ISO   --from-cache | --no-cache | --unknown-cache
```

Two of those deserve their own note.

**`--response-match` is the one to reach for first.** It is the operation this
toolkit exists for: a string seen on the page in, the request that returned it
out.

**The cache flags are three, not two.** `_fromCache` is `true`, `false`, or
*the exporter never recorded it*, so `--no-cache` selects `false` **only** and
`--unknown-cache` is its own flag. Folding the third state into `false` would
make the same command mean different things on a Chrome capture and a
Playwright one, silently.

## Getting data out

| Flag | Effect |
|---|---|
| `--show IDX` | One entry in full: request line, headers, query, bodies, real values |
| `--schema` | A JSON body's shape — keys, types, array lengths — instead of its content |
| `--json-path a.b[*].c` | Pull values out of a JSON body |
| `--css h1` / `--xpath ./item` | Pull from an HTML or XML body. A selector this does not support is refused **by name**, never silently unmatched |
| `--extract-body --output-dir DIR` | Decode and write every matching body to a file |

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
decides what may be asked. `--json` stays parseable under the cap by dropping
whole entries from a fixed envelope, never by cutting bytes mid-structure.

**Safe by default.** Anything written to disk — the index sidecar included —
has its auth headers, cookies and token-shaped parameters replaced with
`<redacted:ab12cd34>`, where the suffix is a salted fingerprint: equal values
stay equal so header analysis still works, and nothing about the original is
recoverable. URL userinfo and fragments are removed outright, because an OAuth
implicit flow puts a live token in a fragment and no name-matching rule would
ever look there. `--show` prints real values — that is an operator reading their
own capture — and a value pattern against a redacted header needs `--secrets`,
because the index cannot answer it. **Extracted response bodies are outside this
guarantee:** a body is unbounded text that may carry a credential anywhere in
it, so an extracted body is as sensitive as the capture and is not a fixture
until someone has read it.

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
