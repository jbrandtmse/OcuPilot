---
title: 'Story 24.2: The analytics editors (first slice: the term-list editor)'
type: 'feature'
created: '2026-11-15'
status: 'done'
baseline_revision: '5b95c1ab23dddec5988333db4e1afe9f5849e3bd'
baseline_commit: '5b95c1ab23dddec5988333db4e1afe9f5849e3bd'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized', 'multiple-goals']
deferred:
  - summary: 'The spec-gate ruling refuses every term list write in a database that is not journaled, on the inference that a TROLLBACK cannot undo a write there. On this build a TROLLBACK undid a Set, a Kill and a Set in a database with journaling off.'
    evidence: 'Measured on ocupilot-b-ci (Task 0): namespace E24NJ over a database created with GlobalJournalState 2, TSTART, Set, Kill, Set, TROLLBACK 1 left the first value and no second node.'
    location: 'src/OcuPilot/Port/AnalyticsPort.cls'
    severity: 'medium'
    note: 'Runner ruling (Spec Change Log, 2026-11-15, second entry): the refusal stays; recovery after a process or instance failure mid-write on a database with journaling off is not measured (inference).'
---

<intent-contract>

## Intent

**Problem:** Story 20.11 shows a namespace's term lists and their entries read-only. To create a term list, change it, or add, change or remove an entry, a person still opens the classic Term List Manager, and the agent cannot propose any of it.

**Approach:** This is the first slice of the story; Design Notes › Proposed split charters the rest. The term-list editor becomes six write tools through `AnalyticsPort`, each reached by two callers (AD-53):

- the person's own actions on the two Term lists screens;
- the agent's confirmed proposals.

The tools are:

- **Term lists:** create, change properties, delete.
- **Entries:** add, change, remove.

Each write calls the vendor's `%DeepSee.TermList` methods, except for two single-node touches the class offers no call for (Boundaries › Vendor calls only).

## Boundaries & Constraints

**Always:**

- **Gate first (AD-29, AD-65).** Every write runs `AnalyticsPort`'s existing gate in this order:
  1. `TERMLISTPAIRS`: `%DeepSee_Portal:USE` and `%DeepSee_PortalEdit:USE`. The second is the classic page's own resource.
  2. The namespace's shape.
  3. The namespace reports analytics, else 409 `ANALYTICS.NAMESPACE`.
  4. READ on the globals database and on the routines database.
  5. Then, through `AdmitDestination`, WRITE on the database `^DeepSee.TermList` maps to, mounted read-write, else 409 `ANALYTICS.TERMLIST.READONLY`.

  All of this happens before any vendor call. A refusal names the failed pair.
- **Vendor calls only (AD-65 as amended at this gate, Design Notes › Spine clauses).**
  - The calls are `%CreateTermList`, `%FromObj` (header properties only, with no values), `%SetValue`, `%DeleteTermList`, and the reads `%TermListExists`, `%ToObj` and `%Lookup`.
  - The class offers no call for two operations, so the port touches one node for each, in the class's own documented layout:
    - **removing one entry:** `Kill ^DeepSee.TermList(ID,"data",key)`, then sets `modDate` as `%SetValue` does;
    - **reading or setting the hide-value flag:** `^DeepSee.TermList(ID,"hideValue")`, which `%ToObj` never reads.
  - No path, stream or CSV is used. Import, export and copy are in the split.
- **All-or-nothing where the instance allows it.** A tool that makes more than one vendor call runs them inside one `TSTART`/`TCOMMIT`, with a `TROLLBACK` on any failure. Those tools are: property change, entry add, entry change.
  - No audit call, job or I/O happens inside the transaction.
  - Design Notes › Touches U-34 names the unjournaled case.
- **Case is the vendor's.**
  - List names and field names fold to upper case. A create whose name matches an existing list ignoring case is refused 409 `ANALYTICS.TERMLIST.TAKEN` before `%CreateTermList`, which would otherwise kill that list.
  - Entry keys are case-sensitive.
- **Shape rules, checked before any vendor call.** A breach answers 422 naming the rule.
  - A list name or key is 1 to 255 characters, with no control character, within the length the instance can store. The length rule is `LookupViolations`' rule.
  - A key or field name holds no `^`, because `%ToObj` splits on it.
  - A field name is never `Value`, compared ignoring case, and never repeated. At most 50 fields.
  - Caption, pattern and subject area are each at most 255 characters. A description and any value are each at most 32,000 characters.
  - A field value names a field the list holds.
  - A field leaves the list only when no entry holds a non-empty value for it (`ANALYTICS.TERMLIST.FIELDINUSE`).
- **Write model.**
  - Server-minted proposal (AD-6).
  - A create inverts the fresh read and fingerprints the target's absence (AD-54).
  - A merge sends a complete header (AD-4).
  - Delete and remove are action-style (AD-51).
  - Prohibited-set review (AD-10).
  - One change event of `term-list` or `term-list-entry` (AD-14).
  - Read-back (AD-58).
  - Agent marker (AD-15). Every write from either caller also records OcuPilot's own `ConfigChange`, because the vendor audits none of these writes (Task 0 measures it).
- **Governance (AD-22).** The six keys join `Baseline.cls` in this change. Delete and remove ship `false` (Design Notes › Governance keys).
- **Untrusted content (AD-11, AD-60).** Names, captions, patterns, keys and values reach the screen only as interpolated text.
- **Contended files take add-only edits, except those named in Design Notes › Contended files.**

**Never:**

- `/api/deepsee`, `%Api.DeepSee` or `%DeepSee.REST.*`.
- `%ImportCSV`, `%ExportCSV`, `%GetTermListNameFromStream`, or any file path or stream (AD-21).
- A `%CreateTermList` call over an existing list.
- A delete-then-recreate rewrite of a whole list. The classic page saves this way; OcuPilot does not.
- A harvested body: the MCP suite has no term-list handler (measured). AD-23's seam is not engaged.
- Edits to `Screen/Read.cls`, `Screen/Registry.cls`, `ui/tools/screen-mirror.mjs`, `Test/PortGate.cls`, `Kernel/EntityType.cls`, `app.routes.ts`, `angular.json` or the CI files.

## I/O & Edge-Case Matrix

Every row runs in USER on `ocupilot-b-ci`, with analytics turned on by `AnalyticsProbe` and lists named with the test's own marker.

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Create | New term list `M1` with caption, description, pattern, subject area, Fields `[Region]` and Hide value on | `%TermListExists` true. Each property reads back, hide value from its node. Read-back `holds`; one `created` change event | - |
| Name taken | Create `m1` while `M1` exists with entries | Nothing written; `M1`'s entries are unchanged | 409 `ANALYTICS.TERMLIST.TAKEN` |
| Change properties | Change `M1`'s caption and add field `Note` | Only the header changes, and every entry is unchanged. Read-back `holds` | - |
| Field in use | Remove `Region` while one entry holds a Region value | Nothing written | 422 `ANALYTICS.TERMLIST.FIELDINUSE` |
| Entry add | Key `K1`, Value `V1`, `Region` `West` | `%Lookup(M1,"K1")` is `V1`, and with `Region` it is `West` | - |
| Entry taken / list gone | Add `K1` again; or add to a list deleted after the mint | Nothing written | 409 `ANALYTICS.TERMLIST.ENTRYTAKEN` / 404 `ANALYTICS.TERMLIST.ABSENT` |
| Entry change | `K1` Value `V2` and `Region` empty | `%Lookup` reads `V2`, and `Region` reads empty | - |
| Partial failure | Seam fails the second `%SetValue` of an entry change | The entry reads as it did before. The write answers its failure. No change event | Transaction rolled back |
| Entry remove / list delete | Typed-name confirm | Entry: `%Lookup` answers its default. List: `%TermListExists` false. Read-back expects absence | - |
| Shape | Key `a^b`, field `value`, a 32,001-character value, an unknown field | Nothing reaches the vendor | 422 naming the rule |
| Read-only | `^DeepSee.TermList` maps to a read-only database | Before any vendor call | 409 `ANALYTICS.TERMLIST.READONLY` |
| Pair missing | A principal without `%DeepSee_PortalEdit:USE` | Before any vendor call | 403 `AUTH.NOPRIVILEGE`; `detail.failedPair` names the pair |
| Governance | Agent delete or remove with its key at `false` | No proposal is confirmed. A person's own Delete is not asked (AD-22) | The governance refusal |
| Stale | The list changes between mint and confirm | Nothing written | The confirm's fingerprint refusal (AD-34) |

</intent-contract>

## Code Map

Paths are under `/Users/jbrandt/git/OcuPilot/.worktrees/epic-24` (HEAD `857ef0518dfa4eec7a01cc4a4cfba20ff8719571`).

- **`src/OcuPilot/Port/AnalyticsPort.cls`** (2,008 lines): the port this story extends.
  - Endpoints: `ENDPOINTS` :71 and `TERMLISTPAIRS` :105.
  - Routing: `Pairs` :270 (term-list branch :278), `Serves` :288 and `IsWrite` :296. Widen these two for the new read and write types. `Invoke` :334 routes a non-LIST type at :354-:357, as `InvokeCubeManager` :1697 does.
  - Gate: `Admit` :404, `AdmitNamespace` :437 and `AdmitDestination` :420. Reuse the last with `"^DeepSee.TermList"` and the new READONLY code.
  - Term-list reads: `Collect` :471, where `%GetTermLists` is :542 and `%ToObj` :555. The switch is :479, the restore :588, and the restore is the `Catch`'s first line at :590.
  - Write pattern: `PerformCube` :1748 and `AuditWrite` :1954 (`Kernel.Audit.Event.Record`, after the restore, never failing the write).
  - Private refusals: `Deny` :730, `Refuse` :738, `Conflict` :747, `Fail` :763 and `Absent` :1965.
- **`src/OcuPilot/Api/AnalyticsError.cls`**: the new `ANALYTICS.TERMLIST.*` codes and sentences go here, not in `Api/Error.cls` (DW-2473's sibling note).
- **`src/OcuPilot/Screen/Tool/AnalyticsAction.cls`** and the `AnalyticsCube{Build,Synchronize}.cls` tools: 20.34's analytics write tools (`PORTCLASS`, `PrivilegePairs`, `CLASSICPAGES`, `FINGERPRINTSUBJECT`, `CONSEQUENCECODE`, `SCREENACTIONS`).
- **The lookup editor (Story 20.5): the shape to follow.**
  - Tools: `Screen/Tool/InteropLookupEntry{Action,Add,Set,Remove}.cls` and `InteropLookupTableDelete.cls`. They use `CREATES`, `READBACKTOOL`, `READBACKFIELDS`, `FIELDS`, `FieldRows`, `ComposeCreate`, `CreatedId`, `REMOVALROWS`, `StateDiff` and `InteropLookupEntryMint`, which builds the composite id.
  - The port's write: `Port/InteropPort.cls` `InvokeLookup` :6111, `LookupWriteToken` :6086, `ReadLookupEntry` :6386-:6408, `LookupViolations` and `PerformLookup` :6423.
  - Save routes: `Area/Interop/ItemSave.cls`, which resolves `PortClass` from its `CREATETOOL`, and `Area/Interop/LookupEntrySave.cls` behind `Api/Router.cls` :274 and :1935.
  - Client pages: `ui/src/app/areas/interoperability/interop-lookup-{table-list.page,entry-list.page,entry-dialog,entry.store}.ts`, registered in `ui/src/app/shell/screen-outlet.ts` :231-:233.
- **Descriptors:** `src/OcuPilot/Screen/Descriptor/AnalyticsTermListList.cls` and `AnalyticsTermListEntryList.cls`. The entry list already declares `id` composite `["TermList","Key"]` and empty actions. Add `primaryAction` and `rowActions` ids only.
- **Kernel touches:**
  - `Kernel/Governance/Baseline.cls`: `XData Keys` :17. Insert after :255 (`analytics.cubemanager.synchronize`).
  - `Kernel/Proposal/Prohibited.cls`: `COVEREDTYPES` :282, the `Prohibits` chain :1460, and the cube branch :1803 as the precedent.
  - `Kernel/Audit/Event.cls`: `EVENTCONFIG` `ConfigChange` :25 and `Record` :194.
- **Client maps:**
  - `ui/src/app/shell/screen-action-handler.ts`: `SCREEN_ACTION_DESCRIPTORS` :70, `DESTRUCTIVE_ACTIONS` :544, `DESTRUCTIVE_CONSEQUENCES` :572/:631 and `TYPED_NAME_ROWS` :680/:716.
  - `ui/src/app/shell/screen-actions.ts` about :160, and `ui/src/app/shell/proposal-view.ts` about :400 and :571.
  - `ui/src/app/core/strings.ts`: the analytics block runs :7654-:7854, with the term-list keys at :7656-:7740.
- **Tests and fixtures:**
  - `Test/AnalyticsProbe.cls` (turns USER's analytics on, `Remove`, `Left`), `Test/AnalyticsPort.cls` and `Test/AnalyticsGate.cls`.
  - `Test/AnalyticsCube{Actions,Gate,Manager,Seam}.cls`: 20.34's write tests and their vendor seam.
  - `ui/tools/analytics.test.mjs`, and `ui/browser/analytics.browser-spec.mjs` and `analytics-cube-manager.browser-spec.mjs`.
- **`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`**:
  - :604 is the 47 KB Fixed strings row that Epic 21 is editing, so do not touch it. :606 is the table's last row. Add a new row after it.
  - :298 holds "Type <name> to confirm".
- **Vendor (read only):**
  - `irislib/%DeepSee/TermList.cls`: the node layout :19-29, `%DeleteTermList` :91, `%CreateTermList` :160 (it starts with a `Kill`), `%SetValue` :181, `%ToObj` :557 and `%FromObj` :609.
    - `%ToObj` never reads `hideValue`.
    - For a missing list, `%ToObj` leaves `pSC` undefined.
    - `%FromObj` sets the seven header nodes, and `modDate` from the object, and kills nothing.
  - `irislib/%DeepSee/UI/TermListManager.cls`: `RESOURCE` `%DeepSee_PortalEdit` :18, and `SubmitTermList` :883-:933, which saves as delete, create, then `%SetValue` per cell.

## Tasks & Acceptance

**Execution:**

- [x] **Task 0: measure, on `ocupilot-b-ci` only.** Use USER, analytics on through `AnalyticsProbe`, and marker-named lists. Record the results under Design Notes › Measured, then remove everything created.
  1. With auditing on, check whether any vendor audit event records a `%CreateTermList`, `%FromObj`, `%SetValue`, entry-node `Kill` or `%DeleteTermList`. None is expected.
  2. Read USER's database journal state. Check whether a `TROLLBACK` after `%SetValue` inside `TSTART` restores the node.
  3. Check that the longest name, key and field the shape rule admits can be stored.
- [x] `src/OcuPilot/Port/AnalyticsPort.cls`: extend `ENDPOINTS`, `Serves`, `IsWrite` and `Invoke`.
  - Read types `TERMLIST` (header plus `HideValue`) and `TERMLISTENTRY` (`{TermList, Key, Value, Fields}`) for the mint's fresh read, the fingerprint and the read-back.
  - Write types `ADD`, `UPDATE`, `DELETE`, `ENTRYADD`, `ENTRYSET` and `ENTRYREMOVE`.
  - Add `TermListViolations` for the shape rules, the gate with `AdmitDestination`, the transaction around each multi-call write, the refusals, and `AuditWrite` with `ConfigChange` after commit and restore.
  - Keep the vendor calls behind seam methods (`VendorTermList*`), as 20.34's `VendorBuild` is, so the partial-failure row is testable.
- [x] `src/OcuPilot/Api/AnalyticsError.cls`: the codes `TERMLIST.TAKEN`, `ENTRYTAKEN`, `ABSENT`, `NAME`, `KEY`, `FIELD`, `FIELDINUSE`, `VALUE`, `READONLY`, `DELETE` and `REMOVE`, each with the sentence from Design Notes › Proposed strings.
- [x] `src/OcuPilot/Screen/Tool/`: an abstract `AnalyticsTermListAction` (port, pairs, `CLASSICPAGES` `%DeepSee.UI.TermListManager`, read types), then the six tools:
  - `AnalyticsTermListAdd` (create, `READBACKTOOL` `AnalyticsTermListUpdate`);
  - `AnalyticsTermListUpdate` (merge);
  - `AnalyticsTermListDelete` (action, destructive);
  - `AnalyticsTermListEntryAdd`, with a mint for the composite id;
  - `AnalyticsTermListEntrySet`;
  - `AnalyticsTermListEntryRemove` (destructive).

  Tool names, fields and `SCREENACTIONS` are in Design Notes › Tools.
- [x] `src/OcuPilot/Area/Analytics/TermListSave.cls` and `TermListEntrySave.cls`, extending `Area/Interop/ItemSave.cls`. Add `POST /analytics/term-lists` and `POST /analytics/term-list-entries` to `Api/Router.cls`, add-only, beside :274 and :1935.
- [x] The two term-list descriptors: `primaryAction` `add`, and `rowActions` `update` and `delete` on the list, or `set` and `remove` on the entries.
  - New term list and Add entry post to the two new routes.
  - Edit, Change, Delete and Remove are screen actions through `POST /screens/:screen/action`, carrying only the values their tool declares (AD-53, AD-56).
- [x] `Kernel/Governance/Baseline.cls` (six keys after :255) and `Kernel/Proposal/Prohibited.cls`: cover `term-list` and `term-list-entry` as reviewed, following the `cube` branch. OcuPilot itself uses no term list, so nothing is prohibited.
- [x] Client:
  - New `ui/src/app/areas/analytics/term-list{-list.page,-entry-list.page,-dialog,-entry-dialog,.store}.ts`, registered add-only after `screen-outlet.ts` :252.
  - Add the new actions to the client maps.
  - Add the strings to `strings.ts`, each cited to the new EXPERIENCE.md row.
- [x] `EXPERIENCE.md`: one new Fixed strings row after :606, holding Design Notes › Proposed strings verbatim.
- [x] Tests.
  - New: `Test/AnalyticsTermListEdit.cls` (the port, the matrix and the seam), `Test/AnalyticsTermListGate.cls` (pairs, read-only and governance; armed `OCUPILOT_ALLOW_PRINCIPALS` in `scripts/ci-throwaway.sh`'s roster) and `Test/AnalyticsTermListRoutes.cls` (both callers, read-back, change event, marker and `ConfigChange`).
  - Extend `ui/tools/analytics.test.mjs`.
  - New `ui/browser/analytics-term-list-editor.browser-spec.mjs`.
  - Update every roster Design Notes › Contended files names.

- [x] Spec-gate ruling (Spec Change Log, item 2): each of the six term-list writes, from either caller, is refused 409 `ANALYTICS.TERMLIST.NOTJOURNALED` with the ruled reason, before any vendor call or transaction, when the database the namespace's term-list global maps to is not journaled; a matrix-style test pins it on the throwaway (a probe namespace or database with journaling off, created with its own directory and removed after) and Task 0 records the rollback measurement.

**Acceptance Criteria:**

- **AC1 (create, change and delete a term list, by both callers).**
  - **Given** USER with analytics on.
  - **When** a person uses New term list, Edit and Delete on Term lists, and the agent's `analytics.termlists.add`, `.update` and `.delete` proposals are confirmed.
  - **Then:**
    - each list's properties, hide value included, read back through `%ToObj` and its node;
    - Term lists re-fetches and shows the change;
    - each write answers `readBack` `holds`, or absent for a delete;
    - the delete asks for the typed name with its consequence sentence.
- **AC2 (entries, by both callers).**
  - **Given** a term list with field `Region`.
  - **When** entries are added, changed and removed from the Entries screen and through the agent's three entry tools.
  - **Then:**
    - `%Lookup` answers each value and field value written, and a removed key answers its default;
    - the Entries screen shows the same rows as `analytics.termlistentries`.
- **AC3 (refusals before the vendor).**
  - **Given** each refusal row of the I/O matrix.
  - **When** it is attempted from either caller.
  - **Then** it answers that row's code and sentence, and a snapshot of `^DeepSee.TermList` taken around the attempt is unchanged.
- **AC4 (all or nothing).**
  - **Given** a journaled USER database and a seam that fails the second vendor call of an entry change.
  - **When** the change is confirmed.
  - **Then:**
    - the entry reads as it did before;
    - the write reports failure;
    - no change event is emitted.
- **AC5 (audit).**
  - **Given** auditing on.
  - **When** each tool's write succeeds.
  - **Then:**
    - from either caller, OcuPilot's `ConfigChange` names the tool, the namespace and the list or entry;
    - an agent write also carries the marker with the proposal id (AD-15).
- **AC6 (Integration, Rule 1).**
  - **Given** an entry the agent's `analytics.termlistentries.add` wrote.
  - **When** `GET /screens/analytics.termlistentries/read` and the read tool `analytics.termlistentries` run for that list.
  - **Then** both answer the new row with its `Fields` joined as `Region: West`.
- **AC7 (declared, governed and rostered).**
  - **Given** the six tools.
  - **When** the instance validates them.
  - **Then:**
    - each declares `write`, its port and its classic page;
    - `Baseline.cls` holds the six keys, with delete and remove at `false`;
    - `GovernanceBaseline`, `SurfaceCoverage`, `EndpointCoverage` and `SaveHoldCoverage` hold their rows, and removing one row reddens that test alone.
- **AC8 (the fixture leaves USER as found).**
  - **Given** a run of any new test class or of the browser spec.
  - **When** it ends.
  - **Then** no marker-named term list remains, and `AnalyticsProbe.Gone()` is true.

## Spec Change Log

- 2026-11-15, runner spec gate (unattended rulings, one veto item): (1) the `Proposed split` is applied in `epics.md`: 24.2 keeps the term-list editor; Stories 24.10-24.14 are inserted after 24.9, and AN-16 and AN-17 stay in scope as 24.14 (the runner's reading of "the remaining analytics editors"; inference). (2) **Partial application (U-34 avoided, not decided):** every one of the six term-list writes is refused before any vendor call when the database the term-list global maps to in that namespace is not journaled, so a write is always all-or-nothing inside its transaction and no partly applied write exists to audit. Task 0 measures that a `TROLLBACK` undoes a multi-step term-list write in a journaled database and that the journal check reads the right database. The refusal is 409 `ANALYTICS.TERMLIST.NOTJOURNALED` with the ruled reason "Term lists can be changed only in a journaled database, so that a change is never left half done. Journaling is off for the database that holds this namespace's term lists." (3) The `Proposed strings` are kept as written, with that reason added. (4) The term-list writes extend `AnalyticsPort` under AD-65's Binds ("later writes"), the vendor-unaudited writes record OcuPilot's own `ConfigChange` under AD-15's existing Rule, and the six keys join the baseline under AD-22's Rule; the spine is not edited in this run, and the `Spine clauses for the spec gate` above wait for the owner's attended architecture update as proposed lines. Contended files were checked against `origin/OCU-1-epic21` on 2026-11-15; the runner re-checks before implement.

- 2026-11-15, runner ruling on the implement-stage HALT (veto item): the two agent empty-state values follow the established `*EmptyAgent` pattern, a lowercase action phrase the empty state wraps (as `userListEmptyAgent: 'create a user'`): `analyticsTermListsEmptyAgent: 'create a term list'` and `analyticsTermListEntriesEmptyAgent: 'add an entry to this term list'`, in `strings.ts` and the EXPERIENCE.md row. The `NOTJOURNALED` refusal stays as ruled: the in-process `TROLLBACK` measurement is recorded, and recovery after a process or instance failure mid-write on a database with journaling off is not measured (inference), so the safe behavior is kept; the `deferred:` medium is harvested by the runner, not re-implemented.

## Review Triage Log

### 2026-11-15 -- Review pass

- verdicts: 16 findings -- high 0, medium 5, low 8, false 3, maybe-false 0
- findings:
  - `[medium]` `[patch]` The mint's rule and state checks (`RuleProblem`, `StateProblem`) had no test -- patched: `AnalyticsTermListRoutes.TestAMintRefusesWhatTheWriteWouldRefuse` mints six refusals and asserts each answer, its sentence, no proposal and the nodes unchanged; mutation recorded.
  - `[medium]` `[patch]` The journaling refusal was pinned only through the seam's override, never the production `DestinationJournaled` against a database with journaling off -- patched: a leg reads the instance's own temporary database (no journaling) through the production method; mutation recorded. A full unseamed write against a created unjournaled database stays under the deferred medium.
  - `[medium]` `[patch]` The property change's transaction (a failed hide-value write after the header) was unpinned -- patched: seam mode `failhide` and a leg in `TestAFailedSecondValueWriteRollsTheEntryBack`; mutation recorded.
  - `[low]` `[patch]` The entry change's overlay of an omitted field was unpinned -- patched: the agent's list has two fields and its entry change names one; the read-back leg goes red when the overlay is dropped; mutation recorded.
  - `[medium]` `[patch]` The dialogs' refusal rendering had no host -- patched: browser spec AC3 drives a taken name and a taken key and asserts the server's sentence and nothing written; mutation recorded for both dialogs.
  - `[medium]` `[patch]` Mutations named in test comments but not recorded (pair missing, stale, `EndpointCoverage`, `SaveHoldCoverage`, `MappingDescriptor`) -- patched: each run and recorded; the pair mutation needed four layers removed together, and the Gate test's comment now says so; a `TermListForm` comment named a mutation that reddens nothing and was corrected.
  - `[low]` `[patch]` A test comment claimed an add leg the body lacks -- patched: the comment now describes the legs.
  - `[low]` `[reject]` Assertions guarded by `If $IsObject(...)` skip silently -- each follows an assertion of the 200 or 201 status, so a non-object body with that status is a different, loud failure; a guard-and-else on each is more than a direct correction.
  - `[low]` `[reject]` Change entry parses the row's joined `Fields` text and mis-splits a value that holds `; <next field>: ` -- real only for that literal text; the fix is a structured read the row does not carry, so it is not worth the surface.
  - `[low]` `[reject]` `settle()` and `Hang 1.1` are timing waits -- `settle()` is the sibling handler specs' own idiom with an awaited promise chain, and the one-second wait crosses the vendor's one-second `modDate` on purpose.
  - `[low]` `[reject]` `TestTheDeleteAndRemoveKeysShipOffForTheAgentOnly` asserts a stored policy it did not create -- every test in the suite restores the policy it changes, and `GovernanceBaseline` asserts the same precondition.
  - `[low]` `[reject]` AC4's "no change event" is asserted at the port as no audit row -- the change event is emitted by the caller's success branch only, so a refused write cannot emit one.
  - `[low]` `[reject]` The read-only row comes from a seam override, not a mounted read-only database -- the matrix names the seam for its failure rows, the production `DestinationDatabase` is read by 20.34's tests, and the pair legs use real principals.
  - `[false]` `[reject]` The unjournaled refusal goes beyond the contract's gate list -- it is the spec-gate ruling (Spec Change Log, 2026-11-15), kept as ruled.
  - `[false]` `[reject]` Extra codes and a form read the contract does not list -- Design Notes, Decided in-stage 8 and 12 name them.
  - `[false]` `[reject]` No matrix row is asserted at the UI -- the browser spec drives AC1, AC2 and AC3 on the two screens, and the matrix rows are port behaviours.

## Design Notes

**Governing ADs (Rule 6).**

- AD-65 is the port, and is amended here (below).
- The gate is AD-29 and AD-8. Database READ is AD-9.
- The write path:
  - AD-6 and AD-34 (proposal and confirm);
  - AD-4 (merge) and AD-54 (create);
  - AD-51 (delete and remove);
  - AD-52 (port declaration);
  - AD-53 and AD-55 (two callers);
  - AD-56 (screen values);
  - AD-58 (read-back);
  - AD-14 (change event);
  - AD-10 (prohibited review).
- AD-15 is audit, with a named case added here. AD-22 is the keys.
- AD-3 is the derived field lists.
- AD-13 is the composite id.
- AD-16 is the namespace switch, which also covers the transaction inside the switch.
- AD-21: no path.
- AD-11 and AD-60: untrusted text.
- AD-44: `%DeepSee.UI.TermListManager`.
- AD-5: actions declared on the existing descriptors.

Checked and not engaged:

- AD-23: no handler exists, so the harvest seam is not engaged.
- AD-36 and AD-24: the reads are unchanged.
- AD-62 and AD-63: interop only.
- AD-66: no workflow.

**Spine clauses for the spec gate (Rule 20; the runner writes them).**

- **AD-65:** the term-list editor's calls, its two named nodes (the entry kill and `hideValue`), the WRITE check through `AdmitDestination` with `ANALYTICS.TERMLIST.READONLY`, and the transaction rule.
- **AD-15:** a named case. Term-list writes, which the vendor does not audit, record OcuPilot's own `ConfigChange` from either caller (lookup tables' precedent). This is pending Task 0's measurement.
- **AD-22:** the six keys.

**Touches U-34.** `analytics.termlists.update` makes several writes: `%FromObj`'s header sets, then the `hideValue` set. `analytics.termlistentries.add` and `.set` make one `%SetValue` per value and field.

- Inside one transaction, each is all-or-nothing where the term-list database is journaled.
- Where it is not journaled, a `TROLLBACK` cannot undo them (inference; Task 0 measures USER), so the write can be partly applied.
- Ruled at the spec gate (Spec Change Log, item 2): every term-list write is refused when that database is not journaled, so no write can be partly applied and U-34 is not touched.

**Tools.** Policy keys and defaults:

| Tool | Kind | Fields | Screen action | Key default |
|---|---|---|---|---|
| `analytics.termlists.add` | create | `Name`, `Caption`, `Description`, `Pattern`, `SubjectArea`, `Fields` (array), `HideValue` | `add` | `true` |
| `analytics.termlists.update` | merge | as add, without `Name` | `update` | `true` |
| `analytics.termlists.delete` | action, destructive | none | `delete` | `false` |
| `analytics.termlistentries.add` | create | `TermList`, `Key`, `Value`, `FieldValues` (array of `{Field, Value}`) | `add` | `true` |
| `analytics.termlistentries.set` | merge | `Value`, `FieldValues` | `set` | `true` |
| `analytics.termlistentries.remove` | action, destructive | none | `remove` | `false` |

**Decided in-stage (plan).**

1. **The slice.** 24.2 is the term-list editor's create, change and delete of lists and entries. Everything else the story names, plus term-list import, export and copy (the classic Save As), moves to the siblings below.
2. **Removing a field never drops data.** The classic page's Delete Field becomes two steps: clear the values, then remove the field. The safe behavior is kept.
3. **The two direct node touches are proposed as an AD-65 clause, not a workaround.** The class has no remove-entry or hide-value call, and both nodes are in its own documented layout (20.34's lock probe is the precedent).
4. **No lock.** The vendor and the classic page take none. The confirm's fingerprint re-read (AD-34) is the concurrency check.
5. **The limits** (255, 32,000 and 50) follow the lookup editor's sentences. 50 fields is the plan's own bound.
6. **New strings go in a new EXPERIENCE.md row,** not in :604, so Epic 21's edit there stays conflict-free.
7. **The analytics classes run one per call.** `ci-timings.json` has no row for the new classes.

**Proposed strings (veto item).** Plain language. Every sentence ends with a period.

- **Actions:**
  - "New term list"
  - "Edit term list"
  - "Delete term list"
  - "Add entry"
  - "Change entry"
  - "Remove entry"
- **Dialog titles:**
  - "New term list"
  - "Edit term list <name>"
  - "Add an entry to <name>"
  - "Change entry <key>"
- **Field labels:**
  - "Term list name"
  - "Caption"
  - "Description"
  - "Pattern"
  - "Subject area"
  - "Fields"
  - "Hide value"
  - "Key"
  - "Value"
- **Help:** "Fields name the extra columns each entry can hold besides its value."
- **Refusals:**
  - "This namespace already holds a term list with that name. Names are compared without regard to case."
  - "This term list already holds an entry with that key."
  - "This term list no longer exists."
  - "A term list name is 1 to 255 characters with no control character, within the length the instance can store."
  - "An entry key is 1 to 255 characters with no control character and no ^, within the length the instance can store."
  - "A field name is 1 to 255 characters with no control character and no ^. It is not Value, and no two fields share a name. A term list has at most 50 fields."
  - "This term list has no field of that name."
  - "Some entries hold a value for this field. Clear those values first, then remove the field."
  - "A caption, pattern or subject area is at most 255 characters, and a description or value at most 32,000."
  - "The database that holds this namespace's term lists is read-only, so nothing was written."
- **Consequences:**
  - "Deleting this term list removes it and all its entries, and anything that uses it can no longer read them. This cannot be undone from OcuPilot."
  - "Removing this entry cannot be undone from OcuPilot."

**Governance keys.**

- `analytics.termlists.add`, `.update`: `true`
- `analytics.termlists.delete`: `false` (destructive)
- `analytics.termlistentries.add`, `.set`: `true`
- `analytics.termlistentries.remove`: `false` (destructive)

**Extend, don't copy (Rules 2 and 31).**

- **The port:** the writes extend `AnalyticsPort`. The gate (`Admit`, `AdmitDestination`) and `AuditWrite` are reused, and the vendor seam follows `VendorBuild`'s.
- **The tool base:** `AnalyticsTermListAction` is a sibling of `AnalyticsAction`, not a subclass. `AnalyticsAction` is bodyless and bound to `^DeepSee.Fact`, while four of these tools send bodies. If the two `PrivilegePairs` bodies differ only in the destination global, lift that difference into a `DESTINATIONGLOBAL` parameter on `AnalyticsAction` and extend it.
- **The save routes:** both extend `Area/Interop/ItemSave`, which is generic over its tool's port.
- **The client pages, dialogs and store:** these follow the lookup pages' shape as new files. The reason they are copies: the lookup files belong to the Interoperability area, and a term-list entry carries the list's own fields.
- **The tests:** they extend `AnalyticsProbe` and the `AnalyticsCubeSeam` pattern, and use `InteropTestGate.CreatePrincipals`.

**Integration, Consumes, Consumed-by (Rules 1 and 2).**

- **Integration:** AC6.
- **Consumes:**
  - Story 20.11: `AnalyticsPort`, the two descriptors, `AnalyticsProbe`, `AnalyticsError` and the `term-list` and `term-list-entry` types.
  - Story 20.34: the write pattern and `AdmitDestination`.
  - Story 20.5: the lookup editor's shape and `ItemSave`.
  - The kernel's proposal, confirm, governance and audit.
- **Consumed-by:**
  - 24.10: import, export and copy extend these tools.
  - 24.4: undo snapshots and reverts these writes.

**Ledger inbox (Rule 17):** none owned (`owned_ledger=0`).

- DW-2473 is not engaged, because `Screen/Read.cls` is untouched.
- DW-2474 concerns the cube sentences, which this story leaves alone.

**Contended files (not add-only; check each against `OCU-1-epic21` before implementing).** Each is a single line or literal that 21.2 or 24.1 also edits:

- `Test/ReadTool.cls` :93-94: the count and the names;
- `Test/ToolRoundTrip.cls` `REFUSEEMPTY` :102;
- `Test/ToolWrite.cls` :1326 (`tOtherPorts`);
- `Test/GovernanceBaseline.cls` `DISABLED` :15;
- `Kernel/Proposal/Prohibited.cls` `COVEREDTYPES` :282, and `Test/Prohibited.cls` :233;
- `Test/ClassicPageGate.cls` `OWNPAIRS` :76 and its sentence :175, and `Test/MappingDescriptor.cls` `CLASSICROSTER` :24.

These edits are add-only, at clean positions:

- `Baseline.cls` after :255;
- `SurfaceCoverage.cls` after `AnalyticsFolderItemList` (about :273);
- `Governance.cls` and `ToolDispatch.cls`: a new parameter or branch;
- `ToolEmit.cls`: a new branch, because the pairs differ;
- `EndpointCoverage.cls` and `SaveHoldCoverage.cls`: new rows;
- `Router.cls`, `screen-outlet.ts` and the client maps;
- `strings.ts`, inside the analytics block;
- the EXPERIENCE.md row;
- `ci-throwaway.sh`, beside :593.

**Proposed split** (for the runner, Rule 5 tier 2; numbered from 24.10, after 24.9). The story's text is "the term-list editor, the folder manager's export, import and delete, and the remaining analytics editors".

- **Which catalog rows that phrase covers (inference).** Epic 21's 165 rows are `extract-stages.md`'s custom-REST stage. Its analytics rows are AN-11 to AN-17, and 24.2 is their only home.
- **The open question.** AN-16 (the PMML model tester) and AN-17 (the dashboard and pivot viewer) are a console and a viewer, not editors. Whether they belong to "the remaining analytics editors" is the runner's call. Excluding them drops scope, which is owner-only.
- **24.10 "Folder manager transfer and term-list import, export and copy":**
  - "**Given** the folder manager's export, import and delete **When** each runs **Then** it round-trips over its backing class."
  - "**Given** the term-list editor's import, export and copy **When** each runs **Then** it round-trips over its backing class."
- **24.11 "Listing groups":** "**Given** the remaining analytics editors: the listing group manager **When** each runs **Then** it round-trips over its backing class." It saves and compiles a class.
- **24.12 "Quality measures":** "**Given** the remaining analytics editors: the quality measures editor **When** each runs **Then** it round-trips over its backing class." It saves and compiles a class.
- **24.13 "Analytics settings":** "**Given** the remaining analytics editors: the analytics settings **When** each runs **Then** it round-trips over its backing class."
- **24.14 "PMML model tester and dashboard viewer":** "**Given** the remaining analytics editors: the PMML model tester and the dashboard and pivot viewer **When** each runs **Then** it round-trips over its backing class."
- **24.2's own criterion:** "**Given** the term-list editor **When** each runs **Then** it round-trips over its backing class."

**Measured** (plan, 2026-11-15, `ocupilot-b-ci`, USER):

- One probe list made the full round trip and was removed: `%CreateTermList`, `%SetValue` with and without a field, `%Lookup`, `%ToObj`, the entry `Kill` and `%DeleteTermList`.
- `%TermListExists` answers 10 for a held list.
- The global is per-namespace: in USER it maps to `/durable/iris/mgr/user/`.
- The MCP suite's `REST/Analytics.cls` has only `ExecuteMDX`, `CubeList` and `CubeAction`.

**Measured** (Task 0, 2026-11-15, `ocupilot-b-ci`, USER; everything it created was removed):

- Auditing was on (`Security.System` `AuditEnabled` 1). `%CreateTermList`, `%FromObj`, `%SetValue`, an entry-node `Kill` and `%DeleteTermList` together added no row to `%SYS.Audit` (30,580 before and after), and `%DeepSee/TermList.cls` holds no audit call. OcuPilot's own `ConfigChange` row is therefore the only record, from either caller.
- USER's term list database `/durable/iris/mgr/user/` is journaled. `$ZUTIL(49, <directory>)` answers a record whose seventeenth piece is 128 for it and 4224 for a database created with `GlobalJournalState` 2; `ModifyDatabase` toggled it 128 and 4224 with `GlobalJournalState` 3 and 2, so the flag 4096 is the no-journal flag. The port reads it through `$ZUTIL(49)` because `SYS.Database` is visible only in `%SYS` (inference: a documented class would need the caller to hold `%DB_IRISSYS`).
- `TSTART`, `%SetValue` twice, a `hideValue` node set, `TROLLBACK 1` restored every node in USER. The same sequence in a namespace whose globals map to a database with journaling off (own directory `/durable/e24nj-probe/`, removed afterwards) also restored the first value and left no second node. The spec-gate ruling's premise (a `TROLLBACK` cannot undo a write in a non-journaled database) is not confirmed on this build; the ruled refusal is implemented as ruled (`deferred:`).
- Storage limits: a 255-character name stores as a header, and with a five-character field (`VALUE`) takes a key of at most 226 characters; a 60-character field takes 171; a 255-character field takes none; a 100-character or 1-character name takes a 255-character key. A process-private `^||DeepSee.TermList` probe of the same shape answered each of these exactly, so `TermListFits` is the length rule. The vendor stores the list and the field upper-cased; the key as typed.
- The throwaway's `^SYS("GREDIR","GINDTAB",16)` still names the probe directory after its database was dismounted, deleted through `SYS.Database.DeleteDatabase` and its directory removed; the Database list no longer shows it and the smoke run passes. Removing the directory before `DeleteDatabase` left the list reading Unavailable and failed three smoke checks until the database was recreated in that directory and deleted properly.
- A bare `%ToObj` of a held list answers the object and, for an absent one, an empty object with no status set; `%FromObj` with an empty value list kills nothing.

**Decided in-stage (implement).**

8. **The Term lists screen reads one header** through `GET /analytics/term-lists/form?name=`, a read of the port's `TERMLIST` type under the Term lists pairs: the list's rows carry no description, pattern, subject area, fields or hide-value flag, which Edit term list and the Add entry dialog need. The list's own read is unchanged.
9. **Screen action values are strings (AD-56)**, so Edit's field names travel as JSON array text and its hide-value flag as `true` or `false`, and Change entry's field values as JSON array text; the tools' `ScreenActionDelta` turns them into arrays.
10. **`AnalyticsTermListAction` extends `AnalyticsAction`** after the lift the Design Notes allow: `AnalyticsAction` gains a `DESTINATIONGLOBAL` parameter (default `^DeepSee.Fact`) its `PrivilegePairs` reads, and the term list tools set it to `^DeepSee.TermList`.
11. **The client does not import the Interoperability area's create helper**: `TermListStore` posts the two creates itself, for the reason the lookup pages are copied.
12. **The entry code `ANALYTICS.TERMLIST.NOFIELD`** carries the Proposed string "This term list has no field of that name."; the code list in Tasks has no name for it.
13. **The entries' agent-facing `FieldValues` merge member by member** (`OverlaidPairs`): a field a call leaves out keeps its value.

14. **Each write has a script form (AD-59).** The shared draft registry's roster (`DraftRegistry`) requires every registered write tool's port to render one; `AnalyticsPort.SnippetForm` answers `objectscript` for the six writes and `TermListSnippet` renders the vendor calls the write makes, one transaction for the multi-call writes. Found by the `(once)` sweep.

**Named limits.**

- A term list is read whole, before the field-in-use check.
- Cubes and pivots that use a list are not found or named.
- Import, export and copy are in 24.10.

## Verification

**Shared surfaces:** the rosters named under Design Notes › Contended files, plus:

- `SurfaceCoverage`, `EndpointCoverage` and `SaveHoldCoverage` rows;
- the governance baseline and the per-family disabled lists;
- `Prohibited` covered types;
- `ClassicPageGate` and `MappingDescriptor`;
- the two term-list descriptors' actions;
- the client action maps;
- the strings table and the new EXPERIENCE.md row;
- the `ci-throwaway.sh` arming roster, held by `ci.test.mjs`;
- `screen-outlet.ts`.

*Every test added or changed passes on a fresh environment, in either order.* Each test creates and removes its own marker-named lists through `AnalyticsProbe`.

**Setup (slot B, the throwaway only; never the dev instance `ocupilot-slot-b`):**

- `(loop)` **Load `src`:**
  1. `rsync -a --checksum --delete /Users/jbrandt/git/OcuPilot/.worktrees/epic-24/src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-b-ci/src/`
  2. In `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`, run `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck-d",.tErrors,1)`.
- `(loop)` **Before any browser run:** `cd ui && npm run build && docker exec ocupilot-b-ci sh -c 'cd /durable/iris/csp/ocupilot && rm -rf ./*' && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`

**Commands.** Run each in the foreground with `timeout: 600000`, one at a time. Read results from `%UnitTest_Result`.

- `(loop)` Run `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.AnalyticsTermListEdit`.
  - Then, one call each, the same runner with `--class OcuPilot.Test.AnalyticsTermListGate` and with `--class OcuPilot.Test.AnalyticsTermListRoutes`.
  - Expected: green.
- `(loop)` The same runner, in batches sized from `ui/tools/ci-timings.json` to stay under about 170 s per call. Expected: green.
  - `AnalyticsPort`, `AnalyticsGate` and `AnalyticsDescriptor`;
  - `SurfaceCoverage`, `EndpointCoverage`, `SaveHoldCoverage`, `ReadTool`, `ToolRoundTrip`, `ToolWrite`, `ToolEmit` and `ToolDispatch`;
  - `GovernanceBaseline`, `Governance`, `Prohibited`, `ClassicPageGate`, `MappingDescriptor`, `StageTwoTools` and `Descriptor`;
  - then every class the shared-surface sweep changes.
- `(loop)` `cd ui && npm run test:tools`, then `cd ui && npm run test:components`. Expected: green.
- `(loop)` `cd ui && npm run build`. Expected: green. The new pages are lazy chunks, so the initial total stays under the fixed 2,500 kB warning.
- `(loop)` `uv run scripts/check-objectscript.py <each changed .cls>` and `bash scripts/lint-docs.sh`. Expected: clean.
- `(loop)` After the redeploy, one file per call: `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<file>`. Expected: green.
  - `analytics-term-list-editor.browser-spec.mjs`
  - `analytics.browser-spec.mjs`
- `(once)` The full ObjectScript sweep: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --shard k/17` for k = 1 to 17, one per call. Expected: green.
- **Left to CI:** the full browser suite, including `a11y-structural-invariants`.

**Pinning mutations (Rule 19).** Planned here. The implement stage applies each, observes red, reverts byte-identically, and records the line.

- AC1: the create skips the case-folded existence check → `AnalyticsTermListEdit`'s name-taken leg.
- AC1: `hideValue` is not written → the create read-back leg.
- AC2: `%SetValue` drops the field argument → the entry-add leg and the browser spec.
- AC3: `TermListViolations` admits `^` in a key → the shape leg.
- AC3: `AdmitDestination` is skipped → `AnalyticsTermListGate`'s read-only leg.
- AC4: the `TROLLBACK` is removed → the partial-failure leg.
- AC5: the `ConfigChange` record is dropped on the person's path → `AnalyticsTermListRoutes`.
- AC6: the entry read drops `Fields` → the integration leg.
- AC7: the delete key ships `true` → `GovernanceBaseline`.
- AC7: one `SurfaceCoverage` row is removed → that test, alone.
- AC8: `Remove` leaves a marker list → `OnAfterAllTests`.

**Mutations run (Rule 19)** on `ocupilot-b-ci`, each reverted byte-identically and the tree recompiled:

- mutation: `TermListRefusal` answers `""` for an add whose list is held -> `AnalyticsTermListEdit` `TestANameTakenWithoutRegardToCaseWritesNothing` and `TestACreateMakesTheListAndEveryPropertyReadsBack` (its taken leg) went red.
- mutation: `VendorTermListCreate` passes 0 as the hide-value argument of `%CreateTermList` -> `TestACreateMakesTheListAndEveryPropertyReadsBack` (read-back and node legs) went red.
- mutation: `VendorTermListSetValue` drops the field argument of `%SetValue` -> `TestAChangeMovesOnlyTheHeader`, `TestAFieldInUseIsRefusedAndNothingIsWritten` and `TestAnEntryIsAddedChangedAndRemoved` went red.
- mutation: `NameShaped` admits `^` (`Quit 1`) -> `TestAShapeBreachNeverReachesTheVendor` (key leg and the nothing-written leg) went red.
- mutation: `AdmitTermList` skips `AdmitDestination` -> `AnalyticsTermListGate` `TestAReadOnlyDatabaseIsRefusedBeforeAnyVendorCall` (six legs) went red.
- mutation: the `TROLLBACK 1` in `PerformTermList` replaced by a `Set` -> `TestAFailedSecondValueWriteRollsTheEntryBack` (entry and open-transaction legs), `TestAWriteIsRefusedWhenTheDatabaseIsNotJournaled` and the class level (the open transaction) went red.
- mutation: `AuditWrite`'s `Kernel.Audit.Event.Record` call replaced by `$$$OK` -> `AnalyticsTermListRoutes` `TestThePersonsRoutesAndActionsWriteAndAreAudited` (three audit legs) and `TestTheAgentsSixProposalsConfirmAndTheEntryReadsBack` went red.
- mutation: `EntryRow` never sets `Fields` -> `AnalyticsTermListRoutes` `TestTheAgentsSixProposalsConfirmAndTheEntryReadsBack` and `TestThePersonsRoutesAndActionsWriteAndAreAudited` went red.
- mutation: `analytics.termlists.delete` shipped `true` in `Baseline.cls` -> `GovernanceBaseline` `TestThePurgeIsTheOneDisabledLine` went red.
- mutation: the `analytics.termlists.update` row removed from `SurfaceCoverage` -> `SurfaceCoverage` `TestEveryWriteToolHasACoverageRowAndBack` went red, alone.
- mutation: `AnalyticsTermListEdit.Sweep` stops deleting -> `OnAfterAllTests` ("left term lists in USER") and `TestADeleteAndARemoveTakeWhatTheyNameAndAreAudited` went red.
- mutation: `TermListForm` answers the form read as `text/plain` (`Set %response.ContentType`, a bare `Write`) -> `AnalyticsTermListGate` `TestTheRoutesAnswerJsonEnvelopesOfTheDeclaredShape` (the content-type leg) went red. Answering with no content type set reddens nothing, because the dispatch class defaults to JSON; the test's comment names the `text/plain` form.
- mutation: the entry dialog's add sends `FieldValues: []` (client rebuilt and redeployed) -> `analytics-term-list-editor.browser-spec.mjs` went red (wait timeout on the Region leg); reverted, rebuilt and redeployed, it is green.
- mutation: the entries' `TYPED_NAME_ROWS` entry dropped in `screen-action-handler.ts` (rebuilt and redeployed) -> the browser spec went red (the key typed for Remove entry is refused) and `screen-action-handler-termlist.spec.ts` (the key assertion) went red.
- mutation: `'update'` removed from the Term lists' `UNDRAWN_ACTIONS` entry, and `'set'` from the entries' -> the browser spec stayed green, because the page registers after the handler; the new `screen-action-handler-termlist.spec.ts` pins each (the registration leg) and went red for each. Its list-side `TYPED_NAME_ROWS` entry is not pinned: the list's name is its id, so dropping that entry changes nothing a test or a person can see.
- mutation: the Term lists' `DESTRUCTIVE_CONSEQUENCES` entry dropped -> `screen-action-handler-termlist.spec.ts` (the registration and the consequence legs) went red.
- mutation: the `TSTART` of the property change removed in `PerformTermList` -> `AnalyticsTermListEdit` `TestAFailedSecondValueWriteRollsTheEntryBack` (the failed hide-value leg) went red, with two more that rely on the transaction.
- mutation: `DestinationJournaled` always answers journaled -> `AnalyticsTermListEdit` `TestAWriteIsRefusedWhenTheDatabaseIsNotJournaled` (the temporary-database leg, a real database with journaling off) went red.
- mutation: `AnalyticsTermListAction.RuleProblem` quits before its checks -> `AnalyticsTermListRoutes` `TestAMintRefusesWhatTheWriteWouldRefuse` went red on the update, unknown-field, key and absent-list legs.
- mutation: `OverlaidPairs` keeps no field the call leaves out -> `AnalyticsTermListRoutes` `TestTheAgentsSixProposalsConfirmAndTheEntryReadsBack` (the read-back leg) went red.
- mutation: `%DeepSee_PortalEdit:USE` removed from `TERMLISTPAIRS`, from both term list descriptors and from `AnalyticsAction.PrivilegePairs` together -> `AnalyticsTermListGate` `TestEachWriteIsRefusedNamingTheFailedPair` (the first principal's legs) went red. Dropping the port's pair or the tool's WRITE pair alone reddens nothing: each pair is enforced at several layers.
- mutation: `Modified` dropped from `AnalyticsTermListDelete.FINGERPRINTSUBJECT` -> `AnalyticsTermListRoutes` `TestAConfirmAfterTheListChangedIsRefusedAsMoved` went red.
- mutation: the `/analytics/term-lists/form` probe row removed from `EndpointCoverage` -> that test went red (207 probes, 208 routes).
- mutation: `analytics.termlistentries.add` removed from `MappingDescriptor.CLASSICROSTER` -> `TestTheClassicPagesRosterIsTheDeclaringTools` went red.
- mutation: the hold key of `ItemSave` made different from the mint's -> `SaveHoldCoverage` `TestACreateSaveHoldsTheKeyItsMintComputes` went red on the term list and the term list entry legs.
- mutation: the `AnalyticsTermListEntryMint` row removed from `CompositeMintSweep.Roster` -> `TestTheRosterIsEveryCompositeIdMint` went red, alone (found by the `(once)` sweep, which also found the missing script forms).
- mutation: the field argument of the value write dropped in `AnalyticsPort.TermListSnippet` -> `AnalyticsTermListEdit` `TestEachWritesScriptFormMakesTheSameChange` (the entry add, change and property change legs) went red; the `Kill` of the entry removal dropped there -> its removal leg went red.
- mutation: `this.reason.set(...)` blanked in `term-list-dialog.ts`, then in `term-list-entry-dialog.ts` (client rebuilt and redeployed each time) -> `analytics-term-list-editor.browser-spec.mjs` AC3 went red for each; both reverted, rebuilt and redeployed.

## Auto Run Result

Status: done
Blocking condition: none

This pass applied the runner's ruling, ran the unrun mutations, reviewed the whole story, patched, ran the `(once)` sweep and finalized.

**Summary.** The term-list editor: six write tools through `AnalyticsPort` (create, change, delete of a list; add, change, remove of an entry), each reached by the person's two screens and the agent's confirmed proposals, gated, shape-checked, transactional where it makes several vendor calls, audited and governed. The ruling is applied: the two empty-state phrases are `create a term list` and `add an entry to this term list` (`strings.ts`, the EXPERIENCE.md row), rendered by the table's own wrapper; the `NOTJOURNALED` refusal stays as ruled and the medium stays in `deferred:`.

**Files changed.**

- `src/OcuPilot/Port/AnalyticsPort.cls`: the term list reads and writes, `TermListViolations`, the gates, the vendor seams, and (this pass) the script form `TermListSnippet`.
- `src/OcuPilot/Api/AnalyticsError.cls`, `Api/Router.cls`, `Area/Analytics/TermList{Save,EntrySave,Form}.cls`: the refusal codes and the three routes.
- `src/OcuPilot/Screen/Tool/AnalyticsTermList*.cls` and `AnalyticsAction.cls`: the six tools and their bases, with the destination parameter lifted.
- `src/OcuPilot/Screen/Descriptor/AnalyticsTermList{List,EntryList}.cls`, `Kernel/Governance/Baseline.cls`, `Kernel/Proposal/Prohibited.cls`: actions, six keys, covered types.
- `src/OcuPilot/Test/AnalyticsTermList{Edit,Gate,Routes,Seam}.cls` and the shared rosters (`SurfaceCoverage`, `EndpointCoverage`, `SaveHoldCoverage`, `ToolEmit`, `ClassicPageGate`, `MappingDescriptor`, `GovernanceBaseline`, `Governance`, `Prohibited`, `ReadTool`, `ToolWrite`, `ToolRoundTrip`, `ToolDispatch`, `AnalyticsDescriptor`, and this pass `CompositeMintSweep`).
- `ui/src/app/areas/analytics/term-list*.ts`, `ui/src/app/shell/{screen-action-handler,screen-outlet}.ts`, `ui/src/app/core/{strings,screen-actions,proposal-view,screens.generated}.ts`: the pages, dialogs, store, maps and strings; this pass `screen-action-handler-termlist.spec.ts`.
- `ui/tools/analytics.test.mjs`, `ui/browser/analytics-term-list-editor.browser-spec.mjs` (AC3 added), `ui/browser/analytics.browser-spec.mjs`, `scripts/ci-throwaway.sh`, EXPERIENCE.md (one new row).

**Review.** Two layers, 16 findings: high 0, medium 5, low 8, false 3. Patched: the mint's refusals (test), the journaling refusal against a real database with journaling off (leg), the property change's transaction (leg and seam mode), the overlay of an omitted field (leg), the dialogs' refusal rendering (browser leg), and the mutations named but not recorded (run and recorded, with a comment corrected). Rejected: seven low findings and three false, each with its reason in the Review Triage Log. Deferred: none new; the one medium from the ruling stays.

**Found by the `(once)` sweep and fixed in-pass.** `DraftRegistry` requires a script form for every write tool: `AnalyticsPort.SnippetForm` and `TermListSnippet` now render the six writes, pinned by `TestEachWritesScriptFormMakesTheSameChange` (each script run in `USER` and read back). `CompositeMintSweep` requires a row for every composite-id mint: one row added.

**Follow-up review recommended: true.** Five medium findings were patched on this first pass. The unverified risk: the script form (`TermListSnippet`) and the new test legs were written after the review layers read the diff and have had no second read.

**Verification.** On `ocupilot-b-ci`: the three new classes, `AnalyticsPort`, `AnalyticsGate`, `AnalyticsDescriptor` and the shared-surface batches green; all 17 shards of `ci-runner.mjs --shard k/17` green on the final tree (shards 1 to 10 re-run after the last source patch; shard 11 found the script-form gap and shard 16 the mint roster, both fixed, then green); `npm run test:tools` 2283 green; `npm run test:components` 272 files, 3441 tests green; `npm run build` green with the new pages in lazy chunks; `check-objectscript.py` clean; `lint-docs.sh` clean; `analytics-term-list-editor` (2 tests) and `analytics` (5 tests) browser specs green on the redeployed final bundle. Matrix Test Audit: every matrix row has a test that ran green. Mutations: 28 recorded under Verification, each reverted and recompiled; the client ones rebuilt and redeployed. A client build that fails its lint step leaves the old bundle in place, so every client mutation was checked to have built before its result was read. `AnalyticsProbe.Gone()` is true and no marker list remains.

**Residual risks.**

- The refusal for a database with journaling off rests on a premise this build contradicts (a `TROLLBACK` undid a write there); it stays as ruled, in `deferred:`.
- The Change entry dialog prefills each field from the row's joined `Fields` text, which mis-splits a value holding `; <next field>: ` (rejected as low).
- The Term lists list-side `TYPED_NAME_ROWS` entry is not pinned, because the list's name equals its id.
