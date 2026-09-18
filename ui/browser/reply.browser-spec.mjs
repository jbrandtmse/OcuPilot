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
import { spawnSync } from 'node:child_process';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';

const config = browserConfig();

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
const TAG_PREFIX = 'replybrowser';

let browser = null;
let tagCounter = 0;
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
  removeDefinition('');
  priorDefault = markedDefault();
  preparedId = ensureDefinition(nextTag());
});

after(async () => {
  if (browser !== null) await browser.close();
  if (config.container === LIVE_CONTAINER) return;
  removeDefinition(priorDefault);
});

/** One `turnprobe` tag per test, so a stale script from an earlier test cannot answer a later one. */
function nextTag() {
  tagCounter += 1;
  return `${TAG_PREFIX}${tagCounter}`;
}

function escapeOs(value) {
  return String(value).replace(/"/g, '""');
}

/** Run ObjectScript lines inside the throwaway, in the install namespace, and answer stdout+stderr. */
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

/**
 * The id currently carrying the default marker, or `''`. Read through the marker convention
 * because `runIris` answers the whole IRIS session transcript: a bare `Write` yields the banner
 * and the prompts too, and that multi-line value embedded in the next script's string literal
 * breaks the script instead of failing loudly (DW-1075).
 */
function markedDefault() {
  const output = runIris([
    'Write "OCUREPLY-PRIOR-START:"_##class(OcuPilot.Test.TurnWireFixture).MarkedDefault()_":OCUREPLY-PRIOR-END",!',
  ]);
  const value = markerValue(output, 'OCUREPLY-PRIOR');
  assert.notEqual(value, null, `MarkedDefault answered: ${output}`);
  return value;
}

/**
 * Remove every probe definition and restore `prior` as the default marker, asserting that none
 * survived. A leftover enabled, default-marked definition is instance-wide state that changes
 * what later specs see -- `switches.browser-spec.mjs` reads the panel's read-only line on the
 * stated assumption that nothing is configured -- and a cleanup whose status nobody reads is how
 * that reaches them.
 */
function removeDefinition(prior) {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.TurnWireFixture).RemoveDefinition("${escapeOs(prior)}")`,
    'Write "OCUREPLY-RM-START:"_$System.Status.IsOK(sc)_":OCUREPLY-RM-END",!',
  ]);
  assert.equal(markerValue(output, 'OCUREPLY-RM'), '1', `RemoveDefinition succeeded: ${output}`);
}

/** Create (or repoint) the default `turnprobe` definition for `tag`, and answer its id. */
function ensureDefinition(tag) {
  const output = runIris([
    `Set sc=##class(OcuPilot.Test.TurnWireFixture).EnsureDefinition("${escapeOs(tag)}",.id)`,
    'Write "OCUREPLY-DEF-START:"_$System.Status.IsOK(sc)_"|"_id_":OCUREPLY-DEF-END",!',
  ]);
  const value = markerValue(output, 'OCUREPLY-DEF');
  assert.ok(value, `EnsureDefinition answered: ${output}`);
  const [ok, id] = value.split('|');
  assert.equal(ok, '1', `EnsureDefinition succeeded: ${output}`);
  return id;
}

/** Point the current definition at a fresh tag, so this test's scripts cannot answer another's turn. */
function setTag(tag) {
  const output = runIris([`Set sc=##class(OcuPilot.Test.TurnWireFixture).SetTag("${escapeOs(preparedId)}","${escapeOs(tag)}")`, 'Write "OCUREPLY-TAG-START:"_$System.Status.IsOK(sc)_":OCUREPLY-TAG-END",!']);
  assert.equal(markerValue(output, 'OCUREPLY-TAG'), '1', `SetTag succeeded: ${output}`);
}

/** Script one scripted reply for `tag`: `hangSeconds` before answering, then `bodyExpr` (ObjectScript). */
function scriptReply(tag, hangSeconds, bodyExpr) {
  const output = runIris([`Do ##class(OcuPilot.Test.TurnProvider).Script("${escapeOs(tag)}",${hangSeconds},${bodyExpr})`, 'Write "OCUREPLY-SCRIPT-START:ok:OCUREPLY-SCRIPT-END",!']);
  assert.ok(markerValue(output, 'OCUREPLY-SCRIPT'), `Script recorded: ${output}`);
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
  runIris([`Do ##class(OcuPilot.Test.TurnProvider).Forget("${escapeOs(tag)}")`]);
}

/** A fresh context signed in as the configured user, standing on `url` with the frame laid out. */
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
