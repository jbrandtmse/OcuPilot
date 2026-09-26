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
import { savedLine, withReadBack } from '../../core/read-back';
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
  ALGORITHM_GROUPS,
  AUTH_MEMBER,
  AUTH_METHODS,
  AUTH_SIGNING_MEMBER,
  CLIENT_ID_FIELD,
  CLIENT_NAME_MEMBER,
  CONTACTS_MEMBER,
  CREDENTIALS_FIELD,
  CREDENTIALS_TAB,
  DESCRIPTION_FIELD,
  GENERAL_TAB,
  GRANT_MEMBER,
  GRANT_TYPES,
  INFORMATION_TAB,
  JWKS_MEMBER,
  JWT_AUTH_METHODS,
  JWT_GRANT,
  JWT_TAB,
  type KeySource,
  LAUNCH_FIELD,
  LOGOUT_MEMBER,
  MAX_AGE_MEMBER,
  METADATA_FIELD,
  NAME_FIELD,
  OAuthRegisteredClientForm,
  REDIRECT_FIELD,
  REGISTERED_CLIENT_FIELD_ORDER,
  REGISTERED_CLIENT_FIELD_TABS,
  RESOURCE_TYPE,
  RESPONSE_MEMBER,
  RESPONSE_TYPES,
  SCOPE_FIELD,
  SECRET_FIELD,
  SESSION_MEMBER,
  type TextKey,
  TYPE_FIELD,
  URL_MEMBERS,
  generateSecret,
  memberField,
} from './oauth-registered-client-form.store';

/** The tab this form is reached from, which Cancel and a delete return to. */
export const OAUTH_REGISTERED_CLIENT_TAB_ROUTE = 'security/oauth/server-clients';

/** This form's own route, the fallback when the mirror cannot resolve it from the URL. */
export const OAUTH_REGISTERED_CLIENT_FORM_ROUTE = 'security/oauth/server-clients/edit';

/** The tab whose declared Delete and Update JWKS this page sends (AD-53). */
export const OAUTH_REGISTERED_CLIENT_TAB_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.OAuthServerClientTab';

export const DELETE_ACTION = 'delete';

export const UPDATE_JWKS_ACTION = 'updatejwks';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** The id every control's own id begins with. */
const ID_PREFIX = 'ocu-oauth-registered-client';

/** The text fields, keyed by the wire field, each with the store key it edits. */
const TEXT_KEYS: Readonly<Record<string, TextKey>> = {
  [NAME_FIELD]: 'name',
  [DESCRIPTION_FIELD]: 'description',
  [TYPE_FIELD]: 'clientType',
  [LAUNCH_FIELD]: 'launchUrl',
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

/** The display URLs' labels, by member. */
const URL_LABELS: Readonly<Record<string, string>> = {
  logo_uri: STRINGS.oauthClientFieldLogo,
  client_uri: STRINGS.oauthClientFieldHome,
  policy_uri: STRINGS.oauthClientFieldPolicy,
  tos_uri: STRINGS.oauthClientFieldTos,
};

/** The four algorithm groups' legends, and each group's three columns, in the classic page's order. */
const ALGORITHM_LEGENDS: readonly string[] = [STRINGS.oauthClientAlgIdToken, STRINGS.oauthClientAlgUserinfo, STRINGS.oauthClientAlgAccessToken, STRINGS.oauthClientAlgRequest];

const ALGORITHM_COLUMNS: readonly string[] = [STRINGS.oauthClientAlgSigning, STRINGS.oauthClientAlgEncryption, STRINGS.oauthClientAlgKey];

/** The value every algorithm list uses for no algorithm. */
const NO_ALGORITHM = 'none';

/** The public key source's control, which no wire field carries. */
const KEY_SOURCE_FIELD = 'keySource';

type Control = ClientFieldControl;

type Option = ClientFieldOption;

/** One algorithm group, resolved for drawing. */
interface AlgorithmGroup {
  readonly id: string;
  readonly legend: string;
  readonly controls: readonly Control[];
}

/** One redirect URL row, resolved for drawing. */
interface RedirectRow {
  readonly index: number;
  readonly id: string;
  readonly value: string;
}

/** A control's id for `field`: `Metadata.x` as `Metadata-x`. */
function idFor(field: string): string {
  return `${ID_PREFIX}-${field.replace(/[^A-Za-z0-9_-]/g, '-')}`;
}

/**
 * The OAuth 2.0 server client description editor, a tabbed `form-page` that registers a client on
 * `security/oauth/server-clients/edit` and edits one on `security/oauth/server-clients/edit/<clientId>`
 * (AD-55).
 *
 * **Its four tabs are the classic editor's** (`%CSP.UI.Portal.OAuth2.Server.Client`), on
 * `app-form-tabs` (UX-DR33): General, Client Credentials, Client Information and JWT Settings. A
 * refused Save opens the tab that holds the first refused field.
 *
 * **The client secret is masked and never pre-filled.** Generate fills the field with a new random
 * secret and Show reveals the field's own value; nothing else ever reads it (AD-35).
 *
 * **Update JWKS and Delete are the tab's own declared actions**, sent through the shell's handler
 * exactly as its row menu sends them (AD-53). Update JWKS is offered on a saved, unchanged client whose
 * stored JWKS URL is not empty; Delete types the client id first.
 *
 * It composes no payload and authors no field sentence. Every control-flow condition is a paren-free
 * member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-oauth-registered-client-form-page',
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
        <div class="ocu-form-fields ocu-oauth-registered-client-tab">
          @for (control of generalControls; track control.id) {
            <app-oauth-client-field [control]="control" [locked]="locked" (edited)="onInput(control, $event)" (left)="onBlur(control.field)" />
          }
          @if (showsRedirects) {
            <fieldset class="ocu-field ocu-oauth-registered-client-group" [id]="redirectsId" tabindex="-1" [attr.aria-describedby]="redirectsDescribedBy">
              <legend class="ocu-field-label" [class.ocu-field-label-required]="redirectsRequired">{{ STRINGS.oauthColumnRedirectUrls }}</legend>
              @for (row of redirectRows; track row.index) {
                <div class="ocu-oauth-registered-client-row">
                  <input
                    class="ocu-field-input"
                    type="url"
                    spellcheck="false"
                    autocomplete="off"
                    [id]="row.id"
                    [value]="row.value"
                    [readOnly]="locked"
                    [attr.aria-label]="STRINGS.oauthColumnRedirectUrls"
                    [attr.aria-invalid]="redirectsInvalid"
                    (input)="onRedirect(row.index, $event)"
                  />
                  <button type="button" class="ocu-button-text" [attr.aria-disabled]="locked" (click)="removeRedirect(row.index)">{{ STRINGS.actionRemove }}</button>
                </div>
              }
              <div class="ocu-oauth-registered-client-row">
                <button type="button" class="ocu-button-secondary" [id]="addRedirectId" [attr.aria-disabled]="locked" (click)="addRedirect()">{{ STRINGS.oauthRegisteredClientAddRedirect }}</button>
              </div>
              @if (redirectsInvalid) {
                <p class="ocu-form-error" [id]="redirectsId + '-reason'">{{ redirectsReason }}</p>
              }
            </fieldset>
          }
          <fieldset class="ocu-field ocu-oauth-registered-client-group" [id]="grantsId" tabindex="-1" [attr.aria-describedby]="grantsDescribedBy">
            <legend class="ocu-field-label" [class.ocu-field-label-required]="grantsRequired">{{ STRINGS.oauthColumnGrantTypes }}</legend>
            @for (control of grantControls; track control.id) {
              <app-oauth-client-field [control]="control" [locked]="locked" (toggled)="onCheck(control, $event)" />
            }
            @if (grantsInvalid) {
              <p class="ocu-form-error" [id]="grantsId + '-reason'">{{ grantsReason }}</p>
            }
          </fieldset>
          <fieldset class="ocu-field ocu-oauth-registered-client-group" [id]="responsesId" tabindex="-1" [attr.aria-describedby]="responsesDescribedBy">
            <legend class="ocu-field-label" [class.ocu-field-label-required]="responsesRequired">{{ STRINGS.oauthRegisteredClientFieldResponseTypes }}</legend>
            @for (control of responseControls; track control.id) {
              <app-oauth-client-field [control]="control" [locked]="locked" (toggled)="onCheck(control, $event)" />
            }
            @if (responsesInvalid) {
              <p class="ocu-form-error" [id]="responsesId + '-reason'">{{ responsesReason }}</p>
            }
          </fieldset>
          @for (control of authControls; track control.id) {
            <app-oauth-client-field [control]="control" [locked]="locked" (edited)="onInput(control, $event)" />
          }
        </div>
      </ng-template>

      <ng-template ocuFormTab="credentials">
        <div class="ocu-form-fields ocu-oauth-registered-client-tab">
          @for (control of clientIdControls; track control.id) {
            <app-oauth-client-field [control]="control" [locked]="locked" />
          }
          <div class="ocu-field">
            <label class="ocu-field-label" [class.ocu-field-label-required]="secretRequired" [attr.for]="secretId">{{ STRINGS.oauthClientFieldSecret }}</label>
            <div class="ocu-oauth-registered-client-row">
              <input
                class="ocu-field-input"
                spellcheck="false"
                autocomplete="new-password"
                [type]="secretType"
                [id]="secretId"
                [value]="secretValue"
                [readOnly]="locked"
                [attr.aria-required]="secretRequiredOrNull"
                [attr.aria-invalid]="secretInvalid"
                [attr.aria-describedby]="secretDescribedBy"
                (input)="onSecret($event)"
              />
              <button type="button" class="ocu-button-secondary" [id]="generateId" [attr.aria-controls]="secretId" [attr.aria-disabled]="locked" (click)="onGenerate()">{{ STRINGS.oauthRegisteredClientGenerate }}</button>
              <button type="button" class="ocu-button-text" [id]="revealId" [attr.aria-controls]="secretId" [attr.aria-pressed]="revealed()" (click)="toggleReveal()">{{ revealLabel }}</button>
            </div>
            @if (secretHinted) {
              <p class="ocu-field-caption" [id]="secretId + '-hint'">{{ STRINGS.oauthClientSecretHint }}</p>
              <p class="ocu-field-caption" [id]="secretId + '-effect'">{{ STRINGS.oauthRegisteredClientSecretEffect }}</p>
            }
            @if (secretInvalid) {
              <p class="ocu-form-error" [id]="secretId + '-reason'">{{ secretReason }}</p>
            }
          </div>
        </div>
      </ng-template>

      <ng-template ocuFormTab="information">
        <div class="ocu-form-fields ocu-oauth-registered-client-tab" [id]="informationId" tabindex="-1">
          @for (control of informationControls; track control.id) {
            <app-oauth-client-field [control]="control" [locked]="locked" (edited)="onInput(control, $event)" (toggled)="onCheck(control, $event)" (left)="onBlur(control.field)" />
          }
        </div>
      </ng-template>

      <ng-template ocuFormTab="jwt">
        <div class="ocu-form-fields ocu-oauth-registered-client-tab">
          @for (control of keyControls; track control.id) {
            <app-oauth-client-field [control]="control" [locked]="locked" (edited)="onInput(control, $event)" />
          }
          @for (group of algorithmGroups; track group.id) {
            <fieldset class="ocu-field ocu-oauth-registered-client-group" [id]="group.id">
              <legend class="ocu-field-label">{{ group.legend }}</legend>
              @for (control of group.controls; track control.id) {
                <app-oauth-client-field [control]="control" [locked]="locked" (edited)="onInput(control, $event)" />
              }
            </fieldset>
          }
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
        @if (offersDelete) {
          <button type="button" class="ocu-button-text" [attr.aria-disabled]="actionBlocked" (click)="onDelete()">
            {{ STRINGS.actionDelete }}
          </button>
        }
        @if (offersUpdateJwks) {
          <button type="button" class="ocu-button-secondary" [attr.aria-disabled]="actionBlocked" (click)="onUpdateJwks()">
            {{ STRINGS.oauthServerUpdateJwks }}
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
        class="ocu-oauth-registered-client-delete"
        [verb]="deleteVerb"
        [target]="storedClientId"
        [consequence]="STRINGS.oauthServerClientDeleteConsequence"
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
export class OAuthRegisteredClientFormPage {
  private readonly store = inject(OAuthRegisteredClientForm);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly handler = inject(ScreenActionHandler);
  private readonly stores = inject(ScreenStores);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  protected readonly redirectsId = idFor(REDIRECT_FIELD);
  protected readonly addRedirectId = `${ID_PREFIX}-add-redirect`;
  protected readonly grantsId = idFor(memberField(GRANT_MEMBER));
  protected readonly responsesId = idFor(memberField(RESPONSE_MEMBER));
  protected readonly secretId = idFor(SECRET_FIELD);
  protected readonly generateId = `${ID_PREFIX}-generate`;
  protected readonly revealId = `${ID_PREFIX}-reveal`;
  protected readonly informationId = `${ID_PREFIX}-information`;

  /** The key of the tab on screen. */
  protected readonly selectedTab = signal(GENERAL_TAB);

  /** Whether the secret field shows its own value. */
  protected readonly revealed = signal(false);

  /** Bumped by the stores and this page's own state, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  private focusedSummary = false;

  private deleting = false;

  /** Whether a Delete or an Update JWKS is in flight. */
  private acting = false;

  /** The status line an Update JWKS wrote, or `''`. */
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
      this.revealed.set(false);
      this.selectedTab.set(GENERAL_TAB);
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

  protected get storedClientId(): string {
    this.generation();
    return this.store.storedClientId();
  }

  protected get tabs(): readonly FormTabView[] {
    this.generation();
    const counts = tabErrorCounts(REGISTERED_CLIENT_FIELD_TABS, this.store.violations());
    return [
      { key: GENERAL_TAB, label: STRINGS.processDetailsGroupGeneral, count: counts[GENERAL_TAB] ?? 0 },
      { key: CREDENTIALS_TAB, label: STRINGS.oauthClientSectionCredentials, count: counts[CREDENTIALS_TAB] ?? 0 },
      { key: INFORMATION_TAB, label: STRINGS.oauthClientSectionClientInformation, count: counts[INFORMATION_TAB] ?? 0 },
      { key: JWT_TAB, label: STRINGS.oauthClientSectionJwt, count: counts[JWT_TAB] ?? 0 },
    ];
  }

  protected get generalControls(): readonly Control[] {
    this.generation();
    return [
      this.textControl(NAME_FIELD, STRINGS.tableColumnName),
      this.textControl(DESCRIPTION_FIELD, STRINGS.tableColumnDescription),
      this.selectControl(TYPE_FIELD, STRINGS.oauthColumnClientType, this.store.text('clientType'), [
        { value: 'confidential', label: STRINGS.oauthClientTypeConfidential },
        { value: 'public', label: STRINGS.oauthClientTypePublic },
        { value: RESOURCE_TYPE, label: STRINGS.oauthClientTypeResource },
      ]),
    ];
  }

  /** The redirect URLs are drawn for every client type but a resource server, which has none. */
  protected get showsRedirects(): boolean {
    this.generation();
    return this.store.text('clientType') !== RESOURCE_TYPE;
  }

  protected get redirectRows(): readonly RedirectRow[] {
    this.generation();
    return this.store.redirects().map((value, index) => ({ index, id: `${this.redirectsId}-${index + 1}`, value }));
  }

  protected get redirectsRequired(): boolean {
    this.generation();
    return this.store.required(REDIRECT_FIELD);
  }

  protected get redirectsReason(): string {
    this.generation();
    return this.store.violationFor(REDIRECT_FIELD);
  }

  protected get redirectsInvalid(): boolean {
    return this.redirectsReason !== '';
  }

  protected get redirectsDescribedBy(): string | null {
    return this.redirectsInvalid ? `${this.redirectsId}-reason` : null;
  }

  protected get grantControls(): readonly Control[] {
    this.generation();
    const held = this.store.memberList(GRANT_MEMBER);
    return GRANT_TYPES.map((grant) => ({ ...this.base(`grant:${grant}`, `${ID_PREFIX}-grant-${grant}`, GRANT_LABELS[grant] ?? grant), isCheck: true, checked: held.includes(grant) }));
  }

  protected get grantsRequired(): boolean {
    this.generation();
    return this.store.required(memberField(GRANT_MEMBER));
  }

  protected get grantsReason(): string {
    this.generation();
    return this.store.violationFor(memberField(GRANT_MEMBER));
  }

  protected get grantsInvalid(): boolean {
    return this.grantsReason !== '';
  }

  protected get grantsDescribedBy(): string | null {
    return this.grantsInvalid ? `${this.grantsId}-reason` : null;
  }

  protected get responseControls(): readonly Control[] {
    this.generation();
    const held = this.store.memberList(RESPONSE_MEMBER);
    return RESPONSE_TYPES.map((type) => ({ ...this.base(`response:${type}`, `${ID_PREFIX}-response-${type.replace(' ', '-')}`, type), isCheck: true, checked: held.includes(type) }));
  }

  protected get responsesRequired(): boolean {
    this.generation();
    return this.store.required(memberField(RESPONSE_MEMBER));
  }

  protected get responsesReason(): string {
    this.generation();
    return this.store.violationFor(memberField(RESPONSE_MEMBER));
  }

  protected get responsesInvalid(): boolean {
    return this.responsesReason !== '';
  }

  protected get responsesDescribedBy(): string | null {
    return this.responsesInvalid ? `${this.responsesId}-reason` : null;
  }

  /** The authentication type, and its signing algorithm for the two JWT methods and the JWT grant. */
  protected get authControls(): readonly Control[] {
    this.generation();
    const method = this.store.memberText(AUTH_MEMBER);
    const methods = AUTH_METHODS.includes(method) || method === '' ? AUTH_METHODS : [...AUTH_METHODS, method];
    const controls: Control[] = [this.selectControl(memberField(AUTH_MEMBER), STRINGS.oauthRegisteredClientFieldAuthType, method, this.withNotSet(methods))];
    if (JWT_AUTH_METHODS.includes(method) || this.store.memberList(GRANT_MEMBER).includes(JWT_GRANT)) {
      controls.push(this.algorithmSelect(AUTH_SIGNING_MEMBER, STRINGS.oauthClientFieldAuthSigning));
    }
    return controls;
  }

  /** The client id the instance generated: read-only, and blank on a create. */
  protected get clientIdControls(): readonly Control[] {
    this.generation();
    return [{ ...this.base(CLIENT_ID_FIELD, idFor(CLIENT_ID_FIELD), STRINGS.oauthColumnClientId), isInput: true, readOnly: true, value: this.store.storedClientId() }];
  }

  protected get secretValue(): string {
    this.generation();
    return this.store.secret();
  }

  protected get secretType(): string {
    return this.revealed() ? 'text' : 'password';
  }

  protected get revealLabel(): string {
    return this.revealed() ? STRINGS.oauthRegisteredClientHide : STRINGS.oauthRegisteredClientShow;
  }

  protected get secretRequired(): boolean {
    this.generation();
    return this.store.required(SECRET_FIELD);
  }

  protected get secretRequiredOrNull(): true | null {
    return this.secretRequired ? true : null;
  }

  /**
   * The shared "leave empty to keep" hint, and the effect a new secret has on the client's application,
   * apply to an edit alone: a create has no stored secret to keep or replace.
   */
  protected get secretHinted(): boolean {
    this.generation();
    return this.store.mode() === 'edit';
  }

  protected get secretReason(): string {
    this.generation();
    return this.store.violationFor(SECRET_FIELD);
  }

  protected get secretInvalid(): boolean {
    return this.secretReason !== '';
  }

  protected get secretDescribedBy(): string | null {
    const ids: string[] = [];
    if (this.secretHinted) ids.push(`${this.secretId}-hint`, `${this.secretId}-effect`);
    if (this.secretInvalid) ids.push(`${this.secretId}-reason`);
    return ids.length === 0 ? null : ids.join(' ');
  }

  protected get informationControls(): readonly Control[] {
    this.generation();
    return [
      this.textControl(LAUNCH_FIELD, STRINGS.oauthRegisteredClientFieldLaunchUrl, 'url'),
      this.memberInput(CLIENT_NAME_MEMBER, STRINGS.processDetailsClientName, 'text'),
      ...URL_MEMBERS.map((member) => this.memberInput(member, URL_LABELS[member] ?? member, 'url')),
      { ...this.base(memberField(CONTACTS_MEMBER), idFor(memberField(CONTACTS_MEMBER)), STRINGS.oauthRegisteredClientFieldContacts), isInput: true, value: this.store.memberList(CONTACTS_MEMBER).join(', ') },
      this.memberInput(MAX_AGE_MEMBER, STRINGS.oauthClientFieldMaxAge, 'text'),
      this.textControl(SCOPE_FIELD, STRINGS.oauthColumnDefaultScope),
      this.memberInput(LOGOUT_MEMBER, STRINGS.oauthClientFieldLogoutUri, 'url'),
      { ...this.base(memberField(SESSION_MEMBER), idFor(memberField(SESSION_MEMBER)), STRINGS.oauthRegisteredClientFieldLogoutSessionRequired), isCheck: true, checked: this.store.memberFlag(SESSION_MEMBER) },
    ];
  }

  /** The public key source, then the JWKS URL or the X.509 credentials it names. */
  protected get keyControls(): readonly Control[] {
    this.generation();
    const source = this.store.keySource();
    const controls: Control[] = [
      this.selectControl(KEY_SOURCE_FIELD, STRINGS.oauthRegisteredClientFieldKeySource, source, [
        { value: 'none', label: STRINGS.sslVerifyPeerNone },
        { value: 'jwks', label: STRINGS.oauthRegisteredClientKeySourceJwks },
        { value: 'x509', label: STRINGS.oauthClientFieldCredentials },
      ]),
    ];
    if (source === 'jwks') controls.push(this.memberInput(JWKS_MEMBER, STRINGS.oauthRegisteredClientKeySourceJwks, 'url'));
    if (source === 'x509') {
      const alias = this.store.text('credentials');
      const aliases = this.store.credentialAliases();
      controls.push(this.selectControl(CREDENTIALS_FIELD, STRINGS.oauthClientFieldCredentials, alias, this.withNotSet(aliases.includes(alias) || alias === '' ? aliases : [...aliases, alias])));
    }
    return controls;
  }

  protected get algorithmGroups(): readonly AlgorithmGroup[] {
    this.generation();
    return ALGORITHM_GROUPS.map((members, index) => ({
      id: `${ID_PREFIX}-algorithms-${index + 1}`,
      legend: ALGORITHM_LEGENDS[index] ?? '',
      controls: members.map((member, column) => this.algorithmSelect(member, ALGORITHM_COLUMNS[column] ?? member)),
    }));
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

  /** Update JWKS is offered on a saved, unchanged client whose stored JWKS URL is not empty. */
  protected get offersUpdateJwks(): boolean {
    this.generation();
    return this.offersDelete && !this.store.dirty() && this.store.storedJwksUri() !== '';
  }

  protected get deletePending(): boolean {
    this.generation();
    return this.deleting;
  }

  protected get deleteVerb(): string {
    return actionLabel(OAUTH_REGISTERED_CLIENT_TAB_DESCRIPTOR, DELETE_ACTION);
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
      const action = this.store.mode() === 'create' ? STRINGS.oauthServerClientsEmptyAgent : STRINGS.oauthRegisteredClientFormRefusedAction;
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, action);
    }
    if (this.store.refusalCode() === STATE_CONFLICT_CODE) return STRINGS.formStaleSave;
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  /** The status line: an Update JWKS, a secret refused after the save, or "Saved". */
  protected get status(): string {
    this.generation();
    if (this.actionNotice !== '') return this.actionNotice;
    if (!this.store.saved()) return '';
    const refused = this.store.secretRefused();
    return refused === '' ? savedLine(this.store.readBack()) : withReadBack(STRINGS.oauthResourceServerSecretRefused.split('<reason>').join(refused), this.store.readBack());
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
    if (control.field === KEY_SOURCE_FIELD) {
      if (value === 'none' || value === 'jwks' || value === 'x509') this.store.setKeySource(value as KeySource);
      return;
    }
    const key = TEXT_KEYS[control.field];
    if (key !== undefined) {
      this.store.setText(key, value);
      return;
    }
    if (control.field === memberField(CONTACTS_MEMBER)) {
      this.store.setMemberCsv(CONTACTS_MEMBER, value);
      return;
    }
    if (control.field.startsWith(`${METADATA_FIELD}.`)) this.store.setMemberText(control.field.slice(METADATA_FIELD.length + 1), value);
  }

  protected onCheck(control: Control, checked: boolean): void {
    if (control.field.startsWith('grant:')) {
      this.store.setChoice(GRANT_MEMBER, control.field.slice('grant:'.length), checked);
      return;
    }
    if (control.field.startsWith('response:')) {
      this.store.setChoice(RESPONSE_MEMBER, control.field.slice('response:'.length), checked);
      return;
    }
    if (control.field === memberField(SESSION_MEMBER)) this.store.setMemberFlag(SESSION_MEMBER, checked);
  }

  protected onBlur(field: string): void {
    this.store.onBlur(field);
  }

  protected onRedirect(index: number, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setRedirect(index, target.value);
  }

  protected addRedirect(): void {
    if (this.locked) return;
    this.store.addRedirect();
    const id = `${this.redirectsId}-${this.store.redirects().length}`;
    afterNextRender(() => document.getElementById(id)?.focus(), { injector: this.injector });
  }

  protected removeRedirect(index: number): void {
    if (this.locked) return;
    this.store.removeRedirect(index);
  }

  protected onSecret(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setSecret(target.value);
  }

  /** Fill the secret field with a new random secret; it stays masked until Show is chosen. */
  protected onGenerate(): void {
    if (this.locked) return;
    this.store.setSecret(generateSecret());
  }

  protected toggleReveal(): void {
    this.revealed.update((value) => !value);
  }

  protected async onSave(): Promise<void> {
    if (this.saveBlocked) return;
    this.clearAction();
    const creating = this.store.mode() === 'create';
    const saved = await this.store.save();
    this.revealed.set(false);
    if (!saved) {
      this.afterRefusal();
      return;
    }
    const id = this.store.savedId();
    if (id === '') return;
    this.store.retainAcrossRouteReplacement();
    // A create replaces the route with the client's own URL, so the address bar names the entity; an
    // edit reads the client again, so every tab shows what the instance now holds.
    if (creating) {
      void this.router.navigateByUrl(this.editorUrl(id), { replaceUrl: true });
      return;
    }
    await this.store.open(id);
  }

  /** Update JWKS: the tab's declared action, sent as its row menu sends it (AD-53). */
  protected async onUpdateJwks(): Promise<void> {
    if (!this.offersUpdateJwks || this.actionBlocked) return;
    const id = this.store.storedClientId();
    this.clearAction();
    this.acting = true;
    this.bump();
    const applied = await this.handler.sendFor(OAUTH_REGISTERED_CLIENT_TAB_DESCRIPTOR, UPDATE_JWKS_ACTION, id);
    this.acting = false;
    if (!applied) {
      this.actionRefusal = this.tabRefusal();
      this.bump();
      return;
    }
    // The refresh can clear the stored X.509 credentials, so the form reads the client again.
    await this.store.open(id);
    this.actionNotice = STRINGS.oauthRegisteredClientJwksUpdated;
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

  /** The typed client id matched: send the tab's declared delete, then return to the tab (AD-53). */
  protected async confirmDelete(): Promise<void> {
    this.deleting = false;
    this.acting = true;
    this.bump();
    const applied = await this.handler.sendFor(OAUTH_REGISTERED_CLIENT_TAB_DESCRIPTOR, DELETE_ACTION, this.store.storedClientId());
    this.acting = false;
    if (!applied) {
      this.actionRefusal = this.tabRefusal();
      this.bump();
      return;
    }
    this.formDirty.setDirty(false);
    void this.router.navigateByUrl(withQuery(OAUTH_REGISTERED_CLIENT_TAB_ROUTE, this.router.url));
  }

  /** Open the tab that holds `field`, then focus it. */
  protected focusField(field: string): void {
    const tab = REGISTERED_CLIENT_FIELD_TABS[field];
    if (tab !== undefined && tab !== this.selectedTab()) {
      this.selectedTab.set(tab);
      afterNextRender(() => this.focusControl(field), { injector: this.injector });
      return;
    }
    this.focusControl(field);
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(OAUTH_REGISTERED_CLIENT_TAB_ROUTE, this.router.url));
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
    const tab = screenForRoute(OAUTH_REGISTERED_CLIENT_TAB_ROUTE);
    return tab === null ? '' : this.stores.for(tab.descriptor, tab.refreshRates).refusal();
  }

  /** The client id this route names, or `''` for the create. */
  private routeId(): string {
    const screen = screenForRoute(OAUTH_REGISTERED_CLIENT_FORM_ROUTE);
    return screen === null ? '' : ownIdSegment(screen, this.router.url);
  }

  /**
   * After a refused Save: the tab that holds the first refused field in form order opens, the error
   * summary takes focus, then that field, in the order EXPERIENCE.md's `form-page` validation rule
   * states.
   */
  private afterRefusal(): void {
    const open = tabToOpen(REGISTERED_CLIENT_FIELD_TABS, REGISTERED_CLIENT_FIELD_ORDER, this.store.violations());
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
    const order = REGISTERED_CLIENT_FIELD_ORDER;
    const rank = (field: string): number => (order.includes(field) ? order.indexOf(field) : order.length);
    const first = violations.reduce((best, entry) => (rank(entry.field) < rank(best.field) ? entry : best));
    this.focusControl(first.field);
  }

  private focusControl(field: string): void {
    document.getElementById(this.controlId(field))?.focus();
  }

  /** A field's control id: `Metadata` itself is refused on the Client Information tab as a whole. */
  private controlId(field: string): string {
    if (field === METADATA_FIELD) return this.informationId;
    return idFor(field);
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

  private textControl(field: string, label: string, inputType = 'text'): Control {
    const key = TEXT_KEYS[field];
    return { ...this.base(field, idFor(field), label), isInput: true, inputType, value: key === undefined ? '' : this.store.text(key) };
  }

  private memberInput(member: string, label: string, inputType: string): Control {
    const field = memberField(member);
    return { ...this.base(field, idFor(field), label), isInput: true, inputType, value: this.store.memberText(member) };
  }

  private selectControl(field: string, label: string, value: string, options: readonly Option[]): Control {
    return { ...this.base(field, idFor(field), label), isSelect: true, value, options };
  }

  /** An algorithm select: "Not set", the vendor's list, and a stored value outside it kept. */
  private algorithmSelect(member: string, label: string): Control {
    const value = this.store.memberText(member);
    const values = this.store.algorithms(member);
    const all = values.includes(value) || value === '' ? values : [...values, value];
    return this.selectControl(memberField(member), label, value, this.withNotSet(all));
  }

  private withNotSet(values: readonly string[]): readonly Option[] {
    return [{ value: '', label: STRINGS.oauthClientNotSet }, ...values.map((value) => ({ value, label: value === NO_ALGORITHM ? STRINGS.sslVerifyPeerNone : value }))];
  }

  /** The client's own URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private editorUrl(id: string): string {
    const editor = this.navigation.screenForUrl(this.router.url);
    const route = editor === null ? OAUTH_REGISTERED_CLIENT_FORM_ROUTE : editor.route;
    return withQuery(`${route}/${encodeEntityId(id)}`, this.router.url);
  }
}
