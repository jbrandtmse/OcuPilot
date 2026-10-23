/**
 * What a host test answered, as the Test dialog and a confirmed test's card read it (AD-39's seventh exception, Story 20.6): the
 * answer's shape, the sentence its status reads as, and the lines a confirmed test's `output` shows on a proposal card.
 *
 * A data transformation's test answers a different shape (Story 20.27, the same exception): a status of its own, the source and target
 * class, the target's or the error's lines and what the transformation wrote to the device. `transformAnswerOf` reads that shape and
 * `testAnswerOf` never does, so the one `output` is read as exactly one of them.
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

/** The four states a data transformation's test ends in: the target is shown, the input did not parse, the transformation failed, or the target is not text. */
export type TransformStatus = 'done' | 'input' | 'transform' | 'output';

/** One data transformation test's answer, as the instance sent it. */
export interface TransformAnswer {
  readonly status: TransformStatus;
  readonly sourceClass: string;
  readonly targetClass: string;
  /** The target's text lines when `done`, else the error's text lines. */
  readonly lines: readonly string[];
  /** What the transformation wrote to the device. */
  readonly console: readonly string[];
  readonly errors: boolean;
}

/** The strings of `value` when it is an array, else `null`. */
function textLines(value: unknown): readonly string[] | null {
  return Array.isArray(value) ? value.filter((line): line is string => typeof line === 'string') : null;
}

/**
 * The answer a data transformation test's `output` carries, or `null` for any other shape: a status that is one of the four, a source
 * class, and arrays of lines and console lines. A host test's output carries a session and no console, and a compile's no status, so
 * neither is read as a transformation's.
 */
export function transformAnswerOf(output: unknown): TransformAnswer | null {
  if (output === null || typeof output !== 'object' || Array.isArray(output)) return null;
  const record = output as Readonly<Record<string, unknown>>;
  const status = record['status'];
  if (status !== 'done' && status !== 'input' && status !== 'transform' && status !== 'output') return null;
  const lines = textLines(record['lines']);
  const device = textLines(record['console']);
  if (typeof record['sourceClass'] !== 'string' || lines === null || device === null) return null;
  return {
    status,
    sourceClass: record['sourceClass'],
    targetClass: typeof record['targetClass'] === 'string' ? record['targetClass'] : '',
    lines,
    console: device,
    errors: record['errors'] === true,
  };
}

/** The sentence a transformation answer's status reads as. */
export function transformStatusLine(answer: TransformAnswer): string {
  switch (answer.status) {
    case 'done':
      return STRINGS.interopTransformDone;
    case 'input':
      return STRINGS.interopTransformInputFailed;
    case 'transform':
      return STRINGS.interopTransformFailed;
    case 'output':
      return STRINGS.interopTransformOutputFailed;
  }
}

/**
 * The lines a confirmed transformation test's `output` shows on its proposal card: its status sentence, then the target's or the
 * error's lines, then, when the transformation wrote anything, the console label and what it wrote. `[]` for an `output` that is not a
 * transformation test's answer.
 */
export function transformOutcomeLines(output: unknown): readonly string[] {
  const answer = transformAnswerOf(output);
  if (answer === null) return [];
  const written = answer.console.length === 0 ? [] : [STRINGS.interopTransformConsole, ...answer.console];
  return [transformStatusLine(answer), ...answer.lines, ...written];
}
