import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import { NavigationService } from '../../core/navigation';
import { DESCRIPTOR_EDIT_PAGES, type PageLoader } from '../../shell/screen-outlet';
import { RoleCreateFormPage } from './role-create-form.page';
import { ROLES_FORM_PATH, ROLES_PATH } from './role-create-form.store';

/**
 * The create-a-role page's hand-off to the role editor (DW-2372, AC4). The editor's page code is
 * held while the create is saved, so the assertions are about when "Saved" may show: not on this
 * form, and not before the editor has opened.
 */

const EDITOR = 'OcuPilot.Screen.Descriptor.RoleForm';

const RULES = { requiredFields: ['Name'], maxLengths: {}, rules: [], roles: [], resources: [] };

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(createAnswer: JsonResult<unknown>): Promise<ComponentFixture<RoleCreateFormPage>> {
  TestBed.resetTestingModule();
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      if (path === ROLES_FORM_PATH) return { kind: 'ok', status: 200, body: RULES } as unknown as JsonResult<T>;
      if (path === ROLES_PATH && init.method === 'POST') return createAnswer as JsonResult<T>;
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
  const fixture = TestBed.createComponent(RoleCreateFormPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  await settle(fixture);
  return fixture;
}

function save(fixture: ComponentFixture<unknown>): void {
  (fixture.nativeElement.querySelector('.ocu-button-primary') as HTMLButtonElement).click();
}

function statuses(host: HTMLElement): string[] {
  return [...host.querySelectorAll('[role="status"]')].map((node) => node.textContent?.trim() ?? '');
}

/** Hold the editor's page code until `release` is called. */
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

describe('the create-a-role page hand-off (DW-2372)', () => {
  // Mutation (Rule 19): navigate before the warm resolves -- drop the `await warmEditPage(...)` in `onSave` -> the
  // navigation assertion while the chunk is held goes red.
  it('shows no "Saved" and does not navigate while the editor\'s page code is held, then hands off once it is loaded', async () => {
    const hold = holdEditor();
    const fixture = await mount({ kind: 'ok', status: 201, body: { name: 'Probe' } });
    const navigate = vi.spyOn(TestBed.inject(Router), 'navigateByUrl').mockResolvedValue(true);
    save(fixture);
    await settle(fixture);
    expect(statuses(fixture.nativeElement), 'no Saved status while the chunk is held').toEqual([]);
    expect(navigate, 'and no navigation').not.toHaveBeenCalled();

    hold.release();
    await settle(fixture);
    expect(navigate).toHaveBeenCalledTimes(1);
    expect(navigate.mock.calls[0][0]).toContain('Probe');
    expect(statuses(fixture.nativeElement), 'the form\'s own Saved is never shown; the editor draws its own').toEqual([]);
  });

  it('a refused Save hands nothing off', async () => {
    const hold = holdEditor();
    const fixture = await mount({ kind: 'error', status: 409, code: 'ROLE.NAME.REQUIRED', reason: 'Name the role.', detail: null });
    const navigate = vi.spyOn(TestBed.inject(Router), 'navigateByUrl').mockResolvedValue(true);
    save(fixture);
    await settle(fixture);
    hold.release();
    await settle(fixture);
    expect(navigate).not.toHaveBeenCalled();
    expect(statuses(fixture.nativeElement)).toEqual([]);
  });
});
