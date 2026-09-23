---
title: 'Story 8.5: X.509 import, edit and delete'
type: 'feature'
created: '2026-09-23'
status: 'done'
baseline_revision: 'bc1c5fdb92eafc31bab557b67f9596b8c0c83f3b'
baseline_commit: 'bc1c5fdb92eafc31bab557b67f9596b8c0c83f3b'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-8-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-8-4-the-resource-editor.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot cannot import, edit or delete an X.509 credential. The X.509 list declares no action and no tool writes `Security.X509Credential`. The vendor's import (`POST`) also accepts the certificate and key only as file paths on the server, and AD-21 forbids a caller from naming a path.

**Approach:**

- Ship a `security/x509/edit` form page. It creates from the list's Create, labeled Import, and edits from the name cell.
- It saves through `security.x509.import` (a create, AD-54) and `security.x509.update` (a merge, AD-4). The screen and the agent are two callers of one tool (AD-55).
- Ship `security.x509.delete` as an agent-only action-style write (AD-51).
- The import sends certificate and key *content*. `AdminPort` completes that POST through `%SYS.X509Credentials` in `%SYS`, so no path and no file is involved. That needs a spine decision (Design Notes).

## Boundaries & Constraints

### Always

- **Secrets.** `Certificate`, `PrivateKey` and `PrivateKeyPassword` are the X.509 list's `secretArguments`:
  - They travel only in the import request.
  - No OcuPilot read ever returns them.
  - They never appear in a stored proposal argument, a diff value, a ledger row, screen context, an envelope, a status or a log line (AD-3, AD-6, AD-35).
  - The masked fields are never pre-filled or echoed.
- **Import body.** The body the port receives is `{OwnerList, PeerNames}` plus those secrets, with `alias` as the query parameter. `CAFile`, `CertificateFile` and `PrivateKeyFile` are never advertised to any caller and never accepted from one (AD-21).
- **Edit body.** An edit body is exactly the vendor PUT contract `{OwnerList, CAFile, PeerNames}`: the fresh `GET` with the caller's changes applied (AD-4, AC4). `CAFile` always comes from the fresh read, and only `OwnerList` and `PeerNames` are settable.
- **Alias.** Aliases are case-sensitive: `OcuPilotProbe85A` and `ocupilotprobe85a` coexist on the instance. The id rule is therefore exact, and no `IDRULES` entry is added.
- **Wording.** Every field sentence is authored once in `Api/Error.cls`. Every visible word is a `STRINGS.<key>` with a Fixed strings row.

### Never

- Never edit `Kernel/Proposal/Confirm.cls`, `Kernel/Restraint.cls`, `Port/LogSourcePort.cls`, `Install/Smoke.cls`, `Screen/Tool/UserUpdate.cls` or `ui/src/app/areas/{tasks,logs}/**`.
- No row action. It is pending the lead (Design Notes).
- No key replacement on edit.
- No `CAFile` input.
- No private key type other than the vendor default, RSA.
- Never write a certificate or key to a file.
- No `%SYS.X509Credentials` mutation outside `AdminPort` (AD-2, AD-49).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Import, screen | `POST /api/ocupilot/x509` with `{Alias, Certificate, PrivateKey?, PrivateKeyPassword?, OwnerList, PeerNames}`, alias free | 201 `{alias}`. The port completes it through the class. An `x509-credential` `created` event follows, the route becomes `security/x509/edit/<alias>`, and the masked fields are emptied | No error expected |
| Edit, screen | `PUT /x509/<id>` with `{OwnerList:["a"]}` while the instance holds `PeerNames:["p"]` and `CAFile:"/x.cer"` | The port body is `{OwnerList:["a"], CAFile:"/x.cer", PeerNames:["p"]}`. Answers 200 with an `updated` event | Any key other than `OwnerList`/`PeerNames` answers 400, and nothing is sent |
| Agent import | `security.x509.import` `{Alias, OwnerList?, PeerNames?}` minted | A diff row per supplied field, plus masked rows for `Certificate` (required), `PrivateKey` and `PrivateKeyPassword` (`optional`). The absence fingerprint is taken. At confirm the card sends what the user filled | A secret among the model's arguments is refused at mint (existing) |
| Field rules | Alias empty, over 150 characters, holding a control character or `/`; Certificate missing, not one PEM `CERTIFICATE` block, over 64 KB, unparsable or expired; a key that is not a PEM private-key block, or one not matching the certificate; a wrong password; a password with no key; a password over 128 characters | One `X509.<FIELD>.<RULE>` row per failing field | Screen: 422. Agent: 400 `TOOL.ARGUMENTS` at mint for the alias rules. A certificate or key fault found at confirm fails at the port with its normalized reason, which contains no secret text |
| Alias taken | Exact-case alias present | `X509.ALIAS.TAKEN` on Save and on blur (`GET /x509/name`). If taken after the mint: 409 `PROPOSAL.TARGETCHANGED` | Nothing is written |
| Absent on edit | Form read, edit or update mint for an absent alias | 404 `X509.ALIAS.ABSENT`. Save is `aria-disabled` | Nothing is sent |
| Single-line PEM | A block whose line breaks were lost, as a password input or the card loses them | Re-wrapped at 64 columns and accepted | A newline-free key carrying `Proc-Type` is refused `X509.PRIVATEKEY.SHAPE` (screen), or refused 400 by the port (confirm) |
| Agent delete | `security.x509.delete` for an alias | Removal rows from `CERTINFO`, fingerprinted over `SerialNumber,IssuerDN`. Confirm sends a bodyless `DELETE`, then a marker and a `deleted` event | A certificate replaced under the same alias since the mint gives 409 `TARGETCHANGED` |
| Leave dirty | Any navigation away from a changed form, the agent's included | The shared leave question | Nothing is lost silently |

</intent-contract>

## Code Map

### Contention (Epic 7 head `212241da384852c31b5fa1ba777f0f03f07d26ff`)

Before editing a ⚠ file, run `git fetch origin && git show origin/OCU-1-epic7:<path>`. Keep off its hunks (Epic 7 line numbers are marked `e7`) and restructure nothing it added. Roster rule: a shared test or roster file takes this story's own rows only.

**Needs the lead** (these files are in Epic 7's diff but not on the contended list):

- `ui/src/app/core/screen-actions.ts`. Add `DESCRIPTOR_ACTION_LABELS['OcuPilot.Screen.Descriptor.X509CredentialList'] = {create: STRINGS.actionImport}`. Insert it at the head of the map (HEAD :79), away from Epic 7's tail append (e7 +86).
- `ui/src/app/core/screens.generated.ts`. Regenerate only.

### Server

- `src/OcuPilot/Screen/Tool/UserCreate.cls` is the POST-create template:
  - `CREATES` :29, `WRITETYPE "POST"` :37, `PERMITTEDFIELDS` :43;
  - `ComposedSecrets` :89, `ArgumentProblem` :111.
- `Screen/Tool/ResourceUpdate.cls` is the merge template. `Screen/Tool/ResourceDelete.cls` and `RoleDelete.cls` are the action-delete templates.
- `Screen/Tool/Write.cls` (no edit). `IdArgument` :331 defaults to `Name` and `IdParam` :338 to `name`; the X.509 tools override both to `Alias`/`alias`. `FieldRows` :384-433 drops a declared secret at :424, and its `[]` strip is :419-421. `DerivedFields` :216.
- `Kernel/Proposal/Mint.cls` (⚠ rule-contended; Epic 7 has no hunk in it):
  - the absence read :160-182;
  - `Compose` :504 and `Merge` :421;
  - `AppendComposedSecrets` :586, called at :190.
- ⚠ `Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :138 and the TYPE block :141-155 (e7 +149, +164);
  - the type gate :445 (e7 +391) and the dispatch :478-503 (e7 +435);
  - `PermittedChangeFields` :311, `PermittedCreateFields` :369;
  - `Created` :574, `ReviewedFewOnly` :1104.
- `Port/AdminPort.cls` (shared-append):
  - ⚠ `MUTATINGTYPES` :182 (e7 +173-191) and `BODYLESSTYPES` :198 (e7 +207). Both lines conflict with certainty.
  - `CLASSCOMPLETEDTYPES` :236 and `CompleteThroughClass` :984 (8.4's `Security.Resources` completion).
  - the `RunSequence` hook :1196;
  - `Fail`, `TYPESUFFIXES` :118 (`CERTINFO` present), `ImplementsRead` :1163 (POST and DELETE mapped).
- `Screen/Tool/Classification.cls`: the tail entry `permissions.resources.update` :238 (⚠ append-only; Epic 7 also appends). The 8.2 `authored` example is :197-220. `Screen/Tool/FieldLists.cls` :415-425 already derives `Security.X509Credential`. `ToolFields.cls` is regenerated with `cd ui && node tools/field-lists.mjs`.
- `Screen/Registry.cls` (no edit). `ConfirmChannelProblem(pDeclaration)` :1990 is public; its secret check is :2018-2025, and the `[]` strip is in `ToolFieldRows` :2426-2427.
- `Screen/Descriptor/X509CredentialList.cls`: `primaryAction` :48, `rowActions` :49, the `table` empty keys, `toolIdentifier` :84. `UserForm.cls` :18-46 is the form-page descriptor template.
- ⚠ `Api/Router.cls`: add routes after the resource routes :97-106, and handlers after `ResourceUpdate` :360. Epic 7 inserts at e7 :95 and e7 :253.
- `Api/Error.cls`: the RESOURCE block :1843-1898, `ReasonForViolation` :1048 (RESOURCE branches :1128-1136), `ResourceViolationCodes` :1168.
- Screen-route pattern:
  - `Area/Permissions/ResourceRules.cls`: `Validate` :57, `HandleForm` :174, `HandleName` :216, `Taken` :252, `Read` :293.
  - `Area/Permissions/ResourceSave.cls`: `Create` :114, `Update` :153 with `EDITFIELDS`, `Send` :227.
  - `Area/Permissions/UserCreate.cls` `Perform` :102-156. It puts the secret on the payload only after the verdict and clears it after `Invoke`.

### Client

- `ui/src/app/areas/permissions/user-create-form.page.ts` and `.store.ts`:
  - masked field :126-157 (`passwordInputType`, `ocu-reveal-toggle`, `aria-pressed`, page-local `revealed` :287);
  - secret held apart :110 and cleared :236/:374;
  - summary and focus :64-76/:509-515, sticky bar :241-258, leave dialog :261-271, route replacement :484-487.
- `ui/src/app/areas/permissions/resource-editor.store.ts`: `canSave()` needs the fresh read :204-208, `changedFields()` :514-519, and an unchanged edit writes nothing :429-436.
- `ui/src/app/areas/agent/definition-form.page.ts`: `idFromUrl()` :1104 (create and edit on one route; use `encodeEntityId`, not its `encodeURIComponent`), the textarea :396.
- `ui/src/app/core/navigation.ts`: `editorScreenFor` :177 and `createFormFor` :188. A form at `<list>/edit` that is `sideBarPosition` 0 and **not** in `CREATE_ONLY_FORMS` :201 is what the name cell and Create open. No edit here.
- `ui/src/app/areas/permissions/user-actions.ts` is the Create-handler template. `app.ts` has injections :227-243 and sign-out resets :511-515.
- ⚠ `shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :90-100: append after `ResourceList` (Epic 7 adds at e7 :89).
- ⚠ `core/proposal-view.ts`: `maskedRow` :303, `toCardView` :325, `payloadSecrets` :366 (e7 +60-66, +318). ⚠ `shell/proposal-card.ts`: secret inputs :190-209, `secretsFilled` :562 (e7 +33-41, +520-531). `core/turn.ts` holds the proposal types and is not in Epic 7's diff.
- ⚠ `core/strings.ts`: append before `} as const;` :1423 (Epic 7 appends at e7 +1317). Reuse:
  - `x509Column*` :644-656;
  - `formSecretStored` :244, `formSaved`, `formRequiredFieldsLegend`, `formLeaveWithoutSaving`;
  - `accountShowPassword`/`accountHidePassword` :1115/:1117;
  - `tableStatusYes` :322.
- ⚠ EXPERIENCE.md:
  - row :138 already specifies this surface (no edit);
  - `masked-secret-field` :441;
  - append after the Fixed strings row :407 (Epic 7 inserts after e7 :394).
- `ui/browser/users-create.browser-spec.mjs`: `irisSys` :81, `signedInAt` :114, `fill` :131, `saveButton` :138, `waitForSaved` :158, the exact-name cleanup pattern :91.

## Tasks & Acceptance

### Execution

#### Port and prohibited set

- `src/OcuPilot/Port/AdminPort.cls` (shared-append):
  - ⚠ `MUTATINGTYPES` gains `Security.X509Credential/POST,Security.X509Credential/PUT,Security.X509Credential/DELETE`.
  - ⚠ `BODYLESSTYPES` gains `Security.X509Credential/DELETE`.
  - Add `ClassMethod PemBlock(pText, pKind, Output pCanonical) As %Boolean`:
    - strip CR;
    - accept exactly one PEM block whose label is `CERTIFICATE` (kind `cert`), or `PRIVATE KEY`, `RSA PRIVATE KEY` or `ENCRYPTED PRIVATE KEY` (kind `key`), at most 65,536 characters;
    - re-wrap a newline-free body at 64 columns;
    - refuse a newline-free block carrying `Proc-Type`.
  - Add the `Security.X509Credential/POST` completion (SPINE DECISION, Design Notes), dispatched from the `RunSequence` hook beside 8.4's and run after the gate:
    1. Read the alias from the `alias` query.
    2. `Exists` answers 409, as the vendor does.
    3. Canonicalize with `PemBlock` (a refusal answers 400).
    4. Decode the certificate inside `Try`. Garbage raises `<ILLEGAL VALUE>` in `CertificateSet`, which answers 400.
    5. Set `Alias`, `Certificate`, `PrivateKey`, `PrivateKeyPassword`, `OwnerList` and `PeerNames` (lists joined with `,`) and `Save()`.
    6. Answer 201 with the vendor `GET`. A save status goes through `Fail`, the same as the vendor's 500.
    7. Clear every local holding key or password text before returning. No secret text enters a status, fault or log.
  - Do not add `VERIFIEDWRITES` or `VERIFIEDDELETES`. The probes show the vendor PUT and DELETE report failure honestly (Design Notes).
- ⚠ `src/OcuPilot/Kernel/Proposal/Prohibited.cls`, off Epic 7's hunks:
  - Add `TYPEX509 "x509-credential"` to `COVEREDTYPES`, the type gate and the dispatch, using `ReviewedFewOnly`.
  - `PermittedCreateFields` and `PermittedChangeFields` for the type are `OwnerList,PeerNames`.
  - No own-object predicate: OcuPilot creates and uses no X.509 credential (Design Notes).
- ⚠ `src/OcuPilot/Kernel/Proposal/Mint.cls` -- `AppendComposedSecrets` sets `optional: true` on a composed row that the tool's `OptionalSecrets()` names. That call is guarded like `ComposedSecrets`, and a class without the method marks nothing.

#### Tools

- `src/OcuPilot/Screen/Tool/X509Import.cls` -- new, on `UserCreate`:
  - `TOOLNAME "security.x509.import"`, `DESCRIPTORCLASS X509CredentialList`;
  - `CREATES 1`, `CHANGEACTION "created"`, `WRITETYPE "POST"`, `Endpoint() "Security.X509Credential"`;
  - `IdArgument "Alias"`, `IdParam "alias"`, `PERMITTEDFIELDS "OwnerList,PeerNames"`;
  - `ComposedSecrets` is `Certificate,PrivateKey,PrivateKeyPassword`, and `OptionalSecrets` is the last two;
  - `ArgumentProblem` runs `X509Rules.Validate` with the secret checks off.
- `src/OcuPilot/Screen/Tool/X509Update.cls` -- new, on `ResourceUpdate`: `TOOLNAME "security.x509.update"`, `READTYPE "GET"`, `WRITETYPE "PUT"`, `SENDSBODY 1`, `CHANGEACTION "updated"`, `PERMITTEDFIELDS "OwnerList,PeerNames"`, and the same id overrides. The default fingerprint covers every field.
- `src/OcuPilot/Screen/Tool/X509Delete.cls` -- new, on `ResourceDelete`:
  - `READTYPE "CERTINFO"`, `WRITETYPE "DELETE"`, `SENDSBODY 0`, `DESTRUCTIVE 1`, `CHANGEACTION "deleted"`;
  - `READANSWERS "SubjectDN,IssuerDN,SerialNumber,ValidityNotBefore,ValidityNotAfter,HasPrivateKey"`;
  - `FINGERPRINTSUBJECT "SerialNumber,IssuerDN"` and `PRECONDITIONFIELD "SerialNumber"`, which name the certificate the user reviewed;
  - `StateDiff` emits removal rows.
- ⚠ `Classification.cls` (tail append). Add `security.x509.import` and `security.x509.update` over `fieldList "Security.X509Credential"`:
  - `Alias`, `OwnerList[]`, `PeerNames[]`, `CAFile` and `CertificateFile` are `ordinary`;
  - `PrivateKeyPassword` and `PrivateKeyFile` are `secret`;
  - the import adds `authored {"Certificate":"secret","PrivateKey":"secret"}`.
  - Then regenerate `ToolFields.cls`.
- `Screen/Descriptor/X509CredentialList.cls`:
  - `primaryAction {"id":"create"}`;
  - `"secretArguments": ["Certificate","PrivateKey","PrivateKeyPassword"]`;
  - `emptyNextKey ""`, `emptyAgentKey "x509ListEmptyAgent"`;
  - update its doc.
- `Screen/Descriptor/X509Form.cls` -- new, on `UserForm`:
  - `route "security/x509/edit"`, `sideBarPosition 0`, `archetype "form-page"`, `entityType "x509-credential"`, `id single`;
  - the list's privileges;
  - `context.secretFields` holds the three secrets;
  - `classicPage "%CSP.UI.Portal.X509Credential"`, `toolIdentifier "security.x509form"`.

#### Screen routes

- `src/OcuPilot/Area/Security/X509Rules.cls` -- new:
  - `Validate(pAlias, pArgs, Output pViolations, pCheckAlias, pCheckTaken, pCheckSecrets)` holds the matrix rules. The secret checks use `AdminPort.PemBlock` (through the update tool's `PortClass`) and the vendor's own tests from `%OnValidateObject` (`X509GetField` validity; `RSAEncrypt`/`RSADecrypt` with the password), inside `Try`, with no secret in any sentence.
  - `HandleForm` (`GET /x509/form[?alias=]`) answers `{requiredFields, maxLengths, rules}`. With an alias it adds `credential:{Alias, OwnerList, PeerNames, CAFile, SubjectDN, IssuerDN, ValidityNotBefore, ValidityNotAfter, HasPrivateKey}` from `GET` plus `CERTINFO` through the update tool's port. A 404 answers `X509.ALIAS.ABSENT`. `SerialNumber` is not projected.
  - `HandleName` (`GET /x509/name?alias=`) answers `{taken}`, with an exact-case `GET`.
- `src/OcuPilot/Area/Security/X509Save.cls` -- new, on `ResourceSave`/`UserCreate`:
  - `HandleCreate` runs, in order: the gate, the prohibited verdict over the non-secret fields, `Validate` (all), `Compose`, then the secrets put on the body, then the port `POST`.
  - `HandleUpdate` runs, in order: the gate, the fresh `GET` (404 answers `ABSENT`), a check that the body holds only `OwnerList`/`PeerNames` (anything else is 400), `Validate`, `Mint.Merge`, the verdict, then the port `PUT`.
  - `PROHIBITED.*` answers 403.
- ⚠ `Api/Router.cls`: add `GET /x509/form`, `GET /x509/name`, `PUT /x509/:id` and `POST /x509`, with thin handlers.
- `Api/Error.cls` gets its own block:
  - `X509.VALIDATION` (422);
  - `X509.ALIAS.{REQUIRED,LENGTH,SHAPE,TAKEN,ABSENT}`;
  - `X509.CERTIFICATE.{REQUIRED,SHAPE,EXPIRED}`;
  - `X509.PRIVATEKEY.{SHAPE,MISMATCH}`;
  - `X509.PRIVATEKEYPASSWORD.{WRONG,WITHOUTKEY,LENGTH}`;
  - each with its sentence, plus `ReasonForViolation` branches and `X509ViolationCodes`.

#### Client

- `ui/src/app/areas/security/x509-actions.ts`, `x509-form.store.ts` and `x509-form.page.ts` -- new, ids prefixed `ocu-x509-`:
  - **Create mode**, in classic order:
    - Alias (required).
    - Certificate (required): a textarea plus a "Load from file" button reading a local file with `FileReader`.
    - Private key: the masked-field pattern of `user-create-form.page.ts`, plus "Load from file".
    - Private key password: masked, with the helper "Only for an encrypted key".
    - Authorized users and Intended peers: comma-separated, sent as arrays.
  - **Edit mode:**
    - read-only: Alias, Subject, Issuer, Valid from, Valid until, Private key present, CA file;
    - editable: Authorized users and Intended peers;
    - there are no secret fields, so no stored-caption promise applies.
  - The store holds secrets apart from the edit buffer. It sends them once and clears them on an accepted save, on reset and across the route replacement.
  - An edit sends `changedFields()` only after the fresh read. An unchanged edit writes nothing.
  - Save publishes `{kind:'changed', type:'x509-credential', scope:'instance', id, action}`. A create replaces the route with `security/x509/edit/<encodeEntityId(alias)>` and shows `formSaved`.
- `ui/src/app/core/turn.ts` -- a diff row gains `optional?: boolean`.
- ⚠ `proposal-view.ts` -- the view carries the optional masked fields.
- ⚠ `proposal-card.ts` -- `secretsFilled` skips an optional field, and its input's label adds `STRINGS.proposalSecretOptional`.
- ⚠ `screen-outlet.ts` gets the `X509Form` entry. `app.ts` injects `X509Actions` and resets the store at sign-out.
- ⚠ `strings.ts` and EXPERIENCE.md Fixed strings, **append only**:
  - `actionImport` "Import";
  - `x509FormLabel` "X.509 credential";
  - `x509ListEmptyAgent` "import a certificate";
  - `x509FieldAlias`, `x509FieldCertificate`, `x509FieldPrivateKey`, `x509FieldPrivateKeyPassword`, `x509FieldOwnerList` "Authorized users", `x509FieldPeerNames` "Intended peers", `x509FieldCaFile` "Trusted CA file", `x509FieldHasPrivateKey` "Private key present";
  - `x509LoadFromFile` "Load from file";
  - `x509PasswordHelp` "Only for an encrypted key.";
  - `x509ListHelp` "Comma-separated.";
  - `proposalSecretOptional` "optional".

#### Tests and rosters

- `src/OcuPilot/Test/X509Material.cls` -- new. It holds PEM `XData` generated once with openssl, with each command in the header:
  - a 100-year self-signed RSA certificate with its PKCS#8 key;
  - the same key AES-encrypted under a known password, and as legacy `Proc-Type`;
  - an unrelated key;
  - an expired certificate (`-not_before`/`-not_after`).
- `Test/X509Fixture.cls` (a port subclass that records bodies), and `X509Import.cls`, `X509Update.cls` and `X509Delete.cls` -- new, each under 500 lines. They cover every matrix row on both callers, one body from both callers, AC3's secret-absence scan, the optional rows and canonicalization.
- `Test/X509Wire.cls` -- new, armed on `OCUPILOT_ALLOW_PRINCIPALS`. Add it to `scripts/ci-throwaway.sh` :204 and the `ui/tools/ci.test.mjs` roster. It runs through the real port and covers:
  - import of a certificate alone, and with an encrypted key and its password;
  - an edit that keeps the other field;
  - an agent delete;
  - route envelopes;
  - AC3 over every read;
  - cleanup by exact alias.
- `Test/SecretSpelling.cls` -- new (DW-1456; Design Notes).
- `x509-form.store.spec.ts` and `x509-form.page.spec.ts` -- new. Add a ⚠ `proposal-card.spec.ts` leg for optional secrets.
- `ui/browser/x509-import.browser-spec.mjs` -- new, with a real certificate and key made in `before` by openssl on the host and removed in `after`.
- Rosters that redden (own rows only):
  - ⚠ `Test/{SurfaceCoverage :106-108, EndpointCoverage :136-139, ReadTool :94, ToolRoundTrip :30, Prohibited, ToolWrite, PortFixture :21, WireSecurityRead, Descriptor}.cls`;
  - `Test/SecurityLists.cls` :54;
  - `ui/tools/{navigation,screen-mirror}.test.mjs`, `app.routes.spec.ts`.

### Rulings (lead, 2026-09-23)

- The AD-27 second case is approved; the import's `Certificate`, `PrivateKey` and `PrivateKeyPassword` never touch disk (no temporary file, not even inside the port) and never reach the ledger or any log line (AD-35). Pin: a test that fails when the `%SYS.X509Credentials` completion is removed, and one that asserts no private-key bytes appear in the stored proposal record or in any log output the import path writes.
- Optional key and password rows are an explicit per-row declaration by the tool; pin a test that fails if a row the tool marks **required** can be left empty on the card.
- `ui/src/app/core/screen-actions.ts` is contended (Epic 7 +15): read `git show origin/OCU-1-epic7:ui/src/app/core/screen-actions.ts` immediately before editing, add the single "Import" label entry away from Epic 7's append, list it under `footprint_extensions:`.
- The X.509-list Delete row action moved to Story 9.5 as DW-1541 (delete is in this story's title only); this story ships `security.x509.delete`.

### Orchestrator rulings on the implement halt, 2026-09-23 (work these first)

- [x] [Lead] **Bundle budget, DW-1166 policy.** Set `ui/angular.json`'s initial `maximumWarning` to `1261kB` (5% above the measured 1,200,871 B; the parser counts 1 kB as 1,000 B) and the literal pinned in `ui/tools/angular-json.test.mjs` to the same, replacing that file's budget-history sentence with the current figure and reason. `maximumError` stays `1600kB`. If the final measured total exceeds 1,261,000 B, re-base to about 5% above it and say so. The commit message cites DW-1166 and the byte count.
- [x] [Lead] **`ui/src/app/shell/screen-outlet.ts`** is contended append-only: this story adds one `DESCRIPTOR_PAGES` entry and its import; do not touch the `form-page` doc comment. List it under `footprint_extensions:`.
- [x] [Lead] **No private-key literal in the repository** (the repository is public; push protection is off). `Test/X509Material.cls` generates a throwaway RSA key and a self-signed certificate once per class in `OnBeforeAllTests` through `$ZF(-100)` with `openssl` (the image carries `/usr/bin/openssl`, OpenSSL 3.0.13) into a per-run directory under the instance's temp directory, reads them as text, and deletes the directory in `OnAfterAllTests`, asserting it is gone. The expired-certificate and key-mismatch cases generate their own material the same way (for example `-days 0`, or a second key). A certificate with no private key may stay a literal. If `$ZF(-100)` is refused in the test process, HALT `blocked` with `TOOLING: $ZF(-100) openssl refused` -- never fall back to a literal, never obfuscate one. Before the finalize commit, `git diff --cached | grep -c 'BEGIN.*PRIVATE KEY'` must print 0 (the pre-existing `Install/Fixture.cls` demo literal is DW-1544, not this story's).

### Acceptance Criteria

- **AC1.** Given the import form, when it renders, then it takes Alias, Certificate, an **optional** Private key in a masked field (password input with a labeled show/hide toggle, never pre-filled or echoed), Private key password, Authorized users and Intended peers, in that order, and no file path.
- **AC2 (Integration).** Given a credential imported by either caller, when the X.509 list (the change bus's consumer) refreshes without a manual refresh, then its row shows subject, issuer and validity.
- **AC3.** Given a private key or its password was imported, when any read is made afterwards, then neither appears in any OcuPilot read (form read, list read and its tool), stored proposal argument, diff value, ledger row, screen context, envelope or log line. This holds even for a refused import. The masked fields are empty after the save.
- **AC4.** Given an edit saved through either caller, then the body is the PUT contract `{OwnerList, CAFile, PeerNames}` from a fresh read with the edits applied. A field not changed keeps the instance's value, and `CAFile` is never caller-set. The certificate, key and password travel only in the import request.
- **AC5.** Given the agent's import, update or delete confirmed, then the write is marked, the ledger names only non-secret fields, and a `created`, `updated` or `deleted` event is published. The import card requires Certificate and leaves Private key and password optional.
- **AC6.** Given the form holds a change, when any navigation leaves, the agent's included, then the shared leave question asks first.
- **AC7 (DW-1456).** Given a name the registry's confirm-channel validator admits as a settable secret, when a tool's descriptor declares it, then `Write.FieldRows` no longer advertises it. A spelling the consumer never produces (`OwnerList[]`) is refused by the validator.

## Spec Change Log

- 2026-09-23, lead (orchestrator rulings on the bundle-budget halt): budget re-based to 1261kB under DW-1166; `screen-outlet.ts` contended append-only; no private-key literal -- tests generate key material with openssl at run time. Status reset to `in-progress` with the implementation still uncommitted.

- 2026-09-23, spec gate (orchestrator rulings): AD-27's second case approved and written (verified first on the throwaway); the X.509-list row action moved to Story 9.5 (DW-1541); `screen-actions.ts` contended for one entry; optional secret rows agreed as an explicit declaration.

## Review Triage Log

### 2026-09-23 — Review pass

- verdicts: 17 findings — high 0, medium 3, low 10, false 4, maybe-false 0 (plus 1 found by the stage while verifying the patches)
- findings:
  - `[medium]` `[patch]` VG: `App`'s sign-out wipe of `X509Form` had no test -- added the store to `app.spec.ts`'s sign-out test (prime key, certificate, password; assert empty); mutation observed red.
  - `[medium]` `[patch]` VG: `X509Wire.TestZNothingReachedTheMessageLog` passed on an empty or misplaced log read -- it now requires the refused agent import's `X509.PRIVATEKEY.MISMATCH` line before scanning, and scans every generated secret; mutation observed red (run 288).
  - `[low]` `[patch]` VG: AC4's `CAFile` mutation was planned but not observed -- applied, red (run 289), `mutation:` line written.
  - `[false]` `[reject]` VG: the browser AC2 leg's no-load check does not observe the change bus -- its title and the spec header say it is reached by Cancel and that the event is pinned in `x509-form.store.spec.ts`; it claims no more.
  - `[low]` `[patch]` VG: `X509Wire` read assertions guarded by `If $IsObject(...)` could skip silently -- each now asserts the body is an object first.
  - `[false]` `[reject]` VG: `SecretSpelling`'s always-dropped candidates -- the reviewer's own note: not a defect; the drop is exercised by the four candidates the observed mutation covers.
  - `[low]` `[reject]` VG: the spec's `## Auto Run Result` was stale -- its fix is a spec edit; rewritten at this pass's finalize.
  - `[medium]` `[patch]` IA: no test confirmed an agent import the port refuses -- added `X509Wire.TestARefusedAgentImportSavesNothingAndAnswersNoSecret` (mismatched key through the real `Confirm`: 400, nothing saved, no secret in the answer or stored proposal); green runs 285 and later.
  - `[low]` `[reject]` IA: the certificate is required only on the card; a confirm without one is refused as `X509.CERTIFICATE.SHAPE` -- nothing is written, and requiring it server-side edits the never-edit `Confirm.cls`.
  - `[low]` `[reject]` IA: the update mint answers an absent alias 400 `TOOL.ARGUMENTS`, not 404 `X509.ALIAS.ABSENT` -- the kernel's shared contract for every update tool (same ruling as 8.4); nothing is sent.
  - `[low]` `[patch]` IA: the second import's 422 was not checked for its code -- `X509Wire` now asserts `X509.ALIAS.TAKEN`.
  - `[low]` `[reject]` IA: the screen refuses a file path as 403 `UNCOVEREDFIELD`, and `CAFile`/`PrivateKeyFile` are tested there only through `CertificateFile` -- one code path refuses all three; the port and the schema are tested for each.
  - `[false]` `[reject]` IA: tests write generated keys to a temp directory and clean up through `%SYS.X509Credentials` -- test material under the 2026-09-23 ruling and probe cleanup by exact alias; the shipped path writes no file, and `X509Save.Create`'s composed diff is a local never stored or logged.
  - `[low]` `[reject]` IA: no key-type check for a non-RSA key -- the vendor's save refuses a key it cannot use as a mismatch, and no key-type choice is offered (the Never item).
  - `[low]` `[reject]` IA: no X.509-specific test opens the edit form from a list row -- the name cell follows the generic `editorScreenFor` convention tested in `navigation.test.mjs`.
  - `[low]` `[reject]` IA: no test drives an agent-initiated leave -- the shared `FormDirty` route guard (Story 3.5) owns that path; the page answers it and its spec pins the answer.
  - `[false]` `[reject]` IA: the diff reaches beyond the Approach (`optional` rows, `COVEREDTYPES`) -- the matrix and the 2026-09-23 rulings require both.
  - `[medium]` `[patch]` stage (run 284 red, run 285 green): `X509Rules.KeyMatches` read about one wrong password in two hundred as a key mismatch, because the wrong password decrypted the key to bytes that do not decode (measured 8 of 1500) -- an encrypted key is now a mismatch only on the OAEP decrypt error; 1500 of 1500 read as wrong after the fix; pinned by `X509Import.TestAWrongPasswordThatDecodesToNoKeyIsStillThePassword` (mutation run 287).

## Design Notes

**Governing ADs:** AD-2, AD-3, AD-4, AD-5, AD-6, AD-8, AD-10, AD-13, AD-14, AD-15, AD-16, AD-21, AD-24, AD-27, AD-34, AD-35, AD-39, AD-49, AD-51, AD-52, AD-54, AD-55. AD-53 (on Epic 7's branch only) governs the pending row action.

### What the instance settled

The vendor source was read on `ocupilot-slot-b`. The probes ran over HTTP on `ocupilot-b-ci`, and cleanup was confirmed by exact alias. After cleanup the list holds only `OcuPilotDemoCert`, and `/tmp/p85` was removed.

- **Endpoint.** `%Api.Admin.Endpoints.Security.X509Credential` has `ResourcesOR` `%Admin_Secure`. Its `GET`, `CERTINFO`, `PUT` and `DELETE` take `alias`, while `POST` carries `Alias` in the body.
- **POST (the import).**
  - It takes only `CertificateFile` and `PrivateKeyFile` server paths, read by `LoadCertificate`/`LoadPrivateKey`. `PrivateKeyPassword` is set only with a key file.
  - `CertificateFile` and `Alias` are required.
  - It is not an upsert: a taken alias answers 409 (#5805).
  - Failures answer 500: expired #728, wrong password #732, mismatched key #733.
  - A second alias differing only in case answered 201.
- **PUT.** It opens by id, so an absent alias answers 404 and PUT is not an upsert.
  - It sets only the keys sent: an `OwnerList`-only body kept `PeerNames` (AC4's "does not merge" is wider than the instance; the outcome holds regardless).
  - Unknown keys answer 400 (#40307).
  - A missing `CAFile` answered 500 (#5012), and the re-read showed the save unapplied, so no `VERIFIEDWRITES` is needed.
- **DELETE.** It answers 200 and the credential is then gone (a GET answers 404). An absent alias answers 404.
- **Reads.**
  - `GET` answers `{OwnerList, CAFile, PeerNames}`.
  - `CERTINFO` adds `HasPrivateKey`, `SerialNumber`, `IssuerDN`, `SubjectDN` and the validity dates.
  - `LIST` adds `HasPrivateKey`.
  - No read returns the certificate, the key or the password.
- **`%SYS.X509Credentials`.**
  - `Alias` is `MAXLEN` 150 and case-sensitive; `,` and `/` are accepted.
  - `CAFile` is a path resolved under the manager directory.
  - Setting `Certificate` from decoded PEM and `PrivateKey` from PEM text saves.
  - A key with its line breaks stripped fails as a mismatch (#733), which is why `PemBlock` re-wraps.
  - Non-certificate bytes raise `<ILLEGAL VALUE>`.
  - A legacy-encrypted key saves without its password (vendor behavior, kept).
  - `%OnBeforeSave` writes the vendor's own `X509CredentialsChange` audit row, with the key and certificate redacted (AD-15's paired record).
- **OcuPilot's own use.** No installer step creates or uses an X.509 credential. `OcuPilotDemoCert` is opt-in fixture data (AD-25), so no AD-10 refusal applies to this type.

### Ruled: the import's content path (AD-27's second case)

The vendor POST can carry certificate and key only as server file paths. AD-21 forbids a caller from naming one.

**Ruled 2026-09-23 (orchestrator), written into AD-27:** a second named AD-27 case. The lead verified it first on `ocupilot-b-ci`: a certificate and key set as content through `%SYS.X509Credentials` saved, the admin API's list read it back with `HasPrivateKey` true and no key bytes, and its `DELETE` removed it. `Security.X509Credential` `POST` is completed through `%SYS.X509Credentials` in `%SYS`:

- under the same `%Admin_Secure` gate;
- from the content fields `Certificate`, `PrivateKey` and `PrivateKeyPassword`;
- which the import tool authors as secret (an AD-3 reading: an authored secret may belong to a body the port completes, not only to a vendor wrapper).

Nothing above the port knows. **Rejected:** staging the content in a port-owned temporary file for the vendor POST. It writes key material to disk, where a crash can leave it (AD-35).

Wording for AD-27's last bullet: "The second case: `Security.X509Credential` `POST`, whose template names only server file paths for the certificate and key (AD-21); the port completes the import from content through `%SYS.X509Credentials`."

### Ruled: optional secrets on the card

The card requires every masked field filled (`secretsFilled`), so an agent import could not leave out the key.

**Ruled (lead, orchestrator agreed):** composed secret rows marked `optional` by the tool as an explicit declaration, never a relaxed check (`Mint`, `turn.ts`, `proposal-view.ts`, `proposal-card.ts`, all small and off Epic 7's hunks).

**Alternative, a narrowing:** the agent import takes the certificate only, and a key is imported from the screen.

### Moved to Story 9.5 (DW-1541): the X.509-list row action

This story ships `security.x509.delete` as the agent's confirmed tool, and no row action. Edit needs none, because the name cell opens `security/x509/edit/<alias>` once `X509Form` exists (`editorScreenFor`).

A Delete row action needs these (the candidate is Story 9.5, the SSL/TLS editor, the nearest Security-and-secrets story; the orchestrator decides):

- Epic 7's AD-53 route `POST /screens/:screen/action`;
- `rowActions [{"id":"delete","selfProtection":""}]`;
- `SCREENACTIONS "delete"` on `X509Delete`;
- a `screen-action-handler.ts` entry with an `x509DeleteConsequence` sentence;
- its Fixed strings row (DW-1502 applies).

### DW-1456 (ledger inbox): addressed

Its premise is off by one story: `UserList.secretArguments` has held `["Password"]` since 8.2. Neither that nor this story's secrets reach `FieldRows`' drop at :424, because a `secret` row is skipped at :415. The binding therefore needs a declared-ordinary name.

`Test/SecretSpelling.cls` takes the X.509 declaration with `secretArguments` replaced by each candidate spelling of the `security.x509.update` entry (`OwnerList`, `OwnerList[]`, `PeerNames`, `CAFile`, …). It asserts two things:

- `Registry.ConfirmChannelProblem` accepts a name exactly when a test subclass of `X509Update`, answering that name from `SecretArguments`, drops it from `FieldRows`/`InputSchema`;
- `OwnerList[]` is refused.

### Consumes and consumed-by

**Consumes:**

- 8.1's create kind;
- 8.2's authored secret, masked field and composed secret rows;
- 8.4's AD-27 completion hook, form-read pattern and merge route;
- Epic 5's merge and action writes;
- Story 3.5's `FormDirty`.

**Consumed-by:**

- Story 8.6, the wallet secret form (the masked field and optional composed secrets);
- Story 9.5 (the pending row action; DW-268's `CAFile` guard).

**Integration ACs:** AC2 (the list re-reads on the change bus) and AC5 (the card renders optional secrets).

## Verification

Stateful checks run on slot B's throwaway `ocupilot-b-ci` (web 52777, super 1976). When a fresh one is needed: `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976`.

- Nothing stateful runs on `ocupilot-slot-b`.
- Every IRIS MCP call carries `server: "ocupilot-slot-b"`.
- Run one test class per call, and wait for each run to land before sending the next.

### Targeted (loop)

- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/` -- expected: the bundle under test is the one just built.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/x509-import.browser-spec.mjs browser/users-create.browser-spec.mjs` -- expected: all pass.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class <C>`, one class per call -- expected: 0 failures each. Run it for:
  - `X509Import`, `X509Update`, `X509Delete`, `X509Wire`, `SecretSpelling`;
  - `UserCreate`, `Prohibited`, `ProhibitedRoute`, `ToolWrite`;
  - `SurfaceCoverage`, `EndpointCoverage`, `ReadTool`, `ToolRoundTrip`, `PortFixture`;
  - `SecurityLists`, `WireSecurityRead`, `Descriptor`, `DerivedFields`.
- `cd ui && npm run test:tools && npm run test:components` -- expected: 0 failures.
- `cd ui && node tools/field-lists.mjs --check && node tools/screen-mirror.mjs --check && node tools/client-lint.mjs && node tools/browser-reset.mjs` -- expected: no drift.
- `uv run scripts/check-objectscript.py <changed paths>` and `bash scripts/lint-docs.sh` -- expected: clean.

### Once, before `dev_complete`

- The full ObjectScript sweep on a throwaway brought up after the last edit, one class at a time, with totals checked against `%UnitTest_Result` -- expected: 0 failures and a non-zero count.
- `cd ui && npm run build && npm test` -- expected: green.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` -- expected: all pass, with a non-zero count.
- The full browser suite is **not** run locally. CI's `browser` job runs it on a fresh throwaway (Rule 29; DW-1447).

### Pinning tests and mutations (Rule 19; the implementer records what was observed)

| AC | Pinning test | Mutation |
|---|---|---|
| AC1 | `x509-form.page.spec.ts` order and masked-field legs; the browser import leg | Swap Private key and Certificate; render the key input as `type="text"`; pre-fill it from the store |
| AC2 | `X509Wire` import leg (`CERTINFO` fields on the list read); the browser row-without-refresh leg | Drop the store's publish; drop `rowGet` from the list |
| AC3 | `X509Import` secret-absence scan (stored args, diff, ledger fields, envelopes); `X509Wire` read scan and wrong-password leg | Add the stored `PrivateKey` to the form read's `credential`; put the key text in the port's refusal |
| AC4 | `X509Update` merge test on both callers (body keys and a kept `PeerNames`) | `X509Save.Update` sends the caller's fields without `Mint.Merge`; admit `CAFile` in the edit |
| AC5 | `X509Delete` removal-row and serial-moved tests; `X509Import` optional-row test; the card spec's optional leg | `FINGERPRINTSUBJECT "IssuerDN"`; `OptionalSecrets` empty; `secretsFilled` requires every field |
| AC6 | `x509-form.page.spec.ts` dirty-leave leg | Clear `FormDirty` on edit |
| AC7 | `SecretSpelling` | `Write.cls` :424 matches the raw path (`$ListFind(tSecrets, tPath)`) |
| Canonical PEM | `X509Import` single-line leg | `PemBlock` stops re-wrapping |

Observed (implement stage; each applied to the working file, loaded with `cbk-d` or rerun under `node --test`/`ng test`, observed red, restored from a byte copy and reloaded):

- mutation: `AdminPort.CONTENTCOMPLETEDTYPES` emptied -> `X509Wire` import, read-scan and agent-import legs red (run 254) and `X509Import.TestTheSchemaAdvertisesNoSecretAndNoPath` red (run 255), over run-time material (AD-27 pin; the vendor POST refuses the content keys at 400, so the unit port legs stay green)
- mutation: `Mint.Mint`'s refusal of a secret argument disabled -> `X509Import.TestNoSecretReachesTheProposalTheLedgerOrAnAnswer` red on the refusal and the stored-row scan (run 257), over run-time material (AC3 pin, stored proposal)
- mutation: the key text appended to the status `ImportThroughClass` returns for a refused save -> `X509Import.TestARefusedImportLogsNoSecret` red, cases 1-3 (run 256), over run-time material (AC3 pin, log output)
- mutation: `X509Import.OPTIONALSECRETS` empty -> `TestTheCardRequiresTheCertificateAndLeavesTheKeyOptional` red on both optional rows (run 243); Certificate added to it -> red on the required row (run 244); `proposal-card.ts` `secretsFilled` requiring every field -> the card spec's Story 8.5 leg red; answering true -> that leg and AC4/DW-1232 red; `optionalSecrets` in `proposal-view.ts` marking every row -> `proposal-view.test.mjs` optional leg red (required-row pin)
- mutation: `AdminPort.IMPORTFIELDS` admitting `CAFile` -> `X509Import.TestAFilePathIsRefusedByEveryCaller` red, the credential saved (run 240; the leaked probe was deleted by exact alias and the class now removes it in `OnAfterOneTest`)
- mutation: `X509Save.Update` composing instead of `Mint.Merge` -> `X509Update.TestAnEditKeepsTheFieldsTheCallerDidNotChangeOnBothCallers` red (run 246) (AC4)
- mutation: `X509Delete` subject and precondition `IssuerDN` alone -> `TestTheRemovalRowsAndAReplacedCertificateRefusesTheConfirm` red on the moved serial (run 247) (AC5)
- mutation: `Write.FieldRows` testing the raw path (`$ListFind(tSecrets, tPath)`) -> `SecretSpelling.TestTheValidatorAdmitsExactlyTheSpellingsTheFieldRowsDrop` red on `OwnerList`, `OwnerList[]`, `PeerNames`, `PeerNames[]` (run 245) (AC7)
- mutation: `X509Material.Discard` skips the directory's removal -> `X509Import` red on its class-level `OnAfterAllTests` error (run 252; the leftover directory removed by hand) (no-key-literal ruling)
- mutation: `AdminPort.PemBlock` keeps a newline-free body on one line -> `X509Import.TestAFlattenedBlockIsRewrappedAndAFlattenedLegacyKeyRefused` red on the canonical block, the 64-column wrap and the key check (run 261) (canonical PEM)
- mutation: the stored `PrivateKey` added to `X509Rules.HandleForm`'s `credential` -> `X509Wire.TestNoReadCarriesTheKeyOrItsPassword` red on the form read's field and on the read scan (run 260) (AC3)
- mutation: `rowGet` dropped from the X.509 list's declared read -> `X509Wire.TestAnImportShowsOnTheListAndAnEditKeepsTheOtherList` red on subject, issuer and validity (run 263); over the clean redeployed bundle the browser AC2 leg red alone (AC2)
- mutation (component specs, `ng test --include`): Private key block before Certificate -> `x509-form.page.spec.ts` AC1 order red; key input `type="text"` -> AC1 masked red; `clearSecrets` keeping the key -> the page's AC1 pre-fill leg and three store legs red; the store's `publish` dropped -> store AC2 and AC4 red; `change` clearing `FormDirty` -> page AC6 and store AC2 red (AC1, AC2, AC3, AC6)
- mutation (one rebuilt, redeployed bundle): the order swap, the route replacement dropped and `change` clearing `FormDirty` -> browser AC1, AC3 and AC6 red, AC2 green; the restored bundle 4 of 4 green
- roster: `app.routes.spec.ts` and `screen-mirror.test.mjs` read green with this story's rows and needed no edit (not observed red)
- mutation: `X509Save.EDITFIELDS` admitting `CAFile` -> `X509Update.TestAnyOtherKeyIsRefusedOnBothCallers` red on `CAFile`, refused and sent (run 289) (AC4)
- mutation: the key text appended to the status `ImportThroughClass` returns for a refused save -> `X509Wire.TestZNothingReachedTheMessageLog` red on the real message log, its run-marker floor holding (run 288) (AC3, log output)
- mutation: `X509Rules.KeyMatches` without its encrypted-key line -> `X509Import.TestAWrongPasswordThatDecodesToNoKeyIsStillThePassword` red (run 287) (wrong-password classification)
- mutation (`ng test --include=src/app/app.spec.ts`): `this.x509Form.reset()` deleted from `App.verifyWhenSignedIn` -> the sign-out test red on the pasted certificate (AC3, AD-35)

## Auto Run Result

Status: done
Blocking condition: none

footprint_extensions: contended `src/OcuPilot/Kernel/Proposal/Prohibited.cls`, `src/OcuPilot/Kernel/Proposal/Mint.cls`, `src/OcuPilot/Api/Router.cls`, `src/OcuPilot/Screen/Tool/Classification.cls` (tail append), `src/OcuPilot/Screen/Tool/ToolFields.cls` (regenerated), `src/OcuPilot/Test/{SurfaceCoverage,EndpointCoverage,ReadTool,ToolRoundTrip,PortFixture,Prohibited}.cls`, `ui/src/app/core/proposal-view.ts`, `ui/src/app/shell/proposal-card.ts`, `ui/src/app/shell/proposal-card.spec.ts`, `ui/src/app/core/screen-actions.ts` (one head entry), `ui/src/app/shell/screen-outlet.ts` (one entry, one import); shared-append `src/OcuPilot/Port/AdminPort.cls` (plus the `RunSequence` hook line), `ui/src/app/core/strings.ts`, `ui/src/styles/_components.scss`, EXPERIENCE.md Fixed strings rows 408-412; in Epic 7's diff but not contended (roster rule, 2026-09-23): `src/OcuPilot/Test/WireSecurityRead.cls` (five rows), `src/OcuPilot/Test/Wire.cls` and `src/OcuPilot/Test/WireOAuthRead.cls` (one X.509 form row in each security roster; the same assertion lines Epic 7 extends, so a merge conflict there is certain), `ui/tools/navigation.test.mjs` (one route), `ui/src/app/core/screens.generated.ts` (regenerated), `ui/src/app/app.ts` (one injection pair, one reset); outside both footprints: `ui/angular.json` and `ui/tools/angular-json.test.mjs` (DW-1166 budget), `ui/src/app/app.spec.ts` (sign-out leg), `scripts/ci-throwaway.sh` (arming roster)

### This pass

- **Lead rulings, all three checked off.** The budget is `1261kB`, and the measured initial total is 1,200,871 B (`main` 1,071,922 plus `styles` 128,949), so no re-base was needed. `screen-outlet.ts` holds one entry and one import. `Test/X509Material.cls` now generates its key and certificate material at run time through `$ZF(-100)` and `/usr/bin/openssl` into a per-run temp directory. `Discard` deletes that directory and asserts it is gone. `$ZF(-100)` was not refused. `X509Import` and `X509Wire` generate the material in `OnBeforeAllTests`.
- **Client work finished.** Added `x509-form.store.spec.ts`, `x509-form.page.spec.ts` and `ui/browser/x509-import.browser-spec.mjs`, with the AC1, AC2, AC3 and AC6 client mutations, the canonical-PEM mutation and the form-read `PrivateKey` mutation. Each is listed under Observed.
- **Review.** Two layers ran: verification-gap and intent-alignment. Blind-hunter and edge-case-hunter are disabled by this project's customization. They reported 17 findings, and one more came up while verifying the patches (Review Triage Log). Patched:
  - `app.spec.ts` sign-out test now covers `X509Form`.
  - `X509Wire`: a log scan floor, a refused agent import through the real `Confirm`, object-first read assertions and the taken code.
  - The AC4 `CAFile` mutation was run and recorded.
  - `X509Rules.KeyMatches`: an encrypted key is now a mismatch only on the OAEP decrypt error. About one wrong password in 190 was read as a mismatch (8 of 1500 measured; 1500 of 1500 correct after the fix), which made `X509Wire` red once (run 284). A new test pins the fix.
  - Rejected: 9 lows and 4 falses, each with its reason in the log. Nothing deferred.
- **Found by the sweep.** `Test/Wire.cls` and `Test/WireOAuthRead.cls` list the security area's screens, and they now carry the X.509 form's row (roster rule).
- **Patched counts by verdict:** medium 4, low 3, high 0. `followup_review_recommended: true`. The unverified risk is the `KeyMatches` change: it reads every failure of an encrypted key other than the OAEP decrypt error as a wrong password. That was verified only for RSA keys, in PKCS#8 and legacy form, on this build's OpenSSL 3.0.

### Verification (after the last edit, on a throwaway brought up fresh)

- Full ObjectScript sweep, one class per call: 196 classes, 1753 tests, 0 failed. The totals were checked against `%UnitTest_Result` (1753 passed, 0 failed, 196 classes). An earlier full sweep failed only on the `Wire` and `WireOAuthRead` rosters, which were then fixed.
- `cd ui && npm run build` succeeded, with the initial total at 1,200,871 B. `npm test`: 1326 of 1326 tools tests and 890 of 890 component tests passed.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`: 47 executed, 47 passed.
- `uv run scripts/check-objectscript.py` over the changed paths: 0 problems. `bash scripts/lint-docs.sh`: clean. No non-ASCII in added source lines.
- **Private key check.** The staged diff holds no PEM private-key block: a grep for a real key header (five dashes, the begin marker, an optional label, the words private key, five dashes) counts 0. The ruling's own looser pattern counts 2, and both hits are the `-`/`+` pair of the checked-off ruling line above, which quotes that pattern. Neither is key material.
