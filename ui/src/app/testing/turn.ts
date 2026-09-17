import { TurnStore, type TurnStoreOptions } from '../core/turn';

/**
 * A `TurnStore` over a stub transport, for specs that mount `Panel` without being about the
 * store itself (most of `panel.spec.ts`). Every call answers `ok({})`, which is enough for a
 * component that only reads `entries()`, `busy()` and `locked()` and never calls `send()`.
 *
 * `options` lets a spec override the transport, the storage or the schedule when it IS about the
 * store's interaction with the panel -- passed straight through to `TurnStore`'s own constructor.
 */
export function stubTurnStore(options: Partial<TurnStoreOptions> = {}): TurnStore {
  const api = options.api ?? {
    requestJson: async () => ({ kind: 'ok' as const, status: 200, body: {} }),
  };
  const storage =
    options.storage ??
    (() => {
      const map = new Map<string, string>();
      return {
        getItem: (key: string) => (map.has(key) ? (map.get(key) as string) : null),
        setItem: (key: string, value: string) => {
          map.set(key, value);
        },
        removeItem: (key: string) => {
          map.delete(key);
        },
      };
    })();
  return new TurnStore({
    api: api as TurnStoreOptions['api'],
    storage,
    navigationType: options.navigationType ?? (() => 'navigate'),
    schedule: options.schedule,
    pollMs: options.pollMs,
  });
}
