/**
 * What a host test answered, as the Test dialog and a confirmed test's card read it (AD-39's seventh exception, Story 20.6): the
 * answer's shape, the sentence its status reads as, and the lines a confirmed test's `output` shows on a proposal card.
 *
 * Framework-free, and in `core/` because the proposal card (`turn.ts`) and the Test dialog both read it, as `sql-answer.ts` is for a
 * SQL run. Nothing here is stored or sent: the response's text, the session and the status live on the screen and the card alone,
 * and every line is drawn as text, never as markup.
 */

import { STRINGS } from './strings.ts';

/** The three states a test ends in: the target answered, it has not answered yet, or the test failed. */
export type TestStatus = 'done' | 'waiting' | 'error';

/** One test's answer, as the instance sent it. */
export interface TestAnswer {
  readonly status: TestStatus;
  readonly sessionId: string;
  readonly responseClass: string;
  readonly lines: readonly string[];
  readonly errors: boolean;
}

/** `template` with each `<placeholder>` of `values` replaced. */
function fill(template: string, values: Readonly<Record<string, string>>): string {
  let result = template;
  for (const [key, value] of Object.entries(values)) result = result.split(`<${key}>`).join(value);
  return result;
}

/**
 * The answer a test's `output` carries, or `null` for any other shape: a status that is one of the three, a session id, and a list of
 * lines. A compile's output carries lines and an error flag but no status, so it is not read as a test's.
 */
export function testAnswerOf(output: unknown): TestAnswer | null {
  if (output === null || typeof output !== 'object' || Array.isArray(output)) return null;
  const record = output as Readonly<Record<string, unknown>>;
  const status = record['status'];
  if (status !== 'done' && status !== 'waiting' && status !== 'error') return null;
  if (typeof record['sessionId'] !== 'string' || !Array.isArray(record['lines'])) return null;
  return {
    status,
    sessionId: record['sessionId'],
    responseClass: typeof record['responseClass'] === 'string' ? record['responseClass'] : '',
    lines: record['lines'].filter((line): line is string => typeof line === 'string'),
    errors: record['errors'] === true,
  };
}

/** The sentence an answer's status reads as, with the session and, for an answer, the response's class. */
export function testStatusLine(answer: TestAnswer): string {
  const session = answer.sessionId;
  switch (answer.status) {
    case 'done':
      return answer.responseClass === ''
        ? fill(STRINGS.interopTestDoneNoResponse, { session })
        : fill(STRINGS.interopTestDone, { session, class: answer.responseClass });
    case 'waiting':
      return fill(STRINGS.interopTestWaiting, { session });
    case 'error':
      return fill(STRINGS.interopTestFailed, { session });
  }
}

/**
 * The lines a confirmed test's `output` shows on its proposal card: its status sentence, then the response's lines or the error's
 * text. `[]` for an `output` that is not a test's answer.
 */
export function testOutcomeLines(output: unknown): readonly string[] {
  const answer = testAnswerOf(output);
  if (answer === null) return [];
  return [testStatusLine(answer), ...answer.lines];
}
