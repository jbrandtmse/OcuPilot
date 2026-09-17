/**
 * The context chip, its toggle and the paste warning, in a real browser against the throwaway
 * instance (Story 4.11): chip text on the Users list, the egress pill and its tooltip, the key
 * glyph on the Definition form, the toggle surviving a reload, the paste warning's two buttons,
 * and the Integration AC -- a sent turn's recorded provider messages carry the synthetic
 * `screen_context` pair naming the route, the namespace and exactly the rows the chip displayed.
 *
 * Uses the same `turnprobe` wire fixture `turn.browser-spec.mjs` drives
 * (`OcuPilot.Test.TurnWireFixture`): one definition, enabled and marked default, backed by
 * `OcuPilot.Test.TurnProvider`, which records every request it receives and can be read back
 * with `Recorded(tag, call, field)` -- the one way to observe what actually reached the provider
 * without trusting the client's own account of it.
 *
 * The per-user sharing choice (`GET/PUT /agent/context`) is server state keyed by the signed-in
 * user, not by browser context, so every test that changes it restores `share: true` before it
 * ends -- the default every other test in this file, and every other browser spec, assumes.
 *
 * Run: `npm run build` then `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/context-chip.browser-spec.mjs`
 * (`.claude/rules/objectscript-testing.md`'s "a browser spec runs against the deployed bundle").
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const USERS_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';
const FORM_URL = '/ocupilot/agent/definitions/edit?ns=HSCUSTOM';
const CONTEXT_PATH = '/api/ocupilot/agent/context';
const TAG_PREFIX = 'chipbrowser';

let browser = null;
let tagCounter = 0;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec arms the turnprobe provider, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
  runIris(['Do ##class(OcuPilot.Test.TurnWireFixture).RemoveDefinition("")']);
  priorDefault = runIris(['Write ##class(OcuPilot.Test.TurnWireFixture).MarkedDefault()']).trim();
  preparedId = ensureDefinition(nextTag());
  await putShare(true);
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  await putShare(true);
  runIris([`Do ##class(OcuPilot.Test.TurnWireFixture).RemoveDefinition("${escapeOs(priorDefault)}")`]);
});

function nextTag() {
  tagCounter += 1;
  return `${TAG_PREFIX}${tagCounter}`;
}

function escapeOs(value) {
  return String(value).replace(/"/g, '""');
}

function runIris(lines) {
  const script = [
    'Set $NAMESPACE=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")',
    ...lines,
    'Halt',
  ].join('\n');
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input: `${script}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  return `${result.stdout ?? ''}${result.stderr ?? ''}`;
}

function markerValue(output, marker) {
  const re = new RegExp(`${marker}-START:(.*?):${marker}-END`);
  return re.exec(output)?.[1] ?? null;
}

function ensureDefinition(tag) {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.TurnWireFixture).EnsureDefinition("${escapeOs(tag)}",.id)`,
    'Write "OCUCHIP-DEF-START:"_$System.Status.IsOK(sc)_"|"_id_":OCUCHIP-DEF-END",!',
  ]);
  const value = markerValue(output, 'OCUCHIP-DEF');
  assert.ok(value, `EnsureDefinition answered: ${output}`);
  const [ok, id] = value.split('|');
  assert.equal(ok, '1', `EnsureDefinition succeeded: ${output}`);
  return id;
}

function setTag(tag) {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.TurnWireFixture).SetTag("${escapeOs(preparedId)}","${escapeOs(tag)}")`,
    'Write "OCUCHIP-TAG-START:"_$System.Status.IsOK(sc)_":OCUCHIP-TAG-END",!',
  ]);
  assert.equal(markerValue(output, 'OCUCHIP-TAG'), '1', `SetTag succeeded: ${output}`);
}

function scriptReply(tag, hangSeconds, bodyExpr) {
  const output = runIris([
    `Do ##class(OcuPilot.Test.TurnProvider).Script("${escapeOs(tag)}",${hangSeconds},${bodyExpr})`,
    'Write "OCUCHIP-SCRIPT-START:ok:OCUCHIP-SCRIPT-END",!',
  ]);
  assert.ok(markerValue(output, 'OCUCHIP-SCRIPT'), `Script recorded: ${output}`);
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

function forgetTag(tag) {
  runIris([`Do ##class(OcuPilot.Test.TurnProvider).Forget("${escapeOs(tag)}")`]);
}

/** Call `call`'s recorded `messages` array (JSON), the same shape a real Anthropic-style request carries. */
function recordedMessages(tag, call = 1) {
  const output = runIris([
    `Write "OCUCHIP-MSGS-START:"_##class(OcuPilot.Test.TurnProvider).Recorded("${escapeOs(tag)}",${call},"messages")_":OCUCHIP-MSGS-END",!`,
  ]);
  const value = markerValue(output, 'OCUCHIP-MSGS');
  assert.ok(value, `Recorded answered: ${output}`);
  return JSON.parse(value);
}

/**
 * The `screen_context` payload from a recorded `messages` array (Anthropic wire shape: each
 * message's `content` is an array of blocks), or `null` when none is present.
 */
function screenContextPayload(messages) {
  const useIndex = messages.findIndex(
    (entry) =>
      entry.role === 'assistant' &&
      Array.isArray(entry.content) &&
      entry.content.some((block) => block.type === 'tool_use' && block.name === 'screen_context')
  );
  if (useIndex < 0) return null;
  const resultEntry = messages[useIndex + 1];
  if (resultEntry?.role !== 'user' || !Array.isArray(resultEntry.content)) return null;
  const resultBlock = resultEntry.content.find((block) => block.type === 'tool_result');
  if (!resultBlock) return null;
  return JSON.parse(resultBlock.content);
}

function authHeader() {
  return 'Basic ' + Buffer.from(`${config.username}:${config.password}`).toString('base64');
}

async function putShare(share) {
  const answer = await fetch(`${config.origin}${CONTEXT_PATH}`, {
    method: 'PUT',
    headers: { Authorization: authHeader(), 'Content-Type': 'application/json' },
    body: JSON.stringify({ share }),
  });
  assert.ok(answer.ok, `PUT /agent/context {share:${share}} (HTTP ${answer.status})`);
}

/** A fresh context signed in as the configured user, standing on `url` with the panel laid out. */
async function signedInAt(url) {
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.setViewport(config.viewport);
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-panel aside.ocu-panel', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  await page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), {
    timeout: config.navigationTimeoutMs,
  });
  return { context, page };
}

async function typeAndSend(page, text) {
  await page.type('#ocu-panel-composer', text);
  await page.click('.ocu-panel-send');
}

function chipState(page) {
  return page.evaluate(() => {
    const chip = document.querySelector('.ocu-context-chip');
    if (chip === null) return null;
    return {
      text: chip.querySelector('.ocu-context-chip-text')?.textContent ?? '',
      pill: chip.querySelector('.ocu-context-chip-pill')?.textContent?.trim() ?? null,
      pillTitle: chip.querySelector('.ocu-context-chip-pill')?.getAttribute('title') ?? null,
      glyph: chip.querySelector('.ocu-context-chip-glyph') !== null,
      switchChecked: chip.querySelector('.ocu-context-chip-switch')?.checked ?? null,
    };
  });
}

test('List screen, remote provider: the chip carries the row count, provider and host, with the egress pill and its tooltip', async () => {
  const { context, page } = await signedInAt(USERS_URL);
  try {
    await page.waitForFunction(() => (document.querySelector('.ocu-context-chip-text')?.textContent ?? '').includes('rows'), {
      timeout: config.navigationTimeoutMs,
    });
    const state = await chipState(page);
    assert.match(state.text, /^Users, HSCUSTOM \u00b7 \d+ rows \u00b7 turnprobe \u00b7 192\.0\.2\.10/);
    assert.equal(state.pill, STRINGS.contextChipLeavesInstance);
    assert.equal(state.pillTitle, STRINGS.contextChipSentToHost.split('<host>').join('192.0.2.10'));
    assert.equal(state.glyph, false);
    assert.equal(state.switchChecked, true);
  } finally {
    await context.close();
  }
});

test('Secret-typed screen: the key glyph is present and no row segment appears', async () => {
  const { context, page } = await signedInAt(FORM_URL);
  try {
    await page.waitForSelector('.ocu-context-chip', { timeout: config.navigationTimeoutMs });
    const state = await chipState(page);
    assert.equal(state.glyph, true);
    assert.doesNotMatch(state.text, /rows/);
    const glyphName = await page.evaluate(
      () => document.querySelector('.ocu-context-chip-glyph + .ocu-visually-hidden')?.textContent ?? ''
    );
    assert.equal(glyphName, STRINGS.agentContextChipSecretGlyph);
  } finally {
    await context.close();
  }
});

test('Toggle off survives a reload: the chip reads the sharing-off sentence both before and after', async () => {
  const { context, page } = await signedInAt(USERS_URL);
  try {
    await page.waitForSelector('.ocu-context-chip-switch', { timeout: config.navigationTimeoutMs });
    await page.click('.ocu-context-chip-switch');
    await page.waitForFunction(
      (expected) => (document.querySelector('.ocu-context-chip-text')?.textContent ?? '').trim() === expected,
      { timeout: config.navigationTimeoutMs },
      STRINGS.contextChipSharingOff
    );
    await page.reload({ waitUntil: 'networkidle2' });
    await page.waitForSelector('app-panel aside.ocu-panel', { timeout: config.navigationTimeoutMs });
    await page.waitForFunction(
      (expected) => (document.querySelector('.ocu-context-chip-text')?.textContent ?? '').trim() === expected,
      { timeout: config.navigationTimeoutMs },
      STRINGS.contextChipSharingOff
    );
    const switchChecked = await page.evaluate(() => document.querySelector('.ocu-context-chip-switch').checked);
    assert.equal(switchChecked, false, 'the per-user choice was re-read from the instance, not remembered locally');
  } finally {
    await context.close();
    await putShare(true);
  }
});

test("the paste warning's two buttons: Send anyway sends the exact text; Edit refocuses without recording", async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, textReply('acknowledged'));
  const { context, page } = await signedInAt(USERS_URL);
  const secret = 'sk-ant-api03-abcdefghijklmnopqrstuvwxyz';
  try {
    await page.type('#ocu-panel-composer', secret);
    await page.click('.ocu-panel-send');
    await page.waitForSelector('.ocu-panel-warning[role="status"]', { timeout: config.navigationTimeoutMs });

    await page.click('.ocu-panel-warning-edit');
    await page.waitForFunction(() => document.querySelector('.ocu-panel-warning') === null, {
      timeout: config.navigationTimeoutMs,
    });
    const focusedComposer = await page.evaluate(() => document.activeElement.id === 'ocu-panel-composer');
    assert.ok(focusedComposer, 'Edit returned focus to the composer');

    await page.click('.ocu-panel-send');
    await page.waitForSelector('.ocu-panel-warning[role="status"]', { timeout: config.navigationTimeoutMs });
    await page.click('.ocu-panel-warning-send');
    await page.waitForFunction(() => document.querySelector('.ocu-panel-warning') === null, {
      timeout: config.navigationTimeoutMs,
    });
    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === 'acknowledged',
      { timeout: config.navigationTimeoutMs }
    );
    const sentMessage = await page.evaluate(() => document.querySelector('.ocu-panel-message-user')?.textContent ?? '');
    assert.equal(sentMessage, secret, 'the exact acknowledged text was sent');
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

test('Integration AC: a sent turn carries the synthetic screen_context pair naming the route, the namespace and the rows the chip displayed', async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, textReply('read the users'));
  const { context, page } = await signedInAt(USERS_URL);
  try {
    await page.waitForFunction(() => (document.querySelector('.ocu-context-chip-text')?.textContent ?? '').includes('rows'), {
      timeout: config.navigationTimeoutMs,
    });
    const rowsShown = await page.evaluate(() => {
      const match = /(\d+) rows/.exec(document.querySelector('.ocu-context-chip-text').textContent);
      return match ? Number(match[1]) : null;
    });
    assert.ok(Number.isInteger(rowsShown), 'the chip showed a row count');

    await typeAndSend(page, 'who are the users');
    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === 'read the users',
      { timeout: config.navigationTimeoutMs }
    );

    const payload = screenContextPayload(recordedMessages(tag, 1));
    assert.ok(payload, 'a screen_context tool_use/tool_result pair was recorded');
    assert.equal(payload.route, 'permissions/users');
    assert.equal(payload.namespace, 'HSCUSTOM');
    assert.equal(payload.rows.length, rowsShown, 'exactly the rows the chip displayed');
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

test('Fresh at Send: context is assembled at the moment of the click, not cached from an earlier screen', async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(tag, 0, textReply('first'));
  scriptReply(tag, 0, textReply('second'));
  const { context, page } = await signedInAt(USERS_URL);
  try {
    await page.waitForFunction(() => (document.querySelector('.ocu-context-chip-text')?.textContent ?? '').includes('rows'), {
      timeout: config.navigationTimeoutMs,
    });
    await typeAndSend(page, 'first turn, on Users');
    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') === 'first',
      { timeout: config.navigationTimeoutMs }
    );

    // A real in-app navigation (the rail then the side bar, client-side routed), not a page
    // reload -- the AC is about the screen the user moved to inside the running shell. Only
    // Home's rail item navigates directly; every other area opens its side bar first.
    await page.click('#ocu-rail-item-os-management');
    // `.ocu-side-bar-item` can already exist for the PREVIOUS area (Users' own single entry), so
    // waiting for the selector alone can resolve before the side bar has actually swapped to this
    // area's -- wait for the specific text instead.
    await page.waitForFunction(
      () => [...document.querySelectorAll('.ocu-side-bar-item')].some((el) => el.textContent.includes('Processes')),
      { timeout: config.navigationTimeoutMs }
    );
    await page.evaluate(() => {
      const item = [...document.querySelectorAll('.ocu-side-bar-item')].find((el) =>
        el.textContent.includes('Processes')
      );
      item?.click();
    });
    await page.waitForFunction(
      () => (document.querySelector('.ocu-context-chip-text')?.textContent ?? '').startsWith('Processes'),
      { timeout: config.navigationTimeoutMs }
    );
    await typeAndSend(page, 'second turn, on Processes');
    // The SAME conversation now holds two turns, so two `.ocu-panel-message-agent-text`
    // paragraphs exist -- the last one is this turn's.
    await page.waitForFunction(
      () => {
        const replies = document.querySelectorAll('.ocu-panel-message-agent-text');
        return replies[replies.length - 1]?.textContent === 'second';
      },
      { timeout: config.navigationTimeoutMs }
    );

    const payload = screenContextPayload(recordedMessages(tag, 2));
    assert.ok(payload, 'a screen_context pair was recorded for the second turn');
    assert.equal(
      payload.route,
      'os-management/processes',
      "the second turn's context names the second screen, not the first"
    );
  } finally {
    await context.close();
    forgetTag(tag);
  }
});
