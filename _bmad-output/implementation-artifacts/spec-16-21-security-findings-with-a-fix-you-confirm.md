---
title: 'Story 16.21: Security findings, with a fix you confirm'
type: 'feature'
created: '2026-09-26'
status: 'done'
baseline_revision: '4c81c839c00224f8415f7ef1aa57a972eaafe2f7'
baseline_commit: '4c81c839c00224f8415f7ef1aa57a972eaafe2f7'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Home says nothing about the settings that put the instance at risk or stop it working, so a person finds them only by visiting each screen. The contest rival leads with findings; OcuPilot can turn each finding's fix into an ordinary confirmed proposal.

**Approach:**

- Extract the shell-chrome field-read base (DW-1400) and build a fourth reader on it: `Kernel.Shell.Findings`, served as `GET /api/ocupilot/ui/findings`. It runs nine checks in two groups, each through its owning screen's pair gate and read, as the caller.
- Home shows a Findings panel under the performance row. A finding names its object, why it matters and what to do, and offers **Fix it** (an existing write tool), **Open** (no write tool yet) or the prohibited set's own refusal sentence.
- **Fix it** is the person's click: Home opens the affected screen on that object, then the panel sends a fixed sentence per check. The agent proposes through the ordinary proposal path, and nothing changes until Confirm.

## Boundaries & Constraints

**Always:**

- **The checks** (keys, group, owning screen whose pair gate and read each uses, rule):
  - `webapp-open` (security; `WebAppList`'s gate and read, then each enabled row's `WebApp.App` `GET` through `AdminPort` as `Impact.GrantingApplications` does, then `Effective.Read`/`Compose` over its application roles):
    - The application's own `AutheEnabled` (an integer) has bit 64.
    - Its application roles (the `TargetRoles` of `MatchRoles` entries whose `MatchRole` is `""`) compose to `all`, or to a letter granted by a role (not held only publicly) that is `U` on any `%Admin_*` or `%Development` resource, or `W` on any `%DB_*` resource.
    - `/api/monitor` is left to the next check.
  - `monitor-open` (security; the same gate and `GET`): `/api/monitor` enabled with bit 64.
  - `all-holder` (security; `UserList`'s gate and read, whose `GET` rowGet carries `Roles`, then `Effective`): every row with `Enabled` whose `Roles` compose to `all`.
  - `certificate` (security; `X509CredentialList`, whose `CERTINFO` rowGet carries `ValidityNotAfter` as UTC `YYYY-MM-DD HH:MM:SS`):
    - expired when it is earlier than `$ZTimeStamp`;
    - expiring when it falls within 30 × 86,400 s of it.
  - `auditing-off` (security; `AuditingConfig`, `Security.Audit.Enabled` `GET`): `Enabled` false.
  - `database-dismounted` (operations; `DatabaseList`, `Database.SysCRUD` `LIST`): a row whose `Status` does not begin with `Mounted` (measured values: `Mounted/RW`, `Mounted/R`, `Dismounted`).
  - `database-full` (operations; the same rows, mounted only): `MaxSize` is MB as text or `Unlimited`, and `Size` is integer MB. A finding when `MaxSize` is numeric and > 0 and `Size` ≥ 85% of it, 85 being `meter-state.ts`'s warning bound.
  - `task-manager` (operations; `TaskScheduleList`'s declared `banner`, `Task.Manager` `GET`): the answer's `banner` is `taskManagerSuspendedBanner` or `taskManagerStoppedBanner`.
  - `task-error` (operations; the same read, whose `INFO` rowGet makes `Suspended` truthful):
    - For each suspended row, one `Task.CRUD` `INFO` through `AdminPort` reads `Error`.
    - A finding when `Error` is non-empty and not the vendor's `Success`.
    - A person's suspend leaves `Error` empty (measured), and so is not a finding.
- **Answer shape.** `{checks: [{check, group, status}], findings: [{check, group, name, id, route, scope, detail?, fix, refused?}]}`.
  - `status` is `checked`, `unchecked` (with `pair`: the first pair the caller lacks on the owning screen, or the pair `Effective.Read` reports), `truncated` (the read hit its cap) or `failed` (the source threw or faulted; logged through the base's `LogSourceFailure`). Only `checked` may contribute "nothing to report".
  - `fix` is `agent` (a write tool fixes it), `link` or `refused`, and `refused` is `{code, reason}` with `reason` = `Prohibited.ReasonFor(code)`.
  - `detail` carries a check's one value: the certificate's date (`YYYY-MM-DD`), the database's percent, or the banner key.
  - A 403 is never answered: an unreadable check is `unchecked`, and the route has no gate of its own (like `/ui/system`).
- **Routes** (each finding's `route`, `id` and `scope`, and the target of both Fix it and Open):
  - `web-applications/list/<Name>` for `webapp-open` and `monitor-open`;
  - `permissions/users/<Name>`;
  - `security/x509/<Alias>`;
  - `security/auditing`;
  - `os-management/databases/details/<Directory>`;
  - `tasks/schedule`;
  - `tasks/schedule/details/<Id>`.
  The scope is `instance`, and the ids are encoded by the client's `entityUrl`.
- **Fix kinds.** `agent` means `webapp-open` and `monitor-open` (`webapp.list.update`), `all-holder` (`permissions.users.update`), `auditing-off` (`security.auditing.update`) and `task-error` (`tasks.schedule.resume`). `link` means `certificate`, `database-dismounted`, `database-full` and `task-manager` (Stories 18.4 and 16.11 will add Fix it for mount and resume).
- **Refused.** For each `all-holder` account, the verdict is `Prohibited.Prohibits` over the Users list's `remove-role` action with value `%All`. The target, payload and diff are built from the same public entry points the action route's preview uses: `Operation.Read`, the tool's `ScreenActionDelta` and `Mint.Merge`. A prohibited account's `fix` is `refused`, and the panel shows `reason` verbatim.
- **Fix it.** The click opens the affected screen with `entityUrl(route, id, scope, router.url)`:
  - `web-applications/list/<name>`, `permissions/users/<name>`, `security/auditing` and `tasks/schedule/details/<id>`.
  - Home waits for that screen's store `lastUpdate()` to move, as `CitationNavigator.open` does, then calls `FixFinding.request(check)`.
  - The panel takes the request and sends that check's fixed sentence with `assembleContext()`, through the same send path as `onExplainEntry`.
  - Fix it is shown and refused under exactly `ExplainEntry`'s gate (`shown`, `reason`, `describedBy`). A declined or failed navigation sends nothing.
- **Refresh.** Findings load when Home opens. They reload on a `changed` bus event whose `type` is `web-application`, `user`, `role`, `x509-credential`, `auditing-configuration`, `database` or `task`, and on a namespace switch. Home's 10 s tick never re-reads them (AD-43 unchanged).
- **Copy.** All copy is new Fixed strings rows appended after EXPERIENCE.md:578, plus `strings.ts` keys appended before `} as const` (see Design Notes). Reused strings: `homeSuggestedOpen`, `impactRequires`, `impactTooMany`, the two banner keys, and the prohibited set's sentences, which come from the server. Tokens only.

**Never:**

- Add a write tool, read tool, governance key or `Kernel/Governance/Gate.cls` change.
- Put instance-derived text into a user message. The five sentences are constants, and the object reaches the model only through the opened screen's own context (AD-11).
- Put findings into Home's screen context (16.18's `context.fields` stay).
- Duplicate a prohibited-set predicate or sentence.
- Treat an unread check as clean.
- Re-read findings on the tick.
- Use lazy loading or `@defer`.
- Edit Epic 14's hunks: `Router.cls:126-131` and `:746-756`, `EndpointCoverage.cls:115-118`, `turn.ts:40-44` and `:1133-1165`, `strings.ts:163-175`, `_components.scss:3965-4090`, `Write.cls:62-96`, `Operation.cls:320-328`, and `panel.ts` except the two additions named in Tasks.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Clean | Every check `checked`, no finding | Each group reads "Nothing to report." | None |
| Unread | Caller lacks `%Admin_Secure:USE` | All five security checks (their screens all require it) are `unchecked` with that pair; the group shows "Not checked: …" lines and never "Nothing to report." | No 403 |
| Too many | The users read hits its 1,000-row cap | `all-holder` is `truncated`; the line reads "… (too many to check)" | — |
| Source fails | One check's read throws | That check is `failed` ("could not be read"); the other eight answer | Logged once |
| `_SYSTEM` holds `%All` | `all-holder` finding for `_SYSTEM` | `fix` `refused`, `PROHIBITED.SYSTEMACCOUNT`, reason = `userRefusalSystemAccount`'s sentence; no Fix it | — |
| Suspended by a person | `Suspended` without an error | No `task-error` finding | — |
| Unlimited DB | `MaxSize` 0 | No `database-full` finding | — |
| Boundary | Size exactly 85% / cert on day 30 | Finding / finding; at 84.9% and day 31, none | — |
| Fix it | Click on `task-error` | Task details opens on the task; the user message equals `findingFixTask`; the context `entity` is the task id | Declined navigation: nothing sent |
| Kill switch on | Fix it | Rendered `aria-disabled`, described by the kill-switch id | — |

</intent-contract>

## Code Map

Server (seam and reads):

- `src/OcuPilot/Kernel/Shell/About.cls` :56-130, :303-309; `SystemInfo.cls` :56-114, :262-268; `Instance.cls` :101-137, :149-171. These are the three copies of `Members`/`Payload`/`Field`/`ReadSource`/`LogSourceFailure`/`LOGSUBSYSTEM` (DW-1400). `Instance` inlines `Field` three times.
- Fixtures that override the seam: `Test/UiAboutFixture.cls:61,89`, `Test/UiSystemFixture.cls:106,158`, `Test/InstanceFixture.cls:111,126`. Direct callers: `Test/Instance.cls:362,370`, `Test/UiSystemRead.cls:344,352`, `Test/UiAboutRead.cls:257,273,279`.
- `src/OcuPilot/Api/UiSystem.cls:16-30` is the handler template (no gate, `RenderInternal`). `Api/UiPerformance.cls:14-32` renders a fault object. Add routes in `Api/Router.cls`:
  - the route after `/ui/performance` at :142;
  - the `Call` target after `UiPerformance()` at :870-873.
- `src/OcuPilot/Test/EndpointCoverage.cls:132`: add the probe row after this one.
- `src/OcuPilot/Kernel/Proposal/Impact.cls`:
  - `ListRows` :332-343 gates with `Effective.Gate` (unchecked pair), then reads with `Screen.Read.Execute(descriptor, "")`, where a truncated read means `truncated`;
  - `GrantingApplications` :211-245 does the per-app `AdminPort.Invoke("WebApp.App","GET")` and handles a 404 skip.
  Copy this shape, and do not call Impact's private methods.
- `src/OcuPilot/Kernel/Shell/Effective.cls`:
  - `Compose` :53 answers `{all, allVia, resources{res:{letter:grantingRole}}}`, where `""` marks a public letter;
  - `Read` :171 and `Gate` :252.
- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`: `Prohibits` :777, `ReasonFor` :478. The user arm is at :1228 and orders `_SYSTEM` → current user → service account → last holder.
- `Kernel/Proposal/Operation.cls:192` `Read`, `Mint.cls:532` `Merge`, `Screen/Tool/UserUpdate.cls:213` `ScreenActionDelta` (action `remove-role`, value `Role`). The sequence to mirror is `Api/ScreenAction.cls:217-300` without the rendering.
- `Screen/Read.cls:234` `Execute`; the `banner` in the result is at :414 and :814.
- The descriptors:
  - `Screen/Descriptor/WebAppList.cls` (read lacks `AutheEnabled`/`MatchRoles`);
  - `UserList.cls:85-93` (rowGet `Roles`);
  - `X509CredentialList.cls:71-78` (`ValidityNotAfter` is `YYYY-MM-DD HH:MM:SS`, so `beforeToday` does not parse it; compute in Findings);
  - `AuditingConfig.cls:72`;
  - `DatabaseList.cls` (`Status` text, LIST `MaxSize` `"Unlimited"` or MB text);
  - `TaskScheduleList.cls:113-135` (rowGet `INFO` fields `["Suspended"]` only, and `banner`; `Task.Manager` `GET` costs about 1 s).
- `Port/AdminPort.cls` `Invoke(endpoint, type, .query, body, .out, .http, .fault)`, as `Impact.cls:222` calls it.

Client:

- `ui/src/app/areas/home/home.page.ts`:
  - template :274-434 (performance row :275-277, then `.ocu-home-remembered` :278);
  - constructor :664-740 (store subscriptions :701/708, refresh binding :716-724);
  - destroy :725-739.
  A sixth `.ocu-home-block` would break `BLOCK_COUNT = 5` in `home-system-information.browser-spec.mjs`, so the panel is its own row after :277.
- `ui/src/app/core/system-info.ts` (`load` :122 with its generation guard, `reset` :149) is the store template. Wire it at `ui/src/main.ts:216-220/275-276` and reset it at `app.ts:634-638`. The stubs go in `ui/src/app/testing/`.
- `ui/src/app/core/explain-entry.ts` is the hand-off and gate template. The panel side is `shell/panel.ts:719` (subscribe) and `:1799-1815` (`onExplainEntry`), plus `sendWithContext` :1821 and `assembleContext` :1834.
- `ui/src/app/shell/citation-navigator.ts:53-81` is the navigate-then-wait pattern. `core/navigation.ts:653` `entityUrl`; `core/entity-id.ts:41` `joinCompositeId`.
- `ui/src/app/core/change-bus.ts:104` `subscribe`; the event field is `type`.
- `ui/src/app/core/meter-state.ts`: the warning bound is ≥ 85.
- `ui/src/app/core/strings.ts`: append before `} as const` at :2965. Reuse `homeSuggestedOpen` :480, `impactRequires`/`impactTooMany` :2957/2959 and `taskManagerSuspendedBanner`/`taskManagerStoppedBanner` :280/282. `tools/strings.test.mjs` matches by text, and `/** EXPERIENCE.md:n */` comments are line-checked.
- EXPERIENCE.md (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`): the last Fixed strings row is :578. Edit the Home surfaces row :83 in place.
- Browser:
  - the Home precedents are `home-performance.browser-spec.mjs` (principal, the structural gate at :258-292) and `home-system-information.browser-spec.mjs`;
  - `turnprobe-spec.mjs` (`armProbeDefinition`, `scriptReply`) with `task-resume.browser-spec.mjs` is the scripted-agent pattern.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Shell/FieldRead.cls` (new) -- the base (DW-1400):
  - parameters `LOGSUBSYSTEM` and `LOGMESSAGE`;
  - `Members()` → `""`;
  - `Field(pField, ByRef pContext)`, the one `Try` whose degrade value is `""`, logged;
  - abstract-style `ReadSource(pField, ByRef pContext)` → `""`;
  - `LogSourceFailure(pField, pException)`, which swallows its own failure;
  - `Fields(Output pObject, ByRef pContext)`, which loops `Members`.
  Then `About`, `SystemInfo` and `Instance` extend it and delete their copies (Instance's three accessors become `..Field(...)`). The three fixtures take the unified `ReadSource` signature. Behavior and log text are unchanged. This is a pure refactor, pinned by the existing `UiAboutRead`, `UiSystemRead` and `Instance` suites staying green.
- `src/OcuPilot/Kernel/Shell/Findings.cls` (new) -- extends `FieldRead`:
  - `Members` = the nine check keys;
  - `ReadSource(check)` answers that check's `{status, pair?, findings[]}` object;
  - `Read(Output pAnswer)` assembles the answer shape;
  - a `PortClass()`/`ProhibitedClass()` seam for fixtures.
  A check whose `Field` degrades to `""` is `failed`. The rules, gates, `refused` composition and 85%/30-day constants are as in Boundaries, with the constants as class parameters. Dates use `$ZTimeStamp` (UTC; see Design Notes for the certificate time zone).
- `src/OcuPilot/Api/UiFindings.cls` (new) -- `Handle()` has `UiSystem`'s shape: `Findings.Read`, then `Response.JSON`, with `RenderInternal` on failure.
- `src/OcuPilot/Api/Router.cls` -- add `<Route Url="/ui/findings" Method="GET" Call="UiFindings"/>` after :142, and `ClassMethod UiFindings()` after :873.
- `src/OcuPilot/Test/EndpointCoverage.cls` -- add the `/ui/findings` probe row after :132.
- `src/OcuPilot/Test/FindingsFixture.cls`, `Test/Findings.cls` (new) -- unit legs over fixture rows for every I/O row and rule edge: each rule's positive and negative, the 85% and 30-day bounds, `MaxSize` 0, public-only letters, a disabled `%All` account, a granted-role `%All`, `/api/monitor` not double-reported, unchecked with pair, truncated, failed.
- `src/OcuPilot/Test/FindingsWire.cls` (new, `ocupilot-ci`; declares `OCUPILOT_ALLOW_PRINCIPALS`) -- over HTTP, with seeds removed after:
  - an unauthenticated probe application `/csp/ocuprobe1621` whose application role is `%DB_USER` reads as a `webapp-open` finding;
  - the same application with a probe role holding only `%DB_USER:R` does not;
  - the demo task reads as `task-error`;
  - `_SYSTEM` reads `refused` with the same code and reason as `GET /screens/<users>/impact?action=remove-role&id=_SYSTEM&value=%All`;
  - a least-privileged principal without `%Admin_Secure:USE` reads those checks `unchecked`, naming the pair, and holds no finding from them.
- `scripts/ci-throwaway.sh` -- add `# classes: FindingsWire` as a new line after :217, in the `OCUPILOT_ALLOW_PRINCIPALS` roster. Epic 14's hunks begin at :224.
- `ui/src/app/core/findings.ts` (new) + `ui/tools/findings.test.mjs` -- the framework-free store: `FINDINGS_PATH`, a generation-guarded `load`, `reset`, `answered`/`failed`, and `data()`. The pure `findingLines(answer)` builds each group's lines (finding, unchecked, failed, clean).
- `ui/src/app/core/fix-finding.ts` (new) + tests -- the hand-off: `request(check)`/`take()`/`subscribe`. Its gate delegates to the `ExplainEntry` instance. The check → sentence-key map is closed, and a check not in it throws.
- `ui/src/app/areas/home/findings-panel.ts` (new) -- the presentational panel:
  - two sections, each with an `h2` and a list;
  - each finding's sentence, why and what-to-do lines;
  - an action: Fix it (`button`, `aria-disabled` under the gate, `aria-describedby` the finding's sentence), Open (a link), or the refusal sentence.
  Names are rendered as text.
- `ui/src/app/areas/home/home.page.ts` (+ `home.page.spec.ts`) -- inject `Findings`, `FixFinding`, `ChangeBus`, `ScreenStores` and `Router`:
  - load on construct and on a namespace switch;
  - reload on the listed bus types;
  - render the panel after :277;
  - add the Fix it navigate-and-wait, then `request`;
  - the destroy stops everything.
- `ui/src/main.ts`, `ui/src/app/app.ts`, `ui/src/app/testing/findings.ts` -- create, provide and sign-out reset `Findings` and `FixFinding`, and add the stubs.
- `ui/src/app/shell/panel.ts` -- exactly two additions: a `fixFinding.subscribe` beside :719, and `onFixFinding()` beside `onExplainEntry` (:1799-1815). `onFixFinding` does `take()`, re-checks the gate, then `sendWithContext(STRINGS[key], this.assembleContext())`. Pin it with `ui/src/app/shell/panel-fix-finding.spec.ts` (new).
- `ui/src/app/core/strings.ts`, EXPERIENCE.md -- the keys and rows in Design Notes. EXPERIENCE.md :83 is edited in place: "the performance row first, then the Findings panel (Story 16.21)".
- `ui/src/styles/_components.scss` -- append the panel styles at the end of the file. Tokens only.
- `ui/browser/home-findings.browser-spec.mjs` (new; refuses the live container, seeds and removes its probe app):
  - AC1: both groups render, and the probe app's finding names it;
  - AC2: the `_SYSTEM` line shows the refusal sentence and no Fix it;
  - AC3: Fix it on the `task-error` finding opens Task details, the scripted turn's user message equals `findingFixTask`, and the proposal card appears with Confirm;
  - AC4: a principal without `%Admin_Secure:USE` sees "Not checked" lines;
  - AC5: the structural gate passes in light, narrow and dark with no new baseline entry.

**Acceptance Criteria:**

- Given Home, when it renders for `_SYSTEM` on `ocupilot-ci` with the demo fixture, then a Findings panel with Security and Operations groups follows the performance row. It lists:
  - `/oauth2`, `/csp/user` and `/api/monitor`;
  - the four `%All` accounts;
  - the demo task, and neither task 4 nor task 21.
  It does not list `/ocupilot`. Each finding shows its name, why and what to do, and a group with none says "Nothing to report."
- Given a finding with `fix` `agent`, when the person chooses Fix it, then the affected screen opens on that object and a turn is sent whose user message is that check's fixed sentence and whose context `entity` is the object. The agent's proposal is an ordinary card (comparison, privilege line, impact where 16.19 applies, Confirm), and the instance is unchanged until Confirm.
- Given a confirmed fix, when Home is next shown, or a `changed` event of a covered type arrives while it shows, then its findings reload and the fixed finding is gone.
- Given a `link` finding, when rendered, then it shows Open to its screen and no Fix it.
- Given an `all-holder` finding the prohibited set refuses, when rendered, then it shows no Fix it and the server's `reason`, character-equal to that code's published sentence.
- Given a caller who may not read a check's screen, when Home renders, then that check contributes no finding and no "Nothing to report", and says "Not checked" with the pair.
- Given the DW-1400 extraction, when About, System information and the status bar are read, then each answers exactly as before (their suites unchanged and green) from one `FieldRead` base, which `Findings` also extends.

### Review Findings

Code review 2026-09-27 (full-opus: blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor). 0 decision-needed, 4 patch (all applied), 0 defer, 24 rejected. No AD mismatch: AD-8, AD-10, AD-11 (the click is the person's, so rule 3's announcement does not apply; the message is a closed-map constant), AD-24, AD-29, AD-36, AD-40, AD-43, AD-53 checked against the diff. `FieldRead` keeps members, order, degrade value, subsystems and messages byte-identical. `/api/monitor` is matched on `DispatchClass` `%Api.Monitor`, which no OcuPilot application carries. No half-applied change found. Epic 14's hunks are untouched: a three-way merge is conflict-free.

- [x] [Review][Patch] (med) The sign-out reset of `Findings` and `FixFinding` was unpinned [ui/src/app/app.spec.ts:848] — the sign-out case now primes both stores and asserts both resets.
- [x] [Review][Patch] (med) `all-holder` could read `checked` over an unreadable role read, and nothing pinned it [src/OcuPilot/Test/Findings.cls:295] — a leg asserts `unchecked` naming the pair and no holder.
- [x] [Review][Patch] (low) The extraction's "log text unchanged" was not pinned by a literal [src/OcuPilot/Test/UiAboutRead.cls:275] — asserts the `uiabout` subsystem and About's message by value.
- [x] [Review][Patch] (low) AC1's pinning case had no `mutation:` line [ui/src/app/areas/home/home.page.spec.ts:1515] — run and recorded in Verification.

Rejected:

- (low, by-design) `webapp-open` ignores UnknownUser's roles and the `MatchRoles` entries that need a role: the intent names only the unconditional roles. An enabled UnknownUser holding `%All` is itself an `all-holder` finding.
- (low) An account holding `%All` only through another role gets Fix it: this is in the Spec Change Log. The agent proposes from the account's screen context, and the write path asks `Prohibits` at mint.
- (low, by-design) A refused line keeps its why and what-to-do beside `ReasonFor`'s sentence: AD-10 and AD-53 require one sentence, the same one the impact route shows.
- (low, theoretical) A row a checked read cannot interpret is skipped (the certificate date, the auditing row, a detail that is not an object). The date format was measured on `ocupilot-ci` (`OcuPilotDemoCert`, `2036-09-07 12:27:21`). A `rowGet` fault fails the whole read (AD-36), so the check reads `failed`.
- (low) `task-manager` reads `checked` when the Task Manager banner read faults: `Screen.Read.BannerKey` suppresses faults by contract, and the Task schedule screen shows the same silence. A fix needs a second ~1 s call or a change to the shared read. reopen_if: a `Task.Manager` fault in the `adminport` log while Operations reads "Nothing to report."
- (false) `database-full` assumes a numeric `MaxSize`. Measured on `ocupilot-ci`: `/durable/iris/mgr/user/` at `MaxSize` 500 read `"500"` and gave a 92% finding. The value was restored to 0.
- (low, by-design) `database-dismounted` flags every `Status` not beginning `Mounted`: this is the intent's rule over the measured values.
- (low) If the target's read fails, the Fix it wait stays armed and a later read sends the sentence late. It is still the person's own click and the same constant; a timeout would add state.
- (low) A `NavigationStart` that is later canceled drops the pending request: nothing is sent that was not asked for, and the person can click again.
- (false) The client drops a finding and prints "Nothing to report.": the server emits only values the client phrases (prior triage).
- (low) An account deleted between the two reads fails `all-holder`: this was rejected in the earlier triage.
- (low) A shared read that fails is re-issued and logged once per check that uses it: each failed check logging once is pinned, and caching failures would add state.
- (low, by-design) A failed reload keeps the earlier answer with no stale note: this is the About dialog's documented shape.
- (false) Open's link keeps the old namespace: the findings are instance-scoped, the switch reloads and recomputes the rows, and the click builds its URL fresh.
- (false) `FINDINGS_CHANGE_TYPES` lacks `rest-service`: no write tool targets `RestApiList` or `OpenApiViewer`, so no such change event exists.
- (false) The cost is unmeasured: Design Notes measure about 1.8 s.
- (by-design) Nothing refreshes while Home stays open: AD-43 rules out a tick read, and a change event reloads the panel.
- (low) Only `_SYSTEM`'s refusal is asserted: `Prohibited`'s own suites pin the codes. `FindingsWire` pins agreement with the impact route and SuperUser's `agent`. On the instance, `_Ensemble` reads `SERVICEACCOUNT` and the signed-in account reads `CURRENTUSER`.
- (low) The spec's triage counts and process note: the fix would edit the spec under review.
- (low) The `about-help-links` stamp red is not ledgered: it is a throwaway artifact outside this story.
- (low, by-design) The `certificate` check reads X.509 credentials only: this is the intent's check list.
- (low) `panel.ts` has four hunks, not two: the import and the injected field serve the two additions.
- (low) Browser AC1 asserts only that `/ocupilot` is absent: that is AC1's wording, and `FindingsWire`'s read-only probe role pins the `%DB_*:R` rule.
- (false) `FieldRead` cites "AD-36's shell-chrome exception": About and SystemInfo carried the same phrase at baseline, and AD-50 calls it AD-36's exception.

### Rework (CI, iteration 1)

- [x] [CI] browser: `ui/browser/home-findings.browser-spec.mjs:195` (AC1/AC5) fails on run 36307420890 at head 36c21571: it asserts `/oauth2 is named`, a name measured on the reused `ocupilot-ci` that CI's fresh container does not flag. Assert only what the spec seeds itself (its own unauthenticated probe application, the demo task, the accounts a stock install carries), never instance-specific names; keep the leg falsifiable and write its `mutation:` line. Grep the story's other browser legs and the `FindingsWire`/`Findings` tests for any other name a fresh stock container would not hold, and fix each the same way. <https://github.com/jbrandtmse/OcuPilot/actions/runs/36307420890> Done: AC1 names only the seeded application, `/csp/user` and `/api/monitor` (both in the fresh container's rendered lines in that run's failure message), the stock `%All` accounts and the demo task, and checks every `webapp-open`/`monitor-open` finding the instance answers is rendered; no other story test names an unseeded object; 4/4 green on `ocupilot-ci`, mutation red.
- [x] [CI] browser: `ui/browser/a11y-structural-invariants.browser-spec.mjs` failed in its `before` hook on the same run after 227 s with `Runtime.callFunctionOn timed out` (puppeteer's 180 s protocol timeout): one evaluate on some walked page took over 180 s. Locally the same spec passes 12/12 (walk 119 s) against the current bundle, and 16.20's CI run passed it. Bounded investigation: rerun the spec locally with Chrome CPU throttling (e.g. `page.emulateCPUThrottling(4)` in a scratch copy of the walk under a directory named for epic-16, never committed) and time each walked page, above all Home (the findings panel and its reload triggers, the performance row's 10 s refresh). If a page this story changed stalls or loops, fix the cause in the story's code and pin it. If nothing reproduces, record the per-page timings as evidence in `## Auto Run Result`, change no shared test, and leave the verdict to CI's next run. <https://github.com/jbrandtmse/OcuPilot/actions/runs/36307420890> Done, not reproduced: the walk at 4x, 6x and 20x CPU throttling settled every visit, the slowest 2.0 s (Home in dark, the findings read) and no evaluate over 207 ms; `/ui/findings` was requested twice in the whole walk, so nothing loops; no shared test changed.

## Spec Change Log

- 2026-09-27, lead: re-opened for one rework iteration on a red CI browser job (run 36307420890): an instance-specific name in the story's own browser spec, and a structural-walk protocol timeout to reproduce or rule out.

- 2026-09-26, implement. `certificate` findings also carry `expired` (boolean), because `detail` is the date alone and the two sentences differ. `monitor-open` knows the monitoring API by its dispatch class (`%Api.Monitor`, from the Web applications read) rather than by a `/api/monitor` literal, which `check-objectscript.py`'s AD-1 rule refuses under `Kernel/Shell/`. The panel's group headings are `h3` under its `h2` "Findings", so the outline does not repeat a level. A `truncated` check contributes no finding; `task-manager` stays `checked` when only the rows are cut, since the banner does not depend on them. An account holding `%All` only through another role has no `remove-role` of `%All`, so it is never `refused`. Where the explain gate hides Fix it, an `agent` finding offers Open. The fixture seams beyond `PortClass`/`ProhibitedClass` are `Gate`, `ListRead`, `Detail`, `EffectiveRead`, `RemovalVerdict` and `Now`. The bundle crossed 1900kB and was re-based under DW-1166 to 2004kB (5% above the measured 1,908,082 bytes).

## Review Triage Log

### 2026-09-27 — Review pass

- verdicts: 26 findings — high 0, medium 2, low 13, false 11, maybe-false 0
- findings:
  - `[medium]` `[patch]` FindingsWire's read-only leg stays green when the second read fails — added the 200 and `webapp-open` `checked` assertions; mutation red.
  - `[medium]` `[patch]` No real-verdict pin that a removable `%All` holder gets Fix it — FindingsWire asserts SuperUser `agent` with no `refused` (green on `ocupilot-ci`); mutation red.
  - `[low]` `[patch]` `onFixFinding`'s gate re-check never exercised — panel spec case for a request pending when the gate closes; mutation red.
  - `[low]` `[patch]` Open fallback under a hidden gate and the first-read fault line untested — two Home spec cases; mutations red.
  - `[low]` `[patch]` Detail-404 skip, role-read cut and task-read cut have no fixture legs — one `Findings` method covers all three; mutation red.
  - `[low]` `[patch]` The `link` → Open AC had no mutation line — mutation run and recorded.
  - `[low]` `[reject]` `FINDINGS_CHANGE_TYPES` is not tied to descriptor `entityType`s — the values match today; a cross-file roster is more than a direct correction.
  - `[false]` `[reject]` Client could print "Nothing to report." over a dropped finding — the server emits `refused` only with `ReasonFor`'s sentence and `task-manager` only with a banner key, so nothing is dropped.
  - `[low]` `[reject]` One account's `RemovalVerdict` error fails the whole `all-holder` check — needs a user deleted between two reads; the fix adds a branch.
  - `[false]` `[reject]` A check missing from the answer blanks its group — `Findings.Read` always lists all nine members.
  - `[false]` `[reject]` `monitor-open` by dispatch class rather than path — it names `/api/monitor` on the instance (browser AC1); the path literal is refused by AD-1's checker; logged in the Spec Change Log.
  - `[false]` `[reject]` `task-manager` stays `checked` on a cut read — the banner does not depend on the rows; now pinned.
  - `[false]` `[reject]` "Logged once" read per check — each failed check logs once; the one-own-read-fails shape is now pinned (1 log, 7 checked).
  - `[low]` `[patch]` An `agent` finding shows Open while the gate hides Fix it — kept as behavior and pinned (grouped with the Open-fallback row).
  - `[low]` `[reject]` A holder with `%All` only through a role gets Fix it with the `%All` sentence — the measured holders hold it directly; changing it needs a new branch.
  - `[false]` `[reject]` Certificate boundary in seconds, not days — the intent states 30 × 86,400 s.
  - `[false]` `[reject]` `expired` added to the answer — the two sentences need it; documented.
  - `[false]` `[reject]` In-place EXPERIENCE.md row and `strings.ts` citation edit — sanctioned by Tasks and required by `citations.test.mjs`.
  - `[low]` `[patch]` Fix it end to end exercised only for `task-error` — Home spec drives `webapp-open`, `monitor-open`, `all-holder` and `auditing-off` (no id); all pass; mutation red.
  - `[false]` `[reject]` Confirm-then-gone not exercised — the covered types equal the descriptors' `entityType`s (verified by the gap layer) and the reload is pinned.
  - `[low]` `[patch]` "No tick re-read" untested — the 16.18 tick case now asserts `findings.calls` unchanged; Home's context rows are already pinned exactly by 16.18's context case.
  - `[low]` `[patch]` Source-fails row tested only over a shared read — the edge method makes `certificate`'s own read raise (grouped with the fixture-legs row).
  - `[low]` `[reject]` Same as the `RemovalVerdict` row above (grouped).
  - `[low]` `[reject]` A rejected navigation is untested — `.catch(() => false)` feeds the same `navigated !== true` branch the declined case pins.
  - `[false]` `[reject]` Matrix key `findingFixTask` vs `findingFixTaskError` — Design Notes define `findingFix<Key>`; the text is identical.
  - `[false]` `[reject]` Bundle warning re-based — dispatch-authorized under DW-1166, 5% above the measured 1,908,082 bytes.

### 2026-09-27 — Review pass (CI rework)

- verdicts: 5 findings — high 0, medium 0, low 1, false 4, maybe-false 0 (verification-gap: none; intent-alignment: 5)
- findings:
  - `[false]` `[reject]` `/csp/user` is outside the rework's allowed set and unverified on a fresh container — run 36307420890's AC1 message lists the fresh container's rendered lines, `/csp/user` among them.
  - `[false]` `[reject]` `/api/monitor` was never observed on a fresh container — the same message lists "The monitoring API, /api/monitor, answers without signing in."
  - `[low]` `[reject]` The answer-driven loop checks rendering against the server's own answer, not the rule — the rule is pinned by `Findings` and `FindingsWire`, and the fixed names pin it on a real instance; nothing to add.
  - `[false]` `[reject]` "No re-read on the tick" rests on an observation — the 16.18 tick case in `home.page.spec.ts` asserts `findings.calls` unchanged.
  - `[false]` `[reject]` "No other story test names an unseeded object" contradicts the kept `/csp/user` — it is on the stock fresh container (first row); the rework item's evidence clause now names it.

## Design Notes

**Governing ADs:**

- **AD-8 and AD-29:** each check is read as the caller behind its owning screen's pair set (`Effective.Gate`), with no elevation. An unread check is reported, never inferred.
- **AD-10 and AD-53:** the refusal is `Prohibits` plus `ReasonFor`, the one home and the one sentence.
- **AD-11:** the user message is one of five constants, and the object travels only as the opened screen's context `entity` and rows.
- **AD-24:** Home's context is unchanged.
- **AD-36:** the declared reads are reused, and the per-row `GET` follows Impact's precedent.
- **AD-40:** Confirm stays the person's.
- **AD-43:** there is no tick read. A full pass costs about 1.8 s (measured below), which is 18% of a 10 s tick per open Home and is dominated by the vendor's 1 s Task Manager read. A finding changes only by a write, and a write publishes the change event that reloads the panel. The performance row stays the only thing the tick re-reads.
- **AD-5, AD-13, AD-14, AD-16** (switching lives inside the ports), **AD-19, AD-20, AD-39** and **AD-58/AD-57:** untouched. The read-back and try-it paths are not reached.
- **AD-22:** no key.

**Why no read tool and no Home context.** A finding's object reaches the model on the screen that owns it, under that screen's context cap and secret list. Findings in Home's context would put entity names on every Home turn for no request that needs them. The panel is shell chrome, like `/ui/system`.

**Why the person's click opens the screen.** An agent navigation would need the object's name in the user message, and AD-11 forbids that. The click is user-initiated, so it is not announced (a citation-chip click is the precedent), and the form guard still applies.

**Consumes / Consumed-by / Integration.**

- **Consumes:**
  - 16.19's `Effective`, `Prohibits` over a remove-role preview, and the impact line on the `%All` removal the agent proposes;
  - 16.17's read-back on the confirmed fix;
  - 16.18's Home layout, left intact;
  - 11.2's `ExplainEntry` gate;
  - 7.2's remove role, 7.4's auditing enable, 5.11's resume and 9.2's web-app update tools.
- **Consumed-by:** 16.22's Guardrails page reads the same `Prohibited.ReasonFor` sentences (inference until its plan); 16.11 and 18.4 will flip `task-manager` and `database-dismounted` to `agent`.
- **Integration ACs:** `FindingsWire` (the impact route and the findings route agree on `_SYSTEM`) and browser AC3 (Home drives the panel and proposal path on a real instance).

**Ledger.** DW-1400 is addressed by `FieldRead`. DW-118 is declined, because it was resolved by 15.6.

**Concurrent epics.** Epic 14's hunks are listed under Never and avoided. `panel.ts` gains only the two additions, away from its hunks at 21, 72, 232, 468, 678-688, 1287-1330 and 1868. Epic 18 has no branch, and Epic 23 has no source diff.

**Copy (EXPERIENCE.md rows appended after :578; `strings.ts` keys in brackets).** Design Notes defines the text here; the implementer transcribes it.

Every value below is new unless named as reused, and each `|` row is one Fixed strings row:

1. Panel: `"Findings"` [`findingsHeading`] · `"Security"` [`findingsSecurity`] · `"Operations"` [`findingsOperations`] · `"Nothing to report."` [`findingsNothing`] · `"Not checked: <check>"` [`findingsNotChecked`] · `" (could not be read)"` [`findingsCouldNotRead`] · `"Fix it"` [`findingsFix`]. Also reused, so no row: `homeSuggestedOpen` ("Open"), `impactRequires`, `impactTooMany`, `auditingStatusOff` ("Auditing is off."), and `taskManagerSuspendedBanner`/`taskManagerStoppedBanner`.
2. The nine `<check>` names: `"web applications open without signing in"` · `"the monitoring API"` · `"accounts holding %All"` · `"X.509 certificates"` · `"auditing"` · `"database mounts"` · `"database sizes"` · `"the Task Manager"` · `"suspended tasks"` [`findingsCheck<Key>`].
3. Findings, each as sentence · why · what to do, with `<name>` rendered as text [`finding<Key>`, `finding<Key>Why`, `finding<Key>Do`]:
   - **webapp-open:** `"<name> can be reached without signing in and holds a database or administrative role."` · `"Anyone who can reach this address can use that privilege."` · `"Require a password to sign in, or remove the role."`
   - **monitor-open:** `"The monitoring API, <name>, answers without signing in."` · `"Anyone who can reach the instance can read its metrics."` · `"Require a password, and give your metrics collector an account."`
   - **all-holder:** `"<name> holds %All."` · `"Whoever signs in as this account can do anything on this instance."` · `"Take %All off every account that does not need it."`
   - **certificate:** `"The certificate <name> expired on <date>."` / `"The certificate <name> expires on <date>."` · `"Connections that rely on it fail once it has expired."` · `"Import a renewed certificate."`
   - **auditing-off:** (reused `auditingStatusOff`) · `"Nothing that happens on this instance is recorded, OcuPilot's own changes included."` · `"Turn auditing on."`
   - **database-dismounted:** `"The database <name> is dismounted."` · `"Nothing can read or write it until it is mounted."` · `"Mount it from its details."`
   - **database-full:** `"The database <name> is at <percent>% of its maximum size."` · `"Writes to it fail once it is full."` · `"Raise its maximum size, or free space in it."`
   - **task-manager:** (the reused banner sentence, which carries its own why) · `"Resume the Task Manager."` / `"Start the Task Manager."`
   - **task-error:** `"The task <name> was suspended after an error."` · `"It does not run again until it is resumed."` · `"Read its error, then resume it."`
4. The five Fix it user messages [`findingFix<Key>`], constants carrying no instance text:
   - `"This web application can be reached without signing in and holds a database or administrative role. Propose requiring a password to sign in to it."`
   - `"The monitoring API answers without signing in. Propose requiring a password to sign in to it."`
   - `"This account holds %All. Propose taking %All off it."`
   - `"Auditing is off on this instance. Propose turning it on."`
   - `"This task was suspended after an error. Propose resuming it."`

Where each row applies: Home's Findings panel (Story 16.21, AD-10, AD-11), under the performance row. A group says "Nothing to report." only when every one of its checks was read. An unread check reads "Not checked: <check>" plus " (requires <pair>)", " (too many to check)" or " (could not be read)". A refused fix shows the prohibited set's own sentence from the server, never a copy. Each row ends `[ADDED 2026-09-26 - Story 16.21]`.

**Measured on `ocupilot-ci` (2026-09-26, every seed removed and read back):**

- **Unauthenticated applications with roles.** `/oauth2` holds `%All`, `/csp/user` holds `%DB_USER` RW, and `/csp/healthshare/hssys/app/api` holds four `%DB_*` RW, so all three are findings. `/api/monitor` holds `%DB_IRISSYS` RW, and an anonymous `/api/monitor/metrics` answers 200. `/ocupilot` and `/api/ocupilot/readiness` hold only `%DB_HSCUSTOM:R`, so they are not findings.
- **The admin API.** The web application LIST carries no roles; its `GET` carries `AutheEnabled` (integer) and `MatchRoles`. The Users LIST carries no roles; its `GET` does.
- **`%All` holders.** They are `SuperUser`, `_SYSTEM`, `_Ensemble` and `irisowner`. The expected verdicts for `_SYSTEM` and the two service accounts are refused, and SuperUser gets Fix it (inference from `Prohibited` :1228 and `SERVICEACCOUNTS` :387; `FindingsWire` pins it).
- **Suspended tasks.** Tasks 4 and 21 are `Suspended` with an empty `Error`, so they are not findings. Demo task 1002 was suspended after an error, and is one. The task LIST answers `Suspended:false` for every row; `INFO` answers the truth.
- **Cost.** A full pass over HTTP takes about 1.8 s, and more than half of that is `Task.Manager` `GET` at about 1 s.

**Named gap.** The instance-wide authentication mask (`Security.System` `AutheEnabled`) also gates an application, and no admin endpoint reads it. The check therefore reads each application's own setting, as its editor does. Where the instance itself refuses unauthenticated access, the finding over-reports (inference).

## Verification

**Commands** (the targeted runs are marked `(loop)`, and the full runs `(once, before dev_complete)`):

- `cd ui && npm run test:tools` (loop) -- green, including `findings.test.mjs`, `fix-finding.test.mjs`, `strings.test.mjs`, `self-protection.test.mjs`, `citations.test.mjs` and `ci.test.mjs`. Mutations:
  - mutation: `findingLines` prints "Nothing to report." whatever its checks read (dropped `allChecked &&`) → `findings.test.mjs` 2 red; reverted.
  - mutation: dropped the `request !== this.request` guard in `Findings.load` → the late-answer row red; reverted.
  - mutation: `FixFinding.request` records whatever `reason()` says → "a refused request records nothing" red; reverted.
  - mutation: `fixSentenceKey` answers for any check → "the map is closed" red; reverted.
  - mutation: dropped `# classes: FindingsWire` from `scripts/ci-throwaway.sh` → `ci.test.mjs` 1 red; reverted byte-identical.
- `cd ui && npx ng test --include src/app/areas/home/home.page.spec.ts --include src/app/shell/panel-fix-finding.spec.ts` (loop) -- green (64). Mutations:
  - mutation: `fixAndRequest` calls `fix.request` straight after the navigation → the AC2 and navigate-away cases red; reverted.
  - mutation: `onFixFinding` appends the context's `entity` to the sentence → `panel-fix-finding.spec.ts` red ("... resuming it. 1002"); reverted.
  - mutation: Fix it rendered for `fix: "refused"` in `resolvedFindings` → the actions case red; reverted.
  - mutation: `'user'` dropped from `FINDINGS_CHANGE_TYPES` → the AC3 reload case red; reverted.
  - mutation: dropped `navigated !== true` in `fixAndRequest` → "a declined navigation sends nothing" red; reverted byte-identical.
  - mutation: any shown finding offers Fix it (`if (shown)`) → the actions case red on the `link` certificate; reverted.
  - mutation: dropped `&& shown` from the Fix it branch → "while the explain gate hides Fix it, a fixable finding offers Open" red; reverted.
  - mutation: `findingsShown` reads `answered()` alone → "a first read that fails shows the panel with the server-fault line" red; reverted.
  - mutation: `fixAndRequest` navigates to the bare route → AC2 and "Fix it on each other fixable check opens its own screen" red; reverted.
  - mutation: dropped `onFixFinding`'s own gate check → `panel-fix-finding.spec.ts` "a request still pending when the gate closes" red; reverted byte-identical.
  - mutation (review): `findingsShown` answers `false` → `home.page.spec.ts` "Story 16.21 AC1" red (10 cases); reverted byte-identical.
  - mutation (review): deleted `this.findings.reset()`, then `this.fixFinding.reset()`, from `App`'s sign-out branch → `app.spec.ts` sign-out case red each time; reverted byte-identical.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.Findings`, then `FindingsWire`, `UiAboutRead`, `UiAboutWire`, `UiSystemRead`, `UiSystemWire`, `Instance`, `RefusalCopy`, `ImpactRoute`, `Effective`, `EndpointCoverage`, `SurfaceCoverage`, `ScreenGrounding` and `TurnContext`, one at a time (loop) -- green (11, 4, 12, 7, 17, 4, 21, 8, 10, 7, 2, 4, 12, 16). Each mutation was applied to the `ocupilot-ci` copy only, the class and its descendants recompiled, and restored byte-identical:
  - mutation: `Privileged` counts a letter held only publicly → `Findings` `TestAnOpenApplicationHoldingPrivilegeIsAFindingAndNothingElseIs` red.
  - mutation: the 85% test uses `>` (`<=` on the skip) → `TestDatabasesDismountedOrAtEightyFivePercentAreFindings` red.
  - mutation: a degraded `Field` reads `checked` in `Read` → `TestAFailingSourceIsFailedAndLoggedAndTheOthersAnswer` red.
  - mutation: the pair gate skipped in `Rows` → `FindingsWire` least-privilege leg red.
  - mutation: a hand-written sentence in place of `ReasonFor` → `FindingsWire` agreement leg red.
  - mutation: the database-write arm of `Privileged` dropped → `FindingsWire` probe-application leg red.
  - mutation: the `/ui/findings` probe row dropped → `EndpointCoverage` `TestEveryRouteHasAProbeAndEveryProbeHasARoute` red.
  - mutation: a detail 404 is fatal in `Applications` → `Findings` `TestDetailGoneRoleReadCutTaskReadCutAndOneOwnReadFailing` red.
  - mutation: every `all-holder` finding reads `refused` → `FindingsWire` SuperUser leg red.
  - mutation: `webapp-open` always marks itself unchecked → `FindingsWire` read-only leg red on "and the check was read".
  - mutation: `FieldRead.Field` stops calling `LogSourceFailure` (recompiled with every subclass) → `UiSystemRead` 4 red, its refused-source legs (not the :344 leg, which calls the seam directly).
  - mutation (review): dropped `MarkUnread` after `EffectiveRead` in `AllHolders` → `Findings` `TestAnUnreadableCheckIsUncheckedNamingThePair` red (run 15899).
  - mutation (review): About's `LOGMESSAGE` changed → `UiAboutRead` `TestTheSourceFailureLogLineNamesTheField` red (run 15902).
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/ && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/home-findings.browser-spec.mjs browser/home-performance.browser-spec.mjs browser/home-system-information.browser-spec.mjs browser/about-help-links.browser-spec.mjs browser/account-and-filter.browser-spec.mjs browser/explain-screen.browser-spec.mjs browser/explain-entry.browser-spec.mjs browser/suggested-view.browser-spec.mjs browser/suggested-prompts.browser-spec.mjs browser/screen-grounding.browser-spec.mjs browser/preferences-integration.browser-spec.mjs browser/rail-icons.browser-spec.mjs browser/task-resume.browser-spec.mjs browser/users-actions.browser-spec.mjs browser/impact.browser-spec.mjs browser/screen-height.browser-spec.mjs browser/a11y-structural-invariants.browser-spec.mjs` (loop). These are the story's spec plus every existing spec that Home, the panel hand-off or the reused paths could break. Expected: green, with no new structural baseline entry. Observed: all green (home-findings 4, with the gate in light, narrow and dark and no new entry) except `about-help-links`' DW-3 stamp leg, which compares the recorded `buildIdentity` (`main-ZWCBUUJV.js`, the throwaway's last install) with the `docker cp`-deployed bundle and so reads red after any redeploy without a reinstall. mutation: Home's Fix it requests without waiting for Task details' read (rebuilt, redeployed) → AC3 red on the context row; reverted, rebuilt byte-identical (`main-IBBXWY3H.js`), redeployed.
  - mutation (CI rework): `findingLines` renders a `webapp-open` finding without its name (rebuilt, redeployed) → `home-findings` AC1 red on "the seeded application is named"; reverted byte-identical (`main-IBBXWY3H.js`), redeployed.
- `cd ui && npm test`, `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh` (once, before dev_complete) -- green. The bundle stays under 1900 kB, or is re-based under DW-1166 if it crosses; the hard stop is 4000 kB.
- The full ObjectScript sweep on `ocupilot-ci`, one class at a time (once, before dev_complete) -- green.

## Auto Run Result

Status: done
Blocking condition: none

**Implement pass (2026-09-27).** `FieldRead` is extracted and About, SystemInfo and Instance extend it unchanged in behavior. `Findings` runs the nine checks as the caller behind each screen's gate and read, served by `GET /ui/findings` (`UiFindings`, a route and a probe row). Home shows the Findings panel after the performance row, and Fix it hands off through `FixFinding` to the panel's two additions. Copy lands as four Fixed strings rows and their `strings.ts` keys. Deviations are in the Spec Change Log, and the bundle warning is re-based to 2004kB under DW-1166.

Files: `Kernel/Shell/FieldRead.cls`, `Findings.cls` (new) and `About`/`SystemInfo`/`Instance.cls` (on the base); `Api/UiFindings.cls` (new), `Router.cls`; `Test/Findings.cls`, `FindingsFixture.cls`, `FindingsWire.cls` (new), `EndpointCoverage.cls` and the three fixtures and suites on the unified seam; `scripts/ci-throwaway.sh` (roster line); `ui/src/app/core/findings.ts`, `fix-finding.ts`, `areas/home/findings-panel.ts`, `testing/findings.ts` (new); `home.page.ts`, `panel.ts`, `main.ts`, `app.ts`, `strings.ts`, `_components.scss`, `angular.json`; component, tool and browser specs; EXPERIENCE.md.

Review: 26 findings (medium 2, low 13, false 11). Nine entries were patched, all as tests with an observed red: the FindingsWire read-only and SuperUser legs, the panel's gate re-check, Home's Open fallback, fault line, four other Fix it targets and tick, the fixture edge legs, and the `link` mutation. Nothing was deferred; the rejected rows carry their reasons in the triage log. Follow-up review: `false`. Two medium entries were patched, but both were test gaps that are now green on the instance and red under their mutations, so no unverified risk can be named.

Verification: `npm test` passed (1557 tool tests, 113 component files), as did `check-objectscript.py` (0), `lint-docs.sh` (0) and the build at 1.91 MB. Browser loop: 77 of 78 passed. The one red is `about-help-links`' DW-3 stamp leg, which compares the installer's recorded bundle with a `docker cp`-deployed one and so reads red after any redeploy without a reinstall. The full ObjectScript sweep covered 304 classes, 2403 tests: 287 ran green, 16 refused (arming) and 1 is known residue (`WireSecurityRead` task history).

Process note: the handoff subagent returned an interim message while its sweep was in flight. The harness stopped that sweep after 12 classes, its in-flight run 15585 landed, and the stage ran the verification itself. No subagent committed.

Planned from `epic-16-context.md` (cached, valid), the full spine, and measurements on `ocupilot-ci` (every seed removed and read back). No AD change is needed: AD-43's tick scope, AD-24's Home context and AD-10's one home are all kept. DW-1400 is addressed (`FieldRead`), and DW-118 is declined (resolved by 15.6).

**CI rework pass (2026-09-27, iteration 1, follow-up pass).** Status: done. Blocking condition: none.

- **AC1 named an instance-specific application.** `ui/browser/home-findings.browser-spec.mjs` no longer asserts `/oauth2`, which CI's fresh container does not flag. AC1 now names the seeded probe application, `/csp/user` and `/api/monitor` (all three appear in the fresh container's rendered lines in run 36307420890's failure message), the four stock `%All` accounts and the demo task. It also checks that every `webapp-open`/`monitor-open` finding in the instance's own answer is rendered. No other story test names an unseeded object. On `ocupilot-ci` the spec passed 4/4, and the served bundle is unchanged (`main-IBBXWY3H.js`). The mutation line is under Verification.
- **Structural-walk timeout: not reproduced; no shared test changed.** A scratch copy of the walk (outside the worktree) ran at 4x, 6x and 20x CPU throttling, and every visit settled.
  - The slowest single evaluate took 207 ms (Home at 20x), against the 180 s protocol timeout.
  - `/ui/findings` was requested twice across the whole 174-visit walk.
  - Per-page times at 6x, in ms, for 1280 light / 1280 dark / 720 light:
    - Home: 633 / 2036 / 627. The dark visit includes the findings read.
    - `tasks/schedule`: 1621 / 1623 / 1627.
    - `database-free-space`: 1520 / 1502 / 1516.
    - `logs/audit`: 727 / 714 / 715.
    - `tasks/history`: 719 / 708 / 701.
    - REST document: 710 / 704 / 698.
    - `agent/definitions/edit`: 694 / 688 / 693.
    - Every other screen: 578–656.
  
  The verdict is left to CI's next run.
- **Review.** The verification-gap reviewer found nothing. The intent-alignment reviewer raised 5 findings: 4 false, and 1 low that was rejected. Nothing was patched or deferred. The follow-up review recommendation is `false`, because no high was patched.
- **Checks.** `client-lint.mjs` and `lint-docs.sh` both returned 0, and the diff adds no non-ASCII to source.
- **Residual risk.** CI's 180 s evaluate stall is still unexplained. If it recurs, the next step is per-evaluate page logging in CI.
