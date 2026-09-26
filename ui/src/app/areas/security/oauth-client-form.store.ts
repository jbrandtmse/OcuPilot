import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus, type ChangeAction } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The routes the form saves through: `POST` creates, `PUT <path>/<id>` edits. */
export const OAUTH_CLIENT_PATH = '/api/ocupilot/oauth/client-configuration';

/** The form read: the rules, the members, the readable names and, with a name, the configuration. */
export const OAUTH_CLIENT_FORM_PATH = `${OAUTH_CLIENT_PATH}/form`;

/** The entity types and scope the changes this form publishes carry (AD-13, AD-14). */
export const OAUTH_CLIENT_ENTITY = 'oauth2-client-configuration';

export const OAUTH_SERVER_DEFINITION_ENTITY = 'oauth2-server-definition';

export const OAUTH_CLIENT_SCOPE = 'instance';

/** The top-level fields, named as the server names them. */
export const NAME_FIELD = 'ApplicationName';

export const SERVER_FIELD = 'ServerDefinition';

export const ENABLED_FIELD = 'Enabled';

export const DESCRIPTION_FIELD = 'Description';

export const TYPE_FIELD = 'ClientType';

export const SSL_FIELD = 'SSLConfiguration';

export const REDIRECT_FIELD = 'RedirectionEndpoint';

export const AUDIENCE_FIELD = 'JWTAudience';

export const INTERVAL_FIELD = 'JWTInterval';

export const CLIENT_ID_FIELD = 'ClientId';

export const CREDENTIALS_FIELD = 'ClientCredentials';

export const SCOPE_FIELD = 'DefaultScope';

export const METADATA_FIELD = 'Metadata';

/** The four secrets: written through their own writes, never read back (AD-3, AD-35, AD-56). */
export const SECRET_FIELD = 'ClientSecret';

export const PASSWORD_FIELD = 'ClientPassword';

export const REGISTRATION_TOKEN_FIELD = 'RegistrationAccessToken';

export const INITIAL_TOKEN_FIELD = 'InitialAccessToken';

export const SECRET_FIELDS: readonly string[] = [SECRET_FIELD, PASSWORD_FIELD, REGISTRATION_TOKEN_FIELD, INITIAL_TOKEN_FIELD];

/** The member that holds a registered client's registration URI. */
export const REGISTRATION_URI_MEMBER = 'registration_client_uri';

/** The member the grant types live in, and the five the classic page offers, in its order. */
export const GRANT_MEMBER = 'grant_types';

export const GRANT_TYPES: readonly string[] = ['authorization_code', 'implicit', 'password', 'client_credentials', 'jwt_authorization'];

/** The three client types the instance stores, and the one that has no redirect URL. */
export const CLIENT_TYPES: readonly string[] = ['confidential', 'public', 'resource'];

export const RESOURCE_TYPE = 'resource';

/** The four tabs, named and ordered as the classic page's (DW-1644). */
export const GENERAL_TAB = 'general';
export const INFORMATION_TAB = 'information';
export const JWT_TAB = 'jwt';
export const CREDENTIALS_TAB = 'credentials';

/**
 * Which tab each field is drawn on, in form order. A metadata member the form draws no control for
 * is shown in the read-only table on the Client Information tab, so its refusal belongs there too.
 */
export const CLIENT_FIELD_TABS: Readonly<Record<string, string>> = {
  [NAME_FIELD]: GENERAL_TAB,
  'Metadata.client_name': GENERAL_TAB,
  [DESCRIPTION_FIELD]: GENERAL_TAB,
  [ENABLED_FIELD]: GENERAL_TAB,
  [TYPE_FIELD]: GENERAL_TAB,
  [SSL_FIELD]: GENERAL_TAB,
  [SERVER_FIELD]: GENERAL_TAB,
  [REDIRECT_FIELD]: GENERAL_TAB,
  'Metadata.frontchannel_logout_uri': GENERAL_TAB,
  'Metadata.frontchannel_logout_session_required': GENERAL_TAB,
  'Metadata.grant_types': GENERAL_TAB,
  'Metadata.token_endpoint_auth_method': GENERAL_TAB,
  'Metadata.token_endpoint_auth_signing_alg': GENERAL_TAB,
  [AUDIENCE_FIELD]: GENERAL_TAB,
  'Metadata.logo_uri': INFORMATION_TAB,
  'Metadata.client_uri': INFORMATION_TAB,
  'Metadata.policy_uri': INFORMATION_TAB,
  'Metadata.tos_uri': INFORMATION_TAB,
  [SCOPE_FIELD]: INFORMATION_TAB,
  'Metadata.contacts': INFORMATION_TAB,
  'Metadata.default_max_age': INFORMATION_TAB,
  [METADATA_FIELD]: INFORMATION_TAB,
  [INTERVAL_FIELD]: JWT_TAB,
  [CREDENTIALS_FIELD]: JWT_TAB,
  [PASSWORD_FIELD]: JWT_TAB,
  'Metadata.id_token_signed_response_alg': JWT_TAB,
  'Metadata.id_token_encrypted_response_enc': JWT_TAB,
  'Metadata.id_token_encrypted_response_alg': JWT_TAB,
  'Metadata.userinfo_signed_response_alg': JWT_TAB,
  'Metadata.userinfo_encrypted_response_enc': JWT_TAB,
  'Metadata.userinfo_encrypted_response_alg': JWT_TAB,
  'Metadata.access_token_signed_response_alg': JWT_TAB,
  'Metadata.access_token_encrypted_response_enc': JWT_TAB,
  'Metadata.access_token_encrypted_response_alg': JWT_TAB,
  'Metadata.request_object_signing_alg': JWT_TAB,
  'Metadata.request_object_encryption_enc': JWT_TAB,
  'Metadata.request_object_encryption_alg': JWT_TAB,
  [CLIENT_ID_FIELD]: CREDENTIALS_TAB,
  [SECRET_FIELD]: CREDENTIALS_TAB,
  [REGISTRATION_TOKEN_FIELD]: CREDENTIALS_TAB,
  [INITIAL_TOKEN_FIELD]: CREDENTIALS_TAB,
  'Metadata.client_id_issued_at': CREDENTIALS_TAB,
  'Metadata.client_secret_expires_at': CREDENTIALS_TAB,
  'Metadata.registration_client_uri': CREDENTIALS_TAB,
};

/** Every field in form order, which is also the order a refused Save's tab is chosen by. */
export const CLIENT_FIELD_ORDER: readonly string[] = Object.keys(CLIENT_FIELD_TABS);

/** What the form is doing: creating a configuration, or editing the one its route names. */
export type FormMode = 'create' | 'edit';

/** How a metadata member is shaped on the wire. */
export type MemberKind = 'uri' | 'text' | 'list' | 'integer' | 'flag' | 'json';

export interface MetadataMember {
  readonly name: string;
  readonly kind: MemberKind;
  /** A fixed member's allowed values, or empty. */
  readonly values: readonly string[];
  /** Whether a caller may set it: a member the registration or the instance manages is read-only. */
  readonly settable: boolean;
}

/** A member's value in the form: text, a list, or a flag; a JSON member is carried as its text. */
export type MemberValue = string | readonly string[] | boolean;

export interface FieldRule {
  readonly field: string;
  readonly code: string;
  readonly reason: string;
}

/** One server description the caller can read, by its ID and issuer. */
export interface ServerDescription {
  readonly id: string;
  readonly issuer: string;
}

/** The field a violation on metadata member `name` is reported under. */
export function memberField(name: string): string {
  return `${METADATA_FIELD}.${name}`;
}

/** The top-level fields the form edits, as text except `Enabled`. */
interface Held {
  readonly name: string;
  readonly server: string;
  readonly enabled: boolean;
  readonly description: string;
  readonly clientType: string;
  readonly ssl: string;
  readonly redirect: string;
  readonly audience: string;
  readonly interval: string;
  readonly clientId: string;
  readonly credentials: string;
  readonly scope: string;
  readonly metadata: Readonly<Record<string, MemberValue>>;
}

type TextKey = Exclude<keyof Held, 'enabled' | 'metadata'>;

/** Each text field's wire name. */
const TEXT_FIELDS: Readonly<Record<TextKey, string>> = {
  name: NAME_FIELD,
  server: SERVER_FIELD,
  description: DESCRIPTION_FIELD,
  clientType: TYPE_FIELD,
  ssl: SSL_FIELD,
  redirect: REDIRECT_FIELD,
  audience: AUDIENCE_FIELD,
  interval: INTERVAL_FIELD,
  clientId: CLIENT_ID_FIELD,
  credentials: CREDENTIALS_FIELD,
  scope: SCOPE_FIELD,
};

const EMPTY_HELD: Held = {
  name: '',
  server: '',
  enabled: true,
  description: '',
  clientType: 'confidential',
  ssl: '',
  redirect: '',
  audience: '',
  interval: '',
  clientId: '',
  credentials: '',
  scope: '',
  metadata: {},
};

type Secrets = Readonly<Record<string, string>>;

const NO_SECRETS: Secrets = {};

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

/** A member's empty form: `[]` for a list, `''` otherwise. A flag's empty form clears it. */
function emptyOf(kind: MemberKind): MemberValue {
  return kind === 'list' ? [] : '';
}

/** A member's value read off the wire, in its kind's shape. */
function memberOf(kind: MemberKind, value: unknown): MemberValue {
  if (kind === 'list') return stringsOf(value);
  if (kind === 'flag') return typeof value === 'boolean' ? value : '';
  if (kind === 'integer') return typeof value === 'number' ? String(value) : typeof value === 'string' ? value : '';
  if (kind === 'json') return value === undefined || value === null ? '' : JSON.stringify(value);
  return typeof value === 'string' ? value : '';
}

/** A member's value as the wire takes it: an integer's digits as a number. */
function wireOf(kind: MemberKind, value: MemberValue): unknown {
  if (kind === 'integer' && typeof value === 'string' && /^[0-9]+$/.test(value)) return Number(value);
  return value;
}

function isEmpty(value: MemberValue): boolean {
  if (typeof value === 'boolean') return false;
  return value.length === 0;
}

function same(left: MemberValue, right: MemberValue): boolean {
  return JSON.stringify(left) === JSON.stringify(right);
}

/** The JWT interval as the wire takes it: digits as a number, anything else as typed. */
function intervalWire(text: string): unknown {
  return /^[0-9]+$/.test(text) ? Number(text) : text;
}

/**
 * The OAuth 2.0 client configuration editor's store (AD-19, AD-55): a create on
 * `security/oauth/clients/edit`, an edit of the configuration its route names on
 * `security/oauth/clients/edit/<name>`.
 *
 * **It composes no payload of its own.** `POST /oauth/client-configuration` and
 * `PUT /oauth/client-configuration/<id>` resolve the tool classes the agent's
 * `security.oauthclients.create`, `.update` and `.setsecrets` do; the server expands `Metadata` to
 * every settable member and sends the complete set (AD-4), and every field sentence is the server's
 * (AD-39).
 *
 * **An edit sends only what changed since its fresh read**: the top-level fields that changed and,
 * under `Metadata`, the settable members that changed, a cleared one in its empty form.
 *
 * **The four secrets are held in this store alone, until Save** (AD-35). None is ever pre-filled --
 * no read returns one -- and each is sent only when typed; an empty field keeps the stored value.
 */
@Injectable({ providedIn: 'root' })
export class OAuthClientForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private modeValue: FormMode = 'create';

  private buffer: Held = EMPTY_HELD;

  private opened: Held = EMPTY_HELD;

  private secretsValue: Secrets = NO_SECRETS;

  private membersValue: readonly MetadataMember[] = [];

  private serversValue: readonly ServerDescription[] = [];

  private sslNames: readonly string[] = [];

  private credentialNames: readonly string[] = [];

  private rulesValue: readonly FieldRule[] = [];

  private requiredValue: readonly string[] = [];

  private registrationEndpointValue = '';

  private loadedValue = false;

  private heldValue = false;

  private absentValue = false;

  private savingValue = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

  private savedValue = false;

  private secretsRefusedValue = '';

  private registrationNotUpdatedValue = '';

  private savedIdValue = '';

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

  /** Whether an edit names a configuration the instance does not hold, which blocks its Save. */
  absent(): boolean {
    return this.absentValue;
  }

  /** Whether an edit's fresh read is held, which is what the page's row actions act on. */
  held(): boolean {
    return this.heldValue;
  }

  /** A text field's value now. */
  text(key: TextKey): string {
    return this.buffer[key];
  }

  enabled(): boolean {
    return this.buffer.enabled;
  }

  /** The application name the fresh read answered: the configuration the row actions name. */
  storedName(): string {
    return this.opened.name;
  }

  /** A secret as typed, `''` until it is (AD-35). */
  secret(field: string): string {
    return this.secretsValue[field] ?? '';
  }

  /** A metadata member's value now, in its kind's shape. */
  member(name: string): MemberValue {
    const held = this.buffer.metadata[name];
    if (held !== undefined) return held;
    return emptyOf(this.kindOf(name));
  }

  /** A text-shaped member's value now, or `''`. */
  memberText(name: string): string {
    const value = this.member(name);
    return typeof value === 'string' ? value : '';
  }

  /** A list member's values now. */
  memberList(name: string): readonly string[] {
    const value = this.member(name);
    return Array.isArray(value) ? (value as readonly string[]) : [];
  }

  /** A flag member's value now: `true` only when it holds `true`. */
  memberFlag(name: string): boolean {
    return this.member(name) === true;
  }

  /** Every derived member the form read answers, in the server's order. */
  members(): readonly MetadataMember[] {
    return this.membersValue;
  }

  /** The allowed values of fixed member `name`, or empty. */
  valuesOf(name: string): readonly string[] {
    return this.membersValue.find((entry) => entry.name === name)?.values ?? [];
  }

  serverDescriptions(): readonly ServerDescription[] {
    return this.serversValue;
  }

  /** The issuer of the server description the configuration names now, or `''`. */
  issuer(): string {
    return this.serversValue.find((entry) => entry.id === this.buffer.server)?.issuer ?? '';
  }

  /** The issuer of the server description the fresh read names, or `''`. */
  storedIssuer(): string {
    return this.serversValue.find((entry) => entry.id === this.opened.server)?.issuer ?? '';
  }

  sslConfigurations(): readonly string[] {
    return this.sslNames;
  }

  /** The X.509 credentials with a private key the caller can use (AD-5). */
  credentialAliases(): readonly string[] {
    return this.credentialNames;
  }

  /** The stored client ID. */
  storedClientId(): string {
    return this.opened.clientId;
  }

  /** The stored X.509 credentials alias. */
  storedCredentials(): string {
    return this.opened.credentials;
  }

  /** The stored registration URI, which says the client is registered. */
  storedRegistrationUri(): string {
    const value = this.opened.metadata[REGISTRATION_URI_MEMBER];
    return typeof value === 'string' ? value : '';
  }

  /** The registration endpoint the stored server description publishes, or `''`. */
  registrationEndpoint(): string {
    return this.registrationEndpointValue;
  }

  /** Whether the fields take input: in edit mode only once the fresh read is held. */
  editable(): boolean {
    return (this.modeValue === 'create' || this.heldValue) && !this.busy();
  }

  canSave(): boolean {
    if (this.busy() || this.absentValue) return false;
    return this.modeValue === 'create' || this.heldValue;
  }

  /** Whether `field` is required now: the redirect URL only for a client that is not a resource server. */
  required(field: string): boolean {
    if (field === REDIRECT_FIELD && this.buffer.clientType === RESOURCE_TYPE) return false;
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

  /** The sentence a secrets or initial token write was refused with after the save, or `''`. */
  secretsRefused(): string {
    return this.secretsRefusedValue;
  }

  /** The sentence the instance gives when a registered client saved and its registration did not update. */
  registrationNotUpdated(): string {
    return this.registrationNotUpdatedValue;
  }

  /** The name the last accepted Save answered, or `''`. */
  savedId(): string {
    return this.savedIdValue;
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
    this.buffer = EMPTY_HELD;
    this.opened = EMPTY_HELD;
    this.secretsValue = NO_SECRETS;
    this.membersValue = [];
    this.serversValue = [];
    this.sslNames = [];
    this.credentialNames = [];
    this.rulesValue = [];
    this.requiredValue = [];
    this.registrationEndpointValue = '';
    this.loadedValue = false;
    this.heldValue = false;
    this.absentValue = false;
    this.savingValue = false;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.secretsRefusedValue = '';
    this.registrationNotUpdatedValue = '';
    this.savedIdValue = '';
    this.retainingValue = false;
    this.formDirty.reset();
    this.notify();
  }

  /**
   * Open the form: a create when `name` is empty, an edit of that configuration otherwise. An
   * arrival that is a Save's own route replacement keeps the saved confirmation on screen.
   */
  async open(name: string): Promise<void> {
    const arriving = this.retainingValue && name !== '' && name === this.savedIdValue;
    const refused = arriving ? this.secretsRefusedValue : '';
    const notUpdated = arriving ? this.registrationNotUpdatedValue : '';
    this.reset();
    if (arriving) {
      this.savedValue = true;
      this.secretsRefusedValue = refused;
      this.registrationNotUpdatedValue = notUpdated;
    }
    this.modeValue = name === '' ? 'create' : 'edit';
    const generation = this.generation;
    const path = name === '' ? OAUTH_CLIENT_FORM_PATH : `${OAUTH_CLIENT_FORM_PATH}?applicationName=${encodeURIComponent(name)}`;
    const result = await this.api().requestJson<unknown>(path);
    if (generation !== this.generation) return;
    this.absorb(result, name);
    this.loadedValue = true;
    this.notify();
  }

  /** Set a text field. The name is fixed once created. */
  setText(key: TextKey, value: string): void {
    if (!this.editable() || this.buffer[key] === value) return;
    if (key === 'name' && this.modeValue === 'edit') return;
    this.buffer = { ...this.buffer, [key]: value };
    this.change(TEXT_FIELDS[key]);
  }

  setEnabled(value: boolean): void {
    if (!this.editable() || this.buffer.enabled === value) return;
    this.buffer = { ...this.buffer, enabled: value };
    this.change(ENABLED_FIELD);
  }

  setSecret(field: string, value: string): void {
    if (!this.editable() || !SECRET_FIELDS.includes(field) || this.secret(field) === value) return;
    this.secretsValue = { ...this.secretsValue, [field]: value };
    this.change(field);
  }

  /** Set a settable text, URI, integer or fixed member. */
  setMemberText(name: string, value: string): void {
    const kind = this.kindOf(name);
    if (!this.editable() || !this.settable(name) || kind === 'list' || kind === 'flag' || kind === 'json') return;
    if (this.memberText(name) === value) return;
    this.setMember(name, value);
  }

  /** Set a settable list member from comma-separated text; blanks are dropped. */
  setMemberCsv(name: string, text: string): void {
    if (!this.editable() || !this.settable(name) || this.kindOf(name) !== 'list') return;
    const values = text
      .split(',')
      .map((entry) => entry.trim())
      .filter((entry) => entry !== '');
    if (same(values, this.member(name))) return;
    this.setMember(name, values);
  }

  /** Set a settable flag member; unchecked clears it. */
  setMemberFlag(name: string, value: boolean): void {
    if (!this.editable() || !this.settable(name) || this.kindOf(name) !== 'flag') return;
    const next: MemberValue = value ? true : '';
    if (same(next, this.member(name))) return;
    this.setMember(name, next);
  }

  /** Add or remove one grant type, keeping every other value the member holds. */
  setGrant(grant: string, on: boolean): void {
    if (!this.editable() || !this.settable(GRANT_MEMBER)) return;
    const current = this.memberList(GRANT_MEMBER);
    const has = current.includes(grant);
    if (has === on) return;
    this.setMember(GRANT_MEMBER, on ? [...current, grant] : current.filter((entry) => entry !== grant));
  }

  /**
   * On blur: render the server's required-field sentence on an empty required field of a create, as
   * the form read's first rule for it words it.
   */
  onBlur(field: string): void {
    if (this.modeValue !== 'create' || !this.required(field)) return;
    if (this.fieldText(field).trim() !== '') return;
    const rule = this.rulesValue.find((entry) => entry.field === field);
    if (rule === undefined || this.violationList.some((entry) => entry.field === field)) return;
    this.violationList = [...this.violationList, { field, code: rule.code, reason: rule.reason }];
    this.notify();
  }

  /**
   * Save: a create posts every field and the members that hold a value; an edit puts what changed
   * since its fresh read. Typed secrets travel beside them and are stored after the configuration
   * is (AD-56); the store forgets them either way. An accepted Save publishes one change event, and
   * a second for the server description when an initial access token was stored (AD-14).
   */
  async save(): Promise<boolean> {
    if (!this.canSave()) return false;
    const generation = this.generation;
    const creating = this.modeValue === 'create';
    const body = creating ? this.createBody() : this.changedBody();
    const typed = Object.entries(this.secretsValue).filter(([, value]) => value !== '');
    if (!creating && Object.keys(body).length === 0 && typed.length === 0) {
      this.clearRefusal();
      this.savedValue = true;
      this.formDirty.setDirty(false);
      this.notify();
      return true;
    }
    for (const [field, value] of typed) body[field] = value;
    const tokenTyped = this.secret(INITIAL_TOKEN_FIELD) !== '';
    const issuer = this.issuer();
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.secretsRefusedValue = '';
    this.registrationNotUpdatedValue = '';
    this.notify();
    const result = creating
      ? await this.api().requestJson<unknown>(OAUTH_CLIENT_PATH, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        })
      : await this.api().requestJson<unknown>(`${OAUTH_CLIENT_PATH}/${encodeEntityId(this.opened.name)}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(body),
        });
    for (const field of SECRET_FIELDS) delete body[field];
    if (generation !== this.generation) return false;
    this.savingValue = false;
    this.secretsValue = NO_SECRETS;
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.envelopeReason = this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      this.notify();
      return false;
    }
    const id = textAt(result.body, 'applicationName') || this.buffer.name;
    this.savedIdValue = id;
    const secretsRefused = textAt(result.body, 'secretsRefused');
    const tokenRefused = textAt(result.body, 'tokenRefused');
    this.secretsRefusedValue = secretsRefused || tokenRefused;
    this.registrationNotUpdatedValue = textAt(result.body, 'registrationNotUpdated');
    this.opened = this.buffer;
    this.savedValue = true;
    this.formDirty.setDirty(false);
    this.publish(OAUTH_CLIENT_ENTITY, id, creating ? 'created' : 'updated');
    if (tokenTyped && tokenRefused === '' && issuer !== '') this.publish(OAUTH_SERVER_DEFINITION_ENTITY, issuer, 'updated');
    this.notify();
    return true;
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  private kindOf(name: string): MemberKind {
    return this.membersValue.find((entry) => entry.name === name)?.kind ?? 'text';
  }

  private settable(name: string): boolean {
    return this.membersValue.find((entry) => entry.name === name)?.settable === true;
  }

  private setMember(name: string, value: MemberValue): void {
    this.buffer = { ...this.buffer, metadata: { ...this.buffer.metadata, [name]: value } };
    this.change(memberField(name));
  }

  private fieldText(field: string): string {
    const key = (Object.keys(TEXT_FIELDS) as TextKey[]).find((entry) => TEXT_FIELDS[entry] === field);
    if (key !== undefined) return this.buffer[key];
    if (field.startsWith(`${METADATA_FIELD}.`)) return this.memberText(field.slice(METADATA_FIELD.length + 1));
    return '';
  }

  private change(field: string): void {
    if (this.violationList.some((entry) => entry.field === field)) {
      this.violationList = this.violationList.filter((entry) => entry.field !== field);
    }
    this.savedValue = false;
    this.secretsRefusedValue = '';
    this.registrationNotUpdatedValue = '';
    this.formDirty.setDirty(true);
    this.notify();
  }

  /** A create's body: every field and every settable member that holds a value (AD-54). */
  private createBody(): Record<string, unknown> {
    const metadata: Record<string, unknown> = {};
    for (const entry of this.membersValue) {
      if (!entry.settable) continue;
      const value = this.member(entry.name);
      if (!isEmpty(value)) metadata[entry.name] = wireOf(entry.kind, value);
    }
    const body: Record<string, unknown> = {
      [NAME_FIELD]: this.buffer.name,
      [SERVER_FIELD]: this.buffer.server,
      [ENABLED_FIELD]: this.buffer.enabled,
      [DESCRIPTION_FIELD]: this.buffer.description,
      [TYPE_FIELD]: this.buffer.clientType,
      [SSL_FIELD]: this.buffer.ssl,
      [REDIRECT_FIELD]: this.buffer.redirect,
      [AUDIENCE_FIELD]: this.buffer.audience,
      [CLIENT_ID_FIELD]: this.buffer.clientId,
      [CREDENTIALS_FIELD]: this.buffer.credentials,
      [SCOPE_FIELD]: this.buffer.scope,
      [METADATA_FIELD]: metadata,
    };
    if (this.buffer.interval !== '') body[INTERVAL_FIELD] = intervalWire(this.buffer.interval);
    return body;
  }

  /** An edit's body: the fields and the settable members changed since the fresh read. */
  private changedBody(): Record<string, unknown> {
    const out: Record<string, unknown> = {};
    for (const key of Object.keys(TEXT_FIELDS) as TextKey[]) {
      if (key === 'name' || this.buffer[key] === this.opened[key]) continue;
      out[TEXT_FIELDS[key]] = key === 'interval' ? intervalWire(this.buffer.interval) : this.buffer[key];
    }
    if (this.buffer.enabled !== this.opened.enabled) out[ENABLED_FIELD] = this.buffer.enabled;
    const metadata: Record<string, unknown> = {};
    for (const entry of this.membersValue) {
      if (!entry.settable) continue;
      const now = this.member(entry.name);
      const before = this.opened.metadata[entry.name] ?? emptyOf(entry.kind);
      if (!same(now, before)) metadata[entry.name] = wireOf(entry.kind, now);
    }
    if (Object.keys(metadata).length > 0) out[METADATA_FIELD] = metadata;
    return out;
  }

  private absorb(result: JsonResult<unknown>, name: string): void {
    if (result.kind !== 'ok') {
      this.envelopeReason = result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      if (name !== '' && result.kind === 'error' && result.status === 404) this.absentValue = true;
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
    const kinds: readonly string[] = ['uri', 'text', 'list', 'integer', 'flag', 'json'];
    const members: MetadataMember[] = [];
    for (const entry of Array.isArray(body?.['members']) ? (body['members'] as unknown[]) : []) {
      const memberName = textAt(entry, 'name');
      const kind = textAt(entry, 'kind');
      if (memberName === '' || !kinds.includes(kind)) continue;
      members.push({
        name: memberName,
        kind: kind as MemberKind,
        values: stringsOf(record(entry)?.['values']),
        settable: record(entry)?.['settable'] === true,
      });
    }
    this.membersValue = members;
    const servers: ServerDescription[] = [];
    for (const entry of Array.isArray(body?.['serverDescriptions']) ? (body['serverDescriptions'] as unknown[]) : []) {
      const id = textAt(entry, 'id');
      if (id !== '') servers.push({ id, issuer: textAt(entry, 'issuer') });
    }
    this.serversValue = servers;
    this.sslNames = stringsOf(body?.['sslConfigurations']);
    this.credentialNames = stringsOf(body?.['credentials']);
    if (name === '') return;
    const definition = record(body?.['definition']);
    if (definition === null) {
      this.absentValue = true;
      return;
    }
    const stored = record(definition[METADATA_FIELD]);
    const metadata: Record<string, MemberValue> = {};
    for (const entry of members) metadata[entry.name] = memberOf(entry.kind, stored?.[entry.name]);
    const enabled = definition[ENABLED_FIELD];
    this.buffer = {
      name: textAt(definition, NAME_FIELD) || name,
      server: textAt(definition, SERVER_FIELD),
      enabled: typeof enabled === 'boolean' ? enabled : true,
      description: textAt(definition, DESCRIPTION_FIELD),
      clientType: textAt(definition, TYPE_FIELD),
      ssl: textAt(definition, SSL_FIELD),
      redirect: textAt(definition, REDIRECT_FIELD),
      audience: textAt(definition, AUDIENCE_FIELD),
      interval: textAt(definition, INTERVAL_FIELD),
      clientId: textAt(definition, CLIENT_ID_FIELD),
      credentials: textAt(definition, CREDENTIALS_FIELD),
      scope: textAt(definition, SCOPE_FIELD),
      metadata,
    };
    this.opened = this.buffer;
    this.registrationEndpointValue = textAt(definition, 'RegistrationEndpoint');
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

  private publish(type: string, id: string, action: ChangeAction): void {
    if (id === '') return;
    this.injector.get(ChangeBus).publish({ kind: 'changed', type, scope: OAUTH_CLIENT_SCOPE, id, action });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
