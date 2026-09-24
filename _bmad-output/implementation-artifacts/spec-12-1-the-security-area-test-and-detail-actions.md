---
title: 'Story 12.1: The security-area test and detail actions'
type: 'feature'
created: '2026-09-24'
status: 'done'
review_loop_iteration: 0
baseline_revision: 'ffae9b98c73522e6f7ab3eec1a2a4d5d7f7c3791'
baseline_commit: 'ffae9b98c73522e6f7ab3eec1a2a4d5d7f7c3791'
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

### Review Findings

Code review 2026-09-24 (four layers, full-opus). Each finding: severity · fix-risk · footprint · spec-status.

- [x] [Review][Patch] Subject and Issuer hold the same DN in every fixture, so a swap of the two stays green in the page, store and browser legs (medium · low, fixture values only · in-story · clear; Rule 19 unfalsifiable half of AC1) [ui/src/app/areas/security/x509-form.page.spec.ts:30]
- [x] [Review][Patch] `TestTheDetailsCarryTheCertificateAndNoKey` asserts only `SerialNumber` non-empty on the `CERTINFO` side, so a `CERTINFO` that lost SubjectDN, IssuerDN or a validity date passes on `"" = ""` (low · low, one assertion · in-story · clear) [src/OcuPilot/Test/X509Wire.cls:199]
- [x] [Review][Patch] The EXPERIENCE.md row says the six fields are drawn "as the classic page's X.509 Certificate Data draws them", but `DrawCerData` draws only serial, issuer, subject and Not Valid After (low · low, wording · in-story · clear) [_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:467]

Rejected:

- `low` the server leg's oracle `Info()` reads `CERTINFO` through the same port `HandleForm` uses (also the commit message's "against CERTINFO" claim) -- the port is AD-2's defined path, and the browser leg compares against `%SYS.X509Credentials` independently; a separate oracle is a redesign.
- `low` the Review Triage Log tags the port-oracle row `[false]` -- fix is an edit of the spec under review.
- `low` triage rows 3 and 10 are one finding, both tagged `[reject]` though the Verification line was edited -- fix is an edit of the spec under review.
- `low` Code Map and Tasks still say "after :410" while the row sits at the table's end -- fix is an edit of the spec under review; the end-of-table append is correct (inserting at :410 would shift 82 `EXPERIENCE.md:4xx` citations).
- `false` spec-8-5 :199 "`SerialNumber` is not projected" is a superseded claim -- it records 8.5's delivered read, which was accurate; the live doc in `X509Rules.cls` states the ten fields.
- `low` Epic 9 appends at the same table end, `strings.ts` tail and `strings.test.mjs` bound, so the merge conflicts and the `EXPERIENCE.md:467` citations will move -- resolved at Rule 22's integrate-forward, not in this story's code; 800 still holds 772 after the merge.
- `low` the legend reads like one more field label -- spec-bound: the task prescribes `<legend class="ocu-field-label">`.
- `low` the browser leg toggles `ocu-theme-dark` directly rather than through `toggleThemeThroughMenu`, with a hard-coded class name -- spec-bound ("`ocu-theme-dark` set on `<html>`"), and the dark-only contrast mutation proved the dark pass is measured; a renamed class fails loudly on the surface check.
- `low` the server leg compares the key list in order where the spec asks for an exact set -- stricter, and a reorder fails loudly.
- `low` both `MakeRequest` statuses go unchecked -- the class's convention; a transport failure fails loudly on the HTTP status assertion.
- `low` `detectScreen`'s `unmeasurable` count is dropped on the dark pass -- the walk and `definitions.browser-spec.mjs` do the same; the legend was shown measured by the contrast mutation.
- `false` the 720 px resize settles on two frames only -- the same `setViewport` + `frames` sequence as `definitions.browser-spec.mjs` :554-558, and the leg passed 5 of 5 with both structural mutations red.
- `low` the page is not scanned for certificate-body lines or the password -- the page draws only mapped read fields, and `Leak()` over the whole read (encrypted key and password) is mutation-proven.
- AC and AD audit: no violation of AC1-AC3 or of AD-2, AD-5, AD-8, AD-13, AD-19, AD-24, AD-27, AD-35, AD-36, AD-39, AD-44; Rule 3 met by the browser leg; Rule 14 clean; secret scan 0.

## Spec Change Log

- 2026-09-24, spec gate (runner): the Design Notes' AD-4 recommendation is applied. AD-4 now lists `Security.X509Credential` beside `Security.Resource` and `Wallet.Secret`, measured on `ocupilot-b-ci` (an `OwnerList`-only PUT kept `PeerNames` and `CAFile`). No task changes.

## Review Triage Log

### 2026-09-24 — Review pass

- verdicts: 11 findings — high 0, medium 1, low 6, false 4, maybe-false 0
- findings:
  - `[medium]` `[patch]` AC3's dark contrast pass was never shown to fail, and nothing proved the class toggle took — the leg now asserts the body surface differs between the light and dark passes, and a dark-only legend contrast mutation turned it red (Verification).
  - `[low]` `[reject]` the page-HTML key-body and `PRIVATE KEY` checks are unreachable by any recorded mutation — defense in depth; AC1's no-key half is pinned by the mutation-proven `Leak()` scan and the selector-absence checks, and the fix would be a spec note.
  - `[low]` `[reject]` the planned AC3 mutation line named `inline-size`, which stays green — a spec edit; corrected under Rule 19's sanctioned Verification edit.
  - `[false]` `[reject]` `X509Wire.Info()` reads `CERTINFO` through OcuPilot's own port — the browser leg compares against `%SYS.X509Credentials` directly, an independent oracle CI runs.
  - `[false]` `[reject]` the browser leg's oracle is `GetByAlias`, not `CERTINFO` — the spec's task names `GetByAlias`, and the vendor's `RunCertInfo` answers from the same `%SYS.X509Credentials` properties.
  - `[low]` `[reject]` the browser leg looks for no password or certificate-body text on the page — the page draws only mapped fields from a read the mutation-proven `Leak()` scan covers for all three; an encrypted-key browser import is more than a direct correction.
  - `[false]` `[reject]` screen context is untested — the diff changes no descriptor or context field, and the form sends no screen context (`screen-context.ts` :81), unchanged.
  - `[low]` `[patch]` `AssertEquals(HasPrivateKey, 1)` also passes for a number — `X509Wire` now asserts `%GetTypeOf` is `boolean`; class recompiled on `ocupilot-b-ci`.
  - `[false]` `[reject]` the absent-alias row is not re-tested — 8.5's `X509Wire` :127-131 and page-spec :240 legs cover it unchanged and ran green.
  - `[low]` `[reject]` the planned AC3 mutation did not fail (same root cause as the third row) — corrected there.
  - `[low]` `[reject]` the leg depends on the AC3 leg's import, and `strings.test.mjs`'s bound is shared — the leg asserts its precondition as the file's AC2 leg does; the widening follows that file's own protocol.

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
- AC3: the browser leg's structural assertion. Mutations: give `.ocu-x509-certificate` a `min-inline-size` of 1400px, which overflows; color its legend with the surface token in the dark theme only.
- AC2: `git diff --stat` against the story's baseline names no SSL/TLS or LDAP path.

Observed (implement stage, `ocupilot-b-ci`; each applied, loaded or rebuilt and redeployed, observed red, restored byte-identical):

- mutation: `SerialNumber` dropped from `X509Rules.HandleForm`'s `CERTINFO` loop → `X509Wire.TestTheDetailsCarryTheCertificateAndNoKey` red on the key set and the serial (run 2); restored green (run 4)
- mutation: the stored `PrivateKey` added to `HandleForm`'s `credential` → `TestTheDetailsCarryTheCertificateAndNoKey` red on the key set and the secret scan, and `TestNoReadCarriesTheKeyOrItsPassword` red (run 3)
- mutation: the store maps `serialNumber` as `''` → `x509-form.store.spec.ts` AC4 leg red
- mutation: Serial number rendered outside the fieldset → `x509-form.page.spec.ts` edit and Story 12.1 legs red; browser Story 12.1 leg red over the rebuilt bundle
- mutation: the legend removed → the same page-spec legs red; browser Story 12.1 leg red over the rebuilt bundle
- mutation: `#ocu-x509-PrivateKey` drawn in edit mode → the same page-spec legs red; browser Story 12.1 and AC3 legs red over the rebuilt bundle
- mutation: `.ocu-x509-certificate` given `min-inline-size: 1400px` → browser Story 12.1 leg red on two fresh `overflow` entries (1280 and 720). A fixed `inline-size` stays green: `.ocu-form-fields .ocu-field`'s `max-width` clamps it
- mutation: `:root.ocu-theme-dark .ocu-x509-certificate legend { color: var(--mat-sys-surface) }` → browser Story 12.1 leg red on one fresh dark `contrast` entry (1:1), light passes unchanged (review pass)
- AC2: `git diff --stat ffae9b98` names no `ssl*`, `SSL*` or `Ldap*` path
- mutation: the page template's Subject and Issuer `[value]` bindings swapped → `x509-form.page.spec.ts` Story 12.1 leg red (code review; fixtures now carry `IssuerDN: 'CN=Probe CA'`)
- mutation: the store maps `subject` from `IssuerDN` and `issuer` from `SubjectDN` → `x509-form.store.spec.ts` AC4 leg and the page-spec Story 12.1 leg red (code review)

## Auto Run Result

Status: done
Blocking condition: none

- **Change:** the X.509 form read now carries `SerialNumber` from `CERTINFO`, and the edit page groups Subject, Issuer, Serial number, Valid from, Valid until and Private key present in a `fieldset#ocu-x509-certificate` legended "Certificate details". No route, tool, descriptor or admin-API case changed.
- **Files:** `X509Rules.cls` (serial in the form read, doc lists the ten fields); `X509Wire.cls` (details leg on its own probe); `x509-form.store.ts` / `.page.ts` (field and group); `_components.scss` (own fieldset reset); `strings.ts` plus one EXPERIENCE Fixed strings row, appended at the table's end so the other stories' `EXPERIENCE.md:n` references stay put; `strings.test.mjs` (literal bound 700 → 800, as that file's widening protocol sets out); store, page and browser specs.
- **Review:** 11 findings. Two were patched: a dark-theme proof plus a mutation (medium), and a `boolean` type assertion (low). Five were rejected as low and four as false, reasons in the triage log. Nothing was deferred. Patched: high 0, medium 1, low 1.
- **Verification:**
  - `ocupilot-b-ci` first received 11.9's merged source, which the throwaway predated.
  - The full ObjectScript sweep covered 223 classes and 1991 tests with 0 failed, run one class at a time. Its totals match `%UnitTest_Result` (runs 8-230).
  - `x509-import.browser-spec.mjs` passed 5 of 5 over a rebuilt, redeployed bundle.
  - `npm test` passed: 1375 tool tests and 1044 component tests.
  - The smoke passed 49 of 49.
  - `check-objectscript`, `lint-docs` and the secret grep (0) are clean. AC2's path check was clean too.
- **Residual risk:** `strings.test.mjs`'s bound line may conflict with Epic 9's concurrent string additions at merge.
