import { ChangeDetectionStrategy, Component, DestroyRef, inject } from '@angular/core';
import { Router } from '@angular/router';

import { parentCriteria, screenForDescriptor } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { rowKey } from '../../core/table-model';
import { DetailPage } from '../../shell/detail-page';
import { ScreenActionDialogs } from '../../shell/screen-action-dialogs';
import {
  type ActionSink,
  INTEROP_MESSAGE_HEADER,
  INTEROP_MESSAGE_LIST,
  MESSAGE_EDIT_RESEND,
  MESSAGE_RESEND,
  ScreenActionHandler,
} from '../../shell/screen-action-handler';
import { InteropItemTestDialog, type TestRequest } from './interop-item-test-dialog';
import { MessageEditFlow } from './message-edit-flow';

/**
 * A message's Header tab (Story 20.31, AD-5): the detail page over the shared list page, with the tab's two actions -- Resend and Edit
 * and resend -- which this page registers on the descriptor, as the Test tab registers its own.
 *
 * **Resend** reviews the message first: the handler's dry run answers the message's verdict, and its typed-name dialog, typed name the
 * message id, sends the resend only when the person confirms. It is the Messages list's own action over this one message, so it is
 * addressed to that screen (`INTEROP_MESSAGE_LIST`) and its dialog is rendered here for that descriptor.
 *
 * **Edit and resend** is three steps, one dialog after another, never two at once. The form opens first, over the message body's
 * fields as the instance lists them with the value each holds now (a dry run with no fields answers them). Review sends the fields
 * the person changed, and only those, to the dry run while the form stays open: a field the instance refuses is drawn on the field,
 * and any other refusal above the fields. When the dry run is answered the form closes and the typed-name dialog opens over the
 * lines the change makes, typed name the message id; confirming sends the same fields with the review's digest. The body is the
 * instance's to judge: an edit that changes nothing, a body OcuPilot does not edit and a message that can no longer go are refused
 * with the instance's own sentences, on the tab's banner when the form cannot open and in the form otherwise.
 *
 * **The rows of this tab are properties, not messages**, so a row action has no row of its own to name. The page keeps the first row
 * selected, so Edit and resend, which the command bar draws as a row action, is never unavailable for want of a selection.
 */
@Component({
  selector: 'app-interop-message-header-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [DetailPage, InteropItemTestDialog, ScreenActionDialogs],
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
    <app-screen-action-dialogs [descriptor]="listDescriptor" />
    @if (isOpen) {
      <app-interop-item-test-dialog
        [heading]="STRINGS.interopEditResendHeading"
        [submitLabel]="STRINGS.interopEditResendReview"
        [consequence]="STRINGS.interopMessageEditResendConsequence"
        [secretCaption]="STRINGS.interopRefusalEditSecret"
        [rows]="flow.rows()"
        [values]="flow.values()"
        [sending]="flow.sending()"
        [refusal]="flow.refusal()"
        [violations]="flow.violations()"
        (submitted)="onReview($event)"
        (cancelled)="onClose()"
      />
    }`,
})
export class InteropMessageHeaderPage {
  private readonly router = inject(Router);

  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own actions. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  protected readonly STRINGS = STRINGS;

  /** The Messages list's descriptor, whose Resend this page's dialogs draw. */
  protected readonly listDescriptor = INTEROP_MESSAGE_LIST;

  private readonly screen = SCREENS.find((entry) => entry.descriptor === INTEROP_MESSAGE_HEADER) ?? null;

  private readonly store: ScreenStore | null;

  /** An action of this page is waiting on the instance, so a second press waits for the first. */
  private busy = false;

  /** The banner sink: a refusal that names no form is the tab's own. */
  private readonly banner: ActionSink = {
    setRefusal: (reason) => this.store?.setRefusal(reason),
  };

  /** Edit and resend's form, dry runs and review, shared with the Suspended messages list's Edit and resubmit. */
  protected readonly flow = new MessageEditFlow(this.handler, INTEROP_MESSAGE_HEADER, MESSAGE_EDIT_RESEND, this.banner);

  constructor() {
    this.store = this.screen === null ? null : this.stores.for(this.screen.descriptor, this.screen.refreshRates);
    const stopResend = this.actions.register(INTEROP_MESSAGE_HEADER, MESSAGE_RESEND, () => void this.onResend());
    const stopEdit = this.actions.register(INTEROP_MESSAGE_HEADER, MESSAGE_EDIT_RESEND, () => void this.onEdit());
    const stopStore = this.store?.subscribe(() => this.keepSelection());
    this.keepSelection();
    inject(DestroyRef).onDestroy(() => {
      stopResend();
      stopEdit();
      stopStore?.();
    });
  }

  protected get isOpen(): boolean {
    return this.flow.isOpen;
  }

  /** The message the route names: the tab's one criterion, read off the URL. */
  private get messageId(): string {
    const screen = screenForDescriptor(INTEROP_MESSAGE_HEADER);
    if (screen === null) return '';
    return Object.values(parentCriteria(screen, this.router.url))[0] ?? '';
  }

  /** Keep the first row selected while the tab lists any and none is, so a row action is never unavailable for want of one. */
  private keepSelection(): void {
    const store = this.store;
    if (store === null || this.screen === null || store.selection().length > 0) return;
    const first = store.data()[0];
    if (first === undefined) return;
    const key = rowKey(first, this.screen);
    if (key !== '') store.setSelection([key]);
  }

  /** Resend: the dry run of this message, then the typed-name review, through the Messages list's action. */
  private async onResend(): Promise<void> {
    const id = this.messageId;
    if (this.busy || this.flow.isOpen || id === '' || this.handler.pending() !== null) return;
    this.busy = true;
    try {
      await this.handler.startDryRun(INTEROP_MESSAGE_LIST, MESSAGE_RESEND, id, undefined, this.banner);
    } finally {
      this.busy = false;
    }
  }

  /** Edit and resend, step one: the dry run with no fields answers the form; a refusal is the tab's banner and no form opens. */
  private async onEdit(): Promise<void> {
    const id = this.messageId;
    if (this.busy || this.flow.isOpen || id === '' || this.handler.pending() !== null) return;
    this.busy = true;
    try {
      await this.flow.begin(id);
    } finally {
      this.busy = false;
    }
  }

  protected onClose(): void {
    this.flow.close();
  }

  /** Edit and resend, step two: Review of the fields the person changed (`MessageEditFlow.review`). */
  protected async onReview(request: TestRequest): Promise<void> {
    await this.flow.review(this.messageId, request);
  }
}
