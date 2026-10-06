/// <p>Encryption startup settings: how the instance activates its database encryption keys at startup,
/// which system databases, journal files and audit log it encrypts, and which active key is the default and
/// the journal key, one <code>form-page</code> over the vendor's <code>Security.Encryption.Settings</code>
/// <code>GET</code> (AD-5, AD-36, Story 18.23), so the form and <code>security.encryptionstartup.read</code>
/// answer one read of the nine settings. No read answers a password or key material.</p>
/// <p><b>It is unlisted</b> (<code>sideBarPosition</code> 0), reached from Database encryption's "Configure
/// startup settings" link, and its page also issues Database encryption's declared read for the active
/// keys (AD-5).</p>
/// <p><b>Its pairs are Security's</b>, <code>%Admin_Secure:USE</code> and <code>%DB_IRISSYS:READ</code>: the
/// endpoint's <code>ResourcesOR()</code> and the classic page's <code>RESOURCE</code> are
/// <code>%Admin_Secure</code>, and a principal holding exactly the two read and wrote the settings (AD-8,
/// measured at Task 0).</p>
/// <p><b>Its write is <class>OcuPilot.Screen.Tool.EncryptionStartupUpdate</class></b>, reached by the page's
/// own Save (<class>OcuPilot.Area.Security.EncryptionStartupSave</class>) and by the agent's confirmed
/// proposal (AD-55), whose declared secret is the startup administrator's <code>AdminPassword</code>
/// (AD-56); its form read is <code>GET /encryption-startup/form</code>. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.EncryptionStartup Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "security/database-encryption/startup",
  "area": "security",
  "labelKey": "encryptionStartupLabel",
  "sideBarPosition": 0,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "encryption-startup",
  "entityLabelKey": "encryptionStartupLabel",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["DBEncStartMode", "DBEncJournal", "DBEncIRISSecurity", "DBEncIRISTemp", "AuditEncrypt", "DBEncStartKMIPServer", "DBEncStartKeyFile", "DBEncDefaultKeyID", "DBEncJournalKeyID"], "secretFields": []},
  "secretArguments": ["AdminPassword"],
  "emptyStateKey": "",
  "commandAliases": ["encryption startup", "startup settings"],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupAccess", "textKey": "encryptionStartupPrompt1"},
    {"groupKey": "userPromptGroupAccess", "textKey": "encryptionStartupPrompt2"},
    {"groupKey": "userPromptGroupAccess", "textKey": "encryptionStartupPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.EncryptionDatabase",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Security.Encryption.Settings", "type": "GET"},
    "fields": ["DBEncStartMode", "DBEncJournal", "DBEncIRISSecurity", "DBEncIRISTemp", "AuditEncrypt", "DBEncStartKMIPServer", "DBEncStartKeyFile", "DBEncDefaultKeyID", "DBEncJournalKeyID"],
    "filter": ["DBEncStartMode"],
    "sort": {"fields": ["DBEncStartMode"], "default": "DBEncStartMode", "direction": "asc"},
    "paging": "cap"
  },
  "toolIdentifier": "security.encryptionstartup"
}
}

}
