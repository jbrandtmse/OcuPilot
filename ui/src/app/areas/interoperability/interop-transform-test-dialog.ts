import { ChangeDetectionStrategy, Component, computed, input, output, signal } from '@angular/core';

import { STRINGS } from '../../core/strings';
import { type TransformAnswer, transformStatusLine } from '../../core/test-answer';
import { CodeBlock } from '../../shell/code-block';
import { Dialog } from '../../shell/dialog';

/** How many Test dialogs of this kind have been constructed, which makes each one's ids its own. */
let dialogCount = 0;

/** `template` with `<placeholder>` replaced by `value`, shown as written. */
function fill(template: string, placeholder: string, value: string): string {
  return template.split(`<${placeholder}>`).join(value);
}

/** One block of text lines as the code block's single step. */
function stepsOf(lines: readonly string[]): readonly { readonly kind: string; readonly text: string }[] {
  return [{ kind: 'text', text: lines.join('\n') }];
}

/**
 * Test a data transformation (Story 20.27): a Data transformations row's dialog, titled "Test <transformation>". It states that the
 * transformation's code runs here as the person, takes the one pasted message the transformation reads, and hands it to the page.
 *
 * **The message is sent as typed.** Whether it is empty or too long is the instance's answer, which the page passes back as
 * `violation` and the dialog draws under the field; any other refusal comes as `refusal` and is drawn above it. Both are the
 * server's sentences.
 *
 * **The result stays in the dialog.** After a run the source and target class, the status sentence (in the error style when the run
 * did not end `done`), the target's or the error's lines and, when the transformation wrote anything, the console label and what it
 * wrote, beneath the field. Every line is drawn as text, never as markup (AD-11, AD-47), and a further run replaces them. The
 * status sentence is also written into a polite `role="status"` region the dialog keeps mounted, so a screen reader announces the
 * run's end (WCAG 4.1.3).
 */
@Component({
  selector: 'app-interop-transform-test-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, CodeBlock],
  template: `<app-dialog [heading]="heading()" [closeLabel]="STRINGS.actionCancel" (closed)="onClosed()">
    <p class="ocu-banner" data-interop-transform-consequence>{{ STRINGS.interopTransformRunsConsequence }}</p>
    <p class="ocu-visually-hidden" role="status" data-interop-transform-announce>{{ statusLine }}</p>
    @if (hasRefusal) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-interop-transform-reason>{{ refusal() }}</p>
    }
    <div class="ocu-form-fields">
      <div class="ocu-field">
        <label class="ocu-field-label ocu-field-label-required" [attr.for]="fieldId">{{ STRINGS.interopTransformInputLabel }}</label>
        <div class="ocu-field-control">
          <textarea
            class="ocu-field-input ocu-field-textarea"
            rows="8"
            spellcheck="false"
            data-interop-transform-input
            [id]="fieldId"
            [value]="typed()"
            [attr.aria-invalid]="violation() ? 'true' : null"
            [attr.aria-describedby]="describedBy()"
            (input)="onInput($event)"
          ></textarea>
        </div>
        <p class="ocu-field-caption" data-interop-transform-hint [id]="hintId">{{ STRINGS.interopTransformInputHint }}</p>
        @if (hasViolation) {
          <p class="ocu-form-error" data-interop-transform-violation [id]="reasonId">{{ violation() }}</p>
        }
      </div>
    </div>
    @if (hasAnswer) {
      <div class="ocu-form-fields" data-interop-transform-result>
        <div class="ocu-field" data-interop-transform-source>
          <span class="ocu-field-label">{{ STRINGS.interopTransformSourceClass }}</span>
          <span>{{ sourceClass }}</span>
        </div>
        <div class="ocu-field" data-interop-transform-target>
          <span class="ocu-field-label">{{ STRINGS.interopTransformTargetClass }}</span>
          <span>{{ targetClass }}</span>
        </div>
        <p class="ocu-field-caption" data-interop-transform-status [class.ocu-form-error]="failed">{{ statusLine }}</p>
        @if (hasLines) {
          <app-code-block data-interop-transform-lines [steps]="lineSteps" />
        }
        @if (hasConsole) {
          <span class="ocu-field-label" data-interop-transform-console-label>{{ STRINGS.interopTransformConsole }}</span>
          <app-code-block data-interop-transform-console [steps]="consoleSteps" />
        }
      </div>
    }
    <button
      dialogAction
      type="button"
      class="ocu-button-primary"
      data-interop-transform-run
      [attr.aria-disabled]="sending() ? 'true' : null"
      (click)="submit()"
    >
      {{ STRINGS.actionRun }}
    </button>
  </app-dialog>`,
})
export class InteropTransformTestDialog {
  /** The transformation's name, which titles the dialog. */
  readonly name = input<string>('');

  /** A run is in flight. */
  readonly sending = input<boolean>(false);

  /** The instance's refusal sentence for any other reason than the message, or `''`. */
  readonly refusal = input<string>('');

  /** The instance's sentence for the message field, or `''`. */
  readonly violation = input<string>('');

  /** The last run's answer, or `null` before one. */
  readonly answer = input<TransformAnswer | null>(null);

  /** Emitted once per Run, with the message exactly as typed. */
  readonly submitted = output<string>();

  /** Emitted on every dismissal path: Escape, Cancel and the scrim. */
  readonly cancelled = output<void>();

  protected readonly STRINGS = STRINGS;

  private readonly instance = ++dialogCount;

  protected readonly fieldId = `ocu-interop-transform-input-${this.instance}`;

  protected readonly hintId = `ocu-interop-transform-hint-${this.instance}`;

  protected readonly reasonId = `ocu-interop-transform-reason-${this.instance}`;

  /** The message typed so far. */
  protected readonly typed = signal('');

  private closed = false;

  protected readonly heading = computed(() => fill(STRINGS.interopTransformTestTitle, 'transform', this.name()));

  protected readonly describedBy = computed(() => (this.violation() ? `${this.hintId} ${this.reasonId}` : this.hintId));

  protected get hasRefusal(): boolean {
    return this.refusal() !== '';
  }

  protected get hasViolation(): boolean {
    return this.violation() !== '';
  }

  protected get hasAnswer(): boolean {
    return this.answer() !== null;
  }

  /** Whether the run did not end `done`. */
  protected get failed(): boolean {
    return this.answer()?.errors === true;
  }

  protected get sourceClass(): string {
    return this.answer()?.sourceClass ?? '';
  }

  protected get targetClass(): string {
    return this.answer()?.targetClass ?? '';
  }

  protected get statusLine(): string {
    const answer = this.answer();
    return answer === null ? '' : transformStatusLine(answer);
  }

  protected get hasLines(): boolean {
    return (this.answer()?.lines.length ?? 0) > 0;
  }

  protected get hasConsole(): boolean {
    return (this.answer()?.console.length ?? 0) > 0;
  }

  /** The target's or the error's lines as one step, which the code block draws as text. */
  protected get lineSteps(): readonly { readonly kind: string; readonly text: string }[] {
    return stepsOf(this.answer()?.lines ?? []);
  }

  /** What the transformation wrote to the device, as one step. */
  protected get consoleSteps(): readonly { readonly kind: string; readonly text: string }[] {
    return stepsOf(this.answer()?.console ?? []);
  }

  protected onInput(event: Event): void {
    this.typed.set((event.target as HTMLTextAreaElement).value);
  }

  /** Hand the message on unless a run is in flight; the instance judges an empty or an over-long one. */
  protected submit(): void {
    if (this.sending()) return;
    this.submitted.emit(this.typed());
  }

  protected onClosed(): void {
    if (this.closed) return;
    this.closed = true;
    this.cancelled.emit();
  }
}
