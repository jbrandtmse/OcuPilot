import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { rowFor } from '../../core/table-model';
import { reasonForField } from '../../core/violations';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { InteropProductionStartupDialog, STARTUP_GROUP, STARTUP_PRIORITY, type StartupKind, type StartupValues } from './interop-production-startup-dialog';

/** The Productions list's descriptor (Story 20.2). */
export const INTEROP_PRODUCTION_LIST = 'OcuPilot.Screen.Descriptor.InteropProductionList';

/** The declared row actions Start with the instance and Shutdown group, which this page's dialog sends (Story 24.3). */
export const INTEROP_AUTO_START_ACTION = 'autostart';
export const INTEROP_SHUTDOWN_GROUP_ACTION = 'shutdowngroup';

/** The production the open dialog changes: its id, which the action is sent for, and what its row reported. */
interface ProductionTarget {
  readonly id: string;
  readonly kind: StartupKind;
  readonly autoStart: boolean;
  readonly priority: string;
  readonly group: string;
}

/** `value` as text, or `''`. */
function text(value: unknown): string {
  return typeof value === 'string' || typeof value === 'number' ? String(value) : '';
}

/**
 * Interoperability's Productions (Story 24.3, AD-5): the shared list page, over it the dialogs of the two startup settings.
 *
 * **Start, Stop, Restart, Update and Recover stay the shell's**: the handler this page injects registers them exactly as the
 * list sent them before. **Start with the instance and Shutdown group are this page's own actions**, registered on the descriptor after
 * that, each opening the one dialog in its mode over the selected row and sending its values through the handler's `sendFor`. A refusal
 * stays in the dialog, on the value's field where the instance names it; an applied change closes it, and the handler's change event
 * re-reads the list (AD-14), so the columns show what was set.
 */
@Component({
  selector: 'app-interop-production-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, InteropProductionStartupDialog],
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
      <app-interop-production-startup-dialog
        [kind]="target.kind"
        [production]="target.id"
        [autoStart]="target.autoStart"
        [priority]="target.priority"
        [group]="target.group"
        [sending]="sending()"
        [refusal]="refusal()"
        [violation]="violation()"
        (submitted)="onSend($event)"
        (cancelled)="onClose()"
      />
    }`,
})
export class InteropProductionListPage {
  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own actions: its constructor registers the five production actions. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly store: ScreenStore | null;

  /** The production the open dialog changes, or `null` while none is open. */
  protected readonly target = signal<ProductionTarget | null>(null);

  protected readonly sending = signal(false);

  protected readonly refusal = signal('');

  protected readonly violation = signal('');

  protected get openTarget(): ProductionTarget | null {
    return this.target();
  }

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_PRODUCTION_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stopAuto = this.actions.register(INTEROP_PRODUCTION_LIST, INTEROP_AUTO_START_ACTION, () => this.onOpen('autostart'));
    const stopGroup = this.actions.register(INTEROP_PRODUCTION_LIST, INTEROP_SHUTDOWN_GROUP_ACTION, () => this.onOpen('shutdowngroup'));
    inject(DestroyRef).onDestroy(() => {
      stopAuto();
      stopGroup();
    });
  }

  /** Open the dialog on the selected row, never over another dialog. With no selection nothing opens: the surfaces already draw the action unavailable. */
  protected onOpen(kind: StartupKind): void {
    if (this.target() !== null || this.handler.pending() !== null) return;
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_PRODUCTION_LIST);
    const store = this.store;
    if (screen === undefined || store === null) return;
    const selected = store.selection()[0] ?? '';
    const row = rowFor(store.data(), screen, selected);
    if (row === null) return;
    this.refusal.set('');
    this.violation.set('');
    this.target.set({ id: selected, kind, autoStart: row['AutoStart'] === 'Yes', priority: text(row['StartupPriority']), group: text(row['ShutdownGroup']) });
  }

  protected onClose(): void {
    this.target.set(null);
    this.refusal.set('');
    this.violation.set('');
  }

  /**
   * One send through the handler's `sendFor`, the refusal kept in the dialog rather than on the list's banner: the sentence the
   * instance gave the value field, else the envelope's own.
   */
  protected async onSend(values: StartupValues): Promise<void> {
    const target = this.target();
    if (target === null || this.sending()) return;
    this.sending.set(true);
    this.refusal.set('');
    this.violation.set('');
    const action = target.kind === 'autostart' ? INTEROP_AUTO_START_ACTION : INTEROP_SHUTDOWN_GROUP_ACTION;
    const applied = await this.handler.sendFor(INTEROP_PRODUCTION_LIST, action, target.id, { ...values }, { setRefusal: () => undefined });
    this.sending.set(false);
    // A dialog canceled while this send was in flight no longer answers it.
    if (this.target() !== target) return;
    if (applied) {
      this.onClose();
      return;
    }
    const refused = this.handler.lastRefusal();
    const onField = reasonForField(refused?.violations ?? [], target.kind === 'autostart' ? STARTUP_PRIORITY : STARTUP_GROUP);
    if (onField !== '') this.violation.set(onField);
    else this.refusal.set(refused?.reason ?? '');
  }
}
