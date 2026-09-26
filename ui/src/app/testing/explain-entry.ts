import { ExplainEntry } from '../core/explain-entry';

/** The gate facts a page spec arranges for "Explain this entry". */
export interface ExplainEntryState {
  answered: boolean;
  configured: boolean;
  killSwitch: boolean;
  busy: boolean;
  share: boolean;
  contextAnswered: boolean;
}

/**
 * A real `ExplainEntry` over three fake stores whose answers a spec sets through `state`, then
 * announces with `fire()` -- for the log and audit page specs, which mount a page that injects it
 * without mounting the panel that takes its requests.
 */
export function stubExplainEntry(overrides: Partial<ExplainEntryState> = {}): {
  readonly entry: ExplainEntry;
  readonly state: ExplainEntryState;
  readonly fire: () => void;
} {
  const state: ExplainEntryState = { answered: true, configured: true, killSwitch: false, busy: false, share: true, contextAnswered: true, ...overrides };
  const listeners = new Set<() => void>();
  const subscribe = (listener: () => void): (() => void) => {
    listeners.add(listener);
    return () => {
      listeners.delete(listener);
    };
  };
  const entry = new ExplainEntry({
    agentStatus: {
      answered: () => state.answered,
      configured: () => state.configured,
      restraint: () => ({ killSwitch: state.killSwitch }) as never,
      subscribe,
    },
    agentContext: { answered: () => state.contextAnswered, share: () => state.share, subscribe },
    turn: { busy: () => state.busy, subscribe },
  });
  const fire = (): void => {
    for (const listener of [...listeners]) listener();
  };
  return { entry, state, fire };
}
