import { ChangeDetectionStrategy, Component, DestroyRef, ElementRef, inject, signal, viewChild } from '@angular/core';
import { Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { NavigationService } from '../../core/navigation';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { createScreenRead } from '../../core/screen-read';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { Session } from '../../core/session';
import { STRINGS, stringFor } from '../../core/strings';
import { fieldOf } from '../../core/table-model';
import { reasonForField, violationsOf, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { ScreenActionHandler, type ActionSink } from '../../shell/screen-action-handler';
import { clockTime } from './database-operation';

/** License key's descriptor (Story 18.6). */
export const LICENSE_KEY = 'OcuPilot.Screen.Descriptor.LicenseKey';

/** The declared action that activates a key: the screen's primary action and its one row action. */
export const LICENSE_KEY_ACTIVATE = 'activate';

/** The one target the activation names: the instance's one license key (AD-13's singleton id). */
export const LICENSE_KEY_TARGET = 'SYSTEM';

/** The value the activation sends its key text under, the tool's declared secret (AD-56 (i)). */
export const LICENSE_KEY_VALUE = 'Key';

/** The screen-only check of a key's text (never a tool: the model never holds a key). */
export const LICENSE_KEY_VALIDATE_PATH = '/api/ocupilot/license/key/validate';

/** The textarea's control id, which a refusal's reason describes. */
export const LICENSE_KEY_TEXT_ID = 'ocu-license-key-text';

/** The thirteen fields the page lists, in the classic License Key page's order, each with its label key. */
export const LICENSE_KEY_FIELDS: readonly { readonly field: string; readonly labelKey: keyof typeof STRINGS }[] = [
  { field: 'LicenseCapacity', labelKey: 'licenseKeyLicenseCapacity' },
  { field: 'CustomerName', labelKey: 'licenseKeyCustomerName' },
  { field: 'OrderNumber', labelKey: 'licenseKeyOrderNumber' },
  { field: 'Product', labelKey: 'licenseKeyProduct' },
  { field: 'LicenseType', labelKey: 'licenseKeyLicenseType' },
  { field: 'Server', labelKey: 'licenseKeyServer' },
  { field: 'Platform', labelKey: 'licenseKeyPlatform' },
  { field: 'LicenseUnits', labelKey: 'licenseUsageLicenseUnits' },
  { field: 'CoresLicensed', labelKey: 'licenseKeyCoresLicensed' },
  { field: 'CoresEnforced', labelKey: 'licenseKeyCoresEnforced' },
  { field: 'ExpirationDate', labelKey: 'licenseKeyExpirationDate' },
  { field: 'ExtendedFeaturesList', labelKey: 'licenseKeyExtendedFeatures' },
  { field: 'AuthorizedApplications', labelKey: 'licenseKeyAuthorizedApplications' },
];

/** The sentence template each reduction kind reads with, as `LicensePort` names the kinds. */
const REDUCTION_SENTENCES: Readonly<Record<string, string>> = {
  Cores: STRINGS.licenseKeyReductionCores,
  Users: STRINGS.licenseKeyReductionUsers,
  Server: STRINGS.licenseKeyReductionServer,
  LicenseType: STRINGS.licenseKeyReductionLicenseType,
  Product: STRINGS.licenseKeyReductionProduct,
};

/** One field of the key, resolved for drawing. */
interface FieldView {
  readonly field: string;
  readonly label: string;
  readonly value: string;
}

/** What the last validation of the current text answered: valid, with its restart flag and reduction lines. */
export interface Validation {
  readonly requiresRestart: boolean;
  readonly lines: readonly string[];
}

/**
 * A field's value as the page shows it: a list joined with commas, "(none)" when it is empty or
 * absent, a number as written, any other value as its text.
 */
export function fieldText(row: unknown, field: string): string {
  const value = fieldOf(row, field);
  if (Array.isArray(value)) {
    const items = value.filter((entry) => typeof entry === 'string' || typeof entry === 'number').map(String);
    return items.length === 0 ? STRINGS.tableEmptyValue : items.join(', ');
  }
  if (typeof value === 'number') return String(value);
  if (typeof value === 'string' && value !== '') return value;
  return STRINGS.tableEmptyValue;
}

/**
 * A valid validation's answer as the dialog states it (AD-39): the restart flag and one sentence per
 * reduction and for the features removed, in OcuPilot's own words. A kind the page publishes no
 * sentence for is left out. Each value is inserted through a replacer, so a value holding a
 * placeholder is shown as written. `null` for an answer that is not a valid one.
 */
export function validationOf(body: unknown): Validation | null {
  if (body === null || typeof body !== 'object') return null;
  const record = body as Record<string, unknown>;
  if (record['valid'] !== true) return null;
  const lines: string[] = [];
  const reductions = Array.isArray(record['reductions']) ? record['reductions'] : [];
  for (const entry of reductions) {
    if (entry === null || typeof entry !== 'object') continue;
    const row = entry as Record<string, unknown>;
    const template = typeof row['kind'] === 'string' ? REDUCTION_SENTENCES[row['kind']] : undefined;
    if (template === undefined) continue;
    const from = typeof row['from'] === 'string' ? row['from'] : '';
    const to = typeof row['to'] === 'string' ? row['to'] : '';
    lines.push(template.replace('<from>', () => from).replace('<to>', () => to));
  }
  const features = (Array.isArray(record['features']) ? record['features'] : []).filter(
    (entry): entry is string => typeof entry === 'string' && entry !== ''
  );
  if (features.length > 0) lines.push(STRINGS.licenseKeyReductionFeatures.replace('<features>', () => features.join(', ')));
  return { requiresRestart: record['requiresRestart'] === true, lines };
}

/** The print line's time: the local date and clock time, `YYYY-MM-DD HH:MM:SS`. */
export function printedTime(date: Date): string {
  const pad = (value: number): string => String(value).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${clockTime(date)}`;
}

/**
 * License key (Story 18.6, AD-5): OS management's fifteenth entry, the `detail` screen on
 * `os-management/license-key`, over the screen's own declared read.
 *
 * **The fields.** The thirteen fields the read answers, each list joined and "(none)" when empty,
 * and the line that stands in for the authorization key, which the read never carries
 * (`context.secretFields`). The field block is the page's print region: Print calls the browser's
 * own print, and print media shows the block and the "Printed by" line alone (`_print.scss`).
 *
 * **Activate new key** is the screen's primary action, registered here. It opens the activate
 * dialog: the key's text, pasted or loaded from a local file, Validate, which asks the screen-only
 * check and states its answer, and Activate, at the destructive treatment, available only while the
 * last validation of the text now in the field answered valid. Activate sends the declared action
 * with the text as its one secret value (AD-56 (i)); the instance validates it again before it
 * writes. The text lives in this page's own signal and nowhere else: never a store, and cleared when
 * the dialog closes and after an activation.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-license-key-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<section class="ocu-details-page" [attr.aria-busy]="busy">
    @if (faultFlag) {
      <div class="ocu-data-table-refusal" role="alert">
        <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
        <button type="button" class="ocu-button-text" (click)="onRetry()">{{ STRINGS.actionRetry }}</button>
      </div>
    }
    @if (emptyFlag) {
      <p class="ocu-details-heading" data-license="empty">{{ emptyText }}</p>
    }
    @if (hasRow) {
      <div class="ocu-print-region" data-license="fields">
        <div class="ocu-details-fields">
          @for (view of fieldViews; track view.field) {
            <div class="ocu-details-field" [attr.data-field]="view.field">
              <span class="ocu-details-field-label">{{ view.label }}</span>
              <span class="ocu-details-field-value">{{ view.value }}</span>
            </div>
          }
        </div>
        <p class="ocu-license-key-note" data-license="authorization">{{ STRINGS.licenseKeyAuthorizationHidden }}</p>
        <p class="ocu-print-only ocu-license-key-note" data-license="printed">{{ printedLine }}</p>
      </div>
      <div class="ocu-license-key-actions">
        <button type="button" class="ocu-button-secondary" data-license="print" (click)="onPrint()">{{ STRINGS.actionPrint }}</button>
      </div>
    }

    @if (dialogOpen) {
      <app-dialog [heading]="STRINGS.licenseKeyActivateTitle" [closeLabel]="STRINGS.actionCancel" (closed)="closeDialog()">
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="textId">{{ STRINGS.licenseKeyText }}</label>
          <div class="ocu-field-control">
            <textarea
              class="ocu-field-input ocu-field-textarea ocu-x509-pem"
              rows="8"
              autocomplete="off"
              spellcheck="false"
              [id]="textId"
              [value]="keyText"
              [attr.aria-invalid]="keyInvalid"
              [attr.aria-describedby]="keyDescribedBy"
              (input)="onKeyText($event)"
            ></textarea>
          </div>
          <input #keyFile class="ocu-x509-file" type="file" accept=".key" tabindex="-1" aria-hidden="true" (change)="onFile($event)" />
          <button type="button" class="ocu-button-text" data-license="load" (click)="pickFile()">{{ STRINGS.x509LoadFromFile }}</button>
          @if (keyInvalid) {
            <p class="ocu-form-error" [id]="reasonId">{{ keyReason }}</p>
          }
        </div>
        @if (validatedFlag) {
          <div class="ocu-license-key-verdict" role="status" data-license="verdict">
            <p class="ocu-license-key-note">{{ STRINGS.licenseKeyValid }}</p>
            @if (restartFlag) {
              <p class="ocu-license-key-note" data-license="restart">{{ STRINGS.licenseKeyRestart }}</p>
            }
            @if (hasReductions) {
              <p class="ocu-license-key-note">{{ STRINGS.licenseKeyReductions }}</p>
              <ul class="ocu-license-key-reductions" data-license="reductions">
                @for (line of reductionLines; track $index) {
                  <li>{{ line }}</li>
                }
              </ul>
            }
            <p class="ocu-license-key-note" data-license="consequence">{{ STRINGS.licenseKeyActivateConsequence }}</p>
          </div>
        }
        @if (hasReason) {
          <p class="ocu-banner ocu-banner-warning" role="alert">{{ reason }}</p>
        }
        <button dialogAction type="button" class="ocu-button-secondary" data-license="validate" [attr.aria-disabled]="validateBlocked" (click)="onValidate()">
          {{ STRINGS.licenseKeyValidate }}
        </button>
        <button dialogAction type="button" class="ocu-button-destructive" data-license="activate" [attr.aria-disabled]="activateBlocked" (click)="onActivate()">
          {{ STRINGS.licenseKeyActivate }}
        </button>
      </app-dialog>
    }
  </section>`,
})
export class LicenseKeyPage {
  private readonly navigation = inject(NavigationService);
  private readonly router = inject(Router);
  private readonly stores = inject(ScreenStores);
  private readonly refresh = inject(RefreshService);
  private readonly api = inject(ApiService);
  private readonly scope = inject(ScopeService);
  private readonly actions = inject(ScreenActions);
  private readonly handler = inject(ScreenActionHandler);
  private readonly session = inject(Session, { optional: true });

  protected readonly STRINGS = STRINGS;

  protected readonly textId = LICENSE_KEY_TEXT_ID;

  protected readonly reasonId = `${LICENSE_KEY_TEXT_ID}-reason`;

  private readonly screen: ScreenDeclaration | null;

  private readonly store: ScreenStore | null;

  /** Bumped by the store and by the refresh service, so the view re-renders under `OnPush`. */
  private readonly generation = signal(0);

  private readonly open = signal(false);

  /** The key's text: this page's alone, never a store's (AD-35). */
  private readonly text = signal('');

  /** The text the last valid validation was of, and what it answered; `null` before one. */
  private readonly validation = signal<{ readonly text: string; readonly answer: Validation } | null>(null);

  private readonly violations = signal<readonly Violation[]>([]);

  private readonly envelopeReason = signal('');

  private readonly working = signal(false);

  /** When Print was last pressed, which the print-only line names. */
  private readonly printedAt = signal<Date>(new Date());

  /** Which request is current; an answer carrying an older one is stale. */
  private ask = 0;

  private readonly keyFile = viewChild<ElementRef<HTMLInputElement>>('keyFile');

  constructor() {
    const screen = this.navigation.screenForUrl(this.router.url);
    this.screen = screen !== null && screen.descriptor === LICENSE_KEY && screen.read !== null ? screen : null;
    this.store = this.screen === null ? null : this.stores.for(this.screen.descriptor, this.screen.refreshRates);
    const stops: (() => void)[] = [];
    if (this.screen !== null && this.store !== null) {
      this.store.clearAnswers();
      this.refresh.bind(this.screen, createScreenRead(this.api, this.screen));
      if (this.scope.loaded()) void this.refresh.readNow();
      stops.push(this.actions.register(LICENSE_KEY, REFRESH_ACTION_ID, () => void this.refresh.readNow()));
      stops.push(this.store.subscribe(() => this.generation.update((value) => value + 1)));
      stops.push(this.refresh.subscribe(() => this.generation.update((value) => value + 1)));
    }
    stops.push(this.actions.register(LICENSE_KEY, LICENSE_KEY_ACTIVATE, () => this.openDialog()));
    const bound = this.screen;
    inject(DestroyRef).onDestroy(() => {
      for (const stop of stops) stop();
      this.clearText();
      if (bound !== null && this.refresh.descriptor() === bound.descriptor) this.refresh.unbind();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  private get boundHere(): boolean {
    this.generation();
    return this.screen !== null && this.refresh.descriptor() === this.screen.descriptor;
  }

  private get row(): unknown {
    this.generation();
    return this.store?.data()[0] ?? null;
  }

  protected get busy(): boolean {
    return this.boundHere && !this.refresh.hasLoaded() && this.refresh.fault() === null;
  }

  protected get faultFlag(): boolean {
    return this.boundHere && this.refresh.fault() !== null;
  }

  protected get hasRow(): boolean {
    const row = this.row;
    return row !== null && typeof row === 'object';
  }

  protected get emptyFlag(): boolean {
    return this.boundHere && this.refresh.hasLoaded() && !this.hasRow && !this.faultFlag;
  }

  protected get emptyText(): string {
    return this.screen === null ? '' : stringFor(this.screen.emptyStateKey);
  }

  protected get fieldViews(): readonly FieldView[] {
    const row = this.row;
    return LICENSE_KEY_FIELDS.map(({ field, labelKey }) => ({ field, label: STRINGS[labelKey], value: fieldText(row, field) }));
  }

  /** "Printed by <user> on <time>.", for print media alone. */
  protected get printedLine(): string {
    const user = this.session?.userName() ?? '';
    return STRINGS.licenseKeyPrintedBy.replace('<user>', () => user).replace('<time>', () => printedTime(this.printedAt()));
  }

  protected get dialogOpen(): boolean {
    return this.open();
  }

  protected get keyText(): string {
    return this.text();
  }

  protected get keyReason(): string {
    return reasonForField(this.violations(), LICENSE_KEY_VALUE);
  }

  protected get keyInvalid(): boolean {
    return this.keyReason !== '';
  }

  protected get keyDescribedBy(): string | null {
    return this.keyInvalid ? this.reasonId : null;
  }

  /** Whether the last valid validation was of the text now in the field. */
  protected get validatedFlag(): boolean {
    const held = this.validation();
    return held !== null && held.text === this.text();
  }

  protected get restartFlag(): boolean {
    return this.validatedFlag && (this.validation()?.answer.requiresRestart ?? false);
  }

  protected get reductionLines(): readonly string[] {
    return this.validatedFlag ? (this.validation()?.answer.lines ?? []) : [];
  }

  protected get hasReductions(): boolean {
    return this.reductionLines.length > 0;
  }

  protected get reason(): string {
    return this.envelopeReason();
  }

  protected get hasReason(): boolean {
    return this.envelopeReason() !== '';
  }

  protected get validateBlocked(): boolean {
    return this.working() || this.text().trim() === '';
  }

  protected get activateBlocked(): boolean {
    return this.working() || !this.validatedFlag;
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onRetry(): void {
    void this.refresh.readNow();
  }

  protected onPrint(): void {
    this.printedAt.set(new Date());
    window.print();
  }

  protected closeDialog(): void {
    this.open.set(false);
    this.clearText();
  }

  protected onKeyText(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLTextAreaElement) this.setText(target.value);
  }

  /** Open the browser's own file picker. Nothing leaves the browser but the text. */
  protected pickFile(): void {
    this.keyFile()?.nativeElement.click();
  }

  /** Read the picked file as text into the field, and clear the picker so the same file can be picked again. */
  protected onFile(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement)) return;
    const file = target.files?.[0];
    target.value = '';
    if (file === undefined) return;
    const reader = new FileReader();
    reader.onload = () => {
      if (!this.open()) return;
      this.setText(typeof reader.result === 'string' ? reader.result : '');
    };
    reader.readAsText(file);
  }

  /** Ask the screen-only check about the text now in the field, and state its answer. */
  protected async onValidate(): Promise<void> {
    if (this.validateBlocked) return;
    const text = this.text();
    const ask = ++this.ask;
    this.working.set(true);
    this.violations.set([]);
    this.envelopeReason.set('');
    const result = await this.api.requestJson<unknown>(LICENSE_KEY_VALIDATE_PATH, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ [LICENSE_KEY_VALUE]: text }),
    });
    if (ask !== this.ask) return;
    this.working.set(false);
    if (result.kind !== 'ok') {
      this.validation.set(null);
      this.refused(result.kind === 'error' ? violationsOf(result) : [], result.kind === 'error' ? (result.reason ?? '') : '');
      return;
    }
    const answer = validationOf(result.body);
    this.validation.set(answer === null || this.text() !== text ? null : { text, answer });
  }

  /** Send the activation with the validated text, only while that validation still stands. */
  protected async onActivate(): Promise<void> {
    if (this.activateBlocked) return;
    const text = this.text();
    const ask = ++this.ask;
    this.working.set(true);
    this.violations.set([]);
    this.envelopeReason.set('');
    const sink: ActionSink = { setRefusal: () => undefined };
    const applied = await this.handler.sendFor(LICENSE_KEY, LICENSE_KEY_ACTIVATE, LICENSE_KEY_TARGET, { [LICENSE_KEY_VALUE]: text }, sink);
    if (ask !== this.ask) return;
    this.working.set(false);
    if (applied) {
      this.closeDialog();
      void this.refresh.readNow();
      return;
    }
    const refusal = this.handler.lastRefusal();
    this.validation.set(null);
    this.refused(refusal?.violations ?? [], refusal?.reason ?? '');
  }

  // --- internals -------------------------------------------------------------------------------

  private openDialog(): void {
    this.clearText();
    this.open.set(true);
  }

  private setText(text: string): void {
    this.text.set(text);
    if (this.keyInvalid) this.violations.set([]);
    this.envelopeReason.set('');
  }

  /** A refusal on the field where it names one, else the envelope's own sentence (AD-39). */
  private refused(violations: readonly Violation[], reason: string): void {
    const onField = violations.filter((entry) => entry.field === LICENSE_KEY_VALUE);
    this.violations.set(onField);
    this.envelopeReason.set(onField.length > 0 ? '' : reason);
  }

  /** Forget the text and everything said about it. */
  private clearText(): void {
    this.ask += 1;
    this.text.set('');
    this.validation.set(null);
    this.violations.set([]);
    this.envelopeReason.set('');
    this.working.set(false);
  }
}
