import { ChangeDetectionStrategy, Component, DestroyRef, ElementRef, Injector, afterNextRender, inject, signal, viewChild } from '@angular/core';

import { FormDirty } from '../../core/form-dirty';
import { formatDeniedAction } from '../../core/navigation';
import { savedLine } from '../../core/read-back';
import { STRINGS } from '../../core/strings';
import type { Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { AuthOptionsForm, PASSWORD_FIELD, SIG_ALG_FIELD } from './auth-options.store';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** Each field's control id. */
export function authOptionsControlId(field: string): string {
  return `ocu-auth-options-${field}`;
}

/** One method flag or checkbox, resolved for drawing. */
interface FlagView {
  readonly field: string;
  readonly label: string;
  readonly id: string;
  readonly checked: boolean;
  /** Turning it off is refused: drawn `aria-disabled`, focusable, never turned off. */
  readonly refused: boolean;
  /** Its dependency is off: drawn disabled. */
  readonly unavailable: boolean;
  readonly ariaDisabled: 'true' | null;
  readonly reasonId: string;
  readonly reason: string;
  readonly describedBy: string | null;
  readonly invalid: boolean;
  readonly violation: string;
}

/** One text or number input, resolved for drawing. */
interface InputView {
  readonly field: string;
  readonly label: string;
  readonly id: string;
  readonly value: string;
  readonly numeric: boolean;
  readonly invalid: boolean;
  readonly violation: string;
  readonly describedBy: string | null;
}

/** The methods group's flags and each one's label. */
const METHOD_FLAGS: readonly (readonly [string, string])[] = [
  ['AutheUnauthenticated', STRINGS.authOptionsUnauthenticated],
  ['AutheOS', STRINGS.authOptionsOs],
  ['AutheOSDelegated', STRINGS.authOptionsOsDelegated],
  ['AutheOSLDAP', STRINGS.authOptionsOsLdap],
  ['AutheCache', STRINGS.authOptionsPassword],
  ['AutheDelegated', STRINGS.authOptionsDelegated],
  ['AutheAlwaysTryDelegated', STRINGS.authOptionsAlwaysTryDelegated],
  ['AutheKB', STRINGS.authOptionsKerberos],
  ['AutheLDAP', STRINGS.authOptionsLdap],
  ['AutheLDAPCache', STRINGS.authOptionsLdapCache],
  ['AutheOAuth2', STRINGS.authOptionsOAuth2],
];

/**
 * Authentication options (Story 18.8, SA-AUTH, AD-55): Security and secrets' eleventh listed entry, the
 * `form-page` on `security/authentication`, over the screen's own declared read and
 * `GET /authentication-options/form`.
 *
 * **Four groups, in the classic order.** Authentication methods holds eleven flags; Login cookies the
 * cookie flag and its expire time; Two-factor authentication the two flags and, while SMS is on, the
 * timeout, the SMTP server, the from address, the SMTP user and a masked, write-only SMTP password with a
 * clear option; JSON Web Token (JWT) settings the issuer and the signature algorithm.
 *
 * **A flag that cannot be turned off stays focusable and is `aria-disabled`**, naming the sentence through
 * `aria-describedby`: Unauthenticated and Password while OcuPilot's own sign-in rests on them (the server's
 * sentence, from the form read) and O/S authentication while it is on (EXPERIENCE.md's start sentence).
 * Always try Delegated and LDAP cache are disabled until the flag they need is on. A changed issuer or
 * algorithm shows the sign-out sentence before Save. The password is this page's alone, handed over once
 * and cleared whatever the answer (AD-35).
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-auth-options-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<section class="ocu-form-page" [attr.aria-busy]="busyFlag">
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
      <p class="ocu-banner ocu-banner-warning" role="alert" data-auth-options="reason">{{ reason }}</p>
    }
    @if (faultFlag) {
      <div class="ocu-data-table-refusal" role="alert">
        <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
        <button type="button" class="ocu-button-text" (click)="onRetry()">{{ STRINGS.actionRetry }}</button>
      </div>
    }

    @if (heldFlag) {
    <fieldset class="ocu-form-fields ocu-field" data-group="methods">
      <legend class="ocu-field-label">{{ STRINGS.serviceColumnAuthentication }}</legend>
      @for (view of methodViews; track view.field) {
        <label class="ocu-field-checkbox" [attr.data-flag]="view.field">
          <input
            type="checkbox"
            [id]="view.id"
            [checked]="view.checked"
            [disabled]="view.unavailable"
            [attr.aria-disabled]="view.ariaDisabled"
            [attr.aria-invalid]="view.invalid"
            [attr.aria-describedby]="view.describedBy"
            (click)="onFlagClick($event, view)"
          />
          <span>{{ view.label }}</span>
        </label>
        @if (view.refused) {
          <p class="ocu-field-caption" [id]="view.reasonId" data-slot="flag-reason">{{ view.reason }}</p>
        }
        @if (view.invalid) {
          <p class="ocu-form-error" [id]="view.id + '-violation'">{{ view.violation }}</p>
        }
      }
    </fieldset>

    <fieldset class="ocu-form-fields ocu-field" data-group="cookies">
      <legend class="ocu-field-label">{{ STRINGS.authOptionsLoginCookiesLegend }}</legend>
      <label class="ocu-field-checkbox" data-flag="AutheLoginToken">
        <input type="checkbox" [id]="loginTokenView.id" [checked]="loginTokenView.checked" (click)="onFlagClick($event, loginTokenView)" />
        <span>{{ loginTokenView.label }}</span>
      </label>
      <div class="ocu-field" [attr.data-field]="cookieView.field">
        <label class="ocu-field-label" [attr.for]="cookieView.id">{{ cookieView.label }}</label>
        <input
          class="ocu-field-input"
          type="text"
          inputmode="numeric"
          autocomplete="off"
          [id]="cookieView.id"
          [value]="cookieView.value"
          [attr.aria-invalid]="cookieView.invalid"
          [attr.aria-describedby]="cookieView.describedBy"
          (input)="onText(cookieView.field, $event)"
        />
        @if (cookieView.invalid) {
          <p class="ocu-form-error" [id]="cookieView.id + '-reason'">{{ cookieView.violation }}</p>
        }
      </div>
    </fieldset>

    <fieldset class="ocu-form-fields ocu-field" data-group="two-factor">
      <legend class="ocu-field-label">{{ STRINGS.userFieldTwoFactor }}</legend>
      @for (view of twoFactorViews; track view.field) {
        <label class="ocu-field-checkbox" [attr.data-flag]="view.field">
          <input type="checkbox" [id]="view.id" [checked]="view.checked" [attr.aria-invalid]="view.invalid" (click)="onFlagClick($event, view)" />
          <span>{{ view.label }}</span>
        </label>
      }
      @if (smsShown) {
        @for (view of smsViews; track view.field) {
          <div class="ocu-field" [attr.data-field]="view.field">
            <label class="ocu-field-label" [attr.for]="view.id">{{ view.label }}</label>
            <input
              class="ocu-field-input"
              type="text"
              autocomplete="off"
              spellcheck="false"
              [attr.inputmode]="view.numeric ? 'numeric' : null"
              [id]="view.id"
              [value]="view.value"
              [attr.aria-invalid]="view.invalid"
              [attr.aria-describedby]="view.describedBy"
              (input)="onText(view.field, $event)"
            />
            @if (view.invalid) {
              <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.violation }}</p>
            }
          </div>
        }
        <div class="ocu-field" data-field="SMTPPassword">
          <label class="ocu-field-label" [attr.for]="passwordId">{{ STRINGS.authOptionsSmtpPassword }}</label>
          <input
            class="ocu-field-input"
            type="password"
            autocomplete="new-password"
            [id]="passwordId"
            [value]="password"
            [disabled]="clearPassword"
            [attr.aria-invalid]="passwordInvalid"
            [attr.aria-describedby]="passwordHintId"
            (input)="onPassword($event)"
          />
          <p class="ocu-field-caption" [id]="passwordHintId" data-slot="password-hint">{{ STRINGS.authOptionsSmtpPasswordHint }}</p>
          @if (passwordInvalid) {
            <p class="ocu-form-error">{{ passwordViolation }}</p>
          }
          <label class="ocu-field-checkbox" data-flag="clear-password">
            <input type="checkbox" [id]="clearId" [checked]="clearPassword" (click)="onClear($event)" />
            <span>{{ STRINGS.authOptionsSmtpPasswordClear }}</span>
          </label>
        </div>
      }
    </fieldset>

    <fieldset class="ocu-form-fields ocu-field" data-group="jwt">
      <legend class="ocu-field-label">{{ STRINGS.oauthServerGroupJwt }}</legend>
      <div class="ocu-field" [attr.data-field]="issuerView.field">
        <label class="ocu-field-label" [attr.for]="issuerView.id">{{ issuerView.label }}</label>
        <input
          class="ocu-field-input"
          type="text"
          autocomplete="off"
          spellcheck="false"
          [id]="issuerView.id"
          [value]="issuerView.value"
          [attr.aria-invalid]="issuerView.invalid"
          [attr.aria-describedby]="tokenDescribedBy(issuerView)"
          (input)="onText(issuerView.field, $event)"
        />
        @if (issuerView.invalid) {
          <p class="ocu-form-error" [id]="issuerView.id + '-reason'">{{ issuerView.violation }}</p>
        }
      </div>
      <div class="ocu-field" [attr.data-field]="sigAlgField">
        <label class="ocu-field-label" [attr.for]="sigAlgId">{{ STRINGS.authOptionsJwtSigAlg }}</label>
        <select
          class="ocu-field-input"
          [id]="sigAlgId"
          [attr.aria-invalid]="sigAlgInvalid"
          [attr.aria-describedby]="tokenDescribedBy(sigAlgView)"
          (change)="onSigAlg($event)"
        >
          @for (name of sigAlgs; track name) {
            <option [value]="name" [selected]="name === sigAlgValue">{{ name }}</option>
          }
        </select>
        @if (sigAlgInvalid) {
          <p class="ocu-form-error" [id]="sigAlgId + '-reason'">{{ sigAlgViolation }}</p>
        }
      </div>
      @if (hasTokenEffect) {
        <p class="ocu-field-caption" [id]="tokenEffectId" data-slot="token-effect">{{ tokenEffect }}</p>
      }
    </fieldset>
    }

    @if (loadedFlag) {
    <div class="ocu-form-bar">
      <div class="ocu-form-bar-status">
        @if (showSaved) {
          <span role="status">{{ savedText }}</span>
        }
        @if (showSignedOut) {
          <span role="status" data-slot="sign-out-line">{{ STRINGS.authOptionsSignOutConsequence }}</span>
        }
        @if (hasSecretsRefused) {
          <span role="alert" data-slot="secrets-refused">{{ secretsRefused }}</span>
        }
      </div>
      <div class="ocu-form-bar-actions">
        <button type="button" class="ocu-button-text" (click)="cancel()">{{ STRINGS.actionCancel }}</button>
        <button type="button" class="ocu-button-primary" data-auth-options="save" [attr.aria-disabled]="saveBlocked" (click)="onSave()">
          {{ STRINGS.actionSave }}
        </button>
      </div>
    </div>
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
export class AuthOptionsPage {
  private readonly store = inject(AuthOptionsForm);
  private readonly formDirty = inject(FormDirty);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  protected readonly sigAlgField = SIG_ALG_FIELD;

  protected readonly sigAlgId = authOptionsControlId(SIG_ALG_FIELD);

  protected readonly passwordId = authOptionsControlId(PASSWORD_FIELD);

  protected readonly passwordHintId = `${authOptionsControlId(PASSWORD_FIELD)}-hint`;

  protected readonly clearId = `${authOptionsControlId(PASSWORD_FIELD)}-clear`;

  protected readonly tokenEffectId = 'ocu-auth-options-token-effect';

  /** Bumped by the stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  /** The SMTP password typed: this page's alone, never a store's (AD-35). */
  private readonly passwordValue = signal('');

  /** Whether the stored SMTP password is to be cleared. */
  private readonly clearValue = signal(false);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  private focusedSummary = false;

  constructor() {
    const stopStore = this.store.subscribe(() => this.bump());
    const stopDirty = this.formDirty.subscribe(() => this.bump());
    void this.store.open();
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      this.passwordValue.set('');
      this.store.reset();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get loadedFlag(): boolean {
    this.generation();
    return this.store.loaded();
  }

  protected get heldFlag(): boolean {
    this.generation();
    return this.store.editable();
  }

  protected get faultFlag(): boolean {
    this.generation();
    return this.store.fault();
  }

  protected get busyFlag(): 'true' | null {
    this.generation();
    return this.store.busy() ? 'true' : null;
  }

  protected get saveBlocked(): 'true' | null {
    this.generation();
    return this.store.canSave() ? null : 'true';
  }

  protected get violations(): readonly Violation[] {
    this.generation();
    return this.store.violations();
  }

  protected get hasSummary(): boolean {
    return this.violations.length > 0;
  }

  /** An envelope-level refusal (AD-8, AD-39): a privilege denial naming its pair, or the envelope's own reason. */
  protected get reason(): string {
    this.generation();
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') {
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.authOptionsRefusedAction);
    }
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get showSaved(): boolean {
    this.generation();
    return this.store.saved();
  }

  protected get showSignedOut(): boolean {
    this.generation();
    return this.store.saved() && this.store.signedOut();
  }

  protected get secretsRefused(): string {
    this.generation();
    return this.store.secretsRefused();
  }

  protected get hasSecretsRefused(): boolean {
    return this.store.saved() && this.secretsRefused !== '';
  }

  protected get savedText(): string {
    this.generation();
    return savedLine(this.store.readBack());
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  protected get smsShown(): boolean {
    this.generation();
    return this.store.smsShown();
  }

  protected get tokenEffect(): string {
    this.generation();
    return this.store.tokenEffect();
  }

  protected get hasTokenEffect(): boolean {
    return this.tokenEffect !== '';
  }

  protected get password(): string {
    return this.passwordValue();
  }

  protected get clearPassword(): boolean {
    return this.clearValue();
  }

  protected get passwordViolation(): string {
    this.generation();
    return this.store.violationFor(PASSWORD_FIELD);
  }

  protected get passwordInvalid(): 'true' | null {
    return this.passwordViolation === '' ? null : 'true';
  }

  protected get methodViews(): readonly FlagView[] {
    return METHOD_FLAGS.map(([field, label]) => this.flagView(field, label));
  }

  protected get loginTokenView(): FlagView {
    return this.flagView('AutheLoginToken', STRINGS.authOptionsLoginToken);
  }

  protected get twoFactorViews(): readonly FlagView[] {
    return [this.flagView('AutheTwoFactorPW', STRINGS.authOptionsTwoFactorPw), this.flagView('AutheTwoFactorSMS', STRINGS.authOptionsTwoFactorSms)];
  }

  protected get cookieView(): InputView {
    return this.inputView('LoginCookieTimeout', STRINGS.authOptionsCookieTimeout, true);
  }

  protected get smsViews(): readonly InputView[] {
    return [
      this.inputView('TwoFactorTimeout', STRINGS.authOptionsTwoFactorTimeout, true),
      this.inputView('SMTPServer', STRINGS.authOptionsSmtpServer, false),
      this.inputView('TwoFactorFrom', STRINGS.authOptionsTwoFactorFrom, false),
      this.inputView('SMTPUsername', STRINGS.authOptionsSmtpUsername, false),
    ];
  }

  protected get issuerView(): InputView {
    return this.inputView('JWTIssuer', STRINGS.authOptionsJwtIssuer, false);
  }

  protected get sigAlgView(): InputView {
    return this.inputView(SIG_ALG_FIELD, STRINGS.authOptionsJwtSigAlg, false);
  }

  protected get sigAlgs(): readonly string[] {
    this.generation();
    return this.store.sigAlgs();
  }

  protected get sigAlgValue(): string {
    this.generation();
    return this.store.text(SIG_ALG_FIELD);
  }

  protected get sigAlgViolation(): string {
    this.generation();
    return this.store.violationFor(SIG_ALG_FIELD);
  }

  protected get sigAlgInvalid(): 'true' | null {
    return this.sigAlgViolation === '' ? null : 'true';
  }

  // --- intents ---------------------------------------------------------------------------------

  /**
   * A flag whose turn-off is refused, or that its dependency makes unavailable, is never changed: its click
   * is cancelled. Any other click sets the flag to what the click made it.
   */
  protected onFlagClick(event: Event, view: FlagView): void {
    if (view.unavailable || (view.refused && view.checked)) {
      event.preventDefault();
      return;
    }
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setFlag(view.field, target.checked);
  }

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setText(field, target.value);
  }

  protected onSigAlg(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLSelectElement) this.store.setText(SIG_ALG_FIELD, target.value);
  }

  protected onPassword(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement)) return;
    this.passwordValue.set(target.value);
    this.store.setPasswordPending(target.value !== '' || this.clearValue());
  }

  protected onClear(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement)) return;
    this.clearValue.set(target.checked);
    if (target.checked) this.passwordValue.set('');
    this.store.setPasswordPending(target.checked || this.passwordValue() !== '');
  }

  protected onRetry(): void {
    void this.store.open();
  }

  /** One Save; the password is handed over once and cleared whatever the answer (AD-35). */
  protected async onSave(): Promise<void> {
    if (!this.store.canSave()) return;
    const password = this.clearValue() ? '' : this.passwordValue() === '' ? null : this.passwordValue();
    this.passwordValue.set('');
    this.clearValue.set(false);
    const saved = await this.store.save(password);
    if (!saved) this.afterRefusal();
  }

  protected focusField(field: string): void {
    document.getElementById(authOptionsControlId(field))?.focus();
  }

  /** Cancel: the options as the instance holds them, every unsaved change and the password dropped. */
  protected cancel(): void {
    this.passwordValue.set('');
    this.clearValue.set(false);
    void this.store.open();
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  /** The caption a token setting's control is described by while a token setting is changed. */
  protected tokenDescribedBy(view: InputView): string | null {
    this.generation();
    const parts = [view.invalid ? `${view.id}-reason` : null, this.store.tokenEffect() === '' ? null : this.tokenEffectId].filter((entry): entry is string => entry !== null);
    return parts.length === 0 ? null : parts.join(' ');
  }

  // --- internals -------------------------------------------------------------------------------

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  private flagView(field: string, label: string): FlagView {
    this.generation();
    const id = authOptionsControlId(field);
    const reason = this.store.refusal(field);
    const refused = reason !== '';
    const unavailable = (field === 'AutheAlwaysTryDelegated' && !this.store.alwaysTryEnabled()) || (field === 'AutheLDAPCache' && !this.store.ldapCacheEnabled());
    const violation = this.store.violationFor(field);
    const reasonId = `${id}-reason`;
    const described = [refused ? reasonId : null, violation === '' ? null : `${id}-violation`].filter((entry): entry is string => entry !== null);
    return {
      field,
      label,
      id,
      checked: this.store.flag(field),
      refused,
      unavailable,
      ariaDisabled: refused ? 'true' : null,
      reasonId,
      reason,
      describedBy: described.length === 0 ? null : described.join(' '),
      invalid: violation !== '',
      violation,
    };
  }

  private inputView(field: string, label: string, numeric: boolean): InputView {
    this.generation();
    const id = authOptionsControlId(field);
    const violation = this.store.violationFor(field);
    return { field, label, id, value: this.store.text(field), numeric, invalid: violation !== '', violation, describedBy: violation === '' ? null : `${id}-reason` };
  }

  /** After a refused Save: the error summary takes focus, then the first invalid field. */
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
}
