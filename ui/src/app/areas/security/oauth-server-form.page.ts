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

import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { tabErrorCounts, tabToOpen } from '../../core/form-tabs';
import { NavigationService, formatDeniedAction, ownIdSegment, screenForRoute, withQuery } from '../../core/navigation';
import { savedLine } from '../../core/read-back';
import { actionLabel } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { STRINGS } from '../../core/strings';
import { STATE_CONFLICT_CODE, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { FormTabBody, FormTabs, type FormTabView } from '../../shell/form-tabs';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { TypedNameDialog } from '../../shell/typed-name-dialog';
import { type ClientFieldControl, type ClientFieldOption, OAuthClientField } from './oauth-client-field';
import {
  AUTH_SERVER_FIELD_ORDER,
  AUTH_SERVER_FIELD_TABS,
  CUSTOMIZATION_TAB,
  ENCRYPTION_ALGORITHMS,
  FLAG_FIELDS,
  type FlagKey,
  GENERAL_TAB,
  GRANTS_MEMBER,
  GRANT_CHOICES,
  INTERVALS_TAB,
  JWT_TAB,
  KEY_ALGORITHMS,
  METADATA_FLAG_MEMBERS,
  type MetadataFlagKey,
  OAuthServerForm,
  PASSWORD_FIELD,
  REFRESH_POLICIES,
  ROLES_FIELD,
  SCOPES_FIELD,
  SCOPES_TAB,
  SIGNING_ALGORITHMS,
  TEXT_FIELDS,
  type TextKey,
  URL_MEMBERS,
  type UrlKey,
  metadataField,
} from './oauth-server-form.store';

/** The tab this form is reached from, which Cancel and a delete return to. */
export const OAUTH_AUTH_SERVER_TAB_ROUTE = 'security/oauth/server';

/** This form's own route, the fallback when the mirror cannot resolve it from the URL. */
export const OAUTH_AUTH_SERVER_FORM_ROUTE = 'security/oauth/server/edit';

/** The tab whose declared Delete and Rotate Keys this page sends (AD-53). */
export const OAUTH_AUTH_SERVER_TAB_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.OAuthServerTab';

export const DELETE_ACTION = 'delete';

export const ROTATE_ACTION = 'rotatekeys';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** The id every control's own id begins with. */
const ID_PREFIX = 'ocu-oauth-server';

/** The grant types' labels, by value. */
const GRANT_LABELS: Readonly<Record<string, string>> = {
  authorization_code: STRINGS.oauthClientGrantAuthorizationCode,
  implicit: STRINGS.oauthClientGrantImplicit,
  password: STRINGS.oauthClientGrantPassword,
  client_credentials: STRINGS.oauthClientGrantClientCredentials,
  jwt_authorization: STRINGS.oauthClientGrantJwt,
};

/** The refresh token policies' labels, by value. */
const REFRESH_LABELS: Readonly<Record<string, string>> = {
  '': STRINGS.oauthAuthServerRefreshRequired,
  a: STRINGS.oauthAuthServerRefreshAlways,
  c: STRINGS.oauthAuthServerRefreshConfidential,
  f: STRINGS.oauthAuthServerRefreshOffline,
};

type Control = ClientFieldControl;

type Option = ClientFieldOption;

/** One scope row, resolved for drawing. */
interface ScopeRow {
  readonly index: number;
  readonly scopeId: string;
  readonly descriptionId: string;
  readonly scope: string;
  readonly description: string;
}

/** One checkbox of a group, resolved for drawing. */
interface Choice {
  readonly value: string;
  readonly id: string;
  readonly label: string;
  readonly checked: boolean;
}

/** A control's id for `field`: `Metadata.x` as `Metadata-x`. */
function idFor(field: string): string {
  return `${ID_PREFIX}-${field.replace(/[^A-Za-z0-9_-]/g, '-')}`;
}

/**
 * The OAuth 2.0 authorization server editor, a tabbed `form-page` over this instance's one
 * configuration on `security/oauth/server/edit` (AD-55): a create when the instance has none, the
 * stored configuration otherwise, whatever id segment the route carries.
 *
 * **Its five tabs are the classic editor's**: General, Scopes, Intervals, JWT Settings and
 * Customization, on `app-form-tabs` (UX-DR33). A refused Save opens the tab that holds the first
 * refused field.
 *
 * **Rotate Keys and Delete are the tab's own declared actions**, sent through the shell's handler
 * exactly as its row menu sends them (AD-53); Delete after the issuer is typed. Rotate Keys is
 * offered only while the stored configuration signs with keys it generated.
 *
 * It composes no payload and authors no field sentence. The key password is masked and never
 * pre-filled. Every control-flow condition is a paren-free member reference, for the reason
 * `sign-in.ts` records.
 */
@Component({
  selector: 'app-oauth-server-form-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, FormTabs, FormTabBody, OAuthClientField, TypedNameDialog],
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
    <app-form-tabs [tabs]="tabs" [selected]="selectedTab()" (selectedChange)="selectTab($event)">
      <ng-template ocuFormTab="general">
        <div class="ocu-form-fields ocu-oauth-server-tab">
          <app-oauth-client-field [control]="issuerControl" [locked]="locked" (edited)="onInput(issuerControl, $event)" (left)="onBlur(issuerControl.field)" />
          <p class="ocu-field-caption ocu-oauth-server-hint" [id]="issuerHintId">{{ STRINGS.oauthAuthServerIssuerHint }}</p>
          @for (control of generalControls; track control.id) {
            <app-oauth-client-field [control]="control" [locked]="locked" (edited)="onInput(control, $event)" (toggled)="onCheck(control, $event)" (left)="onBlur(control.field)" />
          }
          <fieldset class="ocu-field ocu-oauth-server-group" [id]="grantsId" tabindex="-1" [attr.aria-describedby]="grantsDescribedBy">
            <legend class="ocu-field-label ocu-field-label-required">{{ STRINGS.oauthColumnGrantTypes }}</legend>
            @for (choice of grantChoices; track choice.value) {
              <label class="ocu-field-checkbox">
                <input type="checkbox" [id]="choice.id" [checked]="choice.checked" [disabled]="locked" (change)="onGrant(choice.value, $event)" />
                <span>{{ choice.label }}</span>
              </label>
            }
            @if (grantsInvalid) {
              <p class="ocu-form-error" [id]="grantsId + '-reason'">{{ grantsReason }}</p>
            }
          </fieldset>
          @for (control of documentationControls; track control.id) {
            <app-oauth-client-field [control]="control" [locked]="locked" (edited)="onInput(control, $event)" (toggled)="onCheck(control, $event)" />
          }
        </div>
      </ng-template>

      <ng-template ocuFormTab="scopes">
        <div class="ocu-form-fields ocu-oauth-server-tab">
          <div class="ocu-field ocu-oauth-server-scopes-field" [id]="scopesId" tabindex="-1">
            <table class="ocu-oauth-server-scopes" [attr.aria-describedby]="scopesDescribedBy">
              <caption class="ocu-field-label ocu-field-label-required">{{ STRINGS.oauthColumnScopes }}</caption>
              <thead>
                <tr>
                  <th scope="col">{{ STRINGS.oauthAuthServerFieldScope }}</th>
                  <th scope="col">{{ STRINGS.tableColumnDescription }}</th>
                  <th scope="col" class="ocu-oauth-server-scopes-action">{{ STRINGS.actionRemove }}</th>
                </tr>
              </thead>
              <tbody>
                @for (row of scopeRows; track row.index) {
                  <tr>
                    <td>
                      <input class="ocu-field-input" type="text" spellcheck="false" autocomplete="off" [id]="row.scopeId" [value]="row.scope" [readOnly]="locked" [attr.aria-label]="STRINGS.oauthAuthServerFieldScope" [attr.aria-invalid]="scopesInvalid" (input)="onScope(row.index, 'scope', $event)" />
                    </td>
                    <td>
                      <input class="ocu-field-input" type="text" spellcheck="false" autocomplete="off" [id]="row.descriptionId" [value]="row.description" [readOnly]="locked" [attr.aria-label]="STRINGS.tableColumnDescription" (input)="onScope(row.index, 'description', $event)" />
                    </td>
                    <td class="ocu-oauth-server-scopes-action">
                      <button type="button" class="ocu-button-text" [attr.aria-disabled]="locked" (click)="removeScope(row.index)">{{ STRINGS.actionRemove }}</button>
                    </td>
                  </tr>
                }
              </tbody>
            </table>
            <div class="ocu-oauth-server-row">
              <button type="button" class="ocu-button-secondary" [id]="addScopeId" [attr.aria-disabled]="locked" (click)="addScope()">{{ STRINGS.oauthAuthServerAddScope }}</button>
            </div>
            @if (scopesInvalid) {
              <p class="ocu-form-error" [id]="scopesId + '-reason'">{{ scopesReason }}</p>
            }
          </div>
          @for (control of scopeControls; track control.id) {
            <app-oauth-client-field [control]="control" [locked]="locked" (edited)="onInput(control, $event)" (toggled)="onCheck(control, $event)" (left)="onBlur(control.field)" />
          }
        </div>
      </ng-template>

      <ng-template ocuFormTab="intervals">
        <div class="ocu-form-fields ocu-oauth-server-tab">
          @for (control of intervalControls; track control.id) {
            <app-oauth-client-field [control]="control" [locked]="locked" (edited)="onInput(control, $event)" (left)="onBlur(control.field)" />
          }
        </div>
      </ng-template>

      <ng-template ocuFormTab="jwt">
        <div class="ocu-form-fields ocu-oauth-server-tab">
          @for (control of jwtControls; track control.id) {
            <app-oauth-client-field [control]="control" [locked]="locked" (edited)="onInput(control, $event)" />
          }
        </div>
      </ng-template>

      <ng-template ocuFormTab="customization">
        <div class="ocu-form-fields ocu-oauth-server-tab">
          @for (control of customizationControls; track control.id) {
            <app-oauth-client-field [control]="control" [locked]="locked" (edited)="onInput(control, $event)" (left)="onBlur(control.field)" />
          }
          <fieldset class="ocu-field ocu-oauth-server-group" [id]="rolesId" tabindex="-1" [attr.aria-describedby]="rolesDescribedBy">
            <legend class="ocu-field-label ocu-field-label-required">{{ STRINGS.userColumnRoles }}</legend>
            @for (choice of roleChoices; track choice.value) {
              <label class="ocu-field-checkbox">
                <input type="checkbox" [id]="choice.id" [checked]="choice.checked" [disabled]="locked" (change)="onRole(choice.value, $event)" />
                <span>{{ choice.label }}</span>
              </label>
            }
            @if (addsPrivilege) {
              <p class="ocu-field-caption ocu-oauth-server-privilege" [id]="rolesId + '-privilege'">{{ STRINGS.oauthAuthServerCustomizationEffect }}</p>
            }
            @if (rolesInvalid) {
              <p class="ocu-form-error" [id]="rolesId + '-reason'">{{ rolesReason }}</p>
            }
          </fieldset>
        </div>
      </ng-template>
    </app-form-tabs>

    <div class="ocu-form-bar">
      <div class="ocu-form-bar-status">
        @if (hasStatus) {
          <span role="status">{{ status }}</span>
        }
      </div>
      <div class="ocu-form-bar-actions">
        <button type="button" class="ocu-button-text" (click)="cancel()">{{ STRINGS.actionCancel }}</button>
        @if (offersRotate) {
          <button type="button" class="ocu-button-text" [attr.aria-disabled]="actionBlocked" (click)="onRotate()">{{ rotateLabel }}</button>
        }
        @if (offersDelete) {
          <button type="button" class="ocu-button-text" [attr.aria-disabled]="actionBlocked" (click)="onDelete()">{{ STRINGS.actionDelete }}</button>
        }
        <button type="button" class="ocu-button-primary" [attr.aria-disabled]="saveBlocked" (click)="onSave()">{{ STRINGS.actionSave }}</button>
      </div>
    </div>
    }

    @if (deletePending) {
      <app-typed-name-dialog
        [verb]="deleteVerb"
        [target]="storedIssuer"
        [consequence]="STRINGS.oauthAuthServerDeleteConsequence"
        (confirmed)="confirmDelete()"
        (cancelled)="cancelDelete()"
      />
    }

    @if (leavePending) {
      <app-dialog [heading]="STRINGS.formLeaveWithoutSaving" [closeLabel]="STRINGS.actionCancel" (closed)="answerLeave(false)">
        <button dialogAction type="button" class="ocu-button-primary" (click)="answerLeave(true)">{{ STRINGS.actionConfirm }}</button>
      </app-dialog>
    }
  </section>`,
})
export class OAuthServerFormPage {
  private readonly store = inject(OAuthServerForm);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly handler = inject(ScreenActionHandler);
  private readonly stores = inject(ScreenStores);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  protected readonly issuerHintId = `${ID_PREFIX}-issuer-hint`;
  protected readonly grantsId = idFor(metadataField(GRANTS_MEMBER));
  protected readonly scopesId = idFor(SCOPES_FIELD);
  protected readonly addScopeId = `${ID_PREFIX}-add-scope`;
  protected readonly rolesId = idFor(ROLES_FIELD);

  /** The key of the tab on screen. */
  protected readonly selectedTab = signal(GENERAL_TAB);

  /** Bumped by the stores and this page's own state, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  private focusedSummary = false;

  private deleting = false;

  /** Whether a Delete or a rotation is in flight. */
  private acting = false;

  /** The refusal the last action was answered with, or `''` (AD-39). */
  private actionRefusal = '';

  /** Whether the last action was a rotation the instance applied. */
  private rotated = false;

  constructor() {
    const stopStore = this.store.subscribe(() => this.bump());
    const stopDirty = this.formDirty.subscribe(() => this.bump());
    let followed = this.routeId();
    void this.store.open();
    const stopRoute = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      const id = this.routeId();
      if (id === followed) return;
      followed = id;
      this.actionRefusal = '';
      this.rotated = false;
      this.selectedTab.set(GENERAL_TAB);
      void this.store.open();
    });
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      stopRoute.unsubscribe();
      if (!this.store.retaining()) this.store.reset();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get loadedFlag(): boolean {
    this.generation();
    return this.store.loaded();
  }

  protected get locked(): boolean {
    this.generation();
    return !this.store.editable() || this.acting;
  }

  protected get storedIssuer(): string {
    this.generation();
    return this.store.storedIssuer();
  }

  protected get tabs(): readonly FormTabView[] {
    this.generation();
    const counts = tabErrorCounts(AUTH_SERVER_FIELD_TABS, this.store.violations());
    return [
      { key: GENERAL_TAB, label: STRINGS.processDetailsGroupGeneral, count: counts[GENERAL_TAB] ?? 0 },
      { key: SCOPES_TAB, label: STRINGS.oauthColumnScopes, count: counts[SCOPES_TAB] ?? 0 },
      { key: INTERVALS_TAB, label: STRINGS.oauthAuthServerTabIntervals, count: counts[INTERVALS_TAB] ?? 0 },
      { key: JWT_TAB, label: STRINGS.oauthClientSectionJwt, count: counts[JWT_TAB] ?? 0 },
      { key: CUSTOMIZATION_TAB, label: STRINGS.oauthAuthServerTabCustomization, count: counts[CUSTOMIZATION_TAB] ?? 0 },
    ];
  }

  /** The issuer endpoint, drawn first with its hint beneath it. */
  protected get issuerControl(): Control {
    this.generation();
    const issuer = this.textControl('issuer', STRINGS.oauthServerFieldIssuer);
    return { ...issuer, describedBy: issuer.invalid ? `${this.issuerHintId} ${issuer.id}-reason` : this.issuerHintId };
  }

  /** The General tab's other fields, drawn after the issuer's hint. */
  protected get generalControls(): readonly Control[] {
    this.generation();
    return [
      this.textControl('description', STRINGS.tableColumnDescription),
      this.flagControl('aud', STRINGS.oauthAuthServerFieldAudRequired),
      this.flagControl('supportSession', STRINGS.oauthAuthServerFieldSupportSession),
      this.flagControl('publicRefresh', STRINGS.oauthAuthServerFieldPublicRefresh),
      this.flagControl('pkcePublic', STRINGS.oauthAuthServerFieldPkcePublic),
      this.flagControl('pkceConfidential', STRINGS.oauthAuthServerFieldPkceConfidential),
      this.metadataFlagControl('frontChannel', STRINGS.oauthAuthServerFieldFrontChannel),
      this.metadataFlagControl('frontSession', STRINGS.oauthAuthServerFieldFrontChannelSession),
      this.selectControl(TEXT_FIELDS.refresh, STRINGS.oauthAuthServerFieldReturnRefresh, this.store.text('refresh'), this.refreshOptions()),
    ];
  }

  /** The documentation URLs and the SSL/TLS configuration, drawn after the grant types. */
  protected get documentationControls(): readonly Control[] {
    this.generation();
    return [
      this.urlControl('serviceDocs', STRINGS.oauthAuthServerFieldServiceDocs),
      this.urlControl('policy', STRINGS.oauthClientFieldPolicy),
      this.urlControl('tos', STRINGS.oauthClientFieldTos),
      this.namedSelect(TEXT_FIELDS.ssl, STRINGS.sslFormLabel, 'ssl', this.store.sslConfigurations(), STRINGS.sslVerifyPeerNone),
    ];
  }

  protected get grantChoices(): readonly Choice[] {
    this.generation();
    return GRANT_CHOICES.map((grant) => ({ value: grant, id: idFor(`${metadataField(GRANTS_MEMBER)}-${grant}`), label: GRANT_LABELS[grant] ?? grant, checked: this.store.granted(grant) }));
  }

  protected get grantsReason(): string {
    this.generation();
    return this.store.violationFor(metadataField(GRANTS_MEMBER));
  }

  protected get grantsInvalid(): boolean {
    return this.grantsReason !== '';
  }

  protected get grantsDescribedBy(): string | null {
    return this.grantsInvalid ? `${this.grantsId}-reason` : null;
  }

  protected get scopeRows(): readonly ScopeRow[] {
    this.generation();
    return this.store.scopes().map((entry, index) => ({
      index,
      scopeId: `${this.scopesId}-${index + 1}`,
      descriptionId: `${this.scopesId}-${index + 1}-description`,
      scope: entry.scope,
      description: entry.description,
    }));
  }

  protected get scopesReason(): string {
    this.generation();
    return this.store.violationFor(SCOPES_FIELD);
  }

  protected get scopesInvalid(): boolean {
    return this.scopesReason !== '';
  }

  protected get scopesDescribedBy(): string | null {
    return this.scopesInvalid ? `${this.scopesId}-reason` : null;
  }

  protected get scopeControls(): readonly Control[] {
    this.generation();
    return [this.flagControl('unsupportedScope', STRINGS.oauthAuthServerFieldUnsupportedScope), this.textControl('defaultScope', STRINGS.oauthColumnDefaultScope)];
  }

  protected get intervalControls(): readonly Control[] {
    this.generation();
    return [
      this.numberControl('accessInterval', STRINGS.oauthAuthServerFieldAccessTokenInterval),
      this.numberControl('codeInterval', STRINGS.oauthAuthServerFieldCodeInterval),
      this.numberControl('refreshInterval', STRINGS.oauthAuthServerFieldRefreshInterval),
      this.numberControl('sessionInterval', STRINGS.oauthAuthServerFieldSessionInterval),
      this.numberControl('secretInterval', STRINGS.oauthAuthServerFieldSecretInterval),
    ];
  }

  protected get jwtControls(): readonly Control[] {
    this.generation();
    return [
      this.namedSelect(TEXT_FIELDS.credentials, STRINGS.oauthColumnServerCredentials, 'credentials', this.store.credentials(), STRINGS.sslVerifyPeerNone),
      this.passwordControl(),
      this.selectControl(TEXT_FIELDS.signing, STRINGS.oauthColumnSigningAlgorithm, this.store.text('signing'), this.listOptions(SIGNING_ALGORITHMS, this.store.text('signing'))),
      this.selectControl(TEXT_FIELDS.keyAlgorithm, STRINGS.oauthColumnKeyAlgorithm, this.store.text('keyAlgorithm'), this.listOptions(KEY_ALGORITHMS, this.store.text('keyAlgorithm'))),
      this.selectControl(TEXT_FIELDS.encryption, STRINGS.oauthColumnEncryptionAlgorithm, this.store.text('encryption'), this.listOptions(ENCRYPTION_ALGORITHMS, this.store.text('encryption'))),
    ];
  }

  protected get customizationControls(): readonly Control[] {
    this.generation();
    const namespace = this.store.text('namespace');
    const namespaces = this.store.namespaces();
    return [
      this.textControl('authenticate', STRINGS.oauthAuthServerFieldAuthenticateClass),
      this.textControl('validate', STRINGS.oauthAuthServerFieldValidateUserClass),
      this.textControl('sessionClass', STRINGS.oauthAuthServerFieldSessionClass),
      this.textControl('generate', STRINGS.oauthAuthServerFieldGenerateTokenClass),
      this.textControl('revoke', STRINGS.oauthAuthServerFieldRevokeTokenClass),
      this.selectControl(TEXT_FIELDS.namespace, STRINGS.headerNamespaceLabel, namespace, (namespaces.includes(namespace) || namespace === '' ? namespaces : [...namespaces, namespace]).map((value) => ({ value, label: value }))),
    ];
  }

  protected get roleChoices(): readonly Choice[] {
    this.generation();
    const chosen = this.store.roles();
    return this.store.roleChoices().map((role) => ({ value: role, id: idFor(`${ROLES_FIELD}-${role}`), label: role, checked: chosen.includes(role) }));
  }

  protected get addsPrivilege(): boolean {
    this.generation();
    return this.store.addsPrivilegedRole();
  }

  protected get rolesReason(): string {
    this.generation();
    return this.store.violationFor(ROLES_FIELD);
  }

  protected get rolesInvalid(): boolean {
    return this.rolesReason !== '';
  }

  protected get rolesDescribedBy(): string | null {
    const ids: string[] = [];
    if (this.addsPrivilege) ids.push(`${this.rolesId}-privilege`);
    if (this.rolesInvalid) ids.push(`${this.rolesId}-reason`);
    return ids.length === 0 ? null : ids.join(' ');
  }

  protected get saveBlocked(): boolean {
    this.generation();
    return !this.store.canSave() || this.acting;
  }

  protected get actionBlocked(): boolean {
    this.generation();
    return this.store.busy() || this.acting;
  }

  /** Delete is offered on a held configuration alone. */
  protected get offersDelete(): boolean {
    this.generation();
    return this.store.mode() === 'edit' && this.store.held();
  }

  /** Rotate Keys is offered on a held configuration whose keys the instance generated, as the classic page offers it. */
  protected get offersRotate(): boolean {
    this.generation();
    return this.offersDelete && this.store.storedCredentials() === '';
  }

  protected get rotateLabel(): string {
    return actionLabel(OAUTH_AUTH_SERVER_TAB_DESCRIPTOR, ROTATE_ACTION);
  }

  protected get deletePending(): boolean {
    this.generation();
    return this.deleting;
  }

  protected get deleteVerb(): string {
    return actionLabel(OAUTH_AUTH_SERVER_TAB_DESCRIPTOR, DELETE_ACTION);
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
   * published sentence, the pair the envelope named and the create's or the edit's action, a stale
   * save's published sentence, an action's own refusal, or the envelope's own reason.
   */
  protected get reason(): string {
    this.generation();
    if (this.actionRefusal !== '') return this.actionRefusal;
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') {
      const action = this.store.mode() === 'create' ? STRINGS.oauthAuthServerEmptyAgent : STRINGS.oauthAuthServerFormRefusedAction;
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, action);
    }
    if (this.store.refusalCode() === STATE_CONFLICT_CODE) return STRINGS.formStaleSave;
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  /** The status line: "Saved", with what did not land beside it, or the rotation's outcome. */
  protected get status(): string {
    this.generation();
    if (this.rotated) return STRINGS.oauthAuthServerRotated;
    if (!this.store.saved()) return '';
    const refused = this.store.passwordRefused();
    return refused === '' ? savedLine(this.store.readBack()) : STRINGS.oauthAuthServerPasswordRefused.split('<reason>').join(refused);
  }

  protected get hasStatus(): boolean {
    return this.status !== '';
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  // --- intents ---------------------------------------------------------------------------------

  protected selectTab(key: string): void {
    this.selectedTab.set(key);
  }

  protected onInput(control: Control, value: string): void {
    this.rotated = false;
    if (control.field === PASSWORD_FIELD) {
      this.store.setPassword(value);
      return;
    }
    const url = (Object.keys(URL_MEMBERS) as UrlKey[]).find((key) => metadataField(URL_MEMBERS[key]) === control.field);
    if (url !== undefined) {
      this.store.setUrl(url, value);
      return;
    }
    const key = (Object.keys(TEXT_FIELDS) as TextKey[]).find((entry) => TEXT_FIELDS[entry] === control.field);
    if (key !== undefined) this.store.setText(key, value);
  }

  protected onCheck(control: Control, checked: boolean): void {
    this.rotated = false;
    const flag = (Object.keys(FLAG_FIELDS) as FlagKey[]).find((key) => FLAG_FIELDS[key] === control.field);
    if (flag !== undefined) {
      this.store.setFlag(flag, checked);
      return;
    }
    const member = (Object.keys(METADATA_FLAG_MEMBERS) as MetadataFlagKey[]).find((key) => metadataField(METADATA_FLAG_MEMBERS[key]) === control.field);
    if (member !== undefined) this.store.setMetadataFlag(member, checked);
  }

  protected onBlur(field: string): void {
    this.store.onBlur(field);
  }

  protected onGrant(grant: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setGrant(grant, target.checked);
  }

  protected onRole(role: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setRole(role, target.checked);
  }

  protected onScope(index: number, part: 'scope' | 'description', event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setScope(index, part, target.value);
  }

  protected addScope(): void {
    if (this.locked) return;
    this.store.addScope();
    const id = `${this.scopesId}-${this.store.scopes().length}`;
    afterNextRender(() => document.getElementById(id)?.focus(), { injector: this.injector });
  }

  protected removeScope(index: number): void {
    if (this.locked) return;
    this.store.removeScope(index);
  }

  protected async onSave(): Promise<void> {
    if (this.saveBlocked) return;
    this.actionRefusal = '';
    this.rotated = false;
    const creating = this.store.mode() === 'create';
    const saved = await this.store.save();
    if (!saved) {
      this.afterRefusal();
      return;
    }
    this.store.retainAcrossRouteReplacement();
    // A create replaces the route with the configuration's own URL, as its row's name cell names it,
    // and the route change reads it again; an edit reads it again here, so every tab shows what the
    // instance now holds.
    if (creating) {
      void this.router.navigateByUrl(this.editorUrl(this.store.savedIssuer()), { replaceUrl: true });
      return;
    }
    await this.store.open();
  }

  /** Send the tab's declared Rotate Keys (AD-53). The form shows no key, so nothing is read again. */
  protected async onRotate(): Promise<void> {
    if (!this.offersRotate || this.actionBlocked) return;
    this.actionRefusal = '';
    this.rotated = false;
    this.acting = true;
    this.bump();
    const applied = await this.handler.sendFor(OAUTH_AUTH_SERVER_TAB_DESCRIPTOR, ROTATE_ACTION, this.store.storedIssuer());
    this.acting = false;
    if (!applied) {
      this.actionRefusal = this.tabRefusal();
      this.bump();
      return;
    }
    this.rotated = true;
    this.bump();
  }

  protected onDelete(): void {
    if (!this.offersDelete || this.actionBlocked) return;
    this.actionRefusal = '';
    this.rotated = false;
    this.deleting = true;
    this.bump();
  }

  protected cancelDelete(): void {
    this.deleting = false;
    this.bump();
  }

  /** The typed issuer matched: send the tab's declared delete, then return to the tab (AD-53). */
  protected async confirmDelete(): Promise<void> {
    this.deleting = false;
    this.acting = true;
    this.bump();
    const applied = await this.handler.sendFor(OAUTH_AUTH_SERVER_TAB_DESCRIPTOR, DELETE_ACTION, this.store.storedIssuer());
    this.acting = false;
    if (!applied) {
      this.actionRefusal = this.tabRefusal();
      this.bump();
      return;
    }
    this.formDirty.setDirty(false);
    void this.router.navigateByUrl(withQuery(OAUTH_AUTH_SERVER_TAB_ROUTE, this.router.url));
  }

  /** Open the tab that holds `field`, then focus it. */
  protected focusField(field: string): void {
    const tab = AUTH_SERVER_FIELD_TABS[field];
    if (tab !== undefined && tab !== this.selectedTab()) {
      this.selectedTab.set(tab);
      afterNextRender(() => this.focusControl(field), { injector: this.injector });
      return;
    }
    this.focusControl(field);
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(OAUTH_AUTH_SERVER_TAB_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  /** The sentence the tab's action route refused with, which the handler puts on the tab's store. */
  private tabRefusal(): string {
    const tab = screenForRoute(OAUTH_AUTH_SERVER_TAB_ROUTE);
    return tab === null ? '' : this.stores.for(tab.descriptor, tab.refreshRates).refusal();
  }

  /**
   * After a refused Save: the tab that holds the first refused field opens, the error summary takes
   * focus, then that field, in the order EXPERIENCE.md's `form-page` validation rule states.
   */
  private afterRefusal(): void {
    const open = tabToOpen(AUTH_SERVER_FIELD_TABS, AUTH_SERVER_FIELD_ORDER, this.store.violations());
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
    const order = AUTH_SERVER_FIELD_ORDER;
    const rank = (field: string): number => (order.includes(field) ? order.indexOf(field) : order.length);
    const first = violations.reduce((best, entry) => (rank(entry.field) < rank(best.field) ? entry : best));
    this.focusControl(first.field);
  }

  private focusControl(field: string): void {
    document.getElementById(this.controlId(field))?.focus();
  }

  /** A field's control id: the grant types', scopes' and roles' groups, or its own. */
  private controlId(field: string): string {
    if (field === metadataField(GRANTS_MEMBER) || field === 'Metadata') return this.grantsId;
    if (field === SCOPES_FIELD) return this.scopesId;
    if (field === ROLES_FIELD) return this.rolesId;
    return idFor(field);
  }

  /** A control with no value, for `field` labelled `label`, its refusal wired. */
  private base(field: string, label: string): Control {
    const id = idFor(field);
    const reason = this.store.violationFor(field);
    const invalid = reason !== '';
    return {
      field,
      id,
      label,
      required: this.store.required(field),
      isInput: false,
      isSelect: false,
      isCheck: false,
      isSecret: false,
      readOnly: false,
      inputType: 'text',
      value: '',
      checked: false,
      options: [],
      hasHint: false,
      reason,
      invalid,
      describedBy: invalid ? `${id}-reason` : null,
    };
  }

  private textControl(key: TextKey, label: string): Control {
    return { ...this.base(TEXT_FIELDS[key], label), isInput: true, value: this.store.text(key) };
  }

  private numberControl(key: TextKey, label: string): Control {
    return { ...this.textControl(key, label), inputType: 'number' };
  }

  private urlControl(key: UrlKey, label: string): Control {
    return { ...this.base(metadataField(URL_MEMBERS[key]), label), isInput: true, inputType: 'url', value: this.store.url(key) };
  }

  private flagControl(key: FlagKey, label: string): Control {
    return { ...this.base(FLAG_FIELDS[key], label), isCheck: true, checked: this.store.flag(key) };
  }

  private metadataFlagControl(key: MetadataFlagKey, label: string): Control {
    return { ...this.base(metadataField(METADATA_FLAG_MEMBERS[key]), label), isCheck: true, checked: this.store.metadataFlag(key) };
  }

  private selectControl(field: string, label: string, value: string, options: readonly Option[]): Control {
    return { ...this.base(field, label), isSelect: true, value, options };
  }

  /** A select over readable names, an empty choice first and the stored value kept. */
  private namedSelect(field: string, label: string, key: TextKey, names: readonly string[], empty: string): Control {
    const value = this.store.text(key);
    const values = names.includes(value) || value === '' ? names : [...names, value];
    return this.selectControl(field, label, value, [{ value: '', label: empty }, ...values.map((name) => ({ value: name, label: name }))]);
  }

  /** An algorithm select: an empty choice, the vendor's list, and a stored value outside it kept. */
  private listOptions(values: readonly string[], value: string): readonly Option[] {
    const all = values.includes(value) || value === '' ? values : [...values, value];
    return [{ value: '', label: STRINGS.oauthClientNotSet }, ...all.map((entry) => ({ value: entry, label: entry }))];
  }

  private refreshOptions(): readonly Option[] {
    const value = this.store.text('refresh');
    const values = REFRESH_POLICIES.includes(value) ? REFRESH_POLICIES : [...REFRESH_POLICIES, value];
    return values.map((entry) => ({ value: entry, label: REFRESH_LABELS[entry] ?? entry }));
  }

  private passwordControl(): Control {
    const own = this.base(PASSWORD_FIELD, STRINGS.x509FieldPrivateKeyPassword);
    return {
      ...own,
      isInput: true,
      isSecret: true,
      inputType: 'password',
      value: this.store.password(),
      hasHint: true,
      describedBy: own.invalid ? `${own.id}-hint ${own.id}-reason` : `${own.id}-hint`,
    };
  }

  /** The route's own id segment: only a change of it is a different arrival, never a query change. */
  private routeId(): string {
    const screen = screenForRoute(OAUTH_AUTH_SERVER_FORM_ROUTE);
    return screen === null ? '' : ownIdSegment(screen, this.router.url);
  }

  /** The configuration's own URL, as its row's name cell names it. The id is `encodeEntityId`'s (AD-13). */
  private editorUrl(issuer: string): string {
    const editor = this.navigation.screenForUrl(this.router.url);
    const route = editor === null ? OAUTH_AUTH_SERVER_FORM_ROUTE : editor.route;
    return withQuery(issuer === '' ? route : `${route}/${encodeEntityId(issuer)}`, this.router.url);
  }
}
