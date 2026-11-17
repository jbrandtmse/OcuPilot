/**
 * The unit-test runner as real least-privileged principals reach it, over the shipped routes, against the throwaway (Story 24.5).
 *
 * `unit-tests.browser-spec.mjs` drives the screen and the route as the administrator. This file asks the same route what a
 * person who is not an administrator is allowed to do, and what the agent is allowed to do, with a real account whose role holds
 * exactly the pairs under test (`OcuPilot.Test.TurnWireFixture`, with its role rewritten between tests). What it pins:
 *
 * 1. **Off by default.** A principal holding every pair, with the governance key at its shipped `false`, is refused 403
 *    `EXPLORER.UNITTEST.OFF`, and nothing runs. The preview routes (`/impact`, `/dryrun`) never run anything either.
 * 2. **On.** With the key stored `true` the same principal runs a class, the record shows the run, and USER's root global and the
 *    run lock are as they were.
 * 3. **The pairs.** A principal without `%Development:USE`, and one without WRITE on USER's routines database, is refused 403
 *    `AUTH.NOPRIVILEGE` naming the pair even with the key on, and no run is added. The pair check answers before the key does.
 * 4. **The refusal rows.** Production, not found, bad shape and `OcuPilot` code answer their status and code over the real route,
 *    each leaving the record, the root global and the lock as they were.
 * 5. **Busy.** A run lock held by another process refuses 409 `EXPLORER.UNITTEST.BUSY`, and the run works once it is released.
 * 6. **The agent.** A scripted turn whose model calls the run by its wire name and by its tool name, with the key on and a
 *    principal who holds every pair, is offered no such tool, gets an unknown-tool answer, mints no proposal and adds no run.
 *
 * **It runs real `%UnitTest` runs, in `USER`, of classes it saves itself** (`OcuProbe245`, `OcuProbe245P`), so it never runs beside
 * a `ci-runner` call. It removes the classes, the runs it added, the principal and its role, puts the result counter and the
 * stored governance policy back, and runs only in a throwaway.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1 browser/unit-tests-principals.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { resetRememberedState, governanceRowVersion, resetGovernancePolicy, setGovernanceKey } from './preferences-reset.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { assertThrowaway } from './structural-walk.mjs';
import {
  armProbeDefinition,
  clearGovernancePolicy,
  disarmProbeDefinition,
  escapeOs,
  forgetTag,
  markerValue,
  nextTag,
  requireFreeSlot,
  runIris,
  scriptReply,
  setTag,
} from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const probe = { container: config.container, marker: 'UTPRINC' };

const NAMESPACE = 'USER';
const KEY = 'explorer.unittests.run';
const SCREEN_PATH = '/api/ocupilot/screens/explorer.unittests';
const METHODS_PATH = '/api/ocupilot/screens/explorer.unittestrun';
const TURN_PATH = '/api/ocupilot/turn';
const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
const MIXED = 'OcuProbe245.Mixed';
const LOCK_FLAG = '^IRIS.Temp.OcuQA245Hold';
const LOCK_NAME = '^CacheTemp.OcuPilotUnitTestRun';

/** What a principal's role holds besides the pairs under test: OcuPilot's own needs, from the instance. */
let baseResources = '';
/** USER's pairs as a role grants them, without the routines database's WRITE. */
const READ_PAIRS = ',%DB_USER:R,%DB_ENSLIB:R,%DB_IRISLIB:R';
const DEV_PAIR = ',%Development:U';
const WRITE_PAIR = ',%DB_USER:RW,%DB_ENSLIB:R,%DB_IRISLIB:R';

const password = `OcuPilotUnitTests${randomBytes(12).toString('hex')}Aa9`;
let user = '';
let browser = null;
let preparedId = '';
let priorDefault = '';
let noStoredPolicy = false;
let baseline = 0;
let hadCounter = false;
let counterWas = '';

/** One marker from an instance script, as its trimmed text. */
function iris(marker, lines) {
  const output = runIris(config.container, [...lines, `Write "OCU-${marker}-START:"_tValue_":OCU-${marker}-END",!`]);
  return markerValue(output, marker);
}

/** The newest run `USER` records, as its index, or 0. */
function newestRun() {
  return Number(iris('UTP-NEWEST', [`Set tValue=+$Order(^|"${NAMESPACE}"|UnitTest.Result(""),-1)`]));
}

/** `USER`'s unit-test root global as `<has a value>|<value>`. */
function rootState() {
  return iris('UTP-ROOT', [`Set tValue=($Data(^|"${NAMESPACE}"|UnitTestRoot)#2)_"|"_$Get(^|"${NAMESPACE}"|UnitTestRoot)`]);
}

/** Whether the run lock is free: taken and released by a process of its own. */
function lockIsFree() {
  return iris('UTP-LOCK', [`Lock +${LOCK_NAME}:0`, 'Set tValue=$Test', `Lock -${LOCK_NAME}`]) === '1';
}

/** What a principal's own checks answer for one resource and permission, read from the instance. */
function holds(resource, permission) {
  return iris('UTP-HOLDS', [`Set tValue=$SYSTEM.Security.CheckUserPermission("${escapeOs(user)}","${escapeOs(resource)}","${permission}")`]) === '1';
}

/** How many proposals the instance holds for `userName`. */
function proposalCount(userName) {
  return Number(
    iris('UTP-PROPOSALS', [
      `Set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(UserName) = ?","${escapeOs(userName)}")`,
      'Set tValue=$Select(tRS.%Next():tRS.%GetData(1),1:-1)',
    ])
  );
}

/** Give the probe role exactly `resources`, and assert the instance accepted it. */
function setRole(resources) {
  const output = runIris(config.container, [
    `Set tSC=##class(OcuPilot.Test.TurnWireFixture).SetRoleResources("${escapeOs(resources)}")`,
    'Write "OCU-UTP-ROLE-START:"_$System.Status.IsOK(tSC)_":OCU-UTP-ROLE-END",!',
  ]);
  assert.equal(markerValue(output, 'UTP-ROLE'), '1', `the probe role was set: ${output}`);
}

/** The state every refusal leaves alone: the newest run, the root global and the lock. */
function untouched() {
  return { run: newestRun(), root: rootState(), lockFree: lockIsFree() };
}

function basic(name, secret) {
  return `Basic ${Buffer.from(`${name}:${secret}`).toString('base64')}`;
}

/** The principal's request; answers the status and the parsed body (null when it is not JSON). */
async function call(path, { method = 'GET', body = null } = {}) {
  const answer = await fetch(`${config.origin}${path}`, {
    method,
    headers: { Authorization: basic(user, password), ...(body === null ? {} : { 'Content-Type': 'application/json' }) },
    body: body === null ? undefined : JSON.stringify(body),
  });
  const text = await answer.text();
  let parsed = null;
  try {
    parsed = JSON.parse(text);
  } catch {
    // A body that is not JSON stays null, and the assertion that reads it names the text.
  }
  return { status: answer.status, body: parsed, text };
}

/** The principal's Run of `tests` at `level` through the screen action route. */
function postRun(tests, level, action = 'action') {
  return call(`${SCREEN_PATH}/${action}?ns=${NAMESPACE}`, { method: 'POST', body: { action: 'run', id: 'unittests', values: { tests, level } } });
}

/** The error envelope's code, wherever the envelope keeps it. */
function codeOf(answer) {
  return answer.body?.error?.code ?? answer.body?.code ?? '';
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs unit tests and creates a principal, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  assert.match(config.container, /-ci$/, `this spec runs tests and changes the governance policy, so it runs only in a throwaway; ${config.container} is not one`);
  await assertThrowaway(config);
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);

  noStoredPolicy = (await governanceRowVersion()) === 0;
  await resetGovernancePolicy();
  hadCounter = iris('UTP-COUNTER', [`Set tValue=$Data(^|"${NAMESPACE}"|UnitTest.Result)#2`]) === '1';
  counterWas = hadCounter ? iris('UTP-COUNTERVALUE', [`Set tValue=$Get(^|"${NAMESPACE}"|UnitTest.Result)`]) : '';
  baseline = newestRun();
  const made = runIris(config.container, [
    `Do ##class(OcuPilot.Test.DevToolProbe).RemoveTests("${NAMESPACE}")`,
    `Set tMade=##class(OcuPilot.Test.DevToolProbe).MakeTests("${NAMESPACE}")`,
    'Write "OCU-UTP-MAKE-START:"_$System.Status.IsOK(tMade)_":OCU-UTP-MAKE-END",!',
  ]);
  assert.equal(markerValue(made, 'UTP-MAKE'), '1', `the probe test classes are saved: ${made}`);

  const resources = runIris(config.container, ['Write "OCU-UTP-RES-START:"_##class(OcuPilot.Test.TurnWireFixture).Resources(1)_":OCU-UTP-RES-END",!']);
  baseResources = markerValue(resources, 'UTP-RES') ?? '';
  assert.ok(baseResources !== '', `the fixture resolved the principal's base resources: ${resources}`);
  const output = runIris(config.container, [
    'Set tUser=##class(OcuPilot.Test.TurnWireFixture).#USERA',
    `Set tSC=##class(OcuPilot.Test.TurnWireFixture).EnsurePrincipal(tUser,"${escapeOs(password)}","${escapeOs(baseResources + DEV_PAIR + WRITE_PAIR)}")`,
    'Write "OCU-UTP-USER-START:"_$System.Status.IsOK(tSC)_"|"_tUser_":OCU-UTP-USER-END",!',
  ]);
  const created = markerValue(output, 'UTP-USER');
  assert.ok(created, `EnsurePrincipal answered: ${output}`);
  const [ok, name] = created.split('|');
  assert.equal(ok, '1', `the fixture created the principal: ${output}`);
  user = name;

  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (/-ci$/.test(config.container)) {
      // A holder a failed test left running releases on its flag.
      runIris(config.container, [`Kill ${LOCK_FLAG}`]);
      await requireFreeSlot(config).catch(() => {});
      if (user !== '') await requireFreeSlot({ ...config, username: user, password }).catch(() => {});
      disarmProbeDefinition(probe, priorDefault);
      const added = newestRun();
      const removed = runIris(config.container, [
        `For tI=${baseline + 1}:1:${Math.max(added, baseline)} Do ##class(OcuPilot.Test.DevToolProbe).RemoveRun("${NAMESPACE}",tI)`,
        `Set tGone=##class(OcuPilot.Test.DevToolProbe).RemoveTests("${NAMESPACE}")`,
        hadCounter ? `Set ^|"${NAMESPACE}"|UnitTest.Result=${JSON.stringify(counterWas)}` : `Kill ^|"${NAMESPACE}"|UnitTest.Result`,
        'Write "OCU-UTP-GONE-START:"_$System.Status.IsOK(tGone)_":OCU-UTP-GONE-END",!',
        'Write "OCU-UTP-LEFT-START:"_##class(OcuPilot.Test.TurnWireFixture).RemovePrincipals()_":OCU-UTP-LEFT-END",!',
      ]);
      await resetGovernancePolicy();
      if (noStoredPolicy) clearGovernancePolicy(config.container);
      assert.equal(markerValue(removed, 'UTP-GONE'), '1', `the probe test classes and the runs are removed: ${removed}`);
      assert.equal(markerValue(removed, 'UTP-LEFT'), '', `the probe principal and its role are gone: ${removed}`);
      if (noStoredPolicy) assert.equal(await governanceRowVersion(), 0, 'no governance policy is stored, as before this file ran');
    }
  }
});

// Mutation (Rule 19): ignore the `Gate.Decide` verdict in `ScreenAction.Run` (run when it refuses) -> the first assertion goes red;
// answer `Hold` before the key ask -> not detectable here, `UnitTestRunGate` pins the order.
test('off by default: a principal holding every pair is refused 403 EXPLORER.UNITTEST.OFF, and the previews run nothing', async () => {
  setRole(baseResources + DEV_PAIR + WRITE_PAIR);
  await resetGovernancePolicy();
  for (const [resource, permission] of [['%Development', 'USE'], ['%DB_USER', 'WRITE'], ['%DB_USER', 'READ']]) {
    assert.ok(holds(resource, permission), `the principal holds ${resource}:${permission}`);
  }
  const before = untouched();
  const refused = await postRun(MIXED, 'class');
  assert.equal(refused.status, 403, refused.text);
  assert.equal(codeOf(refused), 'EXPLORER.UNITTEST.OFF', refused.text);
  assert.ok(refused.text.includes(STRINGS.explorerUnitTestOffReason), `the instance's own sentence: ${refused.text}`);

  // A preview of this action answers before the key is asked or not at all; either way it runs nothing and records nothing.
  const impact = await call(`${SCREEN_PATH}/impact?ns=${NAMESPACE}&action=run&id=unittests&value=${encodeURIComponent(MIXED)}`);
  assert.notEqual(impact.status, 200, `a preview of the run does not answer as a success: ${impact.text}`);
  const dryRun = await postRun(MIXED, 'class', 'dryrun');
  assert.notEqual(dryRun.status, 200, `a dry run of the run does not answer as a success: ${dryRun.text}`);
  assert.deepEqual(untouched(), before, 'no run was added, the root global is as it was and the lock is free');
});

// Mutation (Rule 19): drop the `PERSONGATE` ask's `If 'tDecision("allowed")` refusal in `ScreenAction.Run` -> the key-off test above
// goes red and the principal's run lands; skip the root restore in `DevToolPort.RootEnd` -> the root assertion goes red.
test('on: the same principal runs a class, the record shows it, and the root global and the lock are as they were', async () => {
  setRole(baseResources + DEV_PAIR + WRITE_PAIR);
  await setGovernanceKey(KEY, 'enabled');
  const before = untouched();
  const ran = await postRun(MIXED, 'class');
  assert.equal(ran.status, 200, ran.text);
  assert.deepEqual([ran.body.output.passed, ran.body.output.failed], [1, 1], `the class ran both methods: ${ran.text}`);
  const run = ran.body.output.run;
  assert.equal(run, before.run + 1, 'one new run');
  const after = untouched();
  assert.equal(after.run, run, 'the record holds it');
  assert.equal(after.root, before.root, "USER's root global is as it was");
  assert.ok(after.lockFree, 'and the lock was let go');

  // The run record, read as the principal through both screens' shipped read routes.
  const runs = await call(`${SCREEN_PATH}/read?ns=${NAMESPACE}`);
  assert.equal(runs.status, 200, runs.text);
  const first = runs.body.rows[0];
  assert.ok(JSON.stringify(first).includes(`${run}`), `the newest run heads the runs list: ${JSON.stringify(first)}`);
  const methods = await call(`${METHODS_PATH}/read?ns=${NAMESPACE}&run=${run}`);
  assert.equal(methods.status, 200, methods.text);
  assert.equal(methods.body.rows.length, 2, `the run's methods list holds both methods: ${methods.text}`);
  assert.ok(methods.text.includes('the probe assertion that fails'), 'and the failed one carries its assertion');
});

// Mutation (Rule 19): build a package's spec with `BuildTestSpec` instead of the port's `classes` in `UnitTestRun.Run` -> the
// package leg answers 0 and 0 and goes red; put the checked statement back in `DevToolPort.ResolveTests` -> the package leg
// answers 500 INTERNAL.
test('a package and a method run as the principal, who holds no SQL privilege, answer their counts and record their methods', async () => {
  setRole(baseResources + DEV_PAIR + WRITE_PAIR);
  await setGovernanceKey(KEY, 'enabled');
  const before = untouched();
  const pack = await postRun('OcuProbe245', 'package');
  assert.equal(pack.status, 200, pack.text);
  assert.deepEqual([pack.body.output.passed, pack.body.output.failed], [1, 1], `the package ran both methods of its test class: ${pack.text}`);
  const method = await postRun(`${MIXED}:TestPasses`, 'method');
  assert.equal(method.status, 200, method.text);
  assert.deepEqual([method.body.output.passed, method.body.output.failed], [1, 0], `one method ran and passed: ${method.text}`);
  assert.equal(method.body.output.run, pack.body.output.run + 1, 'each is a new run');
  const methods = await call(`${METHODS_PATH}/read?ns=${NAMESPACE}&run=${pack.body.output.run}`);
  assert.equal(methods.body.rows.length, 2, `the package run's record holds both methods: ${methods.text}`);
  const after = untouched();
  assert.equal(after.root, before.root, "USER's root global is as it was");
  assert.ok(after.lockFree, 'and the lock was let go');
});

// Mutation (Rule 19): make `DevToolPort`'s `WritePairs` ask for READ only on the routines database -> the second leg goes red;
// drop `%Development:USE` from `AtelierPort.PAIRS` and from the descriptor -> the first leg goes red.
test('the pairs: without %Development:USE or without WRITE on the routines database a run is refused naming the pair, key on', async () => {
  await setGovernanceKey(KEY, 'enabled');
  const before = untouched();

  setRole(baseResources + READ_PAIRS + WRITE_PAIR.replace(',%DB_USER:RW', ''));
  assert.equal(holds('%Development', 'USE'), false, 'the principal lacks %Development:USE');
  assert.ok(holds('%DB_USER', 'WRITE') === false && holds('%DB_USER', 'READ'), 'and has USER only to read');
  const noDev = await postRun(MIXED, 'class');
  assert.equal(noDev.status, 403, noDev.text);
  assert.equal(codeOf(noDev), 'AUTH.NOPRIVILEGE', noDev.text);
  assert.ok(noDev.text.includes('%Development'), `the pair is named: ${noDev.text}`);

  // The pair check answers before the key does: the same principal, with the key back at its default, is still told its pair.
  await resetGovernancePolicy();
  const noDevOff = await postRun(MIXED, 'class');
  assert.equal(noDevOff.status, 403, noDevOff.text);
  assert.equal(codeOf(noDevOff), 'AUTH.NOPRIVILEGE', `the pair is asked before the key: ${noDevOff.text}`);
  await setGovernanceKey(KEY, 'enabled');

  setRole(baseResources + DEV_PAIR + READ_PAIRS);
  assert.ok(holds('%Development', 'USE'), 'the principal holds %Development:USE');
  assert.equal(holds('%DB_USER', 'WRITE'), false, 'and has no WRITE on the routines database');
  const noWrite = await postRun(MIXED, 'class');
  assert.equal(noWrite.status, 403, noWrite.text);
  assert.equal(codeOf(noWrite), 'AUTH.NOPRIVILEGE', noWrite.text);
  assert.ok(noWrite.text.includes('%DB_USER'), `the routines database's resource is named: ${noWrite.text}`);
  assert.deepEqual(untouched(), before, 'no run was added, the root global is as it was and the lock is free');
});

// Mutation (Rule 19): move the production check after the body in `DevToolPort.UnitTest` -> the production rows go red;
// drop the `ocupilot` stem refusal -> the own-code rows go red.
test('the refusal rows over the real route: production, not found, bad shape and own code leave the record, the root and the lock alone', async () => {
  setRole(baseResources + DEV_PAIR + WRITE_PAIR);
  await setGovernanceKey(KEY, 'enabled');
  const before = untouched();
  const rows = [
    ['OcuProbe245P.Prod', 'class', 409, 'EXPLORER.UNITTEST.PRODUCTION'],
    ['OcuProbe245P', 'package', 409, 'EXPLORER.UNITTEST.PRODUCTION'],
    ['OcuProbe245.Missing', 'class', 404, 'EXPLORER.UNITTEST.NOTFOUND'],
    [`${MIXED}:TestMissing`, 'method', 404, 'EXPLORER.UNITTEST.NOTFOUND'],
    ['OcuProbe245None', 'package', 404, 'EXPLORER.UNITTEST.NOTFOUND'],
    ['Ens.Util.Time', 'class', 404, 'EXPLORER.UNITTEST.NOTFOUND'],
    ['%Library', 'package', 400, 'PORT.VALIDATION'],
    ['a..b', 'class', 400, 'PORT.VALIDATION'],
    ['A:B:C', 'method', 400, 'PORT.VALIDATION'],
    ['*', 'package', 400, 'PORT.VALIDATION'],
    ['OcuPilot.Test.UnitTestRecord', 'class', 400, 'EXPLORER.UNITTEST.OWNCODE'],
    ['ocupilot', 'package', 400, 'EXPLORER.UNITTEST.OWNCODE'],
    ['OCUPILOT.Test.Anything', 'class', 400, 'EXPLORER.UNITTEST.OWNCODE'],
  ];
  for (const [tests, level, status, code] of rows) {
    const answer = await postRun(tests, level);
    assert.equal(answer.status, status, `${tests} (${level}): ${answer.text}`);
    assert.equal(codeOf(answer), code, `${tests} (${level}): ${answer.text}`);
  }
  const badLevel = await postRun(MIXED, 'suite');
  assert.equal(badLevel.status, 400, `a level outside the three: ${badLevel.text}`);
  assert.deepEqual(untouched(), before, 'no row added a run, moved the root global or kept the lock');
});

/** Hold the run lock in a process of its own until `release` is called; answers the release. */
async function holdRunLock() {
  runIris(config.container, [`Kill ${LOCK_FLAG}`]);
  const script = [`Lock +${LOCK_NAME}:5`, `If $Test { Set ${LOCK_FLAG}=1 For tI=1:1:300 { Quit:'$Data(${LOCK_FLAG})  Hang 0.2 } }`, `Lock -${LOCK_NAME}`, 'Halt'].join('\n');
  const child = spawn('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], { stdio: ['pipe', 'ignore', 'ignore'] });
  const exited = new Promise((resolve) => child.on('exit', resolve));
  child.stdin.end(`${script}\n`);
  const deadline = Date.now() + 30000;
  while (iris('UTP-HELD', [`Set tValue=$Data(${LOCK_FLAG})#2`]) !== '1') {
    assert.ok(Date.now() < deadline, 'the holding process took the lock');
    await new Promise((resolve) => setTimeout(resolve, 300));
  }
  assert.equal(lockIsFree(), false, 'the lock is held by another process');
  return async () => {
    runIris(config.container, [`Kill ${LOCK_FLAG}`]);
    await Promise.race([exited, new Promise((resolve) => setTimeout(resolve, 20000))]);
  };
}

// Mutation (Rule 19): drop the lock take in `DevToolPort`'s run path -> the Busy leg answers 200 and goes red; keep the lock after a
// refusal -> the run after the release goes red.
test('busy: a run lock held by another process refuses 409 EXPLORER.UNITTEST.BUSY, and the run works once it is released', async () => {
  setRole(baseResources + DEV_PAIR + WRITE_PAIR);
  await setGovernanceKey(KEY, 'enabled');
  const before = untouched();
  const release = await holdRunLock();
  try {
    const busy = await postRun(MIXED, 'class');
    assert.equal(busy.status, 409, busy.text);
    assert.equal(codeOf(busy), 'EXPLORER.UNITTEST.BUSY', busy.text);
    assert.equal(newestRun(), before.run, 'no run was added while it was held');
    assert.equal(rootState(), before.root, 'and the root global is as it was');
  } finally {
    await release();
  }
  assert.ok(lockIsFree(), 'the lock is free once its holder lets go');
  const ran = await postRun(`${MIXED}:TestPasses`, 'method');
  assert.equal(ran.status, 200, `the refusal kept nothing: ${ran.text}`);
  assert.equal(ran.body.output.passed, 1);
});

/** What the instance recorded for provider call `call` of `tag` under `field`, parsed. */
function recorded(tag, call, field) {
  const output = runIris(config.container, [
    `Write "OCU-UTP-REC-START:"_##class(OcuPilot.Test.TurnProvider).Recorded("${escapeOs(tag)}",${call},"${field}")_":OCU-UTP-REC-END",!`,
  ]);
  const value = markerValue(output, 'UTP-REC');
  assert.ok(value, `Recorded answered: ${output}`);
  return JSON.parse(value);
}

// Mutation (Rule 19): make `ExplorerUnitTestRun` `ADVERTISED 1` -> the offered-tools assertion goes red; make the registry resolve the
// tool for the agent's dispatch -> the tool-result assertion goes red and a run is added.
test('the agent: a scripted turn is offered no run tool, a call of it by either name is unknown, and no proposal or run results', async () => {
  setRole(baseResources + DEV_PAIR + WRITE_PAIR);
  // The strongest position for the agent: the key is on and the person it acts for holds every pair.
  await setGovernanceKey(KEY, 'enabled');
  await requireFreeSlot(config);
  await requireFreeSlot({ ...config, username: user, password });
  const proposalsBefore = proposalCount(user);
  const runBefore = newestRun();
  const input = { tests: MIXED, level: 'class' };
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  scriptReply(
    probe,
    tag,
    0,
    `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_wire", "name": "explorer_unittests_run", "input": ${JSON.stringify(input)}}, {"id": "toolu_dotted", "name": "explorer.unittests.run", "input": ${JSON.stringify(input)}}])`
  );
  scriptReply(probe, tag, 0, '##class(OcuPilot.Test.TurnProvider).TextReply("I could not run those tests.")');

  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.setViewport(config.viewport);
  try {
    await page.goto(`${config.origin}${HOME_URL}`, { waitUntil: 'networkidle2' });
    await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('#ocu-signin-user', user);
    await page.type('#ocu-signin-password', password);
    await page.click('.ocu-signin-card button[type="submit"]');
    await page.waitForSelector('app-panel aside.ocu-panel', { timeout: config.navigationTimeoutMs });
    await leaveFirstLoginGate(page, config.navigationTimeoutMs, HOME_URL);
    await page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), { timeout: config.navigationTimeoutMs });
    await page.type('#ocu-panel-composer', 'run the unit tests in OcuProbe245.Mixed');
    const [started] = await Promise.all([
      page.waitForResponse((response) => response.request().method() === 'POST' && new URL(response.url()).pathname === TURN_PATH, { timeout: config.navigationTimeoutMs }),
      page.click('.ocu-panel-send'),
    ]);
    assert.equal(started.status(), 202, `the instance started the turn: ${await started.text()}`);
    // The turn's second provider call is the reply to both refused calls; once it has been made the turn has handled them.
    const deadline = Date.now() + config.navigationTimeoutMs;
    const callCount = () => Number(iris('UTP-CALLS', [`Set tValue=##class(OcuPilot.Test.TurnProvider).Calls("${escapeOs(tag)}")`]));
    while (callCount() < 2) {
      assert.ok(Date.now() < deadline, 'the turn made its second provider call');
      await new Promise((resolve) => setTimeout(resolve, 500));
    }

    const tools = recorded(tag, 1, 'tools');
    const names = tools.map((tool) => tool.name);
    assert.ok(names.length > 0 && names.some((name) => name.startsWith('explorer_unittests')), `the provider was offered the unit-test read tools: ${names.length} tools`);
    assert.deepEqual(
      names.filter((name) => /unittests?[_.]run$/.test(name)),
      [],
      'and no tool that runs them'
    );

    const messages = JSON.stringify(recorded(tag, 2, 'messages'));
    for (const id of ['toolu_wire', 'toolu_dotted']) {
      const block = recorded(tag, 2, 'messages')
        .flatMap((entry) => (Array.isArray(entry.content) ? entry.content : []))
        .find((entry) => entry.type === 'tool_result' && entry.tool_use_id === id);
      assert.ok(block, `the turn answered ${id}: ${messages}`);
      assert.equal(block.is_error, true, `${id} was refused`);
      assert.ok(/TOOL\.UNKNOWN|PROHIBITED\.PERSONONLY/.test(String(block.content)), `${id} is unknown or person-only: ${String(block.content)}`);
    }
    assert.equal(proposalCount(user), proposalsBefore, 'no proposal was minted');
    assert.equal(newestRun(), runBefore, 'and no run was added');
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});
