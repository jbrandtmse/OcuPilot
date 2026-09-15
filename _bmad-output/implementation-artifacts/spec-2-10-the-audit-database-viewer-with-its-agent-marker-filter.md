---
title: 'Story 2.10: The audit database viewer, with its agent-marker filter'
type: 'feature'
created: '2026-09-14'
status: 'draft'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-2-9-the-processes-list.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Logs has no built screen, so the instance's audit database is unreachable from OcuPilot
and the claim "every agent write is marked" has nowhere to be checked. It is also the only Release 1
list whose API searches on the **server** (EXPERIENCE.md:384), the only one that reaches AdminPort's
**async** path (AD-26), and the only one that opens a **dialog** from a row (EXPERIENCE.md:89).

**Approach:** A sixth list screen, on none of the five shipped templates. Four things land with it:
the `read` grammar gains a `criteria` block so a declared read can carry server search parameters;
the `logs` area gets its first screen and its real privilege set; the client gets its first
`role="dialog"` surface; and the 1,000-row end-to-end NFR-1 measurement (DW-258) gets an audit
database big enough to make it.

## Boundaries & Constraints

**Always:**

- **The declared pair set is `%Admin_Secure:USE`, `%Admin_Operate:USE`, `%DB_IRISSYS:READ`, in that
  order**, and the `logs` area declares the same three, appended after `%Admin_Operate:USE`
  (`Area.cls:55` today declares that one alone). Each verified live 2026-09-14 on `ocupilot-iris`:
  `%Api.Admin.Endpoints.Security.Audit.Record.ResourcesOR()` is `$LISTBUILD("%Admin_Secure")` (`:26`);
  `%Api.Admin.Endpoints.AsyncResult.ResourcesOR()` is `$LISTBUILD("%Admin_Operate")` (`:10`), and the
  port polls through that endpoint, so a caller without it is refused **after** queueing (DW-249);
  `Registry.ReadProblem`'s last arm (`:563-573`) requires the third. `%SYS.Audit` also re-checks
  `%Admin_Secure:USE` for itself inside the query (`Parameter RESOURCEREQUIRED`, `$$$CheckForClassResource`
  at `Audit.cls:1745` and `:2122`) — AD-29's backing-class half agrees with `ResourcesOR()` here, so
  the endpoint's own gate is not a lower bound in this one case.
- **The async path is the self-queued one.** `Record.ShouldRunAsync()` returns **0** for LIST
  (`:12`, verified); `Run()` → `RunList()` queues the task itself and answers 202 with
  `Location: /api/admin/v1/async-result?id=<GUID>` — a hard-coded `v1` even at `APIVERSION = 2`.
  `AdminPort.Invoke:300-305` enters its async branch on `202` **and** `tLocation [ ..#ASYNCLOCATION`,
  so it already works. No test may assert `ShouldRunAsync()` is 1 for LIST; AD-26 names this path
  exactly.
- **Criteria travel on the declared read, never on the command bar.** One read serves screen and
  tool (AD-36), so the read tool's schema gains the same parameters. The command bar's filter and
  the sort control keep their client-side meaning **within the cap**.
- **The detail dialog renders the row already fetched — no `rowGet`.** Verified: the endpoint's GET
  answers 22 keys and the LIST row carries 24; GET − LIST = ∅, and LIST − GET = `{TimeStamp,
  SessionID}`. A `rowGet` here would issue one GET per surviving row (AD-36) to learn nothing.
- **`EventData` never enters `context.fields`.** AD-24 names "an audit event's data blob" as the
  unbounded-row case, and AD-11 makes it untrusted text; the read carries it for the dialog, the
  model does not see it.
- Vendor spellings, verified: the thirteen query keys `beginDateTime endDateTime eventSources
  eventTypes events usernames systemIDs pids namespaces authentication ascending jsonSearch maxRows`
  (`Record.cls:45-57`; `GetQueryParam` upper-cases, so case is not significant), and the 24 LIST keys
  `SystemID AuditIndex TimeStamp EventSource EventType Event Pid SessionID Username Description
  UTCTimeStamp JobNumber Authentication ClientExecutableName ClientIPAddress EventData Namespace
  Roles RoutineSpec UserInfo JobId Status OSUsername StartupClientIPAddress` (`%SYS.Audit:List`
  ROWSPEC, `Audit.cls:1738`). Numeric ones are `AuditIndex Pid JobNumber JobId` and only those
  (`RecordListTask:61`); the rest arrive as JSON strings.
- **The agent-marker filter is `eventSources = OcuPilot`** — `Kernel/State/Base.cls:71`'s
  `AUDITSOURCE`, the Source `Installer.cls:2557` registers and `:2667` emits under, and the Source
  AD-15 says every future marker carries. Probed live: `EventSource='OcuPilot'` and
  `%SYSTEM.Util_CheckName('OcuPilot', EventSource)=1` both answer **7,692** of 89,318 rows, so the
  filter expresses server-side through the one parameter and selects exactly the same set the
  vendor's own name matcher does. It is an affordance, not a default (AD-46, AC5).
- Every new string is an EXPERIENCE.md **Fixed strings** row (`:252-323`) inserted **after `:320`**,
  before any `strings.ts` key — `strings.test.mjs:343-347` derives a closed-world key equality from
  that table. This story adds roughly twenty literals against a band asserted `>= 150 && <= 178`
  (`:297-307`, measured 164 today), so **the band itself must be widened in this story**.
- Denial checks and every audit-row write run on the throwaway (`scripts/ci-throwaway.sh`,
  `ocupilot-ci`, origin `http://localhost:52776`), never on live `ocupilot`.

**Never:**

- **Never enable, disable or purge auditing, and never delete an audit row, on live `ocupilot`.**
  `%Api.Admin.Endpoints.Security.Audit.Record` declares `TYPECOPY` 10 and `TYPEPURGE` 11;
  `AdminPort.cls:84 TYPESUFFIXES = "GET,LIST,INFO"` admits neither, and that is the containment —
  never widen it. Never `docker compose up`/`down` against the live container.
- **Never hide OcuPilot's own rows** and never make the marker filter a default (AD-46, AC5).
- **Never declare `refreshes`.** EXPERIENCE.md:543 exempts this screen by name; `RefreshProblem`
  already refuses `refreshRates` without `refreshes`, and `CriteriaProblem` must refuse the pair.
- **Never satisfy a declared criterion client-side.** A criterion the API cannot express is an
  intent gap, not a filter over the capped page — the tool would not see it and the two answers
  would differ (AD-36).
- Never render rows or a skeleton before Search (EXPERIENCE.md:532); never a banner; never a
  `primaryAction` or `rowActions` (Epic 2 ships read tools only).
- Never use `jsonSearch` and `eventTypes` in the same call **until the gap below is settled** —
  `%SYS.Audit.cls:1765` (`i JSONSearch'="" s EventTypes="%SQL"`) silently discards the second.

**Open (blocking) — the `text` criterion.** AC1, FR-61 (`prd.md:859`) and EXPERIENCE.md:88 all name
nine criteria ending in "text". Eight map to a real parameter; **"text" does not**. See
`## Auto Run Result`. The criteria roster below is written with the eight that map; the ninth is the
lead's amendment.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Screen opens | `logs/audit`, caller holds all three pairs | Criteria form, no table, no skeleton, no read issued | No error expected |
| Search runs | Search pressed, `beginDateTime` set, cap 1000 | One `LIST` through `AdminPort`: 202 → poll → 200; `{fields, rows, truncated, banner}` with `banner` `""`; rows carry the 24 declared fields | Poll bound is `ASYNCTIMEOUT` 30 s → 503 `PORT.TIMEOUT` |
| Marker filter | Filter applied over the same criteria | Read carries `eventSources=OcuPilot`; a proper non-empty subset of the unfiltered result | No error expected |
| Row opened | A result row activated | `role="dialog"`, read-only, carrying `Description` and `EventData`; Escape and Close dismiss; focus returns to the opener | Dialog never stacks (EXPERIENCE.md:173) |
| No match | Criteria matching nothing, read succeeds with zero rows | "No events match."; no skeleton, no fault state | A faulted or denied view is never empty |
| Cap honoured | Cap 5 against ≥ 6 matching rows | Exactly 5 rows, `truncated` true. The port asks for `maxRows = cap + 1` (`Read.cls:100`) | No error expected |
| Vendor cap trap | Any search | `RecordListTask:41` passes **12** arguments to a **13**-parameter query, so `MaxRows` never reaches the SQL and the query runs unbounded; only `While rset.%Next() && (rowNum <= ..MaxRows)` (`:65`) bounds it | Budget risk for AC6, not a fault |
| Queued-but-refused poll | Principal holds `%Admin_Secure:USE` + `%DB_IRISSYS:READ`, not `%Admin_Operate:USE` (DW-249) | 403 naming `%Admin_Operate:USE`; **no `%Api.Admin.Util.AsyncTask` row left behind** | `AwaitTask:649-651` returns the refusal without `ForgetTask` today |
| Thousand rows (DW-258) | Throwaway seeded to ≥ 1,000 audit rows, cap 1000 | First row rendered within 2 s of the Search press | A miss is a deviation for the lead, never a weakened AC |
| Self-auditing read | Any search | `%SYS.Audit:ListExecute` writes a `%System/%Security/AuditReport` row per call unless the caller holds `%All` **and** `%NoAuditList` | Expected; the viewer appears in its own results |

</intent-contract>

## Code Map

**The read grammar — what does not exist yet**

- `src/OcuPilot/Screen/Registry.cls:460` — `read`'s closed key set is `source, fields, filter, sort,
  paging`; `:468` closes `read.source` to `port, endpoint, type, rowGet`; `:478-481` closes
  `read.source.type` to the single literal `"LIST"`. `Validate`'s arm order is `:141`…`:237`
  (`ReadProblem` `:182`, `MalformedPair` `:190`, `AreaCoverageProblem` `:198`, `RefreshProblem`
  `:207`, `BannerProblem` `:216`, `ClassicLinkProblem` `:227`). `UnknownKeyProblem` `:812`,
  `NameArrayProblem` `:785`, `SecretOverlap` `:825`, `TableProblem` `:685` (kinds `:670`).
- `src/OcuPilot/Screen/Read.cls:100` — `Set tQuery("maxRows") = tMax + 1` is the **only** query
  parameter any read has ever sent; `:101` the port call, `:122-123` the cap, `:137` `truncated`,
  `:134-139` the response keys. `:95` re-asserts `type = "LIST"` as an executor precondition.
- `src/OcuPilot/Api/ScreenRead.cls:59` — passes `%request.Get("maxRows")` and nothing else; its
  class doc `:9-10` says "the route takes no filter or sort" and must be corrected at origin.
- `ui/src/app/core/screen-read.ts:142-149` `screenReadPath` emits only `?maxRows=`.
- `src/OcuPilot/Screen/Tool/Read.cls:40-60` — the tool schema, `additionalProperties: false`.
- `ui/tools/screen-mirror.mjs` — the client twin: `readProblem :390`, type wall `:412`, paging
  `:454/:456`, emitted literals `type: 'LIST' :936`, `paging: 'cap' :953`. Every refusal sentence is
  held identically by both engines and pinned by a shared corpus class (`Test/AdminPairCorpus.cls`,
  `Test/BannerCorpus.cls`, `Test/RowGetCorpus.cls` are the pattern).

**The shape the criteria block needs** (new `read.criteria`, so `read`'s closed set grows to six):

```jsonc
"criteria": {
  "fields": [ {"param": "beginDateTime", "labelKey": "auditCriteriaBegin", "kind": "datetime"} ],
  "marker": {"param": "eventSources", "value": "OcuPilot", "labelKey": "auditMarkerFilterLabel"}
}
```

Refused by `Registry.CriteriaProblem` and its mirror `criteriaProblem`, pinned by a shared
`Test/CriteriaCorpus.cls`: `criteria` only on an `admin` source; closed keys `fields, marker`; each
field closed to `param, labelKey, kind` with `kind` from `text, datetime`; `param` non-empty, unique,
and never `maxRows` (reserved by `Read.cls:100`); `marker.param` must name one of the declared
fields; a descriptor declaring `criteria` may not declare `refreshes`. Plumbing: `Read.Execute` seeds
each non-empty criterion beside `maxRows` (empty means "omit", so the vendor's `"*"` defaults stand);
`ScreenRead.Handle` reads each param off `%request` **by the descriptor's own declared name**, which
is the allow-list (AD-21); `screenReadPath` appends them; `Tool/Read.cls` gains one property each.

**Area, id and the dialog**

- `src/OcuPilot/Screen/Area.cls:55` — `{"key":"logs","railPosition":2,…,"privileges":[{"resource":"%Admin_Operate","permission":"USE"}]}`.
  Append `%Admin_Secure:USE` then `%DB_IRISSYS:READ`. `Area.cls:15-17` and `:22-24` claim Logs "has
  no admin API endpoint behind its first screen" and is "the one gated area that does not" name
  `%DB_IRISSYS:READ` — both become false; correct them at origin.
- **Row identity.** Probed live: 89,318 rows, **89,294 distinct `AuditIndex`** and 75,552 distinct
  `UTCTimeStamp` — neither column is unique, so no single `name` column gives a sound `rowKey`
  (`table-model.ts:37-43`). The record's IDKEY is `(UTCTimeStamp, SystemID, AuditIndex)`. Declaring
  `id: {"kind":"composite","parts":["UTCTimeStamp","SystemID","AuditIndex"]}` makes `rowKey` the
  joined composite (AD-13, one segment) **and** gives `hasIdRoute` (`core/navigation.ts:137-139`) a
  `<route>/:id` route — which is the dialog's own channel: the name cell's existing link
  (`data-table.ts:404,411,700-706`) navigates to the id route, the page opens the dialog for that id
  and closes it by returning to the bare route. `id.kind: "none"` is the alternative and costs both a
  new row-open channel and a hand-rolled key; it is not preferred.
- **No dialog exists.** `ui/src/app/core/overlay-stack.ts` is an Escape-ordering registry only
  (`push :45`, `closeTop :75`); there is no `role="dialog"`, no `aria-modal`, no focus trap, no
  scrim, and no `.ocu-dialog*` rule in `ui/src/styles/_components.scss`. Two guards already wait for
  one: `ui/src/app/shell/side-bar.ts:249` and `command-box.ts:277` both go inert on
  `document.querySelector('[role="dialog"]')`. Contract: DESIGN.md:1215 (440px, title/body/actions,
  no stacking), EXPERIENCE.md:355 (Escape closes, focus returns to the opener, Ctrl/Cmd+K/+I/+B
  inert), :602 (traps focus), :173 (the whitelist names "audit event detail"), DESIGN.md:1080 ("the
  audit viewer keeps its criteria form above the table and its detail `confirm-dialog`-shaped
  read-only dialog"). DESIGN.md:1215 assumes Cancel plus an action; the read-only variant is a Close
  alone and needs its own Fixed-strings row.
- **No form controls.** The whole client holds four `<input>`s — `command-bar.ts:136-145`,
  `data-table.ts:310-320`, `sign-in.ts:122` and `:139` — no `<select>`, no `<textarea>`, no
  date/time input, no label/fieldset/validation primitive. `namespace-switch.ts` (334 lines) is the
  closest listbox precedent. DESIGN.md:1064's `form-page` outlined-field rule is the only field
  vocabulary and is scoped to create/edit routes (EXPERIENCE.md:429, :362), so the criteria form
  inherits none of its Save bar, unsaved-changes guard or validation grammar.
- `ui/src/app/shell/screen-outlet.ts:39-46` — `ARCHETYPE_PAGES` is `{home, list}` and is typed so
  every `BuiltArchetypeKey` is required; `'list (server criteria)'` already exists in the vocabulary
  (`Screen/Archetype.cls:66`, `screens.generated.ts:23`) and `ng build` fails until a page is
  registered for it.

**The pins that move** (a sixth list, and the Logs area's first screen)

- `src/OcuPilot/Test/Descriptor.cls:687` `$ListBuild("logs","%Admin_Operate:USE",0,0)`; `:682`/`:694`
  the eight-area counts; `:389` `Archetype.Count(), 16`; `:590` `EntityType.Count(), 26` — no
  vocabulary edit, `audit-record` is already declared (`Kernel/EntityType.cls:22`). **`:292-293` is
  the trap**: `TestAnAreaThatDoesNotCoverItsScreensPairsIsRefused` asserts the refusal names
  `area 'logs'` and `%Admin_Secure:USE`, driven by `Test/AreaPair/Bad.cls:17,24`. Once `logs`
  declares `%Admin_Secure:USE` the fixture is covered; change the fixture's pair to one `logs` still
  does not declare.
- `src/OcuPilot/Test/Navigation.cls:247` (`logs` "declares that resource alone, is admitted by it")
  and its doc `:208-217`; `:225` the `%DB_IRISSYS:READ` area loop; `:277` `areas.%Size(), 8`.
- `src/OcuPilot/Test/Wire.cls:387` `$Get(tVerdict("logs")), 1` — **flips to a denial** for the
  `%Admin_Operate`-only principal; rewrite as a `failedPair` assertion. Header `:378-384`. The new
  screen's whole-entry JSON pin is authored here first and copied to the two client twins.
- `src/OcuPilot/Test/ReadTool.cls:93` (`5`→`6`), `:94` (the `$Order`-alphabetical roster —
  `logs.audit.read` sorts **first**), `:95`, `:150`.
- `src/OcuPilot/Test/WireSecurityRead.cls` — two new principals: one holding all three pairs, one
  holding `%Admin_Secure:USE` + `%DB_IRISSYS:READ` and refused on `%Admin_Operate:USE` (DW-249).
  Roster `:171`/`:175`, prose "seven principals" `:395`, `:412`, `:430`.
- `src/OcuPilot/Test/ScreenRead.cls:189` **silently skips** a descriptor whose read is not
  `admin`/`LIST` while `:238`'s `tChecked > 0` still passes, and `:196` fails a descriptor whose live
  read returns zero rows — both bite a criteria-bearing read whose default search may return nothing.
- `src/OcuPilot/Install/Smoke.cls:455` (`5`→`6`), `:456` the name list, `:460` a sixth `$Select` arm
  before the pinned `1: ""` catch-all, a `AUDITLISTTOOL` parameter beside `:58`, doc `:442-451`, and
  **`:563`** — `Do ..Note(.pChecks,"arealists","pending","the first live list of Logs -- Epic 2 turns
  it into a real check here")` is **deleted**, which changes the report's `pending` count.
  `src/OcuPilot/Test/Smoke.cls:132-141` asserts that note's content and goes with it; `:313`, `:316`,
  `:317`, `:318`, `:319` the five-literal block; `:337-377` is derived and needs no edit but goes red
  if the bound moves without the arm.
- `ui/tools/navigation.test.mjs:112-116` — the sixth route inserts at **index 1** (`logs` is rail 2,
  `os-management` rail 3); `:77`/`:80` the area roster.
- `ui/tools/navigation-wire.test.mjs:36-140` and `ui/src/app/shell/rail-wire.spec.ts:35-139` — two
  byte-identical `LIVE_PAYLOAD` copies, **neither red on its own**; `navigation-wire.test.mjs:160`
  `areaVerdict('logs').allowed, true` and `rail-wire.spec.ts:185-199` ("the one area `%Admin_Operate`
  alone still opens", the five denied tuples) both flip.
- `ui/tools/screen-mirror.test.mjs:428` the shipped-list roster; `:476-479` the banner exemption.
- `ui/tools/strings.test.mjs:297-307` the literal band (widen), `:343-347` the derived closed-world
  equality, `:486-523` every `/** EXPERIENCE.md:n */` re-resolved — inserting rows after `:320`
  shifts the ten `strings.ts` citations at `:321` and below, plus the in-document self-citations the
  EXPERIENCE.md rows at `:312-320` carry.

**Browser tier and the thousand rows**

- `ui/browser/list-spec.mjs` — `waitForRows :30`, `viewCount :40` (`aria-rowcount − 1`, never DOM
  rows), `clearFilter :50`, `filterToSubset :74` (**leaves its text in the field** — clear before any
  cap assertion). `ui/browser.config.mjs:24` origin `http://localhost:52776`, `:36` readiness path,
  `:45` `LIVE_CONTAINER` the specs refuse. `ui/tools/angular-json.test.mjs:263-277` derives the
  `*.browser-spec.mjs` naming rule from content; `:301-303` forbids the string `52774`.
  `npm run test:browser` runs `browser/*.browser-spec.mjs` one file at a time in **name order** —
  `audit.browser-spec.mjs` sorts first, before `classic-link-card`.
- **Seeding precedent:** `ui/browser/tasks.browser-spec.mjs:53-63` `irisSession()` —
  `spawnSync('docker', ['exec','-i', config.container, 'iris','session','iris','-U','%SYS'], {input})`
  with `mark()`/`parseMarkers` (`ui/browser/iris-session.mjs:16`); `users.browser-spec.mjs:44-50` is
  the same helper creating and deleting three users and a role on the throwaway. Nothing in the repo
  creates bulk rows today.
- **Timing precedent:** exactly one, and it is not the instance —
  `ui/browser/data-table.browser-spec.mjs:141-151` (`Date.now()` around `page.goto` plus
  `waitForSelector('[role="grid"] [role="row"][aria-rowindex="2"]', {timeout: 2000})`) runs against
  the spec's own loopback stub server. `performance.now` has zero hits across `ui/`.

**Read-only evidence (live `ocupilot`, 2026-09-14, reads only)**

- 89,318 audit rows; `EventSource='OcuPilot'` 7,692 (3,247 `RoleGranted`, 4,445 `RoleGrantedProbe`);
  `Security.Events` holds exactly one `OcuPilot` row, `OcuPilot||Security||RoleGranted`.
- The classic page is **`%CSP.UI.Portal.Audit.View`** (`Parameter PAGENAME = "AuditList"`;
  `%CSP.UI.Portal.Audit.Detail` is its detail). Its own criteria form (`:74-100`) offers Namespace to
  search in, Begin/End Date/Time, Event Source, Event Type, Event Name, **SQL Statement Type**, PIDs,
  Users, **"JSON String Search"**, Namespaces, System IDs, Authentications and Maximum Rows — and no
  free-text field at all.
- `Test/AdminPortAsync.cls:66 TestTheSelfQueuedAuditListIsPolledToAnOrdinarySuccess` already drives
  this endpoint through the real port at `maxRows=1` and asserts 200, a `%DynamicArray` result and a
  forgotten task row; its header names the `%Admin_Operate:U` + `%Admin_Secure:U` pair.

## Tasks & Acceptance

**Execution:**

- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` — **first**, and
  before `strings.ts`: insert the Fixed-strings rows after `:320` — the screen row (title, column
  headers, "No events match." cited to `:532`), the criteria-form row (one label per declared
  criterion plus Search), the marker-filter row, and the detail-dialog row (title and Close), each
  with a `Where` cell citing `:88`, `:89`, `:163`, `:173`, `:355`, `:532` or `:543`. Re-resolve the
  document's own `:n` self-citations below the insertion point.
- `ui/tools/strings.test.mjs` — widen the `:297-307` literal band above 178 and say why in the
  comment beside it; leave `REQUIRED_ALONGSIDE_TABLE` at 3.
- `ui/src/app/core/strings.ts` — the new keys, each with its `/** EXPERIENCE.md:n */` comment; bump
  the ten existing comments pointing at `:321` and below. No value may collide with an existing one.
- `src/OcuPilot/Screen/Registry.cls` + `ui/tools/screen-mirror.mjs` — the `read.criteria` grammar and
  `CriteriaProblem` / `criteriaProblem`, one refusal sentence each, called from `Validate` after
  `ReadProblem`. Add `src/OcuPilot/Test/CriteriaCorpus.cls` and drive both engines from it.
- `src/OcuPilot/Screen/Read.cls`, `src/OcuPilot/Api/ScreenRead.cls`,
  `src/OcuPilot/Screen/Tool/Read.cls`, `ui/src/app/core/screen-read.ts` — carry the declared criteria
  from the route to the port and into the tool schema; correct `ScreenRead.cls:9-10` at origin.
- `src/OcuPilot/Screen/Area.cls` — append the two pairs to `logs` and correct `:15-17`, `:22-24`.
- `src/OcuPilot/Screen/Descriptor/AuditList.cls` — new. Route `logs/audit`, area `logs`,
  `sideBarPosition` 4 (EXPERIENCE.md:163 lists Audit database last), archetype
  `list (server criteria)`, `built` true, `refreshes` false, privileges in the declared order,
  `entityType` `audit-record`, scope `instance`, `id` composite over
  `UTCTimeStamp, SystemID, AuditIndex`, `primaryAction` and `rowActions` empty, `classicPage`
  `%CSP.UI.Portal.Audit.View`, `classicLinkExemption` not exempt, `toolIdentifier` `logs.audit`,
  `context.fields` excluding `EventData`, `read.fields` all 24, `read.criteria` as above,
  `emptyStateKey` the "No events match." key, `table.columns` with exactly one `name` kind.
- `ui/src/app/shell/dialog.ts` (+ `ui/src/styles/_components.scss`) — the first `role="dialog"`:
  focus trap, initial focus, focus return to the opener, Escape through `OverlayStack.closeTop()`,
  `aria-modal`, scrim, no stacking.
- `ui/src/app/areas/logs/audit.page.ts` (+ its store) and `ui/src/app/shell/screen-outlet.ts:43-46` —
  the `list (server criteria)` page: criteria form above the table, Search, the marker-filter
  affordance, no read before Search, and the id route opening the dialog.
- `src/OcuPilot/Test/Descriptor.cls`, `Test/ReadTool.cls`, `Test/Wire.cls`,
  `Test/WireSecurityRead.cls`, `Test/Navigation.cls`, `Test/AreaPair/Bad.cls` — the pins and the two
  new principals named in the Code Map.
- `src/OcuPilot/Install/Smoke.cls`, `src/OcuPilot/Test/Smoke.cls` — the sixth area-list check and the
  deletion of the `arealists` pending note.
- `ui/tools/navigation.test.mjs`, `ui/tools/navigation-wire.test.mjs`,
  `ui/src/app/shell/rail-wire.spec.ts`, `ui/tools/screen-mirror.test.mjs`; regenerate
  `ui/src/app/core/screens.generated.ts` with `node ui/tools/screen-mirror.mjs` (never hand-edit).
- `ui/browser/audit.browser-spec.mjs` — new, one leg per AC, importing `list-spec.mjs`. Its `before()`
  seeds the throwaway through `irisSession()`: register a dedicated event triple whose Source is
  **not** `OcuPilot` (so AC2's marker subset stays a proper one), emit ≥ 1,000 rows with
  `$System.Security.Audit`, and assert the count back. **Cleanup is the throwaway's teardown** —
  `ci-throwaway.sh down` runs `docker compose down -v` and scrubs the data directory, and audit rows
  cannot be deleted individually (`spec-1-3…:324`); the spec says so rather than pretending to purge.

**Acceptance Criteria:**

- **Given** a caller holding all three pairs, **when** the Audit database screen opens at
  `logs/audit` and Search is pressed with a begin date-time, **then** no rows and no skeleton appear
  before Search; the read runs through `AdminPort`'s self-queued async path and returns rows the
  table lists under their declared columns; and the footer's max-rows field re-reads at the new cap.
  *(Integration AC — driven through the route against a real instance, not a fixture.)*
- **Given** the agent-marker filter, **when** it is applied over the same criteria, **then** the read
  carries `eventSources=OcuPilot` and the view narrows to a proper non-empty subset; **and** with the
  filter off the same search returns strictly more rows, OcuPilot's own events among them, the filter
  never being the default (AD-46). *(Integration AC.)*
- **Given** a result row, **when** it is opened, **then** a read-only `role="dialog"` shows the
  event's description and its JSON payload, traps focus, closes on Escape and on Close, returns focus
  to the opener, and leaves Ctrl/Cmd+K, +I and +B inert while it is open.
- **Given** criteria that match nothing, **when** the read succeeds with zero rows, **then** the
  screen reads "No events match." rather than the generic empty message, with no skeleton and no
  fault state.
- **Given** a real principal on the throwaway holding `%Admin_Secure:USE` and `%DB_IRISSYS:READ` but
  not `%Admin_Operate:USE`, **when** it searches, **then** it is refused with `%Admin_Operate:USE`
  named as the failing pair, on-screen data stays, and **no `%Api.Admin.Util.AsyncTask` row is left
  behind**; **and** the principal holding all three is served. *(DW-249.)*
- **Given** a throwaway seeded to at least a thousand audit rows, **when** Search runs at a
  1,000-row cap, **then** the first row is rendered within two seconds of the Search press. *(DW-258,
  NFR-1 end to end — the first such measurement against IRIS rather than a stub.)*

## Spec Change Log
- 2026-09-14, lead (owner-delegated decision on the plan's intent gap): reading (a) taken. The ninth criterion is struck at its three origins - `prd.md` FR-61, `epics.md` FR-61 and Story 2.10 AC1, and EXPERIENCE.md's screen row - because the audit API has no free-text search and its one text-shaped parameter (`JSONSearch`) is a mode that forces the event type to SQL. That parameter is recorded as a deliberate non-goal (ledger, `wontfix-accepted`). The story stays one story: `multiple-goals` is accepted, since the criteria form, the dialog and the async read are one screen's worth of surface. Re-plan the criteria roster and its strings rows against the amended text; nothing else changes.

## Review Triage Log

## Design Notes

**Governing architecture decisions (Rule 6).** AD-2 and AD-27 (`AdminPort` is the only caller of
`%Api.Admin.*`; `TYPESUFFIXES` is what keeps `TYPECOPY` and `TYPEPURGE` unreachable) · **AD-26** (the
two async paths; this is the self-queued one it names by class) · AD-5 (one descriptor is the source
of route, gate, read tool and table) · AD-8 (the pair set is an AND, checked per call, a denial names
the pair) · AD-11 and AD-24 (`EventData` is untrusted and unbounded, so it stays out of context) ·
AD-13 (the scoped triple; the composite id in one segment) · AD-21 (the declared criteria roster is
the allow-list; no caller key reaches the port) · **AD-29 as amended** (the pair set is established
from the backing class's own check *and* a least-privileged principal — here both agree on
`%Admin_Secure`, and `AsyncResult`'s separate gate is what adds `%Admin_Operate`) · AD-36 (one read
serves screen and tool; no `rowGet`) · AD-39 (the port normalizes vendor text) · AD-43 (this screen
is **not** in EXPERIENCE.md:543's refreshing roster) · AD-44 (a `list` archetype never links out; the
descriptor declares `%CSP.UI.Portal.Audit.View`) · **AD-46** (OcuPilot's own rows are never hidden;
the marker filter is an affordance) · AD-45 (one smoke path). AD-6, AD-10, AD-14, AD-30, AD-34 and
AD-40 are not reached: this story writes nothing.

**Consumes:** Story 1.9's `Registry`, `Area` and `Gate`; Story 1.13's error envelope; Story 2.1's
`AdminPort` and its async branch; Story 2.3's `Screen.Read` and `GET /screens/:screen/read`; Story
2.4's `DataTable`, `ListPage` and `reconcile`; Story 2.8's `ui/browser/list-spec.mjs`; Story 2.9's
command-bar sort control.

**Consumed-by.** Three surfaces are introduced here and each names its consumers. **`read.criteria`:**
Story 2.11's messages.log paging is the next read whose parameters are not `maxRows` alone, and Epic
4 dispatches `logs.audit.read` with the same parameters the screen sends. **The criteria form:**
Task history (EXPERIENCE.md:384 names it as the second server-criteria list, Epic 6) is its second
consumer; no Epic 2 story reuses it. **The detail dialog:** every dialog EXPERIENCE.md:173 whitelists
— set password, role resource grant, resource editor, terminate process (5.12/7.8), remove locks, and
every delete confirmation from Epic 7 onward — is built on this component; it is the first
`role="dialog"` in the client and `side-bar.ts:249` and `command-box.ts:277` are already waiting for
it. Epic 5 uses this screen's marker filter as UJ-3's end point and SM-4's one-minute demo.

**Why the marker filter is a Source filter.** AD-15 says the marker is emitted "under its own Source";
`Kernel/State/Base.cls:71` is that Source and `Installer.cls:2557` registers it. Story 5.6 writes the
agent-write marker itself, so **no marked agent write exists on any instance today** — a filter keyed
to that event's name would match zero rows and its pinning test would be structurally unfalsifiable,
which Rule 19 forbids and which AC4's own rationale ("the filter existing here from build step 1 so
that Epic 5's first confirmed write has somewhere to be found") rules out. A Source filter is
falsifiable today against the installer's own 7,692 rows and admits 5.6's rows unchanged. *(inference:
that 5.6 will emit under the same Source — AD-15's Rule is the evidence.)*

**Known gaps this story inherits and does not re-file (Rule 17).** **DW-275** reaches the Logs area:
`AreaCoverageProblem` forces the area to carry every pair any screen declares, so adding
`%Admin_Secure:USE` here gates the whole Logs rail entry — including Stories 2.11 and 2.12's screens
— on it; that is the same consequence the lead accepted for `os-management`, and it stays
`owner=burndown`. **DW-260** (no manual Refresh action) reaches this screen, which needs one more than
the others since it never auto-refreshes. **DW-273** (the table frame collapses to header height, so a
real pointer click at a row's centre lands on the footer) constrains how the AC3 leg opens a row:
dispatch a synthetic click and set `scrollTop` directly, as `users`, `tasks` and `processes` do.
**DW-271** (a misspelled top-level descriptor key installs silently) is live for every key this
descriptor declares, `criteria` included. **DW-272** (EXPERIENCE.md citations outside `strings.ts` are
ungated) is why only the `strings.ts` citations are repaired. **DW-276** (the sort control is
unasserted on the earlier lists) is `wontfix-accepted`. **DW-274** (the port answers 500 where a
query's own privilege refusal should be a named 403) does not bite here: both gates this screen
crosses refuse with a status the port maps.

**Declined DW-n:** none. DW-249 is addressed by AC5 and the "Queued-but-refused poll" matrix row;
DW-258 by AC6 and the "Thousand rows" row.

**Why the thousand rows are seeded rather than found.** A fresh throwaway's audit database holds only
what install and sign-in wrote — the live instance's 89,318 rows are the residue of weeks and of
DW-44's one row per `Install()` call, not a property of a clean container. The seed registers its own
event triple under a Source other than `OcuPilot` so AC2's "proper non-empty subset" stays proper,
and AC6 measures a cap the seeded population can actually fill.

## Verification

**Commands:**

- `uv run scripts/check-objectscript.py` — expected: clean over every changed `.cls`.
- `cd ui && node tools/screen-mirror.mjs` then `git diff --stat ui/src/app/core/screens.generated.ts`
  — expected: the sixth descriptor appears; stage the regenerated file.
- `cd ui && npm run build` — expected: the `prebuild` checkers pass, `screen-mirror.mjs --check`
  included.
- `cd ui && npm test` — expected: green, with `navigation.test.mjs`, `navigation-wire.test.mjs`,
  `screen-mirror.test.mjs`, `strings.test.mjs`, `rail-wire.spec.ts` and the new dialog spec **updated
  rather than skipped**.
- `bash scripts/lint-docs.sh` — expected: clean after the EXPERIENCE.md rows.
- IRIS MCP (`server: "ocupilot-iris"`): load and compile `src/OcuPilot/`, then **one**
  `iris_execute_tests` call per message, waiting for each to land in `%UnitTest_Result` before the
  next — `Test.Descriptor`, `Test.ReadTool`, `Test.ScreenRead`, `Test.Navigation`, `Test.AdminPortAsync`,
  `Test.Smoke`. **Never two test calls in one message.**
- `sh scripts/ci-throwaway.sh up && sh scripts/wait-readiness.sh --url http://localhost:52776/api/ocupilot/readiness/`,
  then from `ui/`:
  `OCUPILOT_BROWSER_EXECUTABLE="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" node --test --test-concurrency=1 browser/audit.browser-spec.mjs`,
  then the full `npm run test:browser`. Finish with `sh scripts/ci-throwaway.sh down`.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` — expected: six
  area-list checks, the `audit` one reading `logs.audit`, and the `arealists` pending note gone; zero
  executed checks is a failure, never a pass.

**Live `ocupilot` is read-only throughout.** No audit configuration is changed, no audit row is
deleted, no principal is created, and `docker compose up`/`down` is never run against it. Every audit
row this story writes is written on `ocupilot-ci` and dies with it.

**Mutations (Rule 19) — one per AC. Apply, observe red, revert, and confirm `git status --short` and
`git diff --stat` are byte-identical to the pre-mutation snapshot:**

- AC1 — mutation: drop the `beginDateTime` entry from the descriptor's `read.criteria.fields` and
  regenerate → the browser AC1 leg red on the missing control **and** `Test.Descriptor`'s
  `read.criteria` equality pin red on the declaration. Second witness: make `Read.Execute` stop
  seeding criteria into `tQuery` → the leg red because the unfiltered result exceeds the criteria'd
  one, which is what distinguishes a real server search from a form that changes nothing.
- AC2 — mutation: change `read.criteria.marker.value` from `OcuPilot` to a Source with no rows → the
  marker leg red on `0 < kept`, not on `kept < total`; and change it to `*` → red on `kept < total`.
  Both directions are required: a filter that matches everything and one that matches nothing each
  pass one half alone.
- AC3 — mutation: remove the `keydown.escape` binding from the dialog → the Escape test red alone;
  remove the focus-return call → the opener-focus test red alone.
- AC4 — mutation: point `emptyStateKey` at the generic list empty-state key and regenerate → the
  empty leg red naming the wrong sentence. Second: make the zero-row read render the fault state →
  red on the skeleton/fault assertion.
- AC5 — mutation: remove `%Admin_Operate:USE` from the descriptor **and** the `logs` area, rebuild the
  throwaway → `WireSecurityRead`'s denial leg red, because the search is no longer refused by name.
  Second: remove `%Admin_Secure:USE` from the area alone → `Test.Descriptor`'s `AreaCoverageProblem`
  tests red naming the uncovered pair.
- AC6 — mutation: lower the seeded row count below the cap → the timing leg red on its own
  precondition (it must assert the seeded count before it asserts the duration), which is what stops
  a two-second pass over eleven rows from standing for a thousand.

## Auto Run Result

Status: blocked
Blocking condition: intent gap

**The gap.** AC1 (`epics.md:2061`), FR-61 (`prd.md:859`) and EXPERIENCE.md:88 each name **nine**
criteria for the audit viewer's form, ending in "text". Eight map onto a real parameter of the only
query behind the endpoint. **"text" does not, and the one candidate parameter destroys another
criterion in the same AC.**

Evidence, all verified read-only on live `ocupilot` 2026-09-14 (`server: "ocupilot-iris"`):

1. `%SYS.Audit:List` (`Audit.cls:1738`, formal spec confirmed against `%Dictionary.CompiledQuery`)
   takes thirteen parameters: `BeginDateTime, EndDateTime, EventSources, EventTypes, Events,
   Usernames, SystemIDs, Pids, Namespaces, Authentications, Flags, JSONSearch, MaxRows`. **None
   filters on `Description` or on free text.** `Description` appears only in the ROWSPEC.
2. The name filters are `%SYSTEM.Util:CheckName` — exact comma-list membership or a trailing-`*`
   prefix, never a contains match. (`CheckNameContains` exists in the same class and `%SYS.Audit`
   never calls it.)
3. The only text-shaped parameter is `JSONSearch`, documented at `Audit.cls:1736` as "String to
   search for in the JSON Data field", and its implementation at **`Audit.cls:1765`** is
   `i JSONSearch'="" s EventTypes="%SQL"` under the comment `#;JSON search only applies to SQL audit
   events`. **Filling the form's "text" field therefore silently discards the form's own "type"
   field** and restricts the result to SQL audit events.
4. The classic page this descriptor replaces, `%CSP.UI.Portal.Audit.View`, has **no text field**: its
   form (`:74-100`) labels that control **"JSON String Search"** ("Enter a JSON field search
   pattern") and pairs it with a separate "SQL Statement Type" combobox — the vendor's own UI treats
   it as a mode, not as a ninth peer criterion.

Two readings of "text" survive, they produce observably different products, and nothing in the PRD,
the epics, EXPERIENCE.md or DESIGN.md selects between them: (a) drop it, leaving eight criteria; (b)
ship `jsonSearch` under its true name, which needs a rule for the `eventTypes` collision. A third —
filter client-side over the capped page — is refused by AD-36 (the read tool would not see it, so
screen and tool would answer differently) and by this stage's own dispatch. Narrowing or dropping an
AC is the lead's call under Rule 5, not build-auto's.

**Recommended amendment.** Take reading (b), and amend `prd.md:859`, `epics.md:2061` and
EXPERIENCE.md:88 in the same pass so the three agree:

> …by time range, source, type and name, user, process id, namespace, authentication and a **JSON
> payload search**, and open an event's detail. The JSON payload search matches inside an audit
> event's captured JSON data and applies only to SQL audit events; the form disables the Event type
> control while it is filled and says why, because the API replaces that criterion with `%SQL`
> (`%SYS.Audit.cls:1765`).

Reading (a) is the smaller amendment — strike "and text" from the three documents and note that the
API offers no text search — and is defensible if the owner would rather not ship a criterion whose
semantics need a sentence to explain. Either way the amendment is three one-line edits plus the
`## Spec Change Log` entry and the inline `[AMENDED <date> — see the story change log]` markers; the
`read.criteria` grammar, the pair set, the dialog, the marker filter and the thousand-row measurement
above are unaffected, so resetting this spec to `draft` and re-dispatching re-plans only the criteria
roster and its Fixed-strings rows.

**Two warnings carried forward.** `multiple-goals`: this story introduces a grammar extension, a
criteria-form vocabulary the client has no primitives for, the client's first dialog, the Logs area's
first screen and a thousand-row timing harness — five independently shippable pieces. The lead may
wish to split before re-dispatch. `oversized`: the spec exceeds the template's budget, which the
volume of new surface justifies but which the next reviewer should hold against it.

**What was established and does not need re-deriving on the next pass.** The pair set and its three
proofs; that the LIST is the self-queued async path and `ShouldRunAsync()` is 0 for it; the thirteen
query keys and the 24 result keys with their JSON types; that GET ⊂ LIST so no `rowGet` is needed;
that the marker filter is `eventSources=OcuPilot` and selects 7,692 of 89,318 rows live; that neither
`AuditIndex` nor `UTCTimeStamp` is unique so the id must be the composite; that no dialog and no form
primitives exist in the client; that `MaxRows` never reaches the vendor's SQL; and that
`Test/AreaPair/Bad.cls` breaks when `logs` declares `%Admin_Secure:USE`.
