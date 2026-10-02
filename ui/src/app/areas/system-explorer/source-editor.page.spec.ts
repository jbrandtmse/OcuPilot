import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { savedLine, type ReadBack } from '../../core/read-back';
import { ScopeService } from '../../core/scope';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ScreenActionHandler, type ActionRefusal, type ActionSink, type ActionValues } from '../../shell/screen-action-handler';
import { ARCHETYPE_PAGES, DESCRIPTOR_PAGES, resolveScreenPage } from '../../shell/screen-outlet';
import { OBJECT_ONLY_REASON } from './document-viewer.store';
import { SourceEditorPage } from './source-editor.page';

/**
 * The class and routine editors over stubs of what the instance supplies -- the URL's screen, the
 * viewer's read and the list's `save` action (Story 19.3). The real store, the real `FormDirty`, the
 * real dialog and the real template run, so the assertions are about rendered DOM: the text read
 * through the viewer's own read, Save drawn `aria-disabled` while the text is empty, unchanged or
 * being saved, the unsaved-changes question, a landed Save's "Saved", output and re-read, a refused
 * Save keeping the person's text, unsaved text kept across a namespace switch, a document with no
 * source to edit, the routine editor's own read and list, and where Cancel goes.
 */

const CLASS_EDITOR = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ExplorerClassEditor') as ScreenDeclaration;

const ROUTINE_EDITOR = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ExplorerRoutineEditor') as ScreenDeclaration;

const NAME = 'Demo.Probe.cls';

const FIRST = ['Class Demo.Probe Extends %RegisteredObject', '{', '}'];

const SECOND = ['Class Demo.Probe Extends %RegisteredObject', '{', '', 'Parameter P = 1;', '', '}', ''];

const NOTHING_SENT: ReadBack = { verdict: 'nothingSent', fields: [], written: [], reason: '' };

interface SaveCall {
  readonly descriptor: string;
  readonly actionId: string;
  readonly target: string;
  readonly values: ActionValues | undefined;
  readonly scope: string | undefined;
}

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

interface Mounted {
  readonly fixture: ComponentFixture<SourceEditorPage>;
  readonly host: HTMLElement;
  readonly formDirty: FormDirty;
  readonly router: Router;
  readonly reads: { path: string; scope: string | null | undefined }[];
  readonly saves: SaveCall[];
  /** What the next read answers: the document's lines and version, whether its source is kept, or `'gone'`. */
  answer: { lines: readonly string[]; modified: string; available?: boolean; reason?: string } | 'gone';
  /** What the next save answers: applied with output, or refused with a sentence. */
  saveAnswer: { applied: true; output: unknown } | { applied: false; refusal: string; code?: string; detail?: Record<string, unknown> };
  /** Switch the scope's namespace, as the shell's namespace switch does. */
  switchNamespace(namespace: string): void;
}

async function mount(editor: ScreenDeclaration = CLASS_EDITOR, name = NAME): Promise<Mounted> {
  TestBed.resetTestingModule();
  const formDirty = new FormDirty();
  const mounted = {
    reads: [] as { path: string; scope: string | null | undefined }[],
    saves: [] as SaveCall[],
    answer: { lines: FIRST, modified: '2026-10-02 09:00:00.120' } as Mounted['answer'],
    saveAnswer: { applied: true, output: null } as Mounted['saveAnswer'],
  };
  let lastRefusal: ActionRefusal | null = null;
  let lastOutput: unknown = null;
  let lastReadBack: ReadBack | null = null;
  const scope = { namespace: 'USER', listeners: new Set<() => void>() };
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      mounted.reads.push({ path, scope: init.scope });
      const answer = mounted.answer;
      if (answer === 'gone') {
        return { kind: 'error', status: 404, code: 'PORT.NOTFOUND', reason: 'This namespace holds no document by that name.', detail: null };
      }
      const document = { name, form: 'udl', available: answer.available ?? true, reason: answer.reason ?? '', content: answer.lines, modified: answer.modified, database: 'USER', generates: [] };
      return { kind: 'ok', status: 200, body: { fields: [], rows: [], truncated: false, document } as T };
    },
  };
  const handler = {
    sendFor: async (descriptor: string, actionId: string, target: string, values?: ActionValues, sink?: ActionSink, scope?: string) => {
      mounted.saves.push({ descriptor, actionId, target, values, scope });
      sink?.setRefusal('');
      const outcome = mounted.saveAnswer;
      if (!outcome.applied) {
        lastRefusal = { reason: outcome.refusal, code: outcome.code ?? 'EXPLORER.DOCUMENT.CONFLICT', violations: [], detail: outcome.detail ?? null };
        lastOutput = null;
        lastReadBack = null;
        sink?.setRefusal(outcome.refusal);
        return false;
      }
      lastRefusal = null;
      lastOutput = outcome.output;
      lastReadBack = NOTHING_SENT;
      return true;
    },
    lastRefusal: () => lastRefusal,
    lastOutput: () => lastOutput,
    lastReadBack: () => lastReadBack,
  };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: NavigationService, useValue: { screenForUrl: () => editor } as unknown as NavigationService },
      { provide: ScreenActionHandler, useValue: handler as unknown as ScreenActionHandler },
      { provide: FormDirty, useValue: formDirty },
      { provide: OverlayStack, useValue: new OverlayStack() },
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
  await router.navigateByUrl(`/${editor.route}/${encodeEntityId(name)}?ns=USER`);
  const fixture = TestBed.createComponent(SourceEditorPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  const switchNamespace = (namespace: string) => {
    scope.namespace = namespace;
    for (const listener of [...scope.listeners]) listener();
  };
  return Object.assign(mounted, { fixture, host: fixture.nativeElement as HTMLElement, formDirty, router, switchNamespace }) as Mounted;
}

function textArea(host: HTMLElement): HTMLTextAreaElement {
  return host.querySelector('[data-ocu-editor="text"]') as HTMLTextAreaElement;
}

function saveButton(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('[data-ocu-editor="save"]') as HTMLButtonElement;
}

async function type(mounted: Mounted, text: string): Promise<void> {
  const area = textArea(mounted.host);
  area.value = text;
  area.dispatchEvent(new Event('input'));
  await settle(mounted.fixture);
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

describe('the class and routine editors', () => {
  it("opens the document's text through the viewer's own read, with its name and version, Save unavailable while unchanged", async () => {
    const { host, reads } = await mount();
    expect(reads).toEqual([{ path: '/api/ocupilot/screens/explorer.class/read?maxRows=1&name=Demo.Probe.cls&form=udl', scope: 'USER' }]);
    const area = textArea(host);
    expect(area.value).toBe(FIRST.join('\n'));
    expect(area.getAttribute('aria-label')).toBe(STRINGS.explorerEditorTextLabel.replace('<name>', NAME));
    expect(area.getAttribute('spellcheck')).toBe('false');
    expect(area.getAttribute('wrap')).toBe('off');
    expect(area.classList.contains('ocu-source-text')).toBe(true);
    expect(host.querySelector('[data-ocu-editor="header"]')?.textContent).toContain(NAME);
    expect(host.querySelector('[data-ocu-editor="modified"]')?.textContent?.trim()).toBe('2026-10-02 09:00:00.120');
    expect(saveButton(host).getAttribute('aria-disabled')).toBe('true');
    expect((host.querySelector('[data-ocu-editor="compile"]') as HTMLInputElement).checked).toBe(true);
    expect(host.querySelector('[data-ocu-editor="output"]')).toBeNull();
  });

  it('marks the form dirty while the text differs, and the guard asks "Leave without saving?" before any navigation', async () => {
    const mounted = await mount();
    const { host, formDirty, fixture } = mounted;
    await type(mounted, `${FIRST.join('\n')}\n// changed`);
    expect(formDirty.dirty()).toBe(true);
    expect(saveButton(host).getAttribute('aria-disabled')).toBe('false');
    const leaving = formDirty.requestLeave();
    await settle(fixture);
    expect(document.body.textContent).toContain(STRINGS.formLeaveWithoutSaving);
    formDirty.answer(false);
    expect(await leaving).toBe(false);
    await settle(fixture);
    expect(textArea(host).value).toBe(`${FIRST.join('\n')}\n// changed`);
    await type(mounted, FIRST.join('\n'));
    expect(formDirty.dirty()).toBe(false);
    expect(saveButton(host).getAttribute('aria-disabled')).toBe('true');
    expect(await formDirty.requestLeave()).toBe(true);
  });

  it('draws Save unavailable while the text is empty, and sends nothing then', async () => {
    const mounted = await mount();
    await type(mounted, '');
    expect(saveButton(mounted.host).getAttribute('aria-disabled')).toBe('true');
    saveButton(mounted.host).click();
    await settle(mounted.fixture);
    expect(mounted.saves).toEqual([]);
  });

  it("sends the text, the version read and the compile choice to the list's save in the namespace it opened in, then shows Saved, the output and the re-read text", async () => {
    const mounted = await mount();
    const { host, formDirty } = mounted;
    const typed = `${FIRST.join('\n')}\n`;
    await type(mounted, typed);
    mounted.saveAnswer = { applied: true, output: { lines: ['Compiling class Demo.Probe', 'Compilation finished successfully'], errors: false } };
    mounted.answer = { lines: SECOND, modified: '2026-10-02 09:05:00.450' };
    saveButton(host).click();
    await settle(mounted.fixture);
    expect(mounted.saves).toEqual([
      {
        descriptor: 'OcuPilot.Screen.Descriptor.ExplorerClassList',
        actionId: 'save',
        target: NAME,
        values: { content: typed, version: '2026-10-02 09:00:00.120', Compile: 'true' },
        scope: 'USER',
      },
    ]);
    expect(host.querySelector('[data-ocu-editor="status"]')?.textContent?.trim()).toBe(savedLine(NOTHING_SENT));
    expect(host.querySelector('[data-ocu-editor="output"]')?.textContent).toBe('Compiling class Demo.Probe\nCompilation finished successfully');
    expect(host.querySelector('[data-ocu-editor="output"]')?.getAttribute('aria-label')).toBe(STRINGS.explorerOutputLabel);
    expect(textArea(host).value).toBe(SECOND.join('\n'));
    expect(host.querySelector('[data-ocu-editor="modified"]')?.textContent?.trim()).toBe('2026-10-02 09:05:00.450');
    expect(formDirty.dirty()).toBe(false);
    expect(saveButton(host).getAttribute('aria-disabled')).toBe('true');
    expect(mounted.reads.length).toBe(2);
  });

  it('sends Compile false when "Compile after saving" is unchecked', async () => {
    const mounted = await mount();
    const box = mounted.host.querySelector('[data-ocu-editor="compile"]') as HTMLInputElement;
    box.checked = false;
    box.dispatchEvent(new Event('change'));
    await type(mounted, 'Class Demo.Probe Extends %RegisteredObject\n{\n}\n');
    saveButton(mounted.host).click();
    await settle(mounted.fixture);
    expect(mounted.saves[0]?.values?.['Compile']).toBe('false');
  });

  it('keeps unsaved text across a namespace switch and saves it where it was read, and re-reads clean text in the new namespace', async () => {
    const mounted = await mount();
    const typed = `${FIRST.join('\n')}\n// mine`;
    await type(mounted, typed);
    mounted.switchNamespace('HSCUSTOM');
    await settle(mounted.fixture);
    expect(mounted.reads.length).toBe(1);
    expect(textArea(mounted.host).value).toBe(typed);
    expect(mounted.formDirty.dirty()).toBe(true);
    saveButton(mounted.host).click();
    await settle(mounted.fixture);
    expect(mounted.saves.map((save) => save.scope)).toEqual(['USER']);
    expect(mounted.reads.map((read) => read.scope)).toEqual(['USER', 'USER']);
    mounted.switchNamespace('SAMPLES');
    await settle(mounted.fixture);
    expect(mounted.reads.map((read) => read.scope)).toEqual(['USER', 'USER', 'SAMPLES']);
  });

  it("keeps the person's text and shows the envelope's sentence when the save is refused", async () => {
    const mounted = await mount();
    const { host, formDirty } = mounted;
    const typed = `${FIRST.join('\n')}\n// mine`;
    await type(mounted, typed);
    mounted.saveAnswer = { applied: false, refusal: STRINGS.explorerDocumentConflict };
    saveButton(host).click();
    await settle(mounted.fixture);
    const banner = host.querySelector('[data-ocu-editor="refusal"]') as HTMLElement;
    expect(banner.getAttribute('role')).toBe('alert');
    expect(banner.textContent?.trim()).toBe(STRINGS.explorerDocumentConflict);
    expect(textArea(host).value).toBe(typed);
    expect(formDirty.dirty()).toBe(true);
    expect(host.querySelector('[data-ocu-editor="status"]')?.textContent?.trim()).toBe('');
    expect(mounted.reads.length).toBe(1);
  });

  it('names the pair a Save refused for want of a privilege lacks', async () => {
    const mounted = await mount();
    await type(mounted, `${FIRST.join('\n')}\n`);
    mounted.saveAnswer = { applied: false, refusal: 'This account does not hold the privilege this request requires.', code: 'AUTH.NOPRIVILEGE', detail: { failedPair: '%DB_USER:WRITE' } };
    saveButton(mounted.host).click();
    await settle(mounted.fixture);
    expect(mounted.host.querySelector('[data-ocu-editor="refusal"]')?.textContent?.trim()).toBe(
      STRINGS.privilegeDeniedAction.replace('<resource>', '%DB_USER:WRITE').replace('<action>', STRINGS.explorerEditorRefusedAction)
    );
  });

  it("shows the viewer's own sentence and no text area for a document the namespace no longer holds", async () => {
    const mounted = await mount();
    mounted.answer = 'gone';
    await mounted.router.navigateByUrl(`/${CLASS_EDITOR.route}/${encodeEntityId('Demo.Other.cls')}?ns=USER`);
    await settle(mounted.fixture);
    expect(mounted.host.querySelector('[data-ocu-editor="gone"]')?.textContent?.trim()).toBe(STRINGS.explorerClassDocumentEmpty);
    expect(textArea(mounted.host)).toBeNull();
  });

  it("shows the viewer's own sentence and no text area for a document whose source the instance does not keep", async () => {
    const mounted = await mount();
    for (const [name, reason, sentence] of [
      ['Demo.ObjectOnly.cls', OBJECT_ONLY_REASON, STRINGS.explorerViewerObjectOnly],
      ['Demo.NoSource.cls', '', STRINGS.explorerSourceNotAvailable],
    ] as const) {
      mounted.answer = { lines: [], modified: '2026-10-02 09:00:00.120', available: false, reason };
      await mounted.router.navigateByUrl(`/${CLASS_EDITOR.route}/${encodeEntityId(name)}?ns=USER`);
      await settle(mounted.fixture);
      expect(mounted.host.querySelector('[data-ocu-editor="unavailable"]')?.textContent?.trim()).toBe(sentence);
      expect(textArea(mounted.host)).toBeNull();
    }
    expect(mounted.saves).toEqual([]);
  });

  it("renders the routine editor too, reading through the routine viewer's read and saving through the Routines list", async () => {
    for (const editor of [CLASS_EDITOR, ROUTINE_EDITOR]) {
      expect(resolveScreenPage(DESCRIPTOR_PAGES, ARCHETYPE_PAGES, editor.descriptor, editor.archetype)).toBe(SourceEditorPage);
    }
    const mounted = await mount(ROUTINE_EDITOR, 'Demo.Probe.mac');
    expect(mounted.reads[0]?.path).toBe('/api/ocupilot/screens/explorer.routine/read?maxRows=1&name=Demo.Probe.mac&form=udl');
    await type(mounted, 'ROUTINE Demo.Probe\n ; changed');
    saveButton(mounted.host).click();
    await settle(mounted.fixture);
    expect(mounted.saves.map((save) => `${save.descriptor} ${save.target}`)).toEqual(['OcuPilot.Screen.Descriptor.ExplorerRoutineList Demo.Probe.mac']);
    mounted.answer = 'gone';
    await mounted.router.navigateByUrl(`/${ROUTINE_EDITOR.route}/${encodeEntityId('Demo.Other.mac')}?ns=USER`);
    await settle(mounted.fixture);
    expect(mounted.host.querySelector('[data-ocu-editor="gone"]')?.textContent?.trim()).toBe(STRINGS.explorerRoutineDocumentEmpty);
  });

  it("Cancel returns to the document's viewer in the editor's namespace", async () => {
    const mounted = await mount();
    (mounted.host.querySelector('[data-ocu-editor="cancel"]') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(mounted.router.url).toBe(`/system-explorer/classes/document/${encodeEntityId(NAME)}?ns=USER`);
  });
});
