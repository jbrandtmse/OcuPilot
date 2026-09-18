import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { NavigationService } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { LogViewerPage } from './log-viewer.page';
import { LogViewerStore } from './log-viewer.store';

/** The screen this page renders, resolved from the mirror as the shell's outlet resolves it. */
const ALERTS_SCREEN = SCREENS.find((screen) => screen.route === 'logs/alerts')!;

const TAIL_PATH = '/api/ocupilot/logs/alerts';

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

  /** Queue one answer per tail request, in order; the last one repeats. */
  tail(...bodies: unknown[]): void {
    this.tailBodies = bodies;
  }

  refuseTail(status: number, code: string | null, detail: Record<string, unknown> | null = null): void {
    this.tailRefusal = { status, code, detail };
  }

  async requestJson<T>(path: string): Promise<JsonResult<T>> {
    this.paths.push(path);
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
  async function mount(): Promise<{ fixture: ComponentFixture<LogViewerPage>; store: LogViewerStore }> {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([{ path: 'logs/alerts', children: [] }, { path: '**', children: [] }]),
        { provide: ApiService, useValue: api as unknown as ApiService },
        {
          provide: NavigationService,
          useValue: { screenForUrl: () => ALERTS_SCREEN } as unknown as NavigationService,
        },
        { provide: ScreenActions, useValue: new ScreenActions() },
      ],
    });
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
});
