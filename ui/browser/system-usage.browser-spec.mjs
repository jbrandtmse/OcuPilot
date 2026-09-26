/**
 * System usage in a real browser, against the throwaway instance: the declared read, the counters
 * group and the seven meters end to end with live values (AC1), the refresh chip's 5/10/30/60 s
 * cycle (AC1), that the page never gets stuck on a skeleton and a live fill's computed
 * transition-duration and animation-name are `0s` and `none` (AC2 -- the meter's own
 * pending/failed/loaded renderings are `meter.spec.ts`'s, which reads the authored rule rather
 * than a resolved computed style), and the denied deep link for a principal holding
 * `%Admin_Operate:USE` but not `%DB_IRISSYS:READ` (AC5's shape, the same one
 * `OcuPilot.Test.WireSecurityRead.TestTheSystemUsagePairSetIsEnforcedForARealPrincipal` proves over
 * HTTP for its own OPERATEONLYUSER).
 *
 * **It creates a security principal**, so it refuses the live container -- the same discipline
 * `web-applications.browser-spec.mjs` follows. The denied principal holds read on the install
 * namespace's own routine database (so it can sign in and load the shell bundle at all) and
 * `%Admin_Operate:USE`; `after` deletes it and its role whether or not a test failed.
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
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { formatDeniedScreen, formatRequires } = await import(join(uiRoot, 'src', 'app', 'core', 'navigation.ts'));

const config = browserConfig();
const PAGE_PATH = '/ocupilot/os-management/system-usage';
const PAGE_URL = `${PAGE_PATH}?ns=HSCUSTOM`;
const READ_PATH = '/api/ocupilot/screens/osmgmt.systemusage/read';
const DENIED_USER = 'OcuPilotSystemUsageProbe';
const DENIED_ROLE = 'OcuPilotSystemUsageProbeRole';
const DENIED_PASSWORD = 'OcuPilotSystemUsage1';
const DENIED_PAIR = '%DB_IRISSYS:READ';

let browser = null;

/**
 * Run ObjectScript lines in `iris session` inside the throwaway, starting in `%SYS`, and return
 * the value each named marker carries -- the same helper shape `web-applications.browser-spec.mjs`
 * uses.
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
      `Set tSC=##class(Security.Roles).Create("${DENIED_ROLE}","OcuPilot system usage browser spec probe (throwaway)",tRes_":R,%Admin_Operate:U","")`,
      `Set tSC2=##class(Security.Users).Create("${DENIED_USER}","${DENIED_ROLE}","${DENIED_PASSWORD}","OcuPilot system usage browser spec probe (throwaway)","","","",0,1,"")`,
      mark('USER', '$System.Status.IsOK(tSC)&&$System.Status.IsOK(tSC2)'),
      mark('OPERATE', `$SYSTEM.Security.CheckUserPermission("${DENIED_USER}","%Admin_Operate","USE")`),
      mark('IRISSYS', `$SYSTEM.Security.CheckUserPermission("${DENIED_USER}","%DB_IRISSYS","READ")`),
    ],
    ['USER', 'OPERATE', 'IRISSYS']
  );
  assert.equal(values.USER, '1', `the denied principal was created:\n${output}`);
  assert.equal(values.OPERATE, '1', 'and holds %Admin_Operate:USE');
  assert.equal(values.IRISSYS, '0', 'and not %DB_IRISSYS:READ');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  const { values, output } = deletePrincipal();
  assert.equal(values.CLEAN, '1', `the denied principal and its role are gone:\n${output}`);
});

/** A fresh context signed in through the shell's own form at `url`, with its read requests counted. */
async function signedInAt(user, password, url) {
  // Story 15.5: the remembered screen and shell state lives on the instance now, keyed by the
  // one account every spec signs in as, so a fresh context is no longer a fresh slate on its
  // own -- see `preferences-reset.mjs`.
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  const reads = [];
  page.on('request', (request) => {
    if (new URL(request.url()).pathname.startsWith('/api/ocupilot/screens/')) reads.push(request.url());
  });
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', user);
  await page.type('#ocu-signin-password', password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  // The first-login gate takes an administrator to the Definition form on an instance with no
  // enabled definition, whatever URL was asked for (Story 3.6). Back returns to this one.
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  return { context, page, reads };
}

/** Every `.ocu-details-field` on System usage's counters group, keyed by its own label text. */
function counterFields(page) {
  return page.evaluate(() => {
    const out = {};
    for (const field of document.querySelectorAll('.ocu-details-field')) {
      const label = field.querySelector('.ocu-details-field-label')?.textContent?.trim();
      const value = field.querySelector('.ocu-details-field-value')?.textContent?.trim();
      if (label !== undefined) out[label] = value ?? '';
    }
    return out;
  });
}

/** Every `app-meter`, described by its label, value text and word text. */
function meters(page) {
  return page.evaluate(() =>
    Array.from(document.querySelectorAll('app-meter')).map((meter) => ({
      label: meter.querySelector('.ocu-meter-label')?.textContent?.trim() ?? '',
      value: meter.querySelector('.ocu-meter-value')?.textContent?.trim() ?? '',
      word: meter.querySelector('.ocu-meter-word')?.textContent?.trim() ?? null,
    }))
  );
}

test('AC1: System usage reads once and shows live counters, seven meters, and a refresh chip offering 5/10/30/60 s', async () => {
  const { context, page, reads } = await signedInAt(config.username, config.password, PAGE_URL);
  try {
    await page.waitForSelector('.ocu-meter-fill', { timeout: config.navigationTimeoutMs });

    const usageReads = reads.filter((url) => new URL(url).pathname === READ_PATH);
    assert.equal(usageReads.length, 1, `exactly one osmgmt.systemusage read: ${JSON.stringify(reads)}`);

    const counters = await counterFields(page);
    for (const label of [
      STRINGS.processDetailsGlobalReferences,
      STRINGS.systemUsageRoutineCalls,
      STRINGS.systemUsageBlockReads,
      STRINGS.systemUsageBlockWrites,
      STRINGS.systemUsageJournalEntries,
    ]) {
      const text = counters[label];
      assert.ok(text !== undefined, `the ${label} counter is rendered`);
      assert.ok(/^[0-9]+$/.test(text ?? ''), `${label} reads a live number, got ${JSON.stringify(text)}`);
    }

    const meterViews = await meters(page);
    assert.equal(meterViews.length, 7, `seven meters are rendered: ${JSON.stringify(meterViews)}`);

    const sharedMemory = meterViews.find((meter) => meter.label === STRINGS.systemUsageSharedMemory);
    assert.ok(sharedMemory !== undefined, 'the Shared memory meter is rendered');
    assert.ok(/^[0-9]+(\.[0-9])? %$/.test(sharedMemory.value), `Shared memory carries a live percentage, got ${JSON.stringify(sharedMemory.value)}`);
    assert.notEqual(sharedMemory.word, null, 'and its computed Normal/Warning/Troubled word');

    for (const label of [
      STRINGS.systemUsageDatabaseSpace,
      STRINGS.systemUsageJournalSpace,
      STRINGS.systemUsageLockTable,
      STRINGS.systemUsageWriteDaemon,
    ]) {
      const meter = meterViews.find((candidate) => candidate.label === label);
      assert.ok(meter !== undefined, `the ${label} meter is rendered`);
      assert.ok(['Normal', 'Warning', 'Troubled'].includes(meter.word ?? ''), `${label} carries the vendor's own word, got ${JSON.stringify(meter.word)}`);
    }

    // The chip's cycle: off, then each declared rate ascending, then off again.
    const chip = await page.$('.ocu-command-bar-refresh');
    assert.ok(chip !== null, 'the command bar carries the auto-refresh chip, which only a refreshing screen renders');
    assert.equal(await page.$eval('.ocu-command-bar-refresh', (button) => button.textContent.trim()), 'Auto-refresh: off');
    for (const rate of [5, 10, 30, 60]) {
      await chip.click();
      await page.waitForFunction(
        (wanted) => document.querySelector('.ocu-command-bar-refresh').textContent.trim() === wanted,
        { timeout: config.navigationTimeoutMs },
        `Auto-refresh: every ${rate} s`
      );
    }
    await chip.click();
    await page.waitForFunction(() => document.querySelector('.ocu-command-bar-refresh').textContent.trim() === 'Auto-refresh: off', {
      timeout: config.navigationTimeoutMs,
    });
  } finally {
    await context.close();
  }
});

test('AC2: the page never gets stuck on a skeleton once the meters have rendered, and a live fill never transitions or animates', async () => {
  const { context, page } = await signedInAt(config.username, config.password, PAGE_URL);
  try {
    await page.waitForSelector('.ocu-meter-fill', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$('.ocu-data-table-skeleton'), null, 'no skeleton is left showing once the meters have rendered');
    assert.equal(await page.$('[aria-busy="true"]'), null, 'and nothing is marked busy');

    // AC2's own words: "computed transition-duration and animation-name are 0s and none". A real
    // browser is what actually resolves a computed style -- jsdom (`meter.spec.ts`) can only read
    // the authored rule text, never what the cascade resolves to -- so this is the one leg that
    // checks the literal claim rather than the source that is supposed to produce it.
    const fillStyles = await page.$$eval('.ocu-meter-fill', (fills) =>
      fills.map((fill) => {
        const computed = getComputedStyle(fill);
        return { transitionDuration: computed.transitionDuration, animationName: computed.animationName };
      })
    );
    assert.ok(fillStyles.length > 0, 'at least one meter has rendered a colored fill by now');
    for (const style of fillStyles) {
      assert.equal(style.transitionDuration, '0s', `a meter fill's computed transition-duration is 0s, got ${JSON.stringify(style)}`);
      assert.equal(style.animationName, 'none', `a meter fill's computed animation-name is none, got ${JSON.stringify(style)}`);
    }
  } finally {
    await context.close();
  }
});

test('the denied deep link: a principal holding %Admin_Operate:USE but not %DB_IRISSYS:READ sees the denied screen, with no read and no meters', async () => {
  const { context, page, reads } = await signedInAt(DENIED_USER, DENIED_PASSWORD, PAGE_URL);
  try {
    const requires = formatRequires(STRINGS.privilegeRequiresResource, DENIED_PAIR);
    await page.waitForSelector('app-screen-denied .ocu-screen-denied-title', { timeout: config.navigationTimeoutMs });
    const denied = await page.evaluate(() => ({
      title: document.querySelector('app-screen-denied .ocu-screen-denied-title').textContent.trim(),
      reason: document.querySelector('app-screen-denied .ocu-screen-denied-reason').textContent.trim(),
      meters: document.querySelector('app-meter') !== null,
      table: document.querySelector('[role="grid"]') !== null,
    }));
    assert.equal(denied.title, STRINGS.systemUsageLabel, 'the deep link renders the screen title');
    assert.equal(denied.reason, formatDeniedScreen(STRINGS.privilegeDeniedScreen, DENIED_PAIR, STRINGS.systemUsageLabel));
    assert.equal(denied.reason, `You need ${DENIED_PAIR} to open ${STRINGS.systemUsageLabel}.`);
    assert.equal(requires, `Requires ${DENIED_PAIR}`);
    assert.equal(denied.meters, false, 'no meter is rendered');
    assert.equal(denied.table, false, 'and no table either');
    assert.deepEqual(reads, [], 'no screen read was issued');
  } finally {
    await context.close();
  }
});
