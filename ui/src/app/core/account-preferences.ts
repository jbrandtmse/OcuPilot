/**
 * The caller's own favorites and recent items, over `/api/ocupilot/account/preferences`
 * (Story 15.2, AD-50).
 *
 * **Named `account-preferences.ts` and not `preferences.ts`.** That name is taken by the
 * browser-storage store, which holds the side bar's remembered open state and nothing else and is
 * the one module `ui/tools/api.test.mjs` exempts from the `localStorage` ban. This state lives on
 * the instance (AD-50, AD-28): it survives a sign-out, it follows the user to another tab and
 * another machine, and browser storage could deliver none of that.
 *
 * **A transport failure never clears what is on screen.** A read that does not answer leaves the
 * previous lists standing and `answered()` where it was, so Home renders what the instance last
 * said rather than emptying itself because the network blinked. A read that a later one overtook
 * settles nothing either -- `request` is what makes "only the newest answer wins" a property of
 * this store rather than of whichever response happened to arrive last, the shape
 * `agent-status.ts` uses for the same hazard.
 *
 * **Every write answers the whole list**, so the store re-settles from the instance's own reply
 * rather than patching its copy (AD-14's discipline applied to a store of its own): a favorite
 * the instance refused is never on screen, and a recents list the instance trimmed is the one
 * rendered.
 *
 * Framework-free, like the rest of `core/` (AD-19), so `ui/tools/account-preferences.test.mjs`
 * executes it under `node --test`.
 */

import type { ApiService, JsonResult } from './api';

/** Absolute from the origin root, through the one API service (AD-20). */
export const ACCOUNT_PREFERENCES_PATH = '/api/ocupilot/account/preferences';

/** The `kind` value naming the pinned-screens list. */
export const FAVORITE_KIND = 'favorite';

/** The `kind` value naming the visited-screens list. */
export const RECENT_KIND = 'recent';

/** The two lists, as the wire names them. */
export type PreferenceKind = typeof FAVORITE_KIND | typeof RECENT_KIND;

/** The placeholder the two `*RemoveNamed` strings leave for the screen a row removes. */
export const NAME_PLACEHOLDER = '<name>';

/**
 * A `*RemoveNamed` string with its placeholder resolved.
 *
 * A function rather than a `replace` inside a template, for the reason `formatRequires` and
 * `formatResultCount` are: renaming the placeholder on one side only would ship the placeholder to
 * the user as part of a control's accessible name, and a source-text pin cannot see that.
 */
export function formatNamed(template: string, name: string): string {
  return template.split(NAME_PLACEHOLDER).join(name);
}

export interface AccountPreferencesOptions {
  readonly api: ApiService;
}

/** The body member each list arrives under, and the member a write names a screen with. */
const FAVORITES_MEMBER = 'favorites';
const RECENTS_MEMBER = 'recents';
const ROUTE_MEMBER = 'route';

/**
 * The routes one list of the answered body carries.
 *
 * Narrowed rather than cast, the way `violations.ts` narrows a violation: an entry that is not an
 * object, or whose `route` is not a string, is dropped rather than rendered as a row nothing can
 * open. An answer that carries no such member at all reads as an empty list, which is what a body
 * from an older instance would look like.
 */
function routesOf(body: unknown, member: string): readonly string[] {
  if (typeof body !== 'object' || body === null) return [];
  const raw = (body as Record<string, unknown>)[member];
  if (!Array.isArray(raw)) return [];
  const out: string[] = [];
  for (const entry of raw) {
    if (entry === null || typeof entry !== 'object' || Array.isArray(entry)) continue;
    const route = (entry as Record<string, unknown>)[ROUTE_MEMBER];
    if (typeof route === 'string' && route !== '') out.push(route);
  }
  return out;
}

/** Whether two lists say the same thing, so a re-read that confirms one re-renders nothing. */
function same(a: readonly string[], b: readonly string[]): boolean {
  return a.length === b.length && a.every((value, index) => value === b[index]);
}

export class AccountPreferences {
  private readonly api: ApiService;

  private favoritesValue: readonly string[] = [];

  private recentsValue: readonly string[] = [];

  private answeredValue = false;

  /**
   * Bumped by `reset()`, read across the await. An answer about the account a departed principal
   * was signed in as must not land on the one who replaced them -- the shape `agent-status.ts`,
   * `InstanceService` and `NavigationService` all use for the same hazard (AD-8).
   */
  private generation = 0;

  /**
   * Bumped by every call that settles the lists, read across the await, so only the **newest**
   * one wins. `generation` alone does not cover it: two calls issued without a `reset()` between
   * them carry the same generation, and the one that happens to return last would otherwise win
   * whether or not it asked last. That is reachable here -- a visit registered by a navigation can
   * overlap the read Home issues on arrival -- and the answer it would get wrong is the one that
   * already includes the visit.
   */
  private request = 0;

  private readonly listeners = new Set<() => void>();

  constructor(options: AccountPreferencesOptions) {
    this.api = options.api;
  }

  /** Whether a read has ever settled, so a caller can tell "no rows" from "not asked yet". */
  answered(): boolean {
    return this.answeredValue;
  }

  /** The pinned screens' routes, oldest first, as the instance ordered them. */
  favorites(): readonly string[] {
    return this.favoritesValue;
  }

  /** The visited screens' routes, newest first, as the instance ordered them. */
  recents(): readonly string[] {
    return this.recentsValue;
  }

  /** Whether `route` is pinned. The locator bar's toggle reads this for `aria-pressed`. */
  isFavorite(route: string): boolean {
    return this.favoritesValue.includes(route);
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** Read both lists. A read that does not answer leaves the previous ones standing. */
  load(): Promise<void> {
    return this.settle(this.api.requestJson<unknown>(ACCOUNT_PREFERENCES_PATH));
  }

  /** Pin `route`. A refusal -- an unknown route, or the cap -- leaves the lists as they were. */
  add(kind: PreferenceKind, route: string): Promise<void> {
    return this.settle(this.write(kind, 'add', route));
  }

  /** Unpin `route`, or drop it from the recents list. */
  remove(kind: PreferenceKind, route: string): Promise<void> {
    return this.settle(this.write(kind, 'remove', route));
  }

  /** Empty one list. */
  clear(kind: PreferenceKind): Promise<void> {
    return this.settle(this.write(kind, 'clear', null));
  }

  /**
   * Register a visit to `route` (Story 15.2's third acceptance criterion: recents are registered
   * by visiting, with no explicit action).
   *
   * Fire and forget by contract, not by accident: the navigation that produced it is never
   * awaited on this, and a failure surfaces nowhere. What it does do is settle the lists when it
   * answers, so Home shows the visit without a second read.
   */
  registerVisit(route: string): void {
    void this.add(RECENT_KIND, route);
  }

  /**
   * Forget both lists, so the next `load()` asks again. Sign-out clears the tab in place, and
   * these are one account's rows -- the same gesture that drops the navigation map (AD-8).
   */
  reset(): void {
    this.generation += 1;
    this.request += 1;
    this.favoritesValue = [];
    this.recentsValue = [];
    this.answeredValue = false;
    this.notify();
  }

  private write(kind: PreferenceKind, action: string, route: string | null): Promise<JsonResult<unknown>> {
    const body: Record<string, string> = { kind, action };
    if (route !== null) body[ROUTE_MEMBER] = route;
    return this.api.requestJson<unknown>(ACCOUNT_PREFERENCES_PATH, {
      method: 'POST',
      body: JSON.stringify(body),
    });
  }

  private async settle(pending: Promise<JsonResult<unknown>>): Promise<void> {
    const generation = this.generation;
    const request = (this.request += 1);
    const result = await pending;
    if (generation !== this.generation) return;
    if (request !== this.request) return;
    // Parked. A refusal is not an answer about what the account holds, and neither is an instance
    // that did not reply: both leave the previous lists standing rather than emptying the blocks.
    if (result.kind !== 'ok') return;
    const favorites = routesOf(result.body, FAVORITES_MEMBER);
    const recents = routesOf(result.body, RECENTS_MEMBER);
    const moved =
      !this.answeredValue || !same(this.favoritesValue, favorites) || !same(this.recentsValue, recents);
    this.favoritesValue = favorites;
    this.recentsValue = recents;
    this.answeredValue = true;
    if (moved) this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
