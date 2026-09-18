import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { NavigationEnd, Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { DetailHighlights } from '../../core/detail-highlights';
import { NavigationService, parentCriteria, screenForRoute } from '../../core/navigation';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { createScreenRead } from '../../core/screen-read';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration, TableColumn } from '../../core/screens.generated';
import { STRINGS, stringFor } from '../../core/strings';
import { cellView, fieldOf } from '../../core/table-model';
import { Meter } from '../../shell/meter';
import { availableSpaceMeterView, isPropertyField } from './database-details.store';

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

/** One rendered volume-file cell. */
interface VolumeCellView {
  readonly field: string;
  readonly text: string;
}

/** One rendered volume-file row. */
interface VolumeRowView {
  readonly key: string;
  readonly cells: readonly VolumeCellView[];
}

/** The route Database details' Volume files section reads (AD-5's new mechanism, Story 6.11). */
const VOLUMES_ROUTE = 'os-management/databases/volumes';

/** The volumes read's own row cap: a database's own files are never many. */
const VOLUMES_MAX_ROWS = 200;

/**
 * Database details (Story 6.11): one database's own properties and volume files, read on open
 * through the route's one criterion (`parentCriteria`, shared with `DatabaseVolumeList` since both
 * declare the same `dir` param) and bound to the shared auto-refresh framework -- the same shape
 * `process-details.page.ts` follows, with one flat properties group instead of three and one value
 * meter instead of none.
 *
 * **States.** Skeleton fields on first load only; a fault keeps the last values and shows "request
 * refused" with Retry above them (AC6) -- the shared `RefreshService`/`ScreenStore` mechanism
 * `process-details.page.ts` already relies on, unchanged here; zero rows -- an unrecognized
 * directory, answered as a 404 the port reads as none (AD-37) -- show "This database no longer
 * exists." instead of the fields. A silent tick highlights each changed field
 * (`DetailHighlights`).
 *
 * **The meter.** `AvailableSpace` renders through the shared `app-meter` component
 * (`database-details.store.ts`) rather than as a plain field, since `Size` and `AvailableSpace` are
 * not published in the same unit and so make no percentage; every other declared field renders as
 * an ordinary property, `Directory` (the name) included.
 *
 * **Volume files (AD-5, AC9): a page issuing another built screen's declared read.** No descriptor
 * links `DatabaseDetails` to `DatabaseVolumeList` -- this page is the one place the pairing is
 * named, resolving the sibling screen by its route (`screenForRoute`) and reading it with the same
 * one `dir` criterion this page's own route already supplies. It is a one-shot read (`applyTick`
 * into that screen's own store, so a later reader of the store sees the same rows this page
 * rendered), never through `RefreshService.bind`, since `DatabaseVolumeList` declares
 * `refreshes: false` and a second bound read would contend with this page's own binding --
 * `app-data-table` itself renders only the one screen `RefreshService` is bound to, so this
 * section draws its own small table from the same declared columns and `cellView` rule instead,
 * one cell-rendering rule shared with every other table even though the markup is not literally
 * `app-data-table`'s.
 *
 * **A refused volumes read says so in the section.** The sibling screen carries its own pair set
 * -- `%Admin_Manage:USE`, which this screen deliberately does not declare (see the descriptor) --
 * so the designed least-privileged principal for Database details is refused that read on every
 * load. The section shows the shared refusal line with Retry, never a bare heading: this page's
 * own refusal strip covers only its properties read, and the declared empty state would claim the
 * database has no volume files when nobody was allowed to look.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-database-details-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Meter],
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
        <p class="ocu-data-table-empty-title">{{ STRINGS.databaseDetailsGone }}</p>
      </section>
    }
    @if (showFields) {
      <section class="ocu-details-group">
        <h2 class="ocu-details-heading">{{ STRINGS.processDetailsGroupGeneral }}</h2>
        <div class="ocu-details-fields">
          <app-meter
            [label]="meterView.label"
            [value]="meterView.value"
            [unit]="meterView.unit"
            [percent]="meterView.percent"
            [state]="meterView.state"
            [word]="meterView.word"
            [error]="meterView.error"
          />
          @for (field of fieldViews; track field.field) {
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
      <section class="ocu-details-group">
        <h2 class="ocu-details-heading">{{ STRINGS.databaseVolumeListLabel }}</h2>
        @if (volumesFault) {
          <div class="ocu-data-table-refusal" role="alert">
            <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
            <button type="button" class="ocu-button-text" (click)="onRetryVolumes()">{{ STRINGS.actionRetry }}</button>
          </div>
        }
        @if (hasVolumeRows) {
          <table class="ocu-details-volumes-table" role="table">
            <thead>
              <tr role="row">
                @for (column of volumeColumns; track column.field) {
                  <th role="columnheader" scope="col">{{ column.label }}</th>
                }
              </tr>
            </thead>
            <tbody>
              @for (row of volumeRows; track row.key) {
                <tr role="row">
                  @for (cell of row.cells; track cell.field) {
                    <td role="cell">{{ cell.text }}</td>
                  }
                </tr>
              }
            </tbody>
          </table>
        }
        @if (showVolumesEmpty) {
          <p class="ocu-data-table-empty-title">{{ STRINGS.databaseVolumeListEmpty }}</p>
        }
      </section>
    }
  </section>`,
})
export class DatabaseDetailsPage {
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

  protected readonly volumes: DetailsView | null;

  private readonly highlights: DetailHighlights;

  /** Bumped by the store and the refresh service, so the fields re-render under `OnPush`. */
  private readonly generation = signal(0);

  /** Whether the Volume files section's one-shot read has ever completed, so an empty table
   * renders the declared empty state rather than nothing while a first read is still in flight. */
  private readonly volumesLoadedSignal = signal(false);

  /** Whether the Volume files section's own read was refused, so the section says so rather than
   * rendering an empty state that would claim the database has no volume files. */
  private readonly volumesFaultSignal = signal(false);

  constructor() {
    const screen = this.navigation.screenForUrl(this.router.url);
    const volumesScreen = screenForRoute(VOLUMES_ROUTE);
    if (screen === null || screen.read === null || screen.table === null) {
      this.view = null;
      this.volumes = null;
      this.highlights = new DetailHighlights();
      return;
    }
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    this.view = { screen, store };
    this.highlights = new DetailHighlights();
    store.clearAnswers();
    this.volumes =
      volumesScreen === null ? null : { screen: volumesScreen, store: this.stores.for(volumesScreen.descriptor, volumesScreen.refreshRates) };

    const criteria = () => parentCriteria(screen, this.router.url);
    this.refresh.bind(screen, createScreenRead(this.api, screen, criteria));
    if (this.scope.loaded()) {
      void this.refresh.readNow();
      void this.loadVolumes(criteria());
    }

    let readFor = JSON.stringify(criteria());
    const stopIdChange = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      if (this.navigation.screenForUrl(this.router.url)?.descriptor !== screen.descriptor) return;
      const next = criteria();
      if (JSON.stringify(next) === readFor) return;
      readFor = JSON.stringify(next);
      // A different database's directory: the rows, the change highlight and the volume files
      // belong to the database this page has left (the same rule ProcessDetailsPage follows for a
      // different pid).
      this.highlights.reset();
      this.volumes?.store.clearAnswers();
      this.volumesLoadedSignal.set(false);
      this.volumesFaultSignal.set(false);
      if (this.scope.loaded()) {
        this.refresh.noteScopeChanged();
        void this.loadVolumes(next);
      }
    });

    const stopRefreshAction = this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
      void this.refresh.readNow();
      void this.loadVolumes(criteria());
    });

    const stopStore = store.subscribe(() => {
      const row = store.data()[0];
      if (row === undefined) this.highlights.reset();
      else this.highlights.update(row, this.fieldNames(screen));
      this.generation.update((value) => value + 1);
    });

    const stopRefresh = this.refresh.subscribe(() => this.generation.update((value) => value + 1));

    inject(DestroyRef).onDestroy(() => {
      stopIdChange.unsubscribe();
      stopStore();
      stopRefresh();
      stopRefreshAction();
      if (this.refresh.descriptor() === screen.descriptor) this.refresh.unbind();
    });
  }

  /**
   * The Volume files section's own one-shot read (AD-5, AC9): the same declared read
   * `osmgmt.databasevolumes`' own route would issue, narrowed by the same `dir` criterion, applied
   * straight into that screen's own store so the shared table renders it unchanged.
   */
  private async loadVolumes(criteria: Readonly<Record<string, string>>): Promise<void> {
    const volumes = this.volumes;
    if (volumes === null) return;
    const read = createScreenRead(this.api, volumes.screen, () => criteria);
    const result = await read({ maxRows: VOLUMES_MAX_ROWS });
    if (result.kind !== 'ok') {
      this.volumesFaultSignal.set(true);
      this.volumesLoadedSignal.set(true);
      this.generation.update((value) => value + 1);
      return;
    }
    this.volumesFaultSignal.set(false);
    volumes.store.applyTick(result.rows, result.truncated, result.banner ?? '', new Date());
    this.volumesLoadedSignal.set(true);
    this.generation.update((value) => value + 1);
  }

  private fieldNames(screen: ScreenDeclaration): readonly string[] {
    return screen.table?.columns.filter((column) => isPropertyField(column.field)).map((column) => column.field) ?? [];
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

  protected get meterView() {
    this.generation();
    return availableSpaceMeterView(this.row, this.showRefusal ? STRINGS.connectivityRequestRefused : null);
  }

  private fieldView(column: TableColumn, row: unknown, changed: ReadonlySet<string>): FieldView {
    const value = cellView(fieldOf(row, column.field), column.kind, column.emptyKey ?? '').text;
    return { field: column.field, label: stringFor(column.labelKey), value, changed: changed.has(column.field) };
  }

  /** Every declared column but the meter's own, in declared order. */
  protected get fieldViews(): readonly FieldView[] {
    this.generation();
    const view = this.view;
    const row = this.row;
    if (view === null || row === undefined) return [];
    const changed = this.highlights.changed();
    const columns = view.screen.table?.columns.filter((column) => isPropertyField(column.field)) ?? [];
    return columns.map((column) => this.fieldView(column, row, changed));
  }

  protected onRetry(): void {
    void this.refresh.readNow();
    const view = this.view;
    if (view !== null) void this.loadVolumes(parentCriteria(view.screen, this.router.url));
  }

  protected get volumesLoaded(): boolean {
    return this.volumesLoadedSignal();
  }

  protected get hasVolumeRows(): boolean {
    return this.volumeRows.length > 0;
  }

  protected get volumesFault(): boolean {
    this.generation();
    return this.volumesFaultSignal();
  }

  protected get showVolumesEmpty(): boolean {
    return this.volumesLoaded && !this.hasVolumeRows && !this.volumesFault;
  }

  /** Retry the Volume files read alone: the properties read has its own strip and its own Retry. */
  protected onRetryVolumes(): void {
    const view = this.view;
    if (view !== null) void this.loadVolumes(parentCriteria(view.screen, this.router.url));
  }

  /** The Volume files section's declared columns, labelled through the one string source. */
  protected get volumeColumns(): readonly { readonly field: string; readonly label: string }[] {
    return this.volumes?.screen.table?.columns.map((column) => ({ field: column.field, label: stringFor(column.labelKey) })) ?? [];
  }

  /** The Volume files section's rows, rendered through the same `cellView` rule every table uses. */
  protected get volumeRows(): readonly VolumeRowView[] {
    this.generation();
    const volumes = this.volumes;
    if (volumes === null) return [];
    const columns = volumes.screen.table?.columns ?? [];
    if (columns.length === 0) return [];
    return volumes.store.data().map((row, index) => ({
      key: String(index),
      cells: columns.map((column) => ({
        field: column.field,
        text: cellView(fieldOf(row, column.field), column.kind, column.emptyKey ?? '').text,
      })),
    }));
  }
}
