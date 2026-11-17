/**
 * Story 21.14's locale sentences, held to the one published copy (AD-29, AD-39).
 *
 * Each `REASON*` parameter of `OcuPilot.Api.LocaleError` is one published sentence on three surfaces: the server sends it, the client's strings
 * table holds it, and EXPERIENCE.md's Fixed strings publish it. The install and delete tools and the locale-format switch name a consequence code
 * the proposal card maps to one of them, and the Validate dialog's two sentences are published beside them.
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const LOCALE_ERROR = join(REPO_ROOT, 'src', 'OcuPilot', 'Api', 'LocaleError.cls');

const CONFIG_ERROR = join(REPO_ROOT, 'src', 'OcuPilot', 'Api', 'ConfigError.cls');

const TOOLS = join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Tool');

const STRINGS_SOURCE = join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'strings.ts');

const PROPOSAL_VIEW = join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'proposal-view.ts');

const EXPERIENCE = join(REPO_ROOT, '_bmad-output', 'planning-artifacts', 'ux-designs', 'ux-OcuPilot-2026-09-08', 'EXPERIENCE.md');

/** Every sentence `LocaleError` declares, and the `strings.ts` key it is pinned equal to. */
const SENTENCES = [
  ['REASONNOTFOUND', 'localeRefusalNotFound'],
  ['REASONNOTINSTALLABLE', 'localeRefusalNotInstallable'],
  ['REASONSYSTEM', 'localeRefusalSystem'],
  ['REASONCURRENT', 'localeRefusalCurrent'],
  ['REASONINSTALL', 'localeInstallConsequence'],
  ['REASONDELETE', 'localeDeleteConsequence'],
];

/** The consequences a card states: the class that declares the sentence, its code parameter, the code, the `proposal-view.ts` constant and the string. */
const CONSEQUENCES = [
  [LOCALE_ERROR, 'INSTALL', 'REASONINSTALL', 'LOCALE.INSTALL', 'CONSEQUENCE_LOCALEINSTALL', 'localeInstallConsequence'],
  [LOCALE_ERROR, 'DELETE', 'REASONDELETE', 'LOCALE.DELETE', 'CONSEQUENCE_LOCALEDELETE', 'localeDeleteConsequence'],
  [CONFIG_ERROR, 'NLSRELOAD', 'REASONNLSRELOAD', 'CONFIG.NLS.RELOAD', 'CONSEQUENCE_CONFIGNLSRELOAD', 'nlsDefaultReloadConsequence'],
];

/** The Validate dialog's two sentences, which the server never sends: published in Fixed strings and spelled once in the strings table. */
const DIALOG_SENTENCES = [
  ['localeValidateValid', 'This locale is valid.'],
  ['localeValidateProblems', 'This locale has problems.'],
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

// Mutation (Rule 19): change one word of REASONCURRENT in LocaleError.cls, or of `localeRefusalCurrent` in strings.ts -> this goes red naming both.
test('Story 21.14: each locale sentence is one published sentence on the server, the strings table and Fixed strings', () => {
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [parameter, key] of SENTENCES) {
    const server = classParameter(LOCALE_ERROR, parameter);
    assert.equal(server, stringValue(key), `${parameter} and ${key} are one published sentence`);
    assert.ok(experience.includes(`"${server}"`), `${parameter}'s sentence is published in EXPERIENCE.md's Fixed strings`);
    assert.ok(!server.toLowerCase().includes('agent'), `${parameter} names no caller: ${server}`);
  }
});

test('Story 21.14: LocaleError declares no sentence this test does not pin', () => {
  const declared = [...readFileSync(LOCALE_ERROR, 'utf8').matchAll(/^Parameter (REASON\w+)/gm)].map((match) => match[1]).sort();
  assert.deepEqual(declared, SENTENCES.map(([parameter]) => parameter).sort());
});

// Mutation (Rule 19): swap the two returns of the locale branches in `consequenceSentence` -> this goes red naming the code.
test('Story 21.14: the install, delete and locale-format cards state the sentence their consequence code names', () => {
  const proposalView = readFileSync(PROPOSAL_VIEW, 'utf8');
  for (const [file, code, reason, value, constant, key] of CONSEQUENCES) {
    assert.equal(classParameter(file, code), value, `${file} names ${value}`);
    assert.ok(proposalView.includes(`${constant} = '${value}'`), `proposal-view.ts holds ${value}`);
    assert.ok(proposalView.includes(`if (code === ${constant}) return STRINGS.${key};`), `${constant} maps to ${key}`);
    assert.equal(classParameter(file, reason), stringValue(key), `${value}'s server sentence is ${key}`);
  }
  assert.equal(classParameter(join(TOOLS, 'LocaleInstall.cls'), 'CONSEQUENCECODE'), 'LOCALE.INSTALL');
  assert.equal(classParameter(join(TOOLS, 'LocaleDelete.cls'), 'CONSEQUENCECODE'), 'LOCALE.DELETE');
});

test('Story 21.14: the Validate dialog states the two published sentences', () => {
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [key, sentence] of DIALOG_SENTENCES) {
    assert.equal(stringValue(key), sentence, `${key} is the ruled sentence`);
    assert.ok(experience.includes(`"${sentence}"`), `${key}'s sentence is published in EXPERIENCE.md's Fixed strings`);
  }
});
