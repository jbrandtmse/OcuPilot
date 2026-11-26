import { LocationStrategy } from '@angular/common';
import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { NavigationService, formatRequires, openableEntry, screenForRoute, withQuery } from '../../core/navigation';
import { RefreshService, type RefreshRead } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { createScreenRead } from '../../core/screen-read';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS, stringFor } from '../../core/strings';
import { cellView, fieldOf } from '../../core/table-model';
import { Meter } from '../../shell/meter';
import { MONITOR_GROUPS, monitorMeterView, type MonitorGroup, type MonitorMeterView, type MonitorTable } from './interop-system-monitor.store';

/** The screen this page renders and the store its one row lives in. */
interface MonitorView {
  readonly screen: ScreenDeclaration;
  readonly store: ScreenStore;
}

/** One table's drill-down screen, with the page's own store the answer lands in. */
interface TableSource {
  readonly table: MonitorTable;
  readonly screen: ScreenDeclaration;
  readonly store: ScreenStore;
}

/** One rendered table cell. */
interface TableCellView {
  readonly field: string;
  readonly text: string;
}

/** One rendered table row. */
interface TableRowView {
  readonly key: string;
  readonly cells: readonly TableCellView[];
}

/** One group's table, drawn from its drill-down's own read: what to show in its place, its labels and its rows. */
interface TableView {
  readonly present: boolean;
  readonly gated: boolean;
  readonly gatedText: string;
  readonly skeleton: boolean;
  readonly refused: boolean;
  readonly empty: boolean;
  readonly emptyText: string;
  readonly hasRows: boolean;
  readonly labels: readonly { readonly field: string; readonly label: string }[];
  readonly rows: readonly TableRowView[];
}

/** One rendered drill-down link: the built screen it opens, its label and its address, or the reason it is gated. */
interface DrillDownLink {
  readonly route: string;
  readonly label: string;
  readonly href: string;
  readonly target: string;
  readonly gated: boolean;
  readonly reason: string;
  readonly reasonId: string;
}

/** One rendered group: its heading, the link to its drill-down, its meters and its table. */
interface GroupView {
  readonly key: string;
  readonly heading: string;
  readonly headingId: string;
  readonly link: DrillDownLink | null;
  readonly meters: readonly MonitorMeterView[];
  readonly table: TableView;
}

/** How many rows of each drill-down the page draws; the drill-down's own screen lists them all. */
const TABLE_MAX_ROWS = 5;

/** The key suffix of the page's own store for a table, beside its screen store: the rows are the page's, so a drill-down's own store is never written (AD-19). */
const TABLE_STORE_SUFFIX = '#table-';

const NO_TABLE: TableView = {
  present: false,
  gated: false,
  gatedText: '',
  skeleton: false,
  refused: false,
  empty: false,
  emptyText: '',
  hasRows: false,
  labels: [],
  rows: [],
};

/**
 * System monitor (Story 24.17 Batch 5): the classic Interoperability System Monitor's groups over one read, bound to the shared auto-refresh framework the way `dashboard.page.ts` is --
 * `stores.for`, `refresh.bind`, `readNow`, `REFRESH_ACTION_ID`, the generation signal, `DestroyRef` unbind.
 *
 * **Every group but the last is meters** (`interop-system-monitor.store.ts`), each a label over the vendor's text, or the vendor's own word for the status meters. A meter shows the dash and a
 * skeleton until the first read lands, carries the current fault in its tooltip and never animates; a tick updates them silently, with no live region.
 *
 * **Three groups draw a table from a drill-down's own declared read** (AD-5, as the Dashboard draws Upcoming tasks): Most active processes under Production jobs, Most active queues under Production
 * queues and Upcoming tasks under Task manager. Each is read once per tick at five rows, after the row has answered and one table after another, since two vendor calls in flight together
 * can answer the instance as idle; into the page's own store for it -- never the drill-down's, which no other screen writes (AD-19) -- and
 * drawn as its cells under the labels the drill-down declares through the shared `cellView` rule. Only the answer to the latest read issued by a live page is applied. A caller that screen
 * refuses sees "Requires <pair>" and nothing is read. The group's link opens the drill-down, gated as the side bar gates an entry.
 *
 * **It refreshes at one rate**, 60 seconds, default off: each read of the vendor's metrics writes the vendor's own bookkeeping, so the page never reads faster than the classic page does.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-interop-system-monitor-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Meter],
  template: `<section class="ocu-dashboard" [attr.aria-busy]="busy">
    @for (group of groupViews; track group.key) {
      <section class="ocu-dashboard-group" [attr.aria-labelledby]="group.headingId">
        <h2 class="ocu-details-heading ocu-dashboard-heading" [id]="group.headingId">{{ group.heading }}</h2>
        @if (group.link; as link) {
          <nav class="ocu-details-links" [attr.aria-labelledby]="group.headingId">
            <a
              class="ocu-details-link"
              [class.ocu-details-link-gated]="link.gated"
              [attr.href]="link.gated ? null : link.href"
              [attr.role]="link.gated ? 'link' : null"
              [attr.tabindex]="link.gated ? '0' : null"
              [attr.aria-disabled]="link.gated ? 'true' : null"
              [attr.aria-describedby]="link.gated ? link.reasonId : null"
              [attr.data-drill-down]="link.route"
              (click)="onDrillDown($event, link)"
              >{{ link.label }}@if (link.gated) {
                <span class="ocu-details-link-reason" [id]="link.reasonId">{{ link.reason }}</span>
              }</a
            >
          </nav>
        }
        @if (group.meters.length) {
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
        @if (group.table.present) {
          <div class="ocu-dashboard-tasks" [attr.aria-busy]="group.table.skeleton">
            @if (group.table.gated) {
              <p class="ocu-dashboard-tasks-gated">{{ group.table.gatedText }}</p>
            }
            @if (group.table.skeleton) {
              <div class="ocu-data-table-skeleton" aria-hidden="true">
                <div class="ocu-data-table-skeleton-row">
                  <span class="ocu-skeleton-bar ocu-skeleton-bar-40"></span>
                  <span class="ocu-skeleton-bar ocu-skeleton-bar-15"></span>
                </div>
              </div>
            }
            @if (group.table.refused) {
              <p class="ocu-dashboard-tasks-refused">{{ STRINGS.connectivityRequestRefused }}</p>
            }
            @if (group.table.empty) {
              <p class="ocu-dashboard-tasks-empty">{{ group.table.emptyText }}</p>
            }
            @if (group.table.hasRows) {
              <table class="ocu-dashboard-tasks-table">
                <thead>
                  <tr>
                    @for (label of group.table.labels; track label.field) {
                      <th scope="col">{{ label.label }}</th>
                    }
                  </tr>
                </thead>
                <tbody>
                  @for (tableRow of group.table.rows; track tableRow.key) {
                    <tr>
                      @for (cell of tableRow.cells; track cell.field) {
                        <td>{{ cell.text }}</td>
                      }
                    </tr>
                  }
                </tbody>
              </table>
            }
          </div>
        }
      </section>
    }
  </section>`,
})
export class InteropSystemMonitorPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);
  private readonly refresh = inject(RefreshService);
  private readonly api = inject(ApiService);
  private readonly scope = inject(ScopeService);
  private readonly actions = inject(ScreenActions);
  private readonly locationStrategy = inject(LocationStrategy);

  protected readonly STRINGS = STRINGS;

  private readonly view: MonitorView | null;

  /** The three drill-down screens whose declared reads the tables issue, each with the page's own store for its answer. */
  private readonly sources: readonly TableSource[];

  /** The table reads issued so far, by table key; only the latest one's answer is applied. */
  private readonly issued = new Map<string, number>();

  /** Set when the page is destroyed, so a table read that lands afterwards applies nothing. */
  private destroyed = false;

  /** Bumped by the stores and by the refresh service, so the view re-renders under `OnPush`. */
  private readonly generation = signal(0);

  /** The tables whose read has answered at least once, and the ones whose last read was refused, by table key. */
  private readonly loaded = signal<ReadonlySet<string>>(new Set());
  private readonly faulted = signal<ReadonlySet<string>>(new Set());

  constructor() {
    const screen = this.navigation.screenForUrl(this.router.url);
    if (screen === null || screen.read === null) {
      this.view = null;
      this.sources = [];
      return;
    }
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    this.view = { screen, store };
    store.clearAnswers();
    const sources: TableSource[] = [];
    for (const group of MONITOR_GROUPS) {
      const table = group.table;
      if (table === undefined) continue;
      const drillDown = screenForRoute(table.route);
      if (drillDown === null || drillDown.read === null) continue;
      const tableStore = this.stores.for(`${screen.descriptor}${TABLE_STORE_SUFFIX}${table.key}`, [], '');
      tableStore.clearAnswers();
      sources.push({ table, screen: drillDown, store: tableStore });
    }
    this.sources = sources;

    const read = createScreenRead(this.api, screen);
    const tick: RefreshRead = async (options) => {
      const result = await read(options);
      void this.loadTables();
      return result;
    };
    this.refresh.bind(screen, tick);
    if (this.scope.loaded()) void this.refresh.readNow();

    const stopRefreshAction = this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
      void this.refresh.readNow();
    });

    const stopStore = store.subscribe(() => this.generation.update((value) => value + 1));

    // A fault changes the refresh service and never the store, so the meters' tooltip needs its own signal to render under `OnPush`.
    const stopRefresh = this.refresh.subscribe(() => this.generation.update((value) => value + 1));

    // The navigation map answers after the page opens, and each table's gate reads it.
    const stopNavigation = this.navigation.subscribe(() => this.generation.update((value) => value + 1));

    inject(DestroyRef).onDestroy(() => {
      this.destroyed = true;
      stopStore();
      stopRefresh();
      stopNavigation();
      stopRefreshAction();
      if (this.refresh.descriptor() === screen.descriptor) this.refresh.unbind();
    });
  }

  /** The three tables' reads, one after another; none is issued once the page is gone. */
  private async loadTables(): Promise<void> {
    for (const source of this.sources) {
      if (this.destroyed) return;
      await this.loadTable(source);
    }
  }

  /**
   * One table's read, issued once per tick: the drill-down's declared read at five rows into the page's own store, or nothing at all for a caller that screen refuses. An answer that lands after a
   * later read of the same table was issued, or after the page is gone, is dropped.
   */
  private async loadTable(source: TableSource): Promise<void> {
    if (!this.allowed(source)) return;
    const key = source.table.key;
    const issued = (this.issued.get(key) ?? 0) + 1;
    this.issued.set(key, issued);
    const read = createScreenRead(this.api, source.screen);
    const result = await read({ maxRows: TABLE_MAX_ROWS });
    if (this.destroyed || issued !== this.issued.get(key)) return;
    const faulted = new Set(this.faulted());
    if (result.kind === 'ok') {
      source.store.applyTick(result.rows, result.truncated, result.banner ?? '', new Date());
      faulted.delete(key);
    } else {
      faulted.add(key);
    }
    this.faulted.set(faulted);
    this.loaded.set(new Set(this.loaded()).add(key));
    this.generation.update((value) => value + 1);
  }

  private allowed(source: TableSource): boolean {
    this.generation();
    return this.navigation.screenVerdict(source.table.route).allowed;
  }

  private get boundHere(): boolean {
    this.generation();
    return this.view !== null && this.refresh.descriptor() === this.view.screen.descriptor;
  }

  private get hasLoaded(): boolean {
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
    return !this.hasLoaded && this.faultText === null;
  }

  protected get groupViews(): readonly GroupView[] {
    this.generation();
    if (this.view === null) return [];
    const row = this.row;
    const faultText = this.faultText;
    return MONITOR_GROUPS.map((group) => {
      const link = this.linkFor(group);
      return {
        key: group.key,
        heading: stringFor(group.headingKey),
        headingId: `ocu-monitor-heading-${group.key}`,
        link,
        meters: group.meters.map((meter) => monitorMeterView(meter, row, faultText)),
        table: this.tableFor(group),
      };
    });
  }

  /** The link a group with a table offers: the drill-down's screen at its route in this namespace, or gated with the failed pair where the caller is refused it. */
  private linkFor(group: MonitorGroup): DrillDownLink | null {
    const table = group.table;
    if (table === undefined) return null;
    const screen = screenForRoute(table.route);
    if (screen === null || screen.built !== true) return null;
    const opens = openableEntry(screen, (route) => this.navigation.screenVerdict(route));
    return {
      route: table.route,
      label: stringFor(screen.labelKey),
      href: opens === null ? '' : this.locationStrategy.prepareExternalUrl(withQuery(opens.route, this.router.url)),
      target: opens?.route ?? table.route,
      gated: opens === null,
      reason: opens === null ? formatRequires(STRINGS.privilegeRequiresResource, this.navigation.screenVerdict(screen.route).failedPair) : '',
      reasonId: `ocu-monitor-reason-${table.key}`,
    };
  }

  /** One group's table: gated, loading, refused, empty or its rows, never more than one of them at a time. */
  private tableFor(group: MonitorGroup): TableView {
    const table = group.table;
    if (table === undefined) return NO_TABLE;
    const source = this.sources.find((item) => item.table.key === table.key);
    if (source === undefined) return NO_TABLE;
    this.generation();
    const allowed = this.allowed(source);
    const loaded = this.loaded().has(table.key);
    const faulted = this.faulted().has(table.key);
    const data = source.store.data();
    const columns = table.fields
      .map((field) => source.screen.table?.columns.find((column) => column.field === field))
      .filter((column): column is NonNullable<typeof column> => column !== undefined);
    const readable = allowed;
    return {
      present: true,
      gated: !allowed,
      gatedText: allowed ? '' : formatRequires(STRINGS.privilegeRequiresResource, this.navigation.screenVerdict(table.route).failedPair),
      skeleton: readable && !loaded,
      refused: readable && loaded && faulted,
      empty: readable && loaded && !faulted && data.length === 0,
      emptyText: stringFor(source.screen.emptyStateKey),
      hasRows: readable && loaded && !faulted && data.length > 0,
      labels: columns.map((column) => ({ field: column.field, label: stringFor(column.labelKey) })),
      rows: data.slice(0, TABLE_MAX_ROWS).map((dataRow, index) => ({
        key: `${index}`,
        cells: columns.map((column) => ({
          field: column.field,
          text: cellView(fieldOf(dataRow, column.field), column.kind, column.emptyKey ?? '').text,
        })),
      })),
    };
  }

  /** Open a drill-down. A gated one goes nowhere; a modified click is left to the browser, whose new page reads the same screen. */
  protected onDrillDown(event: MouseEvent, link: DrillDownLink | null): void {
    if (link === null) return;
    if (link.gated) {
      event.preventDefault();
      return;
    }
    if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    void this.router.navigateByUrl(withQuery(link.target, this.router.url));
  }
}
