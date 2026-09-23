---
title: 'Story 8.9: Plain IRIS Community verification'
type: 'feature'
created: '2026-09-23'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-8-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Until now, OcuPilot had only been compiled on plain IRIS Community, never installed there. The plan-time probe installed it on the stock image. Install worked, the admin API worked, and 47 of 47 smoke checks passed. The probe also found two defects:

- **`scripts/smoke.sh` cannot find the install.** It defaults to `HSCUSTOM`, so on an instance without that namespace it answers "Access Denied" and gives no verdict.
- **The IRIS-credentials rung is offered where it cannot work.** In a namespace that is not interoperability-enabled, the Definition form still offers the API-key field. Test connection then refuses the key. That is "offered and failing", which AC2 forbids.

**Approach:**

- Fix the smoke default so it follows the install resolver.
- Make CI install, probe and smoke on both stock editions by extending the `images` job.
- Where the credentials rung is unreachable, publish that fact. The form then offers the environment-variable rung in the key field's place, and the server refuses a `creds` definition.
- Correct the README, the workflow header, `ci-image-compile.sh`'s header and `CLAUDE.md`, all at their origin.

## Boundaries & Constraints

### Always

- **The install namespace resolves one way everywhere:** `--namespace` first, then `OCUPILOT_NAMESPACE`, then the instance's own answer (`HSCUSTOM` if it exists, else `USER`).
  - `smoke.sh` asks the instance through the same runner it already uses (`container-start.sh:176-178` is the model).
  - When neither namespace exists, smoke exits non-zero with a message naming both. It never runs a session in a namespace that does not exist.
- **Rung availability comes from one source,** `Ladder.CredentialsRungAvailable()`, reached through `Definitions.SecretClass()`. Nothing else derives it.
  - The client learns it only from `GET /api/ocupilot/agent/providers`, as a top-level boolean `credentialsRungAvailable` beside `providers`.
  - The client treats only an explicit `false` as unavailable. A missing flag keeps today's behavior.
- **The refusal copy lives on the server** (AD-39). The new code's sentence is authored once in `Api/Error.cls`. Every visible client word is a `STRINGS.<key>` with a Fixed strings row.
- **The CI change follows the instance and browser jobs.**
  - The `images` job's throwaway runs from `scripts/ci-throwaway.sh` with its own `--dir`, `--project` and ports. The capture step runs on `failure() || cancelled()` before the teardown, and the teardown runs on `always()`.
  - Every job's reserved-ports step names the same three ports.
  - `ui/tools/ci.test.mjs` holds the new shape in both directions, and no existing assertion is loosened.

### Never

- Never edit `src/OcuPilot/Install/Smoke.cls` or `Kernel/Restraint.cls` (Epic 7's). The smoke checks themselves are unchanged.
- Never make the env rung writable, and never add a secret field for it. The operator sets the variable on the host (FR-26).
- No change to the ladder's resolution logic or its predicate (`Ladder.cls`), and no new route.
- No full ObjectScript suite on plain Community in CI. See Design Notes, which put it to the lead.
- Never touch `ocupilot`, any `ocupilot-slot-*`, `ocupilot-ci` or `ocupilot-browser-ci`. Tear down only a throwaway you brought up.
- Leave `ci-runner.mjs`, `ci-unit-test.sh`, `field-lists.sh` and `ci-ipm-archive.sh` unchanged. Their `HSCUSTOM` defaults serve jobs that run only on IRIS for Health.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|---|---|---|---|
| Smoke on plain Community | `smoke.sh --container X --user _SYSTEM --password SYS` with no `--namespace`, where the instance has `USER` and no `HSCUSTOM` | The session runs in `USER` and reports its verdict (47/47 measured with `--namespace USER`) | No error expected |
| Smoke on an instance with neither namespace | No `--namespace`, no `OCUPILOT_NAMESPACE`, and the instance answers no candidate | Exits non-zero naming `HSCUSTOM` and `USER`, and opens no session | A caller-visible refusal, never "Access Denied" |
| Smoke with an override | `--namespace NS`, or `OCUPILOT_NAMESPACE` in `/proc/1/environ` | That namespace, unchanged from today | As today |
| Providers, rung present | `GET /agent/providers` in `HSCUSTOM` (interop-enabled) | `{providers:[...], credentialsRungAvailable:true}` | 403 without `OcuPilotAdmin`, as today |
| Providers, rung absent | The same call, with `CredentialsRungAvailable()` answering 0 (the seam) | `credentialsRungAvailable:false` | No error expected |
| Create or update a `creds` definition, rung absent | `POST`/`PUT /agent/definitions` with `credType:"creds"` | 422, with violation `{field:"credType", code:"AGENT.CREDTYPE.UNAVAILABLE"}` in the same set as the other rule violations. Nothing is stored | One envelope (AD-12) |
| Create an `env` definition, rung absent | `credType:"env"`, `envVarName:"ANTHROPIC_API_KEY"` | 201, as today | No error expected |
| Form, rung absent, create | The providers response says `false` | No API-key field, reveal toggle or "Stored." caption. An "Environment variable" field, pre-filled from the provider row's `defaultEnvVarName`, sits in the key field's place. The body sends `credType:"env"`. Test connection posts no credential | An empty variable answers `AGENT.ENVVAR.REQUIRED` on that field |
| Form, rung absent, provider change | The provider changes, or "No API key" is unticked | The cascade restores `env`, never `creds` | — |
| Form, rung absent, edit of a stored `creds` definition | The loaded row has `credType:"creds"` | Shown in env mode. The buffer's `credType` becomes `env`, with the row's `envVarName` or the catalog default. This counts as an unsaved change, so the leave guard applies | Nothing is saved silently |
| Form, rung present | The flag is `true` or absent | Exactly as today | — |

</intent-contract>

## Code Map

### Contention (Epic 7 head `2081662424eef9806e6915919b3d4f08d0c7e2ae`)

Before editing a ⚠ file, run `git fetch origin && git show origin/OCU-1-epic7:<path>`. Append only, and stay off Epic 7's hunks.

- ⚠ `ui/src/app/core/strings.ts`: append two keys before `} as const;` (:1489 here, :1488 on Epic 7).
- ⚠ `_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`: append one Fixed strings row after :421, the table's last row. Epic 7 adds rows at :395-425, so expect a union merge.
- Every other file below is outside `git diff --name-only dd70e59 origin/OCU-1-epic7`.
- **Needs the lead:** none of Epic 7's product files.

### Probe evidence (plan time, throwaway `ocupilot-b-community` on 52780/1979, `intersystems/iris-community:2026.2`)

- Install: `container-start: install namespace resolved to USER`, `STARTPATH-OK`, healthy. Readiness answered `{"installed":true,"version":"1","state":"installed"}`. The install log shows `%DB_USER:R` on the shell and readiness roles.
- `scripts/smoke.sh --container ocupilot-b-community --user _SYSTEM --password SYS` answered "Access Denied" with no verdict. With `--namespace USER` it passed 47 of 47.
- Admin API:
  - `AdminPort.VerifyInstance` answered OK with version 2.
  - `node tools/admin-spec.mjs --origin http://localhost:52780` was clean: 185 paths, 184 common, 0 method differences.
  - `GET /api/admin/v2/databases` answered 200.
- Credential predicates in `USER`: `IsEnsembleNamespace` 1, `License.GetFeature(1)` 1, `Ens.Config.Credentials` compiled. So on the stock image the creds rung is reachable, and offering it there is correct.
- A namespace created with `Config.Namespaces.Create` (globals in a new database, routines in `USER`'s) read `IsEnsembleNamespace` 0 and `CredentialsRungAvailable()` 0. `Resolve("env","HOME")` still answered, while `Resolve("creds",...)` answered `""` with transient 1.

### Server (AC2)

- `src/OcuPilot/Api/Definitions.cls`:
  - `HandleProviders` :221 builds `{providers}` at :264-266. Add the flag there.
  - `HandleCreate` :299 and `HandleUpdate` :355 run `AgentRules.Validate` at :327 and :389. The unavailable check joins that violation set.
  - `SecretClass()` :1194 is the seam, and `OcuPilot.Test.DefinitionsProbe` overrides it with `SecretProbe`.
  - `RenderViolations` is at :1270.
  - `CredentialRefusal` :1020-1042 is the model: a public method that tests drive in-process, because no request can reach an unavailable rung on an interop instance.
- `src/OcuPilot/Kernel/AgentRules.cls`: `CredTypeAccepted` :330 stays pure. `CREDTYPEENV`/`CREDTYPECREDS` are at :30/:35. Rule 5's `envVarName` requirement is at :168.
- `src/OcuPilot/Api/Error.cls`:
  - `AGENTCREDTYPEUNKNOWN` :416 is the neighbor for the new code parameter.
  - The reason mapping is at :1055/:1072, and the agent field-code list at :1250.
  - The `REASONAGENTCREDENTIALRUNGUNAVAILABLE` sentence at :1321 is the wording model.
- `src/OcuPilot/Test/SecretProbe.cls`: `SetRungAvailable` :32 and `CredentialsRungAvailable` :74.
- `src/OcuPilot/Test/AgentCredential.cls` :226-239 shows the in-process pattern. The class is 606 lines, so the new tests go in a new class.
- `src/OcuPilot/Test/Secret.cls` :59 already pins the env arm answering with the predicate off. Do not duplicate it.

### Client (AC2)

- `ui/src/app/areas/agent/definition-form.store.ts`:
  - `loadProviders` :750 reads `raw.providers` at :755.
  - `emptyBuffer` :950 defaults `credType` to `creds` at :955.
  - `applyProviderDefaults` :775, which sets `envVarName` at :784 and restores `creds` at :792.
  - `CASCADE_ONLY_FIELDS` :97 lists `envVarName`. In env mode it becomes a rendered field.
  - `save` :563 and `testConnection` :607, which posts the key at :640-653.
- `ui/src/app/areas/agent/definition-form.page.ts`: the key field :269-299, "No API key" :233-248, `onNoKey` :916 and `heldCredType` :498.
- `ui/src/app/areas/agent/definition-form.page.spec.ts`: existing env legs at :1114 and :1320-1361.
- `ui/src/app/core/strings.ts` :508/:512 hold the neighboring keys.

### Scripts, CI, docs (AC1, AC3)

- `scripts/smoke.sh`: the usage header at :21, the namespace default at :139-147, and the runner at :114/:156.
- `scripts/container-start.sh` :175-178 is the resolver to mirror.
- `.github/workflows/ci.yml`:
  - Header :9-21 says "Four jobs" and omits `browser`.
  - The reserve steps are at :139-140 and :209-210.
  - The browser job's throwaway steps at :211-228 are the template.
  - The `images` job is at :230-243.
- `ui/tools/ci.test.mjs`:
  - `DECLARED_GATES` :102-144, with the reserve step at :120/:131 and images at :136.
  - `runCommands` :154 and `jobNames` :196/:454.
  - Always/teardown pairing :370-391, and capture-before-teardown :393-434 over `['instance','browser']`.
  - Images matrix :480-487.
  - The ports-and-name "one fact" test :1475-1535.
  - The smoke stub harness :2087-2109, which today passes `--namespace HSCUSTOM`.
  - `ci-image-compile.sh` verdict arms :1555-1579.
- `scripts/ci-image-compile.sh` :5-7 and :22-23: the "does not install / deferred past the floor" sentences are now false.
- `README.md`:
  - :31-33 is the Community claim.
  - :452-457 documents smoke with no default-namespace sentence.
  - :488-496 says "Four jobs", has no `browser` row, and its `instance` row still lists `npm run test:browser`.
  - :629-641 is the namespace table.
- `CLAUDE.md` :140 says "four jobs". This is outside every epic's footprint; the lead reports it.

## Tasks & Acceptance

### Execution

1. `scripts/smoke.sh`: make the resolution order `--namespace`, then `OCUPILOT_NAMESPACE`, then an instance probe through `$RUNNER iris session iris -U %SYS` that prints between markers.
   - When neither candidate exists, refuse with exit 1 and a message naming both.
   - Update the usage header at :21.
2. `ui/tools/ci.test.mjs`: extend the stub harness at :2087 so the stub `iris` answers the namespace probe. Add three legs:
   - no `--namespace` with the stub reporting only `USER`: the report session runs `-U USER`;
   - the stub reporting neither: non-zero exit and both names, with no report session;
   - `--namespace HSCUSTOM`: the existing behavior is unchanged.
3. `.github/workflows/ci.yml`, `images` job (both legs, no `if:` on the matrix value). Add these steps after `ci-image-compile.sh`:
   - setup-node `22.22.3`, pinned like the other jobs;
   - `npm ci` and `npm run build` in `ui`;
   - `sudo sysctl -w net.ipv4.ip_local_reserved_ports=52776,52780,52781`;
   - `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-images-ci --project ocupilot-images-ci --web 52781 --super 1980 --image ${{ matrix.image }}`;
   - `sh scripts/wait-readiness.sh --url http://localhost:52781/api/ocupilot/readiness/`;
   - `node tools/admin-spec.mjs --origin http://localhost:52781` in `ui`;
   - `sh scripts/smoke.sh --container ocupilot-images-ci --user _SYSTEM --password SYS`, with no `--namespace`, because the fallback is what is under test;
   - the capture step on `failure() || cancelled()`, then the teardown on `always()`, both with the same `--dir`/`--project`.

   Also:
   - Change the instance and browser reserve steps to the same three-port text.
   - Rewrite the header's job list to name five jobs, `browser` included. Say that `images` installs and smokes on each edition.
4. `ui/tools/ci.test.mjs`: hold the new shape.
   - Add the new `run:` lines to `DECLARED_GATES`, and update the reserve-step literal in all three places.
   - Add `'images'` to the capture-before-teardown loop.
   - In the one-fact test, cover the images throwaway: its `--web` port appears in the reserve step, its readiness URL and admin-spec origin, and its `--project` equals smoke's `--container` and the teardown's `--project`.
   - Assert that the images `up` line carries `--image ${{ matrix.image }}` and that images' smoke line carries no `--namespace`.
5. `scripts/ci-image-compile.sh`: replace the deferral sentences at :5-7 and :22-23 with the current fact. The script compiles and reads the version portless, and the install is the images job's own later steps.
6. `src/OcuPilot/Api/Error.cls`:
   - `Parameter AGENTCREDTYPEUNAVAILABLE = "AGENT.CREDTYPE.UNAVAILABLE"`.
   - `REASONAGENTCREDTYPEUNAVAILABLE` = "The credential store is not available in this namespace. Read the key from an environment variable instead."
   - Map the code to the reason and add it to the agent field-code list at :1250.
7. `src/OcuPilot/Api/Definitions.cls`:
   - `HandleProviders` adds `credentialsRungAvailable`. Build the body in a public `ProvidersBody(Output pBody) As %Status` so a test drives it through `DefinitionsProbe`.
   - Add a public `CredTypeRefusal(pCredType As %String) As %String`, which answers the new code for `creds` when `$ClassMethod(..SecretClass(),"CredentialsRungAvailable")` is 0, else `""`.
   - `HandleCreate` and `HandleUpdate` add its answer as a `credType` violation, in the same set `Validate` fills, before rendering.
8. `src/OcuPilot/Test/CredentialRungOffer.cls` (new; its header names what it pins):
   - Through `DefinitionsProbe` with `SecretProbe.SetRungAvailable(0)`: `ProvidersBody` answers `false`; `CredTypeRefusal("creds")` answers the code; `CredTypeRefusal("env")` answers `""`.
   - With the rung available: `true` and `""`.
   - Over HTTP on the throwaway, `GET /agent/providers` as `_SYSTEM` answers `credentialsRungAvailable:true` in the interop install namespace.
   - Reset the probe in `OnAfterOneTest`.
   - If it declares an arming variable, add it to `ci-throwaway.sh`'s roster.
9. `ui/src/app/areas/agent/definition-form.store.ts`: read the flag, then apply every "rung absent" matrix row.
   - Default and cascade to `env`, and hold `env` for "No API key".
   - Treat `envVarName` as a rendered field in env mode.
   - Skip the credential post in `testConnection`.
   - Convert a loaded `creds` row as the matrix says.
10. `ui/src/app/areas/agent/definition-form.page.ts`: in env mode, render the "Environment variable" field, with its caption, in the key field's place. Wire its error and blur the way the other text fields are wired. Render no API-key field.
11. `ui/src/app/areas/agent/definition-form.page.spec.ts`: add the env-mode legs (create, provider change, loaded `creds` row, Test connection posting no credential). Add one leg asserting that `true`/absent is unchanged.
12. `ui/src/app/core/strings.ts` ⚠ and EXPERIENCE.md ⚠:
    - `agentDefinitionFieldEnvVar: 'Environment variable'`;
    - `agentDefinitionEnvVarCaption: 'The key is read from this variable on the instance’s host. Set it there; this form never takes the key.'`;
    - one Fixed strings row for both, naming the Definition form in env mode.
13. `README.md`:
    - Keep :31-33, and add that on plain IRIS Community the install lands in `USER`.
    - Say that a namespace that is not interoperability-enabled gets the environment-variable field instead of the API key.
    - Add smoke's default namespace at :452-457.
    - Make the CI section five jobs: a `browser` row; `instance` without the browser suite; `images` compiling, installing, drift-checking and smoking each edition.
14. `CLAUDE.md` :140: five jobs, `browser` included. The lead reports this as a footprint extension.

### Acceptance Criteria

- AC1: Given the stock `intersystems/iris-community:2026.2` image, which has no `HSCUSTOM`, when the container start path installs and CI's `images` leg for that edition runs, then readiness reports `installed` and `scripts/smoke.sh`, given no namespace, runs in `USER` and passes. The README states that install lands in `USER` there.
- AC2: Given a namespace where `CredentialsRungAvailable()` is 0, when the Definition form opens, then it offers the environment-variable rung and no API-key field, and the server refuses a `creds` definition with `AGENT.CREDTYPE.UNAVAILABLE`. On a namespace where the rung is reachable, including stock plain Community's `USER`, the form is unchanged.
- AC3: Given the plain Community leg's installed throwaway, when `admin-spec.mjs` probes `/api/admin` over HTTP and `ci-image-compile.sh` reads the version, then both are clean and the version is 2.
- AC4: Given the owner scheduled this check after the 2026-09-27 floor and accepted the late-failure risk, when it ran, then the spec records that it ran on 2026-09-23, before the floor. The risk was retired rather than realized. This is recorded under Design Notes.
- Integration (Rule 1): the Definition form, as consumer, reads `credentialsRungAvailable` from `GET /agent/providers` and renders env mode. This is pinned by the page spec against the served shape, and the flag's real value by the HTTP leg in task 8.

## Spec Change Log

### Lead rulings at the spec gate, 2026-09-23

- AC2 env mode: approved as planned (tasks 6-12).
- Spine Stack and CI rows: amended by the lead (Rule 20); the implement stage does not edit the spine.
- Plain-Community suite job: not in this story; routed as DW-1574 (range-end-cleanup).
- `CLAUDE.md` task 14: approved; the lead reports it as a footprint extension.

## Review Triage Log

## Design Notes

**Governing ADs:** AD-12, AD-17, AD-18, AD-19, AD-27, AD-35, AD-38, AD-39, AD-42, AD-45.

- AD-42 fixes the ladder, and FR-26 fixes "offered only where interoperability-enabled".
- AD-45 says there is one smoke path, so the smoke is corrected rather than bypassed with `--namespace` in CI.
- AD-27 keeps the pinned tags. The admin API is reached only through `AdminPort`, which is why the version read goes through `ci-image-compile.sh`.

### Why env mode, not merely hiding the field

FR-26 says the definition stores "the credential type and the variable or credential name", and that the operator sets the variable on the host. In a namespace without the credentials store, env is the only rung that works. A form that hid the key and offered nothing in its place would leave a user no way, through the UI, to configure an agent there. The variable's name is not a secret, and the catalog already carries a default for each provider (`defaultEnvVarName`).

### AC4, recorded

The owner scheduled this check after the floor, and accepted the risk that it would fail late with little time to react (Story 1.17's last AC, `epics.md` :1646-1650). It ran at plan time on 2026-09-23, four days before the floor. The install passed, and so did the admin API. The two defects it found are this story's tasks.

### For the lead

- **Spine, Rule 20.** Two rows are the lead's to amend:
  - the Stack row "IRIS for Health Community ... the only version tested";
  - the CI row "`images` on both stock Community editions".

  Both editions are now installed and smoked in CI.
- **The full ObjectScript suite on plain Community was measured locally, and is not in CI.** `ci-runner.mjs --namespace USER` ran on the probe throwaway from 19:44:47Z to 20:00:55Z: 205 classes and 1,798 tests, with 19 failures in 8 classes.
  - Five classes fail on test fixtures that assume the IRIS for Health layout. Each assertion text says so:
    - `ErrorDelete` and `ErrorLogDenial` need an install namespace that is not `USER`;
    - `FixtureNamespace` needs a suite namespace other than `USER`;
    - `ErrorLog` needs a code database other than `USER`'s;
    - `Namespaces` needs the `HSLIB` read-only mount.
  - Three more are `MgmntPortWire` (whose assertions name `ns=HSCUSTOM`), `MgmntPortDenial` and `TurnContext` (`TURN.CONTEXT.INVALID`). That these are the same kind is (inference).
  - None of the five reads as a product defect.
  - The probe namespace `OCUPLAIN` existed during the run.
  - Making the suite portable, and adding a plain-Community suite job (about 16 minutes beside `instance`), is the lead's call. The recommendation is to leave it out of this story.
- **Wall clock.** Before: run `35907576233` took 21m00s. The critical path was `browser` at 20m55s, beside `instance` at 18m29s; the images legs took 0m51s (plain) and 1m48s (health). The images legs are expected to grow by roughly 4-6 minutes (inference: build plus a first install plus smoke) and stay off the critical path. The lead measures after the push.

### Consumes and consumed-by

- **Consumes:** Story 3.3's ladder and `SecretProbe`/`DefinitionsProbe` seams; Story 1.4's start path and health check; Story 1.17's `images` job; Story 13.2's `admin-spec.mjs`.
- **Consumed-by:** Epic 17's clean-clone run, which relies on `smoke.sh`'s default.

## Verification

Stateful checks run on slot B's throwaway `ocupilot-b-ci` (web 52777, super 1976). The plain-Community checks run on a throwaway you bring up yourself. Every IRIS MCP call carries `server: "ocupilot-slot-b"`. Run one test class per call.

### Targeted (loop)

- `cd ui && node --test tools/ci.test.mjs`. Expected: all pass.
- `cd ui && npx ng test --include src/app/areas/agent/definition-form.page.spec.ts`. Expected: all pass.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class OcuPilot.Test.CredentialRungOffer`, then the same for `OcuPilot.Test.AgentCredential`, then for `OcuPilot.Test.Secret`. Expected: 0 failed each.
- The plain-Community path, in order:
  1. `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-community --project ocupilot-b-community --web 52780 --super 1979 --image intersystems/iris-community:2026.2`
  2. `sh scripts/wait-readiness.sh --url http://localhost:52780/api/ocupilot/readiness/`
  3. `cd ui && node tools/admin-spec.mjs --origin http://localhost:52780`
  4. `sh scripts/smoke.sh --container ocupilot-b-community --user _SYSTEM --password SYS`, with no `--namespace`
  5. `sh scripts/ci-throwaway.sh down --dir /tmp/ocupilot-b-community --project ocupilot-b-community`

  Expected: installed, clean, and a PASSED verdict.

### Once, before `dev_complete`

- The full ObjectScript sweep: `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci`, on a throwaway brought up after the last edit.
- `cd ui && npm run build && npm test`, then `uv run scripts/check-objectscript.py` and `bash scripts/lint-docs.sh`.
- The full browser suite is **not** run locally: CI's `browser` job runs it (Rule 29).

### Pinning tests (Rule 19; record `mutation: <change> → <red test>` for each)

- AC1: the ci.test smoke-stub leg "no `--namespace`, only `USER`". Mutation: restore `NAMESPACE="HSCUSTOM"` as the fallback.
- AC2 server: `CredentialRungOffer`. Mutation: make `CredTypeRefusal` answer `""` always.
- AC2 client: the page-spec env-mode create leg. Mutation: render the API-key field whatever the flag says.
- AC3: the ci.test images-shape assertion. Mutation: delete the images job's `admin-spec.mjs` step.
- CI shape: the capture-before-teardown loop. Mutation: drop the images teardown's `if: always()`.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

- **Planned.** The spec is ready for development; nothing is implemented.
- **The probe** ran on 2026-09-23, on its own throwaway `ocupilot-b-community` (52780/1979, `intersystems/iris-community:2026.2`). It was brought up and torn down by this stage.
  - Install fell back to `USER` and completed, and the container was healthy.
  - `/api/admin` answered v2 through `AdminPort.VerifyInstance`, `admin-spec.mjs` was clean, and HTTP GET answered 200.
  - Smoke passed 47 of 47 with `--namespace USER`. Without it, smoke answered "Access Denied" (defect, task 1).
  - `USER` is interoperability-enabled on the stock image. In a non-interop namespace, the Definition form still offers the API-key field (defect, tasks 6-12).
  - The full suite in `USER` recorded 19 failures in 8 classes, all read as fixture assumptions.
- **For the lead's ruling:**
  - the AC2 design, env mode in the form;
  - the two spine rows (Rule 20);
  - whether a plain-Community suite job is wanted;
  - `CLAUDE.md` as a footprint extension.

  Contended paths: `strings.ts` and EXPERIENCE.md, append only.
