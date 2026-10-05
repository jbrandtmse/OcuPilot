/// <p>The administrators of one encryption key file, read through
/// <class>OcuPilot.Port.EncryptionPort</class> (source <code>encryption</code>, AD-36, Story 18.7) from
/// the same <code>root</code> and <code>path</code> criteria as
/// <class>OcuPilot.Screen.Descriptor.EncryptionKeyFile</class>, whose page issues this read beside its
/// own (AD-5). It takes no side-bar position.</p>
/// <p><b>Its id is <code>none</code></b>: a row is an administrator's name, which the vendor stores in
/// upper case. Add administrator and Remove are the screen's callers of
/// <class>OcuPilot.Screen.Tool.EncryptionKeyFileAddAdmin</class> and
/// <class>OcuPilot.Screen.Tool.EncryptionKeyFileRemoveAdmin</class>, whose target is the key file
/// (AD-13, AD-53). Its pairs are its sibling's (AD-8).</p>
Class OcuPilot.Screen.Descriptor.EncryptionKeyFileAdminList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/encryption-key-file/administrators",
  "area": "security",
  "labelKey": "encryptionKeyFileAdminsTitle",
  "sideBarPosition": 0,
  "archetype": "list (server criteria)",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%Admin_FileSystemAccess", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Admin_FileSystemAccess", "permission": "USE"}],
  "entityType": "encryption-key-file",
  "entityLabelKey": "aboutEncryptionKeyFile",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "addadministrator", "selfProtection": ""}, {"id": "removeadministrator", "selfProtection": ""}],
  "context": {"fields": ["Name"], "secretFields": []},
  "secretArguments": ["OldAdminPassword", "NewAdminPassword"],
  "emptyStateKey": "encryptionKeyFileAdminsEmpty",
  "commandAliases": ["key file administrators"],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupAccess", "textKey": "encryptionKeyFileAdminsPrompt1"},
    {"groupKey": "userPromptGroupAccess", "textKey": "encryptionKeyFileAdminsPrompt2"},
    {"groupKey": "userPromptGroupAccess", "textKey": "encryptionKeyFileAdminsPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.EncryptionManage",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "encryption", "endpoint": "Security.Encryption.AdminInFile", "type": "LIST"},
    "fields": ["Name"],
    "filter": ["Name"],
    "sort": {"fields": ["Name"], "default": "Name", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "root", "labelKey": "pathPickerRootLabel", "kind": "text", "maxLength": 1024, "hint": "An allowed directory exactly as the Allowed directories screen lists it."},
        {"param": "path", "labelKey": "pathPickerFileLabel", "kind": "text", "maxLength": 807, "hint": "The key file's name under that directory, up to eight /-separated parts."}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "encryptionKeyFileColumnAdmin", "kind": "name"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "encryptionKeyFileEmptyAgent"
  },
  "toolIdentifier": "security.encryptionkeyfileadmins"
}
}

}
