---
title: 'Story 12.9: Removing the classic link-outs'
type: 'chore'
created: '2026-09-25'
status: 'ready-for-dev'
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

- [ ] `ui/browser/oauth.browser-spec.mjs`
  - Add the leg "AC1 (Story 12.9): no OAuth 2.0 tab links to the classic portal", per the I/O matrix: for each of `TABS`, sign in at its route, wait for its read's rows, then assert.
  - Add one clause for it to the file header.
  - Replace the :352-354 narration with the contract sentence and its mutation.
- [ ] `ui/tools/classic-links.test.mjs`
  - Rename the fixture `OAuth.cls` to `Reduced.cls` (:214, and the regex at :223).
  - Replace :440-446 with: AD-44 honors two exemptions, the reduced service and LDAP forms, each under its own reason; no OAuth 2.0 descriptor declares one. The mutation reads: restore any OAuth 2.0 tab's exemption → the honored set and both counts go red.
- [ ] `src/OcuPilot/Test/OAuthTabs.cls`: drop the unread eleventh element from all five `Tabs()` rows and from their doc comment.
- [ ] `src/OcuPilot/Test/Tab/Bad.cls`, `Test/TabGroup/First.cls` and `Test/TabGroup/Third.cls`: set `classicLinkExemption` to the Resource servers tab's current `{"exempt": false, "reason": "", "label": "", "href": ""}`. Each is then again the copy its doc comment claims.
- [ ] `src/OcuPilot/Test/Screen/Multi.cls:37`: change the reason to neutral fixture text, `a test detail view that keeps its classic page`, and keep the exemption.
- [ ] `ARCHITECTURE-SPINE.md:514` (AD-44). Replace the span with:

  > Release 1 has exactly two: the reduced service editor, removed by Story 16.13, and the reduced LDAP editor, removed by Story 16.14 - each counted against SM-C1, so SM-C1 counts two. Each is declared once, by `ServiceForm` and `LdapConfigForm`. The check reports the declaring descriptors under each exemption, so each exemption counts once, every declaration stays visible, and any total is recomputed from this list. The OAuth 2.0 tabs' exemption closed in Epic 12, as Stories 12.4-12.8 replaced each tab's classic editor.

  Follow it with the Rule 20 marker, `was "exactly three ... SM-C1 counts three"`.
  - Append the memlog line: `uv run --no-cache _bmad/scripts/memlog.py append --workspace <spine dir> --type decision --text "AD-44 (Story 12.9, DW-1643): two exemptions, ServiceForm and LdapConfigForm; the OAuth 2.0 exemption closed by Stories 12.4-12.8"`.
  - Run `lint_spine.py` and refresh `updated:`.
- [ ] `prd.md`
  - :298: say that two such exemptions remain, the reduced service and LDAP editors (Stories 16.13 and 16.14).
  - :698: say the exemption closed when the FR-75 editors replaced it (Stories 12.4-12.8).
  - :1198: replace the mitigation cell with `**Closed** 2026-09-25: Stories 12.4-12.8 shipped the five OAuth 2.0 editors, and Story 12.9 confirmed that no OAuth 2.0 tab links to the classic portal`.
  - Add a marker on each change, and one `(change)` memlog line.
- [ ] `EXPERIENCE.md`
  - :146: replace the row with `| OAuth 2.0 editors | Security and secrets | OAuth 2.0 row name cell · the tab's Create | each tab's entry opens its OcuPilot editor (FR-75) | form-page (tabs) | P1 |`.
  - :772: delete the words "and OAuth classic editor links" and fix the grammar ("opens a new tab").
- [ ] `epics.md:469` (UX-DR67): make the same deletion ("only the classic-link-card opens a new tab").

**Acceptance Criteria:**

- **AC1 (AD-44).** Given the OAuth 2.0 screen with the probe's objects, when each of its five tabs renders, then every name cell opens OcuPilot's editor in the same tab, nothing on the screen links to the classic portal, and no classic-link card renders.
- **AC2 (AD-44, DW-1643).** Given the shipped descriptor roster, when `classic-links` runs, then:
  - it reports `2 exemption(s) honored (SM-C1)` over `2 descriptor(s)`, which are `ServiceForm` and `LdapConfigForm`;
  - no OAuth 2.0 descriptor declares an exemption;
  - AD-44, the PRD's FR-9 and FR-44, EXPERIENCE.md and UX-DR67 name no OAuth exemption and no OAuth classic link.
- **AC3.** Given the PRD's risk row "OAuth setup is lists and deletes only at the deadline", when this story completes, then the row reads **Closed** and names Stories 12.4-12.8 and 12.9.

## Spec Change Log

- 2026-09-25, lead spec gate: Q1 the full browser suite is CI's (Rule 29); Q2 keep the row-link mechanism (AD-44 unchanged); Q3 remove only the OAuth wording from EXPERIENCE.md :772 and UX-DR67, leaving the Help-control claim to its owner; Q4 the epic context is regenerated, not hand-edited; Q5 keep `REASONOAUTHAUTHENTICATORSECRET` (text, not a link). The PRD, EXPERIENCE.md and UX-DR67 edits are tier-1 amendments: mark each `[AMENDED 2026-09-25, Story 12.9, Rule 5 tier-1]` and list them in the Auto Run Result.

## Review Triage Log

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

## Auto Run Result

Status: ready-for-dev
Blocking condition: none
