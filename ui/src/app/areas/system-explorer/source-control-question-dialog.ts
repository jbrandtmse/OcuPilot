import { ChangeDetectionStrategy, Component, inject, input, output, signal } from '@angular/core';

import {
  ANSWER_CANCEL,
  ANSWER_NO,
  ANSWER_YES,
  SOURCE_CONTROL_ANSWER_ACTION,
  SOURCE_CONTROL_ANSWER_VALUE,
  SOURCE_CONTROL_STEP_VALUE,
  type SourceControlQuestion,
} from '../../core/source-control-question';
import { STRINGS } from '../../core/strings';
import { Dialog } from '../../shell/dialog';
import { ScreenActionHandler, type ActionSink } from '../../shell/screen-action-handler';
import { fillPlaceholders } from './code-list.store';

/** The one question on screen, keyed by its place and attempt so each one is a fresh dialog with its own focus. */
interface Shown {
  readonly key: string;
  readonly question: SourceControlQuestion;
}

/** A refusal is the dialog's own line, so the list's banner is left alone. */
const OWN_SINK: ActionSink = { setRefusal: () => undefined };

/**
 * The question a namespace's source-control class asked after OcuPilot created or deleted a document (Story 21.38, AD-39's ninth exception),
 * shown one at a time in the order the class asked them. Both lists and the agent's proposal card open it.
 *
 * **The class's text is shown as text.** A question or an alert is bound by interpolation alone, so markup in it stays inert and a line break is
 * kept by the element's style. It is held in this component and nowhere else, and it is never sent or logged.
 *
 * **A question** (action 1) shows the lead, the class's text, and Yes, No and Cancel; each one sends `answer` for the document with the step the
 * question followed, to the namespace the question was asked in, on the list's own screen. Escape, the scrim and Cancel are the Cancel answer. An
 * answer the instance refused shows its sentence and leaves the question open, where a second Cancel closes it without sending. **An alert** (action
 * 6) shows the lead and the text with Close, and sends nothing. **Any other step** shows the unsupported line with Close, and sends nothing.
 */
@Component({
  selector: 'app-source-control-question-dialog',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog],
  template: `@for (shown of shownList; track shown.key) {
    <app-dialog [heading]="headingOf(shown.question)" [closeLabel]="closeLabelOf(shown.question)" (closed)="onClosed()">
      @if (shown.question.kind === 'unsupported') {
        <p class="ocu-source-control-text" data-ocu-source-control="unsupported">{{ unsupportedLine(shown.question) }}</p>
      } @else {
        <p class="ocu-field-caption" data-ocu-source-control="lead">{{ leadOf(shown.question) }}</p>
        <p class="ocu-source-control-text" data-ocu-source-control="text">{{ shown.question.text }}</p>
      }
      @if (refusalText !== '') {
        <p class="ocu-explorer-status" role="alert" data-ocu-source-control="refusal">{{ refusalText }}</p>
      }
      @if (shown.question.kind === 'question') {
        <button
          dialogAction
          type="button"
          class="ocu-button-secondary"
          data-ocu-source-control="no"
          [attr.aria-disabled]="busyAttribute"
          (click)="onAnswer(ANSWER_NO)"
        >
          {{ STRINGS.tableStatusNo }}
        </button>
      }
      @if (shown.question.kind === 'question') {
        <button
          dialogAction
          type="button"
          class="ocu-button-primary"
          data-ocu-source-control="yes"
          [attr.aria-disabled]="busyAttribute"
          (click)="onAnswer(ANSWER_YES)"
        >
          {{ STRINGS.tableStatusYes }}
        </button>
      }
    </app-dialog>
  }`,
})
export class SourceControlQuestionDialog {
  /** The questions the class asked, in order. */
  readonly questions = input.required<readonly SourceControlQuestion[]>();

  /** The descriptor class of the list screen an answer is sent to. */
  readonly descriptor = input.required<string>();

  /** The namespace the questions were asked in, which each answer is pinned to; `''` follows the shell's. */
  readonly scope = input<string>('');

  /** Emitted once the last question is answered or dismissed. */
  readonly finished = output<void>();

  protected readonly STRINGS = STRINGS;

  protected readonly ANSWER_NO = ANSWER_NO;

  protected readonly ANSWER_YES = ANSWER_YES;

  private readonly handler = inject(ScreenActionHandler);

  private readonly index = signal(0);

  private readonly attempt = signal(0);

  private readonly sending = signal(false);

  private readonly refusal = signal('');

  /** The question on screen, as the one entry of a list so a new question or a new attempt is a new dialog. */
  protected get shownList(): readonly Shown[] {
    const question = this.questions()[this.index()];
    return question === undefined ? [] : [{ key: `${this.index()}:${this.attempt()}`, question }];
  }

  protected get refusalText(): string {
    return this.refusal();
  }

  protected get busyAttribute(): string | null {
    return this.sending() ? 'true' : null;
  }

  protected headingOf(question: SourceControlQuestion): string {
    return fillPlaceholders(STRINGS.explorerSourceControlTitle, { document: question.document });
  }

  protected leadOf(question: SourceControlQuestion): string {
    return question.kind === 'alert' ? STRINGS.explorerSourceControlAlertLead : STRINGS.explorerSourceControlQuestionLead;
  }

  protected unsupportedLine(question: SourceControlQuestion): string {
    return fillPlaceholders(STRINGS.explorerSourceControlUnsupported, { document: question.document });
  }

  /** Cancel for a question, Close for an alert or a step OcuPilot cannot show. */
  protected closeLabelOf(question: SourceControlQuestion): string {
    return question.kind === 'question' ? STRINGS.actionCancel : STRINGS.auditDialogClose;
  }

  /** Cancel, Escape or the scrim: a question is answered Cancel, once; an alert, an unsupported step or a refused question just closes. */
  protected onClosed(): void {
    const question = this.questions()[this.index()];
    if (question === undefined || this.sending()) return;
    if (question.kind !== 'question' || this.refusal() !== '') {
      this.next();
      return;
    }
    void this.onAnswer(ANSWER_CANCEL);
  }

  /** Send `answer` for the question on screen; an applied one moves on, and a refused one shows the instance's sentence. */
  protected async onAnswer(answer: string): Promise<void> {
    const question = this.questions()[this.index()];
    if (question === undefined || this.sending()) return;
    this.sending.set(true);
    this.refusal.set('');
    const scope = this.scope();
    const applied = await this.handler.sendFor(
      this.descriptor(),
      SOURCE_CONTROL_ANSWER_ACTION,
      question.document,
      { [SOURCE_CONTROL_STEP_VALUE]: String(question.step), [SOURCE_CONTROL_ANSWER_VALUE]: answer },
      OWN_SINK,
      scope === '' ? undefined : scope
    );
    this.sending.set(false);
    if (applied) {
      this.next();
      return;
    }
    this.refusal.set(this.handler.lastRefusal()?.reason || STRINGS.explorerSourceControlAnswerRefused);
    this.attempt.update((count) => count + 1);
  }

  private next(): void {
    this.refusal.set('');
    if (this.index() + 1 >= this.questions().length) {
      this.index.set(this.questions().length);
      this.finished.emit();
      return;
    }
    this.index.update((value) => value + 1);
  }
}
