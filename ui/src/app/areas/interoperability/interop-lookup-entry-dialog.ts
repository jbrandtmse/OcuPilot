import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { INTEROP_LOOKUP_FIELDS, InteropLookupEntryStore } from './interop-lookup-entry.store';

/** How many entry dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * Lookup tables' New table and a table's Add entry (Story 20.5): the fields of one new entry, the sentence that it
 * is in effect at once, and a primary button that posts through `InteropLookupEntryStore` to `namespace`.
 *
 * **One dialog serves both.** A table is created by its first entry, so with no `table` the dialog asks for the new
 * table's name, its first key and its value, and says so; with a `table` the table is shown fixed and only the key and
 * the value are asked. The value is a multi-line field and may be left empty.
 *
 * A refusal on a field is drawn under the field and named by it (`aria-invalid`, `aria-describedby`); any other
 * refusal, such as a key the table already holds or a namespace under source control, is drawn above the fields as an
 * alert. Both are the server's sentences. An accepted add emits `added` with the table's name; Cancel, Escape and the
 * scrim emit `cancelled`. The button is `aria-disabled` while the table or the key is blank or an add is in flight.
 */
@Component({
  selector: 'app-interop-lookup-entry-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    @if (newTable) {
      <p class="ocu-banner" data-interop-lookup-new-table-help>{{ STRINGS.interopLookupNewTableHelp }}</p>
    }
    <p class="ocu-banner" data-interop-lookup-entry-help>{{ STRINGS.interopLookupEntryHelp }}</p>
    @if (reason) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-interop-lookup-reason>{{ reason }}</p>
    }
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label" [class.ocu-field-label-required]="newTable" [attr.for]="fieldId('table')">{{ STRINGS.interopLookupFieldTable }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            data-interop-lookup-table
            [id]="fieldId('table')"
            [value]="tableText"
            [readOnly]="!newTable"
            [attr.aria-required]="newTable ? 'true' : null"
            [attr.aria-readonly]="newTable ? null : 'true'"
            [attr.aria-invalid]="tableViolation ? 'true' : null"
            [attr.aria-describedby]="reasonOnly('table', tableViolation)"
            (input)="onText('table', $event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        @if (tableViolation) {
          <p class="ocu-form-error" data-interop-lookup-violation="Table" [id]="reasonId('table')">{{ tableViolation }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="fieldId('key')">{{ STRINGS.interopLookupColumnKey }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            aria-required="true"
            data-interop-lookup-key
            [id]="fieldId('key')"
            [value]="key"
            [attr.aria-invalid]="keyViolation ? 'true' : null"
            [attr.aria-describedby]="reasonOnly('key', keyViolation)"
            (input)="onText('key', $event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        @if (keyViolation) {
          <p class="ocu-form-error" data-interop-lookup-violation="Key" [id]="reasonId('key')">{{ keyViolation }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="fieldId('value')">{{ STRINGS.errorLogColumnValue }}</label>
        <div class="ocu-field-control">
          <textarea
            class="ocu-field-input ocu-field-textarea"
            rows="4"
            spellcheck="false"
            data-interop-lookup-value
            [id]="fieldId('value')"
            [value]="value"
            [attr.aria-invalid]="valueViolation ? 'true' : null"
            [attr.aria-describedby]="reasonOnly('value', valueViolation)"
            (input)="onText('value', $event)"
          ></textarea>
        </div>
        @if (valueViolation) {
          <p class="ocu-form-error" data-interop-lookup-violation="Value" [id]="reasonId('value')">{{ valueViolation }}</p>
        }
      </div>
    </div>
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      data-interop-lookup-confirm
      [attr.aria-disabled]="confirmDisabled"
      (click)="onConfirm()"
    >
      {{ confirmLabel }}
    </button>
  </app-dialog>`,
})
export class InteropLookupEntryDialog {
  /** The namespace the entry is added in: the one the list reads. */
  readonly namespace = input.required<string>();

  /** The table the entry is added to, or `null` to ask for a new table's name. */
  readonly table = input<string | null>(null);

  /** Emitted once, after the instance added the entry, with its table's name. */
  readonly added = output<string>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly store = inject(InteropLookupEntryStore);

  private readonly id = ++dialogCount;

  /** Bumped by the store, so the template re-reads it under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    this.store.reset();
    const stop = this.store.subscribe(() => this.generation.update((value) => value + 1));
    inject(DestroyRef).onDestroy(() => {
      stop();
      this.store.reset();
    });
  }

  protected fieldId(field: string): string {
    return `ocu-interop-lookup-${field}-${this.id}`;
  }

  protected reasonId(field: string): string {
    return `${this.fieldId(field)}-reason`;
  }

  /** A field drawn with no caption is described by its refusal alone: the refusal's id while it has one, else nothing. */
  protected reasonOnly(field: string, violation: string): string | null {
    return violation === '' ? null : this.reasonId(field);
  }

  protected get newTable(): boolean {
    return this.table() === null;
  }

  protected get heading(): string {
    return this.newTable ? STRINGS.interopLookupTableDialogTitle : STRINGS.interopLookupEntryDialogTitle;
  }

  protected get confirmLabel(): string {
    return this.newTable ? STRINGS.interopLookupTableAddAction : STRINGS.interopLookupEntryAddAction;
  }

  /** The table shown: the one typed for a new table, else the one the dialog was given. */
  protected get tableText(): string {
    this.generation();
    return this.newTable ? this.store.table() : (this.table() ?? '');
  }

  protected get key(): string {
    this.generation();
    return this.store.key();
  }

  protected get value(): string {
    this.generation();
    return this.store.value();
  }

  protected get tableViolation(): string {
    this.generation();
    return this.store.violation(INTEROP_LOOKUP_FIELDS.table);
  }

  protected get keyViolation(): string {
    this.generation();
    return this.store.violation(INTEROP_LOOKUP_FIELDS.key);
  }

  protected get valueViolation(): string {
    this.generation();
    return this.store.violation(INTEROP_LOOKUP_FIELDS.value);
  }

  protected get reason(): string {
    this.generation();
    return this.store.reason();
  }

  protected get confirmDisabled(): string | null {
    this.generation();
    return this.store.busy() || this.tableText.trim() === '' || this.store.key().trim() === '' ? 'true' : null;
  }

  protected onText(field: 'table' | 'key' | 'value', event: Event): void {
    if (field === 'table' && !this.newTable) return;
    this.store.set(field, (event.target as HTMLInputElement | HTMLTextAreaElement).value);
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    void this.onConfirm();
  }

  protected async onConfirm(): Promise<void> {
    if (this.confirmDisabled !== null) return;
    const table = this.tableText;
    if (await this.store.add(this.namespace(), this.table())) this.added.emit(table);
  }
}
