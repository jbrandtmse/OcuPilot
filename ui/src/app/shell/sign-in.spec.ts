import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { Session, type SessionState } from '../core/session';
import { STRINGS } from '../core/strings';
import { SignIn } from './sign-in';

/**
 * DW-103: where focus goes when the sign-in form comes back.
 *
 * Neither UX document names a destination -- EXPERIENCE.md `:583` offers `role="alert"` *or*
 * focus moved to it, while `:582` forbids removing a focused control without one -- and the
 * two sightings in the ledger are the same transition seen twice: something the user was using
 * went away and the form returned. One rule covers both, and this is where it is pinned.
 *
 * The rule is about the *transition*, not the state, which is why the "does not steal focus
 * back" row is here: a re-focus on every change while the form is up would fight the user.
 */

class StubSession {
  private current: SessionState = 'probing';
  private currentUser = '';
  private currentPassword = '';
  private readonly listeners = new Set<() => void>();

  state(): SessionState {
    return this.current;
  }

  userName(): string {
    return this.currentUser;
  }

  password(): string {
    return this.currentPassword;
  }

  setUserName(value: string): void {
    this.currentUser = value;
  }

  setPassword(value: string): void {
    this.currentPassword = value;
  }

  async submitForm(): Promise<void> {}

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  /** Drive a state change the way the real session's own transitions reach the component. */
  move(next: SessionState, user = this.currentUser): void {
    this.current = next;
    this.currentUser = user;
    for (const listener of this.listeners) listener();
  }
}

describe('the sign-in card', () => {
  let fixture: ComponentFixture<SignIn>;
  let session: StubSession;
  const planted: HTMLElement[] = [];

  const field = (id: string): HTMLInputElement | null =>
    fixture.nativeElement.querySelector(`#${id}`);

  beforeEach(() => {
    session = new StubSession();
    TestBed.configureTestingModule({
      providers: [{ provide: Session, useValue: session as unknown as Session }],
    });
    fixture = TestBed.createComponent(SignIn);
    fixture.detectChanges();
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
  });

  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('the probe shows the skeleton and no form at all', () => {
    expect(fixture.nativeElement.querySelector('.ocu-skeleton')).not.toBeNull();
    expect(field('ocu-signin-user')).toBeNull();
  });

  it('DW-103: a rejected attempt keeps the user name and puts focus on the password field', () => {
    session.move('form-rejected', '_SYSTEM');
    fixture.detectChanges();

    expect(field('ocu-signin-user')?.value).toBe('_SYSTEM');
    expect(document.activeElement).toBe(field('ocu-signin-password'));
    // The failure is announced where it is, rather than by moving focus to it -- the field
    // the user has to act on is the one that takes focus, and the alert describes it.
    const alert = fixture.nativeElement.querySelector('[role="alert"]');
    expect(alert?.textContent?.trim()).toBe(STRINGS.authSignInFailed);
    expect(field('ocu-signin-password')?.getAttribute('aria-describedby')).toBe(alert?.id);
  });

  it('DW-103: sign-out clears the name, so focus lands on the user-name field', () => {
    session.move('signed-out', '');
    fixture.detectChanges();

    expect(document.activeElement).toBe(field('ocu-signin-user'));
    expect(fixture.nativeElement.querySelector('.ocu-banner-restrained')?.textContent?.trim()).toBe(
      STRINGS.authSignedOut
    );
  });

  it('DW-103: a session the instance ended focuses the password, the name being still known', () => {
    session.move('session-ended', '_SYSTEM');
    fixture.detectChanges();
    expect(document.activeElement).toBe(field('ocu-signin-password'));
  });

  it('the move happens on the transition only, so typing is never interrupted', () => {
    session.move('form', '');
    fixture.detectChanges();
    expect(document.activeElement).toBe(field('ocu-signin-user'));

    // The user moves to the password field and the session notifies again -- a name typed
    // into the first field is exactly such a notification in the running product.
    field('ocu-signin-password')?.focus();
    session.move('form', '_SYSTEM');
    fixture.detectChanges();
    expect(document.activeElement).toBe(field('ocu-signin-password'));
  });

  it('leaving the form and coming back moves focus again', () => {
    session.move('form', '');
    fixture.detectChanges();
    field('ocu-signin-password')?.focus();

    session.move('probing', '');
    fixture.detectChanges();
    expect(field('ocu-signin-user')).toBeNull();

    session.move('form-rejected', '_SYSTEM');
    fixture.detectChanges();
    expect(document.activeElement).toBe(field('ocu-signin-password'));
  });
});
