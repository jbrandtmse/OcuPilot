/**
 * Story 20.13 in a real browser, against the throwaway: the vendor's three interoperability editors
 * (rule, DTL and BPL) load in a same-origin frame inside the signed-in shell and sign themselves in
 * from the browser-level login, with an empty-body login, no password, no token of OcuPilot's and no
 * message (AD-63; AC1 and AC2), and OcuPilot's own Sign out ends their sign-in (AC3).
 *
 * **The frame is the shipped builder's, mounted by the harness.** No screen embeds an editor in this
 * story (Story 20.7 builds them), so each test mounts an `<iframe>` inside `app-screen-outlet`, the
 * host the routed screens draw into, with `src` from the shipped `interopEditorSource` and the
 * editor's title: no `sandbox`, no `allow`, no listener. Only its size is set, through the DOM's
 * style object, so the editor lays out as it does on a screen. The Angular component that will draw
 * it is pinned by `interop-editor-frame.spec.ts`; it first runs in a browser in Story 20.7.
 *
 * **Each frame names a document the test never creates** (`OcuPilotProbe.EditorFrame<Editor>`), so
 * the editor's read of it is observable without depending on a class this spec made. The editor
 * answers 404 for it, which is the document's absence and not a sign-in failure.
 *
 * Each test signs in in its own context and writes nothing to the instance beyond the reset every
 * context makes. `before` refuses the live container and an instance that is not installed.
 *
 * Run: `npm run build`, `docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=<origin> OCUPILOT_BROWSER_CONTAINER=<container> \
 *   node --test --test-concurrency=1 browser/interop-editor-frame.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import {
  DEFAULT_FRAME_SELECTOR,
  armMessageCounters,
  assertSignOutEndsEditors,
  assertSignedInSilently,
  editorSessionControls,
  signOutThroughMenu,
  tabSnapshot,
  until,
  waitForEditorTokens,
  watchEditorTraffic,
  watchPolicyViolations,
} from './interop-editor-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { signedInAt } from './panel-spec.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { interopEditorSource } = await import(join(uiRoot, 'src', 'app', 'core', 'vendor-frame.ts'));

const config = browserConfig();
const STRINGS = loadStrings();

const NAMESPACE = 'HSCUSTOM';
const START_URL = `/ocupilot/?ns=${NAMESPACE}`;

const EDITORS = [
  { editor: 'rule-editor', documentName: 'OcuPilotProbe.EditorFrameRule', title: STRINGS.interopRuleEditorTitle },
  { editor: 'dtl-editor', documentName: 'OcuPilotProbe.EditorFrameDtl', title: STRINGS.interopDtlEditorTitle },
  { editor: 'bpl-editor', documentName: 'OcuPilotProbe.EditorFrameBpl', title: STRINGS.interopBplEditorTitle },
];

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec signs browser sessions in and out, so it never runs against the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser === null) return;
  await browser.close();
  browser = null;
});

/**
 * A fresh context signed in at the shell's start screen with its navigation map answered: the
 * observers armed, the tab's keys recorded, and nothing of an editor mounted yet.
 */
async function shellWithObservers() {
  const { context, page } = await signedInAt(browser, config, START_URL);
  await waitForMapAnswered(page, config.navigationTimeoutMs);
  const before = await tabSnapshot(page);
  return {
    context,
    page,
    before,
    traffic: watchEditorTraffic(page),
    violations: watchPolicyViolations(page),
    messages: await armMessageCounters(page),
  };
}

/** Mount the editor's frame in the routed screens' host, from the shipped builder and nothing else. */
async function mountEditorFrame(page, editor, documentName, title) {
  const source = interopEditorSource(editor, NAMESPACE, documentName);
  assert.notEqual(source, null, `the builder answers for ${editor} and ${documentName}`);
  await page.evaluate(
    (address, name) => {
      const frame = document.createElement('iframe');
      frame.setAttribute('title', name);
      frame.setAttribute('src', address);
      frame.style.width = '100%';
      frame.style.height = '600px';
      document.querySelector('app-screen-outlet').appendChild(frame);
    },
    source,
    title
  );
  return source;
}

// Mutation (Rule 19): `interopEditorSource` appends `&VSCODE=1` (bundle rebuilt and redeployed) -> the editor
// skips its login and sets `vscodeMode`, so the login wait and the normal-mode assertions go red.
// Mutation (Rule 19): `Session` writes `Rule_Editor-0-accessToken` to sessionStorage after sign-in -> the
// before-mount keys assertion goes red.
test('AC1, AC2: each editor signs itself in from the browser-level login, in normal mode, reading and storing nothing of OcuPilot\'s', async (t) => {
  for (const { editor, documentName, title } of EDITORS) {
    await t.test(editor, async () => {
      const { context, page, before, traffic, violations, messages } = await shellWithObservers();
      try {
        const source = await mountEditorFrame(page, editor, documentName, title);
        assert.equal(await page.$eval(DEFAULT_FRAME_SELECTOR, (node) => node.getAttribute('src')), source, 'the frame carries the builder\'s address');
        assert.deepEqual(await page.$$eval(DEFAULT_FRAME_SELECTOR, (nodes) => nodes[0].getAttributeNames().sort()), ['src', 'style', 'title'], 'and no attribute that loosens it');

        await assertSignedInSilently({ page, config, editor, namespace: NAMESPACE, documentName, traffic, messages, violations, before });

        // The counter counts: a message to the shell and one to the frame are both recorded.
        const frame = await (await page.$(DEFAULT_FRAME_SELECTOR)).contentFrame();
        await frame.evaluate(() => window.postMessage('control', '*'));
        await page.evaluate(() => window.postMessage('control', '*'));
        const seen = await until(() => messages.seen(), (list) => list.length >= 2, 'the message counters record a message in each window', config.navigationTimeoutMs);
        assert.equal(new Set(seen.map((entry) => entry.in)).size, 2, 'in two different windows');

        // The policy watcher counts too: a request the shell's policy refuses is reported to it.
        await page.evaluate(() => fetch('https://policy-control.invalid/').catch(() => null));
        await until(() => violations.length, (count) => count >= 1, 'the policy watcher reports a request the policy refuses', config.navigationTimeoutMs);
      } finally {
        await context.close();
      }
    });
  }
});

// Mutation (Rule 19): `Session.signOut()` posts `/logout` with `credentials: 'omit'` (bundle rebuilt and
// redeployed) -> the browser-level login survives and the empty-body editors login answers 200, so this goes red.
test('AC3: Sign out in the account menu ends the editor\'s sign-in: no frame, no editor key, and its login, access token and refresh token are refused', async () => {
  const { context, page, traffic } = await shellWithObservers();
  try {
    const { editor, documentName, title } = EDITORS[1];
    await mountEditorFrame(page, editor, documentName, title);
    const held = await waitForEditorTokens(page, editor, config.navigationTimeoutMs);
    await until(() => traffic.filter((entry) => entry.path === '/api/interop-editors/login'), (entries) => entries.some((entry) => entry.status === 200), 'the editor signed in', config.navigationTimeoutMs);
    assert.equal((await page.$$('iframe')).length, 1, 'one editor frame is mounted before the sign-out');
    assert.ok(held.accessToken.length > 16 && held.refreshToken.length > 16, 'and the spec holds the editor\'s access and refresh tokens');

    await editorSessionControls(page, held);
    await signOutThroughMenu(page, config.navigationTimeoutMs);
    await assertSignOutEndsEditors(page, held);
  } finally {
    await context.close();
  }
});
