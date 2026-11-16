import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { InteropProductionStartupDialog, type StartupKind, type StartupValues } from './interop-production-startup-dialog';

/** A host that sets the dialog's state and records what it emitted, which is all a caller reads. */
@Component({
  selector: 'app-interop-startup-host',
  imports: [InteropProductionStartupDialog],
  template: `<app-interop-production-startup-dialog
    [kind]="kind()"
    [production]="production()"
    [autoStart]="autoStart()"
    [priority]="priority()"
    [group]="group()"
    [sending]="sending()"
    [refusal]="refusal()"
    [violation]="violation()"
    (submitted)="submits.set([...submits(), $event])"
    (cancelled)="cancels.set(cancels() + 1)"
  />`,
})
class Host {
  readonly kind = signal<StartupKind>('autostart');
  readonly production = signal('Demo.Production');
  readonly autoStart = signal(false);
  readonly priority = signal('');
  readonly group = signal('3');
  readonly sending = signal(false);
  readonly refusal = signal('');
  readonly violation = signal('');
  readonly submits = signal<StartupValues[]>([]);
  readonly cancels = signal(0);
}

/**
 * Start with the instance and Shutdown group (Story 24.3): the title names the production; auto-start draws a checkbox and a
 * priority that opens at the production's own, else 0, and is sent only while the box is checked; the group opens at the production's own;
 * a refusal is drawn under the field or above the fields; nothing is sent while a send is in flight.
 */
describe('the Productions startup dialog (Story 24.3)', () => {
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

  const field = (): HTMLInputElement | null => host.querySelector('[data-interop-startup-value]');
  const checkbox = (): HTMLInputElement | null => host.querySelector('[data-interop-startup-checkbox]');
  const confirm = (): HTMLButtonElement => host.querySelector('[data-interop-startup-confirm]') as HTMLButtonElement;
  const text = (selector: string): string => host.querySelector(selector)?.textContent?.trim() ?? '';

  function set(update: (state: Host) => void): void {
    update(fixture.componentInstance);
    fixture.detectChanges();
  }

  function type(value: string): void {
    const control = field() as HTMLInputElement;
    control.value = value;
    control.dispatchEvent(new Event('input'));
    fixture.detectChanges();
  }

  function tick(checked: boolean): void {
    const box = checkbox() as HTMLInputElement;
    box.checked = checked;
    box.dispatchEvent(new Event('change'));
    fixture.detectChanges();
  }

  it('titles the auto-start dialog with the production, states how the instance starts productions, and draws one unchecked box with no priority field', () => {
    expect(text('.ocu-dialog-title')).toBe(STRINGS.interopProductionAutoStartTitle.replace('<production>', 'Demo.Production'));
    expect(text('[data-interop-startup-help]')).toBe(STRINGS.interopProductionAutoStartHelp);
    expect(checkbox()?.checked).toBe(false);
    expect(host.querySelector('.ocu-field-checkbox')?.textContent?.trim()).toBe(STRINGS.interopProductionAutoStartField);
    expect(field()).toBeNull();
  });

  it('opens the priority at 0 for a production that has none, sends the box and the priority while checked, and the box alone when it is cleared', () => {
    tick(true);
    expect(field()?.value).toBe('0');
    confirm().click();
    expect(fixture.componentInstance.submits()).toEqual([{ AutoStart: '1', StartupPriority: '0' }]);
    type('12 ');
    confirm().click();
    expect(fixture.componentInstance.submits()[1]).toEqual({ AutoStart: '1', StartupPriority: '12' });
    tick(false);
    expect(field()).toBeNull();
    confirm().click();
    expect(fixture.componentInstance.submits()[2]).toEqual({ AutoStart: '0' });
  });

  it('opens a production that starts with the instance checked, at its own priority, and sends no priority when the field is emptied', () => {
    set((state) => {
      state.autoStart.set(true);
      state.priority.set('5');
    });
    expect(checkbox()?.checked).toBe(true);
    expect(field()?.value).toBe('5');
    type('');
    confirm().click();
    expect(fixture.componentInstance.submits()).toEqual([{ AutoStart: '1' }]);
  });

  it('titles the shutdown group dialog with the production, states how the instance stops productions, and sends the group it opened at or the one typed', () => {
    set((state) => state.kind.set('shutdowngroup'));
    expect(text('.ocu-dialog-title')).toBe(STRINGS.interopProductionShutdownGroupTitle.replace('<production>', 'Demo.Production'));
    expect(text('[data-interop-startup-help]')).toBe(STRINGS.interopProductionShutdownGroupHelp);
    expect(checkbox()).toBeNull();
    expect(field()?.value).toBe('3');
    confirm().click();
    type('-4');
    confirm().click();
    expect(fixture.componentInstance.submits()).toEqual([{ ShutdownGroup: '3' }, { ShutdownGroup: '-4' }]);
  });

  it('sends nothing while a send is in flight, and a Cancel is emitted once', () => {
    set((state) => state.kind.set('shutdowngroup'));
    set((state) => state.sending.set(true));
    confirm().click();
    expect(fixture.componentInstance.submits()).toEqual([]);
    expect(confirm().getAttribute('aria-disabled')).toBe('true');
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    cancel.click();
    expect(fixture.componentInstance.cancels()).toBe(1);
  });

  it('draws the instance\'s sentence for the value under it, described by it, and any other refusal above the fields as an alert', () => {
    set((state) => {
      state.kind.set('shutdowngroup');
      state.violation.set(STRINGS.interopStartupRefusalGroup);
    });
    expect(text('[data-interop-startup-violation]')).toBe(STRINGS.interopStartupRefusalGroup);
    expect(field()?.getAttribute('aria-invalid')).toBe('true');
    expect(field()?.getAttribute('aria-describedby')).toBe(host.querySelector('[data-interop-startup-violation]')?.id);
    set((state) => {
      state.violation.set('');
      state.refusal.set(STRINGS.interopStartupRefusalReadOnly);
    });
    expect(text('[data-interop-startup-reason]')).toBe(STRINGS.interopStartupRefusalReadOnly);
    expect(host.querySelector('[data-interop-startup-reason]')?.getAttribute('role')).toBe('alert');
    expect(host.querySelector('[data-interop-startup-violation]')).toBeNull();
    expect(field()?.getAttribute('aria-invalid')).toBeNull();
  });
});
