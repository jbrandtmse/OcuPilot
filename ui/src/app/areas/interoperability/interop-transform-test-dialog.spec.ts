import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import type { TransformAnswer } from '../../core/test-answer';
import { InteropTransformTestDialog } from './interop-transform-test-dialog';

/** A host that sets the dialog's state and records what it emitted, which is all a caller reads. */
@Component({
  selector: 'app-interop-transform-test-host',
  imports: [InteropTransformTestDialog],
  template: `<app-interop-transform-test-dialog
    [name]="name()"
    [sending]="sending()"
    [refusal]="refusal()"
    [violation]="violation()"
    [answer]="answer()"
    (submitted)="submits.set([...submits(), $event])"
    (cancelled)="cancels.set(cancels() + 1)"
  />`,
})
class Host {
  readonly name = signal('OcuProbeDtl.Xml.cls');
  readonly sending = signal(false);
  readonly refusal = signal('');
  readonly violation = signal('');
  readonly answer = signal<TransformAnswer | null>(null);
  readonly submits = signal<string[]>([]);
  readonly cancels = signal(0);
}

const answerOf = (extra: Partial<TransformAnswer> = {}): TransformAnswer => ({
  status: 'done',
  sourceClass: 'Ens.StringRequest',
  targetClass: 'Ens.StringResponse',
  lines: ['<StringResponse>', '  <StringValue>out:x</StringValue>', '</StringResponse>'],
  console: [],
  errors: false,
  ...extra,
});

/**
 * Test a data transformation (Story 20.27): the dialog is titled with the transformation, states that its code runs here as the person, takes one
 * multi-line Input with the sentence that names the formats, and sends the message exactly as typed -- empty included, since the instance judges
 * it. The result shows the source and target class, the status sentence in the error style when the run did not end done, and the target's or the
 * error's lines and the console, each as text and never as markup.
 */
describe('the Test transformation dialog (Story 20.27)', () => {
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

  const input = (): HTMLTextAreaElement => host.querySelector('[data-interop-transform-input]') as HTMLTextAreaElement;
  const run = (): HTMLButtonElement => host.querySelector('[data-interop-transform-run]') as HTMLButtonElement;
  const text = (selector: string): string => host.querySelector(selector)?.textContent?.trim() ?? '';

  function type(value: string): void {
    input().value = value;
    input().dispatchEvent(new Event('input'));
    fixture.detectChanges();
  }

  it('titles the dialog with the transformation, states the runs sentence and the formats sentence, and draws one multi-line Input', () => {
    expect(text('.ocu-dialog-title')).toBe('Test OcuProbeDtl.Xml.cls');
    expect(text('[data-interop-transform-consequence]')).toBe(STRINGS.interopTransformRunsConsequence);
    expect(input().tagName).toBe('TEXTAREA');
    expect(host.querySelector('label')?.textContent?.trim()).toBe(STRINGS.interopTransformInputLabel);
    expect(host.querySelector('label')?.getAttribute('for')).toBe(input().id);
    expect(host.querySelector('label')?.classList.contains('ocu-field-label-required')).toBe(true);
    expect(text('[data-interop-transform-hint]')).toBe(STRINGS.interopTransformInputHint);
    expect(input().getAttribute('aria-describedby')).toBe(host.querySelector('[data-interop-transform-hint]')?.id);
    expect(run().textContent?.trim()).toBe(STRINGS.actionRun);
    expect(host.querySelector('[data-interop-transform-result]')).toBeNull();
  });

  // Mutation (Rule 19): trim or refuse an empty message in `submit` -> the empty leg goes red.
  it('sends the message exactly as typed -- blanks, line breaks and an empty one included -- and not while a run is in flight', () => {
    run().click();
    expect(fixture.componentInstance.submits()).toEqual(['']);
    type('  <StringRequest>\n</StringRequest>  ');
    run().click();
    expect(fixture.componentInstance.submits()[1]).toBe('  <StringRequest>\n</StringRequest>  ');
    fixture.componentInstance.sending.set(true);
    fixture.detectChanges();
    expect(run().getAttribute('aria-disabled')).toBe('true');
    run().click();
    expect(fixture.componentInstance.submits()).toHaveLength(2);
    fixture.componentInstance.sending.set(false);
    fixture.detectChanges();
    expect(run().getAttribute('aria-disabled')).toBeNull();
  });

  it('draws the instance\'s sentence for the message under the Input, and any other refusal above it as an alert', () => {
    fixture.componentInstance.violation.set(STRINGS.interopTransformRefusalContent);
    fixture.detectChanges();
    expect(text('[data-interop-transform-violation]')).toBe(STRINGS.interopTransformRefusalContent);
    expect(input().getAttribute('aria-invalid')).toBe('true');
    expect(input().getAttribute('aria-describedby')).toContain('-reason');
    expect(host.querySelector('[data-interop-transform-reason]')).toBeNull();
    fixture.componentInstance.violation.set('');
    fixture.componentInstance.refusal.set(STRINGS.interopTransformRefusalSourceFormat);
    fixture.detectChanges();
    expect(text('[data-interop-transform-reason]')).toBe(STRINGS.interopTransformRefusalSourceFormat);
    expect(host.querySelector('[data-interop-transform-reason]')?.getAttribute('role')).toBe('alert');
    expect(host.querySelector('[data-interop-transform-violation]')).toBeNull();
    expect(input().getAttribute('aria-invalid')).toBeNull();
  });

  it('shows a run that ended done: both classes, the done sentence, and the target\'s lines as one text block', () => {
    fixture.componentInstance.answer.set(answerOf());
    fixture.detectChanges();
    expect(text('[data-interop-transform-source]')).toBe(`${STRINGS.interopTransformSourceClass}Ens.StringRequest`);
    expect(text('[data-interop-transform-target]')).toBe(`${STRINGS.interopTransformTargetClass}Ens.StringResponse`);
    expect(text('[data-interop-transform-status]')).toBe(STRINGS.interopTransformDone);
    expect(host.querySelector('[data-interop-transform-status]')?.classList.contains('ocu-form-error')).toBe(false);
    const pre = host.querySelector('[data-interop-transform-lines] pre') as HTMLElement;
    expect(pre.textContent).toBe('<StringResponse>\n  <StringValue>out:x</StringValue>\n</StringResponse>');
    expect(host.querySelector('[data-interop-transform-console-label]')).toBeNull();
    expect(host.querySelector('[data-interop-transform-console]')).toBeNull();
  });

  // Mutation (Rule 19): draw the lines or the console through `innerHTML` -> a `b` element is made and the markup legs go red.
  it('draws every line and console line as the text it is, with no element made of its markup', () => {
    fixture.componentInstance.answer.set(
      answerOf({ lines: ['<StringValue>out:<b>x</b></StringValue>'], console: ['<i>device</i> <script>alert(1)</script>'] })
    );
    fixture.detectChanges();
    const lines = host.querySelector('[data-interop-transform-lines] pre') as HTMLElement;
    const device = host.querySelector('[data-interop-transform-console] pre') as HTMLElement;
    expect(lines.textContent).toBe('<StringValue>out:<b>x</b></StringValue>');
    expect(device.textContent).toBe('<i>device</i> <script>alert(1)</script>');
    expect(host.querySelector('[data-interop-transform-result] b, [data-interop-transform-result] i, [data-interop-transform-result] script')).toBeNull();
    expect(lines.children).toHaveLength(0);
    expect(device.children).toHaveLength(0);
  });

  it('labels the console and draws what the transformation wrote beneath the lines', () => {
    fixture.componentInstance.answer.set(answerOf({ console: ['probe-device-line'] }));
    fixture.detectChanges();
    expect(text('[data-interop-transform-console-label]')).toBe(STRINGS.interopTransformConsole);
    expect(host.querySelector('[data-interop-transform-console] pre')?.textContent).toBe('probe-device-line');
  });

  it('shows a failure in the error style with the status sentence of each status, and the error text as lines', () => {
    for (const [status, sentence] of [
      ['input', STRINGS.interopTransformInputFailed],
      ['transform', STRINGS.interopTransformFailed],
      ['output', STRINGS.interopTransformOutputFailed],
    ] as const) {
      fixture.componentInstance.answer.set(answerOf({ status, errors: true, lines: [`why ${status}`] }));
      fixture.detectChanges();
      expect(text('[data-interop-transform-status]'), status).toBe(sentence);
      expect(host.querySelector('[data-interop-transform-status]')?.classList.contains('ocu-form-error'), status).toBe(true);
      expect(host.querySelector('[data-interop-transform-lines] pre')?.textContent, status).toBe(`why ${status}`);
    }
  });

  it('draws no lines block for an answer with no line, and replaces the result with the next answer', () => {
    fixture.componentInstance.answer.set(answerOf({ status: 'output', errors: true, lines: [], targetClass: '' }));
    fixture.detectChanges();
    expect(host.querySelector('[data-interop-transform-lines]')).toBeNull();
    expect(text('[data-interop-transform-target]')).toBe(STRINGS.interopTransformTargetClass);
    fixture.componentInstance.answer.set(answerOf());
    fixture.detectChanges();
    expect(host.querySelectorAll('[data-interop-transform-result]')).toHaveLength(1);
    expect(host.querySelector('[data-interop-transform-lines]')).not.toBeNull();
    fixture.componentInstance.answer.set(null);
    fixture.detectChanges();
    expect(host.querySelector('[data-interop-transform-result]')).toBeNull();
  });

  it('emits cancelled once, from the dismissing button', () => {
    const cancel = [...host.querySelectorAll('.ocu-dialog-actions button')].find((button) => button.textContent?.trim() === STRINGS.actionCancel) as HTMLButtonElement;
    cancel.click();
    fixture.detectChanges();
    expect(fixture.componentInstance.cancels()).toBe(1);
  });
});
