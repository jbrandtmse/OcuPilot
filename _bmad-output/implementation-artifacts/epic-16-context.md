# Epic 16 Context: The remaining polish-week extras

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Voting-week work: the classic portal's remaining second-tier screens and actions, each reached by a person and by the agent through one operation, closing with stories deferred from the contest build. The last two finish Release 1's reduced LDAP form as the full LDAP and Kerberos editor, and make egress visible on every turn through a data-egress line in the agent panel. **Nothing here may break a Release 1 screen or agent write**; anything that risks either waits for Stage 2. Each screen is one descriptor with its derived read tool, and each action ships with its confirmed write tool and joins Epic 14's governance baseline.

- **Done:** 16.1 to 16.13 and 16.16 to 16.25. 16.13 is committed and its merge waits on its CI run.
- **Remaining, on slot A, in order:** 16.14, 16.15, then the epic close.

## Stories

- Story 16.1: The try-it request console
- Story 16.2: Web sessions, listed and ended
- Story 16.3: Effective privileges and the permission-check tool
- Story 16.4: Task export and import
- Story 16.5: Background tasks
- Story 16.6: Broadcast a message to processes
- Story 16.7: License usage and the full dashboard
- Story 16.8: The six secondary log viewers
- Story 16.9: The unified log hub
- Story 16.10: External language servers
- Story 16.11: Start, suspend and resume the Task Manager
- Story 16.12: Remove locks - one, all of a process, all of a remote client
- Story 16.13: The service editor
- Story 16.14: The LDAP and Kerberos editor
- Story 16.15: The data-egress line
- Story 16.16: The agent audit viewer
- Story 16.17: The read-back line
- Story 16.18: Home's performance row
- Story 16.19: Impact lines on removals
- Story 16.20: Older messages.log files
- Story 16.21: Security findings, with a fix you confirm
- Story 16.22: The Guardrails page
- Story 16.23: Any table, downloaded as CSV
- Story 16.24: A try-it request, copied as curl
- Story 16.25: The external language server editor

## Requirements & Constraints

### Every story

- **Every write tool.** A registry test fails on any gap in the following.
  - Its declared port has a `Snippet` for every `Invoke` branch (AD-59).
  - A field the instance normalizes on save declares a read-back `compare` in its Classification entry (AD-58).
  - Its entity type has a canonical-spelling rule.
  - It is measured with auditing on. Where IRIS records nothing, it is named as the next unaudited case in both AD-15 and AD-53. There are nine so far; the ninth is 16.11's Task Manager start.
  - Each classic page or Hidden dialog whose operation it performs beyond its descriptor's `classicPage` is named in `CLASSICPAGES`, read on the instance.
- **Governance key.** Through 2026-10-04, a new write key joins `Kernel/Governance/Baseline.cls` in the same change. It is enabled unless the criteria say disabled.
- **Refusal copy.** A self-protection sentence is published once in EXPERIENCE.md's Fixed strings. The kernel's reason is that sentence, pinned equal by a test.
- **Copy.** New strings go into Fixed strings and `ui/src/app/core/strings.ts` together. EXPERIENCE.md (993 lines) and epics.md are cited by line: edit in place, then `cd ui && npm run test:tools`.
- **Bundle.** 16.13 left it at 2,349,254 B against `maximumWarning` 2350kB (`maximumError` 4000kB). A re-base updates the `angular-json.test.mjs` literal in the same change.
- **Tests.** One test-runner call at a time, never two in one message.
- **DW-118 (epic-level).** Story 15.6 resolved it; decline it with that reason.

### 16.14, the LDAP and Kerberos editor

- **Fields.** The editor covers the fields of the classic `%CSP.UI.Portal.LDAP`; its `irislib/` export is the field list. Kerberos is not a separate object there: it is a hidden, disabled `KerberosConnection` flag carried in `LDAPFlags` (`$$$LDAPKerberosOnly`), beside bit 64, which means enabled.
- **No classic tabs.** The classic page is one form with an "Advanced Settings" toggle over the group-name prefixes (read in `irislib/`), while the UX asks for tabs mirroring the classic tab names. Settle the grouping at the spec gate (inference).
- **Test authentication.** List, get and put stay synchronous. `Security.LDAP`'s test goes through `AdminPort`'s async path, which the slice sees as an ordinary call that resolves later, so the slice writes no polling. It reports the instance's own result text.
- **Measured by 9.9 on `Security.LDAP`.** A PUT keeps an omitted key, and creates the configuration when the name is absent (an upsert). `LDAPSearchPassword` is not in the template and GET never answers it. `LDAPCACertFile` is outside `security.ldap.update`'s permitted fields under AD-21.
- **Search password.** It is a secret: supplied at the write, never stored, diffed, logged or sent as context. The classic page offers Enter new, Clear and Leave as is. It travels only as a declared secret argument in a secret-only body (AD-56 (i)), through the vendor's password request type, `CHANGEPWD` as on `Security.User` (inference; read the type list on the instance).
- **CA certificate file.** It is a server path. By AD-21's SSL/TLS precedent it is shown, never set.
- **Create.** The list's command-bar Create fingerprints the target's absence under its canonical spelling (AD-54), and the upsert makes that load-bearing.
- **DW-1639.** The list's Enabled column reads No for an enabled configuration, because the vendor LIST answers false. Derive it from `LDAPFlags` bit 64, or from `Security.LDAPConfigs:List`, as the reduced form does from GET.
- **Exemption.** The story lifts `LdapConfigForm`'s classic-link exemption.
- **Open questions (inference).** Settle each at the spec gate.
  - The classic test, `%CSP.UI.Portal.LDAPTest`, asks a Username and Password and JOBs `TESTBACKGROUND1^%SYS.LDAP`. If the async `TEST` body carries the password into the vendor's task row, that is the exposure AD-26's queued-write refusal exists for (AD-35, DW-1279). Settle that, and whether `TEST` classes as mutating, which is refused unless on `QUEUEDWRITES`.
  - AD-39 names only the SSL/TLS test's result text as screen-only instance text. The LDAP test needs its own named case: the screen only, never the model, a tool result, the ledger, an audit payload or a log line.
  - The `AsyncResult` poll likely needs `%Admin_Operate:USE` under AD-8's endpoint clause, as audit copy and purge did; `%CSP.UI.Portal.LDAPTest` is a `CLASSICPAGES` candidate.
  - AD-26 and the spine's Deferred table still list the LDAP test among Stage 2 async paths. Correct both at origin if 16.14 takes it. AD-4 should record 9.9's `Security.LDAP` measurement (kept keys, upsert), as 16.13 recorded `Security.Service`.

### 16.15, the data-egress line

- **The line.** On a turn with context sharing on, the panel names the provider in use and says whether screen data left the instance. For a local provider on a private network it says the data did not leave, matching the chip's absent egress pill.
- **Source.** The line derives from the configuration that turn's request actually used, so it cannot disagree with the destination.
- **Copy.** EXPERIENCE.md has no row for the line yet, so add its copy and placement there and add the copy to `strings.ts`.
- **DW-1076.** Add a fixture with a second enabled definition on a different endpoint host; `Test/TurnWireFixture` has none today. Add a live browser leg in which the chip and the line follow a real default-marker move. Today that is pinned only at store level, in `ui/tools/agent-context.test.mjs`.
- **DW-1192 (decided).** A Gemini endpoint with no `{model}` placeholder is allowed, but never silently: at minimum, log that the definition's Model is unused, and say so on the Definition form where the endpoint is edited. A create-time model validation rule stays deferred; the wire already refuses an unusable model as `PROVIDER.EGRESS`.

## Technical Decisions

- **Two callers, one operation (AD-53, AD-55).**
  - A screen Save resolves through the same tool class as the agent's write. For LDAP today that is `security.ldap.update`, reached by `Area/Security/LdapSave` with `LdapRules` (`GET /ldap/form`, `PUT /ldap/:id`).
  - The screen caller mints no proposal, emits no marker, and is not gated by read-only, the kill switch or governance.
  - Both callers share the port, the fresh read, the prohibited set (judged by effect, never payload shape, inside the confirm transition), privileges, the change event, the read-back and removal impact.
  - Governance is asked at dispatch and again at Confirm (AD-22). `Write.ConfirmProblem` re-judges a rule inside the confirm transition (16.11, DW-1861).
  - A confirm and a row action hold the target's lock from the fresh read through the read-back, refusing 409 `WRITE.TARGETBUSY` after 10 s (AD-34). A screen Save does not hold it yet (DW-1882, range-end cleanup).
- **Write kinds.**
  - **Merge (AD-4).** Read fresh, apply the diff and send the complete set. A form Save merges its changed fields over its own fresh read and sends a list field whole (16.13's decision); AD-56 (ii)'s server-side delta binds a screen action route, not a form Save.
  - **Field lists (AD-3)** are derived, never typed by hand. A derived string field matching the credential pattern must be classified secret, or the build fails.
  - **Secrets (AD-56, AD-35).** A secret travels only as a declared secret argument, and the confirm channel admits no other key. The read-back reports it written and never reads it (AD-58).
  - **Create (AD-54).** The fresh read must find the target absent, and Confirm re-reads it.
  - **Async (AD-26).** Async is per request type, never per class. The port's one poller waits a bound that fails `PORT.TIMEOUT`, never partial, and reads a finished result once (a second read logs #7846). A mutating type that would queue is refused unless on `QUEUEDWRITES`.
- **Privilege (AD-8, AD-29).**
  - Pairs are checked at call time. An administrative resource is required at `USE`, never `WRITE`.
  - The LDAP screens use `%Admin_Secure:USE` and `%DB_IRISSYS:READ`. Their classic pages are the list `%CSP.UI.Portal.LDAPs` and the editor `%CSP.UI.Portal.LDAP`.
  - An extra pair is declared only when the vendor class writes a database the screen's read does not, or an endpoint the call must reach (an async poll included) names it; each case is named in AD-8 and refused by name before any port call.
  - Establish a set from the backing class's check in `irislib/` plus a least-privileged principal on the throwaway, never `%Operator`.
- **Classic-link exemptions (AD-44).** One remains, `LdapConfigForm`'s, so SM-C1 counts one. 16.14 removes it and amends AD-44's count at its origin to zero.
- **Provider egress (AD-42, AD-24), 16.15.**
  - `leavesInstance` is computed once, on the instance: `Api/Context` calls `ProviderPort.ResolveEndpoint`, then `Egress.LeavesInstance`, pinned by `Test/EgressLocal`. The chip's pill is `leavesInstance() === true`. The line reuses that computation for the turn's own definition rather than computing a second answer (inference).
  - A proxy is a destination judged by the same policy; a marked-local endpoint bypasses it; a cloud metadata endpoint is refused even when marked local.
  - Moving the default marker is a security change, because it selects a turn's endpoint and credential. The client's agent context re-reads on agent-definition and agent-switch events.
  - The sharing toggle is per user, falling back to the instance default; secret-typed fields are never sent.
- **Spine amendments of 2026-09-30.** They are precedents for naming a new case: each is a named entry, never a general license.
  - **16.11:** AD-5 banner `action`; AD-8 `%Admin_Secure:USE` on the Task Manager start; AD-15 and AD-53's ninth unaudited write.
  - **16.12:** AD-2 unlogged `Lock` 409; AD-5 row-target `unless`; AD-8 `%DB_IRISSYS:WRITE`; AD-10 `PROHIBITED.OCUPILOTLOCK`; AD-44 and AD-51 entries; AD-52 re-list before each `DELETE` (DW-1868).
  - **16.13:** AD-4 `Security.Service` measured; AD-44 counts one; Conventions `EMPTYKEYS`; Deferred DW-1883.

## UX & Interaction Patterns

- **The LDAP editor** is a form page at side-bar position 0, opened from the list's name cell and the command bar's Create. Fields come in the classic order under a sticky Save and Cancel. If tabs are used, one Save applies every tab, a validation error switches to the tab holding it, and a tab with errors adds ", N errors" to its accessible name.
- **The LDAP test** is a dialog on the editor (P1 in the screen inventory), titled with the action and target. The SSL/TLS test panel is the precedent: "The instance connected." or "The instance could not connect." over the instance's own lines.
- **The search password** uses the write-only masked-secret field ("Stored. Enter a new value to replace it." after save).
- **Existing LDAP copy** (the reduced form's strings and both screens' suggested prompts) is in Fixed strings; reuse it in place.
- **The chip** reads `<Screen>, <NAMESPACE> · <N rows> · <provider> · <endpoint host>`, plus a "leaves the instance" pill when the host is not private. Sharing off, it reads "Screen context off — nothing from this screen is sent."
- **Color never carries egress alone**, and a gated control uses `aria-disabled` with "Requires <resource>".

## Cross-Story Dependencies

- **Within the epic and beyond.**
  - **16.14** replaces Story 9.9's reduced `LdapConfigForm` and extends `LdapUpdate`, `LdapSave`, `LdapRules` and their held fixtures. LDAP tests create `OcuP99*` configurations through `Security.LDAPConfigs` in `%SYS` and delete each after checking its exact name.
  - **16.15** builds on the context chip (`ui/src/app/shell/context-chip.ts`), Story 4.11's re-read of the agent definition, and Story 10.3's egress computation.
  - **Keep intact:** 16.6's multi-select table, 16.8's log viewer, Epic 14's baseline, sanitizer and per-user read-only.
- **Slot B.**
  - **Worktrees** `.worktrees/epic-23` and `.worktrees/epic-18`: before editing a file, check both (`diff --stat` against feature, `status -s`); edit a contended file add-only, else stop and ask. 16.13 found `Kernel/Proposal/Prohibited.cls` held by Epic 23.
  - **Shared rosters** are unioned at each merge, so keep edits to them additive. They are `EntityType`, the `Prohibited` codes and covered types, the `AdminPort` type lists (`MUTATINGTYPES` and `QUEUEDWRITES` among them), the `CLASSICPAGES` rosters, the baseline and the screen mirror.
- **Slot A.** It uses `ocupilot-slot-a` and the `ocupilot-ci` throwaway (52776/1975).
- **Release 1.0.5** is cut 2026-10-01 at 14:00 PDT (story-start cutoff 12:00); whatever is green on feature ships.
- **Epic close.** After 16.15, the Rule 27 burn-down gate runs.
  - It charters only entries that block the next release or a downstream story, plus CI flakes. DW-1867, the language-server-editor browser flake, was filed for this close.
  - DW-1883, whether the service editor draws `HttpOnlyCookies`, goes to Epic 16's decision sheet. Every other entry is re-owned to `range-end-cleanup`.
  - Epic 19 follows on slot A, while Epic 18 continues on slot B.
