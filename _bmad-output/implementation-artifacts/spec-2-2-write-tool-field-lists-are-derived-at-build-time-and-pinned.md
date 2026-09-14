---
title: 'Story 2.2: Write-tool field lists are derived at build time and pinned in CI'
type: 'feature'
created: '2026-09-13'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Forty write payloads would otherwise be transcribed by hand from `[Hidden]` vendor classes, and nothing stops a credential field reaching the model as ordinary data or an IRIS upgrade silently moving a field.

**Approach:** An instance-side step derives each endpoint's field list and JSON shape through `AdminPort` into committed source; a repository-side generator joins it with reviewed per-tool classification entries, fails closed, and refuses a credential-named string field classified anything but secret. CI re-derives on a throwaway instance and fails on disagreement.

## Boundaries & Constraints

**Always:**
- Template resolution order is `RequestBodySchema`, `PutRequestBodySchema`, `PutAndPostSchema`, `Schema`, first method the class defines itself; it lives in `AdminPort` (AD-3, AD-27). Templates are evaluated at `ApiVersion` 2, `Security.SSLConfig`'s with `includePrivateKeyPassword` 1.
- Derivation reads template methods only, plus the underlying classes for `Wallet.Secret` (one list per `Type`: `%Wallet.KeyValue`, `%Wallet.RSA`, `%Wallet.SymmetricKey`, under `{Type, WalletSecretConfig}`) and `Security.Audit.Event` (`Security.Events`).
- Shape (`literal`, `object`, `array`) is contract; the placeholder's scalar type is emitted as information only.
- Classification is `ordinary`, `secret` or `opaque`, read only from a reviewed per-tool entry; a classifiable path with no entry is emitted `secret`.
- The credential rule: a `literal` row whose type is `string` and whose last path segment matches `/(password|passwd|pwd|secret|apikey|privatekey|token)$/i`, classified anything but `secret`, fails the build. Booleans and numbers never trip it.
- ObjectScript under `src/OcuPilot/` only; `uv run scripts/check-objectscript.py` passes; one `iris_execute_tests` call per message, never re-submitted on a client timeout.

**Never:**
- No runtime derivation: the generator (`OcuPilot.Test.FieldDerive`) ships in test scope only, and shipped code reads committed XData.
- No class but `AdminPort` names `%Api.Admin`, shell scripts included. `AdminPort.Template` never calls `Run()` or any `Validate*`.
- No wrapper credential (`Security.User` POST `Password`, change-password `NewPassword`) in a derived list; the write tools that need them author them (Story 9.1).
- No write tool, descriptor write-tool declaration, `required`/`enum`/`description` content, or tool registry (Stories 4.2, 5.x).
- No `docker compose up`/`down`; the live `ocupilot` container is read and compiled into, never recreated.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Unclassified path | Entry for `WebApp.App` omits `Timeout` | `ToolFields` row `Timeout` has `class: secret` | No error |
| Credential classified ordinary | Entry classifies `Security.Encryption.Settings` `AdminPassword` `ordinary` | Generator emits nothing | `--check` exits 1 naming tool and path |
| Boolean credential-like name | Entry classifies `Security.User` `ChangePassword` `ordinary` | Emitted `ordinary` | No error |
| Class-derived credential | Entry classifies `Wallet.Secret:%Wallet.RSA` `Password` `ordinary` | Emits nothing | Exits 1 |
| Hand-typed field | Entry names a path or `fieldList` the committed lists lack | Emits nothing | Exits 1 naming the path |
| Bad vocabulary | Class outside the three; `opaque` on a `literal` row; `ordinary` on a member-less object or array; entry key outside `fieldList`, `classification`, `required`, `enum`, `description`; tool name not `<area>.<screen>.<verb>` | Emits nothing | Exits 1 |
| Drift | Committed `ToolFields.cls` differs from regenerated output | — | `--check` exits 1 |
| Instance moved | A template gains, loses or reshapes a field | — | `OcuPilot.Test.DerivedFields` red naming list and path |

</intent-contract>

## Code Map

- `src/OcuPilot/Port/AdminPort.cls` -- `EndpointClass` (`:310`, the seam `PortFixture.SetEndpointClass` overrides), `MethodOrigin` (`:403`), `APIVERSION` (`:53`); `RunSequence` (`:418-461`) shows how to construct before switching to `%SYS` by save and restore.
- `src/OcuPilot/Test/AdminInventory.cls` -- `TEMPLATENAMES` (`:19`) and `TemplateMethod` (`:202`) move to the port; `Derive`/`Stored`/`Regenerate` (`:110-197`) and `SourceState` (`:238`, `unreadable` never scored as "no match") are the precedent for the new columns and for `FieldDerive`.
- `src/OcuPilot/Test/Inventory.cls` -- row-by-row comparison and count pins (`:50-77`).
- `src/OcuPilot/Test/PortFixture.cls`, `src/OcuPilot/Test/EndpointFixture.cls` -- seam fixture and a vendor-free endpoint stand-in (TYPE parameters, dynamic dispatch).
- `ui/tools/screen-mirror.mjs` -- `extractXData` (`:91`), `braceDelta` (`:65`), `--check` drift mode (`:578-590`); reuse, do not copy.
- `ui/package.json` `prebuild` (`:7`); `ui/tools/client-lint.test.mjs:269` reads it.
- `scripts/smoke.sh` -- `--container` → `docker exec -i <name>` runner and `iris session` precedent; `ui/tools/shell-scripts.test.mjs` pins every `scripts/*.sh`.
- `scripts/check-objectscript.py:637` -- `%Api.Admin` containment over `.cls` and `scripts/*.sh`.
- `ui/tools/ci-runner.mjs` -- CI `instance` job runs `OcuPilot.Test.*` one class at a time.

## Tasks & Acceptance

**Execution:**
- `src/OcuPilot/Port/AdminPort.cls` -- add `TEMPLATENAMES`, a `TEMPLATEARGUMENTS` parameter (`Security.SSLConfig` → 1), `TemplateMethod(pEndpoint)` and `Template(pEndpoint, Output pTemplate, Output pMethod) As %Status`, which resolve through `EndpointClass`, construct at `APIVERSION`, call the class or instance method in `%SYS`, and return an error status when no template exists -- AD-3 says the port resolves the method.
- `src/OcuPilot/Test/AdminInventory.cls` -- call the port's `TemplateMethod`; add a `queues` column (own UDL source contains `AddToAsyncQueue`, `unreadable` on a failed fetch) and a `mutating` column (defines `RunPut`, `RunPost`, `RunDelete` or `RunPatch` itself); regenerate the XData -- AC6's both async entries and AD-3's definition of mutating.
- `src/OcuPilot/Test/Inventory.cls` -- pin `queues` = 3 and template-less `mutating` = 16, the five Release 1 classes among them.
- `src/OcuPilot/Test/FieldDerive.cls` -- `Derive`, `Stored` and `Regenerate` (returns the whole `FieldLists.cls` text). `Derive` covers every class `AdminInventory.Derive` reports with a template. List keys are the endpoint name, or `<endpoint>:<class>` when class-derived; a wallet list also records its `Type` value and the `WalletSecretConfig` envelope member. Rows are `{path, shape, templateType, itemType}`: an object with members yields `Parent.Child` rows, an array's first element yields `Parent[]` rows, and a member-less object or array is one row. Class-derived rows take every non-`Private`, non-`Internal`, non-`%` property minus the identifying ones (`Name`; `Source`, `Type`, `Name`), `LIST` → array and `ClientDataType` → `templateType`. `Process`, `Lock` and `Task.Manager` are emitted `source: none`.
- `scripts/field-lists.sh` -- `--container <name>` runs `Regenerate` through `iris session` and writes `src/OcuPilot/Screen/Tool/FieldLists.cls`; a failed status exits non-zero and leaves the file untouched.
- `src/OcuPilot/Screen/Tool/FieldLists.cls` -- generated and committed (`XData Lists`).
- `src/OcuPilot/Screen/Tool/Classification.cls` -- hand-written reviewed entries (`XData Entries`), keyed by tool name, each `{fieldList, classification: {path: class}}` plus the reserved `required`, `enum` and `description`; committed as `{}` because no write tool exists yet.
- `ui/tools/field-lists.mjs` -- read both blocks, check `Lists` is well formed, apply the matrix, write `src/OcuPilot/Screen/Tool/ToolFields.cls` (`XData Tools`: per tool, each classifiable row, meaning a row no other row's path extends, with its `class`); `--check` reports and exits 1. Append `node tools/field-lists.mjs --check` to `prebuild`.
- `src/OcuPilot/Screen/Tool/ToolFields.cls` -- generated and committed.
- `ui/tools/field-lists.test.mjs` -- every matrix row except "Instance moved", with planted entries passed to the exported functions; committed `ToolFields.cls` equals `generate()`; the committed `Lists` carries the three credential paths as `literal`/`string`.
- `src/OcuPilot/Test/TemplateFixture.cls` -- a vendor-free endpoint defining both `PutRequestBodySchema` and `Schema`, each returning a distinct marker.
- `src/OcuPilot/Test/DerivedFields.cls` -- `%UnitTest` pinning AC1, AC2, AC4 and AC5 on the instance, as listed under Verification.

**Acceptance Criteria:**
- AC1: Given the running instance, when `scripts/field-lists.sh` runs, then `FieldLists.cls` holds one list per template endpoint (40), three wallet lists, one audit-event list and three `source: none` entries, every row carrying shape and informational type, and the committed file equals a fresh derivation.
- AC2: Given an endpoint class defining more than one template method, when the port resolves it, then the earliest in AD-3 order is used.
- AC3: Given a per-tool entry, when it names a path or list that derivation did not produce, or a key outside the entry grammar, then the build fails, so a hand-typed field cannot enter a tool schema.
- AC4: Given the instance's templates, when they are derived and classified, then `Security.User`'s list carries no path ending `Password`, the three template credentials (`Security.Encryption.Settings.AdminPassword`, `Security.X509Credential.PrivateKeyPassword`, `Security.SSLConfig.PrivateKeyPassword`) are present as string literals, and the matrix's unclassified and credential rows hold.
- AC5: Given `Wallet.Secret` and `Security.Audit.Event` publish no template, when their lists are derived from the underlying classes, then they are exactly `KeyValue` 5 (`AllowedHosts`, `RequireTLS`, `Secret`, `Secret64`, `Usage`), `SymmetricKey` 4, `RSA` 12 and `Events` 2 (`Description`, `Enabled`), a test fails on disagreement, and `Process`, `Lock` and `Task.Manager` are recorded as needing no template.
- AC6: Given CI's `instance` job, when `OcuPilot.Test.Inventory` runs, then it re-derives classes, templates, `ShouldRunAsync` overrides, self-queued `Run()`s, mutating status and CSP use, and fails when the instance disagrees.

## Spec Change Log

- 2026-09-14, lead (owner-delegated decision on the plan's five intent gaps): G1-G5 recommendations accepted and written at origin - AD-3 (template methods only; wrapper credentials authored secret by the tool; reviewed per-tool `ordinary|secret|opaque` entry, no entry means secret; shape is contract, placeholder type informational; `mutating` defined; `Wallet.Secret` one list per `Type`), the spine's Conventions Secrets row (suffix pattern, applied at build to string-placeholder fields only - `ChangePassword` is a boolean), epics.md Story 2.2 AC1/AC4/AC5 and Story 9.1's password criterion. Re-plan from the amended text; write the intent contract now.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-3 (derivation, order, classification, mutating), AD-5 (field lists are generated), AD-6 (confirm channel keys off secret fields), AD-16 (save and restore), AD-26 (both async entries), AD-27 (containment; inventory is a fixture). Conventions: *Secrets*, *Tests*, *Tool naming*.

**Evidence** (probed on `ocupilot-iris`, `%SYS`, 2026-09-13 and 2026-09-14):
- 40 templates are 21/17/1/1; two take arguments (`LanguageServer(type="")`, evaluated at its default, and `SSLConfig`); `Security.User`'s template has 16 keys and no `Password`.
- Templates hold 11 object fields: five with members (e.g. `Device.Settings.IOSettings`), and six `{}` (`LanguageServer.Custom`, `Task.CRUD.Settings`, four OAuth2 `Metadata`). They also hold arrays of strings, arrays of objects (`Security.Role.Resources`) and two empty arrays (`Security.User.Roles`, `EscalationRoles`).
- `WebApp.App`'s GET returns numbers for five `""` placeholders.
- `AddToAsyncQueue` appears in exactly `Database.Actions`, `Journal.Record` and `Security.Audit.Record`; the 16 template-less mutating classes include all five Release 1 ones.
- The AC5 counts come from `%Dictionary.CompiledProperty` with the filter above. `Security.Events` minus its id triple matches the vendor's inline validator; `Name` is the wallet secret's URL-identified key (inference).
- `iris_execute_classmethod` caps output at 32,768 characters, so the generated text leaves through `iris session`, not MCP.

**Why the join runs in Node:** classification is a pure function of two committed files, so `gates` (no IRIS) enforces the credential rule; only derivation needs an instance.

**Integration ACs:** No consumers in this story; the first consumer will be Story 5.1 (secret fields out of stored arguments), and the first write tool is Story 5.8.

**Consumed-by:**
- `4-2-the-tool-registry-its-one-gate-point-and-the-three-shell-rea` -- input schemas from `ToolFields`.
- `5-1-the-proposal-is-minted-on-the-instance-from-a-fresh-read` -- secret fields.
- `5-8-web-applications-enable-a-disabled-application-and-grant-it` -- first `Classification` entry.
- `8-6-the-wallet-secret-form`, `8-7-system-and-user-audit-event-configuration` -- class-derived lists.
- `9-1-the-user-editor` -- `Security.User` list; authors `Password` and `NewPassword`.

**Consumes:** `OcuPilot.Port.AdminPort` (Story 2.1).

**Ledger inbox:** none.

## Verification

**Commands:**
- `cd ui && npm run build` (gates and instance) -- expected: prebuild's `field-lists.mjs --check` passes.
- `cd ui && npm test` (gates) -- expected: `field-lists.test.mjs` green.
- `uv run scripts/check-objectscript.py` and `uv run scripts/test_check_objectscript.py` (gates) -- expected: zero problems.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci` (instance) -- expected: `OcuPilot.Test.DerivedFields` and `OcuPilot.Test.Inventory` land with zero failures. Locally, one `iris_execute_tests` per class on `ocupilot-iris`.
- `sh scripts/field-lists.sh --container ocupilot && node ui/tools/field-lists.mjs` -- expected: `git diff --stat` shows no change to either generated class.

**Mutations (Rule 19; each reverted and `git status --short` confirmed unchanged):**
- AC1: change one row's `shape` in `FieldLists.cls` → `DerivedFields` committed-equals-derived test red naming list and path.
- AC2: swap the first two names in `AdminPort.TEMPLATENAMES` → `DerivedFields` order test (fixture) red.
- AC3: plant `"NotAVendorField": "ordinary"` in a `Classification.cls` entry for `WebApp.App` → `npm run build` exits 1; `field-lists.test.mjs` hand-typed row red.
- AC4a: default class `ordinary` instead of `secret` in `field-lists.mjs` → unclassified-row test red.
- AC4b: plant an entry classifying `Security.Encryption.Settings` `AdminPassword` `ordinary` → `npm run build` exits 1; with the pattern check removed → credential-row test red.
- AC4c: evaluate `SSLConfig` without argument 1 → `DerivedFields` credential-paths test red.
- AC5: drop `Name` from the wallet exclusions → `DerivedFields` KeyValue count red; remove `Lock` from the no-template set → no-template test red.
- AC6: set `Security.Audit.Record`'s `queues` to 0 in the XData → `Inventory` row comparison red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

This pass wrote the intent contract from the amended AD-3, Conventions › Secrets and epics.md Story 2.2 text, and folded the former `## Intent Gaps` evidence into Design Notes. New probes this pass: object and array nesting across the 40 templates, the `%Wallet.*` and `Security.Events` property filters, `AddToAsyncQueue` callers (3), and template-less mutating classes (16). Only this spec was written; nothing was committed.
