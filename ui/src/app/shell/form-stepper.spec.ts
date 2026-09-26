import { ChangeDetectionStrategy, Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { STRINGS } from '../core/strings';
import { FormStepBody, FormStepper, type FormStepView, REASON_PLACEHOLDER, stepErrorLine } from './form-stepper';

/**
 * The vertical stepper (Story 9.7, AC1): an ordered list of named step buttons over bodies that
 * stay in the DOM, `aria-current="step"` on the current one, a step in error marked and named in
 * text, and a step not yet reached drawn disabled. The real component and template run under a
 * small host.
 */

@Component({
  selector: 'app-stepper-host',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [FormStepper, FormStepBody],
  template: `<app-form-stepper [steps]="steps()" [selected]="selected()" (selectedChange)="chosen.push($event)">
    <ng-template ocuFormStep="one"><input id="stepper-one" [attr.aria-label]="names.one" /></ng-template>
    <ng-template ocuFormStep="two"><input id="stepper-two" [attr.aria-label]="names.two" /></ng-template>
    <ng-template ocuFormStep="three"><input id="stepper-three" [attr.aria-label]="names.three" /></ng-template>
  </app-form-stepper>`,
})
class StepperHost {
  readonly names = { one: 'one', two: 'two', three: 'three' };

  readonly steps = signal<readonly FormStepView[]>([
    { key: 'one', label: 'First', count: 0, firstReason: '', reachable: true },
    { key: 'two', label: 'Second', count: 0, firstReason: '', reachable: true },
    { key: 'three', label: 'Third', count: 0, firstReason: '', reachable: false },
  ]);

  readonly selected = signal('one');

  readonly chosen: string[] = [];
}

const planted: HTMLElement[] = [];

function mount(): { fixture: ComponentFixture<StepperHost>; host: HTMLElement } {
  TestBed.resetTestingModule();
  const fixture = TestBed.createComponent(StepperHost);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  return { fixture, host: fixture.nativeElement as HTMLElement };
}

function heads(host: HTMLElement): HTMLButtonElement[] {
  return [...host.querySelectorAll('.ocu-form-step-head')] as HTMLButtonElement[];
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
  TestBed.resetTestingModule();
});

describe('FormStepper', () => {
  it('AC1: is an ordered list of the steps in order, the current one marked aria-current="step"', () => {
    const { fixture, host } = mount();
    const list = host.querySelector('ol.ocu-form-stepper');
    expect(list).not.toBeNull();
    expect([...host.querySelectorAll('ol.ocu-form-stepper > li')].map((item) => item.getAttribute('data-step'))).toEqual(['one', 'two', 'three']);
    expect(heads(host).map((head) => head.getAttribute('aria-current'))).toEqual(['step', null, null]);
    fixture.componentInstance.selected.set('two');
    fixture.detectChanges();
    expect(heads(host).map((head) => head.getAttribute('aria-current'))).toEqual([null, 'step', null]);
  });

  it('keeps every body in the DOM and shows only the current one, so a value on another step survives', () => {
    const { fixture, host } = mount();
    const two = host.querySelector('#stepper-two') as HTMLInputElement;
    two.value = 'kept';
    expect((host.querySelector('[data-step-body="one"]') as HTMLElement).hidden).toBe(false);
    expect((host.querySelector('[data-step-body="two"]') as HTMLElement).hidden).toBe(true);
    fixture.componentInstance.selected.set('two');
    fixture.detectChanges();
    expect((host.querySelector('[data-step-body="two"]') as HTMLElement).hidden).toBe(false);
    expect((host.querySelector('#stepper-two') as HTMLInputElement).value).toBe('kept');
  });

  it('draws a step not yet reached disabled, and answers a chosen reachable step on selectedChange', () => {
    const { host, fixture } = mount();
    const [, second, third] = heads(host);
    expect(third.disabled).toBe(true);
    expect(second.disabled).toBe(false);
    second.click();
    third.click();
    heads(host)[0].click();
    expect(fixture.componentInstance.chosen).toEqual(['two']);
  });

  it('AC1: a step in error carries the marker, names its first refusal in text, and counts it in its accessible name', () => {
    const { fixture, host } = mount();
    fixture.componentInstance.steps.set([
      { key: 'one', label: 'First', count: 2, firstReason: 'Give the task a name.', reachable: true },
      { key: 'two', label: 'Second', count: 0, firstReason: '', reachable: true },
      { key: 'three', label: 'Third', count: 0, firstReason: '', reachable: false },
    ]);
    fixture.detectChanges();
    const [first, second] = heads(host);
    expect(first.classList.contains('ocu-form-step-invalid')).toBe(true);
    expect(second.classList.contains('ocu-form-step-invalid')).toBe(false);
    expect(first.getAttribute('aria-label')).toBe('First, 2 errors');
    expect(second.getAttribute('aria-label')).toBe('Second');
    // Mutation (Rule 19): drop the `@if (step.error)` line from the template -> this goes red.
    const line = host.querySelector('#ocu-form-step-error-one');
    expect(line?.textContent?.trim()).toBe(stepErrorLine('Give the task a name.'));
    expect(line?.textContent).toContain('Give the task a name.');
    expect(first.getAttribute('aria-describedby')).toBe('ocu-form-step-error-one');
    expect(host.querySelector('#ocu-form-step-error-two')).toBeNull();
  });

  it('the step error line is the published sentence with the refusal in its placeholder', () => {
    expect(STRINGS.taskStepError).toContain(REASON_PLACEHOLDER);
    expect(stepErrorLine('X')).toBe(STRINGS.taskStepError.split(REASON_PLACEHOLDER).join('X'));
    expect(stepErrorLine('X')).not.toContain(REASON_PLACEHOLDER);
  });
});
