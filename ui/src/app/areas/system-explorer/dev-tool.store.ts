/**
 * System Explorer's Code metrics, Document hashes, Compare namespaces and Unit tests state (AD-19, Stories 24.1, 24.8 and 24.5): what the form holds,
 * over the search last sent and the one `RefreshRead` the page binds, which `SentSearchState` holds.
 *
 * **Framework-free.** It imports nothing from Angular; `dev-tool.page.ts` holds one per screen store,
 * so a return to the screen finds the last search.
 *
 * **No read until there is a search.** The bound read answers no rows, and sends nothing, until Search
 * has been pressed with a pattern or an agent's arrival has named one; from then on every read -- the
 * framework's re-read on a change to a class or routine, a namespace switch, Refresh -- runs that same
 * search again (AD-14).
 */

import type { ScreenArrival } from '../../core/screen-arrival';
import { STRINGS } from '../../core/strings';
import type { ActionRefusal, ActionSink, ActionValues } from '../../shell/screen-action-handler';
import { SentSearchState } from './code-search.store';
import { fillPlaceholders } from './code-list.store';

/** The two criteria every screen declares, and the other namespace Compare namespaces adds. */
export const SPEC_PARAM = 'spec';
export const GENERATED_PARAM = 'generated';
export const TARGET_PARAM = 'target';

/** The generated choice's two values. */
export const GENERATED_NO = 'no';
export const GENERATED_YES = 'yes';

/** The action Unit tests declares (Story 24.5), its one target and its two declared values (AD-56 (ii)). */
export const RUN_ACTION = 'run';
export const RUN_TARGET = 'unittests';
export const TESTS_PARAM = 'tests';
export const LEVEL_PARAM = 'level';

/** What a run's target names, in the order the level choice lists them; `class` is the form's default. */
export const LEVEL_PACKAGE = 'package';
export const LEVEL_CLASS = 'class';
export const LEVEL_METHOD = 'method';

/** The level choice's published label for `level`, which the form shows in place of the value the instance takes. */
export function levelLabel(level: string): string {
  if (level === LEVEL_PACKAGE) return STRINGS.explorerUnitTestsLevelPackage;
  if (level === LEVEL_METHOD) return STRINGS.explorerSqlColumnMethod;
  return STRINGS.explorerClassDocumentLabel;
}

/** What sends the run's screen action and reports the refusal it was last answered with: the shell's action handler. */
export interface RunSender {
  sendFor(descriptor: string, actionId: string, target: string, values?: ActionValues, sink?: ActionSink, scope?: string): Promise<boolean>;
  lastRefusal(): ActionRefusal | null;
}

/**
 * The form's pattern and generated choice, and the other namespace when `targeted`, over Search's sent search,
 * refusal and read (`code-search.store.ts`).
 */
export class DevToolState extends SentSearchState {
  private specValue = '';

  private generatedValue = GENERATED_NO;

  private targetValue = '';

  constructor(private readonly targeted = false) {
    super();
  }

  /** Whether the screen declares the other namespace, which a search then needs. */
  hasTarget(): boolean {
    return this.targeted;
  }

  target(): string {
    return this.targetValue;
  }

  setTarget(value: string): void {
    this.targetValue = value;
    this.notify();
  }

  spec(): string {
    return this.specValue;
  }

  includeGenerated(): boolean {
    return this.generatedValue === GENERATED_YES;
  }

  setSpec(value: string): void {
    this.specValue = value;
    this.notify();
  }

  setIncludeGenerated(on: boolean): void {
    this.generatedValue = on ? GENERATED_YES : GENERATED_NO;
    this.notify();
  }

  private testsValue = '';

  private levelValue = LEVEL_CLASS;

  private confirmingValue = false;

  private runningValue = false;

  private runRefusalValue = '';

  /** The tests the Run form names: a package, a class or `Class:Method`. */
  tests(): string {
    return this.testsValue;
  }

  setTests(value: string): void {
    this.testsValue = value;
    this.notify();
  }

  /** What the tests name, one of `LEVEL_PACKAGE`, `LEVEL_CLASS` and `LEVEL_METHOD`. */
  level(): string {
    return this.levelValue;
  }

  setLevel(value: string): void {
    this.levelValue = value;
    this.notify();
  }

  /** Whether the warning dialog is open: Run was pressed and nothing is sent until it is confirmed. */
  confirming(): boolean {
    return this.confirmingValue;
  }

  /** Whether a confirmed run is in flight. */
  running(): boolean {
    return this.runningValue;
  }

  /** The sentence the instance refused the last confirmed run with, or `''`. */
  runRefusal(): string {
    return this.runRefusalValue;
  }

  /** The runs list is read from the first read on, with no search: Unit tests lists what the namespace recorded. */
  listRuns(): void {
    if (!this.searched()) this.send({});
  }

  /** Open the warning dialog and send nothing: answers false, opening nothing, with no tests named or a run in flight. */
  askRun(): boolean {
    if (this.testsValue.trim() === '' || this.runningValue) return false;
    this.runRefusalValue = '';
    this.confirmingValue = true;
    this.notify();
    return true;
  }

  /** Close the warning dialog. Nothing was sent. */
  cancelRun(): void {
    if (!this.confirmingValue) return;
    this.confirmingValue = false;
    this.notify();
  }

  /**
   * Send the confirmed run as the screen action, once: the tests and the level, in the namespace the screen was opened in. A
   * refusal keeps the sentence the instance gave, `EXPLORER.UNITTEST.OFF` included, and the form as it was. Answers whether the
   * run was applied; the runs list re-reads by the change event the handler publishes.
   */
  async proceed(sender: RunSender, descriptor: string, scope: string): Promise<boolean> {
    if (!this.confirmingValue) return false;
    this.confirmingValue = false;
    this.runningValue = true;
    this.runRefusalValue = '';
    this.notify();
    let refused = '';
    const sink: ActionSink = { setRefusal: (reason) => (refused = reason) };
    const values: ActionValues = { [TESTS_PARAM]: this.testsValue.trim(), [LEVEL_PARAM]: this.levelValue };
    const applied = await sender.sendFor(descriptor, RUN_ACTION, RUN_TARGET, values, sink, scope);
    this.runningValue = false;
    if (!applied) this.runRefusalValue = sender.lastRefusal()?.reason || refused || STRINGS.connectivityRequestRefused;
    this.notify();
    return applied;
  }

  /** Show an agent arrival's tests and level in the Run form; nothing is run. */
  useRunArrival(arrival: ScreenArrival): void {
    const criteria = arrival.criteria;
    this.testsValue = typeof criteria[TESTS_PARAM] === 'string' ? criteria[TESTS_PARAM] : '';
    const level = criteria[LEVEL_PARAM];
    this.levelValue = level === LEVEL_PACKAGE || level === LEVEL_METHOD ? level : LEVEL_CLASS;
    this.notify();
  }

  /** Send the form as shown from the next read on: answers false, sending nothing, with no pattern or, where one is declared, no other namespace. */
  search(): boolean {
    if (this.specValue.trim() === '' || (this.targeted && this.targetValue === '')) return false;
    this.send({
      ...(this.targeted ? { [TARGET_PARAM]: this.targetValue } : {}),
      [SPEC_PARAM]: this.specValue,
      [GENERATED_PARAM]: this.generatedValue,
    });
    return true;
  }

  /**
   * Run an agent arrival's search: the declared criteria it carries, shown in the form. An arrival with no
   * pattern sends nothing and drops the search it replaces.
   */
  useArrival(arrival: ScreenArrival): boolean {
    const criteria = arrival.criteria;
    this.specValue = typeof criteria[SPEC_PARAM] === 'string' ? criteria[SPEC_PARAM] : '';
    this.generatedValue = criteria[GENERATED_PARAM] === GENERATED_YES ? GENERATED_YES : GENERATED_NO;
    if (this.targeted) this.targetValue = typeof criteria[TARGET_PARAM] === 'string' ? criteria[TARGET_PARAM] : '';
    if (this.search()) return true;
    this.send(null);
    return false;
  }
}

/** The action Compare namespaces declares over its checked rows (Story 24.9). */
export const PROMOTE_ACTION = 'promote';

/** One document a promote answered: its name, what became of it, and the reason a failed one gives. */
export interface PromotedDocument {
  readonly document: string;
  readonly outcome: string;
  readonly reason: string;
}

/** What a promote's `output` carries (AD-39's fifth exception): each document's outcome, the compile's lines and whether it stopped. */
export interface PromoteOutput {
  readonly documents: readonly PromotedDocument[];
  readonly lines: readonly string[];
  readonly errors: boolean;
  readonly stopped: boolean;
}

function text(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

/** The promote answer `output` holds, or `null` for an answer that is not one. */
export function promoteOutputOf(output: unknown): PromoteOutput | null {
  if (output === null || typeof output !== 'object') return null;
  const record = output as Record<string, unknown>;
  if (!Array.isArray(record['documents'])) return null;
  const documents = (record['documents'] as readonly unknown[]).map((entry) => {
    const document = entry !== null && typeof entry === 'object' ? (entry as Record<string, unknown>) : {};
    return { document: text(document['Document']), outcome: text(document['Outcome']), reason: text(document['Reason']) };
  });
  const lines = Array.isArray(record['lines']) ? (record['lines'] as readonly unknown[]).filter((line): line is string => typeof line === 'string') : [];
  return { documents, lines, errors: record['errors'] === true, stopped: record['stopped'] === true };
}

/** The documents a promote wrote: those answered replaced or added. */
function writtenCount(output: PromoteOutput): number {
  return output.documents.filter((entry) => entry.outcome === STRINGS.explorerPromoteReplaced || entry.outcome === STRINGS.explorerPromoteAdded).length;
}

/** The status line a promote leaves: the document it stopped at, the compile's errors, or the count it wrote. */
export function promoteStatus(output: PromoteOutput): string {
  if (output.stopped) {
    const failed = output.documents.find((entry) => entry.outcome === STRINGS.explorerPromoteFailed);
    return fillPlaceholders(STRINGS.explorerPromoteStopped, { document: failed?.document ?? '' });
  }
  return fillPlaceholders(output.errors ? STRINGS.explorerPromoteDoneErrors : STRINGS.explorerPromoteDone, { n: writtenCount(output) });
}

/** The output pane's lines: each document's outcome and, for a failed one, its reason, then the compile's console lines. */
export function promoteLines(output: PromoteOutput): readonly string[] {
  const documents = output.documents.map((entry) => `${entry.outcome}: ${entry.document}${entry.reason === '' ? '' : ` -- ${entry.reason}`}`);
  return [...documents, ...output.lines];
}
