---
title: 'Story 23.1: The range-end cleanup'
type: 'chore'
created: '2026-09-26'
status: 'done'
baseline_revision: 'f30207594e8641fc86ccaa1db9ebcceee2ba9484'
baseline_commit: 'f30207594e8641fc86ccaa1db9ebcceee2ba9484'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      scripts/test_check_objectscript.py:1659 still says "expected the N-segment route named" in its assertion message.
    evidence: |-
      Same retired wording DW-1298 replaced in five places; the file belongs to Batch B3, so B1 did not touch it.
    location: >-
      scripts/test_check_objectscript.py:1659
    severity: low
  - summary: >-
      DESIGN.md :1181 specifies a 3px destructive bar under the header rule, but the card only recolors its 4px left edge (:1176), and mockups/key-proposal-states.html still draws a typed-name field on the destructive card.
    evidence: |-
      _components.scss .ocu-proposal-card-destructive sets border-left-color only; no under-header bar is drawn. Predates B1; the comments cite :1181 as the spec directed.
    location: >-
      ui/src/styles/_components.scss:4434, _bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/DESIGN.md:1181
    severity: low
---

<intent-contract>

## Intent

**Problem:** Rule 27 re-owned every closable ledger entry that did not block the floor to one symbolic owner, `range-end-cleanup`. That slice now holds 178 entries (97 low and 81 medium severity; fix-risk 128 low, 44 medium and 6 high), and many are stale, already fixed, or describe code that has since been rewritten. The ledger the judges' build leaves behind should be honest, and the code it names should be as correct as the time allows.

**Approach:** Every entry was verified against the current code and given exactly one disposition in `### Triage`: 79 fixes, 19 already resolved, 2 duplicates, 33 wontfix-accepted, 6 wontfix-theoretical, 5 by-design, 5 routed to Epic 14/16 stories, 25 routed to `burndown` and 4 escalated to the owner. The 79 fixes land in eight area batches, ordered lowest risk first, plus one set of document edits the lead applies itself (`L`). Each batch is one implement pass, one commit and one green CI run. The lead writes the 99 non-fix trailers at spec validation (`### Ledger trailers`), and writes a `resolved-by` trailer for each fix when its batch's commit lands.

## Boundaries & Constraints

**Always:**

- Work in `/Users/jbrandt/git/OcuPilot/.worktrees/epic-23` on branch `OCU-1-epic23`. Every IRIS MCP call carries `server: "ocupilot-slot-b"`, and every test and probe that can change instance state runs on the throwaway `ocupilot-b-ci`.
- An implement pass works **one batch only**, in the order B1 → B8. A batch never depends on a later one. A failing batch is re-opened alone.
- Shared-append files are added to, never reordered or reflowed: `ui/src/app/core/strings.ts`, `ui/src/styles/_components.scss` (new rules are appended; the in-place comment edits named in B1 keep their line count), EXPERIENCE.md's Fixed strings, `src/OcuPilot/Api/Error.cls` (new parameters are appended at the end), and the DW bullet runs in epics.md.
- **EXPERIENCE.md keeps its line count.** Record `wc -l` before and after. About 900 `/** EXPERIENCE.md:n */` citations depend on it.
- The client initial bundle stays under the `maximumWarning` of 1854kB; it is about 1.84 MB today. Record the total after any client batch. The lead stops the story above 1900kB.
- Prose discipline (`CLAUDE.md`): a doc comment states what the code does and its contract. It names no review round, DW id or story narration. A wrong sentence is replaced, never followed by a correction. Non-ASCII characters in source are written as `\uXXXX` (Rule 14).
- Rule 19: every fix with behavior gets a pinning test and a `mutation:` line in its batch's Verification. A comment-only or doc-only fix needs none; its task says so.
- Vendor behavior a fix depends on is measured on `ocupilot-b-ci`, never recalled (owner, 2026-09-23).

**Never:**

- Do not touch `release/1.0.0`, and cherry-pick nothing to it.
- Implement passes do not edit the spine, `CLAUDE.md`, `.claude/rules/`, `_bmad/custom/` or `epics.md`. Those edits are batch `L`, applied by the lead (Rule 20, instruction files, and other epics' story blocks).
- No implement pass writes the ledger. Do not stop, remove, recreate or `down` `ocupilot-b-ci`, `ocupilot`, any `ocupilot-slot-*` container, or `ocupilot-ci`.
- Do not fix an entry this spec dispositions as anything other than `fix`, and do not widen a fix beyond its task.
- Do not push a `[skip ci]` bookkeeping commit in the same push as a batch's code commit.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Demo restart (DW-1681) | `OCUPILOT_DEMO=1`, and the demo's `<DIVIDE>` entry is already logged in the install namespace | Start completes, the fixture reports "already present", and the entry count stays at one | A `SYS.ApplicationError` query fault returns its `%Status`, and install reports the step as failed, as it does today |
| Demo entry removed (DW-1681) | An operator deleted the demo entry, or retention purged it | The next start seeds exactly one | No error expected |
| Save pressed again after a stale refusal (DW-425) | The screen still holds the version it read, and the row has moved | 409 `STATE.CONFLICT` again, and nothing is written | A reload fetches the current version, and Save then answers 200 |
| Two confirms on one target (DW-1366) | Two live proposals on one scoped target, confirmed together | One writes; the other answers 409 `PROPOSAL.TARGETBUSY`, and its row stays live | The client offers Confirm again with the reason |
| A batch's CI goes red | The CI run on Bk's head fails | Bk is re-opened alone, and B(k+1)'s implement pass does not start | The fix lands in a new commit on the same batch |
| An entry already fixed | A `resolved` triage row | The lead appends `status=resolved-by:23-1-the-range-end-cleanup` with the earlier commit as evidence | No error expected |

</intent-contract>

## Code Map

- **B1 (comments and docs):** `scripts/ci-throwaway.sh:3`, `scripts/container-start.sh:51`, `scripts/container-health.sh:23-24`, `src/OcuPilot/Test/ProhibitedRoute.cls:1354`, `src/OcuPilot/Test/Wire.cls:905`, `src/OcuPilot/Api/Router.cls:1-26,71,250,991`, and `src/OcuPilot/Api/Readiness.cls:13` all point at README sections that now live in `docs/DEVELOPMENT.md` (`:255`, `:302`, `:369-376`, `:476`). `ui/src/app/shell/proposal-card.ts:663-671` holds the 14.7 comment; it is echoed at `proposal-card.spec.ts:840-842`, `_components.scss:4434-4436`, `Screen/Tool/AuditingUpdate.cls:8-9` and `ui/browser/auditing-write.browser-spec.mjs:216-217,235`. Also: `Kernel/Agent/Limits.cls:95-111`, `Test/CatalogAnthropicStub.cls:1-9`, `Test/ContextBound.cls:212-217`, `Test/AgentViolation.cls:214-215`, `Test/LedgerEmptyPairs.cls:68-70`, `Test/TurnSecretResidue.cls:104-106`, `Port/AdminPort.cls:144-147,709,720,1938`, `Test/Provenance.cls:238-240`, `Install/Installer.cls:3907`, `scripts/check-objectscript.py:120-121,1770,1834-1835`, `Test/ErrorReadStub.cls:56`, `ui/src/app/areas/web-applications/openapi-viewer.page.spec.ts:243`, `ui/browser/audit.browser-spec.mjs:535-549`, EXPERIENCE.md `:197,:382,:606,:611`, DESIGN.md `:898,:1181,:1242,:1272`, and `prds/prd-OcuPilot-2026-09-08/extract-catalog.md:530`.
- **B2 (install, smoke, demo):** the fixture's `Install/Fixture.cls` chain: `Create` at `:169`, `CreateErrorEntry` at `:660` and `SeedApplicationError` at `:766`, run by `Installer.cls:1199`. Its "Deliberately not guarded" paragraph is `:653-659`. `Port/LogSourcePort.cls` `ErrorsRead` shows how `DateList`'s value is passed to `ErrorList`. `Install/Smoke.cls:1737-1766` `Render` is parsed by `scripts/smoke.sh:222` (`failed=`). Also: `Installer.cls:3756,3768-3780` (the uninstall preview) and `:3908-3916` (the delete loop it mirrors), `Installer.cls:2113-2121` (`EnsureApplication`; its twin is at `:2206`), `Installer.cls:1449-1476` (`BundleIdentity`, reached through `Test/InstallerProbe.cls`), `Kernel/Shell/About.cls:303-309`, and `Test/WebApp.cls` (`TestTheInstallTimeAssertionRefusesAMissingMatchingRole`). DW-1439's claim sits in `docs/DEVELOPMENT.md:293-297`, `Installer.cls:2275-2282` and `WebApp.cls:263,308`.
- **B3 (CI, harness, test hygiene):** `scripts/check-objectscript.py:1408-1440` (`check_destructive_test_guard`) and `scripts/test_check_objectscript.py`. The eight production-install classes are `Test/{AuditEvent,AuditMarker,ConfigGate,State,Token,UnexpireScope,Version,Wire}.cls`. Also: `scripts/ci-throwaway.sh:239-249` (arming rosters, pinned by `ui/tools/ci.test.mjs`), `Test/PreferencesWire.cls:20-50`, `ui/browser.config.mjs:45,59-86` with `ui/tools/browser-config.test.mjs`, `ui/browser/tasks.browser-spec.mjs:53,460-466,637`, `Test/WireSecurityRead.cls:459`, `_bmad/scripts/ledger.sh:186-198` with `ui/tools/shell-scripts.test.mjs`, `scripts/ci-image-compile.sh:46` with `ui/tools/ci.test.mjs:1339`, and `scripts/ci-ipm-archive.sh:347,376-379` with `ui/tools/ipm-archive.test.mjs`.
- **B4 (structural gate):** `ui/browser/structural-walk.mjs:96-104,247,349`, `ui/browser/structural-baseline.json`, and the status-bar rules in `_components.scss:1737-1758`. The resize handle's 8px hit area is `:3208-3216` (DESIGN.md `:1140`). The per-screen 24px checkbox rules are `:5696-5704`, `:5804`, `:5839` and `:5850`. Also: `ui/browser/a11y-structural-invariants.browser-spec.mjs`, `ui/tools/structural-baseline.test.mjs`, `ui/browser/process-control.browser-spec.mjs:360-389`, and the `ProcessDetails.cls:59-65` descriptor.
- **B5 (client shell):** `ui/src/app/core/panel-layout.ts:98-134,352-371` with `ui/tools/panel-layout.test.mjs:291-316`, and `shell/rail.ts:226-254`, which follows `side-bar.ts:264`'s full-screen guard. `shell/recents-recorder.ts` has its `record()` gate, and `app.ts:622` only calls `reset()`. Also: `shell/locator-bar.ts:497-512`, `core/help.ts` (`load`, `helpHrefFor`) with `tools/about.test.mjs:201-213`, `app.ts:185-188,214`, and `shell/stale-bundle-notice.ts`, whose house idiom is `account-menu.ts:155`. `_components.scss:5281` sets `.ocu-home-system-row`, against DESIGN.md `:904` and `:912`.
- **B6 (provider, egress, ledger, gate):** `Test/TurnProviderFault.cls:8-12`, `Port/ProviderPort.cls:300-305,483-514` and `Test/ProviderProxy.cls:49-56`. `Kernel/Egress.cls:71` is exercised by `Test/Egress.cls:554-557`. `State/Agent.cls:165` feeds `Test/{AgentState,AgentSchema,DefinitionsFieldGapProbe}.cls`. `Kernel/Provider/MessageAdapter.cls:67-75` flows through `Kernel/Agent/Loop.cls:225` to `Provider/Base.cls:733`, pinned by `Test/Adapter.cls:609,1053-1058` and `Test/TurnStream.cls`. Also: `Kernel/State/Ledger.cls:251-252` with `Test/LedgerWire.cls`, `Screen/Gate.cls:177` (`EvaluateAnyOf`, dead), and `Test/ProviderPortOwner.cls:62-66,90` with `Test/PortGate.cls:137-139`.
- **B7 (proposal path, write and read tools):** `Kernel/State/Propose.cls:372-377,424,442,468-474` (`IsCapBusy` is the idiom to copy), `Kernel/Proposal/Write.cls` (`Codes`, `ReasonFor`, `Claim`), `Kernel/Proposal/Confirm.cls:340,418,436,736-745` and `Kernel/Proposal/Operation.cls:428,445`. `Kernel/Agent/Dispatch.cls:72-81,673-684` holds the duplicated pair check. Also: `Test/ProposalFixture.cls` (`RemoveSeeded`), `Screen/Tool/OAuthServerDescriptionUpdate.cls` and `OAuthClientUpdate.cls` (the pattern is `OAuthAuthorizationServerUpdate.cls:75-92`, the helpers `OAuthServerSave.cls:309` and `OAuthClientSave.cls:266`), `Area/Security/OAuthAuthorizationServerRules.cls:152,390`, `Kernel/Proposal/Disclosure.cls:45-86,142-168`, `Screen/Tool/Read.cls:47,80,136-165`, and `Screen/Descriptor/{Base,OpenApiViewer,WalletSecretList,ServiceList}.cls`. The entity-label sentences are in `Screen/Registry.cls:353-372` and `ui/tools/screen-mirror.mjs:515-517`, pinned by `Test/Descriptor.cls:1745-1764` and `ui/tools/screen-mirror.test.mjs:2271,2288`; the corpus pattern to follow is `Test/ReadSourceCorpus.cls`.
- **B8 (agent configuration handlers):** `Api/Definitions.cls:374,422-491,439,625,786,795,854-936,1323-1333,1349,1386-1391,1491` and `Api/Switches.cls:74-167,185,316,434-450`. `Api/Account.cls:168-180` duplicates `RenderViolations`. `Kernel/Denial.cls:59-62` is the one privilege sentence. Tests: `Test/{AgentConnection,DefinitionsFaults,SwitchesWire,AgentWire,AgentWireSecurity,AccountPasswordWire,Dispatch}.cls`. Client: `ui/src/app/areas/agent/{definition-form.store.ts,switches.store.ts}` with `switches.page.spec.ts:47` and `definition-form.page.spec.ts`.
- **L (lead):** the spine at `:72,:75` (DW-456), `:204` (AD-10's Story 14.7 clause, DW-1688), `:498` (AD-42, DW-1179), `:908` (Deferred row, DW-1319), and `:313` (AD-21, DW-1439, only if B2 measures a different answer); `epics.md:409,437,454,759,1368,2834`; `CLAUDE.md:121`; `.claude/rules/objectscript-testing.md:146-152`; `_bmad/custom/skill-rules.md:232,260`.

## Tasks & Acceptance

**Execution:** one implement pass per batch, in order. Each pass leaves the tree for one commit named `fix(23.1): batch Bk - <area>`. Every item states what the fix does and the files it touches. The lead applies batch `L` itself, alongside the batches, under Rule 20.

### Batch B1 — comments, doc text and fixture prose (17; no behavior)

- [x] DW-1682 (owner must-fix): repoint seven comments from README to `docs/DEVELOPMENT.md`'s section names: "Verifying the start path against a throwaway container", "The container start path", "The web applications and the client bundle" and "The readiness endpoint". Files: `scripts/ci-throwaway.sh:3`, `scripts/container-start.sh:51`, `scripts/container-health.sh:23-24`, `Test/ProhibitedRoute.cls:1354`, `Test/Wire.cls:905`, `Api/Router.cls:991`, `Api/Readiness.cls:13`.
- [x] DW-1688 (owner must-fix): replace `proposal-card.ts:663-671` with this contract. The tool's destructive flag turns the card's left-edge bar and its Confirm to the destructive treatment (DESIGN.md `:1181`, `:1242`). A destructive agent proposal has no typed-name field; the destructive bar, the destructive Confirm and the user's own press are its confirmation. Restate the same line with no story name at `proposal-card.spec.ts:840-842`, `_components.scss:4434-4436` (in place, same line count), `AuditingUpdate.cls:8-9` and `auditing-write.browser-spec.mjs:216` (comment) and `:235` (message). Correct DESIGN.md and EXPERIENCE.md as listed under `### Document corrections at origin`.
- [x] DW-1104: in PROVIDERCALLSECONDS's doc, say that the stored timeout and attempt count are clamped at the point of use (`Retry.EffectiveTimeoutSec`/`EffectiveAttempts` in `Base.Attempts`), which bounds what is configured and not the wall clock. Drop the DW id. File: `Kernel/Agent/Limits.cls:101-111`.
- [x] DW-1197: the header should say that Validate reads the real Catalog and that this class re-adapts the shipped anthropic row. File: `Test/CatalogAnthropicStub.cls:1-9`.
- [x] DW-1219: the recipe should say "the first leg, a private endpoint behind a public proxy, goes red", with the DW id dropped. File: `Test/ContextBound.cls:212-217`.
- [x] DW-1599: the assertion message should read "the thirteen cascade columns and the derived sentence, and none of adapterClass, authVersion or reasoningEffort". Delete the narration comment. File: `Test/AgentViolation.cls:214-215`.
- [x] DW-1325: delete the duplicated `$ZHex` narration paragraph from both classes and keep the one-line contract. Files: `Test/LedgerEmptyPairs.cls:68-70`, `Test/TurnSecretResidue.cls:104-106`.
- [x] DW-1264: the comments should name TYPESUFFIXES or a MUTATINGTYPES/CONNECTIONTESTTYPES pair, and both callers: Confirm's transition and the screen caller through `Kernel.Proposal.Operation`. File: `Port/AdminPort.cls:144-147,709,720,1938`.
- [x] DW-1272: the recipe should name the compound guard `If '$Data(tRemovedKeys(tRKey)), ...Exists(...) Continue`. File: `Test/Provenance.cls:238-240`.
- [x] DW-1277: change "(AD-21's both-directions invariant)" to "(AD-21: the floor role is created and removed by the installer)". File: `Install/Installer.cls:3907`.
- [x] DW-1282: replace the duplicated header with one short summary of the route families and the 404 override. Drop the false "only write verbs" claim. File: `Api/Router.cls:1-26`.
- [x] DW-1298: in five places, replace the "N-segment before (N-1)-segment" wording with "a longer route before a shorter one whose Url matches its leading segments". Files: `Api/Router.cls:71,250`, `scripts/check-objectscript.py:120-121,1770,1834-1835`.
- [x] DW-1313: replace the two retired refusal sentences with the current one. `Test/ErrorReadStub.cls:56` gets it through `##class(OcuPilot.Kernel.Denial).Reason()`; `openapi-viewer.page.spec.ts:243` gets it as a literal. Fixture text only.
- [x] DW-1385: add one caller-contract sentence to the AC2 leg's doc. Its counts are exact, so nothing else may write an OcuPilot- or seed-Source audit row during it, which holds because the suite runs one spec at a time on a throwaway. File: `ui/browser/audit.browser-spec.mjs:535-549`.
- [x] DW-1295: in EXPERIENCE.md `:382`, within the existing cell, say that the dialog's empty-field reason reuses the OpenAPI viewer's "Required" (`:358`). Same line.
- [x] DW-1376: in DESIGN.md `:898`, change the list to "Polish-week additions (system information, favorites, recents, shortcuts, links) go above or beside the grid."
- [x] DW-1318: change the cell at `extract-catalog.md:530` to `*extractor's note, resolved 2026-09-20:* per user, on the instance (AD-50; epics.md Story 15.2)`.

### Batch B2 — install, smoke and the demo fixture (8)

- [ ] DW-1681 (owner must-fix): add `EnsureErrorEntry(pInstallNs, Output pDay, Output pNumber, Output pSeeded) As %Status` to `Install/Fixture.cls`.
  - It switches once to `%SYS` (AD-16) and walks `SYS.ApplicationError` `DateList` then `ErrorList` for the install namespace. Take the date spelling from `LogSourcePort.ErrorsRead`; do not write it from memory.
  - An entry whose error text contains both `SeedApplicationError+` and `^OcuPilot.Install.Fixture` counts as the demo's own error. `ErrorLogSeed`'s entries do not match that.
  - If one exists, the method returns its (day, number) with `pSeeded=0`. Otherwise it restores the namespace and seeds, with `pSeeded=1`.
  - `CreateErrorEntry` calls it, keeps its read-back and `NoteRow` on both paths, and reports "already present - not re-seeded".
  - Replace the "Deliberately not guarded" paragraph (`:653-659`) with the guard's contract. Replace "puts one in on every start" with "keeps one present after every start" at `Test/ErrorLog.cls:2-3` and `Test/ErrorLogWire.cls:6-7`. `Test/Demo.cls`'s header and its first message should read "present, as reported by this run's fixture".
  - New test class `OcuPilot.Test.DemoErrorSeed`. `ARMINGVARIABLE` is `OCUPILOT_ALLOW_ERROR_SEED`; add an inline refusal on `OCUPILOT_ALLOW_ERROR_DELETE`, because it deletes. Add the class to both rosters in `scripts/ci-throwaway.sh`. Both variables are already armed on `ocupilot-b-ci`.
- [ ] DW-1119 and DW-1402: `Render` names the failed checks as `ocupilot-smoke: FAILED -- N check(s) failed: a, b`. It adds the skipped checks to the PASSED line as `ocupilot-smoke: PASSED -- N check(s) skipped: a, b`, only when N>0. The counts line stays byte-identical. File: `Install/Smoke.cls:1737-1766`. Tests go in `Test/Smoke.cls`.
- [ ] DW-1268: the preview lists `tURole` when the role exists and either its application is recorded or no application sits at its roster path, which mirrors the delete loop. Reword the `:3756` warn to "no web application, and no matching role of an application still present, will be removed". File: `Installer.cls:3756,3768-3780`. Add a new method to `Test/Provenance.cls`.
- [ ] DW-1323: the drift check also compares `Type` (expected 4) and repairs it. File: `Installer.cls:2113-2121`. Add a new `Test/IdentityInstall.cls` method using its DriftApplication pattern. If the instance refuses a Type drift, the pass records that measurement under Verification and ships no test; the lead then re-dispositions the entry `wontfix-theoretical`.
- [ ] DW-1374: add `BundleIdentityOf(pDirectory)` to `Test/InstallerProbe.cls`, plus a new `OcuPilot.Test.BundleIdentity` covering an empty argument, a missing directory, no `main-*.js`, and two `main-*.js` (the last one wins).
- [ ] DW-1373: new method in `Test/UiAboutRead.cls`. Call the real `Kernel.Shell.About.LogSourceFailure` with a unique field, find the appended `[OcuPilot]` messages.log line, and assert its level, subsystem and field (the `AuditingScreen.cls:142-166` tail pattern). Also call it with `pException=""` and check it does not throw.
- [ ] DW-1439: in `Test/WebApp.cls` `TestTheInstallTimeAssertionRefusesAMissingMatchingRole`, after the role delete, GET `/api/probeocupilot/readiness` anonymously and assert the measured status and body. If the measurement differs from "500 with `<PROTECT>`", replace that sentence with the measured mechanism at `docs/DEVELOPMENT.md:293-297`, `Installer.cls:2275-2282` and `WebApp.cls:263,308`, and record the measurement for the lead's AD-21 edit (L). If it matches, record it and change no text.

### Batch B3 — CI, harness and test hygiene (8)

- [ ] DW-419: when a class's code calls `Installer.Install("")` or `StartPath`, `check_destructive_test_guard` also requires a refusal on `OCUPILOT_ALLOW_PRODUCTION_INSTALL` (as `ARMINGVARIABLE` or an inline `GetEnviron`). Add that refusal to the eight classes and add them to the PRODUCTION_INSTALL roster. Delete the "seven further classes ... narrower effect" sentence. Files: `scripts/check-objectscript.py:1408`, `scripts/test_check_objectscript.py` (one fixture that must report a problem, and its armed twin that must pass), `Test/{AuditEvent,AuditMarker,ConfigGate,State,Token,UnexpireScope,Version,Wire}.cls`, `scripts/ci-throwaway.sh:239-249`.
- [ ] DW-1340: add `Parameter ARMINGVARIABLE = "OCUPILOT_ALLOW_ACCOUNT_PREFERENCES"` and the standard `OnBeforeAllTests` refusal. Add the compose env line and a `# classes: PreferencesWire` roster block. Files: `Test/PreferencesWire.cls`, `scripts/ci-throwaway.sh`. `ocupilot-b-ci` predates the variable, so the class refuses there. That refusal is this fix's local observable; CI's fresh throwaway runs it armed.
- [ ] DW-1015: `browserConfig` throws when the container is `ocupilot` or matches `/^ocupilot-slot-/`, naming the variable. Files: `ui/browser.config.mjs:59`, `ui/tools/browser-config.test.mjs` (two cases).
- [ ] DW-1425: the Story 6.6 AC1 and AC3 legs type `DEMO_TASK` instead of `'OcuPilotDemo'` and assert `search=DEMO_TASK` on the read URL. File: `ui/browser/tasks.browser-spec.mjs:460-466,637`.
- [ ] DW-1468: `AssertSameRowsAsTestAccount(..#TASKBOTHUSER, "tasks.history", "&search=OcuPilotDemo%20nightly")`. File: `Test/WireSecurityRead.cls:459`.
- [ ] DW-1433: `new` strips one leading `note=` from its note argument. Files: `_bmad/scripts/ledger.sh:186`, plus a case in `ui/tools/shell-scripts.test.mjs` run against a temporary ledger.
- [ ] DW-1332: the case arm becomes `*:latest|*:latest-*)`. Files: `scripts/ci-image-compile.sh:46`. In `ui/tools/ci.test.mjs:1339`, a behavioral test replaces the source match: with a stub `docker` on PATH, `:latest-cd`, `:latest-em`, `:latest` and a tagless reference each exit 2, name AD-27, and call no docker.
- [ ] DW-1689 (harvested from B1): the assertion message at `scripts/test_check_objectscript.py:1659` uses DW-1298's replacement wording ("a longer route before a shorter one whose Url matches its leading segments"). Text only.
- [ ] DW-1344: derive the floor from the repository's `module.xml` as 3 + the `<(Resource|FileCopy|Invoke|WebApplication|Dependency)[ />]` count + 1, and fail naming both numbers. Files: `scripts/ci-ipm-archive.sh:376-379`, `ui/tools/ipm-archive.test.mjs` (a fixture manifest with an extra `<Dependency>` must fail).

### Batch B4 — the structural gate (5)

- [ ] DW-1583: add `OVERFLOW_ALLOWANCES` `[{className:'ocu-panel-resize-handle', px:4, source:'DESIGN.md panel-resize-handle -- 8px hit area on the panel edge'}]`, pass it into `detectInPage`, and skip an overflow only when `past <= px + 1`. Remove every DW-1583 key from the baseline. Files: `ui/browser/structural-walk.mjs:96-104,349`, `ui/browser/structural-baseline.json`, `ui/tools/structural-baseline.test.mjs`.
- [ ] DW-1584: append `.ocu-status-bar-group:last-child { flex-shrink: 0; }` and `.ocu-status-bar-group:first-child { overflow-x: clip; }`, and remove every DW-1584 key. Files: `_components.scss` (append), `structural-baseline.json`.
- [ ] DW-1587: append `.ocu-field-checkbox, .ocu-criteria-marker { min-block-size: var(--ocu-space-6); }` and `.ocu-field-checkbox input:is([type='checkbox'],[type='radio']), .ocu-criteria-marker input[type='checkbox'] { inline-size: var(--ocu-space-6); block-size: var(--ocu-space-6); margin: 0; }`. First confirm that no `appearance: none` switch sits inside those labels. Remove every DW-1587 key. Files: `_components.scss` (append), `structural-baseline.json`.
- [ ] DW-1588: widen the walk's filter to `el instanceof HTMLElement || el instanceof SVGSVGElement`. File: `structural-walk.mjs:247`. This runs after DW-1583, DW-1584 and DW-1587. If it surfaces a fresh svg key that one appended CSS rule does not clear, revert this item, record the count and the first keys in frontmatter `deferred:`, and the lead re-owns DW-1588 as `routed owner=burndown`.
- [ ] DW-1471: add an "AC7, AD-43: Process details pauses" leg that follows the list leg at `:360`. It opens `/ocupilot/os-management/processes/<probePid>` with auto-refresh on, raises the proposal, waits for `data-paused=true` and `STRINGS.statusAutoRefreshPaused`, cancels, and waits for the pause to clear. File: `ui/browser/process-control.browser-spec.mjs`, after `:389`.

### Batch B5 — client shell and panel (9)

- [ ] DW-458: in `applyWidth`, when the side bar is not reopened, bound against the `panelMax` that `resolveLayout` gives with `sideBarPreferred: false`. A drag past the side-bar-shown maximum then yields the side bar again. File: `ui/src/app/core/panel-layout.ts:352-371`. Add a case to `tools/panel-layout.test.mjs`.
- [ ] DW-460: in `activate()`, after the gated check, handle full screen first.
  - Call `toggleFullScreen()` to leave full screen.
  - If the item does not navigate and its area is already the visible, shown side bar, return without toggling it.
  - Otherwise proceed as normal.
  - Files: `shell/rail.ts:226`, `shell/rail.spec.ts`.
- [ ] DW-1148: DESIGN.md `:904` becomes `| 1,920px | Home: collapsed · list: open | 960 | 912 | 400 | 1,232 | none |`. The test row resolves with Home's real `sideBarPreferred` (`areaHasSideBar(HOME_AREA_KEY)`) and expects `{sideBar 0, content 912}`. File: `tools/panel-layout.test.mjs:291-316`.
- [ ] DW-1341: `record()` returns early unless the session is `signed-in` or `probing`. Files: `shell/recents-recorder.ts`, `recents-recorder.spec.ts`.
- [ ] DW-1342: toggles chain per route through a promise tail, so each press reads `isFavorite()` after the previous request settles. The button is never natively disabled. Files: `shell/locator-bar.ts:497`, `locator-bar.spec.ts`.
- [ ] DW-1368: `helpHrefFor` returns `null` when the result is not ok and `''` for an unavailable answer. `load()` deletes the route from `asked` on `null`. Files: `core/help.ts`, `tools/about.test.mjs` (a fail-then-succeed case, the unavailable-asked-once case, and the existing test updated for `null`).
- [ ] DW-1371: render `<app-stale-bundle-notice />` only when no instance notice shows, through a getter: `installUnreadable || (signedIn && !instanceReady)`. Files: `app.ts:186`, `app.spec.ts`.
- [ ] DW-1372: keep a `<p class="ocu-visually-hidden" role="status">` always mounted. It holds `STRINGS.staleBundleNotice` when the bundle is stale and '' otherwise; the visible strip keeps no role. Files: `shell/stale-bundle-notice.ts`, `stale-bundle-notice.spec.ts` (the same node before and after), and the role lookup in `ui/browser/about-help-links.browser-spec.mjs:356`.
- [ ] DW-1392: `height:` becomes `min-height:` (an in-place edit). Files: `_components.scss:5281`, plus an assertion in `tools/design-tokens.test.mjs`.

### Batch B6 — provider, egress, ledger and gate (8)

- [ ] DW-1105: add a new leg. It stores proxy `127.0.0.1` through `State.Egress.SetGuarded`, runs a turn on the fixture definition, asserts that progress answers `PROVIDER.EGRESS` with no credential, and restores the prior Egress row. Replace the header's "no turn can carry an egress refusal". File: `Test/TurnProviderFault.cls`.
- [ ] DW-1217: append `100.100.100.200` to `METADATAADDRESSES` (`Kernel/Egress.cls:71`). Add `https://100.100.100.200/latest/meta-data` to `Test/Egress.cls` `TestACloudMetadataAddressIsRefusedInEveryFamily`; it is refused even when marked local.
- [ ] DW-1222: reword the three comments without a count ("every property SecurityFields names"). Add an `ApplyChange(tA,"HttpAcknowledged",1)` leg after ReEnable, asserting flags `"0|0"`. Files: `Test/DefinitionsFieldGapProbe.cls:5-6`, `Test/AgentSchema.cls:192`, `Test/AgentState.cls:300-304,336`.
- [ ] DW-1661: map `MALFORMED_FUNCTION_CALL`, `UNEXPECTED_TOOL_CALL` and `TOO_MANY_TOOL_CALLS` to a new MessageAdapter stop reason. `Loop` routes it to a new appended code, `PROVIDER.TOOLCALLFAILED`, with the reason "The model could not make a valid tool call. Try again, or rephrase the request." Rewrite the `GEMINISTOPREASONS` doc. Files: `Kernel/Provider/MessageAdapter.cls:67-75`, `Kernel/Agent/Loop.cls:225`, `Api/Error.cls` (append), `Provider/Base.cls` `ReasonFor`. Tests: `Test/Adapter.cls` (the `:609` case list; counts at `:1053-1058`), plus a `Test/TurnStream.cls` leg.
- [ ] DW-1172: `ArgumentsTruncated = ''pArgumentsTruncated || ($Length(pArguments) > +$Parameter(pLimitsClass,"LEDGERROWMAXLENGTH"))`. File: `Kernel/State/Ledger.cls:251-252`. Add a new `Test/LedgerWire.cls` method under `Test.LedgerLimits`.
- [ ] DW-1383: delete `ProviderPort.GateAnyOf` and `Screen.Gate.EvaluateAnyOf`, which have no callers. `GateAnyOfForUser`'s doc states the OR-set semantics. Reword the mutation text at `Test/ProviderPortOwner.cls:62-66` and `Test/PortGate.cls:137-139`. Compiling the package proves nothing called them.
- [ ] DW-1650 (decided at the 10.6 merge gate): the one transport retry in `Provider/Base.cls` `Attempts` excludes a connect that never opened -- `ERROR #6059` with no `HttpResponse` -- so a refused or unreachable endpoint fails after one attempt. Read the failure code from the `%Status` (measure the shape on `ocupilot-b-ci`, e.g. a Post to `http://127.0.0.1:1/` with Timeout 3). A broken connection after the request was sent keeps its one retry. Test: the existing transport-retry test class (`Test/ProviderTransportRetry.cls` or its equivalent) gains a connect-refused leg asserting one attempt. The lead amends AD-42 in L.
- [ ] DW-1322: after DW-1383, an OR-set refusal carries no `failedPair` detail, and the doc says so. Files: `Port/ProviderPort.cls:489-512`, `Test/ProviderPortOwner.cls:90`.

### Batch B7 — proposal path, write tools and read-tool descriptions (12)

- [ ] DW-1366: `Propose` gains `TARGETBUSYREASON` and `IsTargetBusy(status)` for the lock timeout, copying `IsCapBusy`. `Write` gains the code `PROPOSAL.TARGETBUSY` in `Codes()` and `ReasonFor`, with the reason "Another confirmation of this target is being applied. Try again in a moment." `Confirm.Transition` maps it to a 409 refusal that leaves the row live. Files: `Kernel/State/Propose.cls:376`, `Kernel/Proposal/Write.cls`, `Kernel/Proposal/Confirm.cls:340`. Tests: `Test/ProposalSpelling.cls` (the in-flight test flips to 409 `PROPOSAL.TARGETBUSY`) and `Test/ProposalRace.cls`.
- [ ] DW-1260: pass `pUser` to `GuardedExpireStale` in `GuardedClose` and `GuardedCloseLiveForConvo`, and drop the no-user sentence from its doc. File: `Kernel/State/Propose.cls:424,442,468-474`. Add a new `Test/ProposalRace.cls` method: user A's cancel expires A's stale row and leaves another user's live.
- [ ] DW-1283: `Dispatch.MissingPair` delegates to `Operation.MissingPair(pUser,pPairs,$ClassName())`, and the `HoldsPair` bodies in `Dispatch` and `Confirm` call `Operation.Holds`. Files: `Kernel/Agent/Dispatch.cls:72-81,673-684`, `Kernel/Proposal/Confirm.cls:736-745`.
- [ ] DW-1266: add `TestASecondEgressRowIsRefused`. It stores one row through SetGuarded, INSERTs a second, and asserts `SQLCODE<0` and a single row. File: `Test/ProviderProxy.cls`.
- [ ] DW-1267: on error, `RemoveSeeded` kills only the keys it processed, counts surviving Turn rows too, and tests with `$$$ISERR`. File: `Test/ProposalFixture.cls`. It is a fixture, pinned by its callers' teardown `pRemaining=0`.
- [ ] DW-1641: add `MergeUpdate` overrides that set `Metadata = <Save>.MergedMetadata(fresh, args.Metadata)` before `Mint.Merge`. Reword each DESCRIPTION and class doc to "merged over the stored metadata member by member; null clears a member". Files: `Screen/Tool/OAuthServerDescriptionUpdate.cls`, `Screen/Tool/OAuthClientUpdate.cls`. Tests: `Test/OAuthServerUpdate.cls` (it now asserts that unsent members are kept) and a twin in `Test/OAuthClientUpdate.cls`.
- [ ] DW-1662: on a create, the stored set is `StoredRoles(Defaults())`. File: `Area/Security/OAuthAuthorizationServerRules.cls:390`. In `Test/OAuthAuthorizationServerWire.cls`, the least-privileged create test becomes "CanCreateWithTheDefaultRoles" (201) and keeps a 422 for an added unreadable non-default role.
- [ ] DW-1436: `OrdinaryPaths` also returns `class=opaque` paths. `Rows` renders an opaque array value as a count, "1 value" or "<n> values", instead of `Mask()`, and secret paths are unchanged. File: `Kernel/Proposal/Disclosure.cls:45-86,142-168`. Test: `Test/ProposalWire.cls`, where the Users card's `EscalationRoles` row carries the count and a secret still carries the mask. Record the literal in DESIGN.md and EXPERIENCE.md as listed under `### Document corrections at origin`.
- [ ] DW-1637: at `:418`, pass the code `PORT.STARTED` when `+$Get(tWriteHttp)=202`. Append `Parameter PORTSTARTED = "PORT.STARTED"` to `Api/Error.cls`, with a roster row if `Test/Envelope.cls` requires one. File: `Kernel/Proposal/Confirm.cls:418`. Test: `Test/AuditStarted.cls`, where the ledger row reads ok, code `PORT.STARTED`, marked.
- [ ] DW-1001: `Descriptor/Base.cls` gains `ReadToolNotes()`, `{}` by default, shaped `{criteria:{param:sentence}, fields:{field:sentence}}`. `Read.AddCriteria` uses a criteria note in place of the generic text. `OpenApiViewer` and `WalletSecretList` answer "exactly one name, spelled exactly; a list or * is refused". `Registry.Validate` refuses a note naming an undeclared param or field. Files: `Screen/Tool/Read.cls:136-165`, `Screen/Descriptor/{Base,OpenApiViewer,WalletSecretList}.cls`, `Screen/Registry.cls`. Test: `Test/ReadTool.cls`.
- [ ] DW-1013: `ServiceList.ReadToolNotes()` sets `fields.AllowedConnections` to "An empty list means any address may connect.", and `Read.Description` appends each field note. Files: `Screen/Descriptor/ServiceList.cls`, `Screen/Tool/Read.cls`. Test: `Test/ReadTool.cls`.
- [ ] DW-1236: new `OcuPilot.Test.EntityLabelCorpus`, XData cases `{declaration, problem}` shaped like `ReadSourceCorpus`. `Test/Descriptor.cls:1745-1764` and `ui/tools/screen-mirror.test.mjs:2271,2288` iterate it in place of their literals.

### Batch B8 — agent configuration handlers (7)

- [ ] DW-426: `HandleTest` captures `+tRow.RowVersion` beside `ValuesFromRow` and passes it to `ConnectionOutcome` as a new parameter. `ConnectionOutcome` no longer calls `GuardedVersion`, and its four test callers pass the version they read. Files: `Api/Definitions.cls:795,862,880-889`, `Test/AgentConnection.cls:149,744`, `Test/DefinitionsFaults.cls:178,187`. Restate the comments at `:854-861` and `:876-879` as "captured at the open that read the stored values".
- [ ] DW-427: refuse an empty version only on the as-stored branch, before the call. File: `Api/Definitions.cls:880-889,919-921`. In `Test/DefinitionsFaults.cls`, the as-stored call with `""` answers 500 with 0 provider calls, and a not-as-stored leg makes the call and answers 200.
- [ ] DW-1286: pass the RowVersion read at `:733` into `ConnectionOutcome`, and assert `ProviderStub.Calls()=1` and the reason "The provider answered and the agent definition could not be marked verified". File: `Test/AgentConnection.cls:731-751`.
- [ ] DW-1165: pass `.tStage` at the six `ReadRequestBody` call sites. `RenderBadBody` takes an optional `pStage` and renders `RenderInternal` (500) for `read` or `decode`, and the 400 otherwise. Files: `Api/Definitions.cls:374,439,625,786,1349`, `Api/Switches.cls:110,185,450`, plus a `Test/Dispatch.cls` variant that accepts a prebuilt `BodyRequest` with `FaultOnContent=1`. Test: `Test/DefinitionsFaults.cls`.
- [ ] DW-1304: `RenderForbidden` returns `##class(OcuPilot.Kernel.Denial).Envelope(ADMINRESOURCE_":"_ADMINPERMISSION)`, and its doc becomes one line. Files: `Api/Definitions.cls:1323-1333`, `Test/AgentWireSecurity.cls:232,300` (assert the reason), and the fixture text at `switches.page.spec.ts:47`.
- [ ] DW-1294: `Definitions.RenderViolations` takes `pCode As %String = AGENTVALIDATION`, and `Account.RenderViolations` delegates to it with its own code. Files: `Api/Definitions.cls:1386`, `Api/Account.cls:168-180` (its doc says it delegates "with this route's code").
- [ ] DW-425: the switches GET reads the version before `Resolve`. Both PUTs take an optional JSON-number `rowVersion` and pass it as the expected version, and a body without it behaves as today. `definition-form.store.ts` and `switches.store.ts` keep the version from the load and from each 200, and send it on save. Replace "no version token crosses the wire" at `Switches.cls:119-124` and `SwitchesStaleProbe.cls:14-16` with "the version is the one the screen read, sent back on save".
  - Server files: `rowVersion` is added to `FullProjection` and `Switches.Projection`; `Api/Definitions.cls:422-491,1491`, `Api/Switches.cls:74-167,316`.
  - Client and tests: `ui/src/app/areas/agent/{definition-form.store.ts,switches.store.ts}`, `Test/SwitchesWire.cls`, `Test/AgentWire.cls`, `switches.page.spec.ts`, `definition-form.page.spec.ts`.

### Batch L — document and instruction-file edits the lead applies (9 + planning halves)

Each fix below is sentence replacement, not an appended erratum. Spine edits follow Rule 20's light path: memlog, `lint_spine.py`, then refresh `updated:`.

- [x] DW-456: spine `:75` becomes "The registry never depends on kernel behavior (turn, provider, governance). It may name value types, stores and the error vocabulary, and a write tool calls the proposal kernel's mint and prohibited-set entry points (AD-6, AD-10)." Label the diagram's forbidden edge at `:72` to match.
- [x] DW-1179: in AD-42 `:498`, "so a provider that drips its response is bounded by AD-31's turn limits instead" becomes "so a call whose provider keeps writing runs until it stops; AD-31's limits are read at the next step boundary after the call returns, and no transport-level attempt bound is added".
- [x] DW-1319: in the Deferred row at spine `:908`, the decision clause becomes "refuse it at use: every request reads `Enabled` in OnPreDispatch and answers 401 AUTH.DISABLED". The status cell becomes "Decided; implemented in Story 5.4".
- [x] DW-1688 (planning half): in AD-10 `:204`, "the destructive treatment and the typed-name field of Story 14.7" becomes "the destructive treatment, with no typed name (owner plan 2026-09-25)". In epics.md `:454` (UX-DR58), "only after the typed name matches" becomes "in a confirm-dialog only after the typed name matches".
- [x] DW-1338: epics.md `:759`, "a dry-run build" becomes "a local `package` build". The `:5623` half ("dry-run or local form" becomes "local form") is in Story 13.3's block and is escalated, not applied.
- [x] DW-1413: in epics.md at `:409` and `:437`, "per browser" becomes "per user, on the instance". The `:1368` and `:2834` AC lines are in Stories 1.9 and 4.3 and are escalated, not applied.
- [ ] DW-1185 (escalated to the owner, not applied): add to `.claude/rules/objectscript-testing.md` under "A mutation means nothing until the whole tree is recompiled". Run mutations on the throwaway only. A mutation can leave process state, such as an open capture, in a pooled Atelier worker; a later red on reverted code that says "Capture Already Active" is that leftover, not a regression.
- [ ] DW-1434 (escalated to the owner, not applied): add to `_bmad/custom/skill-rules.md` Rule 28 (`:260`): push the implement or merge commit on its own, and confirm its run registered by `headSha` in `gh run list`, before stacking any `[skip ci]` commit, because GitHub evaluates only the pushed head.
- [ ] DW-1435 (escalated to the owner, not applied): add to `_bmad/custom/skill-rules.md` Rule 22 (`:232`): when the merge brings ObjectScript, load the merged `src/` into a fresh or re-loaded throwaway before the suite. The merged tree's browser tier is CI's browser job.
- [ ] DW-1478 (escalated to the owner, not applied): append to the `CLAUDE.md:121` bullet: "a planning document other suites cite by line (EXPERIENCE.md, epics.md) also needs `cd ui && npm run test:tools`".
- [ ] DW-1650: in AD-42, after "is retried **once, on a new connection**, inside the same attempt and delay budget", say that a connect that never opened (`#6059`, no connection) is not retried; mark the Deferred row DW-1650 decided (10.6 merge gate). Applied with B6.
- [ ] DW-1439 (conditional): if B2 measured a different answer than the documented 500 `<PROTECT>`, replace AD-21 `:313`'s sentence with the measured mechanism.

**Acceptance Criteria:**

- Given the ledger slice on owner `range-end-cleanup`, when the story completes, then `bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md slice range-end-cleanup` prints nothing. Each of the 178 entries carries its final trailer: one of the 99 `### Ledger trailers`, or, for a fix, `status=resolved-by:23-1-the-range-end-cleanup ... note=commit <sha>` naming its batch's commit.
- Given an entry of low fix-risk whose fix stays inside the code it names, when it is triaged, then its `### Triage` row is `fix`, or the row's reason says why not. A medium or high fix-risk `fix` row carries its justification.
- Given a batch Bk, when its implement pass completes, then it lands as one commit touching only that batch's files, and the CI run on that commit's head reads `success` before batch B(k+1)'s implement pass starts. A failing batch is re-opened alone.
- Given a fix a judge can see, when it lands, then it is listed under `### Judge-visible changes` with its DW id. Given a fix that contradicts a document, then that document is corrected at origin as listed under `### Document corrections at origin`, and EXPERIENCE.md's line count is unchanged.
- Given DW-1681, DW-1682 and DW-1688, when the story completes, then each is fixed in B1 or B2. A container start that finds the demo `<DIVIDE>` entry seeds no second one (`OcuPilot.Test.DemoErrorSeed`). No comment in `scripts/`, `src/` or `ui/` points at a README section that moved. No source file names Story 14.7.

## Spec Change Log

- 2026-09-26, lead at spec validation: (1) an already-fixed entry closes `resolved-by:23-1-the-range-end-cleanup` with the earlier commit as evidence, not `dropped`, which the grammar keeps for invalid or duplicate entries. (2) DW-1650 moves from `burndown` to B6 + L: its ledger trailer records the owner's decision at the 10.6 merge gate, so only the spine's Deferred row was stale. (3) DW-1185, DW-1434, DW-1435 and DW-1478 are escalated to the owner rather than applied: they edit instruction files (`CLAUDE.md`, `.claude/rules/`, `_bmad/custom/skill-rules.md`), which no agent may change on another agent's say-so; the drafted text stays in Batch L for the owner. (4) DW-1338 and DW-1413 are applied only outside other epics' story blocks; the story-block lines (Stories 1.9, 4.3, 13.3) are escalated for the orchestrator. (5) A batch's commit and the lead's review/bookkeeping commit are pushed together, never with `[skip ci]`; the lead's Batch L commit rides with B1's push.

## Review Triage Log

### 2026-09-26 — Review pass (Batch B1)

- verdicts: 12 findings — high 0, medium 4, low 7, false 1, maybe-false 0
- findings:
  - `[low]` `[reject]` verification-gap: the route-ordering message tail has no assertion past "shorter route" — B1 is text-only with no pinning test by design, and the assertion would live in B3's `test_check_objectscript.py`.
  - `[medium]` `[patch]` verification-gap: EXPERIENCE.md `:192`, `:660`, `:743` still gave a destructive proposal a typed-name field, contradicting `:197/:606/:611` — rewritten in place; line count stays 981.
  - `[medium]` `[patch]` verification-gap: AdminPort's "two callers" paragraph missed the editor Saves that call the port directly and the install smoke — paragraph restated against the code (Operation for Confirm and screen actions/Saves, AD-53/AD-55; direct Save handlers after AD-10; the smoke's restore).
  - `[low]` `[patch]` verification-gap: retired N-segment wording left at `RouterFixture.cls:53` and `test_check_objectscript.py:1659` — fixture comment rewritten; the test message is B3's file and is in `deferred:`.
  - `[low]` `[patch]` verification-gap: `check-objectscript.py` docstring restated the rule twice and ran to 118 columns — rewritten once, wrapped.
  - `[medium]` `[patch]` intent-alignment: AdminPort caller claim does not hold (same root cause as the verification-gap row) — same patch.
  - `[medium]` `[patch]` intent-alignment: EXPERIENCE.md still contradicts itself on the typed-name field (same root cause) — same patch.
  - `[low]` `[defer]` intent-alignment: DESIGN.md `:1181` names a 3px under-header bar the card never draws; the comments cite it for the left edge — pre-existing design/code gap, in `deferred:`.
  - `[low]` `[patch]` intent-alignment: DW-1298 incomplete and circular (same root causes as the two rows above) — same patches.
  - `[low]` `[patch]` intent-alignment: a `; DW-441:` narration prefix remained in `ContextBound.cls` — prefix removed.
  - `[false]` `[reject]` intent-alignment: several edited lines run in no test — they are fixture and message text; the tree compiles with 0 errors and B1 carries no behavior by design.
  - `[low]` `[patch]` intent-alignment: the Router header omitted `/agent/context`, the provider catalog, and the editors' checks — added.

## Design Notes

**Integration ACs (Rules 1 and 2):** No consumers in this story; cleanup only. It introduces no service, module or shared component. `ReadToolNotes()` (DW-1001) is a descriptor hook whose one consumer, `Screen/Tool/Read`, lands in the same batch.

**Governing ADs, by batch (Rule 6).**

- B1: AD-10 (a destructive agent proposal), AD-21, AD-2 and AD-26 (AdminPort types), AD-42, and Conventions › REST route ordering.
- B2: AD-25 (the fixture is opt-in and namespaced), AD-48 (`SYS.ApplicationError` only, with no `^ERRORS` walk), AD-16, AD-17, AD-21 (the anonymous floor), and AD-45 (one smoke path).
- B3: AD-27 (a pinned image, with no rolling tag) and AD-17 (the manifest is generated from one roster).
- B4: AD-43 (the proposal pause), DESIGN.md geometry, and NFR-12's target size.
- B5: AD-19, AD-28 (session), AD-50 (preferences).
- B6: AD-42 (the egress denylist and the adapters' stop reasons), AD-35, AD-41, AD-8, AD-29, AD-39 and AD-12 (new codes are appended to the enum).
- B7: AD-34 (the loser is refused, not failed), AD-6, AD-8, AD-4 (merge metadata member by member), AD-26 (the queued write "started"), AD-15, AD-5, AD-36 (a note describes the view and never widens it), and AD-3 (the opaque class).
- B8: Conventions › Concurrent writes (a refusal the operator can clear by pressing Save again is not a refusal), AD-12, AD-39 and AD-8.
- L: Rule 20.

Entries whose fix would contradict an AD are dispositioned `by-design` and name the AD: DW-1259 (AD-8), DW-1350 and DW-1356 (AD-10 as amended), DW-1466 (AD-43).

**Constraints each fix respects:** shared-append files are added to only, with the in-place comment edits named in B1. EXPERIENCE.md's line count is unchanged. The bundle stays under 1854kB (every client fix is within about ±150 B). Prose discipline and `\uXXXX` apply. Rule 19 gives a pinning test and a mutation to every behavior fix. Vendor behavior is measured, never recalled.

**How the batches were cut:** by area and by risk. Doc and comment fixes come first, then the install path and its must-fix, then CI and harness scripts, then CSS, then client shell code, then kernel code, and last the agent-configuration handlers (DW-425 adds a wire field). DW-426 goes before DW-427, DW-1286 and DW-425. DW-1383 goes before DW-1322. DW-1583, DW-1584 and DW-1587 go before DW-1588. All of these pairs fall inside one batch.

**Routed entries:** DW-1076 → 16.15, DW-1081 → 14.1, DW-1122 → 14.4, DW-1400 → 16.18 and DW-1423 → 16.17. Each touches code those stories' ACs name. The 26 `burndown` entries are all medium severity (Rule 15: `burndown` never owns a low).

### Judge-visible changes

- DW-1681 (B2): with the demo on, Logs › Application errors for the install namespace holds one demo `<DIVIDE>` entry however many times the container restarts, instead of one more per restart.
- DW-1584 (B4): at 720px (200% zoom), the status bar's connection word and refresh stamp show whole. The left group's tail is clipped instead.
- DW-1587 (B4): checkboxes and radios on eight form and filter screens draw at 24px, as they already do in the SSL and task editors.
- DW-458 (B5): at a laptop width, the agent panel can be dragged wider again after it was narrowed.
- DW-460 (B5): a rail click while the panel is full screen leaves full screen and shows the area. The lead may flip this product call to "ignore".
- DW-1650 (B6): a turn against a provider endpoint that refuses connections fails after one attempt instead of two, so the error arrives in about half the time.
- DW-1661 (B6): a Gemini turn whose model botched a tool call says "The model could not make a valid tool call. Try again, or rephrase the request." It no longer says the model declined.
- DW-1366 (B7): a second confirm racing another on the same target answers "Another confirmation of this target is being applied. Try again in a moment." (409), not "An internal error occurred".
- DW-1641 (B7): an agent edit of one OAuth metadata member keeps the other members.
- DW-1662 (B7): a principal holding only the authorization-server tab's two pairs can create a configuration with the default roles the editor pre-ticks.
- DW-1436 (B7): a Users proposal card shows `EscalationRoles` as "2 values" rather than a mask.
- DW-1001 and DW-1013 (B7): the agent asks for an OpenAPI document or a wallet collection by one exact name on the first call. Asked about a service with no address restriction, it says any address may connect.
- DW-425 (B8): after a stale-save refusal on Agent definitions or Switches, pressing Save again is refused again until the page is reloaded, as the published sentence already promises.

### Document corrections at origin

- DW-1688 (B1):
  - DESIGN.md `:1181` "a `typed-name-field` for a destructive write" becomes "a `typed-name-field` for a destructive write taken on a screen (an agent proposal takes none)".
  - DESIGN.md `:1242` and `:1272` "only after the typed name matches" becomes "in a confirm-dialog only after the typed name matches; on a destructive proposal-card, without one".
  - EXPERIENCE.md `:197`, `:606` and `:611` each say, in place, that an agent proposal carries no typed-name field.
  - Spine AD-10 and epics.md `:454`: batch L.
- DW-1148 (B5): DESIGN.md `:904` publishes the 1,920 Home row as side bar 0 and content 912.
- DW-1376 (B1): DESIGN.md `:898`. DW-1295 (B1): EXPERIENCE.md `:382`. DW-1318 (B1): `extract-catalog.md:530`.
- DW-1436 (B7): DESIGN.md's proposal-card recipe (`:1181` list) gains "an opaque field shows its count, never the mask". EXPERIENCE.md's proposal-card Fixed strings row gains the "1 value" / "<n> values" literal in place.
- DW-1439 (B2): the anonymous-floor sentence at `docs/DEVELOPMENT.md:293-297`, `Installer.cls:2275-2282` and `WebApp.cls:263,308` changes only if the measurement differs (AD-21 in L).
- Batch L: the spine at `:72/:75`, `:204`, `:498` and `:908`; epics.md at `:409`, `:437`, `:454`, `:759`, `:1368`, `:2834` and `:5623`; `CLAUDE.md:121`; `.claude/rules/objectscript-testing.md`; `_bmad/custom/skill-rules.md` Rules 22 and 28.

### Triage

One row per slice entry. `resolved` means fixed before this story; its trailer records `resolved-by:23-1-the-range-end-cleanup` with the earlier fix as evidence (this story verified it). A `fix` row's batch is where it lands, and `L` means the lead applies it.

| DW | area | sev/fix-risk | disposition | batch or target | reason |
| --- | --- | --- | --- | --- | --- |
| DW-371 | CI / bundle pin | low/low | resolved |  | 9a91f692: angular-json.test.mjs:377 pins 1854kB; build-output.test.mjs:168 measures the bytes |
| DW-419 | checker | med/low | fix | B3 | production-install classes must also refuse on OCUPILOT_ALLOW_PRODUCTION_INSTALL; 8 classes + checker + roster |
| DW-425 | agent config | med/med | fix | B8 | merge-gate decision (client carries its RowVersion) plus the spine Conventions row require it; optional field, contained |
| DW-426 | agent config | med/med | fix | B8 | take the version at the open beside ValuesFromRow, as Switches does |
| DW-427 | agent config | med/med | fix | B8 | folds into DW-426: refuse an empty version only on the as-stored branch |
| DW-429 | agent config tests | med/med | route | burndown | coverage gap needs the StateClass seam DW-1287 names; no user-reachable fault |
| DW-430 | agent state | med/low | by-design |  | "" = no row is a pinned contract (Mint.cls:725, ProposalConfirm.cls:310); inner calls trap in Base |
| DW-439 | CI | med/low | resolved |  | 17c2d062: ci.yml reserves the throwaway ports; pinned ci.test.mjs:1543 |
| DW-456 | spine | med/med | fix | L | spine direction line is false against shipped code; the merge gate chose amending the line (Rule 20, lead) |
| DW-458 | panel layout | med/med | fix | B5 | a drag bounds against the side-bar-yielded max, applying DESIGN.md's yield order |
| DW-460 | rail | med/low | fix | B5 | a rail click in full screen exits full screen first; nothing written or navigated unseen |
| DW-1001 | read tools | med/low | fix | B7 | one server-only ReadToolNotes hook gives the single-name criteria their true description |
| DW-1013 | read tools | med/low | fix | B7 | same hook: the services read says an empty AllowedConnections means any address |
| DW-1015 | browser harness | med/low | fix | B3 | browserConfig refuses ocupilot and every ocupilot-slot-* container |
| DW-1076 | context chip | med/low | route | 16-15-the-data-egress-line | 16.15 AC2/AC3 need the same two-host fixture and a live default-move leg |
| DW-1081 | reply render | low/low | route | 14-1-the-copy-out-draft | 14.1 AC2 builds the code-surface copy control |
| DW-1082 | reply render | low/low | wontfix-accepted |  | GFM tables are renderer feature work against a bundle at 1.84 MB of 1854kB |
| DW-1097 | dispatch tests | low/med | resolved |  | 7dbacaaa: Test/ToolDispatchClientFault pins all three branches |
| DW-1104 | provider limits | med/low | fix | B1 | Limits.cls doc still says the stored values are unbounded; they are clamped (doc only) |
| DW-1105 | provider egress | low/med | fix | B6 | a stored loopback proxy now reaches PROVIDER.EGRESS through a turn; one leg + header fix |
| DW-1106 | provider stub | low/low | wontfix-accepted |  | a uniform elapsed already drives the deadline check (Base.cls:301) |
| DW-1107 | egress resolver | low/high | wontfix-accepted |  | bounding needs a JOB per lookup; costs latency on a first call, never a wrong verdict |
| DW-1114 | egress resolver | low/med | wontfix-accepted |  | needs unmeasured one-family-raises vendor behavior; window is the 5 s cache |
| DW-1119 | smoke | low/low | fix | B2 | the verdict line names the failed checks (same Render edit as DW-1402) |
| DW-1121 | registry | med/low | resolved |  | 63f19ef4: Read.cls:71 reads SecretArguments per descriptor |
| DW-1122 | ledger retention | med/low | route | 14-4-transcripts-retention-and-administrator-access | 14.4 AC2's purge task owns ledger retention |
| DW-1123 | ledger tests | med/low | resolved |  | 7dbacaaa: all six branches asserted (LedgerWire, LedgerClientRows, LedgerRouteProbe) |
| DW-1126 | ledger pairs | low/low | resolved |  | 7dbacaaa: PairsToString/RedactedKeys fixed and pinned in Test/LedgerPairs |
| DW-1128 | ledger read cost | low/low | wontfix-accepted |  | bounded by the 201-row cap; the fix replaces the idiom all eight stores inherit |
| DW-1133 | dispatch | low/low | wontfix-accepted |  | deliberate asymmetry documented at Dispatch.cls:632 |
| DW-1134 | test size | low/low | resolved |  | 7dbacaaa: Test/Ledger.cls split into three classes with their own teardown |
| DW-1135 | instance date | med/low | wontfix-accepted |  | missing capability, not a defect; Home's line names the date it counts |
| DW-1146 | audit spec | med/med | wontfix-accepted |  | seen once on a reused throwaway, never in CI; the cause is unmeasured |
| DW-1148 | Home geometry | low/low | fix | B5 | DESIGN.md:904 publishes a Home layout no user reaches; correct at origin and pin |
| DW-1150 | agent status | low/low | resolved |  | 7dbacaaa: one restraintSentence read by both surfaces, pinned |
| DW-1151 | browser helpers | low/low | resolved |  | 7dbacaaa: ui/browser/panel-spec.mjs shared helpers |
| DW-1152 | Home | low/low | wontfix-accepted |  | one wasted request with no visible effect |
| DW-1157 | Home | low/low | wontfix-accepted |  | seen once, never reproduced; no defect to fix against |
| DW-1161 | styles | med/low | resolved |  | 7dbacaaa: the four -reason blocks are one selector list |
| DW-1162 | styles | med/med | resolved |  | 7dbacaaa: computed style pinned; the general half is DW-1188 |
| DW-1165 | agent config | med/med | fix | B8 | pass ReadRequestBody's stage so a read/decode fault answers 500, as three handlers already do |
| DW-1168 | rules doc | low/low | resolved |  | 7dbacaaa: objectscript-testing.md reads dist/ocupilot-ui, pinned |
| DW-1172 | ledger | low/low | fix | B6 | the store that cuts Arguments sets ArgumentsTruncated itself |
| DW-1173 | port capture | med/low | resolved |  | 7dbacaaa: both nesting directions pinned |
| DW-1179 | spine AD-42 | med/high | fix | L | AD-42 still overclaims a dripping provider is bounded by AD-31 (Rule 20, lead) |
| DW-1185 | rules doc | med/low | escalated | owner | an instruction-file edit is the owner's to approve, never an agent's; drafted text in Batch L |
| DW-1188 | client lint | med/med | route | burndown | a new client-lint rule family with an allow-list is story-sized |
| DW-1191 | provider stub | med/med | route | burndown | fixture duplication only; consolidation re-verifies every provider suite |
| DW-1197 | test prose | med/low | fix | B1 | CatalogAnthropicStub header names anthropic as the only key (doc only) |
| DW-1201 | egress test | med/med | wontfix-accepted |  | the only vehicle is new test infrastructure; kept deferred by the merge gate |
| DW-1210 | progress poll | med/med | route | burndown | a per-poll bound is a poll-contract decision, not a contained fix |
| DW-1211 | checker | med/med | route | burndown | the new rule's count pin needs a CLAUDE.md edit in the same commit |
| DW-1215 | test ownership | low/low | wontfix-accepted |  | a parallel-run footprint artifact; the pin is legitimate where it is |
| DW-1216 | egress styles | low/med | wontfix-theoretical |  | both treatments read the shared egress tokens and cannot drift in color |
| DW-1217 | egress denylist | med/low | fix | B6 | add Alibaba Cloud's published metadata address to METADATAADDRESSES |
| DW-1219 | test prose | low/low | fix | B1 | ContextBound's mutation recipe says legs, plural, where one reddens (doc only) |
| DW-1220 | credentials | med/med | wontfix-accepted |  | nothing is written; a 422 needs a new code and published sentence |
| DW-1222 | agent state tests | low/low | fix | B6 | three comments drop the stale count; AgentState gains the HttpAcknowledged leg |
| DW-1235 | proposal index | low/low | wontfix-theoretical |  | no released build stored Proposal rows without these indexes |
| DW-1236 | registry corpus | low/low | fix | B7 | one shared corpus for the entity-label sentences, both engines iterate it |
| DW-1237 | registry | low/low | wontfix-accepted |  | requiring a noun refuses 15 shipped screens and needs 15 new strings |
| DW-1238 | conversation read | low/low | wontfix-accepted |  | bounded by expiry and turn limits; no measured cost |
| DW-1239 | proposal fixtures | low/low | wontfix-accepted |  | five scattered hygiene items with no shipped consequence |
| DW-1259 | async port | low/low | by-design |  | AD-8 (amended 2026-09-24) declares the poll pair on the tool, refused at mint |
| DW-1260 | proposal store | low/low | fix | B7 | pass the user to GuardedExpireStale at two call sites |
| DW-1261 | proposal store | low/low | wontfix-theoretical |  | a canceled sibling already fails the claim on State |
| DW-1262 | turn send | low/low | wontfix-accepted |  | closing before the spawn is the safe order; a stale card writes nothing |
| DW-1263 | confirm claim | low/low | wontfix-accepted |  | an early State refusal would lose the CONVERSATION code and ClosedDetail |
| DW-1264 | AdminPort docs | low/low | fix | B1 | AdminPort comments name TYPESUFFIXES alone and one caller (doc only) |
| DW-1265 | conversation | low/low | wontfix-accepted |  | the current order errs safe; swapping risks live proposals behind a replaced transcript |
| DW-1266 | egress state test | low/low | fix | B7 | a test mirroring SwitchState's singleton pin for Egress |
| DW-1267 | proposal fixture | low/low | fix | B7 | RemoveSeeded keeps unreached keys on error and counts turns |
| DW-1268 | uninstall | med/low | fix | B2 | the dry-run preview lists the roles the confirmed run deletes |
| DW-1272 | test prose | low/low | fix | B1 | Provenance's recipe names guard text that no longer exists (doc only) |
| DW-1277 | installer prose | med/low | fix | B1 | Installer comment cites the wrong clause of AD-21 (doc only) |
| DW-1281 | confirm lock | low/low | dropped |  | duplicate of DW-1366 |
| DW-1282 | router docs | low/low | fix | B1 | Router header is duplicated and its only-write-verbs sentence is false (doc only) |
| DW-1283 | pair check | low/med | fix | B7 | Dispatch's MissingPair and the HoldsPair bodies delegate to Operation's one copy |
| DW-1284 | registry | low/low | resolved |  | 66ee3da2: the no-op catch is gone |
| DW-1286 | agent config tests | med/low | fix | B8 | with DW-426 the test reaches the branch it names; add the distinguishing assertion |
| DW-1287 | agent config seam | med/med | route | burndown | a StateClass seam over ~25 call sites with test-only value |
| DW-1289 | password policy | med/low | route | burndown | needs an AD-39 amendment and a system-wide validation-routine fixture |
| DW-1290 | password test | med/low | route | burndown | an independent oracle needs unmeasured vendor status layout |
| DW-1294 | violation envelope | low/low | fix | B8 | RenderViolations takes the code; Account delegates instead of duplicating |
| DW-1295 | UX doc | low/low | fix | B1 | EXPERIENCE.md:382 names the reused Required string, same line (doc only) |
| DW-1296 | strings | low/low | wontfix-accepted |  | each wording is published; unifying renames shared-append keys for no user gain |
| DW-1297 | install lock | med/low | route | burndown | naming the lock holder needs unmeasured ^$LOCK extended-reference behavior |
| DW-1298 | route-order prose | low/low | fix | B1 | five places still state the superseded N-segment wording (doc/message text) |
| DW-1300 | IPM manifest | low/low | wontfix-accepted |  | the registry takes author and license from its form; exporter behavior unmeasured |
| DW-1304 | privilege sentence | med/med | fix | B8 | RenderForbidden delegates to Kernel.Denial, one sentence for one refusal |
| DW-1311 | identity read | low/low | wontfix-accepted |  | no measurement shows a cost |
| DW-1313 | fixture text | low/low | fix | B1 | two retired refusal sentences in fixtures (text only) |
| DW-1318 | PRD extract | low/low | fix | B1 | extract-catalog.md:530 still says undecided; AD-50 decided (doc only) |
| DW-1319 | spine | low/low | fix | L | the Deferred row records a mechanism Story 5.4 replaced (Rule 20, lead) |
| DW-1320 | smoke | low/low | wontfix-accepted |  | smoke already fails on the fault through CheckApiReads, without naming it |
| DW-1322 | provider gate | low/low | fix | B6 | an OR-set refusal names no single failed pair |
| DW-1323 | installer | low/low | fix | B2 | EnsureApplication's drift check also compares Type, as its identity twin does |
| DW-1325 | test prose | low/low | fix | B1 | delete the duplicated $ZHex narration paragraph (doc only) |
| DW-1332 | image script | low/low | fix | B3 | the tag guard refuses every :latest-* rolling tag |
| DW-1333 | IPM manifest | med/low | route | burndown | the exporter drops SystemRequirements; the real fix is a runtime floor in Install |
| DW-1338 | epics.md | med/low | fix (partial) | L | lead fixes :759 (Epic List); :5623 sits in Story 13.3's block, another epic's, so that residual is escalated for the orchestrator |
| DW-1340 | test arming | low/low | fix | B3 | PreferencesWire gains an arming variable so it cannot clear an operator's lists |
| DW-1341 | recents | low/low | fix | B5 | the recorder skips a navigation while signed out |
| DW-1342 | favorites | low/low | fix | B5 | toggles chain per route so a second press sends remove |
| DW-1343 | IPM archive | low/low | wontfix-accepted |  | an extra member cannot happen today; tightening needs unmeasured IPM behavior |
| DW-1344 | IPM archive | low/low | fix | B3 | the manifest floor is derived from module.xml, not the literal 11 |
| DW-1349 | prohibited set | med/low | resolved |  | e5b7e1b9: delete predicates by effect, per-arm tests |
| DW-1350 | prohibited set | low/med | by-design |  | AD-10 amended 2026-09-24 permits every change to non-OcuPilot applications |
| DW-1356 | prohibited set | med/med | by-design |  | AD-10 plus owner 2026-09-23: only OcuPilot's serving path is self-protected |
| DW-1357 | prohibited set | low/low | wontfix-accepted |  | a signature change across every gate caller for a near-unreachable refusal |
| DW-1358 | registry | low/low | dropped |  | duplicate of DW-1450 |
| DW-1360 | prohibited set | low/low | resolved |  | a1b15008: ServesOcuPilot asks once with the normalized path |
| DW-1361 | proposal mint | low/low | wontfix-theoretical |  | no caller input makes a global stream Write fail |
| DW-1365 | webapp state | low/low | wontfix-accepted |  | only install writes records, over roster literals a test pins canonical |
| DW-1366 | confirm lock | med/med | fix | B7 | owner decision: lock contention is a named retryable 409, not 500 INTERNAL |
| DW-1368 | help control | med/low | fix | B5 | a transient help-read failure is retried on the next load |
| DW-1371 | stale bundle | low/low | fix | B5 | the stale strip hides while the instance notice shows |
| DW-1372 | stale bundle | low/low | fix | B5 | the role=status region stays mounted and its text changes |
| DW-1373 | uiabout log | low/low | fix | B2 | a test drives the real LogSourceFailure seam |
| DW-1374 | installer | low/low | fix | B2 | a test reaches BundleIdentity's fallback through InstallerProbe |
| DW-1375 | Home shortcuts | low/low | wontfix-theoretical |  | gated rows stay listed, so the empty state is unreachable |
| DW-1376 | UX doc | low/low | fix | B1 | DESIGN.md:898 adds shortcuts and links to the polish-week list (doc only) |
| DW-1377 | violation codes | med/low | route | burndown | a sweep over every code family needs a resolver map; story-sized |
| DW-1383 | provider gate | low/low | fix | B6 | delete the dead GateAnyOf/EvaluateAnyOf pair; one OR-set walk remains |
| DW-1384 | panel cards | low/med | wontfix-accepted |  | rehydrating cards after reload is feature work; the audit row survives |
| DW-1385 | browser spec prose | low/low | fix | B1 | the AC2 leg's doc states its exact-count precondition (doc only) |
| DW-1386 | probe install | low/low | wontfix-theoretical |  | probe-profile installs never emit a marker |
| DW-1387 | messages-log spec | med/low | resolved |  | 9bf7c9d1 (DW-1190): window-aware reseed |
| DW-1389 | throwaway script | low/low | resolved |  | 2807b557: backticks escaped |
| DW-1391 | UiSystem | low/low | wontfix-accepted |  | the arms need a fault seam for input no caller can construct |
| DW-1392 | Home styles | low/low | fix | B5 | height becomes min-height, as DESIGN.md:912 requires |
| DW-1400 | shell read seam | med/med | route | 16-18-home-s-performance-row | 16.18 AC1 extends SystemInfo's dashboard seam; extract the base there |
| DW-1401 | chrome errors | med/med | route | burndown | role=alert, Retry and messages.log actions on two surfaces is new UI |
| DW-1402 | smoke | med/low | fix | B2 | the PASSED line names skipped checks |
| DW-1407 | toast styles | low/low | resolved |  | 6878250a (Story 15.6): --ocu-toast-link remapped for dark |
| DW-1408 | editors | low/med | wontfix-accepted |  | the gap spans six editors, two with a return path; not bounded |
| DW-1409 | change-bus tests | low/low | wontfix-accepted |  | every row is asserted; only attribution is missing |
| DW-1413 | epics.md | med/low | fix (partial) | L | lead fixes :409 and :437 (Requirements Inventory); :1368 and :2834 sit in Stories 1.9 and 4.3, other epics' blocks, so that residual is escalated |
| DW-1414 | preferences fault | med/high | route | burndown | high fix-risk: an origin tag across five call sites of one slot |
| DW-1423 | change announcement | low/low | route | 16-17-the-read-back-line | 16.17 AC1 changes the marked-row surface; strings.ts forbids rewording the key here |
| DW-1425 | task-history spec | med/low | fix | B3 | search the demo task's full name so probe residue cannot match |
| DW-1433 | ledger.sh | low/low | fix | B3 | strip one leading note= so note=human= is written once |
| DW-1434 | pipeline rule | med/low | escalated | owner | an instruction-file edit is the owner's to approve, never an agent's; drafted text in Batch L |
| DW-1435 | pipeline rule | med/low | escalated | owner | an instruction-file edit is the owner's to approve, never an agent's; drafted text in Batch L |
| DW-1436 | proposal disclosure | low/low | fix | B7 | merge-gate decided: an opaque field renders its count, not the mask |
| DW-1439 | anonymous floor | med/high | fix | B2 | one throwaway probe measures the answer; docs follow the measurement |
| DW-1440 | split-db role | med/med | route | burndown | two grants across install, assert and uninstall; needs a split-database namespace |
| DW-1449 | auditing banner | med/med | route | burndown | a manual re-enable needs a privileged producer within AD-8/AD-9 |
| DW-1450 | secret arguments | med/med | route | burndown | a PermittedFields-aware settable set in both engines is not a bounded batch |
| DW-1451 | checker | med/med | route | burndown | needs a confirm-following call-graph checker |
| DW-1460 | NFR-1 | low/med | wontfix-accepted |  | a measurement question on a large task population; no code at fault |
| DW-1462 | navigate tool | med/med | route | burndown | the ruled parentId convention spans the tool, Directive and client navigator |
| DW-1465 | proposal card | med/med | route | burndown | needs a server-recorded display name for integer-keyed targets |
| DW-1466 | AD-43 roster | low/low | by-design |  | AD-43 counts screens; the free-space view is the Databases screen's second view |
| DW-1468 | wire test | med/low | fix | B3 | scope the same-rows leg to the demo task's own history |
| DW-1471 | browser leg | low/low | fix | B4 | a Process details pause leg beside the list's |
| DW-1478 | CLAUDE.md | med/low | escalated | owner | an instruction-file edit is the owner's to approve, never an agent's; drafted text in Batch L |
| DW-1485 | closed spec | low/low | wontfix-accepted |  | recipes were correct when measured; rewriting a done spec adds surface |
| DW-1497 | screen action lock | med/med | route | burndown | lock scope across both callers' port write is an AD-34/AD-53 design change |
| DW-1555 | wallet secrets | med/med | route | burndown | RSA and symmetric-key secrets are a feature no 14/16 story owns |
| DW-1562 | devices | med/med | route | burndown | a Devices-list Delete row action is a feature no 16.x story owns |
| DW-1574 | portability | low/med | wontfix-accepted |  | making 8 fixture classes portable is not bounded; nothing shipped is affected |
| DW-1583 | structural gate | low/low | fix | B4 | a declared 4px allowance for the designed resize-handle overlap; drop its baseline keys |
| DW-1584 | structural gate | med/low | fix | B4 | the status bar's right group stops shrinking; drop its baseline keys |
| DW-1587 | structural gate | med/low | fix | B4 | one shared 24px rule for checkbox and radio inputs; drop its baseline keys |
| DW-1588 | structural gate | med/low | fix | B4 | the walk visits inline svg roots too |
| DW-1599 | test prose | low/low | fix | B1 | AgentViolation's assertion message and narration comment (text only) |
| DW-1637 | ledger | med/med | fix | B7 | a still-running queued write's ledger row carries PORT.STARTED |
| DW-1641 | OAuth tools | med/med | fix | B7 | the agent's metadata update merges member by member, as the screen does |
| DW-1645 | audit mask | med/high | route | burndown | AD-35 names the gap for a post-release message-dictionary match |
| DW-1650 | provider retry | med/med | fix | B6 + L | decided at the 10.6 merge gate: a connect that never opened (#6059) is not retried; ~10 lines + a test; AD-42 and its Deferred row amended in L |
| DW-1661 | Gemini adapter | med/low | fix | B6 | tool-call finish reasons get their own code and sentence, not DECLINED |
| DW-1662 | OAuth server | med/low | fix | B7 | a create admits the default roles the editor pre-ticks |
| DW-1663 | prohibited set | med/high | route | burndown | flag a role by its privileges, not its name; high fix-risk |
| DW-1669 | proposal card | med/med | route | burndown | a slow re-read of live proposals after the turn ends is post-release |
| DW-1681 | demo fixture | low/low | fix | B2 | owner must-fix: seed the demo error only when none is present |
| DW-1682 | code comments | low/low | fix | B1 | owner must-fix: seven comments point at README sections now in docs/DEVELOPMENT.md |
| DW-1688 | proposal card | low/low | fix | B1 | owner must-fix: the destructive comments name the scratched Story 14.7 |

### Ledger trailers (lead applies at spec validation)

The 96 non-fix entries, one `append` each, run from the worktree root. A `fix` entry keeps its current trailer until its batch commits. The lead then appends `status=resolved-by:23-1-the-range-end-cleanup by=<gate> note=commit <sha>`; for DW-1323 or DW-1588, when this spec's fallback applies, the lead appends that fallback's disposition instead.

```bash
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-371 "status=resolved-by:23-1-the-range-end-cleanup owner=23-1-the-range-end-cleanup by=spec_gate note=fixed before 23.1: 9a91f692 angular-json.test.mjs pins 1854kB; build-output.test.mjs measures the bytes"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-429 "status=routed owner=burndown by=spec_gate note=coverage gap needing a StateClass() seam in Api/Definitions (precedent Kernel/Identity.cls:51); no user-reachable fault"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-430 "status=by-design owner=23-1-the-range-end-cleanup by=spec_gate note=Agent GuardedVersion \"\" = no row is a contract Mint.cls:725 and ProposalConfirm.cls:310 pin; inner calls trap in Base"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-439 "status=resolved-by:23-1-the-range-end-cleanup owner=23-1-the-range-end-cleanup by=spec_gate note=fixed before 23.1: 17c2d062 ci.yml reserves the throwaway ports; pinned in ci.test.mjs"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1076 "status=routed owner=16-15-the-data-egress-line by=spec_gate note=16.15 AC2/AC3 need a two-host fixture and a live default-marker-move leg; chip pinned store-level only"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1081 "status=routed owner=14-1-the-copy-out-draft by=spec_gate note=14.1 AC2 builds a copy control on the code surface; build it once for reply code blocks too"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1082 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=a demo-path reply contains a pipe table shown as raw pipes, or an AC asks for tabular replies"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1097 "status=resolved-by:23-1-the-range-end-cleanup owner=23-1-the-range-end-cleanup by=spec_gate note=fixed before 23.1: 7dbacaaa Test/ToolDispatchClientFault pins Dispatch's three branches"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1106 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=a test must script attempts of different lengths; uniform elapsed already drives Base.cls:301"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1107 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=a first provider call is measured blocked on a hanging resolver beyond a turn-visible delay"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1114 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=a probe shows HostNameToAddrMulti raising for one family while the other answers"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1121 "status=resolved-by:23-1-the-range-end-cleanup owner=23-1-the-range-end-cleanup by=spec_gate note=fixed before 23.1: 63f19ef4 Screen/Tool/Read.cls reads SecretArguments per descriptor"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1122 "status=routed owner=14-4-transcripts-retention-and-administrator-access by=spec_gate note=14.4 AC2's retention purge task; the spine's Retention row puts the agent ledger in that purge"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1123 "status=resolved-by:23-1-the-range-end-cleanup owner=23-1-the-range-end-cleanup by=spec_gate note=fixed before 23.1: 7dbacaaa LedgerWire, LedgerClientRows and LedgerRouteProbe assert all six branches"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1126 "status=resolved-by:23-1-the-range-end-cleanup owner=23-1-the-range-end-cleanup by=spec_gate note=fixed before 23.1: 7dbacaaa Audit/Ledger.cls PairsToString and RedactedKeys; pinned in Test/LedgerPairs"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1128 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=a ledger read at LEDGERVIEWMAXROWS is measured over NFR-1's 2 s"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1133 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=a story gives the progress card a rule for model-authored arguments of an unknown tool"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1134 "status=resolved-by:23-1-the-range-end-cleanup owner=23-1-the-range-end-cleanup by=spec_gate note=fixed before 23.1: 7dbacaaa split Test/Ledger.cls into Ledger, LedgerPairs and LedgerRedaction"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1135 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=a story AC needs a count or filter for the instance's own \"today\" (e.g. an errors-today line)"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1146 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=a CI browser job fails audit.browser-spec with \"must hold at least 1000 OcuPilotSeed rows\""
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1150 "status=resolved-by:23-1-the-range-end-cleanup owner=23-1-the-range-end-cleanup by=spec_gate note=fixed before 23.1: 7dbacaaa one restraintSentence (agent-status.ts) read by suggested-view and panel"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1151 "status=resolved-by:23-1-the-range-end-cleanup owner=23-1-the-range-end-cleanup by=spec_gate note=fixed before 23.1: 7dbacaaa ui/browser/panel-spec.mjs shared helpers; suggested-view imports them"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1152 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=a browser spec's request log shows the Home read issued after the route left Home"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1157 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=panel.browser-spec.mjs's fresh-sign-in geometry assertion fails again"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1161 "status=resolved-by:23-1-the-range-end-cleanup owner=23-1-the-range-end-cleanup by=spec_gate note=fixed before 23.1: 7dbacaaa merged the four -reason blocks into one selector list in _components.scss"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1162 "status=resolved-by:23-1-the-range-end-cleanup owner=23-1-the-range-end-cleanup by=spec_gate note=fixed before 23.1: 7dbacaaa panel-principal spec pins .ocu-panel-empty computed style; rest is DW-1188"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1168 "status=resolved-by:23-1-the-range-end-cleanup owner=23-1-the-range-end-cleanup by=spec_gate note=fixed before 23.1: 7dbacaaa objectscript-testing.md reads dist/ocupilot-ui, pinned by angular-json.test"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1173 "status=resolved-by:23-1-the-range-end-cleanup owner=23-1-the-range-end-cleanup by=spec_gate note=fixed before 23.1: 7dbacaaa PortCapture.cls and MgmntPort.cls pin both nesting directions"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1188 "status=routed owner=burndown by=spec_gate note=new client-lint family (template ocu- classes vs stylesheets) with an allow-list; story-sized"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1191 "status=routed owner=burndown by=spec_gate note=fixture duplication (ProviderStub.IssueHttpsPost vs ProviderStubTransport.Transport); AD-35 half closed"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1201 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=a no-egress listener is admitted in the throwaway (JOBbed |TCP| responder) so the mutation can redden"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1210 "status=routed owner=burndown by=spec_gate note=per-poll bound on Step.GuardedRows needs a poll-contract call (tool-card text vs incremental poll)"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1211 "status=routed owner=burndown by=spec_gate note=rule designed (check_claim_gate_containment); its count pin needs a CLAUDE.md edit in the same commit"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1215 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=a later parallel story whose footprint excludes Test/AgentWire.cls must add a Definitions.Fields() key"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1216 "status=wontfix-theoretical owner=23-1-the-range-end-cleanup by=spec_gate note=real only if an egress rule hard-codes a color instead of the --ocu-egress-warning* tokens both read today"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1220 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=a credential POST on a credType-none definition answers 2xx or creates an Ens.Config.Credentials entry"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1235 "status=wontfix-theoretical owner=23-1-the-range-end-cleanup by=spec_gate note=real if a post-1.0.0 release adds an index to a table holding rows; the installer runs no %BuildIndices"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1237 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=a card title shows the doubled space visibly, or the owner asks for nouns on the 15 screens"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1238 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=GET /conversation/:id is measured slow, or one conversation holds more than ~50 proposal rows"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1239 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=proposal-card spec flakes on test order, or a target-size audit flags .ocu-proposal-card-disclosure"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1259 "status=by-design owner=23-1-the-range-end-cleanup by=spec_gate note=AD-8 (amended 2026-09-24): a queued write's poll pair is declared on the tool and refused at mint"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1261 "status=wontfix-theoretical owner=23-1-the-range-end-cleanup by=spec_gate note=real if any writer does a GuardedSaveIfCurrent read-modify-write on a Propose row after mint"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1262 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=TURN.UNAVAILABLE (\"the turn job could not be started\") appears in the fault log in normal use"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1263 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=a gate ahead of the claim gains a side effect, or a closed-row confirm is measured slow"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1265 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=POST /conversation answers 500 from LoadOrCreate outside a fault injection"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1281 "status=dropped owner=23-1-the-range-end-cleanup by=spec_gate note=duplicate of DW-1366 (same Propose lock-timeout to 500 INTERNAL path), fixed there"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1284 "status=resolved-by:23-1-the-range-end-cleanup owner=23-1-the-range-end-cleanup by=spec_gate note=fixed before 23.1: 66ee3da2 removed the no-op catch in Registry.DeclaredReadFields"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1287 "status=routed owner=burndown by=spec_gate note=one StateClass() seam in Api/Definitions (precedent Kernel/Identity.cls:51) unblocks DW-429; test-only value"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1289 "status=routed owner=burndown by=spec_gate note=needs an AD-39 amendment on how a PasswordValidationRoutine's text reaches the caller, plus a system-wide fixture"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1290 "status=routed owner=burndown by=spec_gate note=needs a code-keyed oracle (DecomposeStatus layout unmeasured on 2026.2); pairs with DW-1289"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1296 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=an a11y audit flags a reveal toggle's accessible name, or a fourth masked field adds a key pattern"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1297 "status=routed owner=burndown by=spec_gate note=timeout message should name the ^\$LOCK holder (measure the extended-reference form first); CI unaffected"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1300 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=the registry listing or a release asks for Author/License in module.xml; measure the exporter first"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1311 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=a timed /instance call shows OnPreDispatch's identity read costing over 50 ms per request"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1320 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=smoke.sh passes on a throwaway whose OcuPilotIdentity application was deleted after install"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1333 "status=routed owner=burndown by=spec_gate note=IPM drops SystemRequirements; fix is Installer.Install refusing below the roster's IRIS version floor"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1343 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=an archive carries a member under the bundle prefix that was not staged"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1349 "status=resolved-by:23-1-the-range-end-cleanup owner=23-1-the-range-end-cleanup by=spec_gate note=fixed before 23.1: e5b7e1b9 Prohibited RemovesOf judges deletes by effect; per-arm tests per AD-10"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1350 "status=by-design owner=23-1-the-range-end-cleanup by=spec_gate note=AD-10 amended 2026-09-24 (developer tool first): own apps refuse every write; other apps are permitted"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1356 "status=by-design owner=23-1-the-range-end-cleanup by=spec_gate note=AD-10 and owner 2026-09-23 (developer tool first): only OcuPilot's own serving path is self-protected"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1357 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=a PROHIBITED.UNCOVEREDFIELD refusal is recorded for a request the product's own client produced"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1358 "status=dropped owner=23-1-the-range-end-cleanup by=spec_gate note=duplicate of DW-1450 (settable projection lacks PermittedFields); closes with it"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1360 "status=resolved-by:23-1-the-range-end-cleanup owner=23-1-the-range-end-cleanup by=spec_gate note=fixed before 23.1: a1b15008 Prohibited.ServesOcuPilot asks Recorded once with the normalized path"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1361 "status=wontfix-theoretical owner=23-1-the-range-end-cleanup by=spec_gate note=real if a caller-supplied input can make a global stream Write fail (e.g. the protected database full)"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1365 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=anything but install writes a WebApp record, or a recorded path differs from its normalized form"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1375 "status=wontfix-theoretical owner=23-1-the-range-end-cleanup by=spec_gate note=real only if a build ships with no built SHORTCUT_ROUTES screen; gated rows stay listed on Home"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1377 "status=routed owner=burndown by=spec_gate note=a field-code to sentence sweep over every family needs a per-family resolver map; HELP.ROUTE pinned meanwhile"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1384 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=a story AC requires a confirmed write's card or not-marked line to be visible after a reload"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1386 "status=wontfix-theoretical owner=23-1-the-range-end-cleanup by=spec_gate note=real only if a probe-profile install is expected to mark a confirmed write"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1387 "status=resolved-by:23-1-the-range-end-cleanup owner=23-1-the-range-end-cleanup by=spec_gate note=fixed before 23.1: 9bf7c9d1 (DW-1190) messages-log spec re-seeds inside the tail window"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1389 "status=resolved-by:23-1-the-range-end-cleanup owner=23-1-the-range-end-cleanup by=spec_gate note=fixed before 23.1: 2807b557 escaped the heredoc backticks in ci-throwaway.sh"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1391 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=UiSystem.Payload gains a path that can return an error status or throw on a real input"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1400 "status=routed owner=16-18-home-s-performance-row by=spec_gate note=16.18 AC1 extends SystemInfo's dashboard read seam; extract the shared base before a fourth reader"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1401 "status=routed owner=burndown by=spec_gate note=About and Home system-information errors need role=alert, Retry, messages.log and a kind-aware failed()"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1407 "status=resolved-by:23-1-the-range-end-cleanup owner=23-1-the-range-end-cleanup by=spec_gate note=fixed before 23.1: 6878250a (Story 15.6) _theme.scss remaps --ocu-toast-link for dark mode"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1408 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=Save on an editor whose record an agent delete removed recreates it or errors"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1409 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=one of the four change-bus matrix rows changes without any test reddening"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1414 "status=routed owner=burndown by=spec_gate note=high fix-risk: an origin-tagged fault across 5 call sites of AccountPreferences' one slot"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1423 "status=routed owner=16-17-the-read-back-line by=spec_gate note=16.17 AC1 marks the changed row; its polite announcement should name the action (strings.ts is append-only)"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1440 "status=routed owner=burndown by=spec_gate note=reproduce where Globals and Routines databases differ; grant both resources and amend AD-21's wording"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1449 "status=routed owner=burndown by=spec_gate note=needs a privileged producer for a manual re-enable within AD-8/AD-9; the next agent marker clears it"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1450 "status=routed owner=burndown by=spec_gate note=needs a PermittedFields-aware settable set in Registry and screen-mirror; reachable only by a descriptor author"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1451 "status=routed owner=burndown by=spec_gate note=needs a confirm-following (call-graph) checker; the limit is stated at check-objectscript.py:1287"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1460 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=the Task schedule read with >=200 scheduled tasks exceeds NFR-1's 2 s"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1462 "status=routed owner=burndown by=spec_gate note=ruled convention needs a parentId parameter across Navigate.cls, the Directive and the client navigator"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1465 "status=routed owner=burndown by=spec_gate note=needs a server-recorded display name for integer-keyed targets (task, process) on the card"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1466 "status=by-design owner=23-1-the-range-end-cleanup by=spec_gate note=AD-43's roster counts screens; Databases' free-space view is that screen's second view"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1485 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=a runner re-runs a spec-5-12 mutation recipe and records its denominator mismatch as a failure"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1497 "status=routed owner=burndown by=spec_gate note=a per-target lock must cover both callers' port write, not only the claim: an AD-34/AD-53 design change"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1555 "status=routed owner=burndown by=spec_gate note=feature: RSA and symmetric-key wallet secret create/edit; no 14/16 story owns wallet secrets"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1562 "status=routed owner=burndown by=spec_gate note=feature: AD-53 delete row action on DeviceList (rowActions [] today); Epic 7's dialog now exists"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1574 "status=wontfix-accepted owner=23-1-the-range-end-cleanup by=spec_gate note=reopen_if=a plain-Community ObjectScript suite job is added to CI, or a user reports a failure there"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1645 "status=routed owner=burndown by=spec_gate note=AD-35 names the gap; post-release match on message-dictionary keys; untestable without a localized instance"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1663 "status=routed owner=burndown by=spec_gate note=flag a customization role by its privileges (a role read), not its name; high fix-risk, post-release"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1669 "status=routed owner=burndown by=spec_gate note=re-read live proposals slowly after the turn ends so a revoked privilege shows; Confirm refuses today"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1185 "status=escalated owner=burndown by=spec_gate note=owner to approve the drafted .claude/rules/objectscript-testing.md text in spec-23-1 Batch L; agents do not edit it"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1434 "status=escalated owner=burndown by=spec_gate note=owner to approve the drafted _bmad/custom/skill-rules.md Rule 28 text in spec-23-1 Batch L; agents do not edit it"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1435 "status=escalated owner=burndown by=spec_gate note=owner to approve the drafted _bmad/custom/skill-rules.md Rule 22 text in spec-23-1 Batch L; agents do not edit it"
bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md append DW-1478 "status=escalated owner=burndown by=spec_gate note=owner to approve the drafted CLAUDE.md:121 text in spec-23-1 Batch L; agents do not edit it"
```

## Verification

Slot B. Every IRIS MCP call carries `server: "ocupilot-slot-b"`. Tests and probes run on the throwaway `ocupilot-b-ci` (52777/1976), one ObjectScript class per call, and each run is awaited in `%UnitTest_Result` before the next. Never run two test calls in one message.

```yaml
  - name: b
    mcp_profile: ocupilot-slot-b          # ../OcuPilot-slot-b/compose.yml, owner-managed
    dev_container: ocupilot-slot-b
    dev_web_port: 52775
    dev_super_port: 1974
    throwaway:
      dir: /tmp/ocupilot-b-ci
      project: ocupilot-b-ci
      container: ocupilot-b-ci
      web: 52777
      super: 1976
      browser_origin: http://localhost:52777
      browser_container: ocupilot-b-ci      # OCUPILOT_BROWSER_CONTAINER -- without it a slot B browser run execs into slot A's throwaway (2026-09-16)
```

**Shared loop steps (every batch that touches the named kind of file):**

- ObjectScript source to the throwaway (loop): `rsync -a --delete src/ /tmp/ocupilot-b-ci/src/`, then `Do $System.OBJ.LoadDir("/opt/ocupilot/src","ck-d",.tErr,1)` inside `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`. Expected: 0 errors. Recompile the whole affected package before reading any mutation's result.
- `uv run scripts/check-objectscript.py <changed .cls and .py>` (loop). Expected: clean.
- One class run (loop): `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.<C>`. Expected: 0 failures, confirmed against `%UnitTest_Result`.
- Client bundle redeploy (loop, before any browser spec): `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`. Expected: the build is green and records the initial total, under 1854kB.
- One browser spec (loop): `cd ui && OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/<name>.browser-spec.mjs`. Expected: every leg passes.
- Docs (loop, when a Markdown file changed): `bash scripts/lint-docs.sh`, plus `wc -l` on EXPERIENCE.md before and after. Expected: clean, and the same line count.

### Batch B1

- Load and compile the touched classes (loop). They are `Router`, `Readiness`, `AdminPort`, `Installer`, `Limits` and `AuditingUpdate`, plus the test classes `ProhibitedRoute`, `Wire`, `CatalogAnthropicStub`, `ContextBound`, `AgentViolation`, `LedgerEmptyPairs`, `TurnSecretResidue`, `Provenance` and `ErrorReadStub`. Expected: 0 compile errors.
- `uv run scripts/check-objectscript.py` and `uv run scripts/test_check_objectscript.py` (loop). Expected: clean. The DW-1298 message text keeps "shorter route" and the Url.
- `cd ui && npm run test:tools && npm run test:components` (loop). Expected: green. This covers EXPERIENCE.md's citations and strings pins, plus the proposal-card and openapi-viewer specs.
- `bash scripts/lint-docs.sh`, and EXPERIENCE.md's `wc -l` is unchanged (loop).
- `git grep -n "14\.7" -- ui/src ui/browser src scripts` and `git grep -nE "README(\.md)?('s| too| section)" -- scripts src ui/src ui/browser` (loop). Expected: neither prints a stale pointer. `docs/DEVELOPMENT.md` itself is not searched.
- Rule 19: all 17 items are doc, comment, message or fixture text. There is no pinning test and no `mutation:` line.

### Batch B2

- Classes (loop, one per call): `DemoErrorSeed` (new), `Demo`, `ErrorLog`, `ErrorLogWire`, `Smoke`, `Provenance`, `IdentityInstall`, `BundleIdentity` (new), `UiAboutRead` and `WebApp`.
- `cd ui && npm run test:tools` (loop), for the `ci.test.mjs` arming rosters. Expected: green.
- `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` (loop). Expected: PASSED. When a check is skipped, the verdict line names it, and the counts line is unchanged.
- Measure and record: DW-1439's anonymous readiness status and body after the role delete, and whether `Security.Applications.Modify` accepts a Type drift (DW-1323).
- Mutations:
  - DW-1681: the find step always answers not-found, and then always answers found → `DemoErrorSeed`, each leg red in turn.
  - DW-1119 and DW-1402: restore "; the first is named above", then drop the skipped suffix → `Test.Smoke` red.
  - DW-1268: restore the `'$Data(tRecorded(tUName))` filter → the new `Provenance` method red.
  - DW-1323: delete the Type comparison → the new `IdentityInstall` method red.
  - DW-1374: initialize to `""` instead of `..#BUILDIDENTITY` → `BundleIdentity` red.
  - DW-1373: empty `About.LogSourceFailure`'s Try body → the new `UiAboutRead` method red.
  - DW-1439: flip the asserted status → `WebApp` red, which shows the leg reads the live answer.

### Batch B3

- `uv run scripts/check-objectscript.py` over the whole tree, then `uv run scripts/test_check_objectscript.py` (loop). Expected: clean and green.
- Classes (loop, one per call): `AuditEvent`, `AuditMarker`, `ConfigGate`, `State`, `Token`, `UnexpireScope`, `Version`, `Wire` and `WireSecurityRead`. Expected: 0 failures. Then `PreferencesWire`, which is expected to refuse with its arming message on this pre-existing throwaway; CI runs it armed.
- `cd ui && npm run test:tools` (loop). This covers `ci.test.mjs`, `browser-config.test.mjs`, `shell-scripts.test.mjs` and `ipm-archive.test.mjs`. Expected: green.
- Browser (loop): `browser/tasks.browser-spec.mjs`.
- Mutations:
  - DW-419: drop the production-install clause → the `test_check_objectscript.py` fixture red.
  - DW-1340: drop `ARMINGVARIABLE` → the `ci.test.mjs` roster equality red.
  - DW-1015: drop the slot branch → `browser-config.test.mjs` red.
  - DW-1425: revert the search term to `'OcuPilotDemo'` → AC1 red where probe residue exists. Record whether `ocupilot-b-ci` holds 40 or more `OcuPilotDemoProbe` history rows.
  - DW-1468: remove the search suffix → "nothing is cut at 1,000" red where history exceeds 1000 rows. Record the row count.
  - DW-1433: remove the strip → `shell-scripts.test.mjs` red.
  - DW-1332: revert the case arm → the `:latest-em` case red.
  - DW-1344: restore the literal `-lt 11` → the `ipm-archive.test.mjs` fixture red.

### Batch B4

- Redeploy the bundle, then run `browser/a11y-structural-invariants.browser-spec.mjs` and `browser/process-control.browser-spec.mjs` (loop). Expected: no fresh structural key and every leg passes.
- `cd ui && npm run test:tools` (loop). This covers `structural-baseline.test.mjs` and the bundle pin. Expected: green, with no DW-1583, DW-1584 or DW-1587 key left.
- Mutations (rebuild and redeploy each):
  - DW-1583: remove the allowance → fresh resize-handle keys.
  - DW-1584: delete the `flex-shrink: 0` rule → fresh status-bar keys at 720.
  - DW-1587: delete the checkbox rule → fresh min-width input keys.
  - DW-1588: Story 15.7's rail-tile svg `width: 40px` → a fresh svg key, where today it stays green.
  - DW-1471: skip the proposal pause for a screen with a `parentScope` in `ui/src/app/core/refresh.ts` → the new Process details leg red, while the list leg stays green.

### Batch B5

- `cd ui && npm run test:tools && npm run test:components` (loop). This covers `panel-layout`, `about` and `design-tokens`, plus the `rail`, `recents-recorder`, `locator-bar`, `app` and `stale-bundle-notice` specs. Expected: green.
- Redeploy the bundle, then run `browser/panel.browser-spec.mjs`, `browser/rail.browser-spec.mjs`, `browser/about-help-links.browser-spec.mjs` and `browser/home-system-information.browser-spec.mjs` (loop). Expected: every leg passes.
- Record the initial bundle total.
- Mutations:
  - DW-458: bound with `layout.panelMax` again → the `panel-layout.test.mjs` drag case red.
  - DW-460: remove the full-screen branch → the `rail.spec.ts` no-write assertion red.
  - DW-1148: make `areaHasSideBar` answer true for Home → the 1,920 row red.
  - DW-1341: drop the session gate → the signed-out case red.
  - DW-1342: call the body without chaining → the add-then-remove case red.
  - DW-1368: drop `asked.delete(route)` → the retry case red.
  - DW-1371: remove the wrapping `@if` → the `app.spec.ts` case red.
  - DW-1372: move the status element back inside `@if (stale)` → the same-node assertion red.
  - DW-1392: restore `height:` → `design-tokens.test.mjs` red.

### Batch B6

- Classes (loop, one per call): `TurnProviderFault`, `Egress`, `AgentState`, `AgentSchema`, `Adapter`, `TurnStream`, `LedgerWire`, `ProviderPortOwner`, `PortGate` and `Envelope`.
- Mutations:
  - DW-1105: delete the proxy refusal at `ProviderPort.cls:302-305` → the new `TurnProviderFault` leg red.
  - DW-1217: remove `100.100.100.200` → the `Egress` leg red.
  - DW-1222: remove `HttpAcknowledged` from `SecurityFields` → the new `AgentState` leg red.
  - DW-1661: map `MALFORMED_FUNCTION_CALL` back to refusal → `Adapter` red. Separately, delete the `Loop` branch → the `TurnStream` leg red.
  - DW-1172: revert `:252` to `''pArgumentsTruncated` → the new `LedgerWire` method red.
  - DW-1322: restore the first-pair assignment → `ProviderPortOwner` red.
  - DW-1383: no mutation, since it removes dead code; a clean package compile is the proof.
  - DW-1650: let `#6059` through to the retry again → the new connect-refused leg red (two attempts).

### Batch B7

- Classes (loop, one per call): `ProposalSpelling`, `ProposalRace`, `ProposalConfirm`, `ToolDispatch`, `DenialParity`, `ProviderProxy`, `ConfirmRoute`, `AuditStarted`, `Envelope`, `OAuthServerUpdate`, `OAuthClientUpdate`, `OAuthAuthorizationServerWire` (armed), `ProposalWire`, `ReadTool`, `Descriptor`, `EntityLabelCorpus`, `SurfaceCoverage` and `ToolRoundTrip`.
- `cd ui && npm run test:tools && node tools/screen-mirror.mjs --check && node tools/field-lists.mjs --check` (loop). Expected: green, with no drift.
- Mutations:
  - DW-1366: drop the `IsTargetBusy` branch in `Confirm.Transition` → `ProposalSpelling` red (500 INTERNAL).
  - DW-1260: call `GuardedExpireStale()` with no argument in `GuardedClose` → the new `ProposalRace` method red.
  - DW-1283: make `Operation.MissingPair` answer `""` → the `ToolDispatch` denied-pair test and the `ProposalConfirm` privilege test red.
  - DW-1266: delete `Index EgressSingletonIdx` and recompile the package → `ProviderProxy` red.
  - DW-1641: delete each `MergeUpdate` override → `OAuthServerUpdate` and `OAuthClientUpdate` red.
  - DW-1662: revert to `StoredRoles(pFresh)` → `OAuthAuthorizationServerWire` red.
  - DW-1436: send opaque paths back to `Mask()` → `ProposalWire` red.
  - DW-1637: pass `""` at `:418` → `AuditStarted` red.
  - DW-1001: return `{}` from `OpenApiViewer.ReadToolNotes` → `ReadTool` red.
  - DW-1013: remove the `ServiceList` override → `ReadTool` red.
  - DW-1236: reword `screen-mirror.mjs:516` only → `screen-mirror.test.mjs` red. Reword `Registry.cls:365` only → `Descriptor` red.
  - DW-1267: none (a fixture, pinned by its callers' teardown).

### Batch B8

- Classes (loop, one per call): `AgentConnection`, `DefinitionsFaults`, `SwitchesWire`, `AgentWire`, `AgentWireSecurity`, `AccountPasswordWire` and `SwitchState`.
- `cd ui && npm run test:components && npm run test:tools` (loop), for the `switches.page.spec.ts` and `definition-form.page.spec.ts` bodies. Expected: green.
- Redeploy the bundle, then run `browser/definitions.browser-spec.mjs` (loop). Expected: every leg passes.
- Mutations:
  - DW-426: have `ConnectionOutcome` re-read the version itself → the new `AgentConnection` method red.
  - DW-427: restore the unconditional empty-version refusal → the not-as-stored `DefinitionsFaults` leg red.
  - DW-1286: swallow the `tWriteSC` failure at `Definitions.cls:930` → the strengthened `AgentConnection` test red.
  - DW-1165: drop `.tStage` at the `HandleCreate` call → `DefinitionsFaults` red.
  - DW-1304: restore the literal sentence → the `AgentWireSecurity` reason assertion red.
  - DW-1294: drop the `pCode` argument in Account's delegation → `AccountPasswordWire` red.
  - DW-425: have the handler ignore the body's `rowVersion` → the second-PUT 409 legs in `SwitchesWire` and `AgentWire` red.

### Once for the whole story

- The full ObjectScript sweep on `ocupilot-b-ci`, one class per call, with totals checked against `%UnitTest_Result` (once, before the final batch's dev_complete). Expected: 0 failed and a non-zero count. The one expected refusal is `PreferencesWire`, unless the lead has re-provisioned the throwaway since B3.
- `cd ui && npm run build && npm test`, then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` (once, before the final batch's dev_complete). Expected: green, with the bundle total recorded under 1854kB.
- The full browser suite runs in CI, not locally (Rule 29, owner instruction 2026-09-22). CI resolves green on each batch's head before the next batch starts (AC3).
- The ledger check once all batches and L have landed: `bash _bmad/scripts/ledger.sh _bmad-output/implementation-artifacts/deferred-work.md slice range-end-cleanup`. Expected: empty.

## Auto Run Result

Status: done
Blocking condition: none

**This pass: Batch B1 only** (baseline `f30207594e8641fc86ccaa1db9ebcceee2ba9484`). All 17 B1 items landed as comment, doc, assertion-message and fixture text, with no behavior change:

- README pointers now name `docs/DEVELOPMENT.md` sections in the seven files.
- The destructive-proposal contract ("no typed-name field") is stated in `proposal-card.ts`, its spec, `_components.scss` (same line count), `AuditingUpdate.cls`, `auditing-write.browser-spec.mjs`, DESIGN.md `:1181/:1242/:1272` and EXPERIENCE.md `:192/:197/:606/:611/:660/:743`.
- Other text fixes: `Limits.cls`, `CatalogAnthropicStub`, `ContextBound`, `AgentViolation`, `LedgerEmptyPairs`, `TurnSecretResidue`, `AdminPort`, `Provenance`, `Installer`, the `Router` header and ordering wording, `check-objectscript.py`, `RouterFixture`, `ErrorReadStub`, `openapi-viewer.page.spec.ts`, `audit.browser-spec.mjs`, DESIGN.md `:898`, EXPERIENCE.md `:382` and `extract-catalog.md:530`.

**Review:** 12 findings. 9 patched (4 medium, 5 low), 1 deferred (low), 2 rejected. The triage log gives each one. The follow-up review recommendation is `false`: the two medium entries patched are prose, and each was checked against the code. The AdminPort paragraph was checked against all 24 direct port callers in `Area/`, and each Save handler references `Prohibited`.

**Verification** (on `ocupilot-b-ci`, after the patches):

- `LoadDir` of `src/` compiled with 0 errors.
- `check-objectscript.py` found 0 problems in 956 files, and `test_check_objectscript.py` passed 130 tests.
- `npm run test:tools` passed 1468/1468, and `npm run test:components` passed 1451/1451.
- `lint-docs.sh` reported 0 issues. EXPERIENCE.md is 981 lines before and after.
- The `14\.7` grep is empty. The README grep prints only `core/session.ts:59`, which is correct because README.md `:265` carries the unexpire command.
- The added source contains no non-ASCII characters.
- The handoff agent ran `OcuPilot.Test.ToolEmit` once: 11 tests, 0 failed.
- The Matrix Test Audit does not apply, since no matrix row concerns B1.
- Rule 19 does not apply, since B1 has no behavior.

**Residual risk:** none beyond the two low items in `deferred:`.
