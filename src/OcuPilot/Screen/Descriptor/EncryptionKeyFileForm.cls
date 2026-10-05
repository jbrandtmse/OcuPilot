/// <p>The encryption key file create form: one new key file, named by an allowed directory and a
/// relative file name, with its first administrator and key, rendered by its own
/// <code>form-page</code> (AD-5, Story 18.7). Its Save and the agent's confirmed
/// <code>security.encryptionkeyfile.create</code> are two callers of one tool (AD-55).</p>
/// <p><b>It takes no side-bar position</b>: it is reached from
/// <class>OcuPilot.Screen.Descriptor.EncryptionKeyFile</class>'s Create. It declares no read and no
/// action. Its pairs are the list's; its classic key is the classic create page (AD-44).</p>
Class OcuPilot.Screen.Descriptor.EncryptionKeyFileForm Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/encryption-key-file/create",
  "area": "security",
  "labelKey": "encryptionKeyFileFormLabel",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%Admin_FileSystemAccess", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Admin_FileSystemAccess", "permission": "USE"}],
  "entityType": "encryption-key-file",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": [], "secretFields": []},
  "secretArguments": [],
  "fingerprintExcludes": [],
  "emptyStateKey": "",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "encryptionKeyFileFormPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "encryptionKeyFileFormPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "encryptionKeyFileFormPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.EncryptionCreate",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "toolIdentifier": "security.encryptionkeyfileform"
}
}

}
