/// <p>The one corpus both engines of the <code>rowTarget</code> grammar run (AD-5, Story 6.10):
/// <method>OcuPilot.Screen.Registry.RowTargetProblem</method> and
/// <method>OcuPilot.Screen.Registry.RowTargetResolutionProblem</method> in
/// <class>OcuPilot.Test.Descriptor</class>, and <code>rowTargetProblem</code> and
/// <code>rowTargetResolutionProblem</code> in <file>ui/tools/screen-mirror.test.mjs</file>, which
/// reads this block off disk.</p>
/// <p>Each <code>Cases</code> entry replaces <code>declaration.rowTarget</code> with its own (a
/// bare value, for the shapes that are not objects at all), or overrides
/// <code>declaration.archetype</code> or <code>declaration.table</code> alone, leaving the shared
/// declaration's own sound <code>rowTarget</code> in place -- the shape used by
/// <method>OcuPilot.Test.ReadSourceCorpus.DeclarationFor</method> -- and names the exact sentence
/// both engines return, or <code>null</code> when it is sound.</p>
/// <p>Each <code>Rosters</code> entry is a roster of <code>{descriptor, declaration}</code> and the
/// sentence the roster-wide rule returns for it, the same shape
/// <class>OcuPilot.Test.TabCorpus</class>'s roster half uses.</p>
Class OcuPilot.Test.RowTargetCorpus Extends %RegisteredObject
{

XData Cases
{
{
  "declaration": {
    "route": "os-management/row-target-corpus", "area": "os-management", "labelKey": "lockListLabel", "sideBarPosition": 0,
    "archetype": "list", "built": false, "refreshes": false, "refreshRates": [],
    "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
    "entityType": "lock", "secondaryEntityTypes": [],
    "scope": "instance", "parentScope": "", "id": {"kind": "composite", "parts": ["DeleteID"]},
    "primaryAction": {"id": "", "selfProtection": ""}, "rowActions": [],
    "context": {"fields": ["Pid", "DeleteID"], "secretFields": []},
    "emptyStateKey": "lockListEmpty", "commandAliases": [], "classicPage": "",
    "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
    "read": {
      "source": {"port": "admin", "endpoint": "Lock", "type": "LIST"},
      "fields": ["Pid", "DeleteID"],
      "filter": ["Pid"],
      "sort": {"fields": ["Pid"], "default": "Pid", "direction": "asc"},
      "paging": "cap"
    },
    "table": {
      "columns": [{"field": "Pid", "labelKey": "processColumnPid", "kind": "name"}],
      "emptyNextKey": "tableReadOnlyEmptyNext", "emptyAgentKey": ""
    },
    "rowTarget": {"route": "os-management/processes/details", "field": "Pid"},
    "toolIdentifier": "osmgmt.rowtargetcorpus"
  },
  "cases": [
    {"name": "the Locks shape is sound", "expected": null},
    {"name": "no rowTarget declared is sound", "rowTarget": null, "expected": null},
    {"name": "a string is not an object", "rowTarget": "os-management/processes/details", "expected": "rowTarget is not an object naming its route and field (AD-5)"},
    {"name": "an unknown key", "rowTarget": {"route": "os-management/processes/details", "field": "Pid", "label": "Owner"}, "expected": "rowTarget declares the unknown key 'label'"},
    {"name": "a detail archetype is not a list", "archetype": "detail", "expected": "rowTarget is declared on a 'detail' archetype, and a row target is a list's own row link (AD-5)"},
    {"name": "no table", "table": null, "expected": "rowTarget is declared without a table, and a row target replaces the table's name column's own link (AD-5)"},
    {"name": "an empty route", "rowTarget": {"route": "", "field": "Pid"}, "expected": "rowTarget.route is empty, and a row target names the route it opens"},
    {"name": "a route equal to this screen's own", "rowTarget": {"route": "os-management/row-target-corpus", "field": "Pid"}, "expected": "rowTarget.route 'os-management/row-target-corpus' is this screen's own route, and a row already reaches it through its own id (AD-5)"},
    {"name": "an empty field", "rowTarget": {"route": "os-management/processes/details", "field": ""}, "expected": "rowTarget.field is empty, and a row target names the field its link encodes"},
    {"name": "a field outside read.fields", "rowTarget": {"route": "os-management/processes/details", "field": "Bogus"}, "expected": "rowTarget.field 'Bogus' is not one of read.fields"}
  ]
}
}

XData Rosters
{
{
  "rosters": [
    {"name": "a route naming no declared screen", "screens": [
      {"descriptor": "OcuPilot.Test.RowTargetCorpus.A", "declaration": {"route": "os-management/rt-a", "area": "os-management", "archetype": "list", "built": true, "sideBarPosition": 1, "table": {"columns": []}, "id": {"kind": "single", "parts": []}, "rowTarget": {"route": "os-management/nonexistent", "field": "Pid"}}}
    ], "expected": "OcuPilot.Test.RowTargetCorpus.A: rowTarget.route 'os-management/nonexistent' names no declared screen (AD-5)"},
    {"name": "a route naming a screen that is not built", "screens": [
      {"descriptor": "OcuPilot.Test.RowTargetCorpus.A", "declaration": {"route": "os-management/rt-a", "area": "os-management", "archetype": "list", "built": true, "sideBarPosition": 1, "table": {"columns": []}, "id": {"kind": "single", "parts": []}, "rowTarget": {"route": "os-management/rt-b", "field": "Pid"}}},
      {"descriptor": "OcuPilot.Test.RowTargetCorpus.B", "declaration": {"route": "os-management/rt-b", "area": "os-management", "archetype": "detail", "built": false, "sideBarPosition": 0, "id": {"kind": "single", "parts": []}}}
    ], "expected": "OcuPilot.Test.RowTargetCorpus.A: rowTarget.route 'os-management/rt-b' names a screen that is not built (AD-5)"},
    {"name": "a route naming a screen with id.kind none", "screens": [
      {"descriptor": "OcuPilot.Test.RowTargetCorpus.A", "declaration": {"route": "os-management/rt-a", "area": "os-management", "archetype": "list", "built": true, "sideBarPosition": 1, "table": {"columns": []}, "id": {"kind": "single", "parts": []}, "rowTarget": {"route": "os-management/rt-b", "field": "Pid"}}},
      {"descriptor": "OcuPilot.Test.RowTargetCorpus.B", "declaration": {"route": "os-management/rt-b", "area": "os-management", "archetype": "detail", "built": true, "sideBarPosition": 0, "id": {"kind": "none", "parts": []}}}
    ], "expected": "OcuPilot.Test.RowTargetCorpus.A: rowTarget.route 'os-management/rt-b' names a screen with no id, and a row target's field decodes into that screen's own id (AD-5)"},
    {"name": "a declaring screen that already pairs its own surface", "screens": [
      {"descriptor": "OcuPilot.Test.RowTargetCorpus.A", "declaration": {"route": "os-management/rt-a", "area": "os-management", "archetype": "list", "built": true, "sideBarPosition": 1, "table": {"columns": []}, "id": {"kind": "single", "parts": []}, "rowTarget": {"route": "os-management/rt-b", "field": "Pid"}}},
      {"descriptor": "OcuPilot.Test.RowTargetCorpus.B", "declaration": {"route": "os-management/rt-b", "area": "os-management", "archetype": "detail", "built": true, "sideBarPosition": 0, "id": {"kind": "single", "parts": []}}},
      {"descriptor": "OcuPilot.Test.RowTargetCorpus.C", "declaration": {"route": "os-management/rt-a/child", "area": "os-management", "archetype": "list", "built": true, "sideBarPosition": 0, "parentScope": "os-management/rt-a", "id": {"kind": "single", "parts": []}}}
    ], "expected": "OcuPilot.Test.RowTargetCorpus.A: rowTarget is declared on a screen that already pairs its own surface, and a row's name cell links to one place (AD-5)"}
  ]
}
}

/// <p>The <code>Cases</code> half as a <class>%DynamicObject</class>: <code>{declaration, cases}</code>.</p>
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

/// <p>The <code>Rosters</code> half as a <class>%DynamicObject</class>: <code>{rosters}</code>.</p>
ClassMethod RostersBlock(Output pRosters As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pRosters = ""
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), "Rosters", , .tOpenSC)
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "the Rosters XData block is missing")
            Quit
        }
        Do tXData.Data.Rewind()
        Set pRosters = ##class(%DynamicObject).%FromJSON(tXData.Data)
    } Catch ex {
        Set pRosters = ""
        Set tSC = ex.AsStatus()
    }
    Quit tSC
}

/// <p>The corpus declaration with <var>pCase</var>'s <code>rowTarget</code> in place when it
/// carries one -- an object, or a bare value for the shapes that are not objects at all -- and its
/// <code>archetype</code> or <code>table</code> when it carries either, as a new object. A case
/// naming none of the three exercises the shared declaration's own sound <code>rowTarget</code>
/// unchanged, which is how the archetype and table cases reach their own check with a rowTarget
/// otherwise sound enough to get there.</p>
ClassMethod DeclarationFor(pCorpus As %DynamicObject, pCase As %DynamicObject) As %DynamicObject
{
    Set tDeclaration = ##class(%DynamicObject).%FromJSON(pCorpus.declaration.%ToJSON())
    Set tRowTargetType = pCase.%GetTypeOf("rowTarget")
    If tRowTargetType = "object" {
        Do tDeclaration.%Set("rowTarget", ##class(%DynamicObject).%FromJSON(pCase.rowTarget.%ToJSON()))
    } ElseIf tRowTargetType = "null" {
        Do tDeclaration.%Set("rowTarget", "", "null")
    } ElseIf tRowTargetType = "string" {
        Do tDeclaration.%Set("rowTarget", pCase.%Get("rowTarget"))
    }
    If pCase.%GetTypeOf("archetype") = "string" Do tDeclaration.%Set("archetype", pCase.%Get("archetype"))
    If pCase.%GetTypeOf("table") = "null" Do tDeclaration.%Set("table", "", "null")
    Quit tDeclaration
}

}
