import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { FormDirty } from '../../core/form-dirty';
import {
  LICENSE_SERVER_FORM_PATH,
  LICENSE_SERVER_NAME_PATH,
  LicenseServerForm,
  NAME_TAKEN_CODE,
  wireValue,
} from './license-server-form.store';

/**
 * The license server form's store (Story 18.6) over a stub of the HTTP answers: the blur look-up, the
 * required-field rule, an absent edit and the wire shape of the port.
 */

const RULES = {
  requiredFields: ['Name', 'Address', 'Port'],
  maxLengths: { Name: 64, Address: 256 },
  rules: [{ field: 'Address', code: 'LICENSE.SERVER.ADDRESS', reason: "Enter the license server's host name or IP address." }],
};

function mount(answer: (path: string) => JsonResult<unknown>) {
  TestBed.resetTestingModule();
  const paths: string[] = [];
  const api = {
    requestJson: async <T,>(path: string): Promise<JsonResult<T>> => {
      paths.push(path);
      return answer(path) as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: FormDirty, useValue: new FormDirty() },
      { provide: ChangeBus, useValue: new ChangeBus() },
    ],
  });
  return { store: TestBed.inject(LicenseServerForm), paths };
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('LicenseServerForm', () => {
  it('a name the instance already holds is marked taken on blur, with its own sentence', async () => {
    const { store, paths } = mount((path) =>
      path.startsWith(LICENSE_SERVER_NAME_PATH)
        ? { kind: 'ok', status: 200, body: { name: 'LOCAL', taken: true, reason: 'A license server of that name already exists.' } }
        : { kind: 'ok', status: 200, body: RULES }
    );
    await store.open('');
    store.setValue('Name', 'local');
    await store.onBlur('Name');
    expect(paths).toContain(`${LICENSE_SERVER_NAME_PATH}?name=local`);
    expect(store.violations()).toEqual([{ field: 'Name', code: NAME_TAKEN_CODE, reason: 'A license server of that name already exists.' }]);
  });

  it("a name of the wrong shape takes the look-up's own refusal on blur", async () => {
    const shape = { field: 'Name', code: 'LICENSE.SERVER.NAME.SHAPE', reason: 'Use up to 64 letters, digits, hyphens and underscores, starting with a letter or digit.' };
    const { store } = mount((path) =>
      path.startsWith(LICENSE_SERVER_NAME_PATH)
        ? { kind: 'error', status: 422, code: 'LICENSE.SERVER.VALIDATION', reason: 'The request was refused.', detail: { violations: [shape] } }
        : { kind: 'ok', status: 200, body: RULES }
    );
    await store.open('');
    store.setValue('Name', 'a b');
    await store.onBlur('Name');
    // Mutation (Rule 19): drop the 422 branch from onBlur -> red.
    expect(store.violations()).toEqual([shape]);
  });

  it("an empty required address takes the form read's own sentence on blur", async () => {
    const { store } = mount(() => ({ kind: 'ok', status: 200, body: RULES }));
    await store.open('');
    await store.onBlur('Address');
    expect(store.violationFor('Address')).toBe("Enter the license server's host name or IP address.");
  });

  it('an edit of a server the instance does not hold is absent and cannot save', async () => {
    const { store, paths } = mount(() => ({ kind: 'error', status: 404, code: 'PORT.NOTFOUND', reason: 'Not found.', detail: null }));
    await store.open('OCUPROBE186GONE');
    expect(paths).toEqual([`${LICENSE_SERVER_FORM_PATH}?name=OCUPROBE186GONE`]);
    expect(store.absent()).toBe(true);
    expect(store.canSave()).toBe(false);
  });

  it('the port travels as an integer when it is a whole number, and as typed otherwise', () => {
    expect(wireValue('Port', ' 4999 ')).toBe(4999);
    expect(wireValue('Port', 'x')).toBe('x');
    expect(wireValue('Address', '127.0.0.1')).toBe('127.0.0.1');
  });
});
