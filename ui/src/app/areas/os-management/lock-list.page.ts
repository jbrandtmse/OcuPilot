import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { rowFor } from '../../core/table-model';
import { ListPage } from '../../shell/list-page';
import { LOCK_LIST, LOCK_REMOVE, ScreenActionHandler } from '../../shell/screen-action-handler';
import { LockRemoveDialog, type LockRemoveRequest } from './lock-remove-dialog';

/** The value every removal sends beside the lock's id, under the name its tools declare (AD-56). */
export const REMOVE_IN_TRANSACTION_VALUE = 'RemoveInTransaction';

/** The envelope code the instance answers a removal with while the owner is in a transaction (DW-1073). */
export const LOCK_IN_TRANSACTION_CODE = 'LOCK.INTRANSACTION';

/** The row the open dialog removes from: its id, its Process ID cell, its reference and its owner's kind. */
interface RemoveTarget {
  readonly id: string;
  readonly pid: string;
  readonly reference: string;
  readonly remote: boolean;
}

/** `value` as the text a cell shows, or `''`. */
function text(value: unknown): string {
  return typeof value === 'string' || typeof value === 'number' ? String(value) : '';
}

/**
 * The Locks list with its Remove locks (Story 16.12, AD-5): the shared list page and, over it, the
 * removal dialog while one is open.
 *
 * **Remove locks is this page's own action.** The shell's handler leaves the three removals undrawn,
 * so this page registers `remove` on the Locks list after injecting that handler -- whose construction
 * registers every other declared row action -- and every surface that offers it opens this page's
 * dialog on the selected row. The dialog's chosen scope is the action this page sends, through the
 * handler's `sendFor`, with `RemoveInTransaction` `'false'`, or `'true'` once the instance has answered
 * that the owner is in a transaction and the person chose Remove anyway.
 *
 * **Refusals stay in the dialog.** `LOCK.INTRANSACTION` turns the dialog's warning on; any other
 * refusal is its sentence in the dialog. An applied removal closes the dialog, and the handler's change
 * event re-reads the list (AD-14).
 */
@Component({
  selector: 'app-lock-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, LockRemoveDialog],
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
    @if (openTarget; as target) {
      <app-lock-remove-dialog
        [pid]="target.pid"
        [reference]="target.reference"
        [remote]="target.remote"
        [sending]="sending()"
        [warned]="warned()"
        [refusal]="refusal()"
        (submitted)="onRemove($event)"
        (cancelled)="onClose()"
      />
    }`,
})
export class LockListPage {
  private readonly stores = inject(ScreenStores);

  /**
   * Constructed before this page registers its own action: its constructor registers every other
   * declared row action, and it is what sends the removal.
   */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  /** The row the open dialog removes from, or `null` while none is open. */
  protected readonly removeTarget = signal<RemoveTarget | null>(null);

  protected readonly sending = signal(false);

  protected readonly warned = signal(false);

  protected readonly refusal = signal('');

  /** The row the open dialog removes from, `null` (falsy) while none is open. */
  protected get openTarget(): RemoveTarget | null {
    return this.removeTarget();
  }

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === LOCK_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stop = this.actions.register(LOCK_LIST, LOCK_REMOVE, () => this.onOpen());
    inject(DestroyRef).onDestroy(() => stop());
  }

  /**
   * Open the dialog on the selected row, never over another dialog. With no selection nothing opens:
   * the surfaces already draw the action unavailable.
   */
  protected onOpen(): void {
    if (this.removeTarget() !== null || this.handler.pending() !== null) return;
    const screen = SCREENS.find((entry) => entry.descriptor === LOCK_LIST);
    const store = this.store;
    if (screen === undefined || store === null) return;
    const selected = store.selection()[0] ?? '';
    const row = rowFor(store.data(), screen, selected);
    if (row === null) return;
    this.warned.set(false);
    this.refusal.set('');
    this.removeTarget.set({ id: selected, pid: text(row['Pid']), reference: text(row['Reference']), remote: row['RemoteOwner'] === true });
  }

  protected onClose(): void {
    this.removeTarget.set(null);
    this.warned.set(false);
    this.refusal.set('');
  }

  /**
   * One removal through the handler's `sendFor`, the refusal kept in the dialog rather than on the
   * list's banner. `LOCK.INTRANSACTION` arms the override for the next Remove.
   */
  protected async onRemove(request: LockRemoveRequest): Promise<void> {
    const target = this.removeTarget();
    if (target === null || this.sending()) return;
    this.sending.set(true);
    this.refusal.set('');
    const applied = await this.handler.sendFor(
      LOCK_LIST,
      request.scope,
      target.id,
      { [REMOVE_IN_TRANSACTION_VALUE]: request.override ? 'true' : 'false' },
      { setRefusal: () => undefined }
    );
    this.sending.set(false);
    if (applied) {
      this.onClose();
      return;
    }
    const refused = this.handler.lastRefusal();
    if (refused?.code === LOCK_IN_TRANSACTION_CODE) {
      this.warned.set(true);
      return;
    }
    this.refusal.set(refused?.reason ?? '');
  }
}
