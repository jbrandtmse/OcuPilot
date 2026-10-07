---
title: "Story 18.27: The operator's read-only LDAP view"
type: 'feature'
created: '2026-10-07'
status: 'blocked'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The classic System Operation pages for LDAP configurations (`%CSP.UI.Portal.LDAPsRO` and `.LDAPRO`, RESOURCE `%Admin_Operate`) have no OcuPilot equivalent. OcuPilot's LDAP list and editor require `%Admin_Secure:USE`. The story asks that an operator holding `%Admin_Operate` but not `%Admin_Secure` read the list and a configuration's detail through the admin API, and be refused every write.

**Approach:** Not planned. The plan measured no path that reads an LDAP configuration for such an operator: not the admin API, not OcuPilot's `AdminPort`, and not the classic pages themselves (Design Notes › Measured at plan). The criterion "each reads through the admin API" is unreachable as worded. The only remaining route is an elevation, which AD-8 forbids. The lead decides (Design Notes › Decision needed).

## Boundaries & Constraints

**Always:**

- Reads go through `AdminPort` (AD-2, AD-27).
- A screen's pairs are measured as a least-privileged principal (AD-29).
- Probes run on `ocupilot-ci` only.

**Never:**

- An elevation that OcuPilot starts on the request path (AD-8 allows only AD-9's).
- `%SYS.LDAP.Get`, which is `[Internal]` and adds `%All`.
- Reading `LDAPSearchPassword` (AD-35).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Operator list | A holder of `%Admin_Operate` without `%Admin_Secure` opens the LDAP list | The criterion asks for the rows through the admin API. Measured: unreachable (Design Notes) | Undecided |
| Operator detail | The same caller opens one configuration | The criterion asks for its fields through the admin API. Measured: unreachable | Undecided |
| Operator write | The same caller sends any LDAP write | Refused by name, `%Admin_Secure:USE`, before any port call | Already true: the four tools' pairs |

</intent-contract>

## Code Map

For a re-plan, whichever option is chosen:

- **The existing LDAP screens.**
  - `src/OcuPilot/Screen/Descriptor/LdapConfigList.cls:33-86` is the list:
    - route `security/ldap`;
    - Security's pairs;
    - `Security.LDAP` `LIST` with a `rowGet` `GET` and an `Enabled` derived `bit64`;
    - classic page `%CSP.UI.Portal.LDAPs`, tool `security.ldap`.
  - `LdapConfigForm.cls:20-53` is the editor (`form-page`, classic page `%CSP.UI.Portal.LDAP`).
- **The write tools** `Screen/Tool/LdapCreate.cls`, `LdapUpdate.cls`, `LdapPassword.cls` and `LdapDelete.cls`.
  - Each takes its pairs from `LdapConfigList`, so an operator is refused `%Admin_Secure:USE` by name before any port call (`Kernel/Proposal/Operation.cls:398`, `Kernel/Agent/Dispatch.cls:260-271`).
  - Widening `LdapConfigList`'s pairs would widen every one of these gates.
- **Placement.** `Screen/Area.cls:83` is OS management: its set is `%Admin_Operate:USE`, `%Admin_Manage:USE` and `%DB_IRISSYS:READ`, and its highest position is 20. A screen there that declares `%Admin_Operate:USE` and `%DB_IRISSYS:READ` needs no own pair. Security is `:87`, highest position 13.
- **Read-only analogs.**
  - `Screen/Descriptor/JournalFileDetails.cls:18-84` is a `detail` over a single-object `GET`, with a route-id criterion and a `parentScope`.
  - `ui/src/app/areas/os-management/process-details.page.ts` (322 lines) is the smallest bespoke detail page.
  - `ui/src/app/shell/detail-page.ts` renders a read only as a table.
- **Operator pins an LDAP screen would move.**
  - `src/OcuPilot/Test/WireSecurityRead.cls:90`: `OcuPilotWireOperate`, holding `%Admin_Operate:U` and `%DB_IRISSYS:R`.
  - `ui/src/app/shell/area-verdict.spec.ts:29-87`: `OPERATOR_MAP`, in which Security is gated.
- **The editor's form read.** `Area/Security/LdapRules.cls:543-595` (`HandleForm`) copies every key of the vendor `GET`. That `GET` never answers `LDAPSearchPassword` (measured).

## Tasks & Acceptance

None until the decision below. Option A needs no code, only the lead's bookkeeping: the ledger, `epics.md`, and the spine.

## Spec Change Log

## Review Triage Log

## Design Notes

**Measured at plan** (`ocupilot-ci`, 2026-10-07):

- **Setup.** The stock configuration `unknowndomain.com` was read by each principal. Every `OcuProbe1827*` principal was created, read as, and removed.

| Caller holds | Admin API `LIST` | Admin API `GET` | Classic read-only pages |
| --- | --- | --- | --- |
| `%Admin_Operate:U` | 500, `<PROTECT>` on `^oddCOM` in IRISSYS | 403, `<PROTECT>` | not tried |
| `%Admin_Operate:U`, `%DB_IRISSYS:R` | 500, `<INVALID OREF>` in `%Api.Admin.Util.ClassQuery` | 404, #822 Access Denied | not tried |
| the stock `%Operator` role | the same 500 | the same 404 | both fail: `<UNDEFINED>%OnGetPageName+2 *Properties("AutheEnabled")` |
| `%DB_IRISSYS:R` | 403 | 403 | not tried |
| `%Admin_Secure:U`, `%DB_IRISSYS:R` | 200 | 200 | not tried |
| `_SYSTEM` | 200 | 200 | both render |

- **OcuPilot's own port.** `AdminPort.Invoke` was called in process as `%Admin_Operate:U`, `%DB_IRISSYS:R` and `%DB_HSCUSTOM:R` (plus terminal access).
  - `LIST` answered 500 `INTERNAL` and logged at severity 2.
  - `GET` answered 404 `PORT.NOTFOUND`: the vendor's #822 was read as an absence.
- **Beneath the gate.** For that caller, `Security.LDAPConfigs:List` and `.Exists` answer #822. `%DB_IRISSECURITY` cannot be granted to a role (#1499).
- **The classic pages' own reads.**
  - The list's query, `%SYS.LDAP:List`, answered that caller no row. It answered `irisowner` one.
  - The detail reads through `%SYS.LDAP.Get`, which is `[Internal]` and adds `%All` with no check of the caller (`irissys/%SYS/LDAP.cls:1229-1236`).
- **The endpoint's gate.** `ResourcesOR()` admits `%Admin_Operate` for `LIST` and `GET` (read on the instance). The endpoint's own gate is therefore only a lower bound (AD-29).
- **End state.** No `OcuProbe1827*` principal remains. The only LDAP configuration is `unknowndomain.com`, unchanged. The monitor reads 0. The probe's two application-error entries were deleted. One severity-2 line from the in-process `LIST` stays in `messages.log`, which is append-only.

**Decision needed** (intent gap; AD-8):

- **A (recommended): close the story without building.**
  - On this build no vendor path serves an operator who holds only `%Admin_Operate`, the classic read-only pages included. Those pages are therefore no reason to keep the classic portal open.
  - The lead closes 18.27 by a Rule 5 amendment and records the finding under AD-8 (For the lead, item 1).
- **B: read through `%SYS.LDAP.Get`, plus an escalated list,** as an AD-27 named case behind `%Admin_Operate:USE` and `%DB_IRISSYS:READ`, which are what the classic menu checks.
  - This is an elevation to `%All` that OcuPilot starts, through an `[Internal]` method.
  - The list needs a second elevation, because `%SYS.LDAP:List` returns nothing.
  - AD-8's `%SYS.Ensemble` precedent covers a vendor method that checks the caller first. This method checks nothing.
  - It needs an AD-8 amendment from the owner. Not recommended.
- **C: hold the story until IRIS fixes these reads** (For the lead, item 3), re-owned to a later epic.

**Declined DW-1896.** It is a write to the LDAP editor (Story 16.14's `LdapUpdate`, `LdapSave` and `AdminPort`), and it needs its own AD-27 named case and Task 0. That puts it outside this story's read-only intent.

- It belongs with the next story that touches the LDAP editor, or with the standing cleanup story `23-5-the-range-end-cleanup-part-5`.
- The 2026-10-05 merge gate called it feature-sized, so the owner's routing decides.
- It needs a new owner whatever happens to 18.27.

**For the lead:**

1. **Spine (Rule 20, AD-8), for option A:** "**An LDAP configuration's read requires `%Admin_Secure:USE`** and `%DB_IRISSYS:READ` (measured on `ocupilot-ci`, 2026-10-07). `Security.LDAP`'s `ResourcesOR()` admits `%Admin_Operate` for `LIST` and `GET`, but `Security.LDAPConfigs` refuses that caller (#822), and the classic System Operation pages fail for it. OcuPilot builds no operator LDAP view (Story 18.27)."
2. **Correct at origin.** `spec-18-8-superservers-authentication-options-and-managed-file-transfe.md:364` and `epic-18-context.md:97` say the read serves `%Admin_Operate`. Only the endpoint's gate admits it; the read refuses it.
3. **IRIS defect candidates** (owner hold, not reported):
   - (a) `Security.LDAP` `LIST` and `GET` admit `%Admin_Operate` at the gate, then fail for that caller (500 `<INVALID OREF>`; 404 #822).
   - (b) `%CSP.UI.Portal.LDAPsRO` and `.LDAPRO` throw `<UNDEFINED>` in `%OnGetPageName` for a holder of `%Operator`, and `%SYS.LDAP:List` returns that caller no rows.
4. **Latent in OcuPilot (inference).** `AdminPort` answers the vendor's 404 #822 as `PORT.NOTFOUND`. No LDAP surface reaches it today, because each one gates `%Admin_Secure:USE` first.

**Governing ADs:**

- AD-2 and AD-27: the admin API only, and its named cases.
- AD-8: no elevation but AD-9's, and own pairs.
- AD-29: `ResourcesOR()` is a lower bound.
- AD-36: one read for the screen and the tool.
- AD-44: the classic pages `%CSP.UI.Portal.LDAPsRO` and `.LDAPRO`.
- AD-35: `LDAPSearchPassword` is never read.
- AD-13: `ldap-configuration` keeps `foldcase`.

**Integration ACs:** No consumers in this story, which introduces no module. Consumes: 16.14 (the LDAP list and editor). Consumed-by: none.

## Verification

**Manual checks:** none until the decision. `ocupilot-ci` reads as the End state above.

## Auto Run Result

Status: blocked
Blocking condition: intent gap: the criterion "each reads through the admin API" is unreachable for an operator who holds %Admin_Operate but not %Admin_Secure (measured on ocupilot-ci 2026-10-07: as %Admin_Operate plus %DB_IRISSYS:READ, and as the stock %Operator role, the admin API answers LIST 500 and GET 404 #822; the classic LDAPsRO and LDAPRO pages fail for %Operator too). The only remaining route is an elevation to %All through the internal %SYS.LDAP.Get, which AD-8 forbids. Decide: A (recommended) close 18.27 without building and record the finding under AD-8; B amend AD-8 for an AD-27 named case through %SYS.LDAP.Get; C hold the story until IRIS fixes these reads. DW-1896 is declined and needs a new owner.
