---
title: 'Story 16.26: Epic 16 burn-down'
type: 'bugfix'
created: '2026-10-01'
status: 'done'
review_loop_iteration: 0
baseline_revision: '5a2b16ad45a5eb032507d01bb269863603fb8d57'
baseline_commit: '5a2b16ad45a5eb032507d01bb269863603fb8d57'
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['multiple-goals', 'oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Two tests flake in CI. `WireSecurityRead.TestTheLogsAreaStaysOpenWithoutTheEventLogsPair` asserts 200 on the alerts.log tail, which a fresh instance answers 404 `LOG.ABSENT` until something posts a severe line (DW-1851). In `language-server-editor.browser-spec.mjs` AC3, the fixture's vendor start of the seeded Java probe was answered 500 on a fresh CI throwaway (DW-1867).

**Approach:** DW-1851: the product is right (AD-21), so the test accepts the named absence past the gate, as `LogSource` and `LogSourceDenial` already do. DW-1867: every language server test that starts a probe listens on a port below the container's ephemeral range, and pins that. The editor spec's fixture start reports the vendor's own reason when it is refused. Each fix is shown by a run that reproduces the old failure, then passes.

## Boundaries & Constraints

**Always:**

- **Fix in the tests.** No product code changes. The Logs area, `LogSourcePort` and the language server editor are correct as shipped (Design Notes).
- **Each test depends only on the freshly installed instance** (Conventions › Tests). DW-1851's test passes whether or not `alerts.log` exists. DW-1867's start sites do not depend on which ephemeral source ports other connections hold.
- **A tolerated absence is still a gate check.** The alerts tail answers 200, or 404 with code `LOG.ABSENT`. Anything else is red, a 403 included.
- **The port rule is read, not assumed.** Each start site reads the low bound of `/proc/sys/net/ipv4/ip_local_port_range` from the instance it runs against, at run time. A file that cannot be read is a failure that names the file, never a pass.
- **Ports.** The probe ports that move keep their last three digits and move from 53xxx to 31xxx: `LanguageServerWire` 31291 and 31292; `language-servers` spec 31293; editor spec 31294, 31295 and 31296; `LanguageServerEditorWire`'s started Java probe 31294. Nothing listens on these ports on `ocupilot-ci` (read at plan).
- **Reproductions run on `ocupilot-ci` only and leave it as found.** `alerts.log` is restored, with anything IRIS wrote meanwhile appended. Every port occupant, probe server and activity row is removed.

**Never:**

- No seeding of `alerts.log`. A severe line raises the instance's alert state, which other tests can observe.
- No retry of a refused probe start. No new test class, browser spec, screen, string or roster entry. No spine edit.
- No edit to `LanguageServerEditorWire`'s ports for probes it never starts (its Python, .NET, Remote, ODBC, agent and taken probes) or to its edit targets such as 53299. The editor spec moves all three of its port constants, the started one and the two it only creates and edits, so its one block stays uniform.
- No restart, recreate or `down` of `ocupilot-ci`. No probe or test on `ocupilot`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Fresh instance (DW-1851) | `alerts.log` absent; `OcuPilotWireAudit` holds the Logs set and not `%Ens_EventLog:USE` | alerts tail 404 `LOG.ABSENT`; the messages tail and the messages and alerts declared reads 200; the event log's route and read 403 naming its pair; test green | - |
| Instance that has alerted | `alerts.log` present | alerts tail 200; test green | - |
| Gate widened (mutation) | `ALERTSPAIRS` gains `%Ens_EventLog:USE` | alerts tail 403; test red | - |
| Port in range (mutation) | a started probe's port set back to 53xxx | that site's range assertion red, naming the port and the low bound | - |
| Occupied old port (reproduction) | a client socket bound to 127.0.0.1:53296 during the editor spec's AC3 | before the fix: AC3 red with "the seeded probe starts (HTTP 500)" after about 10 s, as in CI; after the fix: 4/4 green | occupant removed after |
| Refused fixture start | the seeded probe's own port held by hand | AC3 red, and its message carries the vendor's error text from the admin API answer | - |

</intent-contract>

## Code Map

**DW-1851:**

- `src/OcuPilot/Test/WireSecurityRead.cls:1209-1234`: the test and its doc. The loop at :1222-1226 asserts 200 for all four paths. The second path, `/api/ocupilot/logs/alerts?maxBytes=4096`, is the one a fresh instance answers 404. Arming: `ARMINGVARIABLE` :51.
- `src/OcuPilot/Port/LogSourcePort.cls`:
  - `Resolve` :2913-2934 refuses `LOG.ABSENT` (:2930) once the gate has passed (AD-21);
  - `Rows` :831-835 and :866-872 turn that refusal into 200 with no rows, so `/screens/logs.alerts/read` is 200 either way;
  - `ALERTSPAIRS` :184 is the mutation target.
- Precedent for the tolerance: `Test/LogSource.cls:191-200` and `Test/LogSourceDenial.cls:343-352`.
- `alerts.log` on `ocupilot-ci` is `/durable/iris/mgr/alerts.log` (239 KB at plan). `ui/browser/alerts-log.browser-spec.mjs:92-98` uses the same path.

**DW-1867:**

- `ui/browser/language-server-editor.browser-spec.mjs`:
  - ports :55-57;
  - `adminApi` :67-74, which answers only the status;
  - `before` :172-179, which seeds `SEEDED` with `{Type, Port}`;
  - AC3 :311-331, where the start assertion :316 failed in CI.
  - Shell helpers come from `./turnprobe-spec.mjs:52-70` (`runIris`, `markerValue`, `spawnSync` docker exec).
- `ui/browser/language-servers.browser-spec.mjs`: `SERVER_PORT` :45, seeded at :72, started through the list's Start.
- `src/OcuPilot/Test/LanguageServerWire.cls`:
  - `PROBEPORT` :35 and `BADPROBEPORT` :40;
  - `CreateProbe` :385, called at :87-89;
  - the first start is in `TestTheExactPairsPrincipalStartsAndStopsTheProbe` :146.
- `src/OcuPilot/Test/LanguageServerEditorWire.cls`:
  - `PROBES` :46 (`OcuPilotProbeELSEdJava:Java:53294`), read through `ProbePort`/`CreateProbe` :505;
  - the literal 53294 at :184, :255 and :312;
  - the start in `TestAStartedServerIsRefusedEditAndDelete` :292-298, through `Start` :549-553.
- Vendor, read in source:
  - `%Net.Remote.Service.StartGatewayObject` (`irislib/%Net/Remote/Service.cls:67-160`). `CheckLocalPortFree` comes first. When the port is not free, it pings for 10 s and answers "invalid ping response".
  - `RunStartCmd` :176-220 reads the launch pipe with a fixed 10 s read.
  - `%Net.Remote.Utility.CheckLocalPortFree` :259-274 opens a server socket on the port.
- CI precedent: `.github/workflows/ci.yml:161-171` (DW-439) reserves the host's published ports for the same reason, an ephemeral source port held by a transient occupant.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Test/WireSecurityRead.cls` -- DW-1851. In `TestTheLogsAreaStaysOpenWithoutTheEventLogsPair`, the alerts tail path accepts 200, or 404 whose body's `code` is `LOG.ABSENT`. The other three paths keep 200. The doc states the two outcomes and the `ALERTSPAIRS` mutation. Nothing else in the class changes.
- `ui/browser/language-server-editor.browser-spec.mjs` -- DW-1867:
  - ports 31294, 31295 and 31296;
  - in `before`, assert each is below the container's ephemeral low bound, read with `docker exec <container> cat /proc/sys/net/ipv4/ip_local_port_range`;
  - AC3's start fails with the admin API answer's `status.errors` text and the last console lines in its message (decode `<br>` and HTML entities);
  - one header sentence says why the ports sit below that range.
- `ui/browser/language-servers.browser-spec.mjs` -- DW-1867: `SERVER_PORT` 31293, with the same assertion in `before`.
- `src/OcuPilot/Test/LanguageServerWire.cls` -- DW-1867:
  - `PROBEPORT` 31291 and `BADPROBEPORT` 31292;
  - a ClassMethod `EphemeralLow()` reads the file's first number and answers `""` when it cannot read it;
  - `TestTheExactPairsPrincipalStartsAndStopsTheProbe` first asserts both ports are below it, naming the file on a failed read;
  - one header sentence.
- `src/OcuPilot/Test/LanguageServerEditorWire.cls` -- DW-1867:
  - the `PROBES` entry for `OcuPilotProbeELSEdJava` becomes port 31294;
  - the 53294 literals at :184, :255 and :312 become 31294;
  - `TestAStartedServerIsRefusedEditAndDelete` asserts `ProbePort("OcuPilotProbeELSEdJava")` is below `##class(OcuPilot.Test.LanguageServerWire).EphemeralLow()` before it starts the probe;
  - one header sentence.
- Reproductions on `ocupilot-ci`, not committed:
  - DW-1851 (AC1): move `alerts.log` aside, run the class, check the file is still absent, restore it.
  - DW-1867 (AC3): hold 53296 with `docker exec -d ocupilot-ci python3 -c` (bind `127.0.0.1:53296`, connect to `127.0.0.1:1972`, sleep 180 s so it outlives AC1), run the editor spec, then remove the occupant.
  - Record each under `## Verification`.

**Acceptance Criteria:**

- **AC1 (DW-1851).** Given `ocupilot-ci` with `alerts.log` moved aside, when `OcuPilot.Test.WireSecurityRead` runs armed on the unchanged tree, then `TestTheLogsAreaStaysOpenWithoutTheEventLogsPair` is red, on the alerts tail's 404. When it runs again with the fix, then the test is green and `alerts.log` is still absent after the run. A run with `alerts.log` restored is green too. If the file reappears during a run, that run does not count as a reproduction: repeat the red with a single-method run, and keep the green from a full-class run.
- **AC2 (DW-1851).** Given the fix, when `ALERTSPAIRS` also names `%Ens_EventLog:USE` and `LogSourcePort` is recompiled, then the test is red on the alerts tail's 403. The tolerance is not vacuous.
- **AC3 (DW-1867).** Given the unchanged editor spec and a client socket holding 127.0.0.1:53296, when the spec runs, then AC3 fails at "the seeded probe starts (HTTP 500)" in about 10 s, which reproduces CI run 36724473192's failure. Given the fix and the same occupant, when it runs again, then 4/4 pass.
- **AC4 (DW-1867).** Given each of the four start sites, when it runs, then it asserts that every port it starts a probe on is below the container's ephemeral low bound. Setting one port back to its 53xxx value reddens that assertion, naming the port and the bound.
- **AC5 (DW-1867).** Given the fixed editor spec and its own seeded port held by hand, when AC3's start is refused, then the failure message carries the vendor's error text, such as "Connection cannot be established". The next recurrence names its cause.

## Spec Change Log

## Review Triage Log

### 2026-10-01 — Review pass

- verdicts: 10 findings — high 0, medium 0, low 7, false 3, maybe-false 0
- findings:
  - `[low]` `[patch]` (verification-gap) AC5's vendor reason in AC3's start message had no demonstrated mutation — demonstrated in the review pass: 127.0.0.1:31296 held, `vendorReason(answer)` dropped from the message → AC3 red on "(HTTP 500)" alone; reverted byte-identical, `mutation:` line written. The suggested new tools test file is outside the intent ("no new test class, browser spec").
  - `[low]` `[patch]` (verification-gap) `## Verification` recorded the reproductions and mutations without the `mutation: <what> → <test>` form — the AC1-AC5 lines rewritten in that form.
  - `[low]` `[reject]` (verification-gap) AC3's "fixed spec, same occupant → 4/4" cannot fail by construction: it shows the port moved, not that the rule is right — AC3 defines that run, so the fix edits this build's spec; the rule is pinned by AC4's four mutations, and the limit is named under residual risks.
  - `[low]` `[reject]` (intent-alignment, R2) "no more CI flakes" is observable only in later CI runs, and DW-1867's cause is an inference — inherent to a flake fix; the spec labels the inference and AC5 makes a recurrence name its cause; named under residual risks.
  - `[low]` `[reject]` (intent-alignment, R3) the after-fix run does not exercise the mechanism (the kernel never assigns a source port below the low bound) — same root cause as the AC3 row above, same route.
  - `[low]` `[reject]` (intent-alignment, R4) `LanguageServerWire` checks the ports in one of the three methods that start a probe — the constants it checks are the ones every start reads, so a full class run, the unit CI runs, pins them; only a single-method run of another method skips it, the spec's Tasks name that method, and the fix adds assertions.
  - `[false]` `[reject]` (intent-alignment) `vendorReason`'s reading of `status.errors[].error` and `console[]` is unconfirmed — the review pass's own AC5 run printed both halves: the `#5023`/`#5001` error text and the decoded console lines.
  - `[low]` `[reject]` (intent-alignment) `ephemeralLow` and `PORT_RANGE_FILE` are copied into both browser specs — two five-line copies with no named caller to diverge; sharing them means a new export in a helper outside the Code Map.
  - `[false]` `[reject]` (intent-alignment) the `LIVE_CONTAINER` guard in both specs goes beyond the task list — `ui/tools/angular-json.test.mjs:307-313` (DW-159) requires it in any spec that runs docker, and `npm run test:tools` is red without it.
  - `[false]` `[reject]` (intent-alignment) the frontmatter reads `in-review` while the Auto Run Result section reads `ready-for-dev` — that section is written at finalize in this same pass.

## Design Notes

**DW-1851: the product is right.** AD-21 makes an absent log file a named refusal, 404 `LOG.ABSENT`, after the gate. DW-1814 (AD-2) stopped a 404 read from logging, so a fresh instance can go a whole shard without creating `alerts.log`. The declared read already answers 200 with no rows (`LogSourcePort.Rows` :866-872, pinned by `LogSource:191-200`), so only the tail leg fails. Accepting `LOG.ABSENT` is the precedent in `LogSource` and `LogSourceDenial`: reaching it proves the gate admitted the caller. Seeding would raise the instance's alert state, which is a new coupling.

**DW-1867: the recorded inference is wrong.** CI run 36724473192 attempt 1, browser shard 2/3 (job 109917670405), failed at the start assertion :316 with "the seeded probe starts (HTTP 500)". The test took 10.24 s, its `finally` stop included. The editor was never opened. The ledger and the epic context say "the probe's start is read before it reports running", which is refuted. The vendor's reason did not survive: the container log holds only startup lines, and the artifacts hold only test records.

**Measured on `ocupilot-ci`, 2026-10-01.** All probes were removed after.

| Case | Answer | Time |
|---|---|---|
| Default Java start | 200; the pipe read returned at 10 s, then the ping | 10.7 s |
| JVM made to wait 12 s before launch | 200: neither the pipe read's timeout nor the 5 s ping refuses it | 12.7 s |
| Port held as a client socket's source port (bound to 127.0.0.1:53311, connected to 1972) | 500 "Connection cannot be established > invalid ping response"; a stop while it is held takes 10.4 s | 10.27 s |
| Start right after a stop | 500 "Communication failure ... invalid ping response" | 0.2 s |

- 16.10 measured a process that dies after launch at 500 "Failed to detect Gateway" in 5.7 s.
- The container's ephemeral range is 32768-60999, with nothing reserved. At idle, five established connections to 1972 held source ports 38112, 38122, 38960, 47838 and 53340 (the in-container web gateway's, inference). Every probe port, 53291-53301, is inside that range.

**Cause (inference).** A slow JVM cannot produce a refusal in about 10 s, so that branch is ruled out. The failure's timing fits two cases, and the probe port sitting inside the container's ephemeral range explains both:

- the port check found the port held, pinged for 10 s and refused;
- the JVM was launched, could not bind a held port, and died.

The occupant would be an outbound connection's source port, such as the in-container web gateway's to 1972. DW-439 is the same hazard on the host. Ports below the range can never be handed out as source ports, and that is what AC4 pins. A recurrence with any other vendor reason is a new ledger entry, which AC5 makes diagnosable.

**The screen was checked first.** `LanguageServerForm.editable()` is false until the edit's read is held and while `running()` holds. Both come from one `absorb` of one form read (store :279-289, :600-620), so no render shows editable controls for a running server. The page spec pins it (`language-server-form.page.spec.ts:268`). No code change.

**Named limit.** `LanguageServerEditorWire`'s other probes and every edit-target port stay in 53xxx, because they are never started.

**Governing ADs:**

- AD-21 (the `LOG.ABSENT` refusal after the gate), AD-2 and AD-39 (DW-1814: a 404 read logs nothing), AD-8 (Logs keeps its set; the event log's own pair), AD-29 (the port's gate);
- AD-36 (`ACTIVITY` gives `CurrentlyRunning`), AD-19 (the editor's one-store state);
- Conventions › Tests (a test depends on nothing beyond the fresh instance).

No AC contradicts an AD.

**Spine amendments for the lead:** none needed; each start site pins its own ports. If wanted, a sentence for Conventions › Tests: "A test that starts a server on the instance gives it a port below the container's ephemeral range, which it reads at run time, so no outbound connection's source port can hold it (Story 16.26, DW-1867)."

**Integration ACs:** none. This story introduces no service, module or shared component. It changes five test files.

**Consumes:** 16.8's Logs gate and `LogSourcePort`; 16.10's and 16.25's probe fixtures. **Consumed-by:** none.

**Ledger.** DW-1851 is addressed by AC1-AC2, and DW-1867 by AC3-AC5. For the lead: correct DW-1867's evidence at its origin (the failing step is the fixture start, HTTP 500, at :316). The epic context repeats the refuted inference.

**Footprint.** None of the five files is in Epic 18's diff or working tree (checked at plan). No exact-count roster moves, and nothing is shared-append.

## Verification

Slot A only: every run and reproduction is on `ocupilot-ci`, one test call at a time. Load code with `rsync -a --delete src/ /tmp/ocupilot-ci/src/`, then `sh /private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/1518373f-040c-4be6-a814-a27bfbff2961/scratchpad/epic-16/compile.sh Test/WireSecurityRead.cls Test/LanguageServerWire.cls Test/LanguageServerEditorWire.cls`, and read every line.

**Commands:**

- `uv run scripts/check-objectscript.py src/OcuPilot/Test/WireSecurityRead.cls src/OcuPilot/Test/LanguageServerWire.cls src/OcuPilot/Test/LanguageServerEditorWire.cls` (loop) -- expected: 0 findings.
- `cd ui && EPIC16_ARM="OCUPILOT_ALLOW_ACCOUNT_PREFERENCES OCUPILOT_ALLOW_AUDIT_EVENTS OCUPILOT_ALLOW_AUDIT_PURGE OCUPILOT_ALLOW_AUDIT_TOGGLE OCUPILOT_ALLOW_DATABASE_CONFIG OCUPILOT_ALLOW_ERROR_DELETE OCUPILOT_ALLOW_ERROR_SEED OCUPILOT_ALLOW_LOG_ROTATION OCUPILOT_ALLOW_NAMESPACE_CONFIG OCUPILOT_ALLOW_PRINCIPALS OCUPILOT_ALLOW_PROCESS_CONTROL OCUPILOT_ALLOW_PRODUCTION_INSTALL OCUPILOT_ALLOW_SERVICE_CONFIG OCUPILOT_ALLOW_SSL_CONFIG OCUPILOT_ALLOW_TASK_CONTROL OCUPILOT_ALLOW_TEST_PROVIDER" PATH=/private/tmp/claude-501/-Users-jbrandt-git-OcuPilot/1518373f-040c-4be6-a814-a27bfbff2961/scratchpad/epic-16-recover/shim:$PATH node tools/ci-runner.mjs --container ocupilot-ci --class <C>` (loop), one class per call. `<C>` is each of `OcuPilot.Test.WireSecurityRead`, `OcuPilot.Test.LanguageServerWire` and `OcuPilot.Test.LanguageServerEditorWire`. Expected: green, apart from `WireSecurityRead`'s known task-history residue (DW-1425/DW-1468).
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/ && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/language-server-editor.browser-spec.mjs browser/language-servers.browser-spec.mjs` (loop) -- expected: 4/4 and 2/2.
- `cd ui && npm run test:tools` (once, before `dev_complete`) -- expected: green.
- `node tools/ci-runner.mjs --container ocupilot-ci` through the same shim and arming (once, before `dev_complete`), one class at a time -- expected: green apart from the known residue the slot rules list. The full browser suite runs in CI (Rule 29).

**Reproductions and mutations, recorded by the implement stage:**

- AC1: mutation: the fix reverted (unchanged tree), `alerts.log` moved aside → run 23754, `TestTheLogsAreaStaysOpenWithoutTheEventLogsPair` red on the alerts tail's 404 `LOG.ABSENT`, the file still absent after the run. Fixed, file aside again → run 23755 green, the file still absent after. Restored → run 23757 green. Each run's only other failure is the known residue `TestTaskHistoryPairSetsAreEnforcedForARealPrincipal` (DW-1425/DW-1468).
- AC2: mutation: `ALERTSPAIRS` = `%Admin_Operate:USE,%Ens_EventLog:USE`, `LogSourcePort` and its three fixture subclasses recompiled → run 23756, `TestTheLogsAreaStaysOpenWithoutTheEventLogsPair` red on the alerts tail's 403 `AUTH.NOPRIVILEGE` naming `%Ens_EventLog:USE`.
- AC3: mutation: the fix reverted (unchanged spec), 127.0.0.1:53296 held by a client socket connected to 1972 → 3/4, AC3 red at "the seeded probe starts (HTTP 500)" in 10.30 s. Fixed spec, same occupant, established throughout → 4/4.
- AC4: mutation: `SEEDED_PORT` 53296 → the editor spec's `before` red, "probe port 53296 is below ocupilot-ci's ephemeral port range, which starts at 32768". mutation: `SERVER_PORT` 53293 → the list spec's `before` red, same message. mutation: `PROBEPORT` 53291 → run 23758, `TestTheExactPairsPrincipalStartsAndStopsTheProbe` red on that assertion alone. mutation: the `PROBES` Java entry 53294 → single-method run 23759, `TestAStartedServerIsRefusedEditAndDelete` red on the port assertion and on the 31294 literal.
- AC5: 127.0.0.1:31296 held by a client socket connected to 1972, fixed spec → 3/4, AC3 red: "the seeded probe starts (HTTP 500): ... #5023: Remote Gateway Error: Connection cannot be established > ... #5001: External Language Server: invalid ping response | console: ... Starting Java Gateway Server 'OcuPilotProbeELSSeeded' / ... An error occurred while trying to start the Gateway Server". mutation: `: ${vendorReason(answer)}` dropped from AC3's start message, same occupant → AC3 red on "the seeded probe starts (HTTP 500)" alone, no vendor text. An occupant socket set `SO_REUSEADDR` leaves the port bindable and AC3 green, so the occupant sets none.
- Final: `LanguageServerWire` run 23760 4/4; `LanguageServerEditorWire` run 23761 7/7; `WireSecurityRead` run 23757 24/25, residue only; `language-servers` 2/2 and `language-server-editor` 4/4; `npm run test:tools` 1763/1763; `check-objectscript` 0 findings.
- After each: the tree is byte-identical (`git status --short`, `git diff --stat`), and `ocupilot-ci` holds no occupant, no `OcuPilotProbeELS*` server, no activity row and a restored `alerts.log` (239,294 bytes, nothing appended).

## Auto Run Result

Status: done
Blocking condition: none

**Change.** Test-only fixes for two CI flakes; no product code.

- DW-1851: `WireSecurityRead.TestTheLogsAreaStaysOpenWithoutTheEventLogsPair` accepts 200 or 404 `LOG.ABSENT` on the alerts tail. Anything else is red, a 403 included.
- DW-1867: every probe that is started listens on a 31xxx port. Each of the four start sites reads `/proc/sys/net/ipv4/ip_local_port_range` at run time and asserts its ports are below the low bound. An unreadable file is red and names the file. AC3's fixture start now reports the vendor's `status.errors` and last console lines.

**Files.**

- `src/OcuPilot/Test/WireSecurityRead.cls`: the alerts tail tolerance, and its doc.
- `src/OcuPilot/Test/LanguageServerWire.cls`: ports 31291 and 31292, `PORTRANGEFILE` and `EphemeralLow()`, and the port check in the first start test.
- `src/OcuPilot/Test/LanguageServerEditorWire.cls`: the started Java probe on 31294 (`PROBES` and three literals), checked against `EphemeralLow()`.
- `ui/browser/language-server-editor.browser-spec.mjs`: ports 31294-31296, the range check in `before`, and the vendor reason in AC3's message.
- `ui/browser/language-servers.browser-spec.mjs`: `SERVER_PORT` 31293 and the range check in `before`.
- Both specs also gained the `LIVE_CONTAINER` guard that `angular-json.test.mjs` (DW-159) requires of a spec that runs docker. No path outside the Code Map.

**Review.** 10 findings: 2 low patched, 5 low and 3 false rejected, none deferred (see the triage log).

- Patched: AC5's mutation demonstrated and recorded, and the Verification lines put in `mutation:` form.
- Follow-up review: `false`. Patched counts: high 0, medium 0, low 2.

**Verification** (all on `ocupilot-ci`, one run at a time, after the handoff):

- `check-objectscript`: 0 findings. `npm run test:tools`: 1763/1763.
- ObjectScript, after a sync and compile: `WireSecurityRead` run 23762 24/25, the one failure the known residue `TestTaskHistoryPairSetsAreEnforcedForARealPrincipal` (DW-1425/DW-1468). `LanguageServerWire` run 23763 4/4. `LanguageServerEditorWire` run 23764 7/7.
- Browser, after `npm run build` and a redeploy: `language-server-editor` 4/4, `language-servers` 2/2.
- The handoff's runs 23754-23759 were read back from `%UnitTest_Result` and match `## Verification`.
- The full ObjectScript sweep was skipped as test-only, on the lead's instruction. The full browser suite is CI's (Rule 29).
- `ocupilot-ci` ends as found: no occupant, no `OcuPilotProbe*` server, 0 probe activity rows, and `alerts.log` at 239,294 bytes.

**Residual risks.**

- Whether CI stops flaking shows only in later CI runs. DW-1867's cause is an inference; AC4 pins the port rule, and AC5 makes any other cause name itself.
- A port bound by hand below the range still refuses the start (AC5). The handoff also saw a TIME_WAIT left on the port by a closed connection refuse a start once.
- For the lead: DW-1867's ledger evidence and the epic context still repeat the refuted inference ("read before running"). Correct them at their origin.
