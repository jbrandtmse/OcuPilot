---
title: 'Story 2.2: Write-tool field lists are derived at build time and pinned in CI'
type: 'feature'
created: '2026-09-13'
status: 'done'
baseline_revision: '25de1436a52ad04c1a4a32b0c375255bebba2515'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      LanguageServer's template is evaluated at its default type, so its Custom object derives member-less and no per-type field (ClassPath, JavaHome, PythonPath, Address, ...) can enter a tool schema.
    evidence: |-
      FieldLists.cls LanguageServer row Custom is shape object with no members; the vendor template builds Custom per type argument (reviewer read the instance source). Intent and AD-3 fix no-argument evaluation except SSLConfig, so a per-type list like Wallet.Secret's needs an AD-3 amendment before the language-server form story.
    location: >-
      src/OcuPilot/Port/AdminPort.cls TEMPLATEARGUMENTS; src/OcuPilot/Screen/Tool/FieldLists.cls LanguageServer
    severity: medium
  - summary: >-
      The Conventions Secrets credential suffix pattern misses string secrets such as the wallet Secret64 and License.Key Key, and refuses ordinary on the string OAuth2 ReturnRefreshToken.
    evidence: |-
      Running isCredential over the committed lists: Secret64 (all three wallet lists) and License.Key Key are not matched, so a reviewed entry may classify them ordinary; Security.OAuth2.Server ReturnRefreshToken is a string that matches and can never be ordinary. The pattern is the spine's Conventions Secrets text, so the fix is a spine amendment, not code.
    location: >-
      ui/tools/field-lists.mjs CREDENTIAL_RE; ARCHITECTURE-SPINE.md Conventions Secrets
    severity: medium
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

### 2026-09-14 — Review pass
- verdicts: 47 findings — high 0, medium 12, low 28, false 7, maybe-false 0
- findings:
  - `medium` `defer` BH: `LanguageServer`'s template evaluated at `type=""` yields a member-less `Custom`, so per-type fields are never derived — intent fixes no-argument evaluation (AD-3); a per-type list needs an AD-3 amendment; deferred.
  - `low` `reject` BH: hand-editing `FieldLists.cls` passes local gates — by design; CI `instance` job's `DerivedFields` is the intent's gate, and a hash check adds machinery.
  - `low` `reject` BH: duplicate JSON keys in `Classification.cls` are last-wins — the duplicate line is visible in the reviewed diff; a duplicate-key scanner adds a tokenizer.
  - `medium` `patch` BH: reserved keys `required`/`enum`/`description` accepted with any content — `classify()` now refuses non-empty reserved content (enforces the Never clause); vocabulary test extended.
  - `low` `reject` BH: credential rule depends on `templateType` (a `null` placeholder evades) — intent and Conventions › Secrets say string placeholders only; `DerivedFields` goes red on any placeholder type change.
  - `medium` `defer` BH: credential pattern misses `Secret64`; nothing pins class-derived credentials beyond RSA `Password` — pattern is the spine's Conventions › Secrets text; deferred with the pattern-gap entry.
  - `low` `patch` BH: AC4 wording vs `ChangePassword`, and the wrapper scan covers only `Security.User` — scan now covers `NewPassword` in every derived list; the AC4 sentence is a spec edit (rejected part).
  - `low` `patch` BH: `WALLETTYPES` never checked against the instance — class-derived test now asserts it equals the concrete `%Wallet.Secret` subclasses.
  - `low` `patch` BH: only an array's first element is derived, silently — `WalkMembers` now returns an error for a multi-element array; regeneration unchanged.
  - `low` `reject` BH: `AdminPort.Template` skips `VerifyInstance` — build-time only on the pinned image; drift output still names list and path.
  - `low` `reject` BH: nothing enforces "no request path calls `Template`" — spec places it in the port; no caller exists; a checker rule adds surface.
  - `medium` `patch` BH: AC2 order mostly pinned by a literal; class-method branch unexercised — grouped with VG order fixtures; class-method branch is exercised by `Task.CRUD`.
  - `low` `reject` BH: malformed list makes `classify` throw instead of listing problems — `main()` catches it and exits 1; generated file only.
  - `low` `reject` BH: symlinked invocation skips the check — shared pre-existing guard; `prebuild`, hook and CI use real paths.
  - `low` `reject` BH: `field-lists.test.mjs` lacks write-path, unknown-argument, throw and missing-file cases — each fails closed; not AC-pinned behavior.
  - `low` `reject` BH: shell test lacks no-marker, no-class and `--namespace` cases — each branch exits 1 with the file untouched.
  - `low` `patch` BH: `scripts/field-lists.sh` mode 100644 — made executable.
  - `low` `patch` BH: `ci.yml` header now says "six" of Epic 1's checks — reverted to "five".
  - `false` `reject` BH: spec edits break the oversized rule; Auto Run Result stale — mutation lines are Rule 19 edits; finalize writes the result.
  - `medium` `defer` EC: template argument changes fields (`LanguageServer.Custom`) — same root cause as the first BH row.
  - `medium` `defer` EC: `Secret64` escapes the credential suffix — same root cause as the pattern-gap row.
  - `low` `reject` EC: `null` placeholder evades the credential rule — same as the BH row.
  - `low` `reject` EC: symlink guard — same as the BH row.
  - `false` `reject` EC: a template of `{}`/`[]` commits a zero-row list — that is the derived truth; drift test catches a template shrinking.
  - `low` `patch` EC: multi-element array members dropped — same patch as the BH row.
  - `false` `reject` EC: ReadOnly/Calculated properties emitted writable — probed: no public property of the three wallet classes is Calculated or ReadOnly.
  - `low` `reject` EC: class-method template on a non-`%` class fails in `%SYS` — only a test fixture could hit it; vendor `Task.CRUD` covers the branch.
  - `low` `reject` EC: duplicate JSON keys — same as the BH row.
  - `low` `reject` EC: `--container` with no value exits 1 not 2 — fails closed, file untouched.
  - `false` `reject` EC: `EndpointClass` regex scores a vendor class template-less — the regex admits every valid non-`%` class name, and the regenerated inventory's template column is unchanged.
  - `medium` `patch` EC: reserved keys accept hand-typed paths — same patch as the BH row.
  - `low` `reject` EC: AC4 wording contradicts `ChangePassword` — fix is a spec edit; epics.md already reads `Password`/`NewPassword`.
  - `medium` `patch` VG: AD-3 order for positions 1-3 unpinned — `TemplateFixtureLate`/`Middle`/`Early` pin every adjacent pair; literal assertion removed; mutation observed red.
  - `medium` `patch` VG: "inherited template does not count" has no subject — `TemplateFixtureLate` inherits `PutRequestBodySchema`; mutation observed red.
  - `low` `patch` VG: shapeless-row fixture green on a second defect — fixture is now a template list asserting the one exact problem; mutation observed red.
  - `false` `reject` VG: clauses without mutation lines — Rule 19 requires one per AC and each AC has one; lines updated for patched tests.
  - `medium` `defer` VG: credential pattern misses `Secret64` and `License.Key` `Key`, and forbids `ordinary` on string `ReturnRefreshToken` — same pattern-gap entry.
  - `low` `reject` VG: AC4 wording — same as the EC row.
  - `low` `patch` IA: unclassified row checked in memory, not in emitted `ToolFields` text — test now matches the emitted `Timeout` row with `class: secret`.
  - `low` `reject` IA: only two matrix exit codes run as a process — all refusals share `main()`'s one exit-1 branch.
  - `low` `reject` IA: `Stored` reads the instance's XData copy — in CI that copy is the checkout; the regeneration command compares bytes.
  - `medium` `defer` IA: information-only type drives the credential rule; `Secret64`, `ClientCredentials`, `ServerCredentials`, `Key` not credentials by name — pattern-gap entry (`*Credentials` may be references, inference).
  - `low` `patch` IA: wallet `Type` set and envelope are constants — same patch as the BH `WALLETTYPES` row.
  - `medium` `patch` IA: order pinned by string, inheritance unpinned — same patches as the VG rows; `TYPEGET` is unread by every template.
  - `low` `patch` IA: wrapper scan only on `Security.User` — same patch as the BH row.
  - `false` `reject` IA: "instance moved" mutation edits the committed side — the comparison is symmetric.
  - `false` `reject` IA: queues/mutating columns and gate wiring are outside the intent block — they are the spec's AC6 and tasks.

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
- AC2: swap the first two names in `AdminPort.TEMPLATENAMES` (with `PortFixture` recompiled) → `DerivedFields` order test red on `TemplateFixtureEarly`; accept an inherited definition in `AdminPort.TemplateMethod` → red on `TemplateFixtureLate`.
- AC3: plant `"NotAVendorField": "ordinary"` in a `Classification.cls` entry for `WebApp.App` → `npm run build` exits 1 naming the path, and `field-lists.test.mjs`'s committed-equals-`generate()` test red (observed: the hand-typed row test plants its own entries, and goes red when `classify()`'s "is not in list" refusal is dropped); drop the reserved-key content refusal → vocabulary test red.
- AC4a: default class `ordinary` instead of `secret` in `field-lists.mjs` → unclassified-row test red.
- AC4b: plant an entry classifying `Security.Encryption.Settings` `AdminPassword` `ordinary` → `npm run build` exits 1; with the pattern check removed → credential-row test red.
- AC4c: evaluate `SSLConfig` without argument 1 (empty `AdminPort.TEMPLATEARGUMENTS`) → `DerivedFields` credential-paths test red, and the committed-equals-derived test red naming `Security.SSLConfig PrivateKeyPassword`.
- AC4d: add a `Password` member to `Security.User`'s evaluated template in `AdminPort.Template` → `DerivedFields` credentials test red naming `Security.User:Password`.
- AC5: drop `Name` from the wallet exclusions → `DerivedFields` KeyValue count red; remove `Lock` from the no-template set → no-template test red; drop `%Wallet.RSA` from `FieldDerive.WALLETTYPES` → class-derived test red on the concrete-subclass assertion.
- AC6: set `Security.Audit.Record`'s `queues` to 0 in the XData → `Inventory` row comparison red.

## Auto Run Result

Status: done
Blocking condition: none

**Implemented.** `AdminPort` resolves and evaluates body templates (`TEMPLATENAMES`, `TEMPLATEARGUMENTS`, `TemplateMethod`, `Template`); `FieldDerive` derives 40 template, 3 wallet, 1 audit-event and 3 `none` lists (451 rows) into the generated `FieldLists.cls` via `scripts/field-lists.sh`; `field-lists.mjs` joins them with `Classification.cls` (committed `{}`) into `ToolFields.cls` and runs in `prebuild`, `prestart` and the pre-commit hook; `AdminInventory` gains `queues` and `mutating`, pinned by `Inventory`.

**Files.** `src/OcuPilot/Port/AdminPort.cls` (template resolution); `src/OcuPilot/Test/AdminInventory.cls`, `Inventory.cls` (new columns, AC6); `src/OcuPilot/Test/FieldDerive.cls` (derivation); `src/OcuPilot/Test/DerivedFields.cls` (AC1, AC2, AC4, AC5); `src/OcuPilot/Test/TemplateFixture*.cls` (four order fixtures); `src/OcuPilot/Screen/Tool/FieldLists.cls`, `ToolFields.cls` (generated), `Classification.cls` (reviewed entries); `scripts/field-lists.sh`; `ui/tools/field-lists.mjs`, `field-lists.test.mjs`, `shell-scripts.test.mjs`; `ui/package.json`, `.githooks/pre-commit`, `CLAUDE.md` (six prebuild checkers).

**Review.** 47 findings (medium 12, low 28, false 7). Patched 10 entries — medium 3 (AC2 order fixtures, inherited-template subject, reserved-key content refusal), low 7 (wrapper scan over every list, wallet `Type` set against the instance, multi-element array error, shapeless-row fixture, emitted `Timeout` row assertion, script exec bit, `ci.yml` comment). Deferred 2 (LanguageServer per-type `Custom`; credential pattern gaps, both need a spine amendment). Rejected rows carry their reason in the triage log; AC4's "no path ending `Password`" sentence contradicts `ChangePassword` and is left for the lead to correct at origin (epics.md already reads `Password`/`NewPassword`).

**Follow-up review recommended: true** (3 medium patched). Unverified risk: the patched AC2, AC4 and AC5 assertions and the reserved-key refusal have had no independent review, and have not yet run in CI's fresh-compile `instance` job — locally an `AdminPort` parameter change reached `PortFixture` only after `PortFixture` was recompiled.

**Verification.** `npm run build` exit 0 (`field-lists: up to date; 47 list(s), 451 row(s)`); `npm test` 651 tool + 199 component tests pass; `check-objectscript.py` 0 problems over 144 files and its harness OK; `lint-docs.sh` clean; `field-lists.sh --container ocupilot` then `field-lists.mjs` left both generated files byte-identical. On `ocupilot-iris`, one class per call: every `OcuPilot.Test` class with test methods green (runs 1325, 1331-1375; `Http` has none). Mutations for the patched pins applied, observed red (runs 1327-1330 and two client runs), reverted with the tree byte-identical.

**Residual risks.** The two deferred items; CI's `instance` job has not run this diff.
