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
 * **Every kind the store holds is cleared**, derived from `PREFERENCE_KINDS` rather than listed
 * here. The hand-listed three left favorites and recent items standing, and `recents-recorder.ts`
 * registers a visit on every navigation -- so recents grew across a whole suite run with no spec
 * arranging them, and Home's blocks opened on whatever the previous file had visited. The server
 * already accepts `clear` for the membership kinds (`Api/Preferences.cls`), so nothing but this
 * roster decides what is forgotten.
 *
 * **The per-user read-only choice is turned off too** (Story 14.5). It is not a preferences kind --
 * only `PUT /agent/restraint` writes it -- but it is remembered on the instance for the same
 * account, and one spec's leftover toggle would block every later spec's agent writes. A spec that
 * is about that choice surviving into a fresh context passes `keepReadOnlyForYou` for that one
 * context and turns the choice off itself afterwards.
 *
 * **The governance policy is put back to the default too** (Story 14.2). It is instance-wide, and
 * one spec's disabled key or read-only preset would refuse every later spec's agent writes, so the
 * reset reads the policy and saves no preset and every key inheriting at the version it read.
 *
 * A spec that is **about** this state surviving (`preferences-integration`,
 * `ui-state-survives-sign-out`) arranges and clears its own rows and does not call this.
 *
 * Refuses the live container's origin, the way every write-driving spec here does.
 */

import assert from 'node:assert/strict';

import { LIVE_CONTAINER, browserConfig } from '../browser.config.mjs';

/** The roster of kinds, taken from the client's own source so the two cannot drift (DW-1447). */
const { PREFERENCE_KINDS } = await import(
  new URL('../src/app/core/account-preferences.ts', import.meta.url).href
);

const config = browserConfig();

const PREFERENCES_PATH = '/api/ocupilot/account/preferences';

const RESTRAINT_PATH = '/api/ocupilot/agent/restraint';

const GOVERNANCE_PATH = '/api/ocupilot/agent/governance';

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

/**
 * Forget everything the instance remembers about the signing-in account, kind by kind, and turn
 * its read-only choice off unless `keepReadOnlyForYou` is set.
 */
export async function resetRememberedState({ keepReadOnlyForYou = false } = {}) {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this helper writes the account\'s preferences, so it never runs against the live container');
  for (const kind of PREFERENCE_KINDS) {
    const answer = await fetch(`${config.origin}${PREFERENCES_PATH}`, {
      method: 'POST',
      headers: { Authorization: authHeader(), 'Content-Type': 'application/json' },
      body: JSON.stringify({ kind, action: 'clear' }),
    });
    assert.equal(answer.status, 200, `the ${kind} kind cleared: ${await answer.text()}`);
  }
  if (!keepReadOnlyForYou) await resetReadOnlyForYou();
  await resetGovernancePolicy();
}

/**
 * Put the governance policy back to the default (Story 14.2): no preset, every key inheriting,
 * saved at the version the read answered, asserting both answers.
 */
export async function resetGovernancePolicy() {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this helper writes the instance\'s governance policy, so it never runs against the live container');
  const read = await fetch(`${config.origin}${GOVERNANCE_PATH}`, { headers: { Authorization: authHeader() } });
  const text = await read.text();
  assert.equal(read.status, 200, `the governance policy reads: ${text}`);
  const policy = JSON.parse(text);
  const settings = {};
  for (const row of Array.isArray(policy.keys) ? policy.keys : []) settings[row.key] = 'inherit';
  const rowVersion = typeof policy.rowVersion === 'number' ? policy.rowVersion : 0;
  const answer = await fetch(`${config.origin}${GOVERNANCE_PATH}`, {
    method: 'PUT',
    headers: { Authorization: authHeader(), 'Content-Type': 'application/json' },
    body: JSON.stringify({ preset: '', settings, rowVersion }),
  });
  assert.equal(answer.status, 200, `the governance policy was put back to the default: ${await answer.text()}`);
}

/** Turn the signing-in account's own read-only choice off (Story 14.5), asserting the answer. */
export async function resetReadOnlyForYou() {
  assert.notEqual(config.container, LIVE_CONTAINER, 'this helper writes the account\'s read-only choice, so it never runs against the live container');
  const answer = await fetch(`${config.origin}${RESTRAINT_PATH}`, {
    method: 'PUT',
    headers: { Authorization: authHeader(), 'Content-Type': 'application/json' },
    body: JSON.stringify({ readOnly: false }),
  });
  assert.equal(answer.status, 200, `the read-only choice was turned off: ${await answer.text()}`);
}
