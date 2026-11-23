---
title: 'Story 24.16: Purge, suspended messages, export and the archive manager (Batch 3: export messages)'
type: 'feature'
created: '2026-11-23'
status: 'in-review'
baseline_revision: 'b86a75643a232ce3048e163493f6acb30265a901'
review_loop_iteration: 0
followup_review_recommended: false
owned_ledger: ''
context:
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-16-purge-suspended-messages-export-and-the-archive-manager.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-24-16-purge-suspended-messages-export-and-the-archive-manager-2.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot has nothing for the classic Export Messages dialog (`EnsPortal.Dialog.ExportMessages`, opened from the Message Viewer), so a reviewed set of messages cannot be saved as a file, and nothing round-trips over the message bodies it reads. Two Batch 2 follow-ups ride here: no test pins a Suspended messages write in which every message fails, and DW-2849 (Discard confirms through the typed-name dialog).

**Approach:** Batch 3 of four (Batch 1's veto item 1): **Export** on the Messages screen's checked rows, one operation reached by the screen and by the agent (Veto items 1), extending Story 20.31's resend family on `InteropPort`'s `Messages` endpoint. "Round-trips" means: the file a caller receives holds, in ascending id order and in the chosen separator and character set, the bytes the classic export writes for the same messages (Task 0 (a)), and the vendor records one view of each exported body. Follow-up 1 is a test-first task; follow-up 2 is a veto item, not planned (Veto items 6).

## Boundaries & Constraints

**Always:**

- **One port (AD-62).** `InteropPort` gains on `Messages` the read `EXPORT` (the review: one verdict per id) and the write `EXPORTMESSAGES`, plus `EXPORTCHOICES` (the two lists). Switched by save and restore; no `OcuPilot.*` call while switched; a fault is logged after the restore (as Batch 2's review moved `DeleteHeaderHere`'s log line).
- **Selection (AD-21, AD-51).** Ids arrive as `Messages`, checked by `MessageSet` (at most 100, refused beyond, never truncated, ascending, each bound). Each id is judged before any render, first rule wins: `gone`, `nobody` (the resend family's words), `notext` (a body `ContentsText` cannot draw), else `export`. A person's write carries the reviewed digest and is refused when the verdicts moved.
- **What the file holds.** Each `export` member's body rendered by `ContentsText`'s rule (an EDI document, an `%XML.Adaptor` object, a character stream), never cut, written in ascending id order with the classic separators (`CRLF`, `CR`, `LF`, `MLLP`, `Tab`, `None`; MLLP framed as the classic frames it) through `%Stream.FileCharacter` with `TranslateTable` the chosen character set, which must be one `GetIONames^%SYS.NLS(.d,1)` answers at the call (the classic list; `UTF8` preselected). The file is made, read back and removed as Veto items 2 says, and its bytes travel base64-encoded in the answer's `output.file` (AD-12 unchanged: one JSON envelope).
- **Gate (AD-29, AD-8), before any vendor call or render; never cached.** `%Ens_Portal:USE`, `%Ens_MessageHeader:USE` (the Message Viewer's `RESOURCE`, `MessageViewer.cls:15`), `%Ens_MessageExport:USE` (the export dialog's `RESOURCE`, `irislib/EnsPortal/Dialog/ExportMessages.cls:15`), READ on the namespace's globals database, then `Admit`. That is the classic posture read from source; Task 0 (d) measures that no other pair is needed. No database WRITE: an export writes no database.
- **Refusals by name.** No `export` member: 409 `INTEROP.EXPORT.NONE`; a moved review: 409 `INTEROP.EXPORT.CHANGED`; a file over the cap: 409 `INTEROP.EXPORT.TOOLARGE` with the existing sentence "The file is larger than OcuPilot imports or exports."; 101 ids: 400 `PORT.VALIDATION`; a separator or character set not in its list: the action's argument problem (400 `TOOL.ARGUMENTS` from the screen, a refused mint from the agent).
- **A partial outcome follows the resend family's contract (Story 20.31; Batch 2's Decided in-stage (review) 1).** A member that fails at render answers 200 with `Exported` and `Failed` counts and one `Messages` entry `{ID, Error}` per failed id; its outcome line takes the family's existing form `<id>: not <outcome>: <vendor text>` (`InteropMessageAction.FailureLine`) with the word "not exported" (Veto items 4); the file holds the exported members only; the status line counts only those saved, and the failure lines are shown beside it. When every member fails, no file is sent or saved.
- **Writes (AD-3, AD-6, AD-10, AD-14, AD-22, AD-34, AD-51, AD-53, AD-56, AD-58, AD-59).** `interop.messages.export`: action-style, `DRYRUN`, not destructive, key `true`; screen action `export` with values `Separator` and `Charset`; `FINGERPRINTSUBJECT` the verdicts, `Separator`, `Charset`, `Namespace`. A script form (AD-59) that shape-checks every id, the separator and the character set, renders nothing when one fails, and renders the switch, each body's render with the separator, and the view audit, running none of them. A screen action mints nothing and is not gated by read-only or the kill switch.
- **Namespace at confirm (AD-52).** The stored proposal carries `Namespace`; every confirm-time judgment (the verdicts, the lists, the render, the audit) runs there, whichever namespace the confirm is sent from.
- **Audit (AD-15).** The vendor's `%Ensemble/%Message/ViewContents` per exported body through `AuditViewHere`, as Contents records it; the agent's marker on the agent's write; no row of OcuPilot's own (an export changes nothing).
- **Message content stays in the file.** No body text in a log line, an audit row, the proposal row, the ledger, the transcript or the model's context; the confirm's `output` rides on its answer alone (AD-39's fifth exception).
- **Follow-up 1 (test-first).** A Suspended messages resubmit, discard or delete in which every id fails answers as the resend family's contract says (Batch 2 Decided in-stage (review) 1): 200, `Done` 0, `Failed` the count, one `Messages` entry naming each id with the vendor's status, an outcome line per id on the screen and on the card, and for discard and delete OcuPilot's `ConfigChange` row listing every id under `failed`. Code changes only if a test reddens.
- **Rosters.** The tool is classified in `ConfirmNamespaceRoster` and `DraftRegistry` (each run green with it, and red with its row removed), and every other pinned roster it touches is in the Code Map.

**Never:**

- The background saved-search export (`EnsLib.Background.Process.ExportMessageSearch`, Workflow); any `EnsPortal.*` call in product code (tests may call the classic export as an oracle); the `|XDEV|` device; `^IRIS.Temp.ResendIDs` or `EnsPortal.SessionEvents`; a caller-named path or file name on the server (AD-21); a file kept after its request answers.
- Discard's dialog change (DW-2849; Veto items 6); the archive manager (Batch 4); a README or spine edit.
- `src/OcuPilot/Api/Error.cls` (frozen; new codes go in `InteropError.cls`); `ui/angular.json`; `ui/vitest-base.config.mjs`; `scripts/ci-throwaway.sh` beyond add-only `# classes:` lines, never its bring-up retry block; `Prohibited.cls` beyond appended terms; any non-add-only edit to a file Epic 21 changed (Code Map, marked (c)).

## I/O & Edge-Case Matrix

Route namespace USER. Probe messages are stored headers with bodies, marked `OcuProbe2416x`: an HL7 v2 message, an `Ens.StringRequest` (XML adaptor), a `%Stream.GlobalCharacter` body and a `%Stream.GlobalBinary` body. HSCUSTOM holds its own probes. No production is needed.

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Export, person | HL7, XML and stream probes; each separator; `UTF8` and `CP1252` | 200; the saved bytes equal the oracle's for HL7 and XML, the stream's text as Contents shows it; one `ViewContents` row each; no export file or directory left | - |
| Export, agent | The same, confirmed on the card | The confirming browser saves the same bytes; proposal row, ledger and logs hold no body text | - |
| Verdicts | A deleted id, a body gone, the binary body, beside one actionable | Only the actionable is exported; each line names its verdict | - |
| None | Only non-actionable ids | Nothing exported, no file | 409 `INTEROP.EXPORT.NONE` |
| Moved | A body deleted after the person's review | Nothing exported | 409 `INTEROP.EXPORT.CHANGED` |
| Partial | The seam fails one member's render of three | 200, `Exported` 2, `Failed` 1, its outcome line; the file holds two | - |
| All failed | The seam fails every member | 200, `Exported` 0; no file sent | - |
| Too large | Probes whose rendered file passes the cap | Nothing sent; file and directory removed | 409 `INTEROP.EXPORT.TOOLARGE` |
| Fault | The seam throws mid-render | 500; file and directory removed; nothing logged while switched | - |
| Over 100 | 101 ids | Refused whole | 400 `PORT.VALIDATION` |
| Choices | Separator `FF`; character set `Klingon` | Refused; nothing rendered | 400 `TOOL.ARGUMENTS`; mint refused |
| Gate | A principal without `%Ens_MessageExport:USE`; without the database's READ | Refused before any render | 403 naming the pair |
| Confirm elsewhere | Minted in USER, confirmed with `?ns=HSCUSTOM` | USER's bodies exported; HSCUSTOM's not read, no row in its name | - |
| Script | The draft; a bad id, separator or character set | Renders the switch, renders and view audits, runs nothing; a bad value renders no draft | - |
| All failed, Batch 2 | Resubmit, discard, delete of two ids, each failed by `InteropSuspendedSeam.FailActOf` | 200, `Done` 0, `Failed` 2, both ids in `Messages` with the seam's text; both outcome lines; discard and delete rows list both under `failed` | - |

</intent-contract>

## Code Map

Paths under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `b0e597306`). **(c)** marks a file Epic 21 changed beyond feature (`git log --no-merges origin/OCU-1-epic21 ^origin/feature/OCU-1_ocupilot-mvp`, at plan): add-only edits there. Re-check before editing.

- **`Port/InteropPort.cls`** (12,222 lines; anchors at plan; extend Story 20.31's family, Rule 31): `MESSAGEPAIRS` :337, `MESSAGECONTENTPAIR` :341, types and pairs :620-656 (`RESENDPAIR` :623, `RESENDMAX` :645), `MessageSet` :5216, the verdict family (`MessageVerdict`, `JudgeMessages`, `ResendDigest`, `ReadResend`) beside it, `PerformResend` :5437-5498 (the per-id loop, `Failed`, `Messages`), `OutcomeWord` :5277, `SuspendedOutcomeWord` :5286, `OpenBodyHere` :5080, `AuditViewHere` :5100, `ContentsText` :5114 (add an uncut mode), `ReadMessageContents` :5156, `RenderTargetHere` :11548, `StreamText` :11577 (`TESTOUTPUTMAX` :695 cut, which the export must not apply), `InvokeSuspended` :12033, `VendorSuspended` :12124. Browser-export sibling: `ExportTable` :7588-7658 (`output.lines`, the `AtelierPort.MAXIMPORTCHARACTERS` cap :489 of `AtelierPort`, `INTEROP.LOOKUP.TOOLARGE`).
- **`Port/LocalePort.cls`:** `TransferFile` :1843, `RemoveTransfer` :1861, `TransferParent` :1869, `TransferName` (the per-transfer directory under the OS temporary directory); make them reachable with a file-extension argument rather than copy (Rule 31), called before the switch and after the restore.
- **Vendor (read-only, read at plan):** `irislib/EnsPortal/Dialog/ExportMessages.cls` (`RESOURCE` :15, separators :314-317 and bytes :455-461, MLLP framing :494/:624, character sets :300-311, `tempServerDirectory` :244, `CreateTempFile` :385-657, body kinds :529-566, per-message `AuditViewMessage` :616-619, size limit :755-781, background mode :682-753); `irislib/EnsPortal/MessageViewer.cls` (`RESOURCE` :15, `canExportContents` :269, `doExport` :367-446); `irislib/Ens/Util/Auditing.cls` `AuditViewMessage` :19. The classic export checks only its `RESOURCE`, writes nothing for a body that is neither an EDI document nor an `%XML.Adaptor` object while still counting it, and audits only the bodies it writes.
- **`Api/InteropError.cls`:** `EXPORTNONE`, `EXPORTCHANGED`, `EXPORTTOOLARGE`, consequence `MESSAGEEXPORT`, `VERDICTEXPORT`, `VERDICTNOTEXT`, `OUTCOMEEXPORTED`, `OUTCOMENOTEXPORTED` beside :640-760, an `ExportCodes` list joined into `Codes` and `ConsequenceCodes`, `ReasonFor` arms, `VerdictSentence`. `VERDICTS` keeps its five words (`InteropResendDescriptor` asserts them); the new words go in an `EXPORTVERDICTS` list.
- **Tools (`Screen/Tool/`):** `InteropMessageExport` extending `InteropMessageAction` (`WriteOutput` :103-122, `FailureLine` :96) as `InteropMessageResend` does, with `SCREENACTIONS` `export`, `SCREENVALUES` `export=Separator:Charset`, `CLASSICPAGES` `EnsPortal.Dialog.ExportMessages`, `MintClass` the shared `InteropSuspendedMint`; `WriteOutput` adds `file` beside `lines`.
- **Descriptor:** `Screen/Descriptor/InteropMessageList.cls` :38-39: row action `export`, `multiSelect` `extraActions: ["export"]`. No new screen, route or entity type.
- **Kernel:** `Kernel/Governance/Baseline.cls` (c) one key; `Prohibited.cls` (c) appended terms only if the `Prohibited` test asks.
- **Client (`ui/src/app/`):** `areas/interoperability/interop-message-list.page.ts` (new, wrapping `<app-list-page />` as `interop-suspended-message-list.page.ts` does) registering `export`; `areas/interoperability/interop-message-export-dialog.ts` (new; siblings `areas/system-explorer/explorer-export-dialog.ts` and `interop-purge-dialog.ts`): the review lines from `handler.dryRunFor` (:1857), the two selects, the consequence, Export (button-primary) and Cancel; then `handler.sendFor` (:2084) with `Reviewed`, and `lastOutput()` (:2101); `core/csv.ts` `saveText` :94 extended to take bytes (Rule 31); `core/turn.ts` `outputLinesOf` :532 (used :1519): a confirm answer carrying `output.file` is saved by the confirming browser and the card receives the status and failure lines only (no `proposal-card.ts` edit); `shell/screen-action-handler.ts` (c) add-only map entries (`DRY_RUN_ACTIONS` :519, `ACTION_ADDRESS`, consequences), never `CHECKED_SET_DIALOGS`; `core/screen-actions.ts` (c); `core/proposal-view.ts` (c) consequence entry; `shell/screen-outlet.ts` (c) page registration; `core/strings.ts` (c); regenerate `screens.generated.ts` (c) and `Screen/Titles.cls` (c). Page sibling for the save: `interop-lookup-table-list.page.ts` (`linesOf` :55, `saveText` :278).
- **Tests (new; principal legs armed by `OCUPILOT_ALLOW_PRINCIPALS`, one add-only `# classes:` line in `scripts/ci-throwaway.sh`):** `Test/InteropMessageExport.cls` (both callers, oracle parity, separators, character sets, verdicts, partial, audit rows, file removed), `Test/InteropMessageExportRefusals.cls` (none, moved, too large, fault, 101, choices, gate as principals, no body text in a log, row or ledger), `Test/InteropMessageExportElsewhere.cls`; fixture `Test/InteropMessageExportFixture.cls` storing marked probe headers and bodies through `InteropMessageRead.StoreHeader` (:89) and the probe bodies `Test/InteropMessageContents.cls` builds, `DropProbes` in both namespaces; seam `Test/InteropExportSeam.cls` extending `InteropPort` (fail one render, throw mid-render, name the transfer parent). Follow-up 1: `Test/InteropSuspendedRefusals.cls` (220 lines) gains the all-failed tests through `InteropSuspendedSeam.FailActOf` (:15; `VendorSuspended` override :89, `MARKER`). Browser `ui/browser/interop-message-export.browser-spec.mjs` (sibling `interop-suspended-messages.browser-spec.mjs`); component specs for the page and dialog, and for `turn.ts`'s save.
- **Rosters (Rule 30; re-grep `interop.messages.resend`, `InteropMessageResend`, `interop.suspendedmessages` across `src/OcuPilot/Test`, `ui/tools`, `ui/browser`, `ui/src`, `scripts/`):** `ConfirmNamespaceRoster` `CHECKEDFLOOR` :34 124 → 125; `DraftRegistry` `ARGUMENTVALUES` :71 (`interop.messages.export=Separator:CRLF,Charset:UTF8`); `ToolWrite` (c) :1326 175 → 176; `GovernanceBaseline` (c); `Governance` (c); `SurfaceCoverage` (c); `StageTwoTools` (c); `ToolRoundTrip` (c); `ToolEmit`; `ClassicPageGate` (c) for the new classic page; `DryRunRoute`; `InteropDescriptor`; `InteropResendDescriptor`; `MappingDescriptor` (c) if the row action count is pinned; `ui/tools/interop.test.mjs` (sentence rows); `ui/tools/screen-mirror.test.mjs` (c); `ui/tools/ci.test.mjs` (the arming roster). Both callers reach `POST /screens/:screen/action` and `/dryrun`, so no new route.
- **EXPERIENCE.md** (c): one Fixed strings row after the Suspended messages row (:629), once the strings are ruled.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0** (`ocupilot-b-ci` only, USER and HSCUSTOM, auditing on; every probe header, body, file, user and role removed after; record under Design Notes, Measured): (a) whether `EnsPortal.Dialog.ExportMessages.CreateTempFile` runs outside a session over a `%ResultSet` of probe ids, and its file's bytes for the HL7, XML and stream probes, for each separator and for `UTF8` and `CP1252`: the oracle the tests compare with, and whether `ContentsText`'s renders equal them (HL7's separators, XML's indent); (b) the `ViewContents` rows the classic call and `AuditViewHere` each write, per body kind; (c) where `LocalePort.TransferParent` places the directory, the file's OS owner and mode, and that `^%SYS("TempDir",<ns>)` is unset (read at plan: unset in both); (d) a principal holding `%Ens_Portal:U`, `%Ens_MessageHeader:U`, `%Ens_MessageExport:U` and `%DB_USER:R` renders each body kind and writes its audit row, and whether anything more is needed; `$USERNAME` and `$ROLES` unchanged after each vendor call; (e) the rendered size and time of 100 probes of about 20 KB, and the largest file under the cap; (f) follow-up 1's current answers for two ids failed by the seam (resubmit, discard, delete), and whether the vendor audits a refused resubmit. HALT `blocked` if a read writes beyond the audit rows, if (a) shows OcuPilot's HL7 or XML render cannot equal the classic bytes, if (d) finds an escalation, or if a consequence sentence measures untrue (`intent gap: new string`).
- [ ] **Follow-up 1, test first:** `Test/InteropSuspendedRefusals.cls` -- the all-failed matrix row for resubmit, discard and delete from both callers, asserting the contract named above, run before any code change; change `InteropPort.cls` or `InteropMessageAction.cls` only for a red leg, and record which.
- [ ] `src/OcuPilot/Port/InteropPort.cls`, `src/OcuPilot/Api/InteropError.cls`, `src/OcuPilot/Port/LocalePort.cls` -- the review, the lists, the write, the file lifecycle, the snippet, the codes -- one port, the family extended.
- [ ] `src/OcuPilot/Screen/Tool/InteropMessageExport.cls`, `src/OcuPilot/Screen/Descriptor/InteropMessageList.cls`, `src/OcuPilot/Kernel/Governance/Baseline.cls` -- the tool, the row action, the key.
- [ ] `ui/src/app/areas/interoperability/interop-message-list.page.ts`, `interop-message-export-dialog.ts`, `ui/src/app/core/csv.ts`, `ui/src/app/core/turn.ts`, and the add-only maps and strings the Code Map names -- the page, the dialog, the byte save, the confirm's save; then regenerate the mirror and titles and add the EXPERIENCE.md row.
- [ ] `src/OcuPilot/Test/InteropMessageExport*.cls`, `InteropExportSeam.cls`, `ui/browser/interop-message-export.browser-spec.mjs`, the component specs, and the rosters the sweep names -- the matrix, either order.

**Acceptance Criteria:**

- **AC1 (export, person).** Given USER's probes, when a person reviews checked rows and exports them with each separator and both character sets, then the saved file's bytes equal Task 0 (a)'s oracle for the HL7 and XML bodies and carry the stream's text as Contents shows it, the binary body is left out with its verdict line, one `ViewContents` row is written per exported body, and no export file or directory remains.
- **AC2 (export, agent).** Given the same probes, when the agent's proposal is confirmed on the card, then the confirming browser saves the same bytes, and no body text reaches the proposal row, the ledger, the transcript, the model or a log line.
- **AC3 (refusals, gate, file removed).** Given each refusal and fault row of the matrix, when either caller exports, then the named code answers before any render (or, for too large and the fault, after it), nothing is saved, and the transfer directory is gone.
- **AC4 (partial and all failed).** Given the partial and all-failed rows, when either caller exports, then the answer follows the resend family's contract, the screen's outcome and the card's output name each failed id, and no file is saved when none was exported.
- **AC5 (the proposal's namespace; Integration, Rule 1).** Given probes in USER and HSCUSTOM, when the agent's export is minted in USER and confirmed from HSCUSTOM, then USER's bodies are exported and audited in USER and HSCUSTOM is not read.
- **AC6 (browser).** Given a fresh instance, when a person checks two Messages rows and exports them, then the browser saves a file holding both bodies and the status line names the count.
- **AC7 (Batch 2's all-failed writes).** Given two suspended probes failed by the seam, when each caller resubmits, discards and deletes them, then each answer is 200 with `Done` 0 and `Failed` 2, both ids carry the vendor's status in `Messages` and in an outcome line, and the discard and delete rows list both under `failed`.
- **AC8 (fresh, either order).** Given any new or changed test, run first on a fresh instance in either order, when it ends, then no probe header, body, export file or directory remains in either namespace.

## Spec Change Log

## Review Triage Log

### 2026-11-23 review (Opus; four layers: adversarial, edge cases, verification gaps, intent)

Patched:

- **M1** An oversize export in a widening character set, or of a long non-ASCII body, answered 500 (`<MAXSTRING>` in one `$ZConvert` of the whole body, or in `ExportNarrow`'s check) instead of 409 `INTEROP.EXPORT.TOOLARGE`. `ExportWrite` converts in pieces; Decided in-stage (review) 1.
- **M2** `PerformExport`'s end compare had no red leg: a body at the cap with `LF` sent 2,250,001 bytes under mutation. New leg.
- **M3** The per-body read-limit guard (`'AtEnd`) had no red leg: a cut file was sent under mutation. New leg.
- **M4** AC2's state sweep looked for the sentinel in plain text, which the base64 file never holds. The sweep now looks for the file as the answer carries it.
- **L1** `SnippetForm` gave the Messages review `EXPORT` a script form. Decided in-stage (review) 3.
- **L2** AC7's HTTP delete leg did not assert the `ConfigChange` row; it does now.
- **L3** `main.ts`'s `saveFile` wiring and `saveText`'s byte path were unpinned; two tool tests.
- **L4** The verdict-order mutation a test named could not redden; it names one that does.
- **L5** No byte comparison covered a byte order mark; AC1's loop adds `UnicodeLittle`.
- **L6** Stale wording: `IsMessageType`, `OutcomeLine`, a turn test title naming a leg it lacks, and `InteropFloor`'s roster doc (point 4 (c)).

Rejected (each with `reopen_if`):

- A body past the read limit whose `CRLF`s would narrow it under the cap is refused (Decided in-stage (review) 2). reopen_if: a real message is refused that would fit.
- None and moved reach the callers as the family's 400 `TOOL.ARGUMENTS` and `PROPOSAL.TARGETCHANGED`, the port's 409 behind them (Suspended messages and resend do the same). reopen_if: the spec means the port's code at the caller.
- The gate legs run through the fake gate, which replaces the privilege check alone; the pairs and their order are the port's own, and real principals meet the pairs in `ClassicPageGate` and `InteropFloor`. reopen_if: a defect in the check the fake gate replaces.
- Epic 21 files: the shell edits add entries to existing maps and lists with no logic change, and the roster lines are the Code Map's sweep. reopen_if: the orchestrator reads appending to an existing entry as non-add-only.
- The classic writes nothing for a character stream, no "<Device Default>" set, a per-user size lookup; alarm bodies leave no view row; a stream's `CRLF` reads `LF`: each is a planned decision (plan 3, 4; V2; "as Contents records it"). reopen_if: the owner wants the classic's behavior.
- Latent client paths: any tool's `output.file` is saved as an export; the dialog keeps a stale digest after `CHANGED`; an empty digest or malformed file shows nothing. reopen_if: a second tool answers `file`, or a person meets one.
- Script form: no character set, byte order mark or `CRLF` rule, and no guard for an id with no body; a draft is rendered, never run. reopen_if: drafts become runnable.
- `EXPORTCHOICES` has no product caller; `nobody` reads for a header with no body; an explicit empty choice is refused by the tool. Spec words and rules. reopen_if: the agent needs the lists in its schema.

Deferred (ledger candidates, returned to the lead): a stream's `Read` status is not checked; too large, fault, partial and all-failed are not run through the agent's confirm over HTTP, nor AC7's resubmit and discard; the consequence sentence says "between them" though the separator also follows the last message (a ruled string); AC8's test performs no export and `TempListing` compares a shared directory.

## Veto items

Each is the lead's to take to the veto gate; the recommended option is first.

1. **Both callers reach the export.** The agent's proposal is confirmed on the card, and the confirming browser saves the file, as the screen does (AD-53, AD-40): the confirm's answer carries `output.file`, `turn.ts` saves it and hands the card the status and failure lines. Alternative: the person's screen action alone; no mechanism makes a registered write tool screen-only, so that needs a kernel change and an AD amendment.
2. **The file holding message content.** Created by the request that exports, in a directory made for that export under the instance's temporary directory (`LocalePort.TransferParent`, Task 0 (c)), named by a GUID, never by a caller; written with the chosen character set, read back whole, and removed with its directory before the request answers, on every exit (success, refusal, too large, fault); never kept, listed or served. While it exists it carries the instance's default file mode, readable by the instance's OS account and by any OS account that can reach the directory: a shell in the container reports umask 0022 and the instance's temporary directory is mode 0775 (measured on `ocupilot-b-ci`), so the file is 0644 (inference until Task 0 (c)). Its bytes travel base64-encoded in the JSON answer, at most `AtelierPort.MAXIMPORTCHARACTERS` (3,000,000) encoded characters, so at most 2,250,000 bytes, refused whole above that (the classic export stops at half the disk's free space or the `EnsFileSizeLimitMB` lookup and reports a partial file). The browser saves it as `<NAMESPACE>-messages.txt`. Alternative A: no disk file (the text translated in memory with `$ZCONVERT` into a `%Stream.TmpBinary`). Alternative B: the classic size limit.
3. **Security posture: the classic export's, no stricter.** `%Ens_Portal:USE`, `%Ens_MessageHeader:USE`, `%Ens_MessageExport:USE` and the namespace's database READ. Alternative (stricter): also `%Ens_MessageContent:USE`, which OcuPilot's Contents tab requires and the classic export does not.
4. **New user-facing strings** (reused, each read true here: "Export" (`taskExportAction`, the action, the dialog's button and the row action's label), "Cancel" (`actionCancel`), "The file is larger than OcuPilot imports or exports." (EXPERIENCE.md:609, `analyticsRefusalTermListTooLarge`), the verdicts "no longer exists" and "its body no longer exists" (`interopResendVerdictGone`, `interopResendVerdictNobody`)):
   - Dialog title: "Export <n> messages" · "Export 1 message".
   - Field labels: "Message separator" · "Character set". Separator options (the classic's own names): "CRLF" · "CR" · "LF" · "MLLP" · "Tab" · "None". Character set options are the instance's table names, shown as data.
   - Verdicts: "will be exported" · "its body cannot be exported as text". Outcomes: "exported" · "not exported".
   - Consequence (`MESSAGEEXPORT`, dialog and card): "Exporting saves the body of each message marked to be exported to one file in this browser's downloads, in message id order, with the chosen separator between them. Each body exported is recorded in the audit log as viewed. Anyone who can open the file can read the messages."
   - Refusals: `NONE` "None of these messages can be exported. Each one's line says why." · `CHANGED` "These messages changed after they were reviewed, so nothing was exported. Review them again."
   - Status lines: "Saved <n> messages as <file>." · "Saved 1 message as <file>."
5. **AD amendments, proposed for story end (the orchestrator writes them, add-only; never here).** Each takes `[AMENDED <date>, Story 24.16, Rule 20]`.
   - AD-62, item 21: "**Export messages** (Story 24.16). `InteropPort` gains `EXPORT` and `EXPORTMESSAGES` on `Messages`: at most 100 reviewed ids, each judged before any render (gone, a body no longer present, a body Contents cannot show as text), behind `%Ens_MessageExport:USE`, the classic `EnsPortal.Dialog.ExportMessages` `RESOURCE`, beside the Messages pairs. Each exported body is rendered as Contents renders it, uncut, in ascending id order, with the classic dialog's separator and a character set the instance lists, into a file in a directory the port makes for that export under the instance's temporary directory; the file's bytes ride on the answer base64-encoded, at most 3,000,000 characters, and the file and its directory are removed before the request answers, on every exit. Each exported body records the vendor's `%Ensemble/%Message/ViewContents`. The background saved-search export is not offered."
   - AD-7: "**A message export (Story 24.16)** runs in its confirm or action request; its file exists only while that request runs."
   - AD-39, fifth exception: "and a message export's file (Story 24.16), which the confirming browser saves and which reaches no row, ledger or model".
   - AD-22: "**Story 24.16's Batch 3 key:** `interop.messages.export` ships `true`."
6. **DW-2849 (Discard through the ordinary confirm) is not planned here.** It needs no new string (the warning dialog would read "Discard" (`interopSuspendedDiscardAction`), the discard consequence, and "Proceed" / "Cancel"), but it is a logic change in three files Epic 21 changed, which this run may edit only add-only: `shell/screen-action-handler.ts` (`openReview` :1909-1929 always opens `'typed-name'` and has no per-action kind; `confirmPending` :1483 takes the reviewed path only for `'typed-name'`), and `shell/warning-dialog.ts` with `shell/screen-action-dialogs.ts` :75-85 (the warning dialog has no `review` input). Recommended: plan it as its own item once Epic 21's changes to those files reach feature, or on the orchestrator lifting the add-only rule for these three edits; Batch 2's spec then gets its one-line update. The export avoids the same path: its review is the page's own dialog, never `CHECKED_SET_DIALOGS`.

No new dependency; no privilege, role or access grant.

**Lead rulings at the spec gate (2026-11-23; filed as an INBOX veto item, so binding unless the orchestrator reverses them).**

- **V1:** kept. Both callers reach the export.
- **V2: Alternative A. No file is written on the instance.** Each body is rendered and converted in memory to the chosen character set (`$ZCONVERT`). The bytes are gathered in a `%Stream.TmpBinary` or an equivalent in-process stream, and leave base64-encoded on the answer under the same 3,000,000-character cap, refused whole above it. Nothing is created under the OS temporary directory, so no copy of message content is ever readable by another OS account, and there is nothing to clean up. `LocalePort.TransferFile`, `TransferParent` and Task 0 (c) drop out. Task 0 (a) must show that the in-memory bytes equal the classic `CreateTempFile` bytes for every separator and for `UTF8` and `CP1252`. If a listed character set cannot reach the classic bytes in memory, HALT with `## Clarification Needed`; never fall back to a disk file.
- **V3: the stricter posture.** The pairs are `%Ens_Portal:USE`, `%Ens_MessageHeader:USE`, `%Ens_MessageExport:USE`, `%Ens_MessageContent:USE` and the namespace's database READ. The export writes exactly what OcuPilot's Contents tab shows, and Contents requires `%Ens_MessageContent:USE`, so an export must never be a way round it. Task 0 (d)'s principal holds the extra pair. A test shows a principal without it is refused before any render.
- **V4:** kept. The strings are as quoted.
- **V5:** kept for story end, reworded to V2 and V3. AD-62 item 21 says the bytes are built in memory and names `%Ens_MessageContent:USE` beside `%Ens_MessageExport:USE`. AD-7 reads: "**A message export (Story 24.16)** runs in its confirm or action request and writes no file on the instance."
- **V6:** accepted. DW-2849 stays routed to burndown, because the change needs logic edits in three files that are add-only for this run. Batch 3 does not carry it.
- **Decided in-stage 7** (`Failed` is a count, and `Messages` names each id) matches the orchestrator's ruling on Batch 2 (200 with each failed id named, resend family).

## Design Notes

**Decided in-stage (plan).**

1. Epic context reused as committed (dispatch instruction, as Batches 1 and 2); the spine's AD-7, AD-9, AD-12, AD-15, AD-22, AD-35, AD-59 and AD-62 and both earlier specs were read directly.
2. The export lives on Messages (the classic opens it from the Message Viewer), on checked rows, at most 100, as resend.
3. The bodies written are `ContentsText`'s (EDI, `%XML.Adaptor`, character stream), one rule with Contents; a character stream is written as its text, where the classic writes nothing for it and still counts it. A binary or other body reads `notext` and is left out.
4. The character-set list is the instance's own (`GetIONames^%SYS.NLS`, the classic's), read at the call, `UTF8` preselected; there is no "device default" entry, so no string is added for it. Measured at plan on `ocupilot-b-ci`: the list holds `UTF8`, `CP1252`, `Latin2`, `UnicodeLittle` and 18 others.
5. The view audit source is `AuditViewHere`'s (`"OcuPilot"`), as Contents records it; the classic writes "Message Browser Export to user's browser".
6. A failed render follows the resend family (200, the rest exported), not Batch 1's purge family (a failed vendor status answered 500), because an export, like a resend, acts per message.
7. Follow-up 1 reads "each failed id named in `Failed`" as the resend family's shape: `Failed` is a count and `Messages` names each id (`PerformResend` :5491-5496); the tests assert that shape and nothing changes it.
8. The page's dialog, not the shared handler's review, carries the export's review, so no Epic 21 file takes a logic edit; the shared handler gains add-only map entries.
9. A separator or character set outside its list is refused with the action's argument problem, built from the argument name as `AuditPurge`'s date problem is; tool descriptions and schema text are agent-facing.
10. The export writes no database, so its pairs carry READ, never WRITE, as the explorer export's (Story 19.13).
11. Siblings (Rule 31): `InteropMessageResend` and the resend port family (tool, verdicts, loop), `InteropSuspendedMint` (mint), `ExportTable` (browser export, cap), `LocalePort.TransferFile` (the directory), `ContentsText` (render), `saveText` (save), `explorer-export-dialog.ts` (dialog), `interop-suspended-message-list.page.ts` (page), `InteropSuspendedSeam` (all-failed tests).

**Measured (Task 0, `ocupilot-b-ci`, `HSCUSTOM` probes; every probe header, body, user and role removed after).**

- (a) `EnsPortal.Dialog.ExportMessages.CreateTempFile` runs outside a session over a `%ResultSet` of ids, as `irisowner`, writing a temporary file the probe read and removed. Its bytes for an HL7 v2 message, an `Ens.StringRequest`, an EDI XML document and a 227 KB HL7 message, singly and together, for each of the six separators and `UTF8` and `CP1252`, and for all 22 character sets the instance lists (`URI`, `UnicodeLittle`, `UnicodeBig`, `UTF8`, `RAW`, the `CP` and `Latin` sets and `EBCDIC`) with `CRLF` and `MLLP`, **equal the bytes built in memory**. What the classic writes, which the in-memory build reproduces: the separator after every message, the last included; MLLP as `VT` before the first, `FS` between and `FS CR` after the last; a `CRLF` in one written chunk read as `LF` by its file stream (so a `CRLF` separator reads `LF` on this Linux instance); each character above 255 in an EDI body `?` (the device carries bytes); an XML-adaptor body as indented UTF-8 bytes each taken for a character (declaration and `LF` line ends included) before the character set converts it; `UnicodeLittle` and `UnicodeBig` files begin with their byte order mark. `ContentsText`'s render is not that text (`CRLF` segment ends, no XML declaration), so the export has its own render and `ContentsText` is unchanged. No listed character set failed to reach the classic bytes: V2's halt did not fire.
- (b) The classic writes one `ViewContents` row per EDI or XML body exported, described "Message Browser Export to user's browser", none for a stream or binary body (which it counts as exported); `AuditViewHere` writes one row per body opened, described `OcuPilot`.
- (c) Dropped by V2.
- (d) A principal holding `%Ens_Portal:U`, `%Ens_MessageHeader:U`, `%Ens_MessageExport:U`, `%Ens_MessageContent:U`, READ on `%DB_HSCUSTOM` and `%Development:U` opens and renders every body kind and writes each view row; `$USERNAME` and `$ROLES` read the same after every call. Nothing more is needed, no write on the database either. Reading the audit rows takes a privilege the principal lacked, so the rows were counted as an administrator.
- (e) 100 HL7 probes of about 9.9 KB (not 20 KB): 986,746 bytes, 0.13 s in memory against 0.27 s for the classic call, equal; 1,315,664 base64 characters. A file of exactly the cap, 2,250,000 bytes, is 3,000,000 characters and travels through the port and over HTTP to the browser's route. Stored body sizes do not predict the rendered size (an XML object's rendering has nothing to do with its stored size), so the cap is judged on the rendered stream, before any view is audited.
- (f) The all-failed answers for resubmit, discard and delete are the resend family's contract on the unchanged code: 200, `Done` 0, `Failed` 2, both ids in `Messages`. Whether the vendor audits a refused resubmit was not measured: the seam answers before the vendor call.
- (g) Review, on `ocupilot-b-ci`, a probe user holding `%EnsRole_Administrator` alone (removed after): `CheckUserPermission` reads 1 for `%Ens_Portal:USE`, `%Ens_MessageHeader:USE` (through the granted `%EnsRole_Operator`), `%Ens_MessageExport:USE` and `%Ens_MessageContent:USE`, and 0 for `%DB_USER:READ` and WRITE; the role holds no database resource. With `%DB_USER:R` beside it, as the floor's principal holds its code database's READ, the Message Viewer serves that user with `canExportContents` true, the classic Export button's own `%Ens_MessageExport:USE` check, and the dialog's `RESOURCE` is that same pair. The dialog is `PRIVATE`: a direct GET answers 403, for `_SYSTEM` too, so it opens only through the viewer's link. Every other write tool declares database WRITE, which the floor's principal lacks.
- (h) Review: the widest listed character set, `URI`, writes 9 characters for one (measured over all 22 sets), so a piece of `EXPORTCHUNK` (300,000) characters stays under the longest string.

**Named limits (the orchestrator's U-150 ruling).** Messages per export: `RESENDMAX` (100). Bytes per file: `EXPORTMAXBYTES` 2,250,000, which is `OcuPilot.Port.AtelierPort.MAXIMPORTCHARACTERS` (3,000,000) over four times three, a test holding the two equal; (e) shows that value safe end to end, so it is not lowered. The file is built in a `%Stream.TmpBinary`, one body's text at most `EXPORTMAXBYTES` + 1 characters at a time, and encoded in one `Base64Encode` call without line breaks. An export over the limit is refused before any view is audited and before any byte leaves, with the sentence "The file is larger than OcuPilot imports or exports."

**Decided in-stage (implement).**

1. The bytes reproduce the classic's exactly, its narrowing and `CRLF` reading included, since V2 and AC1 bind equality; the rule lives in one place (`ExportRenderHere`, `ExportMemberHere`, `ExportTail`), so a later change of that rule is one edit. A character stream is written as its text, as the plan decided.
2. A render that returns an error status fails that message (200, the rest exported); a render that throws is 500 for the whole export, logged after the namespace is restored, with no view recorded. Views are audited once every body is rendered and the cap is met.
3. The tool extends `InteropSuspendedAction` (the nearest sibling), which gains `NONECODE`; `MessageVerdict` gains `pNoText` and `SuspendedOutcomeWord` an `export` arm. `EXPORTCHOICES` is served by the port; the dialog reads the lists from the review's answer, so it asks nothing else.
4. The pairs are in the port's order, `%Ens_Portal:USE`, `%Ens_MessageHeader:USE`, `%Ens_MessageExport:USE`, `%Ens_MessageContent:USE`, then READ (never WRITE) on the globals database. The tool's `SettableFields` is `Separator,Charset,Reviewed`, the order its screen action declares. `ClassicPageGate`'s principals gain `%Ens_MessageExport:U`.
5. The script form writes with the command's abbreviation `W`, because `scripts/check-objectscript.py` allows the spelling `Write` in no class but the response writers (AD-12).
6. The new classes start no probe production (`InteropMessageExportCase`). `HoldBody` moves from `InteropSuspendedRemove` to `InteropSuspendedCase`, and `OutcomeLine` and `OutcomeText` join it, for the follow-up 1 tests.
7. Follow-up 1: the seam cannot cross into the HTTP process, so resubmit, discard and delete reach the person's screen leg through the port and the tool's `WriteOutput` (the lines both callers draw), and a delete whose two bodies are locked fails for real from both callers over HTTP.
8. The Messages page wraps `AuditPage`, the search page its archetype already uses, with Export registered over it; `saveText` takes bytes, and `TurnStore` takes a `saveFile` option so `core/` touches no browser global.

**Decided in-stage (review).**

1. A body is converted to its character set `EXPORTCHUNK` characters at a time (`ExportWrite`), stopping once the bytes pass the cap, so an oversize file is the named 409 in every listed character set, never a `<MAXSTRING>` 500; `ExportNarrow` tests for wide characters with `$ZIsWide` rather than by converting.
2. A body longer than the read limit (`EXPORTMAXBYTES` + 1 characters) stays refused whole even when its `CRLF` pairs would narrow it under the cap: the safe side of "never cut".
3. `SnippetForm` gives `EXPORT` a script form on the lookup tables endpoint alone, so the Messages review, a read, has none (AD-59).
4. `InteropFloor.ADMINISTRATORWRITES` is parity with the classic page (Measured (g); the orchestrator's ruling on point 4): it holds exactly `interop.messages.export`, and any other write tool the Administrator principal can reach turns the floor red.
5. The two size compares stay: `ExportMemberHere`'s stops rendering at the first body that passes the cap, and `PerformExport`'s covers the bytes the file ends with; each now has its own red leg.

**Governing ADs (Rule 6):** AD-3, AD-6, AD-7, AD-8, AD-10, AD-11, AD-12, AD-13, AD-14, AD-15, AD-16, AD-21, AD-22, AD-29, AD-34, AD-36, AD-39, AD-40, AD-44, AD-51, AD-52, AD-53, AD-56, AD-58, AD-59, AD-60, AD-62 (items 1-5, 15, 17). Not engaged: AD-9 (no `$ROLES` frame unless Task 0 (d) finds an escalation, which HALTs), AD-23, AD-35 (no secret), AD-54, AD-63, AD-65, AD-66.

**Integration and linkage (Rules 1, 2).** Integration: AC5 (the kernel's confirm consumes the stored proposal in its own namespace) and AC2 (the client's confirm path consumes `output.file`). Consumes: `InteropPort`'s resend family and `ContentsText`, `InteropMessageAction`, `InteropSuspendedMint`, `LocalePort`'s transfer directory, the kernel's proposal, confirm, governance and audit. Consumed-by: Story 24.20's undo names the export as having nothing to undo.

**Ledger inbox (Rule 17):** `LEDGER slice 24-16-...` empty at plan; DW-2849 is answered by Veto items 6; `owned_ledger=0`.

## Verification

**Commands** (one `ci-runner` call per message; `ocupilot-b-ci` only):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.InteropSuspendedRefusals` first (follow-up 1, before any code change), then likewise `InteropMessageExport`, `InteropMessageExportRefusals`, `InteropMessageExportElsewhere`, `InteropMessageContents`, `InteropResend`, `ConfirmNamespaceRoster`, `DraftRegistry`, `GovernanceBaseline`, `ClassicPageGate`, and every class the roster sweep changes. Expected: green; new classes green on their first run.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`, `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/interop-message-export.browser-spec.mjs browser/interop-message-resend.browser-spec.mjs`. Expected: green.
- `(once)` The full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one call each. Expected: green. The full browser suite is left to CI.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`. Expected: clean.

**Shared surfaces:** the Messages screen's row actions and checked-set actions; the governance baseline; the draft, dry-run, classic-page, confirm-namespace and write rosters; `InteropError`'s code and verdict lists; `interop.test.mjs`'s sentence rows; `screen-mirror.test.mjs`; the arming roster; `saveText`'s signature; the confirm path's `output` in `turn.ts`; USER's and HSCUSTOM's message stores; the instance's temporary directory.

**Hermeticity:** every test added or changed passes on its first run on a fresh instance, in either order; it makes its own probes, asserts on them by id or marker, removes them in both namespaces, and asserts no export directory of its own remains (the seam names the transfer parent).

**Mutations** (each AC's pinning test shown red on `ocupilot-b-ci`, `src` reloaded with subclasses and reverted byte-identical; client ones on a rebuilt, redeployed bundle or in the component runner), recorded by the implement stage as `mutation: <change> -> <test red>`. Planned: AC1 the `MLLP` separator written as `LF` -> `InteropMessageExport` red (the oracle leg); AC2 `turn.ts` hands the card the base64 line -> the `turn.ts` component spec red; AC3 `RemoveTransfer` skipped on the fault path -> `InteropMessageExportRefusals` red; AC4 a failed render counted as exported -> `InteropMessageExport` red (the partial leg); AC5 `FINGERPRINTSUBJECT` without `Namespace` -> `InteropMessageExportElsewhere` red; AC6 the page saves the outcome lines instead of the file -> the browser spec red; AC7 `PerformResend` answers 409 when nothing was done -> `InteropSuspendedRefusals` red (the all-failed legs); AC8 the fixture's HSCUSTOM `DropProbes` skipped -> `InteropMessageExportElsewhere`'s after-all check red.

**Recorded (implement).** Server mutations on `ocupilot-b-ci`, `InteropPort` and the seams reloaded with the change and again after the revert (`cmp` identical each time):

- mutation: the `MLLP` separator written as `LF` -> `InteropMessageExport` red (the oracle leg, AC1).
- mutation: the tool drops the character set from the payload it sends -> `InteropMessageExport` red, two tests (AC1, AC2).
- mutation: the size compare in `ExportMemberHere` is `>=` the cap -> `InteropMessageExportRefusals` red (the at-the-cap leg); the cap raised to 9,000,000 -> the one-over leg red; the compare `>` cap plus one in `ExportMemberHere` and in `PerformExport` together -> the one-over leg red (in `ExportMemberHere` alone it stays green, since `PerformExport` also compares) (AC3).
- mutation: a failed render counted as exported -> `InteropMessageExport` red, two tests (AC4).
- mutation: `FINGERPRINTSUBJECT` without `Namespace` -> `InteropMessageExportElsewhere` red, two tests, and `ConfirmNamespaceRoster` red (AC5).
- mutation: `PerformResend` answers 409 when nothing was done -> `InteropSuspendedRefusals` red, two tests (AC7).
- mutation: the fixture's `DropProbes` skips the second namespace -> `InteropMessageExportElsewhere` red, three tests including the class level (AC8).
- mutation: the export branch of `Pairs` without `%Ens_MessageContent:USE` -> `InteropMessageExportRefusals` red (V3).
- mutation: the `DraftRegistry` row for the tool's two settable fields removed -> `DraftRegistry` red.
- mutation: `turn.ts` hands the card the output lines instead of the export card's status and failure lines -> `tools/turn.test.mjs` red (AC2).
- mutation: the page saves the failure lines in place of the file bytes -> the browser spec red on the rebuilt, redeployed bundle, and the page component spec red (AC6).

The planned AC3 mutation (`RemoveTransfer` skipped) does not apply: V2 builds the file in memory, so there is no transfer directory to remove.

**Recorded (review).** Each on `ocupilot-b-ci`, the class reloaded with subclasses, red in the named test alone, green after the revert, `cmp`-identical to a copy taken before:

- mutation: `PerformExport`'s end compare is `>` the cap plus one -> `InteropMessageExportRefusals.TestTheCapHoldsAtTheFilesEndForABodyReadInPartAndInAWideCharacterSet` red (2,250,001 bytes answered).
- mutation: `ExportRenderHere` sets a stream's `pTooLarge` to 0 -> the same test red (a cut file of 1,125,001 bytes answered 200).
- mutation: `EXPORTCHUNK` 3,000,000, one piece -> the same test red (500 `INTERNAL`).
- mutation: `SnippetForm`'s `EXPORT` test without the endpoint -> `TestTheScriptFormRendersTheExportAndRunsNothingAndABadValueRendersNoDraft` red.
- mutation: the export arm of `MessageVerdict` without its `nobody` test -> `TestEachMessageIsJudgedAndOnlyThoseWithATextBodyAreExported` red (and `TestAReviewThatMovedIsRefusedAndNothingIsExported`).
- mutation: `ExportByteOrderMark` answers `""` -> `InteropMessageExport`'s AC1 test red, its six `UnicodeLittle` legs alone.
- mutation: `Confirm` also keeps its `output` in `^OcuPilot.Kernel.State.LeakProbe` -> `TestTheAgentsExportConfirmsOverHttpAndKeepsNoBodyTextInItsState` red on the file leg, the sentinel leg green (global killed after).
- mutation: `PerformResend` records the change row only when a message was done -> `InteropSuspendedRefusals` red, both all-failed tests.
- mutation: `ADMINISTRATORWRITES` empty -> `InteropFloor.TestTheToolsEachPrincipalHoldsAreItsRoster` red, the Administrator leg alone; `InteropSuspendedDiscard` given `DATABASEPERMISSION` READ -> the same leg red.
- mutation: `main.ts` without `saveFile`, and `saveText` decoding bytes as text -> `tools/message-export.test.mjs` and `tools/csv.test.mjs` red, one test each.

## Auto Run Result

Status: in-review
Blocking condition: none

**Review (Opus, 2026-11-23).** Four medium findings and six low ones patched, none high (Review Triage Log). The size cap is now the named 409 in every character set (`ExportWrite`), and each of its guards has a red leg; the AC2 sweep sees the file as it travels; the Messages review has no script form; AC7's HTTP delete asserts its change row; the client's byte save and its `main.ts` wiring are pinned; and `InteropFloor`'s one Administrator write is measured as classic parity (Measured (g)). Verified on `ocupilot-b-ci`, rebuilt at 2026-11-23T14:11:15Z: `InteropSessionRoute` green, run first and cold; then every touched class, the rosters, the five `InteropSuspended*` classes and the five `InteropResend*` classes green, one class per call; the export, resend and suspended messages browser specs green on a rebuilt, redeployed bundle; no production or probe left. `npm run build`, `npm test` (2,410 tool tests, 330 component files), `ci.test.mjs`, `check-objectscript` and `lint-docs` clean. Mutations: Recorded (review).

**Implemented (implement stage).** Export on the Messages screen's checked rows and as the agent's `interop.messages.export` write, through `InteropPort` (`ExportChoices`, `ReadExport`, `PerformExport`, the in-memory byte build in `ExportRenderHere`, `ExportMemberHere` and `ExportTail`), the tool `InteropMessageExport`, the row and checked-set action on `InteropMessageList`, the baseline key, and the client page `interop-message-list.page.ts` with its dialog, `message-export.ts`, the byte save in `csv.ts` and the confirm path's file save in `turn.ts`. Every proposal carries its namespace and its confirm judges there; the file is built in memory (V2), needs `%Ens_MessageContent:USE` as well (V3), and is capped at `EXPORTMAXBYTES` (2,250,000) with the named refusal. Follow-up 1's all-failed test for Batch 2's writes was added first and was green on the unchanged code, so no Batch 2 code changed.

**Verified.** All 17 `ci-runner` shards green on `ocupilot-b-ci` (shards 6 and 10 re-run in full after the two roster updates below; shard 5's `InteropSessionRoute` failed once on this long-lived instance, identically with the story's base `InteropPort`, and passes with the cached query warmed, so it is instance state and not this change (inference); it passed on fresh instances in earlier runs). Smoke 50 of 50; `check-objectscript` 0 problems; `lint-docs` clean; `npm run build`, `test:tools` (2,408), the component runner (330 files, 3,914 tests) and `ci.test.mjs` green; the browser specs for export, resend, messages and suspended messages green on a freshly built and deployed bundle; no probe header, body, user, role or production left. Rosters updated: `InteropFloor` (the Administrator holds the one write tool whose pairs need READ only), `InteropMessageDescriptor` (two row actions), `ConfirmNamespaceRoster`, `DraftRegistry`, `ClassicPageGate`, `SurfaceCoverage`, `ToolEmit`, `ReadTool`, `ToolWrite`, `ToolRoundTrip`, `Prohibited`, `InteropDescriptor`, `InteropResendDescriptor`, `MappingDescriptor`, and the arming roster in `scripts/ci-throwaway.sh`.
