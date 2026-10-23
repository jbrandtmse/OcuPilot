import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ALLOWED_DIRECTORIES_PATH, ALLOWED_DIRECTORY_LIST } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { ALLOWED_DIRECTORY_ACTIONS, AllowedDirectoryActions } from './allowed-directory-actions';
import { AllowedDirectoryDialogs } from './allowed-directory-dialogs';

/**
 * The Allowed directories screen's actions and dialogs (Story 18.46): the three actions it registers with the instance's
 * verdict, and the warning and typed-name dialogs they open. The real service, handler, stores and `ScreenActions` run; only
 * the transport is stubbed.
 */

const SCREEN = SCREENS.find((entry) => entry.descriptor === ALLOWED_DIRECTORY_LIST)!;

/** The actions the descriptor declares, read from the mirror: the primary action, then the row actions. */
const DECLARED = [SCREEN.primaryAction.id, ...SCREEN.rowActions.map((action) => action.id)].filter((id) => id !== '');

const TARGET = { type: 'allowed-directory', scope: 'instance', id: '%GUIFileSelector' };

const MANAGER = '/iris/mgr/';

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

function mount(verdict: JsonResult<unknown> = { kind: 'ok', status: 200, body: { enabled: true } }) {
  TestBed.resetTestingModule();
  const calls: { method: string; path: string; body: string }[] = [];
  const api = {
    requestJson: async <T,>(path: string, init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      const method = init.method ?? 'GET';
      calls.push({ method, path, body: init.body ?? '' });
      if (method === 'POST') return { kind: 'ok', status: 200, body: { action: 'created', target: TARGET, readBack: {} } } as JsonResult<T>;
      return verdict as JsonResult<T>;
    },
  };
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ChangeBus, useValue: new ChangeBus() },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ScopeService, useValue: { namespace: () => 'USER' } as unknown as ScopeService },
    ],
  });
  const fixture = TestBed.createComponent(AllowedDirectoryDialogs);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  const store = stores.for(SCREEN.descriptor, SCREEN.refreshRates);
  return { fixture, host: fixture.nativeElement as HTMLElement, calls, store, actions: TestBed.inject(ScreenActions) };
}

function show(store: ReturnType<typeof mount>['store'], rows: readonly unknown[], selected = ''): void {
  store.applyTick(rows as never, false, '', new Date());
  store.setSelection(selected === '' ? [] : [selected]);
}

function typeInto(host: HTMLElement, selector: string, value: string): void {
  const input = host.querySelector(selector) as HTMLInputElement;
  input.value = value;
  input.dispatchEvent(new Event('input'));
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Allowed directories actions and dialogs', () => {
  it('registers Add, Change and Remove against the descriptor with the verdict as their reason, and unregisters them with the screen', async () => {
    // Mutation (Rule 19): drop the reason argument from the `register` calls -> the held-back legs go red; drop the
    // unregistering from `onDestroy` -> the last leg goes red; drop `remove` from `ALLOWED_DIRECTORY_ACTIONS` -> the
    // declared-set leg goes red.
    expect([...ALLOWED_DIRECTORY_ACTIONS], 'every action the descriptor declares is registered').toEqual(DECLARED);
    const { fixture, actions, calls } = mount({ kind: 'ok', status: 200, body: { enabled: false, code: 'ALLOWLIST.OFF', reason: STRINGS.allowListRefusalOff } });
    await settle(fixture);
    expect(calls.map((call) => [call.method, call.path])).toEqual([['GET', ALLOWED_DIRECTORIES_PATH]]);
    for (const id of DECLARED) {
      expect(actions.has(ALLOWED_DIRECTORY_LIST, id), id).toBe(true);
      expect(actions.reason(ALLOWED_DIRECTORY_LIST, id), id).toBe(STRINGS.allowListRefusalOff);
      expect(actions.run(ALLOWED_DIRECTORY_LIST, id), id).toBe(false);
    }
    expect(fixture.nativeElement.querySelector('[role="dialog"]'), 'a held-back action opens nothing').toBeNull();

    fixture.destroy();
    for (const id of DECLARED) expect(actions.has(ALLOWED_DIRECTORY_LIST, id), id).toBe(false);
  });

  it('closes the dialog that stands when the screen goes, so a return to the screen finds none', async () => {
    // Mutation (Rule 19): drop `this.service.cancel()` from `onDestroy` -> the root service still holds the Add, red.
    const { fixture, actions, store } = mount();
    show(store, [{ Directory: MANAGER, Restricted: true }]);
    await settle(fixture);
    actions.run(ALLOWED_DIRECTORY_LIST, 'add');
    await settle(fixture);
    const service = TestBed.inject(AllowedDirectoryActions);
    expect(service.pending()?.action).toBe('add');
    fixture.destroy();
    expect(service.pending()).toBeNull();
  });

  it('opens Add as a warning with a Directory text field and the plain consequence on a restricted list, and sends what was typed', async () => {
    const { fixture, host, actions, store, calls } = mount();
    show(store, [{ Directory: MANAGER, Restricted: true }]);
    await settle(fixture);
    expect(actions.run(ALLOWED_DIRECTORY_LIST, 'add')).toBe(true);
    await settle(fixture);

    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.allowedDirectoryAddAction);
    expect(host.querySelector('.ocu-warning-consequence')?.textContent?.trim()).toBe(STRINGS.allowedDirectoryAddConsequence);
    expect(host.querySelector('[data-slot="field"] label')?.textContent?.trim()).toBe(STRINGS.lockColumnDirectory);
    expect(host.querySelector('[data-slot="field"] .ocu-field-caption')?.textContent?.trim()).toBe(STRINGS.allowedDirectoryHint);
    expect((host.querySelector('[data-slot="field"] input') as HTMLInputElement).hasAttribute('inputmode')).toBe(false);

    typeInto(host, '[data-slot="field"] input', ' /data/b/ ');
    fixture.detectChanges();
    (host.querySelector('.ocu-dialog-actions .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    const posts = calls.filter((call) => call.method === 'POST');
    expect(posts).toHaveLength(1);
    expect(JSON.parse(posts[0].body)).toEqual({ Action: 'add', Directory: '/data/b/' });
    expect(host.querySelector('[role="dialog"]'), 'the dialog closed').toBeNull();
  });

  it('words an Add on an unrestricted list with the restricting consequence', async () => {
    // Mutation (Rule 19): swap the two consequences in `consequenceOf` -> this and the restricted leg go red.
    const { fixture, host, actions, store } = mount();
    show(store, [{ Directory: MANAGER, Restricted: false }]);
    await settle(fixture);
    actions.run(ALLOWED_DIRECTORY_LIST, 'add');
    await settle(fixture);
    expect(host.querySelector('.ocu-warning-consequence')?.textContent?.trim()).toBe(STRINGS.allowedDirectoryAddRestricts);
  });

  it('opens Change as a warning naming the row, labeled New directory, and sends it as NewDirectory', async () => {
    const { fixture, host, actions, store, calls } = mount();
    show(store, [{ Directory: MANAGER, Restricted: true }, { Directory: '/data/a/', Restricted: true }], '/data/a/');
    await settle(fixture);
    actions.run(ALLOWED_DIRECTORY_LIST, 'change');
    await settle(fixture);

    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.allowedDirectoryChangeAction);
    expect(host.querySelector('.ocu-warning-consequence')?.textContent?.trim()).toBe(
      STRINGS.allowedDirectoryChangeConsequence.replace('<directory>', '/data/a/')
    );
    expect(host.querySelector('[data-slot="field"] label')?.textContent?.trim()).toBe(STRINGS.allowedDirectoryNewLabel);

    typeInto(host, '[data-slot="field"] input', '/data/b/');
    fixture.detectChanges();
    (host.querySelector('.ocu-dialog-actions .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    const posts = calls.filter((call) => call.method === 'POST');
    expect(JSON.parse(posts[0].body)).toEqual({ Action: 'change', Directory: '/data/a/', NewDirectory: '/data/b/' });
  });

  it('opens Remove as a typed-name confirmation on the directory, releases it on the exact name alone, and sends the remove', async () => {
    const { fixture, host, actions, store, calls } = mount();
    show(store, [{ Directory: MANAGER, Restricted: true }, { Directory: '/data/a/', Restricted: true }], '/data/a/');
    await settle(fixture);
    actions.run(ALLOWED_DIRECTORY_LIST, 'remove');
    await settle(fixture);

    expect(host.querySelector('.ocu-typed-name-consequence')?.textContent?.trim()).toBe(STRINGS.allowedDirectoryRemoveConsequence);
    const confirm = (): HTMLButtonElement => host.querySelector('.ocu-button-destructive') as HTMLButtonElement;
    expect(confirm().textContent?.trim()).toBe(`${STRINGS.actionRemove} /data/a/`);
    typeInto(host, '.ocu-typed-name-field', '/data/A/');
    fixture.detectChanges();
    expect(confirm().getAttribute('aria-disabled')).toBe('true');
    confirm().click();
    await settle(fixture);
    expect(calls.filter((call) => call.method === 'POST')).toEqual([]);

    typeInto(host, '.ocu-typed-name-field', '/data/a/');
    fixture.detectChanges();
    confirm().click();
    await settle(fixture);
    const posts = calls.filter((call) => call.method === 'POST');
    expect(JSON.parse(posts[0].body)).toEqual({ Action: 'remove', Directory: '/data/a/' });
  });

  it('emits acting just before a confirm reaches the service, and Cancel sends nothing', async () => {
    const { fixture, host, actions, store, calls } = mount();
    show(store, [{ Directory: MANAGER, Restricted: true }]);
    let acting = 0;
    fixture.componentInstance.acting.subscribe(() => (acting += 1));
    await settle(fixture);
    actions.run(ALLOWED_DIRECTORY_LIST, 'add');
    await settle(fixture);
    (host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(acting).toBe(0);
    expect(host.querySelector('[role="dialog"]')).toBeNull();
    expect(calls.filter((call) => call.method === 'POST')).toEqual([]);

    actions.run(ALLOWED_DIRECTORY_LIST, 'add');
    await settle(fixture);
    typeInto(host, '[data-slot="field"] input', '/data/b/');
    fixture.detectChanges();
    (host.querySelector('.ocu-dialog-actions .ocu-button-primary') as HTMLButtonElement).click();
    await settle(fixture);
    expect(acting).toBe(1);
  });
});
