import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import type { Grant, ResourceOption } from './role-create-form.store';
import { RoleGrantDialog, type GrantResult, grantLine } from './role-grant-dialog';

/**
 * The role form's resource-grant dialog (AC2, AC4): it offers only the letters the bootstrap read
 * ships for a resource, ties Read to Write on a database as the classic dialog does, states the
 * privilege-grant consequence while the resulting grant is of a privileged resource, and shows the
 * current and the resulting grant before Confirm hands the result back. jsdom computes no layout;
 * nothing here asserts geometry.
 */

const RESOURCES: readonly ResourceOption[] = [
  { name: '%Admin_Secure', permissions: 'U', privileged: true },
  { name: '%DB_IRISSECURITY', permissions: 'RW', privileged: false },
  { name: '%DB_USER', permissions: 'RW', privileged: false },
  { name: 'OcuPilotProbeResource', permissions: 'RWU', privileged: false },
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
    const select = host.querySelector<HTMLSelectElement>('#ocu-role-grant-resource')!;
    const options = [...select.querySelectorAll<HTMLOptionElement>('option')];
    expect(options.map((option) => option.value)).toEqual(['%Admin_Secure', '%DB_IRISSECURITY', 'OcuPilotProbeResource']);
    expect(options.some((option) => option.disabled)).toBe(false);

    // A database admits Read and Write, and nothing is refused.
    select.value = '%DB_IRISSECURITY';
    select.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    expect(host.querySelector('#ocu-role-grant-U')).toBeNull();
    expect(box(host, 'W').disabled).toBe(false);
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

  it('AC4: the privilege-grant consequence shows while the resulting grant is of a privileged resource', () => {
    // Mutation (Rule 19): make `showEffect` answer false -> the consequence assertions go red.
    const { fixture, host, applied } = mount([]);
    const select = host.querySelector<HTMLSelectElement>('#ocu-role-grant-resource')!;
    select.value = '%Admin_Secure';
    select.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    expect(host.querySelector('#ocu-role-grant-effect')).toBeNull();
    box(host, 'U').click();
    fixture.detectChanges();
    expect(box(host, 'U').disabled).toBe(false);
    expect(text(host, 'ocu-role-grant-effect')).toBe(STRINGS.privilegedGrantEffect);
    expect(select.getAttribute('aria-describedby')).toBe('ocu-role-grant-effect');
    confirmButton(host).click();
    expect(applied).toEqual([{ name: '%Admin_Secure', permissions: 'U' }]);

    select.value = '%DB_IRISSECURITY';
    select.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    box(host, 'W').click();
    fixture.detectChanges();
    expect(host.querySelector('#ocu-role-grant-effect')).toBeNull();
  });

  it('AC4: in edit mode the consequence describes the permissions, where no resource picker is drawn', () => {
    // Mutation (Rule 19): drop the permissions fieldset's `aria-describedby` -> this goes red.
    const held = { name: '%Admin_Secure', permissions: 'U' };
    const { host } = mount([held], held);
    expect(host.querySelector('#ocu-role-grant-resource')).toBeNull();
    expect(text(host, 'ocu-role-grant-effect')).toBe(STRINGS.privilegedGrantEffect);
    expect(host.querySelector('#ocu-role-grant-permissions')?.getAttribute('aria-describedby')).toBe('ocu-role-grant-effect');
  });

  it('DW-1514: ticking Write on a database ticks and locks Read, as the classic dialog does', () => {
    // Mutation (Rule 19): drop the `writeChanged` line from `onLetter` -> the Read assertions go red.
    const { fixture, host, applied } = mount([]);
    const select = host.querySelector<HTMLSelectElement>('#ocu-role-grant-resource')!;
    select.value = '%DB_IRISSECURITY';
    select.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    box(host, 'W').click();
    fixture.detectChanges();
    expect(box(host, 'R').checked).toBe(true);
    expect(box(host, 'R').disabled).toBe(true);
    expect(text(host, 'ocu-role-grant-resulting')).toBe(`%DB_IRISSECURITY: ${STRINGS.permissionRead}, ${STRINGS.permissionWrite}`);
    box(host, 'W').click();
    fixture.detectChanges();
    expect(box(host, 'R').disabled).toBe(false);
    expect(box(host, 'R').checked).toBe(true);
    confirmButton(host).click();
    expect(applied).toEqual([{ name: '%DB_IRISSECURITY', permissions: 'R' }]);

    // A resource that is not a database's keeps Read and Write independent.
    select.value = 'OcuPilotProbeResource';
    select.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    box(host, 'W').click();
    fixture.detectChanges();
    expect(box(host, 'R').checked).toBe(false);
    expect(box(host, 'R').disabled).toBe(false);
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
