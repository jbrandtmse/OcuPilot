import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { parentCriteria, screenForDescriptor } from '../../core/navigation';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { rowFor } from '../../core/table-model';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { type EntryTarget, TERM_LIST_ENTRY_LIST, TERM_LIST_ENTRY_SET_ACTION, TermListEntryDialog } from './term-list-entry-dialog';

/** The declared primary action id: the command bar's Add entry, which opens the dialog. */
export const TERM_LIST_ENTRY_ADD_ACTION = 'add';

/** `value` as text, or `''`. */
function text(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

/**
 * Analytics' Term list entries (Story 24.2, AD-5): the shared list page, over it the Add entry dialog and the Change entry dialog.
 *
 * **Add entry and Change entry are this page's own actions**, registered on the descriptor after injecting the shell's handler, whose
 * construction registers the list's declared Remove. Add entry adds to the term list the route names, in the namespace the shell is scoped
 * to. Change entry opens on the selected row; an applied write closes the dialog, and the change event it publishes re-reads the list (AD-14).
 */
@Component({
  selector: 'app-term-list-entry-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, TermListEntryDialog],
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
      <app-term-list-entry-dialog [namespace]="namespace" [termList]="termList" (done)="onClose()" (cancelled)="onClose()" />
    }
    @if (changingTarget; as target) {
      <app-term-list-entry-dialog [namespace]="namespace" [termList]="termList" [target]="target" (done)="onClose()" (cancelled)="onClose()" />
    }`,
})
export class TermListEntryListPage {
  private readonly router = inject(Router);

  private readonly scope = inject(ScopeService);

  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own actions: its constructor registers Remove. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  protected readonly adding = signal(false);

  /** The entry the open Change entry dialog changes, or `null` while none is open. */
  protected readonly changing = signal<EntryTarget | null>(null);

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === TERM_LIST_ENTRY_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stopAdd = this.actions.register(TERM_LIST_ENTRY_LIST, TERM_LIST_ENTRY_ADD_ACTION, () => this.onOpenAdd());
    const stopSet = this.actions.register(TERM_LIST_ENTRY_LIST, TERM_LIST_ENTRY_SET_ACTION, () => this.onOpenSet());
    inject(DestroyRef).onDestroy(() => {
      stopAdd();
      stopSet();
    });
  }

  protected get isAdding(): boolean {
    return this.adding();
  }

  protected get changingTarget(): EntryTarget | null {
    return this.changing();
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  /** The term list the route names: the list's one criterion, read off the URL. */
  protected get termList(): string {
    const screen = screenForDescriptor(TERM_LIST_ENTRY_LIST);
    if (screen === null) return '';
    return Object.values(parentCriteria(screen, this.router.url))[0] ?? '';
  }

  /** Open Add entry, never over another dialog. */
  protected onOpenAdd(): void {
    if (this.adding() || this.changing() !== null || this.handler.pending() !== null) return;
    this.adding.set(true);
  }

  /** Open Change entry on the selected row, never over another dialog. With no selection nothing opens. */
  protected onOpenSet(): void {
    if (this.adding() || this.changing() !== null || this.handler.pending() !== null) return;
    const screen = SCREENS.find((entry) => entry.descriptor === TERM_LIST_ENTRY_LIST);
    const store = this.store;
    if (screen === undefined || store === null) return;
    const selected = store.selection()[0] ?? '';
    const row = rowFor(store.data(), screen, selected);
    if (row === null) return;
    this.changing.set({ id: selected, key: text(row['Key']), value: text(row['Value']), fields: text(row['Fields']) });
  }

  protected onClose(): void {
    this.adding.set(false);
    this.changing.set(null);
  }
}
