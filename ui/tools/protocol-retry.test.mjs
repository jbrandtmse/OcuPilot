// Pins browser/protocol-retry.mjs against fake browsers: one retry of a context or page creation
// that times out on the DevTools protocol, and nothing else retried.
//
// Mutations (Rule 19): create the page only once -> the first test goes red. Narrow PROTOCOL_TIMEOUT
// to `Network.enable` -> the Runtime.callFunctionOn case goes red. Retry any error -> the
// other-error case goes red. Drop the retried mark -> the two nested-retry cases go red. Drop either
// WRAPPED guard -> the wrap-twice case goes red. Create a context without `retryOnce` -> the
// context-creation case goes red. Make `withDeadline` return its promise unchanged -> the deadline
// cases go red. Drop the close in `relaunchOnce` -> the wedged-browser case goes red; retry any error
// there -> the other-error case goes red. Drop the `await` on `retryOnce`'s reset -> the async-reset
// case goes red. Swallow the error `reset` throws, or call `reset` inside the second attempt's `try`
// -> the reset-error case goes red. Drop a form from CONNECTION_LOSS -> the isConnectionLoss case goes
// red. Retry a second error the predicate accepts -> the predicate case goes red. In the error-log
// spec, hand the shared browser straight to the open, rethrow a different error, or relaunch without
// handing the new browser on -> the source-text case goes red.

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

import { WALKCALLDEADLINE, installProtocolRetry, isConnectionLoss, isNavigationTimeout, isProtocolTimeout, relaunchOnce, retryOnce, withDeadline, wrapBrowser } from '../browser/protocol-retry.mjs';

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

test('retryOnce waits for an asynchronous reset before its second attempt', async () => {
  let ready = false;
  let tries = 0;
  const value = await retryOnce(
    async () => {
      tries += 1;
      if (tries === 1) throw timeout('Runtime.callFunctionOn');
      return ready ? 'after the reset' : 'before the reset finished';
    },
    async () => {
      await new Promise((resolve) => setTimeout(resolve, 20));
      ready = true;
    }
  );
  assert.equal(value, 'after the reset');
});

test('an error the reset throws propagates unmarked, and the second attempt does not run', async () => {
  let tries = 0;
  const broken = new Error('relaunch failed');
  await assert.rejects(
    retryOnce(
      async () => {
        tries += 1;
        throw timeout('Runtime.callFunctionOn');
      },
      async () => {
        throw broken;
      }
    ),
    (error) => error === broken && error[Symbol.for('ocupilot.protocolRetried')] !== true
  );
  assert.equal(tries, 1, 'the second attempt never ran');
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

test('a call that never settles is abandoned after the deadline, as a protocol timeout naming the call', { timeout: 10_000 }, async () => {
  const started = Date.now();
  let caught = null;
  await withDeadline(new Promise(() => {}), 50, '1280px light: settle').catch((error) => {
    caught = error;
  });
  assert.ok(caught !== null, 'the never-settling promise was rejected');
  assert.ok(Date.now() - started < 1050, 'within the deadline plus a second');
  assert.equal(isProtocolTimeout(caught), true, 'in a shape isProtocolTimeout matches');
  assert.match(caught.message, /1280px light: settle/, 'naming the call');
  assert.match(caught.message, /protocolTimeout does not change this deadline/, 'and that raising protocolTimeout is not the remedy');
});

test('a call that answers in time answers unchanged, and one that fails fails unchanged', async () => {
  assert.equal(await withDeadline(Promise.resolve('ok'), 1000, 'call'), 'ok');
  await assert.rejects(() => withDeadline(Promise.reject(new Error('Target closed')), 1000, 'call'), /Target closed/);
  assert.equal(WALKCALLDEADLINE, 60_000);
});

test('retryOnce re-runs a pass once when one of its calls is abandoned', { timeout: 10_000 }, async () => {
  let creates = 0;
  let resets = 0;
  const result = await retryOnce(
    async () => {
      creates += 1;
      if (creates === 1) await withDeadline(new Promise(() => {}), 20, 'pass: detect route');
      return 'done';
    },
    () => {
      resets += 1;
    }
  );
  assert.equal(result, 'done');
  assert.equal(creates, 2, 'created once more');
  assert.equal(resets, 1, 'reset once');
});

const navigationTimeout = () => new Error('Navigation timeout of 30000 ms exceeded');

/** A launcher whose first browser never navigates and whose later ones do. */
function fakeLauncher(stuck = 1) {
  const launched = [];
  const launch = () => {
    const wedged = launched.length < stuck;
    const fake = { id: launched.length + 1, closed: false, wedged };
    fake.close = async () => {
      fake.closed = true;
    };
    launched.push(fake);
    return fake;
  };
  const open = async (browser) => {
    if (browser.wedged) throw navigationTimeout();
    return { page: `page of browser ${browser.id}` };
  };
  return { launched, launch, open };
}

test('a navigation that times out on a wedged browser is opened again on a new browser, and the wedged one is closed', async () => {
  const launcher = fakeLauncher();
  const first = launcher.launch();
  const page = await relaunchOnce(launcher.open, async () => launcher.launch(), first);
  assert.equal(page.page, 'page of browser 2', 'the page is the new browser\'s');
  assert.equal(first.closed, true, 'browser 1 was closed');
  assert.equal(launcher.launched.length, 2, 'one relaunch');
});

test('a second navigation timeout propagates, after exactly one relaunch', async () => {
  const launcher = fakeLauncher(2);
  const first = launcher.launch();
  await assert.rejects(() => relaunchOnce(launcher.open, async () => launcher.launch(), first), /Navigation timeout of 30000 ms exceeded/);
  assert.equal(launcher.launched.length, 2, 'no third browser');
});

test('an error that is not a navigation timeout, and a browser that opens, relaunch nothing', async () => {
  const launcher = fakeLauncher(0);
  const first = launcher.launch();
  let relaunches = 0;
  const relaunch = async () => {
    relaunches += 1;
    return launcher.launch();
  };
  assert.equal((await relaunchOnce(launcher.open, relaunch, first)).page, 'page of browser 1');
  await assert.rejects(() => relaunchOnce(async () => { throw new Error('Target closed'); }, relaunch, first), /Target closed/);
  assert.equal(relaunches, 0);
  assert.ok(isNavigationTimeout(navigationTimeout()));
  assert.ok(!isNavigationTimeout(timeout('Network.enable')), 'a protocol timeout is retryOnce\'s');
});

test('a browser that will not close is abandoned after the close deadline, and the retry still runs', { timeout: 10_000 }, async () => {
  const launcher = fakeLauncher();
  const first = launcher.launch();
  first.close = () => new Promise(() => {});
  const page = await relaunchOnce(launcher.open, async () => launcher.launch(), first, 50);
  assert.equal(page.page, 'page of browser 2');
});

/** The text of the top-level function `name` in the error-log spec, up to its closing brace. */
function errorLogFunction(name) {
  const source = readFileSync(new URL('../browser/error-log.browser-spec.mjs', import.meta.url), 'utf8');
  const start = source.indexOf(`function ${name}(`);
  assert.notEqual(start, -1, `${name} exists in the error-log spec`);
  const end = source.indexOf('\n}\n', start);
  assert.notEqual(end, -1, `${name} ends at a closing brace`);
  return source.slice(start, end);
}

test('the error-log spec opens its screens through relaunchOnce and navigates through gotoNamingInflight', () => {
  // Mutation (Rule 19): hand the shared browser straight to the open in `openOnSharedBrowser` -> the first assertion goes red.
  const shared = errorLogFunction('openOnSharedBrowser');
  assert.match(shared, /relaunchOnce\(/, 'the shared browser is replaced once on a navigation timeout');
  assert.match(shared, /browser = await puppeteer\.launch\([^\n]*\);\s*return browser;/, 'and the replacement is what the spec holds afterwards, and what the second open gets');
  assert.match(shared, /,\s*browser\s*\);\s*$/, 'the first open runs on the shared browser');
  for (const entry of ['signedInAtScreen', 'signedInAtScreenIntercepting']) {
    assert.match(errorLogFunction(entry), /openOnSharedBrowser\(/, `${entry} opens through the relaunching helper`);
  }
  for (const open of ['openScreen', 'openInterceptingScreen']) {
    const body = errorLogFunction(open);
    assert.match(body, /gotoNamingInflight\(/, `${open} names the requests in flight when its navigation times out`);
    assert.doesNotMatch(body, /page\.goto\(/, `${open} navigates only through gotoNamingInflight`);
    assert.match(body, /catch \(error\) \{\s*await context\.close\(\)\.catch\(\(\) => \{\}\);\s*throw error;\s*\}/, `${open} closes its context when a step throws, and rethrows that error unchanged`);
  }
});

test('isConnectionLoss matches a lost connection, target, session or frame, and nothing else', () => {
  for (const message of ['Protocol error: Connection closed.', 'Target closed', 'Session closed. Most likely the page has been closed.', 'Navigating frame was detached', 'frame got detached', 'Frame detached.', "Attempted to use detached Frame 'F1'.", 'Execution context is not available in detached frame or worker "about:blank" (are you trying to evaluate?)', 'Session already detached. Most likely the page has been closed.']) {
    assert.equal(isConnectionLoss(new Error(message)), true, message);
  }
  assert.equal(isConnectionLoss(new Error('net::ERR_CONNECTION_REFUSED at http://localhost')), false, 'a refused connection is not a lost one');
  assert.equal(isConnectionLoss(timeout('Network.enable')), false, 'a protocol timeout is isProtocolTimeout\'s');
});

test('retryOnce retries what its predicate accepts, and only once', async () => {
  let attempts = 0;
  const lost = () => new Error('Target closed');
  assert.equal(await retryOnce(async () => (++attempts === 1 ? Promise.reject(lost()) : 'ok'), () => {}, isConnectionLoss), 'ok');
  attempts = 0;
  await assert.rejects(() => retryOnce(async () => { attempts += 1; throw lost(); }, () => {}), /Target closed/);
  assert.equal(attempts, 1, 'the default predicate does not retry a lost connection');
  attempts = 0;
  await assert.rejects(() => retryOnce(async () => { attempts += 1; throw lost(); }, () => {}, isConnectionLoss), /Target closed/);
  assert.equal(attempts, 2, 'a second error the predicate accepts is not retried');
});
