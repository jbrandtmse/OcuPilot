import { ChangeDetectionStrategy, Component, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';

/** How many dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/** What the dialog hands its page: the support case number as typed and the statement as written. */
export interface ReportSaveValues {
  readonly wrc: string;
  readonly statement: string;
}

/**
 * SQL troubleshooting reports' Save query (Story 21.29): the support case number and the statement, under the consequence the action states.
 *
 * **It judges nothing but a blank statement.** The case number is sent as typed and the statement as written, and the instance refuses a case number that is
 * not a whole number of up to 9 digits and a statement that is not a query with its own sentence, which the page passes back as `refusal` and which stays in
 * the dialog. Proceed is `aria-disabled` while the statement is blank and while a send is in flight.
 */
@Component({
  selector: 'app-sql-report-save-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.sqlReportsSaveTitle" [closeLabel]="STRINGS.actionCancel" (closed)="onClosed()">
    <p class="ocu-warning-consequence" data-slot="consequence">{{ STRINGS.sqlReportsSaveConsequence }}</p>
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="fieldId('wrc')">{{ STRINGS.explorerSqlReportsColumnWrc }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            inputmode="numeric"
            autocomplete="off"
            spellcheck="false"
            aria-required="true"
            data-slot="wrc"
            [id]="fieldId('wrc')"
            [attr.aria-describedby]="fieldId('wrc-help')"
            [value]="wrc()"
            (input)="wrc.set(valueOf($event))"
          />
          <p class="ocu-field-caption" [id]="fieldId('wrc-help')">{{ STRINGS.sqlReportsWrcHelp }}</p>
        </div>
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="fieldId('statement')">{{ STRINGS.explorerSqlColumnStatement }}</label>
        <div class="ocu-field-control">
          <textarea
            class="ocu-field-input ocu-field-textarea"
            rows="6"
            spellcheck="false"
            aria-required="true"
            data-slot="statement"
            [id]="fieldId('statement')"
            [value]="statement()"
            (input)="statement.set(valueOf($event))"
          ></textarea>
        </div>
      </div>
    </div>
    @if (hasRefusal) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-slot="refusal">{{ refusal() }}</p>
    }
    <button dialogAction type="button" class="ocu-button-primary" data-slot="proceed" [attr.aria-disabled]="proceedDisabled" (click)="submit()">
      {{ STRINGS.actionProceed }}
    </button>
  </app-dialog>`,
})
export class SqlReportSaveDialog {
  /** A send is in flight. */
  readonly sending = input<boolean>(false);

  /** The instance's refusal sentence, or `''`. */
  readonly refusal = input<string>('');

  /** Emitted once per Proceed, with what was typed. */
  readonly submitted = output<ReportSaveValues>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly id = ++dialogCount;

  protected readonly wrc = signal('');

  protected readonly statement = signal('');

  private closed = false;

  protected get hasRefusal(): boolean {
    return this.refusal() !== '';
  }

  protected get proceedDisabled(): 'true' | null {
    return this.sending() || this.statement().trim() === '' ? 'true' : null;
  }

  protected fieldId(field: string): string {
    return `ocu-sql-report-${field}-${this.id}`;
  }

  protected valueOf(event: Event): string {
    return (event.target as HTMLInputElement | HTMLTextAreaElement).value;
  }

  /** Hand what was typed on once, while a statement is written and no send is in flight. */
  protected submit(): void {
    if (this.proceedDisabled !== null) return;
    this.submitted.emit({ wrc: this.wrc().trim(), statement: this.statement() });
  }

  protected onClosed(): void {
    if (this.closed) return;
    this.closed = true;
    this.cancelled.emit();
  }
}
