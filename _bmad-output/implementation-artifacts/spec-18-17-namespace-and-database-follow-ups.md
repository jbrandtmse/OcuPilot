---
title: 'Story 18.17: Namespace and database follow-ups'
type: 'bugfix'
created: '2026-09-30'
baseline_revision: 'c771e4678918b9c24b19604b92dd3d04a0356fe1'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-18-context.md'
warnings: ['oversized', 'multiple-goals']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Three follow-ups to shipped Epic 18 screens, split from Story 18.15 for release 1.0.5:

- DW-1813: a global mapping whose global part begins with `:` (an empty low end, which the instance reads as `%`) or `*` reaches the `%` globals, yet neither the agent's proposal nor the global mapping form states the system-global consequence that a name beginning with `%` carries.
- DW-1824: the New Namespace form's Create a database leaves the form, discards what was typed, lands on the new database's editor and never returns.
- DW-1858: the Integrity log has no side-bar position, so a past check is reachable only by running a new one.

**Approach:**

- DW-1813 widens the kernel's one system-global predicate, which both callers already read, and its client mirror in the form.
- DW-1824 carries the New Namespace form across the database wizard and back through the router, with a closed return marker.
- DW-1858 lists the Integrity log right after Databases.

There is no admin-API write, no new tool and no observation step before the build.

## Boundaries & Constraints

**Always:**

- **DW-1813, one rule.** A global mapping reaches the `%` globals when its name begins with `%`, or when its global part (the text before any `(`) begins with `:` or `*`.
  - The kernel's `IsSystemGlobalMapping` decides the effect `MAPPING.SYSTEMGLOBAL` for both callers (AD-10, AD-53). The agent's mint already asks it on a create and a change of a global mapping, never on a removal.
  - The form's `systemGlobal()` mirrors the rule only to decide whether the published line shows.
  - It is permitted at the strongest confirmation, exactly as a `%` name is. Nothing is refused.
- **DW-1824, through the router (AD-19).**
  - New Namespace in create mode opens the wizard with the closed marker `returnTo=namespace`. That is the only value honored, and it is never a URL (AD-47).
  - Opened with the marker, the wizard's Create and Cancel replace the route with New Namespace carrying `kept=1`. Create also carries `database=<created name>`.
  - New Namespace restores its own retained buffer, then chooses that database as Globals when its re-read list holds it. It compares ignoring case and keeps the list's spelling.
  - Neither page reads or writes the other's store, and no store reads the route.
- **The restored form is dirty, so leaving it asks.** The page drops `kept` and `database` from the URL before the restore, while the form is still clean, so the leave guard does not fire on that replacement.
- **DW-1858.** `DatabaseIntegrityLog` takes `sideBarPosition` 5, and the six listed screens after it each move up by one: `DeviceList` 6, `NamespaceList` 7, `LicenseSummaryTab` 8, `Dashboard` 9, `LanguageServerList` 10 and `LocalDatabaseList` 11. Every pin is re-derived from the code and its class's red, never hand-counted.
- **Probes** carry the prefix `OCUPROBE1817` and run on `ocupilot-b-ci` only. No test confirms a `:` or `*` mapping; it only mints one.
- **Contended files (Rule 11):** see Design Notes › Footprint.
  - `Prohibited.cls` takes inserted lines only.
  - EXPERIENCE.md is edited in place and keeps 993 lines.
  - `screens.generated.ts` is regenerated, never hand-merged.

**Never:**

- No new tool, governance key, port branch, `QUEUEDWRITES` entry, error code, route, dialog or string.
- No edit to `Api/Error.cls`, `Api/Router.cls`, `Kernel/Governance/Baseline.cls`, `Port/AdminPort.cls`, `Screen/Registry.cls`, `Screen/Read.cls`, `Screen/Tool/*` or `ToolFields.cls`.
- No interoperability work of any kind. It stays with Story 18.15, after release 1.0.5.
- No hand-off from Edit Namespace's link, and no return for a wizard opened any other way.
- No stop, restart, recreate, `up` or `down` of `ocupilot-b-ci` or any other container. No spine edit.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
| --- | --- | --- | --- |
| `%` reach, agent (DW-1813) | A global mapping create in a probe namespace named `:A`, `:`, `*` or `*X`, or an edit of such a mapping | Minted destructive with consequence `MAPPING.SYSTEMGLOBAL`, as `%X` and `%X("a")` already are | effect, permitted |
| `%` reach, form (DW-1813) | A person types `:A` or `*` in the global mapping form's Name | The system-global line shows under Name, and Name is described by it | none |
| No `%` reach (DW-1813) | `A:`, `A:Z`, `X*`, `G("%a")` or `G(":")`; a routine mapping `:A`; a delete of `:A` | No `MAPPING.SYSTEMGLOBAL` effect and no line. A delete stays destructive as a delete | none |
| Create a database (DW-1824) | New Namespace with Name and Routines typed, then Create a database, then the wizard's Create of `OCUPROBE1817W` | No leave prompt. Back on New Namespace with a URL carrying neither `kept` nor `database`. Name and Routines are as typed, Globals reads `OCUPROBE1817W`, and the form is dirty | none |
| Wizard Cancel (DW-1824) | The same hand-off, then Cancel in the wizard | Back on New Namespace with what was typed. Globals is unchanged | a dirty wizard asks first, as today |
| Wizard elsewhere (DW-1824) | The wizard opened from Local databases, from Edit Namespace's link, or with any other `returnTo` value | Unchanged: Create opens the new database's editor, and Cancel opens Local databases | none |
| No kept buffer (DW-1824) | New Namespace opened with `kept=1` and nothing retained, as after a reload or a new tab | An empty create form, with Globals set to `database` when the list holds it | none |
| Not listed (DW-1824) | The created name is absent from the re-read list | Globals keeps what was typed | none |
| Side bar (DW-1858) | OS management for a holder of `%Admin_Operate:USE` and `%DB_IRISSYS:READ` | Processes · Locks · System usage · Databases · Integrity log · Devices · Namespaces · License usage · Dashboard · External language servers · Local databases. Integrity log opens the log | A non-holder sees the entry `aria-disabled` and naming the pair, as for every entry |
| Integration (DW-1824) | A real browser and instance. The wizard opened from New Namespace creates `OCUPROBE1817W` | New Namespace's Globals select holds the database the instance just created. The wizard's created name reaches the consumer only through the router query | none |

</intent-contract>

## Code Map

**DW-1813, kernel** (`src/OcuPilot/Kernel/Proposal/`):

- `Prohibited.cls` (Epic 16 also changes this file, so edits are add-only):
  - `EFFECTSYSTEMGLOBAL`: doc at :506-508, parameter at :509.
  - `WeakensByEffect`: doc at :1383-1386. Its global-mapping arm (:1392-1394) answers the effect when `'pRemoves && IsSystemGlobalMapping(pId)`. A routine type falls through to `""`.
  - `IsSystemGlobalMapping` (:2411-2418) splits the composite id with `EntityId.SplitComposite` and tests only `$Extract(name) = "%"`.
- `Mint.cls:325-337` asks `WeakensByEffect` on every global-mapping create and change. It then sets `destructive` and `consequence` from the answer, so the agent's card follows the predicate with no change here.
- `irissys/NSPMAP.int` `oneglob` (read-only): `$Piece(glob1,"*")` at :48 leaves an empty stem for a leading `*`. At :54 an empty stem becomes `%`, with an open upper end. So `:A`, `*` and `*X` reach the `%` globals (DW-1813's evidence measured `:A` moving `^%zz`).

**DW-1813, client** (`ui/src/app/areas/os-management/`):

- `mapping-form.store.ts`: `systemGlobal()` at :262-264, doc at :257-261. Today it is `kind === 'global' && name.startsWith('%')`.
- `mapping-form.page.ts`: the line is drawn at :129-131 (create) and :147-149 (edit). The getter is at :292-296, with a doc saying "a `%` global's", and `nameField` adds `-effect` to `aria-describedby` at :349-353.
- `core/proposal-view.ts:196,238` maps the code to the same string. No change.

**DW-1824** (`ui/src/app/areas/os-management/`):

- `namespace-form.page.ts` (494 lines):
  - Constructor :240-262. It opens with `routeId()` (:447-450), the `NavigationEnd` follower is at :246-252, and the destroy hook (:254-261) resets unless `store.retaining()`.
  - `databaseFields` :366-377 draws the link beside Globals in both modes. `createDatabaseLink` :379-385 is `withQuery(wizard.route, router.url)`, and `onCreateDatabase` :425-435 navigates to it.
  - `NAMESPACE_FORM_ROUTE` is at :29.
  - The query-read model is `mapping-form.page.ts:425-431` (`routeNamespace`).
- `namespace-form.store.ts` (559 lines):
  - `retaining()` :254-257, `retainAcrossRouteReplacement()` :259-262, `reset()` :266-289 (it also calls `formDirty.reset()`), and `open(name)` :291-312.
  - `onChange` :421-426 re-reads the databases on a `database-configuration` created or deleted event while loaded.
  - `absorb` :494-529: the databases are set at :512, and a create's buffer is set at :513-517.
- `database-wizard.page.ts` (614 lines):
  - The destroy hook :293-297 resets its store, which resets `FormDirty`.
  - `onCreate` :533-542 replaces the route with `editorUrl(name)` (:609-613), and `cancel` :555-557 opens Local databases.
  - `LOCAL_DATABASE_FORM_DESCRIPTOR` and `LOCAL_DATABASE_FORM_ROUTE` are exported at :38 and :41. The store sets the form clean on Create (`database-wizard.store.ts:438`).
- `database-actions.ts` holds the OS management database route constants (:8-23), which both pages can import.
- `core/navigation.ts:696-704`: `withQuery` keeps only `ns`. `core/form-dirty.ts` is the one dirty flag, and `app.routes.ts:24` is the guard on every form page.

**DW-1858** (`src/OcuPilot/Screen/Descriptor/`):

- `DatabaseIntegrityLog.cls`: `sideBarPosition` 0 at :27. Its doc at :14-15 says "It takes no side-bar position: the Check integrity flow opens it."
- The current positions are `ProcessList` 1, `LockList` 2, `SystemUsage` 3, `DatabaseList` 4, `DeviceList` 5, `NamespaceList` 6, `LicenseSummaryTab` 7, `Dashboard` 8, `LanguageServerList` 9 and `LocalDatabaseList` 10. Positions must be whole numbers (`Registry.cls:508-531`).
- Doc ordinals that go stale:
  - `DatabaseList.cls:4` ("between System usage and Devices");
  - `DeviceList.cls:4` ("fifth and last ... after Databases");
  - `NamespaceList.cls:5` ("sixth");
  - `LicenseSummaryTab.cls:5-6` ("seventh");
  - `LocalDatabaseList.cls:5` ("tenth").
- Area verdicts are unchanged. An area opens when any listed screen admits the caller (`Registry.ListedScreensForArea` :3340-3360), and `LockList` already declares the Integrity log's two pairs.

**Pins to re-derive for DW-1858** (from each class's red):

- ObjectScript (`src/OcuPilot/Test/`):
  - `Navigation.cls:459-480`: the 30 screens stay 30, the unlisted count goes from 20 to 19, and the per-index list and its comment change.
  - `Descriptor.cls:2288` (Devices), `DeviceWriteGate.cls:200`, `NamespaceWriteGate.cls:144`, `NamespaceDescriptor.cls:26`, `LicenseUsage.cls:110`, `Dashboard.cls:108` and `LanguageServer.cls:66`.
  - `DatabaseDescriptor.cls`: :25-33 (`TestTheListIsOsManagementsTenthEntryKeyedByName`) and :265-278 (`TestTheIntegrityScreensAreBuiltUnlisted`, whose log case reads `|log-viewer|0`).
  - `SurfaceCoverage.cls`: :82 and :135-136 name those two methods.
  - `Wire.cls:694-701` and `WireSecurityRead.cls:540-566`: the full os-management screen JSON for each principal, with its comment.
- Client (`ui/`):
  - `tools/navigation.test.mjs`: the built-screens roster at :152-192 (`integrity-log` at :155 moves into the listed block after `os-management/databases` at :182), and the listed test at :256-280 (its title and comments).
  - `tools/navigation-wire.test.mjs:115-305` and `src/app/shell/rail-wire.spec.ts:120-310`: the live-payload fixtures. They are copies of `Wire.cls`'s string, and they move together with it.
  - `browser/namespaces.browser-spec.mjs:367-386` (the side bar, "sixth"), `license-usage.browser-spec.mjs:126-141` and `local-databases.browser-spec.mjs:1-12,483-496` ("tenth").
- `language-servers.browser-spec.mjs:325-346` and `LanguageServerWire.cls:240-262` stay green, because their principals hold both pairs (inference from their role strings at :97 and :443).

**EXPERIENCE.md** (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`, 993 lines). Epic 16 changes :173, :363, :490 and :504-507, and none of the lines below:

- :164: the OS management side-bar row.
- :375: License usage is "the seventh" entry and the Dashboard "the eighth".
- :377: Local databases is "the tenth"; the clauses "the New Namespace form's link beside its globals select" and "the Integrity log's title".
- :378: Devices is "the fifth" and Namespaces "the sixth"; the clause "the consequence a global mapping whose name begins with % states under Name".
- :584: External language servers is "the ninth".

**Test models:**

- `Test/MappingWrite.cls` (485 lines, armed by `OCUPILOT_ALLOW_NAMESPACE_CONFIG`):
  - `TestASystemGlobalMappingIsPermittedAtTheStrongestConfirmation` :256-276. It mints through `..Mint` and reads `..Marked` (:472-477) as `destructive|consequence`, with probe namespace `..#NS` `OCUPROBE1814A`.
  - :363-373 already mints `*`, `:` and `:A` with status OK, so the mint's fresh read accepts those names.
- `Test/MappingProbe.cls:218` `Id(ns, name)` builds a composite id.
- Client spec models:
  - `mapping-form.store.spec.ts:192-203` (the AD-10 test);
  - `namespace-form.page.spec.ts:246-257` (the Create a database link, which expects `/os-management/local-databases/edit`);
  - `namespace-form.store.spec.ts:208-219` (retained create);
  - `database-wizard.page.spec.ts:229-256` (Create replaces the route, asserted with `vi.spyOn(router, 'navigateByUrl')`).
- `ui/browser/local-databases.browser-spec.mjs`:
  - `DATABASES` :75 drives the cleanup, `noneSurvives` and `probeDirectories` (:160-190).
  - The wizard drive is at :502-527, with `chooseManagerRoot` :445-452, `nextTo` :461-468 and `sideBarOf` :286-300.
- `ui/browser/namespace-mappings.browser-spec.mjs:350-356` is the `%OcuProbe1814` form-line leg.

## Tasks & Acceptance

**Execution: DW-1813:**

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`, add-only:
  - In `IsSystemGlobalMapping`, insert before its last `Quit`:

    ```objectscript
        Set tGlobal = $Piece($ListGet(tParts, 2), "(")
        If ($Extract(tGlobal) = ":") || ($Extract(tGlobal) = "*") Quit 1
    ```

  - Insert one `///` paragraph after each of the doc comments of `IsSystemGlobalMapping`, `EFFECTSYSTEMGLOBAL` and `WeakensByEffect`. It says that a name whose global part begins with `:` (an empty low end, read as `%`) or `*` reaches the `%` globals too.
- `ui/src/app/areas/os-management/mapping-form.store.ts`: `systemGlobal()` returns true for kind `global` when the name begins with `%`, or when the text before its first `(` begins with `:` or `*`. Its doc comment states the same rule.
- `mapping-form.page.ts:292`: the getter's doc reads "Whether the name reaches the `%` globals".

**Execution: DW-1824:**

- `ui/src/app/areas/os-management/database-actions.ts`: export the hand-off vocabulary with one doc line each:
  - `RETURN_PARAM = 'returnTo'` and `RETURN_TO_NAMESPACE = 'namespace'`;
  - `KEPT_PARAM = 'kept'` and `CREATED_DATABASE_PARAM = 'database'`.
- `namespace-form.store.ts`:
  - Add `retainForHandOff()`. It keeps a copy of the create buffer, then calls `formDirty.setDirty(false)`.
  - `retaining()` also answers true while that copy is held, and `reset()` drops it. The sign-out teardown therefore forgets it.
  - `open(name, returning?: { readonly database: string })`. With `returning` and an empty name, capture the held copy before `reset()`. After `absorb`, the buffer is that copy (or empty).
  - Globals becomes the list's spelling of `returning.database` when the list holds it, ignoring case. `opened` stays empty, and the form is marked dirty when the buffer differs from empty.
  - Without `returning`, `open` behaves as today.
- `namespace-form.page.ts`:
  - In create mode, `createDatabaseLink` appends `returnTo=namespace` to its `url` and `href` (`?` or `&` after `withQuery`). Edit mode is unchanged.
  - In create mode only, `onCreateDatabase` calls `store.retainForHandOff()` before navigating.
  - The constructor reads `kept` and `database` from `router.url`, on the `routeNamespace` model. When `kept` is `1` and the id is empty, it first replaces the URL with `withQuery(NAMESPACE_FORM_ROUTE, router.url)` (`replaceUrl`), then opens with `{ database }`. Otherwise it opens as today.
- `database-wizard.page.ts`: read `returnTo` from `router.url`; only `namespace` is honored.
  - Create navigates (`replaceUrl`) to `withQuery(NAMESPACE_FORM_ROUTE, router.url)` plus `kept=1&database=<encodeURIComponent(created name)>`.
  - Cancel does the same with `kept=1` only.
  - Without the marker, both behave as today. Import `NAMESPACE_FORM_ROUTE` from `./namespace-form.page`; that page imports nothing from the wizard.

**Execution: DW-1858:**

- `DatabaseIntegrityLog.cls`: set `sideBarPosition` 5. Its doc sentence becomes "It is OS management's fifth side-bar entry, right after Databases, and the Check integrity flow also opens it."
- `DeviceList`, `NamespaceList`, `LicenseSummaryTab`, `Dashboard`, `LanguageServerList` and `LocalDatabaseList`: each position plus one. Replace each stale ordinal sentence in the Code Map, `DatabaseList.cls:4` included, with the new ordinal and neighbour.
- Regenerate with `cd ui && node tools/screen-mirror.mjs`, then update every pin in the Code Map.
- Rename `DatabaseDescriptor`'s `TestTheListIsOsManagementsTenthEntryKeyedByName` to `TestTheListIsOsManagementsEleventhEntryKeyedByName`, and `TestTheIntegrityScreensAreBuiltUnlisted` to `TestTheIntegrityScreensAreBuilt`. Update `SurfaceCoverage.cls`'s three `method=` attributes to match.

**Execution: EXPERIENCE.md (in place, still 993 lines):**

- :164: the third cell begins "Integrity log (Stage 2, Story 18.17: listed right after Databases) · ".
- :375, :377, :378 and :584: each OS management ordinal moves up by one, from fifth through tenth.
- :377:
  - "the New Namespace form's link beside its globals select" gains ", which opens the wizard and, on its Create or Cancel, returns to the form with what was typed and the created database chosen as its globals database (Story 18.17)".
  - "the Integrity log's title" becomes "the Integrity log's side-bar entry, right after Databases (Story 18.17), and its title".
- :378: "a global mapping whose name begins with %" becomes "a global mapping whose name, pattern or range reaches the % globals (its name begins with %, : or *, Story 18.17)".

**Tests:**

- `src/OcuPilot/Test/MappingSystemGlobal.cls` (new, stateless, under 100 lines). It builds ids with `MappingProbe.Id("OCUPROBE1817A", name)` and asserts `IsSystemGlobalMapping` and `WeakensByEffect("global-mapping", {}, {}, .e, id, 0)`:
  - 1 and `MAPPING.SYSTEMGLOBAL` for `%X`, `%X("a")`, `:A`, `:`, `*` and `*X`;
  - 0 and `""` for `A:`, `A:Z`, `X*`, `G("%a")` and `G(":")`;
  - `""` for `:A` with `pRemoves` 1, and for type `routine-mapping`.
- `MappingWrite.cls`: a new method mints, without confirming, global mapping creates in `..#NS`. `:OcuProbe1817` and `*` read `"1|MAPPING.SYSTEMGLOBAL"`, and the range `OcuProbe1817A:OcuProbe1817Z` reads `"0|"`. A routine create of `:OcuProbe1817R` reads `"0|"`. Each name has a shape the class's own legs already mint with status OK (:363-373, :393-396).
- Client specs:
  - `mapping-form.store.spec.ts`: the AD-10 test gains `:A`, `*` and `*X` (true) and `A:`, `G(":")` (false).
  - `namespace-form.store.spec.ts`:
    - `retainForHandOff`: retaining, and the form left clean;
    - `open('', { database })`: the buffer restored, Globals in the list's spelling, and the form dirty;
    - an unlisted database: Globals as typed;
    - an open without `returning`: reset;
    - `reset()`: drops the held copy.
  - `namespace-form.page.spec.ts`:
    - the link's expectation becomes `/os-management/local-databases/edit?returnTo=namespace`;
    - an edit's link carries no marker;
    - an arrival with `?kept=1&database=X` replaces the URL without them, then shows the restored values.
  - `database-wizard.page.spec.ts`:
    - with the marker, Create navigates to `/os-management/namespaces/edit?ns=USER&kept=1&database=OCUPROBE183A` (`replaceUrl`), and Cancel to `…?ns=USER&kept=1`;
    - `returnTo=elsewhere` and no marker behave as today.
  - `navigation.test.mjs`, `navigation-wire.test.mjs` and `rail-wire.spec.ts`, per the Code Map.
- Browser:
  - `namespace-mappings.browser-spec.mjs`: after the `%OcuProbe1814` step, retype Name `:OcuProbe1817`. The line shows. Then retype `OcuProbe1817:` and the line is gone, before the existing retype to `CREATED`.
  - `local-databases.browser-spec.mjs`:
    - add `OCUPROBE1817W` to `DATABASES`;
    - correct header point 1's ordinal and add a point for DW-1824;
    - in the side-bar test, Integrity log follows Databases, as the eleventh entry;
    - a new DW-1824 test from `/ocupilot/os-management/namespaces/edit?ns=HSCUSTOM`: type Name `OCUPROBE1817N` and choose Routines `USER`, choose Create a database, and expect no leave dialog and a URL carrying `returnTo=namespace`;
    - then create `OCUPROBE1817W` under the manager root. It is back on New Namespace with `kept` and `database` absent from the URL, Name and Routines as typed, and Globals `OCUPROBE1817W`, which `configured()` confirms exists;
    - then Create a database again and Cancel the wizard. Back with the same values. Cancel New Namespace and answer the leave dialog. No namespace is created.
  - `namespaces.browser-spec.mjs`: the side-bar assertion reads seven entries with Integrity log after Databases. Clicking it lands on `os-management/databases/integrity-log` with the log viewer drawn.
  - `license-usage.browser-spec.mjs`: the eleven-entry list.

**Acceptance Criteria:**

- **AC1 (DW-1813, agent):** Given a probe namespace, when the agent proposes a global mapping create named `:A` or `*`, then the proposal is minted destructive with consequence `MAPPING.SYSTEMGLOBAL`, as a `%` name's is, and one named `A:` is not.
- **AC2 (DW-1813, form):** Given the global mapping form, when a person types `:A` or `*` in Name, then the system-global line shows under Name. When the name becomes `A:`, the line is gone.
- **AC3 (DW-1824):** Given New Namespace with a Name and Routines typed, when the person chooses Create a database and creates a database in the wizard, then no leave prompt appears and they are back on New Namespace with Name and Routines kept and the new database chosen as Globals. When they cancel in the wizard instead, they return with what was typed and Globals unchanged.
- **AC4 (Integration, DW-1824):** Given the real throwaway in a browser, when the wizard opened from New Namespace creates a database, then New Namespace, the consumer, shows in its Globals select the database the instance holds under that name. The hand-off is the router query alone.
- **AC5 (DW-1858):** Given OS management's side bar for a holder of the Integrity log's pairs, when it is drawn, then Integrity log is listed right after Databases, every other entry keeps its relative order, and choosing Integrity log opens the Integrity log.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:**

- AD-10: DW-1813's widening. The spine's own-mappings bullet already carries the rule (amended 2026-10-01).
- AD-53 and AD-55: one kernel predicate for both callers.
- AD-5: the side-bar position in the descriptor and the regenerated mirror. AD-8: area verdicts over listed screens.
- AD-19: the router hand-off, with no store reaching another. AD-47: a closed marker, never a URL.
- AD-13: the created name as one encoded query value. AD-14: the form's database choices re-read on the change bus.

No spine amendment: AD-10 already states DW-1813, and nothing here changes an AD's Rule.

**Decisions:**

- **DW-1813 lives once, in the kernel.** The mint already asks `WeakensByEffect` for every global-mapping create and change (`Mint.cls:325-337`), so widening `IsSystemGlobalMapping` covers the agent's create, its edit and every later caller. The client copy only shows the published line.
- **DW-1824 is the create form only.** The ledger and the criterion name New Namespace, whose classic page (`%CSP.UI.Portal.Namespace`) offers the popup. Edit Namespace's link keeps today's behavior.
- **The URL is stripped before the restore.** The guard reads one shared dirty flag. The wizard's destroy has already reset that flag, so the replacement passes while the form is clean, and the restore then marks it dirty.
- **Browser Back** from the wizard is history: it reopens New Namespace without the marker, which starts empty, as today. Both returns use `replaceUrl`, so Back from the restored form never re-enters the wizard.
- **DW-1858 shifts six positions,** because positions are whole numbers.
- **The two `DatabaseDescriptor` methods are renamed,** because their names would state a position or an unlisted status that no longer holds.

**Footprint, for the spec gate (Rule 11).** Epic 16's branch (`OCU-1-epic16`, tree clean, checked 2026-09-30) changes these files that this story edits:

- **Add-only or in place, with no overlap:**
  - `Prohibited.cls` takes inserted lines only.
  - EXPERIENCE.md is edited in place. This story touches rows :164, :375, :377, :378 and :584; Epic 16's hunks are at :173, :363, :490 and :504-507.
  - `screens.generated.ts` is regenerated.
- **Two non-add-only edits need the gate's approval:**
  - `ui/tools/navigation.test.mjs`: the `integrity-log` line moves from :155 to the listed block at :182, and the OS management titles and comments at :185-191 and :256-279 are updated. Epic 16's hunks are in Security, at :217-222 and :359-363.
  - `src/OcuPilot/Test/SurfaceCoverage.cls`: three `method=` attributes at :82 and :135-136. Epic 16's hunks are at :139 and :249-251, with two unchanged lines between this story's and theirs.
  - If the gate refuses the second, the two methods keep their names and only their assertions change.

**Prior art.** Story 18.15's spec (status `blocked`, now the enable's alone) planned these three items on 2026-09-30. This spec lifts its DW-1813, DW-1824 and DW-1858 execution, matrix rows, tests and pins, with every cited line re-checked against `c771e467`. It carries nothing about the enable.

**Integration ACs:** AC4 is pinned by the `local-databases` browser leg on the real throwaway. The New Namespace form consumes the wizard's created name through the router and shows it as Globals. AC1 is pinned by `MappingWrite`, where the agent's mint consumes the kernel predicate on the instance.

**Consumes:**

- 18.2: the New Namespace form page and store.
- 18.3: the database wizard and its `createdId`.
- 18.14: `Prohibited.WeakensByEffect`, `IsSystemGlobalMapping`, the mint's ask and the form's `systemGlobal()`.
- 18.4: `DatabaseIntegrityLog`.
- Story 3.5: the side-bar position rule.

**Consumed-by:**

- 18.16: its planned `RemoteDatabaseList` position 11 is `LocalDatabaseList`'s after this story, so 18.16 takes 12. Its spec, `ready-for-dev`, names 11, and the runner re-bases it before 18.16's implement.
- No other consumer in this epic.

**Ledger inbox (Rule 17):**

- DW-1813 is addressed by its tasks, AC1, AC2 and the matrix's three DW-1813 rows.
- DW-1824 by its tasks, AC3, AC4 and the matrix's five DW-1824 rows.
- DW-1858 by its tasks, AC5 and the side-bar row.
- DW-1774 is met by the DW-1858 pins.

## Verification

**Setup (slot B):**

- Load code with `/tmp/epic-18-d4/load-throwaway.sh` only, never the MCP loader, which reaches the dev instance. MCP calls carry `server: "ocupilot-slot-b"`.
- Every probe stays on `ocupilot-b-ci`, which is never restarted.
- If a class's arming variable reads unset there, arm it per call with `docker exec -e <VAR>=1`, using the variable its header names.
- Run one test class per call, and wait until each run has landed in `%UnitTest_Result`.
- Before any browser run: `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci` exported.

**Commands:**

- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`, one call at a time. Expect 0 failures each, with totals checked against `%UnitTest_Result`. The classes:
  - `MappingSystemGlobal`, `MappingWrite`, `DatabaseDescriptor` and `SurfaceCoverage`;
  - `Navigation`, `Descriptor`, `NamespaceDescriptor`, `DeviceWriteGate`, `NamespaceWriteGate`, `LicenseUsage`, `Dashboard`, `LanguageServer`, `Wire` and `WireSecurityRead`.
- `(loop)` `cd ui && node --test --test-concurrency=1 browser/namespace-mappings.browser-spec.mjs browser/local-databases.browser-spec.mjs browser/namespaces.browser-spec.mjs browser/license-usage.browser-spec.mjs`. Expect a pass.
- `(loop)` `cd ui && npm run test:tools && npm run test:components`, then `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh`. Expect clean, with `wc -l` on EXPERIENCE.md reading 993.
- `(once, before dev_complete)`:
  - the full ObjectScript sweep, `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, one class at a time;
  - then `cd ui && npm test && npm run build`;
  - then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`.
  - Expect green with a non-zero count.
- `(CI)` The full browser suite runs in CI's three browser shards (Rule 29), not locally.

**Planned pinning mutations (Rule 19).** Apply each to the throwaway's loaded source, or to a rebuilt and redeployed bundle. Observe red, revert byte-identical, and record a `mutation:` line here.

| AC | Mutation | Expected red |
| --- | --- | --- |
| AC1 | Remove the inserted `:`/`*` line from `IsSystemGlobalMapping` | `MappingSystemGlobal`'s reaching names; `MappingWrite`'s `:OcuProbe1817` and `*` legs |
| AC2 | `systemGlobal()` back to `startsWith('%')` | `mapping-form.store.spec`'s DW-1813 legs; the `namespace-mappings` browser leg |
| AC3 | `open` ignores `returning` and resets | `namespace-form.store.spec`'s restore legs; the `local-databases` DW-1824 test |
| AC3 | The wizard ignores `returnTo` | `database-wizard.page.spec`'s return legs |
| AC4 | `open` skips choosing `returning.database` | the `local-databases` DW-1824 test's Globals assertion |
| AC5 | `DatabaseIntegrityLog` back at position 0 | `navigation.test.mjs`'s listed test; `Navigation`; the browser side-bar legs |

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
