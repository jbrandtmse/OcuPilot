import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { NavigationService, formatRequires, screenForRoute } from '../../core/navigation';
import { RefreshService, type RefreshRead } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { createScreenRead } from '../../core/screen-read';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS, stringFor } from '../../core/strings';
import { cellView, fieldOf } from '../../core/table-model';
import { Meter } from '../../shell/meter';
import { DASHBOARD_GROUPS, TASK_MANAGER_GROUP, dashboardMeterView, type DashboardMeterView } from './dashboard.store';

/** The screen this page renders and the store its one row lives in. */
interface DashboardView {
  readonly screen: ScreenDeclaration;
  readonly store: ScreenStore;
}

/** One rendered group: its heading and its meters, or the Task manager group's marker. */
interface GroupView {
  readonly key: string;
  readonly heading: string;
  readonly headingId: string;
  readonly tasks: boolean;
  readonly meters: readonly DashboardMeterView[];
}

/** One rendered Task manager cell. */
interface TaskCellView {
  readonly field: string;
  readonly label: string;
  readonly text: string;
}

/** One rendered Task manager row. */
interface TaskRowView {
  readonly key: string;
  readonly cells: readonly TaskCellView[];
}

/** The route of the screen whose declared read the Task manager group issues (AD-5). */
const UPCOMING_ROUTE = 'tasks/upcoming';

/** How many upcoming occurrences the Task manager group asks for. */
const UPCOMING_MAX_ROWS = 5;

/** The Upcoming tasks fields the group draws, in its order: At, Name and Suspended. */
const UPCOMING_FIELDS: readonly string[] = ['Datetime', 'Name', 'Suspended'];

/** The horizon the group reads, the one Upcoming tasks itself opens on. */
const UPCOMING_CRITERIA = { hoursOffset: '24' } as const;

/**
 * Dashboard (Story 16.7): the classic System Dashboard's seven groups over one read, bound to the
 * shared auto-refresh framework the way `system-usage.page.ts` is -- `stores.for`,
 * `refresh.bind`, `readNow`, `REFRESH_ACTION_ID`, the generation signal, `DestroyRef` unbind.
 *
 * **Six groups are meters** (`dashboard.store.ts`), each a heading over a grid of the shared
 * `app-meter`: status meters with the vendor's word, percent meters against DESIGN.md's cut-offs,
 * and value meters with a formatted readout and no state. Every meter shows the dash and a
 * skeleton until the first read lands, carries the current fault in its tooltip, and never
 * animates; a tick updates them silently, with no live region.
 *
 * **The Task manager group issues Upcoming tasks' own declared read** (AD-5, as
 * `database-details.page.ts` issues the volume files' read): once per Dashboard tick, at five rows
 * over the horizon that screen opens on, applied into that screen's own store, and drawn as its
 * At, Name and Suspended cells under its own column labels through the shared `cellView` rule. A
 * caller that screen refuses sees "Requires <pair>" and nothing is read; no rows show that
 * screen's own empty text.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-dashboard-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Meter],
  template: `<section class="ocu-dashboard" [attr.aria-busy]="busy">
    @for (group of groupViews; track group.key) {
      <section class="ocu-dashboard-group" [attr.aria-labelledby]="group.headingId">
        <h2 class="ocu-details-heading ocu-dashboard-heading" [id]="group.headingId">{{ group.heading }}</h2>
        @if (group.tasks) {
          <div class="ocu-dashboard-tasks">
            @if (showTasksGated) {
              <p class="ocu-dashboard-tasks-gated">{{ tasksGatedText }}</p>
            }
            @if (showTasksSkeleton) {
              <div class="ocu-data-table-skeleton" aria-hidden="true">
                <div class="ocu-data-table-skeleton-row">
                  <span class="ocu-skeleton-bar ocu-skeleton-bar-40"></span>
                  <span class="ocu-skeleton-bar ocu-skeleton-bar-15"></span>
                </div>
              </div>
            }
            @if (showTasksRefused) {
              <p class="ocu-dashboard-tasks-refused">{{ STRINGS.connectivityRequestRefused }}</p>
            }
            @if (showTasksEmpty) {
              <p class="ocu-dashboard-tasks-empty">{{ tasksEmptyText }}</p>
            }
            @if (showTasksRows) {
              <table class="ocu-dashboard-tasks-table">
                <thead>
                  <tr>
                    @for (label of taskLabels; track label.field) {
                      <th scope="col">{{ label.label }}</th>
                    }
                  </tr>
                </thead>
                <tbody>
                  @for (taskRow of taskRows; track taskRow.key) {
                    <tr>
                      @for (cell of taskRow.cells; track cell.field) {
                        <td>{{ cell.text }}</td>
                      }
                    </tr>
                  }
                </tbody>
              </table>
            }
          </div>
        } @else {
          <div class="ocu-dashboard-meters">
            @for (meter of group.meters; track meter.field) {
              <app-meter
                [label]="meter.label"
                [value]="meter.value"
                [text]="meter.text"
                [unit]="meter.unit"
                [percent]="meter.percent"
                [state]="meter.state"
                [word]="meter.word"
                [error]="meter.error"
                [skeleton]="true"
              />
            }
          </div>
        }
      </section>
    }
  </section>`,
})
export class DashboardPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);
  private readonly refresh = inject(RefreshService);
  private readonly api = inject(ApiService);
  private readonly scope = inject(ScopeService);
  private readonly actions = inject(ScreenActions);

  protected readonly STRINGS = STRINGS;

  private readonly view: DashboardView | null;

  /** Upcoming tasks' own screen and store, which the Task manager group reads into. */
  private readonly upcoming: DashboardView | null;

  /** Bumped by the stores and by the refresh service, so the view re-renders under `OnPush`. */
  private readonly generation = signal(0);

  /** Whether the Task manager group's read has answered at least once. */
  private readonly tasksLoadedSignal = signal(false);

  /** Whether the Task manager group's last read was refused. */
  private readonly tasksFaultSignal = signal(false);

  constructor() {
    const screen = this.navigation.screenForUrl(this.router.url);
    const upcoming = screenForRoute(UPCOMING_ROUTE);
    this.upcoming =
      upcoming === null || upcoming.read === null ? null : { screen: upcoming, store: this.stores.for(upcoming.descriptor, upcoming.refreshRates) };
    if (screen === null || screen.read === null) {
      this.view = null;
      return;
    }
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    this.view = { screen, store };
    store.clearAnswers();

    const read = createScreenRead(this.api, screen);
    const tick: RefreshRead = async (options) => {
      void this.loadTasks();
      return read(options);
    };
    this.refresh.bind(screen, tick);
    if (this.scope.loaded()) void this.refresh.readNow();

    const stopRefreshAction = this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
      void this.refresh.readNow();
    });

    const stopStore = store.subscribe(() => this.generation.update((value) => value + 1));

    // A fault changes the refresh service and never the store, so the meters' tooltip needs its
    // own signal to render under `OnPush`.
    const stopRefresh = this.refresh.subscribe(() => this.generation.update((value) => value + 1));

    // The navigation map answers after the page opens, and the Task manager group's gate reads it.
    const stopNavigation = this.navigation.subscribe(() => this.generation.update((value) => value + 1));

    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopRefresh();
      stopNavigation();
      stopRefreshAction();
      if (this.refresh.descriptor() === screen.descriptor) this.refresh.unbind();
    });
  }

  /**
   * The Task manager group's read, issued once per Dashboard tick: Upcoming tasks' declared read at
   * five rows, into that screen's own store, or nothing at all for a caller that screen refuses.
   */
  private async loadTasks(): Promise<void> {
    const upcoming = this.upcoming;
    if (upcoming === null || !this.tasksAllowed) return;
    const read = createScreenRead(this.api, upcoming.screen, () => UPCOMING_CRITERIA);
    const result = await read({ maxRows: UPCOMING_MAX_ROWS });
    if (result.kind === 'ok') {
      upcoming.store.applyTick(result.rows, result.truncated, result.banner ?? '', new Date());
      this.tasksFaultSignal.set(false);
    } else {
      this.tasksFaultSignal.set(true);
    }
    this.tasksLoadedSignal.set(true);
    this.generation.update((value) => value + 1);
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

  /** The current fault as the one string every meter's tooltip shares, or `null`. */
  private get faultText(): string | null {
    if (!this.boundHere) return null;
    return this.refresh.fault() !== null ? STRINGS.connectivityRequestRefused : null;
  }

  protected get busy(): boolean {
    return !this.loaded && this.faultText === null;
  }

  protected get groupViews(): readonly GroupView[] {
    this.generation();
    if (this.view === null) return [];
    const row = this.row;
    const faultText = this.faultText;
    return DASHBOARD_GROUPS.map((group) => ({
      key: group.key,
      heading: stringFor(group.headingKey),
      headingId: `ocu-dashboard-heading-${group.key}`,
      tasks: group.key === TASK_MANAGER_GROUP,
      meters: group.meters.map((meter) => dashboardMeterView(meter, row, faultText)),
    }));
  }

  /** Whether the caller holds Upcoming tasks' pairs, as the navigation map answers them. */
  private get tasksAllowed(): boolean {
    this.generation();
    return this.navigation.screenVerdict(UPCOMING_ROUTE).allowed;
  }

  protected get showTasksGated(): boolean {
    return this.upcoming !== null && !this.tasksAllowed;
  }

  protected get tasksGatedText(): string {
    return formatRequires(STRINGS.privilegeRequiresResource, this.navigation.screenVerdict(UPCOMING_ROUTE).failedPair);
  }

  private get tasksReadable(): boolean {
    return this.upcoming !== null && this.tasksAllowed;
  }

  protected get showTasksSkeleton(): boolean {
    this.generation();
    return this.tasksReadable && !this.tasksLoadedSignal();
  }

  protected get showTasksRefused(): boolean {
    this.generation();
    return this.tasksReadable && this.tasksLoadedSignal() && this.tasksFaultSignal();
  }

  private get taskData(): readonly unknown[] {
    this.generation();
    return this.upcoming?.store.data() ?? [];
  }

  protected get showTasksEmpty(): boolean {
    return this.tasksReadable && this.tasksLoadedSignal() && !this.tasksFaultSignal() && this.taskData.length === 0;
  }

  protected get showTasksRows(): boolean {
    return this.tasksReadable && this.tasksLoadedSignal() && !this.tasksFaultSignal() && this.taskData.length > 0;
  }

  protected get tasksEmptyText(): string {
    return stringFor(this.upcoming?.screen.emptyStateKey ?? '');
  }

  private get taskColumns() {
    const columns = this.upcoming?.screen.table?.columns ?? [];
    return UPCOMING_FIELDS.map((field) => columns.find((column) => column.field === field)).filter(
      (column): column is NonNullable<typeof column> => column !== undefined
    );
  }

  protected get taskLabels(): readonly { readonly field: string; readonly label: string }[] {
    return this.taskColumns.map((column) => ({ field: column.field, label: stringFor(column.labelKey) }));
  }

  protected get taskRows(): readonly TaskRowView[] {
    const columns = this.taskColumns;
    return this.taskData.slice(0, UPCOMING_MAX_ROWS).map((taskRow, index) => ({
      key: `${index}`,
      cells: columns.map((column) => ({
        field: column.field,
        label: stringFor(column.labelKey),
        text: cellView(fieldOf(taskRow, column.field), column.kind, column.emptyKey ?? '').text,
      })),
    }));
  }
}
