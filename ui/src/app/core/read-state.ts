/**
 * The states a screen-bound view draws while its read runs (AD-36, AD-43): whether the framework is bound to the screen, whether its
 * first answer has landed, the refusal the connectivity banner has no copy for, the skeleton, and the empty answer.
 *
 * `DataTable` and the detail tabs' body components (`MessageTabBody`) draw these same states over the same `RefreshService` and
 * `ScreenStore`; this is the one place that decides them. A caller hands it the framework's answers, the screen and its store as
 * functions (they are signal inputs in a component), and `touch`, which a component passes to read the signal it bumps so the
 * answer is a dependency of the template that asks.
 *
 * Framework-free, like the rest of `core/`, so `ui/tools/read-state.test.mjs` executes it under `node --test`.
 */

import { type Fault, isBannerFault } from './fault.ts';
import type { ScreenStore } from './screen-store.ts';
import type { ScreenDeclaration } from './screens.generated';

/** The part of the auto-refresh framework a view asks. */
export interface ReadStateSource {
  descriptor(): string;
  hasLoaded(): boolean;
  fault(): Fault | null;
}

export class ReadState {
  private readonly source: ReadStateSource;
  private readonly screen: () => ScreenDeclaration;
  private readonly store: () => ScreenStore;
  private readonly touch: () => unknown;

  constructor(source: ReadStateSource, screen: () => ScreenDeclaration, store: () => ScreenStore, touch: () => unknown = () => undefined) {
    this.source = source;
    this.screen = screen;
    this.store = store;
    this.touch = touch;
  }

  /** Whether the framework is bound to this screen, which is when its answers are this screen's. */
  get boundHere(): boolean {
    this.touch();
    return this.source.descriptor() === this.screen().descriptor;
  }

  /** Whether this screen's first answer has landed. */
  get loaded(): boolean {
    return this.boundHere && this.source.hasLoaded();
  }

  /** This screen's fault, or `null`. */
  get fault(): Fault | null {
    return this.boundHere ? this.source.fault() : null;
  }

  /** A refusal the connectivity banner has no copy for, drawn with Retry in place of the rows. */
  get showRefusal(): boolean {
    const fault = this.fault;
    return fault !== null && !isBannerFault(fault);
  }

  get showSkeleton(): boolean {
    return !this.loaded && !this.showRefusal;
  }

  /** `aria-busy`'s value: `'true'` while the skeleton shows, else `null`. */
  get busy(): string | null {
    return this.showSkeleton ? 'true' : null;
  }

  /** Whether the answer holds no row. */
  get showEmpty(): boolean {
    return this.loaded && this.fault === null && this.store().data().length === 0;
  }
}
