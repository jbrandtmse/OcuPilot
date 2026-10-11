import { TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { ScreenActions } from '../../core/screen-actions';
import { SCREENS } from '../../core/screens.generated';
import { SCREEN_ACTION_DESCRIPTORS } from '../../shell/screen-action-handler';
import { CREATE_ACTION, ROUTINE_APP_LIST_DESCRIPTOR, RoutineAppActions } from './routine-app-actions';

/**
 * The privileged routine applications list's declared Create, Delete and six tab actions (Stories 18.31 and 18.33): Create registered once against
 * the list's descriptor and opening the form at the bare route the mirror pairs with the list, the namespace carried;
 * Delete carried by the screen action handler. The real `ScreenActions` and router run.
 */

async function mount() {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [provideRouter([{ path: '**', children: [] }]), { provide: ScreenActions, useValue: new ScreenActions() }],
  });
  const router = TestBed.inject(Router);
  await router.navigateByUrl('/web-applications/routine-applications?ns=HSCUSTOM');
  const actions = TestBed.inject(ScreenActions);
  TestBed.inject(RoutineAppActions);
  return { actions, router };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('RoutineAppActions', () => {
  it('registers the Create the list declares as its primary action', async () => {
    const { actions } = await mount();
    const list = SCREENS.find((screen) => screen.descriptor === ROUTINE_APP_LIST_DESCRIPTOR);
    expect(list?.primaryAction.id).toBe(CREATE_ACTION);
    expect(actions.has(ROUTINE_APP_LIST_DESCRIPTOR, CREATE_ACTION)).toBe(true);
  });

  // Mutation (Rule 19): drop the constructor's `register` -> `run` answers false and this goes red.
  it('opens the form at its bare route, carrying the namespace', async () => {
    const { actions, router } = await mount();
    const navigate = vi.spyOn(router, 'navigateByUrl');
    expect(actions.run(ROUTINE_APP_LIST_DESCRIPTOR, CREATE_ACTION)).toBe(true);
    expect(navigate).toHaveBeenCalledWith('/web-applications/routine-applications/edit?ns=HSCUSTOM');
  });

  it('declares the six role and routine actions the editor\u2019s tabs send and Delete, all carrying the own-application rule, which the screen action handler carries', () => {
    const list = SCREENS.find((screen) => screen.descriptor === ROUTINE_APP_LIST_DESCRIPTOR);
    expect(list?.rowActions.map((action) => action.id)).toEqual([
      'add-application-role',
      'remove-application-role',
      'add-matching-role',
      'remove-matching-role',
      'add-routine',
      'remove-routine',
      'delete',
    ]);
    expect(new Set(list?.rowActions.map((action) => action.selfProtection))).toEqual(new Set(['ocupilot-routine-application']));
    expect(SCREEN_ACTION_DESCRIPTORS).toContain(ROUTINE_APP_LIST_DESCRIPTOR);
  });
});
