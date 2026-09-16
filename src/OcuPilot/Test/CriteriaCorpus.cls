/// <p>The one corpus both engines of the <code>read.criteria</code> grammar run (AD-21):
/// <method>OcuPilot.Screen.Registry.CriteriaProblem</method> in <class>OcuPilot.Test.ReadTool</class>
/// and <code>criteriaProblem</code> in <file>ui/tools/screen-mirror.test.mjs</file>, which reads
/// this block off disk. Each case replaces <code>declaration.read.criteria</code> with its own
/// <code>criteria</code> and names the exact sentence both engines return, or <code>null</code> for
/// a sound shape. A case may also set <code>refreshes</code>, which is how the last rule -- a
/// criteria-bearing screen never auto-refreshes -- is exercised, and may replace
/// <code>read.source.port</code>, which is how the admin-port rule is. A later story that extends
/// the grammar adds its cases here.</p>
/// <p><b>Every criterion carries a <code>maxLength</code></b> (DW-279), including the ones whose
/// case refuses for another reason: the bound is checked after <code>kind</code> and before
/// <code>options</code>, so a case that omitted it would get the maxLength sentence rather than
/// the one it names. The cases that omit it deliberately are the ones that say so.</p>
Class OcuPilot.Test.CriteriaCorpus Extends %RegisteredObject
{

XData Cases
{
{
  "declaration": {
    "route": "logs/criteria-corpus", "area": "logs", "labelKey": "auditListLabel", "sideBarPosition": 1,
    "archetype": "list", "built": false, "refreshes": false, "refreshRates": [],
    "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
    "entityType": "audit-record", "secondaryEntityTypes": [],
    "scope": "instance", "parentScope": "", "id": {"kind": "single", "parts": []},
    "primaryAction": {"id": "", "selfProtection": ""}, "rowActions": [],
    "context": {"fields": ["Event", "EventSource", "EventType"], "secretFields": []},
    "emptyStateKey": "auditListEmpty", "commandAliases": [], "classicPage": "",
    "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
    "read": {
      "source": {"port": "admin", "endpoint": "Security.Audit.Record", "type": "LIST"},
      "fields": ["Event", "EventSource", "EventType"],
      "filter": ["Event", "EventSource", "EventType"],
      "sort": {"fields": ["Event", "EventSource", "EventType"], "default": "Event", "direction": "asc"},
      "paging": "cap",
      "criteria": {
        "fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": 50}],
        "marker": {"param": "eventSources", "value": "OcuPilot", "labelKey": "auditMarkerFilterLabel"}
      }
    },
    "table": {
      "columns": [{"field": "Event", "labelKey": "auditColumnEventName", "kind": "name"}, {"field": "EventSource", "labelKey": "auditColumnEventSource", "kind": "text"}],
      "emptyNextKey": "tableReadOnlyEmptyNext", "emptyAgentKey": ""
    },
    "toolIdentifier": "logs.criteriacorpus"
  },
  "cases": [
    {"name": "the sound shape", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": 50}], "marker": {"param": "eventSources", "value": "OcuPilot", "labelKey": "auditMarkerFilterLabel"}}, "expected": null},
    {"name": "a null criteria block declares no server search", "criteria": null, "expected": null},
    {"name": "a criteria block with no marker is sound", "criteria": {"fields": [{"param": "beginDateTime", "labelKey": "auditCriteriaBegin", "kind": "datetime", "maxLength": 50}]}, "expected": null},
    {"name": "a null marker is a block with no marker", "criteria": {"fields": [{"param": "beginDateTime", "labelKey": "auditCriteriaBegin", "kind": "datetime", "maxLength": 50}], "marker": null}, "expected": null},
    {"name": "every declared kind is admitted", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": 50}, {"param": "beginDateTime", "labelKey": "auditCriteriaBegin", "kind": "datetime", "maxLength": 50}, {"param": "authentication", "labelKey": "auditCriteriaAuthentication", "kind": "choice", "maxLength": 50, "options": ["Password", "Unauthenticated"]}]}, "expected": null},
    {"name": "an array is not an object", "criteria": [], "expected": "read.criteria is not an object declaring its fields and marker (AD-21)"},
    {"name": "a string is not an object", "criteria": "eventSources", "expected": "read.criteria is not an object declaring its fields and marker (AD-21)"},
    {"name": "an unknown key in the block", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": 50}], "jsonSearch": true}, "expected": "read.criteria declares the unknown key 'jsonSearch'"},
    {"name": "fields that are not an array", "criteria": {"fields": "eventSources"}, "expected": "read.criteria.fields is not an array of criterion declarations"},
    {"name": "no criterion at all", "criteria": {"fields": []}, "expected": "read.criteria.fields is empty, and a declared criteria block carries at least one criterion (AD-21)"},
    {"name": "a criterion that is not an object", "criteria": {"fields": ["eventSources"]}, "expected": "read.criteria.fields entry #1 is not an object declaring its param, labelKey and kind"},
    {"name": "an unknown key on a criterion", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": 50, "placeholder": "Any"}]}, "expected": "read.criteria.fields entry #1 declares the unknown key 'placeholder'"},
    {"name": "options on a kind that is not choice", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": 50, "options": ["OcuPilot"]}]}, "expected": "read.criteria.fields entry #1 declares the unknown key 'options'"},
    {"name": "a missing param", "criteria": {"fields": [{"labelKey": "auditColumnEventSource", "kind": "text"}]}, "expected": "read.criteria.fields entry #1 param '' is not a query parameter name"},
    {"name": "a param that is not a name", "criteria": {"fields": [{"param": "event-sources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": 50}]}, "expected": "read.criteria.fields entry #1 param 'event-sources' is not a query parameter name"},
    {"name": "the row cap's own parameter is reserved", "criteria": {"fields": [{"param": "maxRows", "labelKey": "tableMaxRowsLabel", "kind": "text", "maxLength": 50}]}, "expected": "read.criteria.fields entry #1 param 'maxRows' collides with a name the read's own callers already send"},
    {"name": "and it is reserved whatever its case, because the vendor upper-cases query keys", "criteria": {"fields": [{"param": "MaxRows", "labelKey": "tableMaxRowsLabel", "kind": "text", "maxLength": 50}]}, "expected": "read.criteria.fields entry #1 param 'MaxRows' collides with a name the read's own callers already send"},
    {"name": "and so is each of the read tool's own arguments, which criteria are added after", "criteria": {"fields": [{"param": "sort", "labelKey": "sortControlLabel", "kind": "text", "maxLength": 50}]}, "expected": "read.criteria.fields entry #1 param 'sort' collides with a name the read's own callers already send"},
    {"name": "filter is the tool's too", "criteria": {"fields": [{"param": "filter", "labelKey": "commandBarFilterLabel", "kind": "text", "maxLength": 50}]}, "expected": "read.criteria.fields entry #1 param 'filter' collides with a name the read's own callers already send"},
    {"name": "and direction", "criteria": {"fields": [{"param": "direction", "labelKey": "sortDirectionAscending", "kind": "text", "maxLength": 50}]}, "expected": "read.criteria.fields entry #1 param 'direction' collides with a name the read's own callers already send"},
    {"name": "and the scope key every request already carries", "criteria": {"fields": [{"param": "ns", "labelKey": "headerNamespaceLabel", "kind": "text", "maxLength": 50}]}, "expected": "read.criteria.fields entry #1 param 'ns' collides with a name the read's own callers already send"},
    {"name": "a repeated param", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": 50}, {"param": "eventSources", "labelKey": "auditColumnEventType", "kind": "text", "maxLength": 50}]}, "expected": "read.criteria.fields entry #2 names the param 'eventSources' twice"},
    {"name": "a param repeated in another case", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": 50}, {"param": "EventSources", "labelKey": "auditColumnEventType", "kind": "text", "maxLength": 50}]}, "expected": "read.criteria.fields entry #2 names the param 'EventSources' twice"},
    {"name": "an empty label key", "criteria": {"fields": [{"param": "eventSources", "labelKey": "", "kind": "text", "maxLength": 50}]}, "expected": "read.criteria.fields entry #1 labelKey is empty, and a criterion's control names a string key"},
    {"name": "a kind outside the closed set", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "combobox", "maxLength": 50}]}, "expected": "read.criteria.fields entry #1 kind 'combobox' is not one of text,datetime,choice"},
    {"name": "a choice with no options", "criteria": {"fields": [{"param": "authentication", "labelKey": "auditCriteriaAuthentication", "kind": "choice", "maxLength": 50}]}, "expected": "read.criteria.fields entry #1 kind 'choice' declares no options, and a choice criterion is validated against a declared enum (AD-21)"},
    {"name": "a choice with an empty option list", "criteria": {"fields": [{"param": "authentication", "labelKey": "auditCriteriaAuthentication", "kind": "choice", "maxLength": 50, "options": []}]}, "expected": "read.criteria.fields entry #1 options is empty, and a choice criterion is validated against a declared enum (AD-21)"},
    {"name": "an option that is not a value", "criteria": {"fields": [{"param": "authentication", "labelKey": "auditCriteriaAuthentication", "kind": "choice", "maxLength": 50, "options": ["Password", ""]}]}, "expected": "read.criteria.fields entry #1 options entry #2 is not a non-empty value"},
    {"name": "a repeated option", "criteria": {"fields": [{"param": "authentication", "labelKey": "auditCriteriaAuthentication", "kind": "choice", "maxLength": 50, "options": ["Password", "Password"]}]}, "expected": "read.criteria.fields entry #1 options names 'Password' twice"},
    {"name": "a marker that is not an object", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": 50}], "marker": "OcuPilot"}, "expected": "read.criteria.marker is not an object declaring its param, value and labelKey"},
    {"name": "an unknown key on the marker", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": 50}], "marker": {"param": "eventSources", "value": "OcuPilot", "labelKey": "auditMarkerFilterLabel", "default": true}}, "expected": "read.criteria.marker declares the unknown key 'default'"},
    {"name": "a marker over a criterion the form does not carry", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": 50}], "marker": {"param": "events", "value": "OcuPilot", "labelKey": "auditMarkerFilterLabel"}}, "expected": "read.criteria.marker.param 'events' is not one of read.criteria.fields, and the marker overrides a declared criterion rather than adding one"},
    {"name": "a marker with no value", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": 50}], "marker": {"param": "eventSources", "value": "", "labelKey": "auditMarkerFilterLabel"}}, "expected": "read.criteria.marker.value is empty, and the marker filter sends one declared value"},
    {"name": "a marker with no label key", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": 50}], "marker": {"param": "eventSources", "value": "OcuPilot", "labelKey": ""}}, "expected": "read.criteria.marker.labelKey is empty, and the marker filter names a string key"},
    {"name": "criteria on a port that is neither admin nor mgmnt", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": 50}]}, "port": "monitor", "expected": "read.criteria is declared on a 'monitor' source, and server criteria travel on the admin and mgmnt ports alone (AD-21)"},
    {"name": "criteria on the mgmnt port are sound", "criteria": {"fields": [{"param": "application", "labelKey": "tableColumnName", "kind": "text", "maxLength": 256}]}, "port": "mgmnt", "expected": null},
    {"name": "criteria on a state source are refused by this rule too", "criteria": {"fields": [{"param": "application", "labelKey": "tableColumnName", "kind": "text", "maxLength": 256}]}, "port": "state", "expected": "read.criteria is declared on a 'state' source, and server criteria travel on the admin and mgmnt ports alone (AD-21)"},
    {"name": "a criteria-bearing screen that also declares auto-refresh", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": 50}]}, "refreshes": true, "expected": "refreshes is declared with read.criteria, and a screen that searches on the server renders nothing until Search and does not auto-refresh (AD-43)"},
    {"name": "and auto-refresh alone, with no criteria, is outside this rule", "criteria": null, "refreshes": true, "expected": null},
    {"name": "a large bound is sound, because the vendor's own properties run to 1000", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": 1000}]}, "expected": null},
    {"name": "a criterion declaring no maxLength at all", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text"}]}, "expected": "read.criteria.fields entry #1 declares no maxLength, and every criterion declares the length its vendor property accepts (AD-21)"},
    {"name": "and it is required on a choice criterion too, before its options are read", "criteria": {"fields": [{"param": "authentication", "labelKey": "auditCriteriaAuthentication", "kind": "choice", "options": ["Password"]}]}, "expected": "read.criteria.fields entry #1 declares no maxLength, and every criterion declares the length its vendor property accepts (AD-21)"},
    {"name": "the second criterion is the one missing it", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": 50}, {"param": "events", "labelKey": "auditColumnEventName", "kind": "text"}]}, "expected": "read.criteria.fields entry #2 declares no maxLength, and every criterion declares the length its vendor property accepts (AD-21)"},
    {"name": "a maxLength of zero bounds nothing", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": 0}]}, "expected": "read.criteria.fields entry #1 maxLength '0' is not a whole number above zero"},
    {"name": "a negative maxLength", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": -1}]}, "expected": "read.criteria.fields entry #1 maxLength '-1' is not a whole number above zero"},
    {"name": "a fractional maxLength", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": 1.5}]}, "expected": "read.criteria.fields entry #1 maxLength '1.5' is not a whole number above zero"},
    {"name": "a maxLength written as a string", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": "50"}]}, "expected": "read.criteria.fields entry #1 maxLength '50' is not a whole number above zero"},
    {"name": "a null maxLength is not an absent one", "criteria": {"fields": [{"param": "eventSources", "labelKey": "auditColumnEventSource", "kind": "text", "maxLength": null}]}, "expected": "read.criteria.fields entry #1 maxLength '' is not a whole number above zero"}
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
            Set tSC = $$$ERROR($$$GeneralError, "the corpus XData block is missing")
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

/// <p>The corpus declaration with <var>pCase</var>'s <code>criteria</code> in place, its
/// <code>refreshes</code> when the case declares one, and its <code>read.source.port</code> when
/// the case names one, as a new object.</p>
ClassMethod DeclarationFor(pCorpus As %DynamicObject, pCase As %DynamicObject) As %DynamicObject
{
    Set tDeclaration = ##class(%DynamicObject).%FromJSON(pCorpus.declaration.%ToJSON())
    Set tRead = tDeclaration.read
    Set tType = pCase.%GetTypeOf("criteria")
    If tType = "null" {
        Do tRead.%Set("criteria", "", "null")
    } ElseIf (tType = "object") || (tType = "array") {
        Do tRead.%Set("criteria", ##class(%DynamicAbstractObject).%FromJSON(pCase.criteria.%ToJSON()))
    } Else {
        Do tRead.%Set("criteria", pCase.%Get("criteria"), tType)
    }
    If pCase.%GetTypeOf("refreshes") = "boolean" Do tDeclaration.%Set("refreshes", ''pCase.refreshes, "boolean")
    If pCase.%GetTypeOf("port") = "string" Do tRead.source.%Set("port", pCase.port)
    Quit tDeclaration
}

}
