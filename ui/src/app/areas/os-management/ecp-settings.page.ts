import { ChangeDetectionStrategy, Component, DestroyRef, ElementRef, Injector, afterNextRender, inject, signal, viewChild } from '@angular/core';

import { FormDirty } from '../../core/form-dirty';
import { formatDeniedAction } from '../../core/navigation';
import { savedLine } from '../../core/read-back';
import { STRINGS } from '../../core/strings';
import type { Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { APP_GROUP, DATA_GROUP, EcpSettingsForm, RESTART_FIELD, SSL_CHOICES, SSL_FIELD } from './ecp-settings.store';

/** The machine code a privilege denial carries (AD-39). Never the envelope's human reason. */
const NO_PRIVILEGE_CODE = 'AUTH.NOPRIVILEGE';

/** Each field's control id. */
export function ecpSettingsControlId(field: string): string {
  return `ocu-ecp-settings-${field.replace('.', '-')}`;
}

/** The id of the restart hint, which the maximum number of application servers is described by. */
export const RESTART_HINT_ID = 'ocu-ecp-settings-restart-hint';

/** One number field, resolved for drawing. */
interface NumberView {
  readonly field: string;
  readonly label: string;
  readonly id: string;
  readonly value: string;
  readonly reason: string;
  readonly invalid: boolean;
  readonly describedBy: string | null;
  readonly restart: boolean;
}

/** One SSL/TLS support choice, resolved for drawing. */
interface ChoiceView {
  readonly value: number;
  readonly label: string;
  readonly id: string;
  readonly checked: boolean;
  readonly refused: boolean;
  readonly reasonId: string;
  readonly ariaDisabled: 'true' | null;
  readonly describedBy: string | null;
}

/**
 * ECP settings (Story 18.21, SA-ECP, AD-55): OS management's eighteenth entry, the `form-page` on
 * `os-management/ecp-settings`, over the screen's own declared read and `GET /ecp-settings/form`.
 *
 * **One form, two fieldsets.** "This instance as an ECP application server" holds the maximum number of
 * data servers and the two recovery times; "This instance as an ECP data server" holds the maximum
 * number of application servers, whose hint is the restart sentence, the Troubled state's interval, and
 * ECP SSL/TLS support as Disabled, Enabled and Required, the last two drawn `aria-disabled` with the
 * `%ECPServer` sentence unless that configuration is enabled -- focusable, never selectable. The license
 * line shows while the license lacks ECP. The sticky Save sends only the changed members, nested; after a
 * Save that changed the maximum number of application servers the restart sentence shows beside the
 * saved line, and nothing claims the change applied.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-ecp-settings-page',
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
    @if (faultFlag) {
      <div class="ocu-data-table-refusal" role="alert">
        <span class="ocu-data-table-refusal-message">{{ STRINGS.connectivityRequestRefused }}</span>
        <button type="button" class="ocu-button-text" (click)="onRetry()">{{ STRINGS.actionRetry }}</button>
      </div>
    }

    @if (heldFlag) {
    @if (unlicensed) {
      <p class="ocu-field-caption" data-slot="license-line">{{ STRINGS.ecpLicenseRefusal }}</p>
    }
    <fieldset class="ocu-form-fields ocu-field" data-group="app-server">
      <legend class="ocu-field-label">{{ STRINGS.ecpSettingsAppServerLegend }}</legend>
      @for (view of appViews; track view.field) {
        <div class="ocu-field" [attr.data-field]="view.field">
          <label class="ocu-field-label" [attr.for]="view.id">{{ view.label }}</label>
          <div class="ocu-field-control">
            <input
              class="ocu-field-input"
              type="text"
              inputmode="numeric"
              autocomplete="off"
              [id]="view.id"
              [value]="view.value"
              [attr.aria-invalid]="view.invalid"
              [attr.aria-describedby]="view.describedBy"
              (input)="onText(view.field, $event)"
            />
          </div>
          @if (view.invalid) {
            <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
          }
        </div>
      }
    </fieldset>

    <fieldset class="ocu-form-fields ocu-field" data-group="data-server">
      <legend class="ocu-field-label">{{ STRINGS.ecpSettingsDataServerLegend }}</legend>
      @for (view of dataViews; track view.field) {
        <div class="ocu-field" [attr.data-field]="view.field">
          <label class="ocu-field-label" [attr.for]="view.id">{{ view.label }}</label>
          <div class="ocu-field-control">
            <input
              class="ocu-field-input"
              type="text"
              inputmode="numeric"
              autocomplete="off"
              [id]="view.id"
              [value]="view.value"
              [attr.aria-invalid]="view.invalid"
              [attr.aria-describedby]="view.describedBy"
              (input)="onText(view.field, $event)"
            />
          </div>
          @if (view.restart) {
            <p class="ocu-field-caption" [id]="restartHintId" data-slot="restart-hint">{{ STRINGS.ecpSettingsRestart }}</p>
          }
          @if (view.invalid) {
            <p class="ocu-form-error" [id]="view.id + '-reason'">{{ view.reason }}</p>
          }
        </div>
      }
      <fieldset class="ocu-field ocu-form-authe ocu-ecp-settings-ssl" [attr.data-field]="sslField">
        <legend class="ocu-field-label">{{ STRINGS.ecpSettingsSslSupport }}</legend>
        @for (choice of sslViews; track choice.value) {
          <label class="ocu-field-checkbox" [attr.data-ssl]="choice.value">
            <input
              type="radio"
              name="ocu-ecp-settings-ssl"
              [id]="choice.id"
              [checked]="choice.checked"
              [attr.aria-disabled]="choice.ariaDisabled"
              [attr.aria-describedby]="choice.describedBy"
              (click)="onSslClick($event, choice)"
              (change)="onSslChange(choice)"
            />
            <span>{{ choice.label }}</span>
          </label>
          @if (choice.refused) {
            <p class="ocu-field-caption" [id]="choice.reasonId" data-slot="ssl-reason">{{ STRINGS.ecpSettingsServerSsl }}</p>
          }
        }
        @if (sslInvalid) {
          <p class="ocu-form-error" [id]="sslReasonId">{{ sslReason }}</p>
        }
      </fieldset>
    </fieldset>
    }

    @if (loadedFlag) {
    <div class="ocu-form-bar">
      <div class="ocu-form-bar-status">
        @if (showSaved) {
          <span role="status">{{ savedText }}</span>
        }
        @if (showRestart) {
          <span role="status" data-slot="restart-line">{{ STRINGS.ecpSettingsRestart }}</span>
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
      <app-dialog [heading]="STRINGS.formLeaveWithoutSaving" [closeLabel]="STRINGS.actionCancel" (closed)="answerLeave(false)">
        <button dialogAction type="button" class="ocu-button-primary" (click)="answerLeave(true)">
          {{ STRINGS.actionConfirm }}
        </button>
      </app-dialog>
    }
  </section>`,
})
export class EcpSettingsPage {
  private readonly store = inject(EcpSettingsForm);
  private readonly formDirty = inject(FormDirty);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  protected readonly restartHintId = RESTART_HINT_ID;

  protected readonly sslField = SSL_FIELD;

  protected readonly sslReasonId = `${ecpSettingsControlId(SSL_FIELD)}-reason`;

  /** Bumped by the stores, so the template re-reads them under `OnPush`. */
  private readonly generation = signal(0);

  private readonly summary = viewChild<ElementRef<HTMLElement>>('summary');

  private focusedSummary = false;

  constructor() {
    const stopStore = this.store.subscribe(() => this.bump());
    const stopDirty = this.formDirty.subscribe(() => this.bump());
    void this.store.open();
    inject(DestroyRef).onDestroy(() => {
      stopStore();
      stopDirty();
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

  protected get unlicensed(): boolean {
    this.generation();
    return !this.store.licensed();
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
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.ecpSettingsRefusedAction);
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

  protected get showRestart(): boolean {
    this.generation();
    return this.store.saved() && this.store.restartPending();
  }

  protected get savedText(): string {
    this.generation();
    return savedLine(this.store.readBack());
  }

  protected get leavePending(): boolean {
    this.generation();
    return this.formDirty.pending();
  }

  protected get appViews(): readonly NumberView[] {
    return [
      this.numberView(`${APP_GROUP}.MaxServers`, STRINGS.ecpSettingsMaxServers),
      this.numberView(`${APP_GROUP}.ClientReconnectDuration`, STRINGS.ecpSettingsReconnectDuration),
      this.numberView(`${APP_GROUP}.ClientReconnectInterval`, STRINGS.ecpSettingsReconnectInterval),
    ];
  }

  protected get dataViews(): readonly NumberView[] {
    return [
      this.numberView(RESTART_FIELD, STRINGS.ecpSettingsMaxServerConn),
      this.numberView(`${DATA_GROUP}.ServerTroubleDuration`, STRINGS.ecpSettingsTroubleDuration),
    ];
  }

  protected get sslViews(): readonly ChoiceView[] {
    this.generation();
    const labels: Readonly<Record<number, string>> = {
      0: STRINGS.agentGovernanceDisabled,
      1: STRINGS.tableColumnEnabled,
      2: STRINGS.openApiRequired,
    };
    const base = ecpSettingsControlId(SSL_FIELD);
    return SSL_CHOICES.map((value) => {
      const refused = this.store.sslRefusal(value) !== '';
      const reasonId = `${base}-${value}-reason`;
      const describedBy = [refused ? reasonId : null, this.sslInvalid ? this.sslReasonId : null].filter((entry): entry is string => entry !== null);
      return {
        value,
        label: labels[value] ?? '',
        id: `${base}-${value}`,
        checked: this.store.ssl() === value,
        refused,
        reasonId,
        ariaDisabled: refused ? 'true' : null,
        describedBy: describedBy.length === 0 ? null : describedBy.join(' '),
      };
    });
  }

  protected get sslReason(): string {
    this.generation();
    return this.store.violationFor(SSL_FIELD);
  }

  protected get sslInvalid(): boolean {
    return this.sslReason !== '';
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onText(field: string, event: Event): void {
    const target = event.target;
    if (target instanceof HTMLInputElement) this.store.setText(field, target.value);
  }

  /**
   * A refused choice is never selected: its click -- which an arrow key in the group also fires -- is
   * cancelled, and the group's checked state is put back once the click has settled.
   */
  protected onSslClick(event: Event, choice: ChoiceView): void {
    if (!choice.refused) return;
    event.preventDefault();
    const group = (event.target as HTMLElement).closest('fieldset');
    const selected = this.store.ssl();
    queueMicrotask(() => {
      for (const radio of Array.from(group?.querySelectorAll<HTMLInputElement>('input[type="radio"]') ?? [])) {
        radio.checked = radio.closest('[data-ssl]')?.getAttribute('data-ssl') === String(selected);
      }
    });
  }

  protected onSslChange(choice: ChoiceView): void {
    if (choice.refused) return;
    this.store.setSsl(choice.value);
  }

  protected onRetry(): void {
    void this.store.open();
  }

  protected async onSave(): Promise<void> {
    if (!this.store.canSave()) return;
    const saved = await this.store.save();
    if (!saved) this.afterRefusal();
  }

  protected focusField(field: string): void {
    const id = field === SSL_FIELD ? `${ecpSettingsControlId(SSL_FIELD)}-${this.store.ssl()}` : ecpSettingsControlId(field);
    document.getElementById(id)?.focus();
  }

  /** Cancel: the settings as the instance holds them, every unsaved change dropped. */
  protected cancel(): void {
    void this.store.open();
  }

  protected answerLeave(leave: boolean): void {
    this.formDirty.answer(leave);
  }

  // --- internals -------------------------------------------------------------------------------

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  private numberView(field: string, label: string): NumberView {
    this.generation();
    const id = ecpSettingsControlId(field);
    const reason = this.store.violationFor(field);
    const invalid = reason !== '';
    const restart = field === RESTART_FIELD;
    const described = [restart ? RESTART_HINT_ID : null, invalid ? `${id}-reason` : null].filter((entry): entry is string => entry !== null);
    return { field, label, id, value: this.store.text(field), reason, invalid, describedBy: described.length === 0 ? null : described.join(' '), restart };
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
