/// <p>Journal file databases: the databases one journal file holds records for, read as a list over
/// the <code>Databases</code> member of the file's own <code>Journal.File</code> <code>GET</code> (AD-36
/// as amended, Story 18.5): the read issues the <code>GET</code> once, with the vendor's
/// <code>maxRows</code> the cap plus one, and a 404 for an absent file reads as no rows.</p>
/// <p><b>It is a sub-resource of Journals and never listed</b> (<code>sideBarPosition</code> 0). Journal
/// file details issues its read for the file it shows (AD-5); its one criterion, <code>file</code>, is
/// that file's name, which the admin port accepts only as the instance's journal file list spells it
/// (AD-21's eighth case). Each row is one database, keyed within the file by its system file number
/// (<code>SFN</code>).</p>
/// <p><b>The privilege set is Journals'</b>, and the classic page is the summary page, which lists the
/// same databases (AD-44).</p>
Class OcuPilot.Screen.Descriptor.JournalFileDatabaseList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/journals/databases",
  "area": "os-management",
  "labelKey": "journalFileDatabaseListLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "journal-file-database",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "os-management/journals",
  "id": {"kind": "composite", "parts": ["SFN"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["SFN", "DatabasePathOrAlias"], "secretFields": []},
  "emptyStateKey": "journalFileDatabaseListEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "journalFileDatabaseListPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "journalFileDatabaseListPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "journalFileDatabaseListPrompt3"}
  ],
  "classicPage": "%cspapp.op.utilsysjournalsummary",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Journal.File", "type": "GET", "rows": "Databases"},
    "fields": ["SFN", "DatabasePathOrAlias"],
    "filter": ["DatabasePathOrAlias"],
    "sort": {"fields": ["SFN", "DatabasePathOrAlias"], "default": "SFN", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "file", "labelKey": "tableColumnName", "kind": "text", "maxLength": 1024, "hint": "One journal file, spelled as osmgmt.journals.read answers its Name."}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "DatabasePathOrAlias", "labelKey": "systemInfoDatabase", "kind": "name"},
      {"field": "SFN", "labelKey": "journalColumnSfn", "kind": "number"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "osmgmt.journalfiledatabases"
}
}

}
