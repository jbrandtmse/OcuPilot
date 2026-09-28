# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Take OcuPilot from the contest's Release 1 to System Administration and System Operation parity on the hidden `/api/admin` service. The scope covers:

- namespaces with their mappings;
- the database create, delete and properties wizards, and every disk operation the contest list deferred;
- journals, licensing, ECP, superservers, authentication options, MFT and the four encryption pages;
- SQL privileges and the web-application extras.

Each screen arrives with a read tool and a confirmed single-write tool, so the agent grows with the portal. Stage 2 ships as the first versioned IPM release after the contest. It deepens the dependency on an experimental API by about twenty screens, which is why the containment and inventory rules below carry most of the weight.

## Stories

- Story 18.1: The directory allow-list
- Story 18.2: Namespaces and their mappings
- Story 18.3: Databases - configuration, creation, properties and volumes
- Story 18.4: The deferred disk operations
- Story 18.5: Journals
- Story 18.6: Licensing and ECP
- Story 18.7: Encryption
- Story 18.8: Superservers, authentication options and managed file transfer
- Story 18.9: SQL privileges and the permission extras
- Story 18.10: Web application extras and spec-based REST services
- Story 18.11: Monitoring extras and the live log tail
- Story 18.12: The agent grows with the stage
- Story 18.13: Multi-namespace install

## Requirements & Constraints

- **One contract, no second way to build a screen.** Every screen is:
  - declared by exactly one descriptor;
  - reaches outside only through one port;
  - derives its read tool and its write tools' field lists from that descriptor, with no hand-written tool code;
  - writes only through a server-minted proposal, an instance-computed diff, an explicit confirmation and an agent marker.

  No feature-level spec exists for these rows. A story's acceptance is this contract plus each row's own backing route, and the finer criteria are written at the story's plan, never invented in advance.
- **Gates on the stage:**
  - write payloads are observed on the instance before any form is built;
  - async operations use the port's async path;
  - 18.1 lands before any server-path picker.

  The owner amended the 2027.1 gate on 2026-09-26: Stage 2 builds on the pinned 2026.2 image, and the inventory is re-derived against 2027.1 when that ships.
- **Governance defaults.** Every new write key enters `Kernel/Governance/Baseline.cls` in the same change, because a test names any missing key. Through 2026-10-04 a key is added enabled unless its story says otherwise; after that date the owner decides how keys enter. Every destructive or disruptive key this stage adds is set **disabled**: delete namespace, delete database, dismount, truncate, encryption changes, and each 18.4 operation.
- **Reads and gates.** Every read is bounded and reports truncation, and every gate uses the caller's own privileges at call time. No slice writes polling logic.
- **Catalog rows:** SH-24; CP-35/39/41; WA-10 to WA-14; PM-19 to PM-22; SS-28 to SS-35; OS-16 to OS-22 and OS-30; LG-11; SA-03 to SA-22; SO-01 to SO-08; PK-25. No story names SA-05 (WQM categories) or SA-22 (enable mirror service).
- **Routed ledger items:** DW-236 (a widened SQL grant on OcuPilot's state schema goes undetected) belongs to 18.9. DW-219 (Uninstall's three half-state paths) and DW-423 (`Kernel.State.Stamp` has no retention) belong to 18.13.

## Technical Decisions

- **Containment (AD-2, AD-27).** Only `AdminPort`, or a port extending it, names an `%Api.Admin.*` class, and it reproduces `Main()`'s sequence exactly:
  - stub `%request`/`%response`/`%session` with `IsRunningAsync` 0;
  - `ResourcesOR()` before the query parameters;
  - `ValidateQueryParams()`, then capture output;
  - a non-2xx `%response.Status` is a failure even when `tSC` is OK.

  A call may go through the vendor's own class only as a **named AD-27 case**, written into the spine, where the admin API cannot carry it.
- **Inventory (AD-26, AD-27).** Before using an endpoint outside the inventory fixture, re-run the audit. The fixture records both async entry kinds, and CI fails when the instance drifts from it.
- **Async (AD-26).** A request is async per request type, never per class. The Stage 2 async set:
  - `Database.Actions`: every type except mount and dismount; compact, defragment and integrity queue themselves. This is wider than 18.4's criteria, which name only three, so read the fixture before planning.
  - `Namespace.Namespace`: interop and mappings, including copy-mappings.
  - `Journal.File`: integrity check.
  - `ECP.DataServer`: the server action.
  - `Security.LDAP`: test connection.
  - `Journal.Record`: LIST.
- **Queued writes.** The port refuses every mutating request that would queue unless it is on `QUEUEDWRITES`. Each Stage 2 queued write needs its own named entry, whose body carries no secret. A write still running past the bound is recorded as applied and marked, and the screen and the agent both say it is "started, still running".
- **Polling privilege (AD-8).** Polling needs `%Admin_Operate:USE`, which the `AsyncResult` gate requires. A tool whose screen set lacks that pair declares it as its own.
- **Field lists (AD-3).** A tool's fields come from the endpoint's body-template method: `RequestBodySchema`, then `PutRequestBodySchema`, then `PutAndPostSchema`, then `Schema`.
  - Of the 16 mutating endpoints that publish no template, 11 are Stage 2 or later. Derive their fields from the underlying class and pin that with a test.
  - Every field is classified `ordinary`, `secret` or `opaque`. An unclassified field is treated as secret, and a string field whose name matches the credential pattern must be secret (for example `Encryption.Settings` `AdminPassword`).
- **Write kinds.** Each kind has its own rule:
  - **Merge (AD-4):** read fresh and send the complete set. Measure whether each new `PUT` erases omitted fields and whether it is an upsert.
  - **Create (AD-54):** fingerprint the name's absence, whatever the vendor does. The catalog shows namespace create and edit sharing `PUT /namespace`, which makes create an upsert (inference).
  - **Action-style (AD-51):** a declared request type and no body. The fingerprint subject is every field the action's precondition reads, and a fixed or caller-chosen vendor body is built by the port under a named entry.
  - **Secret-only body (AD-56).**
- **Two callers, one tool (AD-53, AD-55).** A screen's Save or row action and the agent's confirmed write run the same tool. The screen caller emits no marker and is not gated by read-only or the kill switch. Prohibited-set predicates are stated over the effect, so a bodyless delete is covered too.
- **Prohibited set (AD-10).** Already refused:
  - deleting OcuPilot's own database, web applications, resource or role;
  - disabling the superserver or `%Service_WebGateway`.

  The delete wizards cascade to dependent databases and applications, so the predicates must hold over the whole cascade's effect. An effect that must never be reachable is added to the kernel set, never to a policy file.
- **Removal impact (AD-8 precedent).** The namespace and database delete wizards list what depends on the target. Read each dependent part through the owning screen's declared read, with the caller's own privileges. A part the caller cannot read is reported as unchecked and names the missing pair, never shown as "no impact".
- **Privilege pairs (AD-8, AD-29).** `ResourcesOR()` is only a lower bound. Establish each pair set by reading the backing class's own check and by running a least-privileged principal on a throwaway. Administrative resources are required at `USE`. A tool may declare extra pairs only in AD-8's two named situations.
- **Paths (AD-21, 18.1).** No OcuPilot endpoint accepts a filesystem path. The allow-list picker needs a **new named AD-21 case in the spine** before it is built.
  - The existing cases share one shape: one segment or name, resolved under a root computed at call time, a literal `..` refused, a containment check after normalization, and the caller's text never reaching the vendor.
  - The picker is backed by admin-v2 `/fs-access-purposes` and `/fs-access-purpose/paths`; the classic portal uses `%CSP.Portal.Utils.GetAllowedDirectories`.
- **Identity and events (AD-13, AD-14).**
  - Each reference carries the triple `(type, scope, id)`, where the scope is `instance` for a configuration object with no namespace.
  - Each new entity type adds its rule for canonical spelling.
  - Entity types come from the kernel's closed enum, so new types are added there.
- **Descriptors (AD-5, AD-36, AD-44).**
  - New descriptors go into existing slices.
  - A page may issue another built screen's read (a database's volumes beside its properties).
  - Each descriptor declares the classic page class it replaces, or states that it has none. A list never links out.
- **Every write tool also gets:**
  - the read-back (AD-58);
  - a script form (AD-59): the port's `Snippet` mirrors every branch of `Invoke`, and a registry test fails when a tool has none;
  - the change event and the marker (AD-14, AD-15);
  - the switch to `%SYS` by explicit save and restore (AD-16).
- **Mappings (18.2).** Harvest the `%`-global guard from the sibling's mapping manager. Read its current body first, and rename it into OcuPilot's names.
- **Rules for later stories:**
  - **18.5:** journals stay in System Operation, not Logs.
  - **18.6:** ECP relies on the routes alone.
  - **18.7:** `Security.Encryption.Settings` is excluded by the v2 pin, so establish the reachable subset first. Key material is write-only.
  - **18.8:** a change to authentication options that would break OcuPilot's own sign-in is refused under AD-10's serving-path rule.
  - **18.9:** its criteria still say an `%All` or `%Admin_*` grant is refused. AD-10, as the owner amended it on 2026-09-23, now permits such grants at the strongest confirmation and prohibits only application roles on OcuPilot's own applications. The spine governs; reconcile this at the story's spec gate.
  - **18.10:** `MgmntPort` runs in process, and no tool makes an HTTP call (AD-1).
  - **18.11:** the monitoring API's anonymous reach never becomes OcuPilot's (AD-29).
  - **18.12:** a proxy is judged like the endpoint, and a marked-local endpoint bypasses it (AD-42). The wallet becomes a new rung on the credential ladder.
  - **18.13:** one idempotent installer (AD-17), and OcuPilot's globals stay in its protected database (AD-9).

## UX & Interaction Patterns

- **The screen contract.** Each screen registers the same 10 things. The side bar lists only built screens, and every new string goes into EXPERIENCE.md's Fixed strings. A refusal sentence is published once and pinned to the kernel's copy (AD-53).
- **Destructive actions on a screen** use a one-level `confirm-dialog`, never stacked:
  - the title names the action and the target;
  - the body states the consequence (the existing delete bodies end "This cannot be undone.");
  - a typed-name field requires an exact, case-sensitive match.

  An agent proposal carries no typed-name field: its confirmation is the destructive bar plus the Confirm press.
- **Wizards** follow the New Task precedent: a vertical, linear stepper. Next validates the step, Back keeps values, and a step with an error names it in text ("This step needs attention: <reason>"). The integrity-check wizard and its log viewer form one flow.
- **Editors** are form pages whose tabs mirror the classic editor, with one form across all tabs and a sticky Save.
- **Gated controls** stay focusable with `aria-disabled` and name their reason. A self-protection refusal is drawn the same way as a gated control.
- **Live data.**
  - Databases and Database details already auto-refresh, and auto-refresh pauses while a proposal on the same entity type is live.
  - Async values render as skeleton cells until they resolve.
  - The rule that log viewers load bounded pages yields only for sources that opt into 18.11's live tail.

## Cross-Story Dependencies

- **Order within the epic.**
  - 18.1 comes first: every path-taking screen here and in later stages depends on it, 18.3's database create among them.
  - 18.2's inline create-database step (SA-13) reuses 18.3's create wizard (SA-20).
  - 18.4 acts on the databases that Epic 6's read-only Databases list and Database details already show.
- **Shipped machinery these stories build on:** governance (Epic 14: the baseline, its test, the dispatch and Confirm gates), the copy-out draft (14.1), the sanitizer (14.3) and the read-back (16.17).
- **Shared kernel files.** Epics 16 and 23 are still in progress on other slots. Kernel and registry edits stay additive.
- **Stage 3 onward** relies on 18.1's allow-list for its server-path pickers.
