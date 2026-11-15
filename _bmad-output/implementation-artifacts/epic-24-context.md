# Epic 24 Context: Stage 5, second lane - interoperability, analytics, developer tools and the agent's harvested tools

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This epic is the share of Stage 5 (custom-REST parity built from harvested MCP-suite handler bodies) that runs in a second slot beside Epic 21. It covers the remaining interoperability surfaces, the analytics editors Epic 20's rider left out, a developer-tools set, and the last two steps of the agent's growth: the 28 harvested interoperability inspection and search tools, and undo by snapshot and revert. None of these stories depends on a story Epic 21 still holds. Each one harvests through Story 21.1's seam, which is on the feature branch, and the interoperability and analytics stories extend Epic 20, which has merged. Story 24.1 is done: it shipped LOC metrics and drift hashes. The other developer-tools surfaces were split out of it into Stories 24.5 to 24.9.

## Stories

- Story 24.1: Developer tools (done: code metrics and document hashes)
- Story 24.2: The analytics editors
- Story 24.3: Interoperability parity
- Story 24.4: The agent gains the harvested tools and undo
- Story 24.5: Unit-test runner and work-queue viewer
- Story 24.6: The command and class-method consoles
- Story 24.7: Web terminal
- Story 24.8: Remote instance profiles and environment diff
- Story 24.9: Environment promote

## Requirements & Constraints

- **One contract for every screen.** Each screen is declared by exactly one descriptor and reaches outside OcuPilot through exactly one port. Its read tool, and its write tools' field lists, derive from that descriptor; no tool code is written by hand. Every write goes through a server-minted proposal, an instance-computed diff, an explicit confirmation and an agent audit marker. A story is accepted on that contract plus each catalog row's backing class ("round-trips over its backing class").
- **Governance baseline.** Every new write key joins the baseline in the story that ships it. Every new destructive key ships disabled (a `false` line), and destructive actions are named as destructive. Purge, deployment, promote, the consoles and the terminal carry the highest consequence in this epic. Read-only surfaces add no key.
- **Harvest cautions.** Take handler bodies and nothing else: the MCP suite's manifest is stale and its bootstrap is driven from TypeScript. Read the current body before harvesting it. Rename everything harvested, comments included: no `ExecuteMCPv2.*`, `SessionAgent.*` or `%Atelier` token, no `/api/executemcp/v2`, no `^UnitTestRoot` or `^ExecuteMCPv2*`, no `%ExecuteMCPOutput`, no `[IRIS-MCP-TRUNCATED…]` marker, no `iris_` tool prefix and no `IRIS_*` environment variable. The ObjectScript checker refuses the forbidden tokens.
- **Secrets and paths.** Credentials and passwords never reach a displayed surface or a log. No caller value is concatenated into SQL, and no endpoint accepts a filesystem path. Deployment, export and import files are named from a fixed enum or a strict single-segment name.
- **24.2:** the term-list editor, the folder manager's export, import and delete, and the remaining analytics editors.
- **24.3:**
  - Deployment writes its log and rollback files, and the deployment history offers rollback and delete.
  - The hidden EnsPortal pages (service registries, interface maps and references) have only estimated action sets. Identify their backing class on the instance first.
  - It carries ledger items DW-2361, DW-2554, DW-2433, DW-2378, DW-2379 and DW-2452 (probe-namespace guard coverage, business-partner Edit reverting fields, the missing cut note at the Contents cap, HL7 paste double translation, the unannounced Test dialog result, the empty-state agent key wording).
- **24.4:**
  - Each of the 28 tools declares `read` or `write` at definition time and passes the single call-time gate.
  - Undo takes a snapshot before the write and offers a one-click revert. The revert is itself a confirmed proposal with its own diff and its own audit marker; undo is not exempt from the write model.
  - The state-capture model is designed here, not retrofitted. No AD covers it yet, so the story needs a spine amendment.
- **24.6:** the execute-command console's output is capped by the harvested output ceiling (32,768 characters), never unbounded.
- **24.8 and 24.9:**
  - Remote instance profiles land before environment diff and promote, which depend on them.
  - Promote keeps its four gates: a plan, execute-with-confirm, a steps allow-list, and plan-hash freshness. It has no rollback, and the screen says so.
  - **Both wait on an open owner question.** Any test connection, diff read or promote write sends a request to another host. That contradicts three planning statements: no request leaves the instance except to the configured provider; OcuPilot manages only the instance that serves it; and multi-instance management is "Not planned". The proposed resolution is an owner-approved exception plus a new remote-instance port AD. Under it, the host is judged by `Kernel.Egress`, the credential comes only through the wallet, and the port talks only to the remote's `/api/atelier`. Until the owner answers, these two stories are marked waiting, not planned. Two further open points (inference): profile writes would be a person's own admin write and not a proposal, and the sibling's config diff reads through its own REST, which a remote without OcuPilot does not serve.

## Technical Decisions

- **Harvest seam (AD-23).** Harvested bodies inherit Story 21.1's base, `OcuPilot.Port.Harvest.Handler`, which exposes `RenderResponseBody(pStatus, pMsgPart, pResPart)` and emits OcuPilot's envelope. Only the base class changes; a body is never edited to change the response shape. A harvested support library joins its handler by inheritance (it extends `Kernel.Utils`, `[ Abstract ]`), so `..X()` calls resolve while a body is switched to a namespace where OcuPilot classes are not visible. A harvested call into `%Atelier`'s text reader becomes `Kernel.Utils.DocumentLines`, which was measured to answer the same lines.
- **Bodies run only through `HarvestPort.Invoke`, called by one area port.** `HarvestPort`'s `SanitizeError` turns a body's own refusal into `INTERNAL`. So the area port validates shape, refuses wide input and applies cost caps itself, before any body runs. It sends only the query keys it built. A body with no output cap gets a pre-count: count first and refuse over the cap, rather than truncating after the scan. Bodies switch namespace by save and restore (AD-16), and no `OcuPilot.*` class is named by `##class` while one is switched. A caller-containment rule for bodies (DW-2560) is owned by Story 21.2: whichever of 21.2 and an Epic 24 story reaches the feature branch second adds the other's rows.
- **`DevToolPort` (Story 24.1)** is the developer-tools port. It takes `AtelierPort`'s gate in a fixed order: `Pairs()`, namespace shape, `NamespacePairs(ns)`, spec shape, the wide-spec rule, then the document cap. It passes the full pair set to `HarvestPort`. 24.5 and 24.6 extend it rather than adding ports. It is not yet in AD-29's Binds; that amendment waits for the owner's attended architecture update. Caller SQL never goes through Atelier's `action/query`, which prepares with privilege checks off (AD-61).
- **Envelope (AD-12, AD-39).** One flat error envelope with a single response writer, and the no-double-envelope test must keep passing. Vendor `%Status` text is normalized before it reaches the screen or the model. Tool results are sanitized (AD-60).
- **Ports (AD-29, AD-52).** Every port carries its own authorization gate, and the vendor's own check is only a lower bound. A write tool declares its port. The fresh read, the confirm's re-read, the prohibited-set check and the write all resolve through that declaration.
  - Interoperability goes through `InteropPort` (AD-62), the only class that reads or writes production configuration. Items are identified by `[Production, Name]`, never by the vendor's integer id. A write also calls `SaveToClass`, and a namespace under source control refuses item writes. The vendor's Angular editors load in a same-origin frame, and OcuPilot never reaches into that frame (AD-63).
  - Analytics goes through `AnalyticsPort` (AD-65). It calls `%DeepSee` classes in process, never `/api/deepsee`. It checks the endpoint's pairs, the namespace's shape, whether the namespace has analytics, and database READ. It calls only reads measured to write nothing: never `%GetMemberTree`, `%GetDimensionMembers` or `%GetFavoritesForUser`. Any editor write extends this port.
- **Write model.** The proposal is single-use, fingerprinted and expires (AD-6). OcuPilot computes the merge and sends a complete body (AD-4). An action-style write declares its own request type (AD-51). A screen's action and the agent's write are one operation reached by two callers (AD-53). After the write, the target is read back to confirm it holds what was sent (AD-58). One change event is emitted, and screens re-fetch rather than patch (AD-14). Prohibited actions are added only in the kernel (AD-10).
- **Reads (AD-36, AD-5, AD-24).** A screen and its tool share one declared, capped read that reports truncation. Screen context is capped and stripped of secret fields. Each descriptor names the classic page class it replaces, or `""` where none exists (AD-44).
- **Guided workflows (AD-66).** A workflow is a new `XData Catalog` entry, never a code path, and each of its writes is one proposal. The promote workflow stays absent until 24.9 supplies its tools. The spine still names 24.1 for it, pending the owner's update.
- **Dry-run and confirm double gate.** This is the reference pattern for purge and promote. Dry-run returns a distinct typed shape. A match count over the cap is refused, never truncated and then executed.
- **The 28 tools** come from iris-session-agent's `Tool.*` and are all read-only and Ens-specific. They cover session summary and timeline, message header, detail and body, event and rule logs, explain error, BP instance, source and methods, related sessions, queue state, config item, and the `search_by_*` family. Take the rules, not the mechanism:
  - the cross-vendor JSON-Schema subset (no `$ref`, `oneOf`, `anyOf`, `allOf` or `pattern`);
  - bounded time-window searches on an indexed lead column;
  - a tool never touches `%session`, `%request` or `$NAMESPACE`.
- **Reusable harvested helpers:** namespace switch and restore, the validators, `SanitizeError`, `ApplyOutputCeiling`, `SurrogateSafeCutLength` and `DocumentLines`.

## UX & Interaction Patterns

- The proposal review card shows the target, the changed fields as before/after rows, the unchanged fields collapsed under "N unchanged fields", the rationale, the expected impact, and a "Reverse:" line where a reversal exists. Undo builds on that line.
- A destructive action uses the typed-name confirm dialog. It states the consequence and ends with "This cannot be undone." where that is true.
- Developer tools that read code sit in System Explorer under its gate; there is no new area. Side-bar positions are contended with Epic 21, so check both branches before claiming one. The generic list page cannot show a refusal's reason, so 24.1 added one bespoke page, `dev-tool.page.ts`, over the generic table. Later developer-tool screens extend that page and its store rather than copying them.
- New user-facing strings go into EXPERIENCE.md's Fixed strings.

## Cross-Story Dependencies

- Every story depends on Story 21.1's seam, which is on the feature branch.
- Run order after the split: 24.2, 24.3, 24.4, then 24.5 to 24.9.
- 24.3 extends Epic 20's Interoperability slice and `InteropPort`. 24.2 extends Epic 20's analytics rider and `AnalyticsPort`. An open owner question may touch 24.2.
- 24.4 gives the agent reach into interoperability through `InteropPort`. Ordering it after 24.3 follows from the epic's story order (inference). Undo applies across the write tools from earlier epics.
- 24.5 and 24.6 extend 24.1's `DevToolPort`. 24.8's document diff may reuse 24.1's hashes (inference). 24.9 follows 24.8, and both wait on the owner question above.
- Epic 21 runs in parallel on another slot. Do not take its stories (backup, mirroring, settings, globals, SQL tuning, remaining leaves). Single-line rosters (`Screen/Read`, `Screen/Registry`, `Test/PortGate`) and the literal tool, screen and navigation counts in the roster tests are contended with it. Check them against `OCU-1-epic21` before implementing.
