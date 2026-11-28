import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import {
  INTEROP_SCHEDULE_DEPLOYABLE,
  INTEROP_SCHEDULE_NAME,
  InteropScheduleStore,
  type ScheduleValues,
} from './interop-schedule.store';

/** How many schedule spec dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/** One text field the dialog draws: the server's member name, its published label, and whether it is a multi-line field. */
interface ScheduleField {
  readonly field: string;
  readonly label: string;
  readonly multiline: boolean;
}

/** The schedule and the description, drawn after the name. */
const TEXT_FIELDS: readonly ScheduleField[] = [
  { field: 'ScheduleSpec', label: STRINGS.taskDetailsSchedule, multiline: false },
  { field: 'Description', label: STRINGS.tableColumnDescription, multiline: true },
];

/**
 * Schedule specs' New schedule spec and Edit (Story 24.15): the name, the schedule, the description and the deployable flag of one schedule spec,
 * the sentence that says what a schedule spec does, and a primary button that saves it.
 *
 * **One dialog serves both.** With no `schedule` it asks for the new schedule spec's name and the button posts through `InteropScheduleStore` to
 * `namespace`, emitting `added`. With a `schedule` (its name) the name is shown read-only, because a name cannot be changed, the form holds the
 * values the store was reset to, and the button emits `submitted` with them for the page to send through the screen action route.
 *
 * A refusal on a field is drawn under the field and named by it (`aria-invalid`, `aria-describedby`); any other refusal, such as a name the namespace
 * holds or a namespace under source control, is drawn above the fields as an alert. Both are the server's sentences. Cancel, Escape and the scrim emit
 * `cancelled`. The button is `aria-disabled` while the name is blank or a save is in flight.
 */
@Component({
  selector: 'app-interop-schedule-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <p class="ocu-banner" data-interop-schedule-help>{{ STRINGS.interopScheduleHelp }}</p>
    @if (reason) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-interop-schedule-reason>{{ reason }}</p>
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
            [id]="fieldId(nameField)"
            [attr.data-interop-schedule-field]="nameField"
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
          <p class="ocu-form-error" [attr.data-interop-schedule-violation]="nameField" [id]="reasonId(nameField)">{{ reasons[nameField] }}</p>
        }
      </div>
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
                [attr.data-interop-schedule-field]="entry.field"
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
                [attr.data-interop-schedule-field]="entry.field"
                [value]="text(entry.field)"
                [attr.aria-invalid]="violation(entry.field) ? 'true' : null"
                [attr.aria-describedby]="reasonOnly(entry.field)"
                (input)="onText(entry.field, $event)"
                (keydown.enter)="onEnter($event)"
              />
            }
          </div>
          @if (reasons[entry.field]) {
            <p class="ocu-form-error" [attr.data-interop-schedule-violation]="entry.field" [id]="reasonId(entry.field)">{{ reasons[entry.field] }}</p>
          }
        </div>
      }
      <div class="ocu-field">
        <label class="ocu-field-checkbox">
          <input
            type="checkbox"
            [id]="fieldId(deployableField)"
            [attr.data-interop-schedule-field]="deployableField"
            [checked]="deployable"
            [attr.aria-describedby]="deployableHelpId"
            (change)="onDeployable($event)"
          />
          <span>{{ STRINGS.interopDefaultSettingColumnDeployable }}</span>
        </label>
        <p class="ocu-field-caption" [id]="deployableHelpId">{{ STRINGS.interopScheduleDeployableHelp }}</p>
        @if (reasons[deployableField]) {
          <p class="ocu-form-error" [attr.data-interop-schedule-violation]="deployableField" [id]="reasonId(deployableField)">{{ reasons[deployableField] }}</p>
        }
      </div>
    </div>
    <button dialogAction type="button" class="ocu-button-primary" data-interop-schedule-confirm [attr.aria-disabled]="confirmDisabled" (click)="onConfirm()">
      {{ STRINGS.actionSave }}
    </button>
  </app-dialog>`,
})
export class InteropScheduleDialog {
  /** The namespace a new schedule spec is added in: the one the list reads. */
  readonly namespace = input.required<string>();

  /** The name of the schedule spec being edited, or `null` to ask for a new schedule spec's name. */
  readonly schedule = input<string | null>(null);

  /** Emitted once, after the instance added the schedule spec, with its name. */
  readonly added = output<string>();

  /** Emitted by an edit's button, with the values the form holds, for the page to send. */
  readonly submitted = output<ScheduleValues>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly textFields = TEXT_FIELDS;

  protected readonly nameField = INTEROP_SCHEDULE_NAME;

  protected readonly deployableField = INTEROP_SCHEDULE_DEPLOYABLE;

  private readonly store = inject(InteropScheduleStore);

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
    return this.schedule() !== null;
  }

  protected get heading(): string {
    const schedule = this.schedule();
    return schedule === null ? STRINGS.interopScheduleAddAction : STRINGS.interopCredentialEditTitle.replace('<name>', () => schedule);
  }

  protected fieldId(field: string): string {
    return `ocu-interop-schedule-${field}-${this.id}`;
  }

  protected get deployableHelpId(): string {
    return `${this.fieldId(INTEROP_SCHEDULE_DEPLOYABLE)}-help`;
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
    const fields = [INTEROP_SCHEDULE_NAME, ...TEXT_FIELDS.map((entry) => entry.field), INTEROP_SCHEDULE_DEPLOYABLE];
    return Object.fromEntries(fields.map((field) => [field, this.violation(field)]));
  }

  protected get reason(): string {
    this.generation();
    return this.store.reason();
  }

  protected get confirmDisabled(): string | null {
    this.generation();
    return this.store.busy() || this.store.value(INTEROP_SCHEDULE_NAME).trim() === '' ? 'true' : null;
  }

  protected onText(field: string, event: Event): void {
    if (this.editing && field === INTEROP_SCHEDULE_NAME) return;
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
    const name = this.store.value(INTEROP_SCHEDULE_NAME);
    if (await this.store.add(this.namespace())) this.added.emit(name);
  }
}
