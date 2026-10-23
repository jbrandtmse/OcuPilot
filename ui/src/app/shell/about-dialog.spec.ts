import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

import { ABOUT_FIELDS, About } from '../core/about';
import { ConnectivityService } from '../core/connectivity';
import { NavigationService, type Verdict } from '../core/navigation';
import { OverlayStack } from '../core/overlay-stack';
import { SCREENS, type ScreenDeclaration } from '../core/screens.generated';
import { ShellState } from '../core/shell-state';
import { STRINGS } from '../core/strings';
import { stubAbout, type StubbedAbout } from '../testing/about';
import { AboutDialog } from './about-dialog';

const ALLOWED: Verdict = { allowed: true, failedPair: '' };

/** The real `messages.log` screen, from the mirror, so Open messages.log has somewhere to go. */
const MESSAGES_LOG = SCREENS.find((candidate) => candidate.route === 'logs/messages')!;

/** The three members the in-place banner reads from the shell; none of them is about this dialog. */
class StubConnectivity {
  fault(): null {
    return null;
  }

  retry(): void {}

  subscribe(): () => void {
    return () => {};
  }
}

class StubNavigation {
  builtScreens(): readonly ScreenDeclaration[] {
    return [MESSAGES_LOG];
  }

  screenVerdict(): Verdict {
    return ALLOWED;
  }

  subscribe(): () => void {
    return () => {};
  }
}

class StubShell {
  showArea(): void {}
}

/**
 * What the About dialog renders for each state its store can be in (Story 15.3).
 *
 * `account-menu.spec.ts` owns the opener, the overlay and the focus return, and `dialog.spec.ts`
 * owns the modal behaviour underneath. What is only observable here is the read's three outcomes:
 * an answer, an answer the instance could only partly report, and a read that never answered --
 * the I/O matrix's *About read unreachable* row, whose rendered half nothing else exercises.
 *
 * Mutations (Rule 19), each applied to `about-dialog.ts`, observed red here alone, and reverted:
 * make `unanswered` return `this.about.failed()` alone -> "a failed read after an answer keeps the
 * answer on screen" red, because a dialog reopened on an unreachable instance would blank the
 * thirteen values it had; drop the empty-value row from `resolved` (filter `value !== ''`) ->
 * "a member the instance could not report keeps its label" red; swap the `databaseCacheMb` and
 * `routineCacheMb` entries of `FIELD_LABELS` -> "it lists every carried member once" red, which
 * `terms[0]`/`terms[last]`/the length alone could not see.
 */
describe('the about dialog', () => {
  let fixture: ComponentFixture<AboutDialog>;
  let about: StubbedAbout;
  const planted: HTMLElement[] = [];

  const terms = (): string[] =>
    [...fixture.nativeElement.querySelectorAll('.ocu-about-term')].map(
      (node: HTMLElement) => node.textContent?.trim() ?? ''
    );
  const values = (): string[] =>
    [...fixture.nativeElement.querySelectorAll('.ocu-about-value')].map(
      (node: HTMLElement) => node.textContent?.trim() ?? ''
    );
  const fault = (): HTMLElement | null =>
    fixture.nativeElement.querySelector('.ocu-fault-banner');
  const faultButton = (label: string): HTMLButtonElement | undefined =>
    [...fixture.nativeElement.querySelectorAll('.ocu-fault-banner button')].find(
      (node: HTMLButtonElement) => node.textContent?.trim() === label
    );

  /** Mount the dialog over `store` and let its on-mount read settle. */
  async function mount(store: StubbedAbout): Promise<void> {
    about = store;
    TestBed.configureTestingModule({
      providers: [
        provideRouter([{ path: 'logs/messages', children: [] }]),
        { provide: About, useValue: about },
        { provide: OverlayStack, useValue: new OverlayStack() },
        { provide: ConnectivityService, useValue: new StubConnectivity() as unknown as ConnectivityService },
        { provide: NavigationService, useValue: new StubNavigation() as unknown as NavigationService },
        { provide: ShellState, useValue: new StubShell() as unknown as ShellState },
      ],
    });
    fixture = TestBed.createComponent(AboutDialog);
    fixture.detectChanges();
    await fixture.whenStable();
    fixture.detectChanges();
    document.body.appendChild(fixture.nativeElement);
    planted.push(fixture.nativeElement);
  }

  beforeEach(() => {
    TestBed.resetTestingModule();
  });

  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('it lists every carried member once, in the order the read answers them', async () => {
    await mount(stubAbout());

    expect(terms()).toHaveLength(ABOUT_FIELDS.length);
    expect(terms()[0]).toBe(STRINGS.aboutVersion);
    expect(terms()[terms().length - 1]).toBe(STRINGS.aboutBuild);
    expect(values()[0]).toBe('version-value');
    expect(fault()).toBeNull();
    // Every member under its own label, not just the first and the last: the stub seeds each field
    // a distinguishable `<field>-value`, so a label bound to the wrong member is visible here. Two
    // pairs are otherwise indistinguishable by eye -- the two caches and the two ports.
    expect(Object.fromEntries(terms().map((term, index) => [term, values()[index]]))).toEqual({
      [STRINGS.aboutVersion]: 'version-value',
      [STRINGS.aboutComponents]: 'productComponents-value',
      [STRINGS.aboutConfiguration]: 'configuration-value',
      [STRINGS.aboutDatabaseCache]: 'databaseCacheMb-value',
      [STRINGS.aboutRoutineCache]: 'routineCacheMb-value',
      [STRINGS.aboutJournalFile]: 'journalFile-value',
      [STRINGS.aboutSuperServerPort]: 'superServerPort-value',
      [STRINGS.aboutWebServerPort]: 'webServerPort-value',
      [STRINGS.aboutLicenseServer]: 'licenseServer-value',
      [STRINGS.statusSegmentLicensedTo]: 'licensedTo-value',
      [STRINGS.aboutEncryptionKeyId]: 'encryptionKeyId-value',
      [STRINGS.aboutLocale]: 'locale-value',
      [STRINGS.aboutBuild]: 'buildIdentity-value',
    });
    // One read, on mount -- the dialog is the only surface that shows any of it.
    expect(about.calls.map((call) => `${call.method} ${call.path}`)).toEqual([
      'GET /api/ocupilot/ui/about',
    ]);
  });

  it('a member the instance could not report keeps its label and renders empty', async () => {
    await mount(stubAbout({ fields: { journalFile: '', encryptionKeyId: '' } }));

    const rows = Object.fromEntries(terms().map((term, index) => [term, values()[index]]));
    expect(rows[STRINGS.aboutJournalFile]).toBe('');
    expect(rows[STRINGS.aboutEncryptionKeyId]).toBe('');
    expect(rows[STRINGS.aboutVersion]).toBe('version-value');
    // Dropping the row would say nothing at all; an empty value says the instance did not report it.
    expect(terms()).toHaveLength(ABOUT_FIELDS.length);
  });

  it('a read that never answered renders the in-place unreachable alert instead of thirteen blanks', async () => {
    await mount(stubAbout({ unreachable: true }));

    // Mutation (Rule 19): make the in-place banner draw `connectivityServerFault` whatever the
    // kind -> this goes red, and an unreachable instance would be described as a server fault.
    expect(fault()?.getAttribute('role')).toBe('alert');
    expect(fault()?.textContent).toContain(STRINGS.connectivityBannerUnreachable);
    expect(fault()?.textContent).not.toContain(STRINGS.connectivityServerFault);
    expect(faultButton(STRINGS.actionRetry)).toBeDefined();
    expect(faultButton(STRINGS.actionOpenMessagesLog)).toBeUndefined();
    expect(fixture.nativeElement.querySelectorAll('[role="alert"]')).toHaveLength(1);
    expect(terms()).toHaveLength(0);
    expect(fixture.nativeElement.querySelector('.ocu-about-list')).toBeNull();
    // Still one dialog with its published title -- the failure is inside it, not instead of it.
    expect(
      fixture.nativeElement.querySelector('.ocu-dialog-title')?.textContent?.trim()
    ).toBe(STRINGS.aboutTitle);
  });

  it('a server fault draws the generic sentence with Retry and Open messages.log', async () => {
    const store = stubAbout();
    store.setStatus(500);
    await mount(store);

    expect(fault()?.getAttribute('role')).toBe('alert');
    expect(fault()?.textContent).toContain(STRINGS.connectivityServerFault);
    expect(faultButton(STRINGS.actionRetry)).toBeDefined();
    expect(faultButton(STRINGS.actionOpenMessagesLog)).toBeDefined();
    expect(fixture.nativeElement.querySelectorAll('[role="alert"]')).toHaveLength(1);
  });

  it('Retry reads again, follows a change of fault, and shows the rows once the instance answers', async () => {
    await mount(stubAbout({ unreachable: true }));
    expect(about.calls).toHaveLength(1);
    expect(fault()?.textContent).toContain(STRINGS.connectivityBannerUnreachable);

    // The instance replies, but with a server fault: the sentence follows the new kind.
    about.setUnreachable(false);
    about.setStatus(500);
    faultButton(STRINGS.actionRetry)?.click();
    await fixture.whenStable();
    fixture.detectChanges();
    expect(about.calls).toHaveLength(2);
    expect(fault()?.textContent).toContain(STRINGS.connectivityServerFault);
    expect(faultButton(STRINGS.actionOpenMessagesLog)).toBeDefined();

    about.setStatus(null);
    faultButton(STRINGS.actionRetry)?.click();
    await fixture.whenStable();
    fixture.detectChanges();
    expect(about.calls).toHaveLength(3);
    expect(fault()).toBeNull();
    expect(terms()).toHaveLength(ABOUT_FIELDS.length);
    expect(values()[0]).toBe('version-value');
  });

  it('a Retry that answers leaves focus inside the dialog, not on the body behind it', async () => {
    // Mutation (Rule 19): drop the `afterNextRender` call from `AboutDialog.reread` -> this goes
    // red, focus fallen to the body once the Retry that held it left with the alert, where the
    // dialog's focus trap no longer hears Tab.
    await mount(stubAbout({ unreachable: true }));
    const retry = faultButton(STRINGS.actionRetry);
    retry?.focus();
    expect(document.activeElement).toBe(retry);

    about.setUnreachable(false);
    retry?.click();
    await fixture.whenStable();
    fixture.detectChanges();
    await fixture.whenStable();

    expect(fault()).toBeNull();
    const surface = fixture.nativeElement.querySelector('[role="dialog"]') as HTMLElement;
    expect(document.activeElement).not.toBe(document.body);
    expect(surface.contains(document.activeElement)).toBe(true);
  });

  it('a Retry read that settles after the dialog closed asks nothing of the destroyed dialog', async () => {
    // Mutation (Rule 19): drop `if (this.gone) return;` from `AboutDialog.reread` -> this goes red,
    // `afterNextRender` registered on a destroyed view rejects the read's promise (NG0911).
    const rejected: unknown[] = [];
    const onRejection = (reason: unknown): void => {
      rejected.push(reason);
    };
    process.on('unhandledRejection', onRejection);
    try {
      await mount(stubAbout({ unreachable: true }));
      about.setUnreachable(false);
      faultButton(STRINGS.actionRetry)?.click();
      fixture.destroy();
      await new Promise((resolve) => setTimeout(resolve, 0));
      expect(about.calls).toHaveLength(2);
      expect(rejected).toEqual([]);
    } finally {
      process.off('unhandledRejection', onRejection);
    }
  });

  it('Open messages.log closes the dialog before it navigates', async () => {
    const store = stubAbout();
    store.setStatus(500);
    await mount(store);
    // Mutation (Rule 19): drop `(logOpened)="closed.emit()"` from `about-dialog.ts`, or move the
    // emit below the navigation in `FaultBanner.openMessagesLog` -> this goes red, a dialog left
    // standing over the screen it navigated to.
    const order: string[] = [];
    const router = TestBed.inject(Router);
    const navigateByUrl = router.navigateByUrl.bind(router);
    vi.spyOn(router, 'navigateByUrl').mockImplementation((url, extras) => {
      order.push('navigate');
      return navigateByUrl(url, extras);
    });
    fixture.componentInstance.closed.subscribe(() => order.push('closed'));

    faultButton(STRINGS.actionOpenMessagesLog)?.click();
    await fixture.whenStable();

    expect(order).toEqual(['closed', 'navigate']);
  });

  it('a failed read after an answer keeps the answer on screen', async () => {
    await mount(stubAbout());
    expect(values()[0]).toBe('version-value');

    // The instance stops answering, and the store is read again.
    about.setFields({ version: 'never-seen' });
    about.setUnreachable(true);
    await about.load();
    fixture.detectChanges();

    expect(fault()).toBeNull();
    expect(values()[0]).toBe('version-value');
  });
});
