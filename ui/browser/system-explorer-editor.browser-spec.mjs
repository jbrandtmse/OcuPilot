/**
 * Story 19.3 in a real browser, against the throwaway: a probe class in `USER` is opened from its
 * viewer's "Edit source", changed and saved with "Compile after saving" -- the request carrying the
 * version the viewer read, the instance holding the text, the editor showing "Saved", the compiler's
 * lines and the re-read text under a new version, and the viewer then reading the saved text and its
 * new "Last modified" through its own read (AC1, AC4, AC8); a save after another writer changed the
 * class is refused by name with the person's text kept and the other writer's text standing (AC1);
 * leaving with unsaved text asks "Leave without saving?" first (AC3); and the editor carries no
 * classic link (AC2). The editor passes the structural walk at 1280 light, 720 light and 1280 dark,
 * with no entry beyond the baseline.
 *
 * The probe is `OcuPilot.Test.ExplorerSaveProbe`'s, created in `before` and removed in `after` by that
 * class, which names only its own package; the "other writer" changes it in the container. It refuses
 * the live container.
 *
 * Run: `node --test --test-concurrency=1 browser/system-explorer-editor.browser-spec.mjs` (after
 * `npm run build`, the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, VIEWPORTS, assertThrowaway, collapse, compare, componentMinimums, detectScreen, readBaseline } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { encodeEntityId } = await import(join(uiRoot, 'src', 'app', 'core', 'entity-id.ts'));

const config = browserConfig();
const STRINGS = loadStrings();
const EDITOR_ROUTE = 'system-explorer/classes/editor';
const PROBE = 'OcuPilot.Test.ExplorerSaveProbe';
const CLASS = 'OcuProbe193.Alpha';
const DOCUMENT = `${CLASS}.cls`;
const VIEWER_URL = `/ocupilot/system-explorer/classes/document/${encodeEntityId(DOCUMENT)}?ns=USER`;
const EDITOR_URL = `/ocupilot/${EDITOR_ROUTE}/${encodeEntityId(DOCUMENT)}?ns=USER`;
const ACTION_PATH = '/api/ocupilot/screens/explorer.classes/action';

let browser = null;

const marker = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** The probe class's text as the instance holds it, its lines joined by `|`. */
function instanceText() {
  const output = runIris(config.container, [marker('SOURCE', `$Translate(##class(${PROBE}).Source("USER","${DOCUMENT}"),$Char(10),"|")`)]);
  return markerValue(output, 'SOURCE') ?? '';
}

/** The probe class's text whose one method answers `answer`, as the probe class writes it. */
function classText(answer) {
  return `Class ${CLASS} Extends %RegisteredObject\n{\n\nClassMethod Probe() As %Integer\n{\n    Quit ${answer}\n}\n\n}\n`;
}

/** Remove the probes and save the probe class afresh. */
function freshProbe() {
  const output = runIris(config.container, [
    `Set tSC=##class(${PROBE}).Remove("USER")`,
    `If tSC Set tSC=##class(${PROBE}).MakeClass("USER","${CLASS}")`,
    marker('OK', '$System.Status.IsOK(tSC)'),
  ]);
  assert.equal(markerValue(output, 'OK'), '1', `the probe class is saved in USER: ${output}`);
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and changes classes, so it never runs inside the live container');
  await assertThrowaway(config);
  freshProbe();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  const output = runIris(config.container, [`Set tSC=##class(${PROBE}).Remove("USER")`, marker('OK', '$System.Status.IsOK(tSC)')]);
  assert.equal(markerValue(output, 'OK'), '1', `no probe document is left in USER: ${output}`);
});

function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

function transitionsSettled(page) {
  return page.waitForFunction(
    () => document.getAnimations().every((animation) => !(animation instanceof CSSTransition) || animation.playState !== 'running'),
    { timeout: config.navigationTimeoutMs }
  );
}

/** The walk of the editor at three passes, answering entries outside the baseline. */
async function structural(page) {
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
    await page.evaluate((dark) => document.documentElement.classList.toggle('ocu-theme-dark', dark), theme === 'dark');
    await frames(page);
    await transitionsSettled(page);
    surfaces[theme] = await page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const { entries } = await detectScreen(page, { route: EDITOR_ROUTE, checks, viewport: viewport.width, theme, minimums });
    found.push(...entries);
  }
  await page.evaluate(() => document.documentElement.classList.remove('ocu-theme-dark'));
  await page.setViewport(VIEWPORTS.wide);
  await frames(page);
  assert.notEqual(surfaces.dark, surfaces.light, 'the dark pass measured the dark theme, not the light one');
  return compare(collapse(found), readBaseline()?.entries ?? []).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

/** Wait for the editor's text area to hold the document's text, and answer it and the version shown. */
async function editorOpen(page) {
  await page.waitForFunction(() => (document.querySelector('[data-ocu-editor="text"]')?.value ?? '') !== '', { timeout: config.navigationTimeoutMs });
  return page.evaluate(() => ({
    text: document.querySelector('[data-ocu-editor="text"]').value,
    modified: document.querySelector('[data-ocu-editor="modified"]').textContent.trim(),
  }));
}

/** Replace the editor's text, as typing does. */
function typeText(page, text) {
  return page.evaluate((value) => {
    const area = document.querySelector('[data-ocu-editor="text"]');
    area.value = value;
    area.dispatchEvent(new Event('input', { bubbles: true }));
  }, text);
}

test('AC1, AC2, AC4, AC8: Edit source opens the class, Save stores it at the version read and compiles it, and the viewer reads it back', async () => {
  freshProbe();
  const { context, page } = await signedInAt(browser, config, VIEWER_URL, VIEWPORTS.wide);
  const posts = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === ACTION_PATH) posts.push(JSON.parse(request.postData() ?? '{}'));
  });
  try {
    await page.waitForSelector('pre[data-ocu-source="text"]', { timeout: config.navigationTimeoutMs });
    const viewed = await page.evaluate(() => ({
      text: document.querySelector('pre[data-ocu-source="text"]').textContent,
      modified: Array.from(document.querySelectorAll('[data-ocu-source="header"] dd')).map((node) => node.textContent.trim())[2],
    }));
    await page.click('a[data-ocu-source="edit"]');
    const opened = await editorOpen(page);
    assert.equal(new URL(page.url()).pathname + new URL(page.url()).search, EDITOR_URL, 'Edit source opens the class editor in the namespace');
    assert.equal(opened.text, viewed.text, 'the editor opens on the text the viewer shows');
    assert.equal(opened.modified, viewed.modified, 'and on its version');
    assert.equal(await page.$eval('[data-ocu-editor="save"]', (node) => node.getAttribute('aria-disabled')), 'true', 'Save is unavailable while the text is unchanged');
    assert.equal(await page.$('a[href*="/csp/"]'), null, 'the editor carries no classic link (AC2)');
    assert.equal(await page.$eval('[data-ocu-editor="compile"]', (node) => node.checked), true, 'Compile after saving opens checked');

    const sent = classText(7).replace(/\n$/, '');
    await typeText(page, sent);
    await page.click('[data-ocu-editor="save"]');
    await page.waitForFunction(
      (wanted) => document.querySelector('[data-ocu-editor="status"]')?.textContent.trim() === wanted,
      { timeout: config.navigationTimeoutMs },
      `${STRINGS.formSaved} \u00B7 ${STRINGS.readBackNothingSent}`
    );
    assert.deepEqual(posts, [{ action: 'save', id: DOCUMENT, values: { content: sent, version: opened.modified, Compile: 'true' } }], 'one save, carrying the version the editor read');
    const saved = await page.evaluate(() => ({
      text: document.querySelector('[data-ocu-editor="text"]').value,
      modified: document.querySelector('[data-ocu-editor="modified"]').textContent.trim(),
      output: document.querySelector('[data-ocu-editor="output"]')?.textContent ?? '',
      saveDisabled: document.querySelector('[data-ocu-editor="save"]').getAttribute('aria-disabled'),
    }));
    assert.ok(saved.output.includes(`Compiling class ${CLASS}`), `the compiler's lines are in the output pane: ${saved.output}`);
    assert.equal(saved.text, classText(7), "the editor adopts the instance's re-read text");
    assert.notEqual(saved.modified, opened.modified, 'under its new version');
    assert.equal(saved.saveDisabled, 'true', 'and nothing is left to save');
    assert.equal(instanceText(), classText(7).replace(/\n/g, '|'), 'the instance holds the saved text');
    assert.deepEqual(await structural(page), [], 'the editor with its output adds no structural entry');

    await page.click('[data-ocu-editor="cancel"]');
    await page.waitForFunction((wanted) => (document.querySelector('pre[data-ocu-source="text"]')?.textContent ?? '').includes(wanted), { timeout: config.navigationTimeoutMs }, 'Quit 7');
    const back = await page.evaluate(() => Array.from(document.querySelectorAll('[data-ocu-source="header"] dd')).map((node) => node.textContent.trim())[2]);
    assert.equal(back, saved.modified, 'the viewer reads the saved text and its new Last modified (AC8)');
  } finally {
    await context.close();
  }
});

test("AC1, AC3: a save after another writer's change is refused by name with the person's text kept, and leaving asks first", async () => {
  freshProbe();
  const { context, page } = await signedInAt(browser, config, EDITOR_URL, VIEWPORTS.wide);
  try {
    await editorOpen(page);
    const output = runIris(config.container, [`Set tSC=##class(${PROBE}).Rewrite("USER","${CLASS}","3")`, marker('OK', '$System.Status.IsOK(tSC)')]);
    assert.equal(markerValue(output, 'OK'), '1', `another writer changes the class: ${output}`);
    const mine = classText(9);
    await typeText(page, mine);
    await page.click('[data-ocu-editor="save"]');
    await page.waitForSelector('[data-ocu-editor="refusal"]', { timeout: config.navigationTimeoutMs });
    const refused = await page.evaluate(() => ({
      banner: document.querySelector('[data-ocu-editor="refusal"]').textContent.trim(),
      role: document.querySelector('[data-ocu-editor="refusal"]').getAttribute('role'),
      text: document.querySelector('[data-ocu-editor="text"]').value,
    }));
    assert.deepEqual(refused, { banner: STRINGS.explorerDocumentConflict, role: 'alert', text: mine }, "the conflict is refused by name and the person's text stays");
    assert.ok(instanceText().includes('Quit 3'), "the other writer's text stands on the instance");

    await page.click('[data-ocu-editor="cancel"]');
    await page.waitForFunction(
      (wanted) => Array.from(document.querySelectorAll('.ocu-dialog-title')).some((node) => node.textContent.trim() === wanted),
      { timeout: config.navigationTimeoutMs },
      STRINGS.formLeaveWithoutSaving
    );
    await page.click('.ocu-dialog-actions button.ocu-button-secondary');
    await page.waitForFunction(() => document.querySelector('.ocu-dialog-title') === null, { timeout: config.navigationTimeoutMs });
    assert.equal(new URL(page.url()).pathname, new URL(`${config.origin}${EDITOR_URL}`).pathname, 'declining keeps the editor');
    assert.equal(await page.$eval('[data-ocu-editor="text"]', (node) => node.value), mine, 'with the text');
    await page.click('[data-ocu-editor="cancel"]');
    await page.waitForSelector('.ocu-dialog-title', { timeout: config.navigationTimeoutMs });
    await page.click('.ocu-dialog-actions button.ocu-button-primary');
    await page.waitForSelector('pre[data-ocu-source="text"]', { timeout: config.navigationTimeoutMs });
    assert.ok(!instanceText().includes('Quit 9'), 'leaving sends nothing');
  } finally {
    await context.close();
  }
});
