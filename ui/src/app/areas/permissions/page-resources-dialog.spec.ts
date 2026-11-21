import { Component, signal } from '@angular/core';
import { TestBed } from '@angular/core/testing';
import { afterEach, describe, expect, it } from 'vitest';

import { OverlayStack } from '../../core/overlay-stack';
import { STRINGS } from '../../core/strings';
import {
  PageResourcesDialog,
  replacesLine,
  type PageResourceEntry,
  type PageResourceMode,
  type PageResourceReview,
} from './page-resources-dialog';

/** A host that sets the dialog's state and records what it emitted, which is all a caller reads. */
@Component({
  selector: 'app-page-resources-host',
  imports: [PageResourcesDialog],
  template: `<app-page-resources-dialog
    [mode]="mode()"
    [page]="page()"
    [current]="current()"
    [review]="review()"
    [sending]="sending()"
    [refusal]="refusal()"
    (reviewRequested)="reviews.set([...reviews(), $event])"
    (submitted)="saves.set([...saves(), $event])"
    (cancelled)="cancels.set(cancels() + 1)"
  />`,
})
class Host {
  readonly mode = signal<PageResourceMode>('assign');
  readonly page = signal('');
  readonly current = signal('');
  readonly review = signal<PageResourceReview | null>(null);
  readonly sending = signal(false);
  readonly refusal = signal('');
  readonly reviews = signal<PageResourceEntry[]>([]);
  readonly saves = signal<PageResourceEntry[]>([]);
  readonly cancels = signal(0);
}

const PAGE = '%CSP.UI.Portal.Users';

const titles = (count: number): string[] => Array.from({ length: count }, (_, index) => `Screen ${index + 1}`);

/**
 * Page resources' dialog (Story 21.37): its three titles, Assign's two fields and Change's read-only page, the line that states which screens follow
 * the page (one, up to five, six or more, and none), the consequence line, Save kept unavailable while the resource is empty or unchanged, the review
 * asked once a typed page and resource are left, and Clear's confirmation with its warning.
 */
describe('the Page resources dialog (Story 21.37)', () => {
  let fixture: ReturnType<typeof TestBed.createComponent<Host>>;
  let host: HTMLElement;
  let model: Host;

  function mount(setup: (model: Host) => void = () => undefined): void {
    TestBed.configureTestingModule({ providers: [{ provide: OverlayStack, useValue: new OverlayStack() }] });
    fixture = TestBed.createComponent(Host);
    model = fixture.componentInstance;
    setup(model);
    host = fixture.nativeElement as HTMLElement;
    document.body.appendChild(host);
    fixture.detectChanges();
  }

  afterEach(() => {
    host.remove();
    TestBed.resetTestingModule();
  });

  const title = (): string => host.querySelector('.ocu-dialog-title')?.textContent?.trim() ?? '';
  const field = (name: string): HTMLInputElement => host.querySelector(`[data-field="${name}"]`) as HTMLInputElement;
  const submit = (): HTMLButtonElement => host.querySelector('.ocu-page-resources-submit') as HTMLButtonElement;
  const line = (): string => host.querySelector('.ocu-page-resources-line')?.textContent?.trim() ?? '';
  const consequence = (): string => host.querySelector('.ocu-page-resources-consequence')?.textContent?.trim() ?? '';

  function type(name: string, value: string): void {
    const input = field(name);
    input.value = value;
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();
  }

  const review = (screens: readonly string[], page = PAGE, resource = 'ResA', consequenceCode = ''): PageResourceReview => ({ page, resource, screens, consequence: consequenceCode });

  // Mutation (Rule 19): swap the Assign and Change titles, or fill the page into Assign's -> the titles go red.
  it('titles Assign, Change and Clear as the ruled strings do', () => {
    mount();
    expect(title()).toBe('Assign a resource to a page');
    expect(submit().textContent?.trim()).toBe('Assign resource');
    host.remove();
    TestBed.resetTestingModule();
    mount((m) => {
      m.mode.set('change');
      m.page.set(PAGE);
      m.current.set('ResA');
    });
    expect(title()).toBe(`Change the resource of ${PAGE}`);
    expect(submit().textContent?.trim()).toBe('Change resource');
    host.remove();
    TestBed.resetTestingModule();
    mount((m) => {
      m.mode.set('clear');
      m.page.set(PAGE);
      m.current.set('ResA');
    });
    expect(title()).toBe(`Clear the resource of ${PAGE}`);
    expect(submit().textContent?.trim()).toBe('Clear resource');
  });

  // Mutation (Rule 19): drop `[readOnly]` from the page field -> the Change leg goes red; make Assign's page read-only -> the typing legs go red.
  it("Assign asks for the page and the resource with their help; Change shows its page read-only beside the resource the page holds", () => {
    mount();
    expect(host.querySelector('label[for]')?.textContent?.trim()).toBe(STRINGS.explorerSqlDataPage);
    expect(field('page').readOnly).toBe(false);
    expect(field('resource').value).toBe('');
    const help = Array.from(host.querySelectorAll('.ocu-field-caption')).map((node) => node.textContent?.trim());
    expect(help).toEqual(['Name a classic page by its class.', 'Name a resource this instance defines.']);
    host.remove();
    TestBed.resetTestingModule();
    mount((m) => {
      m.mode.set('change');
      m.page.set(PAGE);
      m.current.set('ResA');
    });
    expect(field('page').value).toBe(PAGE);
    expect(field('page').readOnly).toBe(true);
    expect(field('resource').value).toBe('ResA');
  });

  describe('the replaces line', () => {
    // Mutation (Rule 19): list every title instead of at most five and then the count -> the six-or-more legs go red; drop the singular branch
    // -> the one-screen leg goes red.
    it('is the singular line for one screen, naming it', () => {
      expect(replacesLine(['Users'])).toBe("Users follows this page's resource and will require it from the next request.");
    });

    it('is the plural line for two to five screens, naming each and no count of the rest', () => {
      expect(replacesLine(titles(2))).toBe("These 2 screens follow this page's resource and will require it from the next request: Screen 1, Screen 2.");
      expect(replacesLine(titles(5))).toBe(
        "These 5 screens follow this page's resource and will require it from the next request: Screen 1, Screen 2, Screen 3, Screen 4, Screen 5."
      );
    });

    it('names five titles and counts the rest for six or more screens', () => {
      expect(replacesLine(titles(6))).toBe(
        "These 6 screens follow this page's resource and will require it from the next request: Screen 1, Screen 2, Screen 3, Screen 4, Screen 5, and 1 more."
      );
      expect(replacesLine(titles(22))).toBe(
        "These 22 screens follow this page's resource and will require it from the next request: Screen 1, Screen 2, Screen 3, Screen 4, Screen 5, and 17 more."
      );
    });

    it('shows a title that holds a placeholder as written', () => {
      expect(replacesLine(['$&<count>'])).toBe("$&<count> follows this page's resource and will require it from the next request.");
      expect(replacesLine(['<titles>', 'B'])).toBe("These 2 screens follow this page's resource and will require it from the next request: <titles>, B.");
    });

    it('says only the classic portal uses the resource where no screen follows the page', () => {
      expect(replacesLine([])).toBe('No OcuPilot screen replaces this page, so only the classic portal uses this resource.');
    });

    // Mutation (Rule 19): draw the line from a review that is not the typed page and resource -> the stale legs go red.
    it("is drawn in the dialog only from the review of exactly what is typed, and states the line for each count", () => {
      mount((m) => {
        m.mode.set('change');
        m.page.set(PAGE);
        m.current.set('ResA');
      });
      expect(line()).toBe('');
      model.review.set(review(['Users'], PAGE, 'ResA'));
      fixture.detectChanges();
      expect(line()).toBe("Users follows this page's resource and will require it from the next request.");
      model.review.set(review(titles(5), PAGE, 'ResA'));
      fixture.detectChanges();
      expect(line()).toBe(replacesLine(titles(5)));
      model.review.set(review(titles(6), PAGE, 'ResA'));
      fixture.detectChanges();
      expect(line()).toContain(', and 1 more.');
      type('resource', 'ResB');
      expect(line()).toBe('');
    });
  });

  // Mutation (Rule 19): state a change's consequence for the resource the page holds -> the unchanged leg goes red; drop the cleared branch -> the Clear
  // leg goes red.
  it('states the change consequence, naming every screen, only where the resource differs from the one the page holds', () => {
    mount((m) => {
      m.mode.set('change');
      m.page.set(PAGE);
      m.current.set('ResA');
      m.review.set(review(['Users', 'Roles'], PAGE, 'ResA', 'PAGERESOURCE.CHANGED'));
    });
    expect(consequence()).toBe('');
    type('resource', 'ResB');
    expect(consequence()).toBe('');
    model.review.set(review(['Users', 'Roles'], PAGE, 'ResB', 'PAGERESOURCE.CHANGED'));
    fixture.detectChanges();
    expect(consequence()).toBe('Accounts that hold only the old resource can no longer open Users, Roles.');
    model.review.set(review(['Users'], PAGE, 'ResB', ''));
    fixture.detectChanges();
    expect(consequence()).toBe('');
  });

  // Mutation (Rule 19): enable Save while the typed resource equals the held one, or while it is empty -> the matching leg goes red.
  it('keeps Save unavailable while the resource is empty or is the one the page already holds, and hands the page and resource on once it is not', () => {
    mount((m) => {
      m.mode.set('change');
      m.page.set(PAGE);
      m.current.set('ResA');
    });
    expect(submit().getAttribute('aria-disabled')).toBe('true');
    submit().click();
    expect(model.saves()).toEqual([]);
    type('resource', '  ');
    expect(submit().getAttribute('aria-disabled')).toBe('true');
    type('resource', ' ResB ');
    expect(submit().getAttribute('aria-disabled')).toBe('true');
    model.review.set(review([], PAGE, 'ResB'));
    field('resource').dispatchEvent(new Event('change'));
    fixture.detectChanges();
    expect(submit().getAttribute('aria-disabled')).toBeNull();
    submit().click();
    expect(model.saves()).toEqual([{ page: PAGE, resource: 'ResB' }]);
    model.sending.set(true);
    fixture.detectChanges();
    expect(submit().getAttribute('aria-disabled')).toBe('true');
  });

  it('Assign needs both a page and a resource before Save is available', () => {
    mount();
    expect(submit().getAttribute('aria-disabled')).toBe('true');
    type('resource', 'ResA');
    expect(submit().getAttribute('aria-disabled')).toBe('true');
    type('page', ` ${PAGE} `);
    field('page').dispatchEvent(new Event('change'));
    model.review.set(review([]));
    fixture.detectChanges();
    expect(submit().getAttribute('aria-disabled')).toBeNull();
    submit().click();
    expect(model.saves()).toEqual([{ page: PAGE, resource: 'ResA' }]);
  });

  // Mutation (Rule 19): compare the typed resource with the dialog's opening value only, not the review's held one -> both legs go red.
  it("treats Assign's resource as unchanged when the review answers that the page already holds it", () => {
    mount();
    type('page', PAGE);
    type('resource', 'ResA');
    field('resource').dispatchEvent(new Event('change'));
    model.review.set({ ...review(['Users'], PAGE, 'ResA', 'PAGERESOURCE.CHANGED'), held: 'ResA' });
    fixture.detectChanges();
    expect(line()).toBe("Users follows this page's resource and will require it from the next request.");
    expect(consequence()).toBe('');
    expect(submit().getAttribute('aria-disabled')).toBe('true');
  });

  // Mutation (Rule 19): let Save or Enter send a value whose review has not been answered -> the first saves assertion goes red.
  it('sends nothing on Enter or Save until the review of exactly what is typed is answered, and asks for that review instead', () => {
    const enter = (): void => {
      field('resource').dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter' }));
      fixture.detectChanges();
    };
    mount();
    type('page', PAGE);
    type('resource', 'ResA');
    enter();
    expect(model.saves()).toEqual([]);
    expect(model.reviews()).toEqual([{ page: PAGE, resource: 'ResA' }]);
    enter();
    expect(model.saves()).toEqual([]);
    expect(model.reviews()).toHaveLength(1);
    model.review.set(review(['Users'], PAGE, 'ResA'));
    fixture.detectChanges();
    expect(line()).toBe("Users follows this page's resource and will require it from the next request.");
    enter();
    expect(model.saves()).toEqual([{ page: PAGE, resource: 'ResA' }]);
    type('resource', 'ResB');
    expect(submit().getAttribute('aria-disabled')).toBe('true');
    submit().click();
    expect(model.saves()).toHaveLength(1);
    expect(model.reviews()).toEqual([
      { page: PAGE, resource: 'ResA' },
      { page: PAGE, resource: 'ResB' },
    ]);
    // The instance's refusal answers the review as well, so the refused value can still be sent for the instance to refuse again.
    model.refusal.set('This instance defines no resource of that name.');
    fixture.detectChanges();
    expect(submit().getAttribute('aria-disabled')).toBeNull();
  });

  // Mutation (Rule 19): emit the review on every keystroke, or never on open for Change -> the timing legs go red.
  it("asks for the review when a typed page and resource are left, and for Change's page and held resource when it opens", () => {
    mount();
    type('page', PAGE);
    type('resource', 'ResA');
    expect(model.reviews()).toEqual([]);
    type('resource', 'ResAB');
    field('resource').dispatchEvent(new Event('change'));
    expect(model.reviews()).toEqual([{ page: PAGE, resource: 'ResAB' }]);
    host.remove();
    TestBed.resetTestingModule();
    mount((m) => {
      m.mode.set('change');
      m.page.set(PAGE);
      m.current.set('ResA');
    });
    expect(model.reviews()).toEqual([{ page: PAGE, resource: 'ResA' }]);
  });

  it('asks for nothing while the resource is empty', () => {
    mount();
    type('page', PAGE);
    field('page').dispatchEvent(new Event('change'));
    expect(model.reviews()).toEqual([]);
  });

  // Mutation (Rule 19): drop the warning from the Clear template, or send the held resource -> the Clear legs go red.
  it("Clear carries no field, states the warning and the consequence, asks for its review when it opens, and sends the page with no resource", () => {
    mount((m) => {
      m.mode.set('clear');
      m.page.set(PAGE);
      m.current.set('ResA');
    });
    expect(host.querySelectorAll('input')).toHaveLength(0);
    expect(host.querySelector('.ocu-page-resources-warning')?.textContent?.trim()).toBe('After this, the page needs no custom resource.');
    expect(model.reviews()).toEqual([{ page: PAGE, resource: '' }]);
    expect(consequence()).toBe('');
    model.review.set(review(['Users', 'Roles'], PAGE, '', 'PAGERESOURCE.CLEARED'));
    fixture.detectChanges();
    expect(consequence()).toBe('More accounts may open Users, Roles. The instance still checks what they do there.');
    expect(submit().getAttribute('aria-disabled')).toBeNull();
    submit().click();
    expect(model.saves()).toEqual([{ page: PAGE, resource: '' }]);
  });

  it("shows the instance's refusal in the dialog and reports every dismissal once", () => {
    mount((m) => {
      m.mode.set('change');
      m.page.set(PAGE);
      m.current.set('ResA');
      m.refusal.set('This instance defines no resource of that name.');
    });
    expect(host.querySelector('.ocu-page-resources-refusal')?.textContent?.trim()).toBe('This instance defines no resource of that name.');
    (host.querySelector('.ocu-dialog-actions .ocu-button-secondary') as HTMLButtonElement).click();
    fixture.detectChanges();
    expect(model.cancels()).toBe(1);
  });
});
