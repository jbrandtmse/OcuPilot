import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService, formatDeniedAction } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { PhoneProviderFormPage } from './phone-provider-form.page';
import { PHONE_PROVIDER_FORM_PATH, PHONE_PROVIDER_PATH } from './phone-provider-form.store';

/**
 * The mobile phone provider editor over stubs of what an instance supplies -- the form read and the Save. The real store and template run,
 * so the assertions are about rendered DOM (Story 21.10).
 */

const FORM_SCREEN = SCREENS.find((screen) => screen.route === 'security/phone-providers/edit');

const EMPTY_ROW = { Name: '', SMSGateway: '' };

const HELD_ROW = { Name: 'OcuPhoneProbeA', SMSGateway: 'sms.ocuphoneprobe.invalid' };

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

interface MountOptions {
  readonly url?: string;
  readonly row?: Record<string, unknown>;
  readonly save?: JsonResult<unknown>;
}

async function mount(options: MountOptions = {}) {
  TestBed.resetTestingModule();
  const calls: { path: string; method: string; body: string }[] = [];
  const url = options.url ?? '/security/phone-providers/edit';
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ path, method, body: init.body ?? '' });
      if (path.startsWith(PHONE_PROVIDER_FORM_PATH)) return { kind: 'ok', status: 200, body: { row: options.row ?? EMPTY_ROW } } as unknown as JsonResult<T>;
      return (options.save ?? { kind: 'ok', status: 200, body: { id: 'OcuPhoneProbeB', readBack: { verdict: 'matches', fields: [], written: [] } } }) as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: NavigationService, useValue: { screenForUrl: () => FORM_SCREEN ?? null } as unknown as NavigationService },
      { provide: FormDirty, useValue: new FormDirty() },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(url + '?ns=USER');
  const fixture = TestBed.createComponent(PhoneProviderFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return { fixture, calls, host: fixture.nativeElement as HTMLElement };
}

function control(host: HTMLElement, field: string): HTMLInputElement {
  return host.querySelector(`#ocu-phone-provider-${field}`) as HTMLInputElement;
}

async function type(fixture: ComponentFixture<unknown>, host: HTMLElement, field: string, value: string): Promise<void> {
  const input = control(host, field);
  input.value = value;
  input.dispatchEvent(new Event('input'));
  await settle(fixture);
}

function save(host: HTMLElement): void {
  (host.querySelector('.ocu-form-bar-actions .ocu-button-primary') as HTMLButtonElement).click();
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('PhoneProviderFormPage', () => {
  it('B1: on a create the name takes input and the two fields carry their labels', async () => {
    const { host } = await mount();
    const labels = [...host.querySelectorAll('[data-group="provider"] .ocu-field > .ocu-field-label')].map((label) => label.textContent?.trim());
    expect(labels).toEqual([STRINGS.phoneProviderFormName, STRINGS.phoneProviderColumnGateway]);
    expect([control(host, 'Name').readOnly, control(host, 'SMSGateway').readOnly]).toEqual([false, false]);
  });

  it('B1: an edit holds the row and the name is read-only', async () => {
    const { host, calls } = await mount({ url: '/security/phone-providers/edit/OcuPhoneProbeA', row: HELD_ROW });
    expect(calls.some((call) => call.path === `${PHONE_PROVIDER_FORM_PATH}?id=OcuPhoneProbeA`)).toBe(true);
    expect([control(host, 'Name').readOnly, control(host, 'SMSGateway').readOnly]).toEqual([true, false]);
    expect([control(host, 'Name').value, control(host, 'SMSGateway').value]).toEqual(['OcuPhoneProbeA', 'sms.ocuphoneprobe.invalid']);
  });

  it('B2: a Save refused for a missing pair names the pair and the action of this form', async () => {
    const pair = '%Admin_Secure:USE';
    const denied = { kind: 'error', status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'Forbidden', detail: { failedPair: pair } } as unknown as JsonResult<unknown>;
    const { fixture, host } = await mount({ save: denied });
    await type(fixture, host, 'Name', 'OcuPhoneProbeB');
    save(host);
    await settle(fixture);
    // Mutation (Rule 19): pass `STRINGS.mftConnectionRefusedAction` in place of `STRINGS.phoneProviderRefusedAction` in the page -> this goes red.
    expect(host.querySelector('[data-phone-provider="reason"]')?.textContent?.trim()).toBe(formatDeniedAction(STRINGS.privilegeDeniedAction, pair, STRINGS.phoneProviderRefusedAction));
  });

  it('B2: a create sends the two fields and shows the read-back of the instance; a refused name stays on its field', async () => {
    const refused: JsonResult<unknown> = {
      kind: 'error',
      status: 422,
      code: 'PHONEPROVIDER.VALIDATION',
      reason: 'The provider was refused.',
      detail: { violations: [{ field: 'Name', code: 'PHONEPROVIDER.TAKEN', reason: 'A mobile phone provider with that name already exists.' }] },
    };
    const first = await mount({ save: refused });
    await type(first.fixture, first.host, 'Name', 'OcuPhoneProbeB');
    save(first.host);
    await settle(first.fixture);
    expect(first.host.querySelector('#ocu-phone-provider-Name-reason')?.textContent?.trim()).toBe('A mobile phone provider with that name already exists.');
    expect(control(first.host, 'Name').getAttribute('aria-invalid')).toBe('true');
    expect(first.host.querySelector('.ocu-form-summary')).not.toBeNull();

    const second = await mount();
    await type(second.fixture, second.host, 'Name', 'OcuPhoneProbeB');
    await type(second.fixture, second.host, 'SMSGateway', 'typed.ocuphoneprobe.invalid');
    save(second.host);
    await settle(second.fixture);
    const post = second.calls.find((call) => call.method === 'POST');
    expect(post?.path).toBe(PHONE_PROVIDER_PATH);
    // Mutation (Rule 19): bind the name and gateway controls to each other's field in the page -> the body compares unequal and this goes red.
    expect(JSON.parse(post?.body ?? '{}')).toEqual({ Name: 'OcuPhoneProbeB', SMSGateway: 'typed.ocuphoneprobe.invalid' });
    const status = second.host.querySelector('.ocu-form-bar-status [role="status"]');
    expect(status).not.toBeNull();
    // Mutation (Rule 19): drop `readBackOf(body?.['readBack'])` from the store's accepted Save -> the status reads "Saved" alone and this goes red.
    expect(status?.textContent?.trim()).toContain(STRINGS.readBackMatches);
  });

  it('B2: an edit puts the gateway alone', async () => {
    const { fixture, host, calls } = await mount({ url: '/security/phone-providers/edit/OcuPhoneProbeA', row: HELD_ROW });
    await type(fixture, host, 'SMSGateway', 'moved.ocuphoneprobe.invalid');
    save(host);
    await settle(fixture);
    const put = calls.find((call) => call.method === 'PUT');
    expect(put?.path).toBe(`${PHONE_PROVIDER_PATH}/OcuPhoneProbeA`);
    expect(JSON.parse(put?.body ?? '{}')).toEqual({ SMSGateway: 'moved.ocuphoneprobe.invalid' });
  });
});
