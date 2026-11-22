import { ChangeDetectionStrategy, Component, DestroyRef, ElementRef, inject, input, output, signal, viewChild } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import {
  INTEROP_CREDENTIAL_NAME,
  INTEROP_CREDENTIAL_PASSWORD,
  INTEROP_CREDENTIAL_VALUE_FIELDS,
  InteropCredentialStore,
  type CredentialValues,
} from './interop-credential.store';

/** How many credential dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/** What the dialog is for: a new credential, an edit of one, or a new password for one. */
export type CredentialDialogMode = 'add' | 'edit' | 'password';

/**
 * Credentials' New credential, Edit and Set password (Story 24.15, AD-35): the name, the user name, the business partner and the password of one
 * credential, the sentence that says what a credential is, and a primary button that saves it.
 *
 * **One dialog serves all three.** In `add` mode it asks for the new credential's name, user name, business partner and, optionally, password, and
 * the button posts through `InteropCredentialStore` to `namespace`, emitting `added`. In `edit` mode the name is shown read-only, because a name cannot
 * be changed, the form holds the values the store was reset to, and the button emits `submitted` with them for the page to send through the screen
 * action route. In `password` mode only the masked password field is drawn, and the button emits `passwordSubmitted`.
 *
 * **The business partner is a choice of the namespace's partners**, read when the dialog opens, with the published None for no partner.
 *
 * **The password is write-only.** The field is empty on open, `autocomplete="new-password"`, never pre-filled and never echoed. Its value is read
 * from the DOM at submit, untrimmed, handed to the opener in one emission, and never assigned to a field of this component or the store; the input is
 * cleared whenever the dialog closes, so no password outlives it (AD-21, AD-35). Set password stays `aria-disabled` while the field is empty.
 *
 * A refusal on a field is drawn under the field and named by it (`aria-invalid`, `aria-describedby`); any other refusal, such as a name the namespace
 * holds, is drawn above the fields as an alert. Both are the server's sentences. Cancel, Escape and the scrim emit `cancelled`.
 */
@Component({
  selector: 'app-interop-credential-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="onClosed()">
    @if (!passwordOnly) {
      <p class="ocu-banner" data-interop-credential-help>{{ STRINGS.interopCredentialHelp }}</p>
    }
    @if (reason) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-interop-credential-reason>{{ reason }}</p>
    }
    <div class="ocu-form-fields">
      @if (!passwordOnly) {
        <div class="ocu-field">
          <label class="ocu-field-label" [class.ocu-field-label-required]="!editing" [attr.for]="fieldId('Name')">{{ STRINGS.tableColumnName }}</label>
          <div class="ocu-field-control">
            <input
              class="ocu-field-input"
              type="text"
              autocomplete="off"
              spellcheck="false"
              [id]="fieldId('Name')"
              data-interop-credential-field="Name"
              [value]="text('Name')"
              [readOnly]="editing"
              [attr.aria-required]="editing ? null : 'true'"
              [attr.aria-readonly]="editing ? 'true' : null"
              [attr.aria-invalid]="violation('Name') ? 'true' : null"
              [attr.aria-describedby]="reasonOnly('Name')"
              (input)="onText('Name', $event)"
              (keydown.enter)="onEnter($event)"
            />
          </div>
          @if (nameReason) {
            <p class="ocu-form-error" data-interop-credential-violation="Name" [id]="reasonId('Name')">{{ nameReason }}</p>
          }
        </div>
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="fieldId('Username')">{{ STRINGS.fieldUserName }}</label>
          <div class="ocu-field-control">
            <input
              class="ocu-field-input"
              type="text"
              autocomplete="off"
              spellcheck="false"
              [id]="fieldId('Username')"
              data-interop-credential-field="Username"
              [value]="text('Username')"
              [attr.aria-invalid]="violation('Username') ? 'true' : null"
              [attr.aria-describedby]="reasonOnly('Username')"
              (input)="onText('Username', $event)"
              (keydown.enter)="onEnter($event)"
            />
          </div>
          @if (usernameReason) {
            <p class="ocu-form-error" data-interop-credential-violation="Username" [id]="reasonId('Username')">{{ usernameReason }}</p>
          }
        </div>
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="fieldId('BusinessPartner')">{{ STRINGS.interopCredentialBusinessPartner }}</label>
          <div class="ocu-field-control">
            <select
              class="ocu-field-input"
              [id]="fieldId('BusinessPartner')"
              data-interop-credential-field="BusinessPartner"
              [attr.aria-invalid]="violation('BusinessPartner') ? 'true' : null"
              [attr.aria-describedby]="reasonOnly('BusinessPartner')"
              (change)="onPartner($event)"
            >
              <option value="" [selected]="text('BusinessPartner') === ''">{{ STRINGS.sslVerifyPeerNone }}</option>
              @for (partner of partnerOptions; track partner) {
                <option [value]="partner" [selected]="partner === text('BusinessPartner')">{{ partner }}</option>
              }
            </select>
          </div>
          @if (partnerReason) {
            <p class="ocu-form-error" data-interop-credential-violation="BusinessPartner" [id]="reasonId('BusinessPartner')">{{ partnerReason }}</p>
          }
        </div>
      }
      @if (!editing) {
        <div class="ocu-field">
          <label class="ocu-field-label" [class.ocu-field-label-required]="passwordOnly" [attr.for]="fieldId('Password')">{{ STRINGS.fieldPassword }}</label>
          <div class="ocu-field-control">
            <input
              #passwordInput
              class="ocu-field-input"
              type="password"
              autocomplete="new-password"
              spellcheck="false"
              [id]="fieldId('Password')"
              data-interop-credential-field="Password"
              [attr.aria-required]="passwordOnly ? 'true' : null"
              [attr.aria-invalid]="violation('Password') ? 'true' : null"
              [attr.aria-describedby]="reasonOnly('Password')"
              (input)="onPasswordInput()"
              (keydown.enter)="onEnter($event)"
            />
          </div>
          @if (passwordReason) {
            <p class="ocu-form-error" data-interop-credential-violation="Password" [id]="reasonId('Password')">{{ passwordReason }}</p>
          }
        </div>
      }
    </div>
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      data-interop-credential-confirm
      [attr.aria-disabled]="confirmDisabled"
      (click)="onConfirm()"
    >
      {{ passwordOnly ? STRINGS.userActionSetPassword : STRINGS.actionSave }}
    </button>
  </app-dialog>`,
})
export class InteropCredentialDialog {
  /** The namespace a new credential is added in: the one the list reads. */
  readonly namespace = input.required<string>();

  /** What the dialog is for. */
  readonly mode = input<CredentialDialogMode>('add');

  /** The name of the credential being edited or given a password, or `null` for a new one. */
  readonly credential = input<string | null>(null);

  /** Emitted once, after the instance added the credential, with its name. */
  readonly added = output<string>();

  /** Emitted by an edit's button, with the values the form holds, for the page to send. */
  readonly submitted = output<CredentialValues>();

  /** Emitted by Set password's button, with the password exactly as typed, for the page to send. */
  readonly passwordSubmitted = output<string>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly store = inject(InteropCredentialStore);

  private readonly id = ++dialogCount;

  /** Bumped by the store, so the template re-reads it under `OnPush`. */
  private readonly generation = signal(0);

  /** Whether the password field holds anything -- the one fact about it this component keeps. */
  private readonly filled = signal(false);

  private readonly passwordInput = viewChild<ElementRef<HTMLInputElement>>('passwordInput');

  constructor() {
    const stop = this.store.subscribe(() => this.generation.update((value) => value + 1));
    inject(DestroyRef).onDestroy(() => {
      stop();
      this.clearPassword();
      this.store.reset();
    });
    void this.store.loadPartners();
  }

  protected get editing(): boolean {
    return this.mode() === 'edit';
  }

  protected get passwordOnly(): boolean {
    return this.mode() === 'password';
  }

  protected get heading(): string {
    const credential = this.credential();
    if (this.mode() === 'edit' && credential !== null) return STRINGS.interopCredentialEditTitle.replace('<name>', () => credential);
    return this.mode() === 'password' ? STRINGS.userActionSetPassword : STRINGS.interopCredentialAddAction;
  }

  protected fieldId(field: string): string {
    return `ocu-interop-credential-${field}-${this.id}`;
  }

  protected reasonId(field: string): string {
    return `${this.fieldId(field)}-reason`;
  }

  /** A field described by its refusal alone: the refusal's id while it has one, else nothing. */
  protected reasonOnly(field: string): string | null {
    return this.violation(field) === '' ? null : this.reasonId(field);
  }

  protected text(field: string): string {
    this.generation();
    return this.store.value(field);
  }

  protected violation(field: string): string {
    this.generation();
    return this.store.violation(field);
  }

  /** The refusal on each field the dialog draws, `''` for a field with none. */
  protected get nameReason(): string {
    return this.violation(INTEROP_CREDENTIAL_NAME);
  }

  protected get usernameReason(): string {
    return this.violation(INTEROP_CREDENTIAL_VALUE_FIELDS[0]);
  }

  protected get partnerReason(): string {
    return this.violation(INTEROP_CREDENTIAL_VALUE_FIELDS[1]);
  }

  protected get passwordReason(): string {
    return this.violation(INTEROP_CREDENTIAL_PASSWORD);
  }

  protected get reason(): string {
    this.generation();
    return this.store.reason();
  }

  /** The partners to choose from, with the credential's own partner kept in the list even when the namespace no longer lists it. */
  protected get partnerOptions(): readonly string[] {
    this.generation();
    const held = this.store.value('BusinessPartner');
    const partners = this.store.partners();
    return held === '' || partners.includes(held) ? partners : [held, ...partners];
  }

  protected get confirmDisabled(): string | null {
    this.generation();
    if (this.store.busy()) return 'true';
    if (this.passwordOnly) return this.filled() ? null : 'true';
    return this.store.value('Name').trim() === '' ? 'true' : null;
  }

  protected onText(field: string, event: Event): void {
    if (this.editing && field === 'Name') return;
    this.store.set(field, (event.target as HTMLInputElement).value);
  }

  protected onPartner(event: Event): void {
    this.store.set('BusinessPartner', (event.target as HTMLSelectElement).value);
  }

  protected onPasswordInput(): void {
    this.filled.set((this.passwordInput()?.nativeElement.value ?? '') !== '');
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    void this.onConfirm();
  }

  protected onClosed(): void {
    this.clearPassword();
    this.cancelled.emit();
  }

  protected async onConfirm(): Promise<void> {
    if (this.confirmDisabled !== null) return;
    const typed = this.passwordInput()?.nativeElement.value ?? '';
    if (this.passwordOnly) {
      this.passwordSubmitted.emit(typed);
      this.clearPassword();
      return;
    }
    if (this.editing) {
      this.submitted.emit(this.store.values());
      return;
    }
    const name = this.store.value('Name');
    const added = await this.store.add(this.namespace(), typed);
    // A refused add keeps the typed password, so the corrected Save sends it again.
    if (!added) return;
    this.clearPassword();
    this.added.emit(name);
  }

  /** Empty the password field, so what was typed outlives neither a submit nor the dialog. */
  private clearPassword(): void {
    const input = this.passwordInput()?.nativeElement;
    if (input !== undefined) input.value = '';
    this.filled.set(false);
  }
}
