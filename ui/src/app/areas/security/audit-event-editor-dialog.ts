import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  Injector,
  afterNextRender,
  inject,
  output,
  signal,
  viewChild,
} from '@angular/core';

import { formatDeniedAction } from '../../core/navigation';
import { savedLine } from '../../core/read-back';
import { STRINGS } from '../../core/strings';
import type { Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import {
  AuditEventEditor,
  DESCRIPTION_FIELD,
  ENABLED_FIELD,
  NAME_FIELD,
  SOURCE_FIELD,
  TYPE_FIELD,
} from './audit-event-editor.store';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** One text field, resolved for drawing. */
interface FieldView {
  readonly field: string;
  readonly id: string;
  readonly label: string;
  readonly value: string;
  readonly required: boolean;
  readonly readOnly: boolean;
  readonly maxLength: number | null;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/**
 * The user audit event editor (DW-1573, EXPERIENCE.md's dialog list): one dialog over the User
 * events list, in create mode from the list's Create and in edit mode from a row's name cell.
 *
 * **Fields are the classic dialog's, in its order**: Source, Type and Name (required, read-only
 * when editing), Description, then Enabled -- checked by default on a create and absent on an edit,
 * where enabling and disabling stay the row actions. A refusal renders at its field with
 * `aria-invalid` and `aria-describedby`, and a refused Save focuses the summary and then the first
 * invalid field.
 *
 * **Every dismissal asks first.** Cancel, Escape and the scrim reach `closed`, and this component
 * emits `closeRequested` for its host, which asks `AuditEventEditor.requestClose()`.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-audit-event-editor-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  styles: `
    .ocu-field-checkbox {
      min-block-size: var(--ocu-space-6);
    }
    .ocu-field-checkbox input[type='checkbox'] {
      inline-size: var(--ocu-space-6);
      block-size: var(--ocu-space-6);
      margin: 0;
    }
  `,
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="closeRequested.emit()">
    @if (hasSummary) {
      <div #summary class="ocu-banner ocu-form-summary" role="alert" tabindex="-1">
        <ul class="ocu-form-summary-list">
          @for (entry of violations; track $index) {
            <li>
              <button type="button" class="ocu-button-text" (click)="focusField(entry.field)">{{ entry.reason }}</button>
            </li>
          }
        </ul>
      </div>
    }
    @if (hasReason) {
      <p class="ocu-banner ocu-banner-warning" role="alert">{{ reason }}</p>
    }
    @for (view of fields; track view.field) {
      <div class="ocu-field">
        <label class="ocu-field-label" [class.ocu-field-label-required]="view.required" [attr.for]="view.id">{{ view.label }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            [id]="view.id"
            [value]="view.value"
            [readOnly]="view.readOnly"
            [attr.aria-required]="view.required"
            [attr.maxlength]="view.maxLength"
            [attr.aria-invalid]="view.invalid"
            [attr.aria-describedby]="view.describedBy"
            (input)="onText(view.field, $event)"
          />
        </div>
        @if (view.invalid) {
          <p class="ocu-field-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
        }
      </div>
    }
    @if (creating) {
      <div class="ocu-field">
        <label class="ocu-field-checkbox">
          <input type="checkbox" [id]="enabledId" [checked]="enabledValue" (change)="onEnabled($event)" />
          <span>{{ STRINGS.tableColumnEnabled }}</span>
        </label>
      </div>
    }
    @if (showSaved) {
      <span dialogAction class="ocu-dialog-status" role="status">{{ savedText }}</span>
    }
    <button dialogAction type="button" class="ocu-button-primary" [attr.aria-disabled]="saveBlocked" (click)="onSave()">
      {{ STRINGS.actionSave }}
    </button>
  </app-dialog>`,
})
export class AuditEventEditorDialog {
  private readonly store = inject(AuditEventEditor);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  /** Emitted for every dismissal path; the host asks whether the dialog may close. */
  readonly closeRequested = output<void>();

  /** Emitted after an accepted Save, which the host follows with the route a create now names. */
  readonly saved = output<void>();

  protected readonly enabledId = this.controlId(ENABLED_FIELD);

  /** Bumped by the store, so the template re-reads it under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  constructor() {
    const stop = this.store.subscribe(() => this.generation.update((value) => value + 1));
    inject(DestroyRef).onDestroy(stop);
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get creating(): boolean {
    this.generation();
    return this.store.mode() === 'create';
  }

  protected get heading(): string {
    this.generation();
    return this.store.mode() === 'edit'
      ? STRINGS.auditUserEventEditorEdit.replace('<name>', this.store.editedName())
      : STRINGS.auditUserEventEditorCreate;
  }

  protected get fields(): readonly FieldView[] {
    this.generation();
    const editing = this.store.mode() === 'edit';
    return [
      this.fieldView(SOURCE_FIELD, STRINGS.auditEventFieldSource, this.store.source(), true, editing),
      this.fieldView(TYPE_FIELD, STRINGS.tableColumnType, this.store.type(), true, editing),
      this.fieldView(NAME_FIELD, STRINGS.tableColumnName, this.store.name(), true, editing),
      this.fieldView(DESCRIPTION_FIELD, STRINGS.tableColumnDescription, this.store.description(), false, editing && !this.store.canSave()),
    ];
  }

  protected get enabledValue(): boolean {
    this.generation();
    return this.store.enabled();
  }

  protected get violations(): readonly Violation[] {
    this.generation();
    return this.store.violations();
  }

  protected get hasSummary(): boolean {
    return this.violations.length > 0;
  }

  /** An envelope-level refusal: a privilege denial composed from the published sentence, or the envelope's own reason. */
  protected get reason(): string {
    this.generation();
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') {
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.auditUserEventListEmptyAgent);
    }
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get showSaved(): boolean {
    this.generation();
    return this.store.saved();
  }

  /** "Saved", with the instance's read-back line where the Save answered one (AD-58). */
  protected get savedText(): string {
    this.generation();
    return savedLine(this.store.readBack());
  }

  /** Save does nothing while a Save is in flight, or in edit mode without a fresh read of the event. */
  protected get saveBlocked(): boolean {
    this.generation();
    return !this.store.canSave();
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement)) return;
    if (field === DESCRIPTION_FIELD) this.store.setDescription(target.value);
    else this.store.setPart(field, target.value);
  }

  protected onEnabled(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setEnabled(target.checked);
  }

  protected async onSave(): Promise<void> {
    if (this.saveBlocked) return;
    const accepted = await this.store.save();
    if (accepted) {
      this.saved.emit();
      return;
    }
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
  }

  protected focusField(field: string): void {
    document.getElementById(this.controlId(field))?.focus();
  }

  // --- internals -------------------------------------------------------------------------------

  /** After a refused Save: the summary takes focus, then the first invalid field. */
  private focusRefusal(): void {
    const first = this.store.violations()[0];
    if (first === undefined) return;
    this.summary()?.nativeElement.focus();
    this.focusField(first.field);
  }

  private fieldView(field: string, label: string, value: string, required: boolean, readOnly: boolean): FieldView {
    const id = this.controlId(field);
    const reason = this.store.violationFor(field);
    const invalid = reason !== '';
    const bound = this.store.maxLength(field);
    return {
      field,
      id,
      label,
      value,
      required,
      readOnly,
      maxLength: bound > 0 ? bound : null,
      reason,
      invalid,
      describedBy: invalid ? `${id}-reason` : null,
    };
  }

  private controlId(field: string): string {
    return `ocu-audit-event-${field}`;
  }
}
