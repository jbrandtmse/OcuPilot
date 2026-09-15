---
title: 'Story 2.10: The audit database viewer, with its agent-marker filter'
type: 'feature'
created: '2026-09-14'
status: 'done'
baseline_revision: '171811103a1c18ba3a9f6197cf57160c5888f928'
baseline_commit: '171811103a1c18ba3a9f6197cf57160c5888f928'
review_loop_iteration: 0
followup_review_recommended: true
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-2-9-the-processes-list.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      The spec's "Queued-but-refused poll" matrix row and AC5 both expect a refused poll to leave an
      %Api.Admin.Util.AsyncTask row behind; on this screen the gate refuses before anything is
      queued, so the row it names never exists.
    evidence: |-
      OcuPilot.Api.ScreenRead.Handle evaluates the descriptor's pair set before the read executor is
      called, and the descriptor declares %Admin_Operate:USE. The AC5 leg counts the async-task rows
      around the refused read and they are unchanged, because the LIST was never queued. DW-249's
      underlying port behaviour - AwaitTask returning a refusal without ForgetTask - is unreached
      from any screen that declares the poll's own pair, and is still live for one that does not.
    location: >-
      _bmad-output/implementation-artifacts/deferred-work.md (DW-249)
    severity: low
  - summary: >-
      EXPERIENCE.md's own ":n" self-citations are still re-resolved by hand, and this story moved
      twelve of them by four with nothing gating the result.
    evidence: |-
      strings.test.mjs resolves only the /** EXPERIENCE.md:n */ comments in strings.ts. The four
      Fixed-strings rows inserted here shifted every self-citation at or below :321, and the
      citations in .cls, .ts and .scss comments elsewhere in the tree are ungated by anything.
    location: >-
      _bmad-output/implementation-artifacts/deferred-work.md (DW-272)
    severity: medium
  - summary: >-
      Adding %Admin_Secure:USE to the Logs area gates the whole Logs rail entry on it, including
      Stories 2.11 and 2.12's screens, which need only %Admin_Operate.
    evidence: |-
      AreaCoverageProblem (AD-8) forces the area to carry every pair any of its screens declares, and
      Gate evaluates the area's set separately from each screen's. The same consequence the lead
      accepted for os-management in Story 2.9; recorded again because the area it now reaches is the
      one AD-48 documents as needing %Admin_Operate alone.
    location: >-
      _bmad-output/implementation-artifacts/deferred-work.md (DW-275)
    severity: medium
  - summary: >-
      The audit database viewer ships without a manual Refresh action, and it is the screen that
      needs one most: it never auto-refreshes, so a stale result can only be re-read by pressing
      Search again.
    evidence: |-
      EXPERIENCE.md :571 requires a manual Refresh on every list; no list ships one. This screen is
      exempt from the auto-refresh roster by name, so unlike the other five it has no other path to
      fresh rows at all.
    location: >-
      _bmad-output/implementation-artifacts/deferred-work.md (DW-260)
    severity: low
  - summary: >-
      A criteria-bearing screen's own page owns its state in a root-provided store because the
      detail route re-creates the component; nothing stops the next such screen re-deriving that.
    evidence: |-
      Angular's default RouteReuseStrategy does not reuse across <route> and <route>/:id, so the
      page, its criteria and its "has searched" flag are destroyed on every dialog open and close.
      areas/logs/audit.store.ts carries them; Task history (Epic 6) is the archetype's second
      consumer and would have to solve the same problem from scratch. The same entry covers the
      page's copy: the two hint lines, the Search label and the "Any" option are this screen's
      literals inside a component the archetype key points every such screen at.
    severity: low
  - summary: >-
      A criterion value longer than the vendor's own column for that parameter fails inside the
      queued task's save and answers 500, where the declared grammar has no length to refuse it by.
    evidence: |-
      Probed live on ocupilot-iris: an 83-character `pids` value (twelve process ids) through
      OcuPilot.Screen.Read.Execute answers http=500 code=INTERNAL. The vendor's task declares Pids,
      BeginDateTime, EndDateTime and Authentication as plain %String (MAXLEN 50) and the other five
      at MAXLEN 1000, so one conservative bound would wrongly refuse a legitimate comma list. The
      smallest honest fix is a declared per-criterion maxLength in the read.criteria grammar, which
      this story's intent does not settle.
    location: >-
      src/OcuPilot/Screen/Read.cls (SeedCriteria)
    severity: medium
  - summary: >-
      EXPERIENCE.md citations in source files no longer resolve after this story's four-line
      insertion, and a blanket re-resolution would move pointers that did not resolve before it
      either.
    evidence: |-
      Five cited values (:409, :552, :582, :594, :604) now land on blank lines, with their content
      four lines below. Spot checks show the same citations did not carry their content before the
      shift: side-bar.ts `:530`, Archetype.cls `:409`, namespace-switch.ts `:552` and app.ts `:594`
      all mismatch at both the pre- and post-shift target. Roughly sixty sites at or beyond line 321
      would need semantic re-resolution, which DW-272 records as ungated by any test.
    location: >-
      _bmad-output/implementation-artifacts/deferred-work.md (DW-272)
    severity: medium
  - summary: >-
      The criteria form tells the user to include a time but does not require one, so a bare date in
      the End field silently drops the whole of that day.
    evidence: |-
      The matrix row "End time at midnight" states the mitigation as a property of the form. The
      `datetime` kind renders as a plain text input; its only effect is the helper line and a
      different description in the tool schema. OcuPilot.Test.AuditRead pins the vendor's rollback,
      not the mitigation. A control that requires a time is a design the spec does not specify.
    location: >-
      ui/src/app/areas/logs/audit.page.ts
    severity: low
  - summary: >-
      AD-24's field-level bound is unimplemented project-wide, so the read tool's payload carries an
      unbounded EventData blob for every row it returns.
    evidence: |-
      AD-24 requires each field to be truncated to a declared maximum with the truncation marked;
      no descriptor declares one and OcuPilot.Screen.Tool.Read.View truncates only rows, against the
      context cap. Pre-existing and common to every screen, but this is the first descriptor whose
      read carries a field AD-24 names by example.
    location: >-
      src/OcuPilot/Screen/Tool/Read.cls (View)
    severity: medium
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

- **The criteria roster is the eight the amended FR-61 names, over nine parameters.** Verified live
  2026-09-14 on `ocupilot-iris` against `%Api.Admin.Endpoints.Security.Audit.Record.RunList` (the
  `GetQueryParam` block) and `%SYS.Audit:List` (`Audit.cls:1738`): time range →
  `beginDateTime` + `endDateTime`; source → `eventSources`; type → `eventTypes`; name → `events`;
  user → `usernames`; process id → `pids`; namespace → `namespaces`; authentication →
  `authentication` (**singular**). `systemIDs`, `ascending` and `jsonSearch` are real parameters this
  story deliberately does not declare — `systemIDs` and `ascending` because FR-61 does not name them,
  `jsonSearch` because it is a terminal non-goal (DW-277).
- **`authentication` is a closed choice, not free text, because an unrecognized value widens the
  search instead of narrowing it.** `Audit.cls:1823-1824` converts the criterion with
  `$$AuthenticationDisplayToLogical^%SYS.SECURITY`, which answers **-1** for any name it does not
  know, and `%SYS.Audit.CheckAuthentication` (`:2404`) is `$zb(+Select,+Data,1)` — probed live,
  `CheckAuthentication(-1, 32) = 1`, so a typo silently matches every row with any authentication bit
  set. The criterion is therefore declared `kind: "choice"` over the vendor's own display vocabulary,
  and the **executor refuses a value outside the declared options** (AD-21) so the read tool cannot
  send one either. The eleven names round-trip through `$$AuthenticationLogicalToDisplay`, are
  case-insensitive, and combine as a comma list (probed: `"Password,Operating System"` → 48). They
  are **eleven of the build's wider vocabulary** (21 display names round-trip), not all of it, so a
  row authenticated by an undeclared mechanism is unreachable through this criterion.
- **The declared pair set is `%Admin_Secure:USE`, `%Admin_Operate:USE`, `%DB_IRISSYS:READ`, in that
  order**, and the `logs` area declares the same three, appended after `%Admin_Operate:USE`
  (`Area.cls:55` today declares that one alone). Each verified live 2026-09-14:
  `%Api.Admin.Endpoints.Security.Audit.Record.ResourcesOR()` is `$LISTBUILD("%Admin_Secure")`;
  `%Api.Admin.Endpoints.AsyncResult.ResourcesOR()` is `$LISTBUILD("%Admin_Operate")`, and the port
  polls through that endpoint, so a caller without it is refused **after** queueing (DW-249);
  `Registry.ReadProblem`'s last arm (`:573`) requires the third. `%SYS.Audit` also re-checks
  `%Admin_Secure:USE` for itself inside the query (`$$$CheckForClassResource` at `Audit.cls:1745` and
  `:2122`) — AD-29's backing-class half agrees with `ResourcesOR()` here, so the endpoint's own gate
  is not a lower bound in this one case.
- **The async path is the self-queued one.** `Record.ShouldRunAsync()` returns **0** for LIST
  (it is `(..Type = ..#TYPECOPY) || (..Type = ..#TYPEPURGE)`); `Run()` → `RunList()` queues the task
  itself and answers 202 with `Location: /api/admin/v1/async-result?id=<GUID>` — a hard-coded `v1`
  even at `APIVERSION = 2`. `AdminPort.Invoke:300-305` enters its async branch on `202` **and**
  `tLocation [ ..#ASYNCLOCATION`, so it already works. No test may assert `ShouldRunAsync()` is 1 for
  LIST; AD-26 names this path exactly.
- **Criteria travel on the declared read, never on the command bar.** One read serves screen and
  tool (AD-36), so the read tool's schema gains the same parameters. The command bar's filter and
  the sort control keep their client-side meaning **within the cap**.
- **The marker filter overrides the `eventSources` criterion; it never merges with it.** Both name
  the same parameter, and `%SYSTEM.Util_CheckName` treats a comma list as membership — appending
  `OcuPilot` to a user's source would *widen* the result, contradicting AC2. While the marker is on,
  the Event source field renders unavailable (DESIGN.md:855's 38%, no reason text) and its value is
  not sent; turning the marker off restores it.
- **The detail dialog renders the row already fetched — no `rowGet`.** Verified: the endpoint's
  `RunGet` answers 22 keys and the LIST row carries 24; GET − LIST = ∅, and LIST − GET =
  `{TimeStamp, SessionID}`. A `rowGet` here would issue one GET per surviving row (AD-36) to learn
  nothing. `RunGet` also confirms the id order: `Set id = UTCTimestamp _ "||" _ systemID _ "||" _
  auditIndex`.
- **`EventData` never enters `context.fields`.** AD-24 names "an audit event's data blob" as the
  unbounded-row case, and AD-11 makes it untrusted text; the read carries it for the dialog. It is
  **not** kept from the read tool: `Tool.Read.View` answers `read.fields` minus secret fields
  (AD-36), so the tool's payload carries it too, and AD-24's per-field bound is unimplemented
  project-wide (DW-281).
- Vendor spellings, verified: the thirteen query keys `beginDateTime endDateTime eventSources
  eventTypes events usernames systemIDs pids namespaces authentication ascending jsonSearch maxRows`
  (`Record.RunList`; `GetQueryParam` upper-cases, so case is not significant), and the 24 LIST keys
  `SystemID AuditIndex TimeStamp EventSource EventType Event Pid SessionID Username Description
  UTCTimeStamp JobNumber Authentication ClientExecutableName ClientIPAddress EventData Namespace
  Roles RoutineSpec UserInfo JobId Status OSUsername StartupClientIPAddress` (`%SYS.Audit:List`
  ROWSPEC, `Audit.cls:1738`). Numeric ones are `AuditIndex Pid JobNumber JobId` and only those
  (`RecordListTask.RunTask`); the rest arrive as JSON strings, `Authentication` included.
- **The agent-marker filter is `eventSources = OcuPilot`** — `Kernel/State/Base.cls:71`'s
  `AUDITSOURCE`, the Source `Installer.cls:2557` registers and `:2667` emits under, and the Source
  AD-15 says every future marker carries. Probed live: `EventSource='OcuPilot'` and
  `%SYSTEM.Util_CheckName('OcuPilot', EventSource)=1` both answer **7,692** of 89,318 rows, so the
  filter expresses server-side through the one parameter and selects exactly the same set the
  vendor's own name matcher does. It is an affordance, not a default (AD-46, AC2).
- Every new string is an EXPERIENCE.md **Fixed strings** row (`:252-323`) inserted **after `:320`**,
  before any `strings.ts` key — `strings.test.mjs:333-348` derives a **strict cardinality equality**
  from that table, so each new literal needs exactly one new `strings.ts` key and no new row may
  repeat a literal the table already carries (`:437-443` also forbids duplicate values). This story
  adds **17** literals against a band asserted `>= 150 && <= 178` (`:297-307`, measured 164 today), so
  the band must be widened to admit 181 **in this story**.
- Denial checks and every **deliberate** audit-row write run on the throwaway
  (`scripts/ci-throwaway.sh`, `ocupilot-ci`, origin `http://localhost:52776`), never on live
  `ocupilot`. The vendor's own self-audit row is the exception and cannot be one: `%SYS.Audit:List`
  records one per query, so every audit read this screen performs writes one wherever it runs — that
  is the "Self-auditing read" matrix row, not a violation of this line.

**Never:**

- **Never enable, disable or purge auditing, and never delete an audit row, on live `ocupilot`.**
  `%Api.Admin.Endpoints.Security.Audit.Record` declares `TYPECOPY` 10 and `TYPEPURGE` 11;
  `AdminPort.cls:84 TYPESUFFIXES = "GET,LIST,INFO"` admits neither, and that is the containment —
  never widen it. Never `docker compose up`/`down` against the live container.
- **Never hide OcuPilot's own rows** and never make the marker filter a default (AD-46, AC2).
- **Never declare `refreshes`.** EXPERIENCE.md:543 exempts this screen by name; `RefreshProblem`
  already refuses `refreshRates` without `refreshes`, and `CriteriaProblem` must refuse the pair.
- **Never satisfy a declared criterion client-side.** A criterion the API cannot express is an
  intent gap, not a filter over the capped page — the tool would not see it and the two answers
  would differ (AD-36).
- **Never render `Authentication` as a table column.** It arrives as the stored logical integer
  (probed live: `0, 16, 32, 64, 1024, 4194304, 8388608` across 89,318 rows) while the criterion takes
  display names, so a column would show `32` and would not round-trip into the field beside it. It
  stays in `read.fields` and out of `table.columns`.
- Never render rows or a skeleton before Search (EXPERIENCE.md:532); never a banner; never a
  `primaryAction` or `rowActions` (Epic 2 ships read tools only).
- Never declare `jsonSearch` (DW-277, terminal) and never use it with `eventTypes` — `Audit.cls:1765`
  (`i JSONSearch'="" s EventTypes="%SQL"`) silently discards the second.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Screen opens | `logs/audit`, caller holds all three pairs | Criteria form (nine fields), no table, no skeleton, no read issued | No error expected |
| Search runs | Search pressed, `beginDateTime` set, cap 1000 | One `LIST` through `AdminPort`: 202 → poll → 200; `{fields, rows, truncated, banner}` with `banner` `""`; rows carry the 24 declared fields, newest first (`ORDER BY UTCTimeStamp DESC, SystemID ASC, AuditIndex DESC`, `Audit.cls:1850`) | Poll bound is `ASYNCTIMEOUT` 30 s → 503 `PORT.TIMEOUT` |
| Empty criterion | A declared field left blank | The parameter is omitted; the vendor's own default stands (`"*"` for the seven name criteria, unbounded for the two times — `Audit.cls:1754-1761`, `:1815-1818`) | No error expected |
| Marker filter | Filter applied over the same criteria | Read carries `eventSources=OcuPilot`; the Event source field goes unavailable and its value is not sent; a proper non-empty subset of the unfiltered result | No error expected |
| Off-list authentication | `authentication=Bogus` on the route or from the read tool | Refused by name before the port is called; **no** LIST is queued | Without the refusal, `DisplayToLogical` answers -1 and `CheckAuthentication(-1, 32)=1` matches nearly every row (probed live) |
| End time at midnight | `endDateTime` with a zero time part | `Audit.cls:1812` rolls it back to the **previous** day at 86399.999. An explicit `00:00:00` is a bound the caller chose and is honoured; a date with no time part is refused by name instead, 400 `READ.CRITERION`, before the port is called (DW-280) | Budget for AC1's fixture, not a fault |
| Row opened | A result row activated | `role="dialog"`, read-only, carrying `Description` and `EventData`; Escape and Close dismiss; focus returns to the opener | Dialog never stacks (EXPERIENCE.md:173) |
| No match | Criteria matching nothing, read succeeds with zero rows | "No events match."; no skeleton, no fault state | A faulted or denied view is never empty |
| Cap honoured | Cap 5 against ≥ 6 matching rows | Exactly 5 rows, `truncated` true. The port asks for `maxRows = cap + 1` (`Read.cls:100`) | No error expected |
| Vendor cap trap | Any search | `RecordListTask.RunTask` sets `f = 12` and passes twelve arguments to the thirteen-parameter query, so `MaxRows` keeps its `-1` default, `Audit.cls:1766` raises it to `%BigInt.#MAXVAL`, and `SELECT TOP :MaxRows` (`:1836`) bounds nothing. Only `While rset.%Next() && (rowNum <= ..MaxRows)` stops the fetch | Elapsed time scales with the **matching** population, not the cap — a DW-258 budget risk, not a fault |
| Refused before the queue | Principal holds `%Admin_Secure:USE` + `%DB_IRISSYS:READ`, not `%Admin_Operate:USE` (DW-249) | 403 naming `%Admin_Operate:USE`, at the screen's own gate; nothing is queued, so **no `%Api.Admin.Util.AsyncTask` row is left behind** | Declaring the poll's own pair is the fix: DW-249's port behaviour (`AwaitTask:649-651` returns a refusal without `ForgetTask`) is unreachable from this screen and stays live for one that does not declare it |
| Thousand rows (DW-258) | Throwaway seeded to ≥ 1,000 audit rows, cap 1000 | `aria-rowcount` reaches 1,001 and the first data row is in the DOM within 2 s of the Search press | A miss is a deviation for the lead, never a weakened AC |
| Self-auditing read | Any search | `%SYS.Audit:ListExecute` writes a `%System/%Security/AuditReport` row per call unless the caller holds `%All` **and** `%NoAuditList` (`Audit.cls:1768`) | Expected; the viewer appears in its own results |

</intent-contract>

## Code Map

**The read grammar — what does not exist yet**

- `src/OcuPilot/Screen/Registry.cls:460` — `read`'s closed key set is `source, fields, filter, sort,
  paging`; `:468` closes `read.source` to `port, endpoint, type, rowGet`; `:478-481` closes
  `read.source.type` to the single literal `"LIST"`. `Validate`'s arm order is `:141`…`:237`
  (`ReadProblem` `:182`, `MalformedPair` `:190`, `AreaCoverageProblem` `:198`, `RefreshProblem`
  `:207`, `BannerProblem` `:216`, `ClassicLinkProblem` `:227`) — all verified. `UnknownKeyProblem`
  `:812`, `NameArrayProblem` `:785`, `SecretOverlap` `:825`, `TableProblem` `:685` (kinds `:670`).
  `ReadProblem`'s `%DB_IRISSYS:READ` arm is the sentence at `:573`.
- `src/OcuPilot/Screen/Read.cls:100` — `Set tQuery("maxRows") = tMax + 1` is the **only** query
  parameter any read has ever sent; `:101` the port call, `:122-123` the cap, `:137` `truncated`,
  `:134-139` the response keys. `:95` re-asserts `type = "LIST"` through the `READTYPE` constant.
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
  "fields": [
    {"param": "beginDateTime",  "labelKey": "auditCriteriaBegin",          "kind": "datetime"},
    {"param": "endDateTime",    "labelKey": "auditCriteriaEnd",            "kind": "datetime"},
    {"param": "eventSources",   "labelKey": "auditColumnEventSource",      "kind": "text"},
    {"param": "eventTypes",     "labelKey": "auditColumnEventType",        "kind": "text"},
    {"param": "events",         "labelKey": "auditColumnEventName",        "kind": "text"},
    {"param": "usernames",      "labelKey": "processColumnUser",           "kind": "text"},
    {"param": "pids",           "labelKey": "processColumnPid",            "kind": "text"},
    {"param": "namespaces",     "labelKey": "headerNamespaceLabel",        "kind": "text"},
    {"param": "authentication", "labelKey": "auditCriteriaAuthentication", "kind": "choice",
     "options": ["Kerberos Credentials Cache", "Kerberos", "K5KeyTab", "Operating System",
                 "Password", "Unauthenticated", "Kerberos with Encryption",
                 "Kerberos with Packet Integrity", "LDAP", "Delegated", "Mutual TLS"]}
  ],
  "marker": {"param": "eventSources", "value": "OcuPilot", "labelKey": "auditMarkerFilterLabel"}
}
```

Refused by `Registry.CriteriaProblem` and its mirror `criteriaProblem`, pinned by a shared
`Test/CriteriaCorpus.cls` — one refusal sentence per rule, byte-identical in both engines:
`criteria` only on an `admin` source; closed keys `fields, marker`; `fields` a non-empty array, each
field closed to `param, labelKey, kind` plus `options` **only** when `kind` is `choice`; `kind` from
`text, datetime, choice`; `param` non-empty, unique, and never `maxRows` (reserved by
`Read.cls:100`); a `choice` field's `options` a non-empty array of unique non-empty strings, and no
other kind may declare one; `marker` closed to `param, value, labelKey` with `marker.param` naming
one of the declared fields and `marker.value` non-empty; a descriptor declaring `criteria` may not
declare `refreshes`. Plumbing: `Read.Execute` seeds each non-empty criterion beside `maxRows` and
**refuses a `choice` value outside its options** before calling the port; `ScreenRead.Handle` reads
each param off `%request` **by the descriptor's own declared name**, which is the allow-list (AD-21),
ignoring every other query key; `screenReadPath` appends them URL-encoded; `Tool/Read.cls` gains one
property per criterion, the `choice` one as an `enum`, with `additionalProperties: false` kept.

**Area, id and the dialog**

- `src/OcuPilot/Screen/Area.cls:55` — `{"key":"logs","railPosition":2,…,"privileges":[{"resource":"%Admin_Operate","permission":"USE"}]}`.
  Append `%Admin_Secure:USE` then `%DB_IRISSYS:READ`. `Area.cls:15-17` ("Logs has no admin API
  endpoint behind its first screen") and `:22-24` ("the one gated area that does not" name
  `%DB_IRISSYS:READ`) both become false; correct them at origin.
- **Row identity.** Probed live: 89,318 rows, **89,294 distinct `AuditIndex`** and 75,552 distinct
  `UTCTimeStamp` — neither column is unique, so no single `name` column gives a sound `rowKey`
  (`table-model.ts:37-43`). The record's IDKEY is `(UTCTimeStamp, SystemID, AuditIndex)`, the order
  `RunGet` joins with `||`. Declaring `id: {"kind":"composite","parts":["UTCTimeStamp","SystemID",
  "AuditIndex"]}` makes `rowKey` the joined composite (AD-13, one segment; note `AuditIndex` arrives
  as a JSON number and the other two as strings) **and** gives `hasIdRoute`
  (`core/navigation.ts:137-139`) a `<route>/:id` route — which is the dialog's own channel: the name
  cell's existing link (`data-table.ts:404,411`, handler `onLinkClick` `:702-707`) navigates to the
  id route, the page opens the dialog for that id and closes it by returning to the bare route.
  `id.kind: "none"` is the alternative and costs both a new row-open channel and a hand-rolled key;
  it is not preferred.
- **No dialog exists.** `ui/src/app/core/overlay-stack.ts` is an Escape-ordering registry only
  (`push :45`, `closeTop :75`); there is no `role="dialog"`, no `aria-modal`, no focus trap, no
  scrim, and no `.ocu-dialog*` rule in `ui/src/styles/_components.scss`. Two guards already wait for
  one: `ui/src/app/shell/side-bar.ts:249` and `command-box.ts:277` are the identical line
  `if (document.querySelector('[role="dialog"]') !== null) return;`. Contract: DESIGN.md:1215 (440px,
  title/body/actions, focus lands on the first input or on the action where there is none, no
  stacking), EXPERIENCE.md:355 (Escape closes, focus returns to the opener, Ctrl/Cmd+K/+I/+B inert),
  :602 (traps focus), :173 (the whitelist names "audit event detail"), DESIGN.md:1080 ("the audit
  viewer keeps its criteria form above the table and its detail `confirm-dialog`-shaped read-only
  dialog"). DESIGN.md:1215 assumes Cancel plus an action; the read-only variant is a Close alone and
  needs its own Fixed-strings row.
- **No form controls.** The whole client holds five `<input>`s — `command-bar.ts:136` (the filter),
  `data-table.ts:310` (the footer max-rows field), `command-box.ts:122`, `sign-in.ts:122` and `:139`
  — no `<select>`, no `<textarea>`, no date/time input, no label/fieldset/validation primitive.
  `namespace-switch.ts` (334 lines) is the closest listbox precedent. `@angular/material` reaches the
  client only through `src/styles/_theme.scss`, and `@angular/cdk` only through `data-table.ts`, so
  every control here is hand-rolled markup over the tokens. DESIGN.md:1064's `form-page`
  outlined-field rule is the only field vocabulary and is scoped to create/edit routes
  (EXPERIENCE.md:429, :362), so the criteria form inherits its field anatomy but none of its Save
  bar, unsaved-changes guard or validation grammar.
- `ui/src/app/shell/screen-outlet.ts:39-46` — `ARCHETYPE_PAGES` is `{home, list}` and is typed so
  every `BuiltArchetypeKey` is required; `'list (server criteria)'` already exists in the vocabulary
  (`Screen/Archetype.cls:66`, `screens.generated.ts:23`) and `ng build` fails until a page is
  registered for it.

**The pins that move** (a sixth list, and the Logs area's first screen)

- `src/OcuPilot/Test/Descriptor.cls:687` `$ListBuild("logs","%Admin_Operate:USE",0,0)`; `:682`/`:694`
  the eight-area counts; `:389` `Archetype.Count(), 16`; `:590` `EntityType.Count(), 26` — no
  vocabulary edit, `audit-record` is already declared (`Kernel/EntityType.cls:22`). **`:292-293` is
  the trap**: `TestAnAreaThatDoesNotCoverItsScreensPairsIsRefused` (from `:287`) asserts the refusal
  names `area 'logs'` and `%Admin_Secure:USE`, driven by `Test/AreaPair/Bad.cls:17,24` (area `logs`,
  pair `%Admin_Secure:USE`). Once `logs` declares that pair the fixture is covered; change the
  fixture's pair to one `logs` still does not declare, and move the assertion with it.
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
  before the pinned `1: ""` catch-all, an `AUDITLISTTOOL` parameter beside `:58`, doc `:442-451`, and
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

**The strings pipeline — what the tests actually enforce** (verified by reading `strings.test.mjs`)

- `:297-307` the literal band, `assert.ok(expectedLiterals.length >= 150 && expectedLiterals.length
  <= 178, …)` with the name "roughly 165"; the extractor finds the table by its `**Fixed strings**`
  anchor and `| String | Where |` header, not by line number, and counts **every** double-quoted span
  in column 1 **without de-duplicating**. Measured 164 today.
- `:333-348` the closed world: every `strings.ts` value must be in `expectedLiterals ∪
  EXTRACTED_FROM_PROSE ∪ REQUIRED_ALONGSIDE_TABLE`, **and** `Object.keys(strings).length` must equal
  the sum of those three lengths. `REQUIRED_ALONGSIDE_TABLE` is pinned at exactly 3 (`:361`) and is
  not a bypass. Consequence: one new key per new table literal, and **a new row may never repeat a
  literal the table already carries** — `:437-443` forbids duplicate values, so the cardinality would
  not balance.
- `:486-523` the citations: for every `/** EXPERIENCE.md:n */` above a key, line `n` of
  EXPERIENCE.md must literally contain `"<value>"`. Five entries cite at or beyond the insertion
  point and shift by exactly the number of rows inserted: `homeStarterPromptExplainScreen`,
  `homeStarterPromptExplainLog`, `homeStarterPromptChangeOneThing` (all `:321`),
  `proposalExpectedImpactExample` (`:322`), `auditMarkerDescription` (`:323`).
- Reusable keys, so these literals get **no** new row: `tableColumnDescription: 'Description'`
  (`strings.ts:336`), `processColumnPid: 'Process ID'` (`:350`), `processColumnUser: 'User'`
  (`:352`), `headerNamespaceLabel: 'Namespace'` (`:421`).
- Values reach a screen as keys, never as text: descriptors carry `labelKey` / `emptyStateKey`,
  resolved by `lookup` (`strings.ts:466-469`) in `data-table.ts:550` and `table-model.ts:201-212`.
  `client-lint.mjs`'s `checkTemplateLiterals` fails a quoted literal inside an interpolation but
  passes a bound expression, so descriptor-carried `options` values render legally.

**Browser tier and the thousand rows**

- `ui/browser/list-spec.mjs` — `waitForRows :30`, `viewCount :40` (`aria-rowcount − 1`, never DOM
  rows), `clearFilter :50`, `filterToSubset :74` (**leaves its text in the field** — clear before any
  cap assertion). `ui/browser.config.mjs:24` origin `http://localhost:52776`, `:36` readiness path,
  `:45` `LIVE_CONTAINER` the specs refuse. `ui/tools/angular-json.test.mjs:263-277` derives the
  `*.browser-spec.mjs` naming rule from content; `:301-303` forbids the string `52774`.
  `npm run test:browser` runs `browser/*.browser-spec.mjs` one file at a time in **name order** —
  `audit.browser-spec.mjs` sorts first, before `classic-link-card`.
- **Seeding precedent:** `ui/browser/tasks.browser-spec.mjs:53-62` `irisSession()` —
  `spawnSync('docker', ['exec','-i', config.container, 'iris','session','iris','-U','%SYS'], {input})`
  with `mark()` and `parseMarkers` (`ui/browser/iris-session.mjs:16`); `users.browser-spec.mjs:44-50`
  is the same helper creating and deleting three users and a role on the throwaway. Nothing in the
  repo creates bulk rows today.
- **Timing precedent:** exactly one, and it is not the instance —
  `ui/browser/data-table.browser-spec.mjs:141-151` (`Date.now()` around `page.goto` plus
  `waitForSelector('[role="grid"] [role="row"][aria-rowindex="2"]', {timeout: 2000})`) runs against
  the spec's own loopback stub server. `performance.now` has zero hits across `ui/`.

**Read-only evidence (live `ocupilot`, 2026-09-14, reads only)**

- 89,318 audit rows; `EventSource='OcuPilot'` 7,692 (3,247 `RoleGranted`, 4,445 `RoleGrantedProbe`);
  `Security.Events` holds exactly one `OcuPilot` row, `OcuPilot||Security||RoleGranted`.
- The classic page is **`%CSP.UI.Portal.Audit.View`** (`Parameter PAGENAME = "AuditList"`;
  `%CSP.UI.Portal.Audit.Detail` is its detail). Its own criteria form (`:74-100`) is a `select` for
  the audit namespace, two `dateText` fields, editable comboboxes for source/type/name/users/
  namespaces/system ids, plain text for PIDs and JSON String Search, a **`listBox`** for
  Authentications whose options it builds at runtime from `Security.System.AutheEnabled` through
  `AuthenticationLogicalToDisplay` (`:518-525`), and a Maximum Rows field — and no free-text field.
- `Test/AdminPortAsync.cls:66 TestTheSelfQueuedAuditListIsPolledToAnOrdinarySuccess` already drives
  this endpoint through the real port at `maxRows=1` and asserts 200, a `%DynamicArray` result and a
  forgotten task row; its header names the `%Admin_Operate:U` + `%Admin_Secure:U` pair.

## Tasks & Acceptance

**Execution:**

- `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md` — **first**, and
  before `strings.ts`: insert **four** Fixed-strings rows after `:320`, carrying exactly these **17**
  new literals and no literal the table already holds:
  1. `"Audit database"` · `"Time"` · `"Event source"` · `"Event type"` · `"Event name"` ·
     `"No events match."` — the side-bar entry and screen title (`:163`, `:88`), the column headers
     beyond the reused Description, User, Process ID and Namespace, and the empty state the
     `list (server criteria)` archetype row already names (`:532`).
  2. `"Begin date and time"` · `"End date and time"` · `"Authentication"` · `"Search"` · `"Any"` ·
     `"Comma-separated. * matches any name."` · `"Instance local time, as YYYY-MM-DD HH:MM:SS."` —
     the criteria form (`:88`, `:532`): the two time-range labels, the authentication label and its
     unset option, the Search control, and the two helper lines. The other six labels are reused
     keys: Event source, Event type and Event name from row 1, User and Process ID from `:319`, and
     Namespace from the namespace switch's accessible name (`:335`).
  3. `"Agent-marked events only"` — the marker filter (`:88`; an affordance, never a default, AD-46).
  4. `"Audit event"` · `"Event data"` · `"Close"` — the detail dialog's title, its payload label and
     its sole action (`:89`, `:173`, `:355`); Description is reused.

  Then re-resolve citations mechanically: **every** EXPERIENCE.md `:n` self-citation in the document
  that points at a line ≥ 321 moves by four (`:332`, `:335`, `:338`, `:341`, `:349`, `:365`, `:385`,
  `:532`, `:543`, `:602`, `:606` among them).
- `ui/tools/strings.test.mjs` — widen the `:297-307` band to admit **181** (`>= 150 && <= 200`) and
  update the test name and failure message from "roughly 165" so they do not lie; say in the comment
  beside it that Story 2.10 added 17. Leave `REQUIRED_ALONGSIDE_TABLE` at 3.
- `ui/src/app/core/strings.ts` — 17 new keys under an `audit*` prefix, each with its
  `/** EXPERIENCE.md:n */` comment pointing at the line that literally carries the quoted value; bump
  the five comments now citing `:321`-`:323` to `:325`-`:327`. No value may collide with an existing
  one.
- `src/OcuPilot/Screen/Registry.cls` + `ui/tools/screen-mirror.mjs` — the `read.criteria` grammar and
  `CriteriaProblem` / `criteriaProblem`, one refusal sentence per rule, called from `Validate` after
  `ReadProblem`. Add `src/OcuPilot/Test/CriteriaCorpus.cls` and drive both engines from it.
- `src/OcuPilot/Screen/Read.cls`, `src/OcuPilot/Api/ScreenRead.cls`,
  `src/OcuPilot/Screen/Tool/Read.cls`, `ui/src/app/core/screen-read.ts` — carry the declared criteria
  from the route to the port and into the tool schema; refuse an off-list `choice` value before the
  port call; correct `ScreenRead.cls:9-10` at origin.
- `src/OcuPilot/Screen/Area.cls` — append the two pairs to `logs` and correct `:15-17`, `:22-24`.
- `src/OcuPilot/Screen/Descriptor/AuditList.cls` — new. Route `logs/audit`, area `logs`,
  `sideBarPosition` 4 (EXPERIENCE.md:163 lists Audit database last), archetype
  `list (server criteria)`, `built` true, `refreshes` false, privileges in the declared order,
  `entityType` `audit-record`, scope `instance`, `id` composite over
  `UTCTimeStamp, SystemID, AuditIndex`, `primaryAction` and `rowActions` empty, `classicPage`
  `%CSP.UI.Portal.Audit.View`, `classicLinkExemption` not exempt, `toolIdentifier` `logs.audit`,
  `read.fields` all 24, `context.fields` excluding `EventData`, `read.criteria` as in the Code Map,
  `emptyStateKey` the "No events match." key, and `table.columns` Time · Event source · Event type ·
  Event name (the one `name` kind) · User · Process ID · Namespace · Description.
- `ui/src/app/shell/dialog.ts` (+ `ui/src/styles/_components.scss`) — the first `role="dialog"`:
  focus trap, initial focus, focus return to the opener, Escape through `OverlayStack.closeTop()`,
  `aria-modal`, scrim, no stacking.
- `ui/src/app/areas/logs/audit.page.ts` (+ its store) and `ui/src/app/shell/screen-outlet.ts:43-46` —
  the `list (server criteria)` page: criteria form above the table (text, datetime and the one
  `choice` rendered as a native `<select>` whose first option is the "Any" label), Search, the
  marker-filter affordance that overrides and disables Event source, no read before Search, and the
  id route opening the dialog.
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
- One unit test per I/O-matrix row that is not covered by an AC leg: the empty-criterion omission,
  the midnight end-time rule, the cap, the vendor cap trap, and the self-auditing read.

**Acceptance Criteria:**

- **Given** a caller holding all three pairs, **when** the Audit database screen opens at
  `logs/audit` and Search is pressed with a begin date-time, **then** no rows and no skeleton appear
  before Search; the read runs through `AdminPort`'s self-queued async path and returns rows the
  table lists under their declared columns; and the footer's max-rows field re-reads at the new cap.
  *(Integration AC — driven through the route against a real instance, not a fixture.)*
- **Given** the agent-marker filter, **when** it is applied over the same criteria, **then** the read
  carries `eventSources=OcuPilot`, the Event source field goes unavailable, and the view narrows to a
  proper non-empty subset; **and** with the filter off the same search returns strictly more rows,
  OcuPilot's own events among them, the filter never being the default (AD-46). *(Integration AC.)*
- **Given** a result row, **when** it is opened, **then** a read-only `role="dialog"` shows the
  event's description and its JSON payload, traps focus, closes on Escape and on Close, returns focus
  to the opener, and leaves Ctrl/Cmd+K, +I and +B inert while it is open.
- **Given** criteria that match nothing, **when** the read succeeds with zero rows, **then** the
  screen reads "No events match." rather than the generic empty message, with no skeleton and no
  fault state.
- **Given** a real principal on the throwaway holding `%Admin_Secure:USE` and `%DB_IRISSYS:READ` but
  not `%Admin_Operate:USE`, **when** it searches, **then** it is refused at the screen's own gate
  with `%Admin_Operate:USE` named as the failing pair, on-screen data stays, and — because nothing
  reached the port — **no `%Api.Admin.Util.AsyncTask` row is left behind**; **and** the principal
  holding all three is served. *(DW-249: declaring the poll's own pair is what moves the refusal in
  front of the queue.)*
- **Given** a throwaway seeded to at least a thousand audit rows, **when** Search runs at a
  1,000-row cap, **then** `aria-rowcount` reaches 1,001 and the first data row is in the DOM within
  two seconds of the Search press. *(DW-258, NFR-1 end to end — the first such measurement against
  IRIS rather than a stub.)*
- **Given** an `authentication` value outside the declared options — sent on the route and again
  through `logs.audit.read` — **when** the read is executed, **then** it is refused by name and no
  LIST is queued, so an unrecognized mechanism can never widen the result the way the vendor's own
  `-1` conversion would.

### Review Findings

Code review, 2026-09-15, four layers (blind hunter, edge-case hunter, verification-gap, acceptance
auditor) at the `full-opus` tier. No high. Ten patched, four closed terminal in the ledger, the rest
closed here with a reason.

**Patched.**

- **DW-280 (the lead's named fix).** `Read.SeedCriteria` now requires a `datetime` criterion to
  carry its time part and refuses a date alone by name — 400 `READ.CRITERION`, before the port, on
  the one path the route and the read tool both cross. The tool's schema description says so. This
  makes the matrix row's own claim ("the form always sends an explicit time") true rather than
  aspirational, and it is the reading the row now states. QA's pin is flipped to the corrected
  behaviour, mutation red alone.
- **A vacuous assertion in `Test.WireSecurityRead`.** `tMarked.rows.%Size() <= tUnfiltered` compared
  two reads capped at 25 over populations one of which contains the other: true for every possible
  implementation, the criterion ignored included. Replaced with a foreign-Source count over the
  unfiltered page, which with the wrong-Source scan beside it is what says the filter narrowed.
- **The criteria form used the native `disabled` attribute** for a control the marker overrides.
  EXPERIENCE.md's Accessibility Floor, through Privilege Gating > Mechanism, says `aria-disabled` in
  the tab order and never that attribute, with the reason announced — and names "nothing selected"
  as the same mechanism, so it is not a privilege-only rule. Now `aria-disabled` + `readonly`, with
  the marker's own label as the announced reason (no new string) and the 38% rule keyed to the ARIA
  state. The value is dropped in the handler too, since the control still fires.
- **The dialog deviated from DESIGN.md's `confirm-dialog` tokens**: `padding: 20px` and
  `--ocu-radius-md` where `{spacing.6}` and `{rounded.lg}` are specified, on the component every
  dialog EXPERIENCE.md:173 whitelists inherits.
- **`Dialog`'s `aria-labelledby` target id was a constant**, which the route-driven open and close
  can make ambiguous for a change detection; now per instance.
- **Two absence assertions in `Test.Descriptor` were substring matches over the node's JSON**,
  twenty lines below a comment forbidding exactly that. Now structural over the walked roster.
- **Three claims corrected at origin**: the descriptor called its eleven authentication options "the
  eleven mechanisms FR-61's roster names" (FR-61 names the criterion, not its values) and left the
  thirteenth query parameter unaccounted for; the spec's Design Notes called them "the full display
  vocabulary" after review had measured 21; and the spec's `EventData` constraint still said the
  model does not see it after the descriptor had been corrected to say it does.
- **`Test.AuditRead`'s header counted three methods and had four**, and its cap method's doc claimed
  to observe the vendor's own unbounded SQL. The assertions observe the OcuPilot half; no assertion
  can redden if the vendor bounds its own query, and the doc and `## Verification` now say so.
- **`navigation-wire.test.mjs`'s header still read "three allowed, five denied"** after this story
  moved `logs` into the denied set; its `rail-wire.spec.ts` twin had been corrected and it had not.
- **Three figures in `## Verification` disagreed with their own twins in `## Auto Run Result`** for
  the same run (file count, `npm test` totals, throwaway test count); corrected at origin.

**Closed with a reason.**

- **AD-24's per-field bound** — the read tool's payload carries an unbounded `EventData` blob, which
  is an AD Rule mismatch and so a Rule 6 high by the letter. It is `routed` on DW-281 to the context
  cap story (4.4) and is unimplemented project-wide, not introduced here; not re-filed.
- **DW-283 to DW-286** — the dialog's real-browser geometry, the dialog route's two unhandled edges,
  the smoke check's unbounded vendor scan, and the route handler's untested allow-list. Each is
  closed terminal in the ledger with what would make it real.
- **"`Test.ScreenRead` materializes the whole audit database"** — filed by a layer, measured rather
  than argued: the class's live leg over all six admin/LIST descriptors runs in 77 ms against this
  instance's 89,318 audit rows. Not filed.
- **The command bar's filter and sort are live before Search** — the spec makes them client-side
  within the cap and the table is absent until Search, so they act on nothing; a guard is a product
  addition, not a correction.
- The remaining layer findings were prose restatements of entries this spec already carries.

**Re-verified after the patches.** `check-objectscript` 195 files / 16 rules / 0 problems ·
`npm run build` (six prebuild checkers) · `npm test` 715 + 273 green · live `ocupilot-iris`
(one `iris_execute_tests` per message) `Test.AuditRead` 4/4, `Test.Descriptor` 27/27,
`Test.ReadTool` 19/19, `Test.ScreenRead` 19/19 · throwaway `ci-runner.mjs` **51 classes / 483 tests
/ 0 failed**, no probe leftovers, no overlap, no foreign run · `audit.browser-spec.mjs` 7/7 and the
full `npm run test:browser` **50/50** · `smoke.sh --container ocupilot-ci` `executed=16 passed=16
failed=0 pending=2`, PASSED. Throwaway torn down. Live `ocupilot` was read-only apart from the
vendor's own self-audit row, which every audit read writes wherever it runs.

## Spec Change Log
- 2026-09-15, code review (Rule 5 apply-and-report: the observable is unchanged, the mechanism it
  cited was wrong): the "Queued-but-refused poll" matrix row is renamed "Refused before the queue"
  and its error-handling cell no longer cites `AwaitTask:649-651` as this screen's path. AC5 says
  the refusal lands at the screen's own gate. The screen declares `%Admin_Operate:USE`, so nothing
  is ever queued and the orphan row the old wording named cannot exist here; DW-249's port
  behaviour is unreached from this screen and stays live for one that does not declare the pair.
- 2026-09-14, lead (owner-delegated decision on the plan's intent gap): reading (a) taken. The ninth criterion is struck at its three origins - `prd.md` FR-61, `epics.md` FR-61 and Story 2.10 AC1, and EXPERIENCE.md's screen row - because the audit API has no free-text search and its one text-shaped parameter (`JSONSearch`) is a mode that forces the event type to SQL. That parameter is recorded as a deliberate non-goal (ledger, `wontfix-accepted`). The story stays one story: `multiple-goals` is accepted, since the criteria form, the dialog and the async read are one screen's worth of surface. Re-plan the criteria roster and its strings rows against the amended text; nothing else changes.

## Review Triage Log

### 2026-09-14 — Review pass

- verdicts: 38 findings — high 1, medium 9, low 21, false 6, maybe-false 1
- findings:
  - `[medium]` `[patch]` `AuditSearch` is the one per-principal holder the sign-out teardown does not drop — verified: `app.ts` resets five and not this one. Added `AuditSearch.reset()` and the sixth teardown line; pinned in `app.spec.ts`, mutation observed red.
  - `[low]` `[reject]` the archetype store is a root singleton shared by every `list (server criteria)` screen — real but no second such screen exists, and the spec's own `deferred:` list already carries it; a per-descriptor key is a design change, not a correction.
  - `[medium]` `[patch]` a criterion may claim `filter`, `sort`, `direction` or `ns` and silently replace the tool's own schema property or forward the scope key — verified by reading `InputSchema`'s ordering and `ScreenRead.Handle`. Reserved set widened in both engines with four new corpus cases.
  - `[medium]` `[defer]` a criterion value over the vendor's column length fails inside the task save as a 500 — verified live: an 83-character `pids` answers `500 INTERNAL`. Smallest fix is a `maxLength` grammar addition the spec does not settle.
  - `[low]` `[reject]` nothing binds `read.criteria` to the `list (server criteria)` archetype in either direction — a mis-declared archetype renders no criteria form at all, so it announces itself at the first render rather than silently; the bidirectional half is a design question.
  - `[medium]` `[patch]` `Test.Descriptor`'s "Authentication is read" assertion cannot fail — verified: `read.%ToJSON()` contains the criterion's `auditCriteriaAuthentication` label key. Replaced with structural walks over `read.fields` and `table.columns`; mutation observed red.
  - `[medium]` `[patch]` `WireSecurityRead`'s marker leg passes on zero rows — verified: only `tWrongSource` is asserted, and the comment claims a bound it does not have. Added the lower bound and an upper one against the unfiltered count.
  - `[low]` `[patch]` AC6's timing assertion is unreachable because the wait and the budget are the same constant — the leg still reddens, but on a selector timeout rather than the measured figure. Wait raised to five times the budget.
  - `[low]` `[patch]` `Dialog` documents an `actions` projection slot it does not have — corrected at origin.
  - `[low]` `[patch]` `Dialog`'s initial-focus selector does not exclude disabled controls, unlike its trap's — `:not([disabled])` added; unreachable today, since this dialog has no fields.
  - `[low]` `[reject]` the Shift+Tab arm's `!contains(active)` branch is dead — true, and it is a cheap safety net; deleting it buys nothing.
  - `[false]` `[reject]` a dialog whose parent navigation never completes is permanently inert — the close navigates to the screen's own bare route, which has no guard and cannot fail.
  - `[low]` `[patch]` the descriptor claims a `rowGet` would "learn nothing" — verified: `RunGet` converts `Authentication` through `$$AuthenticationLogicalToDisplay`, a value the LIST does not carry. Corrected at origin.
  - `[low]` `[reject]` the dialog renders 2 of the 24 fields read — AC3 specifies the description and the payload; spec-bound, closed by-design.
  - `[low]` `[reject]` the marker affordance is absent from the read tool's schema — the marker overrides a declared parameter, so the tool can express it as `eventSources=OcuPilot`; a named affordance is a product addition.
  - `[medium]` `[defer]` EXPERIENCE.md citations in source no longer resolve — verified: five cited values now land on blank lines. Also verified that the same citations did not resolve before the shift either (`side-bar.ts:530`, `Archetype.cls:409`, `namespace-switch.ts:552`, `app.ts:594`), so a blanket `+4` would move already-wrong pointers; DW-272 owns the class. The one this story authored (`audit.browser-spec.mjs` `:530`) was corrected to `:359`.
  - `[low]` `[reject]` the smoke run has no outcome for an instance with no audit rows — every one of the six area-list checks requires exactly one row, so the shape predates this story; an empty audit database is an operator state the check reports as a failure by the same rule as an instance with no SSL configuration.
  - `[low]` `[patch]` `Test.AuditRead`'s preconditions fail opaquely — the read's status is now carried into the message.
  - `[false]` `[reject]` two getters do O(rows) work per change detection — `detail` returns early unless the id route is active, so the `find` runs only with a dialog open; `criteria` builds nine objects.
  - `[false]` `[reject]` an unparseable `datetime` criterion raises `<ILLEGAL VALUE>` and answers 500 — probed live with four malformed values (`not-a-date`, `2026-13-45 99:99:99`, `'; DROP`, `99999999`): every one answers 200 with zero rows.
  - `[medium]` `[patch]` (duplicate of the `AuditSearch` sign-out finding) — same root cause, same fix.
  - `[low]` `[reject]` a max-rows change re-reads with criteria edited since Search — the re-read is one the user initiated by changing the cap; a snapshot-at-Search mechanism is a design change.
  - `[low]` `[reject]` (duplicate of the shared-singleton finding) — same root cause, same disposition.
  - `[false]` `[reject]` a `choice` criterion with no `options` throws `<INVALID OREF>` out of `InputSchema` — both engines refuse such a descriptor before it can ship, and no fixture declares one.
  - `[low]` `[reject]` (duplicate of the empty-audit-database smoke finding) — same root cause, same disposition.
  - `[medium]` `[patch]` no executing test drives `Tool.Read.View`'s criteria path — filed pre-verified by the gap layer. Added `TestTheReadToolSendsItsDeclaredCriteriaToThePort`, driven through the port fixture; mutation observed red alone.
  - `[medium]` `[patch]` `Registry.Validate`'s criteria arm has no fixture-registry pin, unlike every other grammar rule — filed pre-verified. Added `Test/Criteria/Bad.cls`, `Test/CriteriaRegistry.cls` and `TestCriteriaOutsideTheGrammarAreRefusedByTheRegistry`; mutation observed red alone.
  - `[medium]` `[patch]` the descriptor claims the model never sees `EventData`, and the read tool returns it — verified: `Tool.Read.View` answers `read.fields` minus secrets, which `TestTheToolViewIsTheRouteReadNarrowed` has pinned since Story 2.3 and which AD-36 specifies. The claim, not the code, was wrong; corrected at origin, and the unimplemented half of AD-24 (no per-field truncation anywhere) is deferred.
  - `[high]` `[patch]` leaving the screen after a Search and returning renders a skeleton nothing resolves — verified by construction: `bind` clears `hasLoaded` on a full re-bind, `transition()` issues no read, and this archetype has no timer. Added a conditional `readNow()` and a `revisit` case in `audit.page.spec.ts`; mutation observed red alone.
  - `[low]` `[reject]` `AuditPage` renders no banner strip and the grammar does not refuse `banner` beside `criteria` — this descriptor declares none and `Test.Descriptor` pins that; a future screen's missing banner announces itself at the first render.
  - `[low]` `[patch]` the option-count assertion derives its expected value from the declaration it renders, with a `?? 0` fallback — replaced with the literal 12.
  - `[low]` `[reject]` AC2's `kept > 0` and `kept < total` cannot fail after `waitForCount` — true; `waitForCount` is the falsifiable bound and `kept === markerRowCount()` is an independent one, both of which the mutation record reports going red.
  - `[low]` `[reject]` `CriteriaProblem` is asserted twice in one method with no intervening mutation — harmless restatement.
  - `[low]` `[reject]` the grammar is generic but the page's copy and dialog fields are this screen's — true and recorded in the spec's own `deferred:` list for the store; the copy half is the same entry's substance.
  - `[medium]` `[defer]` "the form always sends an explicit time" is implemented as a hint line, not as a control constraint — real, and the fix is a `datetime` control the spec does not specify.
  - `[low]` `[reject]` AC5 asserts at the gate rather than at the poll — already recorded in this spec's `deferred:` list as DW-249.
  - `[medium]` `[patch]` the descriptor calls its eleven options the vendor's "full display vocabulary" — verified live: the build round-trips 21 display names, and two mechanisms present in the live rows are undeclared. Corrected at origin; the eleven-name roster itself is spec-bound.
  - `[low]` `[reject]` the table's default sort is `TimeStamp` rather than `UTCTimeStamp` — both sort chronologically as strings, and the vendor order the matrix names is the server's.
  - `[low]` `[reject]` the strings band was widened to 200 rather than to just admit 181 — the spec's task list specifies `>= 150 && <= 200` verbatim.

## Design Notes

**Governing architecture decisions (Rule 6).** AD-2 and AD-27 (`AdminPort` is the only caller of
`%Api.Admin.*`; `TYPESUFFIXES` is what keeps `TYPECOPY` and `TYPEPURGE` unreachable) · **AD-26** (the
two async paths; this is the self-queued one it names by class) · AD-5 (one descriptor is the source
of route, gate, read tool and table) · AD-8 (the pair set is an AND, checked per call, a denial names
the pair) · AD-11 and AD-24 (`EventData` is untrusted and unbounded, so it stays out of context) ·
AD-13 (the scoped triple; the composite id in one segment) · **AD-21** (the declared criteria roster
is the allow-list, no caller key reaches the port, and a `choice` value is validated against a fixed
enum rather than passed through) · AD-15 (the marker's Source) · **AD-29 as twice amended** (the pair
set is established from the backing class's own check *and* a least-privileged principal — here both
agree on `%Admin_Secure`, and `AsyncResult`'s separate gate is what adds `%Admin_Operate`) · AD-36
(one read serves screen and tool; no `rowGet`) · AD-39 (the port normalizes vendor **error** text —
it says nothing about result values, which is why `Authentication` is left unrendered rather than
converted) · AD-43 (this screen is **not** in EXPERIENCE.md:543's refreshing roster) · AD-44 (a
`list` archetype never links out; the descriptor declares `%CSP.UI.Portal.Audit.View`) · **AD-46**
(OcuPilot's own rows are never hidden; the marker filter is an affordance) · AD-45 (one smoke path).
AD-6, AD-10, AD-14, AD-30, AD-34 and AD-40 are not reached: this story writes nothing.

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
which Rule 19 forbids and which the epic's own marker AC (`epics.md`: "the filter existing here from
build step 1 so that Epic 5's first confirmed write has somewhere to be found") rules out. A Source filter is
falsifiable today against the installer's own 7,692 rows and admits 5.6's rows unchanged. *(inference:
that 5.6 will emit under the same Source — AD-15's Rule is the evidence.)*

**Why `authentication` is the one `choice` and its options are static.** The vendor's own page builds
its Authentications `listBox` from `Security.System.AutheEnabled` — the *instance's enabled*
mechanisms, which differ per instance — so a descriptor pinning that subset would pin this container.
The declared options are instead eleven display names the conversion functions round-trip (of 21 the
build round-trips — a subset, not the whole vocabulary), so selecting a mechanism the instance does
not use returns no rows (honest) rather than everything (the `-1` trap). The eleven names are **vendor vocabulary carried as descriptor data**, the same
status a namespace name has in `namespace-switch` — not OcuPilot copy — so only the field label and
the "Any" option label take Fixed-strings rows.

**How NFR-1 applies to an archetype that does not auto-load.** NFR-1 (`prd.md:1068`) measures "a list
screen renders its first page within two seconds of navigation". This screen renders nothing on
navigation by design (EXPERIENCE.md:532), so the equivalent event is the **Search press**; AC6 is
that reading, not a weakening. Because `MaxRows` never bounds the vendor's SQL (matrix row), the
elapsed time tracks the **matching** population rather than the cap, which is why the throwaway is
seeded to roughly the cap and not to ten times it, and why AC6's leg asserts the seeded count first.

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
ungated) is why the four-line shift has to be re-resolved by hand rather than caught by a test.
**DW-276** (the sort control is unasserted on the earlier lists) is `wontfix-accepted`. **DW-274**
(the port answers 500 where a query's own privilege refusal should be a named 403) does not bite here:
both gates this screen crosses refuse with a status the port maps.

**Declined DW-n:** none. DW-249 is addressed by AC5 and the "Queued-but-refused poll" matrix row;
DW-258 by AC6 and the "Thousand rows" row. DW-277 is terminal and is not re-opened.

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

**Mutations (Rule 19) — one per AC. Apply, observe red, revert, and confirm `git status --short`
and `git diff --stat` are byte-identical to the pre-mutation snapshot.** Every line below was run;
each `mutation:` records what was changed, what went red, and at which tier. The tree was compared
against the snapshot after the last revert and is byte-identical.

- AC1 — mutation: drop the `beginDateTime` entry from the descriptor's `read.criteria.fields` and
  regenerate → `screen-mirror.test.mjs`'s criteria-roster pin red on the declaration
  (`the eight criteria FR-61 names, over nine parameters, in declaration order`), and only it;
  `Test.Descriptor`'s `TestTheAuditListValidatesAndDeclaresItsServerCriteria` holds the same roster.
  Second witness: make `Read.SeedCriteria` validate but never write into `pQuery` → `Test.ReadTool`'s
  `TestAnOffListChoiceIsRefusedBeforeThePortIsCalled` red **alone**, on `and is seeded under the
  vendor's own parameter name` — which is what distinguishes a real server search from a form that
  changes nothing.
- AC2 — mutation: change `read.criteria.marker.value` to `NoSuchSource`, regenerate, rebuild the
  throwaway → the browser marker leg red on the **lower** bound (`a proper non-empty subset of 1007;
  the view held -1`), and `screen-mirror.test.mjs`'s marker pin red at the unit tier.
  Second: make `AuditSearch.criteria` append the marker's value to the criterion instead of
  overriding it → the same leg red on the **upper** bound (`a proper non-empty subset of 1005; the
  view held 1005`), which is the whole reason it overrides. Both directions required, both observed,
  and no other leg moved for either.
- AC3 — mutation: remove `overlays.push` from `Dialog`'s constructor → `dialog.spec.ts`'s "closes on
  Escape, through the one overlay authority, and never stacks" red **alone** (1 of 272). Second:
  remove the `opener.focus()` from the destroy hook → "closes on its action, and returns focus to the
  opener" red **alone** (1 of 272).
- AC4 — mutation: point `emptyStateKey` at `webAppListEmpty` and regenerate → `audit.page.spec.ts`'s
  "a zero-row answer reads the screen's own empty sentence" red **alone**, naming the wrong sentence.
- AC5 — mutation: remove `%Admin_Operate:USE` from the descriptor **and** the `logs` area and
  rebuild the throwaway → `Test.WireSecurityRead.TestTheAuditListsPairSetIsEnforcedForARealPrincipal`
  red, 1 of 6, on all four denial assertions, because the search is no longer refused by name.
  Second witness: remove `%Admin_Secure:USE` from the area alone → five `Test.Descriptor` tests red,
  each naming `OcuPilot.Screen.Descriptor.AuditList: area 'logs' does not declare %Admin_Secure:USE,
  which this screen requires`.
- AC6 — mutation: seed eleven rows instead of a thousand, under a Source of its own so the top-up
  cannot find an earlier run's → the timing leg red on its **own precondition** (`the instance holds
  at least a thousand rows under OcuPilotSeedSmall to read: 11`), before any duration was measured.
  The leg's two count assertions are written as the literal 1,000 and 1,001 rather than as
  `SEED_ROWS`, so a seed constant lowered on its own cannot take them down with it.
- AC7 — mutation: make `Read.SeedCriteria` pass a `choice` value through without checking it against
  `options` → `Test.ReadTool`'s off-list test red **alone**, on the refusal, the 400, the
  `READ.CRITERION` code and "no endpoint was constructed". Second witness: drop `options` from the
  sound `choice` case in `Test/CriteriaCorpus.cls` → both engines' criteria tests red on
  `every declared kind is admitted`, with the missing-options sentence.

**The three matrix rows the task list routes to their own unit test, not to an AC leg**, are
`src/OcuPilot/Test/AuditRead.cls`, which issues the shipped read through the real port:

- "End time at midnight" — `TestAnEndTimeAtMidnightIsRolledBackToThePreviousDay`. The explicit-end
  count is asserted first, so two reads that both answered nothing cannot pass for it.
- "Cap honoured" and the observable half of "Vendor cap trap" —
  `TestTheRowCapBoundsTheAnswerAndNotThePopulation`: the cap bounds the answer, out of a population
  read back wider than it. That the vendor's own SQL is unbounded is read from `Audit.cls`, not
  observed here: no OcuPilot behaviour changes with it, so no assertion would redden if the vendor
  bounded its own query. It is still the fact AC6's seeding is sized around.
- "Self-auditing read" — `TestTheAuditReadRecordsAnAuditEventOfItsOwn`: the recorded event names a
  token unique to the run, so neither read that looks for it can satisfy it.
- mutation: make `Read.SeedCriteria` validate without writing into the query → the midnight test red
  on the rolled-back bound and the self-auditing test red on the unrecorded token, the cap test
  green. mutation: remove `If tSurviving = tMax Quit` from `Read.Execute` → the cap test red alone.
  Both applied, observed, reverted; the tree and the two files re-checksummed identical afterwards.

**Review pass (2026-09-15) — mutations for the two patches that changed behaviour.**

- DW-280 — mutation: remove the `datetime` arm from `Read.SeedCriteria` → `Test.AuditRead`'s
  `TestABareDateEndTimeIsRefusedRatherThanSilentlyDroppingThatDay` red **alone** (1 of 4), on all
  four refusal assertions. Reverted; the class re-read 4/4.
- Criteria-form availability — mutation: restore `[disabled]="field.unavailable"` on the criterion
  input in place of the `aria-disabled` / `readonly` / `aria-describedby` bindings →
  `audit.page.spec.ts`'s "the marker overrides the criterion it names" red **alone** (1 of 273).
  Reverted; the file re-read byte-identical.
- The marker leg's replaced assertion is pinned by AC2's own recorded mutation: stop
  `SeedCriteria` writing the value and the wrong-Source scan reddens. The foreign-Source count
  beside it is what makes that scan mean narrowing rather than an empty search.

**What each command actually reported.**

- `uv run scripts/check-objectscript.py` — 195 files, 16 rules, 0 problems.
- `cd ui && node tools/screen-mirror.mjs` — the sixth descriptor appears; the regenerated mirror is
  staged (`+305` lines).
- `cd ui && npm run build` — the six `prebuild` checkers pass, `screen-mirror.mjs --check` included.
- `cd ui && npm test` — 715 `node --test` assertions and 273 component tests green, with
  `navigation.test.mjs`, `navigation-wire.test.mjs`, `screen-mirror.test.mjs`, `strings.test.mjs`,
  `screen-read.test.mjs`, `rail-wire.spec.ts` updated, and `dialog.spec.ts` and
  `audit.page.spec.ts` new.
- `bash scripts/lint-docs.sh` — 0 markdownlint issues, 0 prose problems over 19 files.
- IRIS MCP (`server: "ocupilot-iris"`), one `iris_execute_tests` call per message: `Test.Descriptor`
  26/26, `Test.ReadTool` 18/18, `Test.ScreenRead` 19/19, `Test.Navigation` 11/11,
  `Test.AdminPortAsync` 2/2, `Test.Smoke` 20/20, `Test.AuditRead` 3/3.
- Throwaway (`ocupilot-ci`, origin `http://localhost:52776`): the whole ObjectScript suite through
  `node tools/ci-runner.mjs --container ocupilot-ci` — **51 classes, 482 tests, 0 failed**, no probe
  leftovers, no overlap, no foreign run; `browser/audit.browser-spec.mjs` 6/6; the full
  `npm run test:browser` **49/49**. Torn down with `sh scripts/ci-throwaway.sh down`.
- `bash scripts/smoke.sh --container ocupilot --user _SYSTEM --password SYS` — the live instance's
  own six area-list checks, `executed=15 passed=15 failed=0 pending=2 skipped=1`, PASSED.
- `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS` — **six** area-list
  checks including `audit`, `executed=16 passed=16 failed=0 pending=2`, PASSED; the `arealists`
  pending note is gone.

**Live `ocupilot` was read-only throughout.** No audit configuration was changed, no audit row was
deleted, no principal was created, and `docker compose up`/`down` was never run against it. Its
source was loaded and compiled through the IRIS MCP tools, which is how this project builds. Every
audit row this story wrote, and both new principals, were on `ocupilot-ci` and died with it.

### QA follow-up (2026-09-15) — new tests (QA)

Closed two of the three named gaps; the third (the dialog's real-browser proof) needed no new test
because the existing AC3 leg already drives it.

- `ui/browser/audit.browser-spec.mjs` (QA) — new test **"AC1 regression: leaving the audit screen
  after a Search and returning re-reads automatically, with no skeleton left stuck"**. Drives the
  HIGH finding's fix (the follow-up review's own named gap) through the shell's real SPA
  navigation — the Home rail item, then the Logs side bar's one entry — rather than the jsdom stub
  `audit.page.spec.ts` used. Mutation: comment out the `if (this.search.searched() &&
  !this.refresh.hasLoaded())` guard's `void this.refresh.readNow()` in
  `ui/src/app/areas/logs/audit.page.ts` → red alone, a `TimeoutError` at the row-appears wait (the
  skeleton the fix exists to resolve never resolves). Reverted; `git status --short` and
  `git diff --stat` confirmed byte-identical before recompiling; rebuilding after the revert
  reproduced the identical output chunk hash (`main-HFR62RF6.js`) the pre-mutation build produced.
  Verified against the throwaway: the new leg alone (996 ms), the full `audit.browser-spec.mjs`
  (7/7), and the full `npm run test:browser` (**50/50**).
- `src/OcuPilot/Test/AuditRead.cls` (QA) — new method
  **`TestABareDateEndTimeIsAlsoSilentlyRolledBackToThePreviousDay`**, pinning DW-280's current
  behavior (not a fix — DW-280 stays open, owned by the code reviewer): a bare `endDateTime` with
  no time part reaches `$zdatetimeh(...,3,...)` the same way an explicit `00:00:00` does, so it is
  rolled back to the previous day and silently drops that day's events. Mutation: make
  `OcuPilot.Screen.Read.SeedCriteria` validate without writing into the query → red alone, on the
  rollback assertion. Reverted; `git status --short` / `git diff --stat` confirmed byte-identical.
  Verified on `ocupilot-iris` (live, read-only precedent already established by this class's other
  three methods): `Test.AuditRead` 4/4 before and after.
- **Dialog real-browser proof — no new test.** The existing `ui/browser/audit.browser-spec.mjs`
  AC3 leg drives **three** of the four properties in a real browser, and the fourth by a different
  mechanism: focus moves into the dialog on open (`focusedInDialog` checked immediately after
  `[role="dialog"]` appears); focus is trapped while it stands — but this dialog has one focusable
  element, so the Tab probe exercises `first === last` and the wrap-around and Shift+Tab arms are
  jsdom-only (the chord probe is not trap evidence: Ctrl/Cmd+K/I/B move no focus either way);
  Escape closes it (through the overlay stack, with the URL and grid focus
  re-checked after); and focus returns to the opener side (`[role="grid"]`, per `audit.page.ts`'s
  own documented reason its close hands focus to the grid rather than relying on `Dialog`'s
  built-in opener-restore, which this screen's route-driven open/close cannot use — the opener
  element is destroyed by the navigation before `Dialog`'s own destroy hook could restore it).
  `dialog.spec.ts` already pins `Dialog`'s own generic opener-restore and wrap-around trap at the
  jsdom tier for a component whose parent does not destroy on open. Re-ran `audit.browser-spec.mjs`
  AC3 (`node --test`) to confirm it still passes: it does, unchanged.

Commands run for this pass: `uv run scripts/check-objectscript.py` (195 files, 16 rules, 0
problems, unchanged), `cd ui && npm test` (715 `node --test` + 273 component tests, unchanged),
`cd ui && npm run build` (baseline and post-mutation, each clean), IRIS MCP
(`server: "ocupilot-iris"`) `iris_doc_load` + `iris_execute_tests` on `OcuPilot.Test.AuditRead`
(one call per message, each run's `runIndex` read back before the next), `sh
scripts/ci-throwaway.sh up` / `sh scripts/wait-readiness.sh` / `OCUPILOT_BROWSER_EXECUTABLE="/Applications/Google
Chrome.app/Contents/MacOS/Google Chrome" node --test browser/audit.browser-spec.mjs` and
`npm run test:browser` / `sh scripts/ci-throwaway.sh down`. Live `ocupilot` was read-only
throughout this pass too, aside from the same self-auditing side effect `Test.AuditRead`'s other
methods already carry; every mutated bundle and container restart was on `ocupilot-ci`, which was
torn down at the end.

## Auto Run Result

Status: done
Blocking condition: none

**What shipped.** A sixth list screen on a sixth archetype, and four surfaces with it: the
`read.criteria` grammar (both engines, one shared corpus, one refusal sentence per rule); the Logs
area's first screen and its real three-pair privilege set; the client's first `role="dialog"`; and
DW-258's thousand-row NFR-1 measurement against IRIS rather than a stub. The roster is the
allow-list on both callers -- `ScreenRead.Handle` reads a query key only where the descriptor names
it, and the read tool publishes one property per criterion -- and a `choice` value outside its
declared options is refused 400 `READ.CRITERION` before the port is called, which is what keeps the
vendor's `-1` conversion unreachable.

**Files changed.** `Screen/Registry.cls` + `ui/tools/screen-mirror.mjs` (the grammar and its twin) ·
`Test/CriteriaCorpus.cls` (39 cases, both engines) · `Screen/Read.cls` (`CriteriaParams`,
`SeedCriteria`) · `Api/ScreenRead.cls`, `Screen/Tool/Read.cls`, `core/screen-read.ts` (the two
callers) · `Api/Error.cls` (`READ.CRITERION`) · `Screen/Descriptor/AuditList.cls` (new) ·
`Screen/Area.cls` (the Logs pairs) · `shell/dialog.ts` + `_components.scss` (the modal) ·
`areas/logs/audit.page.ts` + `audit.store.ts` + `shell/screen-outlet.ts` (the archetype page) ·
`app.ts` (the sixth sign-out teardown) · `EXPERIENCE.md` + `core/strings.ts` + `tools/strings.test.mjs`
(four Fixed-strings rows, 17 literals) · `Install/Smoke.cls` (the sixth area-list check, the
`arealists` note deleted) · the pins in `Test/Descriptor`, `Test/ReadTool`, `Test/Navigation`,
`Test/Wire`, `Test/WireSecurityRead`, `Test/Smoke`, `Test/AreaPair/Bad`, `navigation.test.mjs`,
`navigation-wire.test.mjs`, `rail-wire.spec.ts`, `screen-mirror.test.mjs`, `screen-read.test.mjs` ·
new tests `Test/AuditRead.cls`, `Test/Criteria/Bad.cls`, `Test/CriteriaRegistry.cls`,
`dialog.spec.ts`, `audit.page.spec.ts`, `browser/audit.browser-spec.mjs`.

**Review.** 38 findings over four layers. **16 patched** (1 high, 8 medium, 7 low), **4 deferred**,
**18 rejected** with a recorded reason each -- every row is in the `## Review Triage Log` above. The
high: leaving the screen after a Search and returning rendered a skeleton nothing resolved, because
a full re-bind clears `hasLoaded` and this archetype has neither a timer nor a read on navigation.
Four findings were refuted against the instance rather than argued -- a malformed `datetime`
criterion answers 200 with zero rows, not the 500 that was filed.

**Verification.** `check-objectscript` 195 files / 16 rules / 0 problems · `npm run build` (six
prebuild checkers) · `npm test` 715 + 273 green · `lint-docs` clean · six MCP test classes on live
plus `Test.AuditRead` · on the throwaway: the whole ObjectScript suite through `ci-runner.mjs`,
**51 classes / 482 tests / 0 failed**, no probe leftovers, no overlap, no foreign run;
`npm run test:browser` **49/49**; `smoke.sh` 16/16 with six area-list checks. Live `ocupilot` smoke
15/15. Throwaway torn down. **Eight Rule 19 mutations** were applied, observed red and reverted --
seven AC ones recorded in `## Verification`, plus the five for the review patches (the two client
fixes, the tool-view criteria path, the registry's criteria arm, and the previously vacuous
`Authentication` assertion, which went red only after the patch). The tree was re-checksummed
byte-identical after each revert.

**Live `ocupilot` was read-only throughout.** No audit configuration changed, no audit row deleted,
no principal created, no `docker compose up`/`down`. Every audit-row write and both new principals
were on `ocupilot-ci` and died with it.

**Follow-up review recommended: true.** One high was patched. The named unverified risk is that its
fix -- the conditional `readNow()` on a re-bind -- is pinned only at the component tier, in jsdom
over a stubbed API (`audit.page.spec.ts`, "re-reads on a return to the screen"). No browser leg
navigates away from the audit screen and back, so the fix has not been observed against a real
instance; a follow-up should add that leg.

**Residual risks.** The four deferred entries, of which two are the sharpest: a criterion value
longer than the vendor's own column answers 500 rather than a named refusal (an 83-character `pids`,
probed live), and roughly sixty EXPERIENCE.md citations in source no longer resolve -- though the
same ones did not resolve before this story's insertion either, which is why a blanket shift was
declined rather than applied. Both warnings stand: `multiple-goals` was accepted by the lead, and
`oversized` is real.
