import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { entityKeyOf, rowFor } from '../../core/table-model';
import { ListPage } from '../../shell/list-page';
import {
  PAGE_RESOURCE_ASSIGN,
  PAGE_RESOURCE_CHANGE,
  PAGE_RESOURCE_CLEAR,
  PAGE_RESOURCE_LIST,
  PAGE_RESOURCE_VALUE,
  ScreenActionHandler,
  type ActionRefusal,
} from '../../shell/screen-action-handler';
import {
  PageResourcesDialog,
  type PageResourceEntry,
  type PageResourceMode,
  type PageResourceReview,
} from './page-resources-dialog';

/** `value` as text, or `''`. */
function text(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

/** The sentence a refusal shows in the dialog: the one the instance gave a field, else the envelope's own. */
function sentenceOf(refusal: ActionRefusal | null): string {
  if (refusal === null) return '';
  return refusal.violations.find((entry) => entry.reason !== '')?.reason ?? refusal.reason;
}

/**
 * Page resources (Story 21.37, AD-44, AD-64): the shared list page and, over it, the dialog of the action the person started.
 *
 * **All three actions are this page's own.** The shell's handler draws none of them, so this page registers Assign resource, Change resource and
 * Clear resource on the list, and every surface that offers one opens this page's dialog. Assign and Change both send the declared `change`, the
 * one tool the route serves for a resource, with the page as the target and the resource as the value `Resource`; Clear sends `clear`.
 *
 * **Each dialog is reviewed before it is saved.** The dialog hands on the page and resource it holds, and the page asks the instance for the review
 * through the handler's `dryRunFor` (AD-53), keeps only the answer to the latest ask, and passes it back for the dialog to draw. A new ask clears
 * the previous refusal. A refused review puts its sentence in the dialog, which stays open; so does a refused save, and an applied one closes it, the
 * handler's change event re-reading the list (AD-14).
 */
@Component({
  selector: 'app-page-resources-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, PageResourcesDialog],
  // The height chain every page host carries, so the list's viewport keeps its height.
  styles: `
    :host {
      display: flex;
      flex: 1 1 auto;
      flex-direction: column;
      min-height: 0;
    }
  `,
  template: `<app-list-page />
    @if (openMode; as mode) {
      <app-page-resources-dialog
        [mode]="mode"
        [page]="page()"
        [current]="held()"
        [review]="review()"
        [sending]="sending()"
        [refusal]="refusal()"
        (reviewRequested)="onReview($event)"
        (submitted)="onSubmit($event)"
        (cancelled)="onClose()"
      />
    }`,
})
export class PageResourcesPage {
  private readonly stores = inject(ScreenStores);

  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  /** What the open dialog does, or `null` while none is open. */
  protected readonly open = signal<PageResourceMode | null>(null);

  /** The page Change and Clear act on, and the resource it held when the dialog opened. */
  protected readonly page = signal('');

  protected readonly held = signal('');

  protected readonly review = signal<PageResourceReview | null>(null);

  protected readonly sending = signal(false);

  protected readonly refusal = signal('');

  /** Which review ask is current; an answer carrying an older one is dropped. */
  private ask = 0;

  /** What the open dialog does, `null` (falsy) while none is open. */
  protected get openMode(): PageResourceMode | null {
    return this.open();
  }

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === PAGE_RESOURCE_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stops = [
      this.actions.register(PAGE_RESOURCE_LIST, PAGE_RESOURCE_ASSIGN, () => this.onOpen('assign')),
      this.actions.register(PAGE_RESOURCE_LIST, PAGE_RESOURCE_CHANGE, () => this.onOpen('change')),
      this.actions.register(PAGE_RESOURCE_LIST, PAGE_RESOURCE_CLEAR, () => this.onOpen('clear')),
    ];
    inject(DestroyRef).onDestroy(() => {
      for (const stop of stops) stop();
    });
  }

  /**
   * Open the dialog, never over another dialog. Change and Clear open over the selected row, whose page and held resource they read; with no
   * selection they open nothing.
   */
  protected onOpen(mode: PageResourceMode): void {
    if (this.open() !== null || this.handler.pending() !== null || this.store === null) return;
    let page = '';
    let held = '';
    if (mode !== 'assign') {
      const screen = SCREENS.find((entry) => entry.descriptor === PAGE_RESOURCE_LIST);
      const selected = entityKeyOf(this.store.selection()[0] ?? '');
      const row = screen === undefined ? null : rowFor(this.store.data(), screen, selected);
      if (row === null) return;
      page = selected;
      held = text(row['Resource']);
    }
    this.store.setRefusal('');
    this.ask += 1;
    this.page.set(page);
    this.held.set(held);
    this.review.set(null);
    this.refusal.set('');
    this.open.set(mode);
  }

  protected onClose(): void {
    this.ask += 1;
    this.open.set(null);
    this.review.set(null);
    this.refusal.set('');
  }

  /** Ask the instance to review `entry`, and keep the answer only if it is still the latest ask of the dialog that is open. */
  protected async onReview(entry: PageResourceEntry): Promise<void> {
    const mode = this.open();
    if (mode === null) return;
    const ask = ++this.ask;
    const clearing = mode === 'clear';
    // An earlier answer does not stand for this ask: the dialog takes a refusal as the review of what it asked last.
    this.refusal.set('');
    const run = await this.handler.dryRunFor(
      PAGE_RESOURCE_LIST,
      clearing ? PAGE_RESOURCE_CLEAR : PAGE_RESOURCE_CHANGE,
      entry.page,
      clearing ? undefined : { [PAGE_RESOURCE_VALUE]: entry.resource }
    );
    if (ask !== this.ask || this.open() !== mode) return;
    if (run.kind === 'refused') {
      this.review.set(null);
      this.refusal.set(sentenceOf(run.refusal));
      return;
    }
    const titles = run.review['Screens'];
    const code = run.review['Consequence'];
    const current = run.review['Current'];
    this.refusal.set('');
    this.review.set({
      page: entry.page,
      resource: entry.resource,
      screens: Array.isArray(titles) ? (titles as readonly unknown[]).filter((title): title is string => typeof title === 'string') : [],
      consequence: typeof code === 'string' ? code : '',
      ...(typeof current === 'string' ? { held: current } : {}),
    });
  }

  /** One save through the handler's `sendFor`, a refusal kept in the dialog; an applied save closes it. */
  protected async onSubmit(entry: PageResourceEntry): Promise<void> {
    const mode = this.open();
    if (mode === null || this.sending()) return;
    const clearing = mode === 'clear';
    // A review still in flight no longer answers the dialog, so it cannot wipe this save's refusal.
    this.ask += 1;
    this.sending.set(true);
    this.refusal.set('');
    const applied = await this.handler.sendFor(
      PAGE_RESOURCE_LIST,
      clearing ? PAGE_RESOURCE_CLEAR : PAGE_RESOURCE_CHANGE,
      entry.page,
      clearing ? undefined : { [PAGE_RESOURCE_VALUE]: entry.resource },
      { setRefusal: () => undefined }
    );
    this.sending.set(false);
    // A dialog closed while this send was in flight no longer answers it.
    if (this.open() !== mode) return;
    if (applied) {
      this.onClose();
      return;
    }
    this.refusal.set(sentenceOf(this.handler.lastRefusal()));
  }
}
