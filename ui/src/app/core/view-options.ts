/**
 * The one active binding behind the command bar's View control (EXPERIENCE.md "the command-bar
 * View control", DESIGN.md `:1039`, Story 6.11).
 *
 * `command-bar.ts` draws nothing here on its own: a page whose screen family has more than one
 * route -- Databases' General and Free-space views are the first (AD-5's `list (two views)`) --
 * registers its options, which route is current, and what choosing one does. The command bar
 * reads through this seam without knowing what "Databases" or "General" mean, the same separation
 * `ScreenActions` keeps between a declared action and the handler that carries it out.
 *
 * **One binding at a time**, like `RefreshService`'s: only the page currently on screen has a View
 * control to offer, so a second `register` replaces the first rather than layering by descriptor.
 * A page removes its own binding on destroy; replacing an unregistered binding is a no-op.
 *
 * Framework-free, like the rest of `core/`: a plain subscribable a component mirrors into a
 * signal.
 */

/** One entry the View control offers. */
export interface ViewOption {
  readonly route: string;
  readonly label: string;
}

/** What a page registers to drive the View control. */
export interface ViewOptionsBinding {
  /** The options to offer, in menu order. */
  readonly options: () => readonly ViewOption[];
  /** The route of the option in force right now. */
  readonly current: () => string;
  /** Carry out choosing `route` -- ordinarily a navigation, never a client-side toggle. */
  readonly choose: (route: string) => void;
}

export class ViewOptions {
  private binding: ViewOptionsBinding | null = null;

  private readonly listeners = new Set<() => void>();

  /** Register `binding` as the active View control, replacing whatever was there. Returns the remover. */
  register(binding: ViewOptionsBinding): () => void {
    this.binding = binding;
    this.notify();
    return () => {
      if (this.binding !== binding) return;
      this.binding = null;
      this.notify();
    };
  }

  /** Whether a page has a View control registered right now. */
  has(): boolean {
    return this.binding !== null;
  }

  options(): readonly ViewOption[] {
    return this.binding?.options() ?? [];
  }

  current(): string {
    return this.binding?.current() ?? '';
  }

  choose(route: string): void {
    this.binding?.choose(route);
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  private notify(): void {
    for (const listener of this.listeners) listener();
  }
}
