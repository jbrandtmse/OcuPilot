/**
 * Story 7.10 end to end in a real browser against the throwaway instance: the application error
 * log's one Delete, on every drill level, whose scope is the level -- one error from the list's row
 * menu, a date from the command bar, and a whole namespace from the namespaces level.
 *
 * **It deletes real application errors.** It refuses outright to run outside a `-ci` throwaway, it
 * seeds every error it removes through `OcuPilot.Test.ErrorDelete`'s own guarded helpers, in that
 * class's own namespace, and its `after` hook clears that namespace whatever happened above.
 *
 * **What only a browser can answer here:** that the shipped bundle draws the row menu on the drill
 * levels, that the typed-name dialog names each scope and releases only on its last part, that the
 * command bar acts on the drill's own selection, and that the drill -- which binds no
 * `RefreshService` -- re-reads and steps up on the composite `deleted` event. Every request carries
 * the route's `?ns=HSCUSTOM`, and the posted id names the drilled namespace all the same.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/error-log-actions.browser-spec.mjs`. A spec run against a bundle that was not rebuilt
 * reads the old client and proves nothing.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
import { markerValue, requireFreeSlot, runIris as sharedRunIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

/** The route carries another namespace on purpose: the drill, not `?ns=`, names the target. */
const LOG_URL = '/ocupilot/logs/errors?ns=HSCUSTOM';
const ACTION_PATH = '/api/ocupilot/screens/logs.applicationerrors/action';

/** The namespace this spec seeds and clears -- `OcuPilot.Test.ErrorDelete`'s own. */
const TARGET_NAMESPACE = 'USER';

/** The composite id's separator, as an escape (Rule 14). */
const SEP = '\u0001';

const DRILL_ROW = '[role="grid"] .ocu-data-table-body [role="row"]';

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec deletes application errors, so it never runs inside the live container');
  assert.match(
    config.container,
    /-ci$/,
    `this spec deletes application errors on the instance, so it runs only in a throwaway; ${config.container} is not one`
  );
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (!/-ci$/.test(config.container)) return;
  clearNamespace();
});

function runIris(lines) {
  return sharedRunIris(config.container, lines);
}

/** Seed one application error into the target namespace and answer its date and number. */
function seedError() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.ErrorDelete).Seed(.d,.n)`,
    `Write "OCU-EASEED-START:"_$Select($System.Status.IsOK(sc):d_"|"_n,1:"")_":OCU-EASEED-END",!`,
  ]);
  const [date, number] = (markerValue(output, 'EASEED') ?? '').split('|');
  assert.ok(date !== undefined && date !== '' && number !== undefined && number !== '', `the spec seeds an application error: ${output}`);
  return { date, number };
}

/** The target namespace's `date|number` entries now, or `null` when it holds none. */
function entries() {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.ErrorDelete).Enumerate("${TARGET_NAMESPACE}",.r,.h,.f)`,
    `Set out="" If $IsObject($Get(r)) { Set it=r.entries.%GetIterator() While it.%GetNext(.k,.e) { Set out=out_e.date_"#"_e.errorNumber_"," } }`,
    `Write "OCU-EAENTRIES-START:"_$Select($IsObject($Get(r)):out,1:"none")_":OCU-EAENTRIES-END",!`,
  ]);
  const value = markerValue(output, 'EAENTRIES') ?? 'none';
  return value === 'none' ? null : value.split(',').filter((entry) => entry !== '');
}

function clearNamespace() {
  runIris([`Do ##class(OcuPilot.Test.ErrorDelete).Clear()`, `Write "OCU-EACLEAR-START:1:OCU-EACLEAR-END",!`]);
}

/** A signed-in page at the log, recording every POST to the error log's action route. */
async function signedInRecording() {
  await requireFreeSlot(config);
  const { context, page } = await signedInAt(browser, config, LOG_URL);
  const posts = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === ACTION_PATH) posts.push(request.postData() ?? '');
  });
  return { context, page, posts };
}

/** The first cell of every rendered row. */
function firstCells(page) {
  return page.$$eval(DRILL_ROW, (rows) =>
    rows.map((row) => (row.querySelector('[role="gridcell"]')?.textContent ?? '').trim())
  );
}

/** Wait until a row whose first cell reads `text` is (or is no longer) rendered. */
async function waitForRow(page, text, present = true) {
  await page.waitForFunction(
    (selector, wanted, want) =>
      Array.from(document.querySelectorAll(selector)).some(
        (row) => (row.querySelector('[role="gridcell"]')?.textContent ?? '').trim() === wanted
      ) === want,
    { timeout: config.navigationTimeoutMs },
    DRILL_ROW,
    text,
    present
  );
}

/** Open the row whose first cell reads `text` through its link, and wait for the scope line. */
async function drillInto(page, text, scope) {
  await waitForRow(page, text);
  await page.evaluate(
    (selector, wanted) => {
      const row = Array.from(document.querySelectorAll(selector)).find(
        (candidate) => (candidate.querySelector('[role="gridcell"]')?.textContent ?? '').trim() === wanted
      );
      row.querySelector('.ocu-data-table-link').click();
    },
    DRILL_ROW,
    text
  );
  await page.waitForFunction(
    (wanted) => (document.querySelector('[data-ocu-drill="scope"]')?.textContent ?? '').trim() === wanted,
    { timeout: config.navigationTimeoutMs },
    scope
  );
}

/** Open the row menu of the row whose first cell reads `text`, and answer its entries' labels. */
async function openRowMenu(page, text) {
  await waitForRow(page, text);
  await page.evaluate(
    (selector, wanted) => {
      const row = Array.from(document.querySelectorAll(selector)).find(
        (candidate) => (candidate.querySelector('[role="gridcell"]')?.textContent ?? '').trim() === wanted
      );
      row.querySelector('.ocu-data-table-trigger').click();
    },
    DRILL_ROW,
    text
  );
  await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
  return page.$$eval('[role="menu"] [role="menuitem"]', (items) =>
    items.map((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() ?? '')
  );
}

async function chooseMenu(page, label) {
  await page.evaluate((wanted) => {
    const items = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'));
    items.find((item) => item.textContent.trim().startsWith(wanted)).click();
  }, label);
}

/** The open typed-name dialog's title and body. */
async function openedDialog(page) {
  await page.waitForSelector('app-typed-name-dialog', { timeout: config.navigationTimeoutMs });
  return page.evaluate(() => ({
    title: document.querySelector('.ocu-dialog-title').textContent.trim(),
    consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
    released: document.querySelector('.ocu-button-destructive').getAttribute('aria-disabled'),
  }));
}

async function typeAndConfirm(page, typed) {
  await page.click('.ocu-typed-name-field', { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type('.ocu-typed-name-field', typed);
  await page.waitForFunction(
    () => document.querySelector('.ocu-button-destructive')?.getAttribute('aria-disabled') === null,
    { timeout: config.navigationTimeoutMs }
  );
  await page.click('.ocu-button-destructive');
}

test('AC1: one error from the list\u2019s row menu -- the dialog names it, a mismatch sends nothing, and only that error goes', async () => {
  // Mutation (Rule 19): `ErrorDelete` `SCREENACTIONS ""`, reloaded -- the route finds no tool for
  // the action and answers 404, the row never leaves, and this goes red.
  clearNamespace();
  const first = seedError();
  const second = seedError();
  const { context, page, posts } = await signedInRecording();
  try {
    await drillInto(page, TARGET_NAMESPACE, TARGET_NAMESPACE);
    await drillInto(page, first.date, `${TARGET_NAMESPACE} \u00b7 ${first.date}`);
    const menu = await openRowMenu(page, first.number);
    assert.deepEqual(menu, [STRINGS.actionDelete], 'the row menu offers the one Delete');
    await chooseMenu(page, STRINGS.actionDelete);

    const opened = await openedDialog(page);
    assert.equal(opened.title, `${STRINGS.errorDeleteOneVerb} ${first.number}`, 'the title names the error');
    assert.equal(opened.consequence, STRINGS.errorDeleteOneConsequence, 'the body states the one-error consequence');
    assert.equal(opened.released, 'true', 'and the button is aria-disabled until the number is typed');

    await page.type('.ocu-typed-name-field', `${first.number}0`);
    await page.evaluate(() => document.querySelector('.ocu-typed-name-field').blur());
    await page.waitForSelector('.ocu-typed-name-mismatch', { timeout: config.navigationTimeoutMs });
    await page.click('.ocu-button-destructive');
    assert.equal(posts.length, 0, 'a mismatched number sends nothing');

    await typeAndConfirm(page, first.number);
    await waitForRow(page, first.number, false);
    assert.equal(posts.length, 1, `one request: ${JSON.stringify(posts)}`);
    assert.deepEqual(JSON.parse(posts[0]), {
      action: 'delete',
      id: `${TARGET_NAMESPACE}${SEP}${first.date}${SEP}${first.number}`,
    }, 'naming the drilled namespace, never the route\u2019s');
    assert.ok((await firstCells(page)).includes(second.number), 'the other error is still listed');
    const left = entries();
    assert.ok(left !== null && !left.includes(`${first.date}#${first.number}`), `the named error is gone: ${left}`);
    assert.ok(left.includes(`${second.date}#${second.number}`), `and the other remains: ${left}`);
  } finally {
    await context.close();
    clearNamespace();
  }
});

test('AC1: a date from the command bar -- the dialog names the date, and the drill steps up once the namespace is empty', async () => {
  // Mutation (Rule 19): drop `SCOPED_TARGETS` from the handler, rebuild and redeploy -> the title
  // reads the joined id and the consequence the namespace's, red.
  clearNamespace();
  const seeded = seedError();
  seedError();
  const { context, page, posts } = await signedInRecording();
  try {
    await drillInto(page, TARGET_NAMESPACE, TARGET_NAMESPACE);
    await waitForRow(page, seeded.date);
    // A click on the row outside its link selects it; the command bar acts on that selection.
    await page.evaluate(
      (selector, wanted) => {
        const row = Array.from(document.querySelectorAll(selector)).find(
          (candidate) => (candidate.querySelector('[role="gridcell"]')?.textContent ?? '').trim() === wanted
        );
        row.querySelectorAll('[role="gridcell"]')[1].click();
      },
      DRILL_ROW,
      seeded.date
    );
    await page.waitForFunction(
      (wanted) =>
        Array.from(document.querySelectorAll('.ocu-command-bar-action')).find(
          (button) => button.textContent.trim() === wanted
        )?.getAttribute('aria-disabled') === null,
      { timeout: config.navigationTimeoutMs },
      STRINGS.actionDelete
    );
    await page.evaluate((wanted) => {
      Array.from(document.querySelectorAll('.ocu-command-bar-action'))
        .find((button) => button.textContent.trim() === wanted)
        .click();
    }, STRINGS.actionDelete);

    const opened = await openedDialog(page);
    assert.equal(opened.title, `${STRINGS.errorDeleteDateVerb} ${seeded.date}`, 'the title names the date');
    assert.equal(opened.consequence, STRINGS.errorDeleteDateConsequence, 'the body states the date consequence');

    await typeAndConfirm(page, seeded.date);
    await page.waitForFunction(
      () => (document.querySelector('[data-ocu-drill="scope"]')?.textContent ?? '').trim() === '',
      { timeout: config.navigationTimeoutMs }
    );
    assert.deepEqual(JSON.parse(posts[0]), { action: 'delete', id: `${TARGET_NAMESPACE}${SEP}${seeded.date}` });
    assert.equal(entries(), null, 'the namespace\u2019s only date held both errors, so it holds none now');
  } finally {
    await context.close();
    clearNamespace();
  }
});

test('AC1: a whole namespace from the namespaces level -- the dialog names it, and its row leaves', async () => {
  clearNamespace();
  seedError();
  const { context, page, posts } = await signedInRecording();
  try {
    const menu = await openRowMenu(page, TARGET_NAMESPACE);
    assert.deepEqual(menu, [STRINGS.actionDelete]);
    await chooseMenu(page, STRINGS.actionDelete);
    const opened = await openedDialog(page);
    assert.equal(opened.title, `${STRINGS.errorDeleteEveryVerb} ${TARGET_NAMESPACE}`, 'the title names the namespace');
    assert.equal(opened.consequence, STRINGS.errorDeleteEveryConsequence, 'the body states the namespace consequence');

    await typeAndConfirm(page, TARGET_NAMESPACE);
    await waitForRow(page, TARGET_NAMESPACE, false);
    assert.deepEqual(JSON.parse(posts[0]), { action: 'delete', id: TARGET_NAMESPACE });
    assert.equal(entries(), null, 'and the namespace records no application errors');
  } finally {
    await context.close();
    clearNamespace();
  }
});
