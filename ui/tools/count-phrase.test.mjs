// Pins the one rule that chooses a count sentence's singular (`core/count-phrase.ts`): a count of
// exactly 1 reads the singular, 0 and 2 or more read the plural, and no other module makes that
// choice. Two scans read the application source and name the file and line: one finds a count
// sentence chosen inline, the other a singular key reached other than through `pickCount`. Two more
// read the tests: an expected digit pattern that names the plural alone (`\d+ rows`, which fails at a
// count of 1), and a plural that has a singular filled with the literal 1.
//
// Mutations (Rule 19):
// - `=== 1` becomes `<= 1` in `pickCount` -> the 0 case goes red.
// - `rowCountPhrase` formats `STRINGS.tableRowCount` alone -> the 1 case goes red.
// - choose `part.count === 1 ? phrases.one : ...` inline in `core/impact.ts` -> the inline scan goes red.
// - restore a private `pick(count, one, many)` in `core/sql-answer.ts` and call it -> the singular-key scan goes red.
// - write `/^\d+ lines removed/` in a browser spec -> the test scan of expected count patterns goes red.
// - fill `STRINGS.explorerImportDone` with '1' in a browser spec -> the fill scan goes red.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readdirSync, readFileSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const appRoot = join(uiRoot, 'src', 'app');
const core = (name) => join(appRoot, 'core', name);

const { capNoticePhrase, downloadCappedPhrase, pickCount, rowCountPhrase } = await import(core('count-phrase.ts'));
const { STRINGS } = await import(core('strings.ts'));

test('pickCount answers the singular at exactly 1 and the plural at 0 and at 2 or more', () => {
  assert.equal(pickCount(0, 'one', 'many'), 'many');
  assert.equal(pickCount(1, 'one', 'many'), 'one');
  assert.equal(pickCount(2, 'one', 'many'), 'many');
  assert.equal(pickCount(1000, 'one', 'many'), 'many');
});

test('rowCountPhrase reads 0 rows, 1 row, 2 rows and 1,000 rows', () => {
  assert.equal(rowCountPhrase(0), '0 rows');
  assert.equal(rowCountPhrase(1), '1 row');
  assert.equal(rowCountPhrase(2), '2 rows');
  assert.equal(rowCountPhrase(1000), '1,000 rows');
});

test('the cap notice and the Download CSV description read the first row at a cap of one', () => {
  assert.equal(capNoticePhrase(1), 'Showing the first row. Narrow the filter or raise the max rows.');
  assert.equal(capNoticePhrase(1000), 'Showing the first 1,000 rows. Narrow the filter or raise the max rows.');
  assert.equal(downloadCappedPhrase(1), 'The file holds the first row only.');
  assert.equal(downloadCappedPhrase(2), 'The file holds the first 2 rows only.');
});

test('every plural count string this rule serves has a singular beside it that differs from it', () => {
  const pairs = [
    ['toolCallReadResultLine', ['toolCallReadResultLineOne']],
    ['commandBoxResultCount', ['commandBoxResultCountOneFirst', 'commandBoxResultCountOneSecond', 'commandBoxResultCountOneBoth']],
    ['agentLedgerWithheld', ['agentLedgerWithheldOne']],
    ['agentLedgerDropped', ['agentLedgerDroppedOne']],
    ['explorerExportSaved', ['explorerExportSavedOne']],
    ['explorerExportDone', ['explorerExportDoneOne']],
    ['explorerImportDone', ['explorerImportDoneOne']],
    ['explorerImportDoneErrors', ['explorerImportDoneErrorsOne']],
    ['explorerCompileSummary', ['explorerCompileSummaryOne']],
    ['explorerCompileStopped', ['explorerCompileStoppedOne']],
    ['explorerDeleteRunning', ['explorerDeleteRunningOne']],
    ['explorerDeleteSummary', ['explorerDeleteSummaryOne']],
    ['explorerCompareSummary', ['explorerCompareSummaryOneFirst', 'explorerCompareSummaryOneSecond', 'explorerCompareSummaryOneBoth']],
    ['proposalResidue', ['proposalResidueOne']],
    ['proposalUnchangedFieldsDisclosure', ['proposalUnchangedFieldsDisclosureOne']],
    ['proposalOpaqueCount', ['proposalOpaqueCountOne']],
    ['oauthResourceServerMappingsRefused', ['oauthResourceServerMappingsRefusedOne']],
    ['tryItBinary', ['tryItBinaryOne']],
    ['tableRowCapNotice', ['tableRowCapNoticeOne']],
    ['tableDownloadCsvCapped', ['tableDownloadCsvCappedOne']],
    ['agentTurnLimitBanner', ['agentTurnLimitBannerOne']],
    ['agentTurnLimitLine', ['agentTurnLimitLineOne']],
    ['agentGuardrailsTurnsLimit', ['agentGuardrailsTurnsLimitOne']],
    ['agentGuardrailsContextLimits', ['agentGuardrailsContextLimitsOne']],
    ['agentDefinitionRetentionCaption', ['agentDefinitionRetentionCaptionOne']],
    ['interopTestMaxLength', ['interopTestMaxLengthOne']],
    ['explorerSqlStopped', ['explorerSqlStoppedOne']],
    ['explorerSqlStoppedUndone', ['explorerSqlStoppedUndoneOne']],
    ['agentDefinitionTestTimeout', ['agentDefinitionTestTimeoutOne']],
    ['agentDefinitionTestTimeoutLocal', ['agentDefinitionTestTimeoutLocalOne']],
  ];
  for (const [plural, singulars] of pairs) {
    assert.equal(typeof STRINGS[plural], 'string', `${plural} exists`);
    for (const singular of singulars) {
      assert.equal(typeof STRINGS[singular], 'string', `${singular} exists beside ${plural}`);
      assert.notEqual(STRINGS[singular], STRINGS[plural], `${singular} differs from ${plural}`);
    }
  }
});

// --- The scan ---------------------------------------------------------------------------------

/** An operand a reversed comparison names: a name, a member path, or a call with no arguments. */
const OPERAND = String.raw`[\w$.]+(?:\(\))?`;

/** A comparison of a count against 1 that makes the pair "one" and "not one", either way round. */
const AGAINST_ONE = String.raw`(?:===?|!==?)\s*1\b|(?:>|<=)\s*1\b|(?:>=|<)\s*2\b|\b1\s*(?:===?|!==?|<|>=)\s*${OPERAND}|\b2\s*(?:>|<=)\s*${OPERAND}`;

/** An `if` condition's text, which may hold calls and other parenthesized parts one level deep. */
const CONDITION = String.raw`(?:[^()]|\([^()]*\))*?`;

/** What a branch carries when it names a published sentence or a phrase's singular. */
const NAMES_A_SENTENCE = /STRINGS\.|\.one\b|One\b/;

/**
 * The places in `text` that choose between a singular and a plural sentence inline: a ternary or an
 * `if` whose condition compares a count against 1 and whose branch names a sentence. Answers each as
 * `{ line, excerpt }`, the excerpt being the source line the comparison sits on.
 */
export function inlineChoices(text) {
  const found = [];
  const patterns = [
    new RegExp(String.raw`(?:${AGAINST_ONE})\s*\)?\s*\?([^;]*)`, 'g'),
    new RegExp(String.raw`\bif\s*\(${CONDITION}(?:${AGAINST_ONE})${CONDITION}\)\s*(?:return\b)?([^;]*)`, 'g'),
  ];
  for (const pattern of patterns) {
    for (const match of text.matchAll(pattern)) {
      if (!NAMES_A_SENTENCE.test(match[1])) continue;
      const line = text.slice(0, match.index).split('\n').length;
      found.push({ line, excerpt: text.split('\n')[line - 1].trim() });
    }
  }
  return found;
}

/** A singular count key: `<plural>One`, or a two-count sentence's `OneFirst`, `OneSecond` or `OneBoth`. */
const SINGULAR_KEY = /\bSTRINGS\.\w+One(?:First|Second|Both)?\b/g;

/** The name of the call whose open argument list holds `index`, or `''` when the innermost open bracket is not a call's. */
function enclosingCall(text, index) {
  let depth = 0;
  for (let at = index - 1; at >= 0; at -= 1) {
    const char = text[at];
    if (char === ')' || char === ']' || char === '}') depth += 1;
    else if (char === '(' || char === '[' || char === '{') {
      if (depth === 0) return char === '(' ? (/[\w$]+(?=\s*$)/.exec(text.slice(Math.max(0, at - 80), at))?.[0] ?? '') : '';
      depth -= 1;
    }
  }
  return '';
}

/**
 * The places in `text` that name a singular count key other than as an argument of `pickCount` or as
 * the `one` entry of a phrase table: a singular reached any other way is chosen by something other
 * than the rule. Answers each as `{ line, excerpt }`.
 */
export function singularsOutsideTheRule(text) {
  const found = [];
  for (const match of text.matchAll(SINGULAR_KEY)) {
    if (enclosingCall(text, match.index) === 'pickCount') continue;
    if (/\bone\s*:\s*$/.test(text.slice(Math.max(0, match.index - 40), match.index))) continue;
    const line = text.slice(0, match.index).split('\n').length;
    found.push({ line, excerpt: text.split('\n')[line - 1].trim() });
  }
  return found;
}

/**
 * Where a comparison against 1 is not a count's singular. Each entry names the file, and the text a
 * choice there must contain to be excused.
 */
const EXCUSED = [
  // A schedule's "every N" wording is chosen where the cadence is built.
  { file: 'areas/tasks/details.store.ts', contains: null },
  // A boolean flag a vendor answers as 1.
  { file: 'areas/security/ssl-form.page.ts', contains: 'value === true || value === 1' },
];

const OWN_FILE = 'core/count-phrase.ts';

function applicationSources(dir) {
  const files = [];
  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) files.push(...applicationSources(path));
    else if (entry.name.endsWith('.ts') && !entry.name.endsWith('.spec.ts')) files.push(path);
  }
  return files;
}

test('the scan recognizes an inline count choice, in a ternary and in an if, and passes the rule itself', () => {
  assert.equal(inlineChoices('const t = count === 1 ? STRINGS.a : STRINGS.b;').length, 1, 'a ternary between two sentences');
  assert.equal(inlineChoices('const t = n !== 1 ? STRINGS.many : STRINGS.one;').length, 1, 'the negated form');
  assert.equal(inlineChoices('const t = part.count === 1 ? phrases.one : phrases.many;').length, 1, 'a phrase table');
  assert.equal(inlineChoices('if (count === 1) return STRINGS.formTabErrorOne;').length, 1, 'an if that returns a sentence');
  assert.equal(inlineChoices('const t = every > 1 ? STRINGS.everyN : STRINGS.every;').length, 1, 'a greater-than-one form');
  assert.deepEqual(inlineChoices('const t = kept.length === 1 ? kept[0] : JSON.stringify(kept);'), [], 'a choice of values is not one of sentences');
  assert.deepEqual(inlineChoices('const t = pickCount(count, STRINGS.a, STRINGS.b);'), [], 'the shared rule');
  assert.equal(inlineChoices('const t = (count === 1) ? STRINGS.a : STRINGS.b;').length, 1, 'a parenthesized condition');
  assert.equal(inlineChoices('const t = 1 === count ? STRINGS.a : STRINGS.b;').length, 1, 'a reversed comparison');
  assert.equal(inlineChoices('if (this.names().length === 1) return STRINGS.a;').length, 1, 'an if whose condition holds a call');
});

test('the singular-key scan passes pickCount and a phrase table, and finds a singular reached any other way', () => {
  assert.deepEqual(singularsOutsideTheRule('const t = pickCount(n, STRINGS.aOne, STRINGS.a);'), [], 'the shared rule');
  assert.deepEqual(singularsOutsideTheRule('const t = fill(pickCount(n, STRINGS.aOneFirst, STRINGS.a), { n });'), [], 'the rule inside a fill');
  assert.deepEqual(singularsOutsideTheRule('const p = { one: STRINGS.aOne, many: STRINGS.a };'), [], 'a phrase table pickCount reads');
  assert.equal(singularsOutsideTheRule('const t = pick(n, STRINGS.aOne, STRINGS.a);').length, 1, 'a private chooser');
  assert.equal(singularsOutsideTheRule('if (this.count() === 1) return STRINGS.aOne;').length, 1, 'a condition holding a call');
  assert.equal(singularsOutsideTheRule('const t = n === 1 ? STRINGS.aOneBoth : STRINGS.a;').length, 1, 'a ternary');
});

test('no module but count-phrase.ts chooses a count sentence inline', () => {
  const files = applicationSources(appRoot);
  assert.ok(files.length > 200, `the scan reads the application source, found ${files.length} file(s)`);
  assert.ok(files.some((path) => relative(appRoot, path) === OWN_FILE), 'and includes the module that owns the rule');
  const offending = [];
  for (const path of files) {
    const name = relative(appRoot, path);
    if (name === OWN_FILE) continue;
    const text = readFileSync(path, 'utf8');
    for (const choice of inlineChoices(text)) {
      const excused = EXCUSED.some((entry) => entry.file === name && (entry.contains === null || choice.excerpt.includes(entry.contains)));
      if (!excused) offending.push(`${name}:${choice.line}: ${choice.excerpt}`);
    }
  }
  assert.deepEqual(offending, [], `these choose a singular without core/count-phrase.ts:\n${offending.join('\n')}`);
});

test('no module but count-phrase.ts reaches a singular count key other than through pickCount', () => {
  const offending = [];
  for (const path of applicationSources(appRoot)) {
    const name = relative(appRoot, path);
    if (name === OWN_FILE) continue;
    for (const found of singularsOutsideTheRule(readFileSync(path, 'utf8'))) offending.push(`${name}:${found.line}: ${found.excerpt}`);
  }
  assert.deepEqual(offending, [], `these reach a singular without core/count-phrase.ts:\n${offending.join('\n')}`);
});

test('every excused file still holds the comparison that excuses it', () => {
  for (const entry of EXCUSED) {
    const text = readFileSync(join(appRoot, entry.file), 'utf8');
    const kept = inlineChoices(text).filter((choice) => entry.contains === null || choice.excerpt.includes(entry.contains));
    assert.ok(kept.length > 0, `${entry.file} still holds the choice its excuse names, so the excuse is not stale`);
  }
});

// --- The tests' own expectations ---------------------------------------------------------------

/** The nouns a count sentence in this application counts. */
const COUNT_NOUNS = 'rows|lines|documents|items|screens|actions|fields|bytes|characters|days|turns|mappings|calls|errors';

/**
 * The places in `text` that expect a digit pattern followed by a count noun in the plural alone,
 * such as `\d+ rows returned` or `[\d,]+\s+rows`: a count of 1 reads the singular, so the pattern
 * fails at 1. A noun followed by `?` (`\d+ rows?`) is a pattern that reads the number and leaves the
 * noun to another assertion. Answers each as `{ line, excerpt }`.
 */
export function pluralOnlyPatterns(text) {
  const found = [];
  const pattern = new RegExp(String.raw`(?:\\d|\[\\d,?\])(?:[+*]|\{\d+(?:,\d*)?\})?\)?(?:[ ]+|\\s[+*]?)(?:${COUNT_NOUNS})(?!\?)\b`, 'g');
  for (const match of text.matchAll(pattern)) {
    const line = text.slice(0, match.index).split('\n').length;
    found.push({ line, excerpt: text.split('\n')[line - 1].trim() });
  }
  return found;
}

/** The plural count keys that have a singular, so a sentence filled with 1 names the singular instead. */
const PLURALS_WITH_A_SINGULAR = new Set([
  'tableRowCount',
  ...Object.keys(STRINGS).flatMap((key) => {
    const plural = key.replace(/One(?:First|Second|Both)?$/, '');
    return plural !== key && typeof STRINGS[plural] === 'string' ? [plural] : [];
  }),
]);

/** A count placeholder filled with the literal 1, by `replace` or by `split` and `join`. */
const FILLED_WITH_ONE = new RegExp(
  String.raw`\.replace\(\s*(['"])<(?:n|count|rows|s)>\1\s*,\s*(['"])1\2\s*\)|\.split\(\s*(['"])<(?:n|count|rows|s)>\3\s*\)\.join\(\s*(['"])1\4\s*\)`
);

/**
 * The places in `text` that fill a plural count sentence that has a singular with the literal 1 -- by
 * `replace`, by `split` and `join`, or as a formatter's count argument -- which expects a sentence the
 * client never renders. Answers each as `{ line, excerpt }`.
 */
export function pluralsFilledWithOne(text) {
  const found = [];
  const pattern = /STRINGS\.(\w+)((?:\.(?:replace|split|join)\([^()]*\))*)|\b(?:formatRowCount|formatCapNotice|formatRemovalResidue|formatCount)\(\s*STRINGS\.(\w+)\s*,\s*1\s*\)/g;
  for (const match of text.matchAll(pattern)) {
    const key = match[1] ?? match[3];
    const filledWithOne = match[3] !== undefined || FILLED_WITH_ONE.test(match[2] ?? '');
    if (!filledWithOne || !PLURALS_WITH_A_SINGULAR.has(key)) continue;
    const line = text.slice(0, match.index).split('\n').length;
    found.push({ line, excerpt: text.split('\n')[line - 1].trim() });
  }
  return found;
}

function testSources(dir, suffix) {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) return testSources(path, suffix);
    return entry.name.endsWith(suffix) ? [path] : [];
  });
}

test('the test scan recognizes a digit pattern with a plural noun alone, and passes one that reads the noun separately', () => {
  assert.equal(pluralOnlyPatterns(String.raw`assert.match(s, /^\d+ lines removed/);`).length, 1, 'a plural alone');
  assert.equal(pluralOnlyPatterns(String.raw`assert.match(s, /^\d+ rows returned \u00b7 \d+ sent$/);`).length, 1, 'a phrase around it');
  assert.equal(pluralOnlyPatterns(String.raw`const m = /(\d+) documents\b/.exec(t);`).length, 1, 'a captured count');
  assert.deepEqual(pluralOnlyPatterns(String.raw`const m = /(\d+) rows?\b/.exec(t);`), [], 'a noun that may be either');
  assert.deepEqual(pluralOnlyPatterns(String.raw`const m = /^(\d+) (rows?) returned/.exec(t);`), [], 'a noun read as its own group');
  assert.deepEqual(pluralOnlyPatterns('const t = `${n} rows`;'), [], 'text that is not a digit pattern');
  assert.equal(pluralOnlyPatterns(String.raw`assert.match(s, /^[\d,]+\s+rows$/);`).length, 1, 'a grouped count and a whitespace class');
  assert.equal(pluralOnlyPatterns(String.raw`assert.match(s, /^\d+ calls were counted/);`).length, 1, 'another counted noun');
});

test('the fill scan finds a plural that has a singular filled with 1, and passes any other fill', () => {
  assert.equal(pluralsFilledWithOne(`const t = STRINGS.explorerImportDone.replace('<n>', '1');`).length, 1, 'a replace');
  assert.equal(pluralsFilledWithOne(`const t = STRINGS.agentTurnLimitBanner.split('<n>').join('1');`).length, 1, 'a split and join');
  assert.equal(pluralsFilledWithOne('const t = formatRowCount(STRINGS.tableRowCount, 1);').length, 1, 'a formatter');
  assert.deepEqual(pluralsFilledWithOne(`const t = STRINGS.explorerImportDone.replace('<n>', '2');`), [], 'another count');
  assert.deepEqual(pluralsFilledWithOne(`const t = STRINGS.explorerCompileSummary.replace('<done>', '1').replace('<n>', '2');`), [], 'a count the sentence does not choose on');
  assert.deepEqual(pluralsFilledWithOne(`const t = STRINGS.explorerSqlCode.replace('<code>', '1');`), [], 'a sentence with no singular');
});

/** Every browser spec, tools test and component spec but this file. */
function testFiles() {
  const own = join(uiRoot, 'tools', 'count-phrase.test.mjs');
  return [
    ...testSources(join(uiRoot, 'browser'), '.mjs'),
    ...testSources(join(uiRoot, 'tools'), '.test.mjs'),
    ...testSources(appRoot, '.spec.ts'),
  ].filter((path) => path !== own);
}

test('no browser spec, tools test or component spec expects a count in the plural alone', () => {
  const files = testFiles();
  assert.ok(files.length > 300, `the scan reads the tests, found ${files.length} file(s)`);
  assert.ok(files.some((path) => path.endsWith('system-explorer-find.browser-spec.mjs')), 'and includes the Compare browser spec');
  const offending = [];
  for (const path of files) {
    for (const found of pluralOnlyPatterns(readFileSync(path, 'utf8'))) {
      offending.push(`${relative(uiRoot, path)}:${found.line}: ${found.excerpt}`);
    }
  }
  assert.deepEqual(offending, [], `these expect a plural a count of 1 does not read; derive the noun from the count:\n${offending.join('\n')}`);
});

test('no browser spec, tools test or component spec fills a plural that has a singular with 1', () => {
  const files = testFiles();
  assert.ok(files.length > 300, `the scan reads the tests, found ${files.length} file(s)`);
  const offending = [];
  for (const path of files) {
    for (const found of pluralsFilledWithOne(readFileSync(path, 'utf8'))) {
      offending.push(`${relative(uiRoot, path)}:${found.line}: ${found.excerpt}`);
    }
  }
  assert.deepEqual(offending, [], `these expect a plural the client never renders at 1; expect its singular:\n${offending.join('\n')}`);
});
