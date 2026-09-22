import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { describe, expect, it } from 'vitest';

import { AGENT_CONTEXT_PATH, AgentContext, NO_CONTEXT_INFO, type AgentContextInfo } from '../core/agent-context';
import { AgentStatus, type Restraint, formatKillSwitch } from '../core/agent-status';
import { NavigationService, UNGATED, type Verdict } from '../core/navigation';
import { PanelState } from '../core/panel-layout';
import { ScopeService } from '../core/scope';
import { Session } from '../core/session';
import { ScreenStores } from '../core/screen-store';
import { ShellState } from '../core/shell-state';
import { STRINGS } from '../core/strings';
import { SOURCES, SWITCHES_DESCRIPTOR, SuggestedView, type Source } from '../core/suggested-view';
import { formatChangeSentence } from '../core/toasts';
import { TokenStore } from '../core/token-store';
import {
  CONVERSATION_PATH,
  TURN_PATH,
  TurnStore,
  proposalCancelPath,
  proposalConfirmPath,
  turnProgressPath,
  turnStopPath,
} from '../core/turn';
import { stubAgentContext } from '../testing/agent-context';
import { stubAgentStatus } from '../testing/agent-status';
import { stubTurnStore } from '../testing/turn';
import { Panel } from './panel';
import { stubAccountPreferences } from '../testing/account-preferences';

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

/**
 * A real `Session` holding `userName`, which is the one fact the panel reads off it: the footer's
 * runs-as caption and the confirmed status line are both about the account a write would run as.
 * Its transport answers nothing and its timer never fires.
 */
function sessionNamed(userName: string): Session {
  const session = new Session({
    fetch: async () => ({ status: 503, text: async () => '{}' }),
    tokens: new TokenStore({ storage: memoryStorage(), navigationType: () => 'navigate' }),
    schedule: () => {},
  } as never);
  session.setUserName(userName);
  return session;
}

interface Mounted {
  readonly fixture: ComponentFixture<Panel>;
  readonly navigation: StubNavigation;
  readonly agentStatus: AgentStatus;
  readonly agentContext: AgentContext;
  readonly scope: StubScope;
  readonly screenStores: ScreenStores;
  readonly shell: ShellState;
  readonly suggested: SuggestedView;
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
    /** The area `ShellState` reports, which is what puts the panel on Home (Story 4.10). */
    area?: string;
    /** `SuggestedView`'s transport, for the suggested-view block (Story 4.10). */
    suggestedApi?: { requestJson: (path: string, init?: unknown) => Promise<unknown> };
    /**
     * Whether to settle the block before the first render. Defaults to true on Home; a case about
     * the in-flight gate passes false, because awaiting a read it is holding open would hang here.
     */
    settleSuggested?: boolean;
    /** The account the panel reads off `Session` for a card's footer captions (Story 5.2). */
    userName?: string;
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
    options.screenStores ?? new ScreenStores({ account: stubAccountPreferences() });
  const preferences = stubAccountPreferences();
  const shell = new ShellState({ account: preferences });
  if (options.area !== undefined) shell.setActiveArea(options.area);
  const panelState = options.panelState ?? new PanelState({ account: preferences, shell });
  const turn = options.turn ?? stubTurnStore();
  const suggested = new SuggestedView({
    api: (options.suggestedApi ?? {
      requestJson: async () => ({ kind: 'ok', status: 200, body: { rows: [] } }),
    }) as never,
    agentStatus,
    scope: scope as unknown as ScopeService,
  });
  // On Home the panel loads the block itself, asynchronously; settling the store first is what
  // makes the first render the answered one, so a DOM assertion is not racing a microtask.
  if (options.settleSuggested ?? options.area === 'home') await suggested.load();
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
      { provide: ShellState, useValue: shell },
      { provide: SuggestedView, useValue: suggested },
      { provide: Session, useValue: sessionNamed(options.userName ?? '_SYSTEM') },
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
    shell,
    suggested,
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

  /**
   * Integration AC (Rule 1), Story 5.6 / AD-15 / FR-22: the panel is the consumer of
   * `GET /agent/restraint`'s `writesMarked`, and what it produces is the reserved slot filled with
   * the published sentence and nothing beside it.
   *
   * mutation: render the banner outside `data-slot="not-marked"` (as a sibling of the slot div)
   * -> the slot-order assertion below goes red, because `.ocu-panel-banners > *` gains a member.
   * Second mutation: make `writesNotMarked` read `restraint().writesMarked` -> the banner is
   * absent and the first assertions go red.
   */
  it('AC: writesMarked false fills the reserved not-marked slot with the banner sentence alone', async () => {
    // One enabled definition, so the reminder banner is not in the way and the slot list below is
    // this story's banner beside the one slot Story 4.5 already reserved.
    const { host } = await mount({ rows: [{ enabled: true }], restraint: { writesMarked: false } });
    const body = host.querySelector('.ocu-panel-body') as HTMLElement;

    const slot = body.querySelector('[data-slot="not-marked"]') as HTMLElement;
    const banner = slot.querySelector('.ocu-panel-banner') as HTMLElement;
    expect(banner).not.toBeNull();
    expect(banner.classList.contains('ocu-banner-warning')).toBe(true);
    expect(banner.querySelector('.ocu-banner-message')?.textContent?.trim()).toBe(
      STRINGS.auditingOffBanner
    );
    // The sentence alone: the published link and action stay unrendered until Story 7.4.
    expect(slot.querySelector('a')).toBeNull();
    expect(slot.querySelector('button')).toBeNull();
    expect(slot.textContent).not.toContain(STRINGS.auditingConfigurationLink);
    expect(slot.textContent).not.toContain(STRINGS.auditingTurnOnAction);
    // Nothing anywhere says marking IS working, which is what makes a stale fact acceptable.
    expect(body.textContent).not.toContain('are being marked');

    // The slot order is unchanged: the banner is INSIDE the slot the panel already reserved.
    const slots = [...body.querySelectorAll('.ocu-panel-banners > *')].map(
      (node) => node.id || node.getAttribute('data-slot')
    );
    expect(slots).toEqual(['not-marked', 'lock']);
  });

  it('AC: an answered instance that is marking shows no banner in that slot', async () => {
    const { host } = await mount({ rows: [{ enabled: true }], restraint: { writesMarked: true } });
    const slot = host.querySelector('[data-slot="not-marked"]') as HTMLElement;
    expect(slot.querySelector('.ocu-panel-banner')).toBeNull();
    expect(slot.textContent?.trim()).toBe('');
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
                    reason: 'This account does not hold the privilege this request requires.',
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
    // Story 5.4, AC2: a privilege refusal resolves the <reason> slot with the pair that failed,
    // which is the privilege the user has to be granted; the generic sentence names none.
    expect(statusWord.textContent).toBe(
      STRINGS.toolCallStatusFailed.split('<reason>').join('%Admin_Secure:USE')
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
    const preferences = stubAccountPreferences();
    const panelState = new PanelState({ account: preferences, shell: new ShellState({ account: preferences }) });
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

// --- Story 4.10: Home's suggested view and the starter prompts ----------------------------------

/** An `ApiService`-shaped transport for `SuggestedView`, recording every path it was asked for. */
function fakeDatesApi(answer: unknown) {
  const calls: string[] = [];
  return {
    calls,
    requestJson: async (path: string) => {
      calls.push(path);
      return answer;
    },
  };
}

const DATES_OK = (rows: { date: string; count: number }[]) => ({ kind: 'ok', status: 200, body: { rows } });

const DATES_REFUSED = { kind: 'error', status: 403, code: 'AUTH.FORBIDDEN', reason: null, detail: null };

/** Home, an enabled definition, and the application-errors read answering `rows`. */
function mountOnHome(
  rows: { date: string; count: number }[],
  extra: { verdict?: Verdict; turn?: TurnStore; url?: string; restraint?: Partial<Restraint> } = {}
): Promise<Mounted> {
  return mount({
    rows: [{ enabled: true }],
    area: 'home',
    suggestedApi: fakeDatesApi(DATES_OK(rows)),
    ...extra,
  });
}

describe("Story 4.10: Home's suggested view and the starter prompts", () => {
  it('AC1: the block precedes the transcript, carries the published eyebrow, and puts each count in a <code>', async () => {
    // Mutation (Rule 19): move the `<section class="ocu-suggested">` below `.ocu-panel-transcript`
    // in `panel.ts` -> the DOM-order assertion goes red.
    const { host } = await mountOnHome([{ date: '2026-09-17', count: 3 }]);
    const order = [
      ...host.querySelectorAll('.ocu-panel-banners, .ocu-panel-chip-slot, .ocu-suggested, [role="log"], .ocu-panel-footer'),
    ].map((node) => node.className);
    expect(order).toEqual([
      'ocu-panel-banners',
      'ocu-panel-chip-slot',
      'ocu-suggested',
      'ocu-panel-transcript',
      'ocu-panel-footer',
    ]);

    const block = host.querySelector('.ocu-suggested') as HTMLElement;
    const eyebrow = block.querySelector('.ocu-suggested-eyebrow') as HTMLElement;
    expect(eyebrow.textContent?.trim()).toBe(STRINGS.homeSuggestedView);
    expect(block.getAttribute('aria-labelledby')).toBe(eyebrow.id);

    const rows = [...block.querySelectorAll('.ocu-suggested-line')];
    expect(rows).toHaveLength(2);
    const errors = rows[1];
    const code = errors.querySelector('code') as HTMLElement;
    expect(code.textContent?.trim()).toBe('3');
    expect(errors.querySelector('.ocu-suggested-prompt')?.textContent?.trim()).toBe(
      'Application errors in HSCUSTOM: 3 on 2026-09-17'
    );
    // The agent-status line is the sentence the footer renders, so the two cannot disagree.
    expect(rows[0].querySelector('.ocu-suggested-prompt')?.textContent?.trim()).toBe(STRINGS.statusReadOnlyOff);
    expect(rows[0].querySelector('code')).toBeNull();
  });

  it('AC1: the block renders on Home only, and only with an enabled definition', async () => {
    const away = await mount({ rows: [{ enabled: true }], area: 'permissions' });
    expect(away.host.querySelector('.ocu-suggested-eyebrow')).toBeNull();

    const unconfigured = await mount({ rows: [], area: 'home' });
    expect(unconfigured.host.querySelector('.ocu-suggested-eyebrow')).toBeNull();

    const unanswered = await mount({ rows: [{ enabled: true }], area: 'home', answered: false });
    expect(unanswered.host.querySelector('.ocu-suggested-eyebrow')).toBeNull();
  });

  it('AC2: a refused read renders no line at all -- no zero, no skeleton row', async () => {
    const { host } = await mount({
      rows: [{ enabled: true }],
      area: 'home',
      suggestedApi: fakeDatesApi(DATES_REFUSED),
    });
    const rows = [...host.querySelectorAll('.ocu-suggested-line')];
    // The agent-status line, then the three prompts the vacuous all-zero test selects.
    expect(rows[0].querySelector('.ocu-suggested-prompt')?.textContent?.trim()).toBe(STRINGS.statusReadOnlyOff);
    expect(host.querySelector('.ocu-suggested')?.textContent).not.toContain('Application errors in');
    expect(host.querySelectorAll('.ocu-suggested code')).toHaveLength(0);
  });

  it('AC2: nothing renders while a read is in flight -- on Home, where the block would otherwise show', async () => {
    // Mutation (Rule 19): delete `&& this.suggested.answered()` from `suggestedVisible` -> the
    // before-release assertion goes red, because the block paints the eyebrow and the
    // agent-status line and then gains a second line when the read lands.
    //
    // This case must mount ON Home: off Home the `onHome` conjunct hides the block whatever the
    // read is doing, so the assertion would hold with the in-flight gate gone.
    let release = () => {};
    const gate = new Promise<void>((resolve) => {
      release = resolve;
    });
    let asked = 0;
    const suggestedApi = {
      requestJson: async () => {
        asked += 1;
        await gate;
        return DATES_OK([{ date: '2026-09-17', count: 1 }]);
      },
    };
    const { host, fixture, suggested } = await mount({
      rows: [{ enabled: true }],
      area: 'home',
      suggestedApi,
      settleSuggested: false,
    });
    expect(asked).toBe(1);
    expect(host.querySelector('.ocu-suggested-eyebrow')).toBeNull();
    expect(host.querySelectorAll('.ocu-suggested-line')).toHaveLength(0);

    // The store's own notification is the settle point; a fixed number of microtask hops would be
    // a guess about how many awaits `load()` takes.
    const settled = new Promise<void>((resolve) => {
      const stop = suggested.subscribe(() => {
        stop();
        resolve();
      });
    });
    release();
    await settled;
    fixture.detectChanges();
    expect(host.querySelector('.ocu-suggested-eyebrow')?.textContent?.trim()).toBe(STRINGS.homeSuggestedView);
    expect(host.querySelectorAll('.ocu-suggested-line')).toHaveLength(2);
  });

  it('AC3: a line has two distinct controls, and its text goes to the composer without starting a turn', async () => {
    // Mutation (Rule 19): wire the line's text button to `TurnStore.send` instead of
    // `PanelState.setDraft` -> the "no turn was started" assertion goes red.
    // Mutation (Rule 19): render the row as one button wrapping the `Open` label -> the
    // two-distinct-controls assertion goes red.
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
    });
    const turn = stubTurnStore({ api: api as never });
    const { host, fixture, panelState } = await mountOnHome([{ date: '2026-09-17', count: 3 }], { turn });

    const row = [...host.querySelectorAll('.ocu-suggested-line')][1] as HTMLElement;
    const text = row.querySelector('.ocu-suggested-prompt') as HTMLButtonElement;
    const open = row.querySelector('.ocu-suggested-open') as HTMLAnchorElement;
    expect(text.tagName).toBe('BUTTON');
    expect(open.tagName).toBe('A');
    expect(open).not.toBe(text);
    expect(text.contains(open)).toBe(false);
    expect(open.textContent?.trim().startsWith(STRINGS.homeSuggestedOpen)).toBe(true);

    const line = 'Application errors in HSCUSTOM: 3 on 2026-09-17';
    text.click();
    await turnSettle();
    fixture.detectChanges();
    expect(panelState.draft()).toBe(line);
    expect((host.querySelector('.ocu-panel-composer') as HTMLTextAreaElement).value).toBe(line);
    expect(document.activeElement).toBe(host.querySelector('.ocu-panel-composer'));
    expect(api.calls.some((c) => c.path === TURN_PATH || c.path === CONVERSATION_PATH)).toBe(false);
  });

  it("AC3: a line's Open navigates to that line's own screen, carrying the current query", async () => {
    const { host, fixture } = await mountOnHome([{ date: '2026-09-17', count: 3 }], { url: '/?ns=USER' });
    const open = [...host.querySelectorAll('.ocu-suggested-open')][1] as HTMLAnchorElement;
    expect(open.getAttribute('href')).toBe('logs/errors?ns=USER');
    open.click();
    await fixture.whenStable();
    expect(TestBed.inject(Router).url).toBe('/logs/errors?ns=USER');
  });

  it('AC4: a refused Open stays listed, focusable and aria-disabled, and names the pair that failed', async () => {
    // Mutation (Rule 19): replace `[attr.aria-disabled]` with the native `disabled` attribute ->
    // the focusable-and-described assertions go red.
    const { host, fixture } = await mountOnHome([{ date: '2026-09-17', count: 3 }], { verdict: DENIED });
    const open = [...host.querySelectorAll('.ocu-suggested-open')][1] as HTMLAnchorElement;
    expect(open).not.toBeNull();
    expect(open.getAttribute('aria-disabled')).toBe('true');
    expect(open.hasAttribute('disabled')).toBe(false);
    expect(open.hasAttribute('tabindex')).toBe(false);
    expect(open.hasAttribute('href')).toBe(true);
    const reason = host.querySelector(`#${open.getAttribute('aria-describedby')}`) as HTMLElement;
    expect(reason.textContent?.trim()).toBe('Requires OcuPilotAdmin:USE');

    // The matrix names the agent-status line's own Open (target Switches, OcuPilotAdmin:USE), so
    // the row the matrix is about is asserted as well as the one below it.
    const statusOpen = [...host.querySelectorAll('.ocu-suggested-open')][0] as HTMLAnchorElement;
    expect(statusOpen.getAttribute('aria-disabled')).toBe('true');
    expect(statusOpen.hasAttribute('disabled')).toBe(false);
    expect(statusOpen.hasAttribute('href')).toBe(true);
    expect(
      host.querySelector(`#${statusOpen.getAttribute('aria-describedby')}`)?.textContent?.trim()
    ).toBe('Requires OcuPilotAdmin:USE');

    const before = TestBed.inject(Router).url;
    open.click();
    await fixture.whenStable();
    expect(TestBed.inject(Router).url).toBe(before);

    // A modifier click on a refused control is refused too. The observable is the cancellation,
    // not the router: the anchor keeps a real href, and a handler that bailed on the modifiers
    // before the gate would leave the default action standing -- which opens the refused screen in
    // a new tab, something jsdom cannot show by moving the router.
    const modified = new MouseEvent('click', { bubbles: true, cancelable: true, metaKey: true });
    open.dispatchEvent(modified);
    await fixture.whenStable();
    expect(modified.defaultPrevented).toBe(true);
    expect(TestBed.inject(Router).url).toBe(before);
    // The converse -- a modifier click on a REACHABLE line is left to the browser -- is not
    // asserted here: dispatching it makes jsdom log an unimplemented cross-document navigation,
    // which is noise in every later run. The modifier bail is the second branch of the same
    // handler, and the AC3 navigation case above pins the unmodified path.
  });

  it("AC3: the agent-status line's Open resolves to Switches, so its declared descriptor is real", async () => {
    // Mutation (Rule 19): respell `SWITCHES_DESCRIPTOR` -> `screenForDescriptor` answers null, the
    // href empties and this goes red. Without it a descriptor rename leaves that line's Open inert
    // with every other test still green, because they all assert the application-errors row.
    const { host } = await mountOnHome([{ date: '2026-09-17', count: 3 }], { url: '/?ns=USER' });
    const statusOpen = [...host.querySelectorAll('.ocu-suggested-open')][0] as HTMLAnchorElement;
    expect(statusOpen.getAttribute('href')).toBe('agent/switches?ns=USER');
    expect(SWITCHES_DESCRIPTOR).toBe('OcuPilot.Screen.Descriptor.AgentSwitches');
  });

  it('AC5: a fourth source appended to the declared array renders a fourth row, through the block itself', async () => {
    // Mutation (Rule 19): replace the template's `@for (row of suggestedRows)` with two explicit
    // rows for the two known keys, or cap `suggestedRows` with `.slice(0, 2)` -> this goes red.
    // `tools/suggested-view.test.mjs` pins the same AC at the store; this is the render path the
    // AC actually names, including `suggestedRow`'s descriptor lookup, which a new source can fail.
    // `readonly Source[]` is a compile-time guarantee about production code, not about a test that
    // stands in for Story 6.13's append; the `finally` below is what keeps the array as it was.
    const sources = SOURCES as Source[];
    sources.push({
      key: 'alerts-log',
      read: (_view, state) => {
        state.answer = {
          key: 'alerts-log',
          counted: true,
          text: 'New alerts.log entries: 2',
          count: 2,
          label: 'New alerts.log entries: ',
          tail: '',
          descriptor: SWITCHES_DESCRIPTOR,
        };
        return Promise.resolve();
      },
    });
    try {
      const { host } = await mountOnHome([{ date: '2026-09-17', count: 3 }]);
      const rows = [...host.querySelectorAll('.ocu-suggested-line')];
      expect(rows).toHaveLength(3);
      expect(rows[2].querySelector('.ocu-suggested-prompt')?.textContent?.trim()).toBe(
        'New alerts.log entries: 2'
      );
      expect(rows[2].querySelector('code')?.textContent?.trim()).toBe('2');
      expect(rows[2].querySelector('.ocu-suggested-open')?.getAttribute('href')).toContain('agent/switches');
    } finally {
      sources.pop();
    }
  });

  it('AC6: every counted line at zero renders the three published prompts, and the agent-status line stays', async () => {
    const { host, panelState } = await mountOnHome([]);
    const block = host.querySelector('.ocu-suggested') as HTMLElement;
    expect(block.querySelector('.ocu-suggested-eyebrow')?.textContent?.trim()).toBe(STRINGS.homeSuggestedView);
    // The send glyph is `aria-hidden` and contributes no word, so the row's own name is the text
    // span alone -- which is what a starter prompt places in the composer.
    const labels = [...block.querySelectorAll('.ocu-suggested-prompt, .ocu-suggested-starter > span:first-child')].map(
      (node) => node.textContent?.trim()
    );
    expect(labels).toEqual([
      STRINGS.statusReadOnlyOff,
      STRINGS.homeStarterPromptExplainScreen,
      STRINGS.homeStarterPromptExplainLog,
      STRINGS.homeStarterPromptChangeOneThing,
    ]);
    expect(block.querySelectorAll('code')).toHaveLength(0);
    expect(block.querySelectorAll('.ocu-suggested-starter')).toHaveLength(3);

    // The same gesture as a line's own text.
    (block.querySelectorAll('.ocu-suggested-starter')[1] as HTMLButtonElement).click();
    expect(panelState.draft()).toBe(STRINGS.homeStarterPromptExplainLog);
  });

  it('AC7: a restored, empty transcript reads greeting, three prompts, then the selection hint', async () => {
    // Mutation (Rule 19): swap the greeting and the selection hint in `panel.ts` -> the DOM-order
    // assertion goes red.
    const turn = stubTurnStore();
    await turn.restore();
    const { host } = await mountOnHome([{ date: '2026-09-17', count: 3 }], { turn });
    const log = host.querySelector('[role="log"]') as HTMLElement;
    const parts = [
      ...log.querySelectorAll('.ocu-panel-greeting, .ocu-suggested-starter > span:first-child, .ocu-panel-selection-hint'),
    ].map((node) => node.textContent?.trim());
    expect(parts).toEqual([
      STRINGS.agentIdleGreeting,
      STRINGS.homeStarterPromptExplainScreen,
      STRINGS.homeStarterPromptExplainLog,
      STRINGS.homeStarterPromptChangeOneThing,
      STRINGS.agentIdleSelectionHint,
    ]);
  });

  it('AC6 with AC7: the fresh-container state offers exactly one set of three starter prompts', async () => {
    // Mutation (Rule 19): drop the `transcriptEmpty` guard from `suggestedPrompts` -> this goes
    // red with six prompt rows.
    //
    // Home, an enabled definition, a restored empty transcript and a clean log all hold at once on
    // a fresh container -- EXPERIENCE.md's UJ-2 calls that state "the suggested view offering the
    // three starter prompts", singular -- and both blocks would otherwise render the same three.
    // Its Home row reads "its suggested view or, when nothing needs attention, three starter
    // prompts", and its panel Idle row publishes the greeting's own order, "over the screen's
    // three starter prompts, and beneath them the hint", so the greeting keeps them.
    const turn = stubTurnStore();
    await turn.restore();
    const { host } = await mountOnHome([], { turn });

    const block = host.querySelector('.ocu-suggested') as HTMLElement;
    const log = host.querySelector('[role="log"]') as HTMLElement;
    expect(host.querySelectorAll('.ocu-suggested-starter')).toHaveLength(3);
    expect(block.querySelectorAll('.ocu-suggested-starter')).toHaveLength(0);
    expect(log.querySelectorAll('.ocu-suggested-starter')).toHaveLength(3);

    // The block still renders, and still carries the uncounted agent-status line (AC2).
    expect(block.querySelector('.ocu-suggested-eyebrow')?.textContent?.trim()).toBe(STRINGS.homeSuggestedView);
    expect(
      [...block.querySelectorAll('.ocu-suggested-prompt')].map((node) => node.textContent?.trim())
    ).toEqual([STRINGS.statusReadOnlyOff]);

    // And the greeting's published order survives it.
    expect(
      [...log.querySelectorAll('.ocu-panel-greeting, .ocu-suggested-starter > span:first-child, .ocu-panel-selection-hint')].map(
        (node) => node.textContent?.trim()
      )
    ).toEqual([
      STRINGS.agentIdleGreeting,
      STRINGS.homeStarterPromptExplainScreen,
      STRINGS.homeStarterPromptExplainLog,
      STRINGS.homeStarterPromptChangeOneThing,
      STRINGS.agentIdleSelectionHint,
    ]);
  });

  it('a suggestion is refused while the composer is unavailable, as every other draft write is', async () => {
    // Mutation (Rule 19): drop the `composerUnavailable` guard from `onSuggestion` -> this goes
    // red. With the kill switch on the block still renders -- its agent-status line is that
    // state's sentence -- and the composer is readonly, so the draft could not be sent.
    const { host, panelState } = await mountOnHome([{ date: '2026-09-17', count: 3 }], {
      restraint: { killSwitch: true, killSwitchAudience: 'everyone', killSwitchReason: 'Change freeze' },
    });
    const composer = host.querySelector('.ocu-panel-composer') as HTMLTextAreaElement;
    expect(composer.hasAttribute('readonly')).toBe(true);
    const rows = [...host.querySelectorAll('.ocu-suggested-line')];
    expect(rows.length).toBeGreaterThan(0);
    (rows[0].querySelector('.ocu-suggested-prompt') as HTMLButtonElement).click();
    expect(panelState.draft()).toBe('');
    expect(composer.value).toBe('');
  });

  it('AC7: the greeting is withheld until the transcript is restored, and once a turn exists', async () => {
    const unrestored = stubTurnStore();
    const before = await mount({ rows: [{ enabled: true }], area: 'home', turn: unrestored });
    expect(before.host.querySelector('.ocu-panel-greeting')).toBeNull();

    const restored = stubTurnStore();
    await restored.restore();
    const empty = await mount({ rows: [{ enabled: true }], area: 'home', turn: restored });
    expect(empty.host.querySelector('.ocu-panel-greeting')?.textContent?.trim()).toBe(STRINGS.agentIdleGreeting);
  });

  it('the greeting is withheld until the agent status has answered, as its published trigger requires', async () => {
    // Mutation (Rule 19): gate the greeting on `transcriptEmpty` instead of `greetingVisible` ->
    // this goes red. The transcript's `@else` branch is reached whenever the panel is not
    // known-unconfigured, which includes the window before the status answers, so the greeting
    // would render before anything knows whether a definition is enabled.
    const turn = stubTurnStore();
    await turn.restore();
    const unanswered = await mount({ rows: [{ enabled: true }], area: 'home', turn, answered: false });
    expect(unanswered.host.querySelector('.ocu-panel-greeting')).toBeNull();
    expect(unanswered.host.querySelector('.ocu-panel-selection-hint')).toBeNull();

    const answered = await mount({ rows: [{ enabled: true }], area: 'home', turn });
    expect(answered.host.querySelector('.ocu-panel-greeting')?.textContent?.trim()).toBe(
      STRINGS.agentIdleGreeting
    );
  });

  it('the greeting renders on every route, not only on Home -- the published prompts are screen-agnostic', async () => {
    const turn = stubTurnStore();
    await turn.restore();
    const { host } = await mount({ rows: [{ enabled: true }], area: 'permissions', turn });
    expect(host.querySelector('.ocu-suggested-eyebrow')).toBeNull();
    expect(host.querySelector('.ocu-panel-greeting')?.textContent?.trim()).toBe(STRINGS.agentIdleGreeting);
  });

  it('the block reads once per Home visit per namespace, and not at all before a namespace resolves', async () => {
    // Mutation (Rule 19): drop the `suggestedLoadedFor === namespace` guard from `syncSuggested`
    // -> the "one call" assertions go red, because every store's own notification reads again.
    const api = fakeDatesApi(DATES_OK([{ date: '2026-09-17', count: 1 }]));
    const { fixture, scope, shell } = await mount({
      rows: [{ enabled: true }],
      area: 'home',
      namespace: '',
      suggestedApi: api,
    });
    expect(api.calls).toEqual([]);

    scope.value = 'HSCUSTOM';
    scope.notify();
    await Promise.resolve();
    fixture.detectChanges();
    expect(api.calls).toEqual(['/api/ocupilot/logs/errors/dates?namespace=HSCUSTOM']);

    // Another store answering on the same visit reads nothing more.
    shell.setActiveArea('home');
    scope.notify();
    await Promise.resolve();
    expect(api.calls).toHaveLength(1);

    // Leaving and returning is a new visit.
    shell.setActiveArea('permissions');
    shell.setActiveArea('home');
    await Promise.resolve();
    expect(api.calls).toHaveLength(2);

    // A switch is a different question (AD-44).
    scope.value = 'USER';
    scope.notify();
    await Promise.resolve();
    expect(api.calls[2]).toBe('/api/ocupilot/logs/errors/dates?namespace=USER');
    expect(api.calls).toHaveLength(3);
  });

  it('a namespace switch drops the previous namespace\'s answer rather than rendering it against the new scope', async () => {
    // Mutation (Rule 19): drop the `if (previous !== null) this.suggested.reset()` from
    // `syncSuggested` -> this goes red, because the block keeps rendering the HSCUSTOM sentence
    // while the tab is scoped to USER.
    let release = () => {};
    const gate = new Promise<void>((resolve) => {
      release = resolve;
    });
    let call = 0;
    const suggestedApi = {
      requestJson: async (path: string) => {
        call += 1;
        if (call > 1) await gate;
        return DATES_OK([{ date: '2026-09-17', count: path.endsWith('USER') ? 7 : 3 }]);
      },
    };
    const { host, fixture, scope, suggested } = await mount({
      rows: [{ enabled: true }],
      area: 'home',
      suggestedApi,
    });
    expect(host.querySelector('.ocu-suggested')?.textContent).toContain(
      'Application errors in HSCUSTOM: 3 on 2026-09-17'
    );

    scope.value = 'USER';
    scope.notify();
    fixture.detectChanges();
    // The block is withheld whole rather than showing the departed namespace's count.
    expect(host.querySelector('.ocu-suggested-eyebrow')).toBeNull();
    expect(host.querySelector('.ocu-suggested')?.textContent).not.toContain('HSCUSTOM');

    const settled = new Promise<void>((resolve) => {
      const stop = suggested.subscribe(() => {
        stop();
        resolve();
      });
    });
    release();
    await settled;
    fixture.detectChanges();
    expect(host.querySelector('.ocu-suggested')?.textContent).toContain(
      'Application errors in USER: 7 on 2026-09-17'
    );
  });

  it('the hidden block references no label of its own, so it leaves no dangling IDREF off Home', async () => {
    // Mutation (Rule 19): bind `[attr.aria-labelledby]="suggestedLabelId"` unconditionally -> this
    // goes red. The section is in the DOM on every route, so an unconditional binding points at an
    // element that only exists inside the `@if`.
    const away = await mount({ rows: [{ enabled: true }], area: 'permissions' });
    const hidden = away.host.querySelector('.ocu-suggested') as HTMLElement;
    expect(hidden).not.toBeNull();
    expect(hidden.hasAttribute('aria-labelledby')).toBe(false);

    const home = await mountOnHome([{ date: '2026-09-17', count: 3 }]);
    const shown = home.host.querySelector('.ocu-suggested') as HTMLElement;
    expect(home.host.querySelector(`#${shown.getAttribute('aria-labelledby')}`)).not.toBeNull();
  });

  it('an unconfigured panel renders neither the block nor the greeting: the existing empty state owns the transcript', async () => {
    const turn = stubTurnStore();
    await turn.restore();
    const { host } = await mount({ rows: [], area: 'home', turn });
    expect(host.querySelector('.ocu-suggested-eyebrow')).toBeNull();
    expect(host.querySelector('.ocu-panel-greeting')).toBeNull();
    expect(host.querySelector('[role="log"] .ocu-panel-example')).not.toBeNull();
  });

  /** A `TurnStore` whose restore answered one finished turn, so the transcript is not empty. */
  async function restoredWithOneTurn(): Promise<TurnStore> {
    const map = new Map<string, string>([['ocupilot.conversation', 'convo-1']]);
    const storage = {
      getItem: (key: string) => (map.has(key) ? (map.get(key) as string) : null),
      setItem: (key: string, value: string) => {
        map.set(key, value);
      },
      removeItem: (key: string) => {
        map.delete(key);
      },
    };
    const api = fakeTurnApi({
      [conversationReadPathFor('convo-1')]: [
        {
          kind: 'ok',
          status: 200,
          body: {
            conversationId: 'convo-1',
            turns: [{ seq: 1, message: 'go', state: 'completed', reply: 'ok', error: null, steps: [], stepsDropped: 0 }],
          },
        },
      ],
    });
    const turn = stubTurnStore({ api: api as never, storage, navigationType: () => 'reload' });
    await turn.restore();
    return turn;
  }

  it('AC1: the block still reads when the navigation map is the last of the bootstrap reads to answer', async () => {
    // Mutation (Rule 19): drop `this.syncSuggested()` from the `navigation.subscribe` handler in
    // `panel.ts` -> this goes red, and the block renders nothing for that whole Home visit.
    //
    // `App` issues the map, the namespace list and the status read concurrently, and
    // `syncSuggested` withholds the read until `answered` -- the map AND the status -- holds. The
    // shell's own notification is spent long before either answers, because `ScreenOutlet` sets
    // the area from the static mirror on the first route event, so when the map settles last its
    // own notification is the only thing left that can start the read.
    const api = fakeDatesApi(DATES_OK([{ date: '2026-09-17', count: 3 }]));
    const { host, fixture, navigation, suggested } = await mount({
      rows: [{ enabled: true }],
      area: 'home',
      loaded: false,
      suggestedApi: api,
      settleSuggested: false,
    });
    expect(api.calls).toEqual([]);
    expect(host.querySelector('.ocu-suggested-eyebrow')).toBeNull();

    navigation.loadedFlag = true;
    navigation.notify();
    await turnSettle();
    fixture.detectChanges();
    expect(api.calls).toEqual(['/api/ocupilot/logs/errors/dates?namespace=HSCUSTOM']);
    expect(suggested.answered()).toBe(true);
    expect(host.querySelector('.ocu-suggested-eyebrow')?.textContent?.trim()).toBe(STRINGS.homeSuggestedView);
  });

  it('AC6: with the conversation restored and a turn in it, the block itself carries the three prompts', async () => {
    // Mutation (Rule 19): make `suggestedPrompts` return `[]` unconditionally -> this goes red.
    //
    // This is the state AC6 names, as production reaches it: the transcript has answered and
    // holds a turn, so the greeting is not showing and the block is the only place the prompts
    // can be. The case above mounts a transcript that was never restored, which is a window
    // production leaves within one round trip -- `TurnStore.restore()` sets `restored()` on every
    // settle, a fault included -- so it cannot stand for AC6 on its own.
    const turn = await restoredWithOneTurn();
    const { host } = await mountOnHome([], { turn });
    const block = host.querySelector('.ocu-suggested') as HTMLElement;
    const log = host.querySelector('[role="log"]') as HTMLElement;
    expect(log.querySelectorAll('.ocu-panel-turn')).toHaveLength(1);
    expect(log.querySelector('.ocu-panel-greeting')).toBeNull();
    expect(host.querySelectorAll('.ocu-suggested-starter')).toHaveLength(3);
    expect(
      [...block.querySelectorAll('.ocu-suggested-starter > span:first-child')].map((node) =>
        node.textContent?.trim()
      )
    ).toEqual([
      STRINGS.homeStarterPromptExplainScreen,
      STRINGS.homeStarterPromptExplainLog,
      STRINGS.homeStarterPromptChangeOneThing,
    ]);
    // The zeros are gone and the uncounted agent-status line stays (AC2).
    expect(block.querySelectorAll('code')).toHaveLength(0);
    expect([...block.querySelectorAll('.ocu-suggested-prompt')].map((node) => node.textContent?.trim())).toEqual([
      STRINGS.statusReadOnlyOff,
    ]);
  });

  it("the Open control is named by the published word alone, and both glyphs are decorative", async () => {
    // EXPERIENCE.md's Fixed strings row gives it "the accessible name of a suggested-view line's
    // open control" -- the published word, with the chevron beside it decorative -- and its
    // accessibility floor makes every such glyph `aria-hidden`.
    // Mutation (Rule 19): drop `aria-hidden` from either glyph span in `panel.ts` -> this goes
    // red. Nothing else observes it: `textContent` carries a hidden glyph either way.
    const { host } = await mountOnHome([{ date: '2026-09-17', count: 3 }]);
    const open = [...host.querySelectorAll('.ocu-suggested-open')][1] as HTMLAnchorElement;
    const glyphs = [...open.querySelectorAll('span')];
    expect(glyphs).toHaveLength(1);
    expect(glyphs[0].getAttribute('aria-hidden')).toBe('true');
    const spoken = [...open.childNodes]
      .filter((node) => (node as HTMLElement).getAttribute?.('aria-hidden') !== 'true')
      .map((node) => node.textContent ?? '')
      .join('')
      .trim();
    expect(spoken).toBe(STRINGS.homeSuggestedOpen);

    const zero = await mountOnHome([]);
    const send = zero.host.querySelector('.ocu-suggested-send-glyph') as HTMLElement;
    expect(send.getAttribute('aria-hidden')).toBe('true');
  });

  it('an appended source naming a descriptor the mirror does not carry renders an Open that refuses', async () => {
    // Mutation (Rule 19): drop the `row.url === ''` half of `onSuggestionOpen`'s guard -> this
    // goes red, because the handler then calls `navigateByUrl('')` and the tab leaves the query
    // it was on. Both shipped descriptors are pinned resolvable in
    // `tools/suggested-view.test.mjs`, which is what makes this branch reachable only through an
    // appended source -- and appending one is Story 6.13's whole shape.
    const sources = SOURCES as Source[];
    sources.push({
      key: 'alerts-log',
      read: (_view, state) => {
        state.answer = {
          key: 'alerts-log',
          counted: true,
          text: 'New alerts.log entries: 2',
          count: 2,
          label: 'New alerts.log entries: ',
          tail: '',
          descriptor: 'OcuPilot.Screen.Descriptor.NotBuilt',
        };
        return Promise.resolve();
      },
    });
    try {
      const { host, fixture } = await mountOnHome([{ date: '2026-09-17', count: 3 }], { url: '/?ns=USER' });
      const open = [...host.querySelectorAll('.ocu-suggested-open')][2] as HTMLAnchorElement;
      expect(open.getAttribute('href')).toBe('');
      const before = TestBed.inject(Router).url;
      const click = new MouseEvent('click', { bubbles: true, cancelable: true });
      open.dispatchEvent(click);
      await fixture.whenStable();
      expect(click.defaultPrevented).toBe(true);
      expect(TestBed.inject(Router).url).toBe(before);
    } finally {
      sources.pop();
    }
  });
});

/**
 * Story 5.2: the live proposal cards in the transcript.
 *
 * Every card here arrives the way a real one does -- off a progress poll the test drives by hand
 * through the injected `schedule` seam -- so the panel is asserted over the store's own shape
 * rather than over a hand-built `PanelTurnView`.
 */

/** One wire proposal, in the shape `OcuPilot.Kernel.State.Propose`'s wire row writes. */
function wireProposal(overrides: Record<string, unknown> = {}) {
  return {
    proposalId: 'p1',
    target: { type: 'web-application', scope: 'instance', id: '/csp/myapp' },
    expiresAt: new Date(Date.now() + 599_000).toISOString(),
    tool: 'webapp.list.update',
    changed: [{ field: 'Enabled', before: 'No', after: 'Yes' }],
    unchangedCount: 38,
    rationale: 'The application is disabled.',
    expectedImpact: 'it can be reached',
    reverse: 'disable it again',
    state: 'live',
    auditWarning: false,
    ...overrides,
  };
}

/** A completed progress answer carrying `proposals`, as `OcuPilot.Api.Turn.HandleProgress` writes it. */
function progressWith(proposals: unknown[], state = 'completed', reply = 'I have prepared the change.') {
  return {
    kind: 'ok',
    status: 200,
    body: {
      turnId: 'turn-1',
      state,
      startedAt: null,
      endedAt: null,
      iterations: 1,
      tokens: { input: 1, output: 1 },
      limit: null,
      steps: [],
      stepsDropped: 0,
      reply: state === 'completed' ? reply : null,
      error: null,
      proposals,
    },
  };
}

/** A panel with one finished turn carrying `proposals`, reached through a real send and one poll. */
async function mountWithProposals(proposals: unknown[]): Promise<Mounted & { api: ReturnType<typeof fakeTurnApi> }> {
  const { schedule, scheduled } = fakeTurnSchedule();
  const api = fakeTurnApi({
    [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
    [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
    [turnProgressPath('turn-1')]: [progressWith(proposals)],
  });
  const turn = stubTurnStore({ api: api as never, schedule });
  const mounted = await mount({ rows: [{ enabled: true }], turn });
  await typeDraft(mounted.host, mounted.fixture, 'enable the demo application');
  (mounted.host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
  await turnSettle();
  scheduled.shift()?.run();
  await turnSettle();
  mounted.fixture.detectChanges();
  return { ...mounted, api };
}

const cardTitles = (host: HTMLElement): string[] =>
  [...host.querySelectorAll('app-proposal-card .ocu-proposal-card-title')].map((node) =>
    (node.textContent ?? '').trim()
  );

describe('Story 5.2: the proposal cards in the transcript', () => {
  it('Integration AC: one card per wire proposal, and Send carries the secondary class while one is live', async () => {
    // Mutation (Rule 19): leave Send on `ocu-button-primary` while a card is live -> this goes red,
    // and Confirm would not be the only filled button in the view.
    const { host } = await mountWithProposals([wireProposal()]);
    expect(host.querySelectorAll('app-proposal-card')).toHaveLength(1);
    // The noun is the target screen's own declaration (AD-5), not a client-side table.
    expect(cardTitles(host)).toEqual(['Proposal \u00b7 Web application /csp/myapp']);

    const send = host.querySelector('.ocu-panel-send') as HTMLButtonElement;
    expect(send.classList.contains('ocu-button-secondary')).toBe(true);
    expect(send.classList.contains('ocu-button-primary')).toBe(false);
    const confirm = host.querySelector('.ocu-proposal-card-confirm') as HTMLButtonElement;
    expect(confirm.classList.contains('ocu-button-primary')).toBe(true);

    // The footer captions read the account off the session, and the reply points at Confirm.
    expect(host.querySelector('.ocu-proposal-card-runs-as')?.textContent?.trim()).toBe(
      'Runs as _SYSTEM, with your privileges.'
    );
    expect(host.querySelector('.ocu-panel-message-agent-text')?.textContent).toContain(
      STRINGS.proposalConfirmSentence
    );
  });

  it('AC5: several proposals stack in wire order, each with its own Confirm and Cancel, and no control confirms more than one', async () => {
    // Mutation (Rule 19): add a control that confirms every card at once -> the button roster
    // below goes red naming it.
    const { host } = await mountWithProposals([
      wireProposal(),
      wireProposal({ proposalId: 'p2', target: { type: 'web-application', scope: 'instance', id: '/csp/other' } }),
    ]);
    expect(cardTitles(host)).toEqual([
      'Proposal \u00b7 Web application /csp/myapp',
      'Proposal \u00b7 Web application /csp/other',
    ]);
    expect(host.querySelectorAll('.ocu-proposal-card-confirm')).toHaveLength(2);
    expect(host.querySelectorAll('.ocu-proposal-card-cancel')).toHaveLength(2);

    const labels = [...host.querySelectorAll('button')].map(
      (button) => button.getAttribute('aria-label') ?? button.textContent?.trim()
    );
    expect(labels).toEqual([
      STRINGS.actionNewConversation,
      STRINGS.agentPanelFullScreen,
      STRINGS.actionConfirm,
      STRINGS.actionCancel,
      STRINGS.actionConfirm,
      STRINGS.actionCancel,
      STRINGS.actionSend,
    ]);
  });

  it("Cancel on one card takes that card's own status line, and leaves its sibling live", async () => {
    const { host, fixture } = await mountWithProposals([
      wireProposal(),
      wireProposal({ proposalId: 'p2' }),
    ]);
    (host.querySelectorAll('.ocu-proposal-card-cancel')[0] as HTMLButtonElement).click();
    fixture.detectChanges();
    const cards = [...host.querySelectorAll('app-proposal-card')] as HTMLElement[];
    expect(cards[0].querySelector('.ocu-proposal-card-status')?.textContent?.trim()).toBe(
      STRINGS.proposalStatusCanceledByYou
    );
    expect(cards[1].querySelector('.ocu-proposal-card-status')).toBeNull();
    // One card still live, so Send is still the secondary.
    expect((host.querySelector('.ocu-panel-send') as HTMLElement).classList.contains('ocu-button-secondary')).toBe(true);
  });

  it('a typed message cancels every live card, and Send returns to primary once none is live', async () => {
    // Mutation (Rule 19): drop the `cancelLiveCards` call from `sendCurrentDraft` -> this goes red,
    // and a card the message has already cancelled would still offer Confirm.
    const { host, fixture } = await mountWithProposals([
      wireProposal(),
      wireProposal({ proposalId: 'p2' }),
    ]);
    await typeDraft(host, fixture, 'yes');
    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();

    const statuses = [...host.querySelectorAll('.ocu-proposal-card-status')].map((node) =>
      (node.textContent ?? '').trim()
    );
    expect(statuses).toEqual([
      STRINGS.proposalStatusCanceledByMessage,
      STRINGS.proposalStatusCanceledByMessage,
    ]);
    expect((host.querySelector('.ocu-panel-send') as HTMLElement).classList.contains('ocu-button-primary')).toBe(true);

    // Mutation (Rule 19): widen `replyWithConfirmSentence`'s guard to `proposals.length === 0`, so
    // the sentence is appended to any turn that minted a card -> this goes red. The sentence is
    // the panel's own live instruction, not part of the model's reply, so it goes when the last
    // card of the turn does; nothing else in this file reads the reply on the terminal branch.
    expect(host.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '').not.toContain(
      STRINGS.proposalConfirmSentence
    );
  });

  it('the ticker advances the panel clock, so a card that runs out while it is on screen expires', async () => {
    // Mutation (Rule 19): make `syncTicker` a no-op (never call `setInterval`) -> this goes red.
    // Nothing else in this suite waits on the clock: every other fixture is either 599s ahead or
    // already past at mount, so a countdown frozen at the moment the poll landed ships green --
    // it would never reach 0:00, `phaseFor` would never answer `expired`, and Confirm would stay
    // pressable past AD-6's window. This is the one test that watches a second go by.
    const { host, fixture } = await mountWithProposals([
      wireProposal({ expiresAt: new Date(Date.now() + 1_500).toISOString() }),
    ]);
    expect(host.querySelector('.ocu-proposal-card-confirm')).not.toBeNull();
    expect(
      (host.querySelector('.ocu-panel-send') as HTMLElement).classList.contains('ocu-button-secondary')
    ).toBe(true);

    await new Promise((resolve) => setTimeout(resolve, 2_300));
    fixture.detectChanges();

    expect(host.querySelector('.ocu-proposal-card-status')?.textContent?.trim()).toBe(
      STRINGS.proposalStatusExpired
    );
    expect(host.querySelector('.ocu-proposal-card-confirm')).toBeNull();
    expect(
      (host.querySelector('.ocu-panel-send') as HTMLElement).classList.contains('ocu-button-primary')
    ).toBe(true);
  });

  it('Stop cancels nothing: a proposal already posted in that turn stays live', async () => {
    // Mutation (Rule 19): cancel live cards on Stop -> this goes red, and the New-conversation
    // test above stays green, which is what separates the two paths.
    const { schedule, scheduled } = fakeTurnSchedule();
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
      [turnProgressPath('turn-1')]: [progressWith([wireProposal()], 'running')],
      [turnStopPath('turn-1')]: [{ kind: 'ok', status: 200, body: { stopRequested: true } }],
    });
    const turn = stubTurnStore({ api: api as never, schedule });
    const { host, fixture } = await mount({ rows: [{ enabled: true }], turn });
    await typeDraft(host, fixture, 'enable it');
    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    scheduled.shift()?.run();
    await turnSettle();
    fixture.detectChanges();
    expect(host.querySelectorAll('app-proposal-card')).toHaveLength(1);

    // Send reads Stop while the turn runs; pressing it asks the instance to stop and cancels
    // nothing here.
    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();
    expect(api.calls.some((call) => call.path === turnStopPath('turn-1'))).toBe(true);
    expect(host.querySelector('.ocu-proposal-card-status')).toBeNull();
    expect(host.querySelector('.ocu-proposal-card-confirm')).not.toBeNull();
  });

  it('New conversation clears the transcript, so every live card goes with it', async () => {
    const { host, fixture } = await mountWithProposals([wireProposal()]);
    expect(host.querySelectorAll('app-proposal-card')).toHaveLength(1);
    (host.querySelector('.ocu-panel-new-conversation') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();
    expect(host.querySelectorAll('app-proposal-card')).toHaveLength(0);
    expect((host.querySelector('.ocu-panel-send') as HTMLElement).classList.contains('ocu-button-primary')).toBe(true);
  });

  it('a live card under the kill switch offers no Confirm, only the published status line', async () => {
    // The restraint object is read on every call (`testing/agent-status.ts`), so the switch is
    // flipped the way the instance flips it: the state changes and the next read answers
    // differently.
    const restraint: { -readonly [K in keyof Restraint]?: Restraint[K] } = {};
    const { schedule, scheduled } = fakeTurnSchedule();
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
      [turnProgressPath('turn-1')]: [progressWith([wireProposal()])],
    });
    const turn = stubTurnStore({ api: api as never, schedule });
    const { host, fixture, agentStatus } = await mount({ rows: [{ enabled: true }], turn, restraint });
    await typeDraft(host, fixture, 'enable it');
    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    scheduled.shift()?.run();
    await turnSettle();
    fixture.detectChanges();
    expect(host.querySelector('.ocu-proposal-card-confirm')).not.toBeNull();

    restraint.killSwitch = true;
    restraint.killSwitchAudience = 'everyone';
    restraint.killSwitchReason = 'Paused during the change freeze';
    restraint.blocked = true;
    await agentStatus.load();
    fixture.detectChanges();
    expect(host.querySelector('.ocu-proposal-card-status')?.textContent?.trim()).toBe(
      STRINGS.proposalStatusAgentSwitchedOff
    );
    // Across the transition Confirm is `aria-disabled` rather than removed while it could hold
    // focus; it goes once the status line has taken focus.
    expect(host.querySelector('.ocu-proposal-card-confirm')?.getAttribute('aria-disabled')).toBe('true');
    await new Promise((resolve) => setTimeout(resolve, 0));
    fixture.detectChanges();
    expect(host.querySelector('.ocu-proposal-card-confirm')).toBeNull();
  });

  it('a card whose countdown has run out is expired to this panel too: Send returns to primary and a typed message does not relabel it', async () => {
    // Mutation (Rule 19): drop the clock from `phaseFor` -> both halves go red. The panel and the
    // card each resolve a phase, so without the clock in `phaseFor` the card draws itself
    // `Expired` while `liveCards` still counts it live: Send stays secondary with no Confirm
    // anywhere in the view, the ticker never disarms, and the next typed message overwrites
    // `Expired` with `Canceled - by your message`, taking Re-propose away (WCAG 2.2.1).
    //
    // The expiry is already past at mount, so the assertion needs no timer: the clock the panel
    // reads is `Date.now()` either way.
    const { host, fixture } = await mountWithProposals([
      wireProposal({ expiresAt: new Date(Date.now() - 1_000).toISOString() }),
    ]);
    expect(host.querySelectorAll('app-proposal-card')).toHaveLength(1);
    expect(host.querySelector('.ocu-proposal-card-status')?.textContent?.trim()).toBe(
      STRINGS.proposalStatusExpired
    );
    expect(host.querySelector('.ocu-proposal-card-confirm')).toBeNull();
    const send = host.querySelector('.ocu-panel-send') as HTMLElement;
    expect(send.classList.contains('ocu-button-primary')).toBe(true);
    expect(send.classList.contains('ocu-button-secondary')).toBe(false);

    // And the message cancels nothing that had already run out of time.
    await typeDraft(host, fixture, 'what happened?');
    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();
    expect(host.querySelector('.ocu-proposal-card-status')?.textContent?.trim()).toBe(
      STRINGS.proposalStatusExpired
    );
    expect(host.querySelector('.ocu-proposal-card-repropose')).not.toBeNull();
  });

  it('the confirm sentence is appended once, never again to a reply that already ends with it', async () => {
    // Mutation (Rule 19): drop `replyWithConfirmSentence`'s "already ends with it" guard -> this
    // goes red on a doubled sentence. The integration AC above uses `toContain`, which a second
    // copy satisfies just as well.
    const { schedule, scheduled } = fakeTurnSchedule();
    const answered = progressWith([wireProposal()]);
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
      [turnProgressPath('turn-1')]: [
        {
          ...answered,
          body: { ...answered.body, reply: 'I have prepared the change.\n\n' + STRINGS.proposalConfirmSentence },
        },
      ],
    });
    const turn = stubTurnStore({ api: api as never, schedule });
    const mounted = await mount({ rows: [{ enabled: true }], turn });
    await typeDraft(mounted.host, mounted.fixture, 'enable the demo application');
    (mounted.host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    scheduled.shift()?.run();
    await turnSettle();
    mounted.fixture.detectChanges();

    const text = mounted.host.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '';
    expect(text.split(STRINGS.proposalConfirmSentence)).toHaveLength(2);
  });

  it('DW-1213: a restored transcript renders its cards expired, with Re-propose and no countdown', async () => {
    // Mutation (Rule 19): make `parseRestoredEntry` hard-code `proposals: []` again -> this goes
    // red on the card count, and a reload would lose the card with no other route to it.
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
                message: 'enable the demo application',
                state: 'completed',
                reply: 'I have prepared the change.',
                error: null,
                steps: [],
                stepsDropped: 0,
                proposals: [wireProposal()],
              },
            ],
          },
        },
      ],
    });
    const storage = memoryStorage();
    storage.setItem('ocupilot.conversation', 'convo-1');
    const turn = stubTurnStore({ api: api as never, storage, navigationType: () => 'reload' });
    await turn.restore();
    const { host } = await mount({ rows: [{ enabled: true }], turn });

    expect(host.querySelectorAll('app-proposal-card')).toHaveLength(1);
    expect(host.querySelector('.ocu-proposal-card-status')?.textContent?.trim()).toBe(
      STRINGS.proposalStatusExpired
    );
    expect(host.querySelector('.ocu-proposal-card-repropose')?.textContent?.trim()).toBe(
      STRINGS.actionRepropose
    );
    expect(host.querySelector('.ocu-proposal-card-confirm')).toBeNull();
    expect(host.querySelector('.ocu-proposal-card-countdown')).toBeNull();
    // A restored card is terminal, so Send is a primary again.
    expect((host.querySelector('.ocu-panel-send') as HTMLElement).classList.contains('ocu-button-primary')).toBe(true);
  });
});

/**
 * Story 5.3: the panel's half of the confirmed write -- the in-flight Confirm, the terminal phase
 * the wire supplies, the cancel that reaches the instance, and Re-propose.
 *
 * Every card arrives off a real poll, as above; the decision routes are stubbed per path, so what
 * is asserted is the request the panel actually made and the phase the answer produced.
 */
describe('Story 5.3: confirming, cancelling and re-proposing a card', () => {
  /** A panel with one live card, and the two decision routes answering `answers`. */
  async function mountDecidable(
    answers: Record<string, unknown[]>,
    proposals: unknown[] = [wireProposal()],
    reply = 'I have prepared the change.'
  ) {
    const { schedule, scheduled } = fakeTurnSchedule();
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [{ kind: 'ok', status: 202, body: { turnId: 'turn-1' } }],
      [turnProgressPath('turn-1')]: [progressWith(proposals, 'completed', reply)],
      ...answers,
    });
    const turn = stubTurnStore({ api: api as never, schedule });
    const mounted = await mount({ rows: [{ enabled: true }], turn });
    await typeDraft(mounted.host, mounted.fixture, 'enable the demo application');
    (mounted.host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    scheduled.shift()?.run();
    await turnSettle();
    mounted.fixture.detectChanges();
    return { ...mounted, api, scheduled };
  }

  it('AC8: the card draws the in-flight Confirm while the request is still out', async () => {
    // The half of AC8 that only exists between the press and the answer, and the one the Cancel
    // guard depends on: `cancelAriaDisabled` refuses during `confirming`, which is unreachable
    // unless the panel actually enters that phase.
    // Mutation (Rule 19): delete `this.setCardPhase(proposalId, 'confirming')` from
    // `Panel.onCardConfirm` -> the card stays `live` for the whole round trip and the spinner and
    // both `aria-disabled` assertions below go red.
    let answer!: (value: unknown) => void;
    const held = new Promise((resolve) => {
      answer = resolve;
    });
    const { host, fixture } = await mountDecidable({ [proposalConfirmPath('p1')]: [held] });

    (host.querySelector('.ocu-proposal-card-confirm') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();

    // Nothing has answered yet: this is the card mid-flight.
    const confirm = host.querySelector('.ocu-proposal-card-confirm');
    expect(confirm).not.toBeNull();
    expect(confirm?.getAttribute('aria-disabled')).toBe('true');
    expect(confirm?.classList.contains('ocu-proposal-card-confirm-busy')).toBe(true);
    expect(host.querySelector('.ocu-proposal-card-confirm-spinner')).not.toBeNull();
    expect(host.querySelector('.ocu-proposal-card-cancel')?.getAttribute('aria-disabled')).toBe('true');
    expect(host.querySelector('.ocu-proposal-card-status')).toBeNull();

    answer({
      kind: 'ok',
      status: 200,
      body: { proposalId: 'p1', state: 'confirmed', closedReason: '', confirmedAt: '2026-09-19T10:31:04Z' },
    });
    await turnSettle();
    fixture.detectChanges();
    expect(host.querySelector('.ocu-proposal-card-confirm-spinner')).toBeNull();
    expect(host.querySelector('.ocu-proposal-card-status')?.textContent?.trim()).toBe(
      'Confirmed by _SYSTEM \u00b7 10:31:04'
    );
  });

  it('AC8: Confirm posts the confirm route and the card ends in the state the instance answered', async () => {
    // Mutation (Rule 19): stop dropping this panel's own `confirming` decision in `onCardConfirm`
    // -> the confirmed status line never appears and this goes red, because the panel's decision
    // would outrank the instance's answer for the card's whole life.
    const { host, fixture, api } = await mountDecidable({
      [proposalConfirmPath('p1')]: [
        {
          kind: 'ok',
          status: 200,
          body: { proposalId: 'p1', state: 'confirmed', closedReason: '', confirmedAt: '2026-09-19T10:31:04Z' },
        },
      ],
    });
    (host.querySelector('.ocu-proposal-card-confirm') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();

    const posted = api.calls.find((call) => call.path === proposalConfirmPath('p1'));
    expect(posted?.method).toBe('POST');
    expect(JSON.parse(String(posted?.body ?? '{}'))).toEqual({});
    expect(host.querySelector('.ocu-proposal-card-status')?.textContent?.trim()).toBe(
      'Confirmed by _SYSTEM \u00b7 10:31:04'
    );
    // Across the transition the outgoing button is `aria-disabled` rather than removed, and it is
    // dropped on the macrotask after the status line has had its chance at focus.
    expect(host.querySelector('.ocu-proposal-card-confirm')?.getAttribute('aria-disabled')).toBe('true');
    await new Promise((resolve) => setTimeout(resolve, 0));
    fixture.detectChanges();
    expect(host.querySelector('.ocu-proposal-card-confirm')).toBeNull();
    // The last live card is gone, so Send is a primary again.
    expect((host.querySelector('.ocu-panel-send') as HTMLElement).classList.contains('ocu-button-primary')).toBe(true);
  });

  it("DW-1227: the card's screen facts come from the proposal's own tool, not from its entity type", async () => {
    // The auditing write's screen is `built: false`, so `screenForEntityType` answers `null` for it
    // and the card would carry no singular noun at all -- while `screenForToolName` resolves the one
    // screen whose `toolIdentifier` claims that tool name. The noun is what makes the difference
    // observable here; the secret names travel the same lookup.
    //
    // Mutation (Rule 19): key `Panel.proposalView` back on `proposal.target.type` -> the title loses
    // its noun and this goes red.
    const { host } = await mountDecidable({}, [
      wireProposal({
        proposalId: 'p1',
        tool: 'security.auditing.update',
        target: { type: 'auditing-configuration', scope: 'instance', id: 'SYSTEM' },
        changed: [{ field: 'Enabled', before: 'Yes', after: 'No' }],
      }),
    ]);
    const title = (host.querySelector('.ocu-proposal-card-title')?.textContent ?? '').trim();
    expect(title).toContain(STRINGS.auditingConfigurationLink);
    expect(title).toContain('SYSTEM');
  });

  it("AC1: the tool's destructive declaration reaches the card off the wire, through this panel", async () => {
    // The whole client path for AC1: the wire row's `destructive`, the panel's view mapping, and
    // the card's treatment. The declaration is the write tool's own -- nothing in this client holds
    // a list of destructive tool names.
    //
    // Mutation (Rule 19): drop `destructive` from `parseProposal` or from `toCardView` -> this goes
    // red; the instance half is `OcuPilot.Test.ToolWrite`'s and `OcuPilot.Test.ProposalWire`'s.
    const { host } = await mountDecidable({}, [wireProposal({ destructive: true })]);
    const card = host.querySelector('.ocu-proposal-card') as HTMLElement;
    expect(card.classList.contains('ocu-proposal-card-destructive')).toBe(true);
    expect(
      host.querySelector('.ocu-proposal-card-confirm')?.classList.contains('ocu-button-destructive')
    ).toBe(true);

    const plain = await mountDecidable({}, [wireProposal()]);
    expect(
      (plain.host.querySelector('.ocu-proposal-card') as HTMLElement).classList.contains(
        'ocu-proposal-card-destructive'
      )
    ).toBe(false);
  });

  it('AC4: a fingerprint refusal closes the card target-changed and offers only Re-propose', async () => {
    const { host, fixture } = await mountDecidable({
      [proposalConfirmPath('p1')]: [
        {
          kind: 'error',
          status: 409,
          code: 'PROPOSAL.TARGETCHANGED',
          reason: 'the target changed',
          detail: { state: 'canceled', closedReason: 'target-changed' },
        },
      ],
    });
    (host.querySelector('.ocu-proposal-card-confirm') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();

    const status = host.querySelector('.ocu-proposal-card-status') as HTMLElement;
    expect(status.classList.contains('ocu-banner-warning')).toBe(true);
    expect(status.querySelector('.ocu-banner-message')?.textContent?.trim()).toBe(
      STRINGS.proposalTargetChanged
    );
    expect(host.querySelector('.ocu-proposal-card-repropose')).not.toBeNull();
  });

  it('a refusal that left the row live gives the card its Confirm back, says it was refused, and records the refused write -- 5.6 pinned the absence only because nothing produced one', async () => {
    // DW-1348 (Story 5.6). The Confirm coming back is the pre-existing half; what that story added
    // is that the press is no longer invisible -- the envelope's own written reason is on the card.
    // DW-1426 (Story 5.8) adds the other half: the write was attempted, so the transcript records
    // it as a `failed` tool-call card. Story 5.6 asserted zero cards here, which was true of the
    // code and not of the contract: `recordWriteCard` returned early on every refusal, so there was
    // no card to find.
    //
    // mutation: drop the `recordProposalRefusal` call from `decideProposal`'s error path in
    // `core/turn.ts` -> the reason assertions go red while the Confirm one stays green, which is
    // exactly the state this story found.
    const { host, fixture } = await mountDecidable({
      [proposalConfirmPath('p1')]: [
        {
          kind: 'error',
          status: 403,
          code: 'AGENT.READONLY.ENFORCED',
          reason: 'Read-only mode is enforced on this instance.',
          detail: null,
        },
      ],
    });
    (host.querySelector('.ocu-proposal-card-confirm') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();
    expect(host.querySelector('.ocu-proposal-card-status')).toBeNull();
    expect(host.querySelector('.ocu-proposal-card-confirm')).not.toBeNull();
    const refusal = host.querySelector('[data-slot="refusal"]') as HTMLElement;
    expect(refusal).not.toBeNull();
    expect(refusal.textContent).toContain('Read-only mode is enforced on this instance.');
    // The write that was attempted and refused has its own card, reading the published failed
    // line with the envelope's own reason -- and the reply gains no change sentence, because
    // nothing changed.
    //
    // mutation: restore `recordWriteCard`'s `if (!outcome.ok) return;` -> this goes red.
    const cards = host.querySelectorAll('app-tool-call-card');
    expect(cards).toHaveLength(1);
    const word = cards[0].querySelector('.ocu-tool-call-status-word') as HTMLElement;
    expect(word.textContent?.trim()).toBe(
      STRINGS.toolCallStatusFailed.split('<reason>').join('Read-only mode is enforced on this instance.')
    );
    const reply = host.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '';
    expect(reply).not.toContain(formatChangeSentence(STRINGS.tableChangeUpdated, '/csp/myapp'));
    expect(reply).not.toContain(STRINGS.agentAuditFollowUpQuestion);
  });

  it('a Confirm whose request never reached the instance records no card at all', async () => {
    // DW-1426's boundary. `recordWriteCard` now records a card for a refusal, which is the point of
    // this story -- but an answer with `status` 0 is not a refusal: it is what `ApiService` produces
    // for a thrown or aborted fetch, so the instance never said anything about this write. Recording
    // it would put `failed - ` in the transcript, with no reason and no pair, for a write the
    // instance never received.
    //
    // mutation: drop the `!outcome.ok && outcome.status === 0` guard from `recordWriteCard` -> a
    // card is appended and this goes red.
    // The answer shape is `ApiService`'s own for a thrown or aborted fetch, verbatim from
    // `core/api.ts`: status 0 with a null code, reason and detail. `detail` is not optional on the
    // error variant, so a fixture that omitted it would not be a `JsonResult` at all.
    const { host, fixture } = await mountDecidable({
      [proposalConfirmPath('p1')]: [{ kind: 'error', status: 0, code: null, reason: null, detail: null }],
    });
    (host.querySelector('.ocu-proposal-card-confirm') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();
    expect(host.querySelectorAll('app-tool-call-card')).toHaveLength(0);
    // The row is untouched, so the card keeps its Confirm and gains no terminal status line.
    expect(host.querySelector('.ocu-proposal-card-confirm')).not.toBeNull();
    expect(host.querySelector('.ocu-proposal-card-status')).toBeNull();
  });

  it('AC: a confirm refused for a missing privilege pair names the pair on the failed card, not the generic reason', async () => {
    // DW-1426 with AD-8: a 403 on confirm reads "failed - <resource>" and the detail is the pair
    // the instance named, because the pair is what the user has to be granted.
    //
    // mutation: stop reading `detail.failedPair` in `decideProposal`'s refusal branch -> the card
    // falls back to the written reason and this goes red.
    const { host, fixture } = await mountDecidable({
      [proposalConfirmPath('p1')]: [
        {
          kind: 'error',
          status: 403,
          code: 'AUTH.NOPRIVILEGE',
          reason: 'A privilege this action requires is missing.',
          detail: { failedPair: '%Admin_Secure:USE' },
        },
      ],
    });
    (host.querySelector('.ocu-proposal-card-confirm') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();
    const word = host.querySelector('.ocu-tool-call-status-word') as HTMLElement;
    expect(word.textContent?.trim()).toBe(
      STRINGS.toolCallStatusFailed.split('<reason>').join('%Admin_Secure:USE')
    );
    // The card the refusal was about keeps its Confirm and its banner: the row is still live.
    expect(host.querySelector('.ocu-proposal-card-confirm')).not.toBeNull();
    expect(host.querySelector('[data-slot="refusal"]')).not.toBeNull();
  });

  /**
   * Integration AC (Rule 1), Story 5.6: the panel is the consumer of the confirm answer's
   * `auditMarked`, and what it produces is a tool-call card whose **collapsed** line says what
   * became of the marker, plus the published sentence on the reply.
   *
   * mutation: stop passing `outcome.auditMarked` in `Panel.recordWriteCard` (record `true`
   * unconditionally) -> the status-word and reply assertions below go red, while the marked case
   * stays green.
   */
  it('AC: a confirmed write whose marker was dropped appends a card reading done \u00b7 audit not marked, and the reply says so', async () => {
    const { host, fixture } = await mountDecidable({
      [proposalConfirmPath('p1')]: [
        {
          kind: 'ok',
          status: 200,
          body: {
            proposalId: 'p1',
            state: 'confirmed',
            closedReason: '',
            confirmedAt: '2026-09-19T10:31:04Z',
            auditMarked: false,
          },
        },
      ],
    });
    expect(host.querySelectorAll('app-tool-call-card')).toHaveLength(0);
    (host.querySelector('.ocu-proposal-card-confirm') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();

    const cards = host.querySelectorAll('app-tool-call-card');
    expect(cards).toHaveLength(1);
    const card = cards[0] as HTMLElement;
    const toggle = card.querySelector('.ocu-tool-call-toggle') as HTMLElement;
    // Collapsed, and the sentence is on the line the user can see without opening anything.
    expect(toggle.getAttribute('aria-expanded')).toBe('false');
    expect(card.querySelector('.ocu-tool-call-body')).toBeNull();
    const word = card.querySelector('.ocu-tool-call-status-word') as HTMLElement;
    expect(word.textContent?.trim()).toBe(STRINGS.auditMarkerFailed);
    expect(word.classList.contains('ocu-tool-call-status-warning')).toBe(true);
    // The card names the write it is about.
    expect(card.querySelector('.ocu-tool-call-name')?.textContent).toContain('webapp.list.update');

    const reply = host.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '';
    expect(reply).toContain(STRINGS.auditMarkerReplySentence);
    // The write happened: nothing calls it a failure (AD-15).
    expect(reply).not.toContain(STRINGS.toolCallStatusFailed.split(' <reason>')[0]);
    // Story 5.8: and there is no audit entry to offer, because the marker was dropped. Offering
    // one would be the panel inventing a row the user could go and fail to find.
    expect(reply).not.toContain(STRINGS.agentAuditFollowUpQuestion);
  });

  it('AC: a confirmed write that was marked reads done \u00b7 audit marked, and the reply gains no sentence', async () => {
    const { host, fixture } = await mountDecidable({
      [proposalConfirmPath('p1')]: [
        {
          kind: 'ok',
          status: 200,
          body: {
            proposalId: 'p1',
            state: 'confirmed',
            closedReason: '',
            confirmedAt: '2026-09-19T10:31:04Z',
            auditMarked: true,
          },
        },
      ],
    });
    (host.querySelector('.ocu-proposal-card-confirm') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();

    const card = host.querySelector('app-tool-call-card') as HTMLElement;
    const word = card.querySelector('.ocu-tool-call-status-word') as HTMLElement;
    expect(word.textContent?.trim()).toBe(STRINGS.auditMarkerMarked);
    expect(word.classList.contains('ocu-tool-call-status-warning')).toBe(false);
    const reply = host.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '';
    expect(reply).not.toContain(STRINGS.auditMarkerReplySentence);
    // AC3 (Story 5.8): the reply ends with the published audit-entry offer, appended by this panel
    // the way the confirm, change and marker sentences are -- "the agent ends with an offer" is
    // not assertable against model-authored prose.
    //
    // mutation: drop the `replyWithAuditOfferSentence` call from `Panel.turns` -> this goes red.
    expect(reply.trimEnd().endsWith(STRINGS.agentAuditFollowUpQuestion)).toBe(true);
  });

  it('AC: the audit-entry offer is appended once, even to a reply that already ends with it', async () => {
    // Idempotent like the other three appenders. **Driven against a MODEL-AUTHORED reply that
    // already carries the sentence**, which is the only shape the guard can be observed in:
    // `Panel.turns` is a getter that recomposes from the store's pristine `entry.reply` on every
    // read, so repeated renders each append to text that never carries the sentence yet and would
    // read "appended once" whether the guard existed or not. A model that ends its own reply with
    // the published question is the case the guard is for, and the one that doubles it without.
    //
    // mutation: drop the `endsWith(STRINGS.agentAuditFollowUpQuestion)` early return from
    // `Panel.replyWithAuditOfferSentence` -> this goes red at length 3.
    const { host, fixture } = await mountDecidable(
      {
        [proposalConfirmPath('p1')]: [
          {
            kind: 'ok',
            status: 200,
            body: {
              proposalId: 'p1',
              state: 'confirmed',
              closedReason: '',
              confirmedAt: '2026-09-19T10:31:04Z',
              auditMarked: true,
            },
          },
        ],
      },
      [wireProposal()],
      'I enabled it and granted the resource. ' + STRINGS.agentAuditFollowUpQuestion
    );
    (host.querySelector('.ocu-proposal-card-confirm') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();
    fixture.detectChanges();
    const reply = host.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '';
    expect(reply.split(STRINGS.agentAuditFollowUpQuestion)).toHaveLength(2);
  });

  it('Story 5.7: a confirmed write names its change in the reply, once, so an expired toast loses nothing', async () => {
    // The toast is transient and may never have been raised at all -- the user may have been
    // looking at the very screen that changed -- so the turn's own record carries the same
    // published sentence. The sentence is the panel's copy, not the model's: "the agent's reply
    // names the change" is not assertable against model-authored prose.
    //
    // Mutation (Rule 19): drop the `text.includes(sentence)` guard in `replyWithChangeSentence`
    // -> the "once" assertion goes red on a doubled sentence, which the `toContain` half above
    // would not see.
    const { host, fixture } = await mountDecidable({
      [proposalConfirmPath('p1')]: [
        {
          kind: 'ok',
          status: 200,
          body: {
            proposalId: 'p1',
            state: 'confirmed',
            closedReason: '',
            confirmedAt: '2026-09-19T10:31:04Z',
            auditMarked: true,
          },
        },
      ],
    });
    const before = host.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '';
    const sentence = STRINGS.tableChangeUpdated.replace('<entity>', '/csp/myapp');
    expect(before).not.toContain(sentence);

    (host.querySelector('.ocu-proposal-card-confirm') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();

    const reply = host.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '';
    expect(reply).toContain(sentence);
    expect(reply.split(sentence)).toHaveLength(2);
    // The published word, not a placeholder: shipping `<entity>` is what a formatter exists to stop.
    expect(reply).not.toContain('<entity>');
  });

  it('Story 5.7: a cancelled card names no change -- nothing was written', async () => {
    const { host, fixture } = await mountDecidable({
      [proposalCancelPath('p1')]: [
        { kind: 'ok', status: 200, body: { proposalId: 'p1', state: 'canceled', closedReason: 'you', confirmedAt: '' } },
      ],
    });
    (host.querySelector('.ocu-proposal-card-cancel') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();

    const reply = host.querySelector('.ocu-panel-message-agent-text')?.textContent ?? '';
    expect(reply).not.toContain(STRINGS.tableChangeUpdated.replace('<entity>', '/csp/myapp'));
  });

  it('Cancel reaches the instance as well as the card (DW-1243)', async () => {
    // Mutation (Rule 19): drop the `turn.cancelProposal` call from `onCardCancel` -> this goes
    // red, and a card the user cancelled would still be claimable on the instance.
    const { host, fixture, api } = await mountDecidable({
      [proposalCancelPath('p1')]: [
        { kind: 'ok', status: 200, body: { proposalId: 'p1', state: 'canceled', closedReason: 'you', confirmedAt: '' } },
      ],
    });
    (host.querySelector('.ocu-proposal-card-cancel') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();
    expect(api.calls.some((call) => call.path === proposalCancelPath('p1') && call.method === 'POST')).toBe(true);
    expect(host.querySelector('.ocu-proposal-card-status')?.textContent?.trim()).toBe(
      STRINGS.proposalStatusCanceledByYou
    );
  });

  it('DW-1224: Re-propose sends the message that produced the card, as a new turn', async () => {
    // Mutation (Rule 19): have `onCardRepropose` send the composer's draft instead of the turn's
    // own message -> this goes red, and Re-propose would ask for something the user never said.
    const { host, fixture, api } = await mountDecidable({}, [
      wireProposal({ state: 'canceled', closedReason: 'target-changed' }),
    ]);
    expect(host.querySelector('.ocu-proposal-card-repropose')).not.toBeNull();
    const before = api.calls.filter((call) => call.path === TURN_PATH).length;

    (host.querySelector('.ocu-proposal-card-repropose') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();

    const sent = api.calls.filter((call) => call.path === TURN_PATH);
    expect(sent.length).toBe(before + 1);
    expect(JSON.parse(String(sent[sent.length - 1].body ?? '{}')).message).toBe(
      'enable the demo application'
    );
  });

  it('DW-1231: Re-propose draws the same close the instance performs on the accepted turn', async () => {
    // Mutation (Rule 19): drop the `cancelLiveCards` call from `onCardRepropose` -> this goes red,
    // and a card would keep offering Confirm for a row the turn's own start had canceled.
    const { host, fixture } = await mountDecidable(
      {
        // Two turn starts: the one that produced the cards, and the one Re-propose asks for. The
        // close is drawn only on an accepted send, so the second answer has to be one.
        [TURN_PATH]: [
          { kind: 'ok', status: 202, body: { turnId: 'turn-1' } },
          { kind: 'ok', status: 202, body: { turnId: 'turn-2' } },
        ],
      },
      [
        wireProposal({ proposalId: 'p1', state: 'canceled', closedReason: 'target-changed' }),
        wireProposal({ proposalId: 'p2' }),
      ]
    );
    const liveBefore = host.querySelectorAll('.ocu-proposal-card-confirm').length;
    expect(liveBefore).toBe(1);

    (host.querySelector('.ocu-proposal-card-repropose') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();

    const lines = [...host.querySelectorAll('.ocu-proposal-card-status')].map((node) =>
      (node.textContent ?? '').trim()
    );
    expect(lines).toContain(STRINGS.proposalStatusCanceledByMessage);
    // The outgoing buttons stay `aria-disabled` in the DOM until the status line has had its
    // chance at focus, so the count is read on the macrotask after the transition.
    await new Promise((resolve) => setTimeout(resolve, 0));
    fixture.detectChanges();
    expect(host.querySelectorAll('.ocu-proposal-card-confirm').length).toBe(0);
  });

  it('DW-1231: a send the instance refused leaves the cards live', async () => {
    const { schedule, scheduled } = fakeTurnSchedule();
    const api = fakeTurnApi({
      [CONVERSATION_PATH]: [{ kind: 'ok', status: 201, body: { conversationId: 'convo-1' } }],
      [TURN_PATH]: [
        { kind: 'ok', status: 202, body: { turnId: 'turn-1' } },
        { kind: 'error', status: 503, code: 'TURN.UNAVAILABLE', reason: 'no job slot', detail: null },
      ],
      [turnProgressPath('turn-1')]: [progressWith([wireProposal()])],
    });
    const turn = stubTurnStore({ api: api as never, schedule });
    const { host, fixture } = await mount({ rows: [{ enabled: true }], turn });
    await typeDraft(host, fixture, 'enable the demo application');
    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    scheduled.shift()?.run();
    await turnSettle();
    fixture.detectChanges();
    expect(host.querySelector('.ocu-proposal-card-confirm')).not.toBeNull();

    await typeDraft(host, fixture, 'yes');
    (host.querySelector('.ocu-panel-send') as HTMLButtonElement).click();
    await turnSettle();
    fixture.detectChanges();
    expect(host.querySelector('.ocu-proposal-card-status')).toBeNull();
    expect(host.querySelector('.ocu-proposal-card-confirm')).not.toBeNull();
  });
});
