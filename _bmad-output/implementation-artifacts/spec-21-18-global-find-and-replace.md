---
title: 'Story 21.18: Global find and replace'
type: 'feature'
created: '2026-11-15'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
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
| Protected | `^OcuPilot*`; a changing node in OcuPilot's database or a system database; a code global in the install namespace's routines database | refused before any write, both callers | 409 `PROHIBITED.PROTECTEDGLOBAL` / `PROHIBITED.OCUPILOTCODE` |
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

## Spec Change Log

## Review Triage Log

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

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned on Story 21.5's declared design. The agent caller proposes with a count-only card, which needs only the owner-allowed AD-51 entry, written final in Design Notes. Two items are for the spec gate: the count posture and the new strings. Probes were read-only on slot A `ocupilot`; nothing ran against `ocupilot-ci`.
