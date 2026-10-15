import { DestroyRef, Directive, type OnInit, inject, input, signal } from '@angular/core';

import { ReadState } from '../../core/read-state';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import type { ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { emptyStateView } from '../../core/table-model';

/**
 * What a message tab's body component shares (Stories 20.9 and 20.30, AD-5, AD-19): the screen and its store as inputs, the states
 * the read draws while it runs -- the first answer, a refusal with Retry, the empty sentence -- decided by `ReadState`, the one
 * decision `DataTable` makes too, and a signal the store, the framework and the scope bump so the body re-renders under `OnPush`.
 *
 * A subclass supplies its template and what it draws once the rows have landed. `ListPage` binds the read, the refresh and the
 * id-change re-read; a body only draws what the store holds. Every control-flow condition in a template stays a paren-free member
 * reference, for the reason `sign-in.ts` records.
 */
@Directive()
export abstract class MessageTabBody implements OnInit {
  /** The tab's declaration, whose read the page binds. */
  readonly screen = input.required<ScreenDeclaration>();

  /** The screen's store, which holds the rows the read answered. */
  readonly store = input.required<ScreenStore>();

  protected readonly refresh = inject(RefreshService);
  protected readonly scope = inject(ScopeService);
  private readonly destroyRef = inject(DestroyRef);

  protected readonly STRINGS = STRINGS;
  protected readonly skeletonRows = [0, 1, 2, 3, 4, 5];

  /** Bumped by the store and the framework, so the block re-renders under `OnPush`. */
  protected readonly generation = signal(0);

  private readonly readState = new ReadState(
    this.refresh,
    () => this.screen(),
    () => this.store(),
    () => this.generation()
  );

  constructor() {
    const stopRefresh = this.refresh.subscribe(() => this.bump());
    const stopScope = this.scope.subscribe(() => this.bump());
    this.destroyRef.onDestroy(() => {
      stopRefresh();
      stopScope();
    });
  }

  ngOnInit(): void {
    const stopStore = this.store().subscribe(() => this.bump());
    this.destroyRef.onDestroy(stopStore);
  }

  /** Whether the first answer for this screen has landed. */
  protected get loaded(): boolean {
    return this.readState.loaded;
  }

  protected get showRefusal(): boolean {
    return this.readState.showRefusal;
  }

  protected get showSkeleton(): boolean {
    return this.readState.showSkeleton;
  }

  protected get busy(): string | null {
    return this.readState.busy;
  }

  /** The answer holds no row. */
  protected get showEmpty(): boolean {
    return this.readState.showEmpty;
  }

  /** The answer holds rows to draw. */
  protected get showRows(): boolean {
    return this.loaded && !this.showEmpty;
  }

  protected get emptyTitle(): string {
    return emptyStateView(this.screen(), this.scope.namespace()).title;
  }

  protected get emptyNext(): string {
    return emptyStateView(this.screen(), this.scope.namespace()).next;
  }

  protected onRetry(): void {
    void this.refresh.readNow();
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}
