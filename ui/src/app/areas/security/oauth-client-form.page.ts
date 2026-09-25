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
import { NavigationService, formatDeniedAction, ownIdSegment, screenForRoute, withQuery } from '../../core/navigation';
import { actionLabel } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { STRINGS } from '../../core/strings';
import { STATE_CONFLICT_CODE, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { TypedNameDialog } from '../../shell/typed-name-dialog';
import { type ClientFieldControl, type ClientFieldOption, OAuthClientField } from './oauth-client-field';
import {
  AUDIENCE_FIELD,
  CLIENT_ID_FIELD,
  CREDENTIALS_FIELD,
  DESCRIPTION_FIELD,
  ENABLED_FIELD,
  GRANT_MEMBER,
  GRANT_TYPES,
  INITIAL_TOKEN_FIELD,
  INTERVAL_FIELD,
  type MemberValue,
  NAME_FIELD,
  OAuthClientForm,
  PASSWORD_FIELD,
  REDIRECT_FIELD,
  REGISTRATION_TOKEN_FIELD,
  SCOPE_FIELD,
  SECRET_FIELD,
  SECRET_FIELDS,
  SERVER_FIELD,
  SSL_FIELD,
  TYPE_FIELD,
  memberField,
} from './oauth-client-form.store';

/** The tab this form is reached from, which Cancel and a delete return to. */
export const OAUTH_CLIENT_TAB_ROUTE = 'security/oauth/clients';

/** This form's own route, the fallback when the mirror cannot resolve it from the URL. */
export const OAUTH_CLIENT_FORM_ROUTE = 'security/oauth/clients/edit';

/** The tab whose declared Delete, Rotate Keys and Register this page sends (AD-53). */
export const OAUTH_CLIENT_TAB_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.OAuthClientTab';

export const DELETE_ACTION = 'delete';

export const ROTATE_ACTION = 'rotatekeys';

export const REGISTER_ACTION = 'register';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** The id every control's own id begins with. */
const ID_PREFIX = 'ocu-oauth-client';

/** The top-level text fields, keyed by the wire field, each with the store key it edits. */
const TEXT_KEYS: Readonly<Record<string, 'name' | 'server' | 'description' | 'clientType' | 'ssl' | 'redirect' | 'audience' | 'interval' | 'clientId' | 'credentials' | 'scope'>> = {
  [NAME_FIELD]: 'name',
  [SERVER_FIELD]: 'server',
  [DESCRIPTION_FIELD]: 'description',
  [TYPE_FIELD]: 'clientType',
  [SSL_FIELD]: 'ssl',
  [REDIRECT_FIELD]: 'redirect',
  [AUDIENCE_FIELD]: 'audience',
  [INTERVAL_FIELD]: 'interval',
  [CLIENT_ID_FIELD]: 'clientId',
  [CREDENTIALS_FIELD]: 'credentials',
  [SCOPE_FIELD]: 'scope',
};

/** The grant types' labels, by value, in the classic page's order. */
const GRANT_LABELS: Readonly<Record<string, string>> = {
  authorization_code: STRINGS.oauthClientGrantAuthorizationCode,
  implicit: STRINGS.oauthClientGrantImplicit,
  password: STRINGS.oauthClientGrantPassword,
  client_credentials: STRINGS.oauthClientGrantClientCredentials,
  jwt_authorization: STRINGS.oauthClientGrantJwt,
};

/** The authentication methods the classic page offers, as the instance stores them. */
const AUTH_METHODS: readonly string[] = ['none', 'client_secret_basic', 'client_secret_post', 'client_secret_jwt', 'private_key_jwt'];

/** The four algorithm groups, each its signing, encryption and key member, in the classic page's order. */
const ALGORITHM_GROUPS: readonly { readonly legend: string; readonly members: readonly string[] }[] = [
  {
    legend: STRINGS.oauthClientAlgIdToken,
    members: ['id_token_signed_response_alg', 'id_token_encrypted_response_enc', 'id_token_encrypted_response_alg'],
  },
  {
    legend: STRINGS.oauthClientAlgUserinfo,
    members: ['userinfo_signed_response_alg', 'userinfo_encrypted_response_enc', 'userinfo_encrypted_response_alg'],
  },
  {
    legend: STRINGS.oauthClientAlgAccessToken,
    members: ['access_token_signed_response_alg', 'access_token_encrypted_response_enc', 'access_token_encrypted_response_alg'],
  },
  {
    legend: STRINGS.oauthClientAlgRequest,
    members: ['request_object_signing_alg', 'request_object_encryption_enc', 'request_object_encryption_alg'],
  },
];

/** Each algorithm group's three columns, in the classic page's order. */
const ALGORITHM_COLUMNS: readonly string[] = [STRINGS.oauthClientAlgSigning, STRINGS.oauthClientAlgEncryption, STRINGS.oauthClientAlgKey];

/** The members the form draws a control of its own for; every other non-secret one is in the table. */
const DRAWN_MEMBERS: readonly string[] = [
  'client_name',
  'frontchannel_logout_uri',
  'frontchannel_logout_session_required',
  GRANT_MEMBER,
  'token_endpoint_auth_method',
  'token_endpoint_auth_signing_alg',
  'logo_uri',
  'client_uri',
  'policy_uri',
  'tos_uri',
  'contacts',
  'default_max_age',
  ...ALGORITHM_GROUPS.flatMap((group) => group.members),
  'client_id_issued_at',
  'client_secret_expires_at',
  'registration_client_uri',
];

type Control = ClientFieldControl;

type Option = ClientFieldOption;

/** One algorithm group, resolved for drawing. */
interface AlgorithmGroup {
  readonly id: string;
  readonly legend: string;
  readonly controls: readonly Control[];
}

/** One row of the read-only metadata table. */
interface MetadataRow {
  readonly name: string;
  readonly value: string;
}

/** A member's value as the metadata table reads it: a list joined, a flag in words, empty as "(none)". */
function displayOf(value: MemberValue): string {
  if (typeof value === 'boolean') return value ? STRINGS.tableStatusYes : STRINGS.tableStatusNo;
  const text = typeof value === 'string' ? value : value.join(', ');
  return text === '' ? STRINGS.tableEmptyValue : text;
}

/** A control's id for `field`: `Metadata.x` as `Metadata-x`. */
function idFor(field: string): string {
  return `${ID_PREFIX}-${field.replace('.', '-')}`;
}

/**
 * The OAuth 2.0 client configuration editor, a `form-page` that creates a configuration on
 * `security/oauth/clients/edit` and edits one on `security/oauth/clients/edit/<name>` (AD-55).
 *
 * **Its four sections are the classic page's four tabs, named and ordered as they are, untabbed**
 * (`%CSP.UI.Portal.OAuth2.Client.Configuration`): General, Client Information, JWT Settings and
 * Client Credentials; then a read-only table of every other metadata member.
 *
 * **Register, Rotate Keys and Delete are the tab's own declared actions**, sent through the shell's
 * handler exactly as its row menu sends them (AD-53). Register is offered on a saved, unchanged,
 * unregistered client whose server description has a registration endpoint; Rotate Keys on a
 * saved, unchanged client with no X.509 credentials; Delete types the name first.
 *
 * It composes no payload and authors no field sentence. The four secrets are masked and never
 * pre-filled. Every control-flow condition is a paren-free member reference, for the reason
 * `sign-in.ts` records.
 */
@Component({
  selector: 'app-oauth-client-form-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, OAuthClientField, TypedNameDialog],
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
      <fieldset class="ocu-field ocu-oauth-client-section" id="ocu-oauth-client-general">
        <legend class="ocu-field-label">{{ STRINGS.processDetailsGroupGeneral }}</legend>
        @for (control of generalControls; track control.id) {
          <app-oauth-client-field [control]="control" [locked]="locked" (edited)="onInput(control, $event)" (toggled)="onCheck(control, $event)" (left)="onBlur(control.field)" />
        }
        <fieldset class="ocu-field ocu-oauth-client-group" [id]="grantsId">
          <legend class="ocu-field-label">{{ STRINGS.oauthColumnGrantTypes }}</legend>
          @for (control of grantControls; track control.id) {
            <app-oauth-client-field [control]="control" [locked]="locked" (toggled)="onCheck(control, $event)" />
          }
        </fieldset>
        @for (control of authControls; track control.id) {
          <app-oauth-client-field [control]="control" [locked]="locked" (edited)="onInput(control, $event)" (toggled)="onCheck(control, $event)" (left)="onBlur(control.field)" />
        }
      </fieldset>

      <fieldset class="ocu-field ocu-oauth-client-section" id="ocu-oauth-client-information">
        <legend class="ocu-field-label">{{ STRINGS.oauthClientSectionClientInformation }}</legend>
        @for (control of informationControls; track control.id) {
          <app-oauth-client-field [control]="control" [locked]="locked" (edited)="onInput(control, $event)" (toggled)="onCheck(control, $event)" (left)="onBlur(control.field)" />
        }
      </fieldset>

      <fieldset class="ocu-field ocu-oauth-client-section" id="ocu-oauth-client-jwt">
        <legend class="ocu-field-label">{{ STRINGS.oauthClientSectionJwt }}</legend>
        @for (control of jwtControls; track control.id) {
          <app-oauth-client-field [control]="control" [locked]="locked" (edited)="onInput(control, $event)" (toggled)="onCheck(control, $event)" (left)="onBlur(control.field)" />
        }
        @for (group of algorithmGroups; track group.id) {
          <fieldset class="ocu-field ocu-oauth-client-group" [id]="group.id">
            <legend class="ocu-field-label">{{ group.legend }}</legend>
            @for (control of group.controls; track control.id) {
              <app-oauth-client-field [control]="control" [locked]="locked" (edited)="onInput(control, $event)" (toggled)="onCheck(control, $event)" (left)="onBlur(control.field)" />
            }
          </fieldset>
        }
      </fieldset>

      <fieldset class="ocu-field ocu-oauth-client-section" id="ocu-oauth-client-credentials">
        <legend class="ocu-field-label">{{ STRINGS.oauthClientSectionCredentials }}</legend>
        @for (control of credentialControls; track control.id) {
          <app-oauth-client-field [control]="control" [locked]="locked" (edited)="onInput(control, $event)" (toggled)="onCheck(control, $event)" (left)="onBlur(control.field)" />
        }
      </fieldset>

      <div class="ocu-field ocu-oauth-client-metadata">
        <table class="ocu-oauth-client-metadata-table" id="ocu-oauth-client-metadata" tabindex="-1">
          <caption class="ocu-field-label">{{ STRINGS.oauthServerGroupMetadata }}</caption>
          <tbody>
            @for (row of metadataRows; track row.name) {
              <tr>
                <th scope="row">{{ row.name }}</th>
                <td>{{ row.value }}</td>
              </tr>
            }
          </tbody>
        </table>
      </div>
    </div>

    <div class="ocu-form-bar">
      <div class="ocu-form-bar-status">
        @if (hasStatus) {
          <span role="status">{{ status }}</span>
        }
      </div>
      <div class="ocu-form-bar-actions">
        <button type="button" class="ocu-button-text" (click)="cancel()">{{ STRINGS.actionCancel }}</button>
        @if (offersDelete) {
          <button type="button" class="ocu-button-text" [attr.aria-disabled]="actionBlocked" (click)="onDelete()">
            {{ STRINGS.actionDelete }}
          </button>
        }
        @if (offersRotate) {
          <button type="button" class="ocu-button-secondary" [attr.aria-disabled]="actionBlocked" (click)="onRotate()">
            {{ STRINGS.oauthClientRotateKeys }}
          </button>
        }
        @if (offersRegister) {
          <button type="button" class="ocu-button-secondary" [attr.aria-disabled]="actionBlocked" (click)="onRegister()">
            {{ STRINGS.oauthClientRegister }}
          </button>
        }
        <button type="button" class="ocu-button-primary" [attr.aria-disabled]="saveBlocked" (click)="onSave()">
          {{ STRINGS.actionSave }}
        </button>
      </div>
    </div>
    }

    @if (deletePending) {
      <app-typed-name-dialog
        [verb]="deleteVerb"
        [target]="storedName"
        [consequence]="STRINGS.oauthClientDeleteConsequence"
        (confirmed)="confirmDelete()"
        (cancelled)="cancelDelete()"
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
export class OAuthClientFormPage {
  private readonly store = inject(OAuthClientForm);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly handler = inject(ScreenActionHandler);
  private readonly stores = inject(ScreenStores);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  protected readonly grantsId = `${ID_PREFIX}-grant-types`;

  /** Bumped by the stores and this page's own state, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  private focusedSummary = false;

  private deleting = false;

  /** Whether a Delete, a Rotate Keys or a Register is in flight. */
  private acting = false;

  /** The status line a Rotate Keys or a Register wrote, or `''`. */
  private actionNotice = '';

  /** The refusal a row action was answered with, or `''` (AD-39). */
  private actionRefusal = '';

  constructor() {
    const stopStore = this.store.subscribe(() => this.bump());
    const stopDirty = this.formDirty.subscribe(() => this.bump());
    let followed = this.routeId();
    void this.store.open(followed);
    const stopIdChange = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      const id = this.routeId();
      if (id === followed) return;
      followed = id;
      this.clearAction();
      void this.store.open(id);
    });
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      stopIdChange.unsubscribe();
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

  protected get storedName(): string {
    this.generation();
    return this.store.storedName();
  }

  protected get generalControls(): readonly Control[] {
    this.generation();
    const editing = this.store.mode() === 'edit';
    return [
      this.textControl(NAME_FIELD, STRINGS.oauthClientFieldName, 'text', editing),
      this.memberInput('client_name', STRINGS.processDetailsClientName, 'text'),
      this.textControl(DESCRIPTION_FIELD, STRINGS.tableColumnDescription, 'text'),
      this.checkControl(ENABLED_FIELD, STRINGS.tableColumnEnabled, this.store.enabled()),
      this.selectControl(TYPE_FIELD, STRINGS.oauthColumnClientType, this.store.text('clientType'), [
        { value: 'confidential', label: STRINGS.oauthClientTypeConfidential },
        { value: 'public', label: STRINGS.oauthClientTypePublic },
        { value: 'resource', label: STRINGS.oauthClientTypeResource },
      ]),
      this.sslControl(),
      this.serverControl(),
      this.textControl(REDIRECT_FIELD, STRINGS.oauthClientFieldRedirect, 'url'),
      this.memberInput('frontchannel_logout_uri', STRINGS.oauthClientFieldLogoutUri, 'url'),
      this.checkControl(memberField('frontchannel_logout_session_required'), STRINGS.oauthClientFieldLogoutSession, this.store.memberFlag('frontchannel_logout_session_required')),
    ];
  }

  protected get grantControls(): readonly Control[] {
    this.generation();
    const held = this.store.memberList(GRANT_MEMBER);
    return GRANT_TYPES.map((grant) => ({
      ...this.base(`grant:${grant}`, `${ID_PREFIX}-grant-${grant}`, GRANT_LABELS[grant] ?? grant),
      isCheck: true,
      checked: held.includes(grant),
    }));
  }

  protected get authControls(): readonly Control[] {
    this.generation();
    const method = this.store.memberText('token_endpoint_auth_method');
    const methods = AUTH_METHODS.includes(method) || method === '' ? AUTH_METHODS : [...AUTH_METHODS, method];
    return [
      this.selectControl(memberField('token_endpoint_auth_method'), STRINGS.oauthClientFieldAuthMethod, method, this.withNotSet(methods)),
      this.memberSelect('token_endpoint_auth_signing_alg', STRINGS.oauthClientFieldAuthSigning),
      this.textControl(AUDIENCE_FIELD, STRINGS.oauthClientFieldAudience, 'text'),
    ];
  }

  protected get informationControls(): readonly Control[] {
    this.generation();
    return [
      this.memberInput('logo_uri', STRINGS.oauthClientFieldLogo, 'url'),
      this.memberInput('client_uri', STRINGS.oauthClientFieldHome, 'url'),
      this.memberInput('policy_uri', STRINGS.oauthClientFieldPolicy, 'url'),
      this.memberInput('tos_uri', STRINGS.oauthClientFieldTos, 'url'),
      this.textControl(SCOPE_FIELD, STRINGS.oauthColumnDefaultScope, 'text'),
      { ...this.base(memberField('contacts'), idFor(memberField('contacts')), STRINGS.oauthClientFieldContacts), isInput: true, inputType: 'text', value: this.store.memberList('contacts').join(', ') },
      this.memberInput('default_max_age', STRINGS.oauthClientFieldMaxAge, 'text'),
    ];
  }

  protected get jwtControls(): readonly Control[] {
    this.generation();
    const alias = this.store.text('credentials');
    const aliases = this.store.credentialAliases();
    const options = aliases.includes(alias) || alias === '' ? aliases : [...aliases, alias];
    return [
      this.textControl(INTERVAL_FIELD, STRINGS.oauthClientFieldInterval, 'text'),
      this.selectControl(CREDENTIALS_FIELD, STRINGS.oauthClientFieldCredentials, alias, this.withNotSet(options)),
      this.secretControl(PASSWORD_FIELD, STRINGS.x509FieldPrivateKeyPassword),
    ];
  }

  protected get algorithmGroups(): readonly AlgorithmGroup[] {
    this.generation();
    return ALGORITHM_GROUPS.map((group, index) => ({
      id: `${ID_PREFIX}-algorithms-${index + 1}`,
      legend: group.legend,
      controls: group.members.map((member, column) => this.memberSelect(member, ALGORITHM_COLUMNS[column] ?? member)),
    }));
  }

  protected get credentialControls(): readonly Control[] {
    this.generation();
    return [
      this.textControl(CLIENT_ID_FIELD, STRINGS.oauthColumnClientId, 'text'),
      this.secretControl(SECRET_FIELD, STRINGS.oauthClientFieldSecret),
      this.secretControl(REGISTRATION_TOKEN_FIELD, STRINGS.oauthServerFieldToken),
      this.secretControl(INITIAL_TOKEN_FIELD, STRINGS.oauthClientFieldInitialToken),
      this.readOnlyMember('client_id_issued_at', STRINGS.oauthClientFieldIssuedAt),
      this.readOnlyMember('client_secret_expires_at', STRINGS.oauthClientFieldExpiresAt),
      this.readOnlyMember('registration_client_uri', STRINGS.oauthClientFieldRegistrationUri),
    ];
  }

  protected get metadataRows(): readonly MetadataRow[] {
    this.generation();
    return this.store
      .members()
      .filter((entry) => !DRAWN_MEMBERS.includes(entry.name))
      .map((entry) => ({ name: entry.name, value: displayOf(this.store.member(entry.name)) }));
  }

  protected get saveBlocked(): boolean {
    this.generation();
    return !this.store.canSave() || this.acting;
  }

  protected get actionBlocked(): boolean {
    this.generation();
    return this.store.busy() || this.acting;
  }

  /** Delete is offered on a held edit alone. */
  protected get offersDelete(): boolean {
    this.generation();
    return this.store.mode() === 'edit' && this.store.held();
  }

  /** Rotate Keys is offered on a saved, unchanged client with no X.509 credentials. */
  protected get offersRotate(): boolean {
    this.generation();
    return this.offersDelete && !this.store.dirty() && this.store.storedCredentials() === '';
  }

  /**
   * Register is offered on a saved, unchanged client with no client ID and no registration URI,
   * whose server description has a registration endpoint.
   */
  protected get offersRegister(): boolean {
    this.generation();
    return (
      this.offersDelete &&
      !this.store.dirty() &&
      this.store.storedClientId() === '' &&
      this.store.storedRegistrationUri() === '' &&
      this.store.registrationEndpoint() !== ''
    );
  }

  protected get deletePending(): boolean {
    this.generation();
    return this.deleting;
  }

  protected get deleteVerb(): string {
    return actionLabel(OAUTH_CLIENT_TAB_DESCRIPTOR, DELETE_ACTION);
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
   * save's published sentence, a row action's own refusal, or the envelope's own reason.
   */
  protected get reason(): string {
    this.generation();
    if (this.actionRefusal !== '') return this.actionRefusal;
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') {
      const action = this.store.mode() === 'create' ? STRINGS.oauthClientsEmptyAgent : STRINGS.oauthClientFormRefusedAction;
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, action);
    }
    if (this.store.refusalCode() === STATE_CONFLICT_CODE) return STRINGS.formStaleSave;
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  /** The status line: a row action's report, or "Saved" with what did not land beside it. */
  protected get status(): string {
    this.generation();
    if (this.actionNotice !== '') return this.actionNotice;
    if (!this.store.saved()) return '';
    const lines: string[] = [];
    const refused = this.store.secretsRefused();
    if (refused !== '') lines.push(STRINGS.oauthClientSecretsRefused.split('<reason>').join(refused));
    const notUpdated = this.store.registrationNotUpdated();
    if (notUpdated !== '') {
      lines.push(STRINGS.oauthClientRegistrationNotUpdated.split('<issuer>').join(this.store.storedIssuer()).split('<reason>').join(notUpdated));
    }
    return lines.length === 0 ? STRINGS.formSaved : lines.join(' ');
  }

  protected get hasStatus(): boolean {
    return this.status !== '';
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onInput(control: Control, value: string): void {
    const key = TEXT_KEYS[control.field];
    if (key !== undefined) {
      this.store.setText(key, value);
      return;
    }
    if (SECRET_FIELDS.includes(control.field)) {
      this.store.setSecret(control.field, value);
      return;
    }
    if (control.field === memberField('contacts')) {
      this.store.setMemberCsv('contacts', value);
      return;
    }
    if (control.field.startsWith('Metadata.')) this.store.setMemberText(control.field.slice('Metadata.'.length), value);
  }

  protected onCheck(control: Control, checked: boolean): void {
    if (control.field === ENABLED_FIELD) {
      this.store.setEnabled(checked);
      return;
    }
    if (control.field.startsWith('grant:')) {
      this.store.setGrant(control.field.slice('grant:'.length), checked);
      return;
    }
    if (control.field.startsWith('Metadata.')) this.store.setMemberFlag(control.field.slice('Metadata.'.length), checked);
  }

  protected onBlur(field: string): void {
    this.store.onBlur(field);
  }

  protected async onSave(): Promise<void> {
    if (this.saveBlocked) return;
    this.clearAction();
    const creating = this.store.mode() === 'create';
    const saved = await this.store.save();
    if (!saved) {
      this.afterRefusal();
      return;
    }
    // A create replaces the route with the configuration's own URL, so the address bar names the
    // entity; the page is built again there over its edit.
    const id = this.store.savedId();
    if (id !== '' && creating) {
      this.store.retainAcrossRouteReplacement();
      void this.router.navigateByUrl(this.editorUrl(id), { replaceUrl: true });
    }
  }

  /** Register: the tab's declared action, sent as its row menu sends it (AD-53). */
  protected async onRegister(): Promise<void> {
    if (!this.offersRegister || this.actionBlocked) return;
    const name = this.store.storedName();
    this.clearAction();
    this.acting = true;
    this.bump();
    const applied = await this.handler.sendFor(OAUTH_CLIENT_TAB_DESCRIPTOR, REGISTER_ACTION, name);
    this.acting = false;
    if (!applied) {
      this.actionRefusal = this.tabRefusal();
      this.bump();
      return;
    }
    // The registration replaced the client ID, so the form reads the configuration again.
    await this.store.open(name);
    this.actionNotice = STRINGS.oauthClientRegistered.split('<issuer>').join(this.store.storedIssuer()).split('<clientId>').join(this.store.storedClientId());
    this.bump();
  }

  /** Rotate Keys: the tab's declared action, sent as its row menu sends it (AD-53). */
  protected async onRotate(): Promise<void> {
    if (!this.offersRotate || this.actionBlocked) return;
    const name = this.store.storedName();
    this.clearAction();
    this.acting = true;
    this.bump();
    const applied = await this.handler.sendFor(OAUTH_CLIENT_TAB_DESCRIPTOR, ROTATE_ACTION, name);
    this.acting = false;
    if (!applied) {
      this.actionRefusal = this.tabRefusal();
      this.bump();
      return;
    }
    // The rotation replaced the key set, so the form reads the configuration again.
    await this.store.open(name);
    this.actionNotice = STRINGS.oauthClientKeysRotated;
    this.bump();
  }

  protected onDelete(): void {
    if (!this.offersDelete || this.actionBlocked) return;
    this.clearAction();
    this.deleting = true;
    this.bump();
  }

  protected cancelDelete(): void {
    this.deleting = false;
    this.bump();
  }

  /** The typed name matched: send the tab's declared delete, then return to the tab (AD-53). */
  protected async confirmDelete(): Promise<void> {
    this.deleting = false;
    this.acting = true;
    this.bump();
    const applied = await this.handler.sendFor(OAUTH_CLIENT_TAB_DESCRIPTOR, DELETE_ACTION, this.store.storedName());
    this.acting = false;
    if (!applied) {
      this.actionRefusal = this.tabRefusal();
      this.bump();
      return;
    }
    this.formDirty.setDirty(false);
    void this.router.navigateByUrl(withQuery(OAUTH_CLIENT_TAB_ROUTE, this.router.url));
  }

  protected focusField(field: string): void {
    document.getElementById(this.controlId(field))?.focus();
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(OAUTH_CLIENT_TAB_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  private clearAction(): void {
    this.actionNotice = '';
    this.actionRefusal = '';
  }

  /** The sentence the tab's action route refused with, which the handler puts on the tab's store. */
  private tabRefusal(): string {
    const tab = screenForRoute(OAUTH_CLIENT_TAB_ROUTE);
    return tab === null ? '' : this.stores.for(tab.descriptor, tab.refreshRates).refusal();
  }

  /** The name this route names, or `''` for the create. */
  private routeId(): string {
    const screen = screenForRoute(OAUTH_CLIENT_FORM_ROUTE);
    return screen === null ? '' : ownIdSegment(screen, this.router.url);
  }

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

  /** A control with no value, for `field` with control `id` and `label`, and its refusal wired. */
  private base(field: string, id: string, label: string): Control {
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

  private textControl(field: string, label: string, inputType: string, readOnly = false): Control {
    const key = TEXT_KEYS[field];
    return { ...this.base(field, idFor(field), label), isInput: true, inputType, readOnly, value: key === undefined ? '' : this.store.text(key) };
  }

  private memberInput(member: string, label: string, inputType: string): Control {
    const field = memberField(member);
    return { ...this.base(field, idFor(field), label), isInput: true, inputType, value: this.store.memberText(member) };
  }

  private readOnlyMember(member: string, label: string): Control {
    return { ...this.memberInput(member, label, 'text'), readOnly: true };
  }

  private checkControl(field: string, label: string, checked: boolean): Control {
    return { ...this.base(field, idFor(field), label), isCheck: true, checked };
  }

  private selectControl(field: string, label: string, value: string, options: readonly Option[]): Control {
    return { ...this.base(field, idFor(field), label), isSelect: true, value, options };
  }

  /** A fixed member's select: "Not set" and its values, the stored value kept if it is another. */
  private memberSelect(member: string, label: string): Control {
    const value = this.store.memberText(member);
    const values = this.store.valuesOf(member);
    const all = values.includes(value) || value === '' ? values : [...values, value];
    return this.selectControl(memberField(member), label, value, this.withNotSet(all));
  }

  private secretControl(field: string, label: string): Control {
    const id = idFor(field);
    const own = this.base(field, id, label);
    return {
      ...own,
      isInput: true,
      isSecret: true,
      inputType: 'password',
      value: this.store.secret(field),
      hasHint: true,
      describedBy: own.invalid ? `${id}-hint ${id}-reason` : `${id}-hint`,
    };
  }

  private sslControl(): Control {
    const value = this.store.text('ssl');
    const names = this.store.sslConfigurations();
    return this.selectControl(SSL_FIELD, STRINGS.oauthServerFieldSsl, value, this.withNotSet(names.includes(value) || value === '' ? names : [...names, value]));
  }

  private serverControl(): Control {
    const value = this.store.text('server');
    const options: Option[] = this.store.serverDescriptions().map((entry) => ({ value: entry.id, label: entry.issuer || entry.id }));
    if (value !== '' && !options.some((option) => option.value === value)) options.push({ value, label: value });
    return this.selectControl(SERVER_FIELD, STRINGS.oauthServerFormLabel, value, [{ value: '', label: STRINGS.oauthClientNotSet }, ...options]);
  }

  private withNotSet(values: readonly string[]): readonly Option[] {
    return [{ value: '', label: STRINGS.oauthClientNotSet }, ...values.map((value) => ({ value, label: value }))];
  }

  /**
   * A field's control id. A metadata member the form draws no control for is refused on the
   * metadata table, which takes focus in its place; so is `Metadata` itself.
   */
  private controlId(field: string): string {
    if (field === 'Metadata') return `${ID_PREFIX}-metadata`;
    const member = field.startsWith('Metadata.') ? field.slice('Metadata.'.length) : '';
    if (member === GRANT_MEMBER) return this.grantsId;
    if (member !== '' && !DRAWN_MEMBERS.includes(member)) return `${ID_PREFIX}-metadata`;
    return idFor(field);
  }

  /** The configuration's own URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private editorUrl(id: string): string {
    const editor = this.navigation.screenForUrl(this.router.url);
    const route = editor === null ? OAUTH_CLIENT_FORM_ROUTE : editor.route;
    return withQuery(`${route}/${encodeEntityId(id)}`, this.router.url);
  }
}
