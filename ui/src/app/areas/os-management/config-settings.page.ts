import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { screenForUrl } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { rowFor } from '../../core/table-model';
import { reasonForField } from '../../core/violations';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { BOOLEAN_TYPE, InteropItemSettingDialog } from '../interoperability/interop-item-setting-dialog';

/** The three descriptors this one page serves (Story 21.3). */
export const STARTUP_SETTING_LIST = 'OcuPilot.Screen.Descriptor.StartupSettingList';
export const MEMORY_SETTING_LIST = 'OcuPilot.Screen.Descriptor.MemorySettingList';
export const COMPATIBILITY_SETTING_LIST = 'OcuPilot.Screen.Descriptor.CompatibilitySettingList';

/** The declared row action Set value, which this page's dialog sends. */
export const CONFIG_SET_ACTION = 'set';

/** The value the dialog sends beside the setting's name, under the name the tools declare (AD-56). */
export const CONFIG_VALUE = 'Value';

/** The setting the open dialog changes: its id and what its row reported. */
interface SettingTarget {
  readonly id: string;
  readonly name: string;
  readonly current: string;
  readonly kind: string;
  readonly restart: boolean;
  readonly statement: string;
}

/** `value` as text, or `''`. */
function text(value: unknown): string {
  return typeof value === 'string' || typeof value === 'number' ? String(value) : '';
}

/**
 * Startup settings, Memory settings and Compatibility settings (Story 21.3, AD-5, AD-53): the shared list page over each
 * descriptor's declared table, and over it the Set value dialog.
 *
 * **One page serves the three descriptors**, which differ only in the class they read; it resolves its screen from the URL, as the list page
 * does. Set value is this page's own action, registered after injecting the shell's handler, and it opens `InteropItemSettingDialog` as it is,
 * with the row's `Accepts` line above the field and, when the row's `Restart` is true, the restart sentence after it.
 *
 * **A row the port reads as shown and never changed offers no Set value**: the registration's reason is the published refusal sentence, so
 * every surface draws the action unavailable with that sentence, and opening it opens nothing. The value goes through the handler's `sendFor`
 * with `Value` as its one value, an empty one allowed. A refusal stays in the dialog, on the value's field where the instance names it. After
 * an applied change on a row whose `Restart` is true, the page states the restart sentence above the list.
 */
@Component({
  selector: 'app-config-settings-page',
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
  template: `@if (shownRestart; as note) {
      <p class="ocu-banner" role="status" data-config-setting-restart>{{ note }}</p>
    }
    <app-list-page />
    @if (openTarget; as target) {
      <app-interop-item-setting-dialog
        [name]="target.name"
        [current]="target.current"
        [type]="target.kind === 'boolean' ? booleanType : ''"
        [statement]="target.statement"
        [defaultShown]="false"
        [sending]="sending()"
        [refusal]="refusal()"
        [violation]="violation()"
        (submitted)="onSet($event)"
        (cancelled)="onClose()"
      />
    }`,
})
export class ConfigSettingsPage {
  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own action, as every page that adds to the handler's does. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly screen: ScreenDeclaration | null;

  private readonly store: ScreenStore | null;

  protected readonly booleanType = BOOLEAN_TYPE;

  /** The setting the open dialog changes, or `null` while none is open. */
  protected readonly target = signal<SettingTarget | null>(null);

  protected readonly sending = signal(false);

  protected readonly refusal = signal('');

  protected readonly violation = signal('');

  /** The restart sentence stated after an applied change that needs one, or `''`. */
  protected readonly restartNote = signal('');

  protected get shownRestart(): string {
    return this.restartNote();
  }

  protected get openTarget(): SettingTarget | null {
    return this.target();
  }

  constructor() {
    const found = screenForUrl(inject(Router).url);
    this.screen = found !== null && this.serves(found.descriptor) ? found : null;
    this.store = this.screen === null ? null : this.stores.for(this.screen.descriptor, this.screen.refreshRates);
    if (this.screen === null) return;
    const stop = this.actions.register(
      this.screen.descriptor,
      CONFIG_SET_ACTION,
      () => this.onOpen(),
      () => (this.selectedRow()?.['ReadOnly'] === true ? STRINGS.configRefusalReadOnly : '')
    );
    inject(DestroyRef).onDestroy(stop);
  }

  private serves(descriptor: string): boolean {
    return descriptor === STARTUP_SETTING_LIST || descriptor === MEMORY_SETTING_LIST || descriptor === COMPATIBILITY_SETTING_LIST;
  }

  /** The selected row, or `null` while none is selected. */
  private selectedRow(): Readonly<Record<string, unknown>> | null {
    if (this.screen === null || this.store === null) return null;
    return rowFor(this.store.data(), this.screen, this.store.selection()[0] ?? '');
  }

  /** Open the dialog on the selected row, never over another dialog and never over a row that is never changed here. */
  protected onOpen(): void {
    if (this.target() !== null || this.handler.pending() !== null || this.store === null) return;
    const selected = this.store.selection()[0] ?? '';
    const row = this.selectedRow();
    if (row === null) return;
    if (row['ReadOnly'] === true) {
      this.store.setRefusal(STRINGS.configRefusalReadOnly);
      return;
    }
    this.store.setRefusal('');
    this.refusal.set('');
    this.violation.set('');
    this.restartNote.set('');
    const accepts = text(row['Accepts']);
    this.target.set({
      id: selected,
      name: text(row['Name']),
      current: text(row['Value']),
      kind: text(row['Kind']),
      restart: row['Restart'] === true,
      statement: row['Restart'] === true ? `${accepts} ${STRINGS.encryptionStartupRestart}` : accepts,
    });
  }

  protected onClose(): void {
    this.target.set(null);
    this.refusal.set('');
    this.violation.set('');
  }

  /**
   * One Set value through the handler's `sendFor`, the refusal kept in the dialog rather than on the list's banner: the sentence the instance
   * gave the value field, else the envelope's own.
   */
  protected async onSet(value: string): Promise<void> {
    const target = this.target();
    if (target === null || this.screen === null || this.sending()) return;
    this.sending.set(true);
    this.refusal.set('');
    this.violation.set('');
    const applied = await this.handler.sendFor(this.screen.descriptor, CONFIG_SET_ACTION, target.id, { [CONFIG_VALUE]: value }, { setRefusal: () => undefined });
    this.sending.set(false);
    // A dialog canceled while this send was in flight no longer answers it.
    if (this.target() !== target) return;
    if (applied) {
      this.onClose();
      this.restartNote.set(target.restart ? STRINGS.encryptionStartupRestart : '');
      return;
    }
    const refused = this.handler.lastRefusal();
    const onField = reasonForField(refused?.violations ?? [], CONFIG_VALUE);
    if (onField !== '') this.violation.set(onField);
    else this.refusal.set(refused?.reason ?? '');
  }
}
