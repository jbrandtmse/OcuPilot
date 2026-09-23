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
 * The label a surface draws for `actionId` on `descriptor`.
 *
 * A declared action's label is its own identifier until a screen carries published copy for it.
 * Both the command bar and the command box resolve through here, so the two surfaces cannot name
 * the same action two ways -- which is exactly what `command-bar.spec.ts`'s reachability assertion
 * compares.
 *
 * **The descriptor is not decoration** (DW-370). One action id means different things on different
 * screens: `create` is "Create" on the Definitions list and "Switch off a user" on Switches, and a
 * map keyed by the bare id can only ever draw one of them. A screen's own entry wins; an id the
 * screen publishes nothing for falls back to the shared map, which is where an action that means
 * the same thing everywhere lives.
 */
export function actionLabel(descriptor: string, actionId: string): string {
  const own = Object.hasOwn(DESCRIPTOR_ACTION_LABELS, descriptor)
    ? DESCRIPTOR_ACTION_LABELS[descriptor]
    : undefined;
  if (own !== undefined && Object.hasOwn(own, actionId)) return own[actionId];
  return Object.hasOwn(ACTION_LABELS, actionId) ? ACTION_LABELS[actionId] : actionId;
}

/**
 * The actions that carry published copy wherever they appear, keyed by the id a descriptor
 * declares (or, for Refresh, by the well-known id above).
 *
 * An id with no entry here and none on its screen renders as itself, which is the state every
 * action was in until a screen published words for one: `ActionDeclaration` carries no label key,
 * so these maps are where a declared action's name lives until it does.
 */
const ACTION_LABELS: Readonly<Record<string, string>> = {
  [REFRESH_ACTION_ID]: STRINGS.actionRefresh,
  create: STRINGS.actionCreate,
  enable: STRINGS.agentDefinitionEnable,
  disable: STRINGS.agentDefinitionDisable,
  // The published verb a delete carries wherever one is offered -- the row menu, the command bar,
  // the command box and the typed-name dialog's own title and button. A screen whose delete means
  // something narrower publishes its own words below (Switches' removes a hold, not an entity).
  delete: STRINGS.actionDelete,
  'set-default': STRINGS.agentDefinitionSetDefault,
};

/**
 * The actions one screen publishes its own words for, keyed by the descriptor class name the
 * mirror carries and then by the action id (DW-370).
 *
 * Switches is the first screen here: its `create` adds a per-user hold and its `delete` removes
 * one, and EXPERIENCE.md publishes a sentence for each. Both ids also mean something else
 * elsewhere, which is the whole reason this map is keyed by descriptor.
 */
const DESCRIPTOR_ACTION_LABELS: Readonly<Record<string, Readonly<Record<string, string>>>> = {
  'OcuPilot.Screen.Descriptor.AgentSwitches': {
    create: STRINGS.agentSwitchesHoldAdd,
    delete: STRINGS.agentSwitchesHoldRemove,
  },
  // Story 7.2: the Users list's three value-carrying row actions.
  'OcuPilot.Screen.Descriptor.UserList': {
    'set-password': STRINGS.userActionSetPassword,
    'add-role': STRINGS.userActionAddRole,
    'remove-role': STRINGS.userActionRemoveRole,
  },
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
