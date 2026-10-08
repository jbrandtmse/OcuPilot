/**
 * Story 20.15's Screen permissions sentences, held to the instance's own source (AD-39, AD-64).
 *
 * Each `OcuPilot.Api.AccessError` sentence is one published string on both surfaces: the server sends it,
 * the client draws it, and EXPERIENCE.md's Fixed strings publish it. The port's bound on a set,
 * `OcuPilot.Api.AccessError.MAXPAIRS`, is the source of the number the "at most" sentence states.
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const ERROR = join(REPO_ROOT, 'src', 'OcuPilot', 'Api', 'AccessError.cls');

const STRINGS_SOURCE = join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'strings.ts');

const EXPERIENCE = join(REPO_ROOT, '_bmad-output', 'planning-artifacts', 'ux-designs', 'ux-OcuPilot-2026-09-08', 'EXPERIENCE.md');

/** Every `<parameter>` sentence `AccessError` declares, and the `strings.ts` key it is pinned equal to. */
const SENTENCES = [
  ['REASONSCREENUNKNOWN', 'accessRefusalScreenUnknown'],
  ['REASONNOTADJUSTED', 'accessRefusalNotAdjusted'],
  ['REASONPAIRSEMPTY', 'accessRefusalPairsEmpty'],
  ['REASONRESOURCEUNKNOWN', 'accessRefusalResourceUnknown'],
  ['REASONPAIRMALFORMED', 'accessRefusalPairMalformed'],
  ['REASONPAIRABSENT', 'accessRefusalPairAbsent'],
  ['REASONPAIRPRESENT', 'accessRefusalPairPresent'],
  ['REASONPAIRSTOOMANY', 'accessRefusalPairsTooMany'],
];

/** The value `key` holds in `strings.ts`, which may sit on the line after its key. */
function stringValue(key) {
  const source = readFileSync(STRINGS_SOURCE, 'utf8');
  const match = new RegExp(`\\b${key}:\\s*\\n?\\s*'((?:[^'\\\\]|\\\\.)*)'`).exec(source);
  assert.notEqual(match, null, `strings.ts carries ${key}`);
  return match[1].replace(/\\'/g, "'").replace(/\\\\/g, '\\');
}

/** The sentence `parameter` holds in `AccessError.cls`. */
function serverSentence(parameter) {
  const match = new RegExp(`Parameter ${parameter} = "([^"]+)";`).exec(readFileSync(ERROR, 'utf8'));
  assert.notEqual(match, null, `AccessError.cls declares ${parameter}`);
  return match[1];
}

test('Story 20.15: each Screen permissions refusal is one sentence on both surfaces, published in Fixed strings', () => {
  // Mutation (Rule 19): change one word of REASONPAIRPRESENT in AccessError.cls -> this goes red naming both.
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [parameter, key] of SENTENCES) {
    const server = serverSentence(parameter);
    assert.equal(server, stringValue(key), `${parameter} and ${key} are one published sentence`);
    assert.ok(experience.includes(`"${server}"`), `${parameter}'s sentence is published in EXPERIENCE.md's Fixed strings`);
    assert.ok(!server.toLowerCase().includes('agent'), `${parameter} names no caller: ${server}`);
  }
});

test("Story 20.15: the set bound the 'at most' sentence states is AccessError's MAXPAIRS", () => {
  // Mutation (Rule 19): change MAXPAIRS in AccessError.cls to 9 -> this goes red.
  const match = /Parameter MAXPAIRS = (\d+);/.exec(readFileSync(ERROR, 'utf8'));
  assert.notEqual(match, null, 'AccessError.cls declares MAXPAIRS');
  assert.ok(stringValue('accessRefusalPairsTooMany').includes(`at most ${match[1]} permissions`), 'the sentence states the bound');
});
