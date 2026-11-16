import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { rowFor } from '../../core/table-model';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { TERM_LIST_LIST, TERM_LIST_UPDATE_ACTION, TermListDialog } from './term-list-dialog';

/** The declared primary action id: the command bar's New term list, which opens the dialog. */
export const TERM_LIST_ADD_ACTION = 'add';

/**
 * Analytics' Term lists (Story 24.2, AD-5): the shared list page, over it the New term list dialog and the Edit term list dialog.
 *
 * **New term list and Edit term list are this page's own actions**, registered on the descriptor after injecting the shell's handler,
 * whose construction registers the list's declared Delete. New term list creates in the namespace the shell is scoped to. Edit term list
 * opens on the selected row; an applied write closes the dialog, and the change event it publishes re-reads the list (AD-14).
 */
@Component({
  selector: 'app-term-list-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, TermListDialog],
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
    @if (isAdding) {
      <app-term-list-dialog [namespace]="namespace" (done)="onClose()" (cancelled)="onClose()" />
    }
    @if (editingName; as name) {
      <app-term-list-dialog [namespace]="namespace" [target]="name" (done)="onClose()" (cancelled)="onClose()" />
    }`,
})
export class TermListListPage {
  private readonly scope = inject(ScopeService);

  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own actions: its constructor registers Delete. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  protected readonly adding = signal(false);

  /** The name of the term list the open Edit dialog changes, or `null` while none is open. */
  protected readonly editing = signal<string | null>(null);

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === TERM_LIST_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stopAdd = this.actions.register(TERM_LIST_LIST, TERM_LIST_ADD_ACTION, () => this.onOpenAdd());
    const stopEdit = this.actions.register(TERM_LIST_LIST, TERM_LIST_UPDATE_ACTION, () => this.onOpenEdit());
    inject(DestroyRef).onDestroy(() => {
      stopAdd();
      stopEdit();
    });
  }

  protected get isAdding(): boolean {
    return this.adding();
  }

  protected get editingName(): string | null {
    return this.editing();
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  /** Open New term list, never over another dialog. */
  protected onOpenAdd(): void {
    if (this.adding() || this.editing() !== null || this.handler.pending() !== null) return;
    this.adding.set(true);
  }

  /** Open Edit term list on the selected row, never over another dialog. With no selection nothing opens. */
  protected onOpenEdit(): void {
    if (this.adding() || this.editing() !== null || this.handler.pending() !== null) return;
    const screen = SCREENS.find((entry) => entry.descriptor === TERM_LIST_LIST);
    const store = this.store;
    if (screen === undefined || store === null) return;
    const selected = store.selection()[0] ?? '';
    if (rowFor(store.data(), screen, selected) === null) return;
    this.editing.set(selected);
  }

  protected onClose(): void {
    this.adding.set(false);
    this.editing.set(null);
  }
}
