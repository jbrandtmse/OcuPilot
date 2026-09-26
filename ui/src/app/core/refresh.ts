/**
 * The one auto-refresh framework (AD-43), and the proposal pause that is part of it.
 *
 * A screen declares in its descriptor whether it refreshes and at what rates (AD-5); this owns
 * everything else -- one timer, one persisted per-screen setting, one silent re-fetch through the
 * screen's own registered read (AD-36), and the pause while a proposal against the screen's
 * entity type is live. Every refreshing screen therefore implements none of it, which is the
 * point: a timer per screen is one place per screen for "sort, filter, selection and scroll
 * survive a tick" to be almost true.
 *
 * **One arm, ever.** The `schedule` seam has no cancel handle -- it is the bare
 * `(run, delayMs) => void` shape `connectivity.ts` and `session.ts` already inject -- so an arm is
 * cancelled by a generation counter captured when it was armed and compared inside the callback
 * (`session.ts:305-311`'s idiom). Every transition bumps the counter and re-arms exactly once, so
 * a rate change, a proposal, a fault, an unbind and a sign-out each leave one pending arm and
 * never two.
 *
 * **Resume is a predicate, never a `paused` flag.** Three separate conditions suspend the timer --
 * the rate is off, a proposal is live, a fault parked a re-arm -- and Story 1.13 spent three
 * findings on exactly this shape: a recovery path cancelled by the event meant to drive it. A
 * boolean cleared by `proposal-closed` would resume a timer a fault had suspended, and a boolean
 * cleared by the connectivity park would resume one a proposal had paused. So nothing clears a
 * flag: `canArm()` recomputes all three on every transition.
 *
 * **The pause is held by a set of ids, and it expires.** Two opens and one close stays paused
 * (AD-6 mints one proposal per write, and a turn can mint several). A close that never arrives --
 * a turn that died, a browser that missed the event -- would otherwise strand the pause forever,
 * so `proposal-open` carries `expiresAt` and the pause's own deadline is what the one timer is
 * armed for while it holds: the seam is driven past the expiry, the id is dropped, and the tick
 * arm comes back. **That deadline is the same arm, not a second timer** -- `armedFor()` names
 * which of the two the one arm is currently serving, so "zero tick arms while paused" and "the
 * pause has a deadline" are both true and both observable.
 *
 * **A tick that meets a fault suspends and parks one re-arm.** It never probes, never classifies
 * and never re-arms itself: Story 1.13 owns the taxonomy, the probe and its backoff, and this
 * module imports no `ApiService` at all. The park lifts the suspension only for a banner fault
 * (`isBannerFault`), the kinds whose recovery the connectivity probe reports; any other kind was
 * an answer, not an outage, and stays suspended until a `readNow()` succeeds -- Retry, a max-rows
 * commit, a scope switch or a `changed` event, each a new request rather than a retry -- because a
 * success elsewhere draining the park would otherwise retry a refused read (AD-8). This is correct only because `connectivity.reset()` and `reset()` here are called in
 * the same sign-out gesture (`app.ts`).
 *
 * **Binding is the screen's own act** (`ListPage`), refused for a refreshing screen that
 * registered no read, because a framework that invented a read of its own would be the second
 * query AD-36 exists to prevent. `readNow()` runs that same read outside the timer -- the first
 * load, Retry, a max-rows commit, a scope switch and a `changed` event -- under the same
 * superseded-read guard as a tick.
 *
 * Framework-free, like the rest of `core/`, so `ui/tools/refresh.test.mjs` executes it under
 * `node --test`. Every cadence and every expiry is observable as the `delayMs` handed to the
 * seam, so no test waits on a clock.
 */

import type { ChangeBus, ChangeEvent } from './change-bus';
import type { ConnectivityService } from './connectivity';
import { type Fault, isBannerFault } from './fault.ts';
import { screenShowsEntity } from './navigation.ts';
import { RATE_OFF, type ScreenStore, type ScreenStores } from './screen-store.ts';
import type { ScreenDeclaration } from './screens.generated';
import { STRINGS } from './strings.ts';

/**
 * The key a suspended timer parks its one re-arm under. One key, not one per screen: a park is
 * keyed so repeats collapse (`connectivity.ts`), and there is one bound screen at a time.
 */
export const REFRESH_PARK_KEY = 'ocupilot.refresh';

/**
 * What a screen's registered read answers. A fault is already classified -- this never does.
 *
 * `banner` is the string key of the strip the answer raises above the table: screen chrome the
 * instance resolved inside the same read (AD-36), so a tick re-evaluates it and the strip is gone
 * the moment the condition clears (EXPERIENCE.md "panel (top), form-pages, Task"). It is optional, and an omitted one reads
 * as no strip -- the key is additive, a screen that declares no banner never carries it, and a read
 * that could not resolve one answers `''` for the same reason `OcuPilot.Screen.Read.BannerKey`
 * does: a strip is chrome over rows, and the rows are what the screen is for.
 */
export type RefreshReadResult =
  | { readonly kind: 'ok'; readonly rows: readonly unknown[]; readonly truncated: boolean; readonly banner?: string }
  | { readonly kind: 'fault'; readonly fault: Fault };

/**
 * The screen's own read (AD-36), handed the cap it must respect. `createScreenRead` in
 * `screen-read.ts` builds it from a screen's declaration; this module owns the contract, which is
 * that there is exactly one and the tick calls it.
 */
export type RefreshRead = (options: { readonly maxRows: number }) => Promise<RefreshReadResult>;

/** The message a refreshing screen that registered no read is refused with. */
export const MISSING_READ_MESSAGE =
  'the refresh framework issues no read of its own (AD-36); register the screen read for ';

/** The span the auto-refresh chip's "on" string leaves for the rate (EXPERIENCE.md "command-bar chip states; status-bar"). */
export const RATE_PLACEHOLDER = '<n>';

/**
 * `Auto-refresh: every <n> s` with the rate, in seconds, filled in. A function rather than a
 * `replace` inside the chip, for the reason `formatLastUpdate` is one: renaming the span on one
 * side only would compile, build, and ship `<n>` to the user.
 */
export function formatAutoRefreshOn(template: string, rate: number): string {
  return template.split(RATE_PLACEHOLDER).join(String(rate));
}

/** The span the last-update string leaves for the time (EXPERIENCE.md "command-bar chip states; status-bar"). */
export const LAST_UPDATE_PLACEHOLDER = 'hh:mm:ss';

/**
 * `Last update hh:mm:ss` with the time filled in, local and 24-hour.
 *
 * A function rather than a `replace` inside the status bar, for the reason `formatArea` is one:
 * renaming the span on one side only would compile, build, and ship `hh:mm:ss` to the user.
 */
export function formatLastUpdate(template: string, at: Date): string {
  const pad = (value: number): string => String(value).padStart(2, '0');
  const time = pad(at.getHours()) + ':' + pad(at.getMinutes()) + ':' + pad(at.getSeconds());
  return template.split(LAST_UPDATE_PLACEHOLDER).join(time);
}

export interface RefreshOptions {
  readonly stores: ScreenStores;
  readonly connectivity: ConnectivityService;
  readonly bus: ChangeBus;
  /**
   * The resolved namespace a `namespace`-scoped screen's references carry (AD-13, AD-44), read at
   * call time. Lazy for the reason `ApiOptions.scope` is: `src/main.ts` builds this service
   * alongside the one that answers it.
   */
  readonly namespace?: () => string;
  /** Defaults to `setTimeout`. Byte-identical in shape to `connectivity.ts`'s and `session.ts`'s. */
  readonly schedule?: (run: () => void, delayMs: number) => void;
  /** Defaults to `Date`. The tick's stamp and the expiry sweep both read it. */
  readonly now?: () => Date;
}

/**
 * What the one arm is serving: a re-fetch, the live pause's own deadline, or nothing. There is
 * never more than one, whatever the bound screen and whatever the rate.
 */
export type ArmKind = 'none' | 'tick' | 'expiry';

/** The screen currently bound, resolved once so the tick and the bus read the same values. */
interface Bound {
  readonly descriptor: string;
  readonly refreshes: boolean;
  /** The declaration itself, so the bus filter asks `screenShowsEntity` rather than re-deriving it. */
  readonly screen: ScreenDeclaration;
  readonly read: RefreshRead | null;
  readonly store: ScreenStore;
}

export class RefreshService {
  private readonly stores: ScreenStores;
  private readonly connectivity: ConnectivityService;
  private readonly bus: ChangeBus;
  private readonly namespace: () => string;
  private readonly schedule: (run: () => void, delayMs: number) => void;
  private readonly now: () => Date;

  private bound: Bound | null = null;

  /**
   * Bumped by every transition; captured at arm time and compared inside the callback. An arm
   * whose generation has moved returns without touching anything, because the transition that
   * moved it has already armed whatever comes next.
   */
  private generation = 0;

  /** What the one current-generation arm is serving. Exactly one arm, or none, at every moment. */
  private arm: ArmKind = 'none';

  /** A read met a fault; the connectivity park or a successful `readNow()` lifts it. */
  private suspended = false;

  /** The bound read's last fault, or `null` once a read has succeeded since. */
  private lastFault: Fault | null = null;

  /** Whether a read has succeeded since the bind or the last scope switch. */
  private loadedOnce = false;

  /** Reads issued, so a read that a later one has overtaken cannot write the store. */
  private issued = 0;

  /** Live proposals against the bound screen, by id, each with the moment it stops being live. */
  private readonly liveProposals = new Map<string, number>();

  private stopBus: (() => void) | null = null;

  /** Released on unbind: the bound store's own notifications, read for a rate it adopted. */
  private stopStore: (() => void) | null = null;

  /** The rate the last transition armed for, so a rate the store adopts later re-arms. */
  private armedRate = RATE_OFF;

  /** Set while `setRate` writes the store, which transitions on its own. */
  private settingRate = false;

  private readonly listeners = new Set<() => void>();

  constructor(options: RefreshOptions) {
    this.stores = options.stores;
    this.connectivity = options.connectivity;
    this.bus = options.bus;
    this.namespace = options.namespace ?? (() => '');
    this.schedule =
      options.schedule ??
      ((run, delayMs) => {
        setTimeout(run, delayMs);
      });
    this.now = options.now ?? (() => new Date());
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  // --- Binding ---------------------------------------------------------------------------------

  /**
   * Bind `screen`, with the read its ticks call.
   *
   * A screen that declares `refreshes` and registers no read is **refused**: the framework
   * re-fetches through the screen's own read and has none of its own (AD-36), so binding one
   * would arm a timer that could only ever fail. A screen that does not refresh binds without a
   * read -- it still gets a store, which is where its sort, filter and max rows live.
   *
   * **A re-bind is a no-op only when the read is the same one too.** Stores are keyed by
   * descriptor so a detail screen's several URLs share one, which means the same descriptor is
   * re-bound with a *different* read every time the entity changes; comparing the descriptor
   * alone would leave the timer calling the previous entity's read and writing its rows into the
   * store the screen renders.
   */
  bind(screen: ScreenDeclaration, read: RefreshRead | null = null): void {
    if (screen.refreshes && read === null) {
      throw new Error(MISSING_READ_MESSAGE + screen.descriptor);
    }
    if (this.bound?.descriptor === screen.descriptor && this.bound.read === read) return;
    this.unbind();
    this.bound = {
      descriptor: screen.descriptor,
      refreshes: screen.refreshes,
      screen,
      read,
      store: this.stores.for(screen.descriptor, screen.refreshRates, screen.route, screen.refreshDefault),
    };
    this.lastFault = null;
    this.loadedOnce = false;
    this.stopBus = this.bus.subscribe((event) => this.onBusEvent(event));
    const store = this.bound.store;
    this.stopStore = store.subscribe(() => this.onStoreChanged(store));
    this.transition();
    this.notify();
  }

  /** Let go of the bound screen. Its store survives, so returning to it restores the setting. */
  unbind(): void {
    this.stopBus?.();
    this.stopBus = null;
    this.stopStore?.();
    this.stopStore = null;
    this.bound = null;
    this.liveProposals.clear();
    this.suspended = false;
    this.lastFault = null;
    this.loadedOnce = false;
    this.transition();
    this.notify();
  }

  /**
   * Forget everything this principal had. Called from the same sign-out teardown as
   * `connectivity.reset()`, which is what drops the park a fault suspension is waiting on -- the
   * two are one gesture, and a suspension whose park outlived it would never resume.
   */
  reset(): void {
    this.unbind();
    this.stores.reset();
    this.notify();
  }

  // --- What the chrome reads --------------------------------------------------------------------

  /** The descriptor bound, or `''`. */
  descriptor(): string {
    return this.bound?.descriptor ?? '';
  }

  /** Whether the bound screen is one the framework refreshes at all. */
  refreshes(): boolean {
    return this.bound?.refreshes === true;
  }

  /** The current rate in seconds; `0` is off. */
  rate(): number {
    return this.bound?.store.rate() ?? RATE_OFF;
  }

  /** The rates the bound screen's descriptor permits. */
  rates(): readonly number[] {
    return this.bound?.store.rates() ?? [];
  }

  /** When the bound screen's data last landed, or `null` when nothing has. */
  lastUpdate(): Date | null {
    return this.bound?.store.lastUpdate() ?? null;
  }

  /** The bound read's last fault, or `null` when its last read succeeded or none has failed. */
  fault(): Fault | null {
    return this.lastFault;
  }

  /** Whether the bound read has succeeded since the bind or the last scope switch. */
  hasLoaded(): boolean {
    return this.loadedOnce;
  }

  /** Whether a proposal against the bound screen's entity is holding the timer. */
  paused(): boolean {
    return this.liveProposals.size > 0;
  }

  /**
   * What the one outstanding arm is serving, or `'none'`.
   *
   * `'tick'` is a pending re-fetch; `'expiry'` is the live pause's own deadline, which issues no
   * read and exists so an unclosed proposal cannot strand the screen. A paused screen therefore
   * has zero `'tick'` arms, which is the invariant, and still has a way back.
   */
  armedFor(): ArmKind {
    return this.arm;
  }

  /**
   * The chip's literal, or `''` for a screen with no chip.
   *
   * Three published states and no fourth (EXPERIENCE.md "command-bar chip states; status-bar"): off, the rate, and paused. A
   * fault-suspended timer keeps showing its rate, because the chip reads the **setting** the user
   * chose and the instance being unreachable is the banner's news, not the chip's (DW-126
   * publishes no fourth literal, and inventing one is not available).
   *
   * **Off wins over paused.** A pause is something happening to a timer, and a screen switched off
   * has none: "Auto-refresh paused" there would report a state the user cannot see the point of,
   * and it would also be the one state nothing lifts -- the expiry deadline is only armed while
   * the rate is above zero, so a proposal opening against an off screen would hold that literal
   * until the screen was left. Reading the rate first makes both go away.
   */
  chipLabel(): string {
    if (!this.refreshes()) return '';
    const rate = this.rate();
    if (rate === RATE_OFF) return STRINGS.statusAutoRefreshOff;
    if (this.paused()) return STRINGS.statusAutoRefreshPaused;
    return formatAutoRefreshOn(STRINGS.statusAutoRefreshOn, rate);
  }

  /**
   * The next rate in the chip's cycle: off, then each permitted rate ascending, then off again.
   *
   * A cycle rather than a menu, because a menu needs an accessible name and a label per option
   * and EXPERIENCE.md publishes neither (DW-126). A chip whose visible literal *is* its accessible
   * name invents nothing; with one permitted rate it reads as a toggle.
   */
  advanceRate(): void {
    const cycle = [RATE_OFF, ...this.rates()];
    const next = cycle[(cycle.indexOf(this.rate()) + 1) % cycle.length];
    this.setRate(next);
  }

  /**
   * The resolved namespace moved (AD-44): switching re-fetches rather than re-routes.
   *
   * A namespace-scoped screen's rows, its `Last update` stamp and any proposal against its entity
   * are all answers about the namespace the shell has just left, so they go; the rate is the
   * user's setting for the screen and stays. The timer then re-arms and the next tick reads the
   * namespace now in force. Dropping the live proposals is also what stops a switch stranding the
   * pause: a `proposal-closed` published under the old namespace no longer matches the bound
   * screen's scope, so the open it would have ended would hold until it expired.
   *
   * **A read still out is one of those answers too**, so `issued` moves here and not only in
   * `tick()`. Clearing the store and leaving the flight alone would have the old namespace's rows
   * land in the cleared store seconds later under a fresh stamp -- and a fault from that read
   * suspend the new namespace's timer -- which is the AD-44 switch undone by the read it was
   * meant to supersede.
   *
   * The new namespace is then read at once, whatever the rate: a screen whose rate is off would
   * otherwise stay empty until the user left and returned.
   *
   * `src/main.ts` calls this from the one `onScopeChange` handler, beside the map re-read --
   * `scope.ts` names this framework as that channel's second subscriber.
   */
  noteScopeChanged(): void {
    const bound = this.bound;
    if (bound === null) return;
    this.issued += 1;
    this.liveProposals.clear();
    this.lastFault = null;
    this.loadedOnce = false;
    bound.store.clearAnswers();
    this.transition();
    this.notify();
    void this.readNow();
  }

  /**
   * Run the bound read now, whatever the rate, under the guard a tick runs under: a read a later
   * one overtook, or one the scope moved under, writes nothing.
   *
   * A success applies the rows, lifts a fault suspension and re-arms through `canArm()`. A fault
   * suspends and parks exactly as a tick's does, and is never retried here (AD-8).
   */
  async readNow(): Promise<void> {
    const bound = this.bound;
    if (bound === null || bound.read === null) return;
    const issue = (this.issued += 1);

    let result: RefreshReadResult | null = null;
    try {
      result = await bound.read({ maxRows: bound.store.maxRows() });
    } catch {
      result = null;
    }

    if (this.bound !== bound) return;
    if (issue !== this.issued) return;

    if (result === null || result.kind === 'fault') {
      this.lastFault = result === null ? null : result.fault;
      this.suspend();
      return;
    }

    this.lastFault = null;
    this.loadedOnce = true;
    this.suspended = false;
    bound.store.applyTick(result.rows, result.truncated, result.banner ?? '', this.now());
    this.transition();
    this.notify();
  }

  /** Set the rate, and re-arm. Refused, changing nothing, for a rate the descriptor forbids. */
  setRate(seconds: number): boolean {
    const bound = this.bound;
    if (bound === null) return false;
    this.settingRate = true;
    let accepted = false;
    try {
      accepted = bound.store.setRate(seconds);
    } finally {
      this.settingRate = false;
    }
    if (!accepted) return false;
    this.transition();
    this.notify();
    return true;
  }

  // --- The timer --------------------------------------------------------------------------------

  /**
   * Whether the one timer may hold a tick arm right now, recomputed from all three conditions.
   *
   * Not cached, and not a flag: see the module header. The order is deliberate only in being
   * total -- each condition suspends on its own, and none of them clears another.
   */
  private canArm(): boolean {
    const bound = this.bound;
    if (bound === null || !bound.refreshes || bound.read === null) return false;
    if (this.suspended) return false;
    if (this.liveProposals.size > 0) return false;
    return bound.store.rate() > RATE_OFF;
  }

  /**
   * Every state change lands here: bump the generation, so whatever was armed is inert, then arm
   * whatever the new state calls for. Exactly one of three outcomes, which is what "exactly one
   * pending arm" means mechanically.
   */
  private transition(): void {
    this.generation += 1;
    this.arm = 'none';
    this.armedRate = this.rate();
    this.sweepExpired();
    const generation = this.generation;

    if (this.canArm()) {
      this.arm = 'tick';
      this.schedule(() => {
        if (generation !== this.generation) return;
        this.arm = 'none';
        void this.tick(generation);
      }, this.rate() * 1000);
      return;
    }

    // Paused by a live proposal: the one arm serves the pause's own deadline instead of the rate,
    // so an unclosed proposal cannot strand the screen. Nothing is armed for the other two
    // suspensions -- off has no deadline, and a fault's only triggers are the connectivity park
    // (banner kinds) and `readNow()`, deliberately.
    const earliest = this.earliestExpiry();
    if (earliest === null || this.suspended || this.rate() === RATE_OFF) return;
    this.arm = 'expiry';
    this.schedule(
      () => {
        if (generation !== this.generation) return;
        this.arm = 'none';
        this.transition();
        this.notify();
      },
      Math.max(0, earliest - this.now().getTime())
    );
  }

  private earliestExpiry(): number | null {
    let earliest: number | null = null;
    for (const expiresAt of this.liveProposals.values()) {
      if (earliest === null || expiresAt < earliest) earliest = expiresAt;
    }
    return earliest;
  }

  /** Drop every proposal whose expiry has passed (AD-6, AD-34, AD-40 are all the same close here). */
  private sweepExpired(): void {
    const nowMs = this.now().getTime();
    for (const [id, expiresAt] of [...this.liveProposals]) {
      if (expiresAt <= nowMs) this.liveProposals.delete(id);
    }
  }

  /**
   * One tick: call the screen's read with the store's cap, record what came back, re-arm.
   *
   * The three ways this ends are each a matrix row. A fault suspends and parks. A read that lands
   * after a transition still updates the store -- the data is good, and throwing it away would
   * make a `proposal-open` arriving mid-flight lose a read the user already paid for -- but the
   * re-arm belongs to the transition, not to this. Otherwise: store, notify, re-arm.
   *
   * **Only the newest read may write.** A transition mid-flight re-arms immediately, so a read
   * that outlives one interval is still out when the next one is issued; whichever answers last
   * would otherwise win, and `applyTick` stamps the moment it *applies*. An older read landing
   * second would put the earlier rows under the later `Last update` -- a stamp claiming a
   * freshness the rows do not have, which is the one thing the stamp must never do.
   *
   * **A read that throws is a read that failed.** `RefreshRead` is a type, not an enforcement, so
   * a broken read rejects rather than answering; left unguarded that is an unhandled rejection
   * with the timer stopped, nothing parked and no trigger left. It takes the failure path
   * instead, carrying no `Fault` -- classification is Story 1.13's and this module does none.
   */
  private async tick(generation: number): Promise<void> {
    const bound = this.bound;
    if (bound === null || bound.read === null) return;
    const issue = (this.issued += 1);

    let result: RefreshReadResult | null = null;
    try {
      result = await bound.read({ maxRows: bound.store.maxRows() });
    } catch {
      result = null;
    }

    // The screen moved under the read: its rows belong to a store this one is not.
    if (this.bound !== bound) return;
    // Superseded while it was out: a later read was issued, or the scope moved under this one.
    if (issue !== this.issued) return;

    if (result === null || result.kind === 'fault') {
      this.lastFault = result === null ? null : result.fault;
      this.suspend();
      return;
    }

    this.lastFault = null;
    this.loadedOnce = true;
    bound.store.applyTick(result.rows, result.truncated, result.banner ?? '', this.now());
    this.notify();
    if (generation !== this.generation) return;
    this.transition();
  }

  /**
   * The read failed: stop the timer and park the one re-arm the instance's next answer will run.
   *
   * The transition is one like any other, so the generation moves and nothing armed under the old
   * one can fire. It arms nothing, because `canArm()` reads the suspension -- which is what leaves
   * the park (for a banner kind) and `readNow()` as the only triggers.
   */
  private suspend(): void {
    this.suspended = true;
    const bound = this.bound;
    const issue = this.issued;
    this.connectivity.retryWhenReachable(REFRESH_PARK_KEY, () => this.resume(bound, issue));
    this.transition();
    this.notify();
  }

  /**
   * The instance answered again: lift a banner fault's suspension and let `canArm()` decide the
   * rest. It does not resume anything a proposal or an off rate is holding, which is the whole
   * reason resume is a predicate. A suspension under any other fault kind stays until a read
   * succeeds (AD-8).
   *
   * A park made before a later bind or a later read is stale: that read settles the state itself,
   * and resuming would issue a second one that overtakes it. A screen that has not loaded, or that
   * no tick will re-read (its rate off, or it does not refresh), reads now unless a proposal holds
   * it, so the instance coming back does not leave the failed read's answer missing.
   */
  private resume(bound: Bound | null, issue: number): void {
    if (this.bound !== bound || this.issued !== issue) return;
    if (this.lastFault !== null && !isBannerFault(this.lastFault)) return;
    this.suspended = false;
    this.transition();
    this.notify();
    if (!this.loadedOnce || (this.arm === 'none' && !this.paused())) void this.readNow();
  }

  /**
   * The bound store notified. Only a rate it moved on its own matters here -- the remembered rate
   * the instance answered after the bind (`ScreenStore.adoptRemembered`) -- and that re-arms, so
   * the timer and the chip follow the adopted rate rather than the default the bind armed for. A
   * tick's own write, and `setRate`, which transitions itself, change nothing here.
   */
  private onStoreChanged(store: ScreenStore): void {
    if (this.settingRate || this.bound?.store !== store) return;
    if (store.rate() === this.armedRate) return;
    this.transition();
    this.notify();
  }

  // --- The bus ----------------------------------------------------------------------------------

  /**
   * One event, filtered by `screenShowsEntity` -- the one predicate that answers "does the bound
   * screen show this entity" (AD-13, AD-14). The toast store asks the same question, so a change
   * either highlights a row here or raises a toast there, never both and never neither.
   *
   * **A `changed` event re-fetches, never patches** (AD-14): the entity's id is marked changed in
   * the store and the bound read runs once, through `readNow()`, which is the one re-fetch.
   */
  private onBusEvent(event: ChangeEvent): void {
    const bound = this.bound;
    if (bound === null) return;
    if (!screenShowsEntity(bound.screen, event, this.namespace())) return;

    if (event.kind === 'changed') {
      bound.store.markChanged(event.id, event.action, event.readBack ?? null);
      // AD-14's action, and the one thing it decides here: a row that did not exist before is
      // selected as soon as the re-fetch returns it, because it is the one row the user has not
      // seen. An update leaves the caret where the user put it; a delete is `reconcile`'s, which
      // clears a selection whose key has left the view.
      if (event.action === 'created') bound.store.setPendingSelection(event.id);
      void this.readNow();
      return;
    }
    if (event.kind === 'proposal-open') {
      this.liveProposals.set(event.proposalId, event.expiresAt);
    } else if (event.kind === 'proposal-closed') {
      // A close for an id never opened ends nothing: the set is what the pause is held by, and
      // deleting a key that is not there would be indistinguishable from closing the last one.
      if (!this.liveProposals.has(event.proposalId)) return;
      this.liveProposals.delete(event.proposalId);
    } else {
      // Named rather than assumed. A kind added to the bus later would otherwise fall into the
      // close branch and end a pause it was never about -- the shape Story 1.13 met three times.
      return;
    }
    this.transition();
    this.notify();
  }

  private notify(): void {
    for (const listener of this.listeners) listener();
  }
}
