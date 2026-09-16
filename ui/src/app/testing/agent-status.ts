import {
  AGENT_RESTRAINT_PATH,
  AgentStatus,
  type Restraint,
  UNRESTRAINED,
} from '../core/agent-status';
import type { ApiService } from '../core/api';

/**
 * An `AgentStatus` over stubbed reads, for the specs that mount something which injects it
 * without being about it -- the frame, the rail, the guard's route table and the Definition form
 * -- and for the ones that are.
 *
 * It is the real class rather than a hand-written double, so a spec that arranges "no definition
 * is enabled" or "the kill switch is on" arranges it the way the instance does: a body with the
 * keys it names, read through the real narrowing. Construct it and do not `load()` and
 * `answered()` is false, which is every consumer's "render nothing"; `load()` it and the bodies
 * decide.
 *
 * Both objects are read on every call rather than snapshotted, so a test arranges an Enable, or a
 * switch being flipped, the way the instance does -- the state changes, and the next read answers
 * differently.
 */
export function stubAgentStatus(
  rows: { enabled: boolean }[] = [],
  restraint: Partial<Restraint> = {}
): AgentStatus {
  const api = {
    requestJson: async (path: string) => ({
      kind: 'ok' as const,
      status: 200,
      body:
        path === AGENT_RESTRAINT_PATH
          ? { ...UNRESTRAINED, ...restraint }
          : { definitions: rows.map((row, index) => ({ id: String(index), enabled: row.enabled })) },
    }),
  };
  return new AgentStatus({ api: api as unknown as ApiService });
}
