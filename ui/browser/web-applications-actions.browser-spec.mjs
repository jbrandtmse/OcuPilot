/**
 * Story 7.1 in a real browser, against the throwaway instance: the Web applications list's three
 * declared row actions, end to end through `POST /screens/webapp.list/action` (AD-5, AD-53).
 *
 * What it pins: enable and disable from the row menu and from the command bar, with the row
 * updating in place and the filter and selection surviving; the typed-name delete, including the
 * mismatch message and the button that stays `aria-disabled` until the name matches exactly; and
 * the self-protection refusal on one of OcuPilot's own applications, listed and arrow-reachable
 * rather than Material-disabled.
 *
 * **It creates and deletes a web application**, so it refuses the live container. `before` makes
 * the probe application and `after` removes it whether or not a test failed.
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
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const LIST_URL = '/ocupilot/web-applications/list?ns=HSCUSTOM';
const ACTION_PATH = '/api/ocupilot/screens/webapp.list/action';

/** This spec's own application, never one the instance had. */
const PROBE = '/csp/ocupilotprobeaction';

/** One of OcuPilot's own, which the instance refuses every write to (AD-10). */
const OWN = '/api/ocupilot';

let browser = null;

/** Run ObjectScript in `iris session` inside the throwaway and read back the named markers. */
function irisSession(lines, names) {
  const input = `${[...lines, 'Halt'].join('\n')}\n`;
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const values = {};
  for (const name of names) {
    const match = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
    values[name] = match === null ? null : match[1];
  }
  return { values, output };
}

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

function createProbe() {
  return irisSession(
    [
      `If ##class(Security.Applications).Exists("${PROBE}") Do ##class(Security.Applications).Delete("${PROBE}")`,
      'Set tNS=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")',
      'Kill tProps Set tProps("NameSpace")=tNS,tProps("Enabled")=1,tProps("AutheEnabled")=32',
      `Set tProps("Description")="OcuPilot row-action browser spec probe (throwaway)"`,
      `Set tSC=##class(Security.Applications).Create("${PROBE}",.tProps)`,
      mark('MADE', '$System.Status.IsOK(tSC)'),
    ],
    ['MADE']
  );
}

function deleteProbe() {
  return irisSession(
    [
      `If ##class(Security.Applications).Exists("${PROBE}") Do ##class(Security.Applications).Delete("${PROBE}")`,
      mark('CLEAN', `('##class(Security.Applications).Exists("${PROBE}"))`),
    ],
    ['CLEAN']
  );
}

/** Whether the instance reports the probe application enabled; `''` when it is gone. */
function probeEnabled() {
  const { values } = irisSession(
    [
      `Set tThere=##class(Security.Applications).Exists("${PROBE}",.tRow)`,
      mark('ENABLED', `$Select(tThere: tRow.Enabled, 1: "gone")`),
    ],
    ['ENABLED']
  );
  return values.ENABLED;
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates and deletes a web application, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  const { values, output } = createProbe();
  assert.equal(values.MADE, '1', `the probe application was created:\n${output}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  const { values, output } = deleteProbe();
  assert.equal(values.CLEAN, '1', `the probe application is gone:\n${output}`);
});

/** A fresh context signed in at the list, with the action requests it issues counted. */
async function signedInAtList() {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const writes = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname === ACTION_PATH) writes.push(request.method());
  });
  await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, LIST_URL);
  await waitForRows(page, config.navigationTimeoutMs);
  return { context, page, writes };
}

/**
 * The selector the name cell's own text element carries.
 *
 * A row's name is read from it rather than from the cell, because a row the change framework has
 * marked carries a "Changed" tag inside that same cell -- so the cell's text is the name with the
 * tag glued to it, and an exact comparison against the name would stop matching the moment a write
 * landed on the row. `describeRow` in `web-applications.browser-spec.mjs` reads the same element.
 */
const NAME_TEXT = '.ocu-data-table-link, .ocu-data-table-text';

/**
 * Narrow the list to `name` and select that row, leaving the filter in place.
 *
 * The filter is not required to leave exactly one row: `/api/ocupilot` is a prefix of
 * `/api/ocupilot/readiness`, and both are rows this spec has something to say about. What is
 * required is that the wanted row is there to click.
 */
async function selectOnly(page, name) {
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
  await clickRowCentre(page, { text: name });
}

/** Open the selected row's overflow menu and describe every entry. */
async function openRowMenu(page) {
  await page.click('.ocu-data-table-trigger');
  await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
  return page.$$eval('[role="menu"] [role="menuitem"]', (items) =>
    items.map((item) => ({
      label: item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() ?? '',
      reason: item.querySelector('.ocu-data-table-menu-reason')?.textContent.trim() ?? '',
      name: item.getAttribute('aria-label'),
      ariaDisabled: item.getAttribute('aria-disabled'),
      disabled: item.hasAttribute('disabled'),
      tabIndex: item.getAttribute('tabindex'),
    }))
  );
}

/** The rendered Enabled cell of the row whose name cell reads `name`. */
function enabledCell(page, name) {
  return page.evaluate(
    (selector, wanted, textSelector) => {
      const row = Array.from(document.querySelectorAll(selector)).find((candidate) => {
        const cell = candidate.querySelector('[role="gridcell"]');
        const text = cell.querySelector(textSelector);
        return (text === null ? cell : text).textContent.trim() === wanted;
      });
      return row === undefined ? null : row.querySelectorAll('[role="gridcell"]')[3].textContent.trim();
    },
    ROW_SELECTOR,
    name,
    NAME_TEXT
  );
}

test('AC1: disable and enable run from the row menu and the command bar, and the row updates in place', async () => {
  const { context, page, writes } = await signedInAtList();
  try {
    await selectOnly(page, PROBE);
    assert.equal(await enabledCell(page, PROBE), STRINGS.tableStatusYes, 'the probe application starts enabled');

    const entries = await openRowMenu(page);
    assert.deepEqual(
      entries.map((entry) => entry.label),
      [STRINGS.agentDefinitionEnable, STRINGS.agentDefinitionDisable, STRINGS.actionDelete],
      'the menu lists the three declared actions in command-bar order, destructive last'
    );
    for (const entry of entries) {
      assert.equal(entry.reason, '', `${entry.label} is offered rather than explained on an ordinary row`);
      assert.equal(entry.ariaDisabled, null, `${entry.label} is selectable`);
    }

    // Disable, from the row menu.
    await page.evaluate((label) => {
      const items = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'));
      items.find((item) => item.textContent.trim().startsWith(label)).click();
    }, STRINGS.agentDefinitionDisable);
    await page.waitForFunction(
      (selector, wanted, textSelector) => {
        const row = Array.from(document.querySelectorAll(selector)).find((candidate) => {
          const cell = candidate.querySelector('[role="gridcell"]');
          const text = cell.querySelector(textSelector);
          return (text === null ? cell : text).textContent.trim() === wanted;
        });
        return row !== undefined && row.querySelectorAll('[role="gridcell"]')[3].textContent.trim() === 'No';
      },
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      PROBE,
      NAME_TEXT
    );
    assert.equal(probeEnabled(), '0', 'the instance itself reports the application disabled');
    // In place: the filter that narrowed to this row is still narrowing to it, and it is still
    // the selected row -- which is what "re-fetches in place" means (AD-14).
    assert.equal(await page.$eval(FILTER_SELECTOR, (field) => field.value), PROBE, 'the filter survived the write');
    assert.equal(
      await page.$$eval(ROW_SELECTOR, (rows) => rows.filter((row) => row.getAttribute('aria-selected') === 'true').length),
      1,
      'and the row is still selected'
    );

    // Enable, from the command bar this time: the same handler, the other surface.
    await page.evaluate((label) => {
      const actions = Array.from(document.querySelectorAll('.ocu-command-bar-action'));
      actions.find((action) => action.textContent.trim() === label).click();
    }, STRINGS.agentDefinitionEnable);
    await page.waitForFunction(
      (selector, wanted, textSelector) => {
        const row = Array.from(document.querySelectorAll(selector)).find((candidate) => {
          const cell = candidate.querySelector('[role="gridcell"]');
          const text = cell.querySelector(textSelector);
          return (text === null ? cell : text).textContent.trim() === wanted;
        });
        return row !== undefined && row.querySelectorAll('[role="gridcell"]')[3].textContent.trim() === 'Yes';
      },
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      PROBE,
      NAME_TEXT
    );
    assert.equal(probeEnabled(), '1', 'and the instance reports it enabled again');
    assert.equal(writes.length, 2, 'exactly one request per action, both POSTs');
    assert.deepEqual([...new Set(writes)], ['POST']);
  } finally {
    await context.close();
  }
});

test('AC2: the delete dialog asks for the name, and only an exact match releases the destructive button', async () => {
  const { context, page, writes } = await signedInAtList();
  try {
    await selectOnly(page, PROBE);
    await openRowMenu(page);
    await page.evaluate((label) => {
      const items = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'));
      items.find((item) => item.textContent.trim().startsWith(label)).click();
    }, STRINGS.actionDelete);
    await page.waitForSelector('[role="dialog"]', { timeout: config.navigationTimeoutMs });

    const opened = await page.evaluate(() => ({
      title: document.querySelector('.ocu-dialog-title').textContent.trim(),
      consequence: document.querySelector('.ocu-typed-name-consequence').textContent.trim(),
      label: document.querySelector('.ocu-typed-name-label').textContent.trim(),
      action: document.querySelector('.ocu-button-destructive').textContent.trim(),
      ariaDisabled: document.querySelector('.ocu-button-destructive').getAttribute('aria-disabled'),
      disabled: document.querySelector('.ocu-button-destructive').hasAttribute('disabled'),
      focused: document.activeElement.className,
    }));
    assert.equal(opened.title, `${STRINGS.actionDelete} ${PROBE}`, 'the title names the verb and the target');
    assert.equal(opened.consequence, STRINGS.webAppDeleteConsequence, 'the body states the consequence');
    assert.equal(opened.label, STRINGS.formTypedNameConfirm.split('<name>').join(PROBE));
    assert.equal(opened.action, `${STRINGS.actionDelete} ${PROBE}`, 'the button is labeled with the verb and the target');
    assert.equal(opened.ariaDisabled, 'true', 'and is aria-disabled to begin with');
    assert.equal(opened.disabled, false, 'never the disabled attribute');
    assert.ok(opened.focused.includes('ocu-typed-name-field'), `initial focus is the typed-name field, not ${opened.focused}`);

    // A mismatch on blur: the published message, aria-invalid, and Enter that does not submit.
    await page.type('.ocu-typed-name-field', PROBE.toUpperCase());
    await page.evaluate(() => document.querySelector('.ocu-typed-name-field').blur());
    await page.waitForSelector('.ocu-typed-name-mismatch', { timeout: config.navigationTimeoutMs });
    const mismatch = await page.evaluate(() => ({
      message: document.querySelector('.ocu-typed-name-mismatch').textContent.trim(),
      invalid: document.querySelector('.ocu-typed-name-field').getAttribute('aria-invalid'),
      describedBy: document.querySelector('.ocu-typed-name-field').getAttribute('aria-describedby'),
      mismatchId: document.querySelector('.ocu-typed-name-mismatch').id,
      ariaDisabled: document.querySelector('.ocu-button-destructive').getAttribute('aria-disabled'),
    }));
    assert.equal(mismatch.message, STRINGS.formTypedNameMismatch);
    assert.equal(mismatch.invalid, 'true');
    assert.equal(mismatch.describedBy, mismatch.mismatchId, 'the message is what describes the field');
    assert.equal(mismatch.ariaDisabled, 'true', 'and the button is still aria-disabled on a case mismatch');
    await page.focus('.ocu-typed-name-field');
    await page.keyboard.press('Enter');
    assert.equal(writes.length, 0, 'Enter on a mismatch submits nothing');
    assert.notEqual(probeEnabled(), 'gone', 'and the application is still there');

    // The exact name releases it, and Enter submits.
    await page.click('.ocu-typed-name-field', { clickCount: 3 });
    await page.keyboard.press('Backspace');
    await page.type('.ocu-typed-name-field', PROBE);
    await page.waitForFunction(
      () => document.querySelector('.ocu-button-destructive')?.getAttribute('aria-disabled') === null,
      { timeout: config.navigationTimeoutMs }
    );
    await page.keyboard.press('Enter');
    await page.waitForFunction(
      (selector, wanted, textSelector) =>
        !Array.from(document.querySelectorAll(selector)).some((row) => {
          const cell = row.querySelector('[role="gridcell"]');
          const text = cell.querySelector(textSelector);
          return (text === null ? cell : text).textContent.trim() === wanted;
        }),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      PROBE,
      NAME_TEXT
    );
    assert.equal(writes.length, 1, 'exactly one request, sent only once the name matched');
    assert.equal(probeEnabled(), 'gone', 'and the instance no longer holds the application');
  } finally {
    // Every later test in this file needs the probe application back.
    createProbe();
    await context.close();
  }
});

test("AC3: OcuPilot's own application lists its actions with the refusal inline, never Material-disabled", async () => {
  const { context, page, writes } = await signedInAtList();
  try {
    await selectOnly(page, OWN);
    const entries = await openRowMenu(page);
    assert.equal(entries.length, 3, 'all three actions are still listed');
    for (const entry of entries) {
      assert.equal(entry.reason, STRINGS.webAppServesOcuPilotRefusal, `${entry.label} carries the published reason inline`);
      assert.equal(entry.name, `${entry.label} ${STRINGS.webAppServesOcuPilotRefusal}`, 'which is part of its accessible name');
      assert.equal(entry.ariaDisabled, 'true', 'aria-disabled');
      assert.equal(entry.disabled, false, 'never the disabled attribute a key manager would skip');
      assert.equal(entry.tabIndex, '-1', 'and still in the menu, reachable by the arrow keys');
    }

    // Pressing one anyway sends nothing: the surfaces explain, and the instance refuses.
    await page.evaluate((label) => {
      const items = Array.from(document.querySelectorAll('[role="menu"] [role="menuitem"]'));
      items.find((item) => item.textContent.trim().startsWith(label)).click();
    }, STRINGS.actionDelete);
    assert.equal(writes.length, 0, 'no request left the browser');
    assert.equal(await page.$('[role="dialog"]'), null, 'and no typed-name dialog opened');
  } finally {
    await context.close();
  }
});
