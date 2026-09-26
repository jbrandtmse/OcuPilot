---
title: 'Story 16.17: The read-back line'
type: 'feature'
created: '2026-09-26'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['oversized']
deferred: []
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
| Secret sent | user password; or a merge carrying a supplied secret | `written`, `[NewPassword]`; a merge appends "· … written, not read back" | read value never examined |
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

## Spec Change Log

- 2026-09-26, lead, spec gate: AD-58 written into the spine as recommended below (Rule 20, light path; no existing AD contradicted), with pointers in AD-3 and AD-53. Status reset to ready-for-dev; no other change.

## Review Triage Log

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

## Auto Run Result

Status: ready-for-dev
Blocking condition: none (the needed AD was written by the lead as AD-58 at the spec gate on 2026-09-26)
