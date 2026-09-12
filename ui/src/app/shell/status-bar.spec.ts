import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { InstanceService, type InstanceStatus } from '../core/instance';
import { OverlayStack } from '../core/overlay-stack';
import { Session, type SessionState } from '../core/session';
import { STRINGS } from '../core/strings';
import { StatusBar } from './status-bar';

/**
 * The status bar's rendered contract (DESIGN.md `:1021`, `:1025`; EXPERIENCE.md `:54`, `:318`,
 * `:319`), and DW-10's client half.
 *
 * The payload behind it is `OcuPilot.Test.Instance`'s: this file asserts what the band does
 * with the three fields, not what the server puts in them.
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

describe('the status bar', () => {
  let fixture: ComponentFixture<StatusBar>;
  let instance: StubInstance;
  let session: StubSession;
  const planted: HTMLElement[] = [];

  const band = (): HTMLElement => fixture.nativeElement.querySelector('[role="contentinfo"]');
  const badge = (): HTMLElement | null => fixture.nativeElement.querySelector('.ocu-server-flag');

  beforeEach(() => {
    instance = new StubInstance();
    session = new StubSession();
    TestBed.configureTestingModule({
      providers: [
        { provide: InstanceService, useValue: instance as unknown as InstanceService },
        { provide: Session, useValue: session as unknown as Session },
        { provide: OverlayStack, useValue: new OverlayStack() },
      ],
    });
    fixture = TestBed.createComponent(StatusBar);
    fixture.detectChanges();
  });

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
        return element.tagName === 'SPAN' ? (element.textContent ?? '').trim() : element.tagName;
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

  it('the auto-refresh stamp does not render: Story 1.14 is what supplies a value', () => {
    expect(band().textContent).not.toContain(STRINGS.statusLastUpdate);
  });
});
