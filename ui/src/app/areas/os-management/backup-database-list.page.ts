import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { ListPage } from '../../shell/list-page';
import { BACKUP_ADD_DATABASE, BACKUP_DATABASE_LIST, ScreenActionHandler } from '../../shell/screen-action-handler';
import { BackupAddDatabaseDialog } from './backup-add-database-dialog';

/**
 * Backup database list (Story 21.2, AD-5): the shared list page and, over it, the Add database dialog while one is open.
 *
 * **Add database is this page's own action.** The shell's handler leaves it undrawn, so this page registers it on the list after injecting that
 * handler -- whose construction registers Remove -- and every surface that offers it opens this page's dialog. The typed name is sent through the
 * handler's `sendFor`, which carries no value: the database is the action's target. Refusals stay in the dialog, each the instance's own sentence;
 * an applied add closes it, and the handler's change event re-reads the list (AD-14).
 */
@Component({
  selector: 'app-backup-database-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, BackupAddDatabaseDialog],
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
      <app-backup-add-database-dialog
        [sending]="sending()"
        [refusal]="refusal()"
        (submitted)="onAdd($event)"
        (cancelled)="onClose()"
      />
    }`,
})
export class BackupDatabaseListPage {
  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own action: it registers Remove and is what sends the add. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  protected readonly dialogOpen = signal(false);

  protected readonly sending = signal(false);

  protected readonly refusal = signal('');

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === BACKUP_DATABASE_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stop = this.actions.register(BACKUP_DATABASE_LIST, BACKUP_ADD_DATABASE, () => this.onOpen());
    inject(DestroyRef).onDestroy(() => stop());
  }

  protected get showDialog(): boolean {
    return this.dialogOpen();
  }

  /** Open the dialog, never over another dialog. */
  protected onOpen(): void {
    if (this.dialogOpen() || this.handler.pending() !== null) return;
    this.refusal.set('');
    this.dialogOpen.set(true);
  }

  protected onClose(): void {
    this.dialogOpen.set(false);
    this.refusal.set('');
  }

  /** One add through the handler's `sendFor`, a refusal kept in the dialog: the sentence the instance gave, else the envelope's own. */
  protected async onAdd(name: string): Promise<void> {
    if (this.sending() || this.store === null) return;
    this.sending.set(true);
    this.refusal.set('');
    const applied = await this.handler.sendFor(BACKUP_DATABASE_LIST, BACKUP_ADD_DATABASE, name, undefined, { setRefusal: () => undefined });
    this.sending.set(false);
    if (!this.dialogOpen()) return;
    if (applied) {
      this.onClose();
      return;
    }
    this.refusal.set(this.handler.lastRefusal()?.reason ?? '');
  }
}
