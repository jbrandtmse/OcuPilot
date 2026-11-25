import { ChangeDetectionStrategy, Component, DestroyRef, type OnInit, inject, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import {
  INTEROP_WORKFLOW_USER_ACTIVE,
  INTEROP_WORKFLOW_USER_FULL_NAME,
  INTEROP_WORKFLOW_USER_NAME,
  InteropWorkflowUserStore,
  type WorkflowUserValues,
} from './interop-workflow-user.store';

/** How many workflow user dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * Workflow users' New workflow user and Edit (Story 24.17 Batch 3a): the name, the full name and the active flag of one workflow user, the sentence
 * that says what a workflow user is, and a primary button that saves it.
 *
 * **One dialog serves both.** With no `workflowUser` it asks for a new workflow user's name, a choice among the users of the instance that the
 * namespace does not already hold as a workflow user (`held`, compared in any letter case), and the button posts through `InteropWorkflowUserStore`
 * to `namespace`, emitting `added`. With a `workflowUser` (its name) the name is shown read-only, because a name cannot be changed, the form holds
 * the values the store was reset to, and the button emits `submitted` with them for the page to send through the screen action route. An edit that
 * takes an active user inactive states what that does, with `wasActive` saying the user was active when the dialog opened.
 *
 * A refusal on a field is drawn under the field and named by it (`aria-invalid`, `aria-describedby`); any other refusal, such as a namespace under
 * source control, is drawn above the fields as an alert, and so is the sentence the instance gave when it would not list the users to choose from.
 * Both are the server's sentences. Cancel, Escape and the scrim emit `cancelled`. The button is `aria-disabled` while the name is blank or a save is
 * in flight.
 */
@Component({
  selector: 'app-interop-workflow-user-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <p class="ocu-banner" data-interop-workflow-user-help>{{ STRINGS.interopWorkflowUserHelp }}</p>
    @if (reason) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-interop-workflow-user-reason>{{ reason }}</p>
    }
    @if (inactiveNotice) {
      <p class="ocu-banner ocu-banner-warning" data-interop-workflow-user-inactive>{{ STRINGS.interopWorkflowUserInactiveConsequence }}</p>
    }
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label" [class.ocu-field-label-required]="!editing" [attr.for]="fieldId(nameField)">{{ STRINGS.tableColumnName }}</label>
        <div class="ocu-field-control">
          @if (editing) {
            <input
              class="ocu-field-input"
              type="text"
              autocomplete="off"
              spellcheck="false"
              readonly
              aria-readonly="true"
              [id]="fieldId(nameField)"
              [attr.data-interop-workflow-user-field]="nameField"
              [value]="name"
            />
          } @else {
            <select
              class="ocu-field-input"
              aria-required="true"
              [id]="fieldId(nameField)"
              [attr.data-interop-workflow-user-field]="nameField"
              [attr.aria-invalid]="violation(nameField) ? 'true' : null"
              [attr.aria-describedby]="reasonOnly(nameField)"
              (change)="onName($event)"
            >
              <option value="" [selected]="name === ''"></option>
              @for (choice of offered; track choice) {
                <option [value]="choice" [selected]="choice === name">{{ choice }}</option>
              }
            </select>
          }
        </div>
        @if (reasons[nameField]) {
          <p class="ocu-form-error" [attr.data-interop-workflow-user-violation]="nameField" [id]="reasonId(nameField)">{{ reasons[nameField] }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="fieldId(fullNameField)">{{ STRINGS.userColumnFullName }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            [id]="fieldId(fullNameField)"
            [attr.data-interop-workflow-user-field]="fullNameField"
            [value]="fullName"
            [attr.aria-invalid]="violation(fullNameField) ? 'true' : null"
            [attr.aria-describedby]="reasonOnly(fullNameField)"
            (input)="onFullName($event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        @if (reasons[fullNameField]) {
          <p class="ocu-form-error" [attr.data-interop-workflow-user-violation]="fullNameField" [id]="reasonId(fullNameField)">{{ reasons[fullNameField] }}</p>
        }
      </div>
      <div class="ocu-field">
        <label class="ocu-field-checkbox">
          <input
            type="checkbox"
            [id]="fieldId(activeField)"
            [attr.data-interop-workflow-user-field]="activeField"
            [checked]="active"
            (change)="onActive($event)"
          />
          <span>{{ STRINGS.interopColumnActive }}</span>
        </label>
        @if (reasons[activeField]) {
          <p class="ocu-form-error" [attr.data-interop-workflow-user-violation]="activeField" [id]="reasonId(activeField)">{{ reasons[activeField] }}</p>
        }
      </div>
    </div>
    <button dialogAction type="button" class="ocu-button-primary" data-interop-workflow-user-confirm [attr.aria-disabled]="confirmDisabled" (click)="onConfirm()">
      {{ STRINGS.actionSave }}
    </button>
  </app-dialog>`,
})
export class InteropWorkflowUserDialog implements OnInit {
  /** The namespace a new workflow user is added in: the one the list reads. */
  readonly namespace = input.required<string>();

  /** The name of the workflow user being edited, or `null` to ask for a new workflow user's name. */
  readonly workflowUser = input<string | null>(null);

  /** The names the namespace already holds as workflow users, which a new one is not offered. */
  readonly held = input<readonly string[]>([]);

  /** Whether the user being edited was active when the dialog opened. */
  readonly wasActive = input<boolean>(false);

  /** Emitted once, after the instance added the workflow user, with its name. */
  readonly added = output<string>();

  /** Emitted by an edit's button, with the values the form holds, for the page to send. */
  readonly submitted = output<WorkflowUserValues>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly nameField = INTEROP_WORKFLOW_USER_NAME;

  protected readonly fullNameField = INTEROP_WORKFLOW_USER_FULL_NAME;

  protected readonly activeField = INTEROP_WORKFLOW_USER_ACTIVE;

  private readonly store = inject(InteropWorkflowUserStore);

  private readonly id = ++dialogCount;

  /** Bumped by the store, so the template re-reads it under `OnPush`. */
  private readonly generation = signal(0);

  private loaded = false;

  constructor() {
    const stop = this.store.subscribe(() => this.generation.update((value) => value + 1));
    inject(DestroyRef).onDestroy(() => {
      stop();
      this.store.reset();
    });
  }

  /** Read the users a new workflow user may take, once, for a dialog that adds one: the inputs are set by now. */
  ngOnInit(): void {
    if (this.loaded || this.editing) return;
    this.loaded = true;
    void this.store.loadChoices(this.namespace());
  }

  protected get editing(): boolean {
    return this.workflowUser() !== null;
  }

  protected get heading(): string {
    const user = this.workflowUser();
    return user === null ? STRINGS.interopWorkflowUserAddAction : STRINGS.interopCredentialEditTitle.replace('<name>', () => user);
  }

  protected fieldId(field: string): string {
    return `ocu-interop-workflow-user-${field}-${this.id}`;
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

  protected get fullName(): string {
    this.generation();
    return this.store.fullName();
  }

  protected get active(): boolean {
    this.generation();
    return this.store.active();
  }

  /** The users of the instance the namespace does not already hold as workflow users, a name held in any letter case counted as held. */
  protected get offered(): readonly string[] {
    this.generation();
    const held = new Set(this.held().map((entry) => entry.toLowerCase()));
    return this.store.choices().filter((choice) => !held.has(choice.toLowerCase()));
  }

  protected violation(field: string): string {
    this.generation();
    return this.store.violation(field);
  }

  /** The refusal on each field the dialog draws, keyed by the server's member name, `''` for a field with none. */
  protected get reasons(): Readonly<Record<string, string>> {
    return Object.fromEntries([INTEROP_WORKFLOW_USER_NAME, INTEROP_WORKFLOW_USER_FULL_NAME, INTEROP_WORKFLOW_USER_ACTIVE].map((field) => [field, this.violation(field)]));
  }

  /** The refusal that names no field, else the sentence the instance gave when it would not list the users to choose from. */
  protected get reason(): string {
    this.generation();
    return this.store.reason() || (this.editing ? '' : this.store.choicesReason());
  }

  /** Whether an edit has taken a user who was active inactive, which the dialog says what it does. */
  protected get inactiveNotice(): boolean {
    this.generation();
    return this.editing && this.wasActive() && !this.store.active();
  }

  protected get confirmDisabled(): string | null {
    this.generation();
    return this.store.busy() || this.store.name().trim() === '' ? 'true' : null;
  }

  protected onName(event: Event): void {
    this.store.setName((event.target as HTMLSelectElement).value);
  }

  protected onFullName(event: Event): void {
    this.store.setFullName((event.target as HTMLInputElement).value);
  }

  protected onActive(event: Event): void {
    this.store.setActive((event.target as HTMLInputElement).checked);
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
