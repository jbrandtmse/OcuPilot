import { ApplicationRef } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { BUSY_REASON_ID, CONTEXT_CHIP_OFF_ID, ExplainEntry, KILL_SWITCH_ID } from '../../core/explain-entry';
import { NavigationService } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenArrivals } from '../../core/screen-arrival';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { stubExplainEntry, type ExplainEntryState } from '../../testing/explain-entry';
import { fileOptionText } from './log-line';
import { LogViewerPage } from './log-viewer.page';
import { LogViewerStore } from './log-viewer.store';

/** The screens this page renders, resolved from the mirror as the shell's outlet resolves it. */
const ALERTS_SCREEN = SCREENS.find((screen) => screen.route === 'logs/alerts')!;
const MESSAGES_SCREEN = SCREENS.find((screen) => screen.route === 'logs/messages')!;
const XDBC_SCREEN = SCREENS.find((screen) => screen.route === 'logs/xdbc')!;
const XDBC_PATH = '/api/ocupilot/logs/xdbc';

/** `GET /logs/xdbc`'s answer (Story 16.8): the newest entries first, already normalized. */
function entriesPage(texts: readonly string[], truncated = false) {
  const entries = texts.map((text, index) => {
    const time = `2026-09-27T10:0${texts.length - index}:00.000`;
    return { time, pid: String(100 + index), severity: '2', text: `[HSCUSTOM] ${text}`, raw: `${time} (${100 + index}) 2 [HSCUSTOM] ${text}` };
  });
  return { source: 'xdbc', entries, truncated };
}

const TAIL_PATH = '/api/ocupilot/logs/alerts';
const MESSAGES_TAIL_PATH = '/api/ocupilot/logs/messages';
const FILES_PATH = '/api/ocupilot/logs/messages/files';

/** `GET /logs/messages/files`' answer: messages.log first, then the rotated files newest first. */
const FILES = [
  { name: 'messages.log', size: 1637621, modified: '2026-09-27T03:10:48Z' },
  { name: 'messages.old_20260926_5', size: 2982895, modified: '2026-09-26T21:18:14Z' },
  { name: 'messages.old_20260926_4', size: 2048, modified: '2026-09-26T09:00:00Z' },
];

const FILE_LINES = [
  '09/18/26-07:33:42:173 (423284) 2 [OcuPilot.Log] [OcuPilot] a severe entry',
  '09/18/26-07:33:56:057 (892) 0 [Utility.Event] an informational entry',
];

/**
 * The alerts.log viewer over a stubbed API (Story 6.13 AC4, AC5, AC6, AC7).
 *
 * The geometry is `alerts-log.browser-spec.mjs`'s -- jsdom computes no layout, so a 28px assertion
 * here would pass against a row of any height. What belongs here is everything that is not
 * geometry: the rows on screen, the paging cursor, the absence of any timer, and the controls' own
 * behaviour.
 *
 * Mutations (Rule 19), each applied and observed red here alone: add a `setInterval` re-read to the
 * store -> the zero-requests-after-ten-minutes assertion goes red; drop the severity word from the
 * chip -> the chip-text assertion goes red; send the tail request without `identity` -> the Load
 * newer cursor assertion goes red.
 */
class StubApi {
  readonly paths: string[] = [];

  private tailBodies: unknown[] = [];

  private tailRefusal: { status: number; code: string | null; detail: Record<string, unknown> | null } | null = null;

  private filesBody: unknown = { source: 'messages', files: FILES, truncated: false };

  private filesRefused = false;

  /** Answer the file list with `files`. */
  listFiles(files: unknown[]): void {
    this.filesBody = { source: 'messages', files, truncated: false };
  }

  refuseFiles(): void {
    this.filesRefused = true;
  }

  /** Queue one answer per tail request, in order; the last one repeats. */
  tail(...bodies: unknown[]): void {
    this.tailBodies = bodies;
  }

  refuseTail(status: number, code: string | null, detail: Record<string, unknown> | null = null): void {
    this.tailRefusal = { status, code, detail };
  }

  async requestJson<T>(path: string): Promise<JsonResult<T>> {
    this.paths.push(path);
    if (path === FILES_PATH) {
      if (this.filesRefused) return { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: null, detail: null };
      return { kind: 'ok', status: 200, body: this.filesBody as T };
    }
    if (this.tailRefusal !== null) {
      return {
        kind: 'error',
        status: this.tailRefusal.status,
        code: this.tailRefusal.code,
        reason: null,
        detail: this.tailRefusal.detail,
      };
    }
    const body = this.tailBodies.length > 1 ? this.tailBodies.shift() : this.tailBodies[0];
    return { kind: 'ok', status: 200, body: (body ?? { lines: [] }) as T };
  }
}

function tailPage(lines: readonly string[], offset = 400, identity = 'first-line', extra: Record<string, unknown> = {}) {
  return { source: 'alerts', lines, offset, identity, size: offset - 1, restarted: false, truncated: false, ...extra };
}

describe('LogViewerPage', () => {
  let api: StubApi;

  beforeEach(() => {
    api = new StubApi();
    api.tail(tailPage(FILE_LINES));
  });

  afterEach(() => {
    TestBed.inject(LogViewerStore).reset();
    TestBed.resetTestingModule();
  });

  /**
   * Mount the page and let the read its constructor issues settle, so the test asserts against the
   * screen as it opens rather than against a second read of its own.
   */
  async function mount(
    screen = ALERTS_SCREEN,
    address = '',
    arrivals: ScreenArrivals | null = null
  ): Promise<{ fixture: ComponentFixture<LogViewerPage>; store: LogViewerStore }> {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([{ path: screen.route, children: [] }, { path: '**', children: [] }]),
        { provide: ApiService, useValue: api as unknown as ApiService },
        {
          provide: NavigationService,
          useValue: { screenForUrl: () => screen } as unknown as NavigationService,
        },
        { provide: ScreenActions, useValue: new ScreenActions() },
        { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
        ...(arrivals === null ? [] : [{ provide: ScreenArrivals, useValue: arrivals }]),
      ],
    });
    if (address !== '') await TestBed.inject(Router).navigateByUrl(address);
    const fixture = TestBed.createComponent(LogViewerPage);
    fixture.detectChanges();
    await settle();
    fixture.detectChanges();
    return { fixture, store: TestBed.inject(LogViewerStore) };
  }

  /** Let the read's promise resolve; the store issues no timer, so a few microtask turns is all. */
  async function settle(): Promise<void> {
    for (let turn = 0; turn < 8; turn += 1) await Promise.resolve();
  }

  function rows(fixture: ComponentFixture<LogViewerPage>): string[][] {
    return Array.from(fixture.nativeElement.querySelectorAll('.ocu-log-row')).map((row) =>
      Array.from((row as HTMLElement).querySelectorAll('.ocu-log-cell')).map((cell) =>
        ((cell as HTMLElement).textContent ?? '').trim()
      )
    );
  }

  function textOf(fixture: ComponentFixture<LogViewerPage>, selector: string): string {
    const node = fixture.nativeElement.querySelector(selector) as HTMLElement | null;
    return node === null ? '' : (node.textContent ?? '').trim();
  }

  it('AC4: each rendered row is the line parsed into time, pid, severity word and text', async () => {
    const { fixture } = await mount();

    const rendered = rows(fixture);
    expect(rendered).toHaveLength(2);
    expect(rendered[0][0]).toBe('2026-09-18T07:33:42.173');
    expect(rendered[0][1]).toBe('423284');
    expect(rendered[0][2]).toBe(STRINGS.logSeveritySevere);
    expect(rendered[0][3]).toBe('[OcuPilot] a severe entry');
    expect(rendered[1][1]).toBe('892');
    expect(rendered[1][2]).toBe(STRINGS.logSeverityInfo);
  });

  it('AC4: a head-less window keeps its bytes on screen under the empty-cell word', async () => {
    api.tail(tailPage(['    a fragment of the line above the window']));
    const { fixture } = await mount();

    const rendered = rows(fixture);
    expect(rendered).toHaveLength(1);
    expect(rendered[0][0]).toBe('');
    expect(rendered[0][1]).toBe(STRINGS.tableEmptyValue);
    expect(rendered[0][2]).toBe(STRINGS.tableEmptyValue);
    expect(rendered[0][3]).toContain('a fragment of the line above the window');
  });

  // Story 16.9, AC8. Mutation (Rule 19): ignore the arrival in the page's constructor -> the mark
  // assertions go red.
  it('Story 16.9: an arrival from the log hub marks the chosen line, current and focusable', async () => {
    const arrivals = new ScreenArrivals();
    arrivals.set({ route: 'logs/alerts', criterion: '', criteria: {}, entry: { time: '2026-09-18T07:33:56.057', text: 'an informational entry' } });
    const { fixture } = await mount(ALERTS_SCREEN, '', arrivals);
    await settle();
    fixture.detectChanges();
    const current = fixture.nativeElement.querySelectorAll('[aria-current="true"]');
    expect(current).toHaveLength(1);
    expect((current[0] as HTMLElement).classList.contains('ocu-log-row-current')).toBe(true);
    expect((current[0] as HTMLElement).getAttribute('tabindex')).toBe('-1');
    expect((current[0] as HTMLElement).textContent).toContain('an informational entry');
    expect(fixture.nativeElement.querySelector('[data-ocu-log="entry-gone"]')).toBeNull();
    expect(arrivals.take('logs/alerts')).toBeNull();
  });

  it('Story 16.9: a text cut at U+2026 still finds its line, and an entry no longer in the window says so', async () => {
    const arrivals = new ScreenArrivals();
    arrivals.set({ route: 'logs/alerts', criterion: '', criteria: {}, entry: { time: '2026-09-18T07:33:42.173', text: '[OcuPilot] a sev\u2026' } });
    const { fixture } = await mount(ALERTS_SCREEN, '', arrivals);
    await settle();
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('[aria-current="true"]')?.textContent).toContain('a severe entry');

    TestBed.resetTestingModule();
    const gone = new ScreenArrivals();
    gone.set({ route: 'logs/alerts', criterion: '', criteria: {}, entry: { time: '2026-09-17T00:00:00.000', text: 'long gone' } });
    const second = await mount(ALERTS_SCREEN, '', gone);
    await settle();
    second.fixture.detectChanges();
    expect(second.fixture.nativeElement.querySelector('[aria-current="true"]')).toBeNull();
    expect(textOf(second.fixture, '[data-ocu-log="entry-gone"]')).toBe(STRINGS.logViewerEntryGone);
  });

  it('AC5: Load newer asks for one page from the held offset and identity', async () => {
    const { fixture, store } = await mount();
    const before = api.paths.length;

    api.tail(tailPage(['09/18/26-07:40:00:000 (1) 1 newer'], 500, 'first-line'));
    await store.loadNewer();
    await settle();
    fixture.detectChanges();

    const paged = api.paths.slice(before).filter((path) => path.startsWith(TAIL_PATH));
    expect(paged).toHaveLength(1);
    expect(paged[0]).toContain('offset=400');
    expect(paged[0]).toContain('identity=first-line');
    expect(rows(fixture).some((cells) => cells[3].includes('newer'))).toBe(true);
  });

  it('AC5: a rotation answers restarted and re-seeds from byte 1 without a fault', async () => {
    const { fixture, store } = await mount();
    expect(rows(fixture)).toHaveLength(2);

    api.tail(tailPage(['09/18/26-08:00:00:000 (1) 1 the new file'], 40, 'second-line', { restarted: true }));
    await store.loadNewer();
    await settle();
    fixture.detectChanges();

    expect(store.restarted()).toBe(true);
    expect(store.fault()).toBeNull();
    const rendered = rows(fixture);
    expect(rendered).toHaveLength(1);
    expect(rendered[0][3]).toContain('the new file');
  });

  it('AC5: no control is offered for the oldest end, and none is requested', async () => {
    const { fixture, store } = await mount();

    expect(fixture.nativeElement.querySelector('[data-ocu-log="load-newer"]')).not.toBeNull();
    expect(fixture.nativeElement.querySelector('[data-ocu-log="load-older"]')).toBeNull();
    const asked = api.paths.filter((path) => path.startsWith(TAIL_PATH));
    expect(asked).toHaveLength(1);
  });

  it('AC6: nothing streams -- ten minutes of fake time issues no request and registers no timer', async () => {
    // The clock is faked and restored here and nowhere else in this file; `vi.getTimerCount()` is
    // what makes "registers no interval" an observation rather than an absence of evidence, and it
    // needs no spy on a global the fake clock has already replaced.
    // jsdom supplies both constructors, so "opens no EventSource and no WebSocket" is counted at
    // construction rather than asserted as their absence -- which would pass on any page.
    const globals = globalThis as { EventSource?: unknown; WebSocket?: unknown };
    const heldSource = globals.EventSource;
    const heldSocket = globals.WebSocket;
    let opened = 0;
    globals.EventSource = function EventSourceProbe() {
      opened += 1;
    };
    globals.WebSocket = function WebSocketProbe() {
      opened += 1;
    };
    vi.useFakeTimers();
    try {
      const { fixture } = await mount();
      const issued = api.paths.length;
      expect(issued).toBeGreaterThan(0);

      await vi.advanceTimersByTimeAsync(10 * 60 * 1000);
      fixture.detectChanges();

      expect(api.paths.length).toBe(issued);
      expect(vi.getTimerCount()).toBe(0);
      expect(opened).toBe(0);
    } finally {
      vi.useRealTimers();
      globals.EventSource = heldSource;
      globals.WebSocket = heldSocket;
    }
  });

  it('a log the instance has not written yet is the empty state, not a refusal', async () => {
    api.refuseTail(404, 'LOG.ABSENT');
    const { fixture, store } = await mount();

    expect(store.fault()).toBeNull();
    expect(rows(fixture)).toHaveLength(0);
    expect(fixture.nativeElement.querySelector('[data-ocu-log="refusal"]')).toBeNull();
    expect(textOf(fixture, '[data-ocu-log="empty"]')).toBe(STRINGS.logViewerEmpty);
    expect(fixture.nativeElement.querySelector('[data-ocu-log="load-newer"]')).toBeNull();
  });

  it('the tail failing is the screen\'s own refusal, naming the pair the envelope named', async () => {
    api.refuseTail(403, 'AUTH.NOPRIVILEGE', { failedPair: '%DB_IRISSYS:READ' });
    const { fixture, store } = await mount();

    expect(rows(fixture)).toHaveLength(0);
    expect(textOf(fixture, '[data-ocu-log="refusal"]')).toContain('%DB_IRISSYS');
  });

  it('AC7: searching highlights the matches and announces a polite count', async () => {
    const { fixture, store } = await mount();

    const search = fixture.nativeElement.querySelector('[data-ocu-log="search"]') as HTMLInputElement;
    expect(search.getAttribute('type')).toBe('search');
    search.value = 'entry';
    search.dispatchEvent(new Event('input'));
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelectorAll('.ocu-log-mark').length).toBeGreaterThan(0);
    const count = fixture.nativeElement.querySelector('[data-ocu-log="count"]') as HTMLElement;
    expect(count.getAttribute('role')).toBe('status');
    expect(count.textContent?.trim()).toBe('1 of 2');

    // Enter moves the caret forward over the matches, Shift+Enter back, both wrapping.
    search.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter' }));
    fixture.detectChanges();
    expect(count.textContent?.trim()).toBe('2 of 2');
    search.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', shiftKey: true }));
    fixture.detectChanges();
    expect(count.textContent?.trim()).toBe('1 of 2');
  });

  it('AC7: the Raw toggle swaps to the bounded monospace block and back', async () => {
    const { fixture, store } = await mount();

    const raw = fixture.nativeElement.querySelector('[data-ocu-log="raw"]') as HTMLButtonElement;
    expect(raw.getAttribute('aria-pressed')).toBe('false');
    raw.click();
    fixture.detectChanges();

    expect(fixture.nativeElement.querySelector('[data-ocu-log="raw-block"]')).not.toBeNull();
    expect(rows(fixture)).toHaveLength(0);
    expect(raw.getAttribute('aria-pressed')).toBe('true');

    raw.click();
    fixture.detectChanges();
    expect(rows(fixture)).toHaveLength(2);
  });

  it('AC7: every chip carries its severity word, and clicking one filters then clears', async () => {
    const { fixture, store } = await mount();

    const words = Array.from(fixture.nativeElement.querySelectorAll('.ocu-log-chip-word')).map((node) =>
      ((node as HTMLElement).textContent ?? '').trim()
    );
    expect(words).toEqual([
      STRINGS.logSeverityDebug,
      STRINGS.logSeverityInfo,
      STRINGS.logSeverityWarning,
      STRINGS.logSeveritySevere,
      STRINGS.logSeverityFatal,
    ]);

    const severe = fixture.nativeElement.querySelector('[data-ocu-chip="severe"]') as HTMLButtonElement;
    severe.click();
    fixture.detectChanges();
    expect(severe.getAttribute('aria-pressed')).toBe('true');
    expect(rows(fixture)).toHaveLength(1);

    severe.click();
    fixture.detectChanges();
    expect(severe.getAttribute('aria-pressed')).toBe('false');
    expect(rows(fixture)).toHaveLength(2);
  });

  it('AC7: every rendered severity carries its word, never colour alone', async () => {
    const { fixture, store } = await mount();

    const chips = Array.from(fixture.nativeElement.querySelectorAll('.ocu-log-chip-static')).map((node) =>
      ((node as HTMLElement).textContent ?? '').trim()
    );
    expect(chips).toEqual([STRINGS.logSeveritySevere, STRINGS.logSeverityInfo]);
  });

  it('distinguishes "No entries." from "No matches."', async () => {
    api.tail(tailPage([]));
    const { fixture, store } = await mount();
    expect(textOf(fixture, '[data-ocu-log="empty"]')).toBe(STRINGS.logViewerEmpty);

    api.tail(tailPage(FILE_LINES));
    await store.open();
    await settle();
    fixture.detectChanges();
    const search = fixture.nativeElement.querySelector('[data-ocu-log="search"]') as HTMLInputElement;
    search.value = 'nothing in this file';
    search.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    // The search highlights rather than filters, so the rows are stood down only when none of them
    // matches -- which is what makes the published "No matches." reachable from the search at all.
    expect(textOf(fixture, '[data-ocu-log="empty"]')).toBe(STRINGS.logViewerNoMatches);
    expect(rows(fixture)).toHaveLength(0);

    const fatal = fixture.nativeElement.querySelector('[data-ocu-chip="fatal"]') as HTMLButtonElement;
    fatal.click();
    fixture.detectChanges();
    expect(textOf(fixture, '[data-ocu-log="empty"]')).toBe(STRINGS.logViewerNoMatches);
  });

  it('Story 6.14 AC1: the messages.log screen reads its own route, and every request is one bounded page', async () => {
    // The route -> source map is the whole of this story's client change, so it is pinned by which
    // path the store asks for rather than by the rows that come back. The exact path equality is
    // what makes "bounded" observable: the cursor is the only thing a page carries, so a request
    // that asked for the file's size would have a query this assertion does not admit.
    const { store } = await mount(MESSAGES_SCREEN);

    api.tail(tailPage(['09/18/26-07:40:00:000 (1) 1 newer'], 500, 'first-line'));
    await store.loadNewer();
    await settle();

    expect(api.paths.filter((path) => path.startsWith(TAIL_PATH))).toHaveLength(0);
    // The file list (Story 16.20) is its own route, not a page of the file.
    const asked = api.paths.filter((path) => path.startsWith(MESSAGES_TAIL_PATH) && path !== FILES_PATH);
    expect(asked).toEqual([MESSAGES_TAIL_PATH, `${MESSAGES_TAIL_PATH}?offset=400&identity=first-line`]);
    for (const path of asked) expect(path).not.toContain('maxBytes');
  });

  it('every built log-viewer screen reads the file its own descriptor declares', async () => {
    // `log-viewer.page.ts`'s `SOURCES` map is a second declaration beside the mirror's own
    // `read.source.endpoint`, and it falls through to `ALERTS_SOURCE` for a route it does not
    // carry -- so a third `log-viewer` descriptor (EXPERIENCE.md's log-viewer row anticipates
    // "P1 secondary logs") added there and forgotten here would render alerts.log under its own
    // title and its own gate. That is DW-148's defect one layer down, and nothing pinned it.
    // Derived from the mirror rather than listed, so the next log screen is covered the day it
    // ships.
    //
    // Mutation (Rule 19): drop the `'logs/messages'` entry from `SOURCES` -> this goes red naming
    // the route that fell through to `/api/ocupilot/logs/alerts` (observed).
    const viewers = SCREENS.filter((screen) => screen.archetype === 'log-viewer' && screen.built);
    expect(viewers.length).toBeGreaterThan(1);

    let firstMount = true;
    for (const screen of viewers) {
      if (!firstMount) {
        TestBed.inject(LogViewerStore).reset();
        TestBed.resetTestingModule();
      }
      firstMount = false;
      api = new StubApi();
      api.tail(tailPage(FILE_LINES));
      const { store } = await mount(screen);

      expect(store.fault()).toBeNull();
      expect(api.paths[0]).toBe(`/api/ocupilot/logs/${screen.read?.source.endpoint ?? ''}`);
    }
  });

  it('Story 6.14 AC3: a rotation on messages.log replaces the rendered rows rather than appending', async () => {
    const { fixture, store } = await mount(MESSAGES_SCREEN);
    expect(rows(fixture)).toHaveLength(2);

    api.tail(tailPage(['09/18/26-08:00:00:000 (1) 1 the new file'], 40, 'second-line', { restarted: true }));
    await store.loadNewer();
    await settle();
    fixture.detectChanges();

    expect(store.restarted()).toBe(true);
    expect(store.fault()).toBeNull();
    expect(rows(fixture)).toHaveLength(1);
    expect(rows(fixture)[0][3]).toContain('the new file');
  });

  it('Story 6.14 AC5: Clear filter appears with the chip filter, restores every row, and goes', async () => {
    // Mutation (Rule 19): leave `chipValue` set in `onClear` -> the restored-row-count and the
    // control-is-gone assertions both go red.
    const { fixture } = await mount(MESSAGES_SCREEN);
    const clear = (): HTMLButtonElement | null =>
      fixture.nativeElement.querySelector('[data-ocu-log="clear"]');

    expect(clear()).toBeNull();
    expect(rows(fixture)).toHaveLength(2);

    const severe = fixture.nativeElement.querySelector('[data-ocu-chip="severe"]') as HTMLButtonElement;
    severe.click();
    fixture.detectChanges();
    expect(rows(fixture)).toHaveLength(1);
    expect(clear()).not.toBeNull();
    expect(clear()?.textContent?.trim()).toBe(STRINGS.logViewerClearFilter);

    clear()?.click();
    fixture.detectChanges();
    expect(rows(fixture)).toHaveLength(2);
    expect(severe.getAttribute('aria-pressed')).toBe('false');
    expect(clear()).toBeNull();
    // Focus destinations (EXPERIENCE.md Accessibility Floor): the control removed itself on its
    // own click, so focus is handed to the chip it cleared rather than falling to the body.
    // Mutation (Rule 19): drop the `focus()` call from `onClear` -> this goes red reading BODY
    // (observed).
    expect(document.activeElement).toBe(severe);
  });

  it('the polite count never announces a position past the total after the chip filter narrows it', async () => {
    const { fixture } = await mount();

    const search = fixture.nativeElement.querySelector('[data-ocu-log="search"]') as HTMLInputElement;
    search.value = 'entry';
    search.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    search.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter' }));
    fixture.detectChanges();
    expect(textOf(fixture, '[data-ocu-log="count"]')).toBe('2 of 2');

    (fixture.nativeElement.querySelector('[data-ocu-chip="severe"]') as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(textOf(fixture, '[data-ocu-log="count"]')).toBe('1 of 1');
  });

  // --- Story 16.20: older messages.log files ---------------------------------------------------

  const ADDRESS = '/logs/messages?ns=HSCUSTOM';
  const OLDER = 'messages.old_20260926_5';

  /** Let a navigation and the read it starts settle. */
  async function settleNavigation(fixture: ComponentFixture<LogViewerPage>): Promise<void> {
    for (let turn = 0; turn < 4; turn += 1) {
      await new Promise((resolve) => setTimeout(resolve, 0));
      await settle();
    }
    fixture.detectChanges();
  }

  function fileChoice(fixture: ComponentFixture<LogViewerPage>): HTMLSelectElement | null {
    return fixture.nativeElement.querySelector('select[data-ocu-log="file"]');
  }

  function choose(fixture: ComponentFixture<LogViewerPage>, value: string): void {
    const select = fileChoice(fixture)!;
    select.value = value;
    select.dispatchEvent(new Event('change'));
  }

  const tailRequests = (): string[] => api.paths.filter((path) => path.startsWith(MESSAGES_TAIL_PATH) && path !== FILES_PATH);

  it('Story 16.20 AC1: the file choice lists messages.log, then the rotated files newest first, each with size and time', async () => {
    const { fixture } = await mount(MESSAGES_SCREEN, ADDRESS);

    const select = fileChoice(fixture);
    expect(select).not.toBeNull();
    expect(select?.classList.contains('ocu-criteria-select')).toBe(true);
    expect(select?.getAttribute('aria-label')).toBe(STRINGS.databaseVolumeColumnFile);
    const options = Array.from(select!.querySelectorAll('option'));
    expect(options.map((option) => option.textContent?.trim())).toEqual(FILES.map((entry) => fileOptionText(entry)));
    expect(options.map((option) => option.value)).toEqual(['', FILES[1].name, FILES[2].name]);
    expect(select?.value).toBe('');
    expect(api.paths.filter((path) => path === FILES_PATH)).toHaveLength(1);
    expect(tailRequests()).toEqual([MESSAGES_TAIL_PATH]);
  });

  // Mutation (Rule 19): drop `file=` from the store's read -> this goes red on the request path.
  it('Story 16.20 AC2: choosing an older file puts it in the address beside ns and reads that file', async () => {
    const { fixture } = await mount(MESSAGES_SCREEN, ADDRESS);
    api.tail(tailPage(['09/26/26-21:00:00:000 (7) 0 [Utility.Event] from the older file'], 90, 'older-line'));

    choose(fixture, OLDER);
    await settleNavigation(fixture);

    const url = TestBed.inject(Router).url;
    expect(url).toContain('ns=HSCUSTOM');
    expect(url).toContain(`file=${OLDER}`);
    expect(tailRequests().at(-1)).toBe(`${MESSAGES_TAIL_PATH}?file=${OLDER}`);
    expect(rows(fixture).map((cells) => cells[3])).toEqual(['from the older file']);
    expect(fileChoice(fixture)?.value).toBe(OLDER);
  });

  it('Story 16.9: choosing another file takes down the sentence that the hub\'s entry has left the window', async () => {
    const arrivals = new ScreenArrivals();
    arrivals.set({ route: 'logs/messages', criterion: '', criteria: {}, entry: { time: '2026-09-17T00:00:00.000', text: 'long gone' } });
    const { fixture } = await mount(MESSAGES_SCREEN, ADDRESS, arrivals);
    await settle();
    fixture.detectChanges();
    expect(textOf(fixture, '[data-ocu-log="entry-gone"]')).toBe(STRINGS.logViewerEntryGone);
    choose(fixture, OLDER);
    await settleNavigation(fixture);
    expect(fixture.nativeElement.querySelector('[data-ocu-log="entry-gone"]')).toBeNull();
  });

  it('Story 16.20 AC2: Load newer on an older file carries its cursor and its name', async () => {
    const { store } = await mount(MESSAGES_SCREEN, `${ADDRESS}&file=${OLDER}`);
    await store.loadNewer();
    await settle();
    expect(tailRequests()).toEqual([`${MESSAGES_TAIL_PATH}?file=${OLDER}`, `${MESSAGES_TAIL_PATH}?offset=400&identity=first-line&file=${OLDER}`]);
  });

  // Mutation (Rule 19): stop the page reading `file` from the address -> this goes red.
  it('Story 16.20 AC2: a shared link opens the named file and the choice shows it', async () => {
    const { fixture, store } = await mount(MESSAGES_SCREEN, `${ADDRESS}&file=${OLDER}`);

    expect(store.file()).toBe(OLDER);
    expect(tailRequests()).toEqual([`${MESSAGES_TAIL_PATH}?file=${OLDER}`]);
    expect(fileChoice(fixture)?.value).toBe(OLDER);
  });

  it('Story 16.20: choosing messages.log takes file out of the address and reads the current file', async () => {
    const { fixture } = await mount(MESSAGES_SCREEN, `${ADDRESS}&file=${OLDER}`);

    choose(fixture, '');
    await settleNavigation(fixture);

    const url = TestBed.inject(Router).url;
    expect(url).toContain('ns=HSCUSTOM');
    expect(url).not.toContain('file=');
    expect(tailRequests().at(-1)).toBe(MESSAGES_TAIL_PATH);
    expect(fileChoice(fixture)?.value).toBe('');
  });

  it('Story 16.20: a named file no longer on disk is the published refusal, listed by its name alone, with no empty state', async () => {
    api.refuseTail(404, 'LOG.ABSENT');
    const gone = 'messages.old_20200101';
    const { fixture, store } = await mount(MESSAGES_SCREEN, `${ADDRESS}&file=${gone}`);

    expect(store.gone()).toBe(true);
    expect(textOf(fixture, '[data-ocu-log="refusal"]')).toBe(STRINGS.logViewerFileGone);
    expect(fixture.nativeElement.querySelector('[data-ocu-log="empty"]')).toBeNull();
    const options = Array.from(fileChoice(fixture)!.querySelectorAll('option'));
    expect(options.at(-1)?.textContent?.trim()).toBe(gone);
    expect(fileChoice(fixture)?.value).toBe(gone);
  });

  // Mutation (Rule 19): stop `read` clearing `gone` -> this goes red on the refusal text.
  it('Story 16.20: a Refresh after a removed file shows what the new read answered, not the stale removal', async () => {
    api.refuseTail(404, 'LOG.ABSENT');
    const { fixture, store } = await mount(MESSAGES_SCREEN, `${ADDRESS}&file=messages.old_20200101`);
    api.refuseTail(403, 'AUTH.NOPRIVILEGE', { failedPair: '%Admin_Operate:USE' });
    await store.open();
    fixture.detectChanges();
    expect(store.gone()).toBe(false);
    expect(textOf(fixture, '[data-ocu-log="refusal"]')).not.toBe(STRINGS.logViewerFileGone);
  });

  it('Story 16.20: messages.log answering LOG.ABSENT keeps today\'s empty state, not the removed-file refusal', async () => {
    api.refuseTail(404, 'LOG.ABSENT');
    const { fixture, store } = await mount(MESSAGES_SCREEN, ADDRESS);
    expect(store.gone()).toBe(false);
    expect(textOf(fixture, '[data-ocu-log="empty"]')).toBe(STRINGS.logViewerEmpty);
  });

  it('Story 16.20: a name the server refuses LOG.FILE is the generic refusal, not the removed-file one', async () => {
    api.refuseTail(400, 'LOG.FILE');
    const { fixture, store } = await mount(MESSAGES_SCREEN, `${ADDRESS}&file=${OLDER}.bak`);
    expect(store.gone()).toBe(false);
    expect(textOf(fixture, '[data-ocu-log="refusal"]')).toBe(STRINGS.connectivityRequestRefused);
    expect(fixture.nativeElement.querySelector('[data-ocu-log="empty"]')).toBeNull();
  });

  it('Story 16.20: a refused list renders no choice, and the rows are as today', async () => {
    api.refuseFiles();
    const { fixture } = await mount(MESSAGES_SCREEN, ADDRESS);
    expect(fileChoice(fixture)).toBeNull();
    expect(rows(fixture)).toHaveLength(2);
    expect(fixture.nativeElement.querySelector('[data-ocu-log="refusal"]')).toBeNull();
  });

  // Mutation (Rule 19): give ALERTS_SOURCE a `filesPath` -> this goes red.
  it('Story 16.20: alerts.log renders no file choice, asks for no list, and sends no file', async () => {
    const { fixture } = await mount(ALERTS_SCREEN, `/logs/alerts?ns=HSCUSTOM&file=${OLDER}`);
    expect(fileChoice(fixture)).toBeNull();
    expect(api.paths.filter((path) => path.includes('/files'))).toHaveLength(0);
    expect(api.paths).toEqual([TAIL_PATH]);
  });

  // Mutation (Rule 19): drop `publishRows` from the page -> this goes red on the published rows.
  it('Story 16.20: the lines on screen are published into the screen store, newest first, and replaced by the next file', async () => {
    const { fixture } = await mount(MESSAGES_SCREEN, ADDRESS);
    const published = () => TestBed.inject(ScreenStores).for(MESSAGES_SCREEN.descriptor, []).data();

    expect(published()).toEqual([
      { time: '2026-09-18T07:33:56.057', severity: '0', text: 'an informational entry' },
      { time: '2026-09-18T07:33:42.173', severity: '2', text: '[OcuPilot] a severe entry' },
    ]);

    api.tail(tailPage(['09/26/26-21:00:00:000 (7) 1 [Utility.Event] from the older file'], 90, 'older-line'));
    choose(fixture, OLDER);
    await settleNavigation(fixture);
    expect(published()).toEqual([{ time: '2026-09-26T21:00:00.000', severity: '1', text: 'from the older file' }]);
  });

  // Mutation (Rule 19): append Load newer's page in place, keeping the array -> this goes red.
  it('Story 16.20: Load newer publishes the appended lines too, newest first', async () => {
    const { store } = await mount(MESSAGES_SCREEN, ADDRESS);
    api.tail(tailPage(['09/18/26-07:40:00:000 (1) 1 [Utility.Event] newer'], 500, 'first-line'));
    await store.loadNewer();
    await settle();
    const published = TestBed.inject(ScreenStores).for(MESSAGES_SCREEN.descriptor, []).data();
    expect(published.map((row) => (row as { text: string }).text)).toEqual(['newer', 'an informational entry', '[OcuPilot] a severe entry']);
  });

  // Mutation (Rule 19): publish only when the source lists files -> this goes red.
  it('Story 16.20: alerts.log publishes its lines into its own screen store too', async () => {
    await mount(ALERTS_SCREEN, '/logs/alerts?ns=HSCUSTOM');
    const published = TestBed.inject(ScreenStores).for(ALERTS_SCREEN.descriptor, []).data();
    expect(published).toEqual([
      { time: '2026-09-18T07:33:56.057', severity: '0', text: 'an informational entry' },
      { time: '2026-09-18T07:33:42.173', severity: '2', text: '[OcuPilot] a severe entry' },
    ]);
  });

  it('Story 16.20: Refresh re-reads the list and the window', async () => {
    const { fixture } = await mount(MESSAGES_SCREEN, ADDRESS);
    const before = api.paths.length;
    const actions = TestBed.inject(ScreenActions);
    actions.run(MESSAGES_SCREEN.descriptor, 'refresh');
    await settle();
    fixture.detectChanges();
    expect(api.paths.slice(before).sort()).toEqual([FILES_PATH, MESSAGES_TAIL_PATH].sort());
  });
});

// --- Story 11.2: "Explain this entry" on each parsed row -----------------------------------------

describe('LogViewerPage: Explain this entry', () => {
  afterEach(() => {
    TestBed.inject(LogViewerStore).reset();
    TestBed.resetTestingModule();
  });

  async function mountWith(screen: typeof ALERTS_SCREEN, gate: Partial<ExplainEntryState> = {}) {
    const api = new StubApi();
    api.tail(tailPage(FILE_LINES));
    const stub = stubExplainEntry(gate);
    TestBed.configureTestingModule({
      providers: [
        provideRouter([{ path: screen.route, children: [] }, { path: '**', children: [] }]),
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: NavigationService, useValue: { screenForUrl: () => screen } as unknown as NavigationService },
        { provide: ScreenActions, useValue: new ScreenActions() },
        { provide: ExplainEntry, useValue: stub.entry },
        { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
      ],
    });
    const fixture = TestBed.createComponent(LogViewerPage);
    fixture.detectChanges();
    for (let turn = 0; turn < 8; turn += 1) await Promise.resolve();
    fixture.detectChanges();
    return { fixture, ...stub };
  }

  const explainButtons = (fixture: ComponentFixture<LogViewerPage>): HTMLButtonElement[] =>
    Array.from(fixture.nativeElement.querySelectorAll('[data-ocu-log="explain"]'));

  // Mutation (Rule 19): request `line.raw` instead of `row.entry` -> this goes red on the row.
  it('messages.log: each row carries the control, and a click hands that row alone to the panel', async () => {
    const { fixture, entry } = await mountWith(MESSAGES_SCREEN);
    const buttons = explainButtons(fixture);
    expect(buttons).toHaveLength(2);
    expect(buttons[1].textContent?.trim()).toBe(STRINGS.agentExplainEntryAction);
    expect(buttons[1].getAttribute('aria-disabled')).toBeNull();
    expect(fixture.nativeElement.querySelector('.ocu-log-row')?.classList.contains('ocu-log-row-explain')).toBe(true);

    buttons[1].click();
    const taken = entry.take();
    expect(taken?.screen.route).toBe('logs/messages');
    expect(taken?.row).toEqual({ time: '2026-09-18T07:33:56.057', severity: '0', text: 'an informational entry' });
  });

  it('alerts.log: the same control, sent as the alerts screen', async () => {
    const { fixture, entry } = await mountWith(ALERTS_SCREEN);
    explainButtons(fixture)[0].click();
    expect(entry.take()?.screen.route).toBe('logs/alerts');
  });

  it('Raw view: no entry control, since the file block is not rows', async () => {
    const { fixture } = await mountWith(MESSAGES_SCREEN);
    (fixture.nativeElement.querySelector('[data-ocu-log="raw"]') as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('[data-ocu-log="raw-block"]')).not.toBeNull();
    expect(explainButtons(fixture)).toHaveLength(0);
  });

  it('Unconfigured: no enabled definition, no control and no fifth track', async () => {
    const { fixture } = await mountWith(MESSAGES_SCREEN, { configured: false });
    expect(explainButtons(fixture)).toHaveLength(0);
    expect(fixture.nativeElement.querySelector('.ocu-log-row-explain')).toBeNull();
  });

  // Mutation (Rule 19): drop the sharing-off arm from `ExplainEntry.reason()` -> the sharing-off leg goes red.
  it('Blocked: kill switch, busy and sharing off each refuse, described by their reason, and a click records nothing', async () => {
    const cases: [Partial<ExplainEntryState>, string][] = [
      [{ killSwitch: true }, KILL_SWITCH_ID],
      [{ busy: true }, BUSY_REASON_ID],
      [{ share: false }, CONTEXT_CHIP_OFF_ID],
    ];
    for (const [gate, reasonId] of cases) {
      const { fixture, entry } = await mountWith(MESSAGES_SCREEN, gate);
      const button = explainButtons(fixture)[0];
      expect(button.getAttribute('aria-disabled'), JSON.stringify(gate)).toBe('true');
      expect(button.getAttribute('aria-describedby'), JSON.stringify(gate)).toBe(reasonId);
      button.click();
      expect(entry.take(), JSON.stringify(gate)).toBeNull();
      TestBed.inject(LogViewerStore).reset();
      TestBed.resetTestingModule();
    }
  });

  it('a gate that changes re-renders the control', async () => {
    const { fixture, state, fire } = await mountWith(MESSAGES_SCREEN);
    state.busy = true;
    fire();
    fixture.detectChanges();
    expect(explainButtons(fixture)[0].getAttribute('aria-disabled')).toBe('true');
  });
});

describe('LogViewerPage over an entries source (Story 16.8)', () => {
  let api: StubApi;

  beforeEach(() => {
    api = new StubApi();
    api.tail(entriesPage(['newest match', 'middle match', 'oldest match']));
  });

  afterEach(() => {
    TestBed.inject(LogViewerStore).reset();
    TestBed.resetTestingModule();
  });

  async function settle(): Promise<void> {
    for (let turn = 0; turn < 8; turn += 1) await Promise.resolve();
  }

  async function mount(): Promise<{ fixture: ComponentFixture<LogViewerPage>; store: LogViewerStore }> {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([{ path: XDBC_SCREEN.route, children: [] }, { path: '**', children: [] }]),
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: NavigationService, useValue: { screenForUrl: () => XDBC_SCREEN } as unknown as NavigationService },
        { provide: ScreenActions, useValue: new ScreenActions() },
        { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
      ],
    });
    const fixture = TestBed.createComponent(LogViewerPage);
    fixture.detectChanges();
    await settle();
    fixture.detectChanges();
    return { fixture, store: TestBed.inject(LogViewerStore) };
  }

  function cells(fixture: ComponentFixture<LogViewerPage>): string[][] {
    return Array.from(fixture.nativeElement.querySelectorAll('.ocu-log-row')).map((row) =>
      Array.from((row as HTMLElement).querySelectorAll('.ocu-log-cell')).map((cell) => ((cell as HTMLElement).textContent ?? '').trim())
    );
  }

  function count(fixture: ComponentFixture<LogViewerPage>): string {
    return ((fixture.nativeElement.querySelector('[data-ocu-log="count"]') as HTMLElement).textContent ?? '').trim();
  }

  // Mutation (Rule 19): send `offset` and `identity` on an entries source's read -> the bare-path
  // assertion goes red.
  it('reads a bare GET with no query and renders the entries oldest first, with no file choice', async () => {
    const { fixture } = await mount();
    expect(api.paths).toEqual([XDBC_PATH]);
    const rendered = cells(fixture);
    expect(rendered.map((row) => row[3])).toEqual(['[HSCUSTOM] oldest match', '[HSCUSTOM] middle match', '[HSCUSTOM] newest match']);
    expect(rendered[0][0]).toBe('2026-09-27T10:01:00.000');
    expect(rendered[0][1]).toBe('102');
    expect(rendered[0][2]).toBe(STRINGS.logSeveritySevere);
    expect(fixture.nativeElement.querySelector('[data-ocu-log="file"]')).toBeNull();

    (fixture.nativeElement.querySelector('[data-ocu-log="raw"]') as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(textOfNode(fixture, '[data-ocu-log="raw-block"]')).toContain('2026-09-27T10:01:00.000 (102) 2 [HSCUSTOM] oldest match');
  });

  it('Load newer reads the newest window again and replaces the rows', async () => {
    const { fixture, store } = await mount();
    expect(fixture.nativeElement.querySelector('[data-ocu-log="load-newer"]')).not.toBeNull();
    api.tail(entriesPage(['arrived later', 'newest match', 'middle match', 'oldest match']));
    await store.loadNewer();
    await settle();
    fixture.detectChanges();
    expect(api.paths).toEqual([XDBC_PATH, XDBC_PATH]);
    expect(cells(fixture).map((row) => row[3]).at(-1)).toBe('[HSCUSTOM] arrived later');
    expect(cells(fixture)).toHaveLength(4);
  });

  // Mutation (Rule 19): delete the `afterNextRender(() => this.onBottom())` line from
  // `LogViewerPage.onLoadNewer` -> the viewport is never scrolled and this goes red.
  it('the Load newer button jumps to the bottom once the newest window has rendered', async () => {
    const { fixture } = await mount();
    const viewport = fixture.nativeElement.querySelector('[data-ocu-log="viewport"]') as HTMLElement;
    const scrollTo = vi.fn();
    viewport.scrollTo = scrollTo as unknown as HTMLElement['scrollTo'];
    api.tail(entriesPage(['arrived later', 'newest match', 'middle match', 'oldest match']));
    (fixture.nativeElement.querySelector('[data-ocu-log="load-newer"]') as HTMLButtonElement).click();
    await settle();
    fixture.detectChanges();
    TestBed.inject(ApplicationRef).tick();
    expect(scrollTo).toHaveBeenCalledWith({ top: viewport.scrollHeight });
    expect(cells(fixture).map((row) => row[3]).at(-1)).toBe('[HSCUSTOM] arrived later');
  });

  it('publishes the entries on screen as the declared rows, newest first', async () => {
    await mount();
    const published = TestBed.inject(ScreenStores).for(XDBC_SCREEN.descriptor, []).data();
    expect(published[0]).toEqual({ time: '2026-09-27T10:03:00.000', severity: '2', text: '[HSCUSTOM] newest match' });
    expect(published).toHaveLength(3);
  });

  // Mutation (Rule 19): drop the entries branch's `truncatedValue = flagAt(...)` from
  // `LogViewerStore.read` -> the published flag stays false and this goes red.
  it('publishes whether the server cut the window, so the agent is not told a capped window is whole', async () => {
    api.tail(entriesPage(['newest match', 'middle match', 'oldest match'], true));
    await mount();
    expect(TestBed.inject(ScreenStores).for(XDBC_SCREEN.descriptor, []).truncated()).toBe(true);
  });

  // Mutation (Rule 19): make Next match call `step(-1)` -> the forward sequence goes red.
  it('DW-1102: Next match and Previous match carry their names and move the caret, wrapping', async () => {
    const { fixture } = await mount();
    const next = fixture.nativeElement.querySelector('[data-ocu-log="next"]') as HTMLButtonElement;
    const previous = fixture.nativeElement.querySelector('[data-ocu-log="previous"]') as HTMLButtonElement;
    expect(next.textContent?.trim()).toBe(STRINGS.logViewerNextMatch);
    expect(previous.textContent?.trim()).toBe(STRINGS.logViewerPreviousMatch);
    expect(next.getAttribute('type')).toBe('button');

    const search = fixture.nativeElement.querySelector('[data-ocu-log="search"]') as HTMLInputElement;
    search.value = 'match';
    search.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    expect(count(fixture)).toBe('1 of 3');
    const seen: string[] = [];
    for (let press = 0; press < 3; press += 1) {
      next.click();
      fixture.detectChanges();
      seen.push(count(fixture));
    }
    expect(seen).toEqual(['2 of 3', '3 of 3', '1 of 3']);
    previous.click();
    fixture.detectChanges();
    expect(count(fixture)).toBe('3 of 3');
  });
});

function textOfNode(fixture: ComponentFixture<LogViewerPage>, selector: string): string {
  const node = fixture.nativeElement.querySelector(selector) as HTMLElement | null;
  return node === null ? '' : (node.textContent ?? '').trim();
}
