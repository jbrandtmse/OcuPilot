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
 * joins a fetch already running **in the same namespace**, which is what keeps the navigation
 * call's own 403 (a caller who holds no administrative resource at all) from looping; a fetch
 * running against a namespace the shell has since left is re-run once instead (**DW-157**,
 * `single-flight.ts`).
 *
 * **Before the map arrives nothing is gated.** An unanswered question is not a denial: marking
 * every entry gated until the first response would show an administrator a fully gated rail
 * for the length of one round trip. Entries become gated when the map says so. What waits for
 * the map is a screen's page: `ScreenOutlet` mounts none until `answered()`, so a screen the map
 * then refuses issues no read of its own.
 */

import type { ApiService } from './api';
import type { ConnectivityService } from './connectivity';
import { AREAS, SCREENS, type AreaDeclaration, type ScreenDeclaration } from './screens.generated.ts';
import { createSingleFlight } from './single-flight.ts';

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
  /**
   * Where a failed map read is parked (DW-135). Optional so a test that is not about the
   * re-read can leave it out.
   */
  readonly connectivity?: ConnectivityService;
  /**
   * The resolved namespace the map is computed against (AD-44), read at call time rather than
   * held -- the same lazy shape `ApiOptions.scope` uses, and for the same reason: `src/main.ts`
   * builds this service before the one that answers it.
   *
   * It is the **single-flight key** (**DW-157**): a map read already in flight is the right
   * answer for a second caller in the same namespace and the wrong one after a switch, and the
   * key is what tells those apart. Defaults to `() => ''`, which makes every read join -- the
   * behaviour of a shell that is not namespace-scoped at all.
   */
  readonly namespace?: () => string;
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
 * built does not appear in the side-bar" (EXPERIENCE.md "Entries in daily-use order.") and not a missing empty state.
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

/**
 * The first screen in `screens` the caller may actually open, or `null` when none of them is
 * (**DW-161**).
 *
 * Every surface that opens "the area's first screen" -- Home's tile, the locator's area segment
 * -- has to answer the same question, and answering it as `screens[0]` navigates a user with the
 * area but not its first screen straight into a refusal. The verdict is passed in rather than
 * read here so this stays a pure function over a roster and a lookup: the same shape
 * `formatRequires` and `withQuery` take, and executable under `node --test`.
 *
 * An empty roster answers `null` as well, which is the same answer for a different reason -- an
 * area with nothing built has nowhere to go either. Callers that must tell "nowhere to go" from
 * "somewhere, but refused" compare the roster's own length.
 */
export function firstAllowedScreen(
  screens: readonly ScreenDeclaration[],
  verdictFor: (route: string) => Verdict
): ScreenDeclaration | null {
  return screens.find((screen) => verdictFor(screen.route).allowed) ?? null;
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
 * surface of a gated control.
 */
export function formatRequires(template: string, failedPair: string): string {
  return template.split(RESOURCE_PLACEHOLDER).join(failedPair);
}

/** The placeholder the Fixed strings table leaves for a screen's own title. */
export const SCREEN_PLACEHOLDER = '<screen>';

/**
 * `You need <resource> to open <screen>.` resolved to the failed `resource:permission` pair and
 * the screen's title -- the permission-denied screen's sentence. A function for the reason
 * `formatRequires` is one.
 */
export function formatDeniedScreen(template: string, failedPair: string, screenTitle: string): string {
  return template.split(RESOURCE_PLACEHOLDER).join(failedPair).split(SCREEN_PLACEHOLDER).join(screenTitle);
}

/** The one query parameter that is data scope rather than screen state (AD-44). */
export const NAMESPACE_PARAM = 'ns';

/**
 * A target URL for `route` carrying the namespace `currentUrl` is scoped to (AD-44,
 * **DW-134**).
 *
 * `?ns=` is data scope, not decoration: it selects the namespace every read and write on the
 * screen executes against, so dropping it on a rail, side-bar, locator or command-box click
 * would silently move the user's work to another namespace. Navigating with a bare
 * `'/' + route` is exactly that drop, which is why the join lives here rather than being
 * spelled at each call site.
 *
 * **Only `ns` travels.** Every other parameter is the leaving screen's own state -- a page, a
 * filter, a sort -- and applying it to an unrelated screen would be a different bug from the
 * one this fixes. The fragment is not carried either: it addresses a position inside the
 * screen being left.
 */
export function withQuery(route: string, currentUrl: string): string {
  const cut = currentUrl.indexOf('?');
  if (cut < 0) return '/' + route;
  const namespace = new URLSearchParams(currentUrl.slice(cut + 1).split('#')[0]).get(
    NAMESPACE_PARAM
  );
  if (namespace === null) return '/' + route;
  return '/' + route + '?' + NAMESPACE_PARAM + '=' + encodeURIComponent(namespace);
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
  private readonly connectivity: ConnectivityService | null;
  private readonly namespace: () => string;

  private areaVerdicts = new Map<string, Verdict>();
  private screenVerdicts = new Map<string, Verdict>();
  private loadedOnce = false;
  private answeredOnce = false;

  /**
   * The map read, on the shared primitive (**DW-157**). Join on an unchanged namespace,
   * mark-dirty-and-re-run-once on a changed one; the slot is filled before the fetch starts, which
   * is what the DW-9 stub's own refusal depends on.
   */
  private readonly flight = createSingleFlight(
    (key) => this.runLoad(key),
    () => this.namespace()
  );

  /**
   * Bumped by `reset()`, read by `runLoad()` across its await. A map requested by one principal
   * must never be installed after another has taken the tab: the answer is about whoever asked
   * (AD-8). `InstanceService` carries the same counter for the same reason.
   */
  private generation = 0;

  private readonly listeners = new Set<() => void>();

  constructor(options: NavigationOptions) {
    this.api = options.api;
    this.connectivity = options.connectivity ?? null;
    this.namespace = options.namespace ?? (() => '');
  }

  /** Whether a map has been received at all. Nothing is gated until it has. */
  loaded(): boolean {
    return this.loadedOnce;
  }

  /**
   * Whether a map read has completed for this principal, with a map or with a failure. A screen's
   * page is not mounted before it has (`ScreenOutlet`), so a screen the map is about to refuse
   * issues no read of its own. A failed read counts as completed: every verdict then stays
   * `UNGATED` and the page mounts, because the server is the gate (AD-8).
   */
  answered(): boolean {
    return this.answeredOnce;
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

  /**
   * Every built screen, and the screen a router URL resolves to. Seams for the same reason
   * `areas()` is one: the command box lists every screen the user may open and the command
   * bar reads the current screen's declared actions, and no screen in the shipped mirror
   * declares an action, so neither rule would have a subject in a component test.
   * Production never overrides them.
   */
  builtScreens(): readonly ScreenDeclaration[] {
    return builtScreens();
  }

  screenForUrl(url: string): ScreenDeclaration | null {
    return screenForUrl(url);
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
   * Fetch the map. One request however many callers in the same namespace, for the reason
   * `Session.refresh()` is single-flight: the rail, the side bar and the routed screen all want
   * it as the shell paints.
   *
   * A caller arriving after the namespace has moved is a different question, not a repeat of
   * this one, and `createSingleFlight` answers it with one re-run rather than a join
   * (**DW-157**).
   */
  load(): Promise<void> {
    return this.flight.request();
  }

  /**
   * A call was refused: re-read the map, because the privileges it was computed from may have
   * moved.
   *
   * It carries no guard of its own. `createSingleFlight` fills its slot **before** the fetch
   * starts, so a refusal reported by the navigation call itself -- a caller holding no
   * administrative resource at all, whose every request is a 403 -- finds that slot filled, and
   * finds the namespace unchanged, so it joins rather than queueing. A second guard here would be
   * a second copy of that rule, and nothing could tell it from a correct one.
   */
  noteForbidden(): void {
    this.reload();
  }

  /**
   * Read the map again, because something it was computed against has moved -- a refusal above,
   * or the namespace every call is now scoped to (AD-44). The same single-flight `load()`, named
   * for the general case so a caller that is not reacting to a 403 does not have to call one.
   *
   * **What it does about a read already in flight depends on the namespace, and only on that.**
   * The same namespace joins, which is what keeps the shell from issuing a map read per router
   * event while one is outstanding. A namespace that has moved marks the flight and re-runs once
   * against the new one, because the verdict a read started under the old namespace installs is
   * an answer to a question nobody is asking any more (**DW-157**).
   */
  reload(): void {
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
    this.answeredOnce = false;
    this.flight.reset();
    this.notify();
  }

  /**
   * `key` is the namespace the flight was issued against, and it is sent as this call's own scope
   * rather than left to `ApiService`'s live source. The two agree in production -- nothing can
   * change the namespace between `keyOf()` and this line, both being synchronous -- and pinning it
   * is what makes "the re-run carries the new namespace" a property of the request rather than of
   * a service the request happens to consult.
   *
   * An empty key is a service with no namespace source configured, not a namespace of `''`: it
   * sends no scope of its own and `ApiService` attaches whatever the shell is scoped to, which is
   * what this read did before it was keyed.
   */
  private async runLoad(key: string): Promise<void> {
    const generation = this.generation;
    const result = await this.api.requestJson<NavigationWire>(
      NAVIGATION_PATH,
      key === '' ? {} : { scope: key }
    );
    // Asked for by a principal who has since left the tab: discard it rather than reinstate
    // their gating over the one who replaced them. Checked **before** the failure branch, and
    // for the same reason the success branch checks it: a failed read belonging to a departed
    // principal must not park a re-run either. `scope.ts` orders the two the same way.
    if (generation !== this.generation) return;
    if (result.kind !== 'ok') {
      if (!this.answeredOnce) {
        this.answeredOnce = true;
        this.notify();
      }
      // **DW-135: fail open, but never silently.** Every verdict stays `UNGATED`, because AD-8
      // makes the server the gate and closing the client over an unanswered question would lock
      // a user out of screens they hold. What was missing was the other half: an unreachable
      // instance left the rail fully open and said nothing, so it read as an instance the user
      // has no rights on. The failure is now published -- `ApiService` has already classified
      // it -- and the read is parked for one re-run when the instance answers again.
      this.connectivity?.retryWhenReachable(NAVIGATION_PATH, () => this.reload());
      return;
    }
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
        // that carries no route at all would otherwise take Home's slot and gate Home.
        if (typeof screen.route !== 'string') continue;
        nextScreens.set(screen.route, verdictFrom(screen));
      }
    }

    this.areaVerdicts = nextAreas;
    this.screenVerdicts = nextScreens;
    this.loadedOnce = true;
    this.answeredOnce = true;
    this.notify();
  }

  private notify(): void {
    for (const listener of this.listeners) listener();
  }
}
