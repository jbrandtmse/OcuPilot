/**
 * Story 21.19's resource transfer sentences, held to the one published copy (AD-29, AD-39).
 *
 * Each `REASON*` parameter of `OcuPilot.Api.ResourceFileError` is one published sentence on three surfaces: the server sends it, the client's strings table
 * holds it, and EXPERIENCE.md's Fixed strings publish it. The import tool names a consequence code the proposal card maps to the import's sentence, and the
 * two dialogs' own sentences are published beside them.
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const FILE_ERROR = join(REPO_ROOT, 'src', 'OcuPilot', 'Api', 'ResourceFileError.cls');

const IMPORT_TOOL = join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool', 'ResourceImport.cls');

const STRINGS_SOURCE = join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'strings.ts');

const PROPOSAL_VIEW = join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'proposal-view.ts');

const EXPERIENCE = join(REPO_ROOT, '_bmad-output', 'planning-artifacts', 'ux-designs', 'ux-OcuPilot-2026-09-08', 'EXPERIENCE.md');

/** Every sentence `ResourceFileError` declares, and the `strings.ts` key it is pinned equal to. */
const SENTENCES = [
  ['REASONSHAPE', 'resourceFileRefusalShape'],
  ['REASONCHANGED', 'resourceFileRefusalChanged'],
  ['REASONTOOLARGE', 'resourceFileRefusalTooLarge'],
  ['REASONIMPORT', 'resourceImportConsequence'],
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

// Mutation (Rule 19): change one word of REASONCHANGED in ResourceFileError.cls, or of `resourceFileRefusalChanged` in strings.ts -> this goes red naming both.
test('Story 21.19: each resource file sentence is one published sentence on the server, the strings table and Fixed strings', () => {
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [parameter, key] of SENTENCES) {
    const server = classParameter(FILE_ERROR, parameter);
    assert.equal(server, stringValue(key), `${parameter} and ${key} are one published sentence`);
    assert.ok(experience.includes(`"${server}"`), `${parameter}'s sentence is published in EXPERIENCE.md's Fixed strings`);
    assert.ok(!server.toLowerCase().includes('agent'), `${parameter} names no caller: ${server}`);
  }
});

test('Story 21.19: ResourceFileError declares no sentence this test does not pin', () => {
  const declared = [...readFileSync(FILE_ERROR, 'utf8').matchAll(/^Parameter (REASON\w+)/gm)].map((match) => match[1]).sort();
  assert.deepEqual(declared, SENTENCES.map(([parameter]) => parameter).sort());
});

// Mutation (Rule 19): drop the import's line from `consequenceSentence`, or change the import tool's CONSEQUENCECODE -> this goes red.
test('Story 21.19: the import card states the sentence its consequence code names', () => {
  const proposalView = readFileSync(PROPOSAL_VIEW, 'utf8');
  assert.equal(classParameter(FILE_ERROR, 'IMPORT'), 'RESOURCEFILE.IMPORT');
  assert.equal(classParameter(IMPORT_TOOL, 'CONSEQUENCECODE'), 'RESOURCEFILE.IMPORT');
  assert.ok(proposalView.includes("CONSEQUENCE_RESOURCEFILEIMPORT = 'RESOURCEFILE.IMPORT'"), 'proposal-view.ts holds the code');
  assert.ok(proposalView.includes('if (code === CONSEQUENCE_RESOURCEFILEIMPORT) return STRINGS.resourceImportConsequence;'), 'the code maps to the import sentence');
});

// Mutation (Rule 19): change one word of the import dialog's sentence in strings.ts -> this goes red.
test('Story 21.19: the transfer dialogs and lines state the ruled sentences', () => {
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [key, sentence] of [
    ['resourceExportAllAction', 'Export all'],
    ['resourceExportTitle', 'Export resources'],
    ['resourceImportTitle', 'Import resources'],
    ['resourceImportReplaces', 'Importing replaces any existing resource with the same name.'],
    ['resourceImportDone', 'Resources imported: <count>.'],
    ['resourceExportDone', 'Resources exported to <path>: <count>.'],
  ]) {
    assert.equal(stringValue(key), sentence, `${key} is the ruled sentence`);
    assert.ok(experience.includes(`"${sentence}"`), `${key}'s sentence is published in EXPERIENCE.md's Fixed strings`);
  }
});
