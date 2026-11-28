/**
 * Story 21.36's task output refusals, held to the one published copy (AD-12, AD-21).
 *
 * Each `REASON*` parameter of `OcuPilot.Api.TaskError` is one published sentence on three surfaces: the server
 * sends it, the client's strings table holds it, and EXPERIENCE.md's Fixed strings publish it.
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const ERROR = join(REPO_ROOT, 'src', 'OcuPilot', 'Api', 'TaskError.cls');

const STRINGS_SOURCE = join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'strings.ts');

const EXPERIENCE = join(REPO_ROOT, '_bmad-output', 'planning-artifacts', 'ux-designs', 'ux-OcuPilot-2026-09-08', 'EXPERIENCE.md');

/** Every sentence `TaskError` declares, and the `strings.ts` key it is pinned equal to. */
const SENTENCES = [
  ['REASONNONE', 'taskOutputNone'],
  ['REASONELSEWHERE', 'taskOutputElsewhere'],
  ['REASONABSENT', 'taskOutputAbsent'],
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

// Mutation (Rule 19): change one word of REASONELSEWHERE in TaskError.cls -> this goes red naming both.
test('Story 21.36: each task output refusal is one published sentence on the server, the strings table and Fixed strings', () => {
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [parameter, key] of SENTENCES) {
    const server = classParameter(ERROR, parameter);
    assert.equal(server, stringValue(key), `${parameter} and ${key} are one published sentence`);
    assert.ok(experience.includes(`"${server}"`), `${parameter}'s sentence is published in EXPERIENCE.md's Fixed strings`);
    assert.ok(!server.toLowerCase().includes('agent'), `${parameter} names no caller: ${server}`);
  }
});

// Mutation (Rule 19): drop one `REASON*` parameter from TaskError.cls -> this goes red naming it.
test('Story 21.36: TaskError declares no sentence this test does not pin', () => {
  const declared = [...readFileSync(ERROR, 'utf8').matchAll(/^Parameter (REASON\w+)/gm)].map((match) => match[1]).sort();
  assert.deepEqual(declared, SENTENCES.map(([parameter]) => parameter).sort());
});
