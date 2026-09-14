/// <p>The one corpus both engines of the <code>banner</code> grammar run:
/// <method>OcuPilot.Screen.Registry.BannerProblem</method> in <class>OcuPilot.Test.ReadTool</class>
/// and <code>bannerProblem</code> in <file>ui/tools/screen-mirror.test.mjs</file>, which reads this
/// block off disk. Each case replaces the sound declaration's <code>banner</code> with its own and
/// names the exact sentence both engines return, or <code>null</code> for a shape neither refuses.
/// A case may also drop the declaration's <code>read</code> and <code>table</code> by declaring
/// itself <code>readless</code>, which is how the last rule -- a banner on a screen with no read --
/// is exercised. A later story that changes the grammar adds its cases here.</p>
/// <p><b>Every replaced scalar is a string or absent</b>, because the two engines render a JSON
/// boolean into a refusal sentence differently (<code>%Get</code> answers <code>1</code> where
/// <code>String</code> answers <code>true</code>). The shapes a descriptor can plausibly be
/// misauthored into are all covered by string values.</p>
Class OcuPilot.Test.BannerCorpus Extends %RegisteredObject
{

XData Cases
{
{
  "declaration": {
    "route": "tasks/banner-corpus", "area": "tasks", "labelKey": "taskListLabel", "sideBarPosition": 1,
    "archetype": "list", "built": false, "refreshes": false, "refreshRates": [],
    "privileges": [{"resource": "%Admin_Task", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
    "entityType": "task", "secondaryEntityTypes": [],
    "scope": "instance", "parentScope": "", "id": {"kind": "single", "parts": []},
    "primaryAction": {"id": "", "selfProtection": ""}, "rowActions": [],
    "context": {"fields": ["Name", "Namespace"], "secretFields": []},
    "emptyStateKey": "taskListEmpty", "commandAliases": [], "classicPage": "",
    "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
    "read": {
      "source": {"port": "admin", "endpoint": "Task.CRUD", "type": "LIST"},
      "fields": ["Name", "Namespace"],
      "filter": ["Name", "Namespace"],
      "sort": {"fields": ["Name", "Namespace"], "default": "Name", "direction": "asc"},
      "paging": "cap"
    },
    "table": {
      "columns": [{"field": "Name", "labelKey": "tableColumnName", "kind": "name"}, {"field": "Namespace", "labelKey": "headerNamespaceLabel", "kind": "text"}],
      "emptyNextKey": "tableReadOnlyEmptyNext", "emptyAgentKey": ""
    },
    "toolIdentifier": "tasks.bannercorpus"
  },
  "cases": [
    {"name": "the sound shape", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}, "expected": null},
    {"name": "a null banner declares no banner", "readless": false, "banner": null, "expected": null},
    {"name": "the other two severities are sound", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "info"}, "expected": null},
    {"name": "a readless declaration with no banner is outside the rule", "readless": true, "banner": null, "expected": null},
    {"name": "an array is not an object", "readless": false, "banner": [], "expected": "banner is not an object naming its source, field, equals, messageKey and severity"},
    {"name": "a string is not an object", "readless": false, "banner": "taskManagerSuspendedBanner", "expected": "banner is not an object naming its source, field, equals, messageKey and severity"},
    {"name": "an unknown key on the banner", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning", "action": "Resume"}, "expected": "banner declares the unknown key 'action'"},
    {"name": "a missing source", "readless": false, "banner": {"field": "Status", "equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}, "expected": "banner.source is not an object naming its port, endpoint and type"},
    {"name": "a source that is not an object", "readless": false, "banner": {"source": "Task.Manager", "field": "Status", "equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}, "expected": "banner.source is not an object naming its port, endpoint and type"},
    {"name": "an unknown key on the source", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET", "rowGet": "Name"}, "field": "Status", "equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}, "expected": "banner.source declares the unknown key 'rowGet'"},
    {"name": "a port that is not the admin port", "readless": false, "banner": {"source": {"port": "monitor", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}, "expected": "banner.source.port 'monitor' is not 'admin', the one port a Release 1 read names (AD-2)"},
    {"name": "a missing port", "readless": false, "banner": {"source": {"endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}, "expected": "banner.source.port '' is not 'admin', the one port a Release 1 read names (AD-2)"},
    {"name": "an endpoint that is not a package-relative name", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "/api/admin/task-manager", "type": "GET"}, "field": "Status", "equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}, "expected": "banner.source.endpoint '/api/admin/task-manager' is not a package-relative endpoint name"},
    {"name": "a missing endpoint", "readless": false, "banner": {"source": {"port": "admin", "type": "GET"}, "field": "Status", "equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}, "expected": "banner.source.endpoint '' is not a package-relative endpoint name"},
    {"name": "a LIST is not a banner's request type", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "LIST"}, "field": "Status", "equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}, "expected": "banner.source.type 'LIST' is not 'GET'"},
    {"name": "a missing type", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager"}, "field": "Status", "equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}, "expected": "banner.source.type '' is not 'GET'"},
    {"name": "an empty field", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "", "equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}, "expected": "banner.field is empty, and a banner compares one named field to one named value and names the string key it raises"},
    {"name": "a missing field", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}, "expected": "banner.field is empty, and a banner compares one named field to one named value and names the string key it raises"},
    {"name": "an empty equals", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "equals": "", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}, "expected": "banner.equals is empty, and a banner compares one named field to one named value and names the string key it raises"},
    {"name": "an empty messageKey", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "equals": "Suspended", "messageKey": "", "severity": "warning"}, "expected": "banner.messageKey is empty, and a banner compares one named field to one named value and names the string key it raises"},
    {"name": "a severity outside the closed set", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "error"}, "expected": "banner.severity 'error' is not one of info,warning,restrained"},
    {"name": "a missing severity", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "equals": "Suspended", "messageKey": "taskManagerSuspendedBanner"}, "expected": "banner.severity '' is not one of info,warning,restrained"},
    {"name": "a banner on a screen with no read", "readless": true, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}, "expected": "a banner is chrome on a declared read's screen (AD-36)"}
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

/// <p>The corpus declaration with <var>pCase</var>'s <code>banner</code> in place, and its
/// <code>read</code> and <code>table</code> set to <code>null</code> when the case is
/// <code>readless</code>, as a new object.</p>
ClassMethod DeclarationFor(pCorpus As %DynamicObject, pCase As %DynamicObject) As %DynamicObject
{
    Set tDeclaration = ##class(%DynamicObject).%FromJSON(pCorpus.declaration.%ToJSON())
    Set tType = pCase.%GetTypeOf("banner")
    If tType = "null" {
        Do tDeclaration.%Set("banner", "", "null")
    } ElseIf (tType = "object") || (tType = "array") {
        Do tDeclaration.%Set("banner", ##class(%DynamicAbstractObject).%FromJSON(pCase.banner.%ToJSON()))
    } Else {
        Do tDeclaration.%Set("banner", pCase.%Get("banner"), tType)
    }
    If ''pCase.readless {
        Do tDeclaration.%Set("read", "", "null")
        Do tDeclaration.%Set("table", "", "null")
    }
    Quit tDeclaration
}

}
