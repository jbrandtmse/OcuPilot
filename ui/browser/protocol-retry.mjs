/**
 * One retry for a DevTools-protocol command that timed out while a browser context or page was
 * being created.
 *
 * Puppeteer rejects a command that gets no answer within `protocolTimeout` with a message that
 * ends "Increase the 'protocolTimeout' setting ...". On a loaded runner that has hit page creation
 * (`Network.enable`) and a long in-page call (`Runtime.callFunctionOn`), and each failed a whole
 * spec although the next attempt would have passed. `installProtocolRetry` wraps `puppeteer.launch`
 * once, so every spec's browser creates its contexts and pages through `retryOnce`; any other
 * error, and a second timeout, propagate unchanged. A second timeout is marked as retried, so a
 * retry around another one (the structural walk's per-pass retry around a page creation) does not
 * try it again.
 *
 * The wrappers are assigned through `.bind` and property assignment, so this file spells neither
 * call `tools/browser-reset.mjs` counts in a spec.
 */

/** The message a timed-out protocol command carries. */
export const PROTOCOL_TIMEOUT = / timed out\. Increase the 'protocolTimeout'/;

const WRAPPED = Symbol.for('ocupilot.protocolRetry');

/** Set on an error that has already had its retry. */
const RETRIED = Symbol.for('ocupilot.protocolRetried');

/**
 * How long one page call of the structural walk's helpers (`settle`, `detectScreen`,
 * `toggleThemeThroughMenu` and the walk's own steps, in every spec that calls them) may go unanswered
 * before it is abandoned. The protocol limit stays 600 s for every other call; a walk call normally
 * answers in well under a second, so 60 s only ever fires on a call that is never going to return.
 */
export const WALKCALLDEADLINE = 60_000;

/** Whether `error` is a DevTools-protocol timeout. */
export function isProtocolTimeout(error) {
  return PROTOCOL_TIMEOUT.test(String(error?.message ?? error ?? ''));
}

/** The message a browser, target, session or frame that is gone carries. */
export const CONNECTION_LOSS = /Connection closed|Target closed|Session closed|frame (was |got )?detached/i;

/** Whether `error` says the browser connection, its target, its session or its frame was lost. */
export function isConnectionLoss(error) {
  return CONNECTION_LOSS.test(String(error?.message ?? error ?? ''));
}

/**
 * Settle with `promise`, or reject after `ms` with an error that `isProtocolTimeout` matches and
 * that names `label`, so `retryOnce` treats an abandoned call like a protocol timeout. The abandoned
 * promise is left to settle on its own; its later outcome is ignored.
 */
export function withDeadline(promise, ms, label) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(
        new Error(
          `${label} timed out. Increase the 'protocolTimeout' setting in launch/connect calls for a higher timeout if needed (abandoned by withDeadline after ${ms} ms without an answer; protocolTimeout does not change this deadline).`
        )
      );
    }, ms);
    promise.then(
      (value) => {
        clearTimeout(timer);
        resolve(value);
      },
      (error) => {
        clearTimeout(timer);
        reject(error);
      }
    );
  });
}

/**
 * Run `create`; when it fails with an error `retryable` accepts (a protocol timeout by default) that
 * has not had its retry, await `reset` (it may be synchronous or answer a promise) and run it once
 * more. The second attempt's error is marked, so no other retry repeats it. An error `reset` throws
 * propagates unmarked.
 */
export async function retryOnce(create, reset = () => {}, retryable = isProtocolTimeout) {
  try {
    return await create();
  } catch (error) {
    if (!retryable(error) || error[RETRIED] === true) throw error;
    await reset();
    try {
      return await create();
    } catch (again) {
      if (again !== null && typeof again === 'object') again[RETRIED] = true;
      throw again;
    }
  }
}

/** How long a wedged browser is given to close before it is abandoned. */
export const CLOSEDEADLINE = 10_000;

/**
 * Close `browser`, waiting at most `closeDeadline`. A browser that does not close in time, or whose
 * close fails, is abandoned, not waited for; this never throws.
 */
export async function closeOrAbandon(browser, closeDeadline = CLOSEDEADLINE) {
  try {
    await withDeadline(browser.close(), closeDeadline, 'browser close');
  } catch {
    // A wedged browser may not close; the caller moves on without it.
  }
}

/** The message a page navigation that got no answer within `navigationTimeoutMs` carries. */
export const NAVIGATION_TIMEOUT = /Navigation timeout of \d+ ms exceeded/;

/** Whether `error` is a page navigation that timed out. */
export function isNavigationTimeout(error) {
  return NAVIGATION_TIMEOUT.test(String(error?.message ?? error ?? ''));
}

/**
 * Run `open(browser)`; when it fails with a navigation timeout, close `browser`, launch a new one
 * through `relaunch()` and run `open` once more on it. A shared browser that times out one `goto`
 * can time out every later one until it is replaced (inference). Any other error, and a second navigation
 * timeout, propagate unchanged; a browser that cannot be closed is abandoned, not waited for.
 * `relaunch` answers the new browser, and the caller keeps holding it.
 */
export async function relaunchOnce(open, relaunch, browser, closeDeadline = CLOSEDEADLINE) {
  try {
    return await open(browser);
  } catch (error) {
    if (!isNavigationTimeout(error)) throw error;
    await closeOrAbandon(browser, closeDeadline);
    return open(await relaunch());
  }
}

/** Wrap a context's page creation. Idempotent. */
export function wrapContext(context) {
  if (context === null || typeof context !== 'object' || context[WRAPPED]) return context;
  const make = context.newPage.bind(context);
  context.newPage = () => retryOnce(make);
  context[WRAPPED] = true;
  return context;
}

/** Wrap a launched browser's context and page creation. Idempotent. */
export function wrapBrowser(browser) {
  if (browser === null || typeof browser !== 'object' || browser[WRAPPED]) return browser;
  const makeContext = browser.createBrowserContext.bind(browser);
  const makePage = browser.newPage.bind(browser);
  const defaultContext = browser.defaultBrowserContext.bind(browser);
  browser.createBrowserContext = async (...args) => wrapContext(await retryOnce(() => makeContext(...args)));
  browser.newPage = () => retryOnce(makePage);
  browser.defaultBrowserContext = () => wrapContext(defaultContext());
  browser[WRAPPED] = true;
  return browser;
}

/** Make `puppeteer.launch` answer a wrapped browser. Guarded, so importing it twice wraps once. */
export function installProtocolRetry(puppeteer) {
  if (puppeteer[WRAPPED]) return puppeteer;
  const launch = puppeteer.launch.bind(puppeteer);
  puppeteer.launch = async (...args) => wrapBrowser(await launch(...args));
  puppeteer[WRAPPED] = true;
  return puppeteer;
}
