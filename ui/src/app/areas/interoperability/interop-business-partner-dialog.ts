import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { INTEROP_PARTNER_NAME, INTEROP_PARTNER_VALUE_FIELDS, InteropBusinessPartnerStore, type PartnerValues } from './interop-business-partner.store';

/** How many partner dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/** One field the dialog draws: the server's member name, its published label, and whether it is a multi-line field. */
interface PartnerField {
  readonly field: string;
  readonly label: string;
  readonly multiline: boolean;
}

/** One group of fields under its own heading, or none for the name and description. */
interface PartnerGroup {
  readonly key: string;
  readonly heading: string;
  readonly fields: readonly PartnerField[];
}

/** The six fields of one contact, in the order the dialog draws them, under the member names `prefix` gives. */
function contactFields(prefix: 'Primary' | 'Alternative'): readonly PartnerField[] {
  return [
    { field: `${prefix}Contact`, label: STRINGS.tableColumnName, multiline: false },
    { field: `${prefix}Title`, label: STRINGS.interopPartnerFieldTitle, multiline: false },
    { field: `${prefix}Email`, label: STRINGS.userFieldEmail, multiline: false },
    { field: `${prefix}Phone`, label: STRINGS.interopPartnerColumnPhone, multiline: false },
    { field: `${prefix}Mobile`, label: STRINGS.interopPartnerFieldMobile, multiline: false },
    { field: `${prefix}Notes`, label: STRINGS.interopPartnerFieldNotes, multiline: true },
  ];
}

/** The three groups: the name and description, the primary contact and the alternative contact. */
const GROUPS: readonly PartnerGroup[] = [
  { key: 'partner', heading: '', fields: [{ field: 'Description', label: STRINGS.tableColumnDescription, multiline: true }] },
  { key: 'primary', heading: STRINGS.interopPartnerColumnContact, fields: contactFields('Primary') },
  { key: 'alternative', heading: STRINGS.interopPartnerAlternativeContact, fields: contactFields('Alternative') },
];

/**
 * Business partners' New business partner and Edit (Story 20.26): the fields of one partner in three groups -- its name and
 * description, its primary contact and its alternative contact -- the sentence that a partner changes nothing in how a production
 * runs, and a primary button that saves it.
 *
 * **One dialog serves both.** With no `partner` it asks for the new partner's name and the button posts through
 * `InteropBusinessPartnerStore` to `namespace`, emitting `added`. With a `partner` (its name) the name is shown read-only with the
 * sentence that a partner cannot be renamed, the form holds the values the store was reset to, and the button emits `submitted`
 * with the thirteen values for the page to send through the screen action route.
 *
 * A refusal on a field is drawn under the field and named by it (`aria-invalid`, `aria-describedby`); any other refusal, such as a
 * name the namespace holds or a namespace under source control, is drawn above the fields as an alert. Both are the server's
 * sentences. Cancel, Escape and the scrim emit `cancelled`. The button is `aria-disabled` while the name is blank or a save is in
 * flight.
 */
@Component({
  selector: 'app-interop-business-partner-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <p class="ocu-banner" data-interop-partner-help>{{ STRINGS.interopPartnerHelp }}</p>
    @if (editing) {
      <p class="ocu-banner" data-interop-partner-rename-note>{{ STRINGS.interopPartnerRenameNote }}</p>
    }
    @if (reason) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-interop-partner-reason>{{ reason }}</p>
    }
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label" [class.ocu-field-label-required]="!editing" [attr.for]="fieldId(nameField)">{{ STRINGS.tableColumnName }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            data-interop-partner-field="Name"
            [id]="fieldId(nameField)"
            [value]="text(nameField)"
            [readOnly]="editing"
            [attr.aria-required]="editing ? null : 'true'"
            [attr.aria-readonly]="editing ? 'true' : null"
            [attr.aria-invalid]="violation(nameField) ? 'true' : null"
            [attr.aria-describedby]="reasonOnly(nameField)"
            (input)="onText(nameField, $event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        @if (reasons[nameField]) {
          <p class="ocu-form-error" [attr.data-interop-partner-violation]="nameField" [id]="reasonId(nameField)">{{ reasons[nameField] }}</p>
        }
      </div>
      @for (group of groups; track group.key) {
        <fieldset class="ocu-field ocu-form-fields" [attr.data-interop-partner-group]="group.key">
          @if (group.heading) {
            <legend class="ocu-field-label">{{ group.heading }}</legend>
          }
          @for (entry of group.fields; track entry.field) {
            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="fieldId(entry.field)">{{ entry.label }}</label>
              <div class="ocu-field-control">
                @if (entry.multiline) {
                  <textarea
                    class="ocu-field-input ocu-field-textarea"
                    rows="3"
                    spellcheck="false"
                    [id]="fieldId(entry.field)"
                    [attr.data-interop-partner-field]="entry.field"
                    [value]="text(entry.field)"
                    [attr.aria-invalid]="violation(entry.field) ? 'true' : null"
                    [attr.aria-describedby]="reasonOnly(entry.field)"
                    (input)="onText(entry.field, $event)"
                  ></textarea>
                } @else {
                  <input
                    class="ocu-field-input"
                    type="text"
                    autocomplete="off"
                    spellcheck="false"
                    [id]="fieldId(entry.field)"
                    [attr.data-interop-partner-field]="entry.field"
                    [value]="text(entry.field)"
                    [attr.aria-invalid]="violation(entry.field) ? 'true' : null"
                    [attr.aria-describedby]="reasonOnly(entry.field)"
                    (input)="onText(entry.field, $event)"
                    (keydown.enter)="onEnter($event)"
                  />
                }
              </div>
              @if (reasons[entry.field]) {
                <p class="ocu-form-error" [attr.data-interop-partner-violation]="entry.field" [id]="reasonId(entry.field)">{{ reasons[entry.field] }}</p>
              }
            </div>
          }
        </fieldset>
      }
    </div>
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      data-interop-partner-confirm
      [attr.aria-disabled]="confirmDisabled"
      (click)="onConfirm()"
    >
      {{ STRINGS.actionSave }}
    </button>
  </app-dialog>`,
})
export class InteropBusinessPartnerDialog {
  /** The namespace a new partner is added in: the one the list reads. */
  readonly namespace = input.required<string>();

  /** The name of the partner being edited, or `null` to ask for a new partner's name. */
  readonly partner = input<string | null>(null);

  /** Emitted once, after the instance added the partner, with its name. */
  readonly added = output<string>();

  /** Emitted by an edit's button, with the thirteen values the form holds, for the page to send. */
  readonly submitted = output<PartnerValues>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly groups = GROUPS;

  protected readonly nameField = INTEROP_PARTNER_NAME;

  private readonly store = inject(InteropBusinessPartnerStore);

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

  protected get editing(): boolean {
    return this.partner() !== null;
  }

  protected get heading(): string {
    const partner = this.partner();
    return partner === null ? STRINGS.interopPartnerAddAction : STRINGS.interopPartnerEditTitle.replace('<name>', () => partner);
  }

  protected fieldId(field: string): string {
    return `ocu-interop-partner-${field}-${this.id}`;
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

  /** The refusal on each field the dialog draws, keyed by the server's member name, `''` for a field with none. */
  protected get reasons(): Readonly<Record<string, string>> {
    return Object.fromEntries([INTEROP_PARTNER_NAME, ...INTEROP_PARTNER_VALUE_FIELDS].map((field) => [field, this.violation(field)]));
  }

  protected get reason(): string {
    this.generation();
    return this.store.reason();
  }

  protected get confirmDisabled(): string | null {
    this.generation();
    return this.store.busy() || this.store.value(INTEROP_PARTNER_NAME).trim() === '' ? 'true' : null;
  }

  protected onText(field: string, event: Event): void {
    if (field === INTEROP_PARTNER_NAME && this.editing) return;
    this.store.set(field, (event.target as HTMLInputElement | HTMLTextAreaElement).value);
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    void this.onConfirm();
  }

  protected async onConfirm(): Promise<void> {
    if (this.confirmDisabled !== null) return;
    if (this.editing) {
      this.submitted.emit(this.store.values());
      return;
    }
    const name = this.store.value(INTEROP_PARTNER_NAME);
    if (await this.store.add(this.namespace())) this.added.emit(name);
  }
}
