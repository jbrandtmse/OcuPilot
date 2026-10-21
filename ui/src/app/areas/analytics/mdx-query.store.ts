/**
 * Analytics' MDX query state (AD-19, Story 20.33): the statement being written, the cubes the picker
 * offers, the run on screen, the grid it answered and the listing a drill-through answered, the
 * statement a confirmation waits on, and the refusal on screen.
 *
 * **Framework-free.** It imports nothing from Angular; `mdx-query.page.ts` holds one per screen store
 * and hands it what it needs as plain functions, so the component spec drives it directly.
 *
 * **One owner-scoped background run** (`core/background-run.ts`, the SQL console's own machinery): Run
 * starts it and polls it until it ends, or Cancel stops it. The instance prepares and classifies the
 * statement before it spawns anything, so a start answers in one of four ways: a run id, an error
 * outcome (the vendor's own text), a refusal, or `confirm`.
 *
 * **Ask first** (AD-65). A `confirm` answer means the statement's text runs server-side code or SQL,
 * or could not be read, and nothing was started. The state holds the exact statement it was asked for
 * and the namespace it was asked in; Proceed sends that statement again with `confirmed: true` and
 * nothing else, and the first start of any statement never carries it. Cancel, leaving the page and a
 * namespace change drop the confirmation without sending anything.
 *
 * **A drill-through re-runs the last-run statement.** Each value cell of the grid starts a run of the
 * statement that produced the grid, with the cell's 1-based row and column positions in the grid shown
 * (the instance composes the drill from them), carrying the confirmation that statement's run was
 * given. The grid stays shown while the drill runs; its listing replaces the last one.
 *
 * **The answer is screen-only** (AD-39's sixth exception): cells, labels, a listing and the vendor's
 * error text live in this state and are rendered as text; none of it enters the screen's store, so none
 * of it reaches screen context.
 */

import type { JsonResult } from '../../core/api';
import { BackgroundRun, type BackgroundDeps, type BackgroundStart, type BackgroundStatus } from '../../core/background-run';
import { mdxAnswerOf, mdxConfirmOf, mdxStatusLineFor, type MdxAnswer, type MdxCells } from '../../core/mdx-answer';
import { screenForDescriptor } from '../../core/navigation';
import { screenReadPath } from '../../core/screen-read';
import type { SqlRows } from '../../core/sql-answer';
import { STRINGS } from '../../core/strings';

/** The MDX run's start route; its poll and cancel routes are `runPath`'s under it. */
export const MDX_BACKGROUND_PATH = '/api/ocupilot/analytics/mdx/background';

/** The machine code a start answers when the caller's own MDX run is still running. */
export const MDX_BUSY_CODE = 'ANALYTICS.MDX.BUSY';

/** The Cubes list's descriptor: its declared read feeds the cube picker (AD-5, AD-36). */
export const MDX_CUBES_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.AnalyticsCubeList';

/** How many cubes the picker asks for. */
export const MDX_CUBES_MAX_ROWS = 500;

/** The machine code a privilege denial carries (AD-39), whose pair the refusal names. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** The sentence each of this tool's refusal codes reads as, equal to the one the instance sends. */
const REFUSAL_SENTENCES = new Map<string, string>([
  ['ANALYTICS.NAMESPACE', STRINGS.analyticsRefusalNamespace],
  ['ANALYTICS.MDX.INPUT', STRINGS.analyticsRefusalMdxInput],
  ['ANALYTICS.MDX.KIND', STRINGS.analyticsRefusalMdxKind],
  ['ANALYTICS.MDX.AXES', STRINGS.analyticsRefusalMdxAxes],
  ['ANALYTICS.MDX.READONLY', STRINGS.analyticsRefusalMdxReadonly],
  ['ANALYTICS.MDX.BUSY', STRINGS.analyticsRefusalMdxBusy],
  ['ANALYTICS.MDX.FULL', STRINGS.analyticsRefusalMdxFull],
  ['ANALYTICS.MDX.NOTFOUND', STRINGS.analyticsRefusalMdxNotFound],
  ['ANALYTICS.MDX.LOST', STRINGS.analyticsRefusalMdxLost],
]);

/** The sentence a refusal shows: a privilege denial names the pair it lacks (AD-8), a known code its own, any other the envelope's (AD-39). */
export function mdxRefusalText(code: string | null, reason: string | null, detail: Readonly<Record<string, unknown>> | null): string {
  const pair = detail?.['failedPair'];
  if (code === NO_PRIVILEGE_CODE && typeof pair === 'string' && pair !== '') {
    return STRINGS.privilegeRequiresResource.split('<resource>').join(pair);
  }
  return (code === null ? undefined : REFUSAL_SENTENCES.get(code)) ?? reason ?? '';
}

/** The statement a new cube's pick writes: `SELECT FROM [<cube>]`, the name bracket-quoted. */
export function cubeStatement(cube: string): string {
  return `SELECT FROM [${cube.split(']').join(']]')}]`;
}

/** What the page hands the state: the API, the namespace calls are scoped to, and when a poll is sent. */
export type MdxQueryDeps = BackgroundDeps;

/** A statement the instance answered `confirm` for, waiting on the person's Proceed. */
export interface MdxConfirm {
  /** The exact statement the confirmation was asked for. */
  readonly statement: string;
  /** The constructs the instance found in it; empty for a statement it could not read. */
  readonly constructs: readonly string[];
  /** The namespace it was asked in. */
  readonly namespace: string;
}

/** One run a start was sent for: its statement, whether the person confirmed it, and whether it is a cell's drill. */
interface Intent {
  readonly statement: string;
  readonly confirmed: boolean;
  readonly drill: boolean;
}

/** The text of a cube read's row: its `Name`, or `''`. */
function cubeName(row: unknown): string {
  if (row === null || typeof row !== 'object') return '';
  const name = (row as Readonly<Record<string, unknown>>)['Name'];
  return typeof name === 'string' ? name : '';
}

export class MdxQueryState {
  private textValue = '';

  private cubesValue: readonly string[] = [];

  /** Which cube read is current; an answer to an older one is dropped. */
  private cubesGeneration = 0;

  /** The namespace the cubes on offer were read for, or `null` before any read. */
  private cubesScope: string | null = null;

  private readonly run: BackgroundRun<MdxAnswer> = new BackgroundRun<MdxAnswer>(
    { path: MDX_BACKGROUND_PATH, busyCode: MDX_BUSY_CODE, answerOf: mdxAnswerOf, refusalText: mdxRefusalText },
    () => this.adopt()
  );

  /** What a start answered without starting a run: an error outcome. */
  private immediateValue: MdxAnswer | null = null;

  /** The grid on screen, and the run whose statement it answers. */
  private cellsValue: MdxCells | null = null;

  private shownRun: Intent | null = null;

  /** The run on screen was started for this. */
  private attempt: Intent | null = null;

  /** Which attached run `attempt` belongs to, and the last whose grid was adopted, so a grid that was cleared is never adopted again. */
  private attemptSeq = 0;

  private adoptedSeq = 0;

  private confirmValue: MdxConfirm | null = null;

  /** Bumped when the page goes, so a confirmation on its way is dropped. */
  private askGeneration = 0;

  private refusalValue = '';

  private readonly listeners = new Set<() => void>();

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  text(): string {
    return this.textValue;
  }

  /** The cubes the picker offers, `[]` before the read answers or when it is refused. */
  cubes(): readonly string[] {
    return this.cubesValue;
  }

  /** The run's id, or `null` when none is on screen. */
  runId(): string | null {
    return this.run.id();
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
  answer(): MdxAnswer | null {
    return this.immediateValue ?? this.run.answer();
  }

  /** The grid on screen, or `null`. */
  cells(): MdxCells | null {
    return this.cellsValue;
  }

  /** The listing a drill-through or a typed DRILLTHROUGH answered, or `null`. */
  listing(): SqlRows | null {
    const answer = this.answer();
    return answer !== null && answer.outcome === 'rows' ? answer.result : null;
  }

  /** The vendor's error text, or `''`. */
  message(): string {
    const answer = this.answer();
    return answer !== null && answer.outcome === 'error' ? answer.message : '';
  }

  /** Whether the grid on screen can be drilled: the statement that produced it is known. */
  drillable(): boolean {
    return this.cellsValue !== null && this.shownRun !== null;
  }

  /** The statement a confirmation waits on, or `null`. */
  confirm(): MdxConfirm | null {
    return this.confirmValue;
  }

  /** The refusal on screen: a start's, or a failed run's. */
  refusal(): string {
    return this.refusalValue || (this.immediateValue === null ? this.run.refusal() : '');
  }

  /** The status line: the run's state while it runs or was canceled, else what the last answer reads as. */
  statusLine(): string {
    const status = this.status();
    if (status === 'running') return STRINGS.explorerSqlBackgroundRunning;
    if (status === 'canceled') return STRINGS.explorerSqlBackgroundCanceled;
    const answer = this.answer();
    if (answer !== null && (answer.outcome === 'error' || answer.outcome === 'stopped')) return mdxStatusLineFor(answer);
    if (this.cellsValue !== null) return mdxStatusLineFor(this.cellsValue);
    if (answer === null && status === 'failed') return '';
    return mdxStatusLineFor(answer);
  }

  setText(value: string): void {
    if (value === this.textValue) return;
    this.textValue = value;
    this.notify();
  }

  /** A cube's pick writes `SELECT FROM [<cube>]`, and only while the statement is empty. */
  pickCube(cube: string): void {
    if (cube === '' || this.textValue.trim() !== '') return;
    this.textValue = cubeStatement(cube);
    this.notify();
  }

  /** Read the cubes the picker offers, from the Cubes list's declared read in the namespace `deps` scopes to. */
  async loadCubes(deps: MdxQueryDeps): Promise<void> {
    const generation = ++this.cubesGeneration;
    const scope = deps.scope();
    this.cubesScope = scope;
    const screen = screenForDescriptor(MDX_CUBES_DESCRIPTOR);
    let names: readonly string[] = [];
    if (screen !== null && screen.read !== null) {
      const result: JsonResult<unknown> = await deps.api.requestJson<unknown>(screenReadPath(screen, MDX_CUBES_MAX_ROWS), { scope });
      if (generation !== this.cubesGeneration) return;
      const rows = result.kind === 'ok' && result.body !== null && typeof result.body === 'object' ? (result.body as Readonly<Record<string, unknown>>)['rows'] : null;
      if (Array.isArray(rows)) names = rows.map(cubeName).filter((name) => name !== '');
    }
    this.cubesValue = names;
    this.notify();
  }

  /** The namespace changed: a confirmation asked in another one is dropped, and the cubes are read again. */
  scopeChanged(deps: MdxQueryDeps): void {
    const scope = deps.scope();
    if (this.confirmValue !== null && this.confirmValue.namespace !== scope) this.cancelConfirm();
    if (scope !== this.cubesScope) void this.loadCubes(deps);
  }

  /** Run: send the statement as written, without a confirmation. */
  async runStatement(deps: MdxQueryDeps): Promise<void> {
    const statement = this.textValue;
    if (this.run.busy() || statement.trim() === '') return;
    await this.send(deps, { statement }, { statement, confirmed: false, drill: false });
  }

  /** Proceed: send the statement the confirmation was asked for, once more, with the confirmation. */
  async proceed(deps: MdxQueryDeps): Promise<void> {
    const pending = this.confirmValue;
    if (pending === null) return;
    this.confirmValue = null;
    this.notify();
    if (pending.namespace !== deps.scope() || this.run.busy()) return;
    await this.send(deps, { statement: pending.statement, confirmed: true }, { statement: pending.statement, confirmed: true, drill: false });
  }

  /** Cancel: the confirmation closes and nothing is sent. */
  cancelConfirm(): void {
    if (this.confirmValue === null) return;
    this.confirmValue = null;
    this.notify();
  }

  /**
   * Drill through the cell at `row` and `column` (1-based, as the grid shows them): the statement that
   * produced the grid is run again as a drill of that cell, with the confirmation that run was given.
   */
  async drill(deps: MdxQueryDeps, row: number, column: number): Promise<void> {
    const shown = this.shownRun;
    if (this.run.busy() || this.cellsValue === null || shown === null) return;
    const request: Record<string, unknown> = { statement: shown.statement, drill: { row, column } };
    if (shown.confirmed) request['confirmed'] = true;
    await this.send(deps, request, { statement: shown.statement, confirmed: shown.confirmed, drill: true });
  }

  /** Poll the run on screen once, and again every second while it runs. */
  poll(deps: MdxQueryDeps): Promise<void> {
    return this.run.poll(deps);
  }

  /** Cancel the run on screen; polling goes on until it reads canceled. */
  cancelRun(deps: MdxQueryDeps): Promise<void> {
    return this.run.cancel(deps);
  }

  /** The page goes: polling stops, and a confirmation open or on its way is dropped. The run itself is left. */
  leave(): void {
    this.askGeneration += 1;
    this.cubesGeneration += 1;
    this.cancelConfirm();
    this.run.stop();
  }

  /** Post `request` to the start route and settle what it came to. */
  private async send(deps: MdxQueryDeps, request: Record<string, unknown>, intent: Intent): Promise<void> {
    const asked = this.askGeneration;
    const namespace = deps.scope();
    this.refusalValue = '';
    await this.run.start(deps, JSON.stringify(request), (outcome) => this.settle(outcome, intent, asked, namespace));
  }

  /**
   * What a start came to, before the run it attached is polled: a run id makes `intent` the run on
   * screen, a `confirm` answer holds its statement, an error outcome is shown, and a refusal is the banner.
   */
  private settle(outcome: BackgroundStart, intent: Intent, asked: number, namespace: string): void {
    if (outcome.kind === 'attached') {
      this.attemptSeq += 1;
      this.attempt = intent;
      this.immediateValue = null;
      if (!intent.drill) this.clearCells();
      return;
    }
    if (outcome.kind === 'refused') {
      // A run this state did not start is attached by a busy refusal: its statement is not known here.
      if (outcome.attached) {
        this.attemptSeq += 1;
        this.attempt = null;
        this.immediateValue = null;
      }
      this.refusalValue = outcome.refusal;
      return;
    }
    const constructs = mdxConfirmOf(outcome.body);
    if (constructs !== null) {
      if (asked === this.askGeneration) this.confirmValue = { statement: intent.statement, constructs, namespace };
      return;
    }
    const answer = mdxAnswerOf(outcome.body);
    if (answer === null) {
      this.refusalValue = STRINGS.connectivityRequestRefused;
      return;
    }
    this.immediateValue = answer;
    if (!intent.drill) this.clearCells();
  }

  /** The run on screen has changed: a grid it ended with becomes the grid on screen. */
  private adopt(): void {
    const answer = this.run.answer();
    if (
      this.attemptSeq !== this.adoptedSeq &&
      this.run.status() === 'ended' &&
      this.attempt !== null &&
      !this.attempt.drill &&
      answer !== null &&
      answer.outcome === 'cells'
    ) {
      this.cellsValue = answer;
      this.shownRun = this.attempt;
      this.adoptedSeq = this.attemptSeq;
    }
    this.notify();
  }

  private clearCells(): void {
    this.cellsValue = null;
    this.shownRun = null;
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
