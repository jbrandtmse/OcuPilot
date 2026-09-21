/**
 * Everything OcuPilot remembers about this user, over `/api/ocupilot/account/preferences`
 * (Stories 15.2 and 15.5, AD-50).
 *
 * **Every preference the product keeps is here, and none is in browser storage.** Favorites and
 * recent items are set membership; a screen's table view, a screen's auto-refresh rate and the two
 * pieces of shell chrome the user can move are values, keyed by route or by shell member. All of
 * it lives on the instance (AD-50, AD-28, AD-47): it survives a sign-out, it follows the user to
 * another tab and another machine, and the browser holds only the per-tab token pair.
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

/** The `kind` value naming one screen's remembered table view, keyed by route. */
export const VIEW_KIND = 'view';

/** The `kind` value naming one screen's remembered auto-refresh rate, keyed by route. */
export const REFRESH_KIND = 'refresh';

/** The `kind` value naming a remembered piece of shell chrome, keyed by shell member. */
export const SHELL_KIND = 'shell';

/** The `shell` member holding the side bar's open state, as `'1'` or `'0'`. */
export const SHELL_SIDE_BAR_OPEN = 'sideBarOpen';

/** The `shell` member holding the agent co-pilot panel's width in px. */
export const SHELL_PANEL_WIDTH = 'panelWidth';

/** The two membership lists, as the wire names them. */
export type PreferenceKind = typeof FAVORITE_KIND | typeof RECENT_KIND;

/** The three value kinds, as the wire names them. */
export type PreferenceValueKind = typeof VIEW_KIND | typeof REFRESH_KIND | typeof SHELL_KIND;

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

/** The body member each list arrives under, and the members a write names a key and a value with. */
const FAVORITES_MEMBER = 'favorites';
const RECENTS_MEMBER = 'recents';
const VIEWS_MEMBER = 'views';
const REFRESH_RATES_MEMBER = 'refreshRates';
const SHELL_MEMBER = 'shell';
const ROUTE_MEMBER = 'route';
const NAME_MEMBER = 'name';
const VALUE_MEMBER = 'value';

/**
 * Which body member a value kind's key arrives under: a screen-scoped kind is keyed by `route`, a
 * shell one by `name`. Held here so the write and the read read one answer.
 */
function keyMemberFor(kind: PreferenceValueKind): string {
  return kind === SHELL_KIND ? NAME_MEMBER : ROUTE_MEMBER;
}

/**
 * One value list of the answered body, as a key-to-value map.
 *
 * Narrowed rather than cast, the way `routesOf` narrows a membership list: an entry that is not an
 * object, or whose key or value is not a non-empty string, is dropped rather than becoming a
 * preference nothing can mean. An answer carrying no such member reads as an empty map, which is
 * what a body from an instance that predates Story 15.5 looks like.
 */
function valuesOf(body: unknown, member: string, keyMember: string): ReadonlyMap<string, string> {
  const out = new Map<string, string>();
  if (typeof body !== 'object' || body === null) return out;
  const raw = (body as Record<string, unknown>)[member];
  if (!Array.isArray(raw)) return out;
  for (const entry of raw) {
    if (entry === null || typeof entry !== 'object' || Array.isArray(entry)) continue;
    const row = entry as Record<string, unknown>;
    const key = row[keyMember];
    const value = row[VALUE_MEMBER];
    if (typeof key !== 'string' || key === '') continue;
    if (typeof value !== 'string' || value === '') continue;
    out.set(key, value);
  }
  return out;
}

/** Whether two maps say the same thing, so a re-read that confirms one re-renders nothing. */
function sameMap(a: ReadonlyMap<string, string>, b: ReadonlyMap<string, string>): boolean {
  if (a.size !== b.size) return false;
  for (const [key, value] of a) {
    if (b.get(key) !== value) return false;
  }
  return true;
}

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

  private viewsValue: ReadonlyMap<string, string> = new Map();

  private refreshRatesValue: ReadonlyMap<string, string> = new Map();

  private shellValue: ReadonlyMap<string, string> = new Map();

  private answeredValue = false;

  /**
   * Whether an answer has settled **since a read was asked for**, which is what the three stores
   * that adopt a remembered value key off.
   *
   * **Not `answeredValue`.** Every write answers the whole body too, so a store whose first answer
   * is a write's would look settled -- and the stores would take a remembered value from a body
   * that arrived after the user had already moved the thing it describes. A dismissal that
   * deliberately persists nothing (`ShellState.collapse`) is exactly the state that would be
   * undone.
   *
   * **And not "the read itself settled".** A read and a write issued together race, and only the
   * newest answer wins (`request`): on a reloaded tab the visit `recents-recorder.ts` registers is
   * issued just after the read and its answer supersedes it. That answer carries the same whole
   * body, so it settles the question the read asked -- which is why this turns on the read having
   * been *asked for*, not on which answer happened to land. Keying it on the read's own settle
   * left a reloaded tab on the published defaults with the instance's answer already in hand.
   */
  private loadedValue = false;

  /** Whether `load()` has been called since the last `reset()`; see `loadedValue`. */
  private readIssued = false;

  /**
   * The latest value each key is waiting to send, and the keys with a write already in flight.
   *
   * **One write per key at a time, and only the latest value.** A width gesture sends a value per
   * 16 px step and a filter one per keystroke, and three requests issued a few milliseconds apart
   * do not have to arrive in that order -- measured: a panel stepped 416, 432, 448 was left
   * holding 432, because the last write landed first. Serializing per key makes the order the
   * user's, and collapsing a burst to its latest value makes a typed filter one request rather
   * than one per character.
   */
  private readonly pendingValues = new Map<string, string>();

  private readonly writingKeys = new Set<string>();

  /**
   * The published reason the instance last refused a preference write with, `''` for none
   * (DW-1326).
   *
   * **Server text, never client copy** (AD-39): the envelope's own `reason`, which the two
   * surfaces that write preferences announce as `role="alert"` rather than as the polite
   * confirmation a success takes (EXPERIENCE.md "Status messages (WCAG 4.1.3)"). A refusal that
   * carries no reason -- an instance that did not answer at all -- records none, because the
   * connectivity banner is already saying that and a second, wordless alert says nothing.
   */
  private faultValue = '';

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

  /** Whether the instance has ever answered, so a caller can tell "no rows" from "not asked yet". */
  answered(): boolean {
    return this.answeredValue;
  }

  /**
   * Whether the read this shell asked for has been answered, which is what the stores that adopt
   * a remembered value key off (Story 15.5). A write's answer before any read is not one: see
   * `loadedValue`.
   */
  loaded(): boolean {
    return this.loadedValue;
  }

  /** The pinned screens' routes, oldest first, as the instance ordered them. */
  favorites(): readonly string[] {
    return this.favoritesValue;
  }

  /** The visited screens' routes, newest first, as the instance ordered them. */
  recents(): readonly string[] {
    return this.recentsValue;
  }

  /** Each screen's remembered table view, keyed by route. The value is opaque to this store. */
  views(): ReadonlyMap<string, string> {
    return this.viewsValue;
  }

  /** Each screen's remembered auto-refresh rate in whole seconds, keyed by route. */
  refreshRates(): ReadonlyMap<string, string> {
    return this.refreshRatesValue;
  }

  /** The remembered pieces of shell chrome, keyed by shell member. */
  shell(): ReadonlyMap<string, string> {
    return this.shellValue;
  }

  /** The instance's own sentence for the last refused write, `''` for none (DW-1326). */
  fault(): string {
    return this.faultValue;
  }

  /** Drop the standing refusal, so a surface that has announced one does not announce it twice. */
  clearFault(): void {
    if (this.faultValue === '') return;
    this.faultValue = '';
    this.notify();
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
    this.readIssued = true;
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
   * Remember `value` for `key` under `kind` -- a route for a screen-scoped kind, a shell member
   * for `shell`.
   *
   * An empty value is never sent: the instance refuses one (an empty `%String` stores as SQL
   * `NULL`), so a caller with nothing to remember is a caller with nothing to write.
   */
  setValue(kind: PreferenceValueKind, key: string, value: string): Promise<void> {
    if (key === '' || value === '') return Promise.resolve();
    const slot = `${kind}\u0000${key}`;
    this.pendingValues.set(slot, value);
    // A call that joins a write already in flight resolves when it is queued, not when it lands:
    // every caller here is fire and forget, and what it is promised is that the instance ends up
    // holding this value, which `drain` is what guarantees.
    if (this.writingKeys.has(slot)) return Promise.resolve();
    this.writingKeys.add(slot);
    return this.drain(kind, key, slot);
  }

  /** Send this key's pending value, and whatever replaced it while that was in flight. */
  private async drain(kind: PreferenceValueKind, key: string, slot: string): Promise<void> {
    try {
      while (this.pendingValues.has(slot)) {
        const value = this.pendingValues.get(slot) ?? '';
        this.pendingValues.delete(slot);
        const body: Record<string, string> = { kind, action: 'set' };
        body[keyMemberFor(kind)] = key;
        body[VALUE_MEMBER] = value;
        await this.settle(
          this.api.requestJson<unknown>(ACCOUNT_PREFERENCES_PATH, {
            method: 'POST',
            body: JSON.stringify(body),
          })
        );
      }
    } finally {
      this.writingKeys.delete(slot);
    }
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
    this.viewsValue = new Map();
    this.refreshRatesValue = new Map();
    this.shellValue = new Map();
    this.faultValue = '';
    this.answeredValue = false;
    this.loadedValue = false;
    this.readIssued = false;
    this.pendingValues.clear();
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
    // A refusal is not an answer about what the account holds, and neither is an instance that did
    // not reply: both leave the previous lists standing rather than emptying the blocks. What the
    // refusal does now leave is its published sentence (DW-1326), which the two writing surfaces
    // announce; it used to leave nothing at all, so a refused write looked like a write that had
    // not happened yet.
    if (result.kind !== 'ok') {
      const reason = result.kind === 'error' && typeof result.reason === 'string' ? result.reason : '';
      if (reason !== this.faultValue) {
        this.faultValue = reason;
        this.notify();
      }
      return;
    }
    const favorites = routesOf(result.body, FAVORITES_MEMBER);
    const recents = routesOf(result.body, RECENTS_MEMBER);
    const views = valuesOf(result.body, VIEWS_MEMBER, ROUTE_MEMBER);
    const refreshRates = valuesOf(result.body, REFRESH_RATES_MEMBER, ROUTE_MEMBER);
    const shell = valuesOf(result.body, SHELL_MEMBER, NAME_MEMBER);
    // The answer that settles the read this store was asked for always notifies, even when it
    // says exactly what the store already held: the stores that adopt a remembered value are
    // waiting on that notification and there is nothing else to wake them.
    const settlesTheRead = this.readIssued && !this.loadedValue;
    const moved =
      !this.answeredValue ||
      settlesTheRead ||
      this.faultValue !== '' ||
      !same(this.favoritesValue, favorites) ||
      !same(this.recentsValue, recents) ||
      !sameMap(this.viewsValue, views) ||
      !sameMap(this.refreshRatesValue, refreshRates) ||
      !sameMap(this.shellValue, shell);
    this.favoritesValue = favorites;
    this.recentsValue = recents;
    this.viewsValue = views;
    this.refreshRatesValue = refreshRates;
    this.shellValue = shell;
    this.faultValue = '';
    this.answeredValue = true;
    if (this.readIssued) this.loadedValue = true;
    if (moved) this.notify();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
