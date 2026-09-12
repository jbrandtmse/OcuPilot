/**
 * The one module in the client permitted to touch `localStorage`, and the only per-browser
 * preference store.
 *
 * **Why a carve-out exists at all.** EXPERIENCE.md `:51` says the side bar's open state is
 * "remembered per browser", which `sessionStorage` does not deliver -- it is per tab and dies
 * with it. `ui/tools/api.test.mjs`'s source scan bans `localStorage` everywhere under
 * `ui/src`, and that ban is about **credential channels** and cross-tab broadcast (AD-28,
 * AD-47): a token pair is per tab, never persistent, never broadcast. A remembered side bar is
 * neither a credential nor a broadcast.
 *
 * **So the carve-out is narrow, and all four parts of it are load-bearing.** One module; an
 * exact path exemption in the scan, never a pattern; a declared key allow-list this store
 * refuses to step outside; and no `storage` listener and no `BroadcastChannel`, so nothing
 * here reaches another tab. Widening any of the four would make it the bypass it must not
 * become. Nothing in this file may ever hold a token, a user name or anything derived from
 * one.
 *
 * Framework-free, like the rest of `core/`, so `node --test` executes it.
 */

/** The side bar's remembered open state (EXPERIENCE.md `:51`). */
export const SIDE_BAR_OPEN_KEY = 'ocupilot.side-bar.open';

/**
 * Every key this store will read or write. A key that is not here is a programming error, not
 * a miss: the store throws rather than silently reading `null`, so a typo fails where it is
 * made instead of quietly turning a remembered preference into a default.
 */
export const PREFERENCE_KEYS: readonly string[] = [SIDE_BAR_OPEN_KEY];

/** The message an out-of-list key reports. Named so a test can pin it. */
export const UNLISTED_KEY_MESSAGE =
  'the preference store writes only its declared keys (AD-47); received: ';

/** The three methods this store uses, so a test can hand it a map instead of a browser. */
export interface PreferenceStorage {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

export interface PreferenceOptions {
  readonly storage: PreferenceStorage | null;
}

/**
 * The browser's own persistent store, or `null` where it cannot be had.
 *
 * The property access itself throws in a browser with site data blocked, and at module scope
 * that would abort the bootstrap before anything painted -- the reason `token-store.ts` reads
 * `sessionStorage` the same way. A shell that cannot remember its side bar is better than one
 * that cannot render.
 */
export function readPreferenceStorage(): PreferenceStorage | null {
  try {
    return localStorage;
  } catch {
    return null;
  }
}

export class PreferenceStore {
  private readonly storage: PreferenceStorage | null;

  constructor(options: PreferenceOptions) {
    this.storage = options.storage;
  }

  /** Whether `key` is one of the declared keys. */
  allows(key: string): boolean {
    return PREFERENCE_KEYS.includes(key);
  }

  /**
   * The stored value for `key`, or `null` when nothing is stored, the key has never been
   * written, or the browser refused the read. Throws for a key outside the allow-list.
   */
  read(key: string): string | null {
    this.assertAllowed(key);
    if (this.storage === null) return null;
    try {
      return this.storage.getItem(key);
    } catch {
      return null;
    }
  }

  /**
   * Store `value` under `key`. Throws for a key outside the allow-list; a storage that refuses
   * the write (a full or blocked store) is swallowed, because a preference that could not be
   * remembered is not a failure the caller can act on.
   */
  write(key: string, value: string): void {
    this.assertAllowed(key);
    if (this.storage === null) return;
    try {
      this.storage.setItem(key, value);
    } catch {
      // A preference that cannot be remembered is still a shell that works.
    }
  }

  /** The side bar's remembered open state; `fallback` when nothing has been remembered. */
  sideBarOpen(fallback: boolean): boolean {
    const stored = this.read(SIDE_BAR_OPEN_KEY);
    if (stored === null) return fallback;
    return stored === 'true';
  }

  setSideBarOpen(open: boolean): void {
    this.write(SIDE_BAR_OPEN_KEY, open ? 'true' : 'false');
  }

  private assertAllowed(key: string): void {
    if (!this.allows(key)) {
      throw new Error(UNLISTED_KEY_MESSAGE + JSON.stringify(key));
    }
  }
}
