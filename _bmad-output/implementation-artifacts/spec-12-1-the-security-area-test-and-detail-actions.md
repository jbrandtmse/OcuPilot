---
title: 'Story 12.1: The security-area test and detail actions'
type: 'feature'
created: '2026-09-24'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-12-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-8-5-x-509-import-edit-and-delete.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** An X.509 credential's details are the certificate data the classic editor draws under "X.509 Certificate Data": serial number, issuer, subject and validity. Story 8.5's edit page (`security/x509/edit/<alias>`) already shows subject, issuer, validity and "Private key present". It does not show the serial number, and nothing groups these fields as the certificate's details or pins that they render with no private key.

**Approach:** Add `SerialNumber` to the form read. On the edit page, group the certificate's read-only fields under a named "Certificate details" group, with Serial number added. Pin the AC end to end: through the form read, the page, and a browser leg that also runs the DW-1337 structural checks on this view. There is no new route, tool, descriptor field or admin-API case, because `CERTINFO` already answers every field the classic page shows.

## Boundaries & Constraints

**Always:**

- The details come only from the vendor `GET` and `CERTINFO`, through the update tool's port (`X509Rules.Read`), as today (AD-2).
- No read, DOM node, screen context or log line carries the certificate body, the private key or its password (AD-35). Edit mode draws no key, certificate or password input.
- Every visible word is a `STRINGS.<key>` with a Fixed strings row, appended only. Colors and sizes use tokens only, and the view is correct in the dark theme.
- The details view passes the DW-1337 invariants (name, min-width, overflow, contrast) with no baseline entry of its own. The only entries allowed are the shell-chrome entries the baseline already keys to `security/x509/edit`.

**Never:**

- Build the SSL/TLS test (Story 9.5's) or the LDAP test (Story 16.14's).
- Add an X.509 list row action. The list's row action is Story 9.5's (DW-1541).
- Change the X.509 list's declared read, table or context, or any X.509 write, tool or `Classification.cls` entry.
- Touch any contended file (`Screen/Registry.cls`, `screen-mirror.mjs`, `Kernel/Proposal/**`, `Api/Router.cls`, `screen-outlet.ts`, `Classification.cls`), `ui/browser/structural-walk.mjs` (import only), or anything Epic 9 owns.
- Put key material in any file. Test material is generated at run time, as 8.5 does.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Details, key held | `GET /x509/form?alias=<a>` for a credential imported with a key | `credential` holds exactly `Alias, OwnerList, PeerNames, CAFile, SubjectDN, IssuerDN, SerialNumber, ValidityNotBefore, ValidityNotAfter, HasPrivateKey`. Each certificate field equals the vendor `CERTINFO`, and `HasPrivateKey` is `true`. The page's "Certificate details" group shows Subject, Issuer, Serial number, Valid from, Valid until and Private key present ("Yes"), read-only, in that order | No error expected |
| No key text anywhere | Same credential | No read answer and no page HTML holds any line of the key body, a `PRIVATE KEY` marker or the password. `#ocu-x509-PrivateKey`, `#ocu-x509-PrivateKeyPassword` and `#ocu-x509-Certificate` are absent | No error expected |
| Absent alias | Alias not held | Unchanged: 404 `X509.ALIAS.ABSENT`, and Save stays `aria-disabled` | Nothing is sent |

</intent-contract>

## Code Map

- `src/OcuPilot/Area/Security/X509Rules.cls` -- `HandleForm` :199. The `CERTINFO` field loop :235 lacks `SerialNumber`. Update the doc :193-198, and drop 8.5's "SerialNumber is not projected".
- Vendor `%Api.Admin.Endpoints.Security.X509Credential` (read on `ocupilot-slot-b`, `%SYS`). `RunCertInfo` :80-94 answers exactly `HasPrivateKey, SerialNumber, IssuerDN, SubjectDN, ValidityNotBefore, ValidityNotAfter` from `%SYS.X509Credentials`. `RunPut` :96-115 sets only the keys the body defines.
- Classic `irissys/%CSP/UI/Portal/X509Credential.cls` `DrawCerData` :187-222. It draws Serial number, Issuer DN, Subject DN and Not Valid After, in edit mode only. This is the parity target.
- `src/OcuPilot/Test/X509Wire.cls` (410 lines):
  - `TestNoReadCarriesTheKeyOrItsPassword` :172 is the form-read key scan to model on.
  - `Info()` is the vendor `CERTINFO`, and `Leak()` scans for secrets.
  - Probes are removed by exact alias.
  - The class is armed on `OCUPILOT_ALLOW_PRINCIPALS` and already on `scripts/ci-throwaway.sh`'s roster.
- `ui/src/app/areas/security/x509-form.store.ts`:
  - `CredentialView` :56 and `EMPTY_CREDENTIAL` :74;
  - the mapping :572-579, which gains `serialNumber: textAt(credential, 'SerialNumber')`.
- `ui/src/app/areas/security/x509-form.page.ts` -- the edit branch :202-230 (readonly inputs, `readId()`, `hasPrivateKeyText`). A fieldset precedent is `wallet-secret-form.page.ts` :184-185 (`<legend class="ocu-field-label">`), and its reset is `.ocu-form-authe` in `_components.scss` :5264.
- `ui/src/app/areas/security/x509-form.page.spec.ts` -- the edit leg :158-184 pins the label and readonly-id order. Update it. It is this story's file.
- `ui/browser/x509-import.browser-spec.mjs`:
  - the AC3 leg :210-254 imports `ALIASES[0]` with a key and lands on its edit page;
  - `irisSys` :100, `storedCredential` :115.
- `ui/browser/structural-walk.mjs` exports `detectScreen`, `collapse`, `compare`, `readBaseline`, `componentMinimums`, `INVARIANTS` and `VIEWPORTS`. Its walk opens `security/x509/edit` in create mode only, so the details view is never walked. The baseline already keys four shell-chrome entries to `security/x509/edit`.
- `ui/src/app/core/strings.ts` -- X.509 strings :1445-1458. Append before `} as const;`.
- EXPERIENCE.md -- the X.509 form Fixed strings row :410. Append a row after it. Row :148 lists "X.509 details" (P1, entry "editors").

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Area/Security/X509Rules.cls` -- add `SerialNumber` to `HandleForm`'s `CERTINFO` loop as a string, and state the credential's full key set in its doc -- the one server change.
- `src/OcuPilot/Test/X509Wire.cls` -- add `TestTheDetailsCarryTheCertificateAndNoKey`, self-contained on its own exact-alias probe imported with an encrypted key and its password:
  - the form read's `credential` key set equals the ten names exactly;
  - each certificate field equals `Info()`;
  - `HasPrivateKey` is 1;
  - `Leak()` over the answer is empty;
  - clean up in the class's existing exact-alias cleanup;
  - keep the class under 500 lines.
- `ui/src/app/areas/security/x509-form.store.ts` -- add `serialNumber` to `CredentialView`, `EMPTY_CREDENTIAL` and the mapping.
- `ui/src/app/areas/security/x509-form.page.ts`:
  - In edit mode, wrap Subject, Issuer, Serial number (new, `readId('SerialNumber')`), Valid from, Valid until and Private key present in `<fieldset class="ocu-field ocu-x509-certificate" id="ocu-x509-certificate">` with `<legend class="ocu-field-label">{{ STRINGS.x509CertificateDetails }}</legend>`.
  - Alias stays above the group, and CA file stays below it.
- `ui/src/styles/_components.scss` -- append its own `.ocu-x509-certificate` block. It is the `.ocu-form-authe` fieldset reset, `min-inline-size: 0` included, with tokens only. Do not reuse another story's class.
- `ui/src/app/core/strings.ts` -- append `x509CertificateDetails: 'Certificate details'` and `x509FieldSerialNumber: 'Serial number'`.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- append one Fixed strings row after :410 for the two strings (Story 12.1, FR-75).
- `ui/src/app/areas/security/x509-form.store.spec.ts` and `x509-form.page.spec.ts`:
  - the store maps `SerialNumber`;
  - the edit leg's label and readonly-id orders include Serial number after Issuer;
  - a new leg asserts that the group named by its legend holds exactly the six fields, and that no secret input exists.
- `ui/browser/x509-import.browser-spec.mjs` -- add the leg "Story 12.1 AC1" after AC3, on `ALIASES[0]`:
  - Open `security/x509/edit/<alias>`.
  - Assert the fieldset's legend and its six labels and values. The expected values come from the vendor through `irisSys` (`GetByAlias` → `SerialNumber`, `IssuerDN`, `SubjectDN`, `ValidityNotBefore`, `ValidityNotAfter`, `HasPrivateKey`), never from openssl's format.
  - Assert that no secret input exists, and that the page HTML holds no key-body line and no `PRIVATE KEY`.
  - Then run `detectScreen` at 1280 light (`INVARIANTS`), at 720 light (`name`, `min-width`, `overflow`), and at 1280 dark (`contrast`, with `ocu-theme-dark` set on `<html>`, per Conventions › Theme), all with `route: 'security/x509/edit'`.
  - Assert that `compare(collapse(found), readBaseline().entries).fresh` is empty.

**Acceptance Criteria:**

- **AC1.** Given an X.509 credential held with a private key, when the user opens its details (the list's name cell → `security/x509/edit/<alias>`), then the "Certificate details" group renders its subject, issuer, serial number, validity dates and "Private key present: Yes", each equal to the vendor's `CERTINFO`. No form-read field, input or page text carries the key, the certificate body or the password.
- **AC2 (non-build).** Given this story's diff, when it is assessed, then it builds no SSL/TLS test and no LDAP test, and it touches no `ssl*`, `SSL*`, `Ldap*` or `ui/src/app/areas/security/ssl*` path (`git diff --stat` against the baseline).
- **AC3 (DW-1337).** Given the details view, when it is measured at 1280 px light, 720 px light and 1280 px dark, then no structural or contrast violation is found beyond the shell-chrome entries the baseline already holds for `security/x509/edit`.

## Spec Change Log

- 2026-09-24, spec gate (runner): the Design Notes' AD-4 recommendation is applied. AD-4 now lists `Security.X509Credential` beside `Security.Resource` and `Wallet.Secret`, measured on `ocupilot-b-ci` (an `OwnerList`-only PUT kept `PeerNames` and `CAFile`). No task changes.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-2, AD-5, AD-8, AD-13, AD-19, AD-24, AD-27, AD-35, AD-36, AD-39, AD-44. AD-4 is not engaged, because no save changes.

- **Why the editor, and why no row action.** The feature catalog's SS-18 reads "new (SMP shows in editor)". EXPERIENCE row 148's entry for the group is "editors". The classic list's only row links are Edit and Delete. The X.509 list's row action belongs to Story 9.5 (DW-1541), so a "Details" row action would contend with Epic 9.
- **No new AD-27 case.** `CERTINFO` answers every field the classic page draws, so nothing is completed through `%SYS.X509Credentials`, and `X509GetField` is not called on a read path.
- **The agent's read is unchanged (decision).** The list's read already gives the agent subject, issuer and validity. `SerialNumber` stays off it, because no AC asks the agent for it and a shipped read would move three rosters. `HasPrivateKey` also matches the Conventions › Secrets pattern (`…privatekey`). The form declares secret context fields, so it sends no screen context (`screen-context.ts` :81).
- **Rule 20 recommendation for the runner (AD-4).** AD-4 lists `Security.X509Credential` among the endpoints where "sending only the changed fields … erases every field omitted", and the Epic 12 preamble says the same. The vendor `RunPut` (:104-112, read on `ocupilot-slot-b` 2026-09-24) sets `OwnerList`, `PeerNames` and `CAFile` only when `%IsDefined`. Story 8.5 measured an `OwnerList`-only body keeping `PeerNames`. Recommend moving it into AD-4's sentence beside `Security.Resource` and `Wallet.Secret`: it calls no merge helper but keeps a field its body omits. The complete-body rule is unchanged. This story sends no X.509 body, so no probe was run.
- **Contention.** No contended file is edited. `strings.ts`, `_components.scss` and EXPERIENCE.md are shared-append, with own entries only. The descriptor is unchanged, so `screens.generated.ts` does not move. The bundle grows by one field and a group, far below the 1378kB warning.
- **Integration ACs.** No service, module or shared component is introduced, so Rule 1 has no subject. Consumes: Story 8.5's form read, `X509Form`, and the form page. Consumed-by: none.
- **Ledger inbox:** empty.

## Verification

Slot B. Every IRIS MCP call carries `server: "ocupilot-slot-b"`. Stateful runs happen on the throwaway `ocupilot-b-ci` (web 52777, super 1976) only, and nothing stateful runs on `ocupilot-slot-b`. Run one test class per call, and wait for each to land in `%UnitTest_Result` before sending the next.

**Commands:**

- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/` (loop) -- expected: the bundle under test is the one just built.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/x509-import.browser-spec.mjs` (loop) -- expected: all legs pass.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class <C>` for `X509Wire`, then `X509Import`, then `X509Update`, one per call (loop) -- expected: 0 failures each.
- `cd ui && npm run test:components && npm run test:tools && node tools/client-lint.mjs` (loop) -- expected: 0 failures.
- `uv run scripts/check-objectscript.py src/OcuPilot/Area/Security/X509Rules.cls src/OcuPilot/Test/X509Wire.cls && bash scripts/lint-docs.sh` (loop) -- expected: clean.
- The full ObjectScript sweep on `ocupilot-b-ci`, one class per call, with totals checked against `%UnitTest_Result` (once, before dev_complete) -- expected: 0 failures and a non-zero count.
- `cd ui && npm run build && npm test` and `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` (once, before dev_complete) -- expected: green, and a non-zero smoke count.
- The full browser suite is not run locally. CI's `browser` job runs it (Rule 29).
- `git diff | grep -c 'BEGIN.*PRIVATE KEY'` -- expected: `0`.

**Pinning tests and mutations (Rule 19; the implementer records each as `mutation: … → …`):**

- AC1, server: `X509Wire.TestTheDetailsCarryTheCertificateAndNoKey`. Mutations: drop `SerialNumber` from `HandleForm`'s loop; add the stored `PrivateKey` to `credential`.
- AC1, client: the page-spec group leg and the browser leg, over a rebuilt, redeployed bundle. Mutations: render Serial number outside the fieldset; remove the legend; draw `#ocu-x509-PrivateKey` in edit mode.
- AC3: the browser leg's structural assertion. Mutation: give `.ocu-x509-certificate` a fixed `inline-size` of 1400px, which overflows.
- AC2: `git diff --stat` against the story's baseline names no SSL/TLS or LDAP path.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
