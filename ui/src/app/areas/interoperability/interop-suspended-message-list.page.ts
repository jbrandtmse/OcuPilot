import { ChangeDetectionStrategy, Component, DestroyRef, inject } from '@angular/core';

import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { entityKeyOf } from '../../core/table-model';
import { ListPage } from '../../shell/list-page';
import { type ActionSink, INTEROP_SUSPENDED_LIST, ScreenActionHandler, SUSPENDED_EDIT_RESUBMIT } from '../../shell/screen-action-handler';
import { InteropItemTestDialog, type TestRequest } from './interop-item-test-dialog';
import { MessageEditFlow } from './message-edit-flow';

/**
 * Interoperability's Suspended messages (Story 24.16, AD-5): the shared list page over the namespace's suspended message headers, and over it the
 * form of Edit and resubmit.
 *
 * **Resubmit, Discard and Delete** act on the checked rows through the handler's own dry-run review (`CHECKED_SET_DIALOGS`), which lists what each
 * message would do before anything is sent; the page registers none of them.
 *
 * **Edit and resubmit** is this page's own action, registered on the descriptor after injecting the shell's handler, and acts on the one selected
 * row. It runs the same three steps as a message's Header tab (`MessageEditFlow`): the form over the body's fields, the dry run of the fields the
 * person changed, and the handler's typed-name review, whose confirm resubmits the message under its own id with the edited copy of its body. A
 * refusal that names no form (the message is no longer suspended, a body OcuPilot does not edit) is the list's banner.
 */
@Component({
  selector: 'app-interop-suspended-message-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, InteropItemTestDialog],
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
    @if (isOpen) {
      <app-interop-item-test-dialog
        [heading]="STRINGS.interopSuspendedEditResubmitAction"
        [submitLabel]="STRINGS.interopEditResendReview"
        [consequence]="STRINGS.interopSuspendedEditConsequence"
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
export class InteropSuspendedMessageListPage {
  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own action. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  protected readonly STRINGS = STRINGS;

  private readonly store: ScreenStore | null;

  /** The message the open form edits, which a review and its confirm are for. */
  private target = '';

  /** An action of this page is waiting on the instance, so a second press waits for the first. */
  private busy = false;

  /** The banner sink: a refusal that names no form is the list's own. */
  private readonly banner: ActionSink = {
    setRefusal: (reason) => this.store?.setRefusal(reason),
  };

  /** Edit and resubmit's form, dry runs and review, shared with a message's Header tab. */
  protected readonly flow = new MessageEditFlow(this.handler, INTEROP_SUSPENDED_LIST, SUSPENDED_EDIT_RESUBMIT, this.banner);

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_SUSPENDED_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stop = this.actions.register(INTEROP_SUSPENDED_LIST, SUSPENDED_EDIT_RESUBMIT, () => void this.onEdit());
    inject(DestroyRef).onDestroy(() => stop());
  }

  protected get isOpen(): boolean {
    return this.flow.isOpen;
  }

  /** The selected message's id, or `''` with none selected. */
  private get selected(): string {
    return entityKeyOf(this.store?.selection()[0] ?? '');
  }

  /** Edit and resubmit, step one: the form over the selected message, never over another dialog. */
  private async onEdit(): Promise<void> {
    const id = this.selected;
    if (this.busy || this.flow.isOpen || id === '' || this.handler.pending() !== null) return;
    this.busy = true;
    try {
      this.target = id;
      await this.flow.begin(id);
    } finally {
      this.busy = false;
    }
  }

  protected onClose(): void {
    this.flow.close();
    this.target = '';
  }

  /** Edit and resubmit, step two: Review of the fields the person changed, for the message the form opened over (`MessageEditFlow.review`). */
  protected async onReview(request: TestRequest): Promise<void> {
    await this.flow.review(this.target, request);
  }
}
