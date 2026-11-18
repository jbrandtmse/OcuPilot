/**
 * Story 21.5's global sentences, held to the one published copy (AD-29, AD-39).
 *
 * Each `REASON*` parameter of `OcuPilot.Api.GlobalError` is one published sentence on three surfaces: the server sends it, the client's strings
 * table holds it, and EXPERIENCE.md's Fixed strings publish it. The two delete tools name a consequence code the proposal card and the typed-name
 * dialog map to one of them, and the kernel's protected-global sentence is pinned equal to the client's by `self-protection.test.mjs`.
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const GLOBAL_ERROR = join(REPO_ROOT, 'src', 'OcuPilot', 'Api', 'GlobalError.cls');

const TOOLS = join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool');

const STRINGS_SOURCE = join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'strings.ts');

const PROPOSAL_VIEW = join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'proposal-view.ts');

const HANDLER = join(REPO_ROOT, 'ui', 'src', 'app', 'shell', 'screen-action-handler.ts');

const EXPERIENCE = join(REPO_ROOT, '_bmad-output', 'planning-artifacts', 'ux-designs', 'ux-OcuPilot-2026-09-08', 'EXPERIENCE.md');

/** Every sentence `GlobalError` declares, and the `strings.ts` key it is pinned equal to. */
const SENTENCES = [
  ['REASONNOTFOUND', 'globalRefusalNotFound'],
  ['REASONNODENOTFOUND', 'globalRefusalNodeNotFound'],
  ['REASONNODENOTEDITABLE', 'globalRefusalNodeNotEditable'],
  ['REASONVALUESHAPE', 'globalRefusalValueShape'],
  ['REASONTOOLARGE', 'globalRefusalTooLarge'],
  ['REASONOWNDATA', 'globalRefusalOwnData'],
  ['REASONDELETE', 'globalDeleteConsequence'],
  ['REASONNODEDELETE', 'globalNodeDeleteConsequence'],
];

/** The consequences a card or dialog states: the code parameter, the code, the `proposal-view.ts` constant and the string. */
const CONSEQUENCES = [
  ['DELETE', 'GLOBAL.DELETE', 'CONSEQUENCE_GLOBALDELETE', 'globalDeleteConsequence', 'REASONDELETE'],
  ['NODEDELETE', 'GLOBAL.NODE.DELETE', 'CONSEQUENCE_GLOBALNODEDELETE', 'globalNodeDeleteConsequence', 'REASONNODEDELETE'],
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

// Mutation (Rule 19): change one word of REASONNODENOTEDITABLE in GlobalError.cls, or of `globalRefusalNodeNotEditable` in strings.ts -> this goes red naming both.
test('Story 21.5: each global sentence is one published sentence on the server, the strings table and Fixed strings', () => {
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [parameter, key] of SENTENCES) {
    const server = classParameter(GLOBAL_ERROR, parameter);
    assert.equal(server, stringValue(key), `${parameter} and ${key} are one published sentence`);
    assert.ok(experience.includes(`"${server}"`), `${parameter}'s sentence is published in EXPERIENCE.md's Fixed strings`);
    assert.ok(!server.toLowerCase().includes('agent'), `${parameter} names no caller: ${server}`);
  }
});

test('Story 21.5: GlobalError declares no sentence this test does not pin', () => {
  const declared = [...readFileSync(GLOBAL_ERROR, 'utf8').matchAll(/^Parameter (REASON\w+)/gm)].map((match) => match[1]).sort();
  assert.deepEqual(declared, SENTENCES.map(([parameter]) => parameter).sort());
});

// Mutation (Rule 19): swap the two returns of the global branches in `consequenceSentence` -> this goes red naming the code.
test('Story 21.5: the two delete cards state the sentence their consequence code names, and the list\'s dialog the global\'s', () => {
  const proposalView = readFileSync(PROPOSAL_VIEW, 'utf8');
  for (const [code, value, constant, key, reason] of CONSEQUENCES) {
    assert.equal(classParameter(GLOBAL_ERROR, code), value, `GlobalError names ${value}`);
    assert.ok(proposalView.includes(`${constant} = '${value}'`), `proposal-view.ts holds ${value}`);
    assert.ok(proposalView.includes(`if (code === ${constant}) return STRINGS.${key};`), `${constant} maps to ${key}`);
    assert.equal(classParameter(GLOBAL_ERROR, reason), stringValue(key), `${value}'s server sentence is ${key}`);
  }
  assert.equal(classParameter(join(TOOLS, 'ExplorerGlobalDelete.cls'), 'CONSEQUENCECODE'), 'GLOBAL.DELETE');
  assert.equal(classParameter(join(TOOLS, 'ExplorerGlobalNodeDelete.cls'), 'CONSEQUENCECODE'), 'GLOBAL.NODE.DELETE');
  const handler = readFileSync(HANDLER, 'utf8');
  assert.ok(
    handler.includes("'OcuPilot.Screen.Descriptor.ExplorerGlobalList': { delete: STRINGS.globalDeleteConsequence }"),
    "the Globals list's Delete dialog states the global's consequence"
  );
});
