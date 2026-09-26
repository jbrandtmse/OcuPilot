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
import { NavigationEnd, Router } from '@angular/router';

import { ChangeBus } from '../../core/change-bus';
import { tabErrorCounts, tabToOpen } from '../../core/form-tabs';
import { FormDirty } from '../../core/form-dirty';
import { formatRequires, ownIdSegment, screenForDescriptor, withQuery } from '../../core/navigation';
import { savedLine } from '../../core/read-back';
import { selfProtectionReason } from '../../core/self-protection';
import { Session } from '../../core/session';
import { STRINGS } from '../../core/strings';
import { STATE_CONFLICT_CODE, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { FormTabBody, FormTabs, type FormTabView } from '../../shell/form-tabs';
import { ScreenActionDialogs } from '../../shell/screen-action-dialogs';
import { ADD_ROLE, type ActionSink, REMOVE_ROLE, SET_PASSWORD, ScreenActionHandler } from '../../shell/screen-action-handler';
import {
  AUTHE_FIELD,
  GENERAL_FIELDS,
  GENERAL_TAB,
  ROLES_FIELD,
  ROLES_TAB,
  USER_ENTITY,
  USER_FIELD_TABS,
  UserEditor,
} from './user-editor.store';

/** The list the editor is reached from, which Cancel and a delete return to. */
export const USER_LIST_ROUTE = 'permissions/users';

/** The Users list's descriptor, whose declared actions the editor runs (AD-53, DW-1501). */
export const USER_LIST = 'OcuPilot.Screen.Descriptor.UserList';

/** The User form's descriptor, whose id route this editor is. */
export const USER_FORM = 'OcuPilot.Screen.Descriptor.UserForm';

/** The Users list's destructive action. */
const DELETE_ACTION = 'delete';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** One field, resolved for drawing: its control id, its refusal and its described-by wiring. */
interface FieldView {
  readonly id: string;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/** One header action: whether it is drawn refused, and why. */
interface ActionView {
  readonly reason: string;
  readonly reasonId: string;
  readonly disabled: string | null;
  readonly describedBy: string | null;
}

/**
 * The user editor, the `form-page` at `permissions/users/edit/<id>` (Story 9.1, FR-35, AD-55), and
 * the pattern Epic 9's other editors follow for tabs, validation, the error summary and the
 * unsaved-changes guard.
 *
 * **Its tabs are the classic editor's first two** (`%CSP.UI.Portal.User`): General, with every
 * account setting in the classic order, and Roles. One form spans both, and Save sends the fields
 * changed since the account's read; a refused Save opens the tab that holds its first refused
 * field, whose accessible name then counts them (`shell/form-tabs.ts`), and focuses the error
 * summary, then that field.
 *
 * **Its actions are the Users list's own** (AD-53, DW-1501): Set password, Delete, and Add and
 * Remove role, started through `ScreenActionHandler.startFor` and confirmed in the same dialogs
 * (`app-screen-action-dialogs`). An action or a field a self-protection rule explains is drawn
 * refused with that rule's sentence (AD-10); the instance refuses it either way.
 *
 * **A change event re-reads the account** (AD-14): in place while the form is clean, the roles
 * alone while it holds unsaved work. The unsaved-changes guard is the `form-page` route guard,
 * answered here. Every control-flow condition is a paren-free member reference, for the reason
 * `sign-in.ts` records.
 */
@Component({
  selector: 'app-user-editor-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, FormTabs, FormTabBody, ScreenActionDialogs],
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
    @if (hasActionRefusal) {
      <p class="ocu-banner ocu-banner-warning" role="alert">{{ actionRefusal }}</p>
    }

    @if (loadedFlag) {
    @if (present) {
    <div class="ocu-form-actions">
      <button
        type="button"
        class="ocu-button-text"
        data-action="set-password"
        [attr.aria-disabled]="setPasswordAction.disabled"
        [attr.aria-describedby]="setPasswordAction.describedBy"
        (click)="onSetPassword()"
      >
        {{ STRINGS.userActionSetPassword }}
      </button>
      <button
        type="button"
        class="ocu-button-text"
        data-action="delete"
        [attr.aria-disabled]="deleteAction.disabled"
        [attr.aria-describedby]="deleteAction.describedBy"
        (click)="onDelete()"
      >
        {{ STRINGS.actionDelete }}
      </button>
      @if (setPasswordAction.reason) {
        <p class="ocu-form-action-reason" [id]="setPasswordAction.reasonId">{{ setPasswordAction.reason }}</p>
      }
      @if (deleteAction.reason) {
        <p class="ocu-form-action-reason" [id]="deleteAction.reasonId">{{ deleteAction.reason }}</p>
      }
    </div>

    <app-form-tabs [tabs]="tabs" [selected]="selectedTab()" (selectedChange)="selectTab($event)">
      <ng-template ocuFormTab="general">
        <div class="ocu-form-fields">
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="nameId">{{ STRINGS.tableColumnName }}</label>
            <input class="ocu-field-input" type="text" readonly [id]="nameId" [value]="accountName" />
          </div>
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="fullNameField.id">{{ STRINGS.userColumnFullName }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                type="text"
                [id]="fullNameField.id"
                [value]="text('FullName')"
                [readOnly]="locked"
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
            <label class="ocu-field-label" [attr.for]="commentField.id">{{ STRINGS.userFieldComment }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                type="text"
                [id]="commentField.id"
                [value]="text('Comment')"
                [readOnly]="locked"
                [attr.maxlength]="maxLength('Comment')"
                [attr.aria-invalid]="commentField.invalid"
                [attr.aria-describedby]="commentField.describedBy"
                (input)="onText('Comment', $event)"
                (blur)="onBlur('Comment')"
              />
            </div>
            @if (commentField.invalid) {
              <p class="ocu-form-error" [id]="commentField.id + '-reason'">{{ commentField.reason }}</p>
            }
          </div>
          <div class="ocu-field">
            <label class="ocu-field-checkbox">
              <input
                type="checkbox"
                [id]="changePasswordField.id"
                [checked]="flag('ChangePassword')"
                [disabled]="changePasswordLocked"
                [attr.aria-invalid]="changePasswordField.invalid"
                [attr.aria-describedby]="changePasswordDescribedBy"
                (change)="onFlag('ChangePassword', $event)"
              />
              <span>{{ STRINGS.userPasswordChangeOnLogin }}</span>
            </label>
            @if (changePasswordRefusal) {
              <p class="ocu-field-caption" [id]="changePasswordField.id + '-refusal'">{{ changePasswordRefusal }}</p>
            }
            @if (changePasswordField.invalid) {
              <p class="ocu-form-error" [id]="changePasswordField.id + '-reason'">{{ changePasswordField.reason }}</p>
            }
          </div>
          <div class="ocu-field">
            <label class="ocu-field-checkbox">
              <input
                type="checkbox"
                [id]="passwordNeverExpiresField.id"
                [checked]="flag('PasswordNeverExpires')"
                [disabled]="locked"
                [attr.aria-invalid]="passwordNeverExpiresField.invalid"
                [attr.aria-describedby]="passwordNeverExpiresField.describedBy"
                (change)="onFlag('PasswordNeverExpires', $event)"
              />
              <span>{{ STRINGS.userFieldPasswordNeverExpires }}</span>
            </label>
            @if (passwordNeverExpiresField.invalid) {
              <p class="ocu-form-error" [id]="passwordNeverExpiresField.id + '-reason'">{{ passwordNeverExpiresField.reason }}</p>
            }
          </div>
          <div class="ocu-field">
            <label class="ocu-field-checkbox">
              <input
                type="checkbox"
                [id]="enabledField.id"
                [checked]="flag('Enabled')"
                [disabled]="enabledLocked"
                [attr.aria-invalid]="enabledField.invalid"
                [attr.aria-describedby]="enabledDescribedBy"
                (change)="onFlag('Enabled', $event)"
              />
              <span>{{ STRINGS.tableColumnEnabled }}</span>
            </label>
            @if (enabledRefusal) {
              <p class="ocu-field-caption" [id]="enabledField.id + '-refusal'">{{ enabledRefusal }}</p>
            }
            @if (enabledField.invalid) {
              <p class="ocu-form-error" [id]="enabledField.id + '-reason'">{{ enabledField.reason }}</p>
            }
          </div>
          <div class="ocu-field">
            <label class="ocu-field-checkbox">
              <input
                type="checkbox"
                [id]="accountNeverExpiresField.id"
                [checked]="flag('AccountNeverExpires')"
                [disabled]="locked"
                [attr.aria-invalid]="accountNeverExpiresField.invalid"
                [attr.aria-describedby]="accountNeverExpiresField.describedBy"
                (change)="onFlag('AccountNeverExpires', $event)"
              />
              <span>{{ STRINGS.userFieldAccountNeverExpires }}</span>
            </label>
            @if (accountNeverExpiresField.invalid) {
              <p class="ocu-form-error" [id]="accountNeverExpiresField.id + '-reason'">{{ accountNeverExpiresField.reason }}</p>
            }
          </div>
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="expiryField.id">{{ STRINGS.userFormExpiry }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                type="date"
                [id]="expiryField.id"
                [value]="text('ExpirationDate')"
                [readOnly]="locked"
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
                [value]="text('NameSpace')"
                [readOnly]="locked"
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
                [value]="text('Routine')"
                [readOnly]="locked"
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
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="emailField.id">{{ STRINGS.userFieldEmail }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                type="email"
                [id]="emailField.id"
                [value]="text('EmailAddress')"
                [readOnly]="locked"
                [attr.maxlength]="maxLength('EmailAddress')"
                [attr.aria-invalid]="emailField.invalid"
                [attr.aria-describedby]="emailField.describedBy"
                (input)="onText('EmailAddress', $event)"
                (blur)="onBlur('EmailAddress')"
              />
            </div>
            @if (emailField.invalid) {
              <p class="ocu-form-error" [id]="emailField.id + '-reason'">{{ emailField.reason }}</p>
            }
          </div>
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="providerField.id">{{ STRINGS.userFieldPhoneProvider }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                type="text"
                [id]="providerField.id"
                [value]="text('PhoneProvider')"
                [readOnly]="locked"
                [attr.maxlength]="maxLength('PhoneProvider')"
                [attr.aria-invalid]="providerField.invalid"
                [attr.aria-describedby]="providerField.describedBy"
                (input)="onText('PhoneProvider', $event)"
                (blur)="onBlur('PhoneProvider')"
              />
            </div>
            @if (providerField.invalid) {
              <p class="ocu-form-error" [id]="providerField.id + '-reason'">{{ providerField.reason }}</p>
            }
          </div>
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="phoneField.id">{{ STRINGS.userFieldPhoneNumber }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                type="tel"
                [id]="phoneField.id"
                [value]="text('PhoneNumber')"
                [readOnly]="locked"
                [attr.maxlength]="maxLength('PhoneNumber')"
                [attr.aria-invalid]="phoneField.invalid"
                [attr.aria-describedby]="phoneField.describedBy"
                (input)="onText('PhoneNumber', $event)"
                (blur)="onBlur('PhoneNumber')"
              />
            </div>
            @if (phoneField.invalid) {
              <p class="ocu-form-error" [id]="phoneField.id + '-reason'">{{ phoneField.reason }}</p>
            }
          </div>
          <fieldset class="ocu-field ocu-form-authe" [attr.id]="twoFactorField.id" tabindex="-1" [attr.aria-describedby]="twoFactorField.describedBy">
            <legend class="ocu-field-label">{{ STRINGS.userFieldTwoFactor }}</legend>
            <label class="ocu-field-checkbox">
              <input
                type="checkbox"
                [id]="twoFactorField.id + '-sms'"
                [checked]="sms"
                [disabled]="locked"
                (change)="onSms($event)"
              />
              <span>{{ STRINGS.userFieldTwoFactorSms }}</span>
            </label>
            <label class="ocu-field-checkbox">
              <input
                type="checkbox"
                [id]="twoFactorField.id + '-totp'"
                [checked]="totp"
                [disabled]="locked"
                (change)="onTotp($event)"
              />
              <span>{{ STRINGS.userFieldTwoFactorTotp }}</span>
            </label>
            @if (totp) {
              <label class="ocu-field-checkbox">
                <input
                  type="checkbox"
                  [id]="qrField.id"
                  [checked]="flag('HOTPKeyDisplay')"
                  [disabled]="locked"
                  [attr.aria-invalid]="qrField.invalid"
                  [attr.aria-describedby]="qrField.describedBy"
                  (change)="onFlag('HOTPKeyDisplay', $event)"
                />
                <span>{{ STRINGS.userFieldShowQrCode }}</span>
              </label>
            }
            @if (twoFactorField.invalid) {
              <p class="ocu-form-error" [id]="twoFactorField.id + '-reason'">{{ twoFactorField.reason }}</p>
            }
          </fieldset>
        </div>
      </ng-template>
      <ng-template ocuFormTab="roles">
        @if (hasRoles) {
          <ul class="ocu-form-roles" [attr.aria-label]="STRINGS.userColumnRoles">
            @for (role of heldRoles; track role) {
              <li class="ocu-form-role">
                <span class="ocu-form-role-name">{{ role }}</span>
                <button type="button" class="ocu-button-text" [attr.aria-label]="removeLabel(role)" (click)="onRemoveRole(role)">
                  {{ STRINGS.userActionRemoveRole }}
                </button>
              </li>
            }
          </ul>
        } @else {
          <p class="ocu-form-legend">{{ STRINGS.userRolesEmpty }}</p>
        }
        <button type="button" class="ocu-button-text" data-action="add-role" (click)="onAddRole()">
          {{ STRINGS.userActionAddRole }}
        </button>
      </ng-template>
    </app-form-tabs>

    <div class="ocu-form-bar">
      <div class="ocu-form-bar-status">
        @if (showSaved) {
          <span role="status">{{ savedText }}</span>
        }
      </div>
      <div class="ocu-form-bar-actions">
        <button type="button" class="ocu-button-text" (click)="cancel()">{{ STRINGS.actionCancel }}</button>
        <button type="button" class="ocu-button-primary" [attr.aria-disabled]="saveBlocked" (click)="onSave()">
          {{ STRINGS.actionSave }}
        </button>
      </div>
    </div>
    }
    }

    <app-screen-action-dialogs [descriptor]="userList" />

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
export class UserEditorPage {
  private readonly store = inject(UserEditor);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly injector = inject(Injector);
  private readonly actions = inject(ScreenActionHandler);
  private readonly session = inject(Session, { optional: true });

  protected readonly STRINGS = STRINGS;

  protected readonly userList = USER_LIST;

  protected readonly nameId = 'ocu-user-edit-Name';

  /** The key of the tab on screen. */
  protected readonly selectedTab = signal(GENERAL_TAB);

  /** Bumped by both stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  /** Whether the summary has been focused for the refusal now on screen. */
  private focusedSummary = false;

  /** Where the Users list's actions report, when this editor starts them (AD-53). */
  private readonly sink: ActionSink = {
    setRefusal: (reason) => this.store.setActionRefusal(reason),
    applied: (actionId) => this.onApplied(actionId),
  };

  constructor() {
    const stopStore = this.store.subscribe(() => this.bump());
    const stopDirty = this.formDirty.subscribe(() => this.bump());
    let followed = this.routeId();
    void this.store.open(followed);
    // One id route to another reuses this page, so the editor follows the id, not the page's life.
    const stopIdChange = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      const id = this.routeId();
      if (id === followed || id === '') return;
      followed = id;
      this.selectedTab.set(GENERAL_TAB);
      void this.store.open(id);
    });
    // AD-14: a change to this account, from either caller, re-reads it; a delete is the list's.
    const stopChanges = this.injector.get(ChangeBus).subscribe((event) => {
      if (event.kind !== 'changed' || event.type !== USER_ENTITY || event.action === 'deleted') return;
      if (this.store.is(event.id)) void this.store.refresh();
    });
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      stopIdChange.unsubscribe();
      stopChanges();
      if (this.actions.pending()?.descriptor === USER_LIST) this.actions.cancelPending();
      this.store.reset();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get loadedFlag(): boolean {
    this.generation();
    return this.store.loaded();
  }

  protected get present(): boolean {
    this.generation();
    return !this.store.absent();
  }

  protected get locked(): boolean {
    this.generation();
    return !this.store.editable();
  }

  protected get accountName(): string {
    this.generation();
    return this.store.name();
  }

  protected get tabs(): readonly FormTabView[] {
    this.generation();
    const counts = tabErrorCounts(USER_FIELD_TABS, this.store.violations());
    return [
      { key: GENERAL_TAB, label: STRINGS.processDetailsGroupGeneral, count: counts[GENERAL_TAB] ?? 0 },
      { key: ROLES_TAB, label: STRINGS.userColumnRoles, count: counts[ROLES_TAB] ?? 0 },
    ];
  }

  protected get violations(): readonly Violation[] {
    this.generation();
    return this.store.violations();
  }

  protected get hasSummary(): boolean {
    return this.violations.length > 0;
  }

  /**
   * What an envelope-level refusal reads (AD-8, AD-39): a privilege denial names the pair the
   * envelope named, a stale save reads the published sentence, and anything else the envelope's own
   * reason.
   */
  protected get reason(): string {
    this.generation();
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') return formatRequires(STRINGS.privilegeRequiresResource, pair);
    if (this.store.refusalCode() === STATE_CONFLICT_CODE) return STRINGS.formStaleSave;
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get actionRefusal(): string {
    this.generation();
    return this.store.actionRefusal();
  }

  protected get hasActionRefusal(): boolean {
    return this.actionRefusal !== '';
  }

  protected get setPasswordAction(): ActionView {
    return this.actionView(SET_PASSWORD);
  }

  protected get deleteAction(): ActionView {
    return this.actionView(DELETE_ACTION);
  }

  /**
   * The protected-account sentence the Enabled field is drawn refused with while the account reads
   * enabled, or `''` (AD-10): turning a protected account off is refused, turning it on never is.
   */
  protected get enabledRefusal(): string {
    this.generation();
    if (!this.store.storedFlag('Enabled')) return '';
    return this.ruleReason(DELETE_ACTION);
  }

  protected get enabledLocked(): boolean {
    return this.locked || this.enabledRefusal !== '';
  }

  protected get enabledDescribedBy(): string | null {
    return this.describedBy(this.enabledField, this.enabledRefusal !== '' ? `${this.enabledField.id}-refusal` : '');
  }

  /**
   * The sign-in sentence the change-on-login field is drawn refused with while the account reads it
   * off, or `''` (DW-1520): turning it on for a service account is refused, turning it off never is.
   */
  protected get changePasswordRefusal(): string {
    this.generation();
    if (this.store.storedFlag('ChangePassword')) return '';
    return this.ruleReason(SET_PASSWORD);
  }

  protected get changePasswordLocked(): boolean {
    return this.locked || this.changePasswordRefusal !== '';
  }

  protected get changePasswordDescribedBy(): string | null {
    return this.describedBy(this.changePasswordField, this.changePasswordRefusal !== '' ? `${this.changePasswordField.id}-refusal` : '');
  }

  protected get sms(): boolean {
    this.generation();
    return this.store.sms();
  }

  protected get totp(): boolean {
    this.generation();
    return this.store.totp();
  }

  protected get heldRoles(): readonly string[] {
    this.generation();
    return this.store.roles();
  }

  protected get hasRoles(): boolean {
    return this.heldRoles.length > 0;
  }

  protected get saveBlocked(): string | null {
    this.generation();
    return this.store.canSave() ? null : 'true';
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

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  protected text(field: string): string {
    this.generation();
    return this.store.text(field);
  }

  protected flag(field: string): boolean {
    this.generation();
    return this.store.flag(field);
  }

  /** The length the instance stores for `field`, or `null` where it declares none. */
  protected maxLength(field: string): number | null {
    this.generation();
    const bound = this.store.maxLength(field);
    return bound > 0 ? bound : null;
  }

  protected removeLabel(role: string): string {
    return `${STRINGS.userActionRemoveRole} ${role}`;
  }

  protected get fullNameField(): FieldView {
    return this.fieldView('FullName');
  }

  protected get commentField(): FieldView {
    return this.fieldView('Comment');
  }

  protected get changePasswordField(): FieldView {
    return this.fieldView('ChangePassword');
  }

  protected get passwordNeverExpiresField(): FieldView {
    return this.fieldView('PasswordNeverExpires');
  }

  protected get enabledField(): FieldView {
    return this.fieldView('Enabled');
  }

  protected get accountNeverExpiresField(): FieldView {
    return this.fieldView('AccountNeverExpires');
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

  protected get emailField(): FieldView {
    return this.fieldView('EmailAddress');
  }

  protected get providerField(): FieldView {
    return this.fieldView('PhoneProvider');
  }

  protected get phoneField(): FieldView {
    return this.fieldView('PhoneNumber');
  }

  protected get twoFactorField(): FieldView {
    return this.fieldView(AUTHE_FIELD);
  }

  protected get qrField(): FieldView {
    return this.fieldView('HOTPKeyDisplay');
  }

  // --- intents ---------------------------------------------------------------------------------

  protected selectTab(key: string): void {
    this.selectedTab.set(key);
  }

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setText(field, target.value);
  }

  protected onFlag(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setFlag(field, target.checked);
  }

  protected onSms(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setSms(target.checked);
  }

  protected onTotp(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setTotp(target.checked);
  }

  protected onBlur(field: string): void {
    this.store.onBlur(field);
  }

  protected onSetPassword(): void {
    this.start(SET_PASSWORD);
  }

  protected onDelete(): void {
    this.start(DELETE_ACTION);
  }

  protected onAddRole(): void {
    this.start(ADD_ROLE);
  }

  protected onRemoveRole(role: string): void {
    this.start(REMOVE_ROLE, role);
  }

  protected async onSave(): Promise<void> {
    if (!this.store.canSave()) return;
    const saved = await this.store.save();
    if (!saved) this.afterRefusal();
  }

  /** Open the tab that holds `field`, then focus it. */
  protected focusField(field: string): void {
    const tab = USER_FIELD_TABS[field];
    if (tab !== undefined && tab !== this.selectedTab()) {
      this.selectedTab.set(tab);
      afterNextRender(() => this.focusControl(field), { injector: this.injector });
      return;
    }
    this.focusControl(field);
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(USER_LIST_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  /** The account this route names, or `''`. */
  private routeId(): string {
    const screen = screenForDescriptor(USER_FORM);
    return screen === null ? '' : ownIdSegment(screen, this.router.url);
  }

  /** Start one of the Users list's actions on this account (AD-53, DW-1501). */
  private start(actionId: string, role = ''): void {
    if (!this.store.editable()) return;
    this.store.setActionRefusal('');
    this.actions.startFor(USER_LIST, actionId, this.store.name(), { Name: this.store.name(), Roles: this.store.roles() }, this.sink, role);
  }

  /** An action was applied: a delete returns to the list, and anything else re-reads the account. */
  private onApplied(actionId: string): void {
    if (actionId === DELETE_ACTION) {
      this.store.abandon();
      void this.router.navigateByUrl(withQuery(USER_LIST_ROUTE, this.router.url));
      return;
    }
    void this.store.refresh();
  }

  /** The sentence the Users list's declared rule for `actionId` explains this account with, or `''`. */
  private ruleReason(actionId: string): string {
    this.generation();
    const rule = screenForDescriptor(USER_LIST)?.rowActions.find((action) => action.id === actionId)?.selfProtection ?? '';
    return selfProtectionReason(rule, this.store.name(), this.session?.userName() ?? '');
  }

  private actionView(actionId: string): ActionView {
    const reason = this.ruleReason(actionId);
    const reasonId = `ocu-user-edit-action-${actionId}-reason`;
    return {
      reason,
      reasonId,
      disabled: reason !== '' || this.locked ? 'true' : null,
      describedBy: reason !== '' ? reasonId : null,
    };
  }

  /**
   * After a refused Save: the tab that holds the first refused field opens, the error summary takes
   * focus, then that field, in the order EXPERIENCE.md's `form-page` validation rule states.
   */
  private afterRefusal(): void {
    const open = tabToOpen(USER_FIELD_TABS, [...GENERAL_FIELDS, ROLES_FIELD], this.store.violations());
    if (open !== null) this.selectedTab.set(open);
    if (this.store.violations()[0] === undefined) return;
    this.focusedSummary = false;
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
  }

  private focusRefusal(): void {
    if (this.focusedSummary) return;
    const violations = this.store.violations();
    if (violations[0] === undefined) return;
    this.focusedSummary = true;
    this.summary()?.nativeElement.focus();
    const order = [...GENERAL_FIELDS, ROLES_FIELD];
    const rank = (field: string): number => (order.includes(field) ? order.indexOf(field) : order.length);
    const first = violations.reduce((best, entry) => (rank(entry.field) < rank(best.field) ? entry : best));
    this.focusControl(first.field);
  }

  private focusControl(field: string): void {
    document.getElementById(this.controlId(field))?.focus();
  }

  private fieldView(field: string): FieldView {
    this.generation();
    const id = this.controlId(field);
    const reason = this.store.violationFor(field);
    const invalid = reason !== '';
    return { id, reason, invalid, describedBy: invalid ? `${id}-reason` : null };
  }

  private describedBy(view: FieldView, extra: string): string | null {
    const ids = [extra, view.describedBy ?? ''].filter((id) => id !== '');
    return ids.length === 0 ? null : ids.join(' ');
  }

  private controlId(field: string): string {
    return `ocu-user-edit-${field}`;
  }
}
