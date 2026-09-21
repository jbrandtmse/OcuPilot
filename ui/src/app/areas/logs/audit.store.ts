import { Injectable, Injector, inject } from '@angular/core';

import { ApiService } from '../../core/api';
import { RefreshService, type RefreshRead } from '../../core/refresh';
import { createScreenRead, criteriaParams, type ScreenReadCriteria } from '../../core/screen-read';
import type { ScreenDeclaration } from '../../core/screens.generated';

/**
 * The name the screen mirror gives this screen's one flag criterion, which is the name an agent
 * navigation may carry (`OcuPilot.Screen.Descriptor.Base.FlagCriteria`, Story 5.8). It is the
 * mirror's own key for `ReadCriteriaMarker`, and the only flag `ReadCriteria` can structurally
 * hold -- a second one would be a type change here as well as a descriptor change.
 */
export const MARKER_CRITERION = 'marker';

/**
 * The descriptor this store holds the state of. `openWith` checks the declaration it is handed
 * against it, because the shell reaches an area store by injecting it concretely
 * (`shell/agent-navigator.ts`) and so hands this store whichever screen the navigation arrived at.
 * Today `AuditList` is the only descriptor declaring a flag criterion, so no other declaration can
 * get this far -- but `marker` is a field on the shared generated `ReadCriteria`, so a second
 * screen declaring one would otherwise have this store set its own filter and bind that other
 * screen's declaration into the refresh framework through `readFor`.
 */
export const AUDIT_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.AuditList';

/**
 * The audit database viewer's own state: what the criteria form holds, whether the agent-marker
 * filter is on, and whether Search has been pressed at all (AD-19).
 *
 * **It is root-provided rather than component-local, and that is load-bearing.** The screen's row
 * detail opens on its own `/:id` route (AD-13), which is a different route config from the bare
 * route -- so Angular destroys and re-creates the page around every dialog open and close. State in
 * a component field would mean the criteria the user typed, and the fact that they had searched at
 * all, were lost the moment they opened a row. The rows themselves already survive, in the
 * descriptor-keyed `ScreenStore`; this is the rest of the screen's state, kept the same way and for
 * the same reason.
 *
 * It also owns the screen's bound `RefreshRead`, for a second consequence of the same fact: the
 * refresh framework treats a re-bind with a *different* read as a new binding and clears
 * `hasLoaded`, which would show a skeleton in place of the rows the user just searched for. Handing
 * back the same closure every time makes the page's re-bind a no-op.
 */
@Injectable({ providedIn: 'root' })
export class AuditSearch {
  /**
   * The API service is resolved when the first read is built, not when this service is constructed.
   * `App` holds this store so the sign-out teardown can drop it, and constructing the shell must not
   * drag a leaf screen's data dependency in behind it.
   */
  private readonly injector = inject(Injector);

  private values: Record<string, string> = {};

  private markerOn = false;

  private searchedOnce = false;

  /**
   * Bumped whenever a page instance is created, so a destroyed instance can tell "the user left
   * this screen" from "another instance of this screen took over".
   */
  private pageGeneration = 0;

  private readonly reads = new Map<string, RefreshRead>();

  /** Set when a closing dialog asks the next page instance to put focus back on the grid. */
  private gridFocusWanted = false;

  private readonly listeners = new Set<() => void>();

  /**
   * Forget everything this principal had, from the same sign-out teardown as `refresh.reset()`.
   *
   * What it holds is this principal's own search -- the event names, usernames, process ids and
   * namespaces they typed, and whether they had searched at all. Without this, the next principal
   * to sign in in the same tab inherits the form's contents and an already-searched screen, and the
   * "renders nothing until Search" rule the archetype exists for would hold only for the first
   * sign-in of a tab.
   */
  reset(): void {
    this.values = {};
    this.markerOn = false;
    this.searchedOnce = false;
    this.gridFocusWanted = false;
    this.reads.clear();
    this.notify();
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** What the form holds for `param`, or `''`. */
  value(param: string): string {
    return this.values[param] ?? '';
  }

  setValue(param: string, value: string): void {
    this.values = { ...this.values, [param]: value };
    this.notify();
  }

  /** Whether the agent-marker filter is applied. Never the default (AD-46). */
  marker(): boolean {
    return this.markerOn;
  }

  setMarker(on: boolean): void {
    this.markerOn = on;
    this.notify();
  }

  /** Whether Search has been pressed since this tab opened the screen. */
  searched(): boolean {
    return this.searchedOnce;
  }

  noteSearched(): void {
    this.searchedOnce = true;
    this.notify();
  }

  /** A page instance's own generation, taken in its constructor. */
  takeGeneration(): number {
    this.pageGeneration += 1;
    return this.pageGeneration;
  }

  /** Whether `generation` is still the newest page instance's. */
  isCurrentGeneration(generation: number): boolean {
    return this.pageGeneration === generation;
  }

  /**
   * Ask the page instance the next navigation creates to put focus back on the grid.
   *
   * The dialog's own opener does not survive that navigation -- the route change destroys the
   * table it was in -- so "focus returns to the opener" is carried across the gap here rather than
   * by holding a reference to an element that is about to be removed.
   */
  requestGridFocus(): void {
    this.gridFocusWanted = true;
  }

  /** Whether a grid focus was asked for, clearing the request either way. */
  takeGridFocusRequest(): boolean {
    const wanted = this.gridFocusWanted;
    this.gridFocusWanted = false;
    return wanted;
  }

  /**
   * What the read sends: every declared criterion the form holds a value for, with the marker's
   * own criterion **overridden** when the filter is on (AD-46).
   *
   * Overridden, never merged. The marker and the Event source criterion name the same query
   * parameter, and the vendor matches a comma list by membership -- so appending the marker's value
   * to whatever the user typed would *widen* the result, which is the opposite of what the filter
   * is for. While the marker is on, the criterion it names is not sent at all and the field that
   * carries it renders unavailable; turning the filter off restores both.
   */
  criteria(declaration: ScreenDeclaration): ScreenReadCriteria {
    const marker = declaration.read?.criteria?.marker ?? null;
    const sent: Record<string, string> = {};
    for (const param of criteriaParams(declaration)) {
      sent[param] = this.value(param);
    }
    if (this.markerOn && marker !== null) sent[marker.param] = marker.value;
    return sent;
  }

  /** Whether `param`'s control is unavailable because the marker filter has taken it over. */
  overriddenByMarker(declaration: ScreenDeclaration, param: string): boolean {
    const marker = declaration.read?.criteria?.marker ?? null;
    return this.markerOn && marker !== null && marker.param === param;
  }

  /**
   * The one `RefreshRead` for `declaration`, created on first ask and handed back unchanged
   * afterwards. It reads `criteria()` at call time, so Search sends what the form holds now.
   */
  readFor(declaration: ScreenDeclaration): RefreshRead {
    const held = this.reads.get(declaration.descriptor);
    if (held !== undefined) return held;
    const read = createScreenRead(this.injector.get(ApiService), declaration, () =>
      this.criteria(declaration)
    );
    this.reads.set(declaration.descriptor, read);
    return read;
  }

  /**
   * Arrive on this screen with `criterion` applied, and run the screen's declared read (Story 5.8,
   * AD-21): the non-interactive path beside the checkbox's and Search's, so "is the marker on" and
   * "has this screen searched" have one answer and not two.
   *
   * **It names a criterion; it is never given a value.** `criterion` is the name the arriving
   * descriptor declares -- the instance refused anything else before the navigation was announced
   * (`NAV.CRITERIONUNKNOWN`) -- and the value that reaches the read is `criteria()`'s reading of
   * the declaration. A name the declaration does not carry applies nothing and searches nothing,
   * because there is no filter to arrive with.
   *
   * **The form is cleared, so the arrival runs the screen's declared read and not the user's last
   * one.** This store is root-provided and outlives every visit to the screen, so whatever the
   * user last typed into the criteria form is still held here -- and `criteria()` sends every
   * declared criterion the form holds a value for. An arrival that kept them would run the
   * marker filter narrowed by a username or a pid the user typed some visits ago, which is how a
   * hand-off that found the right row for the agent finds none for the user.
   *
   * **It binds and reads rather than leaving that to the page.** The archetype renders nothing
   * until Search has run, and the page instance the router is about to create binds only when
   * Search is pressed -- so a navigation that set the flag and stopped there would land on an
   * unsearched form with a ticked checkbox. Binding is idempotent: `readFor` hands back the same
   * closure every time, which is what makes the page's own re-bind a no-op.
   *
   * **It applies nothing to a screen that is not this one.** `declaration` is whatever screen the
   * navigation arrived at, so the descriptor is checked as well as the criterion name: this store
   * owns one screen's filter and one screen's bound read, and setting either from another screen's
   * declaration would filter a screen nobody asked about (see `AUDIT_DESCRIPTOR`).
   */
  openWith(declaration: ScreenDeclaration, criterion: string): void {
    if (declaration.descriptor !== AUDIT_DESCRIPTOR) return;
    const marker = declaration.read?.criteria?.marker ?? null;
    if (marker === null || criterion !== MARKER_CRITERION) return;
    this.values = {};
    this.markerOn = true;
    this.searchedOnce = true;
    this.notify();
    const refresh = this.injector.get(RefreshService);
    refresh.bind(declaration, this.readFor(declaration));
    void refresh.readNow();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
