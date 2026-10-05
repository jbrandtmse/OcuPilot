/// <p>Encryption key files: one key file's encryption keys, read through
/// <class>OcuPilot.Port.EncryptionPort</class> (source <code>encryption</code>, AD-21's sixth case,
/// AD-36, Story 18.7) from the <code>root</code> and <code>path</code> criteria the page's path picker
/// sends. Its page also issues <class>OcuPilot.Screen.Descriptor.EncryptionKeyFileAdminList</class>'s
/// read for the same file, so one page shows both lists (AD-5). It is Security and secrets' eighth
/// side-bar entry.</p>
/// <p><b>Its id is <code>none</code></b>: a row is a key, not an entity. Its write tools target the key
/// file, whose id is the composite of <code>root</code> and <code>path</code> (AD-13). Create opens
/// <class>OcuPilot.Screen.Descriptor.EncryptionKeyFileForm</class>; Add key and Remove are the screen's
/// callers of <class>OcuPilot.Screen.Tool.EncryptionKeyFileAddKey</class> and
/// <class>OcuPilot.Screen.Tool.EncryptionKeyFileRemoveKey</class> (AD-53). No read answers key
/// material.</p>
/// <p><b>Its pairs are Security's two and <code>%Admin_FileSystemAccess:USE</code></b>, declared its own
/// because every read and write resolves a key file through <class>OcuPilot.Port.PathPort</class> (AD-8,
/// AD-29). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.EncryptionKeyFile Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/encryption-key-file",
  "area": "security",
  "labelKey": "encryptionKeyFileLabel",
  "sideBarPosition": 8,
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
  "primaryAction": {"id": "create", "selfProtection": ""},
  "rowActions": [{"id": "addkey", "selfProtection": ""}, {"id": "removekey", "selfProtection": ""}],
  "context": {"fields": ["Id", "KeyLen", "Description"], "secretFields": []},
  "secretArguments": ["AdminPassword"],
  "emptyStateKey": "encryptionKeyFileKeysEmpty",
  "commandAliases": ["encryption", "encryption key file", "create key file"],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupAccess", "textKey": "encryptionKeyFilePrompt1"},
    {"groupKey": "userPromptGroupAccess", "textKey": "encryptionKeyFilePrompt2"},
    {"groupKey": "userPromptGroupAccess", "textKey": "encryptionKeyFilePrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.EncryptionManage",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "encryption", "endpoint": "Security.Encryption.KeyInFile", "type": "LIST"},
    "fields": ["Id", "KeyLen", "Description"],
    "filter": ["Id", "KeyLen", "Description"],
    "sort": {"fields": ["Id", "KeyLen", "Description"], "default": "Id", "direction": "asc"},
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
      {"field": "Id", "labelKey": "encryptionKeyFileColumnId", "kind": "name"},
      {"field": "KeyLen", "labelKey": "encryptionKeyFileColumnKeyLen", "kind": "number"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "encryptionKeyFileEmptyAgent"
  },
  "toolIdentifier": "security.encryptionkeyfile"
}
}

}
