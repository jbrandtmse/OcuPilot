import { ChangeDetectionStrategy, Component, input } from '@angular/core';

import type { MeterSeverity } from '../core/meter-state';

/**
 * The pending-or-failed placeholder, written as its escape so no non-ASCII byte enters a source
 * file (Rule 14) -- the same idiom `classic-link-card.ts`'s `externalGlyph` follows.
 */
const DASH = '\u2014';

/**
 * The shared meter (Story 6.9, `system-usage.page.ts`; consumed by 6.11's Database details), a
 * label over a 6px `rounded.full` track and a value readout, per EXPERIENCE.md's `meter` row and
 * this story's Boundaries.
 *
 * **Two shapes, one component.** `state` is `null` for a **value meter** (Global references per
 * second, Cache efficiency): no vendor or computed threshold exists for these, so it draws no
 * track and no word, only the label and the value. `state` non-null is a **track meter** -- a
 * percentage (Shared memory) or a status word (Database space, Journal space, Lock table, Write
 * daemon) -- which draws the colored track and, once it has an answer, the word beside the value.
 *
 * **`state === null` means "value meter", never "not yet loaded".** A track meter's caller
 * (`system-usage.store.ts`) always passes a non-null `state` -- an inert `'normal'` placeholder
 * before its first successful read, since nothing here ever paints a color before `hasContent` is
 * true (documented at `showColoredFill`/`showWord` below). That is what lets this component read
 * `state === null` as a structural fact about which of the two shapes to draw, rather than
 * needing an eighth input to say so.
 *
 * **Content, not `value` alone, decides pending.** A status meter's `value` is permanently `null`
 * -- it carries no numeric quantity, only a word -- so "pending" is "neither a value nor a word has
 * ever arrived, and nothing is refused" (`pending`/`hasContent` below), which is what keeps a
 * loaded status meter from being read as still loading.
 *
 * **A fault keeps the last severity and dashes only the number.** `system-usage.store.ts` never
 * blanks `state`/`word`/`percent` on a fault -- only `value`'s *display* is forced to a dash while
 * `error` is set (`displayValue`), which is what lets the fill and the word stay on their last
 * known color while the tooltip explains why the number is a dash (the spec's "Meter fault" row:
 * last values kept, with the refusal surfaced through the tooltip here and the page's own
 * refusal strip elsewhere).
 *
 * **The fill never transitions or animates** (AC2): `.ocu-meter-fill` sets `transition: none` and
 * `animation: none` explicitly in `_components.scss`, regardless of what a future global rule
 * might otherwise apply to a `width` change.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group, so a
 * call expression in the condition leaves a stray `)` the literal-text-node rule reports.
 */
@Component({
  selector: 'app-meter',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { '[attr.title]': 'tooltip' },
  template: `<div class="ocu-meter">
    <span class="ocu-meter-label">{{ label() }}</span>
    @if (isTrack) {
      <div class="ocu-meter-track">
        @if (showSkeletonFill) {
          <span class="ocu-meter-fill-skeleton" aria-hidden="true"></span>
        }
        @if (showColoredFill) {
          <span
            class="ocu-meter-fill"
            [class.ocu-meter-fill-normal]="isNormal"
            [class.ocu-meter-fill-warning]="isWarning"
            [class.ocu-meter-fill-error]="isError"
            [style.width.%]="fillPercent"
          ></span>
        }
      </div>
    }
    <span class="ocu-meter-readout">
      <span
        class="ocu-meter-value"
        [class.ocu-meter-value-normal]="valueColored && isNormal"
        [class.ocu-meter-value-warning]="valueColored && isWarning"
        [class.ocu-meter-value-error]="valueColored && isError"
        >{{ displayValue }}</span
      >
      @if (showWord) {
        <span
          class="ocu-meter-word"
          [class.ocu-meter-word-normal]="isNormal"
          [class.ocu-meter-word-warning]="isWarning"
          [class.ocu-meter-word-error]="isError"
          >{{ wordText }}</span
        >
      }
    </span>
  </div>`,
})
export class Meter {
  readonly label = input('');
  readonly value = input<number | null>(null);
  readonly unit = input('');
  readonly percent = input<number | null>(null);
  readonly state = input<MeterSeverity | null>(null);
  readonly word = input<string | null>(null);
  readonly error = input<string | null>(null);

  /** The whole meter's tooltip: the current fault's text, or none. */
  protected get tooltip(): string | null {
    return this.error();
  }

  /** Whether this is a track meter (percentage or status) rather than a bare value meter. */
  protected get isTrack(): boolean {
    return this.state() !== null;
  }

  /** Whether an answer has ever arrived: a numeric value, or a status word. */
  private get hasContent(): boolean {
    return this.value() !== null || this.word() !== null;
  }

  /** No content yet, and no fault either -- the cold-load state EXPERIENCE.md's matrix names. */
  protected get pending(): boolean {
    return !this.hasContent && this.error() === null;
  }

  private get failed(): boolean {
    return this.error() !== null;
  }

  /** The loading placeholder, in place of the track's colored fill, on a track meter only. */
  protected get showSkeletonFill(): boolean {
    return this.isTrack && this.pending;
  }

  /**
   * The colored fill, once there is content to color -- kept through a later fault, so the last
   * known severity stays on screen while its tooltip explains the refusal (see the class doc).
   */
  protected get showColoredFill(): boolean {
    return this.isTrack && this.hasContent;
  }

  /** The value text takes the state color under the same rule the fill does. */
  protected get valueColored(): boolean {
    return this.showColoredFill;
  }

  protected get isNormal(): boolean {
    return this.state() === 'normal';
  }

  protected get isWarning(): boolean {
    return this.state() === 'warning';
  }

  protected get isError(): boolean {
    return this.state() === 'error';
  }

  /** The fill's width: the bounded percent when one is declared, else full -- a status meter's own shape. */
  protected get fillPercent(): number {
    const percent = this.percent();
    if (percent === null) return 100;
    return Math.min(100, Math.max(0, percent));
  }

  /**
   * The value readout: a dash while pending, a dash while a fault holds (regardless of a kept
   * value -- the number is what a fault dashes; the color and the word are not, see the class
   * doc), and a dash for a status meter's permanently absent numeric value. Otherwise the number,
   * with its unit appended when one is declared.
   */
  protected get displayValue(): string {
    if (this.pending || this.failed) return DASH;
    const value = this.value();
    if (value === null) return DASH;
    const unit = this.unit();
    return unit === '' ? String(value) : `${value} ${unit}`;
  }

  /** The word beside the value, once one has arrived, on a track meter only. */
  protected get showWord(): boolean {
    return this.isTrack && this.word() !== null;
  }

  protected get wordText(): string {
    return this.word() ?? '';
  }
}
