/**
 * Per-tab storage for the JWT pair, and the tab-identity check that makes it per-tab
 * in fact rather than only by intent (AD-28, AD-47, DW-6).
 *
 * The pair lives in `sessionStorage` and travels only as an `Authorization: Bearer`
 * header. Nothing here writes `document.cookie`, `localStorage` or a `BroadcastChannel`,
 * and nothing listens for a `storage` event: the instance's origin is shared with every
 * other application IRIS serves (AD-47), so a token that reached persistent or
 * cross-tab storage would be readable by all of them for the rest of the session.
 *
 * **Why a nonce (DW-6).** Duplicating a tab copies `sessionStorage` wholesale, so the
 * duplicate would otherwise wake holding a pair minted for its parent and go on using
 * its `sid`. The browser does say which kind of navigation this is:
 * `PerformanceNavigationTiming.type` reads `reload` or `back_forward` only when the
 * document is continuing the same tab. Any other value -- `navigate`, which is what a
 * duplicate and a fresh open both report -- means the stored pair belongs to some other
 * tab, so it is discarded, a fresh nonce is stamped, and the caller re-probes.
 *
 * **The navigation kind is what decides; the nonce records the decision.** The nonce is
 * copied along with everything else when a tab is duplicated, so it cannot itself
 * distinguish a copy -- restamping it is how this document marks the storage as its own
 * after the discard, and its absence beside a pair is how a half-written store reads as
 * no pair at all. It is not a secret and is never sent anywhere.
 *
 * Framework-free by design: storage, the navigation-type reader and the nonce generator
 * are all injected, which is what lets `ui/tools/token-store.test.mjs` execute this
 * under `node --test` with no browser and no component runner.
 */

/** The JWT pair exactly as `%CSP.REST`'s token endpoints mint it, in camelCase. */
export interface TokenPair {
  readonly accessToken: string;
  readonly refreshToken: string;
  /** The login name the pair was minted for. */
  readonly sub: string;
  /** Issued-at, seconds since the epoch, as the instance reports it. */
  readonly iat: number;
  /** Expiry, seconds since the epoch, as the instance reports it. */
  readonly exp: number;
}

/** The slice of `Storage` this module uses. */
export interface TokenStorage {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

/**
 * The navigation kinds `PerformanceNavigationTiming.type` reports, plus `unknown` for a
 * browser or an environment that reports nothing.
 */
export type NavigationKind = 'navigate' | 'reload' | 'back_forward' | 'prerender' | 'unknown';

export interface TokenStoreOptions {
  readonly storage: TokenStorage;
  /** How this document was navigated to. Called once, when the store is constructed. */
  readonly navigationType: () => NavigationKind;
  /** Defaults to `defaultNonce`. Injected so a test can make the nonce readable. */
  readonly newNonce?: () => string;
}

/** Storage keys. Namespaced so nothing else on the origin collides with them. */
export const PAIR_STORAGE_KEY = 'ocupilot.token-pair';
export const NONCE_STORAGE_KEY = 'ocupilot.tab-nonce';

/**
 * Read this document's navigation kind from the Performance timeline. Used by the real
 * bootstrap; every test injects its own reader instead.
 */
export function readNavigationKind(): NavigationKind {
  const entries = performance.getEntriesByType('navigation');
  if (entries.length === 0) return 'unknown';
  const first = entries[0] as PerformanceNavigationTiming;
  return first.type;
}

/**
 * This document's `sessionStorage`, or an in-memory stand-in when the browser refuses it.
 *
 * Reading `window.sessionStorage` **throws** where site data is blocked -- the property
 * access itself, before any `getItem`, which no try/catch inside the store can reach. The
 * fallback keeps the tab working for its own lifetime and simply forgets across a reload,
 * which is the store's documented degraded behaviour rather than a new one.
 */
export function readSessionStorage(): TokenStorage {
  try {
    return sessionStorage;
  } catch {
    const map = new Map<string, string>();
    return {
      getItem: (key) => (map.has(key) ? (map.get(key) as string) : null),
      setItem: (key, value) => {
        map.set(key, value);
      },
      removeItem: (key) => {
        map.delete(key);
      },
    };
  }
}

/**
 * A tab-identity nonce. `crypto.randomUUID()` where it exists, and a non-cryptographic id
 * otherwise: it is **secure-context-only**, so on an instance reached as
 * `http://<host>:52773` -- the ordinary way an IRIS instance is reached -- it is
 * `undefined` and calling it would throw before the shell ever rendered. The nonce marks
 * storage as this document's own and is never sent anywhere, so unpredictability buys
 * nothing here and a hard failure costs everything.
 */
export function defaultNonce(): string {
  const webCrypto: Crypto | undefined = typeof crypto === 'undefined' ? undefined : crypto;
  if (webCrypto !== undefined && typeof webCrypto.randomUUID === 'function') {
    return webCrypto.randomUUID();
  }
  return `ocu-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 10)}`;
}

function parsePair(raw: string | null): TokenPair | null {
  if (raw === null || raw === '') return null;
  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return null;
  }
  if (typeof parsed !== 'object' || parsed === null) return null;
  const candidate = parsed as Partial<TokenPair>;
  if (typeof candidate.accessToken !== 'string' || candidate.accessToken === '') return null;
  if (typeof candidate.refreshToken !== 'string' || candidate.refreshToken === '') return null;
  return {
    accessToken: candidate.accessToken,
    refreshToken: candidate.refreshToken,
    sub: typeof candidate.sub === 'string' ? candidate.sub : '',
    iat: typeof candidate.iat === 'number' ? candidate.iat : 0,
    exp: typeof candidate.exp === 'number' ? candidate.exp : 0,
  };
}

export class TokenStore {
  private readonly storage: TokenStorage;
  private readonly makeNonce: () => string;
  private tabNonce = '';
  private adoptedStoredPair = false;

  constructor(options: TokenStoreOptions) {
    this.storage = options.storage;
    this.makeNonce = options.newNonce ?? defaultNonce;

    const kind = options.navigationType();
    const continuesThisTab = kind === 'reload' || kind === 'back_forward';
    const stored = parsePair(this.readItem(PAIR_STORAGE_KEY));
    const storedNonce = this.readItem(NONCE_STORAGE_KEY);

    if (continuesThisTab && stored !== null && storedNonce !== null && storedNonce !== '') {
      this.tabNonce = storedNonce;
      this.adoptedStoredPair = true;
      return;
    }
    this.removeItem(PAIR_STORAGE_KEY);
    this.tabNonce = this.makeNonce();
    this.writeItem(NONCE_STORAGE_KEY, this.tabNonce);
  }

  /** This tab's nonce. Never sent anywhere; it identifies the storage, not the user. */
  nonce(): string {
    return this.tabNonce;
  }

  /**
   * Whether a pair stored by a previous document was adopted. False after a duplicate,
   * a fresh open, or an empty store -- in all three the caller must probe.
   */
  adopted(): boolean {
    return this.adoptedStoredPair;
  }

  /** The stored pair, or null when this tab holds none. */
  read(): TokenPair | null {
    return parsePair(this.readItem(PAIR_STORAGE_KEY));
  }

  /** The access token to present, or `''` when this tab holds no pair. */
  accessToken(): string {
    const pair = this.read();
    return pair === null ? '' : pair.accessToken;
  }

  write(pair: TokenPair): void {
    this.writeItem(PAIR_STORAGE_KEY, JSON.stringify(pair));
    this.adoptedStoredPair = true;
  }

  clear(): void {
    this.removeItem(PAIR_STORAGE_KEY);
    this.adoptedStoredPair = false;
  }

  // Storage throws in a browser that has blocked site data, and a sign-in screen that
  // cannot render is worse than one that cannot remember. Every access is guarded, and a
  // failure reads as "this tab holds nothing", which is the state the probe recovers from.
  private readItem(key: string): string | null {
    try {
      return this.storage.getItem(key);
    } catch {
      return null;
    }
  }

  private writeItem(key: string, value: string): void {
    try {
      this.storage.setItem(key, value);
    } catch {
      // deliberately ignored -- see above
    }
  }

  private removeItem(key: string): void {
    try {
      this.storage.removeItem(key);
    } catch {
      // deliberately ignored -- see above
    }
  }
}
