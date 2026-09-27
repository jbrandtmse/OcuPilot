/**
 * Home's Findings panel in a real browser against the throwaway instance (Story 16.21).
 *
 * - **AC1 and AC5.** For the suite's own account the panel follows the performance row with its
 *   Security and Operations groups; it names a seeded unauthenticated application holding
 *   `%DB_USER`, the stock `/csp/user` and `/api/monitor`, every open application the instance's own
 *   answer lists, the demo fixture's task
 *   suspended after an error and the four `%All` accounts a stock install carries, and
 *   not `/ocupilot` or a task a person suspended. The panel passes the DW-1337 structural gate in
 *   light, narrow and dark with no new baseline entry.
 * - **AC2.** `_SYSTEM`'s line shows the prohibited set's sentence and no Fix it.
 * - **AC3.** Fix it on the demo task opens Task details on it; the scripted turn's user message is
 *   the fixed sentence, its screen context names the task and carries its row, and the proposal
 *   card appears with Confirm. Nothing is confirmed, so the task stays suspended.
 * - **AC4.** A principal without `%Admin_Secure:USE` sees "Not checked" lines naming that pair.
 *
 * **It creates a web application and a security principal**, so it refuses the live container and
 * any container that is not a throwaway; `after` removes both and the probe definition whether or
 * not a test failed.
 *
 * Run: `npm run build`, redeploy the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/home-findings.browser-spec.mjs`
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { randomBytes } from 'node:crypto';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { signedInAt } from './panel-spec.mjs';
import { resetRememberedState } from './preferences-reset.mjs';
import { INVARIANTS, VIEWPORTS, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import {
  armProbeDefinition,
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

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const probe = { container: config.container, marker: 'FINDINGS' };
const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
const HOME_ROUTE_KEY = '/';
const FINDINGS_PATH = '/api/ocupilot/ui/findings';
const TASK_ROUTE = 'tasks/schedule/details';

const PROBE_APP = '/csp/ocufindings1621';
const PROBE_MARKER = 'OcuPilot findings browser probe (throwaway)';
const LOW_USER = 'OcuFindingsBrowserLow';
const LOW_ROLE = 'OcuFindingsBrowserLowRole';
const LOW_PASSWORD = `Ocu${randomBytes(12).toString('hex')}a1`;

let browser = null;
let preparedId = '';
let priorDefault = '';

const fill = (template, values) => Object.entries(values).reduce((out, [key, value]) => out.split(`<${key}>`).join(value), template);

function inSys(lines, names) {
  const output = runIris(config.container, ['Set $NAMESPACE="%SYS"', ...lines]);
  const values = {};
  for (const name of names) values[name] = markerValue(output, name);
  return { values, output };
}

const mark = (name, expression) => `Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`;

function removeSeeds() {
  return inSys(
    [
      `If ##class(Security.Applications).Exists("${PROBE_APP}",.a),a.Description="${escapeOs(PROBE_MARKER)}" Kill a Do ##class(Security.Applications).Delete("${PROBE_APP}")`,
      `If ##class(Security.Users).Exists("${LOW_USER}") Do ##class(Security.Users).Delete("${LOW_USER}")`,
      `If ##class(Security.Roles).Exists("${LOW_ROLE}") Do ##class(Security.Roles).Delete("${LOW_ROLE}")`,
      mark('FCLEAN', `('##class(Security.Applications).Exists("${PROBE_APP}"))&&('##class(Security.Users).Exists("${LOW_USER}"))&&('##class(Security.Roles).Exists("${LOW_ROLE}"))`),
    ],
    ['FCLEAN']
  );
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates a web application and a principal, so it never runs inside the live container');
  assert.match(config.container, /-ci$/, `this spec writes to the instance, so it runs only in a throwaway; ${config.container} is not one`);
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  removeSeeds();
  const { values, output } = inSys(
    [
      'Set tNS=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")',
      'Set tRes=##class(SYS.Database).%OpenId(##class(Config.Databases).Open(##class(Config.Namespaces).Open(tNS).Routines).Directory).ResourceName',
      `Set p("NameSpace")=tNS,p("Description")="${escapeOs(PROBE_MARKER)}",p("AutheEnabled")=64,p("Enabled")=1,p("MatchRoles")=":%DB_USER"`,
      `Set tApp=##class(Security.Applications).Create("${PROBE_APP}",.p)`,
      `Set tRole=##class(Security.Roles).Create("${LOW_ROLE}","OcuPilot findings browser probe (throwaway)",tRes_":R,%Admin_Manage:U,%DB_IRISSYS:R","")`,
      `Set tUser=##class(Security.Users).Create("${LOW_USER}","${LOW_ROLE}","${LOW_PASSWORD}","OcuPilot findings browser probe (throwaway)","","","",0,1,"")`,
      mark('FSEED', '$System.Status.IsOK(tApp)&&$System.Status.IsOK(tRole)&&$System.Status.IsOK(tUser)'),
      mark('FSECURE', `$SYSTEM.Security.CheckUserPermission("${LOW_USER}","%Admin_Secure","USE")`),
    ],
    ['FSEED', 'FSECURE']
  );
  assert.equal(values.FSEED, '1', `the probe application and principal were created:\n${output}`);
  assert.equal(values.FSECURE, '0', 'and the principal does not hold %Admin_Secure:USE');
  await requireFreeSlot(config);
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  const allowed = runIris(config.container, [
    `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`,
    `Write "OCU-FRW-START:"_$System.Status.IsOK(sc)_":OCU-FRW-END",!`,
  ]);
  assert.equal(markerValue(allowed, 'FRW'), '1', `the probe definition allows writes: ${allowed}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  browser = null;
  if (!/-ci$/.test(config.container)) return;
  await requireFreeSlot(config).catch(() => {});
  dropProposals();
  disarmProbeDefinition(probe, priorDefault);
  const { values, output } = removeSeeds();
  await resetRememberedState();
  assert.equal(values.FCLEAN, '1', `the probe application, principal and role are gone:\n${output}`);
});

function dropProposals() {
  runIris(config.container, [`Do ##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`]);
}

/** The findings answer the instance gives the suite's own account. */
async function findingsAnswer() {
  const answer = await fetch(`${config.origin}${FINDINGS_PATH}?ns=HSCUSTOM`, {
    headers: { Authorization: 'Basic ' + Buffer.from(`${config.username}:${config.password}`).toString('base64') },
  });
  assert.equal(answer.status, 200);
  return answer.json();
}

/** Each rendered group as its heading and its lines' sentences. */
function renderedGroups(page) {
  return page.evaluate(() =>
    Array.from(document.querySelectorAll('.ocu-home-findings-group')).map((group) => ({
      heading: group.querySelector('h3')?.textContent?.trim() ?? '',
      lines: Array.from(group.querySelectorAll('.ocu-home-finding')).map((item) => ({
        sentence: item.querySelector('.ocu-home-finding-sentence')?.textContent?.trim() ?? '',
        fix: item.querySelector('.ocu-home-finding-fix') !== null,
        open: item.querySelector('.ocu-home-finding-open') !== null,
        refused: item.querySelector('.ocu-home-finding-refused')?.textContent?.trim() ?? null,
      })),
    }))
  );
}

async function waitForPanel(page) {
  await page.waitForSelector('.ocu-home-findings-group', { timeout: config.navigationTimeoutMs });
}

function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

// Mutation (Rule 19): stop Home from rendering the panel (drop the `@if (findingsShown)` block) and
// rebuild -> this goes red on the groups. Render a `webapp-open` finding without its name
// (`findingLines`) and rebuild -> this goes red on the seeded application.
test('AC1 and AC5: the panel follows the performance row, names what the instance holds, and passes the structural gate in both themes', async () => {
  const { context, page } = await signedInAt(browser, config, HOME_URL);
  try {
    await waitForPanel(page);
    const answer = await findingsAnswer();
    const taskFinding = answer.findings.find((finding) => finding.check === 'task-error');
    assert.ok(taskFinding, `the demo task is a finding: ${JSON.stringify(answer.findings)}`);

    const order = await page.evaluate(() => {
      const panel = document.querySelector('app-findings-panel');
      return { before: panel?.previousElementSibling?.tagName.toLowerCase() ?? '', after: panel?.nextElementSibling?.className ?? '' };
    });
    assert.equal(order.before, 'app-performance-row', 'the panel follows the performance row');
    assert.match(order.after, /ocu-home-remembered/, 'and precedes the blocks');

    const groups = await renderedGroups(page);
    assert.deepEqual(groups.map((group) => group.heading), [STRINGS.findingsSecurity, STRINGS.findingsOperations]);
    const security = groups[0].lines.map((line) => line.sentence);
    const operations = groups[1].lines.map((line) => line.sentence);
    assert.ok(security.includes(fill(STRINGS.findingWebappOpen, { name: PROBE_APP })), `the seeded application is named: ${JSON.stringify(security)}`);
    assert.ok(security.includes(fill(STRINGS.findingWebappOpen, { name: '/csp/user' })), `the stock /csp/user is named: ${JSON.stringify(security)}`);
    assert.ok(security.includes(fill(STRINGS.findingMonitorOpen, { name: '/api/monitor' })), 'the stock monitoring API is named');
    for (const finding of answer.findings.filter((row) => row.check === 'webapp-open' || row.check === 'monitor-open')) {
      const sentence = fill(finding.check === 'webapp-open' ? STRINGS.findingWebappOpen : STRINGS.findingMonitorOpen, { name: finding.name });
      assert.ok(security.includes(sentence), `${finding.name}, which the instance answers, is named: ${JSON.stringify(security)}`);
    }
    for (const name of ['SuperUser', '_SYSTEM', '_Ensemble', 'irisowner']) {
      assert.ok(security.includes(fill(STRINGS.findingAllHolder, { name })), `${name} holds %All`);
    }
    assert.ok(!security.some((line) => line.startsWith('/ocupilot ')), 'OcuPilot\u2019s own applications are not findings');
    assert.ok(operations.includes(fill(STRINGS.findingTaskError, { name: taskFinding.name })), 'the demo task is named');
    assert.ok(!operations.some((line) => line.includes('Integrity Check') || line.includes('Automatic Table Statistic')), 'a task a person suspended is not');

    const found = [];
    const passes = [
      { viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
      { viewport: VIEWPORTS.narrow, theme: 'light', checks: ['name', 'min-width', 'overflow'] },
      { viewport: VIEWPORTS.wide, theme: 'dark', checks: ['contrast'] },
    ];
    const minimums = componentMinimums();
    const surfaces = {};
    for (const { viewport, theme, checks } of passes) {
      await page.setViewport(viewport);
      await page.evaluate((isDark) => document.documentElement.classList.toggle('ocu-theme-dark', isDark), theme === 'dark');
      await frames(page);
      surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
      assert.ok((await page.evaluate(() => document.querySelectorAll('.ocu-home-finding').length)) > 0, `the panel is showing at ${viewport.width}px ${theme}`);
      const { entries } = await detectScreen(page, { route: HOME_ROUTE_KEY, checks, viewport: viewport.width, theme, minimums });
      found.push(...entries);
    }
    await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
    assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme');
    const fresh = compare(collapse(found), readBaseline()?.entries ?? []).fresh;
    assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], 'no violation beyond the baseline on Home with the panel showing');
  } finally {
    await context.close();
  }
});

test("AC2: _SYSTEM's line shows the prohibited set's own sentence and no Fix it", async () => {
  const { context, page } = await signedInAt(browser, config, HOME_URL);
  try {
    await waitForPanel(page);
    const groups = await renderedGroups(page);
    const system = groups[0].lines.find((line) => line.sentence === fill(STRINGS.findingAllHolder, { name: '_SYSTEM' }));
    assert.ok(system, '_SYSTEM is listed');
    assert.equal(system.fix, false, 'with no Fix it');
    assert.equal(system.open, false, 'and no Open');
    assert.equal(system.refused, STRINGS.userRefusalSystemAccount, 'and the prohibited set\u2019s sentence, character for character');
  } finally {
    await context.close();
  }
});

/** Call 1's recorded `messages` for `tag`. */
function recordedMessages(tag) {
  const output = runIris(config.container, [
    `Write "OCU-FMSGS-START:"_##class(OcuPilot.Test.TurnProvider).Recorded("${escapeOs(tag)}",1,"messages")_":OCU-FMSGS-END",!`,
  ]);
  const value = markerValue(output, 'FMSGS');
  assert.ok(value, `Recorded answered: ${output}`);
  return JSON.parse(value);
}

function screenContextPayload(messages) {
  const useIndex = messages.findIndex(
    (entry) => entry.role === 'assistant' && Array.isArray(entry.content) && entry.content.some((block) => block.type === 'tool_use' && block.name === 'screen_context')
  );
  if (useIndex < 0) return null;
  const resultBlock = messages[useIndex + 1]?.content?.find?.((block) => block.type === 'tool_result');
  return resultBlock ? JSON.parse(resultBlock.content) : null;
}

function lastUserText(messages) {
  const last = [...messages].reverse().find((entry) => entry.role === 'user');
  if (last === undefined) return '';
  if (typeof last.content === 'string') return last.content;
  return last.content.filter((block) => block.type === 'text').map((block) => block.text).join('');
}

// Mutation (Rule 19): request the fixed sentence straight after the navigation in Home's
// `fixAndRequest`, without waiting for Task details' read, and rebuild -> the context carries no
// row and this goes red.
test('AC3: Fix it opens Task details on the demo task, sends the fixed sentence with that screen as context, and the agent proposes an ordinary card', async () => {
  await requireFreeSlot(config);
  dropProposals();
  const answer = await findingsAnswer();
  const taskFinding = answer.findings.find((finding) => finding.check === 'task-error');
  assert.ok(taskFinding, 'the demo task is a finding');
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  const input = { Id: taskFinding.id, rationale: 'It was suspended after an error.', expectedImpact: 'it runs again', reverse: 'suspend it again' };
  scriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_resume", "name": "tasks_schedule_resume", "input": ${JSON.stringify(input)}}])`);
  scriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs('Resuming it needs your Confirm.')}")`);
  const { context, page } = await signedInAt(browser, config, HOME_URL);
  try {
    await waitForPanel(page);
    await page.waitForFunction(
      (sentence) =>
        Array.from(document.querySelectorAll('.ocu-home-finding')).some(
          (item) => item.querySelector('.ocu-home-finding-sentence')?.textContent?.trim() === sentence && item.querySelector('.ocu-home-finding-fix:not([aria-disabled])') !== null
        ),
      { timeout: config.navigationTimeoutMs },
      fill(STRINGS.findingTaskError, { name: taskFinding.name })
    );
    await page.evaluate((sentence) => {
      const item = Array.from(document.querySelectorAll('.ocu-home-finding')).find((candidate) => candidate.querySelector('.ocu-home-finding-sentence')?.textContent?.trim() === sentence);
      item.querySelector('.ocu-home-finding-fix').click();
    }, fill(STRINGS.findingTaskError, { name: taskFinding.name }));

    await page.waitForFunction((route, id) => location.pathname.endsWith(`/${route}/${encodeURIComponent(id)}`), { timeout: config.navigationTimeoutMs }, TASK_ROUTE, taskFinding.id);
    await page.waitForSelector('app-proposal-card .ocu-proposal-card-confirm', { timeout: config.navigationTimeoutMs });
    const userLine = await page.$eval('.ocu-panel-message-user', (node) => node.textContent.trim());
    assert.equal(userLine, STRINGS.findingFixTaskError, 'the transcript shows the fixed sentence');

    const messages = recordedMessages(tag);
    assert.equal(lastUserText(messages), STRINGS.findingFixTaskError, 'the user message is the fixed sentence and nothing else');
    const payload = screenContextPayload(messages);
    assert.ok(payload, 'the turn carried screen context');
    assert.equal(payload.route, TASK_ROUTE, 'from Task details');
    assert.equal(String(payload.entity), String(taskFinding.id), 'naming the task as its entity');
    assert.ok(JSON.stringify(payload.rows ?? []).includes(taskFinding.name), 'with the task\u2019s own row, read after the screen opened');
    const suspended = runIris(config.container, [`Write "OCU-FSUSP-START:"_##class(OcuPilot.Test.TaskResume).InfoSuspended("${escapeOs(taskFinding.id)}")_":OCU-FSUSP-END",!`]);
    assert.equal(markerValue(suspended, 'FSUSP'), 'true', 'nothing changed before Confirm: the task is still suspended');
  } finally {
    await context.close();
    forgetTag(probe, tag);
    await requireFreeSlot(config).catch(() => {});
    dropProposals();
  }
});

test('AC4: a caller without %Admin_Secure:USE sees each security check "Not checked", naming the pair, and never "Nothing to report" there', async () => {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  try {
    page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
    await page.setViewport(VIEWPORTS.wide);
    await page.goto(`${config.origin}${HOME_URL}`, { waitUntil: 'networkidle2' });
    await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('#ocu-signin-user', LOW_USER);
    await page.type('#ocu-signin-password', LOW_PASSWORD);
    await page.click('.ocu-signin-card button[type="submit"]');
    await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
    await leaveFirstLoginGate(page, config.navigationTimeoutMs, HOME_URL);
    await waitForPanel(page);
    const groups = await renderedGroups(page);
    const suffix = fill(STRINGS.impactRequires, { pair: '%Admin_Secure:USE' });
    const expected = [
      STRINGS.findingsCheckWebappOpen,
      STRINGS.findingsCheckMonitorOpen,
      STRINGS.findingsCheckAllHolder,
      STRINGS.findingsCheckCertificate,
      STRINGS.findingsCheckAuditingOff,
    ].map((check) => fill(STRINGS.findingsNotChecked, { check }) + suffix);
    assert.deepEqual(groups[0].lines.map((line) => line.sentence), expected);
    assert.ok(groups[0].lines.every((line) => !line.fix && !line.open), 'and offers nothing to act on');
  } finally {
    await context.close();
  }
});
