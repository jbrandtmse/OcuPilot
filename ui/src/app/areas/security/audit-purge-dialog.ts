import { ChangeDetectionStrategy, Component, computed, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';

/** The most days a purge may reach back: four digits, as the classic page's own field allows. */
export const PURGE_MAX_DAYS = 9999;

/** A whole number of days the field accepts, 0 to `PURGE_MAX_DAYS`, or `null`. */
export function purgeDays(text: string): number | null {
  if (!/^\d{1,4}$/.test(text)) return null;
  const days = Number(text);
  return days <= PURGE_MAX_DAYS ? days : null;
}

/**
 * The purge's cut-off day, `YYYY-MM-DD`: `today` minus `days` on the local calendar. Every record
 * dated before that day's midnight is removed, and every record on or after it remains.
 */
export function purgeCutoff(days: number, today: Date): string {
  const day = new Date(today.getFullYear(), today.getMonth(), today.getDate() - days);
  const pad = (value: number, width: number): string => String(value).padStart(width, '0');
  return `${pad(day.getFullYear(), 4)}-${pad(day.getMonth() + 1, 2)}-${pad(day.getDate(), 2)}`;
}

/** How many purge dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * Purge the audit database (Story 12.3, EXPERIENCE.md `confirm-dialog`, `typed-name-field`,
 * `button-destructive`): a days field, the scope and cut-off line computed from it, and a field that
 * asks for the cut-off date before the destructive Purge will do anything.
 *
 * **`aria-disabled`, never `disabled`**, for the reason `typed-name-dialog.ts` records: the button
 * keeps its place in the Tab order, and its click is refused here until the typed text equals the
 * cut-off exactly. Changing the days moves the cut-off, so a date typed for another cut-off no
 * longer releases it. Purge emits the cut-off; Cancel, Escape and the scrim emit `cancelled`.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records.
 */
@Component({
  selector: 'app-audit-purge-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.auditDatabasePurgeTitle" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <div class="ocu-audit-database-field">
      <label class="ocu-typed-name-label" [attr.for]="daysId">{{ STRINGS.auditDatabasePurgeDays }}</label>
      <input
        [id]="daysId"
        class="ocu-typed-name-field"
        type="text"
        inputmode="numeric"
        autocomplete="off"
        data-audit-purge-days
        [attr.aria-invalid]="daysInvalid"
        [value]="daysText()"
        (input)="onDays($event)"
      />
    </div>
    @if (hasCutoff) {
      <p class="ocu-typed-name-consequence" data-audit-purge-consequence>{{ consequence() }}</p>
      <label class="ocu-typed-name-label" [attr.for]="typedId">{{ typedLabel() }}</label>
      <input
        [id]="typedId"
        class="ocu-typed-name-field"
        type="text"
        autocomplete="off"
        spellcheck="false"
        data-audit-purge-typed
        [value]="typed()"
        (input)="onType($event)"
        (keydown.enter)="onEnter($event)"
      />
    }
    <button
      dialogAction
      type="button"
      class="ocu-button-destructive"
      data-audit-purge-confirm
      [attr.aria-disabled]="confirmDisabled"
      (click)="onConfirm()"
    >
      {{ STRINGS.auditDatabasePurgeConfirm }}
    </button>
  </app-dialog>`,
})
export class AuditPurgeDialog {
  /** The day the cut-off is counted back from. The page passes the moment the dialog opened. */
  readonly today = input.required<Date>();

  /** Emitted once, when the typed date matches and Purge is taken, with the cut-off. */
  readonly confirmed = output<string>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly instance = ++dialogCount;

  protected readonly daysId = `ocu-audit-purge-days-${this.instance}`;

  protected readonly typedId = `ocu-audit-purge-typed-${this.instance}`;

  protected readonly daysText = signal('');

  protected readonly typed = signal('');

  /** The cut-off the days field names now, or `''` while it names no whole number in range. */
  protected readonly cutoff = computed(() => {
    const days = purgeDays(this.daysText());
    return days === null ? '' : purgeCutoff(days, this.today());
  });

  protected readonly consequence = computed(() => STRINGS.auditDatabasePurgeConsequence.split('<date>').join(this.cutoff()));

  protected readonly typedLabel = computed(() => STRINGS.formTypedNameConfirm.split('<name>').join(this.cutoff()));

  /** Exact: the cut-off as `purgeCutoff` writes it, and nothing else. */
  private readonly matches = computed(() => this.cutoff() !== '' && this.typed() === this.cutoff());

  protected get hasCutoff(): boolean {
    return this.cutoff() !== '';
  }

  protected get daysInvalid(): string | null {
    return this.daysText() !== '' && this.cutoff() === '' ? 'true' : null;
  }

  protected get confirmDisabled(): string | null {
    return this.matches() ? null : 'true';
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
    if (!this.matches()) return;
    this.confirmed.emit(this.cutoff());
  }
}
