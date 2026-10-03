/// <p>Journal settings: where and how the instance journals, one <code>form-page</code> over the
/// vendor's <code>Journal.Settings</code> <code>GET</code> (AD-5, AD-36, Story 18.18), so the form and
/// <code>osmgmt.journalsettings.read</code> answer one read of the thirteen fields. OS management's
/// fourteenth entry, after Journals, though the classic page is in System Administration.</p>
/// <p><b>Its pairs are the classic page's own check</b>: <code>%CSP.UI.Portal.Journal</code>'s
/// <code>%OnPreHTTP</code> requires <code>%Admin_Manage</code> and <code>%Admin_Journal</code>
/// together, while the admin API takes either, so <code>%Admin_Journal:USE</code> is this screen's own
/// pair beside OS management's set (AD-8).</p>
/// <p><b>Its write is <class>OcuPilot.Screen.Tool.JournalSettingsUpdate</class></b>, reached by the
/// page's own Save (<class>OcuPilot.Area.OsMgmt.JournalSave</class>) and by the agent's confirmed
/// proposal (AD-55). The archive target and the write-image journal are shown and never set (AD-4).
/// It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.JournalSettings Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/journal-settings",
  "area": "os-management",
  "labelKey": "journalSettingsLabel",
  "sideBarPosition": 14,
  "archetype": "form-page",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Manage", "permission": "USE"}, {"resource": "%Admin_Journal", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Admin_Journal", "permission": "USE"}],
  "entityType": "journal-settings",
  "entityLabelKey": "journalSettingsLabel",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["CurrentDirectory", "AlternateDirectory", "FileSizeLimit", "JournalFilePrefix", "ArchiveName", "PurgeArchived", "DaysBeforePurge", "BackupsBeforePurge", "FreezeOnError", "JournalcspSession", "CompressFiles", "wijdir", "targwijsz"], "secretFields": []},
  "emptyStateKey": "",
  "commandAliases": ["journal settings"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupCapacity", "textKey": "journalSettingsPrompt1"},
    {"groupKey": "promptGroupCapacity", "textKey": "journalSettingsPrompt2"},
    {"groupKey": "promptGroupCapacity", "textKey": "journalSettingsPrompt3"}
  ],
  "classicPage": "%CSP.UI.Portal.Journal",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Journal.Settings", "type": "GET"},
    "fields": ["CurrentDirectory", "AlternateDirectory", "FileSizeLimit", "JournalFilePrefix", "ArchiveName", "PurgeArchived", "DaysBeforePurge", "BackupsBeforePurge", "FreezeOnError", "JournalcspSession", "CompressFiles", "wijdir", "targwijsz"],
    "filter": ["CurrentDirectory"],
    "sort": {"fields": ["CurrentDirectory"], "default": "CurrentDirectory", "direction": "asc"},
    "paging": "cap"
  },
  "toolIdentifier": "osmgmt.journalsettings"
}
}

}
