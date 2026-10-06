/**
 * One retry for a DevTools-protocol command that timed out while a browser context or page was
 * being created.
 *
 * Puppeteer rejects a command that gets no answer within `protocolTimeout` with a message that
 * ends "Increase the 'protocolTimeout' setting ...". On a loaded runner that has hit page creation
 * (`Network.enable`) and a long in-page call (`Runtime.callFunctionOn`), and each failed a whole
 * spec although the next attempt would have passed. `installProtocolRetry` wraps `puppeteer.launch`
 * once, so every spec's browser creates its contexts and pages through `retryOnce`; any other
 * error, and a second timeout, propagate unchanged.
 *
 * The wrappers are assigned through `.bind` and property assignment, so this file spells neither
 * call `tools/browser-reset.mjs` counts in a spec.
 */

/** The message a timed-out protocol command carries. */
export const PROTOCOL_TIMEOUT = / timed out\. Increase the 'protocolTimeout'/;

const WRAPPED = Symbol.for('ocupilot.protocolRetry');

/** Whether `error` is a DevTools-protocol timeout. */
export function isProtocolTimeout(error) {
  return PROTOCOL_TIMEOUT.test(String(error?.message ?? error ?? ''));
}

/** Run `create`; when it fails with a protocol timeout, run it once more. */
export async function retryOnce(create) {
  try {
    return await create();
  } catch (error) {
    if (!isProtocolTimeout(error)) throw error;
    return create();
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
