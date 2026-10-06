---
title: 'Story 23.4: The range-end cleanup, part 4'
type: 'bugfix'
created: '2026-10-06'
status: 'done'
baseline_revision: '3168e2d6df11a79b79edbe0edc4ce34050bb472c'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['multiple-goals', 'oversized']
deferred:
  - summary: >-
      structural-walk.mjs withRetry (per-pass retry) has no executed test; it is a closure inside walk.
    evidence: |-
      Only isProtocolTimeout and retryOnce are unit-tested; the walk-level retry was checked by hand with a held font. Extracting withRetry into protocol-retry.mjs would make it testable.
    location: >-
      ui/browser/structural-walk.mjs
    severity: low
  - summary: >-
      data-check's session logic is pinned as source text; the red path was never run on a real instance.
    evidence: |-
      ci.test.mjs stubs docker with a canned session answer. CI runs the green path on every instance leg; the lead's real-runtime step covers the rest.
    location: >-
      scripts/ci-throwaway.sh
    severity: low
  - summary: >-
      turnprobe disarm passes no username, so SweepSince covers every user's rows above the mark (unverified).
    evidence: |-
      Harmless while specs run one at a time; settle by checking whether any spec writes concurrently as another user.
    location: >-
      ui/browser/turnprobe-spec.mjs:237
    severity: low (unverified)
  - summary: >-
      structural-walk retry assumes the dark theme persists outside a fresh browser context (unverified).
    evidence: |-
      Settle by failing a pass after the dark toggle and reading the retry's theme.
    location: >-
      ui/browser/structural-walk.mjs
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** Thirty-one ledger entries are owned by this story. CI's instance legs run 48 to 60 minutes under an 81-minute limit. Local throwaways lose files to macOS's `/tmp` cleaner. Nine flakes and eight isolation defects produce false reds. Twelve product entries leave wrong or unsafe behavior: an unreviewed task import, an unlocked Save, a whole-replaced OAuth `Metadata`, a restore that overflows, a toast that opens the wrong list, a banner that never clears, a doubled alert, a ledger row that says `ok` for a write still running, a partial read-back, a card titled by a number, and a read tool that never says `[]` means unrestricted. Four ids are duplicated in the ledger.

**Approach:** Two batches, in order: (a) CI and test-environment health, then the ledger dedupe; (b) product correctness and safety. Each batch gets one implement pass and one code commit, needs a green CI run on its own head, and merges on its own. A flake or isolation defect is shown by its test passing under the condition that reproduces it. A product defect is shown by a test that reddens before the fix.

## Boundaries & Constraints

**Always:**

- Work in `/Users/jbrandt/git/OcuPilot/.worktrees/epic-23` on `OCU-1-epic23`; check `git rev-parse --show-toplevel` first. Every IRIS MCP call carries `server: "ocupilot-slot-a"`, which reaches the dev instance `ocupilot`, never the throwaway.
- Run tests and state-changing probes only on the throwaway `ocupilot-ci`. One test run in flight at a time, whatever the runner; await each in `%UnitTest_Result`, or the browser run's exit. A client timeout is not a finished run.
- Implement runs on Sonnet, one batch per pass. The lead re-opens the spec (`status: in-progress`) for each batch and scopes the pass to that batch's items. A red batch is reopened alone.
- AD-17: a product start compiles no `OcuPilot.Test.*` class. The throwaway sets `OCUPILOT_LOAD_TESTS=1`; a new armed test class joins `ci-throwaway.sh`'s arming roster, appended, together with its pin in `ci.test.mjs`.
- Every fix that is a wait, a predicate or a refusal has a `mutation:` line in its batch's Verification (Rule 19). Recompile the mutated class and its descendants, or rebuild and redeploy the bundle, before reading a mutation.
- Remove all reproduction state afterwards and read it back as gone: a seeded override, credential, script, conversation, held lock or response.
- Keep shared roster changes additive (append rows, never reorder). Epic 18 resumes on slot A after this story and merges feature forward.
- A new error code goes in a sibling `Api/*Error.cls`, never in `Api/Error.cls` (989 of ERROR #5290's 1,000 parameters).
- Apply CLAUDE.md's prose discipline to every comment. Write non-ASCII characters in source as `\uXXXX`.

**Never:**

- Implement passes never edit the spine, `CLAUDE.md`, `_bmad/custom/*`, `epics.md`, `deferred-work.md` or another story's spec. The lead applies Design Notes › Lead edits.
- Do not flip `tasks.schedule.import`'s shipped value (`Kernel/Governance/Baseline.cls:160` stays `false`).
- Do not lower any `timeout-minutes` (instance-shard 81, browser-shard 56). The browser suite stays at three legs.
- Do not touch `structural-walk.mjs`'s id-source table (`SOURCE_VIEWER_IDS`). A red that depends on shard composition is fixed in the test, never by pinning to a shard.
- Never stop, restart, remove or `down` `ocupilot`, any `ocupilot-slot-*`, `iris-community-edition` or `ocupilot-ci` (the lead's DW-2034 step excepted). `ocupilot-b-ci` is never created. A test never runs `ci-throwaway.sh down` on the default dir.
- Do not delete a mounted database's `IRIS.DAT` on any instance.
- Change product behavior only for batch (b)'s entries and DW-2034's script. Do not absorb anything beyond the 31 entries; name it under Design Notes › Named for filing.
- Never put `[skip ci]` on a commit that carries code. Pushing is the lead's job.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Import as another account (DW-1827) | An import file with a task whose `RunAsUser` is not the caller | Minted destructive with consequence `TASK.RUNSASOTHER`. The card's `tasks` row names each task's `TaskClass` and `RunAsUser`. | All tasks run as the caller: not destructive by this arm |
| Same-named rewrite (DW-1827) | The file is rewritten between preview and import, same `Name`, new `TaskClass` or `RunAsUser` | 409 `TASK.IMPORT.CHANGED`; nothing imported | No error expected |
| Import name shape (DW-1827) | A digit-first or 51-character task name | `TASK.NAME.SHAPE` before any vendor call, on both callers | No error expected |
| Save on a held target (DW-1882) | Another process holds the target's lock | After `CLAIMLOCKSECONDS`: 409 `WRITE.TARGETBUSY`, nothing written. After release: 200, readBack `matches`. | No error expected |
| Agent OAuth `Metadata` edit (DW-1641) | The agent sends `{"userinfo_endpoint": X, "scopes_supported": []}` | One diff row per named member. Every other stored member is kept; scopes are cleared. | Merged metadata that fails the rules refuses the mint |
| Large restore (DW-1864) | 10 entries of about 420 KB steps (over 3,641,144 characters) | `GET /conversation/:id` answers 200, one envelope, 10 turns | No error expected |
| Remote database toast (DW-1939) | A `database-configuration` change from an `osmgmt.remotedatabases.*` tool | The toast reads "Open in Remote databases" and opens that list. It is raised even while Local databases is open. | An event with no tool: lowest side-bar position, as today |
| Auditing re-enabled elsewhere (DW-1449) | Stored fact not-marked; auditing on; OcuPilot's marker event enabled | The restraint read answers `writesMarked` true and records it | The caller cannot read the flag, or a read fails: the stored fact is answered and nothing is written |
| Background preference refusal (DW-1414) | A background write is refused while Home is open | Exactly one `role="alert"`, the locator bar's; Home's line stays silent | No error expected |
| Queued write past its bound (DW-1637) | An audit `COPY` the port answers as started | Ledger row `ok · PORT.STARTED`, marked | A finished write's code stays empty |
| List-row create read-back (DW-1710) | A confirmed `TaskCreate` or `OAuthRegisteredClientCreate` | Re-read by the created id through the update tool's GET; every sent key in its field list compared | No created id: `unchecked` |
| Task card title (DW-1465) | A proposal for any task write | "Proposal · Task <Name>" | Name unread: falls back to the id. A process keeps its pid. |
| Throwaway `down`, `compose.yml` gone (DW-2034) | Compose lists the project with this dir's `compose.yml` | `docker compose -p <project> down -v --remove-orphans`; dir removed | Listed with another file, or not listed: no Compose call, and the message says why |
| Missing `IRIS.DAT` (DW-2034) | A mounted local database directory with no `IRIS.DAT` | `data-check` exits 1 naming the directory | No databases listed, or no marker: exit 1 |
| CI shape (DW-2102) | A push | Instance legs `1/5` to `5/5`; three browser legs; both roll-ups green with every class and spec in exactly one leg | A missing record, empty leg or duplicate fails the roll-up |

</intent-contract>

## Code Map

**Batch a:**

- `scripts/ci-throwaway.sh`:
  - default dir `:33`;
  - `..` refusal `:86-88` and root guard `:89-92`;
  - `compose ls` parsing `:136-140`;
  - `product-check` `:661-701` (the shape `data-check` copies);
  - `down` `:751-759` skips Compose when the file is missing.
  - Hardened precedent: `scripts/ci-ipm-archive.sh:97-114`.
- `ui/tools/ci.test.mjs`:
  - `DECLARED_GATES` `:119-128`;
  - the `-f`-on-every-compose-call test `:1328-1351`;
  - DW-232 executed tests `:1403-1542`;
  - `runProductCheck` `:1741-1801`;
  - `SHARDED` `:2717`, shard-matrix test `:2752-2771`, `SHARD_SETUP_MINUTES` `:2722`, AC9 `:2829-2843`.
  - Docker stubs come from `ui/tools/stub-bin.mjs`; `ui/tools/shell-scripts.test.mjs` parses scripts under dash.
- `.github/workflows/ci.yml`:
  - comments `:15`, `:131`;
  - name `:135`; `timeout-minutes: 81` `:137-139` (unchanged);
  - matrix `:143`; `--shard` `:186`; `--shards` `:232`;
  - the `wait-readiness` step near `:176`;
  - browser `timeout-minutes: 56` `:242` (unchanged).
  - CI passes no `--dir` to instance-shard. Browser-shard and images pass `/tmp/...`, unchanged.
- `ui/tools/ci-timings.json`: currently from run 37367533727. It gets refreshed.
- `ui/tools/ci-shards.mjs:6`, `ui/tools/ci-runner.mjs:42`: comments that say `k/4`.
- `docs/DEVELOPMENT.md:451-452,466` (shards), `:547-551` (throwaway); `README.md:490-491`.
- `ui/browser.config.mjs`: `launchOptions(config)` `:100`. All 162 specs import it and `import puppeteer from 'puppeteer'`.
- New `ui/browser/protocol-retry.mjs`; new `ui/tools/protocol-retry.test.mjs`.
- `ui/tools/browser-reset.mjs:64,74`: the literal patterns a spec's imports must not spell. `browser-reset.test.mjs`: `HELPER_SOURCED_FLOOR`.
- `ui/browser/structural-walk.mjs`:
  - page-scroll check `:360-373`;
  - overflow loop `:388-420`;
  - `fieldNames` `:519-540`;
  - `settle`'s `document.fonts.ready` `:601-604`;
  - `walk()` `:715`;
  - `--write` launch `:786`.
- `ui/browser/a11y-structural-invariants.browser-spec.mjs:48` (`protocolTimeout: 600_000`, kept).
- `ui/browser/system-explorer-transfer.browser-spec.mjs:205-241` (delete `:211-216`, import walk `:222`); `ui/src/app/areas/**/code-list.store.ts:394`.
- `ui/browser/reply.browser-spec.mjs:331-340`. Final reply `panel.ts:524`, streamed block `:537`. Stub slices `Test/TurnProvider.cls:20-25`.
- `ui/browser/turn.browser-spec.mjs:206-247` (hang `:209`, other tab `:228`, lock wait `:231`).
- `ui/browser/toast.browser-spec.mjs`: `sendAndConfirm` `:180-211`, callers `:282,346,410,518`.
- `ui/browser/gate.browser-spec.mjs:539-558`.
- `ui/browser/web-sessions.browser-spec.mjs:216,234`. Hover delay is in `_components.scss:933-951`.
- `ui/browser/turnprobe-spec.mjs`:
  - `nextTag` `:84-94`;
  - `armProbeDefinition` / `disarmProbeDefinition` `:183-193`.
  - Workarounds: `proposal-demo.browser-spec.mjs:126-133`, `process-control.browser-spec.mjs:90-93`.
  - Dead copies: `navigate.browser-spec.mjs:104-124`, `context-chip.browser-spec.mjs:113-141`.
- `ui/browser/governance.browser-spec.mjs` (reset `:106`), `ui/browser/agent-sql.browser-spec.mjs` (`:71`, `:123-135`).
  - `ui/browser/preferences-reset.mjs:119-136` stays as is; its shape is pinned by `tools/preferences-reset.test.mjs:121-165`.
  - `runIris` lives in `ui/browser/iris-session.mjs`.
- `src/OcuPilot/Test/TurnWireFixture.cls`: `Sweep` `:415-452`.
  - Deletes go through `Turn.GuardedDelete` (`Kernel/State/Turn.cls:682-694`) and `Convo.GuardedDelete` (`Kernel/State/Convo.cls:304-309`).
- `scripts/ci-unit-test.sh:110-136`: the `PROBEAPPS` markers around `RunTest`.
  - `ui/tools/ci-runner.mjs:216-238` handles those markers.
  - `src/OcuPilot/Test/GovernanceFixture.cls` (`Snapshot`/`Restore`/`Matches`); `src/OcuPilot/Test/GovernanceRestore.cls`.
  - Holding-global precedent: `Test/AgentFixture.cls:123-215`.
- `src/OcuPilot/Test/OAuthResourceServerAuditMask.cls`: `AssertMasked` `:125-144`. Vendor index refresh: `irissys/%SYS/Audit.cls:193`.
- `src/OcuPilot/Test/SanitizeAuditMask.cls:105-108,152-159`. The secret-carrying row: `Port/AuditPort.cls:120`.
- `src/OcuPilot/Test/MappingCodeGlobals.cls:86-106`; `Kernel/Proposal/Prohibited.cls:633` (`CODEGLOBALS`).
- `src/OcuPilot/Install/Installer.cls`: the lock at `:527-531`, its refusal at `:544`; `INSTALLLOCKSECONDS` `:130`.
  - `src/OcuPilot/Test/InstallLock.cls:421-470`.

**Batch b:**

- DW-1827:
  - `Kernel/Proposal/Mint.cls`: `:283` narrows the payload to `FINGERPRINTSUBJECT`; `:323` classifies; `:341` ORs destructive.
  - `Kernel/Proposal/Prohibited.cls`: task arm `:3719-3729`, doc `:3684`.
  - `Port/TaskTransferPort.cls`:
    - SCHEDULE/PREVIEW answers `:132-148`;
    - compare `:313`; summary `:382`;
    - `FileTasks` `:424`;
    - `TaskProblem` `:493-510`;
    - private `RunAsProblem` `:553-576`.
  - `Screen/Tool/TaskImport.cls` (`:24`, `:41`, `:48`, `:52`, `:83`).
  - `Area/Task/TaskRules.cls`: `Validate:113-117`, `RunAsViolations:513-543`.
  - Consequence precedent: `Screen/Tool/TaskCreate.cls:224`.
- DW-1882:
  - `Kernel/Proposal/Operation.cls`: `Hold` `:57`, `Release` `:64`, doc `:16`.
  - `Kernel/State/Propose.cls`: `CLAIMLOCKSECONDS` `:378`, `TargetHoldKey` `:396`.
  - `Kernel/Proposal/Mint.cls:154` (TargetRef).
  - `Api/Error.cls:4304-4306` (`WRITE.TARGETBUSY`).
  - Callers today: `ScreenAction.cls:263-269,402`, `Confirm.cls:274,527`.
  - `Api/Router.cls` UrlMap; every `Area/**/*Save.cls` (and `WebApp/Create.cls`) `Handle*`.
  - `Kernel/Proposal/ReadBack.cls:8` (doc).
- DW-1641:
  - `Screen/Tool/OAuthServerDescriptionUpdate.cls` (`:20`, `:71`), `Screen/Tool/OAuthClientUpdate.cls:19`.
  - `Area/Security/OAuthServerSave.cls:288-296,323`, `Area/Security/OAuthClientSave.cls:246-254,281`.
  - `Area/Security/OAuthServerRules.cls:205-221`, `OAuthClientRules`.
  - Precedents: `OAuthRegisteredClientUpdate.MergeUpdate:91-100`, `OAuthAuthorizationServerUpdate.MergeUpdate:75-92`.
  - Create-mode texts: `OAuthServerDescriptionCreate.cls:97`, `OAuthClientCreate.cls:117`.
- DW-1013:
  - `Screen/Descriptor/ServiceList.cls`: `read` `:62-68`, doc `:14-17`.
  - `Screen/Tool/Read.cls:51`; `Screen/Registry.cls:1040` (`ReadNoteProblem`).
  - Precedent: `Screen/Descriptor/SqlActivityList.cls:54`.
  - `ui/src/app/core/strings.ts`, `ui/src/app/core/screens.generated.ts`, `EXPERIENCE.md:361`.
- DW-1864:
  - `Api/Response.cls:17`.
  - `Kernel/State/Entry.cls:43,190-195` (`StepsJson`, a stream).
  - `Kernel/Agent/Limits.cls:41,54`.
  - `Test/Http.cls:255` builds one string, so it cannot read the body.
- DW-1939 (client):
  - `ui/src/app/core/change-bus.ts:50-75,145-167`;
  - `ui/src/app/core/navigation.ts`: `screenForEntityType` `:461-473`, `screenForToolName` `:491`, `screenForChange` `:551`;
  - `ui/src/app/core/toasts.ts:193`;
  - `ui/src/app/shell/toast-host.ts:195,223`;
  - publishers: `turn.ts:1405`, `screen-action-handler.ts:1274`, `remote-database-form.store.ts:635`.
  - The lock key includes the entity type: `Propose.cls:386-398,490-498`.
- DW-1449:
  - `Api/Switches.cls`: `HandleRestraint` `:306`, `RestraintBody` `:384-405`.
  - `Kernel/Audit/Event.cls`: doc `:292-296`, `WritesMarked` `:300`, `RecordMarking` `:323`, `ObserveMarking` `:354`.
  - Seam precedent: `ScreenAction.PortClass` `:43`.
  - `Test/SwitchesWire.cls:376`.
- DW-1414 (client):
  - `ui/src/app/core/account-preferences.ts`: `faultValue` `:266`, `fault()` `:344`, `clearFault()` `:349`, set `:485-491`, cleared `:517`.
  - Readers: `home.page.ts:427,991-994,1081`; `locator-bar.ts:216,409,468-471,508`; `panel.ts:1027-1028`.
  - `ui/src/app/testing/account-preferences.ts`.
- DW-1637:
  - `Kernel/Proposal/Confirm.cls:494` (finalize), `:509`, `:530`.
  - `Kernel/State/Ledger.cls:170,173`.
  - New `Api/PortError.cls`, on the pattern of `Api/LockError.cls`.
  - `Test/AuditStarted.cls:91`; `Test/AuditStartedPort`.
- DW-1710:
  - `Kernel/Proposal/ReadBack.cls`: `:72-74`, `Of` `:78-91`, `ForSave` `:156-161`, `Compared` `:290`.
  - `Screen/Tool/Write.cls:369`.
  - `Screen/Tool/TaskCreate.cls:42,46,214`, `Screen/Tool/OAuthRegisteredClientCreate.cls:33,35`.
  - `Confirm.cls:508-512`.
  - `Test/ReadBack.cls:176-179`, `Test/TaskSave.cls:97`.
- DW-1465:
  - `Kernel/State/Propose.cls`: properties end `:196`; set/get `:263`, `:745`; `WireRow` `:788`.
  - `Screen/Tool/Write.cls:821-824`; `Kernel/Proposal/Mint.cls:296-310`.
  - Task tools; `EntityRef.cls:59,101-109`.
  - Client: `ui/src/app/core/proposal-view.ts:666`, `turn.ts:224,637-660`, `proposal-card.ts:569`.
  - `Test/TaskResume.cls:115-121`.

## Tasks & Acceptance

**Execution:**

- One implement pass per batch leaves the tree for one commit: `fix(23.4): batch <x> - <area>`.
- Each entry gives its defect, its reproduction or red, its fix and its ADs.
- The lead writes ledger trailers once the batch's commit is green.

### Batch a: CI and test-environment health

- [x] **DW-2034**: local throwaways sit under `/tmp`, which macOS's cleaner prunes, and `down` skips Compose when `compose.yml` is gone.
  - **Fix in `scripts/ci-throwaway.sh`:**
    - **Default dir.** Decide it after argument parsing, when neither `--dir` nor `OCUPILOT_THROWAWAY_DIR` is set: `$HOME/.ocupilot-throwaways/$PROJECT` when `uname -s` is `Darwin`, otherwise `/tmp/ocupilot-ci`. CI's commands and paths stay byte-identical.
    - **Guard (`:89-92`).** Add an arm for `"$HOME_ROOT/.ocupilot-throwaways"/?*`.
      - Normalize `HOME_ROOT` the way `ci-ipm-archive.sh:101-111` normalizes `TMPDIR`: strip trailing slashes; if it is not absolute, no arm is added.
      - Update the message at `:91`.
    - **`down` (`:751-759`).** If `compose.yml` is missing, run `docker compose -p "$PROJECT" down -v --remove-orphans`, but only when `docker compose ls -a --format json` lists `$PROJECT` with `ConfigFiles` equal to this dir's `compose.yml` (reuse `:136-137`).
      - Otherwise print why and make no Compose call.
      - The scrub and the dir removal run as today.
    - **New `data-check [--dir DIR]`, shaped like `product-check`:**
      - One `%SYS` session reads `SYS.Database:List`. Its Task 0 is a read-only probe on `ocupilot-ci`: which column says mounted, and how a remote row reads.
      - It checks for `IRIS.DAT` in each mounted local directory and prints `OCUPILOT-DATCHECK-START:<count>:<missing, ;-joined>:OCUPILOT-DATCHECK-END`.
      - It exits 1 on a missing file, a count of 0, a missing or garbled marker, or a failed session.
      - No `$$$` macros inside the session.
  - **CI.** Add a `sh scripts/ci-throwaway.sh data-check` step to instance-shard after `wait-readiness`, and append it to `DECLARED_GATES`.
  - **Tests in `ci.test.mjs`,** beside `:1403-1542`, with docker stubbed by `stub-bin.mjs` and the dir from `mkdtempSync(tmpdir())`:
    - **Fallback:** own file listed → down issued and the dir is gone. Another file → no down. Not listed → no down.
    - **Default dir:** stub `uname` (`Darwin` and `Linux`) and set `HOME=<scratch>`. Read the path from `logs`' "no compose file at …" line.
    - **Guard:** `$HOME/.ocupilot-throwaways/x` is admitted. `$HOME/.ocupilot-throwaways` itself is refused.
    - **`data-check`** (modeled on `runProductCheck`): a marker naming a dir → exit 1 naming it. Count 0 → exit 1. No marker → exit 1. All present → exit 0.
    - **`:1328-1351`:** exempt the one `-p` fallback line by its exact text, and assert that the `ConfigFiles` check precedes it.
  - **Docs:** `docs/DEVELOPMENT.md:547-551` names the default root, `data-check` and the fallback. No `.claude/rules` or README line names `/tmp/ocupilot-*`.
  - **ADs:** Conventions › Tests, AD-17.
  - **AC:**
    - Given a macOS host and no `--dir`, when `up` runs, then the throwaway lives under `$HOME/.ocupilot-throwaways/<project>`, and CI's Linux paths are unchanged.
    - Given a throwaway whose `compose.yml` is gone, when `down` runs, then Compose removes exactly that project.
    - Given a mounted database with no `IRIS.DAT`, when `data-check` runs, then it exits 1 naming the directory.

- [x] **DW-2102**: four instance legs take 48 to 60 min under 81. Run 37421343025: 60.5, 56.7, 53.0 and 48.3 min; wall time 60.9 min.
  - **Fix, in one commit.** A refresh on four legs alone reddens AC9: the floor reaches 82.0, above 81.
    - `cd ui && node tools/ci-shards.mjs refresh --run 37421343025` (0e38f829, green). Its suite total, 206.7 min against 201.8 for run 37352698013, shows it is not a slow-runner outlier.
    - `ci.yml`:
      - `:143` `shard: [1, 2, 3, 4, 5]`;
      - `:135` and `:186` `/5`;
      - `:232` `--shards 5`;
      - comments `:15` and `:131`.
    - `ci.test.mjs`: `:122`, `:128`; `SHARDED` `legs: 5` at `:2717`; the title at `:2752`. AC9 is unchanged.
    - `ci-shards.mjs:6` and `ci-runner.mjs:42`: `k/5`.
    - `docs/DEVELOPMENT.md:451-452,466`: five.
    - `README.md:490`: "four containers" becomes "five containers". The minutes are a Lead edit.
  - **Expected:** largest instance leg ≈41.3 min; AC9 floor 66.5.
  - **ADs:** Stack › CI, Operational Envelope › Build and CI, Conventions › Tests.
  - **AC:** Given batch (a)'s head, when CI runs, then:
    - instance-shard runs `1/5` to `5/5` from the refreshed timings;
    - `instance` is green, with every class in exactly one leg;
    - browser stays at three legs;
    - no `timeout-minutes` is lower;
    - the lead reports the longest instance leg and the wall time.

- [x] **DW-2026**: DevTools-protocol hangs fail whole specs. The a11y walk timed out at 730 s on `Runtime.callFunctionOn`; page creation timed out at 180 s on `Network.enable` (messages-log-files, data-table).
  - **Reproduce:**
    - a11y: hold the first `.woff2` after load, never released (23.3's hook), with `protocolTimeout` temporarily set to 20 s at `:48`. The before hook goes red in about 20 s.
    - A `Network.enable` hang cannot be induced; the fakes pin it.
  - **Fix:**
    - **New `ui/browser/protocol-retry.mjs`.** It wraps a launched browser so that a context or page creation failing with a protocol timeout (`/ timed out\. Increase the 'protocolTimeout'/`) is retried once in a fresh one. A hung one that resolves later is closed. Any other error propagates.
    - **`ui/browser.config.mjs`.** It imports that module, which wraps `puppeteer.launch` once (guarded). All 162 specs' launches then go through it with no spec edit.
      - It never spells `createBrowserContext(` or `browser.newPage(`; reach those through `.bind`, because of `browser-reset.mjs:64,74`.
    - **`structural-walk.mjs` `walk()`.** On the same error, rerun the pass once in a fresh signed-in context.
    - **`:48`'s 600 s stays.** That is 23.3's DW-1822 decision.
  - **Pin:** `ui/tools/protocol-retry.test.mjs`, with fake browsers:
    - a timeout, then success → two calls, one page;
    - two timeouts → throws;
    - another error → no retry;
    - a context's page creation is wrapped too.
  - **ADs:** Conventions › Tests.
  - **AC:** Given a page creation or a walk pass that hits one protocol timeout, when the spec runs, then it is retried once fresh and the spec passes. A second timeout still fails.

- [x] **DW-2058**: AC1's walk of the import dialog (`:222`) loses marked nodes.
  - **Cause (inference, from the code):** the classes list re-reads after the delete. `code-list.store.ts:394` sets the status line before that read. The read lands mid-walk and replaces the two marked check inputs.
  - **Reproduce:** hold the first classes-list read after the delete POST long enough to land inside the walk. Measure the walk first. Red at `:222`.
  - **Fix:** after `:216`, wait for that re-read (the spec's `rowsRead`) before the walk.
  - **AC:** Given the held re-read, when AC1 runs, then the walk starts only after the list re-reads, and it passes.

- [x] **DW-1925**: `reply.browser-spec.mjs:331` passes on any non-empty agent text, including the streamed block, so `:340` reads `href` null mid-stream (inference).
  - **Reproduce:** script the reply with `ScriptStream(tag, 0, <TextReply body>, 6)` through `runIris`. Red at `:340`.
  - **Fix:** wait for `.ocu-panel-message-agent:not(.ocu-panel-message-streamed) .ocu-panel-message-agent-text a`.
  - **AC:** Given the slow stream, when (b) runs, then it reads the final reply's link and passes.

- [x] **DW-1935**: the 15 s hang (`:209`) must also cover the other tab's whole sign-in (`:228`). On a slow runner turn 1 frees the slot first, so no lock banner appears (inference).
  - **Reproduce:** hold the second context's sign-in for 16 s. Red at `:231`.
  - **Fix:** sign in the other tab just after `:210`, before the hang starts, and close it in the outer `finally`.
  - **AC:** Given the held sign-in, when 'Second send' runs, then the lock banner appears and the test passes.

- [x] **DW-1983**: in `sendAndConfirm` (`:180-211`), `:193`, `:196` and `:197` are not scoped to the new card, and `:203-210` can match the streamed block.
  - **Reproduce:**
    - Stream turn 2's reply slowly with a mid-hang of about 40 s: test 2 goes red at `:193`.
    - A response-stage hold on the confirm (`Fetch.enable`, `requestStage: Response`) shows that `:197` does not wait.
  - **Fix:**
    - Scope the three lookups to the newest proposal card.
    - Replace `:203-210` with: the final non-streamed reply starts with the expected text, and the composer is enabled again.
  - **AC:** Given the slow second turn, when the DW-1405 test runs, then both toasts are seen and test 2 is unaffected.

- [x] **DW-1984**: `gate.browser-spec.mjs` test 6 looks up Cancel once (`:550-558`). The banner renders before the form's read answers.
  - **Reproduce:** after `FORM_PATH`, hold the form's first `/api/ocupilot` read for about 5 s. Red at `:558`.
  - **Fix:** before `:550`, `waitForFunction` for the Cancel button inside `.ocu-form-bar-actions`.
  - **AC:** Given the held read, when test 6 runs, then it finds Cancel and passes.

- [x] **DW-1873**: the pointer rests on the rail after `:216`. Its tooltip, revealed by `:hover` after 300 ms, overflows its slot at capture.
  - **Reproduce:** hover the rail item and wait 400 ms before each capture. Red at `:234`.
  - **Fix:** the overflow loop in `structural-walk.mjs` (`:388-420`) skips elements matching `[role="tooltip"]`. The page-scroll check at `:360-373` still applies.
  - **AC:** Given a hovered rail item, when web-sessions AC1 captures, then no rail tooltip is reported and a real overflow still is.

- [x] **DW-1916**: `nextTag` restarts per process, so a late call record leaks into the next run. Two specs never forget (`agent-picker`, `egress-line`).
  - **Reproduce:** seed `##class(OcuPilot.Test.TurnProvider).Script("REPLY2", 0, ##class(OcuPilot.Test.TurnProvider).TextReply("stale"))`. reply.browser-spec's first reply assertion goes red. Remove it with `Forget("REPLY2")`; `Remains("REPLY2")` should read 0.
  - **Fix:**
    - The tag becomes `${prefix}${RUN}n${count}`, where `RUN` is 4 random bytes in hex.
    - Record every tag issued; `disarmProbeDefinition` forgets them all in one `runIris` call.
    - Remove the workarounds in proposal-demo and process-control.
    - Reword `:86-88`.
  - **Pin:** a new `ui/tools` test imports `turnprobe-spec.mjs` twice (`?a`, `?b`). The tags differ, and each starts with its marker.
  - **AC:** Given a stale script under an old-format tag, when reply.browser-spec runs, then its replies are its own.

- [x] **DW-1917**: the reset leaves an empty-preset Policy row where none existed. Only governance and agent-sql write the policy.
  - **Reproduce:** Policy count is 0. Run governance.browser-spec. Count is 1.
  - **Fix:**
    - Each of the two specs reads the policy in `before`.
    - If its `rowVersion` is 0, a new `clearGovernancePolicy()` beside `runIris` runs `OcuPilot.Test.GovernanceFixture.Clear()` (with a status marker) at the end and asserts `rowVersion` 0.
    - `resetGovernancePolicy` is unchanged.
  - **AC:**
    - Given no stored policy, when either spec runs, then none is left.
    - Given a seeded policy (`GovernanceFixture.Apply`), when either spec runs, then the policy survives. Afterwards, `Clear()` reads back 0.

- [x] **DW-1929**: every spec that runs a turn leaves a `_SYSTEM` conversation, its entries, a turn, steps and ledger rows. `Retention` reddens on a container older than a day.
  - **Reproduce:** counts before and after one agent-ledger run go from 0/0/0/0 to Convo 1, Entry 1, Turn 1, Step ≥3.
  - **Fix:**
    - **New `TurnWireFixture.StateMark()`:** the high-water mark over Convo, Turn and Ledger IDs. Use one mark if they share the `State.Base` extent; verify that.
    - **New `TurnWireFixture.SweepSince(pMark, pUser)`.** It:
      - abandons and waits like `Sweep`;
      - deletes turns above the mark (`Turn.GuardedDelete` and `Ledger.GuardedDeleteForTurn`);
      - deletes conversations above the mark (`Convo.GuardedDelete`);
      - deletes the remaining ledger rows above the mark;
      - answers what is left, or `""`.
    - `armProbeDefinition` records the mark; `disarmProbeDefinition` sweeps and asserts `""`.
  - **AC:**
    - Given a clean throwaway, when agent-ledger runs, then all four counts read 0 after it.
    - Given turn-running specs have run, when `Retention` runs next on the same container, then it finds no `_SYSTEM` conversation the specs left.

- [x] **DW-1936**: ErrorDelete goes 6 of 15 under a stored override on its key. A source scan finds about 40 classes that reach the confirm gate without `GovernanceFixture` (inference).
  - **Reproduce:** `GovernanceFixture.Apply("", .s)` with `s("logs.applicationerrors.delete")="disabled"`. `ci-runner --class OcuPilot.Test.ErrorDelete` goes 6/15.
  - **Fix: one harness point.**
    - **New `GovernanceFixture.SetAside()`:**
      - if a previous run's copy is still held, put it back first;
      - snapshot into a holding global named on the `^OcuPilotTestAgentAside` pattern;
      - `Clear()`;
      - answer `ok` or the error.
    - **New `GovernanceFixture.PutBack()`:** `Restore`, then `Matches`, then kill the holding global; answer `ok` or the error.
    - **`scripts/ci-unit-test.sh`:**
      - before `PROBEAPPS-BEFORE`, write a `GOVASIDE` marker with `SetAside()`'s answer;
      - after `RunTest`, write a `GOVBACK` marker with `PutBack()`'s answer.
    - **`ci-runner.mjs`:** a missing marker, or one that is not `ok`, fails the class run, as `PROBEAPPS` does.
  - **Pins:**
    - `GovernanceRestore`: set aside a stored preset plus a disabled key → the store reads default; put back → it reads back equal. A held left copy is restored before a new set-aside.
    - `ci.test.mjs` (stubbed session): the order `SetAside`, then `RunTest`, then `PutBack`; and a `GOVBACK` that is not `ok` fails the run.
  - **AC:**
    - Given a stored override on a key a class confirms, when the class runs through `ci-runner`, then it is green and the override reads back unchanged afterwards.
    - Given a put-back that fails, when the run ends, then the runner reports the class run as failed.

- [x] **DW-2027**: `MappingCodeGlobals` walks every global in a routine database that is also the globals database. A stored `OcuPilot*` credential adds `^Ens.Conf.CredentialsD` and `^Ens.SecondaryData.Password`.
  - **Reproduce:** in HSCUSTOM, `##class(Ens.Config.Credentials).SetCredential("OcuPilotRepro2027", "u", "p", 1)`. Red at `:104`. Afterwards, `%DeleteId`, and `$Data` of both globals reads 0.
  - **Fix:**
    - Assert that `CODEGLOBALS` is a subset of the holders.
    - Accept an extra holder only when a compiled class's storage owns it (data, index, stream or id location; measure the dictionary query first).
    - Never exclude a declared member.
  - **AC:** Given the seeded credential, when the class runs, then it is green, and removing a `CODEGLOBALS` member still reddens it.

- [x] **DW-1297**: the install-lock refusal (`Installer.cls:544`) names no holder.
  - **Reproduce:** run `iris session iris -U %SYS 'Lock +^OcuPilotInstallLock("probe") Hang 120'` in the background on `ocupilot-ci`. `Installer.Install("probe")` refuses after 10 s.
    - Remove it by ending that session.
    - `$Data(^$|"%SYS"|LOCK("^OcuPilotInstallLock(""probe"")"))` should then read 0.
  - **Fix:** when the wait runs out, read the owner from `^$|"%SYS"|LOCK(...,"OWNER")` (measure the form first; `%SYS.LockQuery:List` is the fallback).
    - Name in the message: the pid, plus its routine, namespace and user from `%SYS.ProcessQuery`.
    - When no holder is found, say so.
  - **Pin:** `InstallLock.TestSecondInstallAndMarkRefuseWhileTheLockIsHeld` asserts that the refusal names `"process "_tChild`.
  - **ADs:** AD-38, AD-16.
  - **AC:** Given another process holds the install lock, when an install is refused, then the message names that process.

- [x] **DW-1915**: `AssertMasked` reads the screen once (`:133`). The vendor's audit index refresh gives up when its lock is held for more than 0.01 s, so the newest rows can be missing from that read (inference).
  - **Reproduce:**
    1. First read the value run 36949919497 failed on (`gh run view --log-failed`).
    2. Hold the index lock from a `%SYS` session for 5 s (confirm the global name with `iris_macro_info`). Red at `:133`.
    3. Release it; `^$LOCK` should show only WorkQueue owners.
  - **Fix:** each of the two reads polls for at most 15 s until "1 3", asserting "carries no key" on every answer.
  - **AC:** Given a 5 s index-lock hold, when the test runs, then it is green. A real masking regression still reddens at the bound.

- [x] **DW-1937**: `AddServer`'s own "Create Metadata" row can share the window's start millisecond (inference).
  - **Reproduce:** a temporary edit moves `tSince` above `AddServer`. Red at `:157`.
  - **Fix:**
    - The loop asserts only on the "Modify OAuth2 Server Definition" row for this issuer (`AuditPort.cls:120`).
    - Await that row on the screen read before the turn starts.
  - **AC:** Given the window opened before `AddServer`, when the test runs, then it is green.

- [ ] **DW-1938**: no code change. Planned disposition: `wontfix-accepted`.
  - Turn and Step loss is the product's own 900 s sweep (`Turn.GuardedSweep`, `Turn.cls:226,660-676`).
  - Preferences and the switches row are cleared by `PreferencesWire` and `SwitchFixture.Reset`'s 18 callers, which run only on throwaways and CI.
  - `reopen_if`: a release or upgrade check must read seeded preferences or switches back after a full sweep on the same instance.

- [x] **DW-1086**: Story 4.7 (237d9de7) extracted the helpers into `turnprobe-spec.mjs`; its markers follow `OCU-<name>-START`, and `scriptReply` asserts its status. What remains is dead private copies of `abandonTurns` and `slotOwner`, which nothing calls.
  - **Fix:** delete `navigate.browser-spec.mjs:104-124` and `context-chip.browser-spec.mjs:113-141`.
  - **AC:** Given the tree, when it is searched, then `abandonTurns` and `slotOwner` are defined only in `turnprobe-spec.mjs`, and both specs are green.

- [ ] **Ledger dedupe (lead step, the last ledger write of batch a).** This is the one sanctioned direct edit of `deferred-work.md`. Design Notes › Ledger dedupe gives the exact plan.
  - **AC:** Given the edit, when `ledger.sh load` runs, then:
    - DW-1223, DW-1864, DW-1925, DW-2027 and the new id each have exactly one `### DW-n:` block;
    - `total` falls by exactly 3;
    - DW-1223's error-log finding is under the new id, with no `resolved-by:5-8` trailer.

### Batch b: product correctness and safety

- [ ] **DW-1827** (p2, fix-risk high): an import review sees task names only.
  - **The defects:**
    - The task arm reads `RunAsUser`, which the narrowed payload never carries (`Mint.cls:283,323`).
    - The summary and compare carry only `Name (NS)` (`TaskTransferPort.cls:382,313`).
    - `TaskProblem` skips `TASK.NAME.SHAPE`.
  - **Red, in new `Test/TaskTransfer` methods:**
    - (a) `TestAnImportRunningAsAnotherAccountIsMintedDestructive`: expects `"1 TASK.RUNSASOTHER"`. Today it reads `"0 "`.
    - (b) `TestASameNamedRewriteIsRefusedChanged`: a `RunAsUser` leg and a `TaskClass` leg. Each expects `"409 TASK.IMPORT.CHANGED "` and no vendor call. Today it answers 200.
    - (c) Extend `TestOneTaskThatCannotBeCreatedImportsNothing` with a digit-first name and a 51-character name. Give the digit-first case its own cleanup, since `Probes()` matches only `OcuP164*`.
  - **Fix:**
    - **Summary.** One entry per task: `Name (NS) TaskClass as RunAsUser`. The compare is unchanged in form.
    - **`Examine`.** Collect the distinct `RunAsUser` values of the tasks to create. PREVIEW answers them; SCHEDULE answers them empty.
    - **`TaskImport`.** Add a `runAs` member to `SettableFields`, `READANSWERS` and `FINGERPRINTSUBJECT`, unadvertised like `tasks`. Its `Consequence` answers `TASK.RUNSASOTHER` when privileged. Its DESCRIPTION gains the run-as sentence.
    - **The task arm.** An import is privileged when any listed account differs from `$Username`, without regard to case. Extend the doc at `:3684`.
    - **`TaskRules`.** New public `NameProblem(pName)` (from `Validate:113-117`) and public `RunAsProblem(pUser)` (from `:513-543`). `TaskProblem` calls both. Delete the port's private copy at `:553-576`.
    - Reword the doc comments that name DW-1827 as the key's reason: `GovernanceBaseline.cls:55`, `Governance.cls:25`, `TaskTransferLive.cls:33,221`, `TaskTransfer.cls:91,104`.
  - **Also moves:**
    - `TaskTransfer:80`: the settable and subject pin.
    - `:342-346`, `:369`: the summary text.
    - `Prohibited.cls:448` (test): the settable count, from 3 to 4.
    - A person's import gets the name-shape refusal and nothing else new.
  - **ADs:** AD-10, AD-22, AD-54, AD-55, AD-6.
  - **AC:**
    - Given an import file whose task runs as another account, when the agent proposes it, then the proposal is destructive with `TASK.RUNSASOTHER`, and its `tasks` row names `TaskClass` and `RunAsUser`.
    - Given the file rewritten with the same name and a new class or account, when it is imported, then it is refused `TASK.IMPORT.CHANGED`.
    - Given a digit-first task name, when either caller imports it, then it is refused `TASK.NAME.SHAPE`.

- [ ] **DW-1869**: no code change. 23.3's batch d (f2168084) already judges every added address role by effect, in either spelling.
  - `Prohibited.AddressGrantsPrivilege` (`:4790`) uses `EntryParts` and `RoleGrantsAdministrativePrivilege` (`:3555`, `:3507`).
  - The pin is `ServiceUpdate.TestAnAddressRoleIsJudgedByEffectInEitherSpelling` (`:228`); its mutation is recorded at `:224`.
  - Planned disposition: `resolved-by:23-3-the-range-end-cleanup-part-3`, citing f2168084.

- [ ] **DW-1882** (p3, fix-risk med): no screen Save takes the per-target hold.
  - **Scope.** Measured at plan time from the UrlMap: 52 PUT/POST Save routes across 32 Area classes (inference until the coverage test lists them). There is no shared choke point, and the target of a create is in its body.
  - **Red:** new `ReadBackRoute.TestAWebApplicationSaveOnAHeldTargetIsRefusedBusy`, using the `:110-139` harness:
    - The test takes `Lock +^OcuPilotProposalTarget(<TargetHoldKey of web-application/instance/PROBEAPP>)`.
    - `PUT /web-applications/<enc>` answers 409 `WRITE.TARGETBUSY` in 9 to 15 s, with the Description unchanged.
    - After release: 200, readBack `matches`.
    - Today it answers 200 at once.
  - **Fix:**
    - **`Operation.HoldTool(pToolClass, pId, .pHeld, .pKey)`.** It builds the ref with the same computation `Mint.cls:154` uses: factor out one `TargetRefOf`, and have the mint call it.
    - **One shared 409 renderer.** An `Api.Error` method (methods add no parameter). `ScreenAction` reuses it.
    - **Every Save `Handle*`.** Hold after the id or body decode and before the fresh read. Release after the read-back, on every exit.
      - Singletons use `EntityRef.RULESINGLETONID`, creates use the body's name, and mappings use kind plus id.
      - Check each against its tool's mint.
    - Correct the docs at `Operation.cls:16` and `ReadBack.cls:8`.
  - **Coverage test, a new class.** Every PUT/POST route in `Router`'s UrlMap whose handler writes through a write tool calls `HoldTool`. Each exempt route is listed by name with a reason: the read-only POSTs, `/agent/*`, turn, proposal, conversation, account and the screen action route.
    - Its doc comment says it is a tripwire: a later epic's new Save reddens it until it adds the hold.
  - **ADs:** AD-34, AD-53, AD-55, AD-13, AD-9.
  - **AC:**
    - Given another process holding a target, when a person saves that target, then the Save waits `CLAIMLOCKSECONDS`, answers 409 `WRITE.TARGETBUSY` and writes nothing.
    - Given the router's write routes, when the coverage test reads them, then every Save calls `HoldTool`, and every exemption is listed with its reason.

- [ ] **DW-1641**: the agent's server-description and client-configuration updates send `Metadata` whole. `OAuthServerRules.Validate:205-221` then demands the endpoints of a partial edit.
  - **Red:**
    - Rewrite `OAuthServerUpdate.TestTheAgentsEditSendsTheCompleteSet` (`:255`), keeping its name for `SurfaceCoverage.cls:268`:
      - seed both endpoints and `scopes_supported`;
      - the agent sends `{"userinfo_endpoint": X, "scopes_supported": []}`;
      - the rows are `Metadata.userinfo_endpoint` and `Metadata.scopes_supported`;
      - the stored metadata keeps both endpoints, gains userinfo and clears scopes.
      - Today the mint is refused.
    - Extend `OAuthClientUpdate.TestTheAgentsEditKeepsTheRegistrationMembers` (`:179`): a seeded settable member the agent did not name is kept.
  - **Fix:**
    - Add `MergeUpdate` to both tools, on the pattern of `OAuthRegisteredClientUpdate.MergeUpdate`: merge over the fresh read, `Mint.Merge`, then one card row per changed member.
    - Move each Save's `MergedMetadata` into `OAuthServerRules` / `OAuthClientRules`, and have both Saves call the tool's `MergeUpdate`.
    - The server's `ArgumentProblem` checks member violations on the partial edit, then validates the merged result.
    - The client merge drops members that are not `Settable` (verify against `OAuthClientUpdate.cls:195`).
    - Reword the four descriptions: send only the members to change, and `""` or `[]` clears one.
  - **ADs:** AD-4, AD-55, AD-6.
  - **AC:** Given an agent edit naming two `Metadata` members, when it is confirmed, then only those members change, and the card shows one row each.

- [ ] **DW-1013**: `permissions.services.read` answers `[]` for an unrestricted service, and nothing says what that means.
  - **Red:** `PermissionsLists.TestTheServicesListReadsOverTheWire` (`:245`) asserts that the tool description the model receives ends with the note (pattern: `EcpSslConnectionWrite.cls:128-129`). Today it does not.
  - **Fix:**
    - ServiceList's `read` gains `"note": {"key": "serviceListNote", "text": "An empty Allowed IP addresses list (AllowedConnections) means any address may connect."}`. This is AD-36's note, read by both the screen and the tool (precedent: `SqlActivityList.cls:54`).
    - Add `STRINGS.serviceListNote`.
    - Regenerate `screens.generated.ts`.
    - Append the sentence to `EXPERIENCE.md:361`'s row on the same line, with an `[AMENDED, Story 23.4, DW-1013]` marker. Then run `npm run test:tools`.
  - **ADs:** AD-36, AD-24.
  - **AC:** Given the services read tool, when the model receives its description, then it says that an empty list means any address may connect. The Services screen shows the same sentence.

- [ ] **DW-1864**: `Response.cls:17` writes `pData.%ToJSON()` as one string, so a large restore raises `<MAXSTRING>` and answers 500.
  - **Red:** a new test class seeds a conversation (`Convo.LoadOrCreate`, then 10 calls to `Entry.GuardedAppend` of about 420 KB each, one non-ASCII character among them). It GETs `/conversation/:id` with `%Net.HttpRequest`, parses the response stream, and asserts:
    - 200;
    - `turns.%Size()=10`;
    - the character round-trips.
    - `OnAfterOneTest` removes it with `Convo.GuardedDelete`.
    - If it needs an arming variable, append it to `ci-throwaway.sh`'s roster and to `ci.test.mjs`'s pin.
  - **Fix:** `Response.JSON` does `%ToJSON` into a `%Stream.TmpCharacter`, then `OutputToDevice()`. The writer stays the only one.
  - **ADs:** AD-12, AD-39.
  - **AC:** Given a conversation whose JSON exceeds the local string limit, when it is restored, then it answers 200 with every turn in one envelope.

- [ ] **DW-1939** (fix-risk high): `screenForEntityType` picks Local databases (position 11) for a remote database's change. While Local databases is open, a remote change raises no toast.
  - **Option (b), an owner-aware lookup.** Option (a), a second entity type, would split AD-34's lock: the key hashes the type (`Propose.cls:386-398`).
  - **Red:**
    - `ui/tools/toasts.test.mjs`: an event `{type: 'database-configuration', id: 'REMX', tool: 'osmgmt.remotedatabases.create'}` routes to `os-management/remote-databases/…`, and on the Local databases URL it still raises one toast.
    - `navigation.test.mjs`: the `screenForChange` tool leg.
    - `toast-host.spec.ts`: the link reads "Open in Remote databases".
  - **Fix (client only):**
    - `ChangeEvent` gains an optional `tool`, passed through `publish`.
    - The confirm, the screen action handler and the remote form's Save pass their tool.
    - `screenForChange` uses `screenForToolName(tool)` when it is a built list of the same entity type. Otherwise it falls back.
    - `ToastEntry` carries the resolved descriptor; `toast-host.ts` uses it for the title and the route; `targetIsOpen` compares that screen.
  - **What else could move:** every type with more than one built list now opens its tool's own list. For example, `tasks.ondemand.run` opens On-demand tasks.
  - **ADs:** AD-14, AD-13, AD-34.
  - **AC:** Given a remote database confirmed by the agent while Home or Local databases is open, when its toast shows, then it reads "Open in Remote databases" and opens that list on the row.

- [ ] **DW-1449**: the banner's fact has no producer for a re-enable made outside OcuPilot.
  - **Red:** a new class `Test/MarkingRestraint`. A fixture extends `Api.Switches`, overrides `MarkingPortClass` to `Test.MarkingPort`, and exposes `RestraintBody`. The tests:
    - fact 0 with `Arm("1","1")`: the body answers `writesMarked` 1, and `Event.WritesMarked()` reads 1;
    - `Arm("0","1")`: stays 0;
    - `Arm("fault",…)`: stays 0 and nothing is written;
    - stored 1: answers 1 with no observation.
  - **Real-runtime leg:** in `auditing-write.browser-spec.mjs`, disable auditing through the screen so the banner shows, re-enable it through `runIris` (outside OcuPilot), and reload. The banner is gone.
  - **Fix:**
    - In `RestraintBody`, when `WritesMarked()` is 0: `Event.ObserveMarking(..MarkingPortClass(), .m)` runs at the caller's privileges. On OK with `m=1`, call `RecordMarking(1)` and answer 1.
    - New seam `MarkingPortClass()`, returning `OcuPilot.Port.AdminPort`.
    - Replace the sentence in `Event.cls:292-296`.
  - **Also moves:**
    - Re-pin `SwitchesWire.cls:376` through the seam with `Arm("0",…)`.
    - The mutation claims at `AuditingUpdate.cls:542,562` and in `auditing-write.browser-spec.mjs:288` now name only the disable direction.
  - **ADs:** AD-15, AD-53, AD-8, AD-9.
  - **AC:** Given auditing re-enabled outside OcuPilot, when a caller who can read the auditing flag loads the panel, then the banner clears and stays cleared.

- [ ] **DW-1414** (fix-risk high): one unscoped `fault()` slot.
  - A refusal shows twice on Home: `home.page.ts:427` and `locator-bar.ts:216`, both `role="alert"`.
  - A background success clears a gesture's refusal (`:517`).
  - `panel.ts:1028` reads the slot too.
  - **Red:**
    - `app.spec.ts`: the shell at `/` with a refusing stub. After Home's Clear, exactly one `[role="alert"]` reads the refusal. Today two do.
    - `account-preferences.test.mjs`: a refused `setValue(SHELL_KIND, SHELL_THEME, …)` gives `fault('home') === ''` and `fault('background') === reason`.
  - **Fix:**
    - `FaultOrigin = 'home' | 'favorite' | 'agent-pick' | 'background'`.
    - The writes take an origin, defaulting to `'background'`.
    - A refusal or success touches only its own slot.
    - `fault(origin)`; `clearFault(origin?)`, where no argument clears all.
    - Home reads `'home'`. The locator bar reads `'favorite'`, then `'background'`; it is on every screen, so it is the one announcer for background refusals. The panel reads `'agent-pick'`.
    - Update `ui/src/app/testing/account-preferences.ts`.
  - **Also moves:** `account-preferences.test.mjs:339,421`, `locator-bar.spec.ts:605` and `home.page.spec.ts:864` must pass origins.
  - **ADs:** AD-19, AD-50.
  - **AC:** Given a background write refused while Home is open, when it is announced, then exactly one alert carries it, and Home's own line stays empty.

- [ ] **DW-1637**: a 202-started write is finalized `ok` with an empty code (`Confirm.cls:494`).
  - **Red:** at `AuditStarted.cls:91`, assert `Status Code AuditMarked` equals `"ok PORT.STARTED " _ MARKEDYES`.
  - **Fix:**
    - New `Api/PortError.cls` holding `STARTED = "PORT.STARTED"`, its doc and `Codes()`, on the `LockError` pattern. Its reason is EXPERIENCE.md:516's "Still running on the instance. It finishes in the background."
    - At `:494`, the code is `$Select(+$Get(tWriteHttp)=202: <PortError.STARTED>, 1: "")`.
    - Add a `Code ""` assertion to one finished-write ledger test.
  - **ADs:** AD-26, AD-15, AD-41.
  - **AC:** Given a queued write still running at the bound, when it is confirmed, then its ledger row reads `ok · PORT.STARTED`. A finished write's code stays empty.

- [ ] **DW-1710** (decided): a list-row create compares only the 8 keys its row carries.
  - **Red:** new `ReadBack.TestAListRowCreateReReadsByCreatedIdThroughItsUpdateRead`. `ReadBackPort` is armed with one object, and it records the query (extend it).
    - `ForSave("…TaskCreate", …, {"Id": 7}, 201)` gives `differs ["Priority"]`, a GET, and id 7.
    - An OAuth leg reads through `clientId`.
    - With no created id the result is `unchecked`.
  - **Fix:**
    - `Write.cls`: a new `Parameter READBACKTOOL` plus an accessor.
    - `TaskCreate` names `TaskUpdate`. `OAuthRegisteredClientCreate` names its update tool, and gains `CreatedId` returning `pWritten.ClientId`.
    - `ReadBack.Of` gains `pCreatedId`, and re-reads through the named tool's endpoint and `IdParam` with no row key.
    - `ForSave` and `Confirm.cls:512` pass the created id.
    - Rewrite `ReadBack.cls:72-74` and the `:176-179` legs.
    - Route guards: `TaskSave.cls:97` and the OAuth create wire test expect `matches`.
  - **Task 0:** measure a real task create's GET on `ocupilot-ci`. A field the vendor normalizes gets its Classification `compare`.
    - Check that the OAuth change event's id (now the ClientId) matches the tab's row key.
  - **ADs:** AD-58, AD-54, AD-3.
  - **AC:** Given a confirmed task create, when it is read back, then it is re-read by its new id through `TaskUpdate`'s read, and every sent key in its field list is compared.

- [ ] **DW-1465**: a task card is titled by its id (`proposal-view.ts:666`). Every task tool is affected, and a create shows a case-folded name.
  - **Red:**
    - `ui/tools/proposal-view.test.mjs`: `targetName: 'Nightly purge'` gives the title "Proposal · Task Nightly purge" (EXPERIENCE.md:442).
    - A `proposal-card.spec.ts` leg: the rendered title reads the same.
    - A `Test/TaskResume` mint test: `targetName` is the task's Name.
  - **Fix:**
    - `Propose` gains `Property TargetName As %String(MAXLEN=256)` and `WireRow`'s `targetName`. A missing value reads as `""`, so `SCHEMAVERSION` stays (record that at the property).
    - `Write.TargetName(pFresh, pId, pArgs)` is a new hook that answers `""`.
    - `Mint` records the hook's answer.
    - The task tools:
      - a GET-read tool answers `pFresh.Name`;
      - `TaskCreate` answers `pArgs.Name`;
      - an INFO-read tool makes a second `Task.CRUD` GET through its port. That read never refuses the mint; on failure it answers `""`.
      - `TaskResume.cls:121` pins the last request type as INFO, so the name read comes first.
    - Client: `parseProposal` reads `targetName`. `ProposalCardView.title` uses `targetName`, falling back to `target.id`. `name` stays the id.
    - A process keeps its pid.
  - **ADs:** AD-6, AD-13, Conventions › When `SCHEMAVERSION` moves.
  - **AC:** Given a proposal for any task write, when its card renders, then its title names the task. If the name could not be read, it falls back to the id.

## Spec Change Log

- 2026-10-06, lead spec gate: DW-1869 closes `resolved-by:23-3-the-range-end-cleanup-part-3` (f2168084; pin `ServiceUpdate.TestAnAddressRoleIsJudgedByEffectInEitherSpelling` seeds `%Manager` and judges by effect in both spellings), because a `wontfix-accepted` or `by-design` would misstate a fixed defect. The lead runs `ServiceUpdate` in batch b's verification. Every other planned disposition and fix shape is accepted as written.

## Review Triage Log

### 2026-10-06 — Review pass

- verdicts: 9 findings — high 0, medium 1, low 5, false 0, maybe-false 3
- findings:

  - `[medium]` `[patch]` browser.config.mjs wiring of installProtocolRetry unpinned — added ui/tools/browser-config-retry.test.mjs; mutation: comment out the call, the test reddens, reverted byte-identical.
  - `[low]` `[defer]` structural-walk withRetry has no executed test — see deferred list.
  - `[low]` `[reject]` MappingCodeGlobals weakened to subset plus storage-owned — the spec directed the dictionary-query acceptance; the declared set is still asserted present.
  - `[low]` `[defer]` data-check session logic pinned as text — see deferred list.
  - `[low]` `[reject]` DW-2058, DW-1983 no reproduced red — recorded as such in the batch a results block; waits are in and green.
  - `[low]` `[patch]` SanitizeAuditMask stacked doc comments attach to the wrong parameter — MODIFYROW block moved above the AUDITRESOURCES comment; class recompiled, 0 errors.
  - `[maybe-false]` `[defer]` structural-walk retry theme persistence — see deferred list.
  - `[maybe-false]` `[defer]` turnprobe SweepSince without username — see deferred list.
  - `[low]` `[reject]` ci.test.mjs overlong comment line — cosmetic.

## Design Notes

**Integration ACs (Rules 1 and 2):** no service is introduced. Each shared piece has its consumer in the same batch:

- `protocol-retry.mjs`: every browser spec, through `browser.config.mjs`.
- `GovernanceFixture.SetAside` / `PutBack`: `ci-unit-test.sh`.
- `TurnWireFixture.StateMark` / `SweepSince`: `turnprobe-spec.mjs`.
- `Operation.HoldTool`: every Save.
- `READBACKTOOL`: `ReadBack`.
- `Write.TargetName`: `Mint`.
- `PortError`: `Confirm`.

Consumes: none.

**Governing ADs (Rule 6):**

| Batch | ADs |
| --- | --- |
| a | Stack › CI, Operational Envelope › Build and CI, Conventions › Tests, AD-17, AD-38, AD-16, AD-9, AD-35 |
| b | AD-10, AD-22, AD-54, AD-55, AD-6, AD-34, AD-53, AD-13, AD-9, AD-4, AD-36, AD-24, AD-12, AD-39, AD-14, AD-15, AD-8, AD-19, AD-50, AD-26, AD-41, AD-58, AD-3 |

No AC contradicts an AD.

**Declined:** none.

**Planned dispositions** (written by the lead's ledger tool at adjudication):

- DW-1869: `resolved-by:23-3-the-range-end-cleanup-part-3` (f2168084). The lead writes `wontfix-accepted` instead if it reads the AC's `resolved-by` as this story's commits only.
- DW-1938: `wontfix-accepted`, with the `reopen_if` above.
- Every other entry: `resolved-by:23-4-the-range-end-cleanup-part-4`, with its batch's commit.

**Why the fixes take these shapes:**

- **DW-2026:** the merge gate asked for one harness fix, not one per spec. All 162 specs import `browser.config.mjs`, so wrapping `puppeteer.launch` there reaches every spec without editing any. Editing 162 launch lines instead would add a merge surface for Epic 18.
- **DW-1936:** one `SetAside` around every class run covers the confirm gate's reachers (about 40, inference) and any class a later epic adds. A per-class hook would need about 40 edits and would miss the next class. A class run through the MCP runner is not covered; the rules route runs through `ci-runner`.
- **DW-1939:** option (a) would hash a remote and a local database of one name to different lock keys, and would need new `Prohibited` branches for the new type.
- **DW-1013:** AD-36's `read.note` is the existing mechanism that the screen and the tool both read. A tool-only field note would need a new descriptor key, registry validation and a mirror.
- **DW-2058:** the code does not bear out the ledger's picker-listing inference (`server-path-picker.ts:87-95,271-274`). The re-read after the delete is what replaces the marked inputs.

**Ledger dedupe** (lead, the last ledger write of batch a: after the batch's harvest, review filings and adjudication trailers):

- **The edit.** `ledger.sh append` writes to every block that carries an id, so the copies stay identical until the edit. Locate each block by `grep -n '^### DW-<n>:'`; the line numbers below are from the plan.
  - **DW-1864:** remove the first copy (`:8597-8603`). The second (`:8663-8670`) already holds every one of its trailers plus `2026-09-30T16:00:04Z`, in time order. If either copy holds a line the other lacks, merge it in timestamp order.
  - **DW-1925:** remove the second copy (`:9023-9028`). The copies are identical.
  - **DW-2027:** remove the second copy (`:9609-9614`). The copies are identical.
  - **DW-1223:** remove the second block (`:4967-4972`, the error-log finding). The first block, the proposal card, keeps its three trailers.
- **Re-file the DW-1223 finding.** `LEDGER_ID_COUNTER=/Users/jbrandt/git/OcuPilot/.worktrees/.coordination/ledger-next-id bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md new` with:
  - **Summary:** verbatim.
  - **Source:** `cycle-log-parallel.md (Epic 10 merge gate)`.
  - **Severity, fix-risk, footprint:** `med`, `low`, `out-of-footprint`.
  - **Evidence:** run 35466022679's five `page.goto` 30 s timeouts at `:342`; attempt 2 green; run 36483764167 (2026-09-28) attempt 1 explain-screen (c), the same shape.
  - **Status and owner:** `routed owner=range-end-cleanup by=lead`.
  - **Note:** `re-filed from DW-1223 (id collision); routed to 13-2 2026-09-19; 13.2 declined it (Epic 5's, no repro in 35477669085); seen again 36483764167`.
  - The filing is not absorbed into this story.
- **Counts.** Run `ledger.sh load` immediately before and after the edit.
  - `total` falls by exactly 3 (1566 → 1563 on today's ledger).
  - `owner:23-4-the-range-end-cleanup-part-4` falls by the number of non-terminal copies removed: 34 → 31 today. Once batch (a)'s trailers have made DW-1925 and DW-2027 terminal, only DW-1864's copy counts, so it falls by 1.
  - `ledger.sh show` on each of the five ids prints one block.
- **After every forward merge until feature carries the edit** (the Ledger tail hazard check): `grep -c '^### DW-<n>:'` reads 1 for the five ids, and each `show` ends on the expected trailer. A union merge that brings a trailer for a removed copy re-duplicates it; the lead removes it again in the merge commit.

**Lead edits** (Rule 20, and corrections at origin). Each spine amendment below is written by the lead at the batch boundary.

- **Spine amendment, batch a (DW-2102):**
  - Stack › CI: "the ObjectScript suite as four shard jobs and the browser specs as three" → "…as five shard jobs…". Append `[AMENDED, Story 23.4, DW-2102, Rule 20: was "four"]`.
  - Operational Envelope › Build and CI: "the ObjectScript suite split across four shards" → "five shards", with the same marker.
- **After batch a's green run, in a follow-up docs commit:** `README.md:491`'s "about 39 minutes" becomes that run's wall time.
- **DW-2034 real-runtime step, after batch a's commit:**
  1. Run `docker compose ls -a --format json` (read-only) to confirm `ocupilot-ci`'s `ConfigFiles` reads `/tmp/ocupilot-ci/compose.yml`.
  2. Remove `/tmp/ocupilot-ci/compose.yml`. Run `ci-throwaway.sh down --dir /tmp/ocupilot-ci --project ocupilot-ci`, which exercises the fallback; the container is gone and the dir is removed.
  3. Rebuild `ocupilot-ci` under `$HOME/.ocupilot-throwaways/ocupilot-ci`, with the same project, container and ports (52776/1975).
  4. Run `ci-throwaway.sh data-check` on it: exit 0.
  - The check's red is shown in the stub harness only.
- **Spine amendments, batch b:**
  - **AD-34:**
    - "A confirm and a screen row action on one scoped target are ordered by OcuPilot" → "A confirm, a screen row action and a screen's own Save on one scoped target are ordered by OcuPilot".
    - "A screen's own Save (AD-55) does not hold it yet (DW-1882)." → "A screen's own Save (AD-55) holds it the same way, under the key its tool's mint computes [AMENDED, Story 23.4, DW-1882, Rule 20]."
  - **AD-53:** "so a row action and a confirm on one target are ordered by OcuPilot (AD-34) […; a Save does not hold it yet, DW-1882]" → "so a row action, a Save and a confirm on one target are ordered by OcuPilot (AD-34)", keeping the DW-1497 marker.
  - **AD-58:** after "re-reads the target through the tool's declared port and read type", add "; a create whose declared read is a list row re-reads by its created id through its update tool's read (`READBACKTOOL`) [AMENDED, Story 23.4, DW-1710, Rule 20]". The Deferred row for DW-1710 changes its "Revisit when" to "Done in Story 23.4".
  - **AD-26:** "so the confirm records the write as applied and marks it (AD-15)" → "so the confirm records the write as applied, its ledger row carrying the code `PORT.STARTED`, and marks it (AD-15)".
  - **AD-22:** "ships disabled until DW-1827's review of `TaskClass` and `RunAsUser` on an import proposal lands" → "ships disabled; DW-1827's review of `TaskClass` and `RunAsUser` on an import proposal landed in Story 23.4, and re-enabling the key is the owner's decision".
  - **AD-53, the marking paragraph:** add "The restraint read is a third producer: while the stored fact reads not-marked, it re-observes the same two flags with the reader's own privileges and records marked when both read on (DW-1449) [AMENDED, Story 23.4, Rule 20]."

**Reported to the orchestrator at the boundary:**

- `CLAUDE.md`'s CI paragraph: "four shard legs" → five, and "about 39 minutes (run 36923461500)" → batch a's green run.
- `_bmad/custom/parallel.yaml`'s throwaway `dir:` values (`:40`, `:53`, `:66`) → `$HOME/.ocupilot-throwaways/<project>`.
- `tasks.schedule.import` stays disabled. Re-enabling it is the owner's decision.

**Contention:** Epic 18 is paused, and it touches Area Save classes and browser specs. This story's roster edits (`DECLARED_GATES`, the coverage test's exemptions, the arming roster) append only. The Save-hold coverage test reddens on any later Save that lacks the hold, and that is deliberate.

**User-visible changes:**

- A remote database's toast opens Remote databases.
- The auditing banner clears after a re-enable made outside OcuPilot.
- A refusal is announced once.
- A task card names the task.
- The Services screen shows the empty-list note.
- An import running as another account is confirmed as a delete is.
- A Save on a busy target answers "busy".
- The ledger shows `PORT.STARTED`.

**Named for filing** (new findings, not fixed here):

- `ci-throwaway.sh`'s `$TMPDIR` guard arm has no separator and no normalization, so `TMPDIR=/` admits any absolute path.
- The converse of DW-1449: auditing disabled outside OcuPilot leaves the banner hidden.
- The rest of DW-1637: a queued write's later worker failure is still not recorded, because the port never re-polls.
- DW-1827: a person's import dialog shows no run-as consequence line.
- DW-1827 (inference): a task file's `OutputFilename` and `OutputDirectory` against AD-21.
- DW-1465 (inference): other case-folded types show the folded id on the card.

## Verification

**Slot block.** One test run in flight, whatever the runner (`iris_execute_tests`, `node tools/ci-runner.mjs`, `node --test`, `npm run test:browser`). Await each in `%UnitTest_Result` or the browser run's exit. Never re-submit after a client timeout.

```yaml
  - name: a
    mcp_profile: ocupilot-slot-a          # the live `ocupilot` dev container (52774) -- NOT the throwaway
    dev_container: ocupilot
    dev_web_port: 52774
    dev_super_port: 1973
    throwaway:
      dir: /tmp/ocupilot-ci
      project: ocupilot-ci
      container: ocupilot-ci
      web: 52776
      super: 1975
      browser_origin: http://localhost:52776
      browser_container: ocupilot-ci
```

Every IRIS MCP call carries `server: "ocupilot-slot-a"` (the dev instance, never the throwaway). Load the throwaway without MCP. Every `ledger.sh new` runs with `LEDGER_ID_COUNTER=/Users/jbrandt/git/OcuPilot/.worktrees/.coordination/ledger-next-id`.

**`<throwaway dir>`** is `/tmp/ocupilot-ci` until the lead's DW-2034 step after batch a's commit, and `/Users/jbrandt/.ocupilot-throwaways/ocupilot-ci` from then on. Batch b uses the second.

**Shared loop steps:**

- **Load source (loop):** `rsync -a --delete src/ <throwaway dir>/src/`, then `Do $System.OBJ.LoadDir("/opt/ocupilot/src","ck-d",.e,1)` in `docker exec -i ocupilot-ci iris session iris -U HSCUSTOM`. Expected: 0 errors. Recompile the mutated class and every descendant before reading a mutation.
- **One class (loop):** `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`. Expected: 0 failed, confirmed in `%UnitTest_Result`.
- **One browser spec (loop):**
  - `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`;
  - then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/<name>.browser-spec.mjs`.
  - Expected: every leg passes.
- **Checks (loop):**
  - `uv run scripts/check-objectscript.py <changed .cls>` is clean.
  - `cd ui && npm run test:tools` is green when `ui/tools`, `ci.yml`, `EXPERIENCE.md` or a script changes.
  - `cd ui && npm run test:components` is green when a component changes.
  - `bash scripts/lint-docs.sh` is clean when Markdown changes.
- **Reproduction edits** are never committed; `git status --short` shows none before the commit. A probe's state is removed and read back as gone.

**Batch a (loop):**

- **DW-2034:**
  - `npm run test:tools` runs the new `ci.test.mjs` cases. The Task 0 `SYS.Database:List` probe on `ocupilot-ci` is read-only.
  - `mutation:` delete the `$HOME` arm → the "admitted under the local root" case goes red.
  - `mutation:` delete the fallback → no `compose -p … down -v --remove-orphans` is captured.
  - `mutation:` delete the `ConfigFiles` check → the "another file" case downs it.
  - `mutation:` invert the `IRIS.DAT` test, or drop the zero-count floor → the missing-dir or empty-list case exits 0.
  - `mutation:` default Darwin back to `/tmp` → the default-dir case goes red.
- **DW-2102:**
  - `cd ui && node tools/ci-shards.mjs assign --suite objectscript --shards 5`. Expected: largest leg ≈41.3 min.
  - `npm run test:tools` green.
  - `mutation:` drop `5` from the matrix → `:2756` goes red: "instance-shard runs legs 1 to 5; it declares [1,2,3,4]". AC9 also goes red: it needs 82.0.
  - `mutation:` leave the name at `/4` → `:2759` goes red: "labels its legs k/5".
  - `mutation:` leave `SHARDED` at `legs: 4` → `:2756` goes red.
  - The diff touches no `timeout-minutes`.
- **DW-2026:**
  - `protocol-retry.test.mjs` green.
  - a11y under the held font with the temporary 20 s timeout: red before the fix, green after. Clean run: 12/12.
  - `mutation:` create the page only once → the tools test goes red.
  - `mutation:` narrow the pattern to `Network.enable` → the `Runtime.callFunctionOn` case goes red.
  - `mutation:` remove the walk retry → a11y goes red under the held font.
- **Specs under their conditions,** each red before its fix, then green under the condition and clean after it:
  - `system-explorer-transfer` (the held re-read);
  - `reply` (the slow stream);
  - `turn` (the held sign-in);
  - `toast` (the slow second turn and the held confirm);
  - `gate` (the held form read);
  - `web-sessions` (the forced hover).
  - `mutation:` remove each added wait, scope or skip → its spec goes red under its condition.
- **DW-1916:**
  - Seeded `REPLY2`: `reply` red before, green after. Then `Forget` it, and `Remains` reads 0.
  - The new tools test is green.
  - `mutation:` revert to `${prefix}${count}` → both go red.
- **DW-1917:**
  - Policy count before and after `governance` and `agent-sql`: 0 and 0.
  - A seeded row survives the run.
  - `mutation:` drop the clear → count 1, red.
- **DW-1929:**
  - Turn-state counts before and after `agent-ledger`: equal.
  - `mutation:` skip the Convo branch → disarm's readback goes red.
- **DW-1936:**
  - ErrorDelete under the seeded override: 6/15 before, 15/15 after. The override reads back after the run; then `Clear()`.
  - Class `GovernanceRestore` green.
  - `mutation:` delete `SetAside` from `ci-unit-test.sh` → ErrorDelete 6/15 under the override.
  - `mutation:` ignore `GOVBACK` in `ci-runner.mjs` → the `ci.test.mjs` case goes red.
- **DW-2027:**
  - `MappingCodeGlobals` red under the seeded credential before, green after. Then delete the credential, and `$Data` reads 0.
  - `mutation:` drop the storage-owner exclusion → red.
- **DW-1297:**
  - `InstallLock` green, and the refusal names the holder.
  - `mutation:` read `^$LOCK` without `|"%SYS"|` → red.
- **DW-1915:**
  - `OAuthResourceServerAuditMask` red under a 5 s index-lock hold before, green after. Release the hold.
  - `mutation:` a single read → red under the hold.
- **DW-1937:**
  - `SanitizeAuditMask` red under the moved `tSince` before, green after. Revert, and `RemoveAll` probes.
  - `mutation:` drop the Description filter → red.
- **DW-1086:** `navigate` and `context-chip` green.
- **Proof, by the lead:**
  - CI is green on batch a's exact head, with `instance shard 1/5` to `5/5` and the `data-check` step.
  - Report the longest instance leg and the wall time.
  - Then the DW-2034 step and the ledger dedupe.

**Batch a, executed (implement pass):**

- DW-2034, DW-2102: `ci.test.mjs` 87 tests green; every mutation listed above went red and was reverted byte-identical (the `IRIS.DAT` test is pinned as text, since the stub answers the session). `SYS.Database:List` probe on `ocupilot-ci`: column 4 reads `Mounted/RW`, remote rows are not `/`-led paths (none present on the throwaway). `ci-shards.mjs assign --shards 5`: 41.3 min per leg.
- DW-2026: `protocol-retry.test.mjs` green; mutation: no retry in `retryOnce` and a narrowed pattern both red. a11y walk under a held font requested after load with `protocolTimeout` 20 s: red without the walk retry (22 s), 12/12 with it. No second-pass "late resolve" close exists: a rejected creation has nothing to close.
- DW-1925: red at the `href` read with `ScriptStream(...,6)`, green with the wait. DW-1935: red with a 16 s sign-in delay at the old position, green with the early sign-in. DW-1984: red with the form read held 5 s, green with the wait. DW-1873: red when the tooltip skip is removed (rail tooltip 406 px past its slot), green with it.
- DW-2058: the held re-read did not reproduce a red in 12 holds from 0.5 to 8 s; the wait is in place and the spec is green under a 3 s hold. DW-1983: a 40 s mid-hang fails both versions on the 30 s waits, and 20 s fails neither, so the red was not reproduced; the clean spec is green.
- DW-1916: stale `REPLY2` seed: `reply` red with the old tag format, green with the new; `Remains("REPLY2")` reads 0. `turnprobe-tags.test.mjs` green; mutation: old format red.
- DW-1917: policy count 0 before and after `governance` and `agent-sql`; without the clear it is 1 (version 2); a seeded policy survives and `Clear()` reads 0.
- DW-1929: counts Convo/Entry/Turn/Step equal before and after `agent-ledger`; mutation: skipping the Convo delete leaves Convo 1 and Entry 1 and disarm's assertion names them. `Retention` green.
- DW-1936: `ErrorDelete` 6 of 15 failed under a stored `logs.applicationerrors.delete` override without the set-aside, 15 of 15 with it, override read back and then cleared; `GovernanceRestore` 3 of 3; mutations in `ci-unit-test.sh` and `ci-runner.mjs` red.
- DW-2027: `MappingCodeGlobals` red under a seeded `OcuPilotRepro2027` credential, green after; mutation: no storage-owner acceptance red. The credential is deleted and both globals read 0. `^Ens.SecondaryData.Password` has no storage owner, so it is accepted by name (`CREDENTIALSECRETS`).
- DW-1297: `InstallLock` 6 of 6; mutation: lock table read without `|"%SYS"|` red (the owner reads empty from the install namespace). DW-1915: green under a 5 s on and 1 s off hold of `^IRIS.AuditI`, red with a single read; the holder was ended and the lock reads absent. DW-1937: green with `tSince` moved above `AddServer`, red with the Description filter dropped.
- DW-1086: `navigate`, `context-chip`, `proposal-demo` and `process-control` green.
- Checks: `npm run test:tools` 1855 of 1855, `check-objectscript.py` and `lint-docs.sh` clean, `npm run build` green.

**Batch b (loop):**

- **Classes:**
  - `TaskTransfer`;
  - `Prohibited`;
  - `ReadBackRoute`;
  - the new Save-hold coverage class;
  - `OAuthServerUpdate`, `OAuthClientUpdate`;
  - `PermissionsLists`;
  - the new conversation-restore class;
  - `MarkingRestraint`, `SwitchesWire`;
  - `AuditStarted`;
  - `ReadBack`, `TaskSave`, the OAuth registered-client create wire class;
  - `TaskResume`;
  - `GovernanceBaseline`;
  - `Envelope`.
  - Each new test is red before its fix, and every class is green after.
- **Client:**
  - tools: `toasts`, `navigation`, `account-preferences`, `proposal-view`;
  - components: `app.spec.ts`, `toast-host.spec.ts`, `home.page.spec.ts`, `locator-bar.spec.ts`, `proposal-card.spec.ts`;
  - `npm run build`, including `screen-mirror.mjs --check`.
- **Specs:** `auditing-write` and `service-editor`, against the redeployed bundle.
- **Mutations:**
  - `mutation:` drop the import branch or the `runAs` member from the task arm → (a) goes red.
  - `mutation:` drop `TaskClass` or `RunAsUser` from the summary → (b) goes red.
  - `mutation:` remove the `NameProblem` call → (c) goes red.
  - `mutation:` remove the hold from `WebAppSave.HandleUpdate` → the busy test goes red. Drop it from `DocDbSave` → the coverage test goes red.
  - `mutation:` `MergeUpdate` passes the arguments through unmerged → the kept-member assertions and the mint go red.
  - `mutation:` remove the `note` → `PermissionsLists` goes red.
  - `mutation:` revert to `Write pData.%ToJSON()` → the restore test answers 500.
  - `mutation:` drop the tool branch in `screenForChange` → the toasts and navigation legs go red.
  - `mutation:` remove the observe branch → `MarkingRestraint`'s first test and the `auditing-write` re-enable leg go red.
  - `mutation:` make `fault()` ignore its origin → both DW-1414 tests go red.
  - `mutation:` revert the `$Select` → `AuditStarted` goes red. Always answer `STARTED` → the finished-write assertion goes red.
  - `mutation:` remove `READBACKTOOL` from `TaskCreate` → the new `ReadBack` test goes red.
  - `mutation:` the hook answers `""` → both DW-1465 tests go red.
  - `mutation:` comment out `installProtocolRetry(puppeteer)` in `browser.config.mjs` → `browser-config-retry.test.mjs` goes red.

**Full sweep (once, before batch b's dev_complete):** `cd ui && node tools/ci-runner.mjs --container ocupilot-ci`, on the rebuilt throwaway, with no seeded state present. Expected: 0 failed, with totals taken from `%UnitTest_Result`. The full browser suite runs in CI's three browser legs (Rule 29).

**Each batch (lead):** push the code commit alone, and wait for CI green on its exact head.

## Auto Run Result

Status: done
Blocking condition: none

Batch a (17 entries, less DW-1938 and the ledger dedupe, which are the lead's) is implemented: throwaway directory, `data-check` and `down` fallback (DW-2034); five instance shards (DW-2102); protocol retry (DW-2026); wait, scope and cleanup fixes in the browser specs and test classes; governance set-aside in the runner. Review patched two findings (a config-wiring test, a doc-comment order) and deferred four to the spec's `deferred:` list. Follow-up review: false.

Verified: `npm run test:tools` 1856 of 1856; `check-objectscript.py` 0 problems; `lint-docs.sh` clean; src loaded on `ocupilot-ci` with 0 errors; each fix shown red then green under its reproduction on `ocupilot-ci` (DW-2058 and DW-1983 did not reproduce a red). The full sweep and full browser suite did not run (Rule 29). Residual: CI proof on the five-way split, DW-2034's real-runtime step, DW-1938 and the dedupe are the lead's.
