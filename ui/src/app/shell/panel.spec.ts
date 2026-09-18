import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { describe, expect, it } from 'vitest';

import { AGENT_CONTEXT_PATH, AgentContext, NO_CONTEXT_INFO, type AgentContextInfo } from '../core/agent-context';
import { AgentStatus, type Restraint, formatKillSwitch } from '../core/agent-status';
import { NavigationService, UNGATED, type Verdict } from '../core/navigation';
import { PanelState } from '../core/panel-layout';
import { PreferenceStore } from '../core/preferences';
import { ScopeService } from '../core/scope';
import { ScreenStores } from '../core/screen-store';
import { ShellState } from '../core/shell-state';
import { STRINGS } from '../core/strings';
import { CONVERSATION_PATH, TURN_PATH, TurnStore, turnProgressPath, turnStopPath } from '../core/turn';
import { stubAgentContext } from '../testing/agent-context';
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

/** The namespace `assembleContext` and the chip read (Story 4.11); controllable per test. */
class StubScope {
  value = 'HSCUSTOM';
  private readonly listeners = new Set<() => void>();

  namespace(): string {
    return this.value;
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
  readonly agentContext: AgentContext;
  readonly scope: StubScope;
  readonly screenStores: ScreenStores;
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
    /** The context chip's own store (Story 4.11). Unanswered by default, like `AgentStatus`
     * before `load()` -- so a test that is not about the chip never sees one. */
    agentContext?: AgentContext;
    /** `ScopeService.namespace()` (Story 4.11), `'HSCUSTOM'` unless a test says otherwise. */
    namespace?: string;
    screenStores?: ScreenStores;
  } = {}
): Promise<Mounted> {
  TestBed.resetTestingModule();
  const navigation = new StubNavigation();
  navigation.verdict = options.verdict ?? UNGATED;
  navigation.loadedFlag = options.loaded ?? true;
  const rows = options.rows ?? [];
  const agentStatus = stubAgentStatus(rows, options.restraint ?? {});
  if (options.answered ?? true) await agentStatus.load();
  const agentContext = options.agentContext ?? stubAgentContext();
  const scope = new StubScope();
  scope.value = options.namespace ?? 'HSCUSTOM';
  const screenStores =
    options.screenStores ?? new ScreenStores({ preferences: new PreferenceStore({ storage: memoryStorage() }) });
  const preferences = new PreferenceStore({ storage: memoryStorage() });
  const panelState =
    options.panelState ?? new PanelState({ preferences, shell: new ShellState({ preferences }) });
  const turn = options.turn ?? stubTurnStore();
  TestBed.configureTestingModule({
    providers: [
      provideRouter([
        { path: '', children: [] },
        { path: 'agent/definitions', children: [] },
        { path: 'agent/definitions/edit', children: [] },
        { path: 'permissions/users', children: [] },
        // `app.routes.ts` ends in this, and it is what keeps the shell -- and this panel --
        // mounted on a URL that names no built descriptor.
        { path: '**', children: [] },
      ]),
      { provide: NavigationService, useValue: navigation as unknown as NavigationService },
      { provide: AgentStatus, useValue: agentStatus },
      { provide: AgentContext, useValue: agentContext },
      { provide: ScopeService, useValue: scope as unknown as ScopeService },
      { provide: ScreenStores, useValue: screenStores },
      { provide: PanelState, useValue: panelState },
      { provide: TurnStore, useValue: turn },
    ],
  });
  if (options.url !== undefined) await TestBed.inject(Router).navigateByUrl(options.url);
  const fixture = TestBed.createComponent(Panel);
  fixture.detectChanges();
  return {
    fixture,
    navigation,
    agentStatus,
    agentContext,
    scope,
    screenStores,
    panelState,
    turn,
    rows,
    host: fixture.nativeElement as HTMLElement,
  };
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
      'ocu-panel-warning-slot',
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

  it('Story 4.8: a Send the instance refuses with a non-409 status raises the refusal banner carrying the server\'s own reason, and the next successful send clears it', async () => {
    // Mutation (Rule 19): drop the `sendErrorValue` assignment from `TurnStore.send`'s non-409
    // branch -> the banner never renders and this goes red at the first expectation.
    const { schedule } = fakeTurnSchedule();
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [
        { kind: 'error', status: 422, code: 'TURN.MESSAGE.LENGTH', reason: 'That message is too long.', detail: null },
        { kind: 'ok', status: 202, body: { turnId: 'turn-1' } },
      ],
    });
    const turn = stubTurnStore({ api: api as never, schedule });
    const { host, fixture } = await mount({ rows: [{ enabled: true }], turn });
    await typeDraft(host, fixture, 'too long');
    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();

    const banner = host.querySelector('[data-slot="send-error"]') as HTMLElement;
    expect(banner).not.toBeNull();
    expect(banner.getAttribute('role')).toBe('alert');
    expect(banner.textContent).toContain('That message is too long.');
    // The draft is kept and nothing was appended: a refused send changes no transcript.
    expect((host.querySelector('.ocu-panel-composer') as HTMLTextAreaElement).value).toBe('too long');
    expect(host.querySelectorAll('.ocu-panel-message-user')).toHaveLength(0);
    // 409's own banner is a different slot and is not raised by this refusal.
    expect(host.querySelector('[data-slot="lock"] .ocu-banner')).toBeNull();

    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();
    expect(host.querySelector('[data-slot="send-error"]')).toBeNull();
    expect(host.querySelector('.ocu-panel-message-user')?.textContent?.trim()).toBe('too long');
  });

  it('Story 4.8: a Send that never reached the instance falls back to the connectivity sentence, since there is no envelope to quote', async () => {
    const { schedule } = fakeTurnSchedule();
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'error', status: 0, code: null, reason: null, detail: null }],
    });
    const turn = stubTurnStore({ api: api as never, schedule });
    const { host, fixture } = await mount({ rows: [{ enabled: true }], turn });
    await typeDraft(host, fixture, 'anything');
    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();

    const banner = host.querySelector('[data-slot="send-error"]') as HTMLElement;
    expect(banner).not.toBeNull();
    expect(banner.textContent).toContain(STRINGS.connectivityBannerUnreachable);
  });

  // The other arm of the same fallback: an answer that reached the instance but carried no
  // envelope to quote -- a Web Gateway error page, say -- reads as a server fault, not as an
  // unreachable instance. Without this leg only the `unreachable` arm is ever executed.
  //
  // Mutation (Rule 19): answer `STRINGS.connectivityBannerUnreachable` from `sendErrorText`'s
  // false arm -> this goes red while the status-0 case above stays green.
  it('Story 4.8: a refusal that carried no envelope but did reach the instance reads as a server fault', async () => {
    const { schedule } = fakeTurnSchedule();
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'error', status: 502, code: null, reason: null, detail: null }],
    });
    const turn = stubTurnStore({ api: api as never, schedule });
    const { host, fixture } = await mount({ rows: [{ enabled: true }], turn });
    await typeDraft(host, fixture, 'anything');
    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();

    const banner = host.querySelector('[data-slot="send-error"]') as HTMLElement;
    expect(banner).not.toBeNull();
    expect(banner.textContent).toContain(STRINGS.connectivityServerFault);
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

  it('markup in a running step\'s name, arguments and result renders as literal text -- no innerHTML, no element created from it (AD-33)', async () => {
    // QA (Story 4.5): no existing spec covers a tool-call card's own fields the way the reply is
    // covered above -- tool-call-card.ts's doc comment claims interpolation-only rendering for
    // name/arguments/text, but nothing pins it. Built from fragments, as above, so this fixture is
    // not itself a literal off-origin URL (`ui/tools/client-lint.mjs`'s `no-off-origin-url` rule).
    const markup = '<img src="' + 'http:' + '//' + '203.0.113.9' + '/x">';
    const { schedule, scheduled } = fakeTurnSchedule();
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
      [turnProgressPath('turn-1')]: [
        {
          kind: 'ok',
          status: 200,
          body: {
            turnId: 'turn-1',
            state: 'running',
            steps: [turnStep({ status: 'running', name: markup, arguments: markup, text: markup })],
            stepsDropped: 0,
            reply: null,
            error: null,
          },
        },
      ],
    });
    const turn = stubTurnStore({ api: api as never, schedule });
    const { host, fixture } = await mount({ rows: [{ enabled: true }], turn });
    await typeDraft(host, fixture, 'go');
    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();

    scheduled.shift()?.run();
    await turnSettle();
    fixture.detectChanges();

    const card = host.querySelector('.ocu-tool-call-card') as HTMLElement;
    expect(card.querySelector('.ocu-tool-call-name')?.textContent).toBe(markup);
    expect(card.querySelector('.ocu-tool-call-arguments')?.textContent).toBe(markup);
    expect(card.querySelector('.ocu-tool-call-result')?.textContent).toBe(markup);
    expect(card.querySelector('img')).toBeNull();
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

describe('Story 4.5 review: restored cards, the error banner, the rows line, and IME Enter', () => {
  /** Mount the panel over a conversation restored with `turns`. */
  async function mountRestored(turns: unknown[]) {
    const storage = new Map<string, string>([['ocupilot.conversation', 'convo-1']]);
    const memory = {
      getItem: (key: string) => (storage.has(key) ? (storage.get(key) as string) : null),
      setItem: (key: string, value: string) => storage.set(key, value),
      removeItem: (key: string) => storage.delete(key),
    };
    const api = fakeTurnApi({
      [conversationReadPathFor('convo-1')]: [{ kind: 'ok', status: 200, body: { conversationId: 'convo-1', turns } }],
    });
    const turn = stubTurnStore({ api: api as never, storage: memory, navigationType: () => 'reload' });
    await turn.restore();
    return mount({ rows: [{ enabled: true }], turn });
  }

  function restoredTurn(overrides: Record<string, unknown>) {
    return { seq: 1, message: 'go', state: 'completed', reply: null, error: null, steps: [], stepsDropped: 0, ...overrides };
  }

  it('a stop caught before a model call renders its "Stopped by you at provider" bar', async () => {
    // Mutation (Rule 19): filter the `turns` getter to `kind === 'tool'` alone -> this goes red.
    const { host } = await mountRestored([
      restoredTurn({
        state: 'stopped',
        error: { seq: 1, code: 'TURN.STOPPED', reason: 'Stopped.' },
        steps: [turnStep({ kind: 'model', name: 'provider', status: 'stopped' })],
      }),
    ]);
    const bars = host.querySelectorAll('.ocu-tool-call-card-stopped');
    expect(bars).toHaveLength(1);
    expect(bars[0].textContent?.trim()).toBe('Stopped by you at provider');
    // AC7 (Story 4.6): a stop is never an error -- no banner renders alongside the halted card.
    expect(host.querySelector('.ocu-panel-error-banner')).toBeNull();
  });

  it('a failed turn renders the error banner naming the step at error.seq and its reason', async () => {
    const { host } = await mountRestored([
      restoredTurn({
        state: 'failed',
        error: { seq: 2, code: 'TOOL.UNAVAILABLE', reason: 'The tool is unavailable.' },
        steps: [turnStep({ seq: 2, status: 'error', target: 'USER', reason: 'The tool is unavailable.' })],
      }),
    ]);
    const banner = host.querySelector('.ocu-panel-error-banner') as HTMLElement;
    expect(banner).not.toBeNull();
    expect(banner.getAttribute('role')).toBe('alert');
    expect(banner.textContent?.trim()).toBe('The turn stopped at shell.namespaces.read USER: The tool is unavailable.');
    // AC7 (Story 4.6): the failed turn carries no reply, so no reply block renders beside the banner.
    expect(host.querySelector('.ocu-panel-message-agent-text')).toBeNull();
  });

  // AC7 (Story 4.6), pinning the surface half of `turn.test.mjs`'s `turnErrorBanner` invariant:
  // a completed turn's reply and a failed turn's error banner never both render for one turn.
  //
  // The failed turn below CARRIES a reply, which is the state the invariant is about and a state
  // the wire really produces: the live turn view nulls a non-completed turn's reply server-side
  // (`Kernel/State/Turn.cls`), but the RESTORED view emits whatever the row stored
  // (`Kernel/State/Entry.cls`) and `Kernel/Agent/Job.cls` records the loop's reply alongside a
  // `failed` state -- so a reload can hand the panel both. A fixture with `reply: null` would
  // make the second assertion unfalsifiable, since the template's own `@if` would decide it.
  // Mutations (Rule 19): make `turnErrorBanner` answer the banner for `state === 'completed'` too
  // -> the first pair reddens; drop the `errorBanner === null` guard on `reply` in the `turns`
  // getter -> the last assertion reddens, finding the reply block beside the banner.
  it('a reply and an error banner never both render for one turn', async () => {
    const { host: completedHost } = await mountRestored([restoredTurn({ state: 'completed', reply: 'Here is what I found.' })]);
    expect(completedHost.querySelector('.ocu-panel-message-agent-text')).not.toBeNull();
    expect(completedHost.querySelector('.ocu-panel-error-banner')).toBeNull();

    const { host: failedHost } = await mountRestored([
      restoredTurn({
        state: 'failed',
        reply: 'A partial answer the loop had already produced.',
        error: { seq: 1, code: 'TOOL.UNAVAILABLE', reason: 'The tool is unavailable.' },
        steps: [turnStep({ seq: 1, status: 'error', target: 'USER', reason: 'The tool is unavailable.' })],
      }),
    ]);
    expect(failedHost.querySelector('.ocu-panel-error-banner')).not.toBeNull();
    expect(failedHost.querySelector('.ocu-panel-message-agent-text')).toBeNull();
  });

  // Story 4.8 AC7 (DW-1053) at the surface the AC names. `turn.test.mjs` pins the pure function
  // with both templates handed to it; only this decides that the panel hands it the no-step one.
  //
  // Mutation (Rule 19): pass `STRINGS.agentTurnStoppedBanner` as `turnErrorBanner`'s third
  // argument in `panel.ts` -> both legs redden, rendering "The turn stopped at : ...".
  it('Story 4.8: a failed turn whose error names no step renders the no-step wording, never "at :"', async () => {
    // errorSeq 0 -- the job-level refusal, which no step can carry.
    const { host: jobLevelHost } = await mountRestored([
      restoredTurn({
        state: 'failed',
        reply: null,
        error: { seq: 0, code: 'TURN.UNAVAILABLE', reason: 'The turn could not be started.' },
        steps: [turnStep({ seq: 1, status: 'error', target: 'USER', reason: 'The turn could not be started.' })],
      }),
    ]);
    const jobLevel = jobLevelHost.querySelector('.ocu-panel-error-banner') as HTMLElement;
    expect(jobLevel).not.toBeNull();
    expect(jobLevel.textContent?.trim()).toBe('The turn stopped: The turn could not be started.');

    // A seq past MAXSTEPS -- the seq Step.GuardedAppend answers for a row it did not store.
    const { host: pastCapHost } = await mountRestored([
      restoredTurn({
        state: 'failed',
        reply: null,
        error: { seq: 4096, code: 'PROVIDER.TIMEOUT', reason: 'The provider did not answer within the time this instance allows' },
        steps: [turnStep({ seq: 1, status: 'error', target: 'USER', reason: 'no' })],
      }),
    ]);
    const pastCap = pastCapHost.querySelector('.ocu-panel-error-banner') as HTMLElement;
    expect(pastCap).not.toBeNull();
    expect(pastCap.textContent).not.toContain('at :');
  });

  it('an expanded read card shows the rows-returned and rows-sent line', async () => {
    const { host, fixture } = await mountRestored([
      restoredTurn({ reply: 'ok', steps: [turnStep({ result: { rowsReturned: 5, rowsSent: 3, truncated: true } })] }),
    ]);
    expect(host.querySelector('.ocu-tool-call-rows')).toBeNull();
    (host.querySelector('.ocu-tool-call-toggle') as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(host.querySelector('.ocu-tool-call-rows')?.textContent?.trim()).toBe('5 rows returned \u00b7 3 sent');
  });

  it('a step still running when its turn ended renders as failed, never as a running card', async () => {
    const { host } = await mountRestored([
      restoredTurn({
        state: 'abandoned',
        error: { seq: 1, code: 'TURN.ABANDONED.LEASE', reason: 'The turn was abandoned.' },
        steps: [turnStep({ status: 'running' })],
      }),
    ]);
    expect(host.querySelector('.ocu-tool-call-spinner')).toBeNull();
    expect(host.querySelector('.ocu-tool-call-toggle')?.getAttribute('aria-expanded')).toBe('false');
    expect(host.querySelector('.ocu-tool-call-status-word')?.textContent?.trim()).toBe(
      STRINGS.toolCallStatusFailed.split('<reason>').join('The turn was abandoned.')
    );
  });

  it('New conversation is aria-disabled and described by "Stop the turn first" while busy', async () => {
    const { schedule } = fakeTurnSchedule();
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
    });
    const turn = stubTurnStore({ api: api as never, schedule });
    const { host, fixture } = await mount({ rows: [{ enabled: true }], turn });
    const newConversation = host.querySelector('.ocu-panel-new-conversation') as HTMLButtonElement;
    expect(newConversation.hasAttribute('aria-disabled')).toBe(false);
    await typeDraft(host, fixture, 'go');
    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();
    expect(newConversation.getAttribute('aria-disabled')).toBe('true');
    const describedBy = newConversation.getAttribute('aria-describedby') as string;
    expect((host.querySelector(`#${describedBy}`) as HTMLElement).textContent).toBe(STRINGS.agentNewConversationLockedReason);
  });

  it('an Enter that commits an IME composition does not send', async () => {
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
    });
    const turn = stubTurnStore({ api: api as never });
    const { host, fixture } = await mount({ rows: [{ enabled: true }], turn });
    await typeDraft(host, fixture, 'nihon');
    const composer = host.querySelector('.ocu-panel-composer') as HTMLTextAreaElement;
    composer.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', isComposing: true, cancelable: true }));
    await turnSettle();
    expect(api.calls.some((c) => c.path === TURN_PATH || c.path === CONVERSATION_PATH)).toBe(false);
    expect(composer.value).toBe('nihon');
  });

  // --- Story 4.7: the agent's navigation announcement -------------------------------------------
  //
  // Mutations (Rule 19):
  // - drop `kind === 'announce'` from the `turns` getter's step filter -> the announcement
  //   assertions below find nothing.
  // - render an announce step regardless of its status -> the withdrawn-announcement assertion
  //   goes red, since a settled-`error` step would still show a paragraph.
  // - route `announceText` through `app-reply` instead of a plain `{{ }}` interpolation -> a
  //   step carrying HTML-looking text (AD-33: the entity id is model-supplied) would render as
  //   markup instead of literal text.

  it("renders an entity-bearing announce step as the agent's own published sentence, in plain text", async () => {
    const { host } = await mountRestored([
      restoredTurn({
        reply: 'Opened.',
        steps: [
          turnStep({ seq: 1, kind: 'tool', name: 'shell.screen.open', status: 'ok', target: 'permissions/users', text: '_SYSTEM' }),
          turnStep({ seq: 2, kind: 'announce', name: 'shell.screen.open', status: 'ok', target: 'permissions/users', text: '_SYSTEM' }),
        ],
      }),
    ]);
    // The original tool call (seq 1) still renders its own card; the announce step (seq 2)
    // never gets one -- it is a message, not a card.
    expect(host.querySelectorAll('.ocu-tool-call-card')).toHaveLength(1);
    const paragraphs = Array.from(host.querySelectorAll('p.ocu-panel-message-agent-text'));
    const announcement = paragraphs.find((el) => el.textContent?.includes('Users'));
    expect(announcement).not.toBeUndefined();
    // Built from the published template rather than retyped, so the assertion is pinned to
    // EXPERIENCE.md's own sentence (`strings.test.mjs`'s job) and not to a second copy of it.
    const expected = STRINGS.agentNavigationAnnouncement.split('<screen>').join('Users').split('<entity>').join('_SYSTEM');
    expect(announcement?.textContent?.trim()).toBe(expected);
  });

  it('renders the no-entity form when the announce step carries none', async () => {
    const { host } = await mountRestored([
      restoredTurn({
        reply: 'Opened.',
        steps: [turnStep({ seq: 1, kind: 'announce', name: 'shell.screen.open', status: 'ok', target: 'agent/switches', text: '' })],
      }),
    ]);
    const paragraphs = Array.from(host.querySelectorAll('p.ocu-panel-message-agent-text'));
    const announcement = paragraphs.find((el) => el.textContent?.includes('Switches'));
    const expected = STRINGS.agentNavigationAnnouncementNoEntity.split('<screen>').join('Switches');
    expect(announcement?.textContent?.trim()).toBe(expected);
  });

  it('renders nothing for an announce step settled error -- the withdrawal is a removal, not a replacement', async () => {
    const { host } = await mountRestored([
      restoredTurn({
        reply: 'Never mind.',
        steps: [
          turnStep({
            seq: 1,
            kind: 'announce',
            name: 'shell.screen.open',
            status: 'error',
            code: 'NAV.REFUSEDUNSAVED',
            target: 'permissions/users',
          }),
        ],
      }),
    ]);
    expect(host.querySelectorAll('p.ocu-panel-message-agent-text')).toHaveLength(0);
    expect(host.textContent).not.toContain('permissions/users');
  });

  it('an entity id that looks like markup renders as literal text (AD-33)', async () => {
    const { host } = await mountRestored([
      restoredTurn({
        reply: 'Opened.',
        steps: [
          turnStep({ seq: 1, kind: 'announce', name: 'shell.screen.open', status: 'ok', target: 'permissions/users', text: '<b>x</b>' }),
        ],
      }),
    ]);
    const paragraphs = Array.from(host.querySelectorAll('p.ocu-panel-message-agent-text'));
    const announcement = paragraphs.find((el) => el.textContent?.includes('<b>x</b>'));
    expect(announcement).not.toBeUndefined();
    expect(announcement?.querySelector('b')).toBeNull();
  });
});

function conversationReadPathFor(id: string): string {
  return `${CONVERSATION_PATH}/${id}`;
}

// --- Story 4.11: the context chip, its toggle and the paste warning ----------------------------
//
// Mutations (Rule 19):
// - drop `context` from `turn.ts:410`'s body (already Rule-19'd in `turn.test.mjs`) -> the
//   Integration-shaped tests below that inspect the posted body go red on a missing key.
// - gate the row segment on `share` alone, forgetting `context.secretFields` -> the secret-screen
//   test goes red on a `view` key appearing in the posted context.
// - skip the `PUT` in `setShare` and mirror only locally -> the refusal test goes red, since
//   nothing would need to revert.
// - return `false` for a `sk-` prefix in `looksLikeSecret` -> the warning test goes red on no
//   warning ever appearing; return `true` for `%Api.Mgmnt.v2` -> the non-trigger test goes red.

describe('Story 4.11: the context chip, its toggle and the paste warning', () => {
  const USERS_DESCRIPTOR = 'OcuPilot.Screen.Descriptor.UserList';
  const SECRET_SCREEN_URL = '/agent/definitions/edit';

  function userRows(names: string[]) {
    return names.map((name) => ({
      Name: name,
      FullName: '',
      Enabled: true,
      Type: '',
      Roles: [],
      ExpirationDate: '',
      Expired: false,
    }));
  }

  const chipEl = (host: HTMLElement): HTMLElement | null => host.querySelector('.ocu-context-chip');
  const chipText = (host: HTMLElement): string =>
    (chipEl(host)?.querySelector('.ocu-context-chip-text') as HTMLElement | null)?.textContent ?? '';

  it('composing Users, HSCUSTOM and 6 rows reproduces STRINGS.contextChipScreenSegment byte for byte', async () => {
    const agentContext = stubAgentContext({ share: true });
    await agentContext.load();
    const { host, fixture, screenStores } = await mount({
      rows: [{ enabled: true }],
      agentContext,
      url: '/permissions/users',
    });
    screenStores.for(USERS_DESCRIPTOR, []).applyTick(userRows(['a', 'b', 'c', 'd', 'e', 'f']), false, '', new Date());
    fixture.detectChanges();
    // No provider/host (both '' on this stub) and no glyph or pill (no secret fields, leavesInstance
    // null), so the composed sentence is the whole text -- the exact worked example the string pins.
    expect(chipText(host).trim()).toBe(STRINGS.contextChipScreenSegment);
  });

  it('List screen, remote provider: the chip carries the row count, provider and host, with the egress pill and its tooltip', async () => {
    const agentContext = stubAgentContext({
      share: true,
      contextRowCap: 200,
      provider: 'Anthropic',
      endpointHost: 'api.anthropic.com',
      leavesInstance: true,
    });
    await agentContext.load();
    const { host, fixture, screenStores } = await mount({
      rows: [{ enabled: true }],
      agentContext,
      url: '/permissions/users',
    });
    screenStores.for(USERS_DESCRIPTOR, []).applyTick(userRows(['a', 'b', 'c', 'd', 'e', 'f']), false, '', new Date());
    fixture.detectChanges();

    const expectedSentence = STRINGS.contextChipScreenSegment + ' \u00b7 Anthropic \u00b7 api.anthropic.com';
    expect(chipText(host).startsWith(expectedSentence)).toBe(true);

    const pill = chipEl(host)?.querySelector('.ocu-context-chip-pill') as HTMLElement;
    expect(pill.textContent?.trim()).toBe(STRINGS.contextChipLeavesInstance);
    const expectedTooltip = STRINGS.contextChipSentToHost.split('<host>').join('api.anthropic.com');
    expect(pill.getAttribute('title')).toBe(expectedTooltip);
    expect(chipEl(host)?.querySelector('.ocu-context-chip-pill + .ocu-visually-hidden')?.textContent).toBe(
      expectedTooltip
    );
    expect(chipEl(host)?.querySelector('.ocu-context-chip-glyph')).toBeNull();
    expect((host.querySelector('.ocu-context-chip-switch') as HTMLInputElement).checked).toBe(true);
  });

  it('Local provider: leavesInstance false renders the same text with no pill', async () => {
    const agentContext = stubAgentContext({
      share: true,
      provider: 'OpenAI-compatible',
      endpointHost: '192.168.1.10',
      leavesInstance: false,
    });
    await agentContext.load();
    const { host, fixture, screenStores } = await mount({
      rows: [{ enabled: true }],
      agentContext,
      url: '/permissions/users',
    });
    screenStores.for(USERS_DESCRIPTOR, []).applyTick(userRows(['a', 'b']), false, '', new Date());
    fixture.detectChanges();
    expect(chipText(host)).toContain('192.168.1.10');
    expect(chipEl(host)?.querySelector('.ocu-context-chip-pill')).toBeNull();
  });

  it('Secret-typed screen: the key glyph carries its accessible name; no row segment; the posted context carries no view', async () => {
    const agentContext = stubAgentContext({ share: true, contextRowCap: 200 });
    await agentContext.load();
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
    });
    const turn = stubTurnStore({ api: api as never });
    const { host, fixture } = await mount({
      rows: [{ enabled: true }],
      agentContext,
      turn,
      url: SECRET_SCREEN_URL,
    });

    const chip = chipEl(host) as HTMLElement;
    expect(chip.querySelector('.ocu-context-chip-glyph')).not.toBeNull();
    expect(chip.querySelector('.ocu-context-chip-glyph + .ocu-visually-hidden')?.textContent).toBe(
      STRINGS.agentContextChipSecretGlyph
    );
    expect(chipText(host)).not.toContain('rows');

    await typeDraft(host, fixture, 'what fields does this form have');
    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    const body = JSON.parse(api.calls.find((c) => c.path === TURN_PATH)?.body ?? '{}') as {
      context?: { route: string; view?: unknown };
    };
    expect(body.context?.route).toBe('agent/definitions/edit');
    expect(body.context && 'view' in body.context).toBe(false);
  });

  it('Toggle off: the chip reads exactly the sharing-off sentence, and the next Send posts no context', async () => {
    const agentContext = stubAgentContext({
      share: true,
      provider: 'Anthropic',
      endpointHost: 'api.anthropic.com',
      leavesInstance: true,
    });
    await agentContext.load();
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
    });
    const turn = stubTurnStore({ api: api as never });
    const { host, fixture } = await mount({ rows: [{ enabled: true }], agentContext, turn, url: '/permissions/users' });

    const toggle = host.querySelector('.ocu-context-chip-switch') as HTMLInputElement;
    expect(toggle.checked).toBe(true);
    toggle.checked = false;
    toggle.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    // The mirror is optimistic: the sentence is off before the PUT settles.
    expect(chipText(host).trim()).toBe(STRINGS.contextChipSharingOff);
    expect(chipEl(host)?.querySelector('.ocu-context-chip-pill')).toBeNull();
    await turnSettle();
    fixture.detectChanges();
    expect(agentContext.share()).toBe(false);

    await typeDraft(host, fixture, 'anything');
    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    const body = JSON.parse(api.calls.find((c) => c.path === TURN_PATH)?.body ?? '{}') as Record<string, unknown>;
    expect('context' in body).toBe(false);
  });

  it('a refused PUT reverts the mirror, and the chip re-reads the server\'s own value', async () => {
    const calls: { path: string; method: string }[] = [];
    const api = {
      requestJson: async (path: string, init: { method?: string } = {}) => {
        const method = init.method ?? 'GET';
        calls.push({ path, method });
        if (method === 'PUT') return { kind: 'error' as const, status: 403, code: 'AUTH.NOPRIVILEGE', reason: 'no', detail: null };
        return {
          kind: 'ok' as const,
          status: 200,
          body: { share: true, shareDefault: true, userChoice: null, contextRowCap: 200, provider: '', endpointHost: '', leavesInstance: null },
        };
      },
    };
    const agentContext = new AgentContext({ api: api as never });
    await agentContext.load();
    const { host, fixture } = await mount({ rows: [{ enabled: true }], agentContext, url: '/permissions/users' });

    const toggle = host.querySelector('.ocu-context-chip-switch') as HTMLInputElement;
    toggle.checked = false;
    toggle.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    await turnSettle();
    fixture.detectChanges();
    expect(agentContext.share()).toBe(true);
    expect((host.querySelector('.ocu-context-chip-switch') as HTMLInputElement).checked).toBe(true);
  });

  it('View changes: a filter narrowing the view changes the chip\'s row count and the next Send\'s posted rows together', async () => {
    const agentContext = stubAgentContext({ share: true, contextRowCap: 200 });
    await agentContext.load();
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
    });
    const turn = stubTurnStore({ api: api as never });
    const { host, fixture, screenStores } = await mount({
      rows: [{ enabled: true }],
      agentContext,
      turn,
      url: '/permissions/users',
    });
    const store = screenStores.for(USERS_DESCRIPTOR, []);
    store.applyTick(userRows(['keep-1', 'keep-2', 'skip-1', 'skip-2', 'skip-3', 'skip-4']), false, '', new Date());
    fixture.detectChanges();
    expect(chipText(host)).toContain('6 rows');

    store.setFilter('keep');
    fixture.detectChanges();
    expect(chipText(host)).toContain('2 rows');

    await typeDraft(host, fixture, 'who are the kept users');
    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    const body = JSON.parse(api.calls.find((c) => c.path === TURN_PATH)?.body ?? '{}') as {
      context: { view: { rows: unknown[]; rowsAvailable: number } };
    };
    expect(body.context.view.rows).toHaveLength(2);
    expect(body.context.view.rowsAvailable).toBe(2);
  });

  it('Cap below the view: the chip reads the capped count, and the posted rows are capped with the full rowsAvailable', async () => {
    const agentContext = stubAgentContext({ share: true, contextRowCap: 1 });
    await agentContext.load();
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
    });
    const turn = stubTurnStore({ api: api as never });
    const { host, fixture, screenStores } = await mount({
      rows: [{ enabled: true }],
      agentContext,
      turn,
      url: '/permissions/users',
    });
    screenStores.for(USERS_DESCRIPTOR, []).applyTick(userRows(['a', 'b', 'c', 'd', 'e', 'f']), false, '', new Date());
    fixture.detectChanges();
    expect(chipText(host)).toContain('1 rows');

    await typeDraft(host, fixture, 'who is the first user');
    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    const body = JSON.parse(api.calls.find((c) => c.path === TURN_PATH)?.body ?? '{}') as {
      context: { view: { rows: unknown[]; rowsAvailable: number } };
    };
    expect(body.context.view.rows).toHaveLength(1);
    expect(body.context.view.rowsAvailable).toBe(6);
  });

  it('Cap follows agent-switch: a raised contextRowCap moves the chip\'s row count and the next Send\'s posted rows without a reload', async () => {
    // Mutation (Rule 19): remove `agentContext.subscribe(() => this.bump())` from
    // `context-chip.ts`'s constructor -> this goes red on the post-raise `6 rows`, because a
    // re-resolved cap no longer repaints the mounted chip. What drives `load()` in the running
    // instance is the `agent-switch` bus event; that wiring is pinned at the store level by
    // `agent-context.test.mjs`'s AD-14 test and live by `context-chip.browser-spec.mjs`'s
    // "Cap follows agent-switch" leg -- this component test has no bus and cannot stand for it.
    let row: AgentContextInfo = { ...NO_CONTEXT_INFO, share: true, contextRowCap: 1 };
    const contextApi = {
      requestJson: async (path: string) => {
        if (path !== AGENT_CONTEXT_PATH) return { kind: 'error' as const, status: 404, code: null, reason: null, detail: null };
        return { kind: 'ok' as const, status: 200, body: row };
      },
    };
    const agentContext = new AgentContext({ api: contextApi as never });
    await agentContext.load();
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
    });
    const turn = stubTurnStore({ api: api as never });
    const { host, fixture, screenStores } = await mount({
      rows: [{ enabled: true }],
      agentContext,
      turn,
      url: '/permissions/users',
    });
    screenStores.for(USERS_DESCRIPTOR, []).applyTick(userRows(['a', 'b', 'c', 'd', 'e', 'f']), false, '', new Date());
    fixture.detectChanges();
    expect(chipText(host)).toContain('1 rows');

    // Raises the cap the way an operator's Switches change does: the store's next answer differs,
    // and the same `agent-switch` re-read `agent-context.test.mjs`'s AD-14 test pins at the store
    // level is what would drive `load()` here in the running instance.
    row = { ...row, contextRowCap: 200 };
    await agentContext.load();
    fixture.detectChanges();
    expect(chipText(host)).toContain('6 rows');

    await typeDraft(host, fixture, 'who are the users');
    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    const body = JSON.parse(api.calls.find((c) => c.path === TURN_PATH)?.body ?? '{}') as {
      context: { view: { rows: unknown[]; rowsAvailable: number } };
    };
    expect(body.context.view.rows).toHaveLength(6);
    expect(body.context.view.rowsAvailable).toBe(6);
  });

  it('Namespace unresolved: the chip is absent, and Send posts no context (avoids 422 TURN.CONTEXT.INVALID)', async () => {
    const agentContext = stubAgentContext({ share: true, provider: 'Anthropic', endpointHost: 'api.anthropic.com' });
    await agentContext.load();
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
    });
    const turn = stubTurnStore({ api: api as never });
    const { host, fixture } = await mount({
      rows: [{ enabled: true }],
      agentContext,
      turn,
      namespace: '',
      url: '/permissions/users',
    });
    expect(chipEl(host)).toBeNull();

    await typeDraft(host, fixture, 'hello');
    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    const body = JSON.parse(api.calls.find((c) => c.path === TURN_PATH)?.body ?? '{}') as Record<string, unknown>;
    expect('context' in body).toBe(false);
  });

  it('No enabled definition: the chip stays absent even once AgentContext itself has answered', async () => {
    const agentContext = stubAgentContext({ share: true });
    await agentContext.load();
    // `rows` defaults to `[]`, so `AgentStatus.configured()` is false -- the gate this proves,
    // distinct from the "store never answered" case every earlier test in this file exercises.
    const { host } = await mount({ agentContext, url: '/permissions/users' });
    expect(chipEl(host)).toBeNull();
  });

  it('the kill switch restrains the chip: .ocu-context-chip-restrained tracks Panel\'s killSwitch input', async () => {
    // Mutation (Rule 19): drop the `[class.ocu-context-chip-restrained]` binding from
    // `context-chip.ts`'s template -> the `true` case goes red.
    for (const killSwitch of [true, false]) {
      const agentContext = stubAgentContext({ share: true });
      await agentContext.load();
      const restraint = killSwitch
        ? { killSwitch: true, killSwitchAudience: 'everyone', killSwitchReason: 'Paused during the change freeze' }
        : {};
      const { host } = await mount({ rows: [{ enabled: true }], agentContext, restraint, url: '/permissions/users' });
      const chip = chipEl(host) as HTMLElement;
      expect(chip.classList.contains('ocu-context-chip-restrained'), String(killSwitch)).toBe(killSwitch);
    }
  });

  // --- The paste warning -----------------------------------------------------------------------

  it('a secret-looking draft raises the warning on Send; Send anyway sends it once and does not warn again; Edit refocuses without recording', async () => {
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
    });
    const turn = stubTurnStore({ api: api as never });
    const { host, fixture } = await mount({ rows: [{ enabled: true }], turn });
    const secret = 'sk-ant-api03-abcdefghijklmnopqrstuvwxyz';
    await typeDraft(host, fixture, secret);

    const send = () => (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    send();
    await turnSettle();
    fixture.detectChanges();

    expect(api.calls.some((c) => c.path === TURN_PATH)).toBe(false);
    const composer = host.querySelector('.ocu-panel-composer') as HTMLTextAreaElement;
    expect(composer.value).toBe(secret);
    const warning = host.querySelector('.ocu-panel-warning') as HTMLElement;
    expect(warning).not.toBeNull();
    expect(warning.getAttribute('role')).toBe('status');
    expect(warning.textContent).toContain(STRINGS.agentPanelSecretWarning);

    // Edit: hides the warning and returns focus to the composer -- recording nothing.
    (host.querySelector('.ocu-panel-warning-edit') as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(host.querySelector('.ocu-panel-warning')).toBeNull();
    expect(document.activeElement).toBe(composer);
    expect(composer.value).toBe(secret);

    // A further Send of the unchanged text warns again, since Edit recorded nothing.
    send();
    await turnSettle();
    fixture.detectChanges();
    expect(host.querySelector('.ocu-panel-warning')).not.toBeNull();
    expect(api.calls.some((c) => c.path === TURN_PATH)).toBe(false);

    // Send anyway: sends this exact text once, and clears the warning and the draft.
    (host.querySelector('.ocu-panel-warning-send') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();
    expect(host.querySelector('.ocu-panel-warning')).toBeNull();
    const turnCalls = api.calls.filter((c) => c.path === TURN_PATH);
    expect(turnCalls).toHaveLength(1);
    expect(JSON.parse(turnCalls[0].body ?? '{}').message).toBe(secret);
    expect(composer.value).toBe('');
  });

  it('a failed send does not forget an acknowledged secret, so an immediate retry does not warn again', async () => {
    // Mutation (Rule 19): restore `syncSecretRecord`'s old shape-only check (conversation id null,
    // no entries, not busy) with no transition guard -> this goes red, since the acknowledgment is
    // wiped by the failed send below and the retry re-raises the warning.
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'error', status: 500, code: 'INTERNAL', reason: 'boom', detail: null }],
    });
    const turn = stubTurnStore({ api: api as never });
    const { host, fixture } = await mount({ rows: [{ enabled: true }], turn });
    const secret = 'sk-ant-api03-abcdefghijklmnopqrstuvwxyz';
    await typeDraft(host, fixture, secret);

    const send = () => (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    send();
    await turnSettle();
    fixture.detectChanges();
    expect(host.querySelector('.ocu-panel-warning')).not.toBeNull();

    // Send anyway: records the acknowledgment and attempts the send, which fails on a
    // conversation-creation error -- the draft is kept, and the failure must not forget it.
    (host.querySelector('.ocu-panel-warning-send') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();
    expect(host.querySelector('.ocu-panel-warning')).toBeNull();
    const composer = host.querySelector('.ocu-panel-composer') as HTMLTextAreaElement;
    expect(composer.value).toBe(secret);
    expect(api.calls.some((c) => c.path === TURN_PATH)).toBe(false);

    // An immediate retry of the identical, still-acknowledged text must not re-raise the warning.
    send();
    await turnSettle();
    fixture.detectChanges();
    expect(host.querySelector('.ocu-panel-warning')).toBeNull();
  });

  it('a namespace resolving after the chip\'s other two answers brings the chip in, and moves its sentence', async () => {
    // `app.ts` issues `scope.load()`, `agentStatus.load()` and `agentContext.load()` unordered,
    // and a namespace change re-fetches in place without a `router.events`, so `Panel` and
    // `ContextChip` each subscribe to `onScopeChange`. Mutation (Rule 19): drop
    // `onScopeChange(this.scope, () => this.bump())` from `Panel`'s constructor -> the first
    // assertion below goes red; drop it from `ContextChip`'s -> the last one does.
    const agentContext = stubAgentContext({ share: true });
    await agentContext.load();
    const { host, fixture, scope } = await mount({
      rows: [{ enabled: true }],
      agentContext,
      namespace: '',
      url: '/permissions/users',
    });
    expect(chipEl(host)).toBeNull();

    scope.value = 'HSCUSTOM';
    scope.notify();
    fixture.detectChanges();
    expect(chipEl(host)).not.toBeNull();
    expect(chipText(host)).toContain('HSCUSTOM');

    scope.value = 'USER';
    scope.notify();
    fixture.detectChanges();
    expect(chipText(host)).toContain('USER');
  });

  it('a URL naming no built descriptor leaves the chip out, the same omission the payload makes', async () => {
    // Mutation (Rule 19): drop `screenForUrl(this.router.url) !== null` from
    // `contextChipVisible` -> this goes red, and the chip renders ', HSCUSTOM' -- a sentence with
    // no screen in it -- while `assembleScreenContext` posts nothing for the same URL.
    const agentContext = stubAgentContext({ share: true, provider: 'Anthropic' });
    await agentContext.load();
    const { host } = await mount({ rows: [{ enabled: true }], agentContext, url: '/not/a/screen' });
    expect(chipEl(host)).toBeNull();
  });

  it('sharing off colors the sentence restrained, and only the sentence', async () => {
    // DESIGN.md's `context-chip` "When off" state. Mutation (Rule 19): drop the
    // `ocu-context-chip-off` class from `context-chip.ts`'s off branch -> this goes red.
    const agentContext = stubAgentContext({ share: false });
    await agentContext.load();
    const { host } = await mount({ rows: [{ enabled: true }], agentContext, url: '/permissions/users' });
    const off = chipEl(host)?.querySelector('.ocu-context-chip-off') as HTMLElement | null;
    expect(off?.textContent).toBe(STRINGS.contextChipSharingOff);
    expect(chipEl(host)?.classList.contains('ocu-context-chip-restrained')).toBe(false);
  });

  it('New conversation forgets an acknowledged secret, so the same draft warns again in the fresh conversation', async () => {
    // The spec's review-pass item names sign-out and new-conversation as the explicit reset
    // paths. Mutation (Rule 19): drop `acknowledgedSecretText.set(null)` from
    // `onNewConversation()` -> this goes red, because the retry sends with no warning.
    // The acknowledged send has to fail, or a `'sent'` outcome would clear the record on its own
    // and there would be nothing left for New conversation to forget.
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [
        { kind: 'error', status: 500, code: 'INTERNAL', reason: 'boom', detail: null },
        { kind: 'ok', status: 201, body: { conversationId: 'convo-2' } },
      ],
    });
    const turn = stubTurnStore({ api: api as never });
    const { host, fixture } = await mount({ rows: [{ enabled: true }], turn });
    const secret = 'sk-ant-api03-abcdefghijklmnopqrstuvwxyz';
    await typeDraft(host, fixture, secret);
    const send = () => (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    send();
    await turnSettle();
    fixture.detectChanges();
    expect(host.querySelector('.ocu-panel-warning')).not.toBeNull();
    (host.querySelector('.ocu-panel-warning-send') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();
    expect(host.querySelector('.ocu-panel-warning')).toBeNull();

    (host.querySelector('.ocu-panel-new-conversation') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();
    send();
    await turnSettle();
    fixture.detectChanges();
    expect(host.querySelector('.ocu-panel-warning')).not.toBeNull();
  });

  it('the three non-triggers (a URL, a class name, a global reference) send without ever raising the warning', async () => {
    // Built from fragments so this fixture is not itself a literal off-origin URL
    // `ui/tools/client-lint.mjs`'s `no-off-origin-url` rule would refuse (AD-28, AD-47).
    const nonTriggerUrl = 'https:' + '//' + 'localhost:52774/csp/sys/UtilHome.csp';
    for (const text of [nonTriggerUrl, '%Api.Mgmnt.v2', '^OcuPilotTurnSlot("_SYSTEM")']) {
      const api = fakeTurnApi({
        [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
        [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
      });
      const turn = stubTurnStore({ api: api as never });
      const { host, fixture } = await mount({ rows: [{ enabled: true }], turn });
      await typeDraft(host, fixture, text);
      (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
      await turnSettle();
      fixture.detectChanges();
      expect(host.querySelector('.ocu-panel-warning'), text).toBeNull();
      expect(api.calls.some((c) => c.path === TURN_PATH), text).toBe(true);
    }
  });
});
