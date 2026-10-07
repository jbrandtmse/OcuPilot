---
title: 'Story 18.8: Superservers, authentication options and managed file transfer'
type: 'feature'
created: '2026-10-06'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Four Security pages are still classic-only: Authentication/Web Session Options (`%CSP.UI.Portal.Authentication`), Superservers (`.Servers`, `.Server`), Managed File Transfer connections (`.MFT.ConnectionList`, `.Connection`, `.Authorize`) and the operator's read-only LDAP view (`.LDAPsRO`, `.LDAPRO`, RESOURCE `%Admin_Operate`, which Story 16.14's `%Admin_Secure` screens do not serve). The admin API carries them through `Security.WebAuth`, `Security.Superserver`, `Security.MFT` and `Security.LDAP`. The authentication options can break OcuPilot's own sign-in. The ledger inbox adds DW-1896 (clearing an LDAP configuration's last retrieved attribute).

**Approach:** One implement pass cannot hold four surface groups, so the plan recommends a split by surface (Design Notes › Recommended split). **Part A (this story, 18.8)** is planned in full: Authentication options and the self-protection the second criterion asks for, built on this plan's measurement of which values break sign-in. Parts B (superservers), C (MFT connections) and D (the read-only LDAP view and DW-1896) are outlined. The lead decides.

## Boundaries & Constraints

**Always (Part A):**

- One listed Security screen (position 11) over `Security.WebAuth`. It is one declared single-object `GET` read shared by the form and `security.authoptions.read` (AD-36), with the 21 template fields (`FieldLists.cls:632-654`). `SMTPPassword` is never read, answered, put in context, stored in a proposal or logged (AD-24, AD-35, AD-56).
- Two tools on `AdminPort`, each with two callers (AD-53, AD-55):
  - `security.authoptions.update` is a merge (AD-4). It sends the complete set over the fresh read, except an unchanged `AutheKB`.
  - `security.authoptions.smtppassword` is `CHANGESMTPPWD` with a secret-only body (AD-56 (i)).
  - Both governance keys ship enabled (AD-22 as kept; the story's criteria disable neither).
- Every refusal is decided before any `PUT`, on both callers, as a field violation carrying OcuPilot's own sentence (AD-39).
- The Save takes `Operation.HoldTool("security.authoptions.update", "SYSTEM")` before its fresh read (DW-1882, AD-34). It reads back (AD-58) and emits a change event naming its tool (AD-14).
- The new prohibited arm lives once in `Kernel/Proposal/Prohibited.cls` (AD-10). It reads live state at the write, fails closed, and is pinned by a test that reddens when it is removed.
- New error codes go in `Api/WebAuthError.cls` (prefix `WEBAUTH.`, since `AUTH.` is taken). `Api/Error.cls` gains only its two dispatch lines.
- Every probe that writes configuration runs on `ocupilot-ci` only. It restores S0 exactly (Verification › S0) and leaves the monitor state at 0. One test class per call.

**Never (Part A):**

- No test, probe or browser spec really changes `JWTIssuer` or `JWTSigAlg` (doing so ends every token session on the instance, measured); those confirms run through `SeamAuthOptionsUpdate`. No body sends `AutheOS` false past the arm's refusal (the container's next start then fails, measured).
- No real change ever turns off `AutheCache` or `AutheUnauthenticated`. Both are refused before the write, and a test proves that no `PUT` was sent.
- No AD-27 named case. No "Reset Key Store" (`%SYS.TokenAuth.ResetSystemJWKS` is `[Internal]` and has no admin route). No two-factor issuer field (it is not in the template).
- Parts B, C and D are not built here. No bare `git stash`.
- If the story's new Fixed strings would pass `strings.test.mjs`'s bound of 2800 (2754 used, 46 free), stop and report. The bound is the lead's to move.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Read | Screen open, or agent `security.authoptions.read` | The same 21 fields from one read. No `SMTPPassword`. | Missing pair: 403 naming it |
| Ordinary merge | `LoginCookieTimeout` 30, from Save or confirm | The complete set is sent, less an unchanged `AutheKB`. Read-back `matches`. The stored `AutheEnabled` raw value is unchanged (no `AutheK5KeyTab` added). | None expected |
| Kerberos changed | `AutheKB` false→true or true→false | `AutheKB` is sent, and the vendor sets or clears all seven Kerberos bits, as the classic Save does | None expected |
| Field rules | `AutheAlwaysTryDelegated` without `AutheDelegated`; `AutheLDAPCache` without `AutheLDAP`/`AutheOSLDAP`; `AutheTwoFactorSMS` with an empty `SMTPServer` or `TwoFactorFrom`; `JWTSigAlg` outside RS256…ES512; a timeout that is not a whole number ≥ 0; `JWTIssuer` over 1024 | 422 with a `WEBAUTH.*` violation on the field. Nothing is sent. | The mint refuses identically |
| Sign-in self-protection | The change turns off a method that is the only one an OcuPilot application (`/ocupilot` 64, `/api/ocupilot` 32, `/api/ocupilot/readiness` 64) or `%Service_WebGateway` relies on, after applying it to the fresh system flags | `PROHIBITED.OCUPILOTSIGNIN` on that field, from both callers. No `PUT`. The form read lists the field in `locked`. | A failed read of any of the four refuses |
| Token sign-out | `JWTIssuer` or `JWTSigAlg` changed | Agent: the proposal is minted destructive, with consequence `WEBAUTH.SIGNOUT` on the card. Person: the caption shows at the field. The write proceeds. | None expected |
| O/S login off | `AutheOS` true→false, either caller | Refused `PROHIBITED.OCUPILOTSTART` on the `AutheOS` field before any `PUT` (AD-10's start arm); the form draws the field `aria-disabled` naming the sentence | Zero `PUT` |
| SMTP password | A value, or `""` if Task 0 measures that it clears | Read-back `written`. The value appears in no read, proposal, ledger, log or context. | `""` refused when it does not clear |
| Moved target | A field changed between mint and confirm | The fingerprint re-read refuses (target-changed) | Terminal state on the card |
| Busy target | Another Save holds the lock | 409 `WRITE.TARGETBUSY` after 10 s. Nothing written. | The proposal stays live |

</intent-contract>

## Code Map

Analog: Story 18.21's ECP settings, a listed singleton form page. Adds 18.23's arm and effect wiring and 16.14's secret-only tool.

**Analogs to copy:**

- `src/OcuPilot/Screen/Descriptor/EcpSettings.cls`: listed `form-page` with a single-object `GET` read, plus `filter`/`sort`/`paging` shapes.
- `Area/OsMgmt/EcpSettingsRules.cls` (`HandleForm`) and `Area/OsMgmt/EcpSettingsSave.cls` (`HandleUpdate`): the form read and the Save.
- `Screen/Tool/EcpSettingsUpdate.cls` and `JournalSettingsUpdate.cls`: merge tools (`SENDSBODY 1`, `PERMITTEDFIELDS`, `MergeUpdate` :130, `Consequence` :189).
- `Screen/Tool/OAuthAuthorizationServerSetPassword.cls` (`SECRETBODY` :27, `FINGERPRINTSUBJECT` :34) and `LdapPassword.cls` (`WRITETYPE` :28, `CLEARABLESECRETS` :37, `StateDiff` :118): secret-only tools.
- `Area/Security/LdapSave.cls` `TakePassword` :81, `StorePassword` :304, `Operation.Gate` :323: storing a secret after the merge.

**Prohibited set (`Kernel/Proposal/Prohibited.cls`):**

- Serving path: `SERVINGSERVICE` :664, `Service` :4833, `ServiceWeakening` :4867.
- 18.23's arm: `STARTUPINTERACTIVE` :494, `EncryptionStartup` :2578, `LeavesInteractiveRequired` :2607.
- Effects: `WeakensByEffect` :1632, wired from `Mint.cls:337-344` and `ConsequenceOf` :780.
- Lists: `COVEREDTYPES` :250, the fail-closed list :1153, `Codes()` :795 (28).
- OcuPilot's own applications: `ServesOcuPilot` :4596 walks `Install/Roster.cls` `Keys()` :201 and `Application()` :224. No helper reads an application's `AutheEnabled` live.

**Kernel and registries:**

- `Kernel/EntityType.cls` `TYPES` :87 (57) and `Kernel/EntityRef.cls` `IDRULES` :59 (`RULESINGLETONID` "SYSTEM" :147).
- `Kernel/Governance/Baseline.cls` (services update :79 is the enabled precedent).
- `Screen/Tool/Classification.cls` (LDAP :1285); `ToolFields.cls` is regenerated, never hand-edited.
- `Port/AdminRoutes.cls:213-214` already carries both routes. `Test/AdminInventory.cls:105` already carries the endpoint.

**API layer:**

- `Api/Error.cls`: 989 parameters; dispatch at `ReasonForToolCode` :1228 and `ReasonForViolation` :1430. Copy `Api/WalletKeyError.cls` (`Codes()` :105, `FieldOf` :118, `ReasonFor` :132).
- `Api/Router.cls`: the form route before the `PUT`, as at :240-241.

**Credential-pattern exception, held equal in four places by `ui/tools/credential-lists.test.mjs` :68, :78, :90:**

- `Kernel/Audit/Log.cls` `CREDENTIALEXCEPTIONS` :69.
- `ui/tools/credential-pattern.mjs` `CREDENTIAL_EXCEPTIONS` :44.
- The spine's Conventions › Secrets row.
- The copy at :90.

**Client:**

- Page and store analogs: `ui/src/app/areas/os-management/ecp-settings.page.ts` and `.store.ts`. The service editor's field caption is `areas/permissions/service-editor.store.ts:278-288`.
- `shell/screen-outlet.ts` `DESCRIPTOR_PAGES` :230; `app.ts` :366 (inject) and :701 (sign-out reset).
- `core/proposal-view.ts` :346 and :444 (consequence codes).
- `core/strings.ts`, with one key per value; reuse the service and web-application method labels where the value is equal.

**Navigation and tests:**

- `ui/tools/navigation.test.mjs:250-284` holds the Security route literal. `ui/browser/side-bar-spec.mjs` derives labels, so no spec pins a list.
- `ui/tools/self-protection.test.mjs:283-292` (`KERNEL_REFUSALS`).
- `scripts/ci-throwaway.sh:466-474`: the `OCUPILOT_ALLOW_SERVICE_CONFIG` `# classes:` roster that `ui/tools/ci.test.mjs` derives.

**Budgets:** EXPERIENCE.md is 1039 lines. `angular.json` `maximumWarning` is 3012kB; re-base it and `angular-json.test.mjs:541` to the measured total if crossed (DW-1166), and stop above 3800kB.

## Tasks & Acceptance

### Part A: Authentication options (Story 18.8)

**Task 0** (on `ocupilot-ci`; restore S0 after each step; record each result in Design Notes › Measured at Task 0; halt on any contradiction with Measured at plan):

1. **Record S0.**
   - The `Security.WebAuth` `GET`.
   - `Security.System` `AutheEnabled` (33556471 at plan), `JWTIssuer`, `JWTSigAlg`, `LoginCookieTimeout`, `TwoFactorTimeout`, `SMTPServer`, `SMTPUsername`, `TwoFactorFrom`, and the `PublicJWKS`/`PrivateJWKS` SHA-256 prefixes (hashes only).
   - The `AutheEnabled` of the three roster applications and of `%Service_WebGateway`.
   - `$SYSTEM.Monitor.State()`.
2. **The rules' refusals.** For each Field-rules row, record the vendor's answer (status and code) and whether anything was stored. The rules refuse every row whatever the vendor does; a vendor that stores one is a defect candidate for the list.
3. **`CHANGESMTPPWD`.** Set a probe value: the stored value is non-empty (read as `'= ""` only), and the `GET` never answers it. Then send `""`: does it clear? That answer decides `CLEARABLESECRETS`. Record the vendor audit event for each. A `PUT` is already measured to write `%System/%Security/SystemChange`.
4. **Pairs.** A purpose-built principal `OcuProbe188A` holds exactly `%Admin_Secure:USE` and `%DB_IRISSYS:READ`. It reads the `GET`, sends the unchanged `PUT` (less `AutheKB`) and `CHANGESMTPPWD`, and reads `WebApp.App` `GET` for each roster path and `Security.Service` `GET` for `%Service_WebGateway`. Add only what the instance refuses (AD-8, AD-29). Delete the principal afterwards.
5. **Halt** if any of these holds:
   - an unchanged `PUT` less `AutheKB` changes any S0 value or ends a token minted before it;
   - a step leaves anything S0 does not hold.

**Execution (server):**

- `src/OcuPilot/Kernel/EntityType.cls`, `Kernel/EntityRef.cls`: add `authentication-options` and `authentication-options:singleton` (AD-13).
- `src/OcuPilot/Screen/Descriptor/AuthOptions.cls` (new):
  - route `security/authentication`; area `security`, listed at 11; `form-page`; scope `instance`; id `single`.
  - Privileges: Security's two pairs plus the Task 0 measurement.
  - Read: `{admin, Security.WebAuth, GET}` over the 21 fields; context is the same 21 fields, with no secret fields; `secretArguments` `["SMTPPassword"]`.
  - Classic page `%CSP.UI.Portal.Authentication`, no exemption; does not refresh.
  - Three prompts; `toolIdentifier` `security.authoptions`.
- `Screen/Tool/AuthOptionsUpdate.cls` (new): merge, `PUT`, `PERMITTEDFIELDS` the 21 fields.
  - `MergeUpdate` drops `AutheKB` when it equals the fresh read (AD-4's named exception).
  - `Consequence` answers `WEBAUTH.SIGNOUT` for a changed `JWTIssuer` or `JWTSigAlg`, and nothing else; `AutheOS` true→false is refused `PROHIBITED.OCUPILOTSTART` by the arm, beside `OCUPILOTSIGNIN`, from either caller, before any write.
  - The mint and confirm run `AuthOptionsRules.Check`.
- `Screen/Tool/AuthOptionsSmtpPassword.cls` (new): `WRITETYPE "CHANGESMTPPWD"`, `SENDSBODY 0`, `SECRETBODY "SMTPPassword"`, `FINGERPRINTSUBJECT "SMTPUsername"`. `CLEARABLESECRETS` only if Task 0 step 3 measures that `""` clears. `StateDiff` gives one card row.
- `Screen/Tool/Classification.cls`: entries for both tools: the 21 fields `ordinary`, `SMTPPassword` `secret`. Then regenerate `ToolFields.cls` with `bash scripts/field-lists.sh`.
- `Kernel/Audit/Log.cls` `CREDENTIALEXCEPTIONS` and `ui/tools/credential-pattern.mjs`: add `authelogintoken`, a boolean the credential pattern matches by its `token` suffix. Update `credential-lists.test.mjs`'s extraction to the amended spine sentence.
- `Area/Security/AuthOptionsRules.cls` (new):
  - `HandleForm` (`GET /authentication-options/form`): the declared read's row, plus `locked` from `Prohibited.SignInLocks()`, plus the `JWTSigAlg` options.
  - `Check(pBody, .pViolations)`: the Field-rules rows, as `WEBAUTH.*`.
- `Area/Security/AuthOptionsSave.cls` (new), `HandleUpdate` (`PUT /authentication-options`), in this order:
  1. `HoldTool`.
  2. Take `SMTPPassword` out of the body.
  3. `Check`, then the prohibited set through the operation.
  4. The merge `PUT`.
  5. When a password or `""` was sent, the password tool through `Operation.Gate`, and clear the variable.
  6. Read back and answer `{readBack, consequence}`.
- `Kernel/Proposal/Prohibited.cls`:
  - `TYPEAUTHOPTIONS`; `OCUPILOTSIGNIN` and its reason (the published sentence).
  - Dispatch to `AuthOptions(...)`, which applies the payload's `Authe*` flags to the fresh read's flags using the vendor's bit map (`AutheKB` is seven bits). It refuses when `$ZBoolean(mask, new, 1)` is 0 for any mask `SignInMasks` answers. `SignInMasks` reads each roster application through `AdminPort` `WebApp.App` `GET` and `%Service_WebGateway` through `Security.Service` `GET`; a failed read refuses.
  - `SignInLocks()` (public) answers each field whose turning off alone would refuse.
  - `WeakensByEffect` gains the two effects for `Security.WebAuth`.
  - Update `COVEREDTYPES`, the fail-closed list and `Codes()` (29).
- `Api/WebAuthError.cls` (new): codes, sentences, `FieldOf`, `ReasonFor`. `Api/Error.cls`: the two `WEBAUTH.` dispatch lines.
- `Api/Router.cls`: `GET /authentication-options/form` before `PUT /authentication-options`, with thin calls.
- `Kernel/Governance/Baseline.cls`: `"security.authoptions.smtppassword": true` and `"security.authoptions.update": true`.

**Execution (client):**

- `ui/src/app/areas/security/auth-options.page.ts` and `.store.ts` (new):
  - Sections in the classic order: methods, login cookies, two-factor (its SMTP fields shown while SMS is on, as on the classic page), JWT.
  - A sticky Save and an unsaved-changes guard.
  - `locked` fields are `aria-disabled`, with the refusal sentence through `aria-describedby`.
  - `AutheAlwaysTryDelegated` is disabled unless `AutheDelegated` is on, and `AutheLDAPCache` unless `AutheLDAP` or `AutheOSLDAP` is on. A disabled field is sent false.
  - The consequence caption shows at a changed `JWTIssuer` or `JWTSigAlg`; `AutheOS` carries the start refusal's sentence, `aria-disabled`, while it is on.
  - The SMTP password is a masked, write-only field, empty after Save.
- Wiring: `shell/screen-outlet.ts`, `app.ts`, `core/proposal-view.ts` (the two codes), `core/strings.ts`.
- EXPERIENCE.md: one Fixed-strings row (the labels, two consequences, the refusal, three prompts, the side-bar label), each sentence published once. Fix every shifted `EXPERIENCE.md:n` comment.
- Regenerate `screens.generated.ts`.

**Tests:**

- `src/OcuPilot/Test/AuthOptionsDescriptor.cls`: descriptor, entity type, classification (`SMTPPassword` secret, `AutheLoginToken` not masked), baseline keys, no `SMTPPassword` in read or context.
- `Test/AuthOptionsRead.cls`: screen and tool answer one row; the form's `locked` lists `AutheCache` and `AutheUnauthenticated` on a stock instance.
- `Test/AuthOptionsWrite.cls`, armed by `OCUPILOT_ALLOW_SERVICE_CONFIG`; restores S0 in `OnAfterOneTest`:
  - ordinary merge through Save and confirm;
  - the raw `AutheEnabled` unchanged;
  - the Field-rules rows;
  - SMTP password written, and cleared if measured;
  - fingerprint and busy refusals.
- `Test/AuthOptionsGate.cls`, armed by `OCUPILOT_ALLOW_PRINCIPALS`: the measured pairs, each refused by name before any port call.
- `Test/AuthOptionsProhibited.cls`:
  - Password off and unauthenticated off are refused on both callers, with the stored value unchanged and no `PUT` recorded.
  - A seam read failure refuses.
  - O/S off is refused on both callers with zero `PUT`. A JWT change mints destructive with its consequence and confirms through `Test/SeamAuthOptionsUpdate.cls` (new; answers the `PUT` without a vendor call).
- Rosters, plus the arming rosters in `scripts/ci-throwaway.sh`:
  - `Descriptor`, `SurfaceCoverage` (screen and three tools)
  - `EndpointCoverage` (two routes)
  - `Prohibited` (`CoveredTypes`, `Codes` 29), `AuditingUpdate` (`Codes` count)
  - `ReadTool`, `ToolRoundTrip` (`REFUSEEMPTY`), `ToolWrite`, `ToolEmit`, `DraftRegistry`
  - `GovernanceBaseline`, `Governance`
  - `Wire`, `WireSecurityRead`, `WireOAuthRead`, `WireAreaAnyScreen`, `ScreenRead`, `ReadSourceCorpus`, `ClassicPageGate`
- `ui/src/app/areas/security/auth-options.page.spec.ts` and `.store.spec.ts`.
- `ui/tools`: `navigation.test.mjs` (Security literal), `self-protection.test.mjs` (`KERNEL_REFUSALS`), `proposal-view.test.mjs`, `credential-lists.test.mjs`, `screen-mirror`, `field-lists`, `strings`, and `angular-json` if re-based.
- `ui/browser/auth-options.browser-spec.mjs` (new):
  - the page reached from the side bar;
  - Password and Unauthenticated `aria-disabled` with the sentence;
  - the JWT caption shown without saving;
  - a `LoginCookieTimeout` Save round-trips, then is restored.

**Acceptance Criteria:**

- **A0.** Given Task 0 on `ocupilot-ci`, when steps 1-5 run, then each result is recorded in Measured at Task 0, the spine lines it settles are written, and the throwaway reads as S0.
- **A1.** Given the Authentication options screen and `security.authoptions.read`, when each reads, then both answer the same 21 fields from one read, and no answer, context or log carries `SMTPPassword`.
- **A2.** Given an ordinary change, when it is saved on screen or confirmed from a proposal, then the instance holds it, the read-back reads `matches`, every other field and the raw `AutheEnabled` bits are unchanged, and a moved target or a held lock is refused as the matrix says.
- **A3.** Given an SMTP password typed on the form or at confirm, when it is written, then the read-back reads `written`, and the value appears in no read, proposal, ledger row, log line or context.
- **A4.** Given a change that turns off the only method one of OcuPilot's applications or `%Service_WebGateway` relies on, when either caller sends it, then it is refused `PROHIBITED.OCUPILOTSIGNIN` on that field before any `PUT`, and the form draws that field `aria-disabled` naming the same sentence. A change turning `AutheOS` off is refused `PROHIBITED.OCUPILOTSTART` on that field the same way, from either caller.
- **A5.** Given a `JWTIssuer` or `JWTSigAlg` change, when the agent proposes it, then the card is destructive and states its consequence, and the screen shows the same sentence at the field before Save.
- **A6.** Given the rosters, when the suites run, then:
  - Security lists Authentication options at 11 with three prompts;
  - both keys are in the baseline, enabled;
  - `authentication-options` is a singleton type;
  - the credential exception is held equal in all four places;
  - the Fixed strings stay within 2800.
- **Integration.** The page consumes `GET /authentication-options/form` and `PUT /authentication-options`, and the agent consumes the read tool and both write tools, each on `ocupilot-ci` (A1-A5, the browser spec).

## Spec Change Log

- 2026-10-07, spec gate (lead), merge-gate rulings: split approved (Part A is this story; B-D outlines trimmed, kept at `e7a3bef1`). Decision 4 reversed on the lead's measurement: `AutheOS` off is refused `PROHIBITED.OCUPILOTSTART` (the container start fails and stays exited), always, because the install origin is not reliably detectable; `WEBAUTH.OSLOGIN` retired. Matrix, Tasks, A4, A5, the sentence table and the A4 mutation edited to match. Spine AD-10 (`OCUPILOTSIGNIN` and `OCUPILOTSTART`), AD-13, AD-4 and Conventions › Secrets written. DW-1896 re-owned to 18.27; the vendor candidate is DW-2139.

## Review Triage Log

## Design Notes

**Governing ADs (Part A):**

- AD-2, AD-27: `AdminPort` only; both routes exist; no named case.
- AD-3: derived list, plus reviewed classification; `SMTPPassword` is an authored secret.
- AD-4: merge; the `AutheKB` exception is measured.
- AD-5, AD-36, AD-44: one descriptor, one single-object read, the classic page.
- AD-6, AD-34, AD-40, AD-53, AD-55, AD-56: two callers; the closed confirm channel; HoldTool; secret-only body.
- AD-8, AD-29: pairs measured at Task 0.
- AD-10: the new arm and two effects. AD-13: singleton. AD-14: change event.
- AD-15: the vendor's `SystemChange` event (measured); no named case unless step 3 finds none.
- AD-22: baseline. AD-24, AD-35: no secret in context or logs. AD-28: the sign-in this protects. AD-39: own sentences. AD-58: read-back. AD-59: `Snippet` through `AdminRoutes`.
- Conventions › Secrets.

**Measured at plan.** All on `ocupilot-ci`, 2026-10-06, each change through the admin API `PUT`. After each, S0 was restored and re-verified by the same battery: form sign-in, a token minted before the change (Bearer and refresh), silent sign-in, shell, readiness, and the admin API over Basic. Output is in the scratch `p188/measure-out.txt`.

| Change | Form sign-in | Earlier token, Bearer / refresh | Silent | Shell / readiness | Admin API Basic |
| --- | --- | --- | --- | --- | --- |
| None (S0) | 200 | 200 / 200 | 200 | 200 / 200 | 200 |
| `JWTIssuer` set | 200 | 401 / 401 | 200 | 200 / 200 | 200 |
| `JWTSigAlg` ES256→RS256 | 200 | 401 / 401 | 200 | 200 / 200 | 200 |
| `AutheTwoFactorPW` on | 200 | 200 / 200 | 200 | 200 / 200 | 200 |
| `AutheUnauthenticated` off | 200 | 200 / 200 | 200 | **401 / 401** | 200 |
| `AutheCache` (password) off | **401** | 200 / 200 | 200 | 200 / 200 | **401** |
| `AutheLoginToken` on | 200 | 200 / 200 | 200 | 200 / 200 | 200 |
| `AutheOS` off | 200 | 200 / 200 | 200 | 200 / 200 | 200 |

- **`JWTSigAlg` replaces the signing keys.** The JWKS hashes changed, and changing back made new keys again rather than restoring the old ones. The originals were restored from a copy held in `^IRIS.Temp` and then killed. A `PUT` that sends `JWTSigAlg` unchanged kept the keys.
- **`AutheOS` off** answered `iris session` "Access Denied" and failed the container's health check once (`scripts/container-health.sh` and the start hook use `iris session`). **Lead measurement, 2026-10-07 03:47Z:** `AutheOS` off by the admin API, then `docker restart ocupilot-ci`: the start hook's first `iris session` answered "Access Denied", the container was restarted three times and left exited (exit 1); the throwaway was rebuilt.
- **A complete unchanged `PUT`** (the `GET` sent back) kept tokens and keys, but raised `AutheEnabled` from 33556471 to 33556479: `AutheKB` true sets `AutheK5KeyTab`, which the stock instance leaves off. The classic Save does the same (`Authentication.cls:311-314`). Restored.
- **Every `Modify` wrote `%System/%Security/SystemChange`.** C6 left four `%System/%Login/LoginFailure` audit rows, which the append-only audit keeps.
- **End state:** `WebAuth GET` equal to S0, raw `AutheEnabled` 33556471, JWKS hashes equal to S0, monitor 0, container healthy.
- **No OcuPilot screen serves the operator's read-only LDAP view.** `Security.LDAP` admits `%Admin_Operate` for `LIST` and `GET` only (read in source). The epic context's "(inference: the read-only view is covered)" is wrong.

**Decisions** (applied in this plan; the lead confirms them with the split):

1. **Placement: Security, listed at 11,** appended so that no listed position or roster pin moves (the classic page sits under System Security).
2. **A new code in AD-10's serving-path family, `PROHIBITED.OCUPILOTSIGNIN`**, rather than reusing `SERVINGSERVICE`, whose sentence names "this service". The predicate is by effect over live masks, so an application an operator widened (for example password plus delegated) is refused only when all its methods go.
3. **JWT changes are permitted, not refused.** Sign-in survives (measured); every earlier token session ends. The change is minted destructive with `WEBAUTH.SIGNOUT`, and the person sees the caption at the field, as with AD-10's `%Service_WebGateway` wording.
4. **`AutheOS` off is refused** (merge gate 2026-10-07, measured by the lead: OcuPilot's container start then fails and the container stays exited), `PROHIBITED.OCUPILOTSTART` under AD-10's start arm, always: the install origin is not reliably detectable from inside IRIS, and a wrong permit costs an instance that will not start. Was: permitted at the destructive treatment with `WEBAUTH.OSLOGIN`.
5. **Both keys are enabled** (AD-22 as kept; `permissions.services.update` is the precedent for effect-based destructive minting).

**Published sentences** (the server reason equals each one):

| Code | Sentence |
| --- | --- |
| `PROHIBITED.OCUPILOTSIGNIN` | "One of OcuPilot's own web applications, or the web gateway that serves them, signs in only through this method. Turning it off for the whole instance would cut off every user, including you." |
| `WEBAUTH.SIGNOUT` | "Every session signed in with a token ends, every OcuPilot tab included, and each must sign in again. A new signature algorithm also replaces the instance's signing keys." |
| `PROHIBITED.OCUPILOTSTART` (`AutheOS`) | "OcuPilot's own container signs in through the operating system at every start, so turning this off would leave the instance unable to start. If this instance does not run in OcuPilot's container, change it on the classic Authentication page." |

**Named limits:**

1. "Reset Key Store" stays a classic-page action.
2. The two-factor one-time-password issuer is not in the admin API.
3. A user whose account requires two-factor authentication has no second-factor step on OcuPilot's form, and signs in to OcuPilot silently after the classic portal (inference).

**Spine amendments** (Rule 20; 1-4 written at the spec gate on 2026-10-07; 5-6 written by the runner from Task 0):

1. **AD-10, a new bullet in the serving-path family:** "**OcuPilot's own sign-in** (Story 18.8): a `Security.WebAuth` change that would leave one of OcuPilot's own web applications, or `%Service_WebGateway`, with no authentication method enabled for the instance (each read at the write; a failed read refuses) is refused `PROHIBITED.OCUPILOTSIGNIN`, from either caller (measured: password off refused OcuPilot's sign-in 401; unauthenticated off refused its shell and readiness 401). A change to `JWTIssuer` or `JWTSigAlg`, which ends every token session, is permitted at the strongest confirmation with its consequence; turning O/S authentication off is refused `PROHIBITED.OCUPILOTSTART` under the start arm (measured: OcuPilot's container start then fails) [AMENDED 2026-10-07, Story 18.8 spec gate, Rule 20]." (Written at the spec gate.)
2. **AD-13:** "**`authentication-options` is a singleton** (Story 18.8)."
3. **AD-4, after `Security.Encryption.Settings`:** "**`Security.WebAuth` keeps a key its body omits and omits an unchanged `AutheKB`** (Story 18.8): sending it true sets all seven Kerberos bits, so a re-sent value adds `AutheK5KeyTab`, which a stock instance leaves off (measured at Story 18.8's plan)."
4. **Conventions › Secrets:** a second exception, `AutheLoginToken`, the system-wide "Allow creation of Login Cookies" flag, which Story 18.8's tools show and set. Written at the spec gate as an appended sentence, "A second exception: `AutheLoginToken`, ...", after the `ReturnRefreshToken` sentence, so the current extraction stays green; this story extends `credential-lists.test.mjs` to read both sentences and adds `authelogintoken` to `CREDENTIAL_EXCEPTIONS` (`ui/tools/credential-pattern.mjs`).
5. **AD-8:** "Story 18.8's Authentication options declares Security's set; its tools declare <measured> [AMENDED <date>, Story 18.8 Task 0, Rule 20]."
6. **AD-56 `CLEARABLESECRETS` and AD-15/AD-53:** only where Task 0 step 3 measures them.

**Integration ACs.** The new modules (`AuthOptionsRules`, `AuthOptionsSave`, the arm with `SignInLocks`, and `WebAuthError`) are consumed in this story by the page, the agent and both tools (Tasks › Integration).

- **Consumes:** 16.13 (the serving-path family and the field-caption idiom), 18.21 (the listed singleton form), 16.14 (secret-only tool, store after merge), 18.23 (effect wiring), 23.4 (HoldTool, `PORT.STARTED`), 16.17 (read-back), 14.1 (`Snippet`), 14.2 (baseline).
- **Consumed-by:** Story 18.25 (the superserver arm reuses `SignInMasks`' serving-path reading, inference), 18.12 (the agent's grown tool set).

**Ledger inbox (Rule 17):** Declined DW-1896: it is the LDAP editor's write, on Part D's surface; re-owned to `18-27-the-operator-s-read-only-ldap-view` by the merge gate (2026-10-07).

**Footprint (Rule 11).**

- Contended files are edited add-only: kernel, registry, `Error.cls`, `Router.cls`, `Baseline.cls`, `Prohibited.cls`, test rosters, `ci.test.mjs`, `strings.ts`, EXPERIENCE.md, the spine.
- For `footprint_extensions`: `Kernel/Audit/Log.cls`, `ui/tools/credential-pattern.mjs`, `ui/tools/credential-lists.test.mjs`, `scripts/ci-throwaway.sh`, `Api/WebAuthError.cls`.

**Size (Part A, inference).** One listed descriptor, a derived read tool, two write tools, rules and Save classes, one arm with two effects, an error class, a page and store, one browser spec, six test classes. About ECP settings' half of 18.21 plus 18.23's arm.

**Vendor defect candidate** (owner hold; for the lead's list, not reported): the `WebAuth` `GET`→`PUT` round trip is not idempotent. `AutheKB` true adds `AutheK5KeyTab`, which the stock instance leaves off, and the classic Save does the same (measured at plan).

### Split (approved)

The orchestrator's merge gate approved the split on 2026-10-07 (Rule 5): this spec is Part A. Superservers are Story 18.25, managed file transfer connections Story 18.26, and the read-only LDAP view with DW-1896 Story 18.27; their outlines are in this spec as committed at `e7a3bef1` (Design Notes › Recommended split), for their own plans.

## Verification

**Setup (slot A, Part A):**

- Load with `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/1518373f-040c-4be6-a814-a27bfbff2961/scratchpad/epic-18-d8/load-ocupilot-ci.sh`, which prints `LOAD-OK` and `STARTPATH-OK`. Never use the MCP loader.
- One test class per call. Send the next only once the previous run has landed in `%UnitTest_Result`. Never re-submit after a client-side timeout.
- Before any browser run:
  - `cd ui && npm run build`
  - `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`
  - export `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci`.

**S0 for `ocupilot-ci`** (Task 0 step 1 records it):

- `WebAuth GET` equal to S0.
- `Security.System` `AutheEnabled` 33556471, `JWTIssuer` "", `JWTSigAlg` ES256.
- JWKS hash prefixes `rwfWrfBBETXp` / `Xrb3u+PMk9BZ`.
- The roster applications 64/32/64 and `%Service_WebGateway` 32.
- No `OcuProbe188*` principal; monitor 0.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one class at a time. Expected 0 failures, totals checked against `%UnitTest_Result`.
  - The story's classes: `AuthOptionsDescriptor`, `AuthOptionsRead`, `AuthOptionsWrite`, `AuthOptionsGate`, `AuthOptionsProhibited`.
  - Then the rosters in Tasks › Tests.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/auth-options.browser-spec.mjs browser/security.browser-spec.mjs`. Expected pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`. Expected clean.
- `(once, before dev_complete)`, each green with a non-zero count:
  1. the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-ci`, one class at a time;
  2. `cd ui && npm test && npm run build`;
  3. `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`;
  4. the throwaway reads as S0.
- `(CI)` The full browser suite runs in CI's three `browser-shard` jobs (Rule 29).

**Planned pinning mutations (Rule 19).** Apply each on `ocupilot-ci`, recompile the tree, observe red, revert byte-identical, and record `mutation: <change> → <test> red (run n)` here:

- **A1:** the descriptor's read adds `SMTPPassword` → `AuthOptionsDescriptor`'s secret leg.
- **A2:** `MergeUpdate` keeps an unchanged `AutheKB` → `AuthOptionsWrite`'s raw-bits leg. `Check` drops the SMS rule → its field-rule leg.
- **A3:** the Save keeps `SMTPPassword` in the merge body → `AuthOptionsWrite`'s no-secret-in-body leg.
- **A4:** the `OCUPILOTSIGNIN` dispatch removed → `AuthOptionsProhibited`'s two callers. The `OCUPILOTSTART` dispatch removed → its `AutheOS` leg, a `PUT` recorded. `SignInMasks` answers success on a failed read → its seam leg. `SignInLocks` empty → `AuthOptionsRead`'s `locked` leg and the browser spec.
- **A5:** `Consequence` answers "" for `JWTSigAlg` → `AuthOptionsProhibited`'s destructive-mint leg and `proposal-view.test.mjs`.
- **A6:** `security.authoptions.update` dropped from the baseline → `GovernanceBaseline`. `authelogintoken` dropped from `Log.cls` → `credential-lists.test.mjs`.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

- Planned at plan (Opus): Part A in full with ACs A0-A6; Parts B-D outlined, then trimmed at the spec gate after the merge gate approved the split.
- Spec gate (lead, 2026-10-07): Decision 4 reversed to a refusal (`PROHIBITED.OCUPILOTSTART`) on a measured failed start; spine amendments written; DW-2139 filed under the owner's hold.
