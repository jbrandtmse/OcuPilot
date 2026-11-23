import { ChangeDetectionStrategy, Component, DestroyRef, inject } from '@angular/core';
import { Router } from '@angular/router';

import { parentCriteria } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { DetailPage } from '../../shell/detail-page';
import {
  EXPLORER_SQL_TABLE,
  SQL_TABLE_CLEAR_STATISTICS,
  SQL_TABLE_REBUILD_INDICES,
  SQL_TABLE_TUNE,
  ScreenActionHandler,
} from '../../shell/screen-action-handler';

/**
 * A SQL table's Table info tab (Story 21.25, AD-5): the shared detail page, with Rebuild all indices, Collect statistics and Clear fixed statistics
 * registered on it.
 *
 * **The three actions are this page's own.** None names a row, so the shell's handler leaves each declared action undrawn and this page registers them
 * after injecting that handler. Each starts the handler's own flow on the table the route names, reporting to the tab's store: the handler warns first,
 * sends it, and publishes the change event the tab re-reads on (AD-14).
 */
@Component({
  selector: 'app-sql-table-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DetailPage],
  // The height chain every page host carries, so the tab's viewport keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
  `,
  template: `<app-detail-page />`,
})
export class SqlTablePage {
  private readonly stores = inject(ScreenStores);

  private readonly router = inject(Router);

  /** Constructed before this page registers its own actions: it is what sends all three. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly screen: ScreenDeclaration | null;

  private readonly store: ScreenStore | null;

  constructor() {
    this.screen = SCREENS.find((entry) => entry.descriptor === EXPLORER_SQL_TABLE) ?? null;
    this.store = this.screen === null ? null : this.stores.for(this.screen.descriptor, this.screen.refreshRates);
    const stops = [SQL_TABLE_REBUILD_INDICES, SQL_TABLE_TUNE, SQL_TABLE_CLEAR_STATISTICS].map((actionId) =>
      this.actions.register(EXPLORER_SQL_TABLE, actionId, () => this.onStart(actionId))
    );
    inject(DestroyRef).onDestroy(() => {
      for (const stop of stops) stop();
    });
  }

  /** The table the route names, as `Schema.Table`, or `''` where the route names none. */
  private table(): string {
    return this.screen === null ? '' : (parentCriteria(this.screen, this.router.url)['table'] ?? '');
  }

  /** Start `actionId` on the route's table, never while another of the handler's dialogs is open. */
  protected onStart(actionId: string): void {
    const target = this.table();
    if (this.store === null || target === '' || this.handler.pending() !== null) return;
    this.handler.startFor(EXPLORER_SQL_TABLE, actionId, target, {}, this.store);
  }
}
