/**
 * The handlers that run a screen's declared actions (AD-5, AD-19).
 *
 * A descriptor declares its actions; the screen that can carry one out registers a handler for
 * it here, keyed by the descriptor's class name and the action's declared id. The command bar
 * and the command box offer a primary action only while `has` answers `true`, and both surfaces
 * run it through `run`, so neither draws a control nothing can act on.
 *
 * Framework-free, like the rest of `core/`: a plain subscribable that components mirror into a
 * signal.
 */

import { STRINGS } from './strings.ts';

/** What runs one declared action. */
export type ScreenActionRun = () => void;

/**
 * The well-known id of the Refresh action a screen with a read registers (DW-260).
 *
 * **It is not a descriptor `primaryAction` or `rowAction`.** Refresh re-reads whatever the screen
 * already reads; it is shell behaviour over a declared read, not one of the screen's own declared
 * actions, and adding it to a descriptor would have made every Epic 2 screen action-bearing --
 * which is what the empty state's agent invitation and `AdminPort.TYPESUFFIXES` both key off.
 * Registering it here instead is what lets both surfaces offer it on exactly the screens that can
 * carry it out: Home registers none, because it reads nothing, and the audit viewer registers only
 * once it has a search to re-run.
 */
export const REFRESH_ACTION_ID = 'refresh';

/**
 * The label a surface draws for `actionId`.
 *
 * A declared action's label is its own identifier until a screen carries a label key for it.
 * Refresh is the one action with copy of its own, and both the command bar and the command box
 * resolve it through here, so the two surfaces cannot name the same action two ways -- which is
 * exactly what `command-bar.spec.ts`'s reachability assertion compares.
 */
export function actionLabel(actionId: string): string {
  return ACTION_LABELS[actionId] ?? actionId;
}

/**
 * The actions that carry published copy, keyed by the id a descriptor declares (or, for Refresh,
 * by the well-known id above).
 *
 * An id with no entry renders as itself, which is the state every action was in until a screen
 * published words for one: `ActionDeclaration` carries no label key, so this map is where a
 * declared action's name lives until it does. Both the command bar and the command box resolve
 * through here, so the two surfaces cannot name the same action two ways.
 */
const ACTION_LABELS: Readonly<Record<string, string>> = {
  [REFRESH_ACTION_ID]: STRINGS.actionRefresh,
  enable: STRINGS.agentDefinitionEnable,
  disable: STRINGS.agentDefinitionDisable,
  'set-default': STRINGS.agentDefinitionSetDefault,
};

export class ScreenActions {
  private readonly handlers = new Map<string, Map<string, { readonly run: ScreenActionRun }>>();

  private readonly listeners = new Set<() => void>();

  /**
   * Register `run` for `actionId` on `descriptor`, replacing any handler already there, and
   * return the function that removes it. The remover removes only the registration it made, so
   * a stale remover called after a re-registration leaves the newer one in place, even when both
   * registered the same function.
   */
  register(descriptor: string, actionId: string, run: ScreenActionRun): () => void {
    let forDescriptor = this.handlers.get(descriptor);
    if (forDescriptor === undefined) {
      forDescriptor = new Map();
      this.handlers.set(descriptor, forDescriptor);
    }
    const registration = { run };
    forDescriptor.set(actionId, registration);
    this.notify();

    return () => {
      const current = this.handlers.get(descriptor);
      if (current?.get(actionId) !== registration) return;
      current.delete(actionId);
      if (current.size === 0) this.handlers.delete(descriptor);
      this.notify();
    };
  }

  /** Whether a handler is registered for `actionId` on `descriptor`. An empty id never has one. */
  has(descriptor: string, actionId: string): boolean {
    if (actionId === '') return false;
    return this.handlers.get(descriptor)?.has(actionId) ?? false;
  }

  /** Run the registered handler once, and report whether there was one. */
  run(descriptor: string, actionId: string): boolean {
    if (actionId === '') return false;
    const registration = this.handlers.get(descriptor)?.get(actionId);
    if (registration === undefined) return false;
    registration.run();
    return true;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  private notify(): void {
    for (const listener of this.listeners) listener();
  }
}
