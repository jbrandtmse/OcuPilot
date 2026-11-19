import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { parentCriteria, screenForDescriptor } from '../../core/navigation';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { rowFor } from '../../core/table-model';
import { DetailPage } from '../../shell/detail-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { QUALITY_MEASURE_META_LIST, QUALITY_MEASURE_PART_SET_ACTION, QualityMeasureDialog } from './quality-measure-dialog';

/** The declared primary action id: the command bar's Add documentation item, which opens the dialog. */
export const QUALITY_MEASURE_META_ADD_ACTION = 'add';

/** The documentation item a Change documentation item dialog opens on: its composite id and what its row showed. */
interface MetaTarget {
  readonly id: string;
  readonly initial: Readonly<Record<string, string>>;
}

/** The row members the Change documentation item dialog opens on. */
const ROW_MEMBERS: readonly string[] = ['Name', 'Caption', 'Content'];

/**
 * Analytics' Documentation (Story 24.12, AD-5): the second tab of a measure's pair, the detail page over the shared list page, over it the Add documentation item and Change documentation item dialogs.
 *
 * **Add and Change are this page's own actions**, registered on the descriptor after injecting the shell's handler, whose construction registers the list's
 * declared Remove documentation item. Add adds to the measure the route names, in the namespace the shell is scoped to. Change opens on the selected row; an
 * applied write closes the dialog, and the change event it publishes re-reads the list (AD-14). It follows `QualityMeasureElementListPage`'s wiring over the
 * documentation items' own descriptor and fields.
 */
@Component({
  selector: 'app-quality-measure-meta-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DetailPage, QualityMeasureDialog],
  // The height chain every page host carries, so the list's viewport keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
  `,
  template: `<app-detail-page />
    @if (isAdding) {
      <app-quality-measure-dialog kind="documentation" [namespace]="namespace" [measure]="qualityMeasure" (done)="onClose()" (cancelled)="onClose()" />
    }
    @if (changingTarget; as target) {
      <app-quality-measure-dialog kind="documentation" [namespace]="namespace" [measure]="qualityMeasure" [target]="target.id" [initial]="target.initial" (done)="onClose()" (cancelled)="onClose()" />
    }`,
})
export class QualityMeasureMetaListPage {
  private readonly router = inject(Router);

  private readonly scope = inject(ScopeService);

  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own actions: its constructor registers Remove documentation item. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  protected readonly adding = signal(false);

  /** The item the open Change documentation item dialog changes, or `null` while none is open. */
  protected readonly changing = signal<MetaTarget | null>(null);

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === QUALITY_MEASURE_META_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stopAdd = this.actions.register(QUALITY_MEASURE_META_LIST, QUALITY_MEASURE_META_ADD_ACTION, () => this.onOpenAdd());
    const stopSet = this.actions.register(QUALITY_MEASURE_META_LIST, QUALITY_MEASURE_PART_SET_ACTION, () => this.onOpenSet());
    inject(DestroyRef).onDestroy(() => {
      stopAdd();
      stopSet();
    });
  }

  protected get isAdding(): boolean {
    return this.adding();
  }

  protected get changingTarget(): MetaTarget | null {
    return this.changing();
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  /** The quality measure the route names: the list's one criterion, read off the URL. */
  protected get qualityMeasure(): string {
    const screen = screenForDescriptor(QUALITY_MEASURE_META_LIST);
    if (screen === null) return '';
    return Object.values(parentCriteria(screen, this.router.url))[0] ?? '';
  }

  /** Open Add documentation item, never over another dialog. */
  protected onOpenAdd(): void {
    if (this.adding() || this.changing() !== null || this.handler.pending() !== null) return;
    this.adding.set(true);
  }

  /** Open Change documentation item on the selected row, never over another dialog. With no selection nothing opens. */
  protected onOpenSet(): void {
    if (this.adding() || this.changing() !== null || this.handler.pending() !== null) return;
    const screen = SCREENS.find((entry) => entry.descriptor === QUALITY_MEASURE_META_LIST);
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
