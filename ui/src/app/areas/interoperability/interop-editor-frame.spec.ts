import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { ScopeService } from '../../core/scope';
import { STRINGS } from '../../core/strings';
import { INTEROP_EDITORS, interopEditorSource, type InteropEditor } from '../../core/vendor-frame';
import { InteropEditorFrame } from './interop-editor-frame';

/**
 * `app-interop-editor-frame` over a `ScopeService` double (Story 20.13, AC4): one frame whose `src`
 * is the builder's answer and whose name is the editor's own string, carrying no `sandbox`, `allow`,
 * `srcdoc` or `credentialless` and no attribute beyond its class, marker, title and source; drawn only
 * while its namespace is the one on screen and the builder answers; a different element, never a new
 * address on the drawn one, when the editor, namespace, document or revision moves (Story 20.7, DW-2350),
 * and the address written once per element so nothing else reloads the editor; touching no tab storage; and adding
 * no listener to the frame or for a message. jsdom loads no frame, so only the element is
 * pinned here; `browser/interop-editor-frame.browser-spec.mjs` loads the real editors.
 */

const EDITORS: readonly InteropEditor[] = ['rule-editor', 'dtl-editor', 'bpl-editor'];

const TITLES: Readonly<Record<InteropEditor, string>> = {
  'rule-editor': 'Rule editor',
  'dtl-editor': 'DTL editor',
  'bpl-editor': 'BPL editor',
};

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 3; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

interface Inputs {
  readonly editor: string;
  readonly namespace: string;
  readonly document?: string;
}

async function mount(inputs: Inputs, scopeNamespace = 'HSCUSTOM') {
  TestBed.resetTestingModule();
  let current = scopeNamespace;
  const listeners = new Set<() => void>();
  TestBed.configureTestingModule({
    providers: [
      {
        provide: ScopeService,
        useValue: {
          namespace: () => current,
          subscribe: (listener: () => void) => {
            listeners.add(listener);
            return () => listeners.delete(listener);
          },
        } as unknown as ScopeService,
      },
    ],
  });
  const fixture = TestBed.createComponent(InteropEditorFrame);
  fixture.componentRef.setInput('editor', inputs.editor);
  fixture.componentRef.setInput('namespace', inputs.namespace);
  if (inputs.document !== undefined) fixture.componentRef.setInput('document', inputs.document);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  const host = fixture.nativeElement as HTMLElement;
  return {
    fixture,
    host,
    listeners,
    frames: () => Array.from(host.querySelectorAll('iframe')),
    frame: () => host.querySelector('iframe[data-ocu-source="interop-editor-frame"]') as HTMLIFrameElement | null,
    /** Move the scope as `src/main.ts` does, then let the component render. */
    scopeTo: async (next: string) => {
      current = next;
      for (const listener of [...listeners]) listener();
      await settle(fixture);
    },
    set: async (name: 'editor' | 'namespace' | 'document', value: string) => {
      fixture.componentRef.setInput(name, value);
      await settle(fixture);
    },
    /** Move the scope and the `namespace` input together, so the component renders once, at the new namespace. */
    moveTo: async (next: string) => {
      current = next;
      for (const listener of [...listeners]) listener();
      fixture.componentRef.setInput('namespace', next);
      await settle(fixture);
    },
  };
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

describe('app-interop-editor-frame', () => {
  it('Story 20.13 AC4: draws one frame per editor with the builder\'s source and the editor\'s own title, and nothing that loosens or reaches it', async () => {
    // Mutation (Rule 19): the template gains `sandbox=""` -> red.
    // Mutation (Rule 19): the title binding is removed -> red.
    for (const editor of EDITORS) {
      for (const named of ['', 'Demo.Probe.Thing']) {
        const { frames, frame } = await mount({ editor, namespace: 'HSCUSTOM', document: named });
        expect(frames().length, `${editor} draws one frame`).toBe(1);
        const element = frame() as HTMLIFrameElement;
        expect(element.getAttribute('src')).toBe(interopEditorSource(editor, 'HSCUSTOM', named));
        expect(element.getAttribute('src')).toBe(
          named === ''
            ? `/ui/interop/${editor}/index.html?$NAMESPACE=HSCUSTOM`
            : `/ui/interop/${editor}/index.html?$NAMESPACE=HSCUSTOM&${INTEROP_EDITORS[editor].parameter}=${named}`
        );
        expect(element.getAttribute('title')).toBe(TITLES[editor]);
        expect(element.getAttribute('title')).toBe(STRINGS[INTEROP_EDITORS[editor].titleKey]);
        for (const attribute of ['sandbox', 'allow', 'srcdoc', 'credentialless']) {
          expect(element.hasAttribute(attribute), `no ${attribute} on ${editor}`).toBe(false);
        }
        const names = element.getAttributeNames().filter((name) => !name.startsWith('_ng')).sort();
        expect(names, 'and no attribute beyond its own, so no listener attribute either').toEqual(['class', 'data-ocu-source', 'src', 'title']);
        expect(element.getAttribute('class')).toBe('ocu-interop-editor-frame');
      }
    }
  });

  it('Story 20.13 AC4: draws no frame for a source the builder refuses', async () => {
    const refused: Inputs[] = [
      { editor: 'schema-viewer', namespace: 'HSCUSTOM' },
      { editor: 'rule-editor', namespace: '' },
      { editor: 'rule-editor', namespace: 'X&Y=1' },
      { editor: 'dtl-editor', namespace: 'HSCUSTOM', document: 'a/b' },
      { editor: 'bpl-editor', namespace: 'HSCUSTOM', document: 'A&B=1' },
      { editor: 'bpl-editor', namespace: 'HSCUSTOM', document: '..' },
    ];
    for (const inputs of refused) {
      // The scope names the same namespace, so only the builder can refuse.
      const { frames, host } = await mount(inputs, inputs.namespace);
      expect(frames(), JSON.stringify(inputs)).toEqual([]);
      expect(host.querySelector('[src]'), 'and nothing carries an address').toBeNull();
    }
  });

  it('Story 20.13 AC4: draws only while its namespace is the one on screen, and loads the new namespace\'s editor once the scope arrives', async () => {
    // Mutation (Rule 19): the component draws while its namespace differs from the scope's -> red.
    const { frame, frames, scopeTo, set } = await mount({ editor: 'dtl-editor', namespace: 'USER', document: 'Demo.Probe.Thing' }, 'HSCUSTOM');
    expect(frames(), 'the read answered in USER while HSCUSTOM is on screen').toEqual([]);
    await scopeTo('USER');
    expect((frame() as HTMLIFrameElement).getAttribute('src')).toBe(interopEditorSource('dtl-editor', 'USER', 'Demo.Probe.Thing'));
    await scopeTo('HSCUSTOM');
    expect(frames(), 'the scope moved on, so the old namespace\'s document unloads').toEqual([]);
    await set('namespace', 'HSCUSTOM');
    expect((frame() as HTMLIFrameElement).getAttribute('src')).toBe(interopEditorSource('dtl-editor', 'HSCUSTOM', 'Demo.Probe.Thing'));
  });

  it('Story 20.7 AC4 (DW-2350): an editor or document change draws a different element with the new address, and detaches the old one, whose address is left as drawn', async () => {
    // Mutation (Rule 19): the template's `@for` tracks a constant key, so the element is kept -> red.
    const { frame, set } = await mount({ editor: 'bpl-editor', namespace: 'HSCUSTOM', document: 'Demo.One' });
    const first = frame() as HTMLIFrameElement;
    expect(first.getAttribute('src')).toBe(interopEditorSource('bpl-editor', 'HSCUSTOM', 'Demo.One'));
    await set('document', 'Demo.Two');
    const second = frame() as HTMLIFrameElement;
    expect(second, 'a new element').not.toBe(first);
    expect(first.isConnected, 'and the old one is detached').toBe(false);
    expect(first.getAttribute('src'), 'with the address it was drawn with').toBe(interopEditorSource('bpl-editor', 'HSCUSTOM', 'Demo.One'));
    expect(second.getAttribute('src')).toBe(interopEditorSource('bpl-editor', 'HSCUSTOM', 'Demo.Two'));
    await set('document', '');
    const third = frame() as HTMLIFrameElement;
    expect(third).not.toBe(second);
    expect(third.getAttribute('src')).toBe(interopEditorSource('bpl-editor', 'HSCUSTOM'));
    await set('editor', 'rule-editor');
    const fourth = frame() as HTMLIFrameElement;
    expect(fourth).not.toBe(third);
    expect(third.isConnected).toBe(false);
    expect(fourth.getAttribute('src')).toBe(interopEditorSource('rule-editor', 'HSCUSTOM'));
    expect(fourth.getAttribute('title')).toBe(TITLES['rule-editor']);
    await set('document', 'a b');
    expect(frame(), 'a document outside its shape withdraws the frame').toBeNull();
    expect(fourth.isConnected).toBe(false);
  });

  it('Story 20.7 AC4 (DW-2350): a namespace change draws a different element at the new namespace\'s address, and detaches the old one, whose address is left as drawn', async () => {
    // Mutation (Rule 19): the template's `@for` tracks a constant key, so the element is kept -> red.
    const { frame, frames, moveTo } = await mount({ editor: 'dtl-editor', namespace: 'HSCUSTOM', document: 'Demo.Probe.Thing' });
    const first = frame() as HTMLIFrameElement;
    // The scope and the input move in one render, so the frame is never withdrawn in between and only the key can replace it.
    await moveTo('USER');
    expect(frames().length, 'one frame').toBe(1);
    const second = frame() as HTMLIFrameElement;
    expect(second, 'a new element').not.toBe(first);
    expect(first.isConnected, 'and the old one is detached').toBe(false);
    expect(first.getAttribute('src'), 'with the address it was drawn with').toBe(interopEditorSource('dtl-editor', 'HSCUSTOM', 'Demo.Probe.Thing'));
    expect(second.getAttribute('src')).toBe(interopEditorSource('dtl-editor', 'USER', 'Demo.Probe.Thing'));
  });

  it('Story 20.7 AC4 (DW-2351): a revision change draws a new element at the same address, and writes each address once', async () => {
    // Mutation (Rule 19): the template's `@for` tracks the address alone, so the element is kept -> red.
    const writes: string[] = [];
    const original = Element.prototype.setAttribute;
    const spy = vi.spyOn(Element.prototype, 'setAttribute').mockImplementation(function (this: Element, name: string, value: string) {
      if (this instanceof HTMLIFrameElement && name === 'src') writes.push(value);
      return original.call(this, name, value);
    });
    try {
      const { fixture, frame } = await mount({ editor: 'dtl-editor', namespace: 'HSCUSTOM', document: 'Demo.One' });
      const first = frame() as HTMLIFrameElement;
      const address = interopEditorSource('dtl-editor', 'HSCUSTOM', 'Demo.One') as string;
      expect(first.getAttribute('src')).toBe(address);
      fixture.componentRef.setInput('revision', 1);
      await settle(fixture);
      const second = frame() as HTMLIFrameElement;
      expect(second, 'a new revision draws a new element').not.toBe(first);
      expect(first.isConnected).toBe(false);
      expect(second.getAttribute('src'), 'at the same address').toBe(address);
      expect(writes, 'each element has its address written once').toEqual([address, address]);
    } finally {
      spy.mockRestore();
    }
  });

  it('Story 20.13 AC4: writes the address once per distinct address, so nothing that leaves it as it was reloads the editor', async () => {
    // Mutation (Rule 19): the address is written twice for one draw (a second `setAttribute` of `src`) -> red.
    const writes: string[] = [];
    const original = Element.prototype.setAttribute;
    const spy = vi.spyOn(Element.prototype, 'setAttribute').mockImplementation(function (this: Element, name: string, value: string) {
      if (this instanceof HTMLIFrameElement && name === 'src') writes.push(value);
      return original.call(this, name, value);
    });
    try {
      const { fixture, frame, scopeTo, set } = await mount({ editor: 'dtl-editor', namespace: 'HSCUSTOM', document: 'Demo.One' });
      const one = interopEditorSource('dtl-editor', 'HSCUSTOM', 'Demo.One') as string;
      expect(writes, 'the first draw writes the address once').toEqual([one]);

      // A render, a scope notice and inputs that restate what the component already has: the editor must not reload.
      fixture.detectChanges();
      await settle(fixture);
      await scopeTo('HSCUSTOM');
      await set('document', 'Demo.One');
      await set('editor', 'dtl-editor');
      await set('namespace', 'HSCUSTOM');
      expect(writes, 'none of them writes it again').toEqual([one]);

      await set('document', 'Demo.Two');
      const two = interopEditorSource('dtl-editor', 'HSCUSTOM', 'Demo.Two') as string;
      expect(writes, 'a new address is one more write').toEqual([one, two]);

      // Withdrawn and drawn again is a new frame, and a new frame needs its address.
      const first = frame();
      await set('document', 'a b');
      expect(frame()).toBeNull();
      await set('document', 'Demo.Two');
      expect(frame(), 'a new element').not.toBe(first);
      expect(writes, 'with the address written on it').toEqual([one, two, two]);
    } finally {
      spy.mockRestore();
    }
  });

  it('Story 20.13 AC4: adds no listener to the frame and none for a message, through a mount, a change and a destroy', async () => {
    // Mutation (Rule 19): the template gains `(load)="x()"`, or the component gains a `window:message` host listener -> red.
    // Mutation (Rule 19): the component sets the frame's `onload` handler property -> red.
    const added: Array<{ target: EventTarget; type: string }> = [];
    // jsdom registers a handler property below these spies, so the frame's handler properties are read back.
    const handlerProperties = (element: HTMLIFrameElement | null) =>
      ['onload', 'onerror', 'onabort'].filter((name) => element !== null && (element as unknown as Record<string, unknown>)[name] !== null);
    const spies = [EventTarget.prototype, window].map((target) => {
      const original = target.addEventListener;
      return vi.spyOn(target, 'addEventListener').mockImplementation(function (
        this: EventTarget,
        type: string,
        listener: EventListenerOrEventListenerObject | null,
        options?: boolean | AddEventListenerOptions
      ) {
        added.push({ target: this, type });
        return original.call(this, type, listener, options);
      });
    });
    try {
      const { fixture, frame, set, scopeTo } = await mount({ editor: 'dtl-editor', namespace: 'HSCUSTOM', document: 'Demo.Probe.Thing' });
      expect(frame(), 'the frame is drawn while the spies are armed').not.toBeNull();
      expect(handlerProperties(frame()), 'no handler property on the frame').toEqual([]);
      await set('document', 'Demo.Other');
      expect(handlerProperties(frame()), 'nor after its address changes').toEqual([]);
      await scopeTo('USER');
      await scopeTo('HSCUSTOM');
      fixture.destroy();
      const lifecycle = added.slice();

      // The spies see what they are asked about: a listener on a frame and one on the window.
      const control = document.createElement('iframe');
      const noop = () => undefined;
      control.addEventListener('load', noop);
      window.addEventListener('resize', noop);
      window.removeEventListener('resize', noop);
      const seen = added.slice(lifecycle.length);
      expect(seen.some((entry) => entry.target === control && entry.type === 'load'), 'a listener on a frame is recorded').toBe(true);
      expect(seen.some((entry) => entry.target === window && entry.type === 'resize'), 'and one on the window').toBe(true);
      control.onload = noop;
      expect(handlerProperties(control), 'and the handler read sees a handler property').toEqual(['onload']);

      expect(
        lifecycle.filter((entry) => entry.target instanceof HTMLIFrameElement).map((entry) => entry.type),
        'nothing listens on the frame'
      ).toEqual([]);
      expect(lifecycle.filter((entry) => /^message/.test(entry.type)).map((entry) => entry.type), 'and nothing listens for a message').toEqual([]);
    } finally {
      for (const spy of spies) spy.mockRestore();
    }
  });

  it('Story 20.13 AC4: writes nothing to the tab\'s storage, and releases its scope subscription', async () => {
    const sentinel = 'ocupilot.test-sentinel-2013';
    sessionStorage.setItem(sentinel, 'kept');
    try {
      const snapshot = () => JSON.stringify(Object.keys(sessionStorage).sort().map((key) => [key, sessionStorage.getItem(key)]));
      const before = snapshot();
      const { fixture, listeners, frame, set, scopeTo } = await mount({ editor: 'rule-editor', namespace: 'HSCUSTOM', document: 'Demo.Rule' });
      expect(frame()).not.toBeNull();
      await set('document', 'Demo.Other');
      await scopeTo('USER');
      await scopeTo('HSCUSTOM');
      expect(snapshot(), 'the tab holds exactly the keys and values it held before').toBe(before);
      expect(listeners.size, 'the component subscribed to the scope').toBe(1);
      fixture.destroy();
      expect(listeners.size, 'and released it on destroy').toBe(0);
      expect(snapshot()).toBe(before);
    } finally {
      sessionStorage.removeItem(sentinel);
    }
  });
});
