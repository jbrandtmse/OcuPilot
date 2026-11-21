/**
 * Stories 21.3 and 21.4 in a real browser, against the throwaway instance: Startup, Memory, Compatibility, SQL, SQL Shell, TSQL and ISQL
 * settings (AD-5, AD-29, AD-53).
 *
 * What it pins: each screen answers the navigation map and its rows before anything is read; Set value on `LineRecall` opens its dialog over
 * the row, the checkbox flips it, the instance stores the new value and the list shows it without a reload; the dialog over `NullSubscripts`
 * states the restart sentence and, canceled, sends nothing; a row that is shown and never changed (`DefaultPort`) draws Set value unavailable
 * with the published sentence and opens no dialog. The four SQL screens answer their rows; Set value on `SaveMAC` flips `Config.SQL` and the list
 * shows it; the dialog over `FastDistinct` states the purge sentence and, canceled, sends nothing; `DefaultSchema` and `EscapeCondition` draw
 * Set value unavailable.
 *
 * Story 21.19's Task Manager email lists its twelve settings and never the mail password; Set value on `Port` refuses a port out of range, stores
 * a port and shows it without a reload; a subject naming another field is refused with the Task Manager's fields. Story 21.36's Set mail password,
 * the toolbar button of the same screen, stores a generated password through a masked field and an empty one clears it, and the page shows the
 * password nowhere.
 *
 * **It changes one compatibility setting, one SQL setting, the Task Manager email port and the Task Manager mail password** through the shipped screens, so it runs on a throwaway
 * only; the `after` hook puts `LineRecall`, `SaveMAC` and `Port` back to the values it found and clears the password (which the `before` hook asserts is empty, answering 1 or 0 and
 * never a value), whatever the tests answered.
 *
 * Run: `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/config-settings.browser-spec.mjs` (after `npm run build` and the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { FILTER_SELECTOR, ROW_SELECTOR, clickRowCentre, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';
import { markerValue, runIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const route = (name) => `/ocupilot/os-management/${name}`;
const NAME = 'LineRecall';
const SQL_NAME = 'SaveMAC';
const MAIL_NAME = 'Port';
const MAIL_NAMES = ['AuthUser', 'MessageFailure', 'MessageSuccess', 'Port', 'ReplyTo', 'SSLConfiguration', 'Sender', 'Server', 'SubjectFailure', 'SubjectSuccess', 'TimeZone', 'UseSTARTTLS'];

let browser = null;
let found = '';
let foundSql = '';
let foundMail = '';
let touched = false;

/** The Task Manager email setting `name`, as `EmailGet` answers it. */
function storedMail(name) {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    `Set tSC=##class(%SYS.Task.Config).EmailGet("${name}",.v)`,
    'Write "OCU-MAILGET-START:"_$Get(v)_":OCU-MAILGET-END",!',
  ]);
  return { value: markerValue(output, 'MAILGET'), output };
}

/** Put the Task Manager email setting `name` back to `value` through `EmailSet`, answering whether the status was OK. */
function restoreMail(name, value) {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    `Write "OCU-MAILPUT-START:"_$System.Status.IsOK(##class(%SYS.Task.Config).EmailSet("${name}","${value}"))_":OCU-MAILPUT-END",!`,
  ]);
  return { value: markerValue(output, 'MAILPUT'), output };
}

/**
 * Whether the Task Manager mail password reads `expected` (`''` for none), compared inside the instance: 1 or 0, and neither value is printed, kept or put in a message.
 * `''` answers the empty case, and a probe is a generated name.
 */
function mailPasswordIs(expected) {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    'Set tSC=##class(%SYS.Task.Config).EmailGet("AuthPassword",.v)',
    `Write "OCU-MAILPW-START:"_($System.Status.IsOK(tSC)&&($Get(v)="${expected}"))_":OCU-MAILPW-END",!`,
  ]);
  return markerValue(output, 'MAILPW');
}

/** Clear the Task Manager mail password through `EmailSet`, answering whether the status was OK. */
function clearMailPassword() {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    'Write "OCU-MAILPWPUT-START:"_$System.Status.IsOK(##class(%SYS.Task.Config).EmailSet("AuthPassword",""))_":OCU-MAILPWPUT-END",!',
  ]);
  return markerValue(output, 'MAILPWPUT');
}

/** The setting `name` of `Config.Miscellaneous`, as the instance stores it. */
function stored(name) {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    'Do ##class(Config.Miscellaneous).Get(.p)',
    `Write "OCU-CFGGET-START:"_$Get(p("${name}"))_":OCU-CFGGET-END",!`,
  ]);
  return { value: markerValue(output, 'CFGGET'), output };
}

/** Put `LineRecall` back to `value`, answering the status of the write. */
function restore(value) {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    'Do ##class(Config.Miscellaneous).Get(.p)',
    `Set p("${NAME}")=${Number(value)}`,
    'Write "OCU-CFGPUT-START:"_$System.Status.IsOK(##class(Config.Miscellaneous).Modify(.p))_":OCU-CFGPUT-END",!',
  ]);
  return { value: markerValue(output, 'CFGPUT'), output };
}

/** The setting `name` of `Config.SQL`, as the instance stores it. */
function storedSql(name) {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    'Do ##class(Config.SQL).Get(.p)',
    `Write "OCU-SQLGET-START:"_$Get(p("${name}"))_":OCU-SQLGET-END",!`,
  ]);
  return { value: markerValue(output, 'SQLGET'), output };
}

/** Put `SaveMAC` back to `value`, answering the status of the write. */
function restoreSql(value) {
  const output = runIris(config.container, [
    'Set $NAMESPACE="%SYS"',
    'Do ##class(Config.SQL).Get(.p)',
    `Set p("${SQL_NAME}")=${Number(value)}`,
    'Write "OCU-SQLPUT-START:"_$System.Status.IsOK(##class(Config.SQL).Modify(.p))_":OCU-SQLPUT-END",!',
  ]);
  return { value: markerValue(output, 'SQLPUT'), output };
}

/** The screen has answered the navigation map and drew its rows. */
async function answered(page) {
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  await waitForRows(page, config.navigationTimeoutMs);
}

/** The first cell of every rendered body row. */
function names(page) {
  return page.$$eval(ROW_SELECTOR, (rows) => rows.map((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() ?? ''));
}

/** Narrow the list to the rows naming `name`, then click that row on its second cell, which selects it. */
async function selectRow(page, name) {
  await page.click(FILTER_SELECTOR, { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type(FILTER_SELECTOR, name);
  await page.waitForFunction(
    (rowSelector, wanted) => [...document.querySelectorAll(rowSelector)].some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() === wanted),
    { timeout: config.navigationTimeoutMs },
    ROW_SELECTOR,
    name
  );
  await clickRowCentre(page, { text: name, cell: 2 });
}

/** Open the selected row's menu and answer its Set value entry, `aria-disabled` and its reason included. */
async function setValueEntry(page) {
  await (await page.waitForSelector('[role="row"][aria-selected="true"] .ocu-data-table-trigger', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('[role="menu"] [role="menuitem"]', { timeout: config.navigationTimeoutMs });
  return page.evaluate((wanted) => {
    const item = [...document.querySelectorAll('[role="menu"] [role="menuitem"]')].find((entry) => entry.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted);
    if (item === undefined) return null;
    return { disabled: item.getAttribute('aria-disabled') === 'true', reason: item.querySelector('.ocu-data-table-menu-reason')?.textContent.trim() ?? '' };
  }, STRINGS.interopItemSettingSetAction);
}

/** Click the menu's Set value entry, which opens the dialog. */
async function clickSetValue(page) {
  await page.evaluate((wanted) => [...document.querySelectorAll('[role="menu"] [role="menuitem"]')].find((entry) => entry.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted).click(), STRINGS.interopItemSettingSetAction);
  await page.waitForSelector('[data-interop-setting-consequence]', { visible: true, timeout: config.navigationTimeoutMs });
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec runs commands inside the container, so it never runs against the live one');
  await assertThrowaway(config);
  assert.match(config.container, /-ci$/, `this spec changes a compatibility setting, so it runs only in a throwaway; ${config.container} is not one`);
  const read = stored(NAME);
  assert.match(read.value ?? '', /^[01]$/, `${NAME} reads 0 or 1 on the instance: ${read.output}`);
  found = read.value;
  const readSql = storedSql(SQL_NAME);
  assert.match(readSql.value ?? '', /^[01]$/, `${SQL_NAME} reads 0 or 1 on the instance: ${readSql.output}`);
  foundSql = readSql.value;
  const readMail = storedMail(MAIL_NAME);
  assert.match(readMail.value ?? '', /^[0-9]{0,5}$/, `${MAIL_NAME} of the Task Manager email reads a port or nothing on the instance: ${readMail.output}`);
  foundMail = readMail.value;
  assert.equal(mailPasswordIs(''), '1', 'the Task Manager mail password is empty on the throwaway, so the clear after the run puts it back');
  touched = true;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (touched && /-ci$/.test(config.container)) {
      // Both restores run before either is asserted, so a failed first one cannot leave the second setting changed.
      const put = restore(found);
      const putSql = restoreSql(foundSql);
      const putMail = restoreMail(MAIL_NAME, foundMail);
      const clearedPassword = clearMailPassword();
      assert.equal(clearedPassword, '1', 'the Task Manager mail password is cleared again');
      assert.equal(mailPasswordIs(''), '1', 'and reads empty');
      assert.equal(putMail.value, '1', `${MAIL_NAME} of the Task Manager email is put back to '${foundMail}': ${putMail.output}`);
      assert.equal(storedMail(MAIL_NAME).value, foundMail, `and reads '${foundMail}' again`);
      assert.equal(put.value, '1', `${NAME} is put back to ${found}: ${put.output}`);
      assert.equal(stored(NAME).value, found, `and reads ${found} again`);
      assert.equal(putSql.value, '1', `${SQL_NAME} is put back to ${foundSql}: ${putSql.output}`);
      assert.equal(storedSql(SQL_NAME).value, foundSql, `and reads ${foundSql} again`);
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

test('each of the seven screens answers its rows before anything is read', async () => {
  for (const [screen, expected] of [
    ['startup-settings', ['ErrorPurge', 'ShutdownTimeout', 'DefaultPort']],
    ['memory-settings', ['errlog', 'history', 'bbsiz']],
    ['compatibility-settings', [NAME, 'NullSubscripts', 'Undefined']],
    ['sql-settings', [SQL_NAME, 'FastDistinct', 'LockTimeout']],
    ['sql-shell-settings', ['SelectMode', 'Path', 'EchoMode']],
    ['tsql-settings', ['DIALECT', 'ANSI_NULLS', 'TRACE']],
    ['isql-settings', ['DELIMIDENT', 'RESERVEDWORDPREFIX', 'FUNCTIONRETURNSSET']],
  ]) {
    const { context, page } = await signedInAt(browser, config, route(screen), VIEWPORTS.wide);
    try {
      await answered(page);
      await page.click(FILTER_SELECTOR, { clickCount: 3 });
      for (const name of expected) {
        await page.keyboard.press('Backspace');
        await page.type(FILTER_SELECTOR, name);
        await page.waitForFunction(
          (rowSelector, wanted) => [...document.querySelectorAll(rowSelector)].some((row) => row.querySelector('[role="gridcell"]')?.textContent.trim() === wanted),
          { timeout: config.navigationTimeoutMs },
          ROW_SELECTOR,
          name
        );
        assert.ok((await names(page)).includes(name), `${screen} lists ${name}`);
        await page.click(FILTER_SELECTOR, { clickCount: 3 });
      }
    } finally {
      await context.close();
    }
  }
});

test('Set value on LineRecall flips it on the instance, shown without a reload', async () => {
  const flipped = found === '1' ? '0' : '1';
  const { context, page } = await signedInAt(browser, config, route('compatibility-settings'), VIEWPORTS.wide);
  try {
    await answered(page);
    await page.evaluate(() => {
      window.__ocuNoReload = 'standing';
    });
    await selectRow(page, NAME);
    const entry = await setValueEntry(page);
    assert.deepEqual(entry, { disabled: false, reason: '' }, 'Set value is offered on a setting that may change');
    await clickSetValue(page);
    assert.equal(await page.$eval('[data-interop-setting-consequence]', (node) => node.textContent.trim()), '0 (off) or 1 (on).', 'the dialog states what the setting accepts, and no restart');
    await page.click('[data-interop-setting-checkbox]');
    await page.click('[data-interop-setting-confirm]');
    await page.waitForSelector('[data-interop-setting-confirm]', { hidden: true, timeout: config.navigationTimeoutMs });
    assert.equal(stored(NAME).value, flipped, `the instance stores ${flipped}`);
    await page.waitForFunction(
      (rowSelector, wanted, value) => [...document.querySelectorAll(rowSelector)].some((row) => {
        const cells = row.querySelectorAll('[role="gridcell"]');
        // The row the instance has just changed carries its marker in its first cell, so it is matched by its start.
        return cells[0]?.textContent.trim().startsWith(wanted) && cells[1]?.textContent.trim() === value;
      }),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      NAME,
      flipped
    );
    assert.equal(await page.evaluate(() => window.__ocuNoReload), 'standing', 'the list re-read without the page reloading');
    assert.equal(await page.$('[data-config-setting-restart]'), null, 'and a setting that needs no restart states none');
  } finally {
    await context.close();
  }
});

test('the dialog over NullSubscripts states the restart sentence, and canceled sends nothing', async () => {
  const before = stored('NullSubscripts').value;
  const { context, page } = await signedInAt(browser, config, route('compatibility-settings'), VIEWPORTS.wide);
  try {
    await answered(page);
    await selectRow(page, 'NullSubscripts');
    assert.equal((await setValueEntry(page))?.disabled, false, 'Set value is offered');
    await clickSetValue(page);
    const statement = await page.$eval('[data-interop-setting-consequence]', (node) => node.textContent.trim());
    assert.ok(statement.endsWith(STRINGS.encryptionStartupRestart), `the dialog states the restart sentence: ${statement}`);
    await page.evaluate((wanted) => [...document.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent.trim() === wanted).click(), STRINGS.actionCancel);
    await page.waitForSelector('[data-interop-setting-consequence]', { hidden: true, timeout: config.navigationTimeoutMs });
    assert.equal(stored('NullSubscripts').value, before, 'nothing was sent: the setting reads as before');
  } finally {
    await context.close();
  }
});

test('a row that is shown and never changed draws Set value unavailable with the published sentence, and opens no dialog', async () => {
  const { context, page } = await signedInAt(browser, config, route('startup-settings'), VIEWPORTS.wide);
  try {
    await answered(page);
    await selectRow(page, 'DefaultPort');
    const entry = await setValueEntry(page);
    assert.deepEqual(entry, { disabled: true, reason: STRINGS.configRefusalReadOnly }, 'Set value is unavailable, naming why');
    await page.evaluate((wanted) => [...document.querySelectorAll('[role="menu"] [role="menuitem"]')].find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted).click(), STRINGS.interopItemSettingSetAction);
    await new Promise((resolve) => setTimeout(resolve, 500));
    assert.equal(await page.$('[data-interop-setting-consequence]'), null, 'and pressing it opens no dialog');
  } finally {
    await context.close();
  }
});

test('Set value on SaveMAC flips it in Config.SQL, shown without a reload, and states no purge', async () => {
  const flipped = foundSql === '1' ? '0' : '1';
  const { context, page } = await signedInAt(browser, config, route('sql-settings'), VIEWPORTS.wide);
  try {
    await answered(page);
    await page.evaluate(() => {
      window.__ocuNoReload = 'standing';
    });
    await selectRow(page, SQL_NAME);
    assert.deepEqual(await setValueEntry(page), { disabled: false, reason: '' }, 'Set value is offered on a setting that may change');
    await clickSetValue(page);
    assert.equal(await page.$eval('[data-interop-setting-consequence]', (node) => node.textContent.trim()), '0 (off) or 1 (on).', 'the dialog states what the setting accepts, and no purge');
    await page.click('[data-interop-setting-checkbox]');
    await page.click('[data-interop-setting-confirm]');
    await page.waitForSelector('[data-interop-setting-confirm]', { hidden: true, timeout: config.navigationTimeoutMs });
    assert.equal(storedSql(SQL_NAME).value, flipped, `the instance stores ${flipped}`);
    await page.waitForFunction(
      (rowSelector, wanted, value) => [...document.querySelectorAll(rowSelector)].some((row) => {
        const cells = row.querySelectorAll('[role="gridcell"]');
        return cells[0]?.textContent.trim().startsWith(wanted) && cells[1]?.textContent.trim() === value;
      }),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      SQL_NAME,
      flipped
    );
    assert.equal(await page.evaluate(() => window.__ocuNoReload), 'standing', 'the list re-read without the page reloading');
    assert.equal(await page.$('[data-config-setting-purge]'), null, 'and a setting that does not purge states no purge');
  } finally {
    await context.close();
  }
});

test('the dialog over FastDistinct states the purge sentence, and canceled sends nothing', async () => {
  const before = storedSql('FastDistinct').value;
  const { context, page } = await signedInAt(browser, config, route('sql-settings'), VIEWPORTS.wide);
  try {
    await answered(page);
    await selectRow(page, 'FastDistinct');
    assert.equal((await setValueEntry(page))?.disabled, false, 'Set value is offered');
    await clickSetValue(page);
    const statement = await page.$eval('[data-interop-setting-consequence]', (node) => node.textContent.trim());
    assert.ok(statement.endsWith(STRINGS.configSettingPurge), `the dialog states the purge sentence: ${statement}`);
    await page.click('[data-interop-setting-checkbox]');
    await page.evaluate((wanted) => [...document.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent.trim() === wanted).click(), STRINGS.actionCancel);
    await page.waitForSelector('[data-interop-setting-consequence]', { hidden: true, timeout: config.navigationTimeoutMs });
    assert.equal(storedSql('FastDistinct').value, before, 'nothing was sent: the setting reads as before, although the value was changed in the dialog');
  } finally {
    await context.close();
  }
});

test('DefaultSchema and the shell EscapeCondition draw Set value unavailable with the published sentence', async () => {
  for (const [screen, name] of [
    ['sql-settings', 'DefaultSchema'],
    ['sql-shell-settings', 'EscapeCondition'],
  ]) {
    const { context, page } = await signedInAt(browser, config, route(screen), VIEWPORTS.wide);
    try {
      await answered(page);
      await selectRow(page, name);
      assert.deepEqual(await setValueEntry(page), { disabled: true, reason: STRINGS.configRefusalReadOnly }, `Set value is unavailable on ${name}, naming why`);
      await page.evaluate((wanted) => [...document.querySelectorAll('[role="menu"] [role="menuitem"]')].find((item) => item.querySelector('.ocu-data-table-menu-label')?.textContent.trim() === wanted).click(), STRINGS.interopItemSettingSetAction);
      await new Promise((resolve) => setTimeout(resolve, 500));
      assert.equal(await page.$('[data-interop-setting-consequence]'), null, `and pressing it opens no dialog over ${name}`);
    } finally {
      await context.close();
    }
  }
});

/** The refusal the dialog states: on the value's field where the instance names it, else above the field in the envelope's own sentence. */
const REFUSAL_SELECTOR = '[data-interop-setting-violation], [data-interop-setting-reason]';

/** Replace the dialog's text with `value`. */
async function typeInDialog(page, value) {
  await page.click('[data-interop-setting-value]', { clickCount: 3 });
  await page.keyboard.press('Backspace');
  if (value !== '') await page.type('[data-interop-setting-value]', value);
}

test('Task Manager email lists its twelve settings and never the mail password', async () => {
  const { context, page } = await signedInAt(browser, config, '/ocupilot/tasks/email', VIEWPORTS.wide);
  try {
    await answered(page);
    const listed = await names(page);
    assert.deepEqual([...listed].sort(), [...MAIL_NAMES].sort(), 'the rows are the twelve settings of the roster');
    assert.ok(!listed.some((entry) => /password/i.test(entry)), 'and none is the mail password');
    assert.equal(await page.evaluate(() => document.body.textContent.includes('AuthPassword')), false, 'the page names it nowhere');
  } finally {
    await context.close();
  }
});

test('Set value on the Task Manager email Port stores it on the instance, refuses a port out of range, and shows the change without a reload', async () => {
  const changed = foundMail === '587' ? '588' : '587';
  const { context, page } = await signedInAt(browser, config, '/ocupilot/tasks/email', VIEWPORTS.wide);
  try {
    await answered(page);
    await page.evaluate(() => {
      window.__ocuNoReload = 'standing';
    });
    await selectRow(page, MAIL_NAME);
    assert.deepEqual(await setValueEntry(page), { disabled: false, reason: '' }, 'Set value is offered on the port');
    await clickSetValue(page);
    await typeInDialog(page, '70000');
    await page.click('[data-interop-setting-confirm]');
    await page.waitForSelector(REFUSAL_SELECTOR, { visible: true, timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval(REFUSAL_SELECTOR, (node) => node.textContent.trim()), STRINGS.configRefusalValue, 'a port out of range stays in the dialog with the published sentence');
    assert.equal(storedMail(MAIL_NAME).value, foundMail, 'and nothing was stored');
    await typeInDialog(page, changed);
    await page.click('[data-interop-setting-confirm]');
    await page.waitForSelector('[data-interop-setting-confirm]', { hidden: true, timeout: config.navigationTimeoutMs });
    assert.equal(storedMail(MAIL_NAME).value, changed, `the instance stores ${changed}`);
    await page.waitForFunction(
      (rowSelector, wanted, value) => [...document.querySelectorAll(rowSelector)].some((row) => {
        const cells = row.querySelectorAll('[role="gridcell"]');
        return cells[0]?.textContent.trim().startsWith(wanted) && cells[1]?.textContent.trim() === value;
      }),
      { timeout: config.navigationTimeoutMs },
      ROW_SELECTOR,
      MAIL_NAME,
      changed
    );
    assert.equal(await page.evaluate(() => window.__ocuNoReload), 'standing', 'the list re-read without the page reloading');
  } finally {
    await context.close();
  }
});

test('a Task Manager email subject naming a field the Task Manager does not fill in is refused with the fields, and stores nothing', async () => {
  const before = storedMail('SubjectFailure').value;
  const { context, page } = await signedInAt(browser, config, '/ocupilot/tasks/email', VIEWPORTS.wide);
  try {
    await answered(page);
    await selectRow(page, 'SubjectFailure');
    assert.equal((await setValueEntry(page))?.disabled, false, 'Set value is offered on the subject');
    await clickSetValue(page);
    await typeInDialog(page, '#(BOGUS)#');
    await page.click('[data-interop-setting-confirm]');
    await page.waitForSelector(REFUSAL_SELECTOR, { visible: true, timeout: config.navigationTimeoutMs });
    const sentence = await page.$eval(REFUSAL_SELECTOR, (node) => node.textContent.trim());
    assert.ok(sentence.startsWith('Use only these fields between #( and )#: ID, DESCRIPTION, NAME,') && sentence.endsWith('ERROR, SUCCESS.'), `the dialog names the Task Manager's fields: ${sentence}`);
    assert.equal(storedMail('SubjectFailure').value, before, 'and the subject reads as before');
  } finally {
    await context.close();
  }
});

/** Open the Set mail password dialog from the command bar's primary button, answering the button's words and the dialog's title. */
async function openMailPassword(page) {
  const button = await page.waitForSelector('.ocu-command-bar button.ocu-command-bar-primary', { visible: true, timeout: config.navigationTimeoutMs });
  const label = await button.evaluate((node) => node.textContent.trim());
  await button.click();
  await page.waitForSelector('[data-interop-setting-secret]', { visible: true, timeout: config.navigationTimeoutMs });
  const title = await page.$eval('.ocu-dialog-title', (node) => node.textContent.trim());
  return { label, title };
}

test('Set mail password stores a typed password through a masked field and an empty one clears it, and the page shows the password nowhere', async () => {
  const probe = `OcuBrowserPw${Date.now()}`;
  const { context, page } = await signedInAt(browser, config, '/ocupilot/tasks/email', VIEWPORTS.wide);
  try {
    await answered(page);
    await page.evaluate(() => {
      window.__ocuNoReload = 'standing';
    });
    const opened = await openMailPassword(page);
    assert.deepEqual(opened, { label: STRINGS.taskMailPasswordAction, title: STRINGS.taskMailPasswordAction }, 'the toolbar button and the dialog both read Set mail password');
    assert.equal(await page.$eval('[data-interop-setting-secret]', (node) => `${node.type}|${node.value}`), 'password|', 'the field is masked and empty');
    await typeInDialog(page, probe);
    await page.click('[data-interop-setting-confirm]');
    await page.waitForSelector('[data-interop-setting-confirm]', { hidden: true, timeout: config.navigationTimeoutMs });
    assert.equal(mailPasswordIs(probe), '1', 'the instance stores the typed password');
    assert.equal(await page.evaluate((text) => document.body.textContent.includes(text), probe), false, 'and the page shows it nowhere');
    assert.equal(await page.evaluate(() => window.__ocuNoReload), 'standing', 'the screen kept its page');
    await openMailPassword(page);
    await page.click('[data-interop-setting-confirm]');
    await page.waitForSelector('[data-interop-setting-confirm]', { hidden: true, timeout: config.navigationTimeoutMs });
    assert.equal(mailPasswordIs(''), '1', 'an empty password clears it');
  } finally {
    await context.close();
  }
});
