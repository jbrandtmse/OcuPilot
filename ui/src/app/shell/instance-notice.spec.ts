import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { InstanceService, type InstanceStatus } from '../core/instance';
import { Session, type SessionState } from '../core/session';
import { STRINGS } from '../core/strings';
import { TokenStore } from '../core/token-store';
import { InstanceNotice } from './instance-notice';

/**
 * The blocking instance notice's accessibility contract, per variant (EXPERIENCE.md's Status
 * messages line: `role="alert"`, opens with the page heading, takes focus on appearance).
 *
 * The version-mismatch and no-privileges variants read a stubbed `InstanceService`. The
 * unreadable variant is driven through a real `Session` answering a 503 `INSTALL.UNREADABLE`,
 * so its Retry is asserted by the state the session leaves, not by a spy.
 */

class StubInstance {
  constructor(private readonly current: InstanceStatus) {}

  status(): InstanceStatus {
    return this.current;
  }

  adminApiVersion(): number {
    return 1;
  }

  subscribe(): () => void {
    return () => undefined;
  }
}

class StubSession {
  state(): SessionState {
    return 'signed-in';
  }

  subscribe(): () => void {
    return () => undefined;
  }

  retryInstallState(): void {}

  async signOut(): Promise<void> {}
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

/** A real session that has met a 503 `INSTALL.UNREADABLE`, with no timer able to fire. */
function unreadableSession(): Session {
  const tokens = new TokenStore({ storage: memoryStorage(), navigationType: () => 'navigate' });
  const session = new Session({
    fetch: async () => ({ status: 503, text: async () => '{}' }),
    tokens,
    schedule: () => {},
  });
  session.noteInstallInFlight(503, 'INSTALL.UNREADABLE');
  return session;
}

describe('the blocking instance notice', () => {
  let fixture: ComponentFixture<InstanceNotice>;
  const planted: HTMLElement[] = [];

  async function render(instance: StubInstance, session: StubSession | Session): Promise<HTMLElement> {
    TestBed.configureTestingModule({
      providers: [
        { provide: InstanceService, useValue: instance as unknown as InstanceService },
        { provide: Session, useValue: session as unknown as Session },
      ],
    });
    fixture = TestBed.createComponent(InstanceNotice);
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
    fixture.detectChanges();
    await fixture.whenStable();
    return fixture.nativeElement as HTMLElement;
  }

  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  /** The three things every variant owes a screen-reader and keyboard user. */
  function expectBlockingNotice(host: HTMLElement, sentence: string): HTMLElement {
    const section = host.querySelector('section') as HTMLElement;
    expect(section).not.toBeNull();
    expect(section.getAttribute('role')).toBe('alert');
    expect(document.activeElement).toBe(section);
    const headings = host.querySelectorAll('h1');
    expect(headings).toHaveLength(1);
    expect(headings[0].textContent?.trim()).toBe(sentence);
    return section;
  }

  const buttonNamed = (host: HTMLElement, name: string): HTMLButtonElement | undefined =>
    Array.from(host.querySelectorAll('button')).find(
      (button) => button.textContent?.trim() === name
    );

  // Mutation (Rule 19): delete `role="alert"` from the notice's section -> all three go red.
  it('version mismatch: an alert that takes focus and opens with the one heading', async () => {
    const host = await render(new StubInstance('version-mismatch'), new StubSession());
    expectBlockingNotice(host, STRINGS.authAdminApiVersionMismatch.replace('<n>', '1'));
  });

  it('no administrative privileges: an alert that takes focus and opens with the one heading', async () => {
    const host = await render(new StubInstance('no-privileges'), new StubSession());
    expectBlockingNotice(host, STRINGS.authNoAdminPrivileges);
  });

  it('install state unreadable: the alert offers Retry and Sign out, never "Signing in"', async () => {
    const session = unreadableSession();
    expect(session.state()).toBe('install-unreadable');
    const host = await render(new StubInstance('ready'), session);

    expectBlockingNotice(host, STRINGS.authInstallStateUnreadable);
    expect(host.textContent).not.toContain(STRINGS.statusConnectionSigningIn);
    expect(buttonNamed(host, STRINGS.actionSignOut)).toBeDefined();

    const retry = buttonNamed(host, STRINGS.actionRetry);
    expect(retry).toBeDefined();
    retry?.click();
    expect(session.state()).not.toBe('install-unreadable');
  });
});
