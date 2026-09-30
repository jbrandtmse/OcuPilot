import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../core/overlay-stack';
import { STRINGS } from '../core/strings';
import { WarningDialog, type WarningAnswer } from './warning-dialog';

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

/** A host drawing the three optional parts (Story 18.4), keeping every answer. */
@Component({
  selector: 'app-warning-parts-host',
  imports: [WarningDialog],
  template: `<app-warning-dialog
    [verb]="verb"
    [consequence]="consequence"
    [advisory]="advisory()"
    [flagLabel]="flagLabel()"
    [fieldLabel]="fieldLabel()"
    [fieldHint]="fieldHint()"
    (confirmed)="answers.set([...answers(), $event])"
  />`,
})
class PartsHost {
  readonly verb = STRINGS.databaseActionTruncate;
  readonly consequence = STRINGS.databaseTruncateConsequence;
  readonly advisory = signal('');
  readonly flagLabel = signal('');
  readonly fieldLabel = signal('');
  readonly fieldHint = signal('');
  readonly answers = signal<readonly WarningAnswer[]>([]);
}

describe('the warning dialog, with its optional parts (Story 18.4)', () => {
  function mount(parts: { advisory?: string; flagLabel?: string; fieldLabel?: string; fieldHint?: string }) {
    TestBed.configureTestingModule({ providers: [{ provide: OverlayStack, useValue: new OverlayStack() }] });
    const fixture = TestBed.createComponent(PartsHost);
    const component = fixture.componentInstance;
    component.advisory.set(parts.advisory ?? '');
    component.flagLabel.set(parts.flagLabel ?? '');
    component.fieldLabel.set(parts.fieldLabel ?? '');
    component.fieldHint.set(parts.fieldHint ?? '');
    const host = fixture.nativeElement as HTMLElement;
    document.body.appendChild(host);
    fixture.detectChanges();
    return { fixture, host, component };
  }

  function proceedOf(host: HTMLElement): HTMLButtonElement {
    return host.querySelector('.ocu-dialog-actions .ocu-button-primary') as HTMLButtonElement;
  }

  it('draws none of the three parts unless passed, and answers an empty object', () => {
    const { host, component, fixture } = mount({});
    expect(host.querySelector('[data-slot="advisory"]')).toBeNull();
    expect(host.querySelector('[data-slot="flag"]')).toBeNull();
    expect(host.querySelector('[data-slot="field"]')).toBeNull();
    proceedOf(host).click();
    fixture.detectChanges();
    expect(component.answers()).toEqual([{}]);
  });

  it('states an advisory as a warning banner, and Proceed is unchanged by it', () => {
    const { host, component, fixture } = mount({ advisory: STRINGS.databaseRefusalOcuPilot });
    const banner = host.querySelector('[data-slot="advisory"]');
    expect(banner?.classList.contains('ocu-banner-warning')).toBe(true);
    expect(banner?.textContent).toContain(STRINGS.databaseRefusalOcuPilot);
    expect(proceedOf(host).getAttribute('aria-disabled')).toBeNull();
    proceedOf(host).click();
    fixture.detectChanges();
    expect(component.answers().length).toBe(1);
  });

  it('answers a flag unchecked when it opens, and checked once checked', () => {
    // Mutation (Rule 19): answer `flag` true always -> the unchecked answer goes red.
    const { host, component, fixture } = mount({ flagLabel: STRINGS.databaseMountReadOnly });
    const box = host.querySelector('[data-slot="flag"] input') as HTMLInputElement;
    expect(host.querySelector('[data-slot="flag"]')?.textContent).toContain(STRINGS.databaseMountReadOnly);
    expect(box.checked).toBe(false);
    proceedOf(host).click();
    box.click();
    proceedOf(host).click();
    fixture.detectChanges();
    expect(component.answers()).toEqual([{ flag: false }, { flag: true }]);
  });

  it('keeps Proceed unavailable, naming the hint, until the field holds a whole number, and answers its value', () => {
    // Mutation (Rule 19): release Proceed for any text -> the refused clicks answer and this goes red.
    const { host, component, fixture } = mount({ fieldLabel: STRINGS.databaseTargetSizeLabel, fieldHint: STRINGS.databaseTargetSizeHint });
    const input = host.querySelector('[data-slot="field"] input') as HTMLInputElement;
    const label = host.querySelector('[data-slot="field"] label') as HTMLLabelElement;
    expect(label.textContent?.trim()).toBe(STRINGS.databaseTargetSizeLabel);
    expect(label.getAttribute('for')).toBe(input.id);
    const hint = host.querySelector('[data-slot="field"] .ocu-field-caption') as HTMLElement;
    expect(hint.textContent?.trim()).toBe(STRINGS.databaseTargetSizeHint);
    expect(document.activeElement).toBe(input);
    for (const text of ['', '1.5', '-1', 'abc']) {
      input.value = text;
      input.dispatchEvent(new Event('input'));
      fixture.detectChanges();
      expect(proceedOf(host).getAttribute('aria-disabled')).toBe('true');
      expect(proceedOf(host).getAttribute('aria-describedby')).toBe(hint.id);
      proceedOf(host).click();
    }
    expect(component.answers()).toEqual([]);
    input.value = ' 60 ';
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    expect(proceedOf(host).getAttribute('aria-disabled')).toBeNull();
    input.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter' }));
    fixture.detectChanges();
    expect(component.answers()).toEqual([{ value: '60' }]);
  });
});
