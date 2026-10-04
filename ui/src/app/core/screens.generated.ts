/*
 * GENERATED FILE -- DO NOT EDIT.
 *
 * The client mirror of OcuPilot's screen descriptors and area vocabulary (AD-5). Every value
 * here is derived from the XData declarations in src/OcuPilot/Screen/ by
 * ui/tools/screen-mirror.mjs; edit the descriptor and regenerate.
 *
 * Regenerate: node tools/screen-mirror.mjs
 * Drift check: ui/tools/screen-mirror.test.mjs, which fails when this file and the
 * declarations disagree.
 */

export type EntityTypeKey = 'web-application' | 'rest-service' | 'user' | 'role' | 'resource' | 'service' | 'ssl-configuration' | 'x509-credential' | 'ldap-configuration' | 'wallet-collection' | 'wallet-secret' | 'oauth2-client-configuration' | 'oauth2-server-definition' | 'oauth2-resource-server' | 'oauth2-server' | 'oauth2-server-client' | 'audit-event' | 'audit-user-event' | 'auditing-configuration' | 'task' | 'task-history-entry' | 'process' | 'lock' | 'database' | 'device' | 'audit-record' | 'application-error' | 'log-entry' | 'agent-definition' | 'agent-switch' | 'agent-policy' | 'allowed-directory' | 'namespace' | 'web-session' | 'background-task' | 'global-mapping' | 'routine-mapping' | 'package-mapping' | 'database-configuration' | 'language-server' | 'class' | 'routine' | 'journal-file' | 'journal-file-database' | 'journal-settings' | 'journal-record' | 'license-key' | 'license-server' | 'ecp-data-server' | 'ecp-settings' | 'ecp-ssl-connection' | 'encryption-key-file';

/**
 * The closed archetype vocabulary, mirrored from OcuPilot.Screen.Archetype. A screen's
 * archetype decides whether it may link out to the classic portal (AD-44); the classification
 * itself is the build check's and the registry's, not the client's.
 */
export type ArchetypeKey =
  | 'list'
  | 'list (two views)'
  | 'list (server criteria)'
  | 'log-viewer'
  | 'drill-down'
  | 'detail'
  | 'form-page'
  | 'form-page (tabs)'
  | 'wizard'
  | 'meters'
  | 'viewer (OpenAPI)'
  | 'viewer (source)'
  | 'dialog'
  | 'home'
  | 'panel'
  | 'shell'
  | 'external';

/**
 * The archetypes of every built screen, in vocabulary order. The client's archetype-to-page map
 * requires a page for each of these, so a built screen whose archetype has none fails the type
 * check (AD-5).
 */
export type BuiltArchetypeKey =
  | 'list'
  | 'list (two views)'
  | 'list (server criteria)'
  | 'log-viewer'
  | 'drill-down'
  | 'detail'
  | 'form-page'
  | 'meters'
  | 'viewer (OpenAPI)'
  | 'viewer (source)'
  | 'home';

export interface PrivilegePair {
  readonly resource: string;
  readonly permission: string;
}

export interface AreaDeclaration {
  readonly key: string;
  readonly railPosition: number;
  readonly labelKey: string;
  readonly navigates: boolean;
  readonly pinBottom: boolean;
  /**
   * Empty for an area that never gates. Otherwise the area opens when any screen it lists, or any tab
   * of a tab group it lists, is allowed, and when none is it names the first of these the caller
   * lacks, or a listed screen's failed pair when the caller lacks none (AD-8).
   */
  readonly privileges: readonly PrivilegePair[];
}

export interface IdAccessor {
  readonly kind: 'none' | 'single' | 'composite';
  readonly parts: readonly string[];
}

export interface ContextDeclaration {
  readonly fields: readonly string[];
  readonly secretFields: readonly string[];
  /** Per-field length overrides (Story 4.4, AD-24), each a whole number from 1 to 1,000. Absent
   * for a screen that declares none. */
  readonly maxLength?: Readonly<Record<string, number>>;
}

export interface ActionDeclaration {
  readonly id: string;
  readonly selfProtection: string;
}

export interface ClassicLinkExemption {
  readonly exempt: boolean;
  readonly reason: string;
  /** The classic page's own name, which labels the card's action. `''` unless `exempt`. */
  readonly label: string;
  /**
   * Where the card's action goes: a root-relative, same-origin path (AD-47), declared and
   * never derived from `classicPage`, which is a class name (AD-44). `''` unless `exempt`.
   */
  readonly href: string;
  /**
   * The row link a complete exemption may declare (AD-44, AD-47): each row's name cell opens `href`
   * with these params appended from that row, in a new tab. Absent on a screen that links no row.
   */
  readonly rowLink?: ClassicRowLink | null;
}

/** One query parameter a row link appends: its name and the read field whose text it carries. */
export interface ClassicRowLinkParam {
  readonly name: string;
  readonly field: string;
}

/** A row link: the params appended, in order, to the exemption's `href` for one row. */
export interface ClassicRowLink {
  readonly params: readonly ClassicRowLinkParam[];
}

/** A field a detail call derives on the instance from one of its detail fields (AD-36). */
export interface ReadDerived {
  readonly field: string;
  readonly rule: 'beforeToday' | 'bit64';
  readonly from: string;
}

/**
 * The one per-row detail call a read may name (AD-36): the endpoint's declared detail type, issued
 * on the instance for each row that survives the cap with `param` set to the row's `key`,
 * merging `fields` and setting `derived`.
 */
export interface ReadRowGet {
  readonly key: string;
  readonly param: string;
  /** The detail type issued per row; absent means `GET`. */
  readonly type?: 'GET' | 'INFO' | 'CERTINFO' | 'ACTIVITY';
  readonly fields: readonly string[];
  readonly derived: readonly ReadDerived[];
}

/**
 * One `{type, as}` part a single-object `GET` may declare (AD-36, Story 6.9): `type` is the
 * vendor's own upper-case request type, possibly one the endpoint names without its usual `TYPE`
 * prefix, and `as` is the object key its answer is merged under.
 */
export interface ReadSourcePart {
  readonly type: string;
  readonly as: string;
  /** `monitor` for the one part the sensors answer (Story 16.7); absent is the admin endpoint. */
  readonly port?: 'admin' | 'monitor';
}

/**
 * Where a read's rows come from (AD-36): one admin API LIST (AD-2) with an optional per-row detail
 * call, one of OcuPilot's own kernel stores read whole (AD-9), the management API's port, one
 * instance log file's bounded tail, the instance's allowed directories, or an area's listed screens'
 * reads composed into one timeline. A `state` source names the store by its own name, declares no
 * `rowGet` and no `criteria`, and is bounded by the same row cap; a `mgmnt` or `logsource`
 * source declares no `rowGet`, a `path` source is a `LIST` of one of its port's sources, and a
 * `timeline` source's fields and criterion are fixed.
 */
export interface ReadSource {
  readonly port: 'admin' | 'state' | 'mgmnt' | 'logsource' | 'path' | 'timeline' | 'background' | 'atelier' | 'encryption';
  readonly endpoint: string;
  /**
   * `LIST` reads rows; `GET` reads one object as the one row, and a 404 reads as none;
   * `UPCOMING` reads an admin endpoint's scheduled occurrences as rows; `HISTORY` reads its task-run history;
   * `VOLUMELIST` reads a database's own volume files as rows; a bare admin type is read with
   * `rows` (Story 16.7).
   */
  readonly type: 'LIST' | 'GET' | 'UPCOMING' | 'HISTORY' | 'VOLUMELIST' | 'ACTIVITY' | 'LICENSEUSAGE';
  /** The one member of a bare admin type's one-object answer this read lists (AD-36, Story 16.7). */
  readonly rows?: string | null;
  readonly rowGet?: ReadRowGet | null;
  /** The parent list a per-parent read issues its source once per parent for, bounded by the cap. */
  readonly forEach?: ReadForEach | null;
  /**
   * Up to three `{type, as}` parts a single-object `GET` merges into the read's one row as
   * `<as>.<member>` fields (AD-36, Story 6.9).
   */
  readonly parts?: readonly ReadSourcePart[] | null;
  /** Query parameters sent on the read's own list, UPCOMING, HISTORY or GET call and each per-parent child list (never a parent list or a rowGet call), which no caller can change or remove. */
  readonly query?: Readonly<Record<string, string>> | null;
}

/** One parent field a per-parent read copies into each of that parent's rows. */
export interface ReadForEachField {
  readonly field: string;
  readonly from: string;
}

/**
 * A per-parent read (AD-36): `endpoint` is listed first, bounded by the cap plus one, and the read's
 * own source is listed once per parent with `param` set to that parent's `key`, each row taking
 * `fields` from its parent.
 */
export interface ReadForEach {
  readonly endpoint: string;
  readonly key: string;
  readonly param: string;
  readonly fields: readonly ReadForEachField[];
}

/** The fields a read sorts on, its default sort field and direction. */
export interface ReadSort {
  readonly fields: readonly string[];
  readonly default: string;
  readonly direction: 'asc' | 'desc';
}

/** How a declared server-search criterion is entered (AD-21). */
export type CriterionKind = 'text' | 'datetime' | 'choice';

/**
 * One server-search criterion: the query parameter the read sends it as, the string key its
 * control is labelled with, and how it is entered. A `choice` criterion carries the closed
 * `options` its value is validated against on the instance before the port is called - the read
 * executor refuses anything outside them, so an unrecognized value can never widen the search.
 */
export interface ReadCriterion {
  readonly param: string;
  readonly labelKey: string;
  readonly kind: CriterionKind;
  /**
   * The longest value the criterion's own vendor property accepts, declared on every criterion
   * whatever its kind (DW-279). A longer value is refused 400 `READ.CRITERION` naming the
   * parameter and this bound, before any port is called -- where an unbounded one faulted inside
   * the port and named nothing.
   */
  readonly maxLength: number;
  /**
   * The query parameter name the value is sent to the vendor under, instead of `param`, where the
   * vendor's own name is reserved for the read's own arguments (Story 6.6). Absent means the value
   * is sent as `param` itself; the caller, the refusal text and the read tool's schema all keep
   * using `param` regardless.
   */
  readonly vendorParam?: string;
  /**
   * The hours before the instance's own now a caller that omits this `datetime` criterion is
   * searched from (AD-36). An explicit empty value leaves the bound unset instead. The default is
   * computed on the instance, never in the browser.
   */
  readonly defaultHoursAgo?: number;
  /**
   * The read field this `datetime` criterion is compared against on the instance rather than sent
   * to the vendor (AD-36): earlier rows are dropped before truncation is judged.
   */
  readonly atOrAfterField?: string;
  /**
   * The value a caller that omits this `text` or `choice` criterion is read with (AD-36 as
   * amended, Story 19.1); a choice's is one of its `options`. An explicit empty value leaves the
   * criterion unset instead. The form opens on it.
   */
  readonly default?: string;
  readonly options?: readonly string[];
  /**
   * The one sentence the read tool publishes as this criterion's description in place of its kind's
   * generic one (AD-36 as amended, Story 18.19). The screen never shows it.
   */
  readonly hint?: string;
}

/**
 * The agent-marker affordance: one declared criterion set to one declared value (AD-15, AD-46).
 *
 * It **overrides** the criterion `param` names rather than merging with it. Both name the same
 * query parameter and the vendor treats a comma list as membership, so appending would widen the
 * result instead of narrowing it.
 */
export interface ReadCriteriaMarker {
  readonly param: string;
  readonly value: string;
  readonly labelKey: string;
}

/**
 * The server-search parameters a declared read carries (AD-21), for the one Release 1 list whose
 * API searches on the server. The roster is the allow-list: the route reads a query parameter only
 * where this names it, and the read tool publishes one property per criterion, so screen and tool
 * send the same search (AD-36).
 */
export interface ReadCriteria {
  readonly fields: readonly ReadCriterion[];
  readonly marker?: ReadCriteriaMarker | null;
}

/** A screen's one declared read (AD-36): the screen's list and its read tool both resolve through it. */
export interface ReadDeclaration {
  readonly source: ReadSource;
  readonly fields: readonly string[];
  readonly filter: readonly string[];
  readonly sort: ReadSort;
  readonly paging: 'cap';
  /** The server-search criteria this read carries, absent for a read bounded by the cap alone. */
  readonly criteria?: ReadCriteria | null;
  /** One sentence about the rows, shown above the table and ending the read tool's description. */
  readonly note?: { readonly key: string; readonly text: string } | null;
}

/** Where a banner's value comes from: one admin API GET (AD-2). */
export interface BannerSource {
  readonly port: 'admin';
  readonly endpoint: string;
  readonly type: 'GET';
}

/** The `.ocu-banner-*` variants a declared banner may take (DESIGN.md `:1203`). */
export type BannerSeverity = 'info' | 'warning' | 'restrained';

/**
 * One value a banner's field may take, and the sentence it raises (DW-270); `action`, where
 * declared, is the id of the screen's row action the strip offers (Story 16.11, AD-5).
 */
export interface BannerCase {
  readonly equals: string;
  readonly messageKey: string;
  readonly severity: BannerSeverity;
  readonly action?: string;
}

/**
 * A screen's declared banner: one port read over one `field`, and the cases that field's value
 * may match -- the first whose `equals` it equals raises that case's `messageKey`.
 *
 * **One read, many cases.** A field with a closed set of values usually has more than one state
 * worth a strip: the Task Manager answers `Running`, `Suspended` and `Not running`, and a
 * single-case banner left the stopped one silent (DW-270). Adding a second banner would have meant
 * a second port call per read, so the cases share one.
 *
 * It is evaluated on the instance inside the screen's own read (`OcuPilot.Screen.Read`) and
 * arrives as that read's `banner` key, so an auto-refresh tick re-evaluates it and the strip is
 * gone the moment the condition clears. A fault in it suppresses the strip and never fails the
 * list.
 */
export interface BannerDeclaration {
  readonly source: BannerSource;
  readonly field: string;
  readonly cases: readonly BannerCase[];
}

/** How a table column renders its field (AD-5). */
export type TableColumnKind = 'name' | 'identifier' | 'text' | 'number' | 'status';

/**
 * One table column: the read field it shows, its header's string key and its kind, and optionally
 * the string key an empty cell in it reads instead of "(none)".
 */
export interface TableColumn {
  readonly field: string;
  readonly labelKey: string;
  readonly kind: TableColumnKind;
  readonly emptyKey?: string;
}

/**
 * The table a read's rows render in: its columns and the string keys of the empty state's second
 * line, of which exactly one is non-empty.
 */
export interface TableDeclaration {
  readonly columns: readonly TableColumn[];
  readonly emptyNextKey: string;
  readonly emptyAgentKey: string;
}

export interface ScreenDeclaration {
  readonly descriptor: string;
  readonly route: string;
  readonly area: string;
  readonly labelKey: string;
  readonly sideBarPosition: number;
  readonly archetype: ArchetypeKey;
  readonly built: boolean;
  /** Whether the shared auto-refresh framework binds this screen (AD-43). */
  readonly refreshes: boolean;
  /** The rates, in whole seconds ascending, the chip may set. Empty unless `refreshes`. */
  readonly refreshRates: readonly number[];
  /** The rate the framework starts at when none is remembered: one of `refreshRates`, or `0`, off. */
  readonly refreshDefault: number;
  readonly privileges: readonly PrivilegePair[];
  /** The pairs of `privileges` it requires beyond its area's set, gating this screen alone (AD-8). */
  readonly ownPrivileges?: readonly PrivilegePair[];
  readonly entityType: string;
  /** The string key of the singular noun for `entityType`, or `''` (AD-5, AD-14). */
  readonly entityLabelKey: string;
  readonly secondaryEntityTypes: readonly string[];
  readonly scope: string;
  readonly parentScope: string;
  readonly id: IdAccessor;
  readonly context: ContextDeclaration;
  /** The top-level argument names this screen's write tools take as secret (AD-3, AD-6). */
  readonly secretArguments: readonly string[];
  /** The payload paths a proposal's fingerprint leaves out (AD-6); the default is everything else. */
  readonly fingerprintExcludes: readonly string[];
  readonly primaryAction: ActionDeclaration;
  readonly rowActions: readonly ActionDeclaration[];
  readonly emptyStateKey: string;
  readonly commandAliases: readonly string[];
  /** The prompts the panel suggests on this screen, grouped by task, where it declares any (Story 11.3). */
  readonly suggestedPrompts?: readonly SuggestedPrompt[];
  readonly classicPage: string;
  readonly classicLinkExemption: ClassicLinkExemption;
  /** The screen's one declared read, or `null` for a screen with none (AD-36). */
  readonly read: ReadDeclaration | null;
  /** The table the read renders in, or `null` exactly when `read` is. */
  readonly table: TableDeclaration | null;
  /** The strip the read's own answer raises above the table, or `null` for a screen with none. */
  readonly banner: BannerDeclaration | null;
  /** The tab group this screen is one tab of, or `null` for a screen that is no tab (AD-5). */
  readonly tab: TabDeclaration | null;
  readonly toolIdentifier: string;
  /** This list's one declared cross-screen row target, or `null` for a screen with none (AD-5, Story 6.10). */
  readonly rowTarget: ScreenRowTarget | null;
  /** This list's one declared multi-select action, or `null` for a screen with none (AD-5, Story 16.6). */
  readonly multiSelect: ScreenMultiSelect | null;
}

/** One suggested prompt: the string key of the task group it sits under, and of its own text. */
export interface SuggestedPrompt {
  readonly groupKey: string;
  readonly textKey: string;
}

/**
 * One tab of a tabbed screen (AD-5): the route of the group's first tab, this tab's position in the
 * strip, and the string key its label reads.
 */
export interface TabDeclaration {
  readonly group: string;
  readonly position: number;
  readonly labelKey: string;
}

/**
 * A list's single declared cross-screen row target (AD-5, Story 6.10): the route its name cell
 * opens and the row field, read with `fieldOf` and encoded with `encodeEntityId`, that route's
 * id is drawn from -- resolved ahead of the paired-surface chain in `shell/data-table.ts`.
 */
export interface ScreenRowTarget {
  readonly route: string;
  readonly field: string;
  /** The read field that withholds a row's link where it reads `true` (Story 16.12, DW-1074). */
  readonly unless?: string;
}

/**
 * A list's one multi-select action (AD-5, Story 16.6): the row action that acts on the checked rows,
 * the read field that makes a row checkable, the most rows it takes, and the string key an
 * ineligible row's checkbox reads.
 */
export interface ScreenMultiSelect {
  readonly action: string;
  /** The read field that makes a row checkable; absent, every row is (Story 19.2). */
  readonly eligible?: string;
  readonly max: number;
  /** The reason an ineligible row's checkbox carries; declared together with `eligible`. */
  readonly ineligibleKey?: string;
  /** Further row actions that act on the checked set (Story 19.2). */
  readonly extraActions?: readonly string[];
}

/** The closed entity-type vocabulary, mirrored from OcuPilot.Kernel.EntityType. */
export const ENTITY_TYPES: readonly EntityTypeKey[] = [
  "web-application",
  "rest-service",
  "user",
  "role",
  "resource",
  "service",
  "ssl-configuration",
  "x509-credential",
  "ldap-configuration",
  "wallet-collection",
  "wallet-secret",
  "oauth2-client-configuration",
  "oauth2-server-definition",
  "oauth2-resource-server",
  "oauth2-server",
  "oauth2-server-client",
  "audit-event",
  "audit-user-event",
  "auditing-configuration",
  "task",
  "task-history-entry",
  "process",
  "lock",
  "database",
  "device",
  "audit-record",
  "application-error",
  "log-entry",
  "agent-definition",
  "agent-switch",
  "agent-policy",
  "allowed-directory",
  "namespace",
  "web-session",
  "background-task",
  "global-mapping",
  "routine-mapping",
  "package-mapping",
  "database-configuration",
  "language-server",
  "class",
  "routine",
  "journal-file",
  "journal-file-database",
  "journal-settings",
  "journal-record",
  "license-key",
  "license-server",
  "ecp-data-server",
  "ecp-settings",
  "ecp-ssl-connection",
  "encryption-key-file"
];

/**
 * The code point joining the three parts of a reference key, mirrored from
 * OcuPilot.Kernel.EntityRef's REFSEPARATOR (AD-13). `entity-ref.ts` builds its separator from
 * this rather than from a literal of its own, so the two key builders cannot join one entity's
 * parts with different characters (DW-1403).
 */
export const ENTITY_REF_SEPARATOR_CODE = 2;

/**
 * The per-entity-type canonical id rules, mirrored from OcuPilot.Kernel.EntityRef's IDRULES
 * table (AD-13). Only the types that declare one appear; every other type canonicalizes to
 * itself. `entity-ref.ts` holds the implementation of each rule name, pinned equal to
 * `screen-mirror.mjs`'s own roster, so a rule the client cannot apply fails the build rather
 * than mirroring as a no-op.
 */
export const ENTITY_ID_RULES: Readonly<Partial<Record<EntityTypeKey, string>>> = {
  "web-application": "foldcase-striptrailingslash",
  "user": "foldcase",
  "auditing-configuration": "singleton",
  "task": "integer",
  "process": "integerset",
  "application-error": "foldcase",
  "role": "foldcase",
  "resource": "foldcase",
  "audit-event": "foldcase",
  "audit-user-event": "foldcase",
  "service": "foldcase",
  "ldap-configuration": "foldcase",
  "oauth2-server": "singleton",
  "namespace": "foldcase",
  "global-mapping": "foldcase-firstpart",
  "routine-mapping": "foldcase-firstpart",
  "package-mapping": "foldcase-firstpart",
  "database-configuration": "foldcase",
  "database": "directoryset",
  "class": "documentset",
  "routine": "documentset",
  "journal-settings": "singleton",
  "license-key": "singleton",
  "license-server": "foldcase",
  "ecp-data-server": "foldcase",
  "ecp-settings": "singleton"
};

/**
 * The one id every `singleton`-ruled entity type's reference carries, mirrored from
 * OcuPilot.Kernel.EntityRef's RULESINGLETONID (AD-13). `entity-ref.ts` builds that rule from this
 * rather than from a literal of its own, for the reason the separator above is mirrored.
 */
export const ENTITY_SINGLETON_ID = "SYSTEM";

/** The eight areas, in rail order. */
export const AREAS: readonly AreaDeclaration[] = [
  {
    "key": "home",
    "railPosition": 1,
    "labelKey": "navAreaHome",
    "navigates": true,
    "pinBottom": false,
    "privileges": []
  },
  {
    "key": "logs",
    "railPosition": 2,
    "labelKey": "navAreaLogs",
    "navigates": false,
    "pinBottom": false,
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ]
  },
  {
    "key": "os-management",
    "railPosition": 3,
    "labelKey": "navAreaOsManagement",
    "navigates": false,
    "pinBottom": false,
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ]
  },
  {
    "key": "tasks",
    "railPosition": 4,
    "labelKey": "navAreaTasks",
    "navigates": false,
    "pinBottom": false,
    "privileges": [
      {
        "resource": "%Admin_Task",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ]
  },
  {
    "key": "permissions",
    "railPosition": 5,
    "labelKey": "navAreaPermissions",
    "navigates": false,
    "pinBottom": false,
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ]
  },
  {
    "key": "web-applications",
    "railPosition": 6,
    "labelKey": "navAreaWebApplications",
    "navigates": false,
    "pinBottom": false,
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ]
  },
  {
    "key": "security",
    "railPosition": 7,
    "labelKey": "navAreaSecurity",
    "navigates": false,
    "pinBottom": false,
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ]
  },
  {
    "key": "system-explorer",
    "railPosition": 8,
    "labelKey": "navAreaSystemExplorer",
    "navigates": false,
    "pinBottom": false,
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ]
  },
  {
    "key": "agent",
    "railPosition": 9,
    "labelKey": "navAreaAgent",
    "navigates": false,
    "pinBottom": true,
    "privileges": []
  }
];

/** Every declared screen, by descriptor class name. */
export const SCREENS: readonly ScreenDeclaration[] = [
  {
    "descriptor": "OcuPilot.Screen.Descriptor.AgentDefinitionForm",
    "route": "agent/definitions/edit",
    "area": "agent",
    "labelKey": "agentDefinitionFormLabel",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "OcuPilotAdmin",
        "permission": "USE"
      }
    ],
    "entityType": "agent-definition",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": [
        "apiKey"
      ]
    },
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupAgentSetup",
        "textKey": "agentDefinitionFormPrompt1"
      },
      {
        "groupKey": "promptGroupAgentSetup",
        "textKey": "agentDefinitionFormPrompt2"
      },
      {
        "groupKey": "promptGroupAgentSetup",
        "textKey": "agentDefinitionFormPrompt3"
      }
    ],
    "classicPage": "",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "agent.definition",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.AgentDefinitionList",
    "route": "agent/definitions",
    "area": "agent",
    "labelKey": "agentDefinitionListLabel",
    "sideBarPosition": 1,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "OcuPilotAdmin",
        "permission": "USE"
      }
    ],
    "entityType": "agent-definition",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "composite",
      "parts": [
        "id"
      ]
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "enable",
        "selfProtection": ""
      },
      {
        "id": "disable",
        "selfProtection": ""
      },
      {
        "id": "set-default",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "id",
        "name",
        "provider",
        "model",
        "enabled",
        "default"
      ],
      "secretFields": []
    },
    "emptyStateKey": "agentDefinitionListEmpty",
    "commandAliases": [
      "agent definitions",
      "definitions",
      "api key"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupAgentSetup",
        "textKey": "agentDefinitionListPrompt1"
      },
      {
        "groupKey": "promptGroupAgentSetup",
        "textKey": "agentDefinitionListPrompt2"
      },
      {
        "groupKey": "promptGroupAgentSetup",
        "textKey": "agentDefinitionListPrompt3"
      }
    ],
    "classicPage": "",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "state",
        "endpoint": "Agent",
        "type": "LIST"
      },
      "fields": [
        "id",
        "name",
        "provider",
        "model",
        "enabled",
        "default"
      ],
      "filter": [
        "name",
        "provider",
        "model"
      ],
      "sort": {
        "fields": [
          "name",
          "provider",
          "model"
        ],
        "default": "name",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "provider",
          "labelKey": "tableColumnProvider",
          "kind": "text"
        },
        {
          "field": "model",
          "labelKey": "tableColumnModel",
          "kind": "text"
        },
        {
          "field": "enabled",
          "labelKey": "tableColumnEnabled",
          "kind": "status"
        },
        {
          "field": "default",
          "labelKey": "tableColumnDefault",
          "kind": "status"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "agentDefinitionListEmptyAgent"
    },
    "toolIdentifier": "agent.definitions",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.AgentGovernance",
    "route": "agent/governance",
    "area": "agent",
    "labelKey": "agentGovernanceLabel",
    "sideBarPosition": 4,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "OcuPilotAdmin",
        "permission": "USE"
      }
    ],
    "entityType": "agent-policy",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "emptyStateKey": "",
    "commandAliases": [
      "governance",
      "tool policy"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupAgentSetup",
        "textKey": "agentGovernancePrompt1"
      },
      {
        "groupKey": "promptGroupAgentSetup",
        "textKey": "agentGovernancePrompt2"
      },
      {
        "groupKey": "promptGroupAgentSetup",
        "textKey": "agentGovernancePrompt3"
      }
    ],
    "classicPage": "",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "agent.governance",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.AgentGuardrails",
    "route": "agent/guardrails",
    "area": "agent",
    "labelKey": "agentGuardrailsLabel",
    "sideBarPosition": 3,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [],
    "entityType": "",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "emptyStateKey": "",
    "commandAliases": [
      "guardrails",
      "prohibited actions",
      "what the agent refuses"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupAgentSetup",
        "textKey": "agentGuardrailsPrompt1"
      },
      {
        "groupKey": "promptGroupAgentSetup",
        "textKey": "agentGuardrailsPrompt2"
      },
      {
        "groupKey": "promptGroupAgentSetup",
        "textKey": "agentGuardrailsPrompt3"
      }
    ],
    "classicPage": "",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "agent.guardrails",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.AgentLedger",
    "route": "agent/ledger",
    "area": "agent",
    "labelKey": "agentLedgerLabel",
    "sideBarPosition": 5,
    "archetype": "list (server criteria)",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [],
    "entityType": "",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "composite",
      "parts": [
        "ledgerId"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "emptyStateKey": "agentLedgerEmpty",
    "commandAliases": [
      "agent audit ledger",
      "ledger",
      "agent activity"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "auditUserEventPromptGroup",
        "textKey": "agentLedgerPrompt1"
      },
      {
        "groupKey": "auditUserEventPromptGroup",
        "textKey": "agentLedgerPrompt2"
      },
      {
        "groupKey": "auditUserEventPromptGroup",
        "textKey": "agentLedgerPrompt3"
      }
    ],
    "classicPage": "",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "agent.ledger",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.AgentSwitches",
    "route": "agent/switches",
    "area": "agent",
    "labelKey": "agentSwitchesLabel",
    "sideBarPosition": 2,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "OcuPilotAdmin",
        "permission": "USE"
      }
    ],
    "entityType": "agent-switch",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "delete",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "emptyStateKey": "",
    "commandAliases": [
      "kill switch",
      "read-only",
      "switches"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupAgentSetup",
        "textKey": "agentSwitchesPrompt1"
      },
      {
        "groupKey": "promptGroupAgentSetup",
        "textKey": "agentSwitchesPrompt2"
      },
      {
        "groupKey": "promptGroupAgentSetup",
        "textKey": "agentSwitchesPrompt3"
      }
    ],
    "classicPage": "",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "agent.switches",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.AgentTranscript",
    "route": "agent/transcripts/details",
    "area": "agent",
    "labelKey": "agentTranscriptLabel",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [],
    "entityType": "",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "agent/transcripts",
    "id": {
      "kind": "composite",
      "parts": [
        "id"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupAgentSetup",
        "textKey": "agentTranscriptsPrompt1"
      },
      {
        "groupKey": "promptGroupAgentSetup",
        "textKey": "agentTranscriptsPrompt2"
      },
      {
        "groupKey": "promptGroupAgentSetup",
        "textKey": "agentTranscriptsPrompt3"
      }
    ],
    "classicPage": "",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "agent.transcript",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.AgentTranscripts",
    "route": "agent/transcripts",
    "area": "agent",
    "labelKey": "agentTranscriptsLabel",
    "sideBarPosition": 6,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [],
    "entityType": "",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "composite",
      "parts": [
        "id"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "id",
        "user",
        "started",
        "lastActivity",
        "turns",
        "title"
      ],
      "secretFields": []
    },
    "emptyStateKey": "agentTranscriptsEmpty",
    "commandAliases": [
      "transcripts",
      "conversation history"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupAgentSetup",
        "textKey": "agentTranscriptsPrompt1"
      },
      {
        "groupKey": "promptGroupAgentSetup",
        "textKey": "agentTranscriptsPrompt2"
      },
      {
        "groupKey": "promptGroupAgentSetup",
        "textKey": "agentTranscriptsPrompt3"
      }
    ],
    "classicPage": "",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "state",
        "endpoint": "Convo",
        "type": "LIST"
      },
      "fields": [
        "id",
        "user",
        "started",
        "lastActivity",
        "turns",
        "title"
      ],
      "filter": [
        "user",
        "started",
        "lastActivity",
        "title"
      ],
      "sort": {
        "fields": [
          "user",
          "started",
          "lastActivity",
          "turns",
          "title"
        ],
        "default": "lastActivity",
        "direction": "desc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "started",
          "labelKey": "taskHistoryColumnStarted",
          "kind": "name"
        },
        {
          "field": "user",
          "labelKey": "processColumnUser",
          "kind": "text"
        },
        {
          "field": "turns",
          "labelKey": "agentTranscriptsColumnTurns",
          "kind": "number"
        },
        {
          "field": "lastActivity",
          "labelKey": "agentTranscriptsColumnLastActivity",
          "kind": "text"
        },
        {
          "field": "title",
          "labelKey": "agentTranscriptsColumnTitle",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "agent.transcripts",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.AllowedDirectoryList",
    "route": "security/allowed-directories",
    "area": "security",
    "labelKey": "allowedDirectoriesLabel",
    "sideBarPosition": 7,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_FileSystemAccess",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_FileSystemAccess",
        "permission": "USE"
      }
    ],
    "entityType": "allowed-directory",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Directory",
        "Restricted"
      ],
      "secretFields": []
    },
    "emptyStateKey": "allowedDirectoriesEmpty",
    "commandAliases": [
      "allow-list",
      "file access"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "allowedDirectoryListPrompt1"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "allowedDirectoryListPrompt2"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "allowedDirectoryListPrompt3"
      }
    ],
    "classicPage": "",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "path",
        "endpoint": "roots",
        "type": "LIST"
      },
      "fields": [
        "Directory",
        "Restricted"
      ],
      "filter": [
        "Directory",
        "Restricted"
      ],
      "sort": {
        "fields": [
          "Directory",
          "Restricted"
        ],
        "default": "Directory",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Directory",
          "labelKey": "lockColumnDirectory",
          "kind": "name"
        },
        {
          "field": "Restricted",
          "labelKey": "allowedDirectoriesColumnRestricted",
          "kind": "status"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "security.alloweddirectories",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.AuditList",
    "route": "logs/audit",
    "area": "logs",
    "labelKey": "auditListLabel",
    "sideBarPosition": 4,
    "archetype": "list (server criteria)",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "audit-record",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "composite",
      "parts": [
        "UTCTimeStamp",
        "SystemID",
        "AuditIndex"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "SystemID",
        "AuditIndex",
        "TimeStamp",
        "EventSource",
        "EventType",
        "Event",
        "Pid",
        "SessionID",
        "Username",
        "Description",
        "UTCTimeStamp",
        "JobNumber",
        "Authentication",
        "ClientExecutableName",
        "ClientIPAddress",
        "Namespace",
        "Roles",
        "RoutineSpec",
        "UserInfo",
        "JobId",
        "Status",
        "OSUsername",
        "StartupClientIPAddress"
      ],
      "secretFields": []
    },
    "emptyStateKey": "auditListEmpty",
    "commandAliases": [
      "audit"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "auditUserEventPromptGroup",
        "textKey": "auditListPrompt1"
      },
      {
        "groupKey": "auditUserEventPromptGroup",
        "textKey": "auditListPrompt2"
      },
      {
        "groupKey": "auditUserEventPromptGroup",
        "textKey": "auditListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Audit.View",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Security.Audit.Record",
        "type": "LIST"
      },
      "fields": [
        "SystemID",
        "AuditIndex",
        "TimeStamp",
        "EventSource",
        "EventType",
        "Event",
        "Pid",
        "SessionID",
        "Username",
        "Description",
        "UTCTimeStamp",
        "JobNumber",
        "Authentication",
        "ClientExecutableName",
        "ClientIPAddress",
        "EventData",
        "Namespace",
        "Roles",
        "RoutineSpec",
        "UserInfo",
        "JobId",
        "Status",
        "OSUsername",
        "StartupClientIPAddress"
      ],
      "filter": [
        "TimeStamp",
        "EventSource",
        "EventType",
        "Event",
        "Username",
        "Pid",
        "Namespace",
        "Description"
      ],
      "sort": {
        "fields": [
          "TimeStamp",
          "EventSource",
          "EventType",
          "Event",
          "Username",
          "Pid",
          "Namespace",
          "Description"
        ],
        "default": "TimeStamp",
        "direction": "desc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "beginDateTime",
            "labelKey": "auditCriteriaBegin",
            "kind": "datetime",
            "maxLength": 50,
            "defaultHoursAgo": 24
          },
          {
            "param": "endDateTime",
            "labelKey": "auditCriteriaEnd",
            "kind": "datetime",
            "maxLength": 50
          },
          {
            "param": "eventSources",
            "labelKey": "auditColumnEventSource",
            "kind": "text",
            "maxLength": 1000
          },
          {
            "param": "eventTypes",
            "labelKey": "auditColumnEventType",
            "kind": "text",
            "maxLength": 1000
          },
          {
            "param": "events",
            "labelKey": "auditColumnEventName",
            "kind": "text",
            "maxLength": 1000
          },
          {
            "param": "usernames",
            "labelKey": "processColumnUser",
            "kind": "text",
            "maxLength": 1000
          },
          {
            "param": "pids",
            "labelKey": "processColumnPid",
            "kind": "text",
            "maxLength": 50
          },
          {
            "param": "namespaces",
            "labelKey": "headerNamespaceLabel",
            "kind": "text",
            "maxLength": 1000
          },
          {
            "param": "authentication",
            "labelKey": "auditCriteriaAuthentication",
            "kind": "choice",
            "maxLength": 50,
            "options": [
              "Kerberos Credentials Cache",
              "Kerberos",
              "K5KeyTab",
              "Operating System",
              "Password",
              "Unauthenticated",
              "Kerberos with Encryption",
              "Kerberos with Packet Integrity",
              "LDAP",
              "Delegated",
              "Mutual TLS"
            ]
          }
        ],
        "marker": {
          "param": "eventSources",
          "value": "OcuPilot",
          "labelKey": "auditMarkerFilterLabel"
        }
      }
    },
    "table": {
      "columns": [
        {
          "field": "TimeStamp",
          "labelKey": "auditColumnTime",
          "kind": "text"
        },
        {
          "field": "EventSource",
          "labelKey": "auditColumnEventSource",
          "kind": "text"
        },
        {
          "field": "EventType",
          "labelKey": "auditColumnEventType",
          "kind": "text"
        },
        {
          "field": "Event",
          "labelKey": "auditColumnEventName",
          "kind": "name"
        },
        {
          "field": "Username",
          "labelKey": "processColumnUser",
          "kind": "text"
        },
        {
          "field": "Pid",
          "labelKey": "processColumnPid",
          "kind": "identifier"
        },
        {
          "field": "Namespace",
          "labelKey": "headerNamespaceLabel",
          "kind": "text"
        },
        {
          "field": "Description",
          "labelKey": "tableColumnDescription",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "logs.audit",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.AuditSystemEventList",
    "route": "security/auditing/system-events",
    "area": "security",
    "labelKey": "auditSystemEventListLabel",
    "sideBarPosition": 0,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "audit-event",
    "entityLabelKey": "auditDialogTitle",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "composite",
      "parts": [
        "EventName"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "enable",
        "selfProtection": ""
      },
      {
        "id": "disable",
        "selfProtection": ""
      },
      {
        "id": "reset",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "EventName",
        "Enabled",
        "Total",
        "Written",
        "Lost"
      ],
      "secretFields": []
    },
    "emptyStateKey": "auditSystemEventListEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "auditUserEventPromptGroup",
        "textKey": "auditSystemEventListPrompt1"
      },
      {
        "groupKey": "auditUserEventPromptGroup",
        "textKey": "auditSystemEventListPrompt2"
      },
      {
        "groupKey": "auditUserEventPromptGroup",
        "textKey": "auditSystemEventListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Audit.SystemEvents",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Security.Audit.Event",
        "type": "LIST",
        "query": {
          "eventOwner": "1"
        }
      },
      "fields": [
        "EventName",
        "Enabled",
        "Total",
        "Written",
        "Lost"
      ],
      "filter": [
        "EventName",
        "Enabled",
        "Total",
        "Written",
        "Lost"
      ],
      "sort": {
        "fields": [
          "EventName",
          "Enabled",
          "Total",
          "Written",
          "Lost"
        ],
        "default": "EventName",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "EventName",
          "labelKey": "auditColumnEventName",
          "kind": "name"
        },
        {
          "field": "Enabled",
          "labelKey": "tableColumnEnabled",
          "kind": "status"
        },
        {
          "field": "Total",
          "labelKey": "auditEventColumnTotal",
          "kind": "number"
        },
        {
          "field": "Written",
          "labelKey": "auditEventColumnWritten",
          "kind": "number"
        },
        {
          "field": "Lost",
          "labelKey": "auditEventColumnLost",
          "kind": "number"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "auditSystemEventListEmptyAgent"
    },
    "toolIdentifier": "security.auditsystemevents",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": []
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.AuditUserEventList",
    "route": "security/auditing/user-events",
    "area": "security",
    "labelKey": "auditUserEventListLabel",
    "sideBarPosition": 0,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "audit-user-event",
    "entityLabelKey": "auditDialogTitle",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "composite",
      "parts": [
        "EventName"
      ]
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "enable",
        "selfProtection": ""
      },
      {
        "id": "disable",
        "selfProtection": ""
      },
      {
        "id": "reset",
        "selfProtection": ""
      },
      {
        "id": "delete",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "EventName",
        "Enabled",
        "Total",
        "Written",
        "Lost"
      ],
      "secretFields": []
    },
    "emptyStateKey": "auditUserEventListEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "auditUserEventPromptGroup",
        "textKey": "auditUserEventPromptEnabled"
      },
      {
        "groupKey": "auditUserEventPromptGroup",
        "textKey": "auditUserEventPromptBusiest"
      },
      {
        "groupKey": "auditUserEventPromptGroup",
        "textKey": "auditUserEventPromptRegister"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Audit.UserEvents",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Security.Audit.Event",
        "type": "LIST",
        "query": {
          "eventOwner": "0"
        }
      },
      "fields": [
        "EventName",
        "Enabled",
        "Total",
        "Written",
        "Lost"
      ],
      "filter": [
        "EventName",
        "Enabled",
        "Total",
        "Written",
        "Lost"
      ],
      "sort": {
        "fields": [
          "EventName",
          "Enabled",
          "Total",
          "Written",
          "Lost"
        ],
        "default": "EventName",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "EventName",
          "labelKey": "auditColumnEventName",
          "kind": "name"
        },
        {
          "field": "Enabled",
          "labelKey": "tableColumnEnabled",
          "kind": "status"
        },
        {
          "field": "Total",
          "labelKey": "auditEventColumnTotal",
          "kind": "number"
        },
        {
          "field": "Written",
          "labelKey": "auditEventColumnWritten",
          "kind": "number"
        },
        {
          "field": "Lost",
          "labelKey": "auditEventColumnLost",
          "kind": "number"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "auditUserEventListEmptyAgent"
    },
    "toolIdentifier": "security.audituserevents",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": []
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.AuditingConfig",
    "route": "security/auditing",
    "area": "security",
    "labelKey": "auditingConfigurationLink",
    "sideBarPosition": 6,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "auditing-configuration",
    "entityLabelKey": "auditingConfigurationLink",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "enable",
        "selfProtection": ""
      },
      {
        "id": "disable",
        "selfProtection": ""
      },
      {
        "id": "copy",
        "selfProtection": ""
      },
      {
        "id": "purge",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Enabled"
      ],
      "secretFields": []
    },
    "emptyStateKey": "",
    "commandAliases": [
      "auditing"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "auditUserEventPromptGroup",
        "textKey": "auditingConfigPrompt1"
      },
      {
        "groupKey": "auditUserEventPromptGroup",
        "textKey": "auditingConfigPrompt2"
      },
      {
        "groupKey": "auditUserEventPromptGroup",
        "textKey": "auditingConfigPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Audit.SystemEvents",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Security.Audit.Enabled",
        "type": "GET"
      },
      "fields": [
        "Enabled"
      ],
      "filter": [
        "Enabled"
      ],
      "sort": {
        "fields": [
          "Enabled"
        ],
        "default": "Enabled",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "toolIdentifier": "security.auditing",
    "refreshDefault": 0,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": []
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.BackgroundTaskList",
    "route": "tasks/background",
    "area": "tasks",
    "labelKey": "backgroundTaskListLabel",
    "sideBarPosition": 5,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      }
    ],
    "entityType": "background-task",
    "entityLabelKey": "proposalEntityBackgroundTask",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "composite",
      "parts": [
        "Source",
        "Id"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "cancel",
        "selfProtection": ""
      },
      {
        "id": "pause",
        "selfProtection": ""
      },
      {
        "id": "resume",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Source",
        "Id",
        "Task",
        "Namespace",
        "Status",
        "Details",
        "ErrorCount",
        "StartTime",
        "Database"
      ],
      "secretFields": []
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "backgroundTaskListEmpty",
    "commandAliases": [
      "background tasks",
      "background jobs"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "backgroundTaskListPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "backgroundTaskListPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "backgroundTaskListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.BackgroundTaskList",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "background",
        "endpoint": "BackgroundTask",
        "type": "LIST"
      },
      "fields": [
        "Source",
        "Id",
        "Task",
        "Namespace",
        "Status",
        "Details",
        "ErrorCount",
        "StartTime",
        "Database"
      ],
      "filter": [
        "Source",
        "Task",
        "Namespace",
        "Status",
        "Details"
      ],
      "sort": {
        "fields": [
          "StartTime",
          "Task",
          "Source",
          "Namespace",
          "Status"
        ],
        "default": "StartTime",
        "direction": "desc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Task",
          "labelKey": "proposalEntityTask",
          "kind": "name"
        },
        {
          "field": "Source",
          "labelKey": "auditEventFieldSource",
          "kind": "text"
        },
        {
          "field": "Status",
          "labelKey": "taskHistoryColumnStatus",
          "kind": "status"
        },
        {
          "field": "Namespace",
          "labelKey": "headerNamespaceLabel",
          "kind": "text"
        },
        {
          "field": "Details",
          "labelKey": "backgroundTaskColumnDetails",
          "kind": "text"
        },
        {
          "field": "ErrorCount",
          "labelKey": "backgroundTaskColumnErrorCount",
          "kind": "text"
        },
        {
          "field": "StartTime",
          "labelKey": "taskStartTime",
          "kind": "text"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "backgroundTaskListEmptyAgent"
    },
    "toolIdentifier": "tasks.background",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.Dashboard",
    "route": "os-management/dashboard",
    "area": "os-management",
    "labelKey": "dashboardLabel",
    "sideBarPosition": 9,
    "archetype": "meters",
    "built": true,
    "refreshes": true,
    "refreshRates": [
      5,
      10,
      30,
      60
    ],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Sensors.cpuUsage",
        "Dashboard.Performance.GlobalRefsPerSecond",
        "Dashboard.Performance.GlobalRefs",
        "Dashboard.Performance.GlobalSetKill",
        "Dashboard.Performance.RoutineRefs",
        "Dashboard.Performance.LogicalRequests",
        "Dashboard.Performance.DiskReads",
        "Dashboard.Performance.DiskWrites",
        "Dashboard.Performance.CacheEfficiency",
        "Dashboard.ECP.ECPClients",
        "Dashboard.ECP.ECPClientTraffic",
        "Dashboard.ECP.ECPServers",
        "Dashboard.ECP.ECPServerTraffic",
        "Dashboard.ECP.ShadowConnections",
        "Dashboard.ECP.Shadows",
        "Dashboard.Status.UpTime",
        "Dashboard.Status.LastBackup",
        "Dashboard.SystemUsage.DatabaseSpace",
        "Dashboard.SystemUsage.DatabaseJournal",
        "Dashboard.SystemUsage.JournalSpace",
        "Dashboard.SystemUsage.JournalEntries",
        "Dashboard.SystemUsage.LockTable",
        "Dashboard.SystemUsage.WriteDaemon",
        "Dashboard.SystemUsage.Processes",
        "Dashboard.SystemUsage.CSPSessions",
        "Dashboard.Alerts.SeriousAlerts",
        "Dashboard.Alerts.ApplicationErrors",
        "Dashboard.Licensing.LicenseLimit",
        "Dashboard.Licensing.LicenseUse",
        "Dashboard.Licensing.LicenseUseHigh"
      ],
      "secretFields": []
    },
    "emptyStateKey": "dashboardEmpty",
    "commandAliases": [
      "dashboard",
      "system dashboard",
      "cpu"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "dashboardPrompt1"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "dashboardPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "dashboardPrompt3"
      }
    ],
    "classicPage": "%cspapp.op.utildashboard",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Monitor",
        "type": "GET",
        "parts": [
          {
            "type": "DASHBOARDMAIN",
            "as": "Dashboard"
          },
          {
            "port": "monitor",
            "type": "SENSORS",
            "as": "Sensors"
          }
        ]
      },
      "fields": [
        "Sensors.cpuUsage",
        "Dashboard.Performance.GlobalRefsPerSecond",
        "Dashboard.Performance.GlobalRefs",
        "Dashboard.Performance.GlobalSetKill",
        "Dashboard.Performance.RoutineRefs",
        "Dashboard.Performance.LogicalRequests",
        "Dashboard.Performance.DiskReads",
        "Dashboard.Performance.DiskWrites",
        "Dashboard.Performance.CacheEfficiency",
        "Dashboard.ECP.ECPClients",
        "Dashboard.ECP.ECPClientTraffic",
        "Dashboard.ECP.ECPServers",
        "Dashboard.ECP.ECPServerTraffic",
        "Dashboard.ECP.ShadowConnections",
        "Dashboard.ECP.Shadows",
        "Dashboard.Status.UpTime",
        "Dashboard.Status.LastBackup",
        "Dashboard.SystemUsage.DatabaseSpace",
        "Dashboard.SystemUsage.DatabaseJournal",
        "Dashboard.SystemUsage.JournalSpace",
        "Dashboard.SystemUsage.JournalEntries",
        "Dashboard.SystemUsage.LockTable",
        "Dashboard.SystemUsage.WriteDaemon",
        "Dashboard.SystemUsage.Processes",
        "Dashboard.SystemUsage.CSPSessions",
        "Dashboard.Alerts.SeriousAlerts",
        "Dashboard.Alerts.ApplicationErrors",
        "Dashboard.Licensing.LicenseLimit",
        "Dashboard.Licensing.LicenseUse",
        "Dashboard.Licensing.LicenseUseHigh"
      ],
      "filter": [
        "Sensors.cpuUsage",
        "Dashboard.Performance.GlobalRefsPerSecond",
        "Dashboard.Performance.GlobalRefs",
        "Dashboard.Performance.GlobalSetKill",
        "Dashboard.Performance.RoutineRefs",
        "Dashboard.Performance.LogicalRequests",
        "Dashboard.Performance.DiskReads",
        "Dashboard.Performance.DiskWrites",
        "Dashboard.Performance.CacheEfficiency",
        "Dashboard.ECP.ECPClients",
        "Dashboard.ECP.ECPClientTraffic",
        "Dashboard.ECP.ECPServers",
        "Dashboard.ECP.ECPServerTraffic",
        "Dashboard.ECP.ShadowConnections",
        "Dashboard.ECP.Shadows",
        "Dashboard.Status.UpTime",
        "Dashboard.Status.LastBackup",
        "Dashboard.SystemUsage.DatabaseSpace",
        "Dashboard.SystemUsage.DatabaseJournal",
        "Dashboard.SystemUsage.JournalSpace",
        "Dashboard.SystemUsage.JournalEntries",
        "Dashboard.SystemUsage.LockTable",
        "Dashboard.SystemUsage.WriteDaemon",
        "Dashboard.SystemUsage.Processes",
        "Dashboard.SystemUsage.CSPSessions",
        "Dashboard.Alerts.SeriousAlerts",
        "Dashboard.Alerts.ApplicationErrors",
        "Dashboard.Licensing.LicenseLimit",
        "Dashboard.Licensing.LicenseUse",
        "Dashboard.Licensing.LicenseUseHigh"
      ],
      "sort": {
        "fields": [
          "Sensors.cpuUsage",
          "Dashboard.Performance.GlobalRefsPerSecond",
          "Dashboard.Performance.GlobalRefs",
          "Dashboard.Performance.GlobalSetKill",
          "Dashboard.Performance.RoutineRefs",
          "Dashboard.Performance.LogicalRequests",
          "Dashboard.Performance.DiskReads",
          "Dashboard.Performance.DiskWrites",
          "Dashboard.Performance.CacheEfficiency",
          "Dashboard.ECP.ECPClients",
          "Dashboard.ECP.ECPClientTraffic",
          "Dashboard.ECP.ECPServers",
          "Dashboard.ECP.ECPServerTraffic",
          "Dashboard.ECP.ShadowConnections",
          "Dashboard.ECP.Shadows",
          "Dashboard.Status.UpTime",
          "Dashboard.Status.LastBackup",
          "Dashboard.SystemUsage.DatabaseSpace",
          "Dashboard.SystemUsage.DatabaseJournal",
          "Dashboard.SystemUsage.JournalSpace",
          "Dashboard.SystemUsage.JournalEntries",
          "Dashboard.SystemUsage.LockTable",
          "Dashboard.SystemUsage.WriteDaemon",
          "Dashboard.SystemUsage.Processes",
          "Dashboard.SystemUsage.CSPSessions",
          "Dashboard.Alerts.SeriousAlerts",
          "Dashboard.Alerts.ApplicationErrors",
          "Dashboard.Licensing.LicenseLimit",
          "Dashboard.Licensing.LicenseUse",
          "Dashboard.Licensing.LicenseUseHigh"
        ],
        "default": "Dashboard.Status.UpTime",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Sensors.cpuUsage",
          "labelKey": "dashboardCpu",
          "kind": "number"
        },
        {
          "field": "Dashboard.Performance.GlobalRefsPerSecond",
          "labelKey": "systemUsageGlobalRefsPerSecond",
          "kind": "number"
        },
        {
          "field": "Dashboard.Performance.GlobalRefs",
          "labelKey": "processDetailsGlobalReferences",
          "kind": "number"
        },
        {
          "field": "Dashboard.Performance.GlobalSetKill",
          "labelKey": "systemUsageGlobalUpdates",
          "kind": "number"
        },
        {
          "field": "Dashboard.Performance.RoutineRefs",
          "labelKey": "dashboardRoutineReferences",
          "kind": "number"
        },
        {
          "field": "Dashboard.Performance.LogicalRequests",
          "labelKey": "systemUsageLogicalBlockRequests",
          "kind": "number"
        },
        {
          "field": "Dashboard.Performance.DiskReads",
          "labelKey": "performanceDiskReads",
          "kind": "number"
        },
        {
          "field": "Dashboard.Performance.DiskWrites",
          "labelKey": "performanceDiskWrites",
          "kind": "number"
        },
        {
          "field": "Dashboard.Performance.CacheEfficiency",
          "labelKey": "systemUsageCacheEfficiency",
          "kind": "number"
        },
        {
          "field": "Dashboard.ECP.ECPClients",
          "labelKey": "dashboardApplicationServers",
          "kind": "text"
        },
        {
          "field": "Dashboard.ECP.ECPClientTraffic",
          "labelKey": "dashboardApplicationServerTraffic",
          "kind": "number"
        },
        {
          "field": "Dashboard.ECP.ECPServers",
          "labelKey": "dashboardDataServers",
          "kind": "text"
        },
        {
          "field": "Dashboard.ECP.ECPServerTraffic",
          "labelKey": "dashboardDataServerTraffic",
          "kind": "number"
        },
        {
          "field": "Dashboard.ECP.ShadowConnections",
          "labelKey": "dashboardShadowSource",
          "kind": "text"
        },
        {
          "field": "Dashboard.ECP.Shadows",
          "labelKey": "dashboardShadowServer",
          "kind": "text"
        },
        {
          "field": "Dashboard.Status.UpTime",
          "labelKey": "systemInfoUptime",
          "kind": "name"
        },
        {
          "field": "Dashboard.Status.LastBackup",
          "labelKey": "dashboardLastBackup",
          "kind": "text"
        },
        {
          "field": "Dashboard.SystemUsage.DatabaseSpace",
          "labelKey": "systemUsageDatabaseSpace",
          "kind": "text"
        },
        {
          "field": "Dashboard.SystemUsage.DatabaseJournal",
          "labelKey": "dashboardDatabaseJournal",
          "kind": "text"
        },
        {
          "field": "Dashboard.SystemUsage.JournalSpace",
          "labelKey": "systemUsageJournalSpace",
          "kind": "text"
        },
        {
          "field": "Dashboard.SystemUsage.JournalEntries",
          "labelKey": "systemUsageJournalEntries",
          "kind": "number"
        },
        {
          "field": "Dashboard.SystemUsage.LockTable",
          "labelKey": "systemUsageLockTable",
          "kind": "text"
        },
        {
          "field": "Dashboard.SystemUsage.WriteDaemon",
          "labelKey": "systemUsageWriteDaemon",
          "kind": "text"
        },
        {
          "field": "Dashboard.SystemUsage.Processes",
          "labelKey": "processListLabel",
          "kind": "number"
        },
        {
          "field": "Dashboard.SystemUsage.CSPSessions",
          "labelKey": "webSessionListLabel",
          "kind": "number"
        },
        {
          "field": "Dashboard.Alerts.SeriousAlerts",
          "labelKey": "dashboardSeriousAlerts",
          "kind": "number"
        },
        {
          "field": "Dashboard.Alerts.ApplicationErrors",
          "labelKey": "errorLogListLabel",
          "kind": "number"
        },
        {
          "field": "Dashboard.Licensing.LicenseLimit",
          "labelKey": "dashboardLicenseLimit",
          "kind": "number"
        },
        {
          "field": "Dashboard.Licensing.LicenseUse",
          "labelKey": "dashboardLicenseUse",
          "kind": "number"
        },
        {
          "field": "Dashboard.Licensing.LicenseUseHigh",
          "labelKey": "dashboardLicenseUseHigh",
          "kind": "number"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "osmgmt.dashboard",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.DatabaseDetails",
    "route": "os-management/databases/details",
    "area": "os-management",
    "labelKey": "databaseDetailsLabel",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": true,
    "refreshRates": [
      5,
      10,
      30,
      60
    ],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "database",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "os-management/databases",
    "id": {
      "kind": "composite",
      "parts": [
        "Directory"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "mount",
        "selfProtection": ""
      },
      {
        "id": "dismount",
        "selfProtection": ""
      },
      {
        "id": "truncate",
        "selfProtection": ""
      },
      {
        "id": "compact",
        "selfProtection": ""
      },
      {
        "id": "defragment",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Directory",
        "MaxSize",
        "ExpansionSize",
        "NewVolumeThreshold",
        "NewVolumeDirectory",
        "ResourceName",
        "NewGlobalIsKeep",
        "NewGlobalCollation",
        "ClusterMountMode",
        "ReadOnly",
        "GlobalJournalState",
        "Size",
        "AvailableSpace",
        "DiskFree",
        "Mounted"
      ],
      "secretFields": []
    },
    "emptyStateKey": "databaseDetailsGone",
    "commandAliases": [
      "database details"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "databaseDetailsPrompt1"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "databaseDetailsPrompt2"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "databaseDetailsPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.DatabaseDetails",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Database.SysCRUD",
        "type": "GET",
        "rowGet": {
          "key": "dir",
          "param": "dir",
          "type": "INFO",
          "fields": [
            "Size",
            "AvailableSpace",
            "DiskFree",
            "Mounted"
          ],
          "derived": []
        }
      },
      "fields": [
        "Directory",
        "MaxSize",
        "ExpansionSize",
        "NewVolumeThreshold",
        "NewVolumeDirectory",
        "ResourceName",
        "NewGlobalIsKeep",
        "NewGlobalCollation",
        "ClusterMountMode",
        "ReadOnly",
        "GlobalJournalState",
        "Size",
        "AvailableSpace",
        "DiskFree",
        "Mounted"
      ],
      "filter": [
        "Directory",
        "MaxSize",
        "ExpansionSize",
        "NewVolumeThreshold",
        "NewVolumeDirectory",
        "ResourceName",
        "NewGlobalIsKeep",
        "NewGlobalCollation",
        "ClusterMountMode",
        "ReadOnly",
        "GlobalJournalState",
        "Size",
        "AvailableSpace",
        "DiskFree",
        "Mounted"
      ],
      "sort": {
        "fields": [
          "Directory",
          "MaxSize",
          "ExpansionSize",
          "NewVolumeThreshold",
          "NewVolumeDirectory",
          "ResourceName",
          "NewGlobalIsKeep",
          "NewGlobalCollation",
          "ClusterMountMode",
          "ReadOnly",
          "GlobalJournalState",
          "Size",
          "AvailableSpace",
          "DiskFree",
          "Mounted"
        ],
        "default": "Directory",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "dir",
            "labelKey": "lockColumnDirectory",
            "kind": "text",
            "maxLength": 256
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Directory",
          "labelKey": "lockColumnDirectory",
          "kind": "name"
        },
        {
          "field": "Size",
          "labelKey": "databaseColumnSize",
          "kind": "number"
        },
        {
          "field": "MaxSize",
          "labelKey": "databaseColumnMaxSize",
          "kind": "number"
        },
        {
          "field": "AvailableSpace",
          "labelKey": "databaseColumnAvailable",
          "kind": "number"
        },
        {
          "field": "DiskFree",
          "labelKey": "databaseColumnDiskFree",
          "kind": "text"
        },
        {
          "field": "Mounted",
          "labelKey": "databaseColumnMounted",
          "kind": "status"
        },
        {
          "field": "ExpansionSize",
          "labelKey": "databaseDetailsExpansionSize",
          "kind": "number"
        },
        {
          "field": "NewVolumeThreshold",
          "labelKey": "databaseDetailsNewVolumeThreshold",
          "kind": "number"
        },
        {
          "field": "NewVolumeDirectory",
          "labelKey": "databaseDetailsNewVolumeDirectory",
          "kind": "identifier"
        },
        {
          "field": "ResourceName",
          "labelKey": "webAppColumnResource",
          "kind": "identifier"
        },
        {
          "field": "NewGlobalIsKeep",
          "labelKey": "databaseDetailsKeepNewGlobals",
          "kind": "status"
        },
        {
          "field": "NewGlobalCollation",
          "labelKey": "databaseDetailsNewGlobalCollation",
          "kind": "number"
        },
        {
          "field": "ClusterMountMode",
          "labelKey": "databaseDetailsClusterMountMode",
          "kind": "status"
        },
        {
          "field": "ReadOnly",
          "labelKey": "databaseDetailsReadOnly",
          "kind": "status"
        },
        {
          "field": "GlobalJournalState",
          "labelKey": "databaseDetailsJournalNewGlobals",
          "kind": "status"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "databaseDetailsEmptyAgent"
    },
    "toolIdentifier": "osmgmt.databasedetails",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.DatabaseFreeSpace",
    "route": "os-management/database-free-space",
    "area": "os-management",
    "labelKey": "databaseFreeSpaceLabel",
    "sideBarPosition": 0,
    "archetype": "list",
    "built": true,
    "refreshes": true,
    "refreshRates": [
      5,
      10,
      30,
      60
    ],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "database",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Directory",
        "Size",
        "AvailableSpace",
        "DiskFree",
        "Mounted"
      ],
      "secretFields": []
    },
    "emptyStateKey": "databaseListEmpty",
    "commandAliases": [
      "free space",
      "database free space"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "databaseFreeSpacePrompt1"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "databaseFreeSpacePrompt2"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "databaseFreeSpacePrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.OpDatabases",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Database.SysCRUD",
        "type": "LIST",
        "rowGet": {
          "key": "Directory",
          "param": "dir",
          "type": "INFO",
          "fields": [
            "AvailableSpace",
            "DiskFree",
            "Mounted"
          ],
          "derived": []
        }
      },
      "fields": [
        "Directory",
        "Size",
        "AvailableSpace",
        "DiskFree",
        "Mounted"
      ],
      "filter": [
        "Directory",
        "Size",
        "AvailableSpace",
        "DiskFree",
        "Mounted"
      ],
      "sort": {
        "fields": [
          "Directory",
          "Size",
          "AvailableSpace",
          "DiskFree"
        ],
        "default": "Directory",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Directory",
          "labelKey": "lockColumnDirectory",
          "kind": "name"
        },
        {
          "field": "Size",
          "labelKey": "databaseColumnSize",
          "kind": "number"
        },
        {
          "field": "AvailableSpace",
          "labelKey": "databaseColumnAvailable",
          "kind": "number"
        },
        {
          "field": "DiskFree",
          "labelKey": "databaseColumnDiskFree",
          "kind": "text"
        },
        {
          "field": "Mounted",
          "labelKey": "databaseColumnMounted",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "osmgmt.databasefreespace",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.DatabaseIntegrity",
    "route": "os-management/databases/integrity",
    "area": "os-management",
    "labelKey": "databaseIntegrityLabel",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "database",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [
      "check integrity",
      "integrity check"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "databaseIntegrityPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "databaseIntegrityPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "databaseIntegrityPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Dialog.Integ",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "osmgmt.databaseintegrity",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.DatabaseIntegrityLog",
    "route": "os-management/databases/integrity-log",
    "area": "os-management",
    "labelKey": "databaseIntegrityLogLabel",
    "sideBarPosition": 5,
    "archetype": "log-viewer",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "log-entry",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "time",
        "severity",
        "text"
      ],
      "secretFields": []
    },
    "emptyStateKey": "databaseIntegrityNone",
    "commandAliases": [
      "integrity log"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "databaseIntegrityLogPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "databaseIntegrityLogPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "databaseIntegrityLogPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Dialog.IntegLog",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "logsource",
        "endpoint": "integrity",
        "type": "LIST"
      },
      "fields": [
        "time",
        "severity",
        "text"
      ],
      "filter": [
        "time",
        "severity",
        "text"
      ],
      "sort": {
        "fields": [
          "time",
          "severity"
        ],
        "default": "time",
        "direction": "desc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "time",
          "labelKey": "auditColumnTime",
          "kind": "name"
        },
        {
          "field": "severity",
          "labelKey": "logViewerColumnSeverity",
          "kind": "status"
        },
        {
          "field": "text",
          "labelKey": "logViewerColumnMessage",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "osmgmt.integritylog",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.DatabaseList",
    "route": "os-management/databases",
    "area": "os-management",
    "labelKey": "databaseListLabel",
    "sideBarPosition": 4,
    "archetype": "list (two views)",
    "built": true,
    "refreshes": true,
    "refreshRates": [
      5,
      10,
      30,
      60
    ],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "database",
    "secondaryEntityTypes": [
      "database-configuration"
    ],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "integrity",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "integrity",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Directory",
        "Size",
        "MaxSize",
        "Status",
        "Resource"
      ],
      "secretFields": []
    },
    "emptyStateKey": "databaseListEmpty",
    "commandAliases": [
      "databases",
      "disks"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "databaseListPrompt1"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "databaseListPrompt2"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "databaseListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.OpDatabases",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Database.SysCRUD",
        "type": "LIST"
      },
      "fields": [
        "Directory",
        "Size",
        "MaxSize",
        "Status",
        "Resource"
      ],
      "filter": [
        "Directory",
        "Size",
        "MaxSize",
        "Status",
        "Resource"
      ],
      "sort": {
        "fields": [
          "Directory",
          "Size",
          "MaxSize",
          "Status",
          "Resource"
        ],
        "default": "Directory",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Directory",
          "labelKey": "lockColumnDirectory",
          "kind": "name"
        },
        {
          "field": "Size",
          "labelKey": "databaseColumnSize",
          "kind": "number"
        },
        {
          "field": "MaxSize",
          "labelKey": "databaseColumnMaxSize",
          "kind": "text"
        },
        {
          "field": "Status",
          "labelKey": "taskHistoryColumnStatus",
          "kind": "text"
        },
        {
          "field": "Resource",
          "labelKey": "webAppColumnResource",
          "kind": "identifier"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "databaseListEmptyAgent"
    },
    "toolIdentifier": "osmgmt.databases",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.DatabaseVolumeList",
    "route": "os-management/databases/volumes",
    "area": "os-management",
    "labelKey": "databaseVolumeListLabel",
    "sideBarPosition": 0,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "os-management/databases",
    "id": {
      "kind": "composite",
      "parts": [
        "VolumeNumber"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "VolumeNumber",
        "VolumeDirectory",
        "File",
        "Size",
        "VolumeDirectoryTotalSize",
        "DiskFree"
      ],
      "secretFields": []
    },
    "emptyStateKey": "databaseVolumeListEmpty",
    "commandAliases": [
      "volume files"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "databaseVolumeListPrompt1"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "databaseVolumeListPrompt2"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "databaseVolumeListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.DatabaseDetails",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Database.SysCRUD",
        "type": "VOLUMELIST"
      },
      "fields": [
        "VolumeNumber",
        "VolumeDirectory",
        "File",
        "Size",
        "VolumeDirectoryTotalSize",
        "DiskFree"
      ],
      "filter": [
        "VolumeDirectory",
        "File"
      ],
      "sort": {
        "fields": [
          "VolumeNumber",
          "File",
          "VolumeDirectory",
          "Size",
          "VolumeDirectoryTotalSize",
          "DiskFree"
        ],
        "default": "VolumeNumber",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "dir",
            "labelKey": "lockColumnDirectory",
            "kind": "text",
            "maxLength": 256
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "File",
          "labelKey": "databaseVolumeColumnFile",
          "kind": "name"
        },
        {
          "field": "VolumeNumber",
          "labelKey": "databaseVolumeColumnVolume",
          "kind": "number"
        },
        {
          "field": "VolumeDirectory",
          "labelKey": "lockColumnDirectory",
          "kind": "identifier"
        },
        {
          "field": "Size",
          "labelKey": "databaseColumnSize",
          "kind": "number"
        },
        {
          "field": "VolumeDirectoryTotalSize",
          "labelKey": "databaseVolumeColumnDirectoryTotal",
          "kind": "number"
        },
        {
          "field": "DiskFree",
          "labelKey": "databaseColumnDiskFree",
          "kind": "number"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "osmgmt.databasevolumes",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.DeviceForm",
    "route": "os-management/devices/edit",
    "area": "os-management",
    "labelKey": "deviceFormLabel",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "device",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "deviceFormPrompt1"
      },
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "deviceFormPrompt2"
      },
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "deviceFormPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Config.Device",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "osmgmt.deviceform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.DeviceList",
    "route": "os-management/devices",
    "area": "os-management",
    "labelKey": "deviceListLabel",
    "sideBarPosition": 6,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "device",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Name",
        "PhysicalDevice",
        "Type",
        "SubType",
        "Description",
        "Alias"
      ],
      "secretFields": []
    },
    "emptyStateKey": "deviceListEmpty",
    "commandAliases": [
      "devices",
      "device settings"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "deviceListPrompt1"
      },
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "deviceListPrompt2"
      },
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "deviceListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Config.Devices",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Device.Standard",
        "type": "LIST"
      },
      "fields": [
        "Name",
        "PhysicalDevice",
        "Type",
        "SubType",
        "Description",
        "Alias"
      ],
      "filter": [
        "Name",
        "PhysicalDevice",
        "Type",
        "SubType",
        "Description",
        "Alias"
      ],
      "sort": {
        "fields": [
          "Name",
          "PhysicalDevice",
          "Type",
          "SubType",
          "Description",
          "Alias"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "PhysicalDevice",
          "labelKey": "deviceColumnPhysical",
          "kind": "identifier"
        },
        {
          "field": "Type",
          "labelKey": "tableColumnType",
          "kind": "text"
        },
        {
          "field": "SubType",
          "labelKey": "deviceColumnSubtype",
          "kind": "text"
        },
        {
          "field": "Description",
          "labelKey": "tableColumnDescription",
          "kind": "text"
        },
        {
          "field": "Alias",
          "labelKey": "x509ColumnAlias",
          "kind": "number"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "deviceListEmptyAgent"
    },
    "toolIdentifier": "osmgmt.devices",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.EcpAppServerTab",
    "route": "os-management/ecp-application-servers",
    "area": "os-management",
    "labelKey": "ecpAppServersLabel",
    "sideBarPosition": 19,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "ClientName",
        "Status",
        "IPAddress",
        "IPPort"
      ],
      "secretFields": []
    },
    "emptyStateKey": "ecpAppServerListEmpty",
    "commandAliases": [
      "ecp application servers"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "ecpAppServersPrompt1"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "ecpAppServersPrompt2"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "ecpAppServersPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.ECPAppServers",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "ECP.AppServerList",
        "type": "LIST"
      },
      "fields": [
        "ClientName",
        "Status",
        "IPAddress",
        "IPPort"
      ],
      "filter": [
        "ClientName",
        "Status",
        "IPAddress"
      ],
      "sort": {
        "fields": [
          "ClientName",
          "Status",
          "IPAddress",
          "IPPort"
        ],
        "default": "ClientName",
        "direction": "asc"
      },
      "paging": "cap",
      "note": {
        "key": "ecpDataServerStatusCaveat",
        "text": "Each status is what the instance reported when this list was read."
      }
    },
    "table": {
      "columns": [
        {
          "field": "ClientName",
          "labelKey": "processDetailsClientName",
          "kind": "name"
        },
        {
          "field": "Status",
          "labelKey": "taskHistoryColumnStatus",
          "kind": "status"
        },
        {
          "field": "IPAddress",
          "labelKey": "ecpClientIp",
          "kind": "identifier"
        },
        {
          "field": "IPPort",
          "labelKey": "sslTestPort",
          "kind": "number"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "os-management/ecp-application-servers",
      "position": 1,
      "labelKey": "sslPromptGroupConnections"
    },
    "toolIdentifier": "osmgmt.ecpappservers",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.EcpDataServerForm",
    "route": "os-management/ecp-data-servers/edit",
    "area": "os-management",
    "labelKey": "aboutEcpDataServer",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "ecp-data-server",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "ecpDataServerFormPrompt1"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "ecpDataServerFormPrompt2"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "ecpDataServerFormPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Dialog.ECPDataServer",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "osmgmt.ecpdataserverform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.EcpDataServerList",
    "route": "os-management/ecp-data-servers",
    "area": "os-management",
    "labelKey": "ecpDataServerListLabel",
    "sideBarPosition": 17,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "ecp-data-server",
    "entityLabelKey": "aboutEcpDataServer",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "changestatus",
        "selfProtection": ""
      },
      {
        "id": "delete",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Name",
        "RemoteAddress",
        "RemotePort",
        "Status",
        "MirrorConnection",
        "SSLConfig",
        "BatchMode"
      ],
      "secretFields": []
    },
    "emptyStateKey": "ecpDataServerListEmpty",
    "commandAliases": [
      "ecp data servers",
      "create ecp data server"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "ecpDataServerListPrompt1"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "ecpDataServerListPrompt2"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "ecpDataServerListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.ECPDataServers",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "ECP.DataServer",
        "type": "LIST"
      },
      "fields": [
        "Name",
        "RemoteAddress",
        "RemotePort",
        "Status",
        "MirrorConnection",
        "SSLConfig",
        "BatchMode"
      ],
      "filter": [
        "Name",
        "RemoteAddress",
        "RemotePort",
        "Status"
      ],
      "sort": {
        "fields": [
          "Name",
          "RemoteAddress",
          "RemotePort",
          "Status"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "RemoteAddress",
          "labelKey": "languageServerFieldAddress",
          "kind": "identifier"
        },
        {
          "field": "RemotePort",
          "labelKey": "sslTestPort",
          "kind": "number"
        },
        {
          "field": "Status",
          "labelKey": "taskHistoryColumnStatus",
          "kind": "status"
        },
        {
          "field": "MirrorConnection",
          "labelKey": "ecpDataServerMirrorConnection",
          "kind": "status"
        },
        {
          "field": "SSLConfig",
          "labelKey": "sslListLabel",
          "kind": "status"
        },
        {
          "field": "BatchMode",
          "labelKey": "ecpDataServerBatchMode",
          "kind": "status"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "ecpDataServerListEmptyAgent"
    },
    "toolIdentifier": "osmgmt.ecpdataservers",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": []
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.EcpSettings",
    "route": "os-management/ecp-settings",
    "area": "os-management",
    "labelKey": "ecpSettingsLabel",
    "sideBarPosition": 18,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      }
    ],
    "entityType": "ecp-settings",
    "entityLabelKey": "ecpSettingsLabel",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "AppServerSettings.MaxServers",
        "AppServerSettings.ClientReconnectDuration",
        "AppServerSettings.ClientReconnectInterval",
        "DataServerSettings.MaxServerConn",
        "DataServerSettings.ServerTroubleDuration",
        "DataServerSettings.SSLECPServer"
      ],
      "secretFields": []
    },
    "emptyStateKey": "",
    "commandAliases": [
      "ecp settings"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "ecpSettingsPrompt1"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "ecpSettingsPrompt2"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "ecpSettingsPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.ECP",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "ECP.Settings",
        "type": "GET"
      },
      "fields": [
        "AppServerSettings.MaxServers",
        "AppServerSettings.ClientReconnectDuration",
        "AppServerSettings.ClientReconnectInterval",
        "DataServerSettings.MaxServerConn",
        "DataServerSettings.ServerTroubleDuration",
        "DataServerSettings.SSLECPServer"
      ],
      "filter": [
        "AppServerSettings.MaxServers"
      ],
      "sort": {
        "fields": [
          "AppServerSettings.MaxServers"
        ],
        "default": "AppServerSettings.MaxServers",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "toolIdentifier": "osmgmt.ecpsettings",
    "refreshDefault": 0,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": []
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.EcpSslConnectionTab",
    "route": "os-management/ecp-application-servers/ssl",
    "area": "os-management",
    "labelKey": "ecpSslConnectionsLabel",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "ecp-ssl-connection",
    "entityLabelKey": "ecpSslConnectionEntity",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "authorize",
        "selfProtection": "ecp-ssl-pending"
      },
      {
        "id": "reject",
        "selfProtection": "ecp-ssl-pending"
      },
      {
        "id": "delete",
        "selfProtection": "ecp-ssl-authorized"
      }
    ],
    "context": {
      "fields": [
        "SSLComputerName",
        "ClientIP",
        "Status"
      ],
      "secretFields": []
    },
    "emptyStateKey": "ecpSslConnectionListEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "ecpSslConnectionsPrompt1"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "ecpSslConnectionsPrompt2"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "ecpSslConnectionsPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.ECPAppServers",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "ECP.AppServerSSLConnection",
        "type": "LIST"
      },
      "fields": [
        "SSLComputerName",
        "ClientIP",
        "Status"
      ],
      "filter": [
        "SSLComputerName",
        "ClientIP",
        "Status"
      ],
      "sort": {
        "fields": [
          "SSLComputerName",
          "ClientIP",
          "Status"
        ],
        "default": "SSLComputerName",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "SSLComputerName",
          "labelKey": "ecpSslComputerName",
          "kind": "name"
        },
        {
          "field": "ClientIP",
          "labelKey": "ecpClientIp",
          "kind": "identifier"
        },
        {
          "field": "Status",
          "labelKey": "taskHistoryColumnStatus",
          "kind": "status"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "ecpSslConnectionListEmptyAgent"
    },
    "tab": {
      "group": "os-management/ecp-application-servers",
      "position": 2,
      "labelKey": "ecpSslConnectionsLabel"
    },
    "toolIdentifier": "osmgmt.ecpsslconnections",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": []
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.EncryptionKeyFile",
    "route": "security/encryption-key-file",
    "area": "security",
    "labelKey": "encryptionKeyFileLabel",
    "sideBarPosition": 8,
    "archetype": "list (server criteria)",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%Admin_FileSystemAccess",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_FileSystemAccess",
        "permission": "USE"
      }
    ],
    "entityType": "encryption-key-file",
    "entityLabelKey": "aboutEncryptionKeyFile",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "addkey",
        "selfProtection": ""
      },
      {
        "id": "removekey",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Id",
        "KeyLen",
        "Description"
      ],
      "secretFields": []
    },
    "secretArguments": [
      "AdminPassword"
    ],
    "emptyStateKey": "encryptionKeyFileKeysEmpty",
    "commandAliases": [
      "encryption",
      "encryption key file",
      "create key file"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "encryptionKeyFilePrompt1"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "encryptionKeyFilePrompt2"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "encryptionKeyFilePrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.EncryptionManage",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "encryption",
        "endpoint": "Security.Encryption.KeyInFile",
        "type": "LIST"
      },
      "fields": [
        "Id",
        "KeyLen",
        "Description"
      ],
      "filter": [
        "Id",
        "KeyLen",
        "Description"
      ],
      "sort": {
        "fields": [
          "Id",
          "KeyLen",
          "Description"
        ],
        "default": "Id",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "root",
            "labelKey": "pathPickerRootLabel",
            "kind": "text",
            "maxLength": 1024,
            "hint": "An allowed directory exactly as the Allowed directories screen lists it."
          },
          {
            "param": "path",
            "labelKey": "pathPickerFileLabel",
            "kind": "text",
            "maxLength": 807,
            "hint": "The key file's name under that directory, up to eight /-separated parts."
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Id",
          "labelKey": "encryptionKeyFileColumnId",
          "kind": "name"
        },
        {
          "field": "KeyLen",
          "labelKey": "encryptionKeyFileColumnKeyLen",
          "kind": "number"
        },
        {
          "field": "Description",
          "labelKey": "tableColumnDescription",
          "kind": "text"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "encryptionKeyFileEmptyAgent"
    },
    "toolIdentifier": "security.encryptionkeyfile",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "fingerprintExcludes": []
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.EncryptionKeyFileAdminList",
    "route": "security/encryption-key-file/administrators",
    "area": "security",
    "labelKey": "encryptionKeyFileAdminsTitle",
    "sideBarPosition": 0,
    "archetype": "list (server criteria)",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%Admin_FileSystemAccess",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_FileSystemAccess",
        "permission": "USE"
      }
    ],
    "entityType": "encryption-key-file",
    "entityLabelKey": "aboutEncryptionKeyFile",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "addadministrator",
        "selfProtection": ""
      },
      {
        "id": "removeadministrator",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Name"
      ],
      "secretFields": []
    },
    "secretArguments": [
      "OldAdminPassword",
      "NewAdminPassword"
    ],
    "emptyStateKey": "encryptionKeyFileAdminsEmpty",
    "commandAliases": [
      "key file administrators"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "encryptionKeyFileAdminsPrompt1"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "encryptionKeyFileAdminsPrompt2"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "encryptionKeyFileAdminsPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.EncryptionManage",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "encryption",
        "endpoint": "Security.Encryption.AdminInFile",
        "type": "LIST"
      },
      "fields": [
        "Name"
      ],
      "filter": [
        "Name"
      ],
      "sort": {
        "fields": [
          "Name"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "root",
            "labelKey": "pathPickerRootLabel",
            "kind": "text",
            "maxLength": 1024,
            "hint": "An allowed directory exactly as the Allowed directories screen lists it."
          },
          {
            "param": "path",
            "labelKey": "pathPickerFileLabel",
            "kind": "text",
            "maxLength": 807,
            "hint": "The key file's name under that directory, up to eight /-separated parts."
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "encryptionKeyFileColumnAdmin",
          "kind": "name"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "encryptionKeyFileEmptyAgent"
    },
    "toolIdentifier": "security.encryptionkeyfileadmins",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "fingerprintExcludes": []
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.EncryptionKeyFileForm",
    "route": "security/encryption-key-file/create",
    "area": "security",
    "labelKey": "encryptionKeyFileFormLabel",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%Admin_FileSystemAccess",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_FileSystemAccess",
        "permission": "USE"
      }
    ],
    "entityType": "encryption-key-file",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "encryptionKeyFileFormPrompt1"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "encryptionKeyFileFormPrompt2"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "encryptionKeyFileFormPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.EncryptionCreate",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "security.encryptionkeyfileform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerClassDocument",
    "route": "system-explorer/classes/document",
    "area": "system-explorer",
    "labelKey": "explorerClassDocumentLabel",
    "sideBarPosition": 0,
    "archetype": "viewer (source)",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Kind",
        "Name",
        "Type",
        "Flags"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerClassDocumentEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerClassDocumentPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerClassDocumentPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerClassDocumentPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.ClassList",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Class",
        "type": "LIST"
      },
      "fields": [
        "Order",
        "Kind",
        "Name",
        "Type",
        "Flags",
        "Description",
        "Modified",
        "Database",
        "Generates"
      ],
      "filter": [
        "Name",
        "Kind"
      ],
      "sort": {
        "fields": [
          "Order",
          "Kind",
          "Name"
        ],
        "default": "Order",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "name",
            "labelKey": "tableColumnName",
            "kind": "text",
            "maxLength": 256
          },
          {
            "param": "form",
            "labelKey": "explorerFormLabel",
            "kind": "choice",
            "maxLength": 3,
            "options": [
              "udl",
              "xml",
              "int"
            ],
            "default": "udl"
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Kind",
          "labelKey": "agentLedgerColumnKind",
          "kind": "text"
        },
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Type",
          "labelKey": "tableColumnType",
          "kind": "identifier"
        },
        {
          "field": "Flags",
          "labelKey": "explorerColumnFlags",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "explorer.class",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerClassEditor",
    "route": "system-explorer/classes/editor",
    "area": "system-explorer",
    "labelKey": "explorerClassEditorLabel",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerClassDocumentPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerClassDocumentPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerClassDocumentPrompt3"
      }
    ],
    "classicPage": "",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "explorer.classeditor",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerClassList",
    "route": "system-explorer/classes",
    "area": "system-explorer",
    "labelKey": "explorerClassListLabel",
    "sideBarPosition": 1,
    "archetype": "list (server criteria)",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "compile",
        "selfProtection": ""
      },
      {
        "id": "delete",
        "selfProtection": ""
      },
      {
        "id": "export",
        "selfProtection": ""
      },
      {
        "id": "export-browser",
        "selfProtection": ""
      },
      {
        "id": "import",
        "selfProtection": ""
      },
      {
        "id": "import-local",
        "selfProtection": ""
      },
      {
        "id": "save",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Name",
        "Modified",
        "Database",
        "Generated"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerClassListEmpty",
    "commandAliases": [
      "classes",
      "class list",
      "source code"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerClassListPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerClassListPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerClassListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.ClassList",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Classes",
        "type": "LIST"
      },
      "fields": [
        "Name",
        "Modified",
        "Database",
        "Generated"
      ],
      "filter": [
        "Name",
        "Database"
      ],
      "sort": {
        "fields": [
          "Name",
          "Modified",
          "Database"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "pattern",
            "labelKey": "explorerClassPatternLabel",
            "kind": "text",
            "maxLength": 256,
            "default": "*"
          },
          {
            "param": "system",
            "labelKey": "explorerSystemLabel",
            "kind": "choice",
            "maxLength": 3,
            "options": [
              "yes",
              "no"
            ],
            "default": "no"
          },
          {
            "param": "generated",
            "labelKey": "explorerGeneratedLabel",
            "kind": "choice",
            "maxLength": 3,
            "options": [
              "yes",
              "no"
            ],
            "default": "no"
          },
          {
            "param": "mapped",
            "labelKey": "explorerMappedLabel",
            "kind": "choice",
            "maxLength": 3,
            "options": [
              "yes",
              "no"
            ],
            "default": "yes"
          },
          {
            "param": "from",
            "labelKey": "auditCriteriaBegin",
            "kind": "datetime",
            "maxLength": 30
          },
          {
            "param": "to",
            "labelKey": "auditCriteriaEnd",
            "kind": "datetime",
            "maxLength": 30
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Modified",
          "labelKey": "explorerColumnModified",
          "kind": "text"
        },
        {
          "field": "Database",
          "labelKey": "systemInfoDatabase",
          "kind": "identifier"
        },
        {
          "field": "Generated",
          "labelKey": "explorerColumnGenerated",
          "kind": "status"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "explorerClassListEmptyAgent"
    },
    "toolIdentifier": "explorer.classes",
    "multiSelect": {
      "action": "compile",
      "max": 100,
      "extraActions": [
        "delete",
        "export"
      ]
    },
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerCompare",
    "route": "system-explorer/compare",
    "area": "system-explorer",
    "labelKey": "explorerCompareLabel",
    "sideBarPosition": 4,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [
      "routine"
    ],
    "scope": "namespace",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "emptyStateKey": "",
    "commandAliases": [
      "compare",
      "diff"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerComparePrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerComparePrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerComparePrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.RoutineCompare",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "explorer.compare",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerMacro",
    "route": "system-explorer/macros",
    "area": "system-explorer",
    "labelKey": "explorerMacroLabel",
    "sideBarPosition": 5,
    "archetype": "list (server criteria)",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "routine",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Macro",
        "Document",
        "Line",
        "Definition"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerMacroUndefined",
    "commandAliases": [
      "macro",
      "macro definition"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerMacroPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerMacroPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerMacroPrompt3"
      }
    ],
    "classicPage": "",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Macro",
        "type": "LIST"
      },
      "fields": [
        "Macro",
        "Document",
        "Line",
        "Definition"
      ],
      "filter": [
        "Macro",
        "Document",
        "Definition"
      ],
      "sort": {
        "fields": [
          "Macro",
          "Document"
        ],
        "default": "Macro",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "document",
            "labelKey": "explorerColumnDocument",
            "kind": "text",
            "maxLength": 256
          },
          {
            "param": "macro",
            "labelKey": "explorerColumnMacro",
            "kind": "text",
            "maxLength": 128
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Macro",
          "labelKey": "explorerColumnMacro",
          "kind": "name"
        },
        {
          "field": "Document",
          "labelKey": "explorerColumnDocument",
          "kind": "identifier"
        },
        {
          "field": "Line",
          "labelKey": "explorerColumnLine",
          "kind": "number"
        },
        {
          "field": "Definition",
          "labelKey": "agentDefinitionFormLabel",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "explorer.macro",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerRoutineDocument",
    "route": "system-explorer/routines/document",
    "area": "system-explorer",
    "labelKey": "processColumnRoutine",
    "sideBarPosition": 0,
    "archetype": "viewer (source)",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "routine",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Kind",
        "Name",
        "Type",
        "Flags"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerRoutineDocumentEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerRoutineDocumentPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerRoutineDocumentPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerRoutineDocumentPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.System.ViewCode",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Routine",
        "type": "LIST"
      },
      "fields": [
        "Order",
        "Kind",
        "Name",
        "Type",
        "Flags",
        "Description",
        "Modified",
        "Database",
        "Generates"
      ],
      "filter": [
        "Name",
        "Kind"
      ],
      "sort": {
        "fields": [
          "Order",
          "Kind",
          "Name"
        ],
        "default": "Order",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "name",
            "labelKey": "tableColumnName",
            "kind": "text",
            "maxLength": 256
          },
          {
            "param": "form",
            "labelKey": "explorerFormLabel",
            "kind": "choice",
            "maxLength": 3,
            "options": [
              "udl",
              "xml",
              "int"
            ],
            "default": "udl"
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Kind",
          "labelKey": "agentLedgerColumnKind",
          "kind": "text"
        },
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Type",
          "labelKey": "tableColumnType",
          "kind": "identifier"
        },
        {
          "field": "Flags",
          "labelKey": "explorerColumnFlags",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "explorer.routine",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerRoutineEditor",
    "route": "system-explorer/routines/editor",
    "area": "system-explorer",
    "labelKey": "explorerRoutineEditorLabel",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "routine",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerRoutineDocumentPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerRoutineDocumentPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerRoutineDocumentPrompt3"
      }
    ],
    "classicPage": "",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "explorer.routineeditor",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerRoutineList",
    "route": "system-explorer/routines",
    "area": "system-explorer",
    "labelKey": "explorerRoutineListLabel",
    "sideBarPosition": 2,
    "archetype": "list (server criteria)",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "routine",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "compile",
        "selfProtection": ""
      },
      {
        "id": "delete",
        "selfProtection": ""
      },
      {
        "id": "export",
        "selfProtection": ""
      },
      {
        "id": "export-browser",
        "selfProtection": ""
      },
      {
        "id": "import",
        "selfProtection": ""
      },
      {
        "id": "import-local",
        "selfProtection": ""
      },
      {
        "id": "save",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Name",
        "Modified",
        "Database",
        "Generated"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerRoutineListEmpty",
    "commandAliases": [
      "routines",
      "include files",
      "mac routines"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerRoutineListPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerRoutineListPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerRoutineListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.RoutineList",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Routines",
        "type": "LIST"
      },
      "fields": [
        "Name",
        "Modified",
        "Database",
        "Generated"
      ],
      "filter": [
        "Name",
        "Database"
      ],
      "sort": {
        "fields": [
          "Name",
          "Modified",
          "Database"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "pattern",
            "labelKey": "explorerRoutinePatternLabel",
            "kind": "text",
            "maxLength": 256,
            "default": "*.mac"
          },
          {
            "param": "system",
            "labelKey": "explorerSystemLabel",
            "kind": "choice",
            "maxLength": 3,
            "options": [
              "yes",
              "no"
            ],
            "default": "no"
          },
          {
            "param": "generated",
            "labelKey": "explorerGeneratedLabel",
            "kind": "choice",
            "maxLength": 3,
            "options": [
              "yes",
              "no"
            ],
            "default": "yes"
          },
          {
            "param": "mapped",
            "labelKey": "explorerMappedLabel",
            "kind": "choice",
            "maxLength": 3,
            "options": [
              "yes",
              "no"
            ],
            "default": "yes"
          },
          {
            "param": "from",
            "labelKey": "auditCriteriaBegin",
            "kind": "datetime",
            "maxLength": 30
          },
          {
            "param": "to",
            "labelKey": "auditCriteriaEnd",
            "kind": "datetime",
            "maxLength": 30
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Modified",
          "labelKey": "explorerColumnModified",
          "kind": "text"
        },
        {
          "field": "Database",
          "labelKey": "systemInfoDatabase",
          "kind": "identifier"
        },
        {
          "field": "Generated",
          "labelKey": "explorerColumnGenerated",
          "kind": "status"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "explorerRoutineListEmptyAgent"
    },
    "toolIdentifier": "explorer.routines",
    "multiSelect": {
      "action": "compile",
      "max": 100,
      "extraActions": [
        "delete",
        "export"
      ]
    },
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerSearch",
    "route": "system-explorer/search",
    "area": "system-explorer",
    "labelKey": "auditCriteriaSearch",
    "sideBarPosition": 3,
    "archetype": "list (server criteria)",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [
      "routine"
    ],
    "scope": "namespace",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Document",
        "Member",
        "Line",
        "Text"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerSearchEmpty",
    "commandAliases": [
      "search code",
      "find in files"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSearchPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSearchPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSearchPrompt3"
      }
    ],
    "classicPage": "",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Search",
        "type": "LIST"
      },
      "fields": [
        "Order",
        "Document",
        "Member",
        "Line",
        "Attribute",
        "Text"
      ],
      "filter": [
        "Document",
        "Member",
        "Text"
      ],
      "sort": {
        "fields": [
          "Order",
          "Document"
        ],
        "default": "Order",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "text",
            "labelKey": "explorerSearchTextLabel",
            "kind": "text",
            "maxLength": 256
          },
          {
            "param": "scope",
            "labelKey": "explorerSearchScopeLabel",
            "kind": "choice",
            "maxLength": 8,
            "options": [
              "all",
              "classes",
              "routines"
            ],
            "default": "all"
          },
          {
            "param": "case",
            "labelKey": "explorerSearchCaseLabel",
            "kind": "choice",
            "maxLength": 3,
            "options": [
              "yes",
              "no"
            ],
            "default": "no"
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Document",
          "labelKey": "explorerColumnDocument",
          "kind": "name"
        },
        {
          "field": "Member",
          "labelKey": "explorerColumnMember",
          "kind": "identifier"
        },
        {
          "field": "Line",
          "labelKey": "explorerColumnLine",
          "kind": "number"
        },
        {
          "field": "Text",
          "labelKey": "explorerColumnMatch",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "explorer.search",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerSqlCachedQueries",
    "route": "system-explorer/sql-tables/cached-queries",
    "area": "system-explorer",
    "labelKey": "explorerSqlTabCachedQueries",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "system-explorer/sql-tables",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "CachedQuery",
        "Query",
        "Created",
        "Source",
        "QueryType",
        "Features"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerSqlCachedQueriesEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlCachedQueriesPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlCachedQueriesPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlCachedQueriesPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.SQL.Home",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Catalog.CachedQueries",
        "type": "LIST"
      },
      "fields": [
        "CachedQuery",
        "Query",
        "Created",
        "Source",
        "QueryType",
        "Features"
      ],
      "filter": [
        "CachedQuery",
        "Query",
        "QueryType"
      ],
      "sort": {
        "fields": [
          "CachedQuery",
          "Created",
          "QueryType"
        ],
        "default": "CachedQuery",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "table",
            "labelKey": "explorerSqlColumnTable",
            "kind": "text",
            "maxLength": 257
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "CachedQuery",
          "labelKey": "explorerSqlColumnCachedQuery",
          "kind": "name"
        },
        {
          "field": "Query",
          "labelKey": "auditSqlKindQuery",
          "kind": "text"
        },
        {
          "field": "Created",
          "labelKey": "journalColumnCreated",
          "kind": "text"
        },
        {
          "field": "Source",
          "labelKey": "auditEventFieldSource",
          "kind": "status"
        },
        {
          "field": "QueryType",
          "labelKey": "explorerSqlColumnQueryType",
          "kind": "text"
        },
        {
          "field": "Features",
          "labelKey": "explorerSqlColumnFeatures",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "system-explorer/sql-tables/document",
      "position": 8,
      "labelKey": "explorerSqlTabCachedQueries"
    },
    "toolIdentifier": "explorer.sqlcachedqueries",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerSqlConstraints",
    "route": "system-explorer/sql-tables/constraints",
    "area": "system-explorer",
    "labelKey": "explorerSqlTabConstraints",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "system-explorer/sql-tables",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Constraint",
        "Type",
        "Data"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerSqlConstraintsEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlConstraintsPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlConstraintsPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlConstraintsPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.SQL.Home",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Catalog.Constraints",
        "type": "LIST"
      },
      "fields": [
        "Constraint",
        "Type",
        "Data"
      ],
      "filter": [
        "Constraint",
        "Type",
        "Data"
      ],
      "sort": {
        "fields": [
          "Constraint",
          "Type"
        ],
        "default": "Constraint",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "table",
            "labelKey": "explorerSqlColumnTable",
            "kind": "text",
            "maxLength": 257
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Constraint",
          "labelKey": "explorerSqlColumnConstraint",
          "kind": "name"
        },
        {
          "field": "Type",
          "labelKey": "tableColumnType",
          "kind": "text"
        },
        {
          "field": "Data",
          "labelKey": "explorerSqlColumnConstraintData",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "system-explorer/sql-tables/document",
      "position": 7,
      "labelKey": "explorerSqlTabConstraints"
    },
    "toolIdentifier": "explorer.sqlconstraints",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerSqlData",
    "route": "system-explorer/sql-data",
    "area": "system-explorer",
    "labelKey": "explorerSqlDataLabel",
    "sideBarPosition": 11,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "emptyStateKey": "",
    "commandAliases": [
      "data browser",
      "open table",
      "browse table",
      "table rows"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlDataPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlDataPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlDataPrompt3"
      }
    ],
    "classicPage": "%cspapp.exp.utilsqlopen",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "explorer.sqldata",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerSqlFields",
    "route": "system-explorer/sql-tables/fields",
    "area": "system-explorer",
    "labelKey": "explorerSqlTabFields",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "system-explorer/sql-tables",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Field",
        "Type",
        "Column",
        "Required",
        "Unique",
        "Collation",
        "Hidden",
        "MaxLength",
        "ReferenceTo",
        "Selectivity"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerSqlFieldsEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlFieldsPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlFieldsPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlFieldsPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.SQL.Home",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Catalog.Fields",
        "type": "LIST"
      },
      "fields": [
        "Field",
        "Type",
        "Column",
        "Required",
        "Unique",
        "Collation",
        "Hidden",
        "MaxLength",
        "MinValue",
        "MaxValue",
        "Stream",
        "XdbcType",
        "ReferenceTo",
        "VersionColumn",
        "Selectivity"
      ],
      "filter": [
        "Field",
        "Type",
        "ReferenceTo"
      ],
      "sort": {
        "fields": [
          "Column",
          "Field",
          "Type"
        ],
        "default": "Column",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "table",
            "labelKey": "explorerSqlColumnTable",
            "kind": "text",
            "maxLength": 257
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Field",
          "labelKey": "explorerSqlColumnField",
          "kind": "name"
        },
        {
          "field": "Type",
          "labelKey": "tableColumnType",
          "kind": "identifier"
        },
        {
          "field": "Column",
          "labelKey": "explorerSqlColumnNumber",
          "kind": "number"
        },
        {
          "field": "Required",
          "labelKey": "openApiRequired",
          "kind": "status"
        },
        {
          "field": "Unique",
          "labelKey": "explorerSqlColumnUnique",
          "kind": "status"
        },
        {
          "field": "Collation",
          "labelKey": "mappingColumnCollation",
          "kind": "text"
        },
        {
          "field": "Hidden",
          "labelKey": "explorerSqlColumnHidden",
          "kind": "status"
        },
        {
          "field": "MaxLength",
          "labelKey": "explorerSqlColumnMaxLength",
          "kind": "number"
        },
        {
          "field": "ReferenceTo",
          "labelKey": "explorerSqlColumnReferenceTo",
          "kind": "identifier"
        },
        {
          "field": "Selectivity",
          "labelKey": "explorerSqlColumnSelectivity",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "system-explorer/sql-tables/document",
      "position": 2,
      "labelKey": "explorerSqlTabFields"
    },
    "toolIdentifier": "explorer.sqlfields",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerSqlIndices",
    "route": "system-explorer/sql-tables/indices",
    "area": "system-explorer",
    "labelKey": "explorerSqlTabIndices",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "system-explorer/sql-tables",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Index",
        "Map",
        "Fields",
        "Type",
        "SizeMB",
        "Inherited",
        "Global",
        "Status"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerSqlIndicesEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlIndicesPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlIndicesPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlIndicesPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.SQL.Home",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Catalog.Indices",
        "type": "LIST"
      },
      "fields": [
        "Index",
        "Map",
        "Fields",
        "Type",
        "BitmapArgument",
        "SizeMB",
        "Inherited",
        "Global",
        "Status"
      ],
      "filter": [
        "Index",
        "Map",
        "Fields",
        "Global"
      ],
      "sort": {
        "fields": [
          "Index",
          "Map",
          "Type"
        ],
        "default": "Index",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "table",
            "labelKey": "explorerSqlColumnTable",
            "kind": "text",
            "maxLength": 257
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Index",
          "labelKey": "explorerSqlColumnIndex",
          "kind": "name"
        },
        {
          "field": "Map",
          "labelKey": "explorerSqlColumnMap",
          "kind": "identifier"
        },
        {
          "field": "Fields",
          "labelKey": "explorerSqlColumnColumns",
          "kind": "text"
        },
        {
          "field": "Type",
          "labelKey": "tableColumnType",
          "kind": "text"
        },
        {
          "field": "SizeMB",
          "labelKey": "databaseSizeField",
          "kind": "text"
        },
        {
          "field": "Inherited",
          "labelKey": "explorerSqlColumnInherited",
          "kind": "status"
        },
        {
          "field": "Global",
          "labelKey": "explorerSqlColumnGlobal",
          "kind": "identifier"
        },
        {
          "field": "Status",
          "labelKey": "taskHistoryColumnStatus",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "system-explorer/sql-tables/document",
      "position": 3,
      "labelKey": "explorerSqlTabIndices"
    },
    "toolIdentifier": "explorer.sqlindices",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerSqlPartitionMappings",
    "route": "system-explorer/sql-tables/partition-mappings",
    "area": "system-explorer",
    "labelKey": "explorerSqlTabPartitionMappings",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "system-explorer/sql-tables",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Rule",
        "Buckets",
        "Rows",
        "EstimatedSize",
        "Location"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerSqlPartitionMappingsEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlPartitionMappingsPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlPartitionMappingsPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlPartitionMappingsPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.SQL.Home",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Catalog.PartitionMappings",
        "type": "LIST"
      },
      "fields": [
        "Rule",
        "Buckets",
        "Rows",
        "EstimatedSize",
        "Location"
      ],
      "filter": [
        "Rule",
        "Location"
      ],
      "sort": {
        "fields": [
          "Rule",
          "Rows",
          "EstimatedSize"
        ],
        "default": "Rule",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "table",
            "labelKey": "explorerSqlColumnTable",
            "kind": "text",
            "maxLength": 257
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Rule",
          "labelKey": "explorerSqlColumnRule",
          "kind": "name"
        },
        {
          "field": "Buckets",
          "labelKey": "explorerSqlColumnBuckets",
          "kind": "number"
        },
        {
          "field": "Rows",
          "labelKey": "explorerSqlColumnRows",
          "kind": "number"
        },
        {
          "field": "EstimatedSize",
          "labelKey": "explorerSqlColumnEstimatedSize",
          "kind": "number"
        },
        {
          "field": "Location",
          "labelKey": "processDetailsLocation",
          "kind": "identifier"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "system-explorer/sql-tables/document",
      "position": 5,
      "labelKey": "explorerSqlTabPartitionMappings"
    },
    "toolIdentifier": "explorer.sqlpartitionmappings",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerSqlPartitions",
    "route": "system-explorer/sql-tables/partitions",
    "area": "system-explorer",
    "labelKey": "explorerSqlTabPartitions",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "system-explorer/sql-tables",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Partition",
        "Buckets",
        "Rows",
        "EstimatedSize",
        "Location"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerSqlPartitionsEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlPartitionsPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlPartitionsPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlPartitionsPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.SQL.Home",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Catalog.Partitions",
        "type": "LIST"
      },
      "fields": [
        "Partition",
        "Buckets",
        "Rows",
        "EstimatedSize",
        "Location"
      ],
      "filter": [
        "Partition",
        "Location"
      ],
      "sort": {
        "fields": [
          "Partition",
          "Rows",
          "EstimatedSize"
        ],
        "default": "Partition",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "table",
            "labelKey": "explorerSqlColumnTable",
            "kind": "text",
            "maxLength": 257
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Partition",
          "labelKey": "explorerSqlColumnPartition",
          "kind": "name"
        },
        {
          "field": "Buckets",
          "labelKey": "explorerSqlColumnBuckets",
          "kind": "number"
        },
        {
          "field": "Rows",
          "labelKey": "explorerSqlColumnRows",
          "kind": "number"
        },
        {
          "field": "EstimatedSize",
          "labelKey": "explorerSqlColumnEstimatedSize",
          "kind": "number"
        },
        {
          "field": "Location",
          "labelKey": "processDetailsLocation",
          "kind": "identifier"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "system-explorer/sql-tables/document",
      "position": 4,
      "labelKey": "explorerSqlTabPartitions"
    },
    "toolIdentifier": "explorer.sqlpartitions",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerSqlProcedure",
    "route": "system-explorer/sql-procedures/document",
    "area": "system-explorer",
    "labelKey": "explorerSqlProcedureLabel",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "system-explorer/sql-procedures",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Class",
        "Type",
        "Method",
        "Description",
        "Inputs",
        "InOuts",
        "Outputs",
        "Interface",
        "Columns",
        "InputParameters",
        "InOutParameters",
        "OutputParameters",
        "ResultColumns",
        "ReturnValue"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerSqlProcedureEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlProcedurePrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlProcedurePrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlProcedurePrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.SQL.Home",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Catalog.Procedure",
        "type": "LIST"
      },
      "fields": [
        "Class",
        "Type",
        "Method",
        "Description",
        "Inputs",
        "InOuts",
        "Outputs",
        "Interface",
        "Columns",
        "InputParameters",
        "InOutParameters",
        "OutputParameters",
        "ResultColumns",
        "ReturnValue"
      ],
      "filter": [
        "Class",
        "Method",
        "Description"
      ],
      "sort": {
        "fields": [
          "Class"
        ],
        "default": "Class",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "procedure",
            "labelKey": "explorerSqlColumnProcedure",
            "kind": "text",
            "maxLength": 257
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Class",
          "labelKey": "explorerClassDocumentLabel",
          "kind": "name"
        },
        {
          "field": "Type",
          "labelKey": "tableColumnType",
          "kind": "text"
        },
        {
          "field": "Method",
          "labelKey": "explorerSqlColumnMethod",
          "kind": "identifier"
        },
        {
          "field": "Description",
          "labelKey": "tableColumnDescription",
          "kind": "text"
        },
        {
          "field": "Inputs",
          "labelKey": "explorerSqlColumnInputs",
          "kind": "number"
        },
        {
          "field": "InOuts",
          "labelKey": "explorerSqlColumnInOuts",
          "kind": "number"
        },
        {
          "field": "Outputs",
          "labelKey": "explorerSqlColumnOutputs",
          "kind": "number"
        },
        {
          "field": "Interface",
          "labelKey": "explorerSqlColumnInterface",
          "kind": "number"
        },
        {
          "field": "Columns",
          "labelKey": "explorerSqlColumnColumnCount",
          "kind": "number"
        },
        {
          "field": "InputParameters",
          "labelKey": "explorerSqlColumnInputParameters",
          "kind": "text"
        },
        {
          "field": "InOutParameters",
          "labelKey": "explorerSqlColumnInOutParameters",
          "kind": "text"
        },
        {
          "field": "OutputParameters",
          "labelKey": "explorerSqlColumnOutputParameters",
          "kind": "text"
        },
        {
          "field": "ResultColumns",
          "labelKey": "explorerSqlColumnResultColumns",
          "kind": "text"
        },
        {
          "field": "ReturnValue",
          "labelKey": "explorerSqlColumnReturnValue",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "system-explorer/sql-procedures/document",
      "position": 1,
      "labelKey": "explorerSqlTabProcedureInfo"
    },
    "toolIdentifier": "explorer.sqlprocedure",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerSqlProcedureStatements",
    "route": "system-explorer/sql-procedures/statements",
    "area": "system-explorer",
    "labelKey": "explorerSqlTabStatements",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "system-explorer/sql-procedures",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Statement",
        "PlanState",
        "NewPlan",
        "Executions",
        "TotalTime",
        "AverageTime",
        "StdDevTime",
        "RowCount",
        "Commands",
        "FirstSeen",
        "Location"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerSqlProcedureStatementsEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlProcedureStatementsPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlProcedureStatementsPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlProcedureStatementsPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.SQL.Home",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Catalog.ProcedureStatements",
        "type": "LIST"
      },
      "fields": [
        "Statement",
        "PlanState",
        "NewPlan",
        "Executions",
        "TotalTime",
        "AverageTime",
        "StdDevTime",
        "RowCount",
        "Commands",
        "FirstSeen",
        "Location"
      ],
      "filter": [
        "Statement",
        "PlanState",
        "Location"
      ],
      "sort": {
        "fields": [
          "Statement",
          "Executions",
          "TotalTime",
          "FirstSeen"
        ],
        "default": "Statement",
        "direction": "asc"
      },
      "paging": "cap",
      "note": {
        "key": "explorerSqlStatementsNote",
        "text": "Statistics are as of the instance's last aggregation, so a recently run statement can read blank."
      },
      "criteria": {
        "fields": [
          {
            "param": "procedure",
            "labelKey": "explorerSqlColumnProcedure",
            "kind": "text",
            "maxLength": 257
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Statement",
          "labelKey": "explorerSqlColumnStatement",
          "kind": "name"
        },
        {
          "field": "PlanState",
          "labelKey": "explorerSqlColumnPlanState",
          "kind": "text"
        },
        {
          "field": "NewPlan",
          "labelKey": "explorerSqlColumnNewPlan",
          "kind": "status"
        },
        {
          "field": "Executions",
          "labelKey": "explorerSqlColumnExecutions",
          "kind": "number"
        },
        {
          "field": "TotalTime",
          "labelKey": "explorerSqlColumnTotalTime",
          "kind": "number"
        },
        {
          "field": "AverageTime",
          "labelKey": "explorerSqlColumnAverageTime",
          "kind": "number"
        },
        {
          "field": "StdDevTime",
          "labelKey": "explorerSqlColumnStdDevTime",
          "kind": "number"
        },
        {
          "field": "RowCount",
          "labelKey": "explorerSqlColumnRowCount",
          "kind": "number"
        },
        {
          "field": "Commands",
          "labelKey": "processColumnCommands",
          "kind": "number"
        },
        {
          "field": "FirstSeen",
          "labelKey": "explorerSqlColumnFirstSeen",
          "kind": "text"
        },
        {
          "field": "Location",
          "labelKey": "processDetailsLocation",
          "kind": "identifier"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "system-explorer/sql-procedures/document",
      "position": 2,
      "labelKey": "explorerSqlTabStatements"
    },
    "toolIdentifier": "explorer.sqlprocedurestatements",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerSqlProcedures",
    "route": "system-explorer/sql-procedures",
    "area": "system-explorer",
    "labelKey": "explorerSqlProceduresLabel",
    "sideBarPosition": 9,
    "archetype": "list (server criteria)",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Procedure",
        "Type",
        "Class",
        "Method"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerSqlProceduresEmpty",
    "commandAliases": [
      "sql procedures",
      "stored procedures"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlProceduresPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlProceduresPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlProceduresPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.SQL.Home",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Catalog.Procedures",
        "type": "LIST"
      },
      "fields": [
        "Procedure",
        "Schema",
        "Name",
        "Type",
        "Class",
        "Method"
      ],
      "filter": [
        "Procedure",
        "Schema",
        "Class"
      ],
      "sort": {
        "fields": [
          "Procedure",
          "Type",
          "Class"
        ],
        "default": "Procedure",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "system",
            "labelKey": "explorerSystemLabel",
            "kind": "choice",
            "maxLength": 3,
            "options": [
              "yes",
              "no"
            ],
            "default": "no"
          },
          {
            "param": "schema",
            "labelKey": "explorerSqlColumnSchema",
            "kind": "text",
            "maxLength": 128
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Procedure",
          "labelKey": "explorerSqlColumnProcedure",
          "kind": "name"
        },
        {
          "field": "Type",
          "labelKey": "tableColumnType",
          "kind": "text"
        },
        {
          "field": "Class",
          "labelKey": "explorerClassDocumentLabel",
          "kind": "identifier"
        },
        {
          "field": "Method",
          "labelKey": "explorerSqlColumnMethod",
          "kind": "identifier"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "explorer.sqlprocedures",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerSqlQuery",
    "route": "system-explorer/sql-query",
    "area": "system-explorer",
    "labelKey": "explorerSqlQueryLabel",
    "sideBarPosition": 10,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "run",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "emptyStateKey": "",
    "commandAliases": [
      "sql query",
      "execute query",
      "run sql"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlQueryPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlQueryPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlQueryPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.SQL.Home",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "explorer.sqlquery",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerSqlSchemas",
    "route": "system-explorer/sql-schemas",
    "area": "system-explorer",
    "labelKey": "explorerSqlSchemasLabel",
    "sideBarPosition": 6,
    "archetype": "list (server criteria)",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Schema",
        "Tables",
        "Views",
        "Procedures"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerSqlSchemasEmpty",
    "commandAliases": [
      "sql schemas",
      "schemas"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlSchemasPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlSchemasPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlSchemasPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.SQL.Home",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Catalog.Schemas",
        "type": "LIST"
      },
      "fields": [
        "Schema",
        "Tables",
        "Views",
        "Procedures"
      ],
      "filter": [
        "Schema"
      ],
      "sort": {
        "fields": [
          "Schema"
        ],
        "default": "Schema",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "system",
            "labelKey": "explorerSystemLabel",
            "kind": "choice",
            "maxLength": 3,
            "options": [
              "yes",
              "no"
            ],
            "default": "no"
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Schema",
          "labelKey": "explorerSqlColumnSchema",
          "kind": "name"
        },
        {
          "field": "Tables",
          "labelKey": "explorerSqlColumnTables",
          "kind": "status"
        },
        {
          "field": "Views",
          "labelKey": "explorerSqlColumnViews",
          "kind": "status"
        },
        {
          "field": "Procedures",
          "labelKey": "explorerSqlColumnProcedures",
          "kind": "status"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "explorer.sqlschemas",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerSqlTable",
    "route": "system-explorer/sql-tables/document",
    "area": "system-explorer",
    "labelKey": "explorerSqlTableLabel",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "system-explorer/sql-tables",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Name",
        "Owner",
        "LastCompiled",
        "External",
        "ReadOnly",
        "Partitioned",
        "Class",
        "ExtentSize",
        "ExternalType"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerSqlTableEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlTablePrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlTablePrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlTablePrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.SQL.Home",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Catalog.Table",
        "type": "LIST"
      },
      "fields": [
        "Name",
        "Owner",
        "LastCompiled",
        "External",
        "ReadOnly",
        "Partitioned",
        "Class",
        "ExtentSize",
        "ExternalType"
      ],
      "filter": [
        "Name",
        "Class"
      ],
      "sort": {
        "fields": [
          "Name"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "table",
            "labelKey": "explorerSqlColumnTable",
            "kind": "text",
            "maxLength": 257
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Owner",
          "labelKey": "explorerSqlColumnOwner",
          "kind": "text"
        },
        {
          "field": "LastCompiled",
          "labelKey": "explorerSqlColumnLastCompiled",
          "kind": "text"
        },
        {
          "field": "External",
          "labelKey": "explorerSqlColumnExternal",
          "kind": "status"
        },
        {
          "field": "ReadOnly",
          "labelKey": "agentDefinitionFieldReadOnly",
          "kind": "status"
        },
        {
          "field": "Partitioned",
          "labelKey": "explorerSqlColumnPartitioned",
          "kind": "status"
        },
        {
          "field": "Class",
          "labelKey": "explorerClassDocumentLabel",
          "kind": "identifier"
        },
        {
          "field": "ExtentSize",
          "labelKey": "explorerSqlColumnExtentSize",
          "kind": "number"
        },
        {
          "field": "ExternalType",
          "labelKey": "explorerSqlColumnExternalType",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "system-explorer/sql-tables/document",
      "position": 1,
      "labelKey": "explorerSqlTabInfo"
    },
    "toolIdentifier": "explorer.sqltable",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerSqlTableStatements",
    "route": "system-explorer/sql-tables/statements",
    "area": "system-explorer",
    "labelKey": "explorerSqlTabStatements",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "system-explorer/sql-tables",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Statement",
        "PlanState",
        "NewPlan",
        "Executions",
        "TotalTime",
        "AverageTime",
        "StdDevTime",
        "RowCount",
        "Commands",
        "FirstSeen",
        "Location"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerSqlTableStatementsEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlTableStatementsPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlTableStatementsPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlTableStatementsPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.SQL.Home",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Catalog.TableStatements",
        "type": "LIST"
      },
      "fields": [
        "Statement",
        "PlanState",
        "NewPlan",
        "Executions",
        "TotalTime",
        "AverageTime",
        "StdDevTime",
        "RowCount",
        "Commands",
        "FirstSeen",
        "Location"
      ],
      "filter": [
        "Statement",
        "PlanState",
        "Location"
      ],
      "sort": {
        "fields": [
          "Statement",
          "Executions",
          "TotalTime",
          "FirstSeen"
        ],
        "default": "Statement",
        "direction": "asc"
      },
      "paging": "cap",
      "note": {
        "key": "explorerSqlStatementsNote",
        "text": "Statistics are as of the instance's last aggregation, so a recently run statement can read blank."
      },
      "criteria": {
        "fields": [
          {
            "param": "table",
            "labelKey": "explorerSqlColumnTable",
            "kind": "text",
            "maxLength": 257
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Statement",
          "labelKey": "explorerSqlColumnStatement",
          "kind": "name"
        },
        {
          "field": "PlanState",
          "labelKey": "explorerSqlColumnPlanState",
          "kind": "text"
        },
        {
          "field": "NewPlan",
          "labelKey": "explorerSqlColumnNewPlan",
          "kind": "status"
        },
        {
          "field": "Executions",
          "labelKey": "explorerSqlColumnExecutions",
          "kind": "number"
        },
        {
          "field": "TotalTime",
          "labelKey": "explorerSqlColumnTotalTime",
          "kind": "number"
        },
        {
          "field": "AverageTime",
          "labelKey": "explorerSqlColumnAverageTime",
          "kind": "number"
        },
        {
          "field": "StdDevTime",
          "labelKey": "explorerSqlColumnStdDevTime",
          "kind": "number"
        },
        {
          "field": "RowCount",
          "labelKey": "explorerSqlColumnRowCount",
          "kind": "number"
        },
        {
          "field": "Commands",
          "labelKey": "processColumnCommands",
          "kind": "number"
        },
        {
          "field": "FirstSeen",
          "labelKey": "explorerSqlColumnFirstSeen",
          "kind": "text"
        },
        {
          "field": "Location",
          "labelKey": "processDetailsLocation",
          "kind": "identifier"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "system-explorer/sql-tables/document",
      "position": 9,
      "labelKey": "explorerSqlTabStatements"
    },
    "toolIdentifier": "explorer.sqltablestatements",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerSqlTables",
    "route": "system-explorer/sql-tables",
    "area": "system-explorer",
    "labelKey": "explorerSqlTablesLabel",
    "sideBarPosition": 7,
    "archetype": "list (server criteria)",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Table",
        "Class",
        "Owner",
        "Sharded",
        "Partitioned"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerSqlTablesEmpty",
    "commandAliases": [
      "sql tables",
      "tables"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlTablesPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlTablesPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlTablesPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.SQL.Home",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Catalog.Tables",
        "type": "LIST"
      },
      "fields": [
        "Table",
        "Schema",
        "Name",
        "Class",
        "Owner",
        "Sharded",
        "Partitioned"
      ],
      "filter": [
        "Table",
        "Schema",
        "Class"
      ],
      "sort": {
        "fields": [
          "Table",
          "Class",
          "Owner"
        ],
        "default": "Table",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "system",
            "labelKey": "explorerSystemLabel",
            "kind": "choice",
            "maxLength": 3,
            "options": [
              "yes",
              "no"
            ],
            "default": "no"
          },
          {
            "param": "schema",
            "labelKey": "explorerSqlColumnSchema",
            "kind": "text",
            "maxLength": 128
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Table",
          "labelKey": "explorerSqlColumnTable",
          "kind": "name"
        },
        {
          "field": "Class",
          "labelKey": "explorerClassDocumentLabel",
          "kind": "identifier"
        },
        {
          "field": "Owner",
          "labelKey": "explorerSqlColumnOwner",
          "kind": "text"
        },
        {
          "field": "Sharded",
          "labelKey": "explorerSqlColumnSharded",
          "kind": "status"
        },
        {
          "field": "Partitioned",
          "labelKey": "explorerSqlColumnPartitioned",
          "kind": "status"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "explorer.sqltables",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerSqlTriggers",
    "route": "system-explorer/sql-tables/triggers",
    "area": "system-explorer",
    "labelKey": "explorerSqlTabTriggers",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "system-explorer/sql-tables",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Trigger",
        "Event",
        "Order",
        "Code"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerSqlTriggersEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlTriggersPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlTriggersPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlTriggersPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.SQL.Home",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Catalog.Triggers",
        "type": "LIST"
      },
      "fields": [
        "Trigger",
        "Event",
        "Order",
        "Code"
      ],
      "filter": [
        "Trigger",
        "Event",
        "Code"
      ],
      "sort": {
        "fields": [
          "Trigger",
          "Event",
          "Order"
        ],
        "default": "Trigger",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "table",
            "labelKey": "explorerSqlColumnTable",
            "kind": "text",
            "maxLength": 257
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Trigger",
          "labelKey": "explorerSqlColumnTrigger",
          "kind": "name"
        },
        {
          "field": "Event",
          "labelKey": "explorerSqlColumnEvent",
          "kind": "text"
        },
        {
          "field": "Order",
          "labelKey": "explorerSqlColumnOrder",
          "kind": "number"
        },
        {
          "field": "Code",
          "labelKey": "webAppPromptGroupCode",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "system-explorer/sql-tables/document",
      "position": 6,
      "labelKey": "explorerSqlTabTriggers"
    },
    "toolIdentifier": "explorer.sqltriggers",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerSqlView",
    "route": "system-explorer/sql-views/document",
    "area": "system-explorer",
    "labelKey": "explorerSqlViewLabel",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "system-explorer/sql-views",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Class",
        "Owner",
        "LastCompiled",
        "ReadOnly",
        "Updatable",
        "CheckOption",
        "ClassType",
        "Text"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerSqlViewEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlViewPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlViewPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlViewPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.SQL.Home",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Catalog.View",
        "type": "LIST"
      },
      "fields": [
        "Owner",
        "LastCompiled",
        "ReadOnly",
        "Updatable",
        "Class",
        "CheckOption",
        "ClassType",
        "Text"
      ],
      "filter": [
        "Class",
        "Owner",
        "Text"
      ],
      "sort": {
        "fields": [
          "Class"
        ],
        "default": "Class",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "view",
            "labelKey": "viewMenuLabel",
            "kind": "text",
            "maxLength": 257
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Class",
          "labelKey": "explorerClassDocumentLabel",
          "kind": "name"
        },
        {
          "field": "Owner",
          "labelKey": "explorerSqlColumnOwner",
          "kind": "text"
        },
        {
          "field": "LastCompiled",
          "labelKey": "explorerSqlColumnLastCompiled",
          "kind": "text"
        },
        {
          "field": "ReadOnly",
          "labelKey": "agentDefinitionFieldReadOnly",
          "kind": "status"
        },
        {
          "field": "Updatable",
          "labelKey": "explorerSqlColumnUpdatable",
          "kind": "status"
        },
        {
          "field": "CheckOption",
          "labelKey": "explorerSqlColumnCheckOption",
          "kind": "text"
        },
        {
          "field": "ClassType",
          "labelKey": "explorerSqlColumnClassType",
          "kind": "text"
        },
        {
          "field": "Text",
          "labelKey": "explorerSearchTextLabel",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "system-explorer/sql-views/document",
      "position": 1,
      "labelKey": "explorerSqlTabViewInfo"
    },
    "toolIdentifier": "explorer.sqlview",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerSqlViewFields",
    "route": "system-explorer/sql-views/fields",
    "area": "system-explorer",
    "labelKey": "explorerSqlTabFields",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "system-explorer/sql-views",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Field",
        "Type",
        "Collation",
        "MaxLength",
        "Length",
        "Precision",
        "Scale",
        "Stream"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerSqlViewFieldsEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlViewFieldsPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlViewFieldsPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlViewFieldsPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.SQL.Home",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Catalog.ViewFields",
        "type": "LIST"
      },
      "fields": [
        "Field",
        "Type",
        "Collation",
        "MaxLength",
        "MaxValue",
        "MinValue",
        "Stream",
        "Length",
        "Precision",
        "Scale"
      ],
      "filter": [
        "Field",
        "Type"
      ],
      "sort": {
        "fields": [
          "Field",
          "Type"
        ],
        "default": "Field",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "view",
            "labelKey": "viewMenuLabel",
            "kind": "text",
            "maxLength": 257
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Field",
          "labelKey": "explorerSqlColumnField",
          "kind": "name"
        },
        {
          "field": "Type",
          "labelKey": "tableColumnType",
          "kind": "identifier"
        },
        {
          "field": "Collation",
          "labelKey": "mappingColumnCollation",
          "kind": "text"
        },
        {
          "field": "MaxLength",
          "labelKey": "explorerSqlColumnMaxLength",
          "kind": "number"
        },
        {
          "field": "Length",
          "labelKey": "explorerSqlColumnLength",
          "kind": "number"
        },
        {
          "field": "Precision",
          "labelKey": "explorerSqlColumnPrecision",
          "kind": "number"
        },
        {
          "field": "Scale",
          "labelKey": "explorerSqlColumnScale",
          "kind": "number"
        },
        {
          "field": "Stream",
          "labelKey": "explorerSqlColumnStream",
          "kind": "status"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "system-explorer/sql-views/document",
      "position": 2,
      "labelKey": "explorerSqlTabFields"
    },
    "toolIdentifier": "explorer.sqlviewfields",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerSqlViewStatements",
    "route": "system-explorer/sql-views/statements",
    "area": "system-explorer",
    "labelKey": "explorerSqlTabStatements",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "system-explorer/sql-views",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Statement",
        "PlanState",
        "NewPlan",
        "Executions",
        "TotalTime",
        "AverageTime",
        "StdDevTime",
        "RowCount",
        "Commands",
        "FirstSeen",
        "Location"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerSqlViewStatementsEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlViewStatementsPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlViewStatementsPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlViewStatementsPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.SQL.Home",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Catalog.ViewStatements",
        "type": "LIST"
      },
      "fields": [
        "Statement",
        "PlanState",
        "NewPlan",
        "Executions",
        "TotalTime",
        "AverageTime",
        "StdDevTime",
        "RowCount",
        "Commands",
        "FirstSeen",
        "Location"
      ],
      "filter": [
        "Statement",
        "PlanState",
        "Location"
      ],
      "sort": {
        "fields": [
          "Statement",
          "Executions",
          "TotalTime",
          "FirstSeen"
        ],
        "default": "Statement",
        "direction": "asc"
      },
      "paging": "cap",
      "note": {
        "key": "explorerSqlStatementsNote",
        "text": "Statistics are as of the instance's last aggregation, so a recently run statement can read blank."
      },
      "criteria": {
        "fields": [
          {
            "param": "view",
            "labelKey": "viewMenuLabel",
            "kind": "text",
            "maxLength": 257
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Statement",
          "labelKey": "explorerSqlColumnStatement",
          "kind": "name"
        },
        {
          "field": "PlanState",
          "labelKey": "explorerSqlColumnPlanState",
          "kind": "text"
        },
        {
          "field": "NewPlan",
          "labelKey": "explorerSqlColumnNewPlan",
          "kind": "status"
        },
        {
          "field": "Executions",
          "labelKey": "explorerSqlColumnExecutions",
          "kind": "number"
        },
        {
          "field": "TotalTime",
          "labelKey": "explorerSqlColumnTotalTime",
          "kind": "number"
        },
        {
          "field": "AverageTime",
          "labelKey": "explorerSqlColumnAverageTime",
          "kind": "number"
        },
        {
          "field": "StdDevTime",
          "labelKey": "explorerSqlColumnStdDevTime",
          "kind": "number"
        },
        {
          "field": "RowCount",
          "labelKey": "explorerSqlColumnRowCount",
          "kind": "number"
        },
        {
          "field": "Commands",
          "labelKey": "processColumnCommands",
          "kind": "number"
        },
        {
          "field": "FirstSeen",
          "labelKey": "explorerSqlColumnFirstSeen",
          "kind": "text"
        },
        {
          "field": "Location",
          "labelKey": "processDetailsLocation",
          "kind": "identifier"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "system-explorer/sql-views/document",
      "position": 3,
      "labelKey": "explorerSqlTabStatements"
    },
    "toolIdentifier": "explorer.sqlviewstatements",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ExplorerSqlViews",
    "route": "system-explorer/sql-views",
    "area": "system-explorer",
    "labelKey": "explorerSqlViewsLabel",
    "sideBarPosition": 8,
    "archetype": "list (server criteria)",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Development",
        "permission": "USE"
      }
    ],
    "entityType": "class",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "View",
        "Class",
        "Owner",
        "Updatable",
        "CheckOption"
      ],
      "secretFields": []
    },
    "emptyStateKey": "explorerSqlViewsEmpty",
    "commandAliases": [
      "sql views",
      "views"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlViewsPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlViewsPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "explorerSqlViewsPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.SQL.Home",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "atelier",
        "endpoint": "Catalog.Views",
        "type": "LIST"
      },
      "fields": [
        "View",
        "Schema",
        "Name",
        "Class",
        "Owner",
        "Updatable",
        "CheckOption"
      ],
      "filter": [
        "View",
        "Schema",
        "Class"
      ],
      "sort": {
        "fields": [
          "View",
          "Class",
          "Owner"
        ],
        "default": "View",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "system",
            "labelKey": "explorerSystemLabel",
            "kind": "choice",
            "maxLength": 3,
            "options": [
              "yes",
              "no"
            ],
            "default": "no"
          },
          {
            "param": "schema",
            "labelKey": "explorerSqlColumnSchema",
            "kind": "text",
            "maxLength": 128
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "View",
          "labelKey": "viewMenuLabel",
          "kind": "name"
        },
        {
          "field": "Class",
          "labelKey": "explorerClassDocumentLabel",
          "kind": "identifier"
        },
        {
          "field": "Owner",
          "labelKey": "explorerSqlColumnOwner",
          "kind": "text"
        },
        {
          "field": "Updatable",
          "labelKey": "explorerSqlColumnUpdatable",
          "kind": "status"
        },
        {
          "field": "CheckOption",
          "labelKey": "explorerSqlColumnCheckOption",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "explorer.sqlviews",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.GlobalMappingForm",
    "route": "os-management/namespaces/global-mappings/edit",
    "area": "os-management",
    "labelKey": "globalMappingFormLabel",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "global-mapping",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "composite",
      "parts": [
        "namespace",
        "Name"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "globalMappingFormPrompt1"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "globalMappingFormPrompt2"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "globalMappingFormPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Mappings.Global",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "osmgmt.globalmappingform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.GlobalMappingList",
    "route": "os-management/namespaces/global-mappings",
    "area": "os-management",
    "labelKey": "globalMappingListLabel",
    "sideBarPosition": 0,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "global-mapping",
    "secondaryEntityTypes": [
      "namespace"
    ],
    "scope": "instance",
    "parentScope": "os-management/namespaces",
    "id": {
      "kind": "composite",
      "parts": [
        "namespace",
        "Name"
      ]
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "delete",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "namespace",
        "Name",
        "Database",
        "LockDatabase",
        "Collation"
      ],
      "secretFields": []
    },
    "emptyStateKey": "globalMappingListEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "globalMappingListPrompt1"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "globalMappingListPrompt2"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "globalMappingListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Mappings",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Namespace.GlobalMappings",
        "type": "LIST"
      },
      "fields": [
        "namespace",
        "Name",
        "Database",
        "LockDatabase",
        "Collation"
      ],
      "filter": [
        "Name",
        "Database",
        "LockDatabase"
      ],
      "sort": {
        "fields": [
          "Name",
          "Database",
          "LockDatabase",
          "Collation"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "namespace",
            "labelKey": "headerNamespaceLabel",
            "kind": "text",
            "maxLength": 64
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Database",
          "labelKey": "systemInfoDatabase",
          "kind": "identifier"
        },
        {
          "field": "LockDatabase",
          "labelKey": "mappingColumnLockDatabase",
          "kind": "identifier"
        },
        {
          "field": "Collation",
          "labelKey": "mappingColumnCollation",
          "kind": "text"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "globalMappingListEmptyAgent"
    },
    "toolIdentifier": "osmgmt.globalmappings",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.Home",
    "route": "",
    "area": "home",
    "labelKey": "navAreaHome",
    "sideBarPosition": 1,
    "archetype": "home",
    "built": true,
    "refreshes": true,
    "refreshRates": [
      5,
      10,
      30,
      60
    ],
    "refreshDefault": 10,
    "privileges": [],
    "entityType": "",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "context": {
      "fields": [
        "cacheEfficiency",
        "globalReferencesPerSecond",
        "globalUpdatesPerSecond",
        "diskReadsPerSecond",
        "diskWritesPerSecond"
      ],
      "secretFields": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "emptyStateKey": "",
    "commandAliases": [
      "home",
      "start"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "homeStarterPromptExplainScreen"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "homeStarterPromptExplainLog"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "homeStarterPromptChangeOneThing"
      }
    ],
    "classicPage": "%CSP.Portal.Home",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "shell.home",
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.JournalFileDatabaseList",
    "route": "os-management/journals/databases",
    "area": "os-management",
    "labelKey": "journalFileDatabaseListLabel",
    "sideBarPosition": 0,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "journal-file-database",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "os-management/journals",
    "id": {
      "kind": "composite",
      "parts": [
        "SFN"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "SFN",
        "DatabasePathOrAlias"
      ],
      "secretFields": []
    },
    "emptyStateKey": "journalFileDatabaseListEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "journalFileDatabaseListPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "journalFileDatabaseListPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "journalFileDatabaseListPrompt3"
      }
    ],
    "classicPage": "%cspapp.op.utilsysjournalsummary",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Journal.File",
        "type": "GET",
        "rows": "Databases"
      },
      "fields": [
        "SFN",
        "DatabasePathOrAlias"
      ],
      "filter": [
        "DatabasePathOrAlias"
      ],
      "sort": {
        "fields": [
          "SFN",
          "DatabasePathOrAlias"
        ],
        "default": "SFN",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "file",
            "labelKey": "tableColumnName",
            "kind": "text",
            "maxLength": 1024
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "DatabasePathOrAlias",
          "labelKey": "systemInfoDatabase",
          "kind": "name"
        },
        {
          "field": "SFN",
          "labelKey": "journalColumnSfn",
          "kind": "number"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "osmgmt.journalfiledatabases",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.JournalFileDetails",
    "route": "os-management/journals/details",
    "area": "os-management",
    "labelKey": "journalFileDetailsLabel",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "journal-file",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "os-management/journals",
    "id": {
      "kind": "composite",
      "parts": [
        "Name"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Name",
        "CreationTime",
        "FileCount",
        "MaxSize",
        "FileGUID",
        "FirstRecordAddress",
        "LastRecordAddress",
        "End",
        "EncryptionKeyID",
        "MinTransFileCount",
        "MinTransFileIndex",
        "ClusterStartTime",
        "PrevFile.File",
        "NextFile.File"
      ],
      "secretFields": []
    },
    "emptyStateKey": "journalFileDetailsGone",
    "commandAliases": [
      "journal file details"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "journalFileDetailsPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "journalFileDetailsPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "journalFileDetailsPrompt3"
      }
    ],
    "classicPage": "%cspapp.op.utilsysjournalsummary",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Journal.File",
        "type": "GET"
      },
      "fields": [
        "Name",
        "CreationTime",
        "FileCount",
        "MaxSize",
        "FileGUID",
        "FirstRecordAddress",
        "LastRecordAddress",
        "End",
        "EncryptionKeyID",
        "MinTransFileCount",
        "MinTransFileIndex",
        "ClusterStartTime",
        "PrevFile.File",
        "NextFile.File"
      ],
      "filter": [
        "Name",
        "CreationTime",
        "FileGUID",
        "EncryptionKeyID",
        "PrevFile.File",
        "NextFile.File"
      ],
      "sort": {
        "fields": [
          "Name",
          "CreationTime"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "file",
            "labelKey": "tableColumnName",
            "kind": "text",
            "maxLength": 1024
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "CreationTime",
          "labelKey": "journalColumnCreated",
          "kind": "text"
        },
        {
          "field": "FileGUID",
          "labelKey": "journalDetailsGuid",
          "kind": "identifier"
        },
        {
          "field": "FileCount",
          "labelKey": "journalDetailsFileCount",
          "kind": "number"
        },
        {
          "field": "MaxSize",
          "labelKey": "databaseColumnMaxSize",
          "kind": "number"
        },
        {
          "field": "FirstRecordAddress",
          "labelKey": "journalDetailsFirstRecord",
          "kind": "number"
        },
        {
          "field": "LastRecordAddress",
          "labelKey": "journalDetailsLastRecord",
          "kind": "number"
        },
        {
          "field": "End",
          "labelKey": "journalDetailsEnd",
          "kind": "number"
        },
        {
          "field": "EncryptionKeyID",
          "labelKey": "journalDetailsEncryption",
          "kind": "identifier",
          "emptyKey": "journalDetailsNotEncrypted"
        },
        {
          "field": "MinTransFileCount",
          "labelKey": "journalDetailsMinTransCount",
          "kind": "number"
        },
        {
          "field": "MinTransFileIndex",
          "labelKey": "journalDetailsMinTransIndex",
          "kind": "number"
        },
        {
          "field": "ClusterStartTime",
          "labelKey": "journalDetailsClusterStart",
          "kind": "text"
        },
        {
          "field": "PrevFile.File",
          "labelKey": "journalDetailsPrevious",
          "kind": "identifier"
        },
        {
          "field": "NextFile.File",
          "labelKey": "journalDetailsNext",
          "kind": "identifier"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "osmgmt.journalfile",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.JournalList",
    "route": "os-management/journals",
    "area": "os-management",
    "labelKey": "journalListLabel",
    "sideBarPosition": 13,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "journal-file",
    "entityLabelKey": "aboutJournalFile",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "composite",
      "parts": [
        "Name"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "switchfile",
        "selfProtection": ""
      },
      {
        "id": "switchdirectory",
        "selfProtection": ""
      },
      {
        "id": "integrity",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Name",
        "Size",
        "CreationTime",
        "Reason",
        "DataSize"
      ],
      "secretFields": []
    },
    "emptyStateKey": "journalListEmpty",
    "commandAliases": [
      "journals",
      "journal files"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "journalListPrompt1"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "journalListPrompt2"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "journalListPrompt3"
      }
    ],
    "classicPage": "%cspapp.op.utilsysjournals",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Journal.File",
        "type": "LIST"
      },
      "fields": [
        "Name",
        "Size",
        "CreationTime",
        "Reason",
        "DataSize"
      ],
      "filter": [
        "Name",
        "CreationTime",
        "Reason"
      ],
      "sort": {
        "fields": [
          "Name",
          "Size",
          "CreationTime",
          "Reason",
          "DataSize"
        ],
        "default": "CreationTime",
        "direction": "desc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "CreationTime",
          "labelKey": "journalColumnCreated",
          "kind": "text"
        },
        {
          "field": "Size",
          "labelKey": "databaseColumnSize",
          "kind": "number"
        },
        {
          "field": "DataSize",
          "labelKey": "journalColumnDataSize",
          "kind": "number"
        },
        {
          "field": "Reason",
          "labelKey": "agentSwitchesFieldReason",
          "kind": "text"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "journalListEmptyAgent"
    },
    "toolIdentifier": "osmgmt.journals",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": []
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.JournalRecordList",
    "route": "os-management/journal-records",
    "area": "os-management",
    "labelKey": "journalRecordListLabel",
    "sideBarPosition": 0,
    "archetype": "list (server criteria)",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "journal-record",
    "entityLabelKey": "aboutJournalRecord",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "composite",
      "parts": [
        "Address"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Address",
        "TimeStamp",
        "ProcessID",
        "TypeName",
        "ExtTypeName",
        "InTransaction",
        "GlobalNode",
        "DatabaseName"
      ],
      "secretFields": []
    },
    "emptyStateKey": "journalRecordListEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "journalRecordListPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "journalRecordListPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "journalRecordListPrompt3"
      }
    ],
    "classicPage": "%cspapp.op.utilsysjournal",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Journal.Record",
        "type": "LIST"
      },
      "fields": [
        "Address",
        "TimeStamp",
        "ProcessID",
        "TypeName",
        "ExtTypeName",
        "InTransaction",
        "GlobalNode",
        "DatabaseName"
      ],
      "filter": [
        "GlobalNode",
        "DatabaseName",
        "TypeName"
      ],
      "sort": {
        "fields": [
          "Address",
          "TimeStamp",
          "ProcessID",
          "TypeName",
          "ExtTypeName",
          "InTransaction",
          "GlobalNode",
          "DatabaseName"
        ],
        "default": "Address",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "file",
            "labelKey": "aboutJournalFile",
            "kind": "text",
            "maxLength": 1024,
            "hint": "The journal file to read, spelled as osmgmt.journals.read answers its Name; omit it to read the current file."
          },
          {
            "param": "offset",
            "labelKey": "journalRecordOffset",
            "kind": "text",
            "maxLength": 20,
            "vendorParam": "initialOffset",
            "hint": "A whole-number record address to start from, that record included; to continue after a page, send the page's highest Address plus 1, or in order 1 its lowest Address minus 1."
          },
          {
            "param": "order",
            "labelKey": "explorerSqlColumnOrder",
            "kind": "choice",
            "maxLength": 1,
            "options": [
              "0",
              "1"
            ],
            "default": "0",
            "vendorParam": "reverse",
            "hint": "0 lists records in file order from the offset or the file's start, and 1 in reverse from the offset or the file's end; with 1, also send direction desc."
          },
          {
            "param": "column",
            "labelKey": "explorerSqlColumnNumber",
            "kind": "choice",
            "maxLength": 18,
            "options": [
              "TimeStamp",
              "ProcessID",
              "TypeName",
              "ExtTypeName",
              "InTransaction",
              "GlobalNode",
              "DatabaseName",
              "MirrorDatabaseName"
            ],
            "default": "GlobalNode",
            "vendorParam": "matchColumnName",
            "hint": "The record column the value is compared with, compared only when a value is given."
          },
          {
            "param": "operator",
            "labelKey": "journalRecordComparison",
            "kind": "choice",
            "maxLength": 3,
            "options": [
              "=",
              "'=",
              "]]",
              "']]",
              "[",
              "'["
            ],
            "default": "[",
            "vendorParam": "matchOperator",
            "hint": "How the column is compared with the value: = equals, '= does not equal, ]] sorts after, ']] does not sort after, [ contains, '[ does not contain."
          },
          {
            "param": "value",
            "labelKey": "errorLogColumnValue",
            "kind": "text",
            "maxLength": 200,
            "vendorParam": "matchValue",
            "hint": "The text the column is compared with; omit it to list every record unfiltered. InTransaction reads 0 outside a transaction, not false."
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Address",
          "labelKey": "journalRecordOffset",
          "kind": "name"
        },
        {
          "field": "TimeStamp",
          "labelKey": "auditColumnTime",
          "kind": "text"
        },
        {
          "field": "ProcessID",
          "labelKey": "proposalEntityProcess",
          "kind": "identifier"
        },
        {
          "field": "TypeName",
          "labelKey": "tableColumnType",
          "kind": "text"
        },
        {
          "field": "ExtTypeName",
          "labelKey": "journalRecordExtendedType",
          "kind": "text"
        },
        {
          "field": "InTransaction",
          "labelKey": "processDetailsInTransaction",
          "kind": "status"
        },
        {
          "field": "GlobalNode",
          "labelKey": "journalRecordGlobalNode",
          "kind": "text"
        },
        {
          "field": "DatabaseName",
          "labelKey": "systemInfoDatabase",
          "kind": "identifier"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "osmgmt.journalrecords",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": []
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.JournalSettings",
    "route": "os-management/journal-settings",
    "area": "os-management",
    "labelKey": "journalSettingsLabel",
    "sideBarPosition": 14,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%Admin_Journal",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_Journal",
        "permission": "USE"
      }
    ],
    "entityType": "journal-settings",
    "entityLabelKey": "journalSettingsLabel",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "CurrentDirectory",
        "AlternateDirectory",
        "FileSizeLimit",
        "JournalFilePrefix",
        "ArchiveName",
        "PurgeArchived",
        "DaysBeforePurge",
        "BackupsBeforePurge",
        "FreezeOnError",
        "JournalcspSession",
        "CompressFiles",
        "wijdir",
        "targwijsz"
      ],
      "secretFields": []
    },
    "emptyStateKey": "",
    "commandAliases": [
      "journal settings"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "journalSettingsPrompt1"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "journalSettingsPrompt2"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "journalSettingsPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Journal",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Journal.Settings",
        "type": "GET"
      },
      "fields": [
        "CurrentDirectory",
        "AlternateDirectory",
        "FileSizeLimit",
        "JournalFilePrefix",
        "ArchiveName",
        "PurgeArchived",
        "DaysBeforePurge",
        "BackupsBeforePurge",
        "FreezeOnError",
        "JournalcspSession",
        "CompressFiles",
        "wijdir",
        "targwijsz"
      ],
      "filter": [
        "CurrentDirectory"
      ],
      "sort": {
        "fields": [
          "CurrentDirectory"
        ],
        "default": "CurrentDirectory",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "toolIdentifier": "osmgmt.journalsettings",
    "refreshDefault": 0,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": []
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LanguageServerActivity",
    "route": "os-management/language-servers/activity",
    "area": "os-management",
    "labelKey": "languageServerActivityLabel",
    "sideBarPosition": 0,
    "archetype": "log-viewer",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_ExternalLanguageServerEdit",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_ExternalLanguageServerEdit",
        "permission": "USE"
      }
    ],
    "entityType": "log-entry",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "os-management/language-servers",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "ID",
        "DateTime",
        "RecordType",
        "Job",
        "Text"
      ],
      "secretFields": []
    },
    "emptyStateKey": "logViewerEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "languageServerActivityPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "languageServerActivityPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "languageServerActivityPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.ExternalLanguageServerActivities",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "LanguageServer",
        "type": "ACTIVITY",
        "rows": "Activity"
      },
      "fields": [
        "ID",
        "DateTime",
        "RecordType",
        "Job",
        "Text"
      ],
      "filter": [
        "DateTime",
        "RecordType",
        "Text"
      ],
      "sort": {
        "fields": [
          "ID"
        ],
        "default": "ID",
        "direction": "desc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "name",
            "labelKey": "tableColumnName",
            "kind": "text",
            "maxLength": 50
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "DateTime",
          "labelKey": "auditColumnTime",
          "kind": "name"
        },
        {
          "field": "RecordType",
          "labelKey": "logViewerColumnSeverity",
          "kind": "status"
        },
        {
          "field": "Job",
          "labelKey": "processColumnPid",
          "kind": "number"
        },
        {
          "field": "Text",
          "labelKey": "logViewerColumnMessage",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "osmgmt.languageserveractivity",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LanguageServerForm",
    "route": "os-management/language-servers/edit",
    "area": "os-management",
    "labelKey": "languageServerFormLabel",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_ExternalLanguageServerEdit",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_ExternalLanguageServerEdit",
        "permission": "USE"
      }
    ],
    "entityType": "language-server",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "languageServerFormPrompt1"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "languageServerFormPrompt2"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "languageServerFormPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.ExternalLanguageServer",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "osmgmt.languageserverform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LanguageServerList",
    "route": "os-management/language-servers",
    "area": "os-management",
    "labelKey": "languageServersLabel",
    "sideBarPosition": 10,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_ExternalLanguageServerEdit",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_ExternalLanguageServerEdit",
        "permission": "USE"
      }
    ],
    "entityType": "language-server",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "start",
        "selfProtection": ""
      },
      {
        "id": "stop",
        "selfProtection": ""
      },
      {
        "id": "delete",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Name",
        "Type",
        "Port",
        "CurrentlyRunning"
      ],
      "secretFields": []
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "languageServerListEmpty",
    "commandAliases": [
      "language servers",
      "gateways",
      "external servers"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "languageServerListPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "languageServerListPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "languageServerListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.ExternalLanguageServers",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "LanguageServer",
        "type": "LIST",
        "rowGet": {
          "key": "Name",
          "param": "name",
          "type": "ACTIVITY",
          "fields": [
            "CurrentlyRunning"
          ],
          "derived": []
        }
      },
      "fields": [
        "Name",
        "Type",
        "Port",
        "CurrentlyRunning"
      ],
      "filter": [
        "Name",
        "Type"
      ],
      "sort": {
        "fields": [
          "Name"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Type",
          "labelKey": "tableColumnType",
          "kind": "text"
        },
        {
          "field": "Port",
          "labelKey": "sslTestPort",
          "kind": "number"
        },
        {
          "field": "CurrentlyRunning",
          "labelKey": "languageServerColumnRunning",
          "kind": "status"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "languageServerListEmptyAgent"
    },
    "toolIdentifier": "osmgmt.languageservers",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LdapConfigForm",
    "route": "security/ldap/edit",
    "area": "security",
    "labelKey": "ldapFormLabel",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "ldap-configuration",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": [
        "LDAPSearchPassword"
      ]
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "ldapPromptEnabled"
      },
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "ldapPromptServers"
      },
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "ldapPromptUsers"
      }
    ],
    "classicPage": "%CSP.UI.Portal.LDAP",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "security.ldapform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LdapConfigList",
    "route": "security/ldap",
    "area": "security",
    "labelKey": "ldapListLabel",
    "sideBarPosition": 3,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "ldap-configuration",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "delete",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Name",
        "Enabled",
        "Description",
        "LDAPCACertFile",
        "LDAPFlags"
      ],
      "secretFields": []
    },
    "secretArguments": [
      "LDAPSearchPassword"
    ],
    "emptyStateKey": "ldapListEmpty",
    "commandAliases": [
      "kerberos"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "ldapConfigListPrompt1"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "ldapConfigListPrompt2"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "ldapConfigListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.LDAPs",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Security.LDAP",
        "type": "LIST",
        "rowGet": {
          "key": "Name",
          "param": "name",
          "fields": [
            "LDAPFlags"
          ],
          "derived": [
            {
              "field": "Enabled",
              "rule": "bit64",
              "from": "LDAPFlags"
            }
          ]
        }
      },
      "fields": [
        "Name",
        "Enabled",
        "Description",
        "LDAPCACertFile",
        "LDAPFlags"
      ],
      "filter": [
        "Name",
        "Description"
      ],
      "sort": {
        "fields": [
          "Name",
          "Description"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Enabled",
          "labelKey": "tableColumnEnabled",
          "kind": "status"
        },
        {
          "field": "Description",
          "labelKey": "tableColumnDescription",
          "kind": "text"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "ldapListEmptyAgent"
    },
    "toolIdentifier": "security.ldap",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LicenseDistributedTab",
    "route": "os-management/license-usage/distributed",
    "area": "os-management",
    "labelKey": "licenseUsageDistributed",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "UserId",
        "LicenseUnits",
        "Connections",
        "ServerIP",
        "Instance"
      ],
      "secretFields": []
    },
    "emptyStateKey": "licenseUsageDistributedEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "licenseUsagePrompt1"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "licenseUsagePrompt2"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "licenseUsagePrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.LicenseUsage",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Monitor",
        "type": "LICENSEUSAGE",
        "rows": "ConnectionList"
      },
      "fields": [
        "UserId",
        "LicenseUnits",
        "Connections",
        "ServerIP",
        "Instance"
      ],
      "filter": [
        "UserId",
        "ServerIP"
      ],
      "sort": {
        "fields": [
          "UserId",
          "LicenseUnits",
          "Connections",
          "ServerIP",
          "Instance"
        ],
        "default": "UserId",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "UserId",
          "labelKey": "licenseUsageUserId",
          "kind": "name"
        },
        {
          "field": "LicenseUnits",
          "labelKey": "licenseUsageLicenseUnits",
          "kind": "number"
        },
        {
          "field": "Connections",
          "labelKey": "sslPromptGroupConnections",
          "kind": "number"
        },
        {
          "field": "ServerIP",
          "labelKey": "licenseUsageServerIp",
          "kind": "identifier"
        },
        {
          "field": "Instance",
          "labelKey": "statusSegmentInstance",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "os-management/license-usage",
      "position": 4,
      "labelKey": "licenseUsageDistributed"
    },
    "toolIdentifier": "osmgmt.licensedistributed",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LicenseKey",
    "route": "os-management/license-key",
    "area": "os-management",
    "labelKey": "licenseKeyLabel",
    "sideBarPosition": 15,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "license-key",
    "entityLabelKey": "licenseKeyLabel",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "activate",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "activate",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "LicenseCapacity",
        "CustomerName",
        "OrderNumber",
        "Product",
        "LicenseType",
        "Server",
        "Platform",
        "LicenseUnits",
        "CoresLicensed",
        "CoresEnforced",
        "ExpirationDate",
        "ExtendedFeaturesList",
        "AuthorizedApplications"
      ],
      "secretFields": [
        "AuthorizationKey"
      ]
    },
    "secretArguments": [
      "Key"
    ],
    "emptyStateKey": "licenseKeyEmpty",
    "commandAliases": [
      "license key",
      "activate license key"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "licenseKeyPrompt1"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "licenseKeyPrompt2"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "licenseKeyPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.License.Key",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "License.Key",
        "type": "GET"
      },
      "fields": [
        "LicenseCapacity",
        "CustomerName",
        "OrderNumber",
        "AuthorizationKey",
        "Product",
        "LicenseType",
        "Server",
        "Platform",
        "LicenseUnits",
        "CoresLicensed",
        "CoresEnforced",
        "ExpirationDate",
        "ExtendedFeaturesList",
        "AuthorizedApplications"
      ],
      "filter": [
        "CustomerName"
      ],
      "sort": {
        "fields": [
          "CustomerName"
        ],
        "default": "CustomerName",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "CustomerName",
          "labelKey": "licenseKeyCustomerName",
          "kind": "name"
        },
        {
          "field": "LicenseCapacity",
          "labelKey": "licenseKeyLicenseCapacity",
          "kind": "text"
        },
        {
          "field": "OrderNumber",
          "labelKey": "licenseKeyOrderNumber",
          "kind": "number"
        },
        {
          "field": "ExpirationDate",
          "labelKey": "licenseKeyExpirationDate",
          "kind": "text"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "licenseKeyEmptyAgent"
    },
    "toolIdentifier": "osmgmt.licensekey",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "fingerprintExcludes": []
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LicenseProcessTab",
    "route": "os-management/license-usage/processes",
    "area": "os-management",
    "labelKey": "licenseUsageByProcess",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "PID",
        "Process",
        "LID",
        "Type",
        "Con",
        "Active",
        "CSPCon",
        "LU",
        "Grace"
      ],
      "secretFields": []
    },
    "emptyStateKey": "licenseUsageProcessesEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "licenseUsagePrompt1"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "licenseUsagePrompt2"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "licenseUsagePrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.LicenseUsage",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Monitor",
        "type": "LICENSEUSAGE",
        "rows": "UsageByProcess"
      },
      "fields": [
        "PID",
        "Process",
        "LID",
        "Type",
        "Con",
        "Active",
        "CSPCon",
        "LU",
        "Grace"
      ],
      "filter": [
        "Process",
        "LID",
        "Type"
      ],
      "sort": {
        "fields": [
          "PID",
          "Process",
          "LID",
          "Type",
          "Con",
          "Active",
          "CSPCon",
          "LU",
          "Grace"
        ],
        "default": "PID",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "PID",
          "labelKey": "processColumnPid",
          "kind": "name"
        },
        {
          "field": "Process",
          "labelKey": "licenseUsageLoginId",
          "kind": "text"
        },
        {
          "field": "LID",
          "labelKey": "licenseUsageUserId",
          "kind": "text"
        },
        {
          "field": "Type",
          "labelKey": "tableColumnType",
          "kind": "text"
        },
        {
          "field": "Con",
          "labelKey": "sslPromptGroupConnections",
          "kind": "number"
        },
        {
          "field": "Active",
          "labelKey": "licenseUsageActiveTime",
          "kind": "number"
        },
        {
          "field": "CSPCon",
          "labelKey": "webSessionListLabel",
          "kind": "number"
        },
        {
          "field": "LU",
          "labelKey": "licenseUsageUnits",
          "kind": "number"
        },
        {
          "field": "Grace",
          "labelKey": "licenseUsageGraceTime",
          "kind": "number"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "os-management/license-usage",
      "position": 2,
      "labelKey": "licenseUsageByProcess"
    },
    "toolIdentifier": "osmgmt.licenseprocesses",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LicenseServerForm",
    "route": "os-management/license-servers/edit",
    "area": "os-management",
    "labelKey": "aboutLicenseServer",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "license-server",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "licenseServerFormPrompt1"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "licenseServerFormPrompt2"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "licenseServerFormPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.LicenseServers",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "osmgmt.licenseserverform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LicenseServerList",
    "route": "os-management/license-servers",
    "area": "os-management",
    "labelKey": "licenseServerListLabel",
    "sideBarPosition": 16,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "license-server",
    "entityLabelKey": "aboutLicenseServer",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "delete",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Name",
        "Address",
        "Port",
        "KeyDirectory"
      ],
      "secretFields": []
    },
    "emptyStateKey": "licenseServerListEmpty",
    "commandAliases": [
      "license servers",
      "create license server"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "licenseServerListPrompt1"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "licenseServerListPrompt2"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "licenseServerListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.LicenseServers",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "License.Server",
        "type": "LIST"
      },
      "fields": [
        "Name",
        "Address",
        "Port",
        "KeyDirectory"
      ],
      "filter": [
        "Name",
        "Address",
        "Port",
        "KeyDirectory"
      ],
      "sort": {
        "fields": [
          "Name",
          "Address",
          "Port",
          "KeyDirectory"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Address",
          "labelKey": "languageServerFieldAddress",
          "kind": "identifier"
        },
        {
          "field": "Port",
          "labelKey": "sslTestPort",
          "kind": "number"
        },
        {
          "field": "KeyDirectory",
          "labelKey": "licenseServerKeyDirectory",
          "kind": "identifier"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "licenseServerListEmptyAgent"
    },
    "toolIdentifier": "osmgmt.licenseservers",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": []
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LicenseSummaryTab",
    "route": "os-management/license-usage",
    "area": "os-management",
    "labelKey": "licenseUsageLabel",
    "sideBarPosition": 8,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "LicenseUnitUse",
        "Local",
        "Distributed"
      ],
      "secretFields": []
    },
    "emptyStateKey": "licenseUsageSummaryEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "licenseUsagePrompt1"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "licenseUsagePrompt2"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "licenseUsagePrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.LicenseUsage",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Monitor",
        "type": "LICENSEUSAGE",
        "rows": "Summary"
      },
      "fields": [
        "LicenseUnitUse",
        "Local",
        "Distributed"
      ],
      "filter": [],
      "sort": {
        "fields": [
          "LicenseUnitUse",
          "Local",
          "Distributed"
        ],
        "default": "LicenseUnitUse",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "LicenseUnitUse",
          "labelKey": "licenseUsageUnitUse",
          "kind": "name"
        },
        {
          "field": "Local",
          "labelKey": "licenseUsageLocal",
          "kind": "text"
        },
        {
          "field": "Distributed",
          "labelKey": "licenseUsageDistributed",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "os-management/license-usage",
      "position": 1,
      "labelKey": "openApiColumnSummary"
    },
    "toolIdentifier": "osmgmt.licensesummary",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LicenseUserTab",
    "route": "os-management/license-usage/users",
    "area": "os-management",
    "labelKey": "licenseUsageByUser",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "UserId",
        "Type",
        "Connects",
        "MaxCon",
        "CSPCon",
        "LU",
        "Active",
        "Grace"
      ],
      "secretFields": []
    },
    "emptyStateKey": "licenseUsageUsersEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "licenseUsagePrompt1"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "licenseUsagePrompt2"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "licenseUsagePrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.LicenseUsage",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Monitor",
        "type": "LICENSEUSAGE",
        "rows": "UsageByUser"
      },
      "fields": [
        "UserId",
        "Type",
        "Connects",
        "MaxCon",
        "CSPCon",
        "LU",
        "Active",
        "Grace"
      ],
      "filter": [
        "UserId",
        "Type"
      ],
      "sort": {
        "fields": [
          "UserId",
          "Type",
          "Connects",
          "MaxCon",
          "CSPCon",
          "LU",
          "Active",
          "Grace"
        ],
        "default": "UserId",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "UserId",
          "labelKey": "licenseUsageUserId",
          "kind": "name"
        },
        {
          "field": "Type",
          "labelKey": "tableColumnType",
          "kind": "text"
        },
        {
          "field": "Connects",
          "labelKey": "sslPromptGroupConnections",
          "kind": "number"
        },
        {
          "field": "MaxCon",
          "labelKey": "licenseUsageMaxConnections",
          "kind": "number"
        },
        {
          "field": "CSPCon",
          "labelKey": "webSessionListLabel",
          "kind": "number"
        },
        {
          "field": "LU",
          "labelKey": "licenseUsageUnits",
          "kind": "number"
        },
        {
          "field": "Active",
          "labelKey": "licenseUsageActiveTime",
          "kind": "number"
        },
        {
          "field": "Grace",
          "labelKey": "licenseUsageGraceTime",
          "kind": "number"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "os-management/license-usage",
      "position": 3,
      "labelKey": "licenseUsageByUser"
    },
    "toolIdentifier": "osmgmt.licenseusers",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LocalDatabaseForm",
    "route": "os-management/local-databases/edit",
    "area": "os-management",
    "labelKey": "systemInfoDatabase",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "database-configuration",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "localDatabaseFormPrompt1"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "databaseDetailsPrompt2"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "localDatabaseFormPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Database",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "osmgmt.localdatabaseform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LocalDatabaseList",
    "route": "os-management/local-databases",
    "area": "os-management",
    "labelKey": "localDatabaseListLabel",
    "sideBarPosition": 11,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "database-configuration",
    "secondaryEntityTypes": [
      "database"
    ],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "delete",
        "selfProtection": ""
      },
      {
        "id": "expand",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Name",
        "Directory",
        "Status"
      ],
      "secretFields": []
    },
    "emptyStateKey": "localDatabaseListEmpty",
    "commandAliases": [
      "local databases",
      "configure database",
      "create database"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "localDatabaseListPrompt1"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "localDatabaseListPrompt2"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "localDatabaseListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Databases",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Database.ConfigCRUD",
        "type": "LIST",
        "query": {
          "localOnly": "1"
        }
      },
      "fields": [
        "Name",
        "Directory",
        "Status"
      ],
      "filter": [
        "Name",
        "Directory",
        "Status"
      ],
      "sort": {
        "fields": [
          "Name",
          "Directory",
          "Status"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Directory",
          "labelKey": "lockColumnDirectory",
          "kind": "identifier"
        },
        {
          "field": "Status",
          "labelKey": "taskHistoryColumnStatus",
          "kind": "text"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "localDatabaseListEmptyAgent"
    },
    "toolIdentifier": "osmgmt.localdatabases",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LockList",
    "route": "os-management/locks",
    "area": "os-management",
    "labelKey": "lockListLabel",
    "sideBarPosition": 2,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "lock",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "composite",
      "parts": [
        "DeleteID"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "remove",
        "selfProtection": ""
      },
      {
        "id": "removeprocess",
        "selfProtection": ""
      },
      {
        "id": "removeclient",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Pid",
        "OSUserName",
        "RoutineInfo",
        "ModeCount",
        "Reference",
        "Directory",
        "System",
        "DeleteID",
        "RemoteOwner"
      ],
      "secretFields": []
    },
    "emptyStateKey": "lockListEmpty",
    "commandAliases": [
      "locks",
      "lock table"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "lockListPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "lockListPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "lockListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.LocksView",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Lock",
        "type": "LIST"
      },
      "fields": [
        "Pid",
        "OSUserName",
        "RoutineInfo",
        "ModeCount",
        "Reference",
        "Directory",
        "System",
        "DeleteID",
        "RemoteOwner"
      ],
      "filter": [
        "Pid",
        "OSUserName",
        "RoutineInfo",
        "ModeCount",
        "Reference",
        "Directory",
        "System"
      ],
      "sort": {
        "fields": [
          "Pid",
          "OSUserName",
          "RoutineInfo",
          "ModeCount",
          "Reference",
          "Directory",
          "System"
        ],
        "default": "Pid",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Pid",
          "labelKey": "processColumnPid",
          "kind": "name"
        },
        {
          "field": "OSUserName",
          "labelKey": "processColumnUser",
          "kind": "text"
        },
        {
          "field": "RoutineInfo",
          "labelKey": "processColumnRoutine",
          "kind": "identifier"
        },
        {
          "field": "ModeCount",
          "labelKey": "lockColumnMode",
          "kind": "text"
        },
        {
          "field": "Reference",
          "labelKey": "lockColumnReference",
          "kind": "identifier"
        },
        {
          "field": "Directory",
          "labelKey": "lockColumnDirectory",
          "kind": "identifier"
        },
        {
          "field": "System",
          "labelKey": "lockColumnSystem",
          "kind": "text",
          "emptyKey": "lockSystemLocal"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "lockListEmptyAgent"
    },
    "rowTarget": {
      "route": "os-management/processes/details",
      "field": "Pid",
      "unless": "RemoteOwner"
    },
    "toolIdentifier": "osmgmt.locks",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LogAlertViewer",
    "route": "logs/alerts",
    "area": "logs",
    "labelKey": "alertLogListLabel",
    "sideBarPosition": 1,
    "archetype": "log-viewer",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      }
    ],
    "entityType": "log-entry",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "time",
        "severity",
        "text"
      ],
      "secretFields": []
    },
    "emptyStateKey": "logViewerEmpty",
    "commandAliases": [
      "alerts",
      "alerts.log"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logAlertViewerPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logAlertViewerPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logAlertViewerPrompt3"
      }
    ],
    "classicPage": "%cspapp.op.utilsysconsolelog",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "logsource",
        "endpoint": "alerts",
        "type": "LIST"
      },
      "fields": [
        "time",
        "severity",
        "text"
      ],
      "filter": [
        "time",
        "severity",
        "text"
      ],
      "sort": {
        "fields": [
          "time",
          "severity"
        ],
        "default": "time",
        "direction": "desc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "time",
          "labelKey": "auditColumnTime",
          "kind": "name"
        },
        {
          "field": "severity",
          "labelKey": "logViewerColumnSeverity",
          "kind": "status"
        },
        {
          "field": "text",
          "labelKey": "logViewerColumnMessage",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "logs.alerts",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LogAnalyticsViewer",
    "route": "logs/analytics",
    "area": "logs",
    "labelKey": "analyticsLogListLabel",
    "sideBarPosition": 10,
    "archetype": "log-viewer",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%DeepSee_Portal",
        "permission": "USE"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%DeepSee_Portal",
        "permission": "USE"
      }
    ],
    "entityType": "log-entry",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "time",
        "severity",
        "text"
      ],
      "secretFields": []
    },
    "emptyStateKey": "logViewerEmpty",
    "commandAliases": [
      "analytics",
      "deepsee"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logAnalyticsViewerPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logAnalyticsViewerPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logAnalyticsViewerPrompt3"
      }
    ],
    "classicPage": "%DeepSee.UI.LogViewer",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "logsource",
        "endpoint": "analytics",
        "type": "LIST"
      },
      "fields": [
        "time",
        "severity",
        "text"
      ],
      "filter": [
        "time",
        "severity",
        "text"
      ],
      "sort": {
        "fields": [
          "time",
          "severity"
        ],
        "default": "time",
        "direction": "desc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "time",
          "labelKey": "auditColumnTime",
          "kind": "name"
        },
        {
          "field": "severity",
          "labelKey": "logViewerColumnSeverity",
          "kind": "status"
        },
        {
          "field": "text",
          "labelKey": "logViewerColumnMessage",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "logs.analytics",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LogErrorList",
    "route": "logs/errors",
    "area": "logs",
    "labelKey": "errorLogListLabel",
    "sideBarPosition": 3,
    "archetype": "drill-down",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "application-error",
    "entityLabelKey": "errorLogListLabel",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "composite",
      "parts": [
        "namespace",
        "date",
        "errorNumber"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "delete",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "namespace",
        "date",
        "errorNumber",
        "time",
        "errorText",
        "routine",
        "line"
      ],
      "secretFields": []
    },
    "emptyStateKey": "errorLogEmptyInstance",
    "commandAliases": [
      "application errors"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logErrorListPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logErrorListPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logErrorListPrompt3"
      }
    ],
    "classicPage": "%cspapp.op.utilsysapperrornamespaces",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "logs.applicationerrors",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": []
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LogEventViewer",
    "route": "logs/eventlog",
    "area": "logs",
    "labelKey": "eventLogListLabel",
    "sideBarPosition": 9,
    "archetype": "log-viewer",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Ens_EventLog",
        "permission": "USE"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Ens_EventLog",
        "permission": "USE"
      }
    ],
    "entityType": "log-entry",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "time",
        "severity",
        "text"
      ],
      "secretFields": []
    },
    "emptyStateKey": "logViewerEmpty",
    "commandAliases": [
      "event log",
      "interoperability"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logEventViewerPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logEventViewerPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logEventViewerPrompt3"
      }
    ],
    "classicPage": "EnsPortal.EventLog",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "logsource",
        "endpoint": "eventlog",
        "type": "LIST"
      },
      "fields": [
        "time",
        "severity",
        "text"
      ],
      "filter": [
        "time",
        "severity",
        "text"
      ],
      "sort": {
        "fields": [
          "time",
          "severity"
        ],
        "default": "time",
        "direction": "desc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "time",
          "labelKey": "auditColumnTime",
          "kind": "name"
        },
        {
          "field": "severity",
          "labelKey": "logViewerColumnSeverity",
          "kind": "status"
        },
        {
          "field": "text",
          "labelKey": "logViewerColumnMessage",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "logs.eventlog",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LogHub",
    "route": "logs/hub",
    "area": "logs",
    "labelKey": "logHubLabel",
    "sideBarPosition": 11,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      }
    ],
    "entityType": "log-entry",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "time",
        "source",
        "severity",
        "text"
      ],
      "secretFields": []
    },
    "emptyStateKey": "logViewerEmpty",
    "commandAliases": [
      "log hub",
      "timeline",
      "all logs"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logHubPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logHubPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logHubPrompt3"
      }
    ],
    "classicPage": "",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "timeline",
        "endpoint": "logs",
        "type": "LIST"
      },
      "fields": [
        "time",
        "source",
        "severity",
        "text",
        "id"
      ],
      "filter": [
        "time",
        "source",
        "severity",
        "text"
      ],
      "sort": {
        "fields": [
          "time"
        ],
        "default": "time",
        "direction": "desc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "since",
            "labelKey": "auditCriteriaBegin",
            "kind": "datetime",
            "maxLength": 50,
            "defaultHoursAgo": 1
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "time",
          "labelKey": "auditColumnTime",
          "kind": "name"
        },
        {
          "field": "source",
          "labelKey": "auditEventFieldSource",
          "kind": "text"
        },
        {
          "field": "severity",
          "labelKey": "logViewerColumnSeverity",
          "kind": "status"
        },
        {
          "field": "text",
          "labelKey": "logViewerColumnMessage",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "logs.hub",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LogMessageViewer",
    "route": "logs/messages",
    "area": "logs",
    "labelKey": "messagesLogListLabel",
    "sideBarPosition": 2,
    "archetype": "log-viewer",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      }
    ],
    "entityType": "log-entry",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "time",
        "severity",
        "text"
      ],
      "secretFields": []
    },
    "emptyStateKey": "logViewerEmpty",
    "commandAliases": [
      "messages",
      "messages.log"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logMessageViewerPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logMessageViewerPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logMessageViewerPrompt3"
      }
    ],
    "classicPage": "%cspapp.op.utilsysconsolelog",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "logsource",
        "endpoint": "messages",
        "type": "LIST"
      },
      "fields": [
        "time",
        "severity",
        "text"
      ],
      "filter": [
        "time",
        "severity",
        "text"
      ],
      "sort": {
        "fields": [
          "time",
          "severity"
        ],
        "default": "time",
        "direction": "desc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "time",
          "labelKey": "auditColumnTime",
          "kind": "name"
        },
        {
          "field": "severity",
          "labelKey": "logViewerColumnSeverity",
          "kind": "status"
        },
        {
          "field": "text",
          "labelKey": "logViewerColumnMessage",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "logs.messages",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LogSqlDiagnosticsViewer",
    "route": "logs/sqldiagnostics",
    "area": "logs",
    "labelKey": "sqlDiagnosticsLogListLabel",
    "sideBarPosition": 8,
    "archetype": "log-viewer",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      }
    ],
    "entityType": "log-entry",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "time",
        "severity",
        "text"
      ],
      "secretFields": []
    },
    "emptyStateKey": "logViewerEmpty",
    "commandAliases": [
      "sql diagnostics",
      "load data"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logSqlDiagnosticsViewerPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logSqlDiagnosticsViewerPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logSqlDiagnosticsViewerPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.SQL.Logs",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "logsource",
        "endpoint": "sqldiagnostics",
        "type": "LIST"
      },
      "fields": [
        "time",
        "severity",
        "text"
      ],
      "filter": [
        "time",
        "severity",
        "text"
      ],
      "sort": {
        "fields": [
          "time",
          "severity"
        ],
        "default": "time",
        "direction": "desc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "time",
          "labelKey": "auditColumnTime",
          "kind": "name"
        },
        {
          "field": "severity",
          "labelKey": "logViewerColumnSeverity",
          "kind": "status"
        },
        {
          "field": "text",
          "labelKey": "logViewerColumnMessage",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "logs.sqldiagnostics",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LogSystemMonitorViewer",
    "route": "logs/systemmonitor",
    "area": "logs",
    "labelKey": "systemMonitorLogListLabel",
    "sideBarPosition": 5,
    "archetype": "log-viewer",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      }
    ],
    "entityType": "log-entry",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "time",
        "severity",
        "text"
      ],
      "secretFields": []
    },
    "emptyStateKey": "logViewerEmpty",
    "commandAliases": [
      "system monitor",
      "SystemMonitor.log"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logSystemMonitorViewerPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logSystemMonitorViewerPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logSystemMonitorViewerPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.ViewLog",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "logsource",
        "endpoint": "systemmonitor",
        "type": "LIST"
      },
      "fields": [
        "time",
        "severity",
        "text"
      ],
      "filter": [
        "time",
        "severity",
        "text"
      ],
      "sort": {
        "fields": [
          "time",
          "severity"
        ],
        "default": "time",
        "direction": "desc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "time",
          "labelKey": "auditColumnTime",
          "kind": "name"
        },
        {
          "field": "severity",
          "labelKey": "logViewerColumnSeverity",
          "kind": "status"
        },
        {
          "field": "text",
          "labelKey": "logViewerColumnMessage",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "logs.systemmonitor",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LogTaskErrorViewer",
    "route": "logs/taskerrors",
    "area": "logs",
    "labelKey": "taskErrorLogListLabel",
    "sideBarPosition": 6,
    "archetype": "log-viewer",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "log-entry",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "time",
        "severity",
        "text"
      ],
      "secretFields": []
    },
    "emptyStateKey": "logViewerEmpty",
    "commandAliases": [
      "background task errors"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logTaskErrorViewerPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logTaskErrorViewerPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logTaskErrorViewerPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.BackgroundTaskError",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "logsource",
        "endpoint": "taskerrors",
        "type": "LIST"
      },
      "fields": [
        "time",
        "severity",
        "text"
      ],
      "filter": [
        "time",
        "severity",
        "text"
      ],
      "sort": {
        "fields": [
          "time",
          "severity"
        ],
        "default": "time",
        "direction": "desc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "time",
          "labelKey": "auditColumnTime",
          "kind": "name"
        },
        {
          "field": "severity",
          "labelKey": "logViewerColumnSeverity",
          "kind": "status"
        },
        {
          "field": "text",
          "labelKey": "logViewerColumnMessage",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "logs.taskerrors",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.LogXdbcViewer",
    "route": "logs/xdbc",
    "area": "logs",
    "labelKey": "xdbcErrorLogListLabel",
    "sideBarPosition": 7,
    "archetype": "log-viewer",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      }
    ],
    "entityType": "log-entry",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "time",
        "severity",
        "text"
      ],
      "secretFields": []
    },
    "emptyStateKey": "logViewerEmpty",
    "commandAliases": [
      "xdbc",
      "odbc",
      "jdbc"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logXdbcViewerPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logXdbcViewerPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "logXdbcViewerPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.xDBCErrorNamespaces",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "logsource",
        "endpoint": "xdbc",
        "type": "LIST"
      },
      "fields": [
        "time",
        "severity",
        "text"
      ],
      "filter": [
        "time",
        "severity",
        "text"
      ],
      "sort": {
        "fields": [
          "time",
          "severity"
        ],
        "default": "time",
        "direction": "desc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "time",
          "labelKey": "auditColumnTime",
          "kind": "name"
        },
        {
          "field": "severity",
          "labelKey": "logViewerColumnSeverity",
          "kind": "status"
        },
        {
          "field": "text",
          "labelKey": "logViewerColumnMessage",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "logs.xdbc",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.NamespaceForm",
    "route": "os-management/namespaces/edit",
    "area": "os-management",
    "labelKey": "headerNamespaceLabel",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "namespace",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "namespaceFormPrompt1"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "namespaceFormPrompt2"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "namespaceFormPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.NamespaceEdit",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "osmgmt.namespaceform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.NamespaceList",
    "route": "os-management/namespaces",
    "area": "os-management",
    "labelKey": "namespaceListLabel",
    "sideBarPosition": 7,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "namespace",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "delete",
        "selfProtection": ""
      },
      {
        "id": "copy-mappings",
        "selfProtection": ""
      },
      {
        "id": "enable-interop",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Name",
        "Globals",
        "Routines",
        "TempGlobals"
      ],
      "secretFields": []
    },
    "emptyStateKey": "namespaceListEmpty",
    "commandAliases": [
      "namespaces",
      "configure namespace"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "namespaceListPrompt1"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "namespaceListPrompt2"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "namespaceListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Namespaces",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Namespace.Namespace",
        "type": "LIST"
      },
      "fields": [
        "Name",
        "Globals",
        "Routines",
        "TempGlobals"
      ],
      "filter": [
        "Name",
        "Globals",
        "Routines",
        "TempGlobals"
      ],
      "sort": {
        "fields": [
          "Name",
          "Globals",
          "Routines",
          "TempGlobals"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Globals",
          "labelKey": "namespaceColumnGlobals",
          "kind": "identifier"
        },
        {
          "field": "Routines",
          "labelKey": "namespaceColumnRoutines",
          "kind": "identifier"
        },
        {
          "field": "TempGlobals",
          "labelKey": "namespaceColumnTemp",
          "kind": "identifier"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "namespaceListEmptyAgent"
    },
    "toolIdentifier": "osmgmt.namespaces",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.OAuthClientForm",
    "route": "security/oauth/clients/edit",
    "area": "security",
    "labelKey": "oauthClientFormLabel",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_OAuth2_Client",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_OAuth2_Client",
        "permission": "USE"
      }
    ],
    "entityType": "oauth2-client-configuration",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": [
        "ClientSecret",
        "ClientPassword",
        "RegistrationAccessToken",
        "InitialAccessToken"
      ]
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthClientFormPrompt1"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthClientFormPrompt2"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthClientFormPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.OAuth2.Client.Configuration",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "security.oauthclientform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.OAuthClientTab",
    "route": "security/oauth/clients",
    "area": "security",
    "labelKey": "oauthTabClients",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_OAuth2_Client",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_OAuth2_Client",
        "permission": "USE"
      }
    ],
    "entityType": "oauth2-client-configuration",
    "secondaryEntityTypes": [
      "oauth2-server-definition"
    ],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "delete",
        "selfProtection": ""
      },
      {
        "id": "rotatekeys",
        "selfProtection": ""
      },
      {
        "id": "register",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "ApplicationName",
        "ClientType",
        "DefaultScope",
        "ServerDefinitionID",
        "IssuerEndpoint"
      ],
      "secretFields": []
    },
    "secretArguments": [
      "ClientSecret",
      "ClientPassword",
      "RegistrationAccessToken"
    ],
    "emptyStateKey": "oauthClientsEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthClientTabPrompt1"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthClientTabPrompt2"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthClientTabPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.OAuth2.Client.ConfigurationList",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Security.OAuth2.Client.ClientConfiguration",
        "type": "LIST",
        "forEach": {
          "endpoint": "Security.OAuth2.Client.ServerDefinition",
          "key": "ID",
          "param": "serverId",
          "fields": [
            {
              "field": "ServerDefinitionID",
              "from": "ID"
            },
            {
              "field": "IssuerEndpoint",
              "from": "IssuerEndpoint"
            }
          ]
        }
      },
      "fields": [
        "ApplicationName",
        "ClientType",
        "DefaultScope",
        "ServerDefinitionID",
        "IssuerEndpoint"
      ],
      "filter": [
        "ApplicationName",
        "IssuerEndpoint",
        "ClientType",
        "DefaultScope"
      ],
      "sort": {
        "fields": [
          "ApplicationName",
          "IssuerEndpoint",
          "ClientType",
          "DefaultScope"
        ],
        "default": "ApplicationName",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "ApplicationName",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "IssuerEndpoint",
          "labelKey": "x509ColumnIssuer",
          "kind": "text"
        },
        {
          "field": "ClientType",
          "labelKey": "oauthColumnClientType",
          "kind": "text"
        },
        {
          "field": "DefaultScope",
          "labelKey": "oauthColumnDefaultScope",
          "kind": "text"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "oauthClientsEmptyAgent"
    },
    "tab": {
      "group": "security/oauth",
      "position": 2,
      "labelKey": "oauthTabClients"
    },
    "toolIdentifier": "security.oauthclients",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.OAuthResourceServerForm",
    "route": "security/oauth/resource-servers/edit",
    "area": "security",
    "labelKey": "oauthClientTypeResource",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      },
      {
        "resource": "%Admin_OAuth2_Client",
        "permission": "USE"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_OAuth2_Client",
        "permission": "USE"
      }
    ],
    "entityType": "oauth2-resource-server",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": [
        "ClientSecret"
      ]
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthResourceServerFormPrompt1"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthResourceServerFormPrompt2"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthResourceServerFormPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.OAuth2.ResourceServer.Configuration",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "security.oauthresourceserverform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.OAuthResourceServerTab",
    "route": "security/oauth/resource-servers",
    "area": "security",
    "labelKey": "oauthTabResourceServers",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      },
      {
        "resource": "%Admin_OAuth2_Client",
        "permission": "USE"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_OAuth2_Client",
        "permission": "USE"
      }
    ],
    "entityType": "oauth2-resource-server",
    "secondaryEntityTypes": [
      "oauth2-server-definition"
    ],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "delete",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Name",
        "ServerDefinition"
      ],
      "secretFields": []
    },
    "secretArguments": [
      "ClientSecret"
    ],
    "emptyStateKey": "oauthResourceServersEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthResourceServerTabPrompt1"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthResourceServerTabPrompt2"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthResourceServerTabPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.OAuth2.ResourceServer.ConfigurationList",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Security.OAuth2.ResourceServer",
        "type": "LIST"
      },
      "fields": [
        "Name",
        "ServerDefinition"
      ],
      "filter": [
        "Name",
        "ServerDefinition"
      ],
      "sort": {
        "fields": [
          "Name",
          "ServerDefinition"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "ServerDefinition",
          "labelKey": "x509ColumnIssuer",
          "kind": "text"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "oauthResourceServersEmptyAgent"
    },
    "tab": {
      "group": "security/oauth",
      "position": 3,
      "labelKey": "oauthTabResourceServers"
    },
    "toolIdentifier": "security.oauthresourceservers",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.OAuthServerClientForm",
    "route": "security/oauth/server-clients/edit",
    "area": "security",
    "labelKey": "oauthRegisteredClientTitle",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_OAuth2_Registration",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_OAuth2_Registration",
        "permission": "USE"
      }
    ],
    "entityType": "oauth2-server-client",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": [
        "ClientSecret"
      ]
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthServerClientFormPrompt1"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthServerClientFormPrompt2"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthServerClientFormPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.OAuth2.Server.Client",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "security.oauthserverclientform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.OAuthServerClientTab",
    "route": "security/oauth/server-clients",
    "area": "security",
    "labelKey": "oauthTabServerClients",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_OAuth2_Registration",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_OAuth2_Registration",
        "permission": "USE"
      }
    ],
    "entityType": "oauth2-server-client",
    "secondaryEntityTypes": [
      "oauth2-server"
    ],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "composite",
      "parts": [
        "ClientId"
      ]
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "delete",
        "selfProtection": ""
      },
      {
        "id": "updatejwks",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Name",
        "ClientId",
        "ClientType",
        "RedirectURL",
        "Description"
      ],
      "secretFields": []
    },
    "secretArguments": [
      "ClientSecret"
    ],
    "emptyStateKey": "oauthServerClientsEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthServerClientTabPrompt1"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthServerClientTabPrompt2"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthServerClientTabPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.OAuth2.Server.ClientList",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Security.OAuth2.ServerClients",
        "type": "LIST"
      },
      "fields": [
        "Name",
        "ClientId",
        "ClientType",
        "RedirectURL",
        "Description"
      ],
      "filter": [
        "Name",
        "ClientId",
        "ClientType",
        "RedirectURL",
        "Description"
      ],
      "sort": {
        "fields": [
          "Name",
          "ClientId",
          "ClientType",
          "RedirectURL",
          "Description"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "ClientId",
          "labelKey": "oauthColumnClientId",
          "kind": "identifier"
        },
        {
          "field": "ClientType",
          "labelKey": "oauthColumnClientType",
          "kind": "text"
        },
        {
          "field": "RedirectURL",
          "labelKey": "oauthColumnRedirectUrls",
          "kind": "text"
        },
        {
          "field": "Description",
          "labelKey": "tableColumnDescription",
          "kind": "text"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "oauthServerClientsEmptyAgent"
    },
    "tab": {
      "group": "security/oauth",
      "position": 5,
      "labelKey": "oauthTabServerClients"
    },
    "toolIdentifier": "security.oauthserverclients",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.OAuthServerDescriptionForm",
    "route": "security/oauth/edit",
    "area": "security",
    "labelKey": "oauthServerFormLabel",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_OAuth2_Client",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_OAuth2_Client",
        "permission": "USE"
      }
    ],
    "entityType": "oauth2-server-definition",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": [
        "InitialAccessToken"
      ]
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthServerDescriptionFormPrompt1"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthServerDescriptionFormPrompt2"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthServerDescriptionFormPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.OAuth2.Client.ServerConfiguration",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "security.oauthserverdescriptionform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.OAuthServerDescriptionTab",
    "route": "security/oauth",
    "area": "security",
    "labelKey": "oauthLabel",
    "sideBarPosition": 5,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_OAuth2_Client",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_OAuth2_Client",
        "permission": "USE"
      }
    ],
    "entityType": "oauth2-server-definition",
    "secondaryEntityTypes": [
      "oauth2-client-configuration",
      "oauth2-resource-server"
    ],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "delete",
        "selfProtection": ""
      },
      {
        "id": "updatejwks",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "ID",
        "IssuerEndpoint",
        "ClientCount",
        "ResourceCount"
      ],
      "secretFields": []
    },
    "secretArguments": [
      "InitialAccessToken"
    ],
    "emptyStateKey": "oauthServerDescriptionsEmpty",
    "commandAliases": [
      "oauth"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthServerDescriptionTabPrompt1"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthServerDescriptionTabPrompt2"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthServerDescriptionTabPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.OAuth2.Client.ServerList",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Security.OAuth2.Client.ServerDefinition",
        "type": "LIST"
      },
      "fields": [
        "ID",
        "IssuerEndpoint",
        "ClientCount",
        "ResourceCount"
      ],
      "filter": [
        "IssuerEndpoint"
      ],
      "sort": {
        "fields": [
          "IssuerEndpoint",
          "ClientCount",
          "ResourceCount"
        ],
        "default": "IssuerEndpoint",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "IssuerEndpoint",
          "labelKey": "x509ColumnIssuer",
          "kind": "name"
        },
        {
          "field": "ClientCount",
          "labelKey": "oauthTabClients",
          "kind": "number"
        },
        {
          "field": "ResourceCount",
          "labelKey": "oauthTabResourceServers",
          "kind": "number"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "oauthServerDescriptionsEmptyAgent"
    },
    "tab": {
      "group": "security/oauth",
      "position": 1,
      "labelKey": "oauthTabServerDescriptions"
    },
    "toolIdentifier": "security.oauthserverdescriptions",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.OAuthServerForm",
    "route": "security/oauth/server/edit",
    "area": "security",
    "labelKey": "oauthTabServer",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_OAuth2_Server",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_OAuth2_Server",
        "permission": "USE"
      }
    ],
    "entityType": "oauth2-server",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": [
        "ServerPassword"
      ]
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthServerFormPrompt1"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthServerFormPrompt2"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthServerFormPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.OAuth2.Server.Configuration",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "security.oauthserverform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.OAuthServerTab",
    "route": "security/oauth/server",
    "area": "security",
    "labelKey": "oauthTabServer",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_OAuth2_Server",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_OAuth2_Server",
        "permission": "USE"
      }
    ],
    "entityType": "oauth2-server",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "delete",
        "selfProtection": ""
      },
      {
        "id": "rotatekeys",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "IssuerEndpoint",
        "Metadata.scopes_supported",
        "Metadata.grant_types_supported",
        "SigningAlgorithm",
        "EncryptionAlgorithm",
        "KeyAlgorithm",
        "ServerCredentials"
      ],
      "secretFields": []
    },
    "secretArguments": [
      "ServerPassword"
    ],
    "emptyStateKey": "oauthServerEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthServerTabPrompt1"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthServerTabPrompt2"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "oAuthServerTabPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.OAuth2.Server.Configuration",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Security.OAuth2.Server",
        "type": "GET"
      },
      "fields": [
        "IssuerEndpoint",
        "Metadata.scopes_supported",
        "Metadata.grant_types_supported",
        "SigningAlgorithm",
        "EncryptionAlgorithm",
        "KeyAlgorithm",
        "ServerCredentials"
      ],
      "filter": [
        "IssuerEndpoint",
        "Metadata.scopes_supported",
        "Metadata.grant_types_supported",
        "SigningAlgorithm",
        "EncryptionAlgorithm",
        "KeyAlgorithm",
        "ServerCredentials"
      ],
      "sort": {
        "fields": [
          "IssuerEndpoint",
          "Metadata.scopes_supported",
          "Metadata.grant_types_supported",
          "SigningAlgorithm",
          "EncryptionAlgorithm",
          "KeyAlgorithm",
          "ServerCredentials"
        ],
        "default": "IssuerEndpoint",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "IssuerEndpoint",
          "labelKey": "x509ColumnIssuer",
          "kind": "name"
        },
        {
          "field": "Metadata.scopes_supported",
          "labelKey": "oauthColumnScopes",
          "kind": "text"
        },
        {
          "field": "Metadata.grant_types_supported",
          "labelKey": "oauthColumnGrantTypes",
          "kind": "text"
        },
        {
          "field": "SigningAlgorithm",
          "labelKey": "oauthColumnSigningAlgorithm",
          "kind": "text"
        },
        {
          "field": "EncryptionAlgorithm",
          "labelKey": "oauthColumnEncryptionAlgorithm",
          "kind": "text"
        },
        {
          "field": "KeyAlgorithm",
          "labelKey": "oauthColumnKeyAlgorithm",
          "kind": "text"
        },
        {
          "field": "ServerCredentials",
          "labelKey": "oauthColumnServerCredentials",
          "kind": "text"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "oauthAuthServerEmptyAgent"
    },
    "tab": {
      "group": "security/oauth",
      "position": 4,
      "labelKey": "oauthTabServer"
    },
    "toolIdentifier": "security.oauthserver",
    "refreshDefault": 0,
    "banner": null,
    "rowTarget": null,
    "multiSelect": null,
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.OpenApiViewer",
    "route": "web-applications/rest-apis/document",
    "area": "web-applications",
    "labelKey": "openApiViewerLabel",
    "sideBarPosition": 0,
    "archetype": "viewer (OpenAPI)",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "rest-service",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Path",
        "Verb",
        "Summary",
        "OperationId"
      ],
      "secretFields": []
    },
    "emptyStateKey": "openApiViewerEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "openApiViewerPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "openApiViewerPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "openApiViewerPrompt3"
      }
    ],
    "classicPage": "",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "mgmnt",
        "endpoint": "Document",
        "type": "LIST"
      },
      "fields": [
        "Order",
        "Path",
        "Verb",
        "Summary",
        "OperationId",
        "Parameters",
        "Responses"
      ],
      "filter": [
        "Path",
        "Verb",
        "Summary"
      ],
      "sort": {
        "fields": [
          "Order",
          "Path",
          "Verb"
        ],
        "default": "Order",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "application",
            "labelKey": "tableColumnName",
            "kind": "text",
            "maxLength": 256
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Path",
          "labelKey": "openApiColumnPath",
          "kind": "name"
        },
        {
          "field": "Verb",
          "labelKey": "openApiColumnVerb",
          "kind": "text"
        },
        {
          "field": "Summary",
          "labelKey": "openApiColumnSummary",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "webapp.openapi",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.PackageMappingForm",
    "route": "os-management/namespaces/package-mappings/edit",
    "area": "os-management",
    "labelKey": "packageMappingFormLabel",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "package-mapping",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "composite",
      "parts": [
        "namespace",
        "Name"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "packageMappingFormPrompt1"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "packageMappingFormPrompt2"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "packageMappingFormPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Mappings.Package",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "osmgmt.packagemappingform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.PackageMappingList",
    "route": "os-management/namespaces/package-mappings",
    "area": "os-management",
    "labelKey": "packageMappingListLabel",
    "sideBarPosition": 0,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "package-mapping",
    "secondaryEntityTypes": [
      "namespace"
    ],
    "scope": "instance",
    "parentScope": "os-management/namespaces",
    "id": {
      "kind": "composite",
      "parts": [
        "namespace",
        "Name"
      ]
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "delete",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "namespace",
        "Name",
        "Database"
      ],
      "secretFields": []
    },
    "emptyStateKey": "packageMappingListEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "packageMappingListPrompt1"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "packageMappingListPrompt2"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "packageMappingListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Mappings",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Namespace.PackageMappings",
        "type": "LIST"
      },
      "fields": [
        "namespace",
        "Name",
        "Database"
      ],
      "filter": [
        "Name",
        "Database"
      ],
      "sort": {
        "fields": [
          "Name",
          "Database"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "namespace",
            "labelKey": "headerNamespaceLabel",
            "kind": "text",
            "maxLength": 64
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Database",
          "labelKey": "systemInfoDatabase",
          "kind": "identifier"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "packageMappingListEmptyAgent"
    },
    "toolIdentifier": "osmgmt.packagemappings",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ProcessDetails",
    "route": "os-management/processes/details",
    "area": "os-management",
    "labelKey": "processDetailsLabel",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": true,
    "refreshRates": [
      5,
      10,
      30,
      60
    ],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "process",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "os-management/processes",
    "id": {
      "kind": "composite",
      "parts": [
        "Pid"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "suspend",
        "selfProtection": ""
      },
      {
        "id": "resume",
        "selfProtection": ""
      },
      {
        "id": "terminate",
        "selfProtection": ""
      },
      {
        "id": "terminate-with-error",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Pid",
        "JobType",
        "ParentPid",
        "UserName",
        "LoginRoles",
        "EscalatedRoles",
        "OSUserName",
        "NameSpace",
        "Priority",
        "StartTimeUTC",
        "CPUTime",
        "CommandsExecuted",
        "GlobalReferences",
        "PrivateGlobalReferences",
        "PrivateGlobalBlockCount",
        "MemoryAllocated",
        "MemoryPeak",
        "MemoryUsed",
        "CurrentDevice",
        "OpenDevices",
        "State",
        "InTransaction",
        "Routine",
        "CurrentLineAndRoutine",
        "Location",
        "ClientNodeName",
        "ClientExecutableName",
        "ClientIPAddress"
      ],
      "secretFields": []
    },
    "emptyStateKey": "processDetailsGone",
    "commandAliases": [
      "process details"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "processDetailsPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "processDetailsPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "processDetailsPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.ProcessDetails",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Process",
        "type": "GET"
      },
      "fields": [
        "Pid",
        "JobType",
        "ParentPid",
        "UserName",
        "LoginRoles",
        "EscalatedRoles",
        "OSUserName",
        "NameSpace",
        "Priority",
        "StartTimeUTC",
        "CPUTime",
        "CommandsExecuted",
        "GlobalReferences",
        "PrivateGlobalReferences",
        "PrivateGlobalBlockCount",
        "MemoryAllocated",
        "MemoryPeak",
        "MemoryUsed",
        "CurrentDevice",
        "OpenDevices",
        "State",
        "InTransaction",
        "Routine",
        "CurrentLineAndRoutine",
        "Location",
        "ClientNodeName",
        "ClientExecutableName",
        "ClientIPAddress"
      ],
      "filter": [
        "Pid",
        "ParentPid",
        "UserName",
        "LoginRoles",
        "EscalatedRoles",
        "OSUserName",
        "NameSpace",
        "Priority",
        "StartTimeUTC",
        "CPUTime",
        "CommandsExecuted",
        "GlobalReferences",
        "PrivateGlobalReferences",
        "PrivateGlobalBlockCount",
        "MemoryAllocated",
        "MemoryPeak",
        "MemoryUsed",
        "CurrentDevice",
        "OpenDevices",
        "State",
        "InTransaction",
        "Routine",
        "CurrentLineAndRoutine",
        "Location",
        "ClientNodeName",
        "ClientExecutableName",
        "ClientIPAddress"
      ],
      "sort": {
        "fields": [
          "Pid",
          "ParentPid",
          "UserName",
          "LoginRoles",
          "EscalatedRoles",
          "OSUserName",
          "NameSpace",
          "Priority",
          "StartTimeUTC",
          "CPUTime",
          "CommandsExecuted",
          "GlobalReferences",
          "PrivateGlobalReferences",
          "PrivateGlobalBlockCount",
          "MemoryAllocated",
          "MemoryPeak",
          "MemoryUsed",
          "CurrentDevice",
          "OpenDevices",
          "State",
          "InTransaction",
          "Routine",
          "CurrentLineAndRoutine",
          "Location",
          "ClientNodeName",
          "ClientExecutableName",
          "ClientIPAddress"
        ],
        "default": "Pid",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "pid",
            "labelKey": "processColumnPid",
            "kind": "text",
            "maxLength": 10,
            "vendorParam": "id"
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Pid",
          "labelKey": "processColumnPid",
          "kind": "name"
        },
        {
          "field": "ParentPid",
          "labelKey": "processDetailsParentPid",
          "kind": "text"
        },
        {
          "field": "UserName",
          "labelKey": "processColumnUser",
          "kind": "text"
        },
        {
          "field": "LoginRoles",
          "labelKey": "processDetailsLoginRoles",
          "kind": "text"
        },
        {
          "field": "EscalatedRoles",
          "labelKey": "processDetailsEscalatedRoles",
          "kind": "text"
        },
        {
          "field": "OSUserName",
          "labelKey": "processDetailsOsUser",
          "kind": "text"
        },
        {
          "field": "NameSpace",
          "labelKey": "headerNamespaceLabel",
          "kind": "text"
        },
        {
          "field": "Priority",
          "labelKey": "taskDetailsPriority",
          "kind": "number"
        },
        {
          "field": "StartTimeUTC",
          "labelKey": "taskHistoryColumnStarted",
          "kind": "text"
        },
        {
          "field": "CPUTime",
          "labelKey": "processDetailsCpuTime",
          "kind": "number"
        },
        {
          "field": "CommandsExecuted",
          "labelKey": "processColumnCommands",
          "kind": "number"
        },
        {
          "field": "GlobalReferences",
          "labelKey": "processDetailsGlobalReferences",
          "kind": "number"
        },
        {
          "field": "PrivateGlobalReferences",
          "labelKey": "processDetailsPrivateGlobalReferences",
          "kind": "number"
        },
        {
          "field": "PrivateGlobalBlockCount",
          "labelKey": "processDetailsPrivateGlobalBlocks",
          "kind": "number"
        },
        {
          "field": "MemoryAllocated",
          "labelKey": "processDetailsMemoryLimit",
          "kind": "number"
        },
        {
          "field": "MemoryPeak",
          "labelKey": "processDetailsMemoryPeak",
          "kind": "number"
        },
        {
          "field": "MemoryUsed",
          "labelKey": "processDetailsMemoryUsed",
          "kind": "number"
        },
        {
          "field": "CurrentDevice",
          "labelKey": "processDetailsCurrentDevice",
          "kind": "text"
        },
        {
          "field": "OpenDevices",
          "labelKey": "processDetailsOpenDevices",
          "kind": "text"
        },
        {
          "field": "State",
          "labelKey": "processColumnState",
          "kind": "text"
        },
        {
          "field": "InTransaction",
          "labelKey": "processDetailsInTransaction",
          "kind": "text"
        },
        {
          "field": "Routine",
          "labelKey": "processColumnRoutine",
          "kind": "identifier"
        },
        {
          "field": "CurrentLineAndRoutine",
          "labelKey": "processDetailsSourceLocation",
          "kind": "identifier"
        },
        {
          "field": "Location",
          "labelKey": "processDetailsLocation",
          "kind": "text"
        },
        {
          "field": "ClientNodeName",
          "labelKey": "processDetailsClientName",
          "kind": "text"
        },
        {
          "field": "ClientExecutableName",
          "labelKey": "processDetailsClientExecutable",
          "kind": "text"
        },
        {
          "field": "ClientIPAddress",
          "labelKey": "processDetailsClientIpAddress",
          "kind": "text"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "processListEmptyAgent"
    },
    "toolIdentifier": "osmgmt.processdetails",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ProcessList",
    "route": "os-management/processes",
    "area": "os-management",
    "labelKey": "processListLabel",
    "sideBarPosition": 1,
    "archetype": "list",
    "built": true,
    "refreshes": true,
    "refreshRates": [
      5,
      10,
      30,
      60
    ],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "process",
    "entityLabelKey": "proposalEntityProcess",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "suspend",
        "selfProtection": ""
      },
      {
        "id": "resume",
        "selfProtection": ""
      },
      {
        "id": "terminate",
        "selfProtection": ""
      },
      {
        "id": "terminate-with-error",
        "selfProtection": ""
      },
      {
        "id": "broadcast",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Pid",
        "Username",
        "Nspace",
        "Routine",
        "State",
        "Commands",
        "Globals",
        "CanReceiveBroadcast"
      ],
      "secretFields": []
    },
    "emptyStateKey": "processListEmpty",
    "commandAliases": [
      "jobs"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "processListPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "processListPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "processListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Processes",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Process",
        "type": "LIST"
      },
      "fields": [
        "Pid",
        "Username",
        "Nspace",
        "Routine",
        "State",
        "Commands",
        "Globals",
        "CanReceiveBroadcast"
      ],
      "filter": [
        "Pid",
        "Username",
        "Nspace",
        "Routine",
        "State"
      ],
      "sort": {
        "fields": [
          "Pid",
          "Username",
          "Nspace",
          "Routine",
          "State",
          "Commands",
          "Globals"
        ],
        "default": "Pid",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Pid",
          "labelKey": "processColumnPid",
          "kind": "name"
        },
        {
          "field": "Username",
          "labelKey": "processColumnUser",
          "kind": "text"
        },
        {
          "field": "Nspace",
          "labelKey": "headerNamespaceLabel",
          "kind": "text"
        },
        {
          "field": "Routine",
          "labelKey": "processColumnRoutine",
          "kind": "identifier"
        },
        {
          "field": "State",
          "labelKey": "processColumnState",
          "kind": "text"
        },
        {
          "field": "Commands",
          "labelKey": "processColumnCommands",
          "kind": "number"
        },
        {
          "field": "Globals",
          "labelKey": "processColumnGlobals",
          "kind": "number"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "processListEmptyAgent"
    },
    "toolIdentifier": "osmgmt.processes",
    "multiSelect": {
      "action": "broadcast",
      "eligible": "CanReceiveBroadcast",
      "max": 20,
      "ineligibleKey": "processBroadcastIneligible"
    },
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "secretArguments": [],
    "fingerprintExcludes": []
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.RemoteDatabaseForm",
    "route": "os-management/remote-databases/edit",
    "area": "os-management",
    "labelKey": "remoteDatabaseFormLabel",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "database-configuration",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "remoteDatabaseFormPrompt1"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "remoteDatabaseFormPrompt2"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "remoteDatabaseFormPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Dialog.RemoteDatabase",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "osmgmt.remotedatabaseform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.RemoteDatabaseList",
    "route": "os-management/remote-databases",
    "area": "os-management",
    "labelKey": "remoteDatabaseListLabel",
    "sideBarPosition": 12,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "database-configuration",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "delete",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Name",
        "Server",
        "Directory",
        "Status"
      ],
      "secretFields": []
    },
    "emptyStateKey": "remoteDatabaseListEmpty",
    "commandAliases": [
      "remote databases",
      "ecp databases",
      "create remote database"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "remoteDatabaseListPrompt1"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "remoteDatabaseListPrompt2"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "remoteDatabaseListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.RemoteDatabases",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Database.ConfigCRUD",
        "type": "LIST",
        "query": {
          "remoteOnly": "1"
        }
      },
      "fields": [
        "Name",
        "Server",
        "Directory",
        "Status"
      ],
      "filter": [
        "Name",
        "Server",
        "Directory",
        "Status"
      ],
      "sort": {
        "fields": [
          "Name",
          "Server",
          "Directory",
          "Status"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Server",
          "labelKey": "remoteDatabaseServer",
          "kind": "identifier"
        },
        {
          "field": "Directory",
          "labelKey": "lockColumnDirectory",
          "kind": "identifier"
        },
        {
          "field": "Status",
          "labelKey": "taskHistoryColumnStatus",
          "kind": "text"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "remoteDatabaseListEmptyAgent"
    },
    "toolIdentifier": "osmgmt.remotedatabases",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ResourceList",
    "route": "permissions/resources",
    "area": "permissions",
    "labelKey": "resourceListLabel",
    "sideBarPosition": 3,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "resource",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "delete",
        "selfProtection": "system-resource"
      }
    ],
    "context": {
      "fields": [
        "Name",
        "Description",
        "PublicPermission",
        "ResourceType",
        "AllowDelete"
      ],
      "secretFields": []
    },
    "emptyStateKey": "resourceListEmpty",
    "commandAliases": [
      "security resources"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "resourceListPrompt1"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "resourceListPrompt2"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "resourceListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Resources",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Security.Resource",
        "type": "LIST"
      },
      "fields": [
        "Name",
        "Description",
        "PublicPermission",
        "ResourceType",
        "AllowDelete"
      ],
      "filter": [
        "Name",
        "Description",
        "PublicPermission",
        "ResourceType"
      ],
      "sort": {
        "fields": [
          "Name",
          "Description",
          "PublicPermission",
          "ResourceType"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Description",
          "labelKey": "tableColumnDescription",
          "kind": "text"
        },
        {
          "field": "PublicPermission",
          "labelKey": "resourceColumnPublicPermission",
          "kind": "text"
        },
        {
          "field": "ResourceType",
          "labelKey": "tableColumnType",
          "kind": "text"
        },
        {
          "field": "AllowDelete",
          "labelKey": "resourceColumnDeletable",
          "kind": "text"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "resourceListEmptyAgent"
    },
    "toolIdentifier": "permissions.resources",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.RestApiList",
    "route": "web-applications/rest-apis",
    "area": "web-applications",
    "labelKey": "restApiListLabel",
    "sideBarPosition": 2,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "rest-service",
    "secondaryEntityTypes": [],
    "scope": "namespace",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Name",
        "Namespace",
        "DispatchClass",
        "SpecBased",
        "Enabled"
      ],
      "secretFields": []
    },
    "emptyStateKey": "restApiListEmpty",
    "commandAliases": [
      "REST",
      "REST APIs"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "restApiListPrompt1"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "restApiListPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "restApiListPrompt3"
      }
    ],
    "classicPage": "",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "mgmnt",
        "endpoint": "Applications",
        "type": "LIST"
      },
      "fields": [
        "Name",
        "Namespace",
        "DispatchClass",
        "SpecBased",
        "Enabled"
      ],
      "filter": [
        "Name",
        "Namespace",
        "DispatchClass"
      ],
      "sort": {
        "fields": [
          "Name",
          "Namespace",
          "DispatchClass"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Namespace",
          "labelKey": "headerNamespaceLabel",
          "kind": "identifier"
        },
        {
          "field": "DispatchClass",
          "labelKey": "webAppColumnDispatchClass",
          "kind": "identifier"
        },
        {
          "field": "SpecBased",
          "labelKey": "restApiColumnSpecBased",
          "kind": "status"
        },
        {
          "field": "Enabled",
          "labelKey": "tableColumnEnabled",
          "kind": "status"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "webapp.restapis",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.RoleForm",
    "route": "permissions/roles/edit",
    "area": "permissions",
    "labelKey": "userRoleField",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "role",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "rolePromptHolders"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "rolePromptPrivilege"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "rolePromptGrantedRoles"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Role",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "permissions.roleform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.RoleList",
    "route": "permissions/roles",
    "area": "permissions",
    "labelKey": "userColumnRoles",
    "sideBarPosition": 2,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "role",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "delete",
        "selfProtection": "system-role"
      },
      {
        "id": "add-granted-role",
        "selfProtection": ""
      },
      {
        "id": "remove-granted-role",
        "selfProtection": ""
      },
      {
        "id": "set-resource-grant",
        "selfProtection": ""
      },
      {
        "id": "remove-resource-grant",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Name",
        "Description",
        "CreatedBy",
        "EscalationOnly"
      ],
      "secretFields": []
    },
    "emptyStateKey": "roleListEmpty",
    "commandAliases": [
      "security roles"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "roleListPrompt1"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "roleListPrompt2"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "roleListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Roles",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Security.Role",
        "type": "LIST"
      },
      "fields": [
        "Name",
        "Description",
        "CreatedBy",
        "EscalationOnly"
      ],
      "filter": [
        "Name",
        "Description",
        "CreatedBy"
      ],
      "sort": {
        "fields": [
          "Name",
          "Description",
          "CreatedBy"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Description",
          "labelKey": "tableColumnDescription",
          "kind": "text"
        },
        {
          "field": "CreatedBy",
          "labelKey": "roleColumnCreatedBy",
          "kind": "text"
        },
        {
          "field": "EscalationOnly",
          "labelKey": "roleColumnEscalationOnly",
          "kind": "text"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "roleListEmptyAgent"
    },
    "toolIdentifier": "permissions.roles",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.RoutineMappingForm",
    "route": "os-management/namespaces/routine-mappings/edit",
    "area": "os-management",
    "labelKey": "routineMappingFormLabel",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "routine-mapping",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "composite",
      "parts": [
        "namespace",
        "Name"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "routineMappingFormPrompt1"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "routineMappingFormPrompt2"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "routineMappingFormPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Mappings.Routine",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "osmgmt.routinemappingform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.RoutineMappingList",
    "route": "os-management/namespaces/routine-mappings",
    "area": "os-management",
    "labelKey": "routineMappingListLabel",
    "sideBarPosition": 0,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Manage",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "routine-mapping",
    "secondaryEntityTypes": [
      "namespace"
    ],
    "scope": "instance",
    "parentScope": "os-management/namespaces",
    "id": {
      "kind": "composite",
      "parts": [
        "namespace",
        "Name"
      ]
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "delete",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "namespace",
        "Name",
        "Type",
        "Database"
      ],
      "secretFields": []
    },
    "emptyStateKey": "routineMappingListEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "routineMappingListPrompt1"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "routineMappingListPrompt2"
      },
      {
        "groupKey": "promptGroupGettingStarted",
        "textKey": "routineMappingListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Mappings",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Namespace.RoutineMappings",
        "type": "LIST"
      },
      "fields": [
        "namespace",
        "Name",
        "Type",
        "Database"
      ],
      "filter": [
        "Name",
        "Type",
        "Database"
      ],
      "sort": {
        "fields": [
          "Name",
          "Type",
          "Database"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "namespace",
            "labelKey": "headerNamespaceLabel",
            "kind": "text",
            "maxLength": 64
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Type",
          "labelKey": "tableColumnType",
          "kind": "text"
        },
        {
          "field": "Database",
          "labelKey": "systemInfoDatabase",
          "kind": "identifier"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "routineMappingListEmptyAgent"
    },
    "toolIdentifier": "osmgmt.routinemappings",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ServiceForm",
    "route": "permissions/services/edit",
    "area": "permissions",
    "labelKey": "serviceFormLabel",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "service",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "servicePromptWhoConnects"
      },
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "servicePromptEnabled"
      },
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "servicePromptUnauthenticated"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Dialog.Service",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "permissions.serviceform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.ServiceList",
    "route": "permissions/services",
    "area": "permissions",
    "labelKey": "serviceListLabel",
    "sideBarPosition": 4,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "service",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Name",
        "Enabled",
        "Public",
        "AuthenticationMethods",
        "AllowedConnections",
        "Description",
        "HttpOnlyCookies",
        "TwoFactorEnabled"
      ],
      "secretFields": []
    },
    "emptyStateKey": "serviceListEmpty",
    "commandAliases": [
      "security services"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "serviceListPrompt1"
      },
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "serviceListPrompt2"
      },
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "serviceListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Services",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Security.Service",
        "type": "LIST"
      },
      "fields": [
        "Name",
        "Enabled",
        "Public",
        "AuthenticationMethods",
        "AllowedConnections",
        "Description",
        "HttpOnlyCookies",
        "TwoFactorEnabled"
      ],
      "filter": [
        "Name",
        "Description",
        "AuthenticationMethods",
        "AllowedConnections"
      ],
      "sort": {
        "fields": [
          "Name",
          "Description"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Enabled",
          "labelKey": "tableColumnEnabled",
          "kind": "status"
        },
        {
          "field": "AuthenticationMethods",
          "labelKey": "serviceColumnAuthentication",
          "kind": "text"
        },
        {
          "field": "AllowedConnections",
          "labelKey": "serviceColumnAllowedAddresses",
          "kind": "identifier",
          "emptyKey": "serviceAllowedUnrestricted"
        },
        {
          "field": "Description",
          "labelKey": "tableColumnDescription",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "permissions.services",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.SslConfigList",
    "route": "security/ssl",
    "area": "security",
    "labelKey": "sslListLabel",
    "sideBarPosition": 1,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "ssl-configuration",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "delete",
        "selfProtection": "ocupilot-ssl"
      }
    ],
    "context": {
      "fields": [
        "Name",
        "Description",
        "Enabled",
        "Type"
      ],
      "secretFields": []
    },
    "secretArguments": [
      "PrivateKeyPassword"
    ],
    "emptyStateKey": "sslListEmpty",
    "commandAliases": [
      "certificates"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "sslConfigListPrompt1"
      },
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "sslConfigListPrompt2"
      },
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "sslConfigListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.SSLList",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Security.SSLConfig",
        "type": "LIST"
      },
      "fields": [
        "Name",
        "Description",
        "Enabled",
        "Type"
      ],
      "filter": [
        "Name",
        "Description",
        "Type"
      ],
      "sort": {
        "fields": [
          "Name",
          "Description",
          "Type"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Description",
          "labelKey": "tableColumnDescription",
          "kind": "text"
        },
        {
          "field": "Enabled",
          "labelKey": "tableColumnEnabled",
          "kind": "status"
        },
        {
          "field": "Type",
          "labelKey": "tableColumnType",
          "kind": "text"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "sslListEmptyAgent"
    },
    "toolIdentifier": "security.ssl",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.SslForm",
    "route": "security/ssl/edit",
    "area": "security",
    "labelKey": "sslFormLabel",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "ssl-configuration",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": [
        "PrivateKeyPassword"
      ]
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "sslPromptVerifies"
      },
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "sslPromptProtocols"
      },
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "sslPromptOutbound"
      }
    ],
    "classicPage": "%CSP.UI.Portal.SSL",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "security.sslform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.SystemUsage",
    "route": "os-management/system-usage",
    "area": "os-management",
    "labelKey": "systemUsageLabel",
    "sideBarPosition": 3,
    "archetype": "meters",
    "built": true,
    "refreshes": true,
    "refreshRates": [
      5,
      10,
      30,
      60
    ],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "none",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Usage.AllGlobalReferences",
        "Usage.GlobalUpdateReferences",
        "Usage.RoutineCalls",
        "Usage.LogicalBlockRequests",
        "Usage.BlockReads",
        "Usage.BlockWrites",
        "Usage.JournalEntries",
        "Usage.JournalBlockWrites",
        "Usage.LastUpdate",
        "SharedMemory.SMHAllocated",
        "SharedMemory.SMHUsed",
        "SharedMemory.SMHAvailable",
        "Dashboard.Performance.GlobalRefsPerSecond",
        "Dashboard.Performance.CacheEfficiency",
        "Dashboard.SystemUsage.DatabaseSpace",
        "Dashboard.SystemUsage.JournalSpace",
        "Dashboard.SystemUsage.LockTable",
        "Dashboard.SystemUsage.WriteDaemon"
      ],
      "secretFields": []
    },
    "emptyStateKey": "systemUsageEmpty",
    "commandAliases": [
      "system usage",
      "memory",
      "shared memory",
      "global references"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "systemUsagePrompt1"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "systemUsagePrompt2"
      },
      {
        "groupKey": "promptGroupCapacity",
        "textKey": "systemUsagePrompt3"
      }
    ],
    "classicPage": "%cspapp.op.utilsysmonitor",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Monitor",
        "type": "GET",
        "parts": [
          {
            "type": "SYSTEMUSAGE",
            "as": "Usage"
          },
          {
            "type": "SYSTEMUSAGESHM",
            "as": "SharedMemory"
          },
          {
            "type": "DASHBOARDMAIN",
            "as": "Dashboard"
          }
        ]
      },
      "fields": [
        "Usage.AllGlobalReferences",
        "Usage.GlobalUpdateReferences",
        "Usage.RoutineCalls",
        "Usage.LogicalBlockRequests",
        "Usage.BlockReads",
        "Usage.BlockWrites",
        "Usage.JournalEntries",
        "Usage.JournalBlockWrites",
        "Usage.LastUpdate",
        "SharedMemory.SMHAllocated",
        "SharedMemory.SMHUsed",
        "SharedMemory.SMHAvailable",
        "Dashboard.Performance.GlobalRefsPerSecond",
        "Dashboard.Performance.CacheEfficiency",
        "Dashboard.SystemUsage.DatabaseSpace",
        "Dashboard.SystemUsage.JournalSpace",
        "Dashboard.SystemUsage.LockTable",
        "Dashboard.SystemUsage.WriteDaemon"
      ],
      "filter": [
        "Usage.AllGlobalReferences",
        "Usage.GlobalUpdateReferences",
        "Usage.RoutineCalls",
        "Usage.LogicalBlockRequests",
        "Usage.BlockReads",
        "Usage.BlockWrites",
        "Usage.JournalEntries",
        "Usage.JournalBlockWrites",
        "Usage.LastUpdate",
        "SharedMemory.SMHAllocated",
        "SharedMemory.SMHUsed",
        "SharedMemory.SMHAvailable",
        "Dashboard.Performance.GlobalRefsPerSecond",
        "Dashboard.Performance.CacheEfficiency",
        "Dashboard.SystemUsage.DatabaseSpace",
        "Dashboard.SystemUsage.JournalSpace",
        "Dashboard.SystemUsage.LockTable",
        "Dashboard.SystemUsage.WriteDaemon"
      ],
      "sort": {
        "fields": [
          "Usage.AllGlobalReferences",
          "Usage.GlobalUpdateReferences",
          "Usage.RoutineCalls",
          "Usage.LogicalBlockRequests",
          "Usage.BlockReads",
          "Usage.BlockWrites",
          "Usage.JournalEntries",
          "Usage.JournalBlockWrites",
          "Usage.LastUpdate",
          "SharedMemory.SMHAllocated",
          "SharedMemory.SMHUsed",
          "SharedMemory.SMHAvailable",
          "Dashboard.Performance.GlobalRefsPerSecond",
          "Dashboard.Performance.CacheEfficiency",
          "Dashboard.SystemUsage.DatabaseSpace",
          "Dashboard.SystemUsage.JournalSpace",
          "Dashboard.SystemUsage.LockTable",
          "Dashboard.SystemUsage.WriteDaemon"
        ],
        "default": "Usage.LastUpdate",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Usage.AllGlobalReferences",
          "labelKey": "processDetailsGlobalReferences",
          "kind": "number"
        },
        {
          "field": "Usage.GlobalUpdateReferences",
          "labelKey": "systemUsageGlobalUpdates",
          "kind": "number"
        },
        {
          "field": "Usage.RoutineCalls",
          "labelKey": "systemUsageRoutineCalls",
          "kind": "number"
        },
        {
          "field": "Usage.LogicalBlockRequests",
          "labelKey": "systemUsageLogicalBlockRequests",
          "kind": "number"
        },
        {
          "field": "Usage.BlockReads",
          "labelKey": "systemUsageBlockReads",
          "kind": "number"
        },
        {
          "field": "Usage.BlockWrites",
          "labelKey": "systemUsageBlockWrites",
          "kind": "number"
        },
        {
          "field": "Usage.JournalEntries",
          "labelKey": "systemUsageJournalEntries",
          "kind": "number"
        },
        {
          "field": "Usage.JournalBlockWrites",
          "labelKey": "systemUsageJournalBlockWrites",
          "kind": "number"
        },
        {
          "field": "Usage.LastUpdate",
          "labelKey": "systemUsageLastUpdate",
          "kind": "name"
        },
        {
          "field": "SharedMemory.SMHAllocated",
          "labelKey": "systemUsageSharedMemory",
          "kind": "number"
        },
        {
          "field": "SharedMemory.SMHUsed",
          "labelKey": "systemUsageSharedMemory",
          "kind": "number"
        },
        {
          "field": "SharedMemory.SMHAvailable",
          "labelKey": "systemUsageSharedMemory",
          "kind": "number"
        },
        {
          "field": "Dashboard.Performance.GlobalRefsPerSecond",
          "labelKey": "systemUsageGlobalRefsPerSecond",
          "kind": "number"
        },
        {
          "field": "Dashboard.Performance.CacheEfficiency",
          "labelKey": "systemUsageCacheEfficiency",
          "kind": "number"
        },
        {
          "field": "Dashboard.SystemUsage.DatabaseSpace",
          "labelKey": "systemUsageDatabaseSpace",
          "kind": "text"
        },
        {
          "field": "Dashboard.SystemUsage.JournalSpace",
          "labelKey": "systemUsageJournalSpace",
          "kind": "text"
        },
        {
          "field": "Dashboard.SystemUsage.LockTable",
          "labelKey": "systemUsageLockTable",
          "kind": "text"
        },
        {
          "field": "Dashboard.SystemUsage.WriteDaemon",
          "labelKey": "systemUsageWriteDaemon",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "osmgmt.systemusage",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.TaskDetails",
    "route": "tasks/schedule/details",
    "area": "tasks",
    "labelKey": "taskDetailsLabel",
    "sideBarPosition": 0,
    "archetype": "detail",
    "built": true,
    "refreshes": true,
    "refreshRates": [
      5,
      10,
      30,
      60
    ],
    "privileges": [
      {
        "resource": "%Admin_Task",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "task",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "tasks/schedule",
    "id": {
      "kind": "composite",
      "parts": [
        "Id"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Id",
        "Name",
        "Description",
        "NameSpace",
        "TaskClass",
        "Priority",
        "RunAsUser",
        "TimePeriod",
        "TimePeriodEvery",
        "TimePeriodDay",
        "DailyFrequency",
        "DailyFrequencyTime",
        "DailyIncrement",
        "DailyStartTime",
        "DailyEndTime",
        "StartDate",
        "EndDate",
        "Type",
        "Suspended",
        "Error",
        "LastStarted",
        "LastFinished",
        "NextScheduled"
      ],
      "secretFields": []
    },
    "emptyStateKey": "taskDetailsGone",
    "commandAliases": [
      "task details"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "taskPromptGroupSchedule",
        "textKey": "taskDetailsPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "taskDetailsPrompt2"
      },
      {
        "groupKey": "taskPromptGroupSchedule",
        "textKey": "taskDetailsPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.TaskInfo",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Task.CRUD",
        "type": "GET",
        "rowGet": {
          "key": "taskId",
          "param": "id",
          "type": "INFO",
          "fields": [
            "Type",
            "Suspended",
            "Error",
            "LastStarted",
            "LastFinished",
            "NextScheduled"
          ],
          "derived": []
        }
      },
      "fields": [
        "Id",
        "Name",
        "Description",
        "NameSpace",
        "TaskClass",
        "Priority",
        "RunAsUser",
        "TimePeriod",
        "TimePeriodEvery",
        "TimePeriodDay",
        "DailyFrequency",
        "DailyFrequencyTime",
        "DailyIncrement",
        "DailyStartTime",
        "DailyEndTime",
        "StartDate",
        "EndDate",
        "Type",
        "Suspended",
        "Error",
        "LastStarted",
        "LastFinished",
        "NextScheduled"
      ],
      "filter": [
        "Name",
        "Description",
        "NameSpace",
        "TaskClass",
        "Priority",
        "RunAsUser",
        "TimePeriod",
        "TimePeriodEvery",
        "TimePeriodDay",
        "DailyFrequency",
        "DailyFrequencyTime",
        "DailyIncrement",
        "DailyStartTime",
        "DailyEndTime",
        "StartDate",
        "EndDate",
        "Type",
        "Suspended",
        "Error",
        "LastStarted",
        "LastFinished",
        "NextScheduled"
      ],
      "sort": {
        "fields": [
          "Name",
          "Description",
          "NameSpace",
          "TaskClass",
          "Priority",
          "RunAsUser",
          "TimePeriod",
          "TimePeriodEvery",
          "TimePeriodDay",
          "DailyFrequency",
          "DailyFrequencyTime",
          "DailyIncrement",
          "DailyStartTime",
          "DailyEndTime",
          "StartDate",
          "EndDate",
          "Type",
          "Suspended",
          "Error",
          "LastStarted",
          "LastFinished",
          "NextScheduled"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "taskId",
            "labelKey": "taskHistoryColumnTaskId",
            "kind": "text",
            "maxLength": 10,
            "vendorParam": "id"
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Description",
          "labelKey": "tableColumnDescription",
          "kind": "text"
        },
        {
          "field": "NameSpace",
          "labelKey": "headerNamespaceLabel",
          "kind": "text"
        },
        {
          "field": "Type",
          "labelKey": "tableColumnType",
          "kind": "text"
        },
        {
          "field": "Suspended",
          "labelKey": "taskColumnSuspended",
          "kind": "status"
        },
        {
          "field": "TaskClass",
          "labelKey": "taskDetailsTaskClass",
          "kind": "text"
        },
        {
          "field": "Priority",
          "labelKey": "taskDetailsPriority",
          "kind": "text"
        },
        {
          "field": "RunAsUser",
          "labelKey": "taskDetailsRunAs",
          "kind": "text"
        },
        {
          "field": "LastStarted",
          "labelKey": "taskHistoryColumnStarted",
          "kind": "text"
        },
        {
          "field": "LastFinished",
          "labelKey": "taskHistoryColumnCompleted",
          "kind": "text"
        },
        {
          "field": "NextScheduled",
          "labelKey": "taskColumnNextRun",
          "kind": "text"
        },
        {
          "field": "Error",
          "labelKey": "taskDetailsLastError",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "tasks.taskdetails",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.TaskForm",
    "route": "tasks/schedule/edit",
    "area": "tasks",
    "labelKey": "proposalEntityTask",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Task",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "task",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "taskPromptGroupSchedule",
        "textKey": "taskPromptNightly"
      },
      {
        "groupKey": "taskPromptGroupSchedule",
        "textKey": "taskPromptWeekly"
      },
      {
        "groupKey": "taskPromptGroupSchedule",
        "textKey": "taskPromptWhichType"
      }
    ],
    "classicPage": "%cspapp.op.utilsystaskbuilder",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "tasks.scheduleform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.TaskHistoryList",
    "route": "tasks/history",
    "area": "tasks",
    "labelKey": "taskHistoryLabel",
    "sideBarPosition": 4,
    "archetype": "list (server criteria)",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Task",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "task-history-entry",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "composite",
      "parts": [
        "TaskId",
        "LogDatetime",
        "Status"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "LastStart",
        "Completed",
        "Name",
        "Status",
        "Result",
        "TaskId",
        "Namespace",
        "Routine",
        "Pid",
        "ErrDate",
        "ErrNumber",
        "Username",
        "LogDatetime"
      ],
      "secretFields": []
    },
    "emptyStateKey": "taskHistoryEmpty",
    "commandAliases": [
      "task history",
      "task runs"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "taskHistoryListPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "taskHistoryListPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "taskHistoryListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.TaskHistory",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Task.CRUD",
        "type": "HISTORY"
      },
      "fields": [
        "LastStart",
        "Completed",
        "Name",
        "Status",
        "Result",
        "TaskId",
        "Namespace",
        "Routine",
        "Pid",
        "ErrDate",
        "ErrNumber",
        "Username",
        "LogDatetime"
      ],
      "filter": [
        "Name",
        "Namespace",
        "Status",
        "Result",
        "Username",
        "Routine"
      ],
      "sort": {
        "fields": [
          "LastStart",
          "Completed",
          "Name",
          "Namespace",
          "Status",
          "Result",
          "Username",
          "LogDatetime"
        ],
        "default": "LogDatetime",
        "direction": "desc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "search",
            "labelKey": "taskHistorySearch",
            "kind": "text",
            "maxLength": 100,
            "vendorParam": "filter"
          },
          {
            "param": "userOnly",
            "labelKey": "taskHistoryUserOnly",
            "kind": "choice",
            "maxLength": 1,
            "options": [
              "1"
            ]
          },
          {
            "param": "since",
            "labelKey": "taskHistorySince",
            "kind": "datetime",
            "maxLength": 50,
            "defaultHoursAgo": 168,
            "atOrAfterField": "LogDatetime"
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "LastStart",
          "labelKey": "taskHistoryColumnStarted",
          "kind": "text"
        },
        {
          "field": "Completed",
          "labelKey": "taskHistoryColumnCompleted",
          "kind": "text"
        },
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Status",
          "labelKey": "taskHistoryColumnStatus",
          "kind": "text"
        },
        {
          "field": "Result",
          "labelKey": "taskHistoryColumnResult",
          "kind": "text"
        },
        {
          "field": "Username",
          "labelKey": "processColumnUser",
          "kind": "text"
        },
        {
          "field": "Namespace",
          "labelKey": "headerNamespaceLabel",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "tasks.history",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.TaskOnDemandList",
    "route": "tasks/on-demand",
    "area": "tasks",
    "labelKey": "taskOnDemandLabel",
    "sideBarPosition": 2,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Task",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "task",
    "entityLabelKey": "proposalEntityTask",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "composite",
      "parts": [
        "Id"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "run",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Name",
        "Namespace",
        "Type",
        "Description",
        "Id",
        "LastFinished",
        "NextScheduled"
      ],
      "secretFields": []
    },
    "emptyStateKey": "taskOnDemandEmpty",
    "commandAliases": [
      "on demand",
      "run task"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "taskPromptGroupSchedule",
        "textKey": "taskOnDemandListPrompt1"
      },
      {
        "groupKey": "taskPromptGroupSchedule",
        "textKey": "taskOnDemandListPrompt2"
      },
      {
        "groupKey": "taskPromptGroupSchedule",
        "textKey": "taskOnDemandListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.TasksOnDemand",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Task.CRUD",
        "type": "LIST",
        "query": {
          "onDemand": "1"
        }
      },
      "fields": [
        "Name",
        "Namespace",
        "Type",
        "Description",
        "Id",
        "LastFinished",
        "NextScheduled"
      ],
      "filter": [
        "Name",
        "Namespace",
        "Type",
        "Description"
      ],
      "sort": {
        "fields": [
          "Name",
          "Namespace",
          "Type",
          "LastFinished",
          "NextScheduled"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Namespace",
          "labelKey": "headerNamespaceLabel",
          "kind": "text"
        },
        {
          "field": "Type",
          "labelKey": "tableColumnType",
          "kind": "text"
        },
        {
          "field": "Description",
          "labelKey": "tableColumnDescription",
          "kind": "text"
        },
        {
          "field": "LastFinished",
          "labelKey": "taskColumnLastRun",
          "kind": "text"
        },
        {
          "field": "NextScheduled",
          "labelKey": "taskColumnNextRun",
          "kind": "text"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "taskOnDemandEmptyAgent"
    },
    "toolIdentifier": "tasks.ondemand",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": []
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.TaskRunList",
    "route": "tasks/schedule/history",
    "area": "tasks",
    "labelKey": "taskRunsLabel",
    "sideBarPosition": 0,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Task",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "task-history-entry",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "tasks/schedule",
    "id": {
      "kind": "composite",
      "parts": [
        "TaskId",
        "LogDatetime",
        "Status"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "LastStart",
        "Completed",
        "Name",
        "Status",
        "Result",
        "TaskId",
        "Namespace",
        "Routine",
        "Pid",
        "ErrDate",
        "ErrNumber",
        "Username",
        "LogDatetime"
      ],
      "secretFields": []
    },
    "emptyStateKey": "taskRunsEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "taskRunListPrompt1"
      },
      {
        "groupKey": "taskPromptGroupSchedule",
        "textKey": "taskRunListPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "taskRunListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.TaskHistoryId",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Task.CRUD",
        "type": "HISTORY"
      },
      "fields": [
        "LastStart",
        "Completed",
        "Name",
        "Status",
        "Result",
        "TaskId",
        "Namespace",
        "Routine",
        "Pid",
        "ErrDate",
        "ErrNumber",
        "Username",
        "LogDatetime"
      ],
      "filter": [
        "Name",
        "Namespace",
        "Status",
        "Result",
        "Username",
        "Routine"
      ],
      "sort": {
        "fields": [
          "LastStart",
          "Completed",
          "Name",
          "Namespace",
          "Status",
          "Result",
          "Username",
          "LogDatetime"
        ],
        "default": "LogDatetime",
        "direction": "desc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "taskId",
            "labelKey": "taskHistoryColumnTaskId",
            "kind": "text",
            "maxLength": 10
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "LastStart",
          "labelKey": "taskHistoryColumnStarted",
          "kind": "text"
        },
        {
          "field": "Completed",
          "labelKey": "taskHistoryColumnCompleted",
          "kind": "text"
        },
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Status",
          "labelKey": "taskHistoryColumnStatus",
          "kind": "text"
        },
        {
          "field": "Result",
          "labelKey": "taskHistoryColumnResult",
          "kind": "text"
        },
        {
          "field": "Username",
          "labelKey": "processColumnUser",
          "kind": "text"
        },
        {
          "field": "Namespace",
          "labelKey": "headerNamespaceLabel",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "tasks.taskhistory",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.TaskScheduleList",
    "route": "tasks/schedule",
    "area": "tasks",
    "labelKey": "taskListLabel",
    "sideBarPosition": 1,
    "archetype": "list",
    "built": true,
    "refreshes": true,
    "refreshRates": [
      5,
      10,
      30,
      60
    ],
    "privileges": [
      {
        "resource": "%Admin_Task",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "task",
    "entityLabelKey": "proposalEntityTask",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "composite",
      "parts": [
        "Id"
      ]
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "run",
        "selfProtection": ""
      },
      {
        "id": "suspend",
        "selfProtection": ""
      },
      {
        "id": "resume",
        "selfProtection": ""
      },
      {
        "id": "export",
        "selfProtection": ""
      },
      {
        "id": "import",
        "selfProtection": ""
      },
      {
        "id": "delete",
        "selfProtection": ""
      },
      {
        "id": "suspendmanager",
        "selfProtection": ""
      },
      {
        "id": "resumemanager",
        "selfProtection": ""
      },
      {
        "id": "startmanager",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Name",
        "Type",
        "Namespace",
        "Description",
        "Id",
        "LastFinished",
        "NextScheduled",
        "Suspended"
      ],
      "secretFields": []
    },
    "emptyStateKey": "taskListEmpty",
    "commandAliases": [
      "task manager"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "taskScheduleListPrompt1"
      },
      {
        "groupKey": "taskPromptGroupSchedule",
        "textKey": "taskScheduleListPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "taskScheduleListPrompt3"
      },
      {
        "groupKey": "taskPromptGroupSchedule",
        "textKey": "taskScheduleListPrompt4"
      }
    ],
    "classicPage": "%CSP.UI.Portal.TaskSchedule",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Task.CRUD",
        "type": "LIST",
        "rowGet": {
          "key": "Id",
          "param": "id",
          "type": "INFO",
          "fields": [
            "Suspended"
          ],
          "derived": []
        }
      },
      "fields": [
        "Name",
        "Type",
        "Namespace",
        "Description",
        "Id",
        "LastFinished",
        "NextScheduled",
        "Suspended"
      ],
      "filter": [
        "Name",
        "Namespace",
        "Type",
        "Description"
      ],
      "sort": {
        "fields": [
          "Name",
          "Namespace",
          "Type",
          "Description",
          "LastFinished",
          "NextScheduled"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Namespace",
          "labelKey": "headerNamespaceLabel",
          "kind": "text"
        },
        {
          "field": "Type",
          "labelKey": "tableColumnType",
          "kind": "text"
        },
        {
          "field": "Suspended",
          "labelKey": "taskColumnSuspended",
          "kind": "status"
        },
        {
          "field": "LastFinished",
          "labelKey": "taskColumnLastRun",
          "kind": "text"
        },
        {
          "field": "NextScheduled",
          "labelKey": "taskColumnNextRun",
          "kind": "text"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "taskScheduleEmptyAgent"
    },
    "banner": {
      "source": {
        "port": "admin",
        "endpoint": "Task.Manager",
        "type": "GET"
      },
      "field": "Status",
      "cases": [
        {
          "equals": "Suspended",
          "messageKey": "taskManagerSuspendedBanner",
          "severity": "warning",
          "action": "resumemanager"
        },
        {
          "equals": "Not running",
          "messageKey": "taskManagerStoppedBanner",
          "severity": "warning",
          "action": "startmanager"
        }
      ]
    },
    "toolIdentifier": "tasks.schedule",
    "refreshDefault": 0,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": []
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.TaskUpcomingList",
    "route": "tasks/upcoming",
    "area": "tasks",
    "labelKey": "taskUpcomingLabel",
    "sideBarPosition": 3,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Task",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "task",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "composite",
      "parts": [
        "Id",
        "Datetime"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Id",
        "Name",
        "Namespace",
        "Datetime",
        "Suspended"
      ],
      "secretFields": []
    },
    "emptyStateKey": "taskUpcomingEmpty",
    "commandAliases": [
      "upcoming",
      "next runs"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "taskPromptGroupSchedule",
        "textKey": "taskUpcomingListPrompt1"
      },
      {
        "groupKey": "taskPromptGroupSchedule",
        "textKey": "taskUpcomingListPrompt2"
      },
      {
        "groupKey": "taskPromptGroupSchedule",
        "textKey": "taskUpcomingListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.TasksUpcoming",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Task.CRUD",
        "type": "UPCOMING"
      },
      "fields": [
        "Id",
        "Name",
        "Namespace",
        "Datetime",
        "Suspended"
      ],
      "filter": [
        "Name",
        "Namespace"
      ],
      "sort": {
        "fields": [
          "Datetime",
          "Name",
          "Namespace"
        ],
        "default": "Datetime",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "hoursOffset",
            "labelKey": "taskUpcomingHorizon",
            "kind": "choice",
            "maxLength": 3,
            "options": [
              "1",
              "4",
              "12",
              "24",
              "72",
              "168"
            ]
          },
          {
            "param": "toDatetime",
            "labelKey": "taskUpcomingUntil",
            "kind": "datetime",
            "maxLength": 19
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Datetime",
          "labelKey": "taskUpcomingColumnAt",
          "kind": "text"
        },
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Namespace",
          "labelKey": "headerNamespaceLabel",
          "kind": "text"
        },
        {
          "field": "Suspended",
          "labelKey": "taskColumnSuspended",
          "kind": "status"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "tasks.upcoming",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.UserForm",
    "route": "permissions/users/edit",
    "area": "permissions",
    "labelKey": "processColumnUser",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "user",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": [
        "Password"
      ]
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "userPromptSignIn"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "userPromptPrivilege"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "userPromptTwoFactor"
      }
    ],
    "classicPage": "%CSP.UI.Portal.User",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "permissions.userform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.UserList",
    "route": "permissions/users",
    "area": "permissions",
    "labelKey": "userListLabel",
    "sideBarPosition": 1,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "user",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "enable",
        "selfProtection": ""
      },
      {
        "id": "disable",
        "selfProtection": "protected-account"
      },
      {
        "id": "set-password",
        "selfProtection": "service-account-sign-in"
      },
      {
        "id": "add-role",
        "selfProtection": ""
      },
      {
        "id": "remove-role",
        "selfProtection": ""
      },
      {
        "id": "require-password-change",
        "selfProtection": "service-account-sign-in"
      },
      {
        "id": "delete",
        "selfProtection": "protected-account"
      },
      {
        "id": "revoke-tokens",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Name",
        "FullName",
        "Enabled",
        "Type",
        "Roles",
        "ExpirationDate",
        "Expired"
      ],
      "secretFields": []
    },
    "secretArguments": [
      "Password"
    ],
    "emptyStateKey": "userListEmpty",
    "commandAliases": [
      "accounts"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupSignIn",
        "textKey": "userListPrompt1"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "userListPrompt2"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "userListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Users",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Security.User",
        "type": "LIST",
        "rowGet": {
          "key": "Name",
          "param": "name",
          "fields": [
            "Roles",
            "ExpirationDate"
          ],
          "derived": [
            {
              "field": "Expired",
              "rule": "beforeToday",
              "from": "ExpirationDate"
            }
          ]
        }
      },
      "fields": [
        "Name",
        "FullName",
        "Enabled",
        "Type",
        "Roles",
        "ExpirationDate",
        "Expired"
      ],
      "filter": [
        "Name",
        "FullName",
        "Type",
        "Roles"
      ],
      "sort": {
        "fields": [
          "Name",
          "FullName",
          "Type",
          "Roles"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "FullName",
          "labelKey": "userColumnFullName",
          "kind": "text"
        },
        {
          "field": "Enabled",
          "labelKey": "tableColumnEnabled",
          "kind": "status"
        },
        {
          "field": "Expired",
          "labelKey": "userColumnExpired",
          "kind": "text"
        },
        {
          "field": "Type",
          "labelKey": "tableColumnType",
          "kind": "text"
        },
        {
          "field": "Roles",
          "labelKey": "userColumnRoles",
          "kind": "identifier"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "userListEmptyAgent"
    },
    "toolIdentifier": "permissions.users",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.WalletCollectionList",
    "route": "security/wallet",
    "area": "security",
    "labelKey": "walletListLabel",
    "sideBarPosition": 4,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Wallet",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_Wallet",
        "permission": "USE"
      }
    ],
    "entityType": "wallet-collection",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Name",
        "EditResource",
        "UseResource"
      ],
      "secretFields": []
    },
    "emptyStateKey": "walletListEmpty",
    "commandAliases": [
      "secrets"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "walletCollectionListPrompt1"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "walletCollectionListPrompt2"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "walletCollectionListPrompt3"
      }
    ],
    "classicPage": "",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Wallet.Collection",
        "type": "LIST"
      },
      "fields": [
        "Name",
        "EditResource",
        "UseResource"
      ],
      "filter": [
        "Name",
        "UseResource",
        "EditResource"
      ],
      "sort": {
        "fields": [
          "Name",
          "UseResource",
          "EditResource"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "UseResource",
          "labelKey": "walletColumnUseResource",
          "kind": "text"
        },
        {
          "field": "EditResource",
          "labelKey": "walletColumnEditResource",
          "kind": "text"
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "security.wallet",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.WalletSecretForm",
    "route": "security/wallet/secrets/edit",
    "area": "security",
    "labelKey": "walletSecretFormLabel",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Wallet",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_Wallet",
        "permission": "USE"
      }
    ],
    "entityType": "wallet-secret",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": [
        "Secret"
      ]
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "walletSecretFormPrompt1"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "walletSecretFormPrompt2"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "walletSecretFormPrompt3"
      }
    ],
    "classicPage": "",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "security.secretform",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.WalletSecretList",
    "route": "security/wallet/secrets",
    "area": "security",
    "labelKey": "walletSecretListLabel",
    "sideBarPosition": 0,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Wallet",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_Wallet",
        "permission": "USE"
      }
    ],
    "entityType": "wallet-secret",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "security/wallet",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "delete",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Name",
        "Type"
      ],
      "secretFields": []
    },
    "secretArguments": [
      "Secret"
    ],
    "emptyStateKey": "walletSecretListEmpty",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "walletSecretListPrompt1"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "walletSecretListPrompt2"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "walletSecretListPrompt3"
      }
    ],
    "classicPage": "",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Wallet.Secret",
        "type": "LIST"
      },
      "fields": [
        "Name",
        "Type"
      ],
      "filter": [
        "Name",
        "Type"
      ],
      "sort": {
        "fields": [
          "Name",
          "Type"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap",
      "criteria": {
        "fields": [
          {
            "param": "collection",
            "labelKey": "tableColumnName",
            "kind": "text",
            "maxLength": 64
          }
        ]
      }
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Type",
          "labelKey": "tableColumnType",
          "kind": "text"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "walletSecretListEmptyAgent"
    },
    "toolIdentifier": "security.secrets",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.WebAppForm",
    "route": "web-applications/list/edit",
    "area": "web-applications",
    "labelKey": "proposalEntityWebApplication",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "web-application",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "webAppPromptAccess"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "webAppPromptUnauthenticated"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "webAppPromptCode"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Applications.Web",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "webapp.form",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.WebAppList",
    "route": "web-applications/list",
    "area": "web-applications",
    "labelKey": "webAppListLabel",
    "sideBarPosition": 1,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "web-application",
    "entityLabelKey": "proposalEntityWebApplication",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "enable",
        "selfProtection": "serves-ocupilot"
      },
      {
        "id": "disable",
        "selfProtection": "serves-ocupilot"
      },
      {
        "id": "add-application-role",
        "selfProtection": "ocupilot-application-roles"
      },
      {
        "id": "remove-application-role",
        "selfProtection": "ocupilot-application-roles"
      },
      {
        "id": "add-matching-role",
        "selfProtection": "ocupilot-application-roles"
      },
      {
        "id": "remove-matching-role",
        "selfProtection": "ocupilot-application-roles"
      },
      {
        "id": "delete",
        "selfProtection": "serves-ocupilot"
      }
    ],
    "context": {
      "fields": [
        "Name",
        "Namespace",
        "Type",
        "Enabled",
        "DispatchClass",
        "Resource"
      ],
      "secretFields": []
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "webAppListEmpty",
    "commandAliases": [
      "web apps"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "webAppListPrompt1"
      },
      {
        "groupKey": "userPromptGroupAccess",
        "textKey": "webAppListPrompt2"
      },
      {
        "groupKey": "webAppPromptGroupCode",
        "textKey": "webAppListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.Applications.WebList",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "WebApp.App",
        "type": "LIST"
      },
      "fields": [
        "Name",
        "Namespace",
        "Type",
        "Enabled",
        "DispatchClass",
        "Resource"
      ],
      "filter": [
        "Name",
        "Namespace",
        "Type",
        "DispatchClass",
        "Resource"
      ],
      "sort": {
        "fields": [
          "Name",
          "Namespace",
          "Type",
          "DispatchClass",
          "Resource"
        ],
        "default": "Name",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Name",
          "labelKey": "tableColumnName",
          "kind": "name"
        },
        {
          "field": "Namespace",
          "labelKey": "headerNamespaceLabel",
          "kind": "identifier"
        },
        {
          "field": "Type",
          "labelKey": "tableColumnType",
          "kind": "text"
        },
        {
          "field": "Enabled",
          "labelKey": "tableColumnEnabled",
          "kind": "status"
        },
        {
          "field": "DispatchClass",
          "labelKey": "webAppColumnDispatchClass",
          "kind": "identifier"
        },
        {
          "field": "Resource",
          "labelKey": "webAppColumnResource",
          "kind": "identifier"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "webAppListEmptyAgent"
    },
    "toolIdentifier": "webapp.list",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.WebSessionList",
    "route": "web-applications/sessions",
    "area": "web-applications",
    "labelKey": "webSessionListLabel",
    "sideBarPosition": 3,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "ownPrivileges": [
      {
        "resource": "%Admin_Operate",
        "permission": "USE"
      }
    ],
    "entityType": "web-session",
    "entityLabelKey": "proposalEntityWebSession",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "composite",
      "parts": [
        "ID"
      ]
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "end",
        "selfProtection": "ocupilot-session"
      }
    ],
    "context": {
      "fields": [
        "ID",
        "Username",
        "Application",
        "SesProcessId",
        "Timeout"
      ],
      "secretFields": []
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "webSessionListEmpty",
    "commandAliases": [
      "sessions",
      "CSP sessions"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "webSessionListPrompt1"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "webSessionListPrompt2"
      },
      {
        "groupKey": "promptGroupTroubleshooting",
        "textKey": "webSessionListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.CSPSessions",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "WebSession",
        "type": "LIST"
      },
      "fields": [
        "ID",
        "Username",
        "Application",
        "SesProcessId",
        "Timeout",
        "Preserve"
      ],
      "filter": [
        "ID",
        "Username",
        "Application",
        "SesProcessId"
      ],
      "sort": {
        "fields": [
          "ID",
          "Username",
          "Application",
          "SesProcessId",
          "Timeout"
        ],
        "default": "Application",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "SesProcessId",
          "labelKey": "processColumnPid",
          "kind": "name"
        },
        {
          "field": "ID",
          "labelKey": "webSessionColumnSession",
          "kind": "identifier"
        },
        {
          "field": "Username",
          "labelKey": "processColumnUser",
          "kind": "text"
        },
        {
          "field": "Application",
          "labelKey": "oauthResourceServerFieldApplication",
          "kind": "identifier"
        },
        {
          "field": "Timeout",
          "labelKey": "webSessionColumnExpires",
          "kind": "text"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "webSessionListEmptyAgent"
    },
    "rowTarget": {
      "route": "os-management/processes/details",
      "field": "SesProcessId"
    },
    "toolIdentifier": "webapp.sessions",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "multiSelect": null
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.X509CredentialList",
    "route": "security/x509",
    "area": "security",
    "labelKey": "x509ListLabel",
    "sideBarPosition": 2,
    "archetype": "list",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "x509-credential",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "create",
      "selfProtection": ""
    },
    "rowActions": [
      {
        "id": "delete",
        "selfProtection": ""
      }
    ],
    "context": {
      "fields": [
        "Alias",
        "OwnerList",
        "PeerNames",
        "CAFile",
        "SubjectDN",
        "IssuerDN",
        "ValidityNotBefore",
        "ValidityNotAfter"
      ],
      "secretFields": []
    },
    "secretArguments": [
      "Certificate",
      "PrivateKey",
      "PrivateKeyPassword"
    ],
    "emptyStateKey": "x509ListEmpty",
    "commandAliases": [
      "x509"
    ],
    "suggestedPrompts": [
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "x509CredentialListPrompt1"
      },
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "x509CredentialListPrompt2"
      },
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "x509CredentialListPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.X509Credentials",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "read": {
      "source": {
        "port": "admin",
        "endpoint": "Security.X509Credential",
        "type": "LIST",
        "rowGet": {
          "key": "Alias",
          "param": "alias",
          "type": "CERTINFO",
          "fields": [
            "SubjectDN",
            "IssuerDN",
            "ValidityNotBefore",
            "ValidityNotAfter"
          ],
          "derived": []
        }
      },
      "fields": [
        "Alias",
        "OwnerList",
        "PeerNames",
        "CAFile",
        "SubjectDN",
        "IssuerDN",
        "ValidityNotBefore",
        "ValidityNotAfter"
      ],
      "filter": [
        "Alias",
        "SubjectDN",
        "IssuerDN"
      ],
      "sort": {
        "fields": [
          "Alias",
          "SubjectDN",
          "IssuerDN",
          "ValidityNotAfter"
        ],
        "default": "Alias",
        "direction": "asc"
      },
      "paging": "cap"
    },
    "table": {
      "columns": [
        {
          "field": "Alias",
          "labelKey": "x509ColumnAlias",
          "kind": "name"
        },
        {
          "field": "SubjectDN",
          "labelKey": "x509ColumnSubject",
          "kind": "text"
        },
        {
          "field": "IssuerDN",
          "labelKey": "x509ColumnIssuer",
          "kind": "text"
        },
        {
          "field": "ValidityNotBefore",
          "labelKey": "x509ColumnValidFrom",
          "kind": "text"
        },
        {
          "field": "ValidityNotAfter",
          "labelKey": "x509ColumnValidUntil",
          "kind": "text"
        }
      ],
      "emptyNextKey": "",
      "emptyAgentKey": "x509ListEmptyAgent"
    },
    "toolIdentifier": "security.x509",
    "refreshDefault": 0,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.X509Form",
    "route": "security/x509/edit",
    "area": "security",
    "labelKey": "x509FormLabel",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": true,
    "refreshes": false,
    "refreshRates": [],
    "privileges": [
      {
        "resource": "%Admin_Secure",
        "permission": "USE"
      },
      {
        "resource": "%DB_IRISSYS",
        "permission": "READ"
      }
    ],
    "entityType": "x509-credential",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "",
    "id": {
      "kind": "single",
      "parts": []
    },
    "primaryAction": {
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": [
        "Certificate",
        "PrivateKey",
        "PrivateKeyPassword"
      ]
    },
    "secretArguments": [],
    "fingerprintExcludes": [],
    "emptyStateKey": "",
    "commandAliases": [],
    "suggestedPrompts": [
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "x509FormPrompt1"
      },
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "x509FormPrompt2"
      },
      {
        "groupKey": "sslPromptGroupConnections",
        "textKey": "x509FormPrompt3"
      }
    ],
    "classicPage": "%CSP.UI.Portal.X509Credential",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "security.x509form",
    "refreshDefault": 0,
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "multiSelect": null,
    "entityLabelKey": ""
  }
];
