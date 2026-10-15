import { APP_BASE_HREF } from '@angular/common';
import { TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import type { Fault } from '../../core/fault';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { COPY_BUTTON_CLASS } from '../../shell/copy-control';
import { InteropMessageTrace } from './interop-message-trace';
import { arrowName, traceMermaid, traceModel } from './session-trace';

/**
 * The message Trace tab's body (Story 20.30, AD-11, AD-47): each state of the read draws its own block under `data-ocu-trace`; the
 * session is template-bound SVG whose heads, arrows, classes and links follow the rows and whose text is never markup; an arrow
 * follows in the app on a plain click and keeps the browser's default on a modified one; and the Mermaid text is the view switch's
 * other answer, built from the same rows. The read itself is `list-page.spec.ts`'s, so the framework is a stand-in the spec drives
 * and the store is the real one.
 */

const DESCRIPTOR = 'OcuPilot.Screen.Descriptor.InteropMessageTraceTab';

const SCREEN = SCREENS.find((entry) => entry.descriptor === DESCRIPTOR) as ScreenDeclaration;

const TRACE_URL = '/interoperability/messages/trace/11?ns=HSCUSTOM';

/** The framework's answers the block reads, and the read it asks for on Retry. */
class FakeRefresh {
  bound = DESCRIPTOR;
  loaded = false;
  failure: Fault | null = null;
  reads = 0;
  private readonly listeners = new Set<() => void>();

  descriptor(): string {
    return this.bound;
  }

  hasLoaded(): boolean {
    return this.loaded;
  }

  fault(): Fault | null {
    return this.failure;
  }

  async readNow(): Promise<void> {
    this.reads += 1;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  notify(): void {
    for (const listener of [...this.listeners]) listener();
  }
}

/** One row as the Trace tab's read answers it. */
function row(step: number, source: string, target: string, extra: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    Message: '11',
    Step: step,
    ID: String(10 + step),
    TimeCreated: '2026-10-14T10:00:00.000',
    Type: 'Request',
    Status: 'Completed',
    Source: source,
    Target: target,
    BodyClass: '',
    Error: false,
    SessionId: '11',
    ...extra,
  };
}

/** A session of four messages: a request in, a request on, an error response back and a response out. */
const SESSION = [
  row(1, 'Svc', 'Proc', { BodyClass: 'Ens.StringRequest' }),
  row(2, 'Proc', 'Op'),
  row(3, 'Op', 'Proc', { Type: 'Response', Status: 'Error', Error: true }),
  row(4, 'Proc', 'Svc', { Type: 'Response', BodyClass: 'Ens.StringResponse' }),
];

const planted: HTMLElement[] = [];

async function mount() {
  TestBed.resetTestingModule();
  const refresh = new FakeRefresh();
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  const store: ScreenStore = stores.for(DESCRIPTOR, []);
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: APP_BASE_HREF, useValue: '/ocupilot' },
      { provide: RefreshService, useValue: refresh as unknown as RefreshService },
      { provide: ScopeService, useValue: { namespace: () => 'HSCUSTOM', subscribe: () => () => {} } as unknown as ScopeService },
    ],
  });
  const router = TestBed.inject(Router);
  await router.navigateByUrl(TRACE_URL);
  const fixture = TestBed.createComponent(InteropMessageTrace);
  fixture.componentRef.setInput('screen', SCREEN);
  fixture.componentRef.setInput('store', store);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  const host = fixture.nativeElement as HTMLElement;
  const page = {
    refresh,
    store,
    router,
    host,
    block: (name: string) => host.querySelector(`[data-ocu-trace="${name}"]`),
    answer: (rows: readonly unknown[], truncated = false) => {
      store.applyTick(rows, truncated, '', new Date());
      refresh.loaded = true;
      refresh.notify();
      fixture.detectChanges();
    },
    redraw: () => {
      refresh.notify();
      fixture.detectChanges();
    },
    links: () => [...host.querySelectorAll<SVGAElement>('svg a')],
    heads: () => [...host.querySelectorAll('svg g.ocu-trace-participant')],
    view: (key: string) => host.querySelector(`[data-ocu-trace-view="${key}"]`) as HTMLButtonElement,
    /** Click `target`, and answer whether the click was still free to follow its link once it reached the document. */
    click: (target: Element, init: MouseEventInit = {}) => {
      let free = true;
      const spy = (event: Event): void => {
        free = !event.defaultPrevented;
        event.preventDefault();
      };
      document.addEventListener('click', spy);
      try {
        target.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true, ...init }));
      } finally {
        document.removeEventListener('click', spy);
      }
      return free;
    },
    detect: () => fixture.detectChanges(),
  };
  return page;
}

describe('the message Trace block', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  // Mutation (Rule 19): make `showSkeleton` answer false -> this goes red.
  it('draws skeleton bars in an aria-busy region until the first answer, and nothing else', async () => {
    const page = await mount();
    expect(page.block('skeleton')).not.toBeNull();
    expect(page.host.querySelector('.ocu-trace-frame')?.getAttribute('aria-busy')).toBe('true');
    for (const name of ['empty', 'fault', 'nomatch', 'cut', 'diagram', 'mermaid']) expect(page.block(name), name).toBeNull();
  });

  // Mutation (Rule 19): drop the `isBannerFault` test from the read state's `showRefusal` -> the connectivity-banner leg goes red.
  it('draws a refusal the connectivity banner has no copy for, with Retry, in place of the skeleton', async () => {
    const page = await mount();
    page.refresh.failure = { kind: 'refused', status: 403, code: null, path: '/screens/x/read' };
    page.redraw();
    const fault = page.block('fault');
    expect(fault?.textContent).toContain(STRINGS.connectivityRequestRefused);
    expect(page.block('skeleton')).toBeNull();
    const retry = fault?.querySelector('button') as HTMLButtonElement;
    expect(retry.textContent?.trim()).toBe(STRINGS.actionRetry);
    retry.click();
    expect(page.refresh.reads).toBe(1);

    page.refresh.failure = { kind: 'unreachable', status: 0, code: null, path: '/screens/x/read' };
    page.redraw();
    expect(page.block('fault')).toBeNull();
  });

  // Mutation (Rule 19): make `showEmpty` answer false -> this goes red.
  it('draws the Header tab\'s "no longer exists" sentence when the answer holds no row', async () => {
    const page = await mount();
    page.answer([]);
    expect(page.block('empty')?.textContent).toContain(STRINGS.interopMessageHeaderEmpty);
    for (const name of ['skeleton', 'diagram', 'mermaid', 'nomatch']) expect(page.block(name), name).toBeNull();
    expect(page.host.querySelector('.ocu-source-views')).toBeNull();
  });

  // Mutation (Rule 19): draw `store.data()` in place of the store's view -> the filtered legs go red.
  it('says "No matches." when the command bar\'s filter leaves none of the rows, and draws only the matching rows in both views', async () => {
    const page = await mount();
    page.answer(SESSION);
    page.store.setFilter('Ens.StringResponse');
    page.redraw();
    expect(page.links()).toHaveLength(1);
    expect(page.heads().map((head) => head.querySelector('title')?.textContent)).toEqual(['Proc', 'Svc']);
    page.view('mermaid').click();
    page.detect();
    const text = page.block('mermaid')?.textContent ?? '';
    expect(text).toContain('Proc-->>Svc: Ens.StringResponse');
    expect(text).not.toContain('Op');
    page.view('diagram').click();
    page.detect();

    page.store.setFilter('no row says this');
    page.redraw();
    expect(page.block('nomatch')?.textContent).toContain(STRINGS.logViewerNoMatches);
    expect(page.block('diagram')).toBeNull();
    expect(page.block('mermaid')).toBeNull();
    expect(page.block('empty')).toBeNull();
  });

  // Mutation (Rule 19): drop the `store().data().length > 0` term from `showNoMatch` -> the faulted re-read draws "No matches." and
  // this goes red.
  it('says nothing of matches when a re-read of an empty answer faults, since no filter left anything out', async () => {
    const page = await mount();
    page.answer([]);
    page.refresh.failure = { kind: 'unreachable', status: 0, code: null, path: '/screens/x/read' };
    page.redraw();
    expect(page.block('nomatch')).toBeNull();
    expect(page.block('diagram')).toBeNull();
    page.refresh.failure = { kind: 'refused', status: 403, code: null, path: '/screens/x/read' };
    page.redraw();
    expect(page.block('fault')).not.toBeNull();
    expect(page.block('nomatch')).toBeNull();
  });

  // Mutation (Rule 19): register a row's target before its source in `traceModel` -> the head order goes red.
  it('draws a head and a lifeline for each participant in first-appearance order, each head titled with the whole name', async () => {
    const page = await mount();
    const long = `${'x'.repeat(24)}-tail`;
    page.answer([row(1, 'Svc', long), row(2, long, '')]);
    const heads = page.heads();
    expect(heads.map((head) => head.querySelector('title')?.textContent)).toEqual(['Svc', long, STRINGS.interopTraceNoName]);
    expect(heads.map((head) => head.querySelector('text')?.textContent)).toEqual(['Svc', `${'x'.repeat(23)}\u2026`, STRINGS.interopTraceNoName]);
    expect(heads.map((head) => head.querySelector('title') === head.firstElementChild)).toEqual([true, true, true]);
    expect(page.host.querySelectorAll('svg .ocu-trace-lifeline')).toHaveLength(3);
    const svg = page.host.querySelector('svg') as SVGSVGElement;
    expect(svg.getAttribute('role')).toBe('group');
    expect(svg.getAttribute('aria-label')).toBe(STRINGS.interopTraceDiagramLabel);
    expect(page.host.querySelector('.ocu-trace-scroll')?.contains(svg)).toBe(true);
  });

  // Mutation (Rule 19): ignore `kind` in the template's `ocu-trace-response` binding (every arrow solid) -> the response leg goes red.
  it('draws one link for each arrow in Step order: ID, label, dashed class for a response, error class for an error', async () => {
    const page = await mount();
    page.answer([SESSION[2], SESSION[0], SESSION[3], SESSION[1]]);
    const links = page.links();
    expect(links.map((link) => link.querySelector('.ocu-trace-id')?.textContent)).toEqual(['11', '12', '13', '14']);
    expect(links.map((link) => link.querySelector('.ocu-trace-label')?.textContent)).toEqual([
      'Ens.StringRequest',
      STRINGS.interopTraceNoBody,
      `${STRINGS.interopTraceNoBody} ${STRINGS.interopTraceErrorMark}`,
      'Ens.StringResponse',
    ]);
    expect(links.map((link) => link.classList.contains('ocu-trace-response'))).toEqual([false, false, true, true]);
    expect(links.map((link) => link.classList.contains('ocu-trace-error'))).toEqual([false, false, true, false]);
    const model = traceModel(SESSION);
    expect(links.map((link) => link.getAttribute('aria-label'))).toEqual(model.arrows.map((arrow) => arrowName(arrow)));
    expect(links[2].getAttribute('aria-label')).toBe('Message 13: Response from Op to Proc, Error');
  });

  // Mutation (Rule 19): drop the template's `@else` branch (the loop path of a self call) -> the loop leg goes red; drop the arrowhead
  // path -> the head leg goes red.
  it('draws a call a participant makes to itself as a loop path, and every arrow with its head', async () => {
    const page = await mount();
    page.answer([row(1, 'Svc', 'Svc'), SESSION[2]]);
    const [self, error] = page.links();
    expect(self.querySelector('line.ocu-trace-line')).toBeNull();
    expect(self.querySelector('path.ocu-trace-line')?.getAttribute('d') ?? '').toMatch(/^M /);
    expect(error.querySelector('line.ocu-trace-line')).not.toBeNull();
    expect(error.querySelector('path.ocu-trace-line')).toBeNull();
    for (const link of [self, error]) expect(link.querySelector('path.ocu-trace-mark')?.getAttribute('d') ?? '').toMatch(/^M .* Z$/);
  });

  // Mutation (Rule 19): build the href from `messages/trace` in place of `messages/document` -> the href leg goes red; let
  // `followInAppLink` navigate a Shift click while leaving the browser's default -> the Shift leg's URL read goes red.
  it('links each arrow to its message\'s Header tab in the namespace on screen, and follows it in the app on a plain click only', async () => {
    const page = await mount();
    page.answer(SESSION);
    const second = page.links()[1];
    expect(page.links().map((link) => link.getAttribute('href'))).toEqual([
      '/ocupilot/interoperability/messages/document/11?ns=HSCUSTOM',
      '/ocupilot/interoperability/messages/document/12?ns=HSCUSTOM',
      '/ocupilot/interoperability/messages/document/13?ns=HSCUSTOM',
      '/ocupilot/interoperability/messages/document/14?ns=HSCUSTOM',
    ]);

    for (const init of [{ ctrlKey: true }, { metaKey: true }, { shiftKey: true }, { altKey: true }, { button: 1 }]) {
      expect(page.click(second, init), JSON.stringify(init)).toBe(true);
      await new Promise((resolve) => setTimeout(resolve, 0));
      expect(page.router.url, JSON.stringify(init)).toBe(TRACE_URL);
    }

    expect(page.click(second)).toBe(false);
    await new Promise((resolve) => setTimeout(resolve, 0));
    expect(page.router.url).toBe('/interoperability/messages/document/12?ns=HSCUSTOM');
  });

  // Mutation (Rule 19): render a participant's name through `innerHTML` -> an element is made of it and this goes red.
  it('draws a configuration name holding markup as the text it is, with no element made of it and no style or id taken from a row', async () => {
    const page = await mount();
    const name = '<script>alert(1)</script><b>x</b>';
    page.answer([row(1, name, 'Op', { BodyClass: '<img src=x onerror=alert(1)>' })]);
    const svg = page.host.querySelector('svg') as SVGSVGElement;
    expect(svg.querySelector('script, b, img')).toBeNull();
    expect(page.host.querySelectorAll('script')).toHaveLength(0);
    expect(page.heads()[0].querySelector('title')?.textContent).toBe(name);
    expect(page.heads()[0].querySelector('text')?.textContent).toBe(`${name.slice(0, 23)}\u2026`);
    expect(page.links()[0].querySelector('.ocu-trace-label')?.textContent).toBe('<img src=x onerror=alert(1)>');
    expect(svg.querySelectorAll('[style], [id]')).toHaveLength(0);
    expect(page.links()[0].getAttribute('aria-label')).toContain(name);
  });

  // Mutation (Rule 19): give the hit rect a height of 20 -> the 24-pixel leg goes red.
  it('gives every link a hit area at least 24 pixels tall and an accessible name', async () => {
    const page = await mount();
    page.answer(SESSION);
    for (const link of page.links()) {
      expect(Number(link.querySelector('.ocu-trace-hit')?.getAttribute('height'))).toBeGreaterThanOrEqual(24);
      expect((link.getAttribute('aria-label') ?? '').length).toBeGreaterThan(0);
    }
    expect(page.links()).toHaveLength(4);
  });

  // Mutation (Rule 19): make `cut` answer false -> this goes red.
  it('says how many messages it draws above the diagram when the read truncated the session', async () => {
    const page = await mount();
    page.answer(SESSION, true);
    const cut = page.block('cut');
    expect(cut?.textContent).toBe(STRINGS.interopTraceCut.replace('<n>', String(page.store.maxRows())));
    const frame = page.host.querySelector('.ocu-trace-frame') as HTMLElement;
    expect(Array.from(frame.children).map((child) => child.getAttribute('data-ocu-trace') ?? child.className)).toEqual(['cut', 'ocu-source-views', 'diagram']);
    page.answer(SESSION, false);
    expect(page.block('cut')).toBeNull();
  });

  // Mutation (Rule 19): make the view group's buttons ignore `aria-pressed` -> the pressed leg goes red.
  it('switches between the diagram and the Mermaid text, the diagram first, with aria-pressed on the chosen view', async () => {
    const page = await mount();
    page.answer(SESSION);
    const group = page.host.querySelector('.ocu-source-views') as HTMLElement;
    expect(group.getAttribute('role')).toBe('group');
    expect(group.getAttribute('aria-label')).toBe(STRINGS.viewMenuLabel);
    expect([...group.querySelectorAll('button')].map((button) => button.textContent?.trim())).toEqual([STRINGS.interopTraceViewDiagram, STRINGS.interopTraceViewMermaid]);
    expect(page.view('diagram').getAttribute('aria-pressed')).toBe('true');
    expect(page.view('mermaid').getAttribute('aria-pressed')).toBe('false');
    expect(page.block('diagram')).not.toBeNull();
    expect(page.block('mermaid')).toBeNull();

    page.view('mermaid').click();
    page.detect();
    expect(page.view('diagram').getAttribute('aria-pressed')).toBe('false');
    expect(page.view('mermaid').getAttribute('aria-pressed')).toBe('true');
    expect(page.block('diagram')).toBeNull();
    const mermaid = page.block('mermaid') as HTMLElement;
    expect(mermaid.tagName).toBe('APP-CODE-BLOCK');
    expect(mermaid.querySelector('pre')?.textContent).toBe(traceMermaid(traceModel(SESSION)));
    expect(mermaid.querySelector(`.${COPY_BUTTON_CLASS}`)).not.toBeNull();

    page.view('diagram').click();
    page.detect();
    expect(page.block('diagram')).not.toBeNull();
    expect(page.block('mermaid')).toBeNull();
  });

  // Mutation (Rule 19): drop the `descriptor` comparison from the read state's `boundHere` -> this goes red.
  it('draws the skeleton while the framework is bound to another screen', async () => {
    const page = await mount();
    page.answer(SESSION);
    page.refresh.bound = 'OcuPilot.Screen.Descriptor.InteropMessageHeaderTab';
    page.redraw();
    expect(page.block('skeleton')).not.toBeNull();
    expect(page.block('diagram')).toBeNull();
  });
});
