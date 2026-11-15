# Epic 24 Context: Stage 5, second lane - interoperability, analytics, developer tools and the agent's harvested tools

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

This epic takes the share of Stage 5 (custom-REST parity built from harvested MCP-suite handler bodies) that can run in a second slot alongside Epic 21. It covers the remaining interoperability surfaces, the analytics editors that Epic 20's rider left out, a developer-tools set (unit-test runner, work queue, consoles, metrics, environment diff and promote), and the last two steps of the agent's growth: the 28 harvested interoperability inspection and search tools, and undo by snapshot and revert. None of these stories depends on a story Epic 21 still holds. Each one harvests through Story 21.1's seam, which is already on the feature branch, and the interoperability and analytics stories extend Epic 20, which has merged.

## Stories

- Story 24.1: Developer tools
- Story 24.2: The analytics editors
- Story 24.3: Interoperability parity
- Story 24.4: The agent gains the harvested tools and undo

## Requirements & Constraints

- **One contract for every screen.** Each screen is declared by exactly one descriptor and reaches outside OcuPilot through exactly one port. Its read tool, and its write tools' field lists, derive from that descriptor; no tool code is written by hand. Every write goes through a server-minted proposal, an instance-computed diff, an explicit confirmation and an agent audit marker. A story is accepted on that contract plus each catalog row's backing class. Anything finer is worked out when the row is picked up.
- **Governance baseline.** Every new write key joins the baseline in the story that ships it. Every new destructive key ships disabled (a `false` line), and destructive actions are named as destructive. Purge, deployment, promote and the consoles carry the highest consequence in this epic.
- **Harvest cautions.** Take handler bodies and nothing else: the MCP suite's manifest is stale and its bootstrap is driven from TypeScript. Read the current body before harvesting it. Rename everything harvested: no `ExecuteMCPv2.*` or `SessionAgent.*`, no `/api/executemcp/v2`, no `^UnitTestRoot` or `^ExecuteMCPv2*`, no `%ExecuteMCPOutput`, no `[IRIS-MCP-TRUNCATED…]` marker, no `iris_` tool prefix and no `IRIS_*` environment variable.
- **24.1:**
  - The execute-command console's output is capped by the harvested output ceiling (32,768 characters).
  - Environment promote keeps its four gates: a plan, execute-with-confirm, a steps allow-list, and plan-hash freshness. It has no rollback, and the screen says so.
  - Remote instance profiles (DT-11) land before environment diff and promote (DT-09, DT-10).
  - The promote guided workflow stays absent until this story supplies its tools.
- **24.3:**
  - Deployment writes its log and rollback files, and the deployment history offers rollback and delete.
  - The hidden EnsPortal pages (service registries, interface maps and references) have only estimated action sets. Identify their backing class on the instance first.
  - The story carries ledger items: probe-namespace guard coverage (DW-2361), business-partner Edit silently reverting fields (DW-2554), the cut note missing at the Contents cap (DW-2433), HL7 paste double translation (DW-2378), the Test dialog result not announced (DW-2379), and the empty-state agent key wording (DW-2452).
- **24.4:**
  - Each of the 28 tools declares `read` or `write` at definition time and passes the single call-time gate.
  - Undo takes a snapshot before the write and offers a one-click revert.
  - The revert is itself a confirmed proposal with its own diff and its own audit marker; undo is not exempt from the write model.
  - The state-capture model is designed here, not retrofitted.
- **Secrets and paths.** Interoperability credentials and passwords never reach a displayed surface or a log. No caller value is concatenated into SQL, and no endpoint accepts a filesystem path. Deployment, export and import files are named from a fixed enum or a strict single-segment name.

## Technical Decisions

- **Harvest seam (AD-23).** Harvested bodies inherit Story 21.1's OcuPilot base class, which exposes `RenderResponseBody(pStatus As %Status, pMsgPart As %DynamicArray, pResPart As %DynamicObject) As %Status` and emits OcuPilot's envelope. Only the base class changes; a body is never edited to change the response shape. Story 21.2 carries a known gap (DW-2560): bodies are public class methods with no policing yet.
- **Envelope (AD-12, AD-39).** One flat error envelope with a single response writer, and the no-double-envelope test must keep passing. Vendor `%Status` text is normalized before it reaches the screen or the model.
- **Ports (AD-29, AD-52).** Every port carries its own authorization gate, and the vendor's own check is only a lower bound. A write tool declares its port. The fresh read, the confirm's re-read, the prohibited-set check and the write all resolve through that declaration.
  - Interoperability goes through `InteropPort` (AD-62). It is the only class that writes or reads production configuration. Items are identified by `[Production, Name]` and never by the vendor's integer id. A write also calls `SaveToClass`, and a namespace under source control refuses item writes.
  - The vendor's Angular editors load in a same-origin frame, and OcuPilot never reaches into that frame (AD-63).
  - Analytics goes through `AnalyticsPort` (AD-65). It calls `%DeepSee` classes in process, never `/api/deepsee`. It checks the endpoint's pairs, the namespace's shape, whether the namespace has analytics, and database READ. It calls only reads measured to write nothing: never `%GetMemberTree`, `%GetDimensionMembers` or `%GetFavoritesForUser`. Any editor write extends this port.
  - The Atelier-backed developer tools go through `AtelierPort` (AD-61). Caller SQL never goes through `action/query`, which prepares with privilege checks off.
- **Write model.** The proposal is single-use, fingerprinted and expires (AD-6). OcuPilot computes the merge and sends a complete body (AD-4). An action-style write declares its own request type (AD-51). A screen's action and the agent's write are one operation reached by two callers (AD-53). After the write, the target is read back to confirm it holds what was sent (AD-58). One change event is emitted, and screens re-fetch rather than patch (AD-14). Prohibited actions are added only in the kernel (AD-10).
- **Reads (AD-36, AD-24).** A screen and its tool share one declared, capped read that reports truncation. Screen context is capped and stripped of secret fields.
- **Classic page keys (AD-44).** Each descriptor names the classic page class it replaces.
- **Guided workflows (AD-66).** A workflow is a new `XData Catalog` entry, never a code path, and each of its writes is one proposal.
- **Dry-run and confirm double gate.** This is the reference pattern for purge and promote. Dry-run returns a distinct typed shape. A match count over the cap is refused, never truncated and then executed.
- **The 28 tools** come from iris-session-agent's `Tool.*` and are all read-only and Ens-specific. They cover session summary and timeline, message header, detail and body, event and rule logs, explain error, BP instance, source and methods, related sessions, queue state, config item, and the `search_by_*` family. Take the rules, not the mechanism:
  - the cross-vendor JSON-Schema subset (no `$ref`, `oneOf`, `anyOf`, `allOf` or `pattern`);
  - bounded time-window searches on an indexed lead column;
  - a tool never touches `%session`, `%request` or `$NAMESPACE`.
- **Reusable harvested helpers:** namespace switch and restore, the validators, `SanitizeError`, `ApplyOutputCeiling` and `SurrogateSafeCutLength`.

## UX & Interaction Patterns

- The proposal review card shows the target, the changed fields as before/after rows, the unchanged fields collapsed under "N unchanged fields", the rationale, the expected impact, and a "Reverse:" line where a reversal exists. Undo builds on that line.
- A destructive action uses the typed-name confirm dialog. It states the consequence and ends with "This cannot be undone." where that is true.
- New user-facing strings go into EXPERIENCE.md's Fixed strings.

## Cross-Story Dependencies

- Every story depends on Story 21.1's seam, which is already on the feature branch.
- 24.3 extends Epic 20's Interoperability slice and `InteropPort`. 24.2 extends Epic 20's analytics rider and `AnalyticsPort`.
- 24.4 gives the agent reach into interoperability through `InteropPort`. Ordering it after 24.3 follows from the epic's story order (inference). Undo applies across the write tools from earlier epics.
- Within 24.1, DT-11 lands before DT-09 and DT-10.
- Epic 21 runs in parallel on another slot. Do not take its stories (backup, mirroring, settings, globals, SQL tuning, remaining leaves).
