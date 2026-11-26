import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { ListPage } from '../../shell/list-page';
import {
  EXPLORER_SQL_INDEX_ANALYSIS,
  SQL_INDEX_ANALYSIS_GATHER,
  SQL_INDEX_ANALYSIS_PURGE,
  SQL_INDEX_ANALYSIS_RUN,
  SQL_TUNING_ALL_TARGET,
  ScreenActionHandler,
  type ActionValues,
} from '../../shell/screen-action-handler';
import { SqlIndexAnalysisDialog, type IndexAnalysisChoices } from './sql-index-analysis-dialog';

/** The text an action carries a yes or no as. */
function flag(value: boolean): string {
  return value ? 'true' : 'false';
}

/**
 * SQL index analyzer (Story 21.27, AD-5): the shared list page, with Gather statements, Run report and Purge analysis registered on it, and over it the
 * dialog of the one being asked while one is open.
 *
 * **The three actions are this page's own.** Each names the namespace's whole analysis, not a row, so the shell's handler leaves them undrawn and this
 * page registers them after injecting that handler. Purge analysis starts the handler's own warning on the one target the tools read,
 * `SQL_TUNING_ALL_TARGET`, reporting to the list's store. Gather statements and Run report open this page's dialog, which asks for the choices the action
 * declares and sends them through the handler's `sendFor` on the same target: a refusal stays in the dialog, each the instance's own sentence, and an
 * applied send closes it, the handler's change event re-reading the list (AD-14).
 */
@Component({
  selector: 'app-sql-index-analysis-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, SqlIndexAnalysisDialog],
  // The height chain every page host carries, so the list's viewport keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
  `,
  template: `<app-list-page />
    @if (showDialog) {
      <app-sql-index-analysis-dialog [mode]="mode()" [sending]="sending()" [refusal]="refusal()" (submitted)="onSubmit($event)" (cancelled)="onClose()" />
    }`,
})
export class SqlIndexAnalysisPage {
  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own actions: it is what warns and sends them. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  /** The action the open dialog confirms, or `null` while none is open. */
  private readonly open = signal<'gather' | 'run' | null>(null);

  protected readonly sending = signal(false);

  protected readonly refusal = signal('');

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === EXPLORER_SQL_INDEX_ANALYSIS) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stops = [
      this.actions.register(EXPLORER_SQL_INDEX_ANALYSIS, SQL_INDEX_ANALYSIS_GATHER, () => this.onOpen('gather')),
      this.actions.register(EXPLORER_SQL_INDEX_ANALYSIS, SQL_INDEX_ANALYSIS_RUN, () => this.onOpen('run')),
      this.actions.register(EXPLORER_SQL_INDEX_ANALYSIS, SQL_INDEX_ANALYSIS_PURGE, () => this.onPurge()),
    ];
    inject(DestroyRef).onDestroy(() => {
      for (const stop of stops) stop();
    });
  }

  protected get showDialog(): boolean {
    return this.open() !== null;
  }

  protected mode(): 'gather' | 'run' {
    return this.open() ?? 'gather';
  }

  /** Open the dialog for `action`, never over another dialog. */
  protected onOpen(action: 'gather' | 'run'): void {
    if (this.open() !== null || this.handler.pending() !== null) return;
    this.refusal.set('');
    this.open.set(action);
  }

  protected onClose(): void {
    this.open.set(null);
    this.refusal.set('');
  }

  /** Start the purge on the namespace's whole analysis, never while another of the handler's dialogs is open. */
  protected onPurge(): void {
    if (this.store === null || this.open() !== null || this.handler.pending() !== null) return;
    this.handler.startFor(EXPLORER_SQL_INDEX_ANALYSIS, SQL_INDEX_ANALYSIS_PURGE, SQL_TUNING_ALL_TARGET, {}, this.store);
  }

  /** One send through the handler's `sendFor`, a refusal kept in the dialog: the sentence the instance gave, else the envelope's own. */
  protected async onSubmit(choices: IndexAnalysisChoices): Promise<void> {
    const action = this.open();
    if (action === null || this.sending() || this.store === null) return;
    const values: ActionValues =
      action === 'gather'
        ? { SkipSystem: flag(choices.skipSystem), SkipInserts: flag(choices.skipInserts) }
        : {
            Report: choices.report,
            SkipSystem: flag(choices.skipSystem),
            SkipInserts: flag(choices.skipInserts),
            SkipIdKeys: flag(choices.skipIdKeys),
          };
    this.sending.set(true);
    this.refusal.set('');
    const applied = await this.handler.sendFor(EXPLORER_SQL_INDEX_ANALYSIS, action, SQL_TUNING_ALL_TARGET, values, { setRefusal: () => undefined });
    this.sending.set(false);
    if (this.open() === null) return;
    if (applied) {
      this.onClose();
      return;
    }
    this.refusal.set(this.handler.lastRefusal()?.reason ?? '');
  }
}
