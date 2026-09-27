---
title: 'Story 16.22: The Guardrails page'
type: 'feature'
created: '2026-09-27'
status: 'in-progress'
baseline_revision: 'd485a0b6b56921766c58047cd02ae739b6a0dbb5'
baseline_commit: 'd485a0b6b56921766c58047cd02ae739b6a0dbb5'
review_loop_iteration: 1
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
  - (d) `secrets` equals `SecretArguments` per tool, with `permissions.users.password` carrying `Password`;
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
  - Open after review pass 1: `Test.Guardrails` gains a fail-closed leg for an advertised write tool whose secret arguments answer `declared` 0 and one for a `ListTools` error, through a fixture registry reached by `RegistryClass()`; `guardrails.test.mjs` gains "a read in flight across `reset()` never lands"; `guardrails.page.spec.ts` asserts `aria-busy` "true" while the read is pending. Record `mutation:` lines for each, and for AC2's kill-switch line, Users group and secret line and for AC5 (a contrast failure on a `.ocu-guardrails-*` rule reddens the walk).

**Acceptance Criteria:**

- **AC1.** Given a signed-in user, when they open Agent co-pilot › Guardrails from the side bar (after Switches), then the page lists under "Refused outright" one item per code `GET /ui/guardrails` answers, in that order, each showing that row's sentence and code. For a principal holding nothing of OcuPilot's own, the side bar marks the entry allowed (`Wire`) and the route answers 200 with the full shape (`GuardrailsWire` (a)).
- **AC2.** Given enforced read-only on and a row cap of 150 set on `ocupilot-ci`, when the page renders, then it reads:
  - "Enforced read-only: on", and the kill-switch line of the caller's verdict;
  - `permissions.users.delete` under the Users label in "Always needs your Confirm";
  - `permissions.users.password: Password` under "Never sent to the agent", with both sentences;
  - the limits line with 150, 65,536 and 1,000.

  The switches are restored afterwards.
- **AC3.** Given a code added to the set with its sentence, when the answer is read, then its row appears with no other edit. Given a declared code whose reason text is empty, when `Test.Guardrails` runs, then it fails.
- **AC4 (Integration).** Given `_SYSTEM`'s refused `%All` removal on Home's Findings panel, when both routes are read, then Findings' sentence equals the Guardrails row for that code.
- **AC5.** Given the DW-1337 walk, when it visits `agent/guardrails` in light, at 720 px and in dark, then it records no violation and no baseline entry.

### Review Findings

Code review 2026-09-27 (full-opus; blind-hunter, edge-case-hunter, verification-gap, acceptance-auditor): 32 findings: 0 decision-needed, 2 patch, 0 defer, 1 by-design (2 findings), 28 rejected (grouped below).

- [x] [Review][Patch] A failed read's recovery was untested: dropping `failedValue = false` on success kept the fault line on every later visit, with the suite green [ui/src/app/core/guardrails.ts:263] — added "a failed read is cleared by the next read that answers" to `ui/tools/guardrails.test.mjs`.
- [x] [Review][Patch] `Read` restated the registry's advertised rule instead of asking it [src/OcuPilot/Kernel/Shell/Guardrails.cls:86] — now `Registry.IsAdvertised(tTool)`, the predicate `Resolve` and `ProviderTools` use (AD-53). `Guardrails` 10/10 on `ocupilot-ci`.
- [x] [Review][By-design] The secret list shows a screen's secret fields against every tool on it (`permissions.users.delete: Password`) [src/OcuPilot/Kernel/Shell/Guardrails.cls:89] — DW-1752. The Always rule pins it to `SecretArguments`, which is exactly what `Mint` refuses from the agent and `Dispatch` strips, so the pass-1 lead-in is true for every row. Narrowing to `SecretBodyNames` plus `ComposedSecrets` answers a different question ("what you type at Confirm"), and that set is not shown complete (inference).

Lead's points: (1) accurate and by-design, above. (2) Nothing new to a least-privileged caller: the codes and sentences are static text, AD-8 advertises every tool, every descriptor's `secretArguments` already ships in `screens.generated.ts`, and `GET /agent/restraint` answers the same verdict and more. (3) Confirmed: every failure path leaves `pAnswer` `""`, and `UiGuardrails` writes `Response.JSON` only after a successful `Read`, else one `RenderInternal` envelope. (4) Confirmed: nothing in `Restraint.cls`, `Api/Switches.cls`, `Router.cls` :73, `EndpointCoverage` :82 or EXPERIENCE.md :289/:335. AD-36: sound. A form page with no read is the `AgentSwitches` precedent, and instance-wide shell chrome is `/instance`'s, which AD-50 names.

Rejected:

- `false`: the empty-sentence row is not fail-closed at runtime. An empty `ReasonFor` is a declaration defect that `Test.Guardrails` (a) and `Test.Prohibited` refuse, not an unreadable part.
- `low`: an unknown kill-switch audience would read as "everyone". `Restraint` answers `everyone`, `you` or `""`, and a guard would only matter for a future value.
- `low`: the `h3` group ids are unreferenced. They are harmless, and each list follows its heading.
- `low`: an empty tool or secret list still draws its lead-in. The registry today always has both.
- `low`: `GuardrailsWire` (a) checks the shape, not equality with a privileged caller. `ListTools` takes no caller, and the matrix asks for the same shape.
- `false`: "holds no sentence of its own" is unproven. The test renders probe sentences the client does not hold, so the rows come from the answer.
- `low`: Copy item 3's key `agentGuardrailsSwitchesHeading` was not added. The page reuses the identical `agentSwitchesLabel`, which the EXPERIENCE :583 row records.
- `low`: spec bookkeeping (pass-2 counts, identical headings, the "Open after review pass 1" bullet, a `/tmp` KEEP path, and review vs done). The fix is an edit to the spec under review.
- `false`: `restoreSwitches` is skipped if `browser.close` throws. AC2's own `finally` restores the switches, and the hook order is the `switches.browser-spec` precedent. The fixed values are a fresh container's.
- `low`: the (f) fault test lacks a `Mutation:` doc line. Its line is in Verification.
- `low`: groups are rebuilt on each check. There are about 40 names, OnPush.
- `low`: a 503 `installing` answer shows the fault line. The install gate covers the shell, and reopening reads again.
- `low`: a re-opened page shows the previous answer while the new read is pending. It is the same principal, `aria-busy` is set, and `reset()` clears it at sign-out.
- `low`: `GuardrailsWire` setup failing midway leaves the role or user. It runs on a throwaway only, and the next setup modifies or deletes both first (`FindingsWire` precedent).
- `low`: a per-user hold left by an earlier spec could redden AC2. No spec leaves one, and CI runs on a fresh instance.
- `low`: (f) and the fixture set `killSwitch` and `enforcedReadOnly` both to 1, so swapping their sources is invisible to the unit suite. Browser AC2 catches it: enforced on, kill switch off.
- `false`: the `ListTools` error guard and the `'$IsObject` guard each prove only while the other is present. Both fail closed, and the recorded mutation reddens.
- `false`: an AD-36/AD-50 gap. No AD's Rule is contradicted (see above).

### Rework (CI, iteration 1)

- [ ] [CI] browser: `ui/browser/definitions.browser-spec.mjs:418` ("AC5: the form is routable and listed nowhere") fails on run 36320197671 at head dae9f00a: it pins the Agent co-pilot area's listed entries as exactly `Definitions, Switches`, and Guardrails is now listed third by design (this story's AC1). Update that leg's expected list (and its message) to include Guardrails in its declared position, keeping the leg's own point (the Definition form is listed nowhere); rebuild, redeploy and run that spec file alone on `ocupilot-ci`, demonstrate the mutation (drop Guardrails' side-bar position -> the leg reds), write its `mutation:` line. Then grep every other browser spec, component spec and node test for any other assertion that enumerates the Agent co-pilot area's entries, the side bar's entries or the command box's screen list, and fix each the same way, running each touched file alone. <https://github.com/jbrandtmse/OcuPilot/actions/runs/36320197671>

## Spec Change Log

- 2026-09-27, lead: re-opened for one rework iteration on a red CI browser job (run 36320197671): an existing spec pinned the Agent co-pilot area's entries without Guardrails.

- 2026-09-27 (implement, Rule 5 apply-and-report): task (d) and AC2 named the password tool's secret argument `NewPassword`; the instance declares `Password` (`UserList`'s `secretArguments`; `Registry.SecretArguments` on `ocupilot-ci` answers declared=1, `Password`). Corrected the name only; the intent is unchanged.
- 2026-09-27 (review pass 1, bad_spec): the secret list's lead-in "Values you type yourself at Confirm, which the agent never sees:" was false for most rows, because `SecretArguments` answers the screen's secret fields for every tool on it (`permissions.users.delete: Password`). Amended Copy item 5: the lead-in is now `"The fields each tool declares secret, which the agent never sees:"` [agentGuardrailsNeverDeclared], replacing `agentGuardrailsNeverTyped`. Known-bad state avoided: a trust page claiming a delete takes a password at Confirm. KEEP: re-apply `/tmp/epic-16-keep-16-22.patch` (`git apply`; it checked clean against `baseline_revision`) — the whole reviewed implementation, verified green — then change only that string (EXPERIENCE.md :583 row, `strings.ts` key and value, the page, and any spec that names the key) and add the open test items under Tasks.

## Review Triage Log

### 2026-09-27 — Review pass

- verdicts: 15 findings — high 0, medium 4, low 6, false 5, maybe-false 0
- findings:
  - `[medium]` `[patch]` `Read`'s `declared` 0 and `ListTools`-error branches are reached by no test (verification-gap) — carried into the re-derivation as a fixture-registry leg in `Test.Guardrails`.
  - `[medium]` `[patch]` `reset()` during an in-flight `load()` is untested; dropping its generation bump stays green (verification-gap) — carried: an in-flight-across-reset case in `guardrails.test.mjs`.
  - `[low]` `[patch]` nothing asserts `aria-busy` "true" while loading (verification-gap) — carried: a pending-transport case in `guardrails.page.spec.ts`.
  - `[low]` `[patch]` AC2's kill-switch line, Users group and secret line have no `mutation:` line (verification-gap) — carried: record the three.
  - `[low]` `[patch]` AC5 has no `mutation:` line (verification-gap) — carried: a contrast mutation on a `.ocu-guardrails-*` rule against the walk.
  - `[low]` `[reject]` `UiGuardrails`' `RenderInternal` branch is untested over HTTP (verification-gap) — a fault test needs a production seam on the handler; the branch is the two-line mapping `UiFindings` uses, and `Read`'s failure and the page's fault line are each pinned.
  - `[false]` `[reject]` the page spec's limits test uses `toContain` (verification-gap) — the reviewer's own note: `guardrails.test.mjs` and browser AC2 assert the exact line.
  - `[medium]` `[bad_spec]` the secret list's lead-in claims each listed field is typed at Confirm, false for delete and other tools (intent-alignment) — Copy item 5 amended (Spec Change Log).
  - `[low]` `[reject]` the "rule added" fixture overrides `Guardrails.ProhibitedClass()`, not `Write.ProhibitedClass()` (intent-alignment) — the shipped seam delegates to `Write.ProhibitedClass()`; a divergence needs a hard-coded class, which no reachable change introduces.
  - `[medium]` `[patch]` "a part unreadable" is tested only for the verdict (intent-alignment) — grouped with the first row; its HTTP-500 half is the rejected handler row.
  - `[low]` `[reject]` "Kill switch: on for everyone" is covered only on stubbed bodies (intent-alignment) — the server passes `Restraint`'s `AUDIENCEEVERYONE` through unchanged (Restraint.cls:36,108); the page spec draws both lines and (f) pins the pass-through.
  - `[false]` `[reject]` the Default row's numbers are pinned relative to their sources (intent-alignment) — that is stronger than a literal; a probe of `ocupilot-ci` read 18, `{false,"",false}` and `{200,65536,1000}`.
  - `[false]` `[reject]` the unadvertised purge is absent from `secrets` only by construction (intent-alignment) — (d) asserts every listed tool is an advertised write tool, so a listed purge reddens it.
  - `[false]` `[reject]` least-privileged coverage (intent-alignment) — a confirmation; no defect claimed.
  - `[false]` `[reject]` the Fixed "never sent" sentences restate enforcement (intent-alignment) — the intent makes all copy Fixed strings; no rule list is written a second time.

### 2026-09-27 — Review pass

- verdicts: 15 findings — high 0, medium 0, low 7, false 8, maybe-false 0
- findings:
  - `[low]` `[patch]` a tool with several secret fields is rendered by no test (verification-gap) — added "lists every secret field of a tool, in order" to `guardrails.page.spec.ts`; first-field-only mutation red, reverted.
  - `[false]` `[reject]` no unfalsifiable assertion found (verification-gap) — a confirmation; no defect claimed.
  - `[low]` `[patch]` the verdict fault leg has no `mutation:` line (verification-gap) — recorded: dropping the verdict's error check reddens it on `ocupilot-ci`, reverted and recompiled green.
  - `[low]` `[reject]` "rule added" is tested at Guardrails' own seam (intent-alignment) — carried: the shipped seam delegates to `Write.ProhibitedClass()`; no reachable change hard-codes the class.
  - `[low]` `[reject]` no test sets a real kill switch (intent-alignment) — carried: `Restraint`'s audience passes through unchanged; the page spec draws both lines.
  - `[low]` `[reject]` `Switch.Resolve`'s failure and the handler's 500 are not faulted (intent-alignment) — carried for the 500; a `Resolve` fault needs a new seam on the shipped class for a branch shaped like the three pinned ones.
  - `[false]` `[reject]` the Default row's literals are not asserted (intent-alignment) — carried: relative pins are stronger; the probe read 18, `{false,"",false}`, `{200,65536,1000}`.
  - `[false]` `[reject]` the kept sentence ends "you type them yourself at Confirm" (intent-alignment) — a general statement of where a needed secret is entered, true on every screen that takes one.
  - `[false]` `[reject]` name order is inherited, not asserted (intent-alignment) — (c) asserts equality with `ListTools`' `$Order`-by-name list; the page's grouping is the spec's.
  - `[false]` `[reject]` enforced read-only and cap 150 (intent-alignment) — surfaces match; no defect claimed.
  - `[false]` `[reject]` the unadvertised purge (intent-alignment) — carried: surfaces match.
  - `[false]` `[reject]` no browser test runs as the least-privileged account (intent-alignment) — `Wire` pins the navigation map's allowed flag, which is what the side bar renders.
  - `[low]` `[reject]` the walk's overflow check has no Guardrails mutation (intent-alignment) — AC5 has its contrast mutation, and the walk renders the live answer, which carries the longest real tool names.
  - `[false]` `[reject]` the client may hold a copy of a refusal sentence (intent-alignment) — this diff adds none; the seven existing copies in `strings.ts` are the self-protection refusals pinned equal by `self-protection.test.mjs` and `RefusalCopy`.
  - `[false]` `[reject]` the Never ranges and files (intent-alignment) — a confirmation; no hunk lands in them.

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
5. `"Never sent to the agent"` [agentGuardrailsNeverHeading] · `"Fields declared secret, such as passwords, keys and tokens, never leave the instance for the agent: its reads drop them, and you type them yourself at Confirm."` [agentGuardrailsNeverSecrets] · `"An application error reaches the agent as its summary only, never the variables captured with it."` [agentGuardrailsNeverErrorVariables] · `"The fields each tool declares secret, which the agent never sees:"` [agentGuardrailsNeverDeclared]
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

**Observed (applied, red seen, reverted byte-identical; server mutations on the `ocupilot-ci` copy with the class and its fixture subclass recompiled and recompiled back; client mutations rebuilt and redeployed, then redeployed clean):**

- mutation: `guardrails.page.ts` `prohibited` returns a constant row → `guardrails.browser-spec.mjs` AC1 red, `guardrails.page.spec.ts` "renders each refused row" red.
- mutation: `readOnlyLine` answers the off line whatever `enforcedReadOnly` reads → AC2 red, `guardrails.test.mjs` "the read-only line follows enforcedReadOnly" red.
- mutation: `limitsLine` prints a constant 200 for `<rows>` → AC2 red at 150 (after AC2's expectation was made independent of `limitsLine`), `guardrails.test.mjs` "groups each number" red.
- mutation: `Guardrails.Read` drops the `advertised` filter → `Guardrails` (c) `TestConfirmToolsAreTheAdvertisedWriteTools` red.
- mutation: `UNCOVEREDFIELDREASON = ""` → `Guardrails` (a) `TestEveryProhibitedCodeIsARowWithItsOwnSentence` red.
- mutation: `Read` takes `##class(OcuPilot.Kernel.Proposal.Prohibited).Codes()` in place of `ProhibitedClass()`'s → `Guardrails` (b) red.
- mutation: `Read` answers `""` for the fifth code's reason (`_SYSTEM`'s) → `GuardrailsWire` (b) red.
- mutation: `UiGuardrails` refuses a caller without `OcuPilotAdmin:USE` → `GuardrailsWire` (a) red.
- mutation: `"privileges": [{"resource": "OcuPilotAdmin", "permission": "USE"}]` on `AgentGuardrails` → `Wire` red on allowed and failed pair, `Guardrails` (g) red.
- mutation: delete `this.guardrails.reset()` from `app.ts`'s sign-out block → `app.spec.ts` sign-out row red.
- mutation: `Guardrails.Read` reads a failed `ListTools` as an empty list → `Guardrails` `TestAnUnlistedRegistryFailsTheWholeAnswer` red.
- mutation: `Guardrails.Read` skips the `declared` check → `Guardrails` `TestAnUndeclaredSecretListFailsTheWholeAnswer` red.
- mutation: `reset()` bumps neither `generation` nor `request` → `guardrails.test.mjs` "a read in flight across reset() never lands" red.
- mutation: the page's `busy` answers false while the store loads → `guardrails.page.spec.ts` "is busy while its read is pending" red.
- mutation: `killSwitchLine` answers the everyone line when off → `guardrails.browser-spec.mjs` AC2 red at the kill-switch line.
- mutation: the page's `screenLabel` answers null → AC2 red, "a group is headed Users".
- mutation: the secret list drops each tool's first field → AC2 red, `permissions.users.password: Password` not listed.
- mutation: `.ocu-guardrails-note` color `--ocu-outline-variant` → the walk's "no violation outside the baseline" red on `agent/guardrails` (1.53:1 light, 2.07:1 dark).
- mutation: the page renders only each tool's first secret field → `guardrails.page.spec.ts` "lists every secret field of a tool, in order" red.
- mutation: `Guardrails.Read` drops `If $$$ISERR(tSC) Quit` after `..Verdict` → `Guardrails` `TestAnUnreadablePartFailsTheWholeAnswer` red.
- mutation: `load()`'s success branch drops `this.failedValue = false` → `guardrails.test.mjs` "a failed read is cleared by the next read that answers" red.
- mutation: `Guardrails.Read` drops its `Registry.IsAdvertised` filter (code review) → `Guardrails` `TestConfirmToolsAreTheAdvertisedWriteTools` red (run 16254), reverted and recompiled green.

## Auto Run Result

Status: done
Blocking condition: none

**Change.** A read-only Guardrails screen, third in the Agent co-pilot side bar and ungated, renders `GET /ui/guardrails`: the prohibited set's codes and `ReasonFor` sentences, the caller's switches from `Restraint.Resolved`, the advertised write tools grouped by screen, their declared secret arguments, and the context caps. Any unreadable part fails the whole answer.

**Files.**

- `src/OcuPilot/Kernel/Shell/Guardrails.cls`: composes the answer through `ProhibitedClass()`, `Verdict()` and `RegistryClass()` seams.
- `src/OcuPilot/Api/UiGuardrails.cls`, `Api/Router.cls`: the route and its thin target.
- `src/OcuPilot/Screen/Descriptor/AgentGuardrails.cls`: form-page, `privileges: []`, no read, three prompts.
- `src/OcuPilot/Test/Guardrails.cls`, `GuardrailsFixture.cls`, `GuardrailsWire.cls`: legs (a)-(g), three fail-closed legs, the least-privileged and Findings-parity wire legs.
- `Test/Wire.cls`, `SurfaceCoverage.cls`, `EndpointCoverage.cls`, `scripts/ci-throwaway.sh`, `ui/tools/navigation.test.mjs`, `ui/src/app/core/screens.generated.ts`: rosters.
- `ui/src/app/core/guardrails.ts`, `ui/src/app/areas/agent/guardrails.page.ts`, `ui/src/app/testing/guardrails.ts`, `screen-outlet.ts`, `main.ts`, `app.ts`, three app specs: the store, the page, its stub and its wiring and sign-out reset.
- `strings.ts`, EXPERIENCE.md (:152, :169, :226, the :583 row, one shifted citation), `_components.scss`: copy and styles, add-only.
- Tests: `ui/tools/guardrails.test.mjs`, `guardrails.page.spec.ts`, `ui/browser/guardrails.browser-spec.mjs`.

**Review.** Pass 1: 15 findings (medium 4, low 6, false 5); one `bad_spec` (the secret list's lead-in, Copy item 5 amended) re-derived from the KEEP patch with four test items and five mutation lines carried in; four rejected with reasons in the log. Pass 2: 15 findings (low 7, false 8); two low patched (a multi-field secret test, the verdict fault leg's mutation line); five rejected, three of them carried. Nothing deferred. Follow-up review: false (pass 2 patched low 2, medium 0, high 0).

**Verification.** On `ocupilot-ci`: `Guardrails` 10/10, `GuardrailsWire` 2/2 (armed), `Wire` 20/20, `SurfaceCoverage` 4/4, `EndpointCoverage` 2/2, `Prohibited` 13/13, `RefusalCopy` 8/8, `Descriptor` 53/53. Full sweep once, pre-review, on the same non-test server code: 306 classes, 290 ran, 16 refused (arming), 1 known residue. `npm run test:tools` 1566/1566; `npm test` green; targeted component specs green. Browser after rebuild and redeploy: `guardrails` 2/2, structural walk 12/12 with 59 screens walked and no new baseline entry; `switches`, `shell`, `navigate`, `panel-principal`, `rail`, `suggested-prompts`, `explain-screen`, `screen-grounding` green in pass 1. Bundle 1.92 MB. `check-objectscript` 0, `lint-docs` 0. Switches read back at their defaults. Mutation lines under `## Verification`.

**Residual risk.** The route's 500 mapping and a `Switch.Resolve` failure are exercised by no test (rejected in the log). The secret list shows each screen's secret fields against every tool on that screen, as the registry declares them.
