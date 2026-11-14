import { Component, signal } from '@angular/core';
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { InteropItemChangeClassDialog } from './interop-item-change-class-dialog';

/**
 * The Change class dialog (Story 20.41): its published words, the classes the Classes tab lists less the item's own as the
 * select's options, a Review that stays unavailable until one is chosen and then emits it, the empty sentence where the tab lists
 * no other class, the server's refusal of the read drawn as the dialog's alert, and each dismissal path (Cancel, the scrim, Escape
 * through the overlay stack) emitting `cancelled` once and `chosen` never.
 */

@Component({
  imports: [InteropItemChangeClassDialog],
  template: `<app-interop-item-change-class-dialog
    [production]="production()"
    [item]="item()"
    (chosen)="chosen.push($event)"
    (cancelled)="cancelled = cancelled + 1"
  />`,
})
class Host {
  readonly production = signal('Probe.Production');
  readonly item = signal('ProbeOp');
  readonly chosen: string[] = [];
  cancelled = 0;
}

const ROWS = [
  { ClassName: 'Probe.Op', Type: 'operation', Current: true },
  { ClassName: 'Probe.TearOp', Type: 'operation', Current: false },
  { ClassName: 'Probe.RetryOp', Type: 'operation', Current: false },
];

const planted: HTMLElement[] = [];

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 3; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 2));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(answer: JsonResult<unknown>) {
  TestBed.resetTestingModule();
  const sent: string[] = [];
  const overlays = new OverlayStack();
  const api = {
    requestJson: async <T,>(path: string, _init: ApiRequestInit = {}): Promise<JsonResult<T>> => {
      sent.push(path);
      return answer as JsonResult<T>;
    },
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: OverlayStack, useValue: overlays },
    ],
  });
  const fixture = TestBed.createComponent(Host);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, sent, overlays };
}

const select = (host: HTMLElement): HTMLSelectElement | null => host.querySelector('select[data-interop-item-class-select]');

const review = (host: HTMLElement): HTMLButtonElement => host.querySelector('[data-interop-item-class-review]') as HTMLButtonElement;

function choose(fixture: ComponentFixture<unknown>, host: HTMLElement, value: string): void {
  const element = select(host) as HTMLSelectElement;
  element.value = value;
  element.dispatchEvent(new Event('change'));
  fixture.detectChanges();
}

describe('the Change class dialog', () => {
  afterEach(() => {
    for (const element of planted.splice(0)) element.remove();
    TestBed.resetTestingModule();
  });

  it('is titled and labeled with the published words, states the consequence, and lists the Classes tab\u2019s rows but the item\u2019s own', async () => {
    // Mutation (Rule 19): read the Production items list in place of the Classes tab -> the option list is the items and this goes red; keep the `Current` row -> Probe.Op is offered.
    const { host, sent } = await mount({ kind: 'ok', status: 200, body: { rows: ROWS } });
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.interopItemChangeClassAction);
    expect(host.querySelector('[data-interop-item-class-consequence]')?.textContent?.trim()).toBe(STRINGS.interopItemChangeClassConsequence);
    const element = select(host) as HTMLSelectElement;
    expect(host.querySelector(`label[for="${element.id}"]`)?.textContent?.trim()).toBe(STRINGS.interopItemColumnClass);
    expect([...element.querySelectorAll('option')].map((option) => option.value)).toEqual(['', 'Probe.TearOp', 'Probe.RetryOp']);
    expect(sent).toEqual(['/api/ocupilot/screens/interop.itemclasses/read?maxRows=1000&item=Probe.Production%7C%7CProbeOp']);
    expect(review(host).textContent?.trim()).toBe(STRINGS.interopEditResendReview);
  });

  it('keeps Review unavailable until a class is chosen, then emits the choice once', async () => {
    const { fixture, host } = await mount({ kind: 'ok', status: 200, body: { rows: ROWS } });
    expect(review(host).getAttribute('aria-disabled')).toBe('true');
    review(host).click();
    await settle(fixture);
    expect((fixture.componentInstance as Host).chosen).toEqual([]);
    choose(fixture, host, 'Probe.TearOp');
    expect(review(host).getAttribute('aria-disabled')).toBeNull();
    review(host).click();
    await settle(fixture);
    expect((fixture.componentInstance as Host).chosen).toEqual(['Probe.TearOp']);
  });

  it('says so, and offers no select, where the tab lists no other class', async () => {
    const { host } = await mount({ kind: 'ok', status: 200, body: { rows: [ROWS[0]] } });
    expect(host.querySelector('[data-interop-item-class-empty]')?.textContent?.trim()).toBe(STRINGS.interopItemClassesEmpty);
    expect(select(host)).toBeNull();
    expect(review(host).getAttribute('aria-disabled')).toBe('true');
  });

  it('draws the server\u2019s refusal of the read as the dialog\u2019s alert and emits nothing', async () => {
    const { host, fixture } = await mount({ kind: 'error', status: 409, code: 'INTEROP.ITEM.AMBIGUOUS', reason: STRINGS.interopItemRefusalAmbiguous, detail: null });
    const alert = host.querySelector('[data-interop-item-class-reason]') as HTMLElement;
    expect(alert.getAttribute('role')).toBe('alert');
    expect(alert.textContent?.trim()).toBe(STRINGS.interopItemRefusalAmbiguous);
    expect(host.querySelector('[data-interop-item-class-empty]'), 'a refused read is not an empty list').toBeNull();
    expect((fixture.componentInstance as Host).chosen).toEqual([]);
  });

  // Mutation (Rule 19): drop `(closed)="cancelled.emit()"` from the template -> the three dismissal legs go red.
  describe('dismissal', () => {
    const cancel = (host: HTMLElement): HTMLButtonElement =>
      [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;

    it('emits cancelled once for Cancel, even with a class chosen, and never chosen', async () => {
      const { fixture, host } = await mount({ kind: 'ok', status: 200, body: { rows: ROWS } });
      choose(fixture, host, 'Probe.TearOp');
      cancel(host).click();
      await settle(fixture);
      expect((fixture.componentInstance as Host).cancelled).toBe(1);
      expect((fixture.componentInstance as Host).chosen).toEqual([]);
    });

    it('emits cancelled once for a press on the scrim', async () => {
      const { fixture, host } = await mount({ kind: 'ok', status: 200, body: { rows: ROWS } });
      (host.querySelector('.ocu-dialog-scrim') as HTMLElement).dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
      await settle(fixture);
      expect((fixture.componentInstance as Host).cancelled).toBe(1);
      expect((fixture.componentInstance as Host).chosen).toEqual([]);
    });

    it('emits cancelled once for Escape, which reaches the dialog through the overlay stack', async () => {
      const { fixture, overlays } = await mount({ kind: 'ok', status: 200, body: { rows: ROWS } });
      expect(overlays.closeTop()).toBe(true);
      await settle(fixture);
      expect((fixture.componentInstance as Host).cancelled).toBe(1);
      expect((fixture.componentInstance as Host).chosen).toEqual([]);
    });
  });
});
