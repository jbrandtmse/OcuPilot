import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { encodeEntityId } from '../../core/entity-id';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService } from '../../core/navigation';
import { STRINGS } from '../../core/strings';
import { DESCRIPTOR_EDIT_PAGES, type PageLoader } from '../../shell/screen-outlet';
import { WebAppCreateFormPage } from './create-form.page';
import {
  WEB_APPLICATIONS_FORM_PATH,
  WEB_APPLICATIONS_LIST_READ_PATH,
  WEB_APPLICATIONS_PATH,
} from './create-form.store';

/**
 * The create-a-web-application page: its Copy from select (WA-15, AC3) and its hand-off to the
 * editor (DW-2372, AC4). The real store and page run over stubs of the instance's answers, and the
 * editor's page code is held while the create is saved.
 */

const EDITOR = 'OcuPilot.Screen.Descriptor.WebAppForm';

const RULES = {
  authenticationMethods: [{ bit: 32, label: 'Password' }],
  defaultMethod: 32,
  requiredFields: ['Name', 'NameSpace', 'AutheEnabled'],
  wsgiTypes: [],
  maxLengths: {},
  rules: [],
  roles: [],
};

const SOURCE = {
  application: { Description: 'Copied description', NameSpace: 'HSCUSTOM', Enabled: true, Recurse: true, AutheEnabled: 32 },
};

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(
  createAnswer: JsonResult<unknown> = { kind: 'ok', status: 201, body: { name: '/csp/probe' } },
  sourceAnswer: JsonResult<unknown> = { kind: 'ok', status: 200, body: SOURCE }
): Promise<ComponentFixture<WebAppCreateFormPage>> {
  TestBed.resetTestingModule();
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      if (path === WEB_APPLICATIONS_FORM_PATH) return { kind: 'ok', status: 200, body: RULES } as unknown as JsonResult<T>;
      if (path === WEB_APPLICATIONS_LIST_READ_PATH) {
        return { kind: 'ok', status: 200, body: { rows: [{ Name: '/csp/source' }, { Name: '/csp/other' }] } } as unknown as JsonResult<T>;
      }
      if (path.startsWith(`${WEB_APPLICATIONS_FORM_PATH}?name=`)) return sourceAnswer as JsonResult<T>;
      if (path === WEB_APPLICATIONS_PATH && init.method === 'POST') return createAnswer as JsonResult<T>;
      return { kind: 'ok', status: 200, body: {} } as unknown as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: FormDirty, useValue: new FormDirty() },
      { provide: NavigationService, useValue: { screenForUrl: () => null } as unknown as NavigationService },
    ],
  });
  const fixture = TestBed.createComponent(WebAppCreateFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return fixture;
}

function copySelect(host: HTMLElement): HTMLSelectElement {
  return host.querySelector('#ocu-web-app-CopyFrom') as HTMLSelectElement;
}

async function choose(fixture: ComponentFixture<unknown>, value: string): Promise<void> {
  const select = copySelect(fixture.nativeElement);
  select.value = value;
  select.dispatchEvent(new Event('change'));
  await settle(fixture);
}

function save(fixture: ComponentFixture<unknown>): void {
  (fixture.nativeElement.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
}

function statuses(host: HTMLElement): string[] {
  return [...host.querySelectorAll('[role="status"]')].map((node) => node.textContent?.trim() ?? '');
}

function holdEditor(): { release: () => void } {
  let release: () => void = () => undefined;
  const held = new Promise<never>((resolve) => {
    release = () => resolve(class Editor {} as never);
  });
  vi.spyOn(DESCRIPTOR_EDIT_PAGES as Record<string, PageLoader>, EDITOR).mockImplementation(() => held);
  return { release };
}

afterEach(() => {
  vi.restoreAllMocks();
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the create-a-web-application page Copy from select (WA-15)', () => {
  it('is the first field, labeled Copy from, offering None and the instance\'s applications', async () => {
    const fixture = await mount();
    const host = fixture.nativeElement as HTMLElement;
    const select = copySelect(host);
    expect(select).not.toBeNull();
    expect(host.querySelector('.ocu-form-fields .ocu-field label')?.textContent?.trim()).toBe(STRINGS.userCopyFrom);
    expect([...select.options].map((option) => option.textContent?.trim())).toEqual([STRINGS.sslVerifyPeerNone, '/csp/source', '/csp/other']);
  });

  it('choosing an application fills the form from it, and choosing None restores the blank form', async () => {
    const fixture = await mount();
    const host = fixture.nativeElement as HTMLElement;
    await choose(fixture, '/csp/source');
    expect((host.querySelector('#ocu-web-app-Description') as HTMLInputElement).value).toBe('Copied description');
    expect((host.querySelector('#ocu-web-app-NameSpace') as HTMLInputElement).value).toBe('HSCUSTOM');
    expect((host.querySelector('#ocu-web-app-Name') as HTMLInputElement).value, 'the name stays empty').toBe('');
    await choose(fixture, '');
    expect((host.querySelector('#ocu-web-app-Description') as HTMLInputElement).value).toBe('');
    expect((host.querySelector('#ocu-web-app-NameSpace') as HTMLInputElement).value).toBe('');
  });

  it('a refused source read shows its refusal and leaves the form as it was', async () => {
    const fixture = await mount(undefined, { kind: 'error', status: 404, code: 'WEBAPP.NAME.ABSENT', reason: 'That web application is gone.', detail: null });
    const host = fixture.nativeElement as HTMLElement;
    await choose(fixture, '/csp/source');
    expect(host.querySelector('[role="alert"]')?.textContent?.trim()).toBe('That web application is gone.');
    expect((host.querySelector('#ocu-web-app-Description') as HTMLInputElement).value).toBe('');
    expect(copySelect(host).value, 'and the select reads the choice the form holds').toBe('');
  });
});

describe('the create-a-web-application page hand-off to the editor (DW-2372, AC4)', () => {
  // Mutation (Rule 19): navigate before the warm resolves -- drop the `await warmEditPage(...)` in `onSave` -> the
  // navigation assertion while the chunk is held goes red; drop the `handingOff` check from `showSaved` -> the status
  // assertion goes red.
  it('shows no "Saved" and does not navigate while the editor\'s page code is held, then hands off once it is loaded', async () => {
    const hold = holdEditor();
    const fixture = await mount();
    const navigate = vi.spyOn(TestBed.inject(Router), 'navigateByUrl').mockResolvedValue(true);
    save(fixture);
    await settle(fixture);
    expect(statuses(fixture.nativeElement), 'no Saved status while the chunk is held').toEqual([]);
    expect(navigate, 'and no navigation').not.toHaveBeenCalled();

    hold.release();
    await settle(fixture);
    expect(navigate).toHaveBeenCalledTimes(1);
    expect(String(navigate.mock.calls[0][0])).toContain(encodeEntityId('/csp/probe'));
    expect(statuses(fixture.nativeElement), 'the form\'s own Saved is never shown; the editor draws its own').toEqual([]);
  });

  it('a refused Save hands nothing off', async () => {
    const hold = holdEditor();
    const fixture = await mount({ kind: 'error', status: 409, code: 'WEBAPP.NAME.REQUIRED', reason: 'Name the application.', detail: null });
    const navigate = vi.spyOn(TestBed.inject(Router), 'navigateByUrl').mockResolvedValue(true);
    save(fixture);
    await settle(fixture);
    hold.release();
    await settle(fixture);
    expect(navigate).not.toHaveBeenCalled();
    expect(statuses(fixture.nativeElement)).toEqual([]);
  });
});
