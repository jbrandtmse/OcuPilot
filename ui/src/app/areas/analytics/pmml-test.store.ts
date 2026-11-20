/**
 * Analytics' PMML model test state (AD-19, Story 24.14 Batch 2): the data source chosen, the SQL a custom source is written as, the run on screen and
 * what it answered.
 *
 * **Framework-free.** It imports nothing from Angular; `pmml-model-test.page.ts` holds one per model and hands it what it needs as plain functions, so
 * the component spec drives it directly.
 *
 * **One owner-scoped background run** (`core/background-run.ts`, the third kind after SQL query's and MDX query's): Run starts it and polls it until it
 * ends, or Cancel stops it. The instance resolves the model and the source before it spawns anything, so a start answers in one of three ways: a run id,
 * an error outcome (the instance would not prepare a custom SQL), or a refusal. The browser sends the model's id, the kind of source and the name or the
 * SQL, never anything it composed (AD-11).
 *
 * **The answer is screen-only** (AD-39's sixth exception): the counts, the metrics, the per-value counts, each record's values and the vendor's error
 * text live in this state and are rendered as text; none of it enters the screen's store, so none of it reaches screen context.
 */

import { BackgroundRun, type BackgroundDeps, type BackgroundStart, type BackgroundStatus } from '../../core/background-run';
import { pickCount } from '../../core/count-phrase';
import { STRINGS } from '../../core/strings';
import { mdxRefusalText } from './mdx-query.store';

/** The PMML run's start route; its poll and cancel routes are `runPath`'s under it. */
export const PMML_BACKGROUND_PATH = '/api/ocupilot/analytics/pmml/background';

/** The machine code a start answers when the caller's own PMML run is still running. */
export const PMML_BUSY_CODE = 'ANALYTICS.PMML.BUSY';

/** The choice that tests a model against its own verification records. */
export const PMML_VERIFICATION = 'verification';

/** The choice that tests a model against one SQL query the person writes. */
export const PMML_CUSTOM = 'custom';

/** The prefix of the choice that tests a model against one of the definition's data sources: `dataset:<name>`. */
export const PMML_DATASET_PREFIX = 'dataset:';

/** What a client of the run gets: the same dependencies as any background run. */
export type PmmlTestDeps = BackgroundDeps;

/** A metric of a categorical model, as the two averages the instance computes. */
export interface PmmlPair {
  readonly micro: number;
  readonly macro: number;
}

/** One actual value's counts: how many records had it, and how many the model got right and wrong. */
export interface PmmlValue {
  readonly actual: string;
  readonly records: number;
  readonly correct: number;
  readonly incorrect: number;
}

/** One record the test ran: its id, its actual value and the one the model predicted, with the probability when the model reports one. */
export interface PmmlRecord {
  readonly record: string;
  readonly actual: string;
  readonly predicted: string;
  readonly probability: number | null;
}

/** What a finished test answered. */
export interface PmmlRan {
  readonly outcome: 'ran';
  readonly mode: string;
  readonly records: number;
  readonly precision: PmmlPair | null;
  readonly recall: PmmlPair | null;
  readonly fMeasure: PmmlPair | null;
  readonly sigma: number | null;
  readonly rse: number | null;
  readonly rSquared: number | null;
  readonly values: readonly PmmlValue[];
  readonly rows: readonly PmmlRecord[];
  readonly truncated: boolean;
}

/** What a run last answered, as the page draws it. */
export type PmmlAnswer = PmmlRan | { readonly outcome: 'error'; readonly message: string } | { readonly outcome: 'stopped'; readonly seconds: number };

function text(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

function count(value: unknown): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : 0;
}

function numberOrNull(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

function objectOf(value: unknown): Readonly<Record<string, unknown>> | null {
  return value !== null && typeof value === 'object' && !Array.isArray(value) ? (value as Readonly<Record<string, unknown>>) : null;
}

function pairOf(value: unknown): PmmlPair | null {
  const record = objectOf(value);
  const micro = record === null ? null : numberOrNull(record['micro']);
  const macro = record === null ? null : numberOrNull(record['macro']);
  return micro === null || macro === null ? null : { micro, macro };
}

/** One answer of a PMML run (a poll's `result`, or a start's immediate answer), or `null` for any other shape. */
export function pmmlAnswerOf(body: unknown): PmmlAnswer | null {
  const record = objectOf(body);
  if (record === null) return null;
  switch (record['outcome']) {
    case 'ran': {
      const values = Array.isArray(record['values']) ? record['values'] : null;
      const rows = Array.isArray(record['rows']) ? record['rows'] : null;
      if (values === null || rows === null) return null;
      return {
        outcome: 'ran',
        mode: text(record['mode']),
        records: count(record['records']),
        precision: pairOf(record['precision']),
        recall: pairOf(record['recall']),
        fMeasure: pairOf(record['fMeasure']),
        sigma: numberOrNull(record['sigma']),
        rse: numberOrNull(record['rse']),
        rSquared: numberOrNull(record['rSquared']),
        values: values.map((entry): PmmlValue => {
          const value = objectOf(entry) ?? {};
          return { actual: text(value['actual']), records: count(value['records']), correct: count(value['correct']), incorrect: count(value['incorrect']) };
        }),
        rows: rows.map((entry): PmmlRecord => {
          const row = objectOf(entry) ?? {};
          return { record: text(row['record']), actual: text(row['actual']), predicted: text(row['predicted']), probability: numberOrNull(row['probability']) };
        }),
        truncated: record['truncated'] === true,
      };
    }
    case 'error':
      return { outcome: 'error', message: text(record['message']) };
    case 'stopped':
      return { outcome: 'stopped', seconds: count(record['seconds']) };
    default:
      return null;
  }
}

/** `template` with each `<placeholder>` of `values` replaced. */
function fill(template: string, values: Readonly<Record<string, string | number>>): string {
  let result = template;
  for (const [key, value] of Object.entries(values)) result = result.split(`<${key}>`).join(String(value));
  return result;
}

/** The names a model row's `DataSources` field lists, one per line. */
export function dataSourceNames(field: unknown): readonly string[] {
  return text(field)
    .split('\n')
    .filter((name) => name !== '');
}

export class PmmlTestState {
  private modelValue = '';

  private choiceValue = '';

  private sqlValue = '';

  private refusalValue = '';

  /** What a start answered without starting a run: an error outcome. */
  private immediateValue: PmmlAnswer | null = null;

  private readonly run: BackgroundRun<PmmlAnswer>;

  private readonly listeners = new Set<() => void>();

  constructor() {
    this.run = new BackgroundRun<PmmlAnswer>({ path: PMML_BACKGROUND_PATH, busyCode: PMML_BUSY_CODE, answerOf: pmmlAnswerOf, refusalText: mdxRefusalText }, () => this.notify());
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** The model the test is for, as its composite id. */
  model(): string {
    return this.modelValue;
  }

  setModel(id: string): void {
    if (id === this.modelValue) return;
    this.modelValue = id;
    this.notify();
  }

  /** The data source chosen: `dataset:<name>`, `verification` or `custom`, or `''` before a choice. */
  choice(): string {
    return this.choiceValue;
  }

  setChoice(choice: string): void {
    if (choice === this.choiceValue) return;
    this.choiceValue = choice;
    this.notify();
  }

  /** The SQL a custom source is written as. */
  sql(): string {
    return this.sqlValue;
  }

  setSql(value: string): void {
    if (value === this.sqlValue) return;
    this.sqlValue = value;
    this.notify();
  }

  /** Where the run on screen stands: `null` when none is, or when the last start answered an error outcome. */
  status(): BackgroundStatus | null {
    return this.immediateValue === null ? this.run.status() : null;
  }

  /** Whether a start is on its way or the run on screen still runs. */
  busy(): boolean {
    return this.run.busy();
  }

  /** The last answer: a start's error outcome, or the run's own. */
  answer(): PmmlAnswer | null {
    return this.immediateValue ?? this.run.answer();
  }

  /** The vendor's error text, or `''`. */
  message(): string {
    const answer = this.answer();
    return answer !== null && answer.outcome === 'error' ? answer.message : '';
  }

  /** The refusal on screen: a start's, or a failed run's. */
  refusal(): string {
    return this.refusalValue || (this.immediateValue === null ? this.run.refusal() : '');
  }

  /** The status line: the run's state while it runs or was canceled, else what an error, a stop or a cut answer reads as; `''` for a plain answer or none. */
  statusLine(): string {
    const status = this.status();
    if (status === 'running') return STRINGS.explorerSqlBackgroundRunning;
    if (status === 'canceled') return STRINGS.explorerSqlBackgroundCanceled;
    const answer = this.answer();
    if (answer === null) return '';
    if (answer.outcome === 'error') return STRINGS.analyticsMdxErrorLine;
    if (answer.outcome === 'stopped') return fill(pickCount(answer.seconds, STRINGS.explorerSqlStoppedOne, STRINGS.explorerSqlStopped), { s: answer.seconds });
    return answer.truncated ? STRINGS.analyticsMdxCut : '';
  }

  /** The body a start sends for the choice made, or `null` when nothing can be sent: no model, no choice, or a custom source with no SQL. */
  body(): Readonly<Record<string, string>> | null {
    if (this.modelValue === '' || this.choiceValue === '') return null;
    if (this.choiceValue === PMML_VERIFICATION) return { model: this.modelValue, source: PMML_VERIFICATION };
    if (this.choiceValue === PMML_CUSTOM) return this.sqlValue.trim() === '' ? null : { model: this.modelValue, source: PMML_CUSTOM, sql: this.sqlValue };
    if (!this.choiceValue.startsWith(PMML_DATASET_PREFIX)) return null;
    return { model: this.modelValue, source: 'dataset', dataSource: this.choiceValue.slice(PMML_DATASET_PREFIX.length) };
  }

  /** Run: send the test as chosen. Nothing is sent while a run is live or nothing can be sent. */
  async start(deps: PmmlTestDeps): Promise<void> {
    const body = this.body();
    if (this.run.busy() || body === null) return;
    this.immediateValue = null;
    this.refusalValue = '';
    await this.run.start(deps, JSON.stringify(body), (outcome) => this.settle(outcome));
  }

  /** Cancel the run on screen; polling goes on until it ends. */
  async cancel(deps: PmmlTestDeps): Promise<void> {
    await this.run.cancel(deps);
  }

  /** Stop polling the run: the page went. The run itself is left. */
  leave(): void {
    this.run.stop();
  }

  /** Follow the run on screen again: the page returned. */
  async poll(deps: PmmlTestDeps): Promise<void> {
    await this.run.poll(deps);
  }

  /** What a start came to, read before anything is attached: an error outcome is the answer; a refusal is the banner. */
  private settle(outcome: BackgroundStart): void {
    if (outcome.kind === 'answered') {
      this.immediateValue = pmmlAnswerOf(outcome.body);
      if (this.immediateValue === null) this.refusalValue = STRINGS.connectivityRequestRefused;
    } else if (outcome.kind === 'refused') {
      this.refusalValue = outcome.refusal;
    }
  }

  private notify(): void {
    for (const listener of this.listeners) listener();
  }
}
