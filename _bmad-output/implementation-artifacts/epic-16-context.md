# Epic 16 Context: The remaining polish-week extras

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This is the voting-week work: the classic portal's remaining second-tier screens and actions, each reached by a person and by the agent through one operation. The epic closes with stories deferred from the contest build. The last three finish Release 1's two reduced editors, the full service editor and the full LDAP and Kerberos editor, and make egress visible on every turn through a data-egress line in the agent panel. **Nothing here may break a Release 1 screen or agent write**; anything that risks either waits for Stage 2.

- **Done:** 16.1 to 16.12 and 16.16 to 16.25. 16.12's merge waits on its CI run.
- **Remaining, on slot A, in order:** 16.13, 16.14, 16.15, then the epic close.

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

- **Every write tool.** A registry test fails on any gap in the following.
  - Its declared port has a `Snippet` for every `Invoke` branch.
  - A field the instance normalizes on save declares a read-back `compare` in its Classification entry.
  - Its entity type has a canonical-spelling rule. A type with no rule canonicalizes to itself.
  - It is measured with auditing on. Where IRIS records nothing, it is named as the next unaudited case in both AD-15 and AD-53. There are nine so far; the ninth is 16.11's Task Manager start.
  - Each classic page or Hidden dialog whose operation it performs beyond its descriptor's `classicPage` is named in `CLASSICPAGES`, read on the instance.
- **Governance key.** Through 2026-10-04, a new write key joins `Kernel/Governance/Baseline.cls` in the same change. It is enabled unless the criteria say disabled.
- **Refusal copy.** A self-protection sentence is published once in EXPERIENCE.md's Fixed strings. The kernel's reason is that sentence, pinned equal by a test.
- **Copy.** New strings go into Fixed strings and `ui/src/app/core/strings.ts` in the same change. Other suites cite EXPERIENCE.md (993 lines) and epics.md by line, so edit in place. Run `cd ui && npm run test:tools` after touching either.
- **Bundle.** `maximumWarning` is 2346kB and `maximumError` is 4000kB. A re-base updates the `angular-json.test.mjs` literal in the same change.
- **Tests.** One test-runner call at a time, never two in one message.
- **16.13, the service editor.**
  - **Coverage.** Enabled state, allowed IP addresses with add and delete, roles, and authentication methods.
  - **Disabling `%Service_WebGateway`,** the only service serving OcuPilot on this build. The screen draws the control disabled with "OcuPilot is served through this service. Turning it off would cut off every user, including you." Both callers are refused `PROHIBITED.SERVINGSERVICE` on the instance, and the agent's disable is never advertised as a tool.
  - **Address and authentication changes on that service are permitted.** They warn and refuse nothing.
    - The agent's proposal is minted destructive, with the line "OcuPilot itself is served through this service, so a change here can cut off every user, including you."
    - A person's Save shows the same line under the connection list.
    - Letting any other service admit unauthenticated connections carries "Anyone who reaches this service can use it without signing in."
  - **DW-1016.** An empty address list in a proposal diff row reads "Unrestricted", the Services column's `emptyKey` word, not "(none)".
  - **Exemption.** The story lifts `ServiceForm`'s classic-link exemption.
- **16.14, the LDAP and Kerberos editor.**
  - **Fields.** The editor covers the fields of the classic `%CSP.UI.Portal.LDAP`. Its `irislib/` export is the field list, and Kerberos appears there as a connection flag carried in `LDAPFlags`.
  - **Test authentication.** List, get and put stay synchronous. `Security.LDAP` `TEST` goes through `AdminPort`'s async path, which the slice sees as an ordinary call that resolves later, so the slice writes no polling. It reports the instance's own result text.
  - **Search password.** It travels only as a declared secret through `Security.LDAP` `CHANGEPWD`, AD-56's secret-only body (inference).
  - **DW-1639.** The list's Enabled column reads No for an enabled configuration, because the vendor LIST answers false. Derive it from `LDAPFlags` bit 64, or from `Security.LDAPConfigs:List`, as the reduced form does from GET.
  - **Exemption.** The story lifts `LdapConfigForm`'s classic-link exemption.
  - **Open questions (inference).** Settle each at the spec gate.
    - AD-39 names only the SSL/TLS test as screen-only instance text, so the LDAP test likely needs its own named case there.
    - Check whether AD-26's queued-write refusal classes `TEST` as mutating.
    - Check whether the `AsyncResult` poll needs `%Admin_Operate:USE` declared under AD-8's endpoint clause, as the audit copy and purge and the copy-mappings did.
    - `%CSP.UI.Portal.LDAPTest` exists in `irislib/` and is a `CLASSICPAGES` candidate for the test.
    - The spine's Deferred table still lists the LDAP test among Stage 2 async paths. Correct it at origin if 16.14 takes it.
- **16.15, the data-egress line.**
  - **The line.** On a turn with context sharing on, the panel names the provider in use and says whether screen data left the instance. For a local provider on a private network it says the data did not leave, matching the chip's absent egress pill.
  - **Source.** The line derives from the configuration the request actually uses, so it cannot disagree with the destination.
  - **Copy.** The line's copy is not in Fixed strings yet, so add it there and to `strings.ts`.
  - **DW-1076.** Add a fixture with a second enabled definition on a different endpoint host; `TurnWireFixture` has none today. Add a live browser leg in which the chip and the line follow a real default-marker move. Today that is pinned only at store level, in `agent-context.test.mjs`.
  - **DW-1192 (decided).** A Gemini endpoint with no `{model}` placeholder is allowed, but never silently: at minimum, log that the definition's Model is unused, and say so where the endpoint is edited. A create-time model validation rule stays deferred; the wire already refuses an unusable model as `PROVIDER.EGRESS`.
- **Epic-level DW-118.** Story 15.6 resolved it, so decline it with that reason.

## Technical Decisions

- **Two callers, one operation (AD-53, AD-55).**
  - A screen Save resolves through the same tool class as the agent's write. Today those are the reduced `Area/Permissions/ServiceSave` and `Area/Security/LdapSave`.
  - The screen caller mints no proposal and emits no marker. Read-only, the kill switch and governance do not gate it.
  - Both callers share the declared port, the fresh read, the prohibited set, privileges, the change event, the read-back and removal impact.
  - The prohibited set is judged by effect, never by payload shape, inside the single confirm transition (AD-10, AD-34, AD-40).
  - Governance is asked at dispatch and again at Confirm (AD-22).
  - The write base's `Write.ConfirmProblem` is asked inside the confirm transition, for a rule that must be judged again at Confirm (16.11, DW-1861).
- **Write kinds.**
  - **Merge (AD-4), both editors.** Read fresh, apply the diff and send the complete body. Neither `Security.Service` nor `Security.LDAP` is in AD-4's measured lists, so measure whether each keeps an omitted key and record it there (inference).
  - **Field lists (AD-3)** are derived, never typed by hand. A derived string field matching the credential pattern must be classified secret, or the build fails.
  - **Lists (AD-56).** A list field changes by a server-side delta over a fresh read, never by a client-computed list. A screen action accepts only the values its tool declares.
  - **Secrets (AD-56, AD-35).** A secret travels only as a declared secret argument. It is never stored in a proposal, diffed, logged or sent as screen context, and the confirm channel admits no other key.
  - **Create (AD-54).** The LDAP editor's Create fingerprints the target's absence under its canonical spelling, whether or not the PUT upserts. Measure whether it does.
  - **Read-back (AD-58).** Sent top-level keys are compared, and a secret is reported written, never read back. A 202 continuation reads `unchecked`.
- **Async (AD-26), 16.14.** An endpoint is async per request type, never per class, and `Security.LDAP` is async for its test connection only.
  - The port polls `AsyncResult` once, with a bounded wait that fails `PORT.TIMEOUT` and never gives a partial result.
  - A mutating type that would queue is refused unless it is on `QUEUEDWRITES`.
  - A finished task's result is read once. A second `async-result` read logs #7846 and turns the instance to Warning.
- **Privilege (AD-8, AD-29).**
  - Pairs are checked at call time. An administrative resource is required at `USE`, never `WRITE`.
  - **Known sets.** Services and LDAP both use `%Admin_Secure:USE` and `%DB_IRISSYS:READ`. The classic pages are the service editor `%CSP.UI.Portal.Dialog.Service` (list `%CSP.UI.Portal.Services`) and the LDAP editor `%CSP.UI.Portal.LDAP` (list `%CSP.UI.Portal.LDAPs`).
  - **Extra pairs.** A tool declares a pair beyond its screen's set only when its vendor class writes a database the screen's read does not, or an endpoint its call must reach names that resource (an async poll among them). Name each new case in AD-8. A caller without it is refused by name before any port call.
  - **Establishing a set.** Read the backing class's own check in `irislib/`, then run a least-privileged principal on the throwaway. Never use `%Operator` to prove a denial.
- **Classic-link exemptions (AD-44).** Exactly two remain, declared by `ServiceForm` and `LdapConfigForm` and counted against SM-C1. 16.13 and 16.14 each remove one and amend AD-44's count at its origin: two, then one, then zero.
- **Provider egress (AD-42), 16.15.**
  - A configured proxy is a destination, judged by the same policy. A marked-local endpoint bypasses any proxy and is not judged against it. A cloud metadata endpoint is refused even when marked local.
  - The chip's "leaves the instance" statement is computed from the configuration the call uses. Story 10.3 pins that server-side `LeavesInstance` computation in `Test/EgressLocal`. The line reuses it rather than computing a second answer (inference).
  - Moving the default marker is a security change, because it selects a turn's endpoint and credential.
  - The context-sharing toggle is remembered per user, falling back to the instance default (AD-24).
- **Spine amendments of 2026-09-30.** They are precedents for naming a new case: each is a named entry, never a general license.
  - **16.11.** AD-5's banner case names its action and the read answers `bannerRequires`. AD-8 gives `tasks.schedule.startmanager` `%Admin_Secure:USE`. AD-15 and AD-53 record the ninth unaudited write.
  - **16.12.** AD-2 leaves a `Lock` `DELETE` 409 unlogged; AD-5 adds a row target's `unless`; AD-8 adds `%DB_IRISSYS:WRITE`; AD-10 adds `PROHIBITED.OCUPILOTLOCK`; AD-44 names `%CSP.UI.Portal.Locks`; AD-51 and AD-52 name `LockPort`.
  - **DW-1868 (decision-pending).** Whether an owner-scope lock removal re-lists before each `DELETE` goes to Epic 16's decision sheet.

## UX & Interaction Patterns

- **The two editors** are tabbed form pages at side-bar position 0. The tabs mirror the classic tab names, one Save applies every tab, and a validation error switches to the tab holding it. The service editor opens from the Services name cell; the LDAP editor from its name cell and the command bar's Create.
- **The LDAP test** is a dialog attached to the editor (a P1 row in the UX screen inventory).
- **The egress line** appears in the agent panel once per turn, beside the context chip.
  - The chip reads `<Screen>, <NAMESPACE> · <N rows> · <provider> · <endpoint host>`, plus a "leaves the instance" pill when the host is not private.
  - Color never carries egress alone.
- **Dialogs and controls.** A dialog is one level deep, titled with the action and target, and a destructive one asks for the typed name. A gated control uses `aria-disabled` with "Requires <resource>".
- **A stale UX row.** EXPERIENCE.md's "Warning before a write" row still lists a warning before disabling OcuPilot's web service. AD-10 and 16.13's amended criterion govern: the control is drawn disabled.

## Cross-Story Dependencies

- **Within the epic and beyond.**
  - **16.13 and 16.14** replace Story 9.9's reduced forms and extend their Save tools and held fixtures.
  - **16.15** builds on the context chip (`ui/src/app/shell/context-chip.ts`), Story 4.11's re-read of the agent definition, and Story 10.3's egress computation.
  - **Keep intact.** 16.6's shared multi-select table, 16.8's shared log viewer, and Epic 14's baseline, sanitizer and per-user read-only.
  - **DW-1827 is decided.** `tasks.schedule.import` ships disabled by default.
- **Slot B.**
  - **Its queue.** Story 23.2 merges batch by batch. Batches (a) and (b) have merged; (c) is security, DW-1663 and DW-1450; (d) is DW-48. Epic 18 resumes with 18.15 after 23.2.
  - **Before editing a file,** check whether `.worktrees/epic-23` changes it: `diff --stat` against feature, plus `status -s`. Edit a contended file add-only, and stop and ask otherwise.
  - **Shared rosters** are unioned at each merge, so keep edits to them additive. They are `EntityType`, the `Prohibited` codes and covered types, the `AdminPort` type lists (`QUEUEDWRITES` among them), the `CLASSICPAGES` rosters, the baseline and the screen mirror.
- **Slot A.** It uses `ocupilot-slot-a` and the `ocupilot-ci` throwaway (52776/1975).
- **Release 1.0.4.** It is cut 2026-09-30 at 14:00 PDT, and whatever is green on feature then ships.
- **Epic close.** After 16.15, the Rule 27 burn-down gate runs.
  - It charters only entries that block the next release or a downstream story, plus CI flakes. DW-1867, the language-server-editor browser flake, was filed for this close.
  - Every other entry is re-owned to `range-end-cleanup`, and DW-1868 goes to the decision sheet.
  - Epic 19 follows on slot A.
