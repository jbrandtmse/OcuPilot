import { ChangeDetectionStrategy, Component, computed, input, output } from '@angular/core';

import { STRINGS } from '../core/strings';
import { Dialog } from './dialog';

/**
 * What a reviewed action did (Story 20.31, AD-53): the report that follows a confirmed resend, or an edit and resend, in place of the
 * review the person confirmed from. It is not a question, so its one action is the dialog's own Close.
 *
 * **It draws the instance's words and nothing else.** A sent action lists the line the instance answered for each message --
 * `<id>: resent as <new>`, or `<id>: not resent: <reason>` -- as a list of text; a refused one draws the sentence it was refused with
 * as an alert, in the shared warning banner's shape, and no list. Every line is interpolated text, never markup.
 *
 * Every control-flow condition is paren-free, for the reason `proposal-card.ts` records.
 */
@Component({
  selector: 'app-outcome-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading()" [closeLabel]="STRINGS.auditDialogClose" (closed)="closed.emit()">
    @if (hasRefusal) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-ocu-outcome-refusal>
        <span class="ocu-banner-glyph" aria-hidden="true">{{ bannerGlyph }}</span>
        <span class="ocu-banner-message">{{ refusal() }}</span>
      </p>
    }
    @if (hasLines) {
      <ul class="ocu-dialog-review" role="status" data-ocu-outcome>
        @for (entry of lineList; track entry.index) {
          <li>{{ entry.text }}</li>
        }
      </ul>
    }
  </app-dialog>`,
})
export class OutcomeDialog {
  /** The dialog's title: the action and what it was about. */
  readonly heading = input.required<string>();

  /** The line the instance answered for each message, or none. */
  readonly lines = input<readonly string[]>([]);

  /** The sentence the instance refused the action with, or `''` for an action it sent. */
  readonly refusal = input('');

  /** Emitted on every dismissal path: Close, Escape and the scrim. */
  readonly closed = output<void>();

  protected readonly STRINGS = STRINGS;

  /** The lines with their positions, which keys each list item (two messages may answer the same line). */
  protected readonly entries = computed(() => this.lines().map((text, index) => ({ index, text })));

  /** The warning triangle the shared banner carries, as its escape (Rule 14). */
  protected readonly bannerGlyph = '\u26A0';

  /** The entries as a member, for the template's loop (`client-lint`'s blanker reads a loop's source up to its first closing parenthesis). */
  protected get lineList(): readonly { readonly index: number; readonly text: string }[] {
    return this.entries();
  }

  protected get hasRefusal(): boolean {
    return this.refusal() !== '';
  }

  protected get hasLines(): boolean {
    return this.lines().length > 0;
  }
}
