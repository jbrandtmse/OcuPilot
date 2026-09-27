import { TestBed, type ComponentFixture } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { AGENT_RESTRAINT_PATH, AgentStatus, type Restraint, UNRESTRAINED } from '../core/agent-status';
import type { ApiService } from '../core/api';
import { STRINGS } from '../core/strings';
import { ReadOnlyToggle } from './read-only-toggle';

/**
 * Pins the panel's "Read-only for me" switch (Story 14.5): it is drawn only once the status read
 * has answered; it reads on while read-only is on for the caller or enforced; a press sends
 * `PUT /agent/restraint` and the switch follows the verdict the instance answers; and under
 * enforced read-only it is `aria-disabled`, and a press changes nothing and sends nothing (AC2).
 *
 * The `AgentStatus` is the real class over a stubbed transport whose restraint answer the test
 * sets, so each state is arranged the way the instance produces it.
 */

interface Harness {
  readonly fixture: ComponentFixture<ReadOnlyToggle>;
  readonly host: HTMLElement;
  readonly puts: string[];
  readonly status: AgentStatus;
}

async function settle(fixture: ComponentFixture<unknown>): Promise<void> {
  for (let pass = 0; pass < 4; pass += 1) {
    await new Promise((resolve) => setTimeout(resolve, 0));
    fixture.detectChanges();
    await fixture.whenStable();
  }
}

async function mount(verdict: Partial<Restraint>, options: { load?: boolean; refuse?: boolean } = {}): Promise<Harness> {
  const puts: string[] = [];
  let current: Restraint = { ...UNRESTRAINED, ...verdict };
  const api = {
    requestJson: async (path: string, init: { method?: string; body?: string } = {}) => {
      if (path === AGENT_RESTRAINT_PATH && init.method === 'PUT') {
        puts.push(init.body ?? '');
        if (options.refuse === true) {
          return { kind: 'error' as const, status: 500, code: 'INTERNAL', reason: 'no', detail: null };
        }
        const on = (JSON.parse(init.body ?? '{}') as { readOnly: boolean }).readOnly;
        current = { ...current, readOnlyForYou: on, footerKey: on ? 'statusReadOnlyForYou' : 'statusReadOnlyOff' };
        return { kind: 'ok' as const, status: 200, body: current };
      }
      return {
        kind: 'ok' as const,
        status: 200,
        body: path === AGENT_RESTRAINT_PATH ? current : { definitions: [{ id: '1', enabled: true }] },
      };
    },
  };
  const status = new AgentStatus({ api: api as unknown as ApiService });
  if (options.load !== false) await status.load();
  TestBed.resetTestingModule();
  TestBed.configureTestingModule({ providers: [{ provide: AgentStatus, useValue: status }] });
  const fixture = TestBed.createComponent(ReadOnlyToggle);
  fixture.componentRef.setInput('describedBy', 'ocu-panel-read-only-line');
  document.body.appendChild(fixture.nativeElement);
  await settle(fixture);
  return { fixture, host: fixture.nativeElement as HTMLElement, puts, status };
}

function switchOf(host: HTMLElement): HTMLInputElement | null {
  return host.querySelector('input.ocu-read-only-switch');
}

afterEach(() => {
  document.body.textContent = '';
});

describe('the Read-only for me switch', () => {
  it('is drawn only once the status read has answered', async () => {
    const { host } = await mount({}, { load: false });
    expect(switchOf(host)).toBeNull();
  });

  it('is a named switch described by the footer line, off while nothing restrains the caller', async () => {
    const { host } = await mount({});
    const control = switchOf(host)!;
    expect(control.getAttribute('role')).toBe('switch');
    expect(control.getAttribute('aria-label')).toBe(STRINGS.agentReadOnlyForYouLabel);
    expect(control.getAttribute('aria-describedby')).toBe('ocu-panel-read-only-line');
    expect(control.checked).toBe(false);
    expect(control.hasAttribute('aria-disabled')).toBe(false);
  });

  it('AC1: a press sends PUT {readOnly: true} and the switch follows the answered verdict', async () => {
    const { fixture, host, puts, status } = await mount({});
    const control = switchOf(host)!;
    control.click();
    await settle(fixture);
    expect(puts).toEqual(['{"readOnly":true}']);
    expect(status.restraint().footerKey).toBe('statusReadOnlyForYou');
    expect(switchOf(host)!.checked).toBe(true);

    switchOf(host)!.click();
    await settle(fixture);
    expect(puts).toEqual(['{"readOnly":true}', '{"readOnly":false}']);
    expect(switchOf(host)!.checked).toBe(false);
  });

  it('a refused write leaves the switch where the instance has it', async () => {
    const { fixture, host, puts } = await mount({}, { refuse: true });
    switchOf(host)!.click();
    await settle(fixture);
    expect(puts).toHaveLength(1);
    expect(switchOf(host)!.checked).toBe(false);
  });

  it('reads on while read-only is on for the caller', async () => {
    const { host } = await mount({ readOnlyForYou: true, blocked: true, footerKey: 'statusReadOnlyForYou' });
    expect(switchOf(host)!.checked).toBe(true);
    expect(switchOf(host)!.hasAttribute('aria-disabled')).toBe(false);
  });

  it('AC2: under enforced read-only it reads on, is aria-disabled, and a press changes nothing and sends nothing', async () => {
    // Mutation (Rule 19): drop the enforced guard in `onClick` -> the press toggles the box
    // and sends a PUT, and this goes red.
    const { fixture, host, puts } = await mount({ enforcedReadOnly: true, blocked: true, footerKey: 'statusReadOnlyEnforced' });
    const control = switchOf(host)!;
    expect(control.checked).toBe(true);
    expect(control.getAttribute('aria-disabled')).toBe('true');
    expect(control.hasAttribute('disabled')).toBe(false);
    control.click();
    await settle(fixture);
    expect(switchOf(host)!.checked).toBe(true);
    expect(puts).toEqual([]);
  });
});
