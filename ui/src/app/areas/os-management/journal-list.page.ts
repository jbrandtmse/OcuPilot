import { ChangeDetectionStrategy, Component, DestroyRef, effect, inject, signal } from '@angular/core';

import { JOURNAL_SWITCH_DIRECTORY_ACTION_ID, JOURNAL_SWITCH_FILE_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import {
  JOURNAL_CURRENT_TARGET,
  JOURNAL_INTEGRITY,
  JOURNAL_LIST,
  JOURNAL_SWITCH_DIRECTORY,
  JOURNAL_SWITCH_FILE,
  ScreenActionHandler,
  type ActionProgress,
} from '../../shell/screen-action-handler';
import { operationLine } from './database-operation';

/** What a finished integrity check answered for the page alone (AD-39's fifth exception). */
export interface IntegrityOutcome {
  readonly file: string;
  readonly errors: boolean;
  readonly lines: readonly string[];
}

/**
 * A finished check's `output` as the page renders it: its console lines, strings only, and whether
 * the check found errors. A check that answered no output reads as clean with no lines.
 */
export function integrityOutcome(file: string, output: unknown): IntegrityOutcome {
  const record = output !== null && typeof output === 'object' ? (output as Record<string, unknown>) : {};
  const raw = record['lines'];
  const lines = Array.isArray(raw) ? raw.filter((line): line is string => typeof line === 'string') : [];
  return { file, errors: record['errors'] === true, lines };
}

/** The verdict line of `outcome`: "Errors were found in <file>." or "No errors were found in <file>.". */
export function verdictLine(outcome: IntegrityOutcome): string {
  const template = outcome.errors ? STRINGS.journalIntegrityErrors : STRINGS.journalIntegrityClean;
  return template.replace('<file>', () => outcome.file);
}

/**
 * Journals (Story 18.5, AD-5): the shared list page and, above it, the integrity check's status line.
 *
 * **The two switches are this page's own.** Each names the journal the instance writes now, not a
 * row, so the shell's handler leaves both declared actions undrawn and this page registers them at
 * screen level after injecting that handler -- whose construction registers Check integrity, the row
 * action. Each starts the handler's own flow on the one target the tools read,
 * `JOURNAL_CURRENT_TARGET`, with the list's first row -- the file the instance writes now, which the
 * vendor's list answers first -- as the row its warning names, reporting to the list's store. The list
 * re-reads on the change event the handler publishes (AD-14), which is where the new file appears.
 *
 * **The integrity check's line.** While its request is in flight the line reads "Integrity check
 * running on the instance since <time>"; when the instance answers it done, "Integrity check
 * finished." followed by the verdict for the file and, on errors, the check's own lines as text; when
 * it outlasts the port's wait, the still-running sentence (AD-26). The lines are the write's `output`,
 * which reaches this page alone (AD-39's fifth exception) and is kept nowhere else.
 */
@Component({
  selector: 'app-journal-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage],
  // The height chain every page host carries, so the list's viewport keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
  `,
  template: `<div role="status" data-journal="operation">
      <p class="ocu-namespace-copy-status">{{ statusLine }}</p>
      @if (hasVerdict) {
        <p class="ocu-namespace-copy-status" data-journal="verdict">{{ verdict }}</p>
      }
      @if (hasLines) {
        <pre class="ocu-log-raw" data-journal="lines">{{ linesText }}</pre>
      }
    </div>
    <app-list-page />`,
})
export class JournalListPage {
  private readonly stores = inject(ScreenStores);

  /**
   * Constructed before this page registers its own actions: its constructor registers Check
   * integrity, and it is what sends the switches.
   */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly screen: ScreenDeclaration | null;

  private readonly store: ScreenStore | null;

  /** The last integrity check this page saw: how it stands, and what it answered once finished. */
  private readonly check = signal<ActionProgress | null>(null);

  private readonly outcome = signal<IntegrityOutcome | null>(null);

  constructor() {
    this.screen = SCREENS.find((entry) => entry.descriptor === JOURNAL_LIST) ?? null;
    this.store = this.screen === null ? null : this.stores.for(this.screen.descriptor, this.screen.refreshRates);
    const stops = [
      this.actions.register(JOURNAL_LIST, JOURNAL_SWITCH_FILE_ACTION_ID, () => this.onSwitch(JOURNAL_SWITCH_FILE)),
      this.actions.register(JOURNAL_LIST, JOURNAL_SWITCH_DIRECTORY_ACTION_ID, () => this.onSwitch(JOURNAL_SWITCH_DIRECTORY)),
    ];
    inject(DestroyRef).onDestroy(() => {
      for (const stop of stops) stop();
    });
    // The output is read once, as the check's progress turns finished: `lastOutput` is the answer of
    // the request that progress describes, set before it.
    effect(() => {
      const progress = this.handler.progress();
      if (progress === null || progress.descriptor !== JOURNAL_LIST || progress.actionId !== JOURNAL_INTEGRITY) return;
      if (progress.state === 'refused') {
        this.check.set(null);
        this.outcome.set(null);
        return;
      }
      this.check.set(progress);
      this.outcome.set(progress.state === 'finished' ? integrityOutcome(progress.target, this.handler.lastOutput()) : null);
    });
  }

  /**
   * Start a switch on its one target, naming the list's first row in its warning, never while
   * another of the handler's dialogs is open.
   */
  protected onSwitch(actionId: string): void {
    if (this.store === null || this.handler.pending() !== null) return;
    this.handler.startFor(JOURNAL_LIST, actionId, JOURNAL_CURRENT_TARGET, this.newestRow(), this.store);
  }

  /** The integrity check's running, finished or still-running line, or `''` before any. */
  protected get statusLine(): string {
    const check = this.check();
    if (check === null) return '';
    return operationLine(STRINGS.databaseIntegrityCheck, check.state, check.since);
  }

  protected get hasVerdict(): boolean {
    return this.outcome() !== null;
  }

  protected get verdict(): string {
    const outcome = this.outcome();
    return outcome === null ? '' : verdictLine(outcome);
  }

  protected get hasLines(): boolean {
    return (this.outcome()?.lines.length ?? 0) > 0;
  }

  /** The check's own lines, one per line, rendered as text. */
  protected get linesText(): string {
    return (this.outcome()?.lines ?? []).join('\n');
  }

  /** The list's first row, which the vendor's list answers as the file the instance writes now, or `null`. */
  private newestRow(): Readonly<Record<string, unknown>> | null {
    const row = this.store?.data()[0];
    return row !== null && typeof row === 'object' ? (row as Readonly<Record<string, unknown>>) : null;
  }
}
