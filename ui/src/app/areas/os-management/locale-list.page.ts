import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { rowFor } from '../../core/table-model';
import { ListPage } from '../../shell/list-page';
import { LOCALE_LIST, LOCALE_VALIDATE, ScreenActionHandler } from '../../shell/screen-action-handler';
import { LocaleValidateDialog } from './locale-validate-dialog';

/**
 * Locale definitions (Story 21.14, AD-5): the shared list page and, over it, the Validate dialog while one is open.
 *
 * **Validate is this page's own action.** It is a read, so it has no proposal and no write: the shell's handler leaves it undrawn, and this page
 * registers it on the list after injecting that handler -- whose construction registers Install and Delete, each the typed-name dialog of the
 * handler. Every surface that offers Validate opens this page's dialog on the selected locale, never over another dialog.
 */
@Component({
  selector: 'app-locale-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, LocaleValidateDialog],
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
    @if (openLocale; as locale) {
      <app-locale-validate-dialog [name]="locale" (closed)="onClose()" />
    }`,
})
export class LocaleListPage {
  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own action: it registers Install and Delete. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  /** The locale the open dialog validates, or `null` while none is open. */
  protected readonly target = signal<string | null>(null);

  protected get openLocale(): string | null {
    return this.target();
  }

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === LOCALE_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stop = this.actions.register(LOCALE_LIST, LOCALE_VALIDATE, () => this.onOpen());
    inject(DestroyRef).onDestroy(() => stop());
  }

  /** Open the dialog on the selected locale, never over another dialog and never with none selected. */
  protected onOpen(): void {
    if (this.target() !== null || this.handler.pending() !== null || this.store === null) return;
    const screen = SCREENS.find((entry) => entry.descriptor === LOCALE_LIST);
    if (screen === undefined) return;
    const row = rowFor(this.store.data(), screen, this.store.selection()[0] ?? '');
    const name = row?.['Name'];
    if (typeof name !== 'string' || name === '') return;
    this.target.set(name);
  }

  protected onClose(): void {
    this.target.set(null);
  }
}
