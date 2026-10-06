/// <p>Database encryption: the instance's active database encryption keys, read through the vendor's own
/// <code>Security.Encryption.Key</code> <code>LIST</code> (AD-2, AD-36, Story 18.22) as
/// <code>{Id, KeyLen, IsDefault}</code> and drawn by
/// <file>ui/src/app/areas/security/encryption-keys.page.ts</file>; <code>security.databaseencryption.read</code>
/// answers the same rows. No read answers key material. It is Security and secrets' ninth side-bar
/// entry.</p>
/// <p><b>Its id is <code>none</code></b>: a row is a key, not an entity. Its write tools target the
/// singleton <code>database-encryption-keys</code> (AD-13). Activate key opens the page's dialog, the
/// screen's caller of <class>OcuPilot.Screen.Tool.DatabaseKeyActivate</class>, which carries the key file
/// administrator's password as the declared secret <code>AdminPassword</code> (AD-56); Deactivate is the
/// rows' caller of <class>OcuPilot.Screen.Tool.DatabaseKeyDeactivate</class> (AD-53).</p>
/// <p><b>Its pairs are Security's</b>, <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>: the
/// endpoint's <code>ResourcesOR()</code> and the classic page's <code>RESOURCE</code> are
/// <code>%Admin_Secure</code>. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.DatabaseEncryption Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/database-encryption",
  "area": "security",
  "labelKey": "databaseEncryptionLabel",
  "sideBarPosition": 9,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "database-encryption-keys",
  "entityLabelKey": "databaseEncryptionEntity",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "activate", "selfProtection": ""},
  "rowActions": [{"id": "activate", "selfProtection": ""}, {"id": "deactivate", "selfProtection": ""}],
  "context": {"fields": ["Id", "KeyLen", "IsDefault"], "secretFields": []},
  "secretArguments": ["AdminPassword"],
  "emptyStateKey": "databaseEncryptionEmpty",
  "commandAliases": ["database encryption", "activate database key"],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupAccess", "textKey": "databaseEncryptionPrompt1"},
    {"groupKey": "userPromptGroupAccess", "textKey": "databaseEncryptionPrompt2"},
    {"groupKey": "userPromptGroupAccess", "textKey": "databaseEncryptionPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.EncryptionDatabase",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.Encryption.Key", "type": "LIST"},
    "fields": ["Id", "KeyLen", "IsDefault"],
    "filter": ["Id"],
    "sort": {"fields": ["Id", "KeyLen", "IsDefault"], "default": "Id", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Id", "labelKey": "encryptionKeyFileColumnId", "kind": "name"},
      {"field": "KeyLen", "labelKey": "encryptionKeyFileColumnKeyLen", "kind": "number"},
      {"field": "IsDefault", "labelKey": "tableColumnDefault", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "databaseEncryptionEmptyAgent"
  },
  "toolIdentifier": "security.databaseencryption"
}
}

}
