import { Component } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { OverlayStack } from '../../core/overlay-stack';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { ListPage } from '../../shell/list-page';
import { LOCALE_LIST, LOCALE_VALIDATE, ScreenActionHandler } from '../../shell/screen-action-handler';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { LocaleListPage } from './locale-list.page';

/**
 * Locale definitions (Story 21.14). The shared list page is replaced by an empty stand-in, so only this page's own wiring runs: Validate
 * registered beside the handler's Install and Delete, its dialog over the selected locale, Install's typed-name dialog stating its published
 * consequence, and Delete offered only on a custom locale that is not current. The handler, the stores and the bus are real; only the
 * server's answers are stubbed.
 */

@Component({ selector: 'app-list-page', template: '' })
class StubListPage {}

const LIST = SCREENS.find((screen) => screen.descriptor === LOCALE_LIST)!;

const ROWS = [
  { Name: 'enuw', Description: 'English (United States) Unicode', Current: true, Custom: false },
  { Name: 'deuw', Description: 'German Unicode', Current: false, Custom: false },
  { Name: 'yzzw', Description: 'Custom locale', Current: false, Custom: true },
  { Name: 'ycur', Description: 'Custom and current', Current: true, Custom: true },
];

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

function mount(answers: JsonResult<unknown>[] = []) {
  TestBed.resetTestingModule();
  const paths: string[] = [];
  const api = {
    requestJson: async <T,>(path: string, _init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      paths.push(path);
      return (answers.shift() ?? { kind: 'ok', status: 200, body: { Valid: true } }) as JsonResult<T>;
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
    ],
  });
  TestBed.overrideComponent(LocaleListPage, { remove: { imports: [ListPage] }, add: { imports: [StubListPage] } });
  const store = stores.for(LIST.descriptor, LIST.refreshRates);
  store.applyTick(ROWS, false, '', new Date());
  const fixture = TestBed.createComponent(LocaleListPage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, store, paths, actions: TestBed.inject(ScreenActions), handler: TestBed.inject(ScreenActionHandler) };
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Locale definitions page', () => {
  // Mutation (Rule 19): drop this page's `actions.register` of `validate` -> the first assertion goes red, and no surface offers Validate.
  it('registers Validate beside the handler\u2019s Install and Delete', () => {
    const { actions } = mount();
    expect(actions.has(LOCALE_LIST, LOCALE_VALIDATE)).toBe(true);
    expect(actions.has(LOCALE_LIST, 'install')).toBe(true);
    expect(actions.has(LOCALE_LIST, 'delete')).toBe(true);
  });

  it('opens the Validate dialog over the selected locale, reads its validation, and opens nothing while none is selected', async () => {
    const { fixture, host, store, actions, paths } = mount();
    actions.run(LOCALE_LIST, LOCALE_VALIDATE);
    await settle(fixture);
    expect(host.querySelector('app-locale-validate-dialog')).toBeNull();
    store.setSelection(['deuw']);
    actions.run(LOCALE_LIST, LOCALE_VALIDATE);
    await settle(fixture);
    expect(host.querySelector('[data-locale-validate-name]')?.textContent?.trim()).toBe('deuw');
    expect(paths).toEqual(['/api/ocupilot/locales/deuw/validation']);
    expect(host.querySelector('[data-locale-validate-result]')?.textContent?.trim()).toBe(STRINGS.localeValidateValid);
    (host.querySelector('.ocu-dialog-actions button') as HTMLButtonElement).click();
    await settle(fixture);
    expect(host.querySelector('app-locale-validate-dialog')).toBeNull();
  });

  // Mutation (Rule 19): drop `LOCALE_LIST` from `DESTRUCTIVE_ON` -> Install is sent at once, no typed-name dialog opens and this goes red.
  it('confirms an Install by typing the locale\u2019s name and states the published consequence', async () => {
    const { fixture, store, actions, handler, paths } = mount();
    store.setSelection(['deuw']);
    actions.run(LOCALE_LIST, 'install');
    await settle(fixture);
    const pending = handler.pending();
    expect(pending?.kind).toBe('typed-name');
    expect(pending?.consequence).toBe(STRINGS.localeInstallConsequence);
    expect(pending?.name).toBe('deuw');
    expect(paths).toEqual([]);
  });

  // Mutation (Rule 19): drop the `ROW_REASONS` entry for `delete` -> every locale offers Delete and the reasons below read empty.
  it('offers Delete on a custom locale that is not current alone, saying why on the others', () => {
    const { store, actions } = mount();
    store.setSelection(['yzzw']);
    expect(actions.reason(LOCALE_LIST, 'delete')).toBe('');
    store.setSelection(['deuw']);
    expect(actions.reason(LOCALE_LIST, 'delete')).toBe(STRINGS.localeRefusalSystem);
    store.setSelection(['enuw']);
    expect(actions.reason(LOCALE_LIST, 'delete')).toBe(STRINGS.localeRefusalSystem);
    store.setSelection(['ycur']);
    expect(actions.reason(LOCALE_LIST, 'delete')).toBe(STRINGS.localeRefusalCurrent);
    expect(actions.run(LOCALE_LIST, 'delete')).toBe(false);
  });

  it('types the name of a custom locale to confirm Delete and states the published consequence', async () => {
    const { fixture, store, actions, handler } = mount();
    store.setSelection(['yzzw']);
    actions.run(LOCALE_LIST, 'delete');
    await settle(fixture);
    expect(handler.pending()?.kind).toBe('typed-name');
    expect(handler.pending()?.consequence).toBe(STRINGS.localeDeleteConsequence);
    expect(handler.pending()?.name).toBe('yzzw');
  });
});
