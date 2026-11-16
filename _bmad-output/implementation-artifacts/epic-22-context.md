# Epic 22 Context: Stage 6 - the long tail, on demand

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

Make the 56 catalog rows OcuPilot deliberately does not build (the P4 tier) into a recorded, checkable decision instead of a blank. Nothing here is scheduled for building. The epic records every excluded row with its exclusion reason and a gate specific enough that someone can tell whether it has cleared. It also defines the one way a row leaves the long tail: when demand appears and its gate has demonstrably cleared, the row joins the slice that owns its area under the same contract every screen has followed since Epic 1. Future requests can then be answered against evidence, without reopening the whole catalog.

## Stories

- Story 22.1: The exclusion register
- Story 22.2: Picking up a row when its gate clears

## Requirements & Constraints

- **Scope is exactly the 56 P4 rows.** Sizes are S 11 / M 29 / L 16. Building every row would need 32 new REST endpoints. 18 rows have no backing at all, and 6 already have a route: OS-31, OS-32 and SA-50 on the admin API, SS-40 as an embed, AN-23 partly on DeepSee, and DT-12 on Atelier.
- **Stage numbering differs between documents.** The stage-extract document calls this "Stage 5" because it counts from the first post-release stage. The PRD and the epics call it Stage 6. The rows are the same.
- **The eight groups and their counts** (3+11+9+6+5+10+4+8 = 56) are the extract's own. The register keeps them:
  - **Sharding, gated by license (3):** SA-50, SA-51, SA-52. The gate is a sharding license; `$$Sharding^%SYS.LICENSE` reads 0 on Community.
  - **Pages gated by edition: HealthShare, Message Bank, Enterprise, ITK (11):** SS-40, IO-71, IO-74 to IO-81, IO-90. The gate is the edition. For IO-90 it is ITK being present on the instance.
  - **Deprecated features: shadowing and iKnow Text Analytics (9):** LG-13, SA-59, SO-18, SO-19, AN-18 to AN-22. The gate is a decision to support a deprecated feature at all.
  - **Zen Reports, InterSystems Reports and cluster settings (6):** SA-53 to SA-58.
  - **Low-usage or Windows-only pages (5):** WA-17, OS-31 to OS-34. WA-17 and OS-34 are gated by the Windows platform.
  - **Non-HL7 EDI authoring, DICOM, PubSub, adapter dialogs and legacy interop (10):** IO-72, IO-73, IO-82 to IO-89.
  - **Full applications linked rather than rebuilt (4):** AN-23, EX-55, EX-56, EX-57.
  - **Dead references, placeholders, cosmetic items and rows that do not apply (8):** SH-29, SA-60, SA-61, SA-62, AN-24, DT-12, EX-58, PK-26. DT-12 is gated by a debugger implementation existing. PK-26 is gated by the AI Hub early-access program.
- The extract does not name a gate for every group. Where it gives only a reason ("low-usage", "Zen Reports", "dead reference"), Story 22.1 states the gate. A license, edition, platform or deprecation gate must be named precisely enough to test.
- **The cheapest rows to promote** are OS-31, OS-32 and SA-50. They are backed by the admin API and need no new API.
- **Rules for picking up a row:**
  - Check the recorded gate first. The row is built only if the gate has cleared.
  - If the gate has not cleared, the answer names the gate as the reason and the row stays in the long tail.
  - A promoted row gets the read-tool and confirmed-write-tool pattern of the stage its API belongs to. This epic adds nothing to the agent itself.
  - Acceptance is the contract below plus the row's own backing route or class. Anything finer is authored when the row is picked up and is not invented in advance.
- Each stage ships as a versioned IPM release with a Developer Community article.

## Technical Decisions

Every picked-up row follows the one screen contract:

- **One descriptor per screen** (AD-5). It is hand-written and declarative. Route, navigation, privilege gate, read tool, write tools, screen context and change-event key are all derived from it. Adding a screen never means editing a router, a nav list or a tool registry. The client mirror is generated from the descriptor (`screen-mirror.mjs`).
- **Write field lists come from the endpoint's body template** (AD-3). They are never transcribed by hand. Only the semantic half (required fields, enums, descriptions) is authored, once per tool.
- **Every write goes through the proposal path:** a server-minted, single-use, fingerprinted proposal (AD-6), an instance-computed diff, an explicit confirmation and an audit marker (AD-15). Action-style and create writes follow AD-51 and AD-54.
- **Governance:** a new write key joins the governance baseline in the same change (AD-22). A new destructive key defaults to disabled. A prohibited action is added only to AD-10's single prohibited set, never to a policy file.
- **Ports:** anything outside OcuPilot is reached through exactly one port, and every port carries its own authorization gate (AD-29). A row that needs an outside system no existing port covers needs a new port, which means amending the spine first.
  - Only `AdminPort` names `%Api.Admin.*` classes (AD-27). This applies to OS-31, OS-32 and SA-50.
  - Interoperability rows go through `InteropPort` (AD-62). Analytics rows go through `AnalyticsPort` (AD-65).
- **Classic page resources** (AD-44): a descriptor declares the classic page class it replaces, and any custom resource assigned to that page joins its privilege set. Namespace-gated areas use `appliesWhen`.
- **Server paths and SQL** (AD-21): no caller value is concatenated into SQL, and no endpoint accepts a path. Server paths go through the allowed-directories picker. This matters for EDI schema import and the report-server settings.
- **The slice boundary is fixed:** a promoted row lands in the slice that already owns its area, and a slice never reaches into another slice.
- The spine's capability map lists Stage 6 as "on demand" with no AD of its own. A promoted row is governed by the ADs of the stage its API belongs to.

## UX & Interaction Patterns

- Work OcuPilot has not rebuilt stays one click away in the classic portal, through the `classic-link-card` ("More in the classic portal", opens in a new tab). A reduced form carries daily-administration fields plus the link, never a half-working full form.
- An `external` screen (Story 20.32) declares no read, table or actions. It opens a page from `Screen/ExternalPage`'s closed vocabulary in a new tab, with no opener. This is the existing pattern for applications that are linked rather than rebuilt. (inference) The Architect, Analyzer and User Portal links that AN-23 points to may already ship this way; check the instance before treating AN-23's "link instead" as open work.

## Cross-Story Dependencies

- Story 22.2's gate check reads the gates Story 22.1 records, so 22.1 lands first.
- A promoted row is built inside the owning area's slice and follows the contract the earlier stages established: Epic 18 (admin API), Epic 19 (Atelier), Epic 20 (Interoperability and Analytics), Epic 21 (custom REST endpoints from the harvested MCP-suite handlers).
- Related rows in earlier epics: IO-20 and IO-21 (read-only X12 and ASTM schema browsing) are P2 rows in Epic 20, while their authoring halves (IO-86, IO-87) are P4 here. AN-04 to AN-06 are the analytics links that AN-23 defers to.
