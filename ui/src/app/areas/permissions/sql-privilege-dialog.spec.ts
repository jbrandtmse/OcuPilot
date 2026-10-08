import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import type { Violation } from '../../core/violations';
import { SQL_PRIVILEGE_ACTIONS, SQL_PRIVILEGE_TYPES, SqlPrivilegeDialog, type SqlPrivilegeRequest } from './sql-privilege-dialog';

/** The SQL privilege dialog: the Action list follows the Type, WithGrant is a grant's alone, a refusal's reasons sit beside their field. */

function mount(violations: readonly Violation[] = []) {
  TestBed.configureTestingModule({ imports: [SqlPrivilegeDialog], providers: [{ provide: OverlayStack, useValue: new OverlayStack() }] });
  const fixture = TestBed.createComponent(SqlPrivilegeDialog);
  fixture.componentRef.setInput('violations', violations);
  const submitted: SqlPrivilegeRequest[] = [];
  let closed = 0;
  fixture.componentInstance.submitted.subscribe((request) => submitted.push(request));
  fixture.componentInstance.closed.subscribe(() => (closed += 1));
  fixture.detectChanges();
  const host = fixture.nativeElement as HTMLElement;
  return { fixture, host, submitted, closed: () => closed };
}

function pickType(fixture: ReturnType<typeof mount>['fixture'], host: HTMLElement, type: string) {
  const select = host.querySelector<HTMLSelectElement>('#ocu-sqlpriv-type')!;
  select.value = type;
  select.dispatchEvent(new Event('change'));
  fixture.detectChanges();
}

function typeObject(fixture: ReturnType<typeof mount>['fixture'], host: HTMLElement, text: string) {
  const input = host.querySelector<HTMLInputElement>('#ocu-sqlpriv-object')!;
  input.value = text;
  input.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

function actions(host: HTMLElement): string[] {
  return [...host.querySelectorAll<HTMLOptionElement>('#ocu-sqlpriv-action option')].map((option) => option.value);
}

function submitButton(host: HTMLElement): HTMLButtonElement {
  return host.querySelector<HTMLButtonElement>('#ocu-sqlpriv-submit')!;
}

afterEach(() => TestBed.resetTestingModule());

describe('the SQL privilege dialog', () => {
  it('offers the six types and the actions of the chosen type, resetting an action the new type does not take', () => {
    const { fixture, host } = mount();
    expect([...host.querySelectorAll<HTMLOptionElement>('#ocu-sqlpriv-type option')].map((option) => option.value)).toEqual([...SQL_PRIVILEGE_TYPES]);
    expect(actions(host)).toEqual([...SQL_PRIVILEGE_ACTIONS['TABLE']]);
    pickType(fixture, host, 'STORED PROCEDURE');
    expect(actions(host)).toEqual(['EXECUTE']);
    expect(host.querySelector<HTMLSelectElement>('#ocu-sqlpriv-action')!.value).toBe('EXECUTE');
    pickType(fixture, host, 'VIEW');
    expect(actions(host)).not.toContain('REFERENCES');
    expect(host.querySelector<HTMLSelectElement>('#ocu-sqlpriv-action')!.value).toBe('%ALTER');
    pickType(fixture, host, 'FOREIGN SERVER');
    expect(actions(host)).toEqual(['USE']);
  });

  it('blocks a submit with no object, and a grant carries WithGrant as a flag', () => {
    const { fixture, host, submitted } = mount();
    expect(submitButton(host).getAttribute('aria-disabled')).toBe('true');
    expect(submitButton(host).getAttribute('aria-describedby')).toBe('ocu-sqlpriv-object-hint');
    submitButton(host).click();
    expect(submitted).toEqual([]);
    typeObject(fixture, host, 'S.T1');
    host.querySelector<HTMLInputElement>('#ocu-sqlpriv-withgrant')!.click();
    fixture.detectChanges();
    submitButton(host).click();
    expect(submitted).toEqual([{ mode: 'grant', type: 'TABLE', object: 'S.T1', action: 'SELECT', withGrant: true }]);
    expect(submitButton(host).textContent?.trim()).toBe(STRINGS.sqlPrivilegeGrantAction);
  });

  it('in revoke mode hides the grant option and sends none', () => {
    const { fixture, host, submitted } = mount();
    host.querySelector<HTMLInputElement>('#ocu-sqlpriv-withgrant')!.click();
    host.querySelector<HTMLInputElement>('#ocu-sqlpriv-mode-revoke')!.click();
    fixture.detectChanges();
    expect(host.querySelector('#ocu-sqlpriv-withgrant')).toBeNull();
    typeObject(fixture, host, 'S.T1');
    submitButton(host).click();
    expect(submitted).toEqual([{ mode: 'revoke', type: 'TABLE', object: 'S.T1', action: 'SELECT', withGrant: false }]);
    expect(submitButton(host).textContent?.trim()).toBe(STRINGS.sqlPrivilegeRevokeAction);
  });

  it('draws each violation beside the field it names, and the rest under the form', () => {
    const { host } = mount([
      { field: 'Object', code: 'X', reason: 'Object refused.' },
      { field: 'Action', code: 'X', reason: 'Action refused.' },
      { field: 'Elsewhere', code: 'X', reason: 'Other refused.' },
    ]);
    expect(host.querySelector('#ocu-sqlpriv-object-reason')?.textContent?.trim()).toBe('Object refused.');
    expect(host.querySelector('#ocu-sqlpriv-action-reason')?.textContent?.trim()).toBe('Action refused.');
    expect(host.querySelector('#ocu-sqlpriv-object')?.getAttribute('aria-invalid')).toBe('true');
    expect(host.textContent).toContain('Other refused.');
  });

  it('Cancel closes it', () => {
    const { host, closed } = mount();
    [...host.querySelectorAll<HTMLButtonElement>('button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel)!.click();
    expect(closed()).toBe(1);
  });
});
