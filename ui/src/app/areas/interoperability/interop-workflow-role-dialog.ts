import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import {
  INTEROP_WORKFLOW_ROLE_CAPACITY,
  INTEROP_WORKFLOW_ROLE_DESCRIPTION,
  INTEROP_WORKFLOW_ROLE_NAME,
  InteropWorkflowRoleStore,
  type WorkflowRoleValues,
} from './interop-workflow-role.store';

/** How many workflow role dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * Workflow roles' New workflow role and Edit (Story 24.17 Batch 3b): the name, the description and the capacity of one workflow role, the sentence that
 * says what a workflow role is, and a primary button that saves it.
 *
 * **One dialog serves both.** With no `workflowRole` it asks for a new workflow role's name, and the button posts through `InteropWorkflowRoleStore` to
 * `namespace`, emitting `added`. With a `workflowRole` (its name) the name is shown read-only, because a name cannot be changed, the form holds the
 * values the store was reset to, and the button emits `submitted` with them for the page to send through the screen action route.
 *
 * A refusal on a field is drawn under the field and named by it (`aria-invalid`, `aria-describedby`); any other refusal, such as a namespace under
 * source control, is drawn above the fields as an alert. Both are the server's sentences. Cancel, Escape and the scrim emit `cancelled`. The button is
 * `aria-disabled` while the name is blank or a save is in flight.
 */
@Component({
  selector: 'app-interop-workflow-role-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <p class="ocu-banner" data-interop-workflow-role-help>{{ STRINGS.interopWorkflowRoleHelp }}</p>
    @if (reason) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-interop-workflow-role-reason>{{ reason }}</p>
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
            [attr.data-interop-workflow-role-field]="nameField"
            [value]="name"
            [readOnly]="editing"
            [attr.aria-required]="editing ? null : 'true'"
            [attr.aria-readonly]="editing ? 'true' : null"
            [attr.aria-invalid]="violation(nameField) ? 'true' : null"
            [attr.aria-describedby]="reasonOnly(nameField)"
            (input)="onName($event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        @if (reasons[nameField]) {
          <p class="ocu-form-error" [attr.data-interop-workflow-role-violation]="nameField" [id]="reasonId(nameField)">{{ reasons[nameField] }}</p>
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
            [attr.data-interop-workflow-role-field]="descriptionField"
            [value]="description"
            [attr.aria-invalid]="violation(descriptionField) ? 'true' : null"
            [attr.aria-describedby]="reasonOnly(descriptionField)"
            (input)="onDescription($event)"
          ></textarea>
        </div>
        @if (reasons[descriptionField]) {
          <p class="ocu-form-error" [attr.data-interop-workflow-role-violation]="descriptionField" [id]="reasonId(descriptionField)">{{ reasons[descriptionField] }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="fieldId(capacityField)">{{ STRINGS.promptGroupCapacity }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            inputmode="numeric"
            autocomplete="off"
            spellcheck="false"
            [id]="fieldId(capacityField)"
            [attr.data-interop-workflow-role-field]="capacityField"
            [value]="capacity"
            [attr.aria-invalid]="violation(capacityField) ? 'true' : null"
            [attr.aria-describedby]="reasonOnly(capacityField)"
            (input)="onCapacity($event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        @if (reasons[capacityField]) {
          <p class="ocu-form-error" [attr.data-interop-workflow-role-violation]="capacityField" [id]="reasonId(capacityField)">{{ reasons[capacityField] }}</p>
        }
      </div>
    </div>
    <button dialogAction type="button" class="ocu-button-primary" data-interop-workflow-role-confirm [attr.aria-disabled]="confirmDisabled" (click)="onConfirm()">
      {{ STRINGS.actionSave }}
    </button>
  </app-dialog>`,
})
export class InteropWorkflowRoleDialog {
  /** The namespace a new workflow role is added in: the one the list reads. */
  readonly namespace = input.required<string>();

  /** The name of the workflow role being edited, or `null` to ask for a new workflow role's name. */
  readonly workflowRole = input<string | null>(null);

  /** Emitted once, after the instance added the workflow role, with its name. */
  readonly added = output<string>();

  /** Emitted by an edit's button, with the values the form holds, for the page to send. */
  readonly submitted = output<WorkflowRoleValues>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly nameField = INTEROP_WORKFLOW_ROLE_NAME;

  protected readonly descriptionField = INTEROP_WORKFLOW_ROLE_DESCRIPTION;

  protected readonly capacityField = INTEROP_WORKFLOW_ROLE_CAPACITY;

  private readonly store = inject(InteropWorkflowRoleStore);

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
    return this.workflowRole() !== null;
  }

  protected get heading(): string {
    const role = this.workflowRole();
    return role === null ? STRINGS.interopWorkflowRoleAddAction : STRINGS.interopCredentialEditTitle.replace('<name>', () => role);
  }

  protected fieldId(field: string): string {
    return `ocu-interop-workflow-role-${field}-${this.id}`;
  }

  protected reasonId(field: string): string {
    return `${this.fieldId(field)}-reason`;
  }

  /** A field described by its refusal alone: the refusal's id while it has one, else nothing. */
  protected reasonOnly(field: string): string | null {
    return this.violation(field) === '' ? null : this.reasonId(field);
  }

  protected get name(): string {
    this.generation();
    return this.store.name();
  }

  protected get description(): string {
    this.generation();
    return this.store.description();
  }

  protected get capacity(): string {
    this.generation();
    return this.store.capacity();
  }

  protected violation(field: string): string {
    this.generation();
    return this.store.violation(field);
  }

  /** The refusal on each field the dialog draws, keyed by the server's member name, `''` for a field with none. */
  protected get reasons(): Readonly<Record<string, string>> {
    return Object.fromEntries([INTEROP_WORKFLOW_ROLE_NAME, INTEROP_WORKFLOW_ROLE_DESCRIPTION, INTEROP_WORKFLOW_ROLE_CAPACITY].map((field) => [field, this.violation(field)]));
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

  protected onDescription(event: Event): void {
    this.store.setDescription((event.target as HTMLTextAreaElement).value);
  }

  protected onCapacity(event: Event): void {
    this.store.setCapacity((event.target as HTMLInputElement).value);
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
    const name = this.store.name();
    if (await this.store.add(this.namespace())) this.added.emit(name);
  }
}
