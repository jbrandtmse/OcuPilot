import { TestBed } from '@angular/core/testing';
import { provideRouter } from '@angular/router';
import { describe, expect, it } from 'vitest';

import { AgentContext } from '../core/agent-context';
import { AgentStatus } from '../core/agent-status';
import { NavigationService, UNGATED, type Verdict } from '../core/navigation';
import { PanelState } from '../core/panel-layout';
import { ScopeService } from '../core/scope';
import { ScreenStores } from '../core/screen-store';
import { Session } from '../core/session';
import { ShellState } from '../core/shell-state';
import { STRINGS } from '../core/strings';
import { SuggestedView } from '../core/suggested-view';
import { TokenStore } from '../core/token-store';
import { CONVERSATION_STORAGE_KEY, TurnStore, conversationReadPath } from '../core/turn';
import { stubAccountPreferences } from '../testing/account-preferences';
import { stubAgentContext } from '../testing/agent-context';
import { stubAgentStatus } from '../testing/agent-status';
import { stubTurnStore } from '../testing/turn';
import { Panel } from './panel';

/**
 * The data-egress line beneath each turn's message (Story 16.15), rendered from a restored
 * conversation: the three sentences filled with the turn's own provider and host, the egress
 * colors only on a line whose screen context left, no line for a turn with no egress, and an
 * operator-configured host rendered as text, never as markup (AD-11 rule 4). Needs a real
 * `TurnStore` over a stub transport and the panel's usual collaborators; nothing else.
 */

class StubNavigation {
  loaded(): boolean {
    return true;
  }

  answered(): boolean {
    return true;
  }

  screenVerdict(): Verdict {
    return UNGATED;
  }

  subscribe(): () => void {
    return () => {};
  }
}

class StubScope {
  namespace(): string {
    return 'HSCUSTOM';
  }

  subscribe(): () => void {
    return () => {};
  }
}

function memoryStorage(initial: Record<string, string> = {}) {
  const map = new Map<string, string>(Object.entries(initial));
  return {
    getItem: (key: string) => map.get(key) ?? null,
    setItem: (key: string, value: string) => {
      map.set(key, value);
    },
    removeItem: (key: string) => {
      map.delete(key);
    },
  };
}

/** Built from fragments so this fixture is not itself a literal off-origin URL (`client-lint.mjs`). */
const MARKUP_HOST = '<img src="' + 'http:' + '//' + '203.0.113.9' + '/x">';

function egress(endpointHost: string, leavesInstance: boolean, contextSent: boolean) {
  return { provider: 'turnprobe', endpointHost, leavesInstance, contextSent };
}

function restoredTurn(seq: number, message: string, wireEgress: unknown) {
  return { seq, message, state: 'completed', reply: 'ok', error: null, steps: [], stepsDropped: 0, egress: wireEgress };
}

function fill(template: string, endpointHost: string): string {
  return template.split('<provider>').join('turnprobe').split('<host>').join(endpointHost);
}

/** The panel over a conversation restored with `turns`, and its transcript's turn elements. */
async function mountRestored(turns: unknown[]): Promise<HTMLElement[]> {
  TestBed.resetTestingModule();
  const api = {
    requestJson: async (path: string) =>
      path === conversationReadPath('convo-1')
        ? { kind: 'ok', status: 200, body: { conversationId: 'convo-1', turns } }
        : { kind: 'ok', status: 200, body: {} },
  };
  const turn = stubTurnStore({
    api: api as never,
    storage: memoryStorage({ [CONVERSATION_STORAGE_KEY]: 'convo-1' }),
    navigationType: () => 'reload',
    schedule: () => {},
  });
  await turn.restore();
  const agentStatus = stubAgentStatus([{ enabled: true }], {});
  await agentStatus.load();
  const scope = new StubScope();
  const preferences = stubAccountPreferences();
  const shell = new ShellState({ account: preferences });
  const session = new Session({
    fetch: async () => ({ status: 503, text: async () => '{}' }),
    tokens: new TokenStore({ storage: memoryStorage(), navigationType: () => 'navigate' }),
    schedule: () => {},
  } as never);
  session.setUserName('_SYSTEM');
  TestBed.configureTestingModule({
    providers: [
      provideRouter([{ path: '**', children: [] }]),
      { provide: NavigationService, useValue: new StubNavigation() as unknown as NavigationService },
      { provide: AgentStatus, useValue: agentStatus },
      { provide: AgentContext, useValue: stubAgentContext() as AgentContext },
      { provide: ScopeService, useValue: scope as unknown as ScopeService },
      { provide: ScreenStores, useValue: new ScreenStores({ account: stubAccountPreferences() }) },
      { provide: PanelState, useValue: new PanelState({ account: preferences, shell }) },
      { provide: TurnStore, useValue: turn },
      { provide: ShellState, useValue: shell },
      {
        provide: SuggestedView,
        useValue: new SuggestedView({
          api: { requestJson: async () => ({ kind: 'ok', status: 200, body: { rows: [] } }) } as never,
          agentStatus,
          scope: scope as unknown as ScopeService,
        }),
      },
      { provide: Session, useValue: session },
    ],
  });
  const fixture = TestBed.createComponent(Panel);
  fixture.detectChanges();
  const host = fixture.nativeElement as HTMLElement;
  return [...host.querySelectorAll<HTMLElement>('.ocu-panel-transcript .ocu-panel-turn')];
}

describe('Story 16.15: the data-egress line', () => {
  // Mutation (Rule 19): drop the `@if (turn.egress)` block from the panel's template -> every case
  // here that expects a line goes red.
  it('draws the three sentences beneath their messages, the egress colors only where the context left', async () => {
    const turns = await mountRestored([
      restoredTurn(1, 'left', egress('192.0.2.10', true, true)),
      restoredTurn(2, 'stayed', egress('10.0.0.5', false, true)),
      restoredTurn(3, 'none', egress('192.0.2.10', true, false)),
    ]);
    expect(turns).toHaveLength(3);
    const lines = turns.map((turn) => turn.querySelector('.ocu-panel-egress-line') as HTMLElement);
    expect(lines[0].textContent?.trim()).toBe(fill(STRINGS.egressLineLeft, '192.0.2.10'));
    expect(lines[1].textContent?.trim()).toBe(fill(STRINGS.egressLineStayed, '10.0.0.5'));
    expect(lines[2].textContent?.trim()).toBe(fill(STRINGS.egressLineNone, '192.0.2.10'));
    expect(lines.map((line) => line.classList.contains('ocu-panel-egress-line-leaves'))).toEqual([true, false, false]);
    // Beneath the message, inside the turn, so inside the transcript's log.
    for (const [index, turn] of turns.entries()) {
      expect(turn.querySelector('.ocu-panel-message-user + .ocu-panel-egress-line')).toBe(lines[index]);
      expect(turn.closest('[role="log"]')).not.toBeNull();
    }
  });

  // Mutation (Rule 19): draw the line only for a turn with no error banner
  // (`egress: errorBanner === null ? egressLine(entry.egress) : null`) -> this goes red.
  it('draws the line for a failed turn whose call was dispatched, beside its error banner', async () => {
    const failed = {
      ...restoredTurn(1, 'refused', egress('192.0.2.10', true, true)),
      state: 'failed',
      reply: null,
      error: { seq: 1, code: 'PROVIDER.REFUSED', reason: 'The provider refused the request.' },
    };
    const turns = await mountRestored([failed]);
    expect(turns).toHaveLength(1);
    expect(turns[0].querySelector('.ocu-panel-error-banner')).not.toBeNull();
    const line = turns[0].querySelector('.ocu-panel-message-user + .ocu-panel-egress-line');
    expect(line?.textContent?.trim()).toBe(fill(STRINGS.egressLineLeft, '192.0.2.10'));
  });

  it('draws no line for a turn with no egress, or one stored before it existed', async () => {
    const turns = await mountRestored([restoredTurn(1, 'refused', null), { ...restoredTurn(2, 'older', null), egress: undefined }]);
    expect(turns).toHaveLength(2);
    for (const turn of turns) expect(turn.querySelector('.ocu-panel-egress-line')).toBeNull();
  });

  // Mutation (Rule 19): bind the line with `[innerHTML]="turn.egress.text"` -> the `img` assertion
  // goes red.
  it('renders an endpoint host carrying markup as text: no element is created from it', async () => {
    const turns = await mountRestored([restoredTurn(1, 'markup', egress(MARKUP_HOST, true, true))]);
    const line = turns[0].querySelector('.ocu-panel-egress-line') as HTMLElement;
    expect(line.textContent?.trim()).toBe(fill(STRINGS.egressLineLeft, MARKUP_HOST));
    expect(line.querySelector('img')).toBeNull();
    expect(line.children).toHaveLength(0);
  });
});
