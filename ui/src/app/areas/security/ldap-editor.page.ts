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
import { encodeEntityId } from '../../core/entity-id';
import { tabErrorCounts, tabToOpen } from '../../core/form-tabs';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService, formatRequires, ownIdSegment, screenForDescriptor, withQuery } from '../../core/navigation';
import { savedLine } from '../../core/read-back';
import { STRINGS } from '../../core/strings';
import { STATE_CONFLICT_CODE, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { FormTabBody, FormTabs, type FormTabView } from '../../shell/form-tabs';
import {
  ADVANCED_FIELDS,
  ATTRIBUTES_FIELD,
  ATTRIBUTES_TAB,
  AUTHORIZATION_FIELDS,
  BASE_DN_FIELD,
  DESCRIPTION_FIELD,
  FIELD_ORDER,
  FLAG_ACTIVE_DIRECTORY,
  FLAG_ALLOW_ENV,
  FLAG_ENABLED,
  FLAG_GROUPS,
  FLAG_NESTED,
  FLAG_TLS,
  FLAG_UNIVERSAL,
  FLAGS_FIELD,
  GENERAL_TAB,
  GROUPS_BASE_DN_FIELD,
  GROUPS_TAB,
  HOSTS_FIELD,
  LDAP_ENTITY,
  LDAP_FIELD_TABS,
  LdapEditor,
  NAME_FIELD,
  ORGANIZATION_FIELD,
  PASSWORD_FIELD,
  type PasswordMode,
  USER_FIELD,
} from './ldap-editor.store';
import { LdapTestDialog } from './ldap-test-dialog';

/** The editor's descriptor, whose bare and id routes this page serves. */
export const LDAP_FORM = 'OcuPilot.Screen.Descriptor.LdapConfigForm';

/** The list the editor is reached from, which Cancel returns to. */
export const LDAP_LIST_ROUTE = 'security/ldap';

/** This editor's own route, the fallback when the mirror cannot resolve it from the URL. */
export const LDAP_FORM_ROUTE = 'security/ldap/edit';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** The placeholder the refused-password line leaves for the instance's sentence. */
const REASON_PLACEHOLDER = '<reason>';

/** One settable text field, resolved for drawing. */
interface FieldView {
  readonly field: string;
  readonly id: string;
  readonly label: string;
  readonly value: string;
  readonly disabled: boolean;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/** One flag checkbox, resolved for drawing. A refused `LDAPFlags` is drawn under LDAP enabled. */
interface FlagView {
  readonly bit: number;
  readonly id: string;
  readonly label: string;
  readonly checked: boolean;
  readonly disabled: boolean;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/** One entry of the host or attribute list, with its Remove button's name. */
interface EntryView {
  readonly key: string;
  readonly index: number;
  readonly text: string;
  readonly removeLabel: string;
}

/** One read-only example block, with its label. */
interface ExampleView {
  readonly id: string;
  readonly label: string;
  readonly text: string;
}

/** The search password's three options, in the order they are drawn. */
const PASSWORD_MODES: readonly { readonly value: PasswordMode; readonly label: string }[] = [
  { value: 'leave', label: STRINGS.ldapPasswordLeave },
  { value: 'enter', label: STRINGS.ldapPasswordEnter },
  { value: 'clear', label: STRINGS.ldapPasswordClear },
];

/** The labels of the text settings, by field. */
const LABELS: Readonly<Record<string, string>> = {
  [DESCRIPTION_FIELD]: STRINGS.tableColumnDescription,
  [USER_FIELD]: STRINGS.ldapFieldSearchUsername,
  [BASE_DN_FIELD]: STRINGS.ldapFieldBaseDn,
  [GROUPS_BASE_DN_FIELD]: STRINGS.ldapFieldBaseDnGroups,
  LDAPUniqueDNIdentifier: STRINGS.ldapFieldUniqueAttribute,
  LDAPServerTimeout: STRINGS.ldapFieldServerTimeout,
  LDAPClientTimeout: STRINGS.ldapFieldClientTimeout,
  [ORGANIZATION_FIELD]: STRINGS.ldapFieldOrganizationId,
  GroupId: STRINGS.ldapFieldGroupId,
  InstanceId: STRINGS.ldapFieldInstanceId,
  RoleId: STRINGS.ldapFieldRoleId,
  EscalationRoleId: STRINGS.ldapFieldEscalationRoleId,
  NamespaceId: STRINGS.ldapFieldNamespaceId,
  RoutineId: STRINGS.ldapFieldRoutineId,
  DelimiterId: STRINGS.ldapFieldDelimiterId,
  LDAPGroupId: STRINGS.ldapFieldLdapGroupId,
  LDAPInstanceId: STRINGS.ldapFieldLdapInstanceId,
  LDAPAttributeNameSpace: STRINGS.ldapAttributeNamespace,
  LDAPAttributeRoutine: STRINGS.ldapAttributeRoutine,
  LDAPAttributeRoles: STRINGS.ldapAttributeRoles,
  LDAPAttributeEscalationRoles: STRINGS.ldapAttributeEscalationRoles,
  LDAPAttributeComment: STRINGS.ldapAttributeComment,
  LDAPAttributeFullName: STRINGS.ldapAttributeFullName,
  LDAPAttributeMail: STRINGS.ldapAttributeMail,
  LDAPAttributeMobile: STRINGS.ldapAttributeMobile,
  LDAPAttributeMobileProvider: STRINGS.ldapAttributeMobileProvider,
};

/** The General tab's text settings after the password, in the classic order. */
const GENERAL_LOWER_FIELDS: readonly string[] = [BASE_DN_FIELD, GROUPS_BASE_DN_FIELD, 'LDAPUniqueDNIdentifier', 'LDAPServerTimeout', 'LDAPClientTimeout'];

/** The nine user attributes, in the classic order. */
const ATTRIBUTE_TEXT_FIELDS: readonly string[] = [
  'LDAPAttributeNameSpace',
  'LDAPAttributeRoutine',
  'LDAPAttributeRoles',
  'LDAPAttributeEscalationRoles',
  'LDAPAttributeComment',
  'LDAPAttributeFullName',
  'LDAPAttributeMail',
  'LDAPAttributeMobile',
  'LDAPAttributeMobileProvider',
];

/**
 * The LDAP and Kerberos editor, a tabbed `form-page` that creates a configuration on
 * `security/ldap/edit` and edits one on `security/ldap/edit/<name>` (Story 16.14, FR-45, AD-55).
 *
 * **Its tabs cut the classic page `%CSP.UI.Portal.LDAP` at its own captions** -- General, Groups and
 * Attributes -- and keep its order. One Save applies every tab; a refused Save opens the tab holding
 * its first refused field, whose accessible name then counts them, and focuses the error summary,
 * then that field.
 *
 * **The Kerberos pair** is drawn where the instance's Kerberos authentication is on, or the
 * configuration is already Kerberos-only: Kerberos configuration checked and unavailable, and LDAP
 * configuration, unticking which draws only the name, the description and the pair.
 *
 * **The flags couple as on the classic page**: the Groups tab's fields take input only while Use
 * LDAP groups is ticked, the four role, namespace and routine attributes only while it is not, and
 * Search nested groups only while Active Directory server is ticked too. The CA certificate file is
 * shown and never set (AD-21).
 *
 * **The search password is a choice of three** -- Leave as is, Enter a new password (with Confirm
 * password), Clear the password -- and is never read (AD-35). **Test authentication** opens a dialog
 * on a saved configuration with no unsaved change, which shows the instance's own lines as text
 * (AD-39). It links out to no classic page.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-ldap-editor-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, FormTabs, FormTabBody, LdapTestDialog],
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
    @if (absentFlag) {
      <p class="ocu-banner ocu-banner-warning" role="status">{{ STRINGS.ldapGone }}</p>
    }
    @if (hasSecretsRefused) {
      <p class="ocu-banner ocu-banner-warning" role="status">{{ secretsRefusedText }}</p>
    }

    @if (heldFlag) {
      <p class="ocu-form-legend">{{ STRINGS.formRequiredFieldsLegend }}</p>
      <app-form-tabs [tabs]="tabs" [selected]="selectedTab()" (selectedChange)="selectTab($event)">
        <ng-template ocuFormTab="general">
          <div class="ocu-form-fields">
            @if (creating) {
              <div class="ocu-field">
                <label class="ocu-field-label ocu-field-label-required" [attr.for]="nameField.id">{{ STRINGS.tableColumnName }}</label>
                <div class="ocu-field-control">
                  <input
                    class="ocu-field-input"
                    type="text"
                    autocomplete="off"
                    spellcheck="false"
                    [id]="nameField.id"
                    [value]="nameField.value"
                    aria-required="true"
                    [attr.aria-invalid]="nameField.invalid"
                    [attr.aria-describedby]="nameField.describedBy"
                    (input)="onName($event)"
                    (blur)="onNameBlur()"
                  />
                </div>
                @if (nameField.invalid) {
                  <p class="ocu-form-error" [id]="nameField.id + '-reason'">{{ nameField.reason }}</p>
                }
              </div>
              @if (ldapShown) {
                <div class="ocu-field">
                  <label class="ocu-field-label" [attr.for]="copyId">{{ STRINGS.ldapFieldCopyFrom }}</label>
                  <div class="ocu-field-control">
                    <select class="ocu-field-input" [id]="copyId" (change)="onCopy($event)">
                      <option value="" [selected]="copiedFrom === ''">{{ STRINGS.sslVerifyPeerNone }}</option>
                      @for (option of copyOptions; track option) {
                        <option [value]="option" [selected]="option === copiedFrom">{{ option }}</option>
                      }
                    </select>
                  </div>
                </div>
              }
            } @else {
              <div class="ocu-field">
                <label class="ocu-field-label" [attr.for]="nameField.id">{{ STRINGS.tableColumnName }}</label>
                <input class="ocu-field-input" type="text" readonly [id]="nameField.id" [value]="nameField.value" />
              </div>
            }
            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="descriptionField.id">{{ descriptionField.label }}</label>
              <div class="ocu-field-control">
                <input
                  class="ocu-field-input"
                  type="text"
                  [id]="descriptionField.id"
                  [value]="descriptionField.value"
                  [attr.aria-invalid]="descriptionField.invalid"
                  [attr.aria-describedby]="descriptionField.describedBy"
                  (input)="onText(descriptionField.field, $event)"
                />
              </div>
              @if (descriptionField.invalid) {
                <p class="ocu-form-error" [id]="descriptionField.id + '-reason'">{{ descriptionField.reason }}</p>
              }
            </div>
            @if (kerberosPair) {
              <div class="ocu-field">
                <label class="ocu-field-checkbox">
                  <input type="checkbox" [id]="kerberosId" checked disabled />
                  <span>{{ STRINGS.ldapFieldKerberos }}</span>
                </label>
              </div>
              <div class="ocu-field">
                <label class="ocu-field-checkbox">
                  <input type="checkbox" [id]="ldapConfigurationId" [checked]="ldapConfiguration" (change)="onLdapConfiguration($event)" />
                  <span>{{ STRINGS.ldapFormLabel }}</span>
                </label>
              </div>
            }
            @if (ldapShown) {
              @for (view of generalFlags; track view.bit) {
                <div class="ocu-field">
                  <label class="ocu-field-checkbox">
                    <input
                      type="checkbox"
                      [id]="view.id"
                      [checked]="view.checked"
                      [attr.aria-invalid]="view.invalid"
                      [attr.aria-describedby]="view.describedBy"
                      (change)="onFlag(view.bit, $event)"
                    />
                    <span>{{ view.label }}</span>
                  </label>
                  @if (view.invalid) {
                    <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
                  }
                </div>
              }
              <div class="ocu-field">
                <p class="ocu-field-label ocu-field-label-required" [id]="hostsId + '-label'">{{ STRINGS.ldapFieldHostNames }}</p>
                @if (hasHosts) {
                  <ul class="ocu-form-roles" [attr.aria-labelledby]="hostsId + '-label'">
                    @for (item of hostViews; track item.key) {
                      <li class="ocu-form-role">
                        <span class="ocu-form-role-name">{{ item.text }}</span>
                        <button type="button" class="ocu-button-text" data-action="remove-host" [attr.aria-label]="item.removeLabel" (click)="onRemove(hostsField, item.index)">
                          {{ STRINGS.actionRemove }}
                        </button>
                      </li>
                    }
                  </ul>
                }
                <label class="ocu-field-label" [attr.for]="hostsId">{{ STRINGS.ldapHostField }}</label>
                <div class="ocu-field-control">
                  <input
                    #hostInput
                    class="ocu-field-input"
                    type="text"
                    spellcheck="false"
                    [id]="hostsId"
                    [attr.aria-invalid]="hostsInvalid"
                    [attr.aria-describedby]="hostsDescribedBy"
                    (keydown.enter)="onAdd(hostsField, hostInput)"
                  />
                </div>
                <button type="button" class="ocu-button-text" data-action="add-host" (click)="onAdd(hostsField, hostInput)">
                  {{ STRINGS.ldapHostAdd }}
                </button>
                <p class="ocu-field-caption" [id]="hostsId + '-caption'">{{ STRINGS.ldapHostCaption }}</p>
                @if (hostsInvalid) {
                  <p class="ocu-form-error" [id]="hostsId + '-reason'">{{ hostsReason }}</p>
                }
              </div>
              <div class="ocu-field">
                <label class="ocu-field-label ocu-field-label-required" [attr.for]="userField.id">{{ userField.label }}</label>
                <div class="ocu-field-control">
                  <input
                    class="ocu-field-input"
                    type="text"
                    autocomplete="off"
                    spellcheck="false"
                    [id]="userField.id"
                    [value]="userField.value"
                    aria-required="true"
                    [attr.aria-invalid]="userField.invalid"
                    [attr.aria-describedby]="userField.describedBy"
                    (input)="onText(userField.field, $event)"
                  />
                </div>
                @if (userField.invalid) {
                  <p class="ocu-form-error" [id]="userField.id + '-reason'">{{ userField.reason }}</p>
                }
              </div>
              <fieldset class="ocu-field ocu-form-authe" [attr.id]="passwordGroupId" tabindex="-1" [attr.aria-describedby]="passwordDescribedBy">
                <legend class="ocu-field-label">{{ STRINGS.ldapFieldSearchPassword }}</legend>
                @for (choice of passwordModes; track choice.value) {
                  <label class="ocu-field-checkbox">
                    <input
                      type="radio"
                      name="ocu-ldap-password-mode"
                      [id]="passwordGroupId + '-' + choice.value"
                      [value]="choice.value"
                      [checked]="choice.value === passwordMode"
                      (change)="onPasswordMode(choice.value)"
                    />
                    <span>{{ choice.label }}</span>
                  </label>
                }
                @if (enteringPassword) {
                  <div class="ocu-field">
                    <label class="ocu-field-label" [attr.for]="passwordId">{{ STRINGS.fieldPassword }}</label>
                    <div class="ocu-field-control">
                      <input
                        class="ocu-field-input"
                        type="password"
                        autocomplete="new-password"
                        [id]="passwordId"
                        [value]="passwordValue"
                        [attr.aria-invalid]="passwordInvalid"
                        (input)="onPassword($event)"
                      />
                    </div>
                  </div>
                  <div class="ocu-field">
                    <label class="ocu-field-label" [attr.for]="confirmId">{{ STRINGS.ldapFieldPasswordConfirm }}</label>
                    <div class="ocu-field-control">
                      <input
                        class="ocu-field-input"
                        type="password"
                        autocomplete="new-password"
                        [id]="confirmId"
                        [value]="confirmValue"
                        [attr.aria-invalid]="passwordInvalid"
                        (input)="onConfirm($event)"
                      />
                    </div>
                  </div>
                }
                @if (passwordInvalid) {
                  <p class="ocu-form-error" [id]="passwordGroupId + '-reason'">{{ passwordReason }}</p>
                }
              </fieldset>
              @for (view of generalLowerFields; track view.field) {
                <div class="ocu-field">
                  <label class="ocu-field-label ocu-field-label-required" [attr.for]="view.id">{{ view.label }}</label>
                  <div class="ocu-field-control">
                    <input
                      class="ocu-field-input"
                      type="text"
                      spellcheck="false"
                      [id]="view.id"
                      [value]="view.value"
                      aria-required="true"
                      [attr.aria-invalid]="view.invalid"
                      [attr.aria-describedby]="view.describedBy"
                      (input)="onText(view.field, $event)"
                    />
                  </div>
                  @if (view.invalid) {
                    <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
                  }
                </div>
              }
              <div class="ocu-field">
                <label class="ocu-field-checkbox">
                  <input type="checkbox" [id]="tlsFlag.id" [checked]="tlsFlag.checked" (change)="onFlag(tlsFlag.bit, $event)" />
                  <span>{{ tlsFlag.label }}</span>
                </label>
              </div>
              <div class="ocu-field">
                <label class="ocu-field-label" [attr.for]="caFileId">{{ STRINGS.ldapFieldCaFile }}</label>
                <input class="ocu-field-input" type="text" readonly [id]="caFileId" [value]="caFile" />
              </div>
              <div class="ocu-field">
                <label class="ocu-field-checkbox">
                  <input type="checkbox" [id]="envFlag.id" [checked]="envFlag.checked" (change)="onFlag(envFlag.bit, $event)" />
                  <span>{{ envFlag.label }}</span>
                </label>
              </div>
            }
          </div>
        </ng-template>
        <ng-template ocuFormTab="groups">
          <div class="ocu-form-fields">
            @for (view of groupFlags; track view.bit) {
              <div class="ocu-field">
                <label class="ocu-field-checkbox">
                  <input type="checkbox" [id]="view.id" [checked]="view.checked" [disabled]="view.disabled" (change)="onFlag(view.bit, $event)" />
                  <span>{{ view.label }}</span>
                </label>
              </div>
            }
            <div class="ocu-field">
              <label class="ocu-field-label ocu-field-label-required" [attr.for]="organizationField.id">{{ organizationField.label }}</label>
              <div class="ocu-field-control">
                <input
                  class="ocu-field-input"
                  type="text"
                  spellcheck="false"
                  aria-required="true"
                  [id]="organizationField.id"
                  [value]="organizationField.value"
                  [disabled]="organizationField.disabled"
                  [attr.aria-invalid]="organizationField.invalid"
                  [attr.aria-describedby]="organizationField.describedBy"
                  (input)="onText(organizationField.field, $event)"
                  (change)="onGroupInput()"
                />
              </div>
              @if (organizationField.invalid) {
                <p class="ocu-form-error" [id]="organizationField.id + '-reason'">{{ organizationField.reason }}</p>
              }
            </div>
            <div class="ocu-form-advanced">
              <button
                type="button"
                class="ocu-form-disclosure"
                [attr.aria-expanded]="advanced()"
                [attr.aria-controls]="advancedId"
                (click)="toggleAdvanced()"
              >
                {{ STRINGS.agentDefinitionAdvanced }}
              </button>
              @if (advancedShown) {
                <div class="ocu-form-fields" [id]="advancedId">
                  @for (view of advancedFields; track view.field) {
                    <div class="ocu-field">
                      <label class="ocu-field-label ocu-field-label-required" [attr.for]="view.id">{{ view.label }}</label>
                      <div class="ocu-field-control">
                        <input
                          class="ocu-field-input"
                          type="text"
                          spellcheck="false"
                          [id]="view.id"
                          [value]="view.value"
                          [disabled]="view.disabled"
                          aria-required="true"
                          [attr.aria-invalid]="view.invalid"
                          [attr.aria-describedby]="view.describedBy"
                          (input)="onText(view.field, $event)"
                          (change)="onGroupInput()"
                        />
                      </div>
                      @if (view.invalid) {
                        <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
                      }
                    </div>
                  }
                </div>
              }
            </div>
            <div class="ocu-field">
              <label class="ocu-field-checkbox">
                <input
                  type="checkbox"
                  [id]="universalFlag.id"
                  [checked]="universalFlag.checked"
                  [disabled]="universalFlag.disabled"
                  (change)="onFlag(universalFlag.bit, $event)"
                />
                <span>{{ universalFlag.label }}</span>
              </label>
            </div>
            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="universalExample.id">{{ universalExample.label }}</label>
              <textarea class="ocu-field-input ocu-field-textarea ocu-ldap-example" rows="4" readonly [id]="universalExample.id" [value]="universalExample.text"></textarea>
            </div>
            @for (view of authorizationFields; track view.field; let index = $index) {
              <div class="ocu-field">
                <label class="ocu-field-label" [attr.for]="view.id">{{ view.label }}</label>
                <div class="ocu-field-control">
                  <input
                    class="ocu-field-input"
                    type="text"
                    spellcheck="false"
                    [id]="view.id"
                    [value]="view.value"
                    [disabled]="view.disabled"
                    [attr.aria-invalid]="view.invalid"
                    [attr.aria-describedby]="view.describedBy"
                    (input)="onText(view.field, $event)"
                    (change)="onGroupInput()"
                  />
                </div>
                @if (view.invalid) {
                  <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
                }
              </div>
              <div class="ocu-field">
                <label class="ocu-field-label" [attr.for]="authorizationExamples[index].id">{{ authorizationExamples[index].label }}</label>
                <textarea
                  class="ocu-field-input ocu-field-textarea ocu-ldap-example"
                  rows="4"
                  readonly
                  [id]="authorizationExamples[index].id"
                  [value]="authorizationExamples[index].text"
                ></textarea>
              </div>
            }
          </div>
        </ng-template>
        <ng-template ocuFormTab="attributes">
          <div class="ocu-form-fields">
            @for (view of attributeFields; track view.field) {
              <div class="ocu-field">
                <label class="ocu-field-label" [attr.for]="view.id">{{ view.label }}</label>
                <div class="ocu-field-control">
                  <input
                    class="ocu-field-input"
                    type="text"
                    spellcheck="false"
                    [id]="view.id"
                    [value]="view.value"
                    [disabled]="view.disabled"
                    [attr.aria-invalid]="view.invalid"
                    [attr.aria-describedby]="view.describedBy"
                    (input)="onText(view.field, $event)"
                  />
                </div>
                @if (view.invalid) {
                  <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
                }
              </div>
            }
            <div class="ocu-field">
              <p class="ocu-field-label" [id]="attributesId + '-label'">{{ STRINGS.ldapFieldAttributes }}</p>
              @if (hasAttributes) {
                <ul class="ocu-form-roles" [attr.aria-labelledby]="attributesId + '-label'">
                  @for (item of attributeViews; track item.key) {
                    <li class="ocu-form-role">
                      <span class="ocu-form-role-name">{{ item.text }}</span>
                      <button type="button" class="ocu-button-text" data-action="remove-attribute" [attr.aria-label]="item.removeLabel" (click)="onRemove(attributesField, item.index)">
                        {{ STRINGS.actionRemove }}
                      </button>
                    </li>
                  }
                </ul>
              }
              <label class="ocu-field-label" [attr.for]="attributesId">{{ STRINGS.ldapAttributeField }}</label>
              <div class="ocu-field-control">
                <input
                  #attributeInput
                  class="ocu-field-input"
                  type="text"
                  spellcheck="false"
                  [id]="attributesId"
                  [attr.aria-invalid]="attributesInvalid"
                  [attr.aria-describedby]="attributesDescribedBy"
                  (keydown.enter)="onAdd(attributesField, attributeInput)"
                />
              </div>
              <button type="button" class="ocu-button-text" data-action="add-attribute" (click)="onAdd(attributesField, attributeInput)">
                {{ STRINGS.ldapAttributeAdd }}
              </button>
              @if (attributesInvalid) {
                <p class="ocu-form-error" [id]="attributesId + '-reason'">{{ attributesReason }}</p>
              }
            </div>
          </div>
        </ng-template>
      </app-form-tabs>

      @if (editing) {
        <div class="ocu-ldap-test">
          <button
            type="button"
            class="ocu-button-secondary"
            data-action="ldap-test"
            [attr.aria-disabled]="testBlocked"
            [attr.aria-describedby]="testDescribedBy"
            (click)="openTest()"
          >
            {{ STRINGS.ldapTestAction }}
          </button>
          @if (testWaitsForSave) {
            <p class="ocu-field-caption" [id]="testCaptionId">{{ STRINGS.ldapTestSaveFirst }}</p>
          }
        </div>
      }

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

    @if (testShown) {
      <app-ldap-test-dialog (closed)="closeTest()" />
    }

    @if (leavePending) {
      <app-dialog [heading]="STRINGS.formLeaveWithoutSaving" [closeLabel]="STRINGS.actionCancel" (closed)="answerLeave(false)">
        <button dialogAction type="button" class="ocu-button-primary" (click)="answerLeave(true)">
          {{ STRINGS.actionConfirm }}
        </button>
      </app-dialog>
    }
  </section>`,
})
export class LdapEditorPage {
  private readonly store = inject(LdapEditor);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  protected readonly passwordModes = PASSWORD_MODES;
  protected readonly hostsField = HOSTS_FIELD;
  protected readonly attributesField = ATTRIBUTES_FIELD;

  protected readonly copyId = 'ocu-ldap-copy-from';
  protected readonly kerberosId = 'ocu-ldap-kerberos';
  protected readonly ldapConfigurationId = 'ocu-ldap-ldap-configuration';
  protected readonly hostsId = this.controlId(HOSTS_FIELD);
  protected readonly attributesId = this.controlId(ATTRIBUTES_FIELD);
  protected readonly passwordGroupId = this.controlId(PASSWORD_FIELD);
  protected readonly passwordId = 'ocu-ldap-password';
  protected readonly confirmId = 'ocu-ldap-password-confirm';
  protected readonly caFileId = 'ocu-ldap-LDAPCACertFile';
  protected readonly advancedId = 'ocu-ldap-advanced';
  protected readonly testCaptionId = 'ocu-ldap-test-caption';

  /** The key of the tab on screen. */
  protected readonly selectedTab = signal(GENERAL_TAB);

  /** Whether the Advanced disclosure is open. */
  protected readonly advanced = signal(false);

  /** Whether the Test authentication dialog is open. */
  protected readonly testOpen = signal(false);

  /** Bumped by the store and the dirty flag, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  /** Whether the summary has been focused for the refusal now on screen. */
  private focusedSummary = false;

  constructor() {
    const stopStore = this.store.subscribe(() => this.bump());
    const stopDirty = this.formDirty.subscribe(() => this.bump());
    let followed = this.routeId();
    void this.store.open(followed);
    // One id route to another reuses this page, so the editor follows the id, not the page's life.
    const stopIdChange = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      const id = this.routeId();
      if (id === followed) return;
      followed = id;
      this.selectedTab.set(GENERAL_TAB);
      this.testOpen.set(false);
      void this.store.open(id);
    });
    // AD-14: a change to this configuration, from either caller, re-reads it; a delete is the list's.
    const stopChanges = this.injector.get(ChangeBus).subscribe((event) => {
      if (event.kind !== 'changed' || event.type !== LDAP_ENTITY || event.action === 'deleted') return;
      if (this.store.is(event.id)) void this.store.refresh();
    });
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      stopIdChange.unsubscribe();
      stopChanges();
      // Kept across a create's own route replacement, which destroys this page and builds it again
      // over the new configuration; torn down, passwords first, on every other departure.
      if (!this.store.retaining()) this.store.reset();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get heldFlag(): boolean {
    this.generation();
    return this.store.loaded() && this.store.held() && !this.store.absent();
  }

  protected get absentFlag(): boolean {
    this.generation();
    return this.store.absent();
  }

  protected get creating(): boolean {
    this.generation();
    return this.store.mode() === 'create';
  }

  protected get editing(): boolean {
    return !this.creating;
  }

  /** The tabs the form draws, each counting its refusals: General alone while Kerberos-only. */
  protected get tabs(): readonly FormTabView[] {
    this.generation();
    const counts = tabErrorCounts(LDAP_FIELD_TABS, this.store.violations());
    const tabs: FormTabView[] = [{ key: GENERAL_TAB, label: STRINGS.processDetailsGroupGeneral, count: counts[GENERAL_TAB] ?? 0 }];
    if (!this.store.kerberosOnly()) {
      tabs.push({ key: GROUPS_TAB, label: STRINGS.ldapTabGroups, count: counts[GROUPS_TAB] ?? 0 });
      tabs.push({ key: ATTRIBUTES_TAB, label: STRINGS.ldapTabAttributes, count: counts[ATTRIBUTES_TAB] ?? 0 });
    }
    return tabs;
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
   * reason. An absent configuration reads its own sentence instead.
   */
  protected get reason(): string {
    this.generation();
    if (this.store.absent()) return '';
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') return formatRequires(STRINGS.privilegeRequiresResource, pair);
    if (this.store.refusalCode() === STATE_CONFLICT_CODE) return STRINGS.formStaleSave;
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get secretsRefusedText(): string {
    this.generation();
    const refused = this.store.secretsRefused();
    return refused === '' ? '' : STRINGS.ldapPasswordRefused.split(REASON_PLACEHOLDER).join(refused);
  }

  protected get hasSecretsRefused(): boolean {
    return this.secretsRefusedText !== '';
  }

  protected get nameField(): FieldView {
    this.generation();
    return this.view(NAME_FIELD, STRINGS.tableColumnName, this.store.name(), false);
  }

  protected get copyOptions(): readonly string[] {
    this.generation();
    return this.store.copyOptions();
  }

  protected get copiedFrom(): string {
    this.generation();
    return this.store.copiedFrom();
  }

  protected get descriptionField(): FieldView {
    return this.textView(DESCRIPTION_FIELD);
  }

  /** Whether the Kerberos pair is drawn: where Kerberos is on, or the configuration is Kerberos-only. */
  protected get kerberosPair(): boolean {
    this.generation();
    return this.store.kerberos() || this.store.kerberosOnly();
  }

  protected get ldapConfiguration(): boolean {
    this.generation();
    return !this.store.kerberosOnly();
  }

  /** Whether the LDAP settings are drawn: on every configuration that is not Kerberos-only. */
  protected get ldapShown(): boolean {
    return this.ldapConfiguration;
  }

  protected get generalFlags(): readonly FlagView[] {
    return [this.flagView(FLAG_ENABLED, STRINGS.ldapFieldEnabled), this.flagView(FLAG_ACTIVE_DIRECTORY, STRINGS.ldapFieldActiveDirectory)];
  }

  protected get tlsFlag(): FlagView {
    return this.flagView(FLAG_TLS, STRINGS.ldapFieldTls);
  }

  protected get envFlag(): FlagView {
    return this.flagView(FLAG_ALLOW_ENV, STRINGS.ldapFieldAllowEnv);
  }

  protected get groupFlags(): readonly FlagView[] {
    this.generation();
    return [
      this.flagView(FLAG_GROUPS, STRINGS.ldapFieldUseGroups),
      this.flagView(FLAG_NESTED, STRINGS.ldapFieldNestedGroups, !this.store.nestedEnabled()),
    ];
  }

  protected get universalFlag(): FlagView {
    this.generation();
    return this.flagView(FLAG_UNIVERSAL, STRINGS.ldapFieldUniversalGroups, !this.store.groupsEnabled());
  }

  protected get hostViews(): readonly EntryView[] {
    this.generation();
    return this.entries(this.store.hosts());
  }

  protected get hasHosts(): boolean {
    return this.hostViews.length > 0;
  }

  protected get hostsReason(): string {
    this.generation();
    return this.store.violationFor(HOSTS_FIELD);
  }

  protected get hostsInvalid(): boolean {
    return this.hostsReason !== '';
  }

  protected get hostsDescribedBy(): string | null {
    return this.joined([`${this.hostsId}-caption`, this.hostsInvalid ? `${this.hostsId}-reason` : '']);
  }

  protected get userField(): FieldView {
    return this.textView(USER_FIELD);
  }

  protected get passwordMode(): PasswordMode {
    this.generation();
    return this.store.passwordMode();
  }

  protected get enteringPassword(): boolean {
    return this.passwordMode === 'enter';
  }

  protected get passwordValue(): string {
    this.generation();
    return this.store.password();
  }

  protected get confirmValue(): string {
    this.generation();
    return this.store.confirm();
  }

  protected get passwordReason(): string {
    this.generation();
    return this.store.violationFor(PASSWORD_FIELD);
  }

  protected get passwordInvalid(): boolean {
    return this.passwordReason !== '';
  }

  protected get passwordDescribedBy(): string | null {
    return this.passwordInvalid ? `${this.passwordGroupId}-reason` : null;
  }

  protected get generalLowerFields(): readonly FieldView[] {
    return GENERAL_LOWER_FIELDS.map((field) => this.textView(field));
  }

  protected get caFile(): string {
    this.generation();
    return this.store.caFile();
  }

  protected get organizationField(): FieldView {
    return this.textView(ORGANIZATION_FIELD, !this.groupInputs);
  }

  protected get advancedShown(): boolean {
    return this.advanced();
  }

  protected get advancedFields(): readonly FieldView[] {
    return ADVANCED_FIELDS.map((field) => this.textView(field, !this.groupInputs));
  }

  protected get authorizationFields(): readonly FieldView[] {
    return AUTHORIZATION_FIELDS.map((field) => this.textView(field, !this.groupInputs));
  }

  protected get universalExample(): ExampleView {
    this.generation();
    return { id: 'ocu-ldap-example-universal', label: STRINGS.ldapExampleUniversal, text: this.store.examples().universal };
  }

  /** The examples drawn after Authorization group ID and Authorization instance ID, in that order. */
  protected get authorizationExamples(): readonly ExampleView[] {
    this.generation();
    const examples = this.store.examples();
    return [
      { id: 'ocu-ldap-example-group', label: STRINGS.ldapExampleGroup, text: examples.group },
      { id: 'ocu-ldap-example-instance', label: STRINGS.ldapExampleInstance, text: examples.instance },
    ];
  }

  protected get attributeFields(): readonly FieldView[] {
    this.generation();
    return ATTRIBUTE_TEXT_FIELDS.map((field) => this.textView(field, !this.store.attributeEnabled(field)));
  }

  protected get attributeViews(): readonly EntryView[] {
    this.generation();
    return this.entries(this.store.attributes());
  }

  protected get hasAttributes(): boolean {
    return this.attributeViews.length > 0;
  }

  protected get attributesReason(): string {
    this.generation();
    return this.store.violationFor(ATTRIBUTES_FIELD);
  }

  protected get attributesInvalid(): boolean {
    return this.attributesReason !== '';
  }

  protected get attributesDescribedBy(): string | null {
    return this.attributesInvalid ? `${this.attributesId}-reason` : null;
  }

  /** Whether Test authentication waits for a Save: while the form holds unsaved changes. */
  protected get testWaitsForSave(): boolean {
    this.generation();
    return this.formDirty.dirty();
  }

  protected get testBlocked(): string | null {
    this.generation();
    return this.store.canTest() ? null : 'true';
  }

  protected get testShown(): boolean {
    return this.testOpen();
  }

  protected get testDescribedBy(): string | null {
    return this.testWaitsForSave ? this.testCaptionId : null;
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

  // --- intents ---------------------------------------------------------------------------------

  protected selectTab(key: string): void {
    this.selectedTab.set(key);
  }

  protected onName(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setName(target.value);
  }

  protected onNameBlur(): void {
    void this.store.checkName();
  }

  protected onCopy(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLSelectElement && target.value !== '') void this.store.copyFrom(target.value);
  }

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setText(field, target.value);
  }

  /** A committed change to a group input reads the three examples again. */
  protected onGroupInput(): void {
    void this.store.readExamples();
  }

  protected onFlag(bit: number, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setFlag(bit, target.checked);
  }

  protected onLdapConfiguration(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement)) return;
    this.store.setLdapConfiguration(target.checked);
    if (!target.checked) this.selectedTab.set(GENERAL_TAB);
  }

  protected onAdd(field: typeof HOSTS_FIELD | typeof ATTRIBUTES_FIELD, input: HTMLInputElement): void {
    if (this.store.addEntry(field, input.value)) input.value = '';
  }

  protected onRemove(field: typeof HOSTS_FIELD | typeof ATTRIBUTES_FIELD, index: number): void {
    this.store.removeEntry(field, index);
  }

  protected onPasswordMode(mode: PasswordMode): void {
    this.store.setPasswordMode(mode);
  }

  protected onPassword(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setPassword(target.value);
  }

  protected onConfirm(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setConfirm(target.value);
  }

  protected toggleAdvanced(): void {
    this.advanced.update((open) => !open);
  }

  protected openTest(): void {
    if (!this.store.canTest()) return;
    this.testOpen.set(true);
  }

  protected closeTest(): void {
    this.testOpen.set(false);
  }

  protected async onSave(): Promise<void> {
    if (!this.store.canSave()) return;
    const creating = this.store.mode() === 'create';
    const saved = await this.store.save();
    if (!saved) {
      this.afterRefusal();
      return;
    }
    // A create replaces the route with the new configuration's URL, so the address bar names the
    // entity and Back goes to the list; the page is built again there over its edit.
    if (creating && this.store.createdId() !== '') {
      this.store.retainAcrossRouteReplacement();
      void this.router.navigateByUrl(this.editorUrl(this.store.createdId()), { replaceUrl: true });
    }
  }

  /** Open the tab that holds `field`, and the Advanced disclosure where it lives there, then focus it. */
  protected focusField(field: string): void {
    const tab = LDAP_FIELD_TABS[field] ?? GENERAL_TAB;
    const opening = ADVANCED_FIELDS.includes(field) && !this.advanced();
    if (opening) this.advanced.set(true);
    if (tab !== this.selectedTab() || opening) {
      this.selectedTab.set(tab);
      afterNextRender(() => this.focusControl(field), { injector: this.injector });
      return;
    }
    this.focusControl(field);
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(LDAP_LIST_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  private get groupInputs(): boolean {
    this.generation();
    return this.store.groupsEnabled();
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  /** The configuration this route names, or `''` for the create. */
  private routeId(): string {
    const screen = screenForDescriptor(LDAP_FORM);
    return screen === null ? '' : ownIdSegment(screen, this.router.url);
  }

  /**
   * After a refused Save: the tab that holds the first refused field opens, the error summary takes
   * focus, then that field, in the order EXPERIENCE.md's `form-page` validation rule states.
   */
  private afterRefusal(): void {
    const violations = this.store.violations();
    const open = tabToOpen(LDAP_FIELD_TABS, FIELD_ORDER, violations);
    if (open !== null) this.selectedTab.set(open);
    if (violations.some((entry) => ADVANCED_FIELDS.includes(entry.field))) this.advanced.set(true);
    if (violations[0] === undefined) return;
    this.focusedSummary = false;
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
  }

  private focusRefusal(): void {
    if (this.focusedSummary) return;
    const violations = this.store.violations();
    if (violations[0] === undefined) return;
    this.focusedSummary = true;
    this.summary()?.nativeElement.focus();
    const rank = (field: string): number => (FIELD_ORDER.includes(field) ? FIELD_ORDER.indexOf(field) : FIELD_ORDER.length);
    const first = violations.reduce((best, entry) => (rank(entry.field) < rank(best.field) ? entry : best));
    this.focusControl(first.field);
  }

  private focusControl(field: string): void {
    document.getElementById(field === FLAGS_FIELD ? this.flagId(FLAG_ENABLED) : this.controlId(field))?.focus();
  }

  private entries(values: readonly string[]): readonly EntryView[] {
    return values.map((text, index) => ({ key: `${index}\u0000${text}`, index, text, removeLabel: `${STRINGS.actionRemove} ${text}` }));
  }

  private textView(field: string, disabled = false): FieldView {
    this.generation();
    return this.view(field, LABELS[field] ?? field, this.store.text(field), disabled);
  }

  private view(field: string, label: string, value: string, disabled: boolean): FieldView {
    const id = this.controlId(field);
    const reason = this.store.violationFor(field);
    const invalid = reason !== '';
    return { field, id, label, value, disabled, reason, invalid, describedBy: invalid ? `${id}-reason` : null };
  }

  private flagView(bit: number, label: string, disabled = false): FlagView {
    this.generation();
    const id = this.flagId(bit);
    const reason = bit === FLAG_ENABLED ? this.store.violationFor(FLAGS_FIELD) : '';
    const invalid = reason !== '';
    return { bit, id, label, checked: this.store.flag(bit), disabled, reason, invalid, describedBy: invalid ? `${id}-reason` : null };
  }

  private flagId(bit: number): string {
    return `ocu-ldap-flag-${bit}`;
  }

  private joined(ids: readonly string[]): string | null {
    const present = ids.filter((id) => id !== '');
    return present.length === 0 ? null : present.join(' ');
  }

  private controlId(field: string): string {
    return `ocu-ldap-${field}`;
  }

  /** The new configuration's own URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private editorUrl(id: string): string {
    const editor = this.navigation.screenForUrl(this.router.url);
    const route = editor === null ? LDAP_FORM_ROUTE : editor.route;
    return withQuery(`${route}/${encodeEntityId(id)}`, this.router.url);
  }
}
