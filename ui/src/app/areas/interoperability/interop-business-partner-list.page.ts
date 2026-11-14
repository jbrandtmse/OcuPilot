import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { rowFor } from '../../core/table-model';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { InteropBusinessPartnerDialog } from './interop-business-partner-dialog';
import { INTEROP_PARTNER_NAME, INTEROP_PARTNER_VALUE_FIELDS, InteropBusinessPartnerStore, type PartnerValues } from './interop-business-partner.store';

/** The Business partners list's descriptor (Story 20.5). */
export const INTEROP_BUSINESS_PARTNER_LIST = 'OcuPilot.Screen.Descriptor.InteropBusinessPartnerList';

/** The declared primary action id: the command bar's New business partner, which opens the dialog. */
export const INTEROP_PARTNER_ADD_ACTION = 'add';

/** The declared row action Edit, which this page's dialog sends (Story 20.26). */
export const INTEROP_PARTNER_EDIT_ACTION = 'edit';

/** The partner the open Edit dialog changes: the row's key, which the action is sent for, and its name, which the dialog shows. */
interface PartnerTarget {
  readonly id: string;
  readonly name: string;
}

/** `value` as text, or `''`. */
function text(value: unknown): string {
  return typeof value === 'string' || typeof value === 'number' ? String(value) : '';
}

/**
 * Interoperability's business partners (Story 20.26, AD-5): the shared list page, over it the New business partner dialog and
 * the Edit dialog, one component in two modes.
 *
 * **New business partner and Edit are this page's own actions**, registered on the descriptor after injecting the shell's
 * handler, whose construction registers the list's declared Remove (which types the partner's name). New business partner opens
 * the dialog for a new partner in the namespace the shell is scoped to. Edit opens it on the selected row, with the name read-only
 * and the other thirteen fields as the row reported them, and sends them through the handler's `sendFor` with every value, an empty
 * one allowed; a refusal stays in the dialog, on the field where the instance names it, and an applied change closes it, and the
 * handler's change event re-reads the list (AD-14).
 */
@Component({
  selector: 'app-interop-business-partner-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, InteropBusinessPartnerDialog],
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
      <app-interop-business-partner-dialog [namespace]="namespace" (added)="onCloseAdd()" (cancelled)="onCloseAdd()" />
    }
    @if (editing; as partner) {
      <app-interop-business-partner-dialog [namespace]="namespace" [partner]="partner" (submitted)="onEdit($event)" (cancelled)="onCloseEdit()" />
    }`,
})
export class InteropBusinessPartnerListPage {
  private readonly scope = inject(ScopeService);

  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own actions: its constructor registers Remove. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly form = inject(InteropBusinessPartnerStore);

  private readonly store: ScreenStore | null;

  /** Whether the New business partner dialog is open. */
  private readonly open = signal(false);

  /** The partner the open Edit dialog changes, or `null` while none is open. */
  private readonly target = signal<PartnerTarget | null>(null);

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_BUSINESS_PARTNER_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stopAdd = this.actions.register(INTEROP_BUSINESS_PARTNER_LIST, INTEROP_PARTNER_ADD_ACTION, () => this.onOpenAdd());
    const stopEdit = this.actions.register(INTEROP_BUSINESS_PARTNER_LIST, INTEROP_PARTNER_EDIT_ACTION, () => this.onOpenEdit());
    inject(DestroyRef).onDestroy(() => {
      stopAdd();
      stopEdit();
    });
  }

  protected get adding(): boolean {
    return this.open();
  }

  protected get editing(): string | null {
    return this.target()?.name ?? null;
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  /** Open the New business partner dialog, never over a dialog of the handler's or the Edit one. */
  protected onOpenAdd(): void {
    if (this.open() || this.target() !== null || this.handler.pending() !== null) return;
    this.form.reset();
    this.open.set(true);
  }

  protected onCloseAdd(): void {
    this.open.set(false);
  }

  /** Open Edit on the selected row, never over another dialog. With no selection nothing opens: the surfaces already draw the action unavailable. */
  protected onOpenEdit(): void {
    if (this.target() !== null || this.open() || this.handler.pending() !== null) return;
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_BUSINESS_PARTNER_LIST);
    const store = this.store;
    if (screen === undefined || store === null) return;
    const selected = store.selection()[0] ?? '';
    const row = rowFor(store.data(), screen, selected);
    if (row === null) return;
    const initial: Record<string, string> = { [INTEROP_PARTNER_NAME]: text(row[INTEROP_PARTNER_NAME]) };
    for (const field of INTEROP_PARTNER_VALUE_FIELDS) initial[field] = text(row[field]);
    this.form.reset(initial);
    this.target.set({ id: selected, name: initial[INTEROP_PARTNER_NAME] });
  }

  protected onCloseEdit(): void {
    this.target.set(null);
    this.form.reset();
  }

  /**
   * One Edit through the handler's `sendFor`, the refusal kept in the dialog rather than on the list's banner: the sentence the
   * instance gave a field, else the envelope's own. The name is the target and is not among the values.
   */
  protected async onEdit(values: PartnerValues): Promise<void> {
    const target = this.target();
    if (target === null || this.form.busy()) return;
    const generation = this.form.begin();
    const sent: Record<string, string> = {};
    for (const field of INTEROP_PARTNER_VALUE_FIELDS) sent[field] = values[field] ?? '';
    const applied = await this.handler.sendFor(INTEROP_BUSINESS_PARTNER_LIST, INTEROP_PARTNER_EDIT_ACTION, target.id, sent, { setRefusal: () => undefined });
    // A dialog canceled while this send was in flight no longer answers it.
    if (!this.form.current(generation) || this.target() !== target) return;
    if (applied) {
      this.form.finish();
      this.onCloseEdit();
      return;
    }
    const refused = this.handler.lastRefusal();
    this.form.refuse(refused?.violations ?? [], refused?.reason ?? '');
  }
}
