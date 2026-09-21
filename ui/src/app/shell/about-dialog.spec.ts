import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { ABOUT_FIELDS, About } from '../core/about';
import { OverlayStack } from '../core/overlay-stack';
import { STRINGS } from '../core/strings';
import { stubAbout, type StubbedAbout } from '../testing/about';
import { AboutDialog } from './about-dialog';

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
    fixture.nativeElement.querySelector('.ocu-about-fault');

  /** Mount the dialog over `store` and let its on-mount read settle. */
  async function mount(store: StubbedAbout): Promise<void> {
    about = store;
    TestBed.configureTestingModule({
      providers: [
        { provide: About, useValue: about },
        { provide: OverlayStack, useValue: new OverlayStack() },
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

  it('a read that never answered renders the error state instead of thirteen blanks', async () => {
    await mount(stubAbout({ unreachable: true }));

    expect(fault()?.textContent?.trim()).toBe(STRINGS.connectivityServerFault);
    expect(terms()).toHaveLength(0);
    expect(fixture.nativeElement.querySelector('.ocu-about-list')).toBeNull();
    // Still one dialog with its published title -- the failure is inside it, not instead of it.
    expect(
      fixture.nativeElement.querySelector('.ocu-dialog-title')?.textContent?.trim()
    ).toBe(STRINGS.aboutTitle);
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
