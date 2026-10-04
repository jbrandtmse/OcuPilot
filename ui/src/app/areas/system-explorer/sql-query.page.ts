import { NgTemplateOutlet } from '@angular/common';
import { ChangeDetectionStrategy, Component, DestroyRef, InjectionToken, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { NavigationService } from '../../core/navigation';
import { schedulePoll } from '../../core/poll-schedule';
import { ScopeService } from '../../core/scope';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { WarningDialog } from '../../shell/warning-dialog';
import { fillPlaceholders } from './code-list.store';
import { SqlQueryState, backgroundStatusLineFor, consequenceFor, statusLineFor, type SqlQueryDeps, type SqlRows } from './sql-query.store';

/** When a background run's next poll is sent: `schedulePoll` everywhere but a spec, which drives the poll by hand. */
export const SQL_BACKGROUND_SCHEDULE = new InjectionToken<(run: () => void, delayMs: number) => void>('SQL_BACKGROUND_SCHEDULE', {
  providedIn: 'root',
  factory: () => schedulePoll,
});

/** One `SqlQueryState` per screen store, so a return to the screen finds the last statement and answer. */
const HELD = new WeakMap<ScreenStore, SqlQueryState>();

function heldFor(store: ScreenStore | null): SqlQueryState {
  const known = store === null ? undefined : HELD.get(store);
  if (known !== undefined) return known;
  const state = new SqlQueryState();
  if (store !== null) HELD.set(store, state);
  return state;
}

/** One value field as drawn. */
interface ValueField {
  readonly index: number;
  readonly id: string;
  readonly label: string;
  readonly value: string;
}

/** One row of the result grid as drawn. */
interface RowView {
  readonly key: number;
  readonly cells: readonly string[];
}

/** One even track per column of `shown`, each at least wide enough to read. */
function trackTemplate(shown: SqlRows | null): string {
  const count = Math.max(1, shown?.columns.length ?? 1);
  return `repeat(${count}, minmax(10rem, 1fr))`;
}

/**
 * System Explorer's SQL query (Story 19.6): a statement on the code surface, Max rows, Run and
 * Explain plan, and what the instance answered -- a status line, a page-owned grid of text cells, an
 * SQL error as text, or a plan.
 *
 * **Nothing that changes state is decided here** (AD-11). Run posts the statement; the instance
 * answers rows for a query and `confirm` for anything else, and only then is the warning drawn, its
 * consequence naming the statement's kind and, for DML, its tables. Proceed sends the screen action
 * `run` (AD-53). Value fields appear when the instance asks for values, and go when the statement
 * changes.
 *
 * **A query can run in the background** (Story 19.15): Run in background starts it and the Background
 * run section follows it -- its own status line, Cancel while it runs, a failed run's refusal as an
 * alert, and its rows through the same grid template as Run's. Run and Explain plan stay usable while
 * it runs. Polling stops when the page goes and resumes when it returns to a run still running.
 *
 * **Everything shown is text** (AD-11): a cell, an error and a plan are interpolated, never markup.
 * The answer lives in `SqlQueryState`, never in the screen's store, so it never reaches screen context
 * (AD-39's sixth exception). A refusal is an alert banner; a privilege denial names its pair.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-sql-query-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [NgTemplateOutlet, WarningDialog],
  template: `<section class="ocu-form-page ocu-sql-query" [attr.aria-busy]="running">
    @if (hasRefusal) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-ocu-sql="refusal">{{ refusal }}</p>
    }
    <form class="ocu-sql-query-form" data-ocu-sql="form" (submit)="onRun($event)">
      <label class="ocu-criteria-label" for="ocu-sql-statement">{{ STRINGS.explorerSqlColumnStatement }}</label>
      <textarea
        id="ocu-sql-statement"
        class="ocu-source-text ocu-sql-query-statement"
        spellcheck="false"
        wrap="off"
        autocomplete="off"
        data-ocu-sql="statement"
        [value]="text"
        (input)="onText($event)"
      ></textarea>
      @if (hasValues) {
        <div class="ocu-criteria-fields" data-ocu-sql="values">
          @for (field of valueFields; track field.index) {
            <div class="ocu-criteria-field">
              <label class="ocu-criteria-label" [attr.for]="field.id">{{ field.label }}</label>
              <input
                class="ocu-criteria-input"
                type="text"
                autocomplete="off"
                spellcheck="false"
                data-ocu-sql="value"
                [id]="field.id"
                [value]="field.value"
                (input)="onValue(field.index, $event)"
              />
            </div>
          }
        </div>
      }
      <div class="ocu-criteria-controls">
        <div class="ocu-criteria-field ocu-sql-query-max">
          <label class="ocu-criteria-label" for="ocu-sql-max-rows">{{ STRINGS.tableMaxRowsLabel }}</label>
          <input
            id="ocu-sql-max-rows"
            class="ocu-criteria-input"
            type="text"
            inputmode="numeric"
            autocomplete="off"
            data-ocu-sql="max-rows"
            [value]="maxRows"
            (input)="onMaxRows($event)"
          />
        </div>
        <button type="button" class="ocu-button-text" data-ocu-sql="explain" [attr.aria-disabled]="blocked" (click)="onPlan()">
          {{ STRINGS.explorerSqlExplainPlan }}
        </button>
        <button type="button" class="ocu-button-text" data-ocu-sql="background" [attr.aria-disabled]="backgroundBlocked" (click)="onBackground()">
          {{ STRINGS.explorerSqlRunInBackground }}
        </button>
        <button type="submit" class="ocu-button-primary" data-ocu-sql="run" [attr.aria-disabled]="blocked">{{ STRINGS.actionRun }}</button>
      </div>
    </form>
    <p class="ocu-explorer-status" role="status" data-ocu-sql="status">{{ statusLine }}</p>
    @if (hasMessage) {
      <pre class="ocu-source-text ocu-sql-query-message" tabindex="0" data-ocu-sql="message" [attr.aria-label]="statusLine">{{ message }}</pre>
    }
    @if (hasPlan) {
      <h2 class="ocu-details-heading">{{ STRINGS.explorerSqlPlanHeading }}</h2>
      <pre class="ocu-source-text ocu-sql-query-plan" tabindex="0" data-ocu-sql="plan" [attr.aria-label]="STRINGS.explorerSqlPlanHeading">{{ plan }}</pre>
    }
    @if (result; as shown) {
      <ng-container
        [ngTemplateOutlet]="grid"
        [ngTemplateOutletContext]="{ $implicit: shown, rows: rows, template: template, label: STRINGS.explorerSqlQueryLabel, slot: '' }"
      />
    }
    @if (hasBackground) {
      <div class="ocu-sql-query-background" data-ocu-sql="background-run">
        <div class="ocu-sql-query-background-head">
          <h2 class="ocu-details-heading">{{ STRINGS.explorerSqlBackgroundHeading }}</h2>
          @if (backgroundRunning) {
            <button type="button" class="ocu-button-text" data-ocu-sql="background-cancel" (click)="onCancelBackground()">{{ STRINGS.actionCancel }}</button>
          }
        </div>
        <p class="ocu-explorer-status" role="status" data-ocu-sql="background-status">{{ backgroundStatusLine }}</p>
        @if (hasBackgroundRefusal) {
          <p class="ocu-banner ocu-banner-warning" role="alert" data-ocu-sql="background-refusal">{{ backgroundRefusal }}</p>
        }
        @if (hasBackgroundMessage) {
          <pre class="ocu-source-text ocu-sql-query-message" tabindex="0" data-ocu-sql="background-message" [attr.aria-label]="backgroundStatusLine">{{ backgroundMessage }}</pre>
        }
        @if (backgroundResult; as shown) {
          <ng-container
            [ngTemplateOutlet]="grid"
            [ngTemplateOutletContext]="{ $implicit: shown, rows: backgroundRows, template: backgroundTemplate, label: STRINGS.explorerSqlBackgroundHeading, slot: 'background-' }"
          />
        }
      </div>
    }
    <ng-template #grid let-shown let-rows="rows" let-template="template" let-label="label" let-slot="slot">
      <div class="ocu-data-table-frame">
        <div
          class="ocu-data-table-grid ocu-sql-query-results"
          role="table"
          [attr.data-ocu-sql]="slot + 'results'"
          [attr.aria-label]="label"
          [attr.aria-rowcount]="shown.rows.length + 1"
        >
          <div class="ocu-data-table-head" role="rowgroup">
            <div class="ocu-data-table-row ocu-data-table-header-row" role="row" aria-rowindex="1" [style.grid-template-columns]="template">
              @for (column of shown.columns; track $index) {
                <div class="ocu-data-table-header-cell" role="columnheader">
                  <span class="ocu-data-table-header-label">{{ column }}</span>
                </div>
              }
            </div>
          </div>
          <div class="ocu-data-table-viewport">
            <div class="ocu-data-table-body" role="rowgroup">
              @for (row of rows; track row.key) {
                <div class="ocu-data-table-row" role="row" [attr.aria-rowindex]="row.key + 2" [style.grid-template-columns]="template">
                  @for (cell of row.cells; track $index) {
                    <div class="ocu-data-table-cell" role="cell">
                      <span class="ocu-data-table-text ocu-sql-query-cell" [attr.data-ocu-sql]="slot + 'cell'">{{ cell }}</span>
                    </div>
                  }
                </div>
              }
            </div>
          </div>
        </div>
      </div>
    </ng-template>
    @if (confirming) {
      <app-warning-dialog
        [verb]="STRINGS.explorerSqlConfirmTitle"
        [consequence]="consequence"
        (confirmed)="onProceed()"
        (cancelled)="onCancel()"
      />
    }
  </section>`,
})
export class SqlQueryPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);
  private readonly scope = inject(ScopeService);

  protected readonly STRINGS = STRINGS;

  protected readonly screen: ScreenDeclaration | null;

  private readonly state: SqlQueryState;

  private readonly deps: SqlQueryDeps;

  /** Bumped by the state, so the page re-renders under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    this.screen = this.navigation.screenForUrl(this.router.url);
    this.state = heldFor(this.screen === null ? null : this.stores.for(this.screen.descriptor, this.screen.refreshRates));
    this.deps = {
      api: inject(ApiService),
      sender: inject(ScreenActionHandler),
      descriptor: this.screen?.descriptor ?? '',
      scope: () => this.scope.namespace(),
      schedule: inject(SQL_BACKGROUND_SCHEDULE),
    };
    const stop = this.state.subscribe(() => this.bump());
    // A background run left running when the page went is followed again on its return.
    if (this.state.backgroundStatus() === 'running') void this.state.pollBackground(this.deps);
    // A confirmation answers the namespace and statement it was asked for, so leaving the page cancels
    // it; the background run goes on, unpolled until the page returns.
    inject(DestroyRef).onDestroy(() => {
      stop();
      this.state.cancelConfirm();
      this.state.stopPolling();
    });
  }

  protected get text(): string {
    this.generation();
    return this.state.text();
  }

  protected get maxRows(): string {
    this.generation();
    return this.state.maxRows();
  }

  protected get running(): boolean {
    this.generation();
    return this.state.running();
  }

  /** Run and Explain plan stay drawn and answer nothing while a request runs or before a statement is written. */
  protected get blocked(): boolean {
    this.generation();
    return this.state.running() || this.state.text().trim() === '';
  }

  /** Run in background stays drawn and answers nothing while its run runs or before a statement is written. */
  protected get backgroundBlocked(): boolean {
    this.generation();
    return this.state.backgroundBusy() || this.state.text().trim() === '';
  }

  /** Whether the Background run section is drawn: a run is on screen. */
  protected get hasBackground(): boolean {
    this.generation();
    return this.state.backgroundId() !== null;
  }

  protected get backgroundRunning(): boolean {
    this.generation();
    return this.state.backgroundStatus() === 'running';
  }

  protected get backgroundStatusLine(): string {
    this.generation();
    return backgroundStatusLineFor(this.state.backgroundStatus(), this.state.backgroundAnswer());
  }

  protected get backgroundRefusal(): string {
    this.generation();
    return this.state.backgroundRefusal();
  }

  protected get hasBackgroundRefusal(): boolean {
    return this.backgroundRefusal !== '';
  }

  /** A background run's SQL error message, shown as text below its code. */
  protected get backgroundMessage(): string {
    this.generation();
    const answer = this.state.backgroundAnswer();
    return answer !== null && answer.outcome === 'error' ? answer.message : '';
  }

  protected get hasBackgroundMessage(): boolean {
    return this.backgroundMessage !== '';
  }

  protected get backgroundResult(): SqlRows | null {
    this.generation();
    const answer = this.state.backgroundAnswer();
    return answer !== null && answer.outcome === 'rows' ? answer.result : null;
  }

  protected get backgroundRows(): readonly RowView[] {
    return (this.backgroundResult?.rows ?? []).map((cells, key) => ({ key, cells }));
  }

  protected get backgroundTemplate(): string {
    return trackTemplate(this.backgroundResult);
  }

  protected get refusal(): string {
    this.generation();
    return this.state.refusal();
  }

  protected get hasRefusal(): boolean {
    return this.refusal !== '';
  }

  protected get valueFields(): readonly ValueField[] {
    this.generation();
    return this.state.values().map((value, index) => ({
      index,
      id: `ocu-sql-value-${index + 1}`,
      label: fillPlaceholders(STRINGS.explorerSqlValueLabel, { n: index + 1 }),
      value,
    }));
  }

  protected get hasValues(): boolean {
    this.generation();
    return this.state.values().length > 0;
  }

  protected get statusLine(): string {
    this.generation();
    if (this.state.running()) return '';
    return statusLineFor(this.state.answer());
  }

  /** An SQL error's message, shown as text below its code. */
  protected get message(): string {
    this.generation();
    const answer = this.state.answer();
    return answer !== null && answer.outcome === 'error' ? answer.message : '';
  }

  protected get hasMessage(): boolean {
    return this.message !== '';
  }

  protected get plan(): string {
    this.generation();
    const answer = this.state.answer();
    return answer !== null && answer.outcome === 'plan' ? answer.plan : '';
  }

  protected get hasPlan(): boolean {
    return this.plan !== '';
  }

  protected get result(): SqlRows | null {
    this.generation();
    const answer = this.state.answer();
    return answer !== null && answer.outcome === 'rows' ? answer.result : null;
  }

  protected get rows(): readonly RowView[] {
    return (this.result?.rows ?? []).map((cells, key) => ({ key, cells }));
  }

  /** One even track per column, each at least wide enough to read. */
  protected get template(): string {
    return trackTemplate(this.result);
  }

  /** Whether a confirmation waits on Proceed. */
  protected get confirming(): boolean {
    this.generation();
    return this.state.confirm() !== null;
  }

  protected get consequence(): string {
    this.generation();
    const pending = this.state.confirm();
    return pending === null ? '' : consequenceFor(pending);
  }

  protected onText(event: Event): void {
    this.state.setText((event.target as HTMLTextAreaElement).value);
  }

  protected onValue(index: number, event: Event): void {
    this.state.setValue(index, (event.target as HTMLInputElement).value);
  }

  protected onMaxRows(event: Event): void {
    this.state.setMaxRows((event.target as HTMLInputElement).value);
  }

  protected onRun(event: Event): void {
    event.preventDefault();
    if (this.blocked) return;
    void this.state.run(this.deps);
  }

  protected onPlan(): void {
    if (this.blocked) return;
    void this.state.plan(this.deps);
  }

  protected onBackground(): void {
    if (this.backgroundBlocked) return;
    void this.state.startBackground(this.deps);
  }

  protected onCancelBackground(): void {
    void this.state.cancelBackground(this.deps);
  }

  protected onProceed(): void {
    void this.state.proceed(this.deps);
  }

  protected onCancel(): void {
    this.state.cancelConfirm();
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}
