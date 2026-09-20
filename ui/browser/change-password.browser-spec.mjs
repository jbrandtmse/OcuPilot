/**
 * Changing your own password in a real browser, against the throwaway instance (Story 15.1).
 *
 * jsdom moves no real focus, runs no real request and holds no session, so what is only
 * observable here is: the account menu's arrow model moving actual focus between two items, the
 * dialog opening from a keyboard activation, a refusal rendered from a **real** 422 carrying the
 * instance's own policy sentence, a change the instance actually applied, and the tab still
 * authorized afterwards. `src/app/shell/account-menu.spec.ts` and
 * `src/app/shell/change-password-dialog.spec.ts` pin the DOM shape and the decode;
 * `src/OcuPilot/Test/AccountPasswordWire.cls` pins the route's four outcomes over the wire.
 *
 * **It never touches the account the rest of the suite signs in with.** One throwaway user and
 * its role are created in `before` and deleted in `after`; the change under test is that user's
 * own. The role holds read on the install namespace's code database and `%Admin_Operate:USE`,
 * which is what carries it past the API's own administrative gate.
 *
 * Run: `npm run build`, `docker cp dist/ocupilot-ui/browser/. <throwaway>:/durable/iris/csp/ocupilot/`,
 * then `npm run test:browser`.
 */

import { test, before, after } from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { randomBytes } from 'node:crypto';
import puppeteer from 'puppeteer';

import { LIVE_CONTAINER, READINESS_PATH, browserConfig, launchOptions } from '../browser.config.mjs';
import { loadStrings } from '../tools/strings.mjs';
import { parseMarkers } from './iris-session.mjs';
import { leaveFirstLoginGate } from './shell-entry.mjs';

const STRINGS = loadStrings();

const config = browserConfig();

const PROBE_USER = 'OcuPilotBrowserAccount';
const PROBE_ROLE = 'OcuPilotBrowserAccountRole';
const FIRST_PASSWORD = `OcuBrowser${randomBytes(9).toString('hex')}9Zq`;
const NEXT_PASSWORD = `OcuBrowser${randomBytes(9).toString('hex')}7Xk`;
/** Shorter than the three this build's `3.255ANP` pattern admits, so the policy leg really fires. */
const TOO_SHORT = 'ab';

const HOME_URL = '/ocupilot/?ns=HSCUSTOM';
const INSTANCE_PATH = '/api/ocupilot/instance';
const CHANGE_PASSWORD_PATH = '/api/ocupilot/account/password';
const MESSAGES_PATH = '/api/ocupilot/logs/messages?maxBytes=262144';

let browser = null;
let created = false;

/** Run `lines` through `iris session` in the install namespace and read back its markers. */
function irisSession(lines, names) {
  const input = `${[...lines, 'Halt'].join('\n')}\n`;
  const result = spawnSync('docker', ['exec', '-i', config.container, 'iris', 'session', 'iris', '-U', 'HSCUSTOM'], {
    input,
    encoding: 'utf8',
    timeout: 600000,
  });
  const output = `${result.stdout ?? ''}${result.stderr ?? ''}`;
  return { values: parseMarkers(output, names), output };
}

before(async () => {
  // One line, because `tools/angular-json.test.mjs` matches this exact refusal on any browser
  // spec that runs docker commands.
  assert.notEqual(config.container, LIVE_CONTAINER, 'this spec creates a principal and changes its password, so it never runs inside the live container');
  assert.equal(
    /^ocupilot-slot-/.test(config.container),
    false,
    `a slot dev instance is as untouchable as the live one: ${config.container}`
  );
  const ready = await (await fetch(`${config.origin}${READINESS_PATH}`)).json();
  assert.equal(ready.state, 'installed', `the throwaway must be installed, not ${JSON.stringify(ready)}`);

  const { values, output } = irisSession(
    [
      'Set tNs = ##class(OcuPilot.Install.Installer).ResolveNamespace()',
      'Set $NAMESPACE = "%SYS"',
      'Set tNsObj = ##class(Config.Namespaces).Open(tNs)',
      'Set tDbObj = ##class(Config.Databases).Open(tNsObj.Routines)',
      'Set tSysDb = ##class(SYS.Database).%OpenId(tDbObj.Directory)',
      `Set tRes = tSysDb.ResourceName_":R,%Admin_Operate:U"`,
      `If ##class(Security.Roles).Exists("${PROBE_ROLE}") Do ##class(Security.Roles).Delete("${PROBE_ROLE}")`,
      `Set tSC = ##class(Security.Roles).Create("${PROBE_ROLE}", "OcuPilot browser spec principal role (throwaway)", tRes, "")`,
      `If ##class(Security.Users).Exists("${PROBE_USER}") Do ##class(Security.Users).Delete("${PROBE_USER}")`,
      `Set tSC2 = ##class(Security.Users).Create("${PROBE_USER}", "${PROBE_ROLE}", "${FIRST_PASSWORD}", "OcuPilot browser spec principal (throwaway)", "", "", "", 0, 1, "Deleted by change-password.browser-spec.mjs")`,
      'Write "OCU-MADE-START:",(+$System.Status.IsOK(tSC) * +$System.Status.IsOK(tSC2)),":OCU-MADE-END",!',
    ],
    ['MADE']
  );
  assert.equal(values.MADE, '1', `the throwaway principal was created:\n${output}`);
  created = true;

  browser = await puppeteer.launch(launchOptions(config));
});

after(async () => {
  if (browser !== null) await browser.close();
  if (!created) return;
  const { values, output } = irisSession(
    [
      'Set $NAMESPACE = "%SYS"',
      `If ##class(Security.Users).Exists("${PROBE_USER}") Do ##class(Security.Users).Delete("${PROBE_USER}")`,
      `If ##class(Security.Roles).Exists("${PROBE_ROLE}") Do ##class(Security.Roles).Delete("${PROBE_ROLE}")`,
      `Write "OCU-GONE-START:",'##class(Security.Users).Exists("${PROBE_USER}") && '##class(Security.Roles).Exists("${PROBE_ROLE}"),":OCU-GONE-END",!`,
    ],
    ['GONE']
  );
  assert.equal(values.GONE, '1', `no principal this spec created survives it:\n${output}`);
});

function authHeader(user, password) {
  return 'Basic ' + Buffer.from(`${user}:${password}`).toString('base64');
}

/** A fresh context signed in through the form as the throwaway principal, standing on Home. */
async function signedInAsProbe(password) {
  const context = await browser.createBrowserContext();
  const page = await context.newPage();
  page.setDefaultNavigationTimeout(config.navigationTimeoutMs);
  await page.setViewport(config.viewport);
  await page.goto(`${config.origin}${HOME_URL}`, { waitUntil: 'networkidle2' });
  await page.waitForSelector('#ocu-signin-user', { visible: true, timeout: config.navigationTimeoutMs });
  await page.type('#ocu-signin-user', PROBE_USER);
  await page.type('#ocu-signin-password', password);
  await page.click('.ocu-signin-card button[type="submit"]');
  await page.waitForSelector('.ocu-account-trigger', { timeout: config.navigationTimeoutMs });
  await leaveFirstLoginGate(page, config.navigationTimeoutMs, HOME_URL);
  return { context, page };
}

/** Which menu item holds real focus, by its text. */
function focusedItemText(page) {
  return page.evaluate(() => document.activeElement?.textContent?.trim() ?? '');
}

/** Open the menu and wait for the first item to take focus. */
async function openMenu(page) {
  await page.click('.ocu-account-trigger');
  await page.waitForSelector('.ocu-account-panel [role="menuitem"]', { timeout: config.navigationTimeoutMs });
  await page.waitForFunction(
    () => document.activeElement?.getAttribute('role') === 'menuitem',
    { timeout: config.navigationTimeoutMs }
  );
}

/**
 * Fill the two dialog fields and press the confirming action.
 *
 * **Both** fields are filled by real key presses, not by assigning `.value`: an input the user
 * cannot type into -- `readonly`, or covered by the reveal toggle -- passes every assignment-based
 * fill in this repository and fails here, which is the only place that difference is observable.
 * Filling either one by assignment would leave that field's own typeability unpinned.
 */
async function submit(page, current, next) {
  const inputs = await page.$$('.ocu-dialog input.ocu-field-input');
  assert.equal(inputs.length, 2, 'the dialog carries both masked fields');
  await inputs[0].click();
  await page.keyboard.type(current);
  await inputs[1].click();
  await page.keyboard.type(next);
  const typed = await page.$$eval('.ocu-dialog input.ocu-field-input', (nodes) =>
    nodes.map((node) => node.value)
  );
  assert.deepEqual(typed, [current, next], 'both masked fields accept real keystrokes');
  await page.click('.ocu-dialog-actions .ocu-button-primary');
}

test('AC7, DW-115: the arrow model moves real focus between the two items, with wrap-around and Home/End', async () => {
  // Mutation (Rule 19): drop the `% items.length` wrap from `onMenuKeydown` in `account-menu.ts`
  // -> the two wrap assertions go red. jsdom moves focus on `.focus()` but never through a real
  // key press, so the whole path from keydown to `document.activeElement` is only observable here.
  const { context, page } = await signedInAsProbe(FIRST_PASSWORD);
  try {
    await openMenu(page);
    const labels = await page.$$eval('.ocu-account-panel [role="menuitem"]', (nodes) =>
      nodes.map((node) => ({ text: node.textContent.trim(), tabindex: node.getAttribute('tabindex') }))
    );
    assert.deepEqual(labels, [
      { text: STRINGS.accountChangePassword, tabindex: '-1' },
      { text: STRINGS.actionSignOut, tabindex: '-1' },
    ]);
    assert.equal(await focusedItemText(page), STRINGS.accountChangePassword);

    await page.keyboard.press('ArrowDown');
    assert.equal(await focusedItemText(page), STRINGS.actionSignOut);
    await page.keyboard.press('ArrowDown');
    assert.equal(await focusedItemText(page), STRINGS.accountChangePassword, 'ArrowDown wraps');
    await page.keyboard.press('ArrowUp');
    assert.equal(await focusedItemText(page), STRINGS.actionSignOut, 'ArrowUp wraps');
    await page.keyboard.press('Home');
    assert.equal(await focusedItemText(page), STRINGS.accountChangePassword);
    await page.keyboard.press('End');
    assert.equal(await focusedItemText(page), STRINGS.actionSignOut);

    // Escape, through the shell's one overlay authority, and focus really lands on the trigger.
    await page.keyboard.press('Escape');
    await page.waitForFunction(
      () => document.querySelector('.ocu-account-panel') === null,
      { timeout: config.navigationTimeoutMs }
    );
    assert.equal(
      await page.evaluate(() => document.activeElement?.className ?? ''),
      'ocu-account-trigger'
    );
  } finally {
    await context.close();
  }
});

test('AC8: Escape on the open dialog sends nothing and returns focus to the menu trigger', async () => {
  const { context, page } = await signedInAsProbe(FIRST_PASSWORD);
  try {
    await openMenu(page);
    await page.keyboard.press('Enter');
    await page.waitForSelector('.ocu-dialog[role="dialog"]', { timeout: config.navigationTimeoutMs });
    // The shared dialog's initial focus is the first field, and both fields are empty.
    assert.deepEqual(
      await page.$$eval('.ocu-dialog input.ocu-field-input', (nodes) =>
        nodes.map((node) => ({ type: node.type, value: node.value, focused: node === document.activeElement }))
      ),
      [
        { type: 'password', value: '', focused: true },
        { type: 'password', value: '', focused: false },
      ]
    );

    await page.keyboard.press('Escape');
    await page.waitForFunction(() => document.querySelector('.ocu-dialog') === null, {
      timeout: config.navigationTimeoutMs,
    });
    assert.equal(
      await page.evaluate(() => document.activeElement?.className ?? ''),
      'ocu-account-trigger'
    );
    // Nothing was announced, because nothing was changed.
    assert.equal(
      await page.$eval('app-account-menu [role="status"]', (node) => node.textContent.trim()),
      ''
    );
  } finally {
    await context.close();
  }
});

test("Integration AC, AC4: a policy-refused change renders the instance's own reason on newPassword, from a real 422", async () => {
  // Mutation (Rule 19): replace the violation's `reason` in `Api/Account.cls` with
  // `..#REASONACCOUNTPASSWORDPOLICY` -> the equality against the instance's own sentence goes red,
  // because the fallback is OcuPilot's wording and the instance's is not.
  //
  // The expected sentence is taken from the instance rather than transcribed: the same call the
  // handler makes, refused the same way, so nothing this spec asserts is a copy of vendor text.
  const probe = irisSession(
    [
      `Set tOk = $System.Security.ChangePassword("${PROBE_USER}", "${TOO_SHORT}", "${FIRST_PASSWORD}", .tSC)`,
      'Write "OCU-OK-START:",tOk,":OCU-OK-END",!',
      'Write "OCU-TEXT-START:",$System.Status.GetOneStatusText(tSC, 2),":OCU-TEXT-END",!',
    ],
    ['OK', 'TEXT']
  );
  assert.equal(probe.values.OK, '0', `the probe change is refused, so nothing moved:\n${probe.output}`);
  const instanceText = probe.values.TEXT;
  assert.ok(instanceText, `the instance names its own policy refusal:\n${probe.output}`);

  const { context, page } = await signedInAsProbe(FIRST_PASSWORD);
  try {
    await openMenu(page);
    await page.keyboard.press('Enter');
    await page.waitForSelector('.ocu-dialog[role="dialog"]', { timeout: config.navigationTimeoutMs });
    await submit(page, FIRST_PASSWORD, TOO_SHORT);
    await page.waitForSelector('.ocu-dialog .ocu-form-summary', { timeout: config.navigationTimeoutMs });

    const shown = await page.evaluate(() => {
      const fields = [...document.querySelectorAll('.ocu-dialog input.ocu-field-input')];
      const described = fields[1].getAttribute('aria-describedby');
      return {
        summary: document.querySelector('.ocu-dialog .ocu-form-summary').textContent.trim(),
        summaryRole: document.querySelector('.ocu-dialog .ocu-form-summary').getAttribute('role'),
        currentInvalid: fields[0].getAttribute('aria-invalid'),
        newInvalid: fields[1].getAttribute('aria-invalid'),
        describedBy: described,
        describedText: described === null ? '' : document.getElementById(described)?.textContent.trim(),
        stillOpen: document.querySelector('.ocu-dialog') !== null,
      };
    });
    assert.equal(shown.stillOpen, true, 'the dialog stays open on a refusal');
    assert.equal(shown.summaryRole, 'alert');
    assert.equal(shown.summary, instanceText, "the summary carries the instance's own sentence");
    assert.equal(shown.newInvalid, 'true', 'on the new password');
    assert.equal(shown.currentInvalid, 'false', 'and not on the current one');
    assert.equal(shown.describedText, instanceText, 'wired to the field through aria-describedby');
  } finally {
    await context.close();
  }
});

test('AC2, AC3, AC6: a correct change is applied, announced, and leaves the tab signed in -- with no password in any log line', async () => {
  // Mutation (Rule 19): drop the `changed.emit()` from `change-password-dialog.ts` -> the
  // announcement assertion goes red. Pass the current password as the new one in
  // `Api/Account.cls` -> the "signed in with the new password" leg goes red.
  const { context, page } = await signedInAsProbe(FIRST_PASSWORD);
  try {
    await openMenu(page);
    await page.keyboard.press('Enter');
    await page.waitForSelector('.ocu-dialog[role="dialog"]', { timeout: config.navigationTimeoutMs });
    await submit(page, FIRST_PASSWORD, NEXT_PASSWORD);
    await page.waitForFunction(() => document.querySelector('.ocu-dialog') === null, {
      timeout: config.navigationTimeoutMs,
    });

    assert.equal(
      await page.$eval('app-account-menu [role="status"]', (node) => node.textContent.trim()),
      STRINGS.accountPasswordChanged,
      'the polite region outlives the dialog and carries the published sentence'
    );
    assert.equal(
      await page.evaluate(() => document.activeElement?.className ?? ''),
      'ocu-account-trigger'
    );

    // AC3: the tab is not signed out -- the Bearer pair was already minted and authorization is
    // Bearer-only (AD-28), so the next API call still answers 200.
    const status = await page.evaluate(async (path) => {
      const pair = JSON.parse(sessionStorage.getItem('ocupilot.token-pair') ?? '{}');
      const answer = await fetch(path, {
        headers: { Authorization: `Bearer ${pair.accessToken ?? ''}` },
      });
      return answer.status;
    }, INSTANCE_PATH);
    assert.equal(status, 200, 'the tab is still authorized after the change');

    // AC6 / AD-47, on the surface the constraint names: neither value is anywhere in this tab's
    // storage. Both were on screen a moment ago, so an echo back into storage would be caught.
    const stored = await page.evaluate(() => {
      const read = (store) =>
        Object.keys(store)
          .map((key) => `${key}=${store.getItem(key) ?? ''}`)
          .join('\n');
      return `${read(sessionStorage)}\n${read(localStorage)}`;
    });
    for (const secret of [FIRST_PASSWORD, NEXT_PASSWORD]) {
      assert.equal(stored.includes(secret), false, 'no password value is written to browser storage');
    }

    // The route's one logging branch is the body refusal, and nothing the dialog sends can reach
    // it -- so drive it directly, carrying a real password, before reading the log back below.
    // Without this the log assertion cannot fail: the 200 and 422 paths log nothing at all.
    const refused = await page.evaluate(
      async (path, secret) => {
        const pair = JSON.parse(sessionStorage.getItem('ocupilot.token-pair') ?? '{}');
        const answer = await fetch(path, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${pair.accessToken ?? ''}`,
            'Content-Type': 'application/json',
          },
          body: `{"currentPassword":"${secret}","newPassword":"${secret}","userName":"_SYSTEM"}`,
        });
        return answer.status;
      },
      CHANGE_PASSWORD_PATH,
      NEXT_PASSWORD
    );
    assert.equal(refused, 422, 'the extra-member body is refused, through the branch that logs');
  } finally {
    await context.close();
  }

  // The change really landed: the new password authenticates and the old one does not.
  const withNew = await fetch(`${config.origin}${INSTANCE_PATH}`, {
    headers: { Authorization: authHeader(PROBE_USER, NEXT_PASSWORD) },
  });
  assert.equal(withNew.status, 200, 'the new password reaches the API');
  const withOld = await fetch(`${config.origin}${INSTANCE_PATH}`, {
    headers: { Authorization: authHeader(PROBE_USER, FIRST_PASSWORD) },
  });
  assert.equal(withOld.status, 401, 'and the old one no longer does');

  // Integration AC: every line OcuPilot wrote while this ran, read back through the product's own
  // log reader, holds neither password. The malformed body above is what makes this a real check:
  // `RenderBodyRefusal` is the only branch on this route that writes a log line, and it was sent a
  // body whose two members were the live password.
  const log = await fetch(`${config.origin}${MESSAGES_PATH}`, {
    headers: { Authorization: authHeader(config.username, config.password) },
  });
  assert.equal(log.status, 200, `messages.log is readable (HTTP ${log.status})`);
  const text = JSON.stringify(await log.json());
  // `TOO_SHORT` is deliberately not in this list: it is two characters, and a two-character
  // substring occurs in ordinary log text, so asserting its absence would fail on unrelated lines.
  for (const secret of [FIRST_PASSWORD, NEXT_PASSWORD]) {
    assert.equal(text.includes(secret), false, 'no password value reaches a log line');
  }
});
