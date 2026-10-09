import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService } from '../../core/navigation';
import { STRINGS } from '../../core/strings';
import { UserCreateFormPage } from './user-create-form.page';
import { USERS_FORM_PATH, USERS_LIST_READ_PATH } from './user-create-form.store';

/**
 * The create-a-user page's copy consequence (AD-10, Story 18.29). Over stubs of the instance's
 * answers, the real store and page run, so the assertions are about rendered DOM: a copy whose
 * source holds a privileged role states the consequence under the roles, and a plain source does not.
 */

const RULES = {
  requiredFields: ['Name', 'Password'],
  maxLengths: { Name: 160, FullName: 2048, NameSpace: 64, Routine: 64 },
  rules: [],
  roles: [
    { name: '%Developer', privileged: false },
    { name: '%All', privileged: true },
  ],
};

const planted: HTMLElement[] = [];

function sourceForm(roles: string[]) {
  return { ...RULES, user: { Name: 'Src', FullName: 'Source Person', Roles: roles, EscalationRoles: [] } };
}

/** Mount the page with `source` as the account `Src`'s form read. */
async function mount(roles: string[]): Promise<ComponentFixture<UserCreateFormPage>> {
  TestBed.resetTestingModule();
  const api = {
    requestJson: async <T,>(path: string, _init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      if (path.startsWith(`${USERS_FORM_PATH}?name=Src`)) {
        return { kind: 'ok', status: 200, body: sourceForm(roles) } as unknown as JsonResult<T>;
      }
      if (path === USERS_LIST_READ_PATH) {
        return { kind: 'ok', status: 200, body: { rows: [{ Name: 'Src' }, { Name: 'Other' }] } } as unknown as JsonResult<T>;
      }
      return { kind: 'ok', status: 200, body: RULES } as unknown as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      provideRouter([]),
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: FormDirty, useValue: new FormDirty() },
      { provide: NavigationService, useValue: {} as unknown as NavigationService },
    ],
  });
  const fixture = TestBed.createComponent(UserCreateFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return fixture;
}

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

/** Choose `Src` in the copy-from select, as the user does, and wait for its source read to land. */
async function chooseSource(fixture: ComponentFixture<UserCreateFormPage>): Promise<void> {
  const select = fixture.nativeElement.querySelector('select') as HTMLSelectElement;
  select.value = 'Src';
  select.dispatchEvent(new Event('change'));
  await settle(fixture);
}

function effectCaptions(host: HTMLElement): string[] {
  return [...host.querySelectorAll('.ocu-field-caption')].map((node) => node.textContent?.trim() ?? '');
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the create-a-user page copy consequence (AD-10, Story 18.29)', () => {
  it('a copy of a privileged source states the consequence under the roles', async () => {
    const fixture = await mount(['%All']);
    await chooseSource(fixture);
    expect(effectCaptions(fixture.nativeElement)).toContain(STRINGS.userCopyPrivilegedEffect);
    // The select is described by the consequence, so it is read with the choice.
    const select = fixture.nativeElement.querySelector('select') as HTMLSelectElement;
    const described = (select.getAttribute('aria-describedby') ?? '').split(' ').map((id) => document.getElementById(id)?.textContent?.trim() ?? '');
    expect(described).toContain(STRINGS.userCopyPrivilegedEffect);
  });

  it('a copy of a plain source states no consequence', async () => {
    const fixture = await mount(['%Developer']);
    await chooseSource(fixture);
    expect(effectCaptions(fixture.nativeElement)).not.toContain(STRINGS.userCopyPrivilegedEffect);
  });
});
