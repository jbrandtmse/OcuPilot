import { ComponentFixture, TestBed } from '@angular/core/testing';
import { describe, expect, it } from 'vitest';

import { AgentStatus } from '../core/agent-status';
import { NavigationService, UNGATED, type Verdict } from '../core/navigation';
import { STRINGS } from '../core/strings';
import { stubAgentStatus } from '../testing/agent-status';
import { Panel } from './panel';

/**
 * The panel's two unconfigured states, asserted against the DOM (AC2 to AC5).
 *
 * The two facts it turns on are arranged the way the instance produces them: a definitions list
 * body with the rows it names, and a navigation map with a verdict for `agent/definitions`. There
 * is no third input, because the panel reads no third source -- which is the property AC5 is
 * about: the only exit from this state is a definition being enabled.
 */

const DENIED: Verdict = { allowed: false, failedPair: 'OcuPilotAdmin:USE' };

/** Everything that would be a way into the example card. AC3's own selector, verbatim. */
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
   * read that failed, which leaves every verdict `UNGATED` -- so a panel keyed off this would name
   * an audience it has no map for. Pinning it true here is what makes `loadedFlag` the only signal
   * the panel can be reading.
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

interface Mounted {
  readonly fixture: ComponentFixture<Panel>;
  readonly navigation: StubNavigation;
  readonly agentStatus: AgentStatus;
  readonly rows: { enabled: boolean }[];
  readonly host: HTMLElement;
}

async function mount(options: { rows?: { enabled: boolean }[]; verdict?: Verdict; loaded?: boolean } = {}): Promise<Mounted> {
  TestBed.resetTestingModule();
  const navigation = new StubNavigation();
  navigation.verdict = options.verdict ?? UNGATED;
  navigation.loadedFlag = options.loaded ?? true;
  const rows = options.rows ?? [];
  const agentStatus = stubAgentStatus(rows);
  await agentStatus.load();
  TestBed.configureTestingModule({
    providers: [
      { provide: NavigationService, useValue: navigation as unknown as NavigationService },
      { provide: AgentStatus, useValue: agentStatus },
    ],
  });
  const fixture = TestBed.createComponent(Panel);
  fixture.detectChanges();
  return { fixture, navigation, agentStatus, rows, host: fixture.nativeElement as HTMLElement };
}

describe('the agent co-pilot panel', () => {
  it('AC2: an administrator sees the reminder banner, with no dismiss control', async () => {
    // Mutation (Rule 19): give the reminder banner a dismiss control -> the no-button assertion
    // below goes red, and the banner becomes a switch the condition does not own.
    const { host } = await mount();
    const banner = host.querySelector('.ocu-panel-banner') as HTMLElement;
    expect(banner).not.toBeNull();
    expect(banner.textContent).toContain(STRINGS.agentGateReminderBanner);
    // No control that dismisses it -- which is what AC2 says, and is deliberately narrower than
    // "nothing focusable". EXPERIENCE.md's own description of this banner is "it carries a link,
    // cannot be dismissed, and goes the moment the condition clears", so an assertion that forbade
    // every focusable node would pin out published behaviour a later story has to add.
    expect(banner.querySelectorAll('button')).toHaveLength(0);
    // And the other audience's sentence is not also on screen.
    expect(host.textContent).not.toContain(STRINGS.agentGateEmptyState);
  });

  it('AC3: a caller the map refuses sees the configuration-empty sentence and the three trust sentences', async () => {
    const { host } = await mount({ verdict: DENIED });
    expect(host.querySelector('.ocu-panel-banner')).toBeNull();
    const empty = host.querySelector('.ocu-panel-empty') as HTMLElement;
    expect(empty.textContent?.trim()).toBe(STRINGS.agentGateEmptyState);

    const trust = Array.from(host.querySelectorAll('.ocu-panel-trust li')).map((node) =>
      node.textContent?.trim()
    );
    expect(trust).toEqual([
      STRINGS.agentTrustReads,
      STRINGS.agentTrustProposes,
      STRINGS.agentTrustAudited,
    ]);
  });

  it('AC3: the example card is labelled with the published band and holds nothing focusable', async () => {
    const { host } = await mount({ verdict: DENIED });
    const example = host.querySelector('.ocu-panel-example') as HTMLElement;
    expect(example.querySelector('.ocu-proposal-card-band')?.textContent?.trim()).toBe(
      STRINGS.proposalExampleCardTitle
    );
    const card = example.querySelector('.ocu-proposal-card') as HTMLElement;
    expect(card).not.toBeNull();
    expect(card.querySelectorAll(FOCUSABLE)).toHaveLength(0);
    expect(card.textContent).not.toContain('Expires in');
  });

  it('AC4: the composer and Send are focusable and aria-disabled, never disabled, with no context chip', async () => {
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
      // And the composer cannot be typed into: `aria-disabled` announces it as inert, so letting
      // a message be composed in it would be the announcement and the behaviour disagreeing.
      // `readonly` keeps it focusable and in the Tab order, which `disabled` would not.
      expect(composer.hasAttribute('readonly')).toBe(true);

      // The reason a control cannot act is the sentence the panel is showing that audience --
      // one element, not a second copy of the words.
      const described = composer.getAttribute('aria-describedby');
      expect(send.getAttribute('aria-describedby')).toBe(described);
      const reason = host.querySelector(`#${described}`) as HTMLElement;
      expect(reason.textContent).toContain(
        verdict.allowed ? STRINGS.agentGateReminderBanner : STRINGS.agentGateEmptyState
      );

      // The composer is labelled, and the published caption is beneath it.
      const label = host.querySelector(`label[for="${composer.id}"]`) as HTMLElement;
      expect(label.textContent?.trim()).toBe(STRINGS.agentComposerLabel);
      expect(host.querySelector('.ocu-panel-caption')?.textContent?.trim()).toBe(
        STRINGS.agentComposerCaption
      );

      // Story 4.3's panel, and nothing of it here: no chip, no resize handle, no full-screen
      // toggle, no transcript and no New conversation.
      expect(host.textContent).not.toContain(STRINGS.agentShareContextLabel);
      expect(host.querySelector('.ocu-context-chip')).toBeNull();
      expect(host.textContent).not.toContain(STRINGS.actionNewConversation);
    }
  });

  it('AC5: the panel offers no control that clears the state, and Enable clears all of it together', async () => {
    // Mutation (Rule 19): require a second condition beside `configured()` -> this goes red.
    const { fixture, host, agentStatus, rows } = await mount();
    const controls = Array.from(host.querySelectorAll(FOCUSABLE)) as HTMLElement[];
    // Two, and they are the composer and Send -- neither of which can act. Nothing here is an
    // exit: the state is the instance's, and only the instance can leave it. (The banner's
    // published link is not built yet, so this list is still exactly the footer's two controls;
    // when it lands, this assertion is what says it is not an exit either.)
    expect(controls.map((node) => node.className)).toEqual([
      'ocu-panel-composer',
      'ocu-button-primary ocu-panel-send',
    ]);

    rows.push({ enabled: true });
    await agentStatus.load();
    fixture.detectChanges();
    expect(agentStatus.configured()).toBe(true);
    expect(host.querySelector('.ocu-panel')).toBeNull();
    expect(host.querySelector('.ocu-proposal-card')).toBeNull();
    expect(host.textContent?.trim()).toBe('');
  });

  it('renders nothing until both facts have answered, so no audience is guessed at', async () => {
    // No map yet: every verdict defaults to *allowed*, which would show an administrator's banner
    // to somebody who cannot act on it. The stub answers `answered()` true throughout, so this
    // also says the panel is reading `loaded()` -- the signal that is false when the read failed.
    //
    // Mutation (Rule 19): read `navigation.answered()` in `shown` -> this goes red, and a map
    // outage tells every non-administrator that configuring the agent is their job.
    const unansweredMap = await mount({ loaded: false, verdict: DENIED });
    expect(unansweredMap.host.querySelector('.ocu-panel')).toBeNull();
    unansweredMap.navigation.loadedFlag = true;
    unansweredMap.navigation.notify();
    unansweredMap.fixture.detectChanges();
    expect(unansweredMap.host.querySelector('.ocu-panel')).not.toBeNull();

    // And the definitions read unanswered: `configured()` is false before any answer, so a panel
    // that did not wait would show an empty state over a configured instance.
    TestBed.resetTestingModule();
    const navigation = new StubNavigation();
    const agentStatus = stubAgentStatus([]);
    TestBed.configureTestingModule({
      providers: [
        { provide: NavigationService, useValue: navigation as unknown as NavigationService },
        { provide: AgentStatus, useValue: agentStatus },
      ],
    });
    const fixture = TestBed.createComponent(Panel);
    fixture.detectChanges();
    expect(agentStatus.answered()).toBe(false);
    expect((fixture.nativeElement as HTMLElement).querySelector('.ocu-panel')).toBeNull();
  });

  it('names its landmark with the area name, so the panel is a named complementary region', async () => {
    const { host } = await mount();
    const aside = host.querySelector('aside') as HTMLElement;
    expect(aside.getAttribute('aria-label')).toBe(STRINGS.navAreaAgent);
  });
});
