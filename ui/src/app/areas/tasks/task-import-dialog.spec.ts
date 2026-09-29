import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { AllowedDirectoriesStore } from '../../core/allowed-directories';
import type { ApiService } from '../../core/api';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import type { ServerPath } from '../../shell/server-path-picker';
import { TaskImportDialog } from './task-import-dialog';

/**
 * The Task schedule's Import dialog (Story 16.4, AC2, AC4, AC6, AC8): titled "Import tasks", the
 * server-path picker for a file, and an Import that emits the chosen root and name; the instance's
 * refusals are drawn on the field they name, or as an alert.
 */

@Component({
  imports: [TaskImportDialog],
  template: `<app-task-import-dialog
    [store]="store"
    [rootReason]="rootReason()"
    [pathReason]="pathReason()"
    [refusal]="refusal()"
    [sending]="sending()"
    (submitted)="submitted.push($event)"
    (cancelled)="cancelled = cancelled + 1"
  />`,
})
class Host {
  readonly store = new AllowedDirectoriesStore();
  readonly rootReason = signal('');
  readonly pathReason = signal('');
  readonly refusal = signal('');
  readonly sending = signal(false);
  readonly submitted: ServerPath[] = [];
  cancelled = 0;
}

const ROOTS = ['/durable/iris/mgr/', '/data/exports/'];

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 3; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(): Promise<{ fixture: ComponentFixture<Host>; host: HTMLElement; component: Host }> {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({ providers: [{ provide: OverlayStack, useValue: new OverlayStack() }] });
  const fixture = TestBed.createComponent(Host);
  const rows = ROOTS.map((Directory) => ({ Directory }));
  const api = { requestJson: async () => ({ kind: 'ok', status: 200, body: { fields: ['Directory'], rows, truncated: false, banner: '' } }) };
  await fixture.componentInstance.store.load(api as unknown as Pick<ApiService, 'requestJson'>);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, component: fixture.componentInstance };
}

describe('the Task schedule Import dialog', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('is titled "Import tasks", offers every allowed directory, and has no export note', async () => {
    const { host } = await mount();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.taskImportTitle);
    const select = host.querySelector('select') as HTMLSelectElement;
    expect(Array.from(select.options).map((option) => option.value)).toEqual(ROOTS);
    expect(host.querySelector('[data-task-export-note]')).toBeNull();
    expect(host.querySelector('[data-task-import-confirm]')?.textContent?.trim()).toBe(STRINGS.actionImport);
  });

  it('Import emits the chosen root and the name as typed, once both are chosen', async () => {
    const { fixture, host, component } = await mount();
    const confirm = host.querySelector('[data-task-import-confirm]') as HTMLButtonElement;
    const input = host.querySelector('input.ocu-field-input') as HTMLInputElement;
    input.value = 'in/tasks.xml';
    input.dispatchEvent(new Event('input'));
    await settle(fixture);
    expect(confirm.getAttribute('aria-disabled')).toBe('true');
    const select = host.querySelector('select') as HTMLSelectElement;
    select.value = ROOTS[1];
    select.dispatchEvent(new Event('change'));
    await settle(fixture);
    expect(confirm.getAttribute('aria-disabled')).toBeNull();
    confirm.click();
    expect(component.submitted).toEqual([{ root: ROOTS[1], path: 'in/tasks.xml' }]);
  });

  it('draws a refusal on the field it names, and any other refusal as an alert', async () => {
    const { fixture, host, component } = await mount();
    component.pathReason.set('No file of that name exists to read.');
    await settle(fixture);
    expect(Array.from(host.querySelectorAll('.ocu-form-error')).map((node) => node.textContent?.trim())).toEqual(['No file of that name exists to read.']);
    component.pathReason.set('');
    component.refusal.set('Every task in this file is already on this instance.');
    await settle(fixture);
    expect(host.querySelector('.ocu-form-error')).toBeNull();
    expect(host.querySelector('[data-task-transfer-refusal][role="alert"]')?.textContent?.trim()).toBe('Every task in this file is already on this instance.');
  });
});
