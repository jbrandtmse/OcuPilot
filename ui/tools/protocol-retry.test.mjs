// Pins browser/protocol-retry.mjs against fake browsers: one retry of a context or page creation
// that times out on the DevTools protocol, and nothing else retried.
//
// Mutations (Rule 19): create the page only once -> the first test goes red. Narrow PROTOCOL_TIMEOUT
// to `Network.enable` -> the Runtime.callFunctionOn case goes red. Retry any error -> the
// other-error case goes red. Drop the retried mark -> the two nested-retry cases go red. Drop either
// WRAPPED guard -> the wrap-twice case goes red. Create a context without `retryOnce` -> the
// context-creation case goes red.

import assert from 'node:assert/strict';
import test from 'node:test';

import { installProtocolRetry, isProtocolTimeout, retryOnce, wrapBrowser } from '../browser/protocol-retry.mjs';

const timeout = (command) =>
  new Error(`${command} timed out. Increase the 'protocolTimeout' setting in launch/connect calls for a higher timeout if needed.`);

/** A fake browser whose creations follow `script`: each entry is an Error to throw or a name to return. */
function fakeBrowser(script) {
  const calls = { newPage: 0, createBrowserContext: 0, contextNewPage: 0 };
  const steps = [...script];
  const next = (counter) => {
    calls[counter] += 1;
    const step = steps.shift();
    if (step instanceof Error) throw step;
    return { name: step };
  };
  const context = { newPage: async () => next('contextNewPage') };
  return {
    calls,
    context,
    browser: {
      newPage: async () => next('newPage'),
      createBrowserContext: async () => {
        calls.createBrowserContext += 1;
        return context;
      },
      defaultBrowserContext: () => context,
    },
  };
}

test('a page creation that times out once is created again, and the caller sees one page', async () => {
  const { browser, calls } = fakeBrowser([timeout('Network.enable'), 'page']);
  const page = await wrapBrowser(browser).newPage();
  assert.equal(page.name, 'page');
  assert.equal(calls.newPage, 2, 'two creations were attempted');
});

test('two timeouts in a row throw the second', async () => {
  const { browser, calls } = fakeBrowser([timeout('Network.enable'), timeout('Network.enable')]);
  await assert.rejects(() => wrapBrowser(browser).newPage(), /Network\.enable timed out/);
  assert.equal(calls.newPage, 2, 'one retry and no more');
});

test('an error that is not a protocol timeout is not retried', async () => {
  const { browser, calls } = fakeBrowser([new Error('Target closed'), 'page']);
  await assert.rejects(() => wrapBrowser(browser).newPage(), /Target closed/);
  assert.equal(calls.newPage, 1);
});

test('a context creation that times out once is created again', async () => {
  let creations = 0;
  const context = { newPage: async () => ({ name: 'page' }) };
  const browser = {
    newPage: async () => ({ name: 'page' }),
    createBrowserContext: async () => {
      creations += 1;
      if (creations === 1) throw timeout('Target.createBrowserContext');
      return context;
    },
    defaultBrowserContext: () => context,
  };
  assert.equal(await wrapBrowser(browser).createBrowserContext(), context);
  assert.equal(creations, 2, 'two creations were attempted');
});

test('a context created through the wrapped browser retries its own page creation', async () => {
  const { browser, calls } = fakeBrowser([timeout('Runtime.callFunctionOn'), 'page']);
  const context = await wrapBrowser(browser).createBrowserContext();
  const page = await context.newPage();
  assert.equal(page.name, 'page');
  assert.equal(calls.contextNewPage, 2);
  const again = fakeBrowser(['page']);
  const wrapped = wrapBrowser(again.browser);
  const wrappedNewPage = wrapped.newPage;
  const defaultNewPage = wrapped.defaultBrowserContext().newPage;
  wrapBrowser(wrapped);
  assert.equal(wrapped.newPage, wrappedNewPage, 'wrapping twice wraps once');
  assert.equal(wrapped.defaultBrowserContext().newPage, defaultNewPage, 'and so does reaching the default context twice');
  assert.equal((await wrapped.defaultBrowserContext().newPage()).name, 'page', 'and the default context is wrapped too');
});

test('a retry resets before its second attempt only, and a timeout that had its retry is not retried again', async () => {
  let resets = 0;
  let tries = 0;
  const value = await retryOnce(
    async () => {
      tries += 1;
      if (tries === 1) throw timeout('Runtime.callFunctionOn');
      return 'second';
    },
    () => { resets += 1; }
  );
  assert.equal(value, 'second');
  assert.equal(resets, 1, 'reset once, before the second attempt');
  assert.equal(await retryOnce(async () => 'first', () => { resets += 1; }), 'first');
  assert.equal(resets, 1, 'a first attempt that succeeds resets nothing');

  let inner = 0;
  await assert.rejects(
    () => retryOnce(() => retryOnce(async () => {
      inner += 1;
      throw timeout('Network.enable');
    })),
    /Network\.enable timed out/
  );
  assert.equal(inner, 2, 'an outer retry around an inner one adds no attempt');
});

test('a browser whose page creation goes through its wrapped default context still tries twice, not four times', async () => {
  const { browser, calls } = fakeBrowser([timeout('Network.enable'), timeout('Network.enable'), 'page']);
  browser.newPage = async () => browser.defaultBrowserContext().newPage();
  const wrapped = wrapBrowser(browser);
  wrapped.defaultBrowserContext();
  await assert.rejects(() => wrapped.newPage(), /Network\.enable timed out/);
  assert.equal(calls.contextNewPage, 2);
});

test('retryOnce and isProtocolTimeout answer the two message shapes the runs showed', async () => {
  for (const command of ['Runtime.callFunctionOn', 'Network.enable']) assert.ok(isProtocolTimeout(timeout(command)), command);
  assert.ok(!isProtocolTimeout(new Error('Navigation timeout of 30000 ms exceeded')), 'a navigation timeout is not a protocol timeout');
  let tries = 0;
  const value = await retryOnce(async () => {
    tries += 1;
    if (tries === 1) throw timeout('Runtime.callFunctionOn');
    return 'ok';
  });
  assert.equal(value, 'ok');
});

test('installProtocolRetry wraps launch once and answers a wrapped browser', async () => {
  const fake = fakeBrowser([timeout('Network.enable'), 'page']);
  let launches = 0;
  const puppeteer = { launch: async () => { launches += 1; return fake.browser; } };
  installProtocolRetry(puppeteer);
  const launch = puppeteer.launch;
  installProtocolRetry(puppeteer);
  assert.equal(puppeteer.launch, launch, 'a second install leaves the first wrapper in place');
  const browser = await puppeteer.launch();
  assert.equal(launches, 1);
  assert.equal((await browser.newPage()).name, 'page');
  assert.equal(fake.calls.newPage, 2);
});
