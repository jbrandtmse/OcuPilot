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

  it('DW-105: the expired-password banner names the account and carries both published links', () => {
    // The rendering half of DW-105. The state has no trigger on this build -- every 401 from
    // `/login` is byte-identical, verified in Story 1.6 -- so it is driven here directly; what
    // is asserted is that when it IS reached, the sentence is complete rather than shipping its
    // own placeholder.
    //
    // Mutation (Rule 19): drop the `formatUser` call from `SignIn.expiredParts` and the
    // no-literal-<user> assertion goes red; drop `linkParts` and the two-anchor row does.
    session.move('password-expired', '_SYSTEM');
    fixture.detectChanges();

    const banner: HTMLElement = fixture.nativeElement.querySelector('.ocu-banner-info');
    expect(banner).not.toBeNull();

    const rendered = banner.textContent ?? '';
    expect(rendered).toContain('_SYSTEM');
    expect(rendered).not.toContain('<user>');
    // The whole sentence still reads as one sentence: anchoring two phrases must not drop or
    // reorder a clause, which is the failure mode of splitting published copy for rendering.
    expect(rendered.replace(/\s+/g, ' ').trim()).toBe(
      STRINGS.authPasswordExpired.replace('<user>', '_SYSTEM')
    );

    const links: HTMLAnchorElement[] = Array.from(banner.querySelectorAll('a'));
    expect(links).toHaveLength(1);
    // Each link's text is a span of the canonical sentence, never a control name typed into
    // the component -- so every anchor's own words are already in the string source.
    for (const link of links) {
      expect(link.getAttribute('href')).toBeTruthy();
      expect(STRINGS.authPasswordExpired).toContain(link.textContent?.trim() ?? '');
    }
    // The one link goes to the classic portal, where the password is changed.
    expect(links[0].getAttribute('href')).toBe('/csp/sys/UtilHome.csp');
    // DW-166: "the README" is present as words and absent as a link until the repository is
    // public (2026-09-24). The sentence keeps the instruction; the bundle keeps no account
    // name. The whole-sentence assertion above is what proves the phrase still renders.
    expect(rendered).toContain('the README');
    expect(banner.innerHTML.toLowerCase()).not.toContain('github');
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
