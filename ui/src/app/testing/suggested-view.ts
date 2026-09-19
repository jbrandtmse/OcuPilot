import { type AgentStatus, UNRESTRAINED, type Restraint } from '../core/agent-status';
import type { ApiService } from '../core/api';
import type { JsonResult } from '../core/api';
import type { ScopeService } from '../core/scope';
import { SuggestedView } from '../core/suggested-view';

/**
 * A `SuggestedView` over a stubbed application-errors read, for the specs that mount something
 * which injects it without being about it -- the frame and its two wire specs. A spec that is
 * about the block builds its own instance over its own transport, so it can arrange the answer
 * and count the calls (`panel.spec.ts`).
 *
 * It is the real class rather than a hand-written double, so a spec that arranges "the log is
 * clean" or "the read is refused" arranges it the way the instance does: an answer with the keys
 * it names, read through the real narrowing. Construct it and do not `load()` and `answered()` is
 * false, which is every consumer's "render nothing".
 */
export function stubSuggestedView(
  options: {
    /** The `logs/errors/dates` rows, newest date first. */
    rows?: { date: string; count: number }[];
    /** An answer to give instead of `rows`, for a refusal or a fault. */
    answer?: JsonResult<unknown>;
    restraint?: Partial<Restraint>;
    namespace?: string;
  } = {}
): SuggestedView {
  const answer: JsonResult<unknown> =
    options.answer ?? { kind: 'ok', status: 200, body: { rows: options.rows ?? [] } };
  const api = { requestJson: async () => answer };
  const agentStatus = { restraint: () => ({ ...UNRESTRAINED, ...(options.restraint ?? {}) }) };
  const scope = { namespace: () => options.namespace ?? 'HSCUSTOM' };
  return new SuggestedView({
    api: api as unknown as ApiService,
    agentStatus: agentStatus as unknown as AgentStatus,
    scope: scope as unknown as ScopeService,
  });
}
