---
title: 'Story 24.8: Remote instance profiles and environment diff (same instance: namespace diff of documents; remote profiles excluded)'
type: 'feature'
created: '2026-11-16'
status: 'done'
baseline_revision: 'afad7c84244352652d116556b8b8814faac3483a'
baseline_commit: 'afad7c84244352652d116556b8b8814faac3483a'
review_loop_iteration: 0
followup_review_recommended: true
context: []
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The owner ruled (U-45, "C: same instance only") that environment diff compares two namespaces of this instance, and that remote instance profiles are not built. OcuPilot has no way to see which classes and routines differ between two of its namespaces, and the catalog, the stage extract and the exclusion register still treat remote profiles as planned P3 work that diff and promote depend on.

**Approach:** Add a third endpoint, `NamespaceDiff`, to `DevToolPort`. It runs Story 24.1's harvested `EnvSync.DocHashes` body once per namespace through `HarvestPort`, each namespace behind its own gate, and compares the two hash lists using the sibling's rules (only in this namespace, only in the other, content differs). Show it on a new read-only System Explorer screen, Compare namespaces, drawn by 24.1's `dev-tool.page.ts`, with its read tool. Move DT-11 to P4 and record it in the exclusion register, with the catalog and stage-extract changes the register test requires. Reword DT-09 and DT-10 to this instance's namespaces.

## Boundaries & Constraints

**Always:**

- `DevToolPort` stays the only caller of `OcuPilot.Port.Harvest.EnvSync`. For `NamespaceDiff` it checks the following, in this order, before any body runs:
  1. `AtelierPort.Pairs()`.
  2. This namespace (the route's scope): its shape, then `AtelierPort.NamespacePairs`, evaluated.
  3. The endpoint and type.
  4. `target`: its shape, not this namespace (compared upper-cased), then `AtelierPort.NamespacePairs(target)`, evaluated. A namespace whose pairs answer `""` is refused.
  5. `maxRows`, `generated` and the spec's shape and wide rule, as 24.1 checks them.
  6. The document count in each namespace against `MaxDocuments()`.
- Each body call gets `Pairs()` plus that namespace's own pairs. It is sent only `spec`, `namespace` and `includeGenerated`, which the port built itself (AD-29, AD-61 rule 1).
- Comparison rules, taken from the sibling's `diffDocuments` and nothing else from it:
  - A document is keyed by its name.
  - Equal hashes are identical whatever the timestamps.
  - Only drift rows are answered, sorted by `Document`, at most `maxRows` of them.
  - A document only in the other namespace is reported and is never a deletion signal.
- The screen and `explorer.namespacediff.read` share one bounded read that reports truncation (AD-5, AD-24, AD-36).
- Planning-document edits are appended where a list is shared with Epic 21; counts are re-derived from the rows.

**Never:**

- Nothing here sends an HTTP request or names `%Net.*`. No remote profile, host, credential or connection setting exists anywhere (NFR-6, U-45).
- No write, proposal, governance key, route or new port.
- No edit to `Port/HarvestPort.cls`, `Port/Harvest/Handler.cls` or `Port/Harvest/EnvSync.cls`. No sibling class name or `%Atelier` token, comments included.
- No caller value in SQL and no path (AD-21).
- No mappings, default-settings, web-application or configuration comparison (Design Notes, Named limits).
- No new AD or spine edit. NFR-6, PRD §9 and the spine's Deferred row "Multi-instance management" stand unchanged.

## I/O & Edge-Case Matrix

The probe package is `OcuProbe248`, made by `Test/DevToolProbe.MakePair("USER", "HSCUSTOM")`:

- in both namespaces: `Same` (identical) and `Changed` (a different method body in each);
- only in USER: `OnlyHere` and `OcuProbe248Mac.mac`;
- only in HSCUSTOM: `OnlyThere`.

The screen's namespace is USER and `target` is HSCUSTOM. Every row is observed on `ocupilot-b-ci`, unless the row says otherwise:

- through `Screen.Read.Execute` with 24.1's fixture seams (`DevToolPortFixture`, `DevToolHarvestRecorder`, `ScreenGate`), as `DevToolRead` drives them;
- the Diff, Identical and Same namespace rows also through the deployed route `GET /screens/system-explorer/namespace-diff/read`, in the browser spec.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Diff | spec `OcuProbe248.*.cls,OcuProbe248*.mac` | Four rows, in `Document` order. `Changed` reads `Content differs`, and its two hashes are unequal and non-empty. `OnlyHere` and the `.mac` read `Only in this namespace`, with `OtherHash` and `OtherModified` empty. `OnlyThere` reads `Only in the other namespace`, with `Hash` and `Modified` empty. `Same` has no row. Each `Hash` and `OtherHash` equals what `DocumentHashes` answers for that document in its own namespace. `truncated` is false. | none |
| Identical | spec `OcuProbe248.Same.cls` | No rows, `truncated` false | none |
| Generated | `generated` `yes`, then `no` | The recorder shows two body calls, each with `includeGenerated` 1, then each with 0 | none |
| Cut | `maxRows` 2 | Two rows, `truncated` true | none |
| Same namespace | `target` `user` or `USER` | 400 `PORT.VALIDATION`: "Choose a namespace other than this one to compare with." No body runs. | not logged |
| Bad target | `target` empty, or containing a space or `/` | 400 `PORT.VALIDATION`: "Name the namespace to compare with." No body runs. | not logged |
| Unknown target | `target` `NOSUCHNS248` | 400 `PORT.VALIDATION`, with `AtelierPort`'s `REASONNAMESPACEUNKNOWN`. No body runs. | not logged |
| Target gate | `%DB_HSCUSTOM:READ` denied through the `ScreenGate` seam | 403 `AUTH.NOPRIVILEGE`, `detail.failedPair` `%DB_HSCUSTOM:READ`. No body runs. | not logged |
| Wide or bad spec | `*`; `OcuProbe248..x` | 400 `EXPLORER.SPEC.WIDE`; 400 `PORT.VALIDATION`. No body runs. | not logged |
| Too many | the fixture cap is 3, with the Diff spec. USER matches 4 and HSCUSTOM 3 | 400 `EXPLORER.SPEC.TOOMANY`, `detail` `{count: 4, max: 3, namespace: "USER"}`. No body runs. | not logged |
| Read tool | `explorer.namespacediff.read` `{target: "HSCUSTOM", spec: <Diff's spec>}` | The same rows the route answered | the same refusals |

</intent-contract>

## Code Map

### The port and the body

- `src/OcuPilot/Port/DevToolPort.cls` -- the class to extend. Its parts:
  - the header (the gate order) and the `ENDPOINT*` parameters;
  - `Endpoints()` :124;
  - `Invoke` :151-237: the gate, the endpoint check at :182, the spec checks, `CountDocuments` and the `HarvestPortClass()` call at :228;
  - `CountDocuments` :266, `HashRows` :309;
  - `Refuse` :344, whose `detail` argument carries `TOOMANY`'s fields;
  - the reasons it borrows: `AtelierPort.REASONNAMESPACESHAPE` :567, `REASONNAMESPACEUNKNOWN` :571, `NAMESPACEPATTERN` :524.
- `src/OcuPilot/Port/Harvest/EnvSync.cls` -- `DocHashes`. It answers `{documents: [{name, hash, timestamp}], count}`. Read-only.
- Sibling rules, read-only: `/Users/jbrandt/git/iris-execute-mcp-v2/packages/iris-dev-mcp/src/tools/env-diff.ts`, `diffDocuments` :390-430 at `c6aad31`. Only its bucketing rules are taken. Its transport (`fetchDocHashes`, two profile clients) and its other four domains are not.

### Screens and reads

- `src/OcuPilot/Screen/Read.cls:579-593` -- the `devtool` branch. It seeds the criteria and then overwrites `namespace` with the scope, so the new criterion is `target`, never `namespace`. Unchanged.
- `src/OcuPilot/Screen/Registry.cls:1438-1455` and `ui/tools/screen-mirror.mjs:1185-1202, 1648-1663` -- both admit a devtool endpoint by reading `DevToolPort`'s `Endpoints()` and its `ENDPOINT*` parameters. The new parameter must match `^Parameter\s+ENDPOINT[A-Z]+\s*=\s*"..."\s*;`.
- `src/OcuPilot/Screen/Descriptor/ExplorerDocumentHashes.cls` -- the model descriptor. Positions 13 and 14 are 24.1's. Epic 21's Story 21.5 claims 15 (`origin/OCU-1-epic21`, `spec-21-5`). `navigation.test.mjs:130` checks order only, so gaps are allowed.
- `ui/src/app/areas/system-explorer/dev-tool.page.ts` (277 lines) and `dev-tool.store.ts` (68 lines; `DevToolState extends SentSearchState`) -- the page and store to extend.
- `ui/src/app/shell/screen-outlet.ts:222-223` -- the 24.1 loader lines. Append one more.
- `ui/src/app/areas/system-explorer/code-compare.page.ts:105-108` -- the namespace `<select>` over `scope.namespaces()`. The target control is modeled on it.

### Tests

- `src/OcuPilot/Test/DevToolProbe.cls` (124 lines; `Make`, `Remove`, `Body`) -- extended with the `OcuProbe248` pair.
- `src/OcuPilot/Test/DevToolPortFixture.cls` -- the gate seam, `MaxDocuments` and `LogFault`.
- `src/OcuPilot/Test/DevToolHarvestRecorder.cls` -- records each call. Reused unchanged.
- `src/OcuPilot/Test/DevToolRead.cls` -- the model. At 517 lines it is too long to extend.
- The devtool endpoint refusal sentence lists the endpoints. It is pinned in `DevToolRead`'s `Cases` corpus and in `ui/tools/screen-mirror.test.mjs` ("the devtool source refusals agree").
- Roster pins that a new screen or read tool joins:
  - `Test/ReadTool.cls:94` (names and count)
  - `Test/ExplorerDescriptor.cls:161`
  - `Test/DeveloperFloor.cls:45`
  - `SurfaceCoverage`, `ReadDescriptions`, `Descriptor`, `Navigation`, `ClassicPageGate`, `DraftRegistry`, `ToolEmit`, `ToolRoundTrip`, `Wire`, `WireAreaAnyScreen`
  - client `ui/tools/navigation.test.mjs` and `screen-mirror.test.mjs`
  - `ui/browser/definitions.browser-spec.mjs`, for the aliases
- `ui/browser/code-metrics-route.browser-spec.mjs:28-35` -- the model for a browser spec that makes probes through `runIris` and asserts it is on the throwaway.

### The register and its sources

- `docs/exclusion-register.md:218-229` -- the last group. Its `EX-58` row is the model for DT-11's row: `not-applicable`, "an architecture decision lets OcuPilot connect to another instance".
- `ui/tools/exclusion-register.test.mjs` checks three things:
  - the register equals the catalog's P4 rows;
  - the extract's Stage 5 rows equal the catalog's P4 rows;
  - group *n* of the register holds exactly group *n* of the extract, sorted.
  A row in the existing last group therefore needs no edit to Story 22.1's wording.
- `_bmad-output/planning-artifacts/research/technical-ocupilot-portal-feature-landscape-2026-09-08/feature-catalog.md`:
  - the summary table, row 13 and the totals :35, :37;
  - DT-09, DT-10 and DT-11 :621-623;
  - the DT-11 judgment call :686.
- `_bmad-output/planning-artifacts/prds/prd-OcuPilot-2026-09-08/extract-stages.md`:
  - the mapping rules, items 4 and 5 (:28-29);
  - Stage 4: the header :369, the prose :371, the DT rows :606-608, the readiness bullet :623 and the DT and total counts;
  - Stage 5: the header, the last group :737-748 and its counts;
  - §3's sentence on non-custom rows :826;
  - the roll-up :966-967.
- `_bmad-output/planning-artifacts/epics.md:353-354` (post-contest stage table) and `prds/prd-OcuPilot-2026-09-08/extract-catalog.md:408` (a copy of the judgment call).

## Tasks & Acceptance

**Execution, batch 1 (server; commit when its loop commands are green):**

- **Task 0, before code, on `ocupilot-b-ci`.** Time `DocumentHashes` on a 1,000-document spec in USER and in HSCUSTOM in one call each. Record both times under Design Notes. The expected pair total is under 2 s, inferred from 24.1's 0.26-0.30 ms a document. If either takes over 10 s, stop and report.
- `src/OcuPilot/Port/DevToolPort.cls`:
  - Add `ENDPOINTNAMESPACEDIFF = "NamespaceDiff"`, `TARGETKEY = "target"`, the two new reasons and the three `Change` values as parameters, and add the endpoint to `Endpoints()`.
  - In `Invoke`, after the endpoint check, add the target steps from the Always list, before `maxRows`.
  - Count each namespace. Over the cap, refuse with `detail.namespace` naming the one that exceeded it.
  - Call the hash body (`HANDLERHASH`, `METHODHASH`) once per namespace, each with `Pairs()` plus that namespace's pairs. Then shape the two answers with a new pure `DiffRows(pHere, pThere, pMax)`, which reads each answer's `documents` as `HashRows` does.
  - Update the header's ordered list and the answers paragraph.
- `src/OcuPilot/Screen/Descriptor/ExplorerNamespaceDiff.cls` -- new, on `ExplorerDocumentHashes`'s model:
  - route `system-explorer/namespace-diff`, side-bar position 16, `list (server criteria)`, scope `namespace`, id `none`;
  - entity `class`, secondary `routine`;
  - privileges `%Development:USE`, `classicPage` `""`;
  - read `{port: devtool, endpoint: NamespaceDiff, type: LIST}`;
  - fields `Document`, `Change`, `Hash`, `OtherHash`, `Modified`, `OtherModified`; filter `Document` and `Change`; sort default `Document`;
  - criteria: `target` (text, 64, with its hint), then `spec` and `generated` exactly as in hashes;
  - columns `Document`, `Change`, `Modified`, `OtherModified`;
  - `toolIdentifier` `explorer.namespacediff`.
- `src/OcuPilot/Screen/Titles.cls` -- regenerated.
- `src/OcuPilot/Test/DevToolProbe.cls` -- add `MakePair(pHere, pThere)` and `RemovePair(pHere, pThere)` for the `OcuProbe248` documents in the matrix. Leave `OcuProbe241` untouched.
- `src/OcuPilot/Test/NamespaceDiffRead.cls` -- new, under 500 lines, with a header that says what it pins and that it needs USER and HSCUSTOM.
  - Every matrix row, each refusal asserting `DevToolHarvestRecorder.Calls()` 0.
  - The Diff row asserts exactly two calls: one per namespace, each with its namespace's pairs, and keys `spec`, `namespace` and `includeGenerated` only.
  - The hash-equality leg compares against `DocumentHashes` read per namespace.
  - `OnBeforeOneTest` and `OnAfterOneTest` reset the fixtures and call `RemovePair`.
- Roster and corpus pins -- add this story's one screen and one tool to each pin in the Code Map. Each count is re-derived; the devtool endpoint sentence gains `NamespaceDiff`.

**Execution, batch 2 (client):**

- `ui/src/app/areas/system-explorer/dev-tool.store.ts` -- add `TARGET_PARAM` and the target value to `DevToolState`. `search()` also refuses an empty target when the screen declares one. `useArrival` reads `target`.
- `ui/src/app/areas/system-explorer/dev-tool.page.ts` -- when the descriptor declares `target`, draw a `<select>` of `scope.namespaces()` other than the current one, first in the form, defaulting to the first of them. Update the doc comment. Add one `.spec.ts` case for the target.
- `ui/src/app/shell/screen-outlet.ts` -- the loader line.
- `ui/src/app/core/strings.ts`, `screens.generated.ts` (`node tools/screen-mirror.mjs`), and EXPERIENCE.md's Fixed strings -- add-only, with each string's line citation, as 24.1 did.
- `ui/browser/namespace-diff.browser-spec.mjs` -- new.
  - Through `runIris`, call `MakePair`, and `RemovePair` in `after`. Assert the throwaway first.
  - Open the screen in USER, choose HSCUSTOM, enter the Diff spec and wait for the answered signal. Assert the three `Change` values on their documents and that `Same` is absent.
  - Then spec `OcuProbe248.Same.cls` shows the empty sentence, and `target` USER over the read route answers the same-namespace reason.

**Execution, batch 3 (planning documents and the register):**

- `docs/exclusion-register.md` -- append a DT-11 row to `### Dead references, dead placeholders and cosmetic items`:
  - Feature: "Remote instance profiles".
  - Reason: "OcuPilot manages the instance that serves it, and no request leaves it except to the configured provider (NFR-6). Environment diff compares two namespaces of this instance instead."
  - Gate kind: `not-applicable`.
  - Gate: "Only an amendment to the architecture that lets OcuPilot administer a different instance makes the row apply."
  - How to tell it has cleared: "An architecture decision lets OcuPilot connect to another instance."
- `feature-catalog.md`:
  - DT-11's tier becomes P4, and its Evidence ends "— excluded: OcuPilot manages the instance that serves it (owner answer U-45, 2026-11-16)".
  - DT-09 and DT-10 are reworded as in Design Notes.
  - Section 13 changes to P3 9 and P4 2; the totals change to P3 163 and P4 57.
  - The :686 judgment call is replaced with "**DT-11 remote instance profiles at P4** (owner answer U-45): environment diff and promote (DT-09, DT-10) compare namespaces of this instance."
- `extract-stages.md` -- move the DT-11 row from Stage 4 to Stage 5's last group, which becomes "— 9 rows", with:
  - Note: "Excluded: not applicable; OcuPilot manages the instance that serves it."
  - DT-09's note: "Between two namespaces of this instance."
  - DT-10's note: its "depends on DT-11" dropped.
  - The readiness bullet keeping only its DT-04 clause.
  - Stage 4's prose without "and remote profiles".
  - Stage 4 counts: DT M 3, total 9; Stage 4 total 164, M 78.
  - Stage 5 counts: DT M 1, total 2; Stage 5 total 57, M 30.
  - Mapping rules: 163 P3 and 57 P4 rows.
  - §3: "The six Stage 4 rows", without DT-11.
  - Roll-up: rows 4 and 5 re-derived, the "DT-11 before DT-09/10" clause dropped, totals unchanged.
- `epics.md:353-354` -- Stage 5 row 164, M 78, with the "DT-11 before DT-09/DT-10" clause dropped; Stage 6 row 57, M 30. Then `cd ui && npm run test:tools`.
- `prds/prd-OcuPilot-2026-09-08/extract-catalog.md:408` -- the same replacement as the catalog's :686.

**Acceptance Criteria:**

- **AC1.** Given environment diff between two namespaces of this instance, when it runs, then it round-trips over its backing class. That covers matrix rows Diff, Identical, Generated and Cut, observed on `ocupilot-b-ci` as the matrix preamble says (Diff and Identical also over the deployed route). Every hash equals `EnvSync.DocHashes`'s answer for its own namespace.
- **AC2.** Given any refusal row of the matrix, when the read runs, then it answers that row's status, code and reason, and `DevToolHarvestRecorder` recorded no call.
- **AC3.** Given two namespaces, when a diff runs, then each namespace passed its own gate. A caller who may read this namespace but not the other is refused 403, naming the other namespace's pair.
- **AC4 (Integration).** Given `explorer.namespacediff.read` called through tool dispatch with the Diff row's arguments, when it answers, then its rows equal the route's. Given the Compare namespaces screen on the redeployed bundle, when a person runs the Diff search, then the browser shows the three changes.
- **AC5.** Given remote instance profiles, when this story lands, then the exclusion register holds DT-11 as not planned, with the reason (no request leaves the instance, NFR-6; OcuPilot manages the instance that serves it). The catalog marks DT-11 P4, and `exclusion-register.test.mjs` passes.

## Spec Change Log

- 2026-11-16, runner spec gate (unattended rulings, one veto item): (1) the diff compares documents only in this story; the two per-namespace domains it leaves out stay in Epic 24: interoperability default settings are compared by Story 24.15 on its own read (ledger DW-2636, an acceptance bullet in 24.15's block), and mappings go to the Epic 24 burn-down (DW-2635); the frontmatter `deferred:` list was harvested at this gate and emptied. Instance-wide domains (web applications, configuration) cannot differ between two namespaces of one instance. (2) The `Proposed strings` are kept as written. (3) The catalog, stage-extract and `epics.md` stage-table edits are Rule 5 tier-1 amendments applied by this story and reported; the totals Epic 21 also re-derives resolve as unions at integrate-forward (orchestrator ruling A).

## Review Triage Log

### 2026-11-15 -- Review pass

- verdicts: 14 findings -- high 0, medium 3, low 6, false 0, maybe-false 0, descriptive 5
- findings:
  - `[medium]` `[patch]` Same-hash-different-time rule not deterministically pinned (verification-gap) -- `MakePair` now saves the second namespace a second later and the Diff test asserts `Same`'s two `Modified` values differ with equal non-empty hashes; mutation (compare time with hash) reddened four tests.
  - `[medium]` `[patch]` Identical row and the `Same` equality pass when `Same` is absent from both (verification-gap) -- both tests assert a non-empty `Same` hash in each namespace.
  - `[medium]` `[patch]` No-other-namespace branch of the target control untested (verification-gap) -- added a one-namespace case in `dev-tool.page.spec.ts`; mutation of the hint condition reddened it.
  - `[low]` `[patch]` Cap equal to the row count not observed (verification-gap) -- `TestACapBelowTheRowCountTruncates` gains a cap-4 leg: four rows, not truncated.
  - `[low]` `[patch]` Browser spec comment claimed a mutation the route cannot show (verification-gap, other) -- reworded to say the unit class pins it.
  - `[low]` `[patch]` `## Verification` had no literal `mutation:` lines (verification-gap, other) -- written, one per AC plus the client cases.
  - `[low]` `[reject]` Agent arrival naming a namespace the select does not list shows the first option while the read used the named one (verification-gap, other; intent-alignment) -- reachable only by an agent naming an unlisted namespace, which is refused with its reason; the fix needs the store to know the options.
  - `[low]` `[reject]` Target gate order against `maxRows` and the spec checks is not pinned by a test (intent-alignment) -- each refusal test supplies one defect, and the order is a header contract with a mutation on the same-namespace step; a second ordering test is not worth its lines.
  - `[low]` `[defer]` `epics.md:957` still says "DT-11 lands before DT-09 and DT-10" -- it sits in Epic 21's story block, which this story may not edit; filed in `deferred:`.
  - `[descriptive]` `[reject]` Three readings of the intent (contract, capability, planning realignment) -- the diff implements all three; no divergence to act on.
  - `[descriptive]` `[reject]` AC3 is proven through the `ScreenGate` seam, not a real principal; the route and browser run as the administrator -- the spec names the seam as the test's means; a real-principal leg is 24.4's pattern and outside this story's tests.
  - `[descriptive]` `[reject]` The tool leg asserts the refusal code and the route spec asserts the reason -- AD-60 sanitizes the tool result; recorded in Design Notes.
  - `[descriptive]` `[reject]` DT-09 is reworded to documents, mappings and default settings while the screen compares documents only -- the spec's Planning amendments and the spec-gate rulings send the other two to 24.15 and the burn-down.
  - `[descriptive]` `[reject]` `truncated` comes from the shared read, not the port -- the spec's Always list says the screen and tool share one bounded read that reports truncation.

## Design Notes

**Governing ADs (Rule 6):**

- AD-23: the body runs unedited through the seam.
- AD-29 and AD-61 rule 1: one gate per namespace.
- AD-16: the bodies switch namespace by save and restore.
- AD-36, AD-5 and AD-24: one bounded read, shared by the screen and its tool.
- AD-21: no SQL, no path.
- AD-60: tool results are sanitized.
- AD-44: there is no classic page.
- AD-14: re-read on a class or routine change.
- AD-12 and AD-39: one envelope.
- AD-1: in process.
- AD-22: reads only, so no key.

Checked and not engaged: AD-62 (no default settings are read; see Named limits), AD-2 and AD-27 (no admin port), AD-6 and AD-15 (no write), and AD-66 (promote is 24.9). The spine needs no edit. 24.1's proposed `DevToolPort` line for AD-29's Binds still waits for the owner's attended update.

**Decided in-stage:**

- **The diff compares documents only.** Web applications and configuration are instance-wide, so they cannot differ between two namespaces of one instance. Mappings and default settings are per namespace but sit behind other gates, on other screens. They are named limits, carried in frontmatter `deferred:` for the runner to own. **This is a veto item for the runner's spec gate.** If the runner judges it dropped scope, it is owner-only.
- **Drift rows only.** Identical documents are not listed, as the sibling does not list them. The empty sentence says so.
- **Placement.** The screen goes in System Explorer at position 16, so it does not collide with 21.5's 15; the side bar checks only order.
- **The target control is a select.** It lists the instance's namespaces, as Compare does. To the tool, `target` is text checked by the port.
- **`detail.namespace` on TOOMANY** names which namespace exceeded the cap.
- **The register row goes in the existing last group**, beside EX-58, so Story 22.1's group wording stays unchanged.
- **Planning copies left as they are.** `research.md:440` and `research-briefing.html:335` are dated research reports whose own P3 count is a snapshot. `prd.md` §10.3 stays unchanged (U-45: PRD stands). `reconcile-catalog.md:350` records a past reconciliation.
- **Hash equality ignores timestamps**, as the sibling's default does: a recompile with no content change is not drift.

**Decided in implement:**

- **Task 0.** `DocumentHashes` over 971 documents (`%Library`, `%SYS`, `%Dictionary`, `%Net` classes) through `DevToolPort.Invoke` on `ocupilot-b-ci`: 0.66 s in USER and 0.72 s in HSCUSTOM, 1.4 s for the pair.
- **Read row** is "document that differs between namespaces" (40 characters): AD-36 caps `read.row` at 40 and the proposed 47-character sentence is refused by the mirror generator.
- **"Change" column** reuses the existing string `databaseDirectoryChange` (`strings.test.mjs` refuses a duplicate value), so no `explorerColumnChange` key exists; EXPERIENCE.md lists "Change" once, already.
- **Namespace-named string keys** (`explorerNamespaceDiff*`, `explorerOtherNamespaceLabel`) join the roster in `strings.test.mjs`.
- **`DevToolHarvestRecorder`** also records each call's `pairs` (`resource:permission`, comma-separated), so the Diff row can pin each body's pair set; the existing assertions read other keys.
- **The route's refusal** reaches the tool as its code alone (`{"code":"PORT.VALIDATION"}`, AD-60), so the tool leg asserts the code and the route spec asserts the reason.
- **Count re-derived beyond the listed lines:** `extract-stages.md:17` (P3 163, P4 57) and the "18 P4 rows with backing `none`" sentence (19, DT-11 included), verified by parsing both stages. `epics.md:957` ("DT-11 lands before DT-09 and DT-10") is not in this story's list and is left for the next planning touch.
- **No other control** for a namespace with nothing else to compare with: the form says "Name the other namespace: 1 to 64 characters." and sends nothing.

**Named limits:**

- No mappings, default settings, web applications or configuration are compared.
- A "Content differs" row does not link to Compare's line diff.
- The cap is per namespace (1,000 documents each).

**Planning amendments (Rule 5 tier 1, apply and report):**

- **Catalog DT-09:** "Environment diff (documents, mappings and default settings between two namespaces of this instance)". Backing: "custom(EnvSync in both namespaces; mapping and default-settings reads)". Harvest source: "execute-mcp env-diff.ts (comparison rules)".
- **Catalog DT-10:** "Environment promote between two namespaces of this instance (plan / execute with confirm, steps allowlist, plan-hash freshness)". "Target governance" is dropped, because it was a remote profile's governance.
- **DT-11:** to P4 (U-45).
- **The extract and `epics.md:353-354` totals**, as listed in batch 3.

**Contended or more-than-appending edits** (check `origin/OCU-1-epic21` before implement; 21.12 moves six rows into a new Stage 5 group 2 and re-derives the same totals):

- `feature-catalog.md` (three rows, the summary table, the judgment call)
- `extract-stages.md` (the Stage 4 to 5 move and its totals)
- `epics.md:353-354`
- `prds/.../extract-catalog.md:408`
- `DevToolPort.cls`
- `dev-tool.page.ts` and `dev-tool.store.ts`
- the literal counts in `ReadTool`, `Navigation`, `Descriptor`, `ExplorerDescriptor`, `ReadDescriptions` and `DeveloperFloor`
- the devtool endpoint sentence in two corpora

Add-only: `exclusion-register.md`, `strings.ts`, EXPERIENCE.md, `screen-outlet.ts`, `SurfaceCoverage`. Regenerated: `Titles.cls`, `screens.generated.ts`.

**Extend, don't copy (Rules 2 and 31):**

- The port, the page and the store are extended.
- The probe is extended.
- The recorder and fixture are reused.
- The descriptor is a new file on hashes' model, because AD-5 has one descriptor for each screen.
- `NamespaceDiffRead` is a new class because `DevToolRead` is past 500 lines (DW-2583).

**Integration ACs:** AC4.

- **Consumes:** `DevToolPort` and `EnvSync.DocHashes` through `HarvestPort` (24.1, 21.1); `AtelierPort.Pairs` and `NamespacePairs`; `Screen.Read`'s devtool source; `dev-tool.page.ts`; `SentSearchState`.
- **Consumed-by:** Story 24.9, whose promote plan reads this diff's rows to choose the documents it moves.

**Governance keys:** none, because the story only reads.

**Proposed strings (veto item):**

- Title: "Compare namespaces".
- Criterion: "Other namespace". Tool hint: "The namespace to compare this one with, spelled as osmgmt.namespaces.read answers its Name." Criterion reason: "Name the other namespace: 1 to 64 characters."
- Columns: "Change" · "Modified here" · "Modified there". "Document" reuses an existing key.
- Change values: "Only in this namespace" · "Only in the other namespace" · "Content differs".
- Empty: "No difference: every matching class and routine is the same in both namespaces."
- Invite: "Choose another namespace and enter a pattern to see which classes and routines differ."
- Prompts:
  - "Which classes differ between this namespace and the other one?"
  - "What does this namespace hold that the other one lacks?"
  - "Has this package drifted from the other namespace?"
- Aliases: "compare namespaces", "namespace diff", "environment diff".
- Reasons: "Choose a namespace other than this one to compare with." · "Name the namespace to compare with."
- Read row: "document that differs between the two namespaces".

## Verification

**Shared surfaces:**

- the System Explorer side bar and its count;
- the screen registry, `screens.generated.ts` and `Titles`;
- the read-tool roster (`ReadTool`, `ReadDescriptions`, `ExplorerDescriptor`, `DeveloperFloor`);
- `SurfaceCoverage`;
- the `Descriptor` rows;
- the devtool endpoint refusal sentence;
- the command-box aliases;
- the exclusion register and the catalog and extract totals.

The implement stage greps `ui/browser`, `ui/tools`, `ui/src` specs and `src/OcuPilot/Test` for each of them, and every test it changes joins `(loop)`.

*Every test added or changed passes on a fresh environment, in either order.* Each test creates and removes its own `OcuProbe248` documents in USER and HSCUSTOM, and asserts only on them.

**Commands.** Each runs in the foreground with `timeout: 600000`, one call at a time, against `ocupilot-b-ci` only. Never put two test calls in one message.

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/4667058b-f052-49c9-b08a-221f7f41dfab/scratchpad/e24u/24-8/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-24 ocupilot-b-ci` -- expected: `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.NamespaceDiffRead`. Then the same command, one class per call (or several `--class` flags under about 170 s), for `DevToolRead`, `SurfaceCoverage`, `ReadTool`, `ReadDescriptions`, `Descriptor`, `ExplorerDescriptor`, `DeveloperFloor`, `Navigation`, `ClassicPageGate`, `DraftRegistry`, `ToolEmit`, `ToolRoundTrip`, `Wire` and `WireAreaAnyScreen` -- expected: green.
- `(loop)` `uv run scripts/check-objectscript.py`, `uv run scripts/test_check_objectscript.py` and `bash scripts/lint-docs.sh` -- expected: clean.
- `(loop)` `grep -nE '%Net\.|HttpRequest' src/OcuPilot/Port/DevToolPort.cls` -- expected: no match (NFR-6).
- `(loop)` `cd ui && npm run build && npm run test:components`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/namespace-diff.browser-spec.mjs` -- expected: green.
- `(loop)` `cd ui && npm run test:tools` -- expected: green, the register test included.
- `(once)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one per call -- expected: green. The full browser suite is left to CI.

**Mutations (Rule 19), one per AC.** Each is applied on `ocupilot-b-ci`, the tree is recompiled, the red is observed, and the file is restored byte for byte:

- AC1: `DiffRows` drops "only in the other namespace" rows. Expected red: the Diff test.
- AC2: move the same-namespace check after the body calls. Expected red: the Same-namespace test's no-call assertion.
- AC3: skip evaluating `NamespacePairs(target)`. Expected red: the Target-gate test.
- AC4: point the descriptor's endpoint at `DocumentHashes`. Expected red: the read-tool test and the browser spec.
- AC5: remove the DT-11 register row. Expected red: `exclusion-register.test.mjs`.

Observed on `ocupilot-b-ci` (each file restored byte for byte, checked with `cmp`):

- mutation: AC1, `DiffRows` skips a document only in the other namespace -> `TestTheDiffListsEachDifferenceAndNotTheSameDocument` and `TestTheReadToolAnswersTheScreenRows` red.
- mutation: AC1, `DiffRows` compares the time with the hash -> `Same` becomes a row; the Diff, Identical, Cut and read-tool tests red.
- mutation: AC2, the same-namespace check moved after the body calls -> `TestTheSameNamespaceIsRefusedBeforeAnyBody` red.
- mutation: AC3, `NamespacePairs(tTarget)` not evaluated -> `TestACallerWhoMayNotReadTheOtherNamespaceIsRefusedBeforeAnyBody` red.
- mutation: AC4, the descriptor's endpoint set to `DocumentHashes` -> ten tests of `NamespaceDiffRead`, the read-tool test among them, and all three tests of `namespace-diff.browser-spec.mjs` red.
- mutation: AC5, the DT-11 register row removed -> two tests of `exclusion-register.test.mjs` red.
- mutation: client, `target` left out of `search()` -> two cases of `dev-tool.page.spec.ts` red; this namespace offered in `targetOptions` -> two cases red; the hint's `length === 0` condition made false -> the no-other-namespace case red.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** `DevToolPort` gains `NamespaceDiff`: the target is checked (shape, not this namespace, `NamespacePairs` evaluated) before any body, each namespace is counted against the cap and runs `EnvSync.DocHashes` with its own pairs, and `DiffRows` answers the drift rows. A read-only System Explorer screen, Compare namespaces (position 16), is drawn by the extended `dev-tool.page.ts` with a target select, and `explorer.namespacediff.read` shares its bounded read. DT-11 moves to P4 and into the exclusion register; the catalog, extract and `epics.md` stage table are re-derived; DT-09 and DT-10 are reworded.

**Files.** `src/OcuPilot/Port/DevToolPort.cls`, `Screen/Descriptor/ExplorerNamespaceDiff.cls`, `Screen/Titles.cls`; tests `NamespaceDiffRead`, `DevToolProbe`, `DevToolRead`, `DevToolHarvestRecorder` and the roster pins; client `dev-tool.page.ts`, `dev-tool.store.ts`, `screen-outlet.ts`, `strings.ts`, `screens.generated.ts`, their specs and `ui/browser/namespace-diff.browser-spec.mjs`; `docs/exclusion-register.md`, `feature-catalog.md`, `extract-stages.md`, `extract-catalog.md`, `epics.md`, EXPERIENCE.md.

**Review.** 14 findings, none high: 3 medium and 3 low patched (test-only), 2 low rejected, 1 low deferred (`epics.md:957`, Epic 21's block), 5 descriptive. Triage Log has each row.

**Verification.** Reload `LOADERRORS=0`; `NamespaceDiffRead` 12 of 12 and the 14 roster classes green; `npm run build`, `test:components` (3,487) and `test:tools` (2,292) green; `namespace-diff.browser-spec.mjs` 3 of 3 on the redeployed bundle; `check-objectscript`, its harness, `lint-docs` and the `%Net` grep clean; the `(once)` sweep, shards 1 to 17 of 17, each green, after the last patch. Mutations are listed under Verification.

**Follow-up review.** Recommended: three medium test patches. The unverified risk is the one-second `Hang` in `MakePair`, which assumes the class timestamp has second resolution; the mutation that compares time with hash reddened four tests, so it holds on this build.

**Residual risk.** Contended planning files (`feature-catalog.md`, `extract-stages.md`, `epics.md`) may need a union at integrate-forward with Epic 21's Story 21.12. The recorder now also records each call's `pairs`.
