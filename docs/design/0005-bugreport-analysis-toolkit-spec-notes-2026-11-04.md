# Specification notes

_Exported 2026-11-04 · 7 notes._

> Send this file back to continue the review. Notes are embedded as data at the bottom
> so importing this file restores them in the reader.

## 0005 Bugreport Analysis Toolkit

**§2.2 Problem families the detectors target (ranked by forum demand)**  `SPEC §2.2`
> I think they should be included.
> Also, a question like "how is behaving my phone?" could run all the tests to see performance issues, wrong behavior from apps...

**§2.3 Systems touched**  `SPEC §2.3`
> Where is the skill set? With HAR? In a mobile phone section? It doesn't look like core.

**Option B: Indexed, detector-driven toolkit, stdlib only (Recommended)**  `SPEC › Option B: Indexed, detector-driven toolkit, stdlib only (Recommended)`
> If a section can't be read, for example, due to a new version of the file, we must anyway have some basic tooling or primitives to "manually" extract the data and interpret it by the LLM while being quite cost-savimg.
> We didn't talk about the output, but it should be able to give advice with the results (close apps, reduce battery use, how to avoid heat...) given the problems it has. It must be like an auto diagnostic tool. Also, check for apps installed out of the app store, look for security risks I'm app configurations, etc. Let's try to give the user solutions to all the problems the phone can be experimenting, even those that can't be seen.
> If you can find other log files on the internet for other versions of Android or other types of phones that could manage this kind of files differently, try to get them to make the skill more complete.

**Option C: Build on Perfetto trace_processor as the substrate**  `SPEC › Option C: Build on Perfetto trace_processor as the substrate`
> Ok, don't use Perfetto, but you can take ideas from it if they are useful to us.

**§4 Recommendation**  `SPEC §4`
> ¶ _“Recommended option: B — it is the only option that meets "find problems, not just expos…”_
>
> Ok, B.

**§4 Recommendation**  `SPEC §4`
> ¶ _“Open questions: 1. Section: put bugreport in the existing default-off extract section n…”_
>
> 1. I think an Android section or inside diagnostics...
> 2. I have some to give you, but all from the same phone. Try to find  ew ones in forum's or whatever.
> 3. Not sure, maybe a part of it could be from the skill for the LLM to interpret.
> 4. I don't think comparing is really useful here, but it could compare performance between two times. At the end, it is just analyzing two files and do the comparison later.

**§4 Recommendation**  `SPEC §4`
> Please, use skill-workshop rules.

<!-- SPEC-NOTES-DATA
{"s-spec-2-2":"I think they should be included.\nAlso, a question like \"how is behaving my phone?\" could run all the tests to see performance issues, wrong behavior from apps...","s-spec-2-3":"Where is the skill set? With HAR? In a mobile phone section? It doesn't look like core.","s-spec-option-b-indexed-detector-driven":"If a section can't be read, for example, due to a new version of the file, we must anyway have some basic tooling or primitives to \"manually\" extract the data and interpret it by the LLM while being quite cost-savimg.\nWe didn't talk about the output, but it should be able to give advice with the results (close apps, reduce battery use, how to avoid heat...) given the problems it has. It must be like an auto diagnostic tool. Also, check for apps installed out of the app store, look for security risks I'm app configurations, etc. Let's try to give the user solutions to all the problems the phone can be experimenting, even those that can't be seen.\nIf you can find other log files on the internet for other versions of Android or other types of phones that could manage this kind of files differently, try to get them to make the skill more complete.","s-spec-option-c-build-on-perfetto-trace":"Ok, don't use Perfetto, but you can take ideas from it if they are useful to us.","s-spec-4~1oc6wj":"Ok, B.","s-spec-4~1oc6wj~q":"Recommended option: B — it is the only option that meets \"find problems, not just expos…","s-spec-4~1dzyz5u":"1. I think an Android section or inside diagnostics...\n2. I have some to give you, but all from the same phone. Try to find  ew ones in forum's or whatever.\n3. Not sure, maybe a part of it could be from the skill for the LLM to interpret.\n4. I don't think comparing is really useful here, but it could compare performance between two times. At the end, it is just analyzing two files and do the comparison later.","s-spec-4~1dzyz5u~q":"Open questions: 1. Section: put bugreport in the existing default-off extract section n…","s-spec-4":"Please, use skill-workshop rules."}
-->