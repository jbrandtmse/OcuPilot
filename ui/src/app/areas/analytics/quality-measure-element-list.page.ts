import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { COMPOSITE_SEPARATOR } from '../../core/entity-id';
import { parentCriteria, screenForDescriptor } from '../../core/navigation';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { rowFor } from '../../core/table-model';
import { DetailPage } from '../../shell/detail-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { QUALITY_MEASURE_ELEMENT_LIST, QUALITY_MEASURE_PART_SET_ACTION, QualityMeasureDialog } from './quality-measure-dialog';

/** The declared primary action id: the command bar's Add element, which opens the dialog. */
export const QUALITY_MEASURE_ELEMENT_ADD_ACTION = 'add';

/** The row action that removes a group with every element in it; this page starts it on the group's own id. */
export const QUALITY_MEASURE_GROUP_REMOVE_ACTION = 'remove-group';

/** The element a Change element dialog opens on: its composite id and what its row showed. */
interface ElementTarget {
  readonly id: string;
  readonly initial: Readonly<Record<string, string>>;
}

/** The row members the Change element dialog opens on. */
const ROW_MEMBERS: readonly string[] = ['Group', 'GroupCaption', 'GroupDescription', 'Name', 'Caption', 'MDX'];

/**
 * Analytics' Groups and elements (Story 24.12, AD-5): the first tab of a measure's pair, the detail page over the shared list page, over it the Add element and Change element dialogs and the Remove group action.
 *
 * **Add element, Change element and Remove group are this page's own actions**, registered on the descriptor after injecting the shell's handler, whose
 * construction registers the list's declared Remove element. Add element adds to the measure the route names, in the namespace the shell is scoped to, on
 * the selected row's group when there is one. Change element opens on the selected row (a group's row with no element changes the group alone). Remove group
 * is the remove tool's second row action: it starts on the selected row's id with its element name left empty, so the instance removes the group and every
 * element in it, and the typed name is the group's. An applied write closes the dialog, and the change event it publishes re-reads the list (AD-14).
 */
@Component({
  selector: 'app-quality-measure-element-list-page',
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
      <app-quality-measure-dialog kind="element" [namespace]="namespace" [measure]="qualityMeasure" [group]="selectedGroup" (done)="onClose()" (cancelled)="onClose()" />
    }
    @if (changingTarget; as target) {
      <app-quality-measure-dialog kind="element" [namespace]="namespace" [measure]="qualityMeasure" [target]="target.id" [initial]="target.initial" (done)="onClose()" (cancelled)="onClose()" />
    }`,
})
export class QualityMeasureElementListPage {
  private readonly router = inject(Router);

  private readonly scope = inject(ScopeService);

  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own actions: its constructor registers Remove element. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  protected readonly adding = signal(false);

  /** The element the open Change element dialog changes, or `null` while none is open. */
  protected readonly changing = signal<ElementTarget | null>(null);

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === QUALITY_MEASURE_ELEMENT_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stopAdd = this.actions.register(QUALITY_MEASURE_ELEMENT_LIST, QUALITY_MEASURE_ELEMENT_ADD_ACTION, () => this.onOpenAdd());
    const stopSet = this.actions.register(QUALITY_MEASURE_ELEMENT_LIST, QUALITY_MEASURE_PART_SET_ACTION, () => this.onOpenSet());
    const stopGroup = this.actions.register(QUALITY_MEASURE_ELEMENT_LIST, QUALITY_MEASURE_GROUP_REMOVE_ACTION, () => this.onRemoveGroup());
    inject(DestroyRef).onDestroy(() => {
      stopAdd();
      stopSet();
      stopGroup();
    });
  }

  protected get isAdding(): boolean {
    return this.adding();
  }

  protected get changingTarget(): ElementTarget | null {
    return this.changing();
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  /** The quality measure the route names: the list's one criterion, read off the URL. */
  protected get qualityMeasure(): string {
    const screen = screenForDescriptor(QUALITY_MEASURE_ELEMENT_LIST);
    if (screen === null) return '';
    return Object.values(parentCriteria(screen, this.router.url))[0] ?? '';
  }

  /** The selected row, with its id, or `null` when nothing is selected. */
  private selectedRow(): { readonly id: string; readonly row: Readonly<Record<string, unknown>> } | null {
    const screen = SCREENS.find((entry) => entry.descriptor === QUALITY_MEASURE_ELEMENT_LIST);
    const store = this.store;
    if (screen === undefined || store === null) return null;
    const id = store.selection()[0] ?? '';
    const row = rowFor(store.data(), screen, id);
    return row === null ? null : { id, row };
  }

  /** The group the selected row belongs to, which a new element opens on. */
  protected get selectedGroup(): string {
    const selected = this.selectedRow();
    return typeof selected?.row['Group'] === 'string' ? selected.row['Group'] : '';
  }

  /** Open Add element, never over another dialog. */
  protected onOpenAdd(): void {
    if (this.adding() || this.changing() !== null || this.handler.pending() !== null) return;
    this.adding.set(true);
  }

  /** Open Change element on the selected row, never over another dialog. With no selection nothing opens. */
  protected onOpenSet(): void {
    if (this.adding() || this.changing() !== null || this.handler.pending() !== null) return;
    const selected = this.selectedRow();
    if (selected === null) return;
    const initial: Record<string, string> = {};
    for (const member of ROW_MEMBERS) {
      const value = selected.row[member];
      initial[member] = typeof value === 'string' ? value : '';
    }
    initial['Disabled'] = selected.row['Disabled'] === true ? 'true' : 'false';
    initial['GroupDisabled'] = selected.row['GroupDisabled'] === true ? 'true' : 'false';
    this.changing.set({ id: selected.id, initial });
  }

  /** Start Remove group on the selected row's group: its id with the element name left empty and the row's `Name` blanked, so the typed name is the group's. */
  protected onRemoveGroup(): void {
    if (this.adding() || this.changing() !== null || this.handler.pending() !== null) return;
    const screen = SCREENS.find((entry) => entry.descriptor === QUALITY_MEASURE_ELEMENT_LIST);
    const store = this.store;
    const selected = this.selectedRow();
    if (screen === undefined || store === null || selected === null) return;
    const parts = selected.id.split(COMPOSITE_SEPARATOR);
    parts[2] = '';
    this.handler.startFor(QUALITY_MEASURE_ELEMENT_LIST, QUALITY_MEASURE_GROUP_REMOVE_ACTION, parts.join(COMPOSITE_SEPARATOR), { ...selected.row, Name: '' }, store);
  }

  protected onClose(): void {
    this.adding.set(false);
    this.changing.set(null);
  }
}
