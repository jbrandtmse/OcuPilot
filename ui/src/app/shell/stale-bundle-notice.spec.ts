import { ComponentFixture, TestBed } from '@angular/core/testing';
import { NavigationEnd, NavigationError, Router } from '@angular/router';
import { Subject } from 'rxjs';
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
 * A screen whose code cannot load surfaces as a router `NavigationError`, and the notice answers it
 * by asking the instance service to re-read the installed bundle (Story 20.29).
 *
 * Mutations (Rule 19), each applied to `stale-bundle-notice.ts`, observed red here alone, and
 * reverted: make the `stale` getter return `false` unconditionally -> every test that expects the
 * prompt goes red; make `chooseReload()` a no-op -> "asks the document to fetch itself again" goes
 * red; remove the `NavigationError` subscription -> the two navigation-failure tests go red; remove
 * the `onDestroy` unsubscribe -> "stops listening to the router when it is destroyed" goes red.
 *
 * The live region is its own node, mounted empty and filled when the strip is drawn: move the
 * `role="status"` span back inside the `@if` -> "the same live region node, mounted empty, holds
 * the sentence once the identity flips" goes red.
 */
class StubInstance {
  private identity = '';
  private readonly listeners = new Set<() => void>();
  rechecks = 0;
  /** The identity a re-check will find the instance naming, or `null` when it finds no change. */
  recheckFinds: string | null = null;

  recheckBuild(): Promise<void> {
    this.rechecks += 1;
    if (this.recheckFinds !== null) this.publish(this.recheckFinds);
    return Promise.resolve();
  }

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
  let routerEvents: Subject<unknown>;
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

  const liveRegion = (): HTMLElement | null =>
    fixture.nativeElement.querySelector('[role="status"]');

  function mount(): void {
    instance = new StubInstance();
    routerEvents = new Subject<unknown>();
    TestBed.configureTestingModule({
      providers: [
        { provide: InstanceService, useValue: instance as unknown as InstanceService },
        { provide: Router, useValue: { events: routerEvents } },
      ],
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

  it('renders the reload prompt when the instance names a bundle this tab did not load, with no role of its own', () => {
    loadBundle('main-AAAA1111.js');
    mount();
    instance.publish('main-BBBB2222.js');
    fixture.detectChanges();

    const strip = notice();
    expect(strip).not.toBeNull();
    expect(strip?.getAttribute('role')).toBeNull();
    expect(strip?.textContent).toContain(STRINGS.staleBundleNotice);
    expect(liveRegion()?.getAttribute('role')).toBe('status');
    const reload = strip?.querySelector('button');
    expect(reload?.textContent?.trim()).toBe(STRINGS.actionReload);
  });

  it('the same live region node, mounted empty, holds the sentence once the identity flips', () => {
    loadBundle('main-AAAA1111.js');
    mount();
    const region = liveRegion();
    expect(region).not.toBeNull();
    expect(region?.textContent?.trim()).toBe('');
    expect(notice()).toBeNull();

    instance.publish('main-BBBB2222.js');
    fixture.detectChanges();
    expect(liveRegion()).toBe(region);
    expect(region?.textContent?.trim()).toBe(STRINGS.staleBundleNotice);

    instance.publish('main-AAAA1111.js');
    fixture.detectChanges();
    expect(liveRegion()).toBe(region);
    expect(region?.textContent?.trim()).toBe('');
  });

  it('draws neither the strip nor the sentence while the shell holds it back, and both once it lets go', () => {
    loadBundle('main-AAAA1111.js');
    mount();
    fixture.componentRef.setInput('shown', false);
    instance.publish('main-BBBB2222.js');
    fixture.detectChanges();
    expect(notice()).toBeNull();
    expect(liveRegion()?.textContent?.trim()).toBe('');

    fixture.componentRef.setInput('shown', true);
    fixture.detectChanges();
    expect(notice()).not.toBeNull();
    expect(liveRegion()?.textContent?.trim()).toBe(STRINGS.staleBundleNotice);
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

  it('re-checks the installed bundle when a navigation fails, and for no other router event', () => {
    loadBundle('main-AAAA1111.js');
    mount();
    routerEvents.next(new NavigationEnd(1, '/ocupilot/a', '/ocupilot/a'));
    expect(instance.rechecks).toBe(0);

    routerEvents.next(new NavigationError(2, '/ocupilot/b', new Error('Failed to fetch dynamically imported module')));
    expect(instance.rechecks).toBe(1);
  });

  it('shows the prompt when the re-check finds another bundle installed, and leaves it off when it finds the same one', () => {
    loadBundle('main-AAAA1111.js');
    mount();
    instance.recheckFinds = 'main-AAAA1111.js';
    routerEvents.next(new NavigationError(1, '/ocupilot/b', new Error('chunk')));
    fixture.detectChanges();
    expect(instance.rechecks).toBe(1);
    expect(notice()).toBeNull();

    instance.recheckFinds = 'main-BBBB2222.js';
    routerEvents.next(new NavigationError(2, '/ocupilot/b', new Error('chunk')));
    fixture.detectChanges();
    expect(notice()).not.toBeNull();
  });

  it('stops listening to the router when it is destroyed', () => {
    loadBundle('main-AAAA1111.js');
    mount();
    fixture.destroy();
    routerEvents.next(new NavigationError(1, '/ocupilot/b', new Error('chunk')));
    expect(instance.rechecks).toBe(0);
  });
});
