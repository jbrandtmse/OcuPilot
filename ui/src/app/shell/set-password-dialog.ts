import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  inject,
  input,
  output,
  signal,
  viewChild,
} from '@angular/core';

import { ApiService } from '../core/api';
import { STRINGS } from '../core/strings';
import { Dialog } from './dialog';

/** The password check (Story 18.29): the instance's policy verdict for an account's password. */
const PASSWORD_CHECK_PATH = '/api/ocupilot/users/password-check';

function textOf(source: unknown, key: string): string {
  if (source === null || typeof source !== 'object') return '';
  const value = (source as Record<string, unknown>)[key];
  return typeof value === 'string' ? value : '';
}

/** How many set-password dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * Set another account's password, from the Users list (Story 7.2, FR-37, AD-56): one masked field,
 * its labelled reveal toggle -- 15.1's masked-field pattern -- and the change-on-login checkbox.
 *
 * **The password is write-only.** The field is empty and focused on open (`app-dialog` focuses the
 * first field), `autocomplete="new-password"`, never pre-filled and never echoed. Its value is read
 * from the DOM at submit, untrimmed, and handed to the opener in one `submitted` emission; it is
 * never assigned to a field of this component, and the input is cleared whenever the dialog
 * closes, so no password outlives it (AD-21, AD-35).
 *
 * **Submit stays `aria-disabled` while the field is empty**, and a click then does nothing. The
 * flag's own write, and its refusal stopping the password write, are the handler's (AD-56).
 */
@Component({
  selector: 'app-set-password-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="onClosed()">
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="fieldId">{{ STRINGS.accountNewPasswordLabel }}</label>
        <div class="ocu-field-control">
          <input
            #passwordInput
            class="ocu-field-input"
            [id]="fieldId"
            [type]="inputType"
            autocomplete="new-password"
            spellcheck="false"
            [attr.aria-invalid]="reasonShown ? 'true' : null"
            [attr.aria-describedby]="reasonShown ? reasonId : null"
            (input)="onInput()"
            (blur)="onBlur()"
            (keydown.enter)="onEnter($event)"
          />
          <button
            type="button"
            class="ocu-reveal-toggle"
            [attr.aria-label]="revealLabel"
            [attr.aria-pressed]="revealed"
            (click)="toggleReveal()"
          >
            <span aria-hidden="true">{{ revealGlyph }}</span>
          </button>
        </div>
        @if (reasonShown) {
          <p class="ocu-form-error" [id]="reasonId">{{ reasonText() }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-criteria-marker">
          <input #flagInput type="checkbox" />
          {{ STRINGS.userPasswordChangeOnLogin }}
        </label>
      </div>
    </div>
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      [attr.aria-disabled]="submitDisabled"
      (click)="submit()"
    >
      {{ verb() }}
    </button>
  </app-dialog>`,
})
export class SetPasswordDialog {
  /** The published verb ("Set password"), which is also the confirming action's label. */
  readonly verb = input.required<string>();

  /** The account, as the instance's own list reports it. */
  readonly target = input.required<string>();

  /** The password exactly as typed or pasted, and whether the change-on-login flag is checked. */
  readonly submitted = output<{ readonly password: string; readonly changeOnLogin: boolean }>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly fieldId = `ocu-set-password-${++dialogCount}`;

  /** The sentence the instance's policy gave for the password on the field, or `''`. */
  protected readonly reasonText = signal('');

  protected readonly reasonId = `${this.fieldId}-reason`;

  protected get reasonShown(): boolean {
    return this.reasonText() !== '';
  }

  private readonly api = inject(ApiService);

  private checkSeq = 0;

  private readonly passwordInput = viewChild.required<ElementRef<HTMLInputElement>>('passwordInput');

  private readonly flagInput = viewChild.required<ElementRef<HTMLInputElement>>('flagInput');

  /** Whether the field holds anything -- the one fact about it this component keeps. */
  private readonly filled = signal(false);

  private readonly revealedFlag = signal(false);

  private finished = false;

  constructor() {
    inject(DestroyRef).onDestroy(() => this.clear());
  }

  protected get heading(): string {
    return `${this.verb()} ${this.target()}`;
  }

  protected get submitDisabled(): string | null {
    return this.filled() ? null : 'true';
  }

  protected get revealed(): boolean {
    return this.revealedFlag();
  }

  protected get inputType(): string {
    return this.revealedFlag() ? 'text' : 'password';
  }

  protected get revealGlyph(): string {
    return this.revealedFlag() ? '\u25CF' : '\u25CB';
  }

  protected get revealLabel(): string {
    return this.revealedFlag() ? STRINGS.accountHidePassword : STRINGS.accountShowPassword;
  }

  protected toggleReveal(): void {
    this.revealedFlag.set(!this.revealedFlag());
  }

  protected onInput(): void {
    this.filled.set(this.passwordInput().nativeElement.value !== '');
    // A refusal names the value it was given; an edit leaves it describing nothing on the field.
    if (this.reasonText() !== '') this.reasonText.set('');
  }

  /**
   * On the field's blur: ask the instance's policy and show its reason beside the field. The
   * password is read from the field and sent once; an answer for a value since changed is dropped.
   */
  protected onBlur(): void {
    const password = this.passwordInput().nativeElement.value;
    if (password === '') {
      this.checkSeq += 1;
      this.reasonText.set('');
      return;
    }
    const seq = ++this.checkSeq;
    void this.api
      .requestJson<unknown>(PASSWORD_CHECK_PATH, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: this.target(), password }),
      })
      .then((result) => {
        if (seq !== this.checkSeq || this.finished) return;
        if (this.passwordInput().nativeElement.value !== password) return;
        if (result.kind !== 'ok') return;
        const valid = (result.body as Record<string, unknown> | null)?.['valid'] === true;
        this.reasonText.set(valid ? '' : textOf(result.body, 'reason'));
      });
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    this.submit();
  }

  /** Hand the value on once, untrimmed, then clear the field. An empty field sends nothing. */
  protected submit(): void {
    if (this.finished) return;
    const field = this.passwordInput().nativeElement;
    if (field.value === '') return;
    const password = field.value;
    const changeOnLogin = this.flagInput().nativeElement.checked;
    this.finished = true;
    this.clear();
    this.submitted.emit({ password, changeOnLogin });
  }

  protected onClosed(): void {
    this.clear();
    if (this.finished) return;
    this.finished = true;
    this.cancelled.emit();
  }

  private clear(): void {
    try {
      this.passwordInput().nativeElement.value = '';
    } catch {
      // Already torn down: there is no element left to hold a value.
    }
    this.filled.set(false);
    this.checkSeq += 1;
    this.reasonText.set('');
  }
}
