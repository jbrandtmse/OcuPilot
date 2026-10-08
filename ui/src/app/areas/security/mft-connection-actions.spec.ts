import { TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { ScreenActions } from '../../core/screen-actions';
import { SCREENS } from '../../core/screens.generated';
import { SCREEN_ACTION_DESCRIPTORS } from '../../shell/screen-action-handler';
import { CREATE_ACTION, MFT_CONNECTION_LIST_DESCRIPTOR, MftConnectionActions } from './mft-connection-actions';

/**
 * The Managed file transfer list's declared Create, Delete and Revoke token (Story 18.26): Create registered once against the list's
 * descriptor and opening the form at the bare route the mirror pairs with the list, the namespace carried;
 * Delete and Revoke token carried by the screen action handler. The real `ScreenActions` and router run.
 */

async function mount() {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [provideRouter([{ path: '**', children: [] }]), { provide: ScreenActions, useValue: new ScreenActions() }],
  });
  const router = TestBed.inject(Router);
  await router.navigateByUrl('/security/mft-connections?ns=HSCUSTOM');
  const actions = TestBed.inject(ScreenActions);
  TestBed.inject(MftConnectionActions);
  return { actions, router };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('MftConnectionActions', () => {
  it('registers the Create the list declares as its primary action', async () => {
    const { actions } = await mount();
    const list = SCREENS.find((screen) => screen.descriptor === MFT_CONNECTION_LIST_DESCRIPTOR);
    expect(list?.primaryAction.id).toBe(CREATE_ACTION);
    expect(actions.has(MFT_CONNECTION_LIST_DESCRIPTOR, CREATE_ACTION)).toBe(true);
  });

  // Mutation (Rule 19): drop the constructor's `register` -> `run` answers false and this goes red.
  it('opens the form at its bare route, carrying the namespace', async () => {
    const { actions, router } = await mount();
    const navigate = vi.spyOn(router, 'navigateByUrl');
    expect(actions.run(MFT_CONNECTION_LIST_DESCRIPTOR, CREATE_ACTION)).toBe(true);
    expect(navigate).toHaveBeenCalledWith('/security/mft-connections/edit?ns=HSCUSTOM');
  });

  it('declares Delete and Revoke token as its row actions, which the screen action handler carries', () => {
    const list = SCREENS.find((screen) => screen.descriptor === MFT_CONNECTION_LIST_DESCRIPTOR);
    expect(list?.rowActions.map((action) => action.id)).toEqual(['delete', 'revoke-token']);
    expect(SCREEN_ACTION_DESCRIPTORS).toContain(MFT_CONNECTION_LIST_DESCRIPTOR);
  });
});
