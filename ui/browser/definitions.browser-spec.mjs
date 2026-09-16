/**
 * The Definition form and the Definitions list in a real browser, against the throwaway instance
 * (Story 3.5's Integration AC).
 *
 * Three claims, each asserted on rendered DOM and on the real URL rather than on store state:
 *
 * 1. **A definition is created through the form**, its saved sentence appears in the sticky bar,
 *    and the row appears in the list -- the whole path from a typed name to a row, through the
 *    shipped routes.
 * 2. **A declined leave-confirmation leaves the route unchanged** (AC2). The guard is a route
 *    guard, so the observable is the browser's own address bar after the navigation was refused.
 * 3. **The Definition form is routable and never advertised** (AC5): the Agent co-pilot side bar
 *    lists Definitions alone, and the command box offers no Definition screen, while the form's
 *    own URL renders the form.
 *
 * **It refuses the live container**, for the reason its siblings do: the throwaway is the instance
 * a browser run drives, and this spec creates a definition. It **creates the rows it filters and
 * tears them down** (DW-368): the throwaway starts with none, so every row on screen is this
 * spec's own and a filter leg has a whole list to be measured against.
 *
 * **No provider call is made, planned or otherwise.** Test connection is never pressed here; the
 * definition is created and saved disabled, which is what the routes do without a key.
 *
 * Run: `npm run test:browser` (after `npm run build` and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { filterToSubset, viewCount, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const LIST_URL = '/ocupilot/agent/definitions?ns=HSCUSTOM';
const FORM_URL = '/ocupilot/agent/definitions/edit?ns=HSCUSTOM';
const DEFINITIONS_PATH = '/api/ocupilot/agent/definitions';

/** Every definition this spec creates is named with this prefix and removed in `after`. */
const PREFIX = 'OcuPilotBrowserProbe';

const NAMES = [`${PREFIX}Alpha`, `${PREFIX}Beta`];

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec drives the throwaway, never the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  await removeProbeDefinitions();
  if (browser !== null) await browser.close();
});

/** The suite's own credentials, as the other browser specs read them. */
function credentials() {
  return { user: config.username, password: config.password };
}

function authHeader() {
  const { user, password } = credentials();
  return 'Basic ' + Buffer.from(`${user}:${password}`).toString('base64');
}

/**
 * Remove every definition this spec created, through the shipped route.
 *
 * Teardown is done over HTTP rather than through the browser: what has to be true afterwards is
 * that the instance holds none of them, and the delete route is the one thing that can say so.
 */
async function removeProbeDefinitions() {
  const answer = await fetch(`${config.origin}${DEFINITIONS_PATH}`, {
    headers: { Authorization: authHeader() },
  });
  if (!answer.ok) return;
  const body = await answer.json();
  for (const row of Array.isArray(body.definitions) ? body.definitions : []) {
    if (typeof row?.name !== 'string' || !row.name.startsWith(PREFIX)) continue;
    await fetch(`${config.origin}${DEFINITIONS_PATH}/${encodeURIComponent(row.id)}`, {
      method: 'DELETE',
      headers: { Authorization: authHeader() },
    });
  }
}

/** A fresh context signed in through the shell's own form, landed at `url`. */
async function signedInAt(url) {
  const { user, password } = credentials();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', user);
  await page.type('#ocu-signin-password', password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  // The first-login gate takes an administrator to the Definition form on an instance with no
  // enabled definition, whatever URL was asked for (Story 3.6). Back returns to this one -- a
  // no-op for the legs whose own URL already IS the form.
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  return { context, page };
}

/** Type `value` into the form control `id`, replacing whatever is there. */
async function fill(page, id, value) {
  await page.waitForSelector(`#${id}`, { visible: true, timeout: config.navigationTimeoutMs });
  await page.click(`#${id}`, { clickCount: 3 });
  await page.type(`#${id}`, value);
}

/** The path the browser is actually on, with no origin and no fragment. */
function pathOf(page) {
  return new URL(page.url()).pathname;
}

/** The labels the command box's Screens group is offering, right now. */
function screensNow(page) {
  return page.$$eval(
    '.ocu-command-box-group-screens [role="option"] .ocu-command-box-option-label',
    (nodes) => nodes.map((node) => node.textContent.trim())
  );
}

/**
 * Type `text` into the open command box and answer the Screens group's labels, once the view that
 * text produces has actually landed (DW-374, `list-spec.mjs`'s `filterToSubset`).
 *
 * **The whole text must be in the field before the result is believed**, and then the option count
 * must have stopped moving: `page.type` enters one character at a time and the box re-filters on
 * each, so a read taken between the keystrokes and the re-render answers the *unfiltered* list --
 * which is a larger set than the one asserted, and so a red that says nothing about the subject.
 * Observed once in a full-suite run of this file, where the assertion reported all nine screens.
 */
async function screensOffered(page, text) {
  const unfiltered = (await screensNow(page)).length;
  assert.ok(unfiltered > 1, `the unfiltered box offers more than one screen to narrow: ${unfiltered}`);
  await page.type('#ocu-command-box-field', text);
  // Both halves, or an intermediate state passes for the answer: the field holding the whole text
  // (a prefix filters to a different, larger subset), and a group that has actually narrowed (the
  // field can hold the whole text one frame before the view that text produces has landed).
  await page.waitForFunction(
    (typed, before) => {
      const field = document.querySelector('#ocu-command-box-field');
      if (field === null || field.value !== typed) return false;
      const options = document.querySelectorAll(
        '.ocu-command-box-group-screens [role="option"] .ocu-command-box-option-label'
      );
      return options.length < before;
    },
    { timeout: config.navigationTimeoutMs },
    text,
    unfiltered
  );
  // And then it must have stopped moving.
  // Bounded on purpose: a list that never stops moving is a defect this helper reports rather than
  // hangs on. Ten reads is far more than the one re-render a last keystroke costs.
  let settled = await screensNow(page);
  let stable = false;
  for (let read = 0; read < 10 && !stable; read += 1) {
    const again = await screensNow(page);
    stable = again.length === settled.length && again.every((label, index) => label === settled[index]);
    settled = again;
  }
  if (!stable) {
    throw new Error(
      `the command box's Screens group never settled on ${JSON.stringify(text)} (last ` +
        `${JSON.stringify(settled)}); it is still re-rendering after the whole filter text was entered`
    );
  }
  return settled;
}

test('Integration AC: a definition created through the form shows its saved sentence and appears in the list', async () => {
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await page.waitForSelector('#ocu-definition-name', { visible: true, timeout: config.navigationTimeoutMs });
    await fill(page, 'ocu-definition-name', NAMES[0]);

    const save = (await page.$$('.ocu-form-bar-actions button')).at(-1);
    assert.ok(save, 'the sticky bar carries a primary action');
    assert.equal((await save.evaluate((node) => node.textContent.trim())), STRINGS.actionCreate, 'labelled Create on a create route');
    await save.click();

    await page.waitForFunction(
      (sentence) => document.querySelector('.ocu-form-bar-status')?.textContent?.includes(sentence) === true,
      { timeout: config.navigationTimeoutMs },
      STRINGS.formSavedPendingTest
    );
    // The definition was created without a key, so the instance answers it disabled and the bar
    // says so -- rendered from the response body, never from what was sent.
    const status = await page.$eval('.ocu-form-bar-status', (node) => node.textContent.trim());
    assert.ok(status.includes(STRINGS.formSavedPendingTest), `the sticky bar reads the pending-test sentence: ${status}`);

    // AC3: the route is replaced with the new definition's editor, so a reload lands on the entity.
    await page.waitForFunction(
      () => /\/agent\/definitions\/edit\/[^/]+$/.test(new URL(window.location.href).pathname),
      { timeout: config.navigationTimeoutMs }
    );

    await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
    // The first-login gate moves an administrator off any route on an instance with no enabled
    // definition (Story 3.6). Back returns to the one this leg asked for.
    await leaveFirstLoginGate(page, config.navigationTimeoutMs, LIST_URL);
    await waitForRows(page, config.navigationTimeoutMs);
    const names = await page.$$eval('[role="grid"] .ocu-data-table-body [role="row"]', (rows) =>
      rows.map((row) => row.textContent)
    );
    assert.ok(
      names.some((text) => text.includes(NAMES[0])),
      `the row the form created is in the list: ${JSON.stringify(names)}`
    );
  } finally {
    await context.close();
  }
});

test('AC4: the list shows name, provider, model, enabled and default, and filters over the whole list', async () => {
  // A second definition, so the filter has a whole list to be measured against (DW-368).
  const create = await fetch(`${config.origin}${DEFINITIONS_PATH}`, {
    method: 'POST',
    headers: { Authorization: authHeader(), 'Content-Type': 'application/json' },
    body: JSON.stringify({ name: NAMES[1], provider: 'anthropic', credType: 'creds', credentialName: 'OcuPilotAnthropic' }),
  });
  assert.equal(create.status, 201, 'the second probe definition is created');

  const { context, page } = await signedInAt(LIST_URL);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    // `STRINGS` is this process's, not the page's: the actions column's hidden label is passed in
    // rather than closed over, because the browser evaluates this function in its own realm.
    const headers = await page.$$eval(
      '[role="grid"] [role="columnheader"] .ocu-data-table-header-label',
      (cells, actionsLabel) => cells.map((cell) => cell.textContent.trim()).filter((text) => text !== actionsLabel),
      STRINGS.commandBoxGroupActions
    );
    assert.deepEqual(
      headers,
      [
        STRINGS.tableColumnName,
        STRINGS.tableColumnProvider,
        STRINGS.tableColumnModel,
        STRINGS.tableColumnEnabled,
        STRINGS.tableColumnDefault,
      ],
      'the five columns EXPERIENCE.md publishes for this list'
    );

    const total = await viewCount(page);
    assert.ok(total >= 2, `the list carries both probe rows: ${total}`);
    // `filterToSubset` clears to the whole list first and requires 0 < kept < total, and the text
    // names one row rather than relying on a word the corpus happens not to repeat (DW-368).
    await filterToSubset(page, {
      text: NAMES[1],
      expectRow: NAMES[1],
      total,
      timeoutMs: config.navigationTimeoutMs,
    });
  } finally {
    await context.close();
  }
});

test('AC2: a declined leave-confirmation leaves the route unchanged', async () => {
  const { context, page } = await signedInAt(FORM_URL);
  try {
    const before = pathOf(page);
    await page.waitForSelector('#ocu-definition-name', { visible: true, timeout: config.navigationTimeoutMs });
    await fill(page, 'ocu-definition-name', `${PREFIX}NeverSaved`);

    // Any caller: the side bar's own entry, which navigates through `Router.navigateByUrl` like
    // every other surface in the shell.
    const entry = await page.$('app-side-bar .ocu-side-bar-item');
    assert.ok(entry, 'the Agent co-pilot side bar lists an entry to navigate to');
    await entry.click();

    await page.waitForSelector('[role="dialog"]', { visible: true, timeout: config.navigationTimeoutMs });
    const heading = await page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim());
    assert.equal(heading, STRINGS.formLeaveWithoutSaving, 'the guard asks the published question');

    const decline = await page.$('[role="dialog"] .ocu-dialog-actions button');
    assert.equal(await decline.evaluate((node) => node.textContent.trim()), STRINGS.actionCancel);
    await decline.click();
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, {
      timeout: config.navigationTimeoutMs,
    });

    assert.equal(pathOf(page), before, 'the real URL did not move, which is what refusing the navigation means');
    assert.equal(
      await page.$eval('#ocu-definition-name', (node) => node.value),
      `${PREFIX}NeverSaved`,
      'and the unsaved work is still on screen'
    );
  } finally {
    await context.close();
  }
});

test('AC2: a refused Save focuses the error summary, then the first invalid field, in a real browser', async () => {
  // `definition-form.page.spec.ts` pins the `role="alert"` / `aria-invalid` / `aria-describedby`
  // wiring under jsdom, which computes no layout and enforces none of a real browser's rules
  // about what a page may focus. This is the one place `document.activeElement` -- a real
  // browser's own answer, not a store read -- is asked what happened, and in what order: the
  // Design Notes call for the summary focused first and the field second, "so the reader hears
  // the whole list and then lands on the control they have to change", which a snapshot of the
  // final active element alone cannot tell apart from the field being focused directly.
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await page.waitForSelector('#ocu-definition-name', { visible: true, timeout: config.navigationTimeoutMs });

    await page.evaluate(() => {
      window.__focusLog = [];
      document.addEventListener(
        'focus',
        (event) => {
          const target = event.target;
          window.__focusLog.push(target && target.id ? target.id : (target?.className ?? ''));
        },
        true
      );
    });

    // The create form starts with an empty name (DW-340's write-only key applies to the key
    // field alone; name is never pre-filled from anywhere), so pressing Save with nothing typed
    // is a real 422 from the real server, `name` first in `AgentRules.Validate`'s declared order.
    const save = (await page.$$('.ocu-form-bar-actions button')).at(-1);
    assert.ok(save, 'the sticky bar carries a primary action');
    await save.click();

    await page.waitForSelector('.ocu-form-summary[role="alert"]', { timeout: config.navigationTimeoutMs });
    await page.waitForFunction(
      () => document.activeElement?.id === 'ocu-definition-name',
      { timeout: config.navigationTimeoutMs }
    );

    const log = await page.evaluate(() => window.__focusLog);
    const summaryIndex = log.findIndex((entry) => entry.includes('ocu-form-summary'));
    const nameIndex = log.lastIndexOf('ocu-definition-name');
    assert.ok(summaryIndex >= 0, `the error summary itself received DOM focus: ${JSON.stringify(log)}`);
    assert.ok(
      nameIndex > summaryIndex,
      `the first invalid field is focused after the summary, never before it: ${JSON.stringify(log)}`
    );

    assert.equal(
      await page.$eval('#ocu-definition-name', (node) => node.getAttribute('aria-invalid')),
      'true',
      'the field the focus landed on is the one the server named invalid'
    );
    const describedBy = await page.$eval('#ocu-definition-name', (node) => node.getAttribute('aria-describedby'));
    assert.ok(describedBy && describedBy.length > 0, 'and it is wired to its own reason text');
  } finally {
    await context.close();
  }
});

test('AC5: the form is routable and listed nowhere -- one side-bar entry, and no Definition in the command box', async () => {
  const { context, page } = await signedInAt(LIST_URL);
  try {
    const entries = await page.$$eval('app-side-bar .ocu-side-bar-label', (nodes) =>
      nodes.map((node) => node.textContent.trim())
    );
    assert.deepEqual(entries, [STRINGS.agentDefinitionListLabel], 'the area lists Definitions alone');

    await page.keyboard.down('Control');
    await page.keyboard.press('KeyK');
    await page.keyboard.up('Control');
    await page.waitForSelector('#ocu-command-box-list', { visible: true, timeout: config.navigationTimeoutMs });
    // The option's own label element, not the option's whole textContent: an option renders its
    // label span followed by its area-detail span, and Angular drops the whitespace-only node
    // between them, so the whole option reads the label immediately followed by the area name,
    // with no separator -- which starts with neither `"Definition "` nor equals `"Definition"`.
    // Both of the assertions that stood here therefore passed whether or not the form was
    // offered.
    const offered = await screensOffered(page, 'Definition');
    assert.deepEqual(
      offered,
      [STRINGS.agentDefinitionListLabel],
      `the command box offers the list alone, and no Definition form: ${JSON.stringify(offered)}`
    );

    await page.keyboard.press('Escape');
    // ...and it is still reachable by its own URL, which is the other half of the sentinel.
    await page.goto(`${config.origin}${FORM_URL}`, { waitUntil: 'networkidle2' });
    await page.waitForSelector('#ocu-definition-name', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(pathOf(page), '/ocupilot/agent/definitions/edit', 'the unlisted screen renders at its own route');
  } finally {
    await context.close();
  }
});
