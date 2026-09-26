import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { AuditCopyDialog, copyTargets } from './audit-copy-dialog';

/**
 * The audit database's Copy dialog (Story 12.3): a labeled select of the scope's namespaces with
 * `%SYS` left out, the published consequence, and a Copy that emits the chosen namespace.
 */

@Component({
  imports: [AuditCopyDialog],
  template: `<app-audit-copy-dialog [namespaces]="names()" (confirmed)="confirmed.push($event)" (cancelled)="cancelled = cancelled + 1" />`,
})
class Host {
  readonly names = signal<readonly string[]>(['%SYS', 'HSCUSTOM', 'USER']);
  readonly confirmed: string[] = [];
  cancelled = 0;
}

const planted: HTMLElement[] = [];

async function mount(): Promise<{ fixture: ComponentFixture<Host>; host: HTMLElement }> {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({ providers: [{ provide: OverlayStack, useValue: new OverlayStack() }] });
  const fixture = TestBed.createComponent(Host);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await fixture.whenStable();
  return { fixture, host: fixture.nativeElement as HTMLElement };
}

describe('the audit database Copy dialog', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('copyTargets leaves %SYS out in any case, and keeps the rest in order, once each', () => {
    expect(copyTargets(['%SYS', 'USER', '%sys', 'HSCUSTOM', 'USER', ''])).toEqual(['USER', 'HSCUSTOM']);
  });

  it('is titled and labeled with the published words, and offers every namespace but %SYS', async () => {
    const { host } = await mount();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.auditDatabaseCopyTitle);
    const select = host.querySelector('select[data-audit-copy-namespace]') as HTMLSelectElement;
    const label = host.querySelector(`label[for="${select.id}"]`);
    expect(label?.textContent?.trim()).toBe(STRINGS.headerNamespaceLabel);
    expect(Array.from(select.options).map((option) => option.value)).toEqual(['HSCUSTOM', 'USER']);
    expect(host.querySelector('[data-audit-copy-consequence]')?.textContent?.trim()).toBe(STRINGS.auditDatabaseCopyConsequence);
    expect(host.querySelector('[data-audit-copy-confirm]')?.textContent?.trim()).toBe(STRINGS.auditDatabaseCopyConfirm);
  });

  it('Copy emits the namespace chosen, and the first one listed when none was chosen', async () => {
    const { fixture, host } = await mount();
    (host.querySelector('[data-audit-copy-confirm]') as HTMLButtonElement).click();
    const select = host.querySelector('select[data-audit-copy-namespace]') as HTMLSelectElement;
    select.value = 'USER';
    select.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    (host.querySelector('[data-audit-copy-confirm]') as HTMLButtonElement).click();
    expect(fixture.componentInstance.confirmed).toEqual(['HSCUSTOM', 'USER']);
  });

  it('Copy is aria-disabled and emits nothing while no namespace but %SYS is listed', async () => {
    const { fixture, host } = await mount();
    const confirm = host.querySelector('[data-audit-copy-confirm]') as HTMLButtonElement;
    expect(confirm.getAttribute('aria-disabled')).toBeNull();
    fixture.componentInstance.names.set(['%SYS']);
    fixture.detectChanges();
    expect(confirm.getAttribute('aria-disabled')).toBe('true');
    confirm.click();
    expect(fixture.componentInstance.confirmed).toEqual([]);
  });

  it('Cancel emits cancelled and copies nothing', async () => {
    const { fixture, host } = await mount();
    (host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement).click();
    expect(fixture.componentInstance.cancelled).toBe(1);
    expect(fixture.componentInstance.confirmed).toEqual([]);
  });
});
