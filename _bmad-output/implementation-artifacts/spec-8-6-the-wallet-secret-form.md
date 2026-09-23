---
title: 'Story 8.6: The wallet secret form'
type: 'feature'
created: '2026-09-23'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-8-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-8-5-x-509-import-edit-and-delete.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot can list wallet collections and their secrets, but it cannot store a secret. No tool writes `Wallet.Secret`. The vendor endpoint also has no single-secret read: it answers `GET` with 405, and its `LIST` returns only `{Name, Type}`. AD-4's fresh read and AD-6's fingerprint therefore have nothing to read.

**Approach:**

- Ship a `security/wallet/secrets/edit` form page for key-value secrets (`%Wallet.KeyValue`). The Secrets list's Create opens it, and so does the list's name cell.
- The form saves through `security.secrets.create` (a create, AD-54) and `security.secrets.update` (a merge, AD-4). The screen and the agent are two callers of one tool (AD-55).
- Both tools read through a new port, `Port/WalletPort` (AD-52). It completes the missing `GET` from the vendor's own `LIST` and from `%Wallet.Secret.Exists`. That completion needs a spine decision (Design Notes).
- The secret value is a masked field. It is sent only when it is entered, and no read returns it.

## Boundaries & Constraints

### Always

- **Secret value.** It is the tool's `Secret`, `secretArguments` on the Secrets list.
  - It travels only in the write request.
  - No OcuPilot read returns it, and `WalletPort` never reads it.
  - It never appears in a stored proposal argument, a diff value, a ledger row, screen context, an envelope, a status or a log line (AD-3, AD-6, AD-35, AD-41).
  - The masked field is never pre-filled or echoed. On an edit it is optional: an empty value keeps the stored one (measured).
- **Type.** The body is `{Type, WalletSecretConfig:{...}}`, and `Type` is always `%Wallet.KeyValue`. The create tool supplies it. The update tool takes it from the fresh read and refuses any other type before a write.
- **Complete set (AD-4).** An update sends the fresh read's `Usage`, `RequireTLS` and `AllowedHosts` with the caller's changes applied. It adds `Secret` only when a new value was entered.
- **Name.** It is exact and case-sensitive (`Probe86A` and `probe86a` coexisted on the instance), so there is no `IDRULES` entry. A secret is `<collection>.<secret>`, and the collection must already exist.
- **Wording.** Every field sentence is authored once in `Api/Error.cls`. Every visible word is a `STRINGS.<key>` with a Fixed strings row. The stored caption reuses `formSecretStored` ("Stored. Enter a new value to replace it.", `strings.ts:244`), and no duplicate is added.

### Never

- Never edit these: `Kernel/Proposal/Confirm.cls`, `Kernel/Restraint.cls`, `Port/LogSourcePort.cls`, `Install/{Smoke,Fixture}.cls`, `Screen/Tool/UserUpdate.cls`, or `ui/src/app/areas/{tasks,logs}/**`.
- No `Secret64`, no `%Wallet.RSA` or `%Wallet.SymmetricKey` write, and no collection create or edit.
- No delete tool and no row action (Design Notes, pending the lead).
- Never call `GetSecretValue`, `GetStoredSecret` or anything else that returns a stored value.
- Never touch the demo collection `OcuPilotDemo`. Tests use their own collection and remove it by exact name.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Create, screen | `POST /api/ocupilot/wallet/secret` `{Name:"C.S", Secret, Usage:5, RequireTLS:true, AllowedHosts:["h"]}`, name free | 201 `{name}`. The port receives `{Type:"%Wallet.KeyValue", WalletSecretConfig:{Usage:5, RequireTLS:true, AllowedHosts:["h"], Secret}}`. A `wallet-secret` `created` event follows, the route becomes `security/wallet/secrets/edit/C.S`, and Value is empty with the stored caption | No error expected |
| Edit, screen | `PUT /wallet/secret/C.S` `{Usage:1}`, stored `RequireTLS` false and `AllowedHosts` `["h"]`, no new value | Port body `{Type, WalletSecretConfig:{Usage:1, RequireTLS:false, AllowedHosts:["h"]}}` with no `Secret`. The stored value is kept. 200 and an `updated` event | Any key other than `Usage`, `RequireTLS`, `AllowedHosts` or `Secret` answers 400, and nothing is sent |
| Agent create | `security.secrets.create` `{Name, Usage?, RequireTLS?, AllowedHosts?}` | A diff row per supplied field, plus a required masked `Secret` row. The absence fingerprint is taken, and confirm sends what the user filled | A `Secret` among the model's arguments is refused at mint (existing) |
| Agent update | `security.secrets.update` `{Name, ...changes}` | A merge diff over the completed read, plus an **optional** masked `Secret` row (8.5's `OptionalSecrets`) | Fields the read lacks: 400 `TOOL.ARGUMENTS` |
| Deleted since the read (AC4) | Target deleted between the read and the write | Screen: 404 `WALLET.NAME.ABSENT`, nothing sent. Agent: 409 `PROPOSAL.TARGETCHANGED`. The Secrets list then holds no such secret | The vendor PUT would have created it (201, measured). This row is the guard |
| Field rules | Name empty, not `<existing collection>.<part>`, part outside `[A-Za-z0-9._-]+`, full name over 128; Secret missing on create or over 32,768 characters; Usage not an integer from 0 to 15; a host empty, over 255 characters, or holding whitespace or a comma | One `WALLET.<FIELD>.<RULE>` row per failing field | Screen: 422. Agent: 400 `TOOL.ARGUMENTS` at mint |
| Name taken | The exact-case name is present | `WALLET.NAME.TAKEN` on Save and on blur (`GET /wallet/secret/name`). A name that differs only in case is free. Taken after the mint: 409 `TARGETCHANGED` | Nothing is written |
| Collection absent | `?collection=` or the name's collection does not exist | Form read 404 `WALLET.COLLECTION.ABSENT`, Save 422 with the same code | Nothing is sent |
| Another type | The edit target is `%Wallet.RSA` or `%Wallet.SymmetricKey` | Read-only form showing Name, Type and `walletTypeReadOnly`. Save is `aria-disabled` | `PUT` answers 422 `WALLET.TYPE.UNSUPPORTED`. Agent update: 400 `TOOL.ARGUMENTS` |
| No wallet resource (AC5) | Caller lacks `%Admin_Wallet:USE` | The form route renders the screen-level denial naming `%Admin_Wallet` | Every wallet route answers 403 `AUTH.NOPRIVILEGE` naming the pair |
| Leave dirty | Any navigation away from a changed form, the agent's included | The shared leave question | Nothing is lost silently |

</intent-contract>

## Code Map

### Contention (Epic 7 head `2ce9d6739f018c91eb96154c5c1aba094ac28981`)

Before editing a ⚠ file, run `git fetch origin && git show origin/OCU-1-epic7:<path>`. Stay off its hunks: `e7 :n` means a line in Epic 7's file. Restructure nothing it added. A shared roster takes this story's own rows only.

**Needs the lead** (these files are in Epic 7's diff and not on the contended list):

- `ui/browser/security.browser-spec.mjs`:
  - :308 asserts that the Secrets name cell is not a link. This story makes it one, so the assertion flips.
  - :355 is the AC5 deep-link loop, which gains the form route.
  - Epic 7's hunks are e7 :224 and :238.
- `src/OcuPilot/Test/{WireSecurityRead,Wire,WireOAuthRead}.cls`: add the form route to their security-area screen rosters (8.5's rows: WireSecurityRead :786/:832/:860/:959/:978, Wire :577, WireOAuthRead :270/:285/:304/:319).
- `ui/src/app/core/screens.generated.ts`: regenerate only.
- `ui/tools/navigation.test.mjs`: only if a route row is needed.

### Server

- `Screen/Tool/Write.cls` (⚠, no edit): `READTYPE` :57, `WRITETYPE` :62, `SENDSBODY` :67, `PORTCLASS` :114, `CHANGEACTION` :124, `CREATES` :141; `DerivedFields` :216, `Endpoint` :317, `IdArgument`/`IdParam` :331/:338, `ExcludedFields` :346, `InputSchema` :456, `ArgumentProblem` :568. `FieldRows` admits only literal rows, so `AllowedHosts` is a tool-added argument as `RoleCreate.cls` :42/:78-90 adds `Resources`.
- Tool templates: `X509Import.cls` (`ComposedSecrets`/`OptionalSecrets` :95/:103), `X509Update.cls`, `ErrorDelete.cls` :32 (`PORTCLASS`).
- `Kernel/Proposal/Mint.cls` (⚠ rule, no edit): seeds only `tQuery(IdParam)` :165-167, needs one object :174, create inversion :175-179; `Merge` :421 refuses an argument the read lacks :440-442; `Compose` :504; `AppendComposedSecrets` :590.
- Port-subclass template: `origin/OCU-1-epic7:src/OcuPilot/Port/TaskPort.cls` (not on this branch).
- `Port/AdminPort.cls` (shared-append): `Invoke` :522; `WRAPPEDTYPES` :290 (`Endpoint/TYPE=Wrapper:OuterKeys`), `Wrapped` :1392; `Fail` :1685 already strips `WalletSecretConfig.` :1695-1701; ⚠ `MUTATINGTYPES` :189 (e7 :221-254, conflict certain). `VerifyApplied` :949 needs a `GET`, so no `VERIFIEDWRITES`.
- ⚠ `Kernel/Proposal/Prohibited.cls`: `COVEREDTYPES` :138, TYPE block :141-157, type gate :457, dispatch :494-525, `PermittedChangeFields` :316-325 and `PermittedCreateFields` :380-388 (X.509 :323/:386), `X509` :1027 with `ReviewedFewOnly` :1131. Epic 7 hunks e7 :146-165, :495-571, :616-706.
- ⚠ `Screen/Tool/Classification.cls`: tail append after the X.509 entries :252-267 (Epic 7 appends e7 :133-186). The list is `FieldLists.cls` :478-484. Regenerate with `cd ui && node tools/field-lists.mjs`.
- Descriptors: `WalletSecretList.cls` `primaryAction` :42, empty keys :64-65; `X509Form.cls` is the form template (`parentScope ""` :35).
- ⚠ `Api/Router.cls`: routes after :107-110, handlers after :396 (Epic 7 inserts e7 :92, :250-266). `Api/Error.cls`: block after :1922-1999, `ReasonForViolation` :1048, `X509ViolationCodes` :1188.
- Screen routes: `Area/Security/X509Rules.cls` and `X509Save.cls`. In `Create` :120 the verdict runs over `CallerFields` :137, then the rules and `Compose`, and only then the secrets go on the payload :152-157, cleared after `Send` :162. Save does not call `DerivedFields`, so it adds `Type` itself.
- Demo data: `Install/Fixture.cls` :405-430 owns `OcuPilotDemo`/`OcuPilotDemo.Sample`, read by `Test/SecurityLists.cls` :25/:28.

### Client

- Templates, `ui/src/app/areas/security/x509-form.page.ts`: `routeId()` :591 with `store.open` :336-348, masked field :140-201, reveal toggle :429-452/:526-532, summary :73-85, sticky bar :276-288, leave dialog :291-301, save and route replacement :560-574, denied `reason` :400-408. Store: secrets apart :146-150, `clearSecrets` :469, `canSave` :247, `save` :413-461, `changedFields` :520, `publish` :607. `user-create-form.page.ts` :151-152 is the `showStoredCaption` pattern. `x509-actions.ts` :34-40 is the Create handler; the collection comes from `parentCriteria(secretList, router.url)` (`core/navigation.ts` :338-348).
- `core/navigation.ts` (no edit): `editorScreenFor` :177 and `createFormFor` :188 find a built, unlisted `<list>/edit` screen with an id route; `screenForUrl` :652 matches exactly first (a collection named `edit` then cannot be opened; accepted). The name cell (`shell/data-table.ts` :471-478) links there once the form exists. `WalletSecretForm` sorts before `WalletSecretList`, so change toasts open the form.
- The screen-wide denial is `ScreenOutlet`'s (`shell/screen-outlet.ts` :191, :275-299), from the descriptor's `privileges`.
- ⚠ `shell/screen-outlet.ts` `DESCRIPTOR_PAGES`: after :103, import after :30 (e7 :17, :86). `app.ts`: injection after :249, sign-out reset after :522.
- ⚠ `core/strings.ts`: append before `} as const;` :1445 (Epic 7 e7 :1314-1421). ⚠ EXPERIENCE.md: rows :143 and :446 already specify this surface; append Fixed strings after :412 (e7 :392-415).
- Browser template: `ui/browser/x509-import.browser-spec.mjs` (`irisSys` :100, `signedInAt` :127, `fill` :144, `barButtons` :151, before/after :59-78).
- Bundle: initial total 1,200,871 B against `angular.json` :54 `1261kB`, pinned at `tools/angular-json.test.mjs` :371.

## Tasks & Acceptance

### Execution

#### Port and prohibited set

- `src/OcuPilot/Port/WalletPort.cls` -- new, `Extends OcuPilot.Port.AdminPort`, modeled on Epic 7's `TaskPort`. `Invoke` completes `Wallet.Secret` `GET` with the query `name`, in this order:
  1. Split the name into collection (first piece) and part (the rest).
  2. Run `##super` `LIST` with `collection` and `names=<part>`. This call carries the vendor gate. Its 404 (collection absent) answers 404 with the fault `WALLET.COLLECTION.ABSENT`.
  3. Keep only the row whose `Name` equals the name exactly (the vendor filter ignores case). No row answers 404.
  4. For a `%Wallet.KeyValue` row, switch to `%SYS` by explicit save and restore (AD-16), call `##class(%Wallet.Secret).Exists(name, .obj, .sc)` and answer `{Type, Usage, RequireTLS, AllowedHosts:[...]}`. The last is `$ListToString` split into a JSON array. A failed class read fails the whole read.
  5. For any other type, answer `{Type}` alone.
  6. Never read a stored value, and drop `obj` before returning. Every other endpoint and type is `##super` unchanged.
- `src/OcuPilot/Port/AdminPort.cls` (shared-append):
  - ⚠ `MUTATINGTYPES` gains `Wallet.Secret/PUT`.
  - `WRAPPEDTYPES` gains `Wallet.Secret/PUT=WalletSecretConfig:Type`.
  - No `VERIFIED*` entry: there is no `GET`, and the probes show the PUT failing loudly.
- ⚠ `src/OcuPilot/Kernel/Proposal/Prohibited.cls` (off Epic 7's hunks):
  - Add `TYPEWALLETSECRET "wallet-secret"` to `COVEREDTYPES`, the type gate and the dispatch (`ReviewedFewOnly`).
  - Permitted create and change fields are `Usage,RequireTLS,AllowedHosts`.
  - No own-object predicate: OcuPilot writes no wallet secret of its own. The demo is opt-in fixture data (AD-25).

#### Tools

- `src/OcuPilot/Screen/Tool/WalletSecretCreate.cls` -- new, on `X509Import`/`RoleCreate`: `TOOLNAME "security.secrets.create"`, `DESCRIPTORCLASS WalletSecretList`, `PORTCLASS WalletPort`, `CREATES 1`, `WRITETYPE "PUT"`, `READTYPE "GET"`, `CHANGEACTION "created"`, `Endpoint() "Wallet.Secret"`, `IdArgument "Name"`, `IdParam "name"`, `PERMITTEDFIELDS "Usage,RequireTLS"` plus the tool-added `AllowedHosts` string array, `COMPOSEDSECRETS "Secret"`. `DerivedFields` adds `Type` `%Wallet.KeyValue`. `ArgumentProblem` runs `WalletRules.Validate` with the secret check off.
- `src/OcuPilot/Screen/Tool/WalletSecretUpdate.cls` -- new, on `X509Update`: `TOOLNAME "security.secrets.update"`, `WRITETYPE "PUT"`, `SENDSBODY 1`, `CHANGEACTION "updated"`, the same port, ids and fields, `COMPOSEDSECRETS` and `OPTIONALSECRETS` `"Secret"`. `ArgumentProblem` reads through the port and refuses a `Type` other than `%Wallet.KeyValue`. The default fingerprint covers the merged payload, `Type` included.
- ⚠ `Classification.cls` (tail append): both tools over `fieldList "Wallet.Secret:%Wallet.KeyValue"`, with `Usage` and `RequireTLS` `ordinary`, `AllowedHosts` `opaque`, `Secret` and `Secret64` `secret`. Regenerate `ToolFields.cls`.
- `Screen/Descriptor/WalletSecretList.cls`: `primaryAction {"id":"create"}`, `"secretArguments": ["Secret"]`, `emptyNextKey ""`, `emptyAgentKey "walletSecretListEmptyAgent"`, and its doc.
- `Screen/Descriptor/WalletSecretForm.cls` -- new, on `X509Form`: `route "security/wallet/secrets/edit"`, `sideBarPosition 0`, `archetype "form-page"`, `entityType "wallet-secret"`, `scope "instance"`, `parentScope ""`, `id single`, the list's privileges (`%Admin_Wallet:USE`, `%DB_IRISSYS:READ`; AD-8), `context.secretFields ["Secret"]`, `classicPage ""`, `toolIdentifier "security.secretform"`.

#### Screen routes

- `src/OcuPilot/Area/Security/WalletRules.cls` -- new, on `X509Rules`:
  - `Validate(pName, pArgs, Output pViolations, pCheckName, pCheckTaken, pCheckSecret)` holds the matrix rules; collection existence is `Wallet.Collection` `GET` through the port.
  - `HandleForm` (`GET /wallet/secret/form[?name=|?collection=]`) answers `{requiredFields, maxLengths, rules}`, plus `secret:{Name, Collection, Type, Usage, RequireTLS, AllowedHosts, editable}` from `WalletPort` for a name (404 `WALLET.NAME.ABSENT`), or a collection-existence check for a collection.
  - `HandleName` (`GET /wallet/secret/name?name=`) answers `{taken}`, exact case.
- `src/OcuPilot/Area/Security/WalletSave.cls` -- new, on `X509Save`:
  - `HandleCreate`: gate, verdict over the non-secret fields, `Validate`, `Compose`, then `Type` and the value on the body, then the port `PUT`.
  - `HandleUpdate`: gate, fresh `GET` (404 `ABSENT`), key-set and type checks, `Validate`, `Mint.Merge`, verdict, `Secret` only when non-empty, then the port `PUT`.
  - Both clear every local holding the value. `PROHIBITED.*` answers 403.
- ⚠ `Api/Router.cls`: `GET /wallet/secret/form`, `GET /wallet/secret/name`, `PUT /wallet/secret/:id`, `POST /wallet/secret`, thin handlers.
- `Api/Error.cls`, its own block: `WALLET.VALIDATION` (422); `WALLET.NAME.{REQUIRED,SHAPE,LENGTH,TAKEN,ABSENT}`, `WALLET.COLLECTION.ABSENT`, `WALLET.SECRET.{REQUIRED,LENGTH}`, `WALLET.USAGE.RANGE`, `WALLET.ALLOWEDHOSTS.SHAPE`, `WALLET.TYPE.UNSUPPORTED`, each with its sentence; `ReasonForViolation` branches and `WalletViolationCodes`.

#### Client

- `ui/src/app/areas/security/wallet-actions.ts`, `wallet-secret-form.store.ts`, `wallet-secret-form.page.ts` -- new, ids `ocu-wallet-`. Fields in order:
  1. Collection, read-only.
  2. Name, the part after the collection: required on create, read-only on edit.
  3. Value: masked; required on create, optional on edit; `walletValueHelp` beneath; the `formSecretStored` caption whenever a value is stored (edit mode, including right after a save).
  4. Usage: checkboxes HTTP 1, SQL 2, SOAP 4, Custom 8, sent as their sum, all checked by default.
  5. Require TLS: checkbox, on by default.
  6. Allowed hosts: comma-separated, sent as an array, `walletHostsHelp`.
- A target that is not `%Wallet.KeyValue` renders read-only (Name, Type, `walletTypeReadOnly`).
- The store holds the value apart from the edit buffer, sends it once, and clears it on an accepted save, on reset and across the route replacement. An edit sends `changedFields()` after the fresh read, plus a value if entered; an unchanged edit writes nothing.
- Save publishes `{kind:'changed', type:'wallet-secret', scope:'instance', id, action}`. A create replaces the route with `security/wallet/secrets/edit/<encodeEntityId(name)>` and shows `formSaved`.
- ⚠ `screen-outlet.ts` gets the `WalletSecretForm` entry; `app.ts` injects `WalletActions` and resets the store at sign-out.
- ⚠ `strings.ts` and EXPERIENCE.md Fixed strings, append only, reusing any key whose value and meaning match: `walletSecretFormLabel` "Secret", `walletSecretListEmptyAgent` "store a secret", `walletFieldCollection` "Collection", `walletFieldValue` "Value", `walletFieldUsage` "Usage", `walletFieldRequireTls` "Require TLS", `walletFieldAllowedHosts` "Allowed hosts", `walletUsageHttp` "HTTP", `walletUsageSql` "SQL gateway", `walletUsageSoap` "SOAP", `walletUsageCustom` "Custom", `walletValueHelp` "Stored as typed. For HTTP, SOAP or SQL use, enter JSON such as {"user": "...", "password": "..."}.", `walletHostsHelp` "Comma-separated. Applies only when TLS is required.", `walletTypeReadOnly` "Only key-value secrets are edited here.".
- **Bundle.** If the initial total exceeds 1,261,000 B, re-base under DW-1166 (pre-approved): about 5% above the measured total, in `angular.json` and the `angular-json.test.mjs` pin together, citing the byte count in the commit.

#### Tests and rosters

- `Test/WalletProbe.cls` -- new helper: creates and removes the collection `OcuPilotProbe86` (resource `%Admin_Wallet:USE`) and its secrets by exact name in `%SYS`, asserting they are gone; it can add a `%Wallet.SymmetricKey` (`Length` 16) for the other-type legs.
- `Test/WalletPortRead.cls` -- new: the completed `GET` (exact match, a case-variant sibling, an absent name, an absent collection, a non-key-value type answering `{Type}`), no stored value in any answer, and the AC6 vendor facts (array and number `Usage` store a number; object and string `Secret` both save).
- `Test/WalletSecretCreate.cls`, `Test/WalletSecretUpdate.cls` -- new, each under 500 lines, with a body-recording port subclass: every matrix row on both callers, one body from both callers, AC2's value scan (stored args, diff, ledger fields, envelopes, form read, list read and its tool), the kept value on a no-value edit, and the optional card row.
- `Test/WalletWire.cls` -- new, armed on `OCUPILOT_ALLOW_PRINCIPALS` (add to `scripts/ci-throwaway.sh` :204), through the real port: AC4 both ways (a raw port `PUT` with a value against a deleted name answers 201; the tool's confirm after the delete answers 409 and creates nothing); AC5 with a purpose-built role lacking `%Admin_Wallet` (403 on every wallet route, naming the pair); no value in the message log after a refused save; cleanup by exact name.
- `wallet-secret-form.store.spec.ts`, `wallet-secret-form.page.spec.ts` -- new.
- `ui/browser/wallet-secret.browser-spec.mjs` -- new: AC1 (masked, empty, caption after save, route replacement), AC7 (list row without refresh, name cell opens the form), AC5 (deep link without the resource), AC8 (leave question).
- Rosters, own rows only: ⚠ `Test/{SurfaceCoverage :102/:110-112, EndpointCoverage :140-143, ReadTool :93-94, ToolRoundTrip :30, PortFixture :21, Prohibited :193}.cls`; `Test/SecurityLists.cls` (the Secrets primary action); the Needs-the-lead files; `screen-mirror.test.mjs` and `app.routes.spec.ts` if they redden.

### Orchestrator rulings at the spec gate, 2026-09-23

- [ ] [Lead] **`Port/WalletPort` is AD-27's third named case** (written into AD-27, with the fingerprint's limit stated there: the stored value is never read, so a value change between propose and confirm cannot be detected; only `Usage`, `RequireTLS` and `AllowedHosts` are fingerprinted). Both wallet tools declare the port (AD-52). Add a test that fails when the composed read starts returning the stored value.
- [ ] [Lead] **Key-value secrets only** (a tier-1 reading of AC1). An RSA or symmetric-key secret opens read-only, and the read-only view says plainly that those types are edited in the classic portal -- a tier-1 Fixed-strings row (EXPERIENCE.md, append-only) if no existing string says it. Creating and editing them is DW-1555 (range-end cleanup).
- [ ] [Lead] **Delete moves to Story 9.5** as DW-1556 (FR-46's delete: the agent tool and the Secrets-list row action). This story ships no delete.
- [ ] [Lead] **`ui/browser/security.browser-spec.mjs:308`** (Epic 7-modified; its hunks are at 224 and 238-247): flip only that one assertion to "the Secrets name cell is a link and opens `security/wallet/secrets/edit/<name>`". Touch no other line. The form route's entries in `Test/{Wire,WireSecurityRead,WireOAuthRead}.cls` fall under the roster rule, 2026-09-23; `screens.generated.ts` is regenerate-only.

### Acceptance Criteria

- **AC1.** Given the secret form, when it renders, then Value is a masked field (password input, labeled show/hide toggle, never pre-filled or echoed), and after a save by either caller it is empty and captioned "Stored. Enter a new value to replace it.".
- **AC2.** Given a secret stored by either caller, when any read is made afterwards, then the value is never included on any surface named under Always, even after a refused save.
- **AC3.** Given `Wallet.Secret` publishes no body template, when the tools' field lists are built, then they come from `FieldLists` `"Wallet.Secret:%Wallet.KeyValue"`, derived from the class and pinned by `DerivedFields` :175, so `field-lists.mjs --check` and `DerivedFields` fail when the instance disagrees.
- **AC4.** Given the PUT is an upsert, when a body is sent against a target deleted since the read, then the vendor would create it (a pinned port test shows 201), and both callers refuse first, leaving no secret.
- **AC5.** Given a user without `%Admin_Wallet:USE`, when they open the form by any route, then the whole screen is the denial naming `%Admin_Wallet`, and every wallet route answers 403 naming the pair.
- **AC6.** Given the wire shape, when the story is planned, then `Usage` and `Secret` are settled on the instance (Design Notes), and `WalletPortRead` pins what this plan relies on.
- **AC7 (Integration).** Given a secret created or edited by either caller, when the Secrets list (the change bus's consumer) is open, then it shows the row without a manual refresh, and its name cell opens the form.
- **AC8.** Given the form holds a change, when any navigation leaves, the agent's included, then the shared leave question asks first.

## Spec Change Log

- 2026-09-23, spec gate (orchestrator rulings): AD-27's third case approved and written with its fingerprint limit; key-value only with a classic-portal line for the other types (DW-1555); delete to Story 9.5 (DW-1556); one assertion in `security.browser-spec.mjs` approved; AD-4 corrected for `Wallet.Secret` at its origin.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-2, AD-3, AD-4, AD-5, AD-6, AD-8, AD-10, AD-13, AD-14, AD-16, AD-21, AD-24, AD-27, AD-34, AD-35, AD-36, AD-39, AD-41, AD-52, AD-54, AD-55.

### What the instance settled (AC6)

The vendor source was read on `ocupilot-slot-b` with `GetTextAsString` (`%Api.Admin.Endpoints.Wallet.Secret`), together with `%Wallet.KeyValue`, `%Wallet.Secret` and `%SYS.Wallet.Secret` in `irissys/`. The probes ran over HTTP on `ocupilot-b-ci`, in the demo collection. Each probe secret was deleted by exact name, and the list afterwards held only `OcuPilotDemo.Sample`.

- **Endpoint.**
  - `ResourcesOR` is `%Admin_Wallet`. `PUT` and `DELETE` take `name`, and `LIST` takes `collection` and optionally `names`.
  - `GET` answers 405. `LIST` rows are `{Name, Type}`.
  - The `names` filter ignores case: it returned both `Probe86A` and `probe86a`.
- **`Usage` and `Secret`.** Both published shapes are accepted, and each is stored in one form.
  - `Usage:["HTTP"]` stored 1, `Usage:5` stored 5, and `"HTTP,SQL"` stored 3. The bits are HTTP 1, SQL 2, SOAP 4 and CUSTOM 8. An omitted `Usage` stored 15, and `["FOO"]` answered 500 (#5802).
  - `Secret:{user,password}` stored the JSON text `{"user":"u86","password":"p86"}`. `Secret:"plain86"` stored `plain86`. A JSON-text string stored exactly what the object form stored.
  - The tools therefore send `Usage` as the number the class reads back and `Secret` as a string. That keeps the diff and the fingerprint comparing like with like.
- **PUT.**
  - It creates (201) or modifies (200).
  - A modify sets only the keys sent: a `RequireTLS`-only body kept `Usage` and the stored value. A `Secret` of `""` keeps the stored value too (source: `ModifyInternal`'s `If secret'=""`).
  - An unknown key answers 400 (#26218), and an absent collection 422.
  - A different `Type` on an existing name answers 500 (#5805).
  - A `Secret`-less body for an absent name answers 500 (#5659 `Storage` required). One carrying a `Secret` for a name deleted a moment earlier answered 201. The upsert therefore creates a complete new secret rather than a stub.
- **DELETE.** 200, and 404 when the secret is absent.
- **Names.** `Probe86A` and `probe86a` coexisted, so names are case-sensitive. The pattern is `<collection>.<part>`, 128 characters at most. A name without a `.` was refused (#7209).
- **Class read.** `##class(%Wallet.Secret).Exists(name, .obj)` answered the class, `Usage`, `RequireTLS` and `AllowedHosts` with no value. By the source, it needs the caller's `%Admin_Wallet:USE` (`CheckPermission`) and escalates to its storage by itself; the probe ran as `_SYSTEM`.

### Ruled: AD-27's third case, the wallet secret read

`Wallet.Secret` has no `GET`, and its `LIST` carries no metadata. Without a read, AD-4's merge and AD-6's fingerprint have no subject.

Recommended wording for AD-27's last bullet: "The third case: `Wallet.Secret` `GET`, which the admin API does not offer (405). `Port/WalletPort` (AD-52) answers it from the endpoint's own `LIST`, filtered to the exact name, and, for `%Wallet.KeyValue`, from the documented `%Wallet.Secret.Exists` in `%SYS` for `Usage`, `RequireTLS` and `AllowedHosts`. It never reads a stored value."

This is a read completion, not a refused value. The gate is still the vendor's, since `LIST` runs first, and `%Wallet.*` is documented rather than `[Hidden]`.

**Alternative (an AD-4 amendment instead):** the update sends only the fields the caller sets. The vendor keeps the rest (measured). The edit form then cannot show the current `Usage`, `RequireTLS` or `AllowedHosts`.

### SPINE DECISION NEEDED: correct AD-4 at its origin

- AD-4 :129 lists `Wallet.Secret` among the endpoints that erase omitted fields. The probes show that it keeps them, so its entry should read as `Security.Resource`'s does.
- AD-4 :133's "silently create a stub" should read "create a new secret when the body carries a value". A `Secret`-less body for an absent name fails 500.
- The same correction applies to `epic-8-context.md`, whose "Assume nothing merges" bullet names `Wallet.Secret`.
- The stored value is never sent back on an update. That is what makes it write-only, and it depends on the vendor's measured keep.

### Pending the lead (product scope)

- **Scope.** This plan covers key-value secrets only. RSA and symmetric keys open read-only, which fits UX row :143, "masked value". The alternative adds `%Wallet.SymmetricKey` (a generated length, or a value) and RSA PEM content. RSA's `*File` fields are refused under AD-21.
- **Value shape.** The value is stored as typed. JSON text gives key-value use, and the probe showed it stores what the object form stores. The alternatives are the fixture's `{"value": V}` or separate User and Password fields.
- **Delete and row action.** FR-46's delete has no owning story. A candidate for the orchestrator to place is Story 9.5, the nearest Security-and-secrets story. It would need:
  - `security.secrets.delete` (action-style, `READTYPE "GET"` through `WalletPort`, `BODYLESSTYPES` `Wallet.Secret/DELETE`);
  - Epic 7's AD-53 row action;
  - a consequence sentence and its Fixed strings row (DW-1502 applies).

### Consumes and consumed-by

**Consumes:**

- 8.1's create kind;
- 8.2's composed secret and masked field;
- 8.5's optional composed secrets;
- Epic 6's Wallet and Secrets lists;
- Story 3.5's `FormDirty`;
- AD-52's port declaration;
- the Epic 1 field-list derivation (`FieldLists`, `DerivedFields`).

**Consumed-by:**

- the pending wallet delete;
- the Stage 2 wallet-backed credential rung (CP-35), which reads a secret this form stores.

**Integration ACs:** AC7.

## Verification

Stateful checks run on slot B's throwaway `ocupilot-b-ci` (web 52777, super 1976). Nothing stateful runs on `ocupilot-slot-b`, and every IRIS MCP call carries `server: "ocupilot-slot-b"`. Run one test class per call, and wait until each run lands in `%UnitTest_Result` before sending the next.

### Targeted (loop)

- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/` -- expected: the bundle under test is the one just built.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/wallet-secret.browser-spec.mjs browser/security.browser-spec.mjs` -- expected: all pass.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class <C>`, one class per call -- expected: 0 failures each. Run it for:
  - `WalletPortRead`, `WalletSecretCreate`, `WalletSecretUpdate`, `WalletWire`;
  - `Prohibited`, `ProhibitedRoute`, `ToolWrite`;
  - `SurfaceCoverage`, `EndpointCoverage`, `ReadTool`, `ToolRoundTrip`, `PortFixture`;
  - `SecurityLists`, `WireSecurityRead`, `Wire`, `WireOAuthRead`, `Descriptor`, `DerivedFields`.
- `cd ui && npm run test:tools && npm run test:components` -- expected: 0 failures.
- `cd ui && node tools/field-lists.mjs --check && node tools/screen-mirror.mjs --check && node tools/client-lint.mjs && node tools/browser-reset.mjs` -- expected: no drift.
- `uv run scripts/check-objectscript.py <changed paths>` and `bash scripts/lint-docs.sh` -- expected: clean.

### Once, before `dev_complete`

- The full ObjectScript sweep on a throwaway brought up after the last edit, one class at a time, with the totals checked against `%UnitTest_Result` -- expected: 0 failures and a non-zero count.
- `cd ui && npm run build && npm test` -- expected: green, with the initial total recorded.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: all pass, with a non-zero count.
- The full browser suite is **not** run locally. CI's `browser` job runs it on a fresh throwaway (Rule 29; DW-1447).

### Pinning tests and mutations (Rule 19; the implementer records what was observed)

| AC | Pinning test | Mutation |
|---|---|---|
| AC1 | The page spec's masked and caption legs; the browser AC1 leg | Render Value as `type="text"`; pre-fill it from the store; drop the caption |
| AC2 | `WalletSecretCreate`'s value scan; `WalletWire`'s log scan | Add the stored value to `WalletPort`'s answer; put the value in a refusal status |
| AC3 | `DerivedFields` :175; `field-lists.mjs --check` | Remove `Usage` from `FieldLists`'s KeyValue list |
| AC4 | `WalletWire`'s deleted-target legs; `WalletSecretUpdate`'s screen absent leg | Skip the fresh `GET` in `WalletSave.Update`; answer 200 for an absent name in `WalletPort` |
| AC5 | `WalletWire`'s 403 legs; the browser deep-link leg | Drop `%Admin_Wallet` from `WalletSecretForm`'s privileges |
| AC6 | `WalletPortRead`'s shape legs | Drop the exact-case filter |
| AC7 | The store spec's publish leg; the browser list leg | Drop the store's `publish` |
| AC8 | The page spec's dirty-leave leg | Clear `FormDirty` on edit |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned only; nothing implemented. The ledger inbox was empty. Wire probes ran on `ocupilot-b-ci` and were cleaned up by exact name (the demo collection again holds only `OcuPilotDemo.Sample`). `ocupilot-slot-b` was read only.

For the lead's ruling at the spec gate (each is planned as recommended in Design Notes):

- SPINE DECISION NEEDED: AD-27's third case, the `Wallet.Secret` `GET` completed in `Port/WalletPort` (recommended), or an AD-4 amendment instead.
- SPINE DECISION NEEDED: correct AD-4 :129 and :133 and `epic-8-context.md` at their origin; `Wallet.Secret`'s PUT keeps omitted fields (measured).
- Product scope: key-value secrets only; the value stored as typed; FR-46's delete and row action unowned (candidate Story 9.5).
- Needs the lead: `ui/browser/security.browser-spec.mjs`, `Test/{WireSecurityRead,Wire,WireOAuthRead}.cls`, `screens.generated.ts` (Code Map).
