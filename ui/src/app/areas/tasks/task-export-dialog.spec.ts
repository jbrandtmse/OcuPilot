import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { AllowedDirectoriesStore } from '../../core/allowed-directories';
import type { ApiService } from '../../core/api';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import type { ServerPath } from '../../shell/server-path-picker';
import { TaskExportDialog } from './task-export-dialog';

/**
 * The Task schedule's Export dialog (Story 16.4, AC1, AC4, AC8): titled over the task, the server-path
 * picker for a file, the published note and replace line, and an Export that emits the chosen root
 * and name; the instance's refusals are drawn on the field they name, or as an alert.
 */

@Component({
  imports: [TaskExportDialog],
  template: `<app-task-export-dialog
    task="OcuP164Nightly"
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

const ROOT = '/durable/iris/mgr/';

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
  const api = { requestJson: async () => ({ kind: 'ok', status: 200, body: { fields: ['Directory'], rows: [{ Directory: ROOT }], truncated: false, banner: '' } }) };
  await fixture.componentInstance.store.load(api as unknown as Pick<ApiService, 'requestJson'>);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, component: fixture.componentInstance };
}

function type(host: HTMLElement, value: string): void {
  const input = host.querySelector('input.ocu-field-input') as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input'));
}

describe('the Task schedule Export dialog', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('is titled over the task and states the note and the replace line, with a file picker over the allowed directories', async () => {
    const { host } = await mount();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.taskExportTitle.replace('<task>', 'OcuP164Nightly'));
    expect(host.querySelector('[data-task-export-note]')?.textContent?.trim()).toBe(STRINGS.taskExportNote);
    expect(host.querySelector('[data-task-export-replaces]')?.textContent?.trim()).toBe(STRINGS.taskExportReplaces);
    const select = host.querySelector('select') as HTMLSelectElement;
    expect(Array.from(select.options).map((option) => option.value)).toEqual([ROOT]);
    expect(host.querySelector(`label[for="${(host.querySelector('input.ocu-field-input') as HTMLInputElement).id}"]`)?.textContent?.trim()).toBe(STRINGS.pathPickerFileLabel);
    expect(host.querySelector('[data-task-export-confirm]')?.textContent?.trim()).toBe(STRINGS.taskExportAction);
  });

  it('Export stays unavailable until a name is typed, then emits the root and the name as typed', async () => {
    const { fixture, host, component } = await mount();
    const confirm = host.querySelector('[data-task-export-confirm]') as HTMLButtonElement;
    expect(confirm.getAttribute('aria-disabled')).toBe('true');
    confirm.click();
    expect(component.submitted).toEqual([]);
    type(host, 'out/nightly.xml');
    await settle(fixture);
    expect(confirm.getAttribute('aria-disabled')).toBeNull();
    confirm.click();
    expect(component.submitted).toEqual([{ root: ROOT, path: 'out/nightly.xml' }]);
    component.sending.set(true);
    await settle(fixture);
    expect(confirm.getAttribute('aria-disabled')).toBe('true');
  });

  it('draws a refusal on the field it names, and any other refusal as an alert', async () => {
    const { fixture, host, component } = await mount();
    component.pathReason.set('A directory stands at that name.');
    component.rootReason.set('Choose an allowed directory.');
    await settle(fixture);
    const errors = Array.from(host.querySelectorAll('.ocu-form-error')).map((node) => node.textContent?.trim());
    expect(errors).toEqual(['Choose an allowed directory.', 'A directory stands at that name.']);
    expect((host.querySelector('input.ocu-field-input') as HTMLInputElement).getAttribute('aria-invalid')).toBe('true');
    expect(host.querySelector('[data-task-transfer-refusal]')).toBeNull();
    component.refusal.set('The file could not be written.');
    await settle(fixture);
    const alert = host.querySelector('[data-task-transfer-refusal]');
    expect(alert?.getAttribute('role')).toBe('alert');
    expect(alert?.textContent?.trim()).toBe('The file could not be written.');
  });

  it('Cancel emits cancelled and nothing else', async () => {
    const { host, component } = await mount();
    (host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement).click();
    expect(component.cancelled).toBe(1);
    expect(component.submitted).toEqual([]);
  });
});
