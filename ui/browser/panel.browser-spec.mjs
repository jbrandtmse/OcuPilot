/**
 * The docked panel in a real browser against the throwaway instance (Story 4.3): its geometry at
 * every width DESIGN.md's Yield order names, the resize handle by pointer and by keyboard, the
 * remembered width across navigation and reload, full screen, Ctrl/Cmd+I, and the 640px content
 * minimum measured at the narrowest supported viewport.
 *
 * jsdom computes no layout and has no pointer, focus order or reload, so each of these is only
 * observable here. Every test opens its own browser context, so a width one test stores is never
 * another's starting point, and the stored preference dies with the context.
 *
 * It refuses the live container. The draft test enables a probe definition (created over the
 * shipped route, flagged through `OcuPilot.Test.AgentFixture.SetFlags` inside the container) and
 * removes it, so the specs after it still meet an instance with nothing enabled.
 *
 * Run: `npm run test:browser` (after `npm run build`, the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { leaveFirstLoginGate, pathOf } from './shell-entry.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const USERS_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';
const FORM_URL = '/ocupilot/agent/definitions/edit?ns=HSCUSTOM';
const DEFINITIONS_PATH = '/api/ocupilot/agent/definitions';
const PREFIX = 'OcuPilotPanelProbe';

let browser = null;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec enables a definition, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  await removeProbeDefinitions();
  assert.equal(await enabledCount(), 0, 'the throwaway starts with no enabled definition, which is the state every assertion here is about');
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  try {
    // `before` refused the live container; nothing was created there, and nothing is removed.
    if (config.container !== LIVE_CONTAINER) {
      // DW-1048: removed BEFORE the browser closes, and the result asserted. Closing the browser
      // first means a failure here is reported after the run's last hook has already torn down,
      // where node:test attributes it to nothing; and an enabled row this file leaves behind turns
      // `leaveFirstLoginGate` into a no-op for every spec file that sorts after it, surfacing as an
      // unrelated assertion in a file that did nothing wrong. `before` asserts zero enabled, so
      // anything enabled here appeared during this file's own run.
      await removeProbeDefinitions();
      assert.equal(await enabledCount(), 0, 'this spec leaves the instance with no enabled definition');
    }
  } finally {
    // In the `finally` so a failed postcondition reports itself AND still closes Chrome; ordering
    // the two the other way traded a leaked definition for a leaked browser.
    if (browser !== null) await browser.close();
  }
});

function authHeader() {
  return 'Basic ' + Buffer.from(`${config.username}:${config.password}`).toString('base64');
}

async function definitions() {
  const answer = await fetch(`${config.origin}${DEFINITIONS_PATH}`, { headers: { Authorization: authHeader() } });
  assert.ok(answer.ok, `the definitions list is readable (HTTP ${answer.status})`);
  const body = await answer.json();
  assert.ok(Array.isArray(body.definitions), `and projects a definitions array: ${JSON.stringify(body)}`);
  return body.definitions;
}

/** How many definitions this instance currently has enabled -- the state the panel renders on. */
async function enabledCount() {
  return (await definitions()).filter((row) => row.enabled === true).length;
}

async function removeProbeDefinitions() {
  for (const row of await definitions()) {
    if (typeof row?.name !== 'string' || !row.name.startsWith(PREFIX)) continue;
    const gone = await fetch(`${config.origin}${DEFINITIONS_PATH}/${encodeURIComponent(row.id)}`, {
      method: 'DELETE',
      headers: { Authorization: authHeader() },
    });
    assert.ok(gone.ok, `the probe definition ${row.name} is removed (HTTP ${gone.status})`);
  }
}

/** Create a probe definition over the shipped route and mark it enabled and verified in the container. */
async function enabledProbeDefinition() {
  const created = await fetch(`${config.origin}${DEFINITIONS_PATH}`, {
    method: 'POST',
    headers: { Authorization: authHeader(), 'Content-Type': 'application/json' },
    body: JSON.stringify({ name: `${PREFIX}Draft`, provider: 'anthropic', credType: 'creds', credentialName: 'OcuPilotAnthropic' }),
  });
  assert.equal(created.status, 201, `the probe definition is created (HTTP ${created.status})`);
  const id = String((await created.json()).id);
  assert.match(id, /^[A-Za-z0-9._-]+$/, `the definition id is a bare identifier: ${id}`);
  const lines = [
    'Set $NAMESPACE=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")',
    `Set tSC=##class(OcuPilot.Test.AgentFixture).SetFlags("${id}",1,1)`,
    'Write "OCU"_"-ENABLED-START:"_$System.Status.IsOK(tSC)_":OCU"_"-ENABLED-END",!',
    'Halt',
  ];
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input: `${lines.join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  assert.equal(/OCU-ENABLED-START:(.*?):OCU-ENABLED-END/.exec(output)?.[1], '1', `the fixture enabled the row: ${output}`);
}

/** A fresh context signed in through the form, standing on `url` with the frame and the panel laid out. */
async function signedInAt(url, viewport = config.viewport) {
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.setViewport(viewport);
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-panel aside.ocu-panel', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, url);
  await page.waitForSelector('app-panel [role="separator"]', { timeout: config.navigationTimeoutMs });
  return { context, page };
}

/**
 * Wait until the panel is on screen with a composer that is not `aria-disabled` -- the surface the
 * caller goes on to type into -- and name what was actually rendered when it does not arrive.
 *
 * The two waits this replaced each covered half the condition: one waited on the composer's
 * `aria-disabled` without first waiting for the panel (so a remount that had not yet rendered a
 * composer read as "no such element" rather than as "not yet"), and the other waited for the
 * element alone and then read a composer the panel still had disabled. Both failed as a bare
 * 30-second timeout naming neither the sign-in form, the instance notice, nor the path.
 */
async function composerReady(page) {
  try {
    await page.waitForFunction(
      () => {
        if (document.querySelector('app-panel aside.ocu-panel') === null) return false;
        const composer = document.querySelector('#ocu-panel-composer');
        return composer !== null && !composer.hasAttribute('aria-disabled');
      },
      { timeout: config.navigationTimeoutMs }
    );
  } catch (err) {
    const state = await page.evaluate(() => ({
      surface: document.querySelector('app-sign-in') !== null
        ? 'app-sign-in'
        : document.querySelector('app-instance-notice') !== null
          ? 'app-instance-notice'
          : document.querySelector('app-panel') !== null
            ? 'app-panel'
            : 'none of app-sign-in, app-instance-notice or app-panel',
      composer: document.querySelector('#ocu-panel-composer') === null
        ? 'absent'
        : document.querySelector('#ocu-panel-composer').hasAttribute('aria-disabled')
          ? 'present and aria-disabled'
          : 'present and enabled',
      path: window.location.pathname + window.location.search,
    }));
    throw new Error(
      `expected the panel with an enabled composer; the surface on screen was ${state.surface}, ` +
        `the composer was ${state.composer}, and the path was ${state.path}` +
        ` (underlying: ${err.message})`
    );
  }
}

/** The row's measured geometry: side bar, content region, its floor, the routed screen's `main`, the panel, and the page's own scroll. */
function geometry(page) {
  return page.evaluate(() => {
    const box = (selector) => {
      const node = document.querySelector(selector);
      return node === null ? null : node.getBoundingClientRect();
    };
    const content = document.querySelector('.ocu-shell-content');
    const main = document.querySelector('main.ocu-content');
    const panel = box('app-panel aside.ocu-panel');
    const handle = document.querySelector('app-panel [role="separator"]');
    return {
      viewport: document.documentElement.clientWidth,
      sideBar: box('app-side-bar nav.ocu-side-bar')?.width ?? 0,
      contentWidth: content.getBoundingClientRect().width,
      contentClientWidth: content.clientWidth,
      contentScrollWidth: content.scrollWidth,
      floorWidth: box('.ocu-shell-content-floor').width,
      mainClientWidth: main.clientWidth,
      mainScrollWidth: main.scrollWidth,
      panelWidth: panel.width,
      panelLeft: panel.left,
      panelRight: panel.right,
      pageScrollWidth: document.scrollingElement.scrollWidth,
      pageClientWidth: document.scrollingElement.clientWidth,
      valueNow: handle === null ? null : Number(handle.getAttribute('aria-valuenow')),
      valueMax: handle === null ? null : Number(handle.getAttribute('aria-valuemax')),
      atStop: handle === null ? null : handle.classList.contains('ocu-panel-resize-handle-at-stop'),
    };
  });
}

/** Wait for the panel's width transition to settle at `width`. */
async function panelSettlesAt(page, width) {
  await page.waitForFunction(
    (wanted) => Math.abs(document.querySelector('app-panel aside.ocu-panel').getBoundingClientRect().width - wanted) < 0.01,
    { timeout: config.navigationTimeoutMs },
    width
  );
}

async function pressOnHandle(page, key, times) {
  await page.focus('app-panel [role="separator"]');
  for (let count = 0; count < times; count += 1) await page.keyboard.press(key);
}

async function chord(page, key) {
  await page.keyboard.down('Control');
  await page.keyboard.press(key);
  await page.keyboard.up('Control');
}

test('AC1: docked right at 400 on a list route, content reflowing beside it, and no close control', async () => {
  const { context, page } = await signedInAt(USERS_URL);
  try {
    const shown = await geometry(page);
    assert.equal(Math.round(shown.panelRight), shown.viewport, 'docked to the right edge');
    assert.equal(Math.round(shown.panelWidth), 400, 'at the default width');
    assert.equal(Math.round(shown.contentWidth), shown.viewport - 48 - 240 - 400, 'content takes the remaining width');
    assert.equal(shown.pageScrollWidth, shown.pageClientWidth, 'the page body does not scroll horizontally');
    const buttons = await page.$$eval('app-panel aside.ocu-panel button', (nodes) =>
      nodes.map((node) => node.getAttribute('aria-label') ?? node.textContent.trim())
    );
    assert.deepEqual(
      buttons,
      [STRINGS.actionNewConversation, STRINGS.agentPanelFullScreen, STRINGS.actionSend],
      'no close control'
    );
  } finally {
    await context.close();
  }
});

test('AC3: the handle resizes by keyboard and pointer between 320 and the 640px content point, the grip restrained at both stops; the side bar has no sash', async () => {
  // Mutation (Rule 19): clamp `applyWidth` to `Number.MAX_SAFE_INTEGER` instead of `panelMax` ->
  // the drag-past-the-stop assertion goes red.
  const { context, page } = await signedInAt(USERS_URL);
  try {
    await pressOnHandle(page, 'ArrowLeft', 2);
    await panelSettlesAt(page, 432);
    let shown = await geometry(page);
    assert.equal(shown.valueNow, 432, 'Left widens by 16px a press');
    assert.equal(shown.atStop, false);
    assert.equal(await page.evaluate(() => localStorage.getItem('ocupilot.panel.width')), '432', 'the stored width updates');

    // Drag the edge far past the maximum, then far past the minimum.
    const edge = await page.$eval('app-panel [role="separator"]', (node) => {
      const rect = node.getBoundingClientRect();
      return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
    });
    await page.mouse.move(edge.x, edge.y);
    await page.mouse.down();
    await page.mouse.move(edge.x - 2000, edge.y, { steps: 8 });
    shown = await geometry(page);
    const max = shown.viewport - 48 - 240 - 640;
    assert.equal(shown.valueMax, max, 'the maximum is the width that leaves content at 640 beside the open side bar');
    assert.equal(shown.valueNow, max, 'dragging past the stop holds at it');
    assert.equal(shown.atStop, true, 'and the grip is restrained there');
    await page.mouse.move(edge.x + 2000, edge.y, { steps: 8 });
    await page.mouse.up();
    await panelSettlesAt(page, 320);
    shown = await geometry(page);
    assert.equal(shown.valueNow, 320, 'never below the minimum');
    assert.equal(shown.atStop, true, 'restrained at the minimum as well');
    assert.equal(await page.evaluate(() => localStorage.getItem('ocupilot.panel.width')), '320');

    const cursor = await page.$eval('app-panel [role="separator"]', (node) => getComputedStyle(node).cursor);
    assert.equal(cursor, 'col-resize');
    const sideBarSash = await page.evaluate(() => {
      const nodes = [...document.querySelectorAll('app-side-bar, app-side-bar *')];
      return nodes.filter((node) => getComputedStyle(node).cursor === 'col-resize' || node.getAttribute('role') === 'separator').length;
    });
    assert.equal(sideBarSash, 0, 'the side bar carries no sash, grip or resize cursor');
  } finally {
    await context.close();
  }
});

test('AC2: the same panel element, draft and width survive navigation, and the width survives a reload', async () => {
  // Mutation (Rule 19): make `PreferenceStore.setPanelWidth` write nothing -> this goes red on the
  // width after the reload.
  // DW-1048: both inside the try, with the context hoisted, so a throw between creating the probe
  // definition and signing in still reaches the `finally` that removes it. Left outside, a failed
  // sign-in leaked an enabled definition that made `leaveFirstLoginGate` a no-op for every spec
  // file after this one.
  let context = null;
  let page = null;
  try {
    await enabledProbeDefinition();
    ({ context, page } = await signedInAt(USERS_URL));
    await composerReady(page);
    await page.type('#ocu-panel-composer', 'Why is /csp/myapp disabled?');
    await pressOnHandle(page, 'ArrowLeft', 3);
    await panelSettlesAt(page, 448);
    await page.evaluate(() => {
      window.ocuPanelBefore = document.querySelector('app-panel aside.ocu-panel');
    });

    // A client-side route change: the rail opens the Agent co-pilot side bar, and its Definitions entry navigates.
    const before = pathOf(page);
    await page.click(`.ocu-rail-item[aria-label="${STRINGS.navAreaAgent}"]`);
    await page.waitForFunction(
      (label) =>
        [...document.querySelectorAll('app-side-bar .ocu-side-bar-label')].some((node) => node.textContent.trim() === label),
      { timeout: config.navigationTimeoutMs },
      STRINGS.agentDefinitionListLabel
    );
    await page.evaluate((label) => {
      const entry = [...document.querySelectorAll('app-side-bar .ocu-side-bar-item')].find(
        (node) => node.querySelector('.ocu-side-bar-label')?.textContent?.trim() === label
      );
      entry.click();
    }, STRINGS.agentDefinitionListLabel);
    await page.waitForFunction((was) => window.location.pathname !== was, { timeout: config.navigationTimeoutMs }, before);
    const after = await page.evaluate(() => ({
      same: window.ocuPanelBefore === document.querySelector('app-panel aside.ocu-panel'),
      draft: document.querySelector('#ocu-panel-composer').value,
      width: Math.round(document.querySelector('app-panel aside.ocu-panel').getBoundingClientRect().width),
    }));
    assert.notEqual(pathOf(page), before, 'the route changed');
    assert.equal(after.same, true, 'the same panel element is on screen');
    assert.equal(after.draft, 'Why is /csp/myapp disabled?', 'the draft is kept');
    assert.equal(after.width, 448, 'and the width');

    await page.reload({ waitUntil: 'networkidle2' });
    await page.waitForSelector('app-panel aside.ocu-panel', { timeout: config.navigationTimeoutMs });
    await panelSettlesAt(page, 448);
  } finally {
    if (context !== null) await context.close();
    await removeProbeDefinitions();
  }
});

test('AC4: full screen covers the side bar and content, marks them inert, and restores the same width', async () => {
  // Mutation (Rule 19): drop the `[attr.inert]` binding from `.ocu-shell-content` -> this goes red.
  const { context, page } = await signedInAt(USERS_URL);
  try {
    await pressOnHandle(page, 'ArrowRight', 2);
    await panelSettlesAt(page, 368);
    await page.click('.ocu-panel-full-screen-toggle');
    await page.waitForFunction(() => document.querySelector('.ocu-shell-content').hasAttribute('inert'), {
      timeout: config.navigationTimeoutMs,
    });
    const full = await page.evaluate(() => ({
      expanded: document.querySelector('.ocu-panel-full-screen-toggle').getAttribute('aria-expanded'),
      sideBarInert: document.querySelector('app-side-bar').hasAttribute('inert'),
      contentInert: document.querySelector('.ocu-shell-content').hasAttribute('inert'),
      panel: document.querySelector('app-panel aside.ocu-panel').getBoundingClientRect().toJSON(),
      rail: document.querySelector('app-rail').getBoundingClientRect().toJSON(),
      header: document.querySelector('app-header').getBoundingClientRect().toJSON(),
      statusBar: document.querySelector('app-status-bar').getBoundingClientRect().toJSON(),
      viewport: document.documentElement.clientWidth,
    }));
    assert.equal(full.expanded, 'true');
    assert.equal(full.sideBarInert, true);
    assert.equal(full.contentInert, true);
    assert.equal(Math.round(full.panel.left), Math.round(full.rail.right), 'the panel starts where the rail ends');
    assert.equal(Math.round(full.panel.right), full.viewport);
    assert.equal(Math.round(full.panel.top), Math.round(full.header.bottom), 'below the header');
    assert.equal(Math.round(full.panel.bottom), Math.round(full.statusBar.top), 'above the status bar');

    await page.click('.ocu-panel-full-screen-toggle');
    await panelSettlesAt(page, 368);
    const restored = await page.evaluate(() => ({
      expanded: document.querySelector('.ocu-panel-full-screen-toggle').getAttribute('aria-expanded'),
      inert: document.querySelector('app-side-bar').hasAttribute('inert') || document.querySelector('.ocu-shell-content').hasAttribute('inert'),
    }));
    assert.deepEqual(restored, { expanded: 'false', inert: false });
  } finally {
    await context.close();
  }
});

test('Full screen: Escape, the skip link and Ctrl/Cmd+B leave the covered side bar and focus untouched (QA)', async () => {
  // Mutation (Rule 19, QA): drop the `fullScreen()` branch from `App.onEscape` -> the first Escape
  // closes the covered side bar and this goes red; drop the `fullScreen()` guard from
  // `SideBar.onGlobalKeydown` -> the chord closes the covered bar and the restored assertion goes red.
  // The skip-link leg stays green without `App.onSkipToContent`'s guard, because the browser refuses
  // focus into inert content anyway; that guard is pinned in `app.spec.ts`.
  const { context, page } = await signedInAt(USERS_URL);
  try {
    await page.waitForSelector('app-side-bar nav.ocu-side-bar', { timeout: config.navigationTimeoutMs });
    const toggle = await page.$('.ocu-panel-full-screen-toggle');
    await toggle.click();
    await page.waitForFunction(() => document.querySelector('.ocu-shell-content').hasAttribute('inert'), {
      timeout: config.navigationTimeoutMs,
    });
    await toggle.focus();

    await page.keyboard.press('Escape');
    let onToggle = await page.evaluate(() => document.activeElement?.classList.contains('ocu-panel-full-screen-toggle'));
    assert.equal(onToggle, true, 'the first Escape leaves focus on the toggle rather than moving it into inert content');
    let barPresent = await page.evaluate(() => document.querySelector('app-side-bar nav.ocu-side-bar') !== null);
    assert.equal(barPresent, true, 'the covered side bar is not collapsed by Escape');

    await page.keyboard.press('Escape');
    onToggle = await page.evaluate(() => document.activeElement?.classList.contains('ocu-panel-full-screen-toggle'));
    assert.equal(onToggle, true, 'a second Escape does nothing new either');

    // A synthetic `.click()` rather than a pointer click: the link is clip-path-hidden until
    // focused, and `App.onSkipToContent`'s guard is what this leg is about, not hit-testing.
    await page.evaluate(() => document.querySelector('.ocu-skip-link').click());
    onToggle = await page.evaluate(() => document.activeElement?.classList.contains('ocu-panel-full-screen-toggle'));
    assert.equal(onToggle, true, 'the skip link does not move focus into inert content while full screen');

    await page.focus('.ocu-panel-full-screen-toggle');
    await chord(page, 'KeyB');
    await new Promise((resolve) => setTimeout(resolve, 200));
    const stillFull = await page.evaluate(() => document.querySelector('.ocu-shell-content').hasAttribute('inert'));
    assert.equal(stillFull, true, 'still full screen: Ctrl/Cmd+B did not toggle the covered bar');

    await toggle.click();
    await page.waitForFunction(() => !document.querySelector('.ocu-shell-content').hasAttribute('inert'), {
      timeout: config.navigationTimeoutMs,
    });
    barPresent = await page.evaluate(() => document.querySelector('app-side-bar nav.ocu-side-bar') !== null);
    assert.equal(barPresent, true, 'restored: the side bar the chord left alone is still open');
  } finally {
    await context.close();
  }
});

test('Signing out clears the panel draft and full screen; the next sign-in starts fresh (QA)', async () => {
  // Mutation (Rule 19, QA): delete `this.panel.endSession()` from `App.verifyWhenSignedIn` -> the
  // draft and full-screen assertions after the second sign-in go red.
  // DW-1048: both inside the try, with the context hoisted, so a throw between creating the probe
  // definition and signing in still reaches the `finally` that removes it. Left outside, a failed
  // sign-in leaked an enabled definition that made `leaveFirstLoginGate` a no-op for every spec
  // file after this one.
  let context = null;
  let page = null;
  try {
    await enabledProbeDefinition();
    ({ context, page } = await signedInAt(USERS_URL));
    await composerReady(page);
    await page.type('#ocu-panel-composer', 'Draft before sign-out');
    await page.click('.ocu-panel-full-screen-toggle');
    await page.waitForFunction(() => document.querySelector('.ocu-shell-content').hasAttribute('inert'), {
      timeout: config.navigationTimeoutMs,
    });

    // Real pointer clicks: the menu opens upward out of the status bar, so a band that clips it
    // leaves Sign out unreachable. Mutation (Rule 19): `overflow: hidden` on `.ocu-status-bar` ->
    // the hit test below goes red.
    await page.click('#ocu-account-trigger');
    await page.waitForSelector('[role="menuitem"]', { visible: true, timeout: config.navigationTimeoutMs });
    // Sign out by NAME, not by position: Story 15.1 put Change password above it, and a menu that
    // grows again (15.6's theme toggle) must not silently turn this into a click on something else.
    const signOut = await page.evaluate((label) => {
      const item = [...document.querySelectorAll('[role="menuitem"]')].find(
        (candidate) => candidate.textContent.trim() === label
      );
      if (item === undefined) return null;
      const box = item.getBoundingClientRect();
      item.id = 'ocu-probe-sign-out';
      return {
        hit: item.contains(document.elementFromPoint(box.left + box.width / 2, box.top + box.height / 2)),
      };
    }, STRINGS.actionSignOut);
    assert.notEqual(signOut, null, 'the account menu lists Sign out');
    assert.equal(signOut.hit, true, 'the account menu item is the element under the pointer, not clipped by the status bar');
    await page.click('#ocu-probe-sign-out');
    await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });

    await page.type('#ocu-signin-user', config.username);
    await page.type('#ocu-signin-password', config.password);
    await page.click('.ocu-signin-card button[type="submit"]');
    await page.waitForSelector('app-panel aside.ocu-panel', { timeout: config.navigationTimeoutMs });
    await leaveFirstLoginGate(page, config.navigationTimeoutMs, USERS_URL);
    // DW-1048: the gate's own navigation remounts the frame, and the panel with it -- an evaluate
    // that ran the instant `leaveFirstLoginGate` resolved could still find the composer the OLD
    // frame rendered, gone by the time the query ran. Wait for the new frame's own panel and its
    // enabled composer, which is the surface the assertions below read.
    await composerReady(page);

    const after = await page.evaluate(() => ({
      draft: document.querySelector('#ocu-panel-composer').value,
      expanded: document.querySelector('.ocu-panel-full-screen-toggle').getAttribute('aria-expanded'),
      inert: document.querySelector('.ocu-shell-content').hasAttribute('inert'),
    }));
    assert.equal(after.draft, '', 'the draft does not survive sign-out');
    assert.equal(after.expanded, 'false', 'full screen does not survive sign-out');
    assert.equal(after.inert, false, 'content is no longer inert once full screen is cleared');
  } finally {
    if (context !== null) await context.close();
    await removeProbeDefinitions();
  }
});

test('The composer grows with its text to four lines and then scrolls, the footer staying in the panel', async () => {
  // Mutation (Rule 19): drop `field-sizing: content` from `.ocu-panel-composer` -> the two-line height
  // assertion goes red.
  // DW-1048: both inside the try, with the context hoisted, so a throw between creating the probe
  // definition and signing in still reaches the `finally` that removes it. Left outside, a failed
  // sign-in leaked an enabled definition that made `leaveFirstLoginGate` a no-op for every spec
  // file after this one.
  let context = null;
  let page = null;
  try {
    await enabledProbeDefinition();
    ({ context, page } = await signedInAt(USERS_URL));
    await composerReady(page);
    const height = () => page.evaluate(() => document.querySelector('#ocu-panel-composer').getBoundingClientRect().height);
    const one = await height();
    await page.type('#ocu-panel-composer', 'first');
    await page.keyboard.down('Shift');
    await page.keyboard.press('Enter');
    await page.keyboard.up('Shift');
    await page.type('#ocu-panel-composer', 'second');
    const two = await height();
    assert.ok(two > one, `two lines are taller than one (${one} -> ${two})`);
    for (let line = 3; line <= 8; line += 1) {
      await page.keyboard.down('Shift');
      await page.keyboard.press('Enter');
      await page.keyboard.up('Shift');
      await page.type('#ocu-panel-composer', `line ${line}`);
    }
    const shown = await page.evaluate(() => {
      const composer = document.querySelector('#ocu-panel-composer');
      const lineHeight = parseFloat(getComputedStyle(composer).lineHeight);
      const panel = document.querySelector('app-panel aside.ocu-panel').getBoundingClientRect();
      const footer = document.querySelector('.ocu-panel-footer').getBoundingClientRect();
      return { height: composer.getBoundingClientRect().height, lineHeight, scrolls: composer.scrollHeight > composer.clientHeight, footerBottom: footer.bottom, panelBottom: panel.bottom };
    });
    assert.ok(shown.height < 5 * shown.lineHeight + 24, `eight lines stop at four (${shown.height}px, line ${shown.lineHeight}px)`);
    assert.equal(shown.scrolls, true, 'past four lines the composer scrolls');
    assert.ok(shown.footerBottom <= shown.panelBottom + 0.5, 'the footer stays inside the panel');
  } finally {
    if (context !== null) await context.close();
    await removeProbeDefinitions();
  }
});

test('AC6: Ctrl/Cmd+I focuses the composer from content, side bar and rail, and not while the command box is open', async () => {
  // Mutation (Rule 19): drop `composer.focus()` from `App.onComposerChord` -> this goes red.
  const { context, page } = await signedInAt(USERS_URL);
  try {
    const active = () => page.evaluate(() => document.activeElement?.id ?? '');
    await page.focus('main#ocu-content');
    await chord(page, 'KeyI');
    assert.equal(await active(), 'ocu-panel-composer', 'from content');
    await page.focus('app-side-bar .ocu-side-bar-item');
    await chord(page, 'KeyI');
    assert.equal(await active(), 'ocu-panel-composer', 'from the side bar');
    await page.focus('.ocu-rail-item');
    await chord(page, 'KeyI');
    assert.equal(await active(), 'ocu-panel-composer', 'from the rail, while Send is aria-disabled');

    await page.focus('main#ocu-content');
    await chord(page, 'KeyK');
    await page.waitForFunction(
      () => document.querySelector('[role="combobox"][aria-expanded="true"]') !== null,
      { timeout: config.navigationTimeoutMs }
    );
    await chord(page, 'KeyI');
    assert.notEqual(await active(), 'ocu-panel-composer', 'the chord is ignored while the command box is open');
  } finally {
    await context.close();
  }
});

test('Yield order at 1,920, 1,280 (and reopened), 1,024 and 900px; the page body never scrolls horizontally', async () => {
  // Mutation (Rule 19): make `resolveLayout` never collapse the side bar -> the 1,280 row goes red.
  const { context, page } = await signedInAt(USERS_URL, { width: 1920, height: 900 });
  try {
    const measured = [];
    const at = async (width) => {
      await page.setViewport({ width, height: 900 });
      await page.waitForFunction((w) => document.documentElement.clientWidth === w, {}, width);
      await new Promise((resolve) => setTimeout(resolve, 250));
      const row = await geometry(page);
      measured.push(row);
      return row;
    };
    let shown = await at(1920);
    assert.deepEqual([shown.sideBar, Math.round(shown.panelWidth), Math.round(shown.contentWidth)], [240, 400, 1232]);

    shown = await at(1280);
    assert.deepEqual([shown.sideBar, Math.round(shown.panelWidth), Math.round(shown.contentWidth)], [0, 400, 832]);
    assert.equal(await page.evaluate(() => localStorage.getItem('ocupilot.side-bar.open')), null, 'the yield writes no preference');

    await page.focus('main#ocu-content');
    await chord(page, 'KeyB');
    await panelSettlesAt(page, 352);
    shown = await geometry(page);
    assert.deepEqual([shown.sideBar, Math.round(shown.panelWidth), Math.round(shown.contentWidth)], [240, 352, 640]);
    assert.equal(await page.evaluate(() => localStorage.getItem('ocupilot.panel.width')), null, 'the reopen writes no stored width');

    // The chord again returns the reopened side bar to the yield, still writing no preference.
    await page.focus('main#ocu-content');
    await chord(page, 'KeyB');
    await panelSettlesAt(page, 400);
    shown = await geometry(page);
    assert.deepEqual([shown.sideBar, Math.round(shown.panelWidth), Math.round(shown.contentWidth)], [0, 400, 832]);
    assert.equal(await page.evaluate(() => localStorage.getItem('ocupilot.side-bar.open')), null);

    shown = await at(1024);
    assert.deepEqual([shown.sideBar, Math.round(shown.panelWidth), Math.round(shown.contentWidth)], [0, 336, 640]);

    shown = await at(900);
    assert.deepEqual([shown.sideBar, Math.round(shown.panelWidth), Math.round(shown.contentWidth)], [0, 320, 532]);
    assert.ok(shown.contentScrollWidth >= 640, `the content region scrolls its 640px floor: ${shown.contentScrollWidth}`);
    assert.equal(Math.round(shown.floorWidth), 640);

    for (const row of measured) {
      assert.equal(row.pageScrollWidth, row.pageClientWidth, `the page body does not scroll horizontally at ${row.viewport}px`);
    }
  } finally {
    await context.close();
  }
});

test('the 640px content minimum, measured at 1,280px docked and resized to maximum, on the Users list and the Definition form', async () => {
  for (const url of [USERS_URL, FORM_URL]) {
    const { context, page } = await signedInAt(url, { width: 1280, height: 900 });
    try {
      await page.waitForFunction(() => document.documentElement.clientWidth === 1280, { timeout: config.navigationTimeoutMs });
      await panelSettlesAt(page, 400);
      const docked = await geometry(page);
      const max = docked.valueMax;
      await pressOnHandle(page, 'ArrowLeft', Math.ceil((max - 400) / 16) + 1);
      await panelSettlesAt(page, max);
      const resized = await geometry(page);
      console.log(`MEASURE ${JSON.stringify({ url, docked, resized })}`);

      assert.equal(Math.round(docked.panelWidth), 400);
      assert.equal(Math.round(docked.contentWidth), 832);
      assert.equal(max, 592);
      assert.equal(Math.round(resized.contentWidth), 640, 'at the maximum the content region is exactly 640');
      assert.equal(resized.contentScrollWidth, resized.contentClientWidth, 'and the content does not scroll');
      assert.equal(resized.pageScrollWidth, resized.pageClientWidth);
    } finally {
      await context.close();
    }
  }
});
