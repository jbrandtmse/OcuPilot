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
import { STRINGS } from '../../core/strings';
import { STATE_CONFLICT_CODE, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import {
  ALIAS_FIELD,
  CERTIFICATE_FIELD,
  type CredentialView,
  OWNER_LIST_FIELD,
  PASSWORD_FIELD,
  PEER_NAMES_FIELD,
  PRIVATE_KEY_FIELD,
  X509Form,
} from './x509-form.store';

/** The list this form is reached from, which Cancel returns to. */
export const X509_LIST_ROUTE = 'security/x509';

/** This form's own route, the fallback when the mirror cannot resolve it from the URL. */
export const X509_FORM_ROUTE = 'security/x509/edit';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** One field, resolved for drawing: its control id, its refusal and its described-by wiring. */
interface FieldView {
  readonly id: string;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
}

/**
 * The X.509 credential form, a `form-page` that imports a credential on `security/x509/edit` and
 * edits one on `security/x509/edit/<alias>` (AD-55, FR-43).
 *
 * **An import's fields are in the classic editor's order** (`%CSP.UI.Portal.X509Credential`): alias,
 * certificate, private key, private key password, authorized users and intended peers. No field takes
 * a file path: "Load from file" reads a local file in the browser into the field it sits beside
 * (AD-21).
 *
 * **The private key and its password are masked, never pre-filled and never echoed** (AD-35): each
 * input is bound to the store's value, which is empty until typed or loaded and emptied again by an
 * accepted Save, and each carries a labelled show/hide toggle whose state is this page's alone.
 *
 * **An edit shows the credential as its fresh read answered it**, read-only, and changes only the two
 * lists; it has no secret field, so no stored-secret caption applies.
 *
 * It composes no payload and authors no field sentence; the unsaved-changes guard is the `form-page`
 * route guard, answered here. Every control-flow condition is a paren-free member reference, for the
 * reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-x509-form-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
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
      @if (creating) {
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="aliasField.id">{{ STRINGS.x509ColumnAlias }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            [id]="aliasField.id"
            [value]="value('Alias')"
            aria-required="true"
            [attr.maxlength]="maxLength('Alias')"
            [attr.aria-invalid]="aliasField.invalid"
            [attr.aria-describedby]="aliasField.describedBy"
            (input)="onText('Alias', $event)"
            (blur)="onBlur('Alias')"
          />
        </div>
        @if (aliasField.invalid) {
          <p class="ocu-form-error" [id]="aliasField.id + '-reason'">{{ aliasField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="certificateField.id">{{ STRINGS.x509FieldCertificate }}</label>
        <div class="ocu-field-control">
          <textarea
            class="ocu-field-input ocu-field-textarea ocu-x509-pem"
            rows="6"
            spellcheck="false"
            autocomplete="off"
            [id]="certificateField.id"
            [value]="certificateValue"
            aria-required="true"
            [attr.aria-invalid]="certificateField.invalid"
            [attr.aria-describedby]="certificateField.describedBy"
            (input)="onCertificate($event)"
            (blur)="onBlur('Certificate')"
          ></textarea>
        </div>
        <input #certificateFile class="ocu-x509-file" type="file" tabindex="-1" aria-hidden="true" (change)="onFile('Certificate', $event)" />
        <button type="button" class="ocu-button-text" [id]="certificateField.id + '-load'" (click)="pickFile('Certificate')">{{ STRINGS.x509LoadFromFile }}</button>
        @if (certificateField.invalid) {
          <p class="ocu-form-error" [id]="certificateField.id + '-reason'">{{ certificateField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="privateKeyField.id">{{ STRINGS.x509FieldPrivateKey }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            [id]="privateKeyField.id"
            [type]="keyInputType"
            autocomplete="new-password"
            spellcheck="false"
            [value]="privateKeyValue"
            [attr.aria-invalid]="privateKeyField.invalid"
            [attr.aria-describedby]="privateKeyField.describedBy"
            (input)="onPrivateKey($event)"
            (blur)="onBlur('PrivateKey')"
          />
          <button
            type="button"
            class="ocu-reveal-toggle"
            [attr.aria-label]="keyRevealLabel"
            [attr.aria-pressed]="keyRevealed()"
            (click)="toggleKeyReveal()"
          >
            <span aria-hidden="true">{{ keyRevealGlyph }}</span>
          </button>
        </div>
        <input #keyFile class="ocu-x509-file" type="file" tabindex="-1" aria-hidden="true" (change)="onFile('PrivateKey', $event)" />
        <button type="button" class="ocu-button-text" [id]="privateKeyField.id + '-load'" (click)="pickFile('PrivateKey')">{{ STRINGS.x509LoadFromFile }}</button>
        @if (privateKeyField.invalid) {
          <p class="ocu-form-error" [id]="privateKeyField.id + '-reason'">{{ privateKeyField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="passwordField.id">{{ STRINGS.x509FieldPrivateKeyPassword }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            [id]="passwordField.id"
            [type]="passwordInputType"
            autocomplete="new-password"
            [value]="passwordValue"
            [attr.maxlength]="maxLength('PrivateKeyPassword')"
            [attr.aria-invalid]="passwordField.invalid"
            [attr.aria-describedby]="passwordField.describedBy"
            (input)="onPassword($event)"
            (blur)="onBlur('PrivateKeyPassword')"
          />
          <button
            type="button"
            class="ocu-reveal-toggle"
            [attr.aria-label]="passwordRevealLabel"
            [attr.aria-pressed]="passwordRevealed()"
            (click)="togglePasswordReveal()"
          >
            <span aria-hidden="true">{{ passwordRevealGlyph }}</span>
          </button>
        </div>
        <p class="ocu-field-caption" [id]="passwordField.id + '-help'">{{ STRINGS.x509PasswordHelp }}</p>
        @if (passwordField.invalid) {
          <p class="ocu-form-error" [id]="passwordField.id + '-reason'">{{ passwordField.reason }}</p>
        }
      </div>
      } @else {
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="readId('Alias')">{{ STRINGS.x509ColumnAlias }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="readId('Alias')" [value]="credential.alias" />
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="readId('SubjectDN')">{{ STRINGS.x509ColumnSubject }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="readId('SubjectDN')" [value]="credential.subject" />
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="readId('IssuerDN')">{{ STRINGS.x509ColumnIssuer }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="readId('IssuerDN')" [value]="credential.issuer" />
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="readId('ValidityNotBefore')">{{ STRINGS.x509ColumnValidFrom }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="readId('ValidityNotBefore')" [value]="credential.validFrom" />
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="readId('ValidityNotAfter')">{{ STRINGS.x509ColumnValidUntil }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="readId('ValidityNotAfter')" [value]="credential.validUntil" />
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="readId('HasPrivateKey')">{{ STRINGS.x509FieldHasPrivateKey }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="readId('HasPrivateKey')" [value]="hasPrivateKeyText" />
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="readId('CAFile')">{{ STRINGS.x509FieldCaFile }}</label>
        <input class="ocu-field-input" type="text" readonly [id]="readId('CAFile')" [value]="credential.caFile" />
      </div>
      }

      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="ownersField.id">{{ STRINGS.x509FieldOwnerList }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            [id]="ownersField.id"
            [value]="value('OwnerList')"
            [readOnly]="locked"
            [attr.aria-invalid]="ownersField.invalid"
            [attr.aria-describedby]="ownersField.describedBy"
            (input)="onText('OwnerList', $event)"
            (blur)="onBlur('OwnerList')"
          />
        </div>
        <p class="ocu-field-caption" [id]="ownersField.id + '-help'">{{ STRINGS.x509ListHelp }}</p>
        @if (ownersField.invalid) {
          <p class="ocu-form-error" [id]="ownersField.id + '-reason'">{{ ownersField.reason }}</p>
        }
      </div>

      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="peersField.id">{{ STRINGS.x509FieldPeerNames }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            [id]="peersField.id"
            [value]="value('PeerNames')"
            [readOnly]="locked"
            [attr.aria-invalid]="peersField.invalid"
            [attr.aria-describedby]="peersField.describedBy"
            (input)="onText('PeerNames', $event)"
            (blur)="onBlur('PeerNames')"
          />
        </div>
        <p class="ocu-field-caption" [id]="peersField.id + '-help'">{{ STRINGS.x509ListHelp }}</p>
        @if (peersField.invalid) {
          <p class="ocu-form-error" [id]="peersField.id + '-reason'">{{ peersField.reason }}</p>
        }
      </div>
    </div>

    <div class="ocu-form-bar">
      <div class="ocu-form-bar-status">
        @if (showSaved) {
          <span role="status">{{ STRINGS.formSaved }}</span>
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
export class X509FormPage {
  private readonly store = inject(X509Form);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  /** Bumped by both stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  /** Whether the private key and the password are shown in clear. Local to this page, never stored. */
  protected readonly keyRevealed = signal(false);

  protected readonly passwordRevealed = signal(false);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  private readonly certificateFile = viewChild<ElementRef<HTMLInputElement>>('certificateFile');

  private readonly keyFile = viewChild<ElementRef<HTMLInputElement>>('keyFile');

  /** Whether the summary has been focused for the refusal now on screen. */
  private focusedSummary = false;

  constructor() {
    const stopStore = this.store.subscribe(() => this.generation.update((value) => value + 1));
    const stopDirty = this.formDirty.subscribe(() => this.generation.update((value) => value + 1));
    let followed = this.routeId();
    void this.store.open(followed);
    // One id route to another reuses this page, so the form follows the id, not the page's life.
    const stopIdChange = this.router.events.subscribe((event) => {
      if (!(event instanceof NavigationEnd)) return;
      const id = this.routeId();
      if (id === followed) return;
      followed = id;
      void this.store.open(id);
    });
    afterNextRender(() => this.focusRefusal(), { injector: this.injector });
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
      stopIdChange.unsubscribe();
      // Kept across an import's own route replacement, which destroys this page and builds it
      // again over the new credential; torn down on every other departure.
      if (!this.store.retaining()) this.store.reset();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get loadedFlag(): boolean {
    this.generation();
    return this.store.loaded();
  }

  protected get creating(): boolean {
    this.generation();
    return this.store.mode() === 'create';
  }

  /** Whether the two lists refuse input: an edit whose fresh read has not landed. */
  protected get locked(): boolean {
    this.generation();
    return !this.store.editable();
  }

  protected get credential(): CredentialView {
    this.generation();
    return this.store.credential();
  }

  protected get hasPrivateKeyText(): string {
    return this.credential.hasPrivateKey ? STRINGS.tableStatusYes : STRINGS.tableStatusNo;
  }

  protected get saveBlocked(): boolean {
    this.generation();
    return !this.store.canSave();
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
   * published sentence and the pair the envelope named, a stale save's published sentence, or the
   * envelope's own reason.
   */
  protected get reason(): string {
    this.generation();
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') {
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.x509ListEmptyAgent);
    }
    if (this.store.refusalCode() === STATE_CONFLICT_CODE) return STRINGS.formStaleSave;
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get certificateValue(): string {
    this.generation();
    return this.store.certificate();
  }

  protected get privateKeyValue(): string {
    this.generation();
    return this.store.privateKey();
  }

  protected get passwordValue(): string {
    this.generation();
    return this.store.password();
  }

  protected get keyInputType(): string {
    return this.keyRevealed() ? 'text' : 'password';
  }

  protected get passwordInputType(): string {
    return this.passwordRevealed() ? 'text' : 'password';
  }

  protected get keyRevealGlyph(): string {
    return this.keyRevealed() ? '\u25CF' : '\u25CB';
  }

  protected get passwordRevealGlyph(): string {
    return this.passwordRevealed() ? '\u25CF' : '\u25CB';
  }

  /** The toggles' accessible names, which are what make them labelled rather than unnamed icons. */
  protected get keyRevealLabel(): string {
    return this.keyRevealed() ? STRINGS.accountHidePassword : STRINGS.accountShowPassword;
  }

  protected get passwordRevealLabel(): string {
    return this.passwordRevealed() ? STRINGS.accountHidePassword : STRINGS.accountShowPassword;
  }

  protected get showSaved(): boolean {
    this.generation();
    return this.store.saved();
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  protected value(field: string): string {
    this.generation();
    return this.store.value(field);
  }

  /** The length the instance stores for `field`, or `null` where it declares none. */
  protected maxLength(field: string): number | null {
    this.generation();
    const bound = this.store.maxLength(field);
    return bound > 0 ? bound : null;
  }

  protected readId(field: string): string {
    return this.controlId(field);
  }

  protected get aliasField(): FieldView {
    return this.fieldView(ALIAS_FIELD);
  }

  protected get certificateField(): FieldView {
    return this.fieldView(CERTIFICATE_FIELD);
  }

  protected get privateKeyField(): FieldView {
    return this.fieldView(PRIVATE_KEY_FIELD);
  }

  protected get passwordField(): FieldView {
    return this.fieldView(PASSWORD_FIELD);
  }

  protected get ownersField(): FieldView {
    return this.fieldView(OWNER_LIST_FIELD);
  }

  protected get peersField(): FieldView {
    return this.fieldView(PEER_NAMES_FIELD);
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setValue(field, target.value);
  }

  protected onCertificate(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLTextAreaElement) this.store.setCertificate(target.value);
  }

  protected onPrivateKey(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setPrivateKey(target.value);
  }

  protected onPassword(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setPassword(target.value);
  }

  protected toggleKeyReveal(): void {
    this.keyRevealed.update((value) => !value);
  }

  protected togglePasswordReveal(): void {
    this.passwordRevealed.update((value) => !value);
  }

  protected onBlur(field: string): void {
    void this.store.onBlur(field);
  }

  /** Open the browser's own file picker beside `field`. Nothing leaves the browser but the text. */
  protected pickFile(field: string): void {
    const input = field === CERTIFICATE_FIELD ? this.certificateFile() : this.keyFile();
    input?.nativeElement.click();
  }

  /** Read the picked file as text into `field`, and clear the picker so the same file can be picked again. */
  protected onFile(field: string, event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement)) return;
    const file = target.files?.[0];
    target.value = '';
    if (file === undefined) return;
    const reader = new FileReader();
    reader.onload = () => {
      const text = typeof reader.result === 'string' ? reader.result : '';
      if (field === CERTIFICATE_FIELD) this.store.setCertificate(text);
      else this.store.setPrivateKey(text);
    };
    reader.readAsText(file);
  }

  protected async onSave(): Promise<void> {
    if (!this.store.canSave()) return;
    const creating = this.store.mode() === 'create';
    const saved = await this.store.save();
    if (!saved) {
      this.afterRefusal();
      return;
    }
    // An import replaces the route with the new credential's URL, so the address bar names the
    // entity and Back goes to the list; the page is built again there over its edit.
    if (creating && this.store.createdId() !== '') {
      this.store.retainAcrossRouteReplacement();
      void this.router.navigateByUrl(this.editorUrl(this.store.createdId()), { replaceUrl: true });
    }
  }

  protected focusField(field: string): void {
    document.getElementById(this.controlId(field))?.focus();
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(X509_LIST_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  /** The alias this route names, or `''` for the import. */
  private routeId(): string {
    const screen = screenForRoute(X509_FORM_ROUTE);
    return screen === null ? '' : ownIdSegment(screen, this.router.url);
  }

  /**
   * After a refused Save: the error summary takes focus, then the first invalid field, in the
   * order EXPERIENCE.md's `form-page` validation rule states.
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
    const described: string[] = [];
    if (field === PASSWORD_FIELD || field === OWNER_LIST_FIELD || field === PEER_NAMES_FIELD) described.push(`${id}-help`);
    if (invalid) described.push(`${id}-reason`);
    return {
      id,
      reason,
      invalid,
      describedBy: described.length === 0 ? null : described.join(' '),
    };
  }

  private controlId(field: string): string {
    return `ocu-x509-${field}`;
  }

  /** The new credential's own URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private editorUrl(id: string): string {
    const editor = this.navigation.screenForUrl(this.router.url);
    const route = editor === null ? X509_FORM_ROUTE : editor.route;
    return withQuery(`${route}/${encodeEntityId(id)}`, this.router.url);
  }
}
