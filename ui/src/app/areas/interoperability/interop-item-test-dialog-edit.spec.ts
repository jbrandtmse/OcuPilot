import { APP_BASE_HREF } from '@angular/common';
import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import { InteropItemTestDialog, type TestRequest } from './interop-item-test-dialog';

/** A host that binds the edit form's inputs and records what the dialog emitted. */
@Component({
  selector: 'app-interop-edit-host',
  imports: [InteropItemTestDialog],
  template: `<app-interop-item-test-dialog
    [item]="'unused'"
    [heading]="heading()"
    [submitLabel]="submitLabel()"
    [consequence]="consequence()"
    [secretCaption]="secretCaption()"
    [rows]="rows()"
    [values]="values()"
    (submitted)="submits.set([...submits(), $event])"
    (cancelled)="cancels.set(cancels() + 1)"
  />`,
})
class Host {
  readonly heading = signal('');
  readonly submitLabel = signal('');
  readonly consequence = signal('');
  readonly secretCaption = signal('');
  readonly rows = signal<readonly unknown[]>([]);
  readonly values = signal<Readonly<Record<string, string>> | null>(null);
  readonly submits = signal<TestRequest[]>([]);
  readonly cancels = signal(0);
}

const CLASS = 'ResendProbe.Body';

const row = (field: string, extra: Record<string, unknown> = {}): Record<string, unknown> => ({
  RequestClass: CLASS,
  Kind: 'object',
  Field: field,
  Type: '%Library.String',
  Required: false,
  MaxLength: null,
  Values: [],
  Secret: false,
  Value: '',
  ...extra,
});

/** The rows an edit form is drawn from: the body's fields, each with the value it holds now (Story 20.31). */
const FORM = [
  row('Text', { Required: true, MaxLength: 50, Value: 'orig' }),
  row('Kind', { Values: ['alpha', 'beta'], Value: 'alpha' }),
  row('Password', { Secret: true }),
];

/**
 * The Test dialog as the message edit form (Story 20.31): the same fields, opened on the values the message holds, titled and labeled
 * for an edit, handing on every field that is not a credential so an emptied one is a change; its defaults leave the Test dialog as it
 * was.
 */
describe('the Test dialog as the message edit form (Story 20.31)', () => {
  let fixture: ReturnType<typeof TestBed.createComponent<Host>>;
  let host: HTMLElement;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        provideRouter([{ path: '**', children: [] }]),
        { provide: APP_BASE_HREF, useValue: '/ocupilot' },
        { provide: OverlayStack, useValue: new OverlayStack() },
      ],
    });
    fixture = TestBed.createComponent(Host);
    host = fixture.nativeElement as HTMLElement;
    document.body.appendChild(host);
    fixture.componentInstance.rows.set(FORM);
  });

  afterEach(() => {
    host.remove();
    TestBed.resetTestingModule();
  });

  const text = (selector: string): string => host.querySelector(selector)?.textContent?.trim() ?? '';
  const inputOf = (name: string): HTMLInputElement & HTMLSelectElement =>
    host.querySelector(`[data-interop-test-field][data-field="${name}"] [data-interop-test-input]`) as never;
  const send = (): HTMLButtonElement => host.querySelector('[data-interop-test-send]') as HTMLButtonElement;

  function open(): void {
    fixture.componentInstance.heading.set(STRINGS.interopEditResendHeading);
    fixture.componentInstance.submitLabel.set(STRINGS.interopEditResendReview);
    fixture.componentInstance.consequence.set(STRINGS.interopMessageEditResendConsequence);
    fixture.componentInstance.secretCaption.set(STRINGS.interopRefusalEditSecret);
    fixture.componentInstance.values.set({ Text: 'orig', Kind: 'alpha' });
    fixture.detectChanges();
  }

  function type(name: string, value: string): void {
    const input = inputOf(name);
    input.value = value;
    input.dispatchEvent(new Event(input.tagName === 'SELECT' ? 'change' : 'input'));
    fixture.detectChanges();
  }

  it('is titled, labeled and worded for an edit, and opens each field on the value it holds', () => {
    // Mutation (Rule 19): ignore `values` in `typedFor` -> the prefill assertions go red; ignore `heading` or `submitLabel` -> the
    // title and button go red.
    open();
    expect(text('.ocu-dialog-title')).toBe(STRINGS.interopEditResendHeading);
    expect(text('[data-interop-test-send]')).toBe(STRINGS.interopEditResendReview);
    expect(text('[data-interop-test-consequence]')).toBe(STRINGS.interopMessageEditResendConsequence);
    expect(inputOf('Text').value).toBe('orig');
    expect(inputOf('Kind').value).toBe('alpha');
    // A credential-named field is drawn disabled with the edit's sentence, not the test's.
    expect(inputOf('Password').disabled).toBe(true);
    expect(text('[data-field="Password"] [data-interop-test-caption]')).toBe(STRINGS.interopRefusalEditSecret);
  });

  it('hands on every field that is not a credential, an emptied one as an empty string', () => {
    // Mutation (Rule 19): send only the fields that hold text -> the emptied field is missing and this goes red.
    open();
    type('Text', '');
    send().click();
    fixture.detectChanges();
    expect(fixture.componentInstance.submits()).toEqual([{ requestClass: CLASS, fields: { Text: '', Kind: 'alpha' } }]);

    type('Text', 'new text');
    type('Kind', 'beta');
    send().click();
    expect(fixture.componentInstance.submits()[1]).toEqual({ requestClass: CLASS, fields: { Text: 'new text', Kind: 'beta' } });
  });

  it('is the Test dialog when it is given none of the new inputs', () => {
    // Mutation (Rule 19): default `consequence` to '' -> the test sentence goes missing and this goes red.
    fixture.componentInstance.rows.set(FORM);
    fixture.componentInstance.heading.set('');
    fixture.componentInstance.submitLabel.set('');
    fixture.componentInstance.consequence.set('');
    fixture.componentInstance.secretCaption.set('');
    fixture.componentInstance.values.set(null);
    fixture.detectChanges();
    expect(text('.ocu-dialog-title')).toBe(STRINGS.interopTestDialogTitle.split('<item>').join('unused'));
    expect(text('[data-interop-test-send]')).toBe(STRINGS.interopItemTestAction);
    expect(text('[data-interop-test-consequence]')).toBe(STRINGS.interopTestSendsConsequence);
    expect(text('[data-field="Password"] [data-interop-test-caption]')).toBe(STRINGS.interopTestRefusalSecret);
    expect(inputOf('Text').value).toBe('');
    send().click();
    // A test sends only fields that hold text, so nothing is handed on.
    expect(fixture.componentInstance.submits()).toEqual([{ requestClass: CLASS, fields: {} }]);
  });
});
