/**
 * The copy-out draft of one proposal (Story 14.1, AD-59): the route, the answer's shape, and the
 * one request that takes it.
 *
 * **The script is the instance's.** The instance renders it from the stored proposal through the
 * tool's own declared port and closes the row as `canceled` with the reason `draft`; this module
 * posts the id and parses what came back. It composes no step, substitutes no value and holds no
 * copy: the parsed script lives only in the panel that asked for it, for the rest of the session.
 *
 * Framework-free (AD-19), so `tools/draft.test.mjs` runs it under `node --test`.
 */

import type { ApiService } from './api';

/**
 * The proposal routes' root. `core/turn.ts` declares the same root for confirm and cancel;
 * `tools/draft.test.mjs` holds the two equal, because importing it here would make the two modules
 * import each other.
 */
export const DRAFT_PROPOSAL_PATH = '/api/ocupilot/proposal';

/** `POST` here takes proposal `id`'s script instead of confirming it. Absolute (AD-20). */
export function proposalDraftPath(id: string): string {
  return DRAFT_PROPOSAL_PATH + '/' + encodeURIComponent(id) + '/draft';
}

/**
 * One step of a script: a `rest` call against the admin API, or an `objectscript` call a `%SYS`
 * class makes. The kind is the instance's word, carried as-is.
 */
export interface DraftStep {
  readonly kind: string;
  readonly text: string;
}

/** A taken script: its steps in the order they run, and the secret names each `<Name>` stands for. */
export interface ProposalDraft {
  readonly steps: readonly DraftStep[];
  readonly placeholders: readonly string[];
}

/**
 * What one draft request answered.
 *
 * `ok` means the instance closed the row as a draft: `state` and `closedReason` are the row's own,
 * and `draft` is the script, or `null` when the body carried none this module can read. A refusal
 * carries the envelope's `status`, `code` and written `reason`; `state` is the row's own only when
 * the refusal's `detail` names one, and `''` when the row was left as it was. `status` 0 is a
 * request that never reached the instance.
 */
export interface DraftOutcome {
  readonly ok: boolean;
  readonly state: string;
  readonly closedReason: string;
  readonly confirmedAt: string;
  readonly status: number;
  readonly code: string;
  readonly reason: string;
  readonly draft: ProposalDraft | null;
}

function asRecord(value: unknown): Record<string, unknown> | null {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : null;
}

function textOf(source: Record<string, unknown> | null, key: string): string {
  const value = source === null ? undefined : source[key];
  return typeof value === 'string' ? value : '';
}

/**
 * The script a 200 body's `draft` carries, or `null`.
 *
 * **All of it or none of it.** A step whose `text` is missing or empty, or whose `kind` is not a
 * string, makes the whole script unreadable rather than dropping that step: a script with a step
 * silently missing is a different change from the one the card reviewed, and it is exactly the
 * script a user would run. A script with no steps is `null` too. Placeholder names that are not
 * strings are dropped, because they describe the script rather than being part of it.
 */
export function parseDraft(value: unknown): ProposalDraft | null {
  const draft = asRecord(value);
  if (draft === null) return null;
  const rawSteps = draft['steps'];
  if (!Array.isArray(rawSteps) || rawSteps.length === 0) return null;
  const steps: DraftStep[] = [];
  for (const raw of rawSteps) {
    const step = asRecord(raw);
    if (step === null) return null;
    const kind = step['kind'];
    const text = step['text'];
    if (typeof kind !== 'string' || typeof text !== 'string' || text === '') return null;
    steps.push({ kind, text });
  }
  const rawPlaceholders = draft['placeholders'];
  const placeholders = Array.isArray(rawPlaceholders)
    ? rawPlaceholders.filter((name): name is string => typeof name === 'string')
    : [];
  return { steps, placeholders };
}

/** A request that got no envelope back: nothing is known about the row. */
const UNANSWERED: DraftOutcome = {
  ok: false,
  state: '',
  closedReason: '',
  confirmedAt: '',
  status: 0,
  code: '',
  reason: '',
  draft: null,
};

/**
 * Take proposal `id`'s script instead of confirming it: `POST` the draft route with no body, and
 * parse the answer. Never throws; a transport fault or an install in progress answers
 * `UNANSWERED`.
 */
export async function requestDraft(api: Pick<ApiService, 'requestJson'>, id: string): Promise<DraftOutcome> {
  if (id === '') return UNANSWERED;
  const result = await api.requestJson<Record<string, unknown>>(proposalDraftPath(id), { method: 'POST' });
  if (result.kind === 'ok') {
    const body = asRecord(result.body);
    return {
      ok: true,
      state: textOf(body, 'state'),
      closedReason: textOf(body, 'closedReason'),
      confirmedAt: textOf(body, 'confirmedAt'),
      status: result.status,
      code: '',
      reason: '',
      draft: body === null ? null : parseDraft(body['draft']),
    };
  }
  if (result.kind !== 'error') return UNANSWERED;
  return {
    ok: false,
    state: textOf(result.detail, 'state'),
    closedReason: textOf(result.detail, 'closedReason'),
    confirmedAt: '',
    status: result.status,
    code: result.code ?? '',
    reason: result.reason ?? '',
    draft: null,
  };
}
