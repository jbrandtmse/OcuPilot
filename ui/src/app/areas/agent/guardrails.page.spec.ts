import { ComponentFixture, TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';

import type { ApiService } from '../../core/api';
import { Guardrails } from '../../core/guardrails';
import { screenForDescriptor } from '../../core/navigation';
import { STRINGS, stringFor } from '../../core/strings';
import { guardrailsBody, stubGuardrails, type StubbedGuardrails } from '../../testing/guardrails';
import { GuardrailsPage } from './guardrails.page';

/**
 * The Guardrails screen over a stubbed `GET /ui/guardrails` and the real store: the five sections in
 * page order, the refused rows exactly as answered, the Confirm groups under their screens' labels,
 * the three kill-switch lines, and the fault line in place of every section when the read fails.
 */

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 5));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(store: StubbedGuardrails): Promise<{ fixture: ComponentFixture<GuardrailsPage>; root: HTMLElement }> {
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({ providers: [{ provide: Guardrails, useValue: store }] });
  const fixture = TestBed.createComponent(GuardrailsPage);
  fixture.detectChanges();
  await settle(fixture);
  return { fixture, root: fixture.nativeElement as HTMLElement };
}

const texts = (root: HTMLElement, selector: string): string[] =>
  [...root.querySelectorAll(selector)].map((element) => (element.textContent ?? '').replace(/\s+/g, ' ').trim());

describe('GuardrailsPage', () => {
  it('reads its answer on open and lists the five sections in page order', async () => {
    const store = stubGuardrails();
    const { root } = await mount(store);
    expect(store.calls.map((call) => call.path)).toEqual(['/api/ocupilot/ui/guardrails']);
    expect(texts(root, '.ocu-guardrails-intro')).toEqual([STRINGS.agentGuardrailsIntro]);
    expect(texts(root, 'h2')).toEqual([
      STRINGS.agentGuardrailsRefusedHeading,
      STRINGS.agentSwitchesLabel,
      STRINGS.agentGuardrailsConfirmHeading,
      STRINGS.agentGuardrailsNeverHeading,
      STRINGS.transcriptScreenContext,
    ]);
    expect(root.querySelector('.ocu-guardrails-fault')).toBeNull();
    expect(root.querySelector('.ocu-guardrails')?.getAttribute('aria-busy')).toBe('false');
  });

  it('is busy while its read is pending, and not once it lands', async () => {
    // Mutation (Rule 19): `busy` answers false whatever the store's `loading()` reads -> this goes red.
    let release: (value: unknown) => void = () => undefined;
    const pending = new Promise((resolve) => {
      release = resolve;
    });
    const store = new Guardrails({ api: { requestJson: () => pending } as unknown as ApiService });
    TestBed.resetTestingModule();
    TestBed.configureTestingModule({ providers: [{ provide: Guardrails, useValue: store }] });
    const fixture = TestBed.createComponent(GuardrailsPage);
    fixture.detectChanges();
    const root = fixture.nativeElement as HTMLElement;
    expect(root.querySelector('.ocu-guardrails')?.getAttribute('aria-busy')).toBe('true');
    expect(root.querySelector('.ocu-guardrails-fault')).toBeNull();
    expect(root.querySelectorAll('h2').length).toBe(0);
    release({ kind: 'ok', status: 200, body: guardrailsBody() });
    await settle(fixture);
    expect(root.querySelector('.ocu-guardrails')?.getAttribute('aria-busy')).toBe('false');
    expect(root.querySelectorAll('h2').length).toBe(5);
  });

  it('renders each refused row as the answer gives it, in its order, and holds no sentence of its own', async () => {
    // Mutation (Rule 19): render a constant list in place of `prohibited` -> this goes red.
    const body = guardrailsBody();
    body['prohibited'] = [
      { code: 'PROBE.B', reason: 'Answered second-first.' },
      { code: 'PROBE.A', reason: 'Answered <b>as text</b>.' },
    ];
    const { root } = await mount(stubGuardrails({ body }));
    expect(texts(root, '.ocu-guardrails-refused .ocu-guardrails-reason')).toEqual(['Answered second-first.', 'Answered <b>as text</b>.']);
    expect(texts(root, '.ocu-guardrails-refused .ocu-guardrails-code')).toEqual(['PROBE.B', 'PROBE.A']);
    expect(root.querySelector('.ocu-guardrails-refused b')).toBeNull();
  });

  it('groups the Confirm tools under their screens\' labels, with an unmirrored descriptor last and unheaded', async () => {
    const body = guardrailsBody();
    body['confirmTools'] = [
      { name: 'permissions.users.delete', descriptor: 'OcuPilot.Screen.Descriptor.UserList' },
      { name: 'probe.unknown.write', descriptor: 'OcuPilot.Screen.Descriptor.NoSuchScreen' },
      { name: 'permissions.users.password', descriptor: 'OcuPilot.Screen.Descriptor.UserList' },
    ];
    const { root } = await mount(stubGuardrails({ body }));
    const users = screenForDescriptor('OcuPilot.Screen.Descriptor.UserList');
    expect(users).not.toBeNull();
    expect(texts(root, '.ocu-guardrails-group-heading')).toEqual([stringFor(users?.labelKey ?? '')]);
    const groups = [...root.querySelectorAll('.ocu-guardrails-group')].map((group) => texts(group as HTMLElement, 'code'));
    expect(groups).toEqual([['permissions.users.delete', 'permissions.users.password'], ['probe.unknown.write']]);
    expect(texts(root, '.ocu-guardrails-secrets .ocu-guardrails-item')).toEqual(['permissions.users.password: Password']);
  });

  it('lists every secret field of a tool, in order', async () => {
    // Mutation (Rule 19): render only each tool's first field -> this goes red.
    const body = guardrailsBody();
    body['secrets'] = [
      { tool: 'permissions.users.password', fields: ['Password'] },
      { tool: 'probe.multi', fields: ['First', 'Second', 'Third'] },
    ];
    const { root } = await mount(stubGuardrails({ body }));
    expect(texts(root, '.ocu-guardrails-secrets .ocu-guardrails-item')).toEqual([
      'permissions.users.password: Password',
      'probe.multi: First, Second, Third',
    ]);
  });

  it('draws the three kill-switch lines and the read-only line from the caller\'s verdict', async () => {
    const cases: [Record<string, unknown>, string, string][] = [
      [{ killSwitch: false, killSwitchAudience: '', enforcedReadOnly: false }, STRINGS.agentGuardrailsKillSwitchOff, STRINGS.agentGuardrailsReadOnlyOff],
      [{ killSwitch: true, killSwitchAudience: 'everyone', enforcedReadOnly: false }, STRINGS.agentGuardrailsKillSwitchEveryone, STRINGS.agentGuardrailsReadOnlyOff],
      [{ killSwitch: true, killSwitchAudience: 'you', enforcedReadOnly: true }, STRINGS.agentGuardrailsKillSwitchYou, STRINGS.agentGuardrailsReadOnlyOn],
    ];
    for (const [switches, killLine, readOnly] of cases) {
      const body = guardrailsBody();
      body['switches'] = switches;
      const { root } = await mount(stubGuardrails({ body }));
      expect(texts(root, '.ocu-guardrails-kill-switch')).toEqual([killLine]);
      expect(texts(root, '.ocu-guardrails-read-only')).toEqual([readOnly]);
    }
  });

  it('prints the limits line with each number grouped', async () => {
    const body = guardrailsBody();
    body['limits'] = { contextRowCap: 150, totalMaxLength: 65536, fieldMaxLength: 1000 };
    const { root } = await mount(stubGuardrails({ body }));
    const [line] = texts(root, '.ocu-guardrails-limits');
    expect(line).toContain('150');
    expect(line).toContain('65,536');
    expect(line).toContain('1,000');
  });

  it('shows the fault line and no section when the read fails', async () => {
    const { root } = await mount(stubGuardrails({ unreachable: true }));
    expect(texts(root, '.ocu-guardrails-fault')).toEqual([STRINGS.connectivityServerFault]);
    expect(root.querySelectorAll('h2').length).toBe(0);
    expect(root.querySelector('.ocu-guardrails-refused')).toBeNull();
  });
});
