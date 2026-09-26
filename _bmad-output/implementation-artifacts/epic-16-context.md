# Epic 16 Context: The remaining polish-week extras

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This is voting-week work, done after the submission cut. It adds the second-tier screens and actions a judge sees when comparing entries: a try-it console, web sessions, effective privileges, task export and import, background tasks, broadcast, license usage and the full dashboard, six secondary log viewers with a hub, and external language servers. It also carries six stories deferred from the contest build (16.11 to 16.16), and survey-driven stories: read-back, Home's performance row, impact lines, older messages.log files (Community Idea DPI-I-966), a security findings panel whose fixes are agent proposals, and a Guardrails page. **This run's order:** 16.1 (done), 16.17, 16.18, 16.19, 16.20, 16.21, 16.22, then 16.8, then 16.9. The other stories stay backlog. Everything merges to the feature branch; `main` moves only at owner-approved releases. **Nothing here may break a Release 1 screen or a Release 1 agent write.** Anything that risks either waits for Stage 2.

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

## Requirements & Constraints

- **Every story.** Each screen is one descriptor with its derived read tool. Each action ships with its confirmed write tool.
- **Governance baseline: held on an owner decision.** The epic says new write keys join Epic 14's governance baseline, but Story 14.2 is held. No tool is wired into a governance policy in this run; the gate point keeps returning "allowed" for everything not prohibited.
- **Read-back (16.17).**
  - After a confirmed write from either caller, the refreshed row reads "Read back: matches", "Read back: differs" (naming the fields) or "Read back: not found". The comparison runs on the instance.
  - The proposal card's closing line says the same. It is never a silent success.
  - The descriptor's field list declares how each field the instance normalizes on save is compared. A secret is reported as written, and its value is never read back.
- **Home performance row (16.18).**
  - Cache efficiency, global references per second, global updates per second, and disk reads and writes per second, each with its unit, from the instance's own dashboard metrics.
  - It refreshes on the auto-refresh framework's interval. A sparkline of global references per second covers the last ten minutes, starts empty and invents no history.
  - The row is absent, not zeros, for a caller who may not read the metrics. When present, Home's agent context carries the same values.
- **Impact lines (16.19),** on both proposal cards and screen dialogs:
  - Role delete: how many users hold the role and web applications grant it, with the first few names.
  - Role removed from a user: the resources and permissions lost, net of what the user's other roles still grant.
  - Resource delete: the granting roles, and the applications and databases it guards.
  - Counts are read fresh at mint or dialog open. A part the caller cannot read is named as unchecked, never reported as "no impact".
- **Older messages files (16.20).**
  - The file choice lists `messages.log` plus the rotated `messages.old_*` files in the manager directory, newest first, with size and modification time.
  - Paging, search, filter, screen context and explain work exactly as on `messages.log`, and the address names the file.
  - The server accepts only a name matching the rotated-file pattern, never a path. Reading one needs exactly `messages.log`'s privilege.
  - The README names DPI-I-966. The Open Exchange listing is Epic 17, handled by the owner out of band, so hand that half to the owner (inference).
- **Security findings (16.21).**
  - A panel on Home checks at least: unauthenticated web applications holding database or administrative roles, the monitoring API open without authentication, accounts holding `%All`, X.509 certificates expired or expiring within 30 days, and auditing off. Each finding names the object and why it matters, and the panel says plainly when there is nothing to report.
  - **Fix it** has the agent open the affected screen and propose the change as an ordinary proposal (comparison, privilege line, Confirm). Nothing changes until it is confirmed. A finding with no automatic fix, such as a certificate, links to its screen instead.
  - A finding whose fix the prohibited set refuses (the last `%All` holder, say) offers no Fix it and gives the reason in the prohibited set's own words. A finding the caller may not read is left out, never reported as clean.
- **Guardrails page (16.22).**
  - A read-only page in the Agent co-pilot area lists every action the agent refuses outright, each with its refusal reason. It is generated from the same prohibited set the server enforces, never written separately.
  - It shows the kill switch and enforced read-only state, which tools change the instance and therefore always need a Confirm, what the agent never sees (stored secrets, the variables captured with application errors), and the screen-context row limit.
  - A changed rule changes the page with no second edit, and a test fails when a prohibited action has no reason text.
- **Log viewers (16.8).** All six sources render in the shared log viewer: search with highlight and "n of N", jump to top and bottom, Load newer, a Raw toggle, and a per-row explain entry point that sends that entry alone.
  - DW-1102: add "Next match" and "Previous match" (approved copy) as accessible names, with their strings rows.
  - DW-1110: add `LogViewerStore` to sign-out teardown.
- **Hub (16.9).** Lists every source with a count and its last entry. Each row opens that source and carries an explain entry point.
- **Routed ledger entries for backlog stories** (address or decline with a reason when each is built): DW-1018 (16.3), DW-1080, DW-1101, DW-1137 (16.5), DW-1116 (16.7), DW-253 (16.10), DW-1073, DW-1074 (16.12), DW-1016 (16.13), DW-1639 (16.14), DW-1192 (16.15). DW-118 is already resolved by Story 15.6.

## Technical Decisions

- **Descriptors (AD-5, AD-36).**
  - A screen is a hand-written descriptor; `screen-mirror.mjs` generates the mirror, and `Screen/Registry.cls` and the mirror refuse identically. Each built screen has at least three suggested prompts from the closed group vocabulary.
  - The screen and its tool share one read, bounded, reporting truncation, and capped for context (AD-24: row cap 1 to 1,000 set on Switches, default 200; 65,536 characters total; 1,000 a field).
  - A `datetime` criterion may declare `defaultHoursAgo` or `atOrAfterField`, and the answer reports every applied criterion as `criteria`. Screen and tool apply the same default.
- **Navigation (AD-11).** `shell.screen.open` may carry `criteria` keyed by the target's declared criteria fields, on a `list (server criteria)` screen only. Values are validated on the instance before any announcement, travel on the directive and never in a URL. A navigation the user did not start is announced, and the departing screen may refuse it. A citation chip is a reference, not a navigation proposal. This is the path 16.21's Fix it takes to the affected screen (inference).
- **Prohibited set (AD-10).** It has exactly one home: kernel predicates evaluated against the resolved target inside the atomic transition (AD-34), whichever caller wrote. Each refusal has a `PROHIBITED.*` code. Other privilege grants, including `%All`, are permitted at the strongest confirmation. 16.21's refusal wording and 16.22's list must come from this one declaration.
- **Switches and classification (AD-22, AD-30).** Every tool declares `read` or `write`. Read-only and the kill switch are instance state evaluated at the point of effect; `Kernel.Restraint.Verdict` gives the `blocked` answer, and every screen-context payload carries `tools` and `readOnly` (AD-24).
- **What the agent never sees (AD-35, AD-48).** Secret-typed fields are schema-driven, never sent. Error-log detail (captured variables) is secret by default: summary fields only reach the model.
- **Privilege (AD-8, AD-29).**
  - A pair set is `(resource, permission)` pairs; `%Admin_*` and `%Service_*` are required at `USE`, never `WRITE`.
  - Every non-admin port declares and checks its own gate. Establish each set from the backing class's own check, then by a real least-privileged run on a throwaway.
  - There is no elevation. What a caller cannot read is reported as such, never inferred.
- **Paths and files (AD-21).** No endpoint accepts a filesystem path. A file source is named from a fixed enum, its directory is `$System.Util.ManagerDirectory()` resolved on every call, and paging validates the file's identity. 16.20's pattern-matched rotated-file name is a new named case, so amend AD-21 before building it (inference).
- **Writes (AD-53, AD-55, AD-10).** A screen action and the agent's write are two callers of one tool. Kinds are merge (AD-4), action-style (AD-51), create (AD-54) and secret-only (AD-56); the port is declared per tool (AD-52). 16.17 and 16.19 extend these shipped kernel paths and must leave Release 1 writes unchanged.
- **Try-it console (AD-57, done in 16.1).** A browser request under the tab's own Bearer token, never a tool or OcuPilot's write path. Targets under OcuPilot's own applications and `/api/admin` writes are refused before sending; other mutating verbs need a confirmation dialog. The response reaches the screen only, as data.
- **Refresh (AD-14, AD-43).** A confirmed write publishes the scoped triple; screens re-fetch and highlight, never patch. Auto-refresh has one framework, and its roster lives in EXPERIENCE.md, so Home joins the roster and its descriptor together in 16.18 (inference).
- **Client (AD-19, AD-20).** Zoneless, `OnPush`, framework-free stores in `core/` mirrored into signals. Every root store resets at sign-out. Every API URL is absolute through the one API service.
- **Server conventions.** One error envelope `{error, reason, code, detail}` (AD-12, AD-39). Ids are encoded twice and decoded once (AD-13). Tools are named `<area>.<screen>.<verb>`. User-facing strings come only from EXPERIENCE.md's Fixed strings and `strings.ts`; runners never invent copy.

## UX & Interaction Patterns

- **Log viewer.** Rows show time, pid, a severity chip (with its word) and text. The sticky search shows a polite "n of N". Raw is a bounded monospace view on `code-surface`. It is a tail, not live, and never loads the whole file.
- **Meters (16.7, 16.18).** Each meter shows its state as a word as well as a colour.
- **Proposal card.** Diff rows, "N unchanged fields", "Agent's rationale", "Expected impact", 11.8's privilege line ("Requires ...") and a focus-taking status line. 16.19's impact line is 11.8's sibling; 16.17's closing line reports the read-back.
- **Destructive confirmations.** A person's destructive dialog asks for the target's typed name. A destructive agent proposal takes the destructive bar with no typed name (14.7 is scratched).
- **Gated controls.** They use `aria-disabled`, never `disabled`, and name their reason ("Requires <resource>").
- **New copy.** Neither 16.21's panel nor 16.22's page has Fixed strings yet, so their copy must be added to EXPERIENCE.md before a runner uses it.

## Cross-Story Dependencies

- **Slot.** This run is on slot A: profile `ocupilot-slot-a`, throwaway `ocupilot-ci` on 52776/1975.
- **Home.** 16.18 and 16.21 both extend Home (15.4's System Information panel). Build them in order and keep 16.18's row intact.
- **16.21 on 16.17 and 16.19.** Fix it proposals go through the ordinary proposal path, which carries 16.17's read-back line and 16.19's impact lines when they apply (inference).
- **16.22.** It reads the kernel's prohibited set, tool classification, switches and context cap. It adds no new enforcement.
- **16.20.** Extends 6.14's messages.log viewer and 11.2's "Explain this entry".
- **16.9 after 16.8,** because the hub lists 16.8's sources.
- **Held.** 16.4 needs Story 18.1's directory allow-list, which is out of range.
- **Backlog notes.** 16.6 is the first screen to need multi-select. 16.13 and 16.14 each remove a classic-link exemption (AD-44) and replace Story 9.9's reduced forms.
