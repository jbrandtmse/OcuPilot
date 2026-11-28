import { ChangeDetectionStrategy, Component, DestroyRef, inject } from '@angular/core';
import { Router } from '@angular/router';

import { parentCriteria } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { DetailPage } from '../../shell/detail-page';
import {
  EXPLORER_SQL_CACHED_QUERIES,
  SQL_CACHED_QUERY_PURGE_NAMESPACE,
  SQL_CACHED_QUERY_PURGE_TABLE,
  SQL_TUNING_ALL_TARGET,
  ScreenActionHandler,
} from '../../shell/screen-action-handler';

/**
 * A table's Cached queries tab (Story 21.6, AD-5): the shared detail page, with Purge this table's cached queries and Purge all cached queries in
 * this namespace registered on it.
 *
 * **The two purges are this page's own.** Neither names a row, so the shell's handler leaves both declared actions undrawn and this page registers
 * them after injecting that handler -- whose construction registers the row's Purge. Each starts the handler's own flow, reporting to the tab's store:
 * the table's purge on the table the route names (the one criterion every tab of the table's group reads), the namespace's on
 * `SQL_TUNING_ALL_TARGET`. The handler warns first, sends it, and publishes the change event the tab re-reads on (AD-14).
 */
@Component({
  selector: 'app-sql-cached-queries-page',
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
export class SqlCachedQueriesPage {
  private readonly stores = inject(ScreenStores);

  private readonly router = inject(Router);

  /** Constructed before this page registers its own actions: it registers the row's Purge and is what sends all three. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly screen: ScreenDeclaration | null;

  private readonly store: ScreenStore | null;

  constructor() {
    this.screen = SCREENS.find((entry) => entry.descriptor === EXPLORER_SQL_CACHED_QUERIES) ?? null;
    this.store = this.screen === null ? null : this.stores.for(this.screen.descriptor, this.screen.refreshRates);
    const stops = [
      this.actions.register(EXPLORER_SQL_CACHED_QUERIES, SQL_CACHED_QUERY_PURGE_TABLE, () => this.onStart(SQL_CACHED_QUERY_PURGE_TABLE, this.table())),
      this.actions.register(EXPLORER_SQL_CACHED_QUERIES, SQL_CACHED_QUERY_PURGE_NAMESPACE, () => this.onStart(SQL_CACHED_QUERY_PURGE_NAMESPACE, SQL_TUNING_ALL_TARGET)),
    ];
    inject(DestroyRef).onDestroy(() => {
      for (const stop of stops) stop();
    });
  }

  /** The table the route names, as `Schema.Table`, or `''` where the route names none. */
  private table(): string {
    return this.screen === null ? '' : (parentCriteria(this.screen, this.router.url)['table'] ?? '');
  }

  /** Start `actionId` on `target`, never while another of the handler's dialogs is open. */
  protected onStart(actionId: string, target: string): void {
    if (this.store === null || target === '' || this.handler.pending() !== null) return;
    this.handler.startFor(EXPLORER_SQL_CACHED_QUERIES, actionId, target, {}, this.store);
  }
}
