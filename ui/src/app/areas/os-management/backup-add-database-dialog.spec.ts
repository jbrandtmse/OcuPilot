import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { BackupAddDatabaseDialog } from './backup-add-database-dialog';

/**
 * The Add database dialog (Story 21.2): its title and one field, Add database held back until a name is typed and while a send runs, the
 * name handed on trimmed, the refusal drawn as an alert, and one cancel on every dismissal path.
 */

const planted: HTMLElement[] = [];

function mount(inputs: { sending?: boolean; refusal?: string } = {}) {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({ providers: [{ provide: OverlayStack, useValue: new OverlayStack() }] });
  const fixture = TestBed.createComponent(BackupAddDatabaseDialog);
  fixture.componentRef.setInput('sending', inputs.sending ?? false);
  fixture.componentRef.setInput('refusal', inputs.refusal ?? '');
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  const submitted: string[] = [];
  const cancelled: number[] = [];
  fixture.componentInstance.submitted.subscribe((name) => submitted.push(name));
  fixture.componentInstance.cancelled.subscribe(() => cancelled.push(1));
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, submitted, cancelled };
}

function type(fixture: ReturnType<typeof mount>['fixture'], host: HTMLElement, text: string): void {
  const field = host.querySelector('.ocu-backup-database-name') as HTMLInputElement;
  field.value = text;
  field.dispatchEvent(new Event('input', { bubbles: true }));
  fixture.detectChanges();
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Add database dialog', () => {
  it('is titled with the action, asks for the database and holds Add database back until a name is typed', () => {
    const { fixture, host, submitted } = mount();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.backupAddDatabaseAction);
    expect(host.querySelector('label')?.textContent?.trim()).toBe(STRINGS.systemInfoDatabase);
    const button = host.querySelector('.ocu-backup-database-submit') as HTMLButtonElement;
    expect(button.getAttribute('aria-disabled')).toBe('true');
    button.click();
    expect(submitted).toEqual([]);
    type(fixture, host, '   ');
    expect(button.getAttribute('aria-disabled')).toBe('true');
  });

  // Mutation (Rule 19): hand the name on without trimming it -> the emitted name keeps its spaces and this goes red.
  it('hands the typed name on trimmed, once, and not while a send is in flight', () => {
    const { fixture, host, submitted } = mount();
    type(fixture, host, ' USER ');
    (host.querySelector('.ocu-backup-database-submit') as HTMLButtonElement).click();
    expect(submitted).toEqual(['USER']);
    const sending = mount({ sending: true });
    type(sending.fixture, sending.host, 'USER');
    (sending.host.querySelector('.ocu-backup-database-submit') as HTMLButtonElement).click();
    expect(sending.submitted).toEqual([]);
  });

  it('draws the refusal as an alert and cancels once on dismissal', () => {
    const { host, cancelled, fixture } = mount({ refusal: STRINGS.backupRefusalDatabaseNotFound });
    expect(host.querySelector('.ocu-backup-database-refusal')?.getAttribute('role')).toBe('alert');
    expect(host.querySelector('.ocu-backup-database-refusal')?.textContent?.trim()).toBe(STRINGS.backupRefusalDatabaseNotFound);
    fixture.componentInstance['onClosed']();
    fixture.componentInstance['onClosed']();
    expect(cancelled).toHaveLength(1);
  });
});
