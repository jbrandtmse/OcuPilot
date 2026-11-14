---
title: 'Story 20.26: Business partners saved and removed'
type: 'feature'
created: '2026-11-12'
status: 'done'
baseline_revision: '54d90dd107400a1a9ebdf204e22bf7644ca4d1fb'
baseline_commit: '54d90dd107400a1a9ebdf204e22bf7644ca4d1fb'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md'
warnings: [oversized]
deferred: []
---

<intent-contract>

## Intent

**Problem:** Business partners are read-only in OcuPilot (Story 20.5's stated partial, DW-2324). Adding, changing or removing one still needs the classic `EnsPortal.BusinessPartners` page. That page declares no edit resource, renames by `%DeleteId` then `%Save` with no transaction and without renaming references ("This will not rename references to this item."), removes with no check of the items that name the partner, and audits nothing (read in source, `EnsPortal/BusinessPartners.cls` :275-375).

**Approach:** Extend `Port/InteropPort` (AD-62) with a port-composed `PARTNER` read and three writes on the `BusinessPartners` endpoint: `ADDPARTNER` (a create, AD-54), `SETPARTNER` (a merge, AD-4) and `REMOVEPARTNER` (action-style, AD-51). Each is one tool reached by two callers (AD-53, AD-55): the Business partners screen (New business partner, Edit, Remove) and the agent's confirmed proposal. Each records OcuPilot's own `ConfigChange` (AD-15). A rename is refused, and a remove of a partner a production item names is refused (Design Notes › Decisions).

## Boundaries & Constraints

**Always:**

- Every write goes through `InteropPort.Invoke` behind the port's gate (AD-29, AD-62 (2)): the endpoint's pairs, then `%Ens_ProductionConfig:WRITE` (the posture recommendation, Design Notes), then WRITE on the namespace's globals database. No routines database. A refusal names its pair. The tools declare the same pairs, each refused by name before any port call (AD-8).
- The partner is identified by its name, kept exactly (AD-13, entity `business-partner`, scope `namespace`).
- Under the caller's per-target hold (AD-34), the write re-reads and re-judges before any vendor call (AD-62 (5)).
- Before any vendor call, the port refuses by its own code:
  - a namespace under source control, `INTEROP.PARTNER.SOURCECONTROL`, for every write;
  - an add of a name the namespace holds, `INTEROP.PARTNER.TAKEN`;
  - a remove of a partner that any item of any production of the namespace names in its Host setting `BusinessPartner`, `INTEROP.PARTNER.NAMED`;
  - a field past the vendor's `MAXLEN`, or a name that is empty or holds a control character, as 422 violations (`INTEROP.PARTNER.NAME`, `INTEROP.PARTNER.LENGTH`).
- A rename cannot be expressed. The update's settable fields are the thirteen non-name fields, its target is the name, and the Edit dialog shows the name read-only. A call carrying any other argument is refused by the tool schema (`TOOL.ARGUMENTS`) or by the screen-action route (AD-56), before any port call.
- Vendor calls: add `%New`, the fields, `%Save`. Update `%OpenId(name, 4)`, the thirteen fields, `%Save`, the reference dropped right after. Remove `%DeleteId(name)`. Only vendor classes run while switched (AD-16).
- Audit is OcuPilot's own `ConfigChange` through `AuditRuntime`: verbs `add`, `set` and `remove`, entity `business-partner`, the name as id. Effects carry the namespace, and for a set the changed field names. An agent write also carries the AD-15 marker.
- Keys (AD-22): `interop.businesspartners.add` `true`, `.update` `true`, `.remove` `false`. Only the remove is destructive (its record and both contacts cannot be restored from OcuPilot).
- FR-80 holds: one descriptor and one port per screen, and no new declared read. Edits to shared rosters are add-only.

**Never:**

- Never call `EnsPortal.BusinessPartners`' methods, `%Api.InteropEditors.*`, `Ens.Config.BusinessPartner.%Import`, or write `^Ens.Config.BusinessPartnerD` or `^Ens.Configuration` directly.
- No rename (neither the vendor's two-step nor a transaction), no import or export, no credential or system-default-setting check on remove (named limits), no change to the partner list's read fields, and no name link.
- No edit to `Screen/Tool/Write.cls`, `Api/Error.cls`, `Screen/Registry.cls`, `.github/workflows/ci.yml`, `ui/tools/ci-*.mjs` or `ui/tools/ci-timings.json`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Add | A free name, any of the thirteen fields | The partner is stored and listed. Read-back `match`. One `ConfigChange` `add` | — |
| Update | A held name, some fields changed (a field may be cleared) | Those fields change and the rest are kept. Read-back `match` | No field changed: the kernel's "nothing would change" refusal |
| Remove | A held name no item names | The partner is gone and the read-back reads absent | — |
| Named | A remove of a partner that an item's Host `BusinessPartner` setting names, in any production of the namespace, running or not | — | 409 `INTEROP.PARTNER.NAMED`, nothing removed |
| Taken | An add of a held name | — | 409 `INTEROP.PARTNER.TAKEN` (Task 0 (b) settles letter case) |
| Rename | An update carrying a new name under any key, or a screen value the tool does not declare | — | 400 `TOOL.ARGUMENTS`, or the screen-action route's undeclared-value refusal; nothing written |
| Fields | An empty name, a control character, or a field past its `MAXLEN` (name and contact name, title and email 255; description 5,000; phone and mobile 50; notes 1,000) | — | 422 `INTEROP.PARTNER.NAME` or `INTEROP.PARTNER.LENGTH`, naming the field |
| Changed since review | The partner changed or was removed after the mint | — | The confirm closes target-changed, as its siblings do |
| Source control | A namespace under source control | — | 409 `INTEROP.PARTNER.SOURCECONTROL` |
| Unknown | An update or a remove of a name the namespace does not hold | — | 404 `PORT.NOTFOUND`, unlogged |
| Gates | A caller missing one declared pair | Refused before any vendor call | 403 naming the pair |
| Namespace | A namespace that does not report interoperability | — | 409 `INTEROP.NAMESPACE` |

</intent-contract>

## Code Map

### Vendor (read only)

- `irislib/Ens/Config/BusinessPartner.cls`: IdKey `PartnerName` :20, properties and `MAXLEN` :24-33, `List` query :35-38, `%OnAfterDelete` :184 and `%OnAfterSave` :191 stamp `Ens.SourceControl.DataDocument` (the `.SDD` projection, :15).
- `irislib/Ens/Config/BusinessPartnerContact.cls` :12-27: six fields and their `MAXLEN`.
- `irislib/EnsPortal/BusinessPartners.cls`: `RESOURCE` :13, no `EDITRESOURCE` (so `canEdit` is 1, `Template/standardPage.cls` :40, `EnsPortal/Utils.cls` `CheckResourceList` :1443), `DeleteID` :275, `save` :286 and `SaveItem` :318-375, `GetBPs` source-control read-only :441.
- Items name a partner in their Host setting: `Ens/Host.cls` :28/:34, read as `tItem.FindSettingByName("BusinessPartner","Host")` (`Ens/Config/Production.cls` :408). `Ens.Config.Item.Settings` is an embedded list (`Item.cls` :77).

### Port and errors

- `src/OcuPilot/Port/InteropPort.cls` (7,655 lines):
  - `ENDPOINTBUSINESSPARTNERS` :153. Types :287-450. Do not reuse `ADD`, `REMOVE` or `SET`: `IsItemWrite` :780 and `IsSettingWrite` :787 match those, and `Pairs` and `Admit` would then add item pairs and routines WRITE.
  - Classifiers `IsAnyWrite` :821 and `IsLookupWrite` :5211, `Pairs` :851 (the partners line :853), `Serves` :901, `Invoke` :1000 (partner `LIST` :1052), `Admit` :1097, `SourceControlled` :1420.
  - Lookup write template to extend: `InvokeLookup` :5318, `ReadLookupEntry` :5593, `LookupWriteToken` :5293, `LookupViolations` :5268, `PerformLookup` :5630.
  - `ListPartners` :6110: the fourteen field names and the contact mapping. The new `PARTNER` read reuses its row builder.
  - `AuditRuntime` :5020, `SnippetForm` :5032, `Snippet` :5057, `LookupSnippet` :6167.
  - Mappers: `Statused` :2624, `Mapped` :2651, `Conflict` :2694, `Absent` :2707, `Refuse` :2685.
  - Concurrency-4 open precedent: `PerformItem` :1809.
- `src/OcuPilot/Api/InteropError.cls` (178 parameters, far under #5290): lookup codes :270, `Codes` :466, `ConsequenceCodes` :472, `LookupCodes` :519, `PreconditionCodes` :583, `ReasonFor` :590.

### Tools, route and kernel

- `Screen/Tool/InteropLookupEntryAction.cls`, the abstract sibling, and `InteropLookupEntryAdd.cls`, `InteropLookupEntrySet.cls` (`SCREENVALUES`, `SCREENEMPTY`, `ScreenActionDelta`, `StateDiff` empty), `InteropLookupEntryRemove.cls` (`REMOVALROWS`, `StateDiff`), and the parent `InteropAction.cls` (`WRITERESOURCE` :41, `Consequence` :79, `PrivilegePairs` :89, `PortQuery` :131).
- `Area/Interop/ItemSave.cls`: `HandleCreate` :84 and `Create` :133 require a parent; `LookupEntrySave.cls` is the 59-line subclass to copy the shape of.
- `Api/Router.cls`: `/interop/lookup-entries` :273 and its `Call=` target :1926.
- `Screen/Descriptor/InteropBusinessPartnerList.cls`: no actions, `emptyNextKey`.
- `Kernel/Governance/Baseline.cls` `interop.*` :220-248. `Kernel/Proposal/Prohibited.cls`: `COVEREDTYPES` :282, settable-field lists :1202/:1363, the fail-closed list :1444, the create branch :1574, `ReviewedFewOnly` :1784-1790. `business-partner` is not covered yet.

### Client

- `ui/src/app/shell/screen-outlet.ts` :231 (lazy page map). `ui/src/app/shell/screen-action-handler.ts`: `SCREEN_ACTION_DESCRIPTORS` :137, page-registered actions :452-454, `DESTRUCTIVE_CONSEQUENCES` :562/:617-618, `TYPED_NAME_ROWS` :700.
- `ui/src/app/core/screen-actions.ts` `DESCRIPTOR_ACTION_LABELS` (the lookup rows :175-184). `ui/src/app/core/proposal-view.ts` `consequenceSentence`. `ui/src/app/core/strings.ts` partner keys :6976-7014.
- Siblings: `areas/interoperability/interop-lookup-entry-list.page.ts` (page over `ListPage` with page-registered dialogs), `interop-lookup-entry-dialog.ts` (one dialog for two modes, field violations), `interop-lookup-entry.store.ts` and `interop-create.ts` (`postInteropCreate`).
- EXPERIENCE.md :173 is the Dialogs line, and :604 is the Fixed-strings row (the Story 20.5 clause holds the retired line). Clauses are appended; no line is inserted above :604.

### Tests and rosters

- `Test/InteropLookupFixture.cls`: `PutPartner` :171 and the partner cleanup :159. Extend it rather than copy it.
- `Test/InteropLookupControl.cls`: the HTTP confirm, screen-action and Save precedent, armed by `OCUPILOT_ALLOW_PRINCIPALS`. `Test/InteropLookupGate.cls`: the principal generator. `Test/ProductionProbe.cls` `AddItem` :203 takes a setting name, value and target.
- Old-shape assertions to update (Rule 30):
  - `InteropLookupDescriptor` :58 (partners offer no action).
  - `InteropLookupEdges` :176-179 (an action sent to the partners screen is refused).
  - `ui/browser/interop-lookup-tables.browser-spec.mjs` AC6 :424-441 (no trigger, no primary). Move it into the new spec.
- `scripts/ci-throwaway.sh` :511 `# classes:` line. `ui/tools/interop.test.mjs` `SENTENCES`.
- Rosters this story moves:

| File | Anchor | What |
|---|---|---|
| `Test/ReadTool.cls` | :93-94 | registry count +3 and the sorted names |
| `Test/ToolWrite.cls` | :1326 | other-port writes +3 (DW-2407's count) |
| `Test/ToolRoundTrip.cls` | :100 | `REFUSEEMPTY` rows for the three tools |
| `Test/SurfaceCoverage.cls` | :437-439 | three coverage rows |
| `Test/ToolEmit.cls` | the interop branches | partner pairs: `%Ens_ProductionConfig:WRITE` plus globals, no routines |
| `Test/EndpointCoverage.cls` | :287 | a probe row for `POST /interop/business-partners` |
| `Test/GovernanceBaseline.cls` | — | baseline order, one disabled key added |
| `Test/InteropFloor.cls` | :70-73 | unchanged unless its rosters derive write tools (the operator holds only `:R`) |

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0, measure on `ocupilot-b-ci`** (USER, auditing on, probe partners `OcuProbe226*` removed after). Record each result under Design Notes › Measured.
  - (a) `%Save` and `%DeleteId` of a partner write no audit row (AD-15 named case).
  - (b) Letter case: whether `OCUPROBE226CASE` beside `OcuProbe226Case` is a second partner, is refused by `%Save`, or reads present through `%ExistsId`. If it is a second partner, the add refuses a case variant with `INTEROP.PARTNER.NAMECASE`, the conditional string below, as `TABLECASE` does for lookups.
  - (c) What `%Save` answers for a name holding `||`, one of 256 characters, and a field one past its `MAXLEN`. Nothing is stored in each case. If `||` is stored but cannot be opened, the name rule refuses it.
  - (d) A principal holding `%Ens_Portal:U`, `%Ens_ProductionConfig:R` and `%DB_USER:RW` adds and removes through the vendor directly. So the port's gate is the whole gate, and the classic page's posture is READ (confirming the inference).
  - (e) The scan finds the probe partner named by an item of a probe production that is not running.
  - (f) On the branch head: `ToolWrite`'s other-port count and `ReadTool`'s registry count. This story's pins are exactly three above what the branch holds (56 → 59 and 409 → 412 once 20.25 has landed; inference until then). Also note whether Epic 23's `Write.RemovalRows` has landed.
  - A result that changes a destructiveness call, a key default, the audit choice or the pairs is `## Clarification Needed`. Anything else is adjusted within this intent and recorded.
- [ ] `src/OcuPilot/Port/InteropPort.cls`:
  - Add `TYPEPARTNER` `PARTNER`, `TYPEADDPARTNER`, `TYPESETPARTNER` and `TYPEREMOVEPARTNER`, `IsPartnerWrite`, and `PARTNERWRITEPAIR` `%Ens_ProductionConfig:WRITE`, joined in `Pairs`. Add them to `Serves`' BusinessPartners line and to `IsAnyWrite`.
  - `Invoke` routes every non-`LIST` partner type to a new `InvokePartner`, beside `InvokeLookup`.
  - `PARTNER` answers `ListPartners`' fourteen fields plus `NamedBy` (the count) and `Namespace`. With `ACTIONKEY` it refuses as the write would: SOURCECONTROL for any write, TAKEN or the create's 404 for an add, NAMED for a remove.
  - `PartnerNamedByHere` (switched, vendor classes only) counts the items of every production of the namespace whose Host `BusinessPartner` setting equals the name exactly.
  - `PartnerViolations` (pure) mirrors the vendor's `MAXLEN`s and the name rule. `PartnerWriteToken` (pure) answers `TAKEN`, `ABSENT`, `NAMED` or `""`.
  - `PerformPartner` follows `PerformLookup`'s sequence without the table lock: source control, violations, a switched re-read and judge, the vendor call of Boundaries, restore, `AuditRuntime`, then a `PARTNER` read back (after a remove, `{Name, Namespace}`). Vendor errors map through `Statused` and `Mapped`, a lock not got on the update's open as `PerformItem` maps it.
  - Add a `PartnerSnippet` branch to `SnippetForm` and `Snippet` (AD-59), and refresh the header doc and item 10's sentence in it.
- [ ] `src/OcuPilot/Api/InteropError.cls`: add `PARTNERTAKEN`, `PARTNERNAMED`, `PARTNERSOURCECONTROL`, `PARTNERNAME`, `PARTNERLENGTH` (and `PARTNERNAMECASE` only if Task 0 (b) needs it), and consequence `INTEROP.PARTNER.REMOVE`. Put each in a new `PartnerCodes`, and in `Codes`, `ConsequenceCodes`, `PreconditionCodes` (the three 409s) and `ReasonFor`.
- [ ] `src/OcuPilot/Screen/Tool/InteropPartnerAction.cls` (new, abstract, extends `InteropAction`, after `InteropLookupEntryAction`):
  - `DESCRIPTORCLASS` `InteropBusinessPartnerList`, `READTYPE` `PARTNER`, `READANSWERS` as above, and `STATEMARKER` `NamedBy`.
  - `WRITERESOURCE` `%Ens_ProductionConfig` at `WRITE`, and `ROUTINESDATABASE` 0, as the parent sets.
  - `Endpoint`, `TargetName` and `IdArgument` `Name`. The fields' schema descriptions are agent-facing and decided at implement.
- [ ] `src/OcuPilot/Screen/Tool/InteropPartnerAdd.cls`, `InteropPartnerUpdate.cls`, `InteropPartnerRemove.cls` (new):
  - Add: `interop.businesspartners.add`, `CREATES`, `SENDSBODY`, `FIELDS` Name plus the thirteen, `ComposeCreate` adding `Namespace`, `PortQuery` always asking the add, `READBACKTOOL` the update, `PRECONDITIONCODES`, and `ArgumentProblem` over `PartnerViolations`. It extends `InteropLookupEntryAdd`'s pattern.
  - Update: `interop.businesspartners.update`, `SCREENACTIONS` `edit`, `SCREENVALUES` and `SCREENEMPTY` `edit=` the thirteen fields colon-separated, `SENDSBODY`, `READBACKFIELDS` the thirteen, `StateDiff` empty, `ScreenActionDelta`, and `ArgumentProblem`. `NamedBy` and `Namespace` stay out of its fingerprint and read-back, as `InteropLookupEntrySet` keeps `Secret` out. Its `DESCRIPTION` states that the name cannot be changed, and how to rename.
  - Remove: `interop.businesspartners.remove`, `SCREENACTIONS` `remove`, `DESTRUCTIVE`, `CONSEQUENCECODE` `INTEROP.PARTNER.REMOVE`, `FINGERPRINTSUBJECT` the fourteen fields plus `NamedBy`, `REMOVALROWS` `Name,Description,PrimaryContact,AlternativeContact`, and `StateDiff` through `Write.RemovalRows` if Task 0 (f) finds it landed, else `InteropLookupEntryRemove`'s shape.
- [ ] `src/OcuPilot/Area/Interop/ItemSave.cls`: an empty `PRODUCTIONMEMBER` makes the Save namespace-scoped. `HandleCreate` and `Create` then skip the parent member, the parent violation and `ParentHeld`, and `IdOf` answers the name alone. The behavior for a non-empty member is unchanged. Update the doc's subclass sentence.
- [ ] `src/OcuPilot/Area/Interop/PartnerSave.cls` (new, extends `ItemSave`): `CREATETOOL` the add, `DESCRIPTORCLASS`, empty `PRODUCTIONMEMBER`, `NAMEMEMBER` `Name`, `NAMEEMPTYCODE` `INTEROP.PARTNER.NAME`, `TAKENCODE` and `TAKENREASON` from `InteropError`, and `Violations` over `PartnerViolations`.
- [ ] `src/OcuPilot/Api/Router.cls`: `POST /interop/business-partners` → `InteropPartnerCreate` → `PartnerSave.HandleCreate`, beside :273.
- [ ] `src/OcuPilot/Screen/Descriptor/InteropBusinessPartnerList.cls`:
  - `primaryAction` `add`, `rowActions` `edit` then `remove`;
  - `emptyNextKey` `""` and `emptyAgentKey` `interopBusinessPartnersEmptyAgent`;
  - the doc's read-only paragraph replaced. The read stays as it is.
- [ ] `src/OcuPilot/Kernel/Governance/Baseline.cls`: append the three keys (add `true`, update `true`, remove `false`), keeping the last-line comma rule.
- [ ] `src/OcuPilot/Kernel/Proposal/Prohibited.cls`: `business-partner` joins `COVEREDTYPES`, the fail-closed list and both settable-field lists (create: Name plus the thirteen; update: the thirteen). Add a `ReviewedFewOnly` branch beside `lookup-entry`'s: AD-10 names no effect on a partner, which is informational data.
- [ ] Client (new): `ui/src/app/areas/interoperability/interop-business-partner-list.page.ts`, `interop-business-partner-dialog.ts`, `interop-business-partner.store.ts`, each with its `.spec.ts`. Register the page in `shell/screen-outlet.ts`.
  - The page extends the entry list page's pattern. It registers `edit` on the handler, and the handler's construction registers `remove`.
  - One dialog serves New business partner and Edit, as the entry dialog serves two modes. In Edit the name is read-only and the rename note shows. Fields come in three groups: name and description, the primary contact's six, the alternative contact's six.
  - The create posts through `postInteropCreate` to `/interop/business-partners`. Edit sends the thirteen values through `sendFor`, empty values allowed. Violations are drawn on their fields, any other refusal above them.
  - Only existing `ocu-*` template classes are used, or each new one gets a style (client-lint family 7).
- [ ] `ui/src/app/shell/screen-action-handler.ts`, `ui/src/app/core/screen-actions.ts`, `ui/src/app/core/proposal-view.ts`, `ui/src/app/core/strings.ts`:
  - the partner list joins `SCREEN_ACTION_DESCRIPTORS` and the page-registered map (`edit`);
  - `DESTRUCTIVE_CONSEQUENCES` gets `remove`, and `DESCRIPTOR_ACTION_LABELS` gets `add`, `edit` and `remove`;
  - the consequence sentence is added, and the new strings are appended;
  - the retired `interopBusinessPartnersEmptyNext` is removed if the runner rules so.
  - Then run `node tools/screen-mirror.mjs` to regenerate `screens.generated.ts`.
- [ ] `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`: append the ruled strings as a clause to :604's row, and the dialog to :173's Dialogs line. Then run `npm run test:tools`.
- [ ] `src/OcuPilot/Test/InteropLookupFixture.cls`: `PutPartner` takes a name and fields (it already does the name). Add `DropPartners(pPrefix)`.
- [ ] `src/OcuPilot/Test/InteropPartnerControl.cls` (new, armed): a person's Save, Edit and Remove, and the agent's three tools minted and confirmed over HTTP. Each answers its read-back and change-event triple and writes one `ConfigChange`. The Integration AC. A change out of band after the mint closes the confirm.
- [ ] `src/OcuPilot/Test/InteropPartnerRefusals.cls` (new, armed): every Matrix refusal through both callers. The NAMED leg uses a `ProductionProbe` item whose Host `BusinessPartner` names the probe partner, in a probe production that is not running. Source control goes through `InteropItemSeam`'s `SourceControlled` override. The rename leg sends a `NewName` argument and a screen value `Name`.
- [ ] `src/OcuPilot/Test/InteropPartnerGate.cls` (new, armed): reuses `InteropLookupGate`'s principal generator. Each declared pair's 403 comes before any vendor call, and a holder of only `%Ens_ProductionConfig:READ` is refused every write.
- [ ] The old-shape assertions and rosters in the Code Map, then a sweep of `src/OcuPilot/Test`, `ui/browser`, `ui/tools` and the `ui/src` specs for the partner list's old shape. `scripts/ci-throwaway.sh` gets the three new classes on a `# classes:` line.
- [ ] `ui/browser/interop-business-partners.browser-spec.mjs` (new): on the deployed bundle, New business partner creates a probe partner, Edit changes its phone, and Remove (typed name) removes it, each asserted on the list. A remove of a named probe partner shows `NAMED`'s sentence. It includes the moved AC6 list leg and removes every probe in `after`. `ui/tools/interop.test.mjs` gets the new sentences.

**Acceptance Criteria:**

- AC1: Given a business partner, when a create, an update or a remove is proposed by the agent and confirmed, or made on the Business partners screen, then each runs through `InteropPort` on `Ens.Config.BusinessPartner` as a confirmed write over a fresh `PARTNER` read (the create over its absence), records one `ConfigChange` of OcuPilot's own, and answers a read-back verdict of `match` (absent for a remove).
- AC2 (rename): Given an update that names a new name, when it is proposed by the agent or sent from the screen, then it is refused before any port call and the partner is unchanged. The Edit dialog shows the name read-only with the rename note.
- AC3 (named): Given a partner named by an item's Host `BusinessPartner` setting in any production of the namespace, when its remove is proposed, minted or confirmed, then the port reads those items first and refuses it `INTEROP.PARTNER.NAMED`, and the partner remains.
- AC4 (Integration): given a confirmed create, then an update, then a remove, when Story 20.5's Business partners read runs (its screen read route and `interop.businesspartners.read`) against `ocupilot-b-ci`, then it lists the new partner with its fields, then the changed values, then no longer lists it.
- AC5: Given a caller missing one declared pair, `%Ens_ProductionConfig:WRITE` among them, when it acts by either caller, then it is refused 403 naming that pair before any vendor call.
- AC6: Given the three tools, when the rosters run, then the destructiveness, key defaults and audit records are as Boundaries states, Task 0's measurements are recorded, and `ToolWrite`'s other-port count reads exactly three above the branch's pre-story value.

### Review Findings

Code review 2026-11-14 (four layers, full-opus): 6 patched, 3 ledgered, 15 rejected.

- [x] [Review][Patch] `InteropPartnerControl.RowIn` answered the last row when the probe was not listed (a `For` counter ends on the last index), so AC4's "unlisted" leg went red whenever `USER` held another partner [src/OcuPilot/Test/InteropPartnerControl.cls:451] — found flag; red on the old helper with a second partner in `USER`, green on the fix.
- [x] [Review][Patch] `PartnerFits` had no test: a name of 255 characters the instance cannot address [src/OcuPilot/Test/InteropPartnerRefusals.cls:139] — mint, port add (422) and port remove (404) legs added; mutation recorded under Verification.
- [x] [Review][Patch] `InteropPartnerGate`'s doc claimed the exact principal's writes were checked against stored state [src/OcuPilot/Test/InteropPartnerGate.cls:153] — sentence narrowed to what it asserts.
- [x] [Review][Patch] `InteropPartnerRefusals`' AC3 doc said the confirm answers `NAMED`; it closes target-changed, as the remove's `FINGERPRINTSUBJECT` (`NamedBy`) and the Matrix's "Changed since review" row specify [src/OcuPilot/Test/InteropPartnerRefusals.cls:213] — doc corrected; the code is as specified.
- [x] [Review][Patch] `InteropError.PartnerCodes`' doc counted seven codes for six [src/OcuPilot/Api/InteropError.cls:632].
- [x] [Review][Patch] The Edit title used a string replacement, so a name holding `$&` rendered mangled [ui/src/app/areas/interoperability/interop-business-partner-dialog.ts:195] — function replacer, as `database-wizard.page.ts` does.
- [x] [Review][Defer] Edit sends all thirteen values from the non-refreshing list row, reverting a field changed elsewhere since the list loaded [ui/src/app/areas/interoperability/interop-business-partner-list.page.ts:143] — deferred: DW-2554, decision-pending (the task text says the dialog sends every field).
- [x] [Review][Defer] AD-62 (10), AD-15 and AD-22 still describe partners as read-only with READ pairs — deferred: DW-2555, decision-pending, the owner's attended spine Update.
- [x] [Review][Defer] The partner field-validation loop is repeated in three callers — deferred: DW-2556, wontfix-accepted.

Rejected:

- `false`: `InteropError.PreconditionCodes` lacks the partner codes. It feeds the production tools (`InteropPort.PreconditionCodes`, `InteropProductionAction`); each partner tool declares its own `PRECONDITIONCODES`, as the lookup tools do.
- `low`: `PartnerNamedByHere` ignores a failed `Next` or an unopenable production, and the letter-case scan ignores a failed `List` query. Both are unlikely, and the fix adds guards that would block every remove behind one broken production.
- `low`: a partner deleted between the facts read and the update's open answers 503, not 404. The window is the request, under the per-target hold.
- `low`: a remove whose `%DeleteId` meets a held lock, or an add racing an out-of-band add, maps through `Statused`. Rare, and each needs a new branch.
- `low`: the 404's "unlogged" is not asserted. `Absent` is a shared mapper this story did not change.
- `low`: `ToolEmit`'s partner branch derives its expected pair from the tool. `InteropPartnerGate` pins the literal pair, and the lookup branch has the same shape.
- `low`: the Matrix's Update row says a no-change edit is refused, while the screen's is accepted. The fix edits the spec; "Decided at implement" records it.
- `low`: AC5's agent leg evaluates the tools' pairs rather than minting as each principal. That is `InteropLookupGate`'s pattern, and the mint runs the same pair gate.
- `low`: `PartnerSnippet`'s scripts omit the port's checks. They render the vendor calls the port makes (AD-59), like `LookupSnippet`.
- `low`: the thirteen-field list is a literal in each tool's parameters. Class parameters are literals, as in the sibling tools; the Prohibited lists are pinned against `PARTNERSETFIELDS`.
- `low`: the description's fieldset has no legend. Its one field is labeled, and the structural walk passed.
- `low`: a whitespace-only or padded name is admitted. The spec's name rule names empty names and control characters only.
- `low`: an `installing` answer to the Edit leaves the dialog without a sentence. Seven sibling pages read `lastRefusal` the same way.
- `low` (Rule 2 check): the page, dialog and store share about a third of their lines with the lookup entry trio, mostly the project's store shape. The spec names that sibling.
- `low`: the Save's `TAKENREASON` is a literal beside `InteropError.REASONPARTNERTAKEN`, as `LookupEntrySave`'s is.

## Spec Change Log

- 2026-11-12, spec gate (runner and orchestrator): the posture question is ruled (A), `%Ens_ProductionConfig:WRITE` and globals WRITE for add, update and remove (veto, orchestrator); the new strings are kept as proposed (veto U-23); nothing is written into the spine.

## Review Triage Log

### 2026-11-13 — Review pass

- verdicts: 15 findings — high 0, medium 3, low 8, false 4, maybe-false 0
- findings:
  - `[medium]` `[patch]` The partner Save route had no held-key leg in `SaveHoldCoverage` — added the leg; mutating `ItemSave.IdOf`'s name-only key reddens it.
  - `[medium]` `[patch]` `PartnerSnippet` and the partner `SnippetForm` had no test — added `InteropPartnerControl.TestEveryPartnerWriteRendersItsScript`; an unquoted description reddens it.
  - `[medium]` `[patch]` The update's lock-not-got 503 path was unpinned — added `InteropPartnerRefusals.TestAnEditOfAPartnerWhoseLockIsHeldIsRefusedUnavailable`; skipping `tBusy` reddens it.
  - `[low]` `[patch]` Field limits were tested only one past the limit — added `TestAValueAtItsLimitIsSavedWhole`; lowering the description limit reddens it.
  - `[low]` `[patch]` The reviewed field lists were pinned by count only — added a membership assertion against `PARTNERSETFIELDS`; a misspelled field reddens it.
  - `[low]` `[patch]` AC2 and AC5 mutations covered one leg each — recorded two more: a rename key in the update schema reddens the agent leg, and `WRITEPERMISSION` `READ` reddens the tool-pair and screen-route gate legs. The planned AC2 row named a mutation that cannot redden anything (`Name` is already the target), and is replaced.
  - `[low]` `[patch]` `InteropError.PartnerPreconditionCodes` had no caller or test — pinned by the new codes assertion, which also holds each tool's `PRECONDITIONCODES` inside it.
  - `[low]` `[reject]` `PartnerNamedByHere` skips a production that does not open — the listing is the compiled productions, so an unopenable one is not expected (inference); throwing would block removes on a malformed class and the fix adds a branch.
  - `[low]` `[patch]` `InteropPartnerControl` left its probe production on a raise between create and remove — `OnAfterOneTest` now removes it.
  - `[low]` `[reject]` `ListedRow` answers empty on a read error, so the closing "unlisted" check could pass — the earlier listed-row assertions in the same test fail first on a read error.
  - `[false]` `[reject]` Intent audit: `INTEROP.PARTNER.NAMECASE` goes beyond `TAKEN` — Task 0 (b) measured a case variant as a second partner and the spec makes the refusal conditional on that result.
  - `[false]` `[reject]` Intent audit: `PartnerFits` extends the name rule to names the instance cannot address — Task 0 (c) says a stored-but-unopenable name is refused by the name rule.
  - `[low]` `[reject]` Intent audit: a screen Edit that changes nothing is accepted and calls nothing — the dialog sends all thirteen values, nothing is written or audited, and the agent's mint refuses it; recorded in the spec by the implement pass.
  - `[false]` `[reject]` Intent audit: existing tests, EXPERIENCE.md and the moved AC6 leg changed — each is a listed task.
  - `[false]` `[reject]` Intent audit: the tests drive the callers over HTTP and the source-control leg drives the port in process — AC1 and AC4 name both callers, and no throwaway can be put under source control.

## Design Notes

**Governing ADs:** AD-4, AD-6, AD-8, AD-10, AD-13, AD-14, AD-15, AD-16, AD-22, AD-29, AD-34, AD-39, AD-44, AD-51, AD-52, AD-53, AD-54, AD-55, AD-56, AD-58, AD-59, AD-62. Also AD-11 and AD-60: a partner's text is untrusted, and it reaches the model through the existing read and its sanitizer. Checked with nothing to add:

- AD-21 and AD-27: there is no path and no `%Api.*` call.
- AD-36: no declared read changes.
- AD-44: no `CLASSICPAGES`, because the page's `RESOURCE` is the screen's own pair.
- AD-35: partner fields are not credentials.

**Measured or read at this plan** (read-only; the throwaway was not used):

- On `ocupilot-slot-b` (HSCUSTOM), `PartnerName` declares no SQL collation, and the namespace holds no partner, item or production.
- From the source:
  - the classic page saves and removes for any READ holder (`canEdit` is 1 with no `EDITRESOURCE`) unless source control marks the document read-only;
  - it renames as delete then create, and warns that references keep the old name;
  - it removes with no check;
  - the class says partners have "no effect on the running of the system".

**Measured at implement** (on `ocupilot-b-ci`, as `irisowner` unless noted):

- (a) `%Save` and `%DeleteId` of a partner write no audit row: the `%SYS.Audit` count read 206,685 before and after one of each.
- (b) `OCUPROBE226CASE` beside `OcuProbe226Case` is a second partner: both saved, `%ExistsId` is exact (`ocuprobe226case` reads absent), and the vendor's `List` query lists both. So the add refuses a case variant with `INTEROP.PARTNER.NAMECASE`, as the plan allowed.
- (c) A name holding `||` is stored, exists and opens, so the name rule does not refuse it. A 256-character name, a description of 5,001, notes of 1,001, a phone of 51 and a contact name of 256 are each refused #7201 with nothing stored; an empty name is #5659.
- (d) A principal holding `%Development:U`, `%Ens_Portal:U`, `%Ens_ProductionConfig:R` and `%DB_USER:RW` adds and deletes a partner through the vendor directly (both answered OK), so the port's gate is the whole gate. That the classic page admits a READ holder to its saves is read from source (`EnsPortal.BusinessPartners` declares no `EDITRESOURCE`) and stays an inference.
- (e) The scan finds the probe partner named by an item of a probe production that is not running (`NamedBy` reads 1 with no production current): `InteropPartnerRefusals`' named leg.
- (f) On the branch head `ToolWrite`'s other-port count read 58 and `ReadTool`'s production registry 412; they now read 61 and 415 (the registry lists 239 writes and 176 reads). The 56 and 409 the plan expected were stale, since Stories 20.40 and 20.41 had landed. `Write.RemovalRows` has landed, so the remove's `StateDiff` uses it.

**Decisions:**

- **Rename: refused.** The vendor renames without updating references, so every item, credential and alert naming the old partner would point at nothing. Doing it in one transaction would also mean rewriting each item's setting in each production class: an item write with `SaveToClass`, routines WRITE and source control, far past this story. Refusing it is the simplest option consistent with AD-62. The person renames in three confirmed steps (add, re-point the items, remove), and the rename note and the update's description say so.
- **Remove of a named partner: refused, not warned.** A warning on the screen path would need a dynamic warning before a typed-name dialog, or a new list field (a changed declared read and the `ReadDescriptions` roster), so that the person sees which partners are named. A refusal is one code that both callers meet at the port. It keeps references whole, which is the safe behavior, and its sentence says how to proceed. It is a precondition refusal like `INTEROP.ITEM.TEMPSTOPPED`, not a ban: once the items' setting is cleared, the remove runs.
- **Named limits:** a credential (`Ens.Config.Credentials.BusinessPartner`), a system default setting or a managed alert naming the partner is not checked (inference: rare; the AC names items). An item changed to name the partner between the check and the delete is not caught; the window is the request.
- **Source control:** every partner write is refused in a namespace under source control, as every lookup and item write is. This is stricter than the classic page, which refuses only when the document reads read-only. Decided in-stage, because it is a consistency rule and not an access posture.

**Decided at implement:**

- **The update's fingerprint leaves `NamedBy` out** by overriding `MergeUpdate` to drop it from the merged payload, because a merge write may not declare `FINGERPRINTSUBJECT` (`Registry.FingerprintSubjectProblem`). Its `STATEMARKER` is therefore `Namespace`, which the payload carries and a call's arguments do not. `InteropPartnerControl.TestTheAgentsUpdateConfirmsOverHttp` pins it: an item that names the partner after the mint does not close the update.
- **An Edit that changes nothing** from the screen is accepted and calls the vendor nothing and records no row; the agent's mint of the same update is refused by the kernel. `PartnerViolations` judges the name for an add only, since a partner already held keeps the name it has.
- **Strings.** Values in `strings.ts` are unique and the Fixed strings column is their authority, so the row action reuses the published word `Edit` (`agentPanelSecretWarningEdit`), the contact group heading `interopPartnerColumnContact`, and the email label `userFieldEmail`. The retired empty-state line is removed from `strings.ts` and from EXPERIENCE.md's row 604 (the table's literals must all exist in `strings.ts`). The new literals sit in the row's String column and the clause in its Where column; the dialog line is appended to the Dialogs paragraph.
- **Code Map anchors** moved (`InteropPort` is now about 8,900 lines): everything was found by name.
- **Rule 31.** `PerformPartner`, `ReadPartner` and `PartnerFactsHere` follow `PerformLookup`'s and `LookupFactsHere`'s order without the table lock; `ToolEmit` extends the lookup branch to `InteropPartnerAction`; `InteropLookupGate` gains `CreatePrincipals` and `DeletePrincipals`, which `InteropPartnerGate` reuses. `interop-business-partners.browser-spec.mjs` copies the list helpers of `interop-lookup-tables.browser-spec.mjs`, because sharing them would rewrite that spec, and the AC6 list leg moved into it.

**Posture question for the orchestrator** (the story sends it; planning proceeds on (A)):

- (A) The writes declare `%Ens_ProductionConfig:WRITE` and globals WRITE. Recommended. It is stricter than the classic page, so it is a veto-window item.
- (B) `%Ens_ProductionConfig:READ` and globals WRITE, equal to the classic page (inference from source; Task 0 (d) measures it).
- (C) WRITE for the remove only, READ for the add and the update.
- Reason for (A): with (B), `%EnsRole_Operator`, a read-only role that holds `:R` (measured at 20.5), could add, change and remove partners. Every other OcuPilot interoperability configuration write takes `:WRITE`. `%EnsRole_Administrator` and `%EnsRole_WebDeveloper` hold `:W`. The page's missing `EDITRESOURCE` reads as an omission rather than a decision (inference).

**Decided in-stage:**

- Tool names follow the siblings: `add`, `update` (a multi-field edit, as `osmgmt.devices.update` is) and `remove`. The row action id is `edit`, because `update` already labels a production's Update.
- The update is a merge (AD-4) over all thirteen fields. The dialog sends every field, and the kernel refuses an edit that changes nothing.
- The partner name cell stays plain text, as 20.39 left it (`name-links.test.mjs` unchanged). No read gains a field, so 23.12's `ReadDescriptions` roster is unchanged.
- **Rule 31.** `InteropPartnerAction` and its three leaves extend `InteropAction` after the lookup entry tools. `PartnerSave` extends `ItemSave` through a parameter in the parent, not a copy. The page, dialog and store follow the lookup entry trio. `PerformPartner` copies `PerformLookup`'s order for a new row family without the table lock, as `InvokeLookup` copied `InvokeItems`.
- **Not split.** The three writes share one read, one tool base, one page, one dialog and one gate class, and splitting would move the same rosters twice. The size is that of 20.5's Part A.

**New strings for the runner** (proposed wording; the runner rules on each):

- Primary action and dialog title: "New business partner". Row action: "Edit". Edit dialog title: "Edit business partner <name>".
- Group heading "Alternative contact". Field labels "Title", "Mobile" and "Notes". "Name", "Description", "Primary contact", "Email" and "Phone" are reused.
- Dialog sentence: "A business partner is information about an organization or application a production connects to. Saving one changes nothing in how a production runs."
- Rename note (Edit only): "A partner's name cannot be changed. To rename one, add a partner under the new name, change the Business partner setting of each item that names this one, then remove it."
- Empty state, second line: "Ask the agent to add a business partner here." It retires "Business partners are added and changed in the classic Business Partners page."
- `INTEROP.PARTNER.REMOVE` (typed-name confirmation and card): "Removing this business partner deletes its description and both contacts, and it cannot be restored from OcuPilot."
- `INTEROP.PARTNER.TAKEN`: "This namespace already holds a business partner of that name."
- `INTEROP.PARTNER.NAMED`: "Production items name this business partner in their Business partner setting, so it is not removed. Clear that setting on each of them first, then remove the partner."
- `INTEROP.PARTNER.SOURCECONTROL`: "This namespace uses source control, so change business partners in the classic Business Partners page."
- `INTEROP.PARTNER.NAME`: "A business partner name is 1 to 255 characters with no control character."
- `INTEROP.PARTNER.LENGTH`: "This value is longer than a business partner keeps: at most 5,000 characters for a description, 1,000 for notes, 50 for a phone or mobile number and 255 for anything else."
- Conditional on Task 0 (b), `INTEROP.PARTNER.NAMECASE`: "A business partner whose name differs from this one only in letter case already exists. Use its spelling, or choose another name."

**For the owner's attended Update** (the story complies with the ADs as they stand):

- **AD-62 (10)**, replacing its last partner sentence: "Story 20.26: `BusinessPartners` gains `PARTNER`, `ADDPARTNER`, `SETPARTNER` and `REMOVEPARTNER` through `Ens.Config.BusinessPartner` (`%Save`, `%DeleteId`). A rename is refused, a remove of a partner an item's Host `BusinessPartner` setting names is refused, and a namespace under source control refuses every partner write. The pairs are `%Ens_ProductionConfig:WRITE` and globals WRITE (orchestrator ruling)."
- **AD-15:** "Named case (Story 20.26): business-partner writes, which the vendor does not audit, record OcuPilot's own `ConfigChange` from either caller."
- **AD-22:** "Story 20.26's `interop.businesspartners.add` and `.update` ship `true`; `.remove` ships `false`."

**Integration ACs, Consumes, Consumed-by:**

- Integration: AC4. Consumer: Story 20.5's `interop.businesspartners.read` and the screen read route, against `ocupilot-b-ci`.
- Consumes:
  - 20.5: the partner screen, `ListPartners`, `InteropLookupFixture`, the lookup tool and Save patterns.
  - 20.3: `ItemSave`, `ProductionProbe`.
  - 20.22: a setting named by item.
  - 20.23: `AuditRuntime`.
- Consumed-by:
  - Story 21.7 (interoperability parity; inference).
  - 20.12/20.36 workflows that tidy partners (inference).
  - 20.22's item settings, whose `BusinessPartner` value names a partner this story adds.

**Ledger inbox (Rule 17):** DW-2324 is addressed: create, update and remove (AC1), the rename rule (AC2), the remove check (AC3) and the posture question (above).

**Contended (Epic 23, checked 2026-11-12):** none. Epic 23's committed diff changes `Api/Error.cls`, `ui/tools/ci-runner.mjs`, `ci-shards.mjs`, `ci.test.mjs`, `client-paths.test.mjs`, two permissions stores, `journal-records` and `epics.md`. Its uncommitted work changes `Write.cls` (a shared `RemovalRows`), the delete tools including `InteropLookupEntryRemove` and `InteropLookupTableDelete`, and several descriptor tests, `InteropItemDescriptor` among them. This story edits none of them. `scripts/ci-throwaway.sh` takes an add-only line.

**Story 20.25 relative counts (inference until 20.25 lands):** 20.25 moves `ToolWrite` 53 → 56 and `ReadTool` 406 → 409. This story adds three to whatever the branch holds, expected 59 and 412. Task 0 (f) re-reads both.

## Verification

**Shared surfaces:**

- the Business partners descriptor, its actions and empty state
- the write-tool rosters: `ReadTool` +3, `ToolWrite`'s other-port count +3, `ToolRoundTrip`, `SurfaceCoverage`, `ToolEmit`, `EndpointCoverage`
- the governance baseline and the prohibited set's covered types
- `InteropPort`'s `Serves`, `Pairs` and `ItemSave`'s parent rule
- `SCREEN_ACTION_DESCRIPTORS`, `DESTRUCTIVE_CONSEQUENCES`, the action labels, and the Fixed-strings row and the Dialogs line
- the probe partners and the probe production

*Every test added or changed passes on a fresh environment, in either order.*

**Setup (slot B, the implement stage only):** follow common.md's load and redeploy recipes, targeting `ocupilot-b-ci`. The dev instance `ocupilot-slot-b` is for read-only SQL only.

**Commands** (each sized to about 150 s, one class or spec file per call unless `ci-timings.json` puts a batch under about 120 s, `timeout: 600000`):

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one run at a time, with totals read from `%UnitTest_Result`:
  - new: `InteropPartnerControl`, `InteropPartnerRefusals`, `InteropPartnerGate`;
  - touched: `InteropLookupDescriptor`, `InteropLookupEdges`, `InteropLookupRead`, `InteropLookupGate`, `InteropLookupControl`, `InteropFloor`, `InteropDescriptor`, `InteropItemControl`;
  - rosters: `ReadTool`, `ToolWrite`, `ToolRoundTrip`, `ToolEmit`, `SurfaceCoverage`, `EndpointCoverage`, `GovernanceBaseline`, `Governance`, `ToolDispatch`, `Prohibited`, `ReadDescriptions`, `Descriptor`, plus every class the sweep changes.
- `(loop)` `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/interop-business-partners.browser-spec.mjs`, then the same for `browser/interop-lookup-tables.browser-spec.mjs`, on the redeployed bundle.
- `(loop)` `cd ui && npm run test:tools` and, as a separate call, `cd ui && npm run test:components`. Both pass, `name-links.test.mjs` included.
- `(loop)` `cd ui && npm run build`: it passes, with client-lint family 7 clean and the initial bundle under the fixed 2,500 kB warning (the page is lazy).
- `(loop)` `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`, both clean.
- Left to the runner: the full ObjectScript sweep, `npm test`, the smoke and Rule 30's fresh check. Left to CI: the full browser suite.

**Planned pinning mutations (Rule 19):**

| AC | Mutation | Expected red |
|---|---|---|
| AC1 | `PerformPartner` skips `AuditRuntime` | `InteropPartnerControl`'s audit-row assertion |
| AC1 | The update drops `AlternativeNotes` from what it sets | the update leg's read-back (`mismatch`) |
| AC2 | The update's schema gains a rename key (`PartnerFieldRows` adds `NewName`) | `InteropPartnerRefusals`' rename leg |
| AC3 | `PartnerWriteToken` ignores `NamedBy` | the named leg (the partner is removed) |
| AC3 | `PartnerNamedByHere` reads only the running production | the named leg on the stopped probe production |
| AC4 | The add stores `Description` empty | the integration leg's list read |
| AC5 | `Pairs` drops `PARTNERWRITEPAIR` | `InteropPartnerGate`'s `:READ`-only leg |
| AC1 (browser) | The dialog's Edit sends no `PrimaryPhone` | the spec's changed-phone assertion |

**Observed mutations (Rule 19)**, each applied on `ocupilot-b-ci`, the class and every descendant (or the bundle) rebuilt, read red, then reverted:

- AC1: mutation: `PerformPartner` skips `AuditRuntime` -> `InteropPartnerControl`'s five audit and ledger legs went red.
- AC1: mutation: the update skips `AlternativeNotes` -> `InteropPartnerControl.TestThePersonsEditAndRemoveWriteAndAuditWithoutAValue`'s read-back, stored-value and audit-fields legs went red.
- AC1 (browser): mutation: the dialog's Edit sends no `PrimaryPhone` (bundle rebuilt and redeployed) -> `interop-business-partners.browser-spec.mjs`'s changed-phone test went red.
- AC2: mutation: `Name` added to the update's declared screen values -> `InteropPartnerRefusals.TestARenameIsRefusedBeforeAnyPortCall` went red.
- AC2: mutation: `PartnerFieldRows` adds a `NewName` row, so the update's schema admits it -> `InteropPartnerRefusals.TestARenameIsRefusedBeforeAnyPortCall`'s agent leg went red.
- AC3: mutation: `PartnerWriteToken` ignores `NamedBy` -> `InteropPartnerRefusals.TestARemoveOfAPartnerAnItemNamesIsRefused` went red.
- AC3: mutation: `PartnerNamedByHere` reads only the active production -> the same test went red, its production being stopped.
- AC4: mutation: the add stores `Description` empty -> `InteropPartnerControl.TestTheBusinessPartnersReadListsTheAddedChangedAndRemovedPartner`'s first listing went red.
- AC5: mutation: `Pairs` skips `PARTNERWRITEPAIR` -> `InteropPartnerGate`'s read-only principal's write legs went red.
- AC5: mutation: `InteropPartnerAction` declares `WRITEPERMISSION` `READ` -> `InteropPartnerGate.TestEachMissingPairIsRefusedByNameOnEachTool` and `...OnTheScreenRoutes` went red.
- AC1: mutation: `PartnerLimit` answers 255 for the description -> `InteropPartnerControl.TestAValueAtItsLimitIsSavedWhole` went red.
- AC1: mutation: `PartnerSnippet` writes the description unquoted, or `IdOf` of a name-only Save answers a key other than the mint's -> `InteropPartnerControl.TestEveryPartnerWriteRendersItsScript` and `SaveHoldCoverage.TestACreateSaveHoldsTheKeyItsMintComputes` went red.
- AC1: mutation: a misspelled field in `Prohibited.PermittedChangeFields` for `business-partner` -> `InteropPartnerControl.TestTheReviewedFieldListsAndPreconditionCodesAreTheTools` went red.
- AC1: mutation: `PerformPartner`'s `tBusy` answer is skipped -> `InteropPartnerRefusals.TestAnEditOfAPartnerWhoseLockIsHeldIsRefusedUnavailable` went red.
- AC6: mutation: the baseline line of `interop.businesspartners.remove` reads `true` -> `GovernanceBaseline.TestThePurgeIsTheOneDisabledLine` went red.

**QA pass (Rule 19):**

- (QA) `ui/src/app/shell/proposal-card.spec.ts`: a card for `INTEROP.PARTNER.REMOVE` states `interopPartnerRemoveConsequence`, drawn destructive.
- AC1: mutation: `consequenceSentence` drops `INTEROP.PARTNER.REMOVE` -> `proposal-card.spec.ts` "Story 20.26: a business partner's removal states its published sentence" went red.
- AC2: mutation: the dialog's name input is `[readOnly]="false"` -> `interop-business-partner-dialog.spec.ts` Edit test went red.
- AC3: mutation: `PartnerWriteToken` tests `pNamed > 999999` -> `InteropPartnerRefusals.TestARemoveOfAPartnerAnItemNamesIsRefused` went red (loaded on `ocupilot-b-ci`, original reloaded, class green).
- AC5: mutation: `Pairs` skips `PARTNERWRITEPAIR` -> `InteropPartnerGate.TestEachMissingPairIsRefusedByNameThroughThePort` went red (original reloaded, class green).
- AC6: mutation: `interopPartnerRefusalNamed` reworded -> `ui/tools/interop.test.mjs` "each Interoperability refusal and consequence is one sentence on both surfaces" went red.

**Code review (Rule 19):**

- AC1: mutation: `PartnerFits` answers 1 for every name -> `InteropPartnerRefusals.TestANameOrAFieldOutsideItsRuleIsRefusedByItsCode`'s mint and port-add legs for a 255-character name of `$Char(20013)` went red (on `ocupilot-b-ci`, port and subclasses recompiled; reverted, class green).
- AC4 (hermeticity): the pre-review `RowIn` with a second partner in `USER` -> `InteropPartnerControl.TestTheBusinessPartnersReadListsTheAddedChangedAndRemovedPartner`'s "unlisted" leg went red; the fixed helper is green with it present (partner removed after).

## Auto Run Result

Status: done
Blocking condition: none

Summary: Business partners can be added, edited and removed from the Business partners screen and by the agent's confirmed proposal, through new `PARTNER`, `ADDPARTNER`, `SETPARTNER` and `REMOVEPARTNER` types on `InteropPort`. A rename and a remove of a partner an item names are refused, each write is audited by OcuPilot, and Task 0's measurements are under Design Notes.

Files changed: the port, `InteropError`, `Router`, `ItemSave`/`PartnerSave`, the four `InteropPartner*` tools, the partners descriptor, `Baseline` and `Prohibited`, the partner page, dialog and store with their specs, the shell and string wiring, `EXPERIENCE.md`, `ci-throwaway.sh`, three new armed test classes, a new browser spec, and the old-shape and roster tests the spec lists.

Review: 15 findings, none high; 3 medium and 5 low patched (test additions and mutation lines, no product change), 7 rejected with reasons in the Review Triage Log, none deferred. Follow-up review recommended: false (the patches are tests, each shown red by a mutation).

Verification: every `(loop)` class in `## Verification` and both browser specs passed on `ocupilot-b-ci` at the implement pass; after the patches, `InteropPartnerControl` (10), `InteropPartnerRefusals` (7), `InteropPartnerGate` (3), `InteropLookupGate` (3) and `SaveHoldCoverage` (2) pass, and `check-objectscript` reports 0 problems. The full ObjectScript sweep, `npm test`, the smoke, Rule 30's fresh check and the full browser suite are the runner's and CI's. Mutations are under Verification.

Residual risks: `ui/tools/ci-timings.json` has no entries for the new classes and spec until the next refresh; a production class that fails to open is not counted when the scan looks for items naming a partner.
