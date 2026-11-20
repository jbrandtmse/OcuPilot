import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { rowFor } from '../../core/table-model';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { type CopyField, LISTING_GROUP_COPY_ACTION, ListingGroupCopyDialog } from './listing-group-copy-dialog';
import { QUALITY_MEASURE_LIST, QUALITY_MEASURE_UPDATE_ACTION, QualityMeasureDialog } from './quality-measure-dialog';

/** The declared primary action id: the command bar's New quality measure, which opens the dialog. */
export const QUALITY_MEASURE_ADD_ACTION = 'add';

/** The fields a quality measure's copy draws: the new name and the new class. */
export const QUALITY_MEASURE_COPY_FIELDS: readonly CopyField[] = [
  { value: 'NewName', label: STRINGS.analyticsListingGroupNewNameLabel, required: true },
  { value: 'NewClass', label: STRINGS.analyticsListingGroupNewClassLabel, required: true },
];

/**
 * Analytics' Quality measures (Story 24.12, AD-5): the shared list page, over it the New quality measure, Edit and Copy dialogs.
 *
 * **New quality measure, Edit and Copy are this page's own actions**, registered on the descriptor after injecting the shell's handler, whose
 * construction registers the list's declared Delete. New quality measure creates in the namespace the shell is scoped to. Edit and Copy open on
 * the selected row; an applied write closes the dialog, and the change event it publishes re-reads the list (AD-14). It follows
 * `ListingGroupListPage`'s shape; Copy is the listing groups' dialog drawn over the measure's screen and two fields.
 */
@Component({
  selector: 'app-quality-measure-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, QualityMeasureDialog, ListingGroupCopyDialog],
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
      <app-quality-measure-dialog [namespace]="namespace" (done)="onClose()" (cancelled)="onClose()" />
    }
    @if (editingName; as name) {
      <app-quality-measure-dialog [namespace]="namespace" [target]="name" (done)="onClose()" (cancelled)="onClose()" />
    }
    @if (copyingName; as source) {
      <app-listing-group-copy-dialog [namespace]="namespace" [source]="source" [descriptor]="descriptor" [fields]="copyFields" (done)="onClose()" (cancelled)="onClose()" />
    }`,
})
export class QualityMeasureListPage {
  private readonly scope = inject(ScopeService);

  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own actions: its constructor registers Delete. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  protected readonly descriptor = QUALITY_MEASURE_LIST;

  protected readonly copyFields = QUALITY_MEASURE_COPY_FIELDS;

  protected readonly adding = signal(false);

  /** The full name of the quality measure the open Edit dialog changes, or `null` while none is open. */
  protected readonly editing = signal<string | null>(null);

  /** The full name of the quality measure the open Copy dialog copies, or `null` while none is open. */
  protected readonly copying = signal<string | null>(null);

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === QUALITY_MEASURE_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stops = [
      this.actions.register(QUALITY_MEASURE_LIST, QUALITY_MEASURE_ADD_ACTION, () => this.onOpenAdd()),
      this.actions.register(QUALITY_MEASURE_LIST, QUALITY_MEASURE_UPDATE_ACTION, () => this.onOpenEdit()),
      this.actions.register(QUALITY_MEASURE_LIST, LISTING_GROUP_COPY_ACTION, () => this.onOpenCopy()),
    ];
    inject(DestroyRef).onDestroy(() => {
      for (const stop of stops) stop();
    });
  }

  protected get isAdding(): boolean {
    return this.adding();
  }

  protected get editingName(): string | null {
    return this.editing();
  }

  protected get copyingName(): string | null {
    return this.copying();
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  /** Open New quality measure, never over another dialog. */
  protected onOpenAdd(): void {
    if (!this.canOpen()) return;
    this.adding.set(true);
  }

  /** Open Edit on the selected row, never over another dialog. With no selection nothing opens. */
  protected onOpenEdit(): void {
    if (!this.canOpen()) return;
    const selected = this.selectedName();
    if (selected !== '') this.editing.set(selected);
  }

  /** Open Copy on the selected row, never over another dialog. With no selection nothing opens. */
  protected onOpenCopy(): void {
    if (!this.canOpen()) return;
    const selected = this.selectedName();
    if (selected !== '') this.copying.set(selected);
  }

  protected onClose(): void {
    this.adding.set(false);
    this.editing.set(null);
    this.copying.set(null);
  }

  private canOpen(): boolean {
    return !this.adding() && this.editing() === null && this.copying() === null && this.handler.pending() === null;
  }

  /** The name of the selected row, which is its key, or `''` when none is selected. */
  private selectedName(): string {
    const screen = SCREENS.find((entry) => entry.descriptor === QUALITY_MEASURE_LIST);
    const store = this.store;
    if (screen === undefined || store === null) return '';
    const selected = store.selection()[0] ?? '';
    const row = rowFor(store.data(), screen, selected);
    const name = row === null ? '' : row['Name'];
    return typeof name === 'string' ? name : '';
  }
}
