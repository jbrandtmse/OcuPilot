/**
 * Stories 21.3, 21.4 and 21.13's setting sentences, held to the one published copy (AD-29, AD-39).
 *
 * Each `REASON*` and `ACCEPTS*` parameter of `OcuPilot.Api.ConfigError` is one published sentence on three surfaces: the server sends it, the
 * client's strings table holds it, and EXPERIENCE.md's Fixed strings publish it. The restart consequence is the reused
 * `encryptionStartupRestart`, which the abstract set tool names by code.
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const ERROR = join(REPO_ROOT, 'src', 'OcuPilot', 'Api', 'ConfigError.cls');

const STRINGS_SOURCE = join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'strings.ts');

const EXPERIENCE = join(REPO_ROOT, '_bmad-output', 'planning-artifacts', 'ux-designs', 'ux-OcuPilot-2026-09-08', 'EXPERIENCE.md');

/** Every sentence `ConfigError` declares, and the `strings.ts` key it is pinned equal to. */
const SENTENCES = [
  ['REASONSETTINGNOTFOUND', 'configRefusalNotFound'],
  ['REASONSETTINGREADONLY', 'configRefusalReadOnly'],
  ['REASONSETTINGVALUE', 'configRefusalValue'],
  ['REASONSETTINGSUBSTITUTION', 'configRefusalSubstitution'],
  ['REASONSETTINGRESTART', 'encryptionStartupRestart'],
  ['REASONSETTINGPURGE', 'configSettingPurge'],
  ['ACCEPTSBOOLEAN', 'configAcceptsBoolean'],
  ['ACCEPTSRANGE', 'configAcceptsRange'],
  ['ACCEPTSMINIMUM', 'configAcceptsMinimum'],
  ['ACCEPTSCHOICE', 'configAcceptsChoice'],
  ['ACCEPTSTEXT', 'configAcceptsText'],
  ['ACCEPTSBLOCKSIZES', 'configAcceptsBlockSizes'],
  ['ACCEPTSREADONLY', 'configAcceptsReadOnly'],
  ['ACCEPTSDATATYPE', 'configAcceptsDatatype'],
  ['REASONMAPPINGTAKEN', 'configMappingTaken'],
  ['REASONMAPPINGNAME', 'configMappingName'],
  ['REASONMAPPINGDELETE', 'configMappingDelete'],
  ['REASONNLSRELOAD', 'nlsDefaultReloadConsequence'],
];

function stringValue(key) {
  const source = readFileSync(STRINGS_SOURCE, 'utf8');
  const match = new RegExp(`\\b${key}:\\s*\\n?\\s*'((?:[^'\\\\]|\\\\.)*)'`).exec(source);
  assert.notEqual(match, null, `strings.ts carries ${key}`);
  return match[1].replace(/\\'/g, "'").replace(/\\\\/g, '\\');
}

function classParameter(file, parameter) {
  const match = new RegExp(`^Parameter ${parameter}(?: As \\w+)? = "([^"]*)";`, 'm').exec(readFileSync(file, 'utf8'));
  assert.notEqual(match, null, `${file} declares ${parameter}`);
  return match[1];
}

// Mutation (Rule 19): change one word of REASONSETTINGREADONLY in ConfigError.cls -> this goes red naming both.
test('Stories 21.3 and 21.13: each setting sentence is one published sentence on the server, the strings table and Fixed strings', () => {
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [parameter, key] of SENTENCES) {
    const server = classParameter(ERROR, parameter);
    assert.equal(server, stringValue(key), `${parameter} and ${key} are one published sentence`);
    assert.ok(experience.includes(`"${server}"`), `${parameter}'s sentence is published in EXPERIENCE.md's Fixed strings`);
    assert.ok(!server.toLowerCase().includes('agent'), `${parameter} names no caller: ${server}`);
  }
});

// Mutation (Rule 19): drop one `ACCEPTS*` parameter from ConfigError.cls -> this goes red naming it.
test('Story 21.3: ConfigError declares no sentence this test does not pin', () => {
  const declared = [...readFileSync(ERROR, 'utf8').matchAll(/^Parameter ((?:REASON|ACCEPTS)\w+)/gm)].map((match) => match[1]).sort();
  assert.deepEqual(declared, SENTENCES.map(([parameter]) => parameter).sort());
});
