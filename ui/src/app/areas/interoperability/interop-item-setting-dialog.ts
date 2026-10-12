import { ChangeDetectionStrategy, Component, computed, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';

/** How many Set value dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/** The setting type that is a checkbox: the instance's boolean, stored as `1` or `0`. */
export const BOOLEAN_TYPE = '%Library.Boolean';

/** `template` with `<placeholder>` replaced by `value`, shown as written. */
function fill(template: string, placeholder: string, value: string): string {
  return template.split(`<${placeholder}>`).join(value);
}

/**
 * Set value (Story 20.22): the Item settings row action's dialog, titled "Set value of <name>", with the
 * setting's current value and its default, one field for the new value, and the sentence the change carries.
 *
 * **The field follows the setting's type.** A boolean is a checkbox that sends `1` or `0`; every other
 * setting is a text field, which may be left empty to clear the value. Whether the instance accepts a value is
 * its own answer, which the page passes back as `violation` (drawn under the field, the server's sentence) or
 * `refusal` (any other refusal, drawn above it).
 *
 * **The sentence** is the pending-update one, or, for a setting that is a location on the server, the one that
 * names the value typed as a location the item reads or writes when it runs.
 *
 * **Lookup table entries use the same dialog** (Story 20.5): `title` replaces the heading, `statement` the sentence,
 * `multiline` draws the value as a text area, and `defaultShown` false leaves out the default line an entry has none of.
 * Each default is today's item-settings wording.
 */
@Component({
  selector: 'app-interop-item-setting-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading()" [closeLabel]="STRINGS.actionCancel" (closed)="onClosed()">
    <p class="ocu-banner" data-interop-setting-consequence>{{ consequence() }}</p>
    <p class="ocu-field-caption" data-interop-setting-current>{{ currentLine() }}</p>
    @if (showDefault) {
      <p class="ocu-field-caption" data-interop-setting-default>{{ defaultLine() }}</p>
    }
    @if (hasRefusal) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-interop-setting-reason>{{ refusal() }}</p>
    }
    <div class="ocu-form-fields">
      <div class="ocu-field">
        @if (booleanSetting) {
          <label class="ocu-field-checkbox">
            <input
              type="checkbox"
              data-interop-setting-checkbox
              [id]="fieldId"
              [checked]="checked()"
              [attr.aria-describedby]="describedBy()"
              (change)="onChecked($event)"
            />
            {{ STRINGS.errorLogColumnValue }}
          </label>
        } @else {
          <label class="ocu-field-label" [attr.for]="fieldId">{{ STRINGS.errorLogColumnValue }}</label>
          <div class="ocu-field-control">
            @if (multilineField) {
              <textarea
                class="ocu-field-input ocu-field-textarea"
                rows="4"
                spellcheck="false"
                data-interop-setting-value
                [id]="fieldId"
                [value]="text()"
                [attr.aria-invalid]="violation() ? 'true' : null"
                [attr.aria-describedby]="describedBy()"
                (input)="onText($event)"
              ></textarea>
            } @else {
              <input
                class="ocu-field-input"
                type="text"
                autocomplete="off"
                spellcheck="false"
                data-interop-setting-value
                [id]="fieldId"
                [value]="text()"
                [attr.aria-invalid]="violation() ? 'true' : null"
                [attr.aria-describedby]="describedBy()"
                (input)="onText($event)"
                (keydown.enter)="onEnter($event)"
              />
            }
          </div>
        }
        <p class="ocu-field-caption" data-interop-setting-hint [id]="hintId">{{ hint() }}</p>
        @if (hasViolation) {
          <p class="ocu-form-error" data-interop-setting-violation [id]="reasonId">{{ violation() }}</p>
        }
      </div>
    </div>
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      data-interop-setting-confirm
      [attr.aria-disabled]="sending() ? 'true' : null"
      (click)="submit()"
    >
      {{ STRINGS.interopItemSettingSetAction }}
    </button>
  </app-dialog>`,
})
export class InteropItemSettingDialog {
  /** The setting's name, which titles the dialog unless `title` is given. */
  readonly name = input<string>('');

  /** The dialog's heading, in place of the one that names the setting; `''` keeps that one. */
  readonly title = input<string>('');

  /** The sentence the dialog states above its fields, in place of the pending-update one; `''` keeps that one. */
  readonly statement = input<string>('');

  /** Whether the value is drawn as a multi-line field, for a value that may be long. */
  readonly multiline = input<boolean>(false);

  /** Whether the default line is drawn; an entry of a lookup table has no default. */
  readonly defaultShown = input<boolean>(true);

  /** The setting's current value as the instance reported it. */
  readonly current = input<string>('');

  /** The value the setting takes when the production holds none. */
  readonly defaultValue = input<string>('');

  /** The setting's type, e.g. `%Library.Integer`; a boolean draws a checkbox. */
  readonly type = input<string>('');

  /** Whether the setting is a location on the server, which the sentence names. */
  readonly location = input<boolean>(false);

  /** A send is in flight. */
  readonly sending = input<boolean>(false);

  /** The instance's refusal sentence for any other reason than the value, or `''`. */
  readonly refusal = input<string>('');

  /** The instance's sentence for the value field, or `''`. */
  readonly violation = input<string>('');

  /** Emitted once per Set value, with the value to store. */
  readonly submitted = output<string>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly instance = ++dialogCount;

  protected readonly fieldId = `ocu-interop-setting-value-${this.instance}`;

  protected readonly hintId = `ocu-interop-setting-hint-${this.instance}`;

  protected readonly reasonId = `ocu-interop-setting-reason-${this.instance}`;

  /** The text typed; begins as the current value. */
  protected readonly typed = signal<string | null>(null);

  private closed = false;

  protected readonly heading = computed(() => (this.title() !== '' ? this.title() : fill(STRINGS.interopSettingSetTitle, 'name', this.name())));

  protected readonly isBoolean = computed(() => this.type() === BOOLEAN_TYPE);

  protected readonly text = computed(() => this.typed() ?? this.current());

  protected readonly checked = computed(() => {
    const value = this.typed() ?? this.current();
    return value === '1' || value.toLowerCase() === 'true';
  });

  protected readonly currentLine = computed(() => this.line(STRINGS.interopSettingCurrentLine, this.current()));

  protected readonly defaultLine = computed(() => this.line(STRINGS.interopSettingDefaultLine, this.defaultValue()));

  protected readonly hint = computed(() => (this.isBoolean() ? STRINGS.interopSettingBooleanHint : STRINGS.interopSettingEmptyHint));

  /** The pending-update sentence, or the location sentence naming the value typed. */
  protected readonly consequence = computed(() => {
    if (this.statement() !== '') return this.statement();
    const value = this.typed() ?? this.current();
    if (!this.location() || this.isBoolean() || value === '') return STRINGS.interopItemPendingConsequence;
    return STRINGS.interopSettingLocationConsequence.split('<value>').join(value);
  });

  protected readonly describedBy = computed(() => (this.violation() ? `${this.hintId} ${this.reasonId}` : this.hintId));

  protected get hasRefusal(): boolean {
    return this.refusal() !== '';
  }

  protected get hasViolation(): boolean {
    return this.violation() !== '';
  }

  protected get booleanSetting(): boolean {
    return this.isBoolean();
  }

  protected get multilineField(): boolean {
    return this.multiline();
  }

  protected get showDefault(): boolean {
    return this.defaultShown();
  }

  private line(template: string, value: string): string {
    return fill(template, 'value', value === '' ? STRINGS.tableEmptyValue : value);
  }

  protected onText(event: Event): void {
    this.typed.set((event.target as HTMLInputElement | HTMLTextAreaElement).value);
  }

  protected onChecked(event: Event): void {
    this.typed.set((event.target as HTMLInputElement).checked ? '1' : '0');
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    this.submit();
  }

  /** Hand the value on unless a send is in flight; an empty value is a request to clear it. */
  protected submit(): void {
    if (this.sending()) return;
    this.submitted.emit(this.isBoolean() ? (this.checked() ? '1' : '0') : this.text());
  }

  protected onClosed(): void {
    if (this.closed) return;
    this.closed = true;
    this.cancelled.emit();
  }
}
