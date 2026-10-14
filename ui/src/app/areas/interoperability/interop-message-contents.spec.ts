import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import type { Fault } from '../../core/fault';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { InteropMessageContents } from './interop-message-contents';

/**
 * The message Contents tab's block (Story 20.9, AD-11): each state of the read draws its own block under `data-ocu-contents`, the
 * rows are one `pre` of text lines that is never markup, and a truncated read says so above it. The read itself is
 * `list-page.spec.ts`'s, so the framework is a stand-in the spec drives and the store is the real one.
 */

const DESCRIPTOR = 'OcuPilot.Screen.Descriptor.InteropMessageContentsTab';

const SCREEN = SCREENS.find((entry) => entry.descriptor === DESCRIPTOR) as ScreenDeclaration;

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

const planted: HTMLElement[] = [];

function mount() {
  TestBed.resetTestingModule();
  const refresh = new FakeRefresh();
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  const store: ScreenStore = stores.for(DESCRIPTOR, []);
  TestBed.configureTestingModule({
    providers: [
      { provide: RefreshService, useValue: refresh as unknown as RefreshService },
      { provide: ScopeService, useValue: { namespace: () => 'HSCUSTOM', subscribe: () => () => {} } as unknown as ScopeService },
    ],
  });
  const fixture = TestBed.createComponent(InteropMessageContents);
  fixture.componentRef.setInput('screen', SCREEN);
  fixture.componentRef.setInput('store', store);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  const host = fixture.nativeElement as HTMLElement;
  return {
    refresh,
    store,
    host,
    block: (name: string) => host.querySelector(`[data-ocu-contents="${name}"]`),
    answer: (texts: string[], truncated = false) => {
      store.applyTick(
        texts.map((text, index) => ({ Message: '7', Line: index + 1, Text: text })),
        truncated,
        '',
        new Date()
      );
      refresh.loaded = true;
      refresh.notify();
      fixture.detectChanges();
    },
    redraw: () => {
      refresh.notify();
      fixture.detectChanges();
    },
  };
}

describe('the message Contents block', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  // Mutation (Rule 19): make `showSkeleton` answer false -> this goes red.
  it('draws skeleton bars in an aria-busy region until the first answer, and nothing else', () => {
    const page = mount();
    expect(page.block('skeleton')).not.toBeNull();
    expect(page.host.querySelector('.ocu-message-contents-frame')?.getAttribute('aria-busy')).toBe('true');
    expect(page.block('text')).toBeNull();
    expect(page.block('empty')).toBeNull();
    expect(page.block('fault')).toBeNull();
  });

  // Mutation (Rule 19): drop the `isBannerFault` test from `showRefusal` -> the connectivity-banner leg goes red.
  it('draws a refusal the connectivity banner has no copy for, with Retry, in place of the skeleton', () => {
    const page = mount();
    page.refresh.failure = { kind: 'refused', status: 403, code: null, path: '/screens/x/read' };
    page.redraw();
    const fault = page.block('fault');
    expect(fault).not.toBeNull();
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
  it('draws the screen\'s empty sentence when the answer holds no row', () => {
    const page = mount();
    page.answer([]);
    expect(page.block('empty')?.textContent).toContain(STRINGS.interopMessageContentsEmpty);
    expect(page.block('text')).toBeNull();
    expect(page.block('skeleton')).toBeNull();
  });

  // Mutation (Rule 19): render the text through `[innerHTML]` instead of interpolation -> the markup is parsed, the text differs and
  // this goes red.
  it('draws the rows as one block of text lines, a line holding markup as text, labelled and focusable', () => {
    const page = mount();
    page.answer(['<StringRequest>', '  <script>alert(1)</script> <&>', '</StringRequest>']);
    const text = page.block('text') as HTMLElement;
    expect(text.tagName).toBe('PRE');
    expect(text.classList.contains('ocu-message-contents')).toBe(true);
    expect(text.getAttribute('tabindex')).toBe('0');
    expect(text.getAttribute('aria-label')).toBe(STRINGS.interopMessageContentsLabel);
    expect(text.getAttribute('role')).toBe('region');
    expect(text.textContent).toBe('<StringRequest>\n  <script>alert(1)</script> <&>\n</StringRequest>');
    expect(text.querySelector('script')).toBeNull();
    expect(text.children.length).toBe(0);
    expect(page.host.querySelectorAll('pre').length).toBe(1);
    expect(page.block('cut')).toBeNull();
    expect(page.host.querySelector('input, textarea, [contenteditable]')).toBeNull();
    expect(page.host.querySelector('.ocu-message-contents-frame')?.getAttribute('aria-busy')).toBeNull();
  });

  // Mutation (Rule 19): make `cut` answer false -> this goes red.
  it('says the rest of a long message is cut above its text when the read truncated', () => {
    const page = mount();
    page.answer(['first part'], true);
    expect(page.block('cut')?.textContent).toBe(STRINGS.interopMessageContentsCut);
    expect(page.block('text')?.textContent).toBe('first part');
    const frame = page.host.querySelector('.ocu-message-contents-frame') as HTMLElement;
    expect(Array.from(frame.children).map((child) => child.getAttribute('data-ocu-contents'))).toEqual(['cut', 'text']);
  });

  // Mutation (Rule 19): drop the rows whose `Text` is empty from `text` -> this goes red.
  it('keeps an empty line an empty line, so the block reads as the message does', () => {
    const page = mount();
    page.answer(['alpha', '', 'gamma', '']);
    expect(page.block('text')?.textContent).toBe('alpha\n\ngamma\n');
    expect(page.block('empty')).toBeNull();
  });

  // Mutation (Rule 19): draw `store.data()` in `text` instead of the store's view -> this goes red.
  it('draws the lines the command bar\'s filter and sort leave, as the table and the agent\'s context do', () => {
    const page = mount();
    page.answer(['MSH|header', 'PID|patient', 'PV1|visit', 'PID|second']);
    page.store.setFilter('PID');
    page.redraw();
    expect(page.block('text')?.textContent).toBe('PID|patient\nPID|second');
    page.store.setFilter('');
    page.store.setDirection('desc');
    page.redraw();
    expect(page.block('text')?.textContent).toBe('PID|second\nPV1|visit\nPID|patient\nMSH|header');
  });

  // Mutation (Rule 19): drop the `descriptor` comparison from `boundHere` -> this goes red.
  it('draws the skeleton while the framework is bound to another screen', () => {
    const page = mount();
    page.answer(['line']);
    page.refresh.bound = 'OcuPilot.Screen.Descriptor.InteropMessageHeaderTab';
    page.redraw();
    expect(page.block('skeleton')).not.toBeNull();
    expect(page.block('text')).toBeNull();
  });
});
