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

export type EntityTypeKey = 'web-application' | 'rest-service' | 'user' | 'role' | 'resource' | 'service' | 'ssl-configuration' | 'x509-credential' | 'ldap-configuration' | 'wallet-collection' | 'wallet-secret' | 'oauth2-client-configuration' | 'oauth2-server-definition' | 'oauth2-resource-server' | 'oauth2-server' | 'oauth2-server-client' | 'audit-event' | 'task' | 'task-history-entry' | 'process' | 'lock' | 'database' | 'device' | 'audit-record' | 'application-error' | 'log-entry';

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

/** Where a read's rows come from: one admin API LIST (AD-2, AD-36). */
export interface ReadSource {
  readonly port: 'admin';
  readonly endpoint: string;
  readonly type: 'LIST';
}

/** The fields a read sorts on, its default sort field and direction. */
export interface ReadSort {
  readonly fields: readonly string[];
  readonly default: string;
  readonly direction: 'asc' | 'desc';
}

/** A screen's one declared read (AD-36): the screen's list and its read tool both resolve through it. */
export interface ReadDeclaration {
  readonly source: ReadSource;
  readonly fields: readonly string[];
  readonly filter: readonly string[];
  readonly sort: ReadSort;
  readonly paging: 'cap';
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
  "log-entry"
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
    "read": null
  }
];
