import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { NavigationEnd, Router } from '@angular/router';

import { AllowedDirectoriesStore } from '../../core/allowed-directories';
import { ApiService } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { screenForUrl, withQuery } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';
import { ENTITY_SINGLETON_ID, type ScreenDeclaration } from '../../core/screens.generated';
import { Session } from '../../core/session';
import { STRINGS, stringFor } from '../../core/strings';
import { reasonForField, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { ScreenActionDialogs } from '../../shell/screen-action-dialogs';
import { ENCRYPTION_ACTIVATE, ENCRYPTION_DEACTIVATE, ScreenActionHandler, type ActionSink } from '../../shell/screen-action-handler';
import { ServerPathPicker, type ServerPath } from '../../shell/server-path-picker';
import { DATA_ELEMENT_ENCRYPTION, DATABASE_ENCRYPTION, EncryptionKeysStore, type ActiveKeyRow } from './encryption-keys.store';
import { ENCRYPTION_STARTUP_ROUTE } from './encryption-startup.store';

/** The two screens this page serves. */
const ENCRYPTION_KEY_SCREENS: readonly string[] = [DATABASE_ENCRYPTION, DATA_ELEMENT_ENCRYPTION];

/** The values the Activate dialog sends, under the names the activate tools declare (AD-56). */
export const KEY_FILE_ROOT = 'root';
export const KEY_FILE_PATH = 'path';
export const KEY_ADMIN_NAME = 'AdminName';
export const KEY_ADMIN_PASSWORD = 'AdminPassword';

/** Each dialog field's control id. */
export function encryptionKeysControlId(field: string): string {
  return `ocu-encryption-keys-${field}`;
}

/**
 * Database encryption and Data element encryption (Story 18.22, AD-5): Security and secrets' ninth and
 * tenth entries, one page serving `security/database-encryption` and `security/data-element-encryption`,
 * the descriptor taken from the route.
 *
 * **The table** is the screen's declared read (`EncryptionKeysStore`): each active key's identifier, and
 * for database keys its length in bits and whether it is the default. With no key active it states the
 * screen's empty sentence. Deactivate on a row opens the shell's typed-name dialog, whose typed name is the
 * key's identifier and is sent as the action's one value, `KeyId`.
 *
 * **Activate key** is the screen's primary action, registered here, which opens a dialog: the key file's
 * location (the server-path picker, `kind` `file`), an administrator name, by default the signed-in user,
 * and a masked password. Every value lives in this page's own signals and nowhere else, never a store, and
 * is cleared when the dialog closes and after the instance applies the write (AD-35). A refusal is the
 * instance's, drawn on its field.
 *
 * A change event of the screen's entity type, from either caller, reads the list again (AD-14).
 *
 * Database encryption links to the encryption startup settings (Story 18.23), its one way in.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-encryption-keys-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, ScreenActionDialogs, ServerPathPicker],
  // A key's identifier has no break opportunity, so its cells may break anywhere rather than widen the
  // content column past a narrow viewport; and the table contains its own visually hidden column name,
  // which would otherwise be positioned against the page and scroll it sideways (DW-1337).
  styles: `
    .ocu-encryption-keys-table {
      position: relative;
    }
    .ocu-encryption-keys-table th,
    .ocu-encryption-keys-table td {
      overflow-wrap: anywhere;
    }
  `,
  template: `<section class="ocu-form-page" [attr.aria-busy]="busy">
    @if (hasReason) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-encryption-keys="reason">{{ reason }}</p>
    }
    @if (hasActionRefusal) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-encryption-keys="refusal">{{ actionRefusal }}</p>
    }
    @if (hasRows) {
      <table class="ocu-details-volumes-table ocu-encryption-keys-table" role="table" data-encryption-keys="keys">
        <thead>
          <tr role="row">
            <th role="columnheader" scope="col">{{ STRINGS.encryptionKeyFileColumnId }}</th>
            @if (databaseKeys) {
              <th role="columnheader" scope="col">{{ STRINGS.encryptionKeyFileColumnKeyLen }}</th>
              <th role="columnheader" scope="col">{{ STRINGS.tableColumnDefault }}</th>
            }
            <th role="columnheader" scope="col"><span class="ocu-visually-hidden">{{ STRINGS.encryptionKeyDeactivateAction }}</span></th>
          </tr>
        </thead>
        <tbody>
          @for (key of rows; track key.Id) {
            <tr role="row" [attr.data-key]="key.Id">
              <td role="cell">{{ key.Id }}</td>
              @if (databaseKeys) {
                <td role="cell">{{ key.KeyLen }}</td>
                <td role="cell">{{ defaultLabel(key) }}</td>
              }
              <td role="cell">
                <button type="button" class="ocu-button-text" data-encryption-keys="deactivate" (click)="onDeactivate(key)">
                  {{ STRINGS.encryptionKeyDeactivateAction }}
                </button>
              </td>
            </tr>
          }
        </tbody>
      </table>
    }
    @if (showsEmpty) {
      <p class="ocu-data-table-empty-title" data-encryption-keys="empty">{{ emptyText }}</p>
    }
    @if (databaseKeys) {
      <nav class="ocu-details-links">
        <a class="ocu-details-link" data-encryption-keys="startup" [href]="startupRelative" (click)="goStartup($event)">{{ STRINGS.encryptionStartupLink }}</a>
      </nav>
    }

    @if (dialogOpen) {
      <app-dialog [heading]="dialogTitle" [closeLabel]="STRINGS.actionCancel" (closed)="closeDialog()">
        <app-server-path-picker
          idPrefix="ocu-encryption-keys-location"
          kind="file"
          [store]="directories"
          [root]="root"
          [path]="path"
          [rootReason]="rootReason"
          [pathReason]="pathReason"
          (changed)="onLocation($event)"
        />
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="controlId('AdminName')">{{ STRINGS.encryptionKeyFileAdminName }}</label>
          <input class="ocu-field-input" type="text" autocomplete="off" spellcheck="false" [id]="controlId('AdminName')" [value]="adminName" [attr.aria-invalid]="invalid('AdminName')" [attr.aria-describedby]="describedBy('AdminName')" (input)="onAdminName($event)" />
          @if (adminNameReason) {
            <p class="ocu-form-error" [id]="reasonId('AdminName')">{{ adminNameReason }}</p>
          }
        </div>
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="controlId('AdminPassword')">{{ STRINGS.fieldPassword }}</label>
          <input class="ocu-field-input" type="password" autocomplete="off" [id]="controlId('AdminPassword')" [value]="password" [attr.aria-invalid]="invalid('AdminPassword')" [attr.aria-describedby]="describedBy('AdminPassword')" (input)="onPassword($event)" />
          @if (passwordReason) {
            <p class="ocu-form-error" [id]="reasonId('AdminPassword')">{{ passwordReason }}</p>
          }
        </div>
        <p class="ocu-field-caption" data-encryption-keys="consequence">{{ consequence }}</p>
        @if (hasDialogReason) {
          <p class="ocu-banner ocu-banner-warning" role="alert">{{ dialogReason }}</p>
        }
        <button dialogAction type="button" class="ocu-button-primary" data-encryption-keys="submit" [attr.aria-disabled]="sendBlocked" (click)="submit()">
          {{ STRINGS.encryptionKeyActivateAction }}
        </button>
      </app-dialog>
    }

    <app-screen-action-dialogs [descriptor]="descriptor" />
  </section>`,
})
export class EncryptionKeysPage {
  private readonly store = inject(EncryptionKeysStore);
  private readonly api = inject(ApiService);
  private readonly actions = inject(ScreenActions);
  private readonly handler = inject(ScreenActionHandler);
  private readonly router = inject(Router);
  private readonly session = inject(Session, { optional: true });

  protected readonly STRINGS = STRINGS;

  /** The allowed directories the picker offers, read as the page opens. */
  protected readonly directories = new AllowedDirectoriesStore();

  /** Bumped by the store, so the template re-reads it under `OnPush`. */
  private readonly generation = signal(0);

  /** The screen this route serves. */
  private readonly screen = signal<ScreenDeclaration | null>(null);

  private readonly open = signal(false);

  /** What the open dialog holds: this page's alone, the password included, never a store's (AD-35). */
  private readonly location = signal<ServerPath>({ root: '', path: '' });

  private readonly adminValue = signal('');

  private readonly passwordValue = signal('');

  private readonly violations = signal<readonly Violation[]>([]);

  private readonly dialogRefusal = signal('');

  private readonly sending = signal(false);

  /** A Deactivate's refusal, the instance's own sentence (AD-39), or `''`. */
  private readonly rowRefusal = signal('');

  /** The primary action's registration for the screen shown, released when the screen changes. */
  private stopActivate: (() => void) | null = null;

  constructor() {
    const stops: (() => void)[] = [];
    stops.push(this.store.subscribe(() => this.generation.update((value) => value + 1)));
    stops.push(
      inject(ChangeBus).subscribe((event) => {
        const screen = this.screen();
        if (screen === null || event.kind !== 'changed' || event.type !== screen.entityType) return;
        void this.store.read(this.api, screen.descriptor);
      })
    );
    const followed = this.router.events.subscribe((event) => {
      if (event instanceof NavigationEnd) this.follow();
    });
    stops.push(() => followed.unsubscribe());
    void this.directories.load(this.api);
    this.follow();
    inject(DestroyRef).onDestroy(() => {
      for (const stop of stops) stop();
      this.stopActivate?.();
      this.stopActivate = null;
      this.clearDialog();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get descriptor(): string {
    return this.screen()?.descriptor ?? '';
  }

  /** Database keys carry a length and a default flag; data-element keys an identifier alone. */
  protected get databaseKeys(): boolean {
    return this.descriptor === DATABASE_ENCRYPTION;
  }

  protected get busy(): boolean {
    this.generation();
    return this.store.status(this.descriptor) === 'loading';
  }

  protected get rows(): readonly ActiveKeyRow[] {
    this.generation();
    return this.store.rows(this.descriptor);
  }

  protected get hasRows(): boolean {
    return this.rows.length > 0;
  }

  /** The empty sentence states what a read answered, so it waits for one: never while loading or refused. */
  protected get showsEmpty(): boolean {
    this.generation();
    return this.store.status(this.descriptor) === 'ready' && !this.hasRows;
  }

  protected get emptyText(): string {
    return stringFor(this.screen()?.emptyStateKey ?? '');
  }

  protected get reason(): string {
    this.generation();
    return this.store.reason(this.descriptor);
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get actionRefusal(): string {
    return this.rowRefusal();
  }

  protected get hasActionRefusal(): boolean {
    return this.rowRefusal() !== '';
  }

  protected get dialogOpen(): boolean {
    return this.open();
  }

  protected get dialogTitle(): string {
    return this.databaseKeys ? STRINGS.databaseEncryptionActivateTitle : STRINGS.dataElementEncryptionActivateTitle;
  }

  /** The consequence the dialog states before anything is sent, the one the agent's card states. */
  protected get consequence(): string {
    return this.databaseKeys ? STRINGS.encryptionKeyActivateConsequence : STRINGS.encryptionKeyActivateDataElementConsequence;
  }

  protected get root(): string {
    return this.location().root;
  }

  protected get path(): string {
    return this.location().path;
  }

  protected get adminName(): string {
    return this.adminValue();
  }

  protected get password(): string {
    return this.passwordValue();
  }

  protected get rootReason(): string {
    return this.reasonFor(KEY_FILE_ROOT);
  }

  protected get pathReason(): string {
    return this.reasonFor(KEY_FILE_PATH);
  }

  protected get adminNameReason(): string {
    return this.reasonFor(KEY_ADMIN_NAME);
  }

  protected get passwordReason(): string {
    return this.reasonFor(KEY_ADMIN_PASSWORD);
  }

  protected get sendBlocked(): 'true' | null {
    return this.sending() ? 'true' : null;
  }

  protected get dialogReason(): string {
    return this.dialogRefusal();
  }

  protected get hasDialogReason(): boolean {
    return this.dialogRefusal() !== '';
  }

  /** Story 18.23: the encryption startup settings form, in the namespace on screen (AD-44). */
  protected get startupHref(): string {
    return withQuery(ENCRYPTION_STARTUP_ROUTE, this.router.url);
  }

  /** Relative, so the anchor resolves under the document's base href; the router takes the rooted form. */
  protected get startupRelative(): string {
    return this.startupHref.replace(/^\//, '');
  }

  protected defaultLabel(key: ActiveKeyRow): string {
    return key.IsDefault ? STRINGS.tableStatusYes : STRINGS.tableStatusNo;
  }

  protected controlId(field: string): string {
    return encryptionKeysControlId(field);
  }

  protected invalid(field: string): 'true' | null {
    return this.reasonFor(field) === '' ? null : 'true';
  }

  protected reasonId(field: string): string {
    return `${encryptionKeysControlId(field)}-reason`;
  }

  /** Names the field's reason paragraph while a reason is shown, so a screen reader announces it. */
  protected describedBy(field: string): string | null {
    return this.invalid(field) ? this.reasonId(field) : null;
  }

  // --- intents ---------------------------------------------------------------------------------

  /** Open the Activate dialog, the administrator name defaulting to the signed-in user. */
  protected openActivate(): void {
    if (this.open() || this.sending() || this.handler.pending() !== null || this.descriptor === '') return;
    this.location.set({ root: '', path: '' });
    this.adminValue.set(this.session?.userName() ?? '');
    this.passwordValue.set('');
    this.violations.set([]);
    this.dialogRefusal.set('');
    this.rowRefusal.set('');
    this.open.set(true);
  }

  protected closeDialog(): void {
    if (this.sending()) return;
    this.clearDialog();
  }

  protected onLocation(location: ServerPath): void {
    this.location.set({ root: location.root, path: location.path });
    this.forget(KEY_FILE_ROOT, KEY_FILE_PATH);
  }

  protected onAdminName(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement)) return;
    this.adminValue.set(target.value);
    this.forget(KEY_ADMIN_NAME);
  }

  protected onPassword(event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement)) return;
    this.passwordValue.set(target.value);
    this.forget(KEY_ADMIN_PASSWORD);
  }

  /** Activate the key file's keys: one write, whose refusal is drawn on its field (AD-39). */
  protected async submit(): Promise<void> {
    const descriptor = this.descriptor;
    if (this.sending() || descriptor === '') return;
    this.sending.set(true);
    this.violations.set([]);
    this.dialogRefusal.set('');
    const values = {
      [KEY_FILE_ROOT]: this.location().root,
      [KEY_FILE_PATH]: this.location().path,
      [KEY_ADMIN_NAME]: this.adminValue(),
      [KEY_ADMIN_PASSWORD]: this.passwordValue(),
    };
    const sink: ActionSink = { setRefusal: () => undefined };
    const applied = await this.handler.sendFor(descriptor, ENCRYPTION_ACTIVATE, ENTITY_SINGLETON_ID, values, sink);
    this.sending.set(false);
    if (applied) {
      this.clearDialog();
      void this.store.read(this.api, descriptor);
      return;
    }
    const refusal = this.handler.lastRefusal();
    if (refusal === null) return;
    const fields = Object.keys(values);
    const onField = refusal.violations.filter((entry) => fields.includes(entry.field));
    this.violations.set(onField);
    this.dialogRefusal.set(onField.length > 0 ? '' : refusal.reason || STRINGS.connectivityRequestRefused);
  }

  /** Open the encryption startup settings with the router, leaving a modified click to the browser. */
  protected goStartup(event: MouseEvent): void {
    if (event.button !== 0 || event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
    event.preventDefault();
    void this.router.navigateByUrl(this.startupHref);
  }

  /** Deactivate a key, after the typed-name dialog that asks for its identifier. */
  protected onDeactivate(key: ActiveKeyRow): void {
    const descriptor = this.descriptor;
    if (descriptor === '' || this.open()) return;
    this.rowRefusal.set('');
    const sink: ActionSink = {
      setRefusal: (reason) => this.rowRefusal.set(reason),
      applied: () => void this.store.read(this.api, descriptor),
    };
    this.handler.startFor(descriptor, ENCRYPTION_DEACTIVATE, ENTITY_SINGLETON_ID, { Id: key.Id }, sink);
  }

  // --- internals -------------------------------------------------------------------------------

  /**
   * Take the screen this route serves; on a new one, register its Activate key and read its keys. A
   * navigation to any other screen ends before the outlet destroys this page, so it is ignored.
   */
  private follow(): void {
    const next = screenForUrl(this.router.url);
    if (next === null || !ENCRYPTION_KEY_SCREENS.includes(next.descriptor) || next.descriptor === this.screen()?.descriptor) return;
    this.clearDialog();
    this.rowRefusal.set('');
    this.screen.set(next);
    this.stopActivate?.();
    this.stopActivate = this.actions.register(next.descriptor, ENCRYPTION_ACTIVATE, () => this.openActivate());
    void this.store.read(this.api, next.descriptor);
  }

  private reasonFor(field: string): string {
    return reasonForField(this.violations(), field);
  }

  private forget(...fields: readonly string[]): void {
    if (fields.some((field) => this.reasonFor(field) !== '')) this.violations.update((list) => list.filter((entry) => !fields.includes(entry.field)));
    this.dialogRefusal.set('');
  }

  /** Forget everything the dialog held, the password first. */
  private clearDialog(): void {
    this.passwordValue.set('');
    this.adminValue.set('');
    this.location.set({ root: '', path: '' });
    this.violations.set([]);
    this.dialogRefusal.set('');
    this.sending.set(false);
    this.open.set(false);
  }
}
