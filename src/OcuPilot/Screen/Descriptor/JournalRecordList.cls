/// <p>Journal records (Story 18.19): one journal file's records, read through the vendor's own
/// <code>Journal.Record</code> <code>LIST</code> (AD-2, AD-36) and rendered by this screen's own page.
/// It is unlisted: Journal file details' View records opens it with a screen arrival carrying the
/// file, and Next records continues from the read's own rows.</p>
/// <p><b>Its six criteria are the classic record browser's search</b> (AD-21): the file, the offset,
/// the order, and a filter of one column, one comparison and one value. The column and the comparison
/// are closed choices, the classic page's own sets, because the vendor splices the comparison into code
/// it executes; <class>OcuPilot.Port.AdminPort</class> refuses anything else for every caller. Each
/// criterion declares a <code>hint</code>, the description its read tool publishes.</p>
/// <p><b>Its rows carry the eight columns the vendor's list answers and never a record's value</b>
/// (AD-36): <code>NewValue</code>, <code>OldValue</code> and <code>GlobalReference</code> reach only
/// the journal record detail dialog, through <class>OcuPilot.Area.OsMgmt.JournalRecordDetail</class>,
/// which no tool reaches. An omitted file reads the newest listed file (AD-21's eighth case).</p>
/// <p><b>The privilege set is Journals' own</b>, <code>%Admin_Operate:USE</code> and
/// <code>%DB_IRISSYS:READ</code>: a principal holding exactly those listed and read records (measured at
/// Story 18.19's Task 0). It has no action and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.JournalRecordList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/journal-records",
  "area": "os-management",
  "labelKey": "journalRecordListLabel",
  "sideBarPosition": 0,
  "archetype": "list (server criteria)",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "journal-record",
  "entityLabelKey": "aboutJournalRecord",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Address"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Address", "TimeStamp", "ProcessID", "TypeName", "ExtTypeName", "InTransaction", "GlobalNode", "DatabaseName"], "secretFields": []},
  "emptyStateKey": "journalRecordListEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "journalRecordListPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "journalRecordListPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "journalRecordListPrompt3"}
  ],
  "classicPage": "%cspapp.op.utilsysjournal",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "admin", "endpoint": "Journal.Record", "type": "LIST"},
    "fields": ["Address", "TimeStamp", "ProcessID", "TypeName", "ExtTypeName", "InTransaction", "GlobalNode", "DatabaseName"],
    "filter": ["GlobalNode", "DatabaseName", "TypeName"],
    "sort": {"fields": ["Address", "TimeStamp", "ProcessID", "TypeName", "ExtTypeName", "InTransaction", "GlobalNode", "DatabaseName"], "default": "Address", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "file", "labelKey": "aboutJournalFile", "kind": "text", "maxLength": 1024, "hint": "The journal file to read, spelled as osmgmt.journals.read answers its Name; omit it to read the current file."},
        {"param": "offset", "labelKey": "journalRecordOffset", "kind": "text", "maxLength": 20, "vendorParam": "initialOffset", "hint": "A whole-number record address to start from, that record included; to continue after a page, send the page's highest Address plus 1, or in order 1 its lowest Address minus 1."},
        {"param": "order", "labelKey": "journalRecordOrder", "kind": "choice", "maxLength": 1, "options": ["0", "1"], "default": "0", "vendorParam": "reverse", "hint": "0 lists records in file order from the offset or the file's start, and 1 in reverse from the offset or the file's end."},
        {"param": "column", "labelKey": "journalRecordColumn", "kind": "choice", "maxLength": 18, "options": ["TimeStamp", "ProcessID", "TypeName", "ExtTypeName", "InTransaction", "GlobalNode", "DatabaseName", "MirrorDatabaseName"], "default": "GlobalNode", "vendorParam": "matchColumnName", "hint": "The record column the value is compared with, compared only when a value is given."},
        {"param": "operator", "labelKey": "journalRecordComparison", "kind": "choice", "maxLength": 3, "options": ["=", "'=", "]]", "']]", "[", "'["], "default": "[", "vendorParam": "matchOperator", "hint": "How the column is compared with the value: = equals, '= does not equal, ]] sorts after, ']] does not sort after, [ contains, '[ does not contain."},
        {"param": "value", "labelKey": "errorLogColumnValue", "kind": "text", "maxLength": 200, "vendorParam": "matchValue", "hint": "The text the column is compared with; omit it to list every record unfiltered."}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Address", "labelKey": "journalRecordOffset", "kind": "name"},
      {"field": "TimeStamp", "labelKey": "auditColumnTime", "kind": "text"},
      {"field": "ProcessID", "labelKey": "proposalEntityProcess", "kind": "identifier"},
      {"field": "TypeName", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "ExtTypeName", "labelKey": "journalRecordExtendedType", "kind": "text"},
      {"field": "InTransaction", "labelKey": "processDetailsInTransaction", "kind": "status"},
      {"field": "GlobalNode", "labelKey": "journalRecordGlobalNode", "kind": "text"},
      {"field": "DatabaseName", "labelKey": "systemInfoDatabase", "kind": "identifier"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "osmgmt.journalrecords"
}
}

}
