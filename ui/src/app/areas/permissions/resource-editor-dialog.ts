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
import { STRINGS } from '../../core/strings';
import type { Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import {
  DESCRIPTION_FIELD,
  NAME_FIELD,
  PUBLIC_PERMISSION_FIELD,
  ResourceEditor,
  canonicalLetters,
} from './resource-editor.store';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** One field, resolved for drawing: its control id, its refusal and its described-by wiring. */
interface FieldView {
  readonly id: string;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/** One public-permission checkbox, resolved for drawing. */
interface LetterView {
  readonly letter: string;
  readonly id: string;
  readonly label: string;
  readonly checked: boolean;
}

/** The published word for one permission letter. */
function permissionWord(letter: string): string {
  if (letter === 'R') return STRINGS.permissionRead;
  if (letter === 'W') return STRINGS.permissionWrite;
  return STRINGS.permissionUse;
}

/**
 * The resource editor (AC1, EXPERIENCE.md's dialog list): one dialog over the Resources list, in
 * create mode from the list's Create and in edit mode from a row's name cell.
 *
 * **Fields are the classic dialog's, in its order**: Name (required, read-only when editing),
 * Description, then a Public permission fieldset with one checkbox per letter the server's rule
 * admits for the name, plus any letter the resource already holds. Validation is the change-password dialog's: a refusal renders at its field
 * with `aria-invalid` and `aria-describedby`, and a refused Save focuses the summary and then the
 * first invalid field.
 *
 * **Every dismissal asks first.** Cancel, Escape and the scrim reach `closed`, and this component
 * emits `closeRequested` for its host, which asks `ResourceEditor.requestClose()` -- the shared leave
 * question when a change is held. While a letter is checked on a resource the server marked
 * privileged it states `privilegedGrantEffect` at the fieldset (AD-10).
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-resource-editor-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="closeRequested.emit()">
    @if (hasSummary) {
      <div #summary class="ocu-banner ocu-form-summary" role="alert" tabindex="-1">
        <ul class="ocu-form-summary-list">
          @for (entry of violations; track $index) {
            <li>
              <button type="button" class="ocu-button-text" (click)="focusField(entry.field)">
                {{ entry.reason }}
              </button>
            </li>
          }
        </ul>
      </div>
    }
    @if (hasReason) {
      <p class="ocu-banner ocu-banner-warning" role="alert">{{ reason }}</p>
    }
    <div class="ocu-field">
      <label class="ocu-field-label ocu-field-label-required" [attr.for]="nameField.id">{{ STRINGS.tableColumnName }}</label>
      <div class="ocu-field-control">
        <input
          class="ocu-field-input"
          type="text"
          autocomplete="off"
          [id]="nameField.id"
          [value]="nameValue"
          [readOnly]="editing"
          aria-required="true"
          [attr.maxlength]="maxLength('Name')"
          [attr.aria-invalid]="nameField.invalid"
          [attr.aria-describedby]="nameField.describedBy"
          (input)="onName($event)"
          (blur)="onNameBlur()"
        />
      </div>
      @if (nameField.invalid) {
        <p class="ocu-field-error" [id]="nameField.id + '-reason'">{{ nameField.reason }}</p>
      }
    </div>
    <div class="ocu-field">
      <label class="ocu-field-label" [attr.for]="descriptionField.id">{{ STRINGS.tableColumnDescription }}</label>
      <div class="ocu-field-control">
        <input
          class="ocu-field-input"
          type="text"
          autocomplete="off"
          [id]="descriptionField.id"
          [value]="descriptionValue"
          [attr.maxlength]="maxLength('Description')"
          [attr.aria-invalid]="descriptionField.invalid"
          [attr.aria-describedby]="descriptionField.describedBy"
          (input)="onDescription($event)"
        />
      </div>
      @if (descriptionField.invalid) {
        <p class="ocu-field-error" [id]="descriptionField.id + '-reason'">{{ descriptionField.reason }}</p>
      }
    </div>
    <fieldset
      class="ocu-field ocu-form-authe"
      [id]="permissionField.id"
      [attr.aria-invalid]="permissionField.invalid"
      [attr.aria-describedby]="permissionDescribedBy"
    >
      <legend class="ocu-field-label">{{ STRINGS.resourceColumnPublicPermission }}</legend>
      @for (entry of letterViews; track entry.letter) {
        <label class="ocu-field-checkbox">
          <input type="checkbox" [id]="entry.id" [checked]="entry.checked" (change)="onLetter(entry.letter, $event)" />
          <span>{{ entry.label }}</span>
        </label>
      }
    </fieldset>
    @if (showEffect) {
      <p class="ocu-field-caption" [id]="effectId">{{ STRINGS.privilegedGrantEffect }}</p>
    }
    @if (permissionField.invalid) {
      <p class="ocu-field-error" [id]="permissionField.id + '-reason'">{{ permissionField.reason }}</p>
    }
    @if (showSaved) {
      <span dialogAction class="ocu-dialog-status" role="status">{{ STRINGS.formSaved }}</span>
    }
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      [attr.aria-disabled]="saveBlocked"
      (click)="onSave()"
    >
      {{ STRINGS.actionSave }}
    </button>
  </app-dialog>`,
})
export class ResourceEditorDialog {
  private readonly store = inject(ResourceEditor);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  /** Emitted for every dismissal path; the host asks whether the dialog may close. */
  readonly closeRequested = output<void>();

  /** Emitted after an accepted Save, which the host follows with the route a create now names. */
  readonly saved = output<void>();

  protected readonly effectId = 'ocu-resource-effect';

  /** Bumped by the store, so the template re-reads it under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  constructor() {
    const stop = this.store.subscribe(() => this.generation.update((value) => value + 1));
    inject(DestroyRef).onDestroy(stop);
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get editing(): boolean {
    this.generation();
    return this.store.mode() === 'edit';
  }

  protected get heading(): string {
    this.generation();
    return this.store.mode() === 'edit'
      ? STRINGS.resourceEditorEdit.replace('<name>', this.store.editedName())
      : STRINGS.resourceEditorCreate;
  }

  protected get nameValue(): string {
    this.generation();
    return this.store.name();
  }

  protected get descriptionValue(): string {
    this.generation();
    return this.store.description();
  }

  protected get letterViews(): readonly LetterView[] {
    this.generation();
    const checked = this.store.letters();
    // A held letter is drawn even where the rule would not offer it, so it can be cleared.
    return [...canonicalLetters(this.store.admitted() + checked)].map((letter) => ({
      letter,
      id: `${this.controlId(PUBLIC_PERMISSION_FIELD)}-${letter}`,
      label: permissionWord(letter),
      checked: checked.includes(letter),
    }));
  }

  /** Whether a letter is checked on a resource the server marked privileged (AD-10). */
  protected get showEffect(): boolean {
    this.generation();
    return this.store.showsPrivilegedEffect();
  }

  protected get permissionDescribedBy(): string | null {
    const ids = [this.showEffect ? this.effectId : null, this.permissionField.describedBy];
    const joined = ids.filter((id): id is string => id !== null).join(' ');
    return joined === '' ? null : joined;
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
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.resourceListEmptyAgent);
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

  /** Save does nothing while a Save is in flight, or in edit mode without a fresh read of the resource. */
  protected get saveBlocked(): boolean {
    this.generation();
    return !this.store.canSave();
  }

  protected get nameField(): FieldView {
    return this.fieldView(NAME_FIELD);
  }

  protected get descriptionField(): FieldView {
    return this.fieldView(DESCRIPTION_FIELD);
  }

  protected get permissionField(): FieldView {
    return this.fieldView(PUBLIC_PERMISSION_FIELD);
  }

  protected maxLength(field: string): number | null {
    this.generation();
    const bound = this.store.maxLength(field);
    return bound > 0 ? bound : null;
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onName(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setName(target.value);
  }

  protected onNameBlur(): void {
    void this.store.onNameBlur();
  }

  protected onDescription(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setDescription(target.value);
  }

  protected onLetter(letter: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setLetter(letter, target.checked);
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
    const id = field === PUBLIC_PERMISSION_FIELD ? `${this.controlId(field)}-${this.store.admitted()[0] ?? ''}` : this.controlId(field);
    document.getElementById(id)?.focus();
  }

  // --- internals -------------------------------------------------------------------------------

  /** After a refused Save: the summary takes focus, then the first invalid field. */
  private focusRefusal(): void {
    const first = this.store.violations()[0];
    if (first === undefined) return;
    this.summary()?.nativeElement.focus();
    this.focusField(first.field);
  }

  private fieldView(field: string): FieldView {
    this.generation();
    const id = this.controlId(field);
    const reason = this.store.violationFor(field);
    const invalid = reason !== '';
    return { id, reason, invalid, describedBy: invalid ? `${id}-reason` : null };
  }

  private controlId(field: string): string {
    return `ocu-resource-${field}`;
  }
}
