/**
 * Story 20.1 in a real browser, against the throwaway: the Interoperability and Analytics rail
 * items and Home tiles appear only in a namespace that reports the feature (AD-44), and a category
 * that applies but that the caller cannot open stays drawn, unavailable, naming its pair (AD-8).
 *
 * Each namespace's features are read from the instance (`namespace-features.mjs`), never assumed by
 * name: `%SYS` reports neither feature, one namespace reports interoperability alone, and another
 * reports both. The pre-answer state holds `/api/ocupilot/navigation` through request
 * interception. The least-privileged principal comes from `OcuPilot.Test.DeveloperFloorFixture`
 * (`%Developer`, which lacks `%Ens_Portal`) and is removed afterwards, so the spec refuses the live
 * container. It never reads `.ocu-side-bar-label`.
 *
 * Run: `npm run build`, redeploy the bundle, then
 * `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/namespace-categories.browser-spec.mjs`
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { parseMarkers } from './iris-session.mjs';
import { areaApplies, namespacesWith, readNamespaceFeatures } from './namespace-features.mjs';
import { resetRememberedState } from './preferences-reset.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { AREAS } = await import(join(uiRoot, 'src', 'app', 'core', 'screens.generated.ts'));
const { stringFor } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));

const config = browserConfig();
const WIDE = { width: 1280, height: 900 };
const NAVIGATION_PATH = '/api/ocupilot/navigation';
const CATEGORIES = AREAS.filter((area) => area.appliesWhen !== undefined).map((area) => area.key);
const PORTAL_PAIR = '%Ens_Portal:USE';

const password = `OcuPilotCategories${randomBytes(12).toString('hex')}Aa9`;
let developer = '';
let browser = null;
let reported = {};
let noneNs = '';
let interopNs = '';
let bothCandidates = [];
let bothNs = '';

/** Run ObjectScript lines in the throwaway and answer the named markers. */
function irisSession(lines, names) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input: `${['Set $NAMESPACE=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")', ...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  return { values: parseMarkers(output, names), output };
}

const marker = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates a principal, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);

  reported = readNamespaceFeatures(config.container);
  [noneNs] = namespacesWith(reported, { interoperability: false, analytics: false });
  [interopNs] = namespacesWith(reported, { interoperability: true, analytics: false });
  bothCandidates = namespacesWith(reported, { interoperability: true, analytics: true });
  [bothNs] = bothCandidates;
  assert.equal(noneNs, '%SYS', `%SYS reports neither feature: ${JSON.stringify(reported)}`);
  assert.ok(interopNs !== undefined && bothNs !== undefined, `the instance has an interoperability-only and a both-features namespace: ${JSON.stringify(reported)}`);

  const created = irisSession(
    [
      `Set tSC=##class(OcuPilot.Test.DeveloperFloorFixture).EnsurePrincipal("${password}","",.tUser)`,
      marker('USER', '$Get(tUser)'),
      marker('OK', '$System.Status.IsOK(tSC)'),
    ],
    ['USER', 'OK']
  );
  assert.equal(created.values.OK, '1', `the fixture created the principal: ${created.output}`);
  developer = created.values.USER;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  const removed = irisSession([marker('LEFT', '##class(OcuPilot.Test.DeveloperFloorFixture).RemovePrincipals()')], ['LEFT']);
  assert.equal(removed.values.LEFT, '', `the principal and its role are gone: ${removed.output}`);
});

const homeUrl = (namespace) => `/ocupilot/?ns=${encodeURIComponent(namespace)}`;

/** A fresh context signed in as `user` and standing on `url`; `holdNavigation` holds every map read until `release()`. */
async function signIn(user, secret, url, { holdNavigation = false } = {}) {
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.setViewport(WIDE);
  const held = [];
  const gate = { open: !holdNavigation };
  if (holdNavigation) {
    await page.setRequestInterception(true);
    page.on('request', (request) => {
      if (request.isInterceptResolutionHandled()) return;
      if (!gate.open && new URL(request.url()).pathname === NAVIGATION_PATH) held.push(request);
      else request.continue();
    });
  }
  await page.goto(`${config.origin}${url}`, { waitUntil: holdNavigation ? 'domcontentloaded' : 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', user);
  await page.type('#ocu-signin-password', secret);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
  const release = async () => {
    gate.open = true;
    for (const request of held.splice(0)) await request.continue();
  };
  return { context, page, held, release };
}

/** The area keys of the rail, in order, and the names of Home's tiles. */
function drawn(page) {
  return page.evaluate(() => ({
    rail: [...document.querySelectorAll('.ocu-rail-item')].map((item) => item.id.replace('ocu-rail-item-', '')),
    tiles: [...document.querySelectorAll('.ocu-area-tile-name')].map((name) => name.textContent.trim()),
  }));
}

/** What the rail and Home draw in a namespace that reports `features`: every area that applies. */
function expectedFor(features) {
  const applying = AREAS.filter((area) => areaApplies(area, features)).sort((a, b) => a.railPosition - b.railPosition);
  return {
    rail: applying.map((area) => area.key),
    tiles: applying.filter((area) => !area.navigates && !area.pinBottom).map((area) => stringFor(area.labelKey)),
  };
}

/** Choose `namespace` in the header's switch and wait for the route to carry it. */
async function switchTo(page, namespace) {
  await page.click('.ocu-namespace-switch-trigger');
  await page.waitForSelector('.ocu-namespace-switch-option', { timeout: config.navigationTimeoutMs });
  const chose = await page.evaluate((wanted) => {
    const option = [...document.querySelectorAll('.ocu-namespace-switch-option')].find((node) => node.textContent.trim() === wanted);
    option?.click();
    return option !== undefined;
  }, namespace);
  assert.equal(chose, true, `the namespace switch offers ${namespace}`);
  await page.waitForFunction((wanted) => new URL(window.location.href).searchParams.get('ns') === wanted, { timeout: config.navigationTimeoutMs }, namespace);
}

/** The namespaces the header's switch offers, read by opening it and closing it again. */
async function offered(page) {
  await page.click('.ocu-namespace-switch-trigger');
  await page.waitForSelector('.ocu-namespace-switch-option', { timeout: config.navigationTimeoutMs });
  const names = await page.$$eval('.ocu-namespace-switch-option', (nodes) => nodes.map((node) => node.textContent.trim()));
  await page.keyboard.press('Escape');
  await page.waitForFunction(() => document.querySelector('.ocu-namespace-switch-list') === null, { timeout: config.navigationTimeoutMs });
  return names;
}

/** Wait until the rail draws exactly `keys`, so a read still in flight cannot be mistaken for the answer. */
async function railBecomes(page, keys) {
  await page.waitForFunction(
    (wanted) => JSON.stringify([...document.querySelectorAll('.ocu-rail-item')].map((item) => item.id.replace('ocu-rail-item-', ''))) === JSON.stringify(wanted),
    { timeout: config.navigationTimeoutMs },
    keys
  );
}

test('the rail and Home draw a category only in a namespace that reports its feature: %SYS, an interoperability-only namespace, and one reporting both', async () => {
  // Mutation (Rule 19): make `NamespaceFeatures.Reports` answer 1 always -> the %SYS rail draws both
  // categories and this goes red. Make `NavigationService.applies()` treat a missing answer as true
  // -> the pre-answer test goes red.
  const { context, page } = await signIn(config.username, config.password, homeUrl(noneNs));
  try {
    await leaveFirstLoginGate(page, config.navigationTimeoutMs, homeUrl(noneNs));
    const offeredNames = await offered(page);
    const both = bothCandidates.find((name) => offeredNames.includes(name));
    assert.ok(both !== undefined, `the switch offers a namespace that reports both features: ${JSON.stringify(offeredNames)} against ${JSON.stringify(bothCandidates)}`);
    for (const namespace of [noneNs, interopNs, both]) {
      if (new URL(page.url()).searchParams.get('ns') !== namespace) await switchTo(page, namespace);
      const want = expectedFor(reported[namespace]);
      await railBecomes(page, want.rail);
      const seen = await drawn(page);
      assert.deepEqual(seen.rail, want.rail, `${namespace}: the rail draws the areas that apply`);
      assert.deepEqual(seen.tiles, want.tiles, `${namespace}: Home draws one tile per area that applies`);
      for (const key of CATEGORIES) {
        const feature = AREAS.find((area) => area.key === key).appliesWhen;
        assert.equal(seen.rail.includes(key), reported[namespace][feature], `${namespace}: ${key} is drawn exactly when the namespace reports ${feature}`);
      }
    }
  } finally {
    await context.close();
  }
});

test('before the map answers, neither category is drawn while the other areas are', async () => {
  const { context, page, held, release } = await signIn(config.username, config.password, homeUrl(interopNs), { holdNavigation: true });
  try {
    await page.waitForFunction(() => document.querySelector('#ocu-rail-item-logs') !== null, { timeout: config.navigationTimeoutMs });
    const unanswered = await drawn(page);
    assert.ok(unanswered.rail.includes('logs'), 'Logs is drawn, ungated, as before the map answers');
    for (const key of CATEGORIES) assert.equal(unanswered.rail.includes(key), false, `${key} is not drawn while the map read is held`);
    assert.ok(held.length > 0, 'the navigation read is the one being held');

    await release();
    await railBecomes(page, expectedFor(reported[interopNs]).rail);
    assert.equal((await drawn(page)).rail.includes('interoperability'), true, 'and the category appears once the map has answered');
  } finally {
    await context.close();
  }
});

test('opening the Interoperability side bar and then switching to %SYS removes the rail item and the bar, and switching back restores the item', async () => {
  // Mutation (Rule 19): make `side-bar.ts` ignore membership in `areas()` -> the bar stays after the switch.
  const { context, page } = await signIn(config.username, config.password, homeUrl(interopNs));
  try {
    await leaveFirstLoginGate(page, config.navigationTimeoutMs, homeUrl(interopNs));
    await railBecomes(page, expectedFor(reported[interopNs]).rail);
    await page.click('#ocu-rail-item-interoperability');
    await page.waitForSelector('app-side-bar nav', { timeout: config.navigationTimeoutMs });

    await switchTo(page, noneNs);
    await railBecomes(page, expectedFor(reported[noneNs]).rail);
    assert.equal(await page.$('#ocu-rail-item-interoperability'), null, 'the rail item is gone');
    await page.waitForFunction(() => document.querySelector('app-side-bar nav') === null, { timeout: config.navigationTimeoutMs });

    await switchTo(page, interopNs);
    await railBecomes(page, expectedFor(reported[interopNs]).rail);
    assert.notEqual(await page.$('#ocu-rail-item-interoperability'), null, 'switching back restores the rail item');
  } finally {
    await context.close();
  }
});

test('a %Developer principal sees Interoperability drawn, unavailable, naming %Ens_Portal:USE, in a namespace that reports it', async () => {
  // Mutation (Rule 19): make `areas()` filter by `areaVerdict().allowed` instead of `applies()` -> the
  // item is not drawn for this principal and the first assertion goes red.
  const { context, page } = await signIn(developer, password, homeUrl(interopNs));
  try {
    await leaveFirstLoginGate(page, config.navigationTimeoutMs, homeUrl(interopNs));
    await page.waitForSelector('#ocu-rail-item-interoperability', { timeout: config.navigationTimeoutMs });
    const seen = await page.evaluate(() => {
      const item = document.querySelector('#ocu-rail-item-interoperability');
      return {
        disabled: item.getAttribute('aria-disabled'),
        tip: document.querySelector('#ocu-rail-tip-interoperability')?.textContent.trim() ?? null,
        analytics: document.querySelector('#ocu-rail-item-analytics') !== null,
      };
    });
    assert.equal(seen.disabled, 'true', 'Interoperability is drawn aria-disabled');
    assert.equal(seen.tip, `Requires ${PORTAL_PAIR}`, 'naming its pair');
    assert.equal(seen.analytics, false, 'while Analytics, which this namespace does not report, is not drawn');
  } finally {
    await context.close();
  }
});
