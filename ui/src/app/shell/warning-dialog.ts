import { ChangeDetectionStrategy, Component, ElementRef, computed, input, output, signal, viewChild } from '@angular/core';

import { STRINGS } from '../core/strings';
import { Dialog } from './dialog';

/** How many warning dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/** What Proceed answers: the checkbox's state and the field's value, each only where it is drawn. */
export interface WarningAnswer {
  readonly flag?: boolean;
  readonly value?: string;
}

/** A whole number of megabytes as the field takes it: digits only, surrounding space ignored. */
const WHOLE_NUMBER = /^[0-9]{1,9}$/;

/**
 * The warning before a non-delete write (EXPERIENCE.md `confirm-dialog`): the title is the verb,
 * the body is the consequence sentence the caller passes (a Fixed strings row), and the confirming
 * action is Proceed as a `button-primary` -- a warning, never a destructive treatment.
 *
 * **Three optional parts, each drawn only when the caller passes it** (Story 18.4). An advisory is
 * a second sentence -- the prohibited set's refusal of a protected database's dismount, read when
 * the dialog opens -- drawn as a warning banner, `data-slot="advisory"`, never a refusal: Proceed's
 * condition is unchanged, and whether the write may happen is the instance's answer. A flag is a
 * checkbox, `data-slot="flag"`, unchecked when the dialog opens (a mount's read-only). A field is one
 * whole-number input with its hint, `data-slot="field"`: while it does not hold a whole number,
 * Proceed is `aria-disabled` and names the hint as its reason, and a click on it does nothing.
 * `confirmed` carries `{flag, value}`, each only where it is drawn.
 *
 * Cancel is `dialog.ts`'s own dismissing action and takes initial focus where the surface holds no
 * field; the field, or the checkbox, takes it otherwise. Escape, Cancel and the scrim all emit
 * `cancelled`; the focus trap and the return to the opener are `dialog.ts`'s, unchanged.
 *
 * Every control-flow condition is paren-free, for the reason `proposal-card.ts` records.
 */
@Component({
  selector: 'app-warning-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="verb()" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <p class="ocu-warning-consequence">{{ consequence() }}</p>
    @if (advisoryVisible) {
      <p class="ocu-banner ocu-banner-warning ocu-warning-advisory" data-slot="advisory">
        <span class="ocu-banner-glyph" aria-hidden="true">{{ bannerGlyph }}</span>
        <span class="ocu-banner-message">{{ advisory() }}</span>
      </p>
    }
    @if (fieldVisible) {
      <div class="ocu-field" data-slot="field">
        <label class="ocu-field-label" [attr.for]="fieldId">{{ fieldLabel() }}</label>
        <div class="ocu-field-control">
          <input
            [id]="fieldId"
            class="ocu-field-input"
            type="text"
            inputmode="numeric"
            autocomplete="off"
            spellcheck="false"
            [attr.aria-describedby]="hintDescribedBy"
            [value]="typed()"
            (input)="onType($event)"
            (keydown.enter)="onEnter($event)"
          />
        </div>
        @if (hintVisible) {
          <p class="ocu-field-caption" [id]="hintId">{{ fieldHint() }}</p>
        }
      </div>
    }
    @if (flagVisible) {
      <label class="ocu-criteria-marker ocu-warning-flag" data-slot="flag">
        <input #flagInput type="checkbox" />
        {{ flagLabel() }}
      </label>
    }
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      [attr.aria-disabled]="proceedDisabled"
      [attr.aria-describedby]="proceedDescribedBy"
      (click)="onProceed()"
    >
      {{ STRINGS.actionProceed }}
    </button>
  </app-dialog>`,
})
export class WarningDialog {
  /** The verb this dialog confirms, already published copy ("Turn auditing off"). */
  readonly verb = input.required<string>();

  /** The consequence sentence, a Fixed strings row the caller resolves. */
  readonly consequence = input.required<string>();

  /** A second, published sentence for this target, or `''` for none. */
  readonly advisory = input('');

  /** The published label of an optional checkbox, or `''` for none. */
  readonly flagLabel = input('');

  /** The published label of an optional whole-number field, or `''` for none. */
  readonly fieldLabel = input('');

  /** The field's published hint, which is also Proceed's reason while the field holds no whole number. */
  readonly fieldHint = input('');

  /** Emitted once, when Proceed is pressed and released, with the checkbox's state and the field's value. */
  readonly confirmed = output<WarningAnswer>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  /** The warning triangle the shared banner carries, as its escape (Rule 14). */
  protected readonly bannerGlyph = '\u26A0';

  private readonly instance = ++dialogCount;

  protected readonly fieldId = `ocu-warning-field-${this.instance}`;

  protected readonly hintId = `ocu-warning-field-hint-${this.instance}`;

  private readonly flagInput = viewChild<ElementRef<HTMLInputElement>>('flagInput');

  /** What the field holds. */
  protected readonly typed = signal('');

  /** Whether the field, where drawn, holds a whole number. */
  private readonly whole = computed(() => WHOLE_NUMBER.test(this.typed().trim()));

  protected get advisoryVisible(): boolean {
    return this.advisory() !== '';
  }

  protected get flagVisible(): boolean {
    return this.flagLabel() !== '';
  }

  protected get fieldVisible(): boolean {
    return this.fieldLabel() !== '';
  }

  protected get hintVisible(): boolean {
    return this.fieldHint() !== '';
  }

  protected get hintDescribedBy(): string | null {
    return this.hintVisible ? this.hintId : null;
  }

  /** Released unless a drawn field holds no whole number. */
  protected get proceedDisabled(): string | null {
    return this.fieldVisible && !this.whole() ? 'true' : null;
  }

  /** The hint names why Proceed is unavailable while it is. */
  protected get proceedDescribedBy(): string | null {
    return this.proceedDisabled !== null && this.hintVisible ? this.hintId : null;
  }

  protected onType(event: Event): void {
    this.typed.set((event.target as HTMLInputElement).value);
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    this.onProceed();
  }

  protected onProceed(): void {
    if (this.proceedDisabled !== null) return;
    const answer: { flag?: boolean; value?: string } = {};
    if (this.flagVisible) answer.flag = this.flagInput()?.nativeElement.checked ?? false;
    if (this.fieldVisible) answer.value = this.typed().trim();
    this.confirmed.emit(answer);
  }
}
