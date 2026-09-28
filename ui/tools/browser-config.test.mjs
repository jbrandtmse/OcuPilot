/**
 * Pins `browserConfig`'s container guard: a browser run pointed at a non-default origin must name
 * its container, and one naming a non-default container must name its origin, so a spec's pages and
 * its `docker exec` legs never reach two different throwaways. Needs nothing but Node.
 */
import { test } from 'node:test';
import assert from 'node:assert/strict';

import { DEFAULT_CONTAINER, DEFAULT_ORIGIN, browserConfig } from '../browser.config.mjs';

test('the default origin with no container resolves to the default container', () => {
  const config = browserConfig({});
  assert.equal(config.origin, DEFAULT_ORIGIN);
  assert.equal(config.container, DEFAULT_CONTAINER);
});

test('a non-default origin with no container is refused, naming the variable', () => {
  assert.throws(
    () => browserConfig({ OCUPILOT_BROWSER_ORIGIN: 'http://localhost:52777' }),
    /OCUPILOT_BROWSER_CONTAINER is unset/
  );
  assert.throws(
    () => browserConfig({ OCUPILOT_BROWSER_ORIGIN: 'http://localhost:52777', OCUPILOT_BROWSER_CONTAINER: '' }),
    /OCUPILOT_BROWSER_CONTAINER is unset/
  );
});

test('a non-default container with the default origin is refused, naming the origin variable', () => {
  assert.throws(
    () => browserConfig({ OCUPILOT_BROWSER_CONTAINER: 'ocupilot-b-ci' }),
    /OCUPILOT_BROWSER_ORIGIN is the default/
  );
  assert.equal(browserConfig({ OCUPILOT_BROWSER_CONTAINER: DEFAULT_CONTAINER }).container, DEFAULT_CONTAINER);
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

test('a non-default origin with its container resolves to that container', () => {
  const config = browserConfig({
    OCUPILOT_BROWSER_ORIGIN: 'http://localhost:52777',
    OCUPILOT_BROWSER_CONTAINER: 'ocupilot-b-ci',
  });
  assert.equal(config.origin, 'http://localhost:52777');
  assert.equal(config.container, 'ocupilot-b-ci');
});
