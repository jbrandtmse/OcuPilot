import { Injectable, Injector, inject } from '@angular/core';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { screenForRoute } from '../../core/navigation';
import { readBackOf, type ReadBack } from '../../core/read-back';
import { createScreenRead } from '../../core/screen-read';
import { ENTITY_SINGLETON_ID } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { reasonForField, type Violation, violationsOf } from '../../core/violations';

/** The screen this store serves (Story 18.8). */
export const AUTH_OPTIONS_ROUTE = 'security/authentication';

/** The Save's route and the form read's (AD-20, AD-55). */
export const AUTH_OPTIONS_PATH = '/api/ocupilot/authentication-options';
export const AUTH_OPTIONS_FORM_PATH = '/api/ocupilot/authentication-options/form';

/** The change event's triple (AD-13, AD-14): the instance's one set of authentication options. */
export const AUTH_OPTIONS_ENTITY = 'authentication-options';
export const AUTH_OPTIONS_SCOPE = 'instance';

/** The declared read answers one object, so one row is the whole answer. */
export const AUTH_OPTIONS_MAX_ROWS = 1;

/** The fourteen method flags, in the classic page's order. */
export const FLAG_FIELDS: readonly string[] = [
  'AutheUnauthenticated',
  'AutheOS',
  'AutheOSDelegated',
  'AutheOSLDAP',
  'AutheCache',
  'AutheDelegated',
  'AutheAlwaysTryDelegated',
  'AutheKB',
  'AutheLDAP',
  'AutheLDAPCache',
  'AutheOAuth2',
  'AutheLoginToken',
  'AutheTwoFactorPW',
  'AutheTwoFactorSMS',
];

/** The two timeouts, each a whole number of seconds typed as text. */
export const TIMEOUT_FIELDS: readonly string[] = ['LoginCookieTimeout', 'TwoFactorTimeout'];

/** The text settings. */
export const TEXT_FIELDS: readonly string[] = ['SMTPServer', 'TwoFactorFrom', 'SMTPUsername', 'JWTIssuer'];

/** The signature algorithm, one of the form read's options. */
export const SIG_ALG_FIELD = 'JWTSigAlg';

/** The settings whose change ends every token session. */
export const TOKEN_FIELDS: readonly string[] = ['JWTIssuer', SIG_ALG_FIELD];

/** The flag whose turning off is refused on every instance (AD-10's start arm). */
export const OS_FIELD = 'AutheOS';

/** The password's own body key: write-only, and never a field of the read. */
export const PASSWORD_FIELD = 'SMTPPassword';

/** The consequence a Save's answer carries when it changed a token setting. */
export const SIGN_OUT_CONSEQUENCE = 'WEBAUTH.SIGNOUT';

function textOf(value: unknown): string {
  if (typeof value === 'string') return value;
  if (typeof value === 'number') return String(value);
  return '';
}

/** A whole number, spaces around it dropped, as a JSON number; anything else as the text typed, so the server's rule answers it. */
function numberValue(text: string): number | string {
  const trimmed = text.trim();
  return /^[0-9]{1,9}$/.test(trimmed) ? Number(trimmed) : text;
}

/**
 * The authentication options' store (Story 18.8, AD-19, AD-55): the instance's twenty-one settings,
 * read through the screen's own declared read, so the form and `security.authoptions.read` answer one
 * read (AD-36), and the form read's sign-in locks and signature algorithms.
 *
 * **It composes no payload of its own.** `PUT /authentication-options` carries the changed settings
 * only; the server merges them over its own fresh read and sends the complete set less an unchanged
 * Kerberos flag (AD-4), through the tool the agent's `security.authoptions.update` resolves. Every
 * sentence is the server's (AD-39), except the two the screen draws before a click: the O/S
 * authentication start refusal and the sign-out consequence, which EXPERIENCE.md publishes.
 *
 * **A flag the server locks, and O/S authentication while it is on, cannot be turned off** and is
 * drawn `aria-disabled` with its sentence. Always try Delegated needs Delegated on and LDAP cache
 * needs LDAP or O/S with LDAP authorization on; a field whose dependency is off is sent false.
 *
 * **The SMTP password is never held here** (AD-35): the page keeps what is typed and hands it to
 * `save` once; the store only learns whether one is pending, for the unsaved-changes guard.
 */
@Injectable({ providedIn: 'root' })
export class AuthOptionsForm {
  private readonly injector = inject(Injector);

  private readonly formDirty = inject(FormDirty);

  private readonly listeners = new Set<() => void>();

  private generation = 0;

  private flags: Readonly<Record<string, boolean>> = {};

  private openedFlags: Readonly<Record<string, boolean>> = {};

  private texts: Readonly<Record<string, string>> = {};

  private openedTexts: Readonly<Record<string, string>> = {};

  private locks: Readonly<Record<string, string>> = {};

  private algorithms: readonly string[] = [];

  private loadedValue = false;

  private heldValue = false;

  private faultValue = false;

  private savingValue = false;

  private passwordPending = false;

  private violationList: readonly Violation[] = [];

  private envelopeReason = '';

  private refusalCodeValue = '';

  private refusalPairValue = '';

  private savedValue = false;

  private signOutValue = false;

  private secretsRefusedValue = '';

  private readBackValue: ReadBack | null = null;

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  // --- reads -----------------------------------------------------------------------------------

  loaded(): boolean {
    return this.loadedValue;
  }

  /** Whether the fields take input: only once the read is held. */
  editable(): boolean {
    return this.heldValue;
  }

  /** Whether the read was refused or failed, which offers Retry. */
  fault(): boolean {
    return this.faultValue;
  }

  busy(): boolean {
    return this.savingValue;
  }

  canSave(): boolean {
    return this.heldValue && !this.savingValue;
  }

  flag(field: string): boolean {
    return this.flags[field] === true;
  }

  text(field: string): string {
    return this.texts[field] ?? '';
  }

  /** The signature algorithms the instance offers, as the form read answers them. */
  sigAlgs(): readonly string[] {
    return this.algorithms;
  }

  /**
   * Why `field`, a flag now on, cannot be turned off, or `''`: the server's sign-in sentence for a lock it
   * answered, and the published start sentence for O/S authentication.
   */
  refusal(field: string): string {
    if (!this.flag(field)) return '';
    const lock = this.locks[field];
    if (lock !== undefined) return lock;
    return field === OS_FIELD ? STRINGS.authOptionsRefusalStart : '';
  }

  /** Whether Always try Delegated can be chosen: Delegated authentication is on. */
  alwaysTryEnabled(): boolean {
    return this.flag('AutheDelegated');
  }

  /** Whether LDAP cache can be chosen: LDAP, or O/S authentication with LDAP authorization, is on. */
  ldapCacheEnabled(): boolean {
    return this.flag('AutheLDAP') || this.flag('AutheOSLDAP');
  }

  /** Whether the two-factor SMS settings are drawn. */
  smsShown(): boolean {
    return this.flag('AutheTwoFactorSMS');
  }

  /** The sign-out sentence while a token setting is changed and unsaved, or `''`. */
  tokenEffect(): string {
    return TOKEN_FIELDS.some((field) => this.text(field) !== (this.openedTexts[field] ?? '')) ? STRINGS.authOptionsSignOutConsequence : '';
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

  /** Whether the last accepted Save changed a token setting, which ended every token session. */
  signedOut(): boolean {
    return this.signOutValue;
  }

  /** The sentence the last Save's password write was refused with, or `''`. */
  secretsRefused(): string {
    return this.secretsRefusedValue;
  }

  readBack(): ReadBack | null {
    return this.readBackValue;
  }

  // --- writes ----------------------------------------------------------------------------------

  /** Forget everything: from the sign-out teardown and when the page is left. */
  reset(): void {
    this.generation += 1;
    this.flags = {};
    this.openedFlags = {};
    this.texts = {};
    this.openedTexts = {};
    this.locks = {};
    this.algorithms = [];
    this.loadedValue = false;
    this.heldValue = false;
    this.faultValue = false;
    this.savingValue = false;
    this.passwordPending = false;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.signOutValue = false;
    this.secretsRefusedValue = '';
    this.readBackValue = null;
    this.formDirty.reset();
    this.notify();
  }

  /**
   * Open the form over the screen's declared read and the form read. `keepSaved` carries the last accepted
   * Save's confirmation, and its sign-out line, across the re-read that follows it.
   */
  async open(keepSaved = false): Promise<void> {
    const saved = keepSaved && this.savedValue;
    const signedOut = keepSaved && this.signOutValue;
    const refused = keepSaved ? this.secretsRefusedValue : '';
    const readBack = this.readBackValue;
    this.reset();
    if (saved) {
      this.savedValue = true;
      this.signOutValue = signedOut;
      this.secretsRefusedValue = refused;
      this.readBackValue = readBack;
    }
    const screen = screenForRoute(AUTH_OPTIONS_ROUTE);
    if (screen === null || screen.read === null) return;
    const generation = this.generation;
    const [result, form] = await Promise.all([
      createScreenRead(this.api(), screen)({ maxRows: AUTH_OPTIONS_MAX_ROWS }),
      this.api().requestJson<unknown>(AUTH_OPTIONS_FORM_PATH),
    ]);
    if (generation !== this.generation) return;
    this.loadedValue = true;
    const row = result.kind === 'ok' ? result.rows[0] : undefined;
    if (row === null || row === undefined || typeof row !== 'object' || Array.isArray(row) || form.kind !== 'ok') {
      this.faultValue = true;
      this.rememberRefusal(form);
      this.notify();
      return;
    }
    this.absorbForm(form.body);
    this.absorb(row as Record<string, unknown>);
    this.notify();
  }

  /**
   * Set flag `field` to `value`. A turn-off the server or the start arm refuses is never made, and the
   * two dependent flags follow the ones they need: Delegated off clears Always try Delegated, and LDAP and
   * O/S with LDAP both off clear LDAP cache.
   */
  setFlag(field: string, value: boolean): void {
    if (!this.heldValue || !FLAG_FIELDS.includes(field) || this.flag(field) === value) return;
    if (!value && this.refusal(field) !== '') return;
    if (value && field === 'AutheAlwaysTryDelegated' && !this.alwaysTryEnabled()) return;
    if (value && field === 'AutheLDAPCache' && !this.ldapCacheEnabled()) return;
    const next: Record<string, boolean> = { ...this.flags, [field]: value };
    if (!next['AutheDelegated']) next['AutheAlwaysTryDelegated'] = false;
    if (!next['AutheLDAP'] && !next['AutheOSLDAP']) next['AutheLDAPCache'] = false;
    this.flags = next;
    this.change(field);
  }

  setText(field: string, value: string): void {
    if (!this.heldValue || !(TIMEOUT_FIELDS.includes(field) || TEXT_FIELDS.includes(field) || field === SIG_ALG_FIELD)) return;
    if (this.text(field) === value) return;
    this.texts = { ...this.texts, [field]: value };
    this.change(field);
  }

  /** Whether the page holds a typed password or a clear request the form must not be left over. */
  setPasswordPending(pending: boolean): void {
    if (this.passwordPending === pending) return;
    this.passwordPending = pending;
    this.savedValue = this.savedValue && !pending;
    this.formDirty.setDirty(this.dirty());
    this.notify();
  }

  /**
   * Save: put the changed settings, and the SMTP password when `password` is given (`''` clears it, `null`
   * leaves it). An accepted Save publishes one `authentication-options` `updated` change event (AD-14) and
   * re-reads the form; a refused one keeps what was entered. The password is never kept.
   */
  async save(password: string | null = null): Promise<boolean> {
    if (!this.canSave()) return false;
    const generation = this.generation;
    const body: Record<string, unknown> = this.saveBody();
    if (password !== null) body[PASSWORD_FIELD] = password;
    if (Object.keys(body).length === 0) {
      this.clearRefusal();
      this.readBackValue = null;
      this.signOutValue = false;
      this.secretsRefusedValue = '';
      this.savedValue = true;
      this.formDirty.setDirty(false);
      this.notify();
      return true;
    }
    this.savingValue = true;
    this.violationList = [];
    this.clearRefusal();
    this.savedValue = false;
    this.signOutValue = false;
    this.secretsRefusedValue = '';
    this.readBackValue = null;
    this.notify();
    const result = await this.api().requestJson<unknown>(AUTH_OPTIONS_PATH, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    body[PASSWORD_FIELD] = '';
    if (generation !== this.generation) return false;
    this.savingValue = false;
    if (result.kind !== 'ok') {
      this.violationList = violationsOf(result);
      this.envelopeReason = this.violationList.length === 0 && result.kind === 'error' ? (result.reason ?? '') : '';
      this.rememberRefusal(result);
      this.notify();
      return false;
    }
    const answer = result.body !== null && typeof result.body === 'object' ? (result.body as Record<string, unknown>) : {};
    this.readBackValue = readBackOf(answer['readBack']);
    this.signOutValue = answer['consequence'] === SIGN_OUT_CONSEQUENCE;
    this.secretsRefusedValue = typeof answer['secretsRefused'] === 'string' ? answer['secretsRefused'] : '';
    this.savedValue = true;
    this.passwordPending = false;
    this.formDirty.setDirty(false);
    this.publish();
    this.notify();
    await this.open(true);
    return true;
  }

  // --- internals ------------------------------------------------------------------------------

  private api(): ApiService {
    return this.injector.get(ApiService);
  }

  /** The body of a Save: the changed settings only, a number as a JSON number. */
  saveBody(): Record<string, unknown> {
    const body: Record<string, unknown> = {};
    for (const field of FLAG_FIELDS) {
      if (this.flag(field) !== (this.openedFlags[field] === true)) body[field] = this.flag(field);
    }
    for (const field of TIMEOUT_FIELDS) {
      if (this.text(field) !== (this.openedTexts[field] ?? '')) body[field] = numberValue(this.text(field));
    }
    for (const field of [...TEXT_FIELDS, SIG_ALG_FIELD]) {
      if (this.text(field) !== (this.openedTexts[field] ?? '')) body[field] = this.text(field);
    }
    return body;
  }

  private dirty(): boolean {
    return this.passwordPending || Object.keys(this.saveBody()).length > 0;
  }

  private absorbForm(body: unknown): void {
    const form = body !== null && typeof body === 'object' ? (body as Record<string, unknown>) : {};
    const locks: Record<string, string> = {};
    const rows = form['locked'];
    if (Array.isArray(rows)) {
      for (const entry of rows) {
        if (entry === null || typeof entry !== 'object') continue;
        const row = entry as Record<string, unknown>;
        if (typeof row['field'] === 'string' && row['field'] !== '') locks[row['field']] = typeof row['reason'] === 'string' ? row['reason'] : '';
      }
    }
    this.locks = locks;
    const algorithms = form['sigAlgs'];
    this.algorithms = Array.isArray(algorithms) ? algorithms.filter((entry): entry is string => typeof entry === 'string') : [];
  }

  private absorb(row: Record<string, unknown>): void {
    const flags: Record<string, boolean> = {};
    for (const field of FLAG_FIELDS) flags[field] = row[field] === true;
    this.flags = flags;
    this.openedFlags = flags;
    const texts: Record<string, string> = {};
    for (const field of [...TIMEOUT_FIELDS, ...TEXT_FIELDS, SIG_ALG_FIELD]) texts[field] = textOf(row[field]);
    this.texts = texts;
    this.openedTexts = texts;
    this.heldValue = true;
  }

  private change(field: string): void {
    this.clearFieldViolation(field);
    this.savedValue = false;
    this.signOutValue = false;
    this.formDirty.setDirty(this.dirty());
    this.notify();
  }

  private clearFieldViolation(field: string): void {
    if (this.violationList.every((entry) => entry.field !== field)) return;
    this.violationList = this.violationList.filter((entry) => entry.field !== field);
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

  private publish(): void {
    this.injector.get(ChangeBus).publish({
      kind: 'changed',
      type: AUTH_OPTIONS_ENTITY,
      scope: AUTH_OPTIONS_SCOPE,
      id: ENTITY_SINGLETON_ID,
      action: 'updated',
      readBack: this.readBackValue,
    });
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
