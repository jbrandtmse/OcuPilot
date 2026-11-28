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
import { ResultGrid } from '../../shell/result-grid';
import { WarningDialog } from '../../shell/warning-dialog';
import { fillPlaceholders } from './code-list.store';
import type { SqlAdvice, SqlAdviceFinding, SqlAlternatePlan, SqlComparedPlan } from '../../core/sql-answer';
import {
  MAX_COMPARED_PLANS,
  SqlQueryState,
  adviceConfidenceLabel,
  adviceKindLabel,
  backgroundStatusLineFor,
  consequenceFor,
  statusLineFor,
  type SqlQueryDeps,
  type SqlRows,
} from './sql-query.store';

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
 * alert, and its rows through the same `ResultGrid` as Run's. Run and Explain plan stay usable while
 * it runs. Polling stops when the page goes and resumes when it returns to a run still running.
 *
 * **Advise** (Story 21.27) posts the statement with `advise: true` to the plan route and shows the plan with the findings the instance read from it, one
 * row each; every sentence in a row is the instance's own, and the page adds only the finding and confidence names, the note and the empty states.
 *
 * **Alternate plans** (Story 21.28) posts the statement with `alternates: true` and lists the plans the optimizer considered; Show plan puts one plan's text
 * in the plan pane, and Compare plans posts the checked plan numbers (one to five, no values) and shows each run's statistics under the ruled note.
 * The list stays drawn while either answers.
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
  imports: [ResultGrid, WarningDialog],
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
        <button type="button" class="ocu-button-text" data-ocu-sql="explain-stats" [attr.aria-disabled]="blocked" (click)="onPlanWithStatistics()">
          {{ STRINGS.explorerSqlPlanWithStatistics }}
        </button>
        <button type="button" class="ocu-button-text" data-ocu-sql="advise" [attr.aria-disabled]="blocked" (click)="onAdvise()">
          {{ STRINGS.sqlAdviceAction }}
        </button>
        <button type="button" class="ocu-button-text" data-ocu-sql="alternate-plans" [attr.aria-disabled]="blocked" (click)="onAlternatePlans()">
          {{ STRINGS.sqlAlternatePlansAction }}
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
    @if (hasStatisticsNote) {
      <p class="ocu-explorer-status" data-ocu-sql="stats-note">{{ STRINGS.sqlPlanStatisticsNote }}</p>
    }
    @if (hasAlternates) {
      <div data-ocu-sql="alternates" role="region" [attr.aria-label]="STRINGS.sqlAlternatePlansHeading">
        <h2 class="ocu-details-heading">{{ STRINGS.sqlAlternatePlansHeading }}</h2>
        <p class="ocu-explorer-status" data-ocu-sql="alternates-hint">{{ STRINGS.sqlAlternateHint }}</p>
        @if (alternatesTruncated) {
          <p class="ocu-explorer-status" data-ocu-sql="alternates-truncated">{{ STRINGS.sqlAlternatePlansTruncated }}</p>
        }
        <table class="ocu-details-volumes-table" data-ocu-sql="alternates-table">
          <thead>
            <tr>
              <th scope="col"><span class="ocu-visually-hidden">{{ STRINGS.sqlAlternateComparePlans }}</span></th>
              <th scope="col">{{ STRINGS.explorerSqlPlanHeading }}</th>
              <th scope="col">{{ STRINGS.sqlAlternateColumnCost }}</th>
              <th scope="col">{{ STRINGS.indexAnalysisColumnMapType }}</th>
              <th scope="col">{{ STRINGS.sqlAlternateColumnStartingMap }}</th>
              <th scope="col"><span class="ocu-visually-hidden">{{ STRINGS.sqlAlternateShowPlan }}</span></th>
            </tr>
          </thead>
          <tbody>
            @for (row of alternateRows; track row.plan.id) {
              <tr data-ocu-sql="alternate" [attr.data-ocu-plan]="row.plan.id">
                <td>
                  <input
                    type="checkbox"
                    data-ocu-sql="alternate-check"
                    [checked]="row.checked"
                    [disabled]="row.locked"
                    [attr.aria-labelledby]="row.labelId"
                    (change)="onCheck(row.plan.id)"
                  />
                </td>
                <td [id]="row.labelId">{{ row.plan.id }}</td>
                <td>{{ row.plan.cost }}</td>
                <td>{{ row.plan.mapType }}</td>
                <td>{{ row.plan.startingMap }}</td>
                <td>
                  <button type="button" class="ocu-button-text" data-ocu-sql="show-plan" [attr.aria-disabled]="running" (click)="onShowPlan(row.plan.id)">
                    {{ STRINGS.sqlAlternateShowPlan }}
                  </button>
                </td>
              </tr>
            }
          </tbody>
        </table>
        <button type="button" class="ocu-button-text" data-ocu-sql="compare" [attr.aria-disabled]="compareBlocked" (click)="onCompare()">
          {{ STRINGS.sqlAlternateComparePlans }}
        </button>
      </div>
    }
    @if (hasPlan) {
      <h2 class="ocu-details-heading">{{ STRINGS.explorerSqlPlanHeading }}</h2>
      <pre class="ocu-source-text ocu-sql-query-plan" tabindex="0" data-ocu-sql="plan" [attr.aria-label]="STRINGS.explorerSqlPlanHeading">{{ plan }}</pre>
    }
    @if (hasCompared) {
      <div data-ocu-sql="compared" role="region" [attr.aria-label]="STRINGS.sqlAlternateComparedHeading">
        <h2 class="ocu-details-heading">{{ STRINGS.sqlAlternateComparedHeading }}</h2>
        @if (hasCompareNote) {
          <p class="ocu-explorer-status" data-ocu-sql="compare-note">{{ STRINGS.sqlAlternateCompareNote }}</p>
        }
        <table class="ocu-details-volumes-table" data-ocu-sql="compared-table">
          <thead>
            <tr>
              <th scope="col">{{ STRINGS.explorerSqlPlanHeading }}</th>
              <th scope="col">{{ STRINGS.sqlAlternateColumnCost }}</th>
              <th scope="col">{{ STRINGS.sqlAlternateColumnStartingMap }}</th>
              <th scope="col">{{ STRINGS.processDetailsGlobalReferences }}</th>
              <th scope="col">{{ STRINGS.processColumnCommands }}</th>
              <th scope="col">{{ STRINGS.explorerSqlColumnTotalTime }}</th>
              <th scope="col">{{ STRINGS.explorerSqlColumnRows }}</th>
            </tr>
          </thead>
          <tbody>
            @for (row of comparedRows; track row.id) {
              <tr data-ocu-sql="compared-row" [attr.data-ocu-plan]="row.id">
                <td>{{ row.id }}</td>
                <td>{{ row.cost }}</td>
                <td>{{ row.startingMap }}</td>
                <td>{{ row.globalReferences }}</td>
                <td>{{ row.commands }}</td>
                <td>{{ row.totalTime }}</td>
                <td>{{ row.rows }}</td>
              </tr>
            }
          </tbody>
        </table>
      </div>
    }
    @if (hasAdvice) {
      <div data-ocu-sql="advice" role="region" [attr.aria-label]="STRINGS.sqlAdviceAction">
        <p class="ocu-explorer-status" data-ocu-sql="advice-note">{{ STRINGS.sqlAdviceNote }}</p>
        @if (adviceTruncated) {
          <p class="ocu-explorer-status" data-ocu-sql="advice-truncated">{{ STRINGS.sqlAdviceTruncated }}</p>
        }
        @if (hasFindings) {
          <table class="ocu-details-volumes-table" data-ocu-sql="findings">
            <thead>
              <tr>
                <th scope="col">{{ STRINGS.sqlAdviceColumnFinding }}</th>
                <th scope="col">{{ STRINGS.sqlAdviceColumnConfidence }}</th>
                <th scope="col">{{ STRINGS.explorerSqlColumnTable }}</th>
                <th scope="col">{{ STRINGS.securityAdvisorColumnRecommendation }}</th>
              </tr>
            </thead>
            <tbody>
              @for (finding of findings; track $index) {
                <tr data-ocu-sql="finding" [attr.data-ocu-kind]="finding.kind">
                  <td>
                    <strong>{{ finding.label }}</strong>
                    <br />
                    {{ finding.detail }}
                  </td>
                  <td>{{ finding.confidence }}</td>
                  <td>{{ finding.table }}</td>
                  <td>{{ finding.recommendation }}</td>
                </tr>
              }
            </tbody>
          </table>
        } @else {
          <p class="ocu-explorer-status" data-ocu-sql="advice-status">{{ adviceStatus }}</p>
        }
      </div>
    }
    @if (result; as shown) {
      <app-result-grid [answer]="shown" [label]="STRINGS.explorerSqlQueryLabel" />
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
          <app-result-grid [answer]="shown" [label]="STRINGS.explorerSqlBackgroundHeading" [slot]="backgroundSlot" />
        }
      </div>
    }
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

  /** The prefix the Background run section's grid carries on its `data-ocu-sql` values. */
  protected readonly backgroundSlot = 'background-';

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

  /** The advice the plan on screen carries, or `null`: only an Advise answer has any. */
  private get advice(): SqlAdvice | null {
    this.generation();
    const answer = this.state.answer();
    return !this.state.running() && answer !== null && answer.outcome === 'plan' && answer.advice !== undefined ? answer.advice : null;
  }

  protected get hasAdvice(): boolean {
    return this.advice !== null;
  }

  /** Whether the instance cut the findings or the tables at the advice's caps. */
  protected get adviceTruncated(): boolean {
    return this.advice?.truncated === true;
  }

  /** The findings, each with its kind and confidence named; the sentences are the instance's own. */
  protected get findings(): readonly (SqlAdviceFinding & { readonly label: string })[] {
    return (this.advice?.findings ?? []).map((finding) => ({
      ...finding,
      label: adviceKindLabel(finding.kind),
      confidence: adviceConfidenceLabel(finding.confidence),
    }));
  }

  protected get hasFindings(): boolean {
    return this.findings.length > 0;
  }

  /** What stands where the findings would: the plan was not recognized, or it holds nothing to advise on. */
  protected get adviceStatus(): string {
    return this.advice?.recognized === true ? STRINGS.sqlAdviceEmpty : STRINGS.sqlAdviceUnrecognized;
  }

  /** Every Plan with statistics result carries the note that the statement ran without its values. */
  protected get hasStatisticsNote(): boolean {
    this.generation();
    return !this.state.running() && this.state.statisticsAnswer();
  }

  /** Whether the possible plans are drawn: Alternate plans answered some and no other answer has replaced them. */
  protected get hasAlternates(): boolean {
    this.generation();
    return this.state.alternates() !== null;
  }

  /** Whether the instance cut the possible plans at its cap. */
  protected get alternatesTruncated(): boolean {
    this.generation();
    return this.state.alternates()?.truncated === true;
  }

  /** The possible plans, each with whether it is checked and whether a sixth check would be refused. */
  protected get alternateRows(): readonly { readonly plan: SqlAlternatePlan; readonly checked: boolean; readonly locked: boolean; readonly labelId: string }[] {
    this.generation();
    const checked = this.state.checked();
    return (this.state.alternates()?.plans ?? []).map((plan) => ({
      plan,
      checked: checked.includes(plan.id),
      locked: !checked.includes(plan.id) && checked.length >= MAX_COMPARED_PLANS,
      labelId: `ocu-sql-alternate-${plan.id}`,
    }));
  }

  /** Compare plans stays drawn and answers nothing while a request runs or unless one to five plans are checked. */
  protected get compareBlocked(): boolean {
    this.generation();
    const count = this.state.checked().length;
    return this.state.running() || count < 1 || count > MAX_COMPARED_PLANS;
  }

  private get comparedPlans(): readonly SqlComparedPlan[] | null {
    this.generation();
    const answer = this.state.answer();
    return !this.state.running() && answer !== null && answer.outcome === 'compared' ? answer.plans : null;
  }

  protected get hasCompared(): boolean {
    return this.comparedPlans !== null;
  }

  protected get comparedRows(): readonly SqlComparedPlan[] {
    return this.comparedPlans ?? [];
  }

  /** Every Compare plans result carries the note that each plan's run left out the statement's values. */
  protected get hasCompareNote(): boolean {
    this.generation();
    return !this.state.running() && this.state.comparedAnswer();
  }

  protected get result(): SqlRows | null {
    this.generation();
    const answer = this.state.answer();
    return answer !== null && answer.outcome === 'rows' ? answer.result : null;
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

  protected onPlanWithStatistics(): void {
    if (this.blocked) return;
    void this.state.planWithStatistics(this.deps);
  }

  protected onAdvise(): void {
    if (this.blocked) return;
    void this.state.advise(this.deps);
  }

  protected onAlternatePlans(): void {
    if (this.blocked) return;
    void this.state.alternatePlans(this.deps);
  }

  protected onCheck(id: number): void {
    this.state.toggleChecked(id);
  }

  protected onShowPlan(id: number): void {
    if (this.running) return;
    void this.state.showAlternatePlan(this.deps, id);
  }

  protected onCompare(): void {
    if (this.compareBlocked) return;
    void this.state.comparePlans(this.deps);
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
