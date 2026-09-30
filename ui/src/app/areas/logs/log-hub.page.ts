import { LocationStrategy } from '@angular/common';
import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { csvFileName, csvText, saveCsv } from '../../core/csv';
import { ExplainEntry } from '../../core/explain-entry';
import { isBannerFault } from '../../core/fault';
import { NavigationService, entityUrl, formatDeniedAction, formatRequires, screenForRoute, withQuery } from '../../core/navigation';
import { RefreshService, type RefreshRead } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { DOWNLOAD_CSV_ACTION_ID, REFRESH_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenArrivals } from '../../core/screen-arrival';
import { applyView } from '../../core/screen-read';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS, stringFor } from '../../core/strings';
import { SEVERITY_CHIPS, severityChipKey, severityWord } from './log-line';
import { LogHubStore, nextSecond, type LogHubRow } from './log-hub.store';

/** The not-shown notice's placeholder for the source's label; `<resource>` is the navigation module's. */
const SOURCE_PLACEHOLDER = '<source>';

/** The id the no-entries sentence of a Sources row takes, which that row's refused Explain describes itself by. */
const NO_ENTRY_PREFIX = 'ocu-log-hub-none-';

/** The id the Requires reason of a Sources row takes. */
const REASON_PREFIX = 'ocu-log-hub-reason-';

/** One Sources row, resolved for drawing. */
interface SourceView {
  readonly route: string;
  readonly label: string;
  readonly href: string;
  readonly shown: boolean;
  readonly reason: string;
  readonly reasonId: string;
  readonly count: number;
  readonly truncated: boolean;
  readonly last: EntryView | null;
  readonly noEntryId: string;
  readonly explainDisabled: 'true' | null;
  readonly explainDescribedBy: string | null;
}

/** One timeline row, resolved for drawing. */
interface EntryView {
  readonly key: string;
  readonly row: LogHubRow;
  readonly href: string;
  readonly sourceLabel: string;
  readonly chip: string;
  readonly severityWord: string;
  readonly hasSeverity: boolean;
}

/** One filter option. */
interface OptionView {
  readonly value: string;
  readonly text: string;
  readonly selected: boolean;
}

/**
 * The unified log hub (Story 16.9, FR-77): the Sources list -- each Logs source with its entry
 * count, its last entry and an explain entry point -- and the Timeline, every shown source's
 * entries merged newest first over a window, filtered by source, severity and the command bar's
 * text. Both are sections over the hub's one composed read (AD-36 as amended).
 *
 * **What is on screen is the screen context** (AD-24): the rows the Source and Severity filters
 * leave are published into the hub's store, so a turn, the context chip and Download CSV read them
 * through the store's own filter, the same `applyView` this page draws with.
 *
 * **Opening an entry is a person's click, so it is never announced** (AD-11 rule 3). A log viewer
 * is handed the entry through `ScreenArrivals` and marks it; the audit viewer is handed the
 * criteria bracketing the entry's second and opens its dialog on the entry's id route; the
 * application error log drills to the entry's id route.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-log-hub-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<section class="ocu-log-hub" data-ocu-hub="page">
    @if (showRefusal) {
      <div class="ocu-data-table-refusal" role="alert" data-ocu-hub="refusal">
        <span class="ocu-data-table-refusal-message">{{ refusalMessage }}</span>
      </div>
    }

    <section class="ocu-log-hub-section" aria-labelledby="ocu-log-hub-sources-heading">
      <h2 class="ocu-log-hub-heading" id="ocu-log-hub-sources-heading">{{ STRINGS.logHubSourcesHeading }}</h2>
      <div class="ocu-log-hub-frame">
        <table class="ocu-log-hub-table" data-ocu-hub="sources">
          <thead>
            <tr>
              <th scope="col" class="ocu-log-hub-th">{{ STRINGS.auditEventFieldSource }}</th>
              <th scope="col" class="ocu-log-hub-th">{{ STRINGS.logHubColumnEntries }}</th>
              <th scope="col" class="ocu-log-hub-th">{{ STRINGS.logHubColumnLastEntry }}</th>
              @if (explainShown) {
                <th scope="col" class="ocu-log-hub-th">
                  <span class="ocu-visually-hidden">{{ STRINGS.agentExplainEntryAction }}</span>
                </th>
              }
            </tr>
          </thead>
          <tbody>
            @for (source of sourceRows; track source.route) {
              <tr class="ocu-log-hub-tr" [attr.data-ocu-source]="source.route">
                <td class="ocu-log-hub-td">
                  @if (source.shown) {
                    <a class="ocu-data-table-link" data-ocu-hub="source-link" [href]="source.href" (click)="onOpenSource($event, source)">{{
                      source.label
                    }}</a>
                  } @else {
                    <a
                      class="ocu-data-table-link ocu-log-hub-denied"
                      role="link"
                      aria-disabled="true"
                      data-ocu-hub="source-link"
                      [attr.aria-describedby]="source.reasonId"
                      >{{ source.label }}</a
                    >
                    <span class="ocu-log-hub-reason" [id]="source.reasonId">{{ source.reason }}</span>
                  }
                </td>
                <td class="ocu-log-hub-td" data-ocu-hub="count">
                  <span class="ocu-log-hub-count">{{ source.count }}</span>
                  @if (source.truncated) {
                    <span class="ocu-log-hub-cap" data-ocu-hub="cap">{{ STRINGS.errorLogLevelCapNotice }}</span>
                  }
                </td>
                <td class="ocu-log-hub-td ocu-log-hub-last" data-ocu-hub="last">
                  @if (source.last; as last) {
                    <span class="ocu-log-hub-last-time">{{ last.row.time }}</span>
                    @if (last.hasSeverity) {
                      <span class="ocu-log-chip ocu-log-chip-static" [attr.data-ocu-chip]="last.chip">{{ last.severityWord }}</span>
                    }
                    <span class="ocu-log-hub-last-text">{{ last.row.text }}</span>
                  } @else {
                    <span class="ocu-log-hub-none" [id]="source.noEntryId">{{ STRINGS.logViewerEmpty }}</span>
                  }
                </td>
                @if (explainShown) {
                  <td class="ocu-log-hub-td">
                    <button
                      type="button"
                      class="ocu-button-text ocu-log-explain"
                      data-ocu-hub="source-explain"
                      [attr.aria-disabled]="source.explainDisabled"
                      [attr.aria-describedby]="source.explainDescribedBy"
                      (click)="onExplainSource(source)"
                    >
                      {{ STRINGS.agentExplainEntryAction }}
                    </button>
                  </td>
                }
              </tr>
            }
          </tbody>
        </table>
      </div>
    </section>

    <section class="ocu-log-hub-section" aria-labelledby="ocu-log-hub-timeline-heading">
      <h2 class="ocu-log-hub-heading" id="ocu-log-hub-timeline-heading">{{ STRINGS.logHubTimelineHeading }}</h2>
      <form class="ocu-criteria-form" (submit)="onSearch($event)">
        <div class="ocu-criteria-fields">
          <div class="ocu-criteria-field">
            <label class="ocu-criteria-label" for="ocu-log-hub-since">{{ STRINGS.auditCriteriaBegin }}</label>
            <input
              class="ocu-criteria-input"
              id="ocu-log-hub-since"
              type="text"
              data-ocu-hub="since"
              aria-describedby="ocu-log-hub-since-hint"
              [value]="since"
              (input)="onSince($event)"
            />
          </div>
        </div>
        <p class="ocu-criteria-hint" id="ocu-log-hub-since-hint">{{ STRINGS.auditCriteriaTimeHint }}</p>
        <div class="ocu-criteria-controls">
          <button type="submit" class="ocu-button-primary" data-ocu-hub="search">{{ STRINGS.auditCriteriaSearch }}</button>
        </div>
      </form>

      <div class="ocu-log-hub-filters">
        <div class="ocu-criteria-field">
          <label class="ocu-criteria-label" for="ocu-log-hub-source">{{ STRINGS.auditEventFieldSource }}</label>
          <select class="ocu-criteria-select" id="ocu-log-hub-source" data-ocu-hub="source-filter" (change)="onSourceFilter($event)">
            <option value="" [selected]="sourceAny">{{ STRINGS.auditCriteriaAnyOption }}</option>
            @for (option of sourceOptions; track option.value) {
              <option [value]="option.value" [selected]="option.selected">{{ option.text }}</option>
            }
          </select>
        </div>
        <div class="ocu-criteria-field">
          <label class="ocu-criteria-label" for="ocu-log-hub-severity">{{ STRINGS.logViewerColumnSeverity }}</label>
          <select class="ocu-criteria-select" id="ocu-log-hub-severity" data-ocu-hub="severity-filter" (change)="onSeverityFilter($event)">
            <option value="" [selected]="severityAny">{{ STRINGS.auditCriteriaAnyOption }}</option>
            @for (option of severityOptions; track option.value) {
              <option [value]="option.value" [selected]="option.selected">{{ option.text }}</option>
            }
          </select>
        </div>
        @if (showClear) {
          <button type="button" class="ocu-button-text ocu-log-hub-clear" data-ocu-hub="clear" (click)="onClear()">
            {{ STRINGS.logViewerClearFilter }}
          </button>
        }
      </div>

      @if (showNotice) {
        <div class="ocu-banner ocu-banner-info ocu-log-hub-notice" data-ocu-hub="notice">
          @for (line of notices; track line) {
            <p class="ocu-log-hub-notice-line">{{ line }}</p>
          }
        </div>
      }

      @if (showEmpty) {
        <section class="ocu-empty-state ocu-data-table-empty" tabindex="-1">
          <p class="ocu-data-table-empty-title" data-ocu-hub="empty">{{ emptyTitle }}</p>
          <p class="ocu-data-table-empty-next">{{ STRINGS.tableReadOnlyEmptyNext }}</p>
        </section>
      }

      @if (showRows) {
        <div class="ocu-log-hub-frame">
          <div class="ocu-log-rows ocu-log-hub-rows" role="list" data-ocu-hub="timeline">
            @for (entry of timelineRows; track entry.key) {
              <div
                class="ocu-log-row ocu-log-hub-row"
                role="listitem"
                [class.ocu-log-hub-row-explain]="explainShown"
                [attr.data-ocu-source]="entry.row.source"
              >
                <span class="ocu-log-cell ocu-log-cell-time">
                  <a class="ocu-data-table-link" data-ocu-hub="open" [href]="entry.href" (click)="onOpenEntry($event, entry)">{{
                    entry.row.time
                  }}</a>
                </span>
                <span class="ocu-log-cell ocu-log-hub-source" data-ocu-hub="source">{{ entry.sourceLabel }}</span>
                <span class="ocu-log-cell ocu-log-cell-severity">
                  @if (entry.hasSeverity) {
                    <span class="ocu-log-chip ocu-log-chip-static" [attr.data-ocu-chip]="entry.chip">{{ entry.severityWord }}</span>
                  }
                </span>
                <span class="ocu-log-cell ocu-log-cell-text" data-ocu-hub="text">{{ entry.row.text }}</span>
                @if (explainShown) {
                  <button
                    type="button"
                    class="ocu-button-text ocu-log-explain"
                    data-ocu-hub="explain"
                    [attr.aria-disabled]="explainAriaDisabled"
                    [attr.aria-describedby]="explainDescribedBy"
                    (click)="onExplainEntry(entry)"
                  >
                    {{ STRINGS.agentExplainEntryAction }}
                  </button>
                }
              </div>
            }
          </div>
        </div>
      }
    </section>
  </section>`,
})
export class LogHubPage {
  private readonly hub = inject(LogHubStore);

  private readonly navigation = inject(NavigationService);

  private readonly router = inject(Router);

  private readonly location = inject(LocationStrategy);

  private readonly refresh = inject(RefreshService);

  private readonly scope = inject(ScopeService);

  private readonly actions = inject(ScreenActions);

  /** The one-shot hand-off to the page an entry opens (Story 11.11). Optional, so a spec that needs none provides none. */
  private readonly arrivals = inject(ScreenArrivals, { optional: true });

  /** The "Explain this entry" hand-off (Story 11.2). Optional, so a spec that needs none provides none. */
  private readonly explainEntry = inject(ExplainEntry, { optional: true });

  protected readonly STRINGS = STRINGS;

  /** The hub's own screen, or `null` when the URL resolves to none. */
  private readonly screen: ScreenDeclaration | null;

  /** The hub's store: the rows on screen, the command bar's text filter, its sort and its cap. */
  private readonly store: ScreenStore | null;

  /** Bumped by the stores, so the page re-renders under `OnPush`. */
  private readonly generation = signal(0);

  /** The Begin field's text, echoed from the bound each read applied. */
  private sinceValue = '';

  /** The criteria the Begin field last echoed, so only a landed read replaces what was typed. */
  private echoed: Readonly<Record<string, string>> | null = null;

  /** The rows `publish` last wrote into the store, so an unchanged set is not re-published. */
  private published: readonly LogHubRow[] | null = null;

  constructor() {
    const screen = this.navigation.screenForUrl(this.router.url);
    this.screen = screen;
    this.store = screen === null ? null : inject(ScreenStores).for(screen.descriptor, screen.refreshRates);
    this.echo();
    const stopHub = this.hub.subscribe(() => {
      this.echo();
      this.publish();
      this.bump();
    });
    const stopStore = this.store?.subscribe(() => this.bump()) ?? null;
    const stopExplain = this.explainEntry?.subscribe(() => this.bump()) ?? null;
    let stopRefresh: (() => void) | null = null;
    let stopDownload: (() => void) | null = null;
    if (screen !== null) {
      this.refresh.bind(screen, this.boundRead(screen));
      stopRefresh = this.actions.register(screen.descriptor, REFRESH_ACTION_ID, () => {
        void this.refresh.readNow();
      });
      stopDownload = this.actions.register(screen.descriptor, DOWNLOAD_CSV_ACTION_ID, () => this.downloadCsv());
      if (this.scope.loaded()) void this.refresh.readNow();
    }
    inject(DestroyRef).onDestroy(() => {
      stopHub();
      stopStore?.();
      stopExplain?.();
      stopRefresh?.();
      stopDownload?.();
      if (screen === null) return;
      if (this.navigation.screenForUrl(this.router.url)?.descriptor === screen.descriptor) return;
      if (this.refresh.descriptor() === screen.descriptor) this.refresh.unbind();
    });
    this.publish();
  }

  /**
   * The read the refresh framework calls: the hub store's read at the store's cap, with the bound
   * the person last searched, answering the rows the Source and Severity filters leave.
   */
  private boundRead(screen: ScreenDeclaration): RefreshRead {
    return async ({ maxRows }) => {
      const since = this.hub.searchedSince();
      const fault = await this.hub.read(screen, maxRows, since === null ? undefined : since);
      if (fault !== null) return { kind: 'fault', fault };
      return { kind: 'ok', rows: this.filtered(), truncated: this.hub.truncated() };
    };
  }

  /** The rows the Source and Severity filters leave, in the read's order. */
  private filtered(): readonly LogHubRow[] {
    const source = this.hub.sourceFilter();
    const severity = this.hub.severityFilter();
    return this.hub.rows().filter(
      (row) => (source === '' || row.source === source) && (severity === '' || severityChipKey(row.severity) === severity)
    );
  }

  /** The rows on screen: the filtered rows through the store's own text filter and sort (AD-36's view rule). */
  private visible(): readonly LogHubRow[] {
    const read = this.screen?.read ?? null;
    const store = this.store;
    const rows = this.filtered();
    if (read === null || store === null) return rows;
    return applyView(rows, read, { filter: store.filter(), sort: store.sort(), direction: store.direction() }) as readonly LogHubRow[];
  }

  /** Publish the filtered rows into the hub's store, which is what the screen context and Download CSV read (AD-24). */
  private publish(): void {
    if (this.store === null || !this.hub.loaded()) return;
    const rows = this.filtered();
    if (this.published !== null && rows.length === this.published.length && rows.every((row, index) => row === this.published?.[index])) return;
    this.published = rows;
    this.store.applyTick(rows, this.hub.truncated(), '', new Date());
  }

  /** Put the bound a landed read applied into the Begin field (the fresh default among them). */
  private echo(): void {
    const criteria = this.hub.criteria();
    if (criteria === this.echoed || !this.hub.loaded()) return;
    this.echoed = criteria;
    this.sinceValue = criteria['since'] ?? '';
  }

  private bump(): void {
    this.generation.update((value) => value + 1);
  }

  /** The label a source's route names, from its own screen's declaration. */
  private labelFor(route: string): string {
    const screen = screenForRoute(route);
    return screen === null ? route : stringFor(screen.labelKey);
  }

  private hrefFor(url: string): string {
    return this.location.prepareExternalUrl(url);
  }

  /** The URL an entry opens at: its source's id route where the source is keyed, its bare route otherwise. */
  private entryUrl(row: LogHubRow): string {
    const target = screenForRoute(row.source);
    const keyed = target !== null && (target.archetype === 'list (server criteria)' || target.archetype === 'drill-down');
    return keyed && row.id !== '' ? entityUrl(row.source, row.id, '', this.router.url) : withQuery(row.source, this.router.url);
  }

  private entryView(row: LogHubRow, index: number): EntryView {
    return {
      key: String(index) + '|' + row.source + '|' + row.time,
      row,
      href: this.hrefFor(this.entryUrl(row)),
      sourceLabel: this.labelFor(row.source),
      chip: severityChipKey(row.severity),
      severityWord: severityWord(row.severity),
      hasSeverity: row.severity !== '',
    };
  }

  protected get sourceRows(): readonly SourceView[] {
    this.generation();
    const counts = new Map<string, number>();
    for (const row of this.visible()) counts.set(row.source, (counts.get(row.source) ?? 0) + 1);
    const refused = this.explainEntry?.reason() ?? null;
    return this.hub.sources().map((source, index) => {
      const reasonId = REASON_PREFIX + index;
      const noEntryId = NO_ENTRY_PREFIX + index;
      const reason = source.shown ? '' : formatRequires(STRINGS.privilegeRequiresResource, source.requires);
      const last = source.shown && source.last !== null ? this.entryView(source.last, index) : null;
      let explainDescribedBy: string | null = null;
      if (!source.shown) explainDescribedBy = reasonId;
      else if (last === null) explainDescribedBy = noEntryId;
      else if (refused !== null) explainDescribedBy = this.explainEntry?.describedBy() ?? null;
      return {
        route: source.source,
        label: this.labelFor(source.source),
        href: this.hrefFor(withQuery(source.source, this.router.url)),
        shown: source.shown,
        reason,
        reasonId,
        count: counts.get(source.source) ?? 0,
        truncated: source.truncated,
        last,
        noEntryId,
        explainDisabled: explainDescribedBy === null ? null : 'true',
        explainDescribedBy,
      };
    });
  }

  protected get timelineRows(): readonly EntryView[] {
    this.generation();
    return this.visible().map((row, index) => this.entryView(row, index));
  }

  /** One line per source left out, naming the privilege it needs. */
  protected get notices(): readonly string[] {
    this.generation();
    return this.hub
      .sources()
      .filter((source) => !source.shown)
      .map((source) =>
        formatRequires(STRINGS.logHubNotShown.split(SOURCE_PLACEHOLDER).join(this.labelFor(source.source)), source.requires)
      );
  }

  protected get showNotice(): boolean {
    return this.notices.length > 0;
  }

  protected get sourceOptions(): readonly OptionView[] {
    this.generation();
    const chosen = this.hub.sourceFilter();
    return this.hub
      .sources()
      .filter((source) => source.shown)
      .map((source) => ({ value: source.source, text: this.labelFor(source.source), selected: source.source === chosen }));
  }

  protected get severityOptions(): readonly OptionView[] {
    this.generation();
    const chosen = this.hub.severityFilter();
    return SEVERITY_CHIPS.map((chip) => ({ value: chip.key, text: chip.word, selected: chip.key === chosen }));
  }

  protected get sourceAny(): boolean {
    this.generation();
    return this.hub.sourceFilter() === '';
  }

  protected get severityAny(): boolean {
    this.generation();
    return this.hub.severityFilter() === '';
  }

  protected get since(): string {
    this.generation();
    return this.sinceValue;
  }

  /** Whether any of the three filters narrows the timeline, which is the only thing Clear clears. */
  protected get showClear(): boolean {
    this.generation();
    return this.hub.sourceFilter() !== '' || this.hub.severityFilter() !== '' || (this.store?.filter() ?? '') !== '';
  }

  protected get showRows(): boolean {
    this.generation();
    return this.hub.loaded() && this.timelineRows.length > 0;
  }

  protected get showEmpty(): boolean {
    this.generation();
    return this.hub.loaded() && this.hub.fault() === null && this.timelineRows.length === 0;
  }

  /** "No matches." when a filter left nothing, "No entries." when the window itself held none. */
  protected get emptyTitle(): string {
    this.generation();
    return this.hub.rows().length > 0 ? STRINGS.logViewerNoMatches : STRINGS.logViewerEmpty;
  }

  protected get showRefusal(): boolean {
    this.generation();
    const fault = this.hub.fault();
    return fault !== null && !isBannerFault(fault);
  }

  protected get refusalMessage(): string {
    this.generation();
    const pair = this.hub.failedPair();
    if (this.hub.fault()?.code === 'AUTH.NOPRIVILEGE' && pair !== '') {
      return formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.errorLogRefusedAction);
    }
    return STRINGS.connectivityRequestRefused;
  }

  /** Whether entries carry "Explain this entry": the agent answered with an enabled definition. */
  protected get explainShown(): boolean {
    this.generation();
    return this.explainEntry !== null && this.explainEntry.shown();
  }

  protected get explainAriaDisabled(): 'true' | null {
    this.generation();
    const entry = this.explainEntry;
    return entry === null || entry.reason() === null ? null : 'true';
  }

  protected get explainDescribedBy(): string | null {
    this.generation();
    return this.explainEntry?.describedBy() ?? null;
  }

  protected onSince(event: Event): void {
    const target = event.target;
    this.sinceValue = target instanceof HTMLInputElement ? target.value : '';
  }

  /** Search: read with the Begin field as shown, an emptied field being an unset bound. */
  protected onSearch(event: Event): void {
    event.preventDefault();
    const screen = this.screen;
    if (screen === null) return;
    this.hub.setSearchedSince(this.sinceValue);
    this.refresh.bind(screen, this.boundRead(screen));
    void this.refresh.readNow();
  }

  protected onSourceFilter(event: Event): void {
    const target = event.target;
    this.hub.setSourceFilter(target instanceof HTMLSelectElement ? target.value : '');
  }

  protected onSeverityFilter(event: Event): void {
    const target = event.target;
    this.hub.setSeverityFilter(target instanceof HTMLSelectElement ? target.value : '');
  }

  /**
   * Clear all three filters. Focus goes to the Source filter, which stays in the DOM, since this
   * control removes itself on its own click (EXPERIENCE.md Accessibility Floor, Focus destinations).
   */
  protected onClear(): void {
    this.hub.setSourceFilter('');
    this.hub.setSeverityFilter('');
    this.store?.setFilter('');
    document.getElementById('ocu-log-hub-source')?.focus();
  }

  /** Open a shown source at its bare route; a modified click is the browser's (a new tab, say). */
  protected onOpenSource(event: MouseEvent, source: SourceView): void {
    if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    void this.router.navigateByUrl(withQuery(source.route, this.router.url));
  }

  /**
   * Open an entry's source at that entry: a log viewer through a one-shot arrival carrying the
   * entry, the audit viewer on the entry's id route with criteria bracketing its second, and a
   * keyed source on its id route. A modified click is the browser's, and hands nothing off.
   */
  protected onOpenEntry(event: MouseEvent, entry: EntryView): void {
    if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    const row = entry.row;
    const target = screenForRoute(row.source);
    if (target !== null && target.archetype === 'log-viewer') {
      this.arrivals?.set({ route: row.source, criterion: '', criteria: {}, entry: { time: row.time, text: row.text } });
    } else if (target !== null && target.archetype === 'list (server criteria)') {
      const begin = row.time.slice(0, 19).replace('T', ' ');
      this.arrivals?.set({ route: row.source, criterion: '', criteria: { beginDateTime: begin, endDateTime: nextSecond(begin) } });
    }
    void this.router.navigateByUrl(this.entryUrl(row));
  }

  /** Hand this entry to the panel, which marks it among the timeline's rows; a refused control sends nothing. */
  protected onExplainEntry(entry: EntryView): void {
    if (this.screen === null) return;
    this.explainEntry?.request(this.screen, entry.row);
  }

  /** Hand a source's last entry to the panel, which marks it; a source not shown, or with none, sends nothing. */
  protected onExplainSource(source: SourceView): void {
    if (this.screen === null || source.explainDisabled !== null || source.last === null) return;
    this.explainEntry?.request(this.screen, source.last.row);
  }

  /**
   * Save the timeline as it stands -- all three filters and the sort applied, each cell as
   * displayed -- as a CSV file built here, as the data table's own Download CSV does (Story 16.23).
   */
  private downloadCsv(): void {
    const header = [STRINGS.auditColumnTime, STRINGS.auditEventFieldSource, STRINGS.logViewerColumnSeverity, STRINGS.logViewerColumnMessage];
    const rows = this.visible().map((row) => [row.time, this.labelFor(row.source), row.severity === '' ? '' : severityWord(row.severity), row.text]);
    saveCsv(document, csvText(header, rows), csvFileName(STRINGS.logHubLabel, new Date()));
  }
}
