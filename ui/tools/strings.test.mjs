// Pins the AC rows: "String source is complete", "Voice rules hold over the
// source". Builds its expected list by reading EXPERIENCE.md's own Fixed
// strings table at run time (Design Notes: "Build the test's expected list by
// reading those lines, not from memory or from this spec") -- never by copying
// a second static list into this file, which would just check the parser
// against itself.
//
// Mutation (Rule 19): respell one canonical string in the string source (change
// a middle dot to a hyphen) -> the completeness test below goes red naming the
// literal that no longer matches the table. Append "!" to any string value ->
// the voice-rule test goes red naming the key and the rule.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { loadStrings, checkVoiceRules, extractPlaceholders, STRINGS_TS_PATH } from './strings.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const experienceMdPath = join(
  here,
  '..',
  '..',
  '_bmad-output',
  'planning-artifacts',
  'ux-designs',
  'ux-OcuPilot-2026-09-08',
  'EXPERIENCE.md'
);

const stringsTsRaw = readFileSync(STRINGS_TS_PATH, 'utf8');
const experienceMdRaw = readFileSync(experienceMdPath, 'utf8');

const stringsValues = loadStrings(stringsTsRaw);

/**
 * Re-derives the canonical rows from EXPERIENCE.md's Fixed strings table: each row's
 * literals are every double-quoted span in its *String* column -- exactly the rule the
 * story itself states: "\u00b7 (a middle dot) also occurs inside strings, so only the
 * double quotes disambiguate." -- and its *Where* cell is kept beside them.
 *
 * The table is located by its own heading and header row, never by line number
 * (DW-110). A hardcoded range silently reads the wrong rows after any insertion
 * above it, and the range was being quoted elsewhere as a reason not to add a
 * table row -- a test limitation presented as a product constraint.
 */
function extractFixedStringsTable(markdown) {
  const lines = markdown.split('\n');
  const anchor = lines.findIndex((line) => line.startsWith('**Fixed strings**'));
  assert.ok(anchor >= 0, "EXPERIENCE.md must carry the '**Fixed strings**' paragraph the table follows");
  const header = lines.findIndex((line, i) => i > anchor && line.trim() === '| String | Where |');
  assert.ok(header > anchor, "the Fixed strings table must open with a '| String | Where |' header row");

  const rows = [];
  // +2 skips the header row and its |---|---| separator; the table ends at the
  // first line that is not a row of it.
  for (let i = header + 2; i < lines.length; i++) {
    const line = lines[i];
    if (!line.startsWith('|')) break;
    const columns = line.split('|');
    if (columns.length < 3) break;
    rows.push({
      literals: [...columns[1].matchAll(/"([^"]*)"/g)].map((m) => m[1]),
      where: columns[2].trim(),
    });
  }
  return rows;
}

/**
 * The three navigation landmarks' accessible names, from the Accessibility Floor's Landmarks
 * line: `rail and side-bar = navigation (named "Areas" and "<Area> screens"); locator-bar =
 * navigation "Breadcrumb"`.
 *
 * Two targeted reads rather than "every quoted span on that line", which would also authorize
 * "Agent co-pilot" -- a literal no story ships yet, and which would make the count assertion
 * below wrong rather than merely generous. The skip link's label on the same line has its own
 * extractor below. Story 1.10 broadened this from the rail-and-side-bar pair to include the
 * locator bar's own name, which is on the same line and is the same kind of authority.
 */
function extractLandmarkNames(markdown) {
  const pair = /named "([^"]*)" and "([^"]*)"/.exec(markdown);
  assert.ok(pair, "EXPERIENCE.md must name the rail and side-bar landmarks in its Landmarks line");
  const locator = /locator-bar = navigation "([^"]*)"/.exec(markdown);
  assert.ok(locator, "EXPERIENCE.md must name the locator bar's landmark in its Landmarks line");
  return [pair[1], pair[2], locator[1]];
}

/**
 * The skip link's label, from the same Landmarks line: `A "Skip to content" link is the first Tab
 * stop`.
 */
function extractSkipLinkLabel(markdown) {
  const match = /A "([^"]*)" link is the first Tab stop/.exec(markdown);
  assert.ok(match, 'EXPERIENCE.md must name the skip link in its Landmarks line');
  return [match[1]];
}

/**
 * The namespace switch's accessible name, from the Component Patterns header row: `The
 * namespace switch (accessible name "Namespace") is a select ...`. Story 1.10 renders it as
 * the header slot's eyebrow; Story 1.11 turns the slot into the select it names.
 */
function extractNamespaceSwitchName(markdown) {
  const match = /namespace switch \(accessible name "([^"]*)"\)/.exec(markdown);
  assert.ok(match, "EXPERIENCE.md must give the namespace switch an accessible name");
  return [match[1]];
}

/** The header lockup's accessible name, from the logo-lockup row: `Accessible name "..."`. */
function extractLockupName(markdown) {
  const match = /Click navigates to Home\. Accessible name "([^"]*)"/.exec(markdown);
  assert.ok(match, "EXPERIENCE.md must give the header lockup an accessible name");
  return [match[1]];
}

/**
 * The four server-flag words, from the server-flag-badge row: `Live / Test / Failover /
 * Development, colored ...`. Read from that row rather than typed here.
 */
function extractServerFlagWords(markdown) {
  const row = markdown.split('\n').find((line) => line.startsWith('| server-flag-badge |'));
  assert.ok(row, "EXPERIENCE.md must carry the server-flag-badge Component Patterns row");
  const match = /\|\s*([A-Za-z]+(?: \/ [A-Za-z]+)+), colored/.exec(row);
  assert.ok(match, 'the server-flag-badge row must list its flag words before "colored"');
  return match[1].split(' / ');
}

/**
 * The unreachable banner's body and its one control, from the Instance-unreachable State
 * Patterns row: `one banner (\`role="alert"\`) at the top of content: "<sentence>" with <action>;
 * status-bar "Instance unreachable — retrying"`.
 *
 * Anchored on `at the top of content: ` rather than "the first quoted span on the row", which
 * would return `alert` out of the row's own `role="alert"`. The row also publishes the
 * status-bar word, which is already a Fixed strings table literal (:265) and is not taken here.
 */
function extractUnreachableBanner(markdown) {
  const row = markdown.split('\n').find((line) => line.startsWith('| Instance unreachable |'));
  assert.ok(row, 'EXPERIENCE.md must carry the Instance-unreachable State Patterns row');
  const match = /at the top of content: "([^"]+)" with ([^;|]+);/.exec(row);
  assert.ok(match, 'that row must publish the banner sentence and the control that follows it');
  return [match[1], match[2].trim()];
}

/**
 * The generic server-fault body and its two controls, from the Generic-internal-error State
 * Patterns row: `"<sentence>" (\`role="alert"\`) with Retry and Open messages.log`.
 *
 * The action list is read as a span and split on " and " rather than the two names being typed
 * into this file -- the same discipline `extractServerFlagWords` follows for the four flag
 * words, and the reason neither name can drift from the document without this going red.
 */
function extractServerFaultBanner(markdown) {
  const row = markdown.split('\n').find((line) => line.startsWith('| Generic internal error |'));
  assert.ok(row, 'EXPERIENCE.md must carry the Generic-internal-error State Patterns row');
  const match = /\| "([^"]+)" \(`role="alert"`\) with ([^|]+?)\s*\|/.exec(row);
  assert.ok(match, 'that row must publish the server-fault sentence and the actions beside it');
  return [match[1], ...match[2].split(' and ').map((name) => name.trim())];
}

/**
 * The transcript's accessible name, from the panel's Body rule: `(\`role="log"\`, polite,
 * \`aria-label="Conversation"\`, ...)`. Anchored on the Body paragraph so the Accessibility Floor's
 * second statement of the same attribute cannot stand in for a reworded first one.
 */
function extractTranscriptName(markdown) {
  const body = markdown.split('\n').find((line) => line.startsWith('**Body.** Banners, in order'));
  assert.ok(body, "EXPERIENCE.md must carry the panel's Body rule");
  const match = /`aria-label="([^"]*)"`/.exec(body);
  assert.ok(match, "the panel's Body rule must name the transcript");
  return [match[1]];
}

/**
 * The composer caption as macOS spells it. The table row publishes the Ctrl+I form and says, in its
 * Where cell, which chord replaces it there -- `(\u2318I on macOS)` -- so the macOS value is that
 * substitution over the row's own literal, never a second spelling typed here.
 */
function extractMacComposerCaption(rows) {
  const row = rows.find((candidate) => /^composer caption \((\S+) on macOS\)$/.test(candidate.where));
  assert.ok(row, 'the Fixed strings table carries the composer caption row with its macOS chord');
  const chord = /^composer caption \((\S+) on macOS\)$/.exec(row.where)[1];
  assert.equal(row.literals.length, 1, 'the caption row publishes one literal');
  assert.ok(row.literals[0].includes('Ctrl+I'), 'and it carries the Ctrl+I chord the macOS form replaces');
  return [row.literals[0].replace('Ctrl+I', chord)];
}

/**
 * The tool-call-card's "done" and "failed — <reason>" status words, from its Component
 * Patterns row's own status list: `"running" (spinner) · "done" · "done · audit marked" ·
 * "done · audit not marked" (...) · "failed — <reason>" · "blocked by read-only mode" ·
 * "Stopped by you at <step>"`. Read positionally off every quoted span on that row rather than
 * typed here, so a reworded status list is what goes red, not a copy of it.
 */
function extractToolCallCardStatuses(markdown) {
  const row = markdown.split('\n').find((line) => line.startsWith('| tool-call-card |'));
  assert.ok(row, 'EXPERIENCE.md must carry the tool-call-card Component Patterns row');
  const quoted = [...row.matchAll(/"([^"]*)"/g)].map((m) => m[1]);
  assert.equal(
    quoted.length,
    7,
    `expected 7 quoted statuses on the tool-call-card row, found ${quoted.length}: ${JSON.stringify(quoted)}`
  );
  assert.equal(quoted[0], 'running', 'the first status must be "running"');
  assert.equal(quoted[4].startsWith('failed'), true, 'the fifth status must be the failed template');
  // The third is the marked status the confirmed-write card reads (Story 5.6). Its sibling, the
  // fourth, is `REQUIRED_ALONGSIDE_TABLE`'s first entry and stays there: that array is the
  // three it was, and this one is re-derived from the document like every other prose literal.
  assert.equal(quoted[2], `${quoted[1]} \u00b7 audit marked`, 'the third status is the marked one');
  return [quoted[1], quoted[2], quoted[4]];
}

/**
 * Story 4.5's composer-locked reason, from the panel's Busy State Patterns row: `the composer
 * stays focusable and editable (\`aria-disabled\`, reason "A turn is in progress")`.
 */
function extractComposerLockedReason(markdown) {
  const match = /reason "([^"]+)"\); New conversation/.exec(markdown);
  assert.ok(match, 'EXPERIENCE.md\'s Busy row must publish the composer\'s locked reason');
  return [match[1]];
}

/**
 * Story 4.5's New-conversation locked reason, from the panel header row: `while a turn runs
 * it is \`aria-disabled\` with the reason "Stop the turn first"`.
 */
function extractNewConversationLockedReason(markdown) {
  const match = /with the reason "([^"]+)" `\[ASSUMPTION\]`\./.exec(markdown);
  assert.ok(match, 'EXPERIENCE.md\'s panel header row must publish New conversation\'s locked reason');
  return [match[1]];
}

/**
 * Story 5.13's two removal forms, from the `diff-row` Component Patterns row: `it shows the
 * target's identifying fields as \`field \u00b7 value \u2192 (removed)\`, reads "<field>:
 * <value>, removed"`.
 *
 * Two literals, because the row publishes two: the marker the after cell draws, and the direction
 * word that replaces "was"/"now" so the row is spoken as the row says it reads. A targeted read
 * rather than "every quoted span on that row", which would also drag in `"Reverse:"` -- already a
 * Fixed strings literal, and the overlap test below would then fail rather than merely be
 * generous.
 */
function extractRemovalForms(markdown) {
  const match =
    /identifying fields as `field [^`]*\((removed)\)`, reads "<field>: <value>, (removed)"/.exec(
      markdown
    );
  assert.ok(
    match,
    "EXPERIENCE.md's diff-row row must publish the delete row's drawn and spoken removed forms"
  );
  return [`(${match[1]})`, match[2]];
}

const fixedStringsRows = extractFixedStringsTable(experienceMdRaw);
const expectedLiterals = fixedStringsRows.flatMap((row) => row.literals);
const expectedLandmarkNames = extractLandmarkNames(experienceMdRaw);
const expectedSkipLinkLabel = extractSkipLinkLabel(experienceMdRaw);
const expectedNamespaceName = extractNamespaceSwitchName(experienceMdRaw);
const expectedLockupName = extractLockupName(experienceMdRaw);
const expectedServerFlagWords = extractServerFlagWords(experienceMdRaw);
const [expectedUnreachableSentence, expectedRetryAction] =
  extractUnreachableBanner(experienceMdRaw);
const [expectedServerFaultSentence, ...expectedServerFaultActions] =
  extractServerFaultBanner(experienceMdRaw);
const expectedTranscriptName = extractTranscriptName(experienceMdRaw);
const expectedMacComposerCaption = extractMacComposerCaption(fixedStringsRows);
const [expectedToolCallDone, expectedToolCallMarked, expectedToolCallFailed] =
  extractToolCallCardStatuses(experienceMdRaw);
const expectedComposerLockedReason = extractComposerLockedReason(experienceMdRaw);
const expectedNewConversationLockedReason = extractNewConversationLockedReason(experienceMdRaw);
const expectedRemovalForms = extractRemovalForms(experienceMdRaw);

/**
 * The third category: literals EXPERIENCE.md states in prose rather than in the Fixed strings
 * table, each re-derived from the document. Distinct from `REQUIRED_ALONGSIDE_TABLE`, which
 * stays at three -- growing that array is the bypass its own comment forbids.
 */
const EXTRACTED_FROM_PROSE = [
  ...expectedLandmarkNames,
  ...expectedSkipLinkLabel,
  ...expectedNamespaceName,
  ...expectedLockupName,
  ...expectedServerFlagWords,
  expectedUnreachableSentence,
  expectedServerFaultSentence,
  ...expectedTranscriptName,
  ...expectedMacComposerCaption,
  expectedToolCallDone,
  expectedToolCallMarked,
  expectedToolCallFailed,
  ...expectedComposerLockedReason,
  ...expectedNewConversationLockedReason,
  ...expectedRemovalForms,
];

test('the three navigation landmarks are named in EXPERIENCE.md and reach the string source', () => {
  assert.deepEqual(
    expectedLandmarkNames.length,
    3,
    'the rail, the side bar and the locator bar each carry a landmark name'
  );
  const values = new Set(Object.values(stringsValues));
  const missing = expectedLandmarkNames.filter((name) => !values.has(name));
  assert.deepEqual(missing, [], `missing from strings.ts: ${JSON.stringify(missing)}`);
  assert.ok(
    expectedLandmarkNames.some((name) => name.includes('<Area>')),
    "the side bar's landmark keeps its <Area> placeholder, so the component resolves it"
  );
});

test('the skip link label is the Landmarks line\'s own, and the key the shell renders holds it', () => {
  assert.equal(stringsValues.navSkipToContent, expectedSkipLinkLabel[0]);
});

test("the header's two accessible names and the four flag words are EXPERIENCE.md's own", () => {
  const values = new Set(Object.values(stringsValues));
  assert.equal(expectedServerFlagWords.length, 4, `expected four flag words, extracted ${JSON.stringify(expectedServerFlagWords)}`);
  const extracted = [...expectedNamespaceName, ...expectedLockupName, ...expectedServerFlagWords];
  const missing = extracted.filter((name) => !values.has(name));
  assert.deepEqual(missing, [], `missing from strings.ts: ${JSON.stringify(missing)}`);
  // The em dash is what `epics.md:1350` renders as a hyphen. EXPERIENCE.md is the authority
  // for every word, so the dash travels byte for byte -- as an escape in the source (Rule 14)
  // and as the character itself once parsed.
  assert.ok(
    expectedLockupName[0].includes('\u2014'),
    `the lockup name keeps EXPERIENCE.md's em dash: ${JSON.stringify(expectedLockupName[0])}`
  );

  // WHICH key holds which word, not only that all four arrived. Everything else about these
  // four strings is set-based -- the authorized-values check, the uniqueness check and the
  // key count all pass on a permutation -- and `server-flag.ts`'s switch is compared against
  // the same `STRINGS.serverFlag*` symbols it reads, so the comparison cannot see a swap.
  // Swapping `serverFlagLive` and `serverFlagDevelopment` ships a production instance
  // labelled Development with nothing red. The row lists them in the vendor's own order
  // (`irissys/%SYSTEM/Version.cls`: LIVE, TEST, FAILOVER, DEVELOPMENT), which is the order
  // `extractServerFlagWords` returns.
  assert.equal(stringsValues.serverFlagLive, expectedServerFlagWords[0]);
  assert.equal(stringsValues.serverFlagTest, expectedServerFlagWords[1]);
  assert.equal(stringsValues.serverFlagFailover, expectedServerFlagWords[2]);
  assert.equal(stringsValues.serverFlagDevelopment, expectedServerFlagWords[3]);
});

test("the panel's transcript name and the macOS composer caption are EXPERIENCE.md's own", () => {
  assert.equal(stringsValues.agentConversationLabel, expectedTranscriptName[0]);
  assert.equal(stringsValues.agentComposerCaptionMac, expectedMacComposerCaption[0]);
  assert.ok(stringsValues.agentComposerCaptionMac.includes('\u2318I'), 'the macOS form spells the command glyph');
  assert.equal(
    stringsValues.agentComposerCaptionMac.replace('\u2318I', 'Ctrl+I'),
    stringsValues.agentComposerCaption,
    'and differs from the published caption by the chord alone'
  );
});

test("Story 4.5's tool-call status words and the two locked-control reasons are EXPERIENCE.md's own", () => {
  assert.equal(stringsValues.toolCallStatusDone, expectedToolCallDone);
  assert.equal(stringsValues.toolCallStatusFailed, expectedToolCallFailed);
  assert.ok(stringsValues.toolCallStatusFailed.includes('<reason>'));
  assert.equal(stringsValues.agentComposerLockedReason, expectedComposerLockedReason[0]);
  assert.equal(stringsValues.agentNewConversationLockedReason, expectedNewConversationLockedReason[0]);
});

test("Story 5.13's two removal forms are EXPERIENCE.md's own, and the residue sentence is the table's", () => {
  assert.equal(stringsValues.proposalDiffRemovedValue, expectedRemovalForms[0]);
  assert.equal(stringsValues.proposalDiffRemoved, expectedRemovalForms[1]);
  // The drawn marker is the spoken word in parentheses, which is what lets the card render one
  // `aria-hidden` and the other visually hidden without publishing a third spelling.
  assert.equal(expectedRemovalForms[0], `(${expectedRemovalForms[1]})`);
  assert.ok(
    expectedLiterals.includes(stringsValues.proposalResidue),
    "the residue sentence is the Fixed strings table's own"
  );
  assert.ok(stringsValues.proposalResidue.includes('<n>'), 'and keeps its count placeholder');
});

test('AD-48: the residue sentence keeps both its facts, independent of the citation match (QA)', () => {
  // The test above only requires `proposalResidue` to equal SOME row EXPERIENCE.md's Fixed
  // strings table publishes. A rewrite that tightens the wording for card width and updates
  // EXPERIENCE.md to match would still pass that check even if it dropped the second fact -- the
  // spec's own warning ("a version saying only 'removes <n> errors' fails the AC's second half").
  // This test reads the string's own content for AD-48's two facts, independent of the citation.
  //
  // Mutation (Rule 19): shorten `proposalResidue` in `strings.ts` to its first sentence alone
  // ("Removes exactly the <n> errors listed here.") -- the second assertion below goes red even
  // though the count placeholder survives and even if the Fixed strings table's own row were
  // rewritten to match.
  const sentence = stringsValues.proposalResidue;
  assert.ok(
    /exactly the <n> errors/i.test(sentence),
    'fact 1 (what the confirm removes): exactly the enumerated count, never a live re-query'
  );
  assert.ok(
    /will remain/i.test(sentence),
    "fact 2 (the residue AD-48 requires): an error logged since the proposal is not among them and survives"
  );
});

test("the connectivity banners' sentences and actions are EXPERIENCE.md's own, from the rows that publish them", () => {
  const values = new Set(Object.values(stringsValues));

  assert.equal(stringsValues.connectivityBannerUnreachable, expectedUnreachableSentence);
  assert.equal(stringsValues.connectivityServerFault, expectedServerFaultSentence);
  assert.deepEqual(expectedServerFaultActions, [stringsValues.actionRetry, stringsValues.actionOpenMessagesLog],
    `the server-fault row must name exactly Retry and Open messages.log, in that order; extracted ${JSON.stringify(expectedServerFaultActions)}`);
  for (const literal of [expectedUnreachableSentence, expectedServerFaultSentence, ...expectedServerFaultActions]) {
    assert.ok(values.has(literal), `missing from strings.ts: ${JSON.stringify(literal)}`);
  }

  // The Instance-unreachable row names Retry too, and the story renders ONE Retry control on
  // both banners -- so the two rows have to agree about its name. If they ever stop agreeing,
  // this is what says so rather than one of the two silently winning.
  assert.equal(expectedRetryAction, stringsValues.actionRetry);

  // The unreachable sentence is published twice, identically: the Voice and Tone table's *Do*
  // column and the State Patterns row the extractor reads. Held equal here so a reword of
  // either one cannot ship as a second spelling of the same sentence.
  const doColumn = experienceMdRaw
    .split('\n')
    .find((line) => line.startsWith(`| "${expectedUnreachableSentence}" |`));
  assert.ok(
    doColumn,
    `the Voice and Tone *Do* column must carry the same sentence verbatim: ${JSON.stringify(expectedUnreachableSentence)}`
  );

  // The two actions arrive through the Fixed strings table's action-names row; the two
  // sentences are not in the table at all.
  for (const action of expectedServerFaultActions) {
    assert.ok(expectedLiterals.includes(action), `not a Fixed strings literal: ${JSON.stringify(action)}`);
  }
  const overlap = [expectedUnreachableSentence, expectedServerFaultSentence].filter((literal) =>
    expectedLiterals.includes(literal)
  );
  assert.deepEqual(overlap, [], `already a Fixed strings literal: ${JSON.stringify(overlap)}`);
});

test('no literal extracted from prose is also a Fixed strings literal', () => {
  // The count assertion below adds the three categories, so an overlap would make it wrong
  // rather than merely redundant -- strings.ts holds one key per distinct value.
  const overlap = EXTRACTED_FROM_PROSE.filter((literal) => expectedLiterals.includes(literal));
  assert.deepEqual(overlap, [], `already a Fixed strings literal: ${JSON.stringify(overlap)}`);
});

test("the table's area-names row lists the eight navArea keys' values, in rail order", () => {
  const rows = fixedStringsRows.filter((row) => row.where.startsWith('area names'));
  assert.equal(rows.length, 1, 'the Fixed strings table carries one area-names row');
  assert.deepEqual(rows[0].literals, [
    stringsValues.navAreaHome,
    stringsValues.navAreaLogs,
    stringsValues.navAreaOsManagement,
    stringsValues.navAreaTasks,
    stringsValues.navAreaPermissions,
    stringsValues.navAreaWebApplications,
    stringsValues.navAreaSecurity,
    stringsValues.navAreaAgent,
  ]);
});

test("EXPERIENCE.md's Fixed strings table itself holds roughly 200 distinct literals -- a sanity check on the extractor before trusting it", () => {
  // The band is the extractor's tripwire, not a budget: it catches a run that read a fraction of
  // the table (a drifted anchor) or far too much of the document (a broken row terminator). It
  // widens by the rows a story adds -- Story 2.10's four rows carry 17 literals: the audit
  // database list's six, its criteria form's seven, the agent-marker filter's one and the detail
  // dialog's three -- and it is the count assertion below, derived from the table itself, that
  // holds strings.ts to it exactly. Story 2.12's four rows carry 17: the application error log's
  // six column and title literals, its three scope-naming empty states, its detail's seven
  // section and column headings, and its Back control. Story 3.5's three rows carry 22: the
  // Definitions list's nine -- its title, three column headers, two empty-state literals and
  // three row actions -- the Definition form's ten, and the reveal toggle's two names with the
  // retention caption. Story 3.7's three rows carry 10: the Switches screen's eight -- its title,
  // the kill switch and its reason field, the enforced-read-only toggle, and the per-user
  // section's heading, add action, row action and empty state -- the context-sharing default, and
  // the action slot a refused Switches call resolves. (Story 3.6 added rows but no entry: at 236
  // literals it still fit the band.)
  //
  // Why the upper bound moves to 260 rather than to the 246 the table then held: the band is a
  // tripwire against unbounded string growth, not a cap on one screen. It has held because every
  // widening was deliberate and documented here, and 260 leaves headroom for Story 3.8 and the
  // burn-down without making the next widening automatic. Story 6.1's two rows carry 14 -- the REST
  // API explorer's three and the OpenAPI document viewer's eleven -- and take the table to 261, so
  // the bound moves to 300, the headroom Epic 6's remaining screens need. Story 6.4's three OAuth 2.0 rows carry 22 and take the table past 300, so the bound moves to 330. Story 6.6's two rows
  // carry 13 distinct literals -- "Error number" is reused from the Application errors row rather
  // than counted again -- and take the table past 330, so the bound moves to 350. Story 6.7's one
  // row carries 38: eleven Task details field and chrome labels, ten TimePeriod/DailyFrequency
  // phrase templates, five DailyFrequencyTime phrase templates, seven weekday names and five
  // ordinals -- the schedule-in-words vocabulary AD-3 has the client compose rather than take from
  // the vendor -- and takes the table past 350, so the bound moves to 400. Story 6.8's one row
  // carries 24: the screen title, the "no longer exists" empty state, three group headings and
  // nineteen field labels beyond the shared Process ID, User, Namespace, Priority, Routine, State,
  // Commands and "Started" -- and takes the table to 399, still inside the 400 bound Story 6.7 set.
  // Story 6.9's one row carries 17: the screen title, eight counters-group labels beyond the
  // Process details row's "Global references", seven meter labels and the empty state -- the
  // meter state word itself (Normal / Warning / Troubled) is vendor data rendered as reported
  // rather than a translated string, so it carries no literal here -- and takes the table to 416,
  // past the 400 bound, so the bound moves to 450. Story 6.10's one row carries 7 (Locks' title,
  // three column headers beyond the Processes row's own, the local-system word and the empty
  // state) and takes the table to 423, still inside the 450 bound Story 6.9 set. Story 6.11's one
  // row carries 24: the Databases screen title, the Free-space view's own title (also the View
  // control's second option), the View control's accessible name, five column headers beyond the
  // Locks row's "Directory", the Task history row's "Status" and the Web applications row's
  // "Resource", the list's empty state, Database details' title, its "no longer exists" empty
  // state, eight of its remaining field labels, and the volume-files section's heading, three
  // column headers beyond its own reused ones and its own empty state -- and takes the table to
  // 447, three short of the 450 bound left after Story 6.9. Three of headroom for one story and
  // none for 6.12 through 6.14 is not headroom, so the bound moves to 520 now rather than at the
  // next story that would have exceeded it.
  //
  // Epic 4's panel rows arrive with this merge: Story 4.4's five (Definitions, Full screen, the
  // resize handle's name, the context row count and the secret-fields warning), Story 4.11's four
  // (the paste warning with its two actions, and the chip's key glyph), Story 4.8's one (the banner
  // for a turn whose failure names no step) and Story 4.10's three (the suggested view's eyebrow,
  // its open control and the application-errors line). The 520 bound Story 6.11 set absorbs them,
  // so no widening is needed here -- only the measured figure in the message moves.
  //
  // **Story 15.2 moves the bound to 600, which is this file's documented widening protocol rather
  // than a loosening of the assertion.** Its one row publishes fifteen literals -- the two Home
  // blocks' headings, empty states, per-row remove names and Clear controls, the locator bar's
  // favorite toggle in its two states, and the five polite confirmations the two surfaces announce
  // -- taking the table to 505. Fifteen of headroom against the four Epic 15 stories still to land
  // (15.3's About, help, shortcuts and links panel alone publishes more than that) is not headroom,
  // so the bound moves now rather than inside the story that would have tripped it. What the
  // tripwire is for is unchanged -- it catches a run that read a fraction of the table or far too
  // much of the document -- and the exact count assertion below, derived from the table itself, is
  // what still holds strings.ts to the table literal for literal.
  //
  // Story 8.5 moves the bound to 700 under the same protocol: its five rows publish fourteen
  // literals -- the X.509 list's Import and agent invitation, the credential form's title, seven
  // labels, its Load from file button and two helpers, and the proposal card's optional mark -- and
  // take the table past 600.
  //
  // Story 9.1 moves the bound to 800 under the same protocol: its four rows publish nineteen
  // literals -- the sign-in refusal, the user editor's ten labels and empty state, the tab
  // error names and five suggested-prompt literals -- and take the table past 700, with the rest of
  // Epic 9's editors still to land.
  //
  // Story 9.5 moves the bound to 900 under the same protocol: its ten rows publish fifty-seven
  // literals -- the SSL/TLS editor's title, tabs, labels and select words, its captions, effect,
  // refusal, Test connection panel and prompts, three delete consequences and the list-less absent
  // sentence -- and take the table past 800.
  //
  // Story 11.10 moves the bound to 750 under the same protocol: its one row publishes one literal,
  // "Jump to latest", and takes the table to 701.
  //
  // Story 12.1 moves the bound to 800 under the same protocol: its one row's two literals take the
  // table past 700, with Epic 12's OAuth editors still to publish theirs.
  //
  // Story 9.9 moves the bound to 1000 under the same protocol: its six rows publish twenty-nine
  // literals -- the two reduced forms' titles, fields, list controls and captions, their bare and
  // absent sentences, the serving-service refusal, two effects and six prompts -- and take the
  // table past 900.
  //
  // Epic 12's integration of Epic 9 moves the bound to 1100 under the same protocol: Stories
  // 12.1-12.5's rows and Epic 9's together take the table past 1000.
  //
  // Story 12.8 moves the bound to 1200 under the same protocol: its one row's fifteen literals take
  // the table past 1100.
  assert.ok(
    expectedLiterals.length >= 150 && expectedLiterals.length <= 1200,
    `expected between 150 and 1200 distinct literals, extracted ${expectedLiterals.length} -- the extractor's row range or quote-matching may have drifted from the table`
  );
});

test('every literal in the Fixed strings table exists verbatim as some key\'s value in the string source', () => {
  const values = new Set(Object.values(stringsValues));
  const missing = expectedLiterals.filter((literal) => !values.has(literal));
  assert.deepEqual(missing, [], `missing from strings.ts: ${JSON.stringify(missing)}`);
});

// The converse. The test above is one-directional: it proves the table reached
// strings.ts, never that strings.ts holds nothing else. A paraphrased or invented
// value would pass it, pass client-lint (which only checks that a rendered key
// EXISTS), and ship as product copy no document authorizes -- and it would also
// hide a silently-dropped table row, since a shrunken expected list still matches.
// EXPERIENCE.md is the sole authority for every word (intent contract), so the two
// sets differ by exactly the literals the ACs require alongside the table.
//
// Three, not four: Story 1.8's version-mismatch sentence is NOT one of them. It was filed
// as a table row (:255) rather than shipped alongside the table, so it arrives through
// `expectedLiterals` like every other string and this array is unchanged. Keep it that way
// -- an extra entry here is the bypass this mechanism must not become.
const REQUIRED_ALONGSIDE_TABLE = [
  'done \u00b7 audit not marked',
  'running',
  'OcuPilot',
];

test('the string source holds nothing the documents do not authorize -- the table, the literals extracted from prose, and exactly three named extras', () => {
  const authorized = new Set([...expectedLiterals, ...EXTRACTED_FROM_PROSE, ...REQUIRED_ALONGSIDE_TABLE]);
  const unauthorized = Object.entries(stringsValues)
    .filter(([, value]) => !authorized.has(value))
    .map(([key, value]) => `${key}: ${JSON.stringify(value)}`);
  assert.deepEqual(
    unauthorized,
    [],
    `values in strings.ts that appear in no source document: ${JSON.stringify(unauthorized, null, 2)}`
  );
  // Distinct literals: a table row may publish a word another row already does ("Definitions" is
  // both the Definitions list's title and the reminder banner's link), and every value here is
  // held by exactly one key.
  const distinctLiterals = new Set(expectedLiterals).size;
  assert.equal(
    Object.keys(stringsValues).length,
    distinctLiterals + EXTRACTED_FROM_PROSE.length + REQUIRED_ALONGSIDE_TABLE.length,
    `expected ${distinctLiterals} distinct table literals + ${EXTRACTED_FROM_PROSE.length} extracted from prose + ${REQUIRED_ALONGSIDE_TABLE.length} named extras, found ${Object.keys(stringsValues).length} keys`
  );
});

test('Story 1.11 adds no string: the switch and its refusal are named by keys that already exist -- and the namespace-key roster that pins which keys may name one', () => {
  // The namespace switch's accessible name and the sentence a missing privilege is named with
  // are both already here, extracted from EXPERIENCE.md by the two mechanisms above. A story
  // that needed a new word for either would have had to grow one of the three categories, and
  // the count assertion above is what would have caught it.
  assert.equal(stringsValues.headerNamespaceLabel, expectedNamespaceName[0]);
  assert.ok(stringsValues.privilegeRequiresResource.includes('<resource>'));
  assert.ok(
    expectedLiterals.includes(stringsValues.privilegeRequiresResource),
    "the gated-control sentence is the Fixed strings table's own"
  );
  assert.equal(REQUIRED_ALONGSIDE_TABLE.length, 3, 'and the named-extras array is still the three it was');

  // The roster of every namespace-named key, enumerated rather than counted, so adding one stays
  // a deliberate act. It is a tripwire on this naming convention, not proof about the document:
  // a sentence added under another key name would pass it, and the count assertion above is what
  // catches a table that grew at all.
  //
  // Three keys, and each means a different thing about a namespace. `headerNamespaceLabel` is the
  // switch's accessible name. `errorLogEmptyNamespace` (Story 2.12) names a namespace the user
  // drilled INTO that records nothing. `errorLogRefusedNamespace` (Story 3.0) is the one the
  // application error log publishes for a namespace this log does not carry -- so on this screen
  // there IS now a sentence for an unknown namespace, which supersedes the claim this roster
  // carried for DW-126: the shell is silent for a namespace only where no screen publishes copy.
  // `userFormNamespace` is a field label, not a sentence about a namespace: the create-a-user
  // form's startup namespace, which the account enters on sign-in.
  const namespaceSentences = Object.entries(stringsValues).filter(([key]) =>
    key.toLowerCase().includes('namespace')
  );
  assert.deepEqual(
    namespaceSentences.map(([key]) => key).sort(),
    ['errorLogEmptyNamespace', 'errorLogRefusedNamespace', 'headerNamespaceLabel', 'userFormNamespace'],
    'the namespace-named keys are the switch\'s accessible name, one drilled-scope empty state, one named refusal and one field label'
  );
});

test('"done \\u00b7 audit not marked" and "running" are present verbatim (required alongside the table, not from it)', () => {
  const values = new Set(Object.values(stringsValues));
  // Authored as an escape, never a literal byte (Rule 14): this is the one
  // assertion guarding the exact corruption that rule exists to prevent -- the
  // epic file's own copy of this string was normalized to a hyphen once already.
  assert.ok(values.has('done \u00b7 audit not marked'), 'missing the audit-marker-failure fallback text');
  assert.ok(values.has('running'), 'missing the reduced-motion spinner-replacement word');
});

test('the version-mismatch sentence, with <n> resolved, is EXPERIENCE.md "Version mismatch"\'s own words byte for byte', () => {
  // A second, independent pin on the one string the user reads. The table comparison above
  // already authorizes it; this resolves the placeholder the way the State Patterns row at
  // :448 does and looks for that result in the document, so the table row and its own
  // illustration are held equal. A typographic apostrophe, a reworded clause or a moved
  // semicolon all fail here.
  const resolved = stringsValues.authAdminApiVersionMismatch.replace('<n>', '1');
  assert.ok(
    experienceMdRaw.includes(resolved),
    `EXPERIENCE.md does not carry this sentence verbatim: ${JSON.stringify(resolved)}`
  );
  assert.ok(
    stringsValues.authAdminApiVersionMismatch.includes('<n>'),
    'and the stored form keeps the table\'s <n> convention, so the component substitutes it'
  );
});

test("the data table's footer, empty cell and status words are one Fixed strings row, and the cap notice keeps <n>", () => {
  const row = fixedStringsRows.find((candidate) => candidate.literals.includes('Max rows'));
  assert.ok(row, 'the Fixed strings table carries the data-table footer row');
  assert.deepEqual(row.literals, [
    stringsValues.tableRowCount,
    stringsValues.tableMaxRowsLabel,
    stringsValues.tableEmptyValue,
    stringsValues.tableStatusYes,
    stringsValues.tableStatusNo,
  ]);
  assert.ok(stringsValues.tableRowCount.includes('<n>'), 'the row count is substituted, not stored');
  assert.ok(stringsValues.tableRowCapNotice.includes('<n>'), 'the cap notice carries the cap, not a literal 1,000');
  const resolved = stringsValues.tableRowCapNotice.replace('<n>', '1,000');
  assert.ok(
    experienceMdRaw.includes(resolved),
    `the cap notice at the default cap is EXPERIENCE.md's own illustration: ${JSON.stringify(resolved)}`
  );
});

test('the product name is present', () => {
  assert.ok(Object.values(stringsValues).includes('OcuPilot'));
});

test('every key in strings.ts is declared exactly once', () => {
  const keys = [...stringsTsRaw.matchAll(/^\s*(\w+):\s*'(?:[^'\\]|\\.)*',\s*$/gm)].map((m) => m[1]);
  const counts = new Map();
  for (const key of keys) counts.set(key, (counts.get(key) ?? 0) + 1);
  const duplicates = [...counts.entries()].filter(([, count]) => count > 1).map(([key]) => key);
  assert.deepEqual(duplicates, [], `duplicate keys in strings.ts: ${JSON.stringify(duplicates)}`);
  assert.ok(keys.length >= 100, `expected at least 100 keys, found ${keys.length}`);
});

test('every value in strings.ts is unique', () => {
  const values = Object.values(stringsValues);
  const counts = new Map();
  for (const value of values) counts.set(value, (counts.get(value) ?? 0) + 1);
  const duplicates = [...counts.entries()].filter(([, count]) => count > 1).map(([value]) => value);
  assert.deepEqual(duplicates, [], `duplicate values in strings.ts: ${JSON.stringify(duplicates)}`);
});

// --- Voice rules --------------------------------------------------------------

test('no value in the string source violates a voice rule (no "!", no "Oops", no emoji, no "successfully")', () => {
  const result = checkVoiceRules(stringsValues);
  assert.equal(result.ok, true, `voice-rule violations:\n${result.errors.join('\n')}`);
});

test('checkVoiceRules itself catches each of the four violations on a fixture', () => {
  const result = checkVoiceRules({
    a: 'Saved!',
    b: 'Oops, something went wrong.',
    c: 'Saved \u2728', // an emoji, authored as an escape (Rule 14)
    d: 'Configured successfully.',
    e: 'This value is fine.',
  });
  assert.equal(result.ok, false);
  assert.equal(result.errors.length, 4, `expected exactly 4 violations (a,b,c,d), got: ${JSON.stringify(result.errors)}`);
});

// --- Placeholders ---------------------------------------------------------------

test('extractPlaceholders finds every <placeholder> span in a value', () => {
  assert.deepEqual(
    extractPlaceholders(stringsValues.proposalFooterRunsAs),
    ['<user name>'],
    `expected proposalFooterRunsAs to carry exactly one <user name> placeholder`
  );
  assert.deepEqual(extractPlaceholders('no placeholder here'), []);
  assert.deepEqual(extractPlaceholders('<a> and <b>'), ['<a>', '<b>']);
});

test('every placeholder-bearing value parses without a stray unmatched angle bracket', () => {
  for (const [key, value] of Object.entries(stringsValues)) {
    const opens = (value.match(/</g) ?? []).length;
    const closes = (value.match(/>/g) ?? []).length;
    assert.equal(opens, closes, `${key}: unbalanced angle brackets in ${JSON.stringify(value)}`);
  }
});

// --- The `/** EXPERIENCE.md:n */` references themselves ---------------------------------------

test("every EXPERIENCE.md line reference resolves to a line that actually carries its key's value", () => {
  // Story 1.13 rewrote 105 of these, and nothing checked them. They had already drifted once --
  // a row inserted at :253 shifted every reference below it and none was updated -- and the
  // count was mis-measured once on the way to fixing it. A reference is a navigation aid a
  // reader follows; a wrong one sends them to an unrelated row, silently.
  //
  // Resolved the way the extractors above resolve everything else: against the document, never
  // against a second list here.
  //
  // Mutation (Rule 19): decrement any one `/** EXPERIENCE.md:n */` in strings.ts by 1 -> this
  // goes red naming that key and both lines.
  const lines = experienceMdRaw.split('\n');
  // `:\s*'` rather than `: '`: prettier wraps a long literal onto the line after its key, and a
  // pattern that required the value on the key's own line skipped every such key silently -- so
  // the longest published sentences, which are exactly the ones a drifting reference hurts most,
  // were the ones going unchecked.
  const referenced = [
    ...stringsTsRaw.matchAll(
      /\/\*\* EXPERIENCE\.md:(\d+) \*\/\s*\n\s*(\w+):\s*'((?:[^'\\]|\\.)*)',/g
    ),
  ];
  // Every reference, not "at least a hundred of them": a floor cannot see one key dropping out of
  // the match, which is how the wrapped keys stayed invisible.
  const comments = (stringsTsRaw.match(/\/\*\* EXPERIENCE\.md:/g) ?? []).length;
  assert.equal(
    referenced.length,
    comments,
    `${comments} keys carry an EXPERIENCE.md reference and ${referenced.length} matched -- a key whose value the pattern cannot reach is never checked`
  );

  const wrong = [];
  for (const [, rawLine, key, rawValue] of referenced) {
    const lineNo = Number(rawLine);
    // The source is escaped (Rule 14); compare against what it parses to, as the document
    // carries the characters themselves.
    const value = rawValue
      .replace(/\\u([0-9a-fA-F]{4})/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)))
      .replace(/\\'/g, "'");
    const line = lines[lineNo - 1] ?? '';
    if (!line.includes(`"${value}"`)) {
      const actual = lines.findIndex((candidate) => candidate.includes(`"${value}"`)) + 1;
      wrong.push(`${key}: comment says :${lineNo}, value is on :${actual || 'nowhere'}`);
    }
  }
  assert.deepEqual(wrong, [], `line references that do not resolve:\n${wrong.join('\n')}`);
});
