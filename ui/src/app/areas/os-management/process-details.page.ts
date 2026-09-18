import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router, NavigationEnd } from '@angular/router';

import { ApiService } from '../../core/api';
import { NavigationService, parentCriteria } from '../../core/navigation';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { createScreenRead } from '../../core/screen-read';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { cellView, fieldOf } from '../../core/table-model';
import { DetailHighlights } from '../../core/detail-highlights';
import type { ScreenDeclaration, TableColumn } from '../../core/screens.generated';
import { STRINGS, stringFor } from '../../core/strings';
import { groupFor, inTransactionText, type ProcessDetailsGroup } from './process-details.store';

/** The screen this page renders and the store its fields read. */
interface DetailsView {
  readonly screen: ScreenDeclaration;
  readonly store: ScreenStore;
}

/** One rendered field: its label, its value and whether the last tick changed it. */
interface FieldView {
  readonly field: string;
  readonly label: string;
  readonly value: string;
  readonly changed: boolean;
}

/**
 * Process details (Story 6.8): one process's own metrics and identity, read on open through the
 * route's one criterion (`parentCriteria`) and bound to the shared auto-refresh framework, the
 * same shape `areas/tasks/details.page.ts` follows for Task details -- the field list stands in
 * for `DataTable`'s table, since `TableProblem` requires a declared `table` of any read-declaring
 * screen and this page draws its columns as three labeled groups of label-and-value pairs instead
 * of rows.
 *
 * **States.** Skeleton fields on first load only; a fault keeps the last values and shows "request
 * refused" with Retry above them; zero rows -- an exited process, answered as a 404 the port reads
 * as none (AD-37) -- show "This process no longer exists." instead of the fields. A silent tick
 * highlights each field whose value changed (EXPERIENCE.md "Highlight."), tracked by
 * `DetailHighlights` rather than by `ScreenStore.changed()`, which marks whole rows.
 *
 * **Grouping.** `groupFor` (`process-details.store.ts`) sorts the declared columns into the
 * classic page's three labeled value groups; a column no group names renders in General, so
 * nothing is hidden. `InTransaction` renders through `inTransactionText` rather than `cellView`'s
 * own boolean rule, and the name column never renders as a link -- there is no sibling screen for
 * it to open.
 *
 * No meter component and no thresholds: process metrics declare none (Story 6.9 builds the
 * meter).
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-process-details-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<section class="ocu-details-page" [attr.aria-busy]="busy">
    @if (showRefusal) {
      <div class="ocu-data-table-refusal" role="alert">
        <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
        <button type="button" class="ocu-button-text" (click)="onRetry()">{{ STRINGS.actionRetry }}</button>
      </div>
    }
    @if (showSkeleton) {
      <div class="ocu-data-table-skeleton" aria-hidden="true">
        @for (bar of skeletonRows; track bar) {
          <div class="ocu-data-table-skeleton-row">
            <span class="ocu-skeleton-bar ocu-skeleton-bar-40"></span>
            <span class="ocu-skeleton-bar ocu-skeleton-bar-15"></span>
          </div>
        }
      </div>
    }
    @if (showEmpty) {
      <section class="ocu-empty-state" tabindex="-1">
        <p class="ocu-data-table-empty-title">{{ STRINGS.processDetailsGone }}</p>
      </section>
    }
    @if (showFields) {
      @for (group of groupViews; track group.heading) {
        <section class="ocu-details-group">
          <h2 class="ocu-details-heading">{{ group.heading }}</h2>
          <div class="ocu-details-fields">
            @for (field of group.fields; track field.field) {
              <div class="ocu-details-field" [class.ocu-data-table-row-changed]="field.changed">
                <span class="ocu-details-field-label">{{ field.label }}</span>
                <span class="ocu-details-field-value">{{ field.value }}</span>
                @if (field.changed) {
                  <span class="ocu-data-table-changed-tag">{{ STRINGS.tableChangedTag }}</span>
                }
              </div>
            }
          </div>
        </section>
      }
    }
  </section>`,
})
export class ProcessDetailsPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);
  private readonly refresh = inject(RefreshService);
  private readonly api = inject(ApiService);
  private readonly scope = inject(ScopeService);
  private readonly actions = inject(ScreenActions);

  protected readonly STRINGS = STRINGS;

  protected readonly skeletonRows = [0, 1, 2];

  private readonly view: DetailsView | null;

  private readonly highlights: DetailHighlights;

  /** Bumped by the store, so the fields re-render under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    const screen = this.navigation.screenForUrl(this.router.url);
    if (screen === null || screen.read === null || screen.table === null) {
      this.view = null;
      this.highlights = new DetailHighlights();
      return;
    }
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    this.view = { screen, store };
    this.highlights = new DetailHighlights();
    store.clearAnswers();

    const criteria = () => parentCriteria(screen, this.router.url);
    this.refresh.bind(screen, createScreenRead(this.api, screen, criteria));
    if (this.scope.loaded()) void this.refresh.readNow();

    let readFor = JSON.stringify(criteria());
    const stopIdChange = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      if (this.navigation.screenForUrl(this.router.url)?.descriptor !== screen.descriptor) return;
      const next = JSON.stringify(criteria());
      if (next === readFor) return;
      readFor = next;
      // A different process's pid: the rows, and the change highlight, belong to the process this
      // page has left (the same rule a namespace switch follows for a parent-scoped list).
      this.highlights.reset();
      if (this.scope.loaded()) this.refresh.noteScopeChanged();
    });

    const stopRefreshAction = this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
      void this.refresh.readNow();
    });

    const stopStore = store.subscribe(() => {
      const row = store.data()[0];
      // Zero rows: the process exited. A process that later answers under the same pid is a new
      // one, so it starts with nothing highlighted.
      if (row === undefined) this.highlights.reset();
      else this.highlights.update(row, this.fieldNames(screen));
      this.generation.update((value) => value + 1);
    });

    // A fault changes the refresh service and never the store, so the refusal strip needs its own
    // signal to render under `OnPush`.
    const stopRefresh = this.refresh.subscribe(() => this.generation.update((value) => value + 1));

    inject(DestroyRef).onDestroy(() => {
      stopIdChange.unsubscribe();
      stopStore();
      stopRefresh();
      stopRefreshAction();
      if (this.refresh.descriptor() === screen.descriptor) this.refresh.unbind();
    });
  }

  private fieldNames(screen: ScreenDeclaration): readonly string[] {
    return screen.table?.columns.map((column) => column.field) ?? [];
  }

  private get boundHere(): boolean {
    this.generation();
    return this.view !== null && this.refresh.descriptor() === this.view.screen.descriptor;
  }

  private get loaded(): boolean {
    return this.boundHere && this.refresh.hasLoaded();
  }

  private get row(): unknown {
    this.generation();
    return this.view?.store.data()[0];
  }

  protected get busy(): boolean {
    return !this.loaded;
  }

  protected get showRefusal(): boolean {
    this.generation();
    return this.boundHere && this.refresh.fault() !== null;
  }

  protected get showSkeleton(): boolean {
    return !this.loaded && !this.showRefusal;
  }

  protected get showEmpty(): boolean {
    return this.loaded && !this.showRefusal && this.row === undefined;
  }

  protected get showFields(): boolean {
    return this.loaded && this.row !== undefined;
  }

  /** One field, rendered: `InTransaction` through its own word, everything else through `cellView`. */
  private fieldView(column: TableColumn, row: unknown, changed: ReadonlySet<string>): FieldView {
    const value =
      column.field === 'InTransaction'
        ? inTransactionText(row)
        : cellView(fieldOf(row, column.field), column.kind, column.emptyKey ?? '').text;
    return { field: column.field, label: stringFor(column.labelKey), value, changed: changed.has(column.field) };
  }

  /** The three groups, each with its heading and the field views it carries, in declared order. */
  protected get groupViews(): ReadonlyArray<{ heading: string; fields: readonly FieldView[] }> {
    this.generation();
    const view = this.view;
    const row = this.row;
    if (view === null || row === undefined) return [];
    const changed = this.highlights.changed();
    const columns = view.screen.table?.columns ?? [];
    const byGroup: Record<ProcessDetailsGroup, TableColumn[]> = { general: [], execution: [], client: [] };
    for (const column of columns) byGroup[groupFor(column.field)].push(column);
    const headings: ReadonlyArray<{ key: ProcessDetailsGroup; heading: string }> = [
      { key: 'general', heading: STRINGS.processDetailsGroupGeneral },
      { key: 'execution', heading: STRINGS.processDetailsGroupExecution },
      { key: 'client', heading: STRINGS.processDetailsGroupClientApplication },
    ];
    return headings.map(({ key, heading }) => ({
      heading,
      fields: byGroup[key].map((column) => this.fieldView(column, row, changed)),
    }));
  }

  protected onRetry(): void {
    void this.refresh.readNow();
  }
}
