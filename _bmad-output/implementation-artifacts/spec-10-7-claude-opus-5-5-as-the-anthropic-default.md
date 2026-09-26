---
title: 'Story 10.7: Claude Opus 5.5 as the Anthropic default'
type: 'feature'
created: '2026-09-25'
status: 'done'
baseline_revision: 'd8aecbd66b61bbac06bc8735b9d202025884cee0'
review_loop_iteration: 0
followup_review_recommended: false
context: []
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** The provider catalog's Anthropic row defaults a new definition to `claude-opus-5`. Anthropic has released Claude Opus 5.5 and the public demo already runs on it, so a first install should start there without the operator editing the model name.

**Approach:**

- One catalog-data edit: the Anthropic row's `defaultModel` becomes `claude-opus-5-5`, first in `modelSuggestions`.
- The tests that pin the row or its canonical default follow it. The README's provider table states it.
- New pins cover three things: a stored model is never migrated, the Definition form opens on the new default, and `claude-opus-5-5` is sent no sampling parameter.

## Boundaries & Constraints

**Always:**

- `modelSuggestions` for `anthropic` is exactly `["claude-opus-5-5","claude-opus-5","claude-sonnet-5","claude-haiku-4-5","claude-fable-5-1"]`. Every other column of every row is unchanged.
- The Catalog is the only shipped class that spells a model name. Test classes spell the shipped row's values.
- A definition that stores a model keeps it through a create that names it, an update that omits it, a production install and every migration step. No install or upgrade step reads or writes `Model`.
- No sampling parameter (`temperature`, `top_p`, `top_k`) goes to Anthropic, on any model. The rule is not keyed by model name: `Anthropic.CallMessages` never sets one (`Anthropic.cls:47-94`).
- Every edited test that a later mutation could redden gets a `mutation:` line under Verification (Rule 19).
- No live provider and no key. Do not read `.env.local`.

**Never:**

- Edit `src/OcuPilot/Kernel/Provider/Anthropic.cls`. It is contended with Epic 11's streaming work. It is touched only to apply a mutation that is reverted to byte-identical.
- Edit anything in `README.md` but the Anthropic row of the provider table (`README.md:133`). The owner has just rewritten the README.
- Add an installer step, a migration step or a `SCHEMAVERSION` bump. Edit `Installer.cls` or `Api/Definitions.cls` beyond a reverted mutation, or edit `strings.ts`, EXPERIENCE.md, the spine or `ui/src/**` beyond the two component specs' provider stubs (task 8).
- Change test data that only needs some model name. Keep each such line, with the reason given in Design Notes.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Create, no model | `POST /agent/definitions` `{provider:"anthropic",…}` without `model` | 201; `model` is `claude-opus-5-5` | — |
| Create, explicit old model | same, with `model:"claude-opus-5"` | 201; `model` is `claude-opus-5` | — |
| Update omitting model | `PUT …/:id` `{maxTokens:4000}` on that row | 200; `model` still `claude-opus-5`; `GET` reads the same | — |
| Install over a stored row | a row storing `claude-opus-5`; `Installer.Install("")`, then `RunMigrations("",0)` | the row still stores `claude-opus-5` after each | — |
| Providers read | `GET /agent/providers` | the Anthropic row reads `defaultModel` `claude-opus-5-5` and the five suggestions in order | — |
| Form on create | open `/ocupilot/agent/definitions/edit` | provider `anthropic`, model field `claude-opus-5-5`, datalist options in the order above; Save stores `claude-opus-5-5` | — |
| Model call on 5.5 | a definition on `claude-opus-5-5` holding temperature `""` or `0.7` | the recorded body has `model` `claude-opus-5-5` and no `temperature`, `top_p` or `top_k` | — |

</intent-contract>

## Code Map

- `src/OcuPilot/Kernel/Provider/Catalog.cls:66` -- the Anthropic row in XData `Providers`. The class doc (`:1-16`) and the column doc (`:20-62`) name no model, so only the row changes.
- `src/OcuPilot/Api/Definitions.cls`:
  - `HandleCreate` `:366-420` runs `MergeBody` → `ApplyCatalogDefaults` (`:1463-1476`), which fills `model` from `defaultModel` only when the body omits it (`pPresent`).
  - `HandleUpdate` `:422+` merges the body over the stored values and applies no catalog default.
  - So the default is applied on a create alone.
- `src/OcuPilot/Kernel/State/Agent.cls:41` -- `Model` has no `InitialExpression`.
- `src/OcuPilot/Install/**` -- no reference to `Kernel.State.Agent` or the catalog (grep). `Installer.MigrateToVersion1` (`:1916`) is the only migration step, and it moves no data.
- `src/OcuPilot/Kernel/Provider/Anthropic.cls:47-94` -- `CallMessages` sets `model`, `max_tokens`, `system?`, `messages` and `tools?`, and never a sampling field. The class doc (`:13-16`) says so. **Read only.**
- `ui/src/app/areas/agent/definition-form.store.ts`:
  - `:817-842` reads rows from `GET /agent/providers`.
  - `:497` applies the first row's defaults on create, and `:849` sets `model = row.defaultModel`.
  - `definition-form.page.ts:185-189` renders `#ocu-definition-models` from `modelSuggestions`.
  - The client holds no copy of the catalog.
- **Tests that pin the row or its default (change):**
  - `Test/AgentRules.cls:150`: the `AssertRowPinned("anthropic", …)` model and suggestions.
  - `Test/AgentWire.cls:107`: the omitted model takes the row's value, in `TestASoundCreateIsReturnedByTheListImmediately` over HTTP.
- `Test/AdapterSampling.cls` -- `BodyFor` (`:79-139`) stores a definition on `tRow.defaultModel` (`:94`), calls through `ProviderPortProbe` with `CatalogAnthropicStub`, and returns the recorded body. `TestAnthropicIsSentNoSamplingParameterWhateverTheDefinitionHolds` (`:202-213`) is the model to copy.
- `Test/DefinitionDefaults.cls` (114 lines) -- the home of the new legs. It is armed on `OCUPILOT_ALLOW_PRODUCTION_INSTALL` and already on `scripts/ci-throwaway.sh`'s `# classes:` roster (`:246`). `TestAStoredFlagSurvivesAnInstall` (`:88-111`) is the shape to copy, and `StoredReadOnly` (`:55-63`) is the fresh-read shape.
- `Test/AgentWire.cls:43-47` -- `Call` (public ClassMethod: an HTTP request as the suite's credentials). `Test/AgentFixture.cls:23-35` -- `CreateDefinition` stores `Model` `claude-opus-5` with the `OcuPilotProbeAgent` prefix. `RemoveProbeDefinitions` tears down.
- `ui/browser/definitions.browser-spec.mjs`:
  - Helpers: `NAMES` `:71`, `signedInAt` `:125`, `fill` `:148`, `authHeader`, `removeProbeDefinitions`.
  - The Story 10.4 leg (`:568-629`) is the shape to copy: open `FORM_URL`, save, then read back through `DEFINITIONS_PATH`.
- `README.md:131-136` -- the provider table. Only `:133` changes.

## Tasks & Acceptance

**Execution:**

1. `src/OcuPilot/Kernel/Provider/Catalog.cls:66` -- Set `defaultModel` to `claude-opus-5-5`, and `modelSuggestions` to the five-name list under Always. Change nothing else on the line.
2. `src/OcuPilot/Test/AgentRules.cls:150` -- The Anthropic `AssertRowPinned` model becomes `claude-opus-5-5`, and its suggestions become the five-name JSON.
3. `src/OcuPilot/Test/AgentWire.cls:107` -- Expect `claude-opus-5-5`. Its message is unchanged.
4. `src/OcuPilot/Test/DefinitionDefaults.cls` -- Add three methods. The class keeps its arming, teardown and `OcuPilotProbeAgent` prefix, and every new name uses that prefix.
   - **Header.** The class doc's first sentence also names the model: a new Anthropic definition's model, and a stored model surviving an install.
   - **Method: the default.** `TestAnOmittedAnthropicModelIsClaudeOpus55` makes a `POST` without `model` through `##class(OcuPilot.Test.AgentWire).Call` and expects 201 with `model` `claude-opus-5-5`.
   - **Method: an explicit model is kept.** `TestAnExplicitModelIsKeptThroughACreateAndAnUpdate` follows the Matrix rows for an explicit create, an update that omits the model, and a `GET`.
   - **Method: the install.** `TestAStoredModelSurvivesAnInstallAndEveryMigration`:
     - Create the row through `AgentFixture.CreateDefinition`, and assert first that it stores `claude-opus-5` ("the probe stores the former default").
     - Run `Installer.Install("")` and assert the model is unchanged.
     - Run `Installer.RunMigrations("", 0, .tReports)` and assert it again.
     - Read the stored model through a fresh `GuardedOpenId` each time, holding no reference (the `%OpenId` rule).
5. `src/OcuPilot/Test/AdapterSampling.cls`:
   - `BodyFor` gains a trailing `pModel As %String = ""`. When it is non-empty, the definition stores that model instead of the row's.
   - Add `TestClaudeOpus55IsSentNoSamplingParameter`. For each model (`claude-opus-5-5`, `claude-opus-5`) and each held temperature (`""`, `..#SETTEMPERATURE`):
     - the recorded body's `model` equals that model;
     - and it carries no `temperature`, `top_p` or `top_k`.
   - The first assertion proves each leg ran on the named model.
6. `ui/browser/definitions.browser-spec.mjs`:
   - Append `${PREFIX}Opus` to `NAMES`. Add one entry to the header's claim list.
   - Add `test('Story 10.7: a new definition opens on claude-opus-5-5, first of the suggestions, and saves it', …)`. It follows the Matrix row "Form on create": read the provider `select` value, the `#ocu-definition-model` value and the `#ocu-definition-models option` values in order. Then fill the name, Save, wait for `STRINGS.formSavedPendingTest`, and read the definition back over HTTP (`model` `claude-opus-5-5`).
7. `README.md:133` -- `` `claude-opus-5` `` becomes `` `claude-opus-5-5` ``. Change no other byte of the file.
8. `ui/src/app/app.routes.guard.wire.spec.ts:57-58` and `ui/src/app/areas/agent/definition-form.page.spec.ts:27-28` -- in each `PROVIDERS_BODY` Anthropic stub, `defaultModel` becomes `'claude-opus-5-5'` and `modelSuggestions` becomes `['claude-opus-5-5', 'claude-sonnet-5']`. Nothing else in either file changes; the stored-definition `model: 'claude-opus-5'` lines stay.

**Acceptance Criteria:**

- **AC1.** Given the catalog's Anthropic row, when a new Anthropic definition is created without a model, through `POST` or through the Definition form, then its model is `claude-opus-5-5`, and the row's suggestions list `claude-opus-5-5` first, then `claude-opus-5`, `claude-sonnet-5`, `claude-haiku-4-5` and `claude-fable-5-1` (tasks 1, 2, 3, 4, 6).
- **AC2.** Given a definition that stores `claude-opus-5`, when it is updated without a model, or a production install and every migration step run, then it still stores `claude-opus-5` (task 4).
- **AC3.** Given Story 10.4's rule, when a definition on `claude-opus-5-5` calls the model, then the body carries no `temperature`, `top_p` or `top_k`, exactly as on `claude-opus-5` (task 5).
- **AC4.** Given the tests and fixtures that pin the Anthropic row or its canonical default, when this story completes, then they name `claude-opus-5-5`, every kept `claude-opus-5` has its reason in Design Notes, and README's provider table states the new default (tasks 2, 3, 7, 8).

## Spec Change Log

- 2026-09-26, spec gate (runner): task 8 added. The owner's triage names the UI specs that mirror the Anthropic row, so the two `PROVIDERS_BODY` stubs follow it; the Never line and the pin census were amended to match.

## Review Triage Log

### 2026-09-26 — Review pass

- verdicts: 8 findings — high 0, medium 0, low 6, false 2, maybe-false 0
- findings:
  - `[low]` `[patch]` AC4 has no `mutation:` line, and the task-8 stubs are read by no component assertion (verification-gap) — added the AC4 line under Verification naming its executable pins and the observed AC1 runs; the stubs stay mirror data, the form's default being pinned by the browser 10.7 leg.
  - `[low]` `[reject]` The pin census cites `_bmad/custom/epic-dependencies.yaml:135`; the regex hit is `:7` (verification-gap) — true (`git grep -nP`), a keep row either way; the fix is a spec edit, which this pass rejects.
  - `[false]` `[reject]` `GET /agent/providers` values are pinned at no HTTP test (intent-alignment) — the form fills model and datalist from that route and holds no catalog copy, so the browser 10.7 leg observes the route's values; the suggestion-swap mutation reddened it.
  - `[low]` `[reject]` The install leg cannot see a step that only reads `Model` or rewrites the same value (intent-alignment) — neither changes a stored model, so no user-visible outcome; guarding it would need new instrumentation.
  - `[low]` `[reject]` "The Catalog is the only shipped class that spells a model name" is held by a one-time census, not a test (intent-alignment) — pre-existing invariant the diff keeps; a lint is new surface for a theoretical drift.
  - `[low]` `[reject]` No-sampling is tested on two models, not every model (intent-alignment) — `Anthropic.CallMessages` has no model branch; the matrix names 5.5, and a keyed branch would show in review of that file.
  - `[low]` `[patch]` Task 8 stubs change and no component assertion reads them (intent-alignment) — grouped with the first row, same root cause and same fix.
  - `[false]` `[reject]` The install leg's precondition comes from the fixture's literal (intent-alignment) — the leg asserts "the probe stores the former default" first, so a fixture change fails loudly rather than passing.

## Design Notes

**Governing ADs.**

- **AD-42.** The fixed provider contract: one base, four adapters, Anthropic's message shape canonical. This story changes a catalog row, not the contract, and the no-sampling rule lives in the adapter unkeyed by model.
- **AD-17.** Install is guard-then-act and idempotent, and it never touches OcuPilot's agent definitions.
- **AD-38.** The migration registry gains no step.
- **AD-35.** No key is read. The sampling leg runs through `SecretProbe` and a stub transport.
- **Spine.** No AD, Convention or Stack row names a model (grep), so the spine is not edited.

**The pin census.** It comes from `git grep -P 'claude-opus-5(?!-5)'` over the whole repository, `_bmad-output` excluded.

| Hit | Kind | Action | Reason |
|---|---|---|---|
| `Kernel/Provider/Catalog.cls:66` | the row | change | the source of truth |
| `Test/AgentRules.cls:150` | (a) | change | pins the row column by column |
| `Test/AgentWire.cls:107` | (a) | change | pins the canonical default through `POST` |
| `README.md:133` | (a) | change | the provider table states the default |
| `Test/AgentFixture.cls:28` | (b) | keep | a probe's stored model. The new install leg relies on it being the former default, and asserts that first. |
| `Test/AgentRules.cls:47` | (b) | keep | `SoundValues`, a submission every rule accepts; any model does |
| `Test/AgentWire.cls:233,241,249,260` | (b) | keep | a change record's old value beside `claude-sonnet-5` |
| `Test/AgentWireSecurity.cls:246` | (b) | keep | reads back `AgentFixture`'s stored model after a refused `PUT` |
| `Test/AgentConnection.cls:700`, `Test/AgentState.cls:441`, `Test/DefinitionsFaults.cls:79` | (b) | keep | stored models of credential and handler probes; the stubs never read them |
| `ui/src/app/app.routes.guard.wire.spec.ts:57-58` | (a) | change | the `PROVIDERS_BODY` Anthropic stub mirrors the providers response's Anthropic row; the owner's triage names these UI specs, so its `defaultModel` and first suggestion follow the row (lead amendment at the spec gate) |
| `ui/src/app/areas/agent/definition-form.page.spec.ts:27-28` | (a) | change | the same stub, the same reason |
| `ui/src/app/app.routes.guard.wire.spec.ts:232`, `ui/src/app/areas/agent/definition-form.page.spec.ts:195` | (b) | keep | a stored definition's model: a stored `claude-opus-5` staying put is exactly AC2's rule |
| `_bmad/custom/epic-dependencies.yaml:135` | — | keep | orchestration prose, not a pin |

`AdapterSampling:94` and `ProviderSampling:206` read `tRow.defaultModel` rather than spelling it, so they follow the row with no edit.

**Where the new legs go.**

- `DefinitionDefaults` already runs a production install over stored definitions, and it is already armed and on the arming roster.
- A new armed class would have to be added to that roster in `scripts/ci-throwaway.sh`, and `origin/OCU-1-epic11` edits that file.
- `AgentWire.cls` is already 662 lines.

**Footprint extension:** `src/OcuPilot/Test/DefinitionDefaults.cls` is outside Epic 10's `paths_hint`. Epics 11 and 12 claim it only through their `src/OcuPilot/Test/**` wildcard, and no in-flight branch edits it (`git diff` against `origin/OCU-1-epic11`, 2026-09-25).

**Integration ACs.** Catalog data only: no new service, module or shared component. The existing consumers are pinned at their surfaces: `Api/Definitions` over HTTP (tasks 3 and 4), the Definition form in a browser (task 6), and `ProviderPort` → `Anthropic` through the stub transport (task 5).

**Consumes:**

- Story 10.2: the catalog as the source of default models.
- Story 10.4: no sampling to Anthropic, and `AdapterSampling`.
- Story 3.5: the Definition form.
- The installer: `Installer.Install` and `RunMigrations` (the precedent is `DefinitionDefaults`).

**Consumed-by:**

- Story 17.7: the owner's live check on each catalog default model.

**Ledger inbox:** none.

## Verification

**Slot and instance.**

- Slot B. Every IRIS MCP call carries `server: "ocupilot-slot-b"`.
- Every stateful check runs on the throwaway `ocupilot-b-ci` (web 52777, super 1976):
  - This includes the production install in `DefinitionDefaults`, the browser leg and the smoke.
  - Bring it up with `sh scripts/ci-throwaway.sh up --dir /tmp/ocupilot-b-ci --project ocupilot-b-ci --web 52777 --super 1976` if it is not already running.
  - Tear down only a throwaway this stage started.
- Never touch `ocupilot`, any `ocupilot-slot-*` container, or `ocupilot-ci`.
- No live provider, and no key.

**Loading code.**

- `cp -R src/. /tmp/ocupilot-b-ci/src/`
- Then, in `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM`: `$System.OBJ.LoadDir("/opt/ocupilot/src/OcuPilot","ck",,1)` and `$System.OBJ.CompilePackage("OcuPilot","ck")`.

**Commands:**

- `uv run scripts/check-objectscript.py && uv run scripts/test_check_objectscript.py` -- expected: 0 problems.
- `bash scripts/lint-docs.sh` -- expected: clean.
- **(loop)** `cd ui && node tools/ci-runner.mjs --container ocupilot-b-ci --class <Class>`:
  - One class per invocation, one invocation per message, never re-submitted after a client-side timeout.
  - Confirm the totals with the `%UnitTest_Result` probe.
  - Classes: `OcuPilot.Test.AgentRules`, `OcuPilot.Test.AgentWire`, `OcuPilot.Test.DefinitionDefaults` (armed; the throwaway arms it), `OcuPilot.Test.AdapterSampling`, `OcuPilot.Test.ProviderSampling`, `OcuPilot.Test.AgentViolation`.
  - expected: 0 failed.
- **(loop)** Build and redeploy, then run the spec:
  - `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`
  - `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/definitions.browser-spec.mjs`
  - expected: every test passes.
- **(loop)** `cd ui && npm run test:tools` -- expected: green. No client source changes; `test:components` runs because task 8 edits two component specs -- expected: green, both specs included.
- **(once, before dev_complete)** The full ObjectScript sweep: every `%UnitTest.TestCase` under `src/OcuPilot/Test`, one class at a time on `ocupilot-b-ci`.
  - Then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS`. Zero executed checks is a failure.
  - The full browser suite is CI's `browser` job (Rule 29).

**Pinning mutations (Rule 19).** For each: apply it, recompile (or rebuild and redeploy for the browser), observe red, revert, and confirm `git status --short` and `git diff --stat` are unchanged. Record each result beside its line.

- **AC1, the default.** Set `defaultModel` back to `claude-opus-5` in `Catalog.cls:66` → red: `AgentRules.TestTheShippedProviderRowsArePinned`, `AgentWire.TestASoundCreateIsReturnedByTheListImmediately`, `DefinitionDefaults.TestAnOmittedAnthropicModelIsClaudeOpus55`, and the browser 10.7 leg.
  - mutation: `defaultModel` `claude-opus-5` → red: AgentRules run 7 (`TestTheShippedProviderRowsArePinned`), AgentWire run 8 (`TestASoundCreateIsReturnedByTheListImmediately`), DefinitionDefaults run 9 (`TestAnOmittedAnthropicModelIsClaudeOpus55`), browser 10.7 leg (model field `claude-opus-5`); reverted byte-identical.
- **AC1, the order.** Swap the first two suggestions → red: `AgentRules` suggestions, and the browser datalist assertion.
  - mutation: suggestions `claude-opus-5`,`claude-opus-5-5`,… → red: AgentRules run 10 ("anthropic: the suggestion list…" alone), browser 10.7 leg ("the suggestions in the catalog order"); reverted byte-identical.
- **AC2, an explicit create.** Drop `If $Get(pPresent(tField)) Continue` in `Definitions.ApplyCatalogDefaults` → red: `TestAnExplicitModelIsKeptThroughACreateAndAnUpdate` (the create answers `claude-opus-5-5`).
  - mutation: `Continue` line removed → red: DefinitionDefaults run 11, `TestAnExplicitModelIsKeptThroughACreateAndAnUpdate` (create, update, read and stored-model assertions); reverted byte-identical.
- **AC2, an update.** In `HandleUpdate`, call `..ApplyCatalogDefaults(.tValues, .tPresent)` after `MergeBody` → red: the same method's `PUT` leg.
  - mutation: `ApplyCatalogDefaults` after `HandleUpdate`'s `MergeBody` → red: DefinitionDefaults run 12, the same method's `PUT`, `GET` and stored-model assertions, the create leg green; reverted byte-identical.
- **AC2, migrations.** In `Installer.MigrateToVersion1`, set every `anthropic` definition's `Model` to the catalog's `defaultModel` → red: `TestAStoredModelSurvivesAnInstallAndEveryMigration`, the migrations assertion.
  - mutation: an SQL `UPDATE … SET Model = <row defaultModel> WHERE Provider = 'anthropic'` in `MigrateToVersion1` → red: DefinitionDefaults run 13, "and unchanged by the migrations" alone; reverted byte-identical.
- **AC2, the install.** Make the same rewrite at a point in `Install` where the install namespace is current, and record where → red: the post-install assertion.
  - mutation: the same `UPDATE` in `Install` right after `ReadApplicationProvenance` (`Installer.cls:806`, install namespace current) → red: DefinitionDefaults run 14, "unchanged by the install" (and the migrations assertion after it); reverted byte-identical.
- **AC3.** In `Anthropic.CallMessages`, add `If $Get(pValues("model")) = "claude-opus-5-5" Do tBody.%Set("temperature", 1, "number")` → red: `TestClaudeOpus55IsSentNoSamplingParameter` on the 5-5 legs only. Revert, then `git diff --quiet -- src/OcuPilot/Kernel/Provider/Anthropic.cls`, because that file is contended.
  - mutation: as written → red: AdapterSampling run 15, `TestClaudeOpus55IsSentNoSamplingParameter` on the two `claude-opus-5-5` legs only (the `claude-opus-5` legs green), plus `TestAnthropicIsSentNoSamplingParameterWhateverTheDefinitionHolds` and `TestEachRowsColumnAgreesWithWhatItsAdapterSends`, which store the row's default; reverted, `git diff --quiet` on `Anthropic.cls` exits 0, package recompiled, AdapterSampling green again.
- **AC4.** Its executable pins are `AgentRules.cls:150` and `AgentWire.cls:107`, reddened by AC1's default mutation. The README row and the two `PROVIDERS_BODY` stubs are mirror data that no test reads; the form's observable default is the browser 10.7 leg.
  - mutation: `defaultModel` `claude-opus-5` in `Catalog.cls:66` → red: AgentRules run 7 (`TestTheShippedProviderRowsArePinned`), AgentWire run 8 (`TestASoundCreateIsReturnedByTheListImmediately`); the same applied mutation as AC1's first line, reverted byte-identical.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** The catalog's Anthropic row defaults to `claude-opus-5-5`, first of five suggestions; the pins, README row and component stubs follow; new legs pin the default over HTTP and in the form, a stored model through create, update, install and migrations, and no sampling on 5.5.

**Files.**

- `src/OcuPilot/Kernel/Provider/Catalog.cls` -- the Anthropic row's `defaultModel` and `modelSuggestions`.
- `src/OcuPilot/Test/AgentRules.cls`, `src/OcuPilot/Test/AgentWire.cls` -- the row pin and the canonical-default pin.
- `src/OcuPilot/Test/DefinitionDefaults.cls` -- `StoredModel` and three legs (AC1, AC2).
- `src/OcuPilot/Test/AdapterSampling.cls` -- `BodyFor(..., pModel)` and `TestClaudeOpus55IsSentNoSamplingParameter` (AC3).
- `ui/browser/definitions.browser-spec.mjs` -- the Story 10.7 form leg.
- `ui/src/app/app.routes.guard.wire.spec.ts`, `ui/src/app/areas/agent/definition-form.page.spec.ts` -- the `PROVIDERS_BODY` Anthropic stubs.
- `README.md` -- line 133 only.

**Review.** Two layers (verification-gap, intent-alignment), 8 findings: 1 patch entry (low; the AC4 `mutation:` line added), 5 rejected (see the triage log), 0 deferred. Patched by verdict: high 0, medium 0, low 1. `followup_review_recommended: false`.

**Verification.**

- `check-objectscript.py` 0 problems; `test_check_objectscript.py` 130 OK; `lint-docs.sh` clean.
- `npm run test:tools` 1426/1426; `npm run test:components` 1377/1377 (106 files); `npm run build` main 1.65 MB raw, bundle unchanged (no client source edited).
- Browser `definitions.browser-spec.mjs` on `ocupilot-b-ci` after rebuild and redeploy: 9/9.
- Targeted classes (handoff, one per run): AgentRules 20, AgentWire 17, DefinitionDefaults 5, AdapterSampling 6, ProviderSampling 7, AgentViolation 8 -- 0 failed.
- Full ObjectScript sweep on `ocupilot-b-ci` (`ci-runner.mjs`, serialized): 286 classes, 2398 methods, 2398 passed, 0 failed; `%UnitTest_Result` latest-run probe agrees (286 / 2398 / 2398 / 0).
- Smoke `smoke.sh --container ocupilot-b-ci`: executed 49, passed 49, failed 0.
- Rule 19: seven mutations applied, red observed, reverted byte-identical; `git diff --quiet -- src/OcuPilot/Kernel/Provider/Anthropic.cls` exits 0 and the package was recompiled on the throwaway.

**Residual risk.** The census row for `_bmad/custom/epic-dependencies.yaml` cites `:135`; the hit is `:7` (a keep row either way). The browser spec header still reads "Three claims" above seven items, as before this story.
