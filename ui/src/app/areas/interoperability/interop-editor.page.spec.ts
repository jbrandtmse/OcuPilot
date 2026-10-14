import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { NavigationService, formatRequires, type Verdict } from '../../core/navigation';
import { ScopeService } from '../../core/scope';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { screenReadPath } from '../../core/screen-read';
import { STRINGS } from '../../core/strings';
import { interopEditorSource, type InteropEditor } from '../../core/vendor-frame';
import { ARCHETYPE_PAGES, DESCRIPTOR_PAGES, resolveScreenPage } from '../../shell/screen-outlet';
import { InteropEditorPage } from './interop-editor.page';

/**
 * The three embedded editor screens over stubs of what the instance supplies -- the URL's screen, the
 * owning list's declared read, the list's verdict and the scope (Story 20.7). The real store, the real
 * `app-interop-editor-frame` and the real template run, so the assertions are about rendered DOM:
 * each phase draws its block, `open` draws one frame whose address is the builder's for the editor,
 * namespace and document less its extension, Refresh and an id change and a namespace move each draw
 * a different frame element, and the page issues only the list's read.
 */

interface Kind {
  readonly descriptor: string;
  readonly list: string;
  readonly editor: InteropEditor;
  readonly empty: string;
  readonly coded: string | null;
}

const KINDS: readonly Kind[] = [
  {
    descriptor: 'OcuPilot.Screen.Descriptor.InteropRuleEditor',
    list: 'interoperability/rules',
    editor: 'rule-editor',
    empty: 'This business rule no longer exists.',
    coded: null,
  },
  {
    descriptor: 'OcuPilot.Screen.Descriptor.InteropProcessEditor',
    list: 'interoperability/processes',
    editor: 'bpl-editor',
    empty: 'This business process no longer exists.',
    coded: 'This business process is written as a class, not in BPL, so the BPL editor cannot open it.',
  },
  {
    descriptor: 'OcuPilot.Screen.Descriptor.InteropTransformEditor',
    list: 'interoperability/transforms',
    editor: 'dtl-editor',
    empty: 'This data transformation no longer exists.',
    coded: 'This data transformation is written as a class, not in DTL, so the DTL editor cannot open it.',
  },
];

const screenFor = (descriptor: string) => SCREENS.find((screen) => screen.descriptor === descriptor) as ScreenDeclaration;

const ALLOWED: Verdict = { allowed: true, failedPair: '' };

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

type Answer = JsonResult<unknown>;

interface Mounted {
  readonly fixture: ComponentFixture<InteropEditorPage>;
  readonly host: HTMLElement;
  readonly router: Router;
  readonly reads: { path: string; scope: string | null | undefined }[];
  readonly verdictsAsked: string[];
  /** The bus the page hears confirmed changes on. */
  readonly bus: ChangeBus;
  /** What the next read answers. */
  answer: Answer;
  /** What the list's verdict is. */
  verdict: Verdict;
  switchNamespace(namespace: string): void;
}

const rows = (...list: readonly Record<string, unknown>[]): Answer => ({ kind: 'ok', status: 200, body: { fields: [], rows: list, truncated: false } });

async function mount(kind: Kind, name: string, first: Answer): Promise<Mounted> {
  TestBed.resetTestingModule();
  const screen = screenFor(kind.descriptor);
  const mounted = {
    reads: [] as { path: string; scope: string | null | undefined }[],
    verdictsAsked: [] as string[],
    answer: first,
    verdict: ALLOWED,
  };
  const scope = { namespace: 'HSCUSTOM', listeners: new Set<() => void>() };
  const bus = new ChangeBus();
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      mounted.reads.push({ path, scope: init.scope });
      return mounted.answer as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ChangeBus, useValue: bus },
      { provide: ApiService, useValue: api as unknown as ApiService },
      {
        provide: NavigationService,
        useValue: {
          screenForUrl: () => screen,
          screenVerdict: (route: string) => {
            mounted.verdictsAsked.push(route);
            return mounted.verdict;
          },
        } as unknown as NavigationService,
      },
      {
        provide: ScopeService,
        useValue: {
          loaded: () => true,
          namespace: () => scope.namespace,
          subscribe: (listener: () => void) => {
            scope.listeners.add(listener);
            return () => scope.listeners.delete(listener);
          },
        } as unknown as ScopeService,
      },
    ],
  });
  const router = TestBed.inject(Router);
  await router.navigateByUrl(`/${screen.route}/${encodeEntityId(name)}?ns=HSCUSTOM`);
  const fixture = TestBed.createComponent(InteropEditorPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  const switchNamespace = (namespace: string) => {
    scope.namespace = namespace;
    for (const listener of [...scope.listeners]) listener();
  };
  return Object.assign(mounted, { fixture, host: fixture.nativeElement as HTMLElement, router, switchNamespace, bus }) as Mounted;
}

const frameHosts = (host: HTMLElement) => Array.from(host.querySelectorAll('app-interop-editor-frame'));

const frames = (host: HTMLElement) => Array.from(host.querySelectorAll('iframe'));

const block = (host: HTMLElement, name: string) => host.querySelector(`[data-ocu-editor="${name}"]`);

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

describe('the embedded editor screens', () => {
  it('are served by the one page, for each of the three descriptors', async () => {
    for (const kind of KINDS) {
      const screen = screenFor(kind.descriptor);
      expect(screen.archetype).toBe('viewer (source)');
      const loader = resolveScreenPage(DESCRIPTOR_PAGES, ARCHETYPE_PAGES, screen.descriptor, screen.archetype);
      expect(await loader?.(), kind.descriptor).toBe(InteropEditorPage);
    }
  });

  it('open draws the note, Refresh and one frame whose address is the builder\'s for the editor, the namespace and the document without its extension', async () => {
    // Mutation (Rule 19): the page passes the row's name with its `.cls` kept as the document -> red.
    for (const kind of KINDS) {
      const name = 'Demo.Probe.Thing.cls';
      const { host, reads, verdictsAsked } = await mount(kind, name, rows({ Name: 'Other.cls', Coded: false }, { Name: name, Modified: '', Coded: false }));
      const list = SCREENS.find((candidate) => candidate.route === kind.list) as ScreenDeclaration;
      expect(reads, `${kind.editor}: the list's read, once, in the namespace on screen`).toEqual([{ path: screenReadPath(list, 1000), scope: 'HSCUSTOM' }]);
      expect(verdictsAsked, 'the list\'s verdict was asked').toEqual([kind.list]);
      expect(block(host, 'note')?.textContent?.trim()).toBe(STRINGS.interopEditorNote);
      expect(block(host, 'refresh')?.textContent?.trim()).toBe(STRINGS.actionRefresh);
      expect(frameHosts(host).length, `${kind.editor}: one frame component`).toBe(1);
      expect(frames(host).length).toBe(1);
      expect(frames(host)[0].getAttribute('src')).toBe(interopEditorSource(kind.editor, 'HSCUSTOM', 'Demo.Probe.Thing'));
      expect(host.querySelector('section')?.getAttribute('aria-busy')).toBe('false');
      for (const absent of ['gone', 'coded', 'refused', 'fault', 'loading']) expect(block(host, absent), absent).toBeNull();
    }
  });

  it('draws skeleton bars in an aria-busy region while the read is out, and no frame', async () => {
    TestBed.resetTestingModule();
    const kind = KINDS[1];
    const screen = screenFor(kind.descriptor);
    let release: (answer: Answer) => void = () => undefined;
    const api = { requestJson: () => new Promise<Answer>((resolve) => (release = resolve)) };
    TestBed.configureTestingModule({
      providers: [
        provideRouter([{ path: '**', children: [] }]),
        { provide: ChangeBus, useValue: new ChangeBus() },
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: NavigationService, useValue: { screenForUrl: () => screen, screenVerdict: () => ALLOWED } as unknown as NavigationService },
        {
          provide: ScopeService,
          useValue: { loaded: () => true, namespace: () => 'HSCUSTOM', subscribe: () => () => undefined } as unknown as ScopeService,
        },
      ],
    });
    await TestBed.inject(Router).navigateByUrl(`/${screen.route}/${encodeEntityId('Demo.Thing.cls')}`);
    const fixture = TestBed.createComponent(InteropEditorPage);
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
    await settle(fixture);
    const host = fixture.nativeElement as HTMLElement;
    expect(host.querySelector('section')?.getAttribute('aria-busy')).toBe('true');
    expect(block(host, 'loading')?.querySelectorAll('.ocu-skeleton-bar').length).toBeGreaterThan(0);
    expect(frames(host)).toEqual([]);
    expect(block(host, 'note')).toBeNull();
    release(rows({ Name: 'Demo.Thing.cls', Coded: false }));
    await settle(fixture);
    expect(host.querySelector('section')?.getAttribute('aria-busy')).toBe('false');
    expect(block(host, 'loading')).toBeNull();
    expect(frames(host).length).toBe(1);
  });

  it('draws the descriptor\'s empty sentence and no frame for an id the read does not answer', async () => {
    // Mutation (Rule 19): the page draws the frame from the route id without the row -> red.
    for (const kind of KINDS) {
      const { host } = await mount(kind, 'Demo.Absent.cls', rows({ Name: 'Demo.Other.cls', Coded: false }));
      expect(block(host, 'gone')?.textContent?.trim(), kind.editor).toBe(kind.empty);
      expect(frames(host)).toEqual([]);
      expect(frameHosts(host)).toEqual([]);
      expect(block(host, 'note')).toBeNull();
    }
  });

  it('draws the editor\'s coded sentence and no frame for a process or a transformation written as a class', async () => {
    for (const kind of KINDS.filter((candidate) => candidate.coded !== null)) {
      const { host } = await mount(kind, 'EnsLib.Some.Coded.cls', rows({ Name: 'EnsLib.Some.Coded.cls', Coded: true }));
      expect(block(host, 'coded')?.textContent?.trim(), kind.editor).toBe(kind.coded);
      expect(frames(host)).toEqual([]);
      expect(block(host, 'gone')).toBeNull();
    }
  });

  it('draws "Requires <pair>" for a denied verdict without a request, and for a 403 that names its pair', async () => {
    const kind = KINDS[2];
    const denied = await mountDenied(kind);
    expect(denied.reads, 'a denied verdict sends no request').toEqual([]);
    expect(block(denied.host, 'refused')?.textContent?.trim()).toBe(formatRequires(STRINGS.privilegeRequiresResource, '%Ens_Code:READ'));
    expect(frames(denied.host)).toEqual([]);

    const forbidden = await mount(kind, 'Demo.Thing.cls', {
      kind: 'error',
      status: 403,
      code: 'AUTH.NOPRIVILEGE',
      reason: 'no',
      detail: { failedPair: '%Ens_Portal:USE' },
    });
    expect(block(forbidden.host, 'refused')?.textContent?.trim()).toBe(formatRequires(STRINGS.privilegeRequiresResource, '%Ens_Portal:USE'));
    expect(frames(forbidden.host)).toEqual([]);
  });

  it('draws the request-refused strip with Retry for any other answer, and Retry reads again', async () => {
    const kind = KINDS[0];
    const mounted = await mount(kind, 'Demo.Thing.cls', { kind: 'error', status: 500, code: null, reason: null, detail: null });
    const { host } = mounted;
    expect(block(host, 'fault')?.textContent).toContain(STRINGS.connectivityRequestRefused);
    expect(frames(host)).toEqual([]);
    mounted.answer = rows({ Name: 'Demo.Thing.cls' });
    const retry = block(host, 'fault')?.querySelector('button') as HTMLButtonElement;
    expect(retry.textContent?.trim()).toBe(STRINGS.actionRetry);
    retry.click();
    await settle(mounted.fixture);
    expect(mounted.reads.length).toBe(2);
    expect(block(host, 'fault')).toBeNull();
    expect(frames(host).length).toBe(1);
  });

  it('Refresh reads again and draws a new frame element at the same address, detaching the old one', async () => {
    // Mutation (Rule 19): Refresh does not bump the revision -> red.
    const kind = KINDS[2];
    const mounted = await mount(kind, 'Demo.Thing.cls', rows({ Name: 'Demo.Thing.cls', Coded: false }));
    const { host } = mounted;
    const first = frames(host)[0];
    (block(host, 'refresh') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(mounted.reads.length).toBe(2);
    const second = frames(host)[0];
    expect(frames(host).length).toBe(1);
    expect(second).not.toBe(first);
    expect(first.isConnected).toBe(false);
    expect(second.getAttribute('src')).toBe(first.getAttribute('src'));
    expect(second.getAttribute('src')).toBe(interopEditorSource('dtl-editor', 'HSCUSTOM', 'Demo.Thing'));
  });

  it('a different id in the route opens the new document in a new frame', async () => {
    const kind = KINDS[1];
    const mounted = await mount(kind, 'Demo.One.cls', rows({ Name: 'Demo.One.cls', Coded: false }, { Name: 'Demo.Two.cls', Coded: false }));
    const { host, router } = mounted;
    const first = frames(host)[0];
    expect(first.getAttribute('src')).toBe(interopEditorSource('bpl-editor', 'HSCUSTOM', 'Demo.One'));
    await router.navigateByUrl(`/${screenFor(kind.descriptor).route}/${encodeEntityId('Demo.Two.cls')}?ns=HSCUSTOM`);
    await settle(mounted.fixture);
    expect(mounted.reads.length).toBe(2);
    const second = frames(host)[0];
    expect(frames(host).length).toBe(1);
    expect(second).not.toBe(first);
    expect(first.isConnected).toBe(false);
    expect(second.getAttribute('src')).toBe(interopEditorSource('bpl-editor', 'HSCUSTOM', 'Demo.Two'));
    await router.navigateByUrl(`/${screenFor(kind.descriptor).route}/${encodeEntityId('Demo.Gone.cls')}?ns=HSCUSTOM`);
    await settle(mounted.fixture);
    expect(frames(host)).toEqual([]);
    expect(block(host, 'gone')?.textContent?.trim()).toBe(kind.empty);
  });

  it('a namespace move takes the frame away and reads the document again in the new namespace', async () => {
    const kind = KINDS[2];
    const mounted = await mount(kind, 'Demo.Thing.cls', rows({ Name: 'Demo.Thing.cls', Coded: false }));
    const { host } = mounted;
    const first = frames(host)[0];
    mounted.answer = rows();
    mounted.switchNamespace('USER');
    await settle(mounted.fixture);
    expect(first.isConnected).toBe(false);
    expect(mounted.reads.map((read) => read.scope)).toEqual(['HSCUSTOM', 'USER']);
    expect(frames(host)).toEqual([]);
    expect(block(host, 'gone')?.textContent?.trim()).toBe(kind.empty);
    mounted.answer = rows({ Name: 'Demo.Thing.cls', Coded: false });
    mounted.switchNamespace('HSCUSTOM');
    await settle(mounted.fixture);
    expect(frames(host).length).toBe(1);
    expect(frames(host)[0].getAttribute('src')).toBe(interopEditorSource('dtl-editor', 'HSCUSTOM', 'Demo.Thing'));
  });

  it('a Refresh keeps the drawn frame, busy, until its read answers; a read that faults then takes the frame away and Retry draws a new one', async () => {
    // Mutation (Rule 19): the store swallows a Refresh answer that does not open the document and leaves the screen open -> red.
    const kind = KINDS[2];
    const mounted = await mount(kind, 'Demo.Thing.cls', rows({ Name: 'Demo.Thing.cls', Coded: false }));
    const { host } = mounted;
    const first = frames(host)[0];
    let release: (answer: Answer) => void = () => undefined;
    mounted.answer = new Promise<Answer>((resolve) => (release = resolve)) as unknown as Answer;
    (block(host, 'refresh') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(mounted.reads.length).toBe(2);
    expect(host.querySelector('section')?.getAttribute('aria-busy'), 'a Refresh in flight is busy').toBe('true');
    expect(first.isConnected, 'and the editor is still on screen while it is read').toBe(true);
    expect(frames(host)).toEqual([first]);

    release({ kind: 'error', status: 500, code: null, reason: null, detail: null });
    await settle(mounted.fixture);
    expect(host.querySelector('section')?.getAttribute('aria-busy')).toBe('false');
    expect(first.isConnected, 'the faulting read took the editor away').toBe(false);
    expect(frames(host)).toEqual([]);
    expect(frameHosts(host)).toEqual([]);
    expect(block(host, 'note')).toBeNull();
    expect(block(host, 'refresh')).toBeNull();
    expect(block(host, 'fault')?.textContent).toContain(STRINGS.connectivityRequestRefused);

    mounted.answer = rows({ Name: 'Demo.Thing.cls', Coded: false });
    (block(host, 'fault')?.querySelector('button') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(mounted.reads.length).toBe(3);
    expect(block(host, 'fault')).toBeNull();
    expect(frames(host).length).toBe(1);
    expect(frames(host)[0]).not.toBe(first);
    expect(frames(host)[0].getAttribute('src')).toBe(interopEditorSource('dtl-editor', 'HSCUSTOM', 'Demo.Thing'));
  });

  it('the bar says the agent reads only what is saved, beside the note and before any request, and only while the editor is open', async () => {
    // Mutation (Rule 19): the page omits the agent line -> red.
    for (const kind of KINDS) {
      const opened = await mount(kind, 'Demo.Thing.cls', rows({ Name: 'Demo.Thing.cls', Coded: false }));
      const line = block(opened.host, 'agent');
      expect(line?.textContent?.trim(), `${kind.editor}: the agent line`).toBe(STRINGS.interopEditorAgentNote);
      expect(line?.previousElementSibling, 'it follows the note').toBe(block(opened.host, 'note'));
      expect(line?.parentElement?.classList.contains('ocu-interop-editor-bar'), 'in the bar').toBe(true);
      const gone = await mount(kind, 'Demo.Absent.cls', rows({ Name: 'Demo.Thing.cls', Coded: false }));
      expect(block(gone.host, 'agent'), `${kind.editor}: no editor, no agent line`).toBeNull();
    }
  });

  it('a confirmed change to the document opens it again in a new frame at the same address; another id, namespace or type does nothing', async () => {
    // Mutation (Rule 19): the page does not subscribe to the bus -> the matching event draws no new frame and this goes red.
    const kind = KINDS[2];
    const mounted = await mount(kind, 'Demo.Thing.cls', rows({ Name: 'Demo.Thing.cls', Coded: false }));
    const { host, bus } = mounted;
    const first = frames(host)[0];
    expect(mounted.reads.length).toBe(1);
    const publish = (over: Partial<{ type: string; scope: string; id: string; kind: 'changed' | 'proposal-open' }> = {}) =>
      bus.publish({ kind: 'changed', type: 'class', scope: 'HSCUSTOM', id: 'Demo.Thing.cls', action: 'updated', proposalId: 'p1', ...over });
    for (const miss of [{ id: 'Demo.Other.cls' }, { scope: 'USER' }, { type: 'routine', id: 'Demo.Thing.mac' }]) {
      expect(publish(miss), JSON.stringify(miss)).toBe(true);
      await settle(mounted.fixture);
      expect(mounted.reads.length, `${JSON.stringify(miss)} reads nothing`).toBe(1);
      expect(frames(host)[0], 'and keeps the frame').toBe(first);
    }
    expect(bus.publish({ kind: 'proposal-open', type: 'class', scope: 'HSCUSTOM', id: 'Demo.Thing.cls', proposalId: 'p2' })).toBe(true);
    await settle(mounted.fixture);
    expect(mounted.reads.length, 'a proposal opening is not a change').toBe(1);

    expect(publish({ id: 'Demo.Other.cls,Demo.Thing.cls' })).toBe(true);
    await settle(mounted.fixture);
    expect(mounted.reads.length, 'the document is read again').toBe(2);
    const second = frames(host)[0];
    expect(frames(host).length).toBe(1);
    expect(second).not.toBe(first);
    expect(first.isConnected, 'the old frame is detached').toBe(false);
    expect(second.getAttribute('src')).toBe(first.getAttribute('src'));
    expect(second.getAttribute('src')).toBe(interopEditorSource('dtl-editor', 'HSCUSTOM', 'Demo.Thing'));
    expect(block(host, 'agent')?.textContent?.trim()).toBe(STRINGS.interopEditorAgentNote);
  });

  it('reloads each of the three editors, in its own editor, for a confirmed change to its document, and stops hearing changes once the page is destroyed', async () => {
    // Mutation (Rule 19): the page does not release its bus subscription as it is destroyed -> the destroyed page reads the list again and this goes red.
    for (const kind of KINDS) {
      const mounted = await mount(kind, 'Demo.Thing.cls', rows({ Name: 'Demo.Thing.cls', Coded: false }));
      const { fixture, host, bus } = mounted;
      const publish = () => bus.publish({ kind: 'changed', type: 'class', scope: 'HSCUSTOM', id: 'Demo.Thing.cls', action: 'updated', proposalId: 'p1' });
      const first = frames(host)[0];
      expect(first.getAttribute('src'), `${kind.editor}: the first frame`).toBe(interopEditorSource(kind.editor, 'HSCUSTOM', 'Demo.Thing'));
      expect(publish()).toBe(true);
      await settle(fixture);
      expect(mounted.reads.length, `${kind.editor}: the document is read again`).toBe(2);
      expect(first.isConnected, `${kind.editor}: the old frame is detached`).toBe(false);
      expect(frames(host).length, `${kind.editor}: and one frame is drawn`).toBe(1);
      expect(frames(host)[0].getAttribute('src'), `${kind.editor}: for the same editor and address`).toBe(first.getAttribute('src'));
      fixture.destroy();
      expect(publish()).toBe(true);
      await new Promise((resolve) => setTimeout(resolve, 20));
      expect(mounted.reads.length, `${kind.editor}: a destroyed page reads nothing for a change to its document`).toBe(2);
    }
  });

  it('reads nothing before the scope has a namespace, shows the skeleton meanwhile, and reads in the namespace the scope arrives with', async () => {
    // Mutation (Rule 19): the page reads at once, without waiting for the scope -> a read is sent with no namespace and this goes red.
    TestBed.resetTestingModule();
    const kind = KINDS[1];
    const screen = screenFor(kind.descriptor);
    const reads: { path: string; scope: string | null | undefined }[] = [];
    const api = {
      requestJson: async (path: string, init: ApiRequestInit = {}) => {
        reads.push({ path, scope: init.scope });
        return rows({ Name: 'Demo.Thing.cls', Coded: false });
      },
    };
    const scope = { loaded: false, namespace: '', listeners: new Set<() => void>() };
    TestBed.configureTestingModule({
      providers: [
        provideRouter([{ path: '**', children: [] }]),
        { provide: ChangeBus, useValue: new ChangeBus() },
        { provide: ApiService, useValue: api as unknown as ApiService },
        { provide: NavigationService, useValue: { screenForUrl: () => screen, screenVerdict: () => ALLOWED } as unknown as NavigationService },
        {
          provide: ScopeService,
          useValue: {
            loaded: () => scope.loaded,
            namespace: () => scope.namespace,
            subscribe: (listener: () => void) => {
              scope.listeners.add(listener);
              return () => scope.listeners.delete(listener);
            },
          } as unknown as ScopeService,
        },
      ],
    });
    await TestBed.inject(Router).navigateByUrl(`/${screen.route}/${encodeEntityId('Demo.Thing.cls')}`);
    const fixture = TestBed.createComponent(InteropEditorPage);
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
    await settle(fixture);
    const host = fixture.nativeElement as HTMLElement;
    expect(reads, 'nothing is read before the scope has resolved').toEqual([]);
    expect(host.querySelector('section')?.getAttribute('aria-busy')).toBe('true');
    expect(block(host, 'loading')).not.toBeNull();
    expect(frames(host)).toEqual([]);

    scope.loaded = true;
    scope.namespace = 'USER';
    for (const listener of [...scope.listeners]) listener();
    await settle(fixture);
    expect(reads.map((read) => read.scope)).toEqual(['USER']);
    expect(frames(host).length).toBe(1);
    expect(frames(host)[0].getAttribute('src')).toBe(interopEditorSource('bpl-editor', 'USER', 'Demo.Thing'));
  });
});

/** A page whose list's verdict is denied before it opens. */
async function mountDenied(kind: Kind): Promise<Mounted> {
  TestBed.resetTestingModule();
  const screen = screenFor(kind.descriptor);
  const reads: { path: string; scope: string | null | undefined }[] = [];
  const api = {
    requestJson: async (path: string, init: ApiRequestInit = {}) => {
      reads.push({ path, scope: init.scope });
      return rows();
    },
  };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: ApiService, useValue: api as unknown as ApiService },
      {
        provide: NavigationService,
        useValue: { screenForUrl: () => screen, screenVerdict: () => ({ allowed: false, failedPair: '%Ens_Code:READ' }) } as unknown as NavigationService,
      },
      {
        provide: ScopeService,
        useValue: { loaded: () => true, namespace: () => 'HSCUSTOM', subscribe: () => () => undefined } as unknown as ScopeService,
      },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(`/${screen.route}/${encodeEntityId('Demo.Thing.cls')}`);
  const fixture = TestBed.createComponent(InteropEditorPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, reads } as unknown as Mounted;
}
