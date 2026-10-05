import { ComponentFixture, TestBed } from '@angular/core/testing';
import { ActivatedRoute, Router, convertToParamMap, provideRouter } from '@angular/router';
import { BehaviorSubject } from 'rxjs';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import type { ConnectivityService } from '../../core/connectivity';
import { encodeEntityId } from '../../core/entity-id';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { SourceViewerPage } from './document-viewer.page';
import { SourceViewerState, classReferenceUrl, documentOf } from './document-viewer.store';

/**
 * The class and routine viewers over the shipped descriptors, with the real `RefreshService`,
 * `ScreenStores` and `DataTable` and a stubbed HTTP answer per form (Story 19.1, AC2): the header,
 * each view, the re-read per text form, the not-available sentence, a routine's missing class
 * structure, a gone document, and document text rendered as text (AD-11). Story 19.9's Class
 * reference: the frame's address, `sandbox` and name, drawn only once the read has answered for the
 * namespace on screen, and a load the page did not start set back to the class page; jsdom loads no
 * frame, so each `load` is dispatched by the test.
 */

const CLASS_VIEWER = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ExplorerClassDocument') as ScreenDeclaration;
const ROUTINE_VIEWER = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ExplorerRoutineDocument') as ScreenDeclaration;

/** Text a renderer that bound markup would turn into an element. */
const HOSTILE = '<img src=x onerror="alert(1)"> Class Demo.Probe';

const CLASS_ROWS = [
  { Order: 1, Kind: 'class', Name: 'Demo.Probe.cls', Type: '%RegisteredObject', Flags: '', Description: 'The probe class.', Modified: '2026-10-01 10:00:00', Database: 'HSCUSTOM', Generates: 'Demo.Probe.1.int' },
  { Order: 2, Kind: 'method', Name: 'Run', Type: '%Status', Flags: 'class', Description: 'Runs it.', Modified: null, Database: null, Generates: null },
  { Order: 3, Kind: 'property', Name: 'Size', Type: '%Integer', Flags: '', Description: '', Modified: null, Database: null, Generates: null },
];

const ROUTINE_ROWS = [
  { Order: 1, Kind: 'routine', Name: 'Demo.Probe.mac', Type: 'mac', Flags: '', Description: '', Modified: '2026-10-01 10:00:00', Database: 'HSCUSTOM', Generates: 'Demo.Probe.int' },
];

function documentFor(name: string, form: string, rows: readonly unknown[]) {
  const deployed = name.startsWith('Demo.Deployed');
  // A routine kept only as object code (Story 19.2): no form is available, and each says why.
  const objectOnly = name.startsWith('Demo.ObjectOnly');
  const generates = deployed || objectOnly ? [] : name.endsWith('.cls') ? ['Demo.Probe.1.int'] : ['Demo.Probe.int'];
  const available = (form !== 'xml' || name.endsWith('.cls')) && !(deployed && form === 'int') && !objectOnly;
  return {
    name,
    form,
    available,
    ...(objectOnly ? { reason: 'objectonly' } : {}),
    content: available ? [`${form} line 1`, form === 'udl' ? HOSTILE : `${form} line 2`] : [],
    modified: '2026-10-01 10:00:00',
    database: 'HSCUSTOM',
    generates,
    rows,
  };
}

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 20));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

const planted: HTMLElement[] = [];

async function mount(screen: ScreenDeclaration, name: string, rows: readonly unknown[], missing = false, refuseIn = '') {
  TestBed.resetTestingModule();
  const paths: string[] = [];
  let namespace = 'HSCUSTOM';
  const scopeListeners = new Set<() => void>();
  /** While set, each read waits until the test releases it, oldest first. */
  let holding = false;
  const held: (() => void)[] = [];
  let gone = missing;
  let refusing = false;
  const api = {
    requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
      paths.push(path);
      const asked = namespace;
      if (holding) await new Promise<void>((resolve) => held.push(resolve));
      if (gone) {
        return { kind: 'error', status: 404, code: 'PORT.NOTFOUND', reason: 'This namespace holds no document by that name.', detail: null };
      }
      if (asked === refuseIn || refusing) {
        return { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'Refused.', detail: { failedPair: '%DB_USER:READ' } };
      }
      const form = new URLSearchParams(path.split('?')[1] ?? '').get('form') ?? 'udl';
      const { rows: answered, ...document } = documentFor(name, form, rows);
      return { kind: 'ok', status: 200, body: { fields: [], rows: answered, truncated: false, banner: '', document } as T };
    },
  };
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  const refresh = new RefreshService({
    stores,
    connectivity: { retryWhenReachable: () => {} } as unknown as ConnectivityService,
    bus: new ChangeBus(),
    namespace: () => namespace,
    schedule: () => {},
  });
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: NavigationService, useValue: { screenForUrl: () => screen } as unknown as NavigationService },
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: RefreshService, useValue: refresh },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      {
        provide: ScopeService,
        useValue: {
          loaded: () => true,
          namespace: () => namespace,
          subscribe: (listener: () => void) => {
            scopeListeners.add(listener);
            return () => scopeListeners.delete(listener);
          },
        } as unknown as ScopeService,
      },
      {
        provide: ActivatedRoute,
        // The router hands the component the segment decoded once (AD-13).
        useValue: { paramMap: new BehaviorSubject(convertToParamMap({ id: decodeURIComponent(encodeEntityId(name)) })) } as unknown as ActivatedRoute,
      },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(`/${screen.route}/${encodeEntityId(name)}?ns=HSCUSTOM`);
  const fixture = TestBed.createComponent(SourceViewerPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  const host = fixture.nativeElement as HTMLElement;
  return {
    host,
    paths,
    refresh,
    settle: () => settle(fixture),
    hold: () => {
      holding = true;
    },
    /** Answer the oldest held read, then let the page settle. */
    release: async () => {
      holding = held.length > 1;
      held.shift()?.();
      await settle(fixture);
    },
    /** From the next read on, the namespace holds no document by this name. */
    remove: () => {
      gone = true;
    },
    /** From the next read on, every read is refused. */
    refuse: () => {
      refusing = true;
    },
    frame: () => host.querySelector('iframe[data-ocu-source="reference-frame"]') as HTMLIFrameElement | null,
    /** Move the scope as `src/main.ts` does: the framework re-reads, then the scope's listeners run. */
    switchTo: async (next: string) => {
      namespace = next;
      refresh.noteScopeChanged();
      for (const listener of [...scopeListeners]) listener();
      await settle(fixture);
    },
    /** Move the scope and let the page render, without waiting for any held read. */
    switchHeld: (next: string) => {
      namespace = next;
      refresh.noteScopeChanged();
      for (const listener of [...scopeListeners]) listener();
      fixture.detectChanges();
    },
    view: async (key: string) => {
      (host.querySelector(`[data-ocu-source-view="${key}"]`) as HTMLElement).click();
      await settle(fixture);
    },
    pressed: () =>
      Array.from(host.querySelectorAll('[data-ocu-source-view]'))
        .filter((button) => button.getAttribute('aria-pressed') === 'true')
        .map((button) => button.getAttribute('data-ocu-source-view')),
  };
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

describe('the class and routine viewers', () => {
  it('opens a class on Source: the header, six views, and the text rendered as text', async () => {
    const { host, paths, pressed } = await mount(CLASS_VIEWER, 'Demo.Probe.cls', CLASS_ROWS);
    expect(paths).toEqual(['/api/ocupilot/screens/explorer.class/read?maxRows=1000&name=Demo.Probe.cls&form=udl']);
    const header = host.querySelector('[data-ocu-source="header"]') as HTMLElement;
    expect(header.textContent).toContain('Demo.Probe.cls');
    expect(header.textContent).toContain('HSCUSTOM');
    expect(header.textContent).toContain(STRINGS.explorerGenerates);
    expect(host.querySelector('[data-ocu-source="generates"]')?.textContent?.trim()).toBe('Demo.Probe.1.int');
    const labels = Array.from(host.querySelectorAll('[data-ocu-source-view]')).map((button) => button.textContent?.trim());
    expect(labels).toEqual([
      STRINGS.auditEventFieldSource,
      STRINGS.explorerViewXml,
      STRINGS.explorerViewInt,
      STRINGS.explorerViewStructure,
      STRINGS.linksDocumentation,
      STRINGS.explorerViewClassReference,
    ]);
    expect(pressed()).toEqual(['source']);
    const text = host.querySelector('pre[data-ocu-source="text"]') as HTMLElement;
    expect(text.getAttribute('tabindex')).toBe('0');
    expect(text.textContent).toBe(`udl line 1\n${HOSTILE}`);
    expect(text.querySelector('img')).toBeNull();
    expect(host.querySelector('[role="grid"]')).toBeNull();
  });

  it('XML and Intermediate code each re-read with their form; Structure and Documentation read nothing', async () => {
    const { host, paths, view, pressed } = await mount(CLASS_VIEWER, 'Demo.Probe.cls', CLASS_ROWS);
    await view('xml');
    expect(paths[1]).toContain('&form=xml');
    expect(host.querySelector('pre[data-ocu-source="text"]')?.textContent).toBe('xml line 1\nxml line 2');
    await view('int');
    expect(paths[2]).toContain('&form=int');
    expect(pressed()).toEqual(['int']);
    // Mutation (Rule 19): answer `textAvailable` false for the int view -> red.
    expect(host.querySelector('pre[data-ocu-source="text"]')?.textContent).toBe('int line 1\nint line 2');
    await view('structure');
    await view('documentation');
    expect(paths).toHaveLength(3);
  });

  it('Structure is the shared table over the rows; Documentation shows each documented row under its name', async () => {
    const { host, view } = await mount(CLASS_VIEWER, 'Demo.Probe.cls', CLASS_ROWS);
    await view('structure');
    expect(host.querySelector('[role="grid"]')).not.toBeNull();
    expect(host.querySelector('pre[data-ocu-source="text"]')).toBeNull();
    await view('documentation');
    const docs = host.querySelector('[data-ocu-source="documentation"]') as HTMLElement;
    expect(Array.from(docs.querySelectorAll('h2')).map((heading) => heading.textContent?.trim())).toEqual(['Demo.Probe.cls', 'Run']);
    expect(docs.textContent).toContain('The probe class.');
    expect(host.querySelector('[role="grid"]')).toBeNull();
  });

  it('a form the instance keeps none of says so in one sentence', async () => {
    const { host, view } = await mount(ROUTINE_VIEWER, 'Demo.Probe.mac', ROUTINE_ROWS);
    await view('xml');
    expect(host.querySelector('pre[data-ocu-source="text"]')).toBeNull();
    expect(host.querySelector('[data-ocu-source="not-available"]')?.textContent?.trim()).toBe(STRINGS.explorerXmlNotAvailable);
  });

  it('a class that generates no intermediate code says so on Intermediate code', async () => {
    const { host, view } = await mount(CLASS_VIEWER, 'Demo.Deployed.cls', CLASS_ROWS);
    await view('int');
    expect(host.querySelector('pre[data-ocu-source="text"]')).toBeNull();
    expect(host.querySelector('[data-ocu-source="not-available"]')?.textContent?.trim()).toBe(STRINGS.explorerIntNotAvailable);
  });

  it('a routine has no class structure, in Structure and in Documentation, and offers five views, no Class reference', async () => {
    const { host, view } = await mount(ROUTINE_VIEWER, 'Demo.Probe.mac', ROUTINE_ROWS);
    // Mutation (Rule 19): offer every view to a routine too -> a sixth button and this goes red.
    expect(Array.from(host.querySelectorAll('[data-ocu-source-view]')).map((button) => button.getAttribute('data-ocu-source-view'))).toEqual([
      'source',
      'xml',
      'int',
      'structure',
      'documentation',
    ]);
    await view('structure');
    expect(host.querySelector('[data-ocu-source="no-structure"]')?.textContent?.trim()).toBe(STRINGS.explorerRoutineNoStructure);
    expect(host.querySelector('[role="grid"]')).toBeNull();
    await view('documentation');
    expect(host.querySelector('[data-ocu-source="no-structure"]')?.textContent?.trim()).toBe(STRINGS.explorerRoutineNoStructure);
  });

  it('Story 19.2 AC8: a routine kept only as object code says so, in place of the empty state', async () => {
    // Mutation (Rule 19): drop the `OBJECT_ONLY_REASON` branch from the page's `notAvailable` -> red.
    const { host } = await mount(ROUTINE_VIEWER, 'Demo.ObjectOnly.mac', ROUTINE_ROWS);
    expect(host.querySelector('[data-ocu-source="header"]')).not.toBeNull();
    expect(host.querySelector('.ocu-data-table-empty-title')).toBeNull();
    expect(host.querySelector('pre[data-ocu-source="text"]')).toBeNull();
    expect(host.querySelector('[data-ocu-source="not-available"]')?.textContent?.trim()).toBe(STRINGS.explorerViewerObjectOnly);
  });

  it('a document the namespace no longer holds reads as the viewer empty state', async () => {
    const { host } = await mount(CLASS_VIEWER, 'Demo.Gone.cls', [], true);
    expect(host.querySelector('[data-ocu-source="header"]')).toBeNull();
    expect(host.querySelector('.ocu-data-table-empty-title')?.textContent?.trim()).toBe(STRINGS.explorerClassDocumentEmpty);
  });

  it('a namespace switch whose read is refused leaves no text from the namespace left behind', async () => {
    // Mutation (Rule 19): drop the page's `onScopeChange` -> `forget()` -> the header and text stay, red.
    const { host, paths, switchTo } = await mount(CLASS_VIEWER, 'Demo.Probe.cls', CLASS_ROWS, false, 'USER');
    expect(host.querySelector('pre[data-ocu-source="text"]')?.textContent).toBe(`udl line 1\n${HOSTILE}`);
    await switchTo('USER');
    expect(paths).toHaveLength(2);
    expect(host.querySelector('[data-ocu-source="header"]')).toBeNull();
    expect(host.querySelector('pre[data-ocu-source="text"]')).toBeNull();
    expect(host.querySelector('.ocu-data-table-refusal')).not.toBeNull();
  });

  it("Story 19.3: offers Edit source while a document's source is on screen, linking its own editor", async () => {
    const { host, view } = await mount(CLASS_VIEWER, 'Demo.Probe.cls', CLASS_ROWS);
    const link = host.querySelector('a[data-ocu-source="edit"]') as HTMLAnchorElement;
    expect(link.textContent?.trim()).toBe(STRINGS.explorerEditSource);
    expect(link.getAttribute('href')).toBe(`/system-explorer/classes/editor/${encodeEntityId('Demo.Probe.cls')}?ns=HSCUSTOM`);
    await view('xml');
    expect(host.querySelector('a[data-ocu-source="edit"]')).toBeNull();
    await view('source');
    (host.querySelector('a[data-ocu-source="edit"]') as HTMLAnchorElement).click();
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(TestBed.inject(Router).url).toBe(`/system-explorer/classes/editor/${encodeEntityId('Demo.Probe.cls')}?ns=HSCUSTOM`);
    const routine = await mount(ROUTINE_VIEWER, 'Demo.Probe.mac', ROUTINE_ROWS);
    expect(routine.host.querySelector('a[data-ocu-source="edit"]')?.getAttribute('href')).toBe(`/system-explorer/routines/editor/${encodeEntityId('Demo.Probe.mac')}?ns=HSCUSTOM`);
    for (const name of ['Demo.Probe.inc', 'Demo.Probe.int']) {
      const kind = await mount(ROUTINE_VIEWER, name, ROUTINE_ROWS);
      expect(kind.host.querySelector('a[data-ocu-source="edit"]')?.getAttribute('href')).toBe(`/system-explorer/routines/editor/${encodeEntityId(name)}?ns=HSCUSTOM`);
    }
    const objectOnly = await mount(ROUTINE_VIEWER, 'Demo.ObjectOnly.mac', ROUTINE_ROWS);
    expect(objectOnly.host.querySelector('a[data-ocu-source="edit"]')).toBeNull();
  });

  it('Story 19.4: offers Compare with and Look up a macro while a document is on screen, carrying it', async () => {
    const { host, view } = await mount(CLASS_VIEWER, 'Demo.Probe.cls', CLASS_ROWS);
    const compare = host.querySelector('a[data-ocu-source="compare"]') as HTMLAnchorElement;
    expect(compare.textContent?.trim()).toBe(STRINGS.explorerCompareWith);
    expect(compare.getAttribute('href')).toBe('/system-explorer/compare?ns=HSCUSTOM&left=Demo.Probe.cls');
    const macro = host.querySelector('a[data-ocu-source="macro"]') as HTMLAnchorElement;
    expect(macro.textContent?.trim()).toBe(STRINGS.explorerLookUpMacro);
    expect(macro.getAttribute('href')).toBe('/system-explorer/macros?ns=HSCUSTOM&document=Demo.Probe.cls');
    await view('xml');
    expect(host.querySelector('a[data-ocu-source="compare"]')).not.toBeNull();
    macro.click();
    await new Promise((resolve) => setTimeout(resolve, 20));
    expect(TestBed.inject(Router).url).toBe('/system-explorer/macros?ns=HSCUSTOM&document=Demo.Probe.cls');
    const gone = await mount(CLASS_VIEWER, 'Demo.Gone.cls', [], true);
    expect(gone.host.querySelector('a[data-ocu-source="compare"]')).toBeNull();
    expect(gone.host.querySelector('a[data-ocu-source="macro"]')).toBeNull();
  });

  it('Story 19.9 AC1, AC2, AC6: Class reference loads the class page for the namespace on screen in a frame sandboxed with no flag, named for the class, reading nothing', async () => {
    // Mutation (Rule 19): the template's `sandbox=""` becomes `sandbox="allow-scripts allow-same-origin"` -> red.
    // Mutation (Rule 19): the frame's `title` binding is removed -> red.
    const { host, paths, view, pressed, frame } = await mount(CLASS_VIEWER, 'Demo.Probe.cls', CLASS_ROWS);
    expect(frame()).toBeNull();
    await view('reference');
    expect(pressed()).toEqual(['reference']);
    const element = frame() as HTMLIFrameElement;
    expect(element.getAttribute('sandbox')).toBe('');
    expect(element.getAttribute('title')).toBe('Class reference for Demo.Probe');
    expect(element.getAttribute('src')).toBe(classReferenceUrl('HSCUSTOM', 'Demo.Probe.cls'));
    expect(element.getAttribute('src')).toBe('/csp/documatic/%25CSP.Documatic.cls?PAGE=CLASS&SHOWCLASSONLY=1&LIBRARY=HSCUSTOM&CLASSNAME=Demo.Probe');
    expect(host.querySelector('[data-ocu-source="reference-note"]')?.textContent?.trim()).toBe(
      STRINGS.explorerClassReferenceNote.replace('<class>', 'Demo.Probe')
    );
    const status = host.querySelector('[data-ocu-source="reference-status"]') as HTMLElement;
    expect(status.getAttribute('role')).toBe('status');
    expect(status.textContent?.trim()).toBe('');
    expect(host.querySelector('pre[data-ocu-source="text"]')).toBeNull();
    expect(host.querySelector('[role="grid"]')).toBeNull();
    expect(paths).toHaveLength(1);
    await view('source');
    expect(frame()).toBeNull();
  });

  it('Story 19.9 AC3: a load the page did not start sets the class page again and says so; its own loads are counted off', async () => {
    // Mutation (Rule 19): the load counter ignores self-started loads (every load reads as the page's own) -> red.
    const { host, view, frame, settle: render } = await mount(CLASS_VIEWER, 'Demo.Probe.cls', CLASS_ROWS);
    await view('reference');
    const element = frame() as HTMLIFrameElement;
    const source = element.getAttribute('src');
    const status = () => host.querySelector('[data-ocu-source="reference-status"]')?.textContent?.trim();
    element.dispatchEvent(new Event('load'));
    await render();
    expect(status()).toBe('');
    // A link followed inside the frame: the frame navigates on its own and loads.
    element.setAttribute('src', '/csp/documatic/%25CSP.Documatic.cls?PAGE=CLASS&LIBRARY=HSCUSTOM&CLASSNAME=%25Library.Persistent');
    element.dispatchEvent(new Event('load'));
    await render();
    expect(element.getAttribute('src')).toBe(source);
    expect(status()).toBe(STRINGS.explorerClassReferenceRestored.replace('<class>', 'Demo.Probe'));
    // The restore's own load is the page's, so it sets nothing again.
    element.setAttribute('src', 'about:blank#kept');
    element.dispatchEvent(new Event('load'));
    await render();
    expect(element.getAttribute('src')).toBe('about:blank#kept');
    expect(frame()).toBe(element);
    // Mutation (Rule 19): the frame's removal keeps the status line -> a frame drawn again opens on the old sentence and this goes red.
    await view('source');
    await view('reference');
    expect(frame()).not.toBe(element);
    expect(status()).toBe('');
  });

  it('Story 19.9 AC3: a re-read in the same namespace keeps the frame without setting its address again, so a link followed afterwards is still restored', async () => {
    // Mutation (Rule 19): `syncReference` drops its once-per-frame-and-address return -> the re-read sets `src`
    // again and counts a load, the link's load is taken for the page's own, and this goes red.
    const mounted = await mount(CLASS_VIEWER, 'Demo.Probe.cls', CLASS_ROWS);
    await mounted.view('reference');
    const element = mounted.frame() as HTMLIFrameElement;
    const source = element.getAttribute('src');
    element.dispatchEvent(new Event('load'));
    await mounted.settle();
    await mounted.refresh.readNow();
    await mounted.settle();
    expect(mounted.paths).toHaveLength(2);
    expect(mounted.frame()).toBe(element);
    element.setAttribute('src', '/csp/documatic/%25CSP.Documatic.cls?PAGE=CLASS&LIBRARY=HSCUSTOM&CLASSNAME=%25Library.Persistent');
    element.dispatchEvent(new Event('load'));
    await mounted.settle();
    expect(element.getAttribute('src')).toBe(source);
    expect(mounted.host.querySelector('[data-ocu-source="reference-status"]')?.textContent?.trim()).toBe(
      STRINGS.explorerClassReferenceRestored.replace('<class>', 'Demo.Probe')
    );
  });

  it('Story 19.9 AC4: a namespace switch drops the frame until the new namespace answers, then loads it there; a refused read and a gone class draw none', async () => {
    // Mutation (Rule 19): `referenceSource` drops its `hasDocument` condition -> the gone class draws a frame and this goes red.
    const mounted = await mount(CLASS_VIEWER, 'Demo.Probe.cls', CLASS_ROWS);
    const { host, view, frame } = mounted;
    await view('reference');
    expect(frame()?.getAttribute('src')).toContain('&LIBRARY=HSCUSTOM&');
    mounted.hold();
    mounted.switchHeld('USER');
    expect(frame()).toBeNull();
    expect(host.querySelector('[data-ocu-source="header"]')).toBeNull();
    await mounted.release();
    expect(frame()?.getAttribute('src')).toBe(classReferenceUrl('USER', 'Demo.Probe.cls'));

    mounted.refuse();
    await mounted.refresh.readNow();
    await mounted.settle();
    expect(host.querySelector('[data-ocu-source="fault"]')).not.toBeNull();
    expect(frame()).toBeNull();

    const gone = await mount(CLASS_VIEWER, 'Demo.Probe.cls', CLASS_ROWS);
    await gone.view('reference');
    expect(gone.frame()).not.toBeNull();
    gone.remove();
    await gone.refresh.readNow();
    await gone.settle();
    expect(gone.host.querySelector('.ocu-data-table-empty-title')?.textContent?.trim()).toBe(STRINGS.explorerClassDocumentEmpty);
    expect(gone.frame()).toBeNull();

    const refused = await mount(CLASS_VIEWER, 'Demo.Probe.cls', CLASS_ROWS, false, 'USER');
    await refused.view('reference');
    await refused.switchTo('USER');
    expect(refused.host.querySelector('.ocu-data-table-refusal')).not.toBeNull();
    expect(refused.frame()).toBeNull();
  });

  it("Story 19.9 AC4: another namespace's answer still on screen draws no frame", async () => {
    // Mutation (Rule 19): `referenceSource` drops its namespace check -> HSCUSTOM's late answer draws a frame and this goes red.
    const mounted = await mount(CLASS_VIEWER, 'Demo.Probe.cls', CLASS_ROWS);
    await mounted.view('reference');
    mounted.hold();
    void mounted.refresh.readNow();
    mounted.switchHeld('USER');
    expect(mounted.frame()).toBeNull();
    await mounted.release();
    expect(mounted.host.querySelector('[data-ocu-source="header"]')).not.toBeNull();
    expect(mounted.frame()).toBeNull();
    await mounted.release();
    expect(mounted.frame()?.getAttribute('src')).toBe(classReferenceUrl('USER', 'Demo.Probe.cls'));
  });

  it('Story 19.9: classReferenceUrl names the class page alone, each value encoded, and nothing for any other shape', () => {
    expect(classReferenceUrl('USER', '%Library.String.CLS')).toBe(
      '/csp/documatic/%25CSP.Documatic.cls?PAGE=CLASS&SHOWCLASSONLY=1&LIBRARY=USER&CLASSNAME=%25Library.String'
    );
    expect(classReferenceUrl('%SYS', 'OcuProbe199.Doc')).toBe('/csp/documatic/%25CSP.Documatic.cls?PAGE=CLASS&SHOWCLASSONLY=1&LIBRARY=%25SYS&CLASSNAME=OcuProbe199.Doc');
    expect(classReferenceUrl('USER', 'a b')).toBeNull();
    expect(classReferenceUrl('x/y', 'Demo.Probe.cls')).toBeNull();
    for (const name of ['', '.cls', 'Demo..Probe', 'Demo.Probe.', '1Demo.Probe', 'Demo.%Probe', 'Demo.Probe&IRISPassword=SYS', 'Demo/Probe']) {
      expect(classReferenceUrl('USER', name), name).toBeNull();
    }
    for (const namespace of ['', 'USER&x=1', 'US ER', '%%SYS', 'N'.repeat(65)]) {
      expect(classReferenceUrl(namespace, 'Demo.Probe.cls'), namespace).toBeNull();
    }
    expect(classReferenceUrl('N'.repeat(64), 'Demo.Probe.cls')).not.toBeNull();
  });

  it('the state keeps an answer only for the name and form on screen', () => {
    const state = new SourceViewerState();
    expect(state.open('A.cls')).toBe(true);
    expect(state.open('A.cls')).toBe(false);
    const sent = state.criteria();
    expect(state.setView('xml')).toBe(true);
    state.applyAnswer(sent, documentOf({ name: 'A.cls', form: 'udl', available: true, content: ['x'] }), false);
    expect(state.document()).toBeNull();
    expect(state.setView('structure')).toBe(false);
    expect(state.criteria()).toEqual({ name: 'A.cls', form: 'xml' });
  });
});
