/**
 * Pins that `browser.config.mjs` wraps the real `puppeteer.launch` with the protocol-timeout retry
 * every browser spec relies on. Needs nothing from the environment: importing the config launches no
 * browser.
 */
import assert from 'node:assert/strict';
import { test } from 'node:test';

import puppeteer from 'puppeteer';

import '../browser.config.mjs';

test('browser.config.mjs wraps puppeteer.launch with the protocol retry', () => {
  assert.equal(puppeteer[Symbol.for('ocupilot.protocolRetry')], true);
});
