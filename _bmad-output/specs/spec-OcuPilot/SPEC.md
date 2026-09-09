---
id: SPEC-OcuPilot
companions:
  - '../../planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '../../planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/C4.md'
  - '../../planning-artifacts/prds/prd-OcuPilot-2026-09-08/prd.md'
  - '../../planning-artifacts/prds/prd-OcuPilot-2026-09-08/addendum.md'
  - '../../planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md'
  - '../../planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
  - '../../planning-artifacts/research/technical-ocupilot-portal-feature-landscape-2026-09-08/feature-catalog.md'
sources:
  - '../../planning-artifacts/briefs/brief-OcuPilot-2026-09-08/brief.md'
  - '../../planning-artifacts/briefs/brief-OcuPilot-2026-09-08/addendum.md'
  - '../../planning-artifacts/research/technical-ocupilot-portal-feature-landscape-2026-09-08/research.md'
---

> **Canonical contract.** This SPEC and the files in `companions:` are the complete, preservation-validated contract for what to build, test, and validate. Source documents listed in frontmatter are for traceability — consult them only if you need narrative rationale or prose color this contract intentionally omits.

# OcuPilot

## Why

**An opportunity and a vision, on a mandate's clock.** IRIS administrators still manage security, users and roles, tasks, OS monitoring and logs in a Zen-era portal InterSystems has deprecated but only partly replaced — the vendor's Angular work has reached interoperability only, while its hidden `/api/admin` v2 service already covers namespaces, security, tasks, processes, databases and devices. The administration API is being built before the administration UI, and nobody ships an assistant inside the IRIS portal: the field either drafts and refuses to act, or acts without marking the agent in the audit trail. OcuPilot claims that ground — an Angular portal served from the instance it manages, whose defining feature is an agent co-pilot that knows the screen the user is on, answers questions about it, and changes the instance through tools that run strictly as the logged-in user, one confirmed proposal at a time. The clock is InterSystems' "Build Your Own Management Portal" contest (Open Exchange 48): submissions close **2026-09-27 23:59 EST**, voting runs to **2026-10-04**, one developer has nineteen days, and the field was empty as of 2026-09-08. Release 1 exists to win it; the destination beyond it is to be the administration portal InterSystems has not built and can point at.

## Capabilities

Each capability names the functional requirements that resolve it in the PRD companion. FR-level testable consequences and catalog row IDs live there; they are not restated here.

- **CAP-1 — Sign-in and instance guard** *(FR-1, FR-2, FR-3)*
  - **intent:** A user reaches OcuPilot without a login form when the browser already holds an instance login, signs in through OcuPilot's own form otherwise, signs out of both, and is stopped before any screen loads if this is not the instance and API version OcuPilot was built for.
  - **success:** A browser already logged into the instance sees no form; a cold browser's single form login also signs the browser into the vendor's editors *and the classic portal*, which share the `%ISCMgtPortal` application group. Sign-out clears per-tab storage and ends the authenticated session across that group — it does not guarantee the classic portal shows a login form, since that application also permits unauthenticated access. An admin API absent or at a version other than 2 blocks every area screen behind a notice naming the mismatch, while a signed-in user holding no `%Admin_*` resource sees "no administrative privileges on this instance" instead.

- **CAP-2 — Privilege-driven navigation, header and page chrome** *(FR-4, FR-5, FR-6, FR-9)*
  - **intent:** A user sees and opens only the screens their IRIS privileges allow, organized by the six contest areas, with instance identity and namespace always visible and switchable, and with a route to the classic page for anything not yet rebuilt.
  - **success:** A screen the user lacks privilege for renders disabled with a tooltip naming the required resource rather than hidden; the namespace selector offers only namespaces the user can read and write, and the choice rides on the route and into screen context; every screen carries a navigating locator bar and a command bar; every classic page in the six areas that OcuPilot has not rebuilt is reachable from its corresponding screen, and no list screen links out.

- **CAP-3 — Live-data framework and one error envelope** *(FR-7, FR-8)*
  - **intent:** List screens refresh themselves without losing the user's place, and every server failure reaches the user as one consistent message naming the action to take.
  - **success:** Auto-refresh on Processes, Databases, Task details and Task schedule preserves sort, filter and selection, and pauses while a proposal awaits confirmation on that screen so the diff under review does not move. One error envelope serves the whole API: a 401 triggers refresh-and-retry, a 403 names the missing privilege, a failed call distinguishes "instance unreachable" from "request refused", and internal exceptions log fully on the instance and report generically to the browser.

- **CAP-4 — Docked panel carrying screen context** *(FR-10, FR-11)*
  - **intent:** The agent panel is present on every route with the current screen as context, and the user can turn that sharing off.
  - **success:** The panel survives route changes with its conversation, resizes and expands, and has no close control in Release 1. Context is reassembled fresh each turn from the screen the user is on at that moment; every field typed as secret is excluded unconditionally, and a screen carrying such fields sends route and entity identity only. The context chip names what is shared, the provider and endpoint host in use, and says "leaves the instance" when that host is not on a private network.

- **CAP-5 — Turn execution, progress and reply rendering** *(FR-12, FR-13)*
  - **intent:** A user sends a message and watches the agent work until it answers, with the reply rendered safely and offline.
  - **success:** Each tool call appears as a card with name, argument summary and result status while the turn is still running; a second message on the same conversation is refused with a visible lock; the conversation survives a page reload and a new tab starts a fresh one; a provider timeout ends in an error card, never a silent stop. Replies render as sanitized Markdown from vendored code with no CDN reachable, and a reply containing a remote image produces no network request.

- **CAP-6 — Screen synchronization and agent-driven navigation** *(FR-14, FR-15)*
  - **intent:** After a confirmed write the affected screen shows the change without the user hunting for it, and the agent can take the user to a screen.
  - **success:** Every confirmed write emits a change event carrying entity type, id and action; the active screen showing that type re-fetches and highlights the changed row or field within two seconds, and a toast links to it when that screen is not open. Navigation tools accept allow-listed route identifiers and entity ids, never a URL, announce the destination before moving, and are reversible with the browser back button.

- **CAP-7 — One read tool per screen** *(FR-16)*
  - **intent:** The agent can read everything the six areas' screens can read, through the same endpoints they read from.
  - **success:** Every list and detail screen, plus the three shell reads (privilege map, namespace list, instance identity), has exactly one read tool over the same endpoint returning the same fields the screen shows. Read tools, write-tool input schemas and change-event entity types all derive from the one screen descriptor, so adding a screen adds its tools with no hand-written tool code. Read tools take the filters the screen offers and return row identifiers the panel turns into citations. No read tool runs free-form SQL in Release 1.

- **CAP-8 — Propose, review, confirm** *(FR-17)*
  - **intent:** The agent changes the instance only through a proposal the user has confirmed.
  - **success:** A write-tool call mints a server-side proposal holding the tool, the resolved arguments and a fingerprint of the target read fresh; the client never authors one. The card shows the target, a before/after diff computed on the instance, every field the payload will send, the agent's rationale and expected impact labeled as the agent's text, and how to reverse the change where a reversal exists. The write runs only on a separate authenticated confirmation from the browser carrying the proposal id, executing from the stored arguments; no request issued from within a turn can confirm. A confirmation is single-use, expires, and is refused when the user, conversation, agent definition, read-only state or target fingerprint has changed. Secret fields are declared in the schema, never accepted from the model, and travel only in the confirmation request. A destructive proposal requires the user to type the target's name.

- **CAP-9 — Execution strictly as the user** *(FR-18)*
  - **intent:** Every tool runs under the caller's own IRIS privileges, with the prohibited set absent from the tool set rather than gated inside it.
  - **success:** A tool the user lacks privilege for fails with the same 403 the screen would, and the agent reports it instead of retrying with other credentials; no credential but the user's own is used, and the full tool set stays advertised with privilege checked at call time. The Release 1 prohibited set — deleting or disabling the current user, the last `%All` holder or `_SYSTEM`; disabling the web service that serves OcuPilot; terminating IRIS system processes; deleting OcuPilot's own web applications, resource or role — is refused on the instance and never advertised as a tool. Any privilege escalation is confined to named storage and file-read methods, checks an explicit resource first, and is not in effect while tool code, admin API calls or provider calls run.

- **CAP-10 — Read-only mode and kill switch** *(FR-19, FR-20)*
  - **intent:** An OcuPilot administrator can restrain or disable the agent instance-wide, and any user can restrain their own session, without the screens losing function.
  - **success:** In any read-only state every write tool returns a structured "blocked by read-only mode" result, the agent states what it would have changed and on which screen, and no proposal card appears. A disabled agent refuses turns server-side and renders the panel disabled with the reason while every screen keeps working. Both switches are evaluated on the instance before every provider call, every tool call and at confirmation, an in-flight turn stops at its next step when either changes, and both are reachable through a screen that does not depend on the agent.

- **CAP-11 — Agent ledger and audit marker** *(FR-21, FR-22)*
  - **intent:** Every agent action is recoverable afterwards — from OcuPilot's own ledger by turn, and from the IRIS audit database by marker — without hand-correlating across systems.
  - **success:** Every LLM call and tool call lands in the ledger with user, timestamp, screen route, tool or provider name, arguments, result status, token usage where reported, and the IRIS resource the tool required; redaction is schema-driven from each tool's declared secret fields, never pattern-driven alone. Every confirmed write emits an OcuPilot audit event carrying the agent marker alongside the IRIS system event for the same change, a write made by hand emits none, and the audit viewer can filter on the marker. A failed marker is recorded on the ledger row and shown on the tool-call card rather than failing the write, and with auditing off every user sees an "agent writes are not being marked" banner.

- **CAP-12 — Agent definitions, providers and credentials** *(FR-23, FR-24, FR-25, FR-26, FR-27)*
  - **intent:** An OcuPilot administrator configures which model the agent runs on, proves it works before enabling it, and never stores a key OcuPilot can display back.
  - **success:** A definition holds name, provider, model, endpoint, credential type and reference, token and iteration limits, temperature, optional system prompt override, read-only flag, retention period and enabled flag, under the eleven server-side validation rules; changing provider, endpoint or credential disables it until Test connection passes again, and every change is audited with old and new endpoint. Four provider families — Anthropic first, then OpenAI, Google Gemini and OpenAI-compatible including local models — work behind one adapter contract, so adding a family changes no part of the loop, the tools or the screens. Keys resolve at call time from an environment variable or an IRIS credential and are returned by no API call. Test connection makes one minimal call and reports the model's reply or the provider's error text, refusing link-local metadata endpoints while allowing loopback and private hosts. Provider calls retry with bounded backoff on 429 and 5xx honoring `Retry-After`, and a turn names the step that timed out.

- **CAP-13 — First-login gate and the OcuPilot administrative resource** *(FR-28, FR-29)*
  - **intent:** A fresh install sends whoever can configure the agent to do so, and OcuPilot's own state and switches are governed by a resource the installer creates.
  - **success:** With no enabled definition an OcuPilot administrator lands on agent configuration at every login until one is enabled and a banner persists on every screen, while non-administrators keep every screen with the panel in its configuration-empty state naming who can configure it. Every configuration endpoint checks the resource server-side, and every change to a definition, the kill switch, enforced read-only, the context-sharing default or the turn limits emits an audit event naming actor, target and old and new values. A user holding read and write on the install namespace's default database but not the OcuPilot administrative resource cannot read or write OcuPilot's definitions, switches, ledger, transcripts or proposals through SQL or direct global access, and a test proves it.

- **CAP-14 — Web applications and REST API explorer** *(FR-30 … FR-34)*
  - **intent:** A user can list, create, edit, enable, disable and delete web applications, and browse any REST service's OpenAPI document.
  - **success:** The list shows name, namespace, type, enabled, dispatch class and resource with filter, and reflects a save without a manual refresh; the editor covers the classic page's full field set; create supports CSP, REST, WSGI and ASGI with server-side validation; delete confirms by name, and deleting OcuPilot's own applications is refused with an explanation. The explorer combines management-API discovery with the web application list per namespace, renders manually-coded and spec-based documents as a path-and-verb browser, and shows the refusal where the management API will not return a document.

- **CAP-15 — Permissions** *(FR-35 … FR-41)*
  - **intent:** A user can administer users, roles, resources and services — the lists, the full editors, and the small actions that make up most daily administration.
  - **success:** Users, roles, resources and services list with filter and open full editors covering their classic pages' fields; create, enable, disable, delete, password-set with change-on-login, and role add and remove all act from both the row and the editor and update in place. Disabling or deleting the current user is refused with an explanation; deleting a role granted to users warns with the count first; system resources are shown but not deletable; disabling the web service OcuPilot itself depends on warns before proceeding.

- **CAP-16 — Security and secrets** *(FR-42 … FR-47)*
  - **intent:** A user can administer SSL/TLS, X.509 credentials, OAuth 2.0 entries, LDAP and Kerberos, wallet secrets and auditing configuration — the area the contest names most specifically.
  - **success:** SSL/TLS and LDAP have full editors and X.509 imports, edits and deletes with subject, issuer and validity listed; private key material entered in a form is returned by no read. The four OAuth 2.0 lists and the authorization server view read live, client configurations and server client descriptions delete with a named confirmation, and each entry links to the classic editor until the polish-week editors ship. Wallet collections list and their secrets create, edit and delete with values write-only. Auditing enables and disables, system events configure and reset counters, user events create and delete — and disabling auditing warns that agent writes will stop being marked, a warning the agent's own proposal card must carry.

- **CAP-17 — Tasks** *(FR-48 … FR-53)*
  - **intent:** A user can see, create, edit and control scheduled and on-demand tasks and the Task Manager itself.
  - **success:** Schedule, on-demand and upcoming lists read live with filters and a chosen horizon; history renders per task and across tasks with start, end, status and error text; details show properties, schedule and last and next run under auto-refresh and link to history and edit. Run, suspend, resume and delete act on the row in place with delete naming the task, and suspending the Task Manager warns that no scheduled task will run until it is resumed. The New Task wizard and Edit task carry the field set and legal-value semantics of `%SYS.Task` — the schedule vocabulary (daily, weekly, monthly, monthly-special, after-another-task, on-demand), the intra-day frequency triple, expiry offsets, e-mail notification targets, run-as user, output file, priority, suspend-on-error and reschedule-on-restart.

- **CAP-18 — OS management** *(FR-54 … FR-59)*
  - **intent:** A user can watch and control processes, locks, databases, devices and system usage.
  - **success:** Processes list with filter, page size, maximum rows, persisted sort and auto-refresh and open details with meters, client executable and address and open devices; terminate, suspend and resume confirm by process id and refuse action on the user's own process. Locks list by namespace with owner links to process details, and single, per-process and per-remote-client removal warns when the owning process is in a transaction. Databases list in general and free-space views — free space arriving asynchronously and rendering as it arrives — with details, volume files and background tasks under auto-refresh. Devices list, create, edit and delete. System usage counters and the CPU, memory and performance meters render on a refresh interval, their names and thresholds taken from `%CSP.UI.Portal.EnsembleMonitor`'s meter definitions.

- **CAP-19 — Logs** *(FR-60 … FR-63)*
  - **intent:** A user can read every log the contest names and ask the agent what an entry means.
  - **success:** alerts.log shows entries reported since the last monitoring scrape plus a bounded tail of the file; the audit database searches by time range, source, type, name, user, process id, namespace, authentication and text, opens full event detail, and filters to the agent marker; messages.log serves in bounded pages from a manager-directory path no request can change, never loading the whole file into the browser; the application error log drills namespace to date to error and deletes by namespace or individually as a confirmable agent write — which is what gives the Logs area its own confirmed write.

- **CAP-20 — One-command install and packaging** *(FR-64 … FR-68)*
  - **intent:** An operator installs OcuPilot in one step, repeatably, on a Community image, with no Node toolchain and no assumption that IPM exists.
  - **success:** One IPM command installs the module with the built bundle inside the archive, targeting `HSCUSTOM` when present and `USER` otherwise. From a clean clone, `docker compose up` brings up an instance with OcuPilot installed, `_SYSTEM` unexpired and auditing plus OcuPilot's event types enabled, reachable on the workspace's published port; a second `up` after `down`, and an `up` with a newer image against the existing durable volume, both reach the same state with no manual step. Running install twice changes nothing the second time, every created object is guarded by an existence check, no agent definition is seeded, and the namespace is restored on any error. No package, web path, role, resource, global, task, credential or audit source name collides with iris-session-agent, iris-execute-mcp-v2 or iris-couch, and install runs undisturbed with that suite present on the same instance. A smoke script exercises sign-in, one live list per area, one confirmed agent write and the audit marker on a fresh container, and gates every publish and every build-order step. A `demo` option creates the walkthrough fixtures and is opt-in.

- **CAP-21 — Contest submission deliverables** *(FR-69)*
  - **intent:** The contest's hard requirements are met in the repository, not only in the listing.
  - **success:** A public MIT repository with an English README whose install steps work the first time on a clean machine, carrying the UJ-2 and UJ-3 walkthroughs with screenshots, a "get a key in two minutes" section per shipped provider, an Ideas Portal link and a video if one is recorded. The Open Exchange listing exists before the application is submitted, and the application is in by 2026-09-27 23:59 EST.

- **CAP-22 — Screen-aware help, transparency and restraint** *(FR-70, FR-71, FR-72 — polish week)*
  - **intent:** During the voting week the agent explains what the user is looking at, shows its work, and can be governed and held back.
  - **success:** "Explain this screen" is one click everywhere and cites the read tool it used; every log and audit entry carries an explain entry point sending that entry alone; every screen offers at least three suggested prompts grouped by task. Replies carry click-through citation chips, every turn with context on shows a data-egress line naming the provider, and an agent audit viewer lists ledger rows filtered by user, screen and date. A user can take a copy-out ObjectScript, CLI or REST snippet instead of an execution. An administrator can enable or disable each write tool by tool and action with read-only and full presets, over a frozen baseline that keeps every Release 1 write key enabled so the six-areas-six-writes metric holds through 2026-10-04. Tool and log content is truncated, control-stripped, delimiter-wrapped and secret-redacted before reaching the model, and a seeded-injection test asserts the agent did not act on it. Transcripts persist per user with a retention purge, and an administrator opening another user's transcript is ledgered and sees tool results only when holding every resource that transcript's calls required.

- **CAP-23 — Polish-week area extras and engineering hygiene** *(FR-73 … FR-79 — polish week)*
  - **intent:** The voting week adds the second-tier screens, actions and project hygiene that make the entry read as finished.
  - **success:** Shell conveniences — own password, favorites, recents, menu search, About, per-screen Help, shortcuts, links panel, the Home system panel, persisted UI state and a light or dark theme — are reachable and survive a sign-out. REST try-it round-trips with the current session, web sessions list and end, effective privileges render, and the permission-check tool answers yes or no with the granting role. SSL/TLS and LDAP tests report the instance's result text, X.509 details render, OAuth tokens revoke, the audit database copies and purges, and the five OAuth 2.0 editors round-trip create, edit and delete. Tasks export and import across instances, background tasks cancel, pause and resume, a broadcast reaches a chosen process, license usage renders, and every dashboard meter group draws. Six secondary log viewers plus a log hub with counts, last entry and explain entry points render. External language servers list, start, stop and round-trip create, edit and delete. The uninstall hook removes everything the installer created, the suite runs in CI against a stock image, and the package is on the community registry. Nothing shipped in the week breaks a Release 1 screen or a Release 1 agent write.

## Constraints

**Time and shape of the build**

- Submissions close **2026-09-27 23:59 EST**; a submittable build must be listed by **2026-09-14**; the voting week runs to **2026-10-04** and must show a user-visible change every day. One developer, nineteen days, against roughly 45 developer-days of specified work.
- The build order in PRD §10.1 **is** the cut line. Every step ends in a publishable build that passes the smoke script on a clean container, so any step can become the cut without leaving a half-built one behind. No P1 item starts while a step 1 or 2 item is unfinished.
- The **2026-09-27 application floor** is binding: build steps 0–4 complete, at least one create or edit form per area from step 5, no list screen in the six areas linking out to the classic portal, one confirmed agent write in each of the six areas, and the demo journey reproducible end to end on a clean install. Below it the entry is the thin interface the contest rules reject.
- A cut large editor ships as a reduced form plus a link to the classic page, never as a half-working full form — and its write tool ships regardless, so the agent stays a conduit for that edit.

**The two lines that never move**

- The agent never holds a privilege the user does not. No service account, no privilege escalation path through the agent.
- Every agent write stays visibly marked in the IRIS audit database, distinguishable from the same write made by hand.

**The write model**

- Exactly one explicit user confirmation per write, on a diff the instance computed. No batch approval, no undo in Release 1, no client-authored proposal, and a confirmation bound to its proposal and invalidated when the proposal changes.
- Prohibited actions are **absent** from the tool set, not gated within it.
- Read-only mode and the kill switch are reachable without the agent and evaluated at the point of effect, not cached.

**Trust boundary**

- The model is assumed fully compromised by every piece of content it reads — screen context, tool results, log text, audit entries, entity names, comments. The defense is invariants, not a prompt format: no write without a confirmed server-computed diff; no request to any host but the configured provider, including from a rendered reply; navigation restricted to allow-listed route identifiers; untrusted text only ever as delimited tool-result content, never in the system prompt or the user role.
- Secrets are write-only end to end: never returned by a read, never logged, never stored in a proposal's arguments, and excluded from screen context by schema declaration rather than by name matching.
- No caller-supplied value is concatenated into SQL, and no endpoint accepts a path.
- The instance origin is shared with every other application IRIS serves and is treated as hostile ground: per-tab token storage, no cross-tab broadcast, a restrictive CSP naming only the instance origin, and no CDN at runtime — every library vendored. The token pair travels only as a Bearer header, never by cookie and never as a password posted into an embedded frame; cookies alone never authorize a data call. Development proxies through the IRIS origin rather than enabling CORS, so no cross-origin allowance exists to be left switched on.

**Adopted architecture**

- The **architecture spine's 47 ADs are binding** on every unit. Where an AD and another companion disagree, the AD wins; where a diagram and an AD disagree, the AD wins. The spine's *Superseded by decisions in this spine* section lists the four PRD and addendum positions it overrides, and those overrides are live.
- Stack pins come with it: Angular 22.1.x zoneless and signal-based, Angular Material 22.x, TypeScript **6.0.x pinned exactly**, Node `^22.22.3 || ^24.15.0 || ^26.0.0`, the `@angular/build` application builder, IRIS 2026.2 as the floor and the only tested version, IPM 0.10.x as a distribution channel that the runtime must never require, and an explicitly pinned image tag rather than a floating one.
- Everything outside OcuPilot is reached through a port with exactly one adapter; a slice never speaks to another slice or to an outside system directly. Every screen is declared by exactly one descriptor, from which its route, navigation entry, privilege gate, read tool, write tools, context serializer and change-event key all derive.

**Platform and integration**

- The `/api/admin` service is pinned to **v2**, is undocumented and unsupported, and its route set is kept under an automated test that fails when a route OcuPilot uses disappears. The dependency on undocumented vendor internals stays confined to the port and always has a fallback.
- API preference order: a documented official route first, the admin API second, a custom OcuPilot API endpoint only where neither exists. The Atelier API is not used in Release 1.
- No shipped class contains embedded Python; any Python is an operator prerequisite, never an install action.
- No sibling project (iris-session-agent, iris-execute-mcp-v2, iris-couch, iris-table-editor) is a runtime dependency, and no name OcuPilot creates collides with one.
- IRIS Community and IRIS for Health Community, desktop Chrome as the supported and tested browser, English interface only, WCAG 2.1 AA text contrast and full keyboard operation as a floor with no certification claimed.
- Performance budget: a list's first page within two seconds at a thousand rows, a confirmed write's screen refresh within two seconds, first visible turn progress within ten seconds against a current cloud model.
- Public repository under MIT, which the contest's nonexclusive promotional licence clause permits.

## Non-goals

- **Not a multi-instance console.** OcuPilot manages the instance that serves it, and only that one. (Multi-*namespace* is in scope.)
- **No autonomous action.** The agent does not act without confirmation, does not batch-approve, and does not undo in Release 1.
- **No retrievable secrets.** OcuPilot does not store API keys, private keys or secret values in any form it can display back.
- **No vendor bundle redistribution.** The vendor's Angular editors are not copied; when eventually embedded they load in place from the instance. They are not embedded in Release 1.
- **No sibling-project reuse at runtime.** Their packages, paths, roles, globals, tasks and credentials are off limits; they are harvest sources only.
- **No embedded Python in any shipped class.**
- **No mobile, no localization, no accessibility certification** — in Release 1 or any planned stage.
- **No cost metering.** Provider cost is the operator's, bounded only by the definition's maximum tokens and maximum iterations per turn; per-turn and per-user usage analytics is Stage 2 or later.
- **Out of Release 1 entirely:** interoperability, analytics and the System Explorer; database operations beyond listing; guided multistep workflows and investigate runs; free-form SQL for the agent; token streaming; undo; embedded vendor editors. Each has a named later stage.

## Success signal

A judge on the Open Exchange listing clones the repository, runs one command, and reaches a working portal the first time; within a minute of interaction they watch the agent propose a real change to their own instance, confirm it, see the affected screen refresh and highlight what changed, and then find that same change in the IRIS audit database marked as having come through the agent — repeated across all six contest areas. On the strength of that, OcuPilot takes first place in the Experts nomination, with a Community nomination placement as the floor.

Measurable at the deadline: every one of the six areas has at least one live-backed list and at least one agent-proposed, user-confirmed write; over the whole voting week, no confirmed proposal exists without a matching marked audit event and no marked event without a confirmed proposal.

Beyond the contest, the signal is vendor attention, in rising order: a product-team conversation with InterSystems about OcuPilot or the admin API; a reference to OcuPilot in a Developer Community post, webinar or documentation; a design choice from OcuPilot — agent-marked audit, or execute-with-approval — appearing in the vendor's own product. That is what validates the staged delivery, not Release 1 alone.

## Assumptions

- The 2026-09-14 listing build and the 2026-09-27 application floor stated in PRD §1.1 are treated as binding acceptance gates rather than aspirations, because the listing metric and the cut-line rule both depend on them.
- Stages 2 through 6 are named in scope but not enumerated as capabilities here: the spine decides them only where their gates are already clear, and PRD §10.3 plus `extract-stages.md` carry the row-level plan.
- The PRD and its addendum are treated as a companion rather than an absorbed source, on the judgement that epics and stories need FR-level testable consequences that a kernel cannot hold.
- The 2026-09-08 probe findings and owner decisions **have been pushed back into the PRD and its addendum**, as have the architecture spine's four supersessions. No known disagreement remains between this kernel, the PRD and the spine.

## Open Questions

Four remain. The rest closed on 2026-09-08 — by owner decision, or by probing the instance — and are recorded under *Resolved* below rather than carried.

- What technology bonuses apply to contest 48, and is an entry covering only some of the six areas accepted? *(Kick-off, 2026-09-14; the coverage half is moot if all six ship.)*
- What is InterSystems' support stance on `/api/admin`, and will Group by ID and the browser-id cookie survive future releases? *(Kick-off. Note that Group by ID is now load-bearing for more than silent login — see CAP-1 and CAP-2's classic-portal fallback.)*
- When are winners announced? *(Not stated in any source read.)*
- Build step 7's per-user turn limits need a "turn limit reached" banner and a refusal sentence before that step ships. *(Owned by `EXPERIENCE.md`, not by this spec — the one UX item the architecture spine did not answer.)*

### Resolved

**By owner decision, 2026-09-08**

- **No hosted online demo.** A publicly reachable, write-capable IRIS admin portal is the wrong exposure, anonymous voters burn the owner's provider tokens, and it is a P1 bonus competing with real screens. The README's screenshots and per-provider key guide remain the mitigation. Revisit only if the voting week leaves slack.
- **Token streaming ships in the polish week**, conditional on build step 7 finishing first and ranked after FR-70 and FR-71 — not Stage 5, and not Release 1 proper.
- **Freshmen eligibility is likely** — this is the owner's first InterSystems contest. Confirm at the kick-off.
- **Plain IRIS Community verification happens after the application floor is built**, not before the listing. Accepted risk: if plain Community lacks `/api/admin`, or install breaks falling back to `USER`, it surfaces late.

**By probing the instance, 2026-09-08** *(profile `ocupilot-iris`)*

- **The legacy CSP page source cannot be pulled, and does not need to be.** Every page named in the old question is a `%cspapp.*` class marked `[Hidden]` with zero compiled methods, no UDL text, no `.int`, no CSP document and no file on disk — they ship compiled-only. The field lists come from better sources that are all present: `%SYS.Task`'s 66 documented properties for the task wizard and editor (with the legal-value semantics the wizard encodes), `%CSP.UI.Portal.EnsembleMonitor` — already readable in `irislib/` — for the 25 dashboard meters and their thresholds, and the `%CSP.UI.Portal.Audit.*` classes plus the admin API's audit-event endpoint for the auditing page. **This invalidates the 2026-09-11 build-order task and the FR-52/53/56/62/63 preconditions as written.**
- **messages.log has no backing class** — it is a plain file under the manager directory, so its custom endpoint over `LogSourcePort` stands as assumed, with two caveats the architecture pass added: its path is operator-settable and the instance rotates the file, so a byte-offset tail must revalidate rather than trust a held position. **The application error log is the `^ERRORS` global, per namespace**, written by `^%ETN`, with `Config.Startup.ErrorPurge` as the retention *setting* and `%SYS.Task.PurgeErrorsAndLogs` doing the actual purging. It is reached through **`SYS.ApplicationError`** in `%SYS` — a supported API with list, detail and three delete scopes, taking the namespace as a parameter. (An earlier statement here that there is no class API was wrong; the architecture pass found it.)
- **The classic portal does share the browser login.** `/csp/sys`, `/api/admin` and `/ui/interop` all carry `GroupById = %ISCMgtPortal` — and `/ui/interop` is the application the auth spike already observed sharing the session, so the same mechanism covers the classic portal. Two corrections come with it: `/csp/sys` is **not** JWT-enabled, so it rides the CSP session cookie rather than the token pair; and it permits unauthenticated access, so after sign-out it may keep rendering unauthenticated rather than showing a login form.
- **JWT on the Atelier API: yes mechanically, no as shipped.** `/api/atelier` sits outside the portal group with JWT off. Enabling it would work, but it is a change to a *vendor* web application, which this project does not make on an operator's instance. Stage 3 routes Atelier through the OcuPilot API or an explicit Basic header, as the spine already decided.

Three further questions the PRD listed were closed earlier by the architecture spine's own probes and never entered this spec: tool execution transport (in-process), install timing (container start), and the "admin API write payloads are unobserved" risk (schemas generate from the endpoints' own body templates).
