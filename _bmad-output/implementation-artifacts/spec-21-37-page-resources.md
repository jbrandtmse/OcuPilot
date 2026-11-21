---
title: 'Story 21.37: Page resources'
type: 'feature'
created: '2026-11-21'
status: 'in-progress'
baseline_revision: '317781c4e3a192147dd5a1da0ef3dcffeeb7ff88'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-21-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-21-21-leaves-that-wait-on-the-owner.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot cannot assign, change or clear a classic page's custom resource (catalog row SH-27). The classic portal does it per menu item through `%CSP.Portal.ResourceDialog`, and OcuPilot's own screens already honor whatever such a resource demands (AD-44, AD-64 rule 2), so an operator has to leave OcuPilot to change who may open a screen.

**Approach:** A Permissions list, Page resources, over a new `PortalResourcePort` that reads `%SYS.Portal.Resources:List` and calls `%CSP.Portal.Utils.%SetCustomResource` in `%SYS` (AD-44's Story 21.21 record). Two write tools, assign and clear, are one operation for two callers (AD-53). The AD-10 `PROHIBITED.OCUPILOTSCREEN` arm refuses an assign on a page a Home or Agent co-pilot screen declares, and a clear or change of a page any OcuPilot screen declares is minted destructive. Owner answer U-74 carries; the strings are the orchestrator's ruled set (veto U-128).

## Boundaries & Constraints

**Always:**

- One descriptor and one port for the screen (AD-5, AD-52). The port gates first (AD-29) on `%Admin_Secure:USE,%DB_IRISSYS:READ` and enters `%SYS` by save and restore (AD-16).
- The page is a class name, URL-encoded with `$ZConvert(p,"O","URL")` before every vendor call, and stored and shown as `%IsPortalPage` normalizes it (AD-44). No caller value reaches SQL, and no endpoint takes a path (AD-21).
- The port refuses an unknown page, an empty or unknown resource, and a clear of a page with none, before any vendor write. The vendor checks none of these (Task 0).
- Every write takes AD-34's hold, fingerprints the fresh read (AD-51), reads back (AD-58), and emits one `page-resource` change event (AD-14). The agent's write carries its marker (AD-15).
- The declaring screens of a page are derived from the registry on every call: each built descriptor's `classicPage` and `CLASSICPAGES`, and each write tool's `CLASSICPAGES`. Never a literal list, and nothing cached (AD-64 rule 2).
- Use the ruled strings verbatim (Design Notes). New refusal codes are `ACCESS.PAGE.*` in `Api/AccessError.cls`.
- Shared and contended files take add-only edits, as ruled under Design Notes.

**Never:**

- No edit to `Api/Error.cls` (frozen), and no new AD or AD amendment.
- No user-facing string beyond the ruled set. A new one is escalated, never decided.
- No custom resource set on any page of `ocupilot`, a slot instance, `ocupilot-b-ci` or `iris-community-edition`. Tests that write the store run on `ocupilot-ci` only, armed, and restore every page they touch.
- No OcuPilot-owned audit event for these writes (see Design Notes, Audit).
- No change to `Screen.Gate.RequiredPairs`' behavior. Only its doc comment changes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Assign | A portal page class and a defined resource; no screen declares the page | Row stored under the normalized class; list shows it; read-back matches | No error expected |
| Change on a declared page | Page an adjustable screen declares, holding R1; assign R2 | Agent: minted destructive, `PAGERESOURCE.CHANGED`. Person: the consequence line at the field | No error expected |
| Clear on a declared page | Same page, holding R1 | Agent: destructive, `PAGERESOURCE.CLEARED`; the row is gone; the screen's gate drops R1 | No error expected |
| Assign on a Home page | `%CSP.Portal.Home` | 403 `PROHIBITED.OCUPILOTSCREEN`, existing sentence; no vendor write | Both callers, at the mint and at Save |
| Unknown page | Not a portal class, or bad shape | 422 `ACCESS.PAGE.UNKNOWN` on `Page` | Before any vendor write |
| Empty resource on assign | `Resource` "" | 422 `ACCESS.PAGE.RESOURCEREQUIRED` on `Resource` | Before any vendor write |
| Unknown resource | Not in `Security.Resources` | 422 `ACCESS.RESOURCE.UNKNOWN` on `Resource` (reused) | Before any vendor write |
| Clear with none | Page holds no custom resource | 409 `ACCESS.PAGE.NOTASSIGNED` (a precondition code) | No vendor write |
| Stale confirm | Stored R1 changed before the confirm | Refused as target-changed; nothing written | AD-51 fingerprint |
| No pair | Caller lacks `%Admin_Secure:USE` or `%DB_IRISSYS:READ` | 403 `AUTH.NOPRIVILEGE` naming the first lacking pair | Before any vendor call |

</intent-contract>

## Code Map

- `src/OcuPilot/Port/ResourceTransferPort.cls:26-49,97-137,439-465,682-734` -- the sibling to model on: `PAIRS` (the same two pairs), request-type parameters, `Invoke` (gate, refuse a body, branch, 501), `%SYS` save and restore, `GateRefusal`, `Violation`, `Snippet`/`SnippetForm`.
- `src/OcuPilot/Port/ScreenAccessPort.cls:239-480` -- `Prohibit` (403 with the Prohibited sentence), `Violate` (422 on one field), `Conflict`, and `ResourceDefined` (`$System.Security.ResourceExists`), the seam to reuse.
- `src/OcuPilot/Screen/Tool/ScreenAccessAction.cls`, `ScreenAccessAddPair.cls`, `ScreenAccessReset.cls` -- the tool shapes: `SCREENVALUES` and `PortQuery` for a valued bodyless write; `WRITETYPE="DELETE"` with `ReadBackGone`; `PreconditionCodes`; `DRYRUN`. Tools are found by package scan (`Screen/Tool/Registry.cls:37`).
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- `OCUPILOTSCREEN` :962/:967; `TYPESCREENPERMISSION` :697; `COVEREDTYPES` :311; the type check :1706 and the dispatch :1719-1724; the `ScreenPermission` arm :3110-3120; `EFFECTSCREENLOWERED` :1091; `LowersScreenPermission` :2473-2493; `WeakensByEffect` :2525-2533. The mint calls it from `Kernel/Proposal/Mint.cls:354` (the consequence at :360).
- `src/OcuPilot/Screen/Gate.cls:22-25` (doc comment: "The write path is guarded and is not something OcuPilot ever takes" becomes false), `Adjustable` :265 (the one home of the not-adjustable predicate), `RequiredPairs` :238-259, `ClassicResource` :580-584.
- `src/OcuPilot/Screen/Registry.cls:88` `Descriptors`, :4099 `DescriptorForTool`, :1223 the allowed read ports, :1418 a per-port block (`phone`). `Descriptor/Base.cls:399` `ClassicPage()`.
- `src/OcuPilot/Screen/Read.cls:338-345,533,821-824` -- a read source kind (`SOURCE*`, `*PortClass`, the allowed list, the dispatch).
- `src/OcuPilot/Screen/Area.cls:85` -- the Permissions area (rail 5, `%Admin_Secure:USE`, `%DB_IRISSYS:READ`). Side-bar positions 1-4 are Users, Roles, Resources and Services.
- `src/OcuPilot/Kernel/EntityType.cls:156` `TYPES`, with a doc paragraph like :93. Ids are kept exactly, so there is no `EntityRef.IDRULES` entry.
- `src/OcuPilot/Api/AccessError.cls` -- the `ACCESS.*` family, already dispatched by `Api/Error.cls:1254,1479`; `ACCESS.RESOURCE.UNKNOWN` :30-32.
- `src/OcuPilot/Kernel/Governance/Baseline.cls:76-80` -- `permissions.resources.*`; the new keys sort after them.
- `src/OcuPilot/Api/ScreenDryRun.cls` -- `POST /screens/:screen/dryrun`, the person's review before Save. The dialog's line and consequence come from it.
- Client: `ui/src/app/shell/screen-outlet.ts:104` (`DESCRIPTOR_PAGES`); `ui/src/app/areas/agent/screen-permissions.page.ts` and `screen-permissions-dialog.ts` (page and dialog shape); `ui/src/app/core/navigation.ts:106,1225-1233` (re-read on `screen-permission`); `ui/src/app/core/proposal-view.ts:213,543` (consequence codes); `ui/src/app/core/strings.ts:7514-7577`; `ui/tools/client-lint.mjs:703-710`.
- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` -- inventory :123 (Resources list), side bars :157-168, Fixed strings :359-360 and :604.
- `ui/browser/screen-permissions.browser-spec.mjs:70-149` -- principal setup through `irisSession`, the live and slot refusal, `signIn`, `waitForRows`, `waitForMapAnswered`.
- Store writers in tests: `src/OcuPilot/Test/ClassicPageGate.cls:602-628` (assign and restore).

## Tasks & Acceptance

**Task 0** (implement stage, `ocupilot-ci` only, inside Batch 2: once its port and tools load, before its tests are written; recorded under Design Notes). Each item stays (inference) until measured:

- (a) As a principal holding only `%Admin_Secure:USE` and `%DB_IRISSYS:READ` (plus read on the code databases), through the real `POST /screens/pageresources/action` route once Batch 2's port exists: an assign and a clear succeed, and the route answers the read-back. Stop rule: if the vendor refuses that principal in a REST process, HALT `intent gap` naming AD-44's pair.
- (b) An agent assign naming the resource the page already holds is refused by the mint's existing no-change path (`Mint.cls:272-274`). Stop rule: if no existing refusal applies, escalate the wording. Do not add a string.

### Batch 1: the read (server, list and side-bar entry; commit when its loop is green)

- `src/OcuPilot/Port/PortalResourcePort.cls` -- new, on `ResourceTransferPort`'s shape. `PAIRS = "%Admin_Secure:USE,%DB_IRISSYS:READ"`, `ENDPOINT = "PortalResource"`.
  - `LIST` runs `%SYS.Portal.Resources:List` in `%SYS`, capped as the declared read requires. Each row is `{Page, Resource, Screen}`, where `Screen` is the declaring built screens' titles joined by ", " (empty if none).
  - `GET` (one page) normalizes the caller's class name. An unresolved page answers `ACCESS.PAGE.UNKNOWN` (422 on `Page`). A page with none answers `Resource` "".
- `src/OcuPilot/Screen/Registry.cls` -- add `portalresource` to the allowed read ports, with its block. Add one helper, `ScreensDeclaringPage(pPage) As %List`, that returns the built descriptors declaring the page (descriptor `ClassicPage()` and `CLASSICPAGES`, and each write tool's `CLASSICPAGES` through `DescriptorForTool`), read on every call.
- `src/OcuPilot/Screen/Read.cls` -- the `portalresource` source kind (parameter, port class, allowed list, dispatch).
- `src/OcuPilot/Screen/Descriptor/PageResourceList.cls` -- new. Area `permissions`, route `permissions/pageresources`, `sideBarPosition` 5, archetype `list`, `entityType` `page-resource`, `classicPage` `%CSP.Portal.ResourceDialog`, privileges `%Admin_Secure:USE,%DB_IRISSYS:READ`. Its read is `{"port":"portalresource","endpoint":"PortalResource","type":"LIST"}`. It carries the columns, empty state, note and prompts in the ruled strings.
- `src/OcuPilot/Kernel/EntityType.cls` -- add `page-resource` with its doc paragraph.
- `src/OcuPilot/Screen/Gate.cls` -- replace the doc sentence at :24-25 with: the write path is `PortalResourcePort`'s, under the caller's own pairs (AD-44). There is no code change.
- `ui/tools/screen-mirror.mjs`, `ui/tools/screen-mirror.test.mjs` -- `SOURCE_PORTALRESOURCE`, `READ_SOURCE_PORTS`, `readProblem`. Then regenerate `Screen/Titles.cls` and `ui/src/app/core/screens.generated.ts` with `cd ui && node tools/screen-mirror.mjs`.
- `ui/src/app/core/strings.ts`, `EXPERIENCE.md` -- add-only: the Batch 1 ruled strings, the inventory row after Resources list, and the Permissions side-bar entry.
- Tests: `src/OcuPilot/Test/PageResourceRead.cls` (new, armed `OCUPILOT_ALLOW_PRINCIPALS`). It plants a row on a probe page and asserts that row by its marker, never on emptiness, and that a declared page's `Screen` names its screens. Restore in `OnAfterOneTest`.
- Roster updates: `SurfaceCoverage` (screen row), `PortGate` (`ROSTER` `|OcuPilot.Port.PortalResourcePort=PAIRS`), `Descriptor` (a `ReadShapes` row; the entity-type count 111 becomes 112), `ReadTool` (+1 and the sorted name), `WireSecurityRead` (the three Permissions arrays :880, :1031, :1060 and their messages), `ui/tools/navigation.test.mjs` (`'permissions/pageresources'` after `'permissions/services'`), and `scripts/ci-throwaway.sh` (`OCUPILOT_ALLOW_PRINCIPALS` classes, held equal by `ci.test.mjs`).

### Batch 2: the writes (server; commit when its loop is green)

- `src/OcuPilot/Port/PortalResourcePort.cls` -- add the two write branches.
  - `SET` (page, `Resource` query value) refuses empty with `ACCESS.PAGE.RESOURCEREQUIRED` and undefined with `ACCESS.RESOURCE.UNKNOWN`, then calls `%CSP.Portal.Utils.%SetCustomResource(<encoded page>, <resource>)`.
  - `CLEAR` refuses a page with none with `ACCESS.PAGE.NOTASSIGNED`, then makes the same call with "".
  - `Snippet` mirrors both write branches as an ObjectScript step with the encoded page and the resource. `SnippetForm` answers `"objectscript"`.
- `src/OcuPilot/Api/AccessError.cls` -- add `ACCESS.PAGE.UNKNOWN`, `ACCESS.PAGE.RESOURCEREQUIRED` and `ACCESS.PAGE.NOTASSIGNED` with the ruled sentences. Add them to `Codes()`, and add `PagePreconditionCodes()` holding `NOTASSIGNED`.
- `src/OcuPilot/Screen/Tool/PageResourceAction.cls` (new, abstract), `PageResourceAssign.cls` and `PageResourceClear.cls` (new) -- `permissions.pageresources.assign` (valued, `SCREENVALUES` `Resource`, `PortQuery`, `DRYRUN`) and `permissions.pageresources.clear` (`WRITETYPE="DELETE"`, `ReadBackGone` on `Resource`). Each fingerprints the fresh `GET`.
  - `DryRunReview` answers the declaring screens and the consequence code, so the dialog shows the card's line.
  - Card summaries use the ruled strings: "Change …" when the fresh read holds a resource, "Assign …" otherwise.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls` -- add-only: `TYPEPAGERESOURCE`, `page-resource` in `COVEREDTYPES` and the type check, a dispatch line, and a `PageResource` arm beside `ScreenPermission`.
  - The arm refuses an assign whose page a non-`Adjustable` screen declares with `OCUPILOTSCREEN`.
  - Add `EFFECTPAGERESOURCECHANGED = "PAGERESOURCE.CHANGED"` and `EFFECTPAGERESOURCECLEARED = "PAGERESOURCE.CLEARED"`, selected in `WeakensByEffect` when the declaring list is non-empty and the stored resource is non-empty.
- `src/OcuPilot/Screen/Descriptor/PageResourceList.cls` -- the primary action `assign`, the row actions `change` (the assign tool) and `clear`, and the tools.
- `src/OcuPilot/Kernel/Governance/Baseline.cls` -- add-only: both keys, `true`.
- Tests:
  - `Test/PageResourceWrite.cls` (new, armed). Covers AC1, AC2, AC6, AC7, AC10 on both callers against a real least principal. The probe page is the first entry of a candidate list that `%IsPortalPage` resolves and `ScreensDeclaringPage` leaves empty.
  - `Test/PageResourceProhibited.cls` (new, not armed: an in-process seam, as `ScreenAccessGateSeam` does). Covers AC3, AC4, AC5.
- Roster updates: `Test/Prohibited.cls` (`CoveredTypes` "ninety-nine" +1; the `$Case` at :447/:461 if the assign's value counts as a settable argument), `SurfaceCoverage` (two tool rows), `ReadTool` (+2), `ToolWrite` (:1326, 148 becomes 150), `DraftRegistry` (`TYPEDTARGETIDS` `page-resource=%CSP.Portal.ResourceDialog` if the synthetic id does not render), `ui/tools/access.test.mjs` (the three sentences, both directions), `strings.ts`, `EXPERIENCE.md` (the refusal rows, add-only), `scripts/ci-throwaway.sh` (`PageResourceWrite`). `RefusalCopy` and `self-protection.test.mjs` need no change, because no new `PROHIBITED.*` code is added.

### Batch 3: the client (commit when its loop is green)

- `ui/src/app/areas/permissions/page-resources.page.ts`, `page-resources-dialog.ts` (+ `.spec.ts` each) -- new, on Screen permissions' page and dialog.
  - The dialog has the fields Page and Resource, with the ruled help. Change opens it with Page read-only.
  - Before Save it asks `dryrun` and shows the replaces line or the no-screen line, and the consequence where the review names one. Save stays disabled while the resource is unchanged.
  - Clear opens a confirm whose title is the ruled clear summary, carrying the ruled warning and the consequence. Its button is "Clear resource".
  - The empty state, which carries the ruled agent prompt, is pinned in the component spec, not in the browser.
- `ui/src/app/shell/screen-outlet.ts` -- register `PageResourceList` in `DESCRIPTOR_PAGES` (add-only).
- `ui/src/app/core/navigation.ts` -- also reload on a `page-resource` change event, as on `screen-permission`.
- `ui/src/app/core/proposal-view.ts`, `ui/tools/proposal-view.test.mjs` -- add-only: the two consequence codes, mapped to the ruled consequence sentences with `<screen>` from the diff's `Screen` value.
- `ui/src/app/core/strings.ts`, `EXPERIENCE.md`, `ui/tools/client-lint.mjs` (element classes, if pinned) -- add-only.
- `ui/browser/page-resources.browser-spec.mjs` -- new. It refuses live and slot containers. Add it to `side-bar-pins.test.mjs`'s `SIDE_BAR_SPECS` if it pins the side bar.

**Acceptance Criteria** (carried from Story 21.21's AC6 to AC17, renumbered; the adjustments are listed under Design Notes):

- AC1 (assign): Given a caller with `%Admin_Secure:USE` and `%DB_IRISSYS:READ`, a page `%IsPortalPage` resolves that no OcuPilot screen declares, and a resource `Security.Resources` defines, when the person assigns it through the dialog and when the agent's confirmed proposal assigns it, then `%SYS.Portal.Resources` holds the row under the normalized class name (`%CSP.Portal.ResourceDialog.cls` is stored as `%CSP.Portal.ResourceDialog`), the list shows it, and the read-back matches. The agent's write carries its marker (AD-15); the vendor records no event for either caller (Task 0).
- AC2 (clear): Given a page with a custom resource, when the person clears it and when the agent's confirmed clear proposal runs, then the row is gone and the list no longer shows it. A clear of a page with none is refused 409 `ACCESS.PAGE.NOTASSIGNED` with its sentence and no vendor write.
- AC3 (own screens): Given a page that a Home or Agent co-pilot screen declares (`%CSP.Portal.Home`), when an assign is judged on either caller (the agent's at its mint, the person's at its Save), then it is refused 403 `PROHIBITED.OCUPILOTSCREEN` with the sentence already in `Prohibited.cls`, no port write is made, and no row is written. The declared pages are derived from the registry's descriptors, never from a literal list.
- AC4 (lowering): Given a page an OcuPilot screen declares that holds a custom resource, when the agent proposes a clear, or a change that AC3 does not refuse, then the proposal is minted destructive with no typed name and carries the consequence line (`PAGERESOURCE.CLEARED` or `.CHANGED`), and the person's dialog shows the same line at the field. An assign to a page with none, and a clear or change on a page no screen declares, are not minted destructive.
- AC5 (bad input): Given a page `%IsPortalPage` does not resolve, a resource `Security.Resources` does not define, or an assign with an empty resource, when either caller sends it, then it is refused 422 on its own field before any vendor write, with the ruled sentence.
- AC6 (stale): Given a proposal minted while a page held R1, when R1 is changed by someone else before the confirm, then the confirm refuses as stale and writes nothing (AD-51's fingerprint of the fresh read; AD-34's hold).
- AC7 (the gate honors it, the integration AC): Given a custom resource assigned through `PortalResourcePort` to a page a built screen declares, when `Screen.Gate.RequiredPairs` is read on the next call, then it includes that resource at USE, and a caller lacking it is refused that screen by name. After the clear, that caller is admitted again. The reader caches nothing (AD-64 rule 2).
- AC8 (AD-59): Given each of the two tools, when its copy-out draft is rendered, then it shows the `%CSP.Portal.Utils.%SetCustomResource` call with the stored page and resource (an empty resource for the clear) and runs no write, and `DraftRegistry` names no tool without a script form.
- AC9 (governance): Given the keys `permissions.pageresources.assign` and `permissions.pageresources.clear`, when `GovernanceBaseline` runs, then `Baseline.cls` carries both, shipping `true` (AD-22), and the class is green.
- AC10 (port gate): Given a caller without `%Admin_Secure:USE`, or without `%DB_IRISSYS:READ`, when it calls any endpoint of `PortalResourcePort`, then it is refused `AUTH.NOPRIVILEGE` naming the first pair it lacks, before any vendor call (AD-29), and the screen's own gate refuses it the screen.
- AC11 (rosters): Given the new screen, tools, entity type and port, when `SurfaceCoverage`, `EndpointCoverage`, `PortGate`, `Descriptor`, `ScreenGrounding`, `ClassicPageGate`, `ReadTool`, `ToolWrite`, `Navigation`, `WireSecurityRead`, `PermissionsLists` and `navigation.test.mjs` run, then each passes and names them where it names its peers, with each count derived from the registry outside a roster's own pin (Rule 30).
- AC12 (browser, the outermost surface): Given the deployed bundle, when `page-resources.browser-spec.mjs` signs in as an `%Admin_Secure` holder and assigns a resource to a probe-safe page, sees its row, changes it, clears it, and tries a page a Home screen declares, then each step shows the screen's own answer, and the refusal shows the existing sentence.
- AC13 (audit, AD-15 named case 2026-11-21): Given a page custom-resource assign or clear from either caller (the person's dialog and the agent's confirmed proposal), when it writes, then OcuPilot records its own `OcuPilot/Security/SecurityChange` event with the page and the resource before and after, beside the agent's marker for an agent write; a clear of a page with no resource is refused (`ACCESS.PAGE.NOTASSIGNED`) and records no event. The event triple is the one the installer already registers (no second registration).
- AC14 (the replaces line, plural): Given a page that one OcuPilot screen replaces, the dialog shows the ruled singular line; given several, it shows "These <count> screens follow this page's resource and will require it from the next request: <titles>." with at most five titles joined by ", " in the order screens already sort, ending ", and <n> more" past five. A component test pins 1, 5 and 6 or more screens.

## Spec Change Log

- 2026-11-21, orchestrator rulings at the spec gate (authoritative):
  - The plural replaces line is accepted with a cap (AC14): "These <count> screens follow this page's resource and will require it from the next request: <titles>." — at most five titles joined by ", " in the order screens already sort, then ", and <n> more"; one screen keeps the ruled singular line. "and <n> more" is a `strings.ts` string in the same veto item.
  - AD-15, option (b), done here: the spine carries the add-only named case (`2fd24558e`); a page custom-resource assign or clear records OcuPilot's own `OcuPilot/Security/SecurityChange` from either caller (AC13). Confirm the installer already registers the event triple; register no second one.
  - AC4 reads AD-10 as written: a clear or change is destructive on any page an OcuPilot screen declares, Home's included.
  - The rest is approved as planned: the `AccessError` codes, the port's two checks, the pairs, three batches, add-only on the contended files.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-44 (Story 21.21's record: the port, the call, `%Admin_Secure:USE`), AD-64 rule 2 (cleared by AD-44's tools; one reader, no cache), AD-10 (the `OCUPILOTSCREEN` arm for own screens' classic pages; destructive clear or change), AD-22 (both keys `true`), AD-29 (port gate), AD-51 (action-style writes, fingerprint), AD-53 (one operation, two callers), AD-59 (script form). Also AD-5, AD-8, AD-13, AD-14, AD-15, AD-16, AD-21, AD-34, AD-36, AD-52, AD-58. No new AD and no AD amendment is needed.

**Ledger inbox:** none routed to `21-37-page-resources` (`LEDGER slice` empty). Declined: none.

**Task 0, measured on `ocupilot-ci` (2026-11-21, plan stage; the probe users, roles and resource were removed and read back absent, and the store reads 0 rows):**

- `%IsPortalPage` resolves `%CSP.Portal.ResourceDialog(.cls)`, `%CSP.Portal.Home`, `%CSP.UI.Portal.Users(.zen)`, `/csp/sys/sec/%25CSP.UI.Portal.Users.zen` and `EnsPortal.ProductionConfig` to the class name. It refuses `OcuPilot.Api.Dispatch`, `%Library.String` and `Nope.Nada`.
- An unencoded `%DeepSee.UI.Architect` does not resolve (`%De` decodes as a byte), and `%25DeepSee.UI.Architect` does. So the port URL-encodes, as `Gate.ClassicResource` already does.
- `%SetCustomResource` on a page that is not a portal page answers `#5983 Page not found`. It stores an undefined resource without complaint (`NoSuchResXYZ` was stored), and a clear of a page with none answers OK. So the port checks all three itself.
- Principals, logged in a child process from `HSCUSTOM`:
  - With `%Admin_Secure:USE` and `%DB_IRISSYS:READ`: the switch to `%SYS`, `Security.Resources.Exists`, set, get, `List` and clear all succeed. No `%DB_IRISSYS:WRITE` is needed.
  - Without `%DB_IRISSYS:READ`: the switch raises `<PROTECT>`, and `Security.Resources` is unreachable.
  - Without `%Admin_Secure:USE`: the vendor refuses `#822 Access Denied` and audits `AccessDenied`, and `Security.Resources.Exists` answers 0 for a defined resource.
- With auditing on, a set and a clear left no audit row (re-read after 75 s). The same session's user, role and resource deletes were recorded.

**Task 0, Batch 2 (2026-11-21, `ocupilot-ci`, after the port and tools loaded; the probe accounts were removed and the probe page read back with no resource):**

- (a) Measured, passes. A principal holding exactly `%Admin_Secure:USE`, `%DB_IRISSYS:READ` and READ on the code database, through `POST /screens/permissions.pageresources/action`: a change on `%CSP.UI.Portal.About` answered 200 with read-back `matches`, and a clear answered 200 with `notFound`. `%GetCustomResource` read the resource after the first and none after the second.
- (b) Measured: no existing refusal applies. An agent assign naming the resource the page already holds minted a proposal with `changed: []`, because the tool sends no body and `Mint.cls:272-274` runs only for one that does. Per the stop rule the wording is escalated and no string was added. The port stores and records nothing for such an assign.

**Decided in-stage (Batch 2):**

- The port serves `PUT` (assign) and `DELETE` (clear) and lists both in `AdminPort.MUTATINGTYPES`, `PortFixture` and its own `COMPOSEDTYPES`, since it extends the admin port. For that reason `ToolWrite`'s count stays 148.
- The write tools declare `PrivilegePairs` as `Gate.RequiredPairs` of the screen. Without it they required nothing (the AC10 leg found it).
- The route carries row actions only, so the tool serves `change` and the client registers the primary `assign`; Batch 3's Assign dialog sends `change` with the typed page.
- The one-page read answers `{Page, Resource, Screen, Current}`. The fingerprint covers `Page`, `Resource` (the value the write names) and `Current` (the value stored now).
- AC13: the port records `SecurityChange` (entity `page-resource`, verbs `updated` and `deleted`, `changes.resource.old` and `.new`) after each accepted write, so both callers share one record. The installer registers the triple from `Kernel.Audit.Event.Roster` and screen-access writes record it through `Kernel.State.Access.Audit`, so nothing is registered here.
- Card summaries are `TargetName` templates in `PageResourceAction`; Batch 3 adds the client strings.
- The vendor normalizes a `.cls` spelling itself, so the port's own normalization is pinned over `PageResourceStoreSeam` in `PageResourceProhibited`.
- AC10: both short accounts are refused `AUTH.NOPRIVILEGE` naming the pair. The no-`%Admin_Secure` account holds `%Admin_Operate:USE`, since an account with no administrative resource is refused earlier.
- `ScreenGate` is a seam class, not a test, so it has no run.

**Adjustments to the carried ACs:**

- AC1 and AC10 name `%DB_IRISSYS:READ` beside `%Admin_Secure:USE`. The port's `%SYS` entry needs it (measured), as `ResourceTransferPort` declares.
- AC1's audit clause now states what is measured: the agent's marker, and no vendor event.
- AC2 and AC5 say "no vendor write", and AC3 "no port write", because `%IsPortalPage` is itself a vendor read and the arm judges after the fresh read (AD-53).
- AC4 follows AD-10's wording, "a page an OcuPilot screen declares", rather than the draft's "in an area that declares pairs". `RequiredPairs` unions every declaring screen's page, Home's included. On a Home page only a clear can reach the mint.
- AC11 adds `ReadTool`, `ToolWrite`, `Navigation`, `WireSecurityRead` and `PermissionsLists`. `GovernanceBaseline` and `DraftRegistry` are AC9's and AC8's.

**Decided in-stage:**

- The codes go in `Api/AccessError.cls` under `ACCESS.PAGE.*`. `Api/Error.cls` already dispatches `ACCESS.` in `ReasonForToolCode` and `ReasonForViolation`, so the frozen file is untouched. The unknown resource reuses `ACCESS.RESOURCE.UNKNOWN` and its sentence.
- A page is named by class only. A value outside `^%?[A-Za-z][A-Za-z0-9.]*$`, or longer than 256 characters, is `ACCESS.PAGE.UNKNOWN`.
- The declaring-screens map is one `Registry` helper, used by the read's `Screen` column, the Prohibited arm, the destructive effect and the dry-run review (Rule 31: one home). The not-adjustable test reuses `Gate.Adjustable`.
- When several screens declare a page, the `Screen` cell and `<screen>` carry their titles joined by ", " (SQL query declares 22 screens' page).
- The dialog's buttons reuse the ruled action labels. Clear's confirm title is the ruled clear summary.
- An assign of the resource a page already holds changes nothing: Save stays disabled, and the agent's mint is refused by the existing no-change path (Task 0 (b)).
- The shell re-reads the navigation map on a `page-resource` change event, as AD-64 rule 5 does for `screen-permission`, because a page's resource moves the map's verdicts. Every gate holds at the call regardless.
- Tests that write the store are armed on `OCUPILOT_ALLOW_PRINCIPALS` (as `ClassicPageGate` is) and restore each page. Assertions are on their own rows by marker; the empty state is pinned in jsdom.
- The epic context is reused as the runner instructed, though planning artifacts are newer. The tree was clean at the start, and this stage wrote only this spec (probe scripts stay in its scratch folder).

**Audit (for the runner's attention, no amendment made):** the vendor records no event for this call (measured), so the agent's marker is the write's only record, which AD-15's named case "a write the vendor does not audit" already covers. A person's write leaves no record, as the classic dialog's identical call does, so the posture equals the classic portal's. Recording OcuPilot's own `SecurityChange` from either caller, as AD-64's screen-access writes do, would be stricter, but it needs an AD-15 named case, which this story may not write. If the runner keeps AD-15's list of unaudited writes complete, this write is its next entry (Rule 20).

**Ruled strings (veto U-128), used verbatim:**

- Title and side-bar entry: "Page resources". Columns: "Page", "Resource", "Screen" (the shared header). Empty state: "No classic pages have a custom resource on this instance.", with the agent prompt "assign a resource to a classic page".
- Note: "A page's custom resource decides who may open it in the classic portal and in OcuPilot. The instance still checks every read and write."
- Prompts: "Which classic pages have a custom resource?", "Which resource does the Users page require?", "Which OcuPilot screens follow a page's custom resource?"
- Actions: "Assign resource" (primary), "Change resource", "Clear resource" (row). Dialogs: "Assign a resource to a page", "Change the resource of <page>". Fields: "Page", "Resource". Help: "Name a classic page by its class.", "Name a resource this instance defines."
- Lines: "<screen> follows this page's resource and will require it from the next request." and "No OcuPilot screen replaces this page, so only the classic portal uses this resource."
- Consequences: "Accounts that hold only the old resource can no longer open <screen>." (change) and "More accounts may open <screen>. The instance still checks what they do there." (clear). Clear warning: "After this, the page needs no custom resource."
- Card summaries: "Assign <resource> to <page>", "Change the resource of <page> to <resource>", "Clear the resource of <page>".
- Refusals: "No classic portal page has that name." (`ACCESS.PAGE.UNKNOWN`), "Name the resource to assign. To remove one, clear it instead." (`ACCESS.PAGE.RESOURCEREQUIRED`), "This page has no custom resource, so there is nothing to clear." (`ACCESS.PAGE.NOTASSIGNED`). Reused unchanged: "This instance defines no resource of that name." and the `PROHIBITED.OCUPILOTSCREEN` sentence.

**Strings, escalated** (nothing is used until ruled):

- A plural form of the replaces line for a page several screens declare: "<screens> follow this page's resource and will require it from the next request." Until it is ruled, the singular line is shown with the joined titles.

**Contended paths (Epic 24, slot B; `git log origin/OCU-1-epic24 ^origin/feature/OCU-1_ocupilot-mvp`, 2026-11-21; the epic-24 worktree is clean):** Epic 24 changed `Prohibited.cls`, `Baseline.cls`, `strings.ts`, `screens.generated.ts`, `proposal-view.ts`, `EXPERIENCE.md`, and the tests `ToolWrite`, `SurfaceCoverage`, `ReadTool`, `DraftRegistry` and `ClassicPageGate`. Ruled here, all allowed as add-only:

- New members, rows, keys and strings.
- Appending `page-resource` to `COVEREDTYPES` and the type check.
- A dispatch line.
- The roster count bumps (`ReadTool`, `ToolWrite`, `Prohibited` test). Each is a plain roster union at merge (Rule 22).
- A regenerated `screens.generated.ts`, which is generated output.

`ClassicPageGate` needs no change, because neither tool declares `CLASSICPAGES`. None of the other files shows an Epic 24 commit.

**Integration ACs and linkage (Rules 1-2):** `PortalResourcePort` is consumed in this story by the Page resources screen and both tools. `Screen.Gate.RequiredPairs` consumes what it writes (AC7, against a real principal on `ocupilot-ci`). **Consumed-by:** none planned. **Consumes:** `Screen.Gate` (`Adjustable`, `RequiredPairs`, `ClassicResource`), `Screen.Registry`, `Screen.Titles`, `Kernel.Proposal` (mint, confirm, `Prohibited`), `Api.AccessError`, `Api.ScreenDryRun`.

**Extends (Rule 2/31):**

- The port copies `ResourceTransferPort`'s structure rather than subclassing it. The two vendor surfaces are unrelated, and that file is 21.19's. It reuses `ScreenAccessPort`'s refusal helpers' shapes.
- The tools extend `Screen.Tool.Write` through a new abstract `PageResourceAction` on `ScreenAccessAction`'s model. A shared base with `ScreenAccessAction` would couple two ports.
- The page and dialog copy Screen permissions' layout, since neither has a reusable component.

**Size.** Batch 1 is about 19 files (two regenerated), Batch 2 about 18 and Batch 3 about 12. Each is verifiable and committable alone, so the plan keeps one story.

## Verification

**Shared surfaces** (each changed test joins `(loop)`; the implement stage greps `ui/browser`, `ui/tools`, the `ui/src` specs and `src/OcuPilot/Test` for the old shape):

- The Permissions side bar: `WireSecurityRead`, `navigation.test.mjs`, `Navigation`, `PermissionsLists`.
- Entity types: the `Descriptor` count.
- Tool and read rosters: `SurfaceCoverage`, `ReadTool`, `ToolWrite`, `GovernanceBaseline`, `DraftRegistry`.
- `PortGate`'s `ROSTER`; `Prohibited`'s `COVEREDTYPES`.
- Read sources: `screen-mirror.test.mjs`. `ACCESS.*` codes: `access.test.mjs`.
- `strings.ts` and EXPERIENCE.md: `strings.test.mjs`. The arming roster: `ci.test.mjs`. Consequence codes: `proposal-view.test.mjs`.
- The classic page store itself: `ClassicPageGate`, `ScreenAccessGate`, `ScreenGate`. Each restores what it assigns.

Every test added or changed passes on a fresh environment, in either order.

**Commands** (`ocupilot-ci` only, one per foreground call, `timeout: 600000`, never two test calls in one message):

- `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/b708a79b-b765-42ec-adea-dbc87acf6251/scratchpad/e21u/lead/reload.sh /Users/jbrandt/git/OcuPilot/.worktrees/epic-21 ocupilot-ci` (loop) -- expected: `LOADERRORS=0`.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<Class>` (loop), one call each:
  - The batch's new classes: `PageResourceRead`, `PageResourceWrite`, `PageResourceProhibited`.
  - Then the rosters it touched: `SurfaceCoverage`, `PortGate`, `Descriptor`, `ReadTool`, `ToolWrite`, `Navigation`, `WireSecurityRead`, `PermissionsLists`, `GovernanceBaseline`, `DraftRegistry`, `Prohibited`, `RefusalCopy`, `ScreenGrounding`, `EndpointCoverage`, `ClassicPageGate`, `ScreenAccessGate`, `ScreenGate`.
  - Expected: green.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/` (loop, Batches 1 and 3) -- expected: build clean within 2500/4000 kB.
- `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/<file>.browser-spec.mjs` (loop), one call per file: `page-resources`, `screen-permissions` -- expected: green.
- `cd ui && npm run test:tools` and `cd ui && npm run test:components` (loop) -- expected: green.
- `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh` (loop) -- expected: clean.
- The full ObjectScript sweep over `src/OcuPilot/Test` (once, before `dev_complete`), one class per call or in batches sized from `ui/tools/ci-timings.json` to about 8 minutes -- expected: green. The full browser suite is left to CI (Rule 29).

**Mutation plans** (Rule 19; each `mutation:` line is written when it is run):

- AC1: `SET` stores the page un-normalized -> `PageResourceWrite`'s stored-key assertion red.
- AC2: `CLEAR` calls `SET` with the old resource -> the clear test red.
- AC3: the arm skips the non-`Adjustable` check -> `PageResourceProhibited` red on both callers.
- AC4: `WeakensByEffect` never selects the page effects -> the destructive-mint test red.
- AC5: drop the `%IsPortalPage` check -> the unknown-page test red; drop the resource check -> the unknown-resource test red.
- AC6: the tool fingerprints nothing -> the stale-confirm test red.
- AC7: `Gate.ClassicResource` reads a process-cached copy -> the gate-after-clear test red.
- AC8: remove `Snippet`'s clear branch -> `DraftRegistry` red, naming the tool.
- AC9: remove one key from `Baseline.cls` -> `GovernanceBaseline` red.
- AC10: drop `%DB_IRISSYS:READ` from `PAIRS` -> `PortGate` and the gate test red.
- AC11: delete the `SurfaceCoverage` screen row -> `SurfaceCoverage` red alone.
- AC12: remove the `clear` row action from the descriptor -> the browser spec red, against a rebuilt and redeployed bundle.
- AC13: skip the `SecurityChange` record on the person's path, then on the agent's path -> the audit test red each time; record an event on the refused clear -> red.
- AC14: drop the ", and <n> more" tail (list all titles) -> the 6-or-more component case red.

Mutations run, Batch 1 (`ocupilot-ci`; each reverted with Edit, md5 equal, source reloaded):

- mutation: Batch 1, `PortalResourcePort.PAIRS` loses `%DB_IRISSYS:READ` -> `PageResourceRead` red (the pair-count and the gate leg, and the declared-pairs assertion); `PortGate` stays green, since its roster checks only that the named parameter parses.
- mutation: Batch 1, `Listed` reads `Resource` from the page -> `PageResourceRead` red (3 tests); `ScreenTitles` stops after the first title -> the several-screens test red; `ScreensDeclaringPage` ignores a write tool's `CLASSICPAGES` -> 3 tests red; `Normalized` returns the caller's name -> 2 tests red; `Normalized` skips the shape check -> the unknown-page test red; `Rows` admits a cap of 0 -> the cap test red; `Read` asks the port for the cap, not the cap plus one -> the truncation test red; the descriptor's `sideBarPosition` 6 -> the declaration test red.
- mutation: Batch 1, remove the `SurfaceCoverage` screen row -> `SurfaceCoverage` red alone (260 rows against 261 screens).
- mutation: Batch 1, drop `SOURCE_PORTALRESOURCE` from `READ_SOURCE_PORTS` -> `screen-mirror.test.mjs` red; one word of `REASONPAGEUNKNOWN` changed -> `access.test.mjs` red.

Mutations run, Batch 2 (`ocupilot-ci`; each reverted with Edit, md5 equal, source reloaded):

- mutation: Batch 2, AC1, `AssignResource` stores the page as the caller spelled it -> `PageResourceProhibited` red (the accepted-write leg). `PageResourceWrite` stays green, since the vendor normalizes `.cls` itself.
- mutation: Batch 2, AC2, `ClearResource` stores the old resource -> `PageResourceWrite` red (3 tests: the person's, the agent's and the gate's).
- mutation: Batch 2, AC3, `RefusesPageAssignment` skips the `Adjustable` check -> `PageResourceProhibited` red on the prohibited set, the person's gate, the agent's mint and the registry sweep.
- mutation: Batch 2, AC4, `WeakensByEffect` never takes the page effect -> the destructive-mint test red.
- mutation: Batch 2, AC5, `AssignResource` drops its unknown-page check -> the unknown-page legs red; `ResourceProblem` drops its defined check -> the unknown-resource and mint legs red.
- mutation: Batch 2, AC6, the tool's fingerprint subject loses `Current` -> `PageResourceWrite`'s stale-assign leg red.
- mutation: Batch 2, AC7, `Gate.ClassicResource` reads a process-cached copy -> `PageResourceWrite`'s gate test red.
- mutation: Batch 2, AC8, `SnippetForm` answers no form for the clear -> `DraftRegistry` red, naming `permissions.pageresources.clear`.
- mutation: Batch 2, AC9, the clear key removed from `Baseline.cls` -> `GovernanceBaseline` red.
- mutation: Batch 2, AC10, `PageResourceAction.PrivilegePairs` answers none -> `PageResourceWrite`'s short-pair test red on both accounts. (`PortalResourcePort.PAIRS` is pinned by Batch 1's line.)
- mutation: Batch 2, AC11, the assign tool's `SurfaceCoverage` row removed -> `SurfaceCoverage` red alone.
- mutation: Batch 2, AC13, the audit call skipped on the assign branch -> `PageResourceWrite`'s person and agent tests red; skipped on the clear branch -> both red; an event recorded for a refused clear -> `PageResourceProhibited` red.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Plan pass (2026-11-21, HEAD `6893a453dc5ad01210aa82f9c31b72963def5d14`): Task 0's vendor items measured on `ocupilot-ci`, every probe object removed; AC1-AC12 carried from 21.21's AC6-AC17 with the adjustments listed under Design Notes; one string escalated (the plural replaces line).
