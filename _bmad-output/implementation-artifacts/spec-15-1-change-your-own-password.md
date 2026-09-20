---
title: 'Story 15.1: Change your own password'
type: 'feature'
created: '2026-09-19'
status: 'done'
baseline_revision: 'a290a4a74a245fa48ecb5e02153d0bf99fe4968d'
baseline_commit: 'a290a4a74a245fa48ecb5e02153d0bf99fe4968d'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-15-context.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A password the instance refuses through PasswordValidationRoutine answers 500, not the 422
      with the instance's own reason the matrix's "Policy rejection" row promises.
    evidence: |-
      Measured on the slot C throwaway: with a validation routine configured,
      $System.Security.ChangePassword returns 0 with codes "1446,5001" and the routine's own
      sentence. 5001 is outside POLICYCODES ("845,958"), so RenderChangeRefusal takes the 500 arm.
    location: >-
      src/OcuPilot/Api/Account.cls (Parameter POLICYCODES)
    severity: medium
  - summary: >-
      The same closed allow-list turns every other real refusal -- a delegated or LDAP account, a
      disabled one -- into an opaque 500, against the Design Notes' stated observable cost.
    evidence: |-
      Same root cause as the entry above; measured codes 838 (no such user) and 5001 both fall
      through. The Design Notes predicted such a user "sees the instance's own refusal text";
      with the list closed they see the generic internal-error reason instead.
    location: >-
      src/OcuPilot/Api/Account.cls (RenderChangeRefusal)
    severity: medium
  - summary: >-
      A read or decode fault while reading the body is answered 422 as the caller's malformed
      body, where Api/Context.cls splits the two apart (DW-24).
    evidence: |-
      Context.cls:44-53 routes a non-parse stage to a different refusal. The split was implemented
      and then reverted: no constructible input reaches the read or decode stage (an invalid-UTF-8
      body parses through), so the branch could not be pinned by any test.
    location: >-
      src/OcuPilot/Api/Account.cls:52-58
    severity: low
  - summary: >-
      The wire test's policy assertion derives its expected sentence with the same index-2
      assumption PolicyText uses, so the two would move together and stay green.
    evidence: |-
      TestAPolicyRefusalCarriesTheInstancesOwnText calls GetOneStatusText(tProbeSC, 2); PolicyText
      derives its index from the allow-listed code's position in GetErrorCodes. A refusal carrying
      more than one embedded error would move both.
    location: >-
      src/OcuPilot/Test/AccountPasswordWire.cls
    severity: medium
  - summary: >-
      The change-password dialog does not submit on Enter, where the house credential form does.
    evidence: |-
      The two inputs sit in bare divs with a type="button" action; dialog.ts carries no Enter
      binding. sign-in.ts:112-162 uses a real <form (submit)>. No existing app-dialog call site has
      a text input, so there is no house dialog pattern this departs from -- and a form inside the
      projected content is not a trivial change.
    location: >-
      ui/src/app/shell/change-password-dialog.ts
    severity: medium
  - summary: >-
      A new ACCOUNT.* field-level violation code with no ReasonForViolation arm would render a
      blank reason with no test going red.
    evidence: |-
      OcuPilot.Test.AgentViolation.cls:84 skips any parameter whose name does not start with
      "AGENT", so the ACCOUNT.* family is outside the roster guard by construction. Widening the
      sweep edits Epic 13's contended src/OcuPilot/Test/** path.
    location: >-
      src/OcuPilot/Test/AgentViolation.cls:84
    severity: low
  - summary: >-
      Two handlers now render violations, because Definitions.RenderViolations fixes the envelope
      code at AGENT.VALIDATION.
    evidence: |-
      Api/Account.RenderViolations duplicates Api/Definitions.cls:1270 so it can send
      ACCOUNT.VALIDATION. Both serialize through the one Kernel/AgentRules.ViolationsJson, so
      AD-12's single writer holds; the fix is an optional pCode parameter on a file outside this
      story's footprint.
    location: >-
      src/OcuPilot/Api/Definitions.cls:1270
    severity: low
  - summary: >-
      The REST route-ordering convention is worded "N-segment routes before (N-1)-segment routes"
      unconditionally, which the tail-appended /account/password contradicts as written.
    evidence: |-
      check_route_ordering implements only the leading-segments form and passes, and no route
      shares the /account prefix, so nothing misroutes. The wording lives in the spine's
      Consistency Conventions and in Router.cls's class doc, and the tail append is condition 1 of
      the orchestrator's shared-append grant.
    location: >-
      ARCHITECTURE-SPINE.md, Consistency Conventions, "REST route ordering"
    severity: low
  - summary: >-
      The dialog's empty-field reason reuses "Required", whose EXPERIENCE.md row names the OpenAPI
      viewer, and the story's own new row does not list it.
    evidence: |-
      strings.test.mjs asserts an exact key count and the spec allowed exactly six new keys, so
      reusing the published literal was the only compliant option. Reconciling the table is a
      third EXPERIENCE.md edit, beyond the two the shared-append grant covers.
    location: >-
      ui/src/app/shell/change-password-dialog.ts (STRINGS.openApiRequired)
    severity: low
  - summary: >-
      Three different naming conventions now exist for a masked field's reveal toggle.
    evidence: |-
      sign-in.ts:154 labels its toggle STRINGS.fieldPassword, definition-form.page.ts uses
      agentDefinitionShowKey/HideKey, and this dialog uses accountShowPassword/HidePassword. The
      first two already differed before this story.
    location: >-
      ui/src/app/core/strings.ts
    severity: low
  - summary: >-
      EXPERIENCE.md:395 still says the polish week adds Change password, and :505 still sends an
      expired-password user to the classic portal by name.
    evidence: |-
      Both are now stale or half-past-tense. The shared-append grant covers exactly two edits to
      this file -- the :381 append and the line-neutral :173 amendment -- so a third is the lead's.
    location: >-
      _bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:395
    severity: low
footprint_extensions:
  - "src/OcuPilot/Api/Router.cls -- tail-append only (one <Route>, one wrapper); shared-append grant; Epic 5 head a5202e0"
  - "_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md -- one Fixed strings row appended at :381, Dialogs line :173 amended in place and line-neutral; shared-append grant; Epic 5 head a5202e0"
  - "src/OcuPilot/Api/Error.cls -- four codes, four REASON parameters and four ReasonForViolation arms appended; owned by no concurrent epic"
  - "src/OcuPilot/Test/AccountPasswordWire.cls -- NEW under Epic 13's src/OcuPilot/Test/**; check_handler_wire_tests makes it a build gate for the route"
  - "ui/src/app/shell/status-bar.spec.ts -- one assertion now reads both menu items instead of the first; forced by the second item"
  - "ui/browser/panel.browser-spec.mjs -- its sign-out click selects the item by name instead of by position; forced by the second item"
  - "ui/src/app/core/strings.ts -- shared-append: six keys added at the tail, nothing reordered, renamed or reflowed"
---

<intent-contract>

## Intent

**Problem:** A user who wants to change their own password has to leave OcuPilot for the classic portal, and the sign-in card's expired-password banner sends them there by name.

**Approach:** Add **Change password** to the status bar's account menu, opening the shared `app-dialog` over two masked fields. A new caller-own OcuPilot endpoint calls `$System.Security.ChangePassword($Username, new, old, .tSC)` — the same call the Management Portal's own self-service dialog makes — and returns the instance's own policy reason as an AD-39 field violation. Adding the menu's second `role="menuitem"` also settles its keyboard model (DW-115).

## Boundaries & Constraints

**Always:**

- The change runs as the signing-in user: `$Username`, no service account, no `New $ROLES`, no `%SYS` switch (AD-8; `%SYSTEM.*` resolves from any namespace).
- A password value exists only as a local variable on the handler's stack. It never enters a log line, an exception, a `%Status`, a URL, a query parameter, an audit payload or an error message (NFR-5, AD-35, Conventions › Secrets).
- Both fields are masked, write-only, never pre-filled, never echoed back, pastes untrimmed (DESIGN.md:1223).
- One error envelope, one writer (AD-12); every refusal carries a stable dotted code and the human `reason` is display-only (AD-39).
- Every new user-facing literal is published in EXPERIENCE.md's `**Fixed strings**` table **before** it exists as a `strings.ts` key.

**Never:**

- Never the admin API's `POST /security/user/password`: it requires `%Admin_Secure`, takes no old password, and `AdminPort`'s `TYPESUFFIXES` admits read types only.
- Never an agent tool, a proposal, a confirm, a screen descriptor or an Angular route — this is shell chrome (AD-5, AD-40).
- Never a username from the request body, and never a response that distinguishes "wrong current password" from "no such user".
- Never route this handler's body-parse failure through `Definitions.RenderBadBody` → `Fault.LogRaw`, which writes `GetErrorText(status)` unredacted under the member name `status`.
- Never accept the new password as a URL or query value; never store it in the client session.
- Story 15.6's theme toggle is out of scope — but the menu keyboard model is built n-item, because 15.6 adds a third item.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Happy path | signed-in user; `POST /api/ocupilot/account/password` `{"currentPassword","newPassword"}`, both correct | `200` with `{}`; dialog closes; account menu's `role="status"` region announces `Password changed`; focus returns to the menu trigger | No error expected |
| Session survives | same, immediately after success | The tab stays signed in — the Bearer pair was already minted and authorization is Bearer-only (AD-28) — and the next `/api/ocupilot` call still answers `200` | No error expected |
| Wrong current password | `currentPassword` incorrect | `422`, slug `validation_failed`, code `ACCOUNT.VALIDATION`, `detail.violations[{field:"currentPassword", code:"ACCOUNT.PASSWORD.CURRENT", reason:<written>}]`; dialog stays open, field gets `aria-invalid`, summary takes focus | `ChangePassword` returns 0 with codes `1446,952` (verified on slot C). Discriminate by **contains** on `$System.Status.GetErrorCodes`, never equality — 1446 is always the outer code |
| Policy rejection | `newPassword` fails `Security.System.PasswordPattern` or `PasswordValidationRoutine` | `422` as above, violation on `newPassword` with code `ACCOUNT.PASSWORD.POLICY` and **the instance's own text** as `reason` | Pass the text through only for the embedded code `$$$UserPasswordInvalidFormat` (845) and `$$$InvalidPasswordPattern` (958); unwrap the embedded error as `%CSP.PasswordChange.cls:126-136` does |
| Malformed body | not JSON, not an object, an extra member, a missing member, or a non-string member | `422`, slug `validation_failed`, code `ACCOUNT.PASSWORD.BODY`, flat reason naming the two members and no value | Follow `Api/Context.cls:44-69` exactly, including binding the iterator's value to an unread variable. Log a status this handler composed, naming the stage only |
| Any other failure | `ChangePassword` returns 0 with a code outside the allow-list | `500` via `Error.RenderInternal` with a generic reason; the raw `%Status` reaches `OcuPilot.Kernel.Audit.Log.Error` only | Never render vendor text that was not allow-listed (AD-39) |
| Empty field | either field empty at submit | Client refuses before the request; the field carries `aria-invalid` and its reason; no request is sent | No error expected |
| Menu keyboard (DW-115) | account menu open, two `role="menuitem"` items | Every item carries `tabindex="-1"`; ArrowDown/ArrowUp wrap, Home/End jump, all off `document.activeElement`; Escape closes and returns focus to the trigger | Model is n-item — it must behave identically with three items |
| Dialog dismissal | Escape, Cancel, or the scrim | Dialog closes with no request sent and no password retained; focus returns to the menu trigger | `app-dialog` already owns this; do not re-derive it |

</intent-contract>

## Code Map

### Client — reuse, do not re-derive

- `ui/src/app/shell/dialog.ts` — the shared `app-dialog`: `role="dialog"`, `aria-modal`, focus trap (`:145-161`), initial focus on the first input (`:104-117`), focus return to `opener` (`:98`, `:118-122`), Escape via `OverlayStack`, `DIALOG_OVERLAY_ID` making stacking impossible. Inputs `heading` / `closeLabel`, output `closed`, confirming action projected into `[dialogAction]`.
- `ui/src/app/areas/agent/switches.page.ts:280-288` — the only existing call site that uses the `[dialogAction]` slot. Copy this shape.
- `ui/src/app/areas/agent/definition-form.page.ts` — the form model to copy: field view-model factory `:1078-1091` (`{id, invalid, reason, describedBy}`), error summary `:95-113` (`role="alert"`, `tabindex="-1"`), `focusSummaryAndField()` `:1061-1075`, whole-response refusal banner `:116`, masked field with a **labeled** reveal toggle `:268-298` (`revealLabel` `:716-718` — the right precedent; `sign-in.ts:137-159`'s static `aria-label` is not).
- `ui/src/app/shell/data-table.ts:311-325` + `:811-839` — **the house menu keyboard model**: container `(keydown)`, `tabindex="-1"` per `role="menuitem"`, wrap-around Arrow/Home/End off `document.activeElement`, `onMenuMouseDown` (`preventDefault`), `onMenuFocusOut`. DESIGN.md:1023 styles the account menu *as* `row-overflow-menu`, so this is the model it already inherits.
- `ui/src/app/shell/account-menu.ts` — `role="menu"` `:81`, the single `role="menuitem"` `:82-90` with **no** `tabindex`, first-item focus effect `:125-133`, `closeAndRefocus()` `:153-158`. The doc comment at `:22-25` cites EXPERIENCE.md's Dialogs enumeration as authority for having no dialog here; it is now wrong and is replaced, not annotated.
- `ui/src/app/core/api.ts` — `API_PATH_PREFIX` `:156`, `requestJson<T>` `:328`, the three-armed `JsonResult` `:107-122`. Branch on `code`, render `reason` (AD-39).
- `ui/src/app/core/violations.ts` — `Violation` `:20`, `violationsOf(result)` `:35`, `reasonForField(violations, field)` `:67`. The 422 shape decodes through these unchanged.
- `ui/src/app/core/strings.ts` — **shared-append**: add keys only, never reorder, rename or reflow. Reuse `actionCancel` `:103` for the dialog's `closeLabel`. Do **not** reuse `agentDefinitionShowKey`/`HideKey` `:529`/`:531` — they say "key", not "password".

### Server — reuse, do not re-derive

- `src/OcuPilot/Api/Context.cls:40-87` — the caller-own, ungated POST handler template, including the three body rejections at `:44-69`. `CallerUsername()` `:12-15`.
- `src/OcuPilot/Api/Switches.cls:446-452` — a separate handler class forwarding to `Definitions.RenderViolations` with its own `pReason`. Do this; do not duplicate the helper.
- `src/OcuPilot/Api/Definitions.cls:1270` — `RenderViolations(ByRef pViolations, pReason)`; entries are `$ListBuild(field, code, reason)`, serialized by `Kernel/AgentRules.cls:403-417` as `{field, code, reason}`.
- `src/OcuPilot/Api/Error.cls` — `Render` `:1208`, slug `#VALIDATIONFAILED` `:44`, `ReasonForViolation` `:1030` (a new violation code needs an arm here or its `reason` serializes empty), `RenderInternal` `:1258`.
- `src/OcuPilot/Api/Router.cls` — `XData UrlMap` `:72-110`; thin wrappers e.g. `:125-128`. `OnPreDispatch` `:501-572` reads no body and logs nothing.
- `src/OcuPilot/Kernel/Utils.cls:369` — `ReadRequestBody(Output pBody, Output pStage)`.
- `src/OcuPilot/Test/LogSourceDenial.cls:41`, `:85-89` — the `check_destructive_test_guard` template (`Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_PRINCIPALS"`, the `'= 1` comparison, `Quit $$$ERROR(`), and its literal-free password generator ~`:97`.

### Read-only evidence

- `irissys/%CSP/UI/Portal/Dialog/ChangePassword.cls:121-130` — the Management Portal's own self-service dialog: `Do $System.Security.ChangePassword($Username,password,oldpassword,.tSC)`, no `Parameter RESOURCE`, old password passed. This is the precedent that settles the mechanism.
- `irissys/%CSP/PasswordChange.cls:124-139` — the rejection idiom: unwrap the embedded error, re-mint a clean status, surface `$$$UserPasswordInvalidFormat` deliberately.
- `irislib/%SYSTEM/Security.cls:54` — signature; the class is `Abstract` and the implementation is in `%SYS.SECURITY.OBJ`, unreadable. Behavior below is measured, not read.
- Measured on slot C, 2026-09-19: a wrong old password returns `0` with `1446,952` and `ERROR #1446: Password change failed` / `ERROR #952: Invalid password`; `_SYSTEM` was verified unchanged afterwards. `PasswordPattern` is `3.255ANP`, `PasswordValidationRoutine` is empty, `PasswordExpirationDays` is 0 — so on an unmodified instance only a password shorter than three characters trips the policy.
- Measured on slot C: `%System` / `%Security` / `UserChange` is registered and **enabled**, and fires on failed changes too, carrying the actor and the outcome and no password.
- `src/OcuPilot/Kernel/EntityType.cls` — `user` is in the closed vocabulary; `account` and `principal` are not.

## Tasks & Acceptance

**Execution:**

- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- **append** one Fixed strings row immediately after the current last row (`:380`), publishing `"Change password" · "Current password" · "New password" · "Show password" · "Hide password" · "Password changed"`, annotated `[ADDED 2026-09-19 — see the story change log]`; and amend the Dialogs enumeration at `:173` **in place and line-neutral** to name the account menu's change-password dialog -- the table must be appended to and never inserted into, because `strings.test.mjs` resolves 483 `/** EXPERIENCE.md:N */` comments against hard line numbers and every one of them points at `:254`-`:380`.
- `ui/src/app/core/strings.ts` -- append exactly six keys for the six literals, each with its `/** EXPERIENCE.md:<line> */` comment -- the test asserts an exact key count, globally unique values, and that each comment's line carries its value.
- `src/OcuPilot/Api/Error.cls` -- append `ACCOUNT.VALIDATION`, `ACCOUNT.PASSWORD.CURRENT`, `ACCOUNT.PASSWORD.POLICY` and `ACCOUNT.PASSWORD.BODY` with their `REASON*` parameters, and an arm each in `ReasonForViolation` -- this class is the one home of the code vocabulary, and a code minted at its point of use is how a second spelling family starts.
- `src/OcuPilot/Api/Account.cls` -- NEW `OcuPilot.Api.Account` with `HandlePasswordChange()`, modeled on `Context.HandleUpdate`: read and validate the body, call `$System.Security.ChangePassword($Username, tNew, tCurrent, .tSC)`, map the outcome per the I/O matrix, clear both locals before returning on every path.
- `src/OcuPilot/Api/Router.cls` -- **append** `<Route Url="/account/password" Method="POST" Call="AccountPasswordChange"/>` as the last line of `<Routes>`, after `/navigation`, and **append** the one-line `AccountPasswordChange` wrapper after the last existing `Call=` wrapper. Tail-append, not insertion, is a condition of the orchestrator's shared-append grant: it touches no line Epic 5 added, and Epic 5's own `/proposal/:id/{confirm,cancel}` insertion sits near `/turn`, so the two changes stay apart. Checker-safe either way -- rule 15 refuses only a longer route following a shorter route whose Url matches its leading segments, and no route shares the `/account` prefix. No 405 guard route is added, because `Router.Http405` `:602` serves them.
- `src/OcuPilot/Test/AccountPasswordWire.cls` -- NEW wire test. `check_handler_wire_tests` requires a class under `src/OcuPilot/Test/` naming `/account/password` and `POST` in non-comment code and carrying all four wire markers, so this file is mandatory for the route to build. It creates and deletes its own throwaway principal, so it carries the `OCUPILOT_ALLOW_PRINCIPALS` guard in `OnBeforeAllTests` per `LogSourceDenial.cls:85-89`. **`src/OcuPilot/Test/**` is Epic 13's contended path** -- see Design Notes.
- `ui/src/app/core/account.ts` -- NEW framework-free module: `CHANGE_PASSWORD_PATH`, and `changePassword(api, current, next)` returning a discriminated outcome (`ok` | `rejected` with violations | `error` with a classified fault). No `@angular/core` import (AD-19).
- `ui/tools/account.test.mjs` -- NEW `node --test` suite over `core/account.ts` covering every matrix row's decode, against a fake `ApiService`. Picked up by the existing `tools/*.test.mjs` glob with no config edit.
- `ui/src/app/shell/change-password-dialog.ts` + `.spec.ts` -- NEW component wrapping `app-dialog`: two masked fields with labeled show/hide toggles, per-field `aria-invalid` and `aria-describedby`, an error summary focused as `role="alert"` on a refusal, `Change password` projected into `[dialogAction]`, `actionCancel` as `closeLabel`.
- `ui/src/app/shell/account-menu.ts` -- add the Change password item ahead of Sign out; give every `role="menuitem"` `tabindex="-1"` and add the n-item container keyboard model copied from `data-table.ts:811-839`; host the dialog and a polite `role="status"` region on the component's own element so the announcement survives the menu closing; **replace** the stale doc comment at `:22-25`. Addresses **DW-115**.
- `ui/src/app/shell/account-menu.spec.ts` -- extend for the second item, the roving-tabindex model, Arrow/Home/End wrap, dialog open, and focus return.
- `ui/browser/change-password.browser-spec.mjs` -- NEW browser spec (a new file, because `ui/browser/**` is contended): real focus movement through the two menu items, opening the dialog, a rejected change showing the instance's own reason, and a successful change leaving the tab signed in. Registration is the filename glob alone; it must import its origin from `browserConfig()` and never name a literal port.

**Acceptance Criteria:**

- Given a signed-in user, when they open the account menu, then it lists Change password and Sign out, each `role="menuitem"` with `tabindex="-1"`, and choosing Change password opens one `app-dialog` with both fields empty.
- Given the open dialog, when the user submits a correct current password and a policy-satisfying new password, then the request carries no username, the change is applied to `$Username`, the dialog closes, `Password changed` is announced politely, and focus returns to the menu trigger.
- Given a successful change, when the client makes its next `/api/ocupilot` call, then it still answers `200` — the tab is not signed out (AD-28).
- Given a new password the instance's policy refuses, when the user submits, then the dialog stays open and shows **the instance's own reason text**, on the `newPassword` field, via `aria-describedby`, with the error summary focused as `role="alert"`.
- Given an incorrect current password, when the user submits, then the refusal is a `422` violation on `currentPassword` — never a `401`, which would make the API service attempt a token renew.
- Given any failure on this route, when the response and every log line it produced are inspected, then neither contains either password value, in any form. **Integration AC:** the `ui/browser` spec drives the dialog against the throwaway instance and then asserts `OcuPilot.Kernel.Audit.Log`'s rows for the request hold no password substring.
- Given the account menu open with focus on the first item, when ArrowDown, ArrowUp, Home and End are pressed, then focus moves with wrap-around and Home/End jump to the ends, and the same code path behaves identically for three items. (**DW-115**)
- Given the dialog open, when Escape, Cancel or the scrim dismisses it, then no request is sent, no value is retained, and focus returns to the trigger.
- **Integration AC (Rule 1):** Given the consumer `ui/src/app/shell/change-password-dialog.ts` reading through `ui/src/app/core/account.ts` against the real `src/OcuPilot/Api/Account.cls` on the throwaway instance, when the browser spec submits a password the instance's policy refuses, then the observable effect is the instance's own reason text rendered in the dialog and wired to the `newPassword` field — produced by a real `422`, never a mock.

## Spec Change Log

- 2026-09-20, lead spec gate: AD-49 added to the governing ADs -- the lead wrote it into the spine at this gate, after the plan stage had run, so the plan could not have cited it. The `Router.cls` task changed from inserting the route between `/conversation` and `/instance` to appending it at the tail of `<Routes>`, and the wrapper likewise, per condition 1 of the orchestrator's shared-append grant. The grant and its four conditions are recorded under Design Notes.

## Review Triage Log

### 2026-09-20 — Review pass

- verdicts: 46 findings — high 0, medium 9, low 21, false 11, maybe-false 5
- findings:
  - `[medium]` `[patch]` blind-hunter: the dialog computes a five-way fault classification and always renders `connectivityServerFault` — verified; `panel.ts:606` and `fault-banner.ts:148` both branch on `fault.kind === 'unreachable'` off the same helper. Patched: `core/account.ts`'s error arm now carries the envelope's own `reason`, and the dialog renders that when present, else the unreachable/server-fault split, exactly as `panel.ts` chooses it.
  - `[low]` `[reject]` blind-hunter: `focusField()` treats an unknown field name as `newPassword` — real but only reachable if the server sends a third field name, which `Api/Account.cls` cannot; the fix adds a filter guarding state never demonstrated.
  - `[false]` `[reject]` blind-hunter: the class doc and `refuse()` disagree about where focus lands — refuted: `definition-form.page.ts:1069-1071` (`focusRefusal`, the precedent the spec's Code Map names) is byte-for-byte the same sequence, summary then field. This is the house contract, not a deviation. The residual gap — nothing pinned the focus destination — is patched below.
  - `[low]` `[patch]` blind-hunter: two of the four new `ReasonForViolation` arms are unreachable — verified; `ACCOUNT.VALIDATION` and `ACCOUNT.PASSWORD.BODY` are envelope codes, never violation codes. Patched: both arms deleted.
  - `[low]` `[defer]` blind-hunter: the `ACCOUNT.*` family is outside `AgentViolation`'s roster sweep — verified at `src/OcuPilot/Test/AgentViolation.cls:84` (`$Extract(tName,1,5) '= "AGENT"`). Widening it edits Epic 13's contended path; deferred, and the overstated doc sentence on `ViolationCodes()` was corrected in place.
  - `[low]` `[defer]` blind-hunter: `/account/password` contradicts the "N-segment before (N-1)-segment" invariant as that invariant is worded — verified: `check_route_ordering` implements only the leading-segments form and passes, and no route shares the `/account` prefix, so nothing misroutes. The tail-append is condition 1 of the orchestrator's grant; the wording lives in the spine and is the lead's to amend.
  - `[low]` `[defer]` blind-hunter: `Account.RenderViolations` duplicates `Definitions.RenderViolations` — verified; the helper fixes the envelope code at `AGENTVALIDATION`, so a shared renderer needs an optional `pCode` parameter on a file outside this footprint.
  - `[medium]` `[patch]` blind-hunter: the 500 fallthrough arm is untested and logs unexamined vendor text — split: the logging is spec-mandated ("the raw `%Status` reaches `Audit.Log.Error` only"), so `by-design`; the untested half is the same root cause as the verification-gap layer's first finding and is patched there.
  - `[low]` `[patch]` blind-hunter: `tRequestBody` still holds both passwords when the handler returns while the doc claims both are cleared — verified. Patched: the parsed body is dropped once the two locals hold the values, and on both remaining exits.
  - `[medium]` `[patch]` blind-hunter: the browser spec's "no password in a log line" assertion cannot fail — verified and demonstrated; grouped with the verification-gap layer's first finding, patched and now falsifiable.
  - `[false]` `[reject]` blind-hunter: AC6 named `Audit.Log`'s rows but the spec reads messages.log — refuted: `Kernel/Audit/Log.Emit` → `WriteConsole` → `%SYS.System.WriteToConsoleLog`, so messages.log **is** where `Audit.Log` writes. Same surface, not a substitution.
  - `[low]` `[patch]` blind-hunter: `.ocu-account-status` re-declares `.ocu-visually-hidden` byte for byte — verified at `_components.scss:3601-3610`. Patched: the menu uses the existing utility and the new rule is gone, which withdrew the `_components.scss` footprint extension entirely.
  - `[low]` `[patch]` blind-hunter: the new browser spec loads strings by a route no sibling uses — verified; six specs use `loadStrings()` from `../tools/strings.mjs`. Patched (it also removes the `MODULE_TYPELESS_PACKAGE_JSON` warning the run emitted).
  - `[low]` `[defer]` blind-hunter: the empty-field reason reuses `openApiRequired`, published against another screen's row — verified; `strings.test.mjs` asserts an exact key count and the spec allowed exactly six, so reuse was forced. Reconciling the table row is a planning-artifact edit beyond the two EXPERIENCE.md edits the grant covers.
  - `[low]` `[patch]` blind-hunter: `strings.ts` is edited but missing from `footprint_extensions` — verified. Patched: declared (frontmatter bookkeeping the orchestrator's merge gate reads, not a spec-content change).
  - `[medium]` `[defer]` blind-hunter: Enter does not submit the dialog — verified: no `<form>`, and `dialog.ts` has no Enter binding. No existing `app-dialog` call site carries a text input, so there is no house pattern this departs from; a form inside the projected content is not a trivial fix.
  - `[false]` `[reject]` blind-hunter: no ObjectScript suite was reported although `Api/Error.cls` changed — refuted by this stage's own runs: the full `OcuPilot.Test` package ran on the throwaway (131 classes, 1,267 tests, 0 failed), `Envelope` and both `AgentViolation` roster tests among them.
  - `[false]` `[reject]` blind-hunter: a third browser failure was dismissed rather than explained — refuted for this tree: this stage's full suite lost exactly one test, the named inherited DW-1169 case; `suggested-view` passed.
  - `[low]` `[patch]` blind-hunter: nothing pins the busy guard — verified: `submit()` raises `busy` before awaiting and the action carries only `aria-disabled`. Patched with a two-press case asserting one request.
  - `[medium]` `[defer]` blind-hunter: the wire test's policy assertion reproduces `PolicyText`'s own index-2 assumption — verified; both sides would move together. Settling it needs an independent location of the allow-listed code's text, which is more than a direct correction.
  - `[low]` `[patch]` blind-hunter: the spec's Verification names `dist/ocupilot/browser/.` but the builder writes `dist/ocupilot-ui` — verified against `ui/angular.json`. Patched in `## Verification`, which Rule 19 names a tracking section.
  - `[medium]` `[defer]` edge-case: `POLICYCODES` is closed to 845/958, so a `PasswordValidationRoutine` refusal answers 500 — **measured** on the throwaway: with a validation routine configured, `ChangePassword` returns `1446,5001` carrying the routine's own sentence, outside the allow-list. Real and user-visible on such an instance, but widening the list contradicts the matrix's explicit "pass the text through only for 845 and 958" and AD-39's normalization rule — spec-bound, so it is the lead's call, not a patch.
  - `[medium]` `[defer]` edge-case: a refusal that is not a wrong password (838 no-such-user, 959 disabled, a delegated account) answers an opaque 500 — same root cause as the entry above; grouped with it. The route cannot distinguish wrong-password from no-such-user because `$Username` is always the authenticated caller, so the Never-clause holds; what diverges is the Design Notes' prediction that a delegated user "sees the instance's own refusal text".
  - `[false]` `[reject]` edge-case: `refuse()` never leaves focus on the summary — refuted with the blind-hunter's duplicate above, against `definition-form.page.ts:1069-1071`.
  - `[medium]` `[patch]` edge-case: dismissing the dialog while the POST is in flight changes the password with nothing announced and emits on a destroyed output — verified: Escape is reachable throughout the await. Patched with a `finished` re-check immediately after the await.
  - `[medium]` `[patch]` edge-case: fault kinds are not distinguished — duplicate of the blind-hunter's first finding; same patch.
  - `[low]` `[defer]` edge-case: a read or decode fault is answered 422 as a client body error, against DW-24 — verified: `Context.cls:44-53`, the precedent the spec names, does split them. Patched, then **reverted**: no constructible input reaches those stages (an invalid-UTF-8 body parses through to the change), so the split adds a branch no test can exercise. Deferred with that evidence rather than shipping an unpinned branch.
  - `[maybe-false]` `[reject]` edge-case: `ChangePassword` may return 0 without assigning its status, logging nothing — the defensive `$Get(tChangeSC, $$$OK)` already exists; nothing shows the vendor call can do this, and the proposed guard adds a branch on undemonstrated state.
  - `[low]` `[reject]` edge-case: a violation naming an unknown field renders an unlabelled summary entry — duplicate of the blind-hunter's second finding; same reasoning.
  - `[maybe-false]` `[reject]` edge-case: a menu keydown with `document.activeElement` outside the items makes ArrowUp land second-to-last — the panel is not focusable, the first item takes focus on open, `onMenuMouseDown` prevents the default that would move it, and the two document handlers close the menu when focus leaves it; no reachable path was shown.
  - `[low]` `[patch]` edge-case: `REASONACCOUNTPASSWORDPOLICY` is documented as a fallback but is unreachable — verified: the newPassword arm was entered only when the text was non-empty, so a matched code with no text answered 500. Patched: `PolicyText` now reports the match separately from the text, so a matched policy code always renders the violation and the published sentence is the real fallback.
  - `[medium]` `[patch]` verification-gap: the body-refusal branch is the only code on this route that logs, and no test read a log after triggering it — pre-verified and confirmed by demonstration. Patched: the browser spec now POSTs a malformed body carrying the live password before reading messages.log back, and the mutation that reverses the guard reddens it.
  - `[medium]` `[patch]` verification-gap: `core/account.ts` classifies the fault and the dialog discards it — duplicate of the blind-hunter's first finding; same patch, plus a dialog case asserting the unreachable sentence.
  - `[medium]` `[patch]` verification-gap: nothing types into the two dialog fields, so `readonly` would pass every test — pre-verified. Patched: the browser spec fills the current-password field with real key presses and asserts the value arrived.
  - `[low]` `[patch]` verification-gap (Rule 19): AC3, AC6 and AC8 have no `mutation:` line, and the Integration AC's lives only in a test comment — verified. Closed in-pass: all four mutations named, applied, observed red, reverted, and written into `## Verification`; the tree was byte-identical either side.
  - `[low]` `[patch]` verification-gap (other): the `ViolationCodes()` doc overstates what the wire test holds, and the carve-out changes nothing — verified. Patched: the sentence now says the list is `AGENT.*` because its test sweeps that prefix, and names the two `ACCOUNT.*` codes the wire test actually asserts.
  - `[low]` `[patch]` verification-gap (other): `REASONACCOUNTPASSWORDPOLICY` and the two envelope-code arms are unreachable — grouped with the two entries above; same patches.
  - `[low]` `[reject]` verification-gap (other): `account.ts`'s `fault ?? {...}` fallback is dead — true, and its own comment says so; removing it needs a non-null assertion, which is more complexity than the dead branch.
  - `[medium]` `[reject]` intent-alignment D1: the Problem's second clause (the sign-in expired-password banner) is untouched and the reading was taken silently — verified, and there is exactly one possible reading: `/api/ocupilot` is Bearer-only (AD-28) and `session.ts:49-59` records `password-expired` as having no trigger on this build, so the banner's user provably cannot reach this flow. Not an intent gap; the reading is recorded in this spec's result section.
  - `[false]` `[reject]` intent-alignment D2: the summary-focus divergence — refuted above, against `definition-form.page.ts:1069-1071`.
  - `[low]` `[defer]` intent-alignment D3: three naming conventions now exist for a reveal toggle — verified; `sign-in.ts` and `definition-form.page.ts` already differed before this story, so reconciling them is not this change's to make.
  - `[low]` `[patch]` intent-alignment D4: "never store it in the client session" is asserted everywhere except browser storage — verified. Patched: the browser spec now reads `sessionStorage` and `localStorage` back and asserts neither password is in either.
  - `[false]` `[reject]` intent-alignment D5: the server's malformed-body reason is authored, tested and never displayed — refuted as of this pass: the dialog now renders the envelope's own `reason`, so that sentence reaches the user, with a case pinning it.
  - `[low]` `[reject]` intent-alignment D6: the keyboard model is a second copy rather than a shared helper — the spec's task list says "copied from `data-table.ts:811-839`"; extracting a shared helper would alter specified behavior.
  - `[low]` `[patch]` intent-alignment D7: `Parameter CHANGEFAILEDCODE` is declared and never read — verified by search. Patched: deleted, with its one load-bearing sentence (why containment, not equality) folded into `WRONGPASSWORDCODE`.
  - `[low]` `[defer]` intent-alignment D8: `EXPERIENCE.md:395` still reads "polish week adds Change password" and `:505` is D1's row — verified; both are beyond the two EXPERIENCE.md edits the shared-append grant covers.

## Design Notes

**Governing ADs (Rule 6):** **AD-49** (this story is the AD's originating case: a self-service account action is the user's own write, outside the agent write path, calling the documented `%SYSTEM.*` method in the caller's process -- written into the spine at this story's spec gate), AD-8 (the mechanism: process privilege, no elevation, no service account), AD-12 and AD-39 (one envelope; `detail.violations[]` as `{field, code, reason}`; vendor text normalized before it reaches either consumer — which is why exactly two error codes are allow-listed for pass-through), AD-16 (no `%SYS` switch is needed: `%SYSTEM.Security` resolves from any namespace, as the vendor's own portal dialog demonstrates), AD-19 (framework-free `core/`, components mirror), AD-20 (absolute path through the one API service), AD-21 and AD-35 and Conventions › Secrets (nothing secret reaches a surface OcuPilot displays), AD-28 (Bearer-only; the change does not end the session), AD-5 (shell chrome, so no screen descriptor — `Screen/Descriptor/Home.cls` is untouched), AD-15 (agent-write markers; this is a human write), AD-27 and AD-1 and AD-40 (the admin API stays in `AdminPort`; this is not a tool and never reaches the confirm path), AD-47 (no password in any browser storage). Conventions rows: REST route ordering, Error shape, Status handling, Secrets, Tests, Client asset homes.

**Why not the admin API.** The epic context maps this story to the admin API's user-password route. That route is verified to exist (`POST /api/admin/v2/security/user/password`, body `{"NewPassword"}`), and it is verified to be wrong here on three counts: it requires `%Admin_Secure`, which is the elevation AD-8 forbids and which "as any user" rules out; it takes no old password, so it is an administrative reset rather than a self-service change; and `AdminPort`'s `Parameter TYPESUFFIXES` admits read types only, so the port cannot reach it. The PRD's API preference order puts a documented official route first, and `$System.Security.ChangePassword` is one — it is what the Management Portal's own change-your-own-password dialog calls, as `$Username`, with no declared resource. That route belongs to Story 7.2, which is the admin-sets-another-user case.

**No OcuPilot audit marker.** IRIS itself emits `%System` / `%Security` / `UserChange` for this operation — registered, enabled by default on this build, and firing on failures as well as successes, carrying the actor and the outcome and no password (measured on slot C). AD-15 binds *agent* writes; OcuPilot's audit screen shows the vendor row like any other (AD-46). A second record would add review surface and no information.

**Declined: the delegated-user pre-check.** The vendor's dialog calls `$$UserCanChangePassword^%SYS.SECURITY($Username,.AllowEdit)` to hide the fields for users whose passwords IRIS does not own. This story does not, because that entry point lives in unreadable object code and a bare `$$entry^ROUTINE` into a vendor internal is the coupling AD-27's containment exists to prevent. Observable cost, stated rather than hidden: such a user sees the instance's own refusal text instead of a tailored one.

**Contended and out-of-footprint paths, declared (Rule 11).** The orchestrator granted shared-append on `Api/Router.cls` and `EXPERIENCE.md`, epic-wide, on 2026-09-20, against Epic 5's pushed head `d956ff5`. Four conditions bind every such edit: append only at the tail, never reorder, never insert, never touch a line another epic added; run `uv run scripts/check-objectscript.py` before every commit touching `Router.cls` and quote its result; report each edit under `footprint_extensions:` with the Epic 5 head sha checked at that moment; merge conflicts are the orchestrator's to resolve as unions.

- `src/OcuPilot/Test/AccountPasswordWire.cls` — **contended**, `src/OcuPilot/Test/**` is Epic 13's. It is unavoidable: `check_handler_wire_tests` makes a wire test under that exact directory a build gate for any new route, and `check_package_placement` pins classes to the seven roster packages, so there is no alternative home. It is a new file with a name no other epic would pick.
- `_bmad-output/planning-artifacts/ux-designs/.../EXPERIENCE.md` — a shared UX planning artifact. Editing it is the established path for a new string (50 commits; `78ae4a8` is a story adding rows and keys in one commit), and `strings.test.mjs` makes it the *only* compliant path.
- `src/OcuPilot/Api/Router.cls`, `src/OcuPilot/Api/Error.cls`, `ui/src/app/core/violations.ts` (read only) — outside Epic 15's footprint, owned by no concurrent epic. Both edits are appends.

**Two planning-artifact wordings to correct at their origin** (recorded, not worked around): FR-73's done-condition reads "reachable from the header or Home", while every specific contract — the story's own AC, `EXPERIENCE.md:395`, `:81`, `:56`, `DESIGN.md:1023` — puts Change password in the status bar. Nothing observable turns on it. And NFR-5 names API keys, private keys and wallet secrets but not user passwords, so the write-only discipline for *this* secret rests on FR-36 and `EXPERIENCE.md:414` rather than on the NFR the story would naturally cite.

**Consumes:** `ui/src/app/shell/dialog.ts` (the shared dialog contract); `ui/src/app/core/api.ts` and `violations.ts` (transport and refusal decoding); `ui/src/app/core/session.ts` (`userName()`); `OcuPilot.Api.Definitions.RenderViolations`; `OcuPilot.Kernel.Utils.ReadRequestBody`.

**Consumed-by:** Story 15.6 (the theme toggle becomes the account menu's third `role="menuitem"` and inherits this story's keyboard model — build it n-item, never two-item). No other story consumes `core/account.ts` or `Api/Account.cls` in Release 1; the first re-use would be a later self-service account action.

**DW-115 — addressed, not declined.** The ledger entry's stated reason for accepting it was that "there is no UX contract to build against". There is one: `DESIGN.md:1023` styles the account menu *as* `row-overflow-menu`, and `DESIGN.md:1060` gives that component a keyboard-active state and says "a menu item's focus is virtual", while `EXPERIENCE.md:411` and `:216` both require gated menu entries to stay "arrow-reachable". The model is therefore already assumed; this story implements the house version of it from `data-table.ts` rather than inventing one.

## Verification

**Commands** (slot C — every IRIS MCP call carries `server: "ocupilot-slot-c"`; the dev container is `ocupilot-slot-c`; the throwaway is `--dir /tmp/ocupilot-c-ci --project ocupilot-c-ci --web 52779 --super 1978`):

- `cd ui && npm test` -- expected: `node --test tools/*.test.mjs` green including the new `account.test.mjs` and an unchanged-count `strings.test.mjs`, then the Angular runner green including both new specs.
- `cd ui && npm run build` -- expected: all six `prebuild` checkers pass. `client-lint.mjs` is the one that bites: every visible word must be `{{ STRINGS.<key> }}`, every `aria-label` must be exactly one interpolation, every non-ASCII byte must be a `\uXXXX` escape, and every `@if` condition must be a paren-free member reference (use a getter over the signal, as `dialog.spec.ts:42-44` documents).
- `uv run scripts/check-objectscript.py` -- expected: clean, including `check_handler_wire_tests` for `/account/password`, `check_route_ordering`, `check_destructive_test_guard` and `check_escalation_containment`.
- `bash scripts/lint-docs.sh` -- expected: clean over the amended EXPERIENCE.md.
- `bash scripts/smoke.sh --container ocupilot-slot-c --user _SYSTEM --password SYS` -- expected: non-zero executed checks, all passing.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52779 OCUPILOT_BROWSER_CONTAINER=ocupilot-c-ci npm run test:browser` -- expected: the new spec green. Rebuild and `docker cp dist/ocupilot-ui/browser/.` into the throwaway first (`ui/angular.json` sets `outputPath: dist/ocupilot-ui`); the spec reads the deployed bundle, not the working tree.

**Manual checks:**

- Confirm on a throwaway that the policy-rejection path actually fires before claiming it is pinned: `PasswordPattern` is `3.255ANP` and `PasswordValidationRoutine` is empty on this build, so only a password shorter than three characters is refused. A test that assumes a complexity rule passes for the wrong reason.
- Confirm the embedded code for a policy rejection is `845` (or `958`) before hard-coding the allow-list; only `1446,952` for a wrong old password has been measured.
- After any failed request, read `OcuPilot.Kernel.Audit.Log`'s rows and the container's messages.log and confirm neither password value appears.

**Lead AD gate (AD-49), executed by the lead on the slot C throwaway `ocupilot-c-ci`, 2026-09-20:**

- `mutation: OcuPilot.Api.Account.CallerUsername() returns "_SYSTEM" instead of $Username -> OcuPilot.Test.AccountPasswordWire went red, 2 of 4 methods` -- `TestZCorrectChangeSucceedsAndLeavesTheAccountAuthorized` on "the change is applied" and "the account is still authorized with the new password", and `TestAPolicyRefusalCarriesTheInstancesOwnText` on all three of its assertions. Baseline before the mutation was 4/4 pass read from `%UnitTest_Result`, not from the runner envelope; after revert and recompile it is 4/4 again, with `CallerUsername()` read back live. The copy mutated was the throwaway's deployed one under `/tmp/ocupilot-c-ci/src`, so the working tree was byte-identical throughout rather than restored afterwards. This pins AD-49's load-bearing claim: the change runs as the **calling** user, never a name supplied from anywhere else.
- Read-only premises checked on the instance rather than recalled: `%System`/`%Security`/`UserChange` reads `exists=1 enabled=1` on slot C, which is what AD-49 rests on when it says OcuPilot adds no second audit record; and `Api/Account.cls` carries no `$System.Security.Audit` call, no `%SYS` switch, no `New $ROLES` and no tool registration -- its only `proposal` and `$ROLES` matches are the doc comment asserting their absence.


**Mutations (Rule 19)** -- each applied, observed red, reverted, and the tree confirmed byte-identical after:

- mutation: `Account.WRONGPASSWORDCODE` 952 -> 953 → `AccountPasswordWire.TestAWrongCurrentPasswordIsAViolationOnThatField` red (AC5).
- mutation: `Account.POLICYCODES` `"845,958"` -> `"958"` → `AccountPasswordWire.TestAPolicyRefusalCarriesTheInstancesOwnText` red (AC4).
- mutation: `Account.HandlePasswordChange`'s extra-member test replaced by `If 0` → `AccountPasswordWire.TestAMalformedBodyIsOneRefusalNamingNoValue` red (matrix "Malformed body").
- mutation: `ChangePassword` sent `tCurrent` as the new password → `AccountPasswordWire.TestZCorrectChangeSucceedsAndLeavesTheAccountAuthorized` and the policy test red (AC2, AC3).
- mutation: `account.ts` decided `rejected` from `result.status === 422` rather than from `violationsOf` → `account.test.mjs`'s body-refusal and unreadable-violations rows red.
- mutation: `account.ts` sent the two members as `oldPassword`/`password` → `account.test.mjs`'s request row red.
- mutation: `change-password-dialog.ts` lost its empty-field guard → the dialog spec's "Empty field" case red.
- mutation: `change-password-dialog.ts` returned `describedBy: null` → the dialog spec's AC4 and AC5 cases red.
- mutation: `change-password-dialog.ts` kept the two input values after a success → the dialog spec's AC2 case red.
- mutation: `account-menu.ts`'s arrow model clamped instead of wrapping → the menu spec's two DW-115 cases red, and -- after a rebuild and a `docker cp` of the bundle into the throwaway -- `change-password.browser-spec.mjs`'s AC7 case red.
- mutation: `account-menu.ts` dropped `tabindex="-1"` from the first item → the menu spec's AC1 case red.
- mutation: `account-menu.onPasswordChanged` announced `''` → the menu spec's AC2 case red.

Added at the review pass, each applied, observed red, reverted, and the tree confirmed byte-identical
(9 modified + 7 untracked, `405 insertions(+), 33 deletions(-)`, unchanged either side):

- **AC3** -- mutation: `change-password-dialog.submit()` calls `sessionStorage.clear()` on success →
  `change-password.browser-spec.mjs`'s "AC2, AC3, AC6" case red on *the tab is still authorized after
  the change*. Rebuilt and `docker cp`-ed before reading.
- **AC6 (the log half)** -- mutation: `Api/Account.HandlePasswordChange` logs the parsed body through
  `Fault.LogRaw` → the same case red on *no password value reaches a log line*. Before this pass the
  assertion could not fail: the route's only logging branch is the body refusal, and the spec drove
  nothing through it. It now sends a malformed body whose two members are the live password first.
- **AC8** -- mutation: `account-menu.chooseChangePassword()` drops `closeAndRefocus()` for a bare
  `openFlag.set(false)`, so the trigger is never focused before `app-dialog` mounts → that spec's
  "AC8: Escape on the open dialog" case red on the focus destination.
- **Integration AC** -- mutation (recorded here rather than only beside the test): the violation's
  `reason` in `Api/Account.RenderChangeRefusal` becomes `..#REASONACCOUNTPASSWORDPOLICY` →
  `change-password.browser-spec.mjs`'s "Integration AC, AC4" case red, because the rendered sentence
  is then OcuPilot's fallback and not the instance's own.

## Auto Run Result

Status: done
Blocking condition: none

**What shipped.** `POST /api/ocupilot/account/password` calls
`$System.Security.ChangePassword($Username, new, old, .tSC)` in the caller's own process (AD-49,
AD-8) and maps the outcome to one AD-12 envelope: `200 {}`, a 422 violation on `currentPassword`
or on `newPassword` carrying the instance's own sentence, or a 500 whose detail reaches the log
alone. The account menu gained Change password above Sign out with the house n-item keyboard model
(DW-115), and a dialog over two masked, write-only fields.

**Files.** `Api/Account.cls` (new handler), `Api/Error.cls` (four `ACCOUNT.*` codes and their
sentences), `Api/Router.cls` (tail-appended route and wrapper), `Test/AccountPasswordWire.cls` (new
wire test); `core/account.ts` + `tools/account.test.mjs`, `shell/change-password-dialog.ts` +
`.spec.ts`, `shell/account-menu.ts` + `.spec.ts`, `core/strings.ts` (six keys),
`browser/change-password.browser-spec.mjs` (new); `EXPERIENCE.md` (one row appended at `:381`, the
Dialogs line amended in place at `:173`); `status-bar.spec.ts` and `browser/panel.browser-spec.mjs`
each one assertion, forced by the second menu item.

**Review.** 46 findings across four layers: 0 high, 9 medium, 21 low, 11 false, 5 maybe-false.
Patched 14 entries — 4 medium (the dialog discarded `classifyFault`'s verdict and always said
"check messages.log"; the route's only logging branch had no test reading a log after triggering
it; dismissing the dialog mid-request changed the password with nothing announced; no test ever
typed into either field, so `readonly` would have passed everything) and 10 low. Deferred 11.
Rejected 21, the substantive ones being: the summary-focus "deviation" (refuted — it is
`definition-form.page.ts:1069-1071`'s sequence exactly), AC6 reading messages.log rather than
`Audit.Log` (refuted — `Audit.Log.Emit` writes to messages.log), and the sign-in expired-password
banner being left alone (exactly one reading is possible: the API is Bearer-only per AD-28 and
`session.ts:49-59` records `password-expired` as having no trigger on this build, so that banner's
user cannot reach this flow).

One patch was applied and then **reverted**: splitting the body read's `read`/`decode` stages from
`parse`, as `Context.cls:44-53` does, could not be pinned — no constructible input reaches those
stages (an invalid-UTF-8 body parses straight through), so it would have added an unexercised
branch. It is deferred with that evidence instead.

**Verification** (slot C; throwaway `ocupilot-c-ci` on 52779/1978, brought up and torn down by this
stage). `uv run scripts/check-objectscript.py` clean, 21 rules over 496 files, 0 problems —
re-run after every `Router.cls`-touching change. `bash scripts/lint-docs.sh` clean, 92 files.
`npm test` 1,055 tools tests and 664 component tests, 0 failed. `npm run build` clean through all
six prebuild checkers. `smoke.sh --container ocupilot-slot-c` 45 executed, 45 passed;
`--container ocupilot-c-ci` the same on a fresh install of this tree. The full `OcuPilot.Test`
package on the throwaway: 131 classes, 1,267 tests, 0 failed. Browser suite 190 tests, 189 passed;
the single failure is the inherited `ui/browser/context-chip.browser-spec.mjs` "Cap follows
agent-switch" (DW-1169), Epic 5's file and open defect — named, not repaired. The new
`change-password.browser-spec.mjs` is 4/4 on its own and in the full run.

**Follow-up review recommended: true.** Four medium entries were patched. The named unverified
risk: the dialog's error arm was reworked in the review pass — it now renders the envelope's own
`reason` and otherwise picks the connectivity sentence off `classifyFault` — and the mid-flight
dismissal guard was added beside it. Both are pinned only by component cases against stubbed
answers; no browser case drives a genuinely unreachable instance or a real dismissal during an
in-flight request.

**Residual risks.** The two measured `deferred` entries are the ones that reach a user: on an
instance configured with a `PasswordValidationRoutine`, a real policy refusal returns `1446,5001`
(measured) and falls outside the closed `845,958` allow-list, so it renders as an internal error
rather than the instance's reason; the same closed list turns a delegated or LDAP account's refusal
into an opaque 500, against the Design Notes' stated observable cost. Both are spec-bound —
widening the list contradicts the matrix's explicit "only 845 and 958" and AD-39 — so they are the
lead's call, not this pass's.
