---
title: 'Story 21.18: Global find and replace'
type: 'feature'
created: '2026-11-15'
status: 'in-progress'
baseline_revision: 'c9242b05416767b469166c6df368d843ab4f92ed'
review_loop_iteration: 0
followup_review_recommended: true
context: ['{project-root}/_bmad-output/implementation-artifacts/spec-21-5-globals-and-the-data-tools.md']
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The classic Globals page's Replace (`UtilExpFindReplace.csp`) finds text in a global's values and replaces it, after "Are you sure you want to save changes PERMANENTLY?". Story 21.5's globals surface has no find and no replace.

**Approach:** One write, `explorer.globals.replace`, reached by two callers (AD-53). A person uses it from Story 21.5's Global nodes page: a Find field filters the page's rows (screen-only), and Replace is reviewed through the dry-run route, then typed-name confirmed. The agent proposes it by the global's name with its own find and replace text. Its card states only counts, never a value or subscript (AD-36). `GlobalPort` builds the write from the declared `Find`, `Replace` and `MatchCase` (the owner-allowed AD-51 entry in Design Notes). The write is bounded and refuses when the global moved after the review.

## Boundaries & Constraints

**Always:**

- Build on Story 21.5's declared design: `GlobalPort`, `GlobalError`, the `global` entity type, `ExplorerGlobalList`, the Global nodes page, `ParseReference`, and the `Global` arm of `Prohibited`. Implement after 21.5 is `done`. Every edit to its files is add-only.
- Only node **values** are searched; subscripts never are. A node is a candidate only when `%Studio.Global.format` answers 1 (plain text). It changes when its replaced value differs from its value. Every occurrence in it is replaced, left to right and without overlap. With `MatchCase` false, matching compares `$ZConvert(,"L")` of both texts, which keeps every character's position (measured), and replaces the original characters.
- `Find` is 1 to 1,000 characters and `Replace` 0 to 1,000, with no control character in either; anything else is 400 `GLOBAL.VALUE.SHAPE` (21.5's sentence). `MatchCase` is boolean and defaults to true. The texts are compared with `$Find`. They never reach `@`, `Xecute`, `$XECUTE`, SQL or a pattern match.
- Bounded (AD-36). A walk visits at most 20,000 nodes in `$Query` order. A replace over a larger global, or one whose replaced value would exceed 32,767 characters, is 409 `GLOBAL.REPLACE.TOOLARGE`, and nothing is changed. Never a partial replace.
- The fresh read (`REPLACE`, port-composed, `READSVALUES`) answers `{Name, Find, Replace, MatchCase, Nodes, Occurrences, Locations, Digest, Reviewed}`:
  - `Locations` is the distinct directories of the nodes that change, each from `GetGlobalDest`. When the global has a single mapping row, that row's directory is used.
  - `Digest` is a SHA-256 over the changing nodes' references and values in walk order.
  - It holds no value and no subscript. `Nodes` 0 is 409 `GLOBAL.REPLACE.NOCHANGE`, which is named in `PRECONDITIONCODES`.
- The write runs inside the AD-34 hold:
  - Re-walk and record each changing `(reference, old, new)` in a process-private global, and compute the digest.
  - A digest other than the reviewed one (the person's `Reviewed`, else the stored `Digest`) is 409 `GLOBAL.REPLACE.REVIEWCHANGED`, and nothing is written.
  - Then, in one `TSTART`/`TCOMMIT`, set each node only while it still holds its recorded old value. Otherwise `TROLLBACK` and answer `REVIEWCHANGED`.
  - No event, job or I/O inside the transaction.
- The `%SYS` namespace is refused 409 `GLOBAL.REPLACE.SYSNAMESPACE`, as the classic page offers no Replace there (`FindPane.cls:178`).
- Self-protection uses 21.5's `Global` arm, read at the write over the `REPLACE` read:
  - (1) The name stem.
  - (2) Any `Locations` entry that is OcuPilot's database or one of `SYSTEMDATABASES` refuses `PROHIBITED.PROTECTEDGLOBAL`. This is the arm's per-node value-edit clause, applied to every node the replace would change.
  - (3) A `CODEGLOBALS` member with a `Locations` entry in the install namespace's routines database refuses `PROHIBITED.OCUPILOTCODE`, as a whole-global write.
  - The arm applies whichever caller makes the write, key on or off. A read that fails refuses.
- Node values and subscripts never reach the card, the tool result, screen context, the model, a log line, the ledger or an audit payload. The card's rows are `Find`, `Replace`, `MatchCase`, `Nodes` and `Occurrences`.
- Destructive (typed-name confirm with the global's name), and its key ships `false`. A person's write asks for no key (AD-53). The write emits one change event (AD-14). The read-back is the action-style verdict (AD-58).

**Never:**

- No per-node selection. A replace changes every matching value or none.
- No search of subscripts, no regular expression, no pattern match, and no replace in a `$List` or a value with a control character.
- No new route, read tool, screen or entity type.
- No edit to 21.17's export or import.
- No user-facing string beyond those the spec gate rules.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Find | person types `abc` in the Global nodes page's Find | only nodes whose plain-text value holds `abc` (per Match case), paged by cursor; a page that scanned 20,000 nodes without filling answers what it found and `next` | none |
| Review | person: Find `abc`, Replace `xyz`, Review on `^ZZOcuRep<pid>` | dry-run answers rows `Nodes` 3, `Occurrences` 5 and `Digest`; dialog shows them over the typed-name field | none |
| Person replace | confirm with typed `ZZOcuRep<pid>` and `Reviewed` | the three nodes hold `xyz`, the `$List` node and the others are unchanged, the page re-reads | none |
| Agent replace | `explorer.globals.replace {Name, Find, Replace, MatchCase}`, key `true`, then confirm | tool result and card carry only the five rows; values replaced after confirm | key `false`: governance refusal |
| Case | `MatchCase` false, Find `ABC`, value `xAbCy` | `x<Replace>y` | none |
| Nothing | no plain-text value changes | nothing minted or sent | 409 `GLOBAL.REPLACE.NOCHANGE` |
| Moved | a matching node changes after review or mint | nothing written | person 409 `GLOBAL.REPLACE.REVIEWCHANGED`; agent target-changed |
| Too large | 20,001 nodes, or a replaced value over 32,767 characters | nothing written | 409 `GLOBAL.REPLACE.TOOLARGE` |
| Bad text | empty Find, a control character, or over 1,000 characters | nothing read | 400 `GLOBAL.VALUE.SHAPE` (screen) / `TOOL.ARGUMENTS` (agent schema) |
| `%SYS` | any replace in `%SYS` | Replace drawn disabled with the sentence | 409 `GLOBAL.REPLACE.SYSNAMESPACE` |
| Protected | `^OcuPilot*`; a changing node in OcuPilot's database or a system database; a code global in the install namespace's routines database | refused before any write, both callers | 403 `PROHIBITED.PROTECTEDGLOBAL` / `PROHIBITED.OCUPILOTCODE` |
| No privilege | no WRITE on the database | nothing written | 403 `PORT.ACCESSDENIED` |

</intent-contract>

## Code Map

- **Classic (read-only):**
  - `irissys/%CSP/UI/System/FindPane.cls` offers Find and Replace (Replace needs `%Development:USE` and a namespace other than `%SYS`, :176-178) and posts to `/csp/sys/exp/UtilExpFindReplace.csp`.
  - That page is object code only on the instance (`^rOBJ("%cspapp.exp.utilexpfindreplace.1")`, no class or source, measured). Its served script, read logged in on slot A, has fields `FindWhat`, `Replace` and `MatchCase`; each hit toggles separately; Replace all and Undo; and a save confirmed "Are you sure you want to save changes PERMANENTLY?". The rest of its action set is inferred.
- **21.5's design to extend** (`spec-21-5-globals-and-the-data-tools.md`, not yet built):
  - `Port/GlobalPort.cls`: `Globals` (with `Locations`), `Page`, `ParseReference`, the name pattern, and the `<PROTECT>` → 403 mapping.
  - `Api/GlobalError.cls`.
  - `Area/Explorer/GlobalNodes.cls`.
  - `Screen/Descriptor/ExplorerGlobalList.cls` (`toolIdentifier` `explorer.globals`, self-protection rule).
  - `Screen/Tool/ExplorerGlobalDelete.cls`: same target, port and descriptor; the model for `PrivilegePairs` and `IdArgument`.
  - `Kernel/Proposal/Prohibited.cls`: the `Global` arm, `OwnDatabaseDirectories`, `SYSTEMDATABASES` :440, `CODEGLOBALS` :933.
  - `ui/src/app/areas/system-explorer/global-view.page.ts` / `.store.ts`.
- **Reviewed-action sibling:** `src/OcuPilot/Screen/Tool/InteropItemChangeClass.cls`. It sets `DRYRUN` 1, `SCREENVALUES` `changeclass=NewClass:Reviewed`, a `Digest` in `FINGERPRINTSUBJECT`, and the port's `REVIEWCHANGED` refusal (`Port/InteropPort.cls` `ComposeChange` :1857, `ChangeStep` :1913). It answers `DryRunReview`. `src/OcuPilot/Api/ScreenDryRun.cls` is the route.
- **Advertised action with a values-composed read:** `src/OcuPilot/Screen/Tool/ExplorerSqlRun.cls` (`READSVALUES`, `SENDSBODY` 0, `DESTRUCTIVE`, key `false`, `InputSchema` with `rationale`/`expectedImpact`/`reverse`).
- **Kernel hooks:** `Screen/Tool/Write.cls`:
  - `StateDiff` :551, which gives the card's rows;
  - `PortQuery` :485;
  - `PRECONDITIONCODES` :528;
  - `DryRunReview` :405;
  - `View` :947, which returns the mint result to the model, so the card's rows reach the model.

  `Kernel/Proposal/ReadBack.cls` gives an action-style write the verdict "sent no value".
- **Client:** `ui/src/app/shell/screen-action-handler.ts`:
  - `DRY_RUN_ACTIONS` :416;
  - `UNDRAWN_ACTIONS` :459;
  - `startDryRun` :1605;
  - `reviewLinesOf` :1965;
  - the consequence map near :676.

  Also `core/proposal-view.ts`, `core/strings.ts` and `core/screens.generated.ts`.
- **Baseline:** `src/OcuPilot/Kernel/Governance/Baseline.cls` explorer keys :204-219.

## Tasks & Acceptance

**Task 0, on `ocupilot-ci` (implement stage, before code; restore every probe; record results under Design Notes):**

- (a) A forced error after the first `Set` inside `TSTART`, on `^ZZOcuRep<pid>` in `USER`: does `TROLLBACK` restore every node? (inference)
- (b) Time a 20,000-node `REPLACE` read and write. Read-only, the walk was measured at 0.42 s over 20,000 nodes with `format` and a lowercase `$Find`, and `GetGlobalDest` at 0.22 ms a call.
- (c) With auditing on, does a global `Set` from the screen's process record any vendor event? The candidate event, `%System/%SMPExplorer/Change`, ships disabled (measured).

**Batch 1, server (commit when its loop commands are green):**

- `src/OcuPilot/Port/GlobalPort.cls` (add-only):
  - `Replace` endpoint, `REPLACE` read type and write type.
  - The shared match helper (`Matches`/`Replaced`), used by both `Replace` and `Page`.
  - `Page` gains the optional `find` and `matchCase`, with the scan bound per page.
  - The rules under Always; the `%SYS` refusal.
  - `REPLACESCAN` = 20000 and `REPLACEVALUEMAX` = 32767 as parameters.
- `src/OcuPilot/Api/GlobalError.cls` (add-only) -- `GLOBAL.REPLACE.NOCHANGE`, `.TOOLARGE`, `.REVIEWCHANGED`, `.SYSNAMESPACE`, consequence `GLOBAL.REPLACE`, the ruled sentences.
- `src/OcuPilot/Area/Explorer/GlobalNodes.cls` -- accept `find` and `matchCase` in the page request, shape-checked as `Find`. Nothing logged.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` (add-only) -- the `Global` arm's branch for `explorer.globals.replace`, reading the fresh `REPLACE` read's `Locations` (Always, self-protection).
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- DW-2731: `ImportedGlobals`'s `Catch` sets its status from the exception, so an error raised while judging an import's globals refuses the import instead of reading as permitted; a test forces the error and asserts the refusal (report the rewritten clause to the runner).
- `src/OcuPilot/Screen/Tool/ExplorerGlobalReplace.cls` (new):
  - `explorer.globals.replace`, advertised, `PORTCLASS` `GlobalPort`, `DESCRIPTORCLASS` `ExplorerGlobalList`.
  - `READTYPE`/`WRITETYPE` `REPLACE`, `READSVALUES` 1, `SENDSBODY` 0, `DESTRUCTIVE` 1, `DRYRUN` 1.
  - `SCREENACTIONS` `replace`, `SCREENVALUES` `replace=Find:Replace:MatchCase:Reviewed`.
  - `FINGERPRINTSUBJECT` `Name,Find,Replace,MatchCase,Nodes,Occurrences,Locations,Digest,Reviewed`, `PRECONDITIONFIELD` `Nodes`, `PRECONDITIONCODES` `GLOBAL.REPLACE.NOCHANGE`.
  - `CLASSICPAGES` `%cspapp.exp.utilexpfindreplace`.
  - `StateDiff` answers the five card rows, and `DryRunReview` answers `{Digest}`.
  - `InputSchema` takes `Name`, `Find`, `Replace` and `MatchCase`, with the model told that only plain-text values are searched and that the card states counts only.
- `src/OcuPilot/Screen/Descriptor/ExplorerGlobalList.cls` (add-only) -- declare the `replace` action and the tool.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` (add-only) -- `"explorer.globals.replace": false`.
- `src/OcuPilot/Test/GlobalReplace.cls` (new). Each test makes and kills its own `^ZZOcuRep<pid>` in `OnAfterOneTest`.
  - Both callers' round trip (with `$List`, control-character and non-matching nodes unchanged), match case, `NOCHANGE`, `TOOLARGE` (20,001 nodes), and `REVIEWCHANGED` for both callers.
  - The tool result and card JSON hold neither the test's marker value text nor a subscript.
  - `SYSNAMESPACE`, key off, and the shape refusals.
  - The self-protection rows follow 21.5's `GlobalWrite`: refused before any write and never by writing a protected global. The location and code-global rows are pinned at the arm with a composed `REPLACE` read, as `ExplorerTransfer.TestTheCodeArmReadsEveryNameAnImportReviewed` does.
- `src/OcuPilot/Test/GlobalRead.cls` (21.5's) -- the Find filter: the matching rows only, the cursor continuing across a page that scanned out.
- Every shared-surface test under Verification, updated to the new shape.

**Batch 2, client (commit when its loop commands are green):**

- `ui/src/app/areas/system-explorer/global-view.page.ts`, `global-view.store.ts`, specs:
  - Find field and Match case filter the rows through the page request.
  - Replace field and Review call `startDryRun` with the `ExplorerGlobalList` descriptor, `replace`, the global's name, `{Find, Replace, MatchCase}`, and the name to type.
  - Replace is drawn disabled with the sentence in `%SYS` or for a global the list's self-protection rule marks.
  - The page re-reads on the change event.
- `ui/src/app/shell/screen-action-handler.ts` (add-only) -- the list's `replace` goes in `DRY_RUN_ACTIONS` and `UNDRAWN_ACTIONS`, plus its consequence. Also `core/proposal-view.ts` (`GLOBAL.REPLACE`), `core/strings.ts`, and `core/screens.generated.ts` (regenerated).
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- the ruled strings into Fixed strings (add-only).
- `ui/browser/system-explorer-globals.browser-spec.mjs` (21.5's, add-only test). It waits for the answered signal at each step:
  - Find filters the spec's own global.
  - Review shows the counts.
  - The typed-name confirm replaces.
  - The nodes page shows the new values.

**Acceptance Criteria:**

- AC1. Given the test's own global with plain-text, `$List` and non-matching nodes, when the person filters by Find, reviews a replace, types the global's name and confirms, then the review states the node and occurrence counts, and each matching plain-text value holds the replaced text. No other node changes.
- AC2. Given the key `true`, when the agent proposes `explorer.globals.replace` and a person confirms, then the values are replaced. The tool result and card carry only `Find`, `Replace`, `MatchCase`, `Nodes` and `Occurrences`, never a node value or subscript. Under the default baseline, the proposal is refused by governance.
- AC3. Given a reviewed or minted replace, when a matching node changes before confirm, then nothing is written, with `GLOBAL.REPLACE.REVIEWCHANGED` for the person and target-changed for the agent.
- AC4. Given a global over 20,000 nodes, a replace that changes nothing, or the `%SYS` namespace, when either caller replaces, then it is refused with `TOOLARGE`, `NOCHANGE` or `SYSNAMESPACE` and nothing is written.
- AC5. Given any global the `Global` arm protects, when either caller replaces in it, then it is refused before any write with that refusal's sentence, which the client mirror pins equal.

### Review Findings

- [ ] [Review][HIGH] CI run 44397952934 (code head 786f463f5), instance shard 5/8: `DraftRegistry.TestEveryWriteToolHasAScriptForm` and `TestNoSecretReachesAnyRenderedScript` fail on `explorer.globals.replace` ("Globals/REPLACEALL has no script form in OcuPilot.Port.GlobalPort"). AD-59 binds every write tool: the port that defines `Invoke` defines a `Snippet` that mirrors every branch `Invoke` takes, so "the write has no script form" (Design Notes, Verification) contradicts the spine. Add the `REPLACEALL` branch to `GlobalPort.SnippetForm` and `Snippet`, rendering the same replace `Invoke` performs (namespace, global, find, replace, match case; plain-text values only; one transaction) with every value a string literal reached by indirection, as the existing branches do; replace the two wrong sentences; `DraftRegistry` green; a `mutation:` line. [src/OcuPilot/Port/GlobalPort.cls]

Code review, 2026-11-18 (4 layers, full-opus): 38 rows, 29 entries (high 0, medium 6, low 20, false 3). Every medium was patched in this pass, and no high or medium remains open.

- [x] [Review][Patch] The name-stem test wrote `^OcuPilotZZRep<pid>`, which the install namespace maps into OcuPilot's own database. It now uses a lower-case stem, stored in `HSCUSTOM` [src/OcuPilot/Test/GlobalReplace.cls]
- [x] [Review][Patch] The location refusal was pinned only at the arm with a test payload. `TestAGlobalStoredInASystemDatabaseIsNotReplacedOnEitherCaller` drives the person's and the agent's write on the test's own `%`-global, which is stored in the system database, and asserts 403 with nothing changed [src/OcuPilot/Test/GlobalReplace.cls]
- [x] [Review][Patch] No `%Development` principal replaced anything. `TestADeveloperReplacesInItsOwnGlobalAndIsRefusedAProtectedOne` covers the developer's own global (200) and its `%` copy (403) [src/OcuPilot/Test/GlobalWriteDeveloper.cls]
- [x] [Review][Patch] Two paths were unpinned: the port's stale answer through `Invoke`, and the `Catch` rollback. They are now pinned through the new `GlobalReplaceMoveSeam` and a forced error leg [src/OcuPilot/Test/GlobalReplace.cls, src/OcuPilot/Test/GlobalReplaceMoveSeam.cls]
- [x] [Review][Patch] The agent's mint was never driven over a global that changes nothing or one that is too large. Both legs are added [src/OcuPilot/Test/GlobalReplace.cls]
- [x] [Review][Patch] `ExplorerGlobalReplaceMint` copied `InteropTransformMint`'s body byte for byte (Rule 31). It now extends it [src/OcuPilot/Screen/Tool/ExplorerGlobalReplaceMint.cls]
- [x] [Review][Patch] A filtered page that scanned out with more nodes to read said that no node holds the text. The empty state now waits until no page is left [ui/src/app/areas/system-explorer/global-view.page.ts]
- [x] [Review][Patch] The 32,767-character boundary leg is added, and the stale roster messages are reworded [src/OcuPilot/Test/GlobalReplace.cls, DeveloperFloor.cls, ExplorerDescriptor.cls]
- [x] [Review][Defer] DW-2747 (`wontfix-theoretical`): when the arm's own read is refused with a 4xx, the arm leaves that refusal to the write
- [x] [Review][Defer] DW-2748 (`wontfix-accepted`): the replace takes no lock against a concurrent writer
- [x] [Review][Defer] DW-2749 (`wontfix-accepted`): the No privilege row has no test

**Rejected:**

- **false:**
  - Rollback is partial in a database that is not journaled. IRIS journals every update inside a transaction whatever the database's journal setting; `IRISTEMP` is the exception, and it is not rolled back (measured), but it is a protected database that the arm refuses.
  - `Replacing`'s `Catch` leaves a transaction open. `VendorReplaceApply` rolls back to its entry level inside its own `Try`.
  - `ReplaceLocations` hard-codes the namespace key. The sibling `GlobalLocations` uses the same literal.
- **low, by design or bound by the spec:**
  - `Reviewed` is optional, as in `InteropItemChangeClass` and `ExplorerNamespacePromote`.
  - The digest excludes the texts; the spec defines it over the references and values.
  - The counts act as a substring oracle (veto U-63, count-only card).
  - Three walks per replace (Decided in-stage).
  - The write has no script form (Decided in-stage).
  - Raw `MatchCase` row labels (the spec names the card rows).
- **low, not worth fixing:**
  - No "whole global" wording (it would need a new string).
  - A value shrunk from near the 3.6-million-character string limit raises `<MAXSTRING>` (theoretical).
  - Edits that move code into `StreamDigest`/`RawRow`/an `Else` branch are not add-only (no behavior change).
  - An empty Find answers `TOOL.ARGUMENTS`, which the UI cannot send.
  - The AD-51 entry names only `REPLACE` (a spine wording point for the runner).
  - One page-spec leg repeats a check the store already makes (the guard is pinned elsewhere).
  - The agent's port digest check is not pinned apart from the kernel's `PROPOSAL.TARGETCHANGED`. `Digest` is in `FINGERPRINTSUBJECT`, which the existing mutation pins; the port's comparison is one line shared with the person's pinned leg; and the agent's 200 requires the minted digest to reach the write.
  - Leaks beyond the four answers. Measured on `ocupilot-ci`: no node value or subscript in any `^OcuPilot*` global, `%SYS.Audit` or `messages.log` after replaces by both callers.

## Spec Change Log

- 2026-11-18, runner (ledger inbox): DW-2732 -- the Protected row answers 403, as every protected-global and OcuPilot-code refusal does since Story 21.5. DW-2731 -- a Batch 1 task fixes `Prohibited.ImportedGlobals`'s status-less `Catch`. Stories 21.5 and 21.17 are built: extend `GlobalPort`, the `Global` arm and the transfer tests rather than copying them.

## Review Triage Log

### 2026-11-18 -- Review pass

- verdicts: 13 findings -- high 0, medium 3, low 6, false 4, maybe-false 0
- findings:
  - `[medium]` `[patch]` Agent's moved-global leg asserted only "not 200", so any refusal passed -- now asserts `409 PROPOSAL.TARGETCHANGED` and adds a second leg that moves a value without changing either count (`GlobalReplace`).
  - `[medium]` `[patch]` The port's `Locations` answer was never asserted -- `GlobalReplace` now asserts the port's fresh read and the per-node scan both name the global's directory.
  - `[medium]` `[patch]` Protected replace was pinned only at the arm -- `TestAnOcuPilotNamedGlobalIsNotReplacedOnEitherCaller` drives the person's replace and the agent's mint or confirm for an OcuPilot-named global (403, nothing changed). The person's review answers 200 by design: it writes nothing and the refusal is at the write.
  - `[low]` `[patch]` Wide characters untested -- `TestWideCharactersAreKeptInPlace` added.
  - `[low]` `[patch]` Handler spec waited a fixed 12 ms -- now `vi.waitFor`.
  - `[low]` `[patch]` `ClassicPageGate.EXPLORERIMPORTKEYS` comment did not name the replace key -- reworded.
  - `[low]` `[patch]` `Locations`/`Digest` reaching the model was unverified -- the agent test now asserts the mint result holds neither (verified; the harm did not occur).
  - `[low]` `[reject]` AC2 governance assertion reads `allowed` 0 for any refusal -- `ToolDispatch`'s derived loop pins the default-disabled key; a corrective line would add a branch for no user-reachable harm.
  - `[low]` `[reject]` Two string keys have no consumer beyond the dialog rows -- harmless, and the strings are the spec's ruled ones.
  - `[false]` `[reject]` NOCHANGE/TOOLARGE before REVIEWCHANGED on a moved global -- nothing is written either way and the global genuinely no longer matches the review.
  - `[false]` `[reject]` Find filter "server-side, not screen-only" -- the Tasks list names `GlobalNodes` accepting `find` and `matchCase`; no new route exists.
  - `[false]` `[reject]` Agent card UI evidence thin -- the card is the generic proposal view of the five rows, pinned by `StateDiff` and the server test.
  - `[false]` `[reject]` Person's replace has no screen of its own -- by design (Decided in-stage): the page starts the list descriptor's `replace`.

## Design Notes

**Governing ADs:** AD-5, AD-6, AD-8, AD-10, AD-13, AD-14, AD-15, AD-16, AD-21, AD-22, AD-29, AD-34, AD-36, AD-39, AD-44, AD-51, AD-52, AD-53, AD-56, AD-58. No AD-39 exception is needed: the write's answer is the read-back verdict, with no `WriteOutput`.

**AD-51 named entry, final (owner U-59; the runner pastes it at the spec gate, after Story 21.16's case):**

"Story 21.18's case: `GlobalPort`, which builds a global's find and replace from the replace tool's declared `Find`, `Replace` and `MatchCase`, never as code. It walks the global's nodes in `$Query` order, at most 20,000, and changes only a plain-text value that holds `Find`, each such value once with every occurrence replaced, in one transaction, and only while the value still holds what the walk read. It answers the fresh read through a port-composed `REPLACE` type, composed from those values, holding the counts of the nodes and occurrences that change, the directories those nodes resolve to, and a digest of their references and values, and no value or subscript. The digest is the fingerprint's and a person's `Reviewed`, so a global that moved after the review refuses the write. The agent proposes it by the global's name, beside Story 21.5's whole-global delete; its card states only those counts (AD-36). A person's replace records no vendor event with the stock event set (`%System/%SMPExplorer/Change` ships disabled, measured), AD-53's named gap as for Story 21.5's node writes. [AMENDED 2026-11-15, Story 21.18, owner answer U-59]"

**The agent caller (prompt's choice):** the agent proposes it, and the card states only counts. This needs no AD wording beyond the owner-allowed entry above. The person-only option would need a further AD-53 record. For the gate: AD-53's Story 21.5 record ends "The agent proposes only a whole global's delete, by name." That record is scoped "(Story 21.5)". The entry above names this story's agent write beside it, so no AD-53 edit is proposed. The last sentence of the entry carries the audit gap. If the gate prefers it in AD-53's named-gap list, it can move it there unchanged.

**For the spec gate (veto, data posture):** the card's `Nodes` and `Occurrences` reach the model, through `Write.View`'s result. They are counts derived from values the agent's own `Find` selects, and they are what the AC asks the card to state. No value, excerpt or subscript reaches the model. The digest and `Locations` stay in the stored proposal.

**Measured read-only on slot A `ocupilot` (2026-11-15):**

- `$ZConvert(,"L")` and `$ZConvert(,"U")` keep length 1 for U+0130, U+1E9E, U+03A3, U+2126 and U+FB00.
- `%Studio.Global.format` answers 1 for a 40,000-character plain string.
- A 20,000-node `^oddDEF` walk (HSCUSTOM) with `format` and a lowercase `$Find` took 0.42 s.
- 1,000 `GetGlobalDest` calls took 0.22 s.
- `Security.Events` lists no global event other than `%System/%SMPExplorer/*`, all disabled.
- The classic page facts are in the Code Map.

**Decided in-stage:**

- The person's surface is the Global nodes page, not a list row action: Find filters the rows that page already shows, and Replace is reviewed there. The list declares `replace` undrawn.
- Destructive, with typed name and key `false`. A replace cannot be undone from OcuPilot, because Replace may already occur in the values.
- Match case defaults to true (the narrower replace).
- 20,000 nodes per walk and per filtered page. Three walks per agent replace (mint, confirm re-read and write) are about 1.3 s, and about 5 s when per-node destinations are read (inference from the measurements above).
- `Locations` covers only the nodes that change, read per node only when the global has more than one mapping row, so the arm stays per node. A code global is refused as a whole-global write.
- `%SYS` refused: never looser than the classic page.
- No harvested body: the MCP suite has no global replace handler (21.5 checked `ExecuteMCPv2.REST.Global`).
- Tests are not armed. Each writes only its own `^ZZOcuRep<pid>`.

**Task 0, measured on `ocupilot-ci` (2026-11-18, implement):**

- (a) `TROLLBACK` restores every node: after `Set` of nodes 1 and 2 inside `TSTART` and a forced divide error, the three nodes read `a`, `b`, `c` and `$TLevel` was 0.
- (b) A raw loop over 20,000 nodes with `format` and a lower-case `$Find` took 0.022 s, and one transaction of 20,000 `Set`s 0.008 s, with short values in `USER`. The port's own read and write were not timed separately; the 20,000-node review in `GlobalReplace` runs inside one test. The per-node `GetGlobalDest` cost (4.4 s over 20,000 nodes at 0.22 ms) stays an (inference) from the 2026-11-15 measurement.
- (c) With auditing enabled (it already was), two `Set`s and a `Kill` of a `USER` global from a session recorded no `%SYS.Audit` row (229,349 before and after). No vendor event is written, the AD-53 named gap as for Story 21.5's node writes. Auditing was left as found.

**Decided in-stage (implement):**

- The read and the write are two request types on the existing `Globals` endpoint, `REPLACE` and `REPLACEALL`, not one type on a new `Replace` endpoint: the kernel reads with `READTYPE` and writes with `WRITETYPE` through one port, so one type could not tell the two apart.
- A global that holds no data is 404 `GLOBAL.NOTFOUND` (the delete's sentence), before `NOCHANGE` is judged. The read answers `Namespace` and the fingerprint subject names it, so a confirm writes where the proposal read, as the other globals tools do.
- The write refuses when no digest reaches it, `REVIEWCHANGED`: both callers always send one (the person's `Reviewed`, else the stored `Digest`).
- `Locations` is read per node only when the global's name and mapping rows answer more than one directory; with one, that directory is the answer.
- The arm reads the `REPLACE` read through the tool's own `PortQuery`; a read the port refuses with a 4xx (`NOCHANGE`, `TOOLARGE`, `SYSNAMESPACE`, a shape refusal) is not judged by the arm, because the write is refused the same way before it changes anything. A read that fails any other way refuses.
- An unsound find or replacement from the agent is refused `TOOL.ARGUMENTS` before the instance is read, by `ExplorerGlobalReplaceMint` (a new class, modeled on `InteropItemChangeClassMint`), with `GLOBAL.VALUE.SHAPE`'s existing sentence as the problem text.
- The review's five rows carry no before-text, so the handler draws a row that is not removed and has no before-text as `field: value` (`fieldReviewLines`); the review dialog's verb is the ruled "Find and replace".
- The `%SYS` sentence's key is `globalRefusalReplaceSystem`: `strings.test.mjs` pins every key containing `namespace`.
- `GlobalPort.SnippetForm` answers no script form for `REPLACEALL`, as for a read: the replace has no vendor script.
- DW-2731: no clause was rewritten. `Prohibited.ImportedGlobals`'s `Catch` already reads `Set tSC = ex.AsStatus()` (Story 21.5's original commit), so an error raised in it is an error status the caller refuses on. `GlobalWrite.TestAnErrorRaisedWhileJudgingAnImportRefusesIt` pins it (`GlobalProhibited.BreakPort` makes the arm's port a class with no methods); the evidence's "keeps tSC OK" read the file before that line.
- DW-2732: the Protected row answers 403, pinned at the arm in `GlobalReplace` and `GlobalWrite`. No instance global stored in a protected database with at most 20,000 nodes was found to drive end to end (`^oddDEF` in `USER` holds more than 25,000), so both callers' refusal is pinned at the shared arm, not by a real write.

**Strings, escalated for the spec gate's ruling** (reusing "Review", "Match case", `GLOBAL.VALUE.SHAPE`, `PROHIBITED.PROTECTEDGLOBAL`):

- Labels: "Find", "Replace with", "Find and replace".
- Card and review rows: "Nodes", "Occurrences".
- Filter empty state: "No node in this global holds that text."
- Consequence `GLOBAL.REPLACE`: "Replacing changes every value the review counts. This cannot be undone."
- Refusal `GLOBAL.REPLACE.NOCHANGE`: "No plain-text value in this global holds that text, so nothing would change."
- Refusal `GLOBAL.REPLACE.TOOLARGE`: "This global is too large to replace in here: it holds more than 20,000 nodes, or a replaced value would be longer than 32,767 characters."
- Refusal `GLOBAL.REPLACE.REVIEWCHANGED`: "This global changed after the replace was reviewed, so nothing was replaced. Review the replace again."
- Refusal `GLOBAL.REPLACE.SYSNAMESPACE`: "Find and replace is not available in the %SYS namespace."

**Extend, don't copy (Rules 2/31):**

- The tool follows `InteropItemChangeClass` (reviewed digest) and `ExplorerSqlRun` (values-composed read, advertised with key `false`), and extends `Write` directly, as 21.5's tools do.
- `Page`'s filter and `Replace` share one match helper.
- The arm extends 21.5's `Global` arm.
- The client reuses `startDryRun` and the typed-name dialog.

**Integration ACs:** the `REPLACE` types are consumed in this story by the tool's two callers, the dry-run route and `Prohibited`. AC1 to AC5 observe them through HTTP, the agent and the browser.

- **Consumes:** Story 21.5's `GlobalPort`, `GlobalError`, `ExplorerGlobalList`, the Global nodes page and the `Global` arm; `Screen/Tool/Write`; `Api/ScreenDryRun`.
- **Consumed-by:** none known.

**Ledger inbox:** none.

**Contended paths (checked 2026-11-15):** `origin/OCU-1-epic24` has no commit beyond feature on `Prohibited.cls`, `Baseline.cls`, `screen-action-handler.ts`, `proposal-view.ts`, `strings.ts`, `screens.generated.ts` or `EXPERIENCE.md`, and its worktree has no uncommitted change to them. There is no Epic 22 branch or worktree. Edits there stay add-only. No code dependency on 21.17: both add to `GlobalPort` and `GlobalError` only.

**Split:** not needed. The story is 1 tool, no route, and about 16 files across two batches.

**Runner ruling at the spec gate (2026-11-15):** the AD-51 entry is written into the spine without its last sentence (owner answer U-59); the audit-gap sentence is an AD-53 named gap, ledgered as DW-2613 for the owner. The count-only card, the strings and the scoped reading of 21.5's AD-53 record are kept (veto U-63). Implement after Story 21.5.

## Verification

**Shared surfaces:**

- the System Explorer rosters and browser specs (`system-explorer.browser-spec.mjs`, `system-explorer-globals.browser-spec.mjs`);
- `Navigation` (unchanged count, confirmed);
- `Descriptor`, `TeardownGuard`;
- `ReadTool`'s size;
- `ToolWrite`'s counts (+1);
- `Prohibited`;
- `SurfaceCoverage`, `ToolRoundTrip`, `ToolDispatch`, `ToolEmit`;
- `PortGate` (`GlobalPort` types);
- `EndpointCoverage`, `ClassicPageGate`;
- `GovernanceBaseline` (+1 key);
- `ui/tools/strings.test.mjs` with the EXPERIENCE.md literal cap 4200 (if crossed, raise it by 400 under the file's protocol and report it);
- `proposal-view.test.mjs`, `screen-mirror.test.mjs`.

The implement stage greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for each; every test it changes joins `(loop)`.

*Every test added or changed passes on a fresh environment, in either order.*

**Commands** (one per foreground call, `timeout: 600000`, against `ocupilot-ci` only, never two test calls in one message):

- `(loop)` `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` -- expected `LOADERRORS=0`.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.GlobalReplace` -- expected green. Then the same command, one class per call, for:
  - `GlobalRead`, `GlobalWrite`, `Prohibited`;
  - `PortGate`, `SurfaceCoverage`, `EndpointCoverage`, `GovernanceBaseline`;
  - `ReadTool`, `ToolEmit`, `ToolDispatch`, `ToolRoundTrip`, `ToolWrite`;
  - `Descriptor`, `Navigation`, `ClassicPageGate`, `TeardownGuard`.
- `(loop)` `uv run scripts/check-objectscript.py`; `uv run scripts/test_check_objectscript.py`; `bash scripts/lint-docs.sh` -- expected clean.
- `(loop)` `cd ui && node --test tools/strings.test.mjs tools/screen-mirror.test.mjs tools/proposal-view.test.mjs` plus every `ui/tools` test the sweep changes -- expected green.
- `(loop)` The browser check, in order:
  1. `cd ui && npm run build && npm run test:components`
  2. `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`
  3. `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/system-explorer-globals.browser-spec.mjs browser/system-explorer.browser-spec.mjs`

  Expected green.
- `(once)` `cd ui && npm run test:tools` -- expected green.
- `(once)`, runner-owned: the full ObjectScript sweep one class per call, `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`, and Rule 30's fresh check. The full browser suite is left to CI.

**Mutations (Rule 19)** -- apply, observe red, revert byte-identical, reload, record `mutation: <change> -> <test red>`:

- AC1: skip the plain-text check (a `$List` node changes).
- AC2: add one changing reference to `StateDiff`'s rows.
- AC3: drop the per-node old-value check, then drop the digest comparison.
- AC4: raise `REPLACESCAN` past the test's node count.
- AC5: drop the `Locations` check from the arm's replace branch.

Each applied on `ocupilot-ci`, observed red, reverted byte-identical (md5) and reloaded or rebuilt:

- mutation: AC1 skip the plain-text check in `GlobalPort.Candidate` (a `$List` and a tab node change) -> `GlobalReplace.TestAPersonReviewsAndReplaces` and four more red (observed).
- mutation: AC1 (case rule) compare the texts as they are in `GlobalPort.Replaced` -> `GlobalReplace.TestMatchCaseFalseReplacesTheOriginalCharacters` red (observed).
- mutation: AC1 (the filter) keep every node in `GlobalPort.VendorFindWalk`, and continue after the last row kept instead of the last node visited -> `GlobalRead.TestAFindFiltersTheRowsAndTheCursorContinuesAcrossAPageThatScannedOut` red each (observed).
- mutation: AC1 (Find reaches the page request) drop `...filter` from the body in `GlobalViewStore.post` -> `global-view.store.spec.ts` "sends the Find text" and `global-view.page.spec.ts` "Find and Match case filter" red (observed).
- mutation: AC1 (Review) make `GlobalViewPage.onReview` send nothing, rebuild and redeploy -> `system-explorer-globals.browser-spec.mjs` Find-and-replace test red (observed); draw a row with no before-text as `- field:` in `fieldReviewLines` -> `screen-action-handler-globalreplace.spec.ts` review lines red (observed); drop `replace` from `DRY_RUN_ACTIONS` -> four handler specs red (observed).
- mutation: AC2 add a `Digest` row to `ExplorerGlobalReplace.StateDiff` -> `GlobalReplace.TestTheAgentProposesAndAPersonConfirms` red on the rows (observed).
- mutation: AC3 drop the per-node old-value check in `GlobalPort.VendorReplaceApply` -> `GlobalReplace.TestAMovedGlobalIsNotWrittenOnEitherCaller` red on the rollback leg (observed); drop the digest comparison in `GlobalPort.ReplacingRun` -> the same test red on the person's leg (observed); shorten `ExplorerGlobalReplace.FINGERPRINTSUBJECT` to `Name,Find,Replace,MatchCase,Namespace` -> the same test red on the agent's legs, which read `PROPOSAL.TARGETCHANGED` (observed).
- mutation: AC4 raise `GlobalPort.REPLACESCAN` to 25,000 -> `GlobalReplace.TestARefusedReplaceWritesNothing` red on the 20,001-node leg (observed).
- mutation: AC4 (the `%SYS` namespace, client) make `GlobalViewPage.replaceReason` answer `''` -> `global-view.page.spec.ts` "Review is drawn disabled" red (observed).
- mutation: AC4 (text shape) drop the control-character test in `GlobalPort.TextValid` -> `GlobalReplace.TestTextOfTheWrongShapeIsRefusedBeforeAnythingIsRead` red (observed).
- mutation: AC5 set the locations the replace branch of `Prohibited.Global` judges to a directory no database has -> `GlobalReplace.TestTheArmRefusesAProtectedReplaceBeforeAnyWrite` red (observed).
- mutation: AC5 (both callers, name stem) skip the globals arm in `Prohibited.Prohibits` -> `GlobalReplace.TestAnOcuPilotNamedGlobalIsNotReplacedOnEitherCaller` red, as six more tests do (observed, reverted, reloaded).
- mutation: AC1 (wide characters) lower-case only the find text in `GlobalPort.Replaced` -> `GlobalReplace.TestWideCharactersAreKeptInPlace` red, as is the case test (observed, reverted, reloaded).
- mutation: DW-2731 drop `Set tSC = ex.AsStatus()` from the `Catch` of `Prohibited.ImportedGlobals` -> `GlobalWrite.TestAnErrorRaisedWhileJudgingAnImportRefusesIt` red (observed).
- mutation: AC5 (both callers, location) make `Prohibited.ReplaceLocations` answer every read as one the port refused -> `GlobalReplace.TestAGlobalStoredInASystemDatabaseIsNotReplacedOnEitherCaller` red on the person's and the agent's legs (observed, code review).
- mutation: AC5 (developer) `Prohibited.ReplaceLocations` also requires `%Admin_Manage:USE` -> `GlobalWriteDeveloper.TestADeveloperReplacesInItsOwnGlobalAndIsRefusedAProtectedOne` red (observed, code review).
- mutation: AC3 (port) drop `If tStale Quit` from `GlobalPort.ReplacingRun` -> the seam leg of `GlobalReplace.TestAMovedGlobalIsNotWrittenOnEitherCaller` red; drop the rollback loop from `VendorReplaceApply`'s `Catch` -> its error leg red (observed, code review).
- mutation: AC4 (value bound) compare with `'<` in `GlobalPort.VendorReplaceScan` -> the 32,767 leg of `GlobalReplace.TestARefusedReplaceWritesNothing` red (observed, code review).
- mutation: AC1 (filter) drop `!hasMore` from the page's empty state -> `global-view.page.spec.ts` "a filtered page that scanned out" red (observed, code review).
- Each code-review mutation was reverted to byte-identical source (md5) and reloaded. The patched classes are green on `ocupilot-ci`: `GlobalReplace` 11/11 and `GlobalWriteDeveloper` 4/4. The 17 shared-surface and globals classes are also green: `CriterionHints`, `DeveloperFloorRoutes`, `SaveHoldCoverage`, `EndpointCoverage`, `SurfaceCoverage`, `ToolEmit`, `ReadDescriptions`, `Descriptor`, `Navigation`, `ReadTool`, `ToolWrite`, `ClassicPageGate`, `DeveloperFloor`, `ExplorerDescriptor`, `GlobalWrite`, `GlobalRead` and `Prohibited`. `test:tools` passes 2,330/2,330. The globals browser spec passes 7/7 on the rebuilt and redeployed bundle.

## Auto Run Result

Status: done
Blocking condition: none

**Implemented (Batches 1 and 2, one commit).** `explorer.globals.replace` reaches `GlobalPort` through a composed `REPLACE` read and a `REPLACEALL` write: a bounded walk, a digest guard, one transaction with a per-node old-value check, the `%SYS` refusal, and the `Global` arm judging the directories of the nodes that change. The Global nodes page gets Find, Match case, Replace with and Review; the list descriptor, handler, strings, EXPERIENCE.md row, mirror and baseline key (`false`) follow. Task 0 results and in-stage decisions are under Design Notes.

**Files.** Server: `Port/GlobalPort`, `Api/GlobalError`, `Area/Explorer/GlobalNodes`, `Kernel/Proposal/Prohibited`, `Kernel/Governance/Baseline`, `Screen/Descriptor/ExplorerGlobalList`, new `Screen/Tool/ExplorerGlobalReplace` and `ExplorerGlobalReplaceMint`. Tests: new `Test/GlobalReplace` (10) and added cases in `GlobalRead`, `GlobalWrite`, `GlobalProhibited`, `GlobalLocationSeam`, plus roster updates in `ReadTool`, `ToolWrite`, `ClassicPageGate`, `DeveloperFloor`, `ExplorerDescriptor`, `Governance`, `GovernanceBaseline`, `SurfaceCoverage`, `ToolRoundTrip`, `MappingDescriptor`, `Prohibited`. Client: `global-view.page/store` and specs, `screen-action-handler`, `screen-actions`, `proposal-view`, `strings`, regenerated `screens.generated`, `global.test.mjs`, a new handler spec, the browser spec; EXPERIENCE.md (row 613, add-only).

**DW-2731 / DW-2732.** `Prohibited.ImportedGlobals`'s `Catch` already read `Set tSC = ex.AsStatus()`; no clause was rewritten, and `GlobalWrite.TestAnErrorRaisedWhileJudgingAnImportRefusesIt` now pins it. The Protected row answers 403 and is pinned at the arm and by the name-stem test on both callers.

**Review.** 13 findings: 3 medium and 4 low patched (tests only, no production change), 2 low and 4 false rejected; none deferred (Review Triage Log). Patched by counts: medium 3, low 4.

**Verification.** `reload.sh` `LOADERRORS=0`; `GlobalReplace` 10/10, `GlobalWrite` 11/11, `Prohibited` 16/16 green on `ocupilot-ci` after the patches, the other `(loop)` classes green in the handoff pass; `check-objectscript` 0 problems; `lint-docs` clean; `test:tools` 2,328 and the handler spec green; both browser specs green (11); build clean at 2.12 MB initial. Mutations observed red and reverted in this pass: the globals arm skipped, `FINGERPRINTSUBJECT` shortened, `Replaced`'s haystack left in case. The runner owns the full ObjectScript sweep, `smoke.sh` and the fresh check.

**Residual risks.** `followup_review_recommended: true` (three medium patches): the agent's moved-global legs pin the kernel's `PROPOSAL.TARGETCHANGED`, so the port's digest comparison on the agent path is not pinned apart from it. A real protected-database global small enough to replace end to end does not exist on the instance, so the location and code-global refusals are pinned at the arm. Epic 24's worktree has staged edits to `Prohibited.cls`, `ReadTool.cls`, `ToolWrite.cls`, `ClassicPageGate.cls` and EXPERIENCE.md: roster counts on long lines may conflict at integration.
