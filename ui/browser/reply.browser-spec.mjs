/**
 * A reply, rendered in a real browser against the throwaway instance (Story 4.6): sanitized
 * Markdown with highlighting, zero requests for a remote image or link, a render that survives
 * with every non-origin request aborted at the browser, the Content-Security-Policy actually
 * refusing a remote fetch and a remote image rather than merely not being exercised, and no
 * console error along the way.
 *
 * jsdom renders no CSS, issues no real network request and enforces no Content-Security-Policy,
 * so "no request left the origin" and "the browser refuses it" are only observable here. Every
 * test scripts its own `turnprobe` tag (`OcuPilot.Test.TurnProvider`) through `docker exec`, the
 * same fixture `OcuPilot.Test.TurnWire` drives over HTTP -- this drives the same provider through
 * the real panel instead, the way `turn.browser-spec.mjs` does.
 *
 * Run: `npm run build` then `docker cp` the bundle into the throwaway, then
 * `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test browser/reply.browser-spec.mjs`
 * (`.claude/rules/objectscript-testing.md`'s "a browser spec runs against the deployed bundle").
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';
import { resetRememberedState } from './preferences-reset.mjs';
import {
  armProbeDefinition,
  disarmProbeDefinition,
  escapeOs,
  forgetTag as sharedForgetTag,
  nextTag as sharedNextTag,
  runIris as sharedRunIris,
  scriptReply as sharedScriptReply,
  setTag as sharedSetTag,
} from './turnprobe-spec.mjs';

const config = browserConfig();
const probe = { container: config.container, marker: 'REPLY' };

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';

let browser = null;
let preparedId = '';
let priorDefault = '';

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec arms the turnprobe provider, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
  // Defensive: a prior run whose own `after` did not get to run (a crash, a killed process)
  // leaves the uniquely-named probe definition behind, and `EnsureDefinition` always inserts --
  // it does not upsert -- so a stale row here would fail every test in this file at `before`.
  const armed = armProbeDefinition(probe);
  priorDefault = armed.prior;
  preparedId = armed.preparedId;
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  disarmProbeDefinition(probe, priorDefault);
});

function runIris(lines) {
  return sharedRunIris(config.container, lines);
}

/** One `turnprobe` tag per test, so a stale script from an earlier test cannot answer a later one. */
function nextTag() {
  return sharedNextTag(probe);
}

/** Point the current definition at a fresh tag, so this test's scripts cannot answer another's turn. */
function setTag(tag) {
  sharedSetTag(probe, preparedId, tag);
}

/** Script one scripted reply for `tag`: `hangSeconds` before answering, then `bodyExpr` (ObjectScript). */
function scriptReply(tag, hangSeconds, bodyExpr) {
  sharedScriptReply(probe, tag, hangSeconds, bodyExpr);
}

function textReply(text) {
  return `##class(OcuPilot.Test.TurnProvider).TextReply("${escapeOs(text)}")`;
}

/**
 * A multi-line Markdown reply. `escapeOs` only doubles quotes, so a literal newline embedded in
 * the JS template would break across two lines of the ObjectScript session's own stdin -- each
 * line is its own quoted segment instead, joined with `_$Char(10)_`.
 */
function markdownReply(lines) {
  const joined = lines.map((line) => `"${escapeOs(line)}"`).join('_$Char(10)_');
  return `##class(OcuPilot.Test.TurnProvider).TextReply(${joined})`;
}

function forgetTag(tag) {
  sharedForgetTag(probe, tag);
}

/** A fresh context signed in as the configured user, standing on `url` with the frame laid out. */
async function signedInAt(url) {
  // Story 15.5: the remembered screen and shell state lives on the instance now, keyed by the
  // one account every spec signs in as, so a fresh context is no longer a fresh slate on its
  // own -- see `preferences-reset.mjs`.
  await resetRememberedState();
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

/** Console errors and uncaught page errors, the way `shell.browser-spec.mjs` collects them. */
function collectConsoleErrors(page) {
  const consoleErrors = [];
  page.on('console', (message) => {
    if (message.type() !== 'error') return;
    consoleErrors.push(`${message.text()} (${message.location()?.url ?? ''})`);
  });
  page.on('pageerror', (error) => consoleErrors.push(`uncaught: ${String(error)}`));
  return consoleErrors;
}

test('(a) a Markdown reply with a sql fence, a list and inline code renders through the real panel', async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(
    tag,
    0,
    markdownReply(['Findings:', '', '- a row', '- another, `Task-002`', '', '```sql', 'SELECT 1 -- c', '```'])
  );
  const { context, page } = await signedInAt(HOME_URL);
  const consoleErrors = collectConsoleErrors(page);
  try {
    await typeAndSend(page, 'summarize');
    await page.waitForSelector('.ocu-panel-message-agent-text pre > code.language-sql', {
      timeout: config.navigationTimeoutMs,
    });
    const shape = await page.evaluate(() => {
      const root = document.querySelector('.ocu-panel-message-agent-text');
      return {
        hasKeyword: root.querySelector('span.hljs-keyword') !== null,
        listItems: root.querySelectorAll('li').length,
        inlineCode: root.querySelector('code:not(pre code)')?.textContent ?? '',
      };
    });
    assert.equal(shape.hasKeyword, true, 'expected at least one span.hljs-keyword in the fenced code');
    assert.equal(shape.listItems, 2, 'expected the two list items');
    assert.equal(shape.inlineCode, 'Task-002', 'expected the inline code span carrying the cited row');
    assert.deepEqual(consoleErrors, [], `no console error or uncaught page error should occur, got: ${JSON.stringify(consoleErrors)}`);
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

// Named residual risk (## Auto Run Result, "Follow-up review recommendation"): three review-pass
// patches -- the hljs-built_in class surviving HLJS_CLASS_RE, a same-origin link suppressing the
// external-host caption, and a soft line break's <br> surviving sanitizeReplyRoot's DOMPurify
// pass -- were pinned only at the core/reply.ts unit level (`reply.test.mjs`) or the jsdom
// component level (`reply.spec.ts`), never against the real, deployed DOMPurify/browser stack.
// This closes that gap: one real-browser render exercising all three at once.
//
// It also carries every claim about the reply's own CSS, because jsdom computes no style: the
// block host, the structural highlighting that is the whole visible content of Release 1
// highlighting (Design Notes D3), the code-surface pair, the focus ring, and the preserved
// whitespace the literal-source fall-through needs.
//
// Mutations (Rule 19), each independently confirmed against the deployed bundle:
// - narrow `HLJS_CLASS_RE` back to `[a-z0-9-]*` (excluding `_`) in `core/reply.ts` -> the
//   hljs-built_in assertion goes red in the real browser exactly as it does in `reply.test.mjs`.
// - drop the `isSameOriginUrl` guard in `linkNodes` -> the caption-count assertion goes red,
//   finding a `.ocu-reply-link-caption` span the real DOM should not have.
// - drop `'br'` from `REPLY_TAGS` in `core/reply.ts` -> DOMPurify strips the element in the real
//   browser too, and the `<br>` count assertion goes red.
// - delete any one of `_components.scss`'s `display: block`, `.hljs-keyword { font-weight }`,
//   `.hljs-comment { font-style }`, `.ocu-reply-pre { background }`, `a:focus-visible` or
//   `.ocu-reply-source { white-space }` rules -> exactly that computed-style assertion goes red
//   while every class-presence assertion in the suite stays green, which is the point.
test('(a2) the reply\'s structure, its CSS and a same-origin link all survive in the real browser', async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(
    tag,
    0,
    markdownReply([
      'line one',
      'line two',
      '',
      '```sql',
      'SELECT UPPER(name) FROM t -- c',
      '```',
      '',
      '| a | b |',
      '|---|---|',
      '| 1 | 2 |',
      '',
      '[namespaces](/ocupilot/namespaces)',
    ])
  );
  const { context, page } = await signedInAt(HOME_URL);
  const consoleErrors = collectConsoleErrors(page);
  try {
    await typeAndSend(page, 'give me the mixed reply');
    await page.waitForSelector('.ocu-panel-message-agent-text pre > code.language-sql', {
      timeout: config.navigationTimeoutMs,
    });
    const shape = await page.evaluate(() => {
      const root = document.querySelector('.ocu-panel-message-agent-text');
      const link = root.querySelector('a[href="/ocupilot/namespaces"]');
      const pre = root.querySelector('pre.ocu-reply-pre');
      const keyword = root.querySelector('pre code span.hljs-keyword');
      const plainCode = root.querySelector('pre code');
      // `:focus-visible` cannot be read off a computed style -- whether it matches a programmatic
      // `focus()` is a per-browser heuristic about the last input modality, so asserting on it
      // would make this test flap. The rule itself is read out of the served stylesheet instead:
      // deleting it still reddens, and nothing about the reply's classes can satisfy it.
      const focusRule = (() => {
        for (const sheet of document.styleSheets) {
          let rules;
          try {
            rules = sheet.cssRules;
          } catch {
            continue;
          }
          for (const rule of rules) {
            if (rule.selectorText !== '.ocu-panel-message-agent-text a:focus-visible') continue;
            return { outline: rule.style.outline, boxShadow: rule.style.boxShadow };
          }
        }
        return null;
      })();
      return {
        hasBuiltIn: root.querySelector('pre code span.hljs-built_in') !== null,
        breakCount: root.querySelectorAll('br').length,
        linkFound: link !== null,
        // Anywhere in the reply, not only inside the anchor: the caption is the anchor's SIBLING
        // (DESIGN.md puts the host "after the link text"), so `link.querySelector` would miss it
        // and the recorded mutation below would stop reddening.
        captionCount: root.querySelectorAll('.ocu-reply-link-caption').length,
        linkRel: link?.getAttribute('rel') ?? null,
        linkTarget: link?.getAttribute('target'),
        // The VISIBLE half of AC1 and of the focus contract. jsdom computes no style, so a CSS-only
        // regression to any of this ships green everywhere else in the suite: the reply's classes
        // would all still be present and every other reply assertion would still pass.
        hostDisplay: getComputedStyle(root).display,
        keywordWeight: keyword === null ? null : getComputedStyle(keyword).fontWeight,
        codeWeight: plainCode === null ? null : getComputedStyle(plainCode).fontWeight,
        commentStyle: getComputedStyle(root.querySelector('pre code span.hljs-comment') ?? root).fontStyle,
        preBackground: pre === null ? null : getComputedStyle(pre).backgroundColor,
        codeSurface: (() => {
          const probe = document.createElement('span');
          probe.style.backgroundColor = 'var(--ocu-code-surface)';
          document.body.appendChild(probe);
          const value = getComputedStyle(probe).backgroundColor;
          probe.remove();
          return value;
        })(),
        focusRule,
        // The GFM table renders as its own literal source (D7), which is multi-line and carries
        // no `br`: without `ocu-reply-source`'s preserved whitespace it collapses to one line.
        sourceWhitespace: getComputedStyle(root.querySelector('.ocu-reply-source')).whiteSpace,
        sourceText: root.querySelector('.ocu-reply-source').textContent,
      };
    });
    assert.equal(shape.hasBuiltIn, true, 'expected span.hljs-built_in on UPPER, surviving both the parser and the real DOMPurify pass');
    assert.equal(shape.breakCount, 1, 'expected exactly one <br> to survive sanitizeReplyRoot for the two-line reply');
    assert.equal(shape.linkFound, true, 'expected the same-origin link to render as an <a>');
    assert.equal(shape.captionCount, 0, 'a same-origin link must carry no external-host caption anywhere in the reply');
    assert.equal(shape.linkRel, 'noopener noreferrer nofollow');
    assert.equal(shape.linkTarget, null, 'DOMPurify must strip any target attribute');
    // `app-reply` is an unknown element, so `display: inline` by default -- the block host the
    // transcript's paragraph rhythm depends on is one CSS line.
    assert.equal(shape.hostDisplay, 'block', 'the app-reply host renders as a block');
    // Release 1 highlighting is structural (Design Notes D3): weight and slant, no palette. The
    // keyword must be HEAVIER than the surrounding code, or the classes carry no visible meaning.
    assert.ok(
      Number(shape.keywordWeight) > Number(shape.codeWeight),
      `expected an hljs-keyword heavier than plain code, got ${shape.keywordWeight} against ${shape.codeWeight}`
    );
    assert.equal(shape.commentStyle, 'italic', 'expected hljs-comment to render slanted');
    assert.equal(shape.preBackground, shape.codeSurface, 'the fenced block sits on the --ocu-code-surface pair');
    // EXPERIENCE.md Component Patterns: the two-tone ring on every interactive element. A reply's
    // link is the transcript's first focusable element.
    assert.notEqual(shape.focusRule, null, 'the served stylesheet carries a :focus-visible rule for a reply link');
    assert.match(shape.focusRule.outline, /2px solid/, 'the focus ring is the 2px two-tone outline');
    assert.notEqual(shape.focusRule.boxShadow, '', 'the focus ring carries its inner tone as a box-shadow');
    assert.equal(shape.sourceWhitespace, 'pre-wrap', 'a construct rendered as literal source keeps its newlines and column padding');
    assert.ok(shape.sourceText.includes('\n'), `expected the table's own newlines in its text, got ${JSON.stringify(shape.sourceText)}`);
    assert.deepEqual(consoleErrors, [], `no console error or uncaught page error should occur, got: ${JSON.stringify(consoleErrors)}`);
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

test('(b) a remote image and a remote link produce zero requests to that host, and no img element', async () => {
  const tag = nextTag();
  setTag(tag);
  const remoteHost = '203.0.113.9';
  scriptReply(
    tag,
    0,
    markdownReply([`![a map](http://${remoteHost}/m.png)`, '', `[docs](https://${remoteHost}/p)`])
  );
  const { context, page } = await signedInAt(HOME_URL);
  const offOriginRequests = [];
  page.on('request', (request) => {
    const url = new URL(request.url());
    if (url.hostname === remoteHost) offOriginRequests.push(request.url());
  });
  try {
    await typeAndSend(page, 'show me the remote content');
    await page.waitForFunction(
      () => (document.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '') !== '',
      { timeout: config.navigationTimeoutMs }
    );
    const hasImg = await page.evaluate(() => document.querySelector('.ocu-panel-message-agent-text img') !== null);
    assert.equal(hasImg, false, 'no <img> element was created for the remote image');
    // The click is never made -- nothing here fires it -- so "no request until a click" (AC4)
    // needs only that the link exists and nothing has fetched it yet.
    const link = await page.evaluate(() => document.querySelector('.ocu-panel-message-agent-text a')?.getAttribute('href') ?? null);
    assert.equal(link, `https://${remoteHost}/p`);
    assert.deepEqual(offOriginRequests, [], 'no request left the origin for the remote host');
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

test('(c) the reply renders completely with every non-origin request aborted at the browser', async () => {
  const tag = nextTag();
  setTag(tag);
  scriptReply(
    tag,
    0,
    markdownReply(['A full reply.', '', '- one', '- two', '', '```json', '{"a":1}', '```'])
  );
  const { context, page } = await signedInAt(HOME_URL);
  await page.setRequestInterception(true);
  page.on('request', (request) => {
    const url = new URL(config.origin);
    if (new URL(request.url()).origin === url.origin) request.continue();
    else request.abort();
  });
  try {
    await typeAndSend(page, 'give me the full reply');
    await page.waitForSelector('.ocu-panel-message-agent-text pre > code.language-json', {
      timeout: config.navigationTimeoutMs,
    });
    const listItems = await page.evaluate(() => document.querySelectorAll('.ocu-panel-message-agent-text li').length);
    assert.equal(listItems, 2, 'the reply rendered completely with every non-origin request aborted');
  } finally {
    await context.close();
    forgetTag(tag);
  }
});

test('(d) the Content-Security-Policy refuses a remote fetch and a remote image, rather than merely going unexercised', async () => {
  const { context, page } = await signedInAt(HOME_URL);
  const remoteHost = '203.0.113.9';
  // `page.on('request')` is not proof of a refusal: verified in isolation (a minimal CSP page,
  // no throwaway involved) that Chrome's image loader still emits a CDP `requestWillBeSent` for
  // an img-src-blocked <img> before its CSP check finalizes, then fails the load with no bytes
  // ever returned -- `fetch()` blocked by connect-src, by contrast, never reaches the loader at
  // all and emits no request event. `response` is the authoritative signal for either case: it
  // fires only once bytes actually arrive from the far end, which CSP prevents regardless of
  // whether a loader-attempt event was queued first.
  const offOriginResponses = [];
  page.on('response', (response) => {
    if (new URL(response.url()).hostname === remoteHost) offOriginResponses.push(response.url());
  });
  const imageLoadFailures = [];
  page.on('requestfailed', (request) => {
    if (new URL(request.url()).hostname === remoteHost) imageLoadFailures.push(request.url());
  });
  try {
    const result = await page.evaluate(async () => {
      const violations = [];
      const onViolation = (event) => violations.push(event.violatedDirective);
      document.addEventListener('securitypolicyviolation', onViolation);
      let fetchRejected = false;
      try {
        await fetch('https://203.0.113.9/probe');
      } catch {
        fetchRejected = true;
      }
      await new Promise((resolve) => {
        const img = new Image();
        img.onerror = resolve;
        img.onload = resolve;
        img.src = 'https://203.0.113.9/probe.png';
        setTimeout(resolve, 2000);
      });
      // Let queued violation events land before this evaluate() resolves.
      await new Promise((resolve) => setTimeout(resolve, 250));
      document.removeEventListener('securitypolicyviolation', onViolation);
      return { fetchRejected, violations };
    });
    assert.equal(result.fetchRejected, true, 'a remote fetch must reject under connect-src \'self\'');
    assert.ok(result.violations.includes('connect-src'), `expected a connect-src violation among ${JSON.stringify(result.violations)}`);
    assert.ok(result.violations.includes('img-src'), `expected an img-src violation among ${JSON.stringify(result.violations)}`);
    assert.deepEqual(offOriginResponses, [], 'no response was ever received from the blocked host -- the browser refused both requests before any off-origin bytes returned');
    assert.ok(
      imageLoadFailures.includes(`https://${remoteHost}/probe.png`),
      `expected the image load itself to fail at the browser, among failures for: ${JSON.stringify(imageLoadFailures)}`
    );
  } finally {
    await context.close();
  }
});
