import { LocationStrategy } from '@angular/common';
import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { NavigationEnd, Router } from '@angular/router';

import { encodeEntityId } from '../../core/entity-id';
import { parentCriteria, screenForDescriptor, withQuery } from '../../core/navigation';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { InteropItemAddDialog } from './interop-item-add-dialog';

/** The Production items list's descriptor (Story 20.3). */
export const INTEROP_ITEM_LIST = 'OcuPilot.Screen.Descriptor.InteropItemList';

/** The declared primary action id: the command bar's Add item, which opens the add dialog. */
export const INTEROP_ITEM_ADD_ACTION = 'add';

/** The Configuration diagram's descriptor (Story 20.8), which this page links to for the production it lists. */
const INTEROP_PRODUCTION_DIAGRAM = 'OcuPilot.Screen.Descriptor.InteropProductionDiagram';

/**
 * Interoperability's Production items (Story 20.3, AD-5): the shared list page, over it the add dialog.
 *
 * **Add item is this page's own action**, registered on the descriptor after injecting the shell's handler,
 * whose construction registers the list's declared Enable, Disable and Remove. The dialog adds the item to the
 * production the route names, in the namespace the shell is scoped to, which is the one the list reads.
 *
 * **A link above the list opens the production's Configuration diagram** (Story 20.8), the unlisted screen under
 * Productions, while the route names a production and the diagram is declared. It is the diagram's only entry
 * besides a typed address or the agent, and it follows the route: one production's items to another's reuse this page.
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
    .ocu-interop-item-links {
      display: flex;
      flex: 0 0 auto;
      flex-wrap: wrap;
      gap: var(--ocu-space-3);
      padding: var(--ocu-space-2) var(--ocu-space-4);
    }
  `,
  template: `@if (hasDiagram) {
      <nav class="ocu-interop-item-links">
        <a class="ocu-details-link" data-ocu-item-link="diagram" [href]="diagramHref" (click)="onOpenDiagram($event)">{{
          STRINGS.interopProductionDiagramTitle
        }}</a>
      </nav>
    }
    <app-list-page />
    @if (adding) {
      <app-interop-item-add-dialog [namespace]="namespace" [production]="production" (added)="onClose()" (cancelled)="onClose()" />
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

  /** Whether the add dialog is open. */
  private readonly open = signal(false);

  constructor() {
    const stop = this.actions.register(INTEROP_ITEM_LIST, INTEROP_ITEM_ADD_ACTION, () => this.onOpen());
    const stopUrl = this.router.events.subscribe((event) => {
      if (event instanceof NavigationEnd) this.url.set(this.router.url);
    });
    inject(DestroyRef).onDestroy(() => {
      stop();
      stopUrl.unsubscribe();
    });
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
    if (event.ctrlKey || event.metaKey || event.shiftKey || event.button !== 0) return;
    event.preventDefault();
    const url = this.diagramUrl();
    if (url !== '') void this.router.navigateByUrl(url);
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
