import { ChangeDetectionStrategy, Component, DestroyRef, ElementRef, Injector, afterNextRender, inject, signal, viewChild } from '@angular/core';

import { AllowedDirectoriesStore } from '../../core/allowed-directories';
import { ApiService } from '../../core/api';
import { FormDirty } from '../../core/form-dirty';
import { formatDeniedAction } from '../../core/navigation';
import { savedLine } from '../../core/read-back';
import { Session } from '../../core/session';
import { STRINGS } from '../../core/strings';
import type { Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { ServerPathPicker, type ServerPath } from '../../shell/server-path-picker';
import { TypedNameDialog } from '../../shell/typed-name-dialog';
import {
  ADMIN_FIELD,
  DEFAULT_KEY_FIELD,
  EncryptionStartupForm,
  FLAG_FIELDS,
  JOURNAL_KEY_FIELD,
  KMIP_FIELD,
  MODE_FIELD,
  PASSWORD_FIELD,
  PATH_FIELD,
  ROOT_FIELD,
  START_MODES,
  type ChoiceRefusal,
  type FlagField,
  type StartMode,
} from './encryption-startup.store';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** The audit database's name, the typed name its encryption change asks for (EXPERIENCE.md's Dialogs row). */
export const AUDIT_DATABASE_NAME = 'IRISAUDIT';

/** Each control's id. */
export function encryptionStartupControlId(field: string): string {
  return `ocu-encryption-startup-${field}`;
}

/** One start-mode option, resolved for drawing. */
interface ModeView {
  readonly mode: StartMode;
  readonly label: string;
  readonly sentence: string;
  readonly id: string;
  readonly sentenceId: string;
  readonly checked: boolean;
  readonly refused: boolean;
  readonly reason: string;
  readonly reasonId: string;
  readonly ariaDisabled: 'true' | null;
  readonly describedBy: string;
}

/** One encryption setting, resolved for drawing. */
interface FlagView {
  readonly field: FlagField;
  readonly label: string;
  readonly sentence: string;
  readonly id: string;
  readonly sentenceId: string;
  readonly checked: boolean;
  readonly refused: boolean;
  readonly reason: string;
  readonly reasonId: string;
  readonly ariaDisabled: 'true' | null;
  readonly describedBy: string;
  readonly invalid: boolean;
  readonly violation: string;
}

/** One key select, resolved for drawing. */
interface KeyView {
  readonly field: string;
  readonly label: string;
  readonly hint: string;
  readonly id: string;
  readonly hintId: string;
  readonly value: string;
  readonly options: readonly string[];
  readonly invalid: boolean;
  readonly violation: string;
  readonly describedBy: string;
  readonly emptyOption: boolean;
}

/** The sentence a refused choice carries. */
function refusalSentence(refusal: ChoiceRefusal): string {
  if (refusal === 'interactive') return STRINGS.encryptionStartupInteractiveNotOffered;
  if (refusal === 'kmip') return STRINGS.encryptionStartupKmipUnavailable;
  if (refusal === 'needs-start') return STRINGS.encryptionStartupNeedsStart;
  if (refusal === 'no-key') return STRINGS.encryptionStartupNoKey;
  if (refusal === 'no-keys') return STRINGS.databaseEncryptionEmpty;
  return '';
}

/**
 * Encryption startup settings (Story 18.23, AD-55): the unlisted `form-page` on
 * `security/database-encryption/startup`, reached from Database encryption's "Configure startup settings"
 * link, over the screen's declared read, Database encryption's read for the active keys and
 * `GET /encryption-startup/form`.
 *
 * **Key activation at startup** is four radios, each with its published sentence, Unattended's marked not
 * recommended. Interactive is drawn `aria-disabled` with its reason while the audit log, IRISSECURITY or
 * IRISTEMP is encrypted, and KMIP while no KMIP server is configured -- focusable, never selectable. KMIP
 * chosen offers the configured servers; Unattended shows the stored startup key file and the path picker
 * for another, its administrator name, and a masked password that lives in this page's own signal alone and
 * is cleared on every Save, on Cancel and when the page is left (AD-35).
 *
 * **System encryption** is four checkboxes with their sentences, each drawn `aria-disabled` with its reason
 * while turning it on is refused. The default and journal key selects offer Database encryption's active
 * keys, `aria-disabled` while none is active.
 *
 * **The sticky Save** sends only the changed settings; a Save that changes the audit log's encryption opens
 * the shared typed-name dialog first, typed name `IRISAUDIT`, stating the consequence and the advisory.
 * Refusals are drawn on their fields.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-encryption-startup-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, ServerPathPicker, TypedNameDialog],
  styles: `
    .ocu-encryption-startup-file {
      overflow-wrap: anywhere;
    }
  `,
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
      <p class="ocu-banner ocu-banner-warning" role="alert" data-encryption-startup="reason">{{ reason }}</p>
    }
    @if (faultFlag) {
      <div class="ocu-data-table-refusal" role="alert">
        <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
        <button type="button" class="ocu-button-text" (click)="onRetry()">{{ STRINGS.actionRetry }}</button>
      </div>
    }

    @if (heldFlag) {
    <fieldset class="ocu-form-fields ocu-field ocu-form-authe" [attr.data-field]="modeField">
      <legend class="ocu-field-label">{{ STRINGS.encryptionStartupModeLegend }}</legend>
      @for (view of modeViews; track view.mode) {
        <label class="ocu-field-checkbox" [attr.data-mode]="view.mode">
          <input
            type="radio"
            name="ocu-encryption-startup-mode"
            [id]="view.id"
            [checked]="view.checked"
            [attr.aria-disabled]="view.ariaDisabled"
            [attr.aria-describedby]="view.describedBy"
            (click)="onModeClick($event, view)"
            (change)="onModeChange(view)"
          />
          <span>{{ view.label }}</span>
        </label>
        <p class="ocu-field-caption" [id]="view.sentenceId" data-slot="mode-sentence">{{ view.sentence }}</p>
        @if (view.refused) {
          <p class="ocu-field-caption" [id]="view.reasonId" data-slot="mode-reason">{{ view.reason }}</p>
        }
      }
      @if (modeInvalid) {
        <p class="ocu-form-error" [id]="modeErrorId" data-slot="mode-error">{{ modeViolation }}</p>
      }
    </fieldset>

    @if (kmipChosen) {
      <div class="ocu-field" [attr.data-field]="kmipField">
        <label class="ocu-field-label" [attr.for]="kmipId">{{ STRINGS.encryptionStartupKmipServer }}</label>
        <select class="ocu-field-input" [id]="kmipId" [value]="kmipServer" [attr.aria-invalid]="kmipInvalid" (change)="onKmip($event)">
          <option value="">{{ STRINGS.tableEmptyValue }}</option>
          @for (name of kmipServers; track name) {
            <option [value]="name" [selected]="name === kmipServer">{{ name }}</option>
          }
        </select>
        @if (kmipInvalid) {
          <p class="ocu-form-error">{{ kmipViolation }}</p>
        }
      </div>
    }

    @if (unattendedChosen) {
      <div class="ocu-field" data-slot="unattended">
        @if (hasStoredKeyFile) {
          <p class="ocu-field-label">{{ STRINGS.encryptionStartupStoredKeyFile }}</p>
          <p class="ocu-field-caption ocu-encryption-startup-file" data-slot="stored-key-file">{{ storedKeyFile }}</p>
          <p class="ocu-field-label">{{ STRINGS.encryptionStartupNewKeyFile }}</p>
        }
        <app-server-path-picker
          idPrefix="ocu-encryption-startup-location"
          kind="file"
          [store]="directories"
          [root]="root"
          [path]="path"
          [rootReason]="rootReason"
          [pathReason]="pathReason"
          (changed)="onLocation($event)"
        />
        @if (newKeyFile) {
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="adminId">{{ STRINGS.encryptionKeyFileAdminName }}</label>
            <input class="ocu-field-input" type="text" autocomplete="off" spellcheck="false" [id]="adminId" [value]="adminName" [attr.aria-invalid]="adminInvalid" (input)="onAdminName($event)" />
            @if (adminInvalid) {
              <p class="ocu-form-error">{{ adminViolation }}</p>
            }
          </div>
          <div class="ocu-field">
            <label class="ocu-field-label" [attr.for]="passwordId">{{ STRINGS.fieldPassword }}</label>
            <input class="ocu-field-input" type="password" autocomplete="off" [id]="passwordId" [value]="password" [attr.aria-invalid]="passwordInvalid" (input)="onPassword($event)" />
            @if (passwordInvalid) {
              <p class="ocu-form-error">{{ passwordViolation }}</p>
            }
          </div>
        }
      </div>
    }

    <fieldset class="ocu-form-fields ocu-field" data-group="flags">
      <legend class="ocu-field-label">{{ STRINGS.encryptionStartupFlagsLegend }}</legend>
      @for (view of flagViews; track view.field) {
        <label class="ocu-field-checkbox" [attr.data-flag]="view.field">
          <input
            type="checkbox"
            [id]="view.id"
            [checked]="view.checked"
            [attr.aria-disabled]="view.ariaDisabled"
            [attr.aria-invalid]="view.invalid"
            [attr.aria-describedby]="view.describedBy"
            (click)="onFlagClick($event, view)"
          />
          <span>{{ view.label }}</span>
        </label>
        <p class="ocu-field-caption" [id]="view.sentenceId" data-slot="flag-sentence">{{ view.sentence }}</p>
        @if (view.refused) {
          <p class="ocu-field-caption" [id]="view.reasonId" data-slot="flag-reason">{{ view.reason }}</p>
        }
        @if (view.invalid) {
          <p class="ocu-form-error">{{ view.violation }}</p>
        }
      }
    </fieldset>

    @for (view of keyViews; track view.field) {
      <div class="ocu-field" [attr.data-field]="view.field">
        <label class="ocu-field-label" [attr.for]="view.id">{{ view.label }}</label>
        <select
          class="ocu-field-input"
          [id]="view.id"
          [attr.aria-disabled]="keysAriaDisabled"
          [attr.aria-invalid]="view.invalid"
          [attr.aria-describedby]="view.describedBy"
          (change)="onKey(view.field, $event)"
        >
          @if (view.emptyOption) {
            <option value="" [selected]="true">{{ STRINGS.tableEmptyValue }}</option>
          }
          @for (id of view.options; track id) {
            <option [value]="id" [selected]="id === view.value">{{ id }}</option>
          }
        </select>
        <p class="ocu-field-caption" [id]="view.hintId" data-slot="key-hint">{{ view.hint }}</p>
        @if (keysRefused) {
          <p class="ocu-field-caption" [id]="view.id + '-reason'" data-slot="key-reason">{{ keysReason }}</p>
        }
        @if (view.invalid) {
          <p class="ocu-form-error">{{ view.violation }}</p>
        }
      </div>
    }
    }

    @if (loadedFlag) {
    <div class="ocu-form-bar">
      <div class="ocu-form-bar-status">
        @if (showSaved) {
          <span role="status">{{ savedText }}</span>
        }
      </div>
      <div class="ocu-form-bar-actions">
        <button type="button" class="ocu-button-text" (click)="cancel()">{{ STRINGS.actionCancel }}</button>
        <button type="button" class="ocu-button-primary" data-encryption-startup="save" [attr.aria-disabled]="saveBlocked" (click)="onSave()">
          {{ STRINGS.actionSave }}
        </button>
      </div>
    </div>
    }

    @if (auditPending) {
      <app-typed-name-dialog
        [verb]="STRINGS.encryptionStartupAuditVerb"
        [target]="auditTarget"
        [consequence]="STRINGS.encryptionStartupAuditConsequence"
        [advisory]="STRINGS.encryptionStartupAuditAdvisory"
        (confirmed)="confirmAudit()"
        (cancelled)="cancelAudit()"
      />
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
export class EncryptionStartupPage {
  private readonly store = inject(EncryptionStartupForm);
  private readonly formDirty = inject(FormDirty);
  private readonly injector = inject(Injector);
  private readonly api = inject(ApiService);
  private readonly session = inject(Session, { optional: true });

  protected readonly STRINGS = STRINGS;

  protected readonly modeField = MODE_FIELD;

  protected readonly kmipField = KMIP_FIELD;

  protected readonly kmipId = encryptionStartupControlId(KMIP_FIELD);

  protected readonly adminId = encryptionStartupControlId(ADMIN_FIELD);

  protected readonly passwordId = encryptionStartupControlId(PASSWORD_FIELD);

  protected readonly modeErrorId = `${encryptionStartupControlId(MODE_FIELD)}-error`;

  protected readonly auditTarget = AUDIT_DATABASE_NAME;

  /** The allowed directories the picker offers, read as the page opens. */
  protected readonly directories = new AllowedDirectoriesStore();

  /** Bumped by the stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  /** The new key file administrator's password: this page's alone, never a store's (AD-35). */
  private readonly passwordValue = signal('');

  /** Whether the audit log's typed-name dialog is open. */
  private readonly auditOpen = signal(false);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  private focusedSummary = false;

  constructor() {
    const stopStore = this.store.subscribe(() => this.bump());
    const stopDirty = this.formDirty.subscribe(() => this.bump());
    void this.directories.load(this.api);
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

  protected get busyFlag(): boolean {
    this.generation();
    return this.store.busy();
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
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.encryptionStartupRefusedAction);
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

  protected get savedText(): string {
    this.generation();
    return savedLine(this.store.readBack());
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  protected get auditPending(): boolean {
    return this.auditOpen();
  }

  protected get modeViews(): readonly ModeView[] {
    this.generation();
    const labels: Readonly<Record<StartMode, string>> = {
      None: STRINGS.sslVerifyPeerNone,
      Interactive: STRINGS.encryptionStartupModeInteractive,
      Unattended: STRINGS.encryptionStartupModeUnattended,
      KMIP: STRINGS.encryptionStartupModeKmip,
    };
    const sentences: Readonly<Record<StartMode, string>> = {
      None: STRINGS.encryptionStartupNoneConsequence,
      Interactive: STRINGS.encryptionStartupInteractiveConsequence,
      Unattended: STRINGS.encryptionStartupUnattendedConsequence,
      KMIP: STRINGS.encryptionStartupKmipConsequence,
    };
    const invalid = this.modeInvalid;
    return START_MODES.map((mode) => {
      const refusal = this.store.modeRefusal(mode);
      const id = `${encryptionStartupControlId(MODE_FIELD)}-${mode}`;
      const refused = refusal !== '';
      const describedBy = [`${id}-sentence`, refused ? `${id}-reason` : '', invalid ? this.modeErrorId : ''].filter((entry) => entry !== '').join(' ');
      return {
        mode,
        label: labels[mode],
        sentence: sentences[mode],
        id,
        sentenceId: `${id}-sentence`,
        checked: this.store.mode() === mode,
        refused,
        reason: refusalSentence(refusal),
        reasonId: `${id}-reason`,
        ariaDisabled: refused ? 'true' : null,
        describedBy,
      };
    });
  }

  protected get modeViolation(): string {
    this.generation();
    return this.store.violationFor(MODE_FIELD);
  }

  protected get modeInvalid(): boolean {
    return this.modeViolation !== '';
  }

  protected get kmipChosen(): boolean {
    this.generation();
    return this.store.mode() === 'KMIP';
  }

  protected get kmipServers(): readonly string[] {
    this.generation();
    return this.store.kmipServers();
  }

  protected get kmipServer(): string {
    this.generation();
    return this.store.kmipServer();
  }

  protected get kmipViolation(): string {
    this.generation();
    return this.store.violationFor(KMIP_FIELD);
  }

  protected get kmipInvalid(): 'true' | null {
    return this.kmipViolation === '' ? null : 'true';
  }

  protected get unattendedChosen(): boolean {
    this.generation();
    return this.store.mode() === 'Unattended';
  }

  protected get storedKeyFile(): string {
    this.generation();
    return this.store.storedKeyFile();
  }

  protected get hasStoredKeyFile(): boolean {
    return this.storedKeyFile !== '';
  }

  protected get newKeyFile(): boolean {
    this.generation();
    return this.store.newKeyFile();
  }

  protected get root(): string {
    this.generation();
    return this.store.root();
  }

  protected get path(): string {
    this.generation();
    return this.store.path();
  }

  protected get rootReason(): string {
    this.generation();
    return this.store.violationFor(ROOT_FIELD);
  }

  /** A key file the rules refuse, missing or unreadable, is drawn on the name. */
  protected get pathReason(): string {
    this.generation();
    return this.store.violationFor(PATH_FIELD);
  }

  protected get adminName(): string {
    this.generation();
    return this.store.adminName();
  }

  protected get adminViolation(): string {
    this.generation();
    return this.store.violationFor(ADMIN_FIELD);
  }

  protected get adminInvalid(): 'true' | null {
    return this.adminViolation === '' ? null : 'true';
  }

  protected get password(): string {
    return this.passwordValue();
  }

  protected get passwordViolation(): string {
    this.generation();
    return this.store.violationFor(PASSWORD_FIELD);
  }

  protected get passwordInvalid(): 'true' | null {
    return this.passwordViolation === '' ? null : 'true';
  }

  protected get flagViews(): readonly FlagView[] {
    this.generation();
    const labels: Readonly<Record<FlagField, string>> = {
      DBEncIRISSecurity: STRINGS.encryptionStartupIrisSecurity,
      DBEncIRISTemp: STRINGS.encryptionStartupIrisTemp,
      DBEncJournal: STRINGS.encryptionStartupJournal,
      AuditEncrypt: STRINGS.encryptionStartupAudit,
    };
    const sentences: Readonly<Record<FlagField, string>> = {
      DBEncIRISSecurity: STRINGS.encryptionStartupRestart,
      DBEncIRISTemp: STRINGS.encryptionStartupRestart,
      DBEncJournal: STRINGS.encryptionStartupJournalConsequence,
      AuditEncrypt: STRINGS.encryptionStartupAuditConsequence,
    };
    return FLAG_FIELDS.map((field) => {
      const refusal = this.store.flagRefusal(field);
      const id = encryptionStartupControlId(field);
      const refused = refusal !== '';
      const violation = this.store.violationFor(field);
      const describedBy = [`${id}-sentence`, refused ? `${id}-reason` : ''].filter((entry) => entry !== '').join(' ');
      return {
        field,
        label: labels[field],
        sentence: sentences[field],
        id,
        sentenceId: `${id}-sentence`,
        checked: this.store.flag(field),
        refused,
        reason: refusalSentence(refusal),
        reasonId: `${id}-reason`,
        ariaDisabled: refused ? 'true' : null,
        describedBy,
        invalid: violation !== '',
        violation,
      };
    });
  }

  protected get keysRefused(): boolean {
    this.generation();
    return this.store.keyRefusal() !== '';
  }

  protected get keysAriaDisabled(): 'true' | null {
    return this.keysRefused ? 'true' : null;
  }

  protected get keysReason(): string {
    this.generation();
    return refusalSentence(this.store.keyRefusal());
  }

  protected get keyViews(): readonly KeyView[] {
    this.generation();
    const make = (field: string, label: string, hint: string, value: string): KeyView => {
      const id = encryptionStartupControlId(field);
      const violation = this.store.violationFor(field);
      const describedBy = [`${id}-hint`, this.keysRefused ? `${id}-reason` : ''].filter((entry) => entry !== '').join(' ');
      const options = this.store.activeKeys();
      // A value that is not among the active keys, or none active, reads "(none)".
      return { field, label, hint, id, hintId: `${id}-hint`, value, options, invalid: violation !== '', violation, describedBy, emptyOption: !options.includes(value) };
    };
    return [
      make(DEFAULT_KEY_FIELD, STRINGS.encryptionStartupDefaultKey, STRINGS.encryptionStartupDefaultKeyHint, this.store.defaultKey()),
      make(JOURNAL_KEY_FIELD, STRINGS.encryptionStartupJournalKey, STRINGS.encryptionStartupJournalKeyHint, this.store.journalKey()),
    ];
  }

  // --- intents ---------------------------------------------------------------------------------

  /**
   * A refused choice is never selected: its click -- which an arrow key in the group also fires -- is
   * cancelled, and the group's checked state is put back once the click has settled.
   */
  protected onModeClick(event: Event, view: ModeView): void {
    if (!view.refused) return;
    event.preventDefault();
    const group = (event.target as HTMLElement).closest('fieldset');
    const selected = this.store.mode();
    queueMicrotask(() => {
      for (const radio of Array.from(group?.querySelectorAll<HTMLInputElement>('input[type="radio"]') ?? [])) {
        radio.checked = radio.closest('[data-mode]')?.getAttribute('data-mode') === selected;
      }
    });
  }

  protected onModeChange(view: ModeView): void {
    if (view.refused) return;
    this.store.setMode(view.mode);
  }

  /** A refused checkbox is never checked: its click is cancelled and it stays as the store holds it. */
  protected onFlagClick(event: Event, view: FlagView): void {
    if (view.refused) {
      event.preventDefault();
      return;
    }
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setFlag(view.field, target.checked);
  }

  protected onKmip(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLSelectElement) this.store.setKmipServer(target.value);
  }

  protected onKey(field: string, event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLSelectElement)) return;
    if (this.keysRefused) {
      target.value = field === DEFAULT_KEY_FIELD ? this.store.defaultKey() : this.store.journalKey();
      return;
    }
    if (field === DEFAULT_KEY_FIELD) this.store.setDefaultKey(target.value);
    if (field === JOURNAL_KEY_FIELD) this.store.setJournalKey(target.value);
  }

  /** The new key file's location; the administrator name defaults to the signed-in user the first time. */
  protected onLocation(location: ServerPath): void {
    const first = !this.store.newKeyFile();
    this.store.setLocation(location.root, location.path);
    if (first && this.store.newKeyFile() && this.store.adminName() === '') this.store.setAdminName(this.session?.userName() ?? '');
  }

  protected onAdminName(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setAdminName(target.value);
  }

  protected onPassword(event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.passwordValue.set(target.value);
  }

  protected onRetry(): void {
    this.passwordValue.set('');
    void this.store.open();
  }

  /** Save; a change to the audit log's encryption asks for the typed name first. */
  protected async onSave(): Promise<void> {
    if (!this.store.canSave() || this.auditOpen()) return;
    if (this.store.auditChanged()) {
      this.auditOpen.set(true);
      return;
    }
    await this.send();
  }

  protected confirmAudit(): void {
    this.auditOpen.set(false);
    void this.send();
  }

  protected cancelAudit(): void {
    this.auditOpen.set(false);
  }

  protected focusField(field: string): void {
    const id = field === MODE_FIELD ? `${encryptionStartupControlId(MODE_FIELD)}-${this.store.mode()}` : field === ROOT_FIELD || field === PATH_FIELD ? `ocu-encryption-startup-location-${field}` : encryptionStartupControlId(field);
    document.getElementById(id)?.focus();
  }

  /** Cancel: the settings as the instance holds them, every unsaved change and the password dropped. */
  protected cancel(): void {
    this.passwordValue.set('');
    void this.store.open();
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  /** One Save; the password is handed over once and cleared whatever the answer (AD-35). */
  private async send(): Promise<void> {
    const password = this.passwordValue();
    this.passwordValue.set('');
    const saved = await this.store.save(password);
    if (!saved) this.afterRefusal();
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
