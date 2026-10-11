/**
 * Story 20.2's Interoperability sentences and the cap they state, held to the instance's own source
 * (AD-39, AD-53, AD-62).
 *
 * Each `OcuPilot.Api.InteropError` sentence is one published string on both surfaces: the server sends
 * it, the client draws it, and EXPERIENCE.md's Fixed strings publish it. The stop, restart, update and
 * busy sentences state a wait, "15 seconds", which `OcuPilot.Port.InteropPort`'s `STOPSECONDS` is the
 * source of -- a cap changed in one place and not in the sentences would tell a person a wait the port
 * does not make.
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const PORT = join(REPO_ROOT, 'src', 'OcuPilot', 'Port', 'InteropPort.cls');

const ERROR = join(REPO_ROOT, 'src', 'OcuPilot', 'Api', 'InteropError.cls');

const ATELIER_PORT = join(REPO_ROOT, 'src', 'OcuPilot', 'Port', 'AtelierPort.cls');

const STRINGS_SOURCE = join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'strings.ts');

const EXPERIENCE = join(REPO_ROOT, '_bmad-output', 'planning-artifacts', 'ux-designs', 'ux-OcuPilot-2026-09-08', 'EXPERIENCE.md');

/** Every `<parameter>` sentence `InteropError` declares, and the `strings.ts` key it is pinned equal to. */
const SENTENCES = [
  ['REASONNAMESPACE', 'interopRefusalNoProductions'],
  ['REASONRUNNING', 'interopRefusalRunning'],
  ['REASONOTHER', 'interopRefusalOther'],
  ['REASONTROUBLED', 'interopRefusalTroubled'],
  ['REASONNOTRUNNING', 'interopRefusalNotRunning'],
  ['REASONUPTODATE', 'interopRefusalUpToDate'],
  ['REASONNOTTROUBLED', 'interopRefusalNotTroubled'],
  ['REASONBUSY', 'interopRefusalBusy'],
  ['REASONSTATE', 'interopRefusalState'],
  ['REASONSTOP', 'interopStopConsequence'],
  ['REASONRESTART', 'interopRestartConsequence'],
  ['REASONUPDATE', 'interopUpdateConsequence'],
  ['REASONRECOVER', 'interopRecoverConsequence'],
  ['REASONSUSPENDED', 'interopRefusalSuspended'],
  ['REASONPARTSTOPPED', 'interopRefusalPartStopped'],
  ['REASONITEMENABLED', 'interopItemRefusalEnabled'],
  ['REASONITEMDISABLED', 'interopItemRefusalDisabled'],
  ['REASONITEMDEFAULTSETTING', 'interopItemRefusalDefaultSetting'],
  ['REASONITEMPOOLZERO', 'interopItemRefusalPoolZero'],
  ['REASONITEMTAKEN', 'interopItemRefusalTaken'],
  ['REASONITEMAMBIGUOUS', 'interopItemRefusalAmbiguous'],
  ['REASONITEMCLASS', 'interopItemRefusalClass'],
  ['REASONITEMNAME', 'interopItemRefusalName'],
  ['REASONITEMVALUE', 'interopItemRefusalValue'],
  ['REASONITEMENABLEDREMOVE', 'interopItemRefusalEnabledRemove'],
  ['REASONITEMSOURCECONTROL', 'interopItemRefusalSourceControl'],
  ['REASONITEMPENDING', 'interopItemPendingConsequence'],
  ['REASONITEMREMOVE', 'interopItemRemoveConsequence'],
  ['REASONSETTINGSECRET', 'interopSettingRefusalSecret'],
  ['REASONSETTINGSUPPLIED', 'interopSettingRefusalSupplied'],
  ['REASONSETTINGSAME', 'interopSettingRefusalSame'],
  ['REASONSETTINGDEFAULTED', 'interopSettingRefusalDefaulted'],
  ['REASONSETTINGCORE', 'interopSettingRefusalCore'],
  ['REASONSETTINGVALUE', 'interopSettingRefusalValue'],
  ['REASONSETTINGDESCENT', 'interopSettingRefusalDescent'],
  ['REASONSETTINGLOCATION', 'interopSettingLocationConsequence'],
  ['REASONQUEUEEMPTY', 'interopRefusalQueueEmpty'],
  ['REASONQUEUECHANGED', 'interopRefusalQueueChanged'],
  ['REASONJOBDEAD', 'interopRefusalJobDead'],
  ['REASONJOBNOTRETRYING', 'interopRefusalJobNotRetrying'],
  ['REASONJOBNOTSTOPPED', 'interopRefusalJobNotStopped'],
  ['REASONMESSAGEABORT', 'interopMessageAbortConsequence'],
  ['REASONQUEUEABORT', 'interopQueueAbortConsequence'],
  ['REASONJOBABORT', 'interopJobAbortConsequence'],
  ['REASONJOBSUSPEND', 'interopJobSuspendConsequence'],
  ['REASONJOBSTOP', 'interopJobStopConsequence'],
  ['REASONLOOKUPTAKEN', 'interopLookupRefusalTaken'],
  ['REASONLOOKUPTABLECASE', 'interopLookupRefusalTableCase'],
  ['REASONLOOKUPSAME', 'interopLookupRefusalSame'],
  ['REASONLOOKUPSECRET', 'interopLookupRefusalSecret'],
  ['REASONLOOKUPSOURCECONTROL', 'interopLookupRefusalSourceControl'],
  ['REASONLOOKUPLOCKED', 'interopLookupRefusalLocked'],
  ['REASONLOOKUPTABLENAME', 'interopLookupRefusalTableName'],
  ['REASONLOOKUPKEY', 'interopLookupRefusalKey'],
  ['REASONLOOKUPVALUE', 'interopLookupRefusalValue'],
  ['REASONLOOKUPREMOVE', 'interopLookupRemoveConsequence'],
  ['REASONLOOKUPDELETE', 'interopLookupDeleteConsequence'],
  ['REASONLOOKUPIMPORTSHAPE', 'interopLookupRefusalImportShape'],
  ['REASONLOOKUPIMPORTCHANGED', 'interopLookupRefusalImportChanged'],
  ['REASONLOOKUPTOOLARGE', 'interopLookupRefusalTooLarge'],
  ['REASONLOOKUPIMPORT', 'interopLookupImportConsequence'],
];

/** The value `key` holds in `strings.ts`, which may sit on the line after its key. */
function stringValue(key) {
  const source = readFileSync(STRINGS_SOURCE, 'utf8');
  const match = new RegExp(`\\b${key}:\\s*\\n?\\s*'((?:[^'\\\\]|\\\\.)*)'`).exec(source);
  assert.notEqual(match, null, `strings.ts carries ${key}`);
  return match[1].replace(/\\'/g, "'").replace(/\\\\/g, '\\');
}

/** The sentence `parameter` holds in `InteropError.cls`. */
function serverSentence(parameter) {
  const match = new RegExp(`Parameter ${parameter} = "([^"]+)";`).exec(readFileSync(ERROR, 'utf8'));
  assert.notEqual(match, null, `InteropError.cls declares ${parameter}`);
  return match[1];
}

test('Story 20.2: each Interoperability refusal and consequence is one sentence on both surfaces, published in Fixed strings', () => {
  // Mutation (Rule 19): change one word of REASONBUSY in InteropError.cls -> this goes red naming both.
  const experience = readFileSync(EXPERIENCE, 'utf8');
  for (const [parameter, key] of SENTENCES) {
    const server = serverSentence(parameter);
    assert.equal(server, stringValue(key), `${parameter} and ${key} are one published sentence`);
    assert.ok(experience.includes(`"${server}"`), `${parameter}'s sentence is published in EXPERIENCE.md's Fixed strings`);
    assert.ok(!server.toLowerCase().includes('agent'), `${parameter} names no caller: ${server}`);
  }
});

test("Story 20.2: the wait the stop, restart, update and busy sentences state is the port's STOPSECONDS", () => {
  // Mutation (Rule 19): change STOPSECONDS in InteropPort.cls to 20 -> this goes red.
  const match = /Parameter STOPSECONDS = (\d+);/.exec(readFileSync(PORT, 'utf8'));
  assert.notEqual(match, null, 'InteropPort.cls declares STOPSECONDS');
  const seconds = match[1];
  for (const key of ['interopStopConsequence', 'interopRestartConsequence', 'interopUpdateConsequence', 'interopRefusalBusy', 'interopRefusalPartStopped', 'interopJobStopConsequence']) {
    assert.ok(stringValue(key).includes(`${seconds} seconds`), `${key} states a wait of ${seconds} seconds`);
  }
  for (const key of ['interopRecoverConsequence', 'interopRefusalRunning']) {
    assert.ok(!/\d+ seconds/.test(stringValue(key)), `${key} states no wait`);
  }
});

test("Story 20.23: the number the abort-all sentence states is the port's ABORTMAX", () => {
  // Mutation (Rule 19): change ABORTMAX in InteropPort.cls to 5000 -> this goes red.
  const match = /Parameter ABORTMAX = (\d+);/.exec(readFileSync(PORT, 'utf8'));
  assert.notEqual(match, null, 'InteropPort.cls declares ABORTMAX');
  const stated = `up to the first ${Number(match[1]).toLocaleString('en-US')},`;
  assert.ok(stringValue('interopQueueAbortConsequence').includes(stated), `interopQueueAbortConsequence states "${stated}"`);
  assert.ok(serverSentence('REASONQUEUEABORT').includes(stated), `REASONQUEUEABORT states "${stated}"`);
});

test("Story 20.5: the number the too-large sentence states is the Atelier port's MAXIMPORTCHARACTERS", () => {
  // Mutation (Rule 19): change MAXIMPORTCHARACTERS in AtelierPort.cls to 4000000 -> this goes red.
  const match = /Parameter MAXIMPORTCHARACTERS(?: As \w+)? = (\d+);/.exec(readFileSync(ATELIER_PORT, 'utf8'));
  assert.notEqual(match, null, 'AtelierPort.cls declares MAXIMPORTCHARACTERS');
  const stated = `${Number(match[1]).toLocaleString('en-US')} characters`;
  assert.ok(serverSentence('REASONLOOKUPTOOLARGE').includes(stated), `REASONLOOKUPTOOLARGE states "${stated}"`);
  assert.ok(stringValue('interopLookupRefusalTooLarge').includes(stated), `interopLookupRefusalTooLarge states "${stated}"`);
});
