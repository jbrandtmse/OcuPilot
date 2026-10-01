import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { ServiceRolesDialog } from './service-roles-dialog';

/**
 * The Edit roles dialog (Story 16.13, AC3): its title names the address, it draws one checkbox per
 * role option in the read's order ticked where the entry holds the role, Apply hands back the ticked
 * roles, and Cancel hands back nothing.
 */

const OPTIONS = [
  { name: '%All', privileged: true },
  { name: '%Manager', privileged: false },
  { name: '%Operator', privileged: false },
];

const planted: HTMLElement[] = [];

function mount(held: readonly string[]): { fixture: ComponentFixture<ServiceRolesDialog>; host: HTMLElement; applied: (readonly string[])[]; closed: number[] } {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({ providers: [{ provide: OverlayStack, useValue: new OverlayStack() }] });
  const fixture = TestBed.createComponent(ServiceRolesDialog);
  fixture.componentRef.setInput('address', '10.0.0.5');
  fixture.componentRef.setInput('held', held);
  fixture.componentRef.setInput('options', OPTIONS);
  const applied: (readonly string[])[] = [];
  const closed: number[] = [];
  fixture.componentInstance.applied.subscribe((roles) => applied.push(roles));
  fixture.componentInstance.closed.subscribe(() => closed.push(1));
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement, applied, closed };
}

function boxes(host: HTMLElement): HTMLInputElement[] {
  return [...host.querySelectorAll('#ocu-service-roles input[type="checkbox"]')] as HTMLInputElement[];
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('the Edit roles dialog', () => {
  it('is titled with the address and draws the read\u2019s roles in its order, ticked where the entry holds them', () => {
    const { host } = mount(['%manager']);
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.serviceAddressRolesTitle.replace('<address>', '10.0.0.5'));
    const labels = [...host.querySelectorAll('#ocu-service-roles .ocu-field-checkbox span')].map((span) => span.textContent?.trim());
    expect(labels).toEqual(['%All', '%Manager', '%Operator']);
    expect(boxes(host).map((box) => box.checked)).toEqual([false, true, false]);
  });

  it('Apply hands back the ticked roles; Cancel hands back nothing', () => {
    // Mutation (Rule 19): make Apply emit the held roles instead of the ticked ones -> the Apply leg goes red.
    const { fixture, host, applied, closed } = mount([]);
    const operator = boxes(host)[2];
    operator.checked = true;
    operator.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    const apply = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionApply) as HTMLButtonElement;
    apply.click();
    expect(applied).toEqual([['%Operator']]);
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    expect(applied).toHaveLength(1);
    expect(closed).toHaveLength(1);
  });

  it('keeps a held role the read did not list, so an Apply never drops it', () => {
    const { host } = mount(['%Retired']);
    const labels = [...host.querySelectorAll('#ocu-service-roles .ocu-field-checkbox span')].map((span) => span.textContent?.trim());
    expect(labels).toEqual(['%All', '%Manager', '%Operator', '%Retired']);
    expect(boxes(host)[3].checked).toBe(true);
  });
});
