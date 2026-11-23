import { ChangeDetectionStrategy, Component, computed, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';

/** The most days a purge may keep: five digits, as the server judges them (`INTEROP.PURGE.DAYS`). */
export const PURGE_MAX_DAYS = 99999;

/** The days the field names, a whole number from 0 to `PURGE_MAX_DAYS` written without a sign or a leading zero, or `null`. */
export function purgeKeepDays(text: string): number | null {
  if (!/^(0|[1-9]\d{0,4})$/.test(text)) return null;
  const days = Number(text);
  return days <= PURGE_MAX_DAYS ? days : null;
}

/** The three settings and the description a purge will use, as the review of the purge answered them. */
export interface PurgeSettingsView {
  readonly bodies: boolean;
  readonly integrity: boolean;
  readonly bitmap: boolean;
  readonly description: string;
}

/** How many purge dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * Purge management data (Story 24.16, EXPERIENCE.md `confirm-dialog`, `typed-name-field`, `button-destructive`): the three settings the purge
 * will use and the namespace's description, shown as text and never run, the consequence sentence, a days field, and a field that asks for the
 * namespace's name before the destructive Purge will do anything.
 *
 * **`aria-disabled`, never `disabled`**, for the reason `typed-name-dialog.ts` records: the button keeps its place in the Tab order and its
 * click is refused here until the days are a whole number from 0 to 99999 and the typed text equals the namespace exactly. Purge emits the
 * days as text; Cancel, Escape and the scrim emit `cancelled`. A refusal the page passes stays in the dialog, on the days field where the
 * instance names it.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-interop-purge-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.auditDatabasePurgeConfirm" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <p class="ocu-typed-name-consequence" data-interop-purge-consequence>{{ consequence }}</p>
    <ul data-interop-purge-settings>
      <li data-interop-purge-setting="bodies">{{ bodiesLine }}</li>
      <li data-interop-purge-setting="integrity">{{ integrityLine }}</li>
      <li data-interop-purge-setting="bitmap">{{ bitmapLine }}</li>
      @if (hasDescription) {
        <li data-interop-purge-setting="description">{{ descriptionLine }}</li>
      }
    </ul>
    <div class="ocu-audit-database-field">
      <label class="ocu-typed-name-label" [attr.for]="daysId">{{ STRINGS.auditDatabasePurgeDays }}</label>
      <input
        [id]="daysId"
        class="ocu-typed-name-field"
        type="text"
        inputmode="numeric"
        autocomplete="off"
        data-interop-purge-days
        [attr.aria-invalid]="daysInvalid"
        [value]="daysText()"
        (input)="onDays($event)"
      />
    </div>
    @if (hasViolation) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-interop-purge-violation>{{ violation() }}</p>
    }
    <label class="ocu-typed-name-label" [attr.for]="typedId">{{ typedLabel }}</label>
    <input
      [id]="typedId"
      class="ocu-typed-name-field"
      type="text"
      autocomplete="off"
      spellcheck="false"
      data-interop-purge-typed
      [value]="typed()"
      (input)="onType($event)"
      (keydown.enter)="onEnter($event)"
    />
    @if (hasRefusal) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-interop-purge-refusal>{{ refusal() }}</p>
    }
    <button
      dialogAction
      type="button"
      class="ocu-button-destructive"
      data-interop-purge-confirm
      [attr.aria-disabled]="confirmDisabled"
      (click)="onConfirm()"
    >
      {{ STRINGS.auditDatabasePurgeConfirm }}
    </button>
  </app-dialog>`,
})
export class InteropPurgeDialog {
  /** The namespace the purge acts in, which the person types to confirm. */
  readonly namespace = input.required<string>();

  /** The settings the review answered. */
  readonly settings = input.required<PurgeSettingsView>();

  /** A refusal the instance gave that names no field, and the sentence it gave the days field. */
  readonly refusal = input<string>('');

  readonly violation = input<string>('');

  /** Whether a send is in flight, which holds Purge. */
  readonly sending = input<boolean>(false);

  /** Emitted once per Purge taken, with the days as text. */
  readonly confirmed = output<string>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly instance = ++dialogCount;

  protected readonly daysId = `ocu-interop-purge-days-${this.instance}`;

  protected readonly typedId = `ocu-interop-purge-typed-${this.instance}`;

  protected readonly daysText = signal('');

  protected readonly typed = signal('');

  /** Exact: the namespace's name and nothing else, with a whole number of days. */
  private readonly matches = computed(() => purgeKeepDays(this.daysText()) !== null && this.typed() === this.namespace());

  /** The consequence the settings give the purge: the cleanup's sentence when bitmap cleanup is on. */
  protected get consequence(): string {
    return this.settings().bitmap ? STRINGS.interopPurgeBitmapConsequence : STRINGS.interopPurgeRunConsequence;
  }

  protected get hasDescription(): boolean {
    return this.settings().description !== '';
  }

  protected get hasViolation(): boolean {
    return this.violation() !== '';
  }

  protected get hasRefusal(): boolean {
    return this.refusal() !== '';
  }

  /** One setting as a line: its caption, a colon and its value. */
  private line(caption: string, value: string): string {
    return `${caption}: ${value}`;
  }

  protected get bodiesLine(): string {
    return this.line(STRINGS.interopPurgeSettingBodies, this.yesNo(this.settings().bodies));
  }

  protected get integrityLine(): string {
    return this.line(STRINGS.interopPurgeSettingIntegrity, this.yesNo(this.settings().integrity));
  }

  protected get bitmapLine(): string {
    return this.line(STRINGS.interopPurgeSettingBitmap, this.yesNo(this.settings().bitmap));
  }

  protected get descriptionLine(): string {
    return this.line(STRINGS.tableColumnDescription, this.settings().description);
  }

  protected get typedLabel(): string {
    return STRINGS.formTypedNameConfirm.split('<name>').join(this.namespace());
  }

  protected get daysInvalid(): string | null {
    return this.daysText() !== '' && purgeKeepDays(this.daysText()) === null ? 'true' : null;
  }

  protected get confirmDisabled(): string | null {
    return this.matches() && !this.sending() ? null : 'true';
  }

  protected yesNo(value: boolean): string {
    return value ? STRINGS.tableStatusYes : STRINGS.tableStatusNo;
  }

  protected onDays(event: Event): void {
    this.daysText.set((event.target as HTMLInputElement).value);
  }

  protected onType(event: Event): void {
    this.typed.set((event.target as HTMLInputElement).value);
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    this.onConfirm();
  }

  protected onConfirm(): void {
    if (!this.matches() || this.sending()) return;
    this.confirmed.emit(this.daysText());
  }
}
