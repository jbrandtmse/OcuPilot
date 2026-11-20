// Pins the Security advisor's published words: every area name and every recommendation
// sentence `AdvisorPort` holds is a literal of EXPERIENCE.md's Fixed strings table and a value
// in the string source, the rosters have the sizes the vendor's pane implies, and, where the
// vendor's source is on disk, the sentence codes are the pane's own minus the list's second
// line.
//
// Mutation (Rule 19): change one sentence in AdvisorPort.cls's ADVISORTEXTS -> the literal and
// the string-source tests go red naming it; remove one code -> the size and vendor tests go red.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { loadStrings } from './strings.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..', '..');
const portPath = join(root, 'src', 'OcuPilot', 'Port', 'AdvisorPort.cls');
const experiencePath = join(
  root,
  '_bmad-output',
  'planning-artifacts',
  'ux-designs',
  'ux-OcuPilot-2026-09-08',
  'EXPERIENCE.md'
);
const vendorPath = join(root, 'irissys', '%CSP', 'UI', 'System', 'SecurityAdvisorPane.cls');

const AREA_COUNT = 7;
const SENTENCE_COUNT = 39;
const VENDOR_SECOND_LINE = 'PUBLICRolesList1';
/**
 * The one code whose string key does not spell it: a key naming a namespace is held by `strings.test.mjs`'s own roster of such keys,
 * so this sentence's key avoids the word.
 */
const STRING_KEY_OF = { UserNoNamespace: 'UserNoDefault' };

/** A `Parameter NAME = "a=b|c=d";` as ordered `[key, text]` pairs, split on the first `=`. */
function roster(source, name) {
  const match = source.match(new RegExp(`^Parameter ${name} = "([^"]*)";`, 'm'));
  assert.ok(match, `AdvisorPort.cls must carry Parameter ${name}`);
  return match[1].split('|').map((entry) => {
    const at = entry.indexOf('=');
    assert.ok(at > 0, `${name} entry '${entry}' must be Key=Text`);
    return [entry.slice(0, at), entry.slice(at + 1)];
  });
}

/** Every double-quoted literal of the Fixed strings table's String column. */
function fixedLiterals(markdown) {
  const lines = markdown.split('\n');
  const anchor = lines.findIndex((line) => line.startsWith('**Fixed strings**'));
  const header = lines.findIndex((line, i) => i > anchor && line.trim() === '| String | Where |');
  assert.ok(anchor >= 0 && header > anchor, 'EXPERIENCE.md must carry the Fixed strings table');
  const literals = new Set();
  for (let i = header + 2; i < lines.length && lines[i].startsWith('|'); i++) {
    for (const m of lines[i].split('|')[1].matchAll(/"([^"]*)"/g)) literals.add(m[1]);
  }
  return literals;
}

const port = readFileSync(portPath, 'utf8');
const areas = roster(port, 'ADVISORAREAS');
const texts = roster(port, 'ADVISORTEXTS');
const literals = fixedLiterals(readFileSync(experiencePath, 'utf8'));
const strings = loadStrings();
const stringValues = new Set(Object.values(strings));

test('the area roster holds seven names and the sentence roster thirty-nine, each once', () => {
  assert.equal(areas.length, AREA_COUNT, 'ADVISORAREAS size');
  assert.equal(texts.length, SENTENCE_COUNT, 'ADVISORTEXTS size');
  assert.equal(new Set(areas.map(([k]) => k)).size, AREA_COUNT, 'area keys are distinct');
  assert.equal(new Set(texts.map(([k]) => k)).size, SENTENCE_COUNT, 'sentence codes are distinct');
});

test('every area name and every sentence is an EXPERIENCE.md literal', () => {
  const missing = [...areas, ...texts].filter(([, text]) => !literals.has(text)).map(([key, text]) => `${key}: ${text}`);
  assert.deepEqual(missing, [], 'port words that are not Fixed strings literals');
});

test('every sentence is the string source value under its own code, and every area name is a value', () => {
  const wrongKey = texts
    .filter(([code, text]) => strings[`securityAdvisorText${STRING_KEY_OF[code] ?? code}`] !== text)
    .map(([code, text]) => `${code}: ${text}`);
  assert.deepEqual(wrongKey, [], 'sentences that securityAdvisorText<Code> does not hold');
  const unknownArea = areas.filter(([, text]) => !stringValues.has(text)).map(([key, text]) => `${key}: ${text}`);
  assert.deepEqual(unknownArea, [], 'area names missing from the string source');
});

test('the screen\'s empty state reads its title and the agent\'s invitation, both published', () => {
  const generated = readFileSync(join(here, '..', 'src', 'app', 'core', 'screens.generated.ts'), 'utf8');
  const start = generated.indexOf('"route": "security/advisor"');
  assert.ok(start >= 0, 'the generated mirror carries the Security advisor');
  const block = generated.slice(start, start + 8000);
  const titleKey = block.match(/"emptyStateKey": "(\w+)"/)?.[1];
  const agentKey = block.match(/"emptyAgentKey": "(\w+)"/)?.[1];
  assert.equal(titleKey, 'securityAdvisorEmpty', 'the empty state\'s title key');
  assert.equal(agentKey, 'securityAdvisorEmptyAgent', 'the agent phrase key');
  assert.ok(literals.has(strings[titleKey]), 'the title is an EXPERIENCE.md literal');
  assert.ok(literals.has(strings[agentKey]), 'the agent phrase is an EXPERIENCE.md literal');
  const line = strings.tableWriteCapableEmptyState.split('<a write it could propose here>').join(strings[agentKey]);
  assert.equal(line, 'Or ask the agent: ignore or stop ignoring a recommendation.', 'the second line the empty state draws');
});

test('the sentence codes are the vendor pane\'s TextMsg codes without the list\'s second line', (t) => {
  if (!existsSync(vendorPath)) {
    t.skip('irissys/ is not on disk (gitignored reference export)');
    return;
  }
  const vendor = readFileSync(vendorPath, 'utf8');
  const codes = [...vendor.matchAll(/TextMsg\("([A-Za-z0-9]+)"\s*\)\s*=/g)].map((m) => m[1]);
  const expected = [...new Set(codes)].filter((code) => code !== VENDOR_SECOND_LINE);
  assert.equal(expected.length, SENTENCE_COUNT, 'the vendor pane defines thirty-nine sentence codes besides the list line');
  assert.deepEqual(texts.map(([code]) => code), expected, 'port codes, in the pane\'s order');
});
