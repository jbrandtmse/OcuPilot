/**
 * Pins `browserConfig`'s container guard: a browser run pointed at a non-default origin must name
 * its container, so a spec's `docker exec` legs never fall back to the default throwaway, which
 * serves a different origin. Needs nothing but Node.
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

test('a non-default origin with its container resolves to that container', () => {
  const config = browserConfig({
    OCUPILOT_BROWSER_ORIGIN: 'http://localhost:52777',
    OCUPILOT_BROWSER_CONTAINER: 'ocupilot-b-ci',
  });
  assert.equal(config.origin, 'http://localhost:52777');
  assert.equal(config.container, 'ocupilot-b-ci');
});
