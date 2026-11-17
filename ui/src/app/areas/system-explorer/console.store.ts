/**
 * System Explorer's Command console and Class method console state (AD-10, AD-19, Story 24.6): what the form holds, whether the
 * warning dialog is open, whether a confirmed run is in flight, the sentence the instance refused the last run with and the
 * answer the last run came back with.
 *
 * **Framework-free.** It imports nothing from Angular; `console.page.ts` holds one per screen store, so a return to the screen
 * finds the form and the last answer, and the component spec drives it directly.
 *
 * **Nothing is sent before Confirm.** Run opens the warning dialog and sends nothing; Cancel closes it and sends nothing;
 * Confirm sends the screen action `run` (AD-53) with the form's values as the declared ones, once.
 *
 * **The answer is screen-only** (AD-39's eighth exception): the output, the return value, the by-reference values and the error
 * live in this state, are drawn as text, and never enter the screen's store, so they never reach screen context.
 */

import { STRINGS } from '../../core/strings';
import type { ActionRefusal, ActionSink, ActionValues } from '../../shell/screen-action-handler';

/** The action both consoles declare, and the literal each one's target is named by (AD-13). */
export const RUN_ACTION = 'run';
export const COMMAND_TARGET = 'command';
export const CLASSMETHOD_TARGET = 'classmethod';

/** The names the Command console's value and the Class method console's three travel under (AD-56 (ii)). */
export const COMMAND_VALUE = 'command';
export const CLASS_VALUE = 'class';
export const METHOD_VALUE = 'method';
export const ARGS_VALUE = 'args';

/** The most characters a command takes, which the instance also enforces. */
export const COMMAND_MAX = 30000;

/** The argument list the Class method console starts with: none. */
export const NO_ARGUMENTS = '[]';

/** Which console a screen is. */
export type ConsoleKind = 'command' | 'classmethod';

/** What sends the confirmed run and answers its outcome: the shell's `ScreenActionHandler`. */
export interface ConsoleSender {
  sendFor(descriptor: string, actionId: string, target: string, values?: ActionValues, sink?: ActionSink, scope?: string): Promise<boolean>;
  lastOutput(): unknown;
  lastRefusal(): ActionRefusal | null;
}

/** What one run answered, as the screen shows it. `returnValue` and `byRefValues` are empty for a command. */
export interface ConsoleAnswer {
  readonly output: string;
  readonly returnValue: string;
  readonly byRefValues: string;
  readonly error: string;
  readonly outputCut: boolean;
  readonly returnValueCut: boolean;
  readonly byRefCut: boolean;
}

function text(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

/** The answer an action's `output` holds, or `null` for an output that is not one. */
export function answerOf(output: unknown): ConsoleAnswer | null {
  if (output === null || typeof output !== 'object') return null;
  const record = output as Record<string, unknown>;
  if (typeof record['output'] !== 'string') return null;
  const byRef = record['byRefValues'];
  const hasByRef = byRef !== null && typeof byRef === 'object' && Object.keys(byRef as Record<string, unknown>).length > 0;
  return {
    output: record['output'],
    returnValue: text(record['returnValue']),
    byRefValues: hasByRef ? JSON.stringify(byRef, null, 2) : '',
    error: text(record['error']),
    outputCut: record['truncated'] === true,
    returnValueCut: record['returnValueTruncated'] === true,
    byRefCut: record['byRefTruncated'] === true,
  };
}

/** The notes a run's answer carries for what was cut, in the order its parts are drawn. */
export function cutNotes(answer: ConsoleAnswer): readonly string[] {
  const notes: string[] = [];
  if (answer.returnValueCut) notes.push(STRINGS.explorerConsoleReturnCut);
  if (answer.byRefCut) notes.push(STRINGS.explorerConsoleByRefCut);
  if (answer.outputCut) notes.push(STRINGS.explorerConsoleOutputCut);
  return notes;
}

/** One console's form and run state. */
export class ConsoleState {
  private readonly listeners = new Set<() => void>();

  private commandValue = '';

  private classValue = '';

  private methodValue = '';

  private argsValue = NO_ARGUMENTS;

  private confirmingValue = false;

  private runningValue = false;

  private refusalValue = '';

  private answerValue: ConsoleAnswer | null = null;

  constructor(readonly kind: ConsoleKind) {}

  /** Call `listener` after every change; answers the function that stops it. */
  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }

  command(): string {
    return this.commandValue;
  }

  setCommand(value: string): void {
    this.commandValue = value;
    this.notify();
  }

  className(): string {
    return this.classValue;
  }

  setClassName(value: string): void {
    this.classValue = value;
    this.notify();
  }

  method(): string {
    return this.methodValue;
  }

  setMethod(value: string): void {
    this.methodValue = value;
    this.notify();
  }

  args(): string {
    return this.argsValue;
  }

  setArgs(value: string): void {
    this.argsValue = value;
    this.notify();
  }

  /** Whether the warning dialog is open: Run was pressed and nothing is sent until it is confirmed. */
  confirming(): boolean {
    return this.confirmingValue;
  }

  /** Whether a confirmed run is in flight. */
  running(): boolean {
    return this.runningValue;
  }

  /** The sentence the instance refused the last confirmed run with, or `''`. */
  refusal(): string {
    return this.refusalValue;
  }

  /** The answer the last run came back with, or `null` before one or after a refusal. */
  answer(): ConsoleAnswer | null {
    return this.answerValue;
  }

  /** Whether the form names what a run needs: a command, or a class and a method. */
  complete(): boolean {
    if (this.kind === 'command') return this.commandValue.trim() !== '';
    return this.classValue.trim() !== '' && this.methodValue.trim() !== '';
  }

  /** Open the warning dialog and send nothing: answers false, opening nothing, with the form incomplete or a run in flight. */
  askRun(): boolean {
    if (!this.complete() || this.runningValue) return false;
    this.refusalValue = '';
    this.confirmingValue = true;
    this.notify();
    return true;
  }

  /** Close the warning dialog. Nothing was sent. */
  cancelRun(): void {
    if (!this.confirmingValue) return;
    this.confirmingValue = false;
    this.notify();
  }

  /**
   * The values a confirmed run sends, under the names its tool declares. A command's trailing line breaks are left off, so a
   * line ending in Enter is still one line.
   */
  private values(): ActionValues {
    if (this.kind === 'command') return { [COMMAND_VALUE]: this.commandValue.replace(/[\r\n]+$/, '') };
    return { [CLASS_VALUE]: this.classValue.trim(), [METHOD_VALUE]: this.methodValue.trim(), [ARGS_VALUE]: this.argsValue.trim() === '' ? NO_ARGUMENTS : this.argsValue.trim() };
  }

  /**
   * Send the confirmed run as the screen action, once, in the namespace the screen was opened in. A refusal keeps the sentence
   * the instance gave, the switched-off one included, and the form as it was. Answers whether the run was applied.
   */
  async proceed(sender: ConsoleSender, descriptor: string, scope: string): Promise<boolean> {
    if (!this.confirmingValue) return false;
    this.confirmingValue = false;
    this.runningValue = true;
    this.refusalValue = '';
    this.answerValue = null;
    this.notify();
    let refused = '';
    const sink: ActionSink = { setRefusal: (reason) => (refused = reason) };
    const target = this.kind === 'command' ? COMMAND_TARGET : CLASSMETHOD_TARGET;
    const applied = await sender.sendFor(descriptor, RUN_ACTION, target, this.values(), sink, scope);
    this.runningValue = false;
    if (applied) {
      this.answerValue = answerOf(sender.lastOutput());
    } else {
      this.refusalValue = sender.lastRefusal()?.reason || refused || STRINGS.connectivityRequestRefused;
    }
    this.notify();
    return applied;
  }
}
