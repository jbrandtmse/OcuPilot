---
title: 'Story 7.3: Delete an OAuth 2.0 client configuration or server client description'
type: 'feature'
created: '2026-09-23'
status: 'done'
baseline_revision: '5ca4d59858f35cb8dcd29fc68392cf8175018ddc'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-7-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-7-1-enable-disable-and-delete-a-web-application.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The OAuth 2.0 screen's Client configurations and Server client descriptions tabs are
read-only (`rowActions: []`), so nobody can remove an OAuth entry from OcuPilot, and the agent has no
write tool for the family. The prohibited set does not cover either entity type, so any write tool
over them would be refused `PROHIBITED.UNCOVERED` at every write.

**Approach:** Reuse Story 7.1's seam (AD-53) unchanged. Add two AD-51 action-style delete tools,
`security.oauthclients.delete` over `Security.OAuth2.Client.ClientConfiguration` and
`security.oauthserverclients.delete` over `Security.OAuth2.ServerClients`. Declare a `delete` row
action on each tab, cover both entity types in the prohibited set, append the two `DELETE` pairs to
`AdminPort`, and put both descriptors on the generic handler's roster with their consequence copy.

## Boundaries & Constraints

**Always:** Each delete declares `WRITETYPE = "DELETE"`, `SENDSBODY = 0`, `CHANGEACTION = "deleted"`,
`DESTRUCTIVE = 1`, a non-empty `FINGERPRINTSUBJECT` drawn from its `GET`'s answered keys with
identity excluded, and a `PRECONDITIONFIELD` inside that subject (AD-51). The subjects never name
`Metadata`, `ClientCredentials` or any key the Conventions › Secrets pattern matches. A proposal's
stored payload, diff, ledger row and wire answer therefore carry no `client_secret` or
`registration_access_token` (AD-35). Each tool's pair set is its screen's own two declared pairs.
The administrative resource is at `USE`, never `WRITE` (AD-8 as amended). Both callers publish one
AD-14 `deleted` event, and the tab re-fetches in place. The prohibited set stays in
`Prohibited.cls` and is evaluated at the write whatever the caller (AD-10). No self-protection rule
applies (`selfProtection: ""`), because AD-10 names no OAuth effect and install creates no OAuth
object (measured below). Only `AdminPort` names an `%Api.Admin.*` class (AD-27).

**Never:** No per-area handler and no file under `ui/src/app/areas/**`. The handler is the shell's
generic one. No second delete path around `Operation`/`ScreenAction`. Nothing reads or stores
`Metadata`. No new user-facing string is authored in `strings.ts`: the four keys below are the
lead's to publish, and this story consumes them. No edit to an Epic 8 hunk in a contended file, and
no file Epic 8 owns exclusively. No merge-write (`PUT`) tool for this family (Epic 12). No new test
class that needs an arming variable.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Row delete, client configuration | `OcuPilotTestDelete` selected, name typed exactly | `POST /screens/security.oauthclients/action {action:"delete", id}` → 200 `{action:"deleted", target:{type:"oauth2-client-configuration", scope:"instance", id}}`; row gone after the re-fetch; other rows unchanged | No error expected |
| Row delete, server client | the disposable server client's row; its **ClientId** typed | same route under `security.oauthserverclients`; `target.type` `oauth2-server-client`, `id` the ClientId | No error expected |
| Typed name mismatch | a re-cased name, then blur | `STRINGS.formTypedNameMismatch`, `aria-invalid`, button `aria-disabled`, Enter sends nothing | client-side; zero requests |
| Target already gone | row deleted elsewhere after the list read | the route's fresh read answers 404 | port fault envelope; no event published |
| Short of a pair | principal lacks `%DB_IRISSYS:READ`, or holds `%Admin_OAuth2_Server` instead of `%Admin_OAuth2_Registration` | 403 `AUTH.NOPRIVILEGE`, `detail.failedPair` names the first unheld pair, before any read | nothing read or written |
| Agent delete | `security.oauthclients.delete` with `ApplicationName` | proposal minted, card destructive, stored payload is the subject projection only; confirm deletes; agent marker emitted | a changed subject field between mint and confirm → fingerprint refusal |
| Changed field on a covered OAuth type | a payload/diff naming any field (e.g. `Description`) against either type | refused `PROHIBITED.UNCOVEREDFIELD` (reviewed-few list is empty) | 403 with the set's code |

</intent-contract>

## Code Map

Measured for this plan (vendor source via `%Compiler.UDL.TextServices.GetTextAsString` on
`ocupilot-slot-a`, `%SYS`, and `irissys/`):

- `%Api.Admin.Endpoints.Security.OAuth2.Client.ClientConfiguration`: `ResourcesOR` =
  `%Admin_OAuth2_Client`. Non-LIST types require query param `applicationName`. `NeedsRequestBody()`
  = `IsTypePut() || TYPECHANGESECRET`, so `DELETE` reads no body. `RunDelete` is `OAuth2.Client.Exists`
  (else 404), then `DeleteId`. `GET` keys come from the PUT template: `ServerDefinition, Enabled,
  Description, ClientType, SSLConfiguration, RedirectionEndpoint, JWTAudience, JWTInterval, ClientId,
  ClientCredentials, Metadata, DefaultScope`. `Metadata` is `ExportJSON(1)` of `OAuth2.Client.Metadata`,
  which declares `client_secret` and `registration_access_token` (`irissys/OAuth2/Client/Metadata.cls:24,29`).
- `%Api.Admin.Endpoints.Security.OAuth2.ServerClients`: `ResourcesOR` = `%Admin_OAuth2_Registration`.
  Non-LIST/POST types require `clientId`. `NeedsRequestBody()` = PUT, POST or `TYPESECRET`. `RunDelete`
  is `OAuth2.Server.Client.Exists` (else 404), then `DeleteId`. `GET` answers `Name, RedirectURL (array),
  LaunchURL, Description, ClientType, ClientCredentials, Metadata, DefaultScope`, and **no `ClientId`**.
- `irissys/OAuth2/Client.cls:11,16,1180`: `RESOURCEREQUIRED = %Admin_OAuth2_Client`, IdKey
  `ApplicationName`. `DeleteId` runs `$$$CheckForClassResource` (the resource at `USE`,
  `irissys/%sySecurity.inc:445`), escalates, deletes the stored tokens and audits.
  `irissys/OAuth2/Server/Client.cls:10,13,328`: `%Admin_OAuth2_Registration`, IdKey **`ClientId`**
  (`Name` has no unique index), and `DeleteId` revokes every access token for the client.
  `ClientType` is `Required` on both classes.
- No vendor layer requires `%Admin_Secure` for these deletes, so neither tool adds it (AD-8, AD-29).
- `src/OcuPilot/Install/**` creates no OAuth object: grep finds only `Smoke.cls` read checks.

Server:

- `src/OcuPilot/Screen/Tool/WebAppDelete.cls` -- the template to copy whole: parameters `:21-76`,
  `Endpoint`, `SettableFields` (`AdmittedFields`), `InputSchema`, `PrivilegePairs`, `StateDiff`.
- `src/OcuPilot/Screen/Tool/Write.cls` -- `IdArgument` `:353` (default `Name`) and `IdParam` `:360`
  (default `name`), both overridden here. `READANSWERS` `:153`. Read-only (contended).
- `src/OcuPilot/Api/ScreenAction.cls` -- `Handle` `:65` resolves the descriptor by `toolIdentifier`,
  the tool by `SCREENACTIONS`, and the id through `EntityRef.NormalizedId`. `Run` `:138` checks
  pairs, then the fresh read, `Body`, gate and apply. `Body` `:238` projects an action write's stored
  payload to the subject. Reused unchanged.
- `src/OcuPilot/Kernel/Proposal/Mint.cls` `:174-206` -- the action branch: `StateDiff`, then
  `Fingerprint.Projection` to the subject. Unchanged.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` (contended) -- header "Six types" `:30`,
  `COVEREDTYPES` `:128`, type params `:131-141`, the dispatch guard `:355`, the
  `APPLICATIONERROR` branch `:395`, `ApplicationError` `:631` (the reviewed-few precedent),
  `ReviewedFewOnly` `:734`. Epic 8's hunks on `origin/OCU-1-epic8` are the header `:8-12`, after
  `AlwaysProhibitedFields` `:289`, after `Target()` in `Prohibits` `:360`, and after
  `UncoveredWriteTools` `:430`. Stay off all four.
- `src/OcuPilot/Kernel/EntityType.cls` `:34` -- both types are already in the closed enum.
  `Kernel/EntityRef.cls` `NormalizedId` `:238` has no rule for either type, so each canonicalizes to
  itself. That matches exact IdKey lookup (inference).
- `src/OcuPilot/Port/AdminPort.cls` (SHARED-APPEND) -- `MUTATINGTYPES` `:173`, `BODYLESSTYPES` `:189`,
  and their doc blocks. `ImplementsRead` already maps `DELETE` → `RunDelete`, which both classes
  define. Epic 8's one hunk is at `:1055`.
- `src/OcuPilot/Screen/Descriptor/OAuthClientTab.cls`, `OAuthServerClientTab.cls` -- `rowActions`
  `:40`/`:35`, `table.emptyNextKey`/`emptyAgentKey` `:76-77`/`:62-63`, `id` `:38`/`:33`, and the doc
  line "declares no primary or row action". The Registry requires a write-capable table to name
  `emptyAgentKey` with `emptyNextKey` empty (`Screen/Registry.cls:1905-1910`). A single-part
  composite id is the precedent for keying a row off a non-name field (`TaskScheduleList.cls:86`).
- `src/OcuPilot/Test/OAuthProbe.cls` -- helper, not a test case: `Create` `:42`, `Remove` `:97`,
  `RegistrationId` `:143`, `EnsureClient` `:171`.

Client:

- `ui/src/app/shell/screen-action-handler.ts` -- `SCREEN_ACTION_DESCRIPTORS` `:25`,
  `DESTRUCTIVE_CONSEQUENCES` `:46-48`. The target is the store's selected row key, `rowKey`
  (`core/table-model.ts:40`): a composite id's parts, else the `name` column's field.
- `ui/src/app/shell/detail-page.ts` -- the OAuth tabs are `detail` archetype and render `ListPage`
  under the tab strip, so the row menu, command bar and typed-name dialog apply unchanged.
- `ui/src/app/core/screens.generated.ts` -- regenerated by `ui/tools/screen-mirror.mjs`. Never edit it
  by hand. Epic 8 regenerates it too, and the merge regenerates it again.

Tests (existing, to extend):

- `src/OcuPilot/Test/OAuthTabs.cls` (armed `OCUPILOT_ALLOW_PRINCIPALS`, 394 lines):
  `TestEachTabIsDeclaredAsTheOAuthScreenTab` `:132` asserts, for all five tabs, `IdKind` single
  `:151`, `emptyNextKey` `:159` and no action `:160`.
- `src/OcuPilot/Test/WireOAuthRead.cls` (armed, 347 lines) -- principals `CLIENTUSER`, `REGUSER`,
  `SERVERUSER` and `NODBUSER` already exist.
- `src/OcuPilot/Test/Prohibited.cls:181` (contended, off Epic 8's hunks) -- the covered-types literal.
  `:404` `TestNoRegisteredWriteToolHasAnUncoveredEntityType`.
- `src/OcuPilot/Test/ToolRoundTrip.cls:32` `REFUSEEMPTY` and `src/OcuPilot/Test/ReadTool.cls:93-94`
  (count and name roster), both contended. Epic 8 already rewrote these lines, and so did 7.1. The
  conflict is one the merge gate already reconciles, and this story adds two names to it.
- `src/OcuPilot/Test/SurfaceCoverage.cls` (contended) -- `<tool>` rows near `:104`. Epic 8 inserts
  after `tasks.schedule.resume`, so insert the two new rows after `security.auditing.update`.
- `ui/browser/oauth.browser-spec.mjs` -- the fixture pattern: `docker exec … OAuthProbe.Create()` in
  `before` and `Remove()` in `after`. Also `web-applications-actions.browser-spec.mjs`.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Screen/Tool/OAuthClientDelete.cls` (new) -- `TOOLNAME = "security.oauthclients.delete"`,
  `DESCRIPTORCLASS` `OAuthClientTab`, `SCREENACTIONS = "delete"`, `Endpoint()` answering
  `Security.OAuth2.Client.ClientConfiguration`, `IdArgument` `ApplicationName`, `IdParam`
  `applicationName`, `FINGERPRINTSUBJECT = "ServerDefinition,ClientType,DefaultScope,Enabled"`,
  `PRECONDITIONFIELD = "ClientType"`, `WRITERESOURCE = "%Admin_OAuth2_Client"`/`USE`, and
  `READANSWERS` read off a live `GET` on `ocupilot-ci` minus `Metadata`. Everything else is
  `WebAppDelete`'s shape.
- `src/OcuPilot/Screen/Tool/OAuthServerClientDelete.cls` (new) -- `security.oauthserverclients.delete`
  on `OAuthServerClientTab`, `Security.OAuth2.ServerClients`, `IdArgument` `ClientId`, `IdParam`
  `clientId`, `FINGERPRINTSUBJECT = "Name,ClientType,RedirectURL,Description"`,
  `PRECONDITIONFIELD = "ClientType"`, `WRITERESOURCE = "%Admin_OAuth2_Registration"`/`USE`, and
  `READANSWERS` measured the same way.
- `src/OcuPilot/Port/AdminPort.cls` -- APPEND `Security.OAuth2.Client.ClientConfiguration/DELETE` and
  `Security.OAuth2.ServerClients/DELETE` to `MUTATINGTYPES` and `BODYLESSTYPES`, plus one appended doc
  paragraph citing the measurement. No other line.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- first `git -C … fetch origin` and
  `git show origin/OCU-1-epic8:src/OcuPilot/Kernel/Proposal/Prohibited.cls`. Then add both types to
  `COVEREDTYPES` with two `TYPE*` params, widen the `:355` guard, and add one branch after `:395`
  calling a new private `OAuthEntry` placed after `ApplicationError`. `OAuthEntry` is
  `ReviewedFewOnly` for the type, and its doc comment says why no predicate exists. Update the `:30`
  count sentence. Nothing else.
- `src/OcuPilot/Screen/Descriptor/OAuthClientTab.cls` -- `rowActions [{"id":"delete","selfProtection":""}]`,
  `emptyNextKey ""`, `emptyAgentKey "oauthClientsEmptyAgent"`, and fix the doc's "no action" line.
- `src/OcuPilot/Screen/Descriptor/OAuthServerClientTab.cls` -- the same with `oauthServerClientsEmptyAgent`,
  plus `"id": {"kind":"composite","parts":["ClientId"]}`. This makes the row key, the typed name and
  the target the vendor's IdKey (see Design Notes).
- `ui/src/app/shell/screen-action-handler.ts` -- add both descriptors to `SCREEN_ACTION_DESCRIPTORS`
  and their `delete` entries to `DESTRUCTIVE_CONSEQUENCES` (`STRINGS.oauthClientDeleteConsequence`,
  `STRINGS.oauthServerClientDeleteConsequence`). Update the roster comment.
- `ui/src/app/core/screens.generated.ts` -- regenerate through `screen-mirror.mjs`.
- `src/OcuPilot/Test/OAuthProbe.cls` -- add `CreateDisposable()`, which makes client configuration
  `OcuPilotTestDelete` on `ISSUERA` and two server clients that share the `Name`
  `OcuPilotTestDeleteRegistration`, each only if absent. Add a public `DisposableRegistrationIds()`
  answering their ClientIds. Extend `Remove()` to delete every disposable still present.
- `src/OcuPilot/Test/OAuthDelete.cls` (new, **unarmed**: `ProhibitedFixture`/`ProposalFixture` and
  declarations only, no instance write) -- each tool's declaration, as
  `ToolWrite.TestTheWebApplicationDeleteToolIsAnActionWriteOverTheScreensOwnPairs` pins it: pairs
  equal to the screen's own set, no `WRITE`, `FingerprintSubjectProblem` empty, the port pairs admitted
  and bodyless, and the subject naming no secret-pattern key and no `Metadata`. Each covered type,
  driven through `ProhibitedFixture.Ask` with its tool: a subject-only payload is not prohibited, and
  a diff naming `Description` is `UNCOVEREDFIELD`. The family body rule (AC5).
- `src/OcuPilot/Test/OAuthTabs.cls` -- make the five-tab loop expect `delete` and the agent-invitation
  empty state on the two write-capable tabs and composite `ClientId` on server clients. Keep the
  other three as they are. New live legs, each calling `OAuthProbe.CreateDisposable()` first:
  `READANSWERS` equals the live `GET`'s keys minus `Metadata`; route delete of each type; the agent's
  mint and confirm of `security.oauthclients.delete`, with the stored payload, diff and wire answer
  carrying no `Metadata` or `client_secret`; and a delete of a vanished target answering 404. Mint
  and confirm the way 7.1's agent legs in `ProhibitedRoute` do
  (`TestTheAgentsDeleteMintedUnderAnotherSpellingIsStoredCanonicalAndRefused`,
  `TestADeleteWhoseTargetWasRemovedIsRefusedAndWritesNothing`).
- `src/OcuPilot/Test/WireOAuthRead.cls` -- the route as `NODBUSER` (refused, naming
  `%DB_IRISSYS:READ`) and `SERVERUSER` on server clients (refused, naming
  `%Admin_OAuth2_Registration:USE`). `CLIENTUSER` deletes the disposable client configuration with
  exactly the two pairs.
- `src/OcuPilot/Test/Prohibited.cls:181`, `ToolRoundTrip.cls:32` (`…:TOOL.ARGUMENTS` for both),
  `ReadTool.cls:93-94`, `SurfaceCoverage.cls` (two `<tool>` rows naming `OAuthDelete` methods) --
  roster updates, with each tool name read from the instance.
- `ui/src/app/shell/screen-action-handler.spec.ts` -- both descriptors register `delete` and open the
  dialog with their own consequence, and a server client's pending target is its `ClientId`.
- `ui/browser/oauth-delete.browser-spec.mjs` (new; `before`: `Create()` plus `CreateDisposable()`,
  `after`: `Remove()`) -- per tab: row menu → Delete, initial focus in the field, button
  `aria-disabled`, the mismatch message on blur, exact name → the row disappears and other rows stay.
  The server client leg also goes through the command bar.

**Acceptance Criteria:**

- AC1: Given a client configuration or a server client description row, when Delete is chosen from
  the row menu or the command bar, then a dialog titled "Delete <entry>" states that tab's published
  consequence, focuses the typed-name field, and keeps the destructive button `aria-disabled` until
  an exact, case-sensitive match. The confirmed delete is one `POST …/action`, followed by one
  `deleted` event and the tab's in-place re-fetch without the row. *Pin:*
  `oauth-delete.browser-spec.mjs` per tab.
- AC2: Given the server client tab, when a row's delete is confirmed, then the typed and sent id is the
  row's `ClientId` and the vendor deletes that client. Another client with the same `Name` survives.
  *Pin:* the `OAuthTabs` server-client route leg, which creates two clients sharing a `Name` and
  asserts one remains.
- AC3: Given the agent proposes either delete, when it mints and the user confirms, then the card is
  destructive, the stored payload is exactly the subject projection, the target is removed, and the
  agent marker is emitted. No stored or answered value carries `Metadata` or `client_secret`. *Pin:*
  the `OAuthTabs` agent leg.
- AC4: Given either type, when any write reaches the prohibited set, then the type is covered: a
  subject-only delete passes and any changed field is `UNCOVEREDFIELD`. A write tool over an
  uncovered type is impossible to register. *Pin:* `OAuthDelete`'s set legs and
  `Prohibited.TestNoRegisteredWriteToolHasAnUncoveredEntityType`.
- AC5 (epics' second AC): Given no `Security.OAuth2.*` endpoint merges, when any write tool in the
  family is registered, then it is either (a) bodyless, meaning `SENDSBODY = 0` and its
  `<endpoint>/<type>` is in `BODYLESSTYPES`, or (b) a `PUT` merge write, whose body is `Mint.Merge`'s
  complete property set over a fresh read. *Pin:* `OAuthDelete`'s family test iterates the registry
  over `Endpoint()` starting `Security.OAuth2.`. It asserts the (a) half is exactly the two deletes.
  It asserts the (b) half is empty as a temporary tripwire, whose doc comment names Epic 12 as the
  story that replaces it with the non-empty assertion.
- AC6: Given a principal short of a tab's pair, when it posts the row action, then the answer is 403
  `AUTH.NOPRIVILEGE` naming the pair, before any read. A principal holding exactly the tab's two pairs
  succeeds. *Pin:* `WireOAuthRead`'s legs.
- Integration AC (Rule 1/2): the agent's turn consumes `security.oauthclients.delete` against a real
  throwaway client configuration, and `security.oauthclients/read` over the wire then no longer lists
  it (the AC3 leg asserts through the read route, not through tool state).

## Spec Change Log

- 2026-09-23, lead spec gate: the four strings under Design Notes › Copy are published at
  `EXPERIENCE.md:405-408` and appended to `strings.ts` (`npm run test:tools` 1,322/0) -- consume the
  keys, do not re-author them. Accepted as planned: the server client tab keys on `ClientId`; each
  tool's pair set is its tab's own (AD-8, measured against the vendor's `USE` check).

## Review Triage Log

### 2026-09-22 — Review pass

- verdicts: 15 findings — high 0, medium 2, low 3, false 10, maybe-false 0
- findings:
  - `[medium]` `[patch]` (verification-gap) The agent's `security.oauthserverclients.delete` was never minted or confirmed; AC3 says "either delete" -- added `OAuthTabs.TestTheAgentsServerClientDeleteIsMintedConfirmedAndSparesItsNamesake` (subject-only payload, no secret, marker, namesake survives); red under `IdParam` = `name` (run 6886).
  - `[medium]` `[patch]` (verification-gap) AC6's exact-two-pairs success was proven for the client tab only -- `REGUSER` now deletes a server client in `WireOAuthRead`; red under `WRITERESOURCE` = `%Admin_Secure` (run 6887).
  - `[low]` `[patch]` (verification-gap) Neither tool's `StateDiff` precondition refusal was tested -- added `OAuthDelete.TestAReadWithoutTheClientTypeIsAPreconditionProblem`; red with the block removed (run 6888).
  - `[low]` `[patch]` (verification-gap) AC2's recorded mutation could not redden the named route leg -- ran `IdParam` = `name`, route leg red (run 6886); `## Verification` and the leg's doc line now name it.
  - `[false]` `[reject]` (verification-gap, other) AC4 and the matrix say "any changed field (e.g. `Description`) against either type" is `UNCOVEREDFIELD`, but a server client's `Description` is a subject field -- the literal reading contradicts AC4's own "a subject-only delete passes", since a delete's diff is every subject field; a changed `Description` is refused 409 `PROPOSAL.TARGETCHANGED` before the write, so no change goes through. The fix would edit this spec's intent.
  - `[false]` `[reject]` (intent-alignment A) Same root as the previous row -- same refutation.
  - `[false]` `[reject]` (intent-alignment B) Keying the whole server-client tab on `ClientId` is wider than the delete -- Tasks mandate the one-part composite id; the Name column stays the name cell, and `oauth.browser-spec.mjs` is green on it.
  - `[low]` `[patch]` (intent-alignment C) One `deleted` event per caller was not asserted for the OAuth tabs -- the handler spec now answers a realistic target and asserts one `deleted` event of each type; red with the publish skipped.
  - `[false]` `[reject]` (intent-alignment) "Target gone: no event" is inferred from the missing `target` -- the handler publishes only from an answered target, and 7.1's "a refused write ... publishes nothing" component test pins it for every descriptor.
  - `[medium]` `[patch]` (intent-alignment E) The agent server-client path is declaration-only -- grouped with the first row, same patch.
  - `[false]` `[reject]` (intent-alignment D) The vendor `GET` still answers `Metadata` in memory -- unavoidable at the port; no declaration names it and the mint projects to the subject, which the agent legs assert on everything stored and answered.
  - `[false]` `[reject]` (intent-alignment) The no-secret check omits the ledger's `Target` and `Route` columns -- `Target` is the input's id and `Route` the screen route (`Kernel/State/Ledger.cls:96-102`); neither can carry `Metadata`.
  - `[false]` `[reject]` (intent-alignment H) "Before any read" is shown by mutation only -- run 6875 removed the pair check and the refusal asserts went red; the refusal leg also asserts nothing was deleted.
  - `[false]` `[reject]` (intent-alignment G) `AdminPort`'s count sentence "seven" became "nine" beyond the appends -- no Epic 8 hunk touches it (`git merge-tree` against `origin/OCU-1-epic8` merges the file clean); reverting would leave a false count. Listed under footprint_extensions.
  - `[false]` `[reject]` (intent-alignment) Empty-state keys and the actions header changed on the two tabs -- the Registry requires `emptyAgentKey` with `emptyNextKey` empty on a write-capable table (Tasks mandate it), and the header follows from declaring a row action.

### 2026-09-22 — Review pass

- verdicts: 13 findings — high 0, medium 2, low 0, false 11, maybe-false 0
- findings:
  - `[medium]` `[patch]` (verification-gap) The server client's vanished-target 404 was unpinned (client-configuration leg only) -- added `OAuthTabs.TestARowActionAgainstAVanishedServerClientIsNotFound`; green (run 7140), red under `IdParam` = `name` (run 7139).
  - `[false]` `[reject]` (intent-alignment) `UNCOVEREDFIELD` is asserted in-process, not as a route 403 -- no delete tool can carry a non-subject field (carried reasoning, first pass), and the set-to-403 mapping is generic and pinned by `ProhibitedRoute`.
  - `[false]` `[reject]` (intent-alignment) The server-client agent leg omits the ledger check and the "wire" check is in-process -- the ledger row is written by the same generic confirm from the subject-projected payload the leg asserts; the client-configuration leg pins it.
  - `[false]` `[reject]` (intent-alignment) No server-client fingerprint-refusal leg -- `Fingerprint.Projection`/`Canonical` are generic and canonicalise arrays in order (`Fingerprint.cls:78-86,106-110`), and the server-client mint/confirm leg is green.
  - `[false]` `[reject]` (intent-alignment) The agent path's client-side `deleted` event is unchecked for these tools -- `turn.ts:1074` publishes from the confirm answer's `action` for every tool; the agent legs assert that answer.
  - `[medium]` `[patch]` (intent-alignment) No 404 leg for server clients -- grouped with the first row, same patch.
  - `[false]` `[reject]` carried (intent-alignment) "No event" on a vanished target is inferred from the missing `target` -- first pass's refutation.
  - `[false]` `[reject]` carried (intent-alignment H) "Before any read" is shown by mutation only -- first pass's refutation (run 6875).
  - `[false]` `[reject]` carried (intent-alignment D) The fresh `GET` holds `Metadata` in memory -- first pass's refutation.
  - `[false]` `[reject]` (intent-alignment) "No new armed test class" holds only by the letter -- the one new class, `OAuthDelete`, is unarmed; the live legs sit in existing armed classes as Tasks direct.
  - `[false]` `[reject]` (intent-alignment) Shared single-line lists collide with Epic 8 -- `git merge-file` against `origin/OCU-1-epic8` gives the same conflict-hunk count before and after this story in all six contended files; those hunks date from 7.1/8.2 and the merge gate reconciles them (`dispatch.yaml` `contended_extension_8_2b`).
  - `[false]` `[reject]` carried (intent-alignment B) Re-keying the server-client tab and its empty-state keys -- first pass's refutation.
  - `[false]` `[reject]` (intent-alignment) The AC5 family test and fixture helpers are outside the contract -- Tasks mandate both; `ChangeDisposableClientScope` serves the matrix's fingerprint-refusal row.

## Design Notes

**Governing ADs (Rule 6).** AD-3, AD-4 with AD-51 (AC5), AD-5 (one descriptor per tab; the action is
declared per tab), AD-6, AD-8 (screen's own pairs, `USE`), AD-10 (covered types; no OAuth effect is
prohibited), AD-12/AD-39, AD-13 (identity rule: none for either type), AD-14, AD-15 (marker on the
agent path only), AD-27, AD-29 (least-privileged proof in `WireOAuthRead`), AD-34, AD-35 (the
`Metadata` secrets), AD-40, AD-44 (the `classicLinkExemption` stays: the editors are still classic),
AD-51, AD-52 (both keep `AdminPort`), AD-53, AD-56 (the route takes `{action,id}` only).

**Consumes:** Story 7.1 (`Operation`, `ScreenAction`, the generic handler, `typed-name-dialog.ts`, the
`selfProtection` vocabulary), 6.4 (the tabs and `OAuthProbe`), 5.1-5.7 (mint, card, confirm, set,
marker, bus). **Consumed-by:** Epic 12's OAuth editors. Their `PUT`s replace AC5's tripwire, and they
must classify `Metadata` (`client_secret`, `registration_access_token`) as secret before a complete
body can be stored. `ClientConfiguration`'s `PUT` is also an upsert (`RunPut` creates when absent), the
AD-4 caveat AD-6's fingerprint covers.

**The server client is keyed by `ClientId`, not `Name`.** The vendor's IdKey is `ClientId`, `Name`
is not unique, and the `GET`/`DELETE` query parameter is `clientId`. A typed `Name` could not say
*which* entry goes. So the row key, the typed name, the dialog title and the target are the
`ClientId`, and the Name column stays the name cell.

**Measured, not recalled: no `%Admin_Secure`.** The spawn prompt's parenthetical named
`%Admin_Secure:USE`. The vendor gate and the class gate both require only the tab's own resource at
`USE` (Code Map), so each tool's pair set is the screen's declared two. `WireOAuthRead`'s
`CLIENTUSER` leg proves this against a real least-privileged principal.

**AC5's reading.** AD-4 binds writes that send a body. AD-51 states AD-4 "has no subject" for a
bodyless write, and the vendor reads no body for either `DELETE` (measured). The epics' AC is
therefore pinned as a registry-wide rule over the family: this story fills the bodyless half, and the
merge half stays a named tripwire for Epic 12. It is not an intent gap, because no reading makes a
delete send a body.

**Footprint (Rule 11).** New files are under shared-create paths. Contended edits (footprint
extensions, made after `fetch` and `git show origin/OCU-1-epic8:<path>`): `Prohibited.cls` (off
all four Epic 8 hunks), `Test/Prohibited.cls:181`, `Test/SurfaceCoverage.cls`, and the
`Test/ToolRoundTrip.cls:32` and `Test/ReadTool.cls:93-94` single-line rosters. Those two lines
already conflict since 7.1, and the merge gate reconciles them. `AdminPort.cls` is append-only.
`screens.generated.ts` is regenerated.

**Copy for the lead to publish** (EXPERIENCE.md Fixed strings, appended after `:403`, with
`strings.ts` keys appended after Epic 8's block):

| `strings.ts` key | Exact wording | Row note |
| --- | --- | --- |
| `oauthClientDeleteConsequence` | "Deleting this client configuration removes every token stored for it, and applications that use it can no longer obtain new ones. This cannot be undone." | confirm-dialog body, Delete client configuration (Story 7.3). `OAuth2.Client.DeleteId` calls `DeleteTokens` |
| `oauthServerClientDeleteConsequence` | "Deleting this server client description revokes every access token issued to it, and the client can no longer obtain new ones from this authorization server. This cannot be undone." | confirm-dialog body, Delete server client description (Story 7.3). `OAuth2.Server.Client.DeleteId` calls `RevokeByClientId` |
| `oauthClientsEmptyAgent` | "create an OAuth 2.0 client configuration" | resolves `:315` on the Client configurations tab. An empty list has no row to delete, so it names create (orchestrator ruling). The create tool ships with Epic 12 (inference: until then the agent answers that it cannot) |
| `oauthServerClientsEmptyAgent` | "create a server client description" | the same, for Server client descriptions. It supersedes `:368`'s read-only second line for these two tabs |

## Verification

Destructive checks run only on the throwaway `ocupilot-ci` (web 52776, super 1975). Never touch
`ocupilot` or any `ocupilot-slot-*` container. Run stateful classes one at a time, one runner call
per message, and never re-submit on a timeout.

**Targeted (loop):**

- `node ui/tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.OAuthDelete` -- green.
  Then, one call each, in turn: `OAuthTabs`, `WireOAuthRead`, `Prohibited`, `ToolRoundTrip`,
  `ReadTool`, `SurfaceCoverage`, `ToolWrite`.
- `cd ui && npm run test:tools` and `npm run test:components` -- green, including `strings.test.mjs`,
  `screen-mirror`'s checker and `screen-action-handler.spec.ts`.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`,
  then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/oauth-delete.browser-spec.mjs browser/oauth.browser-spec.mjs browser/web-applications-actions.browser-spec.mjs` -- green, against the rebuilt and redeployed bundle.
- `uv run scripts/check-objectscript.py` on the changed paths -- clean.
- Rule 19: one `mutation:` line per AC below its pinning test. Expected shapes:
  - Drop the handler roster entry: AC1's browser leg goes red.
  - Revert the server-client id to `single`: AC2 goes red.
  - Add `Metadata` to a subject: AC3's no-secret assert goes red.
  - Remove a type from `COVEREDTYPES`: AC4 goes red.
  - Set `SENDSBODY = 1` on one delete: AC5 goes red.
  - Drop the pair check in `ScreenAction.Run`: AC6 goes red.
- mutation: drop `OcuPilot.Screen.Descriptor.OAuthClientTab` from `SCREEN_ACTION_DESCRIPTORS`, rebuilt and redeployed → `oauth-delete.browser-spec.mjs` AC1 (client configuration) red; restored, rebuilt, redeployed → 2/2 green.
- mutation: `OAuthServerClientTab` id back to `single` → `OAuthTabs.TestEachTabIsDeclaredAsTheOAuthScreenTab` red (run 6876); with the mirror regenerated, `screen-action-handler.spec.ts` "targets a server client by its ClientId" red ("Shared name" for "abc-123"). AC2's route leg: `OAuthServerClientDelete.IdParam` answering `name` → `OAuthTabs.TestTheServerClientRowActionDeletesByClientIdAndSparesItsNamesake` and `TestTheAgentsServerClientDeleteIsMintedConfirmedAndSparesItsNamesake` red (run 6886).
- mutation (AC6, server client): `OAuthServerClientDelete.WRITERESOURCE` = `%Admin_Secure` → `WireOAuthRead.TestTheDeleteRowActionsRequireEachTabsOwnPairs` red on the `REGUSER` success leg alone (run 6887).
- mutation (precondition): the `tReported = ""` block removed from `OAuthClientDelete.StateDiff` → `OAuthDelete.TestAReadWithoutTheClientTypeIsAPreconditionProblem` red (run 6888).
- mutation (AC1 event): the handler's `ChangeBus.publish` skipped for the OAuth descriptors → `screen-action-handler.spec.ts` "registers delete on both tabs…" red on `events` length.
- mutation: `Metadata` added to `OAuthClientDelete`'s `FINGERPRINTSUBJECT` and `READANSWERS` → `OAuthTabs.TestTheAgentsClientConfigurationDeleteIsMintedConfirmedAndLeavesTheRead` red on the subject-projection and no-secret asserts (run 6874).
- mutation: `oauth2-client-configuration` dropped from `Prohibited.COVEREDTYPES` → `OAuthDelete.TestEachOAuthTypeIsCoveredAndRefusesAChangedField` red, `PROHIBITED.UNCOVERED` (run 6871).
- mutation: `OAuthClientDelete.SENDSBODY` = 1 with `FINGERPRINTSUBJECT` "" → `OAuthDelete.TestEveryOAuthWriteToolIsBodylessOrAMerge` red on both family asserts (run 6873); `SENDSBODY` = 1 alone is refused at registration (run 6872).
- mutation: the pair check ahead of the fresh read in `ScreenAction.Run` removed → `WireOAuthRead.TestTheDeleteRowActionsRequireEachTabsOwnPairs` red on code and `failedPair` (run 6875).
- mutation: `Security.OAuth2.Client.ClientConfiguration/DELETE` dropped from `AdminPort.MUTATINGTYPES` → `OAuthTabs` route and agent legs red, `PORT.NOTIMPLEMENTED` (run 6877).
- mutation (matrix row "Agent delete", fingerprint refusal): `DefaultScope` dropped from `OAuthClientDelete.FINGERPRINTSUBJECT` → `OAuthTabs.TestTheAgentsDeleteOfAChangedClientConfigurationIsRefused` red on the 409, the code and the survival asserts (run 6882).
- mutation (matrix row "Target already gone", server client): `OAuthServerClientDelete.IdParam` answering `name`, applied to the throwaway's copy only → `OAuthTabs.TestARowActionAgainstAVanishedServerClientIsNotFound` red on the 404 and code asserts (run 7139); restored → 17/0 (run 7140).
- Every mutation was reverted and the class reloaded; the tree hash matched before and after.

**Once, before `dev_complete`:**

- The full ObjectScript sweep on `ocupilot-ci`, per class, one call at a time. Verify the totals with
  the numeric-run-index `%UnitTest_Result` probe.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` -- every check
  executed and passing.
- The full browser suite is not run locally (Rule 29). CI runs it.

## Auto Run Result

Status: done
Blocking condition: none

Two AD-51 action deletes, `security.oauthclients.delete` and `security.oauthserverclients.delete`,
ship on the Story 7.1 seam. Each OAuth tab now declares a `delete` row action, and the server
client tab is keyed by `ClientId`. Both types are covered in `Prohibited.cls`, and both `DELETE`
pairs are appended to `AdminPort`. The generic handler holds both descriptors with the published
consequence copy. The four `strings.ts` keys were consumed, not authored.

Files:

- `Screen/Tool/OAuthClientDelete.cls`, `OAuthServerClientDelete.cls` (new): the two tools.
- `Screen/Descriptor/OAuthClientTab.cls`, `OAuthServerClientTab.cls`: the row action, the agent
  empty state, and `ClientId` as the server client key.
- `Kernel/Proposal/Prohibited.cls`: both types covered through the reviewed-few `OAuthEntry`.
- `Port/AdminPort.cls`: two appended pairs and one doc paragraph.
- `ui/.../screen-action-handler.ts` and `screens.generated.ts`: the roster and the regenerated
  mirror.
- Tests:
  - `Test/OAuthDelete.cls` (new, unarmed).
  - `OAuthTabs`, `WireOAuthRead`, `OAuthProbe`.
  - Roster rows in `Prohibited`, `ToolRoundTrip`, `ReadTool`, `SurfaceCoverage` and `PortFixture`.
  - `screen-action-handler.spec.ts`.
  - `oauth-delete.browser-spec.mjs` (new) and `oauth.browser-spec.mjs`.

This pass had two review layers and 13 findings. The two medium findings share one root cause and
got one patch: the new server-client vanished-target leg. There were 11 false findings (rows under
Review Triage Log) and nothing deferred. `followup_review_recommended: false`: only one patched
entry, and it was medium.

Verification, all on `ocupilot-ci` with `src/` reloaded (`LoadDir` SC=1):

- The story's classes, one per call: `OAuthDelete` 5/0, `OAuthTabs` 17/0 (run 7140),
  `WireOAuthRead` 6/0, `Prohibited` 11/0, `ToolRoundTrip` 2/0, `ReadTool` 27/0,
  `SurfaceCoverage` 4/0. The reds recorded at 6886-6888 were the mutation runs.
- The full ObjectScript sweep ran once, serialized through `ci-runner.mjs`, over 180 classes (runs
  6958-7137). The `%UnitTest_Result` probe gives 176 classes with 1,619 methods: 1,618 passed,
  0 failed, and 1 skipped (`ProhibitedRoute`'s auditing-over-the-wire leg).
- `AuditingUpdate`, `ErrorDelete`, `ProcessControl` and `TaskResume` refuse on this container,
  which predates their arming variables. They are recorded here, not fixed.
- `smoke.sh` 49/49.
- `check-objectscript` 0 problems.
- `npm run test:tools` 1,322/0 and `npm run test:components` 842/0.
- Bundle rebuilt and redeployed, then the browser specs `oauth-delete`, `oauth` and
  `web-applications-actions` 9/0.

Deviation: the server-client prohibited leg changes `DefaultScope`, not `Description`, because
that tool's subject carries `Description` and `Changed` skips subject fields.

footprint_extensions:

- Contended files, edited after `fetch` and `git show origin/OCU-1-epic8`, off Epic 8's hunks:
  `src/OcuPilot/Kernel/Proposal/Prohibited.cls`, `src/OcuPilot/Test/Prohibited.cls`,
  `src/OcuPilot/Test/SurfaceCoverage.cls`, `src/OcuPilot/Test/ToolRoundTrip.cls` and
  `src/OcuPilot/Test/ReadTool.cls`.
- `src/OcuPilot/Test/PortFixture.cls` (`contended_extension_8_2b`): the one `MUTATINGTYPES` line,
  and the merge keeps both new entries.
- `src/OcuPilot/Port/AdminPort.cls` (shared-append): the appends, plus the count sentence "seven"
  changed to "nine".
- `ui/src/app/core/screens.generated.ts`: regenerated.
- `git merge-file` against `origin/OCU-1-epic8` gives the same conflict-hunk count before and after
  this story in every contended file.

Residual risk: none beyond the known merge-gate reconciliation of the shared single-line rosters.
