import {
  ACCOUNT_PREFERENCES_PATH,
  AccountPreferences,
  FAVORITE_KIND,
  RECENT_KIND,
  REFRESH_KIND,
  SHELL_KIND,
  SHELL_PANEL_WIDTH,
  SHELL_SIDE_BAR_OPEN,
  VIEW_KIND,
} from '../core/account-preferences.ts';
import type { ApiService } from '../core/api.ts';

// The `.ts` extensions are what let `node --test` resolve this module, so `ui/tools/*.test.mjs`
// and the component suite share one stub rather than keeping two that can disagree about what the
// handler answers.

/** What one stub holds, in the orders the instance answers them in. */
export interface StubbedPreferences {
  readonly favorites: readonly string[];
  readonly recents: readonly string[];
  /** Each screen's remembered table view, keyed by route. */
  readonly views: Readonly<Record<string, string>>;
  /** Each screen's remembered refresh rate in whole seconds, keyed by route. */
  readonly refreshRates: Readonly<Record<string, string>>;
  /** The remembered pieces of shell chrome, keyed by shell member. */
  readonly shell: Readonly<Record<string, string>>;
  /**
   * How the stubbed instance answers a **write**: `'ok'`, a refusal carrying a published sentence,
   * or a transport failure that carries none (DW-1326).
   *
   * The real handler has all three and the stub had only the first, so nothing could drive the
   * refusal path the two writing surfaces announce. A read is unaffected: a spec that arranges
   * "these are stored" still gets them.
   */
  readonly writeAnswer: 'ok' | 'refused' | 'unreachable';
  /** The published sentence a `'refused'` write answers with. */
  readonly refusalReason: string;
}

/** One request the stubbed transport was asked for -- `tools/account-preferences.test.mjs`'s shape. */
export interface StubbedPreferenceCall {
  readonly path: string;
  readonly method: string;
  readonly body: string | null;
}

/**
 * The stub, plus the log of what it was asked for.
 *
 * A spec needs the log wherever the store's answer cannot tell whether a request was issued: a
 * repeat `add` of the front recent recomputes the same list, so `recents()` reads the same either
 * way and a guard that stopped guarding would redden nothing.
 */
export type StubbedAccountPreferences = AccountPreferences & {
  readonly calls: readonly StubbedPreferenceCall[];
};

/**
 * An `AccountPreferences` over a stubbed `GET/POST /account/preferences`, for the specs that mount
 * something which injects it without being about it, and for the ones that are -- mirrors
 * `testing/agent-context.ts`.
 *
 * The real class over a stubbed transport, so a spec that arranges "these two are pinned" arranges
 * it the way the instance does, and every write answers the whole body exactly as
 * `Api/Preferences.cls` does. Favorites stay in the order they were added and recents move to the
 * front on each visit, which is the two orders the handler publishes; a `set` replaces the one row
 * its key names.
 *
 * Construct it and do not `load()` and `answered()` is false, which is a shell that has not heard
 * from the instance yet -- the state in which every published default renders.
 */
export function stubAccountPreferences(
  seed: Partial<StubbedPreferences> = {}
): StubbedAccountPreferences {
  let favorites = [...(seed.favorites ?? [])];
  let recents = [...(seed.recents ?? [])];
  const values = new Map<string, Map<string, string>>([
    [VIEW_KIND, new Map(Object.entries(seed.views ?? {}))],
    [REFRESH_KIND, new Map(Object.entries(seed.refreshRates ?? {}))],
    [SHELL_KIND, new Map(Object.entries(seed.shell ?? {}))],
  ]);
  const writeAnswer = seed.writeAnswer ?? 'ok';
  const refusalReason = seed.refusalReason ?? 'That is not a screen this instance serves, so it cannot be remembered.';
  const calls: StubbedPreferenceCall[] = [];

  const rows = (kind: string, keyMember: string) =>
    [...(values.get(kind) ?? new Map<string, string>())].map(([key, value]) => ({ [keyMember]: key, value }));

  const answer = () => ({
    kind: 'ok',
    status: 200,
    body: {
      favorites: favorites.map((route) => ({ route })),
      recents: recents.map((route) => ({ route })),
      views: rows(VIEW_KIND, 'route'),
      refreshRates: rows(REFRESH_KIND, 'route'),
      shell: rows(SHELL_KIND, 'name'),
    },
  });

  const refusedWrite = () =>
    writeAnswer === 'refused'
      ? { kind: 'error', status: 422, code: 'PREFERENCES.ROUTE', reason: refusalReason, detail: null }
      : { kind: 'error', status: 0, code: null, reason: null, detail: null };

  const api = {
    requestJson: async (path: string, init: { method?: string; body?: string } = {}) => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? null });
      if (path !== ACCOUNT_PREFERENCES_PATH) {
        return { kind: 'error', status: 404, code: null, reason: null, detail: null };
      }
      if ((init.method ?? 'GET') !== 'POST') return answer();
      if (writeAnswer !== 'ok') return refusedWrite();
      const sent = JSON.parse(init.body ?? '{}') as {
        kind?: unknown;
        action?: unknown;
        route?: unknown;
        name?: unknown;
        value?: unknown;
      };
      if (sent.action === 'set') {
        const key = typeof sent.name === 'string' ? sent.name : typeof sent.route === 'string' ? sent.route : '';
        const value = typeof sent.value === 'string' ? sent.value : '';
        const held = values.get(String(sent.kind));
        if (held !== undefined && key !== '' && value !== '') held.set(key, value);
        return answer();
      }
      const route = typeof sent.route === 'string' ? sent.route : '';
      const held = sent.kind === FAVORITE_KIND ? favorites : recents;
      const without = held.filter((entry) => entry !== route);
      let next = held;
      if (sent.action === 'clear') next = [];
      else if (sent.action === 'remove') next = without;
      else if (sent.action === 'add' && route !== '') {
        // Favorites keep the order they were pinned in; a visit moves a screen to the front.
        next = sent.kind === FAVORITE_KIND ? (held.includes(route) ? held : [...held, route]) : [route, ...without];
      }
      if (sent.kind === FAVORITE_KIND) favorites = [...next];
      else recents = [...next];
      return answer();
    },
  };

  return Object.assign(new AccountPreferences({ api: api as unknown as ApiService }), {
    calls: calls as readonly StubbedPreferenceCall[],
  });
}

/**
 * An already-answered stub, for a spec whose subject adopts the remembered state when it is
 * constructed: `ShellState`, `PanelState` and `ScreenStore` all take the instance's answer once,
 * on the first settled read, and a store that has not answered leaves the published default
 * standing.
 */
export async function settledAccountPreferences(
  seed: Partial<StubbedPreferences> = {}
): Promise<StubbedAccountPreferences> {
  const store = stubAccountPreferences(seed);
  await store.load();
  return store;
}

/**
 * The value the last `set` in `calls` sent for `key`, or `undefined` when none did.
 *
 * The log is written synchronously as each request is issued, so a spec can assert what reached
 * the instance without awaiting the answer -- which is what the browser-storage assertions this
 * replaces used to read off a memory map.
 */
export function lastRemembered(
  calls: readonly StubbedPreferenceCall[],
  key: string
): string | undefined {
  for (let index = calls.length - 1; index >= 0; index -= 1) {
    const call = calls[index];
    if (call.method !== 'POST' || call.body === null) continue;
    const sent = JSON.parse(call.body) as {
      action?: unknown;
      route?: unknown;
      name?: unknown;
      value?: unknown;
    };
    if (sent.action !== 'set') continue;
    if (sent.route !== key && sent.name !== key) continue;
    return typeof sent.value === 'string' ? sent.value : undefined;
  }
  return undefined;
}

/** The kinds, re-exported so a spec names them from one place. */
export {
  FAVORITE_KIND,
  RECENT_KIND,
  REFRESH_KIND,
  SHELL_KIND,
  SHELL_PANEL_WIDTH,
  SHELL_SIDE_BAR_OPEN,
  VIEW_KIND,
};
