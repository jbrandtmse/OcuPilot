import { Injectable, Injector, inject } from '@angular/core';

import { ApiService } from '../../core/api';
import type { RefreshRead } from '../../core/refresh';
import type { ScreenArrival } from '../../core/screen-arrival';
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
 * What the next read sends (Story 11.11): the screen's default (nothing, so the instance applies
 * each declared default), the form as shown, or an agent arrival's criteria exactly.
 */
type RequestMode = 'default' | 'form' | 'arrival';

/**
 * The audit database viewer's own state: what the criteria form holds, whether the agent-marker
 * filter is on, whether Search has been pressed, and what the next read sends (AD-19).
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
 *
 * **The form shows the values the read applied** (AD-36). A read leaves some criteria absent -- all
 * of them on open -- and the instance applies their declared defaults; `applyEcho` fills each
 * absent field from the answer's `criteria`, so the begin field reads the instance's own now less
 * 24 hours rather than a time the browser computed.
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

  private mode: RequestMode = 'default';

  /** What an arrival sends, exactly, while `mode` is `arrival`. */
  private arrivalSent: Record<string, string> = {};

  /** The fields the person changed since the screen last chose what to send; an echo leaves them. */
  private readonly edited = new Set<string>();

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
   * to sign in in the same tab inherits the form's contents and has their search re-run on their
   * first visit instead of the screen's default.
   */
  reset(): void {
    this.values = {};
    this.markerOn = false;
    this.searchedOnce = false;
    this.mode = 'default';
    this.arrivalSent = {};
    this.edited.clear();
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
    this.edited.add(param);
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
   * Open on the screen's default read: nothing is sent, so the instance applies each declared
   * default, and the marker is off -- an affordance, never a default (AD-46). Every field is then
   * filled from the answer (`applyEcho`).
   */
  useDefault(): void {
    this.mode = 'default';
    this.markerOn = false;
    this.values = {};
    this.edited.clear();
    this.notify();
  }

  /** Send the form as shown from the next read on: Search, and a return after one. */
  useForm(): void {
    this.mode = 'form';
    this.edited.clear();
    this.notify();
  }

  /**
   * Run an agent arrival's search, exactly (Story 11.11, AD-11): the criteria it carries and nothing
   * else, so a criterion it omits takes its default as the agent's own read did. The form shows those
   * values, and the fields the arrival left absent are filled from the answer.
   *
   * **The marker reads ticked when the search is the marker's.** A flag criterion naming it, or an
   * `eventSources` equal to the marker's value, sends the identical read; showing it as the ticked
   * affordance with the field empty is what tells the person the rows are the agent-marked events.
   * The flag overrides its own parameter, as the checkbox does.
   */
  useArrival(declaration: ScreenDeclaration, arrival: ScreenArrival): void {
    const marker = declaration.read?.criteria?.marker ?? null;
    const sent: Record<string, string> = {};
    for (const param of criteriaParams(declaration)) {
      const value = arrival.criteria[param];
      if (typeof value === 'string') sent[param] = value;
    }
    const markerOn =
      marker !== null && (arrival.criterion === MARKER_CRITERION || sent[marker.param] === marker.value);
    if (markerOn && marker !== null) sent[marker.param] = marker.value;
    this.values = { ...sent };
    if (markerOn && marker !== null) this.values[marker.param] = '';
    this.markerOn = markerOn;
    this.arrivalSent = sent;
    this.edited.clear();
    this.mode = 'arrival';
    this.notify();
  }

  /**
   * What the next read sends, read at call time: nothing on the default read, an arrival's criteria
   * exactly, or the form as shown -- every declared criterion, an emptied field sent empty so the
   * bound is unset, with the marker's own criterion **overridden** when the filter is on (AD-46).
   *
   * Overridden, never merged. The marker and the Event source criterion name the same query
   * parameter, and the vendor matches a comma list by membership -- so appending the marker's value
   * to whatever the user typed would *widen* the result, which is the opposite of what the filter
   * is for. While the marker is on, the criterion it names is not sent from the form at all and the
   * field that carries it renders unavailable; turning the filter off restores both.
   */
  criteria(declaration: ScreenDeclaration): ScreenReadCriteria {
    if (this.mode === 'default') return {};
    if (this.mode === 'arrival') return { ...this.arrivalSent };
    const marker = declaration.read?.criteria?.marker ?? null;
    const sent: Record<string, string> = {};
    for (const param of criteriaParams(declaration)) {
      sent[param] = this.value(param);
    }
    if (this.markerOn && marker !== null) sent[marker.param] = marker.value;
    return sent;
  }

  /**
   * Fill each field the request `sent` left absent from the answer's `applied` criteria (AD-36), so
   * the form shows the values the instance used. A field the request carried keeps what it holds,
   * and so does one the person has typed into since, which is theirs until the next Search.
   */
  applyEcho(declaration: ScreenDeclaration, applied: Readonly<Record<string, string>>, sent: ScreenReadCriteria): void {
    // An answer to a request the screen has since replaced -- an arrival over an open read still
    // out -- is not the search the form now describes.
    if (JSON.stringify(sent) !== JSON.stringify(this.criteria(declaration))) return;
    let changed = false;
    const next = { ...this.values };
    for (const param of criteriaParams(declaration)) {
      if (sent[param] !== undefined || this.edited.has(param)) continue;
      next[param] = applied[param] ?? '';
      changed = true;
    }
    if (!changed) return;
    this.values = next;
    this.notify();
  }

  /** Whether `param`'s control is unavailable because the marker filter has taken it over. */
  overriddenByMarker(declaration: ScreenDeclaration, param: string): boolean {
    const marker = declaration.read?.criteria?.marker ?? null;
    return this.markerOn && marker !== null && marker.param === param;
  }

  /**
   * The one `RefreshRead` for `declaration`, created on first ask and handed back unchanged
   * afterwards. It reads `criteria()` at call time, and hands each answer's applied criteria to
   * `applyEcho`.
   */
  readFor(declaration: ScreenDeclaration): RefreshRead {
    const held = this.reads.get(declaration.descriptor);
    if (held !== undefined) return held;
    const read = createScreenRead(
      this.injector.get(ApiService),
      declaration,
      () => this.criteria(declaration),
      (applied, sent) => this.applyEcho(declaration, applied, sent)
    );
    this.reads.set(declaration.descriptor, read);
    return read;
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
