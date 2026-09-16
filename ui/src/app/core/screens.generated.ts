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

export type EntityTypeKey = 'web-application' | 'rest-service' | 'user' | 'role' | 'resource' | 'service' | 'ssl-configuration' | 'x509-credential' | 'ldap-configuration' | 'wallet-collection' | 'wallet-secret' | 'oauth2-client-configuration' | 'oauth2-server-definition' | 'oauth2-resource-server' | 'oauth2-server' | 'oauth2-server-client' | 'audit-event' | 'task' | 'task-history-entry' | 'process' | 'lock' | 'database' | 'device' | 'audit-record' | 'application-error' | 'log-entry' | 'agent-definition';

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
  | 'list (server criteria)'
  | 'drill-down'
  | 'form-page'
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
}

/** A field a detail call derives on the instance from one of its detail fields (AD-36). */
export interface ReadDerived {
  readonly field: string;
  readonly rule: 'beforeToday';
  readonly from: string;
}

/**
 * The one per-row detail call a read may name (AD-36): the endpoint's GET, issued on the instance
 * for each row that survives the cap with `param` set to the row's `key`, merging `fields`
 * and setting `derived`.
 */
export interface ReadRowGet {
  readonly key: string;
  readonly param: string;
  readonly fields: readonly string[];
  readonly derived: readonly ReadDerived[];
}

/**
 * Where a read's rows come from (AD-36): one admin API LIST (AD-2) with an optional per-row detail
 * call, or one of OcuPilot's own kernel stores read whole (AD-9). A `state` source names the store
 * by its own name, declares no `rowGet` and no `criteria`, and is bounded by the same row cap.
 */
export interface ReadSource {
  readonly port: 'admin' | 'state';
  readonly endpoint: string;
  readonly type: 'LIST';
  readonly rowGet?: ReadRowGet | null;
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

/** One table column: the read field it shows, its header's string key and its kind. */
export interface TableColumn {
  readonly field: string;
  readonly labelKey: string;
  readonly kind: TableColumnKind;
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
  readonly secondaryEntityTypes: readonly string[];
  readonly scope: string;
  readonly parentScope: string;
  readonly id: IdAccessor;
  readonly context: ContextDeclaration;
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
  readonly toolIdentifier: string;
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
  "task",
  "task-history-entry",
  "process",
  "lock",
  "database",
  "device",
  "audit-record",
  "application-error",
  "log-entry",
  "agent-definition"
];

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
    "banner": null
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
    "banner": null
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
    "banner": null
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
    "banner": null
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
    "banner": null
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
    "banner": null
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
    "banner": null
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
        "Type",
        "Namespace",
        "Description",
        "Id",
        "LastFinished",
        "NextScheduled"
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
        "type": "LIST"
      },
      "fields": [
        "Name",
        "Type",
        "Namespace",
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
    "toolIdentifier": "tasks.schedule"
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
      "id": "",
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
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "permissions.users",
    "banner": null
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
        "Enabled",
        "DispatchClass",
        "Resource"
      ],
      "secretFields": []
    },
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
      "emptyNextKey": "tableReadOnlyEmptyNext",
      "emptyAgentKey": ""
    },
    "toolIdentifier": "webapp.list",
    "banner": null
  }
];
