import { TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { ScreenActions } from '../../core/screen-actions';
import { SCREENS } from '../../core/screens.generated';
import { CREATE_ACTION, TASK_LIST_DESCRIPTOR, TaskActions } from './task-actions';

/**
 * The Task schedule's declared Create (Story 9.7): registered once against the list's descriptor,
 * and opening the New Task wizard at the route the mirror pairs with the list, the namespace
 * carried. The real `ScreenActions` and router run.
 */

async function mount() {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [provideRouter([{ path: '**', children: [] }]), { provide: ScreenActions, useValue: new ScreenActions() }],
  });
  const router = TestBed.inject(Router);
  await router.navigateByUrl('/tasks/schedule?ns=HSCUSTOM');
  const actions = TestBed.inject(ScreenActions);
  TestBed.inject(TaskActions);
  return { actions, router };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('TaskActions', () => {
  it('registers the Create the list declares as its primary action', async () => {
    const { actions } = await mount();
    const list = SCREENS.find((screen) => screen.descriptor === TASK_LIST_DESCRIPTOR);
    expect(list?.primaryAction.id).toBe(CREATE_ACTION);
    expect(actions.has(TASK_LIST_DESCRIPTOR, CREATE_ACTION)).toBe(true);
  });

  it('opens the New Task wizard at its own route, carrying the namespace', async () => {
    const { actions, router } = await mount();
    const navigate = vi.spyOn(router, 'navigateByUrl');
    expect(actions.run(TASK_LIST_DESCRIPTOR, CREATE_ACTION)).toBe(true);
    expect(navigate).toHaveBeenCalledWith('/tasks/schedule/edit?ns=HSCUSTOM');
  });
});
