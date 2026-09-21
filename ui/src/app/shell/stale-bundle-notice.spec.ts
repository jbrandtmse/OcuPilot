import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { InstanceService } from '../core/instance';
import { STRINGS } from '../core/strings';
import { StaleBundleNotice } from './stale-bundle-notice';

/**
 * The stale-bundle prompt's own render logic (Story 15.3, DW-3), which until now had no jsdom
 * host: `about-help-links.browser-spec.mjs` covers its render, role, copy, self-reload refusal
 * and the Reload click against a real deployed pair of bundles, and `isStale`/`bundleIdentity`
 * are unit-tested in `about.test.mjs`, but nothing pinned the component's own wiring of the two
 * -- the constructor's `InstanceService` subscription into the `stale` getter, and the getter
 * into `chooseReload()` -- at this faster, host-free tier.
 *
 * `bundleIdentity()` (imported from `core/build-identity`) takes no injectable seam: it reads
 * `document.querySelectorAll('script[src]')` directly, so this spec plants and removes its own
 * `<script src="main-*.js">` in the real `document` to name "the bundle this tab loaded", the
 * same shape `about.test.mjs`'s `scriptSource()` fixture exercises without a document at all.
 *
 * Mutations (Rule 19), each applied to `stale-bundle-notice.ts`, observed red here alone, and
 * reverted: make the `stale` getter return `false` unconditionally -> the two "renders" tests and
 * "reacts to a later instance update" go red (3 of 5); make `chooseReload()` a no-op -> "asks the
 * document to fetch itself again" goes red (1 of 5).
 */
class StubInstance {
  private identity = '';
  private readonly listeners = new Set<() => void>();

  buildIdentity(): string {
    return this.identity;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  /** Simulates the settle the shell already runs on every `/instance` read. */
  publish(identity: string): void {
    this.identity = identity;
    for (const listener of this.listeners) listener();
  }
}

describe('the stale-bundle notice', () => {
  let fixture: ComponentFixture<StaleBundleNotice>;
  let instance: StubInstance;
  const planted: HTMLElement[] = [];
  const plantedScripts: HTMLElement[] = [];

  /** Names "the bundle this tab loaded" for `bundleIdentity()`'s own document read. */
  function loadBundle(name: string): void {
    const script = document.createElement('script');
    script.src = name;
    document.head.appendChild(script);
    plantedScripts.push(script);
  }

  const notice = (): HTMLElement | null =>
    fixture.nativeElement.querySelector('.ocu-stale-bundle');

  function mount(): void {
    instance = new StubInstance();
    TestBed.configureTestingModule({
      providers: [{ provide: InstanceService, useValue: instance as unknown as InstanceService }],
    });
    fixture = TestBed.createComponent(StaleBundleNotice);
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
    fixture.detectChanges();
  }

  beforeEach(() => {
    TestBed.resetTestingModule();
  });

  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
    for (const script of plantedScripts.splice(0)) script.remove();
  });

  it('renders nothing while the instance names no bundle -- absence is not a mismatch', () => {
    loadBundle('main-AAAA1111.js');
    mount();
    expect(notice()).toBeNull();
  });

  it('renders nothing when the instance names the very bundle this tab loaded', () => {
    loadBundle('main-AAAA1111.js');
    mount();
    instance.publish('main-AAAA1111.js');
    fixture.detectChanges();
    expect(notice()).toBeNull();
  });

  it('renders the polite reload prompt when the instance names a bundle this tab did not load', () => {
    loadBundle('main-AAAA1111.js');
    mount();
    instance.publish('main-BBBB2222.js');
    fixture.detectChanges();

    const region = notice();
    expect(region).not.toBeNull();
    expect(region?.getAttribute('role')).toBe('status');
    expect(region?.textContent).toContain(STRINGS.staleBundleNotice);
    const reload = region?.querySelector('button');
    expect(reload?.textContent?.trim()).toBe(STRINGS.actionReload);
  });

  it('reacts to a later instance update -- the prompt is not decided only at construction', () => {
    loadBundle('main-AAAA1111.js');
    mount();
    instance.publish('main-AAAA1111.js');
    fixture.detectChanges();
    expect(notice()).toBeNull();

    instance.publish('main-BBBB2222.js');
    fixture.detectChanges();
    expect(notice()).not.toBeNull();
  });

  it('Reload asks the document to fetch itself again, and never on its own', () => {
    loadBundle('main-AAAA1111.js');
    mount();
    instance.publish('main-BBBB2222.js');
    fixture.detectChanges();

    // jsdom's `Location.reload` is an own, non-configurable property, so `vi.spyOn` cannot wrap
    // it in place; the whole `location` object is swapped for one that can be spied on instead.
    const originalLocation = window.location;
    const reload = vi.fn();
    Object.defineProperty(window, 'location', {
      configurable: true,
      value: { ...originalLocation, reload },
    });
    try {
      expect(reload).not.toHaveBeenCalled();
      notice()?.querySelector('button')?.click();
      expect(reload).toHaveBeenCalledTimes(1);
    } finally {
      Object.defineProperty(window, 'location', { configurable: true, value: originalLocation });
    }
  });
});
