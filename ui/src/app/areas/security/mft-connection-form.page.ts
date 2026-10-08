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
import { savedLine } from '../../core/read-back';
import { STRINGS } from '../../core/strings';
import { STATE_CONFLICT_CODE, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { APPLICATION_FIELD, MftConnectionForm, NAME_FIELD, SERVICES, SERVICE_FIELD, SSL_FIELD, URL_FIELD, USERNAME_FIELD } from './mft-connection-form.store';

/** The list this form is reached from, which Cancel returns to. */
export const MFT_CONNECTION_LIST_ROUTE = 'security/mft-connections';

/** This form's own route, the fallback when the mirror cannot resolve it from the URL. */
export const MFT_CONNECTION_FORM_ROUTE = 'security/mft-connections/edit';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** Each field's control id. */
export function mftConnectionControlId(field: string): string {
  return `ocu-mft-connection-${field}`;
}

/** The id of a field's hint, which the field is described by. */
export function mftConnectionHintId(field: string): string {
  return `${mftConnectionControlId(field)}-hint`;
}

/** One field, resolved for drawing. */
interface InputView {
  readonly id: string;
  readonly invalid: boolean;
  readonly violation: string;
  readonly describedBy: string | null;
}

/**
 * The managed file transfer connection editor (Story 18.26, SA-MFT, AD-55): `security/mft-connections/edit`
 * creates a connection and `security/mft-connections/edit/<name>` edits one, on the superserver editor's model.
 *
 * **Its fields are the classic editor's**: the name and the file service (a create only), the URL, the client
 * SSL/TLS configuration (a picker over the configurations the SSL/TLS list reads), the email address and the
 * OAuth 2.0 client configuration the connection names. Authorizing a connection is a person's sign-in at the
 * file service and stays on the classic page, which a hint names in plain text (AD-44).
 *
 * It composes no payload and authors no field sentence; the unsaved-changes guard is the `form-page` route
 * guard, answered here. Every control-flow condition is a paren-free member reference, for the reason
 * `sign-in.ts` records.
 */
@Component({
  selector: 'app-mft-connection-form-page',
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
      <p class="ocu-banner ocu-banner-warning" role="alert" data-mft-connection="reason">{{ reason }}</p>
    }

    @if (loadedFlag) {
    <p class="ocu-form-legend">{{ STRINGS.formRequiredFieldsLegend }}</p>
    <fieldset class="ocu-form-fields ocu-field" data-group="connection">
      <legend class="ocu-field-label">{{ STRINGS.processDetailsGroupGeneral }}</legend>
      <div class="ocu-field" data-field="Name">
        <label class="ocu-field-label" [class.ocu-field-label-required]="creating" [attr.for]="nameView.id">{{ STRINGS.tableColumnName }}</label>
        <input
          class="ocu-field-input"
          type="text"
          autocomplete="off"
          spellcheck="false"
          [id]="nameView.id"
          [value]="nameValue"
          [readOnly]="fixedReadOnly"
          [attr.aria-required]="requiredFlag"
          [attr.aria-invalid]="nameView.invalid"
          [attr.aria-describedby]="nameView.describedBy"
          (input)="onText('Name', $event)"
          (blur)="onBlur('Name')"
        />
        @if (creating) {
          <p class="ocu-field-caption" [id]="nameHintId">{{ STRINGS.mftConnectionCreateOnlyHint }}</p>
        }
        @if (nameView.invalid) {
          <p class="ocu-form-error" [id]="nameView.id + '-reason'">{{ nameView.violation }}</p>
        }
      </div>
      <div class="ocu-field" data-field="Service">
        <label class="ocu-field-label" [class.ocu-field-label-required]="creating" [attr.for]="serviceView.id">{{ STRINGS.mftConnectionService }}</label>
        <select
          class="ocu-field-input"
          [id]="serviceView.id"
          [disabled]="fixedReadOnly"
          [attr.aria-required]="requiredFlag"
          [attr.aria-invalid]="serviceView.invalid"
          [attr.aria-describedby]="serviceView.describedBy"
          (change)="onSelect('Service', $event)"
        >
          @for (option of serviceOptions; track option) {
            <option [value]="option" [selected]="option === serviceValue">{{ option }}</option>
          }
        </select>
        @if (creating) {
          <p class="ocu-field-caption" [id]="serviceHintId">{{ STRINGS.mftConnectionCreateOnlyHint }}</p>
        }
        @if (serviceView.invalid) {
          <p class="ocu-form-error" [id]="serviceView.id + '-reason'">{{ serviceView.violation }}</p>
        }
      </div>
      <div class="ocu-field" data-field="URL">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="urlView.id">{{ STRINGS.mftConnectionUrl }}</label>
        <input
          class="ocu-field-input"
          type="text"
          autocomplete="off"
          spellcheck="false"
          [id]="urlView.id"
          [value]="urlValue"
          [readOnly]="locked"
          aria-required="true"
          [attr.aria-invalid]="urlView.invalid"
          [attr.aria-describedby]="urlView.describedBy"
          (input)="onText('URL', $event)"
          (blur)="onBlur('URL')"
        />
        <p class="ocu-field-caption" [id]="urlHintId">{{ STRINGS.mftConnectionUrlHint }}</p>
        @if (urlView.invalid) {
          <p class="ocu-form-error" [id]="urlView.id + '-reason'">{{ urlView.violation }}</p>
        }
      </div>
      <div class="ocu-field" data-field="SSLConfiguration">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="sslView.id">{{ STRINGS.sslFormLabel }}</label>
        <select
          class="ocu-field-input"
          [id]="sslView.id"
          [disabled]="locked"
          aria-required="true"
          [attr.aria-invalid]="sslView.invalid"
          [attr.aria-describedby]="sslView.describedBy"
          (change)="onSelect('SSLConfiguration', $event)"
        >
          @for (option of sslOptions; track option.value) {
            <option [value]="option.value" [selected]="option.value === sslValue">{{ option.label }}</option>
          }
        </select>
        @if (noClientConfigs) {
          <p class="ocu-field-caption" data-slot="no-client-configuration">{{ STRINGS.mftConnectionSslNoClient }}</p>
        }
        @if (sslView.invalid) {
          <p class="ocu-form-error" [id]="sslView.id + '-reason'">{{ sslView.violation }}</p>
        }
      </div>
      <div class="ocu-field" data-field="Username">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="usernameView.id">{{ STRINGS.userFieldEmail }}</label>
        <input
          class="ocu-field-input"
          type="text"
          autocomplete="off"
          spellcheck="false"
          [id]="usernameView.id"
          [value]="usernameValue"
          [readOnly]="locked"
          aria-required="true"
          [attr.aria-invalid]="usernameView.invalid"
          [attr.aria-describedby]="usernameView.describedBy"
          (input)="onText('Username', $event)"
          (blur)="onBlur('Username')"
        />
        @if (usernameView.invalid) {
          <p class="ocu-form-error" [id]="usernameView.id + '-reason'">{{ usernameView.violation }}</p>
        }
      </div>
      <div class="ocu-field" data-field="ApplicationName">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="applicationView.id">{{ STRINGS.mftConnectionApplicationName }}</label>
        <input
          class="ocu-field-input"
          type="text"
          autocomplete="off"
          spellcheck="false"
          [id]="applicationView.id"
          [value]="applicationValue"
          [readOnly]="locked"
          aria-required="true"
          [attr.aria-invalid]="applicationView.invalid"
          [attr.aria-describedby]="applicationView.describedBy"
          (input)="onText('ApplicationName', $event)"
          (blur)="onBlur('ApplicationName')"
        />
        <p class="ocu-field-caption" [id]="applicationHintId">{{ STRINGS.mftConnectionApplicationHint }}</p>
        @if (applicationView.invalid) {
          <p class="ocu-form-error" [id]="applicationView.id + '-reason'">{{ applicationView.violation }}</p>
        }
      </div>
      <p class="ocu-field-caption" data-slot="authorize-hint">{{ STRINGS.mftConnectionAuthorizeHint }}</p>
    </fieldset>

    <div class="ocu-form-bar">
      <div class="ocu-form-bar-status">
        @if (showSaved) {
          <span role="status">{{ savedText }}</span>
        }
      </div>
      <div class="ocu-form-bar-actions">
        <button type="button" class="ocu-button-text" (click)="cancel()">{{ STRINGS.actionCancel }}</button>
        <button type="button" class="ocu-button-primary" data-mft-connection="save" [attr.aria-disabled]="saveBlocked" (click)="onSave()">
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
export class MftConnectionFormPage {
  private readonly store = inject(MftConnectionForm);
  private readonly formDirty = inject(FormDirty);
  private readonly router = inject(Router);
  private readonly navigation = inject(NavigationService);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  protected readonly serviceOptions: readonly string[] = SERVICES;

  protected readonly nameHintId = mftConnectionHintId(NAME_FIELD);

  protected readonly serviceHintId = mftConnectionHintId(SERVICE_FIELD);

  protected readonly urlHintId = mftConnectionHintId(URL_FIELD);

  protected readonly applicationHintId = mftConnectionHintId(APPLICATION_FIELD);

  /** Bumped by both stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

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
      // Kept across a create's own route replacement, which destroys this page and builds it again
      // over the new connection; torn down on every other departure.
      if (!this.store.retaining()) this.store.reset();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get loadedFlag(): boolean {
    this.generation();
    return this.store.loaded();
  }

  protected get busyFlag(): 'true' | null {
    this.generation();
    return this.store.busy() ? 'true' : null;
  }

  protected get creating(): boolean {
    this.generation();
    return this.store.mode() === 'create';
  }

  protected get requiredFlag(): 'true' | null {
    return this.creating ? 'true' : null;
  }

  /** The name and the service are fixed once the connection exists: read-only on an edit. */
  protected get fixedReadOnly(): boolean {
    this.generation();
    return this.store.mode() === 'edit' || !this.store.editable();
  }

  /** Whether the fields refuse input: an edit whose fresh read has not landed. */
  protected get locked(): boolean {
    this.generation();
    return !this.store.editable();
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

  /** What an envelope-level refusal reads (AD-8, AD-39): a privilege denial naming its pair, a stale save's sentence, or the envelope's own reason. */
  protected get reason(): string {
    this.generation();
    const pair = this.store.refusalPair();
    if (this.store.refusalCode() === NO_PRIVILEGE_CODE && pair !== '') {
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.mftConnectionRefusedAction);
    }
    if (this.store.refusalCode() === STATE_CONFLICT_CODE) return STRINGS.formStaleSave;
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get showSaved(): boolean {
    this.generation();
    return this.store.saved();
  }

  protected get savedText(): string {
    this.generation();
    return savedLine(this.store.readBack());
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  protected get noClientConfigs(): boolean {
    this.generation();
    return this.store.configs().length === 0;
  }

  protected get nameValue(): string {
    this.generation();
    return this.store.value(NAME_FIELD);
  }

  protected get serviceValue(): string {
    this.generation();
    return this.store.value(SERVICE_FIELD);
  }

  protected get urlValue(): string {
    this.generation();
    return this.store.value(URL_FIELD);
  }

  protected get sslValue(): string {
    this.generation();
    return this.store.value(SSL_FIELD);
  }

  protected get usernameValue(): string {
    this.generation();
    return this.store.value(USERNAME_FIELD);
  }

  protected get applicationValue(): string {
    this.generation();
    return this.store.value(APPLICATION_FIELD);
  }

  /** The picker's options: an empty choice (the field is required, so it offers no "None"), every client
   * configuration, and the one held when it is neither. */
  protected get sslOptions(): readonly { readonly value: string; readonly label: string }[] {
    this.generation();
    const names = [...this.store.configs()];
    const held = this.store.value(SSL_FIELD);
    if (held !== '' && !names.includes(held)) names.push(held);
    return [{ value: '', label: '' }, ...names.map((name) => ({ value: name, label: name }))];
  }

  protected get nameView(): InputView {
    return this.inputView(NAME_FIELD, this.creating ? this.nameHintId : null);
  }

  protected get serviceView(): InputView {
    return this.inputView(SERVICE_FIELD, this.creating ? this.serviceHintId : null);
  }

  protected get urlView(): InputView {
    return this.inputView(URL_FIELD, this.urlHintId);
  }

  protected get sslView(): InputView {
    return this.inputView(SSL_FIELD, null);
  }

  protected get usernameView(): InputView {
    return this.inputView(USERNAME_FIELD, null);
  }

  protected get applicationView(): InputView {
    return this.inputView(APPLICATION_FIELD, this.applicationHintId);
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setValue(field, target.value);
  }

  protected onSelect(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLSelectElement) this.store.setValue(field, target.value);
  }

  protected onBlur(field: string): void {
    this.store.onBlur(field);
  }

  protected async onSave(): Promise<void> {
    if (!this.store.canSave()) return;
    const creating = this.store.mode() === 'create';
    const saved = await this.store.save();
    if (!saved) {
      this.afterRefusal();
      return;
    }
    // A create replaces the route with the new connection's URL, so the address bar names the entity
    // and Back goes to the list; the page is built again there over its edit.
    if (creating && this.store.createdId() !== '') {
      this.store.retainAcrossRouteReplacement();
      void this.router.navigateByUrl(this.editorUrl(this.store.createdId()), { replaceUrl: true });
    }
  }

  protected focusField(field: string): void {
    document.getElementById(mftConnectionControlId(field))?.focus();
  }

  protected cancel(): void {
    void this.router.navigateByUrl(withQuery(MFT_CONNECTION_LIST_ROUTE, this.router.url));
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  /** The connection this route names, or `''` for the create. */
  private routeId(): string {
    const screen = screenForRoute(MFT_CONNECTION_FORM_ROUTE);
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

  /** A field's view: its refusal and the hint and refusal it is described by. */
  private inputView(field: string, hintId: string | null): InputView {
    this.generation();
    const id = mftConnectionControlId(field);
    const violation = this.store.violationFor(field);
    const described = [hintId, violation === '' ? null : `${id}-reason`].filter((entry): entry is string => entry !== null);
    return { id, invalid: violation !== '', violation, describedBy: described.length === 0 ? null : described.join(' ') };
  }

  /** The new connection's own URL. The id is `encodeEntityId`'s, never `encodeURIComponent`'s (AD-13). */
  private editorUrl(id: string): string {
    const editor = this.navigation.screenForUrl(this.router.url);
    const route = editor === null ? MFT_CONNECTION_FORM_ROUTE : editor.route;
    return withQuery(`${route}/${encodeEntityId(id)}`, this.router.url);
  }
}
