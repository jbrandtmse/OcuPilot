import { ChangeDetectionStrategy, Component, input } from '@angular/core';

import { mdxStatusLineFor, type MdxRow } from '../../core/mdx-answer';
import type { SqlRows } from '../../core/sql-answer';
import { STRINGS } from '../../core/strings';
import { ResultGrid } from '../../shell/result-grid';
import { WarningDialog } from '../../shell/warning-dialog';
import type { MdxQueryDeps, MdxQueryState } from './mdx-query.store';

/** One row of the cells grid as drawn. */
interface RowView {
  readonly key: number;
  readonly label: string;
  readonly cells: readonly string[];
}

/**
 * What an MDX run answered, drawn for MDX query (Story 20.33) and for a saved pivot's Definition tab (Story 24.14): the status line, the vendor's
 * error as text, a grid of row labels and cells whose value cells drill through to the cube's listing for that cell, the listing under a
 * Drill-through heading, and the confirmation a statement that runs server-side code or SQL asks first (AD-65).
 *
 * The state and its deps are the page's own (`MdxQueryState`); the page bumps `version` whenever the state changes, so this view re-renders under
 * `OnPush`. **Everything shown is text** (AD-11): a label, a cell, a listing and the vendor's error are interpolated, never markup.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-mdx-run-view',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ResultGrid, WarningDialog],
  template: `<p class="ocu-explorer-status" role="status" data-ocu-mdx="status">{{ statusLine }}</p>
    @if (hasMessage) {
      <pre class="ocu-source-text ocu-sql-query-message" tabindex="0" data-ocu-mdx="error" [attr.aria-label]="STRINGS.analyticsMdxErrorLine">{{ message }}</pre>
    }
    @if (hasGrid) {
      <div class="ocu-data-table-frame">
        <div
          class="ocu-data-table-grid ocu-sql-query-results"
          role="table"
          data-ocu-mdx="grid"
          [attr.aria-label]="STRINGS.analyticsMdxQueryLabel"
          [attr.aria-rowcount]="gridRowCount"
          [attr.aria-colcount]="gridColumnCount"
        >
          <div class="ocu-data-table-head" role="rowgroup">
            <div class="ocu-data-table-row ocu-data-table-header-row" role="row" aria-rowindex="1" [style.grid-template-columns]="gridTemplate">
              @if (hasRowHeader) {
                <div class="ocu-data-table-header-cell" role="columnheader">
                  <span class="ocu-data-table-header-label" data-ocu-mdx="row-header-column">{{ STRINGS.analyticsMdxRowHeader }}</span>
                </div>
              }
              @for (column of gridColumns; track $index) {
                <div class="ocu-data-table-header-cell" role="columnheader">
                  <span class="ocu-data-table-header-label">{{ column }}</span>
                </div>
              }
            </div>
          </div>
          <div class="ocu-data-table-viewport">
            <div class="ocu-data-table-body" role="rowgroup">
              @for (row of gridRows; track row.key) {
                <div class="ocu-data-table-row" role="row" [attr.aria-rowindex]="row.key + 2" [style.grid-template-columns]="gridTemplate">
                  @if (hasRowHeader) {
                    <div class="ocu-data-table-cell" role="rowheader">
                      <span class="ocu-data-table-text ocu-sql-query-cell" data-ocu-mdx="row-header">{{ row.label }}</span>
                    </div>
                  }
                  @for (cell of row.cells; track $index) {
                    <div class="ocu-data-table-cell" role="cell">
                      <button
                        type="button"
                        class="ocu-mdx-drill"
                        data-ocu-mdx="drill-cell"
                        [attr.aria-label]="drillLabel(row.label, $index, cell)"
                        [attr.aria-disabled]="drillBlocked"
                        (click)="onDrill(row.key + 1, $index + 1)"
                      >{{ cell }}</button>
                    </div>
                  }
                </div>
              }
            </div>
          </div>
        </div>
      </div>
    }
    @if (listing; as shown) {
      <div class="ocu-mdx-query-listing" data-ocu-mdx="listing">
        <h2 class="ocu-details-heading">{{ STRINGS.analyticsMdxDrillHeading }}</h2>
        @if (hasGrid) {
          <p class="ocu-explorer-status" data-ocu-mdx="listing-status">{{ listingLine }}</p>
        }
        <app-result-grid [answer]="shown" [label]="STRINGS.analyticsMdxDrillHeading" [slot]="listingSlot" />
      </div>
    }
    @if (confirming) {
      <app-warning-dialog
        [verb]="STRINGS.analyticsMdxConfirmTitle"
        [consequence]="STRINGS.analyticsMdxConfirmConsequence"
        (confirmed)="onProceed()"
        (cancelled)="onCancel()"
      />
    }`,
})
export class MdxRunView {
  /** The run's state and the deps its calls are sent with, both the hosting page's. */
  readonly state = input.required<MdxQueryState>();

  readonly deps = input.required<MdxQueryDeps>();

  /** Bumped by the page whenever the state changes, so the view re-renders under `OnPush`. */
  readonly version = input<number>(0);

  protected readonly STRINGS = STRINGS;

  /** The prefix the drill-through listing's grid carries on its `data-ocu-sql` values. */
  protected readonly listingSlot = 'listing-';

  protected get statusLine(): string {
    this.version();
    return this.state().statusLine();
  }

  /** The vendor's error text, shown as text below the status line. */
  protected get message(): string {
    this.version();
    return this.state().message();
  }

  protected get hasMessage(): boolean {
    return this.message !== '';
  }

  protected get hasGrid(): boolean {
    this.version();
    return this.state().cells() !== null;
  }

  protected get gridColumns(): readonly string[] {
    this.version();
    return this.state().cells()?.columns ?? [];
  }

  protected get gridRows(): readonly RowView[] {
    this.version();
    return (this.state().cells()?.rows ?? []).map((row: MdxRow, key) => ({ key, label: row.label, cells: row.cells }));
  }

  /** Whether the first column of row labels is drawn: some row carries a label. */
  protected get hasRowHeader(): boolean {
    this.version();
    return (this.state().cells()?.rows ?? []).some((row) => row.label !== '');
  }

  protected get gridColumnCount(): number {
    return this.gridColumns.length + (this.hasRowHeader ? 1 : 0);
  }

  protected get gridRowCount(): number {
    return this.gridRows.length + 1;
  }

  /** One even track per drawn column, each at least wide enough to read. */
  protected get gridTemplate(): string {
    return `repeat(${Math.max(1, this.gridColumnCount)}, minmax(10rem, 1fr))`;
  }

  /** A cell's drill answers nothing while a run is live. */
  protected get drillBlocked(): boolean {
    this.version();
    return this.state().busy() || !this.state().drillable();
  }

  /** The listing a drill-through answered, or `null`. */
  protected get listing(): SqlRows | null {
    this.version();
    return this.state().listing();
  }

  /** The listing's own row-count line. */
  protected get listingLine(): string {
    const shown = this.listing;
    return shown === null ? '' : mdxStatusLineFor({ outcome: 'rows', result: shown });
  }

  /** Whether a confirmation waits on Proceed. */
  protected get confirming(): boolean {
    this.version();
    return this.state().confirm() !== null;
  }

  /** A value cell's accessible name: its value as shown, then the drill-through of the row's label and the column's header. */
  protected drillLabel(label: string, index: number, value: string): string {
    const drill = STRINGS.analyticsMdxDrillCell.split('<row>').join(label).split('<column>').join(this.gridColumns[index] ?? '');
    return value === '' ? drill : `${value}, ${drill}`;
  }

  protected onDrill(row: number, column: number): void {
    if (this.drillBlocked) return;
    void this.state().drill(this.deps(), row, column);
  }

  protected onProceed(): void {
    void this.state().proceed(this.deps());
  }

  protected onCancel(): void {
    this.state().cancelConfirm();
  }
}
