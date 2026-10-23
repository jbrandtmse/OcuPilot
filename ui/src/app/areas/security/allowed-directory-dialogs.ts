import { ChangeDetectionStrategy, Component, DestroyRef, inject, output } from '@angular/core';

import { ScreenActions, actionLabel } from '../../core/screen-actions';
import { STRINGS } from '../../core/strings';
import { ALLOWED_DIRECTORY_LIST } from '../../shell/screen-action-handler';
import { TypedNameDialog } from '../../shell/typed-name-dialog';
import { WarningDialog, type WarningAnswer } from '../../shell/warning-dialog';
import { ALLOWED_DIRECTORY_ACTIONS, AllowedDirectoryActions, type PendingAllowedDirectory } from './allowed-directory-actions';

/** The placeholder `allowedDirectoryChangeConsequence` names the row's directory with. */
const DIRECTORY_PLACEHOLDER = '<directory>';

/**
 * The Allowed directories screen's actions and their dialogs (Story 18.46, AD-19, AD-53), rendered by
 * `app-screen-action-dialogs` for this descriptor and so alive exactly while the screen is.
 *
 * **It registers the screen's own three actions** -- Add, Change and Remove -- on construction, each with the service's
 * reason, so every surface draws them off with the instance's sentence while the key is disabled; it reads the verdict once
 * then, and unregisters them (and closes any dialog) when the screen goes. The handler does not register them: the
 * descriptor is not one of `SCREEN_ACTION_DESCRIPTORS`, because its sends go to the allow-list route.
 *
 * **Add and Change are warnings** with a text field -- Add's labeled Directory, Change's New directory -- under the
 * consequence the person is about to cause; **Remove is a typed-name confirmation** on the directory. `acting` is emitted
 * just before a confirming answer is handed on, so the page can move focus off the dialog first.
 */
@Component({
  selector: 'app-allowed-directory-dialogs',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [TypedNameDialog, WarningDialog],
  template: `@if (pendingWarning; as pending) {
      <app-warning-dialog
        fieldKind="text"
        [verb]="verbOf(pending)"
        [consequence]="consequenceOf(pending)"
        [fieldLabel]="fieldLabelOf(pending)"
        [fieldHint]="STRINGS.allowedDirectoryHint"
        (confirmed)="onWarning($event)"
        (cancelled)="onCancel()"
      />
    }
    @if (pendingRemove; as pending) {
      <app-typed-name-dialog
        [verb]="verbOf(pending)"
        [target]="pending.directory"
        [consequence]="STRINGS.allowedDirectoryRemoveConsequence"
        (confirmed)="onRemove()"
        (cancelled)="onCancel()"
      />
    }`,
})
export class AllowedDirectoryDialogs {
  /** Emitted just before a confirming answer reaches the service. */
  readonly acting = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly service = inject(AllowedDirectoryActions);

  constructor() {
    const actions = inject(ScreenActions);
    const stops = ALLOWED_DIRECTORY_ACTIONS.map((action) =>
      actions.register(ALLOWED_DIRECTORY_LIST, action, () => this.service.open(action), () => this.service.reason())
    );
    void this.service.load();
    inject(DestroyRef).onDestroy(() => {
      for (const stop of stops) stop();
      this.service.cancel();
    });
  }

  /** The Add or Change dialog the service has open, or `null`. */
  protected get pendingWarning(): PendingAllowedDirectory | null {
    const pending = this.service.pending();
    return pending !== null && pending.action !== 'remove' ? pending : null;
  }

  /** The Remove dialog the service has open, or `null`. */
  protected get pendingRemove(): PendingAllowedDirectory | null {
    const pending = this.service.pending();
    return pending?.action === 'remove' ? pending : null;
  }

  protected verbOf(pending: PendingAllowedDirectory): string {
    return actionLabel(ALLOWED_DIRECTORY_LIST, pending.action);
  }

  protected fieldLabelOf(pending: PendingAllowedDirectory): string {
    return pending.action === 'add' ? STRINGS.lockColumnDirectory : STRINGS.allowedDirectoryNewLabel;
  }

  /** An add's consequence restricts the list while it is unrestricted; a change's names the row it moves off. */
  protected consequenceOf(pending: PendingAllowedDirectory): string {
    if (pending.action === 'add') return pending.unrestricted ? STRINGS.allowedDirectoryAddRestricts : STRINGS.allowedDirectoryAddConsequence;
    return STRINGS.allowedDirectoryChangeConsequence.replace(DIRECTORY_PLACEHOLDER, () => pending.directory);
  }

  protected onWarning(answer: WarningAnswer): void {
    this.acting.emit();
    void this.service.confirm(answer.value ?? '');
  }

  protected onRemove(): void {
    this.acting.emit();
    void this.service.confirm();
  }

  protected onCancel(): void {
    this.service.cancel();
  }
}
