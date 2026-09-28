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
import { SERVES_OCUPILOT_RULE, selfProtectionReason } from '../../core/self-protection';
import { STRINGS } from '../../core/strings';
import { STATE_CONFLICT_CODE, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { FormTabBody, FormTabs, type FormTabView } from '../../shell/form-tabs';
import {
  ADD_APPLICATION_ROLE,
  ADD_MATCHING_ROLE,
  type ActionSink,
  REMOVE_APPLICATION_ROLE,
  REMOVE_MATCHING_ROLE,
  ScreenActionHandler,
} from '../../shell/screen-action-handler';
import { MATCH_ROLES_FIELD, WEB_APPLICATION_ENTITY, type AutheMethod } from './create-form.store';
import {
  APPLICATION_ROLES_TAB,
  AUTHE_FIELD,
  CORS_FIELDS,
  CORS_TAB,
  DERIVED_PYTHON,
  DERIVED_REST,
  FLAG_FIELDS,
  GENERAL_FIELDS,
  GENERAL_TAB,
  MATCHING_ROLES_TAB,
  NUMBER_FIELDS,
  type MatchingRole,
  WEB_APP_FIELD_TABS,
  WebAppEditor,
} from './web-app-editor.store';

/** The list the editor is reached from, which Cancel returns to. */
export const WEB_APP_LIST_ROUTE = 'web-applications/list';

/** The Web applications list's descriptor, whose declared role actions the editor runs (AD-53). */
export const WEB_APP_LIST = 'OcuPilot.Screen.Descriptor.WebAppList';

/** The Web application form's descriptor, whose id route this editor is. */
export const WEB_APP_FORM = 'OcuPilot.Screen.Descriptor.WebAppForm';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** The label each General and Cross-origin settings field is drawn with. */
const FIELD_LABELS: Readonly<Record<string, string>> = {
  Description: STRINGS.tableColumnDescription,
  NameSpace: STRINGS.headerNamespaceLabel,
  IsNameSpaceDefault: STRINGS.webAppFieldDefaultApplication,
  Enabled: STRINGS.tableColumnEnabled,
  DispatchClass: STRINGS.webAppColumnDispatchClass,
  WSGIAppName: STRINGS.webAppFormPythonFile,
  WSGICallable: STRINGS.webAppFormPythonCallable,
  WSGIType: STRINGS.webAppFormPythonProtocol,
  Resource: STRINGS.webAppColumnResource,
  GroupById: STRINGS.webAppFieldGroupById,
  AutheEnabled: STRINGS.serviceColumnAuthentication,
  Timeout: STRINGS.webAppFieldTimeout,
  JWTAuthEnabled: STRINGS.webAppFieldJwt,
  JWTAccessTokenTimeout: STRINGS.webAppFieldJwtAccessTimeout,
  JWTRefreshTokenTimeout: STRINGS.webAppFieldJwtRefreshTimeout,
  ServeFiles: STRINGS.webAppFieldServeFiles,
  ServeFilesTimeout: STRINGS.webAppFieldServeFilesTimeout,
  Package: STRINGS.webAppFieldPackage,
  SuperClass: STRINGS.webAppFieldSuperClass,
  Recurse: STRINGS.webAppFormRecurse,
  AutoCompile: STRINGS.webAppFieldAutoCompile,
  LockCSPName: STRINGS.webAppFieldLockCspName,
  CorsAllowlist: STRINGS.webAppFieldCorsAllowlist,
  CorsCredentialsAllowed: STRINGS.webAppFieldCorsCredentials,
  CorsHeadersList: STRINGS.webAppFieldCorsHeaders,
};

/** The fields drawn as a select, and the fields drawn as a textarea of one entry per line. */
const SELECT_FIELDS: readonly string[] = ['WSGIType', 'ServeFiles'];

const LIST_FIELDS: readonly string[] = ['CorsAllowlist', 'CorsHeadersList'];

/** One field, resolved for drawing. Exactly one of the `is*` kinds is true. */
interface FieldView {
  readonly field: string;
  readonly id: string;
  readonly label: string;
  readonly isText: boolean;
  readonly isNumber: boolean;
  readonly isFlag: boolean;
  readonly isSelect: boolean;
  readonly isList: boolean;
  readonly isAuthe: boolean;
  readonly value: string;
  readonly checked: boolean;
  readonly options: readonly string[];
  readonly methods: readonly AutheMethodView[];
  readonly maxLength: number | null;
  readonly reason: string;
  readonly invalid: boolean;
  readonly effect: string;
  readonly effectId: string;
  readonly hasEffect: boolean;
  readonly caption: string;
  readonly captionId: string;
  readonly hasCaption: boolean;
  readonly describedBy: string | null;
}

/** One authentication method checkbox. */
interface AutheMethodView {
  readonly bit: number;
  readonly id: string;
  readonly label: string;
  readonly checked: boolean;
}

/** One held role, resolved for drawing with its Remove button's name. */
interface HeldRoleView {
  readonly key: string;
  readonly removeLabel: string;
  readonly match: string;
  readonly role: string;
}

/**
 * The web application editor, the `form-page` at `web-applications/list/edit/<id>` (Story 9.2,
 * FR-30, AD-55), following the user editor's pattern for tabs, validation, the error summary and
 * the unsaved-changes guard.
 *
 * **Its tabs are the classic editor's** (`%CSP.UI.Portal.Applications.Web`): General, Application
 * roles, Matching roles and Cross-origin settings. One form spans the General and Cross-origin
 * settings tabs, and Save sends the fields changed since the application's read; a refused Save
 * opens the tab that holds its first refused field, whose accessible name then counts them, and
 * focuses the error summary, then that field.
 *
 * **Roles change through the Web applications list's own role actions** (AD-53, AD-56 (ii)),
 * started through `ScreenActionHandler.startFor` with the values each tab's pickers chose; the
 * instance applies each as a delta.
 *
 * **A weakening change states its effect at its own field** (AD-10): the unauthenticated line at the
 * authentication methods, the no-resource line at Resource, and the repointed line once, at the
 * first code field the form changes. A privileged role choice states the privilege, or the combined
 * line where the application is unauthenticated. On one of OcuPilot's own applications the fields and
 * Save are drawn refused with the serving-path sentence and the role controls with the
 * privilege-grant one; the instance refuses either way.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-web-app-editor-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, FormTabs, FormTabBody],
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
    @if (hasServesRefusal) {
      <p class="ocu-field-caption" [id]="servesRefusalId">{{ servesRefusal }}</p>
    }
    <app-form-tabs [tabs]="tabs" [selected]="selectedTab()" (selectedChange)="selectTab($event)">
      <ng-template ocuFormTab="general">
        <div class="ocu-form-fields">
          <div class="ocu-form-fixed" role="group" [attr.aria-labelledby]="fixedCaptionId">
            <p class="ocu-field-caption" [id]="fixedCaptionId">{{ STRINGS.webAppEditorFixedFields }}</p>
            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="nameId">{{ STRINGS.tableColumnName }}</label>
              <input class="ocu-field-input" type="text" readonly [id]="nameId" [value]="applicationName" />
            </div>
            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="typeId">{{ STRINGS.webAppFormType }}</label>
              <input class="ocu-field-input" type="text" readonly [id]="typeId" [value]="typeLabel" />
            </div>
            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="locationId">{{ STRINGS.webAppFormPythonDirectory }}</label>
              <input class="ocu-field-input" type="text" readonly [id]="locationId" [value]="location" />
            </div>
            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="pathId">{{ STRINGS.webAppFieldPath }}</label>
              <input class="ocu-field-input" type="text" readonly [id]="pathId" [value]="physicalPath" />
            </div>
          </div>
          @for (view of generalFields; track view.field) {
            @if (view.isAuthe) {
              <fieldset class="ocu-field ocu-form-authe" [attr.id]="view.id" tabindex="-1" [attr.aria-describedby]="view.describedBy">
                <legend class="ocu-field-label">{{ view.label }}</legend>
                @for (method of view.methods; track method.bit) {
                  <label class="ocu-field-checkbox">
                    <input
                      type="checkbox"
                      [id]="method.id"
                      [checked]="method.checked"
                      [disabled]="locked"
                      (change)="onAuthe(method.bit, $event)"
                    />
                    <span>{{ method.label }}</span>
                  </label>
                }
                @if (view.hasEffect) {
                  <p class="ocu-field-caption" [id]="view.effectId">{{ view.effect }}</p>
                }
                @if (view.invalid) {
                  <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
                }
              </fieldset>
            }
            @if (view.isFlag) {
              <div class="ocu-field">
                <label class="ocu-field-checkbox">
                  <input
                    type="checkbox"
                    [id]="view.id"
                    [checked]="view.checked"
                    [disabled]="locked"
                    [attr.aria-invalid]="view.invalid"
                    [attr.aria-describedby]="view.describedBy"
                    (change)="onFlag(view.field, $event)"
                  />
                  <span>{{ view.label }}</span>
                </label>
                @if (view.invalid) {
                  <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
                }
              </div>
            }
            @if (view.isText) {
              <div class="ocu-field">
                <label class="ocu-field-label" [attr.for]="view.id">{{ view.label }}</label>
                <div class="ocu-field-control">
                  <input
                    class="ocu-field-input"
                    type="text"
                    [id]="view.id"
                    [value]="view.value"
                    [readOnly]="locked"
                    [attr.maxlength]="view.maxLength"
                    [attr.aria-invalid]="view.invalid"
                    [attr.aria-describedby]="view.describedBy"
                    (input)="onText(view.field, $event)"
                    (blur)="onBlur(view.field)"
                  />
                </div>
                @if (view.hasEffect) {
                  <p class="ocu-field-caption" [id]="view.effectId">{{ view.effect }}</p>
                }
                @if (view.invalid) {
                  <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
                }
              </div>
            }
            @if (view.isNumber) {
              <div class="ocu-field">
                <label class="ocu-field-label" [attr.for]="view.id">{{ view.label }}</label>
                <div class="ocu-field-control">
                  <input
                    class="ocu-field-input"
                    type="text"
                    inputmode="numeric"
                    [id]="view.id"
                    [value]="view.value"
                    [readOnly]="locked"
                    [attr.aria-invalid]="view.invalid"
                    [attr.aria-describedby]="view.describedBy"
                    (input)="onText(view.field, $event)"
                    (blur)="onBlur(view.field)"
                  />
                </div>
                @if (view.invalid) {
                  <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
                }
              </div>
            }
            @if (view.isSelect) {
              <div class="ocu-field">
                <label class="ocu-field-label" [attr.for]="view.id">{{ view.label }}</label>
                <div class="ocu-field-control">
                  <select
                    class="ocu-field-input"
                    [id]="view.id"
                    [disabled]="locked"
                    [attr.aria-invalid]="view.invalid"
                    [attr.aria-describedby]="view.describedBy"
                    (change)="onText(view.field, $event)"
                  >
                    @for (option of view.options; track option) {
                      <option [value]="option" [selected]="option === view.value">{{ option }}</option>
                    }
                  </select>
                </div>
                @if (view.invalid) {
                  <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
                }
              </div>
            }
          }
        </div>
      </ng-template>
      <ng-template ocuFormTab="application-roles">
        @if (hasApplicationRoles) {
          <ul class="ocu-form-roles" [attr.aria-label]="STRINGS.webAppFormApplicationRoles">
            @for (held of applicationRoles; track held.key) {
              <li class="ocu-form-role">
                <span class="ocu-form-role-name">{{ held.role }}</span>
                <button
                  type="button"
                  class="ocu-button-text"
                  [attr.aria-label]="held.removeLabel"
                  [attr.aria-disabled]="rolesBlocked"
                  [attr.aria-describedby]="rolesDescribedBy"
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
            [attr.aria-describedby]="rolesDescribedBy"
            (click)="onAssignApplicationRole()"
          >
            {{ STRINGS.webAppRoleAssign }}
          </button>
          @if (hasRolesRefusal) {
            <p class="ocu-field-caption" [id]="rolesRefusalId">{{ rolesRefusal }}</p>
          }
        </div>
      </ng-template>
      <ng-template ocuFormTab="matching-roles">
        @if (hasMatchingRoles) {
          <ul class="ocu-form-roles" [attr.aria-label]="STRINGS.webAppTabMatchingRoles">
            @for (held of matchingRoles; track held.key) {
              <li class="ocu-form-role">
                <span class="ocu-form-role-name">{{ held.match }}</span>
                <span class="ocu-form-role-name">{{ held.role }}</span>
                <button
                  type="button"
                  class="ocu-button-text"
                  [attr.aria-label]="held.removeLabel"
                  [attr.aria-disabled]="rolesBlocked"
                  [attr.aria-describedby]="rolesDescribedBy"
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
              <select class="ocu-field-input" [id]="matchRoleId" (change)="onPickMatchRole($event)">
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
            [attr.aria-describedby]="rolesDescribedBy"
            (click)="onAssignMatchingRole()"
          >
            {{ STRINGS.webAppRoleAssign }}
          </button>
          @if (hasRolesRefusal) {
            <p class="ocu-field-caption" [id]="rolesRefusalId + '-matching'">{{ rolesRefusal }}</p>
          }
        </div>
      </ng-template>
      <ng-template ocuFormTab="cors">
        <div class="ocu-form-fields">
          @for (view of corsFields; track view.field) {
            @if (view.isList) {
              <div class="ocu-field">
                <label class="ocu-field-label" [attr.for]="view.id">{{ view.label }}</label>
                <div class="ocu-field-control">
                  <textarea
                    class="ocu-field-input"
                    rows="3"
                    [id]="view.id"
                    [value]="view.value"
                    [readOnly]="locked"
                    [attr.aria-invalid]="view.invalid"
                    [attr.aria-describedby]="view.describedBy"
                    (input)="onList(view.field, $event)"
                    (blur)="onBlur(view.field)"
                  ></textarea>
                </div>
                <p class="ocu-field-caption" [id]="view.captionId">{{ view.caption }}</p>
                @if (view.invalid) {
                  <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
                }
              </div>
            }
            @if (view.isFlag) {
              <div class="ocu-field">
                <label class="ocu-field-checkbox">
                  <input
                    type="checkbox"
                    [id]="view.id"
                    [checked]="view.checked"
                    [disabled]="locked"
                    [attr.aria-invalid]="view.invalid"
                    [attr.aria-describedby]="view.describedBy"
                    (change)="onFlag(view.field, $event)"
                  />
                  <span>{{ view.label }}</span>
                </label>
                @if (view.invalid) {
                  <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
                }
              </div>
            }
          }
        </div>
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
        <button
          type="button"
          class="ocu-button-primary"
          [attr.aria-disabled]="saveBlocked"
          [attr.aria-describedby]="saveDescribedBy"
          (click)="onSave()"
        >
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
export class WebAppEditorPage {
  private readonly store = inject(WebAppEditor);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly injector = inject(Injector);
  private readonly actions = inject(ScreenActionHandler);

  protected readonly STRINGS = STRINGS;

  protected readonly nameId = 'ocu-web-app-edit-Name';
  protected readonly typeId = 'ocu-web-app-edit-Type';
  protected readonly locationId = 'ocu-web-app-edit-WSGIAppLocation';
  protected readonly pathId = 'ocu-web-app-edit-Path';
  protected readonly fixedCaptionId = 'ocu-web-app-edit-fixed';
  protected readonly servesRefusalId = 'ocu-web-app-edit-serves-refusal';
  protected readonly rolesRefusalId = 'ocu-web-app-edit-roles-refusal';
  protected readonly applicationRoleId = 'ocu-web-app-edit-application-role';
  protected readonly matchRoleId = 'ocu-web-app-edit-match-role';
  protected readonly matchTargetId = 'ocu-web-app-edit-match-target';

  /** The key of the tab on screen. */
  protected readonly selectedTab = signal(GENERAL_TAB);

  /** The role each roles tab's picker holds, before its Assign. */
  protected readonly applicationRolePick = signal('');
  protected readonly matchRolePick = signal('');
  protected readonly matchTargetPick = signal('');

  /** Bumped by both stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  /** Whether the summary has been focused for the refusal now on screen. */
  private focusedSummary = false;

  /** Where the Web applications list's role actions report, when this editor starts them (AD-53). */
  private readonly sink: ActionSink = {
    setRefusal: (reason) => this.store.setActionRefusal(reason),
    applied: () => this.onApplied(),
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
      this.clearPicks();
      void this.store.open(id);
    });
    // AD-14: a change to this application, from either caller, re-reads it; a delete is the list's.
    const stopChanges = this.injector.get(ChangeBus).subscribe((event) => {
      if (event.kind !== 'changed' || event.type !== WEB_APPLICATION_ENTITY || event.action === 'deleted') return;
      if (this.store.is(event.id)) void this.store.refresh();
    });
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      stopIdChange.unsubscribe();
      stopChanges();
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

  /**
   * Whether the fields take no input: before the read lands, and on one of OcuPilot's own
   * applications, whose every change the instance refuses (AD-10).
   */
  protected get locked(): boolean {
    this.generation();
    return !this.store.editable() || this.servesRefusal !== '';
  }

  protected get applicationName(): string {
    this.generation();
    return this.store.name();
  }

  /** The derived application type, in the create form's own words. */
  protected get typeLabel(): string {
    this.generation();
    const type = this.store.derivedType();
    if (type === DERIVED_REST) return STRINGS.webAppFormTypeRest;
    if (type === DERIVED_PYTHON) return STRINGS.webAppFormTypePython;
    return STRINGS.webAppFormTypeCsp;
  }

  protected get location(): string {
    this.generation();
    return this.store.fixedValue('WSGIAppLocation');
  }

  protected get physicalPath(): string {
    this.generation();
    return this.store.fixedValue('Path');
  }

  protected get tabs(): readonly FormTabView[] {
    this.generation();
    const counts = tabErrorCounts(WEB_APP_FIELD_TABS, this.store.violations());
    return [
      { key: GENERAL_TAB, label: STRINGS.processDetailsGroupGeneral, count: counts[GENERAL_TAB] ?? 0 },
      { key: APPLICATION_ROLES_TAB, label: STRINGS.webAppFormApplicationRoles, count: counts[APPLICATION_ROLES_TAB] ?? 0 },
      { key: MATCHING_ROLES_TAB, label: STRINGS.webAppTabMatchingRoles, count: counts[MATCHING_ROLES_TAB] ?? 0 },
      { key: CORS_TAB, label: STRINGS.webAppTabCors, count: counts[CORS_TAB] ?? 0 },
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

  /** The serving-path sentence the whole form is drawn refused with on OcuPilot's own applications. */
  protected get servesRefusal(): string {
    this.generation();
    return selfProtectionReason(SERVES_OCUPILOT_RULE, this.store.name());
  }

  protected get hasServesRefusal(): boolean {
    return this.servesRefusal !== '';
  }

  /** The privilege-grant sentence the role controls are drawn refused with there. */
  protected get rolesRefusal(): string {
    return this.ruleReason(ADD_APPLICATION_ROLE);
  }

  protected get hasRolesRefusal(): boolean {
    return this.rolesRefusal !== '';
  }

  protected get rolesBlocked(): string | null {
    return this.rolesRefusal !== '' || !this.store.editable() ? 'true' : null;
  }

  protected get rolesDescribedBy(): string | null {
    return this.rolesRefusal !== '' ? this.rolesRefusalId : null;
  }

  protected get generalFields(): readonly FieldView[] {
    this.generation();
    const repointed = this.store.repointedField();
    return GENERAL_FIELDS.map((field) => {
      let effect = '';
      if (field === AUTHE_FIELD && this.store.addsUnauthenticated()) effect = STRINGS.webAppUnauthenticatedEffect;
      if (field === 'Resource' && this.store.clearsResource()) effect = STRINGS.webAppNoResourceEffect;
      if (field === repointed) effect = STRINGS.webAppRepointedEffect;
      return this.fieldView(field, effect, '');
    });
  }

  protected get corsFields(): readonly FieldView[] {
    this.generation();
    return CORS_FIELDS.map((field) => this.fieldView(field, '', LIST_FIELDS.includes(field) ? STRINGS.webAppCorsListCaption : ''));
  }

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

  protected get matchingRoles(): readonly HeldRoleView[] {
    this.generation();
    return this.store.matchingRoles().map((entry: MatchingRole) => ({
      key: `${entry.match}:${entry.role}`,
      removeLabel: `${STRINGS.actionRemove} ${entry.match} ${entry.role}`,
      match: entry.match,
      role: entry.role,
    }));
  }

  protected get hasMatchingRoles(): boolean {
    return this.matchingRoles.length > 0;
  }

  /** Every role the instance holds, for the matching-role pickers. */
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

  protected get matchRolePicked(): string {
    return this.matchRolePick();
  }

  protected get matchTargetPicked(): string {
    return this.matchTargetPick();
  }

  protected get applicationRoleEffect(): string {
    return this.privilegeEffect(this.applicationRolePick());
  }

  protected get hasApplicationRoleEffect(): boolean {
    return this.applicationRoleEffect !== '';
  }

  protected get applicationRoleDescribedBy(): string | null {
    return this.hasApplicationRoleEffect ? `${this.applicationRoleId}-effect` : null;
  }

  protected get matchTargetEffect(): string {
    return this.privilegeEffect(this.matchTargetPick());
  }

  protected get hasMatchTargetEffect(): boolean {
    return this.matchTargetEffect !== '';
  }

  protected get matchTargetDescribedBy(): string | null {
    return this.hasMatchTargetEffect ? `${this.matchTargetId}-effect` : null;
  }

  protected get assignApplicationBlocked(): string | null {
    return this.rolesBlocked !== null || this.applicationRolePick() === '' ? 'true' : null;
  }

  protected get assignMatchingBlocked(): string | null {
    return this.rolesBlocked !== null || this.matchRolePick() === '' || this.matchTargetPick() === '' ? 'true' : null;
  }

  protected get saveBlocked(): string | null {
    this.generation();
    return this.store.canSave() && this.servesRefusal === '' ? null : 'true';
  }

  protected get saveDescribedBy(): string | null {
    return this.hasServesRefusal ? this.servesRefusalId : null;
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

  // --- intents ---------------------------------------------------------------------------------

  protected selectTab(key: string): void {
    this.selectedTab.set(key);
  }

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement || target instanceof HTMLSelectElement) this.store.setText(field, target.value);
  }

  protected onFlag(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setFlag(field, target.checked);
  }

  protected onList(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLTextAreaElement) this.store.setList(field, target.value);
  }

  protected onAuthe(bit: number, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setAuthe(bit, target.checked);
  }

  protected onBlur(field: string): void {
    this.store.onBlur(field);
  }

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

  protected onAssignApplicationRole(): void {
    if (this.assignApplicationBlocked !== null) return;
    this.start(ADD_APPLICATION_ROLE, { Role: this.applicationRolePick() });
  }

  protected onRemoveApplicationRole(role: string): void {
    if (this.rolesBlocked !== null) return;
    this.start(REMOVE_APPLICATION_ROLE, { Role: role });
  }

  protected onAssignMatchingRole(): void {
    if (this.assignMatchingBlocked !== null) return;
    this.start(ADD_MATCHING_ROLE, { MatchRole: this.matchRolePick(), Role: this.matchTargetPick() });
  }

  protected onRemoveMatchingRole(match: string, role: string): void {
    if (this.rolesBlocked !== null) return;
    this.start(REMOVE_MATCHING_ROLE, { MatchRole: match, Role: role });
  }

  protected async onSave(): Promise<void> {
    if (this.saveBlocked !== null) return;
    const saved = await this.store.save();
    if (!saved) this.afterRefusal();
  }

  /** Open the tab that holds `field`, then focus it. */
  protected focusField(field: string): void {
    const tab = WEB_APP_FIELD_TABS[field];
    if (tab !== undefined && tab !== this.selectedTab()) {
      this.selectedTab.set(tab);
      afterNextRender(() => this.focusControl(field), { injector: this.injector });
      return;
    }
    this.focusControl(field);
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(WEB_APP_LIST_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  /** The application this route names, or `''`. */
  private routeId(): string {
    const screen = screenForDescriptor(WEB_APP_FORM);
    return screen === null ? '' : ownIdSegment(screen, this.router.url);
  }

  private clearPicks(): void {
    this.applicationRolePick.set('');
    this.matchRolePick.set('');
    this.matchTargetPick.set('');
  }

  /** Start one of the Web applications list's role actions on this application (AD-53). */
  private start(actionId: string, values: Readonly<Record<string, string>>): void {
    if (!this.store.editable()) return;
    this.store.setActionRefusal('');
    this.actions.startFor(WEB_APP_LIST, actionId, this.store.name(), null, this.sink, '', values);
  }

  /** A role action was applied: the pickers clear and the application is read again. */
  private onApplied(): void {
    this.clearPicks();
    void this.store.refresh();
  }

  /**
   * The consequence a privileged role choice states (AD-10): the combined line where the
   * application is unauthenticated, as read or as the unsaved form stands, and the privilege line
   * otherwise; `''` for a role the server did not mark.
   */
  private privilegeEffect(role: string): string {
    this.generation();
    if (role === '') return '';
    const choice = this.store.roleChoices().find((option) => option.name === role);
    if (choice === undefined || !choice.privileged) return '';
    return this.store.unauthenticated() ? STRINGS.privilegedGrantEffectUnauthenticated : STRINGS.privilegedGrantEffect;
  }

  /** The sentence the Web applications list's declared rule for `actionId` explains this application with, or `''`. */
  private ruleReason(actionId: string): string {
    this.generation();
    const rule = screenForDescriptor(WEB_APP_LIST)?.rowActions.find((action) => action.id === actionId)?.selfProtection ?? '';
    return selfProtectionReason(rule, this.store.name());
  }

  /**
   * After a refused Save: the tab that holds the first refused field opens, the error summary takes
   * focus, then that field, in the order EXPERIENCE.md's `form-page` validation rule states.
   */
  private afterRefusal(): void {
    const open = tabToOpen(WEB_APP_FIELD_TABS, [...GENERAL_FIELDS, ...CORS_FIELDS, MATCH_ROLES_FIELD], this.store.violations());
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
    const order = [...GENERAL_FIELDS, ...CORS_FIELDS, MATCH_ROLES_FIELD];
    const rank = (field: string): number => (order.includes(field) ? order.indexOf(field) : order.length);
    const first = violations.reduce((best, entry) => (rank(entry.field) < rank(best.field) ? entry : best));
    this.focusControl(first.field);
  }

  private focusControl(field: string): void {
    document.getElementById(this.controlId(field))?.focus();
  }

  private fieldView(field: string, effect: string, caption: string): FieldView {
    const id = this.controlId(field);
    const reason = this.store.violationFor(field);
    const invalid = reason !== '';
    const effectId = `${id}-effect`;
    const captionId = `${id}-caption`;
    const described = [caption !== '' ? captionId : '', effect !== '' ? effectId : '', invalid ? `${id}-reason` : ''].filter((entry) => entry !== '');
    const isAuthe = field === AUTHE_FIELD;
    const isFlag = (FLAG_FIELDS as readonly string[]).includes(field);
    const isSelect = SELECT_FIELDS.includes(field);
    const isList = LIST_FIELDS.includes(field);
    const isNumber = (NUMBER_FIELDS as readonly string[]).includes(field);
    const bound = this.store.maxLength(field);
    const methods: AutheMethodView[] = isAuthe
      ? this.store.rules().authenticationMethods.map((method: AutheMethod) => ({
          bit: method.bit,
          id: `${id}-${method.bit}`,
          label: method.label,
          checked: this.store.autheChecked(method.bit),
        }))
      : [];
    const choices = field === 'WSGIType' ? this.store.rules().wsgiTypes : this.store.serveFilesChoices();
    const value = isList ? this.store.list(field) : this.store.text(field);
    return {
      field,
      id,
      label: FIELD_LABELS[field] ?? field,
      isText: !isAuthe && !isFlag && !isSelect && !isList && !isNumber,
      isNumber,
      isFlag,
      isSelect,
      isList,
      isAuthe,
      value,
      checked: isFlag ? this.store.flag(field) : false,
      options: isSelect ? (choices.includes(value) || value === '' ? choices : [value, ...choices]) : [],
      methods,
      maxLength: bound > 0 ? bound : null,
      reason,
      invalid,
      effect,
      effectId,
      hasEffect: effect !== '',
      caption,
      captionId,
      hasCaption: caption !== '',
      describedBy: described.length === 0 ? null : described.join(' '),
    };
  }

  private controlId(field: string): string {
    return `ocu-web-app-edit-${field}`;
  }
}
