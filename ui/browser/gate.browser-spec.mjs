/**
 * The first-login gate, the panel's unconfigured state and the rail's attention dot, in a real
 * browser against the throwaway instance (Story 3.6).
 *
 * **Four things jsdom cannot say, and every one of them is what an AC is about.**
 *
 * 1. **The browser's own address bar.** AC1 is "the URL becomes the Definition form route" and
 *    AC1b is "the requested URL is unchanged". A jsdom test reads a router's idea of the URL; only
 *    a real navigation, over a real sign-in, through the server's own deep-link fallback, says
 *    what the address bar holds.
 * 2. **A reload is a different event from a sign-in.** AC1b turns on `Session.start()` resuming a
 *    pair out of the tab's own `sessionStorage` and reaching `signed-in` without `adopt()`.
 *    `sessionStorage` surviving a reload is a browser fact; there is no reload in jsdom.
 * 3. **Tab order.** AC4 says the composer and Send are "reachable by Tab". jsdom has no sequential
 *    focus navigation, so `panel.spec.ts` can assert `aria-disabled` and the absence of `disabled`
 *    and still not know whether a keyboard reaches either control.
 * 4. **The Integration AC's own tick.** The dot going within one change-bus tick of the
 *    Definitions list's `Enable` is a chain that runs through the real list, the real write, the
 *    real bus and a real re-read of the real instance.
 *
 * **It refuses the live container**, for the reason its siblings do: it creates a definition,
 * marks it verified and enables it. It **creates the rows it needs and tears them down** (DW-368),
 * so the specs that run after it meet an instance with no enabled definition, which is the state
 * every one of them now renders the panel in.
 *
 * **No provider call is made, planned or otherwise.** `ConnectionVerified` is set on the stored row
 * through `OcuPilot.Test.AgentFixture.SetFlags` inside the container, which is the same seam the
 * ObjectScript suite uses and the only way to reach an enabled definition without calling a
 * provider (`AgentRules.Validate` refuses an enable while the row is unverified).
 *
 * Run: `npm run test:browser` (after `npm run build` and `sh scripts/ci-throwaway.sh up`).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { waitForRows } from './list-spec.mjs';
import { GATE_PATH } from './shell-entry.mjs';
import {
  DEFINITIONS_PATH,
  authHeader as sharedAuthHeader,
  definitions as sharedDefinitions,
} from './panel-spec.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const uiRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const { STRINGS } = await import(join(uiRoot, 'src', 'app', 'core', 'strings.ts'));
const { SCREENS } = await import(join(uiRoot, 'src', 'app', 'core', 'screens.generated.ts'));

/**
 * The id of the Definitions list's enable row action, read out of the generated mirror.
 *
 * The shipped table renders a row action's **id** as its menu item, not a published label, so this
 * is what the menu says today -- and reading it from the mirror rather than typing it means a
 * renamed action fails here rather than silently offering nothing to click.
 */
const ENABLE_ACTION = (() => {
  const list = SCREENS.find((screen) => screen.route === 'agent/definitions');
  assert.ok(list, 'the mirror declares the Definitions list');
  const action = list.rowActions.find((entry) => entry.id.includes('enable') && !entry.id.includes('dis'));
  assert.ok(action, 'and an enable row action on it');
  return action.id;
})();

const config = browserConfig();

/** A screen in another area, so "the gate moved the browser" is a visible change of route. */
const OTHER_URL = '/ocupilot/permissions/users?ns=HSCUSTOM';
/**
 * Where the gate puts an administrator. Taken from `shell-entry.mjs` rather than typed again: the
 * eleven specs that step around the gate and the one spec that asserts where it went have to agree
 * about the destination, and two copies of a path is how one of them ends up pointing elsewhere.
 */
const FORM_PATH = GATE_PATH;

/** Every definition this spec creates is named with this prefix and removed in `after`. */
const PREFIX = 'OcuPilotGateProbe';

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
  await removeProbeDefinitions();
  // The state every later spec file inherits, asserted rather than assumed.
  assert.equal(await enabledCount(), 0, 'this spec leaves the instance with no enabled definition');
  if (browser !== null) await browser.close();
});

function authHeader() {
  return sharedAuthHeader(config);
}

async function definitions() {
  return sharedDefinitions(config);
}

async function enabledCount() {
  return (await definitions()).filter((row) => row.enabled === true).length;
}

/**
 * Remove every definition this spec created, through the shipped route.
 *
 * **Every delete is checked.** Seven spec files enable a definition — this one and
 * `panel.browser-spec.mjs` directly, and `context-chip`, `navigate`, `reply`, `suggested-view` and
 * `turn` through `armProbeDefinition`, which reaches `TurnWireFixture.EnsureDefinition` and its
 * `SetFlags(pId, 1, 1)`. Each is responsible for removing its own, and every spec file that does
 * not enable one renders the panel on the premise that nothing is enabled. A delete that quietly
 * failed would leave an enabled row behind, turn `leaveFirstLoginGate` into a no-op in all of them,
 * and surface as an unrelated assertion in a file that did nothing wrong.
 */
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

/** Create one probe definition through the shipped route and answer its id. */
async function createProbeDefinition(name) {
  const created = await fetch(`${config.origin}${DEFINITIONS_PATH}`, {
    method: 'POST',
    headers: { Authorization: authHeader(), 'Content-Type': 'application/json' },
    body: JSON.stringify({ name, provider: 'anthropic', credType: 'creds', credentialName: 'OcuPilotAnthropic' }),
  });
  assert.equal(created.status, 201, `the probe definition is created (HTTP ${created.status})`);
  return (await created.json()).id;
}

/**
 * Mark a stored definition verified inside the container, so the list's `Enable` is permitted.
 *
 * The rule is the instance's (`AgentRules.Validate`: `enabled` may not be turned on while the
 * definition is unverified), and only a passing Test connection sets the flag over the wire. This
 * spec makes no provider call, so it reaches the same seam the ObjectScript suite does.
 */
function markVerified(id) {
  // The id reaches an ObjectScript command line, so its shape is checked rather than trusted --
  // `.claude/rules/objectscript-basics.md` states the rule without an exception for test helpers,
  // and a quote or a backslash would produce a `<SYNTAX>` this function would report as "the
  // fixture did not mark the row verified".
  assert.match(String(id), /^[A-Za-z0-9._-]+$/, `the definition id is a bare identifier: ${id}`);
  const lines = [
    'Set $NAMESPACE=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")',
    `Set tSC=##class(OcuPilot.Test.AgentFixture).SetFlags("${id}",0,1)`,
    'Write "OCU"_"-VERIFIED-START:"_$System.Status.IsOK(tSC)_":OCU"_"-VERIFIED-END",!',
    'Halt',
  ];
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input: `${lines.join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const match = /OCU-VERIFIED-START:(.*?):OCU-VERIFIED-END/.exec(output);
  assert.equal(match?.[1], '1', `the fixture marked the row verified: ${output}`);
}

/** A fresh context, landed at `url`, with the sign-in card on screen and nothing typed yet. */
async function atSignIn(url) {
  // Story 15.5: the remembered screen and shell state lives on the instance now, keyed by the
  // one account every spec signs in as, so a fresh context is no longer a fresh slate on its
  // own -- see `preferences-reset.mjs`.
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.goto(`${config.origin}${url}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  return { context, page };
}

/** Submit the sign-in form and wait for the frame. */
async function submitSignIn(page) {
  await page.type('#ocu-signin-user', config.username);
  await page.type('#ocu-signin-password', config.password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
}

/**
 * A signed-in context that has left the gate the way an administrator leaves it: through the rail
 * and the side bar, client-side.
 *
 * **Never through a second `page.goto`.** A fresh document is not a resumed tab: `TokenStore`
 * adopts a stored pair only across a reload or a Back/Forward (DW-6), so a `goto` clears the pair,
 * the silent probe mints a new one, `adopt()` runs -- and that is an authentication, which the
 * gate is entitled to act on. Leaving is a route change inside the running shell, which is what
 * this does.
 */
async function signedInAndMovedTo(area, screen) {
  const { context, page } = await atSignIn(OTHER_URL);
  await submitSignIn(page);
  // **Let the gate's navigation land before anything reads the path as a baseline.** `openScreen`
  // waits for the path to differ from the one it captured; if the gate has not moved the tab yet
  // that captured path is still the requested screen's, and clicking that screen navigates to the
  // same path, so the wait can never succeed. Settling first makes the baseline the gate's answer
  // whichever way it went.
  await settlePath(page);
  await openScreen(page, area, screen);
  return { context, page };
}

/** Wait until the address bar has stopped moving, so a caller's baseline is a settled one. */
async function settlePath(page) {
  let seen = pathOf(page);
  for (let read = 0; read < 20; read += 1) {
    await new Promise((resolve) => setTimeout(resolve, 100));
    const again = pathOf(page);
    if (again === seen) return seen;
    seen = again;
  }
  assert.fail(`the address bar never settled; last read ${JSON.stringify(seen)}`);
}

/**
 * Open an area's side bar and click the named entry in it.
 *
 * **The rail item toggles**, so a click is never assumed to have opened anything: clicking the
 * item whose list is already showing collapses it, and the gate lands on a screen in the agent
 * area, whose item therefore starts active. The side bar's own landmark name says which area is
 * listed -- `"<Area> screens"` -- so the loop reads that rather than guessing from a click.
 */
async function openSideBar(page, area) {
  const wanted = STRINGS.navSideBarLandmark.split('<Area>').join(area);
  for (let attempt = 0; attempt < 4; attempt += 1) {
    const shown = await page.$$eval('app-side-bar nav.ocu-side-bar', (nodes, label) =>
      nodes.some((node) => node.getAttribute('aria-label') === label), wanted);
    if (shown) return;
    await page.click(`.ocu-rail-item[aria-label="${area}"]`);
    await new Promise((resolve) => setTimeout(resolve, 250));
  }
  assert.fail(`the ${area} side bar never opened`);
}

/** Open an area's side bar, then click the entry named `screen` and wait for the route to move. */
async function openScreen(page, area, screen) {
  const before = pathOf(page);
  await openSideBar(page, area);
  // Matched on the entry's own label span, never on the item's whole `textContent`: a gated entry
  // renders its reason beside the label, so the two are not the same string.
  const opened = await page.evaluate((label) => {
    const entry = [...document.querySelectorAll('app-side-bar .ocu-side-bar-item')].find(
      (candidate) => candidate.querySelector('.ocu-side-bar-label')?.textContent?.trim() === label
    );
    if (entry === undefined) return false;
    entry.click();
    return true;
  }, screen);
  assert.equal(opened, true, `the ${area} side bar lists ${JSON.stringify(screen)}`);
  await page.waitForFunction(
    (was) => new URL(window.location.href).pathname !== was,
    { timeout: config.navigationTimeoutMs },
    before
  );
}

const pathOf = (page) => new URL(page.url()).pathname;

test('AC1: signing in through the form with nothing enabled lands on the Definition form, under its landing banner', async () => {
  const { context, page } = await atSignIn(OTHER_URL);
  try {
    assert.equal(pathOf(page), '/ocupilot/permissions/users', 'the sign-in card is over the route that was asked for');
    await submitSignIn(page);
    await page.waitForFunction(
      (wanted) => new URL(window.location.href).pathname === wanted,
      { timeout: config.navigationTimeoutMs },
      FORM_PATH
    );
    // The browser's own address bar, not the router's idea of it.
    assert.equal(pathOf(page), FORM_PATH);

    await page.waitForSelector('.ocu-form-gate-banner', { timeout: config.navigationTimeoutMs });
    const banner = await page.$eval('.ocu-form-gate-banner', (node) => node.textContent.trim());
    assert.ok(banner.includes(STRINGS.agentGateLandingBanner), `the gate landing banner is rendered: ${banner}`);

    // Above the form, which is what "landing" means: it is the first thing read on arrival.
    // Both nodes are waited for: the fields render behind the form's own reads, so comparing
    // document position against a node that has not arrived throws rather than failing.
    await page.waitForSelector('.ocu-form-fields', { timeout: config.navigationTimeoutMs });
    const order = await page.evaluate(() => {
      const bannerNode = document.querySelector('.ocu-form-gate-banner');
      const fields = document.querySelector('.ocu-form-fields');
      return (bannerNode.compareDocumentPosition(fields) & Node.DOCUMENT_POSITION_FOLLOWING) !== 0;
    });
    assert.equal(order, true, 'the banner precedes the fields in the document');
  } finally {
    await context.close();
  }
});

test('AC1b: a reload that resumes a stored pair does not redirect, and the requested URL is unchanged', async () => {
  // Mutation (Rule 19): make `Session.start()`'s resume branch call `adopt()` -> this goes red,
  // because the reload would then be an authentication and the gate would take the tab off the
  // route the administrator chose. The same leg reds if the gate runs on `signed-in` rather than
  // on `consumeFreshSignIn()`.
  const { context, page } = await signedInAndMovedTo(STRINGS.navAreaPermissions, STRINGS.userListLabel);
  try {
    const left = pathOf(page);
    assert.notEqual(left, FORM_PATH, 'the administrator has left the gate, and is somewhere else');

    await page.reload({ waitUntil: 'networkidle2' });
    await page.waitForSelector('app-rail .ocu-rail', { timeout: config.navigationTimeoutMs });
    // Long enough for a redirect to have happened if one were coming: the gate's two reads and the
    // navigation they would issue are one round trip each.
    await new Promise((resolve) => setTimeout(resolve, 1500));
    assert.equal(pathOf(page), left, 'the requested URL survived the reload');
    assert.equal(new URL(page.url()).search, '?ns=HSCUSTOM', 'and so did its namespace');

    // And the panel's banner is still there, on this route as on every other: leaving the gate
    // does not clear the condition, and nothing about the gate was remembered.
    const banner = await page.$eval('.ocu-panel-banner', (node) => node.textContent.trim());
    assert.ok(banner.includes(STRINGS.agentGateReminderBanner), `the reminder banner stands: ${banner}`);
  } finally {
    await context.close();
  }
});

test('AC2, AC3: the panel carries the administrator reminder, the labelled example card and the three trust sentences', async () => {
  const { context, page } = await signedInAndMovedTo(STRINGS.navAreaPermissions, STRINGS.userListLabel);
  try {
    await page.waitForSelector('app-panel .ocu-panel', { timeout: config.navigationTimeoutMs });
    const rendered = await page.evaluate(
      (focusable) => {
        const panel = document.querySelector('app-panel .ocu-panel');
        const card = panel.querySelector('.ocu-proposal-card');
        return {
          banner: panel.querySelector('.ocu-panel-banner')?.textContent?.trim() ?? '',
          dismissControls: panel.querySelectorAll('.ocu-panel-banner button').length,
          band: panel.querySelector('.ocu-proposal-card-band')?.textContent?.trim() ?? '',
          cardTitle: card.querySelector('.ocu-proposal-card-title').textContent.trim(),
          cardFocusable: card.querySelectorAll(focusable).length,
          trust: [...panel.querySelectorAll('.ocu-panel-trust li')].map((node) => node.textContent.trim()),
          // The panel really is laid out, not merely present: jsdom would answer 0 here.
          width: panel.getBoundingClientRect().width,
        };
      },
      'a[href], button, input, select, textarea, [tabindex], [contenteditable]'
    );

    assert.ok(rendered.banner.includes(STRINGS.agentGateReminderBanner), `the reminder banner: ${rendered.banner}`);
    assert.equal(rendered.dismissControls, 0, 'and it carries no dismiss control');
    assert.equal(rendered.band, STRINGS.proposalExampleCardTitle);
    assert.equal(rendered.cardTitle, 'Proposal \u00b7 Web application /csp/myapp');
    assert.equal(rendered.cardFocusable, 0, 'nothing in the example card is a way in');
    assert.deepEqual(rendered.trust, [
      STRINGS.agentTrustReads,
      STRINGS.agentTrustProposes,
      STRINGS.agentTrustAudited,
    ]);
    assert.ok(rendered.width >= 320, `the panel is laid out at its own width: ${rendered.width}`);
  } finally {
    await context.close();
  }
});

test('AC4: the composer and Send are reachable by Tab, aria-disabled, and never carry the disabled attribute', async () => {
  const { context, page } = await signedInAndMovedTo(STRINGS.navAreaPermissions, STRINGS.userListLabel);
  try {
    await page.waitForSelector('.ocu-panel-composer', { timeout: config.navigationTimeoutMs });
    const attributes = await page.evaluate(() => {
      const composer = document.querySelector('.ocu-panel-composer');
      const send = document.querySelector('.ocu-panel-send');
      return [composer, send].map((node) => ({
        ariaDisabled: node.getAttribute('aria-disabled'),
        disabled: node.hasAttribute('disabled'),
      }));
    });
    for (const control of attributes) {
      assert.equal(control.ariaDisabled, 'true');
      assert.equal(control.disabled, false);
    }

    // The Tab order itself: focus the composer, then Tab once, and Send is next. A browser skips a
    // natively disabled control, which is the whole reason `aria-disabled` is what is used here.
    await page.focus('.ocu-panel-composer');
    assert.ok(
      await page.evaluate(() => document.activeElement?.classList.contains('ocu-panel-composer') ?? false),
      'the composer takes focus'
    );
    await page.keyboard.press('Tab');
    assert.ok(
      (await page.evaluate(() => document.activeElement?.className ?? '')).includes('ocu-panel-send'),
      'and Tab reaches Send from it'
    );

    // No context chip: there is no provider or endpoint to name until a definition is enabled.
    assert.equal(await page.$$eval('app-panel .ocu-context-chip', (nodes) => nodes.length), 0);
  } finally {
    await context.close();
  }
});

test('AC6, Integration AC: the dot and the panel clear on the first render after the list\'s Enable', async () => {
  const id = await createProbeDefinition(`${PREFIX}Enable`);
  markVerified(id);
  const { context, page } = await signedInAndMovedTo(STRINGS.navAreaAgent, STRINGS.agentDefinitionListLabel);
  try {
    // Lit before, on the Agent co-pilot slot, named for this caller's audience.
    await page.waitForSelector('.ocu-rail-dot', { timeout: config.navigationTimeoutMs });
    const before = await page.$eval('.ocu-rail-dot', (node) => ({
      label: node.getAttribute('aria-label'),
      area: node.closest('.ocu-rail-slot').querySelector('.ocu-rail-item').getAttribute('aria-label'),
      insideButton: node.closest('.ocu-rail-item') !== null,
    }));
    assert.equal(before.label, STRINGS.agentGateReminderBanner);
    assert.equal(before.area, STRINGS.navAreaAgent);
    assert.equal(before.insideButton, false, 'the dot is a sibling of the button, so it keeps its own name');

    // The list's own Enable, through the row menu the shipped table renders.
    await waitForRows(page, config.navigationTimeoutMs);
    const rowIndex = await page.evaluate((name) => {
      const rows = [...document.querySelectorAll('[role="grid"] .ocu-data-table-body [role="row"]')];
      const row = rows.find((candidate) => candidate.textContent.includes(name));
      return row === undefined ? '' : row.getAttribute('aria-rowindex');
    }, `${PREFIX}Enable`);
    assert.notEqual(rowIndex, '', 'the probe definition is in the list');

    await page.click(`[role="row"][aria-rowindex="${rowIndex}"] .ocu-data-table-trigger`);
    await page.waitForSelector('[role="menu"]', { timeout: config.navigationTimeoutMs });
    const clicked = await page.evaluate((label) => {
      const item = [...document.querySelectorAll('[role="menu"] .ocu-data-table-menu-item')].find(
        (candidate) => candidate.textContent.trim() === label
      );
      if (item === undefined) return false;
      item.click();
      return true;
    }, ENABLE_ACTION);
    assert.equal(clicked, true, `the row menu offers ${JSON.stringify(ENABLE_ACTION)}`);

    // One change-bus tick: the write publishes, the status re-reads, and the dot, the banner and
    // the example card go together. Nothing on the client was told to forget.
    await page.waitForFunction(() => document.querySelector('.ocu-rail-dot') === null, {
      timeout: config.navigationTimeoutMs,
    });
    assert.equal(await page.$$eval('app-panel .ocu-panel-banner', (nodes) => nodes.length), 0, 'the reminder banner is gone with it');
    assert.equal(await page.$$eval('.ocu-proposal-card', (nodes) => nodes.length), 0, 'and so is the example card');
    assert.equal(await enabledCount(), 1, 'and the instance really did change: the row is enabled');
  } finally {
    await context.close();
    await removeProbeDefinitions();
  }
});
