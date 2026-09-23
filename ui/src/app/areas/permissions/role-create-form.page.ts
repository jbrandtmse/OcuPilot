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
import {
  GRANTED_ROLES_FIELD,
  RESOURCES_FIELD,
  RoleCreateForm,
  type Grant,
  type ResourceOption,
  type RoleOption,
} from './role-create-form.store';
import { RoleGrantDialog, type GrantResult, grantLine } from './role-grant-dialog';

/** The list this form is reached from, which Cancel and the leave confirmation return to. */
const LIST_ROUTE = 'permissions/roles';

/** This form's own route, the fallback when the mirror cannot resolve it from the URL. */
const FORM_ROUTE = 'permissions/roles/edit';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** One field, resolved for drawing: its control id, its refusal and its described-by wiring. */
interface FieldView {
  readonly id: string;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/** Which grant dialog is open: adding one, or editing or removing the grant held for a resource. */
interface GrantDialogState {
  readonly editing: Grant | null;
  readonly clearing: boolean;
}

/** One held grant, resolved for drawing. */
interface GrantRow {
  readonly grant: Grant;
  readonly line: string;
}

/**
 * The create-a-role form, a `form-page` over a role on the instance (AD-55, FR-39).
 *
 * **Field order is the acceptance criterion's, and the classic editor's**: name, description, the
 * resource grants, then the granted roles, which `%CSP.UI.Portal.Role` assigns on a tab after the
 * save.
 *
 * **Each resource grant is added, edited and removed in its dialog** (`RoleGrantDialog`), which
 * shows the current and the resulting grant before Confirm applies it to the store. The dialog is
 * closed before the leave question renders, because dialogs never stack.
 *
 * **A granted role the server refuses is drawn disabled, described by the server's own sentence**
 * from the bootstrap read. The refusal itself is the server's, on the field it concerns, on either
 * caller (AD-10, AD-39).
 *
 * It composes no payload and authors no field sentence; the unsaved-changes guard is the
 * `form-page` route guard, answered here. Every control-flow condition is a paren-free member
 * reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-role-create-form-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, RoleGrantDialog],
  template: `<section class="ocu-form-page">
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
        <label class="ocu-field-label" [attr.for]="descriptionField.id">{{ STRINGS.tableColumnDescription }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            [id]="descriptionField.id"
            [value]="value('Description')"
            [attr.maxlength]="maxLength('Description')"
            [attr.aria-invalid]="descriptionField.invalid"
            [attr.aria-describedby]="descriptionField.describedBy"
            (input)="onText('Description', $event)"
            (blur)="onBlur('Description')"
          />
        </div>
        @if (descriptionField.invalid) {
          <p class="ocu-form-error" [id]="descriptionField.id + '-reason'">{{ descriptionField.reason }}</p>
        }
      </div>

      <fieldset
        class="ocu-field ocu-form-authe"
        [attr.id]="resourcesField.id"
        tabindex="-1"
        [attr.aria-describedby]="resourcesField.describedBy"
      >
        <legend class="ocu-field-label">{{ STRINGS.resourceListLabel }}</legend>
        <ul class="ocu-role-grants">
          @for (row of grantRows; track row.grant.name) {
            <li class="ocu-role-grant">
              <span class="ocu-role-grant-line">{{ row.line }}</span>
              <button type="button" class="ocu-button-text" (click)="openEdit(row.grant)">{{ STRINGS.agentPanelSecretWarningEdit }}</button>
              <button type="button" class="ocu-button-text" (click)="openRemove(row.grant)">{{ STRINGS.actionRemove }}</button>
            </li>
          }
        </ul>
        <div>
          <button type="button" class="ocu-button-secondary" id="ocu-role-grant-add" (click)="openAdd()">{{ STRINGS.roleGrantAdd }}</button>
        </div>
        @if (resourcesField.invalid) {
          <p class="ocu-form-error" [id]="resourcesField.id + '-reason'">{{ resourcesField.reason }}</p>
        }
      </fieldset>

      <fieldset
        class="ocu-field ocu-form-authe"
        [attr.id]="grantedRolesField.id"
        tabindex="-1"
        [attr.aria-describedby]="grantedRolesField.describedBy"
      >
        <legend class="ocu-field-label">{{ STRINGS.roleFormGrantedRoles }}</legend>
        @for (role of roleOptions; track role.name) {
          <label class="ocu-field-checkbox">
            <input
              type="checkbox"
              [id]="roleId(role.name)"
              [checked]="roleChecked(role.name)"
              [disabled]="role.privileged"
              [attr.aria-describedby]="role.privileged ? privilegeReasonId : null"
              (change)="onRole(role.name, $event)"
            />
            <span>{{ role.name }}</span>
          </label>
        }
        @if (hasPrivilegedRole) {
          <p class="ocu-field-caption" [id]="privilegeReasonId">{{ privilegeReason }}</p>
        }
        @if (grantedRolesField.invalid) {
          <p class="ocu-form-error" [id]="grantedRolesField.id + '-reason'">{{ grantedRolesField.reason }}</p>
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

    @if (grantDialogOpen) {
      <app-role-grant-dialog
        [resources]="resourceOptions"
        [granted]="heldGrants"
        [editing]="dialogEditing"
        [clearing]="dialogClearing"
        [privilegeReason]="privilegeReason"
        (applied)="applyGrant($event)"
        (closed)="closeGrantDialog()"
      />
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
export class RoleCreateFormPage {
  private readonly store = inject(RoleCreateForm);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  /** Bumped by both stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  /** The grant dialog, when one is open. Local to this page and never stored. */
  private readonly grantDialog = signal<GrantDialogState | null>(null);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  /** Whether the summary has been focused for the refusal now on screen. */
  private focusedSummary = false;

  constructor() {
    const stopStore = this.store.subscribe(() => this.generation.update((value) => value + 1));
    const stopDirty = this.formDirty.subscribe(() => {
      // Dialogs never stack: the leave question replaces an open grant dialog.
      if (this.formDirty.pending()) this.grantDialog.set(null);
      this.generation.update((value) => value + 1);
    });
    void this.store.open();
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      // Not torn down while the store is carried across the create's own route replacement,
      // which destroys this component and builds it again over the same role.
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
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.roleListEmptyAgent);
    }
    if (this.store.refusalCode() === STATE_CONFLICT_CODE) return STRINGS.formStaleSave;
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get grantRows(): readonly GrantRow[] {
    this.generation();
    return this.store.grants().map((grant) => ({ grant, line: grantLine(grant.name, grant.permissions) }));
  }

  protected get heldGrants(): readonly Grant[] {
    this.generation();
    return this.store.grants();
  }

  protected get resourceOptions(): readonly ResourceOption[] {
    this.generation();
    return this.store.rules().resources;
  }

  protected get roleOptions(): readonly RoleOption[] {
    this.generation();
    return this.store.rules().roles;
  }

  protected get hasPrivilegedRole(): boolean {
    return this.privilegeReason !== '' && this.roleOptions.some((role) => role.privileged);
  }

  /** The server's sentence for a grant it refuses, which each refused choice is described by. */
  protected get privilegeReason(): string {
    this.generation();
    return this.store.rules().privilegeReason;
  }

  protected get privilegeReasonId(): string {
    return `${this.controlId(GRANTED_ROLES_FIELD)}-privileged`;
  }

  protected get grantDialogOpen(): boolean {
    this.generation();
    return this.grantDialog() !== null && !this.formDirty.pending();
  }

  protected get dialogEditing(): Grant | null {
    return this.grantDialog()?.editing ?? null;
  }

  protected get dialogClearing(): boolean {
    return this.grantDialog()?.clearing ?? false;
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
    return `${this.controlId(GRANTED_ROLES_FIELD)}-${name}`;
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

  protected get descriptionField(): FieldView {
    return this.fieldView('Description');
  }

  protected get resourcesField(): FieldView {
    return this.fieldView(RESOURCES_FIELD);
  }

  protected get grantedRolesField(): FieldView {
    return this.fieldView(GRANTED_ROLES_FIELD);
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setValue(field, target.value);
  }

  protected onRole(name: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setRole(name, target.checked);
  }

  protected onBlur(field: string): void {
    void this.store.onBlur(field);
  }

  protected openAdd(): void {
    this.grantDialog.set({ editing: null, clearing: false });
  }

  protected openEdit(grant: Grant): void {
    this.grantDialog.set({ editing: grant, clearing: false });
  }

  protected openRemove(grant: Grant): void {
    this.grantDialog.set({ editing: grant, clearing: true });
  }

  protected applyGrant(result: GrantResult): void {
    this.grantDialog.set(null);
    this.store.applyGrant(result.name, result.permissions);
  }

  protected closeGrantDialog(): void {
    this.grantDialog.set(null);
  }

  protected async onSave(): Promise<void> {
    if (this.store.busy()) return;
    const saved = await this.store.save();
    if (!saved) {
      this.afterRefusal();
      return;
    }
    // A create replaces the route with the new role's URL, so the address bar names the entity
    // and Back goes to the list. The buffer on screen is carried across that one navigation;
    // nothing here reads the `:id`.
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
    return {
      id,
      reason,
      invalid,
      describedBy: invalid ? `${id}-reason` : null,
    };
  }

  private controlId(field: string): string {
    return `ocu-role-${field}`;
  }

  /** The new role's own URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private editorUrl(id: string): string {
    const editor = this.navigation.screenForUrl(this.router.url);
    const route = editor === null ? FORM_ROUTE : editor.route;
    return withQuery(`${route}/${encodeEntityId(id)}`, this.router.url);
  }
}
