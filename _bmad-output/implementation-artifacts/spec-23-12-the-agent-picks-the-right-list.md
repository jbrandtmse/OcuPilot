---
title: 'Story 23.12: The agent picks the right list'
type: 'feature'
created: '2026-10-23'
status: 'done'
baseline_revision: 'eed218eced7ac6bd8d40a553811dde5e39558f61'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred:
  - summary: >-
      Two read tools' descriptions (osmgmt.dashboard at 1,143 characters, osmgmt.ecpstatistics at 1,030) exceed 1,024 characters, which a provider may refuse in a tool definition.
    evidence: |-
      Measured on ocupilot-ci: both exceed 1,024, and three existing editor save tools already do (interop_processeditor_save 1,505, interop_ruleeditor_save 1,463, interop_transformeditor_save 1,516); neither OpenAI nor Gemini adapter caps a description. An OpenAI limit of 1,024 comes from third-party reports, not its API reference (inference). Settle with one live OpenAI request carrying a description over 1,024 characters (owner-approved key).
    location: >-
      src/OcuPilot/Kernel/Provider/ToolDefAdapter.cls:117
    severity: medium (unverified)
---

<intent-contract>

## Intent

**Problem:** On the 1.0.13 demo, `claude-haiku-5-5` answered "Which tasks are suspended?" with "nothing is suspended" three times out of three while three tasks were suspended. Every read tool's description is one templated sentence naming a screen key, so the model read the empty background-jobs list and claimed the other task lists carry no status, and nothing in the built-in prompt stops a "none" after one list.

**Approach:** Build every read tool's description from declarations: the screen's title (generated onto the instance from `strings.ts`), a declared row phrase, and the fields the read returns (the executor's own projection), plus a declared label on lists a model can confuse. Add three short rules to the built-in prompt. Measure the token cost and run a ten-question live evaluation on `claude-haiku-5-5` before and after.

## Boundaries & Constraints

**Always:**

- The field list is the read's answered fields, `read.fields` minus `context.secretFields`, from the one helper the executor also uses. No descriptor or test writes it as a literal.
- The title is the value of the descriptor's `labelKey` in `ui/src/app/core/strings.ts`. It reaches the instance only through the generated `src/OcuPilot/Screen/Titles.cls` and is never typed on the instance.
- Row phrases and labels are declarations on the descriptor's `read` (`row`, `label`), read only by the tool's description; no page renders them. A label names a neighbouring list by its tool identifier (`tasks.history`), never by a copied title.
- Descriptions are built from compile-time declarations only and are deterministic (AD-5). The prompt stays a build-time constant, never joined to runtime text (AD-11).
- Source text is ASCII, non-ASCII as `\uXXXX` (Rule 14). Comments state contracts only.
- Every live call uses `claude-haiku-5-5`. The key in `/Users/jbrandt/git/OcuPilot/.env.local` is read at the point of use and never printed, logged, written to a file, ledgered or committed. CI stays stub-based.

**Never:**

- Change which tools a turn starts with, `shell.tools.find`'s scoring, or Story 18.45's scoping (`Loop.Scope`, `Context.ScreenTools`).
- Change a write tool's description, stored data, the installer, `module.xml`, compose or the container start script. Add no `Kernel/Governance/Baseline.cls` key and no tool.
- Append a rule or label to a definition's `systemPromptOverride`.
- Put ObjectScript source outside `src/OcuPilot/`: the harness pipes its session statements from `eval.mjs`.
- Start, stop or recreate `ocupilot`, an `ocupilot-slot-*` container or `iris-community-edition`.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Descriptor read | `tasks.schedule.read` in the listing | "Read the rows of the Task schedule screen (tasks.schedule), one scheduled task per row, bounded and with secret fields removed. <its label> Fields: Name, Type, Namespace, Description, Id, LastFinished, NextScheduled, Suspended." | No error expected |
| Secret field | `osmgmt.licensekey.read` | `Fields:` omits `AuthorizationKey` (AD-35) | No error expected |
| Note | `explorer.sqltablestatements.read` | head, label, `Fields:`, then the note, last | No error expected |
| Outside every group | `permissions.users.read` | head and `Fields:` only, no label | No error expected |
| Class tool in a group | `logs.applicationerrors.read` | title "Application errors", "one application error per row", label, `Fields: errorNumber, time, errorText, routine, line.`, then its namespace-and-date sentence | No error expected |
| Fixture descriptor | a test registry's descriptor whose `labelKey` has no generated title, or no `row` | "Read the rows of the <identifier> screen", and no row clause | Never an error |
| Bad grammar | `row` not a string, empty or over 40 characters; `label` not a string, empty or over 240 characters | `Screen/Registry.cls` and `screen-mirror.mjs` refuse with the same sentence | Install-time refusal, as `read.note`'s |
| Discovery (integration) | `shell.tools.find` "suspended tasks", limit 20, on `ocupilot-ci` | a row `tasks_schedule_read` whose description equals the registry's and names `Suspended` | No error expected |
| Override | a definition with `systemPromptOverride` | the override is sent whole, with no rules appended (AD-11) | No error expected |
| Stale titles | a title changed in `strings.ts`, `Titles.cls` not regenerated | `node tools/screen-mirror.mjs --check` exits 1 (prebuild, pre-commit hook, CI `gates`) | Regenerate |

</intent-contract>

## Code Map

Measured from the tree (`ui/tools/screen-mirror.mjs` `readSources`, `loadStrings`): 209 descriptors, 157 declare a read. Every `labelKey` has a string. 129 of the 157 declare no `entityLabelKey`, so the row phrase is a new declaration, not that key.

- `src/OcuPilot/Screen/Tool/Read.cls:24` `DESCRIPTION` and `:47-57` `Description` build today's sentence and append `read.note`'s text. `:262` passes the executor's `fields` through.
- `src/OcuPilot/Screen/Read.cls:775-780` projects `read.fields` minus `ContextSecretFields`, and `:799` is the only place `fields` is set. Every source kind converges here, including the `rowGet` merge at `:1355-1424`.
- `src/OcuPilot/Screen/Descriptor/Base.cls`: accessors `Read()` `:148`, `LabelKey()` `:184`, `ContextSecretFields()` `:310`, `ToolIdentifier()` `:516`.
- `src/OcuPilot/Screen/Registry.cls`: `ReadNoteProblem` `:1073-1095` (the sibling to extend), the read's allowed keys `:1174`, its call `:1607`.
- `ui/tools/screen-mirror.mjs`:
  - `readNoteProblem` `:1329-1347`, the read's allowed keys `:1386`, its call `:1748`.
  - The mirror copies `read` verbatim (`:3540`); `ReadDeclaration` is at `:3835-3845`.
  - `MIRROR_PATH` `:54`, header, `generate`, `main` and `--check` at `:4050-4102`.
  - It does not read `strings.ts` today: `ui/tools/strings.mjs:48` `loadStrings` does.
- `ui/tools/field-lists.mjs:376-478`: the GENERATED ObjectScript header, writer and `--check` idiom for `src/OcuPilot/Screen/Tool/ToolFields.cls`. `Screen/Tool/Write.cls:672` reads that XData with `%Dictionary.XDataDefinition`.
- `src/OcuPilot/Test/ReadSourceCorpus.cls`: note cases `:167-174`, `DeclarationFor` `:207-224`. Its runners are `Test/ReadTool.cls:255` and `ui/tools/screen-mirror.test.mjs:771` (applies note at `:786`). `screen-mirror.test.mjs:201-232` pins the 12 notes against `strings.ts`.
- `src/OcuPilot/Screen/Tool/ErrorRead.cls`: the class tool for `logs.applicationerrors.read`. `DESCRIPTION` `:36`, `DESCRIPTORCLASS` `LogErrorList` `:41`, `SUMMARYFIELDS` `:53`. `Registry.DescriptionOf` (`Screen/Tool/Registry.cls:498-501`) calls a tool class's `Description`.
- `src/OcuPilot/Screen/Tool/ToolsFind.cls:193-206`: scoring, 2 for a name word and 1 for a description word. Rows are `{name, description}`, cut by AD-24's 1,000-character field bound.
- `src/OcuPilot/Kernel/Agent/Prompt.cls:7-24`: `BUILTIN` and the doc comment that counts its sentence groups. `Port/ProviderPort.cls:153-159` `SystemPromptFor` sends an override whole and never both. `Kernel/Agent/Loop.cls:320` is `Builtin()`'s only caller.
- Where descriptions reach a person:
  - `Kernel/Agent/Loop.cls:777-782` stores a step's result text, and `Kernel/State/Step.cls:171-197` cuts it at 4,096 characters.
  - `ui/src/app/shell/tool-call-card.ts:65-68,147-150` shows it in an expanded card, live and on `ui/src/app/areas/agent/transcript.page.ts:75-76`. So a `shell.tools.find` step shows the descriptions it found.
- Tests on the shared surfaces: see `## Verification`.
- Harness seams:
  - `Api/Turn.cls:12-25,47` (POST `/turn` `{message, conversationId}`, no definition id) and `:216` (progress).
  - `Kernel/State/Turn.cls:608-687` (progress: `state`, `tokens{input,output}`, `steps`, `reply`, `error`).
  - `Api/Definitions.cls`: `:112-114` fields, `:367` create, `:618` credential, `:779` test, `:428` update, `:505` delete. `Api/Preferences.cls:27-56` holds the user's `agentDefinition` pick.
  - `ui/browser/turnprobe-spec.mjs:53` (`runIris`) and `:271-276` (Basic-auth `fetch`).
  - Seeds: `Install/Fixture.cls:528-600` (demo task), `Test/RemoteDatabaseProbe.cls:79,104`, `Test/BackgroundSeed.cls:61,379`, `Test/ErrorLogSeed.cls:61`, `Test/TaskResume.cls:533`, `Test/Demo.cls:386`.
  - Measurement:
    - `Test/TurnProvider.cls:8-12,150`, the armed stub's recorded calls.
    - `Kernel/Provider/ToolDefAdapter.cls:107,137`, `MessageAdapter` `CanonicalToOpenAi` and `CanonicalToGemini`, and `Kernel/Provider/Anthropic.cls` `CallMessages` (tools `:103-114`).
    - `Test/TurnScope.cls:214-256`.

## Tasks & Acceptance

**Execution:**

- [ ] **Task 0, for the lead, before any code change.** On `ocupilot-ci`, brought up under this run from the current tree, healthy:
  - (a) the token cost "before";
  - (b) the live evaluation "before".

  Both follow Design Notes, Token cost and Live evaluation. The harness and its records go in `_bmad-output/implementation-artifacts/23-12-eval/`.
- [ ] `ui/tools/screen-mirror.mjs`:
  - (a) `readProblem` admits `row` and `label`, and a new `readRowLabelProblem` beside `readNoteProblem` returns the sentences in the matrix: each optional; otherwise a non-empty string, `row` at most 40 characters, `label` at most 240.
  - (b) `generate`, `main` and `--check` also write and check `src/OcuPilot/Screen/Titles.cls`. It is GENERATED, `Class OcuPilot.Screen.Titles Extends %RegisteredObject` with `XData Titles` `{<labelKey>: <its strings.ts value>}` over every descriptor's `labelKey`. Keys are sorted, non-ASCII is written `\uXXXX`, and a key with no string throws. Use `loadStrings` and the header and writer idiom of `field-lists.mjs`.
  - (c) `ReadDeclaration` gains `readonly row?: string` and `readonly label?: string`: tool-only, no page renders them.
- [ ] `src/OcuPilot/Screen/Titles.cls` (new, generated) and `ui/src/app/core/screens.generated.ts` (regenerated): run `cd ui && node tools/screen-mirror.mjs` and never hand-edit either.
- [ ] `ui/src/app/core/strings.ts`: one header line saying that the descriptors' `labelKey` values are also generated into `src/OcuPilot/Screen/Titles.cls` for the read tools' descriptions. No value changes.
- [ ] `src/OcuPilot/Screen/Registry.cls`: the read's allowed keys gain `row` and `label`, and `ReadRowLabelProblem` beside `ReadNoteProblem` returns the mirror's sentences.
- [ ] `src/OcuPilot/Test/ReadSourceCorpus.cls` and `ui/tools/screen-mirror.test.mjs`:
  - Corpus cases for a sound `row` and `label`, each absent, `null`, a number, empty, and over its length.
  - Both `DeclarationFor`s apply a case's `row` and `label` as they apply `note`.
  - A mirror test that `buildTitles` maps every descriptor `labelKey` to its `strings.ts` value and throws on a missing one.
- [ ] `src/OcuPilot/Screen/Read.cls`: `ClassMethod AnsweredFields(pDescriptor) As %DynamicArray`, lifted from `:775-780`. `Execute` calls it, with no behavior change.
- [ ] `src/OcuPilot/Screen/Tool/Read.cls`:
  - `Title(pDescriptor)` reads `OcuPilot.Screen.Titles`'s XData as `Write.cls:672` reads ToolFields, and answers `""` for a key it lacks.
  - `Compose(pTitle, pIdentifier, pRow, pFields As %DynamicArray, pLabel, pNote)` builds the template in Design Notes.
  - `Description` returns `Compose(Title(D), ToolIdentifier, read.row, Screen.Read.AnsweredFields(D), read.label, read.note.text)`.
  - `DESCRIPTION` and the doc comments say what the description now holds.
- [ ] `src/OcuPilot/Screen/Tool/ErrorRead.cls`:
  - `Parameter ROW = "application error"` and `Parameter LABEL` from the Labels table.
  - `DESCRIPTION` becomes its closing sentence: "It reads one namespace and one date at a time, each exactly as this instance lists them; the captured variable table is never returned."
  - `Description` returns `Read.Compose(Read.Title(DESCRIPTORCLASS), "logs.applicationerrors", ROW, SUMMARYFIELDS as an array, LABEL, DESCRIPTION)`.
- [ ] `src/OcuPilot/Screen/Descriptor/*.cls`, the 157 that declare a read:
  - `read.row` on every one, following the row rule in Design Notes.
  - `read.label` and the table's `row` on the 35 descriptor tools in the Labels table.
  - Nothing else in any descriptor changes.
- [ ] `src/OcuPilot/Kernel/Agent/Prompt.cls`: insert the three rules (Design Notes) after "...say so rather than describe a capability you lack.", and update the doc comment's sentence-group count. Every other sentence stays byte-identical.
- [ ] `src/OcuPilot/Test/ReadDescriptions.cls` (new; it pins and needs only the production registry, and no arming). Tests:
  - `TestEveryReadToolNamesItsTitleRowAndFields`
  - `TestEveryConfusableToolCarriesItsLabel` (literal `XData Groups` roster)
  - `TestTheDiscoveryAnswerCarriesTheDescription`
  - `TestThePromptCarriesTheListRules`
- [ ] Shared-surface sweep (Rule 30): update every test that asserts the old shape.
  - `Test/ExplorerDescriptor.cls:392-412` keeps its intent (the three statements tools end with their note, and the table tool carries none), asserted on the composed text, never the old literal.
  - Each file the sweep changes joins the `(loop)` set.
- [ ] **Task Z, for the lead, after code review.** The "after" token measurement and the "after" live evaluation, on `ocupilot-ci` with this story's code loaded. Same harness, questions and cap.

**Acceptance Criteria:**

- **AC1.** Given any descriptor-declared read tool, or `logs.applicationerrors.read`, in the production listing, when its description is built, then it holds:
  - the screen's title from `Titles.cls`;
  - "one <row> per row";
  - `Fields:` followed by exactly `Screen.Read.AnsweredFields`, so no secret field appears;
  - its `read.note` text, last.
- **AC2.** Given each tool in the Labels table, when its description is built, then it carries its declared label. Every tool identifier a label names is an advertised read tool. No tool outside the table declares a label.
- **AC3.** Given `Prompt.Builtin()`, when a turn runs with no override, then it carries the three rules verbatim, once each, as printable ASCII. A definition's override is sent whole without them.
- **AC4.** Given the first request of a no-screen turn and of a `tasks/schedule` turn, when measured before and after, then the growth stays within the bound table in Design Notes. The 18.45 starting sets are unchanged.
- **AC5.** Given the ten questions on `claude-haiku-5-5` against the seeded `ocupilot-ci`, when they run before and after, then every answer is scored, the after run answers all ten right, both sheets and `eval.mjs` sit in `23-12-eval/`, and the spend stays under the cap.
- **AC6.** Given `ReadDescriptions`, when the field list is removed from `tasks.schedule.read`'s description, then `TestEveryReadToolNamesItsTitleRowAndFields` is red. The same holds for a label removed (AC2 test) and a rule removed (AC3 test).
- **AC7 (integration).** Given `shell.tools.find` on `ocupilot-ci`, when queried "suspended tasks" with limit 20, then the `tasks_schedule_read` row carries the registry's composed description.
- **AC8.** Given the story's diff, when the lead checks the upgrade triggers, then none is touched.

## Spec Change Log

- 2026-10-23, lead spec gate: visible text accepted (veto U-13); AD-5 and AD-36 notes ruled by the orchestrator: no spine edit in this run, lines kept for the owner's Update; status `ready-for-dev`.

## Review Triage Log

### 2026-10-23 -- Review pass

- verdicts: 18 findings -- high 0, medium 1, low 3, false 13, maybe-false 1
- findings:
  - `[maybe-false]` `[defer]` Descriptions over 1,024 characters (`osmgmt.dashboard` 1,143, `osmgmt.ecpstatistics` 1,030) may be refused by OpenAI -- the two lengths and the absent cap are measured; the limit is only in third-party reports, and three existing editor save tools (1,463 to 1,516) already carry the same exposure; settle with one live OpenAI request; deferred as medium (unverified).
  - `[medium]` `[patch]` The title leg of `TestEveryReadToolNamesItsTitleRowAndFields` used `Read.Title` as its own oracle -- confirmed by reading it; patched with `GeneratedTitles` (the compiled XData read independently) and two assertions, mutation line written.
  - `[low]` `[reject]` Five labels state a default window in prose with nothing tying it to the descriptor's default -- all five agree today; a test over numbers in prose is more machinery than a defect this unlikely warrants.
  - `[low]` `[patch]` No `mutation:` line for the row clause or the instance-side title on AC1 -- both mutations applied, red observed, reverted, lines written.
  - `[low]` `[patch]` The AC2 test's doc comment names mutations the spec did not record -- "a label names `tasks.nosuch`" and "a label outside every group" applied, red observed, reverted, lines written.
  - `[false]` `[reject]` AC3's override leg rests on an older test -- `TurnLoop.TestAnOverrideReplacesTheBuiltInPromptWhole` asserts equality with the override and carries its own mutation line.
  - `[false]` `[reject]` AC4 has no pinning test -- the spec makes it a deterministic proxy checked at review; measured and recorded under Verification.
  - `[false]` `[reject]` AC5 and AC8 have no pinning test or mutation line -- the spec makes both lead checks (Task Z; the upgrade-trigger check).
  - `[false]` `[reject]` Only the type refusal of the grammar has a mutation line -- Rule 19 asks one per AC, and the corpus pins the empty, 40/41 and 240/241 boundaries in both engines.
  - `[false]` `[reject]` `Title` re-reads the XData on every call, about 158 per provider request -- measured: 157 `Title` calls take 0.042 s and 157 `Description` calls 0.047 s on `ocupilot-ci`.
  - `[false]` `[reject]` No test exercises `ProviderTools`, the adapters or the assembled request -- `ProviderTools` calls the same `DescriptionOf` on the same entries, `ToolEmit`, `TurnTools`, `TurnScope` and `TurnWire` pass, and Task Z measures the assembled request.
  - `[false]` `[reject]` A discovery row's 1,000-character cut trims the `Fields:` tail of `osmgmt.dashboard` and `osmgmt.ecpstatistics` -- the Design Notes name both and place the label early so the cut trims only fields.
  - `[false]` `[reject]` The field list is tied to the executor by shared code, with no test comparing executed row keys -- the spec requires the one helper, and AC1 says "exactly `Screen.Read.AnsweredFields`".
  - `[false]` `[reject]` The discovery test asserts presence among 20 rows, not rank, and several task reads may tie -- AC7 asks for the row and its description; `ToolsFind` scoring is out of scope (Never).
  - `[false]` `[reject]` Three titles are shared by several tools and some tab titles are generic -- the Design Notes decide it: the identifier in parentheses tells duplicates apart.
  - `[false]` `[reject]` Prompt rule 2 says each read tool names its fields, which the other `KIND = "read"` tools do not -- the rule is ruled verbatim and those tools read no list (Design Notes, Scope of AC1).
  - `[false]` `[reject]` The spine is not edited and AD-36 names only `note` -- the orchestrator ruled no spine edit in this run; the two notes wait for the owner's Update.
  - `[false]` `[reject]` The demo changes only at a later release -- not a defect of the diff.

## Design Notes

**Governing ADs:**

- AD-5: compile-time descriptor source; the listing is cached per process.
- AD-11: build-time prompt; an override replaces it whole.
- AD-24: the turn budget and 18.45's starting sets.
- AD-35: no secret field reaches a description.
- AD-36: one read, its `fields` and `read.note`.
- AD-60: find rows and tool references are unchanged.

**Spine notes, for the owner's attended bmad-architecture Update after the run** (no spine edit in this run, orchestrator ruling 2026-10-23):

- AD-5 gains a third generated artifact: `Screen/Titles.cls`, each descriptor `labelKey`'s string from `strings.ts`, written and checked by `screen-mirror.mjs`.
- AD-36 gains: "A declared read may declare `row`, the phrase for one row, and `label`, one sentence on what the list holds and does not hold. Its read tool's description carries both, with the screen's title and its answered fields. No page renders them. `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs` validate them alike."

**Escalated (veto window), recommended option planned:**

1. **Text a person can see.** On the agent panel's tool-call card for a `shell.tools.find` step, expanded, live and on Agent > Transcripts, the step's raw result text (up to 4,096 characters) shows each found tool's description. That puts these strings in front of a person:
   - the description template;
   - the row phrases;
   - the 36 labels below.

   Today's templated sentence already shows there the same way. Recommended: accept as proposed.
2. **The two spine notes above.** The design complies with both ADs (U7: comply first), and the notes record new grammar. Recommended: apply both. The alternative for titles, a copy on each descriptor held equal to `strings.ts` by a test (the `read.note` pattern), writes 157 titles twice, against the AC.

**Lead rulings (2026-10-23, run 20261020T0940Z-20,23):**

- Item 1, visible text: accepted as planned (veto window: public-facing text not in UX or PRD). The composed descriptions, row phrases and labels may show in an expanded `shell.tools.find` tool-call card, as today's sentence does. Reversal: reword them in a later story.
- Item 2, the AD-5 and AD-36 notes, orchestrator ruling (decide): implement as planned, with no spine edit in this run. `read.row` and `read.label` extend AD-36's read members, and `Screen/Titles.cls` is a client-to-instance flow AD-5 does not address, so neither Rule is contradicted (U7 step 1). An amendment is out under U14, since Story 20.38 cites AD-5. The two lines above wait for the owner's Update. The per-descriptor title copy is rejected.
- Story 20.38 runs beside this story. `ui/tools/screen-mirror.mjs` and `src/OcuPilot/Screen/Registry.cls` are reserved to this story for edits that are not add-only. If 20.38 merges first, the lead integrates forward, adds `row` to its new read descriptors and labels its schema Tables, Views and Procedures tabs, and regenerates.

**Decided in-stage:**

- **Title.** Generated, not copied (see the escalation above). Each screen's own `labelKey` value is its title, tabs included. The identifier in parentheses tells apart duplicates such as the three "SQL statements" tabs.
- **Scope of AC1.** It applies to the 157 descriptor reads and to `logs.applicationerrors.read`, the one class tool that reads a screen's list. Tools that run a query, a search or a check read no list: `explorer.sqlquery.read`, `analytics.mdxquery.read`, the source reads, `shell.*` and `permissions.privileges.check`.
- **Grammar.** `row` and `label` are optional in the grammar, so no fixture registry changes. The roster test requires them in production, which is what AC6 pins.
- **Template.**
  - The head is "Read the rows of the <Title> screen (<identifier>)". With no title it is "Read the rows of the <identifier> screen".
  - Then ", one <row> per row" when a row is declared, then ", bounded and with secret fields removed.".
  - Then " <label>", then " Fields: <F1>, <F2>, ... <Fn>.", then " <note>".
  - The label comes early so that a find row's 1,000-character cut trims only fields. Two reads are projected over 1,000 characters: `osmgmt.dashboard` at 1,135 and `osmgmt.ecpstatistics` at 1,033.
  - The note stays last, so `PermissionsLists:266-268` and `EcpSslConnectionWrite:128-129` hold. The identifier stays, so `ToolEmit:99` holds.
- **Row rule.**
  - A lower-case singular noun phrase, except proper names, of at most 40 characters, with no article and no period. It says what one row stands for, taken from the descriptor's own doc comment.
  - A single-object read names the object, for example "set of journal settings".
  - Code review samples rows against the doc comments.
- **Mirror.** It carries `row` and `label` verbatim, typed and unrendered, about 10 KB. `npm run build` reports the initial total against the fixed 2,500 kB warning.
- **Labels name identifiers.** A rename of a title therefore stales no label, and the roster test checks each identifier a label names. The check covers every `<word>.<word>` token except a `*.log` file name.
- **Extend, don't copy (Rule 2/31):**
  - `AnsweredFields` is lifted from `Execute`, not copied.
  - `Compose` is shared by `Read` and `ErrorRead`.
  - `readRowLabelProblem` and `ReadRowLabelProblem` sit beside the note validators on one corpus.
  - The titles writer extends `screen-mirror.mjs`'s `generate` and `--check`, so `prebuild`, the pre-commit hook and CI already run it. Editing `ui/package.json` or `.githooks` is not needed.
  - `ReadDescriptions` is a new class rather than an extension of `ReadTool` (1,292 lines) or `ToolEmit` (595 lines): both are past the 500-line guideline. `CriterionHints` is its template.
- **Override.** `ProviderPort.SystemPromptFor` sends an override whole and never both, as AD-11 requires. A definition carrying one therefore does not get the three rules, but its tools still carry the new descriptions and labels.
  - No shipped or demo definition sets one: neither the installer nor `Install/Fixture.cls` creates a definition with an override.
  - The online demo's definition is the owner's and was not read.
- **Integration (Rules 1 and 2).**
  - Consumes: `Screen.Read.AnsweredFields`, the `Descriptor.Base` accessors, and `Titles.cls`.
  - Consumed-by: `Loop`'s provider request (`Registry.ProviderTools`), `shell.tools.find` (scoring and rows, AC7), and the live evaluation (AC5, on a real instance).
- **Decided in implement.** The 122 row phrases outside the Labels table follow the row rule, and review sampled them against the doc comments. The pre-commit hook's `Screen mirror:` hint names `Titles.cls` beside `screens.generated.ts`.
- **Upgrade trigger (AC8).** None. The file list touches no `Kernel/State/**` and no `Install/**`, and leaves `module.xml` (`OcuPilot.PKG`, by package), `docker-compose.yml` and the start script alone. It adds no `Baseline.cls` key. `ipm-manifest.mjs --check` is unaffected, because `Screen/` already exists.
- **Ledger inbox.** It holds no entries for this story.

**The three rules,** inserted after "say so rather than describe a capability you lack.":

> When more than one list could hold the answer, read each likely one before you answer that there is none. Never say that a list lacks a field or a status until you have read it; each read tool's description names the fields it returns. When you find nothing, name the lists you checked, by their screen titles.

**Confusable groups.** The set was measured over the 157 reads by three signals: a shared title word, a shared vendor endpoint, and an identical field list. A group was kept where a plausible question has its answer in only one member, so that reading another gives a wrong "none". Six groups, 36 tools:

- Tasks: the five the AC names, plus `tasks.taskhistory` (same fields as `tasks.history`) and `logs.taskerrors` (title "Background task error log").
- Databases: `Database.SysCRUD` and `Database.ConfigCRUD`, ECP data servers, and DocDB.
- Logs: the same `time,severity,text` shape across eight sources, plus the hub, the audit log, `applicationerrors`, and `interop.messages`, which collides with "messages.log".
- Processes: the title word "process" across the instance and interoperability.
- Audit: event definitions against audit records.
- SQL statements: three tabs with an identical title and fields, against running statements.

Signals judged not confusable, because their titles already carry the qualifier:

- the SQL privilege kinds, the mappings and the encryption kinds;
- license usage, ECP statistics and the interoperability item tabs;
- `osmgmt.languageserveractivity` and `interop.itemlog`, which are scoped to one server or one item.

**Labels (proposed; tool, row, label):**

| Tool | row | label |
| --- | --- | --- |
| tasks.schedule | scheduled task | Every Task Manager task, with Suspended true for a suspended one; a task's runs and their errors are in tasks.history, and portal jobs such as a database compact in tasks.background. |
| tasks.ondemand | task that can be run now | Tasks a person can run now, with no suspended state and no run results; those are in tasks.schedule and tasks.history. |
| tasks.upcoming | scheduled run of a task | Each run due within a window ahead, 24 hours unless asked, so a task can appear more than once; past runs are in tasks.history. |
| tasks.history | run of a task | Past runs of every task, newest first, the last 7 days unless asked; a failed run's error text is in Result. Whether a task is suspended is in tasks.schedule. |
| tasks.taskhistory | run of one task | Past runs of one task, named by its task id; every task's runs are in tasks.history. |
| tasks.background | background job | Background jobs such as a database compact, started from the portal, the admin API or a database task; scheduled tasks are in tasks.schedule and their runs in tasks.history. |
| logs.taskerrors | error a background job logged | Errors that portal background jobs logged, from every namespace; a scheduled task's failed runs are in tasks.history. |
| osmgmt.databases | database | The instance's databases by directory, with Status (Mounted/RW, Mounted/R or Dismounted) and size; a remote database's server is in osmgmt.remotedatabases. |
| osmgmt.localdatabases | local database definition | Database definitions whose files are on this instance, with Status; definitions of databases on another server are in osmgmt.remotedatabases. |
| osmgmt.remotedatabases | remote database definition | Database definitions whose files are on another server reached over ECP, with Server and that server's Directory; the servers are in osmgmt.ecpdataservers. |
| osmgmt.databasefreespace | database | Size, free space and disk free for each database, with Mounted true or false; Status and the full list are in osmgmt.databases. |
| osmgmt.ecpdataservers | ECP data server | ECP data servers this instance connects to, with their connection Status; the remote databases on them are in osmgmt.remotedatabases. |
| explorer.docdb | document database | Document databases (DocDB) in this namespace, not the instance's databases, which are in osmgmt.databases. |
| logs.messages | line of messages.log | Lines of the instance's console log, messages.log, newest first, with severity (1 warning, 2 severe, 3 fatal); errors raised in application code are in logs.applicationerrors. |
| logs.applicationerrors (`ErrorRead.LABEL`) | application error | Errors raised in application code and logged per namespace and date; system messages and warnings are in logs.messages, and the last hour's errors also appear in logs.hub. |
| logs.alerts | line of alerts.log | Entries of the instance's alerts.log, newest first; the full console log is logs.messages. |
| logs.systemmonitor | line of SystemMonitor.log | Entries of SystemMonitor.log, the System Monitor's own log; the console log is logs.messages. |
| logs.xdbc | xDBC error | ODBC and JDBC (xDBC) errors, one per process, from every readable namespace; SQL diagnostic results are in logs.sqldiagnostics. |
| logs.sqldiagnostics | SQL diagnostic result | SQL diagnostic results (%SQL_Diag) from every readable namespace; ODBC and JDBC errors are in logs.xdbc. |
| logs.eventlog | interoperability event | Interoperability event log entries (Ens_Util.Log) from every interoperability namespace; production messages are in interop.messages. |
| logs.analytics | line of an analytics task log | Analytics task log lines (DeepSeeTasks) from every namespace; the console log is logs.messages. |
| logs.hub | log entry | Entries from every other Logs screen, application errors included, merged newest first, the last hour unless asked, each naming its source; the integrity log is not included. |
| logs.audit | audit record | Audited events that happened, such as logins and changes, newest first, the last 24 hours unless asked; which events are audited is in security.auditsystemevents and security.audituserevents. |
| osmgmt.integritylog | line of an integrity check report | Lines of the newest integrity check's report, errors marked severity error; no rows while a check runs or when none has run. |
| interop.messages | interoperability message header | Interoperability message headers in this namespace, the last 24 hours unless asked; the console log messages.log is logs.messages. |
| osmgmt.processes | process | Every IRIS process on the instance, daemons included, with its namespace (Nspace) and State; business process classes are in interop.processes. |
| osmgmt.activeprocesses | busy process | The processes running the most commands, as the Dashboard counts them; every process is in osmgmt.processes. |
| interop.processes | business process class | Business process classes (BPL or code) in this namespace, not running processes, which are in osmgmt.processes. |
| interop.jobs | production job | Jobs of this namespace's running production, dead ones included (Dead); the instance's processes are in osmgmt.processes. |
| security.auditsystemevents | system audit event type | Audit event types IRIS defines, each with Enabled and its counters; the audited events themselves are in logs.audit. |
| security.audituserevents | user audit event type | Audit event types applications registered, each with Enabled and its counters; the audited events themselves are in logs.audit. |
| security.auditing | auditing setting | Whether auditing is on for the whole instance; which events are audited is in security.auditsystemevents and security.audituserevents. |
| osmgmt.sqlactivity | running SQL statement | SQL statements running right now in every namespace, slowest first; statistics for one table's, view's or procedure's statements are in explorer.sqltablestatements, explorer.sqlviewstatements and explorer.sqlprocedurestatements. |
| explorer.sqltablestatements | statement that uses the table | Statements that use one table, named by its criterion, with plan state and run statistics; statements running now are in osmgmt.sqlactivity. |
| explorer.sqlviewstatements | statement that uses the view | Statements that use one view, named by its criterion, with plan state and run statistics; statements running now are in osmgmt.sqlactivity. |
| explorer.sqlprocedurestatements | statement that uses the procedure | Statements that use one procedure, named by its criterion, with plan state and run statistics; statements running now are in osmgmt.sqlactivity. |

The facts come from each descriptor's doc comment and declaration. `osmgmt.databases`'s Status values were measured in Story 16.21. Whether that list includes remote databases is unrecorded, so no label claims it either way.

**Token cost (Task 0 (a) and Task Z).**

- **Cases.**
  - N: the first provider request of a turn with no screen open.
  - B: the first provider request of a `tasks/schedule` turn (18.45's largest starting set, 16 tools), with a one-row context.
- **Method (18.45's Task 0 (e)).**
  - Drive each case through the armed `turnprobe` stub on `ocupilot-ci` and take its first recorded call (`Test/TurnProvider.cls` `Recorded`).
  - Render it through each dialect's own builder: Anthropic (`CallMessages`, with `defer_loading` outside the starting set), OpenAI and Gemini.
  - Record the characters of the body and of its tools array.
  - Record `count_tokens` on `claude-haiku-5-5` for the Anthropic body (POST `https://api.anthropic.com/v1/messages/count_tokens`; free of charge (inference)).
- **Where.** Figures only, never a header or a key, in `23-12-eval/measure-before.json` and `measure-after.json`. The lead summarizes them under `## Verification`.
- **Bound** (estimated from the declarations):
  - The rules add about 310 characters (about 80 tokens).
  - The schedule's description grows by about 330 characters.
  - Every description together grows by about 27,000 characters (fields, titles and rows 22,000, labels 4,900 by the table).

| Measure | N | B |
| --- | --- | --- |
| `count_tokens`, `claude-haiku-5-5` | at most +250 tokens and +10% | at most +500 tokens and +10% |
| OpenAI and Gemini body characters | at most +1,000 | at most +2,000 |
| Anthropic body characters (every tool sent, deferred ones included) | at most +40,000 | at most +40,000 |

- **Who checks.** Code review checks the deterministic proxy on `ocupilot-ci`: the summed lengths of the listing's descriptions grow by at most 40,000 characters, and `BUILTIN` by at most 400. A crossing is a finding against this story.

**Live evaluation (Task 0 (b) and Task Z).**

- **Folder.** `_bmad-output/implementation-artifacts/23-12-eval/` holds:
  - `eval.mjs`, the harness, Node and `fetch`;
  - `questions.json`;
  - `score-before.md` and `score-after.md`.

  It is measurement tooling, not product code, and no test runs it.
- **Harness.**
  1. **Preflight.** `docker port ocupilot-ci 52773/tcp` reads 52776, and readiness answers.
  2. **Key.** Read `ANTHROPIC_API_KEY` from `/Users/jbrandt/git/OcuPilot/.env.local` into one variable, used once in the credential POST and in the `count_tokens` headers. Never print, log or write it, and redact it from any error.
  3. **Probe definition.** Over Basic `_SYSTEM`/`SYS` on `http://localhost:52776/api/ocupilot`:
     - POST `/agent/definitions` `{name:"EVAL2312 probe", provider:"anthropic", model:"claude-haiku-5-5", credType:"creds", credentialName:"OcuPilotEval2312"}`;
     - `/credential` `{apiKey}`, then `/test`, then PUT `{enabled:true}`;
     - set `_SYSTEM`'s `agentDefinition` preference, keeping the old value to restore.
  4. **Seed** (below). Wait up to 180 s for the demo task's failed run and its suspension.
  5. **Expected answers.** Read each answer list through its screen's own read route (`GET /screens/:screen/read`) and write them into the sheet before any turn.
  6. **Questions.** For each, in a new conversation (POST `/conversation`), POST `/turn` `{message, conversationId}` with no `context`. Poll `/turn/:id/progress` every 2 s until the turn is terminal. Record the reply, the tool names of its steps, and `tokens{input,output}`.
     - A 409 `TURN.BUSY` waits.
     - A 403 `TURN.LIMITHOUR` waits until `retryAt`.
  7. **Teardown, always** (in `finally`):
     - stop any running turn;
     - DELETE the definition (its OcuPilot-made credential goes with it) and restore the preference;
     - remove the EVAL2312 tasks, the remote database and its ECP server, and the dismounted database's configuration and directory.
- **Seed.** Idempotent, re-run at the start of every run, marker `EVAL2312`. The ObjectScript lines are piped by `eval.mjs` to `docker exec -i ocupilot-ci iris session iris -U %SYS`, as `runIris` does.
  - Tasks "EVAL2312 suspended A", "B" and "C": daily, then suspended (`TaskResume.SuspendProbeTask`), with every task OREF released after `Suspend`.
  - Task "EVAL2312 weekly report": weekly and not suspended.
  - All four use a task class whose `OnTask` does nothing: `%SYS.Task.RunLegacyTask` with `ExecuteCode` `Quit` (inference). The lead confirms it in `irissys/` first.
  - The install's demo task "OcuPilotDemo nightly purge" fails and is suspended by itself.
  - Database EVAL2312DISM:
    - directory `/durable/eval2312/dism/`, asserted outside `##class(%File).ManagerDirectory()` and IRISSYS's directory (owner rule);
    - resource `%DB_EVAL2312DISM` created first, then the database and its configuration, then `DismountDatabase` (`BackgroundSeed.cls:61,379`).
  - ECP server EVAL2312SRV at 127.0.0.1:1972 and remote database EVAL2312REMOTE on it (`RemoteDatabaseProbe.cls:79,104`).
  - A messages.log line at severity 2: `##class(%SYS.System).WriteToConsoleLog("EVAL2312 <run> journal disk check failed", 0, 2)`.
  - In `USER`, a `<DIVIDE>` logged with `LOG^%ETN` (`ErrorLogSeed.cls:61`).
- **Questions** (the answer list, and when the answer is right):

| # | Question | Holds the answer | Right when |
| --- | --- | --- | --- |
| 1 | Which tasks are suspended? | tasks.schedule | It names every task the schedule shows Suspended (the demo task and the three EVAL2312 suspended tasks), and no other. |
| 2 | Which task runs failed in the last 24 hours? | tasks.history | It names every task whose run failed in the history read (the demo task at least), not "none". |
| 3 | Which databases are dismounted? | osmgmt.databases | It names EVAL2312DISM and every other database the read shows Dismounted. |
| 4 | Which databases are remote, and which server holds each? | osmgmt.remotedatabases | EVAL2312REMOTE on EVAL2312SRV. |
| 5 | An error about the EVAL2312 journal disk check was reported in the last hour. Which log holds it, and what does it say? | logs.messages | It names messages.log and quotes the seeded text. |
| 6 | What application error was raised in the USER namespace in the last hour? | logs.applicationerrors or logs.hub | It reports the seeded `<DIVIDE>` in USER, not "none" and not messages.log. |
| 7 | Are any background jobs, such as a database compact, running or failed? | tasks.background | It gives the rows the read shows ("none" when empty) and names Background tasks among the lists checked. |
| 8 | When does the task EVAL2312 weekly report run next? | tasks.schedule | The NextScheduled the schedule shows. |
| 9 | Did OcuPilotDemo nightly purge succeed the last time it ran, and what did it report? | tasks.history | It failed, with its Result error text. |
| 10 | Is auditing on for this instance, and is the LoginFailure event enabled? | security.auditing, security.auditsystemevents | Both values as those reads show them. |

- **Scoring.** The lead scores each reply right or wrong against the "right when" column, with a one-line reason, the tools it read and its tokens.
- **A wrong after-run answer** takes the failed-smoke path. The reply is the evidence.
- **Cost cap.**
  - $2.00 for every live call of Task 0 and Task Z together, and at most $0.90 a run, which the harness enforces.
  - Price: `claude-haiku-5-5` is $0.10 input and $0.50 output per million tokens up to 100K-token prompts, $0.50 and $2.50 beyond. Cache writes cost 1.25 times input, and reads 0.1 times. Source: the claude-api skill's model table (cached 2026-10-06), since the repository records no Anthropic price.
  - The harness prices conservatively: every input token at $0.625 a million (the higher rate's cache write), and every output token at $2.50 a million.
  - It starts no question once the run is at $0.80, and stops a turn (POST `/turn/:id/stop`) that would pass $0.90.
  - Expected real spend is under $0.30 for both runs.
  - A re-run that would pass $2.00 is the owner's (money).

## Verification

**Slot A.**

- `ocupilot-slot-a` (the dev instance) is used read-only.
- The throwaway is `ocupilot-ci`: dir `/Users/jbrandt/.ocupilot-throwaways/ocupilot-ci`, project `ocupilot-ci`, web 52776, super 1975, origin `http://localhost:52776`. Use it only once it reads healthy, and never down it.
- One test run in flight at a time. Every command is `(loop)` and runs in one foreground call with `timeout: 600000`.
- There are no `(once)` lines:
  - the lead runs the full ObjectScript sweep and Rule 30's fresh check;
  - CI runs the full browser suite.
- No browser spec asserts a description or the prompt.

**Shared surfaces:**

- Read-tool descriptions:
  - `ExplorerDescriptor:392-412` (exact text, rewritten);
  - `PermissionsLists:266-268` and `EcpSslConnectionWrite:128-129` (note last);
  - `ToolEmit:98-99` (identifier);
  - `ToolsFind:56,68,86`, `ToolWire:248,293` and `AllowListAgent:96,116-119` (find ranking);
  - `TurnTools:21,37`.
- The prompt:
  - `ScreenGrounding:50-67`, `Governance:260`, `TurnNavigate:510-515`, `Sanitize:60,77`;
  - `TurnLoop:130,151`, `TurnTools:149`, `TurnWire:126`;
  - `Prompt.cls`'s own sentence-group comment.
- The read grammar: `ReadSourceCorpus` (both runners), `screen-mirror.test.mjs`, `screens.generated.ts`.
- Starting-set size: `TurnScope:214-256`.

Every test added or changed passes on a fresh environment, in either order.

**Commands:**

- `(loop)` `cd ui && node tools/screen-mirror.mjs && node tools/screen-mirror.mjs --check` -- expected: writes `screens.generated.ts` and `src/OcuPilot/Screen/Titles.cls`, and the check exits 0.
- `(loop)` Load: `rsync -a --delete src/ /Users/jbrandt/.ocupilot-throwaways/ocupilot-ci/src/`, then `Do $System.OBJ.LoadDir("/opt/ocupilot/src","ck-d",.e,1)` in `docker exec -i ocupilot-ci iris session iris -U HSCUSTOM` -- expected: 0 errors.
- `(loop)` `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one class per call, with totals confirmed in `%UnitTest_Result`. Classes:
  - `ReadDescriptions`, `ReadTool`, `ExplorerDescriptor`, `PermissionsLists`, `EcpSslConnectionWrite`;
  - `ToolEmit`, `ToolsFind`, `ToolWire`, `AllowListAgent`, `TurnTools`, `TurnScope`;
  - `ScreenGrounding`, `Governance`, `TurnNavigate`, `Sanitize`, `TurnLoop`, `TurnWire`;
  - `Descriptor`, `CriterionHints`;
  - every class the sweep changes.

  Expected: 0 failed.
- `(loop)` `cd ui && npm run test:tools` and `cd ui && npm run test:components` -- expected: green.
- `(loop)` `cd ui && npm run build` -- expected: the prebuild checkers and the budgets pass, with the initial total reported.
- `(loop)` `uv run scripts/check-objectscript.py <each changed .cls>`, and `bash scripts/lint-docs.sh` when Markdown changes -- expected: clean.

**Mutations (Rule 19; record each as `mutation: ... -> ...`):**

Each was applied on `ocupilot-ci` (the whole `src/` tree reloaded after it), the named test class run, and the file restored and confirmed byte-identical.

- AC1 and AC6: `Read.Description` omits `Fields:` for `tasks.schedule`. Expected red: `TestEveryReadToolNamesItsTitleRowAndFields`.
  - mutation: `Tool/Read.cls` `Compose` skips the `Fields:` clause when the identifier is `tasks.schedule` -> `ReadDescriptions.TestEveryReadToolNamesItsTitleRowAndFields` red alone, naming `tasks.schedule.read`.
- AC1, secret: `AnsweredFields` keeps secret fields. Expected red: the same test, at `osmgmt.licensekey`.
  - mutation: `Screen/Read.cls` `AnsweredFields` pushes every field, secret or not -> `TestEveryReadToolNamesItsTitleRowAndFields` red alone, at `osmgmt.licensekey.read` (`AuthorizationKey` listed).
- AC1, title: a `labelKey`'s value changed in `strings.ts`, not regenerated. Expected: `screen-mirror.mjs --check` exits 1. Also, `buildTitles` emitting the key in place of its value turns the mirror test red.
  - mutation: `taskListLabel` changed in `strings.ts`, nothing regenerated -> `node tools/screen-mirror.mjs --check` exits 1, "src/OcuPilot/Screen/Titles.cls is stale".
  - mutation: `buildTitles` stores the key as the value -> `screen-mirror.test.mjs` `buildTitles maps every descriptor labelKey ...` red, and the `--check` test with it.
- AC1, instance-side title: `Read.Title` answers the label key. Expected red: `TestEveryReadToolNamesItsTitleRowAndFields`.
  - mutation: `Tool/Read.cls` `Title` sets the title to the label key instead of its XData string -> `ReadDescriptions.TestEveryReadToolNamesItsTitleRowAndFields` red alone, on every tool.
- AC1, row: `Compose` omits the row clause. Expected red: the same test.
  - mutation: `Tool/Read.cls` `Compose` drops its `, one <row> per row` line -> `TestEveryReadToolNamesItsTitleRowAndFields` and `TestAReadWithoutATitleOrARowStillComposes` red.
- AC2: `read.label` removed from `BackgroundTaskList`. Expected red: `TestEveryConfusableToolCarriesItsLabel`.
  - mutation: the `label` line deleted from `Descriptor/BackgroundTaskList.cls` -> `ReadDescriptions.TestEveryConfusableToolCarriesItsLabel` red alone, "tasks.background.read declares its label".
  - mutation: `TaskHistoryList`'s label names `tasks.nosuch` in place of `tasks.schedule` -> `TestEveryConfusableToolCarriesItsLabel` red alone.
  - mutation: `UserList` (outside every group) declares a label -> `TestEveryConfusableToolCarriesItsLabel` red alone.
- AC3: one rule removed from `BUILTIN`. Expected red: `TestThePromptCarriesTheListRules`.
  - mutation: the second rule deleted from `Prompt.BUILTIN` -> `ReadDescriptions.TestThePromptCarriesTheListRules` red alone (once-each and in-order legs).
- AC7: `ToolsFind` answers the old fixed sentence. Expected red: `TestTheDiscoveryAnswerCarriesTheDescription`.
  - mutation: `ToolsFind.View` sets the old fixed sentence for a descriptor-derived read -> `ReadDescriptions.TestTheDiscoveryAnswerCarriesTheDescription` red alone (equality and `Suspended` legs).
- Grammar: `ReadRowLabelProblem` accepts a number. Expected red: `ReadTool.TestEveryReadSourceCorpusCaseGetsItsSentence` and the mirror's corpus test.
  - mutation: `Registry.ReadRowLabelProblem` drops its string-type refusal -> `ReadTool.TestEveryReadSourceCorpusCaseGetsItsSentence` red alone ("a row that is a number", "a label that is a number").
  - mutation: `readRowLabelProblem` drops its string-type refusal -> `screen-mirror.test.mjs` `readProblem returns every ... sentence OcuPilot.Test.ReadSourceCorpus declares` red alone ("a row that is a number").
- Compose without a title or a row: `Compose` always writes the row clause. Expected red: `TestAReadWithoutATitleOrARowStillComposes`.
  - mutation: `Compose` writes ", one <row> per row" unconditionally -> `ReadDescriptions.TestAReadWithoutATitleOrARowStillComposes` red alone ("no title and no row").
- Note stays last: the note dropped from `Read.Description`. Expected red: `ExplorerDescriptor.TestTheStatementsToolsEndWithTheStatisticsNote`.
  - mutation: `Read.Description` never sets the note -> `ExplorerDescriptor.TestTheStatementsToolsEndWithTheStatisticsNote` red alone, all three statements tools on three legs each.

**Measured after (AC4 proxy, `ocupilot-ci`, this story's code loaded, `Loop.DispatchClass().Advertise` and `Prompt.Builtin()`):**

- The listing holds 396 tools; its descriptions sum to 152,880 characters, against 125,314 before: +27,566, bound 40,000.
- `Builtin()` is 4,559 characters, against 4,248 before: +311, bound 400.
- Two reads exceed 1,000 characters, `osmgmt.dashboard` at 1,143 and `osmgmt.ecpstatistics` at 1,030; the longest description of all is an existing write tool at 1,516.
- Warm `Registry.ProviderTools` takes 0.46 to 0.49 s for 396 tools, and 157 `Read.Title` calls take 0.042 s.

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** Every read tool's description is now composed from declarations: the screen's title from the generated `Screen/Titles.cls`, the descriptor's `row` phrase, the executor's answered fields (`Screen.Read.AnsweredFields`), the descriptor's `label` where it declares one, and its `note` last. 157 descriptors declare `row` and 35 also `label`; `logs.applicationerrors.read` composes through the same `Compose` from `ErrorRead.ROW` and `ErrorRead.LABEL`. The built-in prompt carries the three list rules. `Registry.cls` and `screen-mirror.mjs` validate `row` and `label` alike, and `screen-mirror.mjs` writes and checks `Titles.cls`.

**Files changed.**

- `ui/tools/screen-mirror.mjs`: `readRowLabelProblem`, `buildTitles`, `generateTitles`, the `--check` of `Titles.cls`, `ReadDeclaration.row` and `.label`.
- `src/OcuPilot/Screen/Titles.cls` (new, generated) and `ui/src/app/core/screens.generated.ts` (regenerated).
- `ui/src/app/core/strings.ts`: one header line.
- `src/OcuPilot/Screen/Registry.cls`: `ReadRowLabelProblem` and the allowed keys.
- `src/OcuPilot/Screen/Read.cls`: `AnsweredFields`, lifted from `Execute`.
- `src/OcuPilot/Screen/Tool/Read.cls`: `Title`, `Compose`, `Description`; `src/OcuPilot/Screen/Tool/ErrorRead.cls`: `ROW`, `LABEL`, `Description`.
- `src/OcuPilot/Screen/Descriptor/*.cls` (157): `row`, and `label` on 35.
- `src/OcuPilot/Kernel/Agent/Prompt.cls`: the three rules and the sentence-group count.
- `src/OcuPilot/Test/ReadDescriptions.cls` (new), `Test/ReadSourceCorpus.cls`, `Test/ExplorerDescriptor.cls`, `ui/tools/screen-mirror.test.mjs`, `ui/tools/field-lists.test.mjs`.
- `.githooks/pre-commit`: the `Screen mirror:` hint names `Titles.cls`.

**Review.** Two layers ran (`verification-gap`, `intent-alignment`); 18 findings. Patched: 1 medium (the title leg had no independent oracle) and 2 low (missing `mutation:` lines). Deferred: 1 (descriptions over 1,024 characters, medium unverified). Rejected: 14, each with its reason in the Review Triage Log. Follow-up review recommended: `false` (no high patched, one medium).

**Verification.** On `ocupilot-ci`: `src/` loads with 0 errors; the 19 listed classes plus `ReadDescriptions` run one per call, 0 failed, totals confirmed in `%UnitTest_Result`; `npm run test:tools` 2147 passed; `npm run test:components` 3338 passed; `npm run build` passes its prebuild checkers with an initial total of 2.01 MB; `check-objectscript.py` and `lint-docs.sh` report 0 problems. The token proxies are inside the bounds (Verification, Measured after). Fifteen mutations are recorded, each with the test that went red.

**Residual risks and hand-offs.**

- Task Z (the "after" token measurement and live evaluation) is the lead's, and AC5 stays open until it runs.
- Story 20.38 adds three read descriptors (`ExplorerSqlSchema`, `ExplorerSqlSchemaViews`, `ExplorerSqlSchemaProcedures`) that need a `row` before `TestEveryReadToolNamesItsTitleRowAndFields` passes on the merged tree. Both stories edit `strings.ts`, `Test/ExplorerDescriptor.cls` and `screen-mirror.test.mjs`, and the merge regenerates `screens.generated.ts` and `Titles.cls`.
- `.githooks/pre-commit` is outside the spec's file list: a footprint extension for the report.
