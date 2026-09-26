import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../core/overlay-stack';
import { STRINGS } from '../core/strings';
import { WarningDialog } from './warning-dialog';

/** A host that counts what the dialog emitted, which is the only thing a caller reads from it. */
@Component({
  selector: 'app-warning-host',
  imports: [WarningDialog],
  template: `<app-warning-dialog
    [verb]="verb"
    [consequence]="consequence"
    (confirmed)="confirms.set(confirms() + 1)"
    (cancelled)="cancels.set(cancels() + 1)"
  />`,
})
class Host {
  readonly verb = STRINGS.auditingTurnOffAction;
  readonly consequence = STRINGS.proposalAuditWarning;
  readonly confirms = signal(0);
  readonly cancels = signal(0);
}

describe('the warning dialog', () => {
  let fixture: ReturnType<typeof TestBed.createComponent<Host>>;
  let host: HTMLElement;
  let overlays: OverlayStack;

  beforeEach(() => {
    overlays = new OverlayStack();
    TestBed.configureTestingModule({ providers: [{ provide: OverlayStack, useValue: overlays }] });
    fixture = TestBed.createComponent(Host);
    host = fixture.nativeElement as HTMLElement;
    document.body.appendChild(host);
    fixture.detectChanges();
  });

  function proceed(): HTMLButtonElement {
    return host.querySelector('.ocu-dialog-actions .ocu-button-primary') as HTMLButtonElement;
  }

  function cancel(): HTMLButtonElement {
    return host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement;
  }

  it('is titled with the verb, states the consequence, and focuses Cancel', () => {
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.auditingTurnOffAction);
    expect(host.querySelector('.ocu-warning-consequence')?.textContent?.trim()).toBe(STRINGS.proposalAuditWarning);
    expect(cancel().textContent?.trim()).toBe(STRINGS.actionCancel);
    expect(document.activeElement).toBe(cancel());
  });

  it('proceeds through a button-primary, never a destructive one', () => {
    // Mutation (Rule 19): render Proceed as `ocu-button-destructive` -> this goes red.
    expect(proceed()).not.toBeNull();
    expect(proceed().textContent?.trim()).toBe(STRINGS.actionProceed);
    expect(host.querySelector('.ocu-button-destructive')).toBeNull();
    proceed().click();
    fixture.detectChanges();
    expect(fixture.componentInstance.confirms()).toBe(1);
    expect(fixture.componentInstance.cancels()).toBe(0);
  });

  it('emits cancelled, and nothing else, on Cancel', () => {
    cancel().click();
    fixture.detectChanges();
    expect(fixture.componentInstance.cancels()).toBe(1);
    expect(fixture.componentInstance.confirms()).toBe(0);
  });

  it('emits cancelled on Escape', () => {
    expect(overlays.closeTop()).toBe(true);
    fixture.detectChanges();
    expect(fixture.componentInstance.cancels()).toBe(1);
    expect(fixture.componentInstance.confirms()).toBe(0);
  });

  it('emits cancelled on the scrim', () => {
    (host.querySelector('.ocu-dialog-scrim') as HTMLElement).dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
    fixture.detectChanges();
    expect(fixture.componentInstance.cancels()).toBe(1);
    expect(fixture.componentInstance.confirms()).toBe(0);
  });
});
