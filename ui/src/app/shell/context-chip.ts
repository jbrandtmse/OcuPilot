import { ChangeDetectionStrategy, Component, DestroyRef, inject, input, signal } from '@angular/core';
import { Router } from '@angular/router';

import { AgentContext } from '../core/agent-context';
import { screenForUrl } from '../core/navigation';
import { ScopeService, onScopeChange } from '../core/scope';
import { CONTEXT_CHIP_OFF_ID } from '../core/explain-entry';
import { contextRowsSent, contextViewDeclared } from '../core/screen-context';
import { ScreenStores } from '../core/screen-store';
import { STRINGS, stringFor } from '../core/strings';
import { formatRowCount } from '../core/table-model';

/** The sharing-off sentence's id, which describes a control that needs context sharing on. */
export { CONTEXT_CHIP_OFF_ID };

/**
 * The context chip (Story 4.11, `panel.ts`'s `.ocu-panel-chip-slot`): what the next turn would
 * send, the toggle that decides whether anything is, and the paste warning's sibling fact --
 * which fields on this screen are never sent at all.
 *
 * **Every fact but the toggle's own click is read, never remembered.** `AgentContext` is the one
 * source of `share`, `contextRowCap`, `provider`, `endpointHost` and `leavesInstance` (AD-42);
 * this component derives nothing about where a request goes on its own. The screen, the
 * namespace and the row count are read fresh on every update from `ScopeService`, the resolved
 * router URL and the current screen's own `ScreenStore` -- the same three sources `panel.ts`
 * reads again at the moment Send is pressed (`assembleScreenContext`), so the chip's row count
 * and the posted count cannot disagree.
 *
 * **Visibility is the caller's job.** `panel.ts` renders this component only once an enabled
 * definition exists, `AgentContext` has answered and the namespace has resolved (Boundaries &
 * Constraints' "Absent chip"); this component assumes it is meant to be on screen and only
 * decides what to show, never whether to show anything at all.
 *
 * **Sharing off is a total override, not a missing segment.** The Boundaries & Constraints rule
 * reads "the chip reads exactly `STRINGS.contextChipSharingOff`" -- so the off branch renders
 * that sentence alone, with no pill, no glyph and no row segment, rather than the on branch with
 * pieces omitted.
 *
 * The `\u00b7` separators are plain text within the composed sentence (pinned byte-for-byte
 * against `STRINGS.contextChipScreenSegment`) but each rendered as its own `aria-hidden` node,
 * the same convention `locator-bar.ts`'s own separator follows, so `textContent` reproduces the
 * string while a screen reader hears the words alone.
 */
@Component({
  selector: 'app-context-chip',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<div class="ocu-context-chip" [class.ocu-context-chip-restrained]="killSwitch()">
    <div class="ocu-context-chip-text">
      @if (shareOn) {
        <span>{{ screenSegment }}</span>
        @for (segment of extraSegments; track $index) {
          <span aria-hidden="true">{{ separatorText }}</span><span>{{ segment }}</span>
        }
        @if (secretGlyphVisible) {
          <span class="ocu-context-chip-glyph" aria-hidden="true">{{ keyGlyph }}</span>
          <span class="ocu-visually-hidden">{{ STRINGS.agentContextChipSecretGlyph }}</span>
        }
        @if (pillVisible) {
          <span class="ocu-context-chip-pill" [attr.title]="pillTitle">{{ STRINGS.contextChipLeavesInstance }}</span>
          <span class="ocu-visually-hidden">{{ pillTitle }}</span>
        }
      } @else {
        <span class="ocu-context-chip-off" [id]="offId">{{ STRINGS.contextChipSharingOff }}</span>
      }
    </div>
    <label class="ocu-context-chip-toggle">
      <span class="ocu-visually-hidden">{{ STRINGS.agentShareContextLabel }}</span>
      <input
        type="checkbox"
        role="switch"
        class="ocu-context-chip-switch"
        [attr.aria-label]="STRINGS.agentShareContextLabel"
        [checked]="shareOn"
        (change)="onToggle($event)"
      />
    </label>
  </div>`,
})
export class ContextChip {
  private readonly router = inject(Router);
  private readonly scope = inject(ScopeService);
  private readonly stores = inject(ScreenStores);
  private readonly agentContext = inject(AgentContext);

  protected readonly STRINGS = STRINGS;

  protected readonly offId = CONTEXT_CHIP_OFF_ID;

  /** " \u00b7 " between segments, itself `aria-hidden`; composing with the segments around it
   * reproduces `STRINGS.contextChipScreenSegment` byte for byte. */
  protected readonly separatorText = ' \u00b7 ';

  /** The 14px key glyph, itself `aria-hidden`; its name is `STRINGS.agentContextChipSecretGlyph`. */
  protected readonly keyGlyph = '\u26bf';

  /** Whether the agent is switched off for this caller (DESIGN.md "Kill switch on"), from `panel.ts`. */
  readonly killSwitch = input<boolean>(false);

  /** Bumped by every source below, so the template re-reads them under `OnPush` (AD-19). */
  private readonly generation = signal(0);

  /** The descriptor whose `ScreenStore` this component is currently listening to, or `''`. */
  private boundDescriptor = '';
  private stopStore: (() => void) | null = null;

  constructor() {
    const stopRouter = this.router.events.subscribe(() => {
      this.rebindStore();
      this.bump();
    });
    const stopScope = onScopeChange(this.scope, () => this.bump());
    const stopContext = this.agentContext.subscribe(() => this.bump());
    this.rebindStore();
    inject(DestroyRef).onDestroy(() => {
      stopRouter.unsubscribe();
      stopScope();
      stopContext();
      this.stopStore?.();
    });
  }

  /** The resolved current screen, or `null` for a URL naming no built descriptor. */
  private get screen() {
    return screenForUrl(this.router.url);
  }

  /**
   * Follow the current screen's `ScreenStore` (Boundaries & Constraints: "selection and the
   * screen's filtered and sorted view"). Re-subscribes only when the screen actually changed, so
   * a route event that leaves the descriptor the same (a query-only navigation) does not churn
   * the subscription.
   */
  private rebindStore(): void {
    const screen = this.screen;
    const descriptor = screen === null ? '' : screen.descriptor;
    if (descriptor === this.boundDescriptor) return;
    this.stopStore?.();
    this.stopStore = null;
    this.boundDescriptor = descriptor;
    if (screen === null) return;
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    this.stopStore = store.subscribe(() => this.bump());
  }

  protected get shareOn(): boolean {
    this.generation();
    return this.agentContext.share();
  }

  /** `<Screen>, <NAMESPACE>` (Boundaries & Constraints), the chip's one non-`aria-hidden` comma. */
  protected get screenSegment(): string {
    this.generation();
    const screen = this.screen;
    const screenLabel = screen === null ? '' : stringFor(screen.labelKey);
    return screenLabel + ', ' + this.scope.namespace();
  }

  /** The row count, provider and endpoint host, in that order, each its own segment. */
  protected get extraSegments(): readonly string[] {
    this.generation();
    const segments: string[] = [];
    if (this.rowSegmentVisible) segments.push(formatRowCount(STRINGS.tableRowCount, this.rowCount));
    if (this.agentContext.provider() !== '') segments.push(this.agentContext.provider());
    if (this.agentContext.endpointHost() !== '') segments.push(this.agentContext.endpointHost());
    return segments;
  }

  private get rowSegmentVisible(): boolean {
    return contextViewDeclared(this.screen);
  }

  private get rowCount(): number {
    const screen = this.screen;
    if (screen === null) return 0;
    const store = this.stores.for(screen.descriptor, screen.refreshRates);
    return contextRowsSent({
      descriptor: screen,
      rows: store.data(),
      filter: store.filter(),
      sort: store.sort(),
      direction: store.direction(),
      rowCap: this.agentContext.contextRowCap(),
    });
  }

  /** The key glyph: named for the current screen's declared secret fields, never their values. */
  protected get secretGlyphVisible(): boolean {
    this.generation();
    const screen = this.screen;
    return screen !== null && screen.context.secretFields.length > 0;
  }

  protected get pillVisible(): boolean {
    this.generation();
    return this.agentContext.leavesInstance() === true;
  }

  protected get pillTitle(): string {
    return STRINGS.contextChipSentToHost.split('<host>').join(this.agentContext.endpointHost());
  }

  protected onToggle(event: Event): void {
    void this.agentContext.setShare((event.target as HTMLInputElement).checked);
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }
}
