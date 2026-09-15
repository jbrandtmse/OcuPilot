import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { Router } from '@angular/router';

import { isBannerFault } from '../../core/fault';
import { NavigationService } from '../../core/navigation';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { STRINGS } from '../../core/strings';
import { ErrorLogDrill, type ErrorLogLevel } from './error-log.store';

/** One rendered table: its column headers and its rows of already-resolved cell text. */
interface GridView {
  readonly label: string;
  readonly headers: readonly string[];
  readonly template: string;
  readonly rows: readonly GridRow[];
}

/** One rendered row. `open` is the text the first cell links with, `''` for a row that opens nothing. */
interface GridRow {
  readonly key: string;
  readonly open: string;
  readonly cells: readonly string[];
}

/**
 * The page every `drill-down` archetype renders: the application error log, walked namespaces to
 * dates to errors to one error's captured variable table (AD-5, AD-48).
 *
 * **Drill level is store state, not a route.** `buildRoutes` emits one `<route>/:id` segment and no
 * more, and this screen has four levels; putting them in the URL would need a route grammar no
 * other screen has. The store holds the level, the namespace and the date, and it is root-provided
 * so a navigation across the `/:id` boundary cannot drop them.
 *
 * **Each level names its own scope in its empty state** -- the instance, then the namespace, then
 * the namespace and date -- because "no errors" means something different at each, and an
 * instance-wide sentence under a namespace the user drilled to would be wrong rather than merely
 * vague.
 *
 * **The detail renders in place, not in a dialog.** `Dialog` is 440px fixed, single-action and
 * bound to one shared overlay id; a variable table of several hundred rows fits none of that. The
 * level replaces the table and a Back control returns to the errors.
 *
 * **Nothing here reads `?ns=`.** The store's calls all carry `scope: null`, and the namespace they
 * send is the one the user drilled to (AD-48).
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-error-log-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<section class="ocu-list-page">
    <div class="ocu-drill-trail">
      @if (canGoBack) {
        <button type="button" class="ocu-button-text" data-ocu-drill="back" (click)="onBack()">
          {{ STRINGS.errorLogBack }}
        </button>
      }
      <span class="ocu-drill-scope" data-ocu-drill="scope">{{ scopeText }}</span>
    </div>

    @if (showRefusal) {
      <div class="ocu-data-table-refusal" role="alert" data-ocu-drill="refusal">
        <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
      </div>
    }

    @if (showSkeleton) {
      <div class="ocu-data-table-skeleton" aria-hidden="true">
        @for (bar of skeletonRows; track bar) {
          <div class="ocu-data-table-skeleton-row">
            <span class="ocu-skeleton-bar ocu-skeleton-bar-40"></span>
            <span class="ocu-skeleton-bar ocu-skeleton-bar-25"></span>
            <span class="ocu-skeleton-bar ocu-skeleton-bar-15"></span>
          </div>
        }
      </div>
    }

    @if (grid; as view) {
      <div class="ocu-data-table-frame" [attr.data-ocu-level]="level">
        @if (showEmpty) {
          <section class="ocu-empty-state ocu-data-table-empty" tabindex="-1">
            <p class="ocu-data-table-empty-title" data-ocu-drill="empty">{{ emptyTitle }}</p>
            <p class="ocu-data-table-empty-next">{{ STRINGS.tableReadOnlyEmptyNext }}</p>
          </section>
        }
        @if (showGrid) {
          <div
            class="ocu-data-table-grid"
            role="grid"
            tabindex="0"
            [attr.aria-label]="view.label"
            [attr.aria-rowcount]="view.rows.length + 1"
            [attr.aria-colcount]="view.headers.length"
          >
            <div class="ocu-data-table-head" role="rowgroup">
              <div
                class="ocu-data-table-row ocu-data-table-header-row"
                role="row"
                aria-rowindex="1"
                [style.grid-template-columns]="view.template"
              >
                @for (header of view.headers; track header) {
                  <div class="ocu-data-table-header-cell" role="columnheader">
                    <span class="ocu-data-table-header-label">{{ header }}</span>
                  </div>
                }
              </div>
            </div>
            <div class="ocu-data-table-viewport ocu-drill-viewport">
              <div class="ocu-data-table-body" role="rowgroup">
                @for (row of view.rows; track row.key; let index = $index) {
                  <div
                    class="ocu-data-table-row"
                    role="row"
                    [attr.data-ocu-row]="row.key"
                    [attr.aria-rowindex]="index + 2"
                    [style.grid-template-columns]="view.template"
                  >
                    @for (cell of row.cells; track $index; let column = $index) {
                      <div class="ocu-data-table-cell" role="gridcell">
                        @if (column === 0 && row.open !== '') {
                          <a
                            class="ocu-data-table-link"
                            href=""
                            [attr.data-ocu-open]="row.open"
                            (click)="onOpen($event, row.open)"
                            >{{ cell }}</a
                          >
                        } @else {
                          <span class="ocu-data-table-text">{{ cell }}</span>
                        }
                      </div>
                    }
                  </div>
                }
              </div>
            </div>
          </div>
        }
      </div>
      @if (showLevelCapNotice) {
        <p class="ocu-data-table-cap-notice" data-ocu-drill="cap">{{ STRINGS.errorLogLevelCapNotice }}</p>
      }
    }

    @if (detail; as captured) {
      <div class="ocu-drill-detail" data-ocu-level="detail">
        @for (section of captured; track section.label) {
          <section class="ocu-drill-section">
            <h2 class="ocu-drill-section-heading">{{ section.label }}</h2>
            <div
              class="ocu-data-table-frame ocu-drill-section-frame"
              role="grid"
              tabindex="0"
              [attr.aria-label]="section.label"
              [attr.aria-rowcount]="section.rows.length + 1"
              [attr.aria-colcount]="section.headers.length"
              [attr.data-ocu-section]="section.label"
            >
              <div class="ocu-data-table-head" role="rowgroup">
                <div
                  class="ocu-data-table-row ocu-data-table-header-row"
                  role="row"
                  aria-rowindex="1"
                  [style.grid-template-columns]="section.template"
                >
                  @for (header of section.headers; track header) {
                    <div class="ocu-data-table-header-cell" role="columnheader">
                      <span class="ocu-data-table-header-label">{{ header }}</span>
                    </div>
                  }
                </div>
              </div>
              <div class="ocu-data-table-viewport ocu-drill-viewport">
                <div class="ocu-data-table-body" role="rowgroup">
                  @for (row of section.rows; track row.key; let index = $index) {
                    <div
                      class="ocu-data-table-row"
                      role="row"
                      [attr.aria-rowindex]="index + 2"
                      [style.grid-template-columns]="section.template"
                    >
                      @for (cell of row.cells; track $index) {
                        <div class="ocu-data-table-cell" role="gridcell">
                          <span class="ocu-data-table-text">{{ cell }}</span>
                        </div>
                      }
                    </div>
                  }
                </div>
              </div>
            </div>
          </section>
        }
        @if (showDetailCapNotice) {
          <p class="ocu-data-table-cap-notice" data-ocu-drill="detail-cap">{{ STRINGS.errorLogDetailCapNotice }}</p>
        }
      </div>
    }
  </section>`,
})
export class ErrorLogPage {
  private readonly drill = inject(ErrorLogDrill);

  private readonly navigation = inject(NavigationService);

  private readonly router = inject(Router);

  private readonly actions = inject(ScreenActions);

  protected readonly STRINGS = STRINGS;

  /** The middle dot between the scope line's parts, as an escape (Rule 14). */
  private readonly separator = '\u00b7';

  /** Bumped by the store, so the tables re-render under `OnPush`. */
  private readonly generation = signal(0);

  /** The skeleton's bar count, as `DataTable` draws it. */
  protected readonly skeletonRows = [0, 1, 2, 3, 4, 5];

  constructor() {
    const stop = this.drill.subscribe(() => this.generation.update((value) => value + 1));
    // Manual Refresh (DW-260). This screen binds no `RefreshService` -- three levels with three
    // column sets cannot be one declared read -- so Refresh re-issues the level the user is on,
    // through the store's own `open*`, which is the same call the drill itself makes. It is
    // silent: the level's own rows are replaced when the answer lands, and nothing announces it.
    const screen = this.navigation.screenForUrl(this.router.url);
    const stopRefreshAction =
      screen === null
        ? null
        : this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
            void this.drill.reopen();
          });
    inject(DestroyRef).onDestroy(() => {
      stop();
      stopRefreshAction?.();
    });
    if (!this.drill.loaded() && !this.drill.loading()) void this.drill.openNamespaces();
  }

  protected get level(): ErrorLogLevel {
    this.generation();
    return this.drill.level();
  }

  protected get canGoBack(): boolean {
    return this.level !== 'namespaces';
  }

  /** The scope line above the table: the namespace, then the namespace and the date. */
  protected get scopeText(): string {
    this.generation();
    const namespace = this.drill.namespace();
    if (namespace === '') return '';
    const date = this.drill.date();
    if (date === '') return namespace;
    if (this.drill.level() === 'detail') {
      return namespace + ' ' + this.separator + ' ' + date + ' ' + this.separator + ' ' + this.drill.errorNumber();
    }
    return namespace + ' ' + this.separator + ' ' + date;
  }

  /**
   * Whether the level's read was refused, and so whether to say so.
   *
   * A 403 (`AUTH.NOPRIVILEGE`, the per-namespace gate) and a 404 (`LOG.NAMESPACE`, `LOG.DATE`,
   * `LOG.ENTRY`) both classify below the connectivity banner's threshold (`isBannerFault`), so the
   * shell draws nothing for them — which is why `DataTable` renders its own inline notice and why
   * this page must too. Without it a refusal is a blank frame, and the matrix's "a named refusal
   * the page turns into 'this date is gone', not an empty table" would be unmet at the only surface
   * that can meet it.
   */
  protected get showRefusal(): boolean {
    this.generation();
    const fault = this.drill.fault();
    return fault !== null && !isBannerFault(fault);
  }

  /** The first-load skeleton: drawn while a level is in flight and has no rows of its own yet. */
  protected get showSkeleton(): boolean {
    this.generation();
    if (!this.drill.loading()) return false;
    const view = this.grid;
    return view === null ? this.drill.detail() === null : view.rows.length === 0;
  }

  /** Whether a table is drawn at all: the detail level draws its own sections instead. */
  protected get showGrid(): boolean {
    const view = this.grid;
    return view !== null && view.rows.length > 0;
  }

  /**
   * The cap notice under a level whose read the port cut at the row cap (DW-293, AD-36).
   *
   * **Its sentence names no max-rows control**, because this screen has none: the drill sends no
   * `maxRows` and the port's own default is what bounds it. `tableRowCapNotice`, the data table's
   * own, tells the reader to "narrow the filter or raise the max rows" -- two controls the drill
   * does not carry -- which is why this is its own sentence rather than a reuse.
   *
   * Drawn only under a level that actually rendered rows: a refused or faulted level is neither
   * "empty" nor "complete", and a notice under its blank frame would claim it was cut.
   */
  protected get showLevelCapNotice(): boolean {
    this.generation();
    return this.showGrid && this.drill.truncated();
  }

  /**
   * The same notice for a captured detail the port cut (DW-293).
   *
   * The detail's flag is one boolean over three tables (`LogSourcePort.DetailPayload`), so the
   * sentence cannot name which section was cut and does not try to.
   */
  protected get showDetailCapNotice(): boolean {
    this.generation();
    return this.drill.detail()?.truncated === true;
  }

  protected get showEmpty(): boolean {
    this.generation();
    const view = this.grid;
    return view !== null && view.rows.length === 0 && this.drill.loaded();
  }

  /** The empty state's first line, naming this level's own scope. */
  protected get emptyTitle(): string {
    this.generation();
    const level = this.drill.level();
    if (level === 'namespaces') return STRINGS.errorLogEmptyInstance;
    if (level === 'dates') return STRINGS.errorLogEmptyNamespace.replace('<NAMESPACE>', this.drill.namespace());
    return STRINGS.errorLogEmptyDate
      .replace('<NAMESPACE>', this.drill.namespace())
      .replace('<DATE>', this.drill.date());
  }

  /** The table for the current level, or `null` on the detail level, which renders sections. */
  protected get grid(): GridView | null {
    this.generation();
    const level = this.drill.level();
    if (level === 'namespaces') {
      return {
        label: STRINGS.errorLogListLabel,
        headers: [STRINGS.headerNamespaceLabel],
        template: 'minmax(0, 1fr)',
        rows: this.drill.namespaces().map((row) => ({
          key: row.namespace,
          open: 'namespace:' + row.namespace,
          cells: [row.namespace],
        })),
      };
    }
    if (level === 'dates') {
      return {
        label: STRINGS.errorLogListLabel,
        headers: [STRINGS.errorLogColumnDate, STRINGS.errorLogColumnCount],
        template: 'minmax(0, 1fr) minmax(0, 1fr)',
        rows: this.drill.dates().map((row) => ({
          key: row.date,
          open: 'date:' + row.date,
          cells: [row.date, String(row.count)],
        })),
      };
    }
    if (level === 'list') {
      return {
        label: STRINGS.errorLogListLabel,
        headers: [
          STRINGS.errorLogColumnNumber,
          STRINGS.auditColumnTime,
          STRINGS.errorLogColumnText,
          STRINGS.processColumnRoutine,
          STRINGS.errorLogColumnLine,
          STRINGS.processColumnUser,
          STRINGS.processColumnPid,
        ],
        template:
          'minmax(0, 0.6fr) minmax(0, 0.6fr) minmax(0, 2fr) minmax(0, 1.4fr) minmax(0, 2fr) minmax(0, 0.8fr) minmax(0, 0.8fr)',
        rows: this.drill.errors().map((row) => ({
          key: String(row.errorNumber),
          open: 'error:' + row.errorNumber,
          cells: [
            String(row.errorNumber),
            row.time,
            row.errorText,
            row.routine,
            row.line,
            row.username,
            row.process,
          ],
        })),
      };
    }
    return null;
  }

  /** The detail level's three sections, or `null` at every other level. */
  protected get detail(): readonly GridView[] | null {
    this.generation();
    if (this.drill.level() !== 'detail') return null;
    const captured = this.drill.detail();
    if (captured === null) return null;
    return [
      {
        label: STRINGS.errorLogDetailExpressions,
        headers: [STRINGS.errorLogColumnExpression, STRINGS.errorLogColumnValue],
        template: 'minmax(0, 1fr) minmax(0, 2fr)',
        rows: captured.expressions.map((row, index) => ({
          key: String(index),
          open: '',
          cells: [row.expression, row.value],
        })),
      },
      {
        label: STRINGS.errorLogDetailStack,
        headers: [STRINGS.errorLogColumnLevel, STRINGS.errorLogColumnFrame],
        template: 'minmax(0, 0.4fr) minmax(0, 3fr)',
        rows: captured.stack.map((row, index) => ({
          key: String(index),
          open: '',
          cells: [row.level, row.detail],
        })),
      },
      {
        label: STRINGS.errorLogDetailVariables,
        headers: [STRINGS.errorLogColumnLevel, STRINGS.tableColumnName, STRINGS.errorLogColumnValue],
        template: 'minmax(0, 0.4fr) minmax(0, 1fr) minmax(0, 3fr)',
        rows: captured.variables.map((row, index) => ({
          key: String(index),
          open: '',
          cells: [row.level, row.name, row.value],
        })),
      },
    ];
  }

  protected onOpen(event: Event, open: string): void {
    event.preventDefault();
    const kind = open.slice(0, open.indexOf(':'));
    const value = open.slice(open.indexOf(':') + 1);
    if (kind === 'namespace') void this.drill.openDates(value);
    if (kind === 'date') void this.drill.openList(value);
    if (kind === 'error') void this.drill.openDetail(Number(value));
  }

  protected onBack(): void {
    void this.drill.back();
  }
}
