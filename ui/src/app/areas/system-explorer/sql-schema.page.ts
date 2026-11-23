import { ChangeDetectionStrategy, Component, DestroyRef, inject } from '@angular/core';
import { Router } from '@angular/router';

import { parentCriteria } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { DetailPage } from '../../shell/detail-page';
import { EXPLORER_SQL_SCHEMA, SQL_SCHEMA_TUNE, ScreenActionHandler } from '../../shell/screen-action-handler';

/**
 * A SQL schema's Tables tab (Story 21.25, AD-5): the shared detail page, with Tune all tables registered on it.
 *
 * **The action is this page's own.** It names no row, so the shell's handler leaves it undrawn and this page registers it after injecting that handler.
 * It starts the handler's own flow on the schema the route names, reporting to the tab's store: the handler warns first, asking whether to clear
 * values, sends it, and publishes the change event the tab re-reads on (AD-14).
 */
@Component({
  selector: 'app-sql-schema-page',
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
export class SqlSchemaPage {
  private readonly stores = inject(ScreenStores);

  private readonly router = inject(Router);

  /** Constructed before this page registers its own action: it is what sends it. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly screen: ScreenDeclaration | null;

  private readonly store: ScreenStore | null;

  constructor() {
    this.screen = SCREENS.find((entry) => entry.descriptor === EXPLORER_SQL_SCHEMA) ?? null;
    this.store = this.screen === null ? null : this.stores.for(this.screen.descriptor, this.screen.refreshRates);
    const stop = this.actions.register(EXPLORER_SQL_SCHEMA, SQL_SCHEMA_TUNE, () => this.onStart());
    inject(DestroyRef).onDestroy(stop);
  }

  /** The schema the route names, or `''` where the route names none. */
  private schema(): string {
    return this.screen === null ? '' : (parentCriteria(this.screen, this.router.url)['schema'] ?? '');
  }

  /** Start Tune all tables on the route's schema, never while another of the handler's dialogs is open. */
  protected onStart(): void {
    const target = this.schema();
    if (this.store === null || target === '' || this.handler.pending() !== null) return;
    this.handler.startFor(EXPLORER_SQL_SCHEMA, SQL_SCHEMA_TUNE, target, {}, this.store);
  }
}
