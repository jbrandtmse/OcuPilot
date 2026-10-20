/**
 * Pins `browserConfig`'s target guard: a browser run names its throwaway through
 * `OCUPILOT_BROWSER_ORIGIN` and `OCUPILOT_BROWSER_CONTAINER`, both set and not empty, so a spec's
 * pages and its `docker exec` legs never reach two different throwaways, and a run from another
 * slot never drives slot A's by default. Needs nothing but Node.
 *
 * Mutations (Rule 19), each applied, observed red and reverted:
 * - `env.OCUPILOT_BROWSER_ORIGIN ?? DEFAULT_ORIGIN` restored in `browserConfig`, or the container's
 *   alike -> "either variable alone, or an empty value, is refused" goes red.
 * - Both fallbacks restored -> "both variables unset is refused" goes red too.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';

import { DEFAULT_CONTAINER, DEFAULT_ORIGIN, browserConfig } from '../browser.config.mjs';

const BOTH = /OCUPILOT_BROWSER_ORIGIN and OCUPILOT_BROWSER_CONTAINER must both be set and not empty/;

test('both variables unset is refused, naming both and slot A\'s pair as the example', () => {
  assert.throws(() => browserConfig({}), BOTH);
  assert.throws(
    () => browserConfig({}),
    new RegExp(`OCUPILOT_BROWSER_ORIGIN=${DEFAULT_ORIGIN} OCUPILOT_BROWSER_CONTAINER=${DEFAULT_CONTAINER}`)
  );
});

test('either variable alone, or an empty value, is refused, naming both', () => {
  const cases = [
    { OCUPILOT_BROWSER_ORIGIN: 'http://localhost:52777' },
    { OCUPILOT_BROWSER_CONTAINER: 'ocupilot-b-ci' },
    { OCUPILOT_BROWSER_ORIGIN: DEFAULT_ORIGIN },
    { OCUPILOT_BROWSER_CONTAINER: DEFAULT_CONTAINER },
    { OCUPILOT_BROWSER_ORIGIN: 'http://localhost:52777', OCUPILOT_BROWSER_CONTAINER: '' },
    { OCUPILOT_BROWSER_ORIGIN: '', OCUPILOT_BROWSER_CONTAINER: 'ocupilot-b-ci' },
    { OCUPILOT_BROWSER_ORIGIN: '', OCUPILOT_BROWSER_CONTAINER: '' },
  ];
  for (const env of cases) {
    assert.throws(() => browserConfig(env), BOTH, JSON.stringify(env));
  }
});

test('both variables set resolves to exactly them', () => {
  const slotA = browserConfig({ OCUPILOT_BROWSER_ORIGIN: DEFAULT_ORIGIN, OCUPILOT_BROWSER_CONTAINER: DEFAULT_CONTAINER });
  assert.equal(slotA.origin, DEFAULT_ORIGIN);
  assert.equal(slotA.container, DEFAULT_CONTAINER);
  const slotB = browserConfig({
    OCUPILOT_BROWSER_ORIGIN: 'http://localhost:52777',
    OCUPILOT_BROWSER_CONTAINER: 'ocupilot-b-ci',
  });
  assert.equal(slotB.origin, 'http://localhost:52777');
  assert.equal(slotB.container, 'ocupilot-b-ci');
});

test('the live container is refused, naming the variable', () => {
  assert.throws(
    () => browserConfig({ OCUPILOT_BROWSER_ORIGIN: 'http://localhost:52774', OCUPILOT_BROWSER_CONTAINER: 'ocupilot' }),
    /OCUPILOT_BROWSER_CONTAINER is ocupilot, a live or development instance/
  );
});

test('every slot development container is refused, naming the variable', () => {
  for (const [container, port] of [['ocupilot-slot-b', 52775], ['ocupilot-slot-c', 52778]]) {
    assert.throws(
      () => browserConfig({ OCUPILOT_BROWSER_ORIGIN: `http://localhost:${port}`, OCUPILOT_BROWSER_CONTAINER: container }),
      new RegExp(`OCUPILOT_BROWSER_CONTAINER is ${container}, a live or development instance`)
    );
  }
});
