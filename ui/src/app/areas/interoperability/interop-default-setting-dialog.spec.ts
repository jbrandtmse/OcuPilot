import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { InteropDefaultSettingDialog } from './interop-default-setting-dialog';
import { InteropDefaultSettingStore, type DefaultSettingValues } from './interop-default-setting.store';

/**
 * The New default setting and Edit dialog (Story 24.15): its published words in both modes, a button that stays unavailable until the
 * setting's name is typed, the setting posted to the namespace it was given with its flag as a boolean, an Edit that holds the key read-only
 * and hands its values to the page, and the server's two kinds of refusal drawn where each belongs.
 */

@Component({
  imports: [InteropDefaultSettingDialog],
  template: `<app-interop-default-setting-dialog
    [namespace]="namespace()"
    [setting]="setting()"
    (added)="added.push($event)"
    (submitted)="submitted.push($event)"
    (cancelled)="cancelled = cancelled + 1"
  />`,
})
class Host {
  readonly namespace = signal('USER');
  readonly setting = signal<string | null>(null);
  readonly added: string[] = [];
  readonly submitted: DefaultSettingValues[] = [];
  cancelled = 0;
}

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 3; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(answer: JsonResult<unknown>, setting: string | null = null, initial: DefaultSettingValues | null = null) {
  TestBed.resetTestingModule();
  const sent: { path: string; scope: string | null | undefined; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      sent.push({ path, scope: init.scope, body: typeof init.body === 'string' ? init.body : '' });
      return answer as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  TestBed.inject(InteropDefaultSettingStore).reset(initial);
  const fixture = TestBed.createComponent(Host);
  fixture.componentInstance.setting.set(setting);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await fixture.whenStable();
  return { fixture, host: fixture.nativeElement as HTMLElement, sent };
}

function field(host: HTMLElement, name: string): HTMLInputElement | HTMLTextAreaElement {
  return host.querySelector(`[data-interop-default-setting-field="${name}"]`) as HTMLInputElement | HTMLTextAreaElement;
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, name: string, value: string): void {
  const input = field(host, name);
  input.value = value;
  input.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

function confirm(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('[data-interop-default-setting-confirm]') as HTMLButtonElement;
}

describe('the New default setting and Edit dialog', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
    TestBed.resetTestingModule();
  });

  it('as New default setting, draws the key, the value, the description and the flag under their published words, and needs a setting name', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: {} });
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopDefaultSettingAddAction);
    expect(host.querySelector('[data-interop-default-setting-help]')?.textContent?.trim()).toBe(STRINGS.interopDefaultSettingHelp);
    const labels = ['Production', 'Item', 'HostClass', 'Setting', 'Value', 'Description'].map((name) => {
      const control = field(host, name);
      return host.querySelector(`label[for="${control.id}"]`)?.textContent?.trim();
    });
    expect(labels).toEqual([STRINGS.systemInfoProduction, STRINGS.interopItemSettingsCriterionItem, STRINGS.interopItemColumnClass, STRINGS.agentGovernanceColumnSetting, STRINGS.errorLogColumnValue, STRINGS.tableColumnDescription]);
    expect(field(host, 'Production').value).toBe('*');
    expect(field(host, 'Production').readOnly).toBe(false);
    expect(field(host, 'Description').tagName).toBe('TEXTAREA');
    const flag = field(host, 'Deployable') as HTMLInputElement;
    expect(flag.type).toBe('checkbox');
    expect(host.querySelector(`#${flag.getAttribute('aria-describedby')}`)?.textContent?.trim()).toBe(STRINGS.interopDefaultSettingDeployableHelp);
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    confirm(host).click();
    await settle(fixture);
    expect(sent).toEqual([]);
    type(fixture, host, 'Setting', 'ArchiveIO');
    expect(confirm(host).getAttribute('aria-disabled')).toBeNull();
  });

  it('as New default setting, posts the typed key and fields, the flag as a boolean, to the namespace given, and emits the setting once the instance added it', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: { readBack: { verdict: 'matches' } } });
    type(fixture, host, 'Production', 'Demo.Production');
    type(fixture, host, 'Setting', 'ArchiveIO');
    type(fixture, host, 'Value', '1');
    type(fixture, host, 'Description', 'line one\nline two');
    const flag = field(host, 'Deployable') as HTMLInputElement;
    flag.checked = true;
    flag.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    confirm(host).click();
    await settle(fixture);
    expect(sent.map((call) => [call.path, call.scope])).toEqual([['/api/ocupilot/interop/default-settings', 'USER']]);
    const body = JSON.parse(sent[0].body) as Record<string, unknown>;
    expect(body['Production']).toBe('Demo.Production');
    expect(body['Item']).toBe('*');
    expect(body['Setting']).toBe('ArchiveIO');
    expect(body['Value']).toBe('1');
    expect(body['Description']).toBe('line one\nline two');
    expect(body['Deployable']).toBe(true);
    expect((fixture.componentInstance as Host).added).toEqual(['ArchiveIO']);
  });

  it('as Edit, titles the dialog by the setting, holds the four key parts read-only, and hands the values to the page without posting', async () => {
    // Mutation (Rule 19): make a key part writable in Edit -> the read-only and `aria-readonly` assertions go red.
    const initial: DefaultSettingValues = { text: { Production: 'Demo.Production', Item: '*', HostClass: '*', Setting: 'ArchiveIO', Value: 'held', Description: 'd' }, deployable: true };
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 200, body: {} }, 'ArchiveIO', initial);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopDefaultSettingEditTitle.replace('<setting>', 'ArchiveIO'));
    for (const name of ['Production', 'Item', 'HostClass', 'Setting']) {
      const input = field(host, name) as HTMLInputElement;
      expect(input.readOnly).toBe(true);
      expect(input.getAttribute('aria-readonly')).toBe('true');
    }
    expect(field(host, 'Value').value).toBe('held');
    expect((field(host, 'Deployable') as HTMLInputElement).checked).toBe(true);
    type(fixture, host, 'Setting', 'Renamed');
    type(fixture, host, 'Value', '');
    confirm(host).click();
    await settle(fixture);
    expect(sent).toEqual([]);
    const submitted = (fixture.componentInstance as Host).submitted;
    expect(submitted).toHaveLength(1);
    expect(submitted[0].text['Setting']).toBe('ArchiveIO');
    expect(submitted[0].text['Value']).toBe('');
    expect(submitted[0].deployable).toBe(true);
    expect((fixture.componentInstance as Host).added).toEqual([]);
  });

  it('draws a refusal on a field under the field and names it by it, and emits nothing', async () => {
    const violation = { field: 'Value', code: 'INTEROP.DEFAULTSETTING.VALUE', reason: STRINGS.interopDefaultSettingRefusalValue };
    const { fixture, host } = await mount({ kind: 'error', status: 422, code: 'INTEROP.DEFAULTSETTING.VALUE', reason: STRINGS.interopDefaultSettingRefusalValue, detail: { violations: [violation] } });
    type(fixture, host, 'Setting', 'PoolSize');
    type(fixture, host, 'Value', '0');
    confirm(host).click();
    await settle(fixture);
    const input = field(host, 'Value');
    const error = host.querySelector('[data-interop-default-setting-violation="Value"]') as HTMLElement;
    expect(error.textContent?.trim()).toBe(STRINGS.interopDefaultSettingRefusalValue);
    expect(input.getAttribute('aria-invalid')).toBe('true');
    expect(input.getAttribute('aria-describedby')).toBe(error.id);
    expect(host.querySelector('[data-interop-default-setting-reason]')).toBeNull();
    expect((fixture.componentInstance as Host).added).toEqual([]);
  });

  it('draws a refusal that names no field as the alert of the dialog', async () => {
    const { fixture, host } = await mount({ kind: 'error', status: 409, code: 'INTEROP.DEFAULTSETTING.TAKEN', reason: STRINGS.interopDefaultSettingRefusalTaken, detail: null });
    type(fixture, host, 'Setting', 'ArchiveIO');
    confirm(host).click();
    await settle(fixture);
    const alert = host.querySelector('[data-interop-default-setting-reason]') as HTMLElement;
    expect(alert.getAttribute('role')).toBe('alert');
    expect(alert.textContent?.trim()).toBe(STRINGS.interopDefaultSettingRefusalTaken);
    expect((fixture.componentInstance as Host).added).toEqual([]);
  });

  it('emits cancelled for Cancel, sending nothing', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: {} });
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    await settle(fixture);
    expect((fixture.componentInstance as Host).cancelled).toBe(1);
    expect(sent).toEqual([]);
  });
});
