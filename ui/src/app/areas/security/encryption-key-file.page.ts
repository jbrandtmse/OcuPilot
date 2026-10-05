import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';

import { AllowedDirectoriesStore } from '../../core/allowed-directories';
import { ApiService } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { ScreenActions } from '../../core/screen-actions';
import { Session } from '../../core/session';
import { STRINGS } from '../../core/strings';
import { reasonForField, type Violation } from '../../core/violations';
import { Dialog } from '../../shell/dialog';
import { ScreenActionDialogs } from '../../shell/screen-action-dialogs';
import {
  ENCRYPTION_ADD_ADMIN,
  ENCRYPTION_ADD_KEY,
  ENCRYPTION_KEY_FILE,
  ENCRYPTION_KEY_FILE_ADMINS,
  ENCRYPTION_REMOVE_ADMIN,
  ENCRYPTION_REMOVE_KEY,
  ScreenActionHandler,
  type ActionSink,
} from '../../shell/screen-action-handler';
import { ServerPathPicker, type ServerPath } from '../../shell/server-path-picker';
import { ENCRYPTION_CREATE_ACTION } from './encryption-key-file-actions';
import { DEFAULT_KEY_LENGTH, EncryptionKeyFileStore, KEY_LENGTHS, type KeyRow } from './encryption-key-file.store';

/** The entity type every key-file write's change event carries (AD-13, AD-14). */
export const ENCRYPTION_KEY_FILE_ENTITY = 'encryption-key-file';

/** The values the two Add dialogs send, under the names their tools declare (AD-56). */
export const OLD_ADMIN_NAME = 'OldAdminName';
export const OLD_ADMIN_PASSWORD = 'OldAdminPassword';
export const NEW_ADMIN_NAME = 'NewAdminName';
export const NEW_ADMIN_PASSWORD = 'NewAdminPassword';
export const ADMIN_NAME = 'AdminName';
export const ADMIN_PASSWORD = 'AdminPassword';
export const KEY_LENGTH = 'KeyLen';
export const KEY_DESCRIPTION = 'Description';

/** The confirm field each dialog checks its new password against, in the dialog alone. */
export const CONFIRM_FIELD = 'Confirm';


/** Each dialog field's control id. */
export function keyFileControlId(field: string): string {
  return `ocu-key-file-${field}`;
}

/** Which Add dialog is open. */
type OpenDialog = 'admin' | 'key' | null;

/**
 * Encryption key files (Story 18.7, AD-5): Security and secrets' eighth entry, serving both
 * `security/encryption-key-file` and `security/encryption-key-file/administrators`.
 *
 * **Open a key file.** The server-path picker (`kind` `file`) over the instance's allowed directories,
 * and Open, which issues both declared reads with `root` and `path` as criteria
 * (`EncryptionKeyFileStore`). A refusal naming the root or the name is drawn on that picker field
 * (AD-39).
 *
 * **Two tables**: the administrators and the keys. Remove on a row opens the shell's typed-name
 * dialog -- the administrator's name, or the key's identifier -- and sends that name as the action's
 * value beside the key file's composite id. The last administrator's Remove is drawn unavailable with
 * the sentence the instance would refuse it with.
 *
 * **Add administrator and Add key** open dialogs with masked password fields. Every value typed into
 * either lives in this page's own signals and nowhere else, never a store, and is cleared when the
 * dialog closes and after the instance applies the write (AD-35). A new password that does not match
 * its confirmation is refused in the dialog; every other refusal is the instance's, drawn on its field.
 *
 * Create key file opens the create form (`EncryptionKeyFileActions`), the screen's one command-bar
 * action; Add and Remove are this page's own controls, since each acts on the open key file rather
 * than on a selected row of the shell's list. A change event for the open key file, from either
 * caller, reads both lists again (AD-14).
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts` records.
 */
@Component({
  selector: 'app-encryption-key-file-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [Dialog, ScreenActionDialogs, ServerPathPicker],
  // A key's identifier has no break opportunity, so its cells may break anywhere rather than widen
  // the content column past a narrow viewport; and each table contains its own visually hidden
  // column names, which would otherwise be positioned against the page and scroll it sideways
  // (DW-1337).
  styles: `
    .ocu-key-file-table {
      position: relative;
    }
    .ocu-key-file-table th,
    .ocu-key-file-table td {
      overflow-wrap: anywhere;
    }
  `,
  template: `<section class="ocu-form-page" [attr.aria-busy]="busy">
    <div class="ocu-form-fields">
      <app-server-path-picker
        idPrefix="ocu-key-file-location"
        kind="file"
        [store]="directories"
        [root]="root"
        [path]="path"
        [rootReason]="rootReason"
        [pathReason]="pathReason"
        (changed)="onLocation($event)"
      />
      <div class="ocu-form-bar-actions">
        <button type="button" class="ocu-button-primary" data-key-file="open" [attr.aria-disabled]="openBlocked" (click)="onOpen()">
          {{ STRINGS.homeSuggestedOpen }}
        </button>
        <button type="button" class="ocu-button-secondary" data-key-file="create" (click)="onCreate()">
          {{ STRINGS.encryptionKeyFileCreateAction }}
        </button>
      </div>
    </div>
    @if (hasReason) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-key-file="reason">{{ reason }}</p>
    }
    @if (hasActionRefusal) {
      <p class="ocu-banner ocu-banner-warning" role="alert" data-key-file="refusal">{{ actionRefusal }}</p>
    }

    <h2 class="ocu-details-heading">{{ STRINGS.encryptionKeyFileAdminsTitle }}</h2>
    @if (openedFlag) {
      <table class="ocu-details-volumes-table ocu-key-file-table" role="table" data-key-file="administrators">
        <thead>
          <tr role="row">
            <th role="columnheader" scope="col">{{ STRINGS.encryptionKeyFileColumnAdmin }}</th>
            <th role="columnheader" scope="col"><span class="ocu-visually-hidden">{{ STRINGS.actionRemove }}</span></th>
          </tr>
        </thead>
        <tbody>
          @for (name of administrators; track name) {
            <tr role="row" [attr.data-admin]="name">
              <td role="cell">{{ name }}</td>
              <td role="cell">
                <button
                  type="button"
                  class="ocu-button-text"
                  data-key-file="remove-admin"
                  [attr.aria-disabled]="lastAdmin"
                  [attr.aria-describedby]="lastAdminDescribedBy"
                  (click)="onRemoveAdmin(name)"
                >
                  {{ STRINGS.actionRemove }}
                </button>
              </td>
            </tr>
          }
        </tbody>
      </table>
      @if (lastAdminFlag) {
        <p class="ocu-field-caption" [id]="lastAdminId" data-key-file="last-admin">{{ STRINGS.encryptionKeyFileAdminLast }}</p>
      }
      <div class="ocu-form-bar-actions">
        <button type="button" class="ocu-button-secondary" data-key-file="add-admin" (click)="openAdmin()">
          {{ STRINGS.encryptionKeyFileAddAdminAction }}
        </button>
      </div>
    } @else {
      <p class="ocu-data-table-empty-title" data-key-file="admins-empty">{{ STRINGS.encryptionKeyFileAdminsEmpty }}</p>
    }

    <h2 class="ocu-details-heading">{{ STRINGS.encryptionKeyFileKeysTitle }}</h2>
    @if (openedFlag) {
      <table class="ocu-details-volumes-table ocu-key-file-table" role="table" data-key-file="keys">
        <thead>
          <tr role="row">
            <th role="columnheader" scope="col">{{ STRINGS.encryptionKeyFileColumnId }}</th>
            <th role="columnheader" scope="col">{{ STRINGS.encryptionKeyFileColumnKeyLen }}</th>
            <th role="columnheader" scope="col">{{ STRINGS.tableColumnDescription }}</th>
            <th role="columnheader" scope="col"><span class="ocu-visually-hidden">{{ STRINGS.actionRemove }}</span></th>
          </tr>
        </thead>
        <tbody>
          @for (key of keys; track key.Id) {
            <tr role="row" [attr.data-key]="key.Id">
              <td role="cell">{{ key.Id }}</td>
              <td role="cell">{{ key.KeyLen }}</td>
              <td role="cell">{{ key.Description }}</td>
              <td role="cell">
                <button type="button" class="ocu-button-text" data-key-file="remove-key" (click)="onRemoveKey(key)">
                  {{ STRINGS.actionRemove }}
                </button>
              </td>
            </tr>
          }
        </tbody>
      </table>
      <div class="ocu-form-bar-actions">
        <button type="button" class="ocu-button-secondary" data-key-file="add-key" (click)="openKey()">
          {{ STRINGS.encryptionKeyFileAddKeyAction }}
        </button>
      </div>
    } @else {
      <p class="ocu-data-table-empty-title" data-key-file="keys-empty">{{ STRINGS.encryptionKeyFileKeysEmpty }}</p>
    }

    @if (adminDialogOpen) {
      <app-dialog [heading]="STRINGS.encryptionKeyFileAddAdminTitle" [closeLabel]="STRINGS.actionCancel" (closed)="closeDialog()">
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="controlId('OldAdminName')">{{ STRINGS.encryptionKeyFileExistingAdmin }}</label>
          <input class="ocu-field-input" type="text" autocomplete="off" spellcheck="false" [id]="controlId('OldAdminName')" [value]="value('OldAdminName')" [attr.aria-invalid]="invalid('OldAdminName')" [attr.aria-describedby]="describedBy('OldAdminName')" (input)="onValue('OldAdminName', $event)" />
          @if (oldAdminReason) {
            <p class="ocu-form-error" [id]="reasonId('OldAdminName')">{{ oldAdminReason }}</p>
          }
        </div>
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="controlId('OldAdminPassword')">{{ STRINGS.encryptionKeyFileExistingPassword }}</label>
          <input class="ocu-field-input" type="password" autocomplete="off" [id]="controlId('OldAdminPassword')" [value]="value('OldAdminPassword')" [attr.aria-invalid]="invalid('OldAdminPassword')" [attr.aria-describedby]="describedBy('OldAdminPassword')" (input)="onValue('OldAdminPassword', $event)" />
          @if (oldPasswordReason) {
            <p class="ocu-form-error" [id]="reasonId('OldAdminPassword')">{{ oldPasswordReason }}</p>
          }
        </div>
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="controlId('NewAdminName')">{{ STRINGS.encryptionKeyFileNewAdmin }}</label>
          <input class="ocu-field-input" type="text" autocomplete="off" spellcheck="false" [id]="controlId('NewAdminName')" [value]="value('NewAdminName')" [attr.aria-invalid]="invalid('NewAdminName')" [attr.aria-describedby]="describedBy('NewAdminName')" (input)="onValue('NewAdminName', $event)" />
          @if (newAdminReason) {
            <p class="ocu-form-error" [id]="reasonId('NewAdminName')">{{ newAdminReason }}</p>
          }
        </div>
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="controlId('NewAdminPassword')">{{ STRINGS.fieldPassword }}</label>
          <input class="ocu-field-input" type="password" autocomplete="new-password" [id]="controlId('NewAdminPassword')" [value]="value('NewAdminPassword')" [attr.aria-invalid]="invalid('NewAdminPassword')" [attr.aria-describedby]="describedBy('NewAdminPassword')" (input)="onValue('NewAdminPassword', $event)" />
          @if (newPasswordReason) {
            <p class="ocu-form-error" [id]="reasonId('NewAdminPassword')">{{ newPasswordReason }}</p>
          }
        </div>
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="controlId('Confirm')">{{ STRINGS.ldapFieldPasswordConfirm }}</label>
          <input class="ocu-field-input" type="password" autocomplete="new-password" [id]="controlId('Confirm')" [value]="value('Confirm')" [attr.aria-invalid]="invalid('Confirm')" [attr.aria-describedby]="describedBy('Confirm')" (input)="onValue('Confirm', $event)" />
          @if (confirmReason) {
            <p class="ocu-form-error" [id]="reasonId('Confirm')" data-key-file="mismatch">{{ confirmReason }}</p>
          }
        </div>
        @if (hasDialogReason) {
          <p class="ocu-banner ocu-banner-warning" role="alert">{{ dialogReason }}</p>
        }
        <button dialogAction type="button" class="ocu-button-primary" data-key-file="submit-admin" [attr.aria-disabled]="sendBlocked" (click)="submitAdmin()">
          {{ STRINGS.encryptionKeyFileAddAdminAction }}
        </button>
      </app-dialog>
    }

    @if (keyDialogOpen) {
      <app-dialog [heading]="STRINGS.encryptionKeyFileAddKeyTitle" [closeLabel]="STRINGS.actionCancel" (closed)="closeDialog()">
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="controlId('AdminName')">{{ STRINGS.encryptionKeyFileAdminName }}</label>
          <input class="ocu-field-input" type="text" autocomplete="off" spellcheck="false" [id]="controlId('AdminName')" [value]="value('AdminName')" [attr.aria-invalid]="invalid('AdminName')" [attr.aria-describedby]="describedBy('AdminName')" (input)="onValue('AdminName', $event)" />
          @if (adminNameReason) {
            <p class="ocu-form-error" [id]="reasonId('AdminName')">{{ adminNameReason }}</p>
          }
        </div>
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="controlId('AdminPassword')">{{ STRINGS.fieldPassword }}</label>
          <input class="ocu-field-input" type="password" autocomplete="off" [id]="controlId('AdminPassword')" [value]="value('AdminPassword')" [attr.aria-invalid]="invalid('AdminPassword')" [attr.aria-describedby]="describedBy('AdminPassword')" (input)="onValue('AdminPassword', $event)" />
          @if (adminPasswordReason) {
            <p class="ocu-form-error" [id]="reasonId('AdminPassword')">{{ adminPasswordReason }}</p>
          }
        </div>
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="controlId('KeyLen')">{{ STRINGS.encryptionKeyFileCipherLevel }}</label>
          <select class="ocu-field-input" [id]="controlId('KeyLen')" [attr.aria-invalid]="invalid('KeyLen')" [attr.aria-describedby]="describedBy('KeyLen')" (change)="onValue('KeyLen', $event)">
            @for (option of keyLengths; track option.value) {
              <option [value]="option.value" [selected]="option.value === keyLength">{{ option.label }}</option>
            }
          </select>
          @if (keyLengthReason) {
            <p class="ocu-form-error" [id]="reasonId('KeyLen')">{{ keyLengthReason }}</p>
          }
        </div>
        <div class="ocu-field">
          <label class="ocu-field-label" [attr.for]="controlId('Description')">{{ STRINGS.encryptionKeyFileKeyDescription }}</label>
          <input class="ocu-field-input" type="text" autocomplete="off" [id]="controlId('Description')" [value]="value('Description')" (input)="onValue('Description', $event)" />
        </div>
        <p class="ocu-field-caption" data-key-file="new-key-consequence">{{ STRINGS.encryptionKeyFileNewKeyConsequence }}</p>
        @if (hasDialogReason) {
          <p class="ocu-banner ocu-banner-warning" role="alert">{{ dialogReason }}</p>
        }
        <button dialogAction type="button" class="ocu-button-primary" data-key-file="submit-key" [attr.aria-disabled]="sendBlocked" (click)="submitKey()">
          {{ STRINGS.encryptionKeyFileAddKeyAction }}
        </button>
      </app-dialog>
    }

    <app-screen-action-dialogs [descriptor]="adminsDescriptor" />
    <app-screen-action-dialogs [descriptor]="keysDescriptor" />
  </section>`,
})
export class EncryptionKeyFilePage {
  private readonly store = inject(EncryptionKeyFileStore);
  private readonly api = inject(ApiService);
  private readonly actions = inject(ScreenActions);
  private readonly handler = inject(ScreenActionHandler);
  private readonly session = inject(Session, { optional: true });

  protected readonly STRINGS = STRINGS;

  protected readonly adminsDescriptor = ENCRYPTION_KEY_FILE_ADMINS;

  protected readonly keysDescriptor = ENCRYPTION_KEY_FILE;

  protected readonly keyLengths = KEY_LENGTHS;

  protected readonly lastAdminId = 'ocu-key-file-last-admin';

  /** The allowed directories the picker offers, read as the page opens. */
  protected readonly directories = new AllowedDirectoriesStore();

  /** Bumped by the store, so the template re-reads it under `OnPush`. */
  private readonly generation = signal(0);

  private readonly open = signal<OpenDialog>(null);

  /** What the open dialog holds: this page's alone, passwords included, never a store's (AD-35). */
  private readonly values = signal<Readonly<Record<string, string>>>({});

  private readonly violations = signal<readonly Violation[]>([]);

  private readonly dialogRefusal = signal('');

  private readonly sending = signal(false);

  /** A Remove's refusal, the instance's own sentence (AD-39), or `''`. */
  private readonly removeRefusal = signal('');

  constructor() {
    const stops: (() => void)[] = [];
    stops.push(this.store.subscribe(() => this.generation.update((value) => value + 1)));
    stops.push(
      inject(ChangeBus).subscribe((event) => {
        if (event.kind !== 'changed' || event.type !== ENCRYPTION_KEY_FILE_ENTITY) return;
        if (event.id !== this.store.keyFileId()) return;
        void this.store.reread(this.api);
      })
    );
    void this.directories.load(this.api);
    inject(DestroyRef).onDestroy(() => {
      for (const stop of stops) stop();
      this.clearDialog();
    });
  }

  // --- reads -----------------------------------------------------------------------------------

  protected get root(): string {
    this.generation();
    return this.store.root();
  }

  protected get path(): string {
    this.generation();
    return this.store.path();
  }

  protected get rootReason(): string {
    this.generation();
    return this.store.rootReason();
  }

  protected get pathReason(): string {
    this.generation();
    return this.store.pathReason();
  }

  protected get busy(): boolean {
    this.generation();
    return this.store.status() === 'loading';
  }

  protected get openBlocked(): boolean {
    this.generation();
    return this.store.status() === 'loading' || this.store.root() === '' || this.store.path().trim() === '';
  }

  protected get reason(): string {
    this.generation();
    return this.store.reason();
  }

  protected get hasReason(): boolean {
    return this.reason !== '';
  }

  protected get actionRefusal(): string {
    return this.removeRefusal();
  }

  protected get hasActionRefusal(): boolean {
    return this.removeRefusal() !== '';
  }

  protected get openedFlag(): boolean {
    this.generation();
    return this.store.opened() !== null;
  }

  protected get administrators(): readonly string[] {
    this.generation();
    return this.store.administrators();
  }

  protected get keys(): readonly KeyRow[] {
    this.generation();
    return this.store.keys();
  }

  /** One administrator is listed, so its Remove is unavailable: a key file keeps at least one. */
  protected get lastAdminFlag(): boolean {
    return this.administrators.length <= 1;
  }

  protected get lastAdmin(): 'true' | null {
    return this.lastAdminFlag ? 'true' : null;
  }

  protected get lastAdminDescribedBy(): string | null {
    return this.lastAdminFlag ? this.lastAdminId : null;
  }

  protected get adminDialogOpen(): boolean {
    return this.open() === 'admin';
  }

  protected get keyDialogOpen(): boolean {
    return this.open() === 'key';
  }

  protected get keyLength(): string {
    return this.values()[KEY_LENGTH] ?? DEFAULT_KEY_LENGTH;
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

  protected get oldAdminReason(): string {
    return this.reasonFor(OLD_ADMIN_NAME);
  }

  protected get oldPasswordReason(): string {
    return this.reasonFor(OLD_ADMIN_PASSWORD);
  }

  protected get newAdminReason(): string {
    return this.reasonFor(NEW_ADMIN_NAME);
  }

  protected get newPasswordReason(): string {
    return this.reasonFor(NEW_ADMIN_PASSWORD);
  }

  protected get confirmReason(): string {
    return this.reasonFor(CONFIRM_FIELD);
  }

  protected get adminNameReason(): string {
    return this.reasonFor(ADMIN_NAME);
  }

  protected get adminPasswordReason(): string {
    return this.reasonFor(ADMIN_PASSWORD);
  }

  protected get keyLengthReason(): string {
    return this.reasonFor(KEY_LENGTH);
  }

  protected controlId(field: string): string {
    return keyFileControlId(field);
  }

  protected value(field: string): string {
    return this.values()[field] ?? '';
  }

  protected invalid(field: string): 'true' | null {
    return this.reasonFor(field) === '' ? null : 'true';
  }

  protected reasonId(field: string): string {
    return `${keyFileControlId(field)}-reason`;
  }

  /** Names the field's reason paragraph while a reason is shown, so a screen reader announces it. */
  protected describedBy(field: string): string | null {
    return this.invalid(field) ? this.reasonId(field) : null;
  }

  // --- intents ---------------------------------------------------------------------------------

  protected onLocation(location: ServerPath): void {
    this.store.setLocation(location.root, location.path);
  }

  protected onOpen(): void {
    if (this.openBlocked) return;
    this.removeRefusal.set('');
    void this.store.open(this.api);
  }

  protected onCreate(): void {
    this.actions.run(ENCRYPTION_KEY_FILE, ENCRYPTION_CREATE_ACTION);
  }

  protected openAdmin(): void {
    if (!this.canOpen()) return;
    const first = this.store.administrators()[0] ?? '';
    this.values.set({ [OLD_ADMIN_NAME]: first });
    this.openDialog('admin');
  }

  protected openKey(): void {
    if (!this.canOpen()) return;
    const first = this.store.administrators()[0] ?? this.session?.userName() ?? '';
    this.values.set({ [ADMIN_NAME]: first, [KEY_LENGTH]: DEFAULT_KEY_LENGTH });
    this.openDialog('key');
  }

  protected closeDialog(): void {
    if (this.sending()) return;
    this.clearDialog();
  }

  protected onValue(field: string, event: Event): void {
    const target = event.target;
    if (!(target instanceof HTMLInputElement) && !(target instanceof HTMLSelectElement)) return;
    this.values.update((held) => ({ ...held, [field]: target.value }));
    if (this.reasonFor(field) !== '') this.violations.update((list) => list.filter((entry) => entry.field !== field));
    this.dialogRefusal.set('');
  }

  /** Add the administrator: refused in the dialog when the new password and its confirmation differ. */
  protected async submitAdmin(): Promise<void> {
    if (this.sending()) return;
    const held = this.values();
    if ((held[NEW_ADMIN_PASSWORD] ?? '') !== (held[CONFIRM_FIELD] ?? '')) {
      this.violations.set([{ field: CONFIRM_FIELD, code: '', reason: STRINGS.ldapPasswordMismatch }]);
      return;
    }
    await this.send(ENCRYPTION_KEY_FILE_ADMINS, ENCRYPTION_ADD_ADMIN, {
      [OLD_ADMIN_NAME]: held[OLD_ADMIN_NAME] ?? '',
      [NEW_ADMIN_NAME]: held[NEW_ADMIN_NAME] ?? '',
      [OLD_ADMIN_PASSWORD]: held[OLD_ADMIN_PASSWORD] ?? '',
      [NEW_ADMIN_PASSWORD]: held[NEW_ADMIN_PASSWORD] ?? '',
    });
  }

  /** Add a key under the named administrator's password. */
  protected async submitKey(): Promise<void> {
    if (this.sending()) return;
    const held = this.values();
    await this.send(ENCRYPTION_KEY_FILE, ENCRYPTION_ADD_KEY, {
      [ADMIN_NAME]: held[ADMIN_NAME] ?? '',
      [ADMIN_PASSWORD]: held[ADMIN_PASSWORD] ?? '',
      [KEY_LENGTH]: held[KEY_LENGTH] ?? DEFAULT_KEY_LENGTH,
      [KEY_DESCRIPTION]: held[KEY_DESCRIPTION] ?? '',
    });
  }

  /** Remove an administrator, after the typed-name dialog; never the last one. */
  protected onRemoveAdmin(name: string): void {
    if (this.lastAdminFlag) return;
    this.startRemove(ENCRYPTION_KEY_FILE_ADMINS, ENCRYPTION_REMOVE_ADMIN, { Name: name });
  }

  /** Remove a key, after the typed-name dialog that asks for its identifier. */
  protected onRemoveKey(key: KeyRow): void {
    this.startRemove(ENCRYPTION_KEY_FILE, ENCRYPTION_REMOVE_KEY, { Id: key.Id });
  }

  // --- internals -------------------------------------------------------------------------------

  private canOpen(): boolean {
    return this.open() === null && !this.sending() && this.store.opened() !== null && this.handler.pending() === null;
  }

  private openDialog(kind: 'admin' | 'key'): void {
    this.violations.set([]);
    this.dialogRefusal.set('');
    this.removeRefusal.set('');
    this.open.set(kind);
  }

  private startRemove(descriptor: string, actionId: string, row: Readonly<Record<string, unknown>>): void {
    const target = this.store.keyFileId();
    if (target === '' || this.open() !== null) return;
    this.removeRefusal.set('');
    const sink: ActionSink = {
      setRefusal: (reason) => this.removeRefusal.set(reason),
      applied: () => void this.store.reread(this.api),
    };
    this.handler.startFor(descriptor, actionId, target, row, sink);
  }

  /** One write for the open dialog, whose refusal is drawn in the dialog (AD-39). */
  private async send(descriptor: string, actionId: string, values: Readonly<Record<string, string>>): Promise<void> {
    const target = this.store.keyFileId();
    if (target === '') return;
    this.sending.set(true);
    this.violations.set([]);
    this.dialogRefusal.set('');
    const sink: ActionSink = { setRefusal: () => undefined };
    const applied = await this.handler.sendFor(descriptor, actionId, target, values, sink);
    this.sending.set(false);
    if (applied) {
      this.clearDialog();
      void this.store.reread(this.api);
      return;
    }
    const refusal = this.handler.lastRefusal();
    if (refusal === null) return;
    const fields = Object.keys(values);
    const onField = refusal.violations.filter((entry) => fields.includes(entry.field));
    this.violations.set(onField);
    this.dialogRefusal.set(onField.length > 0 ? '' : refusal.reason || STRINGS.connectivityRequestRefused);
  }

  private reasonFor(field: string): string {
    return reasonForField(this.violations(), field);
  }

  /** Forget everything a dialog held, passwords first. */
  private clearDialog(): void {
    this.values.set({});
    this.violations.set([]);
    this.dialogRefusal.set('');
    this.sending.set(false);
    this.open.set(null);
  }
}
