/**
 * The panel as a least-privileged principal sees it, in a real browser against the throwaway
 * (Story 4.3, DW-378).
 *
 * Every other browser spec signs in as `_SYSTEM`, which the navigation map allows everywhere, so
 * the non-administrator configuration-empty state is otherwise exercised in jsdom only. This spec
 * creates a real principal inside the container through `OcuPilot.Test.TurnWireFixture`: its role
 * holds read on the install namespace's databases, `%Ens_Credentials:READ` and `%Admin_Operate:USE`
 * -- the one administrative resource the router's floor requires before any OcuPilot screen
 * renders -- and nothing of OcuPilot's own, so the map refuses it `agent/definitions`. The password
 * is generated per run, and the principal and the fixture's role are removed afterwards.
 *
 * It refuses the live container, and needs an instance with no enabled definition, which every
 * spec that enables one restores.
 *
 * Run: `npm run test:browser` (after `npm run build`, the bundle copied into the throwaway).
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';

const config = browserConfig();
const STRINGS = loadStrings();

/** Two routes: Home, which the principal may open, and a list it is refused. The panel is on both. */
const ROUTES = ['/ocupilot/?ns=HSCUSTOM', '/ocupilot/permissions/users?ns=HSCUSTOM'];

const password = `OcuPilotPanel${randomBytes(12).toString('hex')}Aa9`;
let user = '';
let browser = null;

/** Run ObjectScript lines in the throwaway and answer the named `OCU-<name>-START:...:OCU-<name>-END` markers. */
function irisSession(lines, names) {
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', '%SYS'], {
    input: `${['Set $NAMESPACE=$Select(##class(%SYS.Namespace).Exists("HSCUSTOM"):"HSCUSTOM",1:"USER")', ...lines, 'Halt'].join('\n')}\n`,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  const values = {};
  for (const name of names) values[name] = new RegExp(`OCU-${name}-START:(.*?):OCU-${name}-END`).exec(output)?.[1] ?? null;
  return { values, output };
}

const marker = (name, expression) => `Write "OCU"_"-${name}-START:"_(${expression})_":OCU"_"-${name}-END",!`;

before(async () => {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates a principal, so it never runs inside the live container');
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);
  const created = irisSession(
    [
      'Set tUser=##class(OcuPilot.Test.TurnWireFixture).#USERA',
      `Set tSC=##class(OcuPilot.Test.TurnWireFixture).EnsurePrincipal(tUser,"${password}",##class(OcuPilot.Test.TurnWireFixture).Resources(1))`,
      marker('USER', 'tUser'),
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
  const removed = irisSession([marker('LEFT', '##class(OcuPilot.Test.TurnWireFixture).RemovePrincipals()')], ['LEFT']);
  assert.equal(removed.values.LEFT, '', `the probe principal and its role are gone: ${removed.output}`);
});

test('DW-378: a least-privileged principal sees the panel on two routes, with the configuration-empty state and no reminder banner', async () => {
  // Mutation (Rule 19): render the reminder banner whenever the instance is unconfigured, ignoring
  // the map's verdict -> this goes red on the banner count. For the computed style: delete the
  // `.ocu-panel-empty` block from `_components.scss`, rebuild and redeploy -> the style assertions
  // go red while the presence and text ones stay green, which is the gap DW-1162 named.
  //
  // The style is compared against the tokens themselves rather than against transcribed numbers:
  // this asserts that the sentence takes the body ramp and the on-surface-variant role, not that
  // the ramp is any particular size.
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  try {
    await page.goto(`${config.origin}${ROUTES[0]}`, { waitUntil: 'networkidle2' });
    await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
    await page.type('#ocu-signin-user', user);
    await page.type('#ocu-signin-password', password);
    await page.click('.ocu-signin-card button[type="submit"]');

    for (const [index, route] of ROUTES.entries()) {
      if (index > 0) {
        // A client-side route change, so the tab stays signed in as this principal.
        await page.evaluate((path) => {
          window.history.pushState({}, '', path);
          window.dispatchEvent(new PopStateEvent('popstate'));
        }, route);
        await page.waitForFunction((path) => window.location.pathname === new URL(path, 'http://x.invalid').pathname, {}, route);
      }
      await page.waitForSelector('app-panel [role="log"] .ocu-panel-empty', { timeout: config.navigationTimeoutMs });
      const seen = await page.evaluate(() => {
        const panel = document.querySelector('app-panel aside.ocu-panel');
        const sentence = panel.querySelector('.ocu-panel-empty');
        const computed = getComputedStyle(sentence);
        const root = getComputedStyle(document.documentElement);
        // One probe resolving every token the assertions compare against, so the expected side is
        // the token's own computed value rather than a number transcribed into the spec.
        const probe = document.createElement('span');
        probe.style.color = 'var(--ocu-on-surface-variant)';
        probe.style.fontFamily = 'var(--ocu-type-body-family)';
        probe.style.fontSize = 'var(--ocu-type-body-size)';
        probe.style.lineHeight = 'var(--ocu-type-body-line-height)';
        document.body.appendChild(probe);
        const probed = getComputedStyle(probe);
        const variant = probed.color;
        const bodyFamily = probed.fontFamily;
        const bodyLineHeight = probed.lineHeight;
        probe.remove();
        return {
          path: window.location.pathname,
          width: panel.getBoundingClientRect().width,
          empty: sentence.textContent?.trim() ?? '',
          banners: panel.querySelectorAll('.ocu-panel-banner').length,
          example: panel.querySelector('.ocu-proposal-card') !== null,
          composerDisabled: panel.querySelector('.ocu-panel-composer').getAttribute('aria-disabled'),
          notice: document.querySelector('app-instance-notice') !== null,
          style: {
            fontSize: computed.fontSize,
            fontWeight: computed.fontWeight,
            fontFamily: computed.fontFamily,
            lineHeight: computed.lineHeight,
            margin: `${computed.marginTop} ${computed.marginRight} ${computed.marginBottom} ${computed.marginLeft}`,
            color: computed.color,
          },
          tokens: {
            fontSize: root.getPropertyValue('--ocu-type-body-size').trim(),
            fontWeight: root.getPropertyValue('--ocu-type-body-weight').trim(),
            fontFamily: bodyFamily,
            lineHeight: bodyLineHeight,
            color: variant,
          },
        };
      });
      assert.equal(seen.path, new URL(route, 'http://x.invalid').pathname, 'on the route asked for');
      assert.equal(seen.notice, false, 'the frame, not the no-privileges notice');
      assert.ok(seen.width >= 320, `the panel is laid out: ${seen.width}`);
      assert.equal(seen.empty, STRINGS.agentGateEmptyState);
      assert.equal(seen.banners, 0, 'no administrator reminder for a caller who cannot configure a definition');
      assert.equal(seen.example, true, 'the example card beneath the sentence');
      assert.equal(seen.composerDisabled, 'true');
      // The rule block itself, which jsdom cannot see: the body ramp, no margin of its own inside
      // the transcript's own spacing, and the on-surface-variant role rather than full on-surface.
      assert.equal(seen.style.fontSize, seen.tokens.fontSize, "the sentence takes the body ramp's size");
      assert.equal(seen.style.fontWeight, seen.tokens.fontWeight, "and the body ramp's weight");
      // The ramp mixin sets five properties. Size, family and line height are load-bearing here;
      // the body role's weight (400) and tracking (`normal`) are the CSS initial values, so those
      // two assertions hold whether or not the ramp declares them and pin nothing on their own.
      assert.equal(seen.style.fontFamily, seen.tokens.fontFamily, "and its family");
      assert.equal(seen.style.lineHeight, seen.tokens.lineHeight, "and its line height");
      assert.equal(seen.style.margin, '0px 0px 0px 0px', 'with no margin of its own');
      assert.equal(seen.style.color, seen.tokens.color, "and the on-surface-variant role's colour");
    }
  } finally {
    await context.close();
  }
});
