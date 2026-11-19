import { ChangeDetectionStrategy, Component, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';

/** The nine lists a table is added to, in the order the classic editor shows them, and the one that holds input/output tables. */
export const LOCALE_TABLE_LISTS: readonly string[] = [
  'PatternTables',
  'IdentifierTables',
  'UpperCaseTables',
  'LowerCaseTables',
  'TitleCaseTables',
  'AccentTables',
  'CollationTables',
  'XYTables',
  'XLTTables',
];
export const LOCALE_IO_LIST = 'XLTTables';

/** What the dialog hands its page: the row the table will be, `<list>:<table>`, and the two sides of an input/output table (`''` for the others). */
export interface LocaleTableValues {
  readonly name: string;
  readonly inputFrom: string;
  readonly outputTo: string;
}

/** How many dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * Locale properties' Add table (Story 21.16, AD-53): the list a table joins, its name, and, for the input/output list alone, the two character sets it
 * translates between.
 *
 * **It composes no rule of its own.** The page sends the row, `<list>:<table>`, to the instance, which judges it; every sentence a refusal shows is the
 * server's, drawn above the fields. The button is `aria-disabled` while a name is blank, an input/output table lacks a side, or a send is in flight.
 */
@Component({
  selector: 'app-locale-table-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="STRINGS.localeAddTableAction" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    @if (refusalText) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-locale-table-reason>{{ refusalText }}</p>
    }
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="fieldId('list')">{{ STRINGS.tableColumnType }}</label>
        <div class="ocu-field-control">
          <select class="ocu-field-input" data-locale-table-field="Type" [id]="fieldId('list')" (change)="list.set(valueOf($event))">
            @for (option of lists; track option) {
              <option [value]="option" [selected]="option === list()">{{ option }}</option>
            }
          </select>
        </div>
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="fieldId('table')">{{ STRINGS.interopLookupFieldTable }}</label>
        <div class="ocu-field-control">
          <input
            class="ocu-field-input"
            type="text"
            autocomplete="off"
            spellcheck="false"
            aria-required="true"
            data-locale-table-field="Table"
            [id]="fieldId('table')"
            [value]="table()"
            (input)="table.set(valueOf($event))"
          />
        </div>
      </div>
      @if (isIo) {
        <div class="ocu-field">
          <label class="ocu-field-label ocu-field-label-required" [attr.for]="fieldId('input')">{{ STRINGS.interopTransformInputLabel }}</label>
          <div class="ocu-field-control">
            <input class="ocu-field-input" type="text" autocomplete="off" spellcheck="false" aria-required="true" data-locale-table-field="InputFrom" [id]="fieldId('input')" [value]="inputFrom()" (input)="inputFrom.set(valueOf($event))" />
          </div>
        </div>
        <div class="ocu-field">
          <label class="ocu-field-label ocu-field-label-required" [attr.for]="fieldId('output')">{{ STRINGS.explorerOutputLabel }}</label>
          <div class="ocu-field-control">
            <input class="ocu-field-input" type="text" autocomplete="off" spellcheck="false" aria-required="true" data-locale-table-field="OutputTo" [id]="fieldId('output')" [value]="outputTo()" (input)="outputTo.set(valueOf($event))" />
          </div>
        </div>
      }
    </div>
    <button dialogAction type="button" class="ocu-button-primary" data-locale-table-confirm [attr.aria-disabled]="confirmDisabled" (click)="onConfirm()">
      {{ STRINGS.localeAddTableAction }}
    </button>
  </app-dialog>`,
})
export class LocaleTableDialog {
  /** The instance's refusal of the last attempt, which the page draws above the fields, or `''`. */
  readonly refusal = input('');

  /** Whether a send is in flight, which holds the button. */
  readonly sending = input(false);

  /** Emitted with what was typed when the button is pressed with the fields the list needs. */
  readonly submitted = output<LocaleTableValues>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly lists = LOCALE_TABLE_LISTS;

  private readonly id = ++dialogCount;

  protected readonly list = signal(LOCALE_TABLE_LISTS[0] ?? '');

  protected readonly table = signal('');

  protected readonly inputFrom = signal('');

  protected readonly outputTo = signal('');

  protected get refusalText(): string {
    return this.refusal();
  }

  protected get isIo(): boolean {
    return this.list() === LOCALE_IO_LIST;
  }

  protected get confirmDisabled(): 'true' | null {
    if (this.table().trim() === '' || this.sending()) return 'true';
    if (this.isIo && (this.inputFrom().trim() === '' || this.outputTo().trim() === '')) return 'true';
    return null;
  }

  protected fieldId(field: string): string {
    return `ocu-locale-table-${field}-${this.id}`;
  }

  protected valueOf(event: Event): string {
    return (event.target as HTMLInputElement | HTMLSelectElement).value;
  }

  protected onConfirm(): void {
    if (this.confirmDisabled !== null) return;
    this.submitted.emit({
      name: `${this.list()}:${this.table().trim()}`,
      inputFrom: this.isIo ? this.inputFrom().trim() : '',
      outputTo: this.isIo ? this.outputTo().trim() : '',
    });
  }
}
