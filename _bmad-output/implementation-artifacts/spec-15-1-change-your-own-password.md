---
title: 'Story 15.1: Change your own password'
type: 'feature'
created: '2026-09-19'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-15-context.md'
warnings: ['oversized']
deferred: []
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
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52779 OCUPILOT_BROWSER_CONTAINER=ocupilot-c-ci npm run test:browser` -- expected: the new spec green. Rebuild and `docker cp dist/ocupilot/browser/.` into the throwaway first; the spec reads the deployed bundle, not the working tree.

**Manual checks:**

- Confirm on a throwaway that the policy-rejection path actually fires before claiming it is pinned: `PasswordPattern` is `3.255ANP` and `PasswordValidationRoutine` is empty on this build, so only a password shorter than three characters is refused. A test that assumes a complexity rule passes for the wrong reason.
- Confirm the embedded code for a policy rejection is `845` (or `958`) before hard-coding the allow-list; only `1446,952` for a wrong old password has been measured.
- After any failed request, read `OcuPilot.Kernel.Audit.Log`'s rows and the container's messages.log and confirm neither password value appears.

**Mutations (Rule 19):** each AC's pinning test is named above; the implement stage records `mutation: <what was changed> → <which test went red>` here for each, and rebuilds and redeploys the bundle before reading any browser result.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
