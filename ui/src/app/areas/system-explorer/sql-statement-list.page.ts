import { ChangeDetectionStrategy, Component, DestroyRef, inject } from '@angular/core';

import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { ListPage } from '../../shell/list-page';
import { EXPLORER_SQL_STATEMENT_LIST, SQL_STATEMENT_CLEAN, SQL_TUNING_ALL_TARGET, ScreenActionHandler } from '../../shell/screen-action-handler';

/**
 * SQL statements (Story 21.6, AD-5): the shared list page, with Clean stale statements registered on it.
 *
 * **Clean stale statements is this page's own action.** It names the namespace's whole statement index, not a row, so the shell's handler leaves
 * the declared action undrawn and this page registers it after injecting that handler -- whose construction registers the four row actions.
 * It starts the handler's own flow on the one target the tool reads, `SQL_TUNING_ALL_TARGET`, reporting to the list's store: the handler warns
 * first, sends it, and publishes the change event the list re-reads on (AD-14).
 */
@Component({
  selector: 'app-sql-statement-list-page',
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
export class SqlStatementListPage {
  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own action: it registers the four row actions and is what sends all five. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === EXPLORER_SQL_STATEMENT_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stop = this.actions.register(EXPLORER_SQL_STATEMENT_LIST, SQL_STATEMENT_CLEAN, () => this.onClean());
    inject(DestroyRef).onDestroy(() => stop());
  }

  /** Start the clean on the namespace's index, never while another of the handler's dialogs is open. */
  protected onClean(): void {
    if (this.store === null || this.handler.pending() !== null) return;
    this.handler.startFor(EXPLORER_SQL_STATEMENT_LIST, SQL_STATEMENT_CLEAN, SQL_TUNING_ALL_TARGET, {}, this.store);
  }
}
