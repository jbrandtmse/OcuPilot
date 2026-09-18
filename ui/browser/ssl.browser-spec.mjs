/**
 * The SSL/TLS configurations list in a real browser, against the throwaway instance: the declared
 * read, table and filter end to end (AC1), the demo fixture's row (AC2), the response body carrying
 * no key material (AC3) and the Security and secrets side bar (AC4).
 *
 * **It needs the demo fixture** (`OCUPILOT_DEMO=1`, AD-25), because `OcuPilotDemoTLS` is the row
 * AC2 is asserted on and the one whose Description is non-empty, **and it refuses the live
 * container** for the reason its siblings do: the throwaway is the instance a browser run drives.
 * It creates no security principal -- the pair set's denial is proven over HTTP by
 * `OcuPilot.Test.WireSecurityRead`.
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
const LIST_URL = '/ocupilot/security/ssl?ns=HSCUSTOM';
const READ_PATH = '/api/ocupilot/screens/security.ssl/read';
const DEMO_CONFIG = 'OcuPilotDemoTLS';
const DEMO_DESCRIPTION = 'OcuPilot demo fixture -- not used for any outbound call';
const KEY_MATERIAL = ['PrivateKeyPassword', 'PrivateKeyFile', 'PrivateKeyType', 'CertificateFile', 'CAFile', 'CAPath'];

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec drives the throwaway, never the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
});

/**
 * A fresh context signed in through the shell's own form at the list's deep link, with its read
 * requests counted.
 *
 * `bodies` is this spec's own addition to the shape `users.browser-spec.mjs` uses: AC3 is about
 * what the response carries, and the only place a browser run can see that is the response itself.
 */
async function signedInAtList(user, password) {
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const reads = [];
  const bodies = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname.startsWith('/api/ocupilot/screens/')) reads.push(request.url());
  });
  page.on('response', (response) => {
    if (!new URL(response.url()).pathname.startsWith('/api/ocupilot/screens/')) return;
    bodies.push(
      response
        .text()
        .then((text) => ({ url: response.url(), text }))
        .catch(() => ({ url: response.url(), text: '' }))
    );
  });
  await page.goto(`${config.origin}${LIST_URL}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', user);
  await page.type('#ocu-signin-password', password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  // The first-login gate takes an administrator to the Definition form on an instance with no
  // enabled definition, whatever URL was asked for (Story 3.6). Back returns to this one.
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, LIST_URL);
  return { context, page, reads, bodies };
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
        link: cell.querySelector('.ocu-data-table-link') !== null,
        disc: disc === null ? null : { width: disc.getBoundingClientRect().width, kind: disc.getAttribute('data-disc'), next: disc.nextElementSibling?.textContent.trim() },
      };
    });
    return { cells, code: root.getPropertyValue('--ocu-type-code-family').trim().replace(/["']/g, '') };
  }, name);
}

test('AC1: the list reads once under the declared headers, renders its rows, and filters on the name and on the description', async () => {
  const { context, page, reads } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const headers = await page.$$eval('.ocu-data-table-header-label', (labels) => labels.map((label) => label.textContent.trim()));
    assert.deepEqual(headers, [
      STRINGS.tableColumnName,
      STRINGS.tableColumnDescription,
      STRINGS.tableColumnEnabled,
      STRINGS.tableColumnType,
    ]);
    assert.deepEqual(headers, ['Name', 'Description', 'Enabled', 'Type']);
    const total = await viewCount(page);
    assert.ok(total >= 2, `the instance lists at least two configurations: ${total}`);

    const demo = await describeRow(page, DEMO_CONFIG);
    assert.ok(demo !== null, `the ${DEMO_CONFIG} row is rendered`);
    assert.equal(demo.cells[0].link, true, 'its name cell is a link');
    assert.equal(demo.cells[0].family, demo.code, 'in the code face');
    assert.equal(demo.cells[3].text, 'Client', "the Type cell reads the vendor's own word");

    // The filter narrows through Description, then through Name -- two of the three declared
    // filter fields. `filterToSubset` runs each leg from the whole list and refuses a filter that
    // narrows nothing, which is what a leg chained onto the previous one could not do (DW-267).
    // The description leg must name the demo row alone, not merely a word its description happens
    // to carry: the installer's own `OcuPilotProvider` configuration is described as OcuPilot's
    // outbound provider calls, so 'outbound' matches two rows on any installed instance.
    // Asserted as "the expected row survived and the list narrowed", never as an exact count
    // (DW-368). `filterToSubset` already refuses a leg that keeps nothing, keeps everything, or
    // loses `expectRow`; how many OTHER configurations happen to match is a property of whatever
    // instance this runs against, and an exact count turns another installation's extra row into
    // a failure of the filter.
    const kept = { timeoutMs: config.navigationTimeoutMs, total, expectRow: DEMO_CONFIG };
    const byDescription = await filterToSubset(page, { ...kept, text: 'demo fixture' });
    assert.ok(byDescription < total, `a description substring narrows the list: ${byDescription} of ${total}`);
    // Measured against the whole list, never against the other leg: the filter is a substring
    // match over every declared field, so the two legs have no ordering between them.
    const byName = await filterToSubset(page, { ...kept, text: 'DemoTLS' });
    assert.ok(byName < total, `and a name substring narrows it too: ${byName} of ${total}`);

    assert.equal(reads.length, 1, `exactly one screen read was issued: ${JSON.stringify(reads)}`);
    assert.equal(new URL(reads[0]).pathname, READ_PATH);
  } finally {
    await context.close();
  }
});

test("AC2: the demo fixture's row is present and its Description cell reads the fixture's sentence", async () => {
  const { context, page } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    await filterToSubset(page, {
      text: DEMO_CONFIG,
      expectRow: DEMO_CONFIG,
      total: await viewCount(page),
      timeoutMs: config.navigationTimeoutMs,
    });
    const demo = await describeRow(page, DEMO_CONFIG);
    assert.ok(demo !== null, `the ${DEMO_CONFIG} row is rendered`);
    assert.equal(demo.cells[1].text, DEMO_DESCRIPTION, "its Description cell is the fixture's own sentence");
    assert.deepEqual(demo.cells[2].disc, { width: 7, kind: 'success', next: STRINGS.tableStatusYes }, 'Enabled shows a 7px success disc and then "Yes"');
  } finally {
    await context.close();
  }
});

test('AC3: the read response carries exactly the four declared fields and no key material', async () => {
  const { context, page, bodies } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    const answered = await Promise.all(bodies);
    const read = answered.find((entry) => new URL(entry.url).pathname === READ_PATH);
    assert.ok(read !== undefined, `the read's response was captured: ${JSON.stringify(answered.map((entry) => entry.url))}`);
    // A body the capture could not read back is the empty string, and every `includes` below
    // passes against it -- so the absence assertions mean nothing until the body is known present.
    assert.ok(read.text.length > 0, 'and its body was read back, not lost to a failed capture');
    for (const name of KEY_MATERIAL) {
      assert.equal(read.text.includes(name), false, `no ${name} reaches the response body`);
    }
    const body = JSON.parse(read.text);
    assert.deepEqual(body.fields, ['Name', 'Description', 'Enabled', 'Type']);
    assert.ok(body.rows.length >= 2, `the response carries the instance's configurations: ${body.rows.length}`);
    for (const row of body.rows) {
      assert.deepEqual(Object.keys(row), ['Name', 'Description', 'Enabled', 'Type'], `row ${row.Name} carries exactly the declared keys`);
    }
  } finally {
    await context.close();
  }
});

test('AC4: the Security and secrets side bar lists SSL/TLS first among its entries, and it is the current one', async () => {
  const { context, page } = await signedInAtList(config.username, config.password);
  try {
    await waitForRows(page, config.navigationTimeoutMs);
    if ((await page.$('app-side-bar nav.ocu-side-bar')) === null) {
      await page.keyboard.down('Control');
      await page.keyboard.press('b');
      await page.keyboard.up('Control');
    }
    await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
    const sideBar = await page.evaluate(() => {
      const nav = document.querySelector('app-side-bar nav.ocu-side-bar');
      const current = nav.querySelector('.ocu-side-bar-item[aria-current="page"] .ocu-side-bar-label');
      return {
        area: nav.querySelector('.ocu-side-bar-eyebrow').textContent.trim(),
        entries: Array.from(nav.querySelectorAll('.ocu-side-bar-item .ocu-side-bar-label')).map((label) => label.textContent.trim()),
        current: current === null ? null : current.textContent.trim(),
      };
    });
    assert.equal(sideBar.area, STRINGS.navAreaSecurity);
    assert.deepEqual(
      sideBar.entries,
      [STRINGS.sslListLabel, STRINGS.x509ListLabel, STRINGS.ldapListLabel, STRINGS.walletListLabel, STRINGS.oauthLabel],
      'SSL/TLS, then X.509, LDAP / Kerberos, Wallet (Story 6.3) and OAuth 2.0 (Story 6.4), and no dead entry beside them'
    );
    assert.equal(sideBar.current, STRINGS.sslListLabel, 'which is the current item');
  } finally {
    await context.close();
  }
});
