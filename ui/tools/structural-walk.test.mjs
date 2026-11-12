// Pins the structural walk's settle step (browser/structural-walk.mjs) without a browser: the fonts
// condition is a synchronous status read inside the settle loop, so a font load that never reports
// ready cannot hold the call past the loop's own bound.
//
// Mutations (Rule 19):
// - restore `await document.fonts.ready` inside the settle evaluate -> the first test goes red, its
//   fake `fonts.ready` never resolving.
// - drop the `document.fonts.status === 'loaded'` term from the settle evaluate -> the first test
//   goes red on its lower bound: settle answered before the fonts reported loaded.
// - call `page.evaluate` or `page.waitForFunction` in the walk without `bounded(` -> the second test
//   goes red, naming the line.

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const { settle } = await import(new URL('../browser/structural-walk.mjs', import.meta.url).href);

/** A fake page whose `evaluate(fn)` runs `fn` against the stubbed `document` installed by the test. */
function fakePage() {
  return { evaluate: async (fn, ...args) => fn(...args) };
}

test('settle answers true when fonts.ready never resolves but fonts.status turns loaded', { timeout: 30_000 }, async () => {
  const started = Date.now();
  const fonts = { ready: new Promise(() => {}), status: 'loading' };
  const timer = setTimeout(() => {
    fonts.status = 'loaded';
  }, 1000);
  const before = Object.getOwnPropertyDescriptor(globalThis, 'document');
  globalThis.document = { fonts, querySelector: () => null };
  try {
    const requests = { inflight: new Set(), last: Date.now() - 10_000 };
    const settled = await Promise.race([
      settle(fakePage(), requests),
      new Promise((resolve) => setTimeout(() => resolve('still waiting'), 5000)),
    ]);
    assert.equal(settled, true, 'settle answered rather than waiting on fonts.ready');
    const elapsed = Date.now() - started;
    assert.ok(elapsed >= 900, `and only once the fonts reported loaded (${elapsed} ms)`);
    assert.ok(elapsed < 5000, `and within 5 s (${elapsed} ms)`);
  } finally {
    clearTimeout(timer);
    if (before === undefined) delete globalThis.document;
    else Object.defineProperty(globalThis, 'document', before);
  }
});

test('every page call the walk issues goes through the per-call deadline', () => {
  const lines = readFileSync(new URL('../browser/structural-walk.mjs', import.meta.url), 'utf8').split('\n');
  const bare = [];
  let inFieldNames = false;
  lines.forEach((line, index) => {
    const declared = /^(?:export )?(?:async )?function (\w+)/.exec(line);
    // `fieldNames` runs under its caller's `bounded(` (detectScreen).
    if (declared !== null) inFieldNames = declared[1] === 'fieldNames';
    if (inFieldNames || !/\bpage\.(evaluate|waitForFunction|\$eval)\(/.test(line) || /^\s*(\*|\/\/)/.test(line)) return;
    const context = lines.slice(Math.max(0, index - 3), index + 1).join('\n');
    if (!/\bbounded\(\s*$/m.test(context)) bare.push(`line ${index + 1}: ${line.trim()}`);
  });
  assert.deepEqual(bare, [], 'no walk page call outside bounded()');
});
