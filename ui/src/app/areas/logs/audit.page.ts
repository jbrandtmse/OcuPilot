import { ChangeDetectionStrategy, Component, DestroyRef, afterNextRender, inject, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';

import { decodeEntityId } from '../../core/entity-id';
import { NavigationService, withQuery } from '../../core/navigation';
import { RefreshService } from '../../core/refresh';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { textOf } from '../../core/screen-read';
import { fieldOf, rowKey } from '../../core/table-model';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS, stringFor } from '../../core/strings';
import { COMMAND_BAR_FILTER_ID } from '../../shell/command-bar';
import { DataTable } from '../../shell/data-table';
import { Dialog } from '../../shell/dialog';
import { AuditSearch } from './audit.store';

/** One criterion's control, resolved for drawing. */
interface CriterionView {
  readonly param: string;
  readonly id: string;
  readonly label: string;
  readonly choice: boolean;
  readonly options: readonly string[];
  readonly value: string;
  readonly unavailable: boolean;
}

/** The row a dialog is open over. */
interface DetailView {
  readonly description: string;
  readonly eventData: string;
}

/** The screen this page renders and the store its table reads. */
interface AuditView {
  readonly screen: ScreenDeclaration;
  readonly store: ScreenStore;
}

/**
 * The page every `list (server criteria)` archetype renders: a criteria form above the table, the
 * table itself once Search has run, and the row detail dialog the `/:id` route opens (AD-5).
 *
 * **It renders nothing until Search is pressed** (EXPERIENCE.md "criteria form first, skeleton"). That is the archetype's
 * whole distinction from `list`: this screen's API searches on the server, so an automatic read on
 * navigation would be an unbounded search nobody asked for. The read is therefore not bound to the
 * refresh framework until the first Search -- `RefreshService.readNow()` with no bound read does
 * nothing, which is what keeps a namespace switch from issuing one either -- and the table is not
 * rendered before it, so there is no skeleton and no empty state to see.
 *
 * **Criteria travel on the declared read, never on the command bar** (AD-36). The form's values are
 * sent as the descriptor's own `read.criteria` parameters, so the read tool sends the same search;
 * the command bar's filter and sort keep their client-side meaning within the cap.
 *
 * **The marker filter overrides the criterion it names.** See `AuditSearch.criteria`, which is where
 * the override lives, and why merging would widen rather than narrow.
 *
 * **The detail dialog is the id route.** The Event name cell links to `<route>/<id>` like every
 * other name cell (`data-table.ts`); this page reads that segment, finds the row already fetched --
 * no second request, because the endpoint's own GET answers no key the LIST row lacks -- and
 * renders it. Closing returns to the bare route.
 */
@Component({
  selector: 'app-audit-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DataTable, Dialog],
  template: `<section class="ocu-list-page">
    @if (list; as view) {
      <form class="ocu-criteria-form" (submit)="onSearch($event)">
        <div class="ocu-criteria-fields">
          @for (field of criteria; track field.param) {
            <div class="ocu-criteria-field">
              <label class="ocu-criteria-label" [attr.for]="field.id">{{ field.label }}</label>
              @if (field.choice) {
                <select
                  class="ocu-criteria-select"
                  [id]="field.id"
                  [attr.aria-disabled]="field.unavailable ? 'true' : null"
                  [attr.aria-describedby]="field.unavailable ? markerLabelId : null"
                  [value]="field.value"
                  (change)="onCriterion(field.param, $event)"
                >
                  <option value="">{{ STRINGS.auditCriteriaAnyOption }}</option>
                  @for (option of field.options; track option) {
                    <option [value]="option" [selected]="option === field.value">{{ option }}</option>
                  }
                </select>
              } @else {
                <input
                  class="ocu-criteria-input"
                  type="text"
                  [id]="field.id"
                  [attr.aria-disabled]="field.unavailable ? 'true' : null"
                  [attr.aria-describedby]="field.unavailable ? markerLabelId : null"
                  [readonly]="field.unavailable"
                  [value]="field.value"
                  (input)="onCriterion(field.param, $event)"
                />
              }
            </div>
          }
        </div>
        <p class="ocu-criteria-hint">{{ STRINGS.auditCriteriaTimeHint }}</p>
        <p class="ocu-criteria-hint">{{ STRINGS.auditCriteriaNameHint }}</p>
        <div class="ocu-criteria-controls">
          <button type="submit" class="ocu-button-primary">{{ STRINGS.auditCriteriaSearch }}</button>
          <label class="ocu-criteria-marker" [id]="markerLabelId">
            <input
              type="checkbox"
              data-ocu-marker="filter"
              [checked]="markerOn"
              (change)="onMarker($event)"
            />
            {{ STRINGS.auditMarkerFilterLabel }}
          </label>
        </div>
      </form>
      @if (searched) {
        <app-data-table [screen]="view.screen" [store]="view.store" (focusFilter)="onFocusFilter()" />
      }
      @if (detail; as row) {
        <app-dialog
          [heading]="STRINGS.auditDialogTitle"
          [closeLabel]="STRINGS.auditDialogClose"
          (closed)="onCloseDetail()"
        >
          <p class="ocu-dialog-field">{{ STRINGS.tableColumnDescription }}</p>
          <p class="ocu-dialog-value">{{ row.description }}</p>
          <p class="ocu-dialog-field">{{ STRINGS.auditDialogEventData }}</p>
          <pre class="ocu-dialog-payload">{{ row.eventData }}</pre>
        </app-dialog>
      }
    }
  </section>`,
})
export class AuditPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);
  private readonly stores = inject(ScreenStores);
  private readonly refresh = inject(RefreshService);
  private readonly search = inject(AuditSearch);

  private readonly actions = inject(ScreenActions);

  protected readonly STRINGS = STRINGS;

  /**
   * The marker checkbox's own label, which is also the reason a criterion it overrides is
   * unavailable, so an overridden control describes itself with it rather than needing copy of its
   * own (EXPERIENCE.md Privilege Gating > Mechanism: `aria-disabled`, never the `disabled`
   * attribute, with the reason announced).
   */
  protected readonly markerLabelId = 'ocu-audit-marker-label';

  protected readonly list: AuditView | null;

  /** Bumped by the two stores, so the form and the table re-render under `OnPush`. */
  private readonly generation = signal(0);

  /** The id segment the route carries, decoded once (AD-13). */
  private readonly entityId = signal('');

  constructor() {
    const screen = this.navigation.screenForUrl(this.router.url);
    if (screen === null || screen.read === null || screen.table === null) {
      this.list = null;
      return;
    }
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    this.list = { screen, store };

    // Bind with no read until the first Search. `readNow()` answers nothing for a binding with a
    // null read, so neither the scope's first resolution nor a namespace switch can issue the
    // unbounded search this screen exists to avoid; the binding itself is still what gives the
    // table its `hasLoaded`, its fault and its max-rows re-read.
    this.refresh.bind(screen, this.search.searched() ? this.search.readFor(screen) : null);

    // Returning to this screen after a Search is a FULL re-bind, not the dialog's no-op one: the
    // descriptor in between was another screen's, so `bind` clears `hasLoaded` and the table would
    // render a skeleton that nothing ever resolves -- this archetype has no timer and no read on
    // navigation. The dialog round trip does not reach here, because `bind` returns early for the
    // same descriptor and the same closure, leaving `hasLoaded` true.
    if (this.search.searched() && !this.refresh.hasLoaded()) void this.refresh.readNow();

    // Manual Refresh (DW-260), and **not before the first Search**: this screen renders nothing
    // until one, and a Refresh with no search behind it would either issue the unbounded read the
    // whole archetype exists to avoid or do nothing at all. Registered and removed as the store's
    // own `searched` flag moves, so a sign-out reset takes the control away with the results.
    let stopRefreshAction: (() => void) | null = null;
    const syncRefreshAction = (): void => {
      const offered = this.search.searched();
      if (offered && stopRefreshAction === null) {
        stopRefreshAction = this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
          // The same search, re-run: `readFor` reads the criteria at call time, so Refresh re-runs
          // what is in the form now rather than a snapshot taken when it was registered.
          this.refresh.bind(screen, this.search.readFor(screen));
          void this.refresh.readNow();
        });
      } else if (!offered && stopRefreshAction !== null) {
        stopRefreshAction();
        stopRefreshAction = null;
      }
    };
    syncRefreshAction();

    const stopStore = store.subscribe(() => this.bump());
    const stopSearch = this.search.subscribe(() => {
      this.bump();
      syncRefreshAction();
    });
    const stopParams = this.route.paramMap.subscribe((params) => {
      const raw = params.get('id');
      this.entityId.set(raw === null ? '' : decodeEntityId(raw));
    });

    // The dialog's route is a second route config over the same screen, so Angular destroys this
    // component on every dialog open and close. Unbinding unconditionally would clear `hasLoaded`
    // and put a skeleton where the user's results were, so the unbind is conditional on the router
    // having actually left this screen. If the URL has not been updated yet at teardown the test
    // reads false and nothing is unbound, which is inert: the next screen's own `bind()` replaces
    // the binding, and this screen's timer never arms because it does not refresh.
    // The dialog's close asks for it, and the instance the router then creates is the one that can
    // give it: a one-shot, honoured after the table has rendered and cleared either way, so a later
    // arrival at this screen never has focus taken from wherever the user put it.
    afterNextRender(() => {
      if (!this.search.takeGridFocusRequest()) return;
      document.querySelector<HTMLElement>('[role="grid"]')?.focus();
    });

    const generation = this.search.takeGeneration();
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopSearch();
      stopRefreshAction?.();
      stopParams.unsubscribe();
      if (!this.search.isCurrentGeneration(generation)) return;
      if (this.navigation.screenForUrl(this.router.url)?.descriptor === screen.descriptor) return;
      if (this.refresh.descriptor() === screen.descriptor) this.refresh.unbind();
    });
  }

  /** The criteria form's controls, in declaration order. */
  protected get criteria(): readonly CriterionView[] {
    this.generation();
    const screen = this.list?.screen;
    if (screen === undefined || screen.read?.criteria === undefined || screen.read.criteria === null) return [];
    return screen.read.criteria.fields.map((field) => ({
      param: field.param,
      id: `ocu-audit-criterion-${field.param}`,
      label: stringFor(field.labelKey),
      choice: field.kind === 'choice',
      options: field.options ?? [],
      value: this.search.value(field.param),
      unavailable: this.search.overriddenByMarker(screen, field.param),
    }));
  }

  protected get markerOn(): boolean {
    this.generation();
    return this.search.marker();
  }

  protected get searched(): boolean {
    this.generation();
    return this.search.searched();
  }

  /**
   * The row the id route names, or `null`. Resolved out of the rows the last read returned, by the
   * same `rowKey` the table linked with, so the dialog and the row it opened from cannot disagree.
   * A key that matches nothing -- a pasted URL, or a row a later search dropped -- renders no
   * dialog rather than an empty one.
   */
  protected get detail(): DetailView | null {
    this.generation();
    const view = this.list;
    const id = this.entityId();
    if (view === null || id === '') return null;
    const row = view.store.data().find((candidate) => rowKey(candidate, view.screen) === id);
    if (row === undefined) return null;
    return {
      description: textOf(fieldOf(row, 'Description')),
      eventData: textOf(fieldOf(row, 'EventData')),
    };
  }

  protected onCriterion(param: string, event: Event): void {
    const screen = this.list?.screen;
    // A control the marker has overridden is `aria-disabled`, not `disabled`, so it still takes
    // focus and still fires: the value it would set is dropped here instead.
    if (screen !== undefined && this.search.overriddenByMarker(screen, param)) return;
    this.search.setValue(param, (event.target as HTMLInputElement | HTMLSelectElement).value);
  }

  protected onMarker(event: Event): void {
    this.search.setMarker((event.target as HTMLInputElement).checked);
  }

  /** Search: bind the read if this is the first one, then read now whatever the rate. */
  protected onSearch(event: Event): void {
    event.preventDefault();
    const screen = this.list?.screen;
    if (screen === undefined) return;
    this.search.noteSearched();
    this.refresh.bind(screen, this.search.readFor(screen));
    void this.refresh.readNow();
  }

  /**
   * Close the dialog by returning to the bare route. Focus goes back to the grid, which is where
   * the row was activated from and the table's one Tab stop (EXPERIENCE.md "action for the selection —").
   *
   * **The focus is handed to the next instance rather than taken here.** The dialog's own route is
   * a second route config over the same screen, so this component is destroyed by the navigation
   * and the grid the user came from goes with it; the element `Dialog` recorded as its opener is
   * gone by the time it would restore it. The store carries a one-shot request instead, and the
   * instance the router creates honours it once the table has rendered.
   */
  protected onCloseDetail(): void {
    const screen = this.list?.screen;
    if (screen === undefined) return;
    this.search.requestGridFocus();
    void this.router.navigateByUrl(withQuery(screen.route, this.router.url));
  }

  protected onFocusFilter(): void {
    document.getElementById(COMMAND_BAR_FILTER_ID)?.focus();
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}
