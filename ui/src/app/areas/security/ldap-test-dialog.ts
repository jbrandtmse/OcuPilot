import { ChangeDetectionStrategy, Component, DestroyRef, inject, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { LdapEditor } from './ldap-editor.store';

/** The test body's fields, named as the server names them in a refusal. */
export const TEST_USER_FIELD = 'Username';
export const TEST_PASSWORD_FIELD = 'Password';

/**
 * The LDAP editor's Test authentication dialog (Story 16.14, AD-26, AD-39): a user name and a
 * password, tested against the saved configuration the editor holds, and the instance's own lines
 * under one heading, as text.
 *
 * **The lines carry no verdict**: the vendor's test answers the same whatever happened, so the
 * dialog shows what the instance wrote and never reads it as passed or failed. A request the gateway
 * ends before the instance answers reads as no answer.
 *
 * **The password is this dialog's alone** (AD-35): typed into its field, sent with the one request,
 * and cleared when the dialog closes by any path. The editor's store keeps neither it nor the lines
 * once the dialog is gone.
 */
@Component({
  selector: 'app-ldap-test-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.ldapTestAction" [closeLabel]="STRINGS.actionCancel" (closed)="close()">
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="userId">{{ STRINGS.fieldUserName }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            aria-required="true"
            [id]="userId"
            [value]="user()"
            [attr.aria-invalid]="userInvalid"
            [attr.aria-describedby]="userDescribedBy"
            (input)="onUser($event)"
          />
        </div>
        @if (userInvalid) {
          <p class="ocu-form-error" [id]="userId + '-reason'">{{ userReason }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="passwordId">{{ STRINGS.fieldPassword }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="password"
            autocomplete="off"
            aria-required="true"
            [id]="passwordId"
            [value]="password()"
            [attr.aria-invalid]="passwordInvalid"
            [attr.aria-describedby]="passwordDescribedBy"
            (input)="onPassword($event)"
          />
        </div>
        @if (passwordInvalid) {
          <p class="ocu-form-error" [id]="passwordId + '-reason'">{{ passwordReason }}</p>
        }
      </div>
      <div class="ocu-ssl-test-result" role="status">
        @if (hasReason) {
          <p class="ocu-form-error">{{ reason }}</p>
        }
        @if (noAnswer) {
          <p class="ocu-form-error">{{ STRINGS.ldapTestNoAnswer }}</p>
        }
        @if (hasLines) {
          <p class="ocu-field-label" data-test-output>{{ STRINGS.ldapTestOutput }}</p>
          <ul class="ocu-ssl-test-lines">
            @for (line of lines; track $index) {
              <li>{{ line }}</li>
            }
          </ul>
        }
      </div>
    </div>
    <button dialogAction type="button" class="ocu-button-primary" data-action="ldap-test-run" [attr.aria-disabled]="runBlocked" (click)="run()">
      {{ STRINGS.ldapTestAction }}
    </button>
  </app-dialog>`,
})
export class LdapTestDialog {
  private readonly store = inject(LdapEditor);

  protected readonly STRINGS = STRINGS;

  protected readonly userId = 'ocu-ldap-test-user';
  protected readonly passwordId = 'ocu-ldap-test-password';

  /** Emitted once for every dismissal path. */
  readonly closed = output<void>();

  protected readonly user = signal('');

  /** The password to test with. Local to this dialog and cleared when it closes. */
  protected readonly password = signal('');

  /** Bumped by the store, so the template re-reads it under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    const stop = this.store.subscribe(() => this.generation.update((value) => value + 1));
    inject(DestroyRef).onDestroy(() => {
      stop();
      this.password.set('');
      this.store.clearTest();
    });
  }

  protected get userReason(): string {
    this.generation();
    return this.store.testViolationFor(TEST_USER_FIELD);
  }

  protected get userInvalid(): boolean {
    return this.userReason !== '';
  }

  protected get userDescribedBy(): string | null {
    return this.userInvalid ? `${this.userId}-reason` : null;
  }

  protected get passwordReason(): string {
    this.generation();
    return this.store.testViolationFor(TEST_PASSWORD_FIELD);
  }

  protected get passwordInvalid(): boolean {
    return this.passwordReason !== '';
  }

  protected get passwordDescribedBy(): string | null {
    return this.passwordInvalid ? `${this.passwordId}-reason` : null;
  }

  protected get reason(): string {
    this.generation();
    return this.store.testReason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get noAnswer(): boolean {
    this.generation();
    return this.store.testNoAnswer();
  }

  protected get lines(): readonly string[] {
    this.generation();
    return this.store.testLines() ?? [];
  }

  protected get hasLines(): boolean {
    this.generation();
    return this.store.testLines() !== null;
  }

  protected get runBlocked(): string | null {
    this.generation();
    return this.store.testing() || !this.store.canTest() ? 'true' : null;
  }

  protected onUser(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.user.set(target.value);
  }

  protected onPassword(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.password.set(target.value);
  }

  protected run(): void {
    if (this.runBlocked !== null) return;
    void this.store.test(this.user(), this.password());
  }

  protected close(): void {
    this.password.set('');
    this.store.clearTest();
    this.closed.emit();
  }
}
