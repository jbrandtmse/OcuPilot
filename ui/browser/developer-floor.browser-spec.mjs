/**
 * Story 19.12 in a real browser, against the throwaway (DW-1903): a `%Developer` principal signs
 * in, the shell shows no no-privileges notice, System Explorer's Classes list renders rows, and
 * the Permissions rail item stays listed, unavailable, naming its failed pair.
 *
 * The principal is created inside the container through `OcuPilot.Test.DeveloperFloorFixture`:
 * role `%Developer` plus READ on the install namespace's code database, and nothing else. The
 * password is generated per run, and the principal and its role are removed afterwards. The
 * route and tool rosters are `OcuPilot.Test.DeveloperFloor`'s and `DeveloperFloorRoutes`'.
 *
 * It refuses the live container.
 *
 * Run: `node --test --test-concurrency=1 browser/developer-floor.browser-spec.mjs` (after
 * `npm run build`, the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { parseMarkers } from './iris-session.mjs';
import { viewCount, waitForRows } from './list-spec.mjs';
import { waitForMapAnswered } from './namespace-features.mjs';
import { resetRememberedState } from './preferences-reset.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

/** System Explorer's Classes list, which the principal opens. */
const CLASSES_ROUTE = '/ocupilot/system-explorer/classes?ns=HSCUSTOM';

/** The message a settled instance notice shows; the notice renders no message while it is still checking. */
const NOTICE_MESSAGE = 'app-instance-notice .ocu-empty-state-notice';

/** The pair the Permissions area names for a caller holding none of its set. */
const PERMISSIONS_PAIR = '%Admin_Secure:USE';

const password = `OcuPilotDev${randomBytes(12).toString('hex')}Aa9`;
let user = '';
let browser = null;

/** Run ObjectScript lines in the throwaway and answer the named markers. */
function irisSession(lines, names) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input: `${['Set $NAMESPACE=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")', ...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  return { values: parseMarkers(output, names), output };
}

const marker = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates a principal, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  const created = irisSession(
    [
      `Set tSC=##class(OcuPilot.Test.DeveloperFloorFixture).EnsurePrincipal("${password}","",.tUser)`,
      marker('USER', '$Get(tUser)'),
      marker('OK', '$System.Status.IsOK(tSC)'),
    ],
    ['USER', 'OK']
  );
  assert.equal(created.values.OK, '1', `the fixture created the principal: ${created.output}`);
  user = created.values.USER;
  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  // `before` refused the live container; no principal was created there, and nothing is removed.
  if (config.container === LIVE_CONTAINER) return;
  const removed = irisSession([marker('LEFT', '##class(OcuPilot.Test.DeveloperFloorFixture).RemovePrincipals()')], ['LEFT']);
  assert.equal(removed.values.LEFT, '', `the principal and its role are gone: ${removed.output}`);
});

test('DW-1903: a %Developer principal signs in, reads the System Explorer Classes list, and finds Permissions unavailable naming its pair', async () => {
  // Mutation (Rule 19): `OcuPilot.Screen.Gate.FloorResources` answers `ADMINRESOURCES` alone ->
  // the identity call answers `AUTH.NOADMIN`, the no-privileges notice renders in place of the
  // frame, and the notice assertion goes red.
  await resetRememberedState();
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  try {
    await page.goto(`${config.origin}${CLASSES_ROUTE}`, { waitUntil: 'networkidle2' });
    await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('#ocu-signin-user', user);
    await page.type('#ocu-signin-password', password);
    await page.click('.ocu-signin-card button[type="submit"]');
    // The frame and a settled instance notice never render together: wait for whichever comes first.
    await page.waitForSelector(`app-rail .ocu-rail, ${NOTICE_MESSAGE}`, { timeout: config.navigationTimeoutMs });
    const notice = await page.evaluate((selector) => document.querySelector(selector)?.textContent.trim() ?? null, NOTICE_MESSAGE);
    assert.equal(notice, null, 'the frame, not the no-privileges notice');
    await waitForRows(page, config.navigationTimeoutMs);
    await waitForMapAnswered(page, config.navigationTimeoutMs);

    const seen = await page.evaluate(() => {
      const explorer = document.querySelector('#ocu-rail-item-system-explorer');
      return {
        path: window.location.pathname,
        permissionsDisabled: document.querySelector('#ocu-rail-item-permissions')?.getAttribute('aria-disabled') ?? null,
        permissionsTip: document.querySelector('#ocu-rail-tip-permissions')?.textContent.trim() ?? null,
        explorerDisabled: explorer === null ? 'absent' : explorer.getAttribute('aria-disabled'),
      };
    });
    assert.equal(seen.path, new URL(CLASSES_ROUTE, 'http://x.invalid').pathname, 'on the Classes list');
    assert.ok((await viewCount(page)) > 0, 'the Classes list renders rows');
    assert.equal(seen.explorerDisabled, null, 'System Explorer is listed and available');
    assert.equal(seen.permissionsDisabled, 'true', 'Permissions stays listed, unavailable');
    assert.equal(seen.permissionsTip, STRINGS.privilegeRequiresResource.replace('<resource>', PERMISSIONS_PAIR), 'naming its failed pair');
  } finally {
    await context.close();
  }
});
