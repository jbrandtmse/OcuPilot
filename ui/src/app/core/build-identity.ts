/**
 * Whether the bundle this tab is running is the one the instance has installed (Story 15.3, DW-3,
 * AD-38).
 *
 * **One artifact is both sides of the comparison.** `outputHashing: all` gives the built client a
 * hashed `main-<hash>.js`; the installer records that filename on the version row, and the running
 * document names it in its own `<script src>`. There is no generator and no second artifact to
 * drift: a bundle whose bytes differ has a different name, and a name that matches is the same
 * bundle.
 *
 * **Absence is never a mismatch.** A dev serve, a build with hashing off, or an install that
 * deployed no bundle leaves one side empty, and an empty side means there is nothing to compare --
 * never "stale". That is what keeps the prompt off a developer's screen and off a tab talking to
 * an instance that cannot say what it is running.
 *
 * Framework-free, like the rest of `core/` (AD-19), so `ui/tools/about.test.mjs` executes it under
 * `node --test` with no browser.
 */

/** A hashed entry-point filename, as the Angular application builder emits it. */
const MAIN_BUNDLE_RE = /^main-[A-Za-z0-9]+\.js$/;

/** What `bundleIdentity` reads: the document, narrowed to the one thing it needs from it. */
export interface ScriptSource {
  querySelectorAll(selector: string): ArrayLike<{ getAttribute(name: string): string | null }>;
}

/**
 * The hashed `main-*.js` filename this document loaded, or `''` when it loaded none.
 *
 * The `src` may be absolute, root-relative or relative, so only its last path segment is compared;
 * a query string or fragment is dropped with it. `''` outside a browser, which is where the
 * `node --test` suite reads it from.
 */
export function bundleIdentity(source: ScriptSource | null = defaultSource()): string {
  if (source === null) return '';
  let found = '';
  const scripts = source.querySelectorAll('script[src]');
  for (let index = 0; index < scripts.length; index += 1) {
    const src = scripts[index].getAttribute('src');
    if (src === null) continue;
    const path = src.split('?')[0].split('#')[0];
    const leaf = path.slice(path.lastIndexOf('/') + 1);
    if (!MAIN_BUNDLE_RE.test(leaf)) continue;
    // Deterministic rather than "whichever the document listed first": a page carrying two would
    // otherwise make the verdict depend on markup order.
    if (found === '' || leaf > found) found = leaf;
  }
  return found;
}

/**
 * Whether the instance is serving a bundle this tab is not running.
 *
 * **Both sides must name a hashed bundle for there to be anything to compare.** Empty is one way a
 * side says it cannot name one; the installer's own fallback stamp (`dev`, what it records when the
 * install deployed no hashed main) is another, and so is anything else that is not a bundle name.
 * Comparing those would report every such instance as stale forever against a browser that did load
 * a hashed bundle -- the documented deploy-after-install workflow reaches exactly that state -- and
 * the prompt could not be cleared by reloading, because reloading cannot change what the row says.
 * One name shape, applied to both sides.
 *
 * `bundle` is a parameter so the comparison is executable with no document at all.
 */
export function isStale(serverIdentity: string, bundle: string = bundleIdentity()): boolean {
  if (!MAIN_BUNDLE_RE.test(serverIdentity)) return false;
  if (!MAIN_BUNDLE_RE.test(bundle)) return false;
  return serverIdentity !== bundle;
}

function defaultSource(): ScriptSource | null {
  return typeof document === 'undefined' ? null : (document as unknown as ScriptSource);
}
