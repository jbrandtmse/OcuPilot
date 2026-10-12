# Epic 18 Context: Stage 2 - the rest of the admin API

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

An operator reaches System Administration and System Operation parity on the experimental `/api/admin` v2 service, and on `/api/mgmnt` and `/api/monitor` where those back a row, so no such task needs the classic portal. Each screen comes from one descriptor and brings a read tool, plus confirmed single-write tools where it writes. The agent has grown with the stage: every Stage 2 tool is declared from its descriptor (18.12), each turn is assembled within a result budget with prompt caching and a billed-weight token bound (18.39), and each call carries only the shell area's tools, the screen's tools and what the discovery tool `shell.tools.find` finds (18.45). What remains: OcuPilot installs into a namespace the operator chooses (one per instance), uninstalls cleanly on a shared instance, lets a person (never the agent) edit the directory allow-list, adds interoperability usage and a live log tail, and gives the provider call proxy, custom-CA and wallet-key configuration. This is the first versioned IPM release after the contest. Done: 18.1 to 18.12, 18.14 to 18.34, 18.36, 18.39 and 18.45 (18.27 closed unbuilt, 18.35 retired). Run order: 18.13, 18.43, 18.42, 18.37, 18.38, 18.40, 18.41, the Epic 18 burn-down, then the epic close.

## Stories

- Stories 18.1 to 18.12, 18.14 to 18.34 and 18.36: the Stage 2 screens and the agent's growth (done)
- Story 18.13: Multi-namespace install (ready for dev)
- Story 18.37: Interoperability usage
- Story 18.38: The live log tail
- Story 18.39: The agent's context budget (done)
- Story 18.40: Proxy and custom CA configuration
- Story 18.41: The wallet credential rung
- Story 18.42: Allowed directories: a person's write
- Story 18.43: Uninstall and grants on a shared instance (ready for dev)
- Story 18.45: The agent's tool roster scoped per turn (done)
- The Epic 18 burn-down (chartered at the burn-down gate; not in the epics file)

## Requirements & Constraints

- **One contract (FR-80).** Each screen is one descriptor over one port; its read tool and its write tools' field lists derive from that descriptor. Every agent write is a server-minted proposal, an instance-computed diff, an explicit confirmation and an agent marker. Every read is bounded and reports truncation. Every gate checks the caller's own privileges at call time. A story's acceptance is that contract plus each row's backing route; anything finer is authored at its spec gate.
- **Governance (AD-22).** Every destructive or disruptive key ships `false`; a story that adds a write key adds its `Kernel/Governance/Baseline.cls` entry in the same change. Governance is asked at dispatch and at Confirm, never for a person's own screen write (AD-53, AD-55). A denied call returns a structured result and the tool stays reachable.
- **Observe first.** Measure each route's payload, effects, privileges and audit events on the slot's throwaway (`ocupilot-ci`) before a form or tool exists, as a least-privileged principal, never from the specification. Never build on a `decision-pending` ledger entry; never report a vendor-defect candidate upstream (the owner holds them). Install runs only on a throwaway; recreating `ocupilot` is the owner's call. A live provider key is read from `.env.local` at the point of use, on `ocupilot-ci`, never printed or committed; every live Anthropic check uses `claude-haiku-5-5` (owner, 2026-10-12).
- **Budgets.**
  - Bundle: 3,388,876 B initial at 18.12 (18.39 and 18.45 changed no client code), against the 3527kB warning and 4000kB error budget. A story that crosses the warning re-bases it to 5% above the merged total (DW-1166); stop and ask above 3800kB.
  - Fixed strings: 3,306 literals in EXPERIENCE.md's table (after Epic 20's forward merges), against the 3,400 drift tripwire, raised only once the count comes within 50 of it.
  - `Api/Error.cls` holds 989 of a class's 1,000 parameters; new codes go in a sibling `*Error.cls` with prefix arms in `Error`'s reason mappers.
  - Tools: 374 read tools after 18.45 (`shell.tools.find` added), pinned by `Test/ReadTool` and token-unioned at each forward merge.
  - A spec stays under 16 KB, or the story halts with a proposed split.
- **Ledger, by owner.** Address each item, or decline it with a reason.
  - **18.13:** DW-423 (keep each profile's newest 100 `Stamp` rows in the retention sweep) and DW-1333 (the installer enforces the IRIS floor IPM's exporter drops). DW-1788 stays wontfix-theoretical under one install namespace per instance.
  - **18.43:** DW-219 (uninstall's three half-state paths) and DW-2172 (install warns on a widened schema grant).
  - **18.42:** DW-2334, decided by the owner on 2026-10-11.
  - **18.37, 18.38, 18.40, 18.41:** none routed.
  - **The burn-down fixes** DW-2311, DW-2320, DW-2322, DW-2328, DW-2329, DW-2333, DW-2335 and DW-2340 and audits DW-2327. Its gate also holds DW-1896, DW-1966, DW-1979, DW-1981, DW-2007, DW-2085, DW-2086, DW-2087, DW-2100 (high), DW-2126, DW-2149, DW-2167 and DW-2299 (after Epic 20 merges), plus the CI flakes DW-2111 and DW-2123. DW-2160 was pulled forward into 18.45's sweep.

## Technical Decisions

**Every story**

- **Containment (AD-2, AD-27).** Only `AdminPort` names `%Api.Admin.*` and reads the outcome from both `tSC` and `%response.Status`. A read answered 404 is an absence and is not logged; any other failure outside the unlogged list is logged and raises the instance's alert state, so refuse a predictable vendor refusal before the call. A queued write still running at the bound answers as started (AD-26).
- **Gates (AD-8, AD-29).** No service account; the only OcuPilot elevation is AD-9's, never in effect while tool, port or provider code runs. Each port carries its own gate, evaluated before any vendor call. `ResourcesOR()` is a lower bound: read the backing class's own check, then run as a real least-privileged principal. A write tool declares a pair beyond its screen's set only when measured, refused by name before any port call.
- **The turn never mutates the instance (AD-7).** Exactly six vendor-internal write shapes are permitted; a new one needs a spine amendment at its spec gate. Never call the alerts read, which advances `LastAlertSent`.
- **Read contract (AD-24, AD-36).** 200 rows by default (an operator sets 1 to 1,000), 65,536 characters in total cut by whole rows, 1,000 characters a field; the payload reports `rowsSent`, `rowsAvailable` and truncation. A turn's tool results carry at most 262,144 characters together.
- **Writes.** A merge reads fresh and sends the complete body (AD-4); a create fingerprints the target's absence (AD-54); an action its declared preconditions (AD-51). The screen and the agent are two callers of one tool (AD-53, AD-55) under the per-target hold (AD-34), with a read-back (AD-58), a change event (AD-14) and a script form (AD-59). An unadvertised tool is reachable by its screen alone, and the discovery tool never finds it (AD-53).
- **The tool set (AD-5, AD-8, AD-24).** The listing is built from compile-time declarations, kept per process, and revalidated by compile signature; a value read at run time never enters it. A call carries the shell area's tools and the screen context's `tools`; every other advertised tool is reached through `shell.tools.find` (Anthropic: the whole set with `defer_loading`; other families: the starting set plus each found tool).
- **Self-protection (AD-10).** Predicates over the effect, refused whatever the caller and evaluated inside the confirm's atomic transition; a rule only a screen enforces is not a prohibition. Each lives once in `Kernel/Proposal/Prohibited.cls`, its refusal sentence published once in Fixed strings and pinned equal to the kernel's reason. A privileged grant (`%All` or `%Admin_*`) is permitted at the destructive treatment.
- **Text and amendments.** Vendor text is logged, never sent (AD-39); model-bound text passes AD-60's sanitizer. New pairs, predicates, source kinds, vendor-write shapes and carve-outs are amended into the spine at the spec gate (Rule 20). Rule 31: name the sibling a new class extends, or say why a copy is better.

**18.13, multi-namespace install (ready for dev)**

- **One install namespace per instance (AD-17).** It is the namespace holding the profile's `OcuPilot*` globals mapping. Install validates the target each path names: it refuses `%SYS` and system namespaces, a missing namespace, an IRIS below the roster's floor, a namespace whose `OcuPilot` package resolves from another database (AD-9), and any namespace but the one already holding the mapping. Uninstall and the container start refuse a second namespace the same way; a refusal changes nothing in either namespace.
- **Code and data (AD-9, AD-21).** Code lives in the install namespace's own routine database; only OcuPilot's globals sit behind its protected resource. A definition whose `creds` rung the namespace cannot reach is reported, never refused.
- **Closed by Story 18.13.** IPM re-points the live applications at the start of `Activate`, so a guard invoke after `Compile` (`Installer.GuardTarget`) refuses a second namespace before IPM touches an application.

**18.43, uninstall and grants on a shared instance (ready for dev)**

- **Uninstall (AD-37, DW-219).** It removes only what OcuPilot created and still owns: it keeps, and reports, the shell bundle directory while an application sits at the shell's path and a roster matching role while a surviving application carries it, and refuses, removing nothing, when its provenance record is unreadable while the profile's routine application exists.
- **Widened grant (AD-38, DW-2172).** Install warns naming every grant on OcuPilot's schemas to a grantee other than the escalation role, read from `Security.SQLPrivileges`; it never refuses or revokes one.

**18.42, allowed directories: a person's write**

- **AD-21 as amended (owner, DW-2334).** A person adds, changes and removes `FSAccess` entries (`Path`, `Purpose`) on the Allowed directories screen as a confirmed write whose governance key ships disabled, and the roots OcuPilot needs to run cannot be dropped.
- **The agent never writes the list.** The kernel refuses any agent write, narrowing included, in the AD-10 and AD-21 self-protection family; leaving the tool unadvertised (AD-53) is not enough. A reason found at the gate for letting the agent narrow it is the owner's question.
- **The fence it moves (AD-21's sixth case).** `Port/PathPort` alone computes the roots, at call time and never cached: when the instance restricts `%GUIFileSelector`, that purpose's paths (`FSAccess.Purpose` `GET`, `FSAccess.Path` `LIST`); otherwise `<ManagerDirectory>` alone. A write tool resolves again at its write, so a root dropped after a mint refuses that confirm. The screen declares `%Admin_FileSystemAccess:USE` as its own pair beside Security's set (AD-8).
- **Gate question.** AD-22 never asks governance for a person's screen write, so the disabled key alone cannot hold that write (inference); the gate settles what the key governs.

**18.37, interoperability usage**

- **The catalog row's source fails AD-8.** It names the deprecated `/api/monitor/interop/v1` (`%Api.InteropMetrics.v1`), which checks nothing and reaches `[Internal]` setters that escalate with `$$$AddAllRoleTemporaryInTry`; AD-8 accepts a vendor running as itself only after the vendor has checked the caller.
- **The preferred source.** The classic page (`%CSP.UI.Portal.InteroperabilityUsage`, `RESOURCE` `%Admin_Operate`) queries `SYS.Monitor.Interop.Interface.Utils:InteropInterfaces`. The gate prefers the source that keeps AD-8 as written; relaxing AD-8 is the owner's call. Whether the sensor setters write state (a new AD-7 shape) is a gate question; the port declares its own gate (AD-29), consistent with AD-62's one-port model (inference).

**18.38, the live tail**

- **Sources and route.** `messages.log` and `alerts.log`, the only sources with `LogSourcePort`'s offset-and-identity cursor, opt in through a descriptor key (an AD-5 addition) and keep their classic pages' resources. No vendor event signals a log write, so an OcuPilot route long-polls within `Kernel.Provider.TestCall.BoundSeconds`, re-checking the file's size and identity; rotation restarts the tail cleanly (AD-21). No endpoint accepts a path.
- **Amendments at its gate.** Heartbeat bytes need a second AD-12 device-write carve-out and an AD-43 amendment; whether concurrent tails need a per-user bound, as turns have (AD-41), is a gate question (inference: each poll holds a server process up to the bound). Log text reaching the model passes AD-60.

**18.40, proxy and custom CA**

- **What ships.** The installer creates `OcuPilotProvider` with server-identity checking on (AD-32). `Kernel/State/Egress.cls` stores the proxy settings and SSL configuration name, `SetGuarded` is its one writer, and no route renders it. `ProviderPort` judges the proxy host and CONNECT-tunnels https; a marked-local endpoint bypasses the proxy (AD-42). `Api/Switches.cls` is the sibling settings surface.
- **Custom CA.** A separately named SSL/TLS configuration, because AD-10 refuses a `CAFile` change on OcuPilot's own; AD-32 is amended at the gate, and how far a custom CA is trusted is the owner's call. Test connection exercises the same path as a turn.

**18.41, the wallet rung**

- **The ladder.** `Kernel.Secret.Ladder` ships the `env` and `creds` rungs; a wallet rung joins them on the wallet wiring the secrets screens use. AD-42, AD-35 and AD-7 are amended at the gate. The rung's name fits `CredType` (at most 8 characters).
- **Key handling (AD-35, AD-42).** The ladder never returns a value into a status or an error; the key is fetched at the point of use, cleared before return, never interpolated. A test asserts a forced provider failure leaves no credential in the error log. `Port/WalletPort.cls` never reads a value today, so reading one is new behavior: read `%Wallet.KeyValue` `GetSecretValue` and `ApplyHTTP` first. The vendor's per-use audit write (`%Wallet.Secret` `AuditUsage`) is a candidate seventh AD-7 shape (inference until Task 0). Any choice that exposes a secret or adds a vendor audit write is the owner's.

**The burn-down**

- **DW-2311.** In `MgmntPort.Resolved`, walk each listed application's `UrlMap` `Forward` targets and read `GetWebRESTApps` over every namespace, so a forwarded or cross-namespace service counts as deployed.
- **DW-2320 and DW-2322.** In `GrantsPrivilegeByEffect` (`Prohibited.cls`), key held and wanted `MatchRoles` targets by matching role and target; clearing a privileged routine application's `Resource`, or enabling it, while it grants a privileged role takes the privileged-grant treatment.
- **DW-2328.** Rows of an id-kind-none list share one key when the name column repeats (MetricsList, `RoutineAppRoleList`'s Every caller row); give them a row-unique key or declare composite ids.
- **DW-2329.** `MonitorPort.Samples` handles a label value ending in a single or doubled backslash, and skips and counts one unreadable line rather than failing the table.
- **DW-2333.** A detail read over a web application's `MatchRoles`, on 18.12's routine-application detail-read pattern, so `webapp.list.update` can send the list with one entry changed.
- **DW-2335.** Editor forms show fields no read tool answers (superservers 14, local databases 10, user copy 12): widen the reads, or record why each stays form-only.
- **DW-2340.** The Dashboard's drill-down links (`dashboard.page.ts` `linksFor`) gate on the screen verdict with `aria-disabled` and the Requires reason, as the side bar and Home do.
- **DW-2327.** Audit the two-argument `%GetNext` sites over caller-controlled JSON (500 on an oversized value, where the three-argument form answers 422 or 400); fix them, or charter a sweep if there are many.

## UX & Interaction Patterns

- **Screens.** Every built screen registers the screen contract with at least three suggested prompts (11.3). The side bar lists only built screens.
- **Strings.** New strings go in EXPERIENCE.md's Fixed strings, edited in place with the line count unchanged, one `strings.ts` key per value. Run `cd ui && npm run test:tools` after editing EXPERIENCE.md or epics.md.
- **Gated controls.** A gated control stays focusable with `aria-disabled="true"`, never `disabled`, and names its reason (EXPERIENCE.md's Mechanism, :216).
- **A person's write.** It is reviewed by the screen's own confirm dialog, with the typed-name field on a destructive one, never by a proposal (AD-53); a new dialog joins EXPERIENCE.md's list of the only dialogs that exist (:173).
- **Allowed directories (18.42).** The screen's and the server-path picker's strings sit in EXPERIENCE.md :364.
- **Auto-refresh (AD-43).** One shared framework, paused while a proposal is live; a screen joins only by declaring it and appearing in EXPERIENCE.md's roster of thirteen (:896). Every default is off except Home's.
- **Log viewers (18.38).** Viewers load bounded pages with "Load newer", and nothing streams ("Tail, not live", :899). 18.38 amends that line in place at its gate and re-scopes the "nothing streams" pins in `log-viewer.spec.ts` and `Test/Descriptor.cls` to the sources that do not opt in.
- **Provider settings (18.40, 18.41).** The proxy and SSL settings have no screen today; the credential rung is chosen on the agent definition form.

## Cross-Story Dependencies

- **Run order:** 18.13, 18.43 (re-anchored on 18.13's `Installer.cls`), 18.42, 18.37, 18.38, 18.40, 18.41, the burn-down, then the epic close.
- **Roster pins.** `Test/StageTwoTools.cls` holds Epic 18's screens and every other screen equal to the registry both ways; a new screen or Epic 18 write tool needs its row. `AllowedDirectoryList` is a `read-only` row whose reason says the list is a person's write; 18.42 turns it to `writes`, and an unadvertised tool joins the test's `UNADVERTISED` list. `ReadTool`, `DeveloperFloor`, `InteropFloor` and `InteropFloorOwnPairs` count tools.
- **18.40 and 18.41** rebase on 18.39's and 18.45's `Kernel/Provider/Anthropic.cls` (deferral and cache marker) and both edit `Port/ProviderPort.cls` and `Kernel/Provider/Base.cls`, so 18.41 rebases on 18.40.
- **18.42** adds one guard clause in `Prohibited.cls`, a governance baseline entry and a StageTwoTools row change. **18.37** runs after 18.42, and **18.38** after 18.37.
- **The burn-down** fixes DW-2311 against 18.32's `MgmntPort`, DW-2320 and DW-2322 against 18.33's classifier, and DW-2333 on 18.12's detail-read pattern.
- **Epic 20** runs on slot B (20.13 in implement) and is changing `Screen/Tool/Write.cls`, `Api/ScreenAction.cls`, `Kernel/Agent/Dispatch.cls`, `Kernel/Agent/Loop.cls`, `Screen/Tool/Registry.cls`, `Screen/Tool/MappingMint.cls` and `scripts/ci-throwaway.sh`.
  - A non-add-only edit to a file Epic 20 is changing stops and is reported; `Prohibited.cls` takes one added clause at a time, sent to the orchestrator as a Rule 11 ask.
  - Shared add-only files are unioned at merges: `Kernel/EntityType.cls`, the test rosters, `Screen/Registry.cls`, `Screen/Read.cls`, `Screen/Tool/Classification.cls`, `ToolFields`, `FieldLists`, the governance baseline, `Api/Router.cls` routes, `strings.ts`, EXPERIENCE.md, `angular.json` and the spine. `screens.generated.ts` is regenerated, never hand-edited.
  - Count-pinning rosters are token-merged at each forward merge and re-run fresh; an `angular.json` collision re-measures the merged bundle.
- **The epic close.** No story covers the WQM categories row (SA-05) or the row that enables the mirror service (SA-22); the close assigns or declines each. At Epic 18's merge, DW-2170 reopens if `Wire.cls`'s doc comments still describe a two-member API floor.
