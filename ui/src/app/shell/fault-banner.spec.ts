import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { beforeEach, describe, expect, it } from 'vitest';

import { ConnectivityService } from '../core/connectivity';
import type { Fault, FaultKind } from '../core/fault';
import { NavigationService, type Verdict } from '../core/navigation';
import type { ScreenDeclaration } from '../core/screens.generated';
import { STRINGS } from '../core/strings';
import { screenDeclaration } from '../testing/screen-declaration';
import { FaultBanner } from './fault-banner';

/**
 * The connectivity banner's rendered contract (EXPERIENCE.md `:436`, `:438`).
 *
 * **jsdom computes no layout**, so nothing here measures anything. That the strip is
 * full-width, that it sits at the top of the shell without overlaying the header or the status
 * bar, and that its error pair meets contrast in both token sets are the lead's browser
 * measurement (DW-159 routed the harness to 1.17) -- not claims this file makes. What it pins
 * is which fault draws which sentence, which controls come with it, and what each one does.
 */

const ALLOWED: Verdict = { allowed: true, failedPair: '' };

function screen(route: string, entityType: string): ScreenDeclaration {
  return screenDeclaration({
    route,
    area: 'logs',
    labelKey: 'navAreaLogs',
    entityType,
    id: { kind: 'none', parts: [] },
  });
}

const MESSAGES_LOG = screen('logs/messages', 'log-entry');
const PROCESSES = screen('os-management/processes', 'process');

class StubConnectivity {
  retries = 0;
  private current: Fault | null = null;
  private readonly listeners = new Set<() => void>();

  fault(): Fault | null {
    return this.current;
  }

  isRecovering(): boolean {
    return this.current?.kind === 'unreachable';
  }

  retry(): void {
    this.retries += 1;
  }

  retryWhenReachable(): void {}

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  publish(kind: FaultKind | null): void {
    this.current =
      kind === null ? null : { kind, status: 0, code: null, path: '/api/ocupilot/instance' };
    for (const listener of this.listeners) listener();
  }
}

class StubNavigation {
  screens: readonly ScreenDeclaration[] = [];
  readonly verdicts = new Map<string, Verdict>();
  private readonly listeners = new Set<() => void>();

  builtScreens(): readonly ScreenDeclaration[] {
    return this.screens;
  }

  screenVerdict(route: string): Verdict {
    return this.verdicts.get(route) ?? ALLOWED;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  notify(): void {
    for (const listener of this.listeners) listener();
  }
}

describe('the connectivity banner', () => {
  let fixture: ComponentFixture<FaultBanner>;
  let connectivity: StubConnectivity;
  let navigation: StubNavigation;
  let router: Router;

  const strip = (): HTMLElement | null => fixture.nativeElement.querySelector('.ocu-fault-banner');
  const buttons = (): HTMLButtonElement[] =>
    Array.from(fixture.nativeElement.querySelectorAll('button'));
  const button = (label: string): HTMLButtonElement | undefined =>
    buttons().find((el) => el.textContent?.trim() === label);

  beforeEach(() => {
    connectivity = new StubConnectivity();
    navigation = new StubNavigation();
    TestBed.configureTestingModule({
      providers: [
        provideRouter([
          { path: '', children: [] },
          { path: 'logs/messages', children: [] },
        ]),
        {
          provide: ConnectivityService,
          useValue: connectivity as unknown as ConnectivityService,
        },
        {
          provide: NavigationService,
          useValue: navigation as unknown as NavigationService,
        },
      ],
    });
    fixture = TestBed.createComponent(FaultBanner);
    router = TestBed.inject(Router);
    fixture.detectChanges();
  });

  it('draws nothing while no fault is published', () => {
    expect(strip()).toBeNull();
    expect(fixture.nativeElement.querySelector('[role="alert"]')).toBeNull();
  });

  it('an unreachable fault is one role=alert strip with the published sentence and Retry', () => {
    // Mutation (Rule 19): return `connectivityServerFault` from `FaultBanner.message`'s
    // unreachable arm and the sentence assertion goes red naming the other sentence.
    connectivity.publish('unreachable');
    fixture.detectChanges();

    const banner = strip();
    expect(banner).not.toBeNull();
    expect(banner?.getAttribute('role')).toBe('alert');
    expect(fixture.nativeElement.querySelectorAll('[role="alert"]')).toHaveLength(1);
    expect(banner?.querySelector('.ocu-fault-banner-message')?.textContent?.trim()).toBe(
      STRINGS.connectivityBannerUnreachable
    );
    expect(buttons().map((el) => el.textContent?.trim())).toEqual([STRINGS.actionRetry]);
  });

  it('a server fault carries the generic sentence and both published controls', () => {
    connectivity.publish('server-fault');
    fixture.detectChanges();

    expect(strip()?.querySelector('.ocu-fault-banner-message')?.textContent?.trim()).toBe(
      STRINGS.connectivityServerFault
    );
    expect(buttons().map((el) => el.textContent?.trim())).toEqual([
      STRINGS.actionRetry,
      STRINGS.actionOpenMessagesLog,
    ]);
    // The browser is told the generic reason and nothing about the instance (AD-12, AD-39).
    expect(strip()?.textContent).not.toContain('/api/ocupilot');
  });

  it('the other four kinds draw no banner: each has its own surface, and none has a sentence here', () => {
    // DW-126: EXPERIENCE.md publishes no banner copy for a refusal, an install in flight, a
    // missing entity or a rejected request, and inventing one is what this row refuses.
    for (const kind of ['not-installed', 'rejected', 'refused', 'absent'] as const) {
      connectivity.publish(kind);
      fixture.detectChanges();
      expect(strip(), `${kind} must not raise the connectivity banner`).toBeNull();
    }
  });

  it('the banner goes the moment the fault clears -- it is never dismissible while it holds', () => {
    connectivity.publish('unreachable');
    fixture.detectChanges();
    expect(strip()).not.toBeNull();
    // No dismiss control exists: the condition clearing is the only way it leaves.
    expect(buttons().map((el) => el.textContent?.trim())).toEqual([STRINGS.actionRetry]);

    connectivity.publish(null);
    fixture.detectChanges();
    expect(strip()).toBeNull();
  });

  it('Retry asks connectivity to probe now, rather than re-running the failed call itself', () => {
    // One recovery, not two: the probe's response is what clears the banner AND hands every
    // failed reader its one re-read, so Retry cannot disagree with the automatic path.
    connectivity.publish('unreachable');
    fixture.detectChanges();

    button(STRINGS.actionRetry)?.click();
    expect(connectivity.retries).toBe(1);
  });

  it('Open messages.log is gated in place while no built screen serves it', () => {
    // Epic 1 builds one screen and none over `log-entry`, so the control is listed, focusable
    // and refused -- the side bar's own shape for a destination the user cannot reach -- rather
    // than hidden or pointed at a route that does not exist.
    connectivity.publish('server-fault');
    fixture.detectChanges();

    const open = button(STRINGS.actionOpenMessagesLog);
    expect(open?.getAttribute('aria-disabled')).toBe('true');
    expect(open?.hasAttribute('disabled')).toBe(false);
    expect(open?.hidden).toBe(false);
    expect(open?.tabIndex).toBe(0);
  });

  it('...and opens it once one is built and this user may reach it', async () => {
    // The destination is resolved from the descriptor mirror's entity vocabulary (AD-5), never
    // from a route typed in the component -- so a screen declared over `log-entry` is enough.
    navigation.screens = [PROCESSES, MESSAGES_LOG];
    navigation.notify();
    connectivity.publish('server-fault');
    fixture.detectChanges();

    const open = button(STRINGS.actionOpenMessagesLog);
    expect(open?.getAttribute('aria-disabled')).toBeNull();

    open?.click();
    await fixture.whenStable();
    expect(router.url).toBe('/logs/messages');
  });

  it('a built messages.log screen this user may NOT open leaves the control refused', async () => {
    // AD-8's shape: the client affordance follows the verdict, and the server refuses either
    // way. A control that navigated here would send the user into a refusal page.
    navigation.screens = [MESSAGES_LOG];
    navigation.verdicts.set(MESSAGES_LOG.route, { allowed: false, failedPair: '%Admin_Operate:USE' });
    navigation.notify();
    connectivity.publish('server-fault');
    fixture.detectChanges();

    const open = button(STRINGS.actionOpenMessagesLog);
    expect(open?.getAttribute('aria-disabled')).toBe('true');
    open?.click();
    await fixture.whenStable();
    expect(router.url).toBe('/');
  });
});
