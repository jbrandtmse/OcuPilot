import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { AuditPurgeDialog, purgeCutoff, purgeDays } from './audit-purge-dialog';

/**
 * The audit database's Purge dialog (Story 12.3): the days field, the scope and cut-off line it
 * computes, and a destructive Purge that stays `aria-disabled` until the cut-off date is typed.
 */

/** A fixed local "today", so the cut-off is a known date. */
const TODAY = new Date(2026, 8, 24, 15, 30, 0);

@Component({
  imports: [AuditPurgeDialog],
  template: `<app-audit-purge-dialog [today]="today()" (confirmed)="confirmed.push($event)" (cancelled)="cancelled = cancelled + 1" />`,
})
class Host {
  readonly today = signal(TODAY);
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

function type(fixture: ComponentFixture<Host>, input: HTMLInputElement, value: string): void {
  input.value = value;
  input.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

const purge = (host: HTMLElement) => host.querySelector('[data-audit-purge-confirm]') as HTMLButtonElement;

describe('the audit database Purge dialog', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('purgeCutoff counts back on the local calendar, across a month and a year, and 0 is today', () => {
    expect(purgeCutoff(0, TODAY)).toBe('2026-09-24');
    expect(purgeCutoff(24, TODAY)).toBe('2026-08-31');
    expect(purgeCutoff(365, new Date(2026, 0, 5))).toBe('2025-01-05');
    expect(purgeCutoff(1, new Date(2024, 2, 1))).toBe('2024-02-29');
  });

  it('purgeDays admits a whole number from 0 to 9999 and nothing else', () => {
    expect(['0', '30', '9999'].map(purgeDays)).toEqual([0, 30, 9999]);
    expect(['', '-1', '1.5', '10000', 'ten', ' 7'].map(purgeDays)).toEqual([null, null, null, null, null, null]);
  });

  it('labels the days field, names the scope and the cut-off, and asks for that date', async () => {
    const { fixture, host } = await mount();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.auditDatabasePurgeTitle);
    const days = host.querySelector('[data-audit-purge-days]') as HTMLInputElement;
    expect(days.getAttribute('inputmode')).toBe('numeric');
    expect(host.querySelector(`label[for="${days.id}"]`)?.textContent?.trim()).toBe(STRINGS.auditDatabasePurgeDays);
    expect(host.querySelector('[data-audit-purge-consequence]')).toBeNull();
    type(fixture, days, '30');
    expect(host.querySelector('[data-audit-purge-consequence]')?.textContent?.trim()).toBe(
      STRINGS.auditDatabasePurgeConsequence.split('<date>').join('2026-08-25')
    );
    const typed = host.querySelector('[data-audit-purge-typed]') as HTMLInputElement;
    expect(host.querySelector(`label[for="${typed.id}"]`)?.textContent?.trim()).toBe(STRINGS.formTypedNameConfirm.split('<name>').join('2026-08-25'));
    expect(purge(host).textContent?.trim()).toBe(STRINGS.auditDatabasePurgeConfirm);
    expect(purge(host).classList.contains('ocu-button-destructive')).toBe(true);
  });

  it('keeps Purge aria-disabled until the cut-off is typed exactly, and a changed day count re-locks it', async () => {
    const { fixture, host } = await mount();
    type(fixture, host.querySelector('[data-audit-purge-days]') as HTMLInputElement, '0');
    expect(purge(host).getAttribute('aria-disabled')).toBe('true');
    purge(host).click();
    type(fixture, host.querySelector('[data-audit-purge-typed]') as HTMLInputElement, '2026-9-24');
    purge(host).click();
    expect(purge(host).getAttribute('aria-disabled')).toBe('true');
    expect(fixture.componentInstance.confirmed).toEqual([]);
    type(fixture, host.querySelector('[data-audit-purge-typed]') as HTMLInputElement, '2026-09-24');
    expect(purge(host).getAttribute('aria-disabled')).toBeNull();
    type(fixture, host.querySelector('[data-audit-purge-days]') as HTMLInputElement, '1');
    expect(purge(host).getAttribute('aria-disabled')).toBe('true');
    type(fixture, host.querySelector('[data-audit-purge-days]') as HTMLInputElement, '0');
    purge(host).click();
    expect(fixture.componentInstance.confirmed).toEqual(['2026-09-24']);
  });

  it('marks a days value out of range invalid and offers no cut-off for it', async () => {
    const { fixture, host } = await mount();
    const days = host.querySelector('[data-audit-purge-days]') as HTMLInputElement;
    type(fixture, days, '10000');
    expect(days.getAttribute('aria-invalid')).toBe('true');
    expect(host.querySelector('[data-audit-purge-typed]')).toBeNull();
    expect(purge(host).getAttribute('aria-disabled')).toBe('true');
  });
});
