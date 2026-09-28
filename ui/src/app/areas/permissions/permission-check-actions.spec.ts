import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { screenForDescriptor } from '../../core/navigation';
import { PERMISSION_CHECK_ACTION_ID, ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { PermissionCheck } from '../../shell/permission-check';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { ROLE_LIST_DESCRIPTOR, RoleActions } from './role-actions';
import { USER_LIST_DESCRIPTOR, UserActions } from './user-actions';

/**
 * Check permission on the Users and Roles lists (Story 16.3): each list's root registration opens
 * the dialog on its own descriptor, as a user or a role, prefilled with the selected row or blank.
 */

function mount(): { readonly actions: ScreenActions; readonly stores: ScreenStores; readonly check: PermissionCheck } {
  const actions = new ScreenActions();
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  TestBed.configureTestingModule({
    providers: [provideRouter([]), { provide: ScreenActions, useValue: actions }, { provide: ScreenStores, useValue: stores }],
  });
  TestBed.inject(UserActions);
  TestBed.inject(RoleActions);
  return { actions, stores, check: TestBed.inject(PermissionCheck) };
}

function select(stores: ScreenStores, descriptor: string, id: string): void {
  const screen = screenForDescriptor(descriptor);
  if (screen === null) throw new Error(`no screen for ${descriptor}`);
  stores.for(screen.descriptor, screen.refreshRates).setSelection([id]);
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('Check permission on the Users and Roles lists (Story 16.3)', () => {
  it('opens on the Users list as a user, blank with no selection and prefilled with the selected row', () => {
    const { actions, stores, check } = mount();
    expect(actions.run(USER_LIST_DESCRIPTOR, PERMISSION_CHECK_ACTION_ID)).toBe(true);
    expect(check.pending()).toEqual({ descriptor: USER_LIST_DESCRIPTOR, kind: 'user', name: '' });
    select(stores, USER_LIST_DESCRIPTOR, 'Dana');
    actions.run(USER_LIST_DESCRIPTOR, PERMISSION_CHECK_ACTION_ID);
    expect(check.pending()).toEqual({ descriptor: USER_LIST_DESCRIPTOR, kind: 'user', name: 'Dana' });
  });

  it('opens on the Roles list as a role, prefilled with the selected row', () => {
    // Mutation (Rule 19): open with kind 'user' in `RoleActions` -> the pending assertions go red.
    const { actions, stores, check } = mount();
    expect(actions.run(ROLE_LIST_DESCRIPTOR, PERMISSION_CHECK_ACTION_ID)).toBe(true);
    expect(check.pending()).toEqual({ descriptor: ROLE_LIST_DESCRIPTOR, kind: 'role', name: '' });
    select(stores, ROLE_LIST_DESCRIPTOR, '%Manager');
    actions.run(ROLE_LIST_DESCRIPTOR, PERMISSION_CHECK_ACTION_ID);
    expect(check.pending()).toEqual({ descriptor: ROLE_LIST_DESCRIPTOR, kind: 'role', name: '%Manager' });
  });
});
