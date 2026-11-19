import { ChangeDetectionStrategy, Component, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';

/** How many dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/** What the dialog hands its page: the new locale's name and its description, `''` when none is typed. */
export interface LocaleCopyValues {
  readonly name: string;
  readonly description: string;
}

/**
 * Locale definitions' Copy (Story 21.16, AD-53): the name of the new custom locale and an optional description, over the locale being copied.
 *
 * **It composes no rule of its own.** The page sends the typed name to the instance with the selected locale as `Source`, and every sentence a
 * refusal shows is the server's, drawn above the fields. The button is `aria-disabled` while the name is blank or a copy is in flight; Cancel,
 * Escape and the scrim emit `cancelled`.
 */
@Component({
  selector: 'app-locale-copy-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    @if (refusalText) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-locale-copy-reason>{{ refusalText }}</p>
    }
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="fieldId('name')">{{ STRINGS.tableColumnName }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            aria-required="true"
            data-locale-copy-field="Name"
            [id]="fieldId('name')"
            [value]="name()"
            (input)="name.set(valueOf($event))"
            (keydown.enter)="onConfirm()"
          />
        </div>
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="fieldId('description')">{{ STRINGS.tableColumnDescription }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            data-locale-copy-field="Description"
            [id]="fieldId('description')"
            [value]="description()"
            (input)="description.set(valueOf($event))"
            (keydown.enter)="onConfirm()"
          />
        </div>
      </div>
    </div>
    <button dialogAction type="button" class="ocu-button-primary" data-locale-copy-confirm [attr.aria-disabled]="confirmDisabled" (click)="onConfirm()">
      {{ STRINGS.auditDatabaseCopyConfirm }}
    </button>
  </app-dialog>`,
})
export class LocaleCopyDialog {
  /** The locale being copied, which the heading names. */
  readonly source = input.required<string>();

  /** The instance's refusal of the last attempt, which the page draws above the fields, or `''`. */
  readonly refusal = input('');

  /** Whether a copy is in flight, which holds the button. */
  readonly sending = input(false);

  /** Emitted with what was typed when the button is pressed with a name. */
  readonly submitted = output<LocaleCopyValues>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly id = ++dialogCount;

  protected readonly name = signal('');

  protected readonly description = signal('');

  protected get refusalText(): string {
    return this.refusal();
  }

  protected get heading(): string {
    return STRINGS.localeCopyTitle.replace('<locale>', this.source());
  }

  protected get confirmDisabled(): 'true' | null {
    return this.name().trim() === '' || this.sending() ? 'true' : null;
  }

  protected fieldId(field: string): string {
    return `ocu-locale-copy-${field}-${this.id}`;
  }

  protected valueOf(event: Event): string {
    return (event.target as HTMLInputElement).value;
  }

  protected onConfirm(): void {
    if (this.confirmDisabled !== null) return;
    this.submitted.emit({ name: this.name().trim(), description: this.description().trim() });
  }
}
