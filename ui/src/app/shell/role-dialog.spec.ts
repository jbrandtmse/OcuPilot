import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../core/overlay-stack';
import { STRINGS } from '../core/strings';
import { RoleDialog } from './role-dialog';

@Component({
  selector: 'app-role-host',
  imports: [RoleDialog],
  template: `<app-role-dialog
    [verb]="verb"
    [target]="target"
    [options]="options"
    [privileged]="privileged"
    [impact]="impact()"
    (chose)="chosen.set([...chosen(), $event])"
    (submitted)="roles.set([...roles(), $event])"
    (cancelled)="cancels.set(cancels() + 1)"
  />`,
})
class Host {
  readonly verb = STRINGS.userActionAddRole;
  readonly target = 'probe';
  readonly options: readonly string[] = ['%Developer', '%Operator'];
  readonly privileged: readonly string[] = ['%Operator'];
  readonly roles = signal<string[]>([]);
  readonly cancels = signal(0);
  readonly impact = signal('');
  readonly chosen = signal<string[]>([]);
}

describe('the role dialog (Story 7.2, AD-56)', () => {
  let fixture: ReturnType<typeof TestBed.createComponent<Host>>;
  let host: HTMLElement;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [{ provide: OverlayStack, useValue: new OverlayStack() }] });
    fixture = TestBed.createComponent(Host);
    host = fixture.nativeElement as HTMLElement;
    document.body.appendChild(host);
    fixture.detectChanges();
  });

  afterEach(() => {
    host.remove();
    TestBed.resetTestingModule();
  });

  function select(): HTMLSelectElement {
    return host.querySelector('select') as HTMLSelectElement;
  }

  function action(): HTMLButtonElement {
    return host.querySelector('.ocu-button-primary') as HTMLButtonElement;
  }

  it('offers the given roles in a select labelled Role, with nothing pre-chosen', () => {
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(`${STRINGS.userActionAddRole} probe`);
    expect(host.querySelector('label[for="' + select().id + '"]')?.textContent?.trim()).toBe(STRINGS.userRoleField);
    expect([...select().options].map((option) => option.value)).toEqual(['', '%Developer', '%Operator']);
    expect(select().value).toBe('');
    expect(action().getAttribute('aria-disabled')).toBe('true');
    action().click();
    expect(fixture.componentInstance.roles()).toEqual([]);
  });

  it('emits the one role chosen', () => {
    select().value = '%Operator';
    select().dispatchEvent(new Event('change'));
    fixture.detectChanges();
    expect(action().getAttribute('aria-disabled')).toBeNull();
    action().click();
    expect(fixture.componentInstance.roles()).toEqual(['%Operator']);
  });

  it('emits cancelled on dismissal', () => {
    (host.querySelector('.ocu-button-secondary') as HTMLButtonElement).click();
    expect(fixture.componentInstance.cancels()).toBe(1);
  });

  // DW-1523: choosing a role the server marks privileged states the grant's consequence under the
  // select, read with it; an ordinary role states nothing.
  // Mutation (Rule 19): drop the `aria-describedby` binding from the select -> the wiring assertion
  // goes red; drop the caption's `@if` -> the ordinary-role assertion goes red.
  it('states the privilege-grant consequence while a privileged role is chosen, and only then', () => {
    const choose = (value: string) => {
      select().value = value;
      select().dispatchEvent(new Event('change'));
      fixture.detectChanges();
    };
    choose('%Operator');
    const caption = host.querySelector('.ocu-field-caption');
    expect(caption?.textContent?.trim()).toBe(STRINGS.privilegedGrantEffect);
    expect(select().getAttribute('aria-describedby')).toBe(caption?.id);
    choose('%Developer');
    expect(host.querySelector('.ocu-field-caption')).toBeNull();
    expect(select().getAttribute('aria-describedby')).toBeNull();
  });

  // Story 16.19 (AD-8): the caller's impact line for the chosen role is a caption under the select,
  // read with it beside the privilege caption, and every choice is reported so the caller can read it.
  // Mutation (Rule 19): drop the impact caption from the template -> the caption assertion goes red.
  it('reports each choice and states the impact line for it under the select', () => {
    select().value = '%Developer';
    select().dispatchEvent(new Event('change'));
    fixture.detectChanges();
    expect(fixture.componentInstance.chosen()).toEqual(['%Developer']);
    expect(host.querySelector('[data-slot="impact"]')).toBeNull();

    fixture.componentInstance.impact.set('Impact: probe loses %DB_USER:RW.');
    fixture.detectChanges();
    const caption = host.querySelector('[data-slot="impact"]') as HTMLElement;
    expect(caption?.textContent?.trim()).toBe('Impact: probe loses %DB_USER:RW.');
    expect(caption.classList.contains('ocu-field-caption')).toBe(true);
    expect(select().getAttribute('aria-describedby')).toBe(caption.id);

    select().value = '%Operator';
    select().dispatchEvent(new Event('change'));
    fixture.detectChanges();
    const described = (select().getAttribute('aria-describedby') ?? '').split(' ');
    expect(described).toHaveLength(2);
    expect(described).toContain(caption.id);
  });
});
