import {
  ACCOUNT_PREFERENCES_PATH,
  AccountPreferences,
  FAVORITE_KIND,
  RECENT_KIND,
} from '../core/account-preferences';
import type { ApiService } from '../core/api';

/** What one stub holds, in the two orders the instance answers them in. */
export interface StubbedPreferences {
  readonly favorites: readonly string[];
  readonly recents: readonly string[];
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
 * it the way the instance does, and every write answers the whole list exactly as
 * `Api/Preferences.cls` does. Favorites stay in the order they were added and recents move to the
 * front on each visit, which is the two orders the handler publishes.
 *
 * Construct it and do not `load()` and `answered()` is false, which is a Home that has not heard
 * from the instance yet.
 */
export function stubAccountPreferences(
  seed: Partial<StubbedPreferences> = {}
): StubbedAccountPreferences {
  let favorites = [...(seed.favorites ?? [])];
  let recents = [...(seed.recents ?? [])];
  const calls: StubbedPreferenceCall[] = [];

  const answer = () => ({
    kind: 'ok',
    status: 200,
    body: {
      favorites: favorites.map((route) => ({ route })),
      recents: recents.map((route) => ({ route })),
    },
  });

  const api = {
    requestJson: async (path: string, init: { method?: string; body?: string } = {}) => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? null });
      if (path !== ACCOUNT_PREFERENCES_PATH) {
        return { kind: 'error', status: 404, code: null, reason: null, detail: null };
      }
      if ((init.method ?? 'GET') !== 'POST') return answer();
      const sent = JSON.parse(init.body ?? '{}') as {
        kind?: unknown;
        action?: unknown;
        route?: unknown;
      };
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

/** The two kinds, re-exported so a spec names them from one place. */
export { FAVORITE_KIND, RECENT_KIND };
