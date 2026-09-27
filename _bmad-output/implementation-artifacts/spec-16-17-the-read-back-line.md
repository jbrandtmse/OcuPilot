---
title: 'Story 16.17: The read-back line'
type: 'feature'
created: '2026-09-26'
status: 'done'
baseline_revision: '003d8c985b66ca0bb5983c40a233dc3e2b830c6f'
baseline_commit: '003d8c985b66ca0bb5983c40a233dc3e2b830c6f'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A role's Resources grant sent with Permissions "WR" (or members in another order) reads back as "differs in Resources".
    evidence: |-
      `unordered` compares each element's whole Mint.Display JSON; the vendor stores "WR" as "RW" (measured in Design Notes). The closed top-level vocabulary has no nested mode, so the declaration cannot express it. Settle by an agent role update granting "WR" on ocupilot-ci.
    location: >-
      src/OcuPilot/Kernel/Proposal/ReadBack.cls SameMultiset; Screen/Tool/Classification.cls permissions.roles.*
    severity: medium
---

<intent-contract>

## Intent

**Problem:** A confirmed write is reported as done once the vendor answers OK. Neither the agent's proposal card nor a screen's own action or Save says whether the instance now holds what was sent, so a person re-opens the record to check.

**Approach:** After every write that reads OK, from either caller, the instance re-reads the target through the tool's own port and read type and compares it with what the write sent. The comparison uses a per-field mode declared in the tool's reviewed Classification entry. The success answer carries a `readBack` verdict, which reaches the proposal card's closing line, the marked row (through the change event), and a form's "Saved" line.

## Boundaries & Constraints

**Always:**

- **The comparison runs on the instance, in one kernel class** (`Kernel/Proposal/ReadBack.cls`). It is called by the agent's confirm, by `Api/ScreenAction`, and by every screen Save route that writes an instance object (AD-53, AD-55).
  - The re-read uses the tool's declared port, read type, read id param and row key, with the caller's own privileges. It reuses `Operation.ReadAt`, so a list-type read resolves exactly as the mint's does.
  - It runs after the write reads OK, after the ledger row and the marker. It runs outside any transaction and holds no lock.
  - The verdict never fails, delays or alters the write's own answer.
- **Wire shape:** `readBack: {verdict, fields, written, reason?}`.
  - `verdict` is one of `matches | differs | notFound | present | written | nothingSent | unchecked`.
  - `fields` holds the names that differ. `written` holds the secret names sent. `reason` is `running | unreadable` on `unchecked`.
  - Names only. **No read or sent value ever enters the answer, a log line or the proposal row** (AD-35). A secret's read value is never examined.
- **What each kind compares** (kind derived from the tool's parameters, never hand-set):

  | Kind | Compared set | 404 on re-read | Present on re-read |
  |---|---|---|---|
  | Merge (`SENDSBODY` 1, not `CREATES`), including screen-action deltas and Saves | Every top-level key of the body sent that the tool's `ToolFields` rows name. The descriptor's `fingerprintExcludes` are skipped. Secret-class keys join `written` when their sent value is non-empty and differs from the fresh read's. | `notFound` | `matches` or `differs` |
  | Create (`CREATES`, AD-54) | As merge, with an empty fresh read. The re-read is by the created id (`createdId` where the tool answers one). | `notFound` | `matches` or `differs` |
  | Delete (`CHANGEACTION` `deleted`) | Absence | `notFound`, the expected result | `present`, unless the tool's `ReadBackGone` says gone |
  | Action-style (`SENDSBODY` 0, no `SECRETBODY`) | Nothing: it sends no value (AD-51) | `notFound` | `nothingSent` |
  | Secret-only (`SECRETBODY`, AD-56 (i)) | Nothing: its body is secrets | `notFound` | `written` (the names) |

  A write the port answered 202 (AD-26 `continues`) is `unchecked` with reason `running`, and no re-read is made. A re-read failing other than with 404 is `unchecked` with reason `unreadable`. When `written` is non-empty on a `matches` or `differs`, it is listed too.
- **Default comparison of one field:**
  - Both sides empty (`""`, `[]`, `{}`, `null`, absent) are equal.
  - Where either side's JSON type is boolean, compare truthiness (`true`/`1`/`"1"`/`"true"` against `false`/`0`/`"0"`/`"false"`/`""`).
  - Where both are valid numbers, compare by value (measured: `"0900"` read back as `900`).
  - Otherwise compare `Mint.Display` text (arrays keep their order).
- **Declared comparison modes** live in `Classification.cls` as a new per-entry key `compare: {<top-level path>: <mode>}`. The generator validates them and emits them onto the `ToolFields` rows (AD-3). There is no second list, and no mode in a descriptor, the client or a port. The closed vocabulary:
  - `unordered`: an array compared as a multiset of its elements' `Display`.
  - `unslashed`: one trailing `/` dropped on both sides.
  - `words`: whitespace collapsed.
  - `letters`: compared as a set of upper-cased letters.
  - `members`: an object compared on the members sent, with empty equal to absent.
  - `written`: reported written and never read back.

  `field-lists.mjs` refuses:
  - an unknown mode;
  - a path that is not a top-level row of the entry's list;
  - a mode on a `secret` path;
  - `unordered` on a non-array;
  - `members` on a non-object.
- **Declarations this story makes:**
  - Measured on `ocupilot-ci`, 2026-09-26, or cited:
    - `Roles: unordered` on `permissions.users.update` and `.create`. The vendor sorts roles: `[%SQL,%Developer,%Operator]` reads back `[%Developer,%Operator,%SQL]`.
    - `GrantedRoles: unordered` on `permissions.roles.update` and `.create`. The vendor sorted `[%Operator,%Developer]`.
    - `PublicPermission: letters` on `permissions.resources.update` and `.create`: `"WR"` reads back `"RW"`.
    - On `security.oauthclients.update` and `.create`: `RedirectionEndpoint: unslashed`, `DefaultScope: words` and `Metadata: members` (`Port/OAuthClientPort.cls:224-274,396,402`, Story 12.5).
    - `Metadata: members` on the `update`/`create` tools of `security.oauthserverdescriptions`, `security.oauthserver` and `security.oauthserverclients` (AD-4's measured member merge).
    - `Settings: written` on `tasks.schedule.update` and `.create`: a secret-typed setting is never read (AD-4, AD-35).
  - To measure in this story, declared only if the vendor reorders:
    - `Resources` on `permissions.roles.*`: two grants sent in reverse name order.
    - `CorsAllowlist`: measured order-preserving, so it is not declared.
- **Copy:** one row appended at the end of EXPERIENCE.md's Fixed strings table (line 575). The keys are appended to `strings.ts` citing `:575`. The copy is written in Design Notes and copied verbatim.
- **Where each verdict renders:**
  - On the agent card: a line under the status line.
  - On a marked list row: after the "Changed" tag, and in that row's polite announcement.
  - On a form's Save status: "Saved · <line>".
  - A delete's `notFound` has no row to sit on, because the row leaves (AD-14). The card still says it. A `present` delete keeps its row, marked with the line.
- **The proposal row persists the verdict** as `ReadBack`, and the proposal wire row carries `readBack` (`null` until recorded), so a card reloaded after confirm is never a silent success. Recording failure is logged and never propagated.

**Never:**

- No comparison in the browser: the client renders the server's verdict only.
- No change to the ledger (`Kernel/State/Ledger.cls` is contended; AD-41 is unchanged).
- No change to governance (`Kernel/Governance/Gate.cls`), `Api/Router.cls`, `Port/AdminPort.cls`, `Screen/Tool/AuditingUpdate.cls`, or `ui/browser/structural-baseline.json`.
- No change to `proposal-card.ts` lines 662-672 (Epic 23's `destructive` doc comment), and no edit of `proposal-card.spec.ts`.
- No new route. No re-attempt of a write. No row data patched from the verdict (AD-14).
- Agent definitions and switches are OcuPilot's own state, not instance writes, so they get no read-back.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Merge, all equal | web app update via confirm or Save; `Timeout:"0900"`, `Enabled:0` | `matches`; card line, row line and "Saved · Read back: matches" | none |
| Normalized list | role update, `GrantedRoles` sent reversed | `matches` (declared `unordered`) | none |
| Vendor changed a value | re-read answers a different `Description` | `differs`, fields `[Description]` | none |
| Target gone | update whose re-read is 404 | `notFound` | none |
| Delete | web app delete (either caller) | `notFound`; the row leaves and the card says "Read back: not found" | none |
| Delete not gone | delete whose re-read still answers | `present`; the row stays marked "Read back: still present" | none |
| Error-log delete | `logs.applicationerrors.delete` | `notFound` when none of the enumerated ids (id+Time) re-enumerate (`ReadBackGone`) | none |
| Secret sent | user password; or a merge carrying a supplied secret | `written`, `[Password]`; a merge appends "· … written, not read back" | read value never examined |
| Action | task suspend, process resume, task run | `nothingSent` | none |
| Queued | audit copy answered 202 | `unchecked` / `running`; no re-read | none |
| Re-read refused | re-read answers 403 or 500 | `unchecked` / `unreadable` | the write's answer is unchanged |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/Proposal/Operation.cls` -- `ReadAt`/`ReadTarget` (the read to reuse), `ApplyAt` (`AfterWrite` runs inside it, before the read-back), and the `SendsBody`/`WriteType` accessors.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls:357-436` -- body built at 358-365 (`tBody`, `tFresh` empty for a create, `tIdValue` the caller's spelling); success arm 409-425; `Answer` 751-776 (`auditMarked`, `action`, `createdId`); `continues` 436.
- `src/OcuPilot/Api/ScreenAction.cls:166-293` -- `Run`: `tPayload`/`tFresh` in scope after `Operation.Apply` at 266; answer 281-288.
- Screen Save handlers write through `Port.Invoke` directly and answer `{name}` or similar:
  - `Area/WebApp/{WebAppSave,Create}`
  - `Area/Permissions/{ResourceSave,RoleCreate,RoleSave,ServiceSave,UserCreate,UserSave}`
  - `Area/Security/{LdapSave,AuditEventSave,SslSave,X509Save,WalletSave,OAuthClientSave,OAuthServerSave,OAuthResourceServerSave,OAuthAuthorizationServerSave,OAuthRegisteredClientSave}`
  - `Area/OsMgmt/DeviceSave`
  - `Area/Task/TaskSave`

  Each already names its tool, its body local and, on update, its fresh read.
- `src/OcuPilot/Kernel/Proposal/Mint.cls:837` `Display` -- the one value renderer. `Disclosure.cls:148` and `Fingerprint.cls:20` show how `ToolFields` rows are read by tool name.
- `src/OcuPilot/Screen/Tool/Write.cls` -- parameters `CREATES` :141, `CHANGEACTION` :124, `SENDSBODY` :67, `SECRETBODY` :191, `DESCRIPTORCLASS` :38; `CreatedId` :327. Add `ReadBackGone` here.
- `src/OcuPilot/Screen/Tool/ErrorDelete.cls` -- `READTYPE` `ENUMERATE`, subject `namespace,entries`: overrides `ReadBackGone`.
- `src/OcuPilot/Screen/Tool/Classification.cls` -- grammar :6-20; entries such as `permissions.users.update` :120-140, `permissions.roles.update` :302, `permissions.resources.update` :319. `ToolFields.cls` is generated.
- `ui/tools/field-lists.mjs` -- `ENTRY_KEYS` :55, `classify` :220, row emission :273, `--check` :390; `ui/tools/field-lists.test.mjs`.
- `src/OcuPilot/Kernel/State/Propose.cls` -- `ConfirmedAt` :146, values :628, wire :677; `Test/ProposalWire.cls:28` `WIREKEYS`.
- Client:
  - `core/turn.ts` -- `ProposalOutcome` :326-361; confirm read :1162-1175; publish :1188-1195.
  - `shell/panel.ts` -- `recordWriteCard` :1258-1273; `PanelProposalView` :168-174.
  - `shell/proposal-card.ts` -- inputs :357-373; status template :276-296.
  - `core/change-bus.ts` -- `ChangeEvent` :49-80, `publish` :136-161.
  - `core/refresh.ts:607-622`.
  - `core/screen-store.ts` -- :105-106, :323-345.
  - `shell/data-table.ts` -- tag :349-351, `announceChanged` :1504-1518.
  - `shell/screen-action-handler.ts` -- answer :282-287, publish :645-690.
  - `core/reduced-form.store.ts:351-375`, plus the 17 editor stores that publish their own `'updated'`/`'created'` events. The Saved spans in their pages use `STRINGS.formSaved`.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Proposal/ReadBack.cls` -- new. `Of(pToolClass, pIdValue, pSent, pFresh, pPayloadJson, pPort = "") As %DynamicObject`:
  - the kind table;
  - the default comparison and the declared modes;
  - the rule that no value is returned;
  - a `Compare` helper that the unit tests reach.
- `src/OcuPilot/Screen/Tool/Write.cls` and `ErrorDelete.cls` -- add `ReadBackGone(pAfter, pPayload) As %Boolean` (default 0). ErrorDelete answers gone when no stored entry re-enumerates.
- `Kernel/Proposal/Confirm.cls` -- call `ReadBack.Of` on the success arm after `RecordMarking`, or answer `unchecked`/`running` on 202. Add `readBack` to `Answer`, and record it through `Propose`.
- `Kernel/State/Propose.cls` -- add property `ReadBack` and a guarded `RecordReadBack`, and put `readBack` on the wire row (`null` when empty). Adding the property is not a `SCHEMAVERSION` change, because old rows read empty; note that at the property.
- `Api/ScreenAction.cls` and every Save handler named in the Code Map -- add `readBack` to the success answer.
- `Screen/Tool/Classification.cls`, `ui/tools/field-lists.mjs` and regenerated `ToolFields.cls` -- the `compare` key, its refusals, and the declarations above. Measure `Resources` first.
- Client:
  - new `core/read-back.ts`: `readBackOf(unknown)`, which answers `null` for anything outside the vocabulary; `readBackLine`; `savedLine`.
  - `readBack` carried through `change-bus`, `screen-store`, `refresh`, `data-table`, `screen-action-handler`, `turn`, `panel` and `proposal-card`.
  - each form store keeps the answer's `readBack`, puts it on its publish and exposes `readBack()`.
  - each form page renders `savedLine(...)` where it rendered `formSaved`.
- `strings.ts`, EXPERIENCE.md (append a row at 575) and `_components.scss` (append at the end, tokens only).
- Tests:
  - new `Test/ReadBack.cls`: the unit table over the modes, the kinds and the default rules, through a stub port.
  - new `Test/ReadBackRoute.cls`: HTTP on `ocupilot-ci`, covering the confirm, the ScreenAction delete, the web-app Save, and the role update.
  - `Test/ProposalWire.cls`: `WIREKEYS` plus `readBack`.
  - `ui/tools/read-back.test.mjs` and `field-lists.test.mjs`.
  - component specs: new `shell/proposal-card-read-back.spec.ts`, plus cases in `data-table.spec.ts`, `screen-action-handler.spec.ts` and `web-app-editor.page.spec.ts`.
  - new `ui/browser/read-back.browser-spec.mjs`.

**Acceptance Criteria:**

- Given a confirmed write from the agent's proposal, a row action, or an editor Save, when the list showing that entity refreshes and marks the row, then the row carries the server's read-back line. The card's closing line and the form's "Saved" line say the same.
- Given a re-read value different from the sent one on a field with no declared mode, or a re-read of 404 after an update, then the line reads "Read back: differs in <fields>" or "Read back: not found", never "matches" and never nothing.
- Given a field declared `unordered` (`GrantedRoles`), when the vendor returns it reordered, then it reads back as matching, and removing the declaration makes the same write read "differs in GrantedRoles".
- Given a write carrying a secret, then the line names it "written, not read back", and the read-back never examines its read value.
- Given the web applications list open, the integration consumer, when a web application is enabled by its row action on `ocupilot-ci`, then the row shows "Read back: matches" in both themes and passes the DW-1337 structural gate with no new allowance.

### Review Findings

Code review 2026-09-26 (full-opus: blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor). 1 high, 5 medium, 13 low survived triage; every patch applied.

- [x] [Review][Patch] **High (AD-58 fail-closed):** a read-back that compared no field read `matches` -- every sent name skipped (unnamed, excluded, or absent from a list row) left `Compared` answering 1. `Compared` now counts compared names (a list row's own key is not counted) and `Of` answers `unchecked`, or `written` when only secrets were sent [src/OcuPilot/Kernel/Proposal/ReadBack.cls:125]
- [x] [Review][Patch] DW-1709: a role grant sent `"WR"` (stored `"RW"`) or with its members reordered read "differs in Resources" -- an `unordered` array's element member may now declare a text mode (`Resources[].Permissions: letters`), validated by `field-lists.mjs`, emitted on that row alone; object elements compare by sorted non-empty members [src/OcuPilot/Kernel/Proposal/ReadBack.cls:ElementText, ui/tools/field-lists.mjs:322]
- [x] [Review][Patch] An editor opened by a create showed an earlier Save's verdict, or none -- `reset()` clears the read-back and `arriveSaved` carries the create's [ui/src/app/areas/web-applications/web-app-editor.store.ts:458, role-editor.store.ts, user-editor.store.ts, the three create pages]
- [x] [Review][Patch] Four OAuth editors dropped the read-back line when a follow-up secret write was refused -- the refusal keeps the line beside it [ui/src/app/areas/security/oauth-client-form.page.ts:608 and three siblings]
- [x] [Review][Patch] OAuth Saves never named the secrets they store by their own writes -- `ForSave` takes the landed names (`WithWritten`) from all five OAuth Saves [src/OcuPilot/Kernel/Proposal/ReadBack.cls:ForSave, src/OcuPilot/Area/Security/OAuth*Save.cls]
- [x] [Review][Patch] Comments said a list-row create re-reads by the allocated id; it re-reads by name [src/OcuPilot/Area/Task/TaskSave.cls:159, OAuthRegisteredClientSave.cls:86]
- [x] [Review][Patch] `ReadBackGone` sat between `PortQuery` and its doc comment, and named `Time` for `time` [src/OcuPilot/Screen/Tool/ErrorDelete.cls:214]
- [x] [Review][Patch] A `written`-mode object sent empty was listed written [src/OcuPilot/Kernel/Proposal/ReadBack.cls:Compared]
- [x] [Review][Patch] A row's clipped read-back line had no way to read the rest -- it carries its text as `title` [ui/src/app/shell/data-table.ts:355]
- [x] [Review][Patch] `field-lists.mjs` accepted a text mode on an array or object row -- refused [ui/tools/field-lists.mjs]
- [x] [Review][Patch] AC4's written clause had no `mutation:` line -- demonstrated and recorded under Verification
- [x] [Review][Patch] Save-route verdicts were pinned on few routes and `field-lists.test.mjs` pinned five declarations -- every committed declaration is now pinned; verdicts added on the role update (`"WR"`), the OAuth resource server create (`written`), and the web app, role and user create editors (browser). The remaining routes are DW-1711 (wontfix-accepted)
- [x] [Review][Defer] A list-row create reads `matches` over only the fields its list row carries [src/OcuPilot/Kernel/Proposal/ReadBack.cls:Compared] -- deferred: DW-1710 decision-pending (product call, decision sheet)
- [x] [Review][Defer] 202 never re-read (DW-1713 by-design); numeric default rule (DW-1714 by-design); nothing-compared reads "could not be read" (DW-1715 by-design); MatchRoles default-secret rows reported written (DW-1716 by-design); list-row re-read by name (DW-1717 wontfix-theoretical); duplicate `permissions.users.create` key, pre-existing (DW-1712 wontfix-accepted)

**Rejected:**

- `Settings: written` covers the whole object -- spec-declared (Declarations).
- `""` against `0` reads differs -- the spec's default rule; no Save observed sending it.
- A secret's sent value compared with the pre-write read -- the spec's Merge row; the re-read's value is never examined.
- `Password` for the matrix's `NewPassword` -- spec text; fixing it edits the spec.
- Answer and wire disagree when a read-back passes 4,000 characters, or its recording fails -- names only, so theoretical; failure is logged by spec.
- `RecordReadBack` matching no row -- the row was confirmed in the same call.
- Blank names on an empty `differs` or secret-only `written` -- unreachable: a differs names at least one field and a secret-only tool requires its secret.
- A process terminate reads "still present" -- false: measured `notFound` in 3 of 3 re-reads right after the terminate on `ocupilot-ci`.
- Tracking files disagree on status -- the lead's bookkeeping, not code.
- `Rows` re-parses the XData per write -- negligible cost.
- `Answer`'s doc claims the read-back is read from the row -- the clause qualifies the row fields, as before this story.

## Spec Change Log

- 2026-09-26, lead, after code review: the matrix's secret-row example corrected at origin to `[Password]` (the declared secret name the card asks for; `NewPassword` is only the port's wire name), per the review's flagged spec-text drift.

- 2026-09-26, lead, spec gate: AD-58 written into the spine as recommended below (Rule 20, light path; no existing AD contradicted), with pointers in AD-3 and AD-53. Status reset to ready-for-dev; no other change.

## Review Triage Log

### 2026-09-26 — Review pass

- verdicts: 21 findings — high 1, medium 8, low 6, false 6, maybe-false 0
- findings:
  - `[medium]` `[patch]` VG: agent path client wiring (turn confirm -> event -> card; reload via `parseProposal`) untested — added a `turn.test.mjs` case (outcome, event, row, reload) and a `panel.spec.ts` card-line case; mutations recorded.
  - `[medium]` `[patch]` VG: Save read-backs other than the web app pinned only for presence — `DeviceWire`, `RoleSave`, `TaskEdit`, `UserSave`, `WalletWire` now assert the verdict (`matches []`, wallet `matches ["Secret"]`); all green on `ocupilot-ci` except `TaskEdit` (refuses there, arming residue), whose Save and rename were probed by hand on `ocupilot-ci` and read `matches`.
  - `[medium]` `[patch]` VG: an empty compared set (no sent object, field rows unreadable) answered `matches` — `Compared` now answers 0 and `Of` reports `unchecked`/`unreadable`; `TestAMergeWithNothingToCompareIsUnchecked` added.
  - `[medium]` `[patch]` VG: form-store read-back pinned only on the web app editor — added `reduced-form.page.spec.ts` and `resource-editor.store.spec.ts` cases.
  - `[low]` `[patch]` VG: AC2 `differs` pinning test had no mutation line — mutation applied, red observed, line written.
  - `[low]` `[patch]` VG: `read-back.test.mjs` asserted a source constant — assertion (and its now-unused import) deleted.
  - `[high]` `[patch]` VG: existing browser specs waited for "Saved" exactly and would time out on "Saved · Read back: …" — helpers in `audit-event-editor`, `reduced-editors`, `resources-editor`, `ssl-editor`, `task-editor` and the five OAuth editor specs accept the line; `token-revoke`'s whole-cell tag assertion accepts it too. All ran green on `ocupilot-ci` except `reduced-editors` (refuses there: `OCUPILOT_ALLOW_SERVICE_CONFIG` unset).
  - `[medium]` `[patch]` VG other: field rows unreadable answer `matches` — same root as the empty-compared-set row; closed by that patch.
  - `[medium]` `[defer]` VG other: role `Resources: unordered` compares each element's whole JSON, so a grant sent `"WR"` (read back `"RW"`) or with members in another order reads "differs in Resources" — the closed top-level vocabulary cannot express a nested mode; deferred.
  - `[low]` `[reject]` VG: `ErrorDelete.ReadBackGone` answers gone when the re-read has no `entries` array — the port answers a fixed shape; no reachable path shown.
  - `[low]` `[reject]` IA-R2: `written` answers `Password`, the matrix example says `NewPassword` — the kernel's sent name is the descriptor's declared secret, the one the card asks for; the port renames it only on the wire (`UserPassword.cls:5-10`). Flagged for the lead as spec-text drift.
  - `[medium]` `[defer]` IA-R8: the "Normalized list" reading that covers `Resources[].Permissions` — same root as the VG `Resources` row; deferred with it.
  - `[false]` `[reject]` IA-R3: a secret's sent value is compared with the fresh read's — the intent's Merge row says exactly that; the re-read's value is never examined.
  - `[false]` `[reject]` IA-R6: the re-read delays the answer by one round trip — required for `readBack` to ride the success answer; no wait or retry is added.
  - `[false]` `[reject]` IA-R7: Saves re-read through the Save's own port — that is the port the write went through and the tool's own read resolves on it (task Save via `UpdatePortClass` probed `matches`).
  - `[false]` `[reject]` IA: list-row read skips a sent name the row does not carry (`pRowOnly`) — the reading "a list-type read resolves exactly as the mint's does" admits only this; comparing an unseen field would report `differs` for every such write.
  - `[medium]` `[patch]` IA-R9 surface: agent card/row and forms other than the web app exercised only below their surface — same roots as the VG agent-path and form-store rows; closed by those patches.
  - `[low]` `[reject]` IA-R9: a `present` delete's row line not exercised on the client — `readBackLine` pins the text and `data-table.spec.ts` pins the line's placement; the combination adds no branch.
  - `[low]` `[reject]` IA-R9: a Save answering 202 is not reached by a test — no Save's port answers 202 today; `ForSave` shares `Running()` with the tested callers.
  - `[false]` `[reject]` IA-R9: recording failure never tested — `RecordReadBack` is wrapped in Try/Catch and logs only; no reachable failure shown.
  - `[false]` `[reject]` IA-R9: committed declarations asserted for five update entries only — `field-lists.mjs --check` pins every emitted row byte for byte against `ToolFields.cls`.

## Design Notes

**Recorded as AD-58 at the spec gate (2026-09-26).** The halt as raised: It adds three things other stories rely on: a shared post-write step that both callers of every write tool must run, a declaration vocabulary that every future write tool uses, and per-kind semantics. 16.19's impact lines and 16.21's Fix it proposals depend on these, so they have architectural weight. Recommended text for the lead:

> ### AD-58 -- A confirmed write reads its target back on the instance and says whether it holds what was sent
>
> - **Binds:** Story 16.17; every write tool and both callers of each (AD-53, AD-55); AD-3, AD-6, AD-14, AD-26, AD-35, AD-51, AD-54, AD-56
> - **Prevents:** a write reported as a success while the instance holds something else, a comparison computed in the browser, and a secret read back in order to be compared
> - **Rule:** After a write reads OK, its caller re-reads the target through the tool's declared port and read type with the caller's own privileges, outside any transaction and after the ledger row and marker, and answers `readBack {verdict, fields, written, reason?}` beside the write's own answer, which it never fails or alters. The kind decides the subject: a merge or create compares each top-level key of the sent body that the tool's derived field list names, except the descriptor's `fingerprintExcludes`; a delete expects absence; an action-style write sends no value and says so; a secret is reported written and its read value is never examined, returned or logged. A 202 continuation or a failed re-read is `unchecked`. How a field the instance normalizes on save is compared is declared in the tool's reviewed Classification entry (`compare`, a closed vocabulary) and emitted with the derived list (AD-3). Only names and a verdict leave the instance. The verdict rides the change event as an annotation beside the row mark, never as row data (AD-14), and is kept on the proposal row.

Two pointers follow from it:

- **AD-3:** add "The same reviewed entry declares how the read-back compares a field the instance normalizes on save (AD-58); that declaration is not part of a tool's schema."
- **AD-53:** add "the read-back (AD-58)" to "What both callers share".

No AC contradicts an existing AD Rule. Once AD-58 is in the spine, set `status: ready-for-dev` with no other spec change.

**Decisions flagged for review:**

1. **A Save's visible surface is its "Saved" line.** Editors stay open after Save and mark no row. A dialog editor over a list gets the row line through the bus as well.
2. **"Every field the write sent" is read literally for a merge**, which means AD-4's complete body. Unchanged keys are the fresh read's own values, so they differ only if the endpoint moved them. The descriptor already declares that case for AD-6, as `fingerprintExcludes`.
3. **The action-style kind has no comparison subject.** AD-51 writes send nothing, and their state rows carry labels rather than values. A per-tool expected state is left to a later story.
4. **The verdict is persisted on the proposal row, not on the ledger.**

**Measured on `ocupilot-ci`, 2026-09-26, through `/api/admin` v2. The probe objects were removed and each re-read answered 404.**

- A web app `Path` sent without a trailing slash was kept as sent, as were `CookiePath`, the `CorsAllowlist` order, and `Timeout` sent as `"900"` (read back as `900`) or `"0900"` (read back as `900`).
- `Enabled` sent as `0` read back as `false`.
- Role `GrantedRoles` were read back sorted.
- `Resources[].Permissions` sent as `"WR"` read back as `"RW"`.
- Resource `PublicPermission` sent as `"WR"` read back as `"RW"`.
- User `Roles` were read back sorted.
- A deleted web app, role and resource each re-read as 404.
- Role `Resources` sent as `[%Development,%Admin_Operate]` read back `[%Admin_Operate,%Development]` (implement, 2026-09-26), so `Resources: unordered` is declared on `permissions.roles.update` and `.create`.

**Copy for the EXPERIENCE.md row at 575, verbatim:**

> "Read back: matches" · "Read back: differs in <fields>" · "Read back: not found" · "Read back: still present" · "Read back: <fields> written, not read back" · "<fields> written, not read back" · "Read back: nothing sent to compare" · "Read back: not checked, the write is still running" · "Read back: could not be read" · " and <n> more"

The Where column says: the read-back line of a confirmed write (Story 16.17), on the proposal card under its status line, after the "Changed" tag on the marked row and appended to that row's announcement with " · ", and on a form as "Saved · <line>"; `<fields>` lists up to three field names joined by ", ", then " and <n> more"; the written clause is appended to a matches or differs line with " · " [ADDED 2026-09-26 - Story 16.17].

**Governing ADs:** AD-58, AD-3, AD-4, AD-5, AD-6, AD-8, AD-13, AD-14, AD-15, AD-19, AD-26, AD-29, AD-34, AD-35, AD-36, AD-39, AD-41, AD-43, AD-51, AD-52, AD-53, AD-54, AD-55, AD-56, and Conventions › Secrets.

**Integration ACs:**

- **Consumes:** the write operation and the tool registries.
- **Consumed-by:** 16.19, whose impact lines sit beside this line on the card and the dialog, and 16.21, whose Fix it proposals report their read-back. Both are inference until their plans.

**Governance:** Story 14.2's baseline is held, so no tool is wired into a policy. **DW-118** is declined, because it was already resolved by Story 15.6. The ledger inbox is empty.

**Contended files touched:**

- EXPERIENCE.md: one row appended.
- `strings.ts`: keys appended.
- `_components.scss`: appended at the end.
- `proposal-card.ts`: inputs and template only, away from 662-672.
- Router, AdminPort, Ledger, AuditingUpdate, `proposal-card.spec.ts`, the structural baseline and the contended `Test/*` classes are untouched.

**Bundle:** stays under the 1900 kB warning. There are no lazy loads.

## Verification

**Commands:**

- `cd ui && node tools/field-lists.mjs --check && node --test tools/field-lists.test.mjs tools/read-back.test.mjs tools/change-bus.test.mjs` (loop) -- expected: green. Record these mutations: accept an unknown mode, which should turn the refusal case red; drop `compare` emission, which should turn the drift check red.
- `cd ui && npx ng test --include src/app/shell/proposal-card-read-back.spec.ts --include src/app/shell/data-table.spec.ts --include src/app/shell/screen-action-handler.spec.ts --include src/app/areas/web-applications/web-app-editor.page.spec.ts` (loop) -- expected: green. Mutation: render nothing for `notFound`, which should turn the card case red.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.ReadBack`, then `ReadBackRoute`, `ProposalWire`, `ProposalConfirm`, `ToolWrite`, one at a time (loop) -- expected: green. Mutations:
  - remove `GrantedRoles: unordered`, then regenerate: the role case turns red;
  - compare secrets by value: the secret case turns red;
  - read 404 as `matches`: the not-found case turns red.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/ && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/read-back.browser-spec.mjs` (loop) -- expected: green in both themes. Mutation: drop `readBack` from the ScreenAction answer, which should turn the row case red.
- `cd ui && npm test` (once, before dev_complete) -- expected: green, and the bundle under 1900 kB.
- Full ObjectScript sweep on `ocupilot-ci`, one class at a time (once, before dev_complete) -- expected: green.

**Observed (implement, 2026-09-26; each file restored byte for byte after its run, ObjectScript recompiled on `ocupilot-ci`, the whole tree after the last):**

- mutation: accept an unknown mode in `classify()` (`field-lists.mjs`) -> "a compare declaration is emitted onto its rows, and every malformed one is refused" red.
- mutation: drop the `compare` key from `buildToolFields()` -> `--check` exits "stale", and the drift, committed-file and compare cases red.
- mutation: answer `matches` for a 404 re-read in `ReadBack.Of` -> `Test.ReadBack` `TestAnUpdateWhoseTargetIsGoneIsNotFound` (and the action case's gone leg) red.
- mutation: compare secrets like ordinary fields in `ReadBack.Compared` -> `Test.ReadBack` `TestASecretIsWrittenAndItsReadValueIsNeverExamined` red.
- mutation: remove `GrantedRoles` from `permissions.roles.update`'s `compare`, regenerate -> `Test.ReadBackRoute` `TestAConfirmedRoleUpdateReadsBackAReorderedListAsMatching` and `Test.ReadBack` `TestADeclaredUnorderedListMatchesReordered` red.
- mutation: drop `readBack` from `Propose.WireRow` -> `Test.ProposalWire` `TestTheWireRowCarriesTheRecordedReadBack` and `TestTheWireRowCarriesTheTripleTheDiffAndTheState` red.
- mutation: render `''` for `notFound` in `readBackLine` -> `proposal-card-read-back.spec.ts`'s delete case and `read-back.test.mjs`'s per-verdict case red; accept a verdict outside the vocabulary in `readBackOf` -> the vocabulary case red.
- mutation: drop `readBack` from `ChangeBus.publish` -> `change-bus.test.mjs`'s read-back case red; drop the read-back span from the data table's name cell -> `data-table.spec.ts`'s Story 16.17 case red; drop `readBack` from the row action's publish -> `screen-action-handler.spec.ts`'s read-back case red; render `STRINGS.formSaved` in place of `savedText` on the web application editor -> `web-app-editor.page.spec.ts`'s Story 16.17 case red.
- mutation: drop `readBack` from `ScreenAction.Run`'s answer, recompiled on `ocupilot-ci` with the rebuilt bundle deployed -> `browser/read-back.browser-spec.mjs` AC5 red; the same beside dropping it from `WebAppSave.HandleUpdate`'s answer -> `Test.ReadBackRoute`'s row-action and Save cases red.
- mutation: re-read a 202 write (`If 0` for the 202 branch) in `Confirm.Transition` and `ScreenAction.Run` -> `Test.AuditStarted`'s agent and screen-route cases red on "a copy still running is not read back" (Queued matrix row).
- mutation: never record a differing field in `ReadBack.Compared` (`If 0 Set pFields`) -> `Test.ReadBack` `TestAChangedValueDiffersByName` red (AC2's `differs` half).
- mutation: answer 1 from `Compared` for a missing sent object -> `Test.ReadBack` `TestAMergeWithNothingToCompareIsUnchecked` red; pass `""` as the sent body in `DeviceSave.Create`'s `ForSave` -> `Test.DeviceWire` create case red on its `matches []` verdict.
- mutation: drop `readBack: outcome.readBack` from `confirmProposal`'s publish -> `turn.test.mjs` read-back case red (event leg); drop `readBack` from `parseProposal` -> the same case red (reload leg); drop the card's `[readBack]` binding in `panel.ts` -> `panel.spec.ts` "AC1: a confirmed card carries the instance's read-back line" red (AC1 agent leg).
- mutation: drop the `readBackOf(...)` assignment in `ReducedFormStore.save` -> `reduced-form.page.spec.ts` Story 16.17 case red; drop `readBack` from `ResourceEditor.save`'s publish -> `resource-editor.store.spec.ts` Story 16.17 case red (AC1 form leg).
- mutation (code review): drop the `tCount = 0` branch in `ReadBack.Of` -> `Test.ReadBack` `TestAReadBackThatComparedNothingNeverMatches` red; drop `WithWritten` from `ForSave` -> `TestASavesSecretsStoredApartAreWritten` red; test a written name's sent text against `""` again -> `TestASecretIsWrittenAndItsReadValueIsNeverExamined` red; drop `tStored` from `OAuthResourceServerSave.HandleCreate`'s `ForSave` -> `Test.OAuthResourceServerSecret` save case red.
- mutation (code review, DW-1709): remove `"Resources[].Permissions": "letters"` from both role entries and regenerate -> `Test.ReadBack` `TestARoleGrantReadBackNormalizedMatches` and `Test.ReadBackRoute` role case red (`differs ["Resources"]` from the instance); emit only the top-level mode in `classify()` -> `field-lists.test.mjs` compare case red.
- mutation (code review, AC4 client): render the written clause as the bare line in `readBackLine` -> `read-back.test.mjs` names case and `proposal-card-read-back.spec.ts` "a secret as written" case red.
- mutation (code review, AC1 create leg): drop `this.readBackValue = arrivingReadBack` or the `reset()` clear in `WebAppEditor` -> `web-app-editor.store.spec.ts` Story 16.17 create case red; pass `arriveSaved` no read-back on the web app create page, rebuilt and redeployed -> `web-applications-create.browser-spec.mjs` AC2 red. Drop `withReadBack` from the OAuth client page's refused status -> `oauth-client-form.page.spec.ts` refused case red. Drop the span's `title` -> `data-table.spec.ts` Story 16.17 case red.

## Auto Run Result

**Implemented (AD-58).** `Kernel/Proposal/ReadBack.cls` re-reads the target through `Operation.ReadAt` and answers `{verdict, fields, written, reason?}`, names only; the kind comes from the tool's parameters and every fault, including nothing to compare, reads `unchecked`. Callers: `Confirm.Transition` (recorded on `Propose.ReadBack`, wire `readBack`, `null` until recorded), `ScreenAction.Run` and all 20 Save/Create handlers via `ReadBack.ForSave`; 202 answers `unchecked`/`running`. `compare` is a Classification key validated and emitted by `field-lists.mjs` onto `ToolFields`; role `Resources` measured sorted and declared `unordered`. `ErrorDelete.ReadBackGone` keys on date, number and Time. Client: `core/read-back.ts` renders; the verdict rides the change event to the marked row and its announcement, the proposal card, and every form's "Saved · <line>". Copy appended at EXPERIENCE.md:575 (one citation moved 615 to 616).

**Files:** server `ReadBack.cls` (new), `Confirm.cls`, `ScreenAction.cls`, `Propose.cls`, `Write.cls`, `ErrorDelete.cls`, `Classification.cls`, `ToolFields.cls` (generated), 20 `Area/*` Save handlers; client `read-back.ts` (new), change-bus, screen-store, refresh, data-table, screen-action-handler, turn, panel, proposal-card, reduced form, 17 form stores and pages, `strings.ts`, `_components.scss`; tests `Test.ReadBack`, `Test.ReadBackPort`, `Test.ReadBackRoute` (new), verdict assertions in `ProposalWire`, `AuditStarted`, `DeviceWire`, `RoleSave`, `TaskEdit`, `UserSave`, `WalletWire`, `SslSave`, fixture `ProposalFixture`; `read-back.test.mjs`, `field-lists.test.mjs`, `change-bus.test.mjs`, `turn.test.mjs`, five component specs, `read-back.browser-spec.mjs` (new), eleven browser specs' "Saved"/tag waits; `scripts/ci-throwaway.sh` roster. Epic 23 files touched, off their hunks: EXPERIENCE.md, `_components.scss` (appended at end), `proposal-card.ts` (away from 662-672), `ci-throwaway.sh` (roster comment).

**Review:** 21 findings — 9 patched (high 1: existing browser specs waited for "Saved" exactly; see the triage log), 2 deferred (one root: role `Resources` whole-element compare), 10 rejected with reasons in the log. Patched counts by verdict: high 1, medium 6, low 2. `written` names the declared secret (`Password`) where the matrix example says `NewPassword` (the port's wire name) — flagged for the lead as spec-text drift.

**Follow-up review recommended:** true — the patched high is the browser-spec wait fix; `reduced-editors.browser-spec.mjs` refuses on `ocupilot-ci` (`OCUPILOT_ALLOW_SERVICE_CONFIG` unset), so its patched `saved()` is verified only by CI's browser job.

**Verification:** node tiers (field-lists, read-back, change-bus, turn) green; component specs for the card, data table, action handler, web-app editor, panel, reduced form and resource store green; `npm test` whole green (1505 node tests, 111 component files; one stale expectation in `reduced-form.store.spec.ts` fixed first); build 1,868,563 bytes, under 1900 kB; `check-objectscript` and `lint-docs` clean. On `ocupilot-ci`, one class at a time: `ReadBack` 13, `ReadBackRoute` 3, `ProposalWire` 16, `ProposalConfirm` 20, `ToolWrite` 31, `AuditStarted` 3, `DeviceWire`, `RoleSave`, `UserSave`, `WalletWire`, `SslSave` green. Full sweep once: 294 classes, 2338 tests, 14 refused (arming), 1 known residue (`WireSecurityRead` task history), 1 story failure (`SslSave` exact create answer), patched and re-run green. `TaskEdit` refuses there; its Save and a rename were probed by hand and read `matches`. Browser: `read-back.browser-spec.mjs` green in both themes within the structural baseline; audit-event, resources, SSL, task and token-revoke specs and the five OAuth editor specs green after the wait patch.

**Residual risks:** vendor normalizations not covered by a declaration may read `differs` on editors not exercised here (LDAP, X.509, audit events, services); a role grant sent `"WR"` reads `differs` (deferred).

Status: done
Blocking condition: none
