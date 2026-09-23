import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../core/overlay-stack';
import { STRINGS } from '../core/strings';
import { TypedNameDialog } from './typed-name-dialog';

/** What the dialog asks about in every test here: a delete, and a target with a slash in it. */
const VERB = STRINGS.actionDelete;

const TARGET = '/csp/myapp';

const CONSEQUENCE = STRINGS.webAppDeleteConsequence;

/** A host that counts what the dialog emitted, which is the only thing a caller reads from it. */
@Component({
  selector: 'app-typed-name-host',
  imports: [TypedNameDialog],
  template: `<app-typed-name-dialog
    [verb]="verb"
    [target]="target"
    [consequence]="consequence"
    (confirmed)="confirms.set(confirms() + 1)"
    (cancelled)="cancels.set(cancels() + 1)"
  />`,
})
class Host {
  readonly verb = VERB;
  readonly target = TARGET;
  readonly consequence = CONSEQUENCE;
  readonly confirms = signal(0);
  readonly cancels = signal(0);
}

describe('the typed-name dialog', () => {
  let fixture: ReturnType<typeof TestBed.createComponent<Host>>;
  let host: HTMLElement;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [{ provide: OverlayStack, useValue: new OverlayStack() }] });
    fixture = TestBed.createComponent(Host);
    host = fixture.nativeElement as HTMLElement;
    document.body.appendChild(host);
    fixture.detectChanges();
  });

  function field(): HTMLInputElement {
    return host.querySelector('.ocu-typed-name-field') as HTMLInputElement;
  }

  function action(): HTMLButtonElement {
    return host.querySelector('.ocu-button-destructive') as HTMLButtonElement;
  }

  function type(value: string): void {
    field().value = value;
    field().dispatchEvent(new Event('input'));
    fixture.detectChanges();
  }

  function blur(): void {
    field().dispatchEvent(new Event('blur'));
    fixture.detectChanges();
  }

  it('names the action and the target, states the consequence and focuses the field', () => {
    // Mutation (Rule 19): drop the target from `heading` -> the title assertion goes red.
    expect(host.querySelector('.ocu-dialog-title')?.textContent?.trim()).toBe(`${VERB} ${TARGET}`);
    expect(host.querySelector('.ocu-typed-name-consequence')?.textContent?.trim()).toBe(CONSEQUENCE);
    expect(host.querySelector('.ocu-typed-name-label')?.textContent?.trim()).toBe(
      STRINGS.formTypedNameConfirm.split('<name>').join(TARGET)
    );
    // `dialog.ts` puts initial focus on the first field, which is this one.
    expect(document.activeElement).toBe(field());
    expect(action().textContent?.trim()).toBe(`${VERB} ${TARGET}`);
  });

  it('keeps the destructive button aria-disabled, never disabled, until the name matches exactly', () => {
    // Mutation (Rule 19): compare the two through `toLowerCase()` -> the case leg goes green
    // where it must be red, and this test says so.
    expect(action().getAttribute('aria-disabled')).toBe('true');
    expect(action().hasAttribute('disabled')).toBe(false);

    action().click();
    fixture.detectChanges();
    expect(fixture.componentInstance.confirms()).toBe(0);

    type('/CSP/MYAPP');
    expect(action().getAttribute('aria-disabled')).toBe('true');
    type(` ${TARGET}`);
    expect(action().getAttribute('aria-disabled')).toBe('true');

    type(TARGET);
    expect(action().getAttribute('aria-disabled')).toBeNull();
    expect(host.querySelectorAll('[disabled]')).toHaveLength(0);
    action().click();
    fixture.detectChanges();
    expect(fixture.componentInstance.confirms()).toBe(1);
  });

  it('shows "Does not match" on blur with aria-invalid, and clears it when the name matches', () => {
    // Mutation (Rule 19): show the message on every input rather than on blur -> the first
    // assertion goes red.
    type('/csp/my');
    expect(host.querySelector('.ocu-typed-name-mismatch')).toBeNull();
    expect(field().getAttribute('aria-invalid')).toBeNull();

    blur();
    const message = host.querySelector('.ocu-typed-name-mismatch') as HTMLElement | null;
    expect(message?.textContent?.trim()).toBe(STRINGS.formTypedNameMismatch);
    expect(field().getAttribute('aria-invalid')).toBe('true');
    expect(field().getAttribute('aria-describedby')).toBe(message?.id);

    type(TARGET);
    expect(host.querySelector('.ocu-typed-name-mismatch')).toBeNull();
    expect(field().getAttribute('aria-invalid')).toBeNull();
  });

  it('Enter submits only once the name matches, and Cancel emits without effect', () => {
    // Mutation (Rule 19): drop the match test from `onConfirm` -> the first Enter confirms and
    // this goes red.
    type('not the name');
    field().dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    fixture.detectChanges();
    expect(fixture.componentInstance.confirms()).toBe(0);
    // A refused Enter is the same signal a refused click is: the mismatch is now shown.
    expect(host.querySelector('.ocu-typed-name-mismatch')).not.toBeNull();

    type(TARGET);
    field().dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true }));
    fixture.detectChanges();
    expect(fixture.componentInstance.confirms()).toBe(1);

    (host.querySelector('.ocu-button-secondary') as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(fixture.componentInstance.cancels()).toBe(1);
    expect(fixture.componentInstance.confirms()).toBe(1);
  });
});

describe('the typed-name dialog\u2019s advisory (Story 7.6)', () => {
  it('draws a passed advisory as a warning after the consequence, and nothing when none is passed', () => {
    // Mutation (Rule 19): drop the advisory block from the template -> the first half goes red.
    TestBed.configureTestingModule({ providers: [{ provide: OverlayStack, useValue: new OverlayStack() }] });
    const fixture = TestBed.createComponent(TypedNameDialog);
    fixture.componentRef.setInput('verb', VERB);
    fixture.componentRef.setInput('target', 'Switch Journal');
    fixture.componentRef.setInput('consequence', STRINGS.taskDeleteConsequence);
    fixture.componentRef.setInput('advisory', STRINGS.taskSystemDeleteConsequence);
    fixture.detectChanges();
    const element = fixture.nativeElement as HTMLElement;
    const advisory = element.querySelector('[data-slot="advisory"]') as HTMLElement | null;
    expect(advisory).not.toBeNull();
    expect(advisory?.textContent).toContain(STRINGS.taskSystemDeleteConsequence);
    expect(advisory?.classList.contains('ocu-banner-warning')).toBe(true);

    fixture.componentRef.setInput('advisory', '');
    fixture.detectChanges();
    expect(element.querySelector('[data-slot="advisory"]')).toBeNull();
    TestBed.resetTestingModule();
  });
});
