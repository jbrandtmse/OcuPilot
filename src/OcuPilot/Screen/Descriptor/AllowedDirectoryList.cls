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
/// list links out to nothing (AD-44). It does not refresh (AD-43).</p>
/// <p><b>Its actions are Add, Change and Remove</b> (Story 18.46): <code>add</code> is the primary action, and
/// <code>change</code> and <code>remove</code> are row actions the <code>allowed-directory-fallback</code> rule explains on the
/// unrestricted manager-directory row. All three go through <code>POST /allowed-directories</code>
/// (<class>OcuPilot.Area.Security.AllowedDirectorySave</class>), which asks the governance key
/// <code>security.alloweddirectories.update</code>; <code>GET /allowed-directories</code> answers that key's verdict, which
/// the screen draws the actions off with while the key is disabled. The write tool is unadvertised and declares no
/// <code>SCREENACTIONS</code>, so the screen action route never reaches it (AD-53). The empty state says that no file or
/// directory field can choose a location, because an emptied list allows nothing.</p>
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
  "primaryAction": {"id": "add", "selfProtection": ""},
  "rowActions": [{"id": "change", "selfProtection": "allowed-directory-fallback"}, {"id": "remove", "selfProtection": "allowed-directory-fallback"}],
  "context": {"fields": ["Directory", "Restricted"], "secretFields": []},
  "emptyStateKey": "allowedDirectoriesEmptyNone",
  "commandAliases": ["allow-list", "file access"],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupAccess", "textKey": "allowedDirectoryListPrompt1"},
    {"groupKey": "userPromptGroupAccess", "textKey": "allowedDirectoryListPrompt2"},
    {"groupKey": "userPromptGroupAccess", "textKey": "allowedDirectoryListPrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "allowed directory",
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
    "emptyNextKey": "",
    "emptyAgentKey": "allowedDirectoriesAgentHint"
  },
  "toolIdentifier": "security.alloweddirectories"
}
}

}
