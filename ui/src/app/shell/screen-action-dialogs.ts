import { ChangeDetectionStrategy, Component, computed, inject, input, output } from '@angular/core';

import { RoleDialog } from './role-dialog';
import { type PendingConfirm, ScreenActionHandler } from './screen-action-handler';
import { SetPasswordDialog } from './set-password-dialog';
import { TypedNameDialog } from './typed-name-dialog';
import { WarningDialog } from './warning-dialog';

/**
 * The dialogs a declared action waits on (AD-53): the typed-name confirm of a destructive action,
 * the warning before a non-delete write, the set-password dialog and the role dialog -- the ones
 * `ScreenActionHandler` holds pending for `descriptor`, rendered wherever that screen's actions are
 * offered. A list page renders it under its table and the user editor under its form (DW-1501), so
 * the two surfaces show one dialog, not two copies of it.
 *
 * `acting` is emitted just before a dialog's confirming answer reaches the handler, so the page can
 * move focus off the dialog first (a list page's grid).
 */
@Component({
  selector: 'app-screen-action-dialogs',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [RoleDialog, SetPasswordDialog, TypedNameDialog, WarningDialog],
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
        (submitted)="onRole($event)"
        (cancelled)="onCancel()"
      />
    }
    @if (pendingWarning; as pending) {
      <app-warning-dialog
        [verb]="pending.verb"
        [consequence]="pending.consequence"
        (confirmed)="onWarning()"
        (cancelled)="onCancel()"
      />
    }`,
})
export class ScreenActionDialogs {
  /** The descriptor whose pending action this renders. */
  readonly descriptor = input.required<string>();

  /** Emitted just before a confirming answer is handed to the handler. */
  readonly acting = output<void>();

  private readonly handler = inject(ScreenActionHandler);

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

  /** The typed name matched: the handler sends the write it was standing in front of. */
  protected onConfirm(flag: boolean): void {
    this.acting.emit();
    this.handler.confirmPending(flag);
  }

  /** The warning was proceeded past. */
  protected onWarning(): void {
    this.acting.emit();
    this.handler.confirmPending();
  }

  /** The set-password dialog's value goes straight to the handler and is held nowhere here. */
  protected onPassword(event: { readonly password: string; readonly changeOnLogin: boolean }): void {
    this.acting.emit();
    void this.handler.submitPassword(event.password, event.changeOnLogin);
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
