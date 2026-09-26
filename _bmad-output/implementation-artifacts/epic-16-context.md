# Epic 16 Context: The remaining polish-week extras

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This is voting-week work, done after the submission cut (release/1.0.0). It adds the second-tier screens and actions a judge sees when comparing entries: a try-it console, web sessions, effective privileges, task export and import, background tasks, broadcast, license usage and the full dashboard, six secondary log viewers with a hub, and external language servers. It also carries six stories deferred from the contest build (16.11 to 16.16), three items from the contest survey (read-back, Home's performance row, impact lines) and older messages.log files (Community Idea DPI-I-966). The owner's order is 16.1, then 16.17 to 16.20, then 16.8 and 16.9, then 16.3 and 16.16, then the rest. Everything merges to the feature branch, and `main` moves only at owner-approved releases. **Nothing here may break a Release 1 screen or a Release 1 agent write.** Anything that risks either waits for Stage 2.

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

## Requirements & Constraints

- **Every story.** Each screen is one descriptor with its derived read tool. Each action ships with its confirmed write tool.
- **Governance baseline: owner decision pending.** The epic says new write keys are added to Epic 14's governance baseline. Story 14.2 says the baseline is frozen at Release 1 and that a key absent from it is disabled. Today `Governance/Gate.cls` allows every registered tool. Do not build on either reading.
- **Try-it (16.1).** The request round-trips with the current session and shows status and body. The response renders on the code surface as data and is never evaluated. Any secret in the request is masked in the record of it.
- **Log viewers (16.8).** All six sources render in the shared log viewer (6.13/6.14): search with highlight and "n of N", jump to top and bottom, Load newer, a Raw toggle, and an explain entry point per row that sends that entry alone (11.2's "Explain this entry").
  - DW-1102: add "Next match" and "Previous match" (approved copy) as accessible controls, with their strings rows.
  - DW-1110: add `LogViewerStore` to `app.ts`'s sign-out teardown, so one principal's rows never survive a sign-out.
- **Hub (16.9).** Lists every source with a count and its last entry. Each row opens that source and carries an explain entry point.
- **Read-back (16.17).**
  - After a confirmed write from either caller, the refreshed row reads "Read back: matches", "Read back: differs" (naming the fields) or "Read back: not found". The comparison runs on the instance.
  - The proposal card's closing line says the same thing. It is never a silent success.
  - The descriptor's field list declares how each field that the instance normalizes on save is compared. A secret is reported as written, and its value is never read back.
- **Home performance row (16.18).**
  - It shows cache efficiency, global references per second, global updates per second, and disk reads and writes per second, each with its unit.
  - The values come from the instance's own dashboard metrics.
  - A sparkline of global references per second covers the last ten minutes. It starts empty and invents no history.
  - The row is absent, not zeros, for a caller who may not read the metrics. When it is present, Home's agent context carries the same values.
- **Impact lines (16.19).** They appear on both proposal cards and screen dialogs:
  - Role delete: the number of users holding the role and of web applications granting it, with the first few names.
  - Role removed from a user: the resources and permissions lost, net of what the user's other roles still grant.
  - Resource delete: the granting roles, and the applications and databases it guards.
  - The counts are read fresh at mint or dialog open. A part the caller cannot read is named as unchecked and never reported as "no impact".
- **Older messages files (16.20).**
  - The file choice lists `messages.log` plus the rotated `messages.old_*` files in the manager directory, newest first, with size and modification time.
  - Paging, search, filter, context and explain work on these files exactly as on `messages.log`, and the address names the file.
  - The server accepts only a name that matches the rotated-file pattern, never a path. Reading one needs the same privilege as `messages.log`.
  - The README and the Open Exchange listing name DPI-I-966. The listing is Epic 17, which the owner handles out of band, so hand that half to the owner (inference).
- **Routed ledger entries by story.**
  - DW-1018 (16.3): a rail item is allowed when any of its screens is, and each screen keeps its own gate.
  - DW-1080, DW-1101, DW-1137 (16.5): the port decision for background tasks, `ForgetTask` not reached after an unawaited 202, and the literal `ASYNCTASKPAIR`.
  - DW-1116 (16.7): alerts.log is read through `LogSourcePort` alone.
  - DW-253 (16.10): one field list per language-server type, amending AD-3.
  - DW-1073 and DW-1074 (16.12): the transaction warning comes from the endpoint's 409, and a remote-owner row gets no link.
  - DW-1016 (16.13): an empty `AllowedConnections` reads "Unrestricted".
  - DW-1639 (16.14): the Enabled column comes from LDAPFlags bit 64.
  - DW-1192 (16.15).
  - DW-118 is already resolved by Story 15.6. It is a stale bullet, so record it as resolved.

## Technical Decisions

- **Descriptors (AD-5, AD-36).**
  - A screen is a hand-written descriptor, and the mirror is generated by `screen-mirror.mjs`. `Screen/Registry.cls` and the mirror refuse identically.
  - Every built screen has at least three suggested prompts from the closed group vocabulary.
  - A `list` descriptor that declares a read also declares `table`. An unlisted form page takes `sideBarPosition` 0.
  - The screen and its tool share one read, which is bounded, reports truncation, and is capped for context by AD-24.
- **Privilege (AD-8, AD-29).**
  - A pair set is `(resource, permission)` pairs, and `%Admin_*` and `%Service_*` resources are required at `USE`, never `WRITE`.
  - Every non-admin port declares and checks its own gate. Establish each set by reading the backing class's own check, then by running the read as a real least-privileged principal on a throwaway.
  - There is no elevation. What a caller cannot read is reported as such, never inferred.
- **Paths and files (AD-21).** No endpoint accepts a filesystem path.
  - A file source is named from a fixed enum, and its directory is `$System.Util.ManagerDirectory()`, resolved on every call and never cached.
  - The file rotates, so paging validates the file's identity. A global- or table-backed source takes its namespace from the set the user can read, never from a caller string (AD-48).
  - 16.20's pattern-matched rotated-file name is a new named case, so amend AD-21 before building it (inference).
  - 16.4's file picker needs Story 18.1's directory allow-list, which is out of range, so 16.4 is held.
- **Writes (AD-53, AD-55, AD-10).** A screen action and the agent's write are two callers of one tool.
  - Kinds are merge (AD-4), action-style (AD-51: declared request type, no body, declared fingerprint subject), create (AD-54) and secret-only (AD-56).
  - The port is declared per tool (AD-52).
  - The prohibited set is evaluated on the instance inside the atomic transition, whichever caller made the write.
  - A self-protection refusal sentence is published once in EXPERIENCE.md's Fixed strings and pinned to the kernel's copy.
  - `Task.Manager` and `Lock` are action-style with no template.
  - Disabling `%Service_WebGateway` is refused (`PROHIBITED.SERVINGSERVICE`), and the agent is never offered it.
- **Async (AD-26).** Only the port polls. The `Security.LDAP` test is the async path, while list, get and put stay synchronous. Queued writes are refused except for the port's named `QUEUEDWRITES`.
- **Admin API containment (AD-27).** Only `AdminPort` names `%Api.Admin.*`. A call the admin API cannot carry becomes a named case in AD-27, never a general license.
- **Untrusted content (AD-11, AD-47, AD-28).** Rendering is markup-free, and nothing rendered issues a request.
  - The Bearer token authorizes `/api/ocupilot` only, is kept per tab, and is never posted elsewhere.
  - 16.1 therefore has an open design point: how "the current session" reaches another REST application, how a mutating verb squares with the epic's confirmed-write rule, and AD-1's rule that no tool issues HTTP (inference). Settle it at the spec gate.
- **Secrets (AD-35, AD-41).** Redaction is schema-driven, with the name pattern as a backstop. Ledger rows exclude secrets at write time. The agent audit viewer's gate uses the resources recorded on each row (AD-46).
- **Refresh and change events (AD-14, AD-43).**
  - A confirmed write publishes the scoped triple, and screens re-fetch and highlight, never patch.
  - Auto-refresh has one framework, and its roster (seven screens) lives in EXPERIENCE.md. A new refreshing surface must join the roster and the descriptor together (inference, for Home in 16.18).
- **Client (AD-19, AD-20).** The client is zoneless, `OnPush`, and uses framework-free stores in `core/` mirrored into signals. Every root store resets at sign-out. Every API URL is absolute through the one API service.
- **Egress line (AD-42).** It is computed from the same configuration the request uses.
- **Server conventions.** One error envelope `{error, reason, code, detail}` (AD-12, AD-39). Ids are encoded twice and decoded once (AD-13). Tools are named `<area>.<screen>.<verb>`. User-facing strings come only from EXPERIENCE.md's Fixed strings and `strings.ts`. Runners never invent copy.

## UX & Interaction Patterns

- **Log viewer.** Rows show time, pid, a severity chip (with its word) and text. The sticky search shows a polite "n of N". Raw is a bounded monospace view on `code-surface`. It is a tail, not live, and never loads the whole file.
- **Meters (16.7, 16.18).** Each meter shows its state as a word as well as a colour. A percentage meter warns at 85% and errors at 95%.
- **Proposal card.** It has diff rows, "N unchanged fields", "Agent's rationale", "Expected impact", 11.8's privilege line ("Requires ..."), and a focus-taking status line. 16.19's impact line is 11.8's sibling.
- **Destructive dialogs.** A person's destructive dialog still asks for the target's typed name. A destructive agent proposal takes the destructive bar with no typed name (14.7 is scratched).
- **Gated controls.** They use `aria-disabled`, never `disabled`, and name their reason ("Requires <resource>").

## Cross-Story Dependencies

- **Order and slot.** 16.9 comes after 16.8, because the hub lists 16.8's sources. 16.1 depends only on 6.1's OpenAPI viewer, which is done. This run is on slot A: profile `ocupilot-slot-a`, throwaway `ocupilot-ci` on 52776/1975.
- **16.4.** Held on Story 18.1.
- **16.6.** Extends the data table's selection model to multi-select, the first screen to need it.
- **16.13 and 16.14.** Each removes a classic-link exemption (AD-44), which leaves SM-C1 at zero. Both replace Story 9.9's reduced forms.
- **16.17 and 16.19.** Both extend shipped kernel paths (proposal card, Confirm, the screen action route, 11.8's privilege line). Keep Release 1 writes unchanged.
- **16.18 and 16.20.** 16.18 extends Home (15.4's System Information panel). 16.20 extends 6.14's messages.log viewer and 11.2's explain-this-entry.
