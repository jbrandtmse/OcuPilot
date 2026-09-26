/**
 * The user audit event editor in a real browser, against the throwaway instance (Story 9.10).
 *
 * Four claims, each asserted on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **The command bar's Create opens the editor as a dialog, and a Save registers the event**
 *    (AC1, Integration): the instance holds it as entered, the dialog becomes an edit of it, and the
 *    User events list shows the row marked changed without a page load -- the change event the Save
 *    publishes is what marks it.
 * 2. **A `%` Source is refused on the Source field** with the server's sentence, and nothing is
 *    registered (AC3).
 * 3. **A row's name cell opens the editor over that event**, its identity read-only, and a
 *    Description change is read back from the instance with Enabled untouched (AC2).
 * 4. **The DW-1337 gate on the open dialog, in both modes**: every control named, none under 24x24
 *    or narrower than its declared minimum, nothing overflowing its container.
 *
 * **It refuses anything but a `-ci` throwaway.** Every event it registers has the Source
 * `OcuP910Probe` and is removed by exact name through `OcuPilot.Test.AuditEventEditor`'s own helper
 * inside the throwaway, before and after.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/audit-event-editor.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, filterToSubset, viewCount, waitForRows } from './list-spec.mjs';
import { signedInAt } from './panel-spec.mjs';
import { escapeOs, markerValue, runIris as sharedRunIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const LIST_URL = '/ocupilot/security/auditing/user-events?ns=HSCUSTOM';
const HELPER = 'OcuPilot.Test.AuditEventEditor';

const SOURCE = 'OcuP910Probe';

/** Every event this spec may register, removed by exact name in `before` and `after`. */
const CREATED = [SOURCE, 'Browser', 'Create'];
const EDITED = [SOURCE, 'Browser', 'Edit'];
const RESERVED = [`%${SOURCE}`, 'Browser', 'Reserved'];
const PROBES = [CREATED, EDITED, RESERVED].map((parts) => parts.join('/'));

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec registers audit events, so it never runs inside the live container');
  assert.match(config.container, /-ci$/, `this spec registers audit events, so it runs only in a throwaway; ${config.container} is not one`);
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  removeProbes();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (!/-ci$/.test(config.container)) return;
  removeProbes();
  for (const id of PROBES) assert.equal(stored(id), '', `${id} is gone`);
});

function runIris(lines) {
  return sharedRunIris(config.container, lines);
}

/** Remove every event this spec registers, by its exact name -- never a prefix sweep. */
function removeProbes() {
  runIris(PROBES.map((id) => `Do ##class(${HELPER}).Remove("${escapeOs(id)}")`));
}

/** The stored event as `description|enabled`, or `''` when the instance does not register it; a probe that did not answer fails. */
function stored(id) {
  const output = runIris([`Write "OCU-AEE-START:"_##class(${HELPER}).Stored("${escapeOs(id)}")_":OCU-AEE-END",!`]);
  const value = markerValue(output, 'AEE');
  assert.notEqual(value, null, `the instance answered for ${id}: ${output}`);
  return value;
}

async function openCreate(page) {
  await waitForRows(page, config.navigationTimeoutMs);
  const create = await page.waitForSelector('.ocu-command-bar button.ocu-button-primary', { visible: true, timeout: config.navigationTimeoutMs });
  assert.equal(await create.evaluate((node) => node.textContent.trim()), STRINGS.actionCreate, 'the command bar offers Create');
  await create.click();
  await page.waitForSelector('[role="dialog"] #ocu-audit-event-Source', { visible: true, timeout: config.navigationTimeoutMs });
}

async function fill(page, field, value) {
  await page.click(`#ocu-audit-event-${field}`, { clickCount: 3 });
  await page.type(`#ocu-audit-event-${field}`, value);
}

async function waitForHeading(page, expected) {
  await page.waitForFunction(
    (wanted) => document.querySelector('[role="dialog"] .ocu-dialog-title')?.textContent?.trim() === wanted,
    { timeout: config.navigationTimeoutMs },
    expected
  );
}

async function clickDialogButton(page, label) {
  const clicked = await page.$$eval(
    '[role="dialog"] button',
    (buttons, wanted) => {
      const button = buttons.find((candidate) => candidate.textContent.trim() === wanted);
      if (button === undefined) return false;
      button.click();
      return true;
    },
    label
  );
  assert.ok(clicked, `the dialog offers ${label}`);
}

async function waitForSaved(page) {
  await page.waitForFunction(
    // Story 16.17: the text, or the text and the instance's read-back line after it.
    (sentence) => ((shown) => shown === sentence || shown.startsWith(`${sentence} \u00b7 `))(document.querySelector('[role="dialog"] [role="status"]')?.textContent?.trim() ?? ''),
    { timeout: config.navigationTimeoutMs },
    STRINGS.formSaved
  );
}

/** The DW-1337 structural gate over the open dialog. */
async function dialogGate(page) {
  return page.evaluate(() => {
    const nameOf = (node) => {
      const labelled = node.getAttribute('aria-labelledby');
      if (labelled) return labelled.split(' ').map((id) => document.getElementById(id)?.textContent.trim() ?? '').join(' ').trim();
      if (node.getAttribute('aria-label')) return node.getAttribute('aria-label').trim();
      if (node.labels && node.labels.length > 0) return Array.from(node.labels).map((item) => item.textContent.trim()).join(' ');
      return node.textContent.trim();
    };
    const root = document.querySelector('[role="dialog"]');
    const controls = Array.from(root.querySelectorAll('input, select, textarea, button')).filter((node) => node.offsetParent !== null);
    const unnamed = controls.filter((node) => nameOf(node) === '').map((node) => node.outerHTML.slice(0, 120));
    // A checkbox wrapped in its label is targeted through the label, so the label is what is measured.
    const targetOf = (node) => (node.type === 'checkbox' && node.parentElement?.tagName === 'LABEL' ? node.parentElement : node);
    const small = controls
      .filter((node) => {
        const box = targetOf(node).getBoundingClientRect();
        const min = parseFloat(getComputedStyle(node).minWidth);
        return box.width < 24 || box.height < 24 || (Number.isFinite(min) && box.width + 0.5 < min);
      })
      .map((node) => node.outerHTML.slice(0, 120));
    const overflowing = Array.from(root.querySelectorAll('*'))
      .filter((node) => node.offsetParent !== null && node.parentElement !== null)
      .filter((node) => {
        const own = node.getBoundingClientRect();
        const parent = node.parentElement.getBoundingClientRect();
        if (getComputedStyle(node.parentElement).overflowX !== 'visible') return false;
        return own.width > 0 && own.right > parent.right + 1;
      })
      .map((node) => node.outerHTML.slice(0, 120));
    return { controls: controls.length, unnamed, small, overflowing };
  });
}

function assertGate(report, mode) {
  assert.ok(report.controls >= 4, `${mode}: the gate looked at the dialog's controls: ${report.controls}`);
  assert.deepEqual(report.unnamed, [], `${mode}: every control has an accessible name`);
  assert.deepEqual(report.small, [], `${mode}: none is smaller than 24x24 or narrower than its declared minimum`);
  assert.deepEqual(report.overflowing, [], `${mode}: nothing overflows its container`);
}

// AC1, Integration. Mutation (Rule 19): drop the store's `publish` call -> the list's row is never
// marked changed and this goes red.
test('AC1: the command bar\'s Create registers the event, the dialog becomes its edit, and the list marks the row, disabled', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  try {
    await openCreate(page);
    assert.equal(
      await page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim()),
      STRINGS.auditUserEventEditorCreate
    );
    assert.equal(await page.$eval('#ocu-audit-event-Enabled', (node) => node.checked), true, 'Enabled starts checked');
    assertGate(await dialogGate(page), 'create');
    await fill(page, 'Source', CREATED[0]);
    await fill(page, 'Type', CREATED[1]);
    await fill(page, 'Name', CREATED[2]);
    await fill(page, 'Description', 'browser create');
    await page.click('#ocu-audit-event-Enabled');
    await clickDialogButton(page, STRINGS.actionSave);
    await waitForSaved(page);
    const id = CREATED.join('/');
    await waitForHeading(page, STRINGS.auditUserEventEditorEdit.replace('<name>', id));
    assert.equal(await page.$eval('#ocu-audit-event-Source', (node) => node.readOnly), true, 'the saved dialog is an edit, its identity read-only');
    assert.equal(stored(id), 'browser create|0', 'the instance holds the event as entered, disabled');

    await clickDialogButton(page, STRINGS.actionCancel);
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, { timeout: config.navigationTimeoutMs });
    await waitForRows(page, config.navigationTimeoutMs);
    await page.type(FILTER_SELECTOR, id);
    await page.waitForFunction(
      (rowSelector, name) =>
        Array.from(document.querySelectorAll(rowSelector)).some(
          (row) =>
            (row.querySelector('[role="gridcell"]')?.textContent?.trim() ?? '').startsWith(name) &&
            row.classList.contains('ocu-data-table-row-changed') &&
            row.querySelector('[data-disc]')?.getAttribute('data-disc') === 'outline'
        ),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      id
    );
  } finally {
    await context.close();
  }
});

// AC3. Mutation (Rule 19): drop the reserved check from `AuditEventRules.PartViolation` -> the
// vendor answers the create and neither the sentence nor the absence holds.
test('AC3: a % Source is refused on the Source field with the server\'s sentence, and nothing is registered', async () => {
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  try {
    await openCreate(page);
    await fill(page, 'Source', RESERVED[0]);
    await fill(page, 'Type', RESERVED[1]);
    await fill(page, 'Name', RESERVED[2]);
    await clickDialogButton(page, STRINGS.actionSave);
    await page.waitForFunction(
      (sentence) => document.querySelector('#ocu-audit-event-Source-reason')?.textContent?.trim() === sentence,
      { timeout: config.navigationTimeoutMs },
      STRINGS.auditEventRefusalPartReserved
    );
    assert.equal(await page.$eval('#ocu-audit-event-Source', (node) => node.getAttribute('aria-invalid')), 'true');
    assert.equal(stored(RESERVED.join('/')), '', 'and nothing was registered');
  } finally {
    await context.close();
  }
});

// AC2. Mutation (Rule 19): drop the identity fields' `readOnly` in edit mode -> the read-only
// assertion goes red.
test('AC2: a row\'s name cell opens the editor over that event, identity read-only, and its Description is saved alone', async () => {
  const id = EDITED.join('/');
  runIris([`Do ##class(${HELPER}).Make("${escapeOs(id)}", "before", 0)`]);
  assert.equal(stored(id), 'before|0', 'a disabled probe event is registered');
  const { context, page } = await signedInAt(browser, config, LIST_URL);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const total = await viewCount(page);
    await filterToSubset(page, { text: id, expectRow: id, total, timeoutMs: config.navigationTimeoutMs });
    await clickRowCentre(page, { text: id, link: true });
    await page.waitForSelector('[role="dialog"] #ocu-audit-event-Source', { visible: true, timeout: config.navigationTimeoutMs });
    await waitForHeading(page, STRINGS.auditUserEventEditorEdit.replace('<name>', id));
    await page.waitForFunction(() => document.querySelector('#ocu-audit-event-Description')?.value === 'before', {
      timeout: config.navigationTimeoutMs,
    });
    const identity = await page.$$eval(['Source', 'Type', 'Name'].map((field) => `#ocu-audit-event-${field}`).join(','), (nodes) =>
      nodes.map((node) => [node.value, node.readOnly])
    );
    assert.deepEqual(identity, [[EDITED[0], true], [EDITED[1], true], [EDITED[2], true]], 'Source, Type and Name are read-only');
    assert.equal(await page.$('#ocu-audit-event-Enabled'), null, 'and Enabled is left to the row actions');
    assertGate(await dialogGate(page), 'edit');
    await fill(page, 'Description', 'after');
    await clickDialogButton(page, STRINGS.actionSave);
    await waitForSaved(page);
    assert.equal(stored(id), 'after|0', 'the Description changed and Enabled still reads false');
  } finally {
    await context.close();
  }
});
