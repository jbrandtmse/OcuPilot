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
import { readdirSync, readFileSync } from 'node:fs';
import { test } from 'node:test';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

const PORT = join(REPO_ROOT, 'src', 'OcuPilot', 'Port', 'InteropPort.cls');

const ERROR = join(REPO_ROOT, 'src', 'OcuPilot', 'Api', 'InteropError.cls');

const ATELIER_PORT = join(REPO_ROOT, 'src', 'OcuPilot', 'Port', 'AtelierPort.cls');

const STRINGS_SOURCE = join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'strings.ts');

const EXPERIENCE = join(REPO_ROOT, '_bmad-output', 'planning-artifacts', 'ux-designs', 'ux-OcuPilot-2026-09-08', 'EXPERIENCE.md');

/** Every `<parameter>` sentence `InteropError` declares, and the `strings.ts` key it is pinned equal to (Story 20.31's resend and edit sentences, verdicts and outcome words included). */
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
  ['REASONITEMCOPY', 'interopItemCopyConsequence'],
  ['REASONITEMCOPYSOURCE', 'interopItemRefusalCopySource'],
  ['REASONITEMCHANGECLASS', 'interopItemChangeClassConsequence'],
  ['REASONITEMNEWCLASS', 'interopItemRefusalNewClass'],
  ['REASONITEMSAMECLASS', 'interopItemRefusalSameClass'],
  ['REASONITEMREVIEWCHANGED', 'interopItemRefusalReviewChanged'],
  ['REASONITEMNOTENABLED', 'interopItemRefusalNotEnabled'],
  ['REASONITEMTEMPSTOPPED', 'interopItemRefusalTempStopped'],
  ['REASONITEMNOTTEMPSTOPPED', 'interopItemRefusalNotTempStopped'],
  ['REASONITEMNOJOBS', 'interopItemRefusalNoJobs'],
  ['REASONITEMSTARTPENDING', 'interopItemRefusalStartPending'],
  ['REASONITEMSTOP', 'interopItemStopConsequence'],
  ['REASONITEMSTART', 'interopItemStartConsequence'],
  ['REASONITEMRESTART', 'interopItemRestartConsequence'],
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
  ['REASONLOOKUPEXPORTNAME', 'interopLookupRefusalExportName'],
  ['REASONLOOKUPIMPORT', 'interopLookupImportConsequence'],
  ['REASONPARTNERTAKEN', 'interopPartnerRefusalTaken'],
  ['REASONPARTNERNAMECASE', 'interopPartnerRefusalNameCase'],
  ['REASONPARTNERNAMED', 'interopPartnerRefusalNamed'],
  ['REASONPARTNERSOURCECONTROL', 'interopPartnerRefusalSourceControl'],
  ['REASONPARTNERNAME', 'interopPartnerRefusalName'],
  ['REASONPARTNERLENGTH', 'interopPartnerRefusalLength'],
  ['REASONPARTNERREMOVE', 'interopPartnerRemoveConsequence'],
  ['REASONDEFAULTSETTINGTAKEN', 'interopDefaultSettingRefusalTaken'],
  ['REASONDEFAULTSETTINGSECRET', 'interopDefaultSettingRefusalSecret'],
  ['REASONDEFAULTSETTINGKEY', 'interopDefaultSettingRefusalKey'],
  ['REASONDEFAULTSETTINGVALUE', 'interopDefaultSettingRefusalValue'],
  ['REASONDEFAULTSETTINGRESTRICTED', 'interopDefaultSettingRefusalRestricted'],
  ['REASONDEFAULTSETTINGSOURCECONTROL', 'interopDefaultSettingRefusalSourceControl'],
  ['REASONDEFAULTSETTINGTOOMANY', 'interopDefaultSettingRefusalTooMany'],
  ['REASONDEFAULTSETTINGREMOVE', 'interopDefaultSettingRemoveConsequence'],
  ['REASONDEFAULTSETTINGPENDING', 'interopDefaultSettingPendingConsequence'],
  ['REASONCREDENTIALTAKEN', 'interopCredentialRefusalTaken'],
  ['REASONCREDENTIALNAME', 'interopCredentialRefusalName'],
  ['REASONCREDENTIALPARTNER', 'interopCredentialRefusalPartner'],
  ['REASONCREDENTIALVALUE', 'interopCredentialRefusalValue'],
  ['REASONCREDENTIALREMOVE', 'x509DeleteConsequence'],
  ['REASONCREDENTIALCHANGE', 'interopCredentialChangeConsequence'],
  ['REASONSCHEDULETAKEN', 'interopScheduleRefusalTaken'],
  ['REASONSCHEDULENAME', 'interopScheduleRefusalName'],
  ['REASONSCHEDULESPEC', 'interopScheduleRefusalSpec'],
  ['REASONSCHEDULEDESCRIPTION', 'interopScheduleRefusalDescription'],
  ['REASONSCHEDULESOURCECONTROL', 'interopScheduleRefusalSourceControl'],
  ['REASONSCHEDULEREMOVE', 'interopScheduleRemoveConsequence'],
  ['REASONSCHEDULECHANGE', 'interopScheduleChangeConsequence'],
  ['REASONWORKFLOWSOURCECONTROL', 'interopWorkflowUserRefusalSourceControl'],
  ['REASONWORKFLOWUSERNAME', 'interopWorkflowUserRefusalName'],
  ['REASONWORKFLOWUSERTAKEN', 'interopWorkflowUserRefusalTaken'],
  ['REASONWORKFLOWFULLNAME', 'interopWorkflowUserRefusalFullName'],
  ['REASONWORKFLOWUSERREMOVE', 'interopWorkflowUserRemoveConsequence'],
  ['REASONWORKFLOWUSERINACTIVE', 'interopWorkflowUserInactiveConsequence'],
  ['REASONWORKFLOWROLENAME', 'interopWorkflowRoleRefusalName'],
  ['REASONWORKFLOWROLETAKEN', 'interopWorkflowRoleRefusalTaken'],
  ['REASONWORKFLOWROLEDESCRIPTION', 'interopWorkflowRoleRefusalDescription'],
  ['REASONWORKFLOWROLECAPACITY', 'interopWorkflowRoleRefusalCapacity'],
  ['REASONWORKFLOWMEMBERUSER', 'interopWorkflowMemberRefusalUser'],
  ['REASONWORKFLOWMEMBERTAKEN', 'interopWorkflowMemberRefusalTaken'],
  ['REASONWORKFLOWMEMBERRANK', 'interopWorkflowMemberRefusalRank'],
  ['REASONWORKFLOWMEMBERTITLE', 'interopWorkflowMemberRefusalTitle'],
  ['REASONWORKFLOWROLEREMOVE', 'interopWorkflowRoleRemoveConsequence'],
  ['REASONWORKFLOWMEMBERADD', 'interopWorkflowMemberAddConsequence'],
  ['REASONWORKFLOWMEMBERREMOVE', 'interopWorkflowMemberRemoveConsequence'],
  ['REASONPURGEDAYS', 'interopPurgeRefusalDays'],
  ['REASONPURGERUNNING', 'interopPurgeRefusalRunning'],
  ['REASONPURGERUN', 'interopPurgeRunConsequence'],
  ['REASONPURGEBITMAP', 'interopPurgeBitmapConsequence'],
  ['REASONTESTDISABLED', 'interopTestRefusalDisabled'],
  ['REASONTESTTARGETTYPE', 'interopTestRefusalTargetType'],
  ['REASONTESTTARGETDISABLED', 'interopTestRefusalTargetDisabled'],
  ['REASONTESTREQUESTTYPE', 'interopTestRefusalRequestType'],
  ['REASONTESTSECRET', 'interopTestRefusalSecret'],
  ['REASONTESTFIELD', 'interopTestRefusalField'],
  ['REASONTESTVALUE', 'interopTestRefusalValue'],
  ['REASONTESTREQUEST', 'interopTestRefusalRequest'],
  ['REASONTESTSENDS', 'interopTestSendsConsequence'],
  ['REASONTRANSFORMSOURCEFORMAT', 'interopTransformRefusalSourceFormat'],
  ['REASONTRANSFORMTARGETFORMAT', 'interopTransformRefusalTargetFormat'],
  ['REASONTRANSFORMCONTENT', 'interopTransformRefusalContent'],
  ['REASONTRANSFORMRUNS', 'interopTransformRunsConsequence'],
  ['REASONMESSAGECONTENTS', 'interopRefusalMessageContents'],
  ['REASONRESENDNONE', 'interopRefusalResendNone'],
  ['REASONRESENDCHANGED', 'interopRefusalResendChanged'],
  ['REASONEDITNOTEDITABLE', 'interopRefusalEditNotEditable'],
  ['REASONEDITNOCHANGE', 'interopRefusalEditNoChange'],
  ['REASONEDITFIELD', 'interopRefusalEditField'],
  ['REASONEDITSECRET', 'interopRefusalEditSecret'],
  ['REASONEDITVALUE', 'interopRefusalEditValue'],
  ['REASONMESSAGERESEND', 'interopMessageResendConsequence'],
  ['REASONMESSAGEEDITRESEND', 'interopMessageEditResendConsequence'],
  ['VERDICTRESEND', 'interopResendVerdictResend'],
  ['VERDICTGONE', 'interopResendVerdictGone'],
  ['VERDICTNOBODY', 'interopResendVerdictNobody'],
  ['VERDICTTARGETOFF', 'interopResendVerdictTargetOff'],
  ['VERDICTNOREPLYQUEUE', 'interopResendVerdictNoReplyQueue'],
  ['OUTCOMERESENT', 'interopResendOutcome'],
  ['OUTCOMEFAILED', 'interopResendFailed'],
  // Story 24.16 Batch 2: the suspended messages' refusals, consequences, verdicts and outcome words.
  ['REASONSUSPENDEDNONE', 'interopSuspendedRefusalNone'],
  ['REASONSUSPENDEDCHANGED', 'interopSuspendedRefusalChanged'],
  ['REASONSUSPENDEDRESUBMIT', 'interopSuspendedResubmitConsequence'],
  ['REASONSUSPENDEDEDIT', 'interopSuspendedEditConsequence'],
  ['REASONSUSPENDEDDISCARD', 'interopSuspendedDiscardConsequence'],
  ['REASONSUSPENDEDDELETE', 'interopSuspendedDeleteConsequence'],
  ['VERDICTNOTSUSPENDED', 'interopSuspendedVerdictNotSuspended'],
  ['VERDICTRESUBMIT', 'interopSuspendedVerdictResubmit'],
  ['VERDICTDISCARD', 'interopSuspendedVerdictDiscard'],
  ['VERDICTDELETE', 'interopSuspendedVerdictDelete'],
  ['OUTCOMERESUBMITTED', 'interopSuspendedOutcomeResubmitted'],
  ['OUTCOMENOTRESUBMITTED', 'interopSuspendedOutcomeNotResubmitted'],
  ['OUTCOMEDISCARDED', 'interopSuspendedOutcomeDiscarded'],
  ['OUTCOMENOTDISCARDED', 'interopSuspendedOutcomeNotDiscarded'],
  ['OUTCOMEDELETED', 'interopSuspendedOutcomeDeleted'],
  ['OUTCOMENOTDELETED', 'interopSuspendedOutcomeNotDeleted'],
  // Story 24.16 Batch 3: the message export's refusals, consequence, verdicts and outcome words; a file over the cap reads the one sentence an oversize file already has.
  ['REASONEXPORTNONE', 'interopExportRefusalNone'],
  ['REASONEXPORTCHANGED', 'interopExportRefusalChanged'],
  ['REASONEXPORTTOOLARGE', 'analyticsRefusalTermListTooLarge'],
  ['REASONMESSAGEEXPORT', 'interopMessageExportConsequence'],
  ['VERDICTEXPORT', 'interopExportVerdictExport'],
  ['VERDICTNOTEXT', 'interopExportVerdictNotext'],
  ['OUTCOMEEXPORTED', 'interopExportOutcomeExported'],
  ['OUTCOMENOTEXPORTED', 'interopExportOutcomeNotExported'],
  // Story 24.16 Batch 4: the archive manager's five refusals and its consequence, and what Archive to namespace accepts when no other namespace is listed.
  ['REASONARCHIVERUNNING', 'interopArchiveRefusalRunning'],
  ['REASONARCHIVENOTARGET', 'interopArchiveRefusalNoTarget'],
  ['REASONARCHIVECLASS', 'interopArchiveRefusalClass'],
  ['REASONARCHIVETOOMANY', 'interopArchiveRefusalTooMany'],
  ['REASONARCHIVETAKEN', 'interopArchiveRefusalTaken'],
  ['REASONARCHIVERUN', 'interopArchiveRunConsequence'],
  ['ACCEPTSNOARCHIVETARGET', 'interopArchiveAcceptsNone'],
  // Story 24.17 Batch 1: the managed alert update's six refusals and its consequence.
  ['REASONALERTNOTFOUND', 'interopManagedAlertRefusalNotFound'],
  ['REASONALERTUNCHANGED', 'interopManagedAlertRefusalUnchanged'],
  ['REASONALERTOWNER', 'interopManagedAlertRefusalOwner'],
  ['REASONALERTLEVEL', 'interopManagedAlertRefusalLevel'],
  ['REASONALERTNEXTACTION', 'interopManagedAlertRefusalNextAction'],
  ['REASONALERTREASON', 'interopManagedAlertRefusalReason'],
  ['REASONALERTUPDATE', 'interopManagedAlertUpdateConsequence'],
  // Story 24.17 Batch 2: the business rule log and business process log purges' consequences.
  ['REASONRULELOGPURGE', 'interopRuleLogPurgeConsequence'],
  ['REASONPROCESSLOGPURGE', 'interopProcessLogPurgeConsequence'],
  ['REASONSTARTUPSAME', 'interopStartupRefusalSame'],
  ['REASONSTARTUPPRIORITY', 'interopStartupRefusalPriority'],
  ['REASONSTARTUPGROUP', 'interopStartupRefusalGroup'],
  ['REASONSTARTUPNOPRIORITY', 'interopStartupRefusalNoPriority'],
  ['REASONSTARTUPALLNAMESPACES', 'interopStartupRefusalNeedsAll'],
  ['REASONSTARTUPREADONLY', 'interopStartupRefusalReadOnly'],
  ['REASONAUTOSTART', 'interopAutoStartConsequence'],
  ['REASONSHUTDOWNGROUP', 'interopShutdownGroupConsequence'],
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

test("Story 20.2: the wait the stop, restart, update and busy sentences state (Story 20.25's item stop, restart and start-pending among them) is the port's STOPSECONDS", () => {
  // Mutation (Rule 19): change STOPSECONDS in InteropPort.cls to 20 -> this goes red.
  const match = /Parameter STOPSECONDS = (\d+);/.exec(readFileSync(PORT, 'utf8'));
  assert.notEqual(match, null, 'InteropPort.cls declares STOPSECONDS');
  const seconds = match[1];
  for (const key of ['interopStopConsequence', 'interopRestartConsequence', 'interopUpdateConsequence', 'interopRefusalBusy', 'interopRefusalPartStopped', 'interopJobStopConsequence', 'interopItemStopConsequence', 'interopItemRestartConsequence', 'interopItemRefusalStartPending']) {
    assert.ok(stringValue(key).includes(`${seconds} seconds`), `${key} states a wait of ${seconds} seconds`);
  }
  for (const key of ['interopRecoverConsequence', 'interopRefusalRunning', 'interopItemStartConsequence']) {
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

test("Story 20.27: the number the transformation test's content sentence states is the Atelier port's MAXIMPORTCHARACTERS", () => {
  // Mutation (Rule 19): change MAXIMPORTCHARACTERS in AtelierPort.cls to 4000000 -> this goes red.
  const match = /Parameter MAXIMPORTCHARACTERS(?: As \w+)? = (\d+);/.exec(readFileSync(ATELIER_PORT, 'utf8'));
  assert.notEqual(match, null, 'AtelierPort.cls declares MAXIMPORTCHARACTERS');
  const stated = `at most ${Number(match[1]).toLocaleString('en-US')} characters`;
  assert.ok(serverSentence('REASONTRANSFORMCONTENT').includes(stated), `REASONTRANSFORMCONTENT states "${stated}"`);
  assert.ok(stringValue('interopTransformRefusalContent').includes(stated), `interopTransformRefusalContent states "${stated}"`);
});

test("Story 20.5: the number the too-large sentence states is the Atelier port's MAXIMPORTCHARACTERS", () => {
  // Mutation (Rule 19): change MAXIMPORTCHARACTERS in AtelierPort.cls to 4000000 -> this goes red.
  const match = /Parameter MAXIMPORTCHARACTERS(?: As \w+)? = (\d+);/.exec(readFileSync(ATELIER_PORT, 'utf8'));
  assert.notEqual(match, null, 'AtelierPort.cls declares MAXIMPORTCHARACTERS');
  const stated = `${Number(match[1]).toLocaleString('en-US')} characters`;
  assert.ok(serverSentence('REASONLOOKUPTOOLARGE').includes(stated), `REASONLOOKUPTOOLARGE states "${stated}"`);
  assert.ok(stringValue('interopLookupRefusalTooLarge').includes(stated), `interopLookupRefusalTooLarge states "${stated}"`);
});

const MIRROR = join(REPO_ROOT, 'ui', 'src', 'app', 'core', 'screens.generated.ts');

test('Story 24.3 (DW-2452): the empty-agent phrase of every write-capable Interoperability screen starts with a lowercase letter and ends without a period', () => {
  // The table draws it inside "Or ask the agent: <phrase>.", so a whole sentence there reads "Or ask the agent: Ask the agent ...".
  const screens = JSON.parse(
    readFileSync(MIRROR, 'utf8').match(/export const SCREENS: readonly ScreenDeclaration\[\] = (\[[\s\S]*?\n\]);/)[1]
  );
  const writeCapable = screens.filter(
    (screen) =>
      screen.area === 'interoperability' &&
      screen.table !== null &&
      (screen.primaryAction.id !== '' || screen.rowActions.some((action) => action.id !== ''))
  );
  assert.ok(writeCapable.length >= 11, `the write-capable Interoperability screens are found: ${writeCapable.length}`);
  const wrong = [];
  for (const screen of writeCapable) {
    // A screen with no key draws no agent phrase, and an empty key would match any entry of strings.ts.
    if (screen.table.emptyAgentKey === '') continue;
    const phrase = stringValue(screen.table.emptyAgentKey);
    if (!/^[a-z]/.test(phrase) || phrase.endsWith('.')) wrong.push(`${screen.table.emptyAgentKey}: ${JSON.stringify(phrase)}`);
  }
  assert.deepEqual(wrong, [], `empty-agent phrases that are not lowercase action phrases:\n${wrong.join('\n')}`);
});

const README = join(REPO_ROOT, 'README.md');

const BASELINE = join(REPO_ROOT, 'src', 'OcuPilot', 'Kernel', 'Governance', 'Baseline.cls');

const UNDER_TWENTY = ['zero', 'one', 'two', 'three', 'four', 'five', 'six', 'seven', 'eight', 'nine', 'ten', 'eleven', 'twelve', 'thirteen', 'fourteen', 'fifteen', 'sixteen', 'seventeen', 'eighteen', 'nineteen'];

const TENS = ['', '', 'twenty', 'thirty', 'forty', 'fifty', 'sixty', 'seventy', 'eighty', 'ninety'];

/** A whole number from 1 to 999 as the README writes one, capitalised: "Ninety", "One hundred and seven", "Eighty-five". */
function numberWords(value) {
  const hundreds = Math.floor(value / 100);
  const rest = value % 100;
  const below = rest < 20 ? UNDER_TWENTY[rest] : `${TENS[Math.floor(rest / 10)]}${rest % 10 === 0 ? '' : `-${UNDER_TWENTY[rest % 10]}`}`;
  const words = hundreds === 0 ? below : rest === 0 ? `${UNDER_TWENTY[hundreds]} hundred` : `${UNDER_TWENTY[hundreds]} hundred and ${below}`;
  return words.charAt(0).toUpperCase() + words.slice(1);
}

const SOURCE_ROOT = join(REPO_ROOT, 'src');

/** Every class under `src/` by name: its superclasses, each package-qualified, and the parameters it declares itself. */
function classIndex() {
  const index = new Map();
  for (const entry of readdirSync(SOURCE_ROOT, { recursive: true })) {
    if (!String(entry).endsWith('.cls')) continue;
    const text = readFileSync(join(SOURCE_ROOT, String(entry)), 'utf8');
    const head = /^Class (\S+)(?: Extends (\([^)]*\)|[^\s[]+))?/m.exec(text);
    if (!head) continue;
    const pkg = head[1].slice(0, head[1].lastIndexOf('.'));
    const supers = (head[2] ?? '').replace(/[()]/g, '').split(',').map((name) => name.trim()).filter(Boolean).map((name) => (name.includes('.') ? name : `${pkg}.${name}`));
    const params = new Map([...text.matchAll(/^Parameter (\w+)(?: As \w+)? = "?([^";\n]*)"?;/gm)].map((match) => [match[1], match[2]]));
    index.set(head[1], { supers, params });
  }
  return index;
}

/** The value of `parameter` on class `name`, declared there or inherited, or `undefined`. */
function parameterOf(index, name, parameter) {
  const entry = index.get(name);
  if (!entry) return undefined;
  if (entry.params.has(parameter)) return entry.params.get(parameter);
  for (const parent of entry.supers) {
    const value = parameterOf(index, parent, parameter);
    if (value !== undefined) return value;
  }
  return undefined;
}

// Story 24.16 Batch 4, AC8. The README's count is of agent actions that ship switched off: the baseline's `false` keys less the keys of tools a
// person alone runs (ADVERTISED 0, read from each tool class's own declaration), which its next sentence names separately. A key added `false` to
// the baseline reddens this until the README's count and list say so.
// Mutation (Rule 19): type the count in the README as one less, or drop the archive clause from its off list -> red here; leave
// `explorer.command.run` out of the person-only keys -> red here.
test('the README states the count of the agent actions that ship switched off and carries their clauses', () => {
  const keys = /XData Keys[^\n]*\n\{\n([\s\S]*?)\n\}\n\}/.exec(readFileSync(BASELINE, 'utf8'))?.[1] ?? '';
  const offKeys = [...keys.matchAll(/"([^"]+)": false/g)].map((match) => match[1]);
  assert.equal(offKeys.length, (keys.match(/: false/g) ?? []).length, 'every switched-off line of the baseline is read as a key');
  assert.ok(offKeys.length > 0, 'the baseline lists switched-off keys');
  const index = classIndex();
  const toolClasses = new Map();
  for (const [name, entry] of index) {
    if (name.startsWith('OcuPilot.Test.') || !entry.params.has('TOOLNAME')) continue;
    toolClasses.set(entry.params.get('TOOLNAME'), [...(toolClasses.get(entry.params.get('TOOLNAME')) ?? []), name]);
  }
  const unowned = offKeys.filter((key) => (toolClasses.get(key) ?? []).length !== 1);
  assert.deepEqual(unowned, [], 'each switched-off key is the TOOLNAME of exactly one tool class');
  const personOnly = offKeys.filter((key) => parameterOf(index, toolClasses.get(key)[0], 'ADVERTISED') === '0');
  assert.ok(personOnly.includes('explorer.command.run') && personOnly.includes('explorer.globalnodes.save'), `the person-only keys are read from the tool classes: ${personOnly.join(', ')}`);
  const off = offKeys.length - personOnly.length;
  const readme = readFileSync(README, 'utf8').replace(/\s+/g, ' ');
  assert.ok(readme.includes(`${numberWords(off)} agent actions ship switched off`), `the README says ${numberWords(off)} agent actions ship switched off: the ${offKeys.length} false keys of the baseline less the ${personOnly.length} a person alone runs`);
  assert.ok(
    readme.includes('running SQL that changes data or the schema, clearing an SQL statement\'s run statistics, cleaning out the SQL statements no class or routine still holds, rebuilding one or all of a table\'s indices, removing a table\'s fixed statistics, collecting the statistics of every table in a schema, setting a table\'s extent size, a field\'s selectivity or an index\'s map size, purging the audit database'),
    'the off list names the SQL statement, index, statistics and schema writes'
  );
  assert.ok(
    readme.includes('removing a default setting, a credential, a schedule spec, a workflow user or a workflow role, purging interoperability management data, the business rule log or the business process log, resubmitting, editing and resubmitting or deleting a suspended message, archiving interoperability messages into another namespace, building'),
    'the off list names the purge, the suspended message writes and the archive run'
  );
  assert.ok(
    readme.includes('add, edit and remove schedule specs; keep the purge settings and purge old management data; resubmit, edit and resubmit, discard or delete suspended messages, up to 100 at a time; export up to 100 messages to a file in your browser\'s downloads; keep the archive settings and archive old messages into another interoperability namespace; and add, edit'),
    'the Interoperability paragraph names what a person can do with each'
  );
});
