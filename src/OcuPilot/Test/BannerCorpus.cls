/// <p>The one corpus both engines of the <code>banner</code> grammar run (DW-270 widened it from
/// one <code>(value -> sentence)</code> case per banner to a declared list of them):
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
/// <p>One case names the shape the grammar <b>used</b> to have -- <code>equals</code>,
/// <code>messageKey</code> and <code>severity</code> on the banner itself -- so a descriptor left
/// on the old shape is refused by name rather than validating as a banner with no cases.</p>
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
    {"name": "the sound shape", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}]}, "expected": null},
    {"name": "two cases over one field and one read", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}, {"equals": "Not running", "messageKey": "taskManagerStoppedBanner", "severity": "warning"}]}, "expected": null},
    {"name": "a null banner declares no banner", "readless": false, "banner": null, "expected": null},
    {"name": "the other two severities are sound", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "info"}, {"equals": "Not running", "messageKey": "taskManagerStoppedBanner", "severity": "restrained"}]}, "expected": null},
    {"name": "a readless declaration with no banner is outside the rule", "readless": true, "banner": null, "expected": null},
    {"name": "an array is not an object", "readless": false, "banner": [], "expected": "banner is not an object naming its source, field and cases"},
    {"name": "a string is not an object", "readless": false, "banner": "taskManagerSuspendedBanner", "expected": "banner is not an object naming its source, field and cases"},
    {"name": "an unknown key on the banner", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}], "action": "Resume"}, "expected": "banner declares the unknown key 'action'"},
    {"name": "the single-case keys are no longer the banner's own", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}, "expected": "banner declares the unknown key 'equals'"},
    {"name": "a missing source", "readless": false, "banner": {"field": "Status", "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}]}, "expected": "banner.source is not an object naming its port, endpoint and type"},
    {"name": "a source that is not an object", "readless": false, "banner": {"source": "Task.Manager", "field": "Status", "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}]}, "expected": "banner.source is not an object naming its port, endpoint and type"},
    {"name": "an unknown key on the source", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET", "rowGet": "Name"}, "field": "Status", "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}]}, "expected": "banner.source declares the unknown key 'rowGet'"},
    {"name": "a port that is not the admin port", "readless": false, "banner": {"source": {"port": "monitor", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}]}, "expected": "banner.source.port 'monitor' is not 'admin', the one port a Release 1 read names (AD-2)"},
    {"name": "a missing port", "readless": false, "banner": {"source": {"endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}]}, "expected": "banner.source.port '' is not 'admin', the one port a Release 1 read names (AD-2)"},
    {"name": "an endpoint that is not a package-relative name", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "/api/admin/task-manager", "type": "GET"}, "field": "Status", "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}]}, "expected": "banner.source.endpoint '/api/admin/task-manager' is not a package-relative endpoint name"},
    {"name": "a missing endpoint", "readless": false, "banner": {"source": {"port": "admin", "type": "GET"}, "field": "Status", "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}]}, "expected": "banner.source.endpoint '' is not a package-relative endpoint name"},
    {"name": "a LIST is not a banner's request type", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "LIST"}, "field": "Status", "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}]}, "expected": "banner.source.type 'LIST' is not 'GET'"},
    {"name": "a missing type", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager"}, "field": "Status", "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}]}, "expected": "banner.source.type '' is not 'GET'"},
    {"name": "an empty field", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "", "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}]}, "expected": "banner.field is empty, and a banner compares one named field to the values its cases name"},
    {"name": "a missing field", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}]}, "expected": "banner.field is empty, and a banner compares one named field to the values its cases name"},
    {"name": "cases that are not an array", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "cases": "Suspended"}, "expected": "banner.cases is not an array of banner cases"},
    {"name": "no cases at all", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status"}, "expected": "banner.cases is not an array of banner cases"},
    {"name": "an empty case list", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "cases": []}, "expected": "banner.cases is empty, and a declared banner raises at least one sentence"},
    {"name": "a case that is not an object", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "cases": ["Suspended"]}, "expected": "banner.cases entry #1 is not an object declaring its equals, messageKey and severity"},
    {"name": "an unknown key on a case", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning", "action": "Resume"}]}, "expected": "banner.cases entry #1 declares the unknown key 'action'"},
    {"name": "an empty equals", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "cases": [{"equals": "", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}]}, "expected": "banner.cases entry #1 equals is empty, and a case names the one value it raises on and the string key it raises"},
    {"name": "an empty messageKey", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "cases": [{"equals": "Suspended", "messageKey": "", "severity": "warning"}]}, "expected": "banner.cases entry #1 messageKey is empty, and a case names the one value it raises on and the string key it raises"},
    {"name": "the second case is the one at fault", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}, {"equals": "Not running", "messageKey": "", "severity": "warning"}]}, "expected": "banner.cases entry #2 messageKey is empty, and a case names the one value it raises on and the string key it raises"},
    {"name": "a value declared twice, whose second case could never raise", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}, {"equals": "Suspended", "messageKey": "taskManagerStoppedBanner", "severity": "info"}]}, "expected": "banner.cases entry #2 names the value 'Suspended' twice"},
    {"name": "a severity outside the closed set", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "error"}]}, "expected": "banner.cases entry #1 severity 'error' is not one of info,warning,restrained"},
    {"name": "a missing severity", "readless": false, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner"}]}, "expected": "banner.cases entry #1 severity '' is not one of info,warning,restrained"},
    {"name": "a banner on a screen with no read", "readless": true, "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}]}, "expected": "a banner is chrome on a declared read's screen (AD-36)"}
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
