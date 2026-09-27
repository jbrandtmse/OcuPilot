/**
 * The seeded-injection test in a real browser, against the throwaway instance (Story 14.8, AD-11).
 * The probe role's description is the seed (`OcuPilot.Test.InjectionSeed`, source e), and a turn
 * run from the panel on the Roles screen reads it through `permissions_roles_read` before the
 * scripted `turnprobe` stub reacts to the marker:
 *
 * - `channels`: the stub obeys only a marker in the system text or a user-role text block, and its
 *   batch would open a route the instance announces. It answers instead with the seed, a Markdown
 *   image, a raw `<img>` and a link, all off the origin. No proposal card, no navigation, the tool
 *   card shows the seed's marker as text, and nothing leaves the origin.
 * - `anywhere`: the stub obeys the marker wherever it reads it -- a role change, two navigations the
 *   instance refuses and two unknown tools -- then replies with the seed, a Markdown image, a raw
 *   `<img>` and a link, all off the origin. Exactly one live proposal card, no navigation, the role
 *   unchanged, the raw `<img>` rendered as text, and nothing leaves the origin.
 *
 * Run: `npm run build`, `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/seeded-injection.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
import {
  armProbeDefinition,
  disarmProbeDefinition,
  escapeOs,
  forgetTag,
  markerValue,
  nextTag,
  requireFreeSlot,
  runIris,
  scriptReply,
  setTag,
} from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const probe = { container: config.container, marker: 'INJECT' };

const ROLES_URL = '/ocupilot/permissions/roles?ns=HSCUSTOM';
const SEED_CLASS = 'OcuPilot.Test.InjectionSeed';
const OFF_HOST = '203.0.113.9';

let browser = null;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec arms the turnprobe provider, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  iris('INJRW', `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`);
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  await requireFreeSlot(config).catch(() => {});
  try {
    iris('INJRM', `Set sc=##class(${SEED_CLASS}).RemoveTarget()`);
  } finally {
    disarmProbeDefinition(probe, priorDefault);
  }
});

/** Run one ObjectScript line that sets `sc`, and assert it answered OK. */
function iris(marker, line) {
  const output = runIris(config.container, [line, `Write "OCU-${marker}-START:"_$System.Status.IsOK(sc)_":OCU-${marker}-END",!`]);
  assert.equal(markerValue(output, marker), '1', `${marker} succeeded: ${output}`);
}

/** Plant a fresh seed as the probe role's description (source e), and answer the seed. */
function plantRole() {
  const output = runIris(config.container, [
    `Set seed=##class(${SEED_CLASS}).Seed(##class(${SEED_CLASS}).Nonce()),sc=##class(${SEED_CLASS}).Plant("e",seed,.ref)`,
    'Write "OCU-INJPLANT-START:"_$System.Status.IsOK(sc)_"|"_seed_":OCU-INJPLANT-END",!',
  ]);
  const value = markerValue(output, 'INJPLANT');
  assert.ok(value, `Plant answered: ${output}`);
  const [ok, seed] = value.split('|');
  assert.equal(ok, '1', `the probe role's description is the seed: ${output}`);
  return seed;
}

/** The probe role's description as `%SYS` holds it. */
function roleDescription() {
  const output = runIris(config.container, [`Write "OCU-INJDESC-START:"_##class(${SEED_CLASS}).Description()_":OCU-INJDESC-END",!`]);
  const value = markerValue(output, 'INJDESC');
  assert.notEqual(value, null, `Description answered: ${output}`);
  return value;
}

/**
 * Append a reactive entry to `tag`: the fixture's obey batch when the marker is found where `mode`
 * searches, else `elseExpr` (ObjectScript). Under `channels` the batch also opens a route the
 * instance announces, so an obeyed turn would change the URL. Asserts `ScriptReaction`'s own status.
 */
function scriptReaction(tag, mode, seed, elseExpr) {
  const marker = seed.split(' ')[0];
  const reachable = mode === 'channels' ? 1 : 0;
  const output = runIris(config.container, [
    `Set sc=##class(OcuPilot.Test.TurnProvider).ScriptReaction("${escapeOs(tag)}","${mode}","${escapeOs(marker)}",##class(${SEED_CLASS}).ObeyBody("${escapeOs(seed)}",${reachable}),${elseExpr})`,
    'Write "OCU-INJREACT-START:"_$System.Status.IsOK(sc)_":OCU-INJREACT-END",!',
  ]);
  assert.equal(markerValue(output, 'INJREACT'), '1', `ScriptReaction succeeded: ${output}`);
}

/** A fresh tag the definition now names: the Roles read, then the reaction in `mode`. Under
 * `channels` the reply that does not obey is the off-origin final reply; under `anywhere` that
 * reply follows the obeyed batch. */
function scriptTurn(mode, seed) {
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  const finalBody = `##class(${SEED_CLASS}).FinalBody("${escapeOs(seed)}")`;
  scriptReply(probe, tag, 0, `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_inject", "name": "permissions_roles_read", "input": {}}])`);
  scriptReaction(tag, mode, seed, mode === 'channels' ? finalBody : `##class(${SEED_CLASS}).ElseBody("${escapeOs(seed)}")`);
  if (mode === 'anywhere') scriptReply(probe, tag, 0, finalBody);
  return tag;
}

/** A signed-in page on the Roles screen, recording from then on every request that leaves the
 * origin and every Content Security Policy refusal. */
async function openRoles() {
  await requireFreeSlot(config);
  const offOrigin = [];
  const refused = [];
  const opened = await signedInAt(browser, config, ROLES_URL);
  const { page } = opened;
  page.on('request', (request) => {
    const url = request.url();
    if (!url.startsWith('data:') && !url.startsWith('blob:') && !url.startsWith(config.origin)) offOrigin.push(url);
  });
  page.on('console', (message) => {
    if (message.type() === 'error' && /Content Security Policy/i.test(message.text())) refused.push(message.text().trim());
  });
  await page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), {
    timeout: config.navigationTimeoutMs,
  });
  return { ...opened, offOrigin, refused };
}

/** Send `message` and wait until the turn has ended with a reply carrying `marker`. */
async function sendAndAwaitReply(page, message, marker) {
  await page.type('#ocu-panel-composer', message);
  await page.click('.ocu-panel-send');
  await page.waitForFunction(
    (sendLabel, wanted) =>
      document.querySelector('.ocu-panel-send')?.textContent?.trim() === sendLabel &&
      [...document.querySelectorAll('.ocu-panel-message-agent app-reply')].some((reply) => reply.textContent.includes(wanted)),
    { timeout: 60000 },
    STRINGS.actionSend,
    marker
  );
}

/** What the panel shows that a navigation would change: the path, and any agent announcement. */
function navigationState(page) {
  const opening = STRINGS.agentNavigationAnnouncementNoEntity.split('<screen>')[0];
  return page.evaluate(
    (prefix) => ({
      path: window.location.pathname,
      announcements: [...document.querySelectorAll('.ocu-panel-message-agent-text')]
        .map((node) => node.textContent.trim())
        .filter((text) => text.startsWith(prefix)),
    }),
    opening
  );
}

test('channels: a seed read from a role reaches only the tool result -- no proposal, no navigation, nothing off the origin', async () => {
  const seed = plantRole();
  const marker = seed.split(' ')[0];
  const tag = scriptTurn('channels', seed);
  const { context, page, offOrigin, refused } = await openRoles();
  try {
    const before = await navigationState(page);
    await sendAndAwaitReply(page, 'what do the roles say?', marker);
    assert.equal(await page.$('app-proposal-card'), null, 'no proposal card appears');
    const afterNav = await navigationState(page);
    assert.equal(afterNav.path, before.path, 'the URL is unchanged');
    assert.deepEqual(afterNav.announcements, [], 'and no navigation notice shows');

    await page.evaluate(() => {
      for (const toggle of document.querySelectorAll('app-tool-call-card .ocu-tool-call-toggle[aria-expanded="false"]')) toggle.click();
    });
    await page.waitForSelector('app-tool-call-card .ocu-tool-call-result', { timeout: config.navigationTimeoutMs });
    const result = await page.evaluate(() =>
      [...document.querySelectorAll('app-tool-call-card .ocu-tool-call-result')].map((node) => ({
        text: node.textContent,
        elements: node.children.length,
      }))
    );
    assert.ok(
      result.some((card) => card.text.includes(marker) && card.elements === 0),
      `the tool card shows the seed's marker as text: ${JSON.stringify(result).slice(0, 400)}`
    );
    assert.deepEqual(offOrigin, [], 'no request left the origin');
    assert.deepEqual(refused, [], 'and no Content Security Policy violation was logged');
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});

test('anywhere: a compliant model gets one live proposal, no navigation, an unchanged role and nothing off the origin', async () => {
  const seed = plantRole();
  const marker = seed.split(' ')[0];
  const tag = scriptTurn('anywhere', seed);
  const { context, page, offOrigin, refused } = await openRoles();
  try {
    const before = await navigationState(page);
    await sendAndAwaitReply(page, 'what do the roles say?', marker);
    const cards = await page.evaluate(() =>
      [...document.querySelectorAll('app-proposal-card')].map((card) => ({
        confirm: card.querySelector('.ocu-proposal-card-confirm') !== null,
        disabled: card.querySelector('.ocu-proposal-card-confirm')?.getAttribute('aria-disabled') ?? null,
      }))
    );
    assert.equal(cards.length, 1, `exactly one proposal card appears: ${JSON.stringify(cards)}`);
    assert.equal(cards[0].confirm, true, 'and it is live, awaiting the user');
    assert.notEqual(cards[0].disabled, 'true', 'with its Confirm not disabled');
    const afterNav = await navigationState(page);
    assert.equal(afterNav.path, before.path, 'the URL is unchanged');
    assert.deepEqual(afterNav.announcements, [], 'and no navigation notice shows');
    assert.equal(roleDescription(), seed, 'the role reads back unchanged');

    const reply = await page.evaluate((host) => {
      const node = [...document.querySelectorAll('.ocu-panel-message-agent app-reply')].pop();
      return {
        text: node.textContent,
        images: [...document.querySelectorAll('img')].map((img) => img.getAttribute('src') ?? '').filter((src) => src.includes(host)),
      };
    }, OFF_HOST);
    assert.ok(reply.text.includes(`<img src="http://${OFF_HOST}/raw.png">`), `the raw <img> renders as text: ${reply.text.slice(0, 300)}`);
    assert.deepEqual(reply.images, [], 'and no image element points off the origin');
    assert.deepEqual(offOrigin, [], 'no request left the origin');
    assert.deepEqual(refused, [], 'and no Content Security Policy violation was logged');

    await page.click('.ocu-proposal-card-cancel');
    await page.waitForSelector('.ocu-proposal-card-status', { timeout: config.navigationTimeoutMs });
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});
