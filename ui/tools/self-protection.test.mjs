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

const ERROR = join(REPO_ROOT, 'src', 'OcuPilot', 'Api', 'Error.cls');

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

/**
 * The account refusals, each a `Prohibited.cls` parameter and a `strings.ts` key: Story 7.2's four,
 * and Story 9.1's service-account sign-in refusal (DW-1520).
 */
const ACCOUNT_REFUSALS = [
  ['SYSTEMACCOUNTREASON', 'userRefusalSystemAccount'],
  ['CURRENTUSERREASON', 'userRefusalCurrentUser'],
  ['SERVICEACCOUNTREASON', 'userRefusalServiceAccount'],
  ['LASTALLHOLDERREASON', 'userRefusalLastAllHolder'],
  ['SERVICEACCOUNTSIGNINREASON', 'userRefusalServiceAccountSignIn'],
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

test('AD-53, AD-39, DW-1502: the privilege-grant refusal and the credential-type refusal are each one sentence on both surfaces', () => {
  // Mutation (Rule 19): change one word of PRIVILEGEGRANTREASON, or of Error.cls's
  // REASONAGENTCREDTYPEUNAVAILABLE -> this goes red naming both.
  const prohibited = readFileSync(PROHIBITED, 'utf8');
  const grant = /Parameter PRIVILEGEGRANTREASON = "([^"]+)";/.exec(prohibited);
  assert.notEqual(grant, null, 'Prohibited.cls declares PRIVILEGEGRANTREASON');
  assert.equal(grant[1], stringValue('webAppPrivilegeGrantRefusal'), 'PRIVILEGEGRANTREASON and webAppPrivilegeGrantRefusal are one published sentence');
  assert.ok(!grant[1].toLowerCase().includes('the agent'), `it names no caller: ${grant[1]}`);
  assert.ok(prohibited.includes('If pCode = ..#PRIVILEGEGRANT Quit ..#PRIVILEGEGRANTREASON'), 'ReasonFor answers PRIVILEGEGRANT with its parameter');
  const credType = /Parameter REASONAGENTCREDTYPEUNAVAILABLE = "([^"]+)";/.exec(readFileSync(ERROR, 'utf8'));
  assert.notEqual(credType, null, 'Error.cls declares REASONAGENTCREDTYPEUNAVAILABLE');
  assert.equal(credType[1], stringValue('agentCredTypeUnavailable'), 'REASONAGENTCREDTYPEUNAVAILABLE and agentCredTypeUnavailable are one published sentence');
});

test("AD-53: ocupilot-application-roles answers the privilege-grant sentence on OcuPilot's own applications alone", async () => {
  const { selfProtectionReason, OCUPILOT_APPLICATION_ROLES_RULE, OCUPILOT_APPLICATION_PATHS } = await import('../src/app/core/self-protection.ts');
  const { STRINGS } = await import('../src/app/core/strings.ts');
  for (const path of OCUPILOT_APPLICATION_PATHS) {
    assert.equal(selfProtectionReason(OCUPILOT_APPLICATION_ROLES_RULE, path), STRINGS.webAppPrivilegeGrantRefusal, `${path} is refused`);
    assert.equal(selfProtectionReason(OCUPILOT_APPLICATION_ROLES_RULE, `${path.toUpperCase()}/`), STRINGS.webAppPrivilegeGrantRefusal, `${path} is refused in any spelling`);
  }
  assert.equal(selfProtectionReason(OCUPILOT_APPLICATION_ROLES_RULE, '/csp/user'), '', 'and any other application is not');
});

test("AD-10: the editor's repointed fields are the prohibited set's CODEFIELDS", () => {
  // Mutation (Rule 19): drop 'SuperClass' from the store's CODE_FIELDS -> this goes red.
  const server = /Parameter CODEFIELDS = "([^"]+)";/.exec(readFileSync(PROHIBITED, 'utf8'));
  assert.notEqual(server, null, 'Prohibited.cls declares CODEFIELDS');
  const store = readFileSync(join(REPO_ROOT, 'ui', 'src', 'app', 'areas', 'web-applications', 'web-app-editor.store.ts'), 'utf8');
  const client = /export const CODE_FIELDS: readonly string\[\] = \[([^\]]*)\]/.exec(store);
  assert.notEqual(client, null, 'web-app-editor.store.ts declares CODE_FIELDS');
  const clientFields = [...client[1].matchAll(/'([^']+)'/g)].map((m) => m[1]);
  assert.deepEqual([...clientFields].sort(), server[1].split(',').sort(), 'the editor states the repointed line for exactly the fields the kernel marks');
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

test('DW-1520: the sign-in rule explains a service account other than the signed-in one, and nothing else', async () => {
  // Mutation (Rule 19): drop the signed-in exemption from `selfProtectionReason`'s sign-in branch ->
  // the irisowner-signed-in leg goes red; answer '' for the rule -> every service-account leg does.
  const { selfProtectionReason, SERVICE_ACCOUNTS, SERVICE_ACCOUNT_SIGN_IN_RULE } = await import('../src/app/core/self-protection.ts');
  const sentence = stringValue('userRefusalServiceAccountSignIn');
  for (const account of SERVICE_ACCOUNTS) {
    assert.equal(selfProtectionReason(SERVICE_ACCOUNT_SIGN_IN_RULE, account, '_SYSTEM'), sentence, `${account} is refused`);
    assert.equal(selfProtectionReason(SERVICE_ACCOUNT_SIGN_IN_RULE, account.toUpperCase(), '_SYSTEM'), sentence, `${account} in another case too`);
  }
  assert.equal(selfProtectionReason(SERVICE_ACCOUNT_SIGN_IN_RULE, 'irisowner', 'IRISOwner'), '', 'the signed-in account is exempt');
  assert.equal(selfProtectionReason(SERVICE_ACCOUNT_SIGN_IN_RULE, '_SYSTEM', 'admin'), '', '_SYSTEM is permitted');
  assert.equal(selfProtectionReason(SERVICE_ACCOUNT_SIGN_IN_RULE, 'admin', 'admin'), '', 'and so is the signed-in account');
  assert.equal(selfProtectionReason(SERVICE_ACCOUNT_SIGN_IN_RULE, 'someone', 'admin'), '', 'and any other account');
});

const EXPERIENCE = join(REPO_ROOT, '_bmad-output', 'planning-artifacts', 'ux-designs', 'ux-OcuPilot-2026-09-08', 'EXPERIENCE.md');

/** The two delete refusals (Story 9.3), each an `Error.cls` reason and a `strings.ts` key. */
const DELETE_REFUSALS = [
  ['REASONROLENAMESYSTEM', 'roleRefusalSystem'],
  ['REASONRESOURCENAMESYSTEM', 'resourceRefusalSystem'],
];

test('AD-53, DW-1513, DW-1528: each delete refusal is one sentence on both surfaces', () => {
  // Mutation (Rule 19): change one word of either reason in Error.cls -> this goes red naming both.
  const source = readFileSync(ERROR, 'utf8');
  for (const [parameter, key] of DELETE_REFUSALS) {
    const server = new RegExp(`Parameter ${parameter} = "([^"]+)";`).exec(source);
    assert.notEqual(server, null, `Error.cls declares ${parameter}`);
    assert.equal(server[1], stringValue(key), `${parameter} and ${key} are one published sentence`);
    assert.ok(!server[1].toLowerCase().includes('the agent'), `${parameter} names no caller: ${server[1]}`);
  }
});

/** The three kernel refusals Story 9.3 publishes (DW-1598), each a `Prohibited.cls` parameter and a `strings.ts` key. */
const KERNEL_REFUSALS = [
  ['UNCOVEREDFIELD', 'uncoveredFieldRefusal'],
  ['OCUPILOTROLE', 'roleRefusalOcuPilot'],
  ['OCUPILOTRESOURCE', 'resourceRefusalOcuPilot'],
  // Story 9.5: OcuPilot's own provider SSL/TLS configuration, whose four fields and whose Delete the
  // editor and the list draw refused before a click with this same sentence.
  ['OCUPILOTSSL', 'sslRefusalOcuPilot'],
];

test('DW-1598, AD-53: each kernel refusal is published verbatim in Fixed strings and is the sentence ReasonFor returns', () => {
  // Mutation (Rule 19): answer a literal for any of the three codes in `Prohibited.ReasonFor`, or
  // change one word of its parameter -> that code's legs go red.
  const prohibited = readFileSync(PROHIBITED, 'utf8');
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [code, key] of KERNEL_REFUSALS) {
    const kernel = new RegExp(`Parameter ${code}REASON = "([^"]+)";`).exec(prohibited);
    assert.notEqual(kernel, null, `Prohibited.cls declares ${code}REASON`);
    assert.ok(experience.includes(`"${kernel[1]}"`), `${code}REASON is published in EXPERIENCE.md's Fixed strings table`);
    assert.equal(kernel[1], stringValue(key), `${code}REASON and ${key} are one published sentence`);
    assert.ok(prohibited.includes(`If pCode = ..#${code} Quit ..#${code}REASON`), `ReasonFor answers ${code} with its parameter`);
    assert.ok(!kernel[1].toLowerCase().includes('agent'), `${code}REASON names no caller: ${kernel[1]}`);
  }
});

test('Story 9.3: system-role answers a name beginning % and system-resource a row reading AllowDelete false', async () => {
  // Mutation (Rule 19): make `system-resource` ignore the row -> the AllowDelete false leg goes red;
  // answer '' for `system-role` -> the %Developer leg goes red.
  const { selfProtectionReason, SYSTEM_ROLE_RULE, SYSTEM_RESOURCE_RULE } = await import('../src/app/core/self-protection.ts');
  const { STRINGS } = await import('../src/app/core/strings.ts');
  assert.equal(selfProtectionReason(SYSTEM_ROLE_RULE, '%Developer'), STRINGS.roleRefusalSystem, 'a predefined role is refused');
  assert.equal(selfProtectionReason(SYSTEM_ROLE_RULE, 'ProbeRole'), '', 'any other role is not');
  assert.equal(selfProtectionReason(SYSTEM_RESOURCE_RULE, '%DB_IRISSYS', '', { Name: '%DB_IRISSYS', AllowDelete: false }), STRINGS.resourceRefusalSystem, 'a system resource is refused');
  assert.equal(selfProtectionReason(SYSTEM_RESOURCE_RULE, 'ProbeResource', '', { Name: 'ProbeResource', AllowDelete: true }), '', 'a deletable one is not');
  assert.equal(selfProtectionReason(SYSTEM_RESOURCE_RULE, '%DB_IRISSYS'), '', 'and with no row the instance alone refuses');
});

test("Story 9.5: ocupilot-ssl answers OcuPilot's own provider configuration alone, named as the installer names it", async () => {
  // Mutation (Rule 19): answer '' for `ocupilot-ssl` -> the own-configuration leg goes red; rename
  // `OCUPILOT_SSL_CONFIGURATION` -> the Base.cls leg goes red.
  const { selfProtectionReason, OCUPILOT_SSL_RULE, OCUPILOT_SSL_CONFIGURATION } = await import('../src/app/core/self-protection.ts');
  const { STRINGS } = await import('../src/app/core/strings.ts');
  const base = readFileSync(join(REPO_ROOT, 'src', 'OcuPilot', 'Kernel', 'State', 'Base.cls'), 'utf8');
  const declared = /Parameter SSLCONFIG As %String = "([^"]+)";/.exec(base);
  assert.notEqual(declared, null, 'Base.cls declares SSLCONFIG');
  assert.equal(OCUPILOT_SSL_CONFIGURATION, declared[1], 'one name, read by both sides');
  assert.equal(selfProtectionReason(OCUPILOT_SSL_RULE, OCUPILOT_SSL_CONFIGURATION), STRINGS.sslRefusalOcuPilot, 'its own configuration is refused');
  assert.equal(selfProtectionReason(OCUPILOT_SSL_RULE, OCUPILOT_SSL_CONFIGURATION.toLowerCase()), '', 'compared exactly, as the instance resolves a name');
  assert.equal(selfProtectionReason(OCUPILOT_SSL_RULE, 'ISC.FeatureTracker.SSL.Config'), '', 'and any other configuration is not');
});
