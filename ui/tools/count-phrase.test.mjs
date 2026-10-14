// Pins the one rule that chooses a count sentence's singular (`core/count-phrase.ts`): a count of
// exactly 1 reads the singular, 0 and 2 or more read the plural, and no other module makes that
// choice. The scan below reads the application source, so a count sentence chosen inline again fails
// here and names the file and line.
//
// Mutations (Rule 19):
// - `=== 1` becomes `<= 1` in `pickCount` -> the 0 case goes red.
// - `rowCountPhrase` formats `STRINGS.tableRowCount` alone -> the 1 case goes red.
// - choose `part.count === 1 ? phrases.one : ...` inline in `core/impact.ts` -> the scan goes red.

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

/** A comparison of a count against 1 that makes the pair "one" and "not one". */
const AGAINST_ONE = String.raw`(?:===?|!==?)\s*1\b|(?:>|<=)\s*1\b|(?:>=|<)\s*2\b`;

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
    new RegExp(String.raw`(?:${AGAINST_ONE})\s*\?([^;]*)`, 'g'),
    new RegExp(String.raw`\bif\s*\([^)]*(?:${AGAINST_ONE})[^)]*\)\s*(?:return\b)?([^;]*)`, 'g'),
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

test('every excused file still holds the comparison that excuses it', () => {
  for (const entry of EXCUSED) {
    const text = readFileSync(join(appRoot, entry.file), 'utf8');
    const kept = inlineChoices(text).filter((choice) => entry.contains === null || choice.excerpt.includes(entry.contains));
    assert.ok(kept.length > 0, `${entry.file} still holds the choice its excuse names, so the excuse is not stale`);
  }
});
