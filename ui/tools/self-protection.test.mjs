/**
 * The self-protection layer's two rosters, each held to the source that owns it (AD-5, AD-53).
 *
 * A self-protection rule explains a refusal the instance makes; the client draws it before a click
 * and never enforces it. Two things therefore have to stay equal to the instance, and neither is
 * observable from the client alone:
 *
 * - the closed vocabulary `OcuPilot.Screen.Registry`'s `SELFPROTECTIONRULES` declares, against the
 *   rules `ui/src/app/core/self-protection.ts` can actually evaluate; and
 * - the web applications `src/OcuPilot/Install/Roster.cls` declares, against the paths that file
 *   compares a row against.
 *
 * A roster only one side knows ships as a row action offered with no explanation, or as one
 * explained on a row the instance would have let through -- the same failure `ci.test.mjs` pins for
 * the throwaway's arming rosters and `screen-mirror.test.mjs` for the confirm-channel projections.
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { IMPLEMENTED_SELF_PROTECTION_RULES, parseSelfProtectionRules } from './screen-mirror.mjs';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const SOURCE = join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'self-protection.ts');

const REGISTRY = join(REPO_ROOT, 'src', 'OcuPilot', 'Screen', 'Registry.cls');

const ROSTER = join(REPO_ROOT, 'src', 'OcuPilot', 'Install', 'Roster.cls');

const PROHIBITED = join(REPO_ROOT, 'src', 'OcuPilot', 'Kernel', 'Proposal', 'Prohibited.cls');

const STRINGS_SOURCE = join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'strings.ts');

/** The literals `OCUPILOT_APPLICATION_PATHS` holds, in declaration order. */
function clientPaths() {
  const source = readFileSync(SOURCE, 'utf8');
  const block = /OCUPILOT_APPLICATION_PATHS: readonly string\[\] = \[([^\]]*)\]/.exec(source);
  assert.notEqual(block, null, 'self-protection.ts declares OCUPILOT_APPLICATION_PATHS');
  return [...block[1].matchAll(/'([^']+)'/g)].map((m) => m[1]);
}

/** The `path` of every application `Roster.cls`'s manifest declares, in declaration order. */
function rosterPaths() {
  const roster = readFileSync(ROSTER, 'utf8');
  const applications = /"applications"\s*:\s*\[([\s\S]*?)\n  \]/.exec(roster);
  assert.notEqual(applications, null, 'Roster.cls declares an applications array');
  return [...applications[1].matchAll(/"path"\s*:\s*"([^"]+)"/g)].map((m) => m[1]);
}

/** The value `key` holds in `strings.ts`, which may sit on the line after its key. */
function stringValue(key) {
  const source = readFileSync(STRINGS_SOURCE, 'utf8');
  const match = new RegExp(`\\b${key}:\\s*\\n?\\s*'((?:[^'\\\\]|\\\\.)*)'`).exec(source);
  assert.notEqual(match, null, `strings.ts carries ${key}`);
  return match[1].replace(/\\'/g, "'").replace(/\\\\/g, '\\');
}

test('AD-53, AD-39: the serving-path refusal is one sentence on both surfaces', () => {
  // The row action drawn refused before a click and the envelope returned after one say the same
  // thing, because they are the same rule. Neither file is readable from the other at run time --
  // a running instance mounts no client source -- so the comparison lives here, where both are on
  // disk, and `OcuPilot.Test.RefusalCopy` holds the instance's own half of it.
  //
  // Mutation (Rule 19): change one word of `SERVINGPATHREASON` -> this goes red naming both.
  const kernel = /Parameter SERVINGPATHREASON = "([^"]+)";/.exec(readFileSync(PROHIBITED, 'utf8'));
  assert.notEqual(kernel, null, 'Prohibited.cls declares SERVINGPATHREASON');
  assert.equal(
    kernel[1],
    stringValue('webAppServesOcuPilotRefusal'),
    "the kernel's reason and the client's copy are one published sentence"
  );
  // And it names no caller: the same predicate refuses the agent and the screen alike (AD-53).
  assert.ok(!kernel[1].toLowerCase().includes('the agent'), `it names no caller: ${kernel[1]}`);
});

test('AD-53: the client draws exactly the self-protection rules the instance declares', () => {
  const declared = parseSelfProtectionRules(readFileSync(REGISTRY, 'utf8'));
  assert.notEqual(declared, null, 'Registry.cls declares SELFPROTECTIONRULES');
  assert.deepEqual(
    [...declared].sort(),
    [...IMPLEMENTED_SELF_PROTECTION_RULES].sort(),
    'a rule only one side knows explains nothing on the row it refuses'
  );

  // And the client file actually implements each of them, rather than exporting the roster alone.
  const source = readFileSync(SOURCE, 'utf8');
  for (const rule of declared) {
    assert.ok(source.includes(`'${rule}'`), `self-protection.ts names the rule '${rule}'`);
  }
});

test("AD-53: the client's OcuPilot application paths are the install roster's own", () => {
  const roster = rosterPaths();
  assert.ok(roster.length > 0, 'the roster declares applications at all, so this compared something');
  assert.deepEqual(
    clientPaths(),
    roster,
    'the paths the client explains a refusal for are the ones install creates'
  );
});

/** The four account refusals, each a `Prohibited.cls` parameter and a `strings.ts` key (Story 7.2). */
const ACCOUNT_REFUSALS = [
  ['SYSTEMACCOUNTREASON', 'userRefusalSystemAccount'],
  ['CURRENTUSERREASON', 'userRefusalCurrentUser'],
  ['SERVICEACCOUNTREASON', 'userRefusalServiceAccount'],
  ['LASTALLHOLDERREASON', 'userRefusalLastAllHolder'],
];

test('AD-53, AD-39: each account refusal is one sentence on both surfaces', () => {
  // Mutation (Rule 19): change one word of any *REASON parameter -> this goes red naming both.
  const source = readFileSync(PROHIBITED, 'utf8');
  for (const [parameter, key] of ACCOUNT_REFUSALS) {
    const kernel = new RegExp(`Parameter ${parameter} = "([^"]+)";`).exec(source);
    assert.notEqual(kernel, null, `Prohibited.cls declares ${parameter}`);
    assert.equal(kernel[1], stringValue(key), `${parameter} and ${key} are one published sentence`);
    assert.ok(!kernel[1].toLowerCase().includes('the agent'), `${parameter} names no caller: ${kernel[1]}`);
  }
});

/** The two process refusals, each a `Prohibited.cls` parameter and a `strings.ts` key (Story 7.8). */
const PROCESS_REFUSALS = [
  ['OCUPILOTPROCESSREASON', 'processRefusalOcuPilot'],
  ['SYSTEMPROCESSREASON', 'processRefusalSystem'],
];

test('AD-53, AD-39, DW-1499: each process refusal is one sentence on both surfaces, naming no caller', () => {
  // Mutation (Rule 19): change one word of either *PROCESSREASON parameter -> this goes red naming both.
  const source = readFileSync(PROHIBITED, 'utf8');
  for (const [parameter, key] of PROCESS_REFUSALS) {
    const kernel = new RegExp(`Parameter ${parameter} = "([^"]+)";`).exec(source);
    assert.notEqual(kernel, null, `Prohibited.cls declares ${parameter}`);
    assert.equal(kernel[1], stringValue(key), `${parameter} and ${key} are one published sentence`);
    assert.ok(!kernel[1].toLowerCase().includes('the agent'), `${parameter} names no caller: ${kernel[1]}`);
  }
  // And the lookup answers the parameter, not a literal of its own.
  for (const code of ['OCUPILOTPROCESS', 'SYSTEMPROCESS']) {
    assert.ok(source.includes(`If pCode = ..#${code} Quit ..#${code}REASON`), `ReasonFor answers ${code} with its parameter`);
  }
});

test("AD-53: the client's service accounts are the prohibited set's own", async () => {
  const { SERVICE_ACCOUNTS, SYSTEM_ACCOUNT } = await import('../src/app/core/self-protection.ts');
  const source = readFileSync(PROHIBITED, 'utf8');
  const declared = /Parameter SERVICEACCOUNTS = "([^"]+)";/.exec(source);
  assert.notEqual(declared, null, 'Prohibited.cls declares SERVICEACCOUNTS');
  assert.deepEqual([...SERVICE_ACCOUNTS], declared[1].split(','), 'one list, read by both sides');
  const system = /Parameter SYSTEMACCOUNTNAME = "([^"]+)";/.exec(source);
  assert.equal(SYSTEM_ACCOUNT, system?.[1], 'and one predefined account');
});

test('AD-53: protected-account answers the instance sentence per account, in its order', async () => {
  const { selfProtectionReason, SERVICE_ACCOUNTS } = await import('../src/app/core/self-protection.ts');
  const { STRINGS } = await import('../src/app/core/strings.ts');
  const rule = 'protected-account';
  // Mutation (Rule 19): return '' from the protected-account branch -> every leg below goes red.
  assert.equal(selfProtectionReason(rule, '_SYSTEM', 'Dana'), STRINGS.userRefusalSystemAccount);
  assert.equal(selfProtectionReason(rule, '_system', 'Dana'), STRINGS.userRefusalSystemAccount, 'any spelling');
  assert.equal(selfProtectionReason(rule, 'dana', 'Dana'), STRINGS.userRefusalCurrentUser, 'the signed-in account');
  for (const name of SERVICE_ACCOUNTS) {
    assert.equal(selfProtectionReason(rule, name.toUpperCase(), 'Dana'), STRINGS.userRefusalServiceAccount, name);
  }
  // _SYSTEM is asked first, as the instance asks it: a person signed in as _SYSTEM reads its sentence.
  assert.equal(selfProtectionReason(rule, '_SYSTEM', '_SYSTEM'), STRINGS.userRefusalSystemAccount);
  // An ordinary account and no row each explain nothing.
  assert.equal(selfProtectionReason(rule, 'Priya', 'Dana'), '');
  assert.equal(selfProtectionReason(rule, '', 'Dana'), '');
  // And the other rule is unmoved by the new one.
  assert.equal(selfProtectionReason('serves-ocupilot', '_SYSTEM', '_SYSTEM'), '');
  assert.equal(selfProtectionReason(rule, '/api/ocupilot', 'Dana'), '');
});
