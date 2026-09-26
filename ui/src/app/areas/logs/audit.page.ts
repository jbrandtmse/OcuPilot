import { ChangeDetectionStrategy, Component, DestroyRef, afterNextRender, inject, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';

import { decodeEntityId } from '../../core/entity-id';
import { ExplainEntry } from '../../core/explain-entry';
import { NavigationService, withQuery } from '../../core/navigation';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenArrivals } from '../../core/screen-arrival';
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
 * table, and the row detail dialog the `/:id` route opens (AD-5).
 *
 * **It opens on the screen's default search** (EXPERIENCE.md "default search on open, skeleton
 * until it answers"). One read runs at once with no criteria, so the instance applies the declared
 * default -- the last 24 hours, marker off (AD-36, AD-46) -- and the form then shows the values the
 * read applied. A return visit re-runs the person's last Search, or the default when there was
 * none. An agent arrival (`ScreenArrivals`) runs exactly the search it carries instead, once.
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
      <app-data-table [screen]="view.screen" [store]="view.store" (focusFilter)="onFocusFilter()" />
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
          @if (explainShown) {
            <button
              dialogAction
              type="button"
              class="ocu-button-secondary ocu-audit-explain"
              data-ocu-audit="explain"
              [attr.aria-disabled]="explainAriaDisabled"
              [attr.aria-describedby]="explainDescribedBy"
              (click)="onExplain()"
            >
              {{ STRINGS.agentExplainEntryAction }}
            </button>
          }
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
  private readonly scope = inject(ScopeService);

  private readonly actions = inject(ScreenActions);

  /** An agent navigation's hand-off (Story 11.11). Optional, so a spec that needs none provides none. */
  private readonly arrivals = inject(ScreenArrivals, { optional: true });

  /** The "Explain this entry" hand-off (Story 11.2). Optional, so a spec that needs none provides none. */
  private readonly explainEntry = inject(ExplainEntry, { optional: true });

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

    // Bound on every open. The dialog round trip re-binds the same descriptor with the same
    // closure, which `bind` treats as a no-op that keeps `hasLoaded`, so it reads nothing.
    this.refresh.bind(screen, this.search.readFor(screen));
    const arrival = this.arrivals?.take(screen.route) ?? null;
    if (arrival !== null) {
      this.search.useArrival(screen, arrival);
      this.readNow();
    } else if (!this.refresh.hasLoaded()) {
      // A first visit or a return: the person's last Search when there was one, else the default.
      if (this.search.searched()) this.search.useForm();
      else this.search.useDefault();
      this.readNow();
    }

    // Manual Refresh (DW-260): re-runs the read the screen last issued, reading the form at call
    // time once a Search has run.
    const stopRefreshAction = this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
      this.refresh.bind(screen, this.search.readFor(screen));
      void this.refresh.readNow();
    });

    // An arrival for this screen while it is already mounted is taken here, in place of a new page.
    const stopArrivals =
      this.arrivals?.subscribe(() => {
        const next = this.arrivals?.take(screen.route) ?? null;
        if (next === null) return;
        this.search.useArrival(screen, next);
        this.readNow();
      }) ?? null;

    const stopStore = store.subscribe(() => this.bump());
    const stopExplain = this.explainEntry?.subscribe(() => this.bump()) ?? null;
    const stopSearch = this.search.subscribe(() => this.bump());
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
      stopExplain?.();
      stopSearch();
      stopRefreshAction();
      stopArrivals?.();
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

  /**
   * The row the id route names, or `null`. Resolved out of the rows the last read returned, by the
   * same `rowKey` the table linked with, so the dialog and the row it opened from cannot disagree.
   * A key that matches nothing -- a pasted URL, or a row a later search dropped -- renders no
   * dialog rather than an empty one.
   */
  protected get detail(): DetailView | null {
    const row = this.detailRow;
    if (row === null) return null;
    return {
      description: textOf(fieldOf(row, 'Description')),
      eventData: textOf(fieldOf(row, 'EventData')),
    };
  }

  /** The row the id route names, as the last read returned it, or `null` (`detail`). */
  private get detailRow(): unknown {
    this.generation();
    const view = this.list;
    const id = this.entityId();
    if (view === null || id === '') return null;
    return view.store.data().find((candidate) => rowKey(candidate, view.screen) === id) ?? null;
  }

  /** Whether the dialog carries "Explain this entry": the agent answered with an enabled definition. */
  protected get explainShown(): boolean {
    this.generation();
    return this.explainEntry !== null && this.explainEntry.shown();
  }

  protected get explainAriaDisabled(): 'true' | null {
    this.generation();
    const entry = this.explainEntry;
    return entry === null || entry.reason() === null ? null : 'true';
  }

  protected get explainDescribedBy(): string | null {
    this.generation();
    return this.explainEntry?.describedBy() ?? null;
  }

  /**
   * Hand the open row to the panel, then close the dialog as its own action does. A refused control
   * sends nothing and leaves the dialog open.
   */
  protected onExplain(): void {
    const view = this.list;
    const row = this.detailRow;
    if (this.explainEntry === null || view === null || row === null || typeof row !== 'object') return;
    if (!this.explainEntry.request(view.screen, row)) return;
    this.onCloseDetail();
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

  /** Search: send the form as shown, an emptied field as an unset bound, and read now whatever the rate. */
  protected onSearch(event: Event): void {
    event.preventDefault();
    const screen = this.list?.screen;
    if (screen === undefined) return;
    this.search.noteSearched();
    this.search.useForm();
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

  /** Read once the scope has resolved; before then the framework's own scope read is the one. */
  private readNow(): void {
    if (this.scope.loaded()) void this.refresh.readNow();
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}
