import { TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { ScreenActions } from '../../core/screen-actions';
import { SCREENS } from '../../core/screens.generated';
import { SCREEN_ACTION_DESCRIPTORS } from '../../shell/screen-action-handler';
import { CREATE_ACTION, LICENSE_SERVER_LIST_DESCRIPTOR, LicenseServerActions } from './license-server-actions';

/**
 * License servers' declared Create and Delete (Story 18.6): Create registered once against the list's
 * descriptor and opening the form at the bare route the mirror pairs with the list, the namespace
 * carried; Delete carried by the screen action handler. The real `ScreenActions` and router run.
 */

async function mount() {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [provideRouter([{ path: '**', children: [] }]), { provide: ScreenActions, useValue: new ScreenActions() }],
  });
  const router = TestBed.inject(Router);
  await router.navigateByUrl('/os-management/license-servers?ns=HSCUSTOM');
  const actions = TestBed.inject(ScreenActions);
  TestBed.inject(LicenseServerActions);
  return { actions, router };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('LicenseServerActions', () => {
  it('registers the Create the list declares as its primary action', async () => {
    const { actions } = await mount();
    const list = SCREENS.find((screen) => screen.descriptor === LICENSE_SERVER_LIST_DESCRIPTOR);
    expect(list?.primaryAction.id).toBe(CREATE_ACTION);
    expect(actions.has(LICENSE_SERVER_LIST_DESCRIPTOR, CREATE_ACTION)).toBe(true);
  });

  it('opens the form at its bare route, carrying the namespace', async () => {
    const { actions, router } = await mount();
    const navigate = vi.spyOn(router, 'navigateByUrl');
    expect(actions.run(LICENSE_SERVER_LIST_DESCRIPTOR, CREATE_ACTION)).toBe(true);
    expect(navigate).toHaveBeenCalledWith('/os-management/license-servers/edit?ns=HSCUSTOM');
  });

  it('leaves the row Delete the list declares to the screen action handler', () => {
    const list = SCREENS.find((screen) => screen.descriptor === LICENSE_SERVER_LIST_DESCRIPTOR);
    expect(list?.rowActions.map((action) => action.id)).toEqual(['delete']);
    expect(SCREEN_ACTION_DESCRIPTORS).toContain(LICENSE_SERVER_LIST_DESCRIPTOR);
  });
});
