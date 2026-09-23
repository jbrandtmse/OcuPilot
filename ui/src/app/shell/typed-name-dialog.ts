import { ChangeDetectionStrategy, Component, ElementRef, computed, input, output, signal, viewChild } from '@angular/core';

import { STRINGS } from '../core/strings';
import { Dialog } from './dialog';

/** How many typed-name dialogs have been constructed, which makes each one's field ids its own. */
let dialogCount = 0;

/**
 * The destructive confirm dialog (EXPERIENCE.md `confirm-dialog`, `typed-name-field`,
 * `button-destructive`): title naming the action and the target, a body stating the consequence,
 * and a field that asks for the target's name before the destructive button will do anything.
 *
 * **What it owns, and why each part is published rather than invented.** The title is the verb and
 * the target; the body is the consequence sentence the caller passes, which is a Fixed strings row;
 * the field's label is `formTypedNameConfirm` with the target resolved into it; a mismatch on blur
 * reads `formTypedNameMismatch` with `aria-invalid` and the message in `aria-describedby`; and the
 * action button is `button-destructive`, labeled with the same verb and target, `aria-disabled`
 * until the typed name matches **exactly, case-sensitively**.
 *
 * **`aria-disabled`, never `disabled`.** A gated control keeps its place in the Tab order and keeps
 * announcing why (EXPERIENCE.md, Privilege Gating), so the button is always focusable and its click
 * is refused by this component while the name does not match.
 *
 * **An advisory is a second sentence, drawn only when the caller passes one** -- a delete that is
 * still offered but carries a consequence the first sentence does not state (a system task's).
 * It is a warning banner, `data-slot="advisory"`, never a refusal: the button's condition is
 * unchanged.
 *
 * **A flag is an optional checkbox, drawn only when the caller passes its label** -- Terminate's
 * error-to-job flag, `data-slot="flag"`, unchecked when the dialog opens. It changes which write is
 * sent, never the button's condition, and `confirmed` carries its state (`false` when none is
 * drawn).
 *
 * Every control-flow condition is paren-free, for the reason `proposal-card.ts` records.
 *
 * **Enter submits only once the name matches**, which is the same condition the button is released
 * under -- one predicate, so the keyboard and the pointer cannot disagree.
 *
 * Everything else -- the focus trap, initial focus on the first field, Escape through the one
 * overlay authority, and focus returning to the opener -- is `dialog.ts`'s, unchanged. This
 * component renders inside it and adds no second modal surface.
 */
@Component({
  selector: 'app-typed-name-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `<app-dialog [heading]="heading()" [closeLabel]="STRINGS.actionCancel" (closed)="cancelled.emit()">
    <p class="ocu-typed-name-consequence">{{ consequence() }}</p>
    @if (advisoryVisible) {
      <p class="ocu-banner ocu-banner-warning ocu-typed-name-advisory" data-slot="advisory">
        <span class="ocu-banner-glyph" aria-hidden="true">{{ bannerGlyph }}</span>
        <span class="ocu-banner-message">{{ advisory() }}</span>
      </p>
    }
    <label class="ocu-typed-name-label" [attr.for]="fieldId">{{ fieldLabel() }}</label>
    <input
      [id]="fieldId"
      class="ocu-typed-name-field"
      type="text"
      autocomplete="off"
      spellcheck="false"
      [attr.aria-invalid]="invalid"
      [attr.aria-describedby]="describedBy"
      [value]="typed()"
      (input)="onType($event)"
      (blur)="onBlur()"
      (keydown.enter)="onEnter($event)"
    />
    @if (flagVisible) {
      <label class="ocu-criteria-marker ocu-typed-name-flag" data-slot="flag">
        <input #flagInput type="checkbox" />
        {{ flagLabel() }}
      </label>
    }
    @if (mismatchVisible) {
      <p [id]="mismatchId" class="ocu-typed-name-mismatch" role="alert">
        {{ STRINGS.formTypedNameMismatch }}
      </p>
    }
    <button
      dialogAction
      type="button"
      class="ocu-button-destructive"
      [attr.aria-disabled]="confirmDisabled"
      (click)="onConfirm()"
    >
      {{ actionLabel() }}
    </button>
  </app-dialog>`,
})
export class TypedNameDialog {
  /** The verb this dialog confirms, already published copy ("Delete"). */
  readonly verb = input.required<string>();

  /** The target, as the instance's own list reports it. Typed back to release the button. */
  readonly target = input.required<string>();

  /** The consequence sentence, a Fixed strings row the caller resolves for its own entity. */
  readonly consequence = input.required<string>();

  /** A second, published sentence for this target, or `''` for none. */
  readonly advisory = input('');

  /** The published label of an optional checkbox, or `''` for none. */
  readonly flagLabel = input('');

  /**
   * Emitted once, when the typed name matches and the destructive action is taken, carrying whether
   * the checkbox is checked (`false` when none is drawn).
   */
  readonly confirmed = output<boolean>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  /** The warning triangle the shared banner carries, as its escape (Rule 14). */
  protected readonly bannerGlyph = '\u26A0';

  private readonly instance = ++dialogCount;

  private readonly flagInput = viewChild<ElementRef<HTMLInputElement>>('flagInput');

  protected readonly fieldId = `ocu-typed-name-${this.instance}`;

  protected readonly mismatchId = `ocu-typed-name-mismatch-${this.instance}`;

  /** What the user has typed so far. */
  protected readonly typed = signal('');

  /**
   * Whether the mismatch has been shown. EXPERIENCE.md's `typed-name-field` shows it on blur, so the
   * message does not appear while the name is still being typed -- and it clears again the moment
   * the field matches, because a message telling the reader the name is wrong while it is right
   * says the opposite of the button beside it.
   */
  private readonly blurred = signal(false);

  /** Exact, case-sensitive. A trimmed or folded comparison would release the button on a name the instance resolves differently. */
  private readonly matches = computed(() => this.typed() === this.target());

  protected readonly heading = computed(() => `${this.verb()} ${this.target()}`);

  protected readonly actionLabel = computed(() => `${this.verb()} ${this.target()}`);

  protected readonly fieldLabel = computed(() =>
    STRINGS.formTypedNameConfirm.split('<name>').join(this.target())
  );

  protected get advisoryVisible(): boolean {
    return this.advisory() !== '';
  }

  protected get flagVisible(): boolean {
    return this.flagLabel() !== '';
  }

  protected get mismatchVisible(): boolean {
    return this.blurred() && !this.matches();
  }

  protected get invalid(): string | null {
    return this.mismatchVisible ? 'true' : null;
  }

  protected get describedBy(): string | null {
    return this.mismatchVisible ? this.mismatchId : null;
  }

  protected get confirmDisabled(): string | null {
    return this.matches() ? null : 'true';
  }

  protected onType(event: Event): void {
    this.typed.set((event.target as HTMLInputElement).value);
    if (this.matches()) this.blurred.set(false);
  }

  protected onBlur(): void {
    if (this.typed() === '') return;
    this.blurred.set(true);
  }

  protected onEnter(event: Event): void {
    event.preventDefault();
    this.onConfirm();
  }

  protected onConfirm(): void {
    if (!this.matches()) {
      this.blurred.set(true);
      return;
    }
    this.confirmed.emit(this.flagInput()?.nativeElement.checked ?? false);
  }
}
