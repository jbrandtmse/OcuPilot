/**
 * Two facts about the agent on this instance: whether a definition is enabled (FR-28), and whether
 * anything restrains it for this caller (FR-19, FR-20).
 *
 * Both are read from routes and re-read rather than remembered. The panel's empty states and
 * banners, the rail's attention dot, the panel's footer line and the first-login gate all turn on
 * them, and none of them stores a flag of its own: the conditions are the instance's own rows, so
 * they clear the moment the rows do and nothing has to be told to forget.
 *
 * **The restraint fact is the server's verdict, projected** -- `OcuPilot.Kernel.Restraint` is the
 * one place that decides whether a write may happen (AD-30), and this carries what it answered.
 * Nothing here re-derives it, and no consumer issues a second call for it.
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
import { STRINGS, stringFor } from './strings.ts';

/** Absolute from the origin root, through the one API service (AD-20). */
export const AGENT_DEFINITIONS_PATH = '/api/ocupilot/agent/definitions';

/**
 * The calling user's own restraint verdict, absolute from the origin root (AD-20).
 *
 * Ungated beyond the router, like the definitions list and for the same reason: the audience for
 * the kill-switch banner is precisely the people who cannot change it, and a refusal is not an
 * answer.
 */
export const AGENT_RESTRAINT_PATH = '/api/ocupilot/agent/restraint';

/** The entity type an agent definition's change events travel under (AD-13, AD-14). */
export const AGENT_DEFINITION_ENTITY = 'agent-definition';

/** The entity type the switches and the per-user holds travel under (AD-13, AD-14). */
export const AGENT_SWITCH_ENTITY = 'agent-switch';

/**
 * The entity type the instance's auditing configuration travels under (AD-13, AD-14).
 *
 * It is here because `writesMarked` is computed from it: turning auditing off is what makes the
 * panel's "agent writes are not being marked" banner true, and the confirm that does it publishes
 * a change event on this type. Without it the writing user's own tab would carry the stale answer
 * until its next signed-in pass.
 */
export const AUDITING_CONFIG_ENTITY = 'auditing-configuration';

/**
 * The entity types a change to which can move this payload's own answer, so a `changed` event on
 * one costs a re-read and an event on anything else costs nothing.
 *
 * It is a roster rather than a chain of comparisons because the next entity that feeds a restraint
 * fact is added by naming it here, and because `ui/tools/agent-status.test.mjs` can then hold the
 * roster rather than re-deriving which types matter.
 */
export const RESTRAINT_ENTITIES: readonly string[] = [
  AGENT_DEFINITION_ENTITY,
  AGENT_SWITCH_ENTITY,
  AUDITING_CONFIG_ENTITY,
];

/**
 * OcuPilot's own agent configuration -- definitions and the instance switches alike -- is instance
 * configuration, so its references carry AD-13's instance scope. Both entity types' change events
 * travel under it, and the switches, being one row per instance, use it as their id as well: there
 * is no narrower target for a screen to re-fetch on.
 */
export const AGENT_DEFINITION_SCOPE = 'instance';

/**
 * The restraint verdict, as `GET /agent/restraint` projects it.
 *
 * `footerKey` is a **string key**, not a sentence: the server chooses which of the published
 * read-only lines the panel renders and the client resolves it through `stringFor`, so the line
 * cannot say two things at once and the client composes none of it (AD-39).
 */
export interface Restraint {
  readonly blocked: boolean;
  readonly code: string;
  readonly reason: string;
  readonly footerKey: string;
  readonly killSwitch: boolean;
  /** `'everyone'`, `'you'` or `''` -- which word the published banner's slot resolves to. */
  readonly killSwitchAudience: string;
  readonly killSwitchReason: string;
  readonly enforcedReadOnly: boolean;
  /**
   * Whether the instance was marking agent writes when that was last observed (AD-15).
   *
   * **Not part of the verdict**: marking is not a restraint (AD-30), so it blocks nothing and the
   * agent is not switched off by it. Only its `false` arm is rendered -- the panel's `not-marked`
   * banner -- and nothing anywhere says marking is working, which is what makes the fact being a
   * recorded observation rather than a live read acceptable.
   */
  readonly writesMarked: boolean;
}

/**
 * The footer keys the verdict may answer with, which is the roster
 * `ui/tools/agent-status.test.mjs` holds against `core/strings.ts`.
 *
 * The server half is `OcuPilot.Test.Restraint`, which pins the same three literals against
 * `OcuPilot.Kernel.Restraint`'s own parameters, so a key renamed on either side reddens.
 * `statusReadOnlyForYou` is Story 14.5's and is deliberately not here yet.
 */
export const FOOTER_KEYS = [
  'statusReadOnlyOff',
  'statusReadOnlyEnforced',
  'statusReadOnlyByDefinition',
] as const;

/** The verdict before one has been read, and the one a malformed body falls back to. */
export const UNRESTRAINED: Restraint = {
  blocked: false,
  code: '',
  reason: '',
  footerKey: FOOTER_KEYS[0],
  killSwitch: false,
  killSwitchAudience: '',
  killSwitchReason: '',
  enforcedReadOnly: false,
  // `true`, deliberately: an unanswered read must never show the not-marked banner over a healthy
  // instance, and the banner's absence is never a claim that marking works.
  writesMarked: true,
};

/** The audience word the published kill-switch banner's `<everyone / you>` slot resolves to. */
export const KILL_SWITCH_AUDIENCE_EVERYONE = 'everyone';

/** See `KILL_SWITCH_AUDIENCE_EVERYONE`. */
export const KILL_SWITCH_AUDIENCE_YOU = 'you';

/** The slot the published kill-switch banner leaves for its audience. */
export const AUDIENCE_PLACEHOLDER = '<everyone / you>';

/** The slot it leaves for the operator's own reason. */
export const KILL_SWITCH_REASON_PLACEHOLDER = '<reason>';

/**
 * The two words the audience slot resolves to, taken **out of the published placeholder itself**
 * rather than written here. The slot spells both options, so resolving it is resolution and not
 * new copy -- which is what keeps the client from composing a sentence of its own (AD-39).
 */
const AUDIENCE_WORDS = AUDIENCE_PLACEHOLDER.slice(1, -1).split(' / ');

/**
 * `The agent is switched off for <everyone / you>: <reason>.` resolved to the audience the verdict
 * named and the reason the operator wrote -- the panel's banner, the proposal card's status line
 * and the rail's attention reason all render this one sentence.
 *
 * An audience the verdict did not name resolves to the broader word, which is the safer of the two
 * to be shown by mistake.
 */
export function formatKillSwitch(template: string, audience: string, reason: string): string {
  const word = audience === KILL_SWITCH_AUDIENCE_YOU ? AUDIENCE_WORDS[1] : AUDIENCE_WORDS[0];
  return template
    .split(AUDIENCE_PLACEHOLDER)
    .join(word)
    .split(KILL_SWITCH_REASON_PLACEHOLDER)
    .join(reason);
}

/**
 * The sentence a restraint state reads as: the published kill-switch banner with both slots
 * resolved when the switch is on, and otherwise the read-only line the verdict's own `footerKey`
 * names.
 *
 * **This precedence has one home.** Home's agent-status line and the panel's kill-switch banner
 * both render what this returns, so neither re-derives which of the two sentences applies and the
 * client composes none of it (AD-39). Zero new strings: both arms resolve a published one.
 */
export function restraintSentence(restraint: Restraint): string {
  return restraint.killSwitch
    ? formatKillSwitch(
        STRINGS.agentKillSwitchBanner,
        restraint.killSwitchAudience,
        restraint.killSwitchReason
      )
    : readOnlyFooterLine(restraint);
}

/**
 * `restraintSentence`'s read-only arm on its own -- the line the panel's footer renders
 * unconditionally, beside its own kill-switch banner rather than instead of it.
 *
 * The footer cannot render the ladder: with the kill switch on and read-only by definition, the
 * panel shows the kill-switch banner *and* the by-definition footer line, which `panel.spec.ts`
 * pins. So the arm is exported rather than re-derived at the call site.
 */
export function readOnlyFooterLine(restraint: Restraint): string {
  return stringFor(restraint.footerKey);
}

/**
 * Whether a read-only state applies, which is what turns the panel's footer line restrained.
 *
 * Reads `FOOTER_KEYS[0]` rather than spelling `'statusReadOnlyOff'` again: the panel repeated the
 * off key as a bare literal beside the one `FOOTER_KEYS` declares, and a rename that missed the
 * literal would leave a footer permanently restrained with no test saying so.
 */
export function readOnlyApplies(restraint: Restraint): boolean {
  return restraint.footerKey !== FOOTER_KEYS[0];
}

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

function flagAt(source: Record<string, unknown>, key: string): boolean {
  return source[key] === true;
}

function textAt(source: Record<string, unknown>, key: string): string {
  const value = source[key];
  return typeof value === 'string' ? value : '';
}

/**
 * The verdict a response body carries, narrowed key by key.
 *
 * A body that is not an object, or whose `footerKey` is not one the server may answer with, falls
 * back to `UNRESTRAINED` in that key rather than being rendered: `footerKey` reaches `stringFor`,
 * which answers `''` for a key the source does not hold, and a blank footer line says less than
 * the off one.
 */
function restraintOf(body: unknown): Restraint {
  if (body === null || typeof body !== 'object') return UNRESTRAINED;
  const row = body as Record<string, unknown>;
  const footerKey = textAt(row, 'footerKey');
  return {
    blocked: flagAt(row, 'blocked'),
    code: textAt(row, 'code'),
    reason: textAt(row, 'reason'),
    footerKey: (FOOTER_KEYS as readonly string[]).includes(footerKey)
      ? footerKey
      : UNRESTRAINED.footerKey,
    killSwitch: flagAt(row, 'killSwitch'),
    killSwitchAudience: textAt(row, 'killSwitchAudience'),
    killSwitchReason: textAt(row, 'killSwitchReason'),
    enforcedReadOnly: flagAt(row, 'enforcedReadOnly'),
    // Absent reads as the UNRESTRAINED default, never as `false`: `flagAt` answers `false` for a
    // key that is not there, and a body without this one would otherwise draw the not-marked
    // banner over a healthy instance -- a positive claim in the one direction this story forbids.
    writesMarked: 'writesMarked' in row ? flagAt(row, 'writesMarked') : UNRESTRAINED.writesMarked,
  };
}

/** Whether two verdicts say the same thing, so a re-read that confirms one re-renders nothing. */
function sameRestraint(a: Restraint, b: Restraint): boolean {
  return (
    a.blocked === b.blocked &&
    a.code === b.code &&
    a.reason === b.reason &&
    a.footerKey === b.footerKey &&
    a.killSwitch === b.killSwitch &&
    a.killSwitchAudience === b.killSwitchAudience &&
    a.killSwitchReason === b.killSwitchReason &&
    a.enforcedReadOnly === b.enforcedReadOnly &&
    a.writesMarked === b.writesMarked
  );
}

export class AgentStatus {
  private readonly api: ApiService;

  private readonly connectivity: ConnectivityService | null;

  private configuredValue = false;

  private restraintValue: Restraint = UNRESTRAINED;

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

  /**
   * The newest read in flight, so a **superseded** one can resolve on it rather than on itself.
   *
   * `load()`'s promise means "the answer is in", not "my own request came back". Without that a
   * caller awaiting a read that a later one overtook is handed a settled promise over an
   * unanswered service: the first-login gate awaits exactly that (`app.ts runFirstLoginGate`),
   * and a form login issues two reads -- `Session.adopt()` notifies and then `runSubmit()`
   * notifies again, and `App` loads on every signed-in pass -- so the gate's own read is
   * superseded on every form sign-in and would decline whenever the navigation map answered
   * first (FR-28, AC1).
   */
  private newest: Promise<void> = Promise.resolve();

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

  /** The verdict the instance last answered for this caller. */
  restraint(): Restraint {
    return this.restraintValue;
  }

  /**
   * Whether the agent is restrained in a way the panel has something to say about: the kill
   * switch, or enforced read-only, which are the two sources EXPERIENCE.md gives a banner.
   *
   * A definition that is read-only restrains writes without a banner -- the footer line is where
   * that shows -- so it is deliberately not one of them.
   */
  restrained(): boolean {
    return this.restraintValue.killSwitch || this.restraintValue.enforcedReadOnly;
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
   *
   * **The promise resolves when the answer is in, not when this request came back**: a read a
   * later one overtook waits for that later one, so a caller that awaits a read has an answer to
   * read (`newest`).
   */
  load(): Promise<void> {
    const run = this.read();
    this.newest = run;
    return run;
  }

  private async read(): Promise<void> {
    const generation = this.generation;
    const request = (this.request += 1);
    // Both facts in one pass, so `answered()` is one gate rather than two and a consumer never
    // renders a panel that knows about the definition and not about the kill switch.
    const [definitions, restraint] = await Promise.all([
      this.api.requestJson<unknown>(AGENT_DEFINITIONS_PATH),
      this.api.requestJson<unknown>(AGENT_RESTRAINT_PATH),
    ]);
    if (generation !== this.generation) return;
    if (request !== this.request) {
      // Overtaken. The newer read owns the answer, so this one resolves on it rather than
      // handing its caller a settled promise over a service that has not answered yet. The
      // chain always terminates: `newest` is only ever a read issued after this one.
      await this.newest;
      return;
    }
    if (definitions.kind !== 'ok' || restraint.kind !== 'ok') {
      // Parked for one re-run when the instance answers again. A refusal is parked too: it is not
      // an answer, and both reads are ungated, so the only thing a 403 here can mean is that the
      // request never reached the route it was addressed to.
      const failed = definitions.kind !== 'ok' ? AGENT_DEFINITIONS_PATH : AGENT_RESTRAINT_PATH;
      this.connectivity?.retryWhenReachable(failed, () => void this.load());
      return;
    }
    const next = rowsOf(definitions.body).some(isEnabled);
    const nextRestraint = restraintOf(restraint.body);
    // Notified only when an answer moved, or when there was no answer before: a re-read that
    // confirms what is already on screen must not re-render the panel, the rail and the form.
    const moved =
      !this.answeredValue ||
      this.configuredValue !== next ||
      !sameRestraint(this.restraintValue, nextRestraint);
    this.configuredValue = next;
    this.restraintValue = nextRestraint;
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
    this.restraintValue = UNRESTRAINED;
    this.answeredValue = false;
    this.notify();
  }

  /**
   * An entity this restraint payload is computed from changed: re-read (AD-14 -- consumers
   * re-fetch, they never patch).
   *
   * `changed` only. The bus also carries `proposal-open` and `proposal-closed`, which say a
   * proposal against that entity is live rather than that the instance moved, so neither can
   * change the answer and neither should cost a request.
   */
  private onChange(event: ChangeEvent): void {
    if (event.kind !== 'changed') return;
    if (!RESTRAINT_ENTITIES.includes(event.type)) return;
    void this.load();
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
