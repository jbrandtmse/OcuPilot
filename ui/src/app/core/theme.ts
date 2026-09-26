/**
 * The light and dark theme (Story 15.6, spine Conventions > Theme).
 *
 * **The whole theme is one class on the document root.** `ocu-theme-dark` present is dark and
 * absent is light; `ui/src/styles/_theme.scss` is the one scope that selects it, re-pointing every
 * bare `--ocu-<role>` and Lantern-valued `--mat-sys-*` variable at its `-dark` twin. This store is
 * the one place that sets it, so the toggle is a flag flip and no component selects on the theme.
 *
 * **The choice is per user, on the instance** (AD-50): the `shell` kind's `theme` member, read and
 * written through `AccountPreferences`. Nothing is kept in browser storage. Light renders until the
 * instance's read settles, and a read that fails or holds no row keeps light -- the published
 * default (EXPERIENCE.md). The remembered value is adopted once per sign-in, on the settled read,
 * and adopting it writes nothing: the store is written only when the user chooses.
 *
 * **It is a self-service account action** (AD-49): the user's own write, with no proposal, no
 * marker and no tool. A refused write surfaces through `AccountPreferences.fault()` like every
 * other preference write (DW-1326); the class has already flipped, and the instance's answer
 * decides nothing about what is on screen.
 *
 * Framework-free, like the rest of `core/` (AD-19), so `ui/tools/theme.test.mjs` executes it under
 * `node --test`; components mirror it into a signal.
 */

// The `.ts` extension is what lets `node --test` resolve this at runtime; see `tsconfig.json`'s
// `allowImportingTsExtensions`.
import { AccountPreferences, SHELL_KIND, SHELL_THEME, THEME_DARK, THEME_LIGHT } from './account-preferences.ts';

/** The one class that makes the document dark. `_theme.scss` is the only rule that selects it. */
export const THEME_DARK_CLASS = 'ocu-theme-dark';

/** The two themes, as the `shell.theme` member stores them. */
export type Theme = typeof THEME_LIGHT | typeof THEME_DARK;

/** The part of an element this store touches: its class list. `document.documentElement` in the app. */
export interface ThemeRoot {
  readonly classList: { toggle(token: string, force?: boolean): boolean };
}

export interface ThemeStateOptions {
  readonly account: AccountPreferences;
  readonly root: ThemeRoot;
}

export class ThemeState {
  private readonly account: AccountPreferences;

  private readonly root: ThemeRoot;

  private current: Theme = THEME_LIGHT;

  /**
   * Whether the instance's answer has been adopted since the last sign-in. The remembered theme
   * applies once, on the settled read; a later notification -- another preference being written --
   * must not re-apply it over a toggle the user has made since.
   */
  private adopted = false;

  private readonly listeners = new Set<() => void>();

  constructor(options: ThemeStateOptions) {
    this.account = options.account;
    this.root = options.root;
    this.apply();
    this.account.subscribe(() => this.adoptRemembered());
    this.adoptRemembered();
  }

  /** The theme on screen. */
  theme(): Theme {
    return this.current;
  }

  /** Whether the dark theme is on screen, which is what the account menu's checkbox mirrors. */
  isDark(): boolean {
    return this.current === THEME_DARK;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  /** The user's choice: flip the class at once and remember it on the instance. */
  setTheme(theme: Theme): void {
    if (theme === this.current) return;
    this.current = theme;
    this.apply();
    this.notify();
    // Never awaited: the class has already flipped, and a refusal is announced through the
    // account store's fault, not by undoing what the user chose.
    void this.account.setValue(SHELL_KIND, SHELL_THEME, theme);
  }

  /** The account menu's "Dark theme" item. */
  toggle(): void {
    this.setTheme(this.current === THEME_DARK ? THEME_LIGHT : THEME_DARK);
  }

  /**
   * Back to light for the next principal (AD-8). The theme is one account's row, so without this
   * the next sign-in in this tab renders the departed principal's theme until its own read settles.
   */
  endSession(): void {
    this.adopted = false;
    if (this.current === THEME_LIGHT) return;
    this.current = THEME_LIGHT;
    this.apply();
    this.notify();
  }

  /**
   * Take the instance's remembered theme, once, on the settled read. An unknown or absent value
   * reads as light; a read that has not settled leaves the theme on screen standing.
   */
  private adoptRemembered(): void {
    if (!this.account.loaded()) {
      this.adopted = false;
      return;
    }
    if (this.adopted) return;
    this.adopted = true;
    const next: Theme = this.account.shell().get(SHELL_THEME) === THEME_DARK ? THEME_DARK : THEME_LIGHT;
    if (next === this.current) return;
    this.current = next;
    this.apply();
    this.notify();
  }

  private apply(): void {
    this.root.classList.toggle(THEME_DARK_CLASS, this.current === THEME_DARK);
  }

  private notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}
