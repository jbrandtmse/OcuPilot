/**
 * Per-screen help: the documentation address the locator bar's Help control opens, over
 * `/api/ocupilot/ui/help` (Story 15.3, FR-73, AD-44).
 *
 * **No screen-descriptor key is added for this.** A screen already declares the *class name* of
 * the classic page it replaces, and that class's own `HELPADDRESS` is what a documentation address
 * is built from -- read on the instance at call time. So the descriptor stays the single source
 * (AD-5), the client mirror is consumed read-only, and nothing is regenerated.
 *
 * **The mirror decides whether to ask; the instance decides what to show.** `hasClassicPage` is a
 * local read, so a screen with no classic equivalent costs no request at all. For one that has
 * a classic page the instance is asked, because only it can say whether that page publishes an
 * address -- several shipped screens' classic pages are CSP pages that publish none, and those
 * answer `available: false` and are rendered with no control rather than with one that opens
 * nothing.
 *
 * Framework-free, like the rest of `core/` (AD-19), so `ui/tools/about.test.mjs` executes it under
 * `node --test`.
 */

import type { ApiService } from './api';
import { screenForRoute } from './navigation.ts';

/** Absolute from the origin root, through the one API service (AD-20). */
export const HELP_PATH = '/api/ocupilot/ui/help';

/**
 * Whether `route` names a built screen that declares a classic page, and so whether asking the
 * instance for its documentation address could answer anything.
 *
 * Read from the mirror, so the Help control's absence on a screen with no classic equivalent
 * needs no round trip. Home declares the empty route and the instance refuses one, so an empty
 * route is false here too rather than producing a request that can only be refused.
 */
export function hasClassicPage(route: string): boolean {
  if (route === '') return false;
  const screen = screenForRoute(route);
  return screen !== null && screen.built && screen.classicPage !== '';
}

/**
 * The documentation address the instance resolves for `route`, or `''` when it has none.
 *
 * A refusal, an unavailable answer and an instance that did not reply are all `''`: the control is
 * rendered only for an address, so the three collapse to "no control" and the caller has one case.
 */
export async function helpHrefFor(api: ApiService, route: string): Promise<string> {
  const result = await api.requestJson<unknown>(`${HELP_PATH}?route=${encodeURIComponent(route)}`);
  if (result.kind !== 'ok') return '';
  const body = result.body;
  if (typeof body !== 'object' || body === null || Array.isArray(body)) return '';
  const record = body as Record<string, unknown>;
  if (record['available'] !== true) return '';
  return typeof record['href'] === 'string' ? record['href'] : '';
}

export interface HelpLinksOptions {
  readonly api: ApiService;
}

/**
 * The resolved address per route, so the locator bar asks once per screen rather than once per
 * render.
 *
 * A route is held once it has been asked, answer or not, which is what stops a screen whose
 * classic page publishes no address from re-asking on every router event.
 */
export class HelpLinks {
  private readonly api: ApiService;

  private readonly hrefs = new Map<string, string>();

  private readonly asked = new Set<string>();

  /**
   * Bumped by `reset()`, read across the await: an address resolved for a departed principal must
   * not land on the one who replaced them (AD-8). `asked` alone does not cover it, because the next
   * principal's own `load()` for the same route re-adds the route the reset had removed.
   */
  private generation = 0;

  private readonly listeners = new Set<() => void>();

  constructor(options: HelpLinksOptions) {
    this.api = options.api;
  }

  /** The address held for `route`, or `''` while none is known. */
  hrefFor(route: string): string {
    return this.hrefs.get(route) ?? '';
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /**
   * Resolve `route`'s address if it could have one and has not been asked for yet. Fire and
   * forget: a failure surfaces as no control, never as an error on a screen the user opened for
   * some other reason.
   */
  async load(route: string): Promise<void> {
    if (!hasClassicPage(route)) return;
    if (this.asked.has(route)) return;
    this.asked.add(route);
    const generation = this.generation;
    const href = await helpHrefFor(this.api, route);
    if (generation !== this.generation) return;
    if (!this.asked.has(route)) return;
    if (href === '') return;
    this.hrefs.set(route, href);
    this.notify();
  }

  /**
   * Forget every resolved address. The addresses are the instance's, not the account's, but a
   * sign-out is also the one gesture after which the next caller may be talking to a shell that
   * has been upgraded underneath them.
   */
  reset(): void {
    this.generation += 1;
    this.hrefs.clear();
    this.asked.clear();
    this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
