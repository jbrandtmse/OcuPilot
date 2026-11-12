// Pins the navigation diagnostic of browser/panel-spec.mjs against a fake page: a goto that times
// out is rethrown, the same error, with each request still in flight and its age named in its message.
//
// Mutations (Rule 19):
// - drop the in-flight list from the rethrown message -> the first test goes red.
// - make `signedInAt` call `page.goto` directly -> the `signedInAt` run and the last test go red.
// - start tracking after `prepare` in `signedInAt` -> the `signedInAt` run and the last test go red.

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { EventEmitter } from 'node:events';
import test from 'node:test';

const { gotoNamingInflight, signedInAt, trackInflightRequests } = await import(new URL('../browser/panel-spec.mjs', import.meta.url).href);

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

/** Run `body` with the instance variables a browser run names and a `fetch` that answers every reset call 200. */
async function withStubbedInstance(body) {
  const names = ['OCUPILOT_BROWSER_ORIGIN', 'OCUPILOT_BROWSER_CONTAINER'];
  const saved = Object.fromEntries(names.map((name) => [name, process.env[name]]));
  const realFetch = globalThis.fetch;
  process.env.OCUPILOT_BROWSER_ORIGIN = 'http://throwaway.invalid';
  process.env.OCUPILOT_BROWSER_CONTAINER = 'ocupilot-fake-throwaway';
  globalThis.fetch = async () => new Response(JSON.stringify({ shell: [], keys: [], preset: '', turnsPerHour: 0, rowVersion: 0 }), { status: 200 });
  try {
    return await body();
  } finally {
    globalThis.fetch = realFetch;
    for (const name of names) {
      if (saved[name] === undefined) delete process.env[name];
      else process.env[name] = saved[name];
    }
  }
}

/** A browser whose one page is `page`, and the config `signedInAt` reads. */
function fakeBrowser(page) {
  page.setDefaultNavigationTimeout = () => {};
  page.setViewport = async () => {};
  page.emulateMediaFeatures = async () => {};
  return { createBrowserContext: async () => ({ newPage: async () => page }) };
}

const config = { origin: 'http://throwaway.invalid', navigationTimeoutMs: 30000, viewport: { width: 1440, height: 900 }, username: 'u', password: 'p' };

test('signedInAt, run against a page whose goto times out, names a request that was already in flight', async () => {
  const page = new EventEmitter();
  const original = new TimeoutError('Navigation timeout of 30000 ms exceeded');
  page.goto = async () => {
    page.emit('request', request('http://throwaway.invalid/ocupilot/assets/late.js'));
    await new Promise((resolve) => setTimeout(resolve, 10));
    throw original;
  };
  const prepare = async (target) => {
    target.emit('request', request('http://throwaway.invalid/ocupilot/assets/from-prepare.css'));
  };
  await withStubbedInstance(() =>
    assert.rejects(
      () => signedInAt(fakeBrowser(page), config, '/ocupilot/', config.viewport, null, prepare),
      (error) => {
        assert.equal(error, original, 'the same error object');
        assert.match(error.message, /^Navigation timeout of 30000 ms exceeded/, 'its own message first');
        assert.match(error.message, /from-prepare\.css \(\d+ ms\)/, 'a request made while the spec prepared the page is tracked');
        assert.match(error.message, /late\.js \(\d+ ms\)/, 'and one made by the navigation itself');
        return true;
      }
    )
  );
});

test('signedInAt rethrows a failure that is not a navigation timeout unchanged', async () => {
  const page = new EventEmitter();
  const refused = new Error('net::ERR_CONNECTION_REFUSED');
  page.goto = async () => {
    throw refused;
  };
  await withStubbedInstance(() =>
    assert.rejects(
      () => signedInAt(fakeBrowser(page), config, '/ocupilot/'),
      (error) => error === refused && error.message === 'net::ERR_CONNECTION_REFUSED'
    )
  );
});
