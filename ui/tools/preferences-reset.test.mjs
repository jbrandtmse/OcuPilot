/**
 * What `browser/preferences-reset.mjs` pins: the browser suite's between-context reset forgets
 * **every** kind the preference store holds, and the roster it derives that from is the same five
 * `OcuPilot.Kernel.State.Pref` declares.
 *
 * The helper cleared a hand-listed three (`view`, `refresh`, `shell`) while `recents-recorder.ts`
 * registered a visit on every navigation, so recent items accumulated across a whole suite run
 * with no spec arranging them (DW-1447). A hand-listed set cannot be told apart from a complete
 * one by reading it, so this derives both sides: the cleared set from the helper's own POSTs, and
 * the expected set from the ObjectScript parameters.
 *
 * Needs nothing from the environment -- `fetch` is stubbed, so no instance is reached.
 *
 * Mutations (Rule 19), each applied, observed red and reverted:
 * - restore `VALUE_KINDS = ['view','refresh','shell']` in place of `PREFERENCE_KINDS` -> "the reset
 *   clears every kind the roster holds" goes red, naming `favorite` and `recent` as uncleared.
 * - drop `SHELL_KIND` from `PREFERENCE_VALUE_KINDS` -> "the roster is the five kinds Pref.cls
 *   declares" goes red.
 */

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = join(here, '..', '..');

const { PREFERENCE_KINDS, PREFERENCE_MEMBERSHIP_KINDS } = await import(
  new URL('../src/app/core/account-preferences.ts', import.meta.url).href
);
const { resetRememberedState } = await import(
  new URL('../browser/preferences-reset.mjs', import.meta.url).href
);

/** The `Kind` values `Kernel/State/Pref.cls` declares, read from the class rather than recalled. */
function declaredKinds() {
  const source = readFileSync(join(REPO_ROOT, 'src', 'OcuPilot', 'Kernel', 'State', 'Pref.cls'), 'utf8');
  const found = [];
  const pattern = /^Parameter\s+KIND[A-Z]*\s+As\s+%String\s*=\s*"([^"]+)"\s*;/gm;
  let match = pattern.exec(source);
  while (match !== null) {
    found.push(match[1]);
    match = pattern.exec(source);
  }
  return found;
}

/** Run the reset with `fetch` stubbed, answering 200 to everything, and collect the kinds posted. */
async function clearedKinds() {
  const real = globalThis.fetch;
  const posted = [];
  globalThis.fetch = async (url, init) => {
    if (init !== undefined && init.method === 'POST') posted.push(JSON.parse(init.body));
    return { status: 200, text: async () => '{}' };
  };
  try {
    await resetRememberedState();
  } finally {
    globalThis.fetch = real;
  }
  return posted;
}

test('the roster is the five kinds Pref.cls declares -- neither side hand-listed against the other', () => {
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
