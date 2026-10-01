/**
 * Story 16.3 in a real browser, against the throwaway instance: the user editor's Effective privileges
 * tab reads `GET /api/ocupilot/users/effective` when selected and renders the chained account's
 * sections -- its roles with the one reached through another, never its escalation role; a letter
 * granted by a reached role and a public letter; the web applications, databases and services those
 * resources guard -- and an account whose role grants `%All` as the `%All` statement over its roles
 * alone (AC1, AC2, AC9). With the tab showing, the page passes the structural and contrast checks at
 * 1280 light, 720 light and 1280 dark beyond the baseline (DW-1337), and a role name, like every other
 * line on the tab and on the Check permission dialog, is set in the app's type family (DW-1837).
 *
 * The Users list's Check permission opens its dialog on the selected row and answers from
 * `GET /api/ocupilot/permissions/check`; a scripted turn asks `permissions.privileges.check` the same
 * question, and its recorded `tool_result`, read through `resultPayload`, answers the same object
 * (AC4, AC9). The role editor's Check permission asks the same route as a role and names the
 * granting role with no through, and its Cancel closes the dialog (AC5). A principal holding only `%Admin_Secure:USE` and `%DB_IRISSYS:READ` is offered the
 * Security rail item with SSL/TLS, X.509, LDAP and Auditing available and Wallet and OAuth 2.0 naming
 * their pair (AC7, DW-1018), and reads the tab with Databases not checked (AC3).
 *
 * **It creates and deletes accounts, roles, two resources and a web application**, so it refuses
 * anything but an installed throwaway. `before` makes them and `after` removes them whether or not a
 * test failed.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/permissions-effective.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import {
  armProbeDefinition,
  disarmProbeDefinition,
  escapeOs,
  forgetTag,
  markerValue,
  nextTag,
  requireFreeSlot,
  resultPayload,
  runIris,
  scriptReply,
  setTag,
} from './turnprobe-spec.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { formatArea, formatRequires } = await import(join(uiRoot, 'src', 'app', 'core', 'navigation.ts'));

const config = browserConfig();
const EDITOR_ROUTE = 'permissions/users/edit';
const USERS_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';
const EFFECTIVE_PATH = '/api/ocupilot/users/effective';
const CHECK_PATH = '/api/ocupilot/permissions/check';

/** This spec's own objects, never ones the instance had. */
const RES = 'OcuPilotProbeEffRes';
const PUB = 'OcuPilotProbeEffPub';
const ROLE_A = 'OcuPilotProbeEffA';
const ROLE_B = 'OcuPilotProbeEffB';
const ROLE_E = 'OcuPilotProbeEffE';
const ROLE_ALL = 'OcuPilotProbeEffR';
const ROLE_SECURE = 'OcuPilotProbeEffSec';
const USER_CHAINED = 'OcuPilotProbeEffU';
const USER_ALL = 'OcuPilotProbeEffV';
const USER_SECURE = 'OcuPilotProbeEffSecU';
const APP = '/csp/ocupilotprobeeff';
const MARKER = 'OcuPilot effective privileges browser spec probe (throwaway)';
const PASSWORD = 'OcuPilotEffective9Aa';

let browser = null;
const probe = { container: config.container, marker: 'EFFPRIV' };
let preparedId = '';
let priorDefault = '';

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Run ObjectScript in `%SYS` inside the throwaway and read back the named markers. */
function irisSys(lines, names = []) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input: `${[...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const values = {};
  for (const name of names) {
    const found = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
    values[name] = found === null ? null : found[1];
  }
  return { values, output };
}

/** Remove every probe object by its exact name. */
function removeLines() {
  return [
    ...[USER_CHAINED, USER_ALL, USER_SECURE].map((name) => `If ##class(Security.Users).Exists("${name}") Do ##class(Security.Users).Delete("${name}")`),
    `If ##class(Security.Applications).Exists("${APP}") Do ##class(Security.Applications).Delete("${APP}")`,
    ...[ROLE_A, ROLE_B, ROLE_E, ROLE_ALL, ROLE_SECURE].map((name) => `If ##class(Security.Roles).Exists("${name}") Do ##class(Security.Roles).Delete("${name}")`),
    ...[RES, PUB].map((name) => `If ##class(Security.Resources).Exists("${name}") Do ##class(Security.Resources).Delete("${name}")`),
  ];
}

/** Make the probes afresh. */
function createProbes() {
  const user = (name, roles) => `If $System.Status.IsOK(tSC) Set tSC=##class(Security.Users).Create("${name}","${roles}","${PASSWORD}","Probe","","","",0,1,"${MARKER}")`;
  return irisSys(
    [
      ...removeLines(),
      'Set tNS=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")',
      'Set tCode=##class(SYS.Database).%OpenId(##class(Config.Databases).Open(##class(Config.Namespaces).Open(tNS).Routines).Directory).ResourceName',
      `Set tSC=##class(Security.Resources).Create("${RES}","${MARKER}","","")`,
      `If $System.Status.IsOK(tSC) Set tSC=##class(Security.Resources).Create("${PUB}","${MARKER}","R","")`,
      `If $System.Status.IsOK(tSC) Set tSC=##class(Security.Roles).Create("${ROLE_B}","${MARKER}","${RES}:RU,%DB_USER:R","")`,
      `If $System.Status.IsOK(tSC) Set tSC=##class(Security.Roles).Create("${ROLE_A}","${MARKER}","","${ROLE_B}")`,
      `If $System.Status.IsOK(tSC) Set tSC=##class(Security.Roles).Create("${ROLE_E}","${MARKER}","${RES}:W,%Admin_Secure:U","")`,
      `If $System.Status.IsOK(tSC) Set tSC=##class(Security.Roles).Create("${ROLE_ALL}","${MARKER}","","%All")`,
      `If $System.Status.IsOK(tSC) Set tSC=##class(Security.Roles).Create("${ROLE_SECURE}","${MARKER}",tCode_":R,%Admin_Secure:U,%DB_IRISSYS:R","")`,
      'Kill tProps Set tProps("NameSpace")="USER",tProps("Enabled")=0,tProps("AutheEnabled")=32',
      `Set tProps("Resource")="${RES}",tProps("Description")="${MARKER}"`,
      `If $System.Status.IsOK(tSC) Set tSC=##class(Security.Applications).Create("${APP}",.tProps)`,
      user(USER_CHAINED, ROLE_A),
      user(USER_ALL, ROLE_ALL),
      user(USER_SECURE, ROLE_SECURE),
      `Kill tProps Set tProps("EscalationRoles")="${ROLE_E}"`,
      `If $System.Status.IsOK(tSC) Set tSC=##class(Security.Users).Modify("${USER_CHAINED}",.tProps)`,
      mark('MADE', '$System.Status.IsOK(tSC)'),
      mark('WALLET', `$SYSTEM.Security.CheckUserPermission("${USER_SECURE}","%Admin_Wallet","USE")`),
      mark('MANAGE', `$SYSTEM.Security.CheckUserPermission("${USER_SECURE}","%Admin_Manage","USE")`),
    ],
    ['MADE', 'WALLET', 'MANAGE']
  );
}

/**
 * Two rendered frames, then every running animation and transition finished, so a resize, a theme
 * flip or the tab strip's own indicator and label transitions have landed before anything is
 * measured.
 */
async function frames(page) {
  await page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  await page.waitForFunction(() => document.getAnimations().every((animation) => animation.playState !== 'running'), { timeout: config.navigationTimeoutMs });
}

/** The Security rail item's state: allowed, it carries the area's own tooltip rather than a pair. */
function railOf(page) {
  return page.evaluate((label) => {
    const item = document.querySelector(`.ocu-rail-item[aria-label="${label}"]`);
    return { disabled: item.getAttribute('aria-disabled'), tip: document.getElementById(item.getAttribute('aria-describedby'))?.textContent.trim() };
  }, STRINGS.navAreaSecurity);
}

/**
 * Record every read of `path` the page makes, and each JSON answer in response order. An answer's
 * body is fetched after its response event, so await `settled` before reading `answers`.
 */
function watch(page, path) {
  const reads = [];
  const answers = [];
  const settled = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.pathname === path) reads.push(`${request.method()} ${url.pathname}${url.search}`);
  });
  page.on('response', (response) => {
    if (new URL(response.url()).pathname !== path) return;
    const index = answers.push(null) - 1;
    settled.push(response.json().then((body) => { answers[index] = body; }, () => {}));
  });
  return { reads, answers, settled };
}

/** Open `user`'s editor as `who` and select its Effective privileges tab, answering the rendered sections. */
async function openTab(who, user) {
  const { context, page } = await signedInAt(browser, who, `/ocupilot/${EDITOR_ROUTE}/${encodeURIComponent(user)}?ns=HSCUSTOM`, VIEWPORTS.wide);
  const traffic = watch(page, EFFECTIVE_PATH);
  await (await page.waitForSelector('button[data-tab="effective"]', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[data-ocu-effective="lead"]', { visible: true, timeout: config.navigationTimeoutMs });
  await frames(page);
  return { context, page, traffic };
}

/**
 * Each gated side-bar entry's name, how many lines its name takes, and whether its reason starts
 * after the name -- to its right on the same line, or below it (DW-1879).
 */
function gatedLayout(page) {
  return page.$$eval('app-side-bar .ocu-side-bar-item[aria-disabled="true"]', (items) =>
    items.map((item) => {
      const label = item.querySelector('.ocu-side-bar-label');
      const reason = item.querySelector('.ocu-side-bar-reason');
      const range = document.createRange();
      range.selectNodeContents(label);
      const lines = new Set(Array.from(range.getClientRects()).map((rect) => Math.round(rect.top))).size;
      const named = label.getBoundingClientRect();
      const said = reason.getBoundingClientRect();
      return { label: label.textContent.trim(), lines, after: said.left >= named.right - 0.5 || said.top >= named.bottom - 0.5 };
    })
  );
}

/** The computed font family of the first element `selector` matches. */
function familyOf(page, selector) {
  return page.$eval(selector, (element) => getComputedStyle(element).fontFamily);
}

/**
 * Every rendered element under `root` that holds its own text, or is a form control, and computes a
 * font family other than `family`. The page's body sets no family, so an element that takes no type
 * role falls back to the browser's serif default (DW-1837).
 */
function offFamily(page, root, family) {
  return page.$eval(
    root,
    (rootElement, expected) => {
      const off = [];
      for (const element of [rootElement, ...rootElement.querySelectorAll('*')]) {
        if (element.getClientRects().length === 0) continue;
        const text = Array.from(element.childNodes).some((node) => node.nodeType === Node.TEXT_NODE && node.textContent.trim() !== '');
        const seen = getComputedStyle(element).fontFamily;
        if ((text || element.matches('input, select, textarea, button')) && seen !== expected) off.push(`${[element.localName, ...element.classList].join('.')}: ${seen}`);
      }
      return off;
    },
    family
  );
}

/** The tab's rendered text, section by section. */
function sections(page) {
  return page.evaluate(() => {
    const out = { lead: document.querySelector('[data-ocu-effective="lead"]')?.textContent.trim() ?? '' };
    for (const key of ['roles', 'resources', 'applications', 'databases', 'services']) {
      const section = document.querySelector(`[data-ocu-effective="${key}"]`);
      if (section === null) {
        out[key] = null;
        continue;
      }
      const note = section.querySelector('.ocu-effective-note')?.textContent.trim() ?? '';
      const rows = Array.from(section.querySelectorAll('li, tbody tr')).map((row) => {
        const cells = Array.from(row.querySelectorAll('td'));
        return cells.length > 0 ? cells.map((cell) => cell.textContent.trim()) : [row.textContent.trim()];
      });
      out[key] = { note, rows };
    }
    return out;
  });
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes accounts, roles, resources and a web application, so it never runs inside the live container');
  await assertThrowaway(config);
  const { values, output } = createProbes();
  assert.equal(values.MADE, '1', `the probes were created:\n${output}`);
  assert.equal(values.WALLET, '0', 'the security principal does not hold %Admin_Wallet:USE');
  assert.equal(values.MANAGE, '0', 'nor %Admin_Manage:USE');
  browser = await puppeteer.launch(launchOptions(config));
  await requireFreeSlot(config);
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
});

after(async () => {
  if (browser !== null) await browser.close();
  await requireFreeSlot(config).catch(() => {});
  disarmProbeDefinition(probe, priorDefault);
  const { values, output } = irisSys(
    [
      ...removeLines(),
      mark(
        'CLEAN',
        [
          ...[USER_CHAINED, USER_ALL, USER_SECURE].map((name) => `('##class(Security.Users).Exists("${name}"))`),
          ...[ROLE_A, ROLE_B, ROLE_E, ROLE_ALL, ROLE_SECURE].map((name) => `('##class(Security.Roles).Exists("${name}"))`),
          ...[RES, PUB].map((name) => `('##class(Security.Resources).Exists("${name}"))`),
          `('##class(Security.Applications).Exists("${APP}"))`,
        ].join('&&')
      ),
    ],
    ['CLEAN']
  );
  assert.equal(values.CLEAN, '1', `the probes are gone:\n${output}`);
});

test('AC1, AC9, DW-1337, DW-1837: the chained account\u2019s tab renders its sections, read when selected, in the app\u2019s type, in both themes within the structural baseline', async () => {
  const { context, page, traffic } = await openTab(config, USER_CHAINED);
  try {
    assert.deepEqual(traffic.reads, [`GET ${EFFECTIVE_PATH}?name=${USER_CHAINED}&ns=HSCUSTOM`], 'read from the Effective privileges route as the tab opened');
    const seen = await sections(page);
    assert.equal(seen.lead, STRINGS.userEffectiveIntro);
    assert.deepEqual(seen.roles.rows, [[ROLE_A], [`${ROLE_B}${STRINGS.userEffectiveThrough.replace('<role>', ROLE_A)}`]], 'A, then B through A, and no escalation role');
    const resource = (name) => seen.resources.rows.find((row) => row[0] === name);
    assert.deepEqual(resource(RES), [RES, ROLE_B, '', ROLE_B], 'Read and Use granted by B, and not the escalation role\u2019s Write');
    assert.deepEqual(resource('%DB_USER'), ['%DB_USER', ROLE_B, '', ''], '%DB_USER read through B');
    assert.deepEqual(resource(PUB), [PUB, STRINGS.oauthClientTypePublic, '', ''], 'a public letter reads Public');
    assert.equal(resource('%Admin_Secure'), undefined, 'the escalation role\u2019s %Admin_Secure is not held');
    assert.ok(seen.applications.rows.some((row) => row[0] === APP && row[1] === RES), `the web application the resource guards is listed: ${JSON.stringify(seen.applications)}`);
    assert.ok(seen.databases.rows.some((row) => /\/user\/: Read$/i.test(row[0])), `the USER database is listed with Read: ${JSON.stringify(seen.databases)}`);
    assert.ok(seen.services.rows.length > 0, `the services a public resource of their own name guards are listed: ${JSON.stringify(seen.services)}`);

    // Mutation (Rule 19): drop the type role from `.ocu-form-role-name`, rebuild and redeploy -> the
    // role name, and every Roles, Databases and Services line, reads the browser's serif default.
    const body = await familyOf(page, '[data-ocu-effective="resources"] td');
    assert.deepEqual(
      { roleName: await familyOf(page, '[data-ocu-effective="roles"] .ocu-form-role-name'), off: await offFamily(page, '[data-ocu-effective="tab"]', body) },
      { roleName: body, off: [] },
      'a role name is set in the app\u2019s body family, as a resource cell is, and so is every other line on the tab'
    );

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
      assert.equal((await sections(page)).lead, STRINGS.userEffectiveIntro, `the tab is showing at ${viewport.width}px ${theme}`);
      const { entries } = await detectScreen(page, { route: EDITOR_ROUTE, checks, viewport: viewport.width, theme, minimums });
      found.push(...entries);
    }
    await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
    assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
    const fresh = compare(collapse(found), readBaseline()?.entries ?? []).fresh;
    assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], 'no violation beyond the baseline with the Effective privileges tab showing');
  } finally {
    await context.close();
  }
});

test('AC2: an account whose role grants %All reads the %All statement and lists its roles only', async () => {
  const { context, page } = await openTab(config, USER_ALL);
  try {
    const seen = await sections(page);
    assert.equal(seen.lead, STRINGS.userEffectiveAll.replace('<role>', ROLE_ALL));
    assert.deepEqual(seen.roles.rows, [[ROLE_ALL], [`%All${STRINGS.userEffectiveThrough.replace('<role>', ROLE_ALL)}`]]);
    for (const key of ['resources', 'applications', 'databases', 'services']) assert.equal(seen[key], null, `${key} is not drawn`);
  } finally {
    await context.close();
  }
});

test('AC4, AC9: the Users list\u2019s Check permission answers from the route, and a scripted turn\u2019s permissions.privileges.check answers the same object', async () => {
  // Mutation (Rule 19): make `OcuPilot.Kernel.Shell.PermissionCheck.View` answer a constant object,
  // recompile on the throwaway -> the parity assertion goes red.
  let dialogAnswer = null;
  {
    const { context, page } = await signedInAt(browser, config, USERS_URL, VIEWPORTS.wide);
    const traffic = watch(page, CHECK_PATH);
    try {
      await waitForRows(page, config.navigationTimeoutMs);
      await page.type(FILTER_SELECTOR, USER_CHAINED);
      await page.waitForFunction(
        (selector, wanted) => Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(wanted)),
        { timeout: config.navigationTimeoutMs },
        ROW_SELECTOR,
        USER_CHAINED
      );
      await clickRowCentre(page, { text: USER_CHAINED, cell: 2 });
      await (await page.waitForSelector('.ocu-command-bar-permission-check', { visible: true, timeout: config.navigationTimeoutMs })).click();
      await page.waitForSelector('app-permission-check-dialog [data-field="name"]', { visible: true, timeout: config.navigationTimeoutMs });
      const prefilled = await page.evaluate(() => ({
        kind: document.querySelector('app-permission-check-dialog [data-field="kind"]').value,
        name: document.querySelector('app-permission-check-dialog [data-field="name"]').value,
      }));
      assert.deepEqual(prefilled, { kind: 'user', name: USER_CHAINED }, 'the dialog opens on the selected row');
      await page.type('app-permission-check-dialog [data-field="resource"]', RES);
      await page.click('app-permission-check-dialog [data-action="check"]');
      await page.waitForSelector('app-permission-check-dialog .ocu-permission-check-line[data-slot]', { timeout: config.navigationTimeoutMs });
      const line = await page.$eval('app-permission-check-dialog .ocu-permission-check-line', (node) => ({ text: node.textContent.trim(), role: node.getAttribute('role') }));
      const expected = STRINGS.permissionCheckYes
        .replace('<name>', USER_CHAINED)
        .replace('<pair>', `${RES}:READ`)
        .replace('<role>', `${ROLE_B}${STRINGS.userEffectiveThrough.replace('<role>', ROLE_A)}`);
      assert.deepEqual(line, { text: expected, role: 'status' }, 'a yes names B, through A, in the polite status line');
      // Mutation (Rule 19): drop the type role from `.ocu-field-input`, rebuild and redeploy -> the
      // dialog's four fields take the browser's control font, which they never inherit, and this goes red.
      const body = await familyOf(page, 'app-permission-check-dialog .ocu-permission-check-line');
      assert.deepEqual(await offFamily(page, 'app-permission-check-dialog', body), [], 'every line and field on the dialog is set in the app\u2019s family (DW-1837)');
      assert.deepEqual(
        traffic.reads,
        [`GET ${CHECK_PATH}?kind=user&name=${USER_CHAINED}&resource=${RES}&permission=READ&ns=HSCUSTOM`],
        'asked of the check route once'
      );
      await Promise.all(traffic.settled);
      dialogAnswer = traffic.answers[0];
      assert.equal(dialogAnswer?.held, true, `the route answered held: ${JSON.stringify(dialogAnswer)}`);
    } finally {
      await context.close();
    }
  }

  await requireFreeSlot(config);
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  const input = { kind: 'user', name: USER_CHAINED, resource: RES, permission: 'READ' };
  scriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_check", "name": "permissions_privileges_check", "input": ${JSON.stringify(input)}}])`);
  scriptReply(probe, tag, 0, '##class(OcuPilot.Test.TurnProvider).TextReply("checked")');
  const { context, page } = await signedInAt(browser, config, '/ocupilot/?ns=HSCUSTOM', VIEWPORTS.wide);
  try {
    await page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), { timeout: config.navigationTimeoutMs });
    await page.type('#ocu-panel-composer', `does ${USER_CHAINED} hold ${RES}:READ?`);
    await page.click('.ocu-panel-send');
    await page.waitForFunction(
      (expected) => [...document.querySelectorAll('.ocu-panel-message-agent-text')].some((node) => node.textContent === expected),
      { timeout: config.navigationTimeoutMs },
      'checked'
    );
    const output = runIris(config.container, [
      `Write "OCU-EFFPRIV-MSGS-START:"_##class(OcuPilot.Test.TurnProvider).Recorded("${escapeOs(tag)}",2,"messages")_":OCU-EFFPRIV-MSGS-END",!`,
    ]);
    const messages = JSON.parse(markerValue(output, 'EFFPRIV-MSGS') ?? '[]');
    const block = messages.flatMap((entry) => (Array.isArray(entry.content) ? entry.content : [])).find((candidate) => candidate.type === 'tool_result' && candidate.tool_use_id === 'toolu_check');
    assert.ok(block, `the second model call carried the tool's result: ${output.slice(0, 400)}`);
    assert.notEqual(block.is_error, true, `and it was not an error: ${block.content}`);
    const payload = resultPayload(block);
    assert.deepEqual(
      { held: payload.held, grantedBy: payload.grantedBy, through: payload.through },
      { held: dialogAnswer.held, grantedBy: dialogAnswer.grantedBy, through: dialogAnswer.through },
      'the tool and the dialog agree on held, grantedBy and through'
    );
    assert.deepEqual(payload, dialogAnswer, 'and on the whole answer');
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});

test('AC5: the role editor\u2019s Check permission asks as a role, names the granting role with no through, and Cancel closes it', async () => {
  // Mutation (Rule 19): drop `tIsUser &&` from `OcuPilot.Kernel.Shell.PermissionCheck.Check`'s through
  // rule, recompile on the throwaway -> the sentence gains " (through A)" and the line assertion goes red.
  const { context, page } = await signedInAt(browser, config, `/ocupilot/permissions/roles/edit/${encodeURIComponent(ROLE_A)}?ns=HSCUSTOM`, VIEWPORTS.wide);
  const traffic = watch(page, CHECK_PATH);
  try {
    await (await page.waitForSelector('.ocu-command-bar-permission-check', { visible: true, timeout: config.navigationTimeoutMs })).click();
    await page.waitForSelector('app-permission-check-dialog [data-field="name"]', { visible: true, timeout: config.navigationTimeoutMs });
    const prefilled = await page.evaluate(() => ({
      kind: document.querySelector('app-permission-check-dialog [data-field="kind"]').value,
      name: document.querySelector('app-permission-check-dialog [data-field="name"]').value,
    }));
    assert.deepEqual(prefilled, { kind: 'role', name: ROLE_A }, 'the dialog opens as a role check on the role the editor has open');
    await page.type('app-permission-check-dialog [data-field="resource"]', RES);
    await page.click('app-permission-check-dialog [data-action="check"]');
    await page.waitForSelector('app-permission-check-dialog .ocu-permission-check-line[data-slot]', { timeout: config.navigationTimeoutMs });
    const text = await page.$eval('app-permission-check-dialog .ocu-permission-check-line', (node) => node.textContent.trim());
    const expected = STRINGS.permissionCheckYes.replace('<name>', ROLE_A).replace('<pair>', `${RES}:READ`).replace('<role>', ROLE_B);
    assert.equal(text, expected, 'a role check names the role whose own grant it is, with no through');
    assert.deepEqual(traffic.reads, [`GET ${CHECK_PATH}?kind=role&name=${ROLE_A}&resource=${RES}&permission=READ&ns=HSCUSTOM`], 'asked of the check route as a role, once');
    await page.click('app-permission-check-dialog .ocu-dialog-actions .ocu-button-secondary');
    await page.waitForFunction(() => document.querySelector('app-permission-check-dialog') === null, { timeout: config.navigationTimeoutMs });
  } finally {
    await context.close();
  }
});

test('AC7 (DW-1018), AC3: a principal holding only the Security pairs is offered the Security area, Wallet and OAuth 2.0 naming their pair, and reads the tab with Databases not checked', async () => {
  const principal = { ...config, username: USER_SECURE, password: PASSWORD };
  const { context, page } = await signedInAt(browser, principal, '/ocupilot/security/ssl?ns=HSCUSTOM', VIEWPORTS.wide);
  try {
    assert.deepEqual(await railOf(page), { disabled: null, tip: formatArea(STRINGS.navRailItemTooltip, STRINGS.navAreaSecurity) }, 'the Security rail item is not gated');
    await page.click(`.ocu-rail-item[aria-label="${STRINGS.navAreaSecurity}"]`);
    await page.waitForSelector('app-side-bar .ocu-side-bar-item', { timeout: config.navigationTimeoutMs });
    const entries = await page.$$eval('app-side-bar .ocu-side-bar-item', (items) =>
      items.map((item) => ({
        label: item.querySelector('.ocu-side-bar-label')?.textContent.trim() ?? '',
        disabled: item.getAttribute('aria-disabled'),
        reason: item.querySelector('.ocu-side-bar-reason')?.textContent.trim() ?? '',
      }))
    );
    assert.deepEqual(
      entries,
      [
        { label: STRINGS.sslListLabel, disabled: null, reason: '' },
        { label: STRINGS.x509ListLabel, disabled: null, reason: '' },
        { label: STRINGS.ldapListLabel, disabled: null, reason: '' },
        { label: STRINGS.walletListLabel, disabled: 'true', reason: formatRequires(STRINGS.privilegeRequiresResource, '%Admin_Wallet:USE') },
        { label: STRINGS.oauthLabel, disabled: 'true', reason: formatRequires(STRINGS.privilegeRequiresResource, '%Admin_OAuth2_Client:USE') },
        { label: STRINGS.auditingConfigurationLink, disabled: null, reason: '' },
        { label: STRINGS.allowedDirectoriesLabel, disabled: 'true', reason: formatRequires(STRINGS.privilegeRequiresResource, '%Admin_FileSystemAccess:USE') },
      ],
      'SSL/TLS, X.509, LDAP and Auditing are available; Wallet, OAuth 2.0 and Allowed directories are not, each naming its pair'
    );

    // DW-1879: each gated entry keeps its name on one line and reads its reason after it, in both
    // themes, and the page with the side bar open passes the structural walk.
    // Mutation (Rule 19): drop the `.ocu-side-bar-item-gated` rules appended to `_components.scss`,
    // rebuild and redeploy -> a gated name wraps into its own column and this goes red.
    // The rail item's tooltip, shown while the pointer rests where the rail was clicked, is the
    // rail's own and not this walk's subject.
    await page.mouse.move(900, 700);
    await page.evaluate(() => document.activeElement?.blur());
    const found = [];
    const minimums = componentMinimums();
    for (const theme of ['light', 'dark']) {
      await page.evaluate((isDark) => document.documentElement.classList.toggle('ocu-theme-dark', isDark), theme === 'dark');
      await frames(page);
      assert.deepEqual(
        await gatedLayout(page),
        [STRINGS.walletListLabel, STRINGS.oauthLabel, STRINGS.allowedDirectoriesLabel].map((label) => ({ label, lines: 1, after: true })),
        `${theme}: every gated name is on one line with its reason after it`
      );
      const { entries: walked } = await detectScreen(page, { route: 'security/ssl', checks: theme === 'light' ? INVARIANTS : ['contrast'], viewport: VIEWPORTS.wide.width, theme, minimums });
      found.push(...walked);
    }
    await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
    const fresh = compare(collapse(found), readBaseline()?.entries ?? []).fresh;
    assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], 'no violation beyond the baseline with the gated side bar open, in either theme');
  } finally {
    await context.close();
  }

  const tab = await openTab(principal, USER_CHAINED);
  try {
    const seen = await sections(tab.page);
    assert.equal(seen.databases.note, `${STRINGS.userEffectiveUnchecked}${STRINGS.impactRequires.replace('<pair>', '%Admin_Manage:USE')}`, 'Databases is not checked, naming the pair');
    assert.deepEqual(seen.databases.rows, []);
    for (const key of ['roles', 'resources', 'applications', 'services']) {
      assert.ok(seen[key].rows.length > 0 && seen[key].note === '', `${key} is read and listed: ${JSON.stringify(seen[key])}`);
    }
  } finally {
    await tab.context.close();
  }
});
