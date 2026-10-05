import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  ElementRef,
  Injector,
  afterNextRender,
  inject,
  signal,
  viewChild,
} from '@angular/core';
import { Router } from '@angular/router';

import { AllowedDirectoriesStore } from '../../core/allowed-directories';
import { ApiService } from '../../core/api';
import { FormDirty } from '../../core/form-dirty';
import { formatDeniedAction, withQuery } from '../../core/navigation';
import { Session } from '../../core/session';
import { STRINGS } from '../../core/strings';
import { STATE_CONFLICT_CODE, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { ServerPathPicker, type ServerPath } from '../../shell/server-path-picker';
import { KEY_LENGTHS } from './encryption-key-file.store';
import {
  ADMIN_FIELD,
  DESCRIPTION_FIELD,
  EncryptionKeyFileForm,
  KEY_LENGTH_FIELD,
  PASSWORD_FIELD,
  PATH_FIELD,
  ROOT_FIELD,
} from './encryption-key-file-form.store';

/** The list this form is reached from, which Cancel returns to. */
export const ENCRYPTION_KEY_FILE_LIST_ROUTE = 'security/encryption-key-file';

/** The confirmation of the password, checked here alone. */
export const CONFIRM_PASSWORD_FIELD = 'Confirm';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** Each field's control id; the picker's two take its prefix. */
export function keyFileFormControlId(field: string): string {
  if (field === ROOT_FIELD) return 'ocu-key-file-form-location-root';
  if (field === PATH_FIELD) return 'ocu-key-file-form-location-path';
  return `ocu-key-file-form-${field}`;
}

/** One field, resolved for drawing. */
interface FieldView {
  readonly id: string;
  readonly reason: string;
  readonly invalid: 'true' | null;
  readonly describedBy: string | null;
}

/**
 * The encryption key file create form (Story 18.7), a `form-page` on
 * `security/encryption-key-file/create` (AD-55), on the license server form's model.
 *
 * **Its fields are the classic create page's**: the key file, chosen through the server-path picker
 * (`kind` `file`) as an allowed directory and a relative name; the administrator name, which defaults
 * to the signed-in user; the password and its confirmation, masked; the cipher security level, 128,
 * 192 or 256 bits, 256 by default; and the key description.
 *
 * **The password is this page's alone**: two signals, cleared after an accepted Save and when the page
 * goes, handed to the store's `save` and never held there (AD-35). A confirmation that differs is
 * refused here before anything is sent; every other refusal is the instance's, drawn on its field.
 *
 * **After a Save** the page states the new key's id, the new key's consequence, that it has not been
 * activated, and the classic page's recommendations in plain form. The unsaved-changes guard is the
 * `form-page` route guard, answered here.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-encryption-key-file-form-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, ServerPathPicker],
  template: `<section class="ocu-form-page">
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

    <p class="ocu-form-legend">{{ STRINGS.formRequiredFieldsLegend }}</p>
    <div class="ocu-form-fields">
      <app-server-path-picker
        idPrefix="ocu-key-file-form-location"
        kind="file"
        [store]="directories"
        [root]="value('root')"
        [path]="value('path')"
        [rootReason]="rootReason"
        [pathReason]="pathReason"
        (changed)="onLocation($event)"
      />

      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="adminField.id">{{ STRINGS.encryptionKeyFileAdminName }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            aria-required="true"
            [id]="adminField.id"
            [value]="value('AdminName')"
            [attr.aria-invalid]="adminField.invalid"
            [attr.aria-describedby]="adminField.describedBy"
            (input)="onText('AdminName', $event)"
          />
        </div>
        <p class="ocu-field-caption" [id]="adminHintId">{{ STRINGS.encryptionKeyFileAdminNameHint }}</p>
        @if (adminInvalid) {
          <p class="ocu-form-error" [id]="adminField.id + '-reason'">{{ adminField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="passwordField.id">{{ STRINGS.fieldPassword }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="password"
            autocomplete="new-password"
            aria-required="true"
            [id]="passwordField.id"
            [value]="passwordText"
            [attr.aria-invalid]="passwordField.invalid"
            [attr.aria-describedby]="passwordField.describedBy"
            (input)="onPassword($event)"
          />
        </div>
        <p class="ocu-field-caption" [id]="passwordHintId">{{ STRINGS.encryptionKeyFilePasswordHint }}</p>
        @if (passwordInvalid) {
          <p class="ocu-form-error" [id]="passwordField.id + '-reason'">{{ passwordField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="confirmField.id">{{ STRINGS.ldapFieldPasswordConfirm }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="password"
            autocomplete="new-password"
            aria-required="true"
            [id]="confirmField.id"
            [value]="confirmText"
            [attr.aria-invalid]="confirmField.invalid"
            [attr.aria-describedby]="confirmField.describedBy"
            (input)="onConfirm($event)"
          />
        </div>
        @if (confirmInvalid) {
          <p class="ocu-form-error" [id]="confirmField.id + '-reason'" data-key-file-form="mismatch">{{ confirmField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="keyLengthField.id">{{ STRINGS.encryptionKeyFileCipherLevel }}</label>
        <select
          class="ocu-field-input"
          [id]="keyLengthField.id"
          [attr.aria-invalid]="keyLengthField.invalid"
          [attr.aria-describedby]="keyLengthField.describedBy"
          (change)="onText('KeyLen', $event)"
        >
          @for (option of keyLengths; track option.value) {
            <option [value]="option.value" [selected]="option.value === keyLength">{{ option.label }}</option>
          }
        </select>
        @if (keyLengthInvalid) {
          <p class="ocu-form-error" [id]="keyLengthField.id + '-reason'">{{ keyLengthField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="descriptionField.id">{{ STRINGS.encryptionKeyFileKeyDescription }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            [id]="descriptionField.id"
            [value]="value('Description')"
            [attr.aria-invalid]="descriptionField.invalid"
            [attr.aria-describedby]="descriptionField.describedBy"
            (input)="onText('Description', $event)"
          />
        </div>
        @if (descriptionInvalid) {
          <p class="ocu-form-error" [id]="descriptionField.id + '-reason'">{{ descriptionField.reason }}</p>
        }
      </div>
    </div>

    @if (savedFlag) {
      <div class="ocu-banner" role="status" data-key-file-form="saved">
        <p>{{ newKeyLine }}</p>
        <p>{{ STRINGS.encryptionKeyFileNewKeyConsequence }}</p>
        <p>{{ STRINGS.encryptionKeyFileNotActivated }}</p>
        <ul>
          <li>{{ STRINGS.encryptionKeyFileRecommendAdmin }}</li>
          <li>{{ STRINGS.encryptionKeyFileRecommendBackup }}</li>
          <li>{{ STRINGS.encryptionKeyFileRecommendStore }}</li>
        </ul>
      </div>
    }

    <div class="ocu-form-bar">
      <div class="ocu-form-bar-status"></div>
      <div class="ocu-form-bar-actions">
        <button type="button" class="ocu-button-text" (click)="cancel()">{{ STRINGS.actionCancel }}</button>
        <button type="button" class="ocu-button-primary" data-key-file-form="save" [attr.aria-disabled]="saveBlocked" (click)="onSave()">
          {{ STRINGS.actionSave }}
        </button>
      </div>
    </div>

    @if (leavePending) {
      <app-dialog [heading]="STRINGS.formLeaveWithoutSaving" [closeLabel]="STRINGS.actionCancel" (closed)="answerLeave(false)">
        <button dialogAction type="button" class="ocu-button-primary" (click)="answerLeave(true)">{{ STRINGS.actionConfirm }}</button>
      </app-dialog>
    }
  </section>`,
})
export class EncryptionKeyFileFormPage {
  private readonly store = inject(EncryptionKeyFileForm);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly injector = inject(Injector);
  private readonly api = inject(ApiService);
  private readonly session = inject(Session, { optional: true });

  protected readonly STRINGS = STRINGS;

  protected readonly keyLengths = KEY_LENGTHS;

  protected readonly adminHintId = `${keyFileFormControlId(ADMIN_FIELD)}-hint`;

  protected readonly passwordHintId = `${keyFileFormControlId(PASSWORD_FIELD)}-hint`;

  /** The allowed directories the picker offers, read as the form opens. */
  protected readonly directories = new AllowedDirectoriesStore();

  /** Bumped by both stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  /** The password and its confirmation: this page's alone, never a store's (AD-35). */
  private readonly password = signal('');

  private readonly confirm = signal('');

  /** A confirmation that differs, refused here before anything is sent. */
  private readonly mismatch = signal(false);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  constructor() {
    const stopStore = this.store.subscribe(() => this.generation.update((value) => value + 1));
    const stopDirty = this.formDirty.subscribe(() => this.generation.update((value) => value + 1));
    this.store.open(this.session?.userName() ?? '');
    void this.directories.load(this.api);
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      this.clearPasswords();
      this.store.reset();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected value(field: string): string {
    this.generation();
    return this.store.value(field);
  }

  protected get keyLength(): string {
    return this.value(KEY_LENGTH_FIELD);
  }

  protected get passwordText(): string {
    return this.password();
  }

  protected get confirmText(): string {
    return this.confirm();
  }

  protected get rootReason(): string {
    this.generation();
    return this.store.violationFor(ROOT_FIELD);
  }

  protected get pathReason(): string {
    this.generation();
    return this.store.violationFor(PATH_FIELD);
  }

  protected get saveBlocked(): 'true' | null {
    this.generation();
    return this.store.canSave() ? null : 'true';
  }

  /** The store's refusals, and the confirmation's own where it differs. */
  protected get violations(): readonly Violation[] {
    this.generation();
    const held = this.store.violations();
    return this.mismatch() ? [...held, { field: CONFIRM_PASSWORD_FIELD, code: '', reason: STRINGS.ldapPasswordMismatch }] : held;
  }

  protected get hasSummary(): boolean {
    return this.violations.length > 0;
  }

  /**
   * An envelope-level refusal (AD-8, AD-39): a privilege denial composed from the published sentence,
   * the pair the envelope named and this form's action, a stale save's published sentence, or the
   * envelope's own reason.
   */
  protected get reason(): string {
    this.generation();
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') {
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.encryptionKeyFileCreateRefusedAction);
    }
    if (this.store.refusalCode() === STATE_CONFLICT_CODE) return STRINGS.formStaleSave;
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get savedFlag(): boolean {
    this.generation();
    return this.store.saved();
  }

  /** "New encryption key ID: <id>", the id inserted as written. */
  protected get newKeyLine(): string {
    this.generation();
    const id = this.store.keyId();
    return STRINGS.encryptionKeyFileNewKeyId.replace('<id>', () => id);
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  protected get adminField(): FieldView {
    return this.fieldView(ADMIN_FIELD, this.adminHintId);
  }

  protected get passwordField(): FieldView {
    return this.fieldView(PASSWORD_FIELD, this.passwordHintId);
  }

  protected get confirmField(): FieldView {
    return this.fieldView(CONFIRM_PASSWORD_FIELD, null);
  }

  protected get keyLengthField(): FieldView {
    return this.fieldView(KEY_LENGTH_FIELD, null);
  }

  protected get descriptionField(): FieldView {
    return this.fieldView(DESCRIPTION_FIELD, null);
  }

  protected get adminInvalid(): boolean {
    return this.adminField.invalid !== null;
  }

  protected get passwordInvalid(): boolean {
    return this.passwordField.invalid !== null;
  }

  protected get confirmInvalid(): boolean {
    return this.confirmField.invalid !== null;
  }

  protected get keyLengthInvalid(): boolean {
    return this.keyLengthField.invalid !== null;
  }

  protected get descriptionInvalid(): boolean {
    return this.descriptionField.invalid !== null;
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onLocation(location: ServerPath): void {
    const preselected = location.preselected === true;
    this.store.setValue(ROOT_FIELD, location.root, preselected);
    this.store.setValue(PATH_FIELD, location.path, preselected);
  }

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement || target instanceof HTMLSelectElement) this.store.setValue(field, target.value);
  }

  protected onPassword(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement)) return;
    this.password.set(target.value);
    this.mismatch.set(false);
    this.store.clearViolation(PASSWORD_FIELD);
    this.formDirty.setDirty(true);
  }

  protected onConfirm(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement)) return;
    this.confirm.set(target.value);
    this.mismatch.set(false);
    this.formDirty.setDirty(true);
  }

  protected async onSave(): Promise<void> {
    if (!this.store.canSave()) return;
    if (this.password() !== this.confirm()) {
      this.mismatch.set(true);
      this.afterRefusal();
      return;
    }
    const saved = await this.store.save(this.password());
    if (!saved) {
      this.afterRefusal();
      return;
    }
    this.clearPasswords();
  }

  protected focusField(field: string): void {
    document.getElementById(keyFileFormControlId(field))?.focus();
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(ENCRYPTION_KEY_FILE_LIST_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  /** After a refused Save the error summary takes focus, then the first invalid field. */
  private afterRefusal(): void {
    afterNextRender(
      () => {
        const first = this.violations[0];
        if (first === undefined) return;
        this.summary()?.nativeElement.focus();
        this.focusField(first.field);
      },
      { injector: this.injector }
    );
  }

  private clearPasswords(): void {
    this.password.set('');
    this.confirm.set('');
    this.mismatch.set(false);
  }

  private fieldView(field: string, hint: string | null): FieldView {
    this.generation();
    const id = keyFileFormControlId(field);
    const reason = field === CONFIRM_PASSWORD_FIELD ? (this.mismatch() ? STRINGS.ldapPasswordMismatch : '') : this.store.violationFor(field);
    const invalid = reason !== '';
    const describedBy = [hint, invalid ? `${id}-reason` : null].filter((entry): entry is string => entry !== null).join(' ');
    return { id, reason, invalid: invalid ? 'true' : null, describedBy: describedBy === '' ? null : describedBy };
  }
}
