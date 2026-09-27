---
title: 'Story 16.22: The Guardrails page'
type: 'feature'
created: '2026-09-27'
status: 'ready-for-dev'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-16-context.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** OcuPilot's guardrails are enforced on the instance, but a person sees one only when it refuses something. A judge or an administrator deciding whether to trust the agent has nothing to read.

**Approach:** Add a read-only Guardrails screen, third in the Agent co-pilot side bar and open to every signed-in user. It renders one shell-chrome answer, `GET /ui/guardrails`, which the instance composes from the declarations that already enforce: the prohibited set's codes and sentences, the tool registry's advertised write tools and their declared secret arguments, the caller's restraint verdict, and the context caps. Nothing on the page is written a second time.

## Boundaries & Constraints

**Always:**

- **One home for every rule (AD-10, AD-53).** The refused list is `Codes()` in declared order, and each sentence is `ReasonFor(code)`. Both are reached through `OcuPilot.Kernel.Proposal.Write.ProhibitedClass()`. The client holds no copy of any refusal sentence.
- **Guardrails.cls must not spell the literal `PROHIBITED.`**, not even in a comment. `Test/Prohibited.cls:682-706` refuses it outside the set and the tests, and it refuses a second written copy of any sentence, test classes included. Tests therefore compare against `ReasonFor`, never against a literal.
- **"Needs a Confirm" is the registry's classification (AD-22).** It is the `ListTools` entries with `kind` `"write"` and `advertised` true, in name order, each carrying `descriptor` = `$Parameter(class,"DESCRIPTORCLASS")`.
- **"Never seen" is generated.** It is `Registry.SecretArguments(entry, .declared)` for each advertised write tool, listing only tools with at least one name. `declared` 0 is an error, never "no secrets".
- **The switches are the caller's own verdict.** They come from `Kernel.Restraint.Resolved($Username, .v)`, the same call `GET /agent/restraint` makes, and only its `killSwitch`, `killSwitchAudience` and `enforcedReadOnly` subscripts are read.
- **The limits are the kernel's own values.** `contextRowCap` comes from `Kernel.State.Switch.Resolve`, and the two character caps from `Kernel.Agent.Limits` `TOOLRESULTMAXLENGTH` and `FIELDMAXLENGTH`.
- **Fail closed.** Any failed part makes the route answer 500 through `Error.RenderInternal`, never a partial body. The page then shows `STRINGS.connectivityServerFault` and no sections.
- All copy is new Fixed strings (see Design Notes), and every value is rendered as text.
- Rows that can be long wrap without horizontal overflow at 720 px (`overflow-wrap: anywhere` on code-face names).

**Never:**

- No declared read, no read tool, no `table` and no screen-context rows (see Design Notes).
- No change to `Prohibited.cls`, `Restraint.cls`, `Api/Switches.cls`, `Error.cls`, `Prompt.cls`, `panel.ts`, `agent-status.ts` or `Screen/Tool/Registry.cls`. No governance policy keys: Story 14.2 is not merged, so this story does not show them. No "Read-only for me" (14.5).
- No new archetype, no lazy route or `@defer`, and no structural-baseline entry.
- Stay off Epic 14's hunks:
  - `Router.cls`: the route after `/agent/restraint` :73, and the thin target after `AgentRestraint`.
  - `EndpointCoverage.cls`: around :82 and its `/proposal/:id/draft` row.
  - `strings.ts`: :166-177 and after :230/:564.
  - `_components.scss`: the data-table block near :3968 and :3505-3720.
  - EXPERIENCE.md: :289 and :335.

## I/O & Edge-Case Matrix

| Scenario | State | Expected | Error |
|---|---|---|---|
| Default | fresh `ocupilot-ci` | 200 `{prohibited[18 in Codes() order], switches{false,"",false}, confirmTools[...], secrets[...], limits{200,65536,1000}}`; page shows all five sections | none |
| Rule added | fixture Prohibited adds a code and a sentence | the row appears last with that sentence, and nothing else is edited | none |
| Kill switch | global on / the caller's hold | "Kill switch: on for everyone" / "Kill switch: on for you" | none |
| Enforced read-only on, cap 150 | set on `ocupilot-ci`, restored after | "Enforced read-only: on"; the limits line reads 150 | none |
| Unadvertised write tool | `security.auditing.purge` | absent from both tool lists | none |
| A part unreadable | switch read, registry or secret declaration fails | 500 envelope; the page shows the fault line and no sections | `RenderInternal` |
| Least-privileged caller | holds nothing of OcuPilot's | 200, the same body shape; the side bar lists the page as allowed | none |

</intent-contract>

## Code Map

Server:

- `src/OcuPilot/Kernel/Proposal/Prohibited.cls`:
  - `Codes()` :470 returns 18 codes;
  - `ReasonFor` :478 (every sentence is a `*REASON` parameter except `UNCOVERED`'s, which is inline at :497).
- `Kernel/Proposal/Write.cls`: `ProhibitedClass()` is the seam 16.21's `Findings` also takes.
- `src/OcuPilot/Screen/Tool/Registry.cls`:
  - `ListTools(.pTools)` :106 returns `{name, kind, class, descriptor, fulfilment, advertised}`, where `descriptor` is `""` for a class tool;
  - `SecretArguments(pTool, .pDeclared)` :466;
  - `Write.cls:38` declares `DESCRIPTORCLASS`.
- `Test/SurfaceCoverage.cls` `DeriveWriteTools` :229-259 is the same filter to mirror.
- `src/OcuPilot/Kernel/Restraint.cls` `Resolved` :175; the subscripts are documented at :60-68.
- `Kernel/State/Switch.cls` `Resolve` :107-121 (`contextRowCap`). `Api/Context.cls` `Body` :91 is the precedent for reading the cap as any user.
- `Kernel/Agent/Limits.cls` `TOOLRESULTMAXLENGTH` :57, `FIELDMAXLENGTH` :63.
- Handler template: `Api/UiFindings.cls` (28 lines, no gate, `Response.JSON`/`RenderInternal`).
  - Router route after `/ui/findings` at `Api/Router.cls:143`; `Call` target after `UiFindings()` :876-882.
  - `Test/EndpointCoverage.cls`: add the probe after :133, copied from that row.
- Descriptor template: `Screen/Descriptor/AgentSwitches.cls` (form-page, no read), with `Home.cls` for `privileges: []`, `entityType: ""`, `primaryAction {"id":""}`, `rowActions []`.
- Rosters:
  - `Test/Wire.cls:462-476` (agent screens 3 → 4, positions, allowed);
  - `Test/SurfaceCoverage.cls:57-59` (a `<screen>` row, in alphabetical order);
  - `scripts/ci-throwaway.sh:223` `# classes: FindingsWire`, pinned by `ui/tools/ci.test.mjs`.
- `Test/FindingsWire.cls`:
  - :19-38 arming (`OCUPILOT_ALLOW_PRINCIPALS`) and the low principal;
  - :254 `_SYSTEM`'s refused `%All` removal, with its code and sentence.

Client:

- `ui/src/app/core/findings.ts` :271-331 is the store template (generation guard, `answered`/`failed`/`data`/`subscribe`/`reset`, narrowing).
  - Wire it at `main.ts` :15/:221/:282 and reset it in `app.ts` :60/:234/:643-645.
  - Providers go in `app.spec.ts`, `app.wire.spec.ts` and `app.gate-outlet.wire.spec.ts` (16.21 added one each), with a stub in `ui/src/app/testing/findings.ts`.
- `ui/src/app/shell/screen-outlet.ts`: page imports at :14-15; `DESCRIPTOR_PAGES` at :108.
- `ui/src/app/areas/agent/switches.page.ts`: the section and `h2` pattern at :170-196, `ocu-form-page` at :64.
- `ui/src/app/areas/home/findings-panel.ts`: the fault line at :53-54.
- `core/navigation.ts:390` `screenForDescriptor`; resolve a label through the strings lookup the side bar uses.
- `ui/src/app/core/strings.ts`: `} as const` at :3059; the only citation past EXPERIENCE.md :582 is at :1951 (`:623`).
- `ui/tools/navigation.test.mjs`: roster :192-199 and its message; test :211-225 ("lists two screens and builds three").
- `ui/browser/switches.browser-spec.mjs`: `authHeader` :74, `restoreSwitches` :85, `setSwitches` :101, `signedInAt` :111.
- EXPERIENCE.md (`_bmad-output/planning-artifacts/ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`, 990 lines):
  - Surfaces row :152;
  - side-bar row :169;
  - Privilege Gating row :226;
  - last Fixed strings row :582.

## Tasks & Acceptance

**Execution:**

- `src/OcuPilot/Kernel/Shell/Guardrails.cls` (new, `%RegisteredObject`). `Read(Output pAnswer As %DynamicObject) As %Status` composes `{prohibited, switches, confirmTools, secrets, limits}` as the matrix's Default row shows, each member from the source Always names. Add seams a fixture overrides: `ProhibitedClass()`, `Verdict(pUser, .pVerdict)` (defaulting to `Restraint.Resolved`) and `RegistryClass()`. The class doc states what it reads and that it adds no enforcement.
- `src/OcuPilot/Api/UiGuardrails.cls` (new) -- `HandleGuardrails()` as `UiFindings` does. `Api/Router.cls` -- add `<Route Url="/ui/guardrails" Method="GET" Call="UiGuardrails"/>` after :143, and a thin target after :882.
- `src/OcuPilot/Screen/Descriptor/AgentGuardrails.cls` (new). Copy `AgentSwitches` with these values:
  - `route` `agent/guardrails`, `labelKey` `agentGuardrailsLabel`, `sideBarPosition` 3, `archetype` `form-page`, `built` true, `refreshes` false, `privileges` [];
  - `entityType` "", `scope` `instance`, `id` none, `primaryAction {"id":"","selfProtection":""}`, `rowActions` [], `context {"fields":[],"secretFields":[]}`;
  - `commandAliases` `["guardrails","prohibited actions","what the agent refuses"]`;
  - `suggestedPrompts`: three `promptGroupAgentSetup` prompts, `agentGuardrailsPrompt1..3`;
  - `classicPage` "", with the exemption false;
  - `toolIdentifier` `agent.guardrails`.
- `src/OcuPilot/Test/Guardrails.cls` (new, unarmed) and `Test/GuardrailsFixture.cls`. Legs:
  - (a) every `Codes()` entry is a row in order, with a non-empty reason equal to `ReasonFor`;
  - (b) a fixture Prohibited subclass whose `Codes()` appends a probe code and whose `ReasonFor` answers a probe sentence shows that row last;
  - (c) `confirmTools` equals `ListTools`' advertised writes, with `security.auditing.purge` absent, and every `descriptor` in `Screen.Registry.Descriptors`;
  - (d) `secrets` equals `SecretArguments` per tool, with `permissions.users.password` carrying `NewPassword`;
  - (e) the limits equal `Switch.Resolve` and `Limits`;
  - (f) a fixture verdict (hold, enforced) is reflected: `killSwitch` true, audience `you`, `enforcedReadOnly` true;
  - (g) `TestTheDescriptorIsAListedUngatedAgentScreenWithNoRead`: built, agent area, position 3, no pairs, `Read()` not an object, no `agent.guardrails.*` tool in `ListTools`.
- `src/OcuPilot/Test/GuardrailsWire.cls` (new, armed like `FindingsWire`; add it to that `# classes:` line in `scripts/ci-throwaway.sh`):
  - (a) a least-privileged principal (`OcuGuardrailsLow`, built as `FindingsWire` builds its low user) gets 200 and the full shape over HTTP;
  - (b) as the test user, the sentence `GET /ui/findings` gives for `_SYSTEM`'s refused `%All` removal equals the `GET /ui/guardrails` row for the same code.
  Both remove what they create.
- Rosters:
  - `Test/Wire.cls` :462: 3 → 4; position of `agent/guardrails` = 3; allowed 1 with no `failedPair` for the principal.
  - `Test/SurfaceCoverage.cls`: `<screen name="AgentGuardrails" class="OcuPilot.Test.Guardrails" method="TestTheDescriptorIsAListedUngatedAgentScreenWithNoRead"/>`.
  - `Test/EndpointCoverage.cls`: the `/ui/guardrails` probe.
  - `ui/tools/navigation.test.mjs`: add `agent/guardrails` to both arrays, the roster and the titles, then regenerate `ui/src/app/core/screens.generated.ts` with `node tools/screen-mirror.mjs`.
- EXPERIENCE.md and `strings.ts`, before any client code uses the copy:
  - append one Fixed strings row after :582 (Copy in Design Notes);
  - edit :152, :169 and :226 in place;
  - `strings.ts` keys go before `} as const`, each `/** EXPERIENCE.md:583 */`;
  - shift every citation of a line past 582 by one, including `strings.ts:1951` → `:624`. Find them with `grep -rnE "EXPERIENCE\.md[^0-9]{0,3}(58[3-9]|59[0-9]|[6-9][0-9]{2})" ui src scripts _bmad-output/planning-artifacts`.
- `ui/src/app/core/guardrails.ts` (new, framework-free):
  - a `Guardrails` store and the answer's types;
  - `narrowGuardrails(unknown)`: a malformed answer counts as failed;
  - `confirmGroups(tools, lookup)`: groups by descriptor in first-appearance order, headed by `screenForDescriptor(d)`'s label; a tool with no mirrored screen goes last with no heading;
  - `killSwitchLine(switches)`, `readOnlyLine(switches)`, and `limitsLine(limits)`, which groups digits en-US.
  Wire it in `main.ts`, reset it in `app.ts` (sign-out block), add the stub `ui/src/app/testing/guardrails.ts`, and add the providers to the three app specs.
- `ui/src/app/areas/agent/guardrails.page.ts` (new, standalone, OnPush). It mirrors the store into a signal and calls `load()` on open.
  - `<section class="ocu-form-page ocu-guardrails">` holds the intro, then five `h2` sections in the order of the Copy list:
    - refused: `<ul>` of sentence plus `<code>` code;
    - switches: two lines and the note;
    - confirm: note, then `h3` group label and `<code>` names;
    - never sent: two sentences, the lead-in, then `<code>tool</code>: <code>fields</code>`;
    - limits: one line.
  - `aria-busy` while loading, and the fault line on failure.
  - Register it in `DESCRIPTOR_PAGES`.
- `ui/src/styles/_components.scss` -- append `.ocu-guardrails-*` rules at the end, add-only, using tokens only.
- Tests:
  - `ui/tools/guardrails.test.mjs` (store and helpers);
  - `ui/src/app/areas/agent/guardrails.page.spec.ts` (sections, groups, the three kill-switch lines, fault, no copy of any sentence);
  - `ui/browser/guardrails.browser-spec.mjs` (the ACs below).

**Acceptance Criteria:**

- **AC1.** Given a signed-in user, when they open Agent co-pilot › Guardrails from the side bar (after Switches), then the page lists under "Refused outright" one item per code `GET /ui/guardrails` answers, in that order, each showing that row's sentence and code. For a principal holding nothing of OcuPilot's own, the side bar marks the entry allowed (`Wire`) and the route answers 200 with the full shape (`GuardrailsWire` (a)).
- **AC2.** Given enforced read-only on and a row cap of 150 set on `ocupilot-ci`, when the page renders, then it reads:
  - "Enforced read-only: on", and the kill-switch line of the caller's verdict;
  - `permissions.users.delete` under the Users label in "Always needs your Confirm";
  - `permissions.users.password: NewPassword` under "Never sent to the agent", with both sentences;
  - the limits line with 150, 65,536 and 1,000.

  The switches are restored afterwards.
- **AC3.** Given a code added to the set with its sentence, when the answer is read, then its row appears with no other edit. Given a declared code whose reason text is empty, when `Test.Guardrails` runs, then it fails.
- **AC4 (Integration).** Given `_SYSTEM`'s refused `%All` removal on Home's Findings panel, when both routes are read, then Findings' sentence equals the Guardrails row for that code.
- **AC5.** Given the DW-1337 walk, when it visits `agent/guardrails` in light, at 720 px and in dark, then it records no violation and no baseline entry.

## Spec Change Log

## Review Triage Log

## Design Notes

**Governing ADs:**

- **AD-5:** one descriptor gives the route, the side bar, the gate and the prompts.
- **AD-8:** `privileges: []`. The route answers only declarations every user's tool set already advertises, plus the caller's own verdict.
- **AD-10 and AD-53:** one home, one sentence.
- **AD-11:** rendered as text.
- **AD-22:** read-only use of the classification, with no key.
- **AD-24:** context carries identity, `tools: []` and `readOnly` only, so nothing secret is sent.
- **AD-30:** display, never enforcement.
- **AD-36 and AD-50:** a shell-chrome answer.
- **AD-44:** no classic equivalent, so `classicPage` is "" with the exemption false.
- **AD-48:** a sentence only.
- **AD-9, AD-12, AD-19 and AD-20:** as their precedents.

**Why no declared read.** AD-36 names two source kinds: an instance endpoint behind a port, and a protected store's guarded list. The prohibited set, the registry and the caps are kernel declarations, and the switches line is the caller's own verdict. That is AD-50's shell-chrome case (`/agent/restraint`, `/agent/context`, `/ui/findings`). Serving the set to the agent as a read would need a third, `kernel` source kind, which is an AD-36 amendment and not in this story. So the prompts ask what the agent can answer from its offered tools, the context's `readOnly` and its system prompt.

**Why `form-page`.** It is the Switches precedent: a listed page whose own component (`DESCRIPTOR_PAGES`) renders a non-list answer. `detail` carries parent and child semantics in `navigation.ts:263/:283`. `leaveFormGuard` is harmless because nothing marks the page dirty.

**Consumes, Consumed-by, Integration, Ledger:**

- **Consumes:**
  - AD-10's set, whose sentences 16.21's Findings panel also shows for a refused fix (AC4);
  - the registry's classification and secret arguments;
  - `Restraint.Resolved`;
  - `Switch.Resolve` and `Limits`.
- **Consumed-by:** none. The route's only consumer is this page, which is the Integration AC (AC1, AC2 in the browser; AC4 in `GuardrailsWire`).
- **Ledger:** DW-118 is declined, because it was resolved by 15.6.
- **Governance and 14.5:** not in this story.

**Contention.** Epic 14 (14.5 in implement) edits `Restraint.cls`, `Switches.cls`, `Error.cls`, `Router.cls` :73 and its target, `EndpointCoverage` :82, `strings.ts` :230/:564, and EXPERIENCE.md :289/:335. Every addition here sits in Epic 16's own regions (`Router` :143/:882, `EndpointCoverage` :133, the `strings.ts` tail, the `_components.scss` tail, and EXPERIENCE.md :152/:169/:226/:583). Epics 18 and 23 have no source diff.

**Copy.** Append one Fixed strings row after :582, keyed as in brackets. `<rows>`, `<total>` and `<field>` are whole numbers grouped en-US. The row's Where cell reads: the Guardrails page (Story 16.22, AD-10, AD-22, AD-24): its side-bar label and intro; five section headings with their notes, in page order; the kill-switch and enforced read-only lines; the lead-in of the per-tool secret list; the limits line; and the screen's three suggested prompts (Agent setup group). The refused sentences are the prohibited set's own, from the server. It ends `[ADDED 2026-09-27 - Story 16.22]`.

1. `"Guardrails"` [agentGuardrailsLabel] · `"What the agent refuses, what waits for your Confirm and what it never sees, read from the rules this instance enforces."` [agentGuardrailsIntro]
2. `"Refused outright"` [agentGuardrailsRefusedHeading] · `"Neither the agent nor a screen can make these changes, whoever asks."` [agentGuardrailsRefusedNote]
3. `"Switches"` [agentGuardrailsSwitchesHeading] · `"Kill switch: off"` [agentGuardrailsKillSwitchOff] · `"Kill switch: on for everyone"` [agentGuardrailsKillSwitchEveryone] · `"Kill switch: on for you"` [agentGuardrailsKillSwitchYou] · `"Enforced read-only: off"` [agentGuardrailsReadOnlyOff] · `"Enforced read-only: on"` [agentGuardrailsReadOnlyOn] · `"The kill switch stops the agent. Enforced read-only lets it read and explain but not propose a change. Neither stops what you do on a screen yourself."` [agentGuardrailsSwitchesNote]
4. `"Always needs your Confirm"` [agentGuardrailsConfirmHeading] · `"These are the agent's tools that change the instance. Each one only proposes its change, and nothing happens until you press Confirm."` [agentGuardrailsConfirmNote]
5. `"Never sent to the agent"` [agentGuardrailsNeverHeading] · `"Fields declared secret, such as passwords, keys and tokens, never leave the instance for the agent: its reads drop them, and you type them yourself at Confirm."` [agentGuardrailsNeverSecrets] · `"An application error reaches the agent as its summary only, never the variables captured with it."` [agentGuardrailsNeverErrorVariables] · `"Values you type yourself at Confirm, which the agent never sees:"` [agentGuardrailsNeverTyped]
6. `"Screen context"` [agentGuardrailsContextHeading] · `"Each turn carries at most <rows> rows of the screen you are on, <total> characters in all and <field> characters a field."` [agentGuardrailsContextLimits]
7. `"Which of your tools can change this instance?"` [agentGuardrailsPrompt1] · `"Are you read-only on this instance right now?"` [agentGuardrailsPrompt2] · `"What happens between your proposal and a change on the instance?"` [agentGuardrailsPrompt3]

**In-place edits:**

- :152's Surface becomes `Guardrails · Governance policy · Agent audit ledger · Transcripts`, and its Purpose gains "Guardrails (Story 16.22): read-only, open to every signed-in user".
- :169 becomes `Definitions · Switches · Guardrails`.
- :226 gains "Guardrails is open to every signed-in user (Story 16.22)."

## Verification

**Commands.** Targeted runs are marked `(loop)`; the full runs are marked `(once, before dev_complete)`. Every run that writes to an instance names `ocupilot-ci`, one ObjectScript class at a time.

- `cd ui && npm run test:tools` (loop). Expected: green, including `guardrails.test.mjs`, `navigation.test.mjs`, `navigation-wire.test.mjs`, `screen-mirror.test.mjs`, `suggested-prompts.test.mjs`, `classic-links.test.mjs`, `strings.test.mjs`, `citations.test.mjs` and `ci.test.mjs`.
- `cd ui && npx ng test --include src/app/areas/agent/guardrails.page.spec.ts --include src/app/app.spec.ts --include src/app/app.wire.spec.ts --include src/app/app.gate-outlet.wire.spec.ts --include src/app/shell/screen-outlet.spec.ts --include src/app/shell/side-bar.spec.ts --include src/app/shell/command-box.spec.ts` (loop). Expected: green.
- `cd ui && node tools/ci-runner.mjs --container ocupilot-ci --class OcuPilot.Test.<C>`, one at a time, for `Guardrails`, `GuardrailsWire`, `Wire`, `Navigation`, `Descriptor`, `ScreenRegistry`, `ReadTool`, `SurfaceCoverage`, `EndpointCoverage`, `Prohibited`, `RefusalCopy`, `FindingsWire`, `ScreenGrounding` and `TurnContext` (loop). Expected: green.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-ci:/durable/iris/csp/ocupilot/ && OCUPILOT_BROWSER_ORIGIN=http://localhost:52776 OCUPILOT_BROWSER_CONTAINER=ocupilot-ci node --test --test-concurrency=1 browser/guardrails.browser-spec.mjs browser/a11y-structural-invariants.browser-spec.mjs browser/switches.browser-spec.mjs browser/shell.browser-spec.mjs browser/navigate.browser-spec.mjs browser/panel-principal.browser-spec.mjs browser/rail.browser-spec.mjs browser/suggested-prompts.browser-spec.mjs browser/explain-screen.browser-spec.mjs browser/screen-grounding.browser-spec.mjs` (loop). Expected: green, with no new structural-baseline entry. The bundle stays under the 2004 kB warning.
- `cd ui && npm test`, `uv run scripts/check-objectscript.py`, `bash scripts/lint-docs.sh` (once, before dev_complete). Expected: green.
- The full ObjectScript sweep on `ocupilot-ci`, one class at a time (once, before dev_complete). Expected: green. There is no local full browser suite; CI runs it.

**Mutations (Rule 19; record each as `mutation: … → …` here):**

- AC1: the page renders a constant list in place of the answer's rows → `guardrails.browser-spec.mjs` AC1 red.
- AC2 (three mutations):
  - `readOnlyLine` ignores `enforcedReadOnly` → AC2 red;
  - `Read` drops the `advertised` filter → `Guardrails` (c) red;
  - `limitsLine` prints a constant 200 → AC2 red at 150.
- AC3: blank `UNCOVEREDFIELDREASON` on the `ocupilot-ci` copy → `Guardrails` (a) red. `Read` iterating a fixed list instead of `ProhibitedClass()`'s `Codes()` → (b) red.
- AC4: `Read` answers `""` for one code's reason → `GuardrailsWire` (b) red.
- The ungated gate: declare `OcuPilotAdmin:USE` on the descriptor → `Wire` red on allowed.

## Auto Run Result

Status: ready-for-dev
Blocking condition: none

Planned only (halt after planning). Epic context reused (`epic-16-context.md`); EXPERIENCE.md's only newer change is 16.21's own rows, read directly. Ledger inbox empty; DW-118 declined in Design Notes. No AD change is needed: the page uses a shell-chrome answer and no declared read.
