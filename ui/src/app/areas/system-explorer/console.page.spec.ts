import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { afterEach, describe, expect, it } from 'vitest';

import { ApiService, type ApiRequestInit, type JsonResult } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { NavigationService } from '../../core/navigation';
import { OverlayStack } from '../../core/overlay-stack';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores } from '../../core/screen-store';
import { SCREENS, type ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { stubAccountPreferences } from '../../testing/account-preferences';
import { ConsolePage } from './console.page';

/**
 * The Command console and the Class method console over the shipped descriptors, with the real `ScreenStores` and
 * `ScreenActionHandler` and a stubbed HTTP answer (Story 24.6): Run opens the warning dialog that names the console's
 * consequence and sends nothing, Cancel sends nothing either, Confirm sends the run once with the form's values, a refusal shows
 * the instance's sentence, and an answer shows its output and a note for each part that was cut.
 */

const COMMAND = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ExplorerCommand') as ScreenDeclaration;
const CLASSMETHOD = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.ExplorerClassMethod') as ScreenDeclaration;

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 6; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 20));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

const planted: HTMLElement[] = [];

interface ActionRequest {
  readonly path: string;
  readonly body: Record<string, unknown>;
}

async function mount(screen: ScreenDeclaration, action?: JsonResult<unknown>) {
  TestBed.resetTestingModule();
  const requests: ActionRequest[] = [];
  const api = {
    requestJson: async <T,>(path: string, init?: ApiRequestInit): Promise<JsonResult<T>> => {
      requests.push({ path, body: JSON.parse(String(init?.body ?? '{}')) as Record<string, unknown> });
      return action as JsonResult<T>;
    },
  };
  const stores = new ScreenStores({ account: stubAccountPreferences() });
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: NavigationService, useValue: { screenForUrl: () => screen } as unknown as NavigationService },
      { provide: ApiService, useValue: api as unknown as ApiService },
      { provide: ScreenStores, useValue: stores },
      { provide: ScreenActions, useValue: new ScreenActions() },
      { provide: OverlayStack, useValue: new OverlayStack() },
      { provide: ChangeBus, useValue: new ChangeBus() },
      {
        provide: ScopeService,
        useValue: { loaded: () => true, namespace: () => 'USER', namespaces: () => [{ name: 'USER' }], subscribe: () => () => undefined } as unknown as ScopeService,
      },
    ],
  });
  await TestBed.inject(Router).navigateByUrl(`/${screen.route}?ns=USER`);
  const fixture = TestBed.createComponent(ConsolePage);
  document.body.appendChild(fixture.nativeElement);
  planted.push(fixture.nativeElement);
  fixture.detectChanges();
  await settle(fixture);
  return { host: fixture.nativeElement as HTMLElement, requests, settle: () => settle(fixture) };
}

type Context = Awaited<ReturnType<typeof mount>>;

function applied(output: unknown): JsonResult<unknown> {
  return { kind: 'ok', status: 200, body: { action: 'updated', target: { type: 'class', scope: 'USER', id: 'command' }, readBack: null, output } };
}

function type(host: HTMLElement, selector: string, value: string): void {
  const field = host.querySelector(selector) as HTMLInputElement | HTMLTextAreaElement;
  field.value = value;
  field.dispatchEvent(new Event('input'));
}

async function pressRun(ctx: Context): Promise<void> {
  (ctx.host.querySelector('[data-ocu-console="run"]') as HTMLButtonElement).click();
  await ctx.settle();
}

function dialogButton(ctx: Context, label: string): HTMLButtonElement | undefined {
  return (Array.from(ctx.host.querySelectorAll('app-warning-dialog button')) as HTMLButtonElement[]).find((button) => button.textContent?.trim() === label);
}

afterEach(() => {
  for (const node of planted.splice(0)) node.remove();
});

describe('System Explorer Command console', () => {
  it('draws a textarea limited to 30,000 characters and the Run command button, and no dialog', async () => {
    const ctx = await mount(COMMAND);
    expect(ctx.host.querySelector('label[for="ocu-console-command"]')?.textContent?.trim()).toBe(STRINGS.explorerCommandFieldLabel);
    expect(ctx.host.querySelector('[data-ocu-console="command"]')?.getAttribute('maxlength')).toBe('30000');
    expect(ctx.host.querySelector('[data-ocu-console="run"]')?.textContent?.trim()).toBe(STRINGS.explorerCommandRunAction);
    expect(ctx.host.querySelector('app-warning-dialog')).toBeNull();
  });

  it('opens the warning dialog on Run with its consequence named, and sends nothing: Cancel sends nothing either', async () => {
    // Mutation (Rule 19): send the action from `onAsk` without the dialog -> the request assertions go red.
    const ctx = await mount(COMMAND, applied({ output: 'ok', truncated: false, error: '' }));
    type(ctx.host, '[data-ocu-console="command"]', 'Write "ok"');
    await pressRun(ctx);
    expect(ctx.host.querySelector('app-warning-dialog .ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.explorerCommandRunTitle);
    expect(ctx.host.querySelector('app-warning-dialog .ocu-warning-consequence')?.textContent?.trim()).toBe(STRINGS.explorerCommandRunConsequence);
    expect(ctx.requests).toEqual([]);
    dialogButton(ctx, STRINGS.actionCancel)?.click();
    await ctx.settle();
    expect(ctx.host.querySelector('app-warning-dialog')).toBeNull();
    expect(ctx.requests).toEqual([]);
  });

  it('names no command, opens no dialog', async () => {
    const ctx = await mount(COMMAND);
    type(ctx.host, '[data-ocu-console="command"]', '   ');
    await pressRun(ctx);
    expect(ctx.host.querySelector('app-warning-dialog')).toBeNull();
    expect(ctx.requests).toEqual([]);
  });

  it('sends the run once Proceed is pressed, with the command as typed, and shows its output', async () => {
    const ctx = await mount(COMMAND, applied({ output: 'ok', truncated: false, error: '' }));
    type(ctx.host, '[data-ocu-console="command"]', 'Write "ok"');
    await pressRun(ctx);
    dialogButton(ctx, STRINGS.actionProceed)?.click();
    await ctx.settle();
    expect(ctx.requests).toEqual([{ path: '/api/ocupilot/screens/explorer.command/action', body: { action: 'run', id: 'command', values: { command: 'Write "ok"' } } }]);
    expect(ctx.host.querySelector('[data-ocu-console="output"]')?.textContent?.trim()).toBe('ok');
    expect(ctx.host.querySelector('[data-ocu-console="note"]')).toBeNull();
    expect(ctx.host.querySelector('[data-ocu-console="refusal"]')).toBeNull();
  });

  it("shows the instance's reason when the run is switched off, and keeps the command", async () => {
    // Mutation (Rule 19): draw the generic sentence alone in `proceed` -> the reason assertion goes red.
    const off: JsonResult<unknown> = { kind: 'error', status: 403, code: 'EXPLORER.COMMAND.OFF', reason: STRINGS.explorerCommandOffReason, detail: null };
    const ctx = await mount(COMMAND, off);
    type(ctx.host, '[data-ocu-console="command"]', 'Write 1');
    await pressRun(ctx);
    dialogButton(ctx, STRINGS.actionProceed)?.click();
    await ctx.settle();
    expect(ctx.host.querySelector('[data-ocu-console="refusal"]')?.textContent?.trim()).toBe(STRINGS.explorerCommandOffReason);
    expect((ctx.host.querySelector('[data-ocu-console="command"]') as HTMLTextAreaElement).value).toBe('Write 1');
    expect(ctx.requests).toHaveLength(1);
  });

  it('shows the cut note under a cut output, the error the command raised, and the sentence for a run that wrote nothing', async () => {
    const cut = await mount(COMMAND, applied({ output: 'xxx', truncated: true, error: '<DIVIDE>Run+1' }));
    type(cut.host, '[data-ocu-console="command"]', 'Write 1');
    await pressRun(cut);
    dialogButton(cut, STRINGS.actionProceed)?.click();
    await cut.settle();
    expect(Array.from(cut.host.querySelectorAll('[data-ocu-console="note"]')).map((node) => node.textContent?.trim())).toEqual([STRINGS.explorerConsoleOutputCut]);
    expect(cut.host.querySelector('[data-ocu-console="error"]')?.textContent?.trim()).toBe('<DIVIDE>Run+1');
    const empty = await mount(COMMAND, applied({ output: '', truncated: false, error: '' }));
    type(empty.host, '[data-ocu-console="command"]', 'Set x = 1');
    await pressRun(empty);
    dialogButton(empty, STRINGS.actionProceed)?.click();
    await empty.settle();
    expect(empty.host.querySelector('[data-ocu-console="no-output"]')?.textContent?.trim()).toBe(STRINGS.explorerConsoleNoOutput);
    expect(empty.host.querySelector('[data-ocu-console="output"]')).toBeNull();
  });
});

describe('System Explorer Class method console', () => {
  it('draws Class, Method and Arguments with the hint, and the Call method button', async () => {
    const ctx = await mount(CLASSMETHOD);
    expect(ctx.host.querySelector('label[for="ocu-console-class"]')?.textContent?.trim()).toBe(STRINGS.explorerClassDocumentLabel);
    expect(ctx.host.querySelector('label[for="ocu-console-method"]')?.textContent?.trim()).toBe(STRINGS.explorerSqlColumnMethod);
    expect(ctx.host.querySelector('label[for="ocu-console-args"]')?.textContent?.trim()).toBe(STRINGS.agentLedgerArguments);
    expect(ctx.host.querySelector('[data-ocu-console="hint"]')?.textContent?.trim()).toBe(
      'A list in square brackets, such as ["a", 1]. Write {"byRef": true, "value": "x"} to pass a value by reference.'
    );
    expect(ctx.host.querySelector('[data-ocu-console="run"]')?.textContent?.trim()).toBe(STRINGS.explorerClassMethodRunAction);
  });

  it("opens the warning dialog on Call method with this console's consequence, and sends nothing until Proceed", async () => {
    const ctx = await mount(CLASSMETHOD, applied({ returnValue: '2', argCount: 1, byRefValues: {}, output: 'hi', truncated: false, byRefTruncated: false, returnValueTruncated: false, error: '' }));
    type(ctx.host, '[data-ocu-console="class"]', 'Demo.Echo');
    type(ctx.host, '[data-ocu-console="method"]', 'Echo');
    type(ctx.host, '[data-ocu-console="args"]', '["hi"]');
    await pressRun(ctx);
    expect(ctx.host.querySelector('app-warning-dialog .ocu-dialog-title')?.textContent?.trim()).toBe(STRINGS.explorerClassMethodRunTitle);
    expect(ctx.host.querySelector('app-warning-dialog .ocu-warning-consequence')?.textContent?.trim()).toBe(STRINGS.explorerClassMethodRunConsequence);
    expect(ctx.requests).toEqual([]);
    dialogButton(ctx, STRINGS.actionProceed)?.click();
    await ctx.settle();
    expect(ctx.requests).toEqual([
      { path: '/api/ocupilot/screens/explorer.classmethod/action', body: { action: 'run', id: 'classmethod', values: { class: 'Demo.Echo', method: 'Echo', args: '["hi"]' } } },
    ]);
    expect(ctx.host.querySelector('[data-ocu-console="return-value"]')?.textContent?.trim()).toBe('2');
    expect(ctx.host.querySelector('[data-ocu-console="output"]')?.textContent?.trim()).toBe('hi');
  });

  it('shows a note for each part that was cut, and the by-reference values as text', async () => {
    const ctx = await mount(
      CLASSMETHOD,
      applied({ returnValue: 'x', argCount: 2, byRefValues: { '1': 'hi!' }, output: 'o', truncated: true, byRefTruncated: true, returnValueTruncated: true, error: '' })
    );
    type(ctx.host, '[data-ocu-console="class"]', 'Demo.Echo');
    type(ctx.host, '[data-ocu-console="method"]', 'Echo');
    await pressRun(ctx);
    dialogButton(ctx, STRINGS.actionProceed)?.click();
    await ctx.settle();
    expect(Array.from(ctx.host.querySelectorAll('[data-ocu-console="note"]')).map((node) => node.textContent?.trim())).toEqual([
      STRINGS.explorerConsoleReturnCut,
      STRINGS.explorerConsoleByRefCut,
      STRINGS.explorerConsoleOutputCut,
    ]);
    expect(ctx.host.querySelector('[data-ocu-console="by-ref"]')?.textContent).toContain('"1": "hi!"');
  });

  it('sends no argument list as none, and names no class, opens no dialog', async () => {
    const ctx = await mount(CLASSMETHOD, applied({ returnValue: '', argCount: 0, byRefValues: {}, output: '', truncated: false, byRefTruncated: false, returnValueTruncated: false, error: '' }));
    await pressRun(ctx);
    expect(ctx.host.querySelector('app-warning-dialog')).toBeNull();
    type(ctx.host, '[data-ocu-console="class"]', 'Demo.Echo');
    type(ctx.host, '[data-ocu-console="method"]', 'Big');
    type(ctx.host, '[data-ocu-console="args"]', '  ');
    await pressRun(ctx);
    dialogButton(ctx, STRINGS.actionProceed)?.click();
    await ctx.settle();
    expect((ctx.requests[0].body['values'] as Record<string, string>)['args']).toBe('[]');
  });
});
