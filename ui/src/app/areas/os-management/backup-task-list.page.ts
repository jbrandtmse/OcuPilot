import { ChangeDetectionStrategy, Component, DestroyRef, inject } from '@angular/core';

import { BACKUP_FREEZE_ACTION_ID, BACKUP_THAW_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { ListPage } from '../../shell/list-page';
import { BACKUP_FREEZE, BACKUP_TASK_LIST, BACKUP_THAW, BACKUP_WRITES_TARGET, ScreenActionHandler } from '../../shell/screen-action-handler';

/**
 * Backup tasks (Story 21.2, AD-5): the shared list page, with Freeze writes and Thaw writes registered on it.
 *
 * **The two actions are this page's own.** Each names the instance's database writes, not a row, so the shell's handler leaves both declared
 * actions undrawn and this page registers them at screen level after injecting that handler -- whose construction registers Run, the row action.
 * Each starts the handler's own flow on the one target the tools read, `BACKUP_WRITES_TARGET`, reporting to the list's store: Freeze writes opens
 * the warning that asks for the suspend limit, and Thaw writes is sent at once. The frozen banner's action runs the thaw registered here
 * (`BACKUP_THAW_ACTION_ID` is the declared id), and the list re-reads on the change event the handler publishes (AD-14), which is where the
 * banner appears and clears.
 */
@Component({
  selector: 'app-backup-task-list-page',
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
export class BackupTaskListPage {
  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own actions: it registers Run and is what sends all three. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === BACKUP_TASK_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stops = [
      this.actions.register(BACKUP_TASK_LIST, BACKUP_FREEZE_ACTION_ID, () => this.onStart(BACKUP_FREEZE)),
      this.actions.register(BACKUP_TASK_LIST, BACKUP_THAW_ACTION_ID, () => this.onStart(BACKUP_THAW)),
    ];
    inject(DestroyRef).onDestroy(() => {
      for (const stop of stops) stop();
    });
  }

  /** Start `actionId` on the instance's database writes, never while another of the handler's dialogs is open. */
  protected onStart(actionId: string): void {
    if (this.store === null || this.handler.pending() !== null) return;
    this.handler.startFor(BACKUP_TASK_LIST, actionId, BACKUP_WRITES_TARGET, {}, this.store);
  }
}
