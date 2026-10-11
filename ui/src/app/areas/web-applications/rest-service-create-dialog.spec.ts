import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { RestServiceCreateDialog } from './rest-service-create-dialog';

/**
 * The Create REST service dialog (Story 18.34): its published words, a Create that stays unavailable
 * until both fields hold text, the package and the document posted to the namespace it was given, a
 * file loaded into the document field, and the server's two kinds of refusal drawn where each belongs.
 */

@Component({
  imports: [RestServiceCreateDialog],
  template: `<app-rest-service-create-dialog [namespace]="namespace()" (created)="created.push($event)" (cancelled)="cancelled = cancelled + 1" />`,
})
class Host {
  readonly namespace = signal('USER');
  readonly created: string[] = [];
  cancelled = 0;
}

const planted: HTMLElement[] = [];

const TEXT = '{"swagger": "2.0", "info": {"title": "probe", "version": "1"}, "paths": {}}';

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 3; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(answer: JsonResult<unknown> | Promise<JsonResult<unknown>>) {
  TestBed.resetTestingModule();
  const sent: { path: string; scope: string | null | undefined; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      sent.push({ path, scope: init.scope, body: typeof init.body === 'string' ? init.body : '' });
      return (await answer) as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  const fixture = TestBed.createComponent(Host);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await fixture.whenStable();
  return { fixture, host: fixture.nativeElement as HTMLElement, sent };
}

function nameField(host: HTMLElement): HTMLInputElement {
  return host.querySelector('input[data-rest-service-create-name]') as HTMLInputElement;
}

function documentField(host: HTMLElement): HTMLTextAreaElement {
  return host.querySelector('textarea[data-rest-service-create-document]') as HTMLTextAreaElement;
}

function fill(fixture: ComponentFixture<unknown>, host: HTMLElement, name: string, text: string): void {
  nameField(host).value = name;
  nameField(host).dispatchEvent(new Event('input'));
  documentField(host).value = text;
  documentField(host).dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

function confirm(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('[data-rest-service-create-confirm]') as HTMLButtonElement;
}

describe('the Create REST service dialog', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
    TestBed.resetTestingModule();
  });

  it('is titled, labeled and hinted with the published words, and Create is unavailable until both fields hold text', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: {} });
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.restServiceCreateTitle);
    expect(host.querySelector(`label[for="${nameField(host).id}"]`)?.textContent?.trim()).toBe(STRINGS.tableColumnName);
    expect(host.querySelector(`#${nameField(host).getAttribute('aria-describedby')}`)?.textContent?.trim()).toBe(STRINGS.restServiceNameHint);
    expect(host.querySelector(`label[for="${documentField(host).id}"]`)?.textContent?.trim()).toBe(STRINGS.restServiceDocumentLabel);
    expect(host.querySelector(`#${documentField(host).getAttribute('aria-describedby')}`)?.textContent?.trim()).toBe(STRINGS.restServiceDocumentHint);
    expect(host.querySelector('[data-rest-service-create-load]')?.textContent?.trim()).toBe(STRINGS.x509LoadFromFile);
    expect(confirm(host).textContent?.trim()).toBe(STRINGS.restServiceCreateTitle);
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    // Mutation (Rule 19): drop the document check from `confirmDisabled` -> Create stays available on a blank document and this goes red.
    fill(fixture, host, 'OcuProbe1832A', '   ');
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    fill(fixture, host, '   ', TEXT);
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    confirm(host).click();
    await settle(fixture);
    expect(sent).toEqual([]);
  });

  it('Create posts the package and the document text as typed to the namespace given and emits the package once the instance built it', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: { name: 'OcuProbe1832A', readBack: { verdict: 'matches' } } });
    fill(fixture, host, 'OcuProbe1832A', TEXT);
    expect(confirm(host).getAttribute('aria-disabled')).toBeNull();
    confirm(host).click();
    await settle(fixture);
    expect(sent.map((call) => [call.path, call.scope, JSON.parse(call.body)])).toEqual([['/api/ocupilot/rest-service', 'USER', { Name: 'OcuProbe1832A', Document: TEXT }]]);
    expect((fixture.componentInstance as Host).created).toEqual(['OcuProbe1832A']);
  });

  it('Create is unavailable while a create is in flight, and a second click posts nothing', async () => {
    let release: (result: JsonResult<unknown>) => void = () => undefined;
    const pending = new Promise<JsonResult<unknown>>((resolve) => {
      release = resolve;
    });
    const { fixture, host, sent } = await mount(pending);
    fill(fixture, host, 'OcuProbe1832A', TEXT);
    confirm(host).click();
    await settle(fixture);
    // Mutation (Rule 19): drop `this.store.busy() ||` from `confirmDisabled` -> Create stays available while the post is pending and this goes red.
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    confirm(host).click();
    await settle(fixture);
    expect(sent.length).toBe(1);
    release({ kind: 'ok', status: 201, body: { name: 'OcuProbe1832A' } });
    await settle(fixture);
    expect((fixture.componentInstance as Host).created).toEqual(['OcuProbe1832A']);
  });

  it('Load from file opens the file picker and puts the file\u2019s text in the document field, as a file input that takes JSON', async () => {
    const { fixture, host } = await mount({ kind: 'ok', status: 201, body: {} });
    const picker = host.querySelector('input[data-rest-service-create-file]') as HTMLInputElement;
    expect(picker.getAttribute('type')).toBe('file');
    expect(picker.getAttribute('accept')).toBe('.json');
    let opened = 0;
    picker.addEventListener('click', (event) => {
      opened += 1;
      event.preventDefault();
    });
    (host.querySelector('[data-rest-service-create-load]') as HTMLButtonElement).click();
    // Mutation (Rule 19): make `pickFile` open nothing -> the button is dead and this goes red.
    expect(opened).toBe(1);
    Object.defineProperty(picker, 'files', { configurable: true, value: [new File([TEXT], 'probe.json', { type: 'application/json' })] });
    picker.dispatchEvent(new Event('change'));
    await settle(fixture);
    expect(documentField(host).value).toBe(TEXT);
    expect(nameField(host).value).toBe('');
  });

  it('a refusal on Name and one on Document are each drawn under their field and named by it, and nothing is emitted', async () => {
    const violations = [
      { field: 'Name', code: 'RESTSERVICE.TAKEN', reason: 'the name sentence' },
      { field: 'Document', code: 'RESTSERVICE.DOCUMENT', reason: 'the document sentence' },
    ];
    const { fixture, host } = await mount({ kind: 'error', status: 422, code: 'RESTSERVICE.TAKEN', reason: 'the name sentence', detail: { violations } });
    fill(fixture, host, 'OcuProbe1832A', TEXT);
    confirm(host).click();
    await settle(fixture);
    const nameError = host.querySelector('[data-rest-service-create-name-violation]') as HTMLElement;
    const documentError = host.querySelector('[data-rest-service-create-document-violation]') as HTMLElement;
    expect(nameError.textContent?.trim()).toBe('the name sentence');
    expect(documentError.textContent?.trim()).toBe('the document sentence');
    expect(nameField(host).getAttribute('aria-invalid')).toBe('true');
    expect(nameField(host).getAttribute('aria-describedby')?.split(' ')).toContain(nameError.id);
    expect(documentField(host).getAttribute('aria-invalid')).toBe('true');
    expect(documentField(host).getAttribute('aria-describedby')?.split(' ')).toContain(documentError.id);
    expect(host.querySelector('[data-rest-service-create-reason]')).toBeNull();
    expect((fixture.componentInstance as Host).created).toEqual([]);
  });

  it('a refusal that names no field is the dialog\u2019s alert, and nothing is emitted', async () => {
    const { fixture, host } = await mount({ kind: 'error', status: 409, code: 'WRITE.TARGETBUSY', reason: 'the busy sentence', detail: null });
    fill(fixture, host, 'OcuProbe1832A', TEXT);
    confirm(host).click();
    await settle(fixture);
    const alert = host.querySelector('[data-rest-service-create-reason]') as HTMLElement;
    expect(alert.getAttribute('role')).toBe('alert');
    expect(alert.textContent?.trim()).toBe('the busy sentence');
    expect((fixture.componentInstance as Host).created).toEqual([]);
  });
});
