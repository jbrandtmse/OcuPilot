---
title: 'Story 5.10: Security and secrets - disable and re-enable auditing'
type: 'feature'
created: '2026-09-21'
status: 'in-progress'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      The auditing-off banner clears only when an OcuPilot write emits a marker, so auditing
      re-enabled outside OcuPilot leaves the banner standing.
    evidence: |-
      writesMarked is a recorded fact (Kernel/Audit/Event.cls:293 reads Kernel/State/Switch), written
      only by Confirm.cls:402 after an attempted emission and by Installer.cls:3118. No producer
      exists for a manual re-enable. Probe: re-enable auditing by hand, re-read /agent/restraint.
    location: 'src/OcuPilot/Kernel/Audit/Event.cls:293'
    severity: 'med'
  - summary: >-
      Another user's tab learns the banner only on its next /agent/restraint read; the product has
      no push channel, so "immediately for every user" is bounded by that cadence.
    evidence: |-
      ui/src/app/core/agent-status.ts:450-454 re-reads only on a changed event of type
      agent-definition or agent-switch; ui/src/app/app.ts:541 loads on each signed-in pass. No
      setInterval touches /agent/restraint. Probe: two browsers, confirm the disable in one.
    location: 'ui/src/app/core/agent-status.ts:450'
    severity: 'low'
  - summary: >-
      Whether the in-card audit warning is spoken beside the countdown and terminal live regions is
      answerable only by a screen reader, which no gate in this pipeline runs.
    evidence: |-
      Three polite regions can mount in one frame (proposal-card.ts:86-90, :171, :196-207). jsdom
      computes no announcements and a browser spec reads the DOM, not the accessibility output.
      Human check: VoiceOver over a live destructive auditing card. DW-1246's residual half.
    location: 'ui/src/app/shell/proposal-card.ts:171'
    severity: 'low'
---

<intent-contract>

## Intent

**Problem:** The agent has never changed the setting its own accountability rests on. Auditing is
what FR-22, FR-7, NFR-7 and AD-15's marker depend on, and nothing in the product yet proposes
turning it off, warns while doing so, or shows the instance is unaudited afterwards. The write tool,
the entity type, the destructive declaration and the auditing-off banner's liveness do not exist,
and ten ledger entries against the secrets and warning machinery are unreachable because no tool
ever minted an auditing proposal.

**Approach:** Ship one write tool — `security.auditing.update`, over the admin API's
`Security.Audit.Enabled` PUT — declared **destructive**, on a new `built: false` descriptor that
Story 7.4's Auditing screen later builds out, so the screen and the agent are two callers of one
operation. Disable, then re-enable, as a single demo sequence that returns the instance to the
audited state. Alongside it, close the ten routed entries the tool makes reachable: one union of
declared names shared by both confirm-channel validators (DW-1206), a warning predicate that reads
its argument the way the payload does (DW-1226), a pinning test that is not circular (DW-1244), a
tool-keyed masked-field path with a real data path and a published reason (DW-1227, DW-1232,
DW-1251, DW-1278), a fourth dropped-emission sentence (DW-1171), and a refusal on the port's
mutating-and-async combination (DW-1279).

## Boundaries & Constraints

**Always:**

- Every destructive check runs on the throwaway `ocupilot-ci` (`http://localhost:52776`), **never**
  on the live `ocupilot` container. A class that turns auditing off is armed by its own environment
  variable and restores the prior state on **every** exit path — teardown *and* an in-method frame
  after `Try`/`Catch`, because a raise skips the method's tail.
- The tool name is `security.auditing.update` and its field is `Enabled`, typed boolean, on an
  `instance`-scoped target: `Mint.cls:29`, `:32` and `WarnsAuditingOff` (`:198-212`) already require
  exactly those three. The story does not rename them; it pins them to the shipped tool.
- The marker stays at its one site in `Confirm.Transition` after the write reads OK (Story 5.6,
  AD-15). Nothing in this story adds a second emission site or reorders the transition.
- The write is declared destructive and is deliberately **not** in the prohibited set; its entity
  type still needs a `Prohibited` branch or every write against it is refused wholesale
  (`Prohibited.cls:234-243`).
- One union of declared names, built once and consumed by both validators; the mirror **derives** it
  from the kernel's declaration and throws on mismatch, never re-implements it.
- Secrets are never stored, never logged, never in a proposal's stored arguments (AD-35, AD-3).
- Tests run one class per invocation, waiting for each to land in `%UnitTest_Result`.

**Never:**

- No typed-name field in the card (Story 14.7 ships it; adding it here with no 14.7 wiring would
  leave Confirm permanently `aria-disabled` and AC3 unreachable).
- No Auditing screen, no Angular page, no side-bar entry, no `built: true` descriptor.
- No second set-builder beside `Registry.cls`'s existing one, and no client re-implementation of the
  union rule.
- No shipped descriptor gains a `secretArguments` entry in this story: the auditing write has one
  boolean field and no secret. The secrets guards are armed through the probe screen's **real**
  declaration, not by a fixture that replaces the method under test.
- No `docker compose up`/`down`/`restart` against `ocupilot` or any `ocupilot-slot-*` container; no
  teardown of a throwaway this session did not start.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Disable proposed | agent calls `security.auditing.update` with `Enabled` boolean `false`, auditing on | proposal minted from a fresh `GET` of `Security.Audit.Enabled`; one diff row `Enabled: was true, now false`; `auditWarning` true; `destructive` true | No error expected |
| DW-1226: non-boolean falsy | `Enabled` is `0`, `"false"` or JSON `null` | the payload coerces it the way `Mint.Coerced` already does **and** the card carries the warning — the warning asks the same question the payload does | a value `Mint.Representable` rejects is refused by the merge before any mint |
| Re-enable proposed | `Enabled` true, auditing off | second proposal, no warning, `destructive` still true | No error expected |
| Disable confirmed | user presses Confirm | `AuditEnabled` 0; vendor writes `SystemChange` + `AuditChange` "stopped" **while auditing is still on**; OcuPilot's marker is attempted, drops, and the drop is recorded — ledger not-marked, "done · audit not marked", banner on | marker failure never fails the write (AD-15) |
| Re-enable confirmed | user presses Confirm | `AuditEnabled` 1; vendor writes `AuditChange` "started"; the marker lands; `RecordMarking(1)` clears the banner | as above |
| Two spellings of the singleton | agent sends `Name` `"system"`, then `"SYSTEM"` | both canonicalize to one key, so the second proposal is the first's sibling: one lock, one cancel (AD-13, AD-34) | the loser is refused with the terminal state, never retried |
| DW-1206: misspelled secret | a descriptor declares `secretArguments: ["Pasword"]` | **refused** at registration and at prebuild: the name is neither a settable field of the write tool nor one the read declares | one sentence, two callers, naming AD-6 |
| DW-1206: read-only criterion | a read-only screen declares a credential-named **criterion** as a secret | **accepted** — a criterion is one of the names the read declares | none |
| DW-1278: structured secret | confirm body `{"Password": {...}}` against a declaration that names `Password` | refused 400 before the claim; the proposal row stays live and the token unburned | `CLOSEDCHANNEL` |
| DW-1278: accepted secret | confirm body `{"Password": "s3cret"}` against the same declaration | merged into the body at write time only; absent from the stored payload, the digest, the ledger's field names and every log line | none |
| DW-1232: unfilled masked field | a proposal declaring a secret, input empty | Confirm `aria-disabled` **and** the published reason reachable through `aria-describedby` | none |
| DW-1279: mutating + async | a `PUT` against an endpoint whose `ShouldRunAsync()` is true | refused by the port before `SaveRequestBody`, so no supplied secret reaches the vendor's task row | port fault, logged |
| DW-1171: dropped security event | the `SecurityChange` triple is unregistered and a security-relevant change is made | the log line reads the security sentence, not the configuration one | the change still succeeds |
| Least-privileged confirm | caller holds neither `%Admin_Secure:USE` nor the code-database read | 403 naming the failed pair; auditing unchanged | `AUTH.NOPRIVILEGE` with `detail.failedPair` |

</intent-contract>

## Code Map

Line anchors were read in this checkout on 2026-09-21. Measured facts carry their probe.

### Measured on the throwaway `ocupilot-ci`, 2026-09-21 (auditing restored to 1 afterwards, verified)

- `$System.Security.Audit("OcuPilot","Security","AgentWrite",…)` returns **1** with auditing on,
  **0** in the same process immediately after `Security.System.Modify("SYSTEM", AuditEnabled=0)`,
  and **1** again after the restore. `%SYS.Audit` holds the `probe510on` and `probe510back` rows and
  **no** `probe510off` row. **The effect is immediate and in-process; a marker emitted after the
  disable cannot land.**
- The disable itself writes two rows *before* auditing stops: `SystemChange` "Modify System: SYSTEM
  / Audit enabled modified" and `AuditChange` "Auditing to database … stopped". The re-enable writes
  `AuditChange` "Auditing started to database …".
- `AdminPort.Invoke("Security.Audit.Enabled","GET", …)` answers `200 {"Enabled":true}` with
  `name=SYSTEM`, with no query parameter, and with a bogus parameter — **the endpoint ignores query
  parameters**, so the kernel's one-parameter contract needs no change.
- `AdminPort.TemplateMethod("Security.Audit.Enabled")` resolves `RequestBodySchema`.

### The vendor endpoint

- `%Api.Admin.Endpoints.Security.Audit.Enabled` (`[ Hidden ]`, read from the instance, not in
  `irissys/`): inherited `TYPEGET=1`/`TYPEPUT=2`, defines `RunGet` and `RunPut`,
  `RequestBodySchema()` → `{"Enabled": true}`, `ResourcesOR()` → `$LISTBUILD("%Admin_Secure")`,
  `ShouldRunAsync()` not overridden. `RunPut` opens `Security.System` id `"SYSTEM"`, sets
  `AuditEnabled`, `%Save()`s — so `SYSTEM` is the target's real id, not an invention.
- `src/OcuPilot/Screen/Tool/FieldLists.cls:148-150` **already carries** the derived list for this
  endpoint: one row, `Enabled`, `shape:"literal"`, `templateType:"boolean"`. Nothing is regenerated
  there. `:151-154` carries `Security.Audit.Event:Security.Events` (`source:"class"`,
  `Description`+`Enabled`) — FR-47's no-template case is already derived and pinned by
  `src/OcuPilot/Test/DerivedFields.cls:178`; its identity is a three-part query key that
  `Mint`/`Confirm`/`Prohibited` cannot express, which is why this story writes the enable flag and
  not an event.

### The write tool's seams

- `src/OcuPilot/Screen/Tool/Write.cls:46` `Endpoint()`, `:53` `SettableFields()`, `:60`
  `IdArgument()` → `"Name"`, `:67` `IdParam()` → `"name"`, `:125-155` `FieldRows` (`:137` admits
  `ordinary` only, `:146` drops a declared secret), `:161-170` `AdmittedFields`, `:178-203`
  `InputSchema` (the id property is **required**; `additionalProperties: false` at `:180`),
  `:230-254` `View()` — **`[ Final ]`**, `tId = tArgs.%Get(..IdArgument())` with an empty-id refusal
  at `:244-246`. So the model must supply an id string; the canonical rule below is what makes that
  safe.
- `src/OcuPilot/Screen/Tool/UserUpdate.cls` is the precedent to copy (`:30` `TOOLNAME`, `:32`
  `DESCRIPTORCLASS`, `:41` `PERMITTEDFIELDS`, `:56`/`:58` `WRITERESOURCE`/`WRITEPERMISSION="USE"`,
  `:60` `Endpoint()`, `:68` `SettableFields()`, `:94-103` an `InputSchema` override, `:114-121`
  `PrivilegePairs()` appending its own pair only when `$ListFind` misses it).
- `src/OcuPilot/Kernel/Proposal/Mint.cls:75-78` refuses an empty endpoint, id parameter or id value;
  `:96` seeds exactly one `tQuery(pIdParam)`; `:80-87` refuses a secret-named argument from the
  model; `:89` takes the entity type and scope from the **descriptor**; `:245-247` refuses an
  argument naming a property the fresh read does not carry. `Confirm.cls:545-560` repeats the same
  addressing at confirm.
- `src/OcuPilot/Screen/Tool/Registry.cls:104-174` `ListTools` discovers a tool by inheritance and
  **never** compares `TOOLNAME` to a descriptor's `toolIdentifier` (`:33` `TOOLNAMEPATTERN` is the
  only name rule); `:502-518` the kind and fulfilment refusals. But `Mint.cls:82`/`:89`/`:123`,
  `Write.cls:99` and `Prohibited.cls:298-299` all dereference `DESCRIPTORCLASS`, so a tool without
  one is not viable.

### The descriptor, the entity type, the id rule

- `src/OcuPilot/Screen/Descriptor/AgentDefinitionForm.cls` is the closest shape: no `read`, no
  `table`, `sideBarPosition: 0`, `archetype: "form-page"`, `built: true`. The 22 required keys are
  listed at `src/OcuPilot/Test/Descriptor.cls:615`; the closed key set is
  `src/OcuPilot/Screen/Registry.cls:368` `DECLARATIONKEYS`. `built: false` exempts a descriptor from
  the `sideBarPosition`, `parentScope` and `rowTarget` rules (`Registry.cls:466`, mirror
  `ui/tools/screen-mirror.mjs:720`); **no shipped descriptor uses it today**, and `built: true`
  without an Angular page fails `ng build` (`screen-mirror.mjs:33-34` →
  `ui/src/app/shell/screen-outlet.ts:54`). `form-page` is in the closed archetype vocabulary
  (`src/OcuPilot/Screen/Archetype.cls:70`).
- `src/OcuPilot/Kernel/EntityType.cls:28` `TYPES` holds 28 members, `audit-event` among them, and
  **no** instance-scoped auditing-configuration type. The client half is generated
  (`screen-mirror.mjs` parses `TYPES` directly); `src/OcuPilot/Test/Descriptor.cls:1190` asserts the
  count 28 and moves to 29. `scripts/check-objectscript.py` rule 8 reads `TYPES` from source and
  needs no edit.
- `src/OcuPilot/Kernel/EntityRef.cls:59` `IDRULES = "web-application:foldcase-striptrailingslash,user:foldcase"`,
  `:64` `IDRULENAMES`, `:67`/`:72` the two `RULE*` constants, `:200-201` the application,
  `:185-195` returns the id verbatim for a type with no rule. Client twin
  `ui/src/app/core/entity-ref.ts`; the mirror's roster is `ui/tools/screen-mirror.mjs:154-158`
  `IMPLEMENTED_ID_RULES`, its four refusals `:1951-2004`, pinned by `ui/tools/entity-ref.test.mjs:45,205`.

### The prohibited set

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls:86` `COVEREDTYPES = "web-application,user"`, `:89`
  `TYPEWEBAPPLICATION`, `:91` `TYPEUSER`; `:234-243` the **two** `UNCOVERED` arms (an unlisted type,
  and a listed type with no branch — both fail closed); `:263-267` the dispatch; `:317-362`
  `WebApplication()`, `:381-432` `User()`; `:179-184` `PermittedChangeFields`; `:194-199`
  `AlwaysProhibitedFields`; `:444` `IsOff` (`[ Private ]`, takes a **rendered** string, and reads an
  absent value as off — not reusable from `Mint`, whose own `Representable` `:342-345` and `Coerced`
  `:353-361` already answer the boolean question).
- `src/OcuPilot/Test/Prohibited.cls:178` asserts `CoveredTypes()` is exactly `"web-application,user"`;
  `:380-384` asserts zero write tools with an uncovered entity type — **this reddens the moment the
  new tool compiles**; `:442` asserts ten codes and should stay ten (this write is permitted).

### DW-1206 — the union

- `src/OcuPilot/Screen/Registry.cls:1970-2012` `ConfirmChannelProblem`. `:1989-1995` is the only
  membership test: `'$Data(tRows(tPath)) && '$ListFind(tReadFields, tPath)` → *"fingerprintExcludes
  names '…', which is neither a field of this screen's write tool nor one its read declares
  (AD-6)"*. `secretArguments` reaches only `StringListProblem` (`:1978-1979` → `:2063-2084`: array,
  non-empty strings, no duplicate) and is then read as a **whitelist** at `:2117`
  `CredentialNameProblem`. Its consumer, `Write.cls:146`, matches by exact name, so a misspelled
  entry leaves the real field in `InputSchema` — the defect.
- The two source builders: `:2139-2172` `ToolFieldRows` (keyed by row **path**, value = *is a
  settable string literal*, and it returns a refusal when the block is unreadable) and `:2020-2045`
  `DeclaredReadFields` (`read.fields`, `read.source.rowGet.fields`, `rowGet.derived[].field`).
  **Criteria are not in `tReadFields`**: they come from `:2088-2107` `DeclaredCriterionParams`,
  consumed once at `:1998`, and that helper reads `read.criteria.fields[].param` **only** — it
  misses the *flag* criteria that `src/OcuPilot/Screen/Descriptor/Base.cls:535-564` `FlagCriteria`
  enumerates (`src/OcuPilot/Screen/Descriptor/AuditList.cls:152` `marker` is the one in the tree)
  and it does not de-duplicate.
- **Two spellings, one trap.** `Write.cls:141-146` matches the `[]`-stripped name (`CorsAllowlist`)
  while `ToolFieldRows` keys and `:2117` use the full row path (`CorsAllowlist[]`). A union built
  from raw row paths admits the spelling `Write.cls` does not honour and refuses the one it does.
- `WebAppList.cls:60-61` is the **only** shipped descriptor declaring either key, both `[]`. The
  "must still PASS" case exists today only as a planted fixture:
  `src/OcuPilot/Test/Descriptor.cls:114-118` plants an `apiKey` criterion plus
  `secretArguments: ["apiKey"]` and asserts it sound, mirrored at
  `ui/tools/screen-mirror.test.mjs:1878-1895`. `apiKey` is a criterion and no tool field, so **the
  union must carry the criteria half or that assertion reddens.**
- `src/OcuPilot/Test/ProposalScreen.cls:32` declares `secretArguments: ["Password"]` with read
  fields `["Name","LastModified"]` (`:43`) and `toolIdentifier "probe.proposal"` (`:52`) — a name
  that names nothing, asserted **accepted** at `src/OcuPilot/Test/Proposal.cls:207-211`. DW-1206's
  own defect lives in the test tree, and making it sound is also what arms DW-1278.
- Mirror: `ui/tools/screen-mirror.mjs:374-408` `confirmChannelProblem` with `:417-441`, `:444-455`,
  `:457-464`, `:470-483`, `:486-496`; loaded at `:346-351`, gated at `:2120-2123`. The
  derive-and-throw pattern to clone is the `IDRULES` one: `:62` the `Parameter` regex, `:177-189`
  the parse returning `null` when absent, `:302-310` the throw naming the source class, `:154-158`
  the client roster, `:1951-2004` the four named refusals. The pattern **not** to clone is
  `DECLARATION_KEYS` (`:617-650`), a hand-copied roster held equal only to a corpus.
- Coverage today: `src/OcuPilot/Test/Descriptor.cls:92-126` and
  `ui/tools/screen-mirror.test.mjs:1841-1904` cover type, duplicate and the `fingerprintExcludes`
  sentence; `src/OcuPilot/Test/DeclarationCorpus.cls:62-63,79-80` cover the *singular* key
  misspellings as unknown top-level keys. **Nothing catches a misspelled entry.**

### DW-1226 / DW-1244 — the warning

- `Mint.cls:198-212` `WarnsAuditingOff` quits unless `pArgs.%GetTypeOf("Enabled")` is exactly
  `"boolean"`; `:148` sets `tValues("auditWarning")`; `src/OcuPilot/Kernel/State/Propose.cls:122`
  the property, `:212` the store, `:598` the read, `:640` the typed wire key `auditWarning`;
  `src/OcuPilot/Test/ProposalWire.cls:28` `WIREKEYS`. Client: `ui/src/app/core/turn.ts:218`, `:458`
  (`boolAt` at `:324` is `=== true`), `ui/src/app/core/proposal-view.ts:79`, `:292`,
  `ui/src/app/shell/proposal-card.ts:468-470` `auditWarningVisible`, `:171` the banner
  (`role="status"`, `STRINGS.proposalAuditWarning` at `ui/src/app/core/strings.ts:1269`).
- `src/OcuPilot/Test/ProposalWire.cls:325-338` reads `AUDITINGTOOL` back through `$Parameter` and
  `:82-92` `SeedIn` reads `AUDITINGFIELD` the same way and always types the value `"boolean"` — so
  the test builds its input from the predicate's own configuration, and the DW-1226 shapes are
  unreachable through that seam.
- Banner census (DW-1246 is **false as worded**): `role="alert"` at
  `ui/src/app/areas/agent/switches.page.ts:79`, `areas/agent/definition-form.page.ts:116`,
  `shell/change-password-dialog.ts:93`, `shell/list-page.ts:58`, `shell/panel.ts:279`,
  `shell/proposal-card.ts:179`; `role="status"` at `shell/list-page.ts:52` (severity-computed),
  `shell/panel.ts:255`, `:411`, `shell/proposal-card.ts:171`, and `proposal-card.ts:196`
  (`[attr.role]="statusRole"`, `null` once focus moved). Four warning banners are already
  `status`; the convention is `alert` for faults and refusals, `status` for advisories. The other
  two regions in the same frame: `proposal-card.ts:86-90` the countdown announcement and
  `:194-211` the terminal status line.

### DW-1227 / DW-1232 / DW-1251 / DW-1278 — the secrets path

- `src/OcuPilot/Kernel/Proposal/Confirm.cls:417-452` `ChannelProblem`: `:427` resolves the accepted
  names from the **tool** (`Screen/Tool/Registry.cls:441` → the tool's `SecretArguments`, which for
  a write tool is `Write.cls:95-100` → the descriptor's list, with `pDeclared` unconditionally 1),
  `:439` the membership test, `:445-449` the object/array refusal — both **before** `ClaimById`
  (`:143`) and the burn, which the comment at `:443-444` says is the point. `WithSecrets`
  (`:591-602`) has no type guard and is called at `:349`, after the claim.
- `src/OcuPilot/Test/ConfirmFixture.cls:41-44` `MergeSecrets` is a **visibility** passthrough to the
  private `WithSecrets`, not a replacement seam (contrast `PortClass()` `:13`, `HoldsPair()` `:21`,
  `ProhibitedClassName()` `:31`). What is weak is the arming:
  `src/OcuPilot/Test/ProposalConfirm.cls:387-403` supplies the name list itself, and `:141` asserts
  `WebAppList`'s declared list is empty — so `:439`'s accept arm and `:445-449` are unreached.
- `ui/src/app/shell/panel.ts:1161-1164` `secretsFor` returns `{}`; called at `:1060`;
  `ui/src/app/core/turn.ts:984-985` posts the map as the confirm body. **The card already has the
  inputs** (`proposal-card.ts:153-168`, `type="password"`, `aria-required`) and traps their values
  in a private signal at `:301`; its outputs (`:276-282`, `onConfirm` `:623`) carry only the
  proposal id. The gap is the handoff, not the input.
- `ui/src/app/shell/panel.ts:838` keys the lookup on `proposal.target.type` via
  `ui/src/app/core/navigation.ts:344-347` `screenForEntityType` and passes `screen.secretArguments`
  at `:844`; `ui/src/app/core/proposal-view.ts:273-294` masks the diff (`:284`) and hands the whole
  declared list through as `maskedFields` (`:291`); `proposal-card.ts:464-466` `secretsFilled` and
  `:580-586` `confirmAriaDisabled` demand all of them with no stated reason.
  `screenForEntityType` **is** named by `ui/tools/navigation.test.mjs:884,890` (DW-1227's "no test"
  is wrong); what is untested is its `built` filter and its first-match-wins behavior.
- `src/OcuPilot/Kernel/Proposal/Disclosure.cls:103-104`, `:60-64`: `secret` and `opaque` are
  indistinguishable — both are "not ordinary" and carry `Mask()` (`:123-126`). A secret can never be
  a changed row, because `Mint.cls:80-87` refuses it as an argument.
- Strings: `ui/src/app/core/strings.ts:54-55` is the provenance form (`/** EXPERIENCE.md:254 */`),
  `:68` the tail form; the Fixed-strings table is
  `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:250-393` with the
  last row at `:392` (append-only, tail, union-merge); `ui/tools/strings.test.mjs:497-516` and
  `:659-704` pin the table equal, the load-bearing line being `:698`. No row publishes a reason for
  a Confirm disabled by an unfilled masked field; `EXPERIENCE.md:425` is the `typed-name-field`'s own
  mismatch row and `:297` its label.

### DW-1171 / DW-1279 / install and smoke

- `src/OcuPilot/Kernel/Audit/Event.cls:214` is the `$Select(pEventName = ..#EVENTLEDGERREAD:
  ..#DROPPEDLEDGERREAD, 1: ..#DROPPEDCONFIG)`; the constants are `:25`/`:28`/`:33`/`:38` (event
  names) and `:68`/`:73`/`:84` (dropped sentences). `pEventName` is `""` from both change call sites
  (`src/OcuPilot/Api/Switches.cls:542`, `src/OcuPilot/Api/Definitions.cls:1496`) and `"LedgerRead"`
  from `src/OcuPilot/Kernel/Audit/Ledger.cls:732`; `pSecurityChange` **is** in scope at `:214`, so no
  signature changes. `:109` `Roster()`, `:147` `EventNameFor`, `:293` `WritesMarked`, `:317`
  `RecordMarking`, `:347` `LogFailure`. The pins are
  `src/OcuPilot/Test/AuditEvent.cls:391` (config), `:525` (ledger read),
  `src/OcuPilot/Test/AuditMarker.cls:446` (agent write), capture seam
  `src/OcuPilot/Test/EventProbe.cls:18` — whose default argument is `#DROPPEDCONFIG`, so the new arm
  must be asserted explicitly rather than by default.
- `src/OcuPilot/Port/AdminPort.cls:855` `Sequence`, `:891-898` the async branch with
  `tTask.SaveRequestBody(pBody)`; `:74-88` records that the vendor task row lives in
  `^|"^^:ds:IRISLOCALDATA"|Api.Admin.Util.AsyncTaskD`. `:135` `MUTATINGTYPES = "PUT"`; the request
  type is **not** in `Sequence`'s scope (`:366` `Invoke` holds `pType`, `:809` `RunSequence` passes
  only the resolved numeric type), but `%request.Method` is already set at `:816` from `:751`
  `HttpMethodFor`, which answers the suffix itself for a mutating type — so the guard needs no
  signature change. Of the two Release-1 async paths only `Database.SysCRUD` `TYPEINFO` enters this
  branch (`Security.Audit.Record` LIST self-queues inside `Run()`), and neither is mutating.
  `src/OcuPilot/Test/AdminPortAsync.cls:47`,`:66` cover both reads and assert nothing about a body.
- `src/OcuPilot/Install/Installer.cls:874-878` runs `EnsureAuditEvents` (`:2976`) then
  `EnsureAuditingEnabled` (`:3026`, reading `:3053`, writing `:3065`), both idempotent, **on every
  container start** — so an instance left unaudited is silently repaired by the next start or by any
  test that calls `Install("")`. `:3071-3101` `IsMarkingAgentWrites` and `:3118` `RecordMarking` are
  the other writer of the banner fact.
- `src/OcuPilot/Install/Smoke.cls:1224` `CheckAgentWrite`: `:1310-1323` `agentwrite` **passes** with
  auditing off (it asserts the write landed), `:1326-1332` `auditmarker` **hard-fails** with "0 audit
  row(s) carry this write's proposal id". No `skipped` reason covers auditing being off
  (`:1231`,`:1235`,`:1240`,`:1267`). `:1334-1343` is the restore-in-its-own-frame pattern, using
  `$Get()` on everything it reads — the model for this story's in-method restore.
- Teardown precedents: `src/OcuPilot/Test/AuditMarker.cls:84-100` restores only when the state is
  actually wrong and says why the restore belongs in teardown;
  `src/OcuPilot/Test/AuditEvent.cls:326-337` restores **and asserts the restore worked**, failing the
  teardown otherwise; `src/OcuPilot/Test/UninstallSurvival.cls:108-109`,`:171` is the existing
  "auditing is still enabled" assertion. `src/OcuPilot/Test/AuditOff.cls:67` and
  `src/OcuPilot/Test/AuditEnable.cls:6-7` deliberately **override** the enable method rather than
  flipping real auditing — this story is the first to flip it, so it inherits no precedent for the
  flip, only for the restore. Arming variables live in `scripts/ci-throwaway.sh:191-242` and their
  roster is held against the declaring classes by `ui/tools/ci.test.mjs`.

### The banner and the client path

- `ui/src/app/core/strings.ts:61` `auditingOffBanner`; `:63`/`:65` the link and action strings exist
  and are deliberately unrendered until 7.4. `ui/src/app/shell/panel.ts:253-259` the reserved slot
  (`role="status"`, id from `:71`), `:670` `writesNotMarked`. `ui/src/app/core/agent-status.ts:86`
  the flag, `:115` default true, `:270` the parse, `:450-454` the re-read filter — **only**
  `agent-definition` and `agent-switch`. `ui/src/app/app.ts:541` loads on each signed-in pass; no
  interval polls `/agent/restraint`. Server: `src/OcuPilot/Api/Switches.cls:301` writes
  `writesMarked` from `Event.WritesMarked()`; `src/OcuPilot/Test/SwitchesWire.cls:361-378` pins the
  nine-key order. Client pins: `ui/src/app/shell/panel.spec.ts:273` (the only visible-state test),
  `:301`, `ui/tools/agent-status.test.mjs:415`. **No browser spec touches the banner.**
- Proposal browser machinery to reuse: `ui/browser/turnprobe-spec.mjs:77` `nextTag`, `:132`
  `setTag`, `:151` `scriptReply`, `:171` `armProbeDefinition`, `:179` `disarmProbeDefinition`,
  `:231` `requireFreeSlot`; `ui/browser/panel-spec.mjs:62` `signedInAt`, `:99` `saveAndSettle`;
  `ui/browser/proposal-confirm.browser-spec.mjs:58` the underscored wire name, `:100`
  `allowWrites()`, `:144` `dropProposals()`, `:153-192` the `tool_use` scripting shape that carries
  the tool's arguments verbatim — which is how the DW-1226 argument shapes become observable.
- `src/OcuPilot/Test/SurfaceCoverage.cls:267-278` requires a `<tool>` row per registered tool in
  both directions (rows at `:93-94`); the `<screen>` rows (`:53-92`, asserted at `:248`) cover
  **built** screens only.

## Tasks & Acceptance

**Execution:**

1. `src/OcuPilot/Kernel/EntityType.cls` -- add the `auditing-configuration` token to `TYPES:28` --
   the closed enum is kernel-owned (AD-14) and the descriptor cannot declare a type it lacks.
2. `src/OcuPilot/Kernel/EntityRef.cls` -- add `auditing-configuration:singleton` to `IDRULES:59`,
   `singleton` to `IDRULENAMES:64`, a `RULESINGLETON` constant, and the arm in `:200-201` answering
   the constant `SYSTEM` -- the model supplies a required id argument (`Write.cls:230-254` is
   `Final`), so the canonical rule is what makes every spelling one key, one lock and one
   sibling-cancel set (AD-13 as amended, AD-34).
3. `ui/src/app/core/entity-ref.ts` and `ui/tools/screen-mirror.mjs:154-158` -- add the client twin
   and its roster entry -- AD-5 forbids a second identity rule in TypeScript, and the mirror throws
   on a rule the client cannot implement.
4. `src/OcuPilot/Screen/Descriptor/AuditingConfig.cls` -- a new descriptor: route
   `security/auditing`, area `security`, `built: false`, `archetype "form-page"`, no `read`, no
   `table`, `entityType "auditing-configuration"`, `scope "instance"`, id `single`, privileges
   `%Admin_Secure:USE` and `%DB_IRISSYS:READ`, `classicPage` the classic Auditing page,
   `toolIdentifier "security.auditing"` -- this is the descriptor Story 7.4 builds out, which is what
   makes the screen and the agent two callers of one operation. **Verify `built: false` early**: it is
   a first for this tree, and if a gate refuses it the fallback is `built: true` with
   `sideBarPosition: 0` plus the minimal page 7.4 replaces; record which one shipped and why.
5. `src/OcuPilot/Screen/Tool/AuditingUpdate.cls` -- the write tool. `TOOLNAME
   "security.auditing.update"` (fixed by `Mint.cls:29`), `PERMITTEDFIELDS "Enabled"`, `WRITERESOURCE
   "%Admin_Secure"`, `WRITEPERMISSION "USE"` (AD-8 as amended -- never `WRITE`), `Endpoint()
   "Security.Audit.Enabled"`, `SettableFields()` from `AdmittedFields()`, an `InputSchema()` override
   whose id property says the target is the instance's auditing configuration and that the value is
   `SYSTEM`, and a `Parameter DESTRUCTIVE = 1`.
6. `src/OcuPilot/Screen/Tool/Write.cls` -- add `Parameter DESTRUCTIVE = 0` and a `Destructive()`
   accessor -- the declaration belongs on the tool, not in a second kernel constant list naming a
   tool (which is the shape DW-1244 records).
7. `src/OcuPilot/Screen/Tool/Classification.cls` -- add the `security.auditing.update` entry naming
   field list `Security.Audit.Enabled` and classifying `Enabled` `ordinary` -- an unnamed path
   defaults `secret` (`ui/tools/field-lists.mjs:46`) and would vanish from the schema. Regenerate
   `ToolFields.cls` with `node tools/field-lists.mjs`; `FieldLists.cls` is already correct.
8. `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- add the type to `COVEREDTYPES:86`, a
   `TYPEAUDITING` constant, the third arm in the `:239` type check, the dispatch line at `:263-267`,
   an `Auditing()` predicate whose body is only the permitted-field sweep, and
   `PermittedChangeFields:181` → `$ListBuild("Enabled")` -- AD-10 does not prohibit this write, but a
   covered type with no branch is refused wholesale (`:234-243`). No new code: `Codes()` stays ten.
9. `src/OcuPilot/Kernel/Proposal/Mint.cls` -- (a) rewrite `WarnsAuditingOff:206` to ask the question
   the payload already asks, through `Representable`/`Coerced` (`:342-361`), so `0`, `"false"` and a
   null warn while an absent `Enabled` does not (DW-1226); (b) carry the tool's `Destructive()` into
   `tValues` beside `:148`.
10. `src/OcuPilot/Kernel/State/Propose.cls` -- add a `Destructive` property, store, read and typed
    wire key beside `AuditWarning` (`:122`, `:212`, `:598`, `:640`) -- `auditWarning` is the exact
    precedent, and `src/OcuPilot/Test/ProposalWire.cls:28` `WIREKEYS` gains the key.
11. `src/OcuPilot/Screen/Registry.cls` -- extract ONE `DeclaredNames` builder from
    `ConfirmChannelProblem`'s two sources and have both validators consume it: replace `:1989-1995`'s
    two-part test, and add the `secretArguments` membership refusal before `:1998`'s credential rule.
    Fold the flag criteria (`Base.cls:535-564`) into the builder, de-duplicate, and use the
    `[]`-stripped spelling `Write.cls:141-146` honours. **State in the doc comment that adding the
    criteria half loosens `fingerprintExcludes` (criterion names were refused before) while scoping
    the tool half to settable fields tightens it (any row was accepted before), and pin both
    directions** -- a silent strengthening of a neighbouring gate must not go unremarked.
12. `ui/tools/screen-mirror.mjs` -- have `confirmChannelProblem` (`:374-408`) consume one derived set
    the same way `checkedIdRules` (`:1951-2004`) derives `IDRULES`: read the kernel's declaration,
    throw naming the source class on absence or mismatch, never re-implement the rule.
13. `src/OcuPilot/Test/ProposalScreen.cls` -- make the probe screen's `secretArguments: ["Password"]`
    sound by declaring `Password` among the names its read declares -- the same edit arms DW-1278's
    accept arm, and `src/OcuPilot/Test/Proposal.cls:207-211` keeps guarding it.
14. `src/OcuPilot/Kernel/Audit/Event.cls` -- add a `DROPPEDSECURITY` sentence beside `:68`/`:73`/`:84`
    and a `+pSecurityChange` arm to `:214` (DW-1171).
15. `src/OcuPilot/Port/AdminPort.cls` -- refuse the mutating-and-async combination at `:891` before
    `SaveRequestBody`, reading `%request.Method` against `MUTATINGTYPES` (no signature change), with
    the AD-35 reason in the comment (DW-1279). Neither Release-1 async read is mutating.
16. `ui/src/app/shell/proposal-card.ts` -- emit the typed secret values with `confirm` so the panel
    has a source (`:301`, `:276-282`, `:623`); render the 4px left-edge bar and Confirm in
    `{colors.destructive}` when the proposal is destructive (DESIGN.md:1176, :1243); add the published
    reason to `confirmAriaDisabled`'s unfilled-secret arm through `aria-describedby` (`:580-586`);
    keep `role="status"` on the warning and pin it. **No typed-name field** -- 14.7's.
17. `ui/src/app/shell/panel.ts` -- key the masked-field lookup on the proposal's own **tool**
    (`:838`, `:844`) rather than its entity type, and pass the card's values through `secretsFor`
    (`:1161-1164`) (DW-1227, DW-1251); add the new entity type to `agent-status.ts:450-454`'s
    re-read filter so the confirm that changes auditing re-reads `/agent/restraint`.
18. `ui/src/app/core/proposal-view.ts` -- filter `maskedFields` (`:291`) to the names this
    proposal's own payload carries, and project `destructive` off the wire the way `auditWarning` is
    projected (`:79`, `:292`) (DW-1227).
19. `ui/src/app/core/strings.ts` and `EXPERIENCE.md` -- append one Fixed-strings row after `:392` and
    one provenance-commented key for the unfilled-secret reason (DW-1232); tail only, union merge.
20. `src/OcuPilot/Test/AuditingUpdate.cls` -- the story's own class, armed by its own environment
    variable (declared here, in `scripts/ci-throwaway.sh` and in `ui/tools/ci.test.mjs`'s roster),
    restoring auditing in an in-method frame after `Try`/`Catch` **and** in a teardown that asserts
    the restore worked (`Smoke.cls:1334-1343` and `Test/AuditEvent.cls:326-337` are the two models).
21. Amend the pinning tests: `src/OcuPilot/Test/ProposalWire.cls:325-338` (equality against the
    shipped tool, driven through the tool's own `View()`), `src/OcuPilot/Test/Descriptor.cls:92-126`
    and `:1190`, `src/OcuPilot/Test/Prohibited.cls:178`, `src/OcuPilot/Test/ProposalConfirm.cls`,
    `src/OcuPilot/Test/AuditEvent.cls`, `src/OcuPilot/Test/AdminPortAsync.cls`,
    `src/OcuPilot/Test/SurfaceCoverage.cls` (the new `<tool>` row),
    `ui/tools/{screen-mirror,proposal-view,navigation,entity-ref,strings}.test.mjs`,
    `ui/src/app/shell/{proposal-card,panel}.spec.ts`.
22. `ui/browser/auditing-write.browser-spec.mjs` -- the new browser spec: the destructive card with
    its warning for each of the four `Enabled` shapes, the confirmed disable, the banner appearing,
    the confirmed re-enable, the banner clearing, and the instance left audited.

**Acceptance Criteria:**

- **AC1 (destructive + warning).** Given the agent proposes disabling auditing, when the card
  renders, then it carries the published warning inside the card, its left-edge bar and Confirm are
  `destructive`, and the declaration is the tool's own `DESTRUCTIVE` parameter carried on the wire —
  so Story 14.7's typed-name field applies to this write without another declaration.
- **AC2 (DW-1226).** Given the agent sends `Enabled` as `false`, `0`, `"false"` or null, when the
  proposal is minted, then every one of the four carries the warning, and the predicate and the
  payload answer the same question about the same value.
- **AC3 (DW-1244).** Given the shipped tool, when the suite runs, then `Mint.#AUDITINGTOOL` equals
  the tool's own `TOOLNAME` and `#AUDITINGFIELD` is one of its settable fields, asserted against the
  tool rather than against the constants, and the mint under test is driven through the tool's own
  `View()`.
- **AC4 (the write).** Given the user confirms, when the write runs, then auditing is disabled
  through `Security.Audit.Enabled` PUT as that user with `%Admin_Secure:USE`, and a caller holding
  neither that pair nor the code-database read is refused 403 naming the failed pair, with auditing
  unchanged.
- **AC5 (the marker, and why the epics clause was amended).** `epics.md` asked both that the disable's
  marker land "while auditing is still on" **and** that "the gap being visible on the ledger rows rather
  than silent" — **the two cannot both hold, because if the marker lands there is no gap.** The
  incompatible clause was removed and the observable one kept (amended 2026-09-21, orchestrator-authorised;
  AD-15 carries the impossibility, scoped to a write that closes the audit channel). It is a physical
  constraint, not a trade-off: no marker can land in a database that is closed, and emitting before the
  write instead was **considered and rejected** as strictly worse — it would record an agent write that may
  then fail, the failure AD-15's after-OK site exists to prevent. What survives is one-directional and both
  halves are named: **ledger → audit by timestamp**, via the vendor's registered and enabled `SystemChange`
  and `AuditChange` rows; **audit → ledger is lost**, because those rows carry no proposal id. Given the disable write, when its marker is emitted at the one site
  after the write reads OK, then it is dropped because auditing is already off and **the drop is
  recorded** — the ledger row reads not-marked, the collapsed tool-call line reads "done · audit not
  marked", and the banner turns on — while the audit database's own record of the change is the
  vendor's `SystemChange` and `AuditChange` rows written before auditing stopped; and the re-enable
  write's marker lands once auditing is back, so the ledger shows exactly **one unmarked row bracketed
  by marked ones** — the gap one write wide and legible rather than merely absent.
- **AC6 (the banner).** Given auditing is off, when any signed-in user's panel reads
  `/agent/restraint`, then the banner carries its sentence alone with no link and no action, and it
  clears on the read following the re-enable. The writing user's own tab re-reads on the confirm.
- **AC7 (round trip, never a resting state).** Given the demo sequence, when it completes, then
  `AuditEnabled` is 1, the `AgentWrite` triple is registered, and `smoke.sh`'s `auditmarker` check
  passes — every test that turns auditing off restores it on every exit path, including the failure
  path.
- **AC8 (DW-1206, both directions).** Given a descriptor declaring a `secretArguments` entry that
  names neither a settable field of its write tool nor a name its read declares, when the registry
  or the prebuild mirror validates it, then both refuse with one sentence from one shared set; and
  given a read-only screen declaring a credential-named criterion as a secret, both still accept it.
- **AC9 (DW-1278, DW-1251, DW-1227, DW-1232).** Given a declaration that names a secret, when the
  browser confirms, then the value the user typed reaches the confirm body from the card, a
  structured value is refused before the claim with the row still live, the masked fields asked for
  are the proposal's own tool's declared secrets filtered to its payload, and an unfilled field's
  Confirm states why through a published string.
- **AC10 (DW-1171, DW-1279).** Given a dropped `SecurityChange` emission, the log line reads the
  security sentence; and given a mutating request against an endpoint that would queue, the port
  refuses it before the vendor's task row is written.
- **Integration AC.** Consumer `ui/browser/auditing-write.browser-spec.mjs`, driving the shell in a
  real browser against the throwaway, confirms the disable proposal and observes the panel banner
  appear, then confirms the re-enable and observes it clear — the observable effect of this story's
  write, read through a consumer rather than through the tool's own state.

## Spec Change Log

- **2026-09-21, lead, orchestrator-authorised option (a).** The Rule 5 intent gap is closed by amending
  `epics.md`'s fifth acceptance block rather than by planning around it. The clause asked both that the
  disable's marker land "while auditing is still on" and that the gap be visible on the ledger; the two are
  incompatible, so the first was removed and the second kept. AD-15 gained a scoped impossibility note
  (spine `updated: 2026-09-21`), worded as an impossibility rather than a relaxation and covering only a
  write that closes the audit channel. AC5 is unblocked and two Rule 19 mutations are now REQUIRED: the
  drop's *recording* must be falsifiable, and the bracketing must be pinned as a pair.

## Review Triage Log

## Design Notes

**Governing ADs (Rule 6).** AD-1 (in-process, as the user), AD-2 (the port reproduces the vendor
sequence; only `AdminPort` names an `%Api.Admin.*` class), AD-3 (the field list is derived — already
committed for this endpoint — and classification is where a field becomes ordinary or secret), AD-4
(complete body over the fresh read; one field here, so the merge is trivial and still the same
path), AD-5 (one descriptor is the source; no second identity rule in TypeScript), AD-6 (minted,
fingerprinted, single-use; the confirm channel is closed to anything but the tool's declared
secrets), AD-8 **as amended 2026-09-21** (`%Admin_Secure` at `USE`, never `WRITE`), AD-10 (the
prohibited set is by effect and has one home; this write is deliberately outside it, and its type
still needs a branch), AD-12/AD-39 (one envelope, two renderings), AD-13 **as amended** (the scoped
triple, and a per-type canonical spelling rule — this story's `singleton`), AD-14 (one change event;
the entity-type enum is kernel-owned), AD-15 (the marker never fails the write; a failed marker
surfaces as "done · audit not marked"), AD-17/AD-38 (install enables auditing and registers the
events on every start, which is why an unaudited instance is repaired rather than left), AD-26 (the
two async entries, neither mutating), AD-29 (the pair set is established two ways together — the
backing class's own check plus a least-privileged principal on a throwaway), AD-34 (one atomic
transition, one lock per canonical target), AD-35 (secrets never reach a surface OcuPilot displays,
and never a stored task row), AD-40 (every write gate is at the write), AD-41 (the ledger row is
finalized after the write and records what was executed), AD-43 (this descriptor declares no
refresh and is not on the seven-screen roster, so there is no pause chip), AD-44 (the classic key),
AD-46 (OcuPilot's own rows stay visible). AD-9, AD-21, AD-27, AD-30, AD-31, AD-36, AD-37 hold and
this story changes nothing in them.

**Consumes:** 5.1–5.7 (mint, card, atomic confirm, execution as the user, the prohibited set's
`UNCOVERED` wholesale refusal, the marker, the change bus); 5.8 (the `USE` pair rule, the
disclosure's real rows, the refused-confirm write card); 5.9 (the per-type id rule with its client
twin, the `Prohibited` per-type block, and the lesson below). Story 2.2's derivation; Epic 13's
coverage gates.

**Consumed-by:** Story 7.4 builds this descriptor's screen out and calls the **same** tool and
endpoint — the descriptor is `built: false` precisely so there is one operation to call. Story 14.7
consumes the `DESTRUCTIVE` declaration to draw the typed-name field. 5.11–5.13 each add their own
type's `Prohibited` branch and id rule on this pattern. Epic 8 and Epic 11 depend on Epic 5's write
path.

**Why the id is a canonical singleton rather than kernel surgery.** `Write.View()` is `[ Final ]`
and takes the id from a required schema property, and `Mint`/`Confirm`/`Prohibited` each refuse an
empty id parameter and send exactly one query parameter. Measured: the endpoint ignores query
parameters entirely, so the existing contract works unchanged — but a model-supplied id would make
the target key caller-chosen, and two spellings would be two targets, defeating AD-34's per-target
lock and its sibling cancel. AD-13's per-type rule is the mechanism the spine already carries for
exactly this, so the new type canonicalizes every spelling to `SYSTEM`, which is `Security.System`'s
own row id rather than an invention. Do not rely on a schema `enum` for this unless
`Registry.ValidateArguments` is measured to honour one; the description guides the model and the rule
guarantees the key.

**The region to distrust (Story 5.9's lesson).** Five instances in one story of a safety predicate
whose refusing branch never ran against the real body over a real population. This story adds four
predicates — the `secretArguments` membership rule, the `Auditing()` prohibited branch, the
mutating-and-async port refusal, and the rewritten warning predicate — and two of them are today
guarded by tests that supply their own inputs. So: `ChannelProblem` is exercised through the probe
screen's **real** declaration and a real confirm, never through a fixture that stands in for it
(`Test/ConfirmFixture.cls:41-44` is a visibility passthrough and stays one — what changes is that
the names come from the declaration instead of from the test); and the union refusal is falsified in
both directions, because a fix that catches the typo and also refuses the legitimate criterion is
not a fix.

**Corrections to routed entries, at their origin.** Three of the ten describe the tree inaccurately
and the wrong sentence should be replaced rather than annotated:

- **DW-1246** says the in-card warning is the only `ocu-banner-warning` in the shell that is not
  `role=alert`. Measured false: four warning banners are already `role="status"`
  (`panel.ts:255`, `:411`, `proposal-card.ts:196`, `list-page.ts:52`). The convention is `alert` for
  faults and refusals, `status` for advisories, and the warning follows it. What survives is the
  three-polite-regions-in-one-frame concern, which only a screen reader can answer; it is in this
  spec's frontmatter `deferred:` list as human-owned.
- **DW-1227** says `screenForEntityType` has no test. It is named by
  `ui/tools/navigation.test.mjs:884,890`. What is untested is its `built` filter and its
  first-match-wins behavior for a duplicated entity type — and this story removes the secrets path's
  dependence on it anyway.
- **DW-1171** says the mis-logged case is `DESCRIPTIONGRANT`, an administrative role grant. That
  marker is emitted by the installer directly and never reaches `Event.cls:214`. The real case is a
  security-relevant switch or definition change whose `SecurityChange` row was dropped, and the
  probe is "unregister `SecurityChange`, then make a security-relevant switch write".

**Declined DW-1246 (the spoken half only):** whether three polite live regions in one frame are
announced is observable only to a screen reader, which no gate here runs; the checkable half (the
role, pinned; the census, corrected) is in scope and the rest is recorded as human-owned.

**What this story does not ship, and why that is not a gap.** No shipped descriptor gains a secret:
the auditing write has one boolean field. The secrets machinery is therefore armed by the probe
screen's real declaration on the instance side and by the component and tools tiers on the client
side; a **shipped**-secret browser leg arrives with the first secret-bearing write tool (FR-43's
X.509 and FR-46's wallet editors, outside Epic 5). Stating that is what keeps "the first real secret
field ships in 5.10", which four of the ten entries assume, from being quietly inherited as true.

**Two published tensions worth one line each.** `EXPERIENCE.md:424` classifies disabling auditing as
a **non-destructive** warning — but that row governs a screen's own `confirm-dialog` (Story 7.4's),
not a proposal card, and the epics block governs the agent write, which is declared destructive.
Separately, `DESIGN.md:1243` says `button-destructive` appears only once a typed name matches; with
14.7 unbuilt, this story ships the destructive styling without the field, because shipping the field
alone would leave Confirm permanently `aria-disabled` and AC7's round trip unreachable.

## Verification

**Targeted, inside the implement loop (loop):**

- `cd ui && node tools/field-lists.mjs && node tools/screen-mirror.mjs` — expected: both regenerate
  cleanly; `git diff` touches only `ToolFields.cls` and `screens.generated.ts`.
- `uv run scripts/check-objectscript.py <changed paths>` — expected: 21 rules pass.
- Load and compile the changed classes through the IRIS MCP tools with `server: "ocupilot-slot-a"`,
  reading the error text rather than assuming a clean compile. **Never turn auditing off on
  `ocupilot`.**
- `cd ui && npm run test:tools` and `npm run test:components` — expected: green. These cover
  `screen-mirror.test.mjs`, `proposal-view.test.mjs`, `navigation.test.mjs`, `entity-ref.test.mjs`,
  `strings.test.mjs`, `field-lists.test.mjs`, `agent-status.test.mjs`, `proposal-card.spec.ts`,
  `panel.spec.ts`.
- The throwaway `ocupilot-ci` is already up, installed and source-synced (`bash
  scripts/ci-throwaway.sh --dir /tmp/ocupilot-ci --project ocupilot-ci --web 52776 --super 1975`
  brings one up if it is not). **Before any result on it means anything:** sync the source to
  `/tmp/ocupilot-ci/src`, compile it, and run `OcuPilot.Install.Installer.Install` —
  `ui/tools/ci-runner.mjs` does **not** load source. Then `cd ui && npm run build && docker cp
  dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/` — a browser spec loads the
  deployed bundle, not the working tree. Tear down only a throwaway whose `up` this session ran.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.AuditingUpdate`
  — and the same, **one class per invocation, waiting for each to land in `%UnitTest_Result` before
  the next**, for `OcuPilot.Test.ProposalWire`, `OcuPilot.Test.Descriptor`,
  `OcuPilot.Test.Proposal`, `OcuPilot.Test.ProposalConfirm`, `OcuPilot.Test.Prohibited`,
  `OcuPilot.Test.ProhibitedRoute`, `OcuPilot.Test.ToolWrite`, `OcuPilot.Test.AuditEvent`,
  `OcuPilot.Test.AuditMarker`, `OcuPilot.Test.AdminPortAsync`, `OcuPilot.Test.SurfaceCoverage`,
  `OcuPilot.Test.DerivedFields`, `OcuPilot.Test.DeclarationCorpus`, `OcuPilot.Test.SwitchesWire`.
  Expected: each class green, totals verified with the `%UnitTest_Result` SQL probe rather than the
  runner envelope. Never two test calls in one message. **After the sweep, read `AuditEnabled` back
  and assert it is 1.**
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776
  OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1
  browser/auditing-write.browser-spec.mjs browser/proposal-confirm.browser-spec.mjs
  browser/panel.browser-spec.mjs` — expected: green. Clear `OcuPilot_Kernel_State.Pref` before
  trusting any local re-run: the browser suite is not idempotent on a reused instance (DW-1447,
  DW-1448).
- **Rule 19 — one mutation per AC, applied on the throwaway, reverted, tree confirmed byte-identical
  (`git status --short`, `git diff --stat`) after each:**
  - `mutation: restore the '%GetTypeOf(Enabled) = "boolean"' gate in Mint.WarnsAuditingOff -> OcuPilot.Test.AuditingUpdate (the 0/"false"/null warning legs) and ui/browser/auditing-write.browser-spec.mjs (AC2)`
  - `mutation: set Mint's AUDITINGTOOL to a different name -> OcuPilot.Test.ProposalWire (the equality against the shipped tool's TOOLNAME), which is AC3`
  - `mutation: answer 0 from Write.Destructive on the auditing tool -> the destructive bar and Confirm styling assertions in ui/browser/auditing-write.browser-spec.mjs and proposal-card.spec.ts (AC1)`
  - `mutation: set AuditingUpdate.WRITEPERMISSION back to "WRITE" -> OcuPilot.Test.ToolWrite and the least-privileged confirm leg in OcuPilot.Test.ProhibitedRoute (AC4)`
  - `mutation: answer the id verbatim for the singleton rule in EntityRef.NormalizedId -> OcuPilot.Test.AuditingUpdate's two-spellings sibling-cancel leg (AC4's one-lock half)`
  - `mutation: remove the auditing type from Prohibited.COVEREDTYPES -> OcuPilot.Test.Prohibited (the zero-uncovered-write-tools assertion) and every confirm leg in OcuPilot.Test.AuditingUpdate (PROHIBITED.UNCOVERED)`
  - `mutation: skip RecordMarking in Confirm.Transition -> the banner legs of ui/browser/auditing-write.browser-spec.mjs (AC6) and OcuPilot.Test.AuditingUpdate's recorded-fact leg`
  - `mutation (AC5, REQUIRED - the drop's RECORDING, not the drop): with Audit() answering 0, suppress the recording - no not-marked ledger row, no "done | audit not marked" line, no banner -> OcuPilot.Test.AuditingUpdate's drop-is-recorded leg and ui/browser/auditing-write.browser-spec.mjs. The gate here is not that the marker drops; it is that the drop is VISIBLE, which is the whole substance of the amendment and would otherwise be an unfalsifiable claim`
  - `mutation (AC5, REQUIRED - the BRACKETING as a pair): make the re-enable's marker drop too -> the paired leg asserting exactly ONE unmarked ledger row between two marked ones. Pin the pair, never each half alone: one marked row plus one unmarked row does not distinguish a one-write gap from an unbounded one`
  - `mutation: misspell the probe screen's secretArguments entry -> OcuPilot.Test.Descriptor and ui/tools/screen-mirror.test.mjs (AC8's refusing direction); and separately, remove the criteria half from the shared builder -> the planted apiKey assertions in both files (AC8's accepting direction)`
  - `mutation: accept an object at Confirm.ChannelProblem's type guard -> OcuPilot.Test.ProposalConfirm's structured-secret leg, with the row asserted still live and the token unburned (AC9)`
  - `mutation: return an empty map from panel.secretsFor -> the confirm-body leg of ui/browser/auditing-write.browser-spec.mjs or panel.spec.ts (AC9's data path)`
  - `mutation: key the masked-field lookup back on the entity type -> proposal-view/panel tests over a tool whose screen shares its entity type (AC9's tool-keyed half)`
  - `mutation: drop the +pSecurityChange arm from Event.cls:214 -> OcuPilot.Test.AuditEvent's new security-sentence method (AC10)`
  - `mutation: remove the mutating-and-async refusal from AdminPort.Sequence -> OcuPilot.Test.AdminPortAsync's new refusal method, armed by a fixture endpoint whose ShouldRunAsync answers 1 (AC10)`

**Full runs, once, before `dev_complete` (once, before dev_complete):**

- `cd ui && npm run build && npm test` — expected: the prebuild checkers pass and both client tiers
  are green. `npm test` does **not** run the browser suite.
- `cd ui && npm run test:browser` — expected: the whole browser suite green against the redeployed
  bundle.
- The full ObjectScript sweep through `ci-runner.mjs` against `ocupilot-ci`, one class at a time,
  reconciled against `%UnitTest_Result`, **followed by a read-back asserting `AuditEnabled` is 1**.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` — expected: zero
  checks `pending`, `fail = 0`, a non-zero executed count, and `auditmarker` **pass** — which is the
  check that fails if any class left auditing off. Read the skip lines, not the number.
- `bash scripts/lint-docs.sh` — expected: clean over the amended `EXPERIENCE.md`.

## Auto Run Result

Status: blocked
Blocking condition: intent gap

**The AC.** Story 5.10's fifth acceptance block in
`_bmad-output/planning-artifacts/epics.md:3694-3696`: "**Given** the disable write itself / **When**
its marker is emitted / **Then** it is marked while auditing is still on, and the re-enable write's
marker lands once auditing is back - the gap being visible on the ledger rows rather than silent."

**Why it is unreachable as worded.** AD-15 and Story 5.6 put the agent marker at one site in
`Confirm.Transition`, after the vendor write reads OK (`src/OcuPilot/Kernel/Proposal/Confirm.cls:365`
then `:386-392`) — and the write in this story is the one that turns auditing off. Measured on the
throwaway `ocupilot-ci` on 2026-09-21: `$System.Security.Audit("OcuPilot","Security","AgentWrite",…)`
returns 1 with auditing on, **0** in the same process immediately after
`Security.System.Modify("SYSTEM", AuditEnabled=0)`, and 1 again after the restore; `%SYS.Audit` holds
the before and after probe rows and **no** row for the emission between them. So the disable write's
own marker cannot land, and the clause is also internally at odds with its own purpose clause: if
both markers landed there would be no gap on the ledger rows to be visible. Satisfying it literally
would need either a second emission site or the marker moved ahead of the write for every write —
both re-decide what Story 5.6 settled and what AD-15 means, which is not this story's to change.

**Recommended amendment (one block, no scope change).** Replace that Then clause with the reachable
observable, which is stronger rather than weaker:

> **Then** its marker is emitted at the one site after the write reads OK, is dropped because
> auditing is already off, and **the drop is recorded** — the ledger row reads not-marked, the
> collapsed tool-call line reads "done · audit not marked", and the panel banner turns on — while
> the audit database's own record of the change is the vendor's `SystemChange` and `AuditChange`
> "stopped" rows, written before auditing stopped; **and** the re-enable write's marker lands once
> auditing is back, so the unaudited window is one write wide and visible on the ledger rows rather
> than silent.

Measured support for the amendment: the disable writes `SystemChange` ("Modify System: SYSTEM /
Audit enabled modified") and `AuditChange` ("Auditing to database … stopped") while auditing is
still on, and the re-enable writes `AuditChange` ("Auditing started to database …") — so the window
is bracketed on the audit database as well as on the ledger. A consequence worth recording in
`## Design Notes` at the same time: for the disable write AD-15's "either record locates the other"
degrades to one direction, because the vendor's rows carry no proposal id.

**Everything else is planned.** This spec is otherwise complete — Code Map, Tasks, ACs, all ten
ledger dispositions, and Verification — and its I/O matrix, AC5 placeholder and Verification are
already written to the recommended wording, so the re-dispatch after the amendment is a re-read
rather than a re-plan. Auditing on `ocupilot-ci` was left enabled (`AuditEnabled = 1`, verified
after the probe); `ocupilot` was never touched.
