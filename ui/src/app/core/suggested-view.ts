/**
 * Home's suggested view (Story 4.10): the attention lines above the transcript, and the starter
 * prompts that stand in for them when nothing needs attention.
 *
 * **Lines come from a declared source array, so a later read joins by appending a source.** Each
 * entry carries its own key and one `read` that settles a line, `null` for "no line", or leaves
 * `'pending'` for "not answered yet". Story 6.13's alerts.log line is one appended `SOURCES` entry
 * and one string key; nothing in the render path changes, because the render path iterates the
 * array and knows none of its keys.
 *
 * **A line renders only when its read has answered and the caller may perform it** (AD-8). A read
 * in flight, a fault and a 403 all produce *no line* -- never a zero, never a skeleton row -- and a
 * 403 is never retried. Anything that is not a refusal parks one re-read through
 * `ConnectivityService.retryWhenReachable`, keyed by the path, the way every other reader does
 * (DW-135). `answered()` stays false until every source has answered or settled to absent, so the
 * block renders nothing rather than a partial block or a flash of prompts.
 *
 * **Bounded** (AD-24, AD-36): one HTTP call per line per Home entry per namespace, and no fan-out
 * over namespaces or rows. Home is not in AD-43's six-screen auto-refresh roster, so there is no
 * timer, and this store schedules nothing of its own: `load()` and `reset()` are called by the
 * panel, which is where entering Home and a `ScopeService` namespace change are observed. The
 * injected `ScopeService` is read (`namespace()`), never subscribed to.
 *
 * Framework-free like the rest of `core/` (AD-19, DW-177), so `ui/tools/suggested-view.test.mjs`
 * executes it under `node --test`.
 */

// The `.ts` extensions are what let `node --test` resolve these at runtime.
import { type AgentStatus, formatKillSwitch } from './agent-status.ts';
import type { ApiService } from './api';
import type { ConnectivityService } from './connectivity';
import { classifyFault } from './fault.ts';
import { ERROR_LOG_DATES_PATH } from './log-paths.ts';
import type { ScopeService } from './scope';
import { STRINGS, stringFor } from './strings.ts';

/**
 * The application-errors line's own read (AD-20). Re-exported so this module's existing importers
 * are unaffected; the one declaration is in `log-paths.ts`, beside the prefix the error-log
 * screen's own levels are built from (DW-1149).
 */
export { ERROR_LOG_DATES_PATH };

/** `OcuPilot.Screen.Descriptor.AgentSwitches` -- the agent-status line's `Open` target. */
export const SWITCHES_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.AgentSwitches';

/** `OcuPilot.Screen.Descriptor.LogErrorList` -- the application-errors line's `Open` target. */
export const ERROR_LOG_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.LogErrorList';

/** The slots the published application-errors line leaves for its namespace, count and date. */
export const NAMESPACE_PLACEHOLDER = '<NAMESPACE>';

/** See `NAMESPACE_PLACEHOLDER`. */
export const COUNT_PLACEHOLDER = '<n>';

/** See `NAMESPACE_PLACEHOLDER`. */
export const DATE_PLACEHOLDER = '<DATE>';

/**
 * One rendered line.
 *
 * `text` is one resolved string with two renderings: the row's own label, and the prompt that
 * activating it places in the composer. `count` is what the row wraps in `<code>`; an uncounted
 * line carries `0` and renders none.
 */
export interface SuggestedLine {
  readonly key: string;
  /** Whether this line's value takes part in the all-zero test that selects the starter prompts. */
  readonly counted: boolean;
  readonly text: string;
  readonly count: number;
  /**
   * The resolved text either side of the count, so a row can wrap the count in `<code>` without
   * re-parsing the sentence to find a number inside it. Split at the published `<n>` slot, which
   * is why it cannot drift from `text`. On an uncounted line `label` is the whole text and `tail`
   * is `''`.
   */
  readonly label: string;
  /** See `label`. */
  readonly tail: string;
  /** The declared class name of the screen this line's `Open` control opens (AD-5). */
  readonly descriptor: string;
}

/** What one source answered: a line, `null` for "no line", `'pending'` for "not answered yet". */
export type SourceAnswer = SuggestedLine | null | 'pending';

/**
 * `Application errors in <NAMESPACE>: <n> on <DATE>` resolved to the namespace the read was
 * scoped to, the count the instance answered and the date it named. A function rather than a
 * `replace` at the call site, for the reason `formatKillSwitch` is one: renaming a placeholder on
 * one side only would ship the placeholder to the user.
 */
export function formatApplicationErrors(
  template: string,
  namespace: string,
  count: number,
  date: string
): string {
  return resolveSlots(template, namespace, date).split(COUNT_PLACEHOLDER).join(String(count));
}

/** Every slot but the count, so `<n>` survives to split the sentence into `label` and `tail`. */
function resolveSlots(template: string, namespace: string, date: string): string {
  return template
    .split(NAMESPACE_PLACEHOLDER)
    .join(namespace)
    .split(DATE_PLACEHOLDER)
    .join(date);
}

export interface SuggestedViewOptions {
  readonly api: ApiService;
  readonly agentStatus: AgentStatus;
  readonly scope: ScopeService;
  /**
   * Where a failed read is parked (DW-135's shape), mirroring `agent-status.ts`'s own options.
   * Optional so a test that is not about the re-read can leave it out.
   */
  readonly connectivity?: ConnectivityService;
}

/** The state one source holds between `load()` calls. */
interface SourceState {
  answer: SourceAnswer;
}

/**
 * One declared line, in one of two shapes.
 *
 * - `read` performs this source's own HTTP and settles `state.answer`. It runs once per `load()`.
 * - `project` answers from a store the panel already holds, with no HTTP and nothing remembered.
 *   It is resolved on **every** read rather than at `load()` time, which is what keeps such a line
 *   from contradicting the store it projects: `AgentStatus` answers a round trip after the block
 *   is built, and a remembered projection would render the pre-answer verdict for the life of the
 *   visit.
 *
 * A source declares exactly one of the two.
 */
export interface Source {
  readonly key: string;
  readonly read?: (view: SuggestedView, state: SourceState) => Promise<void>;
  readonly project?: (view: SuggestedView) => SourceAnswer;
}

/**
 * The agent-status line. No HTTP of its own: the text is the sentence the panel's banner and
 * footer already select from `AgentStatus`'s verdict, by the same `footerKey`, so the block cannot
 * contradict the banner two rows above it. Uncounted, because it reports a state rather than a
 * count, and AC2 requires it to survive the all-zero fallback; its read is ungated by construction
 * (`Api/Switches.cls`: "the audience for the kill-switch banner is precisely the people who cannot
 * change it"), so it always answers.
 */
const AGENT_STATUS_SOURCE: Source = {
  key: 'agent-status',
  project: (view) => view.agentStatusLine(),
};

/**
 * The application-errors line: one `GET /logs/errors/dates?namespace=<scope>` per Home entry.
 *
 * `scope: null` -- the route's `?ns=` never reaches `LogSourcePort`, and the namespace travels as
 * this endpoint's own parameter (AD-48). Rows are newest-date-first, so `rows[0]` is the answer and
 * no rows is a count of zero.
 */
const APPLICATION_ERRORS_SOURCE: Source = {
  key: 'application-errors',
  read: (view, state) => view.readApplicationErrors(state),
};

/**
 * The declared lines, in render order. **Appending an entry is how a line joins** (AC5): the
 * render path iterates this array and knows nothing about which keys are in it.
 */
export const SOURCES: readonly Source[] = [AGENT_STATUS_SOURCE, APPLICATION_ERRORS_SOURCE];

function rowsOf(body: unknown): readonly unknown[] {
  if (body === null || typeof body !== 'object') return [];
  const rows = (body as Record<string, unknown>)['rows'];
  return Array.isArray(rows) ? rows : [];
}

function textAt(row: unknown, key: string): string {
  if (row === null || typeof row !== 'object') return '';
  const value = (row as Record<string, unknown>)[key];
  return typeof value === 'string' ? value : '';
}

function numberAt(row: unknown, key: string): number {
  if (row === null || typeof row !== 'object') return 0;
  const value = (row as Record<string, unknown>)[key];
  return typeof value === 'number' ? value : 0;
}

export class SuggestedView {
  private readonly api: ApiService;
  private readonly agentStatus: AgentStatus;
  private readonly scope: ScopeService;
  private readonly connectivity: ConnectivityService | null;

  /** One state per declared source, keyed by its own key, every one `'pending'` until it reads. */
  private readonly states = new Map<string, SourceState>();

  /**
   * Bumped by `reset()` and by every `load()`, read across each await, so an answer about a
   * namespace or a principal the tab has left never settles -- the shape `AgentStatus`,
   * `NavigationService` and `ScopeService` all carry for the same hazard (AD-8).
   */
  private generation = 0;

  private readonly listeners = new Set<() => void>();

  constructor(options: SuggestedViewOptions) {
    this.api = options.api;
    this.agentStatus = options.agentStatus;
    this.scope = options.scope;
    this.connectivity = options.connectivity ?? null;
    for (const source of SOURCES) this.states.set(source.key, { answer: 'pending' });
  }

  /** One source's current answer: projected live, or the one its own read settled. */
  private answerFor(source: Source): SourceAnswer {
    if (source.project !== undefined) return source.project(this);
    return this.stateFor(source.key).answer;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** Whether every declared source has answered or settled to absent. Nothing renders before it has. */
  answered(): boolean {
    for (const source of SOURCES) {
      if (this.answerFor(source) === 'pending') return false;
    }
    return true;
  }

  /** The lines to render, in declared order, absent ones dropped. */
  lines(): readonly SuggestedLine[] {
    const lines: SuggestedLine[] = [];
    for (const source of SOURCES) {
      const answer = this.answerFor(source);
      if (answer !== null && answer !== 'pending') lines.push(answer);
    }
    return lines;
  }

  /**
   * The three published starter prompts, in declaration order -- EXPERIENCE.md's
   * "Home starter prompts, shown when nothing needs attention".
   */
  starterPrompts(): readonly string[] {
    return [
      STRINGS.homeStarterPromptExplainScreen,
      STRINGS.homeStarterPromptExplainLog,
      STRINGS.homeStarterPromptChangeOneThing,
    ];
  }

  /**
   * Whether the prompts stand in for the counted rows: every answered source has answered, and
   * every **counted** line resolved to zero. The agent-status line is uncounted, which is what
   * keeps it out of this test and present in the fallback.
   */
  showPrompts(): boolean {
    if (!this.answered()) return false;
    return this.lines().every((line) => !line.counted || line.count === 0);
  }

  /** Read every declared source once. One call per line per Home entry (AD-24). */
  async load(): Promise<void> {
    const generation = (this.generation += 1);
    await Promise.all(
      SOURCES.filter((source) => source.read !== undefined).map(async (source) => {
        const state: SourceState = { answer: 'pending' };
        await (source.read as NonNullable<Source['read']>)(this, state);
        if (generation !== this.generation) return;
        this.stateFor(source.key).answer = state.answer;
      })
    );
    if (generation !== this.generation) return;
    this.notify();
  }

  /**
   * Forget every answer, so the next `load()` asks again. The panel calls it on leaving Home and
   * before re-reading for a different namespace; sign-out reaches it through `App.reset()`, the
   * same way every other reader is cleared (AD-8).
   */
  reset(): void {
    this.generation += 1;
    for (const source of SOURCES) this.stateFor(source.key).answer = 'pending';
    this.notify();
  }

  /**
   * The agent-status line, which always answers. Kill switch on -> the published kill-switch
   * sentence with its two slots resolved from the verdict; otherwise the footer read-only line the
   * verdict's own `footerKey` names. Zero new strings.
   */
  agentStatusLine(): SuggestedLine {
    const restraint = this.agentStatus.restraint();
    const text = restraint.killSwitch
      ? formatKillSwitch(
          STRINGS.agentKillSwitchBanner,
          restraint.killSwitchAudience,
          restraint.killSwitchReason
        )
      : stringFor(restraint.footerKey);
    return {
      key: AGENT_STATUS_SOURCE.key,
      counted: false,
      text,
      count: 0,
      label: text,
      tail: '',
      descriptor: SWITCHES_DESCRIPTOR,
    };
  }

  /** `APPLICATION_ERRORS_SOURCE`'s body. Public so the declared source can call it. */
  async readApplicationErrors(state: SourceState): Promise<void> {
    const generation = this.generation;
    const namespace = this.scope.namespace();
    // No namespace resolved yet: the read is withheld rather than issued unscoped. The namespace
    // is chosen from the set the instance offered, never taken as a caller string (AD-21, AD-48),
    // and `''` is not in that set -- the endpoint answers 404 for it. The source stays `'pending'`,
    // so `answered()` is false and the block renders nothing until a namespace arrives.
    if (namespace === '') return;
    const path = `${ERROR_LOG_DATES_PATH}?namespace=${encodeURIComponent(namespace)}`;
    const result = await this.api.requestJson<unknown>(path, { scope: null });
    if (generation !== this.generation) return;
    if (result.kind !== 'ok') {
      state.answer = null;
      const fault = classifyFault(result, path);
      // A 403 is reported and never retried (AD-8); everything else parks one re-read.
      if (fault !== null && fault.kind !== 'refused') {
        this.connectivity?.retryWhenReachable(path, () => void this.load());
      }
      return;
    }
    const newest = rowsOf(result.body)[0];
    const count = newest === undefined ? 0 : numberAt(newest, 'count');
    const date = newest === undefined ? '' : textAt(newest, 'date');
    const template = STRINGS.homeSuggestedApplicationErrors;
    const [label = '', tail = ''] = resolveSlots(template, namespace, date).split(COUNT_PLACEHOLDER);
    state.answer = {
      key: APPLICATION_ERRORS_SOURCE.key,
      counted: true,
      text: formatApplicationErrors(template, namespace, count, date),
      count,
      label,
      tail,
      descriptor: ERROR_LOG_DESCRIPTOR,
    };
  }

  private stateFor(key: string): SourceState {
    let state = this.states.get(key);
    if (state === undefined) {
      state = { answer: 'pending' };
      this.states.set(key, state);
    }
    return state;
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
