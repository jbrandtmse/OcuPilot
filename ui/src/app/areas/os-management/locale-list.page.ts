import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ApiService } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { rowFor } from '../../core/table-model';
import { ListPage } from '../../shell/list-page';
import { LOCALE_COPY, LOCALE_LIST, LOCALE_VALIDATE, ScreenActionHandler } from '../../shell/screen-action-handler';
import { LocaleCopyDialog, type LocaleCopyValues } from './locale-copy-dialog';
import { LOCALE_COPY_PATH, LOCALE_COPY_TOOL, LOCALE_ENTITY, postLocaleCreate } from './locale-create';
import { LocaleValidateDialog } from './locale-validate-dialog';

/**
 * Locale definitions (Story 21.14, AD-5): the shared list page and, over it, the Validate dialog while one is open.
 *
 * **Validate is this page's own action.** It is a read, so it has no proposal and no write: the shell's handler leaves it undrawn, and this page
 * registers it on the list after injecting that handler -- whose construction registers Install and Delete, each the typed-name dialog of the
 * handler. Every surface that offers Validate opens this page's dialog on the selected locale, never over another dialog.
 *
 * **Copy is this page's own action too** (Story 21.16): it opens `LocaleCopyDialog` on the selected locale, and the typed name and description are posted
 * to the copy tool's own Save route with the selected locale as `Source`, which publishes the create. A refusal stays in the dialog.
 */
@Component({
  selector: 'app-locale-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, LocaleValidateDialog, LocaleCopyDialog],
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
    }
    @if (copySource; as source) {
      <app-locale-copy-dialog [source]="source" [refusal]="copyRefusal()" [sending]="copySending()" (submitted)="onCopy($event)" (cancelled)="onCloseCopy()" />
    }`,
})
export class LocaleListPage {
  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own action: it registers Install and Delete. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly api = inject(ApiService);

  private readonly bus = inject(ChangeBus);

  private readonly store: ScreenStore | null;

  /** The locale the open dialog validates, or `null` while none is open. */
  protected readonly target = signal<string | null>(null);

  protected get openLocale(): string | null {
    return this.target();
  }

  /** The locale the open Copy dialog copies, or `null` while none is open. */
  private readonly copyTarget = signal<string | null>(null);

  protected readonly copyRefusal = signal('');

  protected readonly copySending = signal(false);

  protected get copySource(): string | null {
    return this.copyTarget();
  }

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === LOCALE_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stop = this.actions.register(LOCALE_LIST, LOCALE_VALIDATE, () => this.onOpen());
    const stopCopy = this.actions.register(LOCALE_LIST, LOCALE_COPY, () => this.onOpenCopy());
    inject(DestroyRef).onDestroy(() => {
      stop();
      stopCopy();
    });
  }

  /** The selected locale's name, or `''` while none is selected. */
  private selectedName(): string {
    const screen = SCREENS.find((entry) => entry.descriptor === LOCALE_LIST);
    if (screen === undefined || this.store === null) return '';
    const name = rowFor(this.store.data(), screen, this.store.selection()[0] ?? '')?.['Name'];
    return typeof name === 'string' ? name : '';
  }

  /** Open the Copy dialog on the selected locale, never over another dialog and never with none selected. */
  protected onOpenCopy(): void {
    if (this.copyTarget() !== null || this.target() !== null || this.handler.pending() !== null) return;
    const name = this.selectedName();
    if (name === '') return;
    this.copyRefusal.set('');
    this.copyTarget.set(name);
  }

  protected onCloseCopy(): void {
    this.copyTarget.set(null);
    this.copyRefusal.set('');
  }

  /** One Copy posted to the Save route: the typed name is the new locale, the selected locale its `Source`, the refusal kept in the dialog. */
  protected async onCopy(values: LocaleCopyValues): Promise<void> {
    const source = this.copyTarget();
    if (source === null || this.copySending()) return;
    this.copySending.set(true);
    this.copyRefusal.set('');
    const body: Record<string, string> = { Name: values.name, Source: source };
    if (values.description !== '') body['Description'] = values.description;
    const outcome = await postLocaleCreate({
      api: this.api,
      bus: this.bus,
      path: LOCALE_COPY_PATH,
      body,
      type: LOCALE_ENTITY,
      tool: LOCALE_COPY_TOOL,
      fallbackId: values.name,
    });
    this.copySending.set(false);
    // A dialog canceled while the copy was in flight no longer answers it; a locale the instance made is announced all the same.
    if (this.copyTarget() !== source) return;
    if (outcome.accepted) {
      this.onCloseCopy();
      return;
    }
    this.copyRefusal.set(outcome.reason);
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
