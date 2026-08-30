# HAR Analysis Toolkit — Specification (annotated edition)

> Generated 2026-08-30. This is the document with a **note slot** after every section. Read it in any Markdown app. To annotate, replace the `_(your notes…)_` placeholder under any section. When done, send the file back — notes are acted on.

---

# 0002 Har Analysis Toolkit

## Preamble & scope

**Status:** Proposed — awaiting decision before implementation
**Depends on:** skill sections (#273, v2.8.0) — this is the first skill to live
outside the default install set.

> **Why this exists.** A browser capture already contains the complete network
> truth of a scraping session: every request, its headers and parameters, and
> every response body. It is also 5–500 MB of JSON, so the one thing nobody can
> do with a HAR is read it. The few hundred bytes that matter — which endpoint
> returns the data, which parameter pages it, which header authenticates it —
> are reachable only through a script. This document specifies that script set.

<!-- -->

> **✎ Notes** · `SPEC · intro`
> _(your notes here — replace this line)_

## §1 Requirements

Stated by the maintainer, treated here as non-negotiable:

1. **Scripts, not reading.** Every answer comes from a deterministic script that
   returns only the result. A session may judge the result; it never pays tokens
   for the search.
2. **Anything a HAR contains must be reachable.** Filtering and search by URL,
   by request parameter, by response content, by status code — and the same for
   everything else the format carries.
3. **Output is reduced by default.** Statistics, URL lists, error tallies,
   bodies written to files. Never a body on stdout that nobody asked for.
4. **Mutation is in scope.** Filtering, then deleting or replacing what was
   filtered, producing a smaller or safer HAR.
5. **It serves scraper construction.** The end of a session is a working
   request, not a report.
6. **Replay is anticipated, not built yet.** v1 must not foreclose it.

<!-- -->

> **✎ Notes** · `SPEC §1`
> _(your notes here — replace this line)_

## §2 Problem statement

Building a scraper for an unfamiliar site currently means driving a browser and
reading rendered pages into context — expensive, non-deterministic, and it has
to be repeated whenever the question changes slightly. Meanwhile a single
DevTools "Save all as HAR" already holds the answer. The gap is not information;
it is that no tool reduces a HAR to the part that matters. As a result a HAR is
either not used at all, or used by grepping raw JSON, which finds strings but
cannot answer structural questions ("which of these 400 requests returned JSON
containing this job title, and what parameters distinguish it from its
neighbours?").

This is a standalone skill with no dependency on any project that happens to
want it. The work it serves is generic: a session pointed at an unfamiliar site
needs to find which request returns the data, what parameters drive it, and what
headers authenticate it — whether the outcome is a scraper, a one-off
extraction, or a diagnosis of why a page loads the way it does.

Concretely, the goal is that a session can do that analysis **from a capture
instead of a browser**, and reach a working request faster and more cheaply than
by driving one.

<!-- -->

> **✎ Notes** · `SPEC §2`
> _(your notes here — replace this line)_

### Success criteria (measurable)

| # | Criterion | Threshold |
|---|---|---|
| SC1 | Default output of any command, every mode | ≤ 4096 bytes hard cap, enforced by truncation, not only by `--limit` |
| SC2 | Index build, 200 MB HAR | ≤ 30 s wall, peak RSS ≤ 400 MB |
| SC3 | Any index-only query, 50k-entry / 200 MB capture | ≤ 1 s, peak RSS ≤ 150 MB — linear in entry count, flat in body bytes |
| SC4 | Commands to locate the endpoint behind a known on-page string | ≤ 2 |
| SC5 | Secrets in the *bounded* fields (headers, cookies, query and body params) of anything written, without `--secrets` | 0 (asserted by test) — extracted response bodies are explicitly outside this guarantee, see § 5.4 |
| SC6 | `create_repro.py --format curl` on a public GET | reproduces the captured status |
| SC7 | Resident listing cost | ≤ 130 tokens for repos with the `extract` section, 0 for those without |

SC5 and SC7 are the two that fail silently if nobody asserts them, so both get
a test rather than a review note. SC3 is deliberately *not* stated as "independent
of HAR size": scanning a JSONL sidecar is linear in entry count. What the index
buys is independence from **body bytes**, which is where a HAR's size actually
lives, so the criterion is a bounded benchmark against a named capture rather
than a complexity claim that would not survive contact with a 500k-entry file.

<!-- -->

> **✎ Notes** · `SPEC › Success criteria (measurable)`
> _(your notes here — replace this line)_

## §3 What a HAR contains

HAR 1.2 is a JSON document with one `log` object. This is the complete raw
material, and the column on the right is what makes each field worth indexing.

<!-- -->

> **✎ Notes** · `SPEC §3`
> _(your notes here — replace this line)_

### §3.1 Top level

| Field | Contents | Useful for |
|---|---|---|
| `log.version` | `"1.2"` | validation |
| `log.creator` | name/version of the exporter | provenance — Chrome, Firefox, mitmproxy and Playwright differ in what they omit |
| `log.browser` | browser name/version | provenance |
| `log.pages[]` | `id`, `title`, `startedDateTime`, `pageTimings` | page boundaries; scoping a query to one navigation |
| `log.entries[]` | the requests | everything below |

<!-- -->

> **✎ Notes** · `SPEC §3.1`
> _(your notes here — replace this line)_

### §3.2 Per entry

| Field | Contents | Useful for |
|---|---|---|
| `pageref` | owning page id | scoping |
| `startedDateTime`, `time` | start, total ms | ordering, time-window filters, slow-request stats |
| `request.method` | GET/POST/… | filtering |
| `request.url` | full URL | the primary search axis |
| `request.httpVersion` | h1/h2/h3 | rarely; reproduction fidelity |
| `request.queryString[]` | parsed `name`/`value` | **parameter search; pagination discovery** |
| `request.headers[]` | all request headers | **auth discovery; reproduction** |
| `request.cookies[]` | parsed cookies | session analysis; reproduction |
| `request.postData` | `mimeType`, `text`, parsed `params[]` | **GraphQL/JSON POST bodies — search and reproduction** |
| `request.headersSize`, `bodySize` | byte counts | statistics |
| `response.status`, `statusText` | code and message | **error tallies** |
| `response.headers[]` | response headers | content type, caching, `Set-Cookie`, rate-limit headers |
| `response.cookies[]` | cookies set | session analysis |
| `response.content` | `size`, `compression`, `mimeType`, `text`, `encoding` | **the payload — search and extraction** |
| `response.redirectURL` | redirect target | redirect chains |
| `cache` | before/after cache state | rarely |
| `timings` | `blocked`,`dns`,`connect`,`send`,`wait`,`receive`,`ssl` | performance analysis (the format's original purpose) |
| `serverIPAddress`, `connection` | transport detail | host/CDN grouping |

<!-- -->

> **✎ Notes** · `SPEC §3.2`
> _(your notes here — replace this line)_

### §3.3 Non-standard fields worth reading

Chrome and Firefox write extensions that the spec does not define but that are
too useful to ignore. All are optional; nothing may depend on their presence.

| Field | Contents | Useful for |
|---|---|---|
| `_resourceType` | `xhr`, `fetch`, `document`, `script`, `stylesheet`, `image`, `font`, `media`, `websocket` | **the single best first filter** |
| `_initiator` | what caused the request (parser, script, stack) | tracing an endpoint back to its caller |
| `_priority` | fetch priority | rarely |
| `_fromCache` | served from cache — **three-state**: `true`, `false`, or *unknown* when the exporter omits it | excluding non-network entries |
| `_webSocketMessages` | frames, when the entry is a socket | sites that stream data over WS |

Where `_resourceType` is absent, it is inferred from `Content-Type` plus the
`Accept`/`X-Requested-With` request headers, and the inference is reported as
inferred rather than presented as fact.

<!-- -->

> **✎ Notes** · `SPEC §3.3`
> _(your notes here — replace this line)_

### §3.4 Two structural traps

- **`content.text` may be base64.** When `content.encoding == "base64"`, the
  text is encoded, and a naive grep silently misses every hit in it. Every
  content-touching operation decodes first.
- **Bodies are frequently absent.** "Save all as HAR" includes them; some
  exporters and some `_fromCache` entries do not. The tool distinguishes *"no
  match"* from *"no body was captured"* — conflating them sends a session
  hunting for an endpoint it already found.

<!-- -->

> **✎ Notes** · `SPEC §3.4`
> _(your notes here — replace this line)_

## §4 The operations

Six scripts, named on the repo's canonical verbs. All read a HAR or its index;
none mutate the input file.

<!-- -->

> **✎ Notes** · `SPEC §4`
> _(your notes here — replace this line)_

### §4.1 analyze_har.py — reduce to insight

The command run first, and the one that answers "what is even in here".

| Mode | Output |
|---|---|
| *(default)* | Overview: entry count, host count, wall-clock span, pages, resource-type histogram, status histogram, total bytes, and the XHR/JSON count — the number that says whether this site has an API |
| `--index` | Build/refresh the sidecar (§ 5.1) |
| `--stats FIELD` | Histogram over `status`, `host`, `mime`, `type`, `method`, `size`, `time` |
| `--errors` | Every non-2xx: status, statusText, URL, and a short body snippet where one exists |
| `--endpoints` | URL paths collapsed to templates, with the parameters that vary and their observed value ranges — **the pagination finder** |
| `--headers` | Request headers grouped by host, split into constant across requests (candidate auth) versus varying |
| `--cookies` | Cookies sent and set, by domain, with flags |
| `--redirects` | Redirect chains, collapsed |
| `--slowest` / `--largest` | Top-N by `time` / `content.size` — the classic performance use |
| `--websockets` | Per-socket frame counts, direction, sizes, first frames |

`--endpoints` deserves its billing. Collapsing `/api/jobs?page=1&loc=NY`,
`?page=2&loc=NY`, `?page=3&loc=NY` into one row that reports `page` varying over
1–3 and `loc` constant is the difference between reading 40 URLs and reading
one line that says how to iterate the site.

<!-- -->

> **✎ Notes** · `SPEC §4.1`
> _(your notes here — replace this line)_

### §4.2 query_har.py — select, show, extract

One filter grammar (§ 5.2), three output modes.

**Select** — every flag composes as AND:

`--url REGEX` · `--host` · `--method` · `--status` (`200`, `2xx`, `400-499`) ·
`--mime` · `--type` · `--min-size` / `--max-size` · `--slower-than` ·
`--has-header NAME[=REGEX]` · `--param NAME[=REGEX]` · `--body-match REGEX`
(request) · `--response-match REGEX` · `--page ID` · `--since` / `--until` ·
`--from-cache` / `--no-cache` · `--unknown-cache` · `--invert`

`_fromCache` is three-state (§ 3.2), so the cache filters say which state they
mean rather than collapsing the missing one: `--from-cache` selects `true`,
`--no-cache` selects `false` **only**, and `--unknown-cache` selects entries whose
exporter never recorded it. Folding *unknown* into `false` would make
`--no-cache` mean different things on a Chrome capture and a Playwright one,
silently, which is the class of bug this document exists to prevent.

**Show:**

| Mode | Output |
|---|---|
| `--list-only` *(default)* | One line per entry: index, method, status, mime, size, ms, URL |
| `--show IDX` | One entry in full: request line, headers, query, body, response headers, body (pretty-printed, truncated at `--max-body`) |
| `--json` | The selection as JSON, for chaining. Bounded output must still **parse**, so the byte budget is applied by dropping whole entries from a fixed envelope — `{"entries": [...], "shown": N, "matched": M, "truncated": true}` — never by cutting bytes mid-structure. Bodies are excluded from `--json` entirely |
| `--fields a,b,c` | Restrict columns — narrow the fetch, not the reader |

**Extract:**

| Flag | Effect |
|---|---|
| `--extract-body --output-dir DIR` | Decode and write each matching body. The name is derived from `NNN-<host><path>.<ext>` but **flattened and sanitised**: path separators, `..` segments, control characters, leading dots and reserved device names are replaced, the stem is length-capped, and each resolved destination is verified to sit inside `--output-dir` before any write. A URL path is attacker-controlled in exactly the same way a response body is; it never gets to choose where a file lands |
| `--json-path EXPR` | Pull a value out of a JSON body |
| `--css SELECTOR` / `--xpath EXPR` | Pull from an HTML/XML body |
| `--schema` | Print a JSON body's *shape* — keys, types, array lengths — instead of its content. Often 100× smaller and usually the actual question |

`--response-match` is the operation the whole toolkit exists for: paste a string
seen on the page, get back the request that returned it. Combined with
`--schema`, SC4's two commands are `--response-match` then `--show`.

<!-- -->

> **✎ Notes** · `SPEC §4.2`
> _(your notes here — replace this line)_

### §4.3 create_repro.py — entry to runnable request

`--id IDX --format curl|python` emits a runnable reproduction with method, URL,
headers, cookies and body. Redacted by default; `--secrets` writes the real
values. This is the handoff from "found the endpoint" to "have a scraper", and
it is where a HAR stops being a diagnostic artifact.

**Every emitted value is escaped for its destination.** A HAR is an untrusted
document — its URLs, header values and bodies came off the network — and this
command's whole purpose is to produce something the operator will paste into a
shell. Shell output single-quotes every argument with the embedded-quote escape,
never interpolating raw text; Python output uses `repr()` rather than string
concatenation. Bodies are passed with `--data-raw`, so a body beginning with `@`
stays inline data instead of becoming a local-file read. A generated command that
executes something the capture did not contain is the worst bug this toolkit
could have, so this is a correctness requirement, not a hardening note.

<!-- -->

> **✎ Notes** · `SPEC §4.3`
> _(your notes here — replace this line)_

### §4.4 create_har.py — write a derived HAR

Takes the same filter grammar and writes a new, valid HAR.

| Flag | Effect |
|---|---|
| `--keep <filters>` / `--drop <filters>` | Subset by any filter |
| `--drop-types image,font,media,stylesheet` | The usual 80 % of a capture by size |
| `--keep-bodies` | **Bodies are dropped by default.** Redaction covers named fields; a response body is unbounded text that may carry a credential anywhere in it (§ 5.4), so a derived HAR that kept bodies by default would hand back a file that looks sanitised and is not. Dropping them also happens to be what the fixture use case wants — shape, status and headers, no payload. `--keep-bodies` opts back in, and says in its own output that the result is as sensitive as the capture |
| `--redact` *(default)* | Replace auth headers, cookies, token-shaped params with `<redacted>` |
| `--output PATH` | Destination. An `--output` that resolves to the input file is **refused before anything is opened** — a direct writer would truncate the source while still reading it. Every other destination is written to a temporary file in the same directory and atomically renamed into place, so an interrupted run leaves either the old file or the new one, never a half-written HAR |

This is requirement 4, and the ability to *write* a valid HAR earns its place
even though it will be used less often than the reading commands:

- **Fixtures.** A capture reduced to twelve XHR entries with redacted headers
  and no bodies is small enough to commit, and a committed capture is how a
  scraper gets a regression test that does not touch the network.
- **A smaller working copy.** A 400 MB capture with the images, fonts and media
  dropped is a 3 MB file that opens instantly in any HAR viewer and travels
  between machines. The reduction is often the whole point, independent of any
  test.
- **Something safe to hand over.** Redacted, body-dropped, filtered to the
  requests that matter — a file that can go in an issue or a PR without
  carrying a session.

All three are the same operation with different flags, which is why this is one
script rather than three.

<!-- -->

> **✎ Notes** · `SPEC §4.4`
> _(your notes here — replace this line)_

### §4.5 compare_har.py — diff two captures

Entries present in one and not the other, status changes, new or missing
parameters, response-size deltas. The way to answer "what actually changed when
I clicked page 2" and, later, "did the site change under my scraper".

**Matching is one-to-one and deterministic**, because a capture routinely repeats
the same method and URL. The key is `(method, scheme, host, port, path, query pairs in captured order,
hash of request body)`. Three things about it are deliberate:

- **The authority is part of request identity**, so two captures hitting the
  same path on different hosts, or on http and https, are never silently paired.
- **Query pairs keep their captured order** rather than being sorted. Sorting
  would make `?tag=a&tag=b` and `?tag=b&tag=a` the same request, and order
  carries meaning for signed requests and for some APIs.
- **`pageref` is not in the key.** HAR page ids are local to one capture, so
  including it would make the same request in two captures — which is exactly
  what a diff is looking for — appear as a removal plus an addition. Page
  context is reportable, never part of identity.

Entries sharing a key are paired in capture order, first with first, second with second. Any left over on either side is reported as
an addition or a removal — never paired with something that merely resembles it,
which is how a diff tool starts inventing changes that did not happen. A pairing
that relied on ordering alone is reported as such, so a reader can tell a real
match from a positional one.

<!-- -->

> **✎ Notes** · `SPEC §4.5`
> _(your notes here — replace this line)_

### §4.6 validate_har.py — is this usable

Well-formedness against HAR 1.2, plus a capability report: are bodies present,
are they base64, is `_resourceType` available, which optional fields this
exporter omitted. Run when something surprising happens; it distinguishes a bad
capture from a bad query.

<!-- -->

> **✎ Notes** · `SPEC §4.6`
> _(your notes here — replace this line)_

### §4.7 run_har.py — replay (deferred)

Not in v1. Specified only to fix its shape: replay selected entries against the
live site and diff the responses against the capture, which is a scraper
regression test. The filter grammar and the index are designed so this is an
added script, not a refactor.

<!-- -->

> **✎ Notes** · `SPEC §4.7`
> _(your notes here — replace this line)_

## §5 Architecture



<!-- -->

> **✎ Notes** · `SPEC §5`
> _(your notes here — replace this line)_

### §5.1 The index sidecar

`analyze_har.py --index` writes `<file>.har.index.jsonl`: one JSON object per
entry, no bodies. For a 200 MB HAR this is single-digit MB.

The schema is fixed, because "every scalar" is not a specification:

```jsonc
{ "i": 12, "off": 91823, "len": 4410,          // byte offset + length in the HAR
  "ts": "2026-08-30T20:14:52.311Z", "ms": 231, "page": "page_1",
  "method": "GET", "url": "…", "host": "…", "path": "/api/jobs",
  "query": [ ["page", "2"], ["loc", "NY"] ],   // pairs: names repeat
  "status": 200, "statusText": "OK",
  "mime": "application/json", "type": "xhr", "typeSrc": "declared",
  "reqBytes": 812, "respBytes": 44120,
  "cache": true,                                // true | false | null = unknown
  "reqHeaders": [ ["accept", "application/json"],
                  ["authorization", "<redacted>"] ],
  "respHeaders": [ ["content-type", "application/json; charset=utf-8"],
                   ["set-cookie", "<redacted>"], ["set-cookie", "<redacted>"] ],
  "hasReqBody": false, "hasRespBody": true, "bodyEncoding": null }
```

Query and header fields are **arrays of pairs, not objects**, because both
repeat: `?tag=a&tag=b` is two values for one name, and `Set-Cookie` appears once
per cookie. Collapsing them into an object silently keeps the last one, which
would make `--param tag=a` miss a request that plainly contains it — and would do
so only on the sites that use repetition, which is the worst possible
distribution for a bug.

**Header values are indexed, and sensitive ones are redacted in the sidecar.**
Names alone would not serve `--has-header NAME=REGEX` or `--headers`, so values
are stored — which makes the sidecar as sensitive as the HAR beside it unless
something is done about it. The same deny-list as § 5.4 applies here: a sensitive
header is written as `<redacted>`, so the sidecar can sit on disk without
carrying a live session token. A value-regex query against a redacted header
therefore cannot be answered from the index; it transparently falls back to
reading those entries from the original HAR by offset, reports that it did, and
requires `--secrets`. Presence queries (`--has-header authorization`) still run
entirely on the index.

Every filter, statistic and search that does not need body *content* runs
against the index alone: flat memory, sub-second, independent of HAR size
(SC3). Each index line also records the byte `offset` and `length` of its entry
in the original file, so a body-touching command seeks directly to one entry and
parses only that object.

The index records both a cheap identity (size and mtime) and a **content
digest**, and they are checked at different moments — because verifying a digest
means reading the whole HAR, which is the exact cost the index exists to avoid:

| Command | Check | Cost |
|---|---|---|
| Index-only (filters, statistics, listings) | size and mtime; a mismatch rebuilds | free — and never touches the HAR, which is what makes SC3 hold |
| Anything that seeks by byte offset (a body read, `--show`, `--extract-body`) | the full content digest, once per run, before the first seek | one pass over a file this command is already reading |

Size and mtime alone are not a content identity — a copy-preserving move or a
coarse filesystem clock can carry both across two different files. That is why
no *offset* is ever trusted on their word. But metadata queries do not use
offsets, so making them pay for a digest would buy nothing and cost the whole
premise of the sidecar.

The sidecar is **written to a temporary file in the HAR's own directory and
atomically renamed**, exactly as derived HARs are (§ 4.4). The same directory
matters: `rename` is only atomic within a filesystem, so a temporary file in the
system temp directory fails with `EXDEV` the moment the capture lives on another
mount — which is the normal case for a large HAR on an external disk. Without that, an interrupted index build leaves a
truncated JSONL whose header line — and therefore whose digest — is perfectly
valid, so the next run would trust it and quietly answer every query from a
partial index. A digest over the input cannot detect damage to the output. It is
rebuilt automatically when stale, and `.gitignore`d by convention. A `--no-index` path
streams the original for the rare case where writing next to the input is not
acceptable.

**The one risky part** is the offset scanner: finding entry boundaries requires
tracking brace depth while respecting strings and escapes.

It operates on **bytes, not decoded text**. The file is opened in binary mode,
scanned as UTF-8 bytes, and seeks use those same byte offsets — because a
character offset and a byte offset diverge the moment a capture contains a
literal non-ASCII character, and captures of real sites contain them constantly.
An index built on `str` positions would work perfectly on every ASCII fixture and
silently return the wrong entry on the first site with an accented job title.

It gets its own unit tests against pathological bodies — braces inside strings,
escaped quotes, Unicode escapes, and **literal multi-byte characters positioned
before a later entry**, which is the only fixture that actually exercises the
byte/character distinction — plus a `--verify-offsets` mode that re-parses every
entry from its offset and compares. If it proves fragile, the fallback is an index without
offsets plus a streaming re-scan for bodies: slower, same interface.

<!-- -->

> **✎ Notes** · `SPEC §5.1`
> _(your notes here — replace this line)_

### §5.2 One filter grammar, shared

`query_har.py`, `create_har.py`, `compare_har.py` and eventually `run_har.py`
accept identical selection flags, implemented once in `_filters.py`. A session
that learns to select entries once can filter, export, prune and replay the same
set. Divergent flag sets across sibling scripts would be the most likely way for
this toolkit to become annoying.

**Every script is discoverable the same way.** The rubric asks for this as a
*should* (`R-HELP-1`: argparse with `--help`, documented invocation, a `main()`
guard), which means it is convention rather than contract. This skill treats it
as a contract, because a toolkit of six scripts is exactly where "mostly
consistent" stops being good enough:

- `--help` on every script, listing every flag with its meaning — the first
  thing a session or a person runs, and enough on its own to use the tool.
- The shared selection flags are spelled identically everywhere, and the
  repo's canonical names (`--input`, `--output`, `--output-dir`, `--limit`,
  `--json`) mean the same thing they mean in every other arsenal script.
- Every script accepts `--json`, so output can be chained rather than parsed
  out of a table.
- SKILL.md documents each script's invocation, and a test asserts that the
  sibling scripts expose the same selection flags — the drift this section
  exists to prevent is checked, not just asked for.

<!-- -->

> **✎ Notes** · `SPEC §5.2`
> _(your notes here — replace this line)_

### §5.3 Output discipline

Default output is a compact table capped two ways: by `--limit` (default 20)
and by a **hard 4096-byte budget** on the rendered output, whichever binds first.
A row cap alone does not bound output — twenty entries with 300-character
tracking URLs blow the budget on their own — so long fields are truncated
deterministically (URLs keep host, path and a middle ellipsis; the tail always
survives) and the trailing line reports both what was dropped and that the
budget, not the limit, did the dropping. The budget applies to every default
mode, not only the entry list. `--json` gives machine-readable output for
chaining, and stays valid under the budget by dropping whole entries from a
fixed envelope rather than cutting bytes mid-structure. Bodies never reach
stdout except through `--show` (truncated) or `--extract-body` (to files).

**The budget is a default for the reader, never a ceiling on the tool.** A
reduced answer that cannot be expanded is a tool that decides for you what you
were allowed to ask, and this one is meant to be useful rather than
semi-informative. Two escapes, both first-class:

| Flag | Effect |
|---|---|
| `--limit 0` | No row cap and no byte budget. Everything that matched, on stdout, deliberately |
| `--output PATH` | The complete result written to a file, uncapped, in full fidelity — the budget applies to what is *rendered for a reader*, not to what the tool can produce. With `--json`, this is the machine-readable full set |

So the rule is: **small by default, complete on request.** The default exists
because the common case is a session that needs an answer rather than a dump,
and the escapes exist because the uncommon case is real — piping every matching
entry into another tool, or saving a full listing to read properly.

<!-- -->

> **✎ Notes** · `SPEC §5.3`
> _(your notes here — replace this line)_

### §5.4 Redaction

Redaction applies to everything written to disk or emitted as a shareable
artifact: derived HARs, extracted entries, repro snippets. It covers
`Authorization`, `Proxy-Authorization`, `Cookie`, `Set-Cookie`, `X-API-Key` and
neighbours, plus query and body parameters whose names match a token pattern
(`token`, `key`, `secret`, `session`, `auth`, `password`, `signature`).

Header **names are matched case-insensitively** everywhere — the deny-list,
`--has-header`, and `--headers` all normalise to lower case before comparing.
HTTP header names are case-insensitive by definition, so a deny-list that
matched literally would let `AUTHORIZATION` through while catching
`Authorization`: a redaction bypass that depends on nothing but an exporter's
capitalisation.

**Redacted values keep a fingerprint, or `--headers` stops working.** Replacing
every sensitive value with a bare `<redacted>` makes two different `Authorization`
values compare equal — which destroys the constant-versus-varying split that is
the whole point of `--headers` as an auth-discovery tool. So a redacted value is
written `<redacted:ab12cd34>`, where the suffix is a truncated digest of the
value under a salt generated per index and never stored. Equal values stay equal,
different values stay different, and nothing about the original is recoverable.
Cookies keep their names and flags for the same reason; only values are replaced.

**The serialized URL is redacted too, and it is the easy one to miss.** A token
in a query parameter is caught by the rule above when the parameter is read as a
parameter — and survives untouched inside `request.url`, which carries the whole
query string inline and is written into the sidecar, every listing, and every
generated reproduction. So the same token pattern is applied to the URL's own
query pairs, and the URL is re-serialized preserving **pair order, repeated
names, and each value's percent-encoding** — a redaction pass that normalises the
query silently changes the request it claims to describe.

Two more parts of a URL carry credentials that no name-matching rule would look
for, and both are removed by default from every artifact:

- **Userinfo.** `https://user:pass@host/path` becomes `https://host/path`.
- **Fragment.** `https://host/callback#access_token=…` loses the fragment
  entirely. OAuth implicit flows put live tokens there, and a fragment is not
  a query parameter, so the token pattern above would never have seen it.

`--secrets` may restore userinfo and fragment **only in `create_repro.py`
output**, where a working reproduction is the entire point. They are never
restored into a sidecar, a listing, or a derived HAR, because those are files
that get committed.

<!-- -->

> **✎ Notes** · `SPEC §5.4`
> _(your notes here — replace this line)_

### Full fidelity, when the work needs it

Redaction is the default because the failure it prevents — a live session token
in a committed file — is silent and expensive. It is not a wall. `--secrets`
returns real values, and it exists precisely for the case where the work needs
them: reproducing a login means the real `Cookie` header, the real
`Authorization`, and the exact `Set-Cookie` sequence the server returned, because
a scraper that authenticates cannot be written from redacted material.

The rule is the same shape as § 5.3's: **safe by default, complete on request.**
What `--secrets` changes is only what is *written*; `--show` on a single entry
has always printed real values, because that is an operator reading their own
capture on their own machine.
Interactive `--show` of a single entry prints real values — that is the operator
reading their own capture. `--secrets` opts out where a working reproduction is
the point.

**Extracted response bodies are outside this guarantee, and SC5 says so.**
Redaction works on a bounded set of named fields; a response body is unbounded
text that may contain a token in a JSON field nobody can enumerate in advance,
and a redactor that tried would either miss things or corrupt the payload the
extraction exists to preserve. So `--extract-body` writes the real body, and the
honest specification is that its output is as sensitive as the capture rather
than a promise that cannot be kept. The command prints a one-line warning naming
the output directory the first time it writes in a run, and the skill's
documentation says plainly that extracted bodies are not fixtures until someone
has looked at them.

<!-- -->

> **✎ Notes** · `SPEC › Full fidelity, when the work needs it`
> _(your notes here — replace this line)_

### §5.5 Packaging

One skill, `har`, in a new `extract` section defaulting off. Consumers who
never scrape pay nothing; `--sections extract` or `--profile all` installs it.

The section is named for what its members do — getting structured data out of
artifacts you did not produce — rather than for the web, which would read as
frontend tooling and mislead in both directions: a consumer skipping it because
they do no web development, or installing it expecting some. `har` is the first
member; a JSON/HTML/XML reader and the binary-format readers are the obvious
next ones, and none of them are scraping in themselves. Scripts are
stdlib-only `python3` so they run in a vendored consumer repo with no
dependency step, consistent with every other shipped script.

**A section nobody installed still has to be findable.** Default-off is right —
a repo that never scrapes should pay nothing — but it creates the obvious
failure: the consumer who needs the tool a year later never learns it exists.
Two mechanisms, both reusing machinery that is already there, and neither
costing a resident token:

- **The upgrade banner announces it once.** `/init` and `check_update.sh`
  already print the CHANGELOG entries between a consumer's installed version and
  the one they are updating to, on every update. A new section named in that
  entry reaches every consumer automatically, exactly once, whether or not they
  install it.
- **`init.py --list-sections` answers on demand.** Prints every section that
  ships, which are on for this repo, what each contains, and the one line that
  enables one. This is the thing to reach for when a session finds itself
  wanting a tool it does not have.

Both are changes to `init`, not to this skill, and are tracked as delivery
stage 0 (§ 9) so the section does not ship before the means of discovering it.

<!-- -->

> **✎ Notes** · `SPEC §5.5`
> _(your notes here — replace this line)_

## §6 Decisions taken

| Question | Decision | Why |
|---|---|---|
| Large files | Index sidecar | Only option that keeps a 500 MB capture usable; makes repeat queries cheap, which is how the tool is actually used |
| Body parsing scope | Extract + text formats (JSON/HTML/XML/CSV) in-tool; binaries decoded to disk for sibling skills | Keeps this skill focused and leaves PDF/XLSX parsers reusable outside HAR |
| Secrets | Redact when writing, raw when inspecting | A HAR is full of live session tokens; the risk is a committed file, not a terminal |
| Repro output | Generic curl + Python `requests` | The natural end of a scraping session; coupling to any one project's connector schema would make a standalone skill track a foreign format |
| Full-text index over bodies | **Not in v1** | The sidecar is a *metadata* index — every scalar and header, no bodies. A second index over decoded body text would make `--response-match` instant, at the cost of a file near the size of the capture, a second invalidation story, and tokenisation choices that silently decide what "matches" means. Filters usually narrow to a handful of entries before any body is read, so scanning those by offset is fast enough. It stays additive: the sidecar format can gain one later without a redesign |

<!-- -->

> **✎ Notes** · `SPEC §6`
> _(your notes here — replace this line)_

## §7 Out of scope

- Replay (§ 4.7) — deferred, shape fixed.
- PDF/XLSX/image parsing — extracted to disk, parsed by sibling skills.
- Capturing HARs. The tool reads captures; producing them is the browser's job.
- HAR *editing* as an interactive activity. `create_har.py` derives a new file;
  it does not offer general-purpose mutation.
- Emitting any project's own parser or connector format. The toolkit's output is
  generic — entries, bodies, curl, `requests` — and translating that into a
  particular schema belongs to whatever owns the schema.

<!-- -->

> **✎ Notes** · `SPEC §7`
> _(your notes here — replace this line)_

## §8 Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Offset scanner mis-parses an entry boundary | High — wrong body for an entry is a silent wrong answer | Dedicated tests on pathological bodies; `--verify-offsets`; documented fallback |
| Exporter variance (missing bodies, missing `_resourceType`) | Medium — looks like "not found" | `validate_har.py` capability report; "no body captured" reported distinctly from "no match" |
| Encoding handling is wrong somewhere in the chain | High — a wrong body or a missed match, both silent | Encoding is where this tool most plausibly fails quietly, so it gets its own test matrix rather than incidental coverage: base64 and identity bodies; `gzip`, `deflate` and `br` content-encodings; charsets that are not UTF-8 (`latin-1`, `shift_jis`) declared in `Content-Type` and *undeclared*; a body whose declared charset is wrong; BOM-prefixed JSON; lone surrogates and invalid byte sequences; and multi-byte characters positioned before a later entry, which is the only case that exercises byte-versus-character offsets. Every one of them asserts the same thing: the tool either returns the right bytes or says plainly that it cannot decode them — never a silently mangled string |
| Filter grammar sprawls across scripts | Medium — the toolkit stops being learnable | Single `_filters.py`; a test asserts the sibling scripts expose the same flags |
| Redaction misses a token shape | Medium — a secret in a committed file | Deny-list plus name-pattern matching, tested; `create_har.py` output scanned in test |
| The sidecar becomes an unnoticed copy of the capture's secrets | Medium | Sensitive header values redacted in the index itself; gitignored by convention |
| A generated `curl` executes something the capture did not contain | High — the operator pastes it into their own shell | Every value escaped for its destination; `--data-raw`; tested against adversarial header and body values |
| An extracted body lands outside `--output-dir` | High — arbitrary file write from an untrusted HAR | Names flattened and sanitised; resolved destination verified inside the output directory before any write |
| Skill earns its resident cost | Low | Default-off section; 0 tokens for repos that do not enable it |

<!-- -->

> **✎ Notes** · `SPEC §8`
> _(your notes here — replace this line)_

## §9 Delivery

| Stage | Contents |
|---|---|
| 0 | `init.py --list-sections`, and a CHANGELOG entry naming the new section — the discovery path (§ 5.5), which lands before or with stage 1 |
| 1 | `extract` section registered; skill scaffold; `validate_har.py`; index builder with offset tests |
| 2 | `_filters.py` + `query_har.py` (select, show, extract, schema) |
| 3 | `analyze_har.py` (overview, stats, errors, endpoints, headers) |
| 4 | `create_repro.py`, `create_har.py` |
| 5 | `compare_har.py`; `run_har.py` if still wanted |

Stages 1–3 are the useful minimum: they answer "which request has my data" and
"how do I iterate it". Stage 4 is what turns that into a scraper.

Fixtures: a small committed HAR exercising base64 bodies, absent bodies, an
absent `_fromCache`, a redirect chain, a paginated JSON API, a websocket, an
entry whose URL path contains `../` and a separator, a body value beginning with
`@` and one containing shell metacharacters, and **literal multi-byte characters
positioned before a later entry** — built by hand rather than captured, so it
carries no real secrets and no site's data. Each of those exists because a
specific claim in this document is false if it is not tested.

<!-- -->

> **✎ Notes** · `SPEC §9`
> _(your notes here — replace this line)_

