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
  AUDIENCES_FIELD,
  AUTHENTICATOR_FIELD,
  AUTHENTICATOR_TAB,
  BINDINGS_SERVICE,
  CLIENT_ID_FIELD,
  DEFAULT_KEY,
  DESCRIPTION_FIELD,
  ENABLED_FIELD,
  type FlagKey,
  GATEWAY_SERVICE,
  GENERAL_TAB,
  IMPLEMENTATION_MEMBER,
  INTROSPECTION_FIELD,
  ISSUER_FIELD,
  JWT_FIELD,
  MAPPINGS_FIELD,
  MAPPINGS_TAB,
  METHODS,
  METHOD_FIELD,
  NAMESPACE_MEMBER,
  NAME_FIELD,
  OAuthResourceServerForm,
  OIDC_FIELD,
  RESOURCE_SERVER_FIELD_ORDER,
  RESOURCE_SERVER_FIELD_TABS,
  SCOPE_FIELD,
  SECRET_FIELD,
  type TextKey,
  TOKEN_TAB,
  mappingName,
  mappingParts,
  settingField,
} from './oauth-resource-server-form.store';

/** The tab this form is reached from, which Cancel and a delete return to. */
export const OAUTH_RESOURCE_SERVER_TAB_ROUTE = 'security/oauth/resource-servers';

/** This form's own route, the fallback when the mirror cannot resolve it from the URL. */
export const OAUTH_RESOURCE_SERVER_FORM_ROUTE = 'security/oauth/resource-servers/edit';

/** The tab whose declared Delete this page sends (AD-53). */
export const OAUTH_RESOURCE_SERVER_TAB_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.OAuthResourceServerTab';

export const DELETE_ACTION = 'delete';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** The id every control's own id begins with. */
const ID_PREFIX = 'ocu-oauth-resource-server';

/** The text fields, keyed by the wire field, each with the store key it edits. */
const TEXT_KEYS: Readonly<Record<string, TextKey>> = {
  [NAME_FIELD]: 'name',
  [DESCRIPTION_FIELD]: 'description',
  [ISSUER_FIELD]: 'issuer',
  [SCOPE_FIELD]: 'scope',
  [CLIENT_ID_FIELD]: 'clientId',
  [METHOD_FIELD]: 'method',
};

/** The flags, keyed by the wire field. */
const FLAG_KEYS: Readonly<Record<string, FlagKey>> = {
  [ENABLED_FIELD]: 'enabled',
  [JWT_FIELD]: 'jwt',
  [INTROSPECTION_FIELD]: 'introspection',
  [OIDC_FIELD]: 'oidc',
};

/** The introspection methods' labels, by value, in the classic page's order. */
const METHOD_LABELS: Readonly<Record<string, string>> = {
  client_secret_basic: STRINGS.oauthResourceServerMethodBasic,
  client_secret_post: STRINGS.oauthResourceServerMethodPost,
  none: STRINGS.oauthResourceServerMethodNone,
};

type Control = ClientFieldControl;

type Option = ClientFieldOption;

/** A control this page draws and may lock on its own: the three introspection fields while it is off. */
interface PageControl extends Control {
  readonly off: boolean;
}

/** One audience row, resolved for drawing. */
interface AudienceRow {
  readonly index: number;
  readonly id: string;
  readonly value: string;
}

/** One mapping row, resolved for drawing. */
interface MappingRow {
  readonly name: string;
  readonly key: string;
  readonly move: string;
}

/** An object setting's text area, resolved for drawing. */
interface JsonControl {
  readonly field: string;
  readonly id: string;
  readonly label: string;
  readonly value: string;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/** A control's id for `field`: `Authenticator.x` as `Authenticator-x`. */
function idFor(field: string): string {
  return `${ID_PREFIX}-${field.replace(/[^A-Za-z0-9_-]/g, '-')}`;
}

/**
 * The OAuth 2.0 resource server editor, a tabbed `form-page` that creates a server on
 * `security/oauth/resource-servers/edit` and edits one on `security/oauth/resource-servers/edit/<name>`
 * (AD-55).
 *
 * **Its four tabs are the classic editor's field sets and its list page's Mappings tab**: General,
 * Access token validation, Authenticator and Mappings, on `app-form-tabs` (UX-DR33). A refused Save
 * opens the tab that holds the first refused field.
 *
 * **Delete is the tab's own declared action**, sent through the shell's handler exactly as its row
 * menu sends it (AD-53), after the name is typed.
 *
 * It composes no payload and authors no field sentence. The client secret is masked and never
 * pre-filled. Every control-flow condition is a paren-free member reference, for the reason
 * `sign-in.ts` records.
 */
@Component({
  selector: 'app-oauth-resource-server-form-page',
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
        <div class="ocu-form-fields ocu-oauth-resource-server-tab">
          @for (control of generalControls; track control.id) {
            <app-oauth-client-field [control]="control" [locked]="locked" (edited)="onInput(control, $event)" (toggled)="onCheck(control, $event)" (left)="onBlur(control.field)" />
          }
          <fieldset class="ocu-field ocu-oauth-resource-server-audiences" [id]="audiencesId" tabindex="-1" [attr.aria-describedby]="audiencesDescribedBy">
            <legend class="ocu-field-label ocu-field-label-required">{{ STRINGS.oauthResourceServerFieldAudiences }}</legend>
            @for (row of audienceRows; track row.index) {
              <div class="ocu-oauth-resource-server-row">
                <input
                  class="ocu-field-input"
                  type="text"
                  spellcheck="false"
                  autocomplete="off"
                  [id]="row.id"
                  [value]="row.value"
                  [readOnly]="locked"
                  [attr.aria-label]="STRINGS.oauthResourceServerFieldAudiences"
                  [attr.aria-invalid]="audiencesInvalid"
                  (input)="onAudience(row.index, $event)"
                />
                <button type="button" class="ocu-button-text" [attr.aria-disabled]="locked" (click)="removeAudience(row.index)">
                  {{ STRINGS.actionRemove }}
                </button>
              </div>
            }
            <div class="ocu-oauth-resource-server-row">
              <button type="button" class="ocu-button-secondary" [id]="addAudienceId" [attr.aria-disabled]="locked" (click)="addAudience()">
                {{ STRINGS.oauthResourceServerAddAudience }}
              </button>
            </div>
            @if (audiencesInvalid) {
              <p class="ocu-form-error" [id]="audiencesId + '-reason'">{{ audiencesReason }}</p>
            }
          </fieldset>
          @for (control of scopeControls; track control.id) {
            <app-oauth-client-field [control]="control" [locked]="locked" (edited)="onInput(control, $event)" (left)="onBlur(control.field)" />
          }
        </div>
      </ng-template>

      <ng-template ocuFormTab="token">
        <div class="ocu-form-fields ocu-oauth-resource-server-tab">
          @for (control of tokenControls; track control.id) {
            <app-oauth-client-field [control]="control" [locked]="control.off" (edited)="onInput(control, $event)" (toggled)="onCheck(control, $event)" (left)="onBlur(control.field)" />
          }
        </div>
      </ng-template>

      <ng-template ocuFormTab="authenticator">
        <div class="ocu-form-fields ocu-oauth-resource-server-tab">
          @for (control of authenticatorControls; track control.id) {
            <app-oauth-client-field [control]="control" [locked]="locked" (edited)="onAuthenticator(control, $event)" (toggled)="onSettingCheck(control, $event)" />
          }
          @for (json of jsonControls; track json.id) {
            <div class="ocu-field">
              <label class="ocu-field-label" [attr.for]="json.id">{{ json.label }}</label>
              <textarea
                class="ocu-field-input ocu-field-textarea"
                spellcheck="false"
                [id]="json.id"
                [value]="json.value"
                [readOnly]="locked"
                [attr.aria-invalid]="json.invalid"
                [attr.aria-describedby]="json.describedBy"
                (input)="onJson(json.field, $event)"
              ></textarea>
              @if (json.invalid) {
                <p class="ocu-form-error" [id]="json.id + '-reason'">{{ json.reason }}</p>
              }
            </div>
          }
        </div>
      </ng-template>

      <ng-template ocuFormTab="mappings">
        <div class="ocu-form-fields ocu-oauth-resource-server-tab" [id]="mappingsId" tabindex="-1">
          <table class="ocu-oauth-resource-server-mappings" [id]="gatewayTableId">
            <caption class="ocu-field-label">{{ STRINGS.oauthResourceServerGatewayMappings }}</caption>
            <thead>
              <tr>
                <th scope="col">{{ STRINGS.oauthResourceServerFieldApplication }}</th>
                <th scope="col" class="ocu-oauth-resource-server-mappings-action">{{ STRINGS.actionRemove }}</th>
              </tr>
            </thead>
            <tbody>
              @for (row of gatewayRows; track row.name) {
                <tr>
                  <td>
                    <span>{{ row.key }}</span>
                    @if (row.move) {
                      <span class="ocu-field-caption ocu-oauth-resource-server-move">{{ row.move }}</span>
                    }
                  </td>
                  <td class="ocu-oauth-resource-server-mappings-action">
                    <button type="button" class="ocu-button-text" [attr.aria-disabled]="locked" (click)="removeMapping(row.name)">{{ STRINGS.actionRemove }}</button>
                  </td>
                </tr>
              }
            </tbody>
          </table>
          <table class="ocu-oauth-resource-server-mappings" [id]="bindingsTableId">
            <caption class="ocu-field-label">{{ STRINGS.oauthResourceServerBindingsMappings }}</caption>
            <thead>
              <tr>
                <th scope="col">{{ STRINGS.headerNamespaceLabel }}</th>
                <th scope="col" class="ocu-oauth-resource-server-mappings-action">{{ STRINGS.actionRemove }}</th>
              </tr>
            </thead>
            <tbody>
              @for (row of bindingsRows; track row.name) {
                <tr>
                  <td>
                    <span>{{ row.key }}</span>
                    @if (row.move) {
                      <span class="ocu-field-caption ocu-oauth-resource-server-move">{{ row.move }}</span>
                    }
                  </td>
                  <td class="ocu-oauth-resource-server-mappings-action">
                    <button type="button" class="ocu-button-text" [attr.aria-disabled]="locked" (click)="removeMapping(row.name)">{{ STRINGS.actionRemove }}</button>
                  </td>
                </tr>
              }
            </tbody>
          </table>
          <fieldset class="ocu-field ocu-oauth-resource-server-add">
            <legend class="ocu-field-label">{{ STRINGS.oauthResourceServerAddMapping }}</legend>
            @for (control of addControls; track control.id) {
              <app-oauth-client-field [control]="control" [locked]="locked" (edited)="onAddRow(control, $event)" />
            }
            @if (hasMoveNote) {
              <p class="ocu-field-caption" [id]="moveNoteId">{{ moveNote }}</p>
            }
            <div class="ocu-oauth-resource-server-row">
              <button type="button" class="ocu-button-secondary" [id]="addMappingId" [attr.aria-disabled]="addBlocked" (click)="onAddMapping()">
                {{ STRINGS.oauthResourceServerAddMapping }}
              </button>
            </div>
            @if (mappingsInvalid) {
              <p class="ocu-form-error" [id]="mappingsId + '-reason'">{{ mappingsReason }}</p>
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
        @if (offersDelete) {
          <button type="button" class="ocu-button-text" [attr.aria-disabled]="actionBlocked" (click)="onDelete()">
            {{ STRINGS.actionDelete }}
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
        [consequence]="STRINGS.oauthResourceServerDeleteConsequence"
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
export class OAuthResourceServerFormPage {
  private readonly store = inject(OAuthResourceServerForm);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly handler = inject(ScreenActionHandler);
  private readonly stores = inject(ScreenStores);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  protected readonly audiencesId = `${ID_PREFIX}-Audiences`;
  protected readonly addAudienceId = `${ID_PREFIX}-add-audience`;
  protected readonly mappingsId = `${ID_PREFIX}-Mappings`;
  protected readonly gatewayTableId = `${ID_PREFIX}-gateway-mappings`;
  protected readonly bindingsTableId = `${ID_PREFIX}-bindings-mappings`;
  protected readonly addMappingId = `${ID_PREFIX}-add-mapping`;
  protected readonly moveNoteId = `${ID_PREFIX}-move`;

  /** The key of the tab on screen. */
  protected readonly selectedTab = signal(GENERAL_TAB);

  /** The Add row's service and key, before Add mapping takes them. */
  private readonly addService = signal(GATEWAY_SERVICE);
  private readonly addKey = signal('');

  /** Bumped by the stores and this page's own state, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  private focusedSummary = false;

  private deleting = false;

  /** Whether a Delete is in flight. */
  private acting = false;

  /** The refusal the Delete was answered with, or `''` (AD-39). */
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
      this.actionRefusal = '';
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

  protected get storedName(): string {
    this.generation();
    return this.store.storedName();
  }

  protected get tabs(): readonly FormTabView[] {
    this.generation();
    const counts = tabErrorCounts(this.fieldTabs(), this.store.violations());
    return [
      { key: GENERAL_TAB, label: STRINGS.processDetailsGroupGeneral, count: counts[GENERAL_TAB] ?? 0 },
      { key: TOKEN_TAB, label: STRINGS.oauthResourceServerTabToken, count: counts[TOKEN_TAB] ?? 0 },
      { key: AUTHENTICATOR_TAB, label: STRINGS.oauthResourceServerTabAuthenticator, count: counts[AUTHENTICATOR_TAB] ?? 0 },
      { key: MAPPINGS_TAB, label: STRINGS.oauthResourceServerTabMappings, count: counts[MAPPINGS_TAB] ?? 0 },
    ];
  }

  protected get generalControls(): readonly Control[] {
    this.generation();
    return [
      this.textControl(NAME_FIELD, STRINGS.tableColumnName, this.store.mode() === 'edit'),
      this.textControl(DESCRIPTION_FIELD, STRINGS.tableColumnDescription),
      this.checkControl(ENABLED_FIELD, STRINGS.tableColumnEnabled),
      this.issuerControl(),
    ];
  }

  protected get scopeControls(): readonly Control[] {
    this.generation();
    return [this.textControl(SCOPE_FIELD, STRINGS.oauthResourceServerFieldScope)];
  }

  protected get audienceRows(): readonly AudienceRow[] {
    this.generation();
    return this.store.audiences().map((value, index) => ({ index, id: `${this.audiencesId}-${index + 1}`, value }));
  }

  protected get audiencesReason(): string {
    this.generation();
    return this.store.violationFor(AUDIENCES_FIELD);
  }

  protected get audiencesInvalid(): boolean {
    return this.audiencesReason !== '';
  }

  protected get audiencesDescribedBy(): string | null {
    return this.audiencesInvalid ? `${this.audiencesId}-reason` : null;
  }

  /** Call introspection is fixed on while JWT is off; the three introspection fields are locked while it is off. */
  protected get tokenControls(): readonly PageControl[] {
    this.generation();
    const locked = !this.store.editable() || this.acting;
    const jwt = this.store.flag('jwt');
    const introspection = this.store.flag('introspection');
    const method = this.store.text('method');
    const methods = METHODS.includes(method) || method === '' ? METHODS : [...METHODS, method];
    return [
      { ...this.checkControl(JWT_FIELD, STRINGS.oauthResourceServerFieldJwt), off: locked },
      { ...this.checkControl(INTROSPECTION_FIELD, STRINGS.oauthResourceServerFieldIntrospection), off: locked || !jwt },
      { ...this.checkControl(OIDC_FIELD, STRINGS.oauthResourceServerFieldOidc), off: locked },
      { ...this.textControl(CLIENT_ID_FIELD, STRINGS.oauthColumnClientId), off: locked || !introspection },
      { ...this.secretControl(), off: locked || !introspection },
      {
        ...this.selectControl(METHOD_FIELD, STRINGS.oauthClientFieldAuthMethod, method, methods.map((value) => ({ value, label: METHOD_LABELS[value] ?? value }))),
        off: locked || !introspection,
      },
    ];
  }

  protected get authenticatorControls(): readonly Control[] {
    this.generation();
    const namespace = this.store.namespace();
    const namespaces = this.store.namespaces();
    const implementation = this.store.implementation();
    const implementations = this.store.implementations();
    const controls: Control[] = [
      this.selectControl(`${AUTHENTICATOR_FIELD}.${NAMESPACE_MEMBER}`, STRINGS.headerNamespaceLabel, namespace, this.options(namespaces.includes(namespace) ? namespaces : [...namespaces, namespace])),
      this.selectControl(
        `${AUTHENTICATOR_FIELD}.${IMPLEMENTATION_MEMBER}`,
        STRINGS.oauthResourceServerFieldImplementation,
        implementation,
        this.options(implementations.includes(implementation) || implementation === '' ? implementations : [...implementations, implementation])
      ),
    ];
    for (const setting of this.store.settings()) {
      if (setting.kind === 'object') continue;
      const field = settingField(setting.name);
      const value = this.store.setting(setting.name);
      if (setting.kind === 'boolean') {
        controls.push({ ...this.base(field, setting.name), isCheck: true, checked: value === true });
        continue;
      }
      const inputType = setting.kind === 'integer' || setting.kind === 'double' ? 'number' : 'text';
      controls.push({ ...this.base(field, setting.name), isInput: true, inputType, value: typeof value === 'string' ? value : '' });
    }
    return controls;
  }

  protected get jsonControls(): readonly JsonControl[] {
    this.generation();
    return this.store
      .settings()
      .filter((setting) => setting.kind === 'object')
      .map((setting) => {
        const field = settingField(setting.name);
        const id = idFor(field);
        const reason = this.store.violationFor(field);
        const value = this.store.setting(setting.name);
        return { field, id, label: setting.name, value: typeof value === 'string' ? value : '', reason, invalid: reason !== '', describedBy: reason !== '' ? `${id}-reason` : null };
      });
  }

  protected get gatewayRows(): readonly MappingRow[] {
    return this.mappingRows(GATEWAY_SERVICE);
  }

  protected get bindingsRows(): readonly MappingRow[] {
    return this.mappingRows(BINDINGS_SERVICE);
  }

  /** The Add row: the service, then a key that service offers, "* (Default)" first. */
  protected get addControls(): readonly Control[] {
    this.generation();
    const service = this.addService();
    const names = service === GATEWAY_SERVICE ? this.store.webApplications() : this.store.namespaces();
    const keys: Option[] = [{ value: '', label: STRINGS.oauthClientNotSet }, { value: DEFAULT_KEY, label: STRINGS.oauthResourceServerDefaultKey }, ...names.map((name) => ({ value: name, label: name }))];
    const describedBy = this.hasMoveNote ? this.moveNoteId : null;
    return [
      this.selectControl(`${MAPPINGS_FIELD}.Service`, STRINGS.serviceFormLabel, service, [
        { value: GATEWAY_SERVICE, label: STRINGS.oauthResourceServerFieldApplication },
        { value: BINDINGS_SERVICE, label: STRINGS.headerNamespaceLabel },
      ]),
      { ...this.selectControl(`${MAPPINGS_FIELD}.Key`, STRINGS.oauthClientAlgKey, this.addKey(), keys), describedBy },
    ];
  }

  /** The move sentence at the Add row: the key chosen is held by another server, which the Save moves it from. */
  protected get moveNote(): string {
    this.generation();
    const key = this.addKey();
    if (key === '') return '';
    const holder = this.store.holderOf(mappingName(this.addService(), key));
    return holder === '' ? '' : STRINGS.oauthResourceServerMoves.split('<server>').join(holder);
  }

  protected get hasMoveNote(): boolean {
    return this.moveNote !== '';
  }

  protected get addBlocked(): boolean {
    this.generation();
    return this.locked || this.addKey() === '';
  }

  protected get mappingsReason(): string {
    this.generation();
    return this.store
      .violations()
      .filter((entry) => entry.field === MAPPINGS_FIELD || entry.field.startsWith(`${MAPPINGS_FIELD}.`))
      .map((entry) => entry.reason)
      .join(' ');
  }

  protected get mappingsInvalid(): boolean {
    return this.mappingsReason !== '';
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

  protected get deletePending(): boolean {
    this.generation();
    return this.deleting;
  }

  protected get deleteVerb(): string {
    return actionLabel(OAUTH_RESOURCE_SERVER_TAB_DESCRIPTOR, DELETE_ACTION);
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
   * save's published sentence, the Delete's own refusal, or the envelope's own reason.
   */
  protected get reason(): string {
    this.generation();
    if (this.actionRefusal !== '') return this.actionRefusal;
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') {
      const action = this.store.mode() === 'create' ? STRINGS.oauthResourceServersEmptyAgent : STRINGS.oauthResourceServerFormRefusedAction;
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, action);
    }
    if (this.store.refusalCode() === STATE_CONFLICT_CODE) return STRINGS.formStaleSave;
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  /** The status line: "Saved", with what did not land beside it. */
  protected get status(): string {
    this.generation();
    if (!this.store.saved()) return '';
    const lines: string[] = [];
    const refused = this.store.secretRefused();
    if (refused !== '') lines.push(STRINGS.oauthResourceServerSecretRefused.split('<reason>').join(refused));
    const mappings = this.store.mappingsRefused();
    if (mappings.count > 0) lines.push(STRINGS.oauthResourceServerMappingsRefused.split('<count>').join(String(mappings.count)).split('<reason>').join(mappings.reason));
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

  protected selectTab(key: string): void {
    this.selectedTab.set(key);
  }

  protected onInput(control: Control, value: string): void {
    if (control.field === SECRET_FIELD) {
      this.store.setSecret(value);
      return;
    }
    const key = TEXT_KEYS[control.field];
    if (key !== undefined) this.store.setText(key, value);
  }

  protected onCheck(control: Control, checked: boolean): void {
    const key = FLAG_KEYS[control.field];
    if (key !== undefined) this.store.setFlag(key, checked);
  }

  protected onBlur(field: string): void {
    this.store.onBlur(field);
  }

  protected onAudience(index: number, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setAudience(index, target.value);
  }

  protected addAudience(): void {
    if (this.locked) return;
    this.store.addAudience();
    const id = `${this.audiencesId}-${this.store.audiences().length}`;
    afterNextRender(() => document.getElementById(id)?.focus(), { injector: this.injector });
  }

  protected removeAudience(index: number): void {
    if (this.locked) return;
    this.store.removeAudience(index);
  }

  protected onAuthenticator(control: Control, value: string): void {
    if (control.field === `${AUTHENTICATOR_FIELD}.${NAMESPACE_MEMBER}`) {
      void this.store.setNamespace(value);
      return;
    }
    if (control.field === `${AUTHENTICATOR_FIELD}.${IMPLEMENTATION_MEMBER}`) {
      this.store.setImplementation(value);
      return;
    }
    this.store.setSetting(control.field.slice(AUTHENTICATOR_FIELD.length + 1), value);
  }

  protected onSettingCheck(control: Control, checked: boolean): void {
    this.store.setSetting(control.field.slice(AUTHENTICATOR_FIELD.length + 1), checked);
  }

  protected onJson(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLTextAreaElement) this.store.setSetting(field.slice(AUTHENTICATOR_FIELD.length + 1), target.value);
  }

  protected onAddRow(control: Control, value: string): void {
    if (control.field === `${MAPPINGS_FIELD}.Service`) {
      this.addService.set(value);
      this.addKey.set('');
    } else {
      this.addKey.set(value);
    }
    this.bump();
  }

  protected onAddMapping(): void {
    if (this.addBlocked) return;
    this.store.addMapping(this.addService(), this.addKey());
    this.addKey.set('');
    this.bump();
  }

  protected removeMapping(name: string): void {
    if (this.locked) return;
    this.store.removeMapping(name);
  }

  protected async onSave(): Promise<void> {
    if (this.saveBlocked) return;
    this.actionRefusal = '';
    const creating = this.store.mode() === 'create';
    const saved = await this.store.save();
    if (!saved) {
      this.afterRefusal();
      return;
    }
    const id = this.store.savedId();
    if (id === '') return;
    this.store.retainAcrossRouteReplacement();
    // A create replaces the route with the server's own URL, so the address bar names the entity; an
    // edit reads the server again, so every tab shows what the instance now holds.
    if (creating) {
      void this.router.navigateByUrl(this.editorUrl(id), { replaceUrl: true });
      return;
    }
    await this.store.open(id);
  }

  protected onDelete(): void {
    if (!this.offersDelete || this.actionBlocked) return;
    this.actionRefusal = '';
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
    const applied = await this.handler.sendFor(OAUTH_RESOURCE_SERVER_TAB_DESCRIPTOR, DELETE_ACTION, this.store.storedName());
    this.acting = false;
    if (!applied) {
      this.actionRefusal = this.tabRefusal();
      this.bump();
      return;
    }
    this.formDirty.setDirty(false);
    void this.router.navigateByUrl(withQuery(OAUTH_RESOURCE_SERVER_TAB_ROUTE, this.router.url));
  }

  /** Open the tab that holds `field`, then focus it. */
  protected focusField(field: string): void {
    const tab = this.fieldTabs()[field];
    if (tab !== undefined && tab !== this.selectedTab()) {
      this.selectedTab.set(tab);
      afterNextRender(() => this.focusControl(field), { injector: this.injector });
      return;
    }
    this.focusControl(field);
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(OAUTH_RESOURCE_SERVER_TAB_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  /** Which tab each field is on: the fixed map, and every authenticator setting on the authenticator tab. */
  private fieldTabs(): Readonly<Record<string, string>> {
    const tabs: Record<string, string> = { ...RESOURCE_SERVER_FIELD_TABS };
    for (const setting of this.store.settings()) tabs[settingField(setting.name)] = AUTHENTICATOR_TAB;
    return tabs;
  }

  private fieldOrder(): readonly string[] {
    return [...RESOURCE_SERVER_FIELD_ORDER, ...this.store.settings().map((setting) => settingField(setting.name))];
  }

  private mappingRows(service: string): readonly MappingRow[] {
    this.generation();
    return this.store
      .mappings()
      .filter((name) => mappingParts(name).service === service)
      .map((name) => {
        const key = mappingParts(name).key;
        const holder = this.store.unsaved(name) ? this.store.holderOf(name) : '';
        return { name, key: key === DEFAULT_KEY ? STRINGS.oauthResourceServerDefaultKey : key, move: holder === '' ? '' : STRINGS.oauthResourceServerMoves.split('<server>').join(holder) };
      });
  }

  /** The sentence the tab's action route refused with, which the handler puts on the tab's store. */
  private tabRefusal(): string {
    const tab = screenForRoute(OAUTH_RESOURCE_SERVER_TAB_ROUTE);
    return tab === null ? '' : this.stores.for(tab.descriptor, tab.refreshRates).refusal();
  }

  /** The name this route names, or `''` for the create. */
  private routeId(): string {
    const screen = screenForRoute(OAUTH_RESOURCE_SERVER_FORM_ROUTE);
    return screen === null ? '' : ownIdSegment(screen, this.router.url);
  }

  /**
   * After a refused Save: the tab that holds the first refused field opens, the error summary takes
   * focus, then that field, in the order EXPERIENCE.md's `form-page` validation rule states.
   */
  private afterRefusal(): void {
    const open = tabToOpen(this.fieldTabs(), this.fieldOrder(), this.store.violations());
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
    const order = this.fieldOrder();
    const rank = (field: string): number => (order.includes(field) ? order.indexOf(field) : order.length);
    const first = violations.reduce((best, entry) => (rank(entry.field) < rank(best.field) ? entry : best));
    this.focusControl(first.field);
  }

  private focusControl(field: string): void {
    document.getElementById(this.controlId(field))?.focus();
  }

  /** A field's control id: the audiences' fieldset, the mappings tab's column, or its own. */
  private controlId(field: string): string {
    if (field === AUDIENCES_FIELD) return this.audiencesId;
    if (field === MAPPINGS_FIELD || field.startsWith(`${MAPPINGS_FIELD}.`)) return this.mappingsId;
    if (field === AUTHENTICATOR_FIELD) return idFor(`${AUTHENTICATOR_FIELD}.${NAMESPACE_MEMBER}`);
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

  private textControl(field: string, label: string, readOnly = false): Control {
    const key = TEXT_KEYS[field];
    return { ...this.base(field, label), isInput: true, readOnly, value: key === undefined ? '' : this.store.text(key) };
  }

  private checkControl(field: string, label: string): Control {
    const key = FLAG_KEYS[field];
    return { ...this.base(field, label), isCheck: true, checked: key === undefined ? false : this.store.flag(key) };
  }

  private selectControl(field: string, label: string, value: string, options: readonly Option[]): Control {
    return { ...this.base(field, label), isSelect: true, value, options };
  }

  private secretControl(): Control {
    const own = this.base(SECRET_FIELD, STRINGS.oauthClientFieldSecret);
    return {
      ...own,
      isInput: true,
      isSecret: true,
      inputType: 'password',
      value: this.store.secret(),
      hasHint: true,
      describedBy: own.invalid ? `${own.id}-hint ${own.id}-reason` : `${own.id}-hint`,
    };
  }

  /** The server description select: its issuers, the stored one kept if it is another. */
  private issuerControl(): Control {
    const value = this.store.text('issuer');
    const issuers = this.store.issuers();
    return this.selectControl(ISSUER_FIELD, STRINGS.oauthServerFormLabel, value, [
      { value: '', label: STRINGS.oauthClientNotSet },
      ...(issuers.includes(value) || value === '' ? issuers : [...issuers, value]).map((issuer) => ({ value: issuer, label: issuer })),
    ]);
  }

  private options(values: readonly string[]): readonly Option[] {
    return values.map((value) => ({ value, label: value }));
  }

  /** The server's own URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private editorUrl(id: string): string {
    const editor = this.navigation.screenForUrl(this.router.url);
    const route = editor === null ? OAUTH_RESOURCE_SERVER_FORM_ROUTE : editor.route;
    return withQuery(`${route}/${encodeEntityId(id)}`, this.router.url);
  }
}
