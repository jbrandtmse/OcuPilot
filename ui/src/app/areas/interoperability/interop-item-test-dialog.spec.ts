import { Component, signal, viewChild, type WritableSignal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import type { TestAnswer } from '../../core/test-answer';
import type { Violation } from '../../core/violations';
import { InteropItemTestDialog, type TestRequest, testRowsOf } from './interop-item-test-dialog';

/** A host that sets the dialog's state and records what it emitted, which is all a caller reads. */
@Component({
  selector: 'app-interop-test-host',
  imports: [InteropItemTestDialog],
  template: `<app-interop-item-test-dialog
    [item]="item()"
    [rows]="rows()"
    [sending]="sending()"
    [refusal]="refusal()"
    [violations]="violations()"
    [answer]="answer()"
    (submitted)="submits.set([...submits(), $event])"
    (cancelled)="cancels.set(cancels() + 1)"
  />`,
})
class Host {
  readonly dialog = viewChild.required(InteropItemTestDialog);
  readonly item = signal('OcuPilotProbeEchoOp');
  readonly rows = signal<readonly unknown[]>([]);
  readonly sending = signal(false);
  readonly refusal = signal('');
  readonly violations = signal<readonly Violation[]>([]);
  readonly answer = signal<TestAnswer | null>(null);
  readonly submits = signal<TestRequest[]>([]);
  readonly cancels = signal(0);
}

const row = (requestClass: string, field: string, extra: Record<string, unknown> = {}): Record<string, unknown> => ({
  Production: 'P.Prod',
  Item: 'Op',
  RequestClass: requestClass,
  Kind: 'object',
  Field: field,
  Type: '%Library.String',
  Required: false,
  MaxLength: null,
  Values: [],
  Secret: false,
  ...extra,
});

const REQUEST = 'OcuPilotProbe.Interop.TestRequest';

const ROWS = [
  row('Ens.StringRequest', 'StringValue'),
  row('EnsLib.HL7.Message', 'content', { Kind: 'document', Required: true }),
  row('Ens.Request', ''),
  row(REQUEST, 'Text', { Required: true, MaxLength: 50 }),
  row(REQUEST, 'Count', { Type: '%Library.Integer' }),
  row(REQUEST, 'Kind', { Values: ['alpha', 'beta', 'gamma'], MaxLength: 50 }),
  row(REQUEST, 'Password', { Secret: true, MaxLength: 50 }),
  row(REQUEST, 'Address.City', { MaxLength: 30 }),
];

/**
 * Send test (Story 20.6): the dialog follows the rows the tab lists. A select names the classes; the chosen class's fields are drawn
 * one each -- text bounded by its length, a select over the values a field is restricted to, one multi-line field for a document and
 * a credential disabled with its sentence; only fields that hold text are sent, never a credential's; a refusal on a field is drawn
 * under it; and the answer shows as text, never markup.
 */
describe('the Send test dialog (Story 20.6)', () => {
  let fixture: ReturnType<typeof TestBed.createComponent<Host>>;
  let host: HTMLElement;

  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [{ provide: OverlayStack, useValue: new OverlayStack() }] });
    fixture = TestBed.createComponent(Host);
    host = fixture.nativeElement as HTMLElement;
    document.body.appendChild(host);
    fixture.componentInstance.rows.set(ROWS);
    fixture.detectChanges();
  });

  afterEach(() => {
    host.remove();
    TestBed.resetTestingModule();
  });

  const classSelect = (): HTMLSelectElement => host.querySelector('[data-interop-test-class]') as HTMLSelectElement;
  const fields = (): HTMLElement[] => [...host.querySelectorAll<HTMLElement>('[data-interop-test-field]')];
  const fieldNamed = (name: string): HTMLElement => host.querySelector(`[data-interop-test-field][data-field="${name}"]`) as HTMLElement;
  const inputOf = (name: string): HTMLInputElement & HTMLSelectElement & HTMLTextAreaElement => fieldNamed(name).querySelector('[data-interop-test-input]') as never;
  const send = (): HTMLButtonElement => host.querySelector('[data-interop-test-send]') as HTMLButtonElement;
  const text = (selector: string): string => host.querySelector(selector)?.textContent?.trim() ?? '';

  function choose(requestClass: string): void {
    classSelect().value = requestClass;
    classSelect().dispatchEvent(new Event('change'));
    fixture.detectChanges();
  }

  function type(name: string, value: string): void {
    const control = inputOf(name);
    control.value = value;
    control.dispatchEvent(new Event(control.tagName === 'SELECT' ? 'change' : 'input'));
    fixture.detectChanges();
  }

  // Mutation (Rule 19): fill `STRINGS.interopTestMaxLength` alone in `fields` -> the one-character caption goes red.
  it('reads "At most 1 character." for a field bounded at one', () => {
    const oneChar = 'OcuPilotProbe.Interop.OneChar';
    fixture.componentInstance.rows.set([...ROWS, row(oneChar, 'Code', { MaxLength: 1 })]);
    fixture.detectChanges();
    choose(oneChar);
    expect(fieldNamed('Code').querySelector('[data-interop-test-caption]')?.textContent?.trim()).toBe('At most 1 character.');
  });

  it('reads the tab rows as typed rows and leaves out one with no class', () => {
    const typed = testRowsOf([...ROWS, 'text', null, row('', 'X')]);
    expect(typed).toHaveLength(ROWS.length);
    expect(typed.find((entry) => entry.field === 'Kind')?.values).toEqual(['alpha', 'beta', 'gamma']);
    expect(typed.find((entry) => entry.field === 'Text')).toMatchObject({ required: true, maxLength: 50, secret: false });
    expect(typed.find((entry) => entry.field === 'Password')?.secret).toBe(true);
  });

  it('titles the dialog with the item, states the sending sentence, and offers each class in the order the tab lists them', () => {
    expect(text('.ocu-dialog-title')).toBe('Test OcuPilotProbeEchoOp');
    expect(text('[data-interop-test-consequence]')).toBe(STRINGS.interopTestSendsConsequence);
    expect([...classSelect().options].map((option) => option.value)).toEqual(['Ens.StringRequest', 'EnsLib.HL7.Message', 'Ens.Request', REQUEST]);
    expect(classSelect().value).toBe('Ens.StringRequest');
    expect(fields().map((entry) => entry.getAttribute('data-field'))).toEqual(['StringValue']);
  });

  // Mutation (Rule 19): make `fields` ignore the chosen class -> the field-list leg goes red.
  it('draws the chosen class\'s fields: bounded text, a select over restricted values, a required mark and a credential disabled with its sentence', () => {
    choose(REQUEST);
    expect(fields().map((entry) => entry.getAttribute('data-field'))).toEqual(['Text', 'Count', 'Kind', 'Password', 'Address.City']);
    expect(inputOf('Text').getAttribute('maxlength')).toBe('50');
    expect(fieldNamed('Text').querySelector('label')?.classList.contains('ocu-field-label-required')).toBe(true);
    expect(fieldNamed('Count').querySelector('label')?.classList.contains('ocu-field-label-required')).toBe(false);
    expect(fieldNamed('Text').querySelector('[data-interop-test-caption]')?.textContent?.trim()).toBe(STRINGS.interopTestMaxLength.replace('<n>', '50'));
    expect(inputOf('Kind').tagName).toBe('SELECT');
    expect([...inputOf('Kind').options].map((option) => option.value)).toEqual(['', 'alpha', 'beta', 'gamma']);
    expect(inputOf('Password').disabled).toBe(true);
    expect(fieldNamed('Password').querySelector('[data-interop-test-caption]')?.textContent?.trim()).toBe(STRINGS.interopTestRefusalSecret);
    expect(inputOf('Address.City').getAttribute('maxlength')).toBe('30');
  });

  it('draws a document class as one multi-line field labelled message text, and a class with no field as its sentence', () => {
    choose('EnsLib.HL7.Message');
    expect(fields()).toHaveLength(1);
    expect(inputOf('content').tagName).toBe('TEXTAREA');
    expect(fieldNamed('content').querySelector('label')?.textContent?.trim()).toBe(STRINGS.interopTestDocumentLabel);
    choose('Ens.Request');
    expect(fields()).toHaveLength(0);
    expect(text('[data-interop-test-nofields]')).toBe(STRINGS.interopTestNoFields);
  });

  // Mutation (Rule 19): send every field, empty ones included -> the empty legs go red.
  it('sends the class and only the fields that hold text, and not while a send is in flight', () => {
    choose(REQUEST);
    type('Text', 'hello');
    type('Kind', 'beta');
    type('Address.City', 'Berlin');
    send().click();
    expect(fixture.componentInstance.submits()).toEqual([{ requestClass: REQUEST, fields: { Text: 'hello', Kind: 'beta', 'Address.City': 'Berlin' } }]);
    type('Kind', '');
    fixture.componentInstance.sending.set(true);
    fixture.detectChanges();
    expect(send().getAttribute('aria-disabled')).toBe('true');
    send().click();
    expect(fixture.componentInstance.submits()).toHaveLength(1);
    fixture.componentInstance.sending.set(false);
    fixture.detectChanges();
    send().click();
    expect(fixture.componentInstance.submits()[1]).toEqual({ requestClass: REQUEST, fields: { Text: 'hello', 'Address.City': 'Berlin' } });
  });

  // Mutation (Rule 19): drop the credential test from `submit` -> this goes red. The control is drawn disabled, so the value is put in the
  // dialog's state directly: the send must still leave it out.
  it('leaves a credential out of the fields even when a value for it reached the dialog\'s state', () => {
    choose(REQUEST);
    type('Text', 'hello');
    const dialog = fixture.componentInstance.dialog() as unknown as { typed: WritableSignal<Record<string, string>> };
    dialog.typed.set({ ...dialog.typed(), Password: 'hunter2' });
    send().click();
    expect(fixture.componentInstance.submits()).toEqual([{ requestClass: REQUEST, fields: { Text: 'hello' } }]);
  });

  it('forgets what was typed when another class is chosen', () => {
    choose(REQUEST);
    type('Text', 'hello');
    choose('Ens.StringRequest');
    type('StringValue', 'x');
    choose(REQUEST);
    expect(inputOf('Text').value).toBe('');
    send().click();
    expect(fixture.componentInstance.submits()[0].fields).toEqual({});
  });

  it('sends a document\'s text as its one content field', () => {
    choose('EnsLib.HL7.Message');
    type('content', 'MSH|^~\\&|A');
    send().click();
    expect(fixture.componentInstance.submits()).toEqual([{ requestClass: 'EnsLib.HL7.Message', fields: { content: 'MSH|^~\\&|A' } }]);
  });

  it('draws the instance\'s sentence for a field under it, and any other refusal above the fields as an alert', () => {
    choose(REQUEST);
    fixture.componentInstance.violations.set([{ field: 'Count', code: 'INTEROP.TEST.VALUE', reason: STRINGS.interopTestRefusalValue }]);
    fixture.detectChanges();
    expect(fieldNamed('Count').querySelector('[data-interop-test-violation]')?.textContent?.trim()).toBe(STRINGS.interopTestRefusalValue);
    expect(inputOf('Count').getAttribute('aria-invalid')).toBe('true');
    expect(inputOf('Count').getAttribute('aria-describedby')).toContain('-reason');
    expect(fieldNamed('Text').querySelector('[data-interop-test-violation]')).toBeNull();
    expect(host.querySelector('[data-interop-test-reason]')).toBeNull();
    fixture.componentInstance.violations.set([]);
    fixture.componentInstance.refusal.set(STRINGS.interopTestRefusalDisabled);
    fixture.detectChanges();
    expect(text('[data-interop-test-reason]')).toBe(STRINGS.interopTestRefusalDisabled);
    expect(host.querySelector('[data-interop-test-reason]')?.getAttribute('role')).toBe('alert');
  });

  // Mutation (Rule 19): draw the lines through `innerHTML` -> the markup leg goes red.
  it('shows the answer as text: the status sentence, then the response\'s lines with their markup left as the text it is', () => {
    expect(host.querySelector('[data-interop-test-result]')).toBeNull();
    fixture.componentInstance.answer.set({ status: 'done', sessionId: '41', responseClass: 'Ens.StringResponse', lines: ['StringValue: echo:<b>x</b>'], errors: false });
    fixture.detectChanges();
    expect(text('[data-interop-test-status]')).toBe(STRINGS.interopTestDone.replace('<session>', '41').replace('<class>', 'Ens.StringResponse'));
    const pre = host.querySelector('[data-interop-test-result] pre') as HTMLElement;
    expect(pre.textContent).toBe('StringValue: echo:<b>x</b>');
    expect(host.querySelector('[data-interop-test-result] b')).toBeNull();
    expect(host.querySelector('[data-interop-test-status]')?.classList.contains('ocu-form-error')).toBe(false);
    fixture.componentInstance.answer.set({ status: 'error', sessionId: '42', responseClass: '', lines: ['boom'], errors: true });
    fixture.detectChanges();
    expect(text('[data-interop-test-status]')).toBe(STRINGS.interopTestFailed.replace('<session>', '42'));
    expect(host.querySelector('[data-interop-test-status]')?.classList.contains('ocu-form-error')).toBe(true);
    fixture.componentInstance.answer.set({ status: 'done', sessionId: '43', responseClass: '', lines: [], errors: false });
    fixture.detectChanges();
    expect(text('[data-interop-test-status]')).toBe(STRINGS.interopTestDoneNoResponse.replace('<session>', '43'));
    expect(host.querySelector('[data-interop-test-result] pre')).toBeNull();
  });

  it('emits cancelled once, from the dismissing button', () => {
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    fixture.detectChanges();
    expect(fixture.componentInstance.cancels()).toBe(1);
  });
});
