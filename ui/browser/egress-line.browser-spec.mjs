/**
 * The data-egress line in a real browser against the throwaway (Story 16.15): a scripted turn on a
 * screen that shares context draws its line beneath the message, from the `egress` the progress poll
 * and the conversation read carry; a real "Set default" on Agent co-pilot > Definitions moves the
 * context chip with no reload and the next turn's line with it, while the earlier turn keeps its
 * own, live and after a reload (DW-1076); sharing off draws the no-context sentence. The line and
 * the Definition form's model-unused note (DW-1192) pass the DW-1337 invariants in both themes.
 *
 * Uses two `turnprobe` definitions of `OcuPilot.Test.TurnWireFixture`: A, armed default at
 * `192.0.2.10`, and B at the private `10.0.0.5`. `after` removes both, restores the default the
 * instance held and the configured user's sharing choice, and hands the turn slot back.
 *
 * Run: `npm run build`, `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/egress-line.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { clickRowCentre, waitForRows } from './list-spec.mjs';
import { authHeader, signedInAt } from './panel-spec.mjs';
import {
  INVARIANTS,
  VIEWPORTS,
  compare,
  componentMinimums,
  detectScreen,
  readBaseline,
  toggleThemeThroughMenu,
} from './structural-walk.mjs';
import {
  armProbeDefinition,
  disarmProbeDefinition,
  ensureLocalDefinition,
  escapeOs,
  markerValue,
  nextTag,
  requireFreeSlot,
  runIris,
  scriptReply,
  setTag,
} from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const probe = { container: config.container, marker: 'EGRESS' };

const USERS_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';
const FORM_URL = '/ocupilot/agent/definitions/edit?ns=HSCUSTOM';
const CONTEXT_PATH = '/api/ocupilot/agent/context';
const PUBLIC_HOST = '192.0.2.10';
const PRIVATE_HOST = '10.0.0.5';
const LOCAL_NAME = 'OcuPilotProbeAgentTurnWireLocal';

let browser = null;
let priorDefault = '';
let idA = '';
let idB = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec arms the turnprobe provider, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  idA = armed.preparedId;
  idB = ensureLocalDefinition(probe, nextTag(probe));
  await putShare(true);
});

after(async () => {
  try {
    try {
      if (config.container === LIVE_CONTAINER) return;
      await requireFreeSlot(config);
    } finally {
      if (config.container !== LIVE_CONTAINER) {
        disarmProbeDefinition(probe, priorDefault);
        await putShare(true);
      }
    }
  } finally {
    if (browser !== null) await browser.close();
  }
});

async function putShare(share) {
  const answer = await fetch(`${config.origin}${CONTEXT_PATH}`, {
    method: 'PUT',
    headers: { Authorization: authHeader(config), 'Content-Type': 'application/json' },
    body: JSON.stringify({ share }),
  });
  assert.ok(answer.ok, `PUT /agent/context {share:${share}} (HTTP ${answer.status})`);
}

/** Move the default marker to definition `id` on the instance. */
function markDefault(id) {
  const output = runIris(config.container, [
    `Set sc=##class(OcuPilot.Test.TurnWireFixture).MarkDefault("${escapeOs(id)}")`,
    `Write "OCU-EGRESS-MARK-START:"_$System.Status.IsOK(sc)_":OCU-EGRESS-MARK-END",!`,
  ]);
  assert.equal(markerValue(output, 'EGRESS-MARK'), '1', `MarkDefault succeeded: ${output}`);
}

/** Point definition `id` at a fresh tag scripted to answer one text reply. */
function scripted(id) {
  const tag = nextTag(probe);
  setTag(probe, id, tag);
  scriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs('ok')}")`);
}

/** A fresh context signed in on `url`, the composer usable and the chip answered. */
async function signedInReady(url) {
  const { context, page } = await signedInAt(browser, config, url);
  await page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), {
    timeout: config.navigationTimeoutMs,
  });
  await page.waitForSelector('.ocu-context-chip', { timeout: config.navigationTimeoutMs });
  return { context, page };
}

function fill(template, host) {
  return template.split('<provider>').join('turnprobe').split('<host>').join(host);
}

/** The chip as drawn: its text and whether the egress pill is present. */
function chipState(page) {
  return page.evaluate(() => ({
    text: document.querySelector('.ocu-context-chip-text')?.textContent ?? '',
    pill: document.querySelector('.ocu-context-chip-pill') !== null,
  }));
}

/** Every egress line in the transcript, in order: its text and whether it carries the leaves modifier. */
function lines(page) {
  return page.evaluate(() =>
    [...document.querySelectorAll('.ocu-panel-transcript .ocu-panel-turn')].map((turn) => {
      const line = turn.querySelector('.ocu-panel-message-user + .ocu-panel-egress-line');
      return line === null ? null : { text: line.textContent.trim(), leaves: line.classList.contains('ocu-panel-egress-line-leaves') };
    })
  );
}

/** Send `text` and wait until the transcript holds `count` turns, the last one finished with a line. */
async function sendAndAwaitLine(page, text, count) {
  await page.type('#ocu-panel-composer', text);
  await page.click('.ocu-panel-send');
  try {
    await page.waitForFunction(
      (wanted, send) => {
        const turns = document.querySelectorAll('.ocu-panel-transcript .ocu-panel-turn');
        return (
          turns.length === wanted &&
          turns[wanted - 1].querySelector('.ocu-panel-egress-line') !== null &&
          document.querySelector('.ocu-panel-send')?.textContent?.trim() === send
        );
      },
      { timeout: config.navigationTimeoutMs },
      count,
      STRINGS.actionSend
    );
  } catch (cause) {
    throw new Error(`expected turn ${count} to finish with an egress line; the transcript reads ${JSON.stringify(await lines(page))} (${cause.message})`);
  }
}

/** Two rendered frames, so a resize or a theme flip has landed before anything is measured. */
function frames(page) {
  return page.evaluate(() => new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

/** Every DW-1337 invariant over `route` as it stands, in light at both widths and dark at 1280, outside the baseline. */
async function freshViolations(page, route) {
  const minimums = componentMinimums();
  const baseline = (readBaseline()?.entries ?? []).filter((entry) => entry.route === route);
  const requests = { inflight: new Set(), last: 0 };
  const found = [];
  for (const { viewport, theme } of [
    { viewport: VIEWPORTS.wide, theme: 'light' },
    { viewport: VIEWPORTS.narrow, theme: 'light' },
    { viewport: VIEWPORTS.wide, theme: 'dark' },
  ]) {
    await page.setViewport(viewport);
    if (theme === 'dark') await toggleThemeThroughMenu(page, requests, config.navigationTimeoutMs);
    try {
      await frames(page);
      const { entries } = await detectScreen(page, { route, checks: INVARIANTS, viewport: viewport.width, theme, minimums });
      found.push(...entries);
    } finally {
      if (theme === 'dark') await toggleThemeThroughMenu(page, requests, config.navigationTimeoutMs);
    }
  }
  await page.setViewport(VIEWPORTS.wide);
  return compare(found, baseline).fresh.map((entry) => `${entry.key}: ${entry.measured}`);
}

/** Click a rail item, then the side-bar entry `label` it reveals, pressing again until the URL reaches `expectedPath`. */
async function navigateViaSideBar(page, railItemId, label, expectedPath) {
  await page.click(railItemId);
  await page.waitForFunction(
    (wanted) => [...document.querySelectorAll('.ocu-side-bar-item')].some((el) => el.textContent.includes(wanted)),
    { timeout: config.navigationTimeoutMs },
    label
  );
  const index = await page.evaluate(
    (wanted) => [...document.querySelectorAll('.ocu-side-bar-item')].findIndex((el) => el.textContent.includes(wanted)),
    label
  );
  const entry = `.ocu-side-bar-item:nth-of-type(${index + 1})`;
  const deadline = Date.now() + config.navigationTimeoutMs;
  while (Date.now() < deadline) {
    if ((await page.evaluate(() => window.location.pathname)) === expectedPath) return;
    await page.click(entry).catch(() => {});
    try {
      await page.waitForFunction((path) => window.location.pathname === path, { timeout: 2000 }, expectedPath);
      return;
    } catch {
      // Absorbed by a router mid-settle; press again until the bound.
    }
  }
  throw new Error(`pressing "${label}" never reached ${expectedPath}; the URL stayed at ${await page.evaluate(() => window.location.pathname)}`);
}

/** Press the command bar's action `label` once it is offered and released. */
async function pressBar(page, label) {
  try {
    await page.waitForFunction(
      (wanted) => {
        const button = [...document.querySelectorAll('.ocu-command-bar-action')].find((candidate) => candidate.textContent.trim() === wanted);
        return button !== undefined && !button.disabled && button.getAttribute('aria-disabled') !== 'true';
      },
      { timeout: config.navigationTimeoutMs },
      label
    );
  } catch (cause) {
    const bar = await page.evaluate(() =>
      [...document.querySelectorAll('.ocu-command-bar-action')].map((button) => `${button.textContent.trim()}:${button.getAttribute('aria-disabled')}`)
    );
    const selected = await page.evaluate(() =>
      [...document.querySelectorAll('[role="grid"] [role="row"][aria-selected="true"]')].map((row) => row.textContent.trim().slice(0, 60))
    );
    throw new Error(`expected "${label}" on the command bar, released; the bar holds ${JSON.stringify(bar)} with ${JSON.stringify(selected)} selected (${cause.message})`);
  }
  await page.evaluate((wanted) => {
    [...document.querySelectorAll('.ocu-command-bar-action')].find((button) => button.textContent.trim() === wanted).click();
  }, label);
}

test('Leg 1: a turn on a sharing screen draws the left line beneath its message, and the panel passes every invariant', async () => {
  markDefault(idA);
  scripted(idA);
  const { context, page } = await signedInReady(USERS_URL);
  try {
    await page.waitForFunction((host) => (document.querySelector('.ocu-context-chip-text')?.textContent ?? '').includes(host), { timeout: config.navigationTimeoutMs }, PUBLIC_HOST);
    const chip = await chipState(page);
    assert.match(chip.text, /\u00b7 turnprobe \u00b7 192\.0\.2\.10/);
    assert.equal(chip.pill, true, 'the chip draws the leaves pill for A');

    await sendAndAwaitLine(page, 'where does this go', 1);
    assert.deepEqual(await lines(page), [{ text: fill(STRINGS.egressLineLeft, PUBLIC_HOST), leaves: true }]);
    assert.deepEqual(await freshViolations(page, 'permissions/users'), [], 'the egress line adds no structural violation in either theme');
  } finally {
    await context.close();
  }
});

test('Leg 2: Set default moves the chip with no reload and the next line with it; the earlier line stays, live and after a reload', async () => {
  markDefault(idA);
  scripted(idA);
  scripted(idB);
  const { context, page } = await signedInReady(USERS_URL);
  try {
    await page.waitForFunction((host) => (document.querySelector('.ocu-context-chip-text')?.textContent ?? '').includes(host), { timeout: config.navigationTimeoutMs }, PUBLIC_HOST);
    await sendAndAwaitLine(page, 'turn one', 1);
    const first = { text: fill(STRINGS.egressLineLeft, PUBLIC_HOST), leaves: true };
    assert.deepEqual(await lines(page), [first]);

    await navigateViaSideBar(page, '#ocu-rail-item-agent', STRINGS.agentDefinitionListLabel, '/ocupilot/agent/definitions');
    await waitForRows(page, config.navigationTimeoutMs);
    await clickRowCentre(page, { text: LOCAL_NAME, cell: 3 });
    await pressBar(page, STRINGS.agentDefinitionSetDefault);
    try {
      await page.waitForFunction(
        (host) => (document.querySelector('.ocu-context-chip-text')?.textContent ?? '').includes(host) && document.querySelector('.ocu-context-chip-pill') === null,
        { timeout: config.navigationTimeoutMs },
        PRIVATE_HOST
      );
    } catch (cause) {
      throw new Error(`expected the chip to name ${PRIVATE_HOST} with no pill after Set default; it reads ${JSON.stringify(await chipState(page))} (${cause.message})`);
    }

    await sendAndAwaitLine(page, 'turn two', 2);
    const second = { text: fill(STRINGS.egressLineStayed, PRIVATE_HOST), leaves: false };
    assert.deepEqual(await lines(page), [first, second], 'turn two names B; turn one keeps A');

    await page.reload({ waitUntil: 'networkidle2' });
    await page.waitForFunction(() => document.querySelectorAll('.ocu-panel-transcript .ocu-panel-egress-line').length === 2, {
      timeout: config.navigationTimeoutMs,
    });
    assert.deepEqual(await lines(page), [first, second], 'and both lines are restored with the conversation');
  } finally {
    await context.close();
    markDefault(idA);
  }
});

test('Leg 3: with sharing off a turn draws the no-context line, naming the provider', async () => {
  markDefault(idA);
  scripted(idA);
  await putShare(false);
  const { context, page } = await signedInReady(USERS_URL);
  try {
    await page.waitForFunction((off) => (document.querySelector('.ocu-context-chip-text')?.textContent ?? '').trim() === off, { timeout: config.navigationTimeoutMs }, STRINGS.contextChipSharingOff);
    await sendAndAwaitLine(page, 'nothing from here', 1);
    assert.deepEqual(await lines(page), [{ text: fill(STRINGS.egressLineNone, PUBLIC_HOST), leaves: false }]);
  } finally {
    await context.close();
    await putShare(true);
  }
});

test('DW-1192: the Definition form notes an unused Model under Endpoint, and passes every invariant in both themes', async () => {
  const { context, page } = await signedInAt(browser, config, FORM_URL);
  try {
    await page.waitForSelector('#ocu-definition-provider', { visible: true, timeout: config.navigationTimeoutMs });
    await page.select('#ocu-definition-provider', 'gemini');
    await page.waitForFunction(() => document.querySelector('#ocu-definition-endpointUrl').value.includes('{model}'), { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$('#ocu-definition-endpointUrl-caption'), null, 'the canonical endpoint uses the Model');
    await page.$eval('#ocu-definition-endpointUrl', (input) => {
      input.value = input.value.replace('{model}', 'pinned');
      input.dispatchEvent(new Event('input', { bubbles: true }));
    });
    await page.waitForSelector('#ocu-definition-endpointUrl-caption', { timeout: config.navigationTimeoutMs });
    assert.equal(await page.$eval('#ocu-definition-endpointUrl-caption', (note) => note.textContent.trim()), STRINGS.agentDefinitionModelUnused);
    assert.equal(await page.$eval('#ocu-definition-endpointUrl', (input) => input.getAttribute('aria-describedby')), 'ocu-definition-endpointUrl-caption');
    assert.deepEqual(await freshViolations(page, 'agent/definitions/edit'), [], 'the note adds no structural violation in either theme');
  } finally {
    await context.close();
  }
});
