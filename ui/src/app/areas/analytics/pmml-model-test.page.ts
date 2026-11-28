import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ApiService } from '../../core/api';
import { joinCompositeId } from '../../core/entity-id';
import { screenForDescriptor } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';
import { ScopeService } from '../../core/scope';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { STRINGS } from '../../core/strings';
import type { Violation } from '../../core/violations';
import { DetailPage } from '../../shell/detail-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { MDX_BACKGROUND_SCHEDULE } from './mdx-query.page';
import { PmmlExportDialog } from './pmml-export-dialog';
import {
  PMML_CUSTOM,
  PMML_DATASET_PREFIX,
  PMML_VERIFICATION,
  PmmlTestState,
  dataSourceNames,
  exportDefaults,
  exportedLine,
  type PmmlExportNames,
  type PmmlPair,
  type PmmlRan,
  type PmmlTestDeps,
} from './pmml-test.store';

/** The Test screen's descriptor (Story 24.14 Batch 2), and its declared primary action: Export to cube, which this page's dialog sends (Batch 4). */
export const PMML_MODEL_TEST = 'OcuPilot.Screen.Descriptor.AnalyticsPmmlModelTest';

export const PMML_EXPORT_ACTION = 'export';

/** One option of the data source picker. */
interface Choice {
  readonly value: string;
  readonly label: string;
}

/** One metric row of a categorical answer. */
interface Metric {
  readonly label: string;
  readonly pair: PmmlPair;
}

/** The text of `row`'s member `name`, or `''`. */
function memberText(row: unknown, name: string): string {
  if (row === null || typeof row !== 'object') return '';
  const value = (row as Readonly<Record<string, unknown>>)[name];
  return typeof value === 'string' ? value : '';
}

/**
 * Analytics' Test screen of a PMML model (Story 24.14 Batch 2, AD-5): the detail page over the shared list page, which draws the model's one row, and
 * under it the test the person runs: a picker of the model's data sources (its own, its verification records when it has them, and one SQL query written
 * here), Run and Cancel, and what the instance answered (`pmml-test.store.ts`). The browser sends the model's id, the kind of source and the name or the
 * SQL, never anything it composed (AD-11).
 *
 * A categorical model answers its record count, its precision, recall and F-measure as micro and macro averages and a table of its actual values; a
 * continuous model its sigma, RSE and R squared; each lists the records it ran, actual against predicted. The status line says a run is running, was
 * canceled or stopped at the bound, or that an answer was cut. **Everything shown is text** (AD-11).
 *
 * The test's state belongs to this page and the model it shows: another model, or leaving the page, drops it (a run left running is left, as MDX query's is).
 *
 * **Export to cube is this page's own action** (Batch 4), registered on the descriptor after injecting the shell's handler. It opens a dialog over the source chosen here, with the four names at the classic's
 * defaults, and sends them through the handler's `sendFor` with the model's composite id as its target: the instance tests the model again, copies the rows into a new class and makes a cube class, and a refusal
 * stays in the dialog. An applied export closes it and leaves one line under the status, naming the class and the cube from the answer the handler read.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-pmml-model-test-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DetailPage, PmmlExportDialog],
  // The height chain every page host carries, so the list's viewport keeps its height; the test's panel scrolls within its own share.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
    .ocu-pmml-test {
      flex: 0 0 auto;
      max-height: 60%;
      overflow: auto;
    }
    .ocu-pmml-table {
      border-collapse: collapse;
      margin: 0.5rem 0;
    }
    .ocu-pmml-table th,
    .ocu-pmml-table td {
      padding: 0.25rem 0.75rem;
      text-align: start;
    }
    .ocu-pmml-facts {
      display: grid;
      grid-template-columns: max-content max-content;
      gap: 0.25rem 1rem;
      margin: 0.5rem 0;
    }
  `,
  template: `<app-detail-page />
    @if (hasModel) {
      <section class="ocu-form-page ocu-mdx-query ocu-pmml-test" data-ocu-pmml="run-panel" [attr.aria-busy]="busy">
        @if (hasRefusal) {
          <p class="ocu-banner ocu-banner-warning" role="alert" data-ocu-pmml="banner">{{ refusal }}</p>
        }
        <div class="ocu-criteria-field">
          <label class="ocu-criteria-label" for="ocu-pmml-source">{{ STRINGS.analyticsColumnDataSource }}</label>
          <select id="ocu-pmml-source" class="ocu-criteria-select" data-ocu-pmml="source" (change)="onChoice($event)">
            @for (choice of choices; track choice.value) {
              <option [value]="choice.value" [selected]="choice.value === currentChoice">{{ choice.label }}</option>
            }
          </select>
        </div>
        @if (isCustom) {
          <label class="ocu-criteria-label" for="ocu-pmml-sql">{{ STRINGS.analyticsPmmlSql }}</label>
          <textarea
            id="ocu-pmml-sql"
            class="ocu-source-text ocu-sql-query-statement"
            spellcheck="false"
            wrap="off"
            autocomplete="off"
            data-ocu-pmml="sql"
            [value]="sql"
            (input)="onSql($event)"
          ></textarea>
        }
        <div class="ocu-criteria-controls">
          @if (running) {
            <button type="button" class="ocu-button-text" data-ocu-pmml="cancel" (click)="onCancelRun()">{{ STRINGS.actionCancel }}</button>
          }
          <button type="button" class="ocu-button-primary" data-ocu-pmml="run" [attr.aria-disabled]="blocked" (click)="onRun()">{{ STRINGS.actionRun }}</button>
        </div>
        <p class="ocu-explorer-status" role="status" data-ocu-pmml="status">{{ statusLine }}</p>
        @if (hasExported) {
          <p class="ocu-explorer-status" role="status" data-ocu-pmml="export-line">{{ exportedText }}</p>
        }
        @if (hasMessage) {
          <pre class="ocu-source-text ocu-sql-query-message" tabindex="0" data-ocu-pmml="error" [attr.aria-label]="STRINGS.analyticsMdxErrorLine">{{ message }}</pre>
        }
        @if (ran; as answer) {
          <div class="ocu-pmml-facts" data-ocu-pmml="facts">
            <span>{{ STRINGS.analyticsPmmlRecords }}</span>
            <span data-ocu-pmml="records">{{ answer.records }}</span>
            @if (isContinuous) {
              <span>{{ STRINGS.analyticsPmmlSigma }}</span>
              <span data-ocu-pmml="sigma">{{ answer.sigma }}</span>
              <span>{{ STRINGS.analyticsPmmlRSE }}</span>
              <span data-ocu-pmml="rse">{{ answer.rse }}</span>
              <span>{{ STRINGS.analyticsPmmlRSquared }}</span>
              <span data-ocu-pmml="rsquared">{{ answer.rSquared }}</span>
            }
          </div>
          @if (hasMetrics) {
            <table class="ocu-pmml-table" data-ocu-pmml="metrics" [attr.aria-label]="STRINGS.explorerSqlColumnPrecision">
              <thead>
                <tr>
                  <th scope="col"></th>
                  <th scope="col">{{ STRINGS.analyticsPmmlMicro }}</th>
                  <th scope="col">{{ STRINGS.explorerColumnMacro }}</th>
                </tr>
              </thead>
              <tbody>
                @for (metric of metrics; track metric.label) {
                  <tr>
                    <th scope="row">{{ metric.label }}</th>
                    <td data-ocu-pmml="micro">{{ metric.pair.micro }}</td>
                    <td data-ocu-pmml="macro">{{ metric.pair.macro }}</td>
                  </tr>
                }
              </tbody>
            </table>
          }
          @if (hasValues) {
            <table class="ocu-pmml-table" data-ocu-pmml="values" [attr.aria-label]="STRINGS.analyticsPmmlActualValue">
              <thead>
                <tr>
                  <th scope="col">{{ STRINGS.analyticsPmmlActualValue }}</th>
                  <th scope="col">{{ STRINGS.analyticsPmmlRecords }}</th>
                  <th scope="col">{{ STRINGS.analyticsPmmlCorrect }}</th>
                  <th scope="col">{{ STRINGS.analyticsPmmlIncorrect }}</th>
                </tr>
              </thead>
              <tbody>
                @for (value of answer.values; track $index) {
                  <tr>
                    <td data-ocu-pmml="value-actual">{{ value.actual }}</td>
                    <td data-ocu-pmml="value-records">{{ value.records }}</td>
                    <td data-ocu-pmml="value-correct">{{ value.correct }}</td>
                    <td data-ocu-pmml="value-incorrect">{{ value.incorrect }}</td>
                  </tr>
                }
              </tbody>
            </table>
          }
          @if (hasRows) {
            <table class="ocu-pmml-table" data-ocu-pmml="rows" [attr.aria-label]="STRINGS.analyticsPmmlRecords">
              <thead>
                <tr>
                  <th scope="col">{{ STRINGS.interopColumnId }}</th>
                  <th scope="col">{{ STRINGS.analyticsPmmlActualValue }}</th>
                  <th scope="col">{{ STRINGS.analyticsPmmlPredictedValue }}</th>
                  <th scope="col">{{ STRINGS.analyticsPmmlProbability }}</th>
                </tr>
              </thead>
              <tbody>
                @for (record of answer.rows; track $index) {
                  <tr>
                    <td data-ocu-pmml="row-record">{{ record.record }}</td>
                    <td data-ocu-pmml="row-actual">{{ record.actual }}</td>
                    <td data-ocu-pmml="row-predicted">{{ record.predicted }}</td>
                    <td data-ocu-pmml="row-probability">{{ probabilityText(record.probability) }}</td>
                  </tr>
                }
              </tbody>
            </table>
          }
        }
      </section>
    }
    @if (isExporting) {
      <app-pmml-export-dialog
        [source]="exportSource"
        [defaults]="exportNames"
        [sending]="exportSending()"
        [refusal]="exportRefusal()"
        [violations]="exportViolations()"
        (submitted)="onExport($event)"
        (cancelled)="onExportClose()"
      />
    }`,
})
export class PmmlModelTestPage {
  private readonly stores = inject(ScreenStores);
  private readonly scope = inject(ScopeService);

  /** Constructed before this page registers its own action. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  protected readonly STRINGS = STRINGS;

  private readonly exporting = signal(false);

  protected readonly exportSending = signal(false);

  protected readonly exportRefusal = signal('');

  protected readonly exportViolations = signal<readonly Violation[]>([]);

  /** The result line of the last applied export of this model, or `''`. */
  private readonly exported = signal('');

  protected state: PmmlTestState = new PmmlTestState();

  protected readonly deps: PmmlTestDeps;

  private readonly store: ScreenStore | null;

  /** The model this page's state belongs to, as its composite id. */
  private modelId = '';

  /** Bumped by the store and the state, so the page re-renders under `OnPush`. */
  private readonly generation = signal(0);

  private stopState: () => void = () => undefined;

  constructor() {
    const screen = screenForDescriptor(PMML_MODEL_TEST);
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    this.deps = {
      api: inject(ApiService),
      scope: () => this.scope.namespace(),
      schedule: inject(MDX_BACKGROUND_SCHEDULE),
    };
    this.follow();
    const stopStore = this.store === null ? () => undefined : this.store.subscribe(() => this.onRows());
    const stopAction = this.actions.register(PMML_MODEL_TEST, PMML_EXPORT_ACTION, () => this.onOpenExport());
    this.onRows();
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopAction();
      this.stopState();
      this.state.leave();
    });
  }

  /** The model's one row, or `null` when it reads none. */
  private get row(): unknown {
    return this.store?.data()[0] ?? null;
  }

  protected get hasModel(): boolean {
    this.generation();
    return this.modelId !== '';
  }

  /** The data sources on offer: the definition's own, the model's verification records when it has some, and one SQL query written here. */
  protected get choices(): readonly Choice[] {
    this.generation();
    const row = this.row;
    const sources = dataSourceNames(memberText(row, 'DataSources')).map((name): Choice => ({ value: `${PMML_DATASET_PREFIX}${name}`, label: name }));
    const verification: readonly Choice[] =
      row !== null && typeof row === 'object' && (row as Readonly<Record<string, unknown>>)['Verification'] === true
        ? [{ value: PMML_VERIFICATION, label: STRINGS.analyticsPmmlSourceVerification }]
        : [];
    return [...sources, ...verification, { value: PMML_CUSTOM, label: STRINGS.analyticsPmmlSourceCustom }];
  }

  /** The choice made, or the first on offer before any. */
  protected get currentChoice(): string {
    this.generation();
    return this.state.choice() || (this.choices[0]?.value ?? '');
  }

  protected get isCustom(): boolean {
    return this.currentChoice === PMML_CUSTOM;
  }

  protected get sql(): string {
    this.generation();
    return this.state.sql();
  }

  protected get busy(): boolean {
    this.generation();
    return this.state.busy();
  }

  protected get running(): boolean {
    this.generation();
    return this.state.status() === 'running';
  }

  /** Run answers nothing while a run is live or nothing can be sent. */
  protected get blocked(): boolean {
    this.generation();
    return this.state.busy() || this.state.body() === null;
  }

  protected get refusal(): string {
    this.generation();
    return this.state.refusal();
  }

  protected get hasRefusal(): boolean {
    return this.refusal !== '';
  }

  protected get statusLine(): string {
    this.generation();
    return this.state.statusLine();
  }

  protected get message(): string {
    this.generation();
    return this.state.message();
  }

  protected get hasMessage(): boolean {
    return this.message !== '';
  }

  /** The answer of a finished test, or `null`. */
  protected get ran(): PmmlRan | null {
    this.generation();
    const answer = this.state.answer();
    return answer !== null && answer.outcome === 'ran' ? answer : null;
  }

  protected get isContinuous(): boolean {
    return this.ran?.mode === 'continuous';
  }

  /** The precision, recall and F-measure rows of a categorical answer. */
  protected get metrics(): readonly Metric[] {
    const answer = this.ran;
    if (answer === null) return [];
    const rows: Metric[] = [];
    if (answer.precision !== null) rows.push({ label: STRINGS.explorerSqlColumnPrecision, pair: answer.precision });
    if (answer.recall !== null) rows.push({ label: STRINGS.analyticsPmmlRecall, pair: answer.recall });
    if (answer.fMeasure !== null) rows.push({ label: STRINGS.analyticsPmmlFMeasure, pair: answer.fMeasure });
    return rows;
  }

  protected get hasMetrics(): boolean {
    return this.metrics.length > 0;
  }

  protected get hasValues(): boolean {
    return (this.ran?.values.length ?? 0) > 0;
  }

  protected get hasRows(): boolean {
    return (this.ran?.rows.length ?? 0) > 0;
  }

  protected probabilityText(value: number | null): string {
    return value === null ? '' : String(value);
  }

  protected get isExporting(): boolean {
    return this.exporting();
  }

  protected get hasExported(): boolean {
    return this.exported() !== '';
  }

  protected get exportedText(): string {
    return this.exported();
  }

  /** The source the dialog shows: the label of the choice made here. */
  protected get exportSource(): string {
    const current = this.currentChoice;
    return this.choices.find((choice) => choice.value === current)?.label ?? '';
  }

  /** The names the dialog's fields start at: the classic's, for the model shown. */
  protected get exportNames(): PmmlExportNames {
    this.generation();
    return exportDefaults(memberText(this.row, 'Class'), memberText(this.row, 'Model'));
  }

  /** Open Export to cube, never over another dialog, and only for a model with a source that can be sent. */
  protected onOpenExport(): void {
    if (this.exporting() || this.exportSending() || this.handler.pending() !== null || this.modelId === '' || this.state.body() === null) return;
    this.exportRefusal.set('');
    this.exportViolations.set([]);
    this.exporting.set(true);
  }

  protected onExportClose(): void {
    this.exporting.set(false);
    this.exportRefusal.set('');
    this.exportViolations.set([]);
  }

  /**
   * One export through the handler's `sendFor`, its refusal kept in the dialog rather than on the screen's banner. An applied export closes the dialog and leaves the result line the handler's answer
   * fills in; a refused one names the fields the instance refused, or says why.
   */
  protected async onExport(names: PmmlExportNames): Promise<void> {
    if (!this.exporting() || this.exportSending()) return;
    const values = this.state.exportValues(names);
    if (values === null) return;
    this.exportSending.set(true);
    this.exportRefusal.set('');
    this.exportViolations.set([]);
    const model = this.modelId;
    const applied = await this.handler.sendFor(PMML_MODEL_TEST, PMML_EXPORT_ACTION, model, values, { setRefusal: () => undefined });
    this.exportSending.set(false);
    // Another model's page does not answer this send.
    if (this.modelId !== model) return;
    // An applied export leaves its line even when its dialog was canceled while it ran, since it cannot be undone.
    if (applied) {
      this.exported.set(exportedLine(STRINGS.analyticsPmmlExportedLine, this.handler.lastOutput()));
      this.exporting.set(false);
      return;
    }
    // A dialog canceled while this send was in flight does not show its refusal.
    if (!this.exporting()) return;
    const refused = this.handler.lastRefusal();
    const fields = refused?.violations ?? [];
    this.exportViolations.set(fields);
    this.exportRefusal.set(fields.length > 0 ? '' : (refused?.reason ?? ''));
  }

  protected onChoice(event: Event): void {
    this.state.setChoice((event.target as HTMLSelectElement).value);
  }

  protected onSql(event: Event): void {
    this.state.setSql((event.target as HTMLTextAreaElement).value);
  }

  protected onRun(): void {
    if (this.blocked) return;
    void this.state.start(this.deps);
  }

  protected onCancelRun(): void {
    void this.state.cancel(this.deps);
  }

  /** The row changed: a test belongs to the model it was started for, so another model starts with a state of its own. */
  private onRows(): void {
    const klass = memberText(this.row, 'Class');
    const model = memberText(this.row, 'Model');
    const id = klass !== '' && model !== '' ? joinCompositeId([klass, model]) : '';
    if (id !== this.modelId) {
      this.modelId = id;
      this.exported.set('');
      this.exporting.set(false);
      this.stopState();
      this.state.leave();
      this.state = new PmmlTestState();
      this.state.setModel(id);
      this.follow();
    }
    const first = this.choices[0];
    if (id !== '' && this.state.choice() === '' && first !== undefined) this.state.setChoice(first.value);
    this.generation.update((value) => value + 1);
  }

  /** Re-render when the current state changes. */
  private follow(): void {
    this.stopState = this.state.subscribe(() => this.generation.update((value) => value + 1));
  }
}
