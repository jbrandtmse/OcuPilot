# Research First

When not certain about a technical point, research it before deciding or coding. ObjectScript
and IRIS have enough surprising corners — and enough confidently-wrong material in circulation
— that guessing costs more than looking.

## When to research

- IRIS or Ensemble method signatures, adapters, or configuration.
- ObjectScript syntax and semantics — `$$$` macro usage, `Quit` behavior in Try/Catch, abstract
  method requirements, `%DynamicObject` edge cases.
- IRIS SQL, global, or vector/embedding datatype behavior.
- Any point where recollection conflicts with the code, or where forum answers disagree.

## Where to look, in order

1. **The instance itself.** The running IRIS is authoritative — probe it through the IRIS MCP
   tools rather than reasoning about what it probably does.
2. **The system source.** [irislib/](../../irislib/) and [irissys/](../../irissys/) hold the
   actual implementation of the class you are about to call. Read it. See
   [reference-folders.md](reference-folders.md).
3. **The official documentation.** [irisdocs/](../../irisdocs/) mirrors the `%Api` pages;
   docs.intersystems.com for everything else; the container serves Documatic for the exact
   installed build.
4. **Perplexity MCP** for discovery, error-code lookups, and community knowledge. Give it
   context in the query — "ObjectScript", "InterSystems IRIS", the feature name, the exact
   error code. Iterate when results conflict.

Prioritize InterSystems official docs and Developer Community posts over general web results.
Quote only the lines that actually change the implementation decision.

## From research to action

- Summarize the decision as a short bullet list before coding — what changes and why.
- Map each decision to a concrete step ("`$$$` not `$$`" → "rewrite the macros in ClassX.cls").
- Verify by compiling with the IRIS MCP compile tools, then by a small isolated test for
  anything about SQL, globals, or vector behavior that the research did not settle definitively.

## When ambiguity survives

If sources disagree, state the conflict in a sentence and take the safest standards-compliant
option. If it is still unresolved after a research pass, ask one targeted question rather than
building on a guess.
