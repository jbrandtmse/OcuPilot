import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal, viewChild } from '@angular/core';

import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { rowFor } from '../../core/table-model';
import { ListPage } from '../../shell/list-page';
import {
  SCREEN_PERMISSIONS,
  SCREEN_PERMISSIONS_ADD,
  SCREEN_PERMISSIONS_REMOVE,
  ScreenActionHandler,
} from '../../shell/screen-action-handler';
import { ScreenPermissionsDialog } from './screen-permissions-dialog';

/** The one value Add and Remove send beside the screen's identifier, under the name their tools declare (AD-56). */
export const PAIR_VALUE = 'Pair';

/** The permission a classic page's custom resource is required at (AD-44). */
const CLASSIC_PERMISSION = 'USE';

/** The screen the open dialog changes and what the list last read about it. */
interface PermissionTarget {
  readonly id: string;
  readonly pairs: readonly string[];
  readonly classic: string;
  readonly adjustable: boolean;
}

/** `value` as text, or `''`. */
function text(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

/** The pairs of a set the list spells `a:USE, b:READ`. */
function split(set: string): readonly string[] {
  return set
    .split(',')
    .map((pair) => pair.trim())
    .filter((pair) => pair !== '');
}

/**
 * Screen permissions (Story 20.15, AD-64): the shared list page, and, over it, the Change permissions
 * dialog while one is open.
 *
 * **Change permissions is this page's own action.** The shell's handler leaves Add and Remove undrawn, so
 * this page registers Add on the list after injecting that handler -- whose construction registers Reset --
 * and every surface that offers it opens this page's dialog on the selected row. The dialog's Add and
 * Remove each go through the handler's `sendFor`, one pair at a time under the value `Pair`, and the
 * handler's change event re-reads the list (AD-14); the dialog is drawn from that re-read, never from a
 * set this page computed.
 *
 * **Refusals stay in the dialog**, each the instance's own sentence: the one it gave the `Pair` field,
 * else the envelope's own reason.
 */
@Component({
  selector: 'app-screen-permissions-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, ScreenPermissionsDialog],
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
      <app-screen-permissions-dialog
        [screen]="target.id"
        [pairs]="target.pairs"
        [classic]="target.classic"
        [adjustable]="target.adjustable"
        [sending]="sending()"
        [refusal]="refusal()"
        (added)="onAdd($event)"
        (removed)="onRemove($event)"
        (cancelled)="onClose()"
      />
    }`,
})
export class ScreenPermissionsPage {
  private readonly stores = inject(ScreenStores);

  /**
   * Constructed before this page registers its own action: its constructor registers the Reset, and it
   * is what sends each change.
   */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  private readonly dialog = viewChild(ScreenPermissionsDialog);

  /** The screen the open dialog changes, or `''` while none is open. */
  private readonly openId = signal('');

  /** Bumped when the list's rows change, so the open dialog is drawn from the latest read. */
  private readonly read = signal(0);

  protected readonly sending = signal(false);

  protected readonly refusal = signal('');

  /** The open dialog's screen as the list last read it, `null` (falsy) while none is open or its row has left. */
  protected get openTarget(): PermissionTarget | null {
    this.read();
    const id = this.openId();
    const screen = SCREENS.find((entry) => entry.descriptor === SCREEN_PERMISSIONS);
    if (id === '' || screen === undefined || this.store === null) return null;
    const row = rowFor(this.store.data(), screen, id);
    if (row === null) return null;
    const adjustment = text(row['Adjustment']);
    const classic = text(row['ClassicResource']);
    return {
      id,
      pairs: split(adjustment !== '' ? adjustment : text(row['Declared'])),
      classic: classic === '' ? '' : `${classic}:${CLASSIC_PERMISSION}`,
      adjustable: row['Adjustable'] === true,
    };
  }

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === SCREEN_PERMISSIONS) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stop = this.actions.register(SCREEN_PERMISSIONS, SCREEN_PERMISSIONS_ADD, () => this.onOpen());
    const unsubscribe = this.store?.subscribe(() => this.read.update((count) => count + 1));
    inject(DestroyRef).onDestroy(() => {
      stop();
      unsubscribe?.();
    });
  }

  /** Open the dialog on the selected row, never over another dialog. With no selection nothing opens. */
  protected onOpen(): void {
    if (this.openId() !== '' || this.handler.pending() !== null || this.store === null) return;
    const screen = SCREENS.find((entry) => entry.descriptor === SCREEN_PERMISSIONS);
    const selected = this.store.selection()[0] ?? '';
    if (screen === undefined || rowFor(this.store.data(), screen, selected) === null) return;
    this.store.setRefusal('');
    this.refusal.set('');
    this.openId.set(selected);
  }

  protected onClose(): void {
    this.openId.set('');
    this.refusal.set('');
  }

  protected onAdd(pair: string): Promise<void> {
    return this.change(SCREEN_PERMISSIONS_ADD, pair);
  }

  protected onRemove(pair: string): Promise<void> {
    return this.change(SCREEN_PERMISSIONS_REMOVE, pair);
  }

  /**
   * One change through the handler's `sendFor`, the refusal kept in the dialog rather than on the list's
   * banner. An applied Add clears the dialog's resource field for the next pair.
   */
  private async change(actionId: string, pair: string): Promise<void> {
    const id = this.openId();
    if (id === '' || this.sending()) return;
    this.sending.set(true);
    this.refusal.set('');
    const applied = await this.handler.sendFor(SCREEN_PERMISSIONS, actionId, id, { [PAIR_VALUE]: pair }, { setRefusal: () => undefined });
    this.sending.set(false);
    // A dialog closed while this send was in flight no longer answers it.
    if (this.openId() !== id) return;
    if (applied) {
      if (actionId === SCREEN_PERMISSIONS_ADD) this.dialog()?.clearResource();
      return;
    }
    const refused = this.handler.lastRefusal();
    const onField = refused?.violations.find((entry) => entry.field === PAIR_VALUE)?.reason ?? '';
    this.refusal.set(onField !== '' ? onField : (refused?.reason ?? ''));
  }
}
