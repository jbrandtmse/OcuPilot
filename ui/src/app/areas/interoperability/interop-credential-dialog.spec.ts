import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { InteropCredentialDialog, type CredentialDialogMode } from './interop-credential-dialog';
import { InteropCredentialStore, type CredentialValues } from './interop-credential.store';

/**
 * The New credential, Edit and Set password dialog (Story 24.15): its published words in each mode, a button that stays unavailable until the name
 * (or the password) is typed, the credential posted to the namespace it was given with the password read from its field once and cleared, an Edit that
 * holds the name read-only and hands its values to the page, a Set password that hands the password alone, and the server's two kinds of refusal drawn
 * where each belongs.
 */

@Component({
  imports: [InteropCredentialDialog],
  template: `<app-interop-credential-dialog
    [namespace]="namespace()"
    [mode]="mode()"
    [credential]="credential()"
    (added)="added.push($event)"
    (submitted)="submitted.push($event)"
    (passwordSubmitted)="passwords.push($event)"
    (cancelled)="cancelled = cancelled + 1"
  />`,
})
class Host {
  readonly namespace = signal('USER');
  readonly mode = signal<CredentialDialogMode>('add');
  readonly credential = signal<string | null>(null);
  readonly added: string[] = [];
  readonly submitted: CredentialValues[] = [];
  readonly passwords: string[] = [];
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

async function mount(answer: JsonResult<unknown>, mode: CredentialDialogMode = 'add', credential: string | null = null, initial: CredentialValues | null = null) {
  TestBed.resetTestingModule();
  const sent: { path: string; scope: string | null | undefined; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      sent.push({ path, scope: init.scope, body: typeof init.body === 'string' ? init.body : '' });
      if (path.includes('/screens/interop.businesspartners/read')) return { kind: 'ok', status: 200, body: { rows: [{ Name: 'PartnerA' }, { Name: 'PartnerB' }] } } as JsonResult<T>;
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
  TestBed.inject(InteropCredentialStore).reset(initial);
  const fixture = TestBed.createComponent(Host);
  fixture.componentInstance.mode.set(mode);
  fixture.componentInstance.credential.set(credential);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, sent };
}

function field(host: HTMLElement, name: string): HTMLInputElement | HTMLSelectElement {
  return host.querySelector(`[data-interop-credential-field="${name}"]`) as HTMLInputElement | HTMLSelectElement;
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, name: string, value: string): void {
  const input = field(host, name);
  input.value = value;
  input.dispatchEvent(new Event(input.tagName === 'SELECT' ? 'change' : 'input'));
  fixture.detectChanges();
}

function confirm(host: HTMLElement): HTMLButtonElement {
  return host.querySelector('[data-interop-credential-confirm]') as HTMLButtonElement;
}

describe('the New credential, Edit and Set password dialog', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
    TestBed.resetTestingModule();
  });

  it('as New credential, draws the name, user name, business partner and masked password under their published words, and needs a name', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: {} });
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopCredentialAddAction);
    expect(host.querySelector('[data-interop-credential-help]')?.textContent?.trim()).toBe(STRINGS.interopCredentialHelp);
    const labels = ['Name', 'Username', 'BusinessPartner', 'Password'].map((name) => host.querySelector(`label[for="${field(host, name).id}"]`)?.textContent?.trim());
    expect(labels).toEqual([STRINGS.tableColumnName, STRINGS.fieldUserName, STRINGS.interopCredentialBusinessPartner, STRINGS.fieldPassword]);
    expect((field(host, 'Password') as HTMLInputElement).type).toBe('password');
    expect((field(host, 'Password') as HTMLInputElement).autocomplete).toBe('new-password');
    expect(field(host, 'Name').getAttribute('readonly')).toBeNull();
    expect(Array.from((field(host, 'BusinessPartner') as HTMLSelectElement).options).map((option) => option.textContent?.trim())).toEqual([STRINGS.sslVerifyPeerNone, 'PartnerA', 'PartnerB']);
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    const before = sent.length;
    confirm(host).click();
    await settle(fixture);
    expect(sent.length).toBe(before);
  });

  it('posts the credential as typed to the namespace given, reads the password from its field, clears it and emits added', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 201, body: { id: 'Probe', target: { type: 'interop-credential', scope: 'USER', id: 'Probe' }, readBack: { verdict: 'matches' } } });
    type(fixture, host, 'Name', 'Probe');
    type(fixture, host, 'Username', 'probe');
    type(fixture, host, 'BusinessPartner', 'PartnerB');
    type(fixture, host, 'Password', 'OcuPw1');
    expect(confirm(host).getAttribute('aria-disabled')).toBeNull();
    confirm(host).click();
    await settle(fixture);
    const posts = sent.filter((entry) => entry.path.endsWith('/interop/credentials'));
    expect(posts).toHaveLength(1);
    expect(posts[0].scope).toBe('USER');
    expect(JSON.parse(posts[0].body)).toEqual({ Name: 'Probe', Username: 'probe', BusinessPartner: 'PartnerB', Password: 'OcuPw1' });
    expect(fixture.componentInstance.added).toEqual(['Probe']);
    // Mutation (Rule 19): leave the typed password in the field after the submit -> this goes red.
    expect((field(host, 'Password') as HTMLInputElement | null)?.value ?? '').toBe('');
  });

  it('as Edit, shows the name read-only with no password field, and hands its values to the page', async () => {
    const { fixture, host, sent } = await mount({ kind: 'ok', status: 200, body: {} }, 'edit', 'Probe', { Name: 'Probe', Username: 'held', BusinessPartner: 'PartnerA' });
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopCredentialEditTitle.replace('<name>', 'Probe'));
    expect(field(host, 'Name').getAttribute('readonly')).not.toBeNull();
    expect(host.querySelector('[data-interop-credential-field="Password"]')).toBeNull();
    expect(field(host, 'Username').value).toBe('held');
    expect(field(host, 'BusinessPartner').value).toBe('PartnerA');
    type(fixture, host, 'Username', 'changed');
    const before = sent.filter((entry) => entry.path.endsWith('/interop/credentials')).length;
    confirm(host).click();
    await settle(fixture);
    expect(fixture.componentInstance.submitted).toEqual([{ Name: 'Probe', Username: 'changed', BusinessPartner: 'PartnerA' }]);
    expect(sent.filter((entry) => entry.path.endsWith('/interop/credentials')).length).toBe(before);
  });

  it('as Set password, draws the masked field alone, stays unavailable while it is empty, and hands the password untrimmed', async () => {
    const { fixture, host } = await mount({ kind: 'ok', status: 200, body: {} }, 'password', 'Probe');
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.userActionSetPassword);
    expect(host.querySelector('[data-interop-credential-field="Name"]')).toBeNull();
    expect(host.querySelector('[data-interop-credential-help]')).toBeNull();
    expect(confirm(host).getAttribute('aria-disabled')).toBe('true');
    confirm(host).click();
    expect(fixture.componentInstance.passwords).toEqual([]);
    type(fixture, host, 'Password', ' OcuPw2 ');
    expect(confirm(host).getAttribute('aria-disabled')).toBeNull();
    confirm(host).click();
    await settle(fixture);
    expect(fixture.componentInstance.passwords).toEqual([' OcuPw2 ']);
    expect((field(host, 'Password') as HTMLInputElement).value).toBe('');
  });

  it('draws a refusal on a field under it and one that names none above the fields', async () => {
    const violation = { field: 'Name', code: 'INTEROP.CREDENTIAL.NAME', reason: STRINGS.interopCredentialRefusalName };
    const named = await mount({ kind: 'error', status: 422, code: 'INTEROP.CREDENTIAL.NAME', reason: STRINGS.interopCredentialRefusalName, detail: { violations: [violation] } });
    type(named.fixture, named.host, 'Name', 'x');
    confirm(named.host).click();
    await settle(named.fixture);
    expect(named.host.querySelector('[data-interop-credential-violation="Name"]')?.textContent?.trim()).toBe(STRINGS.interopCredentialRefusalName);
    expect(field(named.host, 'Name').getAttribute('aria-invalid')).toBe('true');
    expect(named.host.querySelector('[data-interop-credential-reason]')).toBeNull();
    for (const element of planted.splice(0)) element.remove();
    const taken = await mount({ kind: 'error', status: 409, code: 'INTEROP.CREDENTIAL.TAKEN', reason: STRINGS.interopCredentialRefusalTaken, detail: null });
    type(taken.fixture, taken.host, 'Name', 'Held');
    confirm(taken.host).click();
    await settle(taken.fixture);
    expect(taken.host.querySelector('[data-interop-credential-reason]')?.textContent?.trim()).toBe(STRINGS.interopCredentialRefusalTaken);
    expect(taken.fixture.componentInstance.added).toEqual([]);
  });
});
