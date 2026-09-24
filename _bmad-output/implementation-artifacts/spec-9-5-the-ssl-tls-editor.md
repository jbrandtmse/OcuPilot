---
title: 'Story 9.5: The SSL/TLS editor'
type: 'feature'
created: '2026-09-24'
status: 'done'
baseline_revision: '10dff8cb931d69c47c151ed1c7839324a4f0916f'
baseline_commit: '10dff8cb931d69c47c151ed1c7839324a4f0916f'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-9-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-9-3-the-role-editor.md'
warnings: ['oversized', 'multiple-goals']
deferred:
  - 'The initial bundle is 1,476,658 bytes (JS + CSS, measured by ui/tools/build-output.test.mjs), over angular.json''s 1467kB maximumWarning and under the 1500kB stop line, so the DW-371 build-output test is red until the budget is re-based (angular.json and angular-json.test.mjs, outside this story''s files).'
  - 'security/ssl/edit carries the three shell-wide structural-baseline entries every form route carries (DW-1583 panel resize handle, DW-1584 status bar connection); the screen''s own checkbox min-width finding was fixed rather than baselined.'
  - 'The browser leg for OcuPilot''s own configuration aborts any write in the browser and never sends a change to it; the server refusal of such a change is pinned by OcuPilot.Test.SslSave over a port that holds the write. A held-port route harness would let the refusal be pinned over the wire.'
  - summary: >-
      An over-255-character private key password confirmed through the agent's security.ssl.update may be quoted into the admin port's log line.
    evidence: |-
      Unverified. The confirm path never runs SslRules' length rule; Security.SSLConfigs.PrivateKeyPassword is Security.Datatype.Password (%Binary, MAXLEN 255), whose 7201 refusal quotes the value, and AdminPort.Fail logs the vendor status. Settle by confirming security.ssl.update on SslSecret's key-file probe with a 300-character sentinel and scanning messages.log. The same confirm path carries security.x509.* passwords, so the root cause predates this story.
    location: >-
      src/OcuPilot/Port/AdminPort.cls Fail; src/OcuPilot/Kernel/Proposal/Confirm.cls Transition
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** SSL/TLS configurations can be listed (`security/ssl`) but not created, edited or tested from OcuPilot. The X.509 list has no Delete row action (DW-1541). A wallet secret cannot be deleted by anyone (DW-1556, FR-46).

**Approach:** Add one tabbed form page at `security/ssl/edit[/<name>]` for both create and edit, following the X.509 form (one page, the mode set by the id). It saves through two new write tools (AD-55): `security.ssl.create` (AD-54) and `security.ssl.update` (merge, AD-4). A screen-only Test connection reports the instance's own result text. The page shows OcuPilot's own provider configuration as OcuPilot's. The two routed deletes use 9.3's delete pattern (AD-53). Also in scope: the three routed build and copy entries (DW-268, DW-332, DW-391).

## Boundaries & Constraints

**Always:**

- **Tabs and fields.** One form spans five tabs. Save applies everything.
  - **General:** Name (create only), Description, Enabled, Type (Client/Server).
  - **Verification:** VerifyPeer, VerifyDepth, CAFile, CAPath, and the `sslCrlDeprecated` caption.
  - **Credentials:** CertificateFile, PrivateKeyFile, PrivateKeyType, PrivateKeyPassword.
  - **Cryptographic settings:** TLSMinVersion, TLSMaxVersion, CipherList, Ciphersuites, DiffieHellmanBits.
  - **OCSP settings:** OCSP, OCSPIssuerCert, OCSPResponseFile, OCSPTimeout, OCSPURL.
- **Settable fields (both tools).** Description, Enabled, Type, VerifyPeer, VerifyDepth, CAFile, TLSMinVersion, TLSMaxVersion, CipherList, Ciphersuites, DiffieHellmanBits, OCSP and OCSPTimeout. The update tool also takes PrivateKeyPassword, a declared secret.
- **Read-only fields.** Everything else is shown read-only and kept by the merge: the file paths CertificateFile, PrivateKeyFile, CAPath, OCSPIssuerCert and OCSPResponseFile, plus PrivateKeyType, OCSPURL and AuthorizeCN. Beside them, `sslFileClassicOnly` names the classic page, as text with no link (AD-21, AD-44).
- **CAFile** takes exactly three values:
  - `""`;
  - `%OSCertificateStore`, the vendor keyword, which names no location;
  - the fresh read's own value, unchanged.

  Any other value is refused `SSL.CAFILE.PATH`.
- **Save order.** Both callers use `UserSave`'s order: pairs → fresh read → undeclared keys → rules → merge or compose → prohibited set → send.
  - **Edit:**
    - A missing name is 404 `SSL.NAME.ABSENT`.
    - Keys outside the settable set are 400 `PORT.FIELD.UNEXPECTED`.
    - The merge sends the complete set. PrivateKeyPassword is added to the payload only after the prohibited set, as `X509Save` does, and only when it is supplied and non-empty.
  - **Create:**
    - The name must be absent, else `SSL.NAME.TAKEN`. It is 1–64 characters, with no control characters, `/` or `\`, else `SSL.NAME.SHAPE`.
    - Type, VerifyPeer and Enabled are required.
    - The page sends the complete set, starting from the form read's `defaults`. The agent's create composes only what it was given.
  - One `ssl-configuration` event follows `created` or `updated`.
- **`SslRules.Validate` checks what the vendor refuses only with a 500** (all measured on `ocupilot-ci`). Each refusal is a field violation:
  - Type is 0 or 1.
  - A server Type needs CertificateFile and PrivateKeyFile in the fresh read (#982). A create is therefore always client.
  - VerifyPeer is 0 or 1 for a client, and 0, 1 or 3 for a server (#725).
  - VerifyPeer above 0 needs a CAFile or CAPath (#986).
  - TLS versions are in {4, 8, 16, 32}, with min ≤ max (#899).
  - DiffieHellmanBits is in {0, 512, 1024, 2048, 4096}.
  - VerifyDepth and OCSPTimeout are whole numbers ≥ 0.
  - OCSP is 0 or 1.
  - Each cipher entry is non-empty, with no `:` or whitespace. The joined lists fit 4096 and 128 characters.
  - Description is at most 256 characters.
  - PrivateKeyPassword needs a PrivateKeyFile in the fresh read (#985).
- **`AdminPort`:**
  - Add `Security.SSLConfig/PUT` to `MUTATINGTYPES`.
  - Map the vendor codes the rules cannot pre-check to field violations, and never carry the vendor text:
    - 726 → `CipherList` `SSL.CIPHERLIST.EXPANDSEMPTY`;
    - 746 → `Ciphersuites` `SSL.CIPHERSUITES.UNKNOWN`;
    - 732 → `PrivateKeyPassword` `SSL.PRIVATEKEYPASSWORD.WRONG`. The 732 text names the key file's path.

    Extend `PROPERTYFAULTS` so an entry may name its field outright.
  - Admit the non-mutating pair `Security.SSLConfig/TEST` (body `{Host, Port}`). It answers `{passed, lines}`:
    - on 2xx, `passed: true`, and `lines` is the vendor's `Info` array;
    - on a vendor status error at HTTP 500, 200 with `passed: false`, and `lines` is each error's `$System.Status.GetErrorText`;
    - 400, 403 and 404 stay ordinary faults.
- **Test connection** is `POST /ssl/:id/test`. It is screen-only, gated by `SslForm`'s pairs, and has no agent tool.
  - Host is 1–255 characters, with no whitespace and no `://` (`SSL.TEST.HOST`). Port is 1–65535 (`SSL.TEST.PORT`).
  - It tests the saved configuration. The lines render as text in a `role="status"` region, and are never screen context or a tool result (AD-11).
- **Key material (AC2).** The form read is built from the vendor `GET`, which never answers PrivateKeyPassword. It is never built from `Security.SSLConfigs.Get`, which does.
  - The password is declared secret in `Classification.cls`, in the list's `secretArguments` and in `SslForm`'s `context.secretFields`.
  - Its diff row is masked (`OPTIONALSECRETS`). The ledger excludes it at write time (AD-41). No `LogFault` or `%Status` carries it (AD-35).
- **OcuPilot's own configuration** is `##class(OcuPilot.Kernel.State.Base).#SSLCONFIG`.
  - The form read answers `ocupilot: true` for it. The page shows `sslOwnRole` above the tabs and draws VerifyPeer, CAFile, Type and Enabled disabled, with the reason `sslRefusalOcuPilot`.
  - `Prohibited` refuses a change to those four on it with `PROHIBITED.OCUPILOTSSL`, whose reason is `OCUPILOTSSLREASON`. This is subject to the lead's AD-10 ruling in Design Notes.
- **Weakening (DW-1207 pattern).** VerifyPeer going from above 0 to 0 on any other configuration is permitted.
  - `Prohibited.WeakensByEffect` gains an `ssl-configuration` branch with effect `SSL.NOPEERCHECK`, so the agent's proposal is minted destructive and names the effect.
  - The page shows `sslEffectNoPeerCheck` under VerifyPeer before Save.
- **Deletes.** Each follows `RoleDelete`: a `SCREENACTIONS "delete"`, a list `rowActions` `delete` (self-protection `""`, since OcuPilot owns no credential or secret, as measured), and the typed-name dialog with a consequence sentence.
  - **X.509:** `X509Delete` gains the action.
  - **Wallet:** a new `security.secrets.delete`. It is action-style, `READTYPE GET` through `WalletPort`, and overrides `SecretArguments` to none.
    - `AdminPort` gains `Wallet.Secret/DELETE` in `MUTATINGTYPES` and `BODYLESSTYPES`. Measured on `ocupilot-ci`: 200, and 404 for an absent or wrong-case name.
    - `Prohibited`'s wallet branch clears the changed fields on a DELETE, as `X509()` does.
- **DW-332.** Add these calls to `check-objectscript.py`'s `DESTRUCTIVE_TEST_RE`, with harness cases:
  - `Security.SSLConfigs` `Create`, `Delete` and `Modify`;
  - `OcuPilot.Install.Fixture` `Create` and `Remove`;
  - `OcuPilot.Test.FixtureFault` `SeedRemovableObjects`, `RemoveSeededObjects` and `Remove`.

  Then arm every class the checker then flags on `OCUPILOT_ALLOW_SSL_CONFIG`: `Demo`, `DemoFaults` and this story's SSL test classes at least. Add each one to the `# classes:` line in `scripts/ci-throwaway.sh` :240, and keep `ui/tools/ci.test.mjs` green.
- **DW-391.** Add `faultAbsentEntityNoList`, "`<name>` is no longer present on this instance.", as a Fixed-strings row beside :265. Use it in `switches.page.ts` :468.
- **Copy and style.**
  - Every new word is a `strings.ts` key plus a Fixed-strings row, appended and marked `[ADDED 2026-09-24 - see the story change log]`. Where `strings.test.mjs` refuses a duplicate value, reuse the existing key (9.3's precedent).
  - Use tokens only and `\uXXXX` escapes, name every input, and allow no overflow. There is no DW-1337 allowance.
  - `SslForm` declares three `suggestedPrompts`.
- **Test key material** is generated at run time inside the throwaway (`openssl` is present there), and deleted by exact path and exact config name.

**Never:**

- An SSL configuration delete tool or row action. It is FR-42's, but not in this story's ACs; see Design Notes.
- A caller-named file path (AD-21), a CRL control, or a PrivateKeyPassword clear.
- An agent tool for Test connection.
- A write to `x509-form.*`, `X509Rules.cls`, `x509-import.browser-spec.mjs` or `classicLinkExemption`. These belong to Story 12.1 or Epic 12.
- Anything but appends in `Api/Error.cls`, `Api/Router.cls`, `screen-outlet.ts`, `strings.ts`, `_components.scss`, Fixed strings and `Classification.cls`.
- A widened `CREDENTIAL_RE`: DW-268 is declined.
- A full browser suite run locally, or a private key in any file.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected | Error |
|---|---|---|---|
| Create client | Create → Name `P95a`, VerifyPeer Require, CAFile OS store | 201; the page is now `security/ssl/edit/P95a` showing "Saved"; `docker exec` reads it back | — |
| Two-field save | Edit `P95a`: Description plus TLSMinVersion 8 | The vendor receives the complete set; ciphers, OCSP and VerifyDepth read back unchanged; exactly one `updated` event | — |
| Server create | Type Server | Nothing is sent | 400 `SSL.TYPE.SERVERFILES` on `Type` |
| Verify without CA | VerifyPeer 1, CAFile `""`, CAPath `""` | Nothing is sent | 400 `SSL.VERIFYPEER.CAREQUIRED` |
| CAFile path | CAFile `/tmp/x.pem` (agent or screen) | Nothing is sent | 400 `SSL.CAFILE.PATH` |
| Bad cipher | Ciphersuites `["BOGUS"]` | Nothing is changed | 400: a violation on `Ciphersuites` (vendor 746, mapped) |
| Key password | Probe server config, with a run-time key file and encrypted key; Save PrivateKeyPassword right, then wrong | Right: 200, the password is stored (read in `%SYS` as set/unset only). Wrong: 400 `SSL.PRIVATEKEYPASSWORD.WRONG`. No form read, diff, ledger row, `^OcuPilot` log row or envelope holds the sentinel | — |
| Own config | Save VerifyPeer 0, or Enabled false, on `OcuPilotProvider` | Nothing is sent. Description or TLSMinVersion alone is 200 | 403 `PROHIBITED.OCUPILOTSSL` |
| Weakening | The agent sets VerifyPeer 0 on a probe | A destructive proposal naming `SSL.NOPEERCHECK` | — |
| Test fails | Test with `localhost`:52773 | 200, `passed: false`, and a line containing "wrong version number" | — |
| Test passes | Test against `openssl s_server` started in the throwaway | 200, `passed: true`; `lines[0]` is "SSL connection succeeded" | — |
| Absent | Form read, Save or Test of a missing name | — | 404 `SSL.NAME.ABSENT` |
| X.509 delete | X.509 list row → Delete → type the alias | Deleted; the list re-reads | — |
| Wallet delete | Secrets list row → Delete; the agent `security.secrets.delete` | Deleted; the agent's proposal is destructive; a no-op is 400 `TOOL.ARGUMENTS` (`REFUSEEMPTY`) | An absent secret is 404 |

</intent-contract>

## Code Map

S = `src/OcuPilot/`, U = `ui/src/app/`. Anchors are at HEAD `f886722f525e52c53e595f89356790c99a450ed8`.

**Vendor (measured on `ocupilot-ci`, 2026-09-24).** `%Api.Admin.Endpoints.Security.SSLConfig` was read through `GetTextAsString`.

- `RunPut` is an upsert and sets only the keys the body defines. A body without PrivateKeyPassword kept it; `""` cleared it.
- `ObjToJson` uses `PutRequestBodySchema(0)`, so the GET never answers the password. `CipherList` and `Ciphersuites` are arrays, and GET `Type` is 0 or 1.
- `TYPETEST`=10 answers `{Info:[]}`. It is synchronous, and bounded at about 10 s for an unroutable host.
- Every class-level refusal answers 500: codes 982, 725, 986, 899, 7205, 726, 746, 985 and 732.
- A principal holding only `%Admin_Secure:U` and `%DB_IRISSYS:R` created, modified and tested a configuration. `/api/admin` has no application roles.
- `Security.SSLConfigs`: `irissys/Security/SSLConfigs.cls` :48-194. The classic page `irissys/%CSP/UI/Portal/SSL.cls` has no tabs; its groups are "This client's credentials", "Cryptographic settings" and "OCSP settings".

**Server:**

- `S/Port/AdminPort.cls`:
  - lists: `MUTATINGTYPES` :248, `BODYLESSTYPES` :264, `TEMPLATEARGUMENTS "Security.SSLConfig:1"` :479, `PROPERTYFAULTS` :2092 and its reader;
  - `Invoke` :665, `EndpointType` :1795, `ImplementsRead` (the endpoint overrides `Run`, so TEST resolves), `Fail`/`LogFault`.
- `S/Port/WalletPort.cls` :45 handles GET only; a DELETE falls through to `AdminPort`.
- `S/Screen/Tool/`:
  - The templates are `X509Import.cls` (`COMPOSEDSECRETS`/`OPTIONALSECRETS` :44-49, `CREATES`) and `X509Update.cls` (`SecretArguments` :70).
  - `RoleDelete.cls`: `SCREENACTIONS` :45, `ScreenActionDelta` :120-129.
  - `X509Delete.cls` :22-81 has no `SCREENACTIONS`. `WalletSecretUpdate.cls` :24-47.
  - `Write.cls` parameters :38-201. `ScreenActionDelta` :537. The `Consequence` hook is `WebAppUpdate.cls` :191.
  - `Classification.cls`: new SSL entries go after :323, beside `security.x509.*` at :296/:312. Regenerate `ToolFields.cls` with `cd ui && node tools/field-lists.mjs`. `FieldLists.cls` :323-348 already holds the 24-row SSL template list.
- `S/Area/Security/`: `X509Save.cls` (`Create` :120-165, `HandleUpdate` :89, `CallerFields` :284) and `X509Rules.cls` (`HandleForm` :199, `HandleName` :251) are the templates.
- `S/Api/Router.cls`:
  - The X.509 routes are at :115-118; append an SSL block at the tail (:148) in the order `/ssl/form`, `/ssl/name`, `/ssl/:id/test`, `PUT /ssl/:id`, `POST /ssl`.
  - The agent test-route precedent is `Definitions.HandleTest` :769.
- `S/Kernel/Proposal/Prohibited.cls`:
  - `COVEREDTYPES` :233, `OCUPILOTROLE`/`OCUPILOTROLEREASON` :196/:215, `ReasonFor` :374, `PermittedChangeFields` :468 (and the create lists after it), `Prohibits` :618.
  - The wallet branch is :682. `X509()` :1298 is the DELETE-clearing template. `WeakensByEffect` :942 and its `EFFECT*` constants :131-135.
- `S/Kernel/Proposal/Mint.cls` :303-322 holds destructive and consequence. `S/Kernel/State/Base.cls` :95 is `SSLCONFIG`.
- `S/Install/Installer.cls`: `EnsureSslConfiguration` :2890-2935 re-asserts VerifyPeer, CAFile, Type and Enabled at every start (:2908-2931).
- `S/Screen/Descriptor/`:
  - `SslConfigList.cls`: primaryAction :49, `emptyNextKey` :70, doc :17-18 and :27-28.
  - `X509CredentialList.cls` `rowActions` :55 (doc :29). `WalletSecretList.cls` `rowActions` :48.
  - `X509Form.cls` and `RoleForm.cls` :43-47 are the form templates.
- `S/Api/Error.cls` (2,426 lines): append an SSL block. Violation reasons live here (AD-39). Only `OCUPILOTSSLREASON` is published in Fixed strings.
- `scripts/check-objectscript.py`: `DESTRUCTIVE_TEST_RE` :1332-1345, `check_destructive_test_guard` :1398. Harness: `scripts/test_check_objectscript.py` :1753.
  - `Test/Demo.cls` :109/:131 and `Test/DemoFaults.cls` :42-98 are unarmed.
  - `Install/Fixture.cls` :321-338 (`CreateSslConfig`) and :806 (`DeleteSslConfig`); `Test/FixtureFault.cls` :174/:244.
- `scripts/ci-throwaway.sh` :236-241 (the SSL_CONFIG roster). Epic 11 adds lines near :197 and :276: expect an adjacent-text merge. `ui/tools/ci.test.mjs` :1855.

**Rosters a new tool, route, row action or screen trips:**

- `Test/SecurityLists.cls` :160-163 (primary action and zero row actions, per class);
- `Test/SurfaceCoverage.cls` (screen :87/:103, tools :113-117);
- `Test/ReadTool.cls` :93-94 (count 83 and the name list);
- `Test/ToolRoundTrip.cls` :35 `REFUSEEMPTY`;
- `Test/EndpointCoverage.cls` :144-151;
- `Test/Wire.cls` :577 and `Test/WireSecurityRead.cls` :787/:903/:931 (the security routes);
- `Test/Prohibited.cls` :217;
- `Test/Descriptor.cls` :478 and `Test/ScreenReadWire.cls` :214 (key-material names on the SSL list; `secretArguments` gains PrivateKeyPassword);
- `ui/tools/navigation.test.mjs` :238-242 (asserts SSL has no editor; flip it) and :260-289 (the per-editor template);
- `ui/tools/field-lists.test.mjs` :246.

**Client:**

- `U/areas/security/x509-form.page.ts`/`.store.ts` are the one-page create/edit template:
  - `routeId` :591;
  - `open` :336, mode by id;
  - `onSave` :560-574, `retainAcrossRouteReplacement` then `navigateByUrl`, with `replaceUrl`.
- `x509-actions.ts` :31 registers Create and is injected at `U/app.ts` :254.
- The tabs follow `web-app-editor.page.ts`: :193-503 template, :561 selection, :657 tab list, :923 `focusField`, :996 `tabToOpen`. The store's tab maps are :22-28 and :104-108.
- `U/core/form-tabs.ts` (`tabErrorCounts` :30, `tabToOpen` :45) and `U/shell/form-tabs.ts` (`FormTabs` :53, `FormTabBody` :27).
- `U/shell/screen-outlet.ts`: `DESCRIPTOR_PAGES` :98 (X.509 at :111). `SslForm` goes here, not in `DESCRIPTOR_EDIT_PAGES`.
- `U/shell/screen-action-handler.ts`: `SCREEN_ACTION_DESCRIPTORS` :41-56, `DESTRUCTIVE_CONSEQUENCES` :187-199, `TYPED_NAME_ROWS` :233. X.509 types `Alias`.
- The agent test result precedent: `definition-form.page.ts` :336-339.
- `U/areas/agent/switches.page.ts` :179-181 and :467-468; spec :296-316.
- `U/core/strings.ts`: `} as const;` at :1835, `faultAbsentEntity` :83, `sslListLabel` :354.
- EXPERIENCE.md: SSL rows :135-136, the "Or ask the agent" example :315, `faultAbsentEntity` :265, the last Fixed-strings row :482.
- Browser: `ssl.browser-spec.mjs` (list), `wallet-secret.browser-spec.mjs`, `roles-editor.browser-spec.mjs` (the template). `structural-walk.mjs` walks `SslForm` at its bare route automatically.

## Tasks & Acceptance

**Execution:**

Server:

- `S/Port/AdminPort.cls`:
  - add `Security.SSLConfig/PUT`, and `Wallet.Secret/DELETE` (also in `BODYLESSTYPES`), to `MUTATINGTYPES`;
  - add the `Security.SSLConfig/TEST` pair and its `{passed, lines}` answer;
  - add the three code→field fault entries.

  Update the class-list doc paragraphs and `Test/AdminInventory` if it rosters them.
- `S/Screen/Tool/SslCreate.cls` (new): `security.ssl.create`, `CREATES 1`, `DESCRIPTORCLASS` SslConfigList, the pairs as the list's, and `ArgumentProblem` → `SslRules.Validate` (create). `SecretArguments` is none.
- `S/Screen/Tool/SslUpdate.cls` (new): `security.ssl.update`, a merge. `OPTIONALSECRETS "PrivateKeyPassword"`. `ArgumentProblem` is a fresh read, then `SslRules.Validate` (update). `Consequence` covers `SSL.NOPEERCHECK`.
- `S/Screen/Tool/WalletSecretDelete.cls` (new): as in Boundaries. `FINGERPRINTSUBJECT "Type"` and `PRECONDITIONFIELD Type`, `DESTRUCTIVE 1`, `SCREENACTIONS "delete"`.
- `S/Screen/Tool/X509Delete.cls`: `SCREENACTIONS "delete"`.
- Classification entries for both SSL tools and the wallet delete:
  - PrivateKeyPassword is secret; every other derived field is ordinary; the authored `required` and descriptions.
  - Then regenerate `ToolFields.cls`.
- `S/Area/Security/SslRules.cls` (new):
  - `Validate(mode, args, fresh, .violations)`.
  - `HandleForm`: `{requiredFields, maxLengths, rules, defaults}`. The defaults are the vendor's own initial values, read from a `Security.SSLConfigs` `%New()` in `%SYS`. With `?name=` it adds `configuration` (the 21 non-secret GET keys) and `ocupilot`.
  - `HandleName` and `HandleTest`.
- `S/Area/Security/SslSave.cls` (new): `HandleCreate` and `HandleUpdate` in the Save order.
- `S/Api/Router.cls`: the SSL routes block and its thin wrappers.
- `S/Api/Error.cls`: the `SSL.*` codes and reasons, plus the `PROHIBITED.OCUPILOTSSL` code.
- `S/Kernel/Proposal/Prohibited.cls`:
  - `TYPESSL`, and `ssl-configuration` in `COVEREDTYPES`;
  - the permitted change and create fields;
  - an `Ssl()` own-config arm;
  - `OCUPILOTSSL` and `OCUPILOTSSLREASON` in `ReasonFor`;
  - the `WeakensByEffect` branch with `EFFECTNOPEERCHECK`;
  - the wallet DELETE clearing.
- `S/Screen/Descriptor/SslForm.cls` (new):
  - `security/ssl/edit`, `form-page`, `sideBarPosition` 0;
  - the list's pairs, `entityType ssl-configuration`, `classicPage %CSP.UI.Portal.SSL`;
  - `secretFields ["PrivateKeyPassword"]` and three prompts.
- `S/Screen/Descriptor/SslConfigList.cls`: `primaryAction` `create`, `secretArguments ["PrivateKeyPassword"]`, `emptyNextKey ""`, `emptyAgentKey sslListEmptyAgent`, and a corrected doc.
- `X509CredentialList.cls` and `WalletSecretList.cls`: `rowActions` `[{"id":"delete","selfProtection":""}]`, with docs updated. Then regenerate `screens.generated.ts`.
- `scripts/check-objectscript.py` and `scripts/test_check_objectscript.py`: the DW-332 patterns and cases. Arm and roster as in Boundaries.

Server tests (each armed on `OCUPILOT_ALLOW_SSL_CONFIG` where it creates a configuration):

- `Test/SslSave.cls` (new): the matrix rows Create client through Own config, Absent, and the `configuration` key set, which is exact and holds no PrivateKeyPassword.
- `Test/SslSecret.cls` (new): the Key password row. Model the leak scan on `X509SecretProbe`/`X509LogPort`.
- `Test/SslTest.cls` (new): Test fails, Absent, and the host/port violations.
- `Test/SslUpdate.cls` (new):
  - the schema;
  - the agent create's absence fingerprint;
  - Weakening (destructive);
  - the no-op 400;
  - own config at mint.
- `Test/WalletSecretDelete.cls` (new): the screen and agent legs, and the 404.
- `Test/X509Delete.cls`: a screen-action leg.
- `Test/RefusalCopy.cls`: an `OCUPILOTSSLREASON` leg.
- The rosters listed in the Code Map, with names read from the instance.

Client:

- `U/areas/security/ssl-form.page.ts` and `ssl-form.store.ts` (new), each with a `.spec.ts`.
  - They load `GET /ssl/form[?name=]` and `POST`/`PUT`, with the five tabs, the summary and tab error dot, "Saved", `FormDirty`, and a re-read on `ssl-configuration` events.
  - The own-config caption and disabled fields.
  - The CAFile select: None, the OS store, and the current value.
  - The write-only password.
  - The `sslEffectNoPeerCheck` line.
  - The Test connection panel (Host, Port, button, a result list with a passed/failed heading), shown in edit mode only.
- `U/areas/security/ssl-actions.ts` (new): Create registration, injected in `app.ts`. `screen-outlet.ts`: `SslForm: SslFormPage`. `navigation.test.mjs`: the SSL editor block.
- `screen-action-handler.ts`:
  - `X509CredentialList` and `WalletSecretList` in `SCREEN_ACTION_DESCRIPTORS`;
  - their `delete` in `DESTRUCTIVE_CONSEQUENCES` (`x509DeleteConsequence`, `walletSecretDeleteConsequence`);
  - X.509 → `Alias` in `TYPED_NAME_ROWS`.
- `self-protection.test.mjs`: pair `OCUPILOTSSLREASON` ↔ `sslRefusalOcuPilot` and its Fixed-strings row.
- `switches.page.ts` and its spec: `faultAbsentEntityNoList`.
- `strings.ts` and EXPERIENCE.md Fixed strings (appends):
  - tab labels "Verification", "Credentials", "Cryptographic settings", "OCSP settings";
  - `sslOwnRole`: "OcuPilot's agent makes every call to its model provider through this configuration. OcuPilot's installer sets its type, peer verification, trusted certificates and whether it is enabled, and restores them at every start.";
  - `sslRefusalOcuPilot`: "OcuPilot's installer sets this setting of its own provider configuration and restores it at every start, so it cannot be changed here.";
  - `sslFileClassicOnly`: "File locations are set on the classic portal's SSL/TLS Configuration page.";
  - `sslCrlDeprecated`: "Certificate revocation lists are deprecated on this instance and are not set on a configuration.";
  - `sslEffectNoPeerCheck`: "The server's certificate will no longer be checked, so a connection can reach an impostor.";
  - `sslTestRun` "Test connection", `sslTestPassed` "The instance connected.", `sslTestFailed` "The instance could not connect.";
  - `sslListEmptyAgent`: "create an SSL/TLS configuration for outbound HTTPS";
  - `x509DeleteConsequence`: "Anything that names this credential can no longer use it. This cannot be undone.";
  - `walletSecretDeleteConsequence`: "Anything that reads this secret by name can no longer find it. This cannot be undone.";
  - `faultAbsentEntityNoList`;
  - the field labels and three prompts.
- Browser:
  - `ui/browser/ssl-editor.browser-spec.mjs` (new):
    - the name cell opens five tabs;
    - Create client lands on "Saved";
    - two-field Save reads back through `docker exec`;
    - the own config shows its caption, disabled fields and refusal;
    - the tab error dot and leave guard;
    - Test fails, then passes against `openssl s_server` with run-time key material, removed afterwards;
    - the visual gate at 1440x900.
  - `ui/browser/security-deletes.browser-spec.mjs` (new): the X.509 and wallet row deletes through the typed-name dialog.
  - `ssl.browser-spec.mjs`: the list's Create and empty-state lines.

- SSL delete (orchestrator ruling 2026-09-24, FR-42's delete had no owner; epics.md 9.5 amended):
  - `security.ssl.delete` (new, destructive action write on `Security.SSLConfig` DELETE, measured on `ocupilot-ci` first), with its refusal inside `ScreenActionDelta` as 9.3's delete tools do; `rowActions` Delete on the SSL list through AD-53's route and the typed-name dialog.
  - Deleting `OcuPilotProvider` is refused `PROHIBITED.OCUPILOTSSL` on both callers (AD-10's own-SSL arm covers delete as well as the four fields); a test reddens when that refusal is removed.
  - Browser: the SSL list's Delete leg in `security-deletes.browser-spec.mjs` (a probe config deleted through the typed-name dialog; `OcuPilotProvider`'s Delete drawn refused).
- Test connection (AD-39's named exception, spine amended 2026-09-24): the result lines reach the screen only. Add a test that fails if a failure's `%Status` text reaches a tool result, the model, a ledger row, an audit payload or a log line (there is no agent tool for Test; assert the route's text is absent from every server-side sink it could reach).

**Acceptance Criteria:**

- **AC1.** Given the editor, when it opens, then its tabs cover certificates and key (Credentials), CA and peer verification (Verification), protocol minimum and maximum, ciphers and DH bits (Cryptographic settings), and OCSP (OCSP settings). Each value is read from the instance. A file location is shown and never settable, and the Verification tab states that a CRL is not set on a configuration.
- **AC2.** Given a private key password entered in the form or the agent's confirm, when any read is made afterwards, then it is never returned, and it appears in no diff (masked), ledger row, log line or envelope.
- **AC3.** Given `OcuPilotProvider`, when it is opened, then `sslOwnRole` is visible, and Description and the cryptographic and OCSP fields save. A change to VerifyPeer, CAFile, Type or Enabled is drawn disabled before a click and refused after one with the same published sentence.
- **AC4.** Given a saved configuration, when the user runs Test connection, then the instance's own lines are shown under "The instance connected." or "The instance could not connect.".
- **AC5.** Given the SSL list, when Create is chosen and a client configuration saved, then it exists on the instance and the page is its editor showing "Saved". A two-field Save preserves every other field.
- **AC6 (DW-1541, DW-1556).** Given the X.509 list or the Secrets list, when Delete is chosen and the name typed, then the object is deleted through AD-53's route and the list re-reads. The agent's `security.secrets.delete` is destructive.
- **AC7 (DW-332).** Given a test class calling `Security.SSLConfigs` Create or Delete, or the fixture helpers, with no arming refusal, when `check-objectscript.py` runs, then it fails naming the class. `Demo` and `DemoFaults` are armed and rostered.
- **AC8 (DW-391).** Given a Switches hold whose user no longer resolves, when it renders, then it reads `faultAbsentEntityNoList`, which is published.
- **AC9 (SSL delete).** Given the SSL list, when Delete is chosen and the name typed, then the configuration is deleted through AD-53's route and the list re-reads; `OcuPilotProvider` is refused on both callers under AD-10; the agent's `security.ssl.delete` is destructive.
- **Integration.** `SslFormPage` consumes `form-tabs`, the Save routes and the test route. A refused Save on an unselected tab opens it with its dot, and a created configuration is reached through the list's name cell. The browser spec observes both.

## Spec Change Log

- 2026-09-24 spec gate (lead): orchestrator rulings (a) on all three questions - AD-39 gains the Test-connection named exception (spine amended); AC1's CRL is a caption (epics.md amended); SSL delete added to this story (epics.md amended; Tasks, AC9). AD-10's `PROHIBITED.OCUPILOTSSL` and AD-21's SSL file-field clause were accepted as applied.

## Review Triage Log

### 2026-09-24 — Review pass

- verdicts: 27 findings — high 0, medium 5, low 16, false 5, maybe-false 1
- findings:
  - `[medium]` `[patch]` VG1: `app.spec.ts`'s user-change teardown list has no `SslForm` leg, so dropping `this.sslForm.reset()` from `app.ts` leaves a typed private key password to the next user with every test green — add the leg with its mutation line. Patched: `app.spec.ts` SslForm teardown leg (mutation recorded).
  - `[medium]` `[patch]` VG2: the page's re-read on an `ssl-configuration` change event (`ssl-form.page.ts` subscription, `store.refresh()`) has no test; sibling stores test `refresh()` — add a store `refresh` block (clean form re-reads; dirty form keeps typed values and updates read-only fields). Patched: two `refresh` tests in the store spec and a ChangeBus re-read test in the page spec (mutations recorded).
  - `[medium]` `[patch]` VG3: `SslUpdate.DerivedFields` (drop an empty optional password at confirm, which would otherwise clear the stored one) and the screen's `If tPassword '= ""` guard have no test — add an `SslSecret` leg confirming and saving with `PrivateKeyPassword: ""` and asserting the password stays set. Patched: `SslSecret.TestAnEmptyOptionalPasswordLeavesTheStoredOneSet`, agent and screen legs (mutations recorded).
  - `[medium]` `[patch]` VG4: no test calls the five `/ssl` routes as a real principal lacking `%Admin_Secure:USE` or `%DB_IRISSYS:READ`; deleting the `Gate` call from `HandleTest` reddens nothing — add `OcuPilot.Test.SslWire` on `WalletWire`'s pattern. Patched: new `OcuPilot.Test.SslWire`, armed on `OCUPILOT_ALLOW_PRINCIPALS` and `OCUPILOT_ALLOW_SSL_CONFIG`, rostered in both `ci-throwaway.sh` blocks (mutation recorded).
  - `[low]` `[patch]` VG5: `GET /ssl/name`'s `taken` answer is never asserted — assert `taken` true with the `SSL.NAME.TAKEN` sentence for a held name and false for an absent one in `SslSave`'s wire test. Patched: `SslSave`'s wire test asserts `taken` both ways (mutation recorded).
  - `[medium]` `[patch]` VG6: the CAFile select's third option (the file the configuration already names) is untested; dropping the `options.push` shows "None" for a configuration trusting a file (AC1) — add a page-spec case. Patched: page-spec case for a held CA file (mutation recorded).
  - `[low]` `[patch]` VG7 (Rule 19): `ssl-form.store.spec.ts` AC3 sets `Type` to its held value `'0'`, which `setText` ignores, so the lock leg cannot fail — set `'1'`. Patched: each locked field is set to a value it does not hold (mutation recorded).
  - `[low]` `[reject]` VG8 (Rule 19): the X.509 `TYPED_NAME_ROWS` entry is behaviourally equal to the row-key fallback, so its leg cannot fail on its removal — the entry is a spec Task and harmless; pinning an equivalence adds nothing a user meets.
  - `[low]` `[reject]` VG9 (Rule 19): `ssl-editor.browser-spec.mjs` AC1's VerifyPeer, TLSMinVersion and OCSP values equal the defaults — the Description assertion discriminates in the browser and the component spec pins the configuration read through `CertificateFile` and `PrivateKeyType`.
  - `[low]` `[reject]` VG10: two client mutations are recorded as spec-file comments rather than `## Verification` lines — every AC already carries at least one `mutation:` line there.
  - `[low]` `[reject]` VG11: `AdminPort.TestOutcome` renders any vendor 500 on TEST as `passed: false`, ahead of the DW-274 denial mapping — unreachable behind `SslRules.Gate`, whose pairs the vendor was measured to accept; an internal failure's text on screen is AD-39's named exception.
  - `[maybe-false]` `[defer]` VG12: an over-255-character private key password confirmed through the agent skips `SslRules`' length rule, and the vendor's `%Binary` MAXLEN refusal (7201) may quote it into `AdminPort.Fail`'s log line — settle by confirming `security.ssl.update` on `SslSecret`'s key-file probe with a 300-character sentinel and scanning `messages.log`; the same confirm path serves `security.x509.*`'s password, so the root cause predates this story.
  - `[low]` `[reject]` VG13: the CAFile rule's "fresh read's own value, unchanged" arm is unreachable through `Changed()` — it is the spec's third value, harmless, and reachable to any future caller of `Validate`.
  - `[low]` `[reject]` IA1: rule refusals answer 422 `SSL.VALIDATION` on the screen and 400 `TOOL.ARGUMENTS` for the agent, where the matrix writes 400 `SSL.*` — the Boundaries bind `UserSave`'s order, which renders 422, as `X509Save`, `WalletSave` and `ResourceSave` do; the only fix is to edit this spec's matrix.
  - `[low]` `[reject]` IA2: the own-configuration 403 is asserted over a held port, and its 200 benign edit never over the wire — already in `deferred:`; the prohibition on changing `OcuPilotProvider` forbids a wire test whose mutation would write it.
  - `[low]` `[reject]` IA3: a passing Test is pinned only in the browser, with `lines.some(...)` rather than `lines[0]` — the browser leg is the real-runtime pin and still requires the instance's own success line.
  - `[low]` `[reject]` IA4: the browser Create leaves VerifyPeer at its default — VerifyPeer 1 with the OS store is created over `POST /ssl` in `SslSave` and the select is pinned in the component spec.
  - `[false]` `[reject]` IA5: the one `updated` event is client-side — AD-14 publishes it from the client, and `ssl-form.store.spec.ts` asserts exactly one.
  - `[low]` `[reject]` IA6: `SslSave.Create` checks the name's shape before its fresh read — a malformed name cannot be read, and the rules still run after the undeclared-key check; `Update`'s rules over the changed fields read against the fresh read, which is the merge's input.
  - `[false]` `[reject]` IA7: mid-file insertions in `Error.cls`, `Router.cls`, `Classification.cls` and `screen-outlet.ts` — each is an addition at the tail of its own block (the dispatch list, the UrlMap, the entries, the imports) and deletes no line, as 9.3 did.
  - `[low]` `[reject]` IA8: DW-391's row is appended at the table's end, not beside :265 — the spec also orders every new row appended, and appending keeps the pinned `EXPERIENCE.md:<n>` references stable.
  - `[false]` `[reject]` IA9: a second `# classes:` line in `ci-throwaway.sh` — the stage's binding is "append your roster lines only", and `ci.test.mjs` reads both lines.
  - `[low]` `[reject]` IA10: three shell-wide overflow rows (DW-1583, DW-1584) for `security/ssl/edit` in `structural-baseline.json` — every form route at HEAD carries the same three, including 9.3's; the screen's own controls pass the gate unbaselined. Flagged to the lead.
  - `[low]` `[reject]` IA11: an absent wallet secret is refused 400 at the agent's mint rather than 404 — the mint reads first and reports the absent target as its problem, as every Epic 8/9 delete tool does.
  - `[false]` `[reject]` IA12: failed-test lines come from `DecomposeStatus` — it yields each error's `GetErrorText`, the same text.
  - `[false]` `[reject]` IA13: the leak scans read `messages.log` rather than a `^OcuPilot` global — `Kernel.Audit.Log` writes OcuPilot's log lines there.
  - `[low]` `[reject]` IA14: the bundle is over the 1467kB warning — outside the intent and already in `deferred:` for the lead (DW-1166).

## Design Notes

**Governing ADs:**

- AD-2, AD-3 (SSLConfig PrivateKeyPassword via template argument 1), AD-4, AD-5, AD-6, AD-8, AD-10, AD-11, AD-13, AD-14;
- AD-21 (no caller path);
- AD-27 (the port change is inside the port, not a fallback);
- AD-29 (measured least-privileged), AD-32, AD-35, AD-36, AD-39, AD-41, AD-44;
- AD-51, AD-52, AD-53, AD-54, AD-55, AD-56.

**Lead rulings requested (Rule 20; ask-first where it narrows):**

1. **AD-10, own provider configuration (recommended).** The installer re-asserts VerifyPeer, CAFile, Type and Enabled at every start, so an edit to them silently reverts. VerifyPeer 0 would also send the provider key over unverified TLS, which AD-32 exists to prevent. Append to AD-10's fifth bullet:

   > "…; **or changing the type, peer verification, trusted certificates or enablement of OcuPilot's own provider SSL/TLS configuration** (`VerifyPeer`, `CAFile`, `Type`, `Enabled`), refused `PROHIBITED.OCUPILOTSSL`, because the installer sets them for AD-32 and restores them at every start; every other field of it stays editable [AMENDED 2026-09-24, Story 9.5 spec gate]."

   If the lead declines, drop the arm: the four become editable and a consequence line states the restore. VerifyPeer 0 is then minted destructive like any other configuration.
2. **AD-39, Test connection text (required by AC4).** Append:

   > "One named exception: an SSL/TLS configuration's Test connection answers the instance's own result lines — the vendor's `Info` on success, each `%Status` error text on failure — because that text is the result the operator asked for (Story 9.5). It reaches the screen only, as text, and never the model or a log."
3. **AD-21, clarification (recommended).** Append to its "Any other location" sentence:

   > "An SSL/TLS configuration's file fields are such locations: shown, never set; `CAFile`'s vendor keyword `%OSCertificateStore` names none."
4. **AC1's "CRL" (Rule 5, the lead's call).** `CRLFile` is `[Deprecated, Internal]`. It is absent from the template and from the GET, so no reachable outcome shows or sets it. The recommended restatement is the AC1 text above.
5. **SSL delete.** FR-42 lists delete, but no 9.5 AC does, and no story owns it (inference: grep). Route it to Story 9.9 or the range-end cleanup. Deleting `OcuPilotProvider` would then take the AD-10 arm in (1).

**Choices stated:**

- **Weakening** is permitted, confirmed, and names its consequence (DW-1207).
- **Test connection** is screen-only. A model-issued outbound connection to any host is the egress AD-42 guards.
- **A server configuration can only be edited here, never created.** The vendor needs a certificate and a key file for it (#982), and those are classic-portal paths.

**Ledger inbox:**

- **DW-268, declined.** The GET carries no key material (measured). PrivateKeyFile, CertificateFile, CAFile and CAPath are locations, and PrivateKeyType is an algorithm. The one secret, PrivateKeyPassword, already matches `…password`. Widening would reclassify public fields and move the pinned three-way list (`Log.cls`, `credential-pattern.mjs`, the spine) with no gain. AC2's tests pin the real surface.
- **DW-332, addressed.** The entry's three classes are stale: `Installer` and `UninstallGuard` are armed. `Demo` and `DemoFaults` are the unarmed ones.
- **DW-391, addressed.** DW-1541 and DW-1556 are addressed.
- DW-1597 is not this story's.

**Contention and footprint:**

- `origin/OCU-1-epic12` carries planning only, and 12.1 plans `x509-form.*`, `X509Rules` and `x509-import.browser-spec.mjs`, which this story avoids.
- `origin/OCU-1-epic11` touches none of the contended files, except two lines in `ci-throwaway.sh`.
- `footprint_extensions`: `ui/src/app/areas/agent/switches.page.ts`(+spec), `ui/src/app/app.ts`, `scripts/ci-throwaway.sh`, and `Kernel/Proposal/Prohibited.cls` (contended).

**Bundle.** 9.3 added about 31 kB. This page is larger (five tabs, create and edit, the test panel), estimated at 35–45 kB. That puts the initial total near 1.46–1.47 MB: at or just over the 1467kB warning, and under the 1500kB line (inference; measure after build). If it crosses the warning, leave `angular.json` unchanged and report the figure, since raising the budget or lazy loading is the owner's call.

**Integration ACs:**

- **Consumes:** 8.5's one-page form and secret-body pattern, 9.1–9.3's `form-tabs`, the Save order and `REFUSEEMPTY`, 9.3's delete pattern, 8.6's `WalletPort`, and Epic 7's AD-53 route and typed-name dialog.
- **Consumed-by:** Story 12.x/16.x editors may reuse the `{passed, lines}` test answer (inference). None is named.

## Verification

Slot A. Every IRIS MCP call carries `server: "ocupilot-slot-a"`. Anything that creates or changes a configuration runs on `ocupilot-ci` only. Run one test class per call.

**Commands:**

- `(loop)` `cd ui && node --test tools/navigation.test.mjs tools/strings.test.mjs tools/screen-mirror.test.mjs tools/field-lists.test.mjs tools/self-protection.test.mjs tools/ci.test.mjs tools/angular-json.test.mjs tools/credential-lists.test.mjs`. Expected: green.
- `(loop)` `cd ui && npm run test:components`. Expected: green, including `ssl-form.*`, `screen-action-handler`, `switches.page` and `data-table`.
- `(loop)` `uv run scripts/test_check_objectscript.py && uv run scripts/check-objectscript.py && bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<X>`, one at a time, for X in:
  - SslSave, SslSecret, SslTest, SslUpdate;
  - WalletSecretDelete, X509Delete, WalletSecretUpdate;
  - Demo, DemoFaults;
  - SecurityLists, Prohibited, ProhibitedByEffect, RefusalCopy;
  - SurfaceCoverage, EndpointCoverage, ReadTool, ToolRoundTrip;
  - Wire, WireSecurityRead, Descriptor, ScreenReadWire, DerivedFields, AdminInventory.

  Expected: 0 failures each.
- `(loop)` Build and deploy: `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`.
  - Then run each file alone with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/<f>`, over:
    - ssl-editor, security-deletes, ssl, wallet-secret, security;
    - the switches spec (the file that opens `agent/switches`);
    - users-actions, roles-editor, resources-editor, oauth-delete, audit-events;
    - a11y-structural-invariants.
  - Expected: green.
- `(once, before dev_complete)` `node ui/tools/ci-runner.mjs --container ocupilot-ci --package OcuPilot.Test`. Expected: 0 new failures. The full browser suite is CI's.

**Mutations (Rule 19; the pass that adds each pinning test writes its line):**

- AC1: drop the Credentials tab.
- AC2: build the form read from `Security.SSLConfigs.Get`.
- AC3: delete the `Ssl()` arm, and separately drop the disabled binding.
- AC4: return the `Fail` envelope for TEST.
- AC5: merge over `{Name}`.
- AC6: drop `SCREENACTIONS` from each delete tool.
- AC7: remove the SSLConfigs alternative from `DESTRUCTIVE_TEST_RE`.
- AC8: revert `switches.page.ts` to `faultAbsentEntity`.
- Integration: skip `tabToOpen`.

**Mutations observed (implement pass; each reverted, file byte-identical by sha256):**

- mutation: drop the Credentials tab from `SslFormPage`'s tab list → `ssl-form.page.spec.ts` AC1 (and two dependent legs) went red; in the browser, `ssl-editor.browser-spec.mjs` AC1 went red.
- mutation: build the form read's `configuration` from `Security.SSLConfigs.Get` in `SslRules.Configuration` → `OcuPilot.Test.SslSave.TestTheCreateAndTheFormReadAnswerOverTheWire` went red.
- mutation: skip the `Ssl()` arm in `Prohibited.Prohibits` → `OcuPilot.Test.SslSave` own-configuration change and delete legs (and the two-field Save) went red; every write went to a held or fixture port and OcuPilotProvider read back unchanged.
- mutation: drop the delete from `Prohibited.Ssl` (`Set tMoves = 0`) → `OcuPilot.Test.SslSave.TestOcuPilotsOwnConfigurationsDeleteIsRefusedOnBothCallers` went red on both callers' legs.
- mutation: drop the `[disabled]` binding on the peer verification select → `ssl-form.page.spec.ts` AC3 went red; in the browser, `ssl-editor.browser-spec.mjs` AC3 went red.
- mutation: answer the `Fail` envelope for a failed TEST in `AdminPort.TestOutcome` → `OcuPilot.Test.SslTest.TestAFailedTestAnswersTheInstancesOwnLines` went red.
- mutation: log the vendor status in `AdminPort.TestOutcome`'s failure branch → `OcuPilot.Test.SslTest.TestAAFailuresTextReachesNoToolLogAuditOrLedger` went red on its `messages.log` leg (observed twice).
- mutation: merge over `{Name}` in `SslSave.Update` → `OcuPilot.Test.SslSave.TestATwoFieldSaveSendsTheCompleteSetAndTheRestSurvives` went red.
- mutation: drop `SCREENACTIONS` from `X509Delete` → `OcuPilot.Test.X509Delete.TestTheListsDeleteReachesTheSameWrite` went red; from `WalletSecretDelete` → `OcuPilot.Test.WalletSecretDelete` declaration and screen legs went red; from `SslDelete` → `OcuPilot.Test.SslSave.TestOcuPilotsOwnConfigurationsDeleteIsRefusedOnBothCallers` (the probe's Delete) went red.
- mutation: remove the `Security.SSLConfigs` alternative from `DESTRUCTIVE_TEST_RE` → `test_check_objectscript.py` "the SSL configuration calls and fixture helpers are in the population" went red on Create, Delete and Modify.
- mutation: remove `SslTest` from the `OCUPILOT_ALLOW_SSL_CONFIG` roster in `ci-throwaway.sh` → `ci.test.mjs` DW-1276 went red.
- mutation: revert `switches.page.ts` to `faultAbsentEntity` → `switches.page.spec.ts` AD-37 absent-user leg went red.
- mutation: never select the tab `tabToOpen` answers in `SslFormPage.afterRefusal` → `ssl-form.page.spec.ts` Integration went red; in the browser, `ssl-editor.browser-spec.mjs`'s refusal-on-General leg went red.
- mutation: drop the `SslActions` injection from `app.ts` → `ssl.browser-spec.mjs` Story 9.5 and `ssl-editor.browser-spec.mjs` AC5 Create went red.
- mutation: set `SslCreate.CREATES` to 0 → `OcuPilot.Test.SslUpdate.TestTheCreateFingerprintsTheNamesAbsence` went red.
- mutation: drop the SSL branch of `Prohibited.WeakensByEffect` → `OcuPilot.Test.SslUpdate.TestTurningPeerVerificationOffIsMintedDestructive` went red.
- mutation: drop the no-op refusal from `SslUpdate.ArgumentProblem` → `OcuPilot.Test.SslUpdate.TestANoOpIsRefusedAtTheMint` went red.
- mutation: drop the own-configuration check from `SslUpdate.ArgumentProblem` → `OcuPilot.Test.SslUpdate.TestOcuPilotsOwnConfigurationIsRefusedAtTheMint` went red.
- mutation: set `WalletSecretDelete.DESTRUCTIVE` to 0 → `OcuPilot.Test.WalletSecretDelete` stored-destructive and declaration legs went red.
- mutation: drop the `CAFile` location rule from `SslRules.Validate` → `OcuPilot.Test.SslSave.TestTheRulesRefuseBeforeAnythingIsSent` went red.
- mutation: drop the `746` entry from `AdminPort.PROPERTYFAULTS` → `OcuPilot.Test.SslSave.TestAVendorRefusalLandsOnItsFieldAndChangesNothing` went red; the `732` entry → `OcuPilot.Test.SslSecret.TestTheScreenStoresTheRightPasswordRefusesAWrongOneAndLeaksNeither` went red.
- mutation: drop `PrivateKeyPassword` from `SslConfigList`'s `secretArguments` → `OcuPilot.Test.SslSecret.TestTheAgentsConfirmCarriesThePasswordToTheWriteAndNowhereElse` went red.
- mutation: delete `this.sslForm.reset()` from `App.verifyWhenSignedIn` → `app.spec.ts` "AD-8: leaving the signed-in state drops this principal's namespace list" went red on the SSL/TLS password leg.
- mutation: absorb a refresh's read with `replaceBuffer` false in `SslForm.refresh` → `ssl-form.store.spec.ts` "AD-14: a refresh of a clean form re-reads the configuration in place" went red; with `replaceBuffer` true → "AD-14: a refresh of a dirty form keeps what was typed …" went red.
- mutation: drop `void this.store.refresh()` from `SslFormPage`'s ChangeBus subscription → `ssl-form.page.spec.ts` "AD-14: an ssl-configuration change to the configuration on screen re-reads it" went red.
- mutation: drop the held file's `options.push` from `SslFormPage.caFileField` → `ssl-form.page.spec.ts` "AC1, AD-21: an edit of a configuration trusting a file offers that file as the third choice, selected" went red.
- mutation: drop `'Type'` from `OWN_FIELDS` → `ssl-form.store.spec.ts` "AC3, AD-10: OcuPilot's own configuration refuses input …" went red (green before its Type value was changed to `'1'`).
- mutation: keep the empty password in `SslUpdate.DerivedFields` (no `%Remove`) → `OcuPilot.Test.SslSecret.TestAnEmptyOptionalPasswordLeavesTheStoredOneSet` went red on the agent's leg; send the password whenever the body carries it in `SslSave.Update` → the same test went red on the screen's leg.
- mutation: delete the `Gate` call from `SslRules.HandleTest` → `OcuPilot.Test.SslWire.TestACallerLackingAPairIsRefusedOnEveryRoute` went red on the Test route for both principals.
- mutation: answer `taken` 0 in `SslRules.HandleName` → `OcuPilot.Test.SslSave.TestEachRouteAnswersOneJsonEnvelopeOverTheWire` went red on the taken leg.

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** The SSL/TLS editor (`security/ssl/edit[/<name>]`, five tabs, create and edit) saves through the new `security.ssl.create` and `security.ssl.update` tools (AD-54, AD-55); Test connection answers `{passed, lines}` to the screen only (AD-39's exception); OcuPilot's own provider configuration is captioned, its four installer-owned fields drawn disabled and refused `PROHIBITED.OCUPILOTSSL` with its delete (AD-10); turning peer verification off is minted destructive (`SSL.NOPEERCHECK`). Delete row actions on the X.509, Secrets and SSL/TLS lists (DW-1541, DW-1556, AC9) with `security.secrets.delete` and `security.ssl.delete`; DW-332's checker patterns with Demo, DemoFaults and FixtureNamespace armed; DW-391's `faultAbsentEntityNoList`.

**Files.** Server: `Area/Security/SslRules.cls`, `SslSave.cls` (new: rules, form read, name check, test, Save); `Screen/Tool/SslCreate.cls`, `SslUpdate.cls`, `SslDelete.cls`, `WalletSecretDelete.cls` (new tools); `X509Delete.cls` (`SCREENACTIONS`); `Screen/Descriptor/SslForm.cls` (new), `SslConfigList.cls`, `X509CredentialList.cls`, `WalletSecretList.cls` (actions); `Port/AdminPort.cls` (mutating types, `CONNECTIONTESTTYPES`, `@field` property faults); `Kernel/Proposal/Prohibited.cls` (SSL arm, weakening, wallet DELETE clearing); `Api/Error.cls`, `Api/Router.cls`, `Screen/Registry.cls`, `Classification.cls`, regenerated `ToolFields.cls`. Tests: `SslSave`, `SslSecret`, `SslTest`, `SslUpdate`, `SslWire`, `WalletSecretDelete` and fixtures (new); roster updates in `AuditingUpdate`, `Descriptor`, `EndpointCoverage`, `Prohibited`, `ReadTool`, `RefusalCopy`, `SecurityLists`, `SurfaceCoverage`, `ToolRoundTrip`, `Wire`, `WireOAuthRead`, `WireSecurityRead`, `X509Delete`; `Demo`, `DemoFaults`, `FixtureNamespace` armed. Client: `areas/security/ssl-form.page.ts`, `ssl-form.store.ts`, `ssl-actions.ts` with specs (new); `app.ts`, `screen-outlet.ts`, `screen-action-handler.ts`, `self-protection.ts`, `proposal-view.ts`, `switches.page.ts`, `strings.ts`, `_components.scss`, `screens.generated.ts`; browser `ssl-editor`, `security-deletes` (new), `ssl`, `security`, `structural-baseline.json`. Scripts: `check-objectscript.py` and its harness, `ci-throwaway.sh` (appended rosters). EXPERIENCE.md: ten Fixed-strings rows appended.

**Review.** 27 findings (high 0, medium 5, low 16, false 5, maybe-false 1). Patched 7: VG1-VG4 and VG6 (medium), VG5 and VG7 (low), all test additions with mutation lines. Deferred 1: VG12 (unverified medium, a pre-existing confirm-path root cause). Rejected 19, each with its reason in the triage log; IA1 (422 on the screen versus the matrix's 400, following `UserSave`'s order) and IA10 (the three shell-wide baseline rows) are flagged for the lead.

**Follow-up review: recommended** (5 medium entries patched). Unverified by any layer after patching: `SslWire`'s principals (the no-`%Admin_Secure` one holds `%Admin_Operate:U` to pass the router's admin floor) and the new `refresh` tests' dirty-form semantics.

**Verification.** Client tool tests 1387/1388 (the one red is DW-371, the bundle budget, in `deferred:`); component tests 1126/1126; `check-objectscript` 0 problems, its harness OK, `lint-docs` and `client-lint` clean. ObjectScript, one class at a time on `ocupilot-ci`: the story's 22 listed classes plus `SslWire` green but for the known `WireSecurityRead` task-history failure (`AdminInventory` is not a test class). Full sweep once: 235 classes, 2013 tests, 1 failed (`WireSecurityRead.TestTaskHistoryPairSetsAreEnforcedForARealPrincipal`, pre-existing) and 4 refused on arming (`AuditingUpdate`, `ErrorDelete`, `ProcessControl`, `TaskResume`, pre-existing). Browser, rebuilt and redeployed, one file at a time: ssl-editor 7/7, security-deletes 4/4, ssl 5/5, wallet-secret 4/4, security 4/4, switches 4/4, users-actions 2/2, roles-editor 8/8, resources-editor 6/6, oauth-delete 2/2, audit-events 4/4, a11y-structural-invariants 10/10. Initial bundle 1,476,658 bytes (over the 1467kB warning, under 1500kB). Probe configurations removed; `OcuPilotProvider` reads back unchanged; no private key line in the diff.

**Residual risks.** The bundle budget (DW-371 red until re-based); VG12; the own-configuration 200 path is pinned only over a held port (`deferred:`).
