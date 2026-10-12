import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { RestServiceCreateDialog } from './rest-service-create-dialog';

/** The REST API explorer's descriptor (Story 18.34). */
export const REST_API_LIST = 'OcuPilot.Screen.Descriptor.RestApiList';

/** The declared primary action id: the command bar's Create, which opens the create dialog. */
export const REST_API_CREATE_ACTION = 'create';

/**
 * The REST API explorer (Story 18.34, AD-5): the shared list page, and over it the create dialog.
 *
 * **Create is this page's own action**, registered on the descriptor after injecting the shell's
 * handler, whose construction registers the list's declared Delete, a typed-name delete. The dialog
 * builds the service in the namespace the shell is scoped to, which is the one the list reads.
 */
@Component({
  selector: 'app-rest-api-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, RestServiceCreateDialog],
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
    @if (creating) {
      <app-rest-service-create-dialog [namespace]="namespace" (created)="onClose()" (cancelled)="onClose()" />
    }`,
})
export class RestApiListPage {
  private readonly scope = inject(ScopeService);

  /** Constructed before this page registers its own action: its constructor registers the Delete. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  /** Whether the create dialog is open. */
  private readonly open = signal(false);

  constructor() {
    const stop = this.actions.register(REST_API_LIST, REST_API_CREATE_ACTION, () => this.onOpen());
    inject(DestroyRef).onDestroy(stop);
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
