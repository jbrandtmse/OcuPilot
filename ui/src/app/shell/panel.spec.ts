import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { describe, expect, it } from 'vitest';

import { AgentStatus, type Restraint, formatKillSwitch } from '../core/agent-status';
import { NavigationService, UNGATED, type Verdict } from '../core/navigation';
import { PanelState } from '../core/panel-layout';
import { PreferenceStore } from '../core/preferences';
import { ShellState } from '../core/shell-state';
import { STRINGS } from '../core/strings';
import { CONVERSATION_PATH, TURN_PATH, TurnStore, turnProgressPath, turnStopPath } from '../core/turn';
import { stubAgentStatus } from '../testing/agent-status';
import { stubTurnStore } from '../testing/turn';
import { Panel } from './panel';

/**
 * The panel on every signed-in route, asserted against the DOM: its anatomy and banner order, the
 * gate states it carries until a definition is enabled, the restraint banners, and the composer's
 * two modes. It needs a navigation map with a verdict for `agent/definitions`, a definitions list
 * body, and a `PanelState`; nothing else.
 */

const DENIED: Verdict = { allowed: false, failedPair: 'OcuPilotAdmin:USE' };

/** Everything that would be a way into the example card. */
const FOCUSABLE = 'a[href], button, input, select, textarea, [tabindex], [contenteditable]';

class StubNavigation {
  loadedFlag = true;
  verdict: Verdict = UNGATED;
  private readonly listeners = new Set<() => void>();

  loaded(): boolean {
    return this.loadedFlag;
  }

  /**
   * Always true, deliberately. The live service answers true once a read COMPLETES -- including a
   * read that failed, which leaves every verdict `UNGATED` -- so pinning it true makes `loadedFlag`
   * the only signal the panel can be reading.
   */
  answered(): boolean {
    return true;
  }

  screenVerdict(): Verdict {
    return this.verdict;
  }

  subscribe(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  notify(): void {
    for (const listener of this.listeners) listener();
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

interface Mounted {
  readonly fixture: ComponentFixture<Panel>;
  readonly navigation: StubNavigation;
  readonly agentStatus: AgentStatus;
  readonly panelState: PanelState;
  readonly turn: TurnStore;
  readonly rows: { enabled: boolean }[];
  readonly host: HTMLElement;
}

async function mount(
  options: {
    rows?: { enabled: boolean }[];
    verdict?: Verdict;
    loaded?: boolean;
    restraint?: Partial<Restraint>;
    answered?: boolean;
    panelState?: PanelState;
    turn?: TurnStore;
    /** A URL the router is on before the panel is created. */
    url?: string;
  } = {}
): Promise<Mounted> {
  TestBed.resetTestingModule();
  const navigation = new StubNavigation();
  navigation.verdict = options.verdict ?? UNGATED;
  navigation.loadedFlag = options.loaded ?? true;
  const rows = options.rows ?? [];
  const agentStatus = stubAgentStatus(rows, options.restraint ?? {});
  if (options.answered ?? true) await agentStatus.load();
  const preferences = new PreferenceStore({ storage: memoryStorage() });
  const panelState =
    options.panelState ?? new PanelState({ preferences, shell: new ShellState({ preferences }) });
  const turn = options.turn ?? stubTurnStore();
  TestBed.configureTestingModule({
    providers: [
      provideRouter([
        { path: '', children: [] },
        { path: 'agent/definitions', children: [] },
      ]),
      { provide: NavigationService, useValue: navigation as unknown as NavigationService },
      { provide: AgentStatus, useValue: agentStatus },
      { provide: PanelState, useValue: panelState },
      { provide: TurnStore, useValue: turn },
    ],
  });
  if (options.url !== undefined) await TestBed.inject(Router).navigateByUrl(options.url);
  const fixture = TestBed.createComponent(Panel);
  fixture.detectChanges();
  return { fixture, navigation, agentStatus, panelState, turn, rows, host: fixture.nativeElement as HTMLElement };
}

describe('the agent co-pilot panel', () => {
  it('AC1: an aside named for the area, with a header carrying the avatar, the title and Full screen, and no close control', async () => {
    const { host } = await mount({ rows: [{ enabled: true }] });
    const aside = host.querySelector('aside.ocu-panel') as HTMLElement;
    expect(aside.getAttribute('aria-label')).toBe(STRINGS.navAreaAgent);

    const header = aside.querySelector('.ocu-panel-header') as HTMLElement;
    expect(header.querySelector('.ocu-panel-avatar')).not.toBeNull();
    expect(header.querySelector('.ocu-panel-title')?.textContent?.trim()).toBe(STRINGS.navAreaAgent);
    const toggle = header.querySelector('.ocu-panel-full-screen-toggle') as HTMLButtonElement;
    expect(toggle.getAttribute('aria-label')).toBe(STRINGS.agentPanelFullScreen);
    expect(toggle.getAttribute('aria-expanded')).toBe('false');

    // Three controls total: New conversation and Full screen in the header, Send in the footer.
    // New conversation comes first (DESIGN.md panel header row), and none of the three closes
    // anything.
    const labels = [...aside.querySelectorAll('button')].map(
      (button) => button.getAttribute('aria-label') ?? button.textContent?.trim()
    );
    expect(labels).toEqual([STRINGS.actionNewConversation, STRINGS.agentPanelFullScreen, STRINGS.actionSend]);
    const newConversation = header.querySelector('.ocu-panel-new-conversation') as HTMLButtonElement;
    expect(newConversation.hasAttribute('aria-disabled')).toBe(false);
    expect(aside.querySelector('.ocu-context-chip')).toBeNull();
    expect(aside.querySelector('app-panel-resize-handle [role="separator"]')).not.toBeNull();
  });

  it('AC5: an administrator with nothing enabled and the kill switch on reads kill switch, reminder, chip slot, log, then the footer', async () => {
    // Mutation (Rule 19): move the reminder banner above the kill-switch banner in the template ->
    // this goes red on the order.
    const restraint = {
      killSwitch: true,
      killSwitchAudience: 'everyone',
      killSwitchReason: 'Paused during the change freeze',
      blocked: true,
    };
    const { host } = await mount({ restraint });
    const body = host.querySelector('.ocu-panel-body') as HTMLElement;
    const ids = [...body.querySelectorAll('.ocu-panel-banner')].map((node) => node.id);
    expect(ids).toEqual(['ocu-panel-kill-switch', 'ocu-panel-reason']);

    // The two slots this story leaves empty sit where EXPERIENCE.md puts them.
    const slots = [...body.querySelectorAll('.ocu-panel-banners > *')].map(
      (node) => node.id || node.getAttribute('data-slot')
    );
    expect(slots).toEqual(['ocu-panel-kill-switch', 'not-marked', 'ocu-panel-reason', 'lock']);

    const order = [...host.querySelectorAll('.ocu-panel-banners, .ocu-panel-chip-slot, [role="log"], .ocu-panel-footer')].map(
      (node) => node.className
    );
    expect(order).toEqual(['ocu-panel-banners', 'ocu-panel-chip-slot', 'ocu-panel-transcript', 'ocu-panel-footer']);

    const log = host.querySelector('[role="log"]') as HTMLElement;
    expect(log.getAttribute('aria-live')).toBe('polite');
    expect(log.getAttribute('aria-label')).toBe(STRINGS.agentConversationLabel);
    expect(log.getAttribute('tabindex')).toBe('0');

    const footer = host.querySelector('.ocu-panel-footer') as HTMLElement;
    expect([...footer.children].map((node) => node.className)).toEqual([
      'ocu-panel-read-only',
      'ocu-field-label',
      'ocu-panel-composer-row',
      'ocu-panel-caption',
    ]);
    const composer = footer.querySelector('textarea') as HTMLTextAreaElement;
    expect(footer.querySelector(`label[for="${composer.id}"]`)?.textContent?.trim()).toBe(STRINGS.agentComposerLabel);
    expect(footer.querySelector('.ocu-panel-send')?.textContent?.trim()).toBe(STRINGS.actionSend);
  });

  it('AC5: the caption spells the chord the way the platform does, for a Mac and for anything else', async () => {
    // Mutation (Rule 19): pick the caption with `!isApplePlatform()` in `Panel` -> the Mac leg goes red;
    // always pick the Mac caption -> the non-Mac leg goes red.
    const cases = [
      { platform: 'MacIntel', userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)', caption: STRINGS.agentComposerCaptionMac },
      { platform: 'Win32', userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)', caption: STRINGS.agentComposerCaption },
    ];
    for (const { platform, userAgent, caption } of cases) {
      Object.defineProperty(navigator, 'platform', { value: platform, configurable: true });
      Object.defineProperty(navigator, 'userAgent', { value: userAgent, configurable: true });
      try {
        const { host } = await mount();
        expect(host.querySelector('.ocu-panel-caption')?.textContent?.trim()).toBe(caption);
      } finally {
        delete (navigator as unknown as Record<string, unknown>)['platform'];
        delete (navigator as unknown as Record<string, unknown>)['userAgent'];
      }
    }
  });

  it('AC2 (3.6), DW-377: the administrator reminder banner carries its Definitions link and no dismiss control', async () => {
    // Mutation (Rule 19): resolve `definitionsUrl` from `screen.route` without `withQuery` -> the href
    // and the router URL lose `?ns=USER`, and both assertions go red.
    const { host, fixture } = await mount({ url: '/?ns=USER' });
    const banner = host.querySelector('#ocu-panel-reason') as HTMLElement;
    expect(banner.classList).toContain('ocu-panel-banner');
    expect(banner.textContent).toContain(STRINGS.agentGateReminderBanner);
    expect(banner.querySelectorAll('button')).toHaveLength(0);
    const link = banner.querySelector('a') as HTMLAnchorElement;
    expect(link.textContent?.trim()).toBe(STRINGS.agentDefinitionListLabel);
    expect(link.getAttribute('href')).toBe('agent/definitions?ns=USER');
    expect(host.textContent).not.toContain(STRINGS.agentGateEmptyState);

    link.click();
    await fixture.whenStable();
    expect(TestBed.inject(Router).url).toBe('/agent/definitions?ns=USER');
  });

  it('AC3 (3.6): a caller the map refuses reads the configuration-empty sentence in the log, and no reminder banner', async () => {
    const { host } = await mount({ verdict: DENIED });
    expect(host.querySelector('.ocu-panel-banner')).toBeNull();
    const empty = host.querySelector('[role="log"] .ocu-panel-empty') as HTMLElement;
    expect(empty.textContent?.trim()).toBe(STRINGS.agentGateEmptyState);
    const trust = Array.from(host.querySelectorAll('[role="log"] .ocu-panel-trust li')).map((node) =>
      node.textContent?.trim()
    );
    expect(trust).toEqual([STRINGS.agentTrustReads, STRINGS.agentTrustProposes, STRINGS.agentTrustAudited]);
  });

  it('AC3 (3.6): the example card is labelled with the published band and holds nothing focusable', async () => {
    const { host } = await mount({ verdict: DENIED });
    const example = host.querySelector('.ocu-panel-example') as HTMLElement;
    expect(example.querySelector('.ocu-proposal-card-band')?.textContent?.trim()).toBe(STRINGS.proposalExampleCardTitle);
    const card = example.querySelector('.ocu-proposal-card') as HTMLElement;
    expect(card.querySelectorAll(FOCUSABLE)).toHaveLength(0);
    expect(card.textContent).not.toContain('Expires in');
  });

  it('AC4 (3.6): unconfigured, the composer and Send are focusable and aria-disabled, never disabled, described by the sentence showing', async () => {
    // Mutation (Rule 19): swap `aria-disabled` for `disabled` on the composer -> this goes red.
    for (const verdict of [UNGATED, DENIED]) {
      const { host } = await mount({ verdict });
      const composer = host.querySelector('.ocu-panel-composer') as HTMLTextAreaElement;
      const send = host.querySelector('.ocu-panel-send') as HTMLButtonElement;
      for (const control of [composer, send]) {
        expect(control.getAttribute('aria-disabled')).toBe('true');
        expect(control.hasAttribute('disabled')).toBe(false);
        expect(control.hasAttribute('tabindex')).toBe(false);
      }
      expect(composer.hasAttribute('readonly')).toBe(true);
      const described = composer.getAttribute('aria-describedby');
      expect(send.getAttribute('aria-describedby')).toBe(described);
      expect((host.querySelector(`#${described}`) as HTMLElement).textContent).toContain(
        verdict.allowed ? STRINGS.agentGateReminderBanner : STRINGS.agentGateEmptyState
      );
    }
  });

  it('Enable clears the gate state together and leaves the panel, with an editable composer whose draft is the store\'s', async () => {
    // Mutation (Rule 19): restore the `shown` getter that rendered nothing once configured -> this
    // goes red, the panel gone from a configured instance.
    const { fixture, host, agentStatus, rows, panelState } = await mount();
    rows.push({ enabled: true });
    await agentStatus.load();
    fixture.detectChanges();
    expect(host.querySelector('aside.ocu-panel')).not.toBeNull();
    expect(host.querySelector('.ocu-panel-banner')).toBeNull();
    expect(host.querySelector('.ocu-proposal-card')).toBeNull();

    const composer = host.querySelector('.ocu-panel-composer') as HTMLTextAreaElement;
    expect(composer.hasAttribute('aria-disabled')).toBe(false);
    expect(composer.hasAttribute('readonly')).toBe(false);
    expect(composer.hasAttribute('aria-describedby')).toBe(false);
    composer.value = 'Why is /csp/myapp disabled?';
    composer.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    expect(panelState.draft()).toBe('Why is /csp/myapp disabled?');
    // Story 4.5: Send is real now -- available once the composer holds text.
    expect((host.querySelector('.ocu-panel-send') as HTMLElement).hasAttribute('aria-disabled')).toBe(false);

    // A second panel over the same store -- what a remount would be -- shows the same draft.
    const again = await mount({ rows: [{ enabled: true }], panelState });
    expect((again.host.querySelector('.ocu-panel-composer') as HTMLTextAreaElement).value).toBe(
      'Why is /csp/myapp disabled?'
    );
  });

  it('draws its chrome before either fact has answered, and names no audience until both have', async () => {
    // Mutation (Rule 19): read `navigation.answered()` rather than `loaded()` -> this goes red, and a
    // map outage tells every non-administrator that configuring the agent is their job.
    const unansweredMap = await mount({ loaded: false, verdict: DENIED });
    expect(unansweredMap.host.querySelector('aside.ocu-panel')).not.toBeNull();
    expect(unansweredMap.host.querySelector('.ocu-panel-empty')).toBeNull();
    expect(unansweredMap.host.querySelector('.ocu-panel-example')).toBeNull();
    expect(
      (unansweredMap.host.querySelector('.ocu-panel-composer') as HTMLElement).getAttribute('aria-disabled')
    ).toBe('true');
    unansweredMap.navigation.loadedFlag = true;
    unansweredMap.navigation.notify();
    unansweredMap.fixture.detectChanges();
    expect(unansweredMap.host.querySelector('.ocu-panel-empty')).not.toBeNull();

    const unansweredStatus = await mount({ answered: false });
    expect(unansweredStatus.agentStatus.answered()).toBe(false);
    expect(unansweredStatus.host.querySelector('aside.ocu-panel')).not.toBeNull();
    expect(unansweredStatus.host.querySelector('.ocu-panel-banner')).toBeNull();
    expect(unansweredStatus.host.querySelector('.ocu-panel-example')).toBeNull();
  });

  it('AC4: the full-screen toggle flips aria-expanded and the store, and the resize handle leaves while it is on', async () => {
    const { host, fixture, panelState } = await mount({ rows: [{ enabled: true }] });
    const toggle = host.querySelector('.ocu-panel-full-screen-toggle') as HTMLButtonElement;
    toggle.click();
    fixture.detectChanges();
    expect(panelState.fullScreen()).toBe(true);
    expect(toggle.getAttribute('aria-expanded')).toBe('true');
    expect(host.querySelector('[role="separator"]')).toBeNull();
    toggle.click();
    fixture.detectChanges();
    expect(toggle.getAttribute('aria-expanded')).toBe('false');
    expect(host.querySelector('[role="separator"]')).not.toBeNull();
  });

  // --- Story 3.7: the restraint half ----------------------------------------------------------

  it('AC2 (3.7): enforced read-only raises its published banner and the enforced footer line, on a configured instance', async () => {
    const { host } = await mount({
      rows: [{ enabled: true }],
      restraint: { enforcedReadOnly: true, blocked: true, footerKey: 'statusReadOnlyEnforced' },
    });
    const banner = host.querySelector('#ocu-panel-read-only') as HTMLElement;
    expect(banner.textContent).toContain(STRINGS.agentReadOnlyEnforcedBanner);
    expect(banner.getAttribute('role')).toBe('alert');
    expect(banner.className).toContain('ocu-banner-restrained');
    expect((host.querySelector('.ocu-panel-read-only') as HTMLElement).textContent?.trim()).toBe(
      STRINGS.statusReadOnlyEnforced
    );
    expect(host.querySelector('.ocu-panel-example')).toBeNull();
  });

  it('Read-only changes only the footer line: the composer stays editable and the line turns restrained', async () => {
    // Mutation (Rule 19): gate `composerUnavailable` on `agentStatus.restrained()` again -> this goes
    // red on the composer; always `false` from `readOnlyOn` -> red on the footer line.
    const { host, panelState } = await mount({
      rows: [{ enabled: true }],
      restraint: { enforcedReadOnly: true, blocked: true, footerKey: 'statusReadOnlyEnforced' },
    });
    const composer = host.querySelector('.ocu-panel-composer') as HTMLTextAreaElement;
    expect(composer.hasAttribute('aria-disabled')).toBe(false);
    expect(composer.hasAttribute('readonly')).toBe(false);
    composer.value = 'Why is this blocked?';
    composer.dispatchEvent(new Event('input'));
    expect(panelState.draft()).toBe('Why is this blocked?');
    expect((host.querySelector('.ocu-panel-read-only') as HTMLElement).classList.contains('ocu-panel-read-only-on')).toBe(true);

    const off = await mount({ rows: [{ enabled: true }] });
    expect((off.host.querySelector('.ocu-panel-read-only') as HTMLElement).classList.contains('ocu-panel-read-only-on')).toBe(false);
  });

  it('AC2 (3.7): the footer line reads the off key when nothing restrains, and the definition key when the definition does', async () => {
    const off = await mount();
    expect((off.host.querySelector('.ocu-panel-read-only') as HTMLElement).textContent?.trim()).toBe(
      STRINGS.statusReadOnlyOff
    );
    const byDefinition = await mount({
      rows: [{ enabled: true }],
      restraint: {
        blocked: true,
        footerKey: 'statusReadOnlyByDefinition',
        killSwitch: true,
        killSwitchAudience: 'everyone',
        killSwitchReason: 'Paused during the change freeze',
      },
    });
    expect((byDefinition.host.querySelector('.ocu-panel-read-only') as HTMLElement).textContent?.trim()).toBe(
      STRINGS.statusReadOnlyByDefinition
    );
    expect(byDefinition.host.querySelector('#ocu-panel-read-only')).toBeNull();
    expect(byDefinition.host.querySelector('#ocu-panel-kill-switch')).not.toBeNull();
  });

  it('AC3 (3.7): the kill switch raises its published banner with the stored reason, and describes the composer and Send', async () => {
    const restraint = {
      killSwitch: true,
      killSwitchAudience: 'everyone',
      killSwitchReason: 'Paused during the change freeze',
      blocked: true,
    };
    const { host } = await mount({ rows: [{ enabled: true }], restraint });
    const banner = host.querySelector('#ocu-panel-kill-switch') as HTMLElement;
    expect(banner.textContent).toContain(
      formatKillSwitch(STRINGS.agentKillSwitchBanner, restraint.killSwitchAudience, restraint.killSwitchReason)
    );
    expect(banner.getAttribute('role')).toBe('alert');
    for (const control of [host.querySelector('.ocu-panel-composer'), host.querySelector('.ocu-panel-send')] as HTMLElement[]) {
      expect(control.getAttribute('aria-disabled')).toBe('true');
      expect(control.hasAttribute('disabled')).toBe(false);
      expect(control.getAttribute('aria-describedby')).toBe('ocu-panel-kill-switch');
    }
  });

  it('AC3 (3.7): the per-user kill switch resolves the published audience slot to the other word', async () => {
    const { host } = await mount({
      rows: [{ enabled: true }],
      restraint: {
        killSwitch: true,
        killSwitchAudience: 'you',
        killSwitchReason: 'Switched off while the account is reviewed',
        blocked: true,
      },
    });
    const banner = host.querySelector('#ocu-panel-kill-switch') as HTMLElement;
    expect(banner.textContent).toContain('switched off for you:');
    expect(banner.textContent).not.toContain('everyone');
  });

  it("AC2 (3.7): both restraint banners appear in EXPERIENCE.md's order, and the kill switch is the reason the controls name", async () => {
    const { host } = await mount({
      rows: [{ enabled: true }],
      restraint: {
        killSwitch: true,
        killSwitchAudience: 'everyone',
        killSwitchReason: 'off',
        enforcedReadOnly: true,
        blocked: true,
        footerKey: 'statusReadOnlyEnforced',
      },
    });
    const ids = Array.from(host.querySelectorAll('.ocu-panel-banner')).map((node) => node.id);
    expect(ids).toEqual(['ocu-panel-kill-switch', 'ocu-panel-read-only']);
    expect((host.querySelector('.ocu-panel-composer') as HTMLElement).getAttribute('aria-describedby')).toBe(
      'ocu-panel-kill-switch'
    );
  });

  it('Integration AC (3.7): the panel reads the restraint off AgentStatus and follows it when it clears', async () => {
    const restraint: Record<string, unknown> = {
      enforcedReadOnly: true,
      blocked: true,
      footerKey: 'statusReadOnlyEnforced',
    };
    const { host, agentStatus, fixture } = await mount({
      rows: [{ enabled: true }],
      restraint: restraint as Partial<Restraint>,
    });
    expect(host.querySelector('#ocu-panel-read-only')).not.toBeNull();
    delete restraint['enforcedReadOnly'];
    delete restraint['blocked'];
    delete restraint['footerKey'];
    await agentStatus.load();
    fixture.detectChanges();
    expect(host.querySelector('#ocu-panel-read-only')).toBeNull();
    expect((host.querySelector('.ocu-panel-read-only') as HTMLElement).textContent?.trim()).toBe(
      STRINGS.statusReadOnlyOff
    );
    expect((host.querySelector('.ocu-panel-composer') as HTMLElement).hasAttribute('aria-disabled')).toBe(false);
  });
});

// --- Story 4.5: Send/Stop, the lock banner, Enter vs Shift+Enter, cards, and markup as text -----

/** Per-path response queues over `TurnStore`'s own transport shape, and every call recorded. */
function fakeTurnApi(responses: Record<string, unknown[]> = {}) {
  const calls: { path: string; method: string; body?: string }[] = [];
  const seen = new Map<string, number>();
  return {
    calls,
    requestJson: async (path: string, init: { method?: string; body?: string } = {}) => {
      calls.push({ path, method: init.method ?? 'GET', body: init.body });
      const list = responses[path] ?? [];
      const index = seen.get(path) ?? 0;
      seen.set(path, index + 1);
      if (list.length === 0) return { kind: 'ok', status: 200, body: {} };
      return list[Math.min(index, list.length - 1)];
    },
  };
}

function fakeTurnSchedule() {
  const scheduled: { run: () => void; delayMs: number }[] = [];
  return { schedule: (run: () => void, delayMs: number) => scheduled.push({ run, delayMs }), scheduled };
}

const turnSettle = () => new Promise((resolve) => setImmediate(resolve));

function turnStep(overrides: Record<string, unknown> = {}) {
  return {
    seq: 1,
    kind: 'tool',
    name: 'shell.namespaces.read',
    status: 'ok',
    summary: '',
    text: '',
    code: '',
    truncated: false,
    target: '',
    arguments: '',
    result: null,
    reason: '',
    failedPair: '',
    ...overrides,
  };
}

async function typeDraft(host: HTMLElement, fixture: ComponentFixture<Panel>, text: string): Promise<void> {
  const composer = host.querySelector('.ocu-panel-composer') as HTMLTextAreaElement;
  composer.value = text;
  composer.dispatchEvent(new Event('input'));
  fixture.detectChanges();
}

describe('Story 4.5: Send/Stop, the lock banner, Enter vs Shift+Enter, cards, and markup as text', () => {
  it('Send becomes Stop and keeps focus while a turn runs; the composer stays editable, described by "A turn is in progress"', async () => {
    // Mutation (Rule 19): gate `sendAriaDisabled` on `composerUnavailable` alone (drop the busy
    // branch) -> Stop would render `aria-disabled="true"` and this goes red.
    const { schedule } = fakeTurnSchedule();
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
    });
    const turn = stubTurnStore({ api: api as never, schedule });
    const { host, fixture } = await mount({ rows: [{ enabled: true }], turn });
    await typeDraft(host, fixture, 'list namespaces');

    const send = host.querySelector('.ocu-panel-send') as HTMLButtonElement;
    send.focus();
    send.click();
    await turnSettle();
    fixture.detectChanges();

    expect(send.textContent?.trim()).toBe(STRINGS.actionStop);
    expect(send.hasAttribute('aria-disabled')).toBe(false);
    expect(document.activeElement).toBe(send);

    const composer = host.querySelector('.ocu-panel-composer') as HTMLTextAreaElement;
    expect(composer.getAttribute('aria-disabled')).toBe('true');
    expect(composer.hasAttribute('readonly')).toBe(false);
    const describedBy = composer.getAttribute('aria-describedby');
    expect(send.getAttribute('aria-describedby')).toBe(describedBy);
    expect((host.querySelector(`#${describedBy}`) as HTMLElement).textContent).toBe(
      STRINGS.agentComposerLockedReason
    );

    // Send cleared the draft on acceptance (202); the user message is now in the transcript.
    expect(composer.value).toBe('');
    expect(host.querySelector('.ocu-panel-message-user')?.textContent?.trim()).toBe('list namespaces');
  });

  it('Enter (without Shift) sends like Send; Shift+Enter is left to the textarea (no send)', async () => {
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
    });
    const turn = stubTurnStore({ api: api as never });
    const { host, fixture } = await mount({ rows: [{ enabled: true }], turn });
    await typeDraft(host, fixture, 'hello');
    const composer = host.querySelector('.ocu-panel-composer') as HTMLTextAreaElement;

    const shiftEnter = new KeyboardEvent('keydown', { key: 'Enter', shiftKey: true, cancelable: true });
    composer.dispatchEvent(shiftEnter);
    expect(shiftEnter.defaultPrevented).toBe(false);
    expect(api.calls.some((c) => c.path === TURN_PATH)).toBe(false);

    const enter = new KeyboardEvent('keydown', { key: 'Enter', cancelable: true });
    composer.dispatchEvent(enter);
    expect(enter.defaultPrevented).toBe(true);
    await turnSettle();
    fixture.detectChanges();
    expect(api.calls.some((c) => c.path === TURN_PATH)).toBe(true);
    expect(composer.value).toBe('');
  });

  it('Second send: Enter while busy shows the lock banner (role="status"), keeps the draft, and appends nothing', async () => {
    const { schedule } = fakeTurnSchedule();
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
    });
    const turn = stubTurnStore({ api: api as never, schedule });
    const { host, fixture } = await mount({ rows: [{ enabled: true }], turn });
    await typeDraft(host, fixture, 'first');
    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();

    await typeDraft(host, fixture, 'second, while busy');
    const composer = host.querySelector('.ocu-panel-composer') as HTMLTextAreaElement;
    const enter = new KeyboardEvent('keydown', { key: 'Enter', cancelable: true });
    composer.dispatchEvent(enter);
    await turnSettle();
    fixture.detectChanges();

    const banner = host.querySelector('[data-slot="lock"] .ocu-banner') as HTMLElement;
    expect(banner).not.toBeNull();
    expect(banner.getAttribute('role')).toBe('status');
    expect(banner.textContent).toContain(STRINGS.agentTurnLockBanner);
    expect(composer.value).toBe('second, while busy');
    expect(host.querySelectorAll('.ocu-panel-message-user')).toHaveLength(1);
  });

  it('a running card is expanded by default, a done card is collapsed, and a user click overrides either', async () => {
    const { schedule, scheduled } = fakeTurnSchedule();
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
      [turnProgressPath('turn-1')]: [
        { kind: 'ok', status: 200, body: { turnId: 'turn-1', state: 'running', steps: [turnStep({ status: 'running' })], stepsDropped: 0, reply: null, error: null } },
        { kind: 'ok', status: 200, body: { turnId: 'turn-1', state: 'completed', steps: [turnStep()], stepsDropped: 0, reply: 'done', error: null } },
      ],
    });
    const turn = stubTurnStore({ api: api as never, schedule });
    const { host, fixture } = await mount({ rows: [{ enabled: true }], turn });
    await typeDraft(host, fixture, 'go');
    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();

    // The live entry starts with no steps at all; the first poll tick is what writes the card.
    scheduled.shift()?.run();
    await turnSettle();
    fixture.detectChanges();
    let toggle = host.querySelector('.ocu-tool-call-toggle') as HTMLButtonElement;
    expect(toggle.getAttribute('aria-expanded'), 'running, so expanded by default').toBe('true');

    scheduled.shift()?.run();
    await turnSettle();
    fixture.detectChanges();
    toggle = host.querySelector('.ocu-tool-call-toggle') as HTMLButtonElement;
    expect(toggle.getAttribute('aria-expanded'), 'done, and never opened, so it collapsed').toBe('false');

    toggle.click();
    fixture.detectChanges();
    expect(toggle.getAttribute('aria-expanded'), 'the user opened it').toBe('true');
  });

  it('a stopped card is a restrained bar with no body and no button -- not expandable', async () => {
    const storage = new Map<string, string>();
    const memory = {
      getItem: (key: string) => (storage.has(key) ? (storage.get(key) as string) : null),
      setItem: (key: string, value: string) => storage.set(key, value),
      removeItem: (key: string) => storage.delete(key),
    };
    memory.setItem('ocupilot.conversation', 'convo-1');
    const api = fakeTurnApi({
      [conversationReadPathFor('convo-1')]: [
        {
          kind: 'ok',
          status: 200,
          body: {
            conversationId: 'convo-1',
            turns: [
              {
                seq: 1,
                message: 'stop me',
                state: 'stopped',
                reply: null,
                error: { seq: 1, code: 'TURN.STOPPED', reason: 'Stopped' },
                steps: [turnStep({ status: 'stopped', name: 'shell.namespaces.read', target: '' })],
                stepsDropped: 0,
              },
            ],
          },
        },
      ],
    });
    const turn = stubTurnStore({ api: api as never, storage: memory, navigationType: () => 'reload' });
    await turn.restore();
    const { host } = await mount({ rows: [{ enabled: true }], turn });

    const card = host.querySelector('.ocu-tool-call-card-stopped') as HTMLElement;
    expect(card).not.toBeNull();
    expect(card.tagName).toBe('P');
    expect(card.querySelector('button')).toBeNull();
    expect(card.textContent?.trim()).toBe('Stopped by you at shell.namespaces.read');
    expect(host.querySelector('.ocu-tool-call-body')).toBeNull();
    // A stop is never an error: no error banner for this turn.
    expect(host.querySelector('.ocu-panel-error-banner')).toBeNull();
  });

  it('a failed step\'s card reads "failed \u2014 <reason>", stays expandable, and carries its failedPair', async () => {
    // I/O & Edge-Case Matrix row "Failed tool": card 'failed — <reason>'; step carries failedPair.
    const storage = new Map<string, string>();
    const memory = {
      getItem: (key: string) => (storage.has(key) ? (storage.get(key) as string) : null),
      setItem: (key: string, value: string) => storage.set(key, value),
      removeItem: (key: string) => storage.delete(key),
    };
    memory.setItem('ocupilot.conversation', 'convo-1');
    const api = fakeTurnApi({
      [conversationReadPathFor('convo-1')]: [
        {
          kind: 'ok',
          status: 200,
          body: {
            conversationId: 'convo-1',
            turns: [
              {
                seq: 1,
                message: 'disable it',
                state: 'failed',
                reply: null,
                error: { seq: 1, code: 'AUTH.NOPRIVILEGE', reason: 'no privilege' },
                steps: [
                  turnStep({
                    status: 'error',
                    code: 'AUTH.NOPRIVILEGE',
                    reason: 'This account does not hold the privilege that tool call requires.',
                    failedPair: '%Admin_Secure:USE',
                  }),
                ],
                stepsDropped: 0,
              },
            ],
          },
        },
      ],
    });
    const turn = stubTurnStore({ api: api as never, storage: memory, navigationType: () => 'reload' });
    await turn.restore();
    const { host, fixture } = await mount({ rows: [{ enabled: true }], turn });

    const toggle = host.querySelector('.ocu-tool-call-toggle') as HTMLButtonElement;
    expect(toggle).not.toBeNull();
    const statusWord = toggle.querySelector('.ocu-tool-call-status-word') as HTMLElement;
    expect(statusWord.textContent).toBe(
      STRINGS.toolCallStatusFailed.split('<reason>').join('This account does not hold the privilege that tool call requires.')
    );
    expect(statusWord.classList.contains('ocu-tool-call-status-warning')).toBe(true);
    // A failed card is still a disclosure, not a restrained bar: it stays expandable, unlike Stop.
    expect(host.querySelector('.ocu-tool-call-card-stopped')).toBeNull();
    toggle.click();
    fixture.detectChanges();
    expect(toggle.getAttribute('aria-expanded')).toBe('true');
  });

  it('markup in a reply renders as literal text -- no innerHTML, no element created from it', async () => {
    const storage = new Map<string, string>();
    const memory = {
      getItem: (key: string) => (storage.has(key) ? (storage.get(key) as string) : null),
      setItem: (key: string, value: string) => storage.set(key, value),
      removeItem: (key: string) => storage.delete(key),
    };
    memory.setItem('ocupilot.conversation', 'convo-1');
    // Built from fragments so this fixture is not itself a literal off-origin URL
    // `ui/tools/client-lint.mjs`'s `no-off-origin-url` rule would refuse (AD-28, AD-47).
    const markup = '<img src="' + 'http:' + '//' + '203.0.113.9' + '/x">';
    const api = fakeTurnApi({
      [conversationReadPathFor('convo-1')]: [
        {
          kind: 'ok',
          status: 200,
          body: {
            conversationId: 'convo-1',
            turns: [{ seq: 1, message: 'hi', state: 'completed', reply: markup, error: null, steps: [], stepsDropped: 0 }],
          },
        },
      ],
    });
    const turn = stubTurnStore({ api: api as never, storage: memory, navigationType: () => 'reload' });
    await turn.restore();
    const { host } = await mount({ rows: [{ enabled: true }], turn });

    const reply = host.querySelector('.ocu-panel-message-agent-text') as HTMLElement;
    expect(reply.textContent).toBe(markup);
    expect(reply.querySelector('img')).toBeNull();
  });

  it('clicking Send does nothing while the composer is unavailable, even with text in the draft', async () => {
    // Mutation (Rule 19): drop the `composerUnavailable` guard from `sendCurrentDraft` -> this
    // goes red, and a stray click while unconfigured or kill-switched would still start a turn.
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
    });
    const turn = stubTurnStore({ api: api as never });
    const preferences = new PreferenceStore({ storage: memoryStorage() });
    const panelState = new PanelState({ preferences, shell: new ShellState({ preferences }) });
    panelState.setDraft('typed before the kill switch came on');
    const { host } = await mount({
      restraint: { killSwitch: true, killSwitchAudience: 'everyone', killSwitchReason: 'off', blocked: true },
      panelState,
      turn,
    });
    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    expect(api.calls.some((c) => c.path === TURN_PATH)).toBe(false);
  });

  it('Stop stays reachable if the kill switch flips on while a turn is running', async () => {
    // Mutation (Rule 19): check `composerUnavailable` before `busy` in `sendAriaDisabled` -> an
    // emergency kill switch pulled mid-turn would render Stop `aria-disabled="true"`, the one
    // moment it must stay clickable.
    const restraint: Record<string, boolean | string> = {};
    const { schedule } = fakeTurnSchedule();
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
    });
    const turn = stubTurnStore({ api: api as never, schedule });
    const { host, fixture, agentStatus } = await mount({
      rows: [{ enabled: true }],
      turn,
      restraint: restraint as Partial<Restraint>,
    });
    await typeDraft(host, fixture, 'go');
    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();

    restraint['killSwitch'] = true;
    restraint['killSwitchAudience'] = 'everyone';
    restraint['killSwitchReason'] = 'incident';
    await agentStatus.load();
    fixture.detectChanges();

    const send = host.querySelector('.ocu-panel-send') as HTMLButtonElement;
    expect(send.textContent?.trim()).toBe(STRINGS.actionStop);
    expect(send.getAttribute('aria-disabled')).not.toBe('true');
  });

  it('New conversation is unavailable, and issues no POST /conversation, when unconfigured or kill-switched -- not only while busy', async () => {
    // Mutation (Rule 19): gate `newConversationAriaDisabled`/`onNewConversation` on `busy` alone
    // -> this goes red, and a click while kill-switched would still mint a fresh conversation.
    const api = fakeTurnApi({ [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }] });
    const turn = stubTurnStore({ api: api as never });
    const { host } = await mount({
      restraint: { killSwitch: true, killSwitchAudience: 'everyone', killSwitchReason: 'off', blocked: true },
      turn,
    });
    const newConversation = host.querySelector('.ocu-panel-new-conversation') as HTMLButtonElement;
    expect(newConversation.getAttribute('aria-disabled')).toBe('true');
    newConversation.click();
    await turnSettle();
    expect(api.calls.some((c) => c.path === CONVERSATION_PATH)).toBe(false);
  });

  it('a plain-text reply with no tool call renders zero tool-call cards -- a "model" step is never given to the card', async () => {
    // Mutation (Rule 19): drop the `step.kind === 'tool'` filter in the `turns` getter -> this
    // goes red, and every model round-trip would render its own spurious card.
    const storage = new Map<string, string>();
    const memory = {
      getItem: (key: string) => (storage.has(key) ? (storage.get(key) as string) : null),
      setItem: (key: string, value: string) => storage.set(key, value),
      removeItem: (key: string) => storage.delete(key),
    };
    memory.setItem('ocupilot.conversation', 'convo-1');
    const api = fakeTurnApi({
      [conversationReadPathFor('convo-1')]: [
        {
          kind: 'ok',
          status: 200,
          body: {
            conversationId: 'convo-1',
            turns: [
              {
                seq: 1,
                message: 'hi',
                state: 'completed',
                reply: 'hello there',
                error: null,
                steps: [turnStep({ kind: 'model', name: 'provider', status: 'ok' })],
                stepsDropped: 0,
              },
            ],
          },
        },
      ],
    });
    const turn = stubTurnStore({ api: api as never, storage: memory, navigationType: () => 'reload' });
    await turn.restore();
    const { host } = await mount({ rows: [{ enabled: true }], turn });

    expect(host.querySelectorAll('.ocu-tool-call-card')).toHaveLength(0);
    expect(host.querySelectorAll('.ocu-tool-call-toggle')).toHaveLength(0);
  });
});

function conversationReadPathFor(id: string): string {
  return `${CONVERSATION_PATH}/${id}`;
}
