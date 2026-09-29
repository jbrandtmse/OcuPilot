import { ExplainEntry, type ExplainEntryRequest } from '../core/explain-entry';
import { assembleEntryContext, type ScreenContextPayload } from '../core/screen-context';
import type { ScreenStores } from '../core/screen-store';
import type { ScreenDeclaration } from '../core/screens.generated';

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

/**
 * The context the panel sends for `request` (DW-1838): `assembleEntryContext` over the request's
 * screen and that screen's own store in `stores`, read as `Panel.contextInputs` reads it, with
 * sharing on, no entity and `rowCap` -- for a page spec, which mounts the page that publishes the
 * rows and hands the entry over without mounting the panel that sends them.
 */
export function explainContext(stores: ScreenStores, request: ExplainEntryRequest | null, rowCap = 200): ScreenContextPayload | null {
  if (request === null) return null;
  const store = stores.for(request.screen.descriptor, request.screen.refreshRates);
  return assembleEntryContext({
    descriptor: request.screen,
    namespace: 'HSCUSTOM',
    entity: '',
    share: true,
    rows: store.data(),
    filter: store.filter(),
    sort: store.sort(),
    direction: store.direction(),
    rowCap,
    row: request.row,
  });
}

/** `row` narrowed to `screen`'s declared context fields, as a sent row holds it. */
export function narrowedEntry(screen: ScreenDeclaration, row: unknown): Record<string, unknown> {
  const source = row as Record<string, unknown>;
  return Object.fromEntries(screen.context.fields.filter((field) => field in source).map((field) => [field, source[field]]));
}
