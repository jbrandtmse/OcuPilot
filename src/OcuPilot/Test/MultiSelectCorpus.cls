/// <p>The one corpus both engines of the <code>multiSelect</code> grammar run (AD-5, Story 16.6):
/// <method>OcuPilot.Screen.Registry.MultiSelectProblem</method> in
/// <class>OcuPilot.Test.Descriptor</class>, and <code>multiSelectProblem</code> in
/// <file>ui/tools/screen-mirror.test.mjs</file>, which reads this block off disk.</p>
/// <p>Each <code>Cases</code> entry replaces <code>declaration.multiSelect</code> with its own (a bare
/// value, for the shapes that are not objects at all), or overrides <code>archetype</code>,
/// <code>read</code>, <code>table</code> or <code>rowActions</code> alone, leaving the shared
/// declaration's own sound <code>multiSelect</code> in place, and names the exact sentence both
/// engines return, or <code>null</code> when it is sound.</p>
Class OcuPilot.Test.MultiSelectCorpus Extends %RegisteredObject
{

XData Cases
{
{
  "declaration": {
    "route": "os-management/multi-select-corpus", "area": "os-management", "labelKey": "processListLabel", "sideBarPosition": 0,
    "archetype": "list", "built": false, "refreshes": false, "refreshRates": [],
    "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
    "entityType": "process", "secondaryEntityTypes": [],
    "scope": "instance", "parentScope": "", "id": {"kind": "single", "parts": []},
    "primaryAction": {"id": "", "selfProtection": ""}, "rowActions": [{"id": "broadcast", "selfProtection": ""}, {"id": "resume", "selfProtection": ""}],
    "context": {"fields": ["Pid", "CanReceiveBroadcast"], "secretFields": []},
    "emptyStateKey": "processListEmpty", "commandAliases": [], "classicPage": "",
    "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
    "read": {
      "source": {"port": "admin", "endpoint": "Process", "type": "LIST"},
      "fields": ["Pid", "CanReceiveBroadcast"],
      "filter": ["Pid"],
      "sort": {"fields": ["Pid"], "default": "Pid", "direction": "asc"},
      "paging": "cap"
    },
    "table": {
      "columns": [{"field": "Pid", "labelKey": "processColumnPid", "kind": "name"}],
      "emptyNextKey": "tableReadOnlyEmptyNext", "emptyAgentKey": ""
    },
    "toolIdentifier": "osmgmt.multiselectcorpus",
    "multiSelect": {"action": "broadcast", "eligible": "CanReceiveBroadcast", "max": 20, "ineligibleKey": "processBroadcastIneligible", "extraActions": []}
  },
  "cases": [
    {"name": "the Processes shape is sound", "expected": null},
    {"name": "no multiSelect declared is sound", "multiSelect": null, "expected": null},
    {"name": "a max of one is sound", "multiSelect": {"action": "broadcast", "eligible": "CanReceiveBroadcast", "max": 1, "ineligibleKey": "processBroadcastIneligible"}, "expected": null},
    {"name": "a max of a thousand is sound", "multiSelect": {"action": "broadcast", "eligible": "CanReceiveBroadcast", "max": 1000, "ineligibleKey": "processBroadcastIneligible"}, "expected": null},
    {"name": "a string is not an object", "multiSelect": "broadcast", "expected": "multiSelect is not an object naming its action, eligible field, max and ineligibleKey (AD-5)"},
    {"name": "an array is not an object", "multiSelect": ["broadcast"], "expected": "multiSelect is not an object naming its action, eligible field, max and ineligibleKey (AD-5)"},
    {"name": "an unknown key", "multiSelect": {"action": "broadcast", "eligible": "CanReceiveBroadcast", "max": 20, "ineligibleKey": "processBroadcastIneligible", "label": "Broadcast"}, "expected": "multiSelect declares the unknown key 'label'"},
    {"name": "a detail archetype is not a list", "archetype": "detail", "expected": "multiSelect is declared on a 'detail' archetype, and a multi-select is a list's own (AD-5)"},
    {"name": "no read", "read": null, "expected": "multiSelect is declared without a read, and its eligible field is one of read.fields (AD-5)"},
    {"name": "no table", "table": null, "expected": "multiSelect is declared without a table, and its checkboxes are drawn in the table (AD-5)"},
    {"name": "an empty action", "multiSelect": {"action": "", "eligible": "CanReceiveBroadcast", "max": 20, "ineligibleKey": "processBroadcastIneligible"}, "expected": "multiSelect.action is empty, and a multi-select names the row action it acts through"},
    {"name": "an action no row action declares", "multiSelect": {"action": "terminate", "eligible": "CanReceiveBroadcast", "max": 20, "ineligibleKey": "processBroadcastIneligible"}, "expected": "multiSelect.action 'terminate' is not one of rowActions"},
    {"name": "no row actions at all", "rowActions": [], "expected": "multiSelect.action 'broadcast' is not one of rowActions"},
    {"name": "an empty eligible field", "multiSelect": {"action": "broadcast", "eligible": "", "max": 20, "ineligibleKey": "processBroadcastIneligible"}, "expected": "multiSelect.eligible is empty, and a multi-select names the read field that makes a row checkable"},
    {"name": "an eligible field outside read.fields", "multiSelect": {"action": "broadcast", "eligible": "CanBeTerminated", "max": 20, "ineligibleKey": "processBroadcastIneligible"}, "expected": "multiSelect.eligible 'CanBeTerminated' is not one of read.fields"},
    {"name": "a max of zero", "multiSelect": {"action": "broadcast", "eligible": "CanReceiveBroadcast", "max": 0, "ineligibleKey": "processBroadcastIneligible"}, "expected": "multiSelect.max must be a whole number from 1 to 1000"},
    {"name": "a max above a thousand", "multiSelect": {"action": "broadcast", "eligible": "CanReceiveBroadcast", "max": 1001, "ineligibleKey": "processBroadcastIneligible"}, "expected": "multiSelect.max must be a whole number from 1 to 1000"},
    {"name": "a fractional max", "multiSelect": {"action": "broadcast", "eligible": "CanReceiveBroadcast", "max": 2.5, "ineligibleKey": "processBroadcastIneligible"}, "expected": "multiSelect.max must be a whole number from 1 to 1000"},
    {"name": "a max spelled as a string", "multiSelect": {"action": "broadcast", "eligible": "CanReceiveBroadcast", "max": "20", "ineligibleKey": "processBroadcastIneligible"}, "expected": "multiSelect.max must be a whole number from 1 to 1000"},
    {"name": "no max", "multiSelect": {"action": "broadcast", "eligible": "CanReceiveBroadcast", "ineligibleKey": "processBroadcastIneligible"}, "expected": "multiSelect.max must be a whole number from 1 to 1000"},
    {"name": "an empty ineligibleKey", "multiSelect": {"action": "broadcast", "eligible": "CanReceiveBroadcast", "max": 20, "ineligibleKey": ""}, "expected": "multiSelect.ineligibleKey is empty, and a multi-select names the string key an ineligible row's checkbox reads"},
    {"name": "a list (server criteria) archetype is sound", "archetype": "list (server criteria)", "expected": null},
    {"name": "a log-viewer archetype is not a list the table checks", "archetype": "log-viewer", "expected": "multiSelect is declared on a 'log-viewer' archetype, and a multi-select is a list's own (AD-5)"},
    {"name": "no eligible field and no ineligibleKey is sound", "multiSelect": {"action": "broadcast", "max": 100}, "expected": null},
    {"name": "an ineligibleKey without an eligible field", "multiSelect": {"action": "broadcast", "max": 100, "ineligibleKey": "processBroadcastIneligible"}, "expected": "multiSelect.ineligibleKey is declared without multiSelect.eligible, and the two are declared together"},
    {"name": "an eligible field without an ineligibleKey", "multiSelect": {"action": "broadcast", "eligible": "CanReceiveBroadcast", "max": 20}, "expected": "multiSelect.ineligibleKey is empty, and a multi-select names the string key an ineligible row's checkbox reads"},
    {"name": "an extra action is sound", "multiSelect": {"action": "broadcast", "max": 100, "extraActions": ["resume"]}, "expected": null},
    {"name": "extraActions spelled as a string", "multiSelect": {"action": "broadcast", "max": 100, "extraActions": "resume"}, "expected": "multiSelect.extraActions is not an array of row action ids"},
    {"name": "an empty extra action", "multiSelect": {"action": "broadcast", "max": 100, "extraActions": [""]}, "expected": "multiSelect.extraActions is not an array of row action ids"},
    {"name": "an extra action no row action declares", "multiSelect": {"action": "broadcast", "max": 100, "extraActions": ["terminate"]}, "expected": "multiSelect.extraActions names 'terminate', which is not one of rowActions"},
    {"name": "the multi-select's own action as an extra one", "multiSelect": {"action": "broadcast", "max": 100, "extraActions": ["broadcast"]}, "expected": "multiSelect.extraActions names 'broadcast', which is the multi-select's own action"},
    {"name": "an extra action named twice", "multiSelect": {"action": "broadcast", "max": 100, "extraActions": ["resume", "resume"]}, "expected": "multiSelect.extraActions names 'resume' more than once"}
  ]
}
}

/// <p>The corpus as a <class>%DynamicObject</class>: <code>{declaration, cases}</code>.</p>
ClassMethod Corpus(Output pCorpus As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pCorpus = ""
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), "Cases", , .tOpenSC)
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "the Cases XData block is missing")
            Quit
        }
        Do tXData.Data.Rewind()
        Set pCorpus = ##class(%DynamicObject).%FromJSON(tXData.Data)
    } Catch ex {
        Set pCorpus = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The corpus declaration with <var>pCase</var>'s <code>multiSelect</code> in place when it
/// carries one -- an object, an array, a bare string or <code>null</code> -- and its
/// <code>archetype</code>, <code>rowActions</code>, <code>read</code> or <code>table</code> when it
/// carries any, as a new object.</p>
ClassMethod DeclarationFor(pCorpus As %DynamicObject, pCase As %DynamicObject) As %DynamicObject
{
    Set tDeclaration = ##class(%DynamicObject).%FromJSON(pCorpus.declaration.%ToJSON())
    Set tType = pCase.%GetTypeOf("multiSelect")
    If (tType = "object") || (tType = "array") {
        Do tDeclaration.%Set("multiSelect", ##class(%DynamicAbstractObject).%FromJSON(pCase.%Get("multiSelect").%ToJSON()))
    } ElseIf tType = "null" {
        Do tDeclaration.%Set("multiSelect", "", "null")
    } ElseIf tType = "string" {
        Do tDeclaration.%Set("multiSelect", pCase.%Get("multiSelect"))
    }
    If pCase.%GetTypeOf("archetype") = "string" Do tDeclaration.%Set("archetype", pCase.%Get("archetype"))
    If pCase.%GetTypeOf("rowActions") = "array" Do tDeclaration.%Set("rowActions", ##class(%DynamicArray).%FromJSON(pCase.%Get("rowActions").%ToJSON()))
    If pCase.%GetTypeOf("read") = "null" Do tDeclaration.%Set("read", "", "null")
    If pCase.%GetTypeOf("table") = "null" Do tDeclaration.%Set("table", "", "null")
    Quit tDeclaration
}

}
