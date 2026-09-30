/**
 * How a browser spec gets a signed-in shell onto the screen it is about (Story 3.6).
 *
 * **Signing in is not arriving any more.** An OcuPilot administrator's first sign-in while the
 * instance holds no enabled definition is taken to the Definition form by the first-login gate
 * (FR-28), whatever URL the browser asked for -- and a throwaway holds no enabled definition, and
 * `resetRememberedState` forgets the account's first-sign-in record, so that is every spec whose
 * context starts from it. A helper that signed in and then waited for its own screen waited for
 * a screen that was never going to mount.
 *
 * **The way out is Back**, which is what the gate leaves: it navigates with an ordinary history
 * entry rather than replacing one, so the requested route is still in the browser's own history
 * and `page.goBack()` returns to it. That is the gesture EXPERIENCE.md publishes for a screen the
 * user did not choose ("Undo by Back"), it is a route change inside the running shell rather than
 * a second document, and it therefore neither re-authenticates nor re-fires the gate.
 *
 * **Never a second `page.goto`.** A fresh document is not a resumed tab: `TokenStore` adopts a
 * stored pair only across a reload or a Back/Forward (DW-6), so a `goto` clears the pair, the
 * silent probe mints a new one, `adopt()` runs -- and the gate is entitled to act on that. Whether
 * it does turns on the account's first-sign-in record, which the gate writes when it opens the form,
 * so a spec that re-issues its deep link passes it through `leaveFirstLoginGate`, which tolerates
 * either.
 *
 * `gate.browser-spec.mjs` is the one file that does not use this: it is about the gate, so it
 * asserts where the gate put the browser rather than stepping around it.
 */

import assert from 'node:assert/strict';

/** The Definition form's own path, which is where the gate puts an administrator. */
export const GATE_PATH = '/ocupilot/agent/definitions/edit';

/**
 * How long to give the gate to act before concluding it is not going to.
 *
 * The gate navigates only once the navigation map and the definitions list have both answered, so
 * it lands a round trip or two after the frame appears -- which is why "the rail is on screen" is
 * not evidence that the gate has finished deciding. This window is spent only on an instance
 * where the gate does NOT fire; where it does, the wait resolves as soon as the route moves.
 */
const GATE_WINDOW_MS = 5000;

/** The path the browser is actually on, with no origin and no fragment. */
export function pathOf(page) {
  return new URL(page.url()).pathname;
}

/**
 * Return to `requested` when the first-login gate moves the browser off it.
 *
 * `requested` is the URL the spec asked for, so the helper can tell the gate's own navigation from
 * a spec whose screen IS the Definition form -- where the browser is already where it asked to be
 * and Back would take it out of the app. It is a no-op there, on any instance that holds an
 * enabled definition or refuses this caller, and for an account whose first sign-in is recorded.
 */
export async function leaveFirstLoginGate(page, timeoutMs, requested) {
  const wanted = new URL(requested, 'http://ignored.invalid').pathname;
  if (wanted.startsWith(GATE_PATH)) return;
  try {
    await page.waitForFunction(
      (gate) => new URL(window.location.href).pathname.startsWith(gate),
      { timeout: GATE_WINDOW_MS },
      GATE_PATH
    );
  } catch {
    // The gate did not fire: this instance holds an enabled definition, this caller may not
    // configure one, or this account's first sign-in is recorded. Either way the browser should
    // already be where it asked to be -- and that is asserted rather than assumed, because the
    // other way to reach this line is a gate that was slower than the window. Returning silently
    // there would leave the caller asserting against a screen the gate is about to navigate away
    // from, and the failure would name a missing selector rather than the gate.
    assert.equal(
      pathOf(page),
      wanted,
      'the first-login gate did not fire within its window, and the browser is not on the route that was asked for either'
    );
    return;
  }
  await page.goBack();
  await page.waitForFunction(
    (path) => new URL(window.location.href).pathname === path,
    { timeout: timeoutMs },
    wanted
  );
  assert.equal(
    pathOf(page),
    wanted,
    'Back returns to the route the gate moved off, which is what makes the gate bypassable'
  );
}
