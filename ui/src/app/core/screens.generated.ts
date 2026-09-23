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

export type EntityTypeKey = 'web-application' | 'rest-service' | 'user' | 'role' | 'resource' | 'service' | 'ssl-configuration' | 'x509-credential' | 'ldap-configuration' | 'wallet-collection' | 'wallet-secret' | 'oauth2-client-configuration' | 'oauth2-server-definition' | 'oauth2-resource-server' | 'oauth2-server' | 'oauth2-server-client' | 'audit-event' | 'auditing-configuration' | 'task' | 'task-history-entry' | 'process' | 'lock' | 'database' | 'device' | 'audit-record' | 'application-error' | 'log-entry' | 'agent-definition' | 'agent-switch';

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
  readonly rule: 'beforeToday';
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
  readonly type?: 'GET' | 'INFO' | 'CERTINFO';
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
}

/**
 * Where a read's rows come from (AD-36): one admin API LIST (AD-2) with an optional per-row detail
 * call, one of OcuPilot's own kernel stores read whole (AD-9), the management API's port, or one
 * instance log file's bounded tail. A `state` source names the store by its own name, declares no
 * `rowGet` and no `criteria`, and is bounded by the same row cap; a `mgmnt` or
 * `logsource` source declares no `rowGet`.
 */
export interface ReadSource {
  readonly port: 'admin' | 'state' | 'mgmnt' | 'logsource';
  readonly endpoint: string;
  /**
   * `LIST` reads rows; `GET` reads one object as the one row, and a 404 reads as none;
   * `UPCOMING` reads an admin endpoint's scheduled occurrences as rows; `HISTORY` reads its task-run history;
   * `VOLUMELIST` reads a database's own volume files as rows.
   */
  readonly type: 'LIST' | 'GET' | 'UPCOMING' | 'HISTORY' | 'VOLUMELIST';
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
  readonly options?: readonly string[];
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
}

/** Where a banner's value comes from: one admin API GET (AD-2). */
export interface BannerSource {
  readonly port: 'admin';
  readonly endpoint: string;
  readonly type: 'GET';
}

/** The `.ocu-banner-*` variants a declared banner may take (DESIGN.md `:1203`). */
export type BannerSeverity = 'info' | 'warning' | 'restrained';

/** One value a banner's field may take, and the sentence it raises (DW-270). */
export interface BannerCase {
  readonly equals: string;
  readonly messageKey: string;
  readonly severity: BannerSeverity;
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
  readonly privileges: readonly PrivilegePair[];
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
  "agent-switch"
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
  "process": "integer",
  "application-error": "foldcase",
  "role": "foldcase",
  "resource": "foldcase"
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
      },
      {
        "resource": "%Admin_Wallet",
        "permission": "USE"
      },
      {
        "resource": "%Admin_OAuth2_Client",
        "permission": "USE"
      },
      {
        "resource": "%Admin_OAuth2_Server",
        "permission": "USE"
      },
      {
        "resource": "%Admin_OAuth2_Registration",
        "permission": "USE"
      }
    ]
  },
  {
    "key": "agent",
    "railPosition": 8,
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
    "classicPage": "",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "agent.definition",
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
    "classicPage": "",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "agent.switches",
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
            "maxLength": 50
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
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.AuditingConfig",
    "route": "security/auditing",
    "area": "security",
    "labelKey": "auditingConfigurationLink",
    "sideBarPosition": 0,
    "archetype": "form-page",
    "built": false,
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
    "rowActions": [],
    "context": {
      "fields": [],
      "secretFields": []
    },
    "emptyStateKey": "",
    "commandAliases": [],
    "classicPage": "%CSP.UI.Portal.Audit.SystemEvents",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "security.auditing",
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "secretArguments": [],
    "fingerprintExcludes": []
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
    "rowActions": [],
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
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "osmgmt.databasedetails",
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "osmgmt.databases",
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.DeviceList",
    "route": "os-management/devices",
    "area": "os-management",
    "labelKey": "deviceListLabel",
    "sideBarPosition": 5,
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
      "id": "",
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
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "osmgmt.devices",
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
    "context": {
      "fields": [],
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
    "secretArguments": [],
    "fingerprintExcludes": [],
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
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Name",
        "Enabled",
        "Description",
        "LDAPCACertFile"
      ],
      "secretFields": []
    },
    "emptyStateKey": "ldapListEmpty",
    "commandAliases": [
      "kerberos"
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
        "type": "LIST"
      },
      "fields": [
        "Name",
        "Enabled",
        "Description",
        "LDAPCACertFile"
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
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "security.ldap",
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
    "rowActions": [],
    "context": {
      "fields": [
        "Pid",
        "OSUserName",
        "RoutineInfo",
        "ModeCount",
        "Reference",
        "Directory",
        "System",
        "DeleteID"
      ],
      "secretFields": []
    },
    "emptyStateKey": "lockListEmpty",
    "commandAliases": [
      "locks",
      "lock table"
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
        "DeleteID"
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
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "rowTarget": {
      "route": "os-management/processes/details",
      "field": "Pid"
    },
    "toolIdentifier": "osmgmt.locks",
    "banner": null,
    "tab": null,
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
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
    "rowActions": [],
    "context": {
      "fields": [
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
    "classicPage": "%cspapp.op.utilsysapperrornamespaces",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "logs.applicationerrors",
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
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
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
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
    "emptyStateKey": "oauthClientsEmpty",
    "commandAliases": [],
    "classicPage": "%CSP.UI.Portal.OAuth2.Client.ConfigurationList",
    "classicLinkExemption": {
      "exempt": true,
      "reason": "Edited in the classic portal until the OAuth 2.0 editors ship (Epic 12); counted against SM-C1",
      "label": "OAuth 2.0 Client Configuration",
      "href": "/csp/sys/sec/%25CSP.UI.Portal.OAuth2.Client.Configuration.zen",
      "rowLink": {
        "params": [
          {
            "name": "PID",
            "field": "ApplicationName"
          },
          {
            "name": "IssuerEndpointID",
            "field": "ServerDefinitionID"
          },
          {
            "name": "IssuerEndpoint",
            "field": "IssuerEndpoint"
          }
        ]
      }
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
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "security/oauth",
      "position": 2,
      "labelKey": "oauthTabClients"
    },
    "toolIdentifier": "security.oauthclients",
    "banner": null,
    "rowTarget": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
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
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Name",
        "ServerDefinition"
      ],
      "secretFields": []
    },
    "emptyStateKey": "oauthResourceServersEmpty",
    "commandAliases": [],
    "classicPage": "%CSP.UI.Portal.OAuth2.ResourceServer.ConfigurationList",
    "classicLinkExemption": {
      "exempt": true,
      "reason": "Edited in the classic portal until the OAuth 2.0 editors ship (Epic 12); counted against SM-C1",
      "label": "OAuth 2.0 Resource Server Configuration",
      "href": "/csp/sys/sec/%25CSP.UI.Portal.OAuth2.ResourceServer.Configuration.zen",
      "rowLink": {
        "params": [
          {
            "name": "PID",
            "field": "Name"
          }
        ]
      }
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
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "security/oauth",
      "position": 3,
      "labelKey": "oauthTabResourceServers"
    },
    "toolIdentifier": "security.oauthresourceservers",
    "banner": null,
    "rowTarget": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
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
    "entityType": "oauth2-server-client",
    "secondaryEntityTypes": [
      "oauth2-server"
    ],
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
        "ClientId",
        "ClientType",
        "RedirectURL",
        "Description"
      ],
      "secretFields": []
    },
    "emptyStateKey": "oauthServerClientsEmpty",
    "commandAliases": [],
    "classicPage": "%CSP.UI.Portal.OAuth2.Server.ClientList",
    "classicLinkExemption": {
      "exempt": true,
      "reason": "Edited in the classic portal until the OAuth 2.0 editors ship (Epic 12); counted against SM-C1",
      "label": "OAuth 2.0 Authorization Server Client Configuration",
      "href": "/csp/sys/sec/%25CSP.UI.Portal.OAuth2.Server.Client.zen",
      "rowLink": {
        "params": [
          {
            "name": "ClientId",
            "field": "ClientId"
          }
        ]
      }
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
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "security/oauth",
      "position": 5,
      "labelKey": "oauthTabServerClients"
    },
    "toolIdentifier": "security.oauthserverclients",
    "banner": null,
    "rowTarget": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
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
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "ID",
        "IssuerEndpoint",
        "ClientCount",
        "ResourceCount"
      ],
      "secretFields": []
    },
    "emptyStateKey": "oauthServerDescriptionsEmpty",
    "commandAliases": [
      "oauth"
    ],
    "classicPage": "%CSP.UI.Portal.OAuth2.Client.ServerList",
    "classicLinkExemption": {
      "exempt": true,
      "reason": "Edited in the classic portal until the OAuth 2.0 editors ship (Epic 12); counted against SM-C1",
      "label": "OAuth 2.0 Client Configuration",
      "href": "/csp/sys/sec/%25CSP.UI.Portal.OAuth2.Client.ServerConfiguration.zen",
      "rowLink": {
        "params": [
          {
            "name": "PID",
            "field": "ID"
          }
        ]
      }
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
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "security/oauth",
      "position": 1,
      "labelKey": "oauthTabServerDescriptions"
    },
    "toolIdentifier": "security.oauthserverdescriptions",
    "banner": null,
    "rowTarget": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
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
    "emptyStateKey": "oauthServerEmpty",
    "commandAliases": [],
    "classicPage": "%CSP.UI.Portal.OAuth2.Server.Configuration",
    "classicLinkExemption": {
      "exempt": true,
      "reason": "Edited in the classic portal until the OAuth 2.0 editors ship (Epic 12); counted against SM-C1",
      "label": "OAuth 2.0 Authorization Server Configuration",
      "href": "/csp/sys/sec/%25CSP.UI.Portal.OAuth2.Server.Configuration.zen",
      "rowLink": {
        "params": []
      }
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
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "tab": {
      "group": "security/oauth",
      "position": 4,
      "labelKey": "oauthTabServer"
    },
    "toolIdentifier": "security.oauthserver",
    "banner": null,
    "rowTarget": null,
    "secretArguments": [],
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
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
    "rowActions": [],
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
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "osmgmt.processdetails",
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
        "Pid",
        "Username",
        "Nspace",
        "Routine",
        "State",
        "Commands",
        "Globals"
      ],
      "secretFields": []
    },
    "emptyStateKey": "processListEmpty",
    "commandAliases": [
      "jobs"
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
        "Globals"
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
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "osmgmt.processes",
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
    "rowActions": [],
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
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.RoleForm",
    "route": "permissions/roles/edit",
    "area": "permissions",
    "labelKey": "roleFormLabel",
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
    "classicPage": "%CSP.UI.Portal.Role",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "permissions.roleform",
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
    "rowActions": [],
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
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
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
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
      "id": "",
      "selfProtection": ""
    },
    "rowActions": [],
    "context": {
      "fields": [
        "Name",
        "Description",
        "Enabled",
        "Type"
      ],
      "secretFields": []
    },
    "emptyStateKey": "sslListEmpty",
    "commandAliases": [
      "certificates"
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
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "security.ssl",
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
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
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
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
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
        "Namespace",
        "Type",
        "Description",
        "Id",
        "LastFinished"
      ],
      "secretFields": []
    },
    "emptyStateKey": "taskOnDemandEmpty",
    "commandAliases": [
      "on demand",
      "run task"
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
        "LastFinished"
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
          "LastFinished"
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
        }
      ],
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "tasks.ondemand",
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
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
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
    "rowActions": [],
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
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
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
          "severity": "warning"
        },
        {
          "equals": "Not running",
          "messageKey": "taskManagerStoppedBanner",
          "severity": "warning"
        }
      ]
    },
    "toolIdentifier": "tasks.schedule",
    "tab": null,
    "rowTarget": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
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
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.UserForm",
    "route": "permissions/users/edit",
    "area": "permissions",
    "labelKey": "userFormLabel",
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
    "classicPage": "%CSP.UI.Portal.User",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "permissions.userform",
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
    "rowActions": [],
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
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
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
    "entityType": "wallet-secret",
    "secondaryEntityTypes": [],
    "scope": "instance",
    "parentScope": "security/wallet",
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
        "Type"
      ],
      "secretFields": []
    },
    "emptyStateKey": "walletSecretListEmpty",
    "commandAliases": [],
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
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "security.secrets",
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "secretArguments": [],
    "fingerprintExcludes": [],
    "entityLabelKey": ""
  },
  {
    "descriptor": "OcuPilot.Screen.Descriptor.WebAppForm",
    "route": "web-applications/list/edit",
    "area": "web-applications",
    "labelKey": "webAppFormLabel",
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
    "classicPage": "%CSP.UI.Portal.Applications.Web",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "webapp.form",
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
    "rowActions": [],
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
    "banner": null,
    "tab": null,
    "rowTarget": null
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
    "rowActions": [],
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
    "banner": null,
    "tab": null,
    "rowTarget": null,
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
    "classicPage": "%CSP.UI.Portal.X509Credential",
    "classicLinkExemption": {
      "exempt": false,
      "reason": "",
      "label": "",
      "href": ""
    },
    "toolIdentifier": "security.x509form",
    "read": null,
    "table": null,
    "banner": null,
    "tab": null,
    "rowTarget": null,
    "entityLabelKey": ""
  }
];
