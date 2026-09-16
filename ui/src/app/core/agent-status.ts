/**
 * Whether this instance holds an enabled agent definition (FR-28).
 *
 * One fact, read from one route, and re-read rather than remembered. The panel's two empty
 * states, the rail's attention dot and the first-login gate all turn on it, and none of them
 * stores a flag of its own: the condition is the instance's own rows, so it clears the moment a
 * definition is enabled and nothing has to be told to forget.
 *
 * **The read is the ungated selection projection.** `GET /api/ocupilot/agent/definitions` is the
 * one agent route that gates on nothing beyond the router (`Api/Definitions.cls:125 HandleList`),
 * so a caller who is not an OcuPilot administrator -- exactly the audience the
 * configuration-empty state is written for -- can still answer the question. Every other agent
 * route would refuse them, and a refusal is not an answer.
 *
 * **A failed read leaves the previous answer and waits.** It never guesses: before the first
 * answer `answered()` is false and every consumer renders nothing, because `configured()` false
 * on an unanswered read would show an unconfigured instance's banner over one that is configured.
 * The retry is the next change event, not a timer -- the only thing that can change this fact is
 * a write to a definition, and every one of those publishes on the bus (AD-14).
 *
 * Framework-free, like the rest of `core/` (AD-19, DW-177), so `ui/tools/agent-status.test.mjs`
 * executes it under `node --test`.
 */

import type { ApiService } from './api';
import type { ChangeBus, ChangeEvent } from './change-bus';
import type { ConnectivityService } from './connectivity';

/** Absolute from the origin root, through the one API service (AD-20). */
export const AGENT_DEFINITIONS_PATH = '/api/ocupilot/agent/definitions';

/** The entity type an agent definition's change events travel under (AD-13, AD-14). */
export const AGENT_DEFINITION_ENTITY = 'agent-definition';

/** An agent definition is instance configuration, so its references carry AD-13's instance scope. */
export const AGENT_DEFINITION_SCOPE = 'instance';

/**
 * The Definitions list's declared route, whose navigation verdict is the privilege half of the
 * unconfigured state: may this caller enable a definition (AD-8)? The panel, the rail's dot and
 * the form's gate banner all read the map for this one route, so none of them mints a second
 * privilege source.
 */
export const DEFINITIONS_ROUTE = 'agent/definitions';

export interface AgentStatusOptions {
  readonly api: ApiService;
  /**
   * The one client bus (AD-14). Optional so a test that is not about the re-read can leave it
   * out; production always supplies it, because without it the answer would never refresh.
   */
  readonly bus?: ChangeBus;
  /**
   * Where a failed read is parked (DW-135's shape, as `NavigationService` and `ScopeService` use
   * it). Optional so a test that is not about the re-read can leave it out.
   *
   * It is not optional in substance. The bus cannot be the only retry here: the one event that
   * would re-read this is a definition changing, and on the instance this whole story is about
   * there is no definition to change -- the panel, the dot and the gate that would prompt one are
   * all withheld while `answered()` is false. Without this, a single transport fault at sign-in
   * removes the configuration-empty surface for the life of the tab.
   */
  readonly connectivity?: ConnectivityService;
}

function rowsOf(body: unknown): readonly unknown[] {
  if (body === null || typeof body !== 'object') return [];
  const rows = (body as Record<string, unknown>)['definitions'];
  return Array.isArray(rows) ? rows : [];
}

function isEnabled(row: unknown): boolean {
  if (row === null || typeof row !== 'object') return false;
  return (row as Record<string, unknown>)['enabled'] === true;
}

export class AgentStatus {
  private readonly api: ApiService;

  private readonly connectivity: ConnectivityService | null;

  private configuredValue = false;

  private answeredValue = false;

  /**
   * Bumped by `reset()`, read across the await. An answer about the instance a departed
   * principal was reading must not land on the one who replaced them -- the shape
   * `InstanceService` and `NavigationService` both use for the same hazard (AD-8).
   */
  private generation = 0;

  /**
   * Bumped by every `load()`, read across the await, so only the **newest** read settles the
   * answer. `generation` alone does not cover this: two reads issued without a `reset()` between
   * them carry the same generation, and the one that happens to return last wins whether or not
   * it asked last. That is reachable here -- `App` loads on every signed-in pass and the bus
   * loads on every definition change -- and the answer it gets wrong is the one an `Enable` just
   * corrected, which would re-light the dot, the banner and the example card after they cleared.
   */
  private request = 0;

  private readonly listeners = new Set<() => void>();

  constructor(options: AgentStatusOptions) {
    this.api = options.api;
    this.connectivity = options.connectivity ?? null;
    // Never unsubscribed: this service lives as long as the tab does, and a bus subscription
    // dropped on sign-out would leave the next principal's panel unable to notice an Enable.
    options.bus?.subscribe((event) => this.onChange(event));
  }

  /** Whether a read has ever completed. Nothing renders an audience before it has. */
  answered(): boolean {
    return this.answeredValue;
  }

  /** Whether the instance holds at least one definition with `enabled: true`. */
  configured(): boolean {
    return this.configuredValue;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /**
   * Read the list and settle `configured()`.
   *
   * A refusal or an unreachable instance settles nothing: the previous answer stands, and the
   * next change event asks again. A first read that fails therefore leaves `answered()` false,
   * which is what keeps the panel from picking an audience it has no evidence for.
   */
  async load(): Promise<void> {
    const generation = this.generation;
    const request = (this.request += 1);
    const result = await this.api.requestJson<unknown>(AGENT_DEFINITIONS_PATH);
    if (generation !== this.generation) return;
    if (request !== this.request) return;
    if (result.kind !== 'ok') {
      // Parked for one re-run when the instance answers again. A refusal is parked too: it is not
      // an answer, and the read is ungated, so the only thing a 403 here can mean is that the
      // request never reached the route it was addressed to.
      this.connectivity?.retryWhenReachable(AGENT_DEFINITIONS_PATH, () => void this.load());
      return;
    }
    const next = rowsOf(result.body).some(isEnabled);
    // Notified only when the answer moved, or when there was no answer before: a re-read that
    // confirms what is already on screen must not re-render the panel, the rail and the form.
    const moved = !this.answeredValue || this.configuredValue !== next;
    this.configuredValue = next;
    this.answeredValue = true;
    if (moved) this.notify();
  }

  /**
   * Forget the answer, so the next `load()` asks again. The read is ungated, but the rows are
   * still this principal's view of the instance, and sign-out clears the tab in place -- the same
   * gesture that drops the navigation map and the namespace list (AD-8).
   */
  reset(): void {
    this.generation += 1;
    this.request += 1;
    this.configuredValue = false;
    this.answeredValue = false;
    this.notify();
  }

  /**
   * A definition changed: re-read (AD-14 -- consumers re-fetch, they never patch).
   *
   * `changed` only. The bus also carries `proposal-open` and `proposal-closed`, which say a
   * proposal against that entity is live rather than that the instance moved, so neither can
   * change the answer and neither should cost a request.
   */
  private onChange(event: ChangeEvent): void {
    if (event.kind !== 'changed' || event.type !== AGENT_DEFINITION_ENTITY) return;
    void this.load();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
