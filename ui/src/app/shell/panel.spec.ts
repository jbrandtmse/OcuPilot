import { ComponentFixture, TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { describe, expect, it } from 'vitest';

import { AgentStatus, type Restraint, formatKillSwitch } from '../core/agent-status';
import { NavigationService, UNGATED, type Verdict } from '../core/navigation';
import { PanelState } from '../core/panel-layout';
import { PreferenceStore } from '../core/preferences';
import { ShellState } from '../core/shell-state';
import { STRINGS } from '../core/strings';
import { stubAgentStatus } from '../testing/agent-status';
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
  TestBed.configureTestingModule({
    providers: [
      provideRouter([
        { path: '', children: [] },
        { path: 'agent/definitions', children: [] },
      ]),
      { provide: NavigationService, useValue: navigation as unknown as NavigationService },
      { provide: AgentStatus, useValue: agentStatus },
      { provide: PanelState, useValue: panelState },
    ],
  });
  if (options.url !== undefined) await TestBed.inject(Router).navigateByUrl(options.url);
  const fixture = TestBed.createComponent(Panel);
  fixture.detectChanges();
  return { fixture, navigation, agentStatus, panelState, rows, host: fixture.nativeElement as HTMLElement };
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

    // Two controls in the header, neither of which closes anything; and nothing of Story 4.4 or 4.5.
    const labels = [...aside.querySelectorAll('button')].map(
      (button) => button.getAttribute('aria-label') ?? button.textContent?.trim()
    );
    expect(labels).toEqual([STRINGS.agentPanelFullScreen, STRINGS.actionSend]);
    expect(aside.textContent).not.toContain(STRINGS.actionNewConversation);
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
    expect(panelState.draft()).toBe('Why is /csp/myapp disabled?');
    expect((host.querySelector('.ocu-panel-send') as HTMLElement).getAttribute('aria-disabled')).toBe('true');

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
