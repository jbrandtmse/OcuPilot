import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { AllowedDirectoriesStore } from '../../core/allowed-directories';
import type { ApiService } from '../../core/api';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { AuditExportDialog, isExportDay, type AuditExportRequest } from './audit-export-dialog';

/**
 * The audit database's Export dialog (Story 21.10): the server-path picker for a new file, the optional day field with the
 * line that says an empty field exports every record, and an Export that emits the chosen file and day; the instance's
 * refusals are drawn on the field they name, or as an alert.
 */

@Component({
  imports: [AuditExportDialog],
  template: `<app-audit-export-dialog
    [store]="store"
    [rootReason]="rootReason()"
    [pathReason]="pathReason()"
    [beforeReason]="beforeReason()"
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
  readonly beforeReason = signal('');
  readonly refusal = signal('');
  readonly sending = signal(false);
  readonly submitted: AuditExportRequest[] = [];
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

function typeName(host: HTMLElement, value: string): void {
  const input = host.querySelector('input.ocu-field-input') as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input'));
}

function typeDay(host: HTMLElement, value: string): void {
  const input = host.querySelector('[data-audit-export-before]') as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input'));
}

const confirmOf = (host: HTMLElement) => host.querySelector('[data-audit-export-confirm]') as HTMLButtonElement;

describe('the audit database Export dialog', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
  });

  it('isExportDay admits a real day written YYYY-MM-DD up to today and nothing else', () => {
    const today = new Date(2026, 10, 19, 15, 30);
    expect(isExportDay('2026-11-19', today)).toBe(true);
    expect(isExportDay('2024-02-29', today)).toBe(true);
    expect(isExportDay('', today)).toBe(false);
    expect(isExportDay('19/11/2026', today)).toBe(false);
    expect(isExportDay('2026-1-9', today)).toBe(false);
    expect(isExportDay(' 2026-11-19', today)).toBe(false);
    // Mutation (Rule 19): drop the real-day check from isExportDay -> this goes red.
    expect(isExportDay('2026-02-30', today)).toBe(false);
    // Mutation (Rule 19): drop the up-to-today check from isExportDay -> this goes red.
    expect(isExportDay('2026-11-20', today)).toBe(false);
  });

  it('is titled Export, offers a file picker over the allowed directories and the day field with the line about every record', async () => {
    const { host } = await mount();
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.taskExportAction);
    const select = host.querySelector('select') as HTMLSelectElement;
    expect(Array.from(select.options).map((option) => option.value)).toEqual([ROOT]);
    const day = host.querySelector('[data-audit-export-before]') as HTMLInputElement;
    expect(host.querySelector(`label[for="${day.id}"]`)?.textContent?.trim()).toBe(STRINGS.auditExportBefore);
    expect(host.querySelector('[data-audit-export-hint]')?.textContent?.trim()).toBe(STRINGS.auditExportBeforeHint);
    expect(day.getAttribute('aria-describedby')).toBe(host.querySelector('[data-audit-export-hint]')?.id);
    expect(confirmOf(host).textContent?.trim()).toBe(STRINGS.taskExportAction);
  });

  // mutation: `confirmDisabled` ignores an empty path -> Export is available with no name and this goes red.
  it('Export stays unavailable until a name is typed, then emits the root, the name and an empty day', async () => {
    const { fixture, host, component } = await mount();
    expect(confirmOf(host).getAttribute('aria-disabled')).toBe('true');
    confirmOf(host).click();
    expect(component.submitted).toEqual([]);
    typeName(host, 'out/audit.xml');
    await settle(fixture);
    expect(confirmOf(host).getAttribute('aria-disabled')).toBeNull();
    confirmOf(host).click();
    expect(component.submitted).toEqual([{ root: ROOT, path: 'out/audit.xml', before: '' }]);
    component.sending.set(true);
    await settle(fixture);
    expect(confirmOf(host).getAttribute('aria-disabled')).toBe('true');
  });

  // mutation: `confirmDisabled` drops the `dayRefused` term -> a malformed day is sent and this goes red.
  it('holds Export while a day is typed that is not YYYY-MM-DD, and emits a good one beside the file', async () => {
    const { fixture, host, component } = await mount();
    typeName(host, 'audit.xml');
    typeDay(host, 'yesterday');
    await settle(fixture);
    expect(confirmOf(host).getAttribute('aria-disabled')).toBe('true');
    expect((host.querySelector('[data-audit-export-before]') as HTMLInputElement).getAttribute('aria-invalid')).toBe('true');
    confirmOf(host).click();
    expect(component.submitted).toEqual([]);
    typeDay(host, ' 2026-11-19 ');
    await settle(fixture);
    expect(confirmOf(host).getAttribute('aria-disabled')).toBeNull();
    confirmOf(host).click();
    expect(component.submitted).toEqual([{ root: ROOT, path: 'audit.xml', before: '2026-11-19' }]);
  });

  it('draws a refusal on the field it names, and any other refusal as an alert', async () => {
    const { fixture, host, component } = await mount();
    component.pathReason.set('A file already stands at that name.');
    component.rootReason.set('Choose an allowed directory.');
    component.beforeReason.set('That day is after today.');
    await settle(fixture);
    const errors = Array.from(host.querySelectorAll('.ocu-form-error')).map((node) => node.textContent?.trim());
    expect(errors).toEqual(['Choose an allowed directory.', 'A file already stands at that name.']);
    expect(host.querySelector('[data-audit-export-before-reason]')?.textContent?.trim()).toBe('That day is after today.');
    expect((host.querySelector('[data-audit-export-before]') as HTMLInputElement).getAttribute('aria-invalid')).toBe('true');
    expect(host.querySelector('[data-audit-export-refusal]')).toBeNull();
    component.refusal.set('The export could not be started.');
    await settle(fixture);
    const alert = host.querySelector('[data-audit-export-refusal]');
    expect(alert?.getAttribute('role')).toBe('alert');
    expect(alert?.textContent?.trim()).toBe('The export could not be started.');
  });

  it('Cancel emits cancelled and nothing else', async () => {
    const { host, component } = await mount();
    (host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement).click();
    expect(component.cancelled).toBe(1);
    expect(component.submitted).toEqual([]);
  });
});
