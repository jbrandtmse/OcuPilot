import { TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { ScreenActions } from '../../core/screen-actions';
import { SCREENS } from '../../core/screens.generated';
import { SCREEN_ACTION_DESCRIPTORS } from '../../shell/screen-action-handler';
import { CREATE_ACTION, SUPERSERVER_LIST_DESCRIPTOR, SuperserverActions } from './superserver-actions';

/**
 * The Superservers list's declared Create and Delete (Story 18.25): Create registered once against the list's
 * descriptor and opening the form at the bare route the mirror pairs with the list, the namespace carried;
 * Delete carried by the screen action handler. The real `ScreenActions` and router run.
 */

async function mount() {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [provideRouter([{ path: '**', children: [] }]), { provide: ScreenActions, useValue: new ScreenActions() }],
  });
  const router = TestBed.inject(Router);
  await router.navigateByUrl('/security/superservers?ns=HSCUSTOM');
  const actions = TestBed.inject(ScreenActions);
  TestBed.inject(SuperserverActions);
  return { actions, router };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('SuperserverActions', () => {
  it('registers the Create the list declares as its primary action', async () => {
    const { actions } = await mount();
    const list = SCREENS.find((screen) => screen.descriptor === SUPERSERVER_LIST_DESCRIPTOR);
    expect(list?.primaryAction.id).toBe(CREATE_ACTION);
    expect(actions.has(SUPERSERVER_LIST_DESCRIPTOR, CREATE_ACTION)).toBe(true);
  });

  // Mutation (Rule 19): drop the constructor's `register` -> `run` answers false and this goes red.
  it('opens the form at its bare route, carrying the namespace', async () => {
    const { actions, router } = await mount();
    const navigate = vi.spyOn(router, 'navigateByUrl');
    expect(actions.run(SUPERSERVER_LIST_DESCRIPTOR, CREATE_ACTION)).toBe(true);
    expect(navigate).toHaveBeenCalledWith('/security/superservers/edit?ns=HSCUSTOM');
  });

  it('declares Delete as its one row action, which the screen action handler carries', () => {
    const list = SCREENS.find((screen) => screen.descriptor === SUPERSERVER_LIST_DESCRIPTOR);
    expect(list?.rowActions.map((action) => action.id)).toEqual(['delete']);
    expect(SCREEN_ACTION_DESCRIPTORS).toContain(SUPERSERVER_LIST_DESCRIPTOR);
  });
});
