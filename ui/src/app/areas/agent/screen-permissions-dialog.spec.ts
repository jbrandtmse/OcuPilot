import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { ScreenPermissionsDialog } from './screen-permissions-dialog';

/** A host that sets the dialog's state and records what it emitted, which is all a caller reads. */
@Component({
  selector: 'app-screen-permissions-host',
  imports: [ScreenPermissionsDialog],
  template: `<app-screen-permissions-dialog
    [screen]="screen()"
    [pairs]="pairs()"
    [classic]="classic()"
    [adjustable]="adjustable()"
    [sending]="sending()"
    [refusal]="refusal()"
    (added)="adds.set([...adds(), $event])"
    (removed)="removes.set([...removes(), $event])"
    (cancelled)="cancels.set(cancels() + 1)"
  />`,
})
class Host {
  readonly screen = signal('osmgmt.locks');
  readonly pairs = signal<readonly string[]>(['%Admin_Operate:USE', '%DB_IRISSYS:READ']);
  readonly classic = signal('');
  readonly adjustable = signal(true);
  readonly sending = signal(false);
  readonly refusal = signal('');
  readonly adds = signal<string[]>([]);
  readonly removes = signal<string[]>([]);
  readonly cancels = signal(0);
}

/**
 * Change permissions (Story 20.15): its title names the screen, it lists the set with a Remove on each pair,
 * states a lowering's consequence, lists the classic resource as fixed, hands on one pair per Add or Remove,
 * keeps Add unavailable until a resource is typed, shows the instance's refusal, and offers neither control
 * for a screen whose permissions are fixed.
 */
describe('the Change permissions dialog (Story 20.15)', () => {
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

  const title = (): string => host.querySelector('.ocu-dialog-title')?.textContent?.trim() ?? '';
  const pairs = (): string[] => Array.from(host.querySelectorAll('.ocu-screen-permissions-pair[data-pair] .ocu-screen-permissions-text')).map((node) => node.textContent?.trim() ?? '');
  const removes = (): HTMLButtonElement[] => Array.from(host.querySelectorAll<HTMLButtonElement>('.ocu-screen-permissions-remove'));
  const addButton = (): HTMLButtonElement | null => host.querySelector('.ocu-screen-permissions-add-button');
  const resource = (): HTMLInputElement | null => host.querySelector('[data-field="resource"]');
  const permission = (): HTMLSelectElement | null => host.querySelector('[data-field="permission"]');

  function set(update: (state: Host) => void): void {
    update(fixture.componentInstance);
    fixture.detectChanges();
  }

  function type(value: string): void {
    const input = resource() as HTMLInputElement;
    input.value = value;
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();
  }

  it('names the screen and lists the set, each pair with a Remove named for it', () => {
    expect(title()).toBe('Change the permissions of osmgmt.locks');
    expect(pairs()).toEqual(['%Admin_Operate:USE', '%DB_IRISSYS:READ']);
    expect(removes().map((button) => button.getAttribute('aria-label'))).toEqual(['Remove %Admin_Operate:USE', 'Remove %DB_IRISSYS:READ']);
    expect(host.querySelector('.ocu-screen-permissions-consequence')?.textContent?.trim()).toBe(STRINGS.screenPermissionsLowerConsequence);
  });

  // Mutation (Rule 19): drop the `removed` emit from `remove` -> this goes red.
  it('hands on the pair a Remove names, and nothing while a send is in flight', () => {
    removes()[1].click();
    expect(fixture.componentInstance.removes()).toEqual(['%DB_IRISSYS:READ']);
    set((state) => state.sending.set(true));
    removes()[0].click();
    expect(fixture.componentInstance.removes()).toEqual(['%DB_IRISSYS:READ']);
    expect(removes()[0].getAttribute('aria-disabled')).toBe('true');
  });

  // Mutation (Rule 19): make `addDisabled` always null -> the first leg goes red.
  it('keeps Add unavailable until a resource is typed, then hands on resource:PERMISSION', () => {
    expect(addButton()?.getAttribute('aria-disabled')).toBe('true');
    (addButton() as HTMLButtonElement).click();
    expect(fixture.componentInstance.adds()).toEqual([]);
    type('%Admin_Secure');
    expect(addButton()?.getAttribute('aria-disabled')).toBeNull();
    const select = permission() as HTMLSelectElement;
    select.value = 'READ';
    select.dispatchEvent(new Event('change'));
    (addButton() as HTMLButtonElement).click();
    expect(fixture.componentInstance.adds()).toEqual(['%Admin_Secure:READ']);
  });

  it('offers Read, Write and Use, the permissions a pair may carry, with Use first chosen', () => {
    const options = Array.from(host.querySelectorAll<HTMLOptionElement>('[data-field="permission"] option')).map((option) => [option.value, option.textContent?.trim()]);
    expect(options).toEqual([
      ['READ', STRINGS.permissionRead],
      ['WRITE', STRINGS.permissionWrite],
      ['USE', STRINGS.permissionUse],
    ]);
    expect((permission() as HTMLSelectElement).value).toBe('USE');
  });

  it("lists the classic page's resource as fixed, with no Remove of its own", () => {
    set((state) => state.classic.set('OcuPilotProbeClassic:USE'));
    const classic = host.querySelector('.ocu-screen-permissions-classic');
    expect(classic?.textContent?.trim()).toBe('The classic portal also requires OcuPilotProbeClassic:USE here, and only the classic portal changes it.');
    expect(classic?.querySelector('button')).toBeNull();
    expect(removes().length).toBe(2);
  });

  it('shows the instance refusal beside the Add row as an alert', () => {
    set((state) => state.refusal.set('This instance defines no resource of that name.'));
    const alert = host.querySelector('[role="alert"]');
    expect(alert?.textContent?.trim()).toBe('This instance defines no resource of that name.');
  });

  // Mutation (Rule 19): make `canAdjust` always true -> this goes red.
  it('shows a screen whose permissions are fixed with neither Remove nor Add', () => {
    set((state) => state.adjustable.set(false));
    expect(host.querySelector('.ocu-screen-permissions-fixed')?.textContent?.trim()).toBe(STRINGS.screenPermissionsFixed);
    expect(removes().length).toBe(0);
    expect(addButton()).toBeNull();
    expect(host.querySelector('.ocu-screen-permissions-consequence')).toBeNull();
    expect(pairs()).toEqual(['%Admin_Operate:USE', '%DB_IRISSYS:READ']);
  });

  it('reports one dismissal however it was closed', () => {
    (host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(fixture.componentInstance.cancels()).toBe(1);
  });
});
