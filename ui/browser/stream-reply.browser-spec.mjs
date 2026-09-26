/**
 * The streamed reply in a real browser, against the throwaway instance (Story 11.7): while the
 * model writes, the running model step's text grows in an inert block beside the avatar; when the
 * turn ends the block is replaced by exactly the reply a plain turn renders -- under reduced motion
 * too -- and a failure, a write proposal and a refusal each end as they would without streaming.
 * No request leaves the origin throughout.
 *
 * Every turn is answered by the `turnprobe` provider (`OcuPilot.Test.TurnProvider`): a tag scripted
 * with `ScriptStream` streams its reply through the shipped chunk reader, and a tag marked `Plain`
 * answers the same script with no stream, which is the comparison each leg draws.
 *
 * Run: `npm run build`, `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/stream-reply.browser-spec.mjs`.
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
const probe = { container: config.container, marker: 'STREAM' };

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';

/** The follow rule's tolerance, in CSS px (`shell/panel-follow.ts`). */
const TOLERANCE_PX = 4;

/** The demo fixture's own web application, which a clean throwaway always serves (AD-25). */
const TARGET = '/csp/myapp';

let browser = null;
let preparedId = '';
let priorDefault = '';

/** Every request any page of this file made to another origin. */
const offOrigin = [];

/** The final reply container's HTML from leg (b)'s plain run, for leg (c). */
let plainFinalHtml = '';

/** The final reply container's HTML from leg (a)'s streamed run, for leg (b). */
let streamedFinalHtml = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec arms the turnprobe provider, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await requireFreeSlot(config);
  browser = await puppeteer.launch(launchOptions(config));
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
  iris('STRRW', `Set sc=##class(OcuPilot.Test.Restraint).SetDefinitionReadOnly("${escapeOs(preparedId)}",0)`);
  dropProposals();
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  await requireFreeSlot(config).catch(() => {});
  dropProposals();
  disarmProbeDefinition(probe, priorDefault);
});

/** Run one ObjectScript line that sets `sc`, and assert it answered OK. */
function iris(marker, line) {
  const output = runIris(config.container, [line, `Write "OCU-${marker}-START:"_$System.Status.IsOK(sc)_":OCU-${marker}-END",!`]);
  assert.equal(markerValue(output, marker), '1', `${marker} succeeded: ${output}`);
}

/** Remove every proposal this spec's principal minted. */
function dropProposals() {
  iris('STRDROP', `Set sc=##class(OcuPilot.Kernel.State.Propose).GuardedDeleteForUser("${escapeOs(config.username)}")`);
}

/** A fresh tag the definition now names, scripted by `script(tag)`. */
function freshTag(script) {
  const tag = nextTag(probe);
  setTag(probe, preparedId, tag);
  script(tag);
  return tag;
}

/** Script `tag` to stream `bodyExpr`, spreading `midHangSeconds` over it, broken at half when asked. */
function scriptStream(tag, bodyExpr, midHangSeconds = 0, breakAtHalf = 0) {
  iris('STRSCRIPT', `Set sc=##class(OcuPilot.Test.TurnProvider).ScriptStream("${escapeOs(tag)}",0,${bodyExpr},${midHangSeconds},${breakAtHalf})`);
}

/** Mark `tag` plain: its calls ask for no stream. */
function markPlain(tag) {
  iris('STRPLAIN', `Set sc=##class(OcuPilot.Test.TurnProvider).Plain("${escapeOs(tag)}")`);
}

/** A long Markdown reply: a heading, a list, a code block, a remote image, a link and non-ASCII text. */
function longReplyExpr() {
  const lines = ['## What I found', ''];
  for (let i = 1; i <= 30; i += 1) lines.push(`- Item ${i} of the list, with \`code\` and **bold** words in it.`);
  lines.push('', '```sql', 'SELECT Name FROM Security.Users -- the list', '```', '');
  lines.push('![remote](https://images.example.com/diagram.png)', '', 'See [the docs](https://docs.example.com/page).');
  const joined = lines.map((line) => `"${escapeOs(line)}"`).join('_$Char(10)_');
  return `##class(OcuPilot.Test.TurnProvider).TextReply(${joined}_$Char(10,10)_"Caf"_$Char(233)_" costs 5 "_$Char(8364)_".")`;
}

/** A `tool_use` reply naming the shipped write tool on the demo application, with a fixed description. */
function proposeExpr(description) {
  const input = {
    Name: TARGET,
    Description: description,
    rationale: 'The application carries no description, so nobody can tell what it is for.',
    expectedImpact: 'the list names what the application is for',
    reverse: 'clear the description again',
  };
  return `##class(OcuPilot.Test.TurnProvider).ToolUseReply([{"id": "toolu_stream", "name": "webapp_list_update", "input": ${JSON.stringify(input)}}])`;
}

/** A signed-in page on Home with the composer usable, every off-origin request recorded. */
async function openPanel(mediaFeatures = null) {
  await requireFreeSlot(config);
  const opened = await signedInAt(browser, config, HOME_URL, config.viewport, mediaFeatures);
  opened.page.on('request', (request) => {
    const url = request.url();
    if (url.startsWith('data:') || url.startsWith('blob:')) return;
    if (!url.startsWith(config.origin)) offOrigin.push(url);
  });
  await opened.page.waitForFunction(() => !document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled'), {
    timeout: config.navigationTimeoutMs,
  });
  return opened;
}

async function send(page, text) {
  await page.type('#ocu-panel-composer', text);
  await page.click('.ocu-panel-send');
}

/**
 * Wait until the turn has ended in `outcome` -- a final `reply`, an error `banner`, or a proposal
 * `card` -- and Send reads Send again. The label alone is not enough: it reads Send before the
 * turn has started too.
 */
async function waitTurnEnd(page, outcome) {
  await page.waitForFunction(
    (sendLabel, wanted) => {
      if (document.querySelector('.ocu-panel-send')?.textContent?.trim() !== sendLabel) return false;
      if (wanted === 'banner') return document.querySelector('.ocu-panel-error-banner') !== null;
      if (wanted === 'card') return document.querySelector('app-proposal-card .ocu-proposal-card-confirm') !== null;
      return document.querySelector('.ocu-panel-message-agent:not(.ocu-panel-message-streamed) app-reply') !== null;
    },
    { timeout: 60000 },
    STRINGS.actionSend,
    outcome
  );
}

/** The final reply's container, as HTML, or `''` when none rendered. */
function finalReplyHtml(page) {
  return page.evaluate(() => {
    const replies = [...document.querySelectorAll('.ocu-panel-message-agent:not(.ocu-panel-message-streamed)')].filter(
      (node) => node.querySelector('app-reply') !== null
    );
    return replies.length === 0 ? '' : replies[replies.length - 1].outerHTML;
  });
}

/** The streamed block's state this instant. */
function streamedState(page) {
  return page.evaluate(() => {
    const block = document.querySelector('.ocu-panel-message-streamed');
    if (block === null) return null;
    const style = getComputedStyle(block);
    const transcript = document.querySelector('.ocu-panel-transcript');
    return {
      inert: block.hasAttribute('inert'),
      length: block.textContent.length,
      avatar: block.querySelector('.ocu-panel-message-avatar') !== null,
      forbidden: block.querySelectorAll('img, script, iframe').length,
      animationName: style.animationName,
      transitionDuration: style.transitionDuration,
      distance: transcript.scrollHeight - transcript.scrollTop - transcript.clientHeight,
    };
  });
}

/** Wait for the streamed block to appear, then for it to grow; answer the two readings. */
async function watchGrowth(page) {
  await page.waitForSelector('.ocu-panel-message-streamed', { timeout: 30000 });
  const first = await streamedState(page);
  await page.waitForFunction(
    (length) => {
      const block = document.querySelector('.ocu-panel-message-streamed');
      return block !== null && block.textContent.length > length;
    },
    { timeout: 30000 },
    first.length
  );
  const second = await streamedState(page);
  return { first, second };
}

test('(a) a streamed reply grows in an inert block at the newest entry, and ends as a reply', async () => {
  // Mutations (Rule 19): pass no sink from `Loop.Run` (no streamed block ever appears), or drop
  // `inert` from the block in `panel.ts` -> this goes red.
  const tag = freshTag((t) => scriptStream(t, longReplyExpr(), 10));
  const { context, page } = await openPanel();
  try {
    await send(page, 'summarize the users');
    const { first, second } = await watchGrowth(page);
    assert.equal(first.inert, true, 'the streamed block is inert');
    assert.equal(first.avatar, true, 'beside the avatar');
    assert.ok(second.length > first.length, `it grows between two reads: ${first.length} -> ${second.length}`);
    assert.equal(second.forbidden, 0, 'no img, script or iframe is created from streamed text');
    // The follow check means something only once the streamed text overflows the transcript.
    await page.waitForFunction(
      (tolerance) => {
        const transcript = document.querySelector('.ocu-panel-transcript');
        return document.querySelector('.ocu-panel-message-streamed') !== null && transcript.scrollHeight > transcript.clientHeight + tolerance;
      },
      { timeout: 30000 },
      TOLERANCE_PX
    );
    // The follow scroll is smooth outside reduced motion, so it is awaited, while the block still shows.
    const followed = await page
      .waitForFunction(
        (tolerance) => {
          const transcript = document.querySelector('.ocu-panel-transcript');
          const distance = transcript.scrollHeight - transcript.scrollTop - transcript.clientHeight;
          return document.querySelector('.ocu-panel-message-streamed') !== null && distance <= tolerance;
        },
        { timeout: 5000 },
        TOLERANCE_PX
      )
      .then(() => true, () => false);
    const overflowed = await streamedState(page);
    assert.ok(followed, `the transcript follows the growing text to its newest entry: ${overflowed === null ? 'block gone' : `${overflowed.distance} px away`}`);
    await waitTurnEnd(page, 'reply');
    assert.equal(await page.$('.ocu-panel-message-streamed'), null, 'the streamed block is gone once the turn ends');
    streamedFinalHtml = await finalReplyHtml(page);
    assert.ok(streamedFinalHtml.includes('app-reply'), 'and the final reply rendered');
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});

test('(b) the streamed final reply is the plain one, byte for byte', async () => {
  // Compares leg (a)'s final reply container with a plain run's; that the streamed block is gone
  // is asserted by (a) and (c).
  const tag = freshTag((t) => {
    markPlain(t);
    scriptReply(probe, t, 0, longReplyExpr());
  });
  const { context, page } = await openPanel();
  try {
    await send(page, 'summarize the users');
    await waitTurnEnd(page, 'reply');
    plainFinalHtml = await finalReplyHtml(page);
    assert.ok(plainFinalHtml !== '', 'the plain reply rendered');
    assert.equal(streamedFinalHtml, plainFinalHtml, 'the streamed turn ends with exactly the plain reply');
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});

test('(c) under reduced motion nothing animates the streamed block, and the final reply is the same', async () => {
  const tag = freshTag((t) => scriptStream(t, longReplyExpr(), 6));
  const { context, page } = await openPanel([{ name: 'prefers-reduced-motion', value: 'reduce' }]);
  try {
    await send(page, 'summarize the users');
    const { second } = await watchGrowth(page);
    assert.equal(second.animationName, 'none', 'no animation on the streamed block');
    assert.equal(second.transitionDuration, '0s', 'and no transition');
    await waitTurnEnd(page, 'reply');
    assert.equal(await page.$('.ocu-panel-message-streamed'), null, 'the streamed block is gone once the turn ends');
    assert.equal(await finalReplyHtml(page), plainFinalHtml, 'the final reply is the plain one');
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});

test('(d) a stream broken at half ends as a plain transport failure: the banner, no reply, no streamed block', async () => {
  const banners = [];
  for (const streamed of [true, false]) {
    const tag = freshTag((t) => {
      if (streamed) scriptStream(t, longReplyExpr(), 2, 1);
      else scriptReply(probe, t, 0, '""', -1);
    });
    const { context, page } = await openPanel();
    try {
      await send(page, 'summarize the users');
      await waitTurnEnd(page, 'banner');
      const shape = await page.evaluate(() => ({
        banner: document.querySelector('.ocu-panel-error-banner')?.textContent?.trim() ?? '',
        replies: document.querySelectorAll('app-reply').length,
        streamed: document.querySelectorAll('.ocu-panel-message-streamed').length,
      }));
      assert.equal(shape.replies, 0, 'no reply');
      assert.equal(shape.streamed, 0, 'no streamed block');
      banners.push(shape.banner);
    } finally {
      await context.close();
      forgetTag(probe, tag);
    }
  }
  assert.ok(banners[0] !== '', 'the broken stream shows a banner');
  assert.equal(banners[0], banners[1], 'the banner a plain transport failure shows');
});

test('(e) a streamed write proposal renders the card a plain one does', async () => {
  // Mutation (Rule 19): drop the `input_json_delta` branch of `StreamAdapter.TakeAnthropic` ->
  // the streamed turn mints no proposal and this goes red.
  const description = `Streamed probe ${Date.now()}`;
  const cards = [];
  for (const streamed of [true, false]) {
    dropProposals();
    const tag = freshTag((t) => {
      if (streamed) {
        scriptStream(t, proposeExpr(description));
        scriptStream(t, '##class(OcuPilot.Test.TurnProvider).TextReply("I proposed the change.")');
      } else {
        markPlain(t);
        scriptReply(probe, t, 0, proposeExpr(description));
        scriptReply(probe, t, 0, '##class(OcuPilot.Test.TurnProvider).TextReply("I proposed the change.")');
      }
    });
    const { context, page } = await openPanel();
    try {
      await send(page, 'give /csp/myapp a description');
      await waitTurnEnd(page, 'card');
      await waitTurnEnd(page, 'reply');
      const html = await page.evaluate(() => document.querySelector('app-proposal-card').outerHTML);
      cards.push(html.replace(/\d+:\d\d/g, 'M:SS'));
    } finally {
      await context.close();
      forgetTag(probe, tag);
    }
  }
  assert.equal(cards[0], cards[1], 'the streamed proposal card equals the plain one, times normalized');
});

test('(f) a refusal shows the PROVIDER.DECLINED banner and no reply', async () => {
  // Mutation (Rule 19): remove the refusal branch from `Loop.Run` -> the turn completes with a
  // reply and this goes red.
  const refusal = '"{""content"":[{""type"":""text"",""text"":""I can""}],""stop_reason"":""refusal"",""usage"":{""input_tokens"":5,""output_tokens"":2}}"';
  const tag = freshTag((t) => scriptStream(t, refusal));
  const { context, page } = await openPanel();
  try {
    await send(page, 'do something it will decline');
    await waitTurnEnd(page, 'banner');
    const shape = await page.evaluate(() => ({
      banner: document.querySelector('.ocu-panel-error-banner')?.textContent?.trim() ?? '',
      replies: document.querySelectorAll('app-reply').length,
    }));
    assert.ok(shape.banner.includes('The model declined to answer this request'), `the declined banner: ${shape.banner}`);
    assert.equal(shape.replies, 0, 'and no reply');
  } finally {
    await context.close();
    forgetTag(probe, tag);
  }
});

test('(g) no request left the origin in any leg', () => {
  assert.deepEqual(offOrigin, [], `off-origin requests: ${JSON.stringify(offOrigin)}`);
});
