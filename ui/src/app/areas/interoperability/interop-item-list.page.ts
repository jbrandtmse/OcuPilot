import { LocationStrategy } from '@angular/common';
import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { NavigationEnd, Router } from '@angular/router';

import { encodeEntityId, splitCompositeId } from '../../core/entity-id';
import { parentCriteria, screenForDescriptor, withQuery } from '../../core/navigation';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { InteropItemAddDialog } from './interop-item-add-dialog';
import { InteropItemChangeClassDialog } from './interop-item-change-class-dialog';
import { InteropItemCopyDialog } from './interop-item-copy-dialog';

/** The Production items list's descriptor (Story 20.3). */
export const INTEROP_ITEM_LIST = 'OcuPilot.Screen.Descriptor.InteropItemList';

/** The declared primary action id: the command bar's Add item, which opens the add dialog. */
export const INTEROP_ITEM_ADD_ACTION = 'add';

/** The declared row action id: Copy on the selected item, which opens the copy dialog. */
export const INTEROP_ITEM_COPY_ACTION = 'copy';

/** The declared row action id: Change class on the selected item, which opens the class picker, then the review (Story 20.41). */
export const INTEROP_ITEM_CHANGE_CLASS_ACTION = 'changeclass';

/** The value the review and the confirmed action carry: the class the item changes to (AD-56). */
export const INTEROP_ITEM_NEW_CLASS_VALUE = 'NewClass';

/** The Configuration diagram's descriptor (Story 20.8), which this page links to for the production it lists. */
const INTEROP_PRODUCTION_DIAGRAM = 'OcuPilot.Screen.Descriptor.InteropProductionDiagram';

/**
 * Interoperability's Production items (Story 20.3, AD-5): the shared list page, over it the add, copy and change class dialogs.
 *
 * **Add item, Copy and Change class are this page's own actions**, registered on the descriptor after injecting the shell's handler,
 * whose construction registers the list's other declared row actions (Copy and Change class are left to this page through their
 * `UNDRAWN_ACTIONS` entry). The add and copy dialogs add an item to the
 * production the route names, in the namespace the shell is scoped to, which is the one the list reads. Copy
 * (Story 20.40) opens on the selected row and never over another dialog. Change class (Story 20.41) opens the class picker on the
 * selected row; the class it chooses closes it and starts the handler's review of what the change removes, whose typed name is the
 * item's name.
 *
 * **A link above the list opens the production's Configuration diagram** (Story 20.8), the unlisted screen under
 * Productions, while the route names a production and the diagram is declared. It is the diagram's only entry
 * besides a typed address or the agent, and it follows the route: one production's items to another's reuse this page.
 */
@Component({
  selector: 'app-interop-item-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, InteropItemAddDialog, InteropItemCopyDialog, InteropItemChangeClassDialog],
  // The height chain every page host carries, so the list's viewport keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
    .ocu-interop-item-links {
      flex: 0 0 auto;
      padding: var(--ocu-space-2) var(--ocu-space-4);
    }
  `,
  template: `@if (hasDiagram) {
      <nav class="ocu-details-links ocu-interop-item-links">
        <a class="ocu-details-link" data-ocu-item-link="diagram" [href]="diagramHref" (click)="onOpenDiagram($event)">{{
          STRINGS.interopProductionDiagramTitle
        }}</a>
      </nav>
    }
    <app-list-page />
    @if (adding) {
      <app-interop-item-add-dialog [namespace]="namespace" [production]="production" (added)="onClose()" (cancelled)="onClose()" />
    }
    @if (copySource) {
      <app-interop-item-copy-dialog
        [namespace]="namespace"
        [production]="production"
        [source]="copySource"
        (copied)="onCloseCopy()"
        (cancelled)="onCloseCopy()"
      />
    }
    @if (classItem) {
      <app-interop-item-change-class-dialog
        [production]="production"
        [item]="classItem"
        (chosen)="onChosenClass($event)"
        (cancelled)="onCloseClass()"
      />
    }`,
})
export class InteropItemListPage {
  private readonly router = inject(Router);

  private readonly scope = inject(ScopeService);

  private readonly locationStrategy = inject(LocationStrategy);

  protected readonly STRINGS = STRINGS;

  /** The router's URL, mirrored into a signal so the link follows a move from one production's items to another's. */
  private readonly url = signal(this.router.url);

  /** Constructed before this page registers its own action: its constructor registers the row actions. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly stores = inject(ScreenStores);

  /** The list's own store, whose selection names the item Copy copies. */
  private readonly store: ScreenStore | null;

  /** Whether the add dialog is open. */
  private readonly open = signal(false);

  /** The name of the item the open copy dialog copies, or `''` while none is open. */
  private readonly copying = signal('');

  /** The item the open change class dialog changes, or `null` while none is open: its row id and its name. */
  private readonly classing = signal<{ readonly id: string; readonly name: string } | null>(null);

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_ITEM_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stop = this.actions.register(INTEROP_ITEM_LIST, INTEROP_ITEM_ADD_ACTION, () => this.onOpen());
    const stopCopy = this.actions.register(INTEROP_ITEM_LIST, INTEROP_ITEM_COPY_ACTION, () => this.onOpenCopy());
    const stopClass = this.actions.register(INTEROP_ITEM_LIST, INTEROP_ITEM_CHANGE_CLASS_ACTION, () => this.onOpenClass());
    const stopUrl = this.router.events.subscribe((event) => {
      if (event instanceof NavigationEnd) this.url.set(this.router.url);
    });
    inject(DestroyRef).onDestroy(() => {
      stop();
      stopCopy();
      stopClass();
      stopUrl.unsubscribe();
    });
  }

  protected get adding(): boolean {
    return this.open();
  }

  /** The item being copied while the copy dialog is open, `''` (falsy) otherwise. */
  protected get copySource(): string {
    return this.copying();
  }

  /** The name of the item being changed while the change class dialog is open, `''` (falsy) otherwise. */
  protected get classItem(): string {
    return this.classing()?.name ?? '';
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  /** The production the route names: the list's one criterion, read off the URL. */
  protected get production(): string {
    const screen = screenForDescriptor(INTEROP_ITEM_LIST);
    if (screen === null) return '';
    return Object.values(parentCriteria(screen, this.url()))[0] ?? '';
  }

  /** The diagram's address for the production on screen, or `''` while the route names none or no diagram is declared. */
  private diagramUrl(): string {
    const production = this.production;
    const diagram = screenForDescriptor(INTEROP_PRODUCTION_DIAGRAM);
    if (production === '' || diagram === null) return '';
    return withQuery(`${diagram.route}/${encodeEntityId(production)}`, this.url());
  }

  protected get hasDiagram(): boolean {
    return this.diagramUrl() !== '';
  }

  protected get diagramHref(): string {
    const url = this.diagramUrl();
    return url === '' ? '' : this.locationStrategy.prepareExternalUrl(url);
  }

  /** Open the diagram through the router; a modified click keeps the browser's own new-tab behavior. */
  protected onOpenDiagram(event: MouseEvent): void {
    if (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey || event.button !== 0) return;
    event.preventDefault();
    const url = this.diagramUrl();
    if (url !== '') void this.router.navigateByUrl(url);
  }

  /** Open the add dialog, never over a dialog of the handler's or the copy dialog. */
  protected onOpen(): void {
    if (this.open() || this.copying() !== '' || this.classing() !== null || this.handler.pending() !== null) return;
    this.open.set(true);
  }

  /** Open the copy dialog on the selected row, never over another dialog. With no selection nothing opens. */
  protected onOpenCopy(): void {
    if (this.open() || this.copying() !== '' || this.classing() !== null || this.handler.pending() !== null) return;
    const selected = this.store?.selection()[0] ?? '';
    const name = selected === '' ? '' : (splitCompositeId(selected)[1] ?? '');
    if (name !== '') this.copying.set(name);
  }

  /** Open the change class dialog on the selected row, never over another dialog. With no selection nothing opens. */
  protected onOpenClass(): void {
    if (this.open() || this.copying() !== '' || this.classing() !== null || this.handler.pending() !== null) return;
    const selected = this.store?.selection()[0] ?? '';
    const name = selected === '' ? '' : (splitCompositeId(selected)[1] ?? '');
    if (name !== '') this.classing.set({ id: selected, name });
  }

  /** The class was chosen: the dialog gives way to the review of what the change removes, whose typed name is the item's. */
  protected onChosenClass(newClass: string): void {
    const target = this.classing();
    this.classing.set(null);
    if (target === null || this.store === null) return;
    void this.handler.startDryRun(INTEROP_ITEM_LIST, INTEROP_ITEM_CHANGE_CLASS_ACTION, target.id, { [INTEROP_ITEM_NEW_CLASS_VALUE]: newClass }, this.store, target.name);
  }

  protected onCloseClass(): void {
    this.classing.set(null);
  }

  protected onCloseCopy(): void {
    this.copying.set('');
  }

  protected onClose(): void {
    this.open.set(false);
  }
}
