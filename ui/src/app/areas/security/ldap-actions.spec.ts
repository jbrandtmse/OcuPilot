import { TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it, vi } from 'vitest';

import { ScreenActions } from '../../core/screen-actions';
import { SCREENS } from '../../core/screens.generated';
import { SCREEN_ACTION_DESCRIPTORS } from '../../shell/screen-action-handler';
import { CREATE_ACTION, LDAP_LIST_DESCRIPTOR, LdapActions } from './ldap-actions';

/**
 * The LDAP / Kerberos list's declared Create and Delete (Story 16.14): Create registered once against
 * the list's descriptor and opening the editor at the bare route the mirror pairs with the list, the
 * namespace carried; Delete carried by the screen action handler. The real `ScreenActions` and router
 * run.
 */

async function mount() {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({
    providers: [provideRouter([{ path: '**', children: [] }]), { provide: ScreenActions, useValue: new ScreenActions() }],
  });
  const router = TestBed.inject(Router);
  await router.navigateByUrl('/security/ldap?ns=HSCUSTOM');
  const actions = TestBed.inject(ScreenActions);
  TestBed.inject(LdapActions);
  return { actions, router };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('LdapActions', () => {
  it('registers the Create the list declares as its primary action', async () => {
    const { actions } = await mount();
    const list = SCREENS.find((screen) => screen.descriptor === LDAP_LIST_DESCRIPTOR);
    expect(list?.primaryAction.id).toBe(CREATE_ACTION);
    expect(actions.has(LDAP_LIST_DESCRIPTOR, CREATE_ACTION)).toBe(true);
  });

  it('opens the editor at its bare route, carrying the namespace', async () => {
    const { actions, router } = await mount();
    const navigate = vi.spyOn(router, 'navigateByUrl');
    expect(actions.run(LDAP_LIST_DESCRIPTOR, CREATE_ACTION)).toBe(true);
    expect(navigate).toHaveBeenCalledWith('/security/ldap/edit?ns=HSCUSTOM');
  });

  it('leaves the row Delete the list declares to the screen action handler', () => {
    const list = SCREENS.find((screen) => screen.descriptor === LDAP_LIST_DESCRIPTOR);
    expect(list?.rowActions.map((action) => action.id)).toEqual(['delete']);
    expect(SCREEN_ACTION_DESCRIPTORS).toContain(LDAP_LIST_DESCRIPTOR);
  });
});
