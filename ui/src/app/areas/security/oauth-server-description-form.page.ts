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
import {
  CREDENTIALS_FIELD,
  ENDPOINT_MEMBERS,
  ISSUER_FIELD,
  JWKS_MEMBER,
  type JwtChoice,
  type MemberValue,
  OAuthServerDescriptionForm,
  SSL_FIELD,
  TOKEN_FIELD,
  memberField,
} from './oauth-server-description-form.store';

/** The tab this form is reached from, which Cancel and a delete return to. */
export const OAUTH_SERVER_TAB_ROUTE = 'security/oauth';

/** This form's own route, the fallback when the mirror cannot resolve it from the URL. */
export const OAUTH_SERVER_FORM_ROUTE = 'security/oauth/edit';

/** The tab whose declared Delete and Update JWKS this page sends (AD-53). */
export const OAUTH_SERVER_TAB_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.OAuthServerDescriptionTab';

export const DELETE_ACTION = 'delete';

export const UPDATE_JWKS_ACTION = 'updatejwks';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** The six Authorization server endpoints, each with its label, in the classic page's order. */
const ENDPOINT_LABELS: Readonly<Record<string, string>> = {
  authorization_endpoint: STRINGS.oauthServerFieldAuthorization,
  token_endpoint: STRINGS.oauthServerFieldTokenEndpoint,
  userinfo_endpoint: STRINGS.oauthServerFieldUserinfo,
  introspection_endpoint: STRINGS.oauthServerFieldIntrospection,
  revocation_endpoint: STRINGS.oauthServerFieldRevocation,
  end_session_endpoint: STRINGS.oauthServerFieldEndSession,
};

/** The JWT settings' three choices, each with its label. */
const JWT_CHOICES: readonly { readonly value: JwtChoice; readonly label: string }[] = [
  { value: 'none', label: STRINGS.sslVerifyPeerNone },
  { value: 'url', label: STRINGS.oauthServerJwtUrl },
  { value: 'x509', label: STRINGS.oauthServerJwtX509 },
];

/** One field, resolved for drawing: its control id, its refusal and its described-by wiring. */
interface FieldView {
  readonly id: string;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/** One Authorization server endpoint, resolved for drawing. */
interface EndpointView extends FieldView {
  readonly member: string;
  readonly label: string;
  readonly value: string;
  readonly required: boolean;
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

/**
 * The OAuth 2.0 client server description editor, a `form-page` that creates a description on
 * `security/oauth/edit` and edits one on `security/oauth/edit/<issuer>` (AD-55).
 *
 * **Its groups are the classic page's, in its order and untabbed**
 * (`%CSP.UI.Portal.OAuth2.Client.ServerConfiguration`): the issuer, the SSL/TLS configuration and the
 * registration access token; the Authorization server's six endpoints; the JSON Web Token (JWT)
 * settings, one of three choices; and a read-only table of every other metadata member.
 *
 * **Discover fills the form and saves nothing** (AD-27): the members the issuer publishes are for
 * review, and Save sends them. **Update JWKS and Delete are the tab's own declared actions**, sent
 * through the shell's handler exactly as its row menu sends them (AD-53); Update JWKS is offered
 * only on a saved, unchanged description whose stored JWKS URL is not empty, and Delete types the
 * issuer first.
 *
 * It composes no payload and authors no field sentence. Every control-flow condition is a paren-free
 * member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-oauth-server-description-form-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, TypedNameDialog],
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
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="issuerField.id">{{ STRINGS.oauthServerFieldIssuer }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="url"
            autocomplete="off"
            spellcheck="false"
            [id]="issuerField.id"
            [value]="issuer"
            aria-required="true"
            [readOnly]="locked"
            [attr.aria-invalid]="issuerField.invalid"
            [attr.aria-describedby]="issuerField.describedBy"
            (input)="onIssuer($event)"
            (blur)="onBlur('IssuerEndpoint')"
          />
        </div>
        @if (issuerField.invalid) {
          <p class="ocu-form-error" [id]="issuerField.id + '-reason'">{{ issuerField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="sslField.id">{{ STRINGS.sslFormLabel }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            list="ocu-oauth-server-ssl-names"
            [id]="sslField.id"
            [value]="ssl"
            aria-required="true"
            [readOnly]="locked"
            [attr.aria-invalid]="sslField.invalid"
            [attr.aria-describedby]="sslField.describedBy"
            (input)="onSsl($event)"
            (blur)="onBlur('SSLConfiguration')"
          />
          <datalist id="ocu-oauth-server-ssl-names">
            @for (name of sslNames; track name) {
              <option [value]="name"></option>
            }
          </datalist>
        </div>
        @if (sslField.invalid) {
          <p class="ocu-form-error" [id]="sslField.id + '-reason'">{{ sslField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="tokenField.id">{{ STRINGS.oauthServerFieldToken }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="password"
            autocomplete="new-password"
            spellcheck="false"
            [id]="tokenField.id"
            [value]="token"
            [readOnly]="locked"
            [attr.aria-invalid]="tokenField.invalid"
            [attr.aria-describedby]="tokenDescribedBy"
            (input)="onToken($event)"
          />
        </div>
        <p class="ocu-field-caption" [id]="tokenField.id + '-hint'">{{ STRINGS.oauthServerTokenHint }}</p>
        @if (tokenField.invalid) {
          <p class="ocu-form-error" [id]="tokenField.id + '-reason'">{{ tokenField.reason }}</p>
        }
      </div>

      <fieldset class="ocu-field ocu-oauth-server-group" id="ocu-oauth-server-authorization">
        <legend class="ocu-field-label">{{ STRINGS.oauthTabServer }}</legend>
        @for (endpoint of endpoints; track endpoint.member) {
          <div class="ocu-field">
            <label
              class="ocu-field-label"
              [class.ocu-field-label-required]="endpoint.required"
              [attr.for]="endpoint.id"
            >{{ endpoint.label }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                type="url"
                autocomplete="off"
                spellcheck="false"
                [id]="endpoint.id"
                [value]="endpoint.value"
                [attr.aria-required]="endpoint.required || null"
                [readOnly]="locked"
                [attr.aria-invalid]="endpoint.invalid"
                [attr.aria-describedby]="endpoint.describedBy"
                (input)="onMember(endpoint.member, $event)"
                (blur)="onBlurMember(endpoint.member)"
              />
            </div>
            @if (endpoint.invalid) {
              <p class="ocu-form-error" [id]="endpoint.id + '-reason'">{{ endpoint.reason }}</p>
            }
          </div>
        }
      </fieldset>

      <fieldset class="ocu-field ocu-oauth-server-group" id="ocu-oauth-server-jwt">
        <legend class="ocu-field-label">{{ STRINGS.oauthServerGroupJwt }}</legend>
        @for (option of jwtChoices; track option.value) {
          <label class="ocu-field-checkbox">
            <input
              type="radio"
              name="ocu-oauth-server-jwt"
              [id]="'ocu-oauth-server-jwt-' + option.value"
              [value]="option.value"
              [checked]="option.value === choice"
              [disabled]="locked"
              (change)="onChoice(option.value)"
            />
            <span>{{ option.label }}</span>
          </label>
        }
        @if (choosingUrl) {
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="jwksField.id">{{ STRINGS.oauthServerJwtUrl }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                type="url"
                autocomplete="off"
                spellcheck="false"
                [id]="jwksField.id"
                [value]="jwksUri"
                [readOnly]="locked"
                [attr.aria-invalid]="jwksField.invalid"
                [attr.aria-describedby]="jwksField.describedBy"
                (input)="onMember('jwks_uri', $event)"
              />
            </div>
            @if (jwksField.invalid) {
              <p class="ocu-form-error" [id]="jwksField.id + '-reason'">{{ jwksField.reason }}</p>
            }
          </div>
        }
        @if (choosingX509) {
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="credentialsField.id">{{ STRINGS.oauthServerJwtX509 }}</label>
            <div class="ocu-field-control">
              <input
                class="ocu-field-input"
                type="text"
                autocomplete="off"
                spellcheck="false"
                list="ocu-oauth-server-credential-names"
                [id]="credentialsField.id"
                [value]="credentials"
                [readOnly]="locked"
                [attr.aria-invalid]="credentialsField.invalid"
                [attr.aria-describedby]="credentialsField.describedBy"
                (input)="onCredentials($event)"
              />
              <datalist id="ocu-oauth-server-credential-names">
                @for (name of credentialNames; track name) {
                  <option [value]="name"></option>
                }
              </datalist>
            </div>
            @if (credentialsField.invalid) {
              <p class="ocu-form-error" [id]="credentialsField.id + '-reason'">{{ credentialsField.reason }}</p>
            }
          </div>
        }
      </fieldset>

      <div class="ocu-field ocu-oauth-server-metadata">
        <table class="ocu-oauth-server-metadata-table" id="ocu-oauth-server-metadata" tabindex="-1">
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
        @if (offersUpdateJwks) {
          <button type="button" class="ocu-button-secondary" [attr.aria-disabled]="actionBlocked" (click)="onUpdateJwks()">
            {{ STRINGS.oauthServerUpdateJwks }}
          </button>
        }
        <button type="button" class="ocu-button-secondary" [attr.aria-disabled]="discoverBlocked" (click)="onDiscover()">
          {{ STRINGS.oauthServerDiscover }}
        </button>
        <button type="button" class="ocu-button-primary" [attr.aria-disabled]="saveBlocked" (click)="onSave()">
          {{ STRINGS.actionSave }}
        </button>
      </div>
    </div>
    }

    @if (deletePending) {
      <app-typed-name-dialog
        [verb]="deleteVerb"
        [target]="storedIssuer"
        [consequence]="STRINGS.oauthServerDeleteConsequence"
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
export class OAuthServerDescriptionFormPage {
  private readonly store = inject(OAuthServerDescriptionForm);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly handler = inject(ScreenActionHandler);
  private readonly stores = inject(ScreenStores);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  protected readonly jwtChoices = JWT_CHOICES;

  /** Bumped by the stores and this page's own state, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  /** Whether the summary has been focused for the refusal now on screen. */
  private focusedSummary = false;

  /** Whether the typed-name dialog is open over this page. */
  private deleting = false;

  /** Whether a Delete or an Update JWKS is in flight. */
  private acting = false;

  /** The status line an Update JWKS wrote, or `''`. */
  private actionNotice = '';

  /** The refusal an Update JWKS or a Delete was answered with, or `''` (AD-39). */
  private actionRefusal = '';

  constructor() {
    const stopStore = this.store.subscribe(() => this.bump());
    const stopDirty = this.formDirty.subscribe(() => this.bump());
    let followed = this.routeId();
    void this.store.open(followed);
    // One id route to another reuses this page, so the form follows the id, not the page's life.
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
      // Kept across a Save's own route replacement, which destroys this page and builds it again
      // over the saved description; torn down on every other departure.
      if (!this.store.retaining()) this.store.reset();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get loadedFlag(): boolean {
    this.generation();
    return this.store.loaded();
  }

  /** Whether the fields refuse input: an edit whose fresh read has not landed, or a call in flight. */
  protected get locked(): boolean {
    this.generation();
    return !this.store.editable() || this.acting;
  }

  protected get issuer(): string {
    this.generation();
    return this.store.issuer();
  }

  protected get storedIssuer(): string {
    this.generation();
    return this.store.storedIssuer();
  }

  protected get ssl(): string {
    this.generation();
    return this.store.ssl();
  }

  protected get credentials(): string {
    this.generation();
    return this.store.credentials();
  }

  protected get token(): string {
    this.generation();
    return this.store.token();
  }

  protected get jwksUri(): string {
    this.generation();
    return this.store.memberText(JWKS_MEMBER);
  }

  protected get choice(): JwtChoice {
    this.generation();
    return this.store.choice();
  }

  protected get choosingUrl(): boolean {
    return this.choice === 'url';
  }

  protected get choosingX509(): boolean {
    return this.choice === 'x509';
  }

  protected get sslNames(): readonly string[] {
    this.generation();
    return this.store.sslConfigurations();
  }

  protected get credentialNames(): readonly string[] {
    this.generation();
    return this.store.credentialAliases();
  }

  protected get endpoints(): readonly EndpointView[] {
    this.generation();
    return ENDPOINT_MEMBERS.map((member) => ({
      ...this.fieldView(memberField(member)),
      member,
      label: ENDPOINT_LABELS[member] ?? member,
      value: this.store.memberText(member),
      required: this.store.required(memberField(member)),
    }));
  }

  protected get metadataRows(): readonly MetadataRow[] {
    this.generation();
    return this.store.tableMembers().map((entry) => ({ name: entry.name, value: displayOf(this.store.member(entry.name)) }));
  }

  protected get saveBlocked(): boolean {
    this.generation();
    return !this.store.canSave() || this.acting;
  }

  protected get discoverBlocked(): boolean {
    this.generation();
    return !this.store.canDiscover() || this.acting;
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

  /** Update JWKS is offered on a saved, unchanged description whose stored JWKS URL is not empty. */
  protected get offersUpdateJwks(): boolean {
    this.generation();
    return this.offersDelete && !this.store.dirty() && this.store.storedJwksUri() !== '';
  }

  protected get deletePending(): boolean {
    this.generation();
    return this.deleting;
  }

  protected get deleteVerb(): string {
    return actionLabel(OAUTH_SERVER_TAB_DESCRIPTOR, DELETE_ACTION);
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
      const action = this.store.mode() === 'create' ? STRINGS.oauthServerDescriptionsEmptyAgent : STRINGS.oauthServerFormRefusedAction;
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, action);
    }
    if (this.store.refusalCode() === STATE_CONFLICT_CODE) return STRINGS.formStaleSave;
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  /** The status line: an Update JWKS, a discovery, a token refused after the save, or "Saved". */
  protected get status(): string {
    this.generation();
    if (this.actionNotice !== '') return this.actionNotice;
    if (this.store.discovered() !== '') return STRINGS.oauthServerDiscovered.split('<issuer>').join(this.store.discovered());
    if (!this.store.saved()) return '';
    const refused = this.store.tokenRefused();
    if (refused !== '') return STRINGS.oauthServerTokenRefused.split('<reason>').join(refused);
    return STRINGS.formSaved;
  }

  protected get hasStatus(): boolean {
    return this.status !== '';
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  protected get issuerField(): FieldView {
    return this.fieldView(ISSUER_FIELD);
  }

  protected get sslField(): FieldView {
    return this.fieldView(SSL_FIELD);
  }

  protected get credentialsField(): FieldView {
    return this.fieldView(CREDENTIALS_FIELD);
  }

  protected get tokenField(): FieldView {
    return this.fieldView(TOKEN_FIELD);
  }

  /** The token's hint always describes it; its refusal too, when there is one. */
  protected get tokenDescribedBy(): string {
    const field = this.tokenField;
    return field.invalid ? `${field.id}-hint ${field.id}-reason` : `${field.id}-hint`;
  }

  protected get jwksField(): FieldView {
    return this.fieldView(memberField(JWKS_MEMBER));
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onIssuer(event: Event): void {
    this.store.setIssuer(this.textOf(event));
  }

  protected onSsl(event: Event): void {
    this.store.setSsl(this.textOf(event));
  }

  protected onCredentials(event: Event): void {
    this.store.setCredentials(this.textOf(event));
  }

  protected onToken(event: Event): void {
    this.store.setToken(this.textOf(event));
  }

  protected onMember(member: string, event: Event): void {
    this.store.setMemberText(member, this.textOf(event));
  }

  protected onChoice(choice: JwtChoice): void {
    this.store.setChoice(choice);
  }

  protected onBlur(field: string): void {
    this.store.onBlur(field);
  }

  protected onBlurMember(member: string): void {
    this.store.onBlur(memberField(member));
  }

  protected async onDiscover(): Promise<void> {
    if (this.discoverBlocked) return;
    this.clearAction();
    const found = await this.store.discover();
    if (!found) this.afterRefusal();
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
    // A create, or an edit that changed the issuer, replaces the route with the description's own
    // URL, so the address bar names the entity; the page is built again there over its edit.
    const id = this.store.savedId();
    if (id !== '' && (creating || id !== this.routeId())) {
      this.store.retainAcrossRouteReplacement();
      void this.router.navigateByUrl(this.editorUrl(id), { replaceUrl: true });
    }
  }

  /** Update JWKS: the tab's declared action, sent as its row menu sends it (AD-53). */
  protected async onUpdateJwks(): Promise<void> {
    if (!this.offersUpdateJwks || this.actionBlocked) return;
    const issuer = this.store.storedIssuer();
    const url = this.store.storedJwksUri();
    this.clearAction();
    this.acting = true;
    this.bump();
    const applied = await this.handler.sendFor(OAUTH_SERVER_TAB_DESCRIPTOR, UPDATE_JWKS_ACTION, issuer);
    this.acting = false;
    if (!applied) {
      this.actionRefusal = this.tabRefusal();
      this.bump();
      return;
    }
    // The refresh can clear the stored X.509 credential, so the form reads the description again.
    await this.store.open(issuer);
    this.actionNotice = STRINGS.oauthServerJwksUpdated.split('<url>').join(url);
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

  /** The typed issuer matched: send the tab's declared delete, then return to the tab (AD-53). */
  protected async confirmDelete(): Promise<void> {
    this.deleting = false;
    this.acting = true;
    this.bump();
    const applied = await this.handler.sendFor(OAUTH_SERVER_TAB_DESCRIPTOR, DELETE_ACTION, this.store.storedIssuer());
    this.acting = false;
    if (!applied) {
      this.actionRefusal = this.tabRefusal();
      this.bump();
      return;
    }
    this.formDirty.setDirty(false);
    void this.router.navigateByUrl(withQuery(OAUTH_SERVER_TAB_ROUTE, this.router.url));
  }

  protected focusField(field: string): void {
    document.getElementById(this.controlId(field))?.focus();
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(OAUTH_SERVER_TAB_ROUTE, this.router.url));
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
    const tab = screenForRoute(OAUTH_SERVER_TAB_ROUTE);
    return tab === null ? '' : this.stores.for(tab.descriptor, tab.refreshRates).refusal();
  }

  private textOf(event: Event): string {
    const target = event.target;
    return target instanceof HTMLInputElement ? target.value : '';
  }

  /** The issuer this route names, or `''` for the create. */
  private routeId(): string {
    const screen = screenForRoute(OAUTH_SERVER_FORM_ROUTE);
    return screen === null ? '' : ownIdSegment(screen, this.router.url);
  }

  /**
   * After a refused Save or discovery: the error summary takes focus, then the first invalid field,
   * in the order EXPERIENCE.md's `form-page` validation rule states.
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
    return { id, reason, invalid, describedBy: invalid ? `${id}-reason` : null };
  }

  /**
   * A field's control id. A metadata member the form draws no field for is refused on the metadata
   * table, which takes focus in its place.
   */
  private controlId(field: string): string {
    const member = field.startsWith('Metadata.') ? field.slice('Metadata.'.length) : '';
    if (member !== '' && member !== JWKS_MEMBER && !ENDPOINT_MEMBERS.includes(member)) return 'ocu-oauth-server-metadata';
    return `ocu-oauth-server-${field.replace('.', '-')}`;
  }

  /** The description's own URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private editorUrl(id: string): string {
    const editor = this.navigation.screenForUrl(this.router.url);
    const route = editor === null ? OAUTH_SERVER_FORM_ROUTE : editor.route;
    return withQuery(`${route}/${encodeEntityId(id)}`, this.router.url);
  }
}
