import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { InteropBusinessPartnerDialog } from './interop-business-partner-dialog';
import { INTEROP_PARTNER_VALUE_FIELDS, InteropBusinessPartnerStore, type PartnerValues } from './interop-business-partner.store';

/**
 * The New business partner and Edit dialog (Story 20.26): its published words in both modes, three groups of fields, a button that
 * stays unavailable until the name is typed, the partner posted to the namespace it was given, an Edit that holds its name
 * read-only beside the rename note and hands its values to the page, and the server's two kinds of refusal drawn where each belongs.
 */

@Component({
  imports: [InteropBusinessPartnerDialog],
  template: `<app-interop-business-partner-dialog
    [namespace]="namespace()"
    [partner]="partner()"
    (added)="added.push($event)"
    (submitted)="submitted.push($event)"
    (cancelled)="cancelled = cancelled + 1"
  />`,
})
class Host {
  readonly namespace = signal('USER');
  readonly partner = signal<string | null>(null);
  readonly added: string[] = [];
  readonly submitted: PartnerValues[] = [];
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

async function mount(answer: JsonResult<unknown>, partner: string | null = null, initial: PartnerValues = {}) {
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
  TestBed.inject(InteropBusinessPartnerStore).reset(initial);
  const fixture = TestBed.createComponent(Host);
  fixture.componentInstance.partner.set(partner);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await fixture.whenStable();
  return { fixture, host: fixture.nativeElement as HTMLElement, sent };
}

function field(host: HTMLElement, name: string): HTMLInputElement | HTMLTextAreaElement {
  return host.querySelector(`[data-interop-partner-field="${name}"]`) as HTMLInputElement | HTMLTextAreaElement;
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, name: string, value: string): void {
  const input = field(host, name);
  input.value = value;
  input.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

function confirm(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('[data-interop-partner-confirm]') as HTMLButtonElement;
}

describe('the New business partner and Edit dialog', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
    TestBed.resetTestingModule();
  });

  it('as New business partner, draws the name and description and the two contacts\u2019 six fields each under their published words, and needs a name', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: {} });
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopPartnerAddAction);
    expect(host.querySelector('[data-interop-partner-help]')?.textContent?.trim()).toBe(STRINGS.interopPartnerHelp);
    expect(host.querySelector('[data-interop-partner-rename-note]')).toBeNull();
    const name = field(host, 'Name') as HTMLInputElement;
    expect(host.querySelector(`label[for="${name.id}"]`)?.textContent?.trim()).toBe(STRINGS.tableColumnName);
    expect(name.readOnly).toBe(false);
    const legends = [...host.querySelectorAll('fieldset legend')].map((legend) => legend.textContent?.trim());
    expect(legends).toEqual([STRINGS.interopPartnerColumnContact, STRINGS.interopPartnerAlternativeContact]);
    for (const prefix of ['Primary', 'Alternative']) {
      const labels = ['Contact', 'Title', 'Email', 'Phone', 'Mobile', 'Notes'].map((suffix) => {
        const control = field(host, `${prefix}${suffix}`);
        return host.querySelector(`label[for="${control.id}"]`)?.textContent?.trim();
      });
      expect(labels).toEqual([STRINGS.tableColumnName, STRINGS.interopPartnerFieldTitle, STRINGS.userFieldEmail, STRINGS.interopPartnerColumnPhone, STRINGS.interopPartnerFieldMobile, STRINGS.interopPartnerFieldNotes]);
    }
    expect(field(host, 'Description').tagName).toBe('TEXTAREA');
    expect(field(host, 'PrimaryNotes').tagName).toBe('TEXTAREA');
    expect(field(host, 'AlternativeNotes').tagName).toBe('TEXTAREA');
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    confirm(host).click();
    await settle(fixture);
    expect(sent).toEqual([]);
    type(fixture, host, 'Name', 'Probe Partner');
    expect(confirm(host).getAttribute('aria-disabled')).toBeNull();
  });

  it('as New business partner, posts the typed name and every field to the namespace given, and emits the name once the instance added it', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: { readBack: { verdict: 'matches' } } });
    type(fixture, host, 'Name', 'Probe Partner');
    type(fixture, host, 'Description', 'line one\nline two');
    type(fixture, host, 'AlternativeMobile', '555-0202');
    confirm(host).click();
    await settle(fixture);
    expect(sent.map((call) => [call.path, call.scope])).toEqual([['/api/ocupilot/interop/business-partners', 'USER']]);
    const body = JSON.parse(sent[0].body) as Record<string, string>;
    expect(body['Name']).toBe('Probe Partner');
    expect(body['Description']).toBe('line one\nline two');
    expect(body['AlternativeMobile']).toBe('555-0202');
    expect(Object.keys(body)).toHaveLength(1 + INTEROP_PARTNER_VALUE_FIELDS.length);
    expect((fixture.componentInstance as Host).added).toEqual(['Probe Partner']);
  });

  it('as Edit, titles the dialog by the partner, holds its name read-only beside the rename note, and hands the values to the page without posting', async () => {
    // Mutation (Rule 19): make the name field writable in Edit -> the read-only and `aria-readonly` assertions go red.
    const initial = { Name: 'Probe Partner', Description: 'held', PrimaryPhone: '555-0100' };
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 200, body: {} }, 'Probe Partner', initial);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopPartnerEditTitle.replace('<name>', 'Probe Partner'));
    expect(host.querySelector('[data-interop-partner-rename-note]')?.textContent?.trim()).toBe(STRINGS.interopPartnerRenameNote);
    const name = field(host, 'Name') as HTMLInputElement;
    expect(name.value).toBe('Probe Partner');
    expect(name.readOnly).toBe(true);
    expect(name.getAttribute('aria-readonly')).toBe('true');
    expect(field(host, 'Description').value).toBe('held');
    type(fixture, host, 'Name', 'Renamed');
    type(fixture, host, 'PrimaryPhone', '');
    confirm(host).click();
    await settle(fixture);
    expect(sent).toEqual([]);
    const submitted = (fixture.componentInstance as Host).submitted;
    expect(submitted).toHaveLength(1);
    expect(submitted[0]['Name']).toBe('Probe Partner');
    expect(submitted[0]['Description']).toBe('held');
    expect(submitted[0]['PrimaryPhone']).toBe('');
    expect((fixture.componentInstance as Host).added).toEqual([]);
  });

  it('draws a refusal on a field under the field and names it by it, and emits nothing', async () => {
    const violation = { field: 'PrimaryPhone', code: 'INTEROP.PARTNER.LENGTH', reason: STRINGS.interopPartnerRefusalLength };
    const { fixture, host } = await mount({ kind: 'error', status: 422, code: 'INTEROP.PARTNER.LENGTH', reason: STRINGS.interopPartnerRefusalLength, detail: { violations: [violation] } });
    type(fixture, host, 'Name', 'Probe Partner');
    type(fixture, host, 'PrimaryPhone', 'x'.repeat(51));
    confirm(host).click();
    await settle(fixture);
    const input = field(host, 'PrimaryPhone');
    const error = host.querySelector('[data-interop-partner-violation="PrimaryPhone"]') as HTMLElement;
    expect(error.textContent?.trim()).toBe(STRINGS.interopPartnerRefusalLength);
    expect(input.getAttribute('aria-invalid')).toBe('true');
    expect(input.getAttribute('aria-describedby')).toBe(error.id);
    expect(host.querySelector('[data-interop-partner-reason]')).toBeNull();
    expect((fixture.componentInstance as Host).added).toEqual([]);
  });

  it('draws a refusal on the name under the name field, and one that names no field as the dialog\u2019s alert', async () => {
    const violation = { field: 'Name', code: 'INTEROP.PARTNER.NAME', reason: STRINGS.interopPartnerRefusalName };
    const named = await mount({ kind: 'error', status: 422, code: 'INTEROP.PARTNER.NAME', reason: STRINGS.interopPartnerRefusalName, detail: { violations: [violation] } });
    type(named.fixture, named.host, 'Name', 'bad');
    confirm(named.host).click();
    await settle(named.fixture);
    expect(named.host.querySelector('[data-interop-partner-violation="Name"]')?.textContent?.trim()).toBe(STRINGS.interopPartnerRefusalName);
    expect(field(named.host, 'Name').getAttribute('aria-invalid')).toBe('true');
    named.host.remove();
    const taken = await mount({ kind: 'error', status: 409, code: 'INTEROP.PARTNER.TAKEN', reason: STRINGS.interopPartnerRefusalTaken, detail: null });
    type(taken.fixture, taken.host, 'Name', 'Probe Partner');
    confirm(taken.host).click();
    await settle(taken.fixture);
    const alert = taken.host.querySelector('[data-interop-partner-reason]') as HTMLElement;
    expect(alert.getAttribute('role')).toBe('alert');
    expect(alert.textContent?.trim()).toBe(STRINGS.interopPartnerRefusalTaken);
    expect((taken.fixture.componentInstance as Host).added).toEqual([]);
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
