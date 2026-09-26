/**
 * The panel transcript follows the conversation, in real layout (Story 11.10): a Send brings the
 * sent message into view and the transcript to its newest entry, an arrival while the user has
 * scrolled up leaves the position alone and shows "Jump to latest", the control passes the
 * structural invariants, pressing it returns to the newest entry with focus on the transcript, and
 * reduced motion makes the scroll instant. jsdom computes no layout, so none of this is observable
 * in the component suite.
 *
 * Every turn is answered by the `turnprobe` provider (`OcuPilot.Test.TurnProvider`), scripted per
 * test through `docker exec`, so no live model is called.
 *
 * Run: `npm run build`, `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/transcript-follow.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
import { INVARIANTS, componentMinimums, detectScreen } from './structural-walk.mjs';
import {
  armProbeDefinition,
  disarmProbeDefinition,
  escapeOs,
  forgetTag,
  nextTag,
  requireFreeSlot,
  scriptReply,
  setTag,
} from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();
const probe = { container: config.container, marker: 'FOLLOW' };

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';

/** The follow rule's tolerance, in CSS px (`shell/panel-follow.ts`). */
const TOLERANCE_PX = 4;

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
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  disarmProbeDefinition(probe, priorDefault);
});

/** A reply long enough to overflow the transcript on its own: `paragraphs` numbered paragraphs. */
function longReply(label, paragraphs = 24) {
  const lines = [];
  for (let i = 1; i <= paragraphs; i += 1) {
    if (i > 1) lines.push('');
    lines.push(`${label} paragraph ${i}: the transcript grows by one more block of text here.`);
  }
  const joined = lines.map((line) => `"${escapeOs(line)}"`).join('_$Char(10)_');
  return `##class(OcuPilot.Test.TurnProvider).TextReply(${joined})`;
}

/** Script the next turn's reply on a fresh tag, and answer the tag for cleanup. */
function nextReply(label, hangSeconds, paragraphs) {
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  scriptReply(probe, tag, hangSeconds, longReply(label, paragraphs));
  return tag;
}

/** Signed in on Home with the composer usable. */
async function openPanel(mediaFeatures = null) {
  const opened = await signedInAt(browser, config, HOME_URL, config.viewport, mediaFeatures);
  await opened.page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), {
    timeout: config.navigationTimeoutMs,
  });
  return opened;
}

async function send(page, text) {
  await page.type('#ocu-panel-composer', text);
  await page.click('.ocu-panel-send');
}

/** Wait until `count` user messages are in the transcript. */
async function waitForMessages(page, count) {
  await page.waitForFunction((n) => document.querySelectorAll('.ocu-panel-message-user').length >= n, { timeout: config.navigationTimeoutMs }, count);
}

/** Wait until `count` replies have rendered and the turn has ended (Send reads Send again). */
async function waitForReplies(page, count) {
  await page.waitForFunction(
    (n, sendLabel) =>
      document.querySelectorAll('app-reply').length >= n &&
      document.querySelector('.ocu-panel-send')?.textContent?.trim() === sendLabel,
    { timeout: config.navigationTimeoutMs },
    count,
    STRINGS.actionSend
  );
}

/** How far the transcript is from its newest entry, in CSS px. */
function distance(page) {
  return page.evaluate(() => {
    const el = document.querySelector('.ocu-panel-transcript');
    return el.scrollHeight - el.scrollTop - el.clientHeight;
  });
}

/** Wait until the transcript is at its newest entry, and say how far it was when it did not get there. */
async function waitAtNewest(page, why) {
  try {
    await page.waitForFunction(
      (tolerance) => {
        const el = document.querySelector('.ocu-panel-transcript');
        return el.scrollHeight - el.scrollTop - el.clientHeight <= tolerance;
      },
      { timeout: 5000 },
      TOLERANCE_PX
    );
  } catch {
    assert.fail(`${why}: the transcript never reached its newest entry (${await distance(page)} px away)`);
  }
}

/** Wait until the transcript's `scrollTop` holds still across two reads, and answer it. */
async function settledTop(page) {
  let last = -1;
  for (let i = 0; i < 40; i += 1) {
    const top = await page.evaluate(() => document.querySelector('.ocu-panel-transcript').scrollTop);
    if (top === last) return top;
    last = top;
    await new Promise((resolve) => setTimeout(resolve, 150));
  }
  return last;
}

/**
 * The user scrolls the transcript up with the mouse wheel, and the position settles. The panel's own
 * smooth scroll is let finish first, and a wheel scroll starts asynchronously, so this waits for the
 * position to leave where it stood.
 */
async function wheelUp(page, deltaY = -600) {
  await settledTop(page);
  const box = await page.evaluate(() => {
    const el = document.querySelector('.ocu-panel-transcript');
    const rect = el.getBoundingClientRect();
    return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2, top: el.scrollTop };
  });
  await page.mouse.move(box.x, box.y);
  await page.mouse.wheel({ deltaY });
  await page.waitForFunction((from) => document.querySelector('.ocu-panel-transcript').scrollTop < from, { timeout: 5000 }, box.top);
  return settledTop(page);
}

/** The transcript's geometry, for a failure message. */
function geometry(page) {
  return page.evaluate(() => {
    const el = document.querySelector('.ocu-panel-transcript');
    return JSON.stringify({ scrollTop: el.scrollTop, scrollHeight: el.scrollHeight, clientHeight: el.clientHeight });
  });
}

/** Whether the last sent message lies inside the transcript's own box. */
function lastMessageInView(page) {
  return page.evaluate(() => {
    const log = document.querySelector('.ocu-panel-transcript').getBoundingClientRect();
    const messages = document.querySelectorAll('.ocu-panel-message-user');
    const rect = messages[messages.length - 1].getBoundingClientRect();
    return rect.top >= log.top - 1 && rect.bottom <= log.bottom + 1;
  });
}

const jumpVisible = (page) => page.evaluate(() => document.querySelector('.ocu-panel-jump') !== null);

test('(a) three turns: each Send brings the sent message into view and the transcript to its newest entry, from a scrolled-up transcript too', async () => {
  // Mutation (Rule 19): drop `followNewest()` from the panel's accepted-send path -> the second
  // Send, made from a scrolled-up transcript, leaves the message out of view and this goes red.
  const tags = [];
  const { context, page } = await openPanel();
  try {
    for (let turn = 1; turn <= 3; turn += 1) {
      if (turn > 1) {
        await wheelUp(page, -2000);
        assert.ok((await distance(page)) > TOLERANCE_PX, `turn ${turn}: the user has scrolled away before sending: ${await geometry(page)}`);
      }
      tags.push(nextReply(`Turn ${turn}`, 2));
      await send(page, `message ${turn}`);
      await waitForMessages(page, turn);
      await waitAtNewest(page, `turn ${turn}, after Send`);
      assert.equal(await lastMessageInView(page), true, `turn ${turn}: the sent message is inside the transcript`);
      assert.equal(await jumpVisible(page), false, `turn ${turn}: no Jump to latest while at the newest entry`);
      await waitForReplies(page, turn);
      await waitAtNewest(page, `turn ${turn}, after its reply arrived while following`);
    }
    const behavior = await page.evaluate(() => getComputedStyle(document.querySelector('.ocu-panel-transcript')).scrollBehavior);
    assert.equal(behavior, 'smooth', 'without reduced motion the transcript scrolls smoothly');
  } finally {
    await context.close();
    for (const tag of tags) forgetTag(probe, tag);
  }
});

test('(b) an arrival while scrolled up leaves the position, Jump to latest passes the invariants, and pressing it returns with focus on the transcript', async () => {
  // Mutations (Rule 19): scroll on every arrival regardless of following -> the unchanged-position
  // assertion goes red; drop the focus call from the jump -> the active-element assertion goes red.
  const tags = [];
  const { context, page } = await openPanel();
  try {
    tags.push(nextReply('First', 0));
    await send(page, 'first message');
    await waitForReplies(page, 1);
    await waitAtNewest(page, 'after the first reply');

    tags.push(nextReply('Second', 12));
    await send(page, 'second message');
    await waitForMessages(page, 2);
    await waitAtNewest(page, 'after the second Send');
    const top = await wheelUp(page, -600);
    assert.ok((await distance(page)) > TOLERANCE_PX, `the user has scrolled away from the newest entry: ${await geometry(page)}`);
    await page.waitForSelector('.ocu-panel-jump', { timeout: 5000 });
    const repliesBefore = await page.evaluate(() => document.querySelectorAll('app-reply').length);
    assert.equal(repliesBefore, 1, 'the second reply has not arrived yet, so what follows observes an arrival while scrolled up');

    await waitForReplies(page, 2);
    await new Promise((resolve) => setTimeout(resolve, 1000));
    assert.equal(await settledTop(page), top, 'the reply arrived without moving the scrolled-up transcript');
    assert.equal(await jumpVisible(page), true, 'and Jump to latest is shown');

    const shape = await page.evaluate(() => {
      const jump = document.querySelector('.ocu-panel-jump');
      const rect = jump.getBoundingClientRect();
      const composer = document.querySelector('#ocu-panel-composer').getBoundingClientRect();
      return {
        text: jump.textContent.trim(),
        inLog: jump.closest('[role="log"]') !== null,
        width: rect.width,
        height: rect.height,
        overlapsComposer: rect.bottom > composer.top && rect.top < composer.bottom,
      };
    });
    assert.equal(shape.text, STRINGS.agentJumpToLatest);
    assert.equal(shape.inLog, false, 'the control sits outside the log');
    assert.ok(shape.width >= 24 && shape.height >= 24, `the control is at least 24 x 24 CSS px, got ${shape.width} x ${shape.height}`);
    assert.equal(shape.overlapsComposer, false, 'the control never overlays the composer');

    const { entries } = await detectScreen(page, {
      route: '/',
      checks: INVARIANTS,
      viewport: config.viewport.width,
      theme: 'light',
      minimums: componentMinimums(),
    });
    const onControl = entries.filter((entry) => entry.element.includes('ocu-panel-jump'));
    assert.deepEqual(onControl, [], `no structural violation names the control: ${JSON.stringify(onControl)}`);

    await page.click('.ocu-panel-jump');
    await waitAtNewest(page, 'after Jump to latest');
    await page.waitForFunction(() => document.querySelector('.ocu-panel-jump') === null, { timeout: 5000 });
    const focused = await page.evaluate(() => document.activeElement?.classList.contains('ocu-panel-transcript') ?? false);
    assert.equal(focused, true, 'focus is on the transcript');
  } finally {
    await context.close();
    for (const tag of tags) forgetTag(probe, tag);
  }
});

test('(d) a wheel turned up while the panel\'s own smooth scroll is on its way stops it there, and Jump to latest shows again', async () => {
  // Mutation (Rule 19): drop the panel's passive wheel listener -> the browser carries its own
  // scroll on over the wheel to the newest entry, the control goes away, and this goes red.
  const tags = [];
  const { context, page } = await openPanel();
  try {
    tags.push(nextReply('Interrupted', 0, 48));
    await send(page, 'a long answer please');
    await waitForReplies(page, 1);
    await waitAtNewest(page, 'after the reply');
    await wheelUp(page, -4000);
    await page.waitForSelector('.ocu-panel-jump', { timeout: 5000 });
    assert.ok((await distance(page)) > 600, `the user has scrolled far from the newest entry: ${await geometry(page)}`);
    const centre = await page.evaluate(() => {
      const rect = document.querySelector('.ocu-panel-transcript').getBoundingClientRect();
      return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
    });

    await page.click('.ocu-panel-jump');
    await page.mouse.move(centre.x, centre.y);
    await page.mouse.wheel({ deltaY: -100 });
    await settledTop(page);
    assert.ok((await distance(page)) > TOLERANCE_PX, `the own scroll stopped short of the newest entry: ${await geometry(page)}`);
    assert.equal(await jumpVisible(page), true, 'and Jump to latest is shown again');
  } finally {
    await context.close();
    for (const tag of tags) forgetTag(probe, tag);
  }
});

test('(c) under reduced motion the transcript scrolls instantly: a jump lands at the newest entry in the same frame', async () => {
  // Mutation (Rule 19): drop the reduced-motion override -> `scroll-behavior` computes `smooth` and
  // the same-evaluate distance is still the scrolled-up one.
  const tags = [];
  const { context, page } = await openPanel([{ name: 'prefers-reduced-motion', value: 'reduce' }]);
  try {
    const behavior = await page.evaluate(() => getComputedStyle(document.querySelector('.ocu-panel-transcript')).scrollBehavior);
    assert.equal(behavior, 'auto', 'reduced motion computes scroll-behavior auto');

    tags.push(nextReply('Reduced', 0));
    await send(page, 'a long answer please');
    await waitForReplies(page, 1);
    await waitAtNewest(page, 'after the reply');
    await wheelUp(page, -1500);
    await page.waitForSelector('.ocu-panel-jump', { timeout: 5000 });

    const landed = await page.evaluate(() => {
      document.querySelector('.ocu-panel-jump').click();
      const el = document.querySelector('.ocu-panel-transcript');
      return el.scrollHeight - el.scrollTop - el.clientHeight;
    });
    assert.ok(landed <= TOLERANCE_PX, `the jump landed at the newest entry in the same evaluate, ${landed} px away`);
  } finally {
    await context.close();
    for (const tag of tags) forgetTag(probe, tag);
  }
});
