import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeAction } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { ENTITY_SINGLETON_ID } from '../../core/screens.generated';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The routes the form saves through: `POST` creates the configuration, `PUT` edits it. */
export const OAUTH_AUTH_SERVER_PATH = '/api/ocupilot/oauth/authorization-server';

/** The form read: the rules, the readable names, the registered clients and the configuration. */
export const OAUTH_AUTH_SERVER_FORM_PATH = `${OAUTH_AUTH_SERVER_PATH}/form`;

/** The entity type, scope and id the changes this form publishes carry (AD-13, AD-14). */
export const OAUTH_AUTH_SERVER_ENTITY = 'oauth2-server';

export const OAUTH_AUTH_SERVER_SCOPE = 'instance';

export const OAUTH_AUTH_SERVER_ID = ENTITY_SINGLETON_ID;

/** The text fields, named as the server names them. */
export const ISSUER_FIELD = 'IssuerEndpoint';
export const DESCRIPTION_FIELD = 'Description';
export const REFRESH_FIELD = 'ReturnRefreshToken';
export const SSL_FIELD = 'SSLConfiguration';
export const DEFAULT_SCOPE_FIELD = 'DefaultScope';
export const CREDENTIALS_FIELD = 'ServerCredentials';
export const SIGNING_FIELD = 'SigningAlgorithm';
export const KEY_FIELD = 'KeyAlgorithm';
export const ENCRYPTION_FIELD = 'EncryptionAlgorithm';
export const NAMESPACE_FIELD = 'CustomizationNamespace';
export const AUTHENTICATE_FIELD = 'AuthenticateClass';
export const VALIDATE_FIELD = 'ValidateUserClass';
export const SESSION_CLASS_FIELD = 'SessionClass';
export const GENERATE_FIELD = 'GenerateTokenClass';
export const REVOKE_FIELD = 'RevokeTokenClass';

/** The six top-level flags. */
export const AUD_FIELD = 'AudRequired';
export const SUPPORT_SESSION_FIELD = 'SupportSession';
export const PUBLIC_REFRESH_FIELD = 'AllowPublicClientRefresh';
export const PKCE_PUBLIC_FIELD = 'ForcePKCEForPublicClients';
export const PKCE_CONFIDENTIAL_FIELD = 'ForcePKCEForConfidentialClients';
export const UNSUPPORTED_SCOPE_FIELD = 'AllowUnsupportedScope';

/** The five intervals, in seconds. */
export const ACCESS_INTERVAL_FIELD = 'AccessTokenInterval';
export const CODE_INTERVAL_FIELD = 'AuthorizationCodeInterval';
export const REFRESH_INTERVAL_FIELD = 'RefreshTokenInterval';
export const SESSION_INTERVAL_FIELD = 'SessionInterval';
export const SECRET_INTERVAL_FIELD = 'ClientSecretInterval';

/** The two lists, and the metadata the editor sets. */
export const SCOPES_FIELD = 'SupportedScopes';
export const ROLES_FIELD = 'CustomizationRoles';
export const METADATA_FIELD = 'Metadata';
export const GRANTS_MEMBER = 'grant_types_supported';
export const FRONT_CHANNEL_MEMBER = 'frontchannel_logout_supported';
export const FRONT_SESSION_MEMBER = 'frontchannel_logout_session_supported';
export const SERVICE_DOCS_MEMBER = 'service_documentation';
export const POLICY_MEMBER = 'op_policy_uri';
export const TOS_MEMBER = 'op_tos_uri';

/** The one secret: written through its own write, never read back (AD-3, AD-35, AD-56). */
export const PASSWORD_FIELD = 'ServerPassword';

/** The field a metadata member's refusal names. */
export function metadataField(member: string): string {
  return `${METADATA_FIELD}.${member}`;
}

/** The grant types the editor offers, in the classic page's order; the vendor always adds the refresh grant. */
export const GRANT_CHOICES: readonly string[] = ['authorization_code', 'implicit', 'password', 'client_credentials', 'jwt_authorization'];

/** The refresh token policies, in the classic page's order. */
export const REFRESH_POLICIES: readonly string[] = ['', 'a', 'c', 'f'];

/** The vendor's algorithm lists, in the classic page's order. */
export const SIGNING_ALGORITHMS: readonly string[] = ['RS256', 'RS384', 'RS512', 'HS256', 'HS384', 'HS512', 'ES256', 'ES384', 'ES512', 'PS256', 'PS384', 'PS512'];
export const KEY_ALGORITHMS: readonly string[] = ['RSA1_5', 'RSA-OAEP', 'A128KW', 'A192KW', 'A256KW', 'dir'];
export const ENCRYPTION_ALGORITHMS: readonly string[] = ['A128CBC-HS256', 'A192CBC-HS384', 'A256CBC-HS512'];

/** The five tabs, named and ordered as the classic editor's. */
export const GENERAL_TAB = 'general';
export const SCOPES_TAB = 'scopes';
export const INTERVALS_TAB = 'intervals';
export const JWT_TAB = 'jwt';
export const CUSTOMIZATION_TAB = 'customization';

/** Which tab each field is drawn on. */
export const AUTH_SERVER_FIELD_TABS: Readonly<Record<string, string>> = {
  [ISSUER_FIELD]: GENERAL_TAB,
  [DESCRIPTION_FIELD]: GENERAL_TAB,
  [AUD_FIELD]: GENERAL_TAB,
  [SUPPORT_SESSION_FIELD]: GENERAL_TAB,
  [PUBLIC_REFRESH_FIELD]: GENERAL_TAB,
  [PKCE_PUBLIC_FIELD]: GENERAL_TAB,
  [PKCE_CONFIDENTIAL_FIELD]: GENERAL_TAB,
  [metadataField(FRONT_CHANNEL_MEMBER)]: GENERAL_TAB,
  [metadataField(FRONT_SESSION_MEMBER)]: GENERAL_TAB,
  [REFRESH_FIELD]: GENERAL_TAB,
  [metadataField(GRANTS_MEMBER)]: GENERAL_TAB,
  [metadataField(SERVICE_DOCS_MEMBER)]: GENERAL_TAB,
  [metadataField(POLICY_MEMBER)]: GENERAL_TAB,
  [metadataField(TOS_MEMBER)]: GENERAL_TAB,
  [SSL_FIELD]: GENERAL_TAB,
  [METADATA_FIELD]: GENERAL_TAB,
  [SCOPES_FIELD]: SCOPES_TAB,
  [UNSUPPORTED_SCOPE_FIELD]: SCOPES_TAB,
  [DEFAULT_SCOPE_FIELD]: SCOPES_TAB,
  [ACCESS_INTERVAL_FIELD]: INTERVALS_TAB,
  [CODE_INTERVAL_FIELD]: INTERVALS_TAB,
  [REFRESH_INTERVAL_FIELD]: INTERVALS_TAB,
  [SESSION_INTERVAL_FIELD]: INTERVALS_TAB,
  [SECRET_INTERVAL_FIELD]: INTERVALS_TAB,
  [CREDENTIALS_FIELD]: JWT_TAB,
  [PASSWORD_FIELD]: JWT_TAB,
  [SIGNING_FIELD]: JWT_TAB,
  [KEY_FIELD]: JWT_TAB,
  [ENCRYPTION_FIELD]: JWT_TAB,
  [AUTHENTICATE_FIELD]: CUSTOMIZATION_TAB,
  [VALIDATE_FIELD]: CUSTOMIZATION_TAB,
  [SESSION_CLASS_FIELD]: CUSTOMIZATION_TAB,
  [GENERATE_FIELD]: CUSTOMIZATION_TAB,
  [REVOKE_FIELD]: CUSTOMIZATION_TAB,
  [NAMESPACE_FIELD]: CUSTOMIZATION_TAB,
  [ROLES_FIELD]: CUSTOMIZATION_TAB,
};

/** Every field in form order, which is also the order a refused Save's tab is chosen by. */
export const AUTH_SERVER_FIELD_ORDER: readonly string[] = Object.keys(AUTH_SERVER_FIELD_TABS);

/** What the form is doing: creating the configuration, or editing the one the instance holds. */
export type FormMode = 'create' | 'edit';

/** The text fields, by their store key. */
export type TextKey =
  | 'issuer'
  | 'description'
  | 'refresh'
  | 'ssl'
  | 'defaultScope'
  | 'credentials'
  | 'signing'
  | 'keyAlgorithm'
  | 'encryption'
  | 'namespace'
  | 'authenticate'
  | 'validate'
  | 'sessionClass'
  | 'generate'
  | 'revoke'
  | 'accessInterval'
  | 'codeInterval'
  | 'refreshInterval'
  | 'sessionInterval'
  | 'secretInterval';

/** The flags, by their store key. */
export type FlagKey = 'aud' | 'supportSession' | 'publicRefresh' | 'pkcePublic' | 'pkceConfidential' | 'unsupportedScope';

/** The metadata members the editor sets as text, by their store key. */
export type UrlKey = 'serviceDocs' | 'policy' | 'tos';

/** The two front-channel metadata flags, by their store key. */
export type MetadataFlagKey = 'frontChannel' | 'frontSession';

export const TEXT_FIELDS: Readonly<Record<TextKey, string>> = {
  issuer: ISSUER_FIELD,
  description: DESCRIPTION_FIELD,
  refresh: REFRESH_FIELD,
  ssl: SSL_FIELD,
  defaultScope: DEFAULT_SCOPE_FIELD,
  credentials: CREDENTIALS_FIELD,
  signing: SIGNING_FIELD,
  keyAlgorithm: KEY_FIELD,
  encryption: ENCRYPTION_FIELD,
  namespace: NAMESPACE_FIELD,
  authenticate: AUTHENTICATE_FIELD,
  validate: VALIDATE_FIELD,
  sessionClass: SESSION_CLASS_FIELD,
  generate: GENERATE_FIELD,
  revoke: REVOKE_FIELD,
  accessInterval: ACCESS_INTERVAL_FIELD,
  codeInterval: CODE_INTERVAL_FIELD,
  refreshInterval: REFRESH_INTERVAL_FIELD,
  sessionInterval: SESSION_INTERVAL_FIELD,
  secretInterval: SECRET_INTERVAL_FIELD,
};

/** The intervals among the text keys: sent as numbers when they read as one. */
const INTERVAL_KEYS: readonly TextKey[] = ['accessInterval', 'codeInterval', 'refreshInterval', 'sessionInterval', 'secretInterval'];

export const FLAG_FIELDS: Readonly<Record<FlagKey, string>> = {
  aud: AUD_FIELD,
  supportSession: SUPPORT_SESSION_FIELD,
  publicRefresh: PUBLIC_REFRESH_FIELD,
  pkcePublic: PKCE_PUBLIC_FIELD,
  pkceConfidential: PKCE_CONFIDENTIAL_FIELD,
  unsupportedScope: UNSUPPORTED_SCOPE_FIELD,
};

export const URL_MEMBERS: Readonly<Record<UrlKey, string>> = {
  serviceDocs: SERVICE_DOCS_MEMBER,
  policy: POLICY_MEMBER,
  tos: TOS_MEMBER,
};

export const METADATA_FLAG_MEMBERS: Readonly<Record<MetadataFlagKey, string>> = {
  frontChannel: FRONT_CHANNEL_MEMBER,
  frontSession: FRONT_SESSION_MEMBER,
};

/** One supported scope. */
export interface Scope {
  readonly scope: string;
  readonly description: string;
}

export interface FieldRule {
  readonly field: string;
  readonly code: string;
  readonly reason: string;
}

/** One client registered with the server, as the form read names it. */
export interface RegisteredClient {
  readonly clientId: string;
  readonly name: string;
}

/** The fields the form edits. */
interface Held {
  readonly text: Readonly<Record<TextKey, string>>;
  readonly flags: Readonly<Record<FlagKey, boolean>>;
  readonly urls: Readonly<Record<UrlKey, string>>;
  readonly metadataFlags: Readonly<Record<MetadataFlagKey, boolean>>;
  readonly grants: readonly string[];
  readonly scopes: readonly Scope[];
  readonly roles: readonly string[];
}

/** A new configuration's values: the classic page's own for a new configuration. */
const NEW_HELD: Held = {
  text: {
    issuer: '',
    description: '',
    refresh: '',
    ssl: '',
    defaultScope: '',
    credentials: '',
    signing: 'RS256',
    keyAlgorithm: '',
    encryption: '',
    namespace: '%SYS',
    authenticate: '%OAuth2.Server.Authenticate',
    validate: '%OAuth2.Server.Validate',
    sessionClass: 'OAuth2.Server.Session',
    generate: '%OAuth2.Server.Generate',
    revoke: '%OAuth2.Server.Revoke',
    accessInterval: '3600',
    codeInterval: '60',
    refreshInterval: '86400',
    sessionInterval: '86400',
    secretInterval: '0',
  },
  flags: { aud: false, supportSession: true, publicRefresh: false, pkcePublic: false, pkceConfidential: false, unsupportedScope: false },
  urls: { serviceDocs: '', policy: '', tos: '' },
  metadataFlags: { frontChannel: true, frontSession: true },
  grants: ['authorization_code'],
  scopes: [],
  roles: ['%DB_IRISSYS', '%Manager'],
};

function record(source: unknown): Record<string, unknown> | null {
  return source !== null && typeof source === 'object' && !Array.isArray(source) ? (source as Record<string, unknown>) : null;
}

function textAt(source: unknown, key: string): string {
  const value = record(source)?.[key];
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

function stringsOf(value: unknown): string[] {
  return Array.isArray(value) ? value.filter((entry): entry is string => typeof entry === 'string') : [];
}

function same(left: unknown, right: unknown): boolean {
  return JSON.stringify(left) === JSON.stringify(right);
}

/** Whether `role` is `%All` or an `%Admin_` role, compared without regard to case as IRIS resolves a role. */
export function isPrivilegedRole(role: string): boolean {
  const name = role.trim().toUpperCase();
  return name === '%ALL' || name.startsWith('%ADMIN_');
}

/** An interval's wire value: its number when the text is a whole number, the text otherwise (the server refuses it). */
function intervalWire(text: string): number | string {
  return /^-?\d{1,10}$/.test(text.trim()) ? Number(text.trim()) : text;
}

/**
 * The OAuth 2.0 authorization server editor's store (AD-19, AD-55): this instance's one
 * configuration, on `security/oauth/server/edit` whatever id segment the route carries -- a create
 * when the instance has none, an edit of the stored one otherwise.
 *
 * **It composes no payload of its own.** `POST` and `PUT /oauth/authorization-server` resolve the
 * tool classes the agent's `security.oauthserver.*` do; the server sends the complete set (AD-4), and
 * every field sentence is the server's (AD-39). An edit sends only what changed since its fresh read:
 * the scopes and the roles whole, and the metadata as the members that changed.
 *
 * **The key password is held in this store alone, until Save** (AD-35): never pre-filled, and sent
 * only when typed.
 */
@Injectable({ providedIn: 'root' })
export class OAuthServerForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private modeValue: FormMode = 'create';

  private buffer: Held = NEW_HELD;

  private opened: Held = NEW_HELD;

  private passwordValue = '';

  private namespacesValue: readonly string[] = [];

  private rolesValue: readonly string[] = [];

  private sslValue: readonly string[] = [];

  private credentialsValue: readonly string[] = [];

  private clientsValue: readonly RegisteredClient[] = [];

  private clientsHiddenValue = false;

  private rulesValue: readonly FieldRule[] = [];

  private requiredValue: readonly string[] = [];

  private loadedValue = false;

  private heldValue = false;

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

  private savedValue = false;

  private passwordRefusedValue = '';

  private savedIssuerValue = '';

  private retainingValue = false;

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  // --- reads -----------------------------------------------------------------------------------

  mode(): FormMode {
    return this.modeValue;
  }

  loaded(): boolean {
    return this.loadedValue;
  }

  busy(): boolean {
    return this.savingValue;
  }

  /** Whether the instance's configuration is held, which is what Delete and Rotate Keys act on. */
  held(): boolean {
    return this.heldValue;
  }

  text(key: TextKey): string {
    return this.buffer.text[key];
  }

  flag(key: FlagKey): boolean {
    return this.buffer.flags[key];
  }

  url(key: UrlKey): string {
    return this.buffer.urls[key];
  }

  metadataFlag(key: MetadataFlagKey): boolean {
    return this.buffer.metadataFlags[key];
  }

  granted(grant: string): boolean {
    return this.buffer.grants.includes(grant);
  }

  scopes(): readonly Scope[] {
    return this.buffer.scopes;
  }

  roles(): readonly string[] {
    return this.buffer.roles;
  }

  /** The issuer the fresh read answered: what Delete names and the tab's row carries. */
  storedIssuer(): string {
    return this.opened.text.issuer;
  }

  /** The server credentials the fresh read answered: Rotate Keys is offered only while they are empty. */
  storedCredentials(): string {
    return this.opened.text.credentials;
  }

  /** The password as typed, `''` until it is (AD-35). */
  password(): string {
    return this.passwordValue;
  }

  namespaces(): readonly string[] {
    return this.namespacesValue;
  }

  /** The roles the form offers: the readable ones, with the stored and chosen ones kept. */
  roleChoices(): readonly string[] {
    const choices = [...this.rolesValue];
    for (const role of [...this.opened.roles, ...this.buffer.roles]) if (!choices.includes(role)) choices.push(role);
    return choices;
  }

  /** Whether the roles as edited add `%All` or an `%Admin_` role the stored configuration does not hold. */
  addsPrivilegedRole(): boolean {
    const held = this.opened.roles.map((role) => role.toUpperCase());
    return this.buffer.roles.some((role) => isPrivilegedRole(role) && !(this.modeValue === 'edit' && held.includes(role.toUpperCase())));
  }

  sslConfigurations(): readonly string[] {
    return this.sslValue;
  }

  credentials(): readonly string[] {
    return this.credentialsValue;
  }

  clients(): readonly RegisteredClient[] {
    return this.clientsValue;
  }

  clientsHidden(): boolean {
    return this.clientsHiddenValue;
  }

  editable(): boolean {
    return (this.modeValue === 'create' || this.heldValue) && !this.busy();
  }

  canSave(): boolean {
    return !this.busy() && this.loadedValue;
  }

  required(field: string): boolean {
    return this.requiredValue.includes(field);
  }

  violations(): readonly Violation[] {
    return this.violationList;
  }

  violationFor(field: string): string {
    return reasonForField(this.violationList, field);
  }

  reason(): string {
    return this.envelopeReason;
  }

  refusalCode(): string {
    return this.refusalCodeValue;
  }

  refusalPair(): string {
    return this.refusalPairValue;
  }

  saved(): boolean {
    return this.savedValue;
  }

  /** The sentence the password write was refused with after the save, or `''`. */
  passwordRefused(): string {
    return this.passwordRefusedValue;
  }

  /** The issuer the last accepted Save answered: what a create's route replacement names. */
  savedIssuer(): string {
    return this.savedIssuerValue;
  }

  dirty(): boolean {
    return this.formDirty.dirty();
  }

  retaining(): boolean {
    return this.retainingValue;
  }

  /** Keep this form's state across the one navigation that is not a departure. */
  retainAcrossRouteReplacement(): void {
    this.retainingValue = true;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything: from the sign-out teardown and when the form is left. */
  reset(): void {
    this.generation += 1;
    this.modeValue = 'create';
    this.buffer = NEW_HELD;
    this.opened = NEW_HELD;
    this.passwordValue = '';
    this.namespacesValue = [];
    this.rolesValue = [];
    this.sslValue = [];
    this.credentialsValue = [];
    this.clientsValue = [];
    this.clientsHiddenValue = false;
    this.rulesValue = [];
    this.requiredValue = [];
    this.loadedValue = false;
    this.heldValue = false;
    this.savingValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.passwordRefusedValue = '';
    this.savedIssuerValue = '';
    this.retainingValue = false;
    this.formDirty.reset();
    this.notify();
  }

  /**
   * Open the form over the instance's configuration: an edit when the form read answers one, a
   * create with the classic page's values otherwise. An arrival that is a Save's own re-read keeps
   * the saved confirmation on screen.
   */
  async open(): Promise<void> {
    const arriving = this.retainingValue && this.savedValue;
    const refused = this.passwordRefusedValue;
    const issuer = this.savedIssuerValue;
    this.reset();
    if (arriving) {
      this.savedValue = true;
      this.passwordRefusedValue = refused;
      this.savedIssuerValue = issuer;
    }
    const generation = this.generation;
    const result = await this.api().requestJson<unknown>(OAUTH_AUTH_SERVER_FORM_PATH);
    if (generation !== this.generation) return;
    this.absorb(result);
    this.loadedValue = true;
    this.notify();
  }

  setText(key: TextKey, value: string): void {
    if (!this.editable() || this.buffer.text[key] === value) return;
    this.buffer = { ...this.buffer, text: { ...this.buffer.text, [key]: value } };
    this.change(TEXT_FIELDS[key]);
  }

  setFlag(key: FlagKey, value: boolean): void {
    if (!this.editable() || this.buffer.flags[key] === value) return;
    this.buffer = { ...this.buffer, flags: { ...this.buffer.flags, [key]: value } };
    this.change(FLAG_FIELDS[key]);
  }

  setUrl(key: UrlKey, value: string): void {
    if (!this.editable() || this.buffer.urls[key] === value) return;
    this.buffer = { ...this.buffer, urls: { ...this.buffer.urls, [key]: value } };
    this.change(metadataField(URL_MEMBERS[key]));
  }

  setMetadataFlag(key: MetadataFlagKey, value: boolean): void {
    if (!this.editable() || this.buffer.metadataFlags[key] === value) return;
    this.buffer = { ...this.buffer, metadataFlags: { ...this.buffer.metadataFlags, [key]: value } };
    this.change(metadataField(METADATA_FLAG_MEMBERS[key]));
  }

  setGrant(grant: string, on: boolean): void {
    if (!this.editable() || this.buffer.grants.includes(grant) === on) return;
    const grants = on ? GRANT_CHOICES.filter((entry) => entry === grant || this.buffer.grants.includes(entry)) : this.buffer.grants.filter((entry) => entry !== grant);
    this.buffer = { ...this.buffer, grants };
    this.change(metadataField(GRANTS_MEMBER));
  }

  setRole(role: string, on: boolean): void {
    if (!this.editable() || this.buffer.roles.includes(role) === on) return;
    const roles = on ? [...this.buffer.roles, role] : this.buffer.roles.filter((entry) => entry !== role);
    this.buffer = { ...this.buffer, roles };
    this.change(ROLES_FIELD);
  }

  setPassword(value: string): void {
    if (!this.editable() || this.passwordValue === value) return;
    this.passwordValue = value;
    this.change(PASSWORD_FIELD);
  }

  setScope(index: number, part: keyof Scope, value: string): void {
    const current = this.buffer.scopes[index];
    if (!this.editable() || current === undefined || current[part] === value) return;
    this.buffer = { ...this.buffer, scopes: this.buffer.scopes.map((entry, at) => (at === index ? { ...entry, [part]: value } : entry)) };
    this.change(SCOPES_FIELD);
  }

  addScope(): void {
    if (!this.editable()) return;
    this.buffer = { ...this.buffer, scopes: [...this.buffer.scopes, { scope: '', description: '' }] };
    this.change(SCOPES_FIELD);
  }

  removeScope(index: number): void {
    if (!this.editable() || index < 0 || index >= this.buffer.scopes.length) return;
    this.buffer = { ...this.buffer, scopes: this.buffer.scopes.filter((_, at) => at !== index) };
    this.change(SCOPES_FIELD);
  }

  /**
   * On blur: render the server's required-field sentence on an empty required text field of a
   * create, as the form read's first rule for it words it.
   */
  onBlur(field: string): void {
    if (this.modeValue !== 'create' || !this.required(field)) return;
    const key = (Object.keys(TEXT_FIELDS) as TextKey[]).find((entry) => TEXT_FIELDS[entry] === field);
    if (key === undefined || this.buffer.text[key].trim() !== '') return;
    const rule = this.rulesValue.find((entry) => entry.field === field);
    if (rule === undefined || this.violationList.some((entry) => entry.field === field)) return;
    this.violationList = [...this.violationList, { field, code: rule.code, reason: rule.reason }];
    this.notify();
  }

  /**
   * Save: a create posts every field; an edit puts what changed since its fresh read. The typed
   * password travels beside them and is written after the configuration (AD-56); the store forgets
   * it either way. An accepted Save publishes one change event (AD-14).
   */
  async save(): Promise<boolean> {
    if (!this.canSave()) return false;
    const creating = this.modeValue === 'create';
    const body = creating ? this.createBody() : this.changedBody();
    if (!creating && Object.keys(body).length === 0 && this.passwordValue === '') {
      this.clearRefusal();
      this.violationList = [];
      this.savedValue = true;
      this.formDirty.setDirty(false);
      this.notify();
      return true;
    }
    if (this.passwordValue !== '') body[PASSWORD_FIELD] = this.passwordValue;
    const generation = this.generation;
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.passwordRefusedValue = '';
    this.notify();
    const result = await this.api().requestJson<unknown>(OAUTH_AUTH_SERVER_PATH, {
      method: creating ? 'POST' : 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    delete body[PASSWORD_FIELD];
    if (generation !== this.generation) return false;
    this.savingValue = false;
    this.passwordValue = '';
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.envelopeReason = this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      this.notify();
      return false;
    }
    this.savedIssuerValue = textAt(result.body, 'issuer') || this.buffer.text.issuer;
    this.passwordRefusedValue = textAt(result.body, 'passwordRefused');
    this.opened = this.buffer;
    this.modeValue = 'edit';
    this.heldValue = true;
    this.savedValue = true;
    this.formDirty.setDirty(false);
    this.publish(creating ? 'created' : 'updated');
    this.notify();
    return true;
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  private change(field: string): void {
    if (this.violationList.some((entry) => entry.field === field)) {
      this.violationList = this.violationList.filter((entry) => entry.field !== field);
    }
    this.savedValue = false;
    this.passwordRefusedValue = '';
    this.formDirty.setDirty(true);
    this.notify();
  }

  private metadataWire(held: Held): Record<string, unknown> {
    return {
      [GRANTS_MEMBER]: [...held.grants],
      [FRONT_CHANNEL_MEMBER]: held.metadataFlags.frontChannel,
      [FRONT_SESSION_MEMBER]: held.metadataFlags.frontSession,
      [SERVICE_DOCS_MEMBER]: held.urls.serviceDocs,
      [POLICY_MEMBER]: held.urls.policy,
      [TOS_MEMBER]: held.urls.tos,
    };
  }

  private scopesWire(held: Held): readonly Record<string, string>[] {
    return held.scopes.map((entry) => ({ Scope: entry.scope, Description: entry.description }));
  }

  private textWire(key: TextKey): unknown {
    const value = this.buffer.text[key];
    return INTERVAL_KEYS.includes(key) ? intervalWire(value) : value;
  }

  /** A create's body: every field (AD-54). */
  private createBody(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const key of Object.keys(TEXT_FIELDS) as TextKey[]) out[TEXT_FIELDS[key]] = this.textWire(key);
    for (const key of Object.keys(FLAG_FIELDS) as FlagKey[]) out[FLAG_FIELDS[key]] = this.buffer.flags[key];
    out[SCOPES_FIELD] = this.scopesWire(this.buffer);
    out[ROLES_FIELD] = [...this.buffer.roles];
    out[METADATA_FIELD] = this.metadataWire(this.buffer);
    return out;
  }

  /** An edit's body: the fields changed since the fresh read; the lists whole, the metadata as its changed members. */
  private changedBody(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const key of Object.keys(TEXT_FIELDS) as TextKey[]) {
      if (this.buffer.text[key] !== this.opened.text[key]) out[TEXT_FIELDS[key]] = this.textWire(key);
    }
    for (const key of Object.keys(FLAG_FIELDS) as FlagKey[]) {
      if (this.buffer.flags[key] !== this.opened.flags[key]) out[FLAG_FIELDS[key]] = this.buffer.flags[key];
    }
    if (!same(this.buffer.scopes, this.opened.scopes)) out[SCOPES_FIELD] = this.scopesWire(this.buffer);
    if (!same(this.buffer.roles, this.opened.roles)) out[ROLES_FIELD] = [...this.buffer.roles];
    const now = this.metadataWire(this.buffer);
    const before = this.metadataWire(this.opened);
    const members: Record<string, unknown> = {};
    for (const member of Object.keys(now)) if (!same(now[member], before[member])) members[member] = now[member];
    if (Object.keys(members).length > 0) out[METADATA_FIELD] = members;
    return out;
  }

  private absorb(result: JsonResult<unknown>): void {
    if (result.kind !== 'ok') {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      return;
    }
    const body = record(result.body);
    const rules: FieldRule[] = [];
    for (const entry of Array.isArray(body?.['rules']) ? (body['rules'] as unknown[]) : []) {
      const field = textAt(entry, 'field');
      const code = textAt(entry, 'code');
      const reason = textAt(entry, 'reason');
      if (field !== '' && code !== '' && reason !== '') rules.push({ field, code, reason });
    }
    this.rulesValue = rules;
    this.requiredValue = stringsOf(body?.['requiredFields']);
    this.namespacesValue = stringsOf(body?.['namespaces']);
    this.rolesValue = stringsOf(body?.['roles']);
    this.sslValue = stringsOf(body?.['sslConfigurations']);
    this.credentialsValue = stringsOf(body?.['credentials']);
    this.clientsHiddenValue = body?.['clientsHidden'] === true;
    this.clientsValue = (Array.isArray(body?.['clients']) ? (body['clients'] as unknown[]) : [])
      .map((entry) => ({ clientId: textAt(entry, 'ClientId'), name: textAt(entry, 'Name') }))
      .filter((entry) => entry.clientId !== '');
    const definition = record(body?.['definition']);
    if (definition === null) {
      this.modeValue = 'create';
      return;
    }
    const metadata = record(definition[METADATA_FIELD]);
    const text = { ...NEW_HELD.text };
    for (const key of Object.keys(TEXT_FIELDS) as TextKey[]) text[key] = textAt(definition, TEXT_FIELDS[key]);
    const flags = { ...NEW_HELD.flags };
    for (const key of Object.keys(FLAG_FIELDS) as FlagKey[]) flags[key] = definition[FLAG_FIELDS[key]] === true;
    const urls = { ...NEW_HELD.urls };
    for (const key of Object.keys(URL_MEMBERS) as UrlKey[]) urls[key] = textAt(metadata, URL_MEMBERS[key]);
    const metadataFlags = { ...NEW_HELD.metadataFlags };
    for (const key of Object.keys(METADATA_FLAG_MEMBERS) as MetadataFlagKey[]) metadataFlags[key] = metadata?.[METADATA_FLAG_MEMBERS[key]] === true;
    const stored = stringsOf(metadata?.[GRANTS_MEMBER]);
    const scopes = (Array.isArray(definition[SCOPES_FIELD]) ? (definition[SCOPES_FIELD] as unknown[]) : []).map((entry) => ({ scope: textAt(entry, 'Scope'), description: textAt(entry, 'Description') }));
    this.buffer = { text, flags, urls, metadataFlags, grants: GRANT_CHOICES.filter((grant) => stored.includes(grant)), scopes, roles: stringsOf(definition[ROLES_FIELD]) };
    this.opened = this.buffer;
    this.modeValue = 'edit';
    this.heldValue = true;
  }

  private rememberRefusal(result: JsonResult<unknown>): void {
    if (result.kind !== 'error') {
      this.clearRefusal();
      return;
    }
    this.refusalCodeValue = result.code ?? '';
    const pair = result.detail === null ? undefined : result.detail['failedPair'];
    this.refusalPairValue = typeof pair === 'string' ? pair : '';
  }

  private clearRefusal(): void {
    this.envelopeReason = '';
    this.refusalCodeValue = '';
    this.refusalPairValue = '';
  }

  private publish(action: ChangeAction): void {
    this.injector.get(ChangeBus).publish({ kind: 'changed', type: OAUTH_AUTH_SERVER_ENTITY, scope: OAUTH_AUTH_SERVER_SCOPE, id: OAUTH_AUTH_SERVER_ID, action });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
