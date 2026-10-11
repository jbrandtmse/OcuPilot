import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, signal } from '@angular/core';

import { screenForDescriptor } from '../../core/navigation';
import { selfProtectionReason } from '../../core/self-protection';
import { STRINGS } from '../../core/strings';
import {
  ADD_APPLICATION_ROLE,
  ADD_MATCHING_ROLE,
  ADD_ROUTINE,
  type ActionSink,
  REMOVE_APPLICATION_ROLE,
  REMOVE_MATCHING_ROLE,
  REMOVE_ROUTINE,
  ScreenActionHandler,
} from '../../shell/screen-action-handler';
import { ROUTINE_APP_LIST_DESCRIPTOR } from './routine-app-actions';
import { APPLICATION_ROLES_TAB, MATCHING_ROLES_TAB, ROUTINES_TAB, RoutineAppForm } from './routine-app-form.store';

/** The two types a routine entry takes, as the instance spells them. */
export const ROUTINE_TYPE = 'Routine';
export const CLASS_TYPE = 'Class';

/** One held role, resolved for drawing with its Remove button's name. */
interface HeldRoleView {
  readonly key: string;
  readonly removeLabel: string;
  readonly match: string;
  readonly role: string;
}

/** One held routine entry, resolved for drawing with its Remove button's name. */
interface HeldRoutineView {
  readonly key: string;
  readonly removeLabel: string;
  readonly name: string;
  readonly db: string;
  readonly type: string;
}

/**
 * The privileged routine application editor's three member tabs (Story 18.33, AD-56 (ii)): Application roles, Matching
 * roles, and Routines and classes, one body each, chosen by `tab`. The application roles and matching roles bodies are
 * the web application editor's, copied for the reason DW-2278 records; the routines body lists Database, Routine or
 * class, Type and Remove, and adds by a hinted name, a database picker, a Routine or Class picker and Assign.
 *
 * **A tab composes no list.** Each act is `ScreenActionHandler.startFor` on the privileged routine applications list's
 * own declared action with the values the pickers chose, and the instance applies it as a delta over its fresh read; the
 * store then reads the application again. A pick of a privileged role, or a routine added while a role the application
 * grants is privileged, states `privilegedGrantEffect` at the field (AD-10): the server's mark decides, the client decides
 * nothing.
 *
 * **On OcuPilot's own two applications every control is `aria-disabled`**, described by the sentence the list's declared
 * rule explains the refusal with (`routineAppRefusalOcuPilot`); the instance refuses each action either way.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-routine-app-member-tabs',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `@if (actionBanner) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-routine-app="action-refusal">{{ actionRefusal }}</p>
    }
    @if (isApplicationRoles) {
      @if (hasApplicationRoles) {
        <ul class="ocu-form-roles" [attr.aria-label]="STRINGS.webAppFormApplicationRoles">
          @for (held of applicationRoles; track held.key) {
            <li class="ocu-form-role">
              <span class="ocu-form-role-name">{{ held.role }}</span>
              <button
                type="button"
                class="ocu-button-text"
                data-action="remove-application-role"
                [attr.aria-label]="held.removeLabel"
                [attr.aria-disabled]="blocked"
                [attr.aria-describedby]="describedBy"
                (click)="onRemoveApplicationRole(held.role)"
              >
                {{ STRINGS.actionRemove }}
              </button>
            </li>
          }
        </ul>
      } @else {
        <p class="ocu-form-legend">{{ STRINGS.webAppApplicationRolesEmpty }}</p>
      }
      <div class="ocu-form-fields">
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="applicationRoleId">{{ STRINGS.userRoleField }}</label>
          <div class="ocu-field-control">
            <select
              class="ocu-field-input"
              [id]="applicationRoleId"
              [attr.aria-disabled]="blocked"
              [attr.aria-describedby]="applicationRoleDescribedBy"
              (change)="onPickApplicationRole($event)"
            >
              <option value="" [selected]="applicationRolePicked === ''"></option>
              @for (option of applicationRoleOptions; track option) {
                <option [value]="option" [selected]="option === applicationRolePicked">{{ option }}</option>
              }
            </select>
          </div>
          @if (hasApplicationRoleEffect) {
            <p class="ocu-field-caption" [id]="applicationRoleId + '-effect'">{{ applicationRoleEffect }}</p>
          }
        </div>
        <button
          type="button"
          class="ocu-button-text"
          data-action="add-application-role"
          [attr.aria-disabled]="assignApplicationBlocked"
          [attr.aria-describedby]="describedBy"
          (click)="onAssignApplicationRole()"
        >
          {{ STRINGS.webAppRoleAssign }}
        </button>
        @if (hasRefusal) {
          <p class="ocu-field-caption" [id]="refusalId">{{ refusal }}</p>
        }
      </div>
    }
    @if (isMatchingRoles) {
      @if (hasMatchingRoles) {
        <ul class="ocu-form-roles" [attr.aria-label]="STRINGS.webAppTabMatchingRoles">
          @for (held of matchingRoles; track held.key) {
            <li class="ocu-form-role">
              <span class="ocu-form-role-name">{{ held.match }}</span>
              <span class="ocu-form-role-name">{{ held.role }}</span>
              <button
                type="button"
                class="ocu-button-text"
                data-action="remove-matching-role"
                [attr.aria-label]="held.removeLabel"
                [attr.aria-disabled]="blocked"
                [attr.aria-describedby]="describedBy"
                (click)="onRemoveMatchingRole(held.match, held.role)"
              >
                {{ STRINGS.actionRemove }}
              </button>
            </li>
          }
        </ul>
      } @else {
        <p class="ocu-form-legend">{{ STRINGS.webAppMatchingRolesEmpty }}</p>
      }
      <div class="ocu-form-fields">
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="matchRoleId">{{ STRINGS.webAppFieldMatchRole }}</label>
          <div class="ocu-field-control">
            <select
              class="ocu-field-input"
              [id]="matchRoleId"
              [attr.aria-disabled]="blocked"
              [attr.aria-describedby]="describedBy"
              (change)="onPickMatchRole($event)"
            >
              <option value="" [selected]="matchRolePicked === ''"></option>
              @for (option of roleNames; track option) {
                <option [value]="option" [selected]="option === matchRolePicked">{{ option }}</option>
              }
            </select>
          </div>
        </div>
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="matchTargetId">{{ STRINGS.userRoleField }}</label>
          <div class="ocu-field-control">
            <select
              class="ocu-field-input"
              [id]="matchTargetId"
              [attr.aria-disabled]="blocked"
              [attr.aria-describedby]="matchTargetDescribedBy"
              (change)="onPickMatchTarget($event)"
            >
              <option value="" [selected]="matchTargetPicked === ''"></option>
              @for (option of roleNames; track option) {
                <option [value]="option" [selected]="option === matchTargetPicked">{{ option }}</option>
              }
            </select>
          </div>
          @if (hasMatchTargetEffect) {
            <p class="ocu-field-caption" [id]="matchTargetId + '-effect'">{{ matchTargetEffect }}</p>
          }
        </div>
        <button
          type="button"
          class="ocu-button-text"
          data-action="add-matching-role"
          [attr.aria-disabled]="assignMatchingBlocked"
          [attr.aria-describedby]="describedBy"
          (click)="onAssignMatchingRole()"
        >
          {{ STRINGS.webAppRoleAssign }}
        </button>
        @if (hasRefusal) {
          <p class="ocu-field-caption" [id]="refusalId">{{ refusal }}</p>
        }
      </div>
    }
    @if (isRoutines) {
      @if (hasRoutines) {
        <table class="ocu-routine-app-routines" [attr.aria-label]="STRINGS.routineAppTabRoutines">
          <thead>
            <tr>
              <th scope="col">{{ STRINGS.systemInfoDatabase }}</th>
              <th scope="col">{{ STRINGS.routineAppFieldRoutine }}</th>
              <th scope="col">{{ STRINGS.tableColumnType }}</th>
              <th scope="col"><span class="ocu-visually-hidden">{{ STRINGS.actionRemove }}</span></th>
            </tr>
          </thead>
          <tbody>
            @for (held of routines; track held.key) {
              <tr>
                <td>{{ held.db }}</td>
                <td>{{ held.name }}</td>
                <td>{{ held.type }}</td>
                <td>
                  <button
                    type="button"
                    class="ocu-button-text"
                    data-action="remove-routine"
                    [attr.aria-label]="held.removeLabel"
                    [attr.aria-disabled]="blocked"
                    [attr.aria-describedby]="describedBy"
                    (click)="onRemoveRoutine(held.name, held.db, held.type)"
                  >
                    {{ STRINGS.actionRemove }}
                  </button>
                </td>
              </tr>
            }
          </tbody>
        </table>
      } @else {
        <p class="ocu-form-legend">{{ STRINGS.routineAppRoutinesEmpty }}</p>
      }
      <div class="ocu-form-fields">
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="routineNameId">{{ STRINGS.routineAppFieldRoutine }}</label>
          <div class="ocu-field-control">
            <input
              class="ocu-field-input"
              type="text"
              autocomplete="off"
              spellcheck="false"
              data-field="RoutineOrClass"
              [id]="routineNameId"
              [value]="routineNamePicked"
              [attr.aria-disabled]="blocked"
              [attr.aria-describedby]="routineNameDescribedBy"
              (input)="onRoutineName($event)"
            />
          </div>
          <p class="ocu-field-caption" [id]="routineNameHintId">{{ STRINGS.routineAppRoutineHint }}</p>
        </div>
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="routineDbId">{{ STRINGS.systemInfoDatabase }}</label>
          <div class="ocu-field-control">
            <select
              class="ocu-field-input"
              data-field="Db"
              [id]="routineDbId"
              [attr.aria-disabled]="blocked"
              [attr.aria-describedby]="describedBy"
              (change)="onPickRoutineDb($event)"
            >
              <option value="" [selected]="routineDbPicked === ''"></option>
              @for (option of databases; track option) {
                <option [value]="option" [selected]="option === routineDbPicked">{{ option }}</option>
              }
            </select>
          </div>
        </div>
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="routineTypeId">{{ STRINGS.tableColumnType }}</label>
          <div class="ocu-field-control">
            <select
              class="ocu-field-input"
              data-field="Type"
              [id]="routineTypeId"
              [attr.aria-disabled]="blocked"
              [attr.aria-describedby]="describedBy"
              (change)="onPickRoutineType($event)"
            >
              <option [value]="routineType" [selected]="routineTypePicked === routineType">{{ STRINGS.processColumnRoutine }}</option>
              <option [value]="classType" [selected]="routineTypePicked === classType">{{ STRINGS.explorerClassDocumentLabel }}</option>
            </select>
          </div>
        </div>
        <button
          type="button"
          class="ocu-button-text"
          data-action="add-routine"
          [attr.aria-disabled]="assignRoutineBlocked"
          [attr.aria-describedby]="routineDescribedBy"
          (click)="onAssignRoutine()"
        >
          {{ STRINGS.webAppRoleAssign }}
        </button>
        @if (hasRoutineEffect) {
          <p class="ocu-field-caption" [id]="routineEffectId">{{ STRINGS.privilegedGrantEffect }}</p>
        }
        @if (hasRefusal) {
          <p class="ocu-field-caption" [id]="refusalId">{{ refusal }}</p>
        }
      </div>
    }`,
})
export class RoutineAppMemberTabs {
  private readonly store = inject(RoutineAppForm);

  private readonly actions = inject(ScreenActionHandler);

  /** Which body this instance draws: one of the three member tabs' keys. */
  readonly tab = input.required<string>();

  protected readonly STRINGS = STRINGS;

  protected readonly routineType = ROUTINE_TYPE;

  protected readonly classType = CLASS_TYPE;

  protected readonly applicationRoleId = 'ocu-routine-app-application-role';
  protected readonly matchRoleId = 'ocu-routine-app-match-role';
  protected readonly matchTargetId = 'ocu-routine-app-match-target';
  protected readonly routineNameId = 'ocu-routine-app-routine-name';
  protected readonly routineNameHintId = 'ocu-routine-app-routine-name-hint';
  protected readonly routineDbId = 'ocu-routine-app-routine-db';
  protected readonly routineTypeId = 'ocu-routine-app-routine-type';
  protected readonly routineEffectId = 'ocu-routine-app-routine-effect';

  /** What each picker holds, before its Assign. */
  private readonly applicationRolePick = signal('');
  private readonly matchRolePick = signal('');
  private readonly matchTargetPick = signal('');
  private readonly routineNamePick = signal('');
  private readonly routineDbPick = signal('');
  private readonly routineTypePick = signal(ROUTINE_TYPE);

  /** Bumped by the store, so the template re-reads it under `OnPush`. */
  private readonly generation = signal(0);

  /** Where the list's row actions report when this editor starts them (AD-53). */
  private readonly sink: ActionSink = {
    setRefusal: (reason) => this.store.setActionRefusal(reason),
    applied: () => this.onApplied(),
  };

  constructor() {
    const stop = this.store.subscribe(() => this.generation.update((value) => value + 1));
    inject(DestroyRef).onDestroy(stop);
  }

  // --- which body ------------------------------------------------------------------------------

  protected get isApplicationRoles(): boolean {
    return this.tab() === APPLICATION_ROLES_TAB;
  }

  protected get isMatchingRoles(): boolean {
    return this.tab() === MATCHING_ROLES_TAB;
  }

  protected get isRoutines(): boolean {
    return this.tab() === ROUTINES_TAB;
  }

  // --- refusals --------------------------------------------------------------------------------

  /** The sentence the list's declared rule explains OcuPilot's own two applications with, or `''` for any other. */
  protected get refusal(): string {
    this.generation();
    return this.ruleReason(ADD_APPLICATION_ROLE);
  }

  protected get hasRefusal(): boolean {
    return this.refusal !== '';
  }

  protected get blocked(): string | null {
    this.generation();
    return this.refusal !== '' || !this.store.editable() ? 'true' : null;
  }

  /** The rule's sentence, one per body: every body stays in the DOM, so each needs its own id. */
  protected get refusalId(): string {
    return `ocu-routine-app-members-refusal-${this.tab()}`;
  }

  protected get describedBy(): string | null {
    return this.withRefusal();
  }

  /** The refusal a row action was answered with. */
  protected get actionRefusal(): string {
    this.generation();
    return this.store.actionRefusal();
  }

  protected get actionBanner(): boolean {
    return this.actionRefusal !== '';
  }

  // --- application roles -----------------------------------------------------------------------

  protected get applicationRoles(): readonly HeldRoleView[] {
    this.generation();
    return this.store.applicationRoles().map((role) => ({
      key: role,
      removeLabel: `${STRINGS.actionRemove} ${role}`,
      match: '',
      role,
    }));
  }

  protected get hasApplicationRoles(): boolean {
    return this.applicationRoles.length > 0;
  }

  /** Every role the instance holds, for the pickers. */
  protected get roleNames(): readonly string[] {
    this.generation();
    return this.store.roleChoices().map((role) => role.name);
  }

  /** The roles an application-role Assign offers: every role the application does not grant already. */
  protected get applicationRoleOptions(): readonly string[] {
    const held = new Set(this.store.applicationRoles().map((role) => role.toLowerCase()));
    return this.roleNames.filter((role) => !held.has(role.toLowerCase()));
  }

  protected get applicationRolePicked(): string {
    return this.applicationRolePick();
  }

  protected get applicationRoleEffect(): string {
    return this.privilegeEffect(this.applicationRolePick());
  }

  protected get hasApplicationRoleEffect(): boolean {
    return this.applicationRoleEffect !== '';
  }

  protected get applicationRoleDescribedBy(): string | null {
    return this.withRefusal(this.hasApplicationRoleEffect ? `${this.applicationRoleId}-effect` : '');
  }

  protected get assignApplicationBlocked(): string | null {
    return this.blocked !== null || this.applicationRolePick() === '' ? 'true' : null;
  }

  // --- matching roles --------------------------------------------------------------------------

  protected get matchingRoles(): readonly HeldRoleView[] {
    this.generation();
    return this.store.matchingRoles().map((entry) => ({
      key: `${entry.match}:${entry.role}`,
      removeLabel: `${STRINGS.actionRemove} ${entry.match} ${entry.role}`,
      match: entry.match,
      role: entry.role,
    }));
  }

  protected get hasMatchingRoles(): boolean {
    return this.matchingRoles.length > 0;
  }

  protected get matchRolePicked(): string {
    return this.matchRolePick();
  }

  protected get matchTargetPicked(): string {
    return this.matchTargetPick();
  }

  protected get matchTargetEffect(): string {
    return this.privilegeEffect(this.matchTargetPick());
  }

  protected get hasMatchTargetEffect(): boolean {
    return this.matchTargetEffect !== '';
  }

  protected get matchTargetDescribedBy(): string | null {
    return this.withRefusal(this.hasMatchTargetEffect ? `${this.matchTargetId}-effect` : '');
  }

  protected get assignMatchingBlocked(): string | null {
    return this.blocked !== null || this.matchRolePick() === '' || this.matchTargetPick() === '' ? 'true' : null;
  }

  // --- routines --------------------------------------------------------------------------------

  protected get routines(): readonly HeldRoutineView[] {
    this.generation();
    return this.store.routines().map((entry) => ({
      key: `${entry.name}:${entry.db}:${entry.type}`,
      removeLabel: `${STRINGS.actionRemove} ${entry.name} ${entry.db} ${entry.type}`,
      name: entry.name,
      db: entry.db,
      type: entry.type,
    }));
  }

  protected get hasRoutines(): boolean {
    return this.routines.length > 0;
  }

  /** The databases the instance defines, which an entry may name. */
  protected get databases(): readonly string[] {
    this.generation();
    return this.store.databases();
  }

  protected get routineNamePicked(): string {
    return this.routineNamePick();
  }

  protected get routineDbPicked(): string {
    return this.routineDbPick();
  }

  protected get routineTypePicked(): string {
    return this.routineTypePick();
  }

  /** Whether a role the application grants now is privileged, so a routine added now is a grant (AD-10). */
  protected get hasRoutineEffect(): boolean {
    this.generation();
    const roles = [...this.store.applicationRoles(), ...this.store.matchingRoles().map((entry) => entry.role)];
    return roles.some((role) => this.store.privileged(role));
  }

  protected get routineNameDescribedBy(): string | null {
    return this.withRefusal(this.routineNameHintId);
  }

  protected get routineDescribedBy(): string | null {
    return this.withRefusal(this.hasRoutineEffect ? this.routineEffectId : '');
  }

  protected get assignRoutineBlocked(): string | null {
    return this.blocked !== null || this.routineNamePick().trim() === '' || this.routineDbPick() === '' ? 'true' : null;
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onPickApplicationRole(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLSelectElement) this.applicationRolePick.set(target.value);
  }

  protected onPickMatchRole(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLSelectElement) this.matchRolePick.set(target.value);
  }

  protected onPickMatchTarget(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLSelectElement) this.matchTargetPick.set(target.value);
  }

  protected onRoutineName(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.routineNamePick.set(target.value);
  }

  protected onPickRoutineDb(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLSelectElement) this.routineDbPick.set(target.value);
  }

  protected onPickRoutineType(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLSelectElement) this.routineTypePick.set(target.value);
  }

  protected onAssignApplicationRole(): void {
    if (this.assignApplicationBlocked !== null) return;
    this.start(ADD_APPLICATION_ROLE, { Role: this.applicationRolePick() });
  }

  protected onRemoveApplicationRole(role: string): void {
    if (this.blocked !== null) return;
    this.start(REMOVE_APPLICATION_ROLE, { Role: role });
  }

  protected onAssignMatchingRole(): void {
    if (this.assignMatchingBlocked !== null) return;
    this.start(ADD_MATCHING_ROLE, { MatchRole: this.matchRolePick(), Role: this.matchTargetPick() });
  }

  protected onRemoveMatchingRole(match: string, role: string): void {
    if (this.blocked !== null) return;
    this.start(REMOVE_MATCHING_ROLE, { MatchRole: match, Role: role });
  }

  protected onAssignRoutine(): void {
    if (this.assignRoutineBlocked !== null) return;
    this.start(ADD_ROUTINE, { RoutineOrClass: this.routineNamePick().trim(), Db: this.routineDbPick(), Type: this.routineTypePick() });
  }

  protected onRemoveRoutine(name: string, db: string, type: string): void {
    if (this.blocked !== null) return;
    this.start(REMOVE_ROUTINE, { RoutineOrClass: name, Db: db, Type: type });
  }

  // --- internals -------------------------------------------------------------------------------

  /** Start one of the list's row actions on this application with the values a picker chose (AD-53). */
  private start(actionId: string, values: Readonly<Record<string, string>>): void {
    if (!this.store.editable()) return;
    this.store.setActionRefusal('');
    this.actions.startFor(ROUTINE_APP_LIST_DESCRIPTOR, actionId, this.store.id(), null, this.sink, '', values);
  }

  /** A row action was applied: the pickers clear and the application is read again. */
  private onApplied(): void {
    this.applicationRolePick.set('');
    this.matchRolePick.set('');
    this.matchTargetPick.set('');
    this.routineNamePick.set('');
    this.routineDbPick.set('');
    this.routineTypePick.set(ROUTINE_TYPE);
    void this.store.refresh();
  }

  /** `id`, when given, then the rule's sentence while one applies, as one `aria-describedby` value, or `null`. */
  private withRefusal(id = ''): string | null {
    const ids = [id, this.refusal !== '' ? this.refusalId : ''].filter((one) => one !== '');
    return ids.length === 0 ? null : ids.join(' ');
  }

  /** The consequence a privileged role choice states (AD-10); `''` for a role the server did not mark. */
  private privilegeEffect(role: string): string {
    this.generation();
    if (role === '') return '';
    const choice = this.store.roleChoices().find((option) => option.name === role);
    return choice !== undefined && choice.privileged ? STRINGS.privilegedGrantEffect : '';
  }

  /** The sentence the list's declared rule for `actionId` explains this application with, or `''`. */
  private ruleReason(actionId: string): string {
    const rule = screenForDescriptor(ROUTINE_APP_LIST_DESCRIPTOR)?.rowActions.find((action) => action.id === actionId)?.selfProtection ?? '';
    return selfProtectionReason(rule, this.store.id());
  }
}
