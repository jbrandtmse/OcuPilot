/**
 * Story 20.26 in a real browser, against the throwaway instance: Interoperability's Business partners, saved and removed
 * (AD-5, AD-36, AD-53, AD-54, AD-55, AD-62).
 *
 * What it pins, in `USER`, whose probe business partners this spec creates and removes: the list offers New business partner and a
 * row action menu, and lists the probe partner under the published headers; New business partner creates a partner, a held name and
 * the same name in another letter case each refused with the server's sentence in the dialog; Edit opens the same dialog on the
 * selected row with the name read-only and the rename note, and changes its phone; Remove, which types the partner's name, removes
 * it; a remove of a partner a probe production's item names shows the server's sentence on the list and the partner stays; and the
 * list passes the structural and contrast checks at 1280 light, 720 light and 1280 dark, with no entry beyond the baseline
 * (DW-1337).
 *
 * Each test arranges the partner it needs through the fixture and removes it when it ends, so every test passes alone and in any
 * order; the probe production the named leg needs is made and removed by that test.
 *
 * **It writes probe business partners and a probe production in `USER`** through `OcuPilot.Test.InteropLookupFixture` and
 * `OcuPilot.Test.ProductionProbe`, so it runs on a throwaway only; the `after` hook removes every partner and the production,
 * whatever the tests answered. It starts no production.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-business-partners.browser-spec.mjs` (after `npm run build` and the
 * bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { settleViewport, signedInAt, transitionsSettled } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const FIXTURE = 'OcuPilot.Test.InteropLookupFixture';
const PROBE = 'OcuPilot.Test.ProductionProbe';
const PARTNER = 'OcuProbe226Browser';
const HELD = 'OcuProbe226Held';
const NAMED = 'OcuProbe226Named';
const LISTED = 'OcuProbe205Partner';
const PARTNERS_URL = '/ocupilot/interoperability/business-partners?ns=USER';
const PARTNERS_ROUTE = 'interoperability/business-partners';
const ACTION_PATH = '/api/ocupilot/screens/interop.businesspartners/action';
const ADD_PATH = '/api/ocupilot/interop/business-partners';
const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';
const VALUE_FIELDS = [
  'Description',
  'PrimaryContact',
  'PrimaryTitle',
  'PrimaryEmail',
  'PrimaryPhone',
  'PrimaryMobile',
  'PrimaryNotes',
  'AlternativeContact',
  'AlternativeTitle',
  'AlternativeEmail',
  'AlternativePhone',
  'AlternativeMobile',
  'AlternativeNotes',
];

let browser = null;
let created = false;

/** Run one probe call in the throwaway and answer its marker. */
function probe(name, expression) {
  const output = runIris(config.container, [`Write "OCU-${name}-START:"_(${expression})_":OCU-${name}-END",!`]);
  return { value: markerValue(output, name), output };
}

/** The stored partner `name` as `description|primary contact|primary phone|alternative notes`, `<absent>` when it is not held. */
function stored(name) {
  return probe('PARTNER', `##class(${FIXTURE}).PartnerText("${name}")`).value;
}

/** Wait, up to ten probes, until the stored partner reads `<absent>` (`absent` true) or something else; answers the last reading. */
async function settled(name, absent) {
  let last = stored(name);
  for (let tries = 0; (last === '<absent>') !== absent && tries < 10; tries += 1) {
    await new Promise((resolve) => setTimeout(resolve, 500));
    last = stored(name);
  }
  return last;
}

/** Remove every probe partner this spec makes, whatever an earlier step left, and the probe production. */
function drop() {
  const cleared = probe('BPDROP', `$System.Status.IsOK(##class(${FIXTURE}).DropPartners("OcuProbe226"))`);
  assert.equal(cleared.value, '1', `the probe partners are removed: ${cleared.output}`);
}

/** The held partner `name`, with the fields of `fields` (an ObjectScript object literal) when given. */
function arrange(name, fields = '""') {
  const made = probe('BPMADE', `$System.Status.IsOK(##class(${FIXTURE}).PutPartner("${name}",${fields}))`);
  assert.equal(made.value, '1', `the probe partner ${name} is arranged: ${made.output}`);
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** The DW-1337 walk of `route` at 1280 light, 720 light and 1280 dark, answering every entry the baseline does not hold. */
async function structural(page, route) {
  const found = [];
  const passes = [
    { viewport: VIEWPORTS.wide, theme: 'light', checks: INVARIANTS },
    { viewport: VIEWPORTS.narrow, theme: 'light', checks: ['name', 'min-width', 'overflow'] },
    { viewport: VIEWPORTS.wide, theme: 'dark', checks: ['contrast'] },
  ];
  const minimums = componentMinimums();
  const surfaces = {};
  for (const { viewport, theme, checks } of passes) {
    await settleViewport(page, viewport);
    await page.evaluate((dark) => document.documentElement.classList.toggle('ocu-theme-dark', dark), theme === 'dark');
    await frames(page);
    await transitionsSettled(page, config.navigationTimeoutMs);
    surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const { entries: measured } = await detectScreen(page, { route, checks, viewport: viewport.width, theme, minimums });
    found.push(...measured);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

/** The cells of the row whose first cell reads `name`, or `null`. */
function rowOf(page, name) {
  return page.evaluate(
    (rowSelector, wanted, textSelector) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((node) => {
        const cell = node.querySelector('[role="gridcell"]');
        return ((cell?.querySelector(textSelector) ?? cell)?.textContent ?? '').trim() === wanted;
      });
      return row === undefined ? null : Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => cell.textContent.trim());
    },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
}

/** Wait until the list holds a row named `name`, or, with `present` false, none. */
function rowPresent(page, name, present = true) {
  return page.waitForFunction(
    (rowSelector, wanted, textSelector, want) =>
      Array.from(document.querySelectorAll(rowSelector)).some((row) => {
        const cell = row.querySelector('[role="gridcell"]');
        return ((cell?.querySelector(textSelector) ?? cell)?.textContent ?? '').trim() === wanted;
      }) === want,
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    NAME_TEXT,
    present
  );
}

/** Wait until the row named `name` reads `text` in its cell number `cell`. */
function waitForCell(page, name, cell, text) {
  return page.waitForFunction(
    (rowSelector, wanted, textSelector, at, expected) => {
      const row = Array.from(document.querySelectorAll(rowSelector)).find((node) => {
        const first = node.querySelector('[role="gridcell"]');
        return ((first?.querySelector(textSelector) ?? first)?.textContent ?? '').trim() === wanted;
      });
      const cells = row === undefined ? [] : Array.from(row.querySelectorAll('[role="gridcell"]'));
      return cells[at]?.textContent.trim() === expected;
    },
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name,
    NAME_TEXT,
    cell,
    text
  );
}

/** Narrow the list to `name`, select its row, open its menu and choose the entry labeled `label`. */
async function rowAction(page, name, label) {
  await waitForRows(page, config.navigationTimeoutMs);
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await rowPresent(page, name);
  // The filter leaves the one row; its second cell is not the name.
  await clickRowCentre(page, { index: 0, cell: 1 });
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
  await page.evaluate((wanted) => {
    Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'))
      .find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted)
      .click();
  }, label);
}

/** Wait until the dialog closes. */
function dialogClosed(page) {
  return page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
}

/** Replace the text of the dialog field `selector` with `value`. */
async function fill(page, selector, value) {
  await page.click(selector, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  if (value !== '') await page.type(selector, value);
}

const field = (name) => `[data-interop-partner-field="${name}"]`;

/** Open the Business partners list for the probe namespace and wait for its rows and the namespace features. */
async function openList(page) {
  await waitForRows(page, config.navigationTimeoutMs);
  await waitForMapAnswered(page, config.navigationTimeoutMs);
}

/** Open the primary action's dialog on the current list. */
async function openPrimary(page) {
  await (await page.waitForSelector('.ocu-command-bar button.ocu-command-bar-primary', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector(field('Name'), { visible: true, timeout: config.navigationTimeoutMs });
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec writes probe business partners, so it runs only in a throwaway; ${config.container} is not one`);
  const cleared = probe('BPCLEAN', `$System.Status.IsOK(##class(${FIXTURE}).Clear())`);
  assert.equal(cleared.value, '1', `an earlier run's probe partners are removed: ${cleared.output}`);
  const removed = probe('BPPROBE', `$System.Status.IsOK(##class(${PROBE}).Remove())`);
  assert.equal(removed.value, '1', `an earlier run's probe production is removed: ${removed.output}`);
  const partner = probe('BPLISTED', `$System.Status.IsOK(##class(${FIXTURE}).PutPartner())`);
  assert.equal(partner.value, '1', `the probe partner is created: ${partner.output}`);
  created = true;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (created && /-ci$/.test(config.container)) {
      const removed = probe('BPGONE', `$System.Status.IsOK(##class(${FIXTURE}).Clear())_$System.Status.IsOK(##class(${PROBE}).Remove())`);
      assert.equal(removed.value, '11', `the probe partners and the probe production are removed: ${removed.output}`);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

// AC6, moved from the lookup spec. Mutation (Rule 19): drop the partners descriptor's primary action, regenerate the mirror, rebuild and
// redeploy -> the command bar offers none and the New business partner assertion goes red.
test('Business partners lists the probe partner under the published headers, offers New business partner and a row action menu, and the walk passes', async () => {
  const { context, page } = await signedInAt(browser, config, PARTNERS_URL, VIEWPORTS.wide);
  try {
    await openList(page);
    await rowPresent(page, LISTED);
    const headers = await page.$$eval('.ocu-data-table-header-label', (items) => items.map((item) => item.textContent.trim()));
    assert.deepEqual(
      headers.slice(0, 5),
      [STRINGS.tableColumnName, STRINGS.tableColumnDescription, STRINGS.interopPartnerColumnContact, STRINGS.interopPartnerColumnPhone, STRINGS.userFieldEmail],
      'the declared headers'
    );
    const row = await rowOf(page, LISTED);
    assert.deepEqual(row.slice(0, 5), [LISTED, 'Probe partner description', 'Pat Primary', '555-0101', 'pat@example.test'], 'the partner reads its description and its primary contact');
    assert.equal(await page.$eval('.ocu-command-bar button.ocu-command-bar-primary', (node) => node.textContent.trim()), STRINGS.interopPartnerAddAction, 'the command bar offers New business partner');
    await clickRowCentre(page, { index: 0, cell: 1 });
    await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs });
    assert.deepEqual(await structural(page, PARTNERS_ROUTE), [], 'Business partners: no violation beyond the baseline\'s entries');
  } finally {
    await context.close();
  }
});

// AC1, AC2. Mutation (Rule 19): make the Edit dialog send no `PrimaryPhone`, rebuild and redeploy -> the stored phone does not change and
// the changed-phone assertion goes red.
test('AC1, AC2: New business partner creates a partner, Edit changes its phone with the name read-only, and Remove types its name', async () => {
  drop();
  arrange(HELD);
  const { context, page } = await signedInAt(browser, config, PARTNERS_URL, VIEWPORTS.wide);
  const adds = [];
  const actions = [];
  page.on('request', (request) => {
    if (request.method() !== 'POST') return;
    const path = new URL(request.url()).pathname;
    if (path === ADD_PATH) adds.push(JSON.parse(request.postData() ?? '{}'));
    if (path === ACTION_PATH) actions.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await openList(page);
    await rowPresent(page, HELD);
    await openPrimary(page);
    const opened = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title')?.textContent?.trim(),
      text: document.querySelector('[role="dialog"]').textContent,
      groups: Array.from(document.querySelectorAll('[role="dialog"] fieldset legend')).map((node) => node.textContent.trim()),
    }));
    assert.equal(opened.title, STRINGS.interopPartnerAddAction, 'the dialog is titled with the published words');
    assert.ok(opened.text.includes(STRINGS.interopPartnerHelp), 'and states what a partner is and that saving one changes nothing in a production');
    assert.ok(!opened.text.includes(STRINGS.interopPartnerRenameNote), 'and carries no rename note for a new partner');
    assert.deepEqual(opened.groups, [STRINGS.interopPartnerColumnContact, STRINGS.interopPartnerAlternativeContact], 'in three groups, the contacts under their headings');

    await fill(page, field('Name'), HELD);
    await page.click('[data-interop-partner-confirm]');
    await page.waitForSelector('[data-interop-partner-reason]', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('[data-interop-partner-reason]', (node) => node.textContent.trim()), STRINGS.interopPartnerRefusalTaken, 'a held name is refused with the server\'s sentence');
    await fill(page, field('Name'), HELD.toUpperCase());
    await page.click('[data-interop-partner-confirm]');
    await page.waitForFunction((sentence) => document.querySelector('[data-interop-partner-reason]')?.textContent.trim() === sentence, { timeout: config.navigationTimeoutMs }, STRINGS.interopPartnerRefusalNameCase);
    assert.equal(stored(HELD.toUpperCase()), '<absent>', 'the same name in another letter case is refused too, and nothing is stored');

    await fill(page, field('Name'), PARTNER);
    await fill(page, field('Description'), 'a browser partner');
    await fill(page, field('PrimaryContact'), 'Pat Browser');
    await fill(page, field('PrimaryPhone'), '555-0111');
    await fill(page, field('AlternativeNotes'), 'line one');
    await page.click('[data-interop-partner-confirm]');
    await dialogClosed(page);
    await rowPresent(page, PARTNER);
    assert.equal(adds.at(-1).Name, PARTNER, 'the Save carries the name as typed');
    assert.equal(adds.at(-1).PrimaryPhone, '555-0111', 'and the phone');
    assert.equal(stored(PARTNER), 'a browser partner|Pat Browser|555-0111|line one', 'the partner is stored with what was typed');
    assert.deepEqual((await rowOf(page, PARTNER)).slice(1, 4), ['a browser partner', 'Pat Browser', '555-0111'], 'and the list shows it');

    await rowAction(page, PARTNER, STRINGS.agentPanelSecretWarningEdit);
    await page.waitForSelector(field('PrimaryPhone'), { visible: true, timeout: config.navigationTimeoutMs });
    const edit = await page.evaluate((name) => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
      note: document.querySelector('[data-interop-partner-rename-note]')?.textContent.trim() ?? '',
      readOnly: document.querySelector(name).readOnly,
      held: document.querySelector(name).value,
    }), field('Name'));
    assert.deepEqual(edit, { title: STRINGS.interopPartnerEditTitle.replace('<name>', PARTNER), note: STRINGS.interopPartnerRenameNote, readOnly: true, held: PARTNER }, 'Edit opens the same dialog on the row, with the name read-only and the rename note');
    assert.equal(await page.$eval(field('PrimaryPhone'), (node) => node.value), '555-0111', 'holding the phone the row reported');
    await fill(page, field('PrimaryPhone'), '555-0222');
    await page.click('[data-interop-partner-confirm]');
    await dialogClosed(page);
    await waitForCell(page, PARTNER, 3, '555-0222');
    const edit_sent = actions.at(-1);
    assert.deepEqual([edit_sent.action, edit_sent.id], ['edit', PARTNER], 'one edit, sent with the row key');
    assert.deepEqual(Object.keys(edit_sent.values).sort(), [...VALUE_FIELDS].sort(), 'carrying the thirteen values and never the name');
    assert.equal(edit_sent.values.PrimaryPhone, '555-0222', 'the changed phone among them');
    assert.equal(stored(PARTNER), 'a browser partner|Pat Browser|555-0222|line one', 'the stored phone changed and nothing else did');

    await rowAction(page, PARTNER, STRINGS.actionRemove);
    await page.waitForSelector('.ocu-typed-name-consequence', { visible: true, timeout: config.navigationTimeoutMs });
    const dialog = await page.evaluate(() => ({
      title: document.querySelector('[role="dialog"] .ocu-dialog-title').textContent.trim(),
      consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
    }));
    assert.deepEqual(dialog, { title: `${STRINGS.actionRemove} ${PARTNER}`, consequence: STRINGS.interopPartnerRemoveConsequence }, 'Remove asks for the name and states that it cannot be restored');
    const sent = actions.length;
    await page.type('.ocu-typed-name-field', PARTNER);
    await page.keyboard.press('Enter');
    await dialogClosed(page);
    await rowPresent(page, PARTNER, false);
    assert.equal(actions.length, sent + 1, 'one remove was sent');
    assert.deepEqual(actions.at(-1), { action: 'remove', id: PARTNER }, 'with the name once it matched');
    assert.equal(await settled(PARTNER, true), '<absent>', 'the partner is gone from the instance');
    assert.notEqual(stored(HELD), '<absent>', 'and the other partner is untouched');
  } finally {
    await context.close();
    drop();
  }
});

// AC3. Mutation (Rule 19): make `PartnerNamedByHere` read only the running production -> the stopped probe production's item is not
// found, the remove runs and this goes red.
test('AC3: a remove of a partner an item names shows the server\'s sentence on the list, and the partner stays', async () => {
  drop();
  arrange(NAMED);
  const made = probe('BPPROD', `$System.Status.IsOK(##class(${PROBE}).Remove())_$System.Status.IsOK(##class(${PROBE}).Create())_$System.Status.IsOK(##class(${PROBE}).AddItem("OcuPilotProbe226Item","OcuPilotProbe.Interop.Op",1,0,"BusinessPartner","${NAMED}","Host"))`);
  assert.equal(made.value, '111', `the probe production holds an item that names the partner: ${made.output}`);
  const { context, page } = await signedInAt(browser, config, PARTNERS_URL, VIEWPORTS.wide);
  try {
    await openList(page);
    await rowPresent(page, NAMED);
    await rowAction(page, NAMED, STRINGS.actionRemove);
    await page.waitForSelector('.ocu-typed-name-field', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('.ocu-typed-name-field', NAMED);
    await page.keyboard.press('Enter');
    await dialogClosed(page);
    await page.waitForFunction((sentence) => Array.from(document.querySelectorAll('.ocu-banner-message')).some((node) => node.textContent.trim() === sentence), { timeout: config.navigationTimeoutMs }, STRINGS.interopPartnerRefusalNamed);
    assert.ok((await rowOf(page, NAMED)) !== null, 'the partner is still listed');
    assert.notEqual(stored(NAMED), '<absent>', 'and still held');
  } finally {
    await context.close();
    probe('BPPRODGONE', `$System.Status.IsOK(##class(${PROBE}).Remove())`);
    drop();
  }
});
