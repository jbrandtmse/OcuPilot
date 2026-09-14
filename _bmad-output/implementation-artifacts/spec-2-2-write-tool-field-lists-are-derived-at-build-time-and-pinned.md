---
title: 'Story 2.2: Write-tool field lists are derived at build time and pinned in CI'
type: 'feature'
created: '2026-09-13'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: []
deferred: []
---

<!-- Plan halted on an intent gap before the intent contract was written. The <intent-contract>
     block is deliberately absent so the re-plan writes it from the amended AC text rather than
     preserving a pre-amendment draft. -->

## Spec Change Log

- 2026-09-14, lead (owner-delegated decision on the plan's five intent gaps): G1-G5 recommendations accepted and written at origin - AD-3 (template methods only; wrapper credentials authored secret by the tool; reviewed per-tool `ordinary|secret|opaque` entry, no entry means secret; shape is contract, placeholder type informational; `mutating` defined; `Wallet.Secret` one list per `Type`), the spine's Conventions Secrets row (suffix pattern, applied at build to string-placeholder fields only - `ChangePassword` is a boolean), epics.md Story 2.2 AC1/AC4/AC5 and Story 9.1's password criterion. Re-plan from the amended text; write the intent contract now.

## Intent Gaps

Every fact below was probed on `ocupilot-iris` in `%SYS` as `_SYSTEM`. Templates were evaluated live on endpoints constructed at `ApiVersion` 2, all 40 of them, with `Security.SSLConfig` called with `includePrivateKeyPassword` 1, as its own `ValidateRequest` does at version 2. Anything not probed is labelled `(inference)`.

### G1: `Security.User`'s template carries no `Password`

The AC says "the vendor templates' own credential fields, `Security.User`'s `Password` among them, are removed at derivation". The same claim appears in AD-3 `:123` and in Story 9.1 (epics.md `:4090`, "Given the derived field list carries `Password`").

- **Evidence:**
  - `Security.User.Schema()` returns 16 keys, and `Password` is not one of them.
  - `Password` exists only inside `ValidateRequest`: POST builds an inline wrapper `{"User": (..Schema()), "Password": ""}`, and CHANGEPWD builds `{"NewPassword": ""}`.
  - Across all 40 templates, three fields hold credential values by name: `Security.Encryption.Settings.AdminPassword`, `Security.X509Credential.PrivateKeyPassword` and `Security.SSLConfig.PrivateKeyPassword`. The last appears only when the template is called with argument 1.
- **Question:** Does derivation read only the template methods, or also the inline POST and action bodies? The inline bodies include User POST `Password`, User CHANGEPWD `NewPassword`, and the SSLConfig, LDAP, OAuth2 and WebAuth change-password or change-secret bodies. None of those has a callable method; they can be read only from source or from `ValidateRequest` behaviour.
- **Recommended:** templates only.
  - Amend the AC to name the three template credential fields.
  - State that a password or secret set through an action body is classified secret by the story that builds that tool (7.2, 8.2, 9.1).
  - Correct AD-3 `:123` and Story 9.1's AC at their origin.
  - Tier: **ask first**, because this touches Epic 9's story block.

### G2: "A field the generator cannot classify" has no classifier to fail

AD-3 names no source from which a field is classified *ordinary*. Without one, every field that misses the name pattern defaults to ordinary, and the fail-closed rule can never fire, so it cannot be falsified (Rule 19). Conventions `:541` also forbids using the name pattern as the primary classifier.

- **Evidence:** every candidate source is incomplete.
  - **Datatype.** `Security.Datatype.Password` is the type of `Security.Users.Password`, `Security.SSLConfigs.PrivateKeyPassword` and `Security.LDAPConfigs.LDAPSearchPassword`. It is not the type of these, which are plain `%Library.String`: `%SYS.X509Credentials.PrivateKeyPassword`, `OAuth2.Client.ClientSecret`, `OAuth2.ResourceServer.ClientSecret`, `OAuth2.Server.Client.ClientSecret` and `Security.System.SMTPPassword`.
  - **Vendor GET omission.** `SSLConfig.ObjToJson` reads `PutRequestBodySchema(0)`, so its GET omits the private-key password. But `X509Credential.ObjToJson` also omits `Alias`, `CertificateFile` and `PrivateKeyFile`, which are not secrets.
  - **Object and empty-array fields.** Templates hold 11 object-typed fields, among them `Task.CRUD.Settings` (`{}`) and `LanguageServer.Custom` (`{}` at the default type). They also hold 2 empty arrays with no element type, `Security.User.Roles` and `EscalationRoles`.
    - If these count as "unclassifiable → secret", the model cannot see a task's settings or a user's roles. That contradicts Story 5.9 ("adding a role").
    - `review-adversarial-ad48.md` §7 proposed an "opaque pass-through" class for such fields. The spine never adopted it.
- **Question:** What positive signal makes a field ordinary, and how are object and empty-array fields classified?
- **Recommended:** a spine-weight decision (Rule 20).
  - A field is ordinary only when a reviewed classification entry declares it ordinary. That entry sits beside the per-tool `required`/`enum`/`description`, so the hand-written part becomes four keys.
  - A derived field with no entry is emitted secret. An instance upgrade that adds a field therefore lands it secret until reviewed, which is the falsifiable fail-closed rule.
  - Object-typed fields take a third class, `opaque`, per §7.
  - Tier: **ask first**. This amends AD-3's rule and AC3's "only hand-written part".

### G3: "The credential pattern" is undefined, and a literal reading hides ordinary fields

No planning document defines the pattern. The only one in the planning set is the harvested `REDACT_KEY_PATTERN` (`harvest/iris-execute-mcp-v2.md:91`, `/password|passwd|secret|token|credential|apikey|api_key|authorization/i`).

- **Evidence:**
  - That pattern matches 23 template field names across 11 endpoints. Three hold credential values by name (inference).
  - The other 20 include booleans (`Security.User.ChangePassword`, `WebApp.App.CSRFToken`, `CorsCredentialsAllowed`), numbers (`OAuth2.Server.AccessTokenInterval`), paths (`ChangePasswordPage`) and X.509 alias names (`ServerCredentials`, `ClientCredentials`; inference).
  - Read literally, the AC makes all 23 secret. The model then could not see or propose `ChangePassword` or the JWT timeouts.
  - A narrower suffix pattern on leaf names, `(?i)(password|passwd|pwd|secret|apikey|privatekey|token)$`, matches 7. Of those, 4 are string-typed: `AdminPassword`, both `PrivateKeyPassword` fields, and `OAuth2.Server.ReturnRefreshToken`.
- **Question:** Which pattern applies, and does the build failure apply to boolean- and number-typed fields, which cannot carry a credential value?
- **Recommended:**
  - Put the suffix pattern in the Conventions *Secrets* row.
  - Fail the build only on a string-typed match emitted ordinary. That leaves `ReturnRefreshToken` as the one non-credential string the rule forces secret.
  - Tier: **ask first** (Conventions row).

### G4: A template placeholder fixes shape, not scalar JSON type

AC1 requires "each field's JSON type", and AD-3 `:111` reads `""` as a string and `true` as a boolean.

- **Evidence:**
  - On `WebApp.App`, 5 fields that the template types as `""` come back as numbers from the vendor's own GET through `AdminPort.Invoke`: `AutheEnabled`, `Timeout`, `ServeFilesTimeout`, `JWTAccessTokenTimeout` and `JWTRefreshTokenTimeout`. The other 39 endpoints were not compared (inference beyond `WebApp.App`).
  - `%Api.Admin.Util.RequestValidator.ValidateDAO` checks only object, array or literal shape, never scalar type.
  - `Security.Audit.Event`'s inline schema types `Enabled` as `""` over a `Security.Datatype.BooleanYN` property.
- **Question:** Should the emitted type be the placeholder's type, or the shape the vendor validates? If it is the placeholder's type, a tool schema declares `string` for an integer, and the schema-driven argument validator Story 2.3 adds refuses the model's integer.
- **Recommended:**
  - Emit `shape` (`literal`, `object` or `array`) as the contract.
  - Keep the placeholder's type as the informational `templateType`.
  - Amend AD-3 `:111` to say the placeholder fixes shape.
  - Tier: **ask first** (AD rule).

### G5: `Wallet.Secret` has three underlying `%Wallet.*` classes, not one `Security.*`/`%SYS.*` class

This affects AC5.

- **Evidence:**
  - `Wallet.Secret.RunPut` dispatches on the body's `Type`, which must be `%Wallet.KeyValue`, `%Wallet.RSA` or `%Wallet.SymmetricKey`. It passes `WalletSecretConfig` to that class's `Create` or `Modify`.
  - `ValidateRequest` builds `{"Type": "", "WalletSecretConfig": {}}`, and leaves unrecognized fields inside the config allowed.
  - The non-private, non-internal properties differ by type:
    - `KeyValue`: `AllowedHosts`, `RequireTLS`, `Secret`, `Secret64`, `Usage`
    - `SymmetricKey`: `KeyId`, `Length`, `Secret`, `Secret64`
    - `RSA`: 12, including `Password`, `PrivateKey`, and three `*File` path properties
    - Settability is inference.
  - `Security.Audit.Event` is consistent with the AC. `Security.Events`, minus the id triple `Source`/`Type`/`Name`, leaves `Description` and `Enabled`, which is exactly what the vendor's inline validator accepts.
- **Recommended:**
  - Amend AC5 to derive one field list per allowed `Type`, from the three `%Wallet.*` classes, under the `{Type, WalletSecretConfig}` envelope.
  - Tier: **apply and report**, since this corrects a wrong class the AC cites.

### Verified, no amendment needed beyond stating the definition

- **"Sixteen template-less mutating endpoints, five in Release 1" holds under one definition:** a template-less class that itself defines `RunPut`, `RunPost`, `RunDelete` or `RunPatch`.
  - A query over all 70 classes returns 16, and all five Release 1 endpoints are among them.
  - `Database.Actions`, `Security.Audit.Record` and `Security.Encryption.Key` mutate only through custom types (inference from their `Run*` method names), so they fall outside this definition.
  - Recommended: state the definition in AD-3 `:121` (apply and report).
- **The 40 template methods:** 21 `RequestBodySchema`, 17 `PutRequestBodySchema`, 1 `PutAndPostSchema` and 1 `Schema`, as the AC says.
  - All return `%DynamicObject`.
  - `Task.CRUD`'s method is a class method; the other 39 are instance methods.
  - Two take arguments: `LanguageServer(type)` and `SSLConfig(includePrivateKeyPassword)`.
  - Two branch on `ApiVersion`: `SSLConfig` and `Encryption.Settings`.
- **`Process`, `Lock` and `Task.Manager` are action-style.** `Process` takes PATCH `{Action}` and BROADCAST `{Message, PidList}`. `Lock` has no body; its DELETE takes query parameters. `Task.Manager` takes PATCH `{Action}`.
- **Self-queued async callers match AD-26.** The classes that call `AddToAsyncQueue` from their own methods are `Database.Actions` (Compact, Defragment, IntegrityCheck), `Journal.Record` LIST and `Security.Audit.Record` LIST.

## Code Map

- `src/OcuPilot/Test/AdminInventory.cls`: the AD-27 fixture.
  - `TEMPLATENAMES` (`:19`) and `Derive`, `Stored` and `Regenerate` (`:110-197`).
  - Its `async` column records only `ShouldRunAsync` overrides (7). The self-queued entry is missing.
  - It reaches vendor classes only through `AdminPort.EndpointPackage()`, so containment holds.
- `src/OcuPilot/Test/Inventory.cls`: re-derives and compares row by row, and pins the counts 70/21/17/1/1/7. It already runs in CI's `instance` job through `ui/tools/ci-runner.mjs`.
- `src/OcuPilot/Port/AdminPort.cls`:
  - `ENDPOINTPACKAGE` (`:39`), `APIVERSION` (`:53`), `EndpointClass` (`:310`), `MethodOrigin` (`:403`).
  - AD-3 says "the port resolves whichever [template method] exists", so the template accessor belongs here (AD-27).
- `scripts/check-objectscript.py:637` `check_admin_api_containment`: the literal `%Api.Admin` is allowed only in `AdminPort.cls`.
- Generator precedents:
  - `ui/tools/screen-mirror.mjs`: runs on the repository, with a `--check` drift mode, and its test compares the checked-in output.
  - `ui/tools/ipm-manifest.mjs --check`.
  - Neither reads an instance, so a derivation step needs the container. `scripts/smoke.sh --container` is the shell precedent.
- `.github/workflows/ci.yml`: `gates` has no IRIS; `instance` runs `ci-runner.mjs --container ocupilot-ci`.
- Spine home for generated schemas: `src/OcuPilot/Screen/Tool/` (Source tree, "generated schemas").

## Design Notes

**Governing ADs:**
- AD-3: derivation, classification, template order.
- AD-5: the field list is generated from the descriptor.
- AD-6: the confirm channel keys off secret fields.
- AD-26: both async entries in the inventory.
- AD-27: containment, and the inventory as fixture.
- AD-41: ledger exclusion.
- AD-1: in-process.
- Conventions: *Secrets*, *Tests*.

**Direction for the re-plan (not yet an intent contract):**
- `AdminPort` resolves and evaluates a template at version 2.
- A container-side derivation step emits a generated class under `Screen/Tool/`, which is committed.
- `gates` checks the committed artifact's shape and the pattern rule without an instance.
- `OcuPilot.Test.*` re-derives on the `instance` job and fails on disagreement.
- The inventory gains the self-queued entry and the template-less mutating classification.

**Integration ACs.** There is no write tool in this story. The first consumer is Story 5.1 (proposal arguments and secret fields), and the first write tool is Story 5.8.

**Consumed-by:**
- `5-1-the-proposal-is-minted-on-the-instance-from-a-fresh-read`
- `5-8-web-applications-enable-a-disabled-application-and-grant-it`
- `8-6-the-wallet-secret-form`
- `8-7-system-and-user-audit-event-configuration`
- `9-1-the-user-editor`
- `4-2-the-tool-registry-its-one-gate-point-and-the-three-shell-rea`: schema emission.

**Consumes:** `AdminPort` (Story 2.1).

## Auto Run Result

Status: blocked
Blocking condition: intent gap

The plan stopped before writing the intent contract. The live instance contradicts AC4 (G1), leaves AC4's fail-closed and pattern rules without a classifier or a pattern (G2, G3), contradicts AC1's type premise (G4), and names the wrong underlying class in AC5 (G5). Each gap above states its evidence, a recommended amendment and the amendment tier.

G1 to G4 change what AD-3 or a Conventions row says, so they are Rule 20 spine updates. G5 and the definition of "sixteen" correct wording in the planning documents.

Ledger inbox: none. `ledger.sh slice all` has no entry on templates, field lists, classification or the inventory. No files other than this spec were written, and nothing was committed.
