# Specification notes

_Exported 2026-08-31 · 12 notes._

> Send this file back to continue the review. Notes are embedded as data at the bottom
> so importing this file restores them in the reader.

## 0002 Har Analysis Toolkit

**§2 Problem statement**  `SPEC §2`
> Well, I'm doing integral-job-search, but don't use it as an excuse. This har tool must be an independent skill for arsenal.

**Success criteria (measurable)**  `SPEC › Success criteria (measurable)`
> Not sure if web is the right section name or something more scraping-related. Web could include frontend.

**§3.2 Per entry**  `SPEC §3.2`
> About arsenal sections, if someone does not install these scraping tools and then at some moment it needs them, how can we make sure they will know arsenal is more complete and have these tools?

**§3.3 Non-standard fields worth reading**  `SPEC §3.3`
> Good, web sockets can be important. And yes, some fields or headers can be very useful to diagnose requests and to know how to reproduce them. The main goal of this tool is that Claude can use it to boost the process of analyzing websites or create scrapers.

**§3.4 Two structural traps**  `SPEC §3.4`
> Good!

**§5.2 One filter grammar, shared**  `SPEC §5.2`
> Great! We must ensure that someone who uses the script can know what arguments it has a d how to use it. Not sure if arsenal enforces this or a --help call is enough... All the arsenal scripts should work the same way in discovery and usage terms.

**§5.3 Output discipline**  `SPEC §5.3`
> Nice, but in case the user of the script wants the full output, it should have the possibility to get it. Or at least another script that can give it to the user in JSON format or whatever. I mean, the tool must be useful, not only semi-informative.

**§5.4 Redaction**  `SPEC §5.4`
> Good, but I understand we can get full data if needed, right? For example, if Claude is creating a scraper and needs to write a login, all cookies and headers can be useful to implement that part. Same for cookies differences (Set-Cookie).

**§5.5 Packaging**  `SPEC §5.5`
> Again, let's think about a name different to web, which could be misleading. Or let's talk about pros and cons first 

**§6 Decisions taken**  `SPEC §6`
> Just wondering... Could creating an index for text be useful here? Or this is exactly what your sidecar is?

**§7 Out of scope**  `SPEC §7`
> Let's avoid talking about integral-job-search. This tool must be standalone and without dependencies.
> Create_har should be useful to create tests and to create, for example, reduced versions of another har. It is good to have a tool to create har files, even if not used too much.

**§8 Risks**  `SPEC §8`
> We'll need tests for all kind of encoding usual issues.

<!-- SPEC-NOTES-DATA
{"s-spec-2":"Well, I'm doing integral-job-search, but don't use it as an excuse. This har tool must be an independent skill for arsenal.","s-spec-success-criteria-measurable":"Not sure if web is the right section name or something more scraping-related. Web could include frontend.","s-spec-3-2":"About arsenal sections, if someone does not install these scraping tools and then at some moment it needs them, how can we make sure they will know arsenal is more complete and have these tools?","s-spec-3-3":"Good, web sockets can be important. And yes, some fields or headers can be very useful to diagnose requests and to know how to reproduce them. The main goal of this tool is that Claude can use it to boost the process of analyzing websites or create scrapers.","s-spec-3-4":"Good!","s-spec-5-2":"Great! We must ensure that someone who uses the script can know what arguments it has a d how to use it. Not sure if arsenal enforces this or a --help call is enough... All the arsenal scripts should work the same way in discovery and usage terms.","s-spec-5-3":"Nice, but in case the user of the script wants the full output, it should have the possibility to get it. Or at least another script that can give it to the user in JSON format or whatever. I mean, the tool must be useful, not only semi-informative.","s-spec-5-4":"Good, but I understand we can get full data if needed, right? For example, if Claude is creating a scraper and needs to write a login, all cookies and headers can be useful to implement that part. Same for cookies differences (Set-Cookie).","s-spec-5-5":"Again, let's think about a name different to web, which could be misleading. Or let's talk about pros and cons first ","s-spec-6":"Just wondering... Could creating an index for text be useful here? Or this is exactly what your sidecar is?","s-spec-7":"Let's avoid talking about integral-job-search. This tool must be standalone and without dependencies.\nCreate_har should be useful to create tests and to create, for example, reduced versions of another har. It is good to have a tool to create har files, even if not used too much.","s-spec-8":"We'll need tests for all kind of encoding usual issues."}
-->