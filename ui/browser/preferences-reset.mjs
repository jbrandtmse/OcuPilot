/**
 * Clear the signed-in account's **remembered screen and shell state** before a browser context
 * signs in (Story 15.5).
 *
 * **Why every spec needs this now.** Until Story 15.5 the six remembered things -- a screen's
 * sort, direction, filter and max-rows cap, the side bar's open state and the panel's width --
 * lived in `localStorage`, so a fresh `BrowserContext` started every scenario on the published
 * defaults by construction. They live on the instance now (AD-50), keyed by the one account every
 * spec here signs in as, so one test's filter is the next test's starting state -- across tests in
 * a file and across files in the suite. Measured: the processes list opened filtered to one row
 * because an earlier test had filtered it, and a dozen geometry assertions read a panel an earlier
 * test had dragged.
 *
 * Calling this where a context is created restores exactly the old slate, and nothing more: the
 * three **value** kinds are cleared and the two membership kinds -- favorites and recent items --
 * are left alone, because those already lived on the instance before this story and specs that
 * arrange them expect them to survive.
 *
 * A spec that is **about** this state surviving (`preferences-integration`,
 * `ui-state-survives-sign-out`) does its own clearing and does not call this.
 *
 * Refuses the live container's origin, the way every write-driving spec here does.
 */

import assert from 'node:assert/strict';

import { LIVE_CONTAINER, browserConfig } from '../browser.config.mjs';

const config = browserConfig();

const PREFERENCES_PATH = '/api/ocupilot/account/preferences';

/** The kinds that moved out of browser storage in Story 15.5, and only those. */
const VALUE_KINDS = ['view', 'refresh', 'shell'];

function authHeader() {
  return 'Basic ' + Buffer.from(`${config.username}:${config.password}`).toString('base64');
}

/** What the instance holds for one shell member of the signing-in account, or `null` for none. */
export async function rememberedShellMember(name) {
  const answer = await fetch(`${config.origin}${PREFERENCES_PATH}`, { headers: { Authorization: authHeader() } });
  const text = await answer.text();
  assert.equal(answer.status, 200, `the preferences read answers: ${text}`);
  const row = JSON.parse(text).shell.find((entry) => entry.name === name);
  return row === undefined ? null : row.value;
}

/** Forget every remembered view, refresh rate and piece of shell chrome for the signing-in account. */
export async function resetRememberedState() {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this helper writes the account\'s preferences, so it never runs against the live container');
  for (const kind of VALUE_KINDS) {
    const answer = await fetch(`${config.origin}${PREFERENCES_PATH}`, {
      method: 'POST',
      headers: { Authorization: authHeader(), 'Content-Type': 'application/json' },
      body: JSON.stringify({ kind, action: 'clear' }),
    });
    assert.equal(answer.status, 200, `the ${kind} kind cleared: ${await answer.text()}`);
  }
}
