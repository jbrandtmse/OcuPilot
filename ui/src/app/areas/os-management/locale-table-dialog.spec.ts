import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { LOCALE_IO_LIST, LOCALE_TABLE_LISTS, LocaleTableDialog, type LocaleTableValues } from './locale-table-dialog';

/** The Add table dialog (Story 21.16): the nine lists, the two sides only for the input/output list, a held button, and the row it emits. */

@Component({
  imports: [LocaleTableDialog],
  template: `<app-locale-table-dialog (submitted)="values.push($event)" (cancelled)="cancelled = cancelled + 1" />`,
})
class Host {
  values: LocaleTableValues[] = [];
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

function type(host: HTMLElement, field: string, value: string): void {
  const input = host.querySelector<HTMLInputElement>(`[data-locale-table-field="${field}"]`);
  if (input === null) throw new Error(`no ${field} field`);
  input.value = value;
  input.dispatchEvent(new Event('input'));
}

function choose(host: HTMLElement, list: string): void {
  const select = host.querySelector<HTMLSelectElement>('[data-locale-table-field="Type"]');
  if (select === null) throw new Error('no Type field');
  select.value = list;
  select.dispatchEvent(new Event('change'));
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Add table dialog', () => {
  // Mutation (Rule 19): a list dropped from LOCALE_TABLE_LISTS -> the option count goes red.
  it('offers the nine lists and no side fields until the input/output list is chosen', async () => {
    const { fixture, host } = await mount();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.localeAddTableAction);
    expect(host.querySelectorAll('[data-locale-table-field="Type"] option').length).toBe(9);
    expect(LOCALE_TABLE_LISTS).toContain(LOCALE_IO_LIST);
    expect(host.querySelector('[data-locale-table-field="InputFrom"]')).toBeNull();
    choose(host, LOCALE_IO_LIST);
    fixture.detectChanges();
    expect(host.querySelector('[data-locale-table-field="InputFrom"]')).not.toBeNull();
    expect(host.querySelector('[data-locale-table-field="OutputTo"]')).not.toBeNull();
  });

  // Mutation (Rule 19): the row is emitted with the list omitted -> this goes red.
  it('emits <list>:<table> for an internal list, with no side', async () => {
    const { fixture, host } = await mount();
    const button = host.querySelector<HTMLButtonElement>('[data-locale-table-confirm]');
    expect(button?.getAttribute('aria-disabled')).toBe('true');
    choose(host, 'PatternTables');
    type(host, 'Table', ' Latin2 ');
    fixture.detectChanges();
    expect(button?.getAttribute('aria-disabled')).toBeNull();
    button?.click();
    expect(fixture.componentInstance.values).toEqual([{ name: 'PatternTables:Latin2', inputFrom: '', outputTo: '' }]);
  });

  // Mutation (Rule 19): the button ignores a missing side -> this goes red.
  it('holds an input/output table until both sides are typed, then emits them', async () => {
    const { fixture, host } = await mount();
    choose(host, LOCALE_IO_LIST);
    fixture.detectChanges();
    type(host, 'Table', 'myio');
    type(host, 'InputFrom', 'Latin2');
    fixture.detectChanges();
    const button = host.querySelector<HTMLButtonElement>('[data-locale-table-confirm]');
    expect(button?.getAttribute('aria-disabled')).toBe('true');
    type(host, 'OutputTo', 'Latin2');
    fixture.detectChanges();
    button?.click();
    expect(fixture.componentInstance.values).toEqual([{ name: 'XLTTables:myio', inputFrom: 'Latin2', outputTo: 'Latin2' }]);
  });
});
