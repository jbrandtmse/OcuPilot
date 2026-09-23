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

import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService, formatDeniedAction, withQuery } from '../../core/navigation';
import { STRINGS } from '../../core/strings';
import { STATE_CONFLICT_CODE, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { PASSWORD_FIELD, ROLES_FIELD, type RoleOption, UserCreateForm } from './user-create-form.store';

/** The list this form is reached from, which Cancel and the leave confirmation return to. */
const LIST_ROUTE = 'permissions/users';

/** This form's own route, the fallback when the mirror cannot resolve it from the URL. */
const FORM_ROUTE = 'permissions/users/edit';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** One field, resolved for drawing: its control id, its refusal and its described-by wiring. */
interface FieldView {
  readonly id: string;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/**
 * The create-a-user form, a `form-page` over an account on the instance (AD-55, FR-30).
 *
 * **Field order is the acceptance criterion, and it is the classic editor's.** `%CSP.UI.Portal.User`
 * draws name, full name, password, expiration date, startup namespace and startup routine; roles,
 * which that page assigns on a tab after the save, come last here.
 *
 * **The password is masked, never pre-filled and never echoed** (AD-35). The input is bound to the
 * store's value, which is empty until typed and emptied again by an accepted Save, and it asks the
 * browser for a new password rather than a saved one. After a Save it carries the published
 * stored-secret caption.
 *
 * **A role the server refuses to grant is drawn disabled, described by the server's own sentence**
 * from the bootstrap read. The refusal itself is the server's, on either caller (AD-10, AD-39).
 *
 * It composes no payload and authors no field sentence; the unsaved-changes guard is the
 * `form-page` route guard, answered here. Every control-flow condition is a paren-free member
 * reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-user-create-form-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<section class="ocu-form-page">
    @if (hasSummary) {
      <div #summary class="ocu-banner ocu-form-summary" role="alert" tabindex="-1">
        <ul class="ocu-form-summary-list">
          @for (entry of violations; track entry.field) {
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

    @if (loadedFlag) {
    <p class="ocu-form-legend">{{ STRINGS.formRequiredFieldsLegend }}</p>
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="nameField.id">{{ STRINGS.tableColumnName }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            [id]="nameField.id"
            [value]="value('Name')"
            aria-required="true"
            [attr.maxlength]="maxLength('Name')"
            [attr.aria-invalid]="nameField.invalid"
            [attr.aria-describedby]="nameField.describedBy"
            (input)="onText('Name', $event)"
            (blur)="onBlur('Name')"
          />
        </div>
        @if (nameField.invalid) {
          <p class="ocu-form-error" [id]="nameField.id + '-reason'">{{ nameField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="fullNameField.id">{{ STRINGS.userColumnFullName }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            [id]="fullNameField.id"
            [value]="value('FullName')"
            [attr.maxlength]="maxLength('FullName')"
            [attr.aria-invalid]="fullNameField.invalid"
            [attr.aria-describedby]="fullNameField.describedBy"
            (input)="onText('FullName', $event)"
            (blur)="onBlur('FullName')"
          />
        </div>
        @if (fullNameField.invalid) {
          <p class="ocu-form-error" [id]="fullNameField.id + '-reason'">{{ fullNameField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="passwordField.id">{{ STRINGS.fieldPassword }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            [id]="passwordField.id"
            [type]="passwordInputType"
            autocomplete="new-password"
            [value]="passwordValue"
            aria-required="true"
            [attr.aria-invalid]="passwordField.invalid"
            [attr.aria-describedby]="passwordField.describedBy"
            (input)="onPassword($event)"
            (blur)="onBlur('Password')"
          />
          <button
            type="button"
            class="ocu-reveal-toggle"
            [attr.aria-label]="revealLabel"
            [attr.aria-pressed]="revealed()"
            (click)="toggleReveal()"
          >
            <span aria-hidden="true">{{ revealGlyph }}</span>
          </button>
        </div>
        @if (showStoredCaption) {
          <p class="ocu-field-caption" [id]="passwordField.id + '-caption'">{{ STRINGS.formSecretStored }}</p>
        }
        @if (passwordField.invalid) {
          <p class="ocu-form-error" [id]="passwordField.id + '-reason'">{{ passwordField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="expiryField.id">{{ STRINGS.userFormExpiry }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="date"
            [id]="expiryField.id"
            [value]="value('ExpirationDate')"
            [attr.aria-invalid]="expiryField.invalid"
            [attr.aria-describedby]="expiryField.describedBy"
            (input)="onText('ExpirationDate', $event)"
            (blur)="onBlur('ExpirationDate')"
          />
        </div>
        @if (expiryField.invalid) {
          <p class="ocu-form-error" [id]="expiryField.id + '-reason'">{{ expiryField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="namespaceField.id">{{ STRINGS.userFormNamespace }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            [id]="namespaceField.id"
            [value]="value('NameSpace')"
            [attr.maxlength]="maxLength('NameSpace')"
            [attr.aria-invalid]="namespaceField.invalid"
            [attr.aria-describedby]="namespaceField.describedBy"
            (input)="onText('NameSpace', $event)"
            (blur)="onBlur('NameSpace')"
          />
        </div>
        @if (namespaceField.invalid) {
          <p class="ocu-form-error" [id]="namespaceField.id + '-reason'">{{ namespaceField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="routineField.id">{{ STRINGS.userFormRoutine }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            [id]="routineField.id"
            [value]="value('Routine')"
            [attr.maxlength]="maxLength('Routine')"
            [attr.aria-invalid]="routineField.invalid"
            [attr.aria-describedby]="routineField.describedBy"
            (input)="onText('Routine', $event)"
            (blur)="onBlur('Routine')"
          />
        </div>
        @if (routineField.invalid) {
          <p class="ocu-form-error" [id]="routineField.id + '-reason'">{{ routineField.reason }}</p>
        }
      </div>

      <fieldset class="ocu-field ocu-form-authe" [attr.id]="rolesField.id" tabindex="-1">
        <legend class="ocu-field-label">{{ STRINGS.userColumnRoles }}</legend>
        @for (role of roleOptions; track role.name) {
          <label class="ocu-field-checkbox">
            <input
              type="checkbox"
              [id]="roleId(role.name)"
              [checked]="roleChecked(role.name)"
              [disabled]="role.privileged"
              [attr.aria-describedby]="role.privileged ? rolesReasonId : null"
              (change)="onRole(role.name, $event)"
            />
            <span>{{ role.name }}</span>
          </label>
        }
        @if (hasPrivilegedRole) {
          <p class="ocu-field-caption" [id]="rolesReasonId">{{ rolesReason }}</p>
        }
        @if (rolesField.invalid) {
          <p class="ocu-form-error" [id]="rolesField.id + '-reason'">{{ rolesField.reason }}</p>
        }
      </fieldset>
    </div>

    <div class="ocu-form-bar">
      <div class="ocu-form-bar-status">
        @if (showSaved) {
          <span role="status">{{ STRINGS.formSaved }}</span>
        }
      </div>
      <div class="ocu-form-bar-actions">
        <button type="button" class="ocu-button-text" (click)="cancel()">{{ STRINGS.actionCancel }}</button>
        <button
          type="button"
          class="ocu-button-primary"
          [attr.aria-disabled]="busyFlag"
          (click)="onSave()"
        >
          {{ STRINGS.actionSave }}
        </button>
      </div>
    </div>
    }

    @if (leavePending) {
      <app-dialog
        [heading]="STRINGS.formLeaveWithoutSaving"
        [closeLabel]="STRINGS.actionCancel"
        (closed)="answerLeave(false)"
      >
        <button dialogAction type="button" class="ocu-button-primary" (click)="answerLeave(true)">
          {{ STRINGS.actionConfirm }}
        </button>
      </app-dialog>
    }
  </section>`,
})
export class UserCreateFormPage {
  private readonly store = inject(UserCreateForm);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  /** Bumped by both stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  /** Whether the password is shown in clear. Local to this page and never stored. */
  protected readonly revealed = signal(false);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  /** Whether the summary has been focused for the refusal now on screen. */
  private focusedSummary = false;

  constructor() {
    const stopStore = this.store.subscribe(() => this.generation.update((value) => value + 1));
    const stopDirty = this.formDirty.subscribe(() => this.generation.update((value) => value + 1));
    void this.store.open();
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      // Not torn down while the store is carried across the create's own route replacement,
      // which destroys this component and builds it again over the same account.
      if (!this.store.retaining()) this.store.reset();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get loadedFlag(): boolean {
    this.generation();
    return this.store.loaded();
  }

  protected get busyFlag(): boolean {
    this.generation();
    return this.store.busy();
  }

  protected get violations(): readonly Violation[] {
    this.generation();
    return this.store.violations();
  }

  protected get hasSummary(): boolean {
    return this.violations.length > 0;
  }

  /**
   * What an envelope-level refusal reads (AD-8, AD-39): a privilege denial composed from the
   * published sentence and the pair the envelope named, a stale save's published sentence, or the
   * envelope's own reason.
   */
  protected get reason(): string {
    this.generation();
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') {
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.userListEmptyAgent);
    }
    if (this.store.refusalCode() === STATE_CONFLICT_CODE) return STRINGS.formStaleSave;
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get passwordValue(): string {
    this.generation();
    return this.store.password();
  }

  protected get passwordInputType(): string {
    return this.revealed() ? 'text' : 'password';
  }

  protected get revealGlyph(): string {
    return this.revealed() ? '\u25CF' : '\u25CB';
  }

  /** The toggle's accessible name, which is what makes it labelled rather than an unnamed icon. */
  protected get revealLabel(): string {
    return this.revealed() ? STRINGS.accountHidePassword : STRINGS.accountShowPassword;
  }

  /**
   * Whether the password field carries the published stored-secret caption: after an accepted
   * Save, when the account holds the password that was sent and the field no longer does.
   */
  protected get showStoredCaption(): boolean {
    this.generation();
    return this.store.saved();
  }

  protected get roleOptions(): readonly RoleOption[] {
    this.generation();
    return this.store.rules().roles;
  }

  protected get hasPrivilegedRole(): boolean {
    return this.rolesReason !== '' && this.roleOptions.some((role) => role.privileged);
  }

  /** The server's sentence for a role it refuses to grant, which each such checkbox is described by. */
  protected get rolesReason(): string {
    this.generation();
    return this.store.rules().rolesReason;
  }

  protected get rolesReasonId(): string {
    return `${this.controlId(ROLES_FIELD)}-privileged`;
  }

  protected get showSaved(): boolean {
    this.generation();
    return this.store.saved();
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  protected value(field: string): string {
    this.generation();
    return this.store.value(field);
  }

  protected roleChecked(name: string): boolean {
    this.generation();
    return this.store.roleChecked(name);
  }

  protected roleId(name: string): string {
    return `${this.controlId(ROLES_FIELD)}-${name}`;
  }

  /** The length the instance stores for `field`, or `null` where it declares none. */
  protected maxLength(field: string): number | null {
    this.generation();
    const bound = this.store.maxLength(field);
    return bound > 0 ? bound : null;
  }

  protected get nameField(): FieldView {
    return this.fieldView('Name');
  }

  protected get fullNameField(): FieldView {
    return this.fieldView('FullName');
  }

  protected get passwordField(): FieldView {
    return this.fieldView(PASSWORD_FIELD);
  }

  protected get expiryField(): FieldView {
    return this.fieldView('ExpirationDate');
  }

  protected get namespaceField(): FieldView {
    return this.fieldView('NameSpace');
  }

  protected get routineField(): FieldView {
    return this.fieldView('Routine');
  }

  protected get rolesField(): FieldView {
    return this.fieldView(ROLES_FIELD);
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setValue(field, target.value);
  }

  protected onPassword(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setPassword(target.value);
  }

  protected onRole(name: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setRole(name, target.checked);
  }

  protected toggleReveal(): void {
    this.revealed.update((value) => !value);
  }

  protected onBlur(field: string): void {
    void this.store.onBlur(field);
  }

  protected async onSave(): Promise<void> {
    if (this.store.busy()) return;
    const saved = await this.store.save();
    if (!saved) {
      this.afterRefusal();
      return;
    }
    // A create replaces the route with the new account's URL, so the address bar names the entity
    // and Back goes to the list. The buffer on screen, less the password, is carried across that
    // one navigation; nothing here reads the `:id`.
    if (this.store.createdId() !== '') {
      this.store.retainAcrossRouteReplacement();
      void this.router.navigateByUrl(this.editorUrl(this.store.createdId()), { replaceUrl: true });
    }
  }

  protected focusField(field: string): void {
    document.getElementById(this.controlId(field))?.focus();
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(LIST_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  /**
   * After a refused Save: the error summary takes focus, then the first invalid field, in the
   * order EXPERIENCE.md's `form-page` validation rule states. `afterNextRender`, because the
   * summary is not in the DOM until this dirty component has painted.
   */
  private afterRefusal(): void {
    if (this.store.violations()[0] === undefined) return;
    this.focusedSummary = false;
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
  }

  private focusRefusal(): void {
    if (this.focusedSummary) return;
    const first = this.store.violations()[0];
    if (first === undefined) return;
    this.focusedSummary = true;
    this.summary()?.nativeElement.focus();
    this.focusField(first.field);
  }

  private fieldView(field: string): FieldView {
    this.generation();
    const id = this.controlId(field);
    const reason = this.store.violationFor(field);
    const invalid = reason !== '';
    const described: string[] = [];
    if (field === PASSWORD_FIELD && this.store.saved()) described.push(`${id}-caption`);
    if (invalid) described.push(`${id}-reason`);
    return {
      id,
      reason,
      invalid,
      describedBy: described.length === 0 ? null : described.join(' '),
    };
  }

  private controlId(field: string): string {
    return `ocu-user-${field}`;
  }

  /** The new account's own URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private editorUrl(id: string): string {
    const editor = this.navigation.screenForUrl(this.router.url);
    const route = editor === null ? FORM_ROUTE : editor.route;
    return withQuery(`${route}/${encodeEntityId(id)}`, this.router.url);
  }
}
