import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { CopyMappingsDialog, copySources } from './copy-mappings-dialog';

/**
 * The Namespaces list's Copy mappings dialog (Story 18.14, AC6): a labeled select of the namespaces
 * the list read with the row's own left out, the published consequence, and a Copy that emits the
 * chosen source.
 */

@Component({
  imports: [CopyMappingsDialog],
  template: `<app-copy-mappings-dialog
    [destination]="destination()"
    [namespaces]="names()"
    (confirmed)="confirmed.push($event)"
    (cancelled)="cancelled = cancelled + 1"
  />`,
})
class Host {
  readonly destination = signal('OCUPROBE1814BB');
  readonly names = signal<readonly string[]>(['HSCUSTOM', 'OCUPROBE1814BA', 'OCUPROBE1814BB', 'USER']);
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

describe('the Copy mappings dialog', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('copySources leaves the destination out in any case, and keeps the rest in order, once each', () => {
    // Mutation (Rule 19): compare the destination with case -> the lower-case row stays and this goes red.
    expect(copySources(['USER', 'ocuprobe1814bb', 'HSCUSTOM', 'user', '', 'OCUPROBE1814BA'], 'OCUPROBE1814BB')).toEqual([
      'USER',
      'HSCUSTOM',
      'OCUPROBE1814BA',
    ]);
  });

  it('is titled and labeled with the published words, and offers every namespace the list read but the row\u2019s own', async () => {
    const { host } = await mount();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.namespaceCopyMappingsAction);
    const select = host.querySelector('select[data-copy-mappings-source]') as HTMLSelectElement;
    const label = host.querySelector(`label[for="${select.id}"]`);
    expect(label?.textContent?.trim()).toBe(STRINGS.headerNamespaceLabel);
    expect(Array.from(select.options).map((option) => option.value)).toEqual(['HSCUSTOM', 'OCUPROBE1814BA', 'USER']);
    expect(host.querySelector('[data-copy-mappings-consequence]')?.textContent?.trim()).toBe(STRINGS.namespaceCopyMappingsConsequence);
    expect(host.querySelector('[data-copy-mappings-confirm]')?.textContent?.trim()).toBe(STRINGS.auditDatabaseCopyConfirm);
  });

  it('Copy emits the source chosen, and the first one offered when none was chosen', async () => {
    const { fixture, host } = await mount();
    (host.querySelector('[data-copy-mappings-confirm]') as HTMLButtonElement).click();
    const select = host.querySelector('select[data-copy-mappings-source]') as HTMLSelectElement;
    select.value = 'OCUPROBE1814BA';
    select.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    (host.querySelector('[data-copy-mappings-confirm]') as HTMLButtonElement).click();
    expect(fixture.componentInstance.confirmed).toEqual(['HSCUSTOM', 'OCUPROBE1814BA']);
  });

  it('Copy is aria-disabled and emits nothing while the row\u2019s own namespace is the only one read', async () => {
    const { fixture, host } = await mount();
    const confirm = host.querySelector('[data-copy-mappings-confirm]') as HTMLButtonElement;
    expect(confirm.getAttribute('aria-disabled')).toBeNull();
    fixture.componentInstance.names.set(['OCUPROBE1814BB']);
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
