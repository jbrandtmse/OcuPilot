import { ChangeDetectionStrategy, Component, DestroyRef, afterNextRender, inject, signal } from '@angular/core';
import { ActivatedRoute, Router } from '@angular/router';

import { decodeEntityId, encodeEntityId } from '../../core/entity-id';
import { formatDeniedAction, screenForDescriptor, screenForUrl, withQuery } from '../../core/navigation';
import { STRINGS } from '../../core/strings';
import { formatCapNotice, formatRowCount } from '../../core/table-model';
import { Dialog } from '../../shell/dialog';
import {
  LedgerSearch,
  argumentsText,
  kindLabel,
  resultText,
  screenGroups,
  screenLabel,
  statusText,
  targetText,
  type LedgerField,
  type LedgerRow,
  type ScreenGroup,
} from './ledger.store';

/** The descriptor this page renders, and whose `/:id` route opens a row. */
export const AGENT_LEDGER = 'OcuPilot.Screen.Descriptor.AgentLedger';

/** The seven columns' tracks. */
const GRID_TEMPLATE =
  'minmax(0, 1.1fr) minmax(0, 0.8fr) minmax(0, 0.8fr) minmax(0, 1.4fr) minmax(0, 1fr) minmax(0, 1.4fr) minmax(0, 1fr)';

/** The placeholder the no-longer-present sentence leaves for the entity's name. */
const NAME_PLACEHOLDER = '<name>';

/** The refused criterion's sentence, which the field it names points at. */
const INVALID_ID = 'ocu-ledger-invalid';

/** How a row's kind and name are joined in its dialog's title. */
const TITLE_JOIN = ' \u00b7 ';

/** One row as the grid draws it: every cell already text. */
interface GridRow {
  readonly key: string;
  readonly cells: readonly string[];
}

/** The row a dialog is open over, as text. */
interface DetailView {
  readonly heading: string;
  readonly arguments: string;
  readonly result: string;
}

/**
 * The Agent audit ledger (Story 16.16, AD-46): the ledger's rows searched by user, screen and time,
 * and each row's arguments and result in a dialog.
 *
 * **It reads `GET /agent/ledger` and nothing else.** Every decision about which rows the caller
 * sees is the instance's (`Kernel.Audit.Ledger`); this page renders what came back. It declares no
 * read, so it has no data table, no CSV download and no read tool, and it publishes no screen
 * context: its descriptor declares no context field.
 *
 * **It searches once on open**, with the form as it stands -- empty the first time, so every user's
 * rows for an OcuPilot administrator and the caller's own for anyone else, over the last day -- and
 * the form then shows the criteria the instance applied. The search lives in `LedgerSearch`, which
 * is root-provided, so a row's dialog, which is the `/:id` route, keeps it.
 *
 * Everything shown is stored data rendered by interpolation, never as markup (AD-11 rule 4).
 * No control-flow condition holds a call expression, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-ledger-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<section class="ocu-list-page" [attr.aria-busy]="busy">
    <form class="ocu-criteria-form" (submit)="onSearch($event)">
      <div class="ocu-criteria-fields">
        <div class="ocu-criteria-field">
          <label class="ocu-criteria-label" for="ocu-ledger-user">{{ STRINGS.processColumnUser }}</label>
          <input
            class="ocu-criteria-input"
            type="text"
            id="ocu-ledger-user"
            [attr.aria-invalid]="userInvalid"
            [attr.aria-describedby]="userDescribed"
            maxlength="160"
            autocomplete="off"
            [value]="userValue"
            (input)="onField('user', $event)"
          />
        </div>
        <div class="ocu-criteria-field">
          <label class="ocu-criteria-label" for="ocu-ledger-route">{{ STRINGS.agentLedgerColumnScreen }}</label>
          <select
            class="ocu-criteria-select"
            id="ocu-ledger-route"
            [attr.aria-invalid]="routeInvalid"
            [attr.aria-describedby]="routeDescribed"
            (change)="onField('route', $event)"
          >
            <option value="" [selected]="routeValue === ''">{{ STRINGS.auditCriteriaAnyOption }}</option>
            @for (group of groups; track group.key) {
              <optgroup [label]="group.label">
                @for (option of group.screens; track option.route) {
                  <option [value]="option.route" [selected]="option.route === routeValue">{{ option.label }}</option>
                }
              </optgroup>
            }
          </select>
        </div>
        <div class="ocu-criteria-field">
          <label class="ocu-criteria-label" for="ocu-ledger-begin">{{ STRINGS.auditCriteriaBegin }}</label>
          <input
            class="ocu-criteria-input"
            type="text"
            id="ocu-ledger-begin"
            [attr.aria-invalid]="beginInvalid"
            [attr.aria-describedby]="beginDescribed"
            maxlength="50"
            autocomplete="off"
            [value]="beginValue"
            (input)="onField('begin', $event)"
          />
        </div>
        <div class="ocu-criteria-field">
          <label class="ocu-criteria-label" for="ocu-ledger-end">{{ STRINGS.auditCriteriaEnd }}</label>
          <input
            class="ocu-criteria-input"
            type="text"
            id="ocu-ledger-end"
            [attr.aria-invalid]="endInvalid"
            [attr.aria-describedby]="endDescribed"
            maxlength="50"
            autocomplete="off"
            [value]="endValue"
            (input)="onField('end', $event)"
          />
        </div>
      </div>
      <p class="ocu-criteria-hint">{{ STRINGS.auditCriteriaTimeHint }}</p>
      @if (invalidReason) {
        <p class="ocu-data-table-refusal" role="alert" id="ocu-ledger-invalid" data-ocu-ledger="invalid">
          <span class="ocu-data-table-refusal-message">{{ invalidReason }}</span>
        </p>
      }
      <div class="ocu-criteria-controls">
        <button type="submit" class="ocu-button-primary">{{ STRINGS.auditCriteriaSearch }}</button>
      </div>
    </form>

    @if (deniedSentence) {
      <div class="ocu-data-table-refusal" role="alert" data-ocu-ledger="denied">
        <span class="ocu-data-table-refusal-message">{{ deniedSentence }}</span>
      </div>
    }
    @if (refused) {
      <div class="ocu-data-table-refusal" role="alert" data-ocu-ledger="refused">
        <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
        <button type="button" class="ocu-button-text" (click)="onRetry()">{{ STRINGS.actionRetry }}</button>
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
    @if (showEmpty) {
      <section class="ocu-empty-state ocu-data-table-empty" tabindex="-1">
        <p class="ocu-data-table-empty-title" data-ocu-ledger="empty">{{ STRINGS.agentLedgerEmpty }}</p>
        <p class="ocu-data-table-empty-next">{{ STRINGS.tableReadOnlyEmptyNext }}</p>
      </section>
    }
    @if (showGrid) {
      <div class="ocu-data-table-frame">
        <div
          class="ocu-data-table-grid"
          role="grid"
          tabindex="0"
          [attr.aria-label]="STRINGS.agentLedgerLabel"
          [attr.aria-rowcount]="rows.length + 1"
          [attr.aria-colcount]="headers.length"
        >
          <div class="ocu-data-table-head" role="rowgroup">
            <div
              class="ocu-data-table-row ocu-data-table-header-row"
              role="row"
              aria-rowindex="1"
              [style.grid-template-columns]="template"
            >
              @for (header of headers; track header) {
                <div class="ocu-data-table-header-cell" role="columnheader">
                  <span class="ocu-data-table-header-label">{{ header }}</span>
                </div>
              }
            </div>
          </div>
          <div class="ocu-data-table-viewport ocu-drill-viewport">
            <div class="ocu-data-table-body" role="rowgroup">
              @for (row of rows; track row.key; let index = $index) {
                <div
                  class="ocu-data-table-row"
                  role="row"
                  [attr.data-ocu-row]="row.key"
                  [attr.aria-rowindex]="index + 2"
                  [style.grid-template-columns]="template"
                >
                  @for (cell of row.cells; track $index; let column = $index) {
                    <div class="ocu-data-table-cell" role="gridcell">
                      @if (column === 0) {
                        <a class="ocu-data-table-link" href="" [attr.data-ocu-open]="row.key" (click)="onOpen($event, row.key)">{{
                          cell
                        }}</a>
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
      </div>
    }
    @if (showFooter) {
      <div class="ocu-data-table-footer">
        <span class="ocu-data-table-count">{{ rowCountText }}</span>
        @if (capNotice) {
          <p class="ocu-data-table-cap-notice">{{ capNotice }}</p>
        }
        @if (withheldLine) {
          <p class="ocu-data-table-cap-notice" data-ocu-ledger="withheld">{{ withheldLine }}</p>
        }
        @if (droppedLine) {
          <p class="ocu-data-table-cap-notice" data-ocu-ledger="dropped">{{ droppedLine }}</p>
        }
      </div>
    }
    @if (dialogOpen) {
      <app-dialog [heading]="dialogHeading" [closeLabel]="STRINGS.auditDialogClose" (closed)="onCloseDetail()">
        @if (detail; as row) {
          <p class="ocu-dialog-field">{{ STRINGS.agentLedgerArguments }}</p>
          <pre class="ocu-dialog-payload" data-ocu-ledger="arguments">{{ row.arguments }}</pre>
          <p class="ocu-dialog-field">{{ STRINGS.taskHistoryColumnResult }}</p>
          <pre class="ocu-dialog-payload" data-ocu-ledger="result">{{ row.result }}</pre>
        } @else {
          <p class="ocu-dialog-value" data-ocu-ledger="gone">{{ goneSentence }}</p>
        }
      </app-dialog>
    }
  </section>`,
})
export class LedgerPage {
  private readonly search = inject(LedgerSearch);
  private readonly router = inject(Router);
  private readonly route = inject(ActivatedRoute);

  protected readonly STRINGS = STRINGS;

  protected readonly headers: readonly string[] = [
    STRINGS.auditColumnTime,
    STRINGS.processColumnUser,
    STRINGS.agentLedgerColumnKind,
    STRINGS.tableColumnName,
    STRINGS.agentLedgerColumnScreen,
    STRINGS.agentLedgerColumnTarget,
    STRINGS.taskHistoryColumnStatus,
  ];

  protected readonly template = GRID_TEMPLATE;

  protected readonly groups: readonly ScreenGroup[] = screenGroups();

  /** The skeleton's bar count, as `DataTable` draws it. */
  protected readonly skeletonRows = [0, 1, 2, 3, 4, 5];

  private readonly screenRoute = screenForDescriptor(AGENT_LEDGER)?.route ?? '';

  /** Bumped by the store, so the page re-renders under `OnPush`. */
  private readonly generation = signal(0);

  /** The id segment the route carries, decoded once (AD-13). */
  private readonly entityId = signal('');

  constructor() {
    const stopSearch = this.search.subscribe(() => this.generation.update((value) => value + 1));
    const stopParams = this.route.paramMap.subscribe((params) => {
      const raw = params.get('id');
      this.entityId.set(raw === null ? '' : decodeEntityId(raw));
    });
    if (this.search.needsRead()) void this.search.search();

    // A closing dialog asks the next page instance to put focus back on the grid, because the
    // route change destroys the grid the row was opened from.
    afterNextRender(() => {
      if (!this.search.takeGridFocusRequest()) return;
      document.querySelector<HTMLElement>('app-ledger-page [role="grid"]')?.focus();
    });

    inject(DestroyRef).onDestroy(() => {
      stopSearch();
      stopParams.unsubscribe();
      // The dialog's route is a second route over this screen, so this component is destroyed on
      // every open and close; only leaving the screen makes the next visit search again.
      if (screenForUrl(this.router.url)?.descriptor !== AGENT_LEDGER) this.search.leave();
    });
  }

  protected get busy(): boolean {
    this.generation();
    return this.search.phase() === 'loading';
  }

  protected get userValue(): string {
    this.generation();
    return this.search.value('user');
  }

  protected get routeValue(): string {
    this.generation();
    return this.search.value('route');
  }

  protected get beginValue(): string {
    this.generation();
    return this.search.value('begin');
  }

  protected get endValue(): string {
    this.generation();
    return this.search.value('end');
  }

  /** The instance's reason for a refused criterion, or `''`. */
  protected get invalidReason(): string {
    this.generation();
    return this.search.phase() === 'invalid' ? this.search.reason() : '';
  }

  protected get userInvalid(): 'true' | null {
    return this.invalidMark('user');
  }

  protected get routeInvalid(): 'true' | null {
    return this.invalidMark('route');
  }

  protected get beginInvalid(): 'true' | null {
    return this.invalidMark('begin');
  }

  protected get endInvalid(): 'true' | null {
    return this.invalidMark('end');
  }

  protected get userDescribed(): string | null {
    return this.invalidMark('user') === null ? null : INVALID_ID;
  }

  protected get routeDescribed(): string | null {
    return this.invalidMark('route') === null ? null : INVALID_ID;
  }

  protected get beginDescribed(): string | null {
    return this.invalidMark('begin') === null ? null : INVALID_ID;
  }

  protected get endDescribed(): string | null {
    return this.invalidMark('end') === null ? null : INVALID_ID;
  }

  /** The request-refused sentence for another user's rows asked for without the pair, or `''`. */
  protected get deniedSentence(): string {
    this.generation();
    if (this.search.phase() !== 'denied' || this.search.failedPair() === '') return '';
    return formatDeniedAction(STRINGS.privilegeDeniedAction, this.search.failedPair(), STRINGS.agentLedgerDeniedAction);
  }

  protected get refused(): boolean {
    this.generation();
    const phase = this.search.phase();
    return phase === 'refused' || (phase === 'denied' && this.search.failedPair() === '');
  }

  protected get showSkeleton(): boolean {
    this.generation();
    return this.search.phase() === 'loading' && this.search.view() === null;
  }

  protected get showEmpty(): boolean {
    this.generation();
    return this.search.phase() === 'ready' && (this.search.view()?.rows.length ?? 0) === 0;
  }

  protected get showGrid(): boolean {
    this.generation();
    return (this.search.view()?.rows.length ?? 0) > 0 && this.search.phase() !== 'denied';
  }

  protected get showFooter(): boolean {
    this.generation();
    return this.search.view() !== null;
  }

  /** Each row as the grid draws it, newest first as the instance answered. */
  protected get rows(): readonly GridRow[] {
    this.generation();
    return (this.search.view()?.rows ?? []).map((row) => ({
      key: row.ledgerId,
      cells: [
        row.time,
        row.user,
        kindLabel(row.kind),
        row.name,
        screenLabel(row.route),
        targetText(row.target),
        statusText(row),
      ],
    }));
  }

  protected get rowCountText(): string {
    this.generation();
    return formatRowCount(STRINGS.tableRowCount, this.search.view()?.rows.length ?? 0);
  }

  protected get capNotice(): string {
    this.generation();
    const view = this.search.view();
    return view !== null && view.truncated ? formatCapNotice(STRINGS.tableRowCapNotice, view.rows.length) : '';
  }

  protected get withheldLine(): string {
    this.generation();
    const withheld = this.search.view()?.rowsWithheld ?? 0;
    return withheld > 0 ? formatRowCount(STRINGS.agentLedgerWithheld, withheld) : '';
  }

  protected get droppedLine(): string {
    this.generation();
    const dropped = this.search.view()?.rowsDropped ?? 0;
    return dropped > 0 ? formatRowCount(STRINGS.agentLedgerDropped, dropped) : '';
  }

  /** Whether the id route is open: once the search has answered, with the row or the gone sentence. */
  protected get dialogOpen(): boolean {
    this.generation();
    return this.entityId() !== '' && this.search.phase() === 'ready';
  }

  private get openRow(): LedgerRow | null {
    this.generation();
    const id = this.entityId();
    if (id === '') return null;
    return this.search.view()?.rows.find((row) => row.ledgerId === id) ?? null;
  }

  protected get detail(): DetailView | null {
    const row = this.openRow;
    if (row === null) return null;
    return { heading: this.headingFor(row), arguments: argumentsText(row), result: resultText(row) };
  }

  protected get dialogHeading(): string {
    const row = this.openRow;
    return row === null ? STRINGS.agentLedgerLabel : this.headingFor(row);
  }

  /** The no-longer-present sentence for a row the search did not answer. */
  protected get goneSentence(): string {
    return STRINGS.faultAbsentEntity.split(NAME_PLACEHOLDER).join(this.entityId());
  }

  protected onField(field: LedgerField, event: Event): void {
    this.search.setValue(field, (event.target as HTMLInputElement | HTMLSelectElement).value);
  }

  protected onSearch(event: Event): void {
    event.preventDefault();
    this.search.noteSearched();
    void this.search.search();
  }

  protected onRetry(): void {
    void this.search.search();
  }

  protected onOpen(event: Event, key: string): void {
    event.preventDefault();
    void this.router.navigateByUrl(withQuery(`${this.screenRoute}/${encodeEntityId(key)}`, this.router.url));
  }

  /** Close the dialog by returning to the bare route, handing grid focus to the next instance. */
  protected onCloseDetail(): void {
    this.search.requestGridFocus();
    void this.router.navigateByUrl(withQuery(this.screenRoute, this.router.url));
  }

  /** `'true'` on the field a refused criterion names, which the refusal then describes. */
  private invalidMark(field: LedgerField): 'true' | null {
    this.generation();
    return this.search.phase() === 'invalid' && this.search.invalidField() === field ? 'true' : null;
  }

  private headingFor(row: LedgerRow): string {
    return `${kindLabel(row.kind)}${TITLE_JOIN}${row.name}`;
  }
}
