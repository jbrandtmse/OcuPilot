import { AGENT_CONTEXT_PATH, AgentContext, NO_CONTEXT_INFO, type AgentContextInfo } from '../core/agent-context';
import type { ApiService } from '../core/api';

/**
 * An `AgentContext` over a stubbed `GET/PUT /agent/context`, for the specs that mount something
 * which injects it without being about it, and for the ones that are -- mirrors
 * `testing/agent-status.ts`.
 *
 * The real class over a stubbed transport, so a spec that arranges "sharing is on, six rows, a
 * remote provider" arranges it the way the instance does. `PUT` mutates the same in-memory row
 * the next `GET` reads, so `setShare` round-trips like the real handler's `HandleUpdate`
 * (`Api/Context.cls`: both answer the same body). Construct it and do not `load()` and
 * `answered()` is false, which is the chip's own "render nothing yet".
 */
export function stubAgentContext(overrides: Partial<AgentContextInfo> = {}): AgentContext {
  let row: AgentContextInfo = { ...NO_CONTEXT_INFO, ...overrides };
  const api = {
    requestJson: async (path: string, init: { method?: string; body?: string } = {}) => {
      if (path !== AGENT_CONTEXT_PATH) {
        return { kind: 'error', status: 404, code: null, reason: null, detail: null };
      }
      if ((init.method ?? 'GET') === 'PUT') {
        const parsed = JSON.parse(init.body ?? '{}') as { share?: unknown };
        row = { ...row, share: parsed.share === true };
      }
      return { kind: 'ok', status: 200, body: row };
    },
  };
  return new AgentContext({ api: api as unknown as ApiService });
}
