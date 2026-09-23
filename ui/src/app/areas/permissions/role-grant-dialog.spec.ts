import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import type { Grant, ResourceOption } from './role-create-form.store';
import { RoleGrantDialog, type GrantResult, grantLine } from './role-grant-dialog';

/**
 * The role form's resource-grant dialog (AC2): it offers only the letters the bootstrap read
 * ships for a resource, marks the ones the server refuses, and shows the current and the
 * resulting grant before Confirm hands the result back. jsdom computes no layout; nothing here
 * asserts geometry.
 */

const REASON = 'OcuPilot does not grant %All or an administrative privilege.';

const RESOURCES: readonly ResourceOption[] = [
  { name: '%Admin_Secure', permissions: 'U', privileged: true, privilegedPermissions: 'U' },
  { name: '%DB_IRISSECURITY', permissions: 'RW', privileged: false, privilegedPermissions: 'W' },
  { name: '%DB_USER', permissions: 'RW', privileged: false, privilegedPermissions: '' },
  { name: 'OcuPilotProbeResource', permissions: 'RWU', privileged: false, privilegedPermissions: '' },
];

function mount(granted: readonly Grant[], editing: Grant | null = null, clearing = false) {
  TestBed.configureTestingModule({
    imports: [RoleGrantDialog],
    providers: [{ provide: OverlayStack, useValue: new OverlayStack() }],
  });
  const fixture = TestBed.createComponent(RoleGrantDialog);
  fixture.componentRef.setInput('resources', RESOURCES);
  fixture.componentRef.setInput('granted', granted);
  fixture.componentRef.setInput('editing', editing);
  fixture.componentRef.setInput('clearing', clearing);
  fixture.componentRef.setInput('privilegeReason', REASON);
  const applied: GrantResult[] = [];
  fixture.componentInstance.applied.subscribe((result) => applied.push(result));
  fixture.detectChanges();
  const host = fixture.nativeElement as HTMLElement;
  return { fixture, host, applied };
}

function text(host: HTMLElement, id: string): string {
  return host.querySelector(`#${id}`)?.textContent?.trim() ?? '';
}

function box(host: HTMLElement, letter: string): HTMLInputElement {
  const input = host.querySelector<HTMLInputElement>(`#ocu-role-grant-${letter}`);
  expect(input).not.toBeNull();
  return input!;
}

function confirmButton(host: HTMLElement): HTMLButtonElement {
  const button = [...host.querySelectorAll<HTMLButtonElement>('button')].find(
    (candidate) => candidate.textContent?.trim() === STRINGS.actionConfirm
  );
  expect(button).toBeDefined();
  return button!;
}

afterEach(() => {
  TestBed.resetTestingModule();
});

describe('the role grant dialog', () => {
  it('writes a grant as its resource and permission words, and no letter as "No grant"', () => {
    expect(grantLine('%DB_USER', 'WR')).toBe(`%DB_USER: ${STRINGS.permissionRead}, ${STRINGS.permissionWrite}`);
    expect(grantLine('%DB_USER', '')).toBe(STRINGS.roleGrantNone);
  });

  it('AC2: add mode offers the resources not yet granted, the admitted letters only, and the current and resulting grant', () => {
    const { fixture, host, applied } = mount([{ name: '%DB_USER', permissions: 'RW' }]);
    const options = [...host.querySelectorAll<HTMLOptionElement>('#ocu-role-grant-resource option')];
    expect(options.map((option) => option.value)).toEqual(['%Admin_Secure', '%DB_IRISSECURITY', 'OcuPilotProbeResource']);
    expect(options[0].disabled).toBe(true);
    expect(host.querySelector('#ocu-role-grant-reason')?.textContent?.trim()).toBe(REASON);

    // The first resource the server does not refuse is chosen: a database admits Read and Write.
    expect(host.querySelector('#ocu-role-grant-U')).toBeNull();
    expect(box(host, 'W').disabled).toBe(true);
    expect(box(host, 'W').getAttribute('aria-describedby')).toBe('ocu-role-grant-reason');
    expect(text(host, 'ocu-role-grant-current')).toBe(STRINGS.roleGrantNone);
    expect(text(host, 'ocu-role-grant-resulting')).toBe(STRINGS.roleGrantNone);
    expect(confirmButton(host).getAttribute('aria-disabled')).toBe('true');
    confirmButton(host).click();
    expect(applied).toEqual([]);

    box(host, 'R').click();
    fixture.detectChanges();
    // Mutation (Rule 19): render the resulting grant in the current line -> the current-line
    // assertion goes red.
    expect(text(host, 'ocu-role-grant-current')).toBe(STRINGS.roleGrantNone);
    expect(text(host, 'ocu-role-grant-resulting')).toBe(`%DB_IRISSECURITY: ${STRINGS.permissionRead}`);
    expect(confirmButton(host).getAttribute('aria-disabled')).toBe('false');
    confirmButton(host).click();
    expect(applied).toEqual([{ name: '%DB_IRISSECURITY', permissions: 'R' }]);
  });

  it('AC2: edit mode starts from the held letters and shows the grant before and after', () => {
    const { fixture, host, applied } = mount(
      [{ name: 'OcuPilotProbeResource', permissions: 'RU' }],
      { name: 'OcuPilotProbeResource', permissions: 'RU' }
    );
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(
      STRINGS.roleGrantDialogEdit.replace('<resource>', 'OcuPilotProbeResource')
    );
    expect(host.querySelector('#ocu-role-grant-resource')).toBeNull();
    expect(box(host, 'R').checked).toBe(true);
    expect(box(host, 'W').checked).toBe(false);
    expect(box(host, 'U').checked).toBe(true);
    box(host, 'U').click();
    box(host, 'W').click();
    fixture.detectChanges();
    expect(text(host, 'ocu-role-grant-current')).toBe(`OcuPilotProbeResource: ${STRINGS.permissionRead}, ${STRINGS.permissionUse}`);
    expect(text(host, 'ocu-role-grant-resulting')).toBe(`OcuPilotProbeResource: ${STRINGS.permissionRead}, ${STRINGS.permissionWrite}`);
    confirmButton(host).click();
    expect(applied).toEqual([{ name: 'OcuPilotProbeResource', permissions: 'RW' }]);
  });

  it('AC2: a Remove opens with no letter ticked, so the resulting grant reads "No grant" before Confirm', () => {
    const { host, applied } = mount([{ name: '%DB_USER', permissions: 'RW' }], { name: '%DB_USER', permissions: 'RW' }, true);
    expect(box(host, 'R').checked).toBe(false);
    expect(text(host, 'ocu-role-grant-current')).toBe(`%DB_USER: ${STRINGS.permissionRead}, ${STRINGS.permissionWrite}`);
    expect(text(host, 'ocu-role-grant-resulting')).toBe(STRINGS.roleGrantNone);
    expect(confirmButton(host).getAttribute('aria-disabled')).toBe('false');
    confirmButton(host).click();
    expect(applied).toEqual([{ name: '%DB_USER', permissions: '' }]);
  });
});
