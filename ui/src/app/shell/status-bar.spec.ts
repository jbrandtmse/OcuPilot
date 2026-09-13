import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { ChangeBus } from '../core/change-bus';
import { ConnectivityService } from '../core/connectivity';
import type { Fault, FaultKind } from '../core/fault';
import { InstanceService, type InstanceStatus } from '../core/instance';
import { OverlayStack } from '../core/overlay-stack';
import { PreferenceStore } from '../core/preferences';
import { RefreshService } from '../core/refresh';
import { ScreenStores } from '../core/screen-store';
import type { ScreenDeclaration } from '../core/screens.generated';
import { Session, type SessionState } from '../core/session';
import { STRINGS } from '../core/strings';
import { StatusBar } from './status-bar';

/**
 * The status bar's rendered contract (DESIGN.md `:1021`, `:1025`; EXPERIENCE.md `:54`, `:318`,
 * `:319`), and DW-10's client half.
 *
 * The payload behind it is `OcuPilot.Test.Instance`'s: this file asserts what the band does
 * with the three fields, not what the server puts in them.
 *
 * Story 1.13 adds the connection segment's other two words. They are asserted **through the
 * rendered DOM**, never against the service's own state: the Integration AC is that publishing
 * an `unreachable` fault changes what a user sees, and a component that read connectivity and
 * drew the old word would satisfy every service-level assertion.
 */

class StubInstance {
  serverFlagValue = '';
  licensedToValue = 'InterSystems IRIS Community';
  serverNameValue = 'B066BA383583';
  instanceNameValue = 'IRIS';
  instanceVersionValue = 'IRIS for UNIX 2026.2';
  private readonly listeners = new Set<() => void>();

  status(): InstanceStatus {
    return 'ready';
  }

  serverFlag(): string {
    return this.serverFlagValue;
  }

  licensedTo(): string {
    return this.licensedToValue;
  }

  serverName(): string {
    return this.serverNameValue;
  }

  instanceName(): string {
    return this.instanceNameValue;
  }

  instanceVersion(): string {
    return this.instanceVersionValue;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  notify(): void {
    for (const listener of this.listeners) listener();
  }
}

class StubSession {
  current: SessionState = 'signed-in';
  private readonly listeners = new Set<() => void>();

  state(): SessionState {
    return this.current;
  }

  userName(): string {
    return '_SYSTEM';
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  async signOut(): Promise<void> {}

  move(next: SessionState): void {
    this.current = next;
    for (const listener of this.listeners) listener();
  }
}

class StubConnectivity {
  private current: Fault | null = null;
  private recovering = false;
  private readonly listeners = new Set<() => void>();

  fault(): Fault | null {
    return this.current;
  }

  isRecovering(): boolean {
    return this.recovering;
  }

  /** The refresh framework's one park. Nothing here faults, so nothing is ever parked. */
  retryWhenReachable(): void {}

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  /** Publish a verdict the way `ApiService` does, and wake the band the way the real one does. */
  publish(kind: FaultKind | null, recovering = kind === 'unreachable'): void {
    this.current = kind === null ? null : { kind, status: 0, code: null, path: '/api/ocupilot/x' };
    this.recovering = recovering;
    for (const listener of this.listeners) listener();
  }
}

function memoryStorage() {
  const map = new Map<string, string>();
  return {
    getItem: (key: string) => map.get(key) ?? null,
    setItem: (key: string, value: string) => {
      map.set(key, value);
    },
    removeItem: (key: string) => {
      map.delete(key);
    },
  };
}

/**
 * A refreshing screen the framework will bind, and a read whose answer the test controls.
 *
 * The stamp is driven through the **real** `RefreshService` (Integration AC, Rule 1): a band
 * wired to a stub would satisfy every service-level assertion and still draw nothing. The timer
 * seam is neutralized (`schedule: () => {}`) and the tick is driven by hand, so no test here
 * waits on a clock.
 */
const REFRESHING: ScreenDeclaration = {
  descriptor: 'OcuPilot.Screen.Descriptor.Probe',
  route: 'os-management/processes',
  area: 'os-management',
  labelKey: 'navAreaOsManagement',
  sideBarPosition: 1,
  archetype: 'list',
  built: true,
  refreshes: true,
  refreshRates: [10],
  privileges: [],
  entityType: 'process',
  secondaryEntityTypes: [],
  scope: 'namespace',
  parentScope: '',
  id: { kind: 'single', parts: [] },
  context: { fields: [], secretFields: [] },
  primaryAction: { id: '', selfProtection: '' },
  rowActions: [],
  emptyStateKey: '',
  commandAliases: [],
  classicPage: '',
  classicLinkExemption: { exempt: false, reason: '', label: '', href: '' },
  toolIdentifier: 'probe',
};

describe('the status bar', () => {
  let fixture: ComponentFixture<StatusBar>;
  let instance: StubInstance;
  let session: StubSession;
  let connectivity: StubConnectivity;
  let refresh: RefreshService;
  let scheduled: { run: () => void; delayMs: number }[];
  let readAt: Date;
  const planted: HTMLElement[] = [];

  const band = (): HTMLElement => fixture.nativeElement.querySelector('[role="contentinfo"]');
  const badge = (): HTMLElement | null => fixture.nativeElement.querySelector('.ocu-server-flag');

  beforeEach(() => {
    instance = new StubInstance();
    session = new StubSession();
    connectivity = new StubConnectivity();
    scheduled = [];
    readAt = new Date(2026, 8, 12, 9, 5, 3);
    refresh = new RefreshService({
      stores: new ScreenStores({ preferences: new PreferenceStore({ storage: memoryStorage() }) }),
      connectivity: connectivity as unknown as ConnectivityService,
      bus: new ChangeBus(),
      namespace: () => 'HSCUSTOM',
      schedule: (run, delayMs) => scheduled.push({ run, delayMs }),
      now: () => readAt,
    });
    TestBed.configureTestingModule({
      providers: [
        { provide: InstanceService, useValue: instance as unknown as InstanceService },
        { provide: Session, useValue: session as unknown as Session },
        {
          provide: ConnectivityService,
          useValue: connectivity as unknown as ConnectivityService,
        },
        { provide: RefreshService, useValue: refresh },
        { provide: OverlayStack, useValue: new OverlayStack() },
      ],
    });
    fixture = TestBed.createComponent(StatusBar);
    fixture.detectChanges();
  });

  /** Bind the refreshing screen, turn it on, and let one tick land. */
  const tickOnce = async (rows: readonly string[] = ['a']) => {
    refresh.bind(REFRESHING, async () => ({ kind: 'ok', rows, truncated: false }));
    refresh.setRate(10);
    scheduled[scheduled.length - 1].run();
    await new Promise((resolve) => setTimeout(resolve, 0));
    fixture.detectChanges();
  };

  const stamp = (): HTMLElement | null => band().querySelector('.ocu-status-bar-stamp');

  /** A segment's visible value: its text with the visually hidden name taken out. */
  const valueOf = (segment: Element): string =>
    Array.from(segment.childNodes)
      .filter((node) => !(node instanceof HTMLElement && node.classList.contains('ocu-status-bar-label')))
      .map((node) => node.textContent ?? '')
      .join('')
      .trim();

  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('is a contentinfo band naming the server, the instance, the user and the licensee', () => {
    expect(band()).not.toBeNull();
    expect(band().tagName).toBe('FOOTER');

    const text = band().textContent ?? '';
    expect(text).toContain(instance.serverNameValue);
    expect(text).toContain(instance.instanceNameValue);
    expect(text).toContain(instance.instanceVersionValue);
    expect(text).toContain(instance.licensedToValue);
    expect(text).toContain('_SYSTEM');
  });

  it('the band is two groups, and DESIGN.md\'s order is which segment sits in which', () => {
    // The AC says *where*, not only *whether*: server, instance name and version, the user and
    // licensed-to on the LEFT; the flag badge, the stamp and the connection state on the RIGHT.
    // Reading the band's textContent cannot see that -- moving the badge into the left group
    // or the account menu past licensed-to leaves every other row in this file green.
    const groups: HTMLElement[] = Array.from(band().querySelectorAll('.ocu-status-bar-group'));
    expect(groups).toHaveLength(2);

    const shapeOf = (group: HTMLElement): string[] =>
      Array.from(group.children).map((child) => {
        const element = child as HTMLElement;
        return element.tagName === 'SPAN' ? valueOf(element) : element.tagName;
      });

    expect(shapeOf(groups[0])).toEqual([
      instance.serverNameValue,
      instance.instanceNameValue,
      instance.instanceVersionValue,
      'APP-ACCOUNT-MENU',
      instance.licensedToValue,
    ]);
    // Right: the badge, then the stamp's place (Story 1.14 supplies its value), then the
    // connection segment, which is the one wrapper rather than a bare span.
    const right = Array.from(groups[1].children).map((child) => child.tagName);
    expect(right[0]).toBe('APP-SERVER-FLAG');
    expect(right[right.length - 1]).toBe('SPAN');
    expect(
      (groups[1].lastElementChild as HTMLElement).classList.contains('ocu-status-bar-connection')
    ).toBe(true);
  });

  it('DW-126: server, instance and licensed-to each read their published name ahead of the value', () => {
    // jsdom computes no accessible name, so what is pinned is the text a screen reader reads:
    // the name is a node inside the segment, first, not aria-hidden, and followed by the value.
    // The clip that keeps it off screen is pinned as stylesheet text in design-tokens.test.mjs.
    //
    // Mutation (Rule 19): drop the label span from the server segment -> this goes red.
    const named = Array.from(band().querySelectorAll('.ocu-status-bar-segment')).filter(
      (segment) => segment.querySelector('.ocu-status-bar-label') !== null
    );
    expect(
      named.map((segment) => [
        segment.querySelector('.ocu-status-bar-label')?.textContent?.trim(),
        valueOf(segment),
      ])
    ).toEqual([
      [STRINGS.statusSegmentServer, instance.serverNameValue],
      [STRINGS.statusSegmentInstance, instance.instanceNameValue],
      [STRINGS.statusSegmentLicensedTo, instance.licensedToValue],
    ]);
    for (const segment of named) {
      const label = segment.querySelector('.ocu-status-bar-label') as HTMLElement;
      expect(segment.firstChild).toBe(label);
      expect(label.closest('[aria-hidden]')).toBeNull();
      expect((segment.textContent ?? '').replace(/\s+/g, ' ').trim()).toBe(
        `${label.textContent?.trim()} ${valueOf(segment)}`
      );
    }
    expect(band().querySelector('.ocu-status-bar-version .ocu-status-bar-label')).toBeNull();
  });

  it('the user segment is the account menu, and the only interactive element in the band', () => {
    const controls = band().querySelectorAll('button, a, input, select, textarea');
    expect(controls).toHaveLength(1);
    expect(controls[0].classList.contains('ocu-account-trigger')).toBe(true);

    (controls[0] as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(band().querySelector('[role="menuitem"]')?.textContent?.trim()).toBe(
      STRINGS.actionSignOut
    );
  });

  it('a segment whose value the instance could not report does not render', () => {
    instance.licensedToValue = '';
    instance.serverNameValue = '';
    instance.notify();
    fixture.detectChanges();

    const segments = Array.from(
      band().querySelectorAll('.ocu-status-bar-segment')
    ).map((segment) => (segment as HTMLElement).textContent?.trim());
    expect(segments).not.toContain('');
    expect(band().textContent).toContain(instance.instanceNameValue);
  });

  it('DW-10: an unflagged instance gets no badge at all', () => {
    expect(instance.serverFlagValue).toBe('');
    expect(badge()).toBeNull();
    for (const word of [
      STRINGS.serverFlagLive,
      STRINGS.serverFlagTest,
      STRINGS.serverFlagFailover,
      STRINGS.serverFlagDevelopment,
    ]) {
      expect(band().textContent).not.toContain(word);
    }
  });

  it('DW-10: each of the four reads its own word, case-folded, in its own pair', () => {
    // All four, not one: the badge picks the word in a four-arm switch, and a swapped arm
    // would ship a production instance labelled Development with nothing red.
    const pairs: [string, string, string][] = [
      ['LIVE', STRINGS.serverFlagLive, 'live'],
      ['TEST', STRINGS.serverFlagTest, 'test'],
      ['FAILOVER', STRINGS.serverFlagFailover, 'failover'],
      ['development', STRINGS.serverFlagDevelopment, 'development'],
    ];
    for (const [reported, word, kind] of pairs) {
      instance.serverFlagValue = reported;
      instance.notify();
      fixture.detectChanges();

      expect(badge()?.textContent?.trim()).toBe(word);
      expect(badge()?.getAttribute('data-flag')).toBe(kind);
    }
    // The band clips the pill; only Home's instance line sets `unbounded` (DW-163).
    expect(band().querySelector('app-server-flag')?.hasAttribute('data-unbounded')).toBe(false);
  });

  it('DW-10: a mode outside the four is drawn verbatim, in the restrained pair', () => {
    instance.serverFlagValue = 'STANDBY';
    instance.notify();
    fixture.detectChanges();

    expect(badge()?.textContent?.trim()).toBe('STANDBY');
    expect(badge()?.getAttribute('data-flag')).toBe('unknown');
  });

  it('DW-145 (pinned, not fixed): an unrecognised mode of any length is drawn verbatim and uncapped -- nothing in code truncates it; the 24px bar it could stretch is the browser measurement, not this test', () => {
    const long = 'A'.repeat(64);
    instance.serverFlagValue = long;
    instance.notify();
    fixture.detectChanges();

    expect(badge()?.textContent?.trim()).toBe(long);
    expect(badge()?.getAttribute('data-flag')).toBe('unknown');
  });

  it('DW-146 (pinned, not fixed): the truncated version is recoverable only through title, which a keyboard or touch user cannot reach', () => {
    const long =
      'IRIS for UNIX (Ubuntu Server LTS for ARM64 Containers) 2026.2 (Build 221U) Sun Sep 6 2026';
    instance.instanceVersionValue = long;
    instance.notify();
    fixture.detectChanges();

    const version: HTMLElement | null = band().querySelector('.ocu-status-bar-version');
    expect(version?.getAttribute('title')).toBe(long);
    // Not a real disclosure affordance: no tab stop and not a control, so there is no keyboard
    // or touch path to the full text beyond the title attribute pinned above.
    expect(version?.hasAttribute('tabindex')).toBe(false);
    expect(version?.tagName).not.toBe('BUTTON');
    expect(version?.tagName).not.toBe('A');
  });

  it("the connection state's disc is always followed by its word", () => {
    const connection = band().querySelector('.ocu-status-bar-connection');
    expect(connection?.getAttribute('role')).toBe('status');

    const disc = connection?.querySelector('.ocu-status-bar-disc');
    expect(disc?.getAttribute('aria-hidden')).toBe('true');
    expect(disc?.getAttribute('data-connection')).toBe('connected');
    expect(connection?.textContent?.trim()).toBe(STRINGS.statusConnectionConnected);

    session.move('probing');
    fixture.detectChanges();
    expect(
      band().querySelector('.ocu-status-bar-disc')?.getAttribute('data-connection')
    ).toBe('connecting');
    expect(band().querySelector('.ocu-status-bar-connection')?.textContent?.trim()).toBe(
      STRINGS.statusConnectionSigningIn
    );
  });

  it('the stamp does not render until the framework has a last-update time', () => {
    expect(stamp()).toBeNull();
    expect(band().textContent).not.toContain('Last update');

    // Bound and switched on is still not enough: it is the read landing that makes a stamp
    // truthful, and one drawn before then would claim a freshness the screen has not got.
    refresh.bind(REFRESHING, async () => ({ kind: 'ok', rows: [], truncated: false }));
    refresh.setRate(10);
    fixture.detectChanges();
    expect(stamp()).toBeNull();
  });

  it('Integration AC: a tick that lands makes the band read the published stamp', async () => {
    // Through the real framework, through the DOM: `hasStamp` becoming true is the claim, and a
    // band that read the service and drew nothing would satisfy every service-level assertion.
    await tickOnce();

    expect(stamp()?.textContent?.trim()).toBe('Last update 09:05:03');
    // The published span is filled, never shipped.
    expect(band().textContent).not.toContain('hh:mm:ss');
  });

  it('the stamp follows the tick, and is never announced (EXPERIENCE.md :583)', async () => {
    await tickOnce();
    const node = stamp() as HTMLElement;

    // Not hidden from the accessibility tree -- that would take away information a screen-reader
    // user can otherwise read on demand. "Never announced" is the absence of a live region, on
    // the node and on every ancestor, so a tick mutates no live region at all.
    expect(node.hasAttribute('aria-hidden')).toBe(false);
    for (let element: HTMLElement | null = node; element !== null; element = element.parentElement) {
      expect(element.hasAttribute('aria-live')).toBe(false);
      expect(['status', 'alert', 'log']).not.toContain(element.getAttribute('role'));
    }
    // The band's one polite region is the connection segment, and the stamp is its sibling.
    const polite = band().querySelector('.ocu-status-bar-connection') as HTMLElement;
    expect(polite.getAttribute('role')).toBe('status');
    expect(polite.contains(node)).toBe(false);

    // A second tick at a later time updates the text in place, still with no live region.
    readAt = new Date(2026, 8, 12, 23, 59, 59);
    scheduled[scheduled.length - 1].run();
    await new Promise((resolve) => setTimeout(resolve, 0));
    fixture.detectChanges();
    expect(stamp()?.textContent?.trim()).toBe('Last update 23:59:59');
  });

  // --- Story 1.13: the connection segment reads connectivity ------------------------------

  const connection = (): HTMLElement | null =>
    band().querySelector('.ocu-status-bar-connection');
  const disc = (): string | null =>
    band().querySelector('.ocu-status-bar-disc')?.getAttribute('data-connection') ?? null;

  it('Integration AC: an unreachable fault makes the band read Instance unreachable -- retrying', () => {
    // Asserted against the rendered DOM, not against the service: a component that subscribed
    // to connectivity and still drew Connected would pass every state-level check.
    //
    // Mutation (Rule 19): delete the `unreachable` arm from `StatusBar.connectionWord` so the
    // band falls through to Connected -> both assertions go red.
    connectivity.publish('unreachable');
    fixture.detectChanges();

    expect(connection()?.textContent?.trim()).toBe(STRINGS.statusConnectionRetrying);
    expect(disc()).not.toBe('connected');
    expect(disc()).toBe('unreachable');
  });

  it('an install in flight reads Signing in, never the unreachable word (AD-38, DW-1)', () => {
    // An instance that is coming up is not one that is unreachable, and telling a user their
    // connection is gone while it installs is the kind of misattribution DW-1 is about.
    connectivity.publish('not-installed', false);
    fixture.detectChanges();

    expect(connection()?.textContent?.trim()).toBe(STRINGS.statusConnectionSigningIn);
    expect(disc()).toBe('connecting');
  });

  it('an instance that answered again, with nothing yet succeeding, reads Signing in again', () => {
    // The fourth published word (EXPERIENCE.md :261) and the gap it exists for: the probe got a
    // response, so the fault is no longer `unreachable`, but the tab is still re-establishing.
    connectivity.publish('rejected', true);
    fixture.detectChanges();

    expect(connection()?.textContent?.trim()).toBe(STRINGS.statusConnectionSigningInAgain);
    expect(disc()).toBe('connecting');
  });

  it('the four words are four distinct words, and the band shows exactly one at a time', () => {
    // Guards the mapping itself rather than one arm of it: a `connectionWord` that returned the
    // same string for two states would pass each row above that happened to expect that string.
    const words = new Set<string>([
      STRINGS.statusConnectionConnected,
      STRINGS.statusConnectionSigningIn,
      STRINGS.statusConnectionRetrying,
      STRINGS.statusConnectionSigningInAgain,
    ]);
    expect(words.size).toBe(4);

    const seen: string[] = [];
    for (const step of [
      () => connectivity.publish(null),
      () => connectivity.publish('unreachable'),
      () => connectivity.publish('rejected', true),
      () => connectivity.publish('not-installed', false),
    ]) {
      step();
      fixture.detectChanges();
      const text = connection()?.textContent?.trim() ?? '';
      expect(words.has(text)).toBe(true);
      seen.push(text);
    }
    expect(seen).toEqual([
      STRINGS.statusConnectionConnected,
      STRINGS.statusConnectionRetrying,
      STRINGS.statusConnectionSigningInAgain,
      STRINGS.statusConnectionSigningIn,
    ]);
  });

  it('a fault the banner owns leaves the band on Connected: two surfaces, one message each', () => {
    // A server fault is a response -- the instance is reachable and the session is live -- so
    // the band says so and the banner carries the failure. Saying it twice would be two
    // unrelated-looking reports of one event.
    connectivity.publish('server-fault', false);
    fixture.detectChanges();

    expect(connection()?.textContent?.trim()).toBe(STRINGS.statusConnectionConnected);
    expect(disc()).toBe('connected');
  });
});
