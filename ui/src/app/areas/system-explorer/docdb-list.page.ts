import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { DocDbCreateDialog } from './docdb-create-dialog';

/** The Document databases list's descriptor (Story 19.17). */
export const DOCDB_LIST = 'OcuPilot.Screen.Descriptor.ExplorerDocDbList';

/** The declared primary action id: the command bar's Create, which opens the create dialog. */
export const DOCDB_CREATE_ACTION = 'create';

/** The code the instance answers every DocDB call with while `%Service_DocDB` is disabled. */
export const DOCDB_SERVICE_DISABLED = 'DOCDB.SERVICE.DISABLED';

/**
 * System Explorer's Document databases (Story 19.17, AD-5): the shared list page, above it a status
 * strip while the DocDB service is disabled, and over it the create dialog.
 *
 * **The strip is the read's refusal, said in full.** The list draws a refused read as its generic
 * refusal, which names no reason; while the bound read's last fault is `DOCDB.SERVICE.DISABLED` this
 * page states the published sentence naming `%Service_DocDB` and the Services screen.
 *
 * **Create is this page's own action**, registered on the descriptor after injecting the shell's
 * handler, whose construction registers the list's declared Drop, a typed-name delete. The dialog
 * creates the database in the namespace the shell is scoped to, which is the one the list reads.
 */
@Component({
  selector: 'app-docdb-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, DocDbCreateDialog],
  // The height chain every page host carries, so the list's viewport keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }

    .ocu-docdb-service-strip {
      flex: 0 0 auto;
      margin: 0 0 var(--ocu-space-2);
      background: var(--ocu-warning-container);
      color: var(--ocu-warning);
    }
  `,
  template: `@if (serviceDisabled) {
      <p class="ocu-banner ocu-docdb-service-strip" role="status" data-docdb-service-strip>{{ STRINGS.explorerDocDbServiceDisabled }}</p>
    }
    <app-list-page />
    @if (creating) {
      <app-docdb-create-dialog [namespace]="namespace" (created)="onClose()" (cancelled)="onClose()" />
    }`,
})
export class DocDbListPage {
  private readonly refresh = inject(RefreshService);

  private readonly scope = inject(ScopeService);

  /** Constructed before this page registers its own action: its constructor registers the Drop. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  protected readonly STRINGS = STRINGS;

  /** Bumped by the refresh service, so the strip re-reads the fault under `OnPush`. */
  private readonly generation = signal(0);

  /** Whether the create dialog is open. */
  private readonly open = signal(false);

  constructor() {
    const stops: (() => void)[] = [];
    stops.push(this.refresh.subscribe(() => this.generation.update((value) => value + 1)));
    stops.push(this.actions.register(DOCDB_LIST, DOCDB_CREATE_ACTION, () => this.onOpen()));
    inject(DestroyRef).onDestroy(() => {
      for (const stop of stops) stop();
    });
  }

  /** Whether the bound read of this screen was last refused because the DocDB service is disabled. */
  protected get serviceDisabled(): boolean {
    this.generation();
    return this.refresh.descriptor() === DOCDB_LIST && this.refresh.fault()?.code === DOCDB_SERVICE_DISABLED;
  }

  protected get creating(): boolean {
    return this.open();
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  /** Open the create dialog, never over a dialog of the handler's. */
  protected onOpen(): void {
    if (this.open() || this.handler.pending() !== null) return;
    this.open.set(true);
  }

  protected onClose(): void {
    this.open.set(false);
  }
}
