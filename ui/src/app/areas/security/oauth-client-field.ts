import { ChangeDetectionStrategy, Component, input, output } from '@angular/core';

import { STRINGS } from '../../core/strings';

/** One option of a select control. */
export interface ClientFieldOption {
  readonly value: string;
  readonly label: string;
}

/**
 * One control of the client configuration editor, resolved for drawing: its field, its control id,
 * its label, which kind of control it is, its value, and its refusal wired to it (AD-39).
 */
export interface ClientFieldControl {
  readonly field: string;
  readonly id: string;
  readonly label: string;
  readonly required: boolean;
  readonly isInput: boolean;
  readonly isSelect: boolean;
  readonly isCheck: boolean;
  readonly isSecret: boolean;
  readonly readOnly: boolean;
  readonly inputType: string;
  readonly value: string;
  readonly checked: boolean;
  readonly options: readonly ClientFieldOption[];
  readonly hasHint: boolean;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/**
 * One field of the OAuth 2.0 client configuration editor: a text or masked input, a select or a
 * checkbox, with its label, a secret's hint and its refusal. It holds no state; the page's store
 * does, and every change is emitted for the page to apply.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-oauth-client-field',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { class: 'ocu-field' },
  template: `@if (isCheck) {
      <label class="ocu-field-checkbox">
        <input type="checkbox" [id]="view.id" [checked]="view.checked" [disabled]="locked()" (change)="onToggle($event)" />
        <span>{{ view.label }}</span>
      </label>
    } @else {
      <label class="ocu-field-label" [class.ocu-field-label-required]="view.required" [attr.for]="view.id">{{ view.label }}</label>
      <div class="ocu-field-control">
        @if (isSelect) {
          <select
            class="ocu-field-input"
            [id]="view.id"
            [disabled]="locked()"
            [attr.aria-required]="requiredOrNull"
            [attr.aria-invalid]="view.invalid"
            [attr.aria-describedby]="view.describedBy"
            (change)="onValue($event)"
          >
            @for (option of view.options; track option.value) {
              <option [value]="option.value" [selected]="option.value === view.value">{{ option.label }}</option>
            }
          </select>
        } @else {
          <input
            class="ocu-field-input"
            spellcheck="false"
            [attr.autocomplete]="autocomplete"
            [type]="view.inputType"
            [id]="view.id"
            [value]="view.value"
            [attr.aria-required]="requiredOrNull"
            [readOnly]="readOnly"
            [attr.aria-invalid]="view.invalid"
            [attr.aria-describedby]="view.describedBy"
            (input)="onValue($event)"
            (blur)="left.emit()"
          />
        }
      </div>
      @if (hasHint) {
        <p class="ocu-field-caption" [id]="view.id + '-hint'">{{ STRINGS.oauthClientSecretHint }}</p>
      }
    }
    @if (invalid) {
      <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
    }`,
})
export class OAuthClientField {
  readonly control = input.required<ClientFieldControl>();

  /** Whether the form refuses input: a read not landed, or a call in flight. */
  readonly locked = input(false);

  /** The value a text control or a select now holds. */
  readonly edited = output<string>();

  /** The state a checkbox now holds. */
  readonly toggled = output<boolean>();

  /** The text control lost focus. */
  readonly left = output<void>();

  protected readonly STRINGS = STRINGS;

  protected get view(): ClientFieldControl {
    return this.control();
  }

  protected get isCheck(): boolean {
    return this.view.isCheck;
  }

  protected get isSelect(): boolean {
    return this.view.isSelect;
  }

  protected get hasHint(): boolean {
    return this.view.hasHint;
  }

  protected get invalid(): boolean {
    return this.view.invalid;
  }

  protected get readOnly(): boolean {
    return this.locked() || this.view.readOnly;
  }

  protected get requiredOrNull(): true | null {
    return this.view.required ? true : null;
  }

  /** A secret is never offered for autofill as a known password; anything else is not autofilled. */
  protected get autocomplete(): string {
    return this.view.isSecret ? 'new-password' : 'off';
  }

  protected onValue(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement || target instanceof HTMLSelectElement) this.edited.emit(target.value);
  }

  protected onToggle(event: Event): void {
    const target = event.target;
    this.toggled.emit(target instanceof HTMLInputElement && target.checked);
  }
}
