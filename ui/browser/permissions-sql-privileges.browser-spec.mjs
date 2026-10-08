/**
 * The SQL privileges tab of the user and role editors in a real browser, against the throwaway instance
 * (Story 18.9).
 *
 * What it pins, each on rendered DOM:
 *
 * 1. **Grant and revoke on an account**: the user editor's SQL privileges tab, in namespace USER, grants SELECT on
 *    the probe table through "Grant or revoke...", lists the `Direct` row, and the row's Revoke removes it.
 * 2. **A privilege held through a schema is not revoked here**: the probe role holds SELECT on the probe schema, its
 *    table rows read `Schema Privilege`, and they carry the hint and no Revoke button.
 *
 * **It refuses the live and development containers.** It touches only the principals, schema and objects named
 * `OcuSqlPrivProbe...`: `before` and `after` remove them by exact name with `OcuPilot.Test.SqlPrivilegeProbe.RemoveAll`.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test --test-concurrency=1
 * browser/permissions-sql-privileges.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, browserConfig, launchOptions } from '../browser.config.mjs';
import { signedInAt } from './panel-spec.mjs';
import { VIEWPORTS, assertThrowaway } from './structural-walk.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const PROBE = 'OcuPilot.Test.SqlPrivilegeProbe';
const USER = 'OcuSqlPrivProbeU';
const ROLE = 'OcuSqlPrivProbeR';
const TABLE = 'OcuSqlPrivProbe.T1';
const NAMESPACE = 'USER';
const ROW = '[data-ocu-sqlpriv="row"]';

let browser = null;

const mark = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

/** Run `lines` in `HSCUSTOM` inside the throwaway and return the value each named marker carries. */
function iris(lines, names = []) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM'], {
    input: `${[...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const values = {};
  for (const name of names) {
    const hit = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output);
    values[name] = hit === null ? null : hit[1].trim();
  }
  return { values, output };
}

/** Remove every probe principal, schema object and privilege, by exact name. */
function removeProbes() {
  iris([`Do ##class(${PROBE}).RemoveAll()`]);
}

/** Make the probe principals and objects. */
function seed() {
  const { values, output } = iris([mark('SEED', `$System.Status.IsOK(##class(${PROBE}).Seed())`)], ['SEED']);
  assert.equal(values.SEED, '1', `the probe is seeded:\n${output}`);
}

/** How many probe leftovers the instance still holds. */
function remaining() {
  const { values, output } = iris([mark('LEFT', `##class(${PROBE}).Remaining()`)], ['LEFT']);
  assert.ok(values.LEFT !== null, `the instance is read:\n${output}`);
  return values.LEFT;
}

/** Open `kind`'s (`users` or `roles`) editor on `name` and select the SQL privileges tab in `NAMESPACE`. */
async function openTab(kind, name) {
  const { context, page } = await signedInAt(browser, config, `/ocupilot/permissions/${kind}/edit/${encodeURIComponent(name)}?ns=HSCUSTOM`, VIEWPORTS.wide);
  await (await page.waitForSelector('button[data-tab="sql-privileges"]', { visible: true, timeout: config.navigationTimeoutMs })).click();
  await page.waitForSelector('#ocu-sqlpriv-namespace', { visible: true, timeout: config.navigationTimeoutMs });
  await page.select('#ocu-sqlpriv-namespace', NAMESPACE);
  return { context, page };
}

/** The tab's rows as their cell texts. */
function rows(page) {
  return page.$$eval(ROW, (trs) => trs.map((tr) => Array.from(tr.querySelectorAll('td')).map((td) => td.textContent.trim())));
}

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec sends grants, so it never runs inside the live container');
  assert.ok(!/^ocupilot-slot-/.test(config.container), 'nor inside a development instance');
  await assertThrowaway(config);
  removeProbes();
  seed();
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    if (browser !== null) await browser.close();
  } finally {
    if (config.container !== LIVE_CONTAINER) {
      removeProbes();
      iris([`Do $SYSTEM.SQL.Statement.Clean("${NAMESPACE}")`, 'Do $SYSTEM.Monitor.Clear()']);
      assert.equal(remaining(), '0', 'no probe principal, schema, table or privilege is left');
    }
  }
});

// Mutation (Rule 19): drop the Direct-row Revoke from the tab's template, rebuild and redeploy -> the
// Revoke wait goes red.
test('an account is granted SELECT on a probe table from the dialog, lists it as Direct, and Revoke removes it', async () => {
  const { context, page } = await openTab('users', USER);
  try {
    await page.waitForSelector('#ocu-sqlpriv-open', { visible: true, timeout: config.navigationTimeoutMs });
    await page.click('#ocu-sqlpriv-open');
    await page.waitForSelector('#ocu-sqlpriv-object', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('#ocu-sqlpriv-object', TABLE);
    await page.click('#ocu-sqlpriv-submit');
    await page.waitForFunction((selector, text) => Array.from(document.querySelectorAll(selector)).some((row) => row.textContent.includes(text)), { timeout: config.navigationTimeoutMs }, ROW, TABLE);
    const held = await rows(page);
    const mine = held.filter((cells) => cells[0] === TABLE);
    assert.equal(mine.length, 1, `the granted privilege is listed once among ${JSON.stringify(held)}`);
    assert.deepEqual([mine[0][1], mine[0][2], mine[0][5]], ['TABLE', 'SELECT', 'Direct']);
    assert.equal(await page.$('[role="dialog"]'), null, 'the dialog closed');

    await page.evaluate((selector, table) => {
      const row = Array.from(document.querySelectorAll(selector)).find((tr) => tr.querySelector('td').textContent.trim() === table);
      row.querySelector('button[data-action="revoke-sql"]').click();
    }, ROW, TABLE);
    await page.waitForFunction((selector, table) => !Array.from(document.querySelectorAll(selector)).some((tr) => tr.querySelector('td').textContent.trim() === table), { timeout: config.navigationTimeoutMs }, ROW, TABLE);
  } finally {
    await context.close();
  }
});

// Mutation (Rule 19): draw Revoke on every row -> the no-button assertion goes red.
test('the schema privileges of a role carry the hint and no Revoke button', async () => {
  iris([mark('GRANT', `$System.Status.IsOK(##class(${PROBE}).Grant("${ROLE}","SCHEMA","OcuSqlPrivProbe","SELECT"))`)]);
  const { context, page } = await openTab('roles', ROLE);
  try {
    await page.waitForSelector(ROW, { visible: true, timeout: config.navigationTimeoutMs });
    const schemaRows = await page.$$eval(ROW, (trs) =>
      trs
        .filter((tr) => tr.textContent.includes('Schema Privilege'))
        .map((tr) => ({ revoke: tr.querySelector('button') !== null, hint: tr.querySelector('[data-ocu-sqlpriv="hint"]')?.textContent.trim() ?? '' }))
    );
    assert.ok(schemaRows.length >= 2, 'the schema grant shows on the probe tables');
    for (const row of schemaRows) {
      assert.equal(row.revoke, false, 'a schema-held privilege has no Revoke');
      assert.equal(row.hint, STRINGS.sqlPrivilegeViaSchema);
    }
  } finally {
    await context.close();
  }
});
