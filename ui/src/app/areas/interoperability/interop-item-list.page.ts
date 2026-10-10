import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { parentCriteria, screenForDescriptor } from '../../core/navigation';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { InteropItemAddDialog } from './interop-item-add-dialog';

/** The Production items list's descriptor (Story 20.3). */
export const INTEROP_ITEM_LIST = 'OcuPilot.Screen.Descriptor.InteropItemList';

/** The declared primary action id: the command bar's Add item, which opens the add dialog. */
export const INTEROP_ITEM_ADD_ACTION = 'add';

/**
 * Interoperability's Production items (Story 20.3, AD-5): the shared list page, over it the add dialog.
 *
 * **Add item is this page's own action**, registered on the descriptor after injecting the shell's handler,
 * whose construction registers the list's declared Enable, Disable and Remove. The dialog adds the item to the
 * production the route names, in the namespace the shell is scoped to, which is the one the list reads.
 */
@Component({
  selector: 'app-interop-item-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, InteropItemAddDialog],
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
    @if (adding) {
      <app-interop-item-add-dialog [namespace]="namespace" [production]="production" (added)="onClose()" (cancelled)="onClose()" />
    }`,
})
export class InteropItemListPage {
  private readonly router = inject(Router);

  private readonly scope = inject(ScopeService);

  /** Constructed before this page registers its own action: its constructor registers the row actions. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  /** Whether the add dialog is open. */
  private readonly open = signal(false);

  constructor() {
    const stop = this.actions.register(INTEROP_ITEM_LIST, INTEROP_ITEM_ADD_ACTION, () => this.onOpen());
    inject(DestroyRef).onDestroy(stop);
  }

  protected get adding(): boolean {
    return this.open();
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  /** The production the route names: the list's one criterion, read off the URL. */
  protected get production(): string {
    const screen = screenForDescriptor(INTEROP_ITEM_LIST);
    if (screen === null) return '';
    return Object.values(parentCriteria(screen, this.router.url))[0] ?? '';
  }

  /** Open the add dialog, never over a dialog of the handler's. */
  protected onOpen(): void {
    if (this.open() || this.handler.pending() !== null) return;
    this.open.set(true);
  }

  protected onClose(): void {
    this.open.set(false);
  }
}
