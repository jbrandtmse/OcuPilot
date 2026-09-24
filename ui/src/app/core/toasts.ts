/**
 * The off-screen change toast (AD-14, AD-11, AD-39).
 *
 * A confirmed write publishes one `changed` event on the one bus. When the user is looking at the
 * entity's own list, the row highlight is the confirmation and nothing else is raised. Anywhere
 * else -- a details or an editor screen of that entity included -- this store raises a toast naming
 * it, with "Open in <list>", which opens the list with the entity selected (DW-1546, PRD UJ-6).
 *
 * **It never renders a fault.** A read fault, a 403 and a refused confirm are banners
 * (AD-12/AD-39, DESIGN.md's toast recipe says so in as many words), and this store subscribes to
 * the bus alone, which carries no fault -- so there is no branch that could raise one.
 *
 * **The toast is hidden only while its own target is open.** The target is `screenForChange`'s --
 * the entity's list -- and the scope half is `screenShowsEntity`'s, the predicate `RefreshService`
 * filters on, so the list that re-fetches and highlights the row is the one screen that raises
 * nothing. The open screen is resolved from the router URL rather than from the refresh service's
 * bound screen: a screen that declares no auto-refresh still shows entities, and `RefreshService`
 * does not expose what it is bound to.
 *
 * **The timers pause together.** Hovering or focusing anywhere in the stack holds every
 * countdown, because a toast being read must not expire under the reader (EXPERIENCE.md's
 * accessibility floor on time limits). Release shifts every deadline forward by exactly as long
 * as the hold lasted, so the remaining time is the remaining time.
 *
 * Framework-free like the rest of `core/` (AD-19), so `ui/tools/toasts.test.mjs` drives it under
 * `node --test` with its own clock and its own timer seam.
 */

import type { ChangeAction, ChangeBus, ChangeEvent } from './change-bus';
import {
  ACTION_PLACEHOLDER,
  ENTITY_PLACEHOLDER,
  SCREEN_PLACEHOLDER,
  screenForChange,
  screenForUrl,
  screenShowsEntity,
} from './navigation.ts';
import { displayEntityId } from './entity-id.ts';
import type { ScreenDeclaration } from './screens.generated.ts';
import { STRINGS, stringFor } from './strings.ts';

/**
 * What can hold the countdowns. Two independent sources, named rather than counted, because they
 * differ in one way that matters: a `pointerleave` is always owed, while a `focusout` is not owed
 * for an element removed while it held focus -- which is the feature's own primary path, since
 * acting on a toast focuses its control and then dismisses it.
 */
export type ToastHoldSource = 'pointer' | 'focus';

/** DESIGN.md's `max-stack: 3`. A fourth toast drops the oldest rather than growing the column. */
export const TOAST_STACK_MAX = 3;

/** How long a toast with nothing to open lives: there is nothing to act on, so it says its piece. */
export const TOAST_LIFETIME_MS = 10_000;

/** How long a toast carrying an action lives, since acting on it takes longer than reading it. */
export const TOAST_LIFETIME_WITH_ACTION_MS = 30_000;

/** One raised toast. Data only -- a toast renders text and issues no request (AD-11). */
export interface ToastEntry {
  /** This toast's own id, unique within the session; not the entity's. */
  readonly id: string;
  readonly action: ChangeAction;
  readonly entityType: string;
  /** The singular noun the target screen's descriptor publishes, or `''` when none does. */
  readonly entityLabel: string;
  readonly entityId: string;
  /** The route "Open in <screen>" opens, or `''` when no built screen shows this entity type. */
  readonly route: string;
  /** When it leaves, in epoch milliseconds. Shifted forward while the stack is held. */
  readonly expiresAt: number;
}

export interface ToastStoreOptions {
  /** Injected so a test drives expiry without waiting on a clock. Defaults to `Date.now`. */
  readonly now?: () => number;
  /** Arms one sweep and answers with its cancel. Defaults to `setTimeout`/`clearTimeout`. */
  readonly schedule?: (run: () => void, delayMs: number) => () => void;
  /** The router URL the shell is standing on, read on every event. */
  readonly currentUrl?: () => string;
  /** The namespace the shell is scoped to, which is the scope half of every key (AD-44). */
  readonly namespace?: () => string;
}

/** The published sentence for one action. */
export function changeSentenceTemplate(action: ChangeAction): string {
  if (action === 'created') return STRINGS.tableChangeCreated;
  if (action === 'deleted') return STRINGS.tableChangeDeleted;
  return STRINGS.tableChangeUpdated;
}

/**
 * `<entity> was updated` resolved to the entity the change was about. A function for the reason
 * `formatArea` is one: renaming the placeholder on one side only would ship the placeholder to
 * the user, and a source-text pin cannot see that. A composite id reads through
 * `displayEntityId`, so no control character reaches the sentence.
 */
export function formatChangeSentence(template: string, entity: string): string {
  return template.split(ENTITY_PLACEHOLDER).join(displayEntityId(entity));
}

/** `Open in <screen>` resolved to the screen the action opens. */
export function formatChangeToastLink(template: string, screenTitle: string): string {
  return template.split(SCREEN_PLACEHOLDER).join(screenTitle);
}

/**
 * `Updated: <entity> <action>` resolved to the changed row's id and AD-14's own action word.
 *
 * The action word is machine vocabulary rendered as reported, not translated copy -- the same
 * treatment the System usage meters give the vendor's own state words.
 */
export function formatChangeAnnouncement(template: string, entity: string, action: string): string {
  return template.split(ENTITY_PLACEHOLDER).join(entity).split(ACTION_PLACEHOLDER).join(action);
}

export class ToastStore {
  private readonly nowMs: () => number;
  private readonly scheduleSweep: (run: () => void, delayMs: number) => () => void;
  private readonly currentUrl: () => string;
  private readonly namespace: () => string;

  /** Newest first, at most `TOAST_STACK_MAX`. */
  private entries: readonly ToastEntry[] = [];

  /** Which sources are holding the stack; empty means the clocks run. */
  private readonly heldBy = new Set<ToastHoldSource>();

  /** When the current hold started, so release shifts every deadline by exactly that long. */
  private heldSince = 0;

  private cancelSweep: (() => void) | null = null;

  private minted = 0;

  private readonly listeners = new Set<() => void>();

  constructor(options: ToastStoreOptions = {}) {
    this.nowMs = options.now ?? (() => Date.now());
    this.scheduleSweep =
      options.schedule ??
      ((run, delayMs) => {
        const handle = setTimeout(run, delayMs);
        return () => clearTimeout(handle);
      });
    this.currentUrl = options.currentUrl ?? (() => '');
    this.namespace = options.namespace ?? (() => '');
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** The stack, newest first. */
  toasts(): readonly ToastEntry[] {
    return this.entries;
  }

  /** Whether a pointer or focus is holding the countdowns. */
  holding(): boolean {
    return this.heldBy.size > 0;
  }

  /** Drop the armed sweep. A host calls it on destroy so no timer outlives the region. */
  dispose(): void {
    this.cancelSweep?.();
    this.cancelSweep = null;
    this.listeners.clear();
  }

  /**
   * Listen to `bus` and raise a toast for every `changed` event the open screen does not show.
   * Answers with the unsubscribe, so a host releases it on destroy.
   */
  attach(bus: ChangeBus): () => void {
    return bus.subscribe((event) => {
      this.publish(event);
    });
  }

  /**
   * Raise a toast for `event`, and report whether one was raised.
   *
   * Three events raise nothing, and each is a rule rather than a guard: a kind that is not
   * `changed` (a proposal opening is the auto-refresh pause's business, not the user's), a change
   * the open screen already shows (the row highlight is the confirmation), and an event whose
   * action is not one of AD-14's -- which `ChangeBus.publish` already refuses, so nothing on the
   * bus can carry one.
   */
  publish(event: ChangeEvent): boolean {
    if (event.kind !== 'changed') return false;
    if (event.action === '') return false;
    const target = screenForChange(event);
    if (target !== null && this.targetIsOpen(target.screen, event)) return false;

    const lifetime = target === null ? TOAST_LIFETIME_MS : TOAST_LIFETIME_WITH_ACTION_MS;
    this.minted += 1;
    const entry: ToastEntry = {
      id: `toast-${this.minted}`,
      action: event.action,
      entityType: event.type,
      entityLabel: target === null ? '' : stringFor(target.screen.entityLabelKey),
      entityId: event.id,
      route: target === null ? '' : target.route,
      expiresAt: this.nowMs() + lifetime,
    };
    // Newest on top, oldest dropped -- a column that grew would cover the screen it is reporting on.
    this.entries = [entry, ...this.entries].slice(0, TOAST_STACK_MAX);
    this.arm();
    this.notify();
    return true;
  }

  /**
   * Drop one toast. The others keep the time they had left.
   *
   * **A dismissed toast takes the focus hold with it.** A browser does not reliably fire
   * `focusout` for an element removed while it holds focus, and the control that was clicked is
   * inside the toast being removed -- so the focus hold it took is owed a release nobody will
   * send. Left standing it would stop this stack, and every later one, from ever expiring. The
   * pointer hold is untouched: the region is still under the pointer and its `pointerleave` is
   * still owed. An emptied stack forgets both, because the region unmounts with its last entry.
   */
  dismiss(id: string): void {
    const next = this.entries.filter((entry) => entry.id !== id);
    if (next.length === this.entries.length) return;
    this.entries = next;
    if (next.length === 0) {
      this.heldBy.clear();
    } else {
      this.letGo('focus');
    }
    this.arm();
    this.notify();
  }

  /**
   * Hold every countdown: a pointer entered the stack, or focus did.
   *
   * Held by source rather than by a count, because pointer and focus are two independent sources
   * -- a `pointerleave` while the dismiss control still holds focus must not start the clocks
   * again -- and because `dismiss` has to let go of exactly one of them.
   */
  holdTimers(source: ToastHoldSource = 'pointer'): void {
    if (this.heldBy.has(source)) return;
    this.heldBy.add(source);
    if (this.heldBy.size > 1) return;
    this.heldSince = this.nowMs();
    this.cancelSweep?.();
    this.cancelSweep = null;
    this.notify();
  }

  /** Let the countdowns run again, every deadline moved forward by however long the hold lasted. */
  releaseTimers(source: ToastHoldSource = 'pointer'): void {
    if (!this.letGo(source)) return;
    this.arm();
    this.notify();
  }

  /**
   * Forget `source`'s hold, shifting every deadline forward by the whole hold when it was the
   * last one. Answers whether anything changed, so a caller knows whether to re-arm and notify.
   */
  private letGo(source: ToastHoldSource): boolean {
    if (!this.heldBy.has(source)) return false;
    this.heldBy.delete(source);
    if (this.heldBy.size > 0) return true;
    const held = this.nowMs() - this.heldSince;
    if (held > 0) {
      this.entries = this.entries.map((entry) => ({ ...entry, expiresAt: entry.expiresAt + held }));
    }
    return true;
  }

  /**
   * Whether the screen the shell is standing on is `target`, the screen this change's toast would
   * open, showing the entity in `event`'s scope.
   *
   * Resolved with `screenForUrl`, which is the repository's answer to "what is open": a list opened
   * on an entity is `<list route>/<encoded id>` and declares no route of its own, so an exact
   * route-table match answers `null` on every id route and the suppression would fail exactly where
   * the toast's own action lands the user. It resolves built screens only, so there is no second
   * gate here.
   */
  private targetIsOpen(target: ScreenDeclaration, event: ChangeEvent): boolean {
    const screen = screenForUrl(this.currentUrl());
    if (screen === null || screen.descriptor !== target.descriptor) return false;
    return screenShowsEntity(screen, event, this.namespace());
  }

  /**
   * Arm one sweep for the nearest deadline, or none while the stack is held or empty.
   *
   * One timer, never one per toast: several timers over one list is how a dismissed toast's own
   * callback ends up removing the entry that took its place.
   */
  private arm(): void {
    this.cancelSweep?.();
    this.cancelSweep = null;
    if (this.heldBy.size > 0 || this.entries.length === 0) return;
    const now = this.nowMs();
    const soonest = Math.min(...this.entries.map((entry) => entry.expiresAt));
    this.cancelSweep = this.scheduleSweep(() => this.sweep(), Math.max(0, soonest - now));
  }

  /** Drop every toast whose deadline has passed, then re-arm for whatever is left. */
  private sweep(): void {
    this.cancelSweep = null;
    if (this.heldBy.size > 0) return;
    const now = this.nowMs();
    const next = this.entries.filter((entry) => entry.expiresAt > now);
    const changed = next.length !== this.entries.length;
    this.entries = next;
    this.arm();
    if (changed) this.notify();
  }

  private notify(): void {
    for (const listener of this.listeners) listener();
  }
}
