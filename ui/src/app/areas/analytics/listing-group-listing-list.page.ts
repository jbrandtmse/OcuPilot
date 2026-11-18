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
import { LISTING_GROUP_LISTING_LIST, LISTING_SET_ACTION, ListingGroupDialog } from './listing-group-dialog';

/** The declared primary action id: the command bar's Add listing, which opens the dialog. */
export const LISTING_ADD_ACTION = 'add';

/** The listing a Change listing dialog opens on: its composite id and what its row showed. */
interface ListingTarget {
  readonly id: string;
  readonly initial: Readonly<Record<string, string>>;
}

/** The row members the Change listing dialog opens on. */
const ROW_MEMBERS: readonly string[] = ['Name', 'DisplayName', 'Type', 'Fields', 'OrderBy', 'Formats', 'Source', 'Resource', 'SelectMode', 'Description', 'SQL'];

/**
 * Analytics' Listings (Story 24.11, AD-5): the shared list page, over it the Add listing and Change listing dialogs.
 *
 * **Add listing and Change listing are this page's own actions**, registered on the descriptor after injecting the shell's handler, whose
 * construction registers the list's declared Remove listing. Add listing adds to the group the route names, in the namespace the shell is
 * scoped to. Change listing opens on the selected row; an applied write closes the dialog, and the change event it publishes re-reads the
 * list (AD-14).
 */
@Component({
  selector: 'app-listing-group-listing-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, ListingGroupDialog],
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
      <app-listing-group-dialog kind="listing" [namespace]="namespace" [group]="listingGroup" (done)="onClose()" (cancelled)="onClose()" />
    }
    @if (changingTarget; as target) {
      <app-listing-group-dialog
        kind="listing"
        [namespace]="namespace"
        [group]="listingGroup"
        [target]="target.id"
        [initial]="target.initial"
        (done)="onClose()"
        (cancelled)="onClose()"
      />
    }`,
})
export class ListingGroupListingListPage {
  private readonly router = inject(Router);

  private readonly scope = inject(ScopeService);

  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own actions: its constructor registers Remove. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  protected readonly adding = signal(false);

  /** The listing the open Change listing dialog changes, or `null` while none is open. */
  protected readonly changing = signal<ListingTarget | null>(null);

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === LISTING_GROUP_LISTING_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stopAdd = this.actions.register(LISTING_GROUP_LISTING_LIST, LISTING_ADD_ACTION, () => this.onOpenAdd());
    const stopSet = this.actions.register(LISTING_GROUP_LISTING_LIST, LISTING_SET_ACTION, () => this.onOpenSet());
    inject(DestroyRef).onDestroy(() => {
      stopAdd();
      stopSet();
    });
  }

  protected get isAdding(): boolean {
    return this.adding();
  }

  protected get changingTarget(): ListingTarget | null {
    return this.changing();
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  /** The listing group the route names: the list's one criterion, read off the URL. */
  protected get listingGroup(): string {
    const screen = screenForDescriptor(LISTING_GROUP_LISTING_LIST);
    if (screen === null) return '';
    return Object.values(parentCriteria(screen, this.router.url))[0] ?? '';
  }

  /** Open Add listing, never over another dialog. */
  protected onOpenAdd(): void {
    if (this.adding() || this.changing() !== null || this.handler.pending() !== null) return;
    this.adding.set(true);
  }

  /** Open Change listing on the selected row, never over another dialog. With no selection nothing opens. */
  protected onOpenSet(): void {
    if (this.adding() || this.changing() !== null || this.handler.pending() !== null) return;
    const screen = SCREENS.find((entry) => entry.descriptor === LISTING_GROUP_LISTING_LIST);
    const store = this.store;
    if (screen === undefined || store === null) return;
    const selected = store.selection()[0] ?? '';
    const row = rowFor(store.data(), screen, selected);
    if (row === null) return;
    const initial: Record<string, string> = {};
    for (const member of ROW_MEMBERS) {
      const value = row[member];
      initial[member] = typeof value === 'string' ? value : '';
    }
    initial['Disabled'] = row['Disabled'] === true ? 'true' : 'false';
    this.changing.set({ id: selected, initial });
  }

  protected onClose(): void {
    this.adding.set(false);
    this.changing.set(null);
  }
}
