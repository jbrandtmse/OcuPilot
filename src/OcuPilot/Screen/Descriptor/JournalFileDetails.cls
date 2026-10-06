/// <p>Journal file details: one journal file's summary, read through the vendor's own
/// <code>Journal.File</code> <code>GET</code> (AD-2, AD-36) and rendered by this screen's own page,
/// which also issues <class>OcuPilot.Screen.Descriptor.JournalFileDatabaseList</class>'s read for the
/// databases the file holds records for (AD-5, Story 18.5).</p>
/// <p><b>It is a sub-resource of Journals and never listed</b> (<code>sideBarPosition</code> 0),
/// reached from the list's name cell at <code>os-management/journals/details/&lt;Name&gt;</code>. Its
/// one criterion, <code>file</code>, is filled from that route id and seeded onto the answer as
/// <code>Name</code>; a name the instance's journal file list does not answer is refused
/// <code>JOURNAL.FILE.UNLISTED</code> before the vendor is called for it (AD-21's eighth case).</p>
/// <p><b>Its fields are the summary's scalars</b>, the previous and next files projected from their
/// objects (<code>PrevFile.File</code>, <code>NextFile.File</code>); the database list and the mirror
/// figures are not among them.</p>
/// <p><b>The privilege set is Journals'</b>, and the classic page is the summary page the classic
/// Journals list opens (AD-44).</p>
Class OcuPilot.Screen.Descriptor.JournalFileDetails Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/journals/details",
  "area": "os-management",
  "labelKey": "journalFileDetailsLabel",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "journal-file",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "os-management/journals",
  "id": {"kind": "composite", "parts": ["Name"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {
    "fields": ["Name", "CreationTime", "FileCount", "MaxSize", "FileGUID", "FirstRecordAddress", "LastRecordAddress", "End", "EncryptionKeyID", "MinTransFileCount", "MinTransFileIndex", "ClusterStartTime", "PrevFile.File", "NextFile.File"],
    "secretFields": []
  },
  "emptyStateKey": "journalFileDetailsGone",
  "commandAliases": ["journal file details"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "journalFileDetailsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "journalFileDetailsPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "journalFileDetailsPrompt3"}
  ],
  "classicPage": "%cspapp.op.utilsysjournalsummary",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Journal.File", "type": "GET"},
    "fields": ["Name", "CreationTime", "FileCount", "MaxSize", "FileGUID", "FirstRecordAddress", "LastRecordAddress", "End", "EncryptionKeyID", "MinTransFileCount", "MinTransFileIndex", "ClusterStartTime", "PrevFile.File", "NextFile.File"],
    "filter": ["Name", "CreationTime", "FileGUID", "EncryptionKeyID", "PrevFile.File", "NextFile.File"],
    "sort": {"fields": ["Name", "CreationTime"], "default": "Name", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "file", "labelKey": "tableColumnName", "kind": "text", "maxLength": 1024, "hint": "One journal file, spelled as osmgmt.journals.read answers its Name."}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "CreationTime", "labelKey": "journalColumnCreated", "kind": "text"},
      {"field": "FileGUID", "labelKey": "journalDetailsGuid", "kind": "identifier"},
      {"field": "FileCount", "labelKey": "journalDetailsFileCount", "kind": "number"},
      {"field": "MaxSize", "labelKey": "databaseColumnMaxSize", "kind": "number"},
      {"field": "FirstRecordAddress", "labelKey": "journalDetailsFirstRecord", "kind": "number"},
      {"field": "LastRecordAddress", "labelKey": "journalDetailsLastRecord", "kind": "number"},
      {"field": "End", "labelKey": "journalDetailsEnd", "kind": "number"},
      {"field": "EncryptionKeyID", "labelKey": "journalDetailsEncryption", "kind": "identifier", "emptyKey": "journalDetailsNotEncrypted"},
      {"field": "MinTransFileCount", "labelKey": "journalDetailsMinTransCount", "kind": "number"},
      {"field": "MinTransFileIndex", "labelKey": "journalDetailsMinTransIndex", "kind": "number"},
      {"field": "ClusterStartTime", "labelKey": "journalDetailsClusterStart", "kind": "text"},
      {"field": "PrevFile.File", "labelKey": "journalDetailsPrevious", "kind": "identifier"},
      {"field": "NextFile.File", "labelKey": "journalDetailsNext", "kind": "identifier"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "osmgmt.journalfile"
}
}

}
