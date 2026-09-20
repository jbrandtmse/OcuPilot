import { ChangeDetectionStrategy, Component, input, signal } from '@angular/core';

import { STRINGS } from '../core/strings';
import { type TurnStep, stepLabel } from '../core/turn';

/**
 * One tool-call card (Story 4.5, EXPERIENCE.md `tool-call-card`): an ordered-disclosure over one
 * step of the turn's own progress.
 *
 * **Every string here renders through interpolation, never `innerHTML`.** A step's `name`,
 * `target`, `arguments`, `text` and `reason` are model- or tool-originated and, per AD-11, are
 * data -- the template never resolves them as markup.
 *
 * **A `stopped` step is not a disclosure at all.** The spec's own words: restrained bar, no body,
 * not expandable. It renders as one line, no `<button>`, nothing to toggle.
 *
 * **Expand/collapse is a manual override over a status default**, not an independent flag: a
 * running card is expanded and a completed one collapses, *unless the user opened it* -- so a
 * card the user never touched keeps tracking its own status, and one they clicked keeps whatever
 * they left it at. `null` means "no override yet"; `expanded` re-derives the default from
 * `status` on every read, which is what makes a running card default open before anyone touches
 * it and a freshly completed one default closed.
 *
 * Every control-flow condition below is a paren-free getter, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group, and a
 * signal call `foo()` inside one leaves a stray bracket it reports as copy.
 */
@Component({
  selector: 'app-tool-call-card',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `@if (stopped) {
      <p class="ocu-tool-call-card ocu-tool-call-card-stopped" role="status">
        {{ stoppedText }}
      </p>
    } @else {
      <div class="ocu-tool-call-card">
        <button
          type="button"
          class="ocu-tool-call-toggle"
          [attr.aria-expanded]="expandedAttr"
          (click)="toggle()"
        >
          <span class="ocu-tool-call-name">{{ label }}</span>
          <span class="ocu-tool-call-status">
            @if (running) {
              <span class="ocu-tool-call-spinner" aria-hidden="true"></span>
            }
            <span class="ocu-tool-call-status-word" [class.ocu-tool-call-status-warning]="warned">{{
              statusText
            }}</span>
          </span>
        </button>
        @if (expanded) {
          <div class="ocu-tool-call-body">
            @if (hasArguments) {
              <p class="ocu-tool-call-arguments">{{ argumentsText }}</p>
            }
            @if (hasText) {
              <pre class="ocu-tool-call-result">{{ resultText }}</pre>
            }
            @if (hasRowsLine) {
              <p class="ocu-tool-call-rows">{{ rowsLine }}</p>
            }
          </div>
        }
      </div>
    }`,
})
export class ToolCallCard {
  /** One step of `Convo`'s or `Turn`'s progress array. Required: a card with no step is not a state. */
  readonly step = input.required<TurnStep>();

  protected readonly STRINGS = STRINGS;

  /** `null` until the user clicks; then the manual override this card keeps for its whole life. */
  private readonly manualExpanded = signal<boolean | null>(null);

  protected get stopped(): boolean {
    return this.step().status === 'stopped';
  }

  protected get running(): boolean {
    return this.step().status === 'running';
  }

  protected get failed(): boolean {
    return this.step().status === 'error';
  }

  /**
   * Whether the status word carries the warning class. **Not only `error`** (AD-15, FR-22): a
   * confirmed write whose audit marker was dropped succeeded, so its status is `ok` and its line
   * still has to read as a warning -- and it has to read that way on the **collapsed** line, which
   * is where this word is, rather than only in the body a reader may never open.
   */
  protected get warned(): boolean {
    return this.failed || this.step().auditMarked === false;
  }

  protected get label(): string {
    return stepLabel(this.step());
  }

  protected get stoppedText(): string {
    return STRINGS.toolCallStoppedByYou.split('<step>').join(this.label);
  }

  protected get statusText(): string {
    const step = this.step();
    if (step.status === 'running') return STRINGS.accessibilityReducedMotionSpinnerWord;
    if (step.status === 'error') {
      // AD-8: a privilege refusal names the pair that failed. The generic reason says a
      // privilege is missing; the pair says which one, which is what the user has to be
      // granted. Every other failure keeps the reason it already carried.
      const detail = step.failedPair !== '' ? step.failedPair : step.reason;
      return STRINGS.toolCallStatusFailed.split('<reason>').join(detail);
    }
    // A confirmed write's card says what became of its marker; every other card, whose step
    // carries `null`, reads the plain word (AD-15). Nothing here claims marking is working in
    // general -- the sentence is about this write.
    if (step.auditMarked !== null) {
      return step.auditMarked ? STRINGS.auditMarkerMarked : STRINGS.auditMarkerFailed;
    }
    return STRINGS.toolCallStatusDone;
  }

  protected get expanded(): boolean {
    const manual = this.manualExpanded();
    return manual !== null ? manual : this.running;
  }

  protected get expandedAttr(): string {
    return this.expanded ? 'true' : 'false';
  }

  protected get hasArguments(): boolean {
    return this.step().arguments !== '';
  }

  protected get argumentsText(): string {
    return this.step().arguments;
  }

  protected get hasText(): boolean {
    return this.step().text !== '';
  }

  protected get resultText(): string {
    return this.step().text;
  }

  protected get hasRowsLine(): boolean {
    return this.step().result !== null;
  }

  /** The Design Notes row: "<n> rows returned · <m> sent", for a rows-shaped read result. */
  protected get rowsLine(): string {
    const result = this.step().result;
    if (result === null) return '';
    return STRINGS.toolCallReadResultLine
      .split('<n>')
      .join(String(result.rowsReturned))
      .split('<m>')
      .join(String(result.rowsSent));
  }

  protected toggle(): void {
    this.manualExpanded.set(!this.expanded);
  }
}
