import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { rowFor } from '../../core/table-model';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { InteropItemSettingDialog } from './interop-item-setting-dialog';

/** The Item settings list's descriptor (Story 20.22). */
export const INTEROP_ITEM_SETTING_LIST = 'OcuPilot.Screen.Descriptor.InteropItemSettingList';

/** The declared row action Set value, which this page's dialog sends. */
export const INTEROP_SETTING_SET_ACTION = 'set';

/** The value the dialog sends beside the setting's id, under the name its tool declares (AD-56). */
export const SETTING_VALUE = 'Value';

/** The setting the open dialog changes: its id and what its row reported. */
interface SettingTarget {
  readonly id: string;
  readonly name: string;
  readonly current: string;
  readonly defaultValue: string;
  readonly type: string;
  readonly location: boolean;
}

/** `value` as text, or `''`. */
function text(value: unknown): string {
  return typeof value === 'string' || typeof value === 'number' ? String(value) : '';
}

/**
 * Interoperability's Item settings (Story 20.22, AD-5): the shared list page, over it the Set value dialog.
 *
 * **Set value is this page's own action**, registered on the descriptor after injecting the shell's handler,
 * whose construction registers the list's declared Reset to default. Opening reads the selected row: a setting
 * that holds a secret opens no dialog and puts its sentence on the list's banner, because OcuPilot neither
 * shows nor sets it. The value is sent through the handler's `sendFor` with `Value` as its one value, an empty
 * one allowed. A refusal stays in the dialog, on the value's field where the instance names it; an applied
 * change closes the dialog, and the handler's change event re-reads the list (AD-14).
 */
@Component({
  selector: 'app-interop-item-setting-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, InteropItemSettingDialog],
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
    @if (openTarget; as target) {
      <app-interop-item-setting-dialog
        [name]="target.name"
        [current]="target.current"
        [defaultValue]="target.defaultValue"
        [type]="target.type"
        [location]="target.location"
        [sending]="sending()"
        [refusal]="refusal()"
        [violation]="violation()"
        (submitted)="onSet($event)"
        (cancelled)="onClose()"
      />
    }`,
})
export class InteropItemSettingListPage {
  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own action: its constructor registers Reset to default. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  /** The setting the open dialog changes, or `null` while none is open. */
  protected readonly target = signal<SettingTarget | null>(null);

  protected readonly sending = signal(false);

  protected readonly refusal = signal('');

  protected readonly violation = signal('');

  protected get openTarget(): SettingTarget | null {
    return this.target();
  }

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_ITEM_SETTING_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stop = this.actions.register(INTEROP_ITEM_SETTING_LIST, INTEROP_SETTING_SET_ACTION, () => this.onOpen());
    inject(DestroyRef).onDestroy(stop);
  }

  /**
   * Open the dialog on the selected row, never over another dialog. A secret setting opens none: its sentence goes
   * on the list's banner. With no selection nothing opens: the surfaces already draw the action unavailable.
   */
  protected onOpen(): void {
    if (this.target() !== null || this.handler.pending() !== null) return;
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_ITEM_SETTING_LIST);
    const store = this.store;
    if (screen === undefined || store === null) return;
    const selected = store.selection()[0] ?? '';
    const row = rowFor(store.data(), screen, selected);
    if (row === null) return;
    if (row['Secret'] === true) {
      store.setRefusal(STRINGS.interopSettingRefusalSecret);
      return;
    }
    store.setRefusal('');
    this.refusal.set('');
    this.violation.set('');
    this.target.set({
      id: selected,
      name: text(row['Name']),
      current: text(row['Value']),
      defaultValue: text(row['Default']),
      type: text(row['Type']),
      location: row['Location'] === true,
    });
  }

  protected onClose(): void {
    this.target.set(null);
    this.refusal.set('');
    this.violation.set('');
  }

  /**
   * One Set value through the handler's `sendFor`, the refusal kept in the dialog rather than on the list's
   * banner: the sentence the instance gave the value field, else the envelope's own.
   */
  protected async onSet(value: string): Promise<void> {
    const target = this.target();
    if (target === null || this.sending()) return;
    this.sending.set(true);
    this.refusal.set('');
    this.violation.set('');
    const applied = await this.handler.sendFor(INTEROP_ITEM_SETTING_LIST, INTEROP_SETTING_SET_ACTION, target.id, { [SETTING_VALUE]: value }, { setRefusal: () => undefined });
    this.sending.set(false);
    // A dialog canceled while this send was in flight no longer answers it.
    if (this.target() !== target) return;
    if (applied) {
      this.onClose();
      return;
    }
    const refused = this.handler.lastRefusal();
    const onField = refused?.violations.find((entry) => entry.field === SETTING_VALUE)?.reason ?? '';
    if (onField !== '') this.violation.set(onField);
    else this.refusal.set(refused?.reason ?? '');
  }
}
