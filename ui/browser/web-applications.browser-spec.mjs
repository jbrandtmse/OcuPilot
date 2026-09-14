/**
 * The web applications list in a real browser, against the throwaway instance: the declared read,
 * table and AdminPort end to end (AC1), the gated screen for a principal without `%Admin_Secure`
 * (AC3), the entity id carried in one route segment (AC5), and the side bar following the command
 * box and the locator's area segment (AC6).
 *
 * **It needs the demo fixture** (`OCUPILOT_DEMO=1`, AD-25), because `/csp/myapp` is the row the
 * disabled-with-no-resource treatment is asserted on, and **it creates a security principal**, so it
 * refuses the live container. The denied principal holds read on the install namespace's code
 * database and `%Admin_Operate:USE`, the shape `OcuPilot.Test.Wire` builds; `after` deletes it and
 * its role whether or not a test failed.
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

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { formatDeniedScreen, formatRequires } = await import(join(uiRoot, 'src', 'app', 'core', 'navigation.ts'));

const config = browserConfig();
const LIST_PATH = '/ocupilot/web-applications/list';
const LIST_URL = `${LIST_PATH}?ns=HSCUSTOM`;
const READ_PATH = '/api/ocupilot/screens/webapp.list/read';
const DENIED_USER = 'OcuPilotWebAppsProbe';
const DENIED_ROLE = 'OcuPilotWebAppsProbeRole';
const DENIED_PASSWORD = 'OcuPilotWebApps1';
const DENIED_PAIR = '%Admin_Secure:USE';

let browser = null;

/**
 * Run ObjectScript lines in `iris session` inside the throwaway, starting in `%SYS`, and return the
 * value each named marker carries. Markers are split on their source line, so the echoed source
 * cannot supply one.
 */
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

function deletePrincipal() {
  return irisSession(
    [
      `If ##class(Security.Users).Exists("${DENIED_USER}") Do ##class(Security.Users).Delete("${DENIED_USER}")`,
      `If ##class(Security.Roles).Exists("${DENIED_ROLE}") Do ##class(Security.Roles).Delete("${DENIED_ROLE}")`,
      mark('CLEAN', `('##class(Security.Users).Exists("${DENIED_USER}"))&&('##class(Security.Roles).Exists("${DENIED_ROLE}"))`),
    ],
    ['CLEAN']
  );
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates a security principal, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);

  const { values, output } = irisSession(
    [
      'Set tNS=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")',
      'Set tRes=##class(SYS.Database).%OpenId(##class(Config.Databases).Open(##class(Config.Namespaces).Open(tNS).Routines).Directory).ResourceName',
      `If ##class(Security.Users).Exists("${DENIED_USER}") Do ##class(Security.Users).Delete("${DENIED_USER}")`,
      `If ##class(Security.Roles).Exists("${DENIED_ROLE}") Do ##class(Security.Roles).Delete("${DENIED_ROLE}")`,
      `Set tSC=##class(Security.Roles).Create("${DENIED_ROLE}","OcuPilot web applications browser spec probe (throwaway)",tRes_":R,%Admin_Operate:U","")`,
      `Set tSC2=##class(Security.Users).Create("${DENIED_USER}","${DENIED_ROLE}","${DENIED_PASSWORD}","OcuPilot web applications browser spec probe (throwaway)","","","",0,1,"")`,
      mark('USER', '$System.Status.IsOK(tSC)&&$System.Status.IsOK(tSC2)'),
      mark('SECURE', `$SYSTEM.Security.CheckUserPermission("${DENIED_USER}","%Admin_Secure","USE")`),
      mark('OPERATE', `$SYSTEM.Security.CheckUserPermission("${DENIED_USER}","%Admin_Operate","USE")`),
    ],
    ['USER', 'SECURE', 'OPERATE']
  );
  assert.equal(values.USER, '1', `the denied principal was created:\n${output}`);
  assert.equal(values.OPERATE, '1', 'and holds %Admin_Operate:USE');
  assert.equal(values.SECURE, '0', 'and not %Admin_Secure:USE');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  const { values, output } = deletePrincipal();
  assert.equal(values.CLEAN, '1', `the denied principal and its role are gone:\n${output}`);
});

/** A fresh context signed in through the shell's own form at the list's deep link, with its read requests counted. */
async function signedInAtList(user, password) {
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const reads = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname.startsWith('/api/ocupilot/screens/')) reads.push(request.url());
  });
  await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', user);
  await page.type('#ocu-signin-password', password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  return { context, page, reads };
}

async function waitForRows(page) {
  await page.waitForSelector('[role="grid"] .ocu-data-table-body [role="row"]', { timeout: config.navigationTimeoutMs });
}

/**
 * Set the command bar's filter to `text` and wait until every rendered row contains it in some cell,
 * ignoring case, and the row named `name` is among them. The filter matches any declared filter
 * field, so the whole row is what each row is held to.
 */
async function filterTo(page, text, name) {
  await page.click('#ocu-command-bar-filter', { clickCount: 3 });
  await page.keyboard.press('Backspace');
  await page.type('#ocu-command-bar-filter', text);
  await page.waitForFunction(
    (wanted, target) => {
      const rows = Array.from(document.querySelectorAll('[role="grid"] .ocu-data-table-body [role="row"]'));
      return (
        rows.length > 0 &&
        rows.every((row) => row.textContent.toLowerCase().includes(wanted.toLowerCase())) &&
        rows.some((row) => row.querySelector('[role="gridcell"]').textContent.trim() === target)
      );
    },
    { timeout: config.navigationTimeoutMs },
    text,
    name
  );
}

/** The rendered row whose name cell reads `name`, described cell by cell. */
function describeRow(page, name) {
  return page.evaluate((wanted) => {
    const style = (element) => (element === null ? null : getComputedStyle(element).fontFamily.replace(/["']/g, ''));
    const root = getComputedStyle(document.documentElement);
    const rows = Array.from(document.querySelectorAll('[role="grid"] .ocu-data-table-body [role="row"]'));
    const row = rows.find((candidate) => candidate.querySelector('[role="gridcell"]').textContent.trim() === wanted);
    if (row === undefined) return null;
    const cells = Array.from(row.querySelectorAll('[role="gridcell"]')).map((cell) => {
      const text = cell.querySelector('.ocu-data-table-link, .ocu-data-table-text');
      const disc = cell.querySelector('.ocu-data-table-disc');
      return {
        text: cell.textContent.trim(),
        family: style(text),
        disc: disc === null ? null : { width: disc.getBoundingClientRect().width, kind: disc.getAttribute('data-disc'), next: disc.nextElementSibling?.textContent.trim() },
      };
    });
    return {
      cells,
      code: root.getPropertyValue('--ocu-type-code-family').trim().replace(/["']/g, ''),
      body: root.getPropertyValue('--ocu-type-body-family').trim().replace(/["']/g, ''),
    };
  }, name);
}

test('AC1: the list reads once over the real AdminPort and renders the declared columns and cell treatments', async () => {
  const { context, page, reads } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page);
    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers, [
      STRINGS.tableColumnName,
      STRINGS.headerNamespaceLabel,
      STRINGS.tableColumnType,
      STRINGS.tableColumnEnabled,
      STRINGS.webAppColumnDispatchClass,
      STRINGS.webAppColumnResource,
    ]);
    assert.deepEqual(headers, ['Name', 'Namespace', 'Type', 'Enabled', 'Dispatch class', 'Resource']);

    // Each leg below narrows through a different declared filter field: Type, Resource, Dispatch
    // class, Namespace, then Name.
    await filterTo(page, 'System,CSP', '/csp/sys');
    const sys = await describeRow(page, '/csp/sys');
    assert.ok(sys !== null, 'the /csp/sys row is rendered');
    assert.equal(sys.cells[2].text, 'System,CSP', "the Type cell reads the vendor's string verbatim");
    assert.equal(sys.cells[2].family, sys.body, 'in body type');

    await filterTo(page, '%Admin_Operate', '/csp/sys/op');
    const operate = await describeRow(page, '/csp/sys/op');
    assert.equal(operate.cells[5].text, '%Admin_Operate', 'a declared resource is listed');
    assert.equal(operate.cells[5].family, operate.code, 'in the code face');

    await filterTo(page, '%Api.Atelier', '/api/atelier');
    const atelier = await describeRow(page, '/api/atelier');
    assert.equal(atelier.cells[4].text, '%Api.Atelier', 'a dispatch class is listed');
    assert.equal(atelier.cells[4].family, atelier.code, 'in the code face');

    // Nothing in /csp/myapp's row but its Namespace cell contains HSCUSTOM.
    await filterTo(page, 'HSCUSTOM', '/csp/myapp');

    await filterTo(page, 'myapp', '/csp/myapp');
    const myapp = await describeRow(page, '/csp/myapp');
    assert.ok(myapp !== null, 'typing myapp in Filter rows leaves the /csp/myapp row in view');
    assert.equal(myapp.cells[0].family, myapp.code, 'its name is in the code face');
    assert.equal(myapp.cells[1].family, myapp.code, 'and so is its namespace');
    assert.deepEqual(myapp.cells[3].disc, { width: 7, kind: 'outline', next: STRINGS.tableStatusNo }, 'Enabled shows a 7px outline disc and then "No"');
    assert.equal(myapp.cells[3].text, STRINGS.tableStatusNo);
    assert.equal(myapp.cells[4].text, STRINGS.tableEmptyValue, 'an empty dispatch class reads (none)');
    assert.equal(myapp.cells[5].text, STRINGS.tableEmptyValue, 'and so does an empty resource');

    assert.equal(reads.length, 1, `exactly one screen read was issued: ${JSON.stringify(reads)}`);
    assert.equal(new URL(reads[0]).pathname, READ_PATH);
  } finally {
    await context.close();
  }
});

test("AC5: the /csp/myapp name link carries the id in one route segment and the outlet decodes it once", async () => {
  const { context, page } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page);
    await filterTo(page, 'myapp', '/csp/myapp');
    await page.evaluate(() => {
      const rows = Array.from(document.querySelectorAll('[role="grid"] .ocu-data-table-body [role="row"]'));
      const row = rows.find((candidate) => candidate.querySelector('[role="gridcell"]').textContent.trim() === '/csp/myapp');
      row.querySelector('.ocu-data-table-link').click();
    });
    await page.waitForFunction(() => window.location.pathname.endsWith('/web-applications/list/%252Fcsp%252Fmyapp'), {
      timeout: config.navigationTimeoutMs,
    });
    await page.waitForSelector('.ocu-screen-outlet[data-id="/csp/myapp"]', { timeout: config.navigationTimeoutMs });
    const dataId = await page.$eval('.ocu-screen-outlet', (outlet) => outlet.getAttribute('data-id'));
    assert.equal(dataId, '/csp/myapp');
  } finally {
    await context.close();
  }
});

test("AC6: the command box and the locator's area segment open the side bar on the Web applications area", async () => {
  const { context, page } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page);
    const sideBar = () =>
      page.evaluate(() => {
        const nav = document.querySelector('app-side-bar nav.ocu-side-bar');
        if (nav === null) return null;
        const current = nav.querySelector('.ocu-side-bar-item[aria-current="page"] .ocu-side-bar-label');
        return { area: nav.querySelector('.ocu-side-bar-eyebrow').textContent.trim(), current: current === null ? null : current.textContent.trim() };
      });

    await page.click(`.ocu-rail-item[aria-label="${STRINGS.navAreaLogs}"]`);
    await page.waitForFunction((label) => document.querySelector('app-side-bar .ocu-side-bar-eyebrow')?.textContent.trim() === label, {}, STRINGS.navAreaLogs);

    await page.click('[role="combobox"]');
    await page.type('[role="combobox"]', 'web apps');
    await page.waitForSelector('#ocu-command-box-screen-web-applications-list');
    await page.keyboard.press('Enter');
    await page.waitForFunction(
      (label) => document.querySelector('app-side-bar .ocu-side-bar-eyebrow')?.textContent.trim() === label,
      { timeout: config.navigationTimeoutMs },
      STRINGS.navAreaWebApplications
    );
    assert.deepEqual(await sideBar(), { area: STRINGS.navAreaWebApplications, current: STRINGS.webAppListLabel });

    await page.focus('[role="grid"]');
    await page.keyboard.down('Control');
    await page.keyboard.press('b');
    await page.keyboard.up('Control');
    await page.waitForFunction(() => document.querySelector('app-side-bar nav.ocu-side-bar') === null, { timeout: config.navigationTimeoutMs });

    const clicked = await page.evaluate((label) => {
      const segment = Array.from(document.querySelectorAll('.ocu-locator-link')).find((link) => link.textContent.trim() === label);
      segment?.click();
      return segment !== undefined;
    }, STRINGS.navAreaWebApplications);
    assert.equal(clicked, true, "the locator carries the area segment");
    await page.waitForFunction(() => document.querySelector('app-side-bar nav.ocu-side-bar') !== null, { timeout: config.navigationTimeoutMs });
    assert.deepEqual(await sideBar(), { area: STRINGS.navAreaWebApplications, current: STRINGS.webAppListLabel });
  } finally {
    await context.close();
  }
});

test('AC3: a principal without %Admin_Secure sees the screen gated in the rail, the command box and the side bar, and its deep link refused with no read', async () => {
  const { context, page, reads } = await signedInAtList(DENIED_USER, DENIED_PASSWORD);
  try {
    const requires = formatRequires(STRINGS.privilegeRequiresResource, DENIED_PAIR);
    await page.waitForSelector('app-screen-denied .ocu-screen-denied-title', { timeout: config.navigationTimeoutMs });
    const denied = await page.evaluate(() => ({
      title: document.querySelector('app-screen-denied .ocu-screen-denied-title').textContent.trim(),
      reason: document.querySelector('app-screen-denied .ocu-screen-denied-reason').textContent.trim(),
      grid: document.querySelector('[role="grid"]') !== null,
    }));
    assert.equal(denied.title, STRINGS.webAppListLabel, 'the deep link renders the screen title');
    assert.equal(denied.reason, formatDeniedScreen(STRINGS.privilegeDeniedScreen, DENIED_PAIR, STRINGS.webAppListLabel));
    assert.equal(denied.reason, 'You need %Admin_Secure:USE to open Web applications.');
    assert.equal(requires, 'Requires %Admin_Secure:USE');
    assert.equal(denied.grid, false, 'and no table');

    if ((await page.$('app-side-bar nav.ocu-side-bar')) === null) {
      await page.keyboard.down('Control');
      await page.keyboard.press('b');
      await page.keyboard.up('Control');
    }
    await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
    const entry = await page.evaluate((label) => {
      const item = Array.from(document.querySelectorAll('app-side-bar .ocu-side-bar-item')).find(
        (candidate) => candidate.querySelector('.ocu-side-bar-label').textContent.trim() === label
      );
      return item === undefined ? null : { disabled: item.getAttribute('aria-disabled'), text: item.textContent };
    }, STRINGS.webAppListLabel);
    assert.ok(entry !== null, 'the side bar lists Web applications');
    assert.equal(entry.disabled, 'true');
    assert.ok(entry.text.includes(requires), `with the reason inline: ${entry.text}`);

    const rail = await page.evaluate((label) => {
      const item = document.querySelector(`.ocu-rail-item[aria-label="${label}"]`);
      return { disabled: item.getAttribute('aria-disabled'), tip: document.getElementById(item.getAttribute('aria-describedby'))?.textContent.trim() };
    }, STRINGS.navAreaWebApplications);
    assert.deepEqual(rail, { disabled: 'true', tip: requires }, 'the rail item is gated with its reason');

    await page.click('[role="combobox"]');
    await page.type('[role="combobox"]', 'web apps');
    await page.waitForSelector('#ocu-command-box-screen-web-applications-list');
    const row = await page.$eval('#ocu-command-box-screen-web-applications-list', (option) => ({
      disabled: option.getAttribute('aria-disabled'),
      text: option.textContent,
    }));
    assert.equal(row.disabled, 'true', 'the command-box row is gated');
    assert.ok(row.text.includes(STRINGS.webAppListLabel) && row.text.includes(requires), `with the reason inline: ${row.text}`);

    assert.deepEqual(reads, [], 'no screen read was issued');
  } finally {
    await context.close();
  }
});
