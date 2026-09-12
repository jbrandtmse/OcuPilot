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
 * Re-derives the canonical literal list from EXPERIENCE.md's Fixed strings
 * table by extracting every double-quoted span in the table's *String* column --
 * exactly the rule the story itself states: "\u00b7 (a middle dot) also occurs inside
 * strings, so only the double quotes disambiguate."
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

  const literals = [];
  // +2 skips the header row and its |---|---| separator; the table ends at the
  // first line that is not a row of it.
  for (let i = header + 2; i < lines.length; i++) {
    const line = lines[i];
    if (!line.startsWith('|')) break;
    const columns = line.split('|');
    if (columns.length < 3) break;
    for (const m of columns[1].matchAll(/"([^"]*)"/g)) {
      literals.push(m[1]);
    }
  }
  return literals;
}

/**
 * Re-derives the eight area names from EXPERIENCE.md's Information Architecture line -- "The
 * rail, top to bottom (daily-use order): Home · Logs · ..." -- the same way
 * `extractFixedStringsTable` re-derives the table: from the document, never from a second
 * static list here.
 *
 * They are a third category, distinct from the table and from REQUIRED_ALONGSIDE_TABLE. The
 * table carries no row naming an area, and its `navRailItemTooltip` row spells "<Area> ·
 * Ctrl+B toggles the side bar" -- so these eight are the domain of that placeholder, and the
 * line that enumerates them is the authority. Adding them to REQUIRED_ALONGSIDE_TABLE instead
 * would be the bypass that array's own comment forbids.
 *
 * The line's separator is " · " (a middle dot). One entry is a bare em dash marking where
 * Agent co-pilot is pinned away from the rest, and the last carries a parenthetical; both are
 * handled by cutting each entry at its first " (" and dropping any entry with no word in it.
 */
function extractAreaNames(markdown) {
  const anchor = markdown
    .split('\n')
    .find((line) => line.startsWith('**The rail, top to bottom'));
  assert.ok(anchor, "EXPERIENCE.md must carry the '**The rail, top to bottom' line the rail is built from");
  const listed = anchor.split(':**')[1];
  assert.ok(listed, 'the rail line must name its areas after the bold lead-in');
  return listed
    .split(' · ')
    .map((entry) => entry.split(' (')[0].trim())
    .filter((entry) => /[A-Za-z]/.test(entry));
}

/**
 * The three navigation landmarks' accessible names, from the Accessibility Floor's Landmarks
 * line: `rail and side-bar = navigation (named "Areas" and "<Area> screens"); locator-bar =
 * navigation "Breadcrumb"`.
 *
 * Two targeted reads rather than "every quoted span on that line", which would also authorize
 * "Skip to content" and "Agent co-pilot" -- literals no story ships yet, and which would make
 * the count assertion below wrong rather than merely generous. Story 1.10 broadened this from
 * the rail-and-side-bar pair to include the locator bar's own name, which is on the same line
 * and is the same kind of authority.
 */
function extractLandmarkNames(markdown) {
  const pair = /named "([^"]*)" and "([^"]*)"/.exec(markdown);
  assert.ok(pair, "EXPERIENCE.md must name the rail and side-bar landmarks in its Landmarks line");
  const locator = /locator-bar = navigation "([^"]*)"/.exec(markdown);
  assert.ok(locator, "EXPERIENCE.md must name the locator bar's landmark in its Landmarks line");
  return [pair[1], pair[2], locator[1]];
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
 * Development, colored ...`. Read from that row rather than typed here, the same way the
 * eight area names are read from the rail line.
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
 * status-bar word, which is already a Fixed strings table literal (:261) and is not taken here.
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

const expectedLiterals = extractFixedStringsTable(experienceMdRaw);
const expectedAreaNames = extractAreaNames(experienceMdRaw);
const expectedLandmarkNames = extractLandmarkNames(experienceMdRaw);
const expectedNamespaceName = extractNamespaceSwitchName(experienceMdRaw);
const expectedLockupName = extractLockupName(experienceMdRaw);
const expectedServerFlagWords = extractServerFlagWords(experienceMdRaw);
const [expectedUnreachableSentence, expectedRetryAction] =
  extractUnreachableBanner(experienceMdRaw);
const [expectedServerFaultSentence, ...expectedServerFaultActions] =
  extractServerFaultBanner(experienceMdRaw);

/**
 * The third category: literals EXPERIENCE.md states in prose rather than in the Fixed strings
 * table, each re-derived from the document. Distinct from `REQUIRED_ALONGSIDE_TABLE`, which
 * stays at three -- growing that array is the bypass its own comment forbids.
 */
const EXTRACTED_FROM_PROSE = [
  ...expectedAreaNames,
  ...expectedLandmarkNames,
  ...expectedNamespaceName,
  ...expectedLockupName,
  ...expectedServerFlagWords,
  expectedUnreachableSentence,
  expectedServerFaultSentence,
  ...expectedServerFaultActions,
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

test("Story 1.13's four connectivity literals are EXPERIENCE.md's own, from the rows that publish them", () => {
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

  // None of the four is a Fixed strings table literal: the table's action-names row does not
  // carry Retry or Open messages.log, and neither sentence is in it at all. An overlap would
  // make the count assertion below wrong rather than merely redundant.
  const overlap = [
    expectedUnreachableSentence,
    expectedServerFaultSentence,
    ...expectedServerFaultActions,
  ].filter((literal) => expectedLiterals.includes(literal));
  assert.deepEqual(overlap, [], `already a Fixed strings literal: ${JSON.stringify(overlap)}`);
});

test('EXPERIENCE.md names exactly the eight rail areas, and none of them is already a Fixed strings literal', () => {
  assert.equal(
    expectedAreaNames.length,
    8,
    `expected eight area names, extracted ${JSON.stringify(expectedAreaNames)}`
  );
  // The count assertion below adds the three categories, so an overlap would make it wrong
  // rather than merely redundant -- strings.ts holds one key per distinct value.
  const overlap = expectedAreaNames.filter((name) => expectedLiterals.includes(name));
  assert.deepEqual(overlap, [], `an area name is also a Fixed strings literal: ${JSON.stringify(overlap)}`);
});

test('every area name reaches the string source verbatim, so the rail renders no copy of its own', () => {
  const values = new Set(Object.values(stringsValues));
  const missing = expectedAreaNames.filter((name) => !values.has(name));
  assert.deepEqual(missing, [], `missing from strings.ts: ${JSON.stringify(missing)}`);
});

test("EXPERIENCE.md's Fixed strings table itself holds roughly 100 distinct literals -- a sanity check on the extractor before trusting it", () => {
  assert.ok(
    expectedLiterals.length >= 90 && expectedLiterals.length <= 115,
    `expected roughly 100 distinct literals, extracted ${expectedLiterals.length} -- the extractor's row range or quote-matching may have drifted from the table`
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
// as a table row (:253) rather than shipped alongside the table, so it arrives through
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
  assert.equal(
    Object.keys(stringsValues).length,
    expectedLiterals.length + EXTRACTED_FROM_PROSE.length + REQUIRED_ALONGSIDE_TABLE.length,
    `expected ${expectedLiterals.length} table literals + ${EXTRACTED_FROM_PROSE.length} extracted from prose + ${REQUIRED_ALONGSIDE_TABLE.length} named extras, found ${Object.keys(stringsValues).length} keys`
  );
});

test('Story 1.11 adds no string: the switch and its refusal are named by keys that already exist', () => {
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

  // The string table holds exactly one namespace-named key, so nothing was added here for the
  // unknown-namespace case. That is a tripwire on this one naming convention, not proof that no
  // sentence exists anywhere: a row added under another key name would pass. The claim it guards
  // -- EXPERIENCE.md publishes no sentence for a namespace that does not exist, which is why the
  // shell is silent rather than inventing one -- is filed against DW-126's root cause, and the
  // count assertion above is what catches a table that grew at all.
  const namespaceSentences = Object.entries(stringsValues).filter(([key]) =>
    key.toLowerCase().includes('namespace')
  );
  assert.deepEqual(
    namespaceSentences.map(([key]) => key),
    ['headerNamespaceLabel'],
    'the one namespace-named key is the switch\'s own accessible name'
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

test("the version-mismatch sentence, with <n> resolved, is EXPERIENCE.md :428's own words byte for byte", () => {
  // A second, independent pin on the one string the user reads. The table comparison above
  // already authorizes it; this resolves the placeholder the way the State Patterns row at
  // :428 does and looks for that result in the document, so the table row and its own
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
  const referenced = [
    ...stringsTsRaw.matchAll(
      /\/\*\* EXPERIENCE\.md:(\d+) \*\/\s*\n\s*(\w+): '((?:[^'\\]|\\.)*)',/g
    ),
  ];
  assert.ok(
    referenced.length >= 100,
    `expected at least 100 line-referenced keys, matched ${referenced.length} -- the comment convention or the key shape has changed`
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
