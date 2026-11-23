import { ChangeDetectionStrategy, Component, computed, input, output, signal } from '@angular/core';

import { pickCount } from '../../core/count-phrase';
import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';

/** What the person chose: the separator between messages and the character set the file is written in. */
export interface MessageExportChoice {
  readonly separator: string;
  readonly charset: string;
}

/** How many export dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * Messages' Export dialog (Story 24.16 Batch 3, EXPERIENCE.md `confirm-dialog`, `button-primary`): titled by the count of checked messages, the lines of the
 * review that say what each message would do, the consequence sentence, two lists -- the separator between messages and the character set -- and a primary
 * Export beside Cancel. The review was made by the page before the dialog opened; the lists and what they preselect are the instance's own, carried by it.
 *
 * **`aria-disabled`, never `disabled`**, for the reason `typed-name-dialog.ts` records: Export keeps its place in the Tab order, and its click is refused here
 * while a send is in flight. Export emits the two choices; Cancel, Escape and the scrim emit `cancelled`. A refusal the page passes stays in the dialog.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-interop-message-export-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <p class="ocu-banner" data-interop-export-consequence>{{ STRINGS.interopMessageExportConsequence }}</p>
    <ul class="ocu-dialog-review" data-interop-export-lines>
      @for (entry of lineList; track entry.index) {
        <li data-interop-export-line>{{ entry.text }}</li>
      }
    </ul>
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="separatorId">{{ STRINGS.interopMessageExportSeparator }}</label>
        <div class="ocu-field-control">
          <select class="ocu-field-input" data-interop-export-separator [id]="separatorId" (change)="onSeparator($event)">
            @for (name of separatorList; track name) {
              <option [value]="name" [selected]="name === separatorChosen()">{{ name }}</option>
            }
          </select>
        </div>
      </div>
      <div class="ocu-field">
        <label class="ocu-field-label" [attr.for]="charsetId">{{ STRINGS.interopMessageExportCharset }}</label>
        <div class="ocu-field-control">
          <select class="ocu-field-input" data-interop-export-charset [id]="charsetId" (change)="onCharset($event)">
            @for (name of charsetList; track name) {
              <option [value]="name" [selected]="name === charsetChosen()">{{ name }}</option>
            }
          </select>
        </div>
      </div>
    </div>
    @if (hasRefusal) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-interop-export-refusal>{{ refusal() }}</p>
    }
    <button dialogAction type="button" class="ocu-button-primary" data-interop-export-confirm [attr.aria-disabled]="confirmDisabled" (click)="onConfirm()">
      {{ STRINGS.taskExportAction }}
    </button>
  </app-dialog>`,
})
export class InteropMessageExportDialog {
  /** How many messages the export names: the checked rows. */
  readonly count = input.required<number>();

  /** The review's lines, one for each message, in the words the instance sent. */
  readonly lines = input<readonly string[]>([]);

  /** The separators and character sets the instance lists, and the one of each it preselects. */
  readonly separators = input<readonly string[]>([]);

  readonly charsets = input<readonly string[]>([]);

  readonly separator = input<string>('');

  readonly charset = input<string>('');

  /** A refusal the instance gave that the dialog shows. */
  readonly refusal = input<string>('');

  /** Whether a send is in flight, which holds Export. */
  readonly sending = input<boolean>(false);

  /** Emitted once per Export taken, with the two choices. */
  readonly confirmed = output<MessageExportChoice>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly instance = ++dialogCount;

  protected readonly separatorId = `ocu-interop-export-separator-${this.instance}`;

  protected readonly charsetId = `ocu-interop-export-charset-${this.instance}`;

  private readonly separatorPicked = signal<string | null>(null);

  private readonly charsetPicked = signal<string | null>(null);

  protected readonly separatorChosen = computed(() => this.separatorPicked() ?? this.separator());

  protected readonly charsetChosen = computed(() => this.charsetPicked() ?? this.charset());

  /** The review's lines with their positions, which keys each list item (two lines may read alike). */
  protected get lineList(): readonly { readonly index: number; readonly text: string }[] {
    return this.lines().map((text, index) => ({ index, text }));
  }

  protected get separatorList(): readonly string[] {
    return this.separators();
  }

  protected get charsetList(): readonly string[] {
    return this.charsets();
  }

  /** "Export <n> messages", or "Export 1 message" for one. */
  protected get heading(): string {
    const count = this.count();
    return pickCount(count, STRINGS.interopMessageExportTitleOne, STRINGS.interopMessageExportTitle.split('<n>').join(String(count)));
  }

  protected get hasRefusal(): boolean {
    return this.refusal() !== '';
  }

  protected get confirmDisabled(): string | null {
    return this.sending() ? 'true' : null;
  }

  protected onSeparator(event: Event): void {
    this.separatorPicked.set((event.target as HTMLSelectElement).value);
  }

  protected onCharset(event: Event): void {
    this.charsetPicked.set((event.target as HTMLSelectElement).value);
  }

  protected onConfirm(): void {
    if (this.sending()) return;
    this.confirmed.emit({ separator: this.separatorChosen(), charset: this.charsetChosen() });
  }
}
