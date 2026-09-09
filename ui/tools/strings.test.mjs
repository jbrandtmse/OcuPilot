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
 * table (lines 250-302: a two-line header at 250-251, then 51 data rows) by
 * extracting every double-quoted span in the table's *String* column --
 * exactly the rule the story itself states: "\u00b7 (a middle dot) also occurs inside
 * strings, so only the double quotes disambiguate."
 */
function extractFixedStringsTable(markdown) {
  const lines = markdown.split('\n');
  const literals = [];
  for (let lineNo = 252; lineNo <= 302; lineNo++) {
    const line = lines[lineNo - 1] ?? '';
    const columns = line.split('|');
    if (columns.length < 3) continue; // not a table row
    const stringColumn = columns[1];
    for (const m of stringColumn.matchAll(/"([^"]*)"/g)) {
      literals.push(m[1]);
    }
  }
  return literals;
}

const expectedLiterals = extractFixedStringsTable(experienceMdRaw);

test("EXPERIENCE.md's Fixed strings table (lines 250-302) itself has 51 data rows and roughly 100 distinct literals -- a sanity check on the extractor before trusting it", () => {
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
// sets differ by exactly the three literals the AC requires alongside the table.
const REQUIRED_ALONGSIDE_TABLE = ['done \u00b7 audit not marked', 'running', 'OcuPilot'];

test('the string source holds nothing the documents do not authorize -- the table plus exactly three named extras', () => {
  const authorized = new Set([...expectedLiterals, ...REQUIRED_ALONGSIDE_TABLE]);
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
    expectedLiterals.length + REQUIRED_ALONGSIDE_TABLE.length,
    `expected ${expectedLiterals.length} table literals + ${REQUIRED_ALONGSIDE_TABLE.length} named extras, found ${Object.keys(stringsValues).length} keys`
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
