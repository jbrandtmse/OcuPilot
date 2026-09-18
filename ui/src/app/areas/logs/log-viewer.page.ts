import { ChangeDetectionStrategy, Component, DestroyRef, ElementRef, inject, signal, viewChild } from '@angular/core';
import { Router } from '@angular/router';

import { isBannerFault } from '../../core/fault';
import { formatDeniedAction, NavigationService } from '../../core/navigation';
import { REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { STRINGS } from '../../core/strings';
import {
  SEVERITY_CHIPS,
  highlightSpans,
  matchCountText,
  matchesSearch,
  severityChipKey,
  severityWord,
  type LogLine,
} from './log-line';
import { ALERTS_SOURCE, LogViewerStore, type LogViewerSource } from './log-viewer.store';

/** One row, resolved for drawing: the cells' text and the search spans of its message. */
interface RowView {
  readonly key: string;
  readonly stamp: string;
  readonly pid: string;
  readonly severityWord: string;
  readonly chip: string;
  readonly spans: readonly { readonly text: string; readonly match: boolean }[];
  readonly raw: string;
  readonly match: boolean;
}

/** One severity chip, resolved for drawing. */
interface ChipView {
  readonly key: string;
  readonly word: string;
  readonly active: boolean;
  readonly count: number;
}

/** The source each `log-viewer` descriptor reads, keyed by its route. */
const SOURCES: Readonly<Record<string, LogViewerSource>> = {
  'logs/alerts': ALERTS_SOURCE,
};

/**
 * The page every `log-viewer` archetype renders (AD-5): a bounded window of one instance log file,
 * merged with whatever the monitoring API reports since that window's earliest entry.
 *
 * Story 6.13 builds it for `alerts.log`; Story 6.14 declares `messages.log` against it and adds a
 * route to `SOURCES` rather than a page of its own.
 *
 * **Nothing streams and nothing ticks** (AD-43). The store issues one read when the screen opens
 * and one per explicit Load newer; there is no interval, no `EventSource` and no `WebSocket`.
 *
 * **Every severity carries its word** (`EXPERIENCE.md` Accessibility Floor, `DESIGN.md` severity
 * pairs): the chip is a word on a colour pair, never a colour alone, and a level the vendor's scale
 * does not name reads as the number itself rather than being dropped.
 *
 * **The chips are the filter.** Clicking one sets that severity as the filter and marks the chip
 * `aria-pressed`; clicking the pressed chip clears it. The sticky search is an
 * `input type="search"` and carries the browser's own clear affordance. EXPERIENCE.md's
 * "Clear filter" is the command bar's `button-text`, and the shell's command bar renders no such
 * control today, so this screen offers none either -- DW-1109.
 *
 * **Next and previous over the matches are the search field's own Enter and Shift+Enter**, not two
 * buttons. EXPERIENCE.md publishes no name for either control, and an icon button with no published
 * accessible name is worse than a keyboard affordance the polite count already announces.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-log-viewer-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<section class="ocu-log-viewer">
    <div class="ocu-log-viewer-bar">
      <input
        class="ocu-command-bar-filter ocu-log-viewer-search"
        type="search"
        data-ocu-log="search"
        [attr.aria-label]="STRINGS.auditCriteriaSearch"
        [attr.placeholder]="STRINGS.auditCriteriaSearch"
        [value]="search"
        (input)="onSearch($event)"
        (keydown)="onSearchKey($event)"
      />
      <p class="ocu-log-viewer-count" role="status" data-ocu-log="count">{{ countText }}</p>
      <button type="button" class="ocu-button-text" data-ocu-log="top" (click)="onTop()">
        {{ STRINGS.logViewerJumpTop }}
      </button>
      <button type="button" class="ocu-button-text" data-ocu-log="bottom" (click)="onBottom()">
        {{ STRINGS.logViewerJumpBottom }}
      </button>
      <button
        type="button"
        class="ocu-button-text ocu-log-viewer-raw"
        data-ocu-log="raw"
        [attr.aria-pressed]="raw"
        (click)="onRaw()"
      >
        {{ STRINGS.openApiRaw }}
      </button>
    </div>

    <div class="ocu-log-viewer-chips" data-ocu-log="chips">
      @for (chip of chips; track chip.key) {
        <button
          type="button"
          class="ocu-log-chip"
          [class.ocu-log-chip-active]="chip.active"
          [attr.data-ocu-chip]="chip.key"
          [attr.aria-pressed]="chip.active"
          (click)="onChip(chip.key)"
        >
          <span class="ocu-log-chip-word">{{ chip.word }}</span>
          <span class="ocu-log-chip-count">{{ chip.count }}</span>
        </button>
      }
    </div>

    @if (showRecentNotice) {
      <p class="ocu-log-viewer-notice" role="status" data-ocu-log="recent-unavailable">
        {{ STRINGS.alertLogRecentUnavailable }}
      </p>
    }

    @if (showRefusal) {
      <div class="ocu-data-table-refusal" role="alert" data-ocu-log="refusal">
        <span class="ocu-data-table-refusal-message">{{ refusalMessage }}</span>
      </div>
    }

    @if (showEmpty) {
      <section class="ocu-empty-state ocu-data-table-empty" tabindex="-1">
        <p class="ocu-data-table-empty-title" data-ocu-log="empty">{{ emptyTitle }}</p>
        <p class="ocu-data-table-empty-next">{{ STRINGS.tableReadOnlyEmptyNext }}</p>
      </section>
    }

    @if (showRows) {
      <div class="ocu-log-viewport" #viewport data-ocu-log="viewport" tabindex="0">
        @if (raw) {
          <pre class="ocu-log-raw" data-ocu-log="raw-block">@for (row of rows; track row.key; let index = $index) {<span
              class="ocu-log-raw-line"
              ><span class="ocu-log-raw-gutter">{{ index + 1 }}</span
              >{{ row.raw }}
</span>}</pre>
        } @else {
          <div class="ocu-log-rows" role="list">
            @for (row of rows; track row.key) {
              <div
                class="ocu-log-row"
                role="listitem"
                [class.ocu-log-row-match]="row.match"
                [attr.data-ocu-row]="row.key"
                [attr.data-ocu-severity]="row.chip"
              >
                <span class="ocu-log-cell ocu-log-cell-time">{{ row.stamp }}</span>
                <span class="ocu-log-cell ocu-log-cell-pid">{{ row.pid }}</span>
                <span class="ocu-log-cell ocu-log-cell-severity">
                  <span class="ocu-log-chip ocu-log-chip-static" [attr.data-ocu-chip]="row.chip">{{
                    row.severityWord
                  }}</span>
                </span>
                <span class="ocu-log-cell ocu-log-cell-text">
                  @for (span of row.spans; track $index) {
                    @if (span.match) {
                      <mark class="ocu-log-mark">{{ span.text }}</mark>
                    } @else {
                      <span>{{ span.text }}</span>
                    }
                  }
                </span>
              </div>
            }
          </div>
        }
      </div>
    }

    @if (showLoadNewer) {
      <button type="button" class="ocu-button-text ocu-log-load-newer" data-ocu-log="load-newer" (click)="onLoadNewer()">
        {{ STRINGS.logViewerLoadNewer }}
      </button>
    }
  </section>`,
})
export class LogViewerPage {
  private readonly store = inject(LogViewerStore);

  private readonly navigation = inject(NavigationService);

  private readonly router = inject(Router);

  private readonly actions = inject(ScreenActions);

  protected readonly STRINGS = STRINGS;

  private readonly viewport = viewChild<ElementRef<HTMLElement>>('viewport');

  /** Bumped by the store, so the rows re-render under `OnPush`. */
  private readonly generation = signal(0);

  private searchValue = '';

  private chipValue = '';

  private rawValue = false;

  /** Which match the caret is on, 1-based; 0 before the first Next. */
  private caretValue = 0;

  constructor() {
    const stop = this.store.subscribe(() => this.generation.update((value) => value + 1));
    const screen = this.navigation.screenForUrl(this.router.url);
    this.store.setSource(SOURCES[screen?.route ?? ''] ?? ALERTS_SOURCE);
    // Manual Refresh only (DW-260). This screen binds no `RefreshService`: its declared read is the
    // monitoring half alone, while the screen is that half merged with a bounded tail, and one
    // refresh binding cannot re-issue both halves in the order the merge needs.
    const stopRefreshAction =
      screen === null
        ? null
        : this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
            void this.store.open();
          });
    inject(DestroyRef).onDestroy(() => {
      stop();
      stopRefreshAction?.();
    });
    if (!this.store.loaded() && !this.store.loading()) void this.store.open();
  }

  protected get search(): string {
    return this.searchValue;
  }

  protected get raw(): boolean {
    return this.rawValue;
  }

  /** The entries the chip filter admits, oldest first, before the search narrows anything. */
  private get filtered(): readonly LogLine[] {
    this.generation();
    const chip = this.chipValue;
    if (chip === '') return this.store.lines();
    return this.store.lines().filter((line) => severityChipKey(line.severity) === chip);
  }

  protected get rows(): readonly RowView[] {
    const needle = this.searchValue;
    return this.filtered.map((line, index) => ({
      key: String(index) + '|' + line.stamp + '|' + line.pid,
      stamp: line.stamp,
      pid: line.pid === '' ? STRINGS.tableEmptyValue : line.pid,
      severityWord: severityWord(line.severity),
      chip: severityChipKey(line.severity),
      spans: highlightSpans(line.text, needle),
      raw: line.raw,
      match: matchesSearch(line, needle),
    }));
  }

  protected get chips(): readonly ChipView[] {
    this.generation();
    const lines = this.store.lines();
    return SEVERITY_CHIPS.map((chip) => ({
      key: chip.key,
      word: chip.word,
      active: this.chipValue === chip.key,
      count: lines.filter((line) => chip.levels.includes(line.severity)).length,
    }));
  }

  /** The polite count, `''` while nothing is searched for. */
  protected get countText(): string {
    if (this.searchValue === '') return '';
    const total = this.rows.filter((row) => row.match).length;
    return matchCountText(total === 0 ? 0 : this.caretValue, total);
  }

  /**
   * Whether a search is active and narrows the list to nothing. The search highlights rather than
   * filters, so without this the published "No matches." would be unreachable from the search and
   * a fruitless search would leave every row on screen unmarked.
   */
  private get searchFoundNothing(): boolean {
    this.generation();
    if (this.searchValue === '') return false;
    return !this.filtered.some((line) => matchesSearch(line, this.searchValue));
  }

  protected get showRecentNotice(): boolean {
    this.generation();
    return this.store.recentUnavailable() && this.store.lines().length > 0;
  }

  protected get showRefusal(): boolean {
    this.generation();
    const fault = this.store.fault();
    return fault !== null && !isBannerFault(fault);
  }

  protected get refusalMessage(): string {
    this.generation();
    const pair = this.store.failedPair();
    if (this.store.fault()?.code === 'AUTH.NOPRIVILEGE' && pair !== '') {
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.errorLogRefusedAction);
    }
    return STRINGS.connectivityRequestRefused;
  }

  protected get showRows(): boolean {
    this.generation();
    return this.store.loaded() && this.rows.length > 0 && !this.searchFoundNothing;
  }

  protected get showEmpty(): boolean {
    this.generation();
    if (!this.store.loaded() || this.store.fault() !== null) return false;
    return this.rows.length === 0 || this.searchFoundNothing;
  }

  /**
   * Which empty state: "No matches." when the user narrowed the list to nothing, "No entries."
   * when the file itself had none. The distinction is the whole point of publishing two.
   */
  protected get emptyTitle(): string {
    this.generation();
    const narrowed = this.searchValue !== '' || this.chipValue !== '';
    return narrowed && this.store.lines().length > 0 ? STRINGS.logViewerNoMatches : STRINGS.logViewerEmpty;
  }

  protected get showLoadNewer(): boolean {
    this.generation();
    return this.store.canLoadNewer();
  }

  protected onSearch(event: Event): void {
    const target = event.target;
    this.searchValue = target instanceof HTMLInputElement ? target.value : '';
    this.caretValue = this.searchValue === '' ? 0 : 1;
    this.generation.update((value) => value + 1);
  }

  protected onChip(key: string): void {
    this.chipValue = this.chipValue === key ? '' : key;
    // The caret is a position within the matches, and the chip filter changes how many there are;
    // carrying it across would let the polite region announce "5 of 2".
    this.caretValue = this.searchValue === '' ? 0 : 1;
    this.generation.update((value) => value + 1);
  }

  protected onRaw(): void {
    this.rawValue = !this.rawValue;
    this.generation.update((value) => value + 1);
  }

  /**
   * Enter moves the caret to the next match, Shift+Enter to the previous. Read off the event rather
   * than bound as two `keydown.enter` pseudo-events: a search input's own Enter has browser
   * behaviour of its own, and one handler that inspects the key is what makes both directions
   * observable in a real browser.
   */
  protected onSearchKey(event: KeyboardEvent): void {
    if (event.key !== 'Enter') return;
    event.preventDefault();
    this.step(event.shiftKey ? -1 : 1);
  }

  protected onTop(): void {
    this.viewport()?.nativeElement.scrollTo({ top: 0 });
  }

  protected onBottom(): void {
    const element = this.viewport()?.nativeElement;
    if (element === undefined) return;
    element.scrollTo({ top: element.scrollHeight });
  }

  protected onLoadNewer(): void {
    void this.store.loadNewer();
  }

  /** Move the caret over the matches, wrapping at both ends so neither control is a dead end. */
  private step(by: number): void {
    const total = this.rows.filter((row) => row.match).length;
    if (total === 0) {
      this.caretValue = 0;
      return;
    }
    const next = this.caretValue + by;
    this.caretValue = next < 1 ? total : next > total ? 1 : next;
    this.generation.update((value) => value + 1);
  }
}
