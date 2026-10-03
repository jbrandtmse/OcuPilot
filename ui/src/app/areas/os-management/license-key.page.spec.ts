import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import type { ConnectivityService } from '../../core/connectivity';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { RefreshService } from '../../core/refresh';
import { ScopeService } from '../../core/scope';
import { ScreenActions, actionLabel } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { Session } from '../../core/session';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import {
  LICENSE_KEY,
  LICENSE_KEY_ACTIVATE,
  LICENSE_KEY_FIELDS,
  LICENSE_KEY_TEXT_ID,
  LICENSE_KEY_VALIDATE_PATH,
  LicenseKeyPage,
  fieldText,
  printedTime,
  validationOf,
} from './license-key.page';

/**
 * License key (Story 18.6) over stubs of the HTTP answers, with the real `RefreshService`,
 * `ScreenStores`, `ScreenActions`, screen action handler and dialog: the shipped descriptor, read out
 * of the mirror, drives the read, and the assertions are about rendered DOM and the requests sent.
 */

const READ_PATH = '/api/ocupilot/screens/osmgmt.licensekey/read';
const ACTION_PATH = '/api/ocupilot/screens/osmgmt.licensekey/action';

/** A key text carrying a marker no store, request but the two named, or DOM node may keep. */
const MARKER = 'OCUPROBE186MARKER';
const KEY_TEXT = `-----KEY ${MARKER}-----`;

const ROW = {
  LicenseCapacity: 'InterSystems IRIS Community license',
  CustomerName: 'InterSystems IRIS Community',
  OrderNumber: 54702,
  Product: 'Server',
  LicenseType: 'Concurrent User',
  Server: 'Single',
  Platform: 'IRIS Community',
  LicenseUnits: 8,
  CoresLicensed: 20,
  CoresEnforced: 20,
  ExpirationDate: '2027-06-26',
  ExtendedFeaturesList: ['Interoperability', 'Vector Search'],
  AuthorizedApplications: [],
  // Never answered by the instance; planted to prove the page draws only its thirteen fields.
  AuthorizationKey: 'AUTHKEYSECRET',
};

const VALID = {
  valid: true,
  requiresRestart: true,
  reductions: [{ kind: 'Cores', from: '20', to: '8' }],
  features: ['Vector Search'],
};

const INVALID = {
  kind: 'error',
  status: 422,
  code: 'LICENSE.KEY.INVALID',
  reason: 'The request was refused.',
  detail: { violations: [{ field: 'Key', code: 'LICENSE.KEY.INVALID', reason: 'This is not a valid license key for this instance.' }] },
};

interface Sent {
  readonly path: string;
  readonly method: string;
  readonly body: string;
}

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 10));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(options: { validate?: 'valid' | 'invalid' | 'unreached'; activate?: 'ok' | 'invalid' } = {}) {
  TestBed.resetTestingModule();
  const declaration = SCREENS.find((screen) => screen.descriptor === LICENSE_KEY) ?? null;
  const sent: Sent[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: { method?: string; body?: string } = {}): Promise<JsonResult<T>> => {
      sent.push({ path, method: init.method ?? 'GET', body: init.body ?? '' });
      if (path.startsWith(READ_PATH)) {
        return { kind: 'ok', status: 200, body: { fields: [], rows: [ROW], truncated: false, banner: '' } as T };
      }
      if (path === LICENSE_KEY_VALIDATE_PATH) {
        if ((options.validate ?? 'valid') === 'invalid') return INVALID as unknown as JsonResult<T>;
        if (options.validate === 'unreached') return { kind: 'error', status: 0, code: null, reason: null, detail: null };
        return { kind: 'ok', status: 200, body: VALID as T };
      }
      if (path === ACTION_PATH) {
        if (options.activate === 'invalid') return INVALID as unknown as JsonResult<T>;
        return {
          kind: 'ok',
          status: 200,
          body: { target: { type: 'license-key', scope: 'instance', id: 'SYSTEM' }, action: 'updated' } as T,
        };
      }
      return { kind: 'error', status: 404, code: null, reason: null, detail: null };
    },
  };
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  const bus = new ChangeBus();
  const refresh = new RefreshService({
    stores,
    connectivity: { retryWhenReachable: () => {} } as unknown as ConnectivityService,
    bus,
    namespace: () => 'HSCUSTOM',
    schedule: () => {},
  });
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: NavigationService, useValue: { screenForUrl: () => declaration } as unknown as NavigationService },
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: RefreshService, useValue: refresh },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: ChangeBus, useValue: bus },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: Session, useValue: { userName: () => 'probeuser' } as unknown as Session },
      {
        provide: ScopeService,
        useValue: { loaded: () => true, namespace: () => 'HSCUSTOM', subscribe: () => () => {} } as unknown as ScopeService,
      },
    ],
  });
  await TestBed.inject(Router).navigateByUrl('/os-management/license-key');
  const fixture = TestBed.createComponent(LicenseKeyPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return { fixture, sent, stores, actions: TestBed.inject(ScreenActions), host: fixture.nativeElement as HTMLElement };
}

function fieldValue(host: HTMLElement, field: string): string {
  return host.querySelector(`[data-field="${field}"] .ocu-details-field-value`)?.textContent?.trim() ?? '';
}

function button(host: HTMLElement, name: string): HTMLButtonElement {
  return host.querySelector(`[data-license="${name}"]`) as HTMLButtonElement;
}

async function openDialog(mounted: Awaited<ReturnType<typeof mount>>): Promise<void> {
  expect(mounted.actions.run(LICENSE_KEY, LICENSE_KEY_ACTIVATE)).toBe(true);
  await settle(mounted.fixture);
}

async function typeKey(mounted: Awaited<ReturnType<typeof mount>>, text: string): Promise<void> {
  const area = mounted.host.querySelector(`#${LICENSE_KEY_TEXT_ID}`) as HTMLTextAreaElement;
  area.value = text;
  area.dispatchEvent(new Event('input'));
  await settle(mounted.fixture);
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
  vi.restoreAllMocks();
});

describe('License key', () => {
  it('A1: lists the thirteen fields in the classic order, each list joined and an empty one "(none)", and never the authorization key', async () => {
    const { host } = await mount();
    const labels = [...host.querySelectorAll('.ocu-details-field-label')].map((node) => node.textContent?.trim());
    expect(labels).toEqual(LICENSE_KEY_FIELDS.map((entry) => STRINGS[entry.labelKey]));
    expect(labels).toHaveLength(13);
    expect(fieldValue(host, 'OrderNumber')).toBe('54702');
    expect(fieldValue(host, 'ExtendedFeaturesList')).toBe('Interoperability, Vector Search');
    expect(fieldValue(host, 'AuthorizedApplications')).toBe(STRINGS.tableEmptyValue);
    expect(host.querySelector('[data-license="authorization"]')?.textContent?.trim()).toBe(STRINGS.licenseKeyAuthorizationHidden);
    // Mutation (Rule 19): list AuthorizationKey in LICENSE_KEY_FIELDS -> red.
    expect(host.textContent).not.toContain('AUTHKEYSECRET');
  });

  it('registers Activate new key as the primary action, which opens the activate dialog', async () => {
    const mounted = await mount();
    expect(actionLabel(LICENSE_KEY, LICENSE_KEY_ACTIVATE)).toBe(STRINGS.licenseKeyActivateAction);
    expect(mounted.host.querySelector('[role="dialog"]')).toBeNull();
    await openDialog(mounted);
    expect(mounted.host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.licenseKeyActivateTitle);
    const area = mounted.host.querySelector(`#${LICENSE_KEY_TEXT_ID}`) as HTMLTextAreaElement;
    expect(area.getAttribute('autocomplete')).toBe('off');
    expect(area.getAttribute('spellcheck')).toBe('false');
  });

  it('A2/A3: Activate is unavailable until the current text validates, and a change to the text withdraws it', async () => {
    const mounted = await mount();
    await openDialog(mounted);
    expect(button(mounted.host, 'activate').getAttribute('aria-disabled')).toBe('true');
    await typeKey(mounted, KEY_TEXT);
    button(mounted.host, 'validate').click();
    await settle(mounted.fixture);
    expect(mounted.sent.filter((entry) => entry.path === LICENSE_KEY_VALIDATE_PATH)).toHaveLength(1);
    const verdict = mounted.host.querySelector('[data-license="verdict"]')?.textContent ?? '';
    expect(verdict).toContain(STRINGS.licenseKeyValid);
    expect(verdict).toContain(STRINGS.licenseKeyRestart);
    expect(verdict).toContain(STRINGS.licenseKeyActivateConsequence);
    const lines = [...mounted.host.querySelectorAll('[data-license="reductions"] li')].map((node) => node.textContent?.trim());
    expect(lines).toEqual([
      STRINGS.licenseKeyReductionCores.replace('<from>', '20').replace('<to>', '8'),
      STRINGS.licenseKeyReductionFeatures.replace('<features>', 'Vector Search'),
    ]);
    expect(button(mounted.host, 'activate').getAttribute('aria-disabled')).toBe('false');
    // Mutation (Rule 19): make validatedFlag ignore the text it was validated against -> red.
    await typeKey(mounted, `${KEY_TEXT} changed`);
    expect(button(mounted.host, 'activate').getAttribute('aria-disabled')).toBe('true');
    expect(mounted.host.querySelector('[data-license="verdict"]')).toBeNull();
  });

  it('A2: a malformed key is refused on its field, and Activate stays unavailable', async () => {
    const mounted = await mount({ validate: 'invalid' });
    await openDialog(mounted);
    await typeKey(mounted, 'OCUPROBE186 is not a license key');
    button(mounted.host, 'validate').click();
    await settle(mounted.fixture);
    const area = mounted.host.querySelector(`#${LICENSE_KEY_TEXT_ID}`) as HTMLTextAreaElement;
    expect(area.getAttribute('aria-invalid')).toBe('true');
    expect(mounted.host.querySelector(`#${LICENSE_KEY_TEXT_ID}-reason`)?.textContent?.trim()).toBe(
      'This is not a valid license key for this instance.'
    );
    expect(button(mounted.host, 'activate').getAttribute('aria-disabled')).toBe('true');
    button(mounted.host, 'activate').click();
    await settle(mounted.fixture);
    expect(mounted.sent.some((entry) => entry.path === ACTION_PATH)).toBe(false);
  });

  it('A3: Activate sends the declared action with the text as its one value, then closes and forgets the text', async () => {
    const mounted = await mount();
    await openDialog(mounted);
    await typeKey(mounted, KEY_TEXT);
    button(mounted.host, 'validate').click();
    await settle(mounted.fixture);
    button(mounted.host, 'activate').click();
    await settle(mounted.fixture);
    const posts = mounted.sent.filter((entry) => entry.path === ACTION_PATH);
    expect(posts).toHaveLength(1);
    expect(JSON.parse(posts[0].body)).toEqual({ action: 'activate', id: 'SYSTEM', values: { Key: KEY_TEXT } });
    expect(mounted.host.querySelector('[role="dialog"]')).toBeNull();
    // The text lives in the page alone: no store holds it, the DOM drops it, and a reopen starts empty.
    expect(JSON.stringify(mounted.stores.for(LICENSE_KEY, []).data())).not.toContain(MARKER);
    expect(mounted.host.innerHTML).not.toContain(MARKER);
    await openDialog(mounted);
    expect((mounted.host.querySelector(`#${LICENSE_KEY_TEXT_ID}`) as HTMLTextAreaElement).value).toBe('');
    // Only the validate and the action carried the text.
    expect(mounted.sent.filter((entry) => entry.body.includes(MARKER)).map((entry) => entry.path)).toEqual([
      LICENSE_KEY_VALIDATE_PATH,
      ACTION_PATH,
    ]);
  });

  it("A3: the instance's refusal of the activation lands on the field and withdraws the validation", async () => {
    const mounted = await mount({ activate: 'invalid' });
    await openDialog(mounted);
    await typeKey(mounted, KEY_TEXT);
    button(mounted.host, 'validate').click();
    await settle(mounted.fixture);
    button(mounted.host, 'activate').click();
    await settle(mounted.fixture);
    expect(mounted.host.querySelector(`#${LICENSE_KEY_TEXT_ID}-reason`)?.textContent?.trim()).toBe(
      'This is not a valid license key for this instance.'
    );
    expect(button(mounted.host, 'activate').getAttribute('aria-disabled')).toBe('true');
  });

  it('A2: a check that never reached the instance says so in the dialog, and Activate stays unavailable', async () => {
    const mounted = await mount({ validate: 'unreached' });
    await openDialog(mounted);
    await typeKey(mounted, KEY_TEXT);
    button(mounted.host, 'validate').click();
    await settle(mounted.fixture);
    // Mutation (Rule 19): pass the answer's empty reason through unchanged -> red.
    expect(mounted.host.querySelector('[role="dialog"] .ocu-banner-warning')?.textContent?.trim()).toBe(STRINGS.connectivityRequestRefused);
    expect(button(mounted.host, 'activate').getAttribute('aria-disabled')).toBe('true');
  });

  it('Load from file reads the picked key file into the field, and nothing is sent', async () => {
    const mounted = await mount();
    await openDialog(mounted);
    const input = mounted.host.querySelector('input[type="file"]') as HTMLInputElement;
    expect(input.getAttribute('accept')).toBe('.key');
    Object.defineProperty(input, 'files', { value: [new File([KEY_TEXT], 'probe.key', { type: 'text/plain' })], configurable: true });
    input.dispatchEvent(new Event('change'));
    await settle(mounted.fixture);
    // Mutation (Rule 19): make onFile's reader set '' -> red.
    expect((mounted.host.querySelector(`#${LICENSE_KEY_TEXT_ID}`) as HTMLTextAreaElement).value).toBe(KEY_TEXT);
    expect(mounted.sent.some((entry) => entry.body.includes(MARKER))).toBe(false);
  });

  it('closing the dialog clears the text', async () => {
    const mounted = await mount();
    await openDialog(mounted);
    await typeKey(mounted, KEY_TEXT);
    (mounted.host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement).click();
    await settle(mounted.fixture);
    expect(mounted.host.querySelector('[role="dialog"]')).toBeNull();
    expect(mounted.host.innerHTML).not.toContain(MARKER);
    // The page itself no longer holds it, before any reopen clears it again.
    // Mutation (Rule 19): drop `clearText()` from `closeDialog` -> red.
    expect((mounted.fixture.componentInstance as unknown as { keyText: string }).keyText).toBe('');
    await openDialog(mounted);
    expect((mounted.host.querySelector(`#${LICENSE_KEY_TEXT_ID}`) as HTMLTextAreaElement).value).toBe('');
  });

  it('A4: Print opens the browser print over the print region, whose print-only line names the user', async () => {
    const mounted = await mount();
    const print = vi.spyOn(window, 'print').mockImplementation(() => undefined);
    button(mounted.host, 'print').click();
    await settle(mounted.fixture);
    expect(print).toHaveBeenCalledTimes(1);
    const region = mounted.host.querySelector('.ocu-print-region');
    expect(region?.querySelector('[data-license="fields"]') ?? region?.getAttribute('data-license')).toBeTruthy();
    const printed = mounted.host.querySelector('.ocu-print-region .ocu-print-only')?.textContent?.trim() ?? '';
    expect(printed.startsWith('Printed by probeuser on ')).toBe(true);
    // Print sits outside the region, so print media shows the fields alone.
    expect(region?.contains(button(mounted.host, 'print'))).toBe(false);
  });

  it("A4: the browser's own print stamps the printed-by time too", async () => {
    const mounted = await mount();
    vi.useFakeTimers({ toFake: ['Date'] });
    try {
      vi.setSystemTime(new Date(2031, 0, 2, 3, 4, 5));
      window.dispatchEvent(new Event('beforeprint'));
    } finally {
      vi.useRealTimers();
    }
    await settle(mounted.fixture);
    // Mutation (Rule 19): drop the page's `beforeprint` listener -> red.
    expect(mounted.host.querySelector('[data-license="printed"]')?.textContent?.trim()).toBe('Printed by probeuser on 2031-01-02 03:04:05.');
  });
});

describe('License key helpers', () => {
  it('fieldText joins a list, reads a number as written, and answers "(none)" for an empty or absent value', () => {
    expect(fieldText({ A: ['x', 'y'] }, 'A')).toBe('x, y');
    expect(fieldText({ A: [] }, 'A')).toBe(STRINGS.tableEmptyValue);
    expect(fieldText({ A: 7 }, 'A')).toBe('7');
    expect(fieldText({}, 'A')).toBe(STRINGS.tableEmptyValue);
  });

  it("validationOf states each reduction in OcuPilot's words, inserting values as written, and nothing for an invalid answer", () => {
    expect(validationOf({ valid: false })).toBeNull();
    const answer = validationOf({
      valid: true,
      requiresRestart: false,
      reductions: [
        { kind: 'Users', from: '$&', to: '5' },
        { kind: 'Unknown', from: '1', to: '2' },
      ],
      features: [],
    });
    expect(answer).toEqual({ requiresRestart: false, lines: [STRINGS.licenseKeyReductionUsers.replace('<from>', () => '$&').replace('<to>', '5')] });
  });

  it('validationOf states every reduction kind LicensePort names, in its order', () => {
    const answer = validationOf({
      valid: true,
      requiresRestart: true,
      reductions: [
        { kind: 'Cores', from: '20', to: '8' },
        { kind: 'Users', from: '25', to: '5' },
        { kind: 'Server', from: 'Multi', to: 'Single' },
        { kind: 'LicenseType', from: 'Concurrent User', to: 'Named User' },
        { kind: 'Product', from: 'Enterprise', to: 'Standard' },
      ],
      features: [],
    });
    // Mutation (Rule 19): drop a kind from REDUCTION_SENTENCES -> red.
    expect(answer).toEqual({
      requiresRestart: true,
      lines: [
        STRINGS.licenseKeyReductionCores.replace('<from>', '20').replace('<to>', '8'),
        STRINGS.licenseKeyReductionUsers.replace('<from>', '25').replace('<to>', '5'),
        STRINGS.licenseKeyReductionServer.replace('<from>', 'Multi').replace('<to>', 'Single'),
        STRINGS.licenseKeyReductionLicenseType.replace('<from>', 'Concurrent User').replace('<to>', 'Named User'),
        STRINGS.licenseKeyReductionProduct.replace('<from>', 'Enterprise').replace('<to>', 'Standard'),
      ],
    });
  });

  it('printedTime reads the local date and clock time', () => {
    expect(printedTime(new Date(2026, 9, 3, 7, 5, 9))).toBe('2026-10-03 07:05:09');
  });
});
