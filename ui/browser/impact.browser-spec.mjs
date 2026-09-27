/**
 * Story 16.19 in a real browser, against the throwaway instance: the Roles list's Delete and the
 * role editor's Delete read `GET /screens/permissions.roles/impact` as the dialog opens and state the
 * removal's impact as its advisory, a holder added afterwards is counted when the dialog is opened
 * again, the Resources list's Delete states its own, and the Users list's Remove role states what
 * the account loses under the role picker (AD-8). The instance computes; the page renders.
 *
 * The agent's role delete, minted through the armed `turnprobe` row, draws the impact read at the
 * mint on its proposal card, above the privilege line.
 *
 * With the Delete dialog's line showing, and again with the card's, the page passes the structural
 * and contrast checks at 1280 light, 720 light and 1280 dark beyond the baseline (DW-1337), and the
 * line reads the same in both themes.
 *
 * **It creates and deletes accounts, a role, a resource and a web application**, so it refuses
 * anything but an installed throwaway. `before` makes them and `after` removes them whether or not a
 * test failed.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/impact.browser-spec.mjs`.
 *
 * Mutation (Rule 19): make `OcuPilot.Api.ScreenImpact.Handle` answer `{impact: null}`, recompile on
 * the throwaway -> the dialog opens with no advisory and the AC6 leg goes red.
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
  forgetTag as sharedForgetTag,
  markerValue,
  nextTag as sharedNextTag,
  requireFreeSlot,
  runIris as sharedRunIris,
  scriptReply as sharedScriptReply,
  setTag as sharedSetTag,
} from './turnprobe-spec.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const ROLES_ROUTE = 'permissions/roles';
const ROLES_URL = `/ocupilot/${ROLES_ROUTE}?ns=HSCUSTOM`;
const RESOURCES_URL = '/ocupilot/permissions/resources?ns=HSCUSTOM';
const USERS_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';

/** This spec's own objects, never ones the instance had. */
const ROLE = 'OcuPilotProbeImpactRole';
const RESOURCE = 'OcuPilotProbeImpactRes';
const APP = '/csp/ocupilotprobeimpactp';
const HOLDERS = ['OcuPilotProbeImpactA', 'OcuPilotProbeImpactB'];
const LATE = 'OcuPilotProbeImpactC';
const MARKER = 'OcuPilot impact browser spec probe (throwaway)';
const PASSWORD = 'OcuPilotImpact9Aa';
const EDIT_URL = `/ocupilot/permissions/roles/edit/${ROLE}?ns=HSCUSTOM`;

const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';

/** The line the Roles list's Delete states for `holders`, one web application granting the role. */
function roleLine(holders) {
  const holdersPhrase =
    holders.length === 1
      ? STRINGS.impactHoldersOne.replace('<names>', holders[0])
      : STRINGS.impactHolders.replace('<n>', String(holders.length)).replace('<names>', holders.slice(0, 3).join(', '));
  return STRINGS.impactLine.replace('<parts>', `${holdersPhrase}; ${STRINGS.impactGrantingApplicationsOne.replace('<names>', APP)}`);
}

let browser = null;
const probe = { container: config.container, marker: 'IMPACTLINE' };
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
    ...[...HOLDERS, LATE].map((name) => `If ##class(Security.Users).Exists("${name}") Do ##class(Security.Users).Delete("${name}")`),
    `If ##class(Security.Applications).Exists("${APP}") Do ##class(Security.Applications).Delete("${APP}")`,
    `If ##class(Security.Roles).Exists("${ROLE}") Do ##class(Security.Roles).Delete("${ROLE}")`,
    `If ##class(Security.Resources).Exists("${RESOURCE}") Do ##class(Security.Resources).Delete("${RESOURCE}")`,
  ];
}

/** Make the probes afresh: the resource, the role granting it, its two holders, and the application granting the role. */
function createProbes() {
  return irisSys(
    [
      ...removeLines(),
      `Set tSC=##class(Security.Resources).Create("${RESOURCE}","${MARKER}","","")`,
      `If $System.Status.IsOK(tSC) Set tSC=##class(Security.Roles).Create("${ROLE}","${MARKER}","${RESOURCE}:RW","")`,
      ...HOLDERS.map((name) => `If $System.Status.IsOK(tSC) Set tSC=##class(Security.Users).Create("${name}","${ROLE}","${PASSWORD}","Probe","","","",0,1,"${MARKER}")`),
      'Kill tProps Set tProps("NameSpace")="USER",tProps("Enabled")=0,tProps("AutheEnabled")=32',
      `Set tProps("MatchRoles")=":${ROLE}",tProps("Resource")="${RESOURCE}",tProps("Description")="${MARKER}"`,
      `If $System.Status.IsOK(tSC) Set tSC=##class(Security.Applications).Create("${APP}",.tProps)`,
      mark('MADE', '$System.Status.IsOK(tSC)'),
    ],
    ['MADE']
  );
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** Narrow the list to `name`, select its row and open its row menu. */
async function openRowMenu(page, name) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await page.waitForFunction(
    (selector, wanted, textSelector) =>
      Array.from(document.querySelectorAll(selector)).some((row) => {
        const cell = row.querySelector('[role="gridcell"]');
        const text = cell.querySelector(textSelector);
        return (text === null ? cell : text).textContent.trim() === wanted;
      }),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
  await clickRowCentre(page, { text: name, cell: 2 });
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
}

async function choose(page, label) {
  await page.evaluate((wanted) => {
    const items = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'));
    items.find((item) => item.textContent.trim().startsWith(wanted)).click();
  }, label);
}

/** The open typed-name dialog's advisory, or `''` when it draws none. */
async function advisory(page) {
  await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
  return page.$eval('[role="dialog"]', (surface) => (surface.querySelector('[data-slot="advisory"] .ocu-banner-message')?.textContent ?? '').trim());
}

/** Escape the open dialog and wait for it to close. */
async function dismiss(page) {
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
}

/** Delete the signed-in account's proposals. */
function dropProposals() {
  const output = sharedRunIris(config.container, [
    `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`,
    `Write "OCU-IMPACTLINE-DROP-START:"_$System.Status.IsOK(sc)_":OCU-IMPACTLINE-DROP-END",!`,
  ]);
  assert.equal(markerValue(output, 'IMPACTLINE-DROP'), '1', `the probe proposals are removed: ${output}`);
}

/** Record every impact read the page makes. */
function impactReads(page) {
  const reads = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.pathname.endsWith('/impact')) reads.push(`${request.method()} ${url.pathname}${url.search}`);
  });
  return reads;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes accounts, a role, a resource and a web application, so it never runs inside the live container');
  await assertThrowaway(config);
  const { values, output } = createProbes();
  assert.equal(values.MADE, '1', `the probes were created:\n${output}`);
  browser = await puppeteer.launch(launchOptions(config));
  await requireFreeSlot(config);
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  const writable = sharedRunIris(config.container, [
    `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`,
    `Write "OCU-IMPACTLINE-RW-START:"_$System.Status.IsOK(sc)_":OCU-IMPACTLINE-RW-END",!`,
  ]);
  assert.equal(markerValue(writable, 'IMPACTLINE-RW'), '1', `the probe definition allows writes: ${writable}`);
});

after(async () => {
  if (browser !== null) await browser.close();
  await requireFreeSlot(config).catch(() => {});
  dropProposals();
  disarmProbeDefinition(probe, priorDefault);
  const { values, output } = irisSys(
    [...removeLines(), mark('CLEAN', `('##class(Security.Roles).Exists("${ROLE}"))&&('##class(Security.Resources).Exists("${RESOURCE}"))&&('##class(Security.Applications).Exists("${APP}"))`)],
    ['CLEAN']
  );
  assert.equal(values.CLEAN, '1', `the probes are gone:\n${output}`);
});

test('AC6, AC1: the Roles list\u2019s Delete states the impact read as it opens, in both themes, within the structural baseline, and counts a later holder when reopened', async () => {
  const { context, page } = await signedInAt(browser, config, ROLES_URL, VIEWPORTS.wide);
  const reads = impactReads(page);
  try {
    await openRowMenu(page, ROLE);
    await choose(page, STRINGS.actionDelete);
    assert.equal(await advisory(page), roleLine(HOLDERS), 'the dialog states who holds the role and which application grants it');
    assert.deepEqual(reads, [`GET /api/ocupilot/screens/permissions.roles/impact?action=delete&id=${ROLE}&ns=HSCUSTOM`], 'read from the impact route as it opened');

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
      assert.equal(await advisory(page), roleLine(HOLDERS), `the line reads the same at ${viewport.width}px ${theme}`);
      const { entries } = await detectScreen(page, { route: ROLES_ROUTE, checks, viewport: viewport.width, theme, minimums });
      found.push(...entries);
    }
    await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
    await page.setViewport(VIEWPORTS.wide);
    assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
    const fresh = compare(collapse(found), readBaseline()?.entries ?? []).fresh;
    assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], 'no violation beyond the baseline with the impact line showing');
    await dismiss(page);

    const { values, output } = irisSys(
      [`Set tSC=##class(Security.Users).Create("${LATE}","${ROLE}","${PASSWORD}","Probe","","","",0,1,"${MARKER}")`, mark('LATE', '$System.Status.IsOK(tSC)')],
      ['LATE']
    );
    assert.equal(values.LATE, '1', `a third holder is added:\n${output}`);
    await openRowMenu(page, ROLE);
    await choose(page, STRINGS.actionDelete);
    assert.equal(await advisory(page), roleLine([...HOLDERS, LATE]), 'the reopened dialog counts the holder added since');
    await dismiss(page);
  } finally {
    irisSys([`If ##class(Security.Users).Exists("${LATE}") Do ##class(Security.Users).Delete("${LATE}")`]);
    await context.close();
  }
});

test('AC6: the role editor\u2019s Delete opens the same dialog with the same line', async () => {
  const { context, page } = await signedInAt(browser, config, EDIT_URL, VIEWPORTS.wide);
  try {
    await (await page.waitForSelector('button[data-action="delete"]', { visible: true, timeout: config.navigationTimeoutMs })).click();
    assert.equal(await advisory(page), roleLine(HOLDERS), 'the editor\u2019s Delete states the impact');
    await dismiss(page);
  } finally {
    await context.close();
  }
});

test('AC3: the Resources list\u2019s Delete states the roles granting it and what it guards', async () => {
  const { context, page } = await signedInAt(browser, config, RESOURCES_URL, VIEWPORTS.wide);
  try {
    await openRowMenu(page, RESOURCE);
    await choose(page, STRINGS.actionDelete);
    const expected = STRINGS.impactLine.replace(
      '<parts>',
      [
        STRINGS.impactGrantingRolesOne.replace('<names>', ROLE),
        STRINGS.impactGuardedApplicationsOne.replace('<names>', APP),
        STRINGS.impactGuardedDatabasesNone,
      ].join('; ')
    );
    assert.equal(await advisory(page), expected, 'the dialog names the granting role, the guarded application and no database');
    await dismiss(page);
  } finally {
    await context.close();
  }
});

test('AC2: the Users list\u2019s Remove role states what the account loses under the picker, read with it', async () => {
  const { context, page } = await signedInAt(browser, config, USERS_URL, VIEWPORTS.wide);
  const user = HOLDERS[0];
  try {
    await openRowMenu(page, user);
    await choose(page, STRINGS.userActionRemoveRole);
    await page.waitForSelector('[role="dialog"] select', { timeout: config.navigationTimeoutMs });
    await page.select('[role="dialog"] select', ROLE);
    const expected = STRINGS.impactLine.replace('<parts>', STRINGS.impactLoses.replace('<user>', user).replace('<names>', `${RESOURCE}:RW`));
    await page.waitForSelector('[role="dialog"] [data-slot="impact"]', { timeout: config.navigationTimeoutMs });
    const drawn = await page.evaluate(() => {
      const select = document.querySelector('[role="dialog"] select');
      const caption = document.querySelector('[role="dialog"] [data-slot="impact"]');
      return { text: caption.textContent.trim(), described: (select.getAttribute('aria-describedby') ?? '').split(' ').includes(caption.id) };
    });
    assert.deepEqual(drawn, { text: expected, described: true }, 'the loss is stated under the picker and read with it');

    const found = [];
    const passes = [
      { viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
      { viewport: VIEWPORTS.narrow, theme: 'light', checks: ['name', 'min-width', 'overflow'] },
      { viewport: VIEWPORTS.wide, theme: 'dark', checks: ['contrast'] },
    ];
    const minimums = componentMinimums();
    for (const { viewport, theme, checks } of passes) {
      await page.setViewport(viewport);
      await page.evaluate((isDark) => document.documentElement.classList.toggle('ocu-theme-dark', isDark), theme === 'dark');
      await frames(page);
      const caption = await page.$eval('[role="dialog"] [data-slot="impact"]', (node) => node.textContent.trim());
      assert.equal(caption, expected, `the caption reads the same at ${viewport.width}px ${theme}`);
      const { entries } = await detectScreen(page, { route: 'permissions/users', checks, viewport: viewport.width, theme, minimums });
      found.push(...entries);
    }
    await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
    await page.setViewport(VIEWPORTS.wide);
    const fresh = compare(collapse(found), readBaseline()?.entries ?? []).fresh;
    assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], 'no violation beyond the baseline with the Remove role caption showing');
    await dismiss(page);
  } finally {
    await context.close();
  }
});

test('AC1, AC6: the agent\u2019s role delete draws the impact read at its mint on the card, above the privilege line, in both themes, within the structural baseline', async () => {
  // Mutation (Rule 19): make `OcuPilot.Kernel.Proposal.Mint.ImpactValue` record "" always, recompile
  // on the throwaway -> the card draws no impact line and this goes red.
  await requireFreeSlot(config);
  const tag = sharedNextTag(probe);
  sharedSetTag(probe, preparedId, tag);
  const input = { Name: ROLE, rationale: 'The role is no longer used.', expectedImpact: 'the role is gone', reverse: 'create it again' };
  sharedScriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_impact", "name": "permissions_roles_delete", "input": ${JSON.stringify(input)}}])`);
  sharedScriptReply(probe, tag, 20, '##class(OcuPilot.Test.TurnProvider).TextReply("done")');
  const { context, page } = await signedInAt(browser, config, '/ocupilot/?ns=HSCUSTOM', VIEWPORTS.wide);
  try {
    await page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), { timeout: config.navigationTimeoutMs });
    await page.type('#ocu-panel-composer', `delete the role ${ROLE}`);
    await page.click('.ocu-panel-send');
    await page.waitForSelector('app-proposal-card [data-slot="impact"]', { timeout: config.navigationTimeoutMs });
    const cardLine = () =>
      page.evaluate(() => {
        const line = document.querySelector('app-proposal-card [data-slot="impact"]');
        return { text: line?.textContent.trim() ?? '', next: line?.nextElementSibling?.getAttribute('data-slot') ?? '' };
      });
    assert.deepEqual(await cardLine(), { text: roleLine(HOLDERS), next: 'privilege' }, 'the card states the impact above the privilege line');

    const found = [];
    const passes = [
      { viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
      { viewport: VIEWPORTS.narrow, theme: 'light', checks: ['name', 'min-width', 'overflow'] },
      { viewport: VIEWPORTS.wide, theme: 'dark', checks: ['contrast'] },
    ];
    const minimums = componentMinimums();
    for (const { viewport, theme, checks } of passes) {
      await page.setViewport(viewport);
      await page.evaluate((isDark) => document.documentElement.classList.toggle('ocu-theme-dark', isDark), theme === 'dark');
      await frames(page);
      assert.equal((await cardLine()).text, roleLine(HOLDERS), `the card line reads the same at ${viewport.width}px ${theme}`);
      const { entries } = await detectScreen(page, { route: '/', checks, viewport: viewport.width, theme, minimums });
      found.push(...entries);
    }
    await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
    const fresh = compare(collapse(found), readBaseline()?.entries ?? []).fresh;
    assert.deepEqual(fresh.map((entry) => `${entry.key}: ${entry.measured}`), [], 'no violation beyond the baseline with the card\u2019s impact line showing');
  } finally {
    await context.close();
    sharedForgetTag(probe, tag);
  }
});
