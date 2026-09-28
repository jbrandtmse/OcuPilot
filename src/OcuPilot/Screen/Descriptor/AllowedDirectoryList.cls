/// <p>The Allowed directories list: the roots every server-path field may choose from, read through
/// <class>OcuPilot.Port.PathPort</class> (source <code>path</code>, AD-21's sixth case, AD-36) and
/// rendered by the <code>list</code> archetype's page from the declared <code>table</code> (AD-5).
/// The same read feeds its read tool and every <code>app-server-path-picker</code>, so the three
/// show one list.</p>
/// <p><b>Its rows are <code>{Directory, Restricted}</code>.</b> On an instance that restricts the
/// allow-list its file dialogs read, one row per allowed root, <code>Restricted</code> true;
/// otherwise the manager directory alone, <code>Restricted</code> false.</p>
/// <p><b>The privilege set is <code>%Admin_FileSystemAccess:USE</code> and
/// <code>%DB_IRISSYS:READ</code></b>, the port's own gate in the same order (AD-29). The first is
/// declared the screen's own, beyond the Security and secrets area's set, so a caller without it
/// loses this screen alone (AD-8).</p>
/// <p>Its scope is <code>instance</code> and its id <code>single</code>, the directory as the
/// instance answers it (AD-13). No classic page exists, so <code>classicPage</code> is empty and the
/// list links out to nothing (AD-44). It declares no action, so its empty state names what to do
/// next, and it does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.AllowedDirectoryList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/allowed-directories",
  "area": "security",
  "labelKey": "allowedDirectoriesLabel",
  "sideBarPosition": 7,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_FileSystemAccess", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Admin_FileSystemAccess", "permission": "USE"}],
  "entityType": "allowed-directory",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Directory", "Restricted"], "secretFields": []},
  "emptyStateKey": "allowedDirectoriesEmpty",
  "commandAliases": ["allow-list", "file access"],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupAccess", "textKey": "allowedDirectoryListPrompt1"},
    {"groupKey": "userPromptGroupAccess", "textKey": "allowedDirectoryListPrompt2"},
    {"groupKey": "userPromptGroupAccess", "textKey": "allowedDirectoryListPrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "path", "endpoint": "roots", "type": "LIST"},
    "fields": ["Directory", "Restricted"],
    "filter": ["Directory", "Restricted"],
    "sort": {"fields": ["Directory", "Restricted"], "default": "Directory", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Directory", "labelKey": "lockColumnDirectory", "kind": "name"},
      {"field": "Restricted", "labelKey": "allowedDirectoriesColumnRestricted", "kind": "status"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "security.alloweddirectories"
}
}

}
