/// <p>Journals: the instance's journal files, newest first, read through the vendor's own
/// <code>Journal.File</code> <code>LIST</code> (<code>%SYS.Journal.File:ByTimeReverseOrder</code>, AD-2,
/// AD-36) and rendered by this screen's own page (Story 18.5). Each row is one file, keyed by its full
/// name as the instance's list spells it (AD-13): that spelling is the only one any journal route
/// accepts (AD-21's eighth case).</p>
/// <p><b>Its row actions</b> are Switch file and Switch directory, drawn at screen level on the
/// literal target <code>current</code>, and Check integrity on the selected file, each carried out
/// for both callers by one write tool through <class>OcuPilot.Port.JournalPort</class> (AD-51, AD-53):
/// <class>OcuPilot.Screen.Tool.JournalSwitchFile</class>,
/// <class>OcuPilot.Screen.Tool.JournalSwitchDirectory</class> and
/// <class>OcuPilot.Screen.Tool.JournalIntegrityCheck</class>. Each warns first; none removes data. A
/// file's name opens Journal file details (<class>OcuPilot.Screen.Descriptor.JournalFileDetails</class>).</p>
/// <p><b>The privilege set is OS management's operate half, <code>%Admin_Operate:USE</code>, with
/// <code>%DB_IRISSYS:READ</code></b>: the endpoint's <code>ResourcesOR()</code> names
/// <code>%Admin_Operate</code>, and the classic Journals page is its replaced page (AD-44). It does not
/// refresh (AD-43): a switch's change event re-reads it.</p>
Class OcuPilot.Screen.Descriptor.JournalList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/journals",
  "area": "os-management",
  "labelKey": "journalListLabel",
  "sideBarPosition": 13,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "journal-file",
  "entityLabelKey": "aboutJournalFile",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Name"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "switchfile", "selfProtection": ""}, {"id": "switchdirectory", "selfProtection": ""}, {"id": "integrity", "selfProtection": ""}],
  "context": {"fields": ["Name", "Size", "CreationTime", "Reason", "DataSize"], "secretFields": []},
  "emptyStateKey": "journalListEmpty",
  "commandAliases": ["journals", "journal files"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupCapacity", "textKey": "journalListPrompt1"},
    {"groupKey": "promptGroupCapacity", "textKey": "journalListPrompt2"},
    {"groupKey": "promptGroupCapacity", "textKey": "journalListPrompt3"}
  ],
  "classicPage": "%cspapp.op.utilsysjournals",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Journal.File", "type": "LIST"},
    "fields": ["Name", "Size", "CreationTime", "Reason", "DataSize"],
    "filter": ["Name", "CreationTime", "Reason"],
    "sort": {"fields": ["Name", "Size", "CreationTime", "Reason", "DataSize"], "default": "CreationTime", "direction": "desc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "CreationTime", "labelKey": "journalColumnCreated", "kind": "text"},
      {"field": "Size", "labelKey": "databaseColumnSize", "kind": "number"},
      {"field": "DataSize", "labelKey": "journalColumnDataSize", "kind": "number"},
      {"field": "Reason", "labelKey": "agentSwitchesFieldReason", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "journalListEmptyAgent"
  },
  "toolIdentifier": "osmgmt.journals"
}
}

}
