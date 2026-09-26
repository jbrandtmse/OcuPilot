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
import {
  ADD_GRANTED_ROLE,
  ADD_ROLE,
  REMOVE_GRANTED_ROLE,
  REMOVE_RESOURCE_GRANT,
  REMOVE_ROLE,
  ROLE_LIST,
  SET_RESOURCE_GRANT,
  type ActionSink,
  type ActionValues,
  ScreenActionHandler,
} from '../../shell/screen-action-handler';
import { GRANTED_ROLES_FIELD, RESOURCES_FIELD, ROLE_ENTITY, type Grant, type ResourceOption, type RoleOption } from './role-create-form.store';
import {
  ASSIGNED_TO_TAB,
  DESCRIPTION_FIELD,
  ESCALATION_FIELD,
  GENERAL_FIELDS,
  GENERAL_TAB,
  MEMBERS_TAB,
  MEMBER_TYPE_ESCALATION,
  MEMBER_TYPE_ROLE,
  MEMBER_TYPE_USER,
  type Member,
  ROLE_FIELD_TABS,
  RoleEditor,
} from './role-editor.store';
import { RoleGrantDialog, type GrantResult, grantLine } from './role-grant-dialog';

/** The list the editor is reached from, which Cancel and a delete return to. */
export const ROLE_LIST_ROUTE = 'permissions/roles';

/** The Role form's descriptor, whose id route this editor is. */
export const ROLE_FORM = 'OcuPilot.Screen.Descriptor.RoleForm';

/** The Users list's descriptor, whose role actions assign and remove an account member (AD-53). */
export const USER_LIST = 'OcuPilot.Screen.Descriptor.UserList';

/** The Roles list's destructive action. */
const DELETE_ACTION = 'delete';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** Which grant dialog is open: adding one, or editing or removing the grant held for a resource. */
interface GrantDialogState {
  readonly editing: Grant | null;
  readonly clearing: boolean;
}

/** One field, resolved for drawing: its control id, its refusal and its described-by wiring. */
interface FieldView {
  readonly id: string;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/** One member row, resolved for drawing. */
/** A member row's key: its type and name, so a Remove acts on the member drawn even after a re-read. */
function memberKey(member: Member): string {
  return `${member.type}\n${member.name}`;
}

interface MemberView {
  readonly key: string;
  readonly name: string;
  readonly type: string;
  /** Whether the row carries Remove: an account or role member, never an escalation holder. */
  readonly removable: boolean;
  readonly removeLabel: string;
}

/** The published word for a holder-list type. */
function memberTypeWord(type: string): string {
  if (type === MEMBER_TYPE_USER) return STRINGS.roleMemberTypeUser;
  if (type === MEMBER_TYPE_ROLE) return STRINGS.userRoleField;
  if (type === MEMBER_TYPE_ESCALATION) return STRINGS.roleMemberTypeEscalation;
  return type;
}

/**
 * The role editor, the `form-page` at `permissions/roles/edit/<id>` (Story 9.3, FR-39, AD-55),
 * following the user editor's pattern for tabs, validation, the error summary and the
 * unsaved-changes guard.
 *
 * **Its tabs are the classic editor's** (`%CSP.UI.Portal.Role`): General -- the description, the
 * escalation-only flag and the resource grants -- Members and Assigned to. Save sends the
 * description and the flag where they changed since the read; a refused Save opens the tab that
 * holds its first refused field and focuses the error summary, then that field.
 *
 * **Everything else is an action on the instance** (AD-53, AD-56 (ii)), started through
 * `ScreenActionHandler.startFor` and applied as a delta there: a grant is set or removed through
 * `RoleGrantDialog` and the Roles list's grant actions; an account member is the Users list's
 * `add-role`/`remove-role`; a role member is `add-granted-role`/`remove-granted-role` on the member;
 * an assigned role is the same pair on this role. Delete is the Roles list's own, typed-name
 * confirmed with the number of accounts that hold the role. A self-protection rule's sentence is
 * drawn before a click; the instance refuses either way.
 *
 * **A role or user change event re-reads the role** (AD-14): in place while the form is clean, the
 * grants and members alone while it holds unsaved work. Every control-flow condition is a paren-free
 * member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-role-editor-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, FormTabs, FormTabBody, RoleGrantDialog, ScreenActionDialogs],
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
        data-action="delete"
        [attr.aria-disabled]="deleteDisabled"
        [attr.aria-describedby]="deleteDescribedBy"
        (click)="onDelete()"
      >
        {{ STRINGS.actionDelete }}
      </button>
      @if (deleteReason) {
        <p class="ocu-form-action-reason" [id]="deleteReasonId">{{ deleteReason }}</p>
      }
    </div>

    <app-form-tabs [tabs]="tabs" [selected]="selectedTab()" (selectedChange)="selectTab($event)">
      <ng-template ocuFormTab="general">
        <div class="ocu-form-fields">
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="nameId">{{ STRINGS.tableColumnName }}</label>
            <input class="ocu-field-input" type="text" readonly [id]="nameId" [value]="roleName" />
          </div>
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="descriptionField.id">{{ STRINGS.tableColumnDescription }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                type="text"
                [id]="descriptionField.id"
                [value]="description"
                [readOnly]="locked"
                [attr.maxlength]="maxLength('Description')"
                [attr.aria-invalid]="descriptionField.invalid"
                [attr.aria-describedby]="descriptionField.describedBy"
                (input)="onDescription($event)"
                (blur)="onBlur('Description')"
              />
            </div>
            @if (descriptionField.invalid) {
              <p class="ocu-form-error" [id]="descriptionField.id + '-reason'">{{ descriptionField.reason }}</p>
            }
          </div>
          <div class="ocu-field">
            <label class="ocu-field-checkbox">
              <input
                type="checkbox"
                [id]="escalationField.id"
                [checked]="escalationOnly"
                [disabled]="locked"
                [attr.aria-invalid]="escalationField.invalid"
                [attr.aria-describedby]="escalationField.describedBy"
                (change)="onEscalation($event)"
              />
              <span>{{ STRINGS.roleColumnEscalationOnly }}</span>
            </label>
            @if (escalationField.invalid) {
              <p class="ocu-form-error" [id]="escalationField.id + '-reason'">{{ escalationField.reason }}</p>
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
                  <button type="button" class="ocu-button-text" [attr.aria-label]="row.editLabel" (click)="openEdit(row.grant)">
                    {{ STRINGS.agentPanelSecretWarningEdit }}
                  </button>
                  <button type="button" class="ocu-button-text" [attr.aria-label]="row.removeLabel" (click)="openRemove(row.grant)">
                    {{ STRINGS.actionRemove }}
                  </button>
                </li>
              }
            </ul>
            <div>
              <button type="button" class="ocu-button-secondary" id="ocu-role-edit-grant-add" (click)="openAdd()">
                {{ STRINGS.roleGrantAdd }}
              </button>
            </div>
            @if (resourcesField.invalid) {
              <p class="ocu-form-error" [id]="resourcesField.id + '-reason'">{{ resourcesField.reason }}</p>
            }
          </fieldset>
        </div>
      </ng-template>
      <ng-template ocuFormTab="members">
        @if (hasMembers) {
          <ul class="ocu-form-roles" [attr.aria-label]="STRINGS.roleEditorTabMembers">
            @for (member of memberRows; track member.key) {
              <li class="ocu-form-role">
                <span class="ocu-form-role-name">{{ member.name }}</span>
                <span class="ocu-role-member-type">{{ member.type }}</span>
                @if (member.removable) {
                  <button type="button" class="ocu-button-text" [attr.aria-label]="member.removeLabel" (click)="onRemoveMember(member.key)">
                    {{ STRINGS.actionRemove }}
                  </button>
                }
              </li>
            }
          </ul>
        } @else {
          <p class="ocu-form-legend">{{ STRINGS.roleMembersEmpty }}</p>
        }
        <div class="ocu-form-fields">
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="memberUserId">{{ STRINGS.processColumnUser }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                type="text"
                autocomplete="off"
                [id]="memberUserId"
                [value]="memberUserPicked"
                [attr.aria-describedby]="memberEffectDescribedBy"
                (input)="onPickMemberUser($event)"
              />
            </div>
          </div>
          <button type="button" class="ocu-button-text" data-action="assign-user" [attr.aria-disabled]="assignUserBlocked" (click)="onAssignUser()">
            {{ STRINGS.webAppRoleAssign }}
          </button>
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="memberRoleId">{{ STRINGS.userRoleField }}</label>
            <div class="ocu-field-control">
              <select
                class="ocu-field-input"
                [id]="memberRoleId"
                [attr.aria-describedby]="memberEffectDescribedBy"
                (change)="onPickMemberRole($event)"
              >
                <option value="" [selected]="memberRolePicked === ''"></option>
                @for (option of memberRoleOptions; track option) {
                  <option [value]="option" [selected]="option === memberRolePicked">{{ option }}</option>
                }
              </select>
            </div>
          </div>
          <button type="button" class="ocu-button-text" data-action="assign-role" [attr.aria-disabled]="assignMemberRoleBlocked" (click)="onAssignMemberRole()">
            {{ STRINGS.webAppRoleAssign }}
          </button>
          @if (privileged) {
            <p class="ocu-field-caption" [id]="memberEffectId">{{ STRINGS.privilegedGrantEffect }}</p>
          }
        </div>
      </ng-template>
      <ng-template ocuFormTab="assigned-to">
        @if (hasGranted) {
          <ul class="ocu-form-roles" [attr.aria-label]="STRINGS.roleEditorTabAssignedTo">
            @for (role of grantedRoles; track role) {
              <li class="ocu-form-role">
                <span class="ocu-form-role-name">{{ role }}</span>
                <button type="button" class="ocu-button-text" [attr.aria-label]="removeLabel(role)" (click)="onRemoveGranted(role)">
                  {{ STRINGS.actionRemove }}
                </button>
              </li>
            }
          </ul>
        } @else {
          <p class="ocu-form-legend">{{ STRINGS.roleAssignedToEmpty }}</p>
        }
        <div class="ocu-form-fields">
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="grantedRoleId">{{ STRINGS.userRoleField }}</label>
            <div class="ocu-field-control">
              <select
                class="ocu-field-input"
                [id]="grantedRoleId"
                [attr.aria-describedby]="grantedEffectDescribedBy"
                (change)="onPickGranted($event)"
              >
                <option value="" [selected]="grantedPicked === ''"></option>
                @for (option of grantedOptions; track option) {
                  <option [value]="option" [selected]="option === grantedPicked">{{ option }}</option>
                }
              </select>
            </div>
            @if (grantedPickPrivileged) {
              <p class="ocu-field-caption" [id]="grantedRoleId + '-effect'">{{ STRINGS.privilegedGrantEffect }}</p>
            }
          </div>
          <button type="button" class="ocu-button-text" data-action="add-granted-role" [attr.aria-disabled]="assignGrantedBlocked" (click)="onAssignGranted()">
            {{ STRINGS.webAppRoleAssign }}
          </button>
        </div>
      </ng-template>
    </app-form-tabs>

    <!-- The dialogs' hosts sit before the bar, so the bar stays the page's last flex item and
         reaches the bottom of the content area however short the open tab is. -->
    @if (grantDialogOpen) {
      <app-role-grant-dialog
        [resources]="resourceOptions"
        [granted]="heldGrants"
        [editing]="dialogEditing"
        [clearing]="dialogClearing"
        (applied)="applyGrant($event)"
        (closed)="closeGrantDialog()"
      />
    }
    <app-screen-action-dialogs [descriptor]="roleList" />

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
export class RoleEditorPage {
  private readonly store = inject(RoleEditor);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly injector = inject(Injector);
  private readonly actions = inject(ScreenActionHandler);
  private readonly session = inject(Session, { optional: true });

  protected readonly STRINGS = STRINGS;

  protected readonly roleList = ROLE_LIST;

  protected readonly nameId = 'ocu-role-edit-Name';

  protected readonly memberUserId = 'ocu-role-edit-member-user';

  protected readonly memberRoleId = 'ocu-role-edit-member-role';

  protected readonly memberEffectId = 'ocu-role-edit-member-effect';

  protected readonly grantedRoleId = 'ocu-role-edit-granted-role';

  protected readonly deleteReasonId = 'ocu-role-edit-action-delete-reason';

  /** The key of the tab on screen. */
  protected readonly selectedTab = signal(GENERAL_TAB);

  /** The Members tab's account name, the role it picks, and the Assigned to tab's pick. */
  private readonly memberUserPick = signal('');
  private readonly memberRolePick = signal('');
  private readonly grantedPick = signal('');

  /** The grant dialog, when one is open. Local to this page and never stored. */
  private readonly grantDialog = signal<GrantDialogState | null>(null);

  /** Bumped by both stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  /** Whether the summary has been focused for the refusal now on screen. */
  private focusedSummary = false;

  /** Where every action this editor starts reports (AD-53). */
  private readonly sink: ActionSink = {
    setRefusal: (reason) => this.store.setActionRefusal(reason),
    applied: (actionId) => this.onApplied(actionId),
  };

  constructor() {
    const stopStore = this.store.subscribe(() => this.bump());
    const stopDirty = this.formDirty.subscribe(() => {
      // Dialogs never stack: the leave question replaces an open grant dialog.
      if (this.formDirty.pending()) this.grantDialog.set(null);
      this.bump();
    });
    let followed = this.routeId();
    void this.store.open(followed);
    // One id route to another reuses this page, so the editor follows the id, not the page's life.
    const stopIdChange = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      const id = this.routeId();
      if (id === followed || id === '') return;
      followed = id;
      this.selectedTab.set(GENERAL_TAB);
      this.clearPicks();
      void this.store.open(id);
    });
    // AD-14: a change to a role or an account, from either caller, can change this role's grants or
    // members, so it re-reads the role; this role's own delete is the list's.
    const stopChanges = this.injector.get(ChangeBus).subscribe((event) => {
      if (event.kind !== 'changed') return;
      if (event.type !== ROLE_ENTITY && event.type !== 'user') return;
      if (event.type === ROLE_ENTITY && event.action === 'deleted' && this.store.is(event.id)) return;
      void this.store.refresh();
    });
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      stopIdChange.unsubscribe();
      stopChanges();
      if (this.actions.pending()?.descriptor === ROLE_LIST) this.actions.cancelPending();
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

  protected get roleName(): string {
    this.generation();
    return this.store.name();
  }

  protected get description(): string {
    this.generation();
    return this.store.description();
  }

  protected get escalationOnly(): boolean {
    this.generation();
    return this.store.escalationOnly();
  }

  protected get tabs(): readonly FormTabView[] {
    this.generation();
    const counts = tabErrorCounts(ROLE_FIELD_TABS, this.store.violations());
    return [
      { key: GENERAL_TAB, label: STRINGS.processDetailsGroupGeneral, count: counts[GENERAL_TAB] ?? 0 },
      { key: MEMBERS_TAB, label: STRINGS.roleEditorTabMembers, count: counts[MEMBERS_TAB] ?? 0 },
      { key: ASSIGNED_TO_TAB, label: STRINGS.roleEditorTabAssignedTo, count: counts[ASSIGNED_TO_TAB] ?? 0 },
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

  /** The sentence Delete is drawn refused with -- a predefined role's -- or `''` (AD-53). */
  protected get deleteReason(): string {
    this.generation();
    const rule = screenForDescriptor(ROLE_LIST)?.rowActions.find((action) => action.id === DELETE_ACTION)?.selfProtection ?? '';
    return selfProtectionReason(rule, this.store.name(), this.session?.userName() ?? '');
  }

  protected get deleteDisabled(): string | null {
    return this.deleteReason !== '' || this.locked ? 'true' : null;
  }

  protected get deleteDescribedBy(): string | null {
    return this.deleteReason !== '' ? this.deleteReasonId : null;
  }

  protected get grantRows(): readonly { readonly grant: Grant; readonly line: string; readonly editLabel: string; readonly removeLabel: string }[] {
    this.generation();
    return this.store.grants().map((grant) => ({
      grant,
      line: grantLine(grant.name, grant.permissions),
      editLabel: `${STRINGS.agentPanelSecretWarningEdit} ${grant.name}`,
      removeLabel: `${STRINGS.actionRemove} ${grant.name}`,
    }));
  }

  protected get heldGrants(): readonly Grant[] {
    this.generation();
    return this.store.grants();
  }

  protected get resourceOptions(): readonly ResourceOption[] {
    this.generation();
    return this.store.resourceChoices();
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

  protected get memberRows(): readonly MemberView[] {
    this.generation();
    return this.store.members().map((member: Member) => ({
      key: memberKey(member),
      name: member.name,
      type: memberTypeWord(member.type),
      removable: member.type === MEMBER_TYPE_USER || member.type === MEMBER_TYPE_ROLE,
      removeLabel: `${STRINGS.actionRemove} ${member.name}`,
    }));
  }

  protected get hasMembers(): boolean {
    return this.memberRows.length > 0;
  }

  protected get memberUserPicked(): string {
    return this.memberUserPick();
  }

  protected get memberRolePicked(): string {
    return this.memberRolePick();
  }

  /** The roles a role member may be: every role but this one and the roles already holding it. */
  protected get memberRoleOptions(): readonly string[] {
    this.generation();
    const own = this.store.name().toLowerCase();
    const holding = new Set(this.store.members().filter((member) => member.type === MEMBER_TYPE_ROLE).map((member) => member.name.toLowerCase()));
    return this.store
      .roleChoices()
      .map((option: RoleOption) => option.name)
      .filter((name) => name.toLowerCase() !== own && !holding.has(name.toLowerCase()));
  }

  /** Whether granting this role grants %All or an administrative privilege (AD-10). */
  protected get privileged(): boolean {
    this.generation();
    return this.store.privileged();
  }

  /** The Members tab's assign controls are described by the grant's consequence while this role is privileged. */
  protected get memberEffectDescribedBy(): string | null {
    return this.privileged ? this.memberEffectId : null;
  }

  protected get assignUserBlocked(): string | null {
    return this.locked || this.memberUserPick().trim() === '' ? 'true' : null;
  }

  protected get assignMemberRoleBlocked(): string | null {
    return this.locked || this.memberRolePick() === '' ? 'true' : null;
  }

  protected get grantedRoles(): readonly string[] {
    this.generation();
    return this.store.grantedRoles();
  }

  protected get hasGranted(): boolean {
    return this.grantedRoles.length > 0;
  }

  protected get grantedPicked(): string {
    return this.grantedPick();
  }

  /** The roles this role may be assigned: every role but itself and the ones it already carries. */
  protected get grantedOptions(): readonly string[] {
    this.generation();
    const own = this.store.name().toLowerCase();
    const held = new Set(this.store.grantedRoles().map((name) => name.toLowerCase()));
    return this.store
      .roleChoices()
      .map((option: RoleOption) => option.name)
      .filter((name) => name.toLowerCase() !== own && !held.has(name.toLowerCase()));
  }

  /** Whether the role picked on the Assigned to tab grants a privilege, by the server's mark (AD-10). */
  protected get grantedPickPrivileged(): boolean {
    this.generation();
    const picked = this.grantedPick();
    return picked !== '' && this.store.roleChoices().some((option) => option.name === picked && option.privileged);
  }

  protected get grantedEffectDescribedBy(): string | null {
    return this.grantedPickPrivileged ? `${this.grantedRoleId}-effect` : null;
  }

  protected get assignGrantedBlocked(): string | null {
    return this.locked || this.grantedPick() === '' ? 'true' : null;
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

  /** The length the instance stores for `field`, or `null` where it declares none. */
  protected maxLength(field: string): number | null {
    this.generation();
    const bound = this.store.maxLength(field);
    return bound > 0 ? bound : null;
  }

  protected removeLabel(role: string): string {
    return `${STRINGS.actionRemove} ${role}`;
  }

  protected get descriptionField(): FieldView {
    return this.fieldView(DESCRIPTION_FIELD);
  }

  protected get escalationField(): FieldView {
    return this.fieldView(ESCALATION_FIELD);
  }

  protected get resourcesField(): FieldView {
    return this.fieldView(RESOURCES_FIELD);
  }

  // --- intents ---------------------------------------------------------------------------------

  protected selectTab(key: string): void {
    this.selectedTab.set(key);
  }

  protected onDescription(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setDescription(target.value);
  }

  protected onEscalation(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setEscalationOnly(target.checked);
  }

  protected onBlur(field: string): void {
    this.store.onBlur(field);
  }

  protected onDelete(): void {
    if (!this.store.editable()) return;
    this.store.setActionRefusal('');
    this.actions.startFor(ROLE_LIST, DELETE_ACTION, this.store.name(), { Name: this.store.name() }, this.sink);
  }

  protected openAdd(): void {
    if (this.store.editable()) this.grantDialog.set({ editing: null, clearing: false });
  }

  protected openEdit(grant: Grant): void {
    if (this.store.editable()) this.grantDialog.set({ editing: grant, clearing: false });
  }

  protected openRemove(grant: Grant): void {
    if (this.store.editable()) this.grantDialog.set({ editing: grant, clearing: true });
  }

  /** The grant dialog's answer, applied on the instance as a delta over its own read (AD-56 (ii)). */
  protected applyGrant(result: GrantResult): void {
    this.grantDialog.set(null);
    if (result.permissions === '') {
      this.startOnRole(REMOVE_RESOURCE_GRANT, { Resource: result.name });
      return;
    }
    this.startOnRole(SET_RESOURCE_GRANT, { Resource: result.name, Permissions: result.permissions });
  }

  protected closeGrantDialog(): void {
    this.grantDialog.set(null);
  }

  protected onPickMemberUser(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.memberUserPick.set(target.value);
  }

  protected onPickMemberRole(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLSelectElement) this.memberRolePick.set(target.value);
  }

  protected onPickGranted(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLSelectElement) this.grantedPick.set(target.value);
  }

  /** Assign this role to an account: the Users list's `add-role` on that account (AD-53). */
  protected onAssignUser(): void {
    const user = this.memberUserPick().trim();
    if (!this.store.editable() || user === '') return;
    this.store.setActionRefusal('');
    this.actions.startFor(USER_LIST, ADD_ROLE, user, null, this.sink, this.store.name());
  }

  /** Assign this role to another role: `add-granted-role` on that role, with this one as its value. */
  protected onAssignMemberRole(): void {
    const role = this.memberRolePick();
    if (!this.store.editable() || role === '') return;
    this.store.setActionRefusal('');
    this.actions.startFor(ROLE_LIST, ADD_GRANTED_ROLE, role, null, this.sink, '', { Role: this.store.name() });
  }

  /** Remove this role from one member: an account through the Users list, a role through its own grants. */
  protected onRemoveMember(key: string): void {
    const member = this.store.members().find((entry: Member) => memberKey(entry) === key);
    if (member === undefined || !this.store.editable()) return;
    this.store.setActionRefusal('');
    if (member.type === MEMBER_TYPE_USER) {
      this.actions.startFor(USER_LIST, REMOVE_ROLE, member.name, null, this.sink, this.store.name());
      return;
    }
    if (member.type === MEMBER_TYPE_ROLE) {
      this.actions.startFor(ROLE_LIST, REMOVE_GRANTED_ROLE, member.name, null, this.sink, '', { Role: this.store.name() });
    }
  }

  protected onAssignGranted(): void {
    const role = this.grantedPick();
    if (role === '') return;
    this.startOnRole(ADD_GRANTED_ROLE, { Role: role });
  }

  protected onRemoveGranted(role: string): void {
    this.startOnRole(REMOVE_GRANTED_ROLE, { Role: role });
  }

  protected async onSave(): Promise<void> {
    if (!this.store.canSave()) return;
    const saved = await this.store.save();
    if (!saved) this.afterRefusal();
  }

  /** Open the tab that holds `field`, then focus it. */
  protected focusField(field: string): void {
    const tab = ROLE_FIELD_TABS[field];
    if (tab !== undefined && tab !== this.selectedTab()) {
      this.selectedTab.set(tab);
      afterNextRender(() => this.focusControl(field), { injector: this.injector });
      return;
    }
    this.focusControl(field);
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(ROLE_LIST_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  private clearPicks(): void {
    this.memberUserPick.set('');
    this.memberRolePick.set('');
    this.grantedPick.set('');
  }

  /** The role this route names, or `''`. */
  private routeId(): string {
    const screen = screenForDescriptor(ROLE_FORM);
    return screen === null ? '' : ownIdSegment(screen, this.router.url);
  }

  /** Start one of the Roles list's value actions on this role, with the values the editor chose (AD-53). */
  private startOnRole(actionId: string, values: ActionValues): void {
    if (!this.store.editable()) return;
    this.store.setActionRefusal('');
    this.actions.startFor(ROLE_LIST, actionId, this.store.name(), null, this.sink, '', values);
  }

  /** An action was applied: a delete of this role returns to the list, and anything else re-reads it. */
  private onApplied(actionId: string): void {
    if (actionId === DELETE_ACTION) {
      this.store.abandon();
      void this.router.navigateByUrl(withQuery(ROLE_LIST_ROUTE, this.router.url));
      return;
    }
    this.clearPicks();
    void this.store.refresh();
  }

  /**
   * After a refused Save: the tab that holds the first refused field opens, the error summary takes
   * focus, then that field, in the order EXPERIENCE.md's `form-page` validation rule states.
   */
  private afterRefusal(): void {
    const open = tabToOpen(ROLE_FIELD_TABS, [...GENERAL_FIELDS, GRANTED_ROLES_FIELD], this.store.violations());
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
    const order = [...GENERAL_FIELDS, GRANTED_ROLES_FIELD];
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

  private controlId(field: string): string {
    return `ocu-role-edit-${field}`;
  }
}
