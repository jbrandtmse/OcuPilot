/**
 * Story 7.4's Auditing configuration screen, end to end in a real browser against the throwaway
 * instance: "Turn auditing off" opens a warning that sends nothing until Proceed, the panel's
 * "not being marked" banner appears with its link and action, the action opens the screen with
 * "Turn auditing on" focused, and pressing it clears the banner. The screen's cross-link and its two
 * embedded event lists render from their declared reads.
 *
 * **It turns the throwaway's auditing off.** It refuses to run anywhere but a `-ci` throwaway, and
 * its `after` hook puts auditing back whatever happened above.
 *
 * **The banner is read through a consumer** (the Integration AC): the screen caller records the
 * observed marking fact, `GET /agent/restraint` answers it, and what is asserted is the panel strip.
 *
 * Run, from `ui/`: `npm run build && docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `OCUPILOT_BROWSER_ORIGIN=... OCUPILOT_BROWSER_CONTAINER=... node --test
 * browser/auditing-screen.browser-spec.mjs`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import puppeteer from 'puppeteer';

import { READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { signedInAt } from './panel-spec.mjs';
import { markerValue, runIris as sharedRunIris } from './turnprobe-spec.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

const SCREEN_URL = '/ocupilot/security/auditing?ns=HSCUSTOM';

/** The screen action route this page's two buttons post to. */
const ACTION_PATH = '/api/ocupilot/screens/security.auditing/action';

/** The two embedded event lists' sections, keyed by their routes. */
const EVENT_LIST_ROUTES = ['security/auditing/system-events', 'security/auditing/user-events'];

let browser = null;

before(async () => {
  assert.match(
    config.container,
    /-ci$/,
    `this spec disables instance-wide auditing, so it runs only in a throwaway; ${config.container} is not one`
  );
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  browser = await puppeteer.launch(launchOptions(config));
  assert.equal(auditEnabled(), '1', 'the instance starts audited, so the disable has something to change');
});

after(async () => {
  if (browser !== null) await browser.close();
  if (!/-ci$/.test(config.container)) return;
  // Unconditional: auditing off is instance-wide, so a spec that failed between the disable and the
  // re-enable would leave every later spec's instance unaudited.
  restoreAuditing();
  assert.equal(auditEnabled(), '1', 'and the instance is left audited');
});

function runIris(lines) {
  return sharedRunIris(config.container, lines);
}

/** The instance's own `AuditEnabled` setting, read off the instance. */
function auditEnabled() {
  const output = runIris([
    `Write "OCU-AUDSCR-START:"_##class(OcuPilot.Test.AuditingUpdate).AuditEnabled()_":OCU-AUDSCR-END",!`,
  ]);
  return markerValue(output, 'AUDSCR') ?? '';
}

/** Put auditing back, and the recorded marking fact with it. Only repairs a wrong state. */
function restoreAuditing() {
  runIris([`Do ##class(OcuPilot.Test.AuditingUpdate).RestoreAuditing()`]);
}

/** Count every screen-action POST `page` issues, so "Cancel sends nothing" is observed, not assumed. */
function countActions(page) {
  const seen = { posts: 0 };
  page.on('request', (request) => {
    if (request.method() === 'POST' && request.url().includes(ACTION_PATH)) seen.posts += 1;
  });
  return seen;
}

function bannerShowing(page) {
  return page.evaluate(
    (sentence) =>
      Array.from(document.querySelectorAll('[data-slot="not-marked"] .ocu-banner-message')).some(
        (node) => (node.textContent ?? '').trim() === sentence
      ),
    STRINGS.auditingOffBanner
  );
}

test('AC1-AC4: the warning, the banner with its link and action, the focused enable, and the lists', async () => {
  const { context, page } = await signedInAt(browser, config, SCREEN_URL);
  const seen = countActions(page);
  try {
    await page.waitForSelector('button[data-action="disable"]', { timeout: config.navigationTimeoutMs });

    // AC4: the cross-link and both embedded lists, each rendering rows from its declared read. Each
    // list's read is its own request and can answer after the form's, so wait until both have
    // answered: rows, the empty state, or the fault.
    const [systemState, userState] = await (
      await page.waitForFunction(
        (routes) => {
          const states = routes.map((route) => {
            const section = document.querySelector(`[data-section="${route}"]`);
            if (section === null) return 'absent';
            if (section.querySelector('tbody tr') !== null) return 'rows';
            if (section.querySelector('.ocu-data-table-refusal') !== null) return 'fault';
            if (section.querySelector('.ocu-data-table-empty-title') !== null) return 'empty';
            return 'pending';
          });
          return states.includes('pending') ? false : states;
        },
        { timeout: config.navigationTimeoutMs },
        EVENT_LIST_ROUTES
      )
    ).jsonValue();
    const lists = await page.evaluate(() => ({
      cross: document.querySelector('a[data-cross-link]')?.getAttribute('href') ?? '',
      system: document.querySelectorAll('[data-section="security/auditing/system-events"] tbody tr').length,
      user: document.querySelectorAll('[data-section="security/auditing/user-events"] tbody tr').length,
      systemHeading: document.querySelector('[data-section="security/auditing/system-events"] h2 a')?.getAttribute('href') ?? '',
    }));
    assert.equal(lists.cross, 'logs/audit?ns=HSCUSTOM', 'the screen cross-links to the Audit database viewer');
    assert.ok(lists.system > 0, `the system-event list renders rows (${lists.system}, ${systemState})`);
    assert.ok(lists.user > 0, `and so does the user-event list (${lists.user}, ${userState})`);
    assert.equal(lists.systemHeading, 'security/auditing/system-events?ns=HSCUSTOM', 'each list is headed by a link to its own route');

    // AC1: the warning dialog, and Cancel sends nothing.
    assert.equal(await bannerShowing(page), false, 'the banner is absent while the instance is audited');
    const secondary = await page.$eval('button[data-action="disable"]', (button) => button.className);
    assert.equal(secondary, 'ocu-button-secondary', 'turning auditing off is the secondary button');
    await page.click('button[data-action="disable"]');
    await page.waitForSelector('[role="dialog"]', { timeout: config.navigationTimeoutMs });
    const dialog = await page.evaluate(() => {
      const surface = document.querySelector('[role="dialog"]');
      const proceed = surface.querySelector('.ocu-dialog-actions .ocu-button-primary');
      return {
        title: (surface.querySelector('.ocu-dialog-title')?.textContent ?? '').trim(),
        body: (surface.querySelector('.ocu-warning-consequence')?.textContent ?? '').trim(),
        proceed: (proceed?.textContent ?? '').trim(),
        destructive: surface.querySelector('.ocu-button-destructive') !== null,
        focused: document.activeElement?.textContent?.trim() ?? '',
      };
    });
    assert.equal(dialog.title, STRINGS.auditingTurnOffAction, 'the dialog is titled with the verb');
    assert.equal(dialog.body, STRINGS.proposalAuditWarning, 'and states the consequence');
    assert.equal(dialog.proceed, STRINGS.actionProceed, 'Proceed is a button-primary');
    assert.equal(dialog.destructive, false, 'never a destructive one');
    assert.equal(dialog.focused, STRINGS.actionCancel, 'Cancel takes initial focus');
    await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-secondary');
    await page.waitForFunction(() => document.querySelector('[role="dialog"]') === null, {
      timeout: config.navigationTimeoutMs,
    });
    assert.equal(seen.posts, 0, 'Cancel sent nothing');
    assert.equal(auditEnabled(), '1', 'and auditing is unchanged');

    // AC2: Proceed turns auditing off, and the banner appears at once with its link and action.
    await page.click('button[data-action="disable"]');
    await page.waitForSelector('[role="dialog"] .ocu-dialog-actions .ocu-button-primary', {
      timeout: config.navigationTimeoutMs,
    });
    await page.click('[role="dialog"] .ocu-dialog-actions .ocu-button-primary');
    await page.waitForFunction(
      (sentence) =>
        Array.from(document.querySelectorAll('[data-slot="not-marked"] .ocu-banner-message')).some(
          (node) => (node.textContent ?? '').trim() === sentence
        ),
      { timeout: config.navigationTimeoutMs },
      STRINGS.auditingOffBanner
    );
    assert.equal(seen.posts, 1, 'Proceed sent exactly one write');
    assert.equal(auditEnabled(), '0', 'the screen turned auditing off');
    const banner = await page.evaluate(() => ({
      link: (document.querySelector('[data-slot="not-marked"] .ocu-panel-banner-link')?.textContent ?? '').trim(),
      action: (document.querySelector('[data-slot="not-marked"] button[data-auditing-turn-on]')?.textContent ?? '').trim(),
    }));
    assert.equal(banner.link, STRINGS.auditingConfigurationLink, 'the banner links to Auditing configuration');
    assert.equal(banner.action, STRINGS.auditingTurnOnAction, 'and an administrator gets Turn auditing on');

    // AC3: the banner's action opens the screen with "Turn auditing on" focused.
    await page.click('[data-slot="not-marked"] button[data-auditing-turn-on]');
    await page.waitForFunction(
      () => document.activeElement?.getAttribute('data-action') === 'enable',
      { timeout: config.navigationTimeoutMs }
    );

    // AC2: pressing it turns auditing back on and the banner clears.
    await page.keyboard.press('Enter');
    await page.waitForFunction(
      (sentence) =>
        !Array.from(document.querySelectorAll('[data-slot="not-marked"] .ocu-banner-message')).some(
          (node) => (node.textContent ?? '').trim() === sentence
        ),
      { timeout: config.navigationTimeoutMs },
      STRINGS.auditingOffBanner
    );
    assert.equal(seen.posts, 2, 'the enable was sent at once, with no dialog');
    assert.equal(auditEnabled(), '1', 'and auditing is on again');
  } finally {
    await context.close();
  }
});
