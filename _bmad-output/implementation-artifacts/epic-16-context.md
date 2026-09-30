# Epic 16 Context: The remaining polish-week extras

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This is the voting-week work: the classic portal's remaining second-tier screens and actions, each reached by a person and the agent through one operation. The epic closes with stories deferred from the contest build: lock removal, the full service editor, the full LDAP and Kerberos editor, and a per-turn data-egress line. **Nothing here may break a Release 1 screen or agent write**; anything that risks either waits for Stage 2.

- **Done:** 16.1 to 16.11 and 16.16 to 16.25.
- **Remaining, on slot A, in epics.md order:** 16.12, 16.13, 16.14, 16.15, then the epic close.

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

- **Every write tool.** A test fails on any gap in the following.
  - Its declared port has a `Snippet` for every `Invoke` branch.
  - A field the instance normalizes on save declares a read-back `compare`.
  - Its entity type has a canonical-spelling rule. A type with no rule canonicalizes to itself.
  - It is measured with auditing on. Where IRIS records nothing, it is named as the next unaudited case in both AD-15 and AD-53. There are nine so far; the ninth is 16.11's Start Task Manager (`Task.Manager` `RUN`).
  - Each classic page (or Hidden dialog) whose operation it performs beyond its descriptor's `classicPage` is named in `CLASSICPAGES`, read on the instance.
- **Governance key.** Through 2026-10-04, a new write key joins `Kernel/Governance/Baseline.cls` in the same change. It is enabled unless the criteria say disabled.
- **Prohibited arms.** A refusal sentence is published once in EXPERIENCE.md's Fixed strings. The kernel's reason is that sentence, pinned equal by a test. The Guardrails page reads the prohibited set.
- **Copy.** New strings go into Fixed strings and `strings.ts` in the same change. Other suites cite EXPERIENCE.md (993 lines) and epics.md by line, so edit in place. Run `cd ui && npm run test:tools` after touching either.
- **Bundle.** `maximumWarning` is 2346kB (5% above the 2,234,284 bytes measured at the 1.0.3 staging); `maximumError` is 4000kB. A re-base updates the `angular-json.test.mjs` literal in the same change.
- **Tests.** One test-runner call at a time, never two in one message.
- **16.12, lock removal.**
  - **Scopes.** The dialog offers this lock, every lock of the owning process, and every lock from a remote client. Each scope names what it will remove.
  - **Tool shape.** `Lock` publishes no body template, so the tool is action-style. The vendor route is `Lock` `DELETE /lock`.
  - **DW-1073.** Warn when the owning process is in a transaction. Take the warning from the endpoint's own 409 "is currently in a transaction" refusal, never from a `$zu` probe. The classic Manage Locks page asks the same before its Remove confirm, and the check belongs at the confirm, not in the list read.
  - **DW-1074.** A row whose owner is remote (`RemoteOwner` true) has no local pid, so suppress its link to Process details. The branch is read from vendor source; observing it needs an ECP client.
- **16.13, the service editor.**
  - **Coverage.** Enabled state, allowed IP addresses with add and delete, roles, and authentication methods.
  - **Disabling `%Service_WebGateway`.** The control is drawn disabled with the published sentence "OcuPilot is served through this service. Turning it off would cut off every user, including you." Both callers are refused `PROHIBITED.SERVINGSERVICE` on the instance. The agent's disable is never advertised as a tool.
  - **Address and authentication changes on that service** are permitted. The agent's proposal is minted destructive, with a consequence line saying OcuPilot is served through this service.
  - **DW-1016.** An empty address list in a proposal diff row reads "Unrestricted", the Services column's word, not "(none)".
  - **Exemption.** The story lifts `ServiceForm`'s classic-link exemption.
- **16.14, the LDAP and Kerberos editor.**
  - **Fields.** The editor covers the fields of the classic LDAP page, `%CSP.UI.Portal.LDAP`. Its exported source in `irislib/` is the field list.
  - **Test.** List, get and put stay synchronous. Test authentication (`Security.LDAP` `TEST`, `POST /security/ldap/test`) goes through `AdminPort`'s async path, which resolves later with no polling in the slice. It reports the instance's own result text.
  - **Search password.** It travels only through `Security.LDAP` `CHANGEPWD` (`POST .../search-password`). That is AD-56's secret-only body (inference).
  - **DW-1639.** The list's Enabled column reads No for an enabled configuration. Derive it from `LDAPFlags` bit 64, or from `Security.LDAPConfigs:List`, as the reduced form does from GET.
  - **Exemption.** The story lifts `LdapConfigForm`'s classic-link exemption.
  - **Open questions (inference).**
    - AD-39 names only the SSL/TLS test as screen-only instance text, so this test likely needs its own named case there.
    - Check whether AD-26's queued-write refusal classes `TEST` as mutating.
    - Check whether the `AsyncResult` poll needs `%Admin_Operate:USE` declared under AD-8's endpoint clause, as the audit copy and purge and the copy-mappings did.
    - `%CSP.UI.Portal.LDAPTest` exists in `irislib/` and is a `CLASSICPAGES` candidate.
- **16.15, the data-egress line.**
  - **The line.** On a turn with context sharing on, the panel names the provider in use and says whether screen data left the instance. For a local provider on a private network it says the data did not leave, matching the chip's absent egress pill.
  - **Source.** The line derives from the configuration the request actually uses, so it cannot disagree with the destination.
  - **DW-1076.** Add a fixture with a second enabled definition on a different endpoint host; `TurnWireFixture` has none today. Add a live browser leg in which the chip and the line follow a real default-marker move. Today that is pinned only at the store level.
  - **DW-1192 (decided).** A Gemini endpoint with no `{model}` placeholder is allowed, but never silently. At minimum, log that the definition's Model is unused, and say so where the endpoint is edited. A create-time model validation rule stays deferred; the wire already refuses an unusable model as `PROVIDER.EGRESS`.
- **Epic-level DW-118.** Story 15.6 resolved it, so decline it with that reason.

## Technical Decisions

- **Spine amendments for 16.11 (2026-09-30).**
  - **AD-5.** A banner case may name the one row action it offers, and the read answers `bannerRequires`.
  - **AD-8.** `tasks.schedule.startmanager` declares `%Admin_Secure:USE`.
  - **AD-15 and AD-53.** `Task.Manager` `RUN` is the ninth unaudited write.
  - **Confirm hook.** The write base gained `Write.ConfirmProblem`, asked inside the confirm transition. 16.11 uses it to judge a task type's privilege again at Confirm.
- **Two callers, one operation (AD-53, AD-55).**
  - A screen action or Save resolves through the same tool class as the agent's write.
  - The screen caller mints no proposal and emits no marker, and read-only and the kill switch do not gate it.
  - Both callers share the port, the fresh read, the prohibited set, privileges, the change event, the read-back and removal impact.
- **Write kinds.**
  - **Merge (AD-4), 16.13 and 16.14.** Read fresh, apply the diff and send the complete body. Neither `Security.Service` nor `Security.LDAP` is in AD-4's measured lists, so measure whether each keeps an omitted key (inference).
  - **Action-style (AD-51), 16.12.** The tool declares its request type, derives an empty field list and sends no body.
    - It fingerprints a declared subject: every field the action's precondition reads, drawn from what its read type answers. Identity is not required.
    - A vendor body or query carrying a caller's choice, such as the removal scope, is built by the tool's declared port from declared non-secret arguments. Each such port is a new named entry in AD-51.
  - **Create (AD-54).** The LDAP editor's Create fingerprints the target's absence, whether or not the PUT upserts.
  - **Secrets and lists (AD-56).** A secret travels only as a declared secret argument and is never stored, diffed or logged. A list field changes by a server-side delta over a fresh read, never by a client-computed list.
  - **Read-back (AD-58).** A secret is reported written and is never read back. A 202 continuation reads `unchecked`.
- **Gates.**
  - The prohibited set is judged by effect, never by payload shape, inside the single confirm transition, for both callers (AD-10, AD-34, AD-40).
  - Governance is asked at dispatch and again at Confirm (AD-22).
  - A read answered 404 logs nothing and still yields `PORT.NOTFOUND`. A write answered 404 is logged (AD-2).
- **Async (AD-26).** An endpoint is async per request type, never per class.
  - The port polls `AsyncResult` once, with a bounded wait that fails `PORT.TIMEOUT` and never gives a partial result.
  - A mutating type that would queue is refused unless it is on `QUEUEDWRITES`.
  - A finished task's result is read once. A second `async-result` read logs #7846 and turns the instance to Warning.
- **Privilege (AD-8, AD-29).**
  - Pairs are checked at call time. An administrative resource is required at `USE`, never `WRITE`.
  - **Establishing a set.** Read the backing class's own check in `irislib/`, then run a least-privileged principal on the throwaway. Never use `%Operator` to prove a denial.
  - **Extra pairs.** A tool declares a pair beyond its screen's set only when its vendor class writes a database the screen's read does not, or when a vendor endpoint its call must reach (an async poll among them) names that resource. Name each new case in AD-8. A caller without it is refused by name before any port call.
  - **Known sets.**
    - Locks: `%Admin_Operate:USE` and `%DB_IRISSYS:READ`, classic page `%CSP.UI.Portal.LocksView`.
    - Services, in Permissions: `%Admin_Secure:USE` and `%DB_IRISSYS:READ`, classic page `%CSP.UI.Portal.Dialog.Service`.
    - LDAP: the same two pairs, classic page `%CSP.UI.Portal.LDAP`.
    - The Manage Locks page `%CSP.UI.Portal.Locks` is a `CLASSICPAGES` candidate for 16.12 (inference).
- **Classic-link exemptions (AD-44).** Exactly two remain, declared by `ServiceForm` and `LdapConfigForm` and counted against SM-C1. 16.13 and 16.14 each remove one and amend AD-44's count at its origin: two, then one, then zero.
- **Provider egress (AD-42), 16.15.** The chip and the line are computed from the one configuration the turn's provider call uses.
  - A marked-local endpoint bypasses any proxy and is not judged against it.
  - A configured proxy is a destination, judged by the same policy.
  - A cloud metadata endpoint is refused even when the definition is marked local.
  - Moving the default marker is a security change, because it selects a turn's endpoint and credential.
  - Story 10.3 pins the server-side `LeavesInstance` computation in `Test/EgressLocal`.

## UX & Interaction Patterns

- **Placement.**
  - **Remove locks** is a dialog from the Locks row overflow menu. The dialog warns when the owner is in a transaction.
  - **The service and LDAP editors** are tabbed form pages. The tabs mirror the classic tab names, one Save applies every tab, and a validation error switches to the tab holding it.
  - **Opening the editors.** The service editor opens from the Services name cell. The LDAP editor opens from its name cell and from the command bar's Create.
  - **The egress line** appears in the agent panel once per turn, beside the context chip's provider, host and "leaves the instance" pill. Color never carries it alone.
- **Dialogs and controls.** A dialog is one level deep, titled with the action and target, and a destructive one asks for the typed name. A gated control uses `aria-disabled` with "Requires <resource>".
- **A stale UX row.** EXPERIENCE.md's "Warning before a write" row still lists a warning before disabling OcuPilot's web service. AD-10 and 16.13's amended criterion govern: the control is drawn disabled.

## Cross-Story Dependencies

- **Keep intact.** 16.6's shared multi-select table, 16.8's shared log viewer, and Epic 14's baseline, sanitizer and per-user read-only.
- **Within the epic and beyond.**
  - **16.12** extends Story 6.10's Locks list and its cross-screen row target to Process details (AD-5). A change to that target is validated alike by `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs`.
  - **16.13 and 16.14** replace Story 9.9's reduced forms and extend their Save tools: `Area/Permissions/ServiceSave` and `Area/Security/LdapSave`, with their held fixtures.
  - **16.15** builds on the context chip (`ui/src/app/shell/context-chip.ts`) and Story 10.3's egress computation.
  - **DW-1827 is decided.** `tasks.schedule.import` ships disabled by default, and no later story re-decides it.
- **Slot B.** Story 23.2 runs on slot B and merges batch by batch; Epic 18 is paused until 23.2 finishes, then resumes with 18.15.
  - **Before editing a file,** check whether `.worktrees/epic-23` changes it: `diff --stat` against feature, plus `status -s`. Edit a contended file add-only, and stop and ask otherwise.
  - **Shared rosters** are unioned at each merge, so keep edits to them additive. They are `EntityType`, the `Prohibited` codes and covered types, the `AdminPort` type lists, the `CLASSICPAGES` rosters, the baseline and the screen mirror.
- **Slot A.** It uses `ocupilot-slot-a` and the `ocupilot-ci` throwaway (52776/1975). `%SYS` application errors may be purged on `ocupilot-ci` only, through the vendor's own purge.
- **Release 1.0.4.** It is cut Wed 2026-09-30 at 14:00 PDT.
  - No story starts after 12:00 unless it reaches its boundary by 14:00.
  - A done story with green CI on its exact head merges, and one in progress waits.
- **Epic close.** After 16.15, the Rule 27 burn-down gate runs.
  - It charters only entries that block the next release or a downstream story, plus CI flakes.
  - Every other entry is re-owned to `range-end-cleanup`.
  - Epic 19 follows on slot A.
