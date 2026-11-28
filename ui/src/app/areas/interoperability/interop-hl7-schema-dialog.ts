import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import {
  INTEROP_HL7_SCHEMA_BASE,
  INTEROP_HL7_SCHEMA_DESCRIPTION,
  INTEROP_HL7_SCHEMA_NAME,
  InteropHl7SchemaStore,
} from './interop-hl7-schema.store';

/** How many HL7 schema dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * HL7 schemas' New HL7 schema (Story 24.18 Batch 1): the name, the base schema and the description of one custom schema, the sentence that says what a
 * custom schema is, and a primary button that saves it. It follows `InteropWorkflowRoleDialog`'s shape for a new member, without that dialog's edit mode,
 * which a schema has no counterpart for, so it is a component of its own.
 *
 * The base is a choice of the schemas the page's list holds (`bases`), plus none, which is the default and is left out of the post. The button posts
 * through `InteropHl7SchemaStore` to `namespace`, emitting `added`. A refusal on a field is drawn under the field and named by it (`aria-invalid`,
 * `aria-describedby`); any other refusal, such as a namespace under source control, is drawn above the fields as an alert. Both are the server's sentences.
 * Cancel, Escape and the scrim emit `cancelled`. The button is `aria-disabled` while the name is blank or a save is in flight.
 */
@Component({
  selector: 'app-interop-hl7-schema-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.interopHl7SchemaAddAction" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <p class="ocu-banner" data-interop-hl7-schema-help>{{ STRINGS.interopHl7Help }}</p>
    @if (reason) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-interop-hl7-schema-reason>{{ reason }}</p>
    }
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="fieldId(nameField)">{{ STRINGS.tableColumnName }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            [id]="fieldId(nameField)"
            [attr.data-interop-hl7-schema-field]="nameField"
            [value]="name"
            aria-required="true"
            [attr.aria-invalid]="violation(nameField) ? 'true' : null"
            [attr.aria-describedby]="reasonOnly(nameField)"
            (input)="onName($event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        @if (reasons[nameField]) {
          <p class="ocu-form-error" [attr.data-interop-hl7-schema-violation]="nameField" [id]="reasonId(nameField)">{{ reasons[nameField] }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="fieldId(baseField)">{{ STRINGS.interopHl7ColumnBase }}</label>
        <div class="ocu-field-control">
          <select
            class="ocu-field-input"
            [id]="fieldId(baseField)"
            [attr.data-interop-hl7-schema-field]="baseField"
            [attr.aria-invalid]="violation(baseField) ? 'true' : null"
            [attr.aria-describedby]="reasonOnly(baseField)"
            (change)="onBase($event)"
          >
            <option value="" [selected]="base === ''">{{ STRINGS.sslVerifyPeerNone }}</option>
            @for (schema of choices; track schema) {
              <option [value]="schema" [selected]="schema === base">{{ schema }}</option>
            }
          </select>
        </div>
        @if (reasons[baseField]) {
          <p class="ocu-form-error" [attr.data-interop-hl7-schema-violation]="baseField" [id]="reasonId(baseField)">{{ reasons[baseField] }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="fieldId(descriptionField)">{{ STRINGS.tableColumnDescription }}</label>
        <div class="ocu-field-control">
          <textarea
            class="ocu-field-input ocu-field-textarea"
            rows="3"
            spellcheck="false"
            [id]="fieldId(descriptionField)"
            [attr.data-interop-hl7-schema-field]="descriptionField"
            [value]="description"
            [attr.aria-invalid]="violation(descriptionField) ? 'true' : null"
            [attr.aria-describedby]="reasonOnly(descriptionField)"
            (input)="onDescription($event)"
          ></textarea>
        </div>
        @if (reasons[descriptionField]) {
          <p class="ocu-form-error" [attr.data-interop-hl7-schema-violation]="descriptionField" [id]="reasonId(descriptionField)">{{ reasons[descriptionField] }}</p>
        }
      </div>
    </div>
    <button dialogAction type="button" class="ocu-button-primary" data-interop-hl7-schema-confirm [attr.aria-disabled]="confirmDisabled" (click)="onConfirm()">
      {{ STRINGS.actionSave }}
    </button>
  </app-dialog>`,
})
export class InteropHl7SchemaDialog {
  /** The namespace a new schema is added in: the one the list reads. */
  readonly namespace = input.required<string>();

  /** The schemas the namespace holds, which the base may be chosen from. */
  readonly bases = input<readonly string[]>([]);

  /** Emitted once, after the instance added the schema, with its name. */
  readonly added = output<string>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly nameField = INTEROP_HL7_SCHEMA_NAME;

  protected readonly baseField = INTEROP_HL7_SCHEMA_BASE;

  protected readonly descriptionField = INTEROP_HL7_SCHEMA_DESCRIPTION;

  private readonly store = inject(InteropHl7SchemaStore);

  private readonly id = ++dialogCount;

  /** Bumped by the store, so the template re-reads it under `OnPush`. */
  private readonly generation = signal(0);

  constructor() {
    const stop = this.store.subscribe(() => this.generation.update((value) => value + 1));
    inject(DestroyRef).onDestroy(() => {
      stop();
      this.store.reset();
    });
  }

  protected fieldId(field: string): string {
    return `ocu-interop-hl7-schema-${field}-${this.id}`;
  }

  protected reasonId(field: string): string {
    return `${this.fieldId(field)}-reason`;
  }

  /** A field described by its refusal alone: the refusal's id while it has one, else nothing. */
  protected reasonOnly(field: string): string | null {
    return this.violation(field) === '' ? null : this.reasonId(field);
  }

  /** The schemas the base may be chosen from. */
  protected get choices(): readonly string[] {
    return this.bases();
  }

  protected get name(): string {
    this.generation();
    return this.store.name();
  }

  protected get base(): string {
    this.generation();
    return this.store.base();
  }

  protected get description(): string {
    this.generation();
    return this.store.description();
  }

  protected violation(field: string): string {
    this.generation();
    return this.store.violation(field);
  }

  /** The refusal on each field the dialog draws, keyed by the server's member name, `''` for a field with none. */
  protected get reasons(): Readonly<Record<string, string>> {
    return Object.fromEntries([INTEROP_HL7_SCHEMA_NAME, INTEROP_HL7_SCHEMA_BASE, INTEROP_HL7_SCHEMA_DESCRIPTION].map((field) => [field, this.violation(field)]));
  }

  /** The refusal that names no field. */
  protected get reason(): string {
    this.generation();
    return this.store.reason();
  }

  protected get confirmDisabled(): string | null {
    this.generation();
    return this.store.busy() || this.store.name().trim() === '' ? 'true' : null;
  }

  protected onName(event: Event): void {
    this.store.setName((event.target as HTMLInputElement).value);
  }

  protected onBase(event: Event): void {
    this.store.setBase((event.target as HTMLSelectElement).value);
  }

  protected onDescription(event: Event): void {
    this.store.setDescription((event.target as HTMLTextAreaElement).value);
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    void this.onConfirm();
  }

  protected async onConfirm(): Promise<void> {
    if (this.confirmDisabled !== null) return;
    const name = this.store.name();
    if (await this.store.add(this.namespace())) this.added.emit(name);
  }
}
