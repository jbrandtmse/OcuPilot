import { TestBed } from '@angular/core/testing';
import { beforeEach, describe, expect, it } from 'vitest';

import { SCREENS, type ScreenDeclaration } from '../core/screens.generated';
import { STRINGS } from '../core/strings';
import { ClassicLinkCard } from './classic-link-card';

/**
 * The "More in the classic portal" card (FR-9, AD-44).
 *
 * **The subject is the real generated mirror, not a hand-built literal** (Integration AC,
 * Rule 1). `SCREENS` here is `ui/src/app/core/screens.generated.ts` -- the checked-in artifact
 * `ui/tools/screen-mirror.mjs` emits from the XData declarations, whose drift check is
 * `screen-mirror.test.mjs`. The absence half is asserted over **every** screen the mirror
 * carries, which today is Home and from Story 6.4 onward is the first honored exemption too,
 * so this loop is the assertion that keeps tightening rather than one that stops meaning
 * anything. The presence half derives its subject from a real mirror entry by replacing only
 * the exemption object: Epic 1 ships no exempt descriptor -- Home is its one screen and it is
 * not a reduced form -- so a derived declaration is the strongest crossing available here, and
 * it is labelled as derived rather than passed off as the mirror's own.
 *
 * jsdom computes no layout, so nothing here asserts a width; the card's surface is pinned as
 * stylesheet text in `ui/tools/design-tokens.test.mjs`.
 */

const HOME = SCREENS.find((screen) => screen.descriptor === 'OcuPilot.Screen.Descriptor.Home');

// Without this the "real generated mirror" clause cannot fail. `find` is typed
// `ScreenDeclaration | undefined` and the cast below silences the type checker; rename the Home
// descriptor and regenerate, and `HOME` becomes `undefined`, the spread contributes nothing,
// `EXEMPT` degenerates to the three fields written under it, and every assertion in the
// Integration AC still passes over a hand-built literal wearing a spread.
if (HOME === undefined) {
  throw new Error(
    'screens.generated.ts carries no OcuPilot.Screen.Descriptor.Home: the Integration AC has no mirror entry to derive from'
  );
}

/** A real mirror entry with an honored exemption put on it. Derived, not the mirror's own. */
const EXEMPT: ScreenDeclaration = {
  ...(HOME as ScreenDeclaration),
  archetype: 'detail',
  classicPage: 'OcuPilotTestClassicPage',
  classicLinkExemption: {
    exempt: true,
    reason: 'a detail view with no rebuilt equivalent yet',
    label: 'OcuPilot test classic page',
    href: '/csp/sys/OcuPilotTestClassicPage.csp',
  },
};

describe('ClassicLinkCard', () => {
  let fixture: ReturnType<typeof TestBed.createComponent<ClassicLinkCard>>;

  beforeEach(() => {
    TestBed.configureTestingModule({ imports: [ClassicLinkCard] });
    fixture = TestBed.createComponent(ClassicLinkCard);
  });

  function render(screen: ScreenDeclaration | null): HTMLElement {
    fixture.componentRef.setInput('screen', screen);
    fixture.detectChanges();
    return fixture.nativeElement as HTMLElement;
  }

  it('Integration AC: the card renders the published title and one same-origin new-tab anchor', () => {
    const host = render(EXEMPT);

    const card = host.querySelector('.ocu-classic-link-card');
    expect(card).not.toBeNull();
    expect(card?.querySelector('.ocu-classic-link-card-title')?.textContent?.trim()).toBe(
      STRINGS.classicLinkCardTitle
    );

    const anchors = host.querySelectorAll('a');
    expect(anchors.length).toBe(1);
    const anchor = anchors[0];
    expect(anchor.getAttribute('href')).toBe(EXEMPT.classicLinkExemption.href);
    expect(anchor.getAttribute('target')).toBe('_blank');
    expect(anchor.getAttribute('rel')).toBe('noreferrer');
    expect(anchor.classList.contains('ocu-button-secondary')).toBe(true);

    // The visible label is the declared classic page name -- descriptor data naming an
    // external page, like `classicPage` itself, not shell copy the Fixed-strings table
    // governs. The glyph is decoration and is out of the accessible name.
    const glyph = anchor.querySelector('.ocu-external-glyph');
    expect(glyph?.getAttribute('aria-hidden')).toBe('true');
    expect(anchor.textContent).toContain(EXEMPT.classicLinkExemption.label);
    expect(anchor.hasAttribute('aria-label')).toBe(false);
  });

  it('renders nothing at all over a descriptor with no honored exemption', () => {
    // Every screen the real mirror carries. Epic 1's is Home, which is not a reduced form and
    // must therefore grow no card; the same loop covers Story 6.4's exempt descriptor when it
    // lands, which is the point of asserting over the roster rather than over one entry.
    // A loop over an empty roster asserts nothing, so the roster is checked before it is read.
    expect(SCREENS.length).toBeGreaterThan(0);
    for (const screen of SCREENS) {
      const host = render(screen);
      const honored =
        screen.classicLinkExemption.exempt &&
        screen.classicLinkExemption.href !== '' &&
        screen.classicLinkExemption.label !== '';
      if (honored) {
        expect(host.querySelectorAll('a').length, screen.descriptor).toBe(1);
        continue;
      }
      expect(host.querySelector('.ocu-classic-link-card'), screen.descriptor).toBeNull();
      expect(host.querySelectorAll('a').length, screen.descriptor).toBe(0);
    }
  });

  it('renders nothing with no descriptor at all, and nothing for a half-made exemption', () => {
    expect(render(null).querySelectorAll('a').length).toBe(0);

    // The build check and `OcuPilot.Screen.Registry.Validate` refuse both of these before a
    // declaration reaches the mirror. The card still renders nothing rather than a dead
    // control or a link labelled with nothing -- a card with no target is worse than no card.
    const noHref: ScreenDeclaration = {
      ...EXEMPT,
      classicLinkExemption: { ...EXEMPT.classicLinkExemption, href: '' },
    };
    expect(render(noHref).querySelectorAll('a').length).toBe(0);

    const noLabel: ScreenDeclaration = {
      ...EXEMPT,
      classicLinkExemption: { ...EXEMPT.classicLinkExemption, label: '' },
    };
    expect(render(noLabel).querySelectorAll('a').length).toBe(0);
  });

  it('derives no URL from classicPage: the anchor is the declared href and nothing else', () => {
    // AD-44's "never a URL" is scoped to the resource key, and the card is where that scoping
    // could quietly be broken. The classic page's class name must appear nowhere in the
    // rendered href, and changing it must not change where the card goes.
    const movedPage: ScreenDeclaration = { ...EXEMPT, classicPage: 'SomeOther.Portal.Page' };
    const host = render(movedPage);
    const anchor = host.querySelector('a');
    expect(anchor?.getAttribute('href')).toBe(EXEMPT.classicLinkExemption.href);
    expect(anchor?.getAttribute('href')).not.toContain('SomeOther');
    expect(host.innerHTML).not.toContain('SomeOther.Portal.Page');
  });
});
