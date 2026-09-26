---
title: 'Story 14.1: The copy-out draft'
type: 'feature'
created: '2026-09-26'
status: 'done'
baseline_revision: '9e0830f89b979d82b14597eda613eaf1740ce2bb'
baseline_commit: '9e0830f89b979d82b14597eda613eaf1740ce2bb'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-14-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** A production administrator whose changes go through change control cannot let the agent write, so every agent proposal is a dead end: the only way out of a live card is to confirm or cancel it. Reply code blocks also lack the copy icon button DESIGN.md gives them (DW-1081).

**Approach:** Add "Give me the script instead" to every live proposal card. The instance renders a REST or ObjectScript script from the proposal's stored arguments through the tool's own declared contract (its endpoint, request type, body composition and port). Rendering runs no write. The proposal then closes as `canceled` with the reason `draft`, and the card shows the script on the code surface with a copy control. That copy control is built once and also added to reply code blocks.

## Boundaries & Constraints

**Always:**

- The script is built on the instance from the stored row: `Arguments`, `Payload`, `TargetRef` and `ToolName`.
  - Endpoint, request type, id parameter, query and body come from the same `Operation` accessors and tool hooks that Confirm uses. These are `PortClassOf`, `WriteType`, `SendsBody`, `SecretBody`, `Query`, the tool's `DerivedFields`, and the port's own body transformation.
  - Nothing is ever taken from a per-tool table.
- Each port that defines `Invoke` also defines, in the same class, a pure `Snippet` and `SnippetForm` that mirror every branch `Invoke` takes.
  - A branch that reaches the admin API renders a `rest` step: `curl -u '<caller user name>' -X <verb> '<origin>/api/admin/v2<url>?<query>'`, plus a JSON body when the write sends one. The verb and URL come from the checked-in route table.
  - A branch that calls a documented `%SYS` class renders an `objectscript` step that makes that call, in `%SYS`.
  - A tool that overrides `AfterWrite` defines `SnippetAfter`, which renders its extra step or steps.
- No secret value is ever carried. Each of the following is replaced with the literal placeholder `"<Name>"`, in the body and in the query:
  - every name the tool declares secret: `SecretArguments`, `SecretBodyNames`, and `ToolFields` rows of class `secret`;
  - every name matching `Kernel.Audit.Log.IsCredentialName` (the backstop).
- Taking the script is user-originated. It is refused 403 `PROPOSAL.FROMTURN` when `Caller.IsTurn()` is set (AD-40).
- The draft resolves the proposal only through `Propose.GuardedClose(id, user, REASONDRAFT)`, the conditional `live` close that Cancel uses (AD-34).
- The instance evaluates `Prohibited.Prohibits` over the stored payload and diff before it renders a script. A prohibited effect is refused with the confirm path's code and reason, and the row stays live.
- Every new string is copied verbatim from EXPERIENCE.md's Fixed strings.

**Never:**

- Taking the script never calls a port `Invoke`, never mints anything, and never opens or burns a token.
- It never writes a ledger row, never emits an agent marker (AD-15 covers only executed writes), and never publishes a change event.
- It never calls the provider or starts a turn.
- It is not a tool, not in the registry, and has no governance key. `Kernel/Governance/Gate.cls` is untouched.
- The script is never persisted and never enters screen context, a tool result or the model.
- No `innerHTML` and no evaluated text.
- Do not edit `Kernel/Proposal/Confirm.cls`, `proposal-card.spec.ts` or `proposal-card.ts:662-672`, and stay off the Epic 16 hunks listed in Design Notes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Merge write | Live `webapp.list.update` proposal. Owner sends `POST /proposal/:id/draft` | 200 `{proposalId, state:"canceled", closedReason:"draft", draft:{steps:[{kind:"rest", text}], placeholders:[]}}`. The body is the complete stored payload plus derived fields. The application reads back unchanged. Ledger row count and marker count are unchanged | none |
| Secret-only body (AD-56) | Live `permissions.users.password` proposal | A `rest` step whose body carries `"<Password>"` under the vendor's wire name, followed by the `SnippetAfter` flag step when the stored subject has the flag set. `placeholders` names each secret | none |
| %SYS completion (AD-27, AD-48) | Live `logs.applicationerrors.delete` or `osmgmt.processes.terminatewitherror` proposal | `objectscript` steps calling `SYS.ApplicationError.DeleteByError` once per enumerated entry, or the `SYS.Process` terminate call `ProcessPort` makes | none |
| Create (AD-54) | Live create proposal | The `rest` step carries the composed body, with the id as the user typed it | none |
| Not takeable | The row is expired, already terminal, someone else's, or unknown | 404 `PROPOSAL.UNKNOWN`. No script. The row is unchanged | The card shows the row's state from the poll |
| Turn caller | Draft called while `Caller.IsTurn()` is set | 403 `PROPOSAL.FROMTURN`. The row stays live | none |
| Prohibited effect | Live proposal whose effect `Prohibits` refuses | The confirm path's prohibited status, code and reason. The row stays live. No script | The card shows the reason in its refusal slot and keeps its buttons |
| No script form | The port or type has no form at runtime | 409 `PROPOSAL.NODRAFT`. The row stays live | Unreachable while the registry test is green |
| Race | A confirm and a draft of the same row, concurrently | Exactly one wins the `State='live'` predicate. A losing draft returns 404 and discards its script | none |
| Clipboard | A copy is pressed in a non-secure context, or the clipboard is refused | Fallback: a hidden textarea plus `execCommand('copy')`. If that fails, the failure sentence is announced and the text stays selectable | Nothing is thrown to the console |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/State/Propose.cls:36-47`. The `REASON*` parameters, where `REASONDRAFT = "draft"` is added. Also `GuardedByKey` :289, `GuardedExpireStale` :475, `GuardedClose` :420 and `RowValues` :607 (the streams as text). `WireRow` :657 already carries `closedReason`.
- `src/OcuPilot/Kernel/Proposal/Confirm.cls:188-200`. `Cancel` is the pattern to copy: the `IsTurn` refusal, then `GuardedClose`, then `Answer` :751. Lines 358-365 are the body composition to mirror. Read these; do not edit the file. `WithSecrets` :661 and `ToolDerivedFields` :691 are Private.
- `src/OcuPilot/Kernel/Proposal/Operation.cls`. The public accessors are `PortClassOf` :49, `WriteType` :77, `SendsBody` :91, `SecretBody` :113 and `Query` :173. `ApplyAt` :371 is the call and `AfterWrite` sequence the script mirrors. `Gate` :297 shows how `Prohibits` is called and how it answers.
- `src/OcuPilot/Kernel/Proposal/Write.cls`. Holds the proposal codes, including `FROMTURN`. `PROPOSAL.NODRAFT` is added here.
- `src/OcuPilot/Screen/Tool/Write.cls`. Holds `Endpoint` :476, `IdParam` :497, `SecretArguments` :525, `SecretBodyNames` :533, `DerivedFields` :291 and `FieldRows` :592. Read only; this file is contended.
- `src/OcuPilot/Screen/Tool/Registry.cls:106`. `ListTools` returns 76 write tools. `Test/SurfaceCoverage.cls:229` `DeriveWriteTools` is the iteration pattern to copy.
- `src/OcuPilot/Port/*.cls`. Every port has `Invoke(pEndpoint, pType, ByRef pQuery, pBody, …)`. Measured on this branch, write tools declare 12 ports.
  - Admin-endpoint writes: `AdminPort` (38 tools), plus `TaskPort`, `WalletPort`, `TokenPort`, `OAuthClientPort` and `AuditPort`.
    - `AuditPort` composes `COPY`/`PURGE` bodies at :347.
  - Transforming ports: `OAuthResourceServerPort` maps its mapping types, and `OAuthAuthorizationServerPort` `CHANGEPWD` builds its body at :260-289.
  - Writes that call a `%SYS` class directly:
    - `ProcessPort` :93
    - `OAuthAuthorizationServerPort` `ROTATEKEYS` :339
    - `OAuthRegisteredClientPort` :392/:405
    - `OAuthServerPort` :356/:363
    - `LogSourcePort` `DeleteByError` :1291. This port extends `%RegisteredObject`, not `AdminPort`.
- `src/OcuPilot/Port/AdminPort.cls`. The wire-shape parameters `WRAPPEDTYPES` :444, `RENAMEDTYPES` :456, `CONSTANTBODIES` :473 and `QUEUEDWRITES` :481. AD-27's named completions live in its `Invoke` branches: `Security.Resource` with an empty permission, `X509Credential` POST from content, and `WebApp.App` PUT re-applying `Type`.
- `%Api.Admin.Dispatch.v2` on the instance, in `%SYS`. Measured on `ocupilot-slot-b`, its `UrlMap` has 271 routes, each `Url`, `Method`, `Call`, with no path params. The id travels as a query parameter.
  - Each `Call` body names `%Api.Admin.Endpoints.<X>` and a type:
    - `#TYPE<NAME>`: 68 routes.
    - `..Type<Verb>()`, meaning `%Api.Admin.Endpoint.#TYPE<VERB>`: 196 routes.
    - Seven Monitor `GET`s use other parameters.
  - The derivation is therefore structural. Only `AdminPort` may name these classes (AD-27).
- `src/OcuPilot/Test/Inventory.cls` and `Test/DerivedFields.cls`. The idiom for "a checked-in table held equal to a fresh derivation".
- `src/OcuPilot/Kernel/Audit/Log.cls:179`. `IsCredentialName`.
- `src/OcuPilot/Api/Router.cls:127-128` holds the proposal routes, `ProposalCancel` :744, and `Api/Confirm.cls` `HandleCancel`. The coverage roster is at `Test/EndpointCoverage.cls:116-117`, and the HTTP harness is `Test/RouterFixture.cls`. Proposals are seeded with `Test/ProposalFixture.cls`.
- `ui/src/app/core/proposal-view.ts`. `ProposalPhase` :213, `TERMINAL_PHASES` :225, `phaseForState` :263 and `statusLineFor` :359.
- `ui/src/app/shell/proposal-card.ts`. The buttons are at :314-336, and outputs at :383-389. The `[card-footer]` slot :271 is where the panel projects the script.
- `ui/src/app/shell/panel.ts`. The card bindings are at :461-471, `onCardCancel` :1284 and `setCardPhase` :1321. `ui/src/app/core/turn.ts` has `cancelProposal` :1132 and `decideProposal` :1150.
- `ui/src/app/core/reply.ts:363-370`, where `pre.ocu-reply-pre > code.ocu-reply-code-block`. In `ui/src/app/shell/reply.ts`, the DOM is built with `createElement` (:34-57), DOMPurify runs at :84-92 and the chip `WeakMap` click handler is at :153-160.
- `ui/src/styles/_components.scss`. `.ocu-reply-pre` is at :3890-3908, `.ocu-panel-icon-button` :3177 (the icon-button idiom), and `ocu-focus-ring` :41 with its code-surface uses at :4112 and :4617.
- `ui/src/app/core/strings.ts:104-107,154-165`. The action and status keys. The file holds one key per distinct value (`ui/tools/strings.test.mjs:701-711`), and "Copy" is already `auditDatabaseCopyConfirm`. The `EXPERIENCE.md:n` pins are at `strings.test.mjs:755-799`.
- EXPERIENCE.md. `:269` is the action-names row, `:272` the live-card captions and `:275` the status-line row. `:210` already names the action.
- `ui/browser/turnprobe-spec.mjs:151`. `scriptReply()` scripts a real `tool_use` through the stub provider.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Port/AdminRoutes.cls`: new generated class holding the `Routes` table.
  - Its XData `Routes` lists every non-`GET` Dispatch.v2 route as `{endpoint (package-relative), type, verb, url}`, taken from the output of `AdminPort.DeriveRoutes`. It is checked in (AD-3, AD-27).
  - The snippet reads this table and never derives at runtime.
- `src/OcuPilot/Port/AdminPort.cls`: add three methods; the derivation stays inside `AdminPort` because AD-27 confines `%Api.Admin` names here.
  - `DeriveRoutes`, which parses the `UrlMap` and each `Call` implementation.
  - `SnippetForm(pEndpoint, pType)`. It answers `rest` when the table resolves the pair, `objectscript` for its named-completion branches, and `""` otherwise.
  - `Snippet(pEndpoint, pType, ByRef pQuery, pBody, pContext) As %DynamicArray`. It mirrors each `Invoke` branch, including the body wrapping and renaming and the named completions. `pContext` carries the origin and the user name.
- Every other port that defines `Invoke` (`AuditPort`, `OAuthResourceServerPort`, `OAuthAuthorizationServerPort`, `OAuthRegisteredClientPort`, `OAuthServerPort`, `ProcessPort`, `LogSourcePort`, and any others found by the origin check) gets its own `SnippetForm` and `Snippet`. Each renders its own branches and calls `##super` for the rest. `LogSourcePort` has no superclass here.
- `src/OcuPilot/Screen/Tool/UserPassword.cls`: add `SnippetAfter(pEndpoint, pIdParam, pIdValue, pStoredPayload, pContext) As %DynamicArray`, rendering the flag step exactly as `AfterWrite` would.
- `src/OcuPilot/Kernel/Proposal/Draft.cls` (new): `Take(pProposalId, pUser, pOrigin, Output pAnswer, Output pHttpStatus, Output pCode)`. In order:
  1. Refuse a caller from a turn.
  2. `GuardedExpireStale`.
  3. Read the row with `GuardedByKey`. It must be owned and live; otherwise answer 404.
  4. Run `Prohibits`.
  5. Compose the query and body the way Confirm does, then substitute placeholders.
  6. Call `Snippet`, then `SnippetAfter`.
  7. Call `GuardedClose(REASONDRAFT)`. If it does not close, answer 404.
  8. Answer.
- `src/OcuPilot/Kernel/State/Propose.cls`: add `Parameter REASONDRAFT = "draft";` beside the `REASON*` parameters. That is the only change.
- `src/OcuPilot/Kernel/Proposal/Write.cls`: add the code `NODRAFT = "PROPOSAL.NODRAFT"`, add-only.
- `src/OcuPilot/Api/Router.cls`: add `<Route Url="/proposal/:id/draft" Method="POST" Call="ProposalDraft"/>` beside confirm and cancel, plus a thin `ProposalDraft` wrapper.
- `src/OcuPilot/Api/Confirm.cls`: add `HandleDraft`. It takes the origin from the request's scheme and `HTTP_HOST` and renders through `Response.JSON` or `Error.Render` (AD-12).
- `src/OcuPilot/Test/EndpointCoverage.cls`: add a probe row for the new route.
- `src/OcuPilot/Test/DraftRegistry.cls` (new). Iterates every write tool from `ListTools`, with no sample. It asserts four things:
  - `AdminRoutes` equals `DeriveRoutes`.
  - Each tool's port defines `Snippet` and `SnippetForm` in the class that defines `Invoke`, and `SnippetForm(Endpoint, WriteType)` is not `""`. The failure names the tool.
  - A tool that overrides `AfterWrite` defines `SnippetAfter`.
  - **Secrets.** Each tool gets a synthetic stored row: the `ToolFields` rows, the fingerprint subject and every secret name, each set to a unique probe string. The rendered text must contain no secret probe and must show `"<Name>"` for each secret in the body.
- **[Spec gate] Draft/Confirm parity:** because `Draft.cls` repeats Confirm's body composition (`Confirm.cls:358-365`), `DraftRoute` (or `DraftRegistry`) asserts, for at least one merge write, one create and one secret-only-body write, that the query and body the draft renders (placeholders substituted back by the probe values) equal the query and body Confirm composes for an identical proposal -- read from what Confirm actually hands the port (e.g. the ledger row's sent fields, or a port capture), never from a second copy of the composition. Mutation: change one line of the draft's composition -> this assertion goes red.
- `src/OcuPilot/Test/DraftRoute.cls` (new, over `RouterFixture` and `ProposalFixture`). Covers every row of the I/O matrix except Clipboard. For the happy path it also asserts that the target reads back unchanged and that the ledger and marker counts do not move.
- `ui/src/app/core/proposal-view.ts`: add the phase `canceled-by-draft`, which is terminal. `phaseForState('canceled','draft')` maps to it, and its status line is the new key. Every existing canceled consequence applies to it: the restrained treatment, the proposal-closed event and Send.
- `ui/src/app/core/draft.ts` (new): `proposalDraftPath(id)` (AD-20), the `DraftOutcome` type and its parser, and the request through the API service. Stay out of `turn.ts:326-361` and `turn.ts:1162-1175`; if the panel can reach the API only through `TurnService`, add one add-only method beside `cancelProposal`.
- `ui/src/app/shell/copy-control.ts` (new): the one copy control, framework-free. `createCopyButton(getText)` returns an icon button using the `.ocu-panel-icon-button` idiom, with the aria-label "Copy to clipboard".
  - It uses `navigator.clipboard.writeText` in a secure context, and a textarea with `execCommand` otherwise.
  - It announces "Copied" or the failure sentence politely.
- `ui/src/app/shell/code-block.ts` (new): the `app-code-block` component for a script. It renders each step as a `pre` with `tabindex="0"` on the code surface, and each step carries a copy control.
- `ui/src/app/shell/reply.ts`: after DOMPurify has run, attach one copy control to each `pre.ocu-reply-pre`, copying that block's `textContent`. This is DW-1081.
- `ui/src/app/shell/proposal-card.ts`: add a `button-text` "Give me the script instead" after Cancel, shown whenever Cancel is shown and following Cancel's `aria-disabled` rule, plus a `draft` output. Change nothing else.
- `ui/src/app/shell/panel.ts`: add `(draft)` and `onCardDraft`.
  - On success: set the phase to `canceled-by-draft`, keep the script for this session, and project `app-code-block` together with the caption into the card's `[card-footer]`.
  - On a refusal that leaves the row live: show the instance's `reason` in the card's refusal slot, the same way a Confirm refusal shows. The buttons stay.
- `ui/src/styles/_components.scss`: add the code-block and copy-control rules. They go after `.ocu-reply-code-block` (:3908), not at the end of the file, and use only tokens. Focus uses `{components.focus-ring.on-code-surface}`.
- `ui/src/app/core/strings.ts`: add keys beside `proposalStatus*` (:165). They are listed with the EXPERIENCE edits below.
- EXPERIENCE.md, edited in place with the line count unchanged:
  - `:269` gains `"Give me the script instead"`, `"Copy to clipboard"`, `"Copied"` and `"The clipboard is not available here. Select the text and copy it yourself."`, and its description names the copy control's accessible name and its announcements.
  - `:272` gains the caption `"Nothing was changed. Fill in each value in angle brackets before you run this."`.
  - `:275` gains `"Canceled — you took the script instead"`.
- Tests:
  - `ui/tools/proposal-view.test.mjs` and `ui/tools/draft.test.mjs` (new).
  - `ui/src/app/shell/proposal-card-draft.spec.ts` (new), `code-block.spec.ts` (new), and `reply.spec.ts` (copy control on code blocks).
  - `ui/browser/copy-out-draft.browser-spec.mjs` (new). It scripts `webapp.list.update`, presses the action, and asserts:
    - the script shows on the code surface with a copy control, and the status line shows and takes focus;
    - the clipboard holds the text (clipboard permission granted);
    - the application is unchanged;
    - a reply code block's copy control copies its text.

- [x] [CI] instance: `OcuPilot.Test.DraftExecute.TestARenderedObjectScriptScriptDeletesTheErrorItNames` fails on CI's fresh instance (run 36272570883, job `instance`, class run 64): after the one seeded application error is deleted the namespace holds no errors, so the post-delete read answers `LOG.NAMESPACE` ("This instance records no application errors for a namespace by that name") and the test asserts OK on it -- it passed locally only because the reused throwaway held other errors in that namespace. `src/OcuPilot/Test/DraftExecute.cls` (the post-delete assertion, ~line 35) -- the test must prove the named error is gone without depending on any other error existing in the namespace (e.g. read the entry by its id through `SYS.ApplicationError` / the port and assert it is absent, or treat an empty namespace as gone), and must pass on a fresh instance: verify on `ocupilot-b-ci` after deleting every other application error in the seeded namespace first, and keep its Rule 19 mutation line current.

**Acceptance Criteria:**

- Given any live proposal, when the user chooses "Give me the script instead", then the card shows a REST or ObjectScript script that would make the same change, and the target, the ledger and the audit trail are unchanged.
- Given the script, when it renders, then it sits on the code surface with a copy control, and every secret field reads as an `<Name>` placeholder under the caption. `DraftRegistry` proves this for every registered write tool.
- Given the draft is taken, when the card updates, then the status line reads "Canceled — you took the script instead" and takes focus if a button held it. The card takes the restrained treatment, and a later poll reads `canceled` with reason `draft`.
- Given a write tool whose port or request type has no script form, including one Epic 16 adds, when `OcuPilot.Test.DraftRegistry` runs, then it fails and names the tool.
- DW-1081: given a reply containing a fenced code block, when it renders, then the block carries the same copy control, and pressing it copies exactly the block's text.

### Review Findings

Code review 2026-09-26 (four layers, full-opus): 53 raw findings, 11 entries (high 2, medium 2, low 7), all resolved or closed; 30 rejected.

- [x] [Review][Patch] **high** CI red at compile: `DraftLoser`'s `STATELIVE`/`REASONDRAFT` are compile-time expressions over `Propose`, which a fresh compile had not built yet [src/OcuPilot/Test/DraftLoser.cls:9] -- `DependsOn = OcuPilot.Kernel.State.Propose`. Reproduced red with `scripts/ci-image-compile.sh` on the pre-fix tree (`<CLASS DOES NOT EXIST>` at `pREASONDRAFT`), green on both `iris-community:2026.2` and `irishealth-community:2026.2` after (969 classes, fresh containers).
- [x] [Review][Patch] **high** A composed secret (`ComposedSecrets()`: user create, wallet secret create/update, SSL update, X.509 import) is never stored, so the draft omitted it and rendered a different change (a user created with no password, an empty certificate) [src/OcuPilot/Kernel/Proposal/Draft.cls:163] -- `Render` also placeholders each declared secret the stored diff names. `DraftRegistry.SecretProblem` now builds realistic rows (composed secrets in the diff, not the payload); `TestTheDraftOfAComposedSecretCreateIsTheBodyConfirmSends` added.
- [x] [Review][Patch] **medium** X.509 import step could not take a filled-in certificate or key (`Base64Decode("<Certificate>")`; a PEM cannot sit in one literal) [src/OcuPilot/Port/AdminPort.cls:2597] -- a placeholder certificate or key renders the vendor's `LoadCertificate`/`LoadPrivateKey` over the PEM file path it names.
- [x] [Review][Defer] **medium** A merge write's script PUTs the stored payload, so running it after the target changed reverts that change [src/OcuPilot/Kernel/Proposal/Draft.cls:133] -- by-design (AD-59: the script runs outside the fingerprint); DW-1718.
- [x] [Review][Patch] low: the password after-step for an unknown flag set change-at-next-login unconditionally under a comment [src/OcuPilot/Screen/Tool/UserPassword.cls:127] -- one guarded line `If <ChangeAtNextLogin> { ... }`.
- [x] [Review][Patch] low: `DeriveRoutes` skipped an unreadable `<Route>` and collapsed colliding keys, contrary to its "never a shorter table" contract [src/OcuPilot/Port/AdminPort.cls:2357] -- both are errors now.
- [x] [Review][Patch] low: `AdminPort.Literal` emitted raw line breaks, splitting an ObjectScript step [src/OcuPilot/Port/AdminPort.cls:2572] -- control characters render as `$Char` terms.
- [x] [Review][Patch] low: the credential backstop masked strings only and cited Conventions for a rule AD-3 states [src/OcuPilot/Kernel/Proposal/Draft.cls:292] -- numbers are masked too; booleans stay.
- [x] [Review][Patch] low: `DraftExecute` comments narrated history and cited the wrong rule file [src/OcuPilot/Test/DraftExecute.cls:1] -- trimmed.
- [x] [Review][Patch] low: the copy control cleared and set its status in one task, so a repeat press may not re-announce [ui/src/app/shell/copy-control.ts:101] -- cleared before the copy is awaited.
- [x] [Review][Patch] low: the copy glyph was 18px against DESIGN.md's 20px icon-button glyphs [ui/src/styles/_components.scss] -- 20px.

Rejected (30):

- false: the `UserPassword` after-step "violates AD-59" by rendering `Security.Users.Modify` -- AD-59 binds the port `Snippet` branches to routes; the after-step sentence prescribes no form, and the net change is the same flag.
- false: tracking status disagreement (spec `done`, sprint `review`) -- build-auto's machine state by design.
- low, spec-bound: the I/O matrix's merge-write row shows one step (the code renders AD-27's three) and the caption's EXPERIENCE row number -- spec edits, outside this review.
- low, spec-bound: `Copied` and the failure sentence sit on the action-names row, as the task placed them.
- low: `placeholders` omits non-secret `<Type>`/`<ID>` and the client does not read it; the caption shows on scripts with no placeholder.
- low: the code-block step kind is shown only as `data-kind`; the focusable `pre` has no accessible name.
- low (x3): a 200 whose draft does not parse, a status-0 failure, or a lost response leaves no script; Confirm/Cancel stay enabled while a draft is out; a losing draft's refusal could draw over a card another decision closed -- the instance resolves the race (AD-34) and the poll corrects the card.
- low: the origin comes from `HTTP_HOST` and `%request.Secure`, so a TLS-terminating gateway yields `http://`.
- low: `HEAD` routes sit in the non-`GET` table; no write tool uses one.
- low: ObjectScript steps display an error and carry on; `KeptTypeStep` does not stop on a failed read; each step leaves the terminal in `%SYS`.
- low (x2): `DraftExecute` cannot tell a failed restore step when the PUT keeps `Type`; its XECUTE check passes on a displayed error -- its read-backs are the assertions.
- low (x2): `reply.ts` attaches controls after the append (inference: a re-announcement); a streamed re-render drops a focused control.
- low: `AssertParity` passes no `payload`/`diff` context; the PEM fixture is one line; `SnippetForm`'s kind is used only as empty or not.
- low (x3): `NODRAFT`'s reason for a data problem; the lost-race test does not assert the row state; `Answer`'s read-back after a close could fail (theoretical).
- low (x3): an empty `IdParam`/id (every registered tool is rendered by `DraftRegistry`); a caller body on a constant pair (the draft never composes one); a JWKS refresh script with no URI.
- low: the code-surface focus ring is drawn inset (documented, to avoid clipping) and the hover mix is 12%.

### Review Findings (rework 1)

Code review 2026-09-26 of the rework (`9e0830f8..HEAD`, four layers, full-opus): the `[CI]` item is confirmed fixed -- `DraftExecute` 2/2 on `ocupilot-b-ci` with no application error in `USER` before or after (run 355). 4 entries (all low, patched), 0 deferred, 7 rejected.

- [x] [Review][Patch] low: the named entry leaked into `USER` whenever a step before the delete failed; cleanup removed only the other entry [src/OcuPilot/Test/DraftExecute.cls:321] -- cleanup also deletes the named entry when it still reads 200. A mutation skipping the `XECUTE` went red (run 354) and left `USER` empty.
- [x] [Review][Patch] low: the doc comment named a substituted `DeleteByNamespace` mutation, not the appended one run 351 demonstrated (the substituted form reddens the text assertion first) [src/OcuPilot/Test/DraftExecute.cls:261] -- it now names the appended form.
- [x] [Review][Patch] low: the doc comment said "exactly the one entry removed" and `LOG.ENTRY` only, while the test proves the named entry gone and one sibling kept, and accepts `LOG.DATE` across midnight [src/OcuPilot/Test/DraftExecute.cls:257] -- reworded.
- [x] [Review][Patch] low: the first seed's assertion message called it "a second" error while the doc comment calls the named entry the second [src/OcuPilot/Test/DraftExecute.cls:268] -- "the other".

Rejected (7):

- low: across midnight the test expects `LOG.DATE`, so a date-wide over-delete passes and residue on the new date reds -- needs two seeds microseconds apart to straddle midnight; closed `wontfix-theoretical`, DW-1720.
- low: the cleanup assertion adds a second red under an over-delete mutation -- the test is already red there.
- spec edits, outside this review: the `(QA) DraftExecute` paragraph still says one seeded error; the `mutation:` bullet carries two mutations (run 351 is the current one); a patched triage row is labeled `[false]`; runs 346-347 are named without their mutation.

## Design Notes

**Where the script is built: on the instance.** The stored `Arguments` and `Payload` never reach the wire (`WireRow`). The route, body shape and port branches are all known only on the instance: AD-3, AD-27, AD-52. Building the script there keeps one source of truth with the registry, and no model is involved. "The agent returns" is read to mean the panel returns the script: a model-written script could drift from the write, and would arrive as untrusted text (AD-11).

**Measured, correcting the context file's inference.**

- 7 of the 12 declared ports write through admin endpoints, so they get REST scripts.
- 5 call a `%SYS` class directly, so they get ObjectScript scripts.
- `AdminPort`'s own AD-27 completions render the class it calls.
- The kind of script is chosen by the port branch the write takes, never by the tool.

**Prohibited effects.** A proposal can be minted for an effect that the write refuses: `Mint` never calls `Prohibits`. The draft therefore refuses such an effect, following AD-57's precedent: OcuPilot does not offer such a write, even though it stays reachable outside OcuPilot. The draft performs no privilege-pair check, because whoever runs the script is checked by the vendor.

**Deliberate limits.**

- The script is not persisted, so a reloaded transcript shows only the status line.
- The script runs outside OcuPilot's fingerprint check.
- `Draft.cls` repeats Confirm's three-line body sequence, which lives in `Confirm.cls:358-365`. Confirm is not edited because Story 16.17 is editing those lines. The registry test keeps the two in step.

**Governing ADs:** AD-3, AD-4, AD-6, AD-10, AD-11, AD-12, AD-13, AD-15, AD-19, AD-20, AD-22, AD-27, AD-30, AD-34, AD-35, AD-39, AD-40, AD-41, AD-47, AD-51, AD-52, AD-54, AD-56, AD-59, AD-57 (on Epic 16's branch, not yet on this one; cited as precedent only), and Conventions › Secrets.

**AD-59 (claimed and written by the runner at the spec gate, 2026-09-26):** A proposal's copy-out draft is rendered on the instance from the stored proposal by the branches of the tool's declared port.

- It sends nothing and runs no write.
- It is refused for a prohibited effect.
- It closes the proposal as `canceled`/`draft`.
- Every port that defines `Invoke` defines `Snippet`, and every tool that overrides `AfterWrite` defines `SnippetAfter`. A registry test pins both.

**Integration ACs:** the consumer is the agent panel's proposal card, which reads `POST /proposal/:id/draft` and renders the script. This is observed in the browser spec against a real instance.

- **Consumed-by:** Story 14.1's card. Also every later write tool (Epic 16), gated by `DraftRegistry`. And Story 14.2, whose policy result will sit beside the draft.
- **Consumes:** `Kernel.State.Propose` close, the `Operation` accessors, every port's `Invoke` branches, and `Kernel.Audit.Log.IsCredentialName`.

**Contended with Epic 16 (Stories 16.17 and 16.19):**

| File | Story 16.17's hunks — stay off |
| --- | --- |
| `ui/src/app/shell/proposal-card.ts` | inputs :357-373; status template :276-296 |
| `ui/src/app/shell/panel.ts` | :168-174; :1258-1273 |
| `ui/src/app/core/turn.ts` | :326-361; :1162-1175 |
| `src/OcuPilot/Kernel/State/Propose.cls` | :146, :628, :677 |
| `src/OcuPilot/Kernel/Proposal/Confirm.cls` | not edited |

- Also contended, add-only: `ui/src/app/core/strings.ts`, `ui/src/styles/_components.scss` and EXPERIENCE.md.
- `Screen/Tool/Write.cls` is read only.

**DW-1081** is addressed by the reply code-block task and the DW-1081 acceptance criterion.

## Verification

This runs on slot B. Copy each changed `.cls` to `/tmp/ocupilot-b-ci/src` and load it on `ocupilot-b-ci`. Every MCP call carries `server: "ocupilot-slot-b"`, and one test runner is in flight at a time.

**Commands:**

- (loop) Run `sh scripts/ci-unit-test.sh --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one call at a time, for each of `DraftRegistry`, `DraftRoute`, `EndpointCoverage`, `ProposalClose`, `ProposalWire` and `ConfirmRoute`. Expected: 0 failures each.
- (loop) Run `cd ui && node --test tools/proposal-view.test.mjs tools/draft.test.mjs tools/strings.test.mjs && npm run test:tools && npm run test:components`. Expected: 0 failures.
- (loop) Run `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`. Then run `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/copy-out-draft.browser-spec.mjs browser/reply.browser-spec.mjs browser/proposal-card.browser-spec.mjs`. Expected: every leg passes.
- (loop) Run `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean.
- (once, before dev_complete) The full ObjectScript sweep on `ocupilot-b-ci`, one class per call, with totals checked against `%UnitTest_Result`. Expected: 0 failed and a non-zero count. Then run `cd ui && npm test` and `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`. Expected: green.
- The full browser suite is left to CI (Rule 29).

**Pinning mutations (Rule 19). Record each one as `mutation: … → …`:**

- AC1: make `Draft.Take` call the port's `Invoke` → `DraftRoute` goes red on "target unchanged".
- AC2: remove the placeholder substitution → `DraftRegistry` goes red on "secrets".
- AC3: map `draft` to `canceled-by-you` in `phaseForState` → `proposal-view.test.mjs` and the browser status-line leg go red.
- AC4: delete `ProcessPort.Snippet` → `DraftRegistry` goes red, naming `osmgmt.processes.terminatewitherror`.
- DW-1081: skip attaching the control in `reply.ts` → `reply.spec.ts` and the reply leg of the browser spec go red.

- mutation: `Draft.Take` calls `Operation.Apply` on the stored payload before its close → `OcuPilot.Test.DraftRoute` `TestAMergeWriteAnswersItsScriptAndChangesNothing` went red on "the application reads back unchanged".
- mutation: `Draft.Mask` quits on entry (no placeholder substitution) → `OcuPilot.Test.DraftRegistry` `TestNoSecretReachesAnyRenderedScript` went red on "every script renders with its secrets as placeholders".
- mutation: `ProcessPort.Snippet` deleted → `OcuPilot.Test.DraftRegistry` `TestEveryWriteToolHasAScriptForm` went red, naming `osmgmt.processes.terminatewitherror`.
- mutation: the `WithSecrets` line dropped from `Draft.Render`'s composition → `OcuPilot.Test.DraftRegistry` `TestTheDraftOfAMergeWriteIsTheBodyConfirmSends` and `TestTheDraftOfACreateIsTheBodyConfirmSends` went red ([Spec gate] Draft/Confirm parity).
- mutation: the `SecretBody` line in `Draft.Render` replaced by an empty body → `OcuPilot.Test.DraftRegistry` `TestTheDraftOfASecretOnlyBodyIsTheBodyConfirmSends` went red.
- mutation: one `url` in `AdminRoutes`' XData changed → `OcuPilot.Test.DraftRegistry` `TestTheRouteTableEqualsAFreshDerivation` went red.
- mutation: `phaseForState` maps `'draft'` to `'canceled-by-you'` → `ui/tools/proposal-view.test.mjs` "a canceled row reads its phase from the reason the instance recorded with it" and, rebuilt and redeployed, the AC1-AC3 leg of `copy-out-draft.browser-spec.mjs` went red.
- mutation: `attachCopyControls(root)` skipped in `reply.ts` → both "a reply code block" tests in `reply.spec.ts` and, rebuilt and redeployed, the DW-1081 leg of `copy-out-draft.browser-spec.mjs` went red.
- mutation: the `armed` guard dropped in `code-block.ts` → `code-block.spec.ts` "gives each step exactly one copy control" went red.
- mutation: the "Give me the script instead" button removed from the card template → four tests in `proposal-card-draft.spec.ts` went red.
- mutation: the `OcuPilot.Port.AdminRoutes=<table>` row absent from `PortGate`'s roster → `OcuPilot.Test.PortGate` `TestEveryPortDeclaresANamedGate` went red naming `OcuPilot.Port.AdminRoutes` (observed in the full sweep, run 168).
- mutation: `Panel.onCardDraft`'s `draftsById.set` dropped → `panel.spec.ts` "a taken draft projects the script under its caption…" went red (AC2, the card's half).
- mutation: the `drafting` check dropped from `Panel.onCardDraft` → `panel.spec.ts` "a second press while the first draft request is out sends nothing" went red.
- mutation: the `If 'tClosed` refusal deleted from `Draft.Take` → `OcuPilot.Test.DraftRoute` `TestADraftThatLosesTheCloseIsRefused` went red (run 323; the matrix's race).
- mutation: the `IsCredentialName` clause dropped from `Draft.Mask` → `OcuPilot.Test.DraftRegistry` `TestTheCredentialPatternMasksAnUndeclaredName` went red alone (run 324).
- mutation: `ProviderPort.Snippet` deleted → `OcuPilot.Test.DraftRegistry` `TestEveryPortThatDefinesInvokeDefinesASnippet` went red naming `OcuPilot.Port.ProviderPort` (run 325).
- mutation: `AdminPort.ImportStep` decodes the certificate as given → `OcuPilot.Test.DraftPorts` `TestAdminPort` went red (run 326, `OcuPilot.Port` recompiled).
- mutation: `ProcessPort.Snippet` keeps `sendError`, and `OAuthResourceServerPort.Snippet` routes `ADDMAPPING` to the resource-server endpoint → `OcuPilot.Test.DraftPorts` `TestProcessPort` and `TestOAuthResourceServerPort` went red (run 328).

**(QA) `OcuPilot.Test.DraftExecute` (new).** Closes the follow-up review's own residual risk ("no rendered script has been run against the vendor"): takes a live `webapp.list.update` draft and a `logs.applicationerrors.delete` draft on `ocupilot-b-ci`, then actually runs what each renders -- the `rest` step parsed and sent as a real `%Net.HttpRequest` to the instance's own admin API, the `objectscript` steps `XECUTE`d in `%SYS` against one genuine seeded application error -- never through `AdminPort.Invoke` or `LogSourcePort.RemoveErrorIds`. A plain `WebApp.App` merge write answers three steps, not one (AD-27's kept-type completion); the test runs all three, filling the third step's non-secret `<Type>` placeholder from the same read a human would use, and asserts the application ends holding the drafted description and its original type. The `objectscript` leg asserts the seeded error is gone afterward. `OcuPilot.Test.DraftRegistry`'s parity test already proves draft-vs-confirm equality in process through the fixture port; this class is the one that proves the vendor itself accepts the wire shape.

- mutation: `AdminPort.RestStep` drops the query string from the rendered URL → `OcuPilot.Test.DraftExecute` `TestARenderedRestScriptIsAcceptedByTheAdminApi` went red on the admin API's own 400 (`MissingQueryParam`), not on a text assertion (run 333; reverted, `git diff --stat` clean, run 334 green).
- mutation: `LogSourcePort.Snippet` renders the error-number list with an unterminated string literal → `OcuPilot.Test.DraftExecute` `TestARenderedObjectScriptScriptDeletesTheErrorItNames` went red on a real `<SYNTAX>` error from the `XECUTE` (run 331); and appends a `DeleteByNamespace` of the namespace after its `DeleteByError` → the same test went red on the named entry's code (`LOG.NAMESPACE`, not `LOG.ENTRY`) and on the other seeded entry's id read (run 351; reverted, `LogSourcePort` recompiled with its subclasses, `git diff --stat` clean, run 352 green with no other application error in `USER`).
- (CR) mutation: `Draft.Render` without the diff-named secret clause (the pre-review code) → `OcuPilot.Test.DraftRegistry` `TestTheDraftOfAComposedSecretCreateIsTheBodyConfirmSends` and `TestNoSecretReachesAnyRenderedScript` (naming five tools) went red; green after, 9/9 (AC1, AC2).
- (CR) mutation: `AdminPort.ImportStep`, `Literal` and `UserPassword.SnippetAfter` as before the review → `OcuPilot.Test.DraftPorts` `TestAdminPort` and `TestUserPasswordAfterStep` went red; green after, 11/11.
- (CR) mutation: `Draft.Mask` masking strings only → `DraftRegistry` `TestTheCredentialPatternMasksAnUndeclaredName` went red on the numeric `PinSecret`.

## Review Triage Log

- 2026-09-26, rework iteration 1 (trigger=ci): re-opened by the runner for the `[CI]` item above; scope is that item only.


### 2026-09-26 — Review pass

- verdicts: 21 findings — high 0, medium 9, low 9, false 3, maybe-false 0
- findings:
  - `[medium]` `[patch]` (verification-gap) the eight port `Snippet` overrides and five `AdminPort` branches have no content assertion; `terminatewitherror` has no text check — added `OcuPilot.Test.DraftPorts`, one method per overriding port asserting verb, route, query and body keys or the `%SYS` call.
  - `[medium]` `[patch]` (verification-gap) the lost-race branch after `GuardedClose` never runs — added `OcuPilot.Test.DraftLoser` (store seam whose close loses) and `DraftRoute.TestADraftThatLosesTheCloseIsRefused`.
  - `[medium]` `[patch]` (verification-gap) the credential-pattern backstop in `Mask`/`IsSecretName` is unpinned — added `DraftRegistry.TestTheCredentialPatternMasksAnUndeclaredName`.
  - `[low]` `[patch]` (verification-gap) nothing pins the origin in a `rest` step — `DraftRoute` asserts `'http://<test server>:<port>/api/admin/v2…`; the browser spec asserts `config.origin`.
  - `[low]` `[patch]` (verification-gap) the panel's double-press guard and conversation reset are untested — double-press test added; the reset test declined, since a stale script needs a reused proposal id and ids are 32-hex server-minted.
  - `[low]` `[patch]` (verification-gap) missing `mutation:` lines — AC2's card half and the new tests recorded above; matrix rows beyond the per-AC pin are outside Rule 19's scope.
  - `[low]` `[patch]` (verification-gap) `DraftRoute.Counts` returning -1 on both sides would pass — asserts both counts are ≥ 0 first.
  - `[low]` `[patch]` (verification-gap) `AssertParity` compares only the first N drafted steps — asserts equal step counts for a tool with no `SnippetAfter`.
  - `[medium]` `[patch]` (verification-gap) `AdminPort.ImportStep` hands `Base64Decode` the whole PEM block (`<ILLEGAL VALUE>` when run) and omits the alias check — decodes the PEM body `PemBlock` canonicalizes and refuses an existing alias as the port does.
  - `[low]` `[reject]` (verification-gap) a 404 draft refusal carries no `detail`, so the card keeps its buttons until the poll — identical to Cancel's shipped shape, which the matrix delegates to the poll; changing it means a detail branch in both handlers.
  - `[false]` `[reject]` (intent-alignment) a merge write answers three steps, not one `rest` step — the Always clause and AC1 require mirroring `Invoke`'s AD-27 kept-type completion; one `rest` step would reset the application's type.
  - `[false]` `[reject]` (intent-alignment) `DeleteByError` is one call per date, not per entry — `LogSourcePort.RemoveErrorIds` makes exactly those per-date calls.
  - `[medium]` `[patch]` (intent-alignment) process terminate's script text is asserted nowhere — grouped with the first row (`DraftPorts.TestProcessPort`).
  - `[low]` `[patch]` (intent-alignment) `SnippetAfter` renders `Security.Users.Modify` rather than the admin-API re-read and `PUT`, and its set/clear branches are untested — branches pinned in `DraftPorts.TestUserPasswordAfterStep`; the kind is kept because the route table holds non-`GET` routes only, so the re-read cannot be rendered from it.
  - `[medium]` `[patch]` (intent-alignment) `ProviderPort` defines `Invoke` with no `Snippet` (AD-59) — empty `SnippetForm`/`Snippet` added, and `DraftRegistry.TestEveryPortThatDefinesInvokeDefinesASnippet` pins the whole port package.
  - `[medium]` `[patch]` (intent-alignment) nothing checks a script against what the write does — grouped with the first row.
  - `[medium]` `[patch]` (intent-alignment) the credential backstop has no test — grouped with the third row.
  - `[medium]` `[patch]` (intent-alignment) the race is tested only in sequence — grouped with the second row.
  - `[low]` `[reject]` (intent-alignment) not-takeable rows keep the card live on the client — grouped with the tenth row.
  - `[false]` `[reject]` (intent-alignment) the `PROPOSAL.NODRAFT` reason and the `SnippetAfter` comment are not EXPERIENCE.md strings — no `PROPOSAL.*` reason is an EXPERIENCE.md Fixed string, and script text is not UI copy.
  - `[low]` `[patch]` (intent-alignment) `Operation.cls` still calls itself AD-10's single call site — the comment names `Draft.Take` as the only other.
- stage-found while patching: a wholly-placeholder query value rendered URL-encoded (`%3CID%3E`) — `AdminPort.RestStep` keeps it readable; pinned in `DraftPorts.TestOAuthServerPort`.

### 2026-09-26 — Review pass (rework iteration 1, CI)

- verdicts: 7 findings — high 0, medium 1, low 2, false 4, maybe-false 0
- findings:
  - `[medium]` `[patch]` (verification-gap) accepting `LOG.DATE`/`LOG.NAMESPACE` after the delete cannot tell "removed the named entry" from "emptied the date or namespace"; an over-deleting script passes -- the test now seeds a second error that must still read 200, and the named entry must answer exactly `LOG.ENTRY`; mutation run 351.
  - `[low]` `[patch]` (verification-gap) the method's Rule 19 paragraph names only the `<SYNTAX>` mutation -- it now names the over-delete mutation that pins the read-back.
  - `[low]` `[reject]` (intent-alignment) absence is judged through the port's read path, not a direct vendor read -- the same path reads the named entry 200 before and the other entry 200 after, so a blanket wrong 404 fails; a second read path adds complexity for a theoretical defect.
  - `[false]` `[reject]` (intent-alignment) the test does not create the fresh-instance state -- with the second seeded entry the result no longer depends on it; run 352 ran with `USER` empty.
  - `[false]` `[reject]` (intent-alignment) the doc comment's mutation paragraph is stale -- same root cause as the second row, patched there.
  - `[false]` `[reject]` (intent-alignment) spec `status` and `baseline_revision` moved -- the workflow's own bookkeeping.
  - `[false]` `[reject]` (intent-alignment) the rest of the intent contract is untouched -- descriptive, no divergence.

## Auto Run Result

Status: done
Blocking condition: none

- **Change (rework iteration 1, CI):** `OcuPilot.Test.DraftExecute.TestARenderedObjectScriptScriptDeletesTheErrorItNames` seeds two application errors in `USER`, drafts the delete of one, runs the rendered step, then reads each entry by its own id through `LogSourcePort.Errors("detail", …)`: the named entry 200 before and 404 `LOG.ENTRY` after, the other 200 after; the other is removed in cleanup (`DeleteError`, `SYS.ApplicationError.DeleteByError` in `%SYS`). The result no longer depends on what else the namespace holds. The `HasErrorNumber` helper is gone.
- **Files:** `src/OcuPilot/Test/DraftExecute.cls`; this spec (the `[CI]` item ticked, the test's `mutation:` line).
- **Review:** 7 findings; 2 patched (medium 1, low 1), 0 deferred; rejected 1 low (a second read path for a theoretical wrong 404) and 4 false. Details in the triage log.
- **Follow-up review recommended: false** — follow-up pass; no high patched (1 medium, 1 low).
- **Verification (`ocupilot-b-ci`, one run at a time, from `^UnitTest.Result`):** before the fix, with every other `USER` error removed, run 344 red with CI's `LOG.NAMESPACE` failure; after, run 352 2/2 with `USER` empty before and after. Mutation run 351 red (above). `check-objectscript` 0 problems. Removed as throwaway residue, `USER`, 09/26/2026, by exact number: #1, #2, #8 before run 344, and #1, #2 left by mutation runs 346-347.
- **Residual risks:** none new. Previous pass: commit `25ba4560`.
