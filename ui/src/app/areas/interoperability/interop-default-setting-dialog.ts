import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import {
  INTEROP_DEFAULT_SETTING_DEPLOYABLE,
  INTEROP_DEFAULT_SETTING_KEY_FIELDS,
  INTEROP_DEFAULT_SETTING_TEXT_FIELDS,
  InteropDefaultSettingStore,
  type DefaultSettingValues,
} from './interop-default-setting.store';

/** How many default setting dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/** One field the dialog draws: the server's member name, its published label, and whether it is a multi-line field. */
interface SettingField {
  readonly field: string;
  readonly label: string;
  readonly multiline: boolean;
}

/** The four key parts, drawn read-only by an edit, then the value and the description. */
const KEY_FIELDS: readonly SettingField[] = [
  { field: 'Production', label: STRINGS.systemInfoProduction, multiline: false },
  { field: 'Item', label: STRINGS.interopItemSettingsCriterionItem, multiline: false },
  { field: 'HostClass', label: STRINGS.interopItemColumnClass, multiline: false },
  { field: 'Setting', label: STRINGS.agentGovernanceColumnSetting, multiline: false },
];

const TEXT_FIELDS: readonly SettingField[] = [
  { field: 'Value', label: STRINGS.errorLogColumnValue, multiline: false },
  { field: 'Description', label: STRINGS.tableColumnDescription, multiline: true },
];

/**
 * System default settings' New default setting and Edit (Story 24.15): the four parts of one setting's key, its value, its description
 * and its deployable flag, the sentence that says what a default does, and a primary button that saves it.
 *
 * **One dialog serves both.** With no `setting` it asks for the new setting's key and the button posts through
 * `InteropDefaultSettingStore` to `namespace`, emitting `added`. With a `setting` (its name) the four key parts are shown read-only, because
 * a key cannot be changed, the form holds the values the store was reset to, and the button emits `submitted` with them for the page to send
 * through the screen action route.
 *
 * A refusal on a field is drawn under the field and named by it (`aria-invalid`, `aria-describedby`); any other refusal, such as a key the
 * namespace holds or a namespace under source control, is drawn above the fields as an alert. Both are the server's sentences. Cancel,
 * Escape and the scrim emit `cancelled`. The button is `aria-disabled` while the setting's name is blank or a save is in flight.
 */
@Component({
  selector: 'app-interop-default-setting-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <p class="ocu-banner" data-interop-default-setting-help>{{ STRINGS.interopDefaultSettingHelp }}</p>
    @if (reason) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-interop-default-setting-reason>{{ reason }}</p>
    }
    <div class="ocu-form-fields">
      @for (entry of keyFields; track entry.field) {
        <div class="ocu-field">
          <label class="ocu-field-label" [class.ocu-field-label-required]="!editing" [attr.for]="fieldId(entry.field)">{{ entry.label }}</label>
          <div class="ocu-field-control">
            <input
              class="ocu-field-input"
              type="text"
              autocomplete="off"
              spellcheck="false"
              [id]="fieldId(entry.field)"
              [attr.data-interop-default-setting-field]="entry.field"
              [value]="text(entry.field)"
              [readOnly]="editing"
              [attr.aria-required]="editing ? null : 'true'"
              [attr.aria-readonly]="editing ? 'true' : null"
              [attr.aria-invalid]="violation(entry.field) ? 'true' : null"
              [attr.aria-describedby]="reasonOnly(entry.field)"
              (input)="onText(entry.field, $event)"
              (keydown.enter)="onEnter($event)"
            />
          </div>
          @if (reasons[entry.field]) {
            <p class="ocu-form-error" [attr.data-interop-default-setting-violation]="entry.field" [id]="reasonId(entry.field)">{{ reasons[entry.field] }}</p>
          }
        </div>
      }
      @for (entry of textFields; track entry.field) {
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="fieldId(entry.field)">{{ entry.label }}</label>
          <div class="ocu-field-control">
            @if (entry.multiline) {
              <textarea
                class="ocu-field-input ocu-field-textarea"
                rows="3"
                spellcheck="false"
                [id]="fieldId(entry.field)"
                [attr.data-interop-default-setting-field]="entry.field"
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
                [attr.data-interop-default-setting-field]="entry.field"
                [value]="text(entry.field)"
                [attr.aria-invalid]="violation(entry.field) ? 'true' : null"
                [attr.aria-describedby]="reasonOnly(entry.field)"
                (input)="onText(entry.field, $event)"
                (keydown.enter)="onEnter($event)"
              />
            }
          </div>
          @if (reasons[entry.field]) {
            <p class="ocu-form-error" [attr.data-interop-default-setting-violation]="entry.field" [id]="reasonId(entry.field)">{{ reasons[entry.field] }}</p>
          }
        </div>
      }
      <div class="ocu-field">
        <label class="ocu-field-checkbox">
          <input
            type="checkbox"
            [id]="fieldId(deployableField)"
            [attr.data-interop-default-setting-field]="deployableField"
            [checked]="deployable"
            [attr.aria-describedby]="deployableHelpId"
            (change)="onDeployable($event)"
          />
          <span>{{ STRINGS.interopDefaultSettingColumnDeployable }}</span>
        </label>
        <p class="ocu-field-caption" [id]="deployableHelpId">{{ STRINGS.interopDefaultSettingDeployableHelp }}</p>
        @if (reasons[deployableField]) {
          <p class="ocu-form-error" [attr.data-interop-default-setting-violation]="deployableField" [id]="reasonId(deployableField)">{{ reasons[deployableField] }}</p>
        }
      </div>
    </div>
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      data-interop-default-setting-confirm
      [attr.aria-disabled]="confirmDisabled"
      (click)="onConfirm()"
    >
      {{ STRINGS.actionSave }}
    </button>
  </app-dialog>`,
})
export class InteropDefaultSettingDialog {
  /** The namespace a new setting is added in: the one the list reads. */
  readonly namespace = input.required<string>();

  /** The name of the setting being edited, or `null` to ask for a new setting's key. */
  readonly setting = input<string | null>(null);

  /** Emitted once, after the instance added the setting, with its name. */
  readonly added = output<string>();

  /** Emitted by an edit's button, with the values the form holds, for the page to send. */
  readonly submitted = output<DefaultSettingValues>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly keyFields = KEY_FIELDS;

  protected readonly textFields = TEXT_FIELDS;

  protected readonly deployableField = INTEROP_DEFAULT_SETTING_DEPLOYABLE;

  private readonly store = inject(InteropDefaultSettingStore);

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
    return this.setting() !== null;
  }

  protected get heading(): string {
    const setting = this.setting();
    return setting === null ? STRINGS.interopDefaultSettingAddAction : STRINGS.interopDefaultSettingEditTitle.replace('<setting>', () => setting);
  }

  protected fieldId(field: string): string {
    return `ocu-interop-default-setting-${field}-${this.id}`;
  }

  protected get deployableHelpId(): string {
    return `${this.fieldId(INTEROP_DEFAULT_SETTING_DEPLOYABLE)}-help`;
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

  protected get deployable(): boolean {
    this.generation();
    return this.store.deployable();
  }

  protected violation(field: string): string {
    this.generation();
    return this.store.violation(field);
  }

  /** The refusal on each field the dialog draws, keyed by the server's member name, `''` for a field with none. */
  protected get reasons(): Readonly<Record<string, string>> {
    const fields = [...INTEROP_DEFAULT_SETTING_KEY_FIELDS, ...INTEROP_DEFAULT_SETTING_TEXT_FIELDS, INTEROP_DEFAULT_SETTING_DEPLOYABLE];
    return Object.fromEntries(fields.map((field) => [field, this.violation(field)]));
  }

  protected get reason(): string {
    this.generation();
    return this.store.reason();
  }

  protected get confirmDisabled(): string | null {
    this.generation();
    return this.store.busy() || this.store.value('Setting').trim() === '' ? 'true' : null;
  }

  protected onText(field: string, event: Event): void {
    if (this.editing && (INTEROP_DEFAULT_SETTING_KEY_FIELDS as readonly string[]).includes(field)) return;
    this.store.set(field, (event.target as HTMLInputElement | HTMLTextAreaElement).value);
  }

  protected onDeployable(event: Event): void {
    this.store.setDeployable((event.target as HTMLInputElement).checked);
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
    const name = this.store.value('Setting');
    if (await this.store.add(this.namespace())) this.added.emit(name);
  }
}
