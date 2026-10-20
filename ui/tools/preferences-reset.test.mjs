/**
 * What `browser/preferences-reset.mjs` pins: the browser suite's between-context reset forgets
 * **every** kind the preference store holds, and the roster it derives that from is the same five
 * route kinds `OcuPilot.Kernel.State.Pref` declares.
 *
 * The helper cleared a hand-listed three (`view`, `refresh`, `shell`) while `recents-recorder.ts`
 * registered a visit on every navigation, so recent items accumulated across a whole suite run
 * with no spec arranging them (DW-1447). A hand-listed set cannot be told apart from a complete
 * one by reading it, so this derives both sides: the cleared set from the helper's own POSTs, and
 * the expected set from the ObjectScript parameters.
 *
 * Reaches no instance -- `fetch` is stubbed. `browser/preferences-reset.mjs` resolves
 * `browserConfig()` on first use inside each exported function, so importing it needs neither
 * browser variable; this file clears `OCUPILOT_BROWSER_ORIGIN` and `OCUPILOT_BROWSER_CONTAINER`
 * before the import, sets them to slot A's pair for its own calls, and restores them after.
 *
 * Mutations (Rule 19), each applied, observed red and reverted:
 * - restore `VALUE_KINDS = ['view','refresh','shell']` in place of `PREFERENCE_KINDS` -> "the reset
 *   clears every kind the roster holds" goes red, naming `favorite` and `recent` as uncleared.
 * - drop `SHELL_KIND` from `PREFERENCE_VALUE_KINDS` -> "the roster is the five kinds Pref.cls
 *   declares" goes red.
 * - resolve `browserConfig()` at module scope in `browser/preferences-reset.mjs` -> this file fails
 *   to load with neither variable set.
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import test, { after, before } from 'node:test';
import { fileURLToPath } from 'node:url';

import { DEFAULT_CONTAINER, DEFAULT_ORIGIN } from '../browser.config.mjs';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(here, '..', '..');

const { PREFERENCE_KINDS, PREFERENCE_MEMBERSHIP_KINDS } = await import(
  new URL('../src/app/core/account-preferences.ts', import.meta.url).href
);
/** The browser variables this file sets for its own calls, and what each held before. */
const BROWSER_VARIABLES = {
  OCUPILOT_BROWSER_ORIGIN: DEFAULT_ORIGIN,
  OCUPILOT_BROWSER_CONTAINER: DEFAULT_CONTAINER,
};
const heldVariables = {};

// The import below meets neither variable, whatever the shell exports, so a module-scope
// `browserConfig()` in the helper fails this file's load.
for (const name of Object.keys(BROWSER_VARIABLES)) {
  heldVariables[name] = process.env[name];
  delete process.env[name];
}

const { resetRememberedState } = await import(
  new URL('../browser/preferences-reset.mjs', import.meta.url).href
);

before(() => {
  for (const [name, value] of Object.entries(BROWSER_VARIABLES)) process.env[name] = value;
});

after(() => {
  for (const name of Object.keys(BROWSER_VARIABLES)) {
    if (heldVariables[name] === undefined) delete process.env[name];
    else process.env[name] = heldVariables[name];
  }
});

/**
 * The `Kind` the preferences route never serves: the per-user read-only choice (Story 14.5), which
 * only `PUT /agent/restraint` writes and `resetReadOnlyForYou` turns off.
 */
const RESTRAINT_KIND = 'restraint';

/**
 * The `Kind` values `Kernel/State/Pref.cls` declares for the preferences route, read from the class
 * rather than recalled.
 */
function declaredKinds() {
  const source = readFileSync(join(REPO_ROOT, 'src', 'OcuPilot', 'Kernel', 'State', 'Pref.cls'), 'utf8');
  const found = [];
  const pattern = /^Parameter\s+KIND[A-Z]*\s+As\s+%String\s*=\s*"([^"]+)"\s*;/gm;
  let match = pattern.exec(source);
  while (match !== null) {
    found.push(match[1]);
    match = pattern.exec(source);
  }
  assert.ok(found.includes(RESTRAINT_KIND), `Pref.cls declares the restraint kind: ${found.join(', ')}`);
  return found.filter((kind) => kind !== RESTRAINT_KIND);
}

/** Run the reset with `fetch` stubbed, answering 200 to everything, and collect the kinds posted. */
async function clearedKinds(options) {
  return (await sentByReset(options)).posted;
}

/** Run the reset with `fetch` stubbed, and collect both the POSTs and the PUTs it sent. */
async function sentByReset(options) {
  const real = globalThis.fetch;
  const posted = [];
  const put = [];
  globalThis.fetch = async (url, init) => {
    if (init !== undefined && init.method === 'POST') posted.push(JSON.parse(init.body));
    if (init !== undefined && init.method === 'PUT') put.push({ path: new URL(url).pathname, body: JSON.parse(init.body) });
    return { status: 200, text: async () => '{}' };
  };
  try {
    await resetRememberedState(options);
  } finally {
    globalThis.fetch = real;
  }
  return { posted, put };
}

test('with either browser variable unset or empty the reset is refused before any request', async () => {
  // Mutation (Rule 19): fall back to `DEFAULT_CONTAINER` or `DEFAULT_ORIGIN` in `browserConfig` ->
  // this goes red, and the reset would write to an instance the run never named.
  for (const name of Object.keys(BROWSER_VARIABLES)) {
    for (const value of [undefined, '']) {
      const held = process.env[name];
      const real = globalThis.fetch;
      let requests = 0;
      globalThis.fetch = async () => {
        requests += 1;
        return { status: 200, text: async () => '{}' };
      };
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
      try {
        await assert.rejects(() => resetRememberedState(), /must both be set and not empty/, `${name} ${value === undefined ? 'unset' : 'empty'}`);
        assert.equal(requests, 0, `no request is sent with ${name} ${value === undefined ? 'unset' : 'empty'}`);
      } finally {
        globalThis.fetch = real;
        process.env[name] = held;
      }
    }
  }
});

test('the roster is the five route kinds Pref.cls declares -- neither side hand-listed against the other', () => {
  const declared = declaredKinds();
  assert.equal(declared.length, 5, `Pref.cls declares five KIND parameters: ${declared.join(', ')}`);
  assert.deepEqual([...PREFERENCE_KINDS].sort(), [...declared].sort());
});

test('the reset clears every kind the roster holds, with the clear action', async () => {
  const posted = await clearedKinds();
  assert.deepEqual(
    posted.map((body) => body.kind).sort(),
    [...PREFERENCE_KINDS].sort(),
    'a kind the helper does not clear is one spec\'s state becoming the next spec\'s starting state'
  );
  for (const body of posted) {
    assert.equal(body.action, 'clear', `${body.kind} is cleared, not set`);
  }
});

test('the membership kinds are in the cleared set -- the three under-cleared ones are the defect', async () => {
  // Named rather than left to the deepEqual above: `recent` grows with no spec arranging it
  // (`recents-recorder.ts` registers a visit on every navigation), which is how DW-1447 was found.
  const cleared = new Set((await clearedKinds()).map((body) => body.kind));
  for (const kind of PREFERENCE_MEMBERSHIP_KINDS) {
    assert.ok(cleared.has(kind), `${kind} is cleared between contexts`);
  }
});

test('Story 14.5: the reset turns the account\'s read-only choice off, unless a spec keeps it for one context', async () => {
  // Mutation (Rule 19): drop the `resetReadOnlyForYou` call from `resetRememberedState` -> the
  // first assertion goes red, and one spec's leftover switch blocks every later spec's writes.
  const { put } = await sentByReset();
  assert.deepEqual(put, [{ path: '/api/ocupilot/agent/restraint', body: { readOnly: false } }]);
  const kept = await sentByReset({ keepReadOnlyForYou: true });
  assert.deepEqual(kept.put, [], 'a spec about the choice surviving keeps it for that context');
});

test('Story 14.2: the reset puts every key the policy read answers back to inherit, with no preset, at the version it read', async () => {
  // Mutation (Rule 19): drop the `resetGovernancePolicy` call from `resetRememberedState` -> this
  // goes red, and one spec's disabled key refuses every later spec's agent writes.
  const real = globalThis.fetch;
  const put = [];
  globalThis.fetch = async (url, init) => {
    const path = new URL(url).pathname;
    if (init !== undefined && init.method === 'PUT' && path.endsWith('/agent/governance')) put.push(JSON.parse(init.body));
    const body = path.endsWith('/agent/governance') && (init === undefined || init.method === undefined)
      ? { preset: 'read-only', rowVersion: 4, keys: [{ key: 'webapp.list.update' }, { key: 'security.auditing.purge' }] }
      : {};
    return { status: 200, text: async () => JSON.stringify(body) };
  };
  try {
    await resetRememberedState();
  } finally {
    globalThis.fetch = real;
  }
  assert.deepEqual(put, [
    { preset: '', settings: { 'webapp.list.update': 'inherit', 'security.auditing.purge': 'inherit' }, rowVersion: 4 },
  ]);
});

test('Story 14.2: a policy that already reads default is left alone, so the reset writes no audit row', async () => {
  // Mutation (Rule 19): drop the early return in `resetGovernancePolicy` -> this goes red.
  const real = globalThis.fetch;
  const put = [];
  globalThis.fetch = async (url, init) => {
    const path = new URL(url).pathname;
    if (init !== undefined && init.method === 'PUT' && path.endsWith('/agent/governance')) put.push(JSON.parse(init.body));
    const body = path.endsWith('/agent/governance') && (init === undefined || init.method === undefined)
      ? { preset: '', rowVersion: 7, keys: [{ key: 'webapp.list.update', setting: 'inherit' }, { key: 'security.auditing.purge', setting: 'inherit' }] }
      : {};
    return { status: 200, text: async () => JSON.stringify(body) };
  };
  try {
    await resetRememberedState();
  } finally {
    globalThis.fetch = real;
  }
  assert.deepEqual(put, []);
});

test('Story 14.6: the reset puts a set turns-an-hour limit back to none, at the version it read', async () => {
  // Mutation (Rule 19): drop the `resetTurnLimit` call from `resetRememberedState` -> this goes
  // red, and one spec's limit refuses every later spec's second Send.
  const real = globalThis.fetch;
  const put = [];
  globalThis.fetch = async (url, init) => {
    const path = new URL(url).pathname;
    if (init !== undefined && init.method === 'PUT' && path.endsWith('/agent/switches')) put.push(JSON.parse(init.body));
    const body = path.endsWith('/agent/switches') && (init === undefined || init.method === undefined)
      ? { turnsPerHour: 3, rowVersion: 7 }
      : {};
    return { status: 200, text: async () => JSON.stringify(body) };
  };
  try {
    await resetRememberedState();
  } finally {
    globalThis.fetch = real;
  }
  assert.deepEqual(put, [{ turnsPerHour: 0, rowVersion: 7 }]);
});

test('Story 14.6: a limit that already reads none is left alone, so the reset writes no audit row', async () => {
  // Mutation (Rule 19): drop the early return in `resetTurnLimit` -> this goes red.
  const real = globalThis.fetch;
  const put = [];
  globalThis.fetch = async (url, init) => {
    const path = new URL(url).pathname;
    if (init !== undefined && init.method === 'PUT' && path.endsWith('/agent/switches')) put.push(JSON.parse(init.body));
    const body = path.endsWith('/agent/switches') && (init === undefined || init.method === undefined)
      ? { turnsPerHour: 0, rowVersion: 7 }
      : {};
    return { status: 200, text: async () => JSON.stringify(body) };
  };
  try {
    await resetRememberedState();
  } finally {
    globalThis.fetch = real;
  }
  assert.deepEqual(put, []);
});
