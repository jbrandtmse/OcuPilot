import {
  ChangeDetectionStrategy,
  Component,
  DestroyRef,
  Injector,
  type Type,
  afterNextRender,
  computed,
  inject,
  signal,
} from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { ActivatedRoute, RouterOutlet } from '@angular/router';

import { decodeEntityId } from '../core/entity-id';
import { NavigationService, screenForUrl } from '../core/navigation';
import type { ArchetypeKey, BuiltArchetypeKey } from '../core/screens.generated';
import { ShellState } from '../core/shell-state';
import { STRINGS, stringFor } from '../core/strings';
import { ScreenDenied } from './screen-denied';

/**
 * Fetches one page's code and answers its component. Every page is a lazily loaded chunk: no
 * module of the initial bundle imports a page module statically, and `app.routes.ts` hands each
 * screen route's child `loadComponent` the loader these maps name for it, through `rememberedPage`
 * (AD-5).
 */
export type PageLoader = () => Promise<Type<unknown>>;

/**
 * Archetype to page loader (AD-5).
 *
 * **This is what keeps "adding a screen" from meaning "editing a router".** A descriptor
 * declares an archetype; the route table is generated from the mirror and points every route at
 * this one component; and the page that loads is looked up by that declared archetype, or by the
 * descriptor itself where `DESCRIPTOR_PAGES` names one -- never by a route-table entry naming a
 * component, and never by a per-screen `@if`. A slice adding the first screen of a new archetype
 * registers it in this map and nothing else changes; a slice adding a screen of an archetype
 * already here changes nothing at all unless that archetype's page is not its own. A new page is
 * one loader line, `() => import('<path>').then((m) => m.<Page>)`.
 *
 * **A built archetype must have a page.** Every `BuiltArchetypeKey` -- the archetype of a
 * `built: true` descriptor, emitted by the mirror -- is a required key here, so a descriptor
 * that sets `built: true` before its page is registered fails `ng build` naming the missing
 * archetype. Any other archetype is optional, and one with no entry renders nothing. Exported so
 * `screen-outlet.spec.ts` can assert that refusal against this map's own type.
 */
type ArchetypePages = { readonly [K in BuiltArchetypeKey]: PageLoader } & {
  readonly [K in Exclude<ArchetypeKey, BuiltArchetypeKey>]?: PageLoader;
};

export const ARCHETYPE_PAGES: ArchetypePages = {
  home: () => import('../areas/home/home.page').then((m) => m.HomePage),
  list: () => import('./list-page').then((m) => m.ListPage),
  'list (two views)': () => import('../areas/os-management/databases.page').then((m) => m.DatabasesPage),
  'list (server criteria)': () => import('../areas/logs/audit.page').then((m) => m.AuditPage),
  'drill-down': () => import('../areas/logs/error-log.page').then((m) => m.ErrorLogPage),
  'log-viewer': () => import('../areas/logs/log-viewer.page').then((m) => m.LogViewerPage),
  'form-page': () => import('../areas/agent/definition-form.page').then((m) => m.DefinitionFormPage),
  'viewer (OpenAPI)': () => import('../areas/web-applications/openapi-viewer.page').then((m) => m.OpenApiViewerPage),
  'viewer (source)': () => import('../areas/system-explorer/document-viewer.page').then((m) => m.SourceViewerPage),
  detail: () => import('./detail-page').then((m) => m.DetailPage),
  meters: () => import('../areas/os-management/system-usage.page').then((m) => m.SystemUsagePage),
};

/**
 * The pages that serve a descriptor's bare route and its id route alike. Both maps name the one
 * loader, so the two routes share what `rememberedPage` has loaded, and a create's hand-off to its
 * own id route commits before the next render.
 */
const SERVICE_EDITOR_PAGE: PageLoader = () => import('../areas/permissions/service-editor.page').then((m) => m.ServiceEditorPage);
const LDAP_EDITOR_PAGE: PageLoader = () => import('../areas/security/ldap-editor.page').then((m) => m.LdapEditorPage);

/** Stories 20.7 and 20.8: the one page the rule, BPL and DTL editor screens, the Schema viewer and the Configuration diagram share, each descriptor naming this loader. */
const INTEROP_EDITOR_PAGE: PageLoader = () => import('../areas/interoperability/interop-editor.page').then((m) => m.InteropEditorPage);

/** Story 20.9: a message's Contents tab, the detail page drawing its rows as one block of text. */
const INTEROP_MESSAGE_CONTENTS_PAGE: PageLoader = () => import('../areas/interoperability/interop-message-contents.page').then((m) => m.InteropMessageContentsPage);

/**
 * Pages keyed by the descriptor that declares them, resolved **before** the archetype map
 * (DW-369).
 *
 * An archetype one screen serves is a map entry; an archetype several screens serve each in their
 * own way is not. `form-page` is the first of those: the Definition form, Switches, Auditing
 * configuration and the create and edit forms are all `form-page` screens with nothing in common
 * but their shell, and a map keyed by archetype alone can only ever hand them all the same
 * component. Registering the exception here, rather than widening
 * the archetype vocabulary, keeps `ARCHETYPE_PAGES`' exhaustiveness guarantee -- every
 * `BuiltArchetypeKey` still needs an entry there, so a new built archetype with no page still
 * fails `ng build`.
 *
 * A descriptor with no entry falls through to its archetype's page, which is every screen but the
 * ones named here.
 */
export const DESCRIPTOR_PAGES: Readonly<Record<string, PageLoader>> = {
  'OcuPilot.Screen.Descriptor.AgentSwitches': () => import('../areas/agent/switches.page').then((m) => m.SwitchesPage),
  'OcuPilot.Screen.Descriptor.AgentGuardrails': () => import('../areas/agent/guardrails.page').then((m) => m.GuardrailsPage),
  'OcuPilot.Screen.Descriptor.AgentTranscript': () => import('../areas/agent/transcript.page').then((m) => m.TranscriptPage),
  'OcuPilot.Screen.Descriptor.AuditingConfig': () => import('../areas/security/auditing-config.page').then((m) => m.AuditingConfigPage),
  'OcuPilot.Screen.Descriptor.TaskUpcomingList': () => import('../areas/tasks/upcoming.page').then((m) => m.UpcomingPage),
  'OcuPilot.Screen.Descriptor.TaskHistoryList': () => import('../areas/tasks/history.page').then((m) => m.HistoryPage),
  'OcuPilot.Screen.Descriptor.TaskDetails': () => import('../areas/tasks/details.page').then((m) => m.TaskDetailsPage),
  'OcuPilot.Screen.Descriptor.ProcessDetails': () => import('../areas/os-management/process-details.page').then((m) => m.ProcessDetailsPage),
  'OcuPilot.Screen.Descriptor.DatabaseFreeSpace': () => import('../areas/os-management/databases.page').then((m) => m.DatabasesPage),
  'OcuPilot.Screen.Descriptor.DatabaseDetails': () => import('../areas/os-management/database-details.page').then((m) => m.DatabaseDetailsPage),
  'OcuPilot.Screen.Descriptor.WebAppForm': () => import('../areas/web-applications/create-form.page').then((m) => m.WebAppCreateFormPage),
  'OcuPilot.Screen.Descriptor.UserForm': () => import('../areas/permissions/user-create-form.page').then((m) => m.UserCreateFormPage),
  'OcuPilot.Screen.Descriptor.RoleForm': () => import('../areas/permissions/role-create-form.page').then((m) => m.RoleCreateFormPage),
  'OcuPilot.Screen.Descriptor.ResourceList': () => import('../areas/permissions/resource-list.page').then((m) => m.ResourceListPage),
  'OcuPilot.Screen.Descriptor.X509Form': () => import('../areas/security/x509-form.page').then((m) => m.X509FormPage),
  'OcuPilot.Screen.Descriptor.OAuthServerDescriptionForm': () => import('../areas/security/oauth-server-description-form.page').then((m) => m.OAuthServerDescriptionFormPage),
  'OcuPilot.Screen.Descriptor.OAuthClientForm': () => import('../areas/security/oauth-client-form.page').then((m) => m.OAuthClientFormPage),
  'OcuPilot.Screen.Descriptor.OAuthResourceServerForm': () => import('../areas/security/oauth-resource-server-form.page').then((m) => m.OAuthResourceServerFormPage),
  'OcuPilot.Screen.Descriptor.OAuthServerForm': () => import('../areas/security/oauth-server-form.page').then((m) => m.OAuthServerFormPage),
  'OcuPilot.Screen.Descriptor.OAuthServerClientForm': () => import('../areas/security/oauth-registered-client-form.page').then((m) => m.OAuthRegisteredClientFormPage),
  'OcuPilot.Screen.Descriptor.WalletSecretForm': () => import('../areas/security/wallet-secret-form.page').then((m) => m.WalletSecretFormPage),
  'OcuPilot.Screen.Descriptor.DeviceForm': () => import('../areas/os-management/device-form.page').then((m) => m.DeviceFormPage),
  'OcuPilot.Screen.Descriptor.NamespaceForm': () => import('../areas/os-management/namespace-form.page').then((m) => m.NamespaceFormPage),
  // Story 18.14: the Namespaces list with its Copy mappings, and the one page serving the three
  // mapping forms, which takes the kind from the route.
  'OcuPilot.Screen.Descriptor.NamespaceList': () => import('../areas/os-management/namespace-list.page').then((m) => m.NamespaceListPage),
  'OcuPilot.Screen.Descriptor.GlobalMappingForm': () => import('../areas/os-management/mapping-form.page').then((m) => m.MappingFormPage),
  'OcuPilot.Screen.Descriptor.RoutineMappingForm': () => import('../areas/os-management/mapping-form.page').then((m) => m.MappingFormPage),
  'OcuPilot.Screen.Descriptor.PackageMappingForm': () => import('../areas/os-management/mapping-form.page').then((m) => m.MappingFormPage),
  // Story 18.3: the local database form's bare route is the create wizard.
  'OcuPilot.Screen.Descriptor.LocalDatabaseForm': () => import('../areas/os-management/database-wizard.page').then((m) => m.DatabaseWizardPage),
  // Story 18.4: the Check integrity flow, a stepped form page of its own.
  'OcuPilot.Screen.Descriptor.DatabaseIntegrity': () => import('../areas/os-management/database-integrity.page').then((m) => m.DatabaseIntegrityPage),
  'OcuPilot.Screen.Descriptor.SslForm': () => import('../areas/security/ssl-form.page').then((m) => m.SslFormPage),
  'OcuPilot.Screen.Descriptor.TaskForm': () => import('../areas/tasks/task-wizard.page').then((m) => m.TaskWizardPage),
  // Story 16.13: the service editor serves its bare route and its id route.
  'OcuPilot.Screen.Descriptor.ServiceForm': SERVICE_EDITOR_PAGE,
  // Story 16.14: the LDAP and Kerberos editor creates at its bare route and edits at its id route.
  'OcuPilot.Screen.Descriptor.LdapConfigForm': LDAP_EDITOR_PAGE,
  'OcuPilot.Screen.Descriptor.AuditUserEventList': () => import('../areas/security/audit-user-event-list.page').then((m) => m.AuditUserEventListPage),
  'OcuPilot.Screen.Descriptor.AgentGovernance': () => import('../areas/agent/governance.page').then((m) => m.GovernancePage),
  'OcuPilot.Screen.Descriptor.LogHub': () => import('../areas/logs/log-hub.page').then((m) => m.LogHubPage),
  'OcuPilot.Screen.Descriptor.AgentLedger': () => import('../areas/agent/ledger.page').then((m) => m.LedgerPage),
  // Story 16.7: the Dashboard's seven meter groups; System usage keeps the meters archetype's page.
  'OcuPilot.Screen.Descriptor.Dashboard': () => import('../areas/os-management/dashboard.page').then((m) => m.DashboardPage),
  // Story 18.36: the Dashboard's two statistics drill-downs, one page of grouped counters; its resource and
  // process drill-downs are lists and keep the list archetype's page.
  'OcuPilot.Screen.Descriptor.DashboardGlobals': () => import('../areas/os-management/statistics.page').then((m) => m.StatisticsPage),
  'OcuPilot.Screen.Descriptor.DashboardEcp': () => import('../areas/os-management/statistics.page').then((m) => m.StatisticsPage),
  // Story 16.4: the Task schedule with its Export and Import dialogs.
  'OcuPilot.Screen.Descriptor.TaskScheduleList': () => import('../areas/tasks/task-schedule.page').then((m) => m.TaskSchedulePage),
  // Story 16.25: the external language server editor, create and edit alike.
  'OcuPilot.Screen.Descriptor.LanguageServerForm': () => import('../areas/os-management/language-server-form.page').then((m) => m.LanguageServerFormPage),
  // Story 16.12: the Locks list with its Remove locks dialog.
  'OcuPilot.Screen.Descriptor.LockList': () => import('../areas/os-management/lock-list.page').then((m) => m.LockListPage),
  // Story 18.16: the remote database form, create and re-point alike.
  'OcuPilot.Screen.Descriptor.RemoteDatabaseForm': () => import('../areas/os-management/remote-database-form.page').then((m) => m.RemoteDatabaseFormPage),
  // Story 18.5: Journals with its two switches and the integrity check's line, and Journal file
  // details with the file's databases.
  'OcuPilot.Screen.Descriptor.JournalList': () => import('../areas/os-management/journal-list.page').then((m) => m.JournalListPage),
  'OcuPilot.Screen.Descriptor.JournalFileDetails': () => import('../areas/os-management/journal-file-details.page').then((m) => m.JournalFileDetailsPage),
  // Story 18.18: Journal settings, a form over the screen's own declared read.
  'OcuPilot.Screen.Descriptor.JournalSettings': () => import('../areas/os-management/journal-settings.page').then((m) => m.JournalSettingsPage),
  // Story 18.19: Journal records, the record list a journal file opens, with its record dialog.
  'OcuPilot.Screen.Descriptor.JournalRecordList': () => import('../areas/os-management/journal-records.page').then((m) => m.JournalRecordsPage),
  // Story 18.6: License key with its activate dialog and Print, and the license server form, create
  // and edit alike.
  'OcuPilot.Screen.Descriptor.LicenseKey': () => import('../areas/os-management/license-key.page').then((m) => m.LicenseKeyPage),
  'OcuPilot.Screen.Descriptor.LicenseServerForm': () => import('../areas/os-management/license-server-form.page').then((m) => m.LicenseServerFormPage),
  // Story 18.20: ECP data servers with its status line and Change status dialog, and the data server
  // form, create and edit alike.
  'OcuPilot.Screen.Descriptor.EcpDataServerList': () => import('../areas/os-management/ecp-data-server-list.page').then((m) => m.EcpDataServerListPage),
  // Story 20.15: Screen permissions, whose Change permissions dialog opens over the shared list page.
  'OcuPilot.Screen.Descriptor.AgentScreenPermissions': () => import('../areas/agent/screen-permissions.page').then((m) => m.ScreenPermissionsPage),
  'OcuPilot.Screen.Descriptor.EcpDataServerForm': () => import('../areas/os-management/ecp-data-server-form.page').then((m) => m.EcpDataServerFormPage),
  // Story 18.21: ECP settings, a form over the screen's own declared read; ECP application servers'
  // two tabs take the detail page's strip.
  'OcuPilot.Screen.Descriptor.EcpSettings': () => import('../areas/os-management/ecp-settings.page').then((m) => m.EcpSettingsPage),
  // Story 18.7: Encryption key files, one page over a key file's keys and its administrators, and the
  // key file create form.
  'OcuPilot.Screen.Descriptor.EncryptionKeyFile': () => import('../areas/security/encryption-key-file.page').then((m) => m.EncryptionKeyFilePage),
  'OcuPilot.Screen.Descriptor.EncryptionKeyFileAdminList': () => import('../areas/security/encryption-key-file.page').then((m) => m.EncryptionKeyFilePage),
  'OcuPilot.Screen.Descriptor.EncryptionKeyFileForm': () => import('../areas/security/encryption-key-file-form.page').then((m) => m.EncryptionKeyFileFormPage),
  // Story 18.22: Database encryption and Data element encryption, one page over each list of active keys.
  'OcuPilot.Screen.Descriptor.DatabaseEncryption': () => import('../areas/security/encryption-keys.page').then((m) => m.EncryptionKeysPage),
  'OcuPilot.Screen.Descriptor.DataElementEncryption': () => import('../areas/security/encryption-keys.page').then((m) => m.EncryptionKeysPage),
  // Story 18.23: the encryption startup settings form, reached from Database encryption.
  'OcuPilot.Screen.Descriptor.EncryptionStartup': () => import('../areas/security/encryption-startup.page').then((m) => m.EncryptionStartupPage),
  // Story 18.8: Authentication options, a form over the screen's own declared read.
  'OcuPilot.Screen.Descriptor.AuthOptions': () => import('../areas/security/auth-options.page').then((m) => m.AuthOptionsPage),
  // Story 18.25: the superserver editor; the list is the shared list page.
  'OcuPilot.Screen.Descriptor.SuperserverForm': () => import('../areas/security/superserver-form.page').then((m) => m.SuperserverFormPage),
  // Story 18.26: the managed file transfer connection editor; the list is the shared list page.
  'OcuPilot.Screen.Descriptor.MftConnectionForm': () => import('../areas/security/mft-connection-form.page').then((m) => m.MftConnectionFormPage),
  // Story 18.30: the Doc DB application editor; the list is the shared list page.
  'OcuPilot.Screen.Descriptor.DocDbAppForm': () => import('../areas/web-applications/docdb-app-form.page').then((m) => m.DocDbAppFormPage),
  // Story 18.31: the privileged routine application editor; the list is the shared list page.
  'OcuPilot.Screen.Descriptor.RoutineAppForm': () => import('../areas/web-applications/routine-app-form.page').then((m) => m.RoutineAppFormPage),
  // Story 19.1: System Explorer's two lists, each a criteria form drawn from its declared criteria.
  'OcuPilot.Screen.Descriptor.ExplorerClassList': () => import('../areas/system-explorer/code-list.page').then((m) => m.CodeListPage),
  'OcuPilot.Screen.Descriptor.ExplorerRoutineList': () => import('../areas/system-explorer/code-list.page').then((m) => m.CodeListPage),
  // Story 19.3: the class and routine editors, one page serving both.
  'OcuPilot.Screen.Descriptor.ExplorerClassEditor': () => import('../areas/system-explorer/source-editor.page').then((m) => m.SourceEditorPage),
  'OcuPilot.Screen.Descriptor.ExplorerRoutineEditor': () => import('../areas/system-explorer/source-editor.page').then((m) => m.SourceEditorPage),
  // Story 19.4: Search, Compare and Macros, each a page of its own.
  'OcuPilot.Screen.Descriptor.ExplorerSearch': () => import('../areas/system-explorer/code-search.page').then((m) => m.CodeSearchPage),
  'OcuPilot.Screen.Descriptor.ExplorerCompare': () => import('../areas/system-explorer/code-compare.page').then((m) => m.CodeComparePage),
  'OcuPilot.Screen.Descriptor.ExplorerMacro': () => import('../areas/system-explorer/macro-lookup.page').then((m) => m.MacroLookupPage),
  // Story 19.5: the SQL catalog's four lists, each a criteria form drawn from its declared criteria.
  'OcuPilot.Screen.Descriptor.ExplorerSqlSchemas': () => import('../areas/system-explorer/code-list.page').then((m) => m.CodeListPage),
  'OcuPilot.Screen.Descriptor.ExplorerSqlTables': () => import('../areas/system-explorer/code-list.page').then((m) => m.CodeListPage),
  'OcuPilot.Screen.Descriptor.ExplorerSqlViews': () => import('../areas/system-explorer/code-list.page').then((m) => m.CodeListPage),
  'OcuPilot.Screen.Descriptor.ExplorerSqlProcedures': () => import('../areas/system-explorer/code-list.page').then((m) => m.CodeListPage),
  // Story 19.6: SQL query, the console with its guard's confirmation.
  'OcuPilot.Screen.Descriptor.ExplorerSqlQuery': () => import('../areas/system-explorer/sql-query.page').then((m) => m.SqlQueryPage),
  // Story 19.7: Data browser, the schema tree beside one table's or view's paged grid.
  'OcuPilot.Screen.Descriptor.ExplorerSqlData': () => import('../areas/system-explorer/data-browser.page').then((m) => m.DataBrowserPage),
  // Story 19.17: Document databases, the list with its create dialog and the disabled-service strip.
  'OcuPilot.Screen.Descriptor.ExplorerDocDbList': () => import('../areas/system-explorer/docdb-list.page').then((m) => m.DocDbListPage),
  // Story 18.34: the REST API explorer, the list with its create dialog.
  'OcuPilot.Screen.Descriptor.RestApiList': () => import('../areas/web-applications/rest-api-list.page').then((m) => m.RestApiListPage),
  // Story 20.3: Production items, the list with its add dialog.
  'OcuPilot.Screen.Descriptor.InteropItemList': () => import('../areas/interoperability/interop-item-list.page').then((m) => m.InteropItemListPage),
  // Story 20.22: Item settings, the list with its Set value dialog.
  'OcuPilot.Screen.Descriptor.InteropItemSettingList': () => import('../areas/interoperability/interop-item-setting-list.page').then((m) => m.InteropItemSettingListPage),
  // Story 20.6: an item's Test tab, the detail page with its Send test dialog.
  'OcuPilot.Screen.Descriptor.InteropItemTestTab': () => import('../areas/interoperability/interop-item-test.page').then((m) => m.InteropItemTestPage),
  // Story 20.5: Lookup tables, the list with its New table dialog, and a table's entries with their Add entry and Set value dialogs.
  'OcuPilot.Screen.Descriptor.InteropLookupTableList': () => import('../areas/interoperability/interop-lookup-table-list.page').then((m) => m.InteropLookupTableListPage),
  'OcuPilot.Screen.Descriptor.InteropLookupEntryList': () => import('../areas/interoperability/interop-lookup-entry-list.page').then((m) => m.InteropLookupEntryListPage),
  // Story 20.27: Data transformations, the list with its Test dialog.
  'OcuPilot.Screen.Descriptor.InteropTransformList': () => import('../areas/interoperability/interop-transform-list.page').then((m) => m.InteropTransformListPage),
  // Story 20.7: the rule, BPL and DTL editor screens, the vendor's editor in a frame at <list>/document/<class>.cls.
  'OcuPilot.Screen.Descriptor.InteropRuleEditor': INTEROP_EDITOR_PAGE,
  'OcuPilot.Screen.Descriptor.InteropProcessEditor': INTEROP_EDITOR_PAGE,
  'OcuPilot.Screen.Descriptor.InteropTransformEditor': INTEROP_EDITOR_PAGE,
  // Story 20.8: the Schema viewer and the Configuration diagram, the vendor's apps in the same frame.
  'OcuPilot.Screen.Descriptor.InteropSchemaViewer': INTEROP_EDITOR_PAGE,
  'OcuPilot.Screen.Descriptor.InteropProductionDiagram': INTEROP_EDITOR_PAGE,
  // Story 20.9: a message's Contents tab. The Messages search and the Header tab use their archetypes' pages.
  'OcuPilot.Screen.Descriptor.InteropMessageContentsTab': INTEROP_MESSAGE_CONTENTS_PAGE,
};

/**
 * Pages keyed by the descriptor that declares them, for that descriptor's **id route** alone, and
 * resolved before `DESCRIPTOR_PAGES` there (Story 9.1).
 *
 * A paired form's `<route>` creates and its `<route>/<id>` edits. Where the two are one page (the
 * device editor) `DESCRIPTOR_PAGES` serves both; where the edit is a page of its own -- the user
 * editor beside the create form Story 8.2 shipped, the web application editor beside Story 8.1's,
 * the role editor beside Story 8.3's, and Edit task beside the New Task wizard (Story 9.8) -- it is
 * registered here, and the bare route keeps the create page.
 */
export const DESCRIPTOR_EDIT_PAGES: Readonly<Record<string, PageLoader>> = {
  'OcuPilot.Screen.Descriptor.UserForm': () => import('../areas/permissions/user-editor.page').then((m) => m.UserEditorPage),
  'OcuPilot.Screen.Descriptor.WebAppForm': () => import('../areas/web-applications/web-app-editor.page').then((m) => m.WebAppEditorPage),
  'OcuPilot.Screen.Descriptor.RoleForm': () => import('../areas/permissions/role-editor.page').then((m) => m.RoleEditorPage),
  'OcuPilot.Screen.Descriptor.TaskForm': () => import('../areas/tasks/task-editor.page').then((m) => m.TaskEditorPage),
  // Story 16.13's service editor serves its bare route (one sentence back to the list) and its id
  // route from the one page, and Story 16.14's LDAP editor its create and its edit.
  'OcuPilot.Screen.Descriptor.ServiceForm': SERVICE_EDITOR_PAGE,
  'OcuPilot.Screen.Descriptor.LdapConfigForm': LDAP_EDITOR_PAGE,
  // Story 18.3: the local database form's id route is the properties editor beside the wizard.
  'OcuPilot.Screen.Descriptor.LocalDatabaseForm': () => import('../areas/os-management/database-editor.page').then((m) => m.DatabaseEditorPage),
};

/**
 * The guard `page` applies before indexing either map -- exported as a pure function so it can be
 * pinned directly against fixture maps, without routing a corrupted archetype through the
 * generated screen mirror (`screens.generated.ts`), which the test suite must not edit.
 *
 * Story 1.15 closed the archetype vocabulary (`OcuPilot.Screen.Archetype`, mirrored as
 * `ArchetypeKey`), so a declared archetype is now one of a known set. That does not make a bare
 * index (`pages[archetype] ?? null`) safe: `ARCHETYPE_PAGES` is a partial map over that set, and
 * a bare index resolves `constructor`, `toString`, or any other inherited `Object.prototype`
 * member to that member's function -- which is not `null` or `undefined`, so it survives the
 * `??` fallback and reaches the router as a loader that is not one. The parameter stays `string`
 * for the same reason the function is exported: it is pinned against a fixture map, with values
 * the closed vocabulary does not contain. `Object.hasOwn` accepts only a key the map declares --
 * and a descriptor class name is caller-supplied data too, so it passes the same guard.
 */
export function resolveArchetypePage<T>(pages: Readonly<Record<string, T>>, archetype: string): T | null {
  return Object.hasOwn(pages, archetype) ? pages[archetype] : null;
}

/**
 * The page for one screen: its descriptor's own, where it declares one, and its archetype's
 * otherwise (DW-369). Both lookups go through `resolveArchetypePage`'s guard.
 */
export function resolveScreenPage<T>(
  descriptorPages: Readonly<Record<string, T>>,
  archetypePages: Readonly<Record<string, T>>,
  descriptor: string,
  archetype: string
): T | null {
  return (
    resolveArchetypePage(descriptorPages, descriptor) ??
    resolveArchetypePage(archetypePages, archetype)
  );
}

/**
 * The routed target for every route in the table, and Story 1.5's `app-deep-link` grown up.
 *
 * It does three things and no more, because the screens themselves are their slices':
 *
 * 1. **Resolves the route to a descriptor** through the mirror, and tells `ShellState` which
 *    area is active, which is what puts `aria-current="page"` on a rail item and fills the side
 *    bar on a cold deep link.
 * 2. **Decides whether the screen's page mounts** when the navigation map allows it, shows the
 *    refusal when it denies it (EXPERIENCE.md "Deep link to a gated route"), and the not-found
 *    screen when the URL names no declared screen at all. The page itself is the route's child,
 *    loaded on demand by the loader `app.routes.ts` takes from the maps above and placed in this
 *    component's `<router-outlet />`; a page that is not mounted issues no read, though its code
 *    may already have downloaded. A built screen's archetype always has a page, because
 *    `ARCHETYPE_PAGES` requires one.
 * 3. **Decodes the entity id exactly once.** The id arrives from the router already decoded
 *    once -- Angular's `DefaultUrlSerializer` percent-decodes each segment as it parses the URL
 *    -- so one `decodeEntityId` here completes AD-13's encode-twice, decode-once contract.
 *    Story 1.10's locator bar decodes the same route parameter for its own entity segment;
 *    "decode once" is per value, and neither call is ever chained onto the other's result.
 *
 * The resolved selection is exposed as data attributes, as the placeholder it replaces did, so
 * a browser check can read what the client resolved from a pasted or reloaded URL without
 * reaching into component internals.
 *
 * **The host reads `aria-busy="true"` from the moment the router creates it until its routed page
 * has rendered once**, or until the first pass decides no page mounts. The router activates this
 * component before its template exists and the page after it, so the outlet is on screen, empty,
 * for the turn between; a reader that waits on `[aria-busy="true"]` (the structural walk's
 * `settle`, assistive technology) holds through that turn. The attribute is static on the host so
 * that it is there at creation, before any binding has run.
 *
 * **The not-found sentence is the command box's own**, "No screen or action matches." -- the
 * Fixed strings table has no not-found row, and this is the table's own sentence for "what you
 * named is not a screen or an action", resolved to a URL rather than to a query. A not-found
 * sentence of its own would be new product copy, which is the owner's call.
 *
 * Every control-flow condition is a paren-free member reference, for the reason `sign-in.ts`
 * records: `ui/tools/client-lint.mjs`'s blanker matches `@if` plus one parenthesised group.
 */
@Component({
  selector: 'app-screen-outlet',
  changeDetection: ChangeDetectionStrategy.OnPush,
  host: { 'aria-busy': 'true', '[attr.aria-busy]': 'busyValue' },
  imports: [RouterOutlet, ScreenDenied],
  template: `<div
    class="ocu-screen-outlet"
    [attr.data-area]="area()"
    [attr.data-screen]="screenRoute()"
    [attr.data-archetype]="archetype()"
    [attr.data-id]="entityId()"
    [attr.data-ns]="namespace()"
  >
    @if (notFound) {
      <section class="ocu-screen-denied" role="alert">
        <p class="ocu-screen-denied-reason">{{ STRINGS.commandBoxNoMatch }}</p>
      </section>
    }
    @if (denied) {
      <app-screen-denied [title]="title()" [failedPair]="failedPair()" />
    }
    @if (page) {
      <router-outlet (activate)="onPageActivated()" />
    }
  </div>`,
})
export class ScreenOutlet {
  private readonly route = inject(ActivatedRoute);
  private readonly navigation = inject(NavigationService);
  private readonly shell = inject(ShellState);
  private readonly injector = inject(Injector);

  protected readonly STRINGS = STRINGS;

  private readonly segments = toSignal(this.route.url, { initialValue: this.route.snapshot.url });

  private readonly params = toSignal(this.route.paramMap, {
    initialValue: this.route.snapshot.paramMap,
  });

  private readonly query = toSignal(this.route.queryParamMap, {
    initialValue: this.route.snapshot.queryParamMap,
  });

  /** Mirrors the framework-free navigation map into the reactive graph. */
  private readonly mapGeneration = signal(0);

  /** The same mirror for the shell's own state, which is where the screen hold lives. */
  private readonly shellGeneration = signal(0);

  /** Whether the page the router outlet last activated has rendered. */
  private readonly pageRendered = signal(false);

  /** Whether this route has a page to activate: a route table entry with no child never does. */
  private readonly pageRouted = (this.route.routeConfig?.children?.length ?? 0) > 0;

  private readonly screen = computed(() =>
    screenForUrl('/' + this.segments().map((segment) => segment.path).join('/'))
  );

  protected readonly area = computed(() => this.screen()?.area ?? '');

  protected readonly screenRoute = computed(() => this.screen()?.route ?? '');

  protected readonly archetype = computed(() => this.screen()?.archetype ?? '');

  protected readonly title = computed(() => stringFor(this.screen()?.labelKey ?? ''));

  protected readonly entityId = computed(() => {
    const raw = this.params().get('id');
    return raw === null ? '' : decodeEntityId(raw);
  });

  protected readonly namespace = computed(() => this.query().get('ns') ?? '');

  protected readonly failedPair = computed(() => {
    this.mapGeneration();
    const screen = this.screen();
    return screen === null ? '' : this.navigation.screenVerdict(screen.route).failedPair;
  });

  private readonly allowed = computed(() => {
    this.mapGeneration();
    const screen = this.screen();
    return screen === null ? true : this.navigation.screenVerdict(screen.route).allowed;
  });

  constructor() {
    const stop = this.navigation.subscribe(() =>
      this.mapGeneration.set(this.mapGeneration() + 1)
    );
    inject(DestroyRef).onDestroy(stop);

    const stopShell = this.shell.subscribe(() =>
      this.shellGeneration.set(this.shellGeneration() + 1)
    );
    inject(DestroyRef).onDestroy(stopShell);

    // The area the route belongs to is shell state, not screen state: it drives the rail's
    // `aria-current` and fills the side bar on a cold deep link. Set from an effect-free read
    // of the same computed the template uses, whenever the route changes.
    const stopRoute = this.route.url.subscribe(() => this.shell.setActiveArea(this.area()));
    inject(DestroyRef).onDestroy(() => stopRoute.unsubscribe());
  }

  protected get notFound(): boolean {
    return this.screen() === null;
  }

  /** `'true'` while a page that should mount has not rendered yet, else `null`, which drops the attribute. */
  protected get busyValue(): 'true' | null {
    return this.pageRouted && this.page && !this.pageRendered() ? 'true' : null;
  }

  /**
   * The router outlet created the page. The flag follows the render after this one, so a page's own
   * first render still finds this outlet busy.
   */
  protected onPageActivated(): void {
    if (this.pageRendered()) this.pageRendered.set(false);
    afterNextRender(() => this.pageRendered.set(true), { injector: this.injector });
  }

  protected get denied(): boolean {
    return this.screen() !== null && !this.allowed();
  }

  /**
   * Whether the routed page mounts: `false` for a denied screen, an unknown URL, and any screen
   * before the navigation map has answered, so a page the map then refuses never mounts and never
   * reads.
   *
   * `screenHeld()` is the same rule asked of the other decision that can move this browser: while
   * the first-login gate is still deciding (FR-28), no page mounts, so the screen the gate is
   * about to leave issues no read. This component still resolves the route and still tells
   * `ShellState` which area it belongs to, because the requested route is the route until the
   * gate actually moves off it.
   */
  protected get page(): boolean {
    this.mapGeneration();
    this.shellGeneration();
    if (this.screen() === null || this.shell.screenHeld()) return false;
    return this.navigation.answered() && this.allowed();
  }
}
