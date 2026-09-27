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
import { CONVERSATION_PATH, TURN_PATH, TurnStore } from '../core/turn';
import { turnLimitBanner } from '../core/turn-limit';
import { stubAccountPreferences } from '../testing/account-preferences';
import { stubAgentContext } from '../testing/agent-context';
import { stubAgentStatus } from '../testing/agent-status';
import { stubTurnStore } from '../testing/turn';
import { Panel } from './panel';

/**
 * The panel's rendering of a start refused for the turns-an-hour limit (Story 14.6, AD-41): the
 * published banner in its own alert slot, with the instance's `retryAt` in the browser's local
 * time, and the refused turn's transcript line under its message -- never the send-error banner and
 * never the stopped-turn template. Needs a real `TurnStore` over a stub transport and the panel's
 * usual collaborators; nothing else.
 */

class StubNavigation {
  private readonly listeners = new Set<() => void>();

  loaded(): boolean {
    return true;
  }

  answered(): boolean {
    return true;
  }

  screenVerdict(): Verdict {
    return UNGATED;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
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

function memoryStorage() {
  const map = new Map<string, string>();
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

const RETRY_AT = '2026-09-27T14:05:00Z';

async function mountRefused(): Promise<{ host: HTMLElement; turn: TurnStore }> {
  TestBed.resetTestingModule();
  const answers: Record<string, unknown> = {
    [CONVERSATION_PATH]: { kind: 'ok', status: 201, body: { conversationId: 'convo-1' } },
    [TURN_PATH]: {
      kind: 'error',
      status: 403,
      code: 'TURN.LIMITHOUR',
      reason: "You have reached this instance's limit of 3 agent turns an hour. You can send again at 14:05 UTC.",
      detail: { limit: 3, retryAt: RETRY_AT },
    },
  };
  const api = { requestJson: async (path: string) => answers[path] ?? { kind: 'ok', status: 200, body: {} } };
  const turn = stubTurnStore({ api: api as never, schedule: () => {} });
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
  const composer = host.querySelector('.ocu-panel-composer') as HTMLTextAreaElement;
  composer.value = 'list namespaces';
  composer.dispatchEvent(new Event('input'));
  fixture.detectChanges();
  (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
  for (let pass = 0; pass < 4; pass += 1) {
    await new Promise((resolve) => setImmediate(resolve));
    fixture.detectChanges();
  }
  return { host, turn };
}

describe('Story 14.6: a start refused for the turns-an-hour limit', () => {
  it('raises the published banner in its own alert slot, rendered by turnLimitBanner, and no send-error banner', async () => {
    // The runner's zone is not pinned, so local-versus-UTC rendering is pinned by
    // `tools/turn-limit.test.mjs` (Asia/Kolkata) and the browser spec, not here.
    // Mutation (Rule 19): drop the panel's `turn-limit` banner block -> this goes red.
    const { host } = await mountRefused();
    const banner = host.querySelector('[data-slot="turn-limit"]') as HTMLElement;
    expect(banner).not.toBeNull();
    expect(banner.getAttribute('role')).toBe('alert');
    expect(banner.querySelector('.ocu-banner-message')?.textContent?.trim()).toBe(turnLimitBanner(3, RETRY_AT));
    const local = new Date(RETRY_AT);
    const hhmm = `${String(local.getHours()).padStart(2, '0')}:${String(local.getMinutes()).padStart(2, '0')}`;
    expect(banner.textContent).toContain(`You can send again at ${hhmm}.`);
    expect(host.querySelector('[data-slot="send-error"]')).toBeNull();
    expect(host.querySelector('[data-slot="lock"] .ocu-banner')).toBeNull();
    expect((host.querySelector('.ocu-panel-composer') as HTMLTextAreaElement).value).toBe('list namespaces');
  });

  it("shows the refused turn's transcript line under its message, verbatim", async () => {
    // Mutation (Rule 19): drop the `TURN.LIMITHOUR` arm from `turnErrorBanner` -> the line is
    // wrapped in the stopped-turn template and this goes red.
    const { host } = await mountRefused();
    const turns = host.querySelectorAll('.ocu-panel-turn');
    expect(turns).toHaveLength(1);
    expect(turns[0].querySelector('.ocu-panel-message-user')?.textContent?.trim()).toBe('list namespaces');
    const line = turns[0].querySelector('.ocu-panel-error-banner') as HTMLElement;
    expect(line.textContent?.trim()).toBe(STRINGS.agentTurnLimitLine.split('<n>').join('3'));
  });
});
