import { ChangeDetectionStrategy, Component, DestroyRef, computed, inject, input, output } from '@angular/core';

import { screenForDescriptor } from '../core/navigation';
import { BroadcastDialog } from './broadcast-dialog';
import { type PendingCheck, PermissionCheck } from './permission-check';
import { PermissionCheckDialog } from './permission-check-dialog';
import { RoleDialog } from './role-dialog';
import { type PendingConfirm, ScreenActionHandler } from './screen-action-handler';
import { SetPasswordDialog } from './set-password-dialog';
import { TypedNameDialog } from './typed-name-dialog';
import { WarningDialog, type WarningAnswer } from './warning-dialog';

/**
 * The dialogs a declared action waits on (AD-53): the typed-name confirm of a destructive action,
 * the warning before a non-delete write, the set-password dialog, the role dialog and the broadcast
 * dialog over a list's checked rows (Story 16.6) -- the ones
 * `ScreenActionHandler` holds pending for `descriptor`, rendered wherever that screen's actions are
 * offered. A list page renders it under its table and the user editor under its form (DW-1501), so
 * the two surfaces show one dialog, not two copies of it. The Check permission dialog (Story 16.3)
 * renders here too, while `PermissionCheck` holds one open for `descriptor`, and is closed when the
 * page that renders it goes.
 *
 * `acting` is emitted just before a dialog's confirming answer reaches the handler, so the page can
 * move focus off the dialog first (a list page's grid).
 */
@Component({
  selector: 'app-screen-action-dialogs',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [BroadcastDialog, PermissionCheckDialog, RoleDialog, SetPasswordDialog, TypedNameDialog, WarningDialog],
  template: `@if (pendingTypedName; as pending) {
      <app-typed-name-dialog
        [verb]="pending.verb"
        [target]="pending.name"
        [consequence]="pending.consequence"
        [advisory]="pending.advisory"
        [flagLabel]="pending.flagLabel"
        (confirmed)="onConfirm($event)"
        (cancelled)="onCancel()"
      />
    }
    @if (pendingSetPassword; as pending) {
      <app-set-password-dialog
        [verb]="pending.verb"
        [target]="pending.target"
        (submitted)="onPassword($event)"
        (cancelled)="onCancel()"
      />
    }
    @if (pendingRole; as pending) {
      <app-role-dialog
        [verb]="pending.verb"
        [target]="pending.target"
        [options]="pending.options"
        [privileged]="pending.privileged"
        [impact]="pending.impact"
        (chose)="onChoose($event)"
        (submitted)="onRole($event)"
        (cancelled)="onCancel()"
      />
    }
    @if (pendingWarning; as pending) {
      <app-warning-dialog
        [verb]="pending.verb"
        [consequence]="pending.consequence"
        [advisory]="pending.advisory"
        [flagLabel]="pending.flagLabel"
        [fieldLabel]="pending.fieldLabel ?? ''"
        [fieldHint]="pending.fieldHint ?? ''"
        (confirmed)="onWarning($event)"
        (cancelled)="onCancel()"
      />
    }
    @if (pendingBroadcast; as pending) {
      <app-broadcast-dialog
        [count]="broadcastCount"
        [max]="broadcastMax"
        [sending]="broadcastSending"
        [sent]="broadcastSent"
        [refusal]="broadcastRefusal"
        (submitted)="onBroadcast($event)"
        (cancelled)="onCancel()"
      />
    }
    @if (pendingCheck; as check) {
      <app-permission-check-dialog [kind]="check.kind" [name]="check.name" (closed)="onCheckClosed()" />
    }`,
})
export class ScreenActionDialogs {
  /** The descriptor whose pending action this renders. */
  readonly descriptor = input.required<string>();

  /** Emitted just before a confirming answer is handed to the handler. */
  readonly acting = output<void>();

  private readonly handler = inject(ScreenActionHandler);

  private readonly check = inject(PermissionCheck);

  constructor() {
    inject(DestroyRef).onDestroy(() => {
      if (this.check.pending()?.descriptor === this.descriptor()) this.check.close();
    });
  }

  private readonly pending = computed<PendingConfirm | null>(() => {
    const pending = this.handler.pending();
    return pending !== null && pending.descriptor === this.descriptor() ? pending : null;
  });

  protected get pendingTypedName(): PendingConfirm | null {
    return this.pendingOf('typed-name');
  }

  protected get pendingSetPassword(): PendingConfirm | null {
    return this.pendingOf('set-password');
  }

  protected get pendingRole(): PendingConfirm | null {
    return this.pendingOf('role');
  }

  protected get pendingWarning(): PendingConfirm | null {
    return this.pendingOf('warning');
  }

  protected get pendingBroadcast(): PendingConfirm | null {
    return this.pendingOf('broadcast');
  }

  /** The checked rows the broadcast dialog opened over. */
  protected get broadcastCount(): number {
    return this.pendingBroadcast?.count ?? 0;
  }

  /** The most processes one broadcast reaches: the screen's declared multi-select `max`. */
  protected get broadcastMax(): number {
    return screenForDescriptor(this.descriptor())?.multiSelect?.max ?? 0;
  }

  protected get broadcastSending(): boolean {
    return this.pendingBroadcast?.sending === true;
  }

  protected get broadcastSent(): boolean {
    return this.pendingBroadcast?.sent === true;
  }

  protected get broadcastRefusal(): string {
    return this.pendingBroadcast?.refusal ?? '';
  }

  /** The Check permission dialog this screen has open (Story 16.3), or `null`. */
  protected get pendingCheck(): PendingCheck | null {
    const pending = this.check.pending();
    return pending !== null && pending.descriptor === this.descriptor() ? pending : null;
  }

  /** Escape, Cancel or the scrim on the Check permission dialog. */
  protected onCheckClosed(): void {
    this.check.close();
  }

  /** The typed name matched: the handler sends the write it was standing in front of. */
  protected onConfirm(flag: boolean): void {
    this.acting.emit();
    this.handler.confirmPending(flag);
  }

  /** The warning was proceeded past, with its checkbox's state and its field's value where drawn (Story 18.4). */
  protected onWarning(answer: WarningAnswer): void {
    this.acting.emit();
    this.handler.confirmPending(answer.flag ?? false, answer.value ?? '');
  }

  /** The set-password dialog's value goes straight to the handler and is held nowhere here. */
  protected onPassword(event: { readonly password: string; readonly changeOnLogin: boolean }): void {
    this.acting.emit();
    void this.handler.submitPassword(event.password, event.changeOnLogin);
  }

  /** The role dialog's choice changed: a Remove role reads the removal's impact for it (AD-8). */
  protected onChoose(role: string): void {
    void this.handler.chooseRole(role);
  }

  /** The broadcast dialog's message, trimmed: the handler sends it and keeps the dialog's state. */
  protected onBroadcast(message: string): void {
    void this.handler.submitBroadcast(message);
  }

  /** The role dialog's one role. */
  protected onRole(role: string): void {
    this.acting.emit();
    this.handler.submitRole(role);
  }

  private pendingOf(kind: PendingConfirm['kind']): PendingConfirm | null {
    const pending = this.pending();
    return pending?.kind === kind ? pending : null;
  }

  /** Escape, Cancel or the scrim: nothing was sent (EXPERIENCE.md `confirm-dialog`). */
  protected onCancel(): void {
    this.handler.cancelPending();
  }
}
