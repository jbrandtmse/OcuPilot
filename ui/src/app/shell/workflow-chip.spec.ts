import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';

import { STRINGS } from '../core/strings';
import { WorkflowChip } from './workflow-chip';

/**
 * The guided-workflow chip (Story 20.12): the label, the starting prompt's text, Continue and End
 * workflow. Continue is `aria-disabled`, never hidden or natively disabled, and says nothing while it
 * is; neither control decides a proposal.
 */

@Component({
  imports: [WorkflowChip],
  template: `<app-workflow-chip
    [text]="text()"
    [continueDisabled]="disabled()"
    [reasonId]="reasonId()"
    (continue)="continues = continues + 1"
    (end)="ends = ends + 1"
  />`,
})
class Host {
  readonly text = signal('Fix a class until it compiles, step by step');
  readonly disabled = signal(false);
  readonly reasonId = signal<string | null>('why');
  continues = 0;
  ends = 0;
}

function mount() {
  TestBed.resetTestingModule();
  const fixture = TestBed.createComponent(Host);
  fixture.detectChanges();
  const host = fixture.nativeElement as HTMLElement;
  return { fixture, host, component: fixture.componentInstance };
}

const buttons = (host: HTMLElement) => ({
  continue: host.querySelector('.ocu-workflow-chip-continue') as HTMLButtonElement,
  end: host.querySelector('.ocu-workflow-chip-end') as HTMLButtonElement,
});

describe('the workflow chip', () => {
  it('draws its label, the starting prompt and both controls, and marks itself', () => {
    const { host } = mount();
    expect(host.querySelector('[data-ocu-workflow-chip]')).not.toBeNull();
    expect(host.querySelector('.ocu-workflow-chip-label')?.textContent?.trim()).toBe(STRINGS.agentWorkflowLabel);
    expect(host.querySelector('.ocu-workflow-chip-name')?.textContent?.trim()).toBe('Fix a class until it compiles, step by step');
    const { continue: next, end } = buttons(host);
    expect(next.textContent?.trim()).toBe(STRINGS.agentWorkflowContinue);
    expect(end.textContent?.trim()).toBe(STRINGS.agentWorkflowEnd);
    expect(next.getAttribute('type')).toBe('button');
    expect(end.getAttribute('type')).toBe('button');
  });

  it('an enabled Continue asks for the next turn and carries no disabled wiring', () => {
    // Mutation (Rule 19): drop the emit from `onContinue` -> this goes red.
    const { fixture, host, component } = mount();
    const { continue: next } = buttons(host);
    expect(next.hasAttribute('aria-disabled')).toBe(false);
    expect(next.hasAttribute('aria-describedby')).toBe(false);
    next.click();
    fixture.detectChanges();
    expect(component.continues).toBe(1);
    expect(component.ends).toBe(0);
  });

  it('a disabled Continue keeps its tab stop, names its reason and emits nothing when pressed', () => {
    // Mutation (Rule 19): emit regardless of `continueDisabled` -> the press assertion goes red; drop the
    // `aria-describedby` binding -> the reason assertion goes red.
    const { fixture, host, component } = mount();
    component.disabled.set(true);
    fixture.detectChanges();
    const { continue: next } = buttons(host);
    expect(next).not.toBeNull();
    expect(next.getAttribute('aria-disabled')).toBe('true');
    expect(next.getAttribute('aria-describedby')).toBe('why');
    expect(next.hasAttribute('disabled')).toBe(false);
    expect(next.tabIndex).toBe(0);
    next.click();
    fixture.detectChanges();
    expect(component.continues).toBe(0);
  });

  it('a disabled Continue with no reason element names none, and enabling it again clears the wiring', () => {
    const { fixture, host, component } = mount();
    component.disabled.set(true);
    component.reasonId.set(null);
    fixture.detectChanges();
    const { continue: next } = buttons(host);
    expect(next.getAttribute('aria-disabled')).toBe('true');
    expect(next.hasAttribute('aria-describedby')).toBe(false);
    component.disabled.set(false);
    fixture.detectChanges();
    expect(next.hasAttribute('aria-disabled')).toBe(false);
  });

  it('End workflow asks to end the workflow, even while Continue waits', () => {
    // Mutation (Rule 19): gate End on `continueDisabled` -> this goes red.
    const { fixture, host, component } = mount();
    component.disabled.set(true);
    fixture.detectChanges();
    buttons(host).end.click();
    fixture.detectChanges();
    expect(component.ends).toBe(1);
    expect(component.continues).toBe(0);
  });
});
