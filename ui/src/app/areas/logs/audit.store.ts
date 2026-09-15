import { Injectable, Injector, inject } from '@angular/core';

import { ApiService } from '../../core/api';
import type { RefreshRead } from '../../core/refresh';
import { createScreenRead, criteriaParams, type ScreenReadCriteria } from '../../core/screen-read';
import type { ScreenDeclaration } from '../../core/screens.generated';

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

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
