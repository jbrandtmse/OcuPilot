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
 * 4. **A keyless local model is configurable through the form** (Story 10.3's AC1 and AC3): choosing the
 *    OpenAI-compatible provider offers the local-model declaration and the no-API-key choice, and
 *    a plain-`http://` loopback endpoint saved with neither a key nor a credential name is
 *    accepted with no violation on the endpoint field.
 * 5. **The Temperature field follows the catalog's `acceptsTemperature` column** (Story 10.4):
 *    readonly and captioned on the Anthropic row, empty under "Provider default" on OpenAI, each
 *    state passing every DW-1337 invariant, and a definition saved from the second stores no
 *    temperature.
 * 6. **A test that waited its bound reads the published sentence** (Story 10.5): each timeout
 *    code's 504 envelope renders its Fixed strings sentence, resolved from the detail, on the
 *    failure line, which passes every DW-1337 invariant.
 *
 * **It refuses the live container**, for the reason its siblings do: the throwaway is the instance
 * a browser run drives, and this spec creates a definition. It **creates the rows it filters and
 * tears them down** (DW-368): the throwaway starts with none, so every row on screen is this
 * spec's own and a filter leg has a whole list to be measured against.
 *
 * **No provider call is made, planned or otherwise.** Test connection is pressed only in claim 6,
 * where its `POST .../test` is intercepted in the browser and answered there, so it never reaches
 * the instance; every definition is created and saved disabled, which is what the routes do
 * without a key.
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
import { resetRememberedState } from './preferences-reset.mjs';
import {
  INVARIANTS,
  VIEWPORTS,
  compare,
  componentMinimums,
  detectScreen,
  readBaseline,
  toggleThemeThroughMenu,
} from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const LIST_URL = '/ocupilot/agent/definitions?ns=HSCUSTOM';
const FORM_URL = '/ocupilot/agent/definitions/edit?ns=HSCUSTOM';
const DEFINITIONS_PATH = '/api/ocupilot/agent/definitions';

/** Every definition this spec creates is named with this prefix and removed in `after`. */
const PREFIX = 'OcuPilotBrowserProbe';

const NAMES = [`${PREFIX}Alpha`, `${PREFIX}Beta`, `${PREFIX}Local`, `${PREFIX}Sampling`, `${PREFIX}Timeout`];

/** The form's key route in the structural baseline. */
const FORM_ROUTE = 'agent/definitions/edit';

/** The loopback endpoint the local-model leg stores. Nothing here connects to it. */
const LOCAL_ENDPOINT = 'http://127.0.0.1:11434/v1';

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
  // Story 15.5: the remembered screen and shell state lives on the instance now, keyed by the
  // one account every spec signs in as, so a fresh context is no longer a fresh slate on its
  // own -- see `preferences-reset.mjs`.
  await resetRememberedState();
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
  //
  // **Each read is separated by a rendered frame.** Back-to-back `$$eval` calls can both observe
  // the same pending state -- neither yields to the renderer, so a re-render queued by the last
  // keystroke has no opportunity to land between them, and two equal reads of a stale list read
  // as settled. Observed on a full-suite run once the Agent co-pilot area listed a second screen:
  // this helper answered the four screens whose labels share a letter with an early keystroke
  // rather than the one the whole text selects.
  //
  // Three consecutive equal reads, not two, and the loop is bounded on purpose: a list that never
  // stops moving is a defect this helper reports rather than hangs on.
  const frame = () =>
    page.evaluate(
      () => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)))
    );
  let settled = await screensNow(page);
  let identical = 0;
  for (let read = 0; read < 12 && identical < 2; read += 1) {
    await frame();
    const again = await screensNow(page);
    identical =
      again.length === settled.length && again.every((label, index) => label === settled[index])
        ? identical + 1
        : 0;
    settled = again;
  }
  const stable = identical >= 2;
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

test('AC5: the form is routable and listed nowhere -- the area\'s listed entries, and no Definition in the command box', async () => {
  const { context, page } = await signedInAt(LIST_URL);
  try {
    const entries = await page.$$eval('app-side-bar .ocu-side-bar-label', (nodes) =>
      nodes.map((node) => node.textContent.trim())
    );
    // The area's two side-bar entries, in declared order. The Definition form is not among them,
    // which is the sentinel this test is about: it is built, routed and listed nowhere.
    assert.deepEqual(
      entries,
      [STRINGS.agentDefinitionListLabel, STRINGS.agentSwitchesLabel],
      'the area lists Definitions then Switches, and no form'
    );

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

test('Story 10.3 AC1/AC3: the OpenAI-compatible provider offers the local-model controls, and a keyless loopback endpoint saves', async () => {
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await page.waitForSelector('#ocu-definition-name', { visible: true, timeout: config.navigationTimeoutMs });
    await fill(page, 'ocu-definition-name', NAMES[2]);

    // Neither local-model control is on screen for the first row, which is a vendor family: they
    // are gated on the catalog's own `allowsLocal`, and only the compatible row sets it.
    assert.equal(await page.$('#ocu-definition-markedLocal'), null, 'no local-model control for a vendor provider');

    // The provider select carries a row whose value is the shipped catalog key.
    await page.select('#ocu-definition-provider', 'compatible');
    await page.waitForSelector('#ocu-definition-markedLocal', { visible: true, timeout: config.navigationTimeoutMs });
    await page.waitForSelector('#ocu-definition-credType', { visible: true, timeout: config.navigationTimeoutMs });

    await fill(page, 'ocu-definition-endpointUrl', LOCAL_ENDPOINT);
    await page.click('#ocu-definition-markedLocal');
    await page.click('#ocu-definition-credType');

    const save = (await page.$$('.ocu-form-bar-actions button')).at(-1);
    assert.ok(save, 'the sticky bar carries a primary action');
    await save.click();

    // The definition is accepted: the pending-test sentence appears, and no violation was
    // rendered on the endpoint field or anywhere else.
    await page.waitForFunction(
      (sentence) => document.querySelector('.ocu-form-bar-status')?.textContent?.includes(sentence) === true,
      { timeout: config.navigationTimeoutMs },
      STRINGS.formSavedPendingTest
    );
    assert.equal(
      await page.$('#ocu-definition-endpointUrl-reason'),
      null,
      'no violation is rendered on the endpoint field'
    );
    const summary = await page.$$eval('.ocu-form-summary-list li', (nodes) => nodes.map((node) => node.textContent.trim()));
    assert.deepEqual(summary, [], `and the error summary is empty: ${JSON.stringify(summary)}`);

    // Read back through the routes, so the claim is about what the instance stored. The list
    // answers the selection projection, so the endpoint and the two declarations are read from the
    // single-definition route, which answers the full one.
    const answer = await fetch(`${config.origin}${DEFINITIONS_PATH}`, { headers: { Authorization: authHeader() } });
    assert.ok(answer.ok, 'the definitions route answers');
    const body = await answer.json();
    const listed = (Array.isArray(body.definitions) ? body.definitions : []).find((row) => row?.name === NAMES[2]);
    assert.ok(listed, `the definition was stored: ${JSON.stringify(body.definitions)}`);
    assert.equal(listed.provider, 'compatible', 'on the OpenAI-compatible row');

    const one = await fetch(`${config.origin}${DEFINITIONS_PATH}/${encodeURIComponent(listed.id)}`, {
      headers: { Authorization: authHeader() },
    });
    assert.ok(one.ok, 'the single-definition route answers');
    const stored = await one.json();
    assert.equal(stored.endpointUrl, LOCAL_ENDPOINT, 'carrying the loopback endpoint the form sent');
    assert.equal(stored.markedLocal, true, 'declared local');
    assert.equal(stored.credType, 'none', 'and naming no credential at all');
    assert.equal(stored.httpAcknowledged, false, 'with no acknowledgment asked for, there being no key to expose');
  } finally {
    await context.close();
  }
});

/** The Temperature field's rendered state: value, placeholder, the two inert attributes, and its caption. */
function temperatureState(page) {
  return page.$eval('#ocu-definition-temperature', (input) => {
    const described = input.getAttribute('aria-describedby');
    return {
      value: input.value,
      placeholder: input.getAttribute('placeholder'),
      readonly: input.hasAttribute('readonly'),
      ariaDisabled: input.getAttribute('aria-disabled'),
      describedBy: described,
      caption: document.querySelector('#ocu-definition-temperature-caption')?.textContent?.trim() ?? null,
    };
  });
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/**
 * Every DW-1337 invariant over the form as it stands, at 1280 and 720 px in light and at 1280 px in
 * dark, answered as the entries the committed baseline does not already hold for this route. The
 * theme is flipped through the account menu and flipped back before returning.
 */
async function freshViolations(page) {
  const minimums = componentMinimums();
  const baseline = (readBaseline()?.entries ?? []).filter((entry) => entry.route === FORM_ROUTE);
  const requests = { inflight: new Set(), last: 0 };
  const found = [];
  for (const { viewport, theme } of [
    { viewport: VIEWPORTS.wide, theme: 'light' },
    { viewport: VIEWPORTS.narrow, theme: 'light' },
    { viewport: VIEWPORTS.wide, theme: 'dark' },
  ]) {
    await page.setViewport(viewport);
    if (theme === 'dark') await toggleThemeThroughMenu(page, requests, config.navigationTimeoutMs);
    try {
      await frames(page);
      const { entries } = await detectScreen(page, { route: FORM_ROUTE, checks: INVARIANTS, viewport: viewport.width, theme, minimums });
      found.push(...entries);
    } finally {
      if (theme === 'dark') await toggleThemeThroughMenu(page, requests, config.navigationTimeoutMs);
    }
  }
  await page.setViewport(VIEWPORTS.wide);
  return compare(found, baseline).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

test('Story 10.4: the Temperature field follows the catalog column, passes every invariant, and saves unset', async () => {
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await page.emulateMediaFeatures([{ name: 'prefers-reduced-motion', value: 'reduce' }]);
    await page.setViewport(VIEWPORTS.wide);
    await page.waitForSelector('#ocu-definition-name', { visible: true, timeout: config.navigationTimeoutMs });
    await fill(page, 'ocu-definition-name', NAMES[3]);
    assert.equal(
      await page.$eval('#ocu-definition-provider', (select) => select.value),
      'anthropic',
      'the form opens on the first row, which takes no temperature'
    );
    await page.click('.ocu-form-disclosure');
    await page.waitForSelector('#ocu-definition-temperature', { visible: true, timeout: config.navigationTimeoutMs });

    // The column, served by GET /agent/providers, is what shuts the field -- never a provider name.
    const inert = await temperatureState(page);
    assert.equal(inert.placeholder, STRINGS.agentDefinitionTemperatureNotApplicable, `"Not applicable": ${JSON.stringify(inert)}`);
    assert.equal(inert.readonly, true, 'readonly');
    assert.equal(inert.ariaDisabled, 'true', 'and aria-disabled');
    assert.equal(inert.caption, STRINGS.agentDefinitionTemperatureNotApplicableCaption, 'under the caption that gives the reason');
    assert.equal(inert.describedBy, 'ocu-definition-temperature-caption', 'which describes the field');
    assert.deepEqual(await freshViolations(page), [], 'the not-applicable state passes every DW-1337 invariant');

    await page.select('#ocu-definition-provider', 'openai');
    await page.waitForFunction(
      (placeholder) => document.querySelector('#ocu-definition-temperature')?.getAttribute('placeholder') === placeholder,
      { timeout: config.navigationTimeoutMs },
      STRINGS.agentDefinitionTemperatureProviderDefault
    );
    const open = await temperatureState(page);
    assert.equal(open.value, '', `the cascade leaves the field empty: ${JSON.stringify(open)}`);
    assert.equal(open.readonly, false, 'and editable');
    assert.equal(open.ariaDisabled, null, 'with no aria-disabled');
    assert.equal(open.caption, null, 'and no caption');
    assert.deepEqual(await freshViolations(page), [], 'the provider-default state passes every DW-1337 invariant');

    const save = (await page.$$('.ocu-form-bar-actions button')).at(-1);
    assert.ok(save, 'the sticky bar carries a primary action');
    await save.click();
    await page.waitForFunction(
      (sentence) => document.querySelector('.ocu-form-bar-status')?.textContent?.includes(sentence) === true,
      { timeout: config.navigationTimeoutMs },
      STRINGS.formSavedPendingTest
    );

    const answer = await fetch(`${config.origin}${DEFINITIONS_PATH}`, { headers: { Authorization: authHeader() } });
    assert.ok(answer.ok, 'the definitions route answers');
    const body = await answer.json();
    const listed = (Array.isArray(body.definitions) ? body.definitions : []).find((row) => row?.name === NAMES[3]);
    assert.ok(listed, `the definition was stored: ${JSON.stringify(body.definitions)}`);
    assert.equal(listed.provider, 'openai', 'on the OpenAI row');
    const one = await fetch(`${config.origin}${DEFINITIONS_PATH}/${encodeURIComponent(listed.id)}`, {
      headers: { Authorization: authHeader() },
    });
    assert.ok(one.ok, 'the single-definition route answers');
    const stored = await one.json();
    assert.equal(stored.temperature, null, `and it stores no temperature: ${JSON.stringify(stored)}`);
  } finally {
    await context.close();
  }
});

test('Story 10.5: a test that waited its bound reads the published sentence, and the failure line passes every invariant', async () => {
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await page.emulateMediaFeatures([{ name: 'prefers-reduced-motion', value: 'reduce' }]);
    await page.setViewport(VIEWPORTS.wide);
    // The test route is answered here, in the browser, with the envelope the instance answers after
    // its bound -- so the press reaches no provider and takes no fifty seconds. Every other request
    // goes through, the create included.
    let envelope = null;
    await page.setRequestInterception(true);
    page.on('request', (request) => {
      if (envelope !== null && request.method() === 'POST' && /\/agent\/definitions\/[^/]+\/test$/.test(new URL(request.url()).pathname)) {
        request.respond({ status: 504, contentType: 'application/json', body: JSON.stringify(envelope) });
        return;
      }
      request.continue();
    });
    await page.waitForSelector('#ocu-definition-name', { visible: true, timeout: config.navigationTimeoutMs });
    await fill(page, 'ocu-definition-name', NAMES[4]);

    const cases = [
      {
        envelope: {
          error: 'unavailable',
          code: 'PROVIDER.TESTTIMEOUTLOCAL',
          reason: 'the envelope reason',
          detail: { waitedSeconds: 50, providerLabel: 'Anthropic', keySource: 'none', testedAsStored: false },
        },
        expected: STRINGS.agentDefinitionTestTimeoutLocal.replace('<n>', '50'),
      },
      {
        envelope: {
          error: 'unavailable',
          code: 'PROVIDER.TESTTIMEOUT',
          reason: 'the envelope reason',
          detail: { waitedSeconds: 50, providerLabel: 'Anthropic', keySource: 'none', testedAsStored: false },
        },
        expected: STRINGS.agentDefinitionTestTimeout.replace('<provider>', 'Anthropic').replace('<n>', '50'),
      },
    ];
    for (const { envelope: answer, expected } of cases) {
      envelope = answer;
      await page.click('.ocu-form-test button');
      // Mutation (Rule 19): have the store ignore `detail` for the two codes -> this waits out on
      // the envelope's own reason.
      await page.waitForFunction(
        (sentence) => document.querySelector('.ocu-form-test .ocu-form-error')?.textContent?.trim() === sentence,
        { timeout: config.navigationTimeoutMs },
        expected
      );
      assert.deepEqual(await freshViolations(page), [], `the ${answer.code} failure line passes every DW-1337 invariant`);
    }
  } finally {
    await context.close();
  }
});
