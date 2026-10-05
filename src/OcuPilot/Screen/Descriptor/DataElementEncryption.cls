/// <p>Data element encryption: the instance's active data-element encryption keys, read through the
/// vendor's own <code>Security.Encryption.Key</code> <code>DATAELEMENTLIST</code> (AD-2, AD-36, Story
/// 18.22) as <code>{Id}</code> and drawn by <file>ui/src/app/areas/security/encryption-keys.page.ts</file>;
/// <code>security.dataelementencryption.read</code> answers the same rows. No read answers key material.
/// It is Security and secrets' tenth side-bar entry.</p>
/// <p><b>Its id is <code>none</code></b>: a row is a key, not an entity. Its write tools target the
/// singleton <code>data-element-encryption-keys</code> (AD-13). Activate key opens the page's dialog, the
/// screen's caller of <class>OcuPilot.Screen.Tool.DataElementKeyActivate</class>, which carries the key
/// file administrator's password as the declared secret <code>AdminPassword</code> (AD-56); Deactivate is
/// the rows' caller of <class>OcuPilot.Screen.Tool.DataElementKeyDeactivate</class> (AD-53).</p>
/// <p><b>Its pairs are Security's</b>, <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>: the
/// endpoint's <code>ResourcesOR()</code> and the classic page's <code>RESOURCE</code> are
/// <code>%Admin_Secure</code>. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.DataElementEncryption Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/data-element-encryption",
  "area": "security",
  "labelKey": "dataElementEncryptionLabel",
  "sideBarPosition": 10,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "data-element-encryption-keys",
  "entityLabelKey": "dataElementEncryptionEntity",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "activate", "selfProtection": ""},
  "rowActions": [{"id": "activate", "selfProtection": ""}, {"id": "deactivate", "selfProtection": ""}],
  "context": {"fields": ["Id"], "secretFields": []},
  "secretArguments": ["AdminPassword"],
  "emptyStateKey": "dataElementEncryptionEmpty",
  "commandAliases": ["data element encryption"],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupAccess", "textKey": "dataElementEncryptionPrompt1"},
    {"groupKey": "userPromptGroupAccess", "textKey": "dataElementEncryptionPrompt2"},
    {"groupKey": "userPromptGroupAccess", "textKey": "dataElementEncryptionPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.EncryptionManaged",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.Encryption.Key", "type": "DATAELEMENTLIST"},
    "fields": ["Id"],
    "filter": ["Id"],
    "sort": {"fields": ["Id"], "default": "Id", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Id", "labelKey": "encryptionKeyFileColumnId", "kind": "name"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "dataElementEncryptionEmptyAgent"
  },
  "toolIdentifier": "security.dataelementencryption"
}
}

}
