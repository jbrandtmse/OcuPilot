/**
 * The resource editor in a real browser, against the throwaway instance (Story 8.4).
 *
 * Five claims, each asserted on rendered DOM, on the real URL or on the instance itself:
 *
 * 1. **The list's Create opens the editor as a dialog** (AC1) with name, description and public
 *    permission, in that order, and the route does not change.
 * 2. **A row's name cell opens the editor over that resource** (AC1) with the name read-only.
 * 3. **A valid Save creates the resource** (AC4) with the sent values, replaces the route with
 *    `permissions/resources/<id>`, re-labels the dialog to edit mode with the saved sentence, and
 *    the list shows the row without a page load. The change event itself is pinned in
 *    `resource-editor.store.spec.ts`.
 * 4. **A dirty Escape asks first** (AC7): the shared leave question replaces the dialog, and
 *    staying brings it back with the edit.
 * 5. **A public permission on an administrative name states its consequence** (AC6).
 *
 * **It refuses the live container.** Every resource it creates is named below and removed by that
 * exact name through the vendor's own `Security.Resources.Delete` inside the throwaway, before and
 * after.
 *
 * Run: `npm run test:browser` (after `npm run build` and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, filterToSubset, viewCount, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const LIST_URL = '/ocupilot/permissions/resources?ns=HSCUSTOM';

/** Every resource this spec creates, removed by exact name in `before` and `after`. */
const NAMES = ['OcuPilotProbeResourceEditor', 'OcuPilotProbeResourceEdit'];

/** An administrative name the privileged leg types and never saves. */
const PRIVILEGED_NAME = '%Admin_OcuPilotProbe';

const PROBE_DESCRIPTION = 'OcuPilot probe resource';

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec drives the throwaway, never the live container');
  assert.notEqual(config.container, '', 'it removes the resources it creates, so it needs the container that serves the origin');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  removeProbeResources();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  removeProbeResources();
  if (browser !== null) await browser.close();
});

/** Run `lines` in `%SYS` inside the throwaway, returning the combined transcript. */
function irisSys(lines) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input: `${[...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  return `${result.stdout ?? ''}${result.stderr ?? ''}`;
}

/** Remove every resource this spec creates, by its exact name -- never a prefix sweep. */
function removeProbeResources() {
  irisSys(
    [...NAMES, PRIVILEGED_NAME].map(
      (name) => `If ##class(Security.Resources).Exists("${name}") Do ##class(Security.Resources).Delete("${name}")`
    )
  );
}

/** The stored resource `name` as `description|letters`, or `null` when it does not exist. */
function storedResource(name) {
  const output = irisSys([
    `Set tOK = ##class(Security.Resources).Get("${name}", .tProps)`,
    'Write "OCU-OK-START:",tOK,":OCU-OK-END",!',
    'Write "OCU-VAL-START:",$Get(tProps("Description")),"|",$Get(tProps("PublicPermission")),":OCU-VAL-END",!',
  ]);
  const ok = /OCU-OK-START:(.*?):OCU-OK-END/.exec(output);
  if (ok === null || ok[1].trim() !== '1') return null;
  const value = /OCU-VAL-START:(.*?):OCU-VAL-END/.exec(output);
  return value === null ? '' : value[1];
}

/** A fresh context signed in through the shell's own form, landed at `url`. */
async function signedInAt(url) {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  return { context, page };
}

/** Click the list's Create and wait for the editor dialog. */
async function openCreate(page) {
  await waitForRows(page, config.navigationTimeoutMs);
  const create = await page.waitForSelector('.ocu-command-bar button.ocu-button-primary', {
    visible: true,
    timeout: config.navigationTimeoutMs,
  });
  assert.equal(await create.evaluate((node) => node.textContent.trim()), STRINGS.actionCreate, 'the command bar offers Create');
  await create.click();
  await page.waitForSelector('[role="dialog"] #ocu-resource-Name', { visible: true, timeout: config.navigationTimeoutMs });
}

/** Type `value` into the control `id`, replacing whatever is there. */
async function fill(page, id, value) {
  await page.click(`#${id}`, { clickCount: 3 });
  await page.type(`#${id}`, value);
}

/** The dialog's title. */
function heading(page) {
  return page.$eval('[role="dialog"] .ocu-dialog-title', (node) => node.textContent.trim());
}

/** Wait until the dialog's title reads `expected`. */
async function waitForHeading(page, expected) {
  await page.waitForFunction(
    (wanted) => document.querySelector('[role="dialog"] .ocu-dialog-title')?.textContent?.trim() === wanted,
    { timeout: config.navigationTimeoutMs },
    expected
  );
}

/** Click the button in the dialog whose text is `label`. */
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

async function waitForDialogClosed(page) {
  await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, {
    timeout: config.navigationTimeoutMs,
  });
}

/** The path of the page's current URL. */
function pathname(page) {
  return page.evaluate(() => new URL(window.location.href).pathname);
}

// AC1. Mutation (Rule 19): swap the Description field and the Public permission fieldset in the
// dialog template -> this goes red naming the order.
test('AC1: the list\'s Create opens the editor as a dialog, with name, description and public permission in that order', async () => {
  const { context, page } = await signedInAt(LIST_URL);
  try {
    await openCreate(page);
    assert.equal(await heading(page), STRINGS.resourceEditorCreate);
    const labels = await page.$$eval(
      '[role="dialog"] .ocu-field > .ocu-field-label, [role="dialog"] fieldset > legend',
      (nodes) => nodes.map((node) => node.textContent.trim())
    );
    assert.deepEqual(labels, [STRINGS.tableColumnName, STRINGS.tableColumnDescription, STRINGS.resourceColumnPublicPermission]);
    assert.ok((await pathname(page)).endsWith('/permissions/resources'), 'the route does not change');
    assert.equal(await page.$eval('#ocu-resource-Name', (node) => node.readOnly), false, 'the name is editable on a create');
    await clickDialogButton(page, STRINGS.actionCancel);
    await waitForDialogClosed(page);
  } finally {
    await context.close();
  }
});

// AC4. Mutation (Rule 19): drop the route replacement from the page's `afterSave` -> the URL leg
// goes red.
test('AC4: a Save creates the resource, names it in the route, re-labels the dialog, and the list shows it', async () => {
  const { context, page } = await signedInAt(LIST_URL);
  try {
    await openCreate(page);
    await fill(page, 'ocu-resource-Name', NAMES[0]);
    await fill(page, 'ocu-resource-Description', PROBE_DESCRIPTION);
    await page.click('#ocu-resource-PublicPermission-R');
    await page.click('#ocu-resource-PublicPermission-U');
    await clickDialogButton(page, STRINGS.actionSave);

    await page.waitForFunction(
      (sentence) => document.querySelector('[role="dialog"] [role="status"]')?.textContent?.trim() === sentence,
      { timeout: config.navigationTimeoutMs },
      STRINGS.formSaved
    );
    await page.waitForFunction(
      (name) => new URL(window.location.href).pathname.toLowerCase().endsWith(`/permissions/resources/${name.toLowerCase()}`),
      { timeout: config.navigationTimeoutMs },
      NAMES[0]
    );
    await waitForHeading(page, STRINGS.resourceEditorEdit.replace('<name>', NAMES[0]));
    assert.equal(await page.$eval('#ocu-resource-Name', (node) => node.readOnly), true, 'the saved dialog is an edit, its name read-only');
    assert.equal(storedResource(NAMES[0]), `${PROBE_DESCRIPTION}|RU`, 'the instance holds the sent values');

    await clickDialogButton(page, STRINGS.actionCancel);
    await waitForDialogClosed(page);
    await page.waitForFunction(() => new URL(window.location.href).pathname.endsWith('/permissions/resources'), {
      timeout: config.navigationTimeoutMs,
    });
    await waitForRows(page, config.navigationTimeoutMs);
    // The row may carry the change highlight's label after its name, so it is matched by prefix.
    await page.type(FILTER_SELECTOR, NAMES[0]);
    await page.waitForFunction(
      (rowSelector, name) =>
        Array.from(document.querySelectorAll(rowSelector)).some((row) =>
          (row.querySelector('[role="gridcell"]')?.textContent?.trim() ?? '').startsWith(name)
        ),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      NAMES[0]
    );
  } finally {
    await context.close();
  }
});

// AC1's edit entry. Mutation (Rule 19): drop `[readOnly]="editing"` from the dialog's name input
// -> the read-only assertion goes red.
test('AC1: a row\'s name cell opens the editor over that resource, its name read-only', async () => {
  irisSys([`Do ##class(Security.Resources).Create("${NAMES[1]}", "${PROBE_DESCRIPTION}", "R")`]);
  const { context, page } = await signedInAt(LIST_URL);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const total = await viewCount(page);
    await filterToSubset(page, { text: NAMES[1], expectRow: NAMES[1], total, timeoutMs: config.navigationTimeoutMs });
    await clickRowCentre(page, { text: NAMES[1], link: true });
    await page.waitForSelector('[role="dialog"] #ocu-resource-Name', { visible: true, timeout: config.navigationTimeoutMs });
    await waitForHeading(page, STRINGS.resourceEditorEdit.replace('<name>', NAMES[1]));
    await page.waitForFunction(
      (description) => document.querySelector('#ocu-resource-Description')?.value === description,
      { timeout: config.navigationTimeoutMs },
      PROBE_DESCRIPTION
    );
    assert.equal(await page.$eval('#ocu-resource-Name', (node) => node.readOnly), true, 'the name is read-only');
    assert.equal(await page.$eval('#ocu-resource-Name', (node) => node.value), NAMES[1]);
    assert.equal(await page.$eval('#ocu-resource-PublicPermission-R', (node) => node.checked), true, 'the held permission is checked');
  } finally {
    await context.close();
  }
});

// AC7. Mutation (Rule 19): make `ResourceEditor.requestClose()` reset without asking -> the dialog
// closes without the question and this goes red. The route guard is pinned in `app.routes.spec.ts`.
test('AC7: a dirty Escape asks first, and staying brings the dialog back with the edit', async () => {
  const { context, page } = await signedInAt(LIST_URL);
  try {
    await openCreate(page);
    await fill(page, 'ocu-resource-Description', 'typed and not saved');
    await page.keyboard.press('Escape');
    await waitForHeading(page, STRINGS.formLeaveWithoutSaving);
    assert.equal(await page.$('#ocu-resource-Name'), null, 'the question replaces the editor');
    await clickDialogButton(page, STRINGS.actionCancel);
    await page.waitForSelector('[role="dialog"] #ocu-resource-Description', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-resource-Description', (node) => node.value), 'typed and not saved', 'the edit survives');

    // Asked again, leaving discards the edit and closes the editor.
    await page.keyboard.press('Escape');
    await waitForHeading(page, STRINGS.formLeaveWithoutSaving);
    await clickDialogButton(page, STRINGS.actionConfirm);
    await waitForDialogClosed(page);
  } finally {
    await context.close();
  }
});

// AC6. Mutation (Rule 19): make the dialog's `showEffect` answer false -> this goes red.
test('AC6: a public permission on an administrative name states its consequence', async () => {
  const { context, page } = await signedInAt(LIST_URL);
  try {
    await openCreate(page);
    await fill(page, 'ocu-resource-Name', PRIVILEGED_NAME);
    await page.click('#ocu-resource-Description');
    await page.waitForSelector('#ocu-resource-PublicPermission-U', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$('#ocu-resource-PublicPermission-R'), null, 'an administrative resource admits Use alone');
    await page.click('#ocu-resource-PublicPermission-U');
    await page.waitForSelector('#ocu-resource-effect', { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-resource-effect', (node) => node.textContent.trim()), STRINGS.privilegedGrantEffect);
    assert.equal(
      await page.$eval('#ocu-resource-PublicPermission', (node) => node.getAttribute('aria-describedby')),
      'ocu-resource-effect',
      'which describes the Public permission field'
    );
    await page.keyboard.press('Escape');
    await waitForHeading(page, STRINGS.formLeaveWithoutSaving);
    await clickDialogButton(page, STRINGS.actionConfirm);
    await waitForDialogClosed(page);
    assert.equal(storedResource(PRIVILEGED_NAME), null, 'and nothing was created');
  } finally {
    await context.close();
  }
});
