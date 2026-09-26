---
title: 'Story 11.3: Suggested prompts per screen'
type: 'feature'
created: '2026-09-25'
status: 'done'
baseline_revision: 'c7eb5d26881b2e01b59705f10b4533684d6905fa'
baseline_commit: 'c7eb5d26881b2e01b59705f10b4533684d6905fa'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-11-context.md'
  - '{project-root}/_bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** UX-DR79 and Story 11.3 require every screen's idle panel to offer at least three suggested prompts, grouped by task, that send when chosen. Today the greeting shows Home's three hard-coded starter prompts on every screen, and a click only places the text in the composer. Epic 9 declared `suggestedPrompts` on 8 descriptors, but nothing reads them, and the other 45 built screens (Home included) declare none. The ledger inbox adds three Home defects: the block yields its prompts to the greeting (DW-1158), a refused or faulted read reads as "nothing needs attention" (DW-1147), and a zero line can render with no date (DW-1160).

**Approach:**

- Make Epic 9's `suggestedPrompts: [{groupKey, textKey}]` contract required on every built screen, with `groupKey` drawn from a closed vocabulary. `Registry.cls` and `screen-mirror.mjs` enforce this identically.
- Declare three prompts on each of the 45 built screens that declare none. Home re-declares its existing three.
- The panel renders the current screen's prompts, grouped, in the idle empty-transcript greeting. On Home they render in the suggested-view block instead. A click sends the text through 11.1's Send path.

## Boundaries & Constraints

**Always:**

- **Text source.** Prompt and group text lives in `strings.ts`, transcribed from new EXPERIENCE.md Fixed-strings rows. The descriptor names keys only (Epic 9's contract). Where a new text equals an existing `STRINGS` value, reuse that key.
- **Closed group vocabulary.** It has ten keys, listed identically in `Registry.cls` `PROMPTGROUPKEYS` and in `screen-mirror.mjs` `PROMPT_GROUP_KEYS`:
  - Epic 9's six: `userPromptGroupSignIn`, `userPromptGroupAccess`, `webAppPromptGroupCode`, `sslPromptGroupConnections`, `taskPromptGroupSchedule`, `auditUserEventPromptGroup`.
  - Four new ones: `promptGroupTroubleshooting` ('Troubleshooting'), `promptGroupCapacity` ('Capacity'), `promptGroupAgentSetup` ('Agent setup'), `promptGroupGettingStarted` ('Getting started').
- **Rule sentences.** Both engines return the same sentence:
  - a built screen with no `suggestedPrompts`, or a null one: `a built screen declares at least 3 suggestedPrompts`;
  - an unknown group: `suggestedPrompts[<i>].groupKey '<key>' is not one of the declared prompt groups`.
  An unbuilt screen may declare none. Every other existing sentence is unchanged.
- **Grouping.** Groups render in the order each group first appears, and each group's prompts in declaration order. Each group is a `role="group"` element labeled by its visible label.
- **Idle.** Prompts render only in 4.10's greeting, which shows when the definition is enabled and answered and the transcript is restored and empty (epic context: "idle and empty"). They also render in Home's suggested-view block while `showPrompts()` holds.
- **Exactly one prompt set on screen.** On Home, while the block shows its prompts, the greeting renders its sentence and hint but no prompts (DW-1158: EXPERIENCE.md is canonical).
- **Sending.** A click sends the prompt text exactly as the user message, through `sendWithContext(text, this.assembleContext())`. The draft is untouched (AD-11 rule 1).
  - The gate is Send's: the button is `aria-disabled="true"` while `composerUnavailable || busy`, described by `KILL_SWITCH_ID`, then `BUSY_REASON_ID`.
  - A disabled click sends nothing.
  - Sharing off does not block; the context is then `null`, as it is for Send.
- **Lines keep the composer gesture.** Home's attention lines keep 4.10's gesture (`onSuggestion` places the text in the composer).
- **DW-1147.** A refused (403) or faulted application-errors read answers an **unread** counted line: `Application errors in <NAMESPACE>: could not be read`, with no `<code>` count and the Open control kept. `showPrompts()` is false while any counted line is unread. The 403 is still never retried.
- **DW-1160.** The panel never renders a readable counted line whose count is 0, whatever `showPrompts()` answers.
- **Epic 12.** No edit to Epic 12's hunks in `panel.ts` (`:152`, `:896-906`, `:1066-1070`, `:1189`) or `strings.ts` (the `:1955` reference). Descriptor members are added directly after `commandAliases`, beside Epic 12's hunks and never inside them.

**Never:**

- No new tool, read, endpoint or server turn-path change: no `Api/Turn.cls`, `Kernel/Agent/**` or `Screen/Context.cls` edit.
- No prompt text written into a descriptor or a template: only keys.
- No hand edit of `screens.generated.ts`; it is regenerated.
- No change to Epic 9's eight declarations or their keys.
- No citation chips (11.4).
- No prompt rendering outside the greeting and Home's block.
- No live key in any test.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Screen idle | `permissions/users`, empty transcript | greeting, then the "Sign-in" group (1 prompt) and the "Access" group (2), then the hint | none |
| Choose | draft "keep me"; click "Which users hold %All?" | `POST /turn` message exactly that text, with the screen's context; draft "keep me"; transcript follows | none |
| Blocked | kill switch on | each prompt `aria-disabled="true"`, described by `KILL_SWITCH_ID`; click posts nothing | none |
| Sharing off | share off | click sends with `context: null` | none |
| Editor | `permissions/users/edit` | Epic 9's three prompts, grouped | none |
| Home all-zero | Home, empty transcript, errors count 0 | block: agent-status line, then the "Getting started" group's three prompts; greeting has no prompts | none |
| Home attention | errors count 4 | block: lines only; greeting: Home's three prompts | none |
| Refused read | dates read answers 403 | block line "Application errors in USER: could not be read", no `<code>`; no prompts in the block; no retry | none |
| Faulted read | dates read answers 500 | same line; one re-read parked; a later ok read replaces it | none |
| Zero line | a readable counted line with count 0 beside a non-zero one | the zero line is not rendered | none |
| Promptless screen | a built descriptor with no `suggestedPrompts` | `Registry.Validate` and `screen-mirror.mjs` refuse it with the rule sentence | build and test red |
| Unknown group | `groupKey: "misc"` | refused with the unknown-group sentence | build and test red |
| Unresolved route | the not-found route | greeting and hint, no prompts | none |

</intent-contract>

## Code Map

**Server side:**

- `src/OcuPilot/Screen/Registry.cls`:
  - `SuggestedPromptsProblem` `:564-612`, called at `:291`; `SUGGESTEDPROMPTSMIN` `:2253`.
  - Precedents: the built-only precedent is `SideBarPositionProblem` `:481`. The `DECLARATIONKEYS` comment `:374-382` lists optional keys.
  - `Validate` (`:137-340`) walks every descriptor. It is called only by tests: `Test/Descriptor.cls`, `OAuthTabs`, `ProcessTerminate` and `ReadTool`.
- `ui/tools/screen-mirror.mjs`:
  - `SUGGESTED_PROMPTS_MIN` `:1843`; `suggestedPromptsProblem` `:1852-1872`, called at `:2484`.
  - Precedent: `sideBarPositionProblem` `:1004`.
  - A throw in `buildMirror` aborts `--check` (`main` `:2995`). Emitted types are at `:2876` and `:2893`.
- `src/OcuPilot/Test/PromptCorpus.cls` -- the one corpus both engines read (`screen-mirror.test.mjs:625` reads it off disk). Its sound cases use group keys `g`/`h`, and no case carries `built`.
- `src/OcuPilot/Test/Descriptor.cls`:
  - `TestTheProductionRosterValidates` `:49`;
  - `TestAnUndeclaredSideBarPositionIsRefusedOnABuiltScreen` `:1082`, the pattern to copy;
  - `TestEveryPromptCorpusCaseGetsItsSentence` `:1250`.
- **Built fixture descriptors** validated through `Test.ScreenRegistry` subclasses (23 files):
  - `src/OcuPilot/Test/Screen/*` (8) and `ParentScope/**` (8);
  - `TabGroup/*` (2);
  - `ClassicLink`, `Refresh`, `RowTargetRoster`, `RowTargetShape` and `Tab` (1 each).

  Every file with `"built": true` needs prompts, or the later rules' expected refusals are pre-empted.
- `ui/tools/screen-mirror.test.mjs`:
  - `:104` resolves every declared key against `STRINGS`, shipped screens only;
  - `:625-650` is the prompts corpus and roster test;
  - `:1628` is the built-only refusal pattern.
  - 16 minimal `built: true` fixtures pass through `buildMirror`.

**Descriptors and strings:**

- `src/OcuPilot/Screen/Descriptor/*.cls`:
  - 53 descriptors, all built. The 8 declaring prompts are UserForm, RoleForm, WebAppForm, SslForm, ServiceForm, LdapConfigForm, TaskForm and AuditUserEventList.
  - The member sits directly after `"commandAliases"`; see `UserForm.cls:44-49`.
  - `Home.cls:47` holds `commandAliases`.
- `ui/src/app/core/strings.ts`:
  - flat `STRINGS`, with `/** EXPERIENCE.md:<n> */` above each key; values are unique;
  - `stringFor(key)` `:2202`; `homeStarterPrompt*` `:484-488` (row 331); `homeSuggestedApplicationErrors` `:482` (row 356);
  - new keys append before `} as const` (`:2189`).
- `ui/tools/strings.test.mjs`:
  - literals must equal the table's (`:556`, `:574-599`) and be unique (`:695`);
  - the reference check is `:744-789`;
  - the literal band is `:546-552`, upper bound 1000.
  - The only reference past the table is `taskCreate`'s `EXPERIENCE.md:555`.
- EXPERIENCE.md (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`):
  - the Fixed-strings table runs `:252-514`, and the last row is the 11.8 row at `:514`;
  - row `:356` is the errors line;
  - rows `:671` and `:673` are the State Patterns rows for the greeting and the Home suggested view.

**Client:**

- `ui/src/app/core/suggested-view.ts`:
  - `SuggestedLine` `:66-83`; `starterPrompts()` `:256-262` (removed by this story); `showPrompts()` `:269-272`;
  - `readApplicationErrors` `:318-345`, whose non-ok branch is `:329-336`.
  - Pinned by `ui/tools/suggested-view.test.mjs`: `:149`, `:161`, `:209`, `:216`, `:229`, `:237` and `:373`.
- `ui/src/app/shell/panel.ts` (contended):
  - block template `:330-368` (prompts `@for` `:358-365`); greeting `:394-407`;
  - getters `suggestedRows` `:1343`, `suggestedPrompts` `:1362`, `starterPrompts` `:1369`, `greetingVisible` `:1388`;
  - `onSuggestion` `:1435`;
  - `explainAriaDisabled` and `explainDescribedBy` `:1583-1593`; `onExplain` `:1679`; `sendWithContext` `:1712`; `assembleContext` `:1725`.
  - `screenForUrl` (`core/navigation.ts:664`) resolves built screens only, including Home (`''`).
- `ui/src/app/shell/panel.spec.ts`:
  - `describe('Story 4.10…')` `:2040-2734`. These tests pin today's starter behavior: `:2142`, `:2272-2292`, `:2295`, `:2314-2350` and `:2571-2595`.
  - The 11.1 registry-driven pattern is at `:4156`.
- `ui/browser/suggested-view.browser-spec.mjs:301-380` -- the gesture clicks the block's last row, which is a starter prompt on a clean log.
- Browser patterns to copy:
  - `ui/browser/explain-screen.browser-spec.mjs` (`recordedMessages`, `lastUserText`, `waitForReply`);
  - `ui/browser/turnprobe-spec.mjs` (`armProbeDefinition`, `scriptReply`).
- `ui/src/styles/_components.scss` -- `.ocu-suggested-starter` `:3358` and `:3429`; the `.ocu-panel-explain` disabled look is near `:3721`.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Screen/Registry.cls`:
  - Add `Parameter PROMPTGROUPKEYS` (the ten keys, comma-joined).
  - `SuggestedPromptsProblem`: absent or null answers the built sentence when `built` is 1, and "" otherwise.
  - After each prompt's empty-key checks, refuse a `groupKey` outside the vocabulary with the unknown-group sentence.
  - Update the doc comment and the `DECLARATIONKEYS` comment.
- `ui/tools/screen-mirror.mjs` -- the same two arms and an exported `PROMPT_GROUP_KEYS`, in the same order.
- `src/OcuPilot/Test/PromptCorpus.cls`:
  - The existing sound cases use vocabulary keys, and the absent and null cases gain `"built": false`.
  - Add three cases: built with none (refused), built with null (refused), and an unknown group (refused).
- `src/OcuPilot/Test/Descriptor.cls` -- add `TestAPromptlessBuiltScreenIsRefused` on the `:1082` pattern: a built value is refused, an unbuilt one is sound, and the production roster validates.
- The 23 built fixture files -- add a three-prompt `suggestedPrompts` using `promptGroupTroubleshooting`, and any `textKey`.
- `ui/tools/screen-mirror.test.mjs`:
  - a local `FIXTURE_PROMPTS`, spread into each built fixture;
  - a parity test that `Registry.cls`'s `PROMPTGROUPKEYS` equals `PROMPT_GROUP_KEYS`;
  - every shipped built screen has at least 3 prompts, each `groupKey` is in the vocabulary, and each key resolves.
- The 45 descriptors in Design Notes -- add `suggestedPrompts` after `commandAliases`, as the prompt table gives it. Keys:
  - `<descriptor class, first letter lower-cased>Prompt1..3`;
  - Home uses `homeStarterPromptExplainScreen`, `…ExplainLog` and `…ChangeOneThing` under `promptGroupGettingStarted`.
  - Then run `cd ui && node tools/screen-mirror.mjs`.
- `ui/src/app/core/strings.ts`, your own entries appended before `} as const`:
  - the four group keys;
  - 132 prompt keys;
  - `homeSuggestedApplicationErrorsUnread: 'Application errors in <NAMESPACE>: could not be read'`.
  Each carries its `/** EXPERIENCE.md:<n> */`. Renumber `taskCreate`'s `:555` by the rows added.
- EXPERIENCE.md:
  - After the 11.8 row, append one row with the four group labels, then one row per screen in the table order:
    `| "p1" · "p2" · "p3" | the <route> screen's suggested prompts (Story 11.3, AD-5): <Group> group, declared on its descriptor [ADDED 2026-09-25 - Story 11.3] |`
    Home gets no new row. Keep double quotes out of the Where cells.
  - Extend row `:356` in place with `· "Application errors in <NAMESPACE>: could not be read"`, and add to its Where: "or, when the read was refused or failed, the line saying so (DW-1147)".
  - Amend row `:671` in place. "the screen's three starter prompts" becomes "the screen's suggested prompts, grouped by task (Story 11.3)", and add "choosing a prompt sends it as a turn".
  - Amend row `:673` in place:
    - "with the same gesture" becomes "and choosing one sends it as a turn (Story 11.3)";
    - the last sentence becomes "The block keeps its prompt set on an empty transcript and the greeting then shows none, so one set shows at a time (DW-1158)";
    - add "a line whose read was refused or failed says so and stops the prompts (DW-1147); a zero line never renders (DW-1160)".
- `ui/tools/strings.test.mjs` -- raise the band's upper bound to 1100, with one comment line citing Story 11.3.
- `ui/src/app/core/suggested-prompts.ts` (new, framework-free, AD-19) -- `promptGroups(declaration)`. It returns `readonly {key, label, prompts: readonly string[]}[]`, resolved through `stringFor`, and `[]` for `null` or no prompts.
- `ui/tools/suggested-prompts.test.mjs` (new):
  - grouping order;
  - `[]` for null;
  - every built `SCREENS` entry yields at least 3 non-empty prompts, the label of each group a non-empty string.
- `ui/src/app/core/suggested-view.ts`:
  - `SuggestedLine.unread: boolean`, false on existing lines;
  - the non-ok branch answers the unread line (`counted: true`, `count: 0`, `label` the whole text, `tail: ''`) instead of `null`;
  - `showPrompts()` requires every counted line to be readable and 0;
  - delete `starterPrompts()`.
- `ui/tools/suggested-view.test.mjs`:
  - `:149`, `:161` and `:237` now expect the unread line and `showPrompts()` false;
  - drop `:216`'s `starterPrompts` assertion;
  - `:373` stays.
- `ui/src/app/shell/panel.ts`:
  - Add a `promptGroups` getter over `screenForUrl(this.router.url)`.
  - `homeBlockPrompts` = `suggestedVisible && suggested.showPrompts()`.
  - Block: after the lines, render the groups when `homeBlockPrompts`, and delete the `transcriptEmpty` yield.
  - Greeting: render the groups unless `homeBlockPrompts`.
  - Both use one shape: `.ocu-prompt-group[role=group]`, `.ocu-prompt-group-label`, then `.ocu-suggested-lines` of `.ocu-suggested-starter` buttons with the send glyph, and `onSuggestedPrompt(text)` with the Send gate.
  - `suggestedRows` drops readable zero counted lines regardless of `showPrompts()`.
  - The count `<code>` renders only when `counted && !unread`.
  - Remove `starterPrompts` and `suggestedPrompts`.
- `ui/src/styles/_components.scss` -- your own block: `.ocu-prompt-group` spacing, `.ocu-prompt-group-label` in `.ocu-suggested-eyebrow`'s type role (tokens only), and the `.ocu-suggested-starter[aria-disabled="true"]` look mirroring `.ocu-panel-explain`'s.
- `ui/src/app/shell/panel.spec.ts`:
  - Update 4.10's starter tests to the new placement and to "sends".
  - Append `describe('Story 11.3')` with each matrix row, plus a registry-driven leg on the `:4156` pattern. That leg covers every built screen including Home: rendered prompts equal the declaration's, and groups follow first-appearance order.
- `ui/browser/suggested-view.browser-spec.mjs` -- the gesture clicks the last `.ocu-suggested-prompt` line, never a prompt. The clean-log branch reads the group's prompts.
- `ui/browser/suggested-prompts.browser-spec.mjs` (new) -- two legs:
  - (a) On `permissions/users`, with the probe definition and an empty transcript, clicking a prompt records the last user text equal to it, and the reply renders.
  - (b) Home shows exactly one prompt set of at least three.

**Acceptance Criteria:**

- **AC1.** Given any built screen with the panel idle and the transcript empty, when the panel renders, then it offers the screen's declared prompts (at least three), grouped by task.
  - Pinned by the registry-driven panel leg, `suggested-prompts.test.mjs` and browser (a).
- **AC2.** Given a suggested prompt, when the user chooses it, then it is sent as a turn whose user message is exactly its text, the draft is unchanged, and a blocked prompt sends nothing.
  - Pinned by the panel spec and browser (a).
- **AC3.** Given the screen contract, when a built descriptor declares no prompts or names a group outside the vocabulary, then `Registry.Validate` and `screen-mirror.mjs` both refuse it, with the same sentence.
  - Pinned by `PromptCorpus`, `Descriptor` and `screen-mirror.test.mjs`.
- **AC4.** Given Home in any state, when it renders, then exactly one prompt set shows, and it is the block's when the block offers one (DW-1158).
- **AC5.** Given a refused or faulted counted read, when Home renders, then the line says it could not be read and no block prompts show (DW-1147). A readable zero counted line never renders (DW-1160).
- **AC6.** Given 11.1's explain legs, 11.2's entry legs and 4.10's line gesture, when they run, then they stay green. The only edits are the 4.10 starter tests named above.

### Review Findings

Code review 2026-09-25, `review_tier: full-opus`, four layers (blind, edge case, verification gap, acceptance). 0 decision-needed, 6 patch (all applied), 3 ledgered, 14 rejected.

- [x] [Review][Patch] (medium) The block's Busy leg could not fail with the busy half of the prompt guard removed, because the store refuses the second send itself [ui/src/app/shell/panel.spec.ts:4453] -- asserts the lock banner stays away, as 11.1's leg does.
- [x] [Review][Patch] (medium) "Home never answers" could not observe the "no fallback" it names in three microtask ticks [ui/src/app/shell/panel.spec.ts:4546] -- fake timers now run ten minutes past mount.
- [x] [Review][Patch] (low) Row `:718` said an unread line "stops the prompts"; the greeting still offers them, so it now says the block's [EXPERIENCE.md:718]
- [x] [Review][Patch] (low) Row `:716` was amended with no marker [EXPERIENCE.md:716]
- [x] [Review][Patch] (low) `TurnStore.restored()` and the file header said `restore()` runs once, at bootstrap; `app.ts` now also runs it after sign-out [ui/src/app/core/turn.ts:11, :880]
- [x] [Review][Patch] (low) The refused-read assertion message still read "no zero, no skeleton row" [ui/tools/suggested-view.test.mjs:170]
- [x] [Review][Defer] (low) Home's greeting is promptless while the view never answers [ui/src/app/shell/panel.ts:1402] -- DW-1678 wontfix-accepted.
- [x] [Review][Defer] (low) A send during the bootstrap restore abandons it [ui/src/app/core/turn.ts:934] -- DW-1679 wontfix-accepted.
- [x] [Review][Defer] (low) Fixed-strings row `:331` still says Home's prompts show only when nothing needs attention [EXPERIENCE.md:331] -- DW-1680, open for the lead (a row this story did not add).

Rejected:

- `false`: `declaredGroups` in `panel.spec.ts` re-implements `promptGroups` and would share its bugs. It never calls the production function, so a grouping bug in `promptGroups` fails the registry leg.
- `low`: interleaved groups render prompt 1, 3, then 2, unlike the row order. This is the spec's Grouping rule, and a row lists strings, not layout.
- `low`: DESIGN.md does not describe the group label or the disabled prompt. The spec does not task it, and the label reuses the eyebrow type role as the Tasks direct.
- `low`: the unread line keeps the composer gesture. By design: "Lines keep the composer gesture".
- `low`: a repeated `textKey` is not refused, and `track prompt` would see duplicates. No descriptor repeats a key, and `STRINGS` values are unique.
- `low`: the corpus lost its case with no `built` key. Both engines compare against true, and the production roster pins the sound built path on both sides.
- `low`: the vocabulary keys carry Epic 9's screen names. By design (the spec keeps Epic 9's six keys); their labels have rows from Epic 9.
- `low`: nothing tells a screen-reader user that a prompt sends. The turn's live transcript announces the send, and a fix needs a new string row.
- `low`: moving the sign-out restore into `endSession()` would change behavior in contended `turn.ts`. The `app.ts` line is correct and minimal, `app.spec.ts` pins it, and it merges cleanly with Epic 12.
- `low`: `Registry.Validate`'s call to the rule has no Validate-level refusal test. The wiring predates this story, and the test follows the `SideBarPositionProblem` precedent.
- `low`: AC6's list of edited 4.10 tests omits the refused-read leg AC5 required. The fix would edit the spec.
- `low`: `built: 1` is refused by one engine and not the other. This is the existing `sideBarPosition` precedent, and every descriptor declares JSON `true`.
- `low`: Home shows no set with a non-empty transcript and an attention line. That state is not idle, and 4.10 designed it that way.
- `low`: AC4's "exactly one" is really "at most one". The fix would edit the spec, and DW-1678 covers the never-answers state.

- [x] [Merge] Epic 12 merged into the branch (521e3f72) with five new built form screens that declare no suggested prompts, so `screen-mirror.mjs` and `Screen/Registry.cls` refuse them (by design, AC3): `OAuthClientForm`, `OAuthResourceServerForm`, `OAuthServerClientForm`, `OAuthServerDescriptionForm`, `OAuthServerForm` under `src/OcuPilot/Screen/Descriptor/`. Declare three prompts each exactly as this story did for Epic 9's editors (existing group keys, `strings.ts` entries appended at this story's block end, one EXPERIENCE.md Fixed-strings row per screen appended at the table's end, citations resolving, `strings.test.mjs` green); regenerate `screens.generated.ts` with `screen-mirror.mjs`; `field-lists.mjs --check` and `ipm-manifest.mjs --check` stay up to date. Verify: mirror `--check` up to date, `Descriptor` green on `ocupilot-ci` after a whole-package recompile, `test:tools`, `test:components`, and the `suggested-prompts` browser spec against a rebuilt, redeployed bundle.

### Review Findings (rework 1 re-review)

Code review 2026-09-25 of `c7eb5d26..HEAD`, `review_tier: full-opus`, three layers (edge case, verification gap, acceptance; blind skipped on a data-only diff). 0 decision-needed, 3 patch (all applied), 0 ledgered, 2 rejected. The `[Merge]` item is confirmed fixed.

- [x] [Review][Patch] (low) The built-roster floors still read 53 while the mirror holds 58, so dropping an OAuth form stayed green [ui/tools/screen-mirror.test.mjs:685, ui/tools/suggested-prompts.test.mjs:48, ui/src/app/shell/panel.spec.ts:4691] -- raised to 58.
- [x] [Review][Patch] (low) The `[Merge]` item's strings and EXPERIENCE.md half had no `mutation:` line [spec ## Verification] -- written after observing red.
- [x] [Review][Patch] (low) The rework triage header counted `false 3` over four `[false]` rows [spec ## Review Triage Log] -- now `false 4`.

Rejected:

- `low`: the forms' prompts assume a saved object, though `/edit` with no name opens create mode. By design: one prompt set per screen, and the Role, User and WebApp forms word theirs the same way.
- `low`: the registry-driven panel leg cannot see a missing text key, since both sides resolve through `stringFor`. `screen-mirror.test.mjs`'s resolve case pins every key.

## Spec Change Log

- 2026-09-26, rework iteration 1 (trigger integrate_forward): Epic 12's merge brought five built form screens with no prompts; one `[Merge]` item re-opens the spec.
- 2026-09-25, lead spec gate: the proposed AD-5 amendment is written into the spine (Rule 20). The EXPERIENCE.md rewordings (`:671`, `:673`, `:356`) are accepted as Rule 5 tier-1 apply-and-report edits; the implement stage makes them.

## Review Triage Log

### 2026-09-25 — Review pass

- verdicts: 8 findings — high 0, medium 3, low 4, false 1, maybe-false 0
- findings:
  - `[medium]` `[patch]` Browser (b) could not fail on a throwaway whose log holds errors, so AC4's browser pin was vacuous there — (b) now signs in on Users, answers the dates read `{rows: []}` in the page and asserts the set is the block's and the greeting has none; red under the AC4 mutation on the redeployed bundle.
  - `[low]` `[patch]` AC6 had no `mutation:` line — recorded: `onSuggestion` no longer sets the draft -> 4.10's line-gesture leg red.
  - `[medium]` `[patch]` On Home the greeting painted Home's set while the suggested view was in flight, then the set moved into the block — new `greetingPrompts` holds the greeting's set on Home until the view answers; panel leg "Home in flight" added, red under its mutation.
  - `[low]` `[reject]` `strings.ts`'s `taskCreate` reference (`:1955`) was renumbered, the line Epic 12 also renumbers — forced by the Tasks and by `strings.test.mjs`'s reference check once rows land at the table's end; Design Notes ("Epic 12 at merge") and `footprint_extensions` accept it, and the merge re-derives that one line.
  - `[false]` `[reject]` `app.ts` changes outside the named surfaces — no bad outcome: sign-out left `restored()` false, so no greeting or prompts rendered after an interactive sign-in; `void this.turn.restore()` fixes that, pinned in `app.spec.ts`, and merges cleanly with Epic 12's `app.ts` (merge-file check).
  - `[low]` `[reject]` Most matrix rows are proven in jsdom, and browser (a) checks neither the kept draft nor the context — the spec's browser tier is (a) and (b); the draft and context are pinned by the panel "Choose" and "Sharing off" legs over the same Send path, and no failure mode here depends on layout.
  - `[low]` `[reject]` The panel "Faulted read" leg re-loads rather than driving the parked re-read — the park and the recovery it brings are pinned in `suggested-view.test.mjs`; wiring connectivity into the panel harness adds machinery for no new failure.
  - `[medium]` `[patch]` (intent-alignment) Home's set can move from the greeting to the block — same root cause and fix as the third row.

### 2026-09-25 — Review pass (rework 1, [Merge])

- verdicts: 6 findings — high 0, medium 0, low 2, false 4, maybe-false 0
- findings:
  - `[low]` `[reject]` (verification-gap) The spec did not yet record this pass: `[Merge]` unticked, no `mutation:` line, stale Auto Run Result — the fix is a spec edit; the finalize step ticks the item, writes the mutation line and this pass's result.
  - `[false]` `[reject]` (intent-alignment) No component or browser test renders an OAuth edit route — the registry-driven panel leg (`panel.spec.ts:4689-4699`) mounts every built screen, the five forms included, and asserts the rendered groups equal the declaration.
  - `[false]` `[reject]` (intent-alignment) "Rotate keys" and "client secret regenerated" sit under Sign-in though about other tasks — both are OAuth authentication settings, and the five OAuth tabs use the same Sign-in group.
  - `[false]` `[reject]` (intent-alignment) The 15 keys sit before `homeSuggestedApplicationErrorsUnread`, not at the block's literal end — they extend the contiguous prompt run; no reader, test or merge diverges.
  - `[low]` `[reject]` (intent-alignment) `strings.ts`'s `taskCreate` reference (`:1955`) was renumbered — carried: same claim as the 2026-09-25 row; forced by the reference check once rows land at the table's end (`:608` -> `:613`).
  - `[false]` `[reject]` (intent-alignment) The form row says "redirect URLs" where the tab row says "redirect addresses" — the form uses its own field label (`oauthClientFieldRedirect` 'Redirect URL').

### 2026-09-25 — Review pass (rework 1 re-review)

- verdicts: 5 findings — high 0, medium 0, low 5, false 0, maybe-false 0
- findings: 3 patched, 2 rejected; see `### Review Findings (rework 1 re-review)`.

## Design Notes

**Governing ADs:**

- AD-5: the descriptor is the one source, and the mirror is generated.
- AD-11 rule 1: the prompts are fixed build-time user text.
- AD-19: `suggested-prompts.ts` lives in `core/`.
- AD-24: the context is Send's.
- AD-29 and AD-8: a refused read is reported, never read as zero, and never retried.
- AD-44: not engaged.

**Proposed spine amendment (Rule 20, for the lead):** in AD-5's list of what a descriptor carries, after "command-box aliases", add "and, on a built screen, at least three suggested prompts grouped by task from a closed group vocabulary, refused identically by `Screen/Registry.cls` and `ui/tools/screen-mirror.mjs` (Story 11.3)".

**Why strings.ts, not descriptor text.** The epic context binds every user-visible string to `strings.ts` and EXPERIENCE.md, and Epic 9 already ships eight declarations on that contract. Literal text in descriptors would be a second contract. The cost is 45 appended rows. They shift only one reference past the table.

**Why the check lives in the rule.** It follows `SideBarPositionProblem`'s built-only precedent, so it pins fixtures and production alike. A production-only switch would be a special case that reviewers could not see.

**Epic 12 at merge.** Epic 12's five OAuth editor descriptors declare no prompts, so both checks go red at the merge until they declare them. That is intended: the merge is visibly incomplete, never silently promptless. Epic 12 also appends Fixed-strings rows and `STRINGS` keys at the same tails, sets the band at 1200 and renumbers `:555`. The merge takes both sides and re-derives the band and that reference.

**Prompt table.** Each line gives the descriptor, its group, and its three prompts in order. A group per prompt is marked in brackets.

Group abbreviations:

- T = `promptGroupTroubleshooting`
- C = `promptGroupCapacity`
- G = `promptGroupAgentSetup`
- A = `userPromptGroupAccess`
- S = `userPromptGroupSignIn`
- N = `sslPromptGroupConnections`
- K = `webAppPromptGroupCode`
- D = `taskPromptGroupSchedule`
- U = `auditUserEventPromptGroup`

The table:

- Home -- `promptGroupGettingStarted`: the existing three.
- AgentDefinitionList G: "Which agent definition is the default, and which model does it use?" / "Is any agent definition disabled or not yet verified?" / "Where does each definition send screen context?"
- AgentDefinitionForm G: "What does each setting on this definition control?" / "Does this definition send data off this instance?" / "Which model suits this provider for everyday questions?"
- AgentSwitches G: "Is the agent read-only or switched off right now?" / "What does the kill switch stop?" / "How many rows of screen context does the agent send?"
- LogAlertViewer T: "Which alerts are the most recent, and what caused them?" / "Are any alerts repeating?" / "Which of these alerts need action?"
- LogMessageViewer T: "Summarize the warnings and errors in messages.log." / "Did the instance restart recently, and why?" / "Which messages point to a configuration problem?"
- LogErrorList T: "Which namespace has the most application errors?" / "What is the most common application error here, and where does it come from?" / "Which of these errors can I safely delete?"
- AuditList U: "Were there any failed sign-ins recently?" / "Which changes did the agent make?" / "Who changed security settings today?"
- AuditingConfig U: "Is auditing turned on for this instance?" / "What stops being recorded if auditing is turned off?" / "Which audit events are turned off?"
- AuditSystemEventList U: "Which system events are enabled?" / "Which system events record failed sign-ins?" / "Which system events have recorded the most?"
- LdapConfigList S: "Which LDAP configurations are enabled?" / "Which LDAP configuration do users sign in through?" / "Does any LDAP configuration connect without TLS?"
- SslConfigList N: "Which SSL/TLS configurations are enabled?" / "Which configurations do not verify the server certificate?" / "Which configuration does OcuPilot use to reach its provider?"
- X509CredentialList N: "Which X.509 credentials expire soonest?" / "Has any credential already expired?" / "Which credentials carry a private key?"
- X509Form N: "When does this credential expire?" / "Who issued this certificate?" / "Does this credential carry a private key?"
- WalletCollectionList A: "Which wallet collections hold secrets?" / "Who can use the secrets in each collection?" / "What is the secrets wallet for?"
- WalletSecretList A: "Which secrets does this collection hold?" / "Which hosts may use these secrets?" / "Which of these secrets require TLS?"
- WalletSecretForm A: "What kind of secret is this?" / "Which hosts may use this secret?" / "Does this secret require a TLS connection?"
- OAuthServerDescriptionTab S: "Which OAuth 2.0 servers does this instance trust?" / "Which server descriptions have no client configured?" / "What is an OAuth 2.0 server description for?"
- OAuthClientTab S: "Which OAuth 2.0 clients are configured, and for which servers?" / "Which clients are confidential and which are public?" / "Which scopes does each client ask for by default?"
- OAuthResourceServerTab S: "Which resource servers are configured?" / "Which server does each resource server accept tokens from?" / "What does an OAuth 2.0 resource server do?"
- OAuthServerTab S: "Is this instance acting as an OAuth 2.0 authorization server?" / "Which grant types does this server allow?" / "How long do access tokens from this server last?"
- OAuthServerClientTab S: "Which clients are registered with this authorization server?" / "Which redirect addresses does each client use?" / "Which clients may use the client credentials grant?"
- UserList: [S] "Which accounts are disabled or expired?" / [A] "Which users hold %All?" / [A] "Which users hold an administrative role?"
- RoleList A: "Which roles grant %All?" / "Which roles does no user hold?" / "Which roles grant write access to a database?"
- ResourceList A: "Which resources grant access to everyone?" / "Which resources protect databases?" / "Which resource guards the Management Portal?"
- ServiceList: [N] "Which services are turned off?" / [S] "Which services accept a sign-in without a password?" / [N] "Which services limit the addresses that may connect?"
- WebAppList: [A] "Which web applications can be reached without signing in?" / [A] "Which web applications grant %All to their users?" / [K] "Which class answers each REST web application?"
- RestApiList K: "Which REST APIs does this namespace publish?" / "Which web application serves each REST API?" / "Which REST APIs have an OpenAPI document?"
- OpenApiViewer K: "Summarize the operations this API offers." / "Which operations change data?" / "Which operations need authentication?"
- DatabaseList C: "Which databases are close to their maximum size?" / "Which databases are not journaled?" / "Which databases are mounted read-only?"
- DatabaseDetails C: "How much free space does this database have?" / "Is this database journaled?" / "Can this database be written, or is it read-only?"
- DatabaseVolumeList C: "How many volumes does this database have?" / "Which volume is the largest?" / "Where are the volume files for this database?"
- DatabaseFreeSpace C: "Which database has the least free space?" / "How much disk space is free for each database?" / "Which databases could be compacted?"
- DeviceList N: "What is each device on this list used for?" / "Which devices are printers?" / "Which devices write to a file?"
- DeviceForm N: "What does this device type mean?" / "Which settings on this device matter most?" / "Which open mode should this device use?"
- LockList T: "Which processes hold the most locks?" / "Is any process waiting for a lock?" / "Which globals are locked right now?"
- ProcessList T: "Which processes are doing the most work right now?" / "Is any process stuck or waiting?" / "Which processes belong to users rather than the system?"
- ProcessDetails T: "What is this process doing right now?" / "Is this process waiting on something?" / "Is it safe to terminate this process?"
- SystemUsage C: "Is this instance under load right now?" / "Which figure here should I watch most closely?" / "Is the license close to its limit?"
- TaskScheduleList: [T] "Which tasks are suspended, and why?" / [D] "Which tasks run tonight?" / [T] "Which tasks failed on their last run?"
- TaskDetails: [D] "When does this task run next?" / [T] "Why did this task last fail?" / [D] "What does this task do?"
- TaskRunList: [T] "Has this task failed recently?" / [D] "How long does this task usually take?" / [T] "When did this task last succeed?"
- TaskOnDemandList D: "What does each on-demand task do?" / "Which on-demand tasks have never run?" / "Which on-demand task ran most recently?"
- TaskUpcomingList D: "What runs in the next hour?" / "Which tasks run overnight?" / "Do any upcoming tasks run at the same time?"
- TaskHistoryList T: "Which task runs failed this week?" / "Which task takes the longest to run?" / "Did any task stop with an error today?"

**amendments (Rule 5, apply-and-report):** EXPERIENCE.md rows `:671` and `:673` are restated in place to match AC2 ("sends as a turn") and the DW-1158 owner decision. Row `:356` gains the DW-1147 literal. No AC, AD or scope changes.

**Integration ACs.**

- **Consumes:**
  - Epic 9's `suggestedPrompts` contract and the generated mirror;
  - 11.1's `sendWithContext` and `assembleContext`;
  - 4.10's `SuggestedView`.

  The consumer ACs run on the throwaway in browser (a) and (b).
- **Consumed-by:**
  - Epic 12's five editor descriptors, at the merge;
  - every later screen (AC3);
  - 17.7, the owner's live check.

**Ledger inbox:**

- DW-1158 is addressed by AC4 and the matrix's Home rows.
- DW-1147 is addressed by AC5 and the matrix's refused and faulted rows.
- DW-1160 is addressed by AC5 and the matrix's zero-line row.

**footprint_extensions:**

- **Contended**, off Epic 12's hunks:
  - `panel.ts`, `panel.spec.ts`;
  - `strings.ts` (own entries plus the `:555` reference);
  - `screens.generated.ts` (regenerated);
  - the OAuth tab, `AuditingConfig` and `UserList` descriptors (one member each).
- **Outside Epic 11's footprint:**
  - `Registry.cls`, `screen-mirror.mjs`, their tests and corpus, and the 23 fixtures;
  - the other descriptors;
  - `suggested-view.ts` and its test, `core/suggested-prompts.ts`;
  - `strings.test.mjs` (the band), `_components.scss` (own block);
  - EXPERIENCE.md (rows appended; `:356`, `:671` and `:673` in place);
  - `browser/suggested-view.browser-spec.mjs`.

## Verification

**Slot and instance.** Slot A; every IRIS MCP call carries `server: "ocupilot-slot-a"`. Stateful checks run on `ocupilot-ci` only.

- Load with `bash /tmp/epic-11-lead/load.sh` and read `LOADRESULT`/`ERRCOUNT`.
- Before any browser run: `cd ui && npm run build`, then `docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/`, with `OCUPILOT_BROWSER_ORIGIN=http://localhost:52776` and `OCUPILOT_BROWSER_CONTAINER=ocupilot-ci` exported.
- Bundle budget: see the standing ruling (a warning at 1670 kB).

**Commands:**

- `uv run scripts/check-objectscript.py && bash scripts/lint-docs.sh` -- expected: clean.
- `cd ui && node tools/screen-mirror.mjs --check` -- expected: clean after regeneration.
- **(loop)** One class per call: `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, for `Descriptor`, `OAuthTabs`, `ProcessTerminate`, `ReadTool`, `ServiceUpdate`, `LdapUpdate` and `TaskCreate`.
  - Expected: green, confirmed by the `%UnitTest_Result` probe, and never re-submitted.
- **(loop)** `cd ui && npm run test:tools && npm run test:components` -- expected: green.
- **(loop)** `cd ui && node --test --test-concurrency=1` over `browser/suggested-prompts`, `suggested-view`, `explain-screen` and `a11y-structural-invariants` (`.browser-spec.mjs`), against the redeployed bundle. Expected: green.
- **(once, before dev_complete)** The full ObjectScript sweep on `ocupilot-ci`, one class at a time, reported as "N ran, 13 refused (arming), 1 known residue". Then `bash scripts/smoke.sh --container ocupilot-ci --user _SYSTEM --password SYS`. The full browser suite runs in CI only.

**Pinning mutations (Rule 19).** Apply each, rebuild or recompile the whole package, observe red, revert, and confirm `git status --short` is unchanged. Record each as `mutation: ... -> ...`.

- AC1: the `promptGroups` getter returns `[]` off Home → the registry-driven panel leg goes red, and browser (a) goes red.
- AC1 grouping: `promptGroups` puts every prompt in the first group → `suggested-prompts.test.mjs` goes red.
- AC2: `onSuggestedPrompt` calls `onSuggestion` → the panel "sends" leg goes red, and browser (a) goes red.
- AC2 gate: drop `composerUnavailable` from the prompt gate → the panel kill-switch leg goes red.
- AC3 built: drop the built arm on both sides → `Descriptor` goes red, and the `screen-mirror.test` corpus goes red.
- AC3 vocabulary: drop the group arm → the unknown-group corpus case goes red on both sides.
- AC4: the greeting ignores `homeBlockPrompts` → the panel "exactly one prompt set" leg goes red, and browser (b) goes red.
- AC5 DW-1147: the non-ok branch answers `null` → the `suggested-view.test.mjs` refused and faulted legs go red, and the panel refused leg goes red.
- AC5 DW-1160: `suggestedRows` filters only under `showPrompts()` → the panel zero-line leg goes red.

**Recorded mutations (implement stage, 2026-09-25).** Each was reverted byte-identical (`git status --short` and `git diff --stat` compared).

- mutation: `promptGroups` getter answers `[]` off Home -> panel "Screen idle", "Choose", "Blocked", "Sharing off", "Editor" and the registry-driven AC1 leg red; browser (a) red.
- mutation: `promptGroups()` puts every prompt in the first group -> `suggested-prompts.test.mjs` grouping-order test red.
- mutation: `onSuggestedPrompt` calls `onSuggestion` -> panel "Choose", "Busy", "Sharing off" and 4.10's AC6 send leg red; browser (a) red.
- mutation: `composerUnavailable` dropped from `promptAriaDisabled` -> panel "Blocked" (kill switch) leg red.
- mutation: built arm dropped from `Registry.SuggestedPromptsProblem` -> `Descriptor` `TestAPromptlessBuiltScreenIsRefused` and `TestEveryPromptCorpusCaseGetsItsSentence` red (run 12968).
- mutation: built arm dropped from `suggestedPromptsProblem` -> `screen-mirror.test.mjs` PromptCorpus test red.
- mutation: group arm dropped from `Registry.SuggestedPromptsProblem` -> `Descriptor` `TestEveryPromptCorpusCaseGetsItsSentence` red on "a group outside the vocabulary" (run 12969).
- mutation: group arm dropped from `suggestedPromptsProblem` -> `screen-mirror.test.mjs` PromptCorpus test red on "a group outside the vocabulary".
- mutation: the greeting renders its groups whatever `homeBlockPrompts` answers -> panel "Home all-zero", 4.10's fresh-container leg and the registry-driven AC1 leg red; browser (b), whose dates read is answered clean in the page, red ("the greeting offers none").
- mutation: the non-ok branch of `readApplicationErrors` answers `null` -> `suggested-view.test.mjs` refused, faulted, re-read and DW-1147 tests red; panel "Refused read", "Faulted read" and 4.10's AC2 leg red.
- mutation: `suggestedRows` drops readable zero lines only under `showPrompts()` -> panel "Zero line" leg red.
- mutation: `void this.turn.restore()` dropped after `turn.endSession()` in `app.ts` -> `app.spec.ts` sign-out leg red.
- mutation: `greetingPrompts` drops its Home read gate (answers `true` once the block shows none) -> panel "Home in flight" red.
- mutation (AC6): `onSuggestion` no longer sets the draft -> 4.10's "AC3: a line has two distinct controls" leg red.

**QA gap coverage (this pass).** The implement stage's coverage was reviewed against browser (b)'s
faked dates answer and the matrix; the only gap was a read that never settles at all (distinct from
"in flight", which does settle). A component-tier pin was added to `ui/src/app/shell/panel.spec.ts`
`(QA)`: "Home never answers: the greeting and the block both stay promptless, with no fallback" —
`requestJson` returns a promise that never resolves, and after several ticks neither the greeting
nor the block paints a prompt group. "The one set" rule (component tier: "Home all-zero", "Home
attention") and DW-1147's refused/faulted line (component tier: "Refused read", "Faulted read";
unit tier: `suggested-view.test.mjs`'s DW-1147 test) already had real-runtime pins independent of
browser (b)'s stub and needed no new test. AC2 on a non-Home screen at the browser tier and every
I/O matrix row were already pinned (browser (a); the `panel.spec.ts` Story 11.3 suite).

- mutation (QA): `greetingPrompts` drops its `onHome` read gate (answers `true` unconditionally once
  the block shows none) -> panel "Home never answers" red (confirmed; reverted byte-identical).
- mutation (code review): `greetingPrompts` also answers `true` once a 30-second timer fires -> panel
  "Home never answers" red alone ("Home in flight" stays green); reverted byte-identical.
- mutation (rework 1, [Merge]): `OAuthServerForm`'s `suggestedPrompts` removed -> `screen-mirror.mjs --check`
  refuses ("a built screen declares at least 3 suggestedPrompts") and `Descriptor` 7/52 red after a whole-package
  recompile (run 13228; incl. `TestTheProductionRosterValidates`, `TestAPromptlessBuiltScreenIsRefused`); reverted
  byte-identical, recompiled, `Descriptor` 52/52.
- mutation (code review, rework 1): EXPERIENCE.md :571 (`OAuthServerForm`'s row) deleted -> `strings.test.mjs`
  "holds nothing the documents do not authorize" and "every EXPERIENCE.md line reference resolves" red (23/25);
  restored byte-identical (`cmp`).
- mutation (code review): `onSuggestedPrompt` guards on `composerUnavailable` only -> panel block
  "Busy" leg red alone (the lock banner shows); reverted byte-identical.

**Manual check (extra evidence, never the proof).** Use the owner's live-key rules. On `tasks/schedule`, with a live Anthropic definition, choose "Which tasks are suspended, and why?". The reply answers from the screen or the read tool and proposes nothing.

## Auto Run Result

Status: done
Blocking condition: none

**Change (rework 1, [Merge]).** Epic 12's five OAuth form screens (`OAuthServerDescriptionForm`, `OAuthClientForm`, `OAuthResourceServerForm`, `OAuthServerForm`, `OAuthServerClientForm`) each declare three Sign-in prompts after `commandAliases`; 15 `STRINGS` keys follow this story's prompt run; five Fixed-strings rows are appended at EXPERIENCE.md:568-572, and `taskCreate`'s reference moves `:608` -> `:613`; `screens.generated.ts` is regenerated (58 descriptors). The story's first pass closed at `a2398262`.

**Review.** 6 findings: 0 patched, 0 deferred, 6 rejected (2 low, 4 false; reasons in the triage log). Follow-up review recommended: `false` (follow-up pass, no high patched).

**Verification.** `screen-mirror`, `field-lists`, `ipm-manifest` `--check` up to date; `check-objectscript` 0 problems; `lint-docs` clean. `test:tools` 1454/1454; `test:components` 1436/1436. `load.sh` on `ocupilot-ci` ERRCOUNT 0; `Descriptor` 52/52 (run 13227, and 13229 after the mutation revert). Build initial total 1,836,390 B (1.84 MB); redeployed; `suggested-prompts` browser spec 2/2. `smoke.sh --container ocupilot-ci`: 49/49 passed. No full sweep this pass (lead's scope). Mutation: see `## Verification`.

**footprint_extensions:** Epic 12's five OAuth form descriptors (the `suggestedPrompts` member only); `strings.ts` (own entries plus the `taskCreate` reference); `screens.generated.ts` (regenerated); EXPERIENCE.md (five rows appended).
