import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { PCT_ACCESS_SAVE_PATH, WebAppClassAccessDialog } from './web-app-class-access-dialog';

/**
 * The percent-class access add dialog over a stub of the API (Story 18.10). It posts the entry to
 * `POST /web-app/pct-access`, and a refusal is the envelope's own sentence with the fields kept.
 */

const planted: HTMLElement[] = [];

async function mount(answer: JsonResult<unknown>) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      return answer as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  const fixture: ComponentFixture<WebAppClassAccessDialog> = TestBed.createComponent(WebAppClassAccessDialog);
  fixture.componentRef.setInput('application', '/csp/probe');
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await fixture.whenStable();
  return { fixture, calls, host: fixture.nativeElement as HTMLElement };
}

function type(fixture: ComponentFixture<unknown>, host: HTMLElement, selector: string, value: string): void {
  const input = host.querySelector(selector) as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

afterEach(() => {
  for (const element of planted.splice(0)) element.remove();
  TestBed.resetTestingModule();
});

describe('the percent class access add dialog (Story 18.10)', () => {
  it('labels its primary button with the percent class access key', async () => {
    const { host } = await mount({ kind: 'ok', status: 201, body: {} });
    expect((host.querySelector('.ocu-button-primary') as HTMLButtonElement).textContent?.trim()).toBe(STRINGS.webAppPctAccessAdd);
  });

  it('posts the entry to the route and reports it added', async () => {
    const { fixture, calls, host } = await mount({ kind: 'ok', status: 201, body: { name: '/csp/probe' } });
    let added = 0;
    fixture.componentInstance.added.subscribe(() => (added += 1));
    type(fixture, host, 'input[type="text"]', ' %Api.Admin ');
    (host.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await fixture.whenStable();
    expect(calls.length).toBe(1);
    expect(calls[0].path).toBe(PCT_ACCESS_SAVE_PATH);
    expect(calls[0].method).toBe('POST');
    expect(JSON.parse(calls[0].body)).toEqual({ Name: '/csp/probe', AllowType: 'AllowClass', Class: '%Api.Admin', AllowAccess: true });
    expect(added).toBe(1);
  });

  it('sends all-applications when the choice to apply to every application is ticked', async () => {
    const { fixture, calls, host } = await mount({ kind: 'ok', status: 201, body: {} });
    type(fixture, host, 'input[type="text"]', '%Api.Admin');
    const all = [...host.querySelectorAll('input[type="checkbox"]')][1] as HTMLInputElement;
    all.checked = true;
    all.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    (host.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await fixture.whenStable();
    expect(JSON.parse(calls[0].body).Name).toBe('all-applications');
  });

  it('sends the allow type chosen and an entry that denies access when Allow access is cleared', async () => {
    // Mutation (Rule 19): post `AllowType: ALLOW_TYPES[0]` or `AllowAccess: true` in `submit` -> red.
    const { fixture, calls, host } = await mount({ kind: 'ok', status: 201, body: {} });
    const select = host.querySelector('select') as HTMLSelectElement;
    select.value = 'AllowPrefix';
    select.dispatchEvent(new Event('change'));
    type(fixture, host, 'input[type="text"]', '%Api.');
    const access = [...host.querySelectorAll('input[type="checkbox"]')][0] as HTMLInputElement;
    access.checked = false;
    access.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    (host.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await fixture.whenStable();
    expect(JSON.parse(calls[0].body)).toEqual({ Name: '/csp/probe', AllowType: 'AllowPrefix', Class: '%Api.', AllowAccess: false });
  });

  it('shows a refusal on the dialog and keeps the entry for another try', async () => {
    const { fixture, host } = await mount({ kind: 'error', status: 409, code: 'PCTACCESS.EXISTS', reason: STRINGS.pctAccessRefusalSystem, detail: null } as never);
    type(fixture, host, 'input[type="text"]', '%Api.Admin');
    (host.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
    await fixture.whenStable();
    fixture.detectChanges();
    const alert = host.querySelector('[role="alert"]');
    expect(alert?.textContent?.trim()).toBe(STRINGS.pctAccessRefusalSystem);
    expect((host.querySelector('input[type="text"]') as HTMLInputElement).value).toBe('%Api.Admin');
  });
});
