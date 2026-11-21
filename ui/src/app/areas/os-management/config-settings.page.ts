import { ChangeDetectionStrategy, Component, DestroyRef, inject, signal } from '@angular/core';
import { Router } from '@angular/router';

import { ApiService } from '../../core/api';
import { ChangeBus } from '../../core/change-bus';
import { screenForUrl } from '../../core/navigation';
import { ScreenActions } from '../../core/screen-actions';
import { ScreenStores, type ScreenStore } from '../../core/screen-store';
import type { ScreenDeclaration } from '../../core/screens.generated';
import { STRINGS } from '../../core/strings';
import { rowFor } from '../../core/table-model';
import { localeEditRefusal } from '../../core/self-protection';
import { reasonForField } from '../../core/violations';
import { DetailPage } from '../../shell/detail-page';
import { ListPage } from '../../shell/list-page';
import { LOCALE_ADD_TABLE, LOCALE_PROPERTY_LIST, ScreenActionHandler } from '../../shell/screen-action-handler';
import { BOOLEAN_TYPE, InteropItemSettingDialog } from '../interoperability/interop-item-setting-dialog';
import { DdlMappingDialog } from './ddl-mapping-dialog';
import { LOCALE_PROPERTY_ENTITY, LOCALE_TABLE_PATH, LOCALE_TABLE_TOOL, postLocaleCreate } from './locale-create';
import { LocaleTableDialog, type LocaleTableValues } from './locale-table-dialog';

/** The descriptors this one page serves (Stories 21.3, 21.4, 21.13 and 21.14). */
export const STARTUP_SETTING_LIST = 'OcuPilot.Screen.Descriptor.StartupSettingList';
export const MEMORY_SETTING_LIST = 'OcuPilot.Screen.Descriptor.MemorySettingList';
export const COMPATIBILITY_SETTING_LIST = 'OcuPilot.Screen.Descriptor.CompatibilitySettingList';
export const SQL_SETTING_LIST = 'OcuPilot.Screen.Descriptor.SqlSettingList';
export const SQL_SHELL_SETTING_LIST = 'OcuPilot.Screen.Descriptor.SqlShellSettingList';
export const TSQL_SETTING_LIST = 'OcuPilot.Screen.Descriptor.TsqlSettingList';
export const ISQL_SETTING_LIST = 'OcuPilot.Screen.Descriptor.IsqlSettingList';
export const DDL_SYSTEM_MAPPING_LIST = 'OcuPilot.Screen.Descriptor.DdlSystemMappingList';
export const DDL_USER_MAPPING_LIST = 'OcuPilot.Screen.Descriptor.DdlUserMappingList';
export const NLS_DEFAULT_LIST = 'OcuPilot.Screen.Descriptor.NlsDefaultList';
/** System-wide security (Story 21.10), a Security screen this page serves with the same dialog. */
export const SYSTEM_SECURITY_SETTING_LIST = 'OcuPilot.Screen.Descriptor.SystemSecuritySettingList';
/** Task Manager email (Story 21.19), a Tasks screen this page serves with the same dialog; its message settings are long text, drawn as a text area. */
export const TASK_MAIL_SETTING_LIST = 'OcuPilot.Screen.Descriptor.TaskMailSettingList';
const TASK_MAIL_MESSAGE_PREFIX = 'Message';
/** Analytics' General settings (Story 24.13): the first tab of the Settings group, a detail screen, whose Set value this page sends. */
export const ANALYTICS_SETTING_LIST = 'OcuPilot.Screen.Descriptor.AnalyticsSettingList';

const SERVED_LISTS: readonly string[] = [
  ANALYTICS_SETTING_LIST,
  STARTUP_SETTING_LIST,
  MEMORY_SETTING_LIST,
  COMPATIBILITY_SETTING_LIST,
  SQL_SETTING_LIST,
  SQL_SHELL_SETTING_LIST,
  TSQL_SETTING_LIST,
  ISQL_SETTING_LIST,
  DDL_SYSTEM_MAPPING_LIST,
  DDL_USER_MAPPING_LIST,
  NLS_DEFAULT_LIST,
  LOCALE_PROPERTY_LIST,
  SYSTEM_SECURITY_SETTING_LIST,
  TASK_MAIL_SETTING_LIST,
];

/** The one NLS configured default a person changes: the switch that makes new processes take the current locale's formats (Story 21.14). */
export const NLS_LOCALE_FORMAT = 'LocaleFormat';

/** The declared row action Set value, which this page's dialog sends. */
export const CONFIG_SET_ACTION = 'set';

/** The declared primary action New mapping, which only the user DDL mappings list carries and this page registers (Story 21.13). */
export const DDL_MAPPING_ADD_ACTION = 'add';

/** The value the dialog sends beside the setting's name, under the name the tools declare (AD-56). */
export const CONFIG_VALUE = 'Value';

/** The declared row action that sets a secret, and the one value it takes: the General tab's Google Maps key (Story 24.13, AD-56 (i)). */
export const CONFIG_SET_KEY_ACTION = 'setkey';
export const CONFIG_KEY_VALUE = 'GoogleMapsKey';

/** Task Manager email's mail password (Story 21.36, AD-56 (i)): its toolbar action, the one value it takes, and the sign-in name's row it targets. */
export const TASK_MAIL_PASSWORD_ACTION = 'password';
export const TASK_MAIL_PASSWORD_VALUE = 'AuthPassword';
export const TASK_MAIL_PASSWORD_TARGET = 'AuthUser';

/** The action that sets a secret and the one value it takes, per descriptor that has one. */
const SECRET_ACTIONS: Readonly<Partial<Record<string, { readonly action: string; readonly value: string }>>> = {
  [ANALYTICS_SETTING_LIST]: { action: CONFIG_SET_KEY_ACTION, value: CONFIG_KEY_VALUE },
  [TASK_MAIL_SETTING_LIST]: { action: TASK_MAIL_PASSWORD_ACTION, value: TASK_MAIL_PASSWORD_VALUE },
};

/** The row kind that is a secret: drawn as an empty masked field and sent with the key's own action. */
export const SECRET_KIND = 'secret';

/** The setting the open dialog changes: its id and what its row reported. */
interface SettingTarget {
  readonly id: string;
  readonly name: string;
  readonly current: string;
  readonly kind: string;
  readonly restart: boolean;
  readonly purges: boolean;
  /** Whether a change reloads the current locale. */
  readonly reloads: boolean;
  /** Whether the setting is a secret, set by its own action from an empty masked field. */
  readonly secret: boolean;
  /** Whether a change stores every General row, which one not yet stored will be. */
  readonly saves: boolean;
  readonly statement: string;
  /** Whether the value is long text, drawn as a text area. */
  readonly multiline: boolean;
  /** The dialog's heading, in place of the one that names the setting; `''` keeps that one. */
  readonly title: string;
  /** Whether the dialog draws the field and its hint alone: no current-value line and no sentence above them. */
  readonly fieldOnly: boolean;
}

/** `value` as text, or `''`. */
function text(value: unknown): string {
  return typeof value === 'string' || typeof value === 'number' ? String(value) : '';
}

/**
 * Startup, Memory, Compatibility, SQL, SQL Shell, TSQL, ISQL, DDL mapping and NLS configured default settings (Stories 21.3, 21.4, 21.13 and 21.14, AD-5, AD-53): the shared list page over each
 * descriptor's declared table, and over it the Set value dialog.
 *
 * **One page serves the descriptors**, which differ only in the settings they read; it resolves its screen from the URL, as the list page
 * does. Set value is this page's own action, registered after injecting the shell's handler, and it opens `InteropItemSettingDialog` as it is,
 * with the row's `Accepts` line above the field and, when the row's `Restart` is true, the restart sentence after it, or, when the row's
 * `Purges` is true, the sentence that the cached queries of every namespace are purged.
 *
 * **A row the port reads as shown and never changed offers no Set value**: the registration's reason is the published refusal sentence, so
 * every surface draws the action unavailable with that sentence, and opening it opens nothing. The value goes through the handler's `sendFor`
 * with `Value` as its one value, an empty one allowed. A refusal stays in the dialog, on the value's field where the instance names it. After
 * an applied change on a row whose `Restart` is true, the page states the restart sentence above the list; after one that changed the value of a
 * row whose `Purges` is true, it states the purge sentence there.
 *
 * **New mapping is the user DDL mappings list's primary action**, registered by this page on that screen alone: it opens `DdlMappingDialog`, which
 * posts to the Save route and publishes the create. The system list has none, as the classic page offers no create of a system mapping. A DDL
 * mapping row is never shown and never changed in any other way than its datatype, so its Set value is the dialog above with the row's `Accepts` line.
 *
 * **NLS configured defaults offer Set value on the locale-format switch alone**: every table row is read-only and so refused as above. The
 * switch's dialog and the line after an applied change state that the current locale is reloaded.
 *
 * **Locale properties** (Story 21.16) are served here too: Set value's reason is the row's `Refusal` sentence, else the read-only one, and Add
 * table, which this page registers on that screen alone, opens `LocaleTableDialog` and posts `<list>:<table>` of the screen's locale to the add tool's own
 * Save route, its reason the sentence every row of the locale carries.
 */
@Component({
  selector: 'app-config-settings-page',
  changeDetection: ChangeDetectionStrategy.OnPush,
  imports: [ListPage, DetailPage, InteropItemSettingDialog, DdlMappingDialog, LocaleTableDialog],
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
    @if (shownPurge; as note) {
      <p class="ocu-banner" role="status" data-config-setting-purge>{{ note }}</p>
    }
    @if (shownReload; as note) {
      <p class="ocu-banner" role="status" data-config-setting-reload>{{ note }}</p>
    }
    @if (shownSave; as note) {
      <p class="ocu-banner" role="status" data-config-setting-save>{{ note }}</p>
    }
    @if (detailTab) {
      <app-detail-page />
    } @else {
      <app-list-page />
    }
    @if (adding) {
      <app-ddl-mapping-dialog (added)="onCloseAdd()" (cancelled)="onCloseAdd()" />
    }
    @if (tableAdding) {
      <app-locale-table-dialog [refusal]="tableRefusal()" [sending]="tableSending()" (submitted)="onAddTable($event)" (cancelled)="onCloseAddTable()" />
    }
    @if (openTarget; as target) {
      <app-interop-item-setting-dialog
        [name]="target.name"
        [title]="target.title"
        [current]="target.current"
        [type]="target.kind === 'boolean' ? booleanType : ''"
        [secret]="target.secret"
        [multiline]="target.multiline"
        [statement]="target.statement"
        [currentShown]="!target.fieldOnly"
        [consequenceShown]="!target.fieldOnly"
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

  private readonly api = inject(ApiService);

  private readonly bus = inject(ChangeBus);

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

  /** The purge sentence stated after an applied change that purged the cached queries, or `''`. */
  protected readonly purgeNote = signal('');

  /** The reload sentence stated after an applied change of the locale-format switch, or `''`. */
  protected readonly reloadNote = signal('');

  /** Whether the New mapping dialog is open. */
  private readonly addOpen = signal(false);

  protected get shownRestart(): string {
    return this.restartNote();
  }

  protected get shownPurge(): string {
    return this.purgeNote();
  }

  protected get shownReload(): string {
    return this.reloadNote();
  }

  /** The save sentence stated after an applied change of a General setting that stored every row, or `''`. */
  protected readonly saveNote = signal('');

  protected get shownSave(): string {
    return this.saveNote();
  }

  /** Whether this screen is a detail tab (Analytics' General settings), drawn by the detail page. */
  protected get detailTab(): boolean {
    return this.screen?.descriptor === ANALYTICS_SETTING_LIST;
  }

  protected get openTarget(): SettingTarget | null {
    const target = this.target();
    // A system-wide security parameter's dialog states what a change reaches, after the line the row's own flags give it (Story 21.10).
    if (target === null || this.screen?.descriptor !== SYSTEM_SECURITY_SETTING_LIST) return target;
    return { ...target, statement: `${target.statement} ${STRINGS.systemSecuritySetConsequence}` };
  }

  protected get adding(): boolean {
    return this.addOpen();
  }

  /** Whether the Add table dialog is open, its last refusal and whether a send is in flight (Story 21.16). */
  private readonly tableOpen = signal(false);

  protected readonly tableRefusal = signal('');

  protected readonly tableSending = signal(false);

  protected get tableAdding(): boolean {
    return this.tableOpen();
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
      () => {
        const row = this.selectedRow();
        if (this.screen?.descriptor === LOCALE_PROPERTY_LIST) {
          const refusal = localeEditRefusal(row?.['Refusal']);
          if (refusal !== '') return refusal;
        }
        return row?.['ReadOnly'] === true ? STRINGS.configRefusalReadOnly : '';
      }
    );
    const stopAdd = this.screen.descriptor === DDL_USER_MAPPING_LIST ? this.actions.register(this.screen.descriptor, DDL_MAPPING_ADD_ACTION, () => this.onOpenAdd()) : (): void => undefined;
    const stopTable =
      this.screen.descriptor === LOCALE_PROPERTY_LIST
        ? this.actions.register(this.screen.descriptor, LOCALE_ADD_TABLE, () => this.onOpenAddTable(), () => localeEditRefusal(this.localeRows()[0]?.['Refusal']))
        : (): void => undefined;
    const stopPassword =
      this.screen.descriptor === TASK_MAIL_SETTING_LIST ? this.actions.register(this.screen.descriptor, TASK_MAIL_PASSWORD_ACTION, () => this.onOpenPassword()) : (): void => undefined;
    inject(DestroyRef).onDestroy(() => {
      stop();
      stopAdd();
      stopTable();
      stopPassword();
    });
  }

  /** The locale's rows the list holds, or none while it has not read. */
  private localeRows(): readonly Readonly<Record<string, unknown>>[] {
    if (this.screen === null || this.store === null) return [];
    return this.store.data().filter((entry): entry is Readonly<Record<string, unknown>> => entry !== null && typeof entry === 'object');
  }

  /** Open the Add table dialog, never over another dialog, never before the list has read its locale, and never for a locale that admits no change. */
  protected onOpenAddTable(): void {
    if (this.tableOpen() || this.target() !== null || this.addOpen() || this.handler.pending() !== null) return;
    if (typeof this.localeRows()[0]?.['Locale'] !== 'string') return;
    if (localeEditRefusal(this.localeRows()[0]?.['Refusal']) !== '') return;
    this.tableRefusal.set('');
    this.tableOpen.set(true);
  }

  protected onCloseAddTable(): void {
    this.tableOpen.set(false);
    this.tableRefusal.set('');
  }

  /** One Add table posted to the Save route, with the screen's locale and the new row; a refusal stays in the dialog. */
  protected async onAddTable(values: LocaleTableValues): Promise<void> {
    const locale = this.localeRows()[0]?.['Locale'];
    if (this.screen === null || typeof locale !== 'string' || this.tableSending()) return;
    this.tableSending.set(true);
    this.tableRefusal.set('');
    const body: Record<string, string> = { Locale: locale, Name: values.name };
    if (values.inputFrom !== '') body['InputFrom'] = values.inputFrom;
    if (values.outputTo !== '') body['OutputTo'] = values.outputTo;
    const outcome = await postLocaleCreate({
      api: this.api,
      bus: this.bus,
      path: LOCALE_TABLE_PATH,
      body,
      type: LOCALE_PROPERTY_ENTITY,
      tool: LOCALE_TABLE_TOOL,
      fallbackId: `${locale}\u0001${values.name}`,
    });
    this.tableSending.set(false);
    if (outcome.accepted) {
      this.onCloseAddTable();
      return;
    }
    this.tableRefusal.set(outcome.reason);
  }

  private serves(descriptor: string): boolean {
    return SERVED_LISTS.includes(descriptor);
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
    this.purgeNote.set('');
    this.reloadNote.set('');
    this.saveNote.set('');
    const accepts = text(row['Accepts']);
    const purges = row['Purges'] === true;
    const reloads = this.screen?.descriptor === NLS_DEFAULT_LIST && text(row['Name']) === NLS_LOCALE_FORMAT;
    const secret = text(row['Kind']) === SECRET_KIND;
    const saves = this.savesEveryRow(row);
    this.target.set({
      id: selected,
      name: text(row['Name']),
      current: text(row['Value']),
      kind: text(row['Kind']),
      restart: row['Restart'] === true,
      purges,
      reloads,
      secret,
      saves,
      multiline: this.screen?.descriptor === TASK_MAIL_SETTING_LIST && text(row['Name']).startsWith(TASK_MAIL_MESSAGE_PREFIX),
      title: '',
      fieldOnly: false,
      statement:
        row['Restart'] === true
          ? `${accepts} ${STRINGS.encryptionStartupRestart}`
          : purges
            ? `${accepts} ${STRINGS.configSettingPurge}`
            : reloads
              ? `${accepts} ${STRINGS.nlsDefaultReloadConsequence}`
              : saves
                ? `${accepts} ${STRINGS.analyticsSettingSaveConsequence}`
                : accepts,
    });
  }

  /**
   * Whether the change of `row` stores every General row (Story 24.13): a General setting other than the Worklist flag, while the list holds a row that is not stored. The page's Save
   * stores the whole form, so the first change in a namespace that has never saved stores them all.
   */
  private savesEveryRow(row: Readonly<Record<string, unknown>>): boolean {
    if (this.screen?.descriptor !== ANALYTICS_SETTING_LIST || this.store === null || text(row['Name']) === 'Worklist') return false;
    return this.store.data().some((entry) => entry !== null && typeof entry === 'object' && (entry as Readonly<Record<string, unknown>>)['Name'] !== 'Worklist' && (entry as Readonly<Record<string, unknown>>)['Stored'] === false);
  }

  /**
   * Open the Set mail password dialog from the toolbar (Story 21.36): the masked field and the mail password's own action, aimed at the sign-in name's row whatever row is selected. The
   * password is never read, so the dialog states no current value, and an empty one clears it.
   */
  protected onOpenPassword(): void {
    if (this.target() !== null || this.handler.pending() !== null || this.store === null) return;
    this.store.setRefusal('');
    this.refusal.set('');
    this.violation.set('');
    this.restartNote.set('');
    this.purgeNote.set('');
    this.reloadNote.set('');
    this.saveNote.set('');
    this.target.set({
      id: TASK_MAIL_PASSWORD_TARGET,
      name: TASK_MAIL_PASSWORD_TARGET,
      current: '',
      kind: SECRET_KIND,
      restart: false,
      purges: false,
      reloads: false,
      secret: true,
      saves: false,
      multiline: false,
      title: STRINGS.taskMailPasswordAction,
      fieldOnly: true,
      statement: '',
    });
  }

  /** Open the New mapping dialog, never over a dialog of the handler's or the Set value one. */
  protected onOpenAdd(): void {
    if (this.addOpen() || this.target() !== null || this.handler.pending() !== null) return;
    this.addOpen.set(true);
  }

  protected onCloseAdd(): void {
    this.addOpen.set(false);
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
    // A secret is sent by its own action under its own name, from the masked field (AD-56 (i)); every other setting by Set value.
    const secretAction = target.secret ? SECRET_ACTIONS[this.screen.descriptor] : undefined;
    const action = secretAction?.action ?? CONFIG_SET_ACTION;
    const field = secretAction?.value ?? CONFIG_VALUE;
    const applied = await this.handler.sendFor(this.screen.descriptor, action, target.id, { [field]: value }, { setRefusal: () => undefined });
    this.sending.set(false);
    // A dialog canceled while this send was in flight no longer answers it.
    if (this.target() !== target) return;
    if (applied) {
      this.onClose();
      this.saveNote.set(target.saves ? STRINGS.analyticsSettingSaveConsequence : '');
      this.restartNote.set(target.restart ? STRINGS.encryptionStartupRestart : '');
      this.purgeNote.set(target.purges && value !== target.current ? STRINGS.configSettingPurge : '');
      this.reloadNote.set(target.reloads && value !== target.current ? STRINGS.nlsDefaultReloadConsequence : '');
      return;
    }
    const refused = this.handler.lastRefusal();
    const onField = reasonForField(refused?.violations ?? [], field);
    if (onField !== '') this.violation.set(onField);
    else this.refusal.set(refused?.reason ?? '');
  }
}
