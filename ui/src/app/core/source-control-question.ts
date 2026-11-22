/**
 * What a namespace's source-control class asked after OcuPilot created or deleted a document (Story 21.38, AD-39's ninth exception).
 *
 * The class's own text reaches a screen's dialog and a proposal card, as text, and nowhere else: it is read off one answer's `output`, held in
 * memory beside the card, and never sent to the model, written to a log or put into the screen context.
 *
 * Framework-free, like the rest of `core/` (AD-19).
 */

/** The action a person's answer is sent under, on the Classes and Routines lists. */
export const SOURCE_CONTROL_ANSWER_ACTION = 'answer';

/** The values an answer sends beside its target (AD-56): the step the question followed and the answer. */
export const SOURCE_CONTROL_STEP_VALUE = 'step';
export const SOURCE_CONTROL_ANSWER_VALUE = 'answer';

/** The vendor's answers to a question: No, Yes and Cancel (`%Studio.Extension.Base`). */
export const ANSWER_NO = '0';
export const ANSWER_YES = '1';
export const ANSWER_CANCEL = '2';

/** The source-control class's action codes OcuPilot shows: a question with Yes, No and Cancel, and an alert. */
const ACTION_QUESTION = 1;
const ACTION_ALERT = 6;

/** What a question asks of the person. */
export type SourceControlQuestionKind = 'question' | 'alert' | 'unsupported';

/** One question, in the order the class asked it. `text` is the class's own, and `''` for an unsupported step. */
export interface SourceControlQuestion {
  readonly document: string;
  readonly step: number;
  readonly kind: SourceControlQuestionKind;
  readonly text: string;
}

/**
 * The questions an action's or a confirm's `output` carries, in order, or `[]` for any other shape. An entry the class asked in an action
 * other than a question or an alert, or one the port flagged `unsupported`, carries no text.
 */
export function sourceControlQuestionsOf(output: unknown): readonly SourceControlQuestion[] {
  if (output === null || typeof output !== 'object') return [];
  const entries = (output as Record<string, unknown>)['questions'];
  if (!Array.isArray(entries)) return [];
  const questions: SourceControlQuestion[] = [];
  for (const entry of entries) {
    if (entry === null || typeof entry !== 'object') continue;
    const record = entry as Record<string, unknown>;
    const document = record['document'];
    const step = record['step'];
    const action = record['action'];
    if (typeof document !== 'string' || document === '' || typeof step !== 'number' || typeof action !== 'number') continue;
    const target = record['target'];
    const shown = record['unsupported'] !== true && typeof target === 'string';
    if (shown && action === ACTION_QUESTION) questions.push({ document, step, kind: 'question', text: target });
    else if (shown && action === ACTION_ALERT) questions.push({ document, step, kind: 'alert', text: target });
    else questions.push({ document, step, kind: 'unsupported', text: '' });
  }
  return questions;
}
