import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { LocaleCopyDialog, type LocaleCopyValues } from './locale-copy-dialog';

/** The Copy dialog (Story 21.16): its heading names the locale copied, its two fields, a held button until a name is typed, and what it emits. */

@Component({
  imports: [LocaleCopyDialog],
  template: `<app-locale-copy-dialog [source]="source" [refusal]="refusal" (submitted)="values.push($event)" (cancelled)="cancelled = cancelled + 1" />`,
})
class Host {
  source = 'enuw';
  refusal = '';
  values: LocaleCopyValues[] = [];
  cancelled = 0;
}

const planted: HTMLElement[] = [];

async function mount(refusal = ''): Promise<{ fixture: ComponentFixture<Host>; host: HTMLElement }> {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({ providers: [{ provide: OverlayStack, useValue: new OverlayStack() }] });
  const fixture = TestBed.createComponent(Host);
  fixture.componentInstance.refusal = refusal;
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await fixture.whenStable();
  return { fixture, host: fixture.nativeElement as HTMLElement };
}

function type(host: HTMLElement, field: string, value: string): void {
  const input = host.querySelector<HTMLInputElement>(`[data-locale-copy-field="${field}"]`);
  if (input === null) throw new Error(`no ${field} field`);
  input.value = value;
  input.dispatchEvent(new Event('input'));
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Copy dialog', () => {
  // Mutation (Rule 19): the heading names no locale -> this goes red.
  it('names the locale it copies and offers Name and Description', async () => {
    const { host } = await mount();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.localeCopyTitle.replace('<locale>', 'enuw'));
    const labels = [...host.querySelectorAll('.ocu-field-label')].map((label) => label.textContent?.trim());
    expect(labels).toEqual([STRINGS.tableColumnName, STRINGS.tableColumnDescription]);
  });

  // Mutation (Rule 19): the button is never held -> a blank name emits and this goes red.
  it('holds its button until a name is typed, then emits the name and the description once', async () => {
    const { fixture, host } = await mount();
    const button = host.querySelector<HTMLButtonElement>('[data-locale-copy-confirm]');
    expect(button?.getAttribute('aria-disabled')).toBe('true');
    button?.click();
    expect(fixture.componentInstance.values).toEqual([]);
    type(host, 'Name', ' yzzw ');
    type(host, 'Description', 'my locale');
    fixture.detectChanges();
    expect(button?.getAttribute('aria-disabled')).toBeNull();
    button?.click();
    expect(fixture.componentInstance.values).toEqual([{ name: 'yzzw', description: 'my locale' }]);
  });

  // Mutation (Rule 19): the refusal is dropped -> this goes red.
  it('draws the refusal the instance gave above the fields', async () => {
    const { host } = await mount(STRINGS.localeRefusalCopyTaken);
    expect(host.querySelector('[data-locale-copy-reason]')?.textContent?.trim()).toBe(STRINGS.localeRefusalCopyTaken);
  });
});
