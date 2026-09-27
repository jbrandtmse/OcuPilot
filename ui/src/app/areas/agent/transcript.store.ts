/**
 * The transcript page's own state (Story 14.4, AD-19): one stored conversation read from
 * `GET /api/ocupilot/transcripts/<id>`, parsed into turns the page renders as data.
 *
 * Framework-free, like `areas/tasks/details.store.ts`, so `ui/tools/transcript-store.test.mjs` runs
 * it under `node --test`: a plain subscribable the page mirrors into a signal. The request function
 * is injected, so the store names no Angular service.
 *
 * **Nothing here decides what a reader may see.** Whether another user's tool results and screen
 * context arrive is the instance's answer (`released`), made by the ledger's own gate (AD-46); the
 * store only renders what came back, and a withheld answer carries no steps and no context to
 * render.
 */

import type { JsonResult } from '../../core/api';
import { encodeEntityId } from '../../core/entity-id.ts';
import { formatDeniedAction } from '../../core/navigation.ts';
import { STRINGS } from '../../core/strings.ts';
import { parseStep, type TurnStep } from '../../core/turn.ts';

/** The transcript route, absolute from the origin root (AD-20). */
export const TRANSCRIPTS_PATH = '/api/ocupilot/transcripts';

/** The request path for conversation `id`, its key in one encoded segment (AD-13). */
export function transcriptPath(id: string): string {
  return `${TRANSCRIPTS_PATH}/${encodeEntityId(id)}`;
}

/** One turn's stored screen context, as the page shows it: the route it named and the payload as text. */
export interface TranscriptContext {
  readonly route: string;
  readonly text: string;
}

/** One stored turn. */
export interface TranscriptTurn {
  readonly seq: number;
  readonly appendedAt: string;
  readonly message: string;
  readonly reply: string | null;
  readonly errorReason: string | null;
  readonly steps: readonly TurnStep[];
  readonly context: TranscriptContext | null;
}

/** The whole answer. */
export interface TranscriptView {
  readonly conversationId: string;
  readonly user: string;
  readonly own: boolean;
  readonly released: boolean;
  readonly failedPair: string;
  readonly turns: readonly TranscriptTurn[];
}

/** Where the read stands: before it answers, answered, gone (404), or refused otherwise. */
export type TranscriptPhase = 'loading' | 'ready' | 'gone' | 'refused';

/** The one request the store makes. */
export type TranscriptRequest = (path: string) => Promise<JsonResult<unknown>>;

function record(value: unknown): Record<string, unknown> | null {
  return value !== null && typeof value === 'object' && !Array.isArray(value) ? (value as Record<string, unknown>) : null;
}

function text(source: Record<string, unknown>, key: string): string {
  const value = source[key];
  return typeof value === 'string' ? value : '';
}

/** A stored context payload as the page shows it, or `null` when the turn carried none. */
export function parseContext(value: unknown): TranscriptContext | null {
  const payload = record(value);
  if (payload === null) return null;
  return { route: text(payload, 'route'), text: JSON.stringify(payload, null, 2) };
}

/** One wire turn, or `null` when `value` is not one. */
export function parseTurn(value: unknown): TranscriptTurn | null {
  const row = record(value);
  if (row === null) return null;
  const steps: TurnStep[] = [];
  if (Array.isArray(row['steps'])) {
    for (const raw of row['steps']) {
      const step = parseStep(raw);
      if (step !== null) steps.push(step);
    }
  }
  const error = record(row['error']);
  return {
    seq: typeof row['seq'] === 'number' ? row['seq'] : 0,
    appendedAt: text(row, 'appendedAt'),
    message: text(row, 'message'),
    reply: typeof row['reply'] === 'string' && row['reply'] !== '' ? row['reply'] : null,
    errorReason: error === null ? null : text(error, 'reason'),
    steps,
    context: parseContext(row['context']),
  };
}

/** The whole wire answer, or `null` when `value` is not one. */
export function parseTranscript(value: unknown): TranscriptView | null {
  const body = record(value);
  if (body === null || !Array.isArray(body['turns'])) return null;
  const turns: TranscriptTurn[] = [];
  for (const raw of body['turns']) {
    const turn = parseTurn(raw);
    if (turn !== null) turns.push(turn);
  }
  return {
    conversationId: text(body, 'conversationId'),
    user: text(body, 'user'),
    own: body['own'] === true,
    released: body['released'] === true,
    failedPair: text(body, 'failedPair'),
    turns,
  };
}

/**
 * The sentence a withheld transcript shows: EXPERIENCE.md's request-refused pattern resolved to
 * the pair the instance named and this page's published action. `''` when the transcript is
 * released, or when the instance withheld it for a row's shape and named no pair.
 */
export function withheldSentence(view: TranscriptView): string {
  if (view.released || view.failedPair === '') return '';
  return formatDeniedAction(STRINGS.privilegeDeniedAction, view.failedPair, STRINGS.transcriptRefusedAction);
}

/** The transcript page's store: one read, its phase and its answer. */
export class TranscriptStore {
  private phaseValue: TranscriptPhase = 'loading';
  private viewValue: TranscriptView | null = null;
  private generation = 0;
  private readonly subscribers = new Set<() => void>();

  private readonly request: TranscriptRequest;

  constructor(request: TranscriptRequest) {
    this.request = request;
  }

  phase(): TranscriptPhase {
    return this.phaseValue;
  }

  view(): TranscriptView | null {
    return this.viewValue;
  }

  /** Call `listener` on every change; answers the function that stops it. */
  subscribe(listener: () => void): () => void {
    this.subscribers.add(listener);
    return () => this.subscribers.delete(listener);
  }

  /** Read conversation `id`. A later call supersedes an earlier one still in flight. */
  async open(id: string): Promise<void> {
    this.generation += 1;
    const generation = this.generation;
    this.phaseValue = 'loading';
    this.viewValue = null;
    this.notify();
    if (id === '') {
      this.phaseValue = 'gone';
      this.notify();
      return;
    }
    const result = await this.request(transcriptPath(id));
    if (generation !== this.generation) return;
    if (result.kind === 'ok') {
      const view = parseTranscript(result.body);
      this.viewValue = view;
      this.phaseValue = view === null ? 'refused' : 'ready';
    } else {
      this.phaseValue = result.status === 404 ? 'gone' : 'refused';
    }
    this.notify();
  }

  /** Forget the answer, so a page left and opened again reads afresh. */
  reset(): void {
    this.generation += 1;
    this.phaseValue = 'loading';
    this.viewValue = null;
    this.notify();
  }

  private notify(): void {
    for (const listener of this.subscribers) listener();
  }
}
