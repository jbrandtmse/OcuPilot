import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, signal } from '@angular/core';

import { LongBlocks, blockId, isLong } from '../core/long-blocks';
import { STRINGS } from '../core/strings';

/**
 * One long block in the agent panel (Story 20.17, EXPERIENCE.md panel > Long blocks).
 *
 * The projected content is always whole in the DOM. A block whose `lines` estimate is above eight
 * is clamped to eight lines by CSS and carries a native Show more / Show less button; a shorter
 * block renders neither the button nor the clamp class. Focus moving into a collapsed region
 * opens it, so focus is never hidden.
 *
 * What a person opened is kept in the injected `LongBlocks` by `key`, so it survives a re-render
 * and a later turn. An empty `key` is kept in this component only. The region id derives from the
 * key, never from a counter, so a streamed turn and a plain one render the same DOM.
 *
 * Every control-flow condition is a paren-free member reference (`client-lint.mjs`).
 */
@Component({
  selector: 'app-long-block',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { class: 'ocu-long-block-host' },
  template: `<div class="ocu-long-block" [class.ocu-long-block-collapsed]="collapsed">
    <div class="ocu-long-block-region" [attr.id]="regionId" (focusin)="onFocusIn()">
      <ng-content />
    </div>
    @if (long) {
      <button
        type="button"
        class="ocu-long-block-toggle"
        [attr.aria-expanded]="expandedAttr"
        [attr.aria-controls]="regionId"
        (click)="toggle()"
      >
        {{ toggleLabel }}
      </button>
    }
  </div>`,
})
export class LongBlock {
  /** The block's stable key, or `''` for a block whose state stays in this component. */
  readonly key = input<string>('');

  /** The block's estimated line count (`estimateLines`). */
  readonly lines = input<number>(0);

  protected readonly STRINGS = STRINGS;

  private readonly store = inject(LongBlocks, { optional: true }) ?? new LongBlocks();

  /** The store's answer for this key, and the local state an empty key keeps. */
  private readonly storeVersion = signal(0);
  private readonly localOpen = signal(false);

  constructor() {
    const release = this.store.subscribe(() => this.storeVersion.update((value) => value + 1));
    inject(DestroyRef).onDestroy(release);
  }

  protected get long(): boolean {
    return isLong(this.lines());
  }

  protected get open(): boolean {
    this.storeVersion();
    const key = this.key();
    return key === '' ? this.localOpen() : this.store.isOpen(key);
  }

  protected get collapsed(): boolean {
    return this.long && !this.open;
  }

  protected get expandedAttr(): string {
    return this.open ? 'true' : 'false';
  }

  protected get toggleLabel(): string {
    return this.open ? STRINGS.longBlockShowLess : STRINGS.longBlockShowMore;
  }

  protected get regionId(): string {
    return blockId(this.key());
  }

  protected toggle(): void {
    this.setOpen(!this.open);
  }

  protected onFocusIn(): void {
    if (this.collapsed) this.setOpen(true);
  }

  private setOpen(open: boolean): void {
    const key = this.key();
    if (key === '') this.localOpen.set(open);
    else this.store.setOpen(key, open);
  }
}
