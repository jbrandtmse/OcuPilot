# Epic 16 Context: The remaining polish-week extras

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This is the voting-week work. It gives the classic portal's remaining second-tier screens and actions an OcuPilot equivalent that a person and the agent both use. The epic closes with five stories deferred from the contest build: Task Manager control, lock removal, the full service editor, the full LDAP and Kerberos editor, and a per-turn data-egress line. **Nothing here may break a Release 1 screen or a Release 1 agent write.** Anything that risks either waits for Stage 2.

- **Done:** 16.1 to 16.10 and 16.16 to 16.25.
- **Remaining, on slot A, in epics.md order:** 16.11, 16.12, 16.13, 16.14, 16.15, then the epic close.

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

- **Every story.**
  - **Screens.** A screen is one hand-written descriptor with its derived read tool and at least three grouped suggested prompts. It enters the side bar only once built, and an editor paired with its own list takes `sideBarPosition` 0. A screen-adding story extends every browser spec pinning its area's side-bar list (`grep -l ocu-side-bar-label ui/browser`).
  - **Governance key.** An action ships with its confirmed write tool. Through 2026-10-04 its key joins `Kernel/Governance/Baseline.cls` in the same change, enabled unless the criteria say disabled.
  - **Each write tool** meets all of the following, and a test fails on any gap:
    - Its port has a `Snippet` for every `Invoke` branch.
    - A field the instance normalizes on save declares a read-back `compare`.
    - Its entity type gets a canonical-spelling rule. A type with no rule canonicalizes to itself.
    - It is measured with auditing on. Where IRIS records nothing, it is named as the next unaudited case in both AD-15 and AD-53. There are eight so far; the seventh and eighth are 18.4's Add a volume and integrity check.
    - Each classic page (and Hidden dialog) whose operation it performs beyond its descriptor's own page is named in `CLASSICPAGES`, read on the instance.
  - **Prohibited arms.** A new arm needs reason text, because the Guardrails page is generated from the prohibited set. Its sentence is published once in Fixed strings and pinned equal to the kernel's reason.
- **Copy.** New strings go into EXPERIENCE.md's Fixed strings and `strings.ts` in the same change. Edit EXPERIENCE.md in place so it stays at 993 lines. After touching it or epics.md, run `cd ui && npm run test:tools`.
- **Bundle.** `maximumWarning` is 2346kB, 5% above the 2,234,284 bytes measured at the 1.0.3 staging. 16.25 measured 2.27 MB.
  - Crossing the warning re-bases it to about 5% above the measured total, with the `angular-json.test.mjs` literal updated in the same change.
  - Stop and ask above 3800kB. The hard stop is 4000kB.
- **16.11.**
  - **Tool shape.** `Task.Manager` has no body template, so its tools are action-style. The vendor's types are `SUSPEND`, `RESUME` and `RUN`.
  - **Suspend** first warns that no scheduled task will run until it is resumed.
  - **Banner.** It sits above rows that still list, with a privilege-gated Resume. Its sentences for suspended and stopped are already published, and `Running` raises none.
  - **DW-1638.** Task delete, suspend, resume, run and schedule-run must judge the task type's declared privilege (`%SYS.Task.Definition` `RESOURCE`) through `TaskRules.Permitted` in each tool's `ArgumentProblem`, as the create and the 9.8 edit do.
- **16.12.**
  - **Tool shape.** `Lock` has no template, so the tool is action-style. The vendor route is `Lock` `DELETE /lock`.
  - **Scopes.** It offers three, each naming what it removes: this lock, every lock of the owning process, and every lock from a remote client.
  - **DW-1073.** Warn from the endpoint's own 409 "is currently in a transaction" refusal, never from a `$zu` probe. The classic Manage Locks page asks the same before its Remove confirm.
  - **DW-1074.** Drop the Process details link on a row whose owner is remote, since it has no local pid.
- **16.13.**
  - **Coverage.** The editor covers enabled state, allowed IP addresses with add and delete, roles and authentication methods.
  - **Disabling `%Service_WebGateway`.** The control is drawn disabled with the published sentence. The disable is refused `PROHIBITED.SERVINGSERVICE` on the instance for both callers. The same prohibition covers the web application and the superserver, which is not a `Security.Service`.
  - **Address and authentication changes** on that service are permitted. The agent's proposal is minted destructive with a consequence line saying OcuPilot is served through this service.
  - **DW-1016.** An empty address list in a proposal diff row reads "Unrestricted", as the Services column's `emptyKey` does, not "(none)".
- **16.14.**
  - **Fields.** The editor covers the fields of the classic LDAP page, `%CSP.UI.Portal.LDAP`, whose exported source in `irislib/` is the field list.
  - **Test.** List, get and put stay synchronous. Test authentication runs through `AdminPort`'s async path, which resolves later with no polling in the slice, and reports the instance's own result text.
  - **Open questions (inference).**
    - AD-39 names only the SSL/TLS test as screen-only instance text, so this test likely needs its own named case there.
    - Check whether AD-26's queued-write refusal treats `TEST` as mutating.
    - Check whether the `AsyncResult` poll needs `%Admin_Operate:USE` declared under AD-8's endpoint clause, as the audit copy and purge did.
  - **DW-1639.** The list's Enabled column reads No for an enabled configuration. Derive it from `LDAPFlags` bit 64 or the `Security.LDAPConfigs:List` query.
- **16.15.**
  - **The line.** On a turn with context sharing on, the panel names the provider in use and says whether screen data left the instance. For a local provider on a private network it says the data did not leave, matching the chip's absent egress pill.
  - **Source.** It derives from the configuration the request actually uses (AD-42).
  - **DW-1076.** Add a fixture with a second enabled definition on a different endpoint host, and a live browser leg in which the chip and the line follow a real default-marker move. Today that is pinned only at the store level.
  - **DW-1192.** A Gemini endpoint with no `{model}` placeholder is allowed, but never silently. Log that the definition's Model is unused, and say so where the endpoint is edited. A create-time model validation rule stays deferred.
- **Epic-level DW-118.** Story 15.6 resolved it, so decline it with that reason.

## Technical Decisions

- **Reads (AD-5, AD-36).** One declared read serves both screen and tool. It is bounded and reports truncation. A `rowGet` merges detail fields a LIST lacks: `Task.CRUD` `INFO` answers truthfully where LIST coerces `Suspended` to false.
- **Privilege (AD-8, AD-29, AD-44).**
  - Pairs are checked at call time. An administrative resource is required at `USE`, never `WRITE`.
  - **Establishing a set.** Read the backing class's own check in `irislib/`, then run a least-privileged principal on the throwaway. Never use `%Operator` to prove a denial.
  - **Beyond the screen's set.** A write tool declares extra pairs when its vendor class writes a database the screen's read does not (several recent writes needed `%DB_IRISSYS:WRITE`), or when an endpoint its call must reach, such as an async poll's `AsyncResult`, names one. A caller without one is refused by name before any port call.
  - **Known sets.** Tasks' set is `%Admin_Task:USE` and `%DB_IRISSYS:READ`, and Security's (LDAP) is `%Admin_Secure:USE` and `%DB_IRISSYS:READ`. The service editor sits in Permissions.
  - **Classic pages.** Each `CLASSICPAGES` page unions its custom resource at `USE` through `Screen.Gate.WithClassicPages` on every gate call.
- **Writes.**
  - **Two callers, one operation (AD-53, AD-55).** The screen caller mints no proposal and emits no marker, and read-only and the kill switch do not gate it. The prohibited set, fingerprint, read-back, change event and removal impact are shared.
  - **Action-style (AD-51), 16.11 and 16.12.**
    - The tool declares its request type, derives an empty field list and sends no body.
    - It fingerprints a declared subject: every field the action's precondition reads, drawn from what its read type answers. Identity is not required in the subject.
    - A vendor body that carries a caller's choice is built by the tool's declared port from declared non-secret arguments. Each such port is a new named entry in AD-51.
  - **Merge (AD-4), 16.13 and 16.14.**
    - Read fresh, apply the diff, and send the complete body.
    - A list field changes by a server-side delta over a fresh read (AD-56).
    - A secret travels only as a declared secret argument. `Security.LDAP` sets the search password through its own `CHANGEPWD` type (`POST .../search-password`), which would be AD-56's secret-only body (inference).
    - A create fingerprints the target's absence, even where the PUT upserts (AD-54).
  - **Gates.**
    - The prohibited set is judged by effect, inside the confirm transition, for both callers (AD-10, AD-34).
    - Governance is checked at dispatch and again at Confirm.
    - A write that would queue is refused unless it is listed on `QUEUEDWRITES`. An async request is polled once inside the port, with a bounded wait that fails `PORT.TIMEOUT` (AD-26).
  - **Absence (AD-2).** A read answered 404 logs nothing and still yields `PORT.NOTFOUND`. A write answered 404 is logged.
  - **After the write.** It reads its target back (AD-58). A secret is reported written and never read back. A copy-out draft renders on the instance (AD-59).
- **Classic-link exemptions (AD-44).** Exactly two remain, declared by `ServiceForm` and `LdapConfigForm`, each counted against SM-C1. 16.13 and 16.14 each remove one, and AD-44's count is amended at its origin.
- **Provider egress (AD-42), 16.15.** The chip and the line are computed from the one configuration the request uses.
  - A marked-local endpoint bypasses any proxy and is not judged against it.
  - A configured proxy is a destination, judged by the same policy.
  - A cloud metadata endpoint is refused whether or not the definition is marked local.
  - Story 10.3 pins the same `LeavesInstance` computation server-side, in `Test/EgressLocal`.
- **Untrusted text (AD-11, AD-60).** Instance text reaches the model only as delimited, sanitized tool-result content. The SSL/TLS test's result text reaches the screen only (AD-39's named exception).

## UX & Interaction Patterns

- **Placement.**
  - **Suspend Task Manager** is on the Task schedule command bar. Resume sits on the banner.
  - **Remove locks** is a dialog from the Locks row menu.
  - **The service and LDAP editors** are tabbed form pages. The tabs mirror the classic tab names, and one Save applies every tab. A validation error switches to the tab holding it.
  - **Opening the editors.** The service editor opens from the Services name cell. The LDAP editor opens from its name cell and from the command bar's Create.
  - **The egress line** appears in the agent panel, once per turn. Color never carries it alone.
- **Dialogs.** One level deep and titled with the action and target.
  - A destructive dialog asks for the typed name.
  - A non-destructive warning, such as Suspend Task Manager, uses a primary button and states the consequence.
- **Controls.** A gated control uses `aria-disabled` with "Requires <resource>". Row actions update the row in place with "Changed".
- **A stale UX row.** EXPERIENCE.md's "Warning before a write" row still lists a warning for disabling OcuPilot's web service. AD-10 and 16.13's amended criterion, which draw the control disabled, govern.

## Cross-Story Dependencies

- **Keep intact.** 16.6's shared multi-select table, 16.8's shared log viewer, and Epic 14's baseline, sanitizer and per-user read-only.
- **Within the epic and beyond.**
  - **16.11.** Once its Task Manager resume ships, 16.21's Operations finding for a suspended Task Manager proposes it through Fix it instead of linking to Task schedule.
  - **16.12** extends Story 6.10's Locks list and its cross-screen row target to Process details.
  - **16.13 and 16.14** build on Story 9.9's reduced forms and their Save tools (`ServiceSave`, `LdapSave`).
  - **16.15** builds on the context chip and Story 10.3's egress computation.
  - **DW-1827 is decided.** The agent's task import (`tasks.schedule.import`) ships disabled by default. Its fix belongs to range-end cleanup, and a later task story does not re-decide it.
- **Slot B.** Story 23.2, the second range-end cleanup, runs there and merges to feature batch by batch. Epic 18 is paused until it merges.
  - Shared rosters are unioned at each merge, so keep edits additive.
  - They are `EntityType`, `Prohibited` codes and covered types, `ReadTool` counts, `AdminPort` type lists, `CLASSICPAGES` rosters, the baseline and the screen mirror.
- **Slot A.** It uses `ocupilot-slot-a` and the `ocupilot-ci` throwaway (52776/1975). `%SYS` application errors may be purged on `ocupilot-ci` only.
- **Release 1.0.4.** It is cut Wed 2026-09-30 at 14:00 PDT.
  - No story starts after 12:00 unless it finishes by 14:00.
  - A done story with green CI merges, and one in progress waits.
