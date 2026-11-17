/**
 * The command and class method consoles as real least-privileged principals reach them, over the shipped routes, against the
 * throwaway (Story 24.6).
 *
 * `consoles.browser-spec.mjs` drives the screens as the administrator. This file asks the same routes what a person who is not an
 * OcuPilot administrator is allowed to do, and what the agent is allowed to do, with a real account whose role holds exactly the
 * pairs under test (`OcuPilot.Test.TurnWireFixture`, with its role rewritten between tests). What it pins:
 *
 * 1. **AC9, on.** A principal holding `%Development:USE` and WRITE on `USER`'s routines database, and no OcuPilot administration,
 *    runs both consoles with the keys stored `true`.
 * 2. **AC9, the pairs.** The same principal without `%Development:USE`, without WRITE on `USER`'s routines database, and asking
 *    the `HSCUSTOM` namespace it holds no database pair of, is refused 403 `AUTH.NOPRIVILEGE` naming the pair, on both consoles,
 *    with the keys on. The pair check answers before the key does.
 * 3. **AC9, OcuPilot's own state.** The principal's command that calls the kill switch's guarded store by indirection leaves the
 *    switch as it was.
 * 4. **AC6, the agent.** A scripted turn whose model calls either console by its wire name and by its tool name, with the keys on
 *    and a principal who holds every pair, is offered no such tool, gets an unknown-tool answer and mints no proposal.
 * 5. **AC10.** A run writes one `SecurityChange` row that names the console and the namespace, and the command's own text is in
 *    no row.
 *
 * **It runs real commands and class methods, in `USER`, of a class it saves itself** (`OcuProbe246`), so it never runs beside a
 * `ci-runner` call. It removes the class, the principal and its role, and puts the stored governance policy back, and runs only in
 * a throwaway.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1 browser/consoles-principals.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
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
const probe = { container: config.container, marker: 'CNPRINC' };

const NAMESPACE = 'USER';
const COMMAND_KEY = 'explorer.command.run';
const CLASSMETHOD_KEY = 'explorer.classmethod.run';
const COMMAND_PATH = '/api/ocupilot/screens/explorer.command';
const CLASSMETHOD_PATH = '/api/ocupilot/screens/explorer.classmethod';
const TURN_PATH = '/api/ocupilot/turn';
const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
const ECHO = 'OcuProbe246.Echo';

/** What a principal's role holds besides the pairs under test: OcuPilot's own needs, from the instance. */
let baseResources = '';
/** USER's pairs as a role grants them, without the routines database's WRITE. */
const READ_PAIRS = ',%DB_USER:R,%DB_ENSLIB:R,%DB_IRISLIB:R';
const DEV_PAIR = ',%Development:U';
const WRITE_PAIR = ',%DB_USER:RW,%DB_ENSLIB:R,%DB_IRISLIB:R';

const password = `OcuPilotConsoles${randomBytes(12).toString('hex')}Aa9`;
let user = '';
let browser = null;
let preparedId = '';
let priorDefault = '';
let noStoredPolicy = false;

/** One marker from an instance script, as its trimmed text. */
function iris(marker, lines) {
  const output = runIris(config.container, [...lines, `Write "OCU-${marker}-START:"_tValue_":OCU-${marker}-END",!`]);
  return markerValue(output, marker);
}

/** What a principal's own checks answer for one resource and permission, read from the instance. */
function holds(resource, permission) {
  return iris('CNP-HOLDS', [`Set tValue=$SYSTEM.Security.CheckUserPermission("${escapeOs(user)}","${escapeOs(resource)}","${permission}")`]) === '1';
}

/** How many proposals the instance holds for `userName`. */
function proposalCount(userName) {
  return Number(
    iris('CNP-PROPOSALS', [
      `Set tRS=##class(%SQL.Statement).%ExecDirect(,"SELECT COUNT(*) FROM OcuPilot_Kernel_State.Proposal WHERE %EXACT(UserName) = ?","${escapeOs(userName)}")`,
      'Set tValue=$Select(tRS.%Next():tRS.%GetData(1),1:-1)',
    ])
  );
}

/** The kill switch and enforced read-only as the instance holds them now: `<kill switch>|<read-only>`. */
function switchState() {
  return iris('CNP-SWITCH', ['Do ##class(OcuPilot.Kernel.State.Switch).Resolve(.tV)', 'Set tValue=tV("killSwitch")_"|"_tV("enforcedReadOnly")']);
}

/** How many `SecurityChange` rows since `since` name a run of `console`, and the last one's data. */
function runRows(since, console) {
  const text = runIris(config.container, [
    `Set tN=##class(OcuPilot.Test.AuditEvent).RowsCarrying("${since}","SecurityChange","""console"":""${console}""",.tData,"""verb"":""run""")`,
    'Write "OCU-CNP-ROWS-START:"_tN_"|"_tData_":OCU-CNP-ROWS-END",!',
  ]);
  const found = markerValue(text, 'CNP-ROWS');
  assert.ok(found !== null && found.includes('|'), `the audit count was read: ${text.slice(-300)}`);
  const value = found;
  const cut = value.indexOf('|');
  return { count: Number(value.slice(0, cut)), data: value.slice(cut + 1) };
}

/** Give the probe role exactly `resources`, and assert the instance accepted it. */
function setRole(resources) {
  const output = runIris(config.container, [
    `Set tSC=##class(OcuPilot.Test.TurnWireFixture).SetRoleResources("${escapeOs(resources)}")`,
    'Write "OCU-CNP-ROLE-START:"_$System.Status.IsOK(tSC)_":OCU-CNP-ROLE-END",!',
  ]);
  assert.equal(markerValue(output, 'CNP-ROLE'), '1', `the probe role was set: ${output}`);
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

/** The principal's Run of `command` through the Command console's action route, in `namespace`. */
function postCommand(command, namespace = NAMESPACE) {
  return call(`${COMMAND_PATH}/action?ns=${namespace}`, { method: 'POST', body: { action: 'run', id: 'command', values: { command } } });
}

/** The principal's call of `method` of `className` with `args` through the Class method console's action route, in `namespace`. */
function postMethod(className, method, args, namespace = NAMESPACE) {
  return call(`${CLASSMETHOD_PATH}/action?ns=${namespace}`, { method: 'POST', body: { action: 'run', id: 'classmethod', values: { class: className, method, args } } });
}

/** The error envelope's code, wherever the envelope keeps it. */
function codeOf(answer) {
  return answer.body?.error?.code ?? answer.body?.code ?? '';
}

async function keysOn() {
  await setGovernanceKey(COMMAND_KEY, 'enabled');
  await setGovernanceKey(CLASSMETHOD_KEY, 'enabled');
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs code and creates a principal, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  assert.match(config.container, /-ci$/, `this spec runs code and changes the governance policy, so it runs only in a throwaway; ${config.container} is not one`);
  await assertThrowaway(config);
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);

  noStoredPolicy = (await governanceRowVersion()) === 0;
  await resetGovernancePolicy();
  const made = runIris(config.container, [
    `Do ##class(OcuPilot.Test.DevToolProbe).RemoveConsoleProbe("${NAMESPACE}")`,
    `Set tMade=##class(OcuPilot.Test.DevToolProbe).MakeConsoleProbe("${NAMESPACE}")`,
    'Write "OCU-CNP-MAKE-START:"_$System.Status.IsOK(tMade)_":OCU-CNP-MAKE-END",!',
  ]);
  assert.equal(markerValue(made, 'CNP-MAKE'), '1', `the console probe class is saved: ${made}`);

  const resources = runIris(config.container, ['Write "OCU-CNP-RES-START:"_##class(OcuPilot.Test.TurnWireFixture).Resources(1)_":OCU-CNP-RES-END",!']);
  baseResources = markerValue(resources, 'CNP-RES') ?? '';
  assert.ok(baseResources !== '', `the fixture resolved the principal's base resources: ${resources}`);
  const output = runIris(config.container, [
    'Set tUser=##class(OcuPilot.Test.TurnWireFixture).#USERA',
    `Set tSC=##class(OcuPilot.Test.TurnWireFixture).EnsurePrincipal(tUser,"${escapeOs(password)}","${escapeOs(baseResources + DEV_PAIR + WRITE_PAIR)}")`,
    'Write "OCU-CNP-USER-START:"_$System.Status.IsOK(tSC)_"|"_tUser_":OCU-CNP-USER-END",!',
  ]);
  const created = markerValue(output, 'CNP-USER');
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
      await requireFreeSlot(config).catch(() => {});
      if (user !== '') await requireFreeSlot({ ...config, username: user, password }).catch(() => {});
      disarmProbeDefinition(probe, priorDefault);
      const removed = runIris(config.container, [
        `Set tGone=##class(OcuPilot.Test.DevToolProbe).RemoveConsoleProbe("${NAMESPACE}")`,
        'Write "OCU-CNP-GONE-START:"_$System.Status.IsOK(tGone)_":OCU-CNP-GONE-END",!',
        'Write "OCU-CNP-LEFT-START:"_##class(OcuPilot.Test.TurnWireFixture).RemovePrincipals()_":OCU-CNP-LEFT-END",!',
      ]);
      await resetGovernancePolicy();
      if (noStoredPolicy) clearGovernancePolicy(config.container);
      assert.equal(markerValue(removed, 'CNP-GONE'), '1', `the console probe class is removed: ${removed}`);
      assert.equal(markerValue(removed, 'CNP-LEFT'), '', `the probe principal and its role are gone: ${removed}`);
      if (noStoredPolicy) assert.equal(await governanceRowVersion(), 0, 'no governance policy is stored, as before this file ran');
    }
  }
});

// Mutation (Rule 19): ignore the `Gate.Decide` verdict in `ScreenAction.Run` (run when it refuses) -> the off legs go red.
test('off by default: a principal holding every pair is refused 403 with each console\'s own code, and nothing runs', async () => {
  setRole(baseResources + DEV_PAIR + WRITE_PAIR);
  await resetGovernancePolicy();
  for (const [resource, permission] of [['%Development', 'USE'], ['%DB_USER', 'WRITE'], ['%DB_USER', 'READ']]) {
    assert.ok(holds(resource, permission), `the principal holds ${resource}:${permission}`);
  }
  const since = iris('CNP-NOW', ['Set tValue=##class(OcuPilot.Test.AuditEvent).Now()']);
  const command = await postCommand('Write "off"');
  assert.equal(command.status, 403, command.text);
  assert.equal(codeOf(command), 'EXPLORER.COMMAND.OFF', command.text);
  const method = await postMethod(ECHO, 'Echo', '["off"]');
  assert.equal(method.status, 403, method.text);
  assert.equal(codeOf(method), 'EXPLORER.CLASSMETHOD.OFF', method.text);
  assert.equal(runRows(since, 'command').count + runRows(since, 'classmethod').count, 0, 'and no row was written');
});

// Mutation (Rule 19): remove the `AuditRun` call from `DevToolPort.RunConsole` -> the row counts go red; ignore `outputBudget`... not
// visible here, `ConsoleRoundTrip` pins it.
test('AC9 and AC10: with the keys on, the principal runs both consoles with exactly its pairs, and each run writes one row naming no text it typed', async () => {
  setRole(baseResources + DEV_PAIR + WRITE_PAIR);
  await keysOn();
  const since = iris('CNP-NOW', ['Set tValue=##class(OcuPilot.Test.AuditEvent).Now()']);
  const marker = 'OcuMarker246Principal';
  const command = await postCommand(`Write "${marker}"`);
  assert.equal(command.status, 200, command.text);
  assert.equal(command.body.output.output, marker, `the command ran: ${command.text}`);
  const method = await postMethod(ECHO, 'Echo', `["${marker}", {"byRef": true, "value": "x"}]`);
  assert.equal(method.status, 200, method.text);
  assert.equal(method.body.output.returnValue, String(marker.length), `the class method ran: ${method.text}`);
  assert.equal(method.body.output.byRefValues['1'], `${marker}!`, 'and answered its by-reference value');

  const commandRow = runRows(since, 'command');
  assert.equal(commandRow.count, 1, `one row names the command console: ${commandRow.data}`);
  assert.ok(commandRow.data.includes(`"namespace":"${NAMESPACE}"`), `and the namespace: ${commandRow.data}`);
  const methodRow = runRows(since, 'classmethod');
  assert.equal(methodRow.count, 1, `one row names the class method console: ${methodRow.data}`);
  assert.ok(methodRow.data.includes('"class":"OcuProbe246.Echo"') && methodRow.data.includes('"method":"Echo"'), `and the class and the method: ${methodRow.data}`);
  assert.ok(!commandRow.data.includes(marker) && !methodRow.data.includes(marker), 'and neither carries the command, the argument or the answer');
});

// Mutation (Rule 19): make `DevToolPort.Console` ask `NamespacePairs` instead of `WritePairs` -> the second leg goes red; drop
// `%Development:USE` from `AtelierPort.PAIRS` and from the descriptor -> the first leg goes red.
test('AC9, the pairs: without %Development:USE, without WRITE on the routines database, or in a namespace it holds no pair of, a run is refused naming the pair', async () => {
  await keysOn();

  setRole(baseResources + READ_PAIRS + WRITE_PAIR.replace(',%DB_USER:RW', ''));
  assert.equal(holds('%Development', 'USE'), false, 'the principal lacks %Development:USE');
  for (const [label, answer] of [
    ['command', await postCommand('Write 1')],
    ['class method', await postMethod(ECHO, 'Echo', '[]')],
  ]) {
    assert.equal(answer.status, 403, `${label}: ${answer.text}`);
    assert.equal(codeOf(answer), 'AUTH.NOPRIVILEGE', `${label}: ${answer.text}`);
    assert.ok(answer.text.includes('%Development'), `${label}: the pair is named: ${answer.text}`);
  }

  // The pair check answers before the key does: the same principal, with the keys back at their default, is still told its pair.
  await resetGovernancePolicy();
  const noDevOff = await postCommand('Write 1');
  assert.equal(codeOf(noDevOff), 'AUTH.NOPRIVILEGE', `the pair is asked before the key: ${noDevOff.text}`);
  await keysOn();

  setRole(baseResources + DEV_PAIR + READ_PAIRS);
  assert.ok(holds('%Development', 'USE'), 'the principal holds %Development:USE');
  assert.equal(holds('%DB_USER', 'WRITE'), false, 'and has no WRITE on the routines database');
  for (const [label, answer] of [
    ['command', await postCommand('Write 1')],
    ['class method', await postMethod(ECHO, 'Echo', '[]')],
  ]) {
    assert.equal(answer.status, 403, `${label}: ${answer.text}`);
    assert.equal(codeOf(answer), 'AUTH.NOPRIVILEGE', `${label}: ${answer.text}`);
    assert.ok(answer.text.includes('%DB_USER'), `${label}: the routines database's resource is named: ${answer.text}`);
  }

  setRole(baseResources + DEV_PAIR + WRITE_PAIR);
  assert.equal(holds('%DB_HSCUSTOM', 'WRITE'), false, 'the principal holds no WRITE on HSCUSTOM\'s routines database');
  for (const [label, answer] of [
    ['command', await postCommand('Write 1', 'HSCUSTOM')],
    ['class method', await postMethod(ECHO, 'Echo', '[]', 'HSCUSTOM')],
  ]) {
    assert.equal(answer.status, 403, `${label}: ${answer.text}`);
    assert.equal(codeOf(answer), 'AUTH.NOPRIVILEGE', `${label}: ${answer.text}`);
    assert.ok(answer.text.includes('%DB_HSCUSTOM'), `${label}: HSCUSTOM's database is named: ${answer.text}`);
  }
});

// Dropping the `AdminWriteRefused` guard from `Switch.SetGuarded` alone leaves this green: the principal also holds no write on OcuPilot's data, which the instance refuses.
test("AC9, OcuPilot's own state: a command that calls the kill switch's guarded store by indirection leaves the switch as it was", async () => {
  // OcuPilot's classes are visible in HSCUSTOM alone, so the command runs there, and the principal holds that namespace's pairs too.
  setRole(baseResources.split(',').filter((entry) => !entry.startsWith('%DB_HSCUSTOM:')).join(',') + DEV_PAIR + WRITE_PAIR + ',%DB_HSCUSTOM:RW');
  await keysOn();
  const before = switchState();
  const command = await postCommand(
    'Set tValue("killSwitch")=1,tValue("enforcedReadOnly")=1 Set tSC=$ClassMethod("Ocu"_"Pilot.Kernel.State.Switch","SetGuarded",.tValue) Write $System.Status.IsOK(tSC)',
    'HSCUSTOM'
  );
  assert.equal(command.status, 200, command.text);
  assert.equal(command.body.output.error, '', `the command reached the guarded store: ${command.text}`);
  assert.equal(command.body.output.output, '0', `and the guarded store refused the principal: ${command.text}`);
  assert.equal(switchState(), before, "OcuPilot's switches are as they were");
});

/** What the instance recorded for provider call `call` of `tag` under `field`, parsed. */
function recorded(tag, callIndex, field) {
  const output = runIris(config.container, [
    `Write "OCU-CNP-REC-START:"_##class(OcuPilot.Test.TurnProvider).Recorded("${escapeOs(tag)}",${callIndex},"${field}")_":OCU-CNP-REC-END",!`,
  ]);
  const value = markerValue(output, 'CNP-REC');
  assert.ok(value, `Recorded answered: ${output}`);
  return JSON.parse(value);
}

// Mutation (Rule 19): make `ExplorerCommandRun` `ADVERTISED 1` -> the offered-tools assertion goes red; make the registry resolve the
// tool for the agent's dispatch -> the tool-result assertion goes red.
test('the agent: a scripted turn is offered neither console, a call of either by either name is unknown, and no proposal results', async () => {
  setRole(baseResources + DEV_PAIR + WRITE_PAIR);
  // The strongest position for the agent: the keys are on and the person it acts for holds every pair.
  await keysOn();
  await requireFreeSlot(config);
  await requireFreeSlot({ ...config, username: user, password });
  const proposalsBefore = proposalCount(user);
  const calls = [
    ['toolu_cmd_wire', 'explorer_command_run', { Target: 'command', Command: 'Write 1' }],
    ['toolu_cmd_dotted', 'explorer.command.run', { Target: 'command', Command: 'Write 1' }],
    ['toolu_method_wire', 'explorer_classmethod_run', { Target: 'classmethod', Class: ECHO, Method: 'Echo', Arguments: '[]' }],
    ['toolu_method_dotted', 'explorer.classmethod.run', { Target: 'classmethod', Class: ECHO, Method: 'Echo', Arguments: '[]' }],
  ];
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  scriptReply(
    probe,
    tag,
    0,
    `##class(OcuPilot.Test.TurnProvider).ToolUseReply([${calls.map(([id, name, input]) => `{"id": "${id}", "name": "${name}", "input": ${JSON.stringify(input)}}`).join(', ')}])`
  );
  scriptReply(probe, tag, 0, '##class(OcuPilot.Test.TurnProvider).TextReply("I could not run those.")');

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
    await page.type('#ocu-panel-composer', 'run the command Write 1');
    const [started] = await Promise.all([
      page.waitForResponse((response) => response.request().method() === 'POST' && new URL(response.url()).pathname === TURN_PATH, { timeout: config.navigationTimeoutMs }),
      page.click('.ocu-panel-send'),
    ]);
    assert.equal(started.status(), 202, `the instance started the turn: ${await started.text()}`);
    // The turn's second provider call is the reply to the refused calls; once it has been made the turn has handled them.
    const deadline = Date.now() + config.navigationTimeoutMs;
    const callCount = () => Number(iris('CNP-CALLS', [`Set tValue=##class(OcuPilot.Test.TurnProvider).Calls("${escapeOs(tag)}")`]));
    while (callCount() < 2) {
      assert.ok(Date.now() < deadline, 'the turn made its second provider call');
      await new Promise((resolve) => setTimeout(resolve, 500));
    }

    const names = recorded(tag, 1, 'tools').map((tool) => tool.name);
    assert.ok(names.length > 0, `the provider was offered tools: ${names.length}`);
    assert.deepEqual(
      names.filter((name) => /^explorer[_.](command|classmethod)/.test(name)),
      [],
      'and none of the consoles'
    );

    const results = recorded(tag, 2, 'messages').flatMap((entry) => (Array.isArray(entry.content) ? entry.content : []));
    for (const [id] of calls) {
      const block = results.find((entry) => entry.type === 'tool_result' && entry.tool_use_id === id);
      assert.ok(block, `the turn answered ${id}: ${JSON.stringify(results).slice(0, 600)}`);
      assert.equal(block.is_error, true, `${id} was refused`);
      assert.ok(/TOOL\.UNKNOWN|PROHIBITED\.PERSONONLY/.test(String(block.content)), `${id} is unknown or person-only: ${String(block.content)}`);
    }
    assert.equal(proposalCount(user), proposalsBefore, 'no proposal was minted');
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});
