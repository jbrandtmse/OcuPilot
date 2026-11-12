// Pins the navigation diagnostic of browser/panel-spec.mjs against a fake page: a goto that times
// out is rethrown, the same error, with each request still in flight and its age named in its message.
//
// Mutations (Rule 19):
// - drop the in-flight list from the rethrown message -> the first test goes red.
// - make `signedInAt` call `page.goto` directly, or start tracking after `prepare` -> the last test
//   goes red.

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { EventEmitter } from 'node:events';
import test from 'node:test';

const { gotoNamingInflight, trackInflightRequests } = await import(new URL('../browser/panel-spec.mjs', import.meta.url).href);

const request = (url) => ({ url: () => url });

class TimeoutError extends Error {
  constructor(message) {
    super(message);
    this.name = 'TimeoutError';
  }
}

test('a navigation timeout is rethrown with the request still in flight and its age', async () => {
  const page = new EventEmitter();
  const listInflight = trackInflightRequests(page);
  const stuck = request('http://localhost/ocupilot/assets/font.woff2');
  const done = request('http://localhost/ocupilot/main.js');
  page.emit('request', stuck);
  page.emit('request', done);
  page.emit('requestfinished', done);
  const original = new TimeoutError('Navigation timeout of 30000 ms exceeded');
  page.goto = async () => {
    await new Promise((resolve) => setTimeout(resolve, 20));
    throw original;
  };
  await assert.rejects(
    () => gotoNamingInflight(page, 'http://localhost/ocupilot/', { waitUntil: 'networkidle2' }, listInflight),
    (error) => {
      assert.equal(error, original, 'the same error object');
      assert.match(error.message, /^Navigation timeout of 30000 ms exceeded/, 'its own message first');
      assert.match(error.message, /font\.woff2 \(\d+ ms\)/, 'the stuck request and its age');
      assert.doesNotMatch(error.message, /main\.js/, 'not the one that finished');
      return true;
    }
  );
});

test('a failed or finished request leaves the list, and another error passes through unchanged', async () => {
  const page = new EventEmitter();
  const listInflight = trackInflightRequests(page);
  const failed = request('http://localhost/api/ocupilot/x');
  page.emit('request', failed);
  page.emit('requestfailed', failed);
  assert.deepEqual(listInflight(), []);
  const other = new Error('net::ERR_CONNECTION_REFUSED');
  page.goto = async () => {
    throw other;
  };
  await assert.rejects(() => gotoNamingInflight(page, 'http://localhost/', {}, listInflight), (error) => error === other && error.message === 'net::ERR_CONNECTION_REFUSED');
});

test('a goto that succeeds answers what the page answered', async () => {
  const page = new EventEmitter();
  page.goto = async () => 'response';
  assert.equal(await gotoNamingInflight(page, 'http://localhost/', {}, trackInflightRequests(page)), 'response');
});

test('signedInAt tracks requests before prepare and navigates through the diagnostic', () => {
  const source = readFileSync(new URL('../browser/panel-spec.mjs', import.meta.url), 'utf8');
  const body = source.slice(source.indexOf('export async function signedInAt('));
  const tracked = body.indexOf('trackInflightRequests(page)');
  const prepared = body.indexOf('await prepare(page)');
  const navigated = body.indexOf('gotoNamingInflight(page');
  assert.ok(tracked !== -1 && prepared !== -1 && navigated !== -1, 'signedInAt names all three calls');
  assert.ok(tracked < prepared && prepared < navigated, 'tracking starts before prepare, and the goto follows it');
  assert.ok(!/await page\.goto\(/.test(body.slice(0, body.indexOf('\n}\n'))), 'no direct page.goto in signedInAt');
});
