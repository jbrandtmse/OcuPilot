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
 * Every screen's auto-refresh rate, as one descriptor-to-seconds map (EXPERIENCE.md `:561`:
 * "Setting, sort, filter and max rows persist per screen").
 *
 * **One key for sixty screens, not a key per screen.** The allow-list is what keeps this
 * carve-out narrow (AD-47), and a list that grows by one entry per screen built is not a closed
 * list -- it is a prefix rule wearing a list's clothes, and a prefix rule is what a token would
 * hide behind. The map's own keys are descriptor class names, which are not user-supplied.
 */
export const SCREEN_REFRESH_RATES_KEY = 'ocupilot.screen.refresh-rates';

/**
 * Every screen's table view -- sort, direction, filter and max rows -- as one descriptor-to-view
 * map, for the reason the refresh rates are one map (EXPERIENCE.md: "Setting, sort, filter and max
 * rows persist per screen").
 */
export const SCREEN_VIEWS_KEY = 'ocupilot.screen.views';

/**
 * Every key this store will read or write. A key that is not here is a programming error, not
 * a miss: the store throws rather than silently reading `null`, so a typo fails where it is
 * made instead of quietly turning a remembered preference into a default.
 */
export const PREFERENCE_KEYS: readonly string[] = [SIDE_BAR_OPEN_KEY, SCREEN_REFRESH_RATES_KEY, SCREEN_VIEWS_KEY];

/** What a screen remembers of its table's view: its sort, direction, filter and max rows. */
export interface ScreenViewPreference {
  readonly sort: string;
  readonly direction: string;
  readonly filter: string;
  readonly maxRows: number;
}

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

  /**
   * The remembered auto-refresh rate for one screen, in seconds, or `0` (off) when there is no
   * usable one.
   *
   * **Three ways there is no usable one, and all three answer off rather than throwing.** Nothing
   * was ever stored; the blob will not parse, because a browser's persistent storage is shared
   * ground that anything on the origin can write (AD-47) and a half-written value survives a
   * crashed tab; or the stored rate is not one this descriptor declares any more, because the
   * descriptor changed under a browser that remembered the old list. Off is the published default
   * (EXPERIENCE.md `:439`), so falling back to it shows the user a state the chip can name.
   */
  refreshRate(descriptor: string, permitted: readonly number[]): number {
    const stored = this.refreshRates()[descriptor];
    if (typeof stored !== 'number' || !permitted.includes(stored)) return 0;
    return stored;
  }

  /** Remember one screen's rate. `0` is remembered like any other value: off is a choice. */
  setRefreshRate(descriptor: string, seconds: number): void {
    const map = { ...this.refreshRates(), [descriptor]: seconds };
    this.write(SCREEN_REFRESH_RATES_KEY, JSON.stringify(map));
  }

  /**
   * The remembered view for one screen, or `null` when there is no usable one. A stored value that
   * is not the view's shape falls back field by field: a sort, direction or filter that is not a
   * string reads `''`, and a max rows that is not a positive safe integer reads `fallbackMaxRows`.
   */
  screenView(descriptor: string, fallbackMaxRows: number): ScreenViewPreference | null {
    const stored = this.jsonMap(SCREEN_VIEWS_KEY)[descriptor];
    if (stored === null || typeof stored !== 'object' || Array.isArray(stored)) return null;
    const view = stored as Record<string, unknown>;
    const text = (value: unknown): string => (typeof value === 'string' ? value : '');
    const cap = view['maxRows'];
    return {
      sort: text(view['sort']),
      direction: text(view['direction']),
      filter: text(view['filter']),
      maxRows: typeof cap === 'number' && Number.isSafeInteger(cap) && cap > 0 ? cap : fallbackMaxRows,
    };
  }

  /** Remember one screen's view. */
  setScreenView(descriptor: string, view: ScreenViewPreference): void {
    const map = { ...this.jsonMap(SCREEN_VIEWS_KEY), [descriptor]: view };
    this.write(SCREEN_VIEWS_KEY, JSON.stringify(map));
  }

  /** The object stored under `key`, or an empty one for anything that is not a JSON object. */
  private jsonMap(key: string): Record<string, unknown> {
    const raw = this.read(key);
    if (raw === null) return {};
    try {
      const parsed: unknown = JSON.parse(raw);
      if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) return {};
      return parsed as Record<string, unknown>;
    } catch {
      return {};
    }
  }

  /** The stored map, or an empty one for anything that is not a JSON object of numbers. */
  private refreshRates(): Record<string, number> {
    const raw = this.read(SCREEN_REFRESH_RATES_KEY);
    if (raw === null) return {};
    let parsed: unknown;
    try {
      parsed = JSON.parse(raw);
    } catch {
      return {};
    }
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) return {};
    const map: Record<string, number> = {};
    for (const [key, value] of Object.entries(parsed as Record<string, unknown>)) {
      if (typeof value === 'number' && Number.isFinite(value)) map[key] = value;
    }
    return map;
  }

  private assertAllowed(key: string): void {
    if (!this.allows(key)) {
      throw new Error(UNLISTED_KEY_MESSAGE + JSON.stringify(key));
    }
  }
}
