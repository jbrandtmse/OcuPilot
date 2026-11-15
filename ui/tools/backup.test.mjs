/**
 * Story 21.2's backup sentences, held to the instance's own source (AD-21, AD-22, AD-29).
 *
 * `OcuPilot.Api.BackupError`'s sentences are each one published string on three surfaces: the server sends it, the client's strings table
 * holds it, and EXPERIENCE.md's Fixed strings publish it. The run and freeze tools name a consequence code the proposal card maps to one of
 * them.
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const ERROR = join(REPO_ROOT, 'src', 'OcuPilot', 'Api', 'BackupError.cls');

const TOOLS = join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool');

const STRINGS_SOURCE = join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'strings.ts');

const PROPOSAL_VIEW = join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'proposal-view.ts');

const EXPERIENCE = join(REPO_ROOT, '_bmad-output', 'planning-artifacts', 'ux-designs', 'ux-OcuPilot-2026-09-08', 'EXPERIENCE.md');

/** Every sentence `BackupError` declares, and the `strings.ts` key it is pinned equal to. */
const SENTENCES = [
  ['REASONTASKNOTFOUND', 'backupRefusalTaskNotFound'],
  ['REASONRUNNING', 'backupRefusalRunning'],
  ['REASONFREEZELIMIT', 'backupRefusalFreezeLimit'],
  ['REASONFROZEN', 'backupRefusalFrozen'],
  ['REASONFREEZEUNBOUNDED', 'backupRefusalFreezeUnbounded'],
  ['REASONNOTFROZEN', 'backupRefusalNotFrozen'],
  ['REASONDATABASENOTFOUND', 'backupRefusalDatabaseNotFound'],
  ['REASONLISTCONFLICT', 'backupRefusalListConflict'],
  ['REASONRUN', 'backupRunNote'],
  ['REASONFREEZE', 'backupFreezeConsequence'],
];

/** The two tools that state a consequence on their card: the tool file, its code, the `proposal-view.ts` constant and the string it maps to. */
const CONSEQUENCES = [
  ['BackupRun.cls', 'BACKUP.RUN', 'CONSEQUENCE_BACKUPRUN', 'backupRunNote'],
  ['BackupFreeze.cls', 'BACKUP.FREEZE', 'CONSEQUENCE_BACKUPFREEZE', 'backupFreezeConsequence'],
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

test('Story 21.2: each backup sentence is one published sentence on the server, the strings table and Fixed strings', () => {
  // Mutation (Rule 19): change one word of REASONFROZEN in BackupError.cls -> this goes red naming both.
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [parameter, key] of SENTENCES) {
    const server = classParameter(ERROR, parameter);
    assert.equal(server, stringValue(key), `${parameter} and ${key} are one published sentence`);
    assert.ok(experience.includes(`"${server}"`), `${parameter}'s sentence is published in EXPERIENCE.md's Fixed strings`);
    assert.ok(!server.toLowerCase().includes('agent'), `${parameter} names no caller: ${server}`);
  }
});

test('Story 21.2: the run and freeze cards state the sentence their consequence code names', () => {
  // Mutation (Rule 19): swap the two returns in `consequenceSentence`'s backup branches -> this goes red naming the code.
  const proposalView = readFileSync(PROPOSAL_VIEW, 'utf8');
  for (const [file, code, constant, key] of CONSEQUENCES) {
    assert.equal(classParameter(join(TOOLS, file), 'CONSEQUENCECODE'), code, `${file} names ${code}`);
    assert.ok(proposalView.includes(`${constant} = '${code}'`), `proposal-view.ts holds ${code}`);
    assert.ok(proposalView.includes(`if (code === ${constant}) return STRINGS.${key};`), `${constant} maps to ${key}`);
    assert.equal(classParameter(ERROR, key === 'backupRunNote' ? 'REASONRUN' : 'REASONFREEZE'), stringValue(key), `${code}'s server sentence is ${key}`);
  }
});
