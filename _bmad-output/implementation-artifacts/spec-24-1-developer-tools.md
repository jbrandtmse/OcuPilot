---
title: 'Story 24.1: Developer tools (first slice: code metrics and document hashes)'
type: 'feature'
created: '2026-11-14'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The story names ten developer-tool surfaces. That is more than one implement pass, and the six that reach another instance or run code (remote profiles, diff, promote, the consoles, the terminal) carry questions that are still open (see Design Notes). The two that depend on nothing, LOC metrics (DT-07) and drift hashes (DT-08), have no screen and no API in OcuPilot.

**Approach:** Plan 24.1 as those two surfaces and propose five siblings for the rest (Design Notes, `Proposed split:`). Harvest the sibling's `LocCount` and `DocHashes` bodies, and the LOC library they call, through Story 21.1's seam (AD-23). Add one gated area port, `DevToolPort`, that validates and bounds before any body runs. Show the results on two read-only System Explorer screens, Code metrics and Document hashes. Each screen's read tool comes from its descriptor.

## Boundaries & Constraints

### Always:

- The harvested files are copied from `/Users/jbrandt/git/iris-execute-mcp-v2` at `c6aad31` and change only by the rename table in Design Notes. No other line of a body or the library is edited.
- `DevToolPort` is the only caller of the new body classes, through `HarvestPort.Invoke`. Before any body runs it checks the following, in this order:
  1. `AtelierPort.Pairs()`, the same gate the Explorer area uses.
  2. The namespace's shape.
  3. `AtelierPort.NamespacePairs(ns)`, refused when it answers `""`.
  4. The spec's shape.
  5. The wide-spec rule.
  6. The document count cap.
  
  It passes the full pair set to `HarvestPort` (AD-29, AD-61 rule 1).
- The port sends a body only the query keys it built itself: `spec`, `namespace`, `includeGenerated` and, for metrics, `topN` 1. It never sends `allowWide`.
- Both reads are bounded and report truncation (AD-36). A screen and its read tool share one read (AD-5, AD-24).
- The namespace is switched only by the bodies, which save and restore it. No `OcuPilot.*` class is named by `##class` while a body is switched (AD-16; 21.1's named limit).

### Never:

- No write, no governance key, no route, no proposal, and no new entity type.
- No `%Atelier`, `ExecuteMCPv2` or other forbidden token, including in comments.
- No caller value in SQL, and no path (AD-21). A spec is a document-name pattern.
- No edit to `Port/HarvestPort.cls` or `Port/Harvest/Handler.cls`.
- Nothing from the siblings' scope. In particular, the promote workflow stays absent (AD-66).

## I/O & Edge-Case Matrix

The probe package is `OcuProbe241`, made in `USER` by `Test/DevToolProbe`. All rows are observed on `ocupilot-b-ci` through `GET /screens/:screen/read`, unless a row names the read tool.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Metrics | spec `OcuProbe241.*.cls`. Probe classes have known code, comment and blank lines. | One row. Its fields are `Documents`, `Lines`, `Code`, `CodePercent`, `SourceCode`, `TestCode`, `Comments`, `CommentPercent`, `Blank` and `BlankPercent`, each equal to the probe's known composition. `truncated` is false. | none |
| Hashes | the same spec | One row per probe class: `Document`, `Hash` and `Modified`. `Hash` equals SHA-256, written in hex, over the class's UDL lines, each followed by a line feed. The test computes that hash from the text it saved. | none |
| Routines | spec `OcuProbe241*.mac,OcuProbe241*.inc` | Hashes has one row per probe routine and include file. Metrics counts both. | none |
| Generated | `generated` `yes`, then `no` | With `yes`, the probe's generated routines are listed. With `no`, none are listed. If Task 0 finds that the vendor query lists no generated routine for a probe, the row asserts instead that `DevToolHarvestRecorder` recorded `includeGenerated` 1. | none |
| No match | spec `OcuProbe241Absent.*.cls` | Hashes has no rows and `truncated` is false. Metrics has one row with `Documents` 0. | none |
| Over the cap | Hashes with `maxRows` below the probe's count | Answers `maxRows` rows and `truncated` true. | none |
| Wide spec | `*`, or `OcuProbe241.*.cls, *` | 400 `EXPLORER.SPEC.WIDE`. No body runs. | not logged |
| Bad shape | spec containing `/`, `\`, `..`, a space inside a name, a control character, or an empty part | 400 `PORT.VALIDATION` with the shape reason. No body runs. | not logged |
| Too many | the spec matches more than `MaxDocuments()` (the fixture lowers it to 2) | 400 `EXPLORER.SPEC.TOOMANY`, with `detail.count` and `detail.max`. No body runs. | not logged |
| Gate | the caller lacks `%Development:USE`, or READ on the namespace's code database (armed `ScreenGate` seam) | 403 `AUTH.NOPRIVILEGE` with `detail.failedPair`. No body runs. | not logged |
| Unknown namespace | the route namespace does not exist | 400 `PORT.VALIDATION`, as `AtelierPort` answers it | not logged |
| Read tool | `explorer.codemetrics.read` and `explorer.documenthashes.read`, called with the matrix's first spec | Each answers the same rows the screen route answered. | the same refusals |

</intent-contract>

## Code Map

The sibling repository is `/Users/jbrandt/git/iris-execute-mcp-v2` at `c6aad31`. It is read-only.

### Sibling source

- `src/ExecuteMCPv2/REST/Loc.cls:23-96` -- `LocCount`. It switches namespace, then calls `Loc.Generate.Count` while switched.
- `src/ExecuteMCPv2/REST/EnvSync.cls:48-259` -- `DocHashes` and its helpers. `HashDoc:243` calls `%Atelier.v1.Utils.TextServices.GetTextAsArray`. The body has no output cap, and it refuses only a bare `*` part.
- `src/ExecuteMCPv2/Loc/Generate.cls` (198 lines), `Scanner.cls` (124), `Classifier.cls` (327) -- the library. Its cross-class calls:
  - `Generate:47`, to `Utils`
  - `Generate:88` and `Generate:103`, to `Scanner`
  - `Scanner:117`, to `Classifier`
  - `Scanner:109`, to `%Atelier`
- The result shapes are `Generate.cls:36-40` (metrics) and `EnvSync.cls:44` (hashes).

### Seam and gate

- `src/OcuPilot/Port/HarvestPort.cls` -- `Invoke(pHandler, pMethod, pPairs, .pQuery, pBody, .pResult, .pHttpStatus, .pFault, .pConsole)`. `SanitizeError` turns a body's refusal into `INTERNAL`, so `DevToolPort` validates first. `spec-21-1-the-harvest-seam.md` (Design Notes) explains why the base extends `Kernel.Utils`, and records the measurement that an inherited `..X()` call works in `%SYS`.
- `src/OcuPilot/Port/AtelierPort.cls` -- the gate helpers to reuse:
  - `PAIRS:75`, `Pairs():755`, `NamespacePairs():767`
  - the order in `Invoke:874-907`
  - `NAMESPACEPATTERN` and its reasons
  - `Deny`, `Refuse` and `Fail` (:3347-3368) and `LogFault:3327`, as the shape to follow
  - `Snippet` and `SnippetForm` (:3376, :3400). `DraftRegistry` requires them of every port that defines `Invoke`.
- `src/OcuPilot/Port/DocDbPort.cls` -- a smaller area-port sibling: `Invoke(endpoint, type, .query, body, .answer, .http, .fault)`.

### Kernel

- `src/OcuPilot/Kernel/Utils.cls` -- the harvested helpers (`ValidateRequired`, `SwitchNamespace`, `SanitizeError`, `ReadRequestBody`). The new `DocumentLines` goes here.

### Screens and reads

- `src/OcuPilot/Screen/Read.cls`:
  - the source parameters :167-330
  - the source roster :442, a single line
  - the atelier and encryption branches :527-555, which are the model: `SeedCriteria`, `namespace` from `Kernel.Scope.Current()`, and `maxRows = tMax + 1`
- `src/OcuPilot/Screen/Registry.cls` -- the source roster :1223-1224 (single lines) and the per-port endpoint checks :1286-1300.
- `src/OcuPilot/Screen/Descriptor/ExplorerSearch.cls` -- the model descriptor: `list (server criteria)`, the `%Development` pair, scope `namespace`, id `none`, `classicPage` `""`. System Explorer side-bar positions 1-12 are taken on this branch and on `OCU-1-epic21`.
- `ui/src/app/shell/screen-outlet.ts:56` -- `list (server criteria)` falls back to the generic `AuditPage`, so no custom page is needed. `core/strings.ts` holds the keys (Explorer keys at about :4810-4870). `core/screens.generated.ts` is regenerated by `node tools/screen-mirror.mjs`.

### Errors

- `src/OcuPilot/Api/AtelierError.cls:1-90` -- the `EXPLORER.*` code and reason family. The new codes join it; `Error.cls` already dispatches to it.

### Tests

- `Test/ExplorerProbe.cls` -- the probe-document model: package, routines, `MakeClass`, `MakeRoutine`, `Remove`. It is live-safe and unarmed.
- `Test/AtelierPortFixture.cls:110` and `Test/ScreenGate.cls` -- the deny-gate seam.
- Rosters a new port, screen or tool joins:
  - `PortGate` (ROSTER :29, a single line; a port that evaluates another port's set is written `<class>=<OtherPort>.PAIRS`; a body class is `<stub>`)
  - `SurfaceCoverage`, `ReadTool` (production count and names), `ReadDescriptions`, `Descriptor`, `Navigation` (System Explorer count and list), `ClassicPageGate`, `DraftRegistry`, `ToolEmit`, `ToolRoundTrip`, `Wire`, `WireAreaAnyScreen`
  - client `ui/tools/navigation.test.mjs` and `screen-mirror.test.mjs`
  - No route is added, so `EndpointCoverage` is untouched.

## Tasks & Acceptance

### Execution, batch 1 (server; commit when its loop commands are green):

- **Task 0, before any code.** On `ocupilot-b-ci`, through `docker exec -i ocupilot-b-ci iris session iris -U USER`, measure each of the following and record it under Design Notes:
  1. Which non-`%Atelier` reader gives line arrays identical to `%Atelier.v1.Utils.TextServices.GetTextAsArray(name, 0, .lines)` for one `.cls`, one `.mac`, one `.inc` and one `.int`. Candidates: `%Compiler.UDL.TextServices.GetTextAsArray` with `%Library.Routine`, or `%Library.RoutineMgr`'s `Code`. They must match line count and every line.
  2. Whether a compiled probe class's generated routines are listed with `includeGenerated` 1.
  3. The time a full LOC scan and a full hash scan take per document in `HSCUSTOM`, over about 1,000 documents. `MAXDOCUMENTS` is then the largest multiple of 500, at most 5,000, for which the slower scan is projected to finish under 20 seconds.
  4. Whether the pair set holds as a least-privileged principal. Probe with `%Development:USE` and the namespace's READ withheld in turn.
- `src/OcuPilot/Kernel/Utils.cls` -- add `DocumentLines(pDocName, Output pLines) As %Status`. It answers the array the Atelier reader answers (`pLines(0)` is the count), using Task 0's reader. It must work while the process is switched to any namespace.
- `src/OcuPilot/Port/Harvest/LocGenerate.cls`, `LocScanner.cls`, `LocClassifier.cls` -- new, `[ Abstract ]`, extending `OcuPilot.Kernel.Utils`. Each is the sibling library class, renamed only.
- `src/OcuPilot/Port/Harvest/Loc.cls` -- new. It extends `OcuPilot.Port.Harvest.Handler`, `LocGenerate`, `LocScanner` and `LocClassifier`, and contains `LocCount`, renamed only.
- `src/OcuPilot/Port/Harvest/EnvSync.cls` -- new. It extends `OcuPilot.Port.Harvest.Handler` and contains `DocHashes` and its five helpers, renamed only.
- `src/OcuPilot/Port/DevToolPort.cls` -- new.
  - Parameters: `PAIRS` is `""`, and the gate set is `AtelierPort`'s. Also `GATECLASS`, `LOGSUBSYSTEM` `devtoolport`, `MAXDOCUMENTS` (from Task 0), and the endpoints `CodeMetrics` and `DocumentHashes`.
  - `Invoke(pEndpoint, pType, ByRef pQuery, pBody, Output pResult, Output pHttpStatus, Output pFault)` runs the Always order, then counts matches with the same `%RoutineMgr:StudioOpenDialog` call the bodies make (switched by save and restore), then calls `HarvestPort`.
  - It shapes metrics into one row and hashes into `{Document, Hash, Modified}` rows.
  - Overridable `GateClass()`, `HarvestPortClass()` (production: `OcuPilot.Port.HarvestPort`), `MaxDocuments()` and `LogFault()`; `Snippet` and `SnippetForm` (AD-59).
- `src/OcuPilot/Screen/Read.cls`, `src/OcuPilot/Screen/Registry.cls` -- the source `devtool` (`SOURCEDEVTOOL`, `DevToolPortClass()`):
  - a branch on the atelier branch's model;
  - the two source-roster lines;
  - an endpoint check that admits only `DevToolPort`'s two endpoints with `LIST`.
- `src/OcuPilot/Screen/Descriptor/ExplorerCodeMetrics.cls`, `ExplorerDocumentHashes.cls` -- new, on `ExplorerSearch`'s model.
  - Routes `system-explorer/code-metrics` and `system-explorer/document-hashes`, at side-bar positions 13 and 14.
  - Criteria `spec` (text, 256) and `generated` (choice `yes`/`no`, default `no`).
  - `toolIdentifier`s `explorer.codemetrics` and `explorer.documenthashes`; `classicPage` `""`.
- `src/OcuPilot/Api/AtelierError.cls` -- `EXPLORER.SPEC.WIDE` and `EXPLORER.SPEC.TOOMANY`, with the ruled reasons.
- Roster tests, each edited only for the two screens, two tools and six port-package classes (the port, the two bodies and the three library classes):
  - `Test/PortGate.cls`: `DevToolPort=OcuPilot.Port.AtelierPort.PAIRS`, plus `<stub>` rows for the five body and library classes.
  - The other rosters named in the Code Map.
  - `Screen/Titles.cls`, regenerated.
- `src/OcuPilot/Test/DevToolProbe.cls` -- new. It creates the probe classes, routines and include, and `Remove` deletes them.
- `src/OcuPilot/Test/DevToolPortFixture.cls` -- new. It provides the gate seam, `MaxDocuments()` set to 2 by a `^||` node, `LogFault()` writing into `^||`, and `HarvestPortClass()` answering `OcuPilot.Test.DevToolHarvestRecorder`.
- `src/OcuPilot/Test/DevToolHarvestRecorder.cls` -- new, `Extends OcuPilot.Port.HarvestPort`. It records each `Invoke`'s handler, method and query into `^||`, then calls `##super`, so a test can read whether a body ran and what it was sent.
- `src/OcuPilot/Test/DevToolRead.cls` -- new, under 500 lines. It covers every matrix row and the ACs. `OnBeforeOneTest` and `OnAfterOneTest` reset the fixtures and remove the probe.

### Execution, batch 2 (client; commit when its loop commands are green):

- `ui/src/app/core/strings.ts` -- the ruled strings. `ui/src/app/core/screens.generated.ts` -- regenerated.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- the ruled strings go into Fixed strings, add-only. Then run `cd ui && npm run test:tools`.
- `ui/browser/code-metrics.browser-spec.mjs` -- new. Each screen, given spec `%Library.Persistent.cls` in `USER`, waits for the answered signal and shows one row. For hashes, that row's hash is 64 hex characters. The spec `*` shows the wide-spec reason.

### Acceptance Criteria:

- **AC1.** Given LOC metrics and drift hashes, when each runs, then it round-trips over its backing class. That covers every matrix row from "Metrics" to "Over the cap", observed through the screen read route on `ocupilot-b-ci`.
- **AC2.** Given the five harvested files, when each is compared with its sibling file at `c6aad31` after the rename table, then they are identical. `uv run scripts/check-objectscript.py` passes over them.
- **AC3.** Given any refusal row (Wide spec, Bad shape, Too many, Gate, Unknown namespace), when the read runs, then it answers that row's status and code, and `DevToolHarvestRecorder` recorded no call.
- **AC4 (Integration).** Given the read tools `explorer.codemetrics.read` and `explorer.documenthashes.read`, when called through tool dispatch with the matrix's first spec, then each produces the same rows the screen route answered.

## Spec Change Log

- 2026-11-15, runner spec gate (unattended rulings, veto U-44): the `Proposed split` is applied in `epics.md` (24.1 keeps its title and key; Stories 24.5-24.9 are inserted after 24.4, run after it); the `Proposed strings` are kept as written; `DevToolPort` is built under AD-29's Rule without amending its Binds, and the `Proposed spine amendment` lines and AD-66's "promote, Story 24.1" -> 24.9 wait for the owner's attended architecture update. Contended files checked on 2026-11-15: `origin/OCU-1-epic21` has changed none of them; the runner re-checks before implement and resolves roster lines as plain unions at integrate-forward. The escalation for 24.8 and 24.9 is raised when those stories are planned.

## Review Triage Log

## Design Notes

### Governing ADs

- AD-23: the seam.
- AD-29 and AD-61 rule 1: `DevToolPort` takes `AtelierPort`'s gate.
- AD-16: the bodies switch namespace by save and restore.
- AD-36, AD-5 and AD-24: one bounded read, shared by a screen and its tool.
- AD-21: no SQL text and no path.
- AD-12 and AD-39: one envelope.
- AD-44: no classic page counts code, as with `ExplorerSearch`.
- AD-60: tool results are sanitized.
- AD-1: the work runs in process.
- AD-22: reads only, so no baseline key.
- AD-66: promote stays absent.

### Rename table (AC2)

1. The base changes: `ExecuteMCPv2.REST.Base` becomes `OcuPilot.Port.Harvest.Handler`, with the LOC library added as mixins for `Loc`. In the library, `%RegisteredObject` becomes `OcuPilot.Kernel.Utils` and the class becomes `[ Abstract ]`.
2. `##class(ExecuteMCPv2.Utils).` becomes `..`.
3. `##class(ExecuteMCPv2.Loc.Generate|Scanner|Classifier).` becomes `..`.
4. `##class(%Atelier.v1.Utils.TextServices).GetTextAsArray(<doc>, 0, .<lines>)` becomes `..DocumentLines(<doc>, .<lines>)`.
5. Doc comments are rewritten to state OcuPilot's contract, with no sibling names.

Why the library is inherited and not called: OcuPilot classes may be invisible in the namespace a body switches to. This is measured in `%SYS` (21.1) and inferred for any namespace OcuPilot's package is not mapped to. An inherited `..X()` call works there (21.1, measured). The checker forbids `%Atelier` anywhere, and `DocumentLines` is the call-site replacement.

### Decided in-stage

- **The split.** Plan only DT-07 and DT-08, and propose the rest below. The spawn prompt's suggested first slice, remote profiles, is blocked on the escalation below.
- **Placement.** Both screens go in System Explorer, because they read code under its gate. There is no new area.
- **Metrics rows.** Metrics answers one row of totals. The body's top-documents list is not shown (`topN` 1). This is reversible.
- **The document cap.** The port counts matches first and refuses above `MAXDOCUMENTS`. The bodies have no cap, and a scan through the read tool runs in the turn job, with no gateway to stop it. Truncating after the scan would not bound the cost.
- **Validation in the port.** The port refuses a bare `*` and a bad shape itself, because the body's own refusal would reach the caller as `INTERNAL`.
- **Body class names.** The body classes are `Loc` and `EnvSync`, after the sibling's file names.

### Extend, don't copy (Rule 2/31)

- The gate reuses `AtelierPort.Pairs()` and `NamespacePairs()`.
- The bodies run through `HarvestPort`.
- The descriptors follow `ExplorerSearch`, and the client page is the generic one.
- The count query copies the bodies' six-line `StudioOpenDialog` enumeration. Reason: the body cannot be edited and must not run before the cap.

**Integration ACs:** in-story consumers are the two read tools and the two screens (AC4 and the browser spec).

### Consumed-by:

- Sibling 24.8, for the documents half of environment diff (inference).
- Siblings 24.5 and 24.6, which extend `DevToolPort` with their endpoints.

### Consumes:

- `HarvestPort` and `Port/Harvest/Handler` (21.1)
- `AtelierPort.Pairs` and `NamespacePairs`
- `Kernel.Utils`, `Screen.Read`, `Kernel.Fault`

**DW-2560 (owned by 21.2, not this story).** Story 21.2, on Epic 21's branch, adds the harvest-caller containment rule (`HARVEST_CALLERS`) and a `<body>` PortGate row kind. Whichever of 21.2 and 24.1 reaches feature second adds the other's rows at integrate-forward: `Loc`, `EnvSync` and the library are callable only from `DevToolPort`.

### Contended files (not add-only; check against `OCU-1-epic21` before implement)

- `Screen/Read.cls:442` and `Screen/Registry.cls:1223-1224`. These are single-line source rosters, and 21.2 adds `SOURCEBACKUP` to the same lines.
- `Test/PortGate.cls:29`. The ROSTER is one line, and 21.2 edits it.
- Literal counts and lists that 21.2 also changes:
  - `Test/ReadTool.cls`: the production tool count and the name list.
  - `Test/ReadDescriptions.cls`: the group count.
  - `Test/Navigation.cls`: the System Explorer count and list.
  - `Test/Descriptor.cls`: screen rows.
- System Explorer side-bar positions 13 and 14. They are free on both branches today, but 21.5 and 21.6 may claim them.

Add-only edits: `Kernel/Utils.cls`, `Api/AtelierError.cls`, `SurfaceCoverage`, `strings.ts` and EXPERIENCE.md. `screens.generated.ts` and `Titles.cls` are regenerated.

**Proposed split** (for the runner, Rule 5 tier 2; keys follow Rule 17's numbering). AC1's sentence moves as written, with only its list cut to each sibling's members. AC2-AC4 move verbatim.

- **24.1, retitle "Code metrics and document hashes":** "**Given** the … LOC metrics, drift hashes … **When** each runs **Then** it round-trips over its backing class."
- **24.5 "Unit-test runner and work-queue viewer":** "**Given** the unit-test runner, work-queue viewer … **When** each runs **Then** it round-trips over its backing class."
- **24.6 "The command and class-method consoles":** "**Given** the … execute-command and class-method consoles … **When** each runs **Then** it round-trips over its backing class." It also takes, verbatim, "**Given** the execute-command console's output **When** it is returned **Then** it is bounded by the harvested output ceiling rather than unbounded."
- **24.7 "Web terminal":** "**Given** the … web terminal … **When** each runs **Then** it round-trips over its backing class."
- **24.8 "Remote instance profiles and environment diff":** "**Given** the … environment diff … and remote instance profiles **When** each runs **Then** it round-trips over its backing class." It also takes, verbatim, "**Given** remote instance profiles **When** they are sequenced **Then** they land **before** environment diff and promote, which depend on them."
- **24.9 "Environment promote", after 24.8:** "**Given** the … promote … **When** each runs **Then** it round-trips over its backing class." It also takes, verbatim, "**Given** environment promote **When** it runs **Then** it keeps its four-gate model - plan, execute-with-confirm, a steps allow-list and plan-hash freshness - and the absence of a rollback is stated rather than implied."

AD-66's "promote, Story 24.1" then names 24.9.

**Escalation for 24.8 and 24.9 (owner-candidate; not this story's scope).** Three planning documents contradict remote profiles, diff and promote as worded:

- **NFR-6** (`prd.md` §6, `epics.md:199`): "no request leaves the instance to any host other than the configured provider".
- **PRD §9:** "OcuPilot is not a multi-instance console. It manages the instance that serves it, and only that one."
- **The spine's `## Deferred` row** "Multi-instance management": "Not planned".

Any test connection, diff read or promote write sends a request to another host, and promote writes to that host.

Recommended amendments:

- NFR-6: add "... or a remote instance profile that an OcuPilot administrator configured, from a call a person started or confirmed".
- PRD §9: name environment diff and promote against such a profile as the one exception.
- The spine: a new AD for a remote-instance port. Its host is judged by `Kernel.Egress`, as AD-42 judges a provider's. Its credential comes only through the wallet rung (OcuPilot stores none). It talks only to the remote's `/api/atelier`.

Two further questions for 24.8 (inference):

- Agent-definition writes are a person's own `OcuPilotAdmin` write, not a proposal (`Api/Definitions.cls`). That conflicts with "every write is a confirmed proposal" for profiles.
- The sibling's env-diff reads config, mappings, web apps and default settings through its own REST on both instances (`env-diff.ts:570-800`), which a remote without OcuPilot does not serve.

### Proposed strings (veto item)

- Titles: "Code metrics" · "Document hashes".
- Criteria:
  - "Documents", with the hint "Names separated by commas, with * and ? as wildcards, such as MyApp.*.cls,*.mac."
  - "Include generated".
- Metrics columns: "Documents" · "Lines" · "Code" · "Code %" · "Source code" · "Test code" · "Comments" · "Comments %" · "Blank" · "Blank %".
- Hashes columns: "Document" and "Modified" (existing keys) · "SHA-256".
- Empty, both screens: "No class or routine in this namespace matches that pattern."
- Invites:
  - "Enter a pattern to count the lines of this namespace's classes and routines."
  - "Enter a pattern to list a content hash for each matching class and routine."
- Criterion reasons:
  - "Name the documents: 1 to 256 characters."
  - "generated must be yes or no."
- Prompts:
  - "How much of this package is test code?"
  - "What share of these classes is comments?"
  - "How many lines of code does this package hold?"
  - "List the content hash of every class in this package."
  - "Which of these documents changed most recently?"
  - "How many documents does this pattern match?"
- Aliases: "lines of code", "loc" · "document hashes", "drift hashes".
- Reasons:
  - `EXPLORER.SPEC.WIDE`: "Name a package or a pattern, such as MyApp.*.cls; * on its own covers the whole namespace."
  - `EXPLORER.SPEC.TOOMANY`: "That pattern matches more than <MAXDOCUMENTS> documents, the most one read covers. Narrow it to a package." The number is fixed by Task 0.
  - Shape (`PORT.VALIDATION`): "Name documents with letters, digits, %, dots, * and ?, separated by commas."

### Proposed spine amendment (Rule 20, for the runner)

- Add `DevToolPort` to the Design Paradigm's port list and to AD-29's Binds: "`DevToolPort` runs harvested developer-tool bodies through `HarvestPort`, behind `AtelierPort`'s pairs".
- Append to AD-23: "A harvested call into the vendor's `%Atelier` package becomes `Kernel.Utils.DocumentLines`, which answers the same line array (measured). A harvested support library joins its handler by inheritance, so it resolves while switched."

## Verification

### Shared surfaces:

- the System Explorer side bar and its count
- the screen registry and `screens.generated.ts`
- `Titles`
- the tool registry (the `ReadTool` count and names, the `ReadDescriptions` groups)
- `SurfaceCoverage`, the `PortGate` roster, and the read-source rosters in `Read` and `Registry`
- the `Descriptor` rows and the `EXPLORER.*` codes

The implement stage greps `ui/browser`, `ui/tools`, `ui/src` specs and `src/OcuPilot/Test` for each of these. Every test it changes joins `(loop)`.

*Every test added or changed passes on a fresh environment, in either order.* Each test creates and removes its own `OcuProbe241` documents, and asserts only on them or on vendor documents that always ship.

**Commands.** Run each in the foreground with `timeout: 600000`, one per call, against the throwaway `ocupilot-b-ci` only. Never put two test calls in one message. If no slot B throwaway is up, start one with `sh scripts/ci-throwaway.sh up --dir /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976`.

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/4667058b-f052-49c9-b08a-221f7f41dfab/scratchpad/e24u/24-1/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-24 ocupilot-b-ci`. Expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.DevToolRead`. Then run each of the following the same way, one per call: `Harvest`, `PortGate`, `SurfaceCoverage`, `ReadTool`, `ReadDescriptions`, `Descriptor`, `Navigation`, `ClassicPageGate`, `DraftRegistry`, `ToolEmit`, `ToolRoundTrip`, `Wire` and `WireAreaAnyScreen`. Expected: green.
- `(loop)` `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` `cd ui && npm run build && npm run test:components`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/code-metrics.browser-spec.mjs`. Expected: green.
- `(loop)` `cd ui && npm run test:tools`. Expected: green.
- `(loop)`, AC2 check: for each harvested file, apply the rename table to the sibling file with `sed` into the scratch directory, then `diff` the result against the new file, ignoring doc-comment lines. Expected: no other difference.
- `(once)` The full ObjectScript sweep: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one per call. That is about 7.7 minutes each from `ci-timings.json` (7,887 s over 716 classes). Expected: green. The full browser suite is left to CI.

### Mutations (Rule 19), one per AC:

- AC1: `DevToolPort` sends `includeGenerated` 1 always. Expected red: the Generated row.
- AC2: add one statement to `Loc.LocCount` (change the `topN` default to 21). Expected red: the AC2 diff command.
- AC3: move the wide-spec check after the `HarvestPortClass()` call. Expected red: the Wide spec row's no-call assertion.
- AC4: point the code-metrics descriptor's tool read at `DocumentHashes`. Expected red: the Read tool row.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned as the first slice only (DT-07, DT-08). For the runner's spec gate, under Design Notes: the `Proposed split` (five siblings, 24.5-24.9), the `Proposed strings`, the proposed spine amendment, the contended-file list, and the escalation for 24.8 and 24.9 (NFR-6, PRD section 9 and the spine's Deferred row contradict remote profiles, diff and promote as worded).
