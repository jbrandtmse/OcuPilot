---
title: 'Story 12.9: Removing the classic link-outs'
type: 'chore'
created: '2026-09-25'
status: 'done'
baseline_revision: 'f113b80388fce10e250de137599e683e73388f8c'
baseline_commit: 'f113b80388fce10e250de137599e683e73388f8c'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/implementation-artifacts/epic-12-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-12-8-the-oauth-2-0-server-client-description-editor.md'
warnings: ['oversized']
deferred: []
---

<intent-contract>

## Intent

**Problem:** Stories 12.4-12.8 replaced every OAuth 2.0 tab's classic link-out with an OcuPilot editor, but nothing proves the OAuth screen as a whole no longer leaves for the classic portal. The prose still says otherwise: AD-44 reads "exactly three ... SM-C1 counts three" (DW-1643), the PRD and UX spines still name the OAuth tabs as the one exemption and a new-tab classic editor link, and the PRD still carries "OAuth setup is lists and deletes only" as an accepted risk.

**Approach:** Verification and cleanup, no product code. Add one browser leg over all five tabs. Retire the leftover OAuth-exemption data and wording in tests. Replace each stale sentence at its origin: AD-44, the PRD's FR-9 and FR-44 consequences, EXPERIENCE.md, and UX-DR67. Record the risk closed in the PRD's risk register.

## Boundaries & Constraints

**Always:**

- Correct a claim by replacing its sentence, never by appending a correction.
  - Planning-artifact edits carry the project's inline marker `[AMENDED 2026-09-25, Story 12.9, Rule 5 tier-1: was "<old words>"]`.
  - The spine edit uses Rule 20 in place of Rule 5.
- The spine edit follows Rule 20's light path: a memlog `decision` line, `lint_spine.py` clean, and `updated:` refreshed.
- Slot B throughout.
  - Every IRIS MCP call carries `server: "ocupilot-slot-b"`.
  - Every test that writes instance state runs on `ocupilot-b-ci`, one class per call, each awaited.

**Never:**

- Change any descriptor under `src/OcuPilot/Screen/Descriptor/`.
  - `ServiceForm` and `LdapConfigForm` keep their exemptions. They belong to Epic 16 (Stories 16.13, 16.14).
  - No new exemption is declared anywhere.
- Remove `classicPage` from an OAuth descriptor. It is AD-44's resource key and the Help control's documentation lookup, not a link.
- Remove the Help control. It opens DocBook (`/csp/docbook/DocBook.UI.PortalHelpPage.cls?KEY=…`, `Kernel/Shell/About.cls:31,174`), which is documentation, not a classic-portal page.
- Retire the dormant row-link mechanism. That covers:
  - the `rowLink` grammar in `Registry.ClassicLinkProblem`, `classic-links.mjs` and `screen-mirror.mjs`;
  - the `data-table.ts` classic cell (:593-640);
  - `classicRowHref`;
  - `classicRowLinkDescription`.

  AD-44 still lets a detail view link out where it declares an exemption, and retiring the mechanism would narrow AD-44. Its unit fixtures that use an OAuth page as the example value also stay: `data-table.spec.ts` :274/:304 and `table-model.test.mjs` :263-264.
- Reword refusal sentences that send the user to the classic portal for a field OcuPilot does not edit. For example, `Api/Error.cls:2655` `REASONOAUTHAUTHENTICATORSECRET` (Story 12.6) is text, not a link.
- Change client source (`ui/src/**`). The bundle holds at about 1,803,837 bytes.
- Hand-edit `epic-12-context.md`, which is generated.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| Name cells | Each of the five tabs, probe rows present | Every gridcell anchor's path begins `/ocupilot/<tab route>/edit`, with no `target` | Assert at least one anchor per tab, so the check is not vacuous |
| No classic link anywhere | The same five renders | No `a[href]` resolves to a path under `/csp/sys/`, and there is no `.ocu-classic-link-card` | A Help anchor to `/csp/docbook/` passes |

</intent-contract>

## Code Map

**Already done upstream (verified at plan):**

- **Descriptors.** All five OAuth tab descriptors and all five OAuth forms declare `{"exempt": false, …}`. Only `ServiceForm.cls:47` and `LdapConfigForm.cls:49` declare `exempt: true`.
- **Mirror.** `screens.generated.ts` carries exactly two `/csp/sys/` hrefs, at :2504 (LDAP) and :5220 (Services).
- **Other client surfaces are clean.** The command box, `core/shortcuts.ts` and Home's links panel (`About.Links`: DocBook, support, intersystems.com) carry no classic OAuth href. `strings.ts` has no OAuth classic-link string.
- **The checker.** `ui/tools/classic-links.mjs` names no OAuth. Its reason de-duplication (:17-19, :410) is AD-44's general rule and stays.

**Test surface:**

- `ui/browser/oauth.browser-spec.mjs`:
  - header :1-9;
  - `TABS` :51+ (route, read, label for all five);
  - helpers `signedInAt`, `atTab`, `answerFor`, `waitForRows` (from `list-spec.mjs`);
  - the AC4 leg at :352-388 is the model for the new leg. Editor routes are `<tab route>/edit[/<id>]`, and the app base is `/ocupilot/`.
- `ui/tools/classic-links.test.mjs`:
  - :210-228 uses a fixture named `OAuth.cls`;
  - :430-461 is the real-tree roster test, which already pins the honored set to exactly the two reduced forms (2 exemptions, 2 declarations). Its comment at :440-446 narrates history.
- `src/OcuPilot/Test/OAuthTabs.cls`:
  - `Tabs()` :72-83 carries an eleventh element, "rowLink params as JSON", that nothing reads (no `$List(tCase, 11)`, no external caller);
  - `TestEachTabIsDeclaredAsTheOAuthScreenTab` :193 asserts `ClassicLinkExempt` is 0 on every tab.
- Fixtures described as "the Resource servers tab's sound declaration" that still declare the tab's pre-12.6 exemption ("until the OAuth 2.0 editors ship (Epic 12)", an OAuth classic href and a `rowLink`):
  - `src/OcuPilot/Test/Tab/Bad.cls` :32-38;
  - `src/OcuPilot/Test/TabGroup/First.cls` :30-36;
  - `src/OcuPilot/Test/TabGroup/Third.cls` :28-34.

  They are consumed by `Test/TabRegistry.cls`, `Test/TabGroupRegistry.cls` and `Test/Descriptor.cls`.
- `src/OcuPilot/Test/Screen/Multi.cls:37`: its exemption reason is "the OAuth 2.0 tabs are a detail archetype and have no rebuilt equivalent yet". `Descriptor.cls:1162-1165` needs the exemption itself, with a non-empty reason, label and href.

**Planning artifacts** (paths under `_bmad-output/planning-artifacts/`):

- `architecture/architecture-OcuPilot-2026-09-08/ARCHITECTURE-SPINE.md:514`, AD-44's second paragraph, from "Release 1 has exactly three" through the second `[AMENDED …]` marker. The Conventions row at :705 and the AD-27 bullet at :368 are correct already.
- `prds/prd-OcuPilot-2026-09-08/prd.md`:
  - :298, FR-9's last sentence: "The OAuth 2.0 tabs (FR-44) are the one such exemption in Release 1."
  - :698, FR-44's second sentence: "This is the one classic-link exemption in the six areas, and it is counted against SM-C1."
  - :1198, the section 11 risk row. The closed rows at :1201-1203 show the house form.
  - `.memlog.md` beside it, whose entries are `(change)` lines.
- `ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md`:
  - :146, the "Classic OAuth editor" navigation row;
  - :772, the Banned-everywhere clause "and OAuth classic editor links".
- `epics.md:469`, UX-DR67's copy of that clause, "and the classic OAuth editor links".

## Tasks & Acceptance

**Execution:**

- [x] `ui/browser/oauth.browser-spec.mjs`
  - Add the leg "AC1 (Story 12.9): no OAuth 2.0 tab links to the classic portal", per the I/O matrix: for each of `TABS`, sign in at its route, wait for its read's rows, then assert.
  - Add one clause for it to the file header.
  - Replace the :352-354 narration with the contract sentence and its mutation.
- [x] `ui/tools/classic-links.test.mjs`
  - Rename the fixture `OAuth.cls` to `Reduced.cls` (:214, and the regex at :223).
  - Replace :440-446 with: AD-44 honors two exemptions, the reduced service and LDAP forms, each under its own reason; no OAuth 2.0 descriptor declares one. The mutation reads: restore any OAuth 2.0 tab's exemption → the honored set and both counts go red.
- [x] `src/OcuPilot/Test/OAuthTabs.cls`: drop the unread eleventh element from all five `Tabs()` rows and from their doc comment.
- [x] `src/OcuPilot/Test/Tab/Bad.cls`, `Test/TabGroup/First.cls` and `Test/TabGroup/Third.cls`: set `classicLinkExemption` to the Resource servers tab's current `{"exempt": false, "reason": "", "label": "", "href": ""}`. Each is then again the copy its doc comment claims.
- [x] `src/OcuPilot/Test/Screen/Multi.cls:37`: change the reason to neutral fixture text, `a test detail view that keeps its classic page`, and keep the exemption.
- [x] `ARCHITECTURE-SPINE.md:514` (AD-44). Replace the span with:

  > Release 1 has exactly two: the reduced service editor, removed by Story 16.13, and the reduced LDAP editor, removed by Story 16.14 - each counted against SM-C1, so SM-C1 counts two. Each is declared once, by `ServiceForm` and `LdapConfigForm`. The check reports the declaring descriptors under each exemption, so each exemption counts once, every declaration stays visible, and any total is recomputed from this list. The OAuth 2.0 tabs' exemption closed in Epic 12, as Stories 12.4-12.8 replaced each tab's classic editor.

  Follow it with the Rule 20 marker, `was "exactly three ... SM-C1 counts three"`.
  - Append the memlog line: `uv run --no-cache _bmad/scripts/memlog.py append --workspace <spine dir> --type decision --text "AD-44 (Story 12.9, DW-1643): two exemptions, ServiceForm and LdapConfigForm; the OAuth 2.0 exemption closed by Stories 12.4-12.8"`.
  - Run `lint_spine.py` and refresh `updated:`.
- [x] `prd.md`
  - :298: say that two such exemptions remain, the reduced service and LDAP editors (Stories 16.13 and 16.14).
  - :698: say the exemption closed when the FR-75 editors replaced it (Stories 12.4-12.8).
  - :1198: replace the mitigation cell with `**Closed** 2026-09-25: Stories 12.4-12.8 shipped the five OAuth 2.0 editors, and Story 12.9 confirmed that no OAuth 2.0 tab links to the classic portal`.
  - Add a marker on each change, and one `(change)` memlog line.
- [x] `EXPERIENCE.md`
  - :146: replace the row with `| OAuth 2.0 editors | Security and secrets | OAuth 2.0 row name cell · the tab's Create | each tab's entry opens its OcuPilot editor (FR-75) | form-page (tabs) | P1 |`.
  - :772: delete the words "and OAuth classic editor links" and fix the grammar ("opens a new tab").
- [x] `epics.md:469` (UX-DR67): make the same deletion ("only the classic-link-card opens a new tab").

**Acceptance Criteria:**

- **AC1 (AD-44).** Given the OAuth 2.0 screen with the probe's objects, when each of its five tabs renders, then every name cell opens OcuPilot's editor in the same tab, nothing on the screen links to the classic portal, and no classic-link card renders.
- **AC2 (AD-44, DW-1643).** Given the shipped descriptor roster, when `classic-links` runs, then:
  - it reports `2 exemption(s) honored (SM-C1)` over `2 descriptor(s)`, which are `ServiceForm` and `LdapConfigForm`;
  - no OAuth 2.0 descriptor declares an exemption;
  - AD-44, the PRD's FR-9 and FR-44, EXPERIENCE.md and UX-DR67 name no OAuth exemption and no OAuth classic link.
- **AC3.** Given the PRD's risk row "OAuth setup is lists and deletes only at the deadline", when this story completes, then the row reads **Closed** and names Stories 12.4-12.8 and 12.9.

### Review Findings

Code review 2026-09-25 (layers full-opus). 23 findings: 6 patched, 0 deferred, 17 closed. Each patch is a tier-1 edit with its own `[AMENDED …]` marker. `lint-docs.sh` is clean, `npm run test:tools` passes 1425/1425, and EXPERIENCE.md still has 929 lines.

- [x] [Review][Patch] (medium) EXPERIENCE.md still called the OAuth exemption "AD-44's single Release 1 classic-link exemption", against AC2. Reworded [EXPERIENCE.md:741]
- [x] [Review][Patch] (low) The FR-44 copy in epics.md still linked each entry to the classic editor. Now matches the PRD [epics.md:136]
- [x] [Review][Patch] (low) The banned-everywhere clause forbade a new tab for the kept `rowLink` cell, contradicting :367 and AD-44. Now names the cell [EXPERIENCE.md:772, epics.md:469]
- [x] [Review][Patch] (low) One archetype was given for all five editors, but the server-description editor is untabbed. The row now lists `form-page · form-page (tabs)` and uses the table's `**P1**` [EXPERIENCE.md:146]
- [x] [Review][Patch] (low) FR-9 read as though Stories 16.13 and 16.14 create the exemptions. Now "until … replace them" [prd.md:298]
- [x] [Review][Patch] (low) Story 12.9's AC called the OAuth tabs a "list". Now "a table's name cell" [epics.md:5489]

#### Closed

The first three are by-design. Each of the rest is false or a rejected low.

- **by-design:** the Help, Home-link, sign-in and instance-notice new tabs still contradict the banned list. Spec gate Q3 left that claim to its owner (DW-1677, filed `by-design`).
- **by-design:** the AD-44 marker quotes only part of the old span and drops the 2dca0322/8bd12776 provenance. The spec set both the span and the marker, and the spine memlog records both rulings.
- **by-design:** `Multi.cls` keeps an OAuth-shaped exempt fixture, and `epic-12-context.md` is stale. The spec keeps both.
- **low:** the `.ocu-classic-link-card` clause cannot go red on a tab route. The I/O matrix requires it, and it is not the pinning assertion. This matches the earlier triage.
- **false:** "the row-link mechanism lost its coverage". `ClassicLinkCorpus.cls:80-86`, `data-table.spec.ts` and `table-model.test.mjs` still cover it.
- **false:** "the leg misses buttons, `window.open`, menus and unprivileged principals". A classic link reaches the client only through an honored exemption, which AC2 pins.
- **low:** the leg checks the anchors that exist, not the row count. The classic-exit half is pinned, the fix would add a branch, and Stories 12.4-12.8 pin name-cell navigation.
- **low:** `epics.md:811` is Epic 6's historical note in another epic's block.
- **low:** moving the :367 string would break the `strings.ts` line citations.
- **low:** the :146/:148 overlap. This matches the earlier triage.
- **low:** `external` is now an unused archetype key (:72, :724), which is harmless.
- **low:** the name "AC1 (Story 12.9)".
- **low:** `Tab/Bad` still says "everything else" matches, although `primaryAction` and `rowActions` differ. The operative claim, sound apart from the tab, holds.
- **low:** AC2's prose half and AC3 are checked by reading.
- **low:** the Spec Change Log placement and the memlog "prevents" half. Fixing either edits the spec or an append-only log.

## Spec Change Log

- 2026-09-25, lead spec gate: Q1 the full browser suite is CI's (Rule 29); Q2 keep the row-link mechanism (AD-44 unchanged); Q3 remove only the OAuth wording from EXPERIENCE.md :772 and UX-DR67, leaving the Help-control claim to its owner; Q4 the epic context is regenerated, not hand-edited; Q5 keep `REASONOAUTHAUTHENTICATORSECRET` (text, not a link). The PRD, EXPERIENCE.md and UX-DR67 edits are tier-1 amendments: mark each `[AMENDED 2026-09-25, Story 12.9, Rule 5 tier-1]` and list them in the Auto Run Result.

## Review Triage Log

### 2026-09-25 — Review pass

- verdicts: 13 findings — high 0, medium 1, low 6, false 6, maybe-false 0
- findings:
  - `[low]` `[reject]` verification-gap: the AC1 leg's `.ocu-classic-link-card` clause cannot go red on a tab route (the card renders only from `reduced-form.page.ts`) — the I/O matrix mandates the check as a regression guard, and Rule 19 scopes to the pinning test, whose mutation is recorded.
  - `[low]` `[reject]` verification-gap: AC2's prose half and AC3 have no mutation, and the spec's greps hit the markers — checked by reading; a marker-stripped grep over the spine, PRD, EXPERIENCE.md and epics.md returns nothing (Auto Run Result); the fix edits this build's spec.
  - `[false]` `[reject]` verification-gap: Auto Run Result unfilled — it is written at finalize, after review.
  - `[false]` `[reject]` verification-gap: the fixture edits are covered by `Descriptor` — a confirmation, no bad outcome claimed.
  - `[low]` `[reject]` verification-gap: four listed registry classes run no test methods — already recorded under Verification; `Descriptor` is their host; the fix edits this build's spec.
  - `[false]` `[reject]` verification-gap: `Tabs()` element 11 has no reader — a confirmation, no bad outcome claimed.
  - `[false]` `[reject]` intent-alignment: the leg covers the tab renders, not editors, menus or `window.open` — no classic exit exists there: the only client `/csp/sys/` anchors are the two reduced forms' mirror entries and the shell's instance notice and sign-in pages, and form exemptions are pinned by AC2's roster.
  - `[low]` `[reject]` intent-alignment: the AC1 mutation broke one tab of five — Rule 19 asks one mutation per AC; the five tabs share one render path.
  - `[medium]` `[patch]` intent-alignment: `EXPERIENCE.md:367` still called `classicRowLinkDescription` the OAuth tabs' "name cell that opens the classic editor", against AC2 — reworded in place to a `rowLink` exemption's name cell with a tier-1 marker; the string value and the line count are unchanged, and `strings.test.mjs` (25/25) and `lint-docs.sh` pass.
  - `[low]` `[reject]` intent-alignment: the new `EXPERIENCE.md:146` row overlaps :148's "OAuth 2.0 editors (five)" — the row text is the spec's own; the overlap misleads no one.
  - `[false]` `[reject]` intent-alignment: `epics.md:859` and :3986 — the auditor reads them as historical, not stale; no claim made.
  - `[low]` `[reject]` intent-alignment: AD-44's and FR-44's closure clauses narrate history — the text is the spec's own and states a current fact.
  - `[false]` `[reject]` intent-alignment: the closed risk row's claim rests on a local run — the leg passed 5/5 again on a freshly built and deployed bundle at finalize, and CI runs it.

## Design Notes

**Governing ADs:** AD-44 (list-versus-detail, the exemption list, and the count reported to SM-C1), AD-5 (the descriptor is the only source of a screen's link), AD-27 (`classicPage` as the declared fallback), and Conventions › Classic-portal link-out.

**Why AC1's leg covers the five tabs and not the five editors.** A classic link reaches the client only through an honored exemption: the classic-link card on a form, or `rowLink` on a table. AC2's real-tree test pins the honored set for every descriptor, forms included. The browser leg proves the outermost surface on the one screen the story names.

**Integration ACs:** this story introduces no service, module or shared component, so it has no consumers.

**Ledger inbox:** DW-1643 is addressed by the AD-44 task and AC2. `epic-12-context.md`'s "Classic links" bullet goes stale once AD-44 changes. It is regenerated by the pre-warm (the spine will be newer) and is not hand-edited.

## Verification

Slot B. The throwaway's source is the copy at `/tmp/ocupilot-b-ci/src`. Copy each changed `.cls` there, then compile it with `docker exec -i ocupilot-b-ci iris session iris -U HSCUSTOM` and `$System.OBJ.Load("/opt/ocupilot/src/OcuPilot/<path>.cls","ck")`.

**Commands:**

- `sh scripts/ci-unit-test.sh --container ocupilot-b-ci --class OcuPilot.Test.<C>` (loop), one call each for `OAuthTabs`, `Descriptor`, `TabRegistry`, `TabGroupRegistry`, `ClassicLinkRegistry` and `ScreenRegistry`. Expected: 0 failures each.
- `cd ui && node --test tools/classic-links.test.mjs && npm run test:tools` (loop). Expected: 0 failures.
- `cd ui && npm run build && docker cp dist/ocupilot-ui/browser/. ocupilot-b-ci:/durable/iris/csp/ocupilot/`, then `OCUPILOT_BROWSER_ORIGIN=http://localhost:52777 OCUPILOT_BROWSER_CONTAINER=ocupilot-b-ci node --test --test-concurrency=1 browser/oauth.browser-spec.mjs` (loop). Expected: every leg passes.
- `uv run --no-cache .claude/skills/bmad-architecture/scripts/lint_spine.py --workspace _bmad-output/planning-artifacts/architecture/architecture-OcuPilot-2026-09-08`, `uv run scripts/check-objectscript.py <changed .cls>` and `bash scripts/lint-docs.sh` (loop). Expected: clean.
- These greps all return nothing (loop):
  - `grep -nE 'exactly three|counts three' <spine>`;
  - `grep -n 'Classic OAuth editor\|OAuth classic editor\|classic OAuth editor' <EXPERIENCE.md> <epics.md>`;
  - `grep -rn 'OAuth 2.0 editors ship\|OAuth 2.0 tabs are a detail' src ui/src ui/tools ui/browser`.
- The full ObjectScript sweep on `ocupilot-b-ci`, one class per call, with totals checked against `%UnitTest_Result` (once, before dev_complete). Expected: 0 failed, and a non-zero count.
- `cd ui && npm run build && npm test`, then `bash scripts/smoke.sh --container ocupilot-b-ci --user _SYSTEM --password SYS` (once, before dev_complete). Expected: green, and the bundle total recorded unchanged.
- The full browser suite is CI's (Rule 29, owner instruction 2026-09-22).

**Pinning mutations (Rule 19; record each as `mutation: … → …`):**

| AC | Mutation |
| --- | --- |
| AC1 | Restore `OAuthClientTab.cls`'s pre-12.5 exemption with its `rowLink` (`git show 7ea6e89459ad2dd3d2dfe692712c2264fd727520:src/OcuPilot/Screen/Descriptor/OAuthClientTab.cls`, :47-53). Then run `node tools/screen-mirror.mjs`, rebuild and redeploy; the client reads the link from the mirror, so no compile is needed. Expect the new AC1 leg to go red. Revert both files, rebuild, redeploy, and confirm the tree is byte-identical. |
| AC2 | Restore `OAuthServerClientTab.cls`'s exemption. Expect `classic-links.test.mjs` "the shipped descriptor roster passes" to go red. |
| AC3 | None: AC3 is a planning-artifact record, checked by reading the row. |

**Observed in implement (`ocupilot-b-ci`, 2026-09-25), each mutation reverted with `git status --short` and `git diff --stat` identical to before it:**

- mutation: `OAuthClientTab.cls`'s pre-12.5 exemption with its `rowLink` restored, mirror regenerated, rebuilt and redeployed → `oauth.browser-spec.mjs` "AC1 (Story 12.9)" (Client configurations' name cell at `/csp/sys/sec/%25CSP.UI.Portal.OAuth2.Client.Configuration.zen`) and "AC4" (honored set); reverted, rebuilt and redeployed (same `main-5IVFUPZY.js`), and the spec re-ran 5/5 green.
- mutation: `OAuthServerClientTab.cls`'s pre-12.8 exemption restored → `classic-links.test.mjs` "the shipped descriptor roster passes" ("the honored set is exactly the two reduced forms").
- Bundle: initial total 1,803,837 bytes (main 1,652,221, styles 151,616), unchanged.
- The greps' only hits are the `[AMENDED … was "…"]` markers' quoted old words (spine :514, EXPERIENCE.md :146/:772, epics.md :469); the `src ui/src ui/tools ui/browser` grep returns nothing.
- `TabRegistry`, `TabGroupRegistry`, `ClassicLinkRegistry` and `ScreenRegistry` extend `OcuPilot.Screen.Registry`, not `%UnitTest.TestCase` (`TabRegistry` ran 0 methods); `Descriptor` is the test case that consumes them.

## Auto Run Result

Status: done
Blocking condition: none

**Summary.** No product code changed. A new browser leg checks all five OAuth 2.0 tabs: every name cell opens OcuPilot's editor in the same tab, and no link goes to `/csp/sys/`. The test fixtures lost their leftover OAuth exemption data. AD-44, the PRD (FR-9, FR-44, the risk row), EXPERIENCE.md and UX-DR67 were corrected at their origin.

**Files changed:**

- `ui/browser/oauth.browser-spec.mjs`: the new leg, AC1 (Story 12.9), a header clause, and the AC4 comment restated as a contract.
- `ui/tools/classic-links.test.mjs`: the fixture is renamed `Reduced.cls`, and the roster comment is restated.
- `src/OcuPilot/Test/OAuthTabs.cls`: the unread eleventh `Tabs()` element is dropped.
- `src/OcuPilot/Test/Tab/Bad.cls`, `Test/TabGroup/First.cls`, `Test/TabGroup/Third.cls`: each now declares the Resource servers tab's `exempt: false`.
- `src/OcuPilot/Test/Screen/Multi.cls`: the exemption reason is neutral fixture text.
- Spine `ARCHITECTURE-SPINE.md:514` (AD-44) and its `.memlog.md`: Rule 20 (decision line appended). `lint_spine` reports only the existing `{id}` note.
- `prd.md` and its `.memlog.md`: tier-1 amendments and one `(change)` line.
- `EXPERIENCE.md` and `epics.md`: tier-1 amendments.
- This spec.

**Tier-1 amendments (Rule 5; each marked `[AMENDED 2026-09-25, Story 12.9, Rule 5 tier-1: was "…"]`):**

- `prds/prd-OcuPilot-2026-09-08/prd.md:298`: FR-9 now says two exemptions remain, the reduced service and LDAP editors (Stories 16.13, 16.14).
- `prd.md:698`: FR-44 now says each tab opens OcuPilot's editor (FR-75), and its exemption closed with Stories 12.4-12.8. This also replaced the sentence's "links to the classic portal editor … until … FR-75 ship" clause, which AC2 rules out.
- `prd.md:1198`: the risk "OAuth setup is lists and deletes only" is **Closed** 2026-09-25 (Stories 12.4-12.8, 12.9).
- `ux-designs/ux-OcuPilot-2026-09-08/EXPERIENCE.md:146`: the "Classic OAuth editor" navigation row is replaced by "OAuth 2.0 editors".
- `EXPERIENCE.md:367`: `classicRowLinkDescription` is now described as a `rowLink` exemption's name cell, no longer as an OAuth one (review patch).
- `EXPERIENCE.md:772`: "and OAuth classic editor links" is removed from Banned everywhere.
- `epics.md:469` (UX-DR67): the same deletion.
- EXPERIENCE.md still has 929 lines, so the `strings.ts` citations still resolve.

**Review:** 13 findings.

- 1 patched (medium, `EXPERIENCE.md:367`).
- 0 deferred.
- 12 rejected, each with its reason in the Review Triage Log.
- Follow-up review recommended: `false` (patched: high 0, medium 1, low 0).

**Verification (slot B, `ocupilot-b-ci`):**

- **Full ObjectScript sweep:** 286 classes, 2394 tests, 0 failed. Runs 1268-1553 were contiguous and all on `ocupilot-b-ci`. It ran as 12 sequential `ci-runner.mjs --class` chunks, each green, with 0 probe leftovers, 0 overlaps and 0 foreign runs. The instance offered the same 286 classes the checkout carries. Totals were re-counted from `^UnitTest.Result` for runs after 1267: 286 runs, 2394 methods, 0 failed.
- **Targeted:** `OAuthTabs` 17/17 and `Descriptor` 51/51. `classic-links.test.mjs` plus `strings.test.mjs`: 42/42.
- **Client:** `npm run build` green. `npm test`: 1425 tool tests and 1377 component tests (106 files), 0 failed.
- **Bundle:** measured initial total 1,803,837 bytes (main 1,652,221 + styles 151,616), unchanged.
- **Browser:** on a freshly built and deployed bundle, `browser/oauth.browser-spec.mjs` passed 5/5 (AC1, AC2, AC4, AC1 (Story 12.9), AC5). The full browser suite is CI's (Rule 29).
- **Smoke:** `smoke.sh --container ocupilot-b-ci`: executed 49, passed 49, PASSED.
- **Lint:** `check-objectscript` 0 problems, `lint-docs.sh` clean, `lint_spine` shows only the existing `{id}` note.
- **Greps:** with `[AMENDED …]` markers stripped, a grep of the spine, PRD, EXPERIENCE.md and epics.md for the stale phrases finds nothing. The code grep over `src ui/src ui/tools ui/browser` also finds nothing.
- **Mutations:** the AC1 and AC2 `mutation:` lines are under Verification.

**Paths edited outside the footprint:** the code edits are all inside Epic 12's `paths_hint`. These planning files are outside it, and each edit is one of the Rule 5 or Rule 20 amendments listed above:

- `ARCHITECTURE-SPINE.md` and its `.memlog.md`
- `prd.md` and its `.memlog.md`
- `EXPERIENCE.md`
- `epics.md` (UX-DR67)

**Residual risks:** `epic-12-context.md`'s "Classic links" bullet is stale until the pre-warm regenerates it (the spine is now newer).
