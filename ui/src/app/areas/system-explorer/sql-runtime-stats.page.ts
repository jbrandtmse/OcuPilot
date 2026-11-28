import { ChangeDetectionStrategy, Component, DestroyRef, inject } from '@angular/core';

import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { ListPage } from '../../shell/list-page';
import { EXPLORER_SQL_RUNTIME_STATS, SQL_RUNTIME_STATS_PURGE, SQL_TUNING_ALL_TARGET, ScreenActionHandler } from '../../shell/screen-action-handler';

/**
 * SQL runtime statistics (Story 21.26, AD-5): the shared list page, with Purge statistics registered on it.
 *
 * **Purge statistics is this page's own action.** It names the namespace's whole store, not a row, so the shell's handler leaves the declared
 * action undrawn and this page registers it after injecting that handler. It starts the handler's own flow on the one target the tool reads,
 * `SQL_TUNING_ALL_TARGET`, reporting to the list's store: the handler warns first, sends it, and publishes the change event the list re-reads on
 * (AD-14).
 */
@Component({
  selector: 'app-sql-runtime-stats-page',
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
  template: `<app-list-page />`,
})
export class SqlRuntimeStatsPage {
  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own action: it is what warns and sends it. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === EXPLORER_SQL_RUNTIME_STATS) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stop = this.actions.register(EXPLORER_SQL_RUNTIME_STATS, SQL_RUNTIME_STATS_PURGE, () => this.onPurge());
    inject(DestroyRef).onDestroy(() => stop());
  }

  /** Start the purge on the namespace's whole store, never while another of the handler's dialogs is open. */
  protected onPurge(): void {
    if (this.store === null || this.handler.pending() !== null) return;
    this.handler.startFor(EXPLORER_SQL_RUNTIME_STATS, SQL_RUNTIME_STATS_PURGE, SQL_TUNING_ALL_TARGET, {}, this.store);
  }
}
