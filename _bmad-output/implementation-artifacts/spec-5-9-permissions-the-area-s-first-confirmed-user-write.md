---
title: 'Story 5.9: Permissions - the area''s first confirmed user write'
type: 'feature'
created: '2026-09-21'
status: 'done'
baseline_revision: '1d73b30b88b4253228d201d898fa84bf6bb9332a'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      A classified-opaque array reads as the secret mask, so on the Users card EscalationRoles
      renders as eight bullets beside Roles in clear.
    evidence: |-
      Measured: FieldLists.cls:384-385 types Roles and EscalationRoles shape "array" with
      itemType "", so field-lists.mjs:230 refuses "ordinary" on either and AD-3 names
      Security.User's empty Roles as its own opaque example. Disclosure.OrdinaryPaths:86-118
      admits ordinary+literal only, so an unchanged EscalationRoles is masked by the frozen
      matrix working as designed. Unlike DW-1429's alleged case the mask is backed by a real
      classification, but a reader still cannot tell it from a secret. Settling it means giving
      opaque a rendering of its own (a count, a placeholder) in DESIGN.md, which is product
      surface this story does not own.
    location: 'src/OcuPilot/Kernel/Proposal/Disclosure.cls:120-126 (Mask), DESIGN.md toast/card recipes'
    severity: low
---

<intent-contract>

## Intent

**Problem:** The Users area has no confirmed write. `Security.User` is one of AD-4's 28
non-merging endpoints, its `Roles` array is AD-3's own `opaque` example, and none of the four
refusals the epic promises (current user, last `%All` holder, `_SYSTEM`, a privilege grant) has
any code. Three routed ledger entries also land here.

**Approach:** Add one write tool, `permissions.users.update`, over the endpoint the Users list
already reads, and the `user` predicates the prohibited set needs before it can register. Add the
`user` id rule AD-13 requires so two spellings of a name are one target. Reposition the change
toast into the content area (DW-1412) and make the pre-dispatch code-database refusal carry a
reason (DW-1431). No generic write-path machinery changes: the tool overrides the two seams
`Screen/Tool/Write.cls` already exposes.

## Boundaries & Constraints

**Always:**

- The write's pair set **is** `UserList.cls:38`'s declared set — `%Admin_Secure:USE`,
  `%DB_IRISSYS:READ` — each pair once, `USE` never `WRITE` (AD-8 as amended 2026-09-21).
- The payload is the **complete property set** merged over the fresh read (AD-4). Measured on
  `ocupilot-slot-a` 2026-09-21 through the shipped port: a `Security.User` GET answers **16**
  top-level properties (population = every key the returned object iterates); `RunPut` does
  **not** call `MergeJsonAndProperties`. Re-measure against the story's own probe user on the
  throwaway; 16 is the expected value, not an assumed one.
- Every gate — prohibited set, restraint, pairs, fingerprint — is evaluated inside
  `Confirm.Transition`, never at the minting call (AD-40). A prohibited change therefore still
  mints a card and is refused at Confirm, exactly as 5.8's `PROHIBITED.SERVINGPATH` is.
- "Explained in the UI rather than merely hidden" follows 5.5's and 5.8's contract, not a second
  one: a `PROHIBITED.*` code with a written reason, rendered by `tool-call-card.ts:111-117` as
  `failed - <reason>` on the write card and by `proposal-card.ts:175-184`'s refusal banner, with
  the agent stating it and not retrying. The full tool set stays advertised (AD-8).
- The `%All` census is a query over the **whole** user population and asks the instance whether a
  user holds `%All`, never a substring match on the declared `Roles` list — a user holding it only
  through a custom role is counted.
- Destructive checks run **only** on the throwaway `ocupilot-ci` (`http://localhost:52776`), never
  against `ocupilot`. Every fixture account carries the `OcuPilotProbe` prefix (AD-25); `_SYSTEM`
  is only ever a read-only refusal target and its roles are never altered.
- `%UnitTest` classes run **one per tool call**, waiting for each to land in `%UnitTest_Result`
  before the next. Never two test calls in one message.

**Never:**

- Never hand-edit `ToolFields.cls` (generated) or hand-add a row to `FieldLists.cls` — the
  committed lists must equal a fresh derivation row for row (`Test/DerivedFields.cls:17-28`).
- Never make `Roles` a derived settable field: the template answers `[]`, which types no member,
  and AD-3 names it `opaque`. The one authored argument is the tool's own semantic half.
- Never give `/api/ocupilot` a matching role to cure DW-1431 — `Roster.cls:31-34` and
  `Test/WebApp.cls:194` pin `""` because AD-8 requires a request to run with exactly its own
  privileges.
- No screen action, no delete verb, no auto-refresh chip: `UserList.cls:36-37` declares
  `refreshes: false` and is absent from AD-43's seven-screen roster, so 5.8's amended clause
  applies here too.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Two-field change | Probe user enabled=0 with one role; agent asked to enable it and add an ordinary role | Proposal card headed with the target, two diff rows (`Enabled`, `Roles`), the rest under "N unchanged fields"; Confirm writes the complete 16-property set | No error expected |
| Non-merging proof | The same confirm | Every property the fresh read carried is byte-equal after the PUT except the two changed | A missing property fails the test, never a partial write |
| Disclosure | The same card, disclosure opened | Rows equal `unchangedCount`; an `ordinary` literal carries its value; `EscalationRoles` carries the mask because it is classified `opaque` | Unreadable field list masks every row (fail-closed, AD-3) |
| Current user | Target is `$USERNAME`, disable proposed | Refused inside the transition with a `PROHIBITED.*` code whose reason names the cause; `failed - <reason>` card | Refusal, not a fault; no write issued |
| Last `%All` holder | Census says the target is the only holder, disable proposed | Refused for the same reason | As above |
| `_SYSTEM` | Target resolves to `_SYSTEM` in any spelling, disable proposed | Refused for the same reason | As above |
| Privilege grant | `Roles` delta adds `%All` or any `%Admin_*` | Refused with `PRIVILEGEGRANT` at any confirmation level (AD-10) | As above |
| `EscalationRoles` | A payload whose `EscalationRoles` differs from the live target | Refused: always-prohibited for this type, and never advertised | As above |
| Two spellings | Probe user held case-preserved, agent names it in another case | One reference key, one lock, one proposal; the read-back and the highlighted row take the spelling the **instance** returns | A second key would allow two winning confirms (AD-34) |
| Highlight | Confirm from the Users list | Row re-fetches and highlights within 2,000 ms, scrolled into view; audit database carries the `AgentWrite` row for that proposal id | Marker failure reads "done · audit not marked" and never fails the write (AD-15) |
| Bare 403 (DW-1431) | Principal holding both declared pairs but not `READ` on the install namespace's code database | The refusal carries an AD-12 envelope naming the missing pair at whichever layer is reachable, and the prerequisite is documented | If no OcuPilot code can run at that layer, the measurement says so and the documented half stands alone |
| Toast placement (DW-1412) | A change to an entity whose screen is not open, panel docked at its live width, 1440x900 | Toast sits bottom-right of the content area offset by the live panel width; `elementFromPoint` on `.ocu-panel-send`'s center returns the button | In panel full screen no toast is placed: the published invariant "no toast ever overlays the panel" admits no offset, and the reply already carries the change sentence |

</intent-contract>

## Code Map

### The tool and its field list

- `src/OcuPilot/Screen/Tool/Write.cls:46` `Endpoint()` and `:53` `SettableFields()` are the two
  abstract seams; `:60` `IdArgument()` -> `"Name"` and `:67` `IdParam()` -> `"name"` already match
  `UserList`'s read. `:111-155` `FieldRows` admits `class="ordinary"` **and** `shape="literal"`
  (`:137-138`), no dot (`:140`), inside `PermittedFields` when non-empty (`:145`). `:180`
  `additionalProperties: false`; `:199-201` `rationale`/`expectedImpact`/`reverse`; `:230` `View()`
  is `[ Final ]`. `:25` `KIND="write"`, `:29` `FULFILMENT="instance"`.
- `src/OcuPilot/Screen/Tool/WebAppUpdate.cls` is the precedent to copy: `:34` `TOOLNAME`, `:51`
  `PERMITTEDFIELDS`, `:60` `WRITERESOURCE`, `:62` `WRITEPERMISSION = "USE"`, `:71`
  `SettableFields()` -> `..AdmittedFields()`, `:78` `ExcludedFields()`, `:100-107`
  `PrivilegePairs()` (appends its own pair only when `$ListFind` misses it).
- `src/OcuPilot/Screen/Descriptor/UserList.cls:38` the two pairs; `:36-37` `refreshes: false`;
  `:39-43` `entityType "user"`, `scope "instance"`, id `single`; `:49` classic page; `:51-67` the
  declared read (`Security.User` LIST + `rowGet` key `Name`, fields `Roles`, `ExpirationDate`);
  `:68-79` six columns including `Enabled` (status) and `Roles` (identifier); **`:80`
  `toolIdentifier "permissions.users"`** -> the tool name is `permissions.users.update`
  (`Registry.cls:33` `TOOLNAMEPATTERN`, `Conventions > Tool naming`). `:44-45` no actions, so
  `Registry.IsWriteCapable` (`Registry.cls:1908-1921`) stays 0 and the empty-state keys at `:77-78`
  stay as they are.
- `src/OcuPilot/Screen/Tool/FieldLists.cls:374-390` `"Security.User"`, `source "template"`, `method
  "Schema"`, **16 rows: 14 `shape:"literal"`, plus `Roles` and `EscalationRoles` `shape:"array"`
  with `itemType:""`** — verified structurally in the checkout.
- `src/OcuPilot/Screen/Tool/Classification.cls:33-87` `XData Entries`, keyed by tool name; **the only
  entry today is `webapp.list.update`**, so `Security.User` has no classification and every one of
  its 16 rows currently defaults to `secret` (`ui/tools/field-lists.mjs:46`). `:6-17` the grammar;
  `:28-32` the header sentence that `ordinary` is not "the tool admits it".
- `ui/tools/field-lists.mjs:38-40` inputs, `:105-107` what is classifiable, `:215-219` refuses a
  path absent from the named list, `:230` refuses `ordinary` on a member-less array, `:234-241`
  fail-closed default, `:327-334` `--check` byte-compares the committed artifact. Regenerate with
  `cd ui && node tools/field-lists.mjs`.
- `src/OcuPilot/Screen/Registry.cls:104-174` `ListTools` (discovery by inheritance, no manual
  registration), `:502-518` the kind and fulfilment refusals, `:1985-2007` `ConfirmChannelProblem`
  and `:2139-2172` `ToolFieldRows` — **check the authored `Roles` argument against these two; if a
  settable name outside `ToolFieldRows` trips the validation, that validation is what gets extended,
  with a test.**

### The prohibited set

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls:69` `COVEREDTYPES = "web-application"` and `:72`
  `TYPEWEBAPPLICATION`; `:134-138` `PermittedChangeFields`; `:146-150` `AlwaysProhibitedFields`;
  `:179-220` `Prohibits` (`:186-194` the two `UNCOVERED` arms — a listed type with no branch is
  refused wholesale); `:261-306` `WebApplication()` is the predicate-block template, first-hit-wins;
  `:317-340` `Changed()` compares `Rendered(payload)` against `Rendered(liveTarget)`; `:38-64` the
  code parameters, `:87-90` `Codes()`, `:95-105` `ReasonFor()`. **`PRIVILEGEGRANT` exists at `:54`
  but its sentence at `:100` is web-application-specific — reword it at its origin so it is true of
  both types rather than appending a second code.**
- `src/OcuPilot/Test/Prohibited.cls:440` asserts `$ListLength(tCodes) = 7` — the literal moves with
  any new code. `:378-394` asserts zero uncovered write tools with a `tWrites > 0` floor.

### Identity

- `src/OcuPilot/Kernel/EntityRef.cls:42` `REFSEPARATOR`, `:59` `IDRULES =
  "web-application:foldcase-striptrailingslash"` — **no `user` pair**, `:64` `IDRULENAMES`, `:67`
  `RULEFOLDCASESTRIPTRAILINGSLASH`, `:185-195` `NormalizedId` returns the id verbatim for a type with
  no pair. `src/OcuPilot/Kernel/EntityType.cls:28` already carries `user`.
- Measured on `ocupilot-slot-a` 2026-09-21 (population = four spellings of one existing account):
  `_SYSTEM`, `_system` and `_System` all answer 200 with the same `FullName`; a trailing space
  answers 404. **User names resolve case-insensitively, so without a rule one target has several
  keys — the DW-1359 defect AD-13 was amended to close.**
- `ui/tools/screen-mirror.mjs:62-64` parses the three parameters, `:158` `IMPLEMENTED_ID_RULES`,
  `:1966-2000` throws on an unknown type, an undeclared rule, a rule the client cannot implement, or
  a duplicate type. A new rule must also land in `ui/src/app/core/entity-ref.ts`.

### Confirm, disclosure, audit

- `src/OcuPilot/Kernel/Proposal/Confirm.cls:37` `READTYPE="GET"`, `:42` `WRITETYPE="PUT"`; `:198`
  `Transition` in order — tool `:209`, pairs `:217-245`, prohibited `:247-264`, restraint `:266-281`,
  conversation `:283-296`, definition version `:298-307`, fingerprint `:309-326`, claim+close
  `:328-344`, ledger open `:353-359`, vendor PUT `:365`, marker `:386-392`, ledger finalize `:393`;
  `:636` `HoldsPair` is the fixture seam (`Test/ConfirmFixture.cls:21-25`).
- `src/OcuPilot/Kernel/Proposal/Mint.cls:226-292` `Merge` — `:241` iterates `pSettable`, `:243` skips
  the id argument, `:245-247` refuses an argument naming a property the fresh read does not carry,
  `:284` `pUnchanged = tTotal - tChanged`; `:384-390` `Display`.
- `src/OcuPilot/Kernel/Proposal/Disclosure.cls:40-71` `Rows` (one row per payload key not in the
  diff), `:86-118` `OrdinaryPaths`, `:120-126` `Mask()` (8 x U+2022).
- `src/OcuPilot/Kernel/Audit/Event.cls:38,243,272` the `AgentWrite` triple. `Install/Smoke.cls`'s
  `agentwrite`/`auditmarker` checks already pass against the web application and need no change.

### DW-1431

- `irissys/%CSP/REST.cls:326-346` `AccessCheck` requires `READ` on
  `$Piece($zu(90,21,$namespace),"^",4)` — measured on `ocupilot-slot-a`, piece 4 in HSCUSTOM is
  `%DB_HSCUSTOM`. `:183-193` sets 403 **inline**, bypassing `ReportHttpStatusCode`, so IRIS composes
  no body. `AccessCheck` is documented overridable; `src/OcuPilot/Api/Router.cls` overrides
  `OnPreDispatch`, `ReportHttpStatusCode` (`:704-720`) and `Http405` but **not** `AccessCheck`.
- `src/OcuPilot/Install/Installer.cls:2240-2269` `CodeDatabaseResource` derives the resource from
  `SYS.Database.ResourceName`, never from the `%DB_<NAME>` convention; `:2275-2323` the two matching
  roles and why; `:2667-2699` and `:2747-2810` the assertions in both directions.
  `src/OcuPilot/Install/Roster.cls:105-151` the three applications, `:121-136` the API with
  `matchRole: ""`.
- **Two project statements disagree and one is wrong.** `Router.cls:575-579` says a class-load
  failure answers a bare 403 "which is why README.md states the read requirement";
  `README.md:346-349` and `Installer.cls:2278-2280` say a load failure answers 500 with `<PROTECT>`,
  and `README.md:340-352` states the requirement only for the two **anonymous** applications, never
  for an API account. The bare-403 producer in vendor code is `AccessCheck`, which runs after the
  class has loaded.
- `src/OcuPilot/Test/TurnWireFixture.cls:48-59` `Resources(pOperate)` already grants the install
  namespace's code-database READ, which is why `ui/browser/refused-tool.browser-spec.mjs:48-83`
  reaches the API at all. The gap is a descriptor and a document, not a fixture.
- Reusable sentences: `Router.cls:666` `AUTH.NOADMIN`, `:688` `NS.DENIED` with
  `detail.failedPair`; `ui/src/app/core/strings.ts:230` `privilegeRequiresResource`, `:234`
  `privilegeDeniedScreen`, `:236` `privilegeDeniedAction`. Every string key carries an
  `EXPERIENCE.md:<line>` provenance comment.

### DW-1412

- `ui/src/app/shell/toast-host.ts:45` the defect: `:host { position: fixed; right:
  var(--ocu-space-4); bottom: calc(var(--ocu-status-bar-height) + var(--ocu-space-4)); }` —
  viewport-relative. `:12` the header sentence to amend; `:46-51` the region and `.ocu-toast` rules;
  `:53-82` the template. Styles are component-scoped by the documented deviation at `:33-37`.
- **The live panel width is published nowhere a sibling or a stylesheet can read.** It exists as
  `ui/src/app/core/panel-layout.ts:85,225-234` `layout().panelWidth` (a plain number in a
  framework-free store) and as the inline binding at `ui/src/app/app.ts:180`
  `[style.width.px]="panelWidth"`, getter `:328-331` (`null` in full screen), re-read under `OnPush`
  via `panelGeneration` (`:254,266`). `ui/src/styles/_metrics.scss:36-42` holds only static
  `--ocu-panel-*` tokens. `app-toast-host` is already a child of `.ocu-shell`
  (`app.ts:181`), which is `position: relative` (`_components.scss:632-638`).
  Full-screen panel: `_components.scss:664-673`.
- The published rule, verbatim, `DESIGN.md:507`: `position: 'bottom-right of the content area,
  {spacing.4} above the status bar, offset from the right edge by the panel\'s live width'`;
  `DESIGN.md:1211` adds "so no toast ever overlays the panel … The offset tracks the panel's live
  width rather than a fixed token because the panel is resizable"; `EXPERIENCE.md:423` "bottom-right
  of the content area, above the status-bar, clear of the panel". **No numeric token is published,
  and no tool under `ui/tools/` reads the toast recipe** (`design-tokens.test.mjs` contains no
  occurrence of "toast"), so amending them reddens nothing.
- `ui/browser/toast.browser-spec.mjs:214-236` `toastGeometry()`; **`:272-276` asserts
  `toastRect.right ~= viewportWidth - space4`, the assertion the fix invalidates**; `:277-281` the
  bottom assertion, which survives. `:177-183` records DW-1412's own evidence and works around it by
  pressing Enter instead of clicking `.ocu-panel-send` — that workaround is what the pinning test
  replaces. Non-overlap precedent: `ui/browser/screen-height.browser-spec.mjs:213-230`;
  `elementFromPoint` precedent: `ui/browser/list-spec.mjs:167-231` `clickRowCentre`.
- Suppression rule: `ui/src/app/core/toasts.ts:189-211` `publish` with `:283-287` `openScreenShows`;
  `:48-54` the stack bound and two lifetimes. Toasts carry no fault by construction (`:9-11`,
  `change-bus.ts:33`). `ui/src/app/shell/panel.ts:896-905` `replyWithChangeSentence` already puts the
  change sentence in the reply.

### The client path for the write

- `ui/src/app/core/turn.ts:1007-1046` `decideProposal` — publishes `proposal-closed` then `changed`,
  `:1044` hard-coding `action: 'updated'` (every shipped write tool is a PUT).
  `ui/src/app/core/refresh.ts:607-636` `onBusEvent` marks and re-reads regardless of `refreshes`,
  which is what makes the highlight work on a non-refreshing list.
- `ui/src/app/shell/data-table.ts:1013-1019` `viewKeyFor` and `:1030-1040` `changedKeyFor` are the
  two case-reconciliation points — a read-back takes the row's own spelling, never `target.id`.
- Route `/ocupilot/permissions/users?ns=HSCUSTOM`; read path
  `/api/ocupilot/screens/permissions.users/read`; selectors `[role="grid"]
  .ocu-data-table-body [role="row"]`, `.ocu-data-table-row-changed`, `.ocu-data-table-link` (there
  are **no** `data-ocu-*` attributes on rows). `ui/browser/users.browser-spec.mjs:34-66` is the
  existing Users list spec with its own `irisSession` helper and **no** proposal machinery; the
  proposal bracket comes from `ui/browser/turnprobe-spec.mjs` (`nextTag`, `setTag`, `scriptReply`,
  `armProbeDefinition`, `requireFreeSlot`) and `ui/browser/proposal-confirm.browser-spec.mjs:59-193`.
- `ui/browser/change-highlight.browser-spec.mjs:61-70` the 2,000 ms budget with a 5x wait and the
  reasoning; `:309-347` the `Date.now()` bracket that logs on green; `:291-307` the pre-assertions
  that keep the scroll and highlight claims non-vacuous.
- `src/OcuPilot/Test/ProposalFixture.cls:373-567` the web-application write targets and the
  mixed-case trio, `:111-121` `DenyPair`/`DeniedPair`, `:382-400` the `OCUPILOT_ALLOW_PRINCIPALS`
  guard. **No user-entity fixture exists.**

## Tasks & Acceptance

### Execution

1. `src/OcuPilot/Screen/Tool/Classification.cls` + `src/OcuPilot/Screen/Tool/ToolFields.cls` -- add
   the `permissions.users.update` entry with `fieldList: "Security.User"`, classifying all 16 rows:
   the 14 literals `ordinary`, and `Roles` and `EscalationRoles` `opaque` (AD-3 names
   `Security.User`'s empty `Roles` as its own opaque example). Regenerate `ToolFields.cls` with
   `cd ui && node tools/field-lists.mjs`; never hand-edit it and never add a row to `FieldLists.cls`.
2. `src/OcuPilot/Screen/Tool/UserUpdate.cls` (new) -- the write tool. `TOOLNAME
   "permissions.users.update"`, `DESCRIPTORCLASS` the Users descriptor, `Endpoint() "Security.User"`,
   `PERMITTEDFIELDS "Enabled"`, `WRITERESOURCE "%Admin_Secure"`, `WRITEPERMISSION "USE"`,
   `ExcludedFields() "EscalationRoles"`, `PrivilegePairs()` emitting each pair once. Override
   `SettableFields()` to return `..AdmittedFields()` plus `Roles`, and `InputSchema` to add the one
   **authored** `Roles` property — an array of role names, the complete replacement list, with the
   reviewed description AD-3 requires. That is AD-3's authored half for an array the template leaves
   untyped, on the precedent of its own `Security.User` `{User, Password}` case; the derived field
   list is untouched.
3. `src/OcuPilot/Kernel/EntityRef.cls` -- declare `user`'s id rule (a case fold, same direction as
   the existing rule) in `IDRULES`, name it in `IDRULENAMES`, and add its `RULE*` parameter, so two
   spellings of one account are one key and one AD-34 lock.
4. `ui/src/app/core/entity-ref.ts` + `ui/tools/screen-mirror.mjs` -- implement the same fold and add
   it to `IMPLEMENTED_ID_RULES`; regenerate the mirror. AD-5 forbids a second identity rule
   hand-written in TypeScript, so the client implements the declared rule and nothing else.
5. `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- add `user` to `COVEREDTYPES` with its `TYPE*`
   parameter and a `User()` predicate on the `WebApplication()` template: the current user, the last
   `%All` holder, `_SYSTEM`, and a `Roles` delta adding `%All` or any `%Admin_*`.
   `PermittedChangeFields("user")` is `Enabled` and `Roles`; `AlwaysProhibitedFields("user")` is
   `EscalationRoles`. Add the codes and their reasons, and reword `PRIVILEGEGRANT`'s
   web-application-specific reason at `:100` **at its origin** so one code serves both types. The
   census asks the instance whether a user holds `%All` and runs over the whole user population,
   behind an overridable seam so no test has to strip `%All` from a real account.
6. `src/OcuPilot/Test/ProposalFixture.cls` -- probe-user helpers behind `OCUPILOT_ALLOW_PRINCIPALS`,
   on the `EnsureWriteTarget` pattern: a canonical probe user, a case-preserved mixed-case one, one
   holding `%All` through a custom role, and the census seam. Prefix every account `OcuPilotProbe`,
   adopt none it did not create, and remove them all in teardown.
7. `src/OcuPilot/Test/ToolWrite.cls` -- pin the new tool: its resolved pair set is exactly
   `UserList`'s two, each once; its advertised fields are `Enabled` plus the authored `Roles` and
   nothing else; `EscalationRoles` and every unadvertised key are refused under
   `additionalProperties: false`.
8. `src/OcuPilot/Test/UserUpdate.cls` (new) -- the confirm path for this tool, one class under the
   500-line guidance: the complete-property-set PUT, AC2's survival proof, the fingerprint, the pair
   denial through `HoldsPair`, and the four refusals through seeded proposals. Include one leg that
   the census counts a user holding `%All` only through a custom role, so the seam-driven refusals
   are not the only evidence.
9. `src/OcuPilot/Test/ProposalWire.cls` -- the disclosure for this tool: rows equal
   `unchangedCount`, an `ordinary` literal carries its value, and `EscalationRoles` carries the mask
   because it is classified `opaque`.
10. `src/OcuPilot/Test/ProhibitedRoute.cls` + `src/OcuPilot/Test/SurfaceCoverage.cls` +
    `src/OcuPilot/Test/Prohibited.cls` -- the real-principal legs for `user` (no delete verb is
    advertised for the type; each refusal is reachable), the coverage row for the new write tool, and
    the `$ListLength(tCodes)` literal at `Prohibited.cls:440` moved to the new count.
11. `src/OcuPilot/Api/Router.cls` + `README.md` -- (DW-1431) override `AccessCheck` to render the
    AD-12 envelope naming the missing `(resource, permission)` pair before it returns unauthorized,
    and state the prerequisite in README's roles section with the resource derived the way
    `Installer.CodeDatabaseResource` derives it. Correct `Router.cls:575-579` at its origin: it cites
    README for a sentence README does not carry, and attributes the bare 403 to a class-load failure
    that `README.md:346-349` and `Installer.cls:2278-2280` both say answers 500. Before writing
    either, **measure on the throwaway** which layer answers for a principal holding both declared
    pairs and not the code-database read — status, body, and whether any OcuPilot code ran — and let
    the measurement decide whether the envelope half is reachable or the documented half stands
    alone. Reuse `privilegeRequiresResource` rather than adding a string key if it fits.
12. `src/OcuPilot/Test/PreFault.cls` -- pin whatever the measurement in task 11 found: the refusal's
    status, that it carries a reason naming the pair where OcuPilot code runs, and (at `:17`) correct
    the claim that the framework's own `AccessCheck` 403 never reaches OcuPilot if it now does.
13. `ui/src/app/app.ts` -- (DW-1412) publish the panel's live width as a CSS custom property on
    `.ocu-shell`, from the one getter that already re-reads it, so a sibling can offset against it.
14. `ui/src/app/shell/toast-host.ts` -- position the host inside the content area, offset from the
    right edge by that property, keeping the published `{spacing.4}`-above-the-status-bar bottom;
    place no toast while the panel is full screen. Rewrite `:12`'s header sentence to the new rule.
15. `ui/browser/toast.browser-spec.mjs` -- replace `:272-276`'s viewport-right assertion with the
    offset one, measured against a panel resized live through the existing handle helpers so the
    "tracks the live width" half is tested rather than the default width. Add the pinning test: with
    a toast standing, `document.elementFromPoint` on `.ocu-panel-send`'s center returns the send
    button and a real click sends. Drop the Enter workaround and its note at `:177-183`.
16. `ui/src/app/shell/toast-host.spec.ts` -- the full-screen suppression leg (jsdom computes no
    layout, so this tier asserts the decision, not the geometry).
17. `ui/browser/users-write.browser-spec.mjs` (new) -- the story's journey against `ocupilot-ci`,
    signed in **on** `permissions/users` so the highlight is observable, driven through
    `turnprobe-spec.mjs`: a read card completes; the proposal card carries both diff rows; the
    disclosure opens to `unchangedCount` rows with an `ordinary` literal in clear; Confirm produces
    the status line and the `done · audit marked` card; the row re-fetches and highlights inside the
    2,000 ms budget measured with `Date.now()` and logged on a green run. Two more legs on the same
    fixture: the current-user refusal asserting `failed - <reason>` and the card's refusal banner
    with Confirm still pressable, and the mixed-case probe user proving the read-back and the
    highlighted row take the instance's spelling. Refuse to run against `ocupilot`.

### Acceptance Criteria

- Given a principal holding the Users screen's own two pairs and **not** `%All`, when it confirms an
  enable plus an ordinary role add on a probe account, then the write succeeds and the ledger records
  the pairs actually exercised, each once.
- **Integration AC (Rule 1):** Given the Users list open at `permissions/users`, when that confirm
  lands, then the list re-fetches in place and the target row carries
  `.ocu-data-table-row-changed` and the `Changed` tag within 2,000 ms — observed by the browser tier
  against the deployed bundle, not by inspecting the tool's own state.
- Given a confirmed write, when the vendor PUT is issued, then its body is the complete property set
  read fresh at proposal time with the diff applied, and a test proves every property the read
  carried survives the round trip byte-equal except the two changed. Any property the endpoint
  mutates as a side effect is declared in `fingerprintExcludes`, or the measurement records that
  there is none.
- Given the target is the current user, the last `%All` holder, or `_SYSTEM`, when a disable is
  proposed, then it is refused inside the confirm transition with a reason that names the cause, the
  write card reads `failed - <reason>`, the agent says it was refused and does not retry, and no tool
  for the action was ever advertised.
- Given a change that adds `%All` or any `%Admin_*` role, when it is proposed, then it is refused at
  any confirmation level, and a user who holds `%All` only through a custom role is counted by the
  census.
- Given the agent names the account in a different case from the one the instance holds, when the
  proposal is minted and confirmed, then one reference key and one lock are taken, and both the
  read-back and the highlighted row use the spelling the instance returns.
- Given a principal holding both declared pairs and not `READ` on the install namespace's code
  database, when it calls the confirm endpoint, then the refusal carries a reason naming the missing
  pair wherever OcuPilot code runs, and the prerequisite is stated in `README.md` — with the measured
  layer recorded so `Router.cls`'s comment is true of what actually happens.
- Given a toast standing from an earlier turn at 1440x900 with the panel docked and then resized,
  when the panel's Send button's center is hit-tested, then `elementFromPoint` returns the send
  button and a real click sends; and when the panel is full screen, no toast is placed.
- Given `ui/tools/field-lists.mjs --check` and `screen-mirror.mjs --check` at prebuild, when the
  build runs, then both pass against the committed artifacts, and `Test/DerivedFields` still finds
  the committed lists equal to a fresh derivation row for row.

## Spec Change Log

## Review Triage Log

### 2026-09-21 - Review pass

- verdicts: 18 findings - high 0, medium 4, low 9, false 5, maybe-false 0
- findings:
  - `[medium]` `[patch]` The shipped `%All` census is only ever observed answering 0; the branch that refuses is unreached - every refusal leg runs through `ArmLastAllHolder`, which replaces the method. Added `ArmAllHolders` (arms the census's *input*, so the shipped body runs in full over the real population) and `Test/UserUpdate.TestOnlyAnEnabledHolderCountsAsAnotherAllHolder`, two-sided plus one refusal through the transition.
  - `[medium]` `[patch]` `LastAllHolder`'s enabled-column filter is unpinned: deleting it left every test green, so an instance with a disabled `%All` holder would permit disabling the only usable one. Same new test; mutation demonstrated red on both its census assertion and its refusal.
  - `[medium]` `[patch]` `RoleNames`' comma-separated branch - the second input shape the class documents - had no executed test host; read as nothing it empties the role delta and permits every grant. Added `UserObject(..., pRolesAsString)` and `Test/UserUpdate.TestARoleDeltaIsReadWhenTheRolesMemberIsAString`, including a permitted-add leg so the refusals are not vacuous.
  - `[medium]` `[patch]` `IsOff`'s non-boolean branches are executed by nothing, and the `""` branch is reachable in production (`ParsedObject` answers `{}` for an unreadable payload, so every member renders `""`), where it guards all three AD-10 disable refusals. Added `Test/UserUpdate.TestAnEnabledValueTheGuardCannotReadAsOnIsADisable`; each arm demonstrated red separately.
  - `[low]` `[patch]` `IsOff`'s residual `Quit 0` contradicted its own doc comment - a spelling it cannot read was treated as leaving the account enabled, skipping the three refusals, the opposite of the sibling fail-closed decision in `LastAllHolder`. Changed to `Quit 1` and the comment rewritten to state it; pinned by the test above.
  - `[false]` `[reject]` `Codes()`' doc comment said to be stale about ordering. Refuted: `WebApplication()` refuses in the order SERVINGPATH, UNAUTHENTICATED, AUTHORIZATION, DISPATCH, PRIVILEGEGRANT, UNCOVEREDFIELD; `Codes()` lists the first four in exactly that order, then the three user codes, then PRIVILEGEGRANT and UNCOVEREDFIELD - which the comment names separately as "the two both types share" - then UNCOVERED last. The comment describes the list it has.
  - `[low]` `[patch]` The DW-1431 AC had no `mutation:` line. Closed in-pass: granting the code-database resource turns the bodyless 403 into OcuPilot's own 404 `PROPOSAL.UNKNOWN` envelope and reddens three assertions; line written.
  - `[low]` `[patch]` AC5's census half had no `mutation:` line - the plan's `Prohibited.User` mutation does not reach `HoldsAll`. Closed in-pass: reading the declared `Roles` column instead of the recursed set reddens the custom-role test; line written.
  - `[low]` `[patch]` AC4's never-advertised half had no `mutation:` line. Closed in-pass: a second write tool compiled under the `permissions.users` identifier reddens the roster assertion, naming it; line written.
  - `[low]` `[patch]` The toast AC's full-screen half had no `mutation:` line. Closed in-pass: dropping the `panel.fullScreen()` guard reddens `toast-host.spec.ts`'s full-screen leg; line written.
  - `[low]` `[patch]` The generator AC had no `mutation:` line at all. Closed in-pass: classifying `Roles` `ordinary` makes `field-lists.mjs` refuse, and hand-editing `ToolFields.cls` past it makes `--check` report it stale. The line also records that `Test/DerivedFields` stays green on that edit and correctly so - it compares `FieldLists.cls`, not the classified artifact.
  - `[low]` `[patch]` `TestALeastPrivilegedPrincipalConfirmsAUserWriteOverTheWire` reports green having measured nothing when `SeedForPrincipal` answers `""` (`Minted`'s "resolved to no entry" status is returned, not asserted). Added the two assertions that make the skip loud.
  - `[false]` `[reject]` DW-1431 implemented as prose plus a symptom test rather than as a refusal the caller can read. Refuted: the matrix's own error column authorizes exactly this outcome ("if no OcuPilot code can run at that layer, the measurement says so and the documented half stands alone"), and the measurement is complete rather than one probe - every OcuPilot class lives in the database the caller cannot read, which is why the `AccessCheck` override raised `<PROTECT>`.
  - `[low]` `[reject]` The highlight AC's audit half asserts the ledger's `AuditMarked` column and the card's word rather than querying the audit rows by proposal id. Not worth fixing: `MARKEDYES` is written only when `$System.Security.Audit` returned true for the `AgentWrite` triple carrying that proposal id (`Event.cls` turns a dropped emission into an error status), the marker path in `Confirm.cls` is unchanged and branches on no tool name, and `Test/AuditMarker` already pins the row query on that shared path - so the fix is a new test leg, not a direct correction.
  - `[false]` `[reject]` "The agent states it and does not retry" is unobserved. Refuted: a confirm is a user-originated request issued after the turn has completed (AD-6), so there is no agent loop that could retry, and the Always clause defines the stating half as the `failed - <reason>` card and the refusal banner, which the browser leg asserts.
  - `[low]` `[patch]` DW-1412's publisher/consumer contract was pinned only in the browser tier, so deleting `app.ts`'s binding reddened nothing in the `gates` job. Added a source-text roster row to `ui/tools/toasts.test.mjs`, the way `ci.test.mjs` and `compose.test.mjs` pin their cross-file rosters; the geometry stays in the browser tier, where layout is computed.
  - `[false]` `[reject]` "The tool overrides the two seams" versus six actual overrides. Refuted: the Code Map names `Endpoint()` and `SettableFields()` as the two *abstract* seams, task 2 explicitly requires the `InputSchema` override, and `WebAppUpdate` - the precedent the Code Map says to copy - overrides `ExcludedFields`, `PermittedFields` and `PrivilegePairs` too. The boundary the sentence protects (no generic write-path machinery changes) holds: `Write.cls`, `Mint.cls`, `Confirm.cls` and `Disclosure.cls` are untouched.
  - `[false]` `[reject]` Both senses of `opaque` appear on one card - `Roles` masked when unchanged, in clear on the changed diff row. Refuted as a divergence: the Disclosure matrix row speaks only of unchanged rows. The reader-facing half is the standing `deferred:` entry, which this pass keeps.

## Design Notes

**Governing ADs (Rule 6).** AD-3 (the field list is derived; the semantic half is authored once per
tool; `Security.User`'s empty `Roles` is its named `opaque` example), AD-4 (complete body over the
fresh read; `Security.User` is one of the 28 that do not merge), AD-5 (one descriptor is the source;
no second identity rule in TypeScript), AD-6 (server-minted, fingerprinted, single-use; the confirm
channel is closed), AD-8 **as amended 2026-09-21** (the write's pair set is the screen's declared
set, administrative resources at `USE` never `WRITE`), AD-9 and AD-21 (database READ is
routine-execution permission — the whole of DW-1431), AD-10 (prohibited by effect, declared once in
the kernel, evaluated against live state inside the transition), AD-12/AD-39 (one envelope, two
renderings), AD-13 **as amended** (the scoped triple, and a per-type canonical spelling rule), AD-14
(one change event; screens re-fetch, never patch), AD-15 (the marker never fails the write), AD-19
(the toast's state stays in a store), AD-25 (probe fixtures are namespaced and adopt nothing),
AD-29 (the pair set is established two ways together — the backing class's own check plus a real
least-privileged principal on a throwaway), AD-34 (one atomic transition, one lock per canonical
target), AD-36 (screen and tool share one declared read), AD-40 (every write gate is at the write),
AD-43 (the Users list declares `refreshes: false` and is not on the seven-screen roster, so there is
no pause chip), AD-44 (the classic key). AD-2, AD-27, AD-30, AD-41 and AD-46 hold throughout and
this story changes nothing in them.

**Consumes:** 5.1-5.4 (mint, card, atomic confirm, execution as the user); 5.5 (the prohibited set
and its `UNCOVERED` wholesale refusal); 5.6 (the marker); 5.7 (the change bus, highlight and toast);
5.8 (the `USE` pair rule, the disclosure's real rows, and the refused-confirm write card — followed,
not re-derived); Story 2.2's derivation; Epic 2's `UserList` descriptor and Users list.

**Consumed-by:** 5.10-5.13 each add their own type's prohibited predicates and id rule on this
story's pattern before their write tool can register; Epic 8 and Epic 11 depend on Epic 5's write
path. The `user` id rule is consumed by every later story that references a user account.

**Declined DW-1429: measurement refutes its premise — `Name` is not on the card at all, and the fix
it names is refused by the generator.** Measured on `ocupilot-slot-a` 2026-09-21 (population = the
whole `WebApp.App` request-body template and one GET answer): `AdminPort.Template("WebApp.App")`
resolves `RequestBodySchema` with 46 top-level keys and no `Name`, and the GET likewise answers 46
keys with no `Name`. `Mint.cls:234` clones the fresh GET as the payload and `Disclosure.cls:55-66`
iterates the payload's own keys, so there is no `Name` row to mask. The 44 unchanged rows reconcile
exactly as 45 top-level `ordinary` literals plus the `MatchRoles` container, less the two changed
fields — `MatchRoles` masked deliberately and pinned at `Test/ProposalWire.cls:172-175`. The entry's
counts are all correct; its "`Name` reads as eight bullets under the disclosure" is an inference from
the row count, not an observation. The named remedy is also unreachable: `field-lists.mjs:215-219`
refuses a classification path absent from the named list, so classifying `Name` first requires a row
in `FieldLists.cls` that `Test/DerivedFields.cls:17-28` would redden, and typing the element shape of
a field the template omits is what AD-3 forbids. **For the lead:** the wrong sentence has three
origins to correct rather than one — `deferred-work.md:5479`, `epics.md:3664`, and the `deferred:`
entry in Story 5.8's spec. The residual concern is real but different, and is filed in this spec's
frontmatter `deferred:` list: a *classified* `opaque` array is still indistinguishable from a secret,
which this story's own card shows with `EscalationRoles`.

**Why `Roles` is an authored argument and not a derived field.** `FieldLists.cls:384-385` types both
arrays `shape:"array"` with `itemType:""` because the template answers `[]`, and
`field-lists.mjs:230` refuses `ordinary` on a member-less array while `Write.cls:138` admits
`literal` only. Teaching the derivation to type an empty array would be inventing information the
template does not carry, against AD-3's own text and its own example. One authored argument on one
tool, reviewed, is the shape AD-3 already sanctions for this same endpoint.

**Why a prohibited change still mints a card.** AD-40 puts every write gate at the write, so the
refusal arrives at Confirm, not at the tool call — the same shape 5.8 ships for
`PROHIBITED.SERVINGPATH`. "Never advertised as a tool" means there is no `users.disable` tool and no
policy flag, not that the proposal is suppressed; "explained rather than hidden" is the reason on the
refused card. Do not invent a second, earlier refusal surface.

**The full-screen toast.** The published rule names the offset as the panel's live width, and
`app.ts:328-331` has no width in full screen where the panel covers the content area. The published
invariant — "so no toast ever overlays the panel" — admits no offset there, and
`panel.ts:896-905` already puts the change sentence in the reply the user is reading, so placing no
toast loses nothing. That is the reading the invariant forces; it is recorded here rather than
treated as a new product decision.

## Verification

**Targeted, inside the implement loop (loop):**

- `cd ui && node tools/field-lists.mjs && node tools/screen-mirror.mjs` -- expected: both regenerate
  cleanly; `git diff` touches only `ToolFields.cls` and `screens.generated.ts`.
- `uv run scripts/check-objectscript.py <changed paths>` -- expected: 21 rules pass.
- Load and compile the changed classes through the IRIS MCP tools with `server: "ocupilot-slot-a"`
  -- expected: clean compile, error text read rather than assumed.
- `cd ui && npm run test:tools` and `npm run test:components` -- expected: green. These cover
  `field-lists.test.mjs`, `proposal-view.test.mjs`, `toasts.test.mjs`, `navigation.test.mjs`,
  `toast-host.spec.ts`.
- Bring up the throwaway once: `bash scripts/ci-throwaway.sh --dir /tmp/ocupilot-ci --project
  ocupilot-ci --web 52776 --super 1975` -- expected: healthy. It is currently running in a
  post-merge-install state, **not** pristine; treat it accordingly and tear down only a throwaway
  whose `up` this session ran.
- **Before any browser or ObjectScript result on the throwaway means anything:** sync the source to
  `/tmp/ocupilot-ci/src`, compile it, and run `OcuPilot.Install.Installer.Install` --
  `ui/tools/ci-runner.mjs` does **not** load source. Then `cd ui && npm run build && docker cp
  dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/` -- a browser spec loads the
  deployed bundle, never the working tree.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.UserUpdate`
  -- and the same, **one class per invocation, waiting for each to land in `%UnitTest_Result`
  before the next**, for `OcuPilot.Test.ToolWrite`, `OcuPilot.Test.ProposalWire`,
  `OcuPilot.Test.Prohibited`, `OcuPilot.Test.ProhibitedRoute`, `OcuPilot.Test.SurfaceCoverage`,
  `OcuPilot.Test.DerivedFields`, `OcuPilot.Test.Envelope` and `OcuPilot.Test.Wire` (the two that
  exercise the `PreFault` fixture, which extends `OcuPilot.Api.Router` and has no test methods of
  its own), `OcuPilot.Test.WebApp`. Expected: each
  class green; verify the totals with the `%UnitTest_Result` SQL probe rather than the runner
  envelope. Never two test calls in one message.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci
  node --test --test-concurrency=1 browser/users-write.browser-spec.mjs browser/toast.browser-spec.mjs`
  -- expected: green, with the highlight's elapsed figure logged.
- Rule 19, all fourteen demonstrated on the throwaway 2026-09-21 -- the plan's six, and eight the
  review pass added for the ACs and pinning tests that had no line -- each reverted and the tree
  confirmed byte-identical (`git status --short`, `git diff --stat`) after every one:
  - `mutation: remove the changed publish from ui/src/app/core/turn.ts decideProposal -> ui/browser/users-write.browser-spec.mjs "AC1, AC2, AC3 and the Integration AC" (the .ocu-data-table-row-changed wait timed out)`
  - `mutation: return before the Try in OcuPilot.Kernel.Proposal.Prohibited.User, so it refuses nothing -> OcuPilot.Test.UserUpdate (4 methods red: the current-user/_SYSTEM, last-%All-holder, role-grant and escalation-role legs)`
  - `mutation: set OcuPilot.Screen.Tool.UserUpdate.WRITEPERMISSION back to "WRITE" -> OcuPilot.Test.ToolWrite.TestTheUserWriteToolAdvertisesEnabledAndRolesWithTheScreensOwnPairs (4 asserts red) and OcuPilot.Test.ProhibitedRoute.TestALeastPrivilegedPrincipalConfirmsAUserWriteOverTheWire (the confirm answers 403 AUTH.NOPRIVILEGE with detail.failedPair "%Admin_Secure:WRITE"), which is the spec's "least-privileged confirm leg"`
  - `mutation: answer pId verbatim for the foldcase rule in OcuPilot.Kernel.EntityRef.NormalizedId -> OcuPilot.Test.UserUpdate.TestTheUserRuleFoldsCaseTheWayTheInstanceResolvesIt and .TestDisablingTheCurrentUserOrTheSystemAccountIsRefused`
  - `mutation: restore :host { position: fixed; right: var(--ocu-space-4) } in ui/src/app/shell/toast-host.ts -> ui/browser/toast.browser-spec.mjs "DW-1412" (the stack stayed at the viewport edge)`
  - `mutation: Do pPayload.%Remove("FullName") after the clone in OcuPilot.Kernel.Proposal.Mint.Merge -> OcuPilot.Test.UserUpdate.TestAConfirmedWriteSendsTheCompletePropertySetAndTheOthersSurvive and .TestATargetThatMovedAfterTheMintIsRefused`
  - `mutation: grant the install namespace's code-database resource to the principal in OcuPilot.Test.ProhibitedRoute.TestAnAccountWithoutTheCodeDatabaseReadIsRefusedABareForbidden -> that method (the 403 becomes OcuPilot's own 404 PROPOSAL.UNKNOWN envelope, reddening the status, the empty-body and the no-read assertions), which is the DW-1431 AC`
  - `mutation: read the declared Roles column instead of the recursed set in OcuPilot.Kernel.Proposal.Prohibited.HoldsAll -> OcuPilot.Test.UserUpdate.TestTheCensusCountsAUserHoldingAllThroughACustomRole, which is AC5's census half`
  - `mutation: compile a second write tool under the permissions.users identifier -> OcuPilot.Test.ProhibitedRoute.TestNoDeleteVerbIsAdvertisedForAUserAccountAndALiveSystemDisableIsRefused (the roster assertion reddens naming it), which is AC4's never-advertised half`
  - `mutation: drop the panel.fullScreen() guard from ToastHost.visible -> ui/src/app/shell/toast-host.spec.ts "places no toast while the panel is full screen", which is the toast AC's full-screen half; the browser leg reddens too once the bundle is rebuilt`
  - `mutation: classify Roles ordinary in Classification.cls -> node tools/field-lists.mjs refuses ("path Roles is a member-less array and cannot be ordinary", exit 1); and hand-edit ToolFields.cls past it -> node tools/field-lists.mjs --check reports it stale (exit 1). That is the generator AC. Test/DerivedFields stays green on that edit and correctly so: it compares FieldLists.cls against a fresh derivation, while --check is what guards the classified ToolFields.cls`
  - `mutation: drop the enabled-column filter from OcuPilot.Kernel.Proposal.Prohibited.LastAllHolder -> OcuPilot.Test.UserUpdate.TestOnlyAnEnabledHolderCountsAsAnotherAllHolder (both the direct census assertion and the refusal it drives through the transition)`
  - `mutation: return before parsing in the comma-separated branch of OcuPilot.Kernel.Proposal.Prohibited.RoleNames -> OcuPilot.Test.UserUpdate.TestARoleDeltaIsReadWhenTheRolesMemberIsAString`
  - `mutation: answer 0 from OcuPilot.Kernel.Proposal.Prohibited.IsOff for an absent member, or for a spelling it cannot read -> OcuPilot.Test.UserUpdate.TestAnEnabledValueTheGuardCannotReadAsOnIsADisable (demonstrated on each arm separately)`

**Full runs, once, before `dev_complete` (once, before dev_complete):**

- `cd ui && npm run build && npm test` -- expected: the seven prebuild checkers pass and both client
  tiers are green. Note that `npm test` does **not** run the browser suite.
- `cd ui && npm run test:browser` -- expected: the whole browser suite green against the redeployed
  bundle.
- The full ObjectScript sweep through `ci-runner.mjs` against `ocupilot-ci`, one class at a time,
  reconciled against `%UnitTest_Result`.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- expected: zero
  checks `pending`, `fail = 0`, and a non-zero executed count; read the skip lines, not the number.
- `bash scripts/lint-docs.sh` -- expected: clean over the amended `README.md`.

## Auto Run Result

Status: done
Blocking condition: none

**What shipped.** One write tool, `permissions.users.update`, over the endpoint the Users list
already reads: `Enabled` derived, `Roles` as AD-3's authored half, `EscalationRoles` excluded, and a
resolved pair set that is exactly `UserList`'s two with `USE` never `WRITE`. `user` joins
`COVEREDTYPES` with a `User()` predicate carrying the four refusals and a `%All` census that asks
the instance for each account's recursed roles over the whole population. `user:foldcase` joins
`IDRULES` and its client twin. DW-1412 moves the toast stack into the content area behind a live
panel-width custom property. DW-1431 measured: no OcuPilot code runs at that layer, so the
documented half ships alone.

**Files changed.** `Screen/Tool/UserUpdate.cls` (new, the tool); `Screen/Tool/Classification.cls` +
regenerated `ToolFields.cls` (16 rows, 14 `ordinary`, both arrays `opaque`);
`Kernel/Proposal/Prohibited.cls` (the `user` branch, three codes, the census, and `PRIVILEGEGRANT`'s
and `UNCOVEREDFIELD`'s sentences reworded at their origin to serve both types);
`Kernel/EntityRef.cls` + `ui/src/app/core/entity-ref.ts` + `ui/tools/screen-mirror.mjs` +
`screens.generated.ts` (the id rule); `Api/Router.cls` + `README.md` (DW-1431's corrected sentence
and the prerequisite); `ui/src/app/app.ts` + `ui/src/app/shell/toast-host.ts` (DW-1412);
`Test/UserUpdate.cls` (new, 12 methods), `ui/browser/users-write.browser-spec.mjs` (new, 3 legs),
and additions to `ToolWrite`, `ProposalWire`, `ProhibitedRoute`, `Prohibited`, `SurfaceCoverage`,
`ProposalFixture`, `ProhibitedFixture`, `ReadTool`, `ToolRoundTrip`, `PreFault`,
`toast-host.spec.ts`, `toast.browser-spec.mjs`, `toasts.test.mjs`, `screen-mirror.test.mjs`,
`scripts/ci-throwaway.sh`.

**Review findings.** 18 filed across two layers - 0 high, 4 medium, 9 low, 5 false. Eleven entries
patched: the shipped census's refusing branch and its enabled-holder filter now have a test that
runs the real body (`ArmAllHolders` arms its input, not its answer); `RoleNames`' comma-separated
shape and `IsOff`'s non-boolean arms now have executed test hosts; `IsOff`'s residual was
fail-**open** against its own doc comment and is now `Quit 1`; the least-privileged wire leg can no
longer report green having measured nothing; DW-1412's publisher/consumer contract is pinned in the
`gates` tier as a source-text roster; and the five ACs whose pinning tests had no `mutation:` line
have one, demonstrated. Nothing deferred this pass - the standing `deferred:` entry (a classified
`opaque` array is indistinguishable from a secret) is kept and is now directly observable on this
story's own card. Five findings rejected: `Codes()`' ordering claim (refuted - the comment describes
the list it has), DW-1431-as-code (the matrix's error column authorizes the outcome the measurement
selected), the audit-row proxy (`MARKEDYES` is written only when the emission was accepted, on an
unchanged tool-agnostic path `Test/AuditMarker` already pins), "the agent does not retry" (a confirm
is user-originated after the turn ends, so no retry path exists), and the "two seams" count (the two
*abstract* seams; the boundary it protects holds). Each is recorded with its refutation in
`## Review Triage Log`.

**Follow-up review: true.** Three medium entries were patched. The specific unverified risk: the
shipped census's "yes" is now exercised, but only with `HoldsAll` armed - an instance carrying
exactly one `%All` holder and no fixture at all is a state this suite cannot produce, because it
needs a `%All` account to run.

**Verification.** `check-objectscript.py` 21 rules over 592 files, 0 problems; `lint-docs.sh` clean.
`npm run build` with its seven prebuild checkers clean, and `field-lists.mjs --check` /
`screen-mirror.mjs --check` both report up to date after a fresh regeneration. `npm test` runs 1,292
tools tests and 807 component tests green. The full browser suite is 218/218 against the bundle. Full
ObjectScript sweep on `ocupilot-ci` green, reconciled against `%UnitTest_Result` rather than the
runner envelope. `smoke.sh --container ocupilot-ci` green with a non-zero executed count. The
highlight's measured margin is logged on the green run: 2 ms against the 2,000 ms budget. All
fourteen Rule 19 mutations applied on the throwaway, each observed red on the named test, each
reverted with the tree confirmed byte-identical.

**Residual risks.** `OcuPilot.Test.PreFault` extends `OcuPilot.Api.Router` and has no test methods,
so the plan's Verification list named it as runnable; corrected there to the two classes that
exercise it (`Envelope`, `Wire`). The `IsOff` residual change is inert for every account that is not
one of the three protected ones - the guard evaluates the three refusals, none matches, and the
fingerprint gate answers as before - so it can only turn a corrupt-payload confirm's refusal code
from the fingerprint gate's into the prohibited set's, never a refusal into a write.
