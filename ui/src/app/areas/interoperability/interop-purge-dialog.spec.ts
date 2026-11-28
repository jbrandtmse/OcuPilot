import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { InteropPurgeDialog, type PurgeSettingsView } from './interop-purge-dialog';

/**
 * The Purge dialog on its own (Story 24.17 Batch 2): over the three settings Story 24.16's purge shows, and over the record count and the consequence sentence the two log
 * purges pass in their place. The pages that open it are `interop-purge-list.page.spec.ts`'s and `interop-log-purge-list.page.spec.ts`'s.
 */

@Component({
  imports: [InteropPurgeDialog],
  template: `<app-interop-purge-dialog
    namespace="USER"
    [settings]="settings()"
    [count]="count()"
    [consequenceText]="consequenceText()"
    (confirmed)="confirmed.push($event)"
  />`,
})
class Host {
  readonly settings = signal<PurgeSettingsView | null>(null);

  readonly count = signal('');

  readonly consequenceText = signal('');

  readonly confirmed: string[] = [];
}

const planted: HTMLElement[] = [];

function mount(init: { settings?: PurgeSettingsView; count?: string; consequenceText?: string }) {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({ providers: [{ provide: OverlayStack, useValue: new OverlayStack() }] });
  const fixture = TestBed.createComponent(Host);
  fixture.componentInstance.settings.set(init.settings ?? null);
  fixture.componentInstance.count.set(init.count ?? '');
  fixture.componentInstance.consequenceText.set(init.consequenceText ?? '');
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, instance: fixture.componentInstance };
}

function typeInto(host: HTMLElement, selector: string, value: string): void {
  const control = host.querySelector(selector) as HTMLInputElement;
  control.value = value;
  control.dispatchEvent(new Event('input'));
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Purge dialog', () => {
  // Mutation (Rule 19): draw the settings list whatever the page passes -> the log purge's "no settings" assertion goes red.
  it('shows the count and the log\'s own consequence, and no settings, when a log\'s purge passes them', () => {
    const { host } = mount({ count: '42', consequenceText: STRINGS.interopRuleLogPurgeConsequence });
    expect(host.querySelector('[data-interop-purge-count]')?.textContent?.trim()).toBe(`${STRINGS.interopColumnCount}: 42`);
    expect(host.querySelector('[data-interop-purge-settings]')).toBeNull();
    expect(host.querySelector('[data-interop-purge-consequence]')?.textContent?.trim()).toBe(STRINGS.interopRuleLogPurgeConsequence);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.auditDatabasePurgeConfirm);
  });

  it('shows the settings and the settings\' consequence, and no count, when the purge passes settings', () => {
    const { host } = mount({ settings: { bodies: true, integrity: true, bitmap: true, description: '' } });
    expect(host.querySelector('[data-interop-purge-settings]')).not.toBeNull();
    expect(host.querySelector('[data-interop-purge-count]')).toBeNull();
    expect(host.querySelector('[data-interop-purge-consequence]')?.textContent?.trim()).toBe(STRINGS.interopPurgeBitmapConsequence);
  });

  // Mutation (Rule 19): let a `0` count read as none, or drop the count line -> this goes red.
  it('shows a count of 0 as a line, and none for an empty count', () => {
    expect(mount({ count: '0' }).host.querySelector('[data-interop-purge-count]')?.textContent?.trim()).toBe(`${STRINGS.interopColumnCount}: 0`);
    expect(mount({ count: '' }).host.querySelector('[data-interop-purge-count]')).toBeNull();
  });

  // Mutation (Rule 19): make Purge ignore the typed name for a log purge -> the held assertion goes red.
  it('holds Purge for a log purge until the days and the namespace\'s name are right, then emits the days as text', () => {
    const { fixture, host, instance } = mount({ count: '3' });
    const confirm = host.querySelector('[data-interop-purge-confirm]') as HTMLButtonElement;
    typeInto(host, '[data-interop-purge-days]', '3650');
    fixture.detectChanges();
    expect(confirm.getAttribute('aria-disabled')).toBe('true');
    confirm.click();
    expect(instance.confirmed).toEqual([]);
    typeInto(host, '[data-interop-purge-typed]', 'USER');
    fixture.detectChanges();
    expect(confirm.getAttribute('aria-disabled')).toBeNull();
    confirm.click();
    expect(instance.confirmed).toEqual(['3650']);
  });
});
