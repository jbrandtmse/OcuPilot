---
title: 'Story 18.24: RSA and symmetric-key wallet secrets'
type: 'feature'
created: '2026-10-06'
status: 'done'
baseline_revision: '95476bdc23c5a522cf014e22a504ea66121776c7'
baseline_commit: '95476bdc23c5a522cf014e22a504ea66121776c7'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Story 8.6 creates and edits key-value wallet secrets only; an RSA or symmetric-key secret opens read-only with "Manage RSA and symmetric-key secrets through the %Wallet classes", and the classic portal has no wallet page (DW-1555).

**Approach:** Extend 8.6's Secret form, `WalletPort` and Save routes with a type choice: create an RSA key (generate by length, or import PEM material) or a symmetric key (generate by length, or import base64), and replace an existing key's material. Four tools on `WalletPort`, the two create keys `true` and the two destructive replace keys `false`; key material, public halves included, is write-only and returned by no read (the AC).

## Boundaries & Constraints

**Always:**

- Key material (`Certificate`, `PublicKey`, `PrivateKey`, `Password`, `Secret64`) is a declared secret end to end: never in a read, the list, the form read, a proposal's stored arguments, the ledger, a log line, screen context, a tool result, `Snippet` output (placeholders) or the DOM after save (AD-35, AD-56, Conventions › Secrets). Reads answer metadata only: RSA `{Type, Length, HasPrivateKey, HasCertificate}`, symmetric `{Type, Length, KeyId}`.
- Lengths are a closed set: RSA 2048, 3072, 4096 bits; symmetric 16, 24, 32 bytes, generated or imported.
- Every refusal the rules can pre-empt is refused on its field before any `PUT` (the vendor answers each with a 500 that `AdminPort` logs at severity 2; measured below).
- The agent's tools generate only (`Length` required at the mint); imports are the person's, on the form (Decision 2). `security.secrets.replacesymmetric` is unadvertised (AD-53).
- Every Save takes `Operation.HoldTool(<tool>, <name>)` before its fresh read (AD-34, DW-1882's coverage test). Replace is the destructive treatment: the agent's proposal is minted destructive with its consequence; a person's Save asks `app-typed-name-dialog` (the secret's full name) first and is not governed.
- New error codes live in a new sibling `Api/WalletKeyError.cls` (prefix `WALLETKEY.`); `Api/Error.cls` gains only dispatch lines (ERROR #5290 limit).
- Shared files take add-only edits: `Prohibited.cls`, `AdminPort.cls`, `Router.cls`, `Baseline.cls`, `Classification.cls`, `Error.cls`, `strings.ts`, `proposal-view.ts`, EXPERIENCE.md, the rosters.

**Never:**

- A server path for key material: `CertificateFile`, `PublicKeyFile`, `PrivateKeyFile` are refused by `AdminPort` (the vendor reads the named server file; measured).
- `Length` sent beside `Secret64` on a symmetric create (the vendor then stores a random key in place of the imported one; measured), or `Length` alone to an existing symmetric secret except as the port's own follow-up (it changes only the stored length; measured).
- A settable `KeyId`, `Usage`, `RequireTLS` or `AllowedHosts` on an RSA or symmetric secret (the vendor refuses `Usage` 400; `KeyId` is the vendor's GUID).
- OcuPilot generating key material, or a key held by the model.
- A type change on an existing name (the vendor refuses it; OcuPilot refuses first).
- Test keys in the repository: tests make material at run time (`Test/X509Material`, `$System.Encryption.GenCryptRand`) and remove what they store.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| RSA generate | free name, `Length` 2048/3072/4096, either caller | one `PUT {Type:%Wallet.RSA, Length}`, 201; read `HasPrivateKey` true, `HasCertificate` false | taken since mint: refused target-changed, zero `PUT` |
| Symmetric generate | free name, `Length` 16/24/32 | one `PUT {Type, Length}`, 201; read `Length` n, `KeyId` a GUID | as above |
| RSA import | form: `Certificate` and/or `PublicKey`, optional `PrivateKey` (PKCS#1, PKCS#8, encrypted), `Password` | one `PUT` of canonical PEM (`AdminPort.PemBlock`, line breaks restored); metadata from the vendor | no certificate or public key `WALLETKEY.PUBLIC.REQUIRED`; bad block `*.SHAPE`; expired or not-yet-valid `WALLETKEY.CERTIFICATE.INVALID`; encrypted with no password `WALLETKEY.PASSWORD.REQUIRED`; wrong password `WALLETKEY.PASSWORD.WRONG`; other key or not RSA `WALLETKEY.PRIVATEKEY.MISMATCH`; zero `PUT` |
| Symmetric import | form: `Secret64` decoding to 16/24/32 bytes | `PUT {Type, Secret64}` then `PUT {Type, Length}` (port-computed); stored key equals the imported one | other length or not base64 `WALLETKEY.SECRET64.SHAPE`, zero `PUT` |
| Source rules | no `Length` and no material; both | — | `WALLETKEY.SOURCE.REQUIRED`; `WALLETKEY.SOURCE.BOTH`; other length `WALLETKEY.LENGTH.RSA` / `.SYMMETRIC`; zero `PUT` |
| RSA replace | existing RSA; generate (either caller) or import (form) | destructive; one `PUT`; whole pair replaced; a certificate-only import leaves no private key | other type `WALLETKEY.TYPE.MISMATCH`; metadata moved since mint: target-changed; zero `PUT` |
| Symmetric replace | existing symmetric; form import | typed name first; one `PUT {Type, Secret64, Length}`; `KeyId` kept | as RSA replace |
| Agent import attempt | mint without `Length`, or a confirm carrying material | — | mint `WALLETKEY.SOURCE.REQUIRED`; confirm with material `WALLETKEY.SOURCE.BOTH`, zero `PUT` |
| Path field | any `Wallet.Secret` `PUT` body with `*File` | — | 400 `PORT.FIELD.UNEXPECTED` before any vendor call |
| Key-value secret | 8.6 create, edit | unchanged | unchanged |

</intent-contract>

## Code Map

**Vendor (read in source, measured below):** `%Api.Admin.Endpoints.Wallet.Secret` (Hidden; `RunPut`: `$CLASSMETHOD(Type,"Exists")` then `Modify` or `Create`, 201 on create, 422 absent collection, 400 `WalletInvalidParameter`); `irislib/%Wallet/AsymmetricKey.cls` (`NormalizeProperties`: `*File` read through `GetFile`, `CreateKeyPair` when no material); `RSA.cls` (`Length` from certificate or private key only; `ValidateSecret` #26224, #732, #733, #742, expired); `SymmetricKey.cls:65-83` (`Create`: `properties("Length")` sets a local subscript, so an imported key stores no `Length`; random key when `Length` is defined and `Secret` is not); `Secret.cls` (`NormalizeProperties` maps `Secret64` to `Secret`).

**Server** (`src/OcuPilot/`):

- `Port/WalletPort.cls`: `Invoke` :43 (completes `GET` from `LIST`), `Completed` :68-108 (non-key-value answers `{Type}` alone), `KeyValueSettings` :115-151 (the model for the new metadata read: open through `%Wallet.Secret.Exists` in `%SYS`, read properties, drop the object), `Snippet` :168.
- `Port/AdminPort.cls`: `WRAPPEDTYPES` :730 (flat body to `{Type, WalletSecretConfig}`), `PemBlock` :2090 (`cert` and `key` kinds; re-wraps a block whose line breaks were lost), `PemBytes` after it, `UNLOGGEDREFUSALS` :598, `PROPERTYFAULTS` :3266, `Snippet` :3453.
- `Area/Security/WalletSave.cls`: `HandleCreate` :67 and `HandleUpdate` :105 (hold, then `Create` :146 / `Update` :204); `Prohibited` :289; `RenderViolations` :365.
- `Area/Security/WalletRules.cls`: `Validate` :62, `HandleForm` :162 (`editable` false for non-key-value :192), `Rules` :342, `FieldOf` :360.
- `Area/Security/X509Rules.cls`: `Validate` :56 and `KeyMatches` (the key, password and expiry checks to mirror).
- `Screen/Tool/WalletSecretCreate.cls`, `WalletSecretUpdate.cls` (`ArgumentProblem` :136 refuses non-key-value); action-with-arguments model `EncryptionKeyFileWrite.cls` (`ARGUMENTS`, `REQUIREDARGUMENTS`, `FINGERPRINTSUBJECT`, `MergeUpdate` :146 answering payload and diff) and `EncryptionKeyFileRemoveKey.cls` (`DESTRUCTIVE`, `CONSEQUENCE`); unadvertised model `LicenseKeyActivate.cls:25`.
- `Screen/Descriptor/WalletSecretList.cls:53` (`secretArguments`), `WalletSecretForm.cls:42` (`context.secretFields`).
- `Screen/Tool/FieldLists.cls:718-743` (already derives `Wallet.Secret:%Wallet.RSA` and `:%Wallet.SymmetricKey`); `Classification.cls:513-532` (the key-value entries to model); `ToolFields.cls` (regenerated).
- `Kernel/Proposal/Prohibited.cls`: wallet arm :1245-1251, `PermittedChangeFields` :931, `PermittedCreateFields` :1058 (pinned equal to 8.6's tools by `Test/WalletSecretUpdate.cls:73`).
- `Kernel/Governance/Baseline.cls:135-137`. `Api/Error.cls` wallet codes :2459-2523, `ENCRYPTION.` dispatch lines :1227, :1428; `Api/EncryptionError.cls` (sibling model: `Codes`, `ViolationCodes`, `FieldOf`, `ReasonFor`). `Api/Router.cls:114-117`, :544-571.

**Client** (`ui/src/app/`):

- `areas/security/wallet-secret-form.page.ts` (read-only captions :113-114, `editable` :337) and `.store.ts` (`KEY_VALUE_TYPE` :36, `SecretView` :61-77); PEM entry model `x509-form.page.ts:118-167` (certificate textarea, masked key input with reveal toggle, Load from file); `shell/typed-name-dialog.ts`; `core/proposal-view.ts` (consequence codes); `core/strings.ts:1631-1635` (wallet strings; `walletTypeReadOnly`, `walletTypeElsewhere` retire), reuse `x509FieldCertificate`, `x509FieldPrivateKey`, `x509FieldPrivateKeyPassword`, `x509FieldHasPrivateKey`, `x509LoadFromFile`, `tableColumnType`, `tableStatusYes/No`.
- Budgets: `ui/tools/strings.test.mjs:588` (2800, 2705 used); `ui/angular.json:54` `maximumWarning` 2993kB, pinned at `ui/tools/angular-json.test.mjs:538` (DW-1166 re-base; stop and ask above 3800kB). No new screen, so `navigation.test.mjs` is unchanged.
- EXPERIENCE.md (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`, 1039 lines): :173 Dialogs, :414-416 the wallet form rows (:416 holds the two retiring sentences).

**Tests and rosters:** models `Test/WalletSecretCreate.cls`, `WalletSecretUpdate.cls`, `WalletPortRead.cls`, `WalletWire.cls` (`OCUPILOT_ALLOW_PRINCIPALS`), `WalletRecordPort.cls` (records every mutating body), `WalletProbe.cls` (`COLLECTION` `OcuPilotProbe86`), `X509Material.cls` (run-time PEMs: certificate, PKCS#8, encrypted, legacy, other, EC, expired); `ui/browser/wallet-secret.browser-spec.mjs`. Rosters (re-derive each count from its red): `SurfaceCoverage`, `ReadTool`, `ToolRoundTrip`, `ToolWrite`, `ToolEmit`, `Governance`, `GovernanceBaseline`, `Descriptor`, `Prohibited`, `DraftRegistry`, `DerivedFields`, `FieldDerive`; `scripts/ci-throwaway.sh` principals roster comment (:368) with `ui/tools/ci.test.mjs`.

## Tasks & Acceptance

**Execution (server)** (`src/OcuPilot/`):

- `Port/AdminPort.cls` (add-only) -- refuse `CertificateFile`, `PublicKeyFile`, `PrivateKeyFile` on `Wallet.Secret` `PUT` with 400 `PORTFIELDUNEXPECTED` before any vendor call; `PemBlock` gains a `public` kind (`PUBLIC KEY`, `RSA PUBLIC KEY`) -- AD-21; the vendor reads a named server file (measured).
- `Port/WalletPort.cls` -- `Completed` answers RSA `{Type, Length, HasPrivateKey, HasCertificate}` and symmetric `{Type, Length, KeyId}` through a `KeySettings` read modeled on `KeyValueSettings`, never `GetPublic` or a stored value; a `Wallet.Secret` `PUT` of a `%Wallet.SymmetricKey` body carrying `Secret64` reads the name first: absent, it sends `{Type, Secret64}` then `{Type, Length}` with the decoded byte count; present, one `{Type, Secret64, Length}`; the decoded bytes are cleared before return; `Snippet` mirrors both branches with `"<Secret64>"` -- AD-27, AD-52, AD-59; DW-1555.
- `Api/WalletKeyError.cls` (new) and `Api/Error.cls` (two dispatch lines, `WALLETKEY.` prefix) -- the codes and sentences in Design Notes › Sentences; `Error.REASONWALLETTYPEUNSUPPORTED` becomes "This secret is not a key-value secret." -- AD-39.
- `Area/Security/WalletKeyRules.cls` (new) -- `Validate(type, mode, args, .violations, checkTaken)` over the I/O matrix, using `PemBlock` for shapes and mirroring `X509Rules` (validity, `KeyMatches` over a certificate or a public key, password); answers canonical PEM for the port; `HandleForm` additions served by `WalletRules.HandleForm` (`secret` metadata, `editable` true for all three types, `keyLengths {rsa:[2048,3072,4096], symmetric:[16,24,32]}`, the `WALLETKEY` rules) -- AD-39, AD-55.
- `Area/Security/WalletKeySave.cls` (new) -- create and replace for RSA and symmetric through the four tools, each taking `HoldTool` first, rules before the port, material joined to the body only after the verdict and cleared after the port answers, answering `{name, readBack}`; `WalletSave.HandleCreate` dispatches a body whose `Type` is RSA or symmetric here, and `HandleUpdate` a fresh read of those types -- AD-34, AD-53, AD-55, AD-56; DW-1555.
- `Screen/Tool/WalletKeyCreateRsa.cls` (`security.secrets.creatersa`) and `WalletKeyCreateSymmetric.cls` (`security.secrets.createsymmetric`) (new) -- AD-54 creates on `WalletPort`, `READTYPE` `GET`, `WRITETYPE` `PUT`, `PERMITTEDFIELDS` `Length`, `DerivedFields` sets `Type`, schema `{Name, Length}` with its enum, `ArgumentProblem` requires `Length`; the material names are screen-only secrets (in `SecretBodyNames`, none in `ComposedSecrets`, so the card shows no key row); the write refuses material beside `Length` (`WALLETKEY.SOURCE.BOTH`); `WRITERESOURCE` `%Admin_Wallet:USE`.
- `Screen/Tool/WalletKeyReplaceRsa.cls` (`security.secrets.replacersa`, advertised, generate for the agent) and `WalletKeyReplaceSymmetric.cls` (`security.secrets.replacesymmetric`, `ADVERTISED` 0) (new, on an abstract `WalletKeyReplace.cls` modeled on `EncryptionKeyFileWrite`) -- action-style writes with a port-built body (AD-51, AD-56 (i)); `DESTRUCTIVE` 1; `CONSEQUENCE` `WALLETKEY.REPLACE.RSA` / `.SYMMETRIC`; `FINGERPRINTSUBJECT` `Type,Length,HasPrivateKey,HasCertificate` / `Type,Length,KeyId`; `MergeUpdate` answers the `Length` diff row; a fresh read of another type refuses `WALLETKEY.TYPE.MISMATCH` before any `PUT`.
- `Screen/Tool/Classification.cls` (add-only) -- entries for the four tools over their type's field list: `Length`, `HasPrivateKey`, `HasCertificate`, `KeyId` ordinary; `Certificate`, `PublicKey`, `PrivateKey`, `Password`, `Secret`, `Secret64` secret; the three `*File` fields ordinary and admitted by no tool; regenerate `ToolFields.cls`.
- `Screen/Descriptor/WalletSecretList.cls` and `WalletSecretForm.cls` -- `secretArguments` and `context.secretFields` gain `Certificate`, `PublicKey`, `PrivateKey`, `Password`, `Secret64`; regenerate `screens.generated.ts`.
- `Kernel/Proposal/Prohibited.cls` (add-only) -- the wallet arm checks a tool declaring `SECRETTYPE` against `WalletKeyFields(type, creates)` (RSA: `Length`, `Certificate`, `PublicKey`, `PrivateKey`, `Password`; symmetric create: `Length`, `Secret64`; symmetric replace: `Secret64`); the key-value lists are unchanged -- AD-10, AD-54.
- `Kernel/Governance/Baseline.cls` (add-only) -- `security.secrets.creatersa` and `.createsymmetric` `true`, `.replacersa` and `.replacesymmetric` `false` -- AD-22.
- `Api/Router.cls` -- no new route: the two wallet routes dispatch by type.

**Execution (client)** (`ui/src/app/`):

- `areas/security/wallet-secret-form.page.ts` and `.store.ts` -- on create a Type choice (Key-value, RSA key, Symmetric key) and, for RSA and symmetric, Generate (Key length select) or Import; RSA import: Certificate and Public key textareas, Private key masked input with reveal toggle, Private key password masked, each PEM field with Load from file (the X.509 model); symmetric import: masked Key (base64). An existing RSA or symmetric secret shows its metadata read-only and a Replace the key section (RSA: generate or import; symmetric: import); its Save opens `app-typed-name-dialog` (verb "Replace the key", the secret's full name, the consequence sentence) before any `PUT`. Material fields are page-local, never in the store's buffer or screen context, emptied on save, leave and destroy. Refusals land on their fields.
- `core/proposal-view.ts` -- the two consequence codes. `core/strings.ts` (add-only, one key per value under its `/** EXPERIENCE.md:n */`; retire `walletTypeReadOnly`, `walletTypeElsewhere`). `ui/angular.json` and `angular-json.test.mjs` -- re-base `maximumWarning` to the measured total under DW-1166 if crossed.
- **EXPERIENCE.md, in place, keeping 1039 lines** (then `cd ui && npm run test:tools`) -- :173 adds "replace a wallet key's material on the Secret form (Story 18.24: the destructive treatment, typed name the secret's full name)"; :414 and :415 gain the new labels and helpers; :416 is replaced by the RSA and symmetric fields, the sentences and the consequences, tagged `[AMENDED 2026-10-06 - Story 18.24]`.

**Tests** (probe collection `OcuPilotProbe1824` through a `Test/WalletKeyProbe` subclass of `WalletProbe`; material from `X509Material` and `GenCryptRand` at run time; every write through `WalletRecordPort`):

- `Test/WalletKeyCreate.cls` -- schemas carry no material; generation on both callers with read-backs; each import form on the screen (PKCS#1, PKCS#8, encrypted PKCS#8 and legacy with password, certificate only, public key only, line breaks removed); every matrix refusal with zero recorded `PUT`; a symmetric import's stored key equals the imported one (AES-CBC round trip with the test-time key) and its `Length` reads 16/24/32; a name taken since the mint.
- `Test/WalletKeyReplace.cls` -- destructive mint, consequence codes, the screen route replacing with no proposal and no governance check (the typed name is the page's), fingerprint refusal after the metadata moved, type mismatch with zero `PUT`, a certificate-only RSA replace leaving `HasPrivateKey` false, a symmetric replace keeping `KeyId`.
- `Test/WalletKeyRead.cls` -- the metadata read per type; no answer, proposal, ledger row, `messages.log` line or tool result carries a test-time key's base64, a `-----BEGIN` line or public material; the `*File` refusal with no vendor call; codes, sentences, baseline keys, `replacesymmetric` absent from every advertised roster.
- `Test/WalletKeyWire.cls` (`OCUPILOT_ALLOW_PRINCIPALS`; joins `ci-throwaway.sh`'s roster comment and `ci.test.mjs`) -- over HTTP: a principal holding only the form's pairs creates, imports, replaces and reads; one without `%Admin_Wallet:USE` is refused by name on each route.
- Component specs for the page and store; `ui/browser/wallet-secret.browser-spec.mjs` (extended): create an RSA key by generation and a symmetric key by import, the metadata view, Replace through the typed-name dialog, no key text in the DOM after save, the theme gate in both themes.

**Acceptance Criteria:**

- **C1:** Given an RSA, symmetric or key-value secret, when the Secret form, the agent's fresh read or the Secrets list answers it, then RSA reads `Type`, `Length`, `HasPrivateKey`, `HasCertificate`, symmetric `Type`, `Length`, `KeyId`, key-value as 8.6, and no answer, DOM, screen context, proposal, ledger row, log line or tool result carries key material, public halves included.
- **C2:** Given a free name in an existing collection, when a person saves, or the agent proposes and the person confirms, an RSA key of 2048, 3072 or 4096 bits or a symmetric key of 16, 24 or 32 bytes, then one `PUT {Type, Length}` is sent, the secret lists with its type, the read-back matches `Length`, and a name taken since the mint refuses the confirm with zero `PUT`.
- **C3:** Given the Secret form, when a person imports an RSA key (certificate or public key, optional private key and password, pasted or loaded from a local file) or a symmetric key (base64), then the material reaches the vendor once, as content, the metadata reads as the key's, and an imported symmetric key is stored as given with its length; the agent's tools offer no import.
- **C4:** Given an existing RSA or symmetric secret, when a person saves a replacement after typing its name, or the agent proposes an RSA regeneration and the person confirms, then one `PUT` replaces the material, the consequence is stated before it, and a confirm after the metadata moved or against another type is refused with zero `PUT`.
- **C5:** Given a body the rules refuse, when either caller submits it, then it is refused on its field with zero `PUT` and no `messages.log` line.
- **C6:** Given a `Wallet.Secret` `PUT` body naming `CertificateFile`, `PublicKeyFile` or `PrivateKeyFile`, when it reaches `AdminPort`, then it is refused 400 `PORT.FIELD.UNEXPECTED` before the vendor is called.
- **C7:** Given a principal holding only the wallet screens' pairs, when it creates, imports, replaces and reads, then each succeeds; without `%Admin_Wallet:USE`, each is refused by that pair's name with no vendor call.
- **C8:** Given the story lands, when the rosters run, then the baseline reads the two create keys `true` and the two replace keys `false`, `security.secrets.replacesymmetric` is in no advertised list, every roster names the four tools, EXPERIENCE.md reads 1039 lines and the strings bound holds.
- [ ] DW-1555: creating and editing RSA and symmetric-key wallet secrets -- C1 to C8.

## Spec Change Log

- 2026-10-06, spec gate (lead): Decision 5 changed. `security.secrets.creatersa` and `.createsymmetric` ship `true`, the two replace keys `false` (AD-22 as restated; the preamble's disabled set is destructive actions). Intent, Tasks, C8, the C8 mutation and Design Notes edited to match. The six proposed amendments are written into the spine (AD-8, AD-21, AD-27, AD-51, AD-52, AD-53). The two vendor findings measured at plan are ledgered as IRIS defect candidates under the owner's hold. Verification names the runner's loader.

## Review Triage Log

### 2026-10-06 - Review pass

- verdicts: 18 findings - high 0, medium 3, low 12, false 3, maybe-false 0
- findings:
  - `medium` `patch` the `Prohibited` wallet-key arm has no refusal test - added `WalletKeyRead.TestTheFieldFenceJudgesAKeyWriteByItsOwnType` (create and replace, permitted and refused); both arms mutated red.
  - `low` `patch` no mutation names the moved-metadata fingerprint - mutation run and recorded under C4; the symmetric `KeyId` leg shares the digest mechanism and is not separately mutated.
  - `low` `patch` the script test's last assertion could not fail - the RSA replace body now carries a test-time key and the mutation reddens it.
  - `medium` `patch` the page spec's DOM check cannot see an input's value property - new replace-flow test reads the input value; mutation red.
  - `low` `reject` the store spec's "holds none" check - the store never receives the material except as a call argument, and the page spec now pins the emptying; a test-only tightening buys nothing.
  - `low` `patch` a dead `optional` refusal case - removed.
  - `low` `patch` `tForm` computed and unused - the assertion now compares to the form's own pairs.
  - `low` `reject` `Leak` over an empty secrets object - `All()` is a fixed roster.
  - `medium` `patch` C1 client half has no mutation line - same root as the DOM finding; line added.
  - `low` `reject` C2 read-back not mutated - the wire test asserts the `matches` verdict on a real create; the comparison is Story 16.17's.
  - `low` `reject` C5 rules not mutated one at a time - each refusal case names its own code and fails alone.
  - `low` `patch` C7 denial test has no mutation line - mutation run and recorded.
  - `low` `reject` C8's budget and `proposal-view.test.mjs` read source text - the pinned artifact is the text itself, as in the sibling tests.
  - `low` `reject` the old `WALLETTYPEUNSUPPORTED` refusal path lost its coverage - the key-value tool's refusal is pinned by `WALLET.TYPE.UNSUPPORTED` sentence and `WalletKeyRead` roster legs; the changed screen answer is the intended one.
  - `false` `reject` the screen's replace passes an empty diff to `Prohibits` - the screen's body is port-built from fixed members, never from a caller-chosen field.
  - `false` `reject` note (a): `replacesymmetric` stores `destructive=0` - an unadvertised tool cannot be minted (`Registry.Resolve` refuses), so no proposal exists; the tool declares `DESTRUCTIVE` 1 and the page asks the typed name.
  - `false` `reject` note (b): a confirm carrying material is spent before its 422 - the matrix row requires 422 `WALLETKEY.SOURCE.BOTH` with zero `PUT`, and every other port refusal follows the claim (`Confirm.cls` header).
  - `low` `reject` intent audit: no divergence reported; the one unconfirmed claim (`replacesymmetric` unadvertised) is pinned by `WalletKeyRead` roster legs.

## Design Notes

**Governing ADs:** AD-2, AD-27, AD-52 (`WalletPort` extends `AdminPort`; AD-27's third case widens); AD-3 (field lists already derived per `Type`; reviewed classification); AD-4, AD-54 (upsert `PUT`; creates fingerprint absence); AD-51, AD-56 (replace is action-style with a port-built body carrying declared secrets); AD-6, AD-34, AD-40, AD-53, AD-55 (two callers, the hold, the closed confirm channel; one unadvertised tool); AD-8, AD-29 (the wallet screens' pairs, measured); AD-10 (no arm: OcuPilot keeps no RSA or symmetric secret, and the vendor refuses a type change); AD-13, AD-14 (`wallet-secret`, unchanged); AD-15, AD-53 (vendor event on every write, so no named case); AD-21 (no path for key material); AD-22 (create keys `true`, replace keys `false`); AD-24, AD-35, AD-36, AD-48 (no material on any surface); AD-26 (synchronous, nothing queues); AD-39; AD-58; AD-59.

**Measured at plan** (on `ocupilot-ci`, 2026-10-06 21:37-21:43 UTC, through `WalletPort.Invoke` in HSCUSTOM as `irisowner`, collection `OcuPilotProbe1824`; material made by the container's OpenSSL at run time and deleted; no value printed; S0: no wallet secret but `OcuPilotDemo.Sample`, monitor state 0 with 0 alerts):

- **RSA generate:** `Length` 2048 201 in 96 ms, 3072 and 4096 about 280 ms, 1000 and 1024 accepted, 512 500 #731, 0 and none 500 #26225; `"2048"` accepted. Stored `HasPrivateKey` 1, `HasCertificate` 0.
- **RSA import:** PKCS#1 key with PKCS#1 public key, PKCS#8 with SPKI, certificate alone, certificate with key, encrypted PKCS#8 and legacy with password: 201, `Length` 2048. Public key alone: 201 with `Length` empty (the vendor computes it only from a certificate or private key; `$System.Encryption.RSASize` raises `<ILLEGAL VALUE>` on a public key). Refused 500: private key alone #26224, encrypted without or with a wrong password #732, another certificate's or an EC key #733, not a certificate #742. `Length` beside a certificate is ignored; `HasCertificate` sent is ignored; `Usage` 400 #26218. `CertificateFile` naming a server file: 201, the vendor read the file. A PEM with its line breaks removed does not parse (`RSASize` -1, the certificate's fields empty).
- **Symmetric:** generate 16, 24, 32 (also 1 and 64) 201; 0, -1 and none 500 (#5802, #5659). `Secret64` alone 201, key stored as given (AES-CBC round trip), `Length` empty; `Secret64` with `Length` stores a random key (the round trip fails); a 20-byte import is accepted and AES-CBC then refuses it (#26210); bad base64 500 #26219; a duplicate `KeyId` 500 #5808 (and a "Create Wallet Secret" audit row for the failed create).
- **Modify** (`PUT` on an existing name): RSA with no material 500 #26225, unchanged; with `Length` 3072 regenerates the pair (in 736 ms); with a certificate alone replaces the material and drops the private key (`HasPrivateKey` 0). Symmetric with nothing 200, unchanged; `Length` alone changes only the stored length; `Secret64` replaces the key and keeps the old `Length`; `Secret64` with `Length` sets both in one `PUT`; `KeyId` changes. A `PUT` whose `Type` differs from the stored secret's (key-value to RSA or symmetric, symmetric to RSA or key-value, RSA to symmetric): 500, mapped `PORT.CONFLICT`, nothing changed, the stored value intact.
- **Events:** every create and modify records `%System/%Security/WalletSecretChange` with the metadata and `Storage: ********`, no key material.
- **Pairs:** a principal holding `%Admin_Wallet:USE`, `%DB_IRISSYS:READ` and the code databases' `READ` created, imported, replaced and read each type through `WalletPort`.
- **Cost of a vendor refusal:** each 500 above logged one severity-2 line; the 26 alerts set the monitor state to 2 (cleared to 0 at teardown). Teardown removed 33 secrets, the collection, the principal and role, the routine and the key files; `%Wallet.LocalStorage` holds the demo row alone.

**Decisions** (applied in this plan; the spec gate confirms):

1. **Edit is replace.** An RSA or symmetric secret has no settable metadata (`Usage` refused; `Length` alone falsifies the stored length; `KeyId` is the vendor's GUID), so editing it means replacing its material, at the destructive treatment, through two replace tools. A fresh generated symmetric key needs a new secret: the vendor generates only on create.
2. **Imports are the person's, on the form.** The agent's tools generate only; key material never passes through a proposal card or the model, as for License key's activation (AD-53). `replacesymmetric`, import-only, is unadvertised.
3. **No public material in any read or fingerprint.** The AC makes every key material write-only; reads and fingerprints use metadata.
4. **Lengths:** RSA 2048, 3072, 4096 bits; symmetric 16, 24, 32 bytes (AES-CBC's; AES-GCM uses 32).
5. **The create keys `true`, the replace keys `false`** (spec gate, AD-22 as restated 2026-10-05: a new write key enters enabled unless the story sets it disabled, and a destructive one ships off. Creating a wallet key secret changes no existing encryption, like 8.6's `security.secrets.create`; Epic 18's preamble disables destructive actions, which the two replaces are).
6. **Pre-check everything the vendor refuses**, mirroring `X509Rules`, so no refusal reaches the vendor's logged 500.
7. **The port computes an imported symmetric key's `Length`** and sequences the create's second `PUT` (the vendor's `Create` drops it and turns `Length` with `Secret64` into a random key).

**Sentences** (published once at EXPERIENCE.md :416, held equal by the existing fixed-strings test):

| Code (field) | Sentence |
| --- | --- |
| `WALLETKEY.VALIDATION` | "The key was refused." |
| `WALLETKEY.SOURCE.REQUIRED` (Length) | "Choose a length to generate a key, or enter a key to import." |
| `WALLETKEY.SOURCE.BOTH` (Length) | "Generate a key or import one, not both." |
| `WALLETKEY.LENGTH.RSA` (Length) | "An RSA key is 2048, 3072 or 4096 bits long." |
| `WALLETKEY.LENGTH.SYMMETRIC` (Length) | "A symmetric key is 16, 24 or 32 bytes long." |
| `WALLETKEY.PUBLIC.REQUIRED` (Certificate) | "An imported RSA key needs its certificate or its public key." |
| `WALLETKEY.CERTIFICATE.SHAPE` / `.PUBLICKEY.SHAPE` / `.PRIVATEKEY.SHAPE` | "Paste one PEM certificate." / "Paste one PEM RSA public key." / "Paste one PEM private key." |
| `WALLETKEY.CERTIFICATE.INVALID` | "This certificate is not valid now: it has expired or is not yet valid." |
| `WALLETKEY.PRIVATEKEY.MISMATCH` | "This private key does not belong to the certificate or public key, or is not an RSA key." |
| `WALLETKEY.PASSWORD.REQUIRED` / `.WRONG` / `.WITHOUTKEY` | "This private key is encrypted. Enter its password." / "This password does not open the private key." / "A password is used only with an encrypted private key." |
| `WALLETKEY.SECRET64.SHAPE` | "Enter the key as base64 that decodes to 16, 24 or 32 bytes." |
| `WALLETKEY.TYPE.MISMATCH` (Type) | "This secret holds another type of key, and a secret's type cannot change." |
| `WALLET.TYPE.UNSUPPORTED` (8.6's code, reworded; the key-value edit tool's refusal) | "This secret is not a key-value secret." |
| `WALLETKEY.REPLACE.RSA` | "Replaces the whole key pair. The old private key is discarded, so data encrypted to the old public key can no longer be decrypted with this secret. An import without a private key leaves the secret with none." |
| `WALLETKEY.REPLACE.SYMMETRIC` | "Replaces the key. Data encrypted with the old key can no longer be decrypted with this secret." |

Labels and helpers: "Key-value", "RSA key", "Symmetric key", "Generate a new key", "Import a key", "Key length", "2048 bits", "3072 bits", "4096 bits", "16 bytes (AES-128)", "24 bytes (AES-192)", "32 bytes (AES-256)", "Public key", "Key (base64)", "Certificate present", "Key ID", "Replace the key", "The instance generates the key. No read returns it.", "Key material is write-only: no read returns it, here or to the agent."

**Named limits:** (1) a public-key-only RSA import reads `Length` empty (the vendor's); (2) a vendor refusal the rules do not pre-empt still logs at severity 2 until DW-2007's code-scoped entry (Epic 18's burn-down); (3) `KeyId` is not settable; (4) a legacy encrypted key pasted into the single-line field loses its header lines and is refused its shape, while Load from file keeps them (`PemBlock`'s rule, as for X.509).

**Proposed amendments** (Rule 20; the lead writes them at the spec gate):

1. **AD-27, the third case:** "returns `{Type, Usage, RequireTLS, AllowedHosts}`" becomes "returns a key-value secret's `{Type, Usage, RequireTLS, AllowedHosts}`, an RSA key's `{Type, Length, HasPrivateKey, HasCertificate}` and a symmetric key's `{Type, Length, KeyId}` (Story 18.24)", and its fingerprint sentence names those fields; never a value, public halves included.
2. **AD-21, after the encryption key file sentence:** "**Wallet key material is content, never a path** (Story 18.24): `AdminPort` refuses `CertificateFile`, `PublicKeyFile` and `PrivateKeyFile` on any `Wallet.Secret` `PUT`, because the vendor reads the named server file (measured on `ocupilot-ci`, 2026-10-06)."
3. **AD-51, after Story 18.22's case:** "Story 18.24's case: `WalletPort`, which builds the replace tools' `Wallet.Secret` `PUT` bodies from the declared `Length` and secrets; an RSA `PUT` on an existing name replaces the whole key material (a certificate alone drops the stored private key), and a `PUT` whose `Type` differs from the stored secret's is refused by the vendor with nothing changed (measured)."
4. **AD-52, after `LicensePort`:** "`WalletPort` (Story 18.24) sequences an imported symmetric key's create: `PUT {Type, Secret64}` then `PUT {Type, Length}`, because the vendor stores no length for an imported key and stores a random key when `Length` rides with `Secret64` (measured)."
5. **AD-53's unadvertised list and AD-8's parenthetical:** add `security.secrets.replacesymmetric` (Story 18.24): key material the model never supplies, entered only on the Secret form; its key ships disabled.
6. **AD-8:** "**Story 18.24's wallet key tools declare the wallet screens' pairs** and nothing more (measured on `ocupilot-ci`, 2026-10-06: a principal holding exactly them created, imported, replaced and read each type)."

**Integration ACs:** the form consumes `GET /wallet/secret/form`, `POST /wallet/secret` and `PUT /wallet/secret/:id` for RSA and symmetric keys against `ocupilot-ci` (C1 to C4, C7; `WalletKeyWire`, the browser spec); the Secrets list's read shows a created key (C2); `Mint` consumes the two consequence codes and `DESTRUCTIVE` (C4; `WalletKeyReplace`).

**Consumes:** 8.6 (`WalletPort`, the form, its routes, rules and probe), 8.5 (`PemBlock`, `X509Rules`, `X509Material`), 23.4 (`HoldTool`), 16.17 (read-back), 14.1 (`Snippet`), 14.2 (baseline). **Consumed-by:** 18.12 (the agent's tool set).

**Ledger inbox (Rule 17):** DW-1555 is addressed by every task above and C1 to C8.

**Footprint (Rule 11):** for `footprint_extensions`: `Port/WalletPort.cls`, `Port/AdminPort.cls`, `Area/Security/Wallet*.cls`, `Api/WalletKeyError.cls`, `Screen/Tool/WalletKey*.cls`, the two wallet descriptors, and the wallet form page, store and specs.

**Size:** four tools, a rules and a save class, one error class, the form's type choice and replace section; about Story 8.6's size (inference). No Task 0: every payload was observed at plan.

## Verification

**Setup (slot A):** `ocupilot-ci` only (52776/1975). Load the worktree's `src` with the runner's loader `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/1518373f-040c-4be6-a814-a27bfbff2961/scratchpad/epic-18-d8/load-ocupilot-ci.sh` (rsync to `/Users/jbrandt/.ocupilot-throwaways/ocupilot-ci/src`, `LoadDir` "ck" and `StartPath(1, "")` through `docker exec`; prints `LOAD-OK` and `STARTPATH-OK`; leaves a deployed bundle alone), never through the MCP loader, whose `ocupilot-slot-a` profile reaches `ocupilot`. One test class per call, the next only once the previous has landed in `%UnitTest_Result`, never re-submitted after a client-side timeout. Before a browser run: `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, 0 failures checked against `%UnitTest_Result`: `WalletKeyCreate`, `WalletKeyReplace`, `WalletKeyRead`, `WalletKeyWire`, then `WalletSecretCreate`, `WalletSecretUpdate`, `WalletSecretDelete`, `WalletPortRead`, `WalletWire`, `X509Wire`, and the rosters `SurfaceCoverage`, `ReadTool`, `ToolRoundTrip`, `ToolWrite`, `ToolEmit`, `Governance`, `GovernanceBaseline`, `Descriptor`, `Prohibited`, `DraftRegistry`, `DerivedFields`, `Inventory`. `FieldDerive` has no test methods: run `cd ui && node tools/field-lists.mjs --check` for it.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/wallet-secret.browser-spec.mjs browser/security.browser-spec.mjs`; pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, `uv run scripts/check-objectscript.py <changed .cls>`, `bash scripts/lint-docs.sh`; clean, EXPERIENCE.md 1039 lines.
- `(once, before dev_complete)`, each green with a non-zero count: the full ObjectScript sweep (`cd ui && node tools/ci-runner.mjs --container ocupilot-ci`, one class at a time); `cd ui && npm test && npm run build`; `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`; then no `OcuPilotProbe1824` secret or collection, no probe principal, and monitor state 0 (`$SYSTEM.Monitor.Clear()` after a deliberate vendor refusal).
- `(CI)` the full browser suite, in CI's three `browser-shard` jobs (Rule 29).

**Pinning mutations (Rule 19)** (run on `ocupilot-ci` after a reload with the loader; each reverted byte-identical, checked by hash):

- C1: `KeySettings` adds `GetPublic(name).PublicKey` to the answer. mutation: red in `WalletKeyRead` (the exact key set and the no-material scan), 2 of 5.
- C2: the `generate` mode stops requiring `Length`. mutation: red in `WalletKeyCreate` (`TestTheAgentImportsNothing`, the mint leg of `TestEveryRefusalSendsNothing`). The create's absence fingerprint accepted as a match in `Confirm.FingerprintMatches`. mutation: red in `TestANameTakenSinceTheMintRefusesTheConfirm` (the confirm is sent).
- C3: `Length` sent beside `Secret64` on the create. mutation: red in `TestAnImportedSymmetricKeyIsStoredAsGiven` (the first body and the stored key's round trip). The second `PUT` dropped. mutation: red in the same test (the two-`PUT` count). `PemBlock`'s re-wrap skipped. mutation: red in `TestEveryImportFormOnTheScreen` (the line-breaks leg).
- C4: `DESTRUCTIVE` 0. mutation: red in `WalletKeyReplace.TestTheReplaceIsMintedDestructive`. The type check skipped in `WalletKeyReplace.MergeUpdate`. mutation: red in `TestAMovedOrFlippedTargetRefusesTheConfirm...` (the flipped confirm is sent, the mint accepted). The typed-name branch skipped in the page. mutation: red in `wallet-secret-form.page.spec.ts` (the Save-asks-the-typed-name case, a `PUT` goes out first). `WalletSave.Update` stops dispatching to the key replace and `replacersa` enters the baseline `true`. mutation: red in 4 of 5 `WalletKeyReplace` tests.
- C5: all seven rules dropped (length, source, public, password, mismatch, expiry, base64), applied together. mutation: red in `TestEveryRefusalSendsNothing`, one failing case per rule (the vendor-reaching cases, public, expiry, mismatch and both password, also record a `PUT`), and in `TestTheAgentImportsNothing`.
- C6: `AdminPort.WalletPathField` answers `""` (the one check `AdminPort.Invoke` and `WalletPort.PutKey` both ask). mutation: red in `WalletKeyRead.TestAServerFileNameIsRefusedBeforeAnyVendorCall`.
- C7: a create tool declaring `%Admin_Secure:USE`. mutation: red in `WalletKeyWire.TestEachToolRequiresTheFormsPairsAlone` for both create tools.
- C8: `replacersa` `true` and `creatersa` `false`. mutation: red in `GovernanceBaseline` and in `WalletKeyRead` (`TestCodesSentencesBaselineAndRosters`, and `TestNoSurfaceCarriesKeyMaterial` whose confirm is then refused). `ADVERTISED` 1 on `replacesymmetric`. mutation: red in the same test (the advertised roster and the agent's resolve).
- C4 (moved metadata): `WalletKeyReplaceRsa.FINGERPRINTSUBJECT` reduced to `Type,Length,NewLength`. mutation: red in `WalletKeyReplace.TestAMovedOrFlippedTargetRefusesTheConfirmAndAnotherTypeRefusesTheSave` (the moved confirm is sent).
- C4 (client): `confirmReplace` skips `clearMaterial()`. mutation: red in `wallet-secret-form.page.spec.ts` ("a replacement key is in no input once the instance accepted it", which reads the input's value property).
- C7 (denial): `%Admin_Wallet:USE` dropped from `WalletSecretForm`'s `privileges`. mutation: red in `WalletKeyWire.TestACallerWithoutTheWalletResourceIsRefusedOnEachKeyRoute` and `TestEachToolRequiresTheFormsPairsAlone`.
- AD-10, AD-54 (field fence): `Prohibited.WalletKey` (the first `If` of its loop) answers 0, and separately `WalletKeyChanged`. mutation: red in `WalletKeyRead.TestTheFieldFenceJudgesAKeyWriteByItsOwnType` (create cases 2, 4, 5 for the first; replace cases 2, 4 for the second).
- AD-59 (script): the RSA branch of `WalletPort.Snippet` passes the given body in place of the generating body. mutation: red in `WalletKeyRead.TestTheScriptsCarryNoKeyMaterial` (the last leg).
- AD-35 (log): the sent body logged by `AdminPort.Fail`. mutation: red in `WalletKeyRead.TestNoSurfaceCarriesKeyMaterial` (the message-log leg, which looks for each block's first base64 line because a log line cuts a long text short).

## Auto Run Result

Status: done
Blocking condition: none

**Summary:** RSA and symmetric-key wallet secrets: the Secret form's type choice with generate and import, the metadata-only reads, four `WalletPort` tools (creates `true`, replaces `false`, `replacesymmetric` unadvertised), the typed-name replace, the `*File` refusal, `WALLETKEY.*` codes. The orphaned handoff's tree (ff16667b) was audited against Tasks, the matrix and C1 to C8 and found complete.

**Changed this pass:** `Test/WalletKeyRead.cls` (field-fence test, script leg made falsifiable), `Test/WalletKeyCreate.cls` (dead case removed), `Test/WalletKeyWire.cls` (pairs compared to the form's), `Test/ToolDispatch.cls` (roster names the two replace keys, found by the full sweep), `wallet-secret-form.page.spec.ts` (replacement key read from the input's value), and the spec's Verification mutation lines (every AC and the new legs, each demonstrated red and reverted by hash). `warnings` stays `oversized`.

**Review:** 18 findings (medium 3, low 12, false 3): 9 patched, 9 rejected with reasons in the Triage Log; none deferred. The handoff's notes (a) and (b) were judged not real. Follow-up review recommended: false (3 medium patched, all test-only).

**Verification on `ocupilot-ci`:** full ObjectScript sweep 489 classes, 3953 tests; `ToolDispatch` failed in it (roster, fixed, 18 of 18 green after) and `AuditPurge` failed once near the UTC date change and was green on rerun; smoke 50 of 50; `npm test` (1866 tools, 2550 components) and `npm run build` green, bundle 3.01 MB under the re-based 3012 kB warning; `check-objectscript` and `lint-docs` clean; EXPERIENCE.md 1039 lines; monitor state cleared to 0, no `OcuPilotProbe1824` collection. Browser specs ran green in the handoff (12 of 12) against the final client source.

**Residual risks:** `OcuPilotProbeProhibitedRouteRole` remains on the throwaway (another class's fixture, not this story's); a public-key-only RSA import reads `Length` empty (named limit).
