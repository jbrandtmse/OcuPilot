import { AgentStatus } from '../core/agent-status';
import type { ApiService } from '../core/api';

/**
 * An `AgentStatus` over a stubbed list read, for the specs that mount something which injects it
 * without being about it -- the frame, the rail, the guard's route table and the Definition form.
 *
 * It is the real class rather than a hand-written double, so a spec that arranges "no definition
 * is enabled" arranges it the way the instance does: a list body with the rows it names, read
 * through the real narrowing. Construct it and do not `load()` and `answered()` is false, which is
 * every consumer's "render nothing"; `load()` it and the rows decide.
 */
export function stubAgentStatus(rows: { enabled: boolean }[] = []): AgentStatus {
  // The array is read on every call rather than snapshotted, so a test arranges an Enable the way
  // the instance does -- the rows change, and the next read answers differently.
  const api = {
    requestJson: async () => ({
      kind: 'ok' as const,
      status: 200,
      body: { definitions: rows.map((row, index) => ({ id: String(index), enabled: row.enabled })) },
    }),
  };
  return new AgentStatus({ api: api as unknown as ApiService });
}
