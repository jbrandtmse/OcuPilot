import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { parentCriteria, screenForDescriptor } from '../../core/navigation';
import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { rowFor } from '../../core/table-model';
import { reasonForField } from '../../core/violations';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { InteropItemSettingDialog } from './interop-item-setting-dialog';
import { InteropLookupEntryDialog } from './interop-lookup-entry-dialog';

/** The table's entries list's descriptor (Story 20.5). */
export const INTEROP_LOOKUP_ENTRY_LIST = 'OcuPilot.Screen.Descriptor.InteropLookupEntryList';

/** The declared primary action id: the command bar's Add entry, which opens the entry dialog. */
export const INTEROP_LOOKUP_ENTRY_ADD_ACTION = 'add';

/** The declared row action Set value, which this page's dialog sends. */
export const INTEROP_LOOKUP_ENTRY_SET_ACTION = 'set';

/** The value the dialog sends beside the entry's id, under the name its tool declares (AD-56). */
export const LOOKUP_ENTRY_VALUE = 'Value';

/** The entry the open Set value dialog changes: its id and the value its row reported. */
interface EntryTarget {
  readonly id: string;
  readonly current: string;
}

/** `value` as text, or `''`. */
function text(value: unknown): string {
  return typeof value === 'string' || typeof value === 'number' ? String(value) : '';
}

/**
 * Interoperability's lookup table entries (Story 20.5, AD-5): the shared list page, over it the Add entry dialog and
 * the Set value dialog.
 *
 * **Add entry and Set value are this page's own actions**, registered on the descriptor after injecting the shell's
 * handler, whose construction registers the list's declared Remove. Add entry adds to the table the route names, in
 * the namespace the shell is scoped to. Set value opens on the selected row, sends the value through the handler's
 * `sendFor` with `Value` as its one value, an empty one allowed, and keeps a refusal in the dialog, on the value's
 * field where the instance names it; an applied change closes the dialog, and the handler's change event re-reads
 * the list (AD-14). A key that names a credential opens no dialog: its row's `Secret` flag puts the instance's
 * sentence on the list's banner, because OcuPilot neither shows nor sets such a value.
 */
@Component({
  selector: 'app-interop-lookup-entry-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, InteropLookupEntryDialog, InteropItemSettingDialog],
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
    @if (adding) {
      <app-interop-lookup-entry-dialog [namespace]="namespace" [table]="table" (added)="onCloseAdd()" (cancelled)="onCloseAdd()" />
    }
    @if (openTarget; as target) {
      <app-interop-item-setting-dialog
        [title]="setTitle"
        [current]="target.current"
        [multiline]="true"
        [statement]="entryStatement"
        [defaultShown]="false"
        [sending]="sending()"
        [refusal]="refusal()"
        [violation]="violation()"
        (submitted)="onSet($event)"
        (cancelled)="onCloseSet()"
      />
    }`,
})
export class InteropLookupEntryListPage {
  private readonly router = inject(Router);

  private readonly scope = inject(ScopeService);

  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own actions: its constructor registers Remove. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  /** Whether the Add entry dialog is open. */
  private readonly open = signal(false);

  /** The entry the open Set value dialog changes, or `null` while none is open. */
  protected readonly target = signal<EntryTarget | null>(null);

  protected readonly sending = signal(false);

  protected readonly refusal = signal('');

  protected readonly violation = signal('');

  /** The Set value dialog's title and its sentence: an entry is in effect at once, with no production to update. */
  protected readonly setTitle = STRINGS.interopLookupSetDialogTitle;

  protected readonly entryStatement = STRINGS.interopLookupEntryHelp;

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_LOOKUP_ENTRY_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stopAdd = this.actions.register(INTEROP_LOOKUP_ENTRY_LIST, INTEROP_LOOKUP_ENTRY_ADD_ACTION, () => this.onOpenAdd());
    const stopSet = this.actions.register(INTEROP_LOOKUP_ENTRY_LIST, INTEROP_LOOKUP_ENTRY_SET_ACTION, () => this.onOpenSet());
    inject(DestroyRef).onDestroy(() => {
      stopAdd();
      stopSet();
    });
  }

  protected get adding(): boolean {
    return this.open();
  }

  protected get openTarget(): EntryTarget | null {
    return this.target();
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  /** The lookup table the route names: the list's one criterion, read off the URL. */
  protected get table(): string {
    const screen = screenForDescriptor(INTEROP_LOOKUP_ENTRY_LIST);
    if (screen === null) return '';
    return Object.values(parentCriteria(screen, this.router.url))[0] ?? '';
  }

  /** Open the Add entry dialog, never over a dialog of the handler's or the Set value one. */
  protected onOpenAdd(): void {
    if (this.open() || this.target() !== null || this.handler.pending() !== null) return;
    this.open.set(true);
  }

  protected onCloseAdd(): void {
    this.open.set(false);
  }

  /**
   * Open Set value on the selected row, never over another dialog. A credential's key opens none: its sentence goes
   * on the list's banner. With no selection nothing opens: the surfaces already draw the action unavailable.
   */
  protected onOpenSet(): void {
    if (this.target() !== null || this.open() || this.handler.pending() !== null) return;
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_LOOKUP_ENTRY_LIST);
    const store = this.store;
    if (screen === undefined || store === null) return;
    const selected = store.selection()[0] ?? '';
    const row = rowFor(store.data(), screen, selected);
    if (row === null) return;
    if (row['Secret'] === true) {
      store.setRefusal(STRINGS.interopLookupRefusalSecret);
      return;
    }
    store.setRefusal('');
    this.refusal.set('');
    this.violation.set('');
    this.target.set({ id: selected, current: text(row['Value']) });
  }

  protected onCloseSet(): void {
    this.target.set(null);
    this.refusal.set('');
    this.violation.set('');
  }

  /**
   * One Set value through the handler's `sendFor`, the refusal kept in the dialog rather than on the list's banner:
   * the sentence the instance gave the value field, else the envelope's own.
   */
  protected async onSet(value: string): Promise<void> {
    const target = this.target();
    if (target === null || this.sending()) return;
    this.sending.set(true);
    this.refusal.set('');
    this.violation.set('');
    const applied = await this.handler.sendFor(
      INTEROP_LOOKUP_ENTRY_LIST,
      INTEROP_LOOKUP_ENTRY_SET_ACTION,
      target.id,
      { [LOOKUP_ENTRY_VALUE]: value },
      { setRefusal: () => undefined }
    );
    this.sending.set(false);
    // A dialog canceled while this send was in flight no longer answers it.
    if (this.target() !== target) return;
    if (applied) {
      this.onCloseSet();
      return;
    }
    const refused = this.handler.lastRefusal();
    const onField = reasonForField(refused?.violations ?? [], LOOKUP_ENTRY_VALUE);
    if (onField !== '') this.violation.set(onField);
    else this.refusal.set(refused?.reason ?? '');
  }
}
