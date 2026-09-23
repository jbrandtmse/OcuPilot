import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  Injector,
  afterNextRender,
  inject,
  signal,
  viewChild,
} from '@angular/core';

import { Router } from '@angular/router';

import { ChangeBus } from '../../core/change-bus';
import { isBannerFault } from '../../core/fault';
import { formatDeniedAction, NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { REFRESH_ACTION_ID, ScreenActions, actionLabel } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { selfProtectionReason } from '../../core/self-protection';
import { STRINGS } from '../../core/strings';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { TypedNameDialog } from '../../shell/typed-name-dialog';
import { ERROR_LOG_ENTITY_TYPE, ErrorLogDrill, type ErrorLogLevel } from './error-log.store';

/** The descriptor this page renders, whose store the command bar and the row-action handler read. */
export const LOG_ERROR_LIST = 'OcuPilot.Screen.Descriptor.LogErrorList';

/** The track the row menu's trigger cell takes, as `DataTable` sizes it. */
const TRIGGER_TRACK = 'calc(28px + 2 * var(--ocu-space-3))';

/** The overlay id the row menu registers, so Escape closes it before anything beneath it. */
const MENU_OVERLAY_ID = 'ocu-error-log-menu';

/** One row-menu entry: a declared row action with a registered handler. */
interface MenuItem {
  readonly id: string;
  readonly label: string;
  readonly reason: string;
  readonly name: string;
  readonly ariaDisabled: 'true' | null;
}

/** One rendered table: its column headers and its rows of already-resolved cell text. */
interface GridView {
  readonly label: string;
  readonly headers: readonly string[];
  readonly template: string;
  readonly rows: readonly GridRow[];
}

/**
 * One rendered row. `open` is the text the first cell links with, `''` for a row that opens nothing.
 * `select` is the composite id the row is selected and deleted by (`ErrorLogDrill.selectionKey`),
 * `''` for a row that takes no selection.
 */
interface GridRow {
  readonly key: string;
  readonly open: string;
  readonly cells: readonly string[];
  readonly select: string;
  readonly selected: boolean;
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
 * **It hosts its own row actions** (Story 7.10, AD-53), as Process details does. Each level's rows
 * carry the row menu `DataTable` draws, and opening it or clicking a row outside its link selects
 * the row; the detail level selects its own error after each load. The selection is the row's
 * composite id -- the level is the delete's scope -- and it is written into this screen's
 * `ScreenStore`, which is what the command bar and the shell's `ScreenActionHandler` read. The
 * typed-name dialog renders here while the pending action is this screen's, and a refused action's
 * sentence renders as `role="alert"`.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-error-log-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [TypedNameDialog],
  template: `<section class="ocu-list-page">
    @if (actionRefusal) {
      <p class="ocu-banner ocu-list-page-banner ocu-banner-warning" role="alert" data-ocu-drill="action-refusal">
        <span class="ocu-banner-glyph" aria-hidden="true">{{ bannerGlyph }}</span>
        <span class="ocu-banner-message">{{ actionRefusal }}</span>
      </p>
    }
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
        <span class="ocu-data-table-refusal-message">{{ refusalMessage }}</span>
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
            #grid
            class="ocu-data-table-grid"
            role="grid"
            tabindex="0"
            [attr.aria-label]="view.label"
            [attr.aria-rowcount]="view.rows.length + 1"
            [attr.aria-colcount]="view.headers.length + (hasRowActions ? 1 : 0)"
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
                @if (hasRowActions) {
                  <div class="ocu-data-table-header-cell" role="columnheader">
                    <span class="ocu-data-table-header-label ocu-data-table-hidden-label">{{
                      STRINGS.commandBoxGroupActions
                    }}</span>
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
                    [class.ocu-data-table-row-selected]="row.selected"
                    [attr.aria-selected]="row.select === '' ? null : row.selected"
                    [attr.data-ocu-row]="row.key"
                    [attr.aria-rowindex]="index + 2"
                    [style.grid-template-columns]="view.template"
                    (click)="onRowClick($event, row)"
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
                    @if (hasRowActions) {
                      <div class="ocu-data-table-cell ocu-data-table-cell-trigger" role="gridcell">
                        <button
                          type="button"
                          class="ocu-data-table-trigger"
                          aria-haspopup="menu"
                          data-ocu-drill="trigger"
                          [attr.aria-expanded]="menuKey === row.select"
                          [attr.aria-controls]="menuKey === row.select ? menuId : null"
                          [attr.aria-label]="STRINGS.commandBoxGroupActions"
                          (click)="onTriggerClick($event, row)"
                        >
                          <span aria-hidden="true">{{ menuGlyph }}</span>
                        </button>
                      </div>
                    }
                  </div>
                }
              </div>
            </div>
          </div>
        }
        @if (menuOpen) {
          <div
            #menu
            class="ocu-data-table-menu"
            role="menu"
            [id]="menuId"
            [attr.aria-label]="STRINGS.commandBoxGroupActions"
            [style.top.px]="menuTopPx"
            (keydown)="onMenuKeydown($event)"
            (mousedown)="onMenuMouseDown($event)"
            (focusout)="onMenuFocusOut($event)"
          >
            @for (item of menuItems; track item.id) {
              <button
                type="button"
                class="ocu-data-table-menu-item"
                role="menuitem"
                tabindex="-1"
                [attr.aria-disabled]="item.ariaDisabled"
                [attr.aria-label]="item.name"
                (click)="onMenuItem(item)"
              >
                <span class="ocu-data-table-menu-label">{{ item.label }}</span>
                @if (item.reason) {
                  <span class="ocu-data-table-menu-reason">{{ item.reason }}</span>
                }
              </button>
            }
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
    @if (pendingTypedName; as pending) {
      <app-typed-name-dialog
        [verb]="pending.verb"
        [target]="pending.name"
        [consequence]="pending.consequence"
        [advisory]="pending.advisory"
        [flagLabel]="pending.flagLabel"
        (confirmed)="onConfirmDestructive($event)"
        (cancelled)="onCancelDestructive()"
      />
    }
  </section>`,
})
export class ErrorLogPage {
  private readonly drill = inject(ErrorLogDrill);

  private readonly navigation = inject(NavigationService);

  private readonly router = inject(Router);

  private readonly actions = inject(ScreenActions);

  private readonly overlays = inject(OverlayStack);

  private readonly injector = inject(Injector);

  /** Constructed for its own sake, as `ListPage` constructs it: its constructor registers the row actions. */
  private readonly screenActions = inject(ScreenActionHandler);

  /** This screen's store: the selection the command bar and the handler act on, and the refusal. */
  private readonly store: ScreenStore = inject(ScreenStores).for(
    LOG_ERROR_LIST,
    SCREENS.find((screen) => screen.descriptor === LOG_ERROR_LIST)?.refreshRates ?? []
  );

  protected readonly STRINGS = STRINGS;

  /** The middle dot between the scope line's parts, as an escape (Rule 14). */
  private readonly separator = '\u00b7';

  /** The vertical ellipsis the row menu's trigger draws, as an escape (Rule 14). */
  protected readonly menuGlyph = '\u22ee';

  /** The banner's warning triangle, as its escape (Rule 14). */
  protected readonly bannerGlyph = '\u26A0';

  protected readonly menuId = MENU_OVERLAY_ID;

  private readonly gridElement = viewChild<ElementRef<HTMLElement>>('grid');

  private readonly menuElement = viewChild<ElementRef<HTMLElement>>('menu');

  /** The composite id whose row menu is open, `''` when none is. */
  private readonly menuKeyValue = signal('');

  private readonly menuTop = signal(0);

  /** Bumped by the store, so the tables re-render under `OnPush`. */
  private readonly generation = signal(0);

  /** The skeleton's bar count, as `DataTable` draws it. */
  protected readonly skeletonRows = [0, 1, 2, 3, 4, 5];

  constructor() {
    const stop = this.drill.subscribe(() => {
      this.syncSelection();
      this.generation.update((value) => value + 1);
    });
    const stopStore = this.store.subscribe(() => this.generation.update((value) => value + 1));
    this.syncSelection();
    // Manual Refresh (DW-260). This screen binds no `RefreshService` -- three levels with three
    // column sets cannot be one declared read -- so Refresh re-issues the level the user is on
    // through `reopen()`, which sends the read directly and NOT through `open*`: those drop the
    // level's rows first, and a blanked table draws the first-load skeleton over itself, which is
    // the one thing "Refresh is silent" forbids. The rows stand until the answer replaces them.
    const screen = this.navigation.screenForUrl(this.router.url);
    const stopRefreshAction =
      screen === null
        ? null
        : this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
            void this.drill.reopen();
          });
    // AD-14. A confirmed delete against this log publishes one `changed` event, and a screen
    // showing that entity type re-fetches in place rather than patching its own rows. This screen
    // binds no `RefreshService` -- three levels are three column sets -- so it holds its own
    // subscription rather than a refresh binding, which is the same reason `reopen()` exists.
    //
    // Optional, because the bus is provided at the application root and this page is mounted
    // without it in its own component spec; a page with no bus behaves exactly as it did before
    // the delete tool shipped.
    const bus = inject(ChangeBus, { optional: true });
    const stopBus =
      bus === null
        ? null
        : bus.subscribe((event) => {
            if (event.kind !== 'changed') return;
            if (event.type !== ERROR_LOG_ENTITY_TYPE) return;
            if (event.action !== 'deleted') return;
            void this.drill.applyDeleted(event.id);
          });
    inject(DestroyRef).onDestroy(() => {
      stop();
      stopStore();
      stopBus?.();
      stopRefreshAction?.();
      this.overlays.remove(MENU_OVERLAY_ID);
      // The handler is the app's, so a dialog left open would outlive the page it was opened on.
      if (this.screenActions.pending()?.descriptor === LOG_ERROR_LIST) this.screenActions.cancelPending();
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
   * this page must too. Without it a refusal is a blank frame rather than an answer.
   *
   * Which sentence the notice carries is `refusalMessage`'s; this decides only that there is one.
   */
  protected get showRefusal(): boolean {
    this.generation();
    const fault = this.drill.fault();
    return fault !== null && !isBannerFault(fault);
  }

  /**
   * The sentence the refusal notice carries, chosen by the envelope's machine `code` (AD-39) —
   * never by the server's human `reason`, which is rewordable.
   *
   * Four refusals are named: the three levels the log no longer carries (`LOG.NAMESPACE`,
   * `LOG.DATE`, `LOG.ENTRY`), each with its own published sentence, and a privilege denial
   * (`AUTH.NOPRIVILEGE`) that names a pair, rendered through the published
   * `You need <resource> to <action>.` pattern (AD-8).
   *
   * **`connectivityRequestRefused` is the default arm, not an error path.** Every other code —
   * an `AUTH.NOPRIVILEGE` whose envelope named no pair included, since a resolved sentence with
   * an empty resource slot says less than the generic one — falls through to it by design.
   */
  protected get refusalMessage(): string {
    this.generation();
    const code = this.drill.fault()?.code ?? null;
    if (code === 'LOG.NAMESPACE') return STRINGS.errorLogRefusedNamespace;
    if (code === 'LOG.DATE') return STRINGS.errorLogRefusedDate;
    if (code === 'LOG.ENTRY') return STRINGS.errorLogRefusedEntry;
    const pair = this.drill.failedPair();
    if (code === 'AUTH.NOPRIVILEGE' && pair !== '') {
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.errorLogRefusedAction);
    }
    return STRINGS.connectivityRequestRefused;
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
        template: this.withTrigger('minmax(0, 1fr)'),
        rows: this.drill.namespaces().map((row) => this.gridRow(row.namespace, 'namespace:' + row.namespace, [row.namespace])),
      };
    }
    if (level === 'dates') {
      return {
        label: STRINGS.errorLogListLabel,
        headers: [STRINGS.errorLogColumnDate, STRINGS.errorLogColumnCount],
        template: this.withTrigger('minmax(0, 1fr) minmax(0, 1fr)'),
        rows: this.drill.dates().map((row) => this.gridRow(row.date, 'date:' + row.date, [row.date, String(row.count)])),
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
        template: this.withTrigger(
          'minmax(0, 0.6fr) minmax(0, 0.6fr) minmax(0, 2fr) minmax(0, 1.4fr) minmax(0, 2fr) minmax(0, 0.8fr) minmax(0, 0.8fr)'
        ),
        rows: this.drill.errors().map((row) =>
          this.gridRow(String(row.errorNumber), 'error:' + row.errorNumber, [
            String(row.errorNumber),
            row.time,
            row.errorText,
            row.routine,
            row.line,
            row.username,
            row.process,
          ])
        ),
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
          select: '',
          selected: false,
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
          select: '',
          selected: false,
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
          select: '',
          selected: false,
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
    this.closeMenu(false);
    void this.drill.back();
  }

  // --- Row actions (Story 7.10) ---------------------------------------------------------------------

  /**
   * The row menu's entries, as `DataTable` resolves its own: every declared row action with a
   * registered handler, each with its label and, where the selected row refuses it, the reason.
   */
  protected get menuItems(): readonly MenuItem[] {
    this.generation();
    const screen = SCREENS.find((entry) => entry.descriptor === LOG_ERROR_LIST);
    if (screen === undefined) return [];
    const selected = this.drill.selected();
    return screen.rowActions
      .filter((action) => action.id !== '')
      .filter((action) => this.actions.has(LOG_ERROR_LIST, action.id))
      .map((action) => {
        const reason = selfProtectionReason(action.selfProtection, selected, '');
        const label = actionLabel(LOG_ERROR_LIST, action.id);
        return {
          id: action.id,
          label,
          reason,
          name: reason === '' ? label : `${label} ${reason}`,
          ariaDisabled: reason === '' ? null : 'true',
        };
      });
  }

  /** Whether the table levels draw the row menu: only when an action can run from it. */
  protected get hasRowActions(): boolean {
    return this.menuItems.length > 0;
  }

  protected get menuOpen(): boolean {
    return this.menuKeyValue() !== '';
  }

  protected get menuKey(): string {
    return this.menuKeyValue();
  }

  protected get menuTopPx(): number {
    return this.menuTop();
  }

  /** The typed-name dialog, while the pending action is this screen's, or `null`. */
  protected get pendingTypedName(): ReturnType<ScreenActionHandler['pending']> {
    this.generation();
    const pending = this.screenActions.pending();
    return pending !== null && pending.kind === 'typed-name' && pending.descriptor === LOG_ERROR_LIST ? pending : null;
  }

  /** The sentence the last refused action answered with, or `''` (AD-39). */
  protected get actionRefusal(): string {
    this.generation();
    return this.store.refusal();
  }

  /** A click on a row outside its link selects it; the link opens the next level instead. */
  protected onRowClick(event: MouseEvent, row: GridRow): void {
    if (row.select === '') return;
    const target = event.target;
    if (target instanceof Element && target.closest('a, button') !== null) return;
    this.drill.select(row.select);
  }

  protected onTriggerClick(event: MouseEvent, row: GridRow): void {
    event.stopPropagation();
    this.drill.select(row.select);
    this.menuKeyValue.set(row.select);
    this.overlays.push(MENU_OVERLAY_ID, () => this.closeMenu(true));
    afterNextRender(
      () => {
        this.placeMenu(row.key);
        this.menuButtons()[0]?.focus();
      },
      { injector: this.injector }
    );
  }

  protected onMenuKeydown(event: KeyboardEvent): void {
    const items = this.menuButtons();
    if (items.length === 0) return;
    const at = items.indexOf(document.activeElement as HTMLElement);
    let next = -1;
    if (event.key === 'ArrowDown') next = (at + 1) % items.length;
    else if (event.key === 'ArrowUp') next = (at - 1 + items.length) % items.length;
    else if (event.key === 'Home') next = 0;
    else if (event.key === 'End') next = items.length - 1;
    if (next < 0) return;
    event.preventDefault();
    items[next].focus();
  }

  /** Keep focus in the menu while an item is pressed, as `DataTable` does. */
  protected onMenuMouseDown(event: MouseEvent): void {
    event.preventDefault();
  }

  protected onMenuFocusOut(event: FocusEvent): void {
    const menu = this.menuElement()?.nativeElement;
    const next = event.relatedTarget;
    if (menu === undefined || (next instanceof Node && menu.contains(next))) return;
    this.closeMenu(false);
  }

  /** Run one menu entry; a refused one is `aria-disabled`, so the click arrives and is refused here. */
  protected onMenuItem(item: MenuItem): void {
    this.closeMenu(true);
    if (item.reason !== '') return;
    this.actions.run(LOG_ERROR_LIST, item.id);
  }

  /** The typed name matched: the handler sends the delete it was standing in front of. */
  protected onConfirmDestructive(flag = false): void {
    this.gridElement()?.nativeElement.focus();
    this.screenActions.confirmPending(flag);
  }

  /** Escape, Cancel or the scrim: nothing was sent. */
  protected onCancelDestructive(): void {
    this.gridElement()?.nativeElement.focus();
    this.screenActions.cancelPending();
  }

  /** One table row: its cells, its link, and the composite id it is selected by. */
  private gridRow(key: string, open: string, cells: readonly string[]): GridRow {
    const select = this.drill.selectionKey(key);
    return { key, open, cells, select, selected: select === this.drill.selected() };
  }

  private withTrigger(template: string): string {
    return this.hasRowActions ? `${template} ${TRIGGER_TRACK}` : template;
  }

  /**
   * Write the drill's selection into this screen's store, which is what the command bar and the
   * handler read. On the detail level the selection is the error on screen, once it has loaded.
   */
  private syncSelection(): void {
    if (this.drill.level() === 'detail' && this.drill.detail() !== null) {
      this.drill.select(this.drill.selectionKey(''));
    }
    const key = this.drill.selected();
    const held = this.store.selection();
    if (key === '') {
      if (held.length > 0) this.store.setSelection([]);
      if (this.menuOpen) this.closeMenu(false);
      return;
    }
    if (held.length === 1 && held[0] === key) return;
    this.store.setSelection([key]);
  }

  /** Put the menu under its row, or above it where the frame has no room below, as `DataTable` does. */
  private placeMenu(rowKey: string): void {
    const menu = this.menuElement()?.nativeElement;
    const grid = this.gridElement()?.nativeElement;
    const frame = grid?.closest('.ocu-data-table-frame');
    if (menu === undefined || grid === undefined || !(frame instanceof HTMLElement)) return;
    const row = Array.from(grid.querySelectorAll<HTMLElement>('[data-ocu-row]')).find(
      (element) => element.getAttribute('data-ocu-row') === rowKey
    );
    if (row === undefined) return;
    const frameTop = frame.getBoundingClientRect().top;
    const rowRect = row.getBoundingClientRect();
    const rowTop = rowRect.top - frameTop;
    const below = rowRect.bottom - frameTop;
    const height = menu.getBoundingClientRect().height;
    this.menuTop.set(below + height <= frame.clientHeight ? below : Math.max(0, rowTop - height));
  }

  private closeMenu(returnFocus: boolean): void {
    if (this.menuKeyValue() === '') return;
    this.menuKeyValue.set('');
    this.overlays.remove(MENU_OVERLAY_ID);
    if (returnFocus) this.gridElement()?.nativeElement.focus();
  }

  private menuButtons(): HTMLElement[] {
    const menu = this.menuElement()?.nativeElement;
    return menu === undefined ? [] : Array.from(menu.querySelectorAll<HTMLElement>('[role="menuitem"]'));
  }
}
