# Epic 16 Context: The remaining polish-week extras

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This is the voting-week work. It gives the classic portal's remaining second-tier screens and actions an OcuPilot equivalent that a person and the agent both use. It also carries the six stories deferred from the contest build (16.11 to 16.16), the contest-survey additions (16.17 to 16.24), and 16.25, which was split from 16.10 for size. **Nothing here may break a Release 1 screen or a Release 1 agent write.** Anything that risks either waits for Stage 2.

- **Done:** 16.1 to 16.10 and 16.16 to 16.24.
- **Next on slot A:** 16.25, the editor for 16.10's list. After it, 16.11 to 16.15 are backlog.

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
  - **Screens.** A screen is one hand-written descriptor with its derived read tool and at least three grouped suggested prompts. It enters the side bar only once built. A screen-adding story extends every browser spec pinning its area's side-bar list (`grep -l ocu-side-bar-label ui/browser`).
  - **Governance key.** An action ships with its confirmed write tool. Through 2026-10-04 its key joins `Kernel/Governance/Baseline.cls` in the same change, enabled unless the criteria say disabled.
  - **Each write tool** meets all of the following, and a test fails on any gap:
    - Its port has a `Snippet` for every `Invoke` branch.
    - A field the instance normalizes on save declares a read-back `compare`.
    - Its entity type gets a canonical-spelling rule.
    - It is measured with auditing on. Where IRIS records nothing, it is named as the next unaudited case in both AD-15 and AD-53. There are six so far: the fifth is the language server Stop, the sixth the task export.
    - Each classic page (and Hidden dialog) whose operation it performs beyond its descriptor's own page is named in `CLASSICPAGES`, read on the instance.
  - **Prohibited arms.** A new arm needs reason text, because the Guardrails page is generated from the prohibited set. Its sentence is published once in Fixed strings and pinned equal to the kernel's reason.
- **Copy.** New strings go into EXPERIENCE.md's Fixed strings and `strings.ts` in the same change. Edit EXPERIENCE.md in place so it stays at 993 lines. After touching it or epics.md, run `cd ui && npm run test:tools`.
- **Bundle.** It measures about 2.18 MB, against a 2217kB `maximumWarning`.
  - Crossing the warning re-bases it to about 5% above the measured total, with the `angular-json.test.mjs` literal updated in the same change.
  - Stop and ask above 3800kB. The hard stop is 4000kB.
- **16.25.**
  - **Round trip.** Create, edit and delete round-trip through the admin API, and delete confirms by name.
  - **DW-253.** Derive one field list per server type, as `Wallet.Secret` does, and amend AD-3.
  - **Measured by 16.10, not to be re-probed.**
    - PUT is the only create and edit (an upsert). `Type` is required and cannot change, and `Port` is required on create.
    - A PUT carrying `Custom` clears a Python server's classic-only members, so an unchanged `Custom` is omitted. That is an AD-4 named exception.
    - PUT and DELETE need `%Admin_Manage:USE` and `%DB_IRISSYS:WRITE`. A Python delete also needs `%System_CallOut:USE`.
    - A running server keeps listening after a delete, so edit and delete are refused while it runs, as the classic page does.
    - The path fields (`LogFile`, `ClassPath`, `JavaHome`, `PythonPath`, `FilePath`) are recommended shown and never sent. A settable path would be a new AD-21 case.
- **16.11.**
  - **Tool shape.** `Task.Manager` has no body template, so the tool is action-style.
  - **Suspend** first warns that no scheduled task will run until it is resumed.
  - **Banner.** The suspended banner, with its privilege-gated Resume, sits above rows that still list. Its copy for suspended and stopped is already published.
  - **DW-1638.** Task delete, suspend, resume and run must enforce the task type's declared privilege, as the create and the edit do.
- **16.12.**
  - **Tool shape.** `Lock` has no template, so the tool is action-style.
  - **Scopes.** It offers three scopes, each naming what it removes.
  - **DW-1073.** Warn from the endpoint's own 409 "in a transaction" refusal, never from a `$zu` probe.
  - **DW-1074.** Drop the Process details link on a row with a remote owner.
- **16.13.**
  - **Coverage.** The editor covers enabled state, allowed addresses with add and delete, roles and authentication methods.
  - **Disabling `%Service_WebGateway`.** The control is drawn disabled with the published sentence. The disable is refused `PROHIBITED.SERVINGSERVICE` on the instance for both callers.
  - **Address and authentication changes** on that service are permitted, minted destructive with a consequence line.
  - **DW-1016.** An empty address-list diff cell reads as unrestricted, not "(none)".
- **16.14.**
  - **Fields.** The editor covers the classic LDAP page's fields.
  - **Test.** List, get and put stay synchronous. The test runs through `AdminPort`'s async path and reports the instance's own result text.
  - **Open questions (inference).** AD-39 names only the SSL/TLS test as screen-only instance text, so this test likely needs its own case there. Check whether the queued-write refusal treats its request type as mutating.
  - **DW-1639.** The list's Enabled column reads No for an enabled configuration. Derive it from LDAPFlags bit 64 or the List query.
- **16.15.**
  - **Egress line.** It derives from the configuration the request actually uses (AD-42): a marked-local endpoint bypasses the proxy, and a proxy is judged as a destination.
  - **DW-1076.** Add a live leg in which the chip follows a real default-marker move.
  - **DW-1192.** A Gemini endpoint with no model placeholder is allowed, but never silently: log that the Model is unused, and say so where the endpoint is edited.
- **Epic-level DW-118.** Story 15.6 resolved it, so decline it with that reason.

## Technical Decisions

- **Reads (AD-5, AD-36).** One declared read serves both screen and tool, is bounded, and reports truncation.
  - **Optional parts:** a `rowGet` per row, `source.rows` over one member (the vendor's `maxRows` sent as the cap plus one), and up to three `parts`.
  - **External language servers.** `rowGet` issues `LanguageServer` `ACTIVITY` with `maxRows` 1 to merge `CurrentlyRunning`, and the parent-scoped Activity log reads `ACTIVITY` with `source.rows` `Activity`.
- **Privilege (AD-8, AD-29, AD-44).**
  - Pairs are checked at call time, and an administrative resource is required at `USE`, never `WRITE`.
  - **Establishing a set.** Read the backing class's own check in `irislib/`, then run a least-privileged principal on the throwaway. Never use `%Operator` to prove a denial.
  - **Extra pairs** go in the screen's `ownPrivileges` or on the write tool. A caller without one is refused by name before any port call. External language servers' list and Activity log own `%Admin_ExternalLanguageServerEdit:USE` beside `%DB_IRISSYS:READ`.
  - **Classic pages.** A descriptor declares the classic page it replaces. A write tool names every further page it performs in `CLASSICPAGES`, and `Screen.Gate.WithClassicPages` unions each page's custom resource into its pairs at `USE` on every gate call. The mechanism is on this branch: 16.4 and 16.10 both declare theirs, so a new tool never defers it.
- **Writes.**
  - **Two callers.** A screen action and the agent's write are one operation. The screen caller mints no proposal and emits no marker, and read-only and the kill switch do not gate it (AD-53, AD-55).
  - **Declared shape.** Each tool declares its port, `AdminPort` by default (AD-52).
    - An action-style write sends no body and fingerprints a declared subject holding every precondition field (AD-51).
    - A merge sends the complete body (AD-4).
    - A create fingerprints the target's absence (AD-54).
    - A screen action accepts only declared values, and changes a list field by a server-side delta over a fresh read (AD-56).
  - **Named cases.** Each is a closed list, and a new entry is added to the AD, never assumed.
    - **A port that builds the vendor body** from declared non-secret arguments (AD-51).
    - **A vendor `%SYS` class** reached instead of the admin API, allowed only where the admin API cannot carry the call (AD-27).
    - **16.4 is the latest of both.** `TaskTransferPort` calls `%SYS.Task.ExportTasks` and `ImportTasks`, which the admin API lacks, and builds their file argument from the declared `root` and `path`.
  - **Gates.**
    - The prohibited set is judged by effect, inside the confirm transition, for both callers (AD-10, AD-34).
    - Governance is checked at dispatch and again at Confirm.
    - A write that would queue is refused unless it is listed on `QUEUEDWRITES` (AD-26).
  - **Absence (AD-2).** A read answered 404 writes no log line, so a delete's re-read, a read-back or an existence check still gets `PORT.NOTFOUND` without raising the instance's alert state. A write answered 404 is still logged at error.
  - **After the write.** It reads its target back (AD-58), and a copy-out draft renders on the instance (AD-59).
- **Paths and logs (AD-21, AD-60).**
  - **No endpoint accepts a path.** A file is named as a root and a relative name through `Port/PathPort`, and is resolved again at the write. The tool declares `%Admin_FileSystemAccess:USE` and `%DB_IRISSYS:READ`.
  - **Overwriting consumers** are also refused configuration, database, journal and OcuPilot-served files. A file the tool reads is a `source`.
  - **Log text** reaches the model only through the sanitizer.
- **Refresh (AD-43).** Auto-refresh covers nine screens, including the Dashboard. A new one needs both its descriptor and EXPERIENCE.md's Auto-refresh controls row.

## UX & Interaction Patterns

- **Placement.**
  - **External language servers** is an OS management list with Start and Stop as row actions. Its editor (16.25) is a form-page. Once the editor exists, the name cell opens it, and the editor links the Activity log.
  - **Remove locks** is a dialog from the Locks row menu.
  - **Suspend Task Manager** is on the Task schedule command bar.
  - **The service and LDAP editors** are tabbed form pages.
- **Dialogs.** One level deep and titled with the action and target.
  - A destructive dialog asks for the typed name.
  - A non-destructive warning uses a primary button and states the consequence.
- **Controls.** A gated control uses `aria-disabled` with "Requires <resource>". Row actions update the row in place with "Changed".

## Cross-Story Dependencies

- **Keep intact.** 16.6's shared multi-select table, 16.8's shared log viewer, and Epic 14's baseline, sanitizer and per-user read-only.
- **Within the epic.**
  - 16.25 builds on 16.10's list, entity type `language-server` and Activity log read. 16.10's spec Design Notes, "Handed to the editor story", hold the full measured facts.
  - 16.11's Task Manager resume becomes 16.21's Operations "Fix it", which links to the screen until then.
  - 16.12 extends Story 6.10's Locks list.
  - 16.13 and 16.14 each remove one classic-link exemption (`ServiceForm`, `LdapConfigForm`), which lowers SM-C1 from two.
  - **DW-1827 is decided.** The agent's task import (`tasks.schedule.import`) is disabled by default in the governance baseline, and the person's screen import is unaffected. The commit was made in the 1.0.3 staging branch, so this branch receives it at the next forward merge. The fix is routed to range-end cleanup, and a later task story does not re-decide it.
- **Epic 18, on slot B.**
  - Shared rosters are unioned at each merge, so keep edits additive: `EntityType`, `Prohibited` codes and covered types, `ReadTool` counts, `AdminPort` type lists, `CLASSICPAGES` rosters, the baseline and the screen mirror.
  - OS management side-bar positions are reconciled from the merged registry.
- **Slot A.** It uses `ocupilot-slot-a` and the `ocupilot-ci` throwaway (52776/1975).
- **Release 1.0.3.** It is cut Tue 2026-09-29 at 14:00 PDT and staged with 16.4. 16.10 and every later story merge after the cut.
