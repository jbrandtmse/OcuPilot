import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { ScopeService } from '../../core/scope';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import { SCREENS } from '../../core/screens.generated';
import { rowFor } from '../../core/table-model';
import { ListPage } from '../../shell/list-page';
import { ScreenActionHandler } from '../../shell/screen-action-handler';
import { InteropCredentialDialog } from './interop-credential-dialog';
import {
  INTEROP_CREDENTIAL_NAME,
  INTEROP_CREDENTIAL_PASSWORD,
  INTEROP_CREDENTIAL_VALUE_FIELDS,
  InteropCredentialStore,
  type CredentialValues,
} from './interop-credential.store';

/** The Credentials list's descriptor (Story 24.15). */
export const INTEROP_CREDENTIAL_LIST = 'OcuPilot.Screen.Descriptor.InteropCredentialList';

/** The declared primary action id: the command bar's New credential, which opens the dialog. */
export const INTEROP_CREDENTIAL_ADD_ACTION = 'add';

/** The declared row actions Edit and Set password, which this page's dialog sends. */
export const INTEROP_CREDENTIAL_EDIT_ACTION = 'edit';
export const INTEROP_CREDENTIAL_PASSWORD_ACTION = 'password';

/** The credential the open Edit or Set password dialog is about: the row's key, which the action is sent for, its name, and the values it opened with. */
interface CredentialTarget {
  readonly id: string;
  readonly name: string;
  readonly initial: CredentialValues;
}

/** `value` as text, or `''`. */
function text(value: unknown): string {
  return typeof value === 'string' || typeof value === 'number' ? String(value) : '';
}

/**
 * Interoperability's credentials (Story 24.15, AD-5, AD-35): the shared list page, over it the New credential dialog, the Edit dialog and the Set
 * password dialog, one component in three modes.
 *
 * **New credential, Edit and Set password are this page's own actions**, registered on the descriptor after injecting the shell's handler, whose
 * construction registers the list's declared Remove (which types the credential's name). New credential opens the dialog for a new credential in the
 * namespace the shell is scoped to. Edit opens it on the selected row, with the name read-only and the user name and the business partner as the row
 * reported them, and sends through the handler's `sendFor` only the values the person changed, an empty one allowed, so a field another caller changed
 * since the list was read is kept; a dialog that changes nothing closes without sending. Set password opens the masked password field alone and sends the
 * password once, exactly as typed, through the same route; **no row, no context and no store of this page holds a password**.
 * A refusal stays in the dialog, on the field where the instance names it, and an applied change closes it, and the handler's change event re-reads
 * the list (AD-14).
 */
@Component({
  selector: 'app-interop-credential-list-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, InteropCredentialDialog],
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
      <app-interop-credential-dialog mode="add" [namespace]="namespace" (added)="onCloseAdd()" (cancelled)="onCloseAdd()" />
    }
    @if (editing; as credential) {
      <app-interop-credential-dialog
        mode="edit"
        [namespace]="namespace"
        [credential]="credential"
        (submitted)="onEdit($event)"
        (cancelled)="onCloseTarget()"
      />
    }
    @if (settingPassword; as credential) {
      <app-interop-credential-dialog
        mode="password"
        [namespace]="namespace"
        [credential]="credential"
        (passwordSubmitted)="onPassword($event)"
        (cancelled)="onCloseTarget()"
      />
    }`,
})
export class InteropCredentialListPage {
  private readonly scope = inject(ScopeService);

  private readonly stores = inject(ScreenStores);

  /** Constructed before this page registers its own actions: its constructor registers Remove. */
  private readonly handler = inject(ScreenActionHandler);

  private readonly actions = inject(ScreenActions);

  private readonly form = inject(InteropCredentialStore);

  private readonly store: ScreenStore | null;

  /** Whether the New credential dialog is open. */
  private readonly open = signal(false);

  /** The credential the open Edit dialog changes, or `null` while none is open. */
  private readonly editTarget = signal<CredentialTarget | null>(null);

  /** The credential the open Set password dialog is about, or `null` while none is open. */
  private readonly passwordTarget = signal<CredentialTarget | null>(null);

  constructor() {
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_CREDENTIAL_LIST) ?? null;
    this.store = screen === null ? null : this.stores.for(screen.descriptor, screen.refreshRates);
    const stopAdd = this.actions.register(INTEROP_CREDENTIAL_LIST, INTEROP_CREDENTIAL_ADD_ACTION, () => this.onOpenAdd());
    const stopEdit = this.actions.register(INTEROP_CREDENTIAL_LIST, INTEROP_CREDENTIAL_EDIT_ACTION, () => this.onOpenEdit());
    const stopPassword = this.actions.register(INTEROP_CREDENTIAL_LIST, INTEROP_CREDENTIAL_PASSWORD_ACTION, () => this.onOpenPassword());
    inject(DestroyRef).onDestroy(() => {
      stopAdd();
      stopEdit();
      stopPassword();
    });
  }

  protected get adding(): boolean {
    return this.open();
  }

  protected get editing(): string | null {
    return this.editTarget()?.name ?? null;
  }

  protected get settingPassword(): string | null {
    return this.passwordTarget()?.name ?? null;
  }

  protected get namespace(): string {
    return this.scope.namespace();
  }

  /** Whether any of this page's dialogs, or one of the handler's, is open. */
  private busy(): boolean {
    return this.open() || this.editTarget() !== null || this.passwordTarget() !== null || this.handler.pending() !== null;
  }

  /** Open the New credential dialog, never over another dialog. */
  protected onOpenAdd(): void {
    if (this.busy()) return;
    this.form.reset();
    this.open.set(true);
  }

  protected onCloseAdd(): void {
    this.open.set(false);
  }

  /** The selected row as a target, or `null` with no selection. */
  private selected(): CredentialTarget | null {
    const screen = SCREENS.find((entry) => entry.descriptor === INTEROP_CREDENTIAL_LIST);
    const store = this.store;
    if (screen === undefined || store === null) return null;
    const selected = store.selection()[0] ?? '';
    const row = rowFor(store.data(), screen, selected);
    if (row === null) return null;
    const initial: Record<string, string> = { [INTEROP_CREDENTIAL_NAME]: text(row[INTEROP_CREDENTIAL_NAME]) };
    for (const field of INTEROP_CREDENTIAL_VALUE_FIELDS) initial[field] = text(row[field]);
    return { id: selected, name: initial[INTEROP_CREDENTIAL_NAME], initial };
  }

  /** Open Edit on the selected row, never over another dialog. With no selection nothing opens: the surfaces already draw the action unavailable. */
  protected onOpenEdit(): void {
    if (this.busy()) return;
    const target = this.selected();
    if (target === null) return;
    this.form.reset(target.initial);
    this.editTarget.set(target);
  }

  /** Open Set password on the selected row, never over another dialog. */
  protected onOpenPassword(): void {
    if (this.busy()) return;
    const target = this.selected();
    if (target === null) return;
    this.form.reset();
    this.passwordTarget.set(target);
  }

  protected onCloseTarget(): void {
    this.editTarget.set(null);
    this.passwordTarget.set(null);
    this.form.reset();
  }

  /**
   * One Edit through the handler's `sendFor`, the refusal kept in the dialog rather than on the list's banner: the sentence the instance gave a field,
   * else the envelope's own. The name is the target and is not among the values, and a value equal to the one the dialog opened with is not sent either.
   */
  protected async onEdit(values: CredentialValues): Promise<void> {
    const target = this.editTarget();
    if (target === null || this.form.busy()) return;
    const sent: Record<string, string> = {};
    for (const field of INTEROP_CREDENTIAL_VALUE_FIELDS) {
      const value = values[field] ?? '';
      if (value !== (target.initial[field] ?? '')) sent[field] = value;
    }
    if (Object.keys(sent).length === 0) {
      this.onCloseTarget();
      return;
    }
    const generation = this.form.begin();
    const applied = await this.handler.sendFor(INTEROP_CREDENTIAL_LIST, INTEROP_CREDENTIAL_EDIT_ACTION, target.id, sent, { setRefusal: () => undefined });
    // A dialog canceled while this send was in flight no longer answers it.
    if (!this.form.current(generation) || this.editTarget() !== target) return;
    if (applied) {
      this.form.finish();
      this.onCloseTarget();
      return;
    }
    const refused = this.handler.lastRefusal();
    this.form.refuse(refused?.violations ?? [], refused?.reason ?? '');
  }

  /**
   * One Set password through the handler's `sendFor`: the password exactly as typed, in the one call and held by nothing else, the refusal kept in the
   * dialog. An empty password is never sent.
   */
  protected async onPassword(password: string): Promise<void> {
    const target = this.passwordTarget();
    if (target === null || password === '' || this.form.busy()) return;
    const generation = this.form.begin();
    const applied = await this.handler.sendFor(INTEROP_CREDENTIAL_LIST, INTEROP_CREDENTIAL_PASSWORD_ACTION, target.id, { [INTEROP_CREDENTIAL_PASSWORD]: password }, { setRefusal: () => undefined });
    if (!this.form.current(generation) || this.passwordTarget() !== target) return;
    if (applied) {
      this.form.finish();
      this.onCloseTarget();
      return;
    }
    const refused = this.handler.lastRefusal();
    this.form.refuse(refused?.violations ?? [], refused?.reason ?? '');
  }
}
