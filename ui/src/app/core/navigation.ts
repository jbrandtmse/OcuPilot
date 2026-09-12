/**
 * The client's screen registry and the navigation map it gates on (AD-5, AD-8).
 *
 * Two halves, both framework-free so `node --test` executes them:
 *
 * - **The registry** -- ordered areas, each area's built screens, and the route-to-descriptor
 *   lookup -- reads `screens.generated.ts`, which is the mirror of the same XData the server
 *   reads. There is no second hand-written list of screens anywhere in the client, and the
 *   route table is built from this rather than typed out.
 * - **`NavigationService`** holds the map `GET /api/ocupilot/navigation` answered with: one
 *   `allowed` per area and per built screen and, when denied, the `(resource, permission)`
 *   pair that failed. The server recomputes every verdict from live state on every call
 *   (AD-8), so the map is a snapshot of an answer, never an authority in its own right.
 *
 * **A 403 re-reads the map.** Privileges can change after the map was fetched -- a role
 * revoked mid-session -- and the shell learns about it the moment any call is refused:
 * `ApiService` calls `noteForbidden()` on every 403 and the map is fetched again. The re-read
 * is a no-op while a fetch is in flight, which is what keeps the navigation call's own 403
 * (a caller who holds no administrative resource at all) from looping.
 *
 * **Before the map arrives nothing is gated.** An unanswered question is not a denial: marking
 * every entry gated until the first response would show an administrator a fully gated rail
 * for the length of one round trip. Entries become gated when the map says so.
 */

import type { ApiService } from './api';
import { AREAS, SCREENS, type AreaDeclaration, type ScreenDeclaration } from './screens.generated.ts';

/** Absolute from the origin root, through the one API service (AD-20). */
export const NAVIGATION_PATH = '/api/ocupilot/navigation';

/** One verdict: whether the calling process may reach a thing, and why not when it may not. */
export interface Verdict {
  readonly allowed: boolean;
  readonly failedPair: string;
}

/** The verdict a screen or an area carries before the map has answered. */
export const UNGATED: Verdict = { allowed: true, failedPair: '' };

interface ScreenVerdictWire {
  route?: unknown;
  allowed?: unknown;
  failedPair?: unknown;
}

interface AreaVerdictWire {
  key?: unknown;
  allowed?: unknown;
  failedPair?: unknown;
  screens?: unknown;
}

interface NavigationWire {
  areas?: unknown;
}

export interface NavigationOptions {
  readonly api: ApiService;
}

/** The areas in rail order. Agent co-pilot is pinned to the bottom by `pinBottom`. */
export function orderedAreas(): readonly AreaDeclaration[] {
  return AREAS;
}

/** The area declared under `key`, or `null`. */
export function areaByKey(key: string): AreaDeclaration | null {
  return AREAS.find((area) => area.key === key) ?? null;
}

/**
 * The screens an area's side bar lists: its own, built, in side-bar order. An area with no
 * built screens lists nothing, which is the correct rendering of "a screen that is not yet
 * built does not appear in the side-bar" (EXPERIENCE.md `:157`) and not a missing empty state.
 */
export function builtScreensForArea(areaKey: string): readonly ScreenDeclaration[] {
  return SCREENS.filter((screen) => screen.area === areaKey && screen.built).sort(
    (a, b) => a.sideBarPosition - b.sideBarPosition
  );
}

/** Every built screen, in area rail order then side-bar order. The route table reads this. */
export function builtScreens(): readonly ScreenDeclaration[] {
  return AREAS.flatMap((area) => builtScreensForArea(area.key));
}

/** The screen declared at `route`, or `null`. Home's route is the empty string. */
export function screenForRoute(route: string): ScreenDeclaration | null {
  return SCREENS.find((screen) => screen.route === route) ?? null;
}

/** Whether a screen is keyed by an id, and therefore carries an `/:id` route. */
export function hasIdRoute(screen: ScreenDeclaration): boolean {
  return screen.id.kind !== 'none';
}

/** The placeholder the Fixed strings table leaves for an area's own name. */
export const AREA_PLACEHOLDER = '<Area>';

/** The placeholder the Fixed strings table leaves for the privilege a control requires. */
export const RESOURCE_PLACEHOLDER = '<resource>';

/**
 * A canonical string with `<Area>` resolved to one area's name -- the rail item's tooltip and
 * the side bar's landmark both take it. A function rather than a `replace` inside a component,
 * for the reason `formatVersionMismatch` is one: renaming the placeholder on one side only
 * would ship the placeholder to the user, and a source-text pin cannot see that.
 */
export function formatArea(template: string, areaName: string): string {
  return template.split(AREA_PLACEHOLDER).join(areaName);
}

/**
 * `Requires <resource>` resolved to the `(resource, permission)` pair that failed, spelled
 * `resource:permission` -- which is what "a denial names the pair that failed" means at the
 * surface. The Fixed strings table has no permission-denied row of its own; this row is the
 * one it does have for a gated control, and it says exactly what is missing.
 */
export function formatRequires(template: string, failedPair: string): string {
  return template.split(RESOURCE_PLACEHOLDER).join(failedPair);
}

/** The declared route a router URL names: no leading slash, no query, no fragment. */
export function routeFromUrl(url: string): string {
  const path = url.split('?')[0].split('#')[0];
  return path.replace(/^\/+/, '').replace(/\/+$/, '');
}

/**
 * The screen a router URL resolves to, or `null`.
 *
 * A detail route carries the entity id as its last segment (AD-13: one segment, always), so a
 * URL that matches no declared route is tried once more without it. Nothing deeper is
 * attempted: an id is one segment by construction, so a second cut would only ever match a
 * shorter screen's route by accident.
 *
 * **Only built screens resolve.** An unbuilt screen is declared but has no route in the table
 * and no page behind it, so a URL naming one is a URL the client cannot render: it must reach
 * the not-found screen, not a screen that resolves and then draws nothing.
 */
export function screenForUrl(url: string): ScreenDeclaration | null {
  const path = routeFromUrl(url);
  const built = (screen: ScreenDeclaration | null): ScreenDeclaration | null =>
    screen !== null && screen.built ? screen : null;
  const exact = built(screenForRoute(path));
  if (exact !== null) return exact;
  const cut = path.lastIndexOf('/');
  if (cut < 0) return null;
  const parent = built(screenForRoute(path.slice(0, cut)));
  return parent !== null && hasIdRoute(parent) ? parent : null;
}

/** The area a router URL belongs to, or `''` when it names no declared screen. */
export function areaForUrl(url: string): string {
  return screenForUrl(url)?.area ?? '';
}

function asString(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function verdictFrom(entry: { allowed?: unknown; failedPair?: unknown }): Verdict {
  return { allowed: entry.allowed === true, failedPair: asString(entry.failedPair) };
}

export class NavigationService {
  private readonly api: ApiService;

  private areaVerdicts = new Map<string, Verdict>();
  private screenVerdicts = new Map<string, Verdict>();
  private loadedOnce = false;
  private inFlight: Promise<void> | null = null;

  /**
   * Bumped by `reset()`, read by `runLoad()` across its await. A map requested by one principal
   * must never be installed after another has taken the tab: the answer is about whoever asked
   * (AD-8). `InstanceService` carries the same counter for the same reason.
   */
  private generation = 0;

  private readonly listeners = new Set<() => void>();

  constructor(options: NavigationOptions) {
    this.api = options.api;
  }

  /** Whether a map has been received at all. Nothing is gated until it has. */
  loaded(): boolean {
    return this.loadedOnce;
  }

  /**
   * The areas the rail renders, and the screens an area's side bar lists.
   *
   * They delegate to the mirror and add nothing -- they exist on the service so a component
   * test can hand the rail and the side bar a roster the shipped mirror does not carry. At the
   * end of Epic 1 that mirror holds one screen, Home, whose area has no side bar, so without
   * this seam the side bar's own listing rules would have nothing to render and nothing to
   * assert. Production never overrides them.
   */
  areas(): readonly AreaDeclaration[] {
    return orderedAreas();
  }

  screensForArea(areaKey: string): readonly ScreenDeclaration[] {
    return builtScreensForArea(areaKey);
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** The verdict for an area's rail item and tile. */
  areaVerdict(key: string): Verdict {
    return this.areaVerdicts.get(key) ?? UNGATED;
  }

  /** The verdict for one screen, by its declared route. */
  screenVerdict(route: string): Verdict {
    return this.screenVerdicts.get(route) ?? UNGATED;
  }

  /**
   * Fetch the map. One request however many callers, for the reason `Session.refresh()` is
   * single-flight: the rail, the side bar and the routed screen all want it as the shell
   * paints.
   */
  load(): Promise<void> {
    const running = this.inFlight;
    if (running !== null) return running;
    // The in-flight slot is filled BEFORE the fetch starts, not after it returns. `runLoad`
    // begins executing synchronously up to its first `await`, and anything it reaches in that
    // window -- a refusal reported by the very call it is making -- would otherwise find an
    // empty slot and start another load, recursively.
    let settle: () => void = () => {};
    const gate = new Promise<void>((resolve) => {
      settle = resolve;
    });
    this.inFlight = gate;
    void this.runLoad()
      .catch(() => undefined)
      .finally(() => {
        if (this.inFlight === gate) this.inFlight = null;
        settle();
      });
    return gate;
  }

  /**
   * A call was refused: re-read the map, because the privileges it was computed from may have
   * moved.
   *
   * It carries no guard of its own. `load()` fills its in-flight slot **before** the fetch
   * starts, so a refusal reported by the navigation call itself -- a caller holding no
   * administrative resource at all, whose every request is a 403 -- finds that slot filled and
   * joins the fetch already running instead of starting another. A second guard here would be
   * a second copy of that rule, and nothing could tell it from a correct one.
   */
  noteForbidden(): void {
    void this.load();
  }

  /**
   * Forget the map, so the next `load()` asks again. The verdicts are about **this user**
   * (AD-8), and sign-out clears the tab in place without a reload, so a second principal
   * signing in must not inherit the first one's gating.
   */
  reset(): void {
    this.generation += 1;
    this.areaVerdicts = new Map();
    this.screenVerdicts = new Map();
    this.loadedOnce = false;
    this.inFlight = null;
    this.notify();
  }

  private async runLoad(): Promise<void> {
    const generation = this.generation;
    const result = await this.api.requestJson<NavigationWire>(NAVIGATION_PATH);
    if (result.kind !== 'ok') return;
    // Asked for by a principal who has since left the tab: discard it rather than reinstate
    // their gating over the one who replaced them.
    if (generation !== this.generation) return;
    const body = result.body ?? {};
    const areas = Array.isArray(body.areas) ? body.areas : [];

    const nextAreas = new Map<string, Verdict>();
    const nextScreens = new Map<string, Verdict>();
    for (const raw of areas) {
      if (typeof raw !== 'object' || raw === null) continue;
      const area = raw as AreaVerdictWire;
      const key = asString(area.key);
      if (key !== '') nextAreas.set(key, verdictFrom(area));
      const screens = Array.isArray(area.screens) ? area.screens : [];
      for (const rawScreen of screens) {
        if (typeof rawScreen !== 'object' || rawScreen === null) continue;
        const screen = rawScreen as ScreenVerdictWire;
        // Guarded the way the area key above is. Home's route legitimately IS '', so an entry
        // that carries no route at all would otherwise take Home's slot and gate the one screen
        // this epic ships.
        if (typeof screen.route !== 'string') continue;
        nextScreens.set(screen.route, verdictFrom(screen));
      }
    }

    this.areaVerdicts = nextAreas;
    this.screenVerdicts = nextScreens;
    this.loadedOnce = true;
    this.notify();
  }

  private notify(): void {
    for (const listener of this.listeners) listener();
  }
}
