import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../core/api';
import { ChangeBus } from '../core/change-bus';
import { OverlayStack } from '../core/overlay-stack';
import { ScopeService } from '../core/scope';
import { ScreenActions } from '../core/screen-actions';
import { ScreenStores } from '../core/screen-store';
import { SCREENS } from '../core/screens.generated';
import { stubAccountPreferences } from '../testing/account-preferences';
import { ALLOWED_DIRECTORY_LIST } from './screen-action-handler';
import { ScreenActionDialogs } from './screen-action-dialogs';

/**
 * What `app-screen-action-dialogs` renders beside the handler's own dialogs (Story 18.46): the Allowed directories list's
 * actions and dialogs, for that descriptor alone. The handler's dialogs are pinned by the specs of the screens that open
 * them.
 */

/** The actions the Allowed directories descriptor declares, read from the mirror: the primary action, then the row actions. */
const DECLARED = (() => {
  const screen = SCREENS.find((entry) => entry.descriptor === ALLOWED_DIRECTORY_LIST)!;
  return [screen.primaryAction.id, ...screen.rowActions.map((action) => action.id)].filter((id) => id !== '');
})();

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

function mount(descriptor: string) {
  TestBed.resetTestingModule();
  const api = {
    requestJson: async <T,>(_path: string, _init: ApiRequestInit = {}): Promise<JsonResult<T>> =>
      ({ kind: 'ok', status: 200, body: { enabled: true } }) as JsonResult<T>,
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScopeService, useValue: { namespace: () => 'USER' } as unknown as ScopeService },
    ],
  });
  const fixture: ComponentFixture<ScreenActionDialogs> = TestBed.createComponent(ScreenActionDialogs);
  fixture.componentRef.setInput('descriptor', descriptor);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, actions: TestBed.inject(ScreenActions) };
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the screen action dialogs, beside the handler\u2019s', () => {
  it('render the Allowed directories actions and dialogs for that descriptor, which register its three actions', () => {
    // Mutation (Rule 19): drop the `hasAllowedDirectories` branch from the template -> no action registers and this goes red.
    const { actions } = mount(ALLOWED_DIRECTORY_LIST);
    for (const id of DECLARED) expect(actions.has(ALLOWED_DIRECTORY_LIST, id), id).toBe(true);
  });

  it('render nothing of them for any other descriptor', () => {
    const { actions } = mount('OcuPilot.Screen.Descriptor.WebAppList');
    for (const id of DECLARED) expect(actions.has(ALLOWED_DIRECTORY_LIST, id), id).toBe(false);
  });

  it('unregister the actions when the screen goes', () => {
    const { fixture, actions } = mount(ALLOWED_DIRECTORY_LIST);
    fixture.destroy();
    for (const id of DECLARED) expect(actions.has(ALLOWED_DIRECTORY_LIST, id), id).toBe(false);
  });

  it('forward an Allowed directories dialog\u2019s confirming answer as acting, so the list page moves focus off the dialog first', async () => {
    // Mutation (Rule 19): drop the `(acting)` binding on `app-allowed-directory-dialogs` -> nothing is forwarded and this goes red.
    const { fixture, actions } = mount(ALLOWED_DIRECTORY_LIST);
    const screen = SCREENS.find((entry) => entry.descriptor === ALLOWED_DIRECTORY_LIST)!;
    const store = TestBed.inject(ScreenStores).for(screen.descriptor, screen.refreshRates);
    store.applyTick([{ Directory: '/iris/mgr/', Restricted: true }, { Directory: '/data/a/', Restricted: true }] as never, false, '', new Date());
    store.setSelection(['/data/a/']);
    let acting = 0;
    fixture.componentInstance.acting.subscribe(() => (acting += 1));
    await settle(fixture);
    actions.run(ALLOWED_DIRECTORY_LIST, 'remove');
    await settle(fixture);
    const host = fixture.nativeElement as HTMLElement;
    const field = host.querySelector('.ocu-typed-name-field') as HTMLInputElement;
    field.value = '/data/a/';
    field.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    expect(acting, 'nothing is forwarded before the name is confirmed').toBe(0);
    (host.querySelector('.ocu-button-destructive') as HTMLButtonElement).click();
    await settle(fixture);
    expect(acting).toBe(1);
  });
});
