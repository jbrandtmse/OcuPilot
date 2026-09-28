---
title: 'Story 16.2: Web sessions, listed and ended'
type: 'feature'
created: '2026-09-28'
status: 'done'
baseline_revision: '5bd3404921b58f23316d46ecb735f3ba2746b94e'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** To clear a stuck or unwanted web session, an administrator has to use the classic portal's Web Sessions page. OcuPilot can neither list sessions nor end one.

**Approach:** Add a Web sessions list to the Web applications area. It reads the admin API's `WebSession` `LIST`, and each row's Process cell links to Process details. Add an End session row action as one action-style write tool, `webapp.sessions.end` (`WebSession` `DELETE`). The screen and the agent both reach it, the person confirms by typing the session id, and the instance refuses it for a session OcuPilot is itself running in.

## Boundaries & Constraints

**Always:**

- **Read** (`webapp.sessions.read`, AD-36): the source is `{port: admin, endpoint: WebSession, type: LIST}`.
  - Fields: `ID, Username, Application, SesProcessId, Timeout, Preserve`.
  - Columns: Process (`SesProcessId`, the name column), Session (`ID`), User, Application, Expires (UTC) (`Timeout`).
  - Links: the Process cell links to `os-management/processes/details` through `rowTarget {route, field: SesProcessId}`, as Locks does. An empty process renders as the unlinked default "(none)".
  - The row key is `id {kind: composite, parts: [ID]}`. Entity type is `web-session` (new), scope `instance`. The classic page is `%CSP.UI.Portal.CSPSessions`.
- **Pairs** (AD-8, AD-29; each pair measured necessary on `ocupilot-ci`):
  - The screen declares `privileges` `%Admin_Operate:USE` and `%DB_IRISSYS:READ`, with `ownPrivileges` `%Admin_Operate:USE`. The area's own pairs are `%Admin_Secure:USE` and `%DB_IRISSYS:READ`.
  - The end tool also declares `%DB_IRISSYS:WRITE` (`WRITERESOURCE`/`WRITEPERMISSION`, as `DeviceDelete`), because `$$DeleteSession^%SYS.cspServer` answers `#921` without it. A caller without it is refused by name before any port call.
- **End** (AD-51, AD-53):
  - A bodyless `DELETE` with query `id`, destructive, confirmed through the typed-name dialog: the title is "End session <id>" and the person types the session id.
  - The fresh read is the `LIST` row whose `ID` equals the id **exactly, case included**. Session ids are mixed-case random strings, and `Operation.ReadTarget` folds case today.
  - Fingerprint subject: `Username,Application,Preserve,SesProcessId`. `Timeout` is excluded because every request the session serves moves it. The precondition field is `Application`.
- **Believed only when gone.** The vendor marks the session and a daemon removes it 1.6–4.1 s later (measured). So after the vendor answers 2xx, `AdminPort` re-reads `LIST` every 250 ms until no row carries the id, for at most 10 s. Past that bound the write still stands as made (AD-26: never a false failure), and the read-back (AD-58) says what the instance holds.
- **Self-protection** (AD-10, AD-53; option A, the lead's ruling at the spec gate):
  - The code is `PROHIBITED.OCUPILOTSESSION`. It covers a session whose `Application` is one `Prohibited.ServesOcuPilot` names (roster or install record, normalized path), or whose `ID` is the serving request's `%session.SessionId`.
  - The instance refuses it whoever the caller is. The check is evaluated on the fresh read inside the transition, and fails closed on a read with no `Application`.
  - The client rule `ocupilot-session` draws the row action `aria-disabled` with the same one sentence. It reads the row's `Application` against `OCUPILOT_APPLICATION_PATHS` under the web-application canonical rule.
- **Governance:** the key `webapp.sessions.end` joins `Baseline.cls`, enabled.
- **Copy:** new copy goes into EXPERIENCE.md's Fixed strings and `strings.ts` together. EXPERIENCE.md stays at 993 lines.

**Never:**

- **No new route, port or AD-27 vendor-class case.** The admin API carries both `LIST` and `DELETE`.
- **No `^%cspSession` access.** No OcuPilot code or test reads or writes it.
- **No auto-refresh.** AD-43's roster is unchanged.
- **No multi-select end.** Story 16.6 owns the table's selection model.
- **No `AllowEndSession` refusal**, unless the ruling is option C.
- **The session id never reaches** a ledger `detail`, a log line or the typed-name field's DOM beyond the dialog's own input.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| List | sessions under `/api/atelier/`, `/csp/sys/` | one row each: user, application, process ("(none)" when empty), id, expiry | none |
| Empty | no sessions | empty state and the agent invitation | none |
| Area holder only | `%Admin_Secure:USE` + `%DB_IRISSYS:READ`, no `%Admin_Operate` | Web sessions unavailable ("Requires %Admin_Operate"); Web applications and REST API explorer stay open | route and read refused naming the pair |
| Screen end | End session on a row, type the id, confirm | one POST; the port waits until the row is gone; the row leaves on the change event; the read-back reads gone | a mismatched id sends nothing |
| Agent end | `webapp.sessions.end {id}` | card lists Username, Application, Process, Expires as removed; the confirm ends the session; marker emitted | none |
| Already gone | session ended or expired after the read | 404 at the fresh read; refused; the row leaves on re-read | not-found envelope |
| Moved | `Username`/`Application`/`Preserve`/`SesProcessId` differ at confirm | `PROPOSAL.TARGETCHANGED` | confirm refused |
| Case twin | id differing only in case from a live one | absent (exact compare) | 404 |
| OcuPilot's own (option A) | `Application` `/api/ocupilot/`, `/API/OcuPilot`, `/ocupilot/`, `/api/ocupilot/readiness` | drawn disabled with the sentence; the instance refuses both callers | `PROHIBITED.OCUPILOTSESSION` |
| No write pair | holds the screen's pairs, lacks `%DB_IRISSYS:WRITE` | refused naming `%DB_IRISSYS:WRITE` before any port call | nothing sent |
| Slow daemon | still listed 10 s after the vendor's 2xx | write reported made; read-back reports still present; row stays until the next read | none |

</intent-contract>

## Code Map

- `src/OcuPilot/Screen/Descriptor/LockList.cls:40-94` -- the model descriptor: `rowTarget` (:92) on the name column, `id` composite. New `WebSessionList.cls` beside it. `Screen/Registry.cls:396` `DECLARATIONKEYS`, `:2171` column kinds, `:2538` prompt groups (Processes and Locks use `promptGroupTroubleshooting`), `:3388` `RowTargetProblem`, `:739-770` `OwnPrivilegesProblem` (`WalletCollectionList.cls:35-36` is an own-pair example). Web applications side bar: `WebAppList` 1, `RestApiList` 2, so the new screen is 3. `Screen/Area.cls:112` holds the area's pairs.
- `src/OcuPilot/Kernel/EntityType.cls:40` -- `TYPES` (32). Add `web-session`. No `IDRULES` pair (`Kernel/EntityRef.cls:59`), so the id is kept as given.
- `src/OcuPilot/Screen/Tool/DeviceDelete.cls` -- the model tool: bodyless `DELETE`, `WRITERESOURCE` `%DB_IRISSYS` + `PrivilegePairs` override, `REMOVALROWS`, `StateDiff`. `AuditEventReset.cls:47-54` is the `LIST` fresh-read model (`READTYPE LIST`, `READROWKEY`, `READANSWERS`). `Screen/Tool/Write.cls` holds the parameters, among them `READROWKEY` :181 and `SCREENACTIONS` :157.
- `src/OcuPilot/Kernel/Proposal/Operation.cls:252-282` -- `ReadTarget` compares with `$ZConvert(...,"U")`. `ReadRowKeyOf` :233 is the accessor pattern. The kernel always sends the id as a query parameter (`Query` :173). The vendor `LIST` ignores an unknown one (measured: `?id=abc&name=x` answered 200).
- `src/OcuPilot/Port/AdminPort.cls` -- `MUTATINGTYPES` :302 and `BODYLESSTYPES` :318 lack `WebSession/DELETE`; today `Invoke` answers 501. The post-2xx block is :854 (`VERIFIEDDELETES` :348 and `VerifyGone` :1215 re-read with `GET`, which `WebSession` lacks). `Snippet` :2490 already routes `DELETE /web-session` (`AdminRoutes.cls:237`). `PROBEENDPOINT` :61 is already `WebSession`.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - Existing structure: `COVEREDTYPES` :250, the type guard :788, the per-type branches (`Process` :1694, `IsOcuPilotProcess` :1760), `Codes()` :470-473 (18 codes), `ReasonFor` :478-503, `ServesOcuPilot` :2871.
  - The port stubs `%session` (`AdminPort.cls:2012,2024`), so the request's own session id is read in `Prohibits` itself, before any port call.
- `src/OcuPilot/Kernel/Shell/Guardrails.cls:58-62` -- lists every code in `Codes()` with its sentence. A new code needs nothing more.
- `src/OcuPilot/Kernel/Governance/Baseline.cls:17-97` -- one `"<tool>": true` per key, in name order. `Test/GovernanceBaseline.cls:15`.
- `ui/src/app/core/self-protection.ts:39` `OCUPILOT_APPLICATION_PATHS` (pinned to the roster by `ui/tools/self-protection.test.mjs:40-51`), `:121-156` `selfProtectionReason` (`system-resource` reads `row`). The rule set is also listed in `Screen/Registry.cls:2530` `SELFPROTECTIONRULES` and `ui/tools/screen-mirror.mjs:313` `IMPLEMENTED_SELF_PROTECTION_RULES`; the build refuses a mismatch.
- `ui/src/app/shell/screen-action-handler.ts` -- `SCREEN_ACTION_DESCRIPTORS` :50-71, `DESTRUCTIVE_ACTIONS` :182, `DESTRUCTIVE_CONSEQUENCES` :202-221, `startFor` :486-557. A verb missing from :182 is sent with no dialog; one missing from :202 is not registered. `core/screen-actions.ts:72` `ACTION_LABELS`. The typed-name title is `verb + ' ' + target` (`typed-name-dialog.ts:144`).
- `ui/src/app/shell/list-page.ts` -- serves the screen with no per-screen Angular code. `data-table.ts:587-623` renders the row-target link.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- Fixed strings rows 254-585. The row for this story's strings is 357 (REST API explorer, the area's second entry); the Locks row at 376 is the model. Related lines: Dialogs :173, Self-protection refusals :220, Web sessions :134 and :167.
- `ui/src/app/core/strings.ts` -- append after :3380 under `// Story 16.2`, each key cited `/** EXPERIENCE.md:357 */`. Reuse "Process ID" (`processColumnPid`), "User" and "Application" (values are unique, `strings.test.mjs:710`).
- `src/OcuPilot/Test/ScreenRead.cls:180-240` -- the drift guard fails a `LIST` read that answers no row. CI's fresh instance has no sessions (measured: 0 rows on `ocupilot-ci` before any seeding). The OAuth tabs are the exclusion precedent.
- `src/OcuPilot/Test/Http.cls` `AbsoluteRequest` -- any path, with a supplied principal. `GET /api/atelier/` (`UseSession` 1) leaves a real session row, which is the seed for live tests.
- `ui/browser/process-actions.browser-spec.mjs` -- the model for the throwaway guard, recording sign-in, typed-name assertions and the row-leaves wait (:48-60, :120-136, :305-351). `token-revoke.browser-spec.mjs:174-199` is the model for the DW-1337 gate with a dialog open. Helpers: `list-spec.mjs`, `panel-spec.mjs`, `structural-walk.mjs`.

## Tasks & Acceptance

**Execution:**

**Server:**

- `src/OcuPilot/Kernel/EntityType.cls` -- add `web-session` to `TYPES`.
- `src/OcuPilot/Screen/Descriptor/WebSessionList.cls` -- new list descriptor, built from the Boundaries above:
  - route `web-applications/sessions`, `sideBarPosition` 3, `toolIdentifier` `webapp.sessions`, `labelKey` "Web sessions";
  - sort default `Application` ascending;
  - context fields `ID, Username, Application, SesProcessId, Timeout`, with no secret field;
  - `rowActions [{id: end, selfProtection: ocupilot-session}]`;
  - empty and agent-invitation keys, three suggested prompts, command aliases.
- `src/OcuPilot/Screen/Tool/Write.cls` + `Kernel/Proposal/Operation.cls` -- new `READROWKEYEXACT` (default 0). When it is 1, `ReadTarget` compares the row key exactly, read through a `ReadRowKeyExactOf` accessor, as `ReadRowKeyOf` is. Existing tools are unchanged.
- `src/OcuPilot/Screen/Tool/WebSessionEnd.cls` -- new tool `webapp.sessions.end`, modeled on `DeviceDelete`:
  - `READTYPE LIST`, `READROWKEY ID`, `READROWKEYEXACT 1`, `READANSWERS` as the vendor row;
  - `WRITETYPE DELETE`, `SENDSBODY 0`, `CHANGEACTION deleted`, `DESTRUCTIVE 1`;
  - `PRECONDITIONFIELD Application`, `FINGERPRINTSUBJECT Username,Application,Preserve,SesProcessId`, `REMOVALROWS Username,Application,SesProcessId,Timeout`;
  - `WRITERESOURCE %DB_IRISSYS` / `WRITE`;
  - `IdParam` `id`, `SCREENACTIONS` `end`, and an id description telling the model to copy the id exactly, case included.
- `src/OcuPilot/Port/AdminPort.cls` -- add `WebSession/DELETE` to `MUTATINGTYPES` and `BODYLESSTYPES`. Add `AWAITEDDELETES` (`WebSession/DELETE`, row key `ID`) with a private `AwaitGone`, called from the post-2xx block:
  - it polls `LIST` every 250 ms for up to 10 s (the named constants `AWAITEDDELETEMS` / `AWAITEDDELETEPOLLMS`), with an exact compare;
  - gone → OK;
  - past the bound → OK, and the fact is logged through `LogFault` with no session id in the text;
  - a failing `LIST` → OK: the vendor's own answer stands.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - add `OCUPILOTSESSION`, with `OCUPILOTSESSIONREASON` = the published sentence;
  - add an entry each to `Codes()`, `ReasonFor`, `COVEREDTYPES`, the type guard and a `WebSession` branch;
  - that branch's `IsOcuPilotSession(pTarget)` returns true for a `ServesOcuPilot` path, or for an `ID` equal to `%session.SessionId` when `%session` is an object; it fails closed on a missing `Application` or a roster fault.
- `src/OcuPilot/Screen/Registry.cls` :2530 + `ui/tools/screen-mirror.mjs` :313 -- add `ocupilot-session`.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` -- add `"webapp.sessions.end": true`.

**Client:**

- `ui/src/app/core/self-protection.ts` -- add `OCUPILOT_SESSION_RULE`, with a branch reading `row.Application` that answers `STRINGS.webSessionRefusalOcuPilot` and `''` for no row.
- `ui/src/app/shell/screen-action-handler.ts` + `ui/src/app/core/screen-actions.ts`:
  - register the descriptor;
  - make `end` destructive, with its consequence;
  - give it the label "End session".
- `ui/src/app/core/screens.generated.ts` -- regenerate through `screen-mirror.mjs`; never hand-edit it.
- `ui/src/app/core/strings.ts` + EXPERIENCE.md -- add these strings, folded into row 357 in place:
  - "Web sessions";
  - "Session";
  - "Expires (UTC)";
  - "No web sessions on this instance.";
  - the invitation "end a web session that is stuck or unwanted";
  - "End session";
  - the consequence "Ending this session discards what its application kept for it, and its next request starts a new session. This cannot be undone.";
  - the refusal "OcuPilot itself is running in this session. It cannot be ended from OcuPilot.";
  - the card noun "Web session";
  - three prompts.

  Two lines are edited in place: :173 gains "end web session" and :220 gains "a session OcuPilot is itself running in". Line count stays 993. Any shifted `/** EXPERIENCE.md:n */` citation is updated.

**Rosters (additive only):**

| File | Change |
|---|---|
| `Test/ReadTool.cls:93-94` | 130→132, plus both names |
| `Test/SurfaceCoverage.cls` | a screen row and a tool row |
| `Test/ToolRoundTrip.cls:38` | `webapp.sessions.end:TOOL.ARGUMENTS` |
| `Test/ToolWrite.cls:1195` | the two port entries |
| `Test/Descriptor.cls:1699` | 32→33 |
| `Test/Wire.cls:521` | the new entry |
| `Test/Prohibited.cls:218` | the `COVEREDTYPES` string |
| `Test/Prohibited.cls:672` | 18→19 |
| `Test/AuditingUpdate.cls:505` | 18→19 |
| `Test/RefusalCopy.cls` | the new code |
| `Test/ScreenRead.cls` | exclude `WebSessionList`, named with the OAuth tabs |
| `ui/tools/navigation.test.mjs` | :179, :211, :346-350 |
| `ui/tools/screen-actions.test.mjs:99-111` | the new label |
| `ui/tools/screen-mirror.test.mjs:961` | the new descriptor |
| `ui/tools/self-protection.test.mjs` | `KERNEL_REFUSALS` (:252-275) and cases for the new rule |
| `ui/tools/navigation-wire.test.mjs`, `ui/src/app/shell/rail-wire.spec.ts` | the captured payload |

**Tests:**

- `src/OcuPilot/Test/WebSessions.cls` (new, ≤500 lines) -- over canned reads:
  - the descriptor and tool declarations;
  - `StateDiff`;
  - the exact-case fresh read (a case twin is 404);
  - the mint fingerprint, and `PROPOSAL.TARGETCHANGED` when `Application` moves but not when `Timeout` moves;
  - the own-session arm, refused for each OcuPilot path spelling, permitted for `/api/atelier/` and `/csp/sys/`, and fail-closed on no `Application`.
- `src/OcuPilot/Test/WebSessionsLive.cls` (new) -- each test seeds its own `/api/atelier/` session through `AbsoluteRequest`, never a shared one, and covers:
  - the declared read fields held to the live row;
  - `AdminPort` `DELETE` + `AwaitGone`: the `LIST` lacks the id when `Invoke` returns, and an unknown id answers 404;
  - the screen-action route ends a seeded session (200, change event `deleted`, read-back gone);
  - a purpose-built role holding the screen's pairs without `%DB_IRISSYS:WRITE`, which is refused naming that pair with the session still listed. Never `%Operator` (Conventions).
- `ui/src/app/shell/screen-action-handler.spec.ts` + `list-page.spec.ts` -- cases against the Web sessions descriptor:
  - the End dialog title and consequence;
  - the synthetic `/api/ocupilot/` row drawn disabled with the sentence, sending nothing;
  - the Process cell linked for a row with `SesProcessId` and unlinked for "(none)".
- `ui/browser/web-sessions.browser-spec.mjs` (new) -- on the `-ci` throwaway:
  - seeding: an `/api/atelier/` session as `_SYSTEM` over HTTP, with its id read from the admin `LIST`;
  - the list: the row shows `_SYSTEM`, `/api/atelier/` and "(none)", and Web sessions is third in the Web applications side bar;
  - the dialog: the title "End session <id>", a mismatch sending nothing, and a match sending exactly one POST, after which the row leaves;
  - the DW-1337 structural gate, in both themes with the dialog open, with no new allowance;
  - the `after` hook ends every session the spec seeded.

**Acceptance Criteria:**

- Given sessions on the instance, when Web sessions loads, then each row shows its user, application and process, and a row carrying a process id links to that process's Process details.
- Given a session, when the person ends it and types its id, then the instance ends it, and the row leaves the list on the re-read that follows the write. The same write proposed by the agent ends it on Confirm.
- Given a session OcuPilot is itself running in (option A), when an end is attempted, then the row action is drawn disabled with the published sentence. The instance also refuses a screen action or a confirm with `PROHIBITED.OCUPILOTSESSION`, the kernel's reason is pinned equal to the sentence, and the Guardrails page lists the new code.
- Given a caller holding the screen's pairs but not `%DB_IRISSYS:WRITE`, when they end a session, then the refusal names that pair and the session is still listed.

## Spec Change Log

- 2026-09-28, spec gate (lead): AC3 amended in epics.md from "the user's **own** session" to "a session **OcuPilot is itself running in**" (Rule 5, apply-and-report: the AC's own reference is the process arm's shape, and the literal reading has no subject on this build). Option A taken; AD-8, AD-10, AD-15 and AD-53 amended in the spine; status reset `blocked` to `ready-for-dev`.

## Review Triage Log

### 2026-09-28 — Review pass

- verdicts: 15 findings — high 0, medium 0, low 10, false 5, maybe-false 0
- findings:
  - `[low]` `[patch]` `AwaitPort.LogFault` recorded the message and dropped the status text, so the no-session-id assertion saw half the logged line — it now records both, and the assertion covers the whole line.
  - `[low]` `[patch]` `IsOcuPilotSession`'s fail-closed branch on a roster fault was never exercised — added `Test/RosterFaultSet.cls` (one replaced seam, `ServesOcuPilot` failing) and a roster leg in `WebSessions`; mutation red in run 18246.
  - `[false]` `[reject]` `list-page.spec.ts`'s `page.bodies` check after the refused click cannot tell refused from offered — the refusal is pinned by the dialog-null, `aria-disabled` and reason assertions beside it; the bodies check is not the pin.
  - `[low]` `[reject]` two AC3 clauses (reason pinned to the sentence, Guardrails lists the code) have no `mutation:` line of their own — Rule 19 asks one per AC and AC3 carries them; the reviewer confirmed both tests redden when the code leaves `Codes()`/`ReasonFor`, and the fix is a spec edit only.
  - `[false]` `[reject]` the own-session refusal is proven only over canned rows — the intent's option A is defensive by ruling: no session under an OcuPilot application can be seeded, so canned rows and the synthetic client row are the intended surface.
  - `[low]` `[reject]` the slow-daemon row is tested in two pieces (the bounded wait, the present read-back), not one live 10 s path — a daemon slower than 10 s cannot be produced; each piece is pinned and the composition adds no new code.
  - `[low]` `[patch]` the session id reached a log line: a vendor 404 logs `ERROR #5907: Session ID '<id>' does not exist` (confirmed on `ocupilot-ci`), reachable when a session ends between the fresh read and the `DELETE` — added `AdminPort.UNLOGGEDQUERY` and `Unlogged`, masking the value before `Fail` logs; pinned in `WebSessionsLive`, mutation red in run 18247.
  - `[false]` `[reject]` no test reads the ledger `detail` of this tool's row — `Kernel.State.Ledger` has no `detail` property, and a failed write's logged reason is the normalized envelope text, which names no id.
  - `[false]` `[reject]` the typed-name dialog puts the id in its label and button as well as its title — the diff adds no DOM site: the shared dialog is unchanged, and the intent itself puts the id in the title and in the list's Session column.
  - `[low]` `[reject]` the no-write-pair refusal is not shown to precede the fresh read, and the agent path is not tested for a principal lacking the pair — the code checks pairs before the read (`ScreenAction.cls:245` vs `:255`) and the mint refuses through the same gate `DeviceDelete` pins; showing the order needs a port spy.
  - `[low]` `[reject]` "Moved" exercises only `Application` (409) and `Timeout` (allowed) — the subject is pinned exactly by the declaration test and `FingerprintSubjectProblem`, over the shared digest; per-field legs add no discriminating power.
  - `[false]` `[reject]` the Process link is tested only in jsdom — no preserve-mode session can be produced on the throwaway (Residuals); the link is the shared `rowTarget` path, clicked live by `locks.browser-spec.mjs`.
  - `[low]` `[patch]` "No `AllowEndSession` refusal" was held by absent code, every canned row carrying `true` — the `/csp/sys/` leg now carries `false`, as the vendor answers, and stays permitted.
  - `[low]` `[reject]` the area holder's rendered "Requires %Admin_Operate" is not tested for this screen — that rendering is the shared per-screen gate; this screen's navigation verdict and read refusal are pinned live.
  - `[low]` `[reject]` the agent end is tested in-process, not over the tool-call wire — the wire is shared dispatch, and `ToolRoundTrip` pins this tool's schema refusal.

## Design Notes

**Ruling (lead, spec gate 2026-09-28): option A.** AC3 now reads "a session OcuPilot is itself running in" (epics.md, Rule 5 apply-and-report), and AD-10 carries the arm. The plan halted because "the user's **own** session" has no subject on this build:

- **No session row is OcuPilot's.** All three OcuPilot applications are `UseSession` 0 with JWT. Sign-in, `GET /api/ocupilot/instance` and the admin `LIST` request itself each left zero rows in `%CSP.Session:SessionInfo` (measured on `ocupilot-ci`).
- **One cannot be seeded either.** `%CSP.Session.SetContext` and the `Application` setter are private, so a test cannot create a row under an OcuPilot path.
- **Ending a portal session does not sign that browser out.** Its group record survives, and the next portal request re-created the session.

Three readings give observably different outcomes:

- **(A) Recommended, and the one this spec is written to.** A session OcuPilot is itself running in: one under an application `ServesOcuPilot` names, or the serving request's own session. The arm is defensive. It is proven over canned reads and a synthetic client row, never on a live row.
- **(B)** Every session whose `Username` is the signed-in user, as the Users list's signed-in-account rule works. This is testable live. But on a single-administrator instance (every session `_SYSTEM`'s) it refuses every End, and it contradicts the process arm's narrowing of 2026-09-22.
- **(C)** (A), plus the vendor's `AllowEndSession` false rows (`/csp/sys/` and preserve-mode sessions). The classic page enforces these in its UI only, and the admin API ends them anyway (measured: 200).

The AC's own reference, the process arm as narrowed on 2026-09-22, is (A). (B) would refuse every End on a single-administrator instance, and (C)'s rows are ones the admin API ends and the owner's "developer tool first" direction permits.

**Measured on `ocupilot-ci`, 2026-09-28:**

- **The endpoint.** `%Api.Admin.Endpoints.WebSession`: `ResourcesOR` `%Admin_Operate`; `LIST` over `%CSP.Session:SessionInfo`; `DELETE ?id` answering 404 `#5907` for an unknown id and otherwise calling `$$DeleteSession^%SYS.cspServer`. There is no GET (405). Both are synchronous.
- **Pairs.** `LIST` through the port needs `%Admin_Operate:U` and `%DB_IRISSYS:R`. `DELETE` also needs `%DB_IRISSYS:W`. `%Admin_Secure` does not stand in for `%Admin_Operate`.
- **Removal.** The row stays listed until the daemon removes it, 1.65–4.09 s later over five trials.
- **Rows.** `SesProcessId` was empty on every Preserve-0 row.
- **Audit.** Ending a session wrote no audit row, with auditing on.
- **The classic page** (`irissys/%CSP/UI/Portal/CSPSessions.cls`) declares `RESOURCE %Admin_Operate`, stays in `%SYS`, and ends a session through the same routine.

**The spine cases this story names** (recorded by the lead at the spec gate, Rule 20):

- **AD-8:** Web sessions' own pair (`%Admin_Operate:USE`), and the end tool's `%DB_IRISSYS:WRITE` under the write-tool clause.
- **AD-10:** the own-session arm.
- **AD-53 named gap, and AD-15's no-vendor-event case:** ending a session leaves no vendor audit row, so a screen end is unrecorded in the audit database, and the agent's marker is the only record of an agent end.

No AD-27 case is needed. The `AdminPort` wait is `DELETE` verification on AD-26's synchronous path, like `VERIFIEDDELETES`.

**Placement.** EXPERIENCE.md :134 and :167 and the epic context put Web sessions in the Web applications side bar. The dispatch's "OS management" is not what the UX spine says.

**The session id is shown and sent to the model.** The classic page and the admin API show it too. It is not a credential: measured on `ocupilot-ci` by the lead, the session cookie is a prefix, the 10-character id and a key, and the id alone as the cookie answered 401 while the full cookie answered 200.

**Governing ADs:** AD-2, AD-5, AD-6, AD-8, AD-10, AD-13, AD-14, AD-15, AD-22, AD-24, AD-26, AD-27, AD-29, AD-34, AD-36, AD-43, AD-44, AD-51, AD-52, AD-53, AD-58, AD-59.

**Integration ACs:** the new read and tool are consumed in this story by the list page, the screen-action route and the agent. The browser spec and `WebSessionsLive` exercise each against the instance. **Consumes:** `AdminPort`, `Prohibited.ServesOcuPilot`, the shared row target (Story 6.10) and the typed-name dialog. **Consumed-by:** none planned. Story 16.6's multi-select is Processes'.

**Declined DW-1725:** fixed ahead of this story by the lead in ef90e7f4 (orchestrator re-own); the lead resolves it against that commit.

**Contended files, touched add-only:** `strings.ts`, EXPERIENCE.md (in place), `Baseline.cls`, and the exact-count rosters listed above. `Api/Router.cls`, `Api/Error.cls`, `_components.scss` and `PathPort.cls` are not touched.

**Residuals:**

- **Process link not proven live.** No preserve-mode session (the only kind with a process) could be produced on the throwaway without compiling a CSP page. The Process link is therefore pinned at the component tier, and the shared click is `locks.browser-spec.mjs`'s.
- **Slow daemon.** If the daemon takes longer than 10 s, the ended row stays listed until the next read.

## Verification

**Commands:**

- `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/1518373f-040c-4be6-a814-a27bfbff2961/scratchpad/epic-16/compile.sh <changed paths>` after `rsync -a --delete src/ /tmp/ocupilot-ci/src/`, then `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class <C>`, one class per call, for `WebSessions`, `WebSessionsLive`, `Prohibited`, `RefusalCopy`, `ReadTool`, `SurfaceCoverage`, `Descriptor`, `Wire`, `ToolWrite`, `ToolRoundTrip`, `ScreenRead`, `GovernanceBaseline`, `Guardrails`, `AuditingUpdate` (loop) -- expected: green. Planned mutations:
  - drop the own-session branch → the `WebSessions` own-arm cases red;
  - restore `ReadTarget`'s case fold for the tool → the case-twin case red;
  - skip `AwaitGone` → `WebSessionsLive`'s "`LIST` lacks the id when `Invoke` returns" red;
  - drop `WRITERESOURCE` → the least-privilege case red;
  - add `Timeout` to the subject → the Timeout-moves case red.
- `cd ui && npm run test:tools && npx ng test --include src/app/shell/screen-action-handler.spec.ts --include src/app/shell/list-page.spec.ts` (loop) -- expected: green. Planned mutations: drop the `ocupilot-session` branch → the self-protection and handler disabled-row cases red; remove `end` from `DESTRUCTIVE_ACTIONS` → the dialog case red.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/ && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/web-sessions.browser-spec.mjs` (loop) -- expected: green. Planned mutation: skip the port's wait, then rebuild and redeploy → the row-leaves wait fails.
- `cd ui && npm test` (once, before dev_complete) -- expected: green, with the bundle under `maximumWarning` 2107kB.
- The full ObjectScript sweep on `ocupilot-ci`, one class at a time (once, before dev_complete) -- expected: green apart from the known residue (13 arming refusals, `WireSecurityRead`'s task history, DW-1759's 29). The full browser suite is CI's.

**Mutations (Rule 19, each observed red and reverted with the tree byte-identical):**

- AC1: mutation: drop `rowTarget` from `WebSessionList.cls` and regenerate the mirror → `list-page.spec.ts` "links the Process cell of a row carrying a process to Process details" red (the href named the session's own route).
- AC1: mutation: drop `ownPrivileges` from `WebSessionList.cls` → `WebSessions.TestTheDescriptorDeclaresTheListItsPairsAndItsRowAction` red.
- AC2: mutation: skip `AwaitGone` in `AdminPort.InvokeLocated` → `WebSessionsLive.TestThePortReturnsOnceTheSessionIsGone` red ("the list no longer carries it"), with the screen-action and agent-confirm legs, and `web-sessions.browser-spec.mjs` AC2's row-leaves wait timed out.
- AC2: mutation: remove `end` from `DESTRUCTIVE_ACTIONS` → `screen-action-handler.spec.ts` "registers End session, opening the typed-name dialog" and the `list-page.spec.ts` End session case red.
- AC2: mutation: set `WebSessionEnd.READROWKEYEXACT` to 0 → `WebSessions.TestTheFreshReadComparesTheIdExactly` red (case twin found; of two twins the first row read).
- AC2: mutation: add `Timeout` to `WebSessionEnd.FINGERPRINTSUBJECT` → `WebSessions.TestTheFingerprintCoversTheApplicationAndNotTheExpiry` red (409 on a moved expiry).
- AC3: mutation: make `Prohibited.WebSession` skip `IsOcuPilotSession` → `WebSessions.TestTheSetRefusesASessionOcuPilotIsRunningIn` and `TestBothCallersAreRefusedForOcuPilotsOwnSession` red (route 200, confirm applied).
- AC3: mutation: answer `''` from the `ocupilot-session` branch of `selfProtectionReason` → `self-protection.test.mjs` Story 16.2 case, `screen-action-handler.spec.ts` "draws a session under OcuPilot's own application refused" and the `list-page.spec.ts` refused-entry case red.
- AC4: mutation: make `WebSessionEnd.PrivilegePairs` answer the list's pairs alone → `WebSessionsLive.TestAPrincipalWithoutTheWritePairIsRefusedByName` red (the vendor refused inside the port, not by the named pair).
- Label: mutation: drop the `WebSessionList` entry from `DESCRIPTOR_ACTION_LABELS` → `screen-actions.test.mjs` "a screen's row action draws its own published words" red.
- Slow daemon (matrix): mutation: make `AdminPort.AwaitGone` read the list once and return (its deadline check replaced by `Quit`), recompiled with `Test/AwaitPort.cls` → `WebSessions.TestTheWaitForTheDaemonIsBoundedAndNeverFailsTheWrite` red (run 18223).
- AC3 (fails closed): mutation: `IsOcuPilotSession` answers 0 on a roster fault → `WebSessions.TestTheSetRefusesASessionOcuPilotIsRunningIn` roster leg red through `Test/RosterFaultSet.cls` (run 18246).
- Never (no id in a log line): mutation: empty `AdminPort.UNLOGGEDQUERY` → `WebSessionsLive.TestThePortReturnsOnceTheSessionIsGone` log leg red, the line quoting `ERROR #5907: Session ID 'OcuNoSessn'` (run 18247).

## Auto Run Result

Status: done
Blocking condition: none

Implemented (implement stage, 2026-09-28): the Web sessions list (third Web applications entry, `WebSession` `LIST`, Process cell linked to Process details) and `webapp.sessions.end` (bodyless `DELETE`, exact-case fresh read through the new `READROWKEYEXACT`, `%DB_IRISSYS:WRITE` declared, destructive typed-name confirm), `AdminPort`'s bounded wait for the vendor's daemon (`AWAITEDDELETES`, `AwaitGone`), the `PROHIBITED.OCUPILOTSESSION` arm and its client rule `ocupilot-session`, the governance key, and the copy. The plan's option-A ruling is in the Spec Change Log.

Files:

- `src/OcuPilot/Screen/Descriptor/WebSessionList.cls`, `Screen/Tool/WebSessionEnd.cls` -- the new descriptor and end tool.
- `Kernel/EntityType.cls`, `Kernel/Governance/Baseline.cls`, `Screen/Registry.cls` -- `web-session`, the enabled key, the `ocupilot-session` rule (each appended).
- `Screen/Tool/Write.cls`, `Kernel/Proposal/Operation.cls` -- `READROWKEYEXACT` and `ReadRowKeyExactOf`; every other tool still folds case.
- `Port/AdminPort.cls` -- `WebSession/DELETE` appended to `MUTATINGTYPES`/`BODYLESSTYPES`; `AWAITEDDELETES`, `AwaitGone`; `UNLOGGEDQUERY`, `Unlogged` (review patch: a vendor 404 quoted the session id into the log).
- `Kernel/Proposal/Prohibited.cls` -- the code, its sentence, the covered type, the `WebSession` branch, `IsOcuPilotSession`, `ServingSessionId`.
- Tests: new `Test/WebSessions.cls`, `WebSessionsLive.cls`, `WebSessionActionFixture.cls`, `AwaitPort.cls`, `RosterFaultSet.cls`; roster bumps in `AuditingUpdate`, `Descriptor`, `PortFixture`, `Prohibited`, `ReadTool`, `RefusalCopy`, `ScreenRead`, `SurfaceCoverage`, `ToolRoundTrip`, `Wire`, `WireSecurityRead`.
- Client: `core/self-protection.ts`, `screen-actions.ts`, `strings.ts`, regenerated `screens.generated.ts`; `shell/screen-action-handler.ts`; specs `list-page`, `rail-wire`, `screen-action-handler`; tools `navigation`, `navigation-wire`, `screen-actions`, `screen-mirror` (+ test), `self-protection` test; new `ui/browser/web-sessions.browser-spec.mjs`.
- `EXPERIENCE.md` rows 173, 220, 357 in place (993 lines); `scripts/ci-throwaway.sh` one `# classes:` comment under the existing `OCUPILOT_ALLOW_PRINCIPALS`.

Review: 15 findings (two layers) -- 4 low patched (the await fixture's log stub, the roster-fault leg, the session id masked in the port's vendor-fault log, a realistic `AllowEndSession` false row), 6 low rejected and 5 false, each with its reason in the Review Triage Log; nothing deferred. Follow-up review: not recommended (patched: high 0, medium 0, low 4).

Verification:

- Matrix audit: two rows lacked a covering test and gained one -- Empty (`list-page.spec.ts`) and Slow daemon (`WebSessions.TestTheWaitForTheDaemonIsBoundedAndNeverFailsTheWrite` over `Test/AwaitPort.cls`, plus the present read-back leg). Every row now has a test that ran green.
- ObjectScript on `ocupilot-ci`, one class at a time, after the review patches: `WebSessions` 8/8, `WebSessionsLive` 6/6, `Prohibited`, `RefusalCopy`, `ReadTool`, `SurfaceCoverage`, `Descriptor`, `Wire`, `ToolWrite`, `ToolRoundTrip`, `ScreenRead`, `GovernanceBaseline`, `Guardrails`, `AdminPortFault`, `AdminPortSync`, `X509Import` green; `WireSecurityRead` fails only its task-history test (residue); `AuditingUpdate` refuses on `OCUPILOT_ALLOW_AUDIT_TOGGLE` (residue), so its 18-to-19 bump is CI's to prove.
- Full ObjectScript sweep (once, handoff stage, before the review patches): 340 classes offered (338 in the checkout), 2,650 tests. Residue named: 19 classes refused on arming variables (`InjectionCompromised` among them; the lead's list says 13 -- this story adds no variable); `WireSecurityRead`'s task-history test (DW-1425/DW-1468); `TaskHistory` 3 tests on the demo task having no recorded runs (not on the lead's list; the diff touches no task code, so throwaway state (inference)); DW-1759's 29 did not appear. The sweep's three `WireSecurityRead` Web applications roster failures were this story's and were fixed and re-run green.
- Client: `npm run test:tools` 1684/1684; `screen-action-handler.spec.ts` + `list-page.spec.ts` 75/75; `npm test` green at the handoff (1,684 tool + 1,697 component tests).
- Browser: `web-sessions.browser-spec.mjs` 2/2 on the rebuilt, redeployed bundle, after the patches, with the DW-1337 walk in both themes and the dialog open, no new allowance.
- Bundle (last `npm run build`): initial total 2.05 MB (359.15 kB transfer), under `maximumWarning` 2107kB.
- Mutations: the handoff reports each of its lines in `## Verification` observed red and reverted byte-identical; this stage observed its three added lines red (runs 18223, 18246, 18247) and reverted byte-identical.

Footprint extensions (outside the listed trees): `src/OcuPilot/Kernel/EntityType.cls`, `src/OcuPilot/Kernel/Governance/Baseline.cls`, `scripts/ci-throwaway.sh`, `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`.

Residual risks: the own-session arm has no live subject on this build (option A, proven over canned rows); a daemon slower than 10 s leaves the ended row listed until the next read; the Process link is pinned at the component tier only.

Planned (plan stage, 2026-09-28): the full spec for option A, from three investigations (server conventions, client conventions, instance measurement on ocupilot-ci) and four direct probes (the WebSession class source, a LIST with unknown query parameters, the vendor audit trail after an end, seeding a synthetic session). Everything created on ocupilot-ci was removed; the one extra /api/atelier/ session this stage opened was ended by its own probe.
