import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import type { SourceControlQuestion } from '../../core/source-control-question';
import { STRINGS } from '../../core/strings';
import { ScreenActionHandler, type ActionRefusal } from '../../shell/screen-action-handler';
import { SourceControlQuestionDialog } from './source-control-question-dialog';

/**
 * The source-control question dialog (Story 21.38, AD-39's ninth exception) over a stubbed `ScreenActionHandler`: each question in the order the
 * class asked it, each answer sent for its document with its step to the list's own screen and the namespace it was asked in, an alert and an
 * unsupported step that send nothing, and the class's text shown as inert plain text.
 */

const DESCRIPTOR = 'OcuPilot.Screen.Descriptor.ExplorerClassList';

interface Send {
  readonly descriptor: string;
  readonly action: string;
  readonly target: string;
  readonly values: Readonly<Record<string, string>> | undefined;
  readonly scope: string | undefined;
}

const planted: HTMLElement[] = [];

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

function question(overrides: Partial<SourceControlQuestion> = {}): SourceControlQuestion {
  return { document: 'Probe.Alpha.cls', step: 1, kind: 'question', text: 'Add Probe.Alpha.cls to source control?', ...overrides };
}

async function settle(fixture: { detectChanges(): void; whenStable(): Promise<unknown> }): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 0));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(questions: readonly SourceControlQuestion[], refusal: ActionRefusal | null = null, scope = 'HSCUSTOM') {
  TestBed.resetTestingModule();
  const sends: Send[] = [];
  const state = { refusal };
  const handler = {
    sendFor: async (descriptor: string, action: string, target: string, values?: Readonly<Record<string, string>>, _sink?: unknown, sentScope?: string) => {
      sends.push({ descriptor, action, target, values, scope: sentScope });
      return state.refusal === null;
    },
    lastRefusal: () => state.refusal,
  };
  TestBed.configureTestingModule({
    providers: [
      { provide: ScreenActionHandler, useValue: handler as unknown as ScreenActionHandler },
      { provide: OverlayStack, useValue: new OverlayStack() },
    ],
  });
  const fixture = TestBed.createComponent(SourceControlQuestionDialog);
  fixture.componentRef.setInput('questions', questions);
  fixture.componentRef.setInput('descriptor', DESCRIPTOR);
  fixture.componentRef.setInput('scope', scope);
  let finished = 0;
  fixture.componentInstance.finished.subscribe(() => {
    finished += 1;
  });
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  const host = fixture.nativeElement as HTMLElement;
  return {
    fixture,
    host,
    sends,
    state,
    finished: () => finished,
    title: () => host.querySelector('.ocu-dialog-title')?.textContent?.trim(),
    text: () => host.querySelector('[data-ocu-source-control="text"]'),
    button: (name: string) => host.querySelector(`[data-ocu-source-control="${name}"]`) as HTMLButtonElement | null,
    cancel: () => host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement,
    press: async (button: HTMLElement | null) => {
      button?.click();
      await settle(fixture);
    },
  };
}

describe('the source-control question dialog', () => {
  it('AC5: a question shows its title, lead and the class\'s text with Yes, No and Cancel, and Yes sends the answer for the document and step to the list screen', async () => {
    // Mutation (Rule 19): send the Yes answer as 0 in `onAnswer`'s caller (the template's ANSWER_YES) -> the sent values go red.
    const view = await mount([question()]);
    expect(view.title()).toBe('Source control asks about Probe.Alpha.cls');
    expect(view.host.querySelector('[data-ocu-source-control="lead"]')?.textContent?.trim()).toBe(STRINGS.explorerSourceControlQuestionLead);
    expect(view.text()?.textContent).toBe('Add Probe.Alpha.cls to source control?');
    expect(view.button('yes')?.textContent?.trim()).toBe('Yes');
    expect(view.button('no')?.textContent?.trim()).toBe('No');
    expect(view.cancel().textContent?.trim()).toBe(STRINGS.actionCancel);
    await view.press(view.button('yes'));
    expect(view.sends).toEqual([
      { descriptor: DESCRIPTOR, action: 'answer', target: 'Probe.Alpha.cls', values: { step: '1', answer: '1' }, scope: 'HSCUSTOM' },
    ]);
    expect(view.finished()).toBe(1);
  });

  it('AC5: No sends 0 and Cancel, Escape or the scrim send 2, once', async () => {
    // Mutation (Rule 19): make Cancel close without sending in `onClosed` -> the Cancel leg goes red.
    const no = await mount([question({ step: 2 })]);
    await no.press(no.button('no'));
    expect(no.sends.map((send) => send.values)).toEqual([{ step: '2', answer: '0' }]);
    const cancel = await mount([question({ step: 7 })]);
    await cancel.press(cancel.cancel());
    expect(cancel.sends.map((send) => send.values)).toEqual([{ step: '7', answer: '2' }]);
    expect(cancel.finished()).toBe(1);
    const escape = await mount([question({ step: 1 })]);
    expect(TestBed.inject(OverlayStack).closeTop()).toBe(true);
    await settle(escape.fixture);
    expect(escape.sends.map((send) => send.values)).toEqual([{ step: '1', answer: '2' }]);
    expect(escape.finished()).toBe(1);
    const scrim = await mount([question({ step: 2 })]);
    scrim.host.querySelector('.ocu-dialog-scrim')?.dispatchEvent(new MouseEvent('mousedown', { bubbles: true }));
    await settle(scrim.fixture);
    expect(scrim.sends.map((send) => send.values)).toEqual([{ step: '2', answer: '2' }]);
    expect(scrim.finished()).toBe(1);
  });

  it('shows two questions in the order the class asked them, the second only once the first is answered', async () => {
    const view = await mount([question({ step: 1, text: 'first' }), question({ step: 7, kind: 'alert', text: 'second' })]);
    expect(view.text()?.textContent).toBe('first');
    await view.press(view.button('yes'));
    expect(view.finished()).toBe(0);
    expect(view.text()?.textContent).toBe('second');
    expect(view.host.querySelector('[data-ocu-source-control="lead"]')?.textContent?.trim()).toBe(STRINGS.explorerSourceControlAlertLead);
    await view.press(view.cancel());
    expect(view.sends).toHaveLength(1);
    expect(view.finished()).toBe(1);
  });

  it('AC6: an alert shows its lead and text with Close, and Close sends nothing', async () => {
    // Mutation (Rule 19): send the Cancel answer when an alert closes in `onClosed` -> red.
    const view = await mount([question({ kind: 'alert', step: 7, text: 'The file was added.' })]);
    expect(view.host.querySelector('[data-ocu-source-control="lead"]')?.textContent?.trim()).toBe(STRINGS.explorerSourceControlAlertLead);
    expect(view.text()?.textContent).toBe('The file was added.');
    expect(view.button('yes')).toBeNull();
    expect(view.button('no')).toBeNull();
    expect(view.cancel().textContent?.trim()).toBe(STRINGS.auditDialogClose);
    await view.press(view.cancel());
    expect(view.sends).toEqual([]);
    expect(view.finished()).toBe(1);
  });

  it('AC6: a step OcuPilot cannot show reads the unsupported line for its document and sends nothing', async () => {
    const view = await mount([question({ kind: 'unsupported', text: '', document: 'Probe.Beta.mac' })]);
    expect(view.host.querySelector('[data-ocu-source-control="unsupported"]')?.textContent?.trim()).toBe(
      STRINGS.explorerSourceControlUnsupported.replace('<document>', 'Probe.Beta.mac')
    );
    expect(view.host.querySelector('[data-ocu-source-control="lead"]')).toBeNull();
    expect(view.cancel().textContent?.trim()).toBe(STRINGS.auditDialogClose);
    await view.press(view.cancel());
    expect(view.sends).toEqual([]);
    expect(view.finished()).toBe(1);
  });

  it('a refused answer shows the instance\'s sentence and keeps the question, and a second Cancel closes it without sending', async () => {
    // Mutation (Rule 19): advance past a refused answer in `onAnswer` -> the stay-open leg goes red.
    const refusal: ActionRefusal = { reason: STRINGS.explorerSourceControlAnswerRefused, code: 'EXPLORER.SOURCECONTROL.ANSWER', violations: [], detail: null };
    const view = await mount([question()], refusal);
    await view.press(view.button('yes'));
    expect(view.host.querySelector('[data-ocu-source-control="refusal"]')?.textContent?.trim()).toBe(STRINGS.explorerSourceControlAnswerRefused);
    expect(view.host.querySelector('[data-ocu-source-control="refusal"]')?.getAttribute('role')).toBe('alert');
    expect(view.text()?.textContent).toBe('Add Probe.Alpha.cls to source control?');
    expect(view.finished()).toBe(0);
    await view.press(view.cancel());
    expect(view.sends).toHaveLength(1);
    expect(view.finished()).toBe(1);
  });

  it('a refused Cancel answer can still be closed, and a retry after a refusal sends again', async () => {
    const refusal: ActionRefusal = { reason: '', code: '', violations: [], detail: null };
    const view = await mount([question()], refusal);
    await view.press(view.cancel());
    expect(view.host.querySelector('[data-ocu-source-control="refusal"]')?.textContent?.trim()).toBe(STRINGS.explorerSourceControlAnswerRefused);
    view.state.refusal = null;
    await view.press(view.button('yes'));
    expect(view.sends.map((send) => send.values)).toEqual([
      { step: '1', answer: '2' },
      { step: '1', answer: '1' },
    ]);
    expect(view.finished()).toBe(1);
  });

  it('AC9: a question carrying markup and a line break renders as inert plain text', async () => {
    // Mutation (Rule 19): bind the text through `innerHTML` in the template -> the element legs go red.
    const hostile = 'Add <img src="x" onerror="alert(1)"> and <b>bold</b>?\nSecond line <script>alert(2)</script>';
    const view = await mount([question({ text: hostile })]);
    const shown = view.text() as HTMLElement;
    expect(shown.textContent).toBe(hostile);
    expect(shown.children).toHaveLength(0);
    expect(view.host.querySelector('img, b, script')).toBeNull();
    const alert = await mount([question({ kind: 'alert', text: hostile })]);
    expect(alert.text()?.textContent).toBe(hostile);
    expect(alert.host.querySelector('img, b, script')).toBeNull();
  });
});
