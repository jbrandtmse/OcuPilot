/// <p>The one corpus both engines of the <code>read.source.rowGet</code> grammar run (AD-36):
/// <method>OcuPilot.Screen.Registry.ReadProblem</method> in <class>OcuPilot.Test.ReadTool</class> and
/// <code>readProblem</code> in <file>ui/tools/screen-mirror.test.mjs</file>, which reads this block
/// off disk. Each case replaces <code>declaration.read.source.rowGet</code> with its own
/// <code>rowGet</code> and names the exact sentence both engines return, or <code>null</code> for a
/// sound shape. A later story that extends the grammar adds its cases here.</p>
Class OcuPilot.Test.RowGetCorpus Extends %RegisteredObject
{

XData Cases
{
{
  "declaration": {
    "route": "permissions/corpus", "area": "permissions", "labelKey": "userListLabel", "sideBarPosition": 1,
    "archetype": "list", "built": false, "refreshes": false, "refreshRates": [],
    "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}], "entityType": "user", "secondaryEntityTypes": [],
    "scope": "instance", "parentScope": "", "id": {"kind": "single", "parts": []},
    "primaryAction": {"id": "", "selfProtection": ""}, "rowActions": [],
    "context": {"fields": ["Name", "FullName", "Enabled", "Type", "Roles", "ExpirationDate", "Expired"], "secretFields": []},
    "emptyStateKey": "userListEmpty", "commandAliases": [], "classicPage": "",
    "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
    "read": {
      "source": {"port": "admin", "endpoint": "Security.User", "type": "LIST", "rowGet": null},
      "fields": ["Name", "FullName", "Enabled", "Type", "Roles", "ExpirationDate", "Expired"],
      "filter": ["Name", "FullName", "Type", "Roles"],
      "sort": {"fields": ["Name", "FullName", "Type", "Roles"], "default": "Name", "direction": "asc"},
      "paging": "cap"
    },
    "table": {
      "columns": [{"field": "Name", "labelKey": "tableColumnName", "kind": "name"}, {"field": "Expired", "labelKey": "userColumnExpired", "kind": "text"}],
      "emptyNextKey": "tableReadOnlyEmptyNext", "emptyAgentKey": ""
    },
    "toolIdentifier": "permissions.corpus"
  },
  "cases": [
    {"name": "the sound shape", "rowGet": {"key": "Name", "param": "name", "fields": ["Roles", "ExpirationDate"], "derived": [{"field": "Expired", "rule": "beforeToday", "from": "ExpirationDate"}]}, "expected": null},
    {"name": "a null rowGet declares no detail call", "rowGet": null, "expected": null},
    {"name": "an empty derived list is sound", "rowGet": {"key": "Name", "param": "name", "fields": ["Roles"], "derived": []}, "expected": null},
    {"name": "an array is not an object", "rowGet": [], "expected": "read.source.rowGet is not an object declaring its key, param, fields and derived (AD-36)"},
    {"name": "a string is not an object", "rowGet": "Name", "expected": "read.source.rowGet is not an object declaring its key, param, fields and derived (AD-36)"},
    {"name": "an unknown key", "rowGet": {"key": "Name", "param": "name", "fields": ["Roles"], "derived": [], "endpoint": "Security.User"}, "expected": "read.source.rowGet declares the unknown key 'endpoint'"},
    {"name": "a missing key", "rowGet": {"param": "name", "fields": ["Roles"], "derived": []}, "expected": "read.source.rowGet.key is not a string"},
    {"name": "a key outside the fields", "rowGet": {"key": "Id", "param": "name", "fields": ["Roles"], "derived": []}, "expected": "read.source.rowGet.key 'Id' is not one of read.fields"},
    {"name": "a missing param", "rowGet": {"key": "Name", "fields": ["Roles"], "derived": []}, "expected": "read.source.rowGet.param is not a string"},
    {"name": "a param that is not a name", "rowGet": {"key": "Name", "param": "user-name", "fields": ["Roles"], "derived": []}, "expected": "read.source.rowGet.param 'user-name' is not a query parameter name"},
    {"name": "fields that are not an array", "rowGet": {"key": "Name", "param": "name", "fields": "Roles", "derived": []}, "expected": "read.source.rowGet.fields is not an array of field names"},
    {"name": "a fields entry that is not a name", "rowGet": {"key": "Name", "param": "name", "fields": [""], "derived": []}, "expected": "read.source.rowGet.fields entry #1 is not a field name"},
    {"name": "a repeated field", "rowGet": {"key": "Name", "param": "name", "fields": ["Roles", "Roles"], "derived": []}, "expected": "read.source.rowGet.fields names 'Roles' twice"},
    {"name": "a field outside the read's fields", "rowGet": {"key": "Name", "param": "name", "fields": ["Comment"], "derived": []}, "expected": "read.source.rowGet.fields names 'Comment', which is not one of read.fields"},
    {"name": "no detail field", "rowGet": {"key": "Name", "param": "name", "fields": [], "derived": []}, "expected": "read.source.rowGet.fields is empty, and a detail call merges at least one field (AD-36)"},
    {"name": "the key as a detail field", "rowGet": {"key": "Name", "param": "name", "fields": ["Name", "Roles"], "derived": []}, "expected": "read.source.rowGet.fields names the key field 'Name', which the list row already carries"},
    {"name": "a missing derived list", "rowGet": {"key": "Name", "param": "name", "fields": ["Roles"]}, "expected": "read.source.rowGet.derived is not an array of derived fields"},
    {"name": "a derived entry that is not an object", "rowGet": {"key": "Name", "param": "name", "fields": ["ExpirationDate"], "derived": ["Expired"]}, "expected": "read.source.rowGet.derived entry #1 is not an object declaring its field, rule and from"},
    {"name": "a derived entry with an unknown key", "rowGet": {"key": "Name", "param": "name", "fields": ["ExpirationDate"], "derived": [{"field": "Expired", "rule": "beforeToday", "from": "ExpirationDate", "days": 30}]}, "expected": "read.source.rowGet.derived entry #1 declares the unknown key 'days'"},
    {"name": "a derived entry with no field", "rowGet": {"key": "Name", "param": "name", "fields": ["ExpirationDate"], "derived": [{"rule": "beforeToday", "from": "ExpirationDate"}]}, "expected": "read.source.rowGet.derived entry #1 field is not a string"},
    {"name": "a derived field outside the read's fields", "rowGet": {"key": "Name", "param": "name", "fields": ["ExpirationDate"], "derived": [{"field": "Locked", "rule": "beforeToday", "from": "ExpirationDate"}]}, "expected": "read.source.rowGet.derived entry #1 field 'Locked' is not one of read.fields"},
    {"name": "the key as a derived field", "rowGet": {"key": "Name", "param": "name", "fields": ["ExpirationDate"], "derived": [{"field": "Name", "rule": "beforeToday", "from": "ExpirationDate"}]}, "expected": "read.source.rowGet.derived entry #1 field 'Name' is the key field"},
    {"name": "a detail field as a derived field", "rowGet": {"key": "Name", "param": "name", "fields": ["Roles", "ExpirationDate"], "derived": [{"field": "Roles", "rule": "beforeToday", "from": "ExpirationDate"}]}, "expected": "read.source.rowGet.derived entry #1 field 'Roles' is also a detail field, whose value the detail call supplies"},
    {"name": "a repeated derived field", "rowGet": {"key": "Name", "param": "name", "fields": ["ExpirationDate"], "derived": [{"field": "Expired", "rule": "beforeToday", "from": "ExpirationDate"}, {"field": "Expired", "rule": "beforeToday", "from": "ExpirationDate"}]}, "expected": "read.source.rowGet.derived entry #2 names the field 'Expired' twice"},
    {"name": "a derived entry with no rule", "rowGet": {"key": "Name", "param": "name", "fields": ["ExpirationDate"], "derived": [{"field": "Expired", "from": "ExpirationDate"}]}, "expected": "read.source.rowGet.derived entry #1 rule is not a string"},
    {"name": "a rule outside the closed set", "rowGet": {"key": "Name", "param": "name", "fields": ["ExpirationDate"], "derived": [{"field": "Expired", "rule": "afterToday", "from": "ExpirationDate"}]}, "expected": "read.source.rowGet.derived entry #1 rule 'afterToday' is not one of beforeToday"},
    {"name": "a derived entry with no from", "rowGet": {"key": "Name", "param": "name", "fields": ["ExpirationDate"], "derived": [{"field": "Expired", "rule": "beforeToday"}]}, "expected": "read.source.rowGet.derived entry #1 from is not a string"},
    {"name": "a from outside the detail fields", "rowGet": {"key": "Name", "param": "name", "fields": ["ExpirationDate"], "derived": [{"field": "Expired", "rule": "beforeToday", "from": "FullName"}]}, "expected": "read.source.rowGet.derived entry #1 from 'FullName' is not one of read.source.rowGet.fields"}
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

/// <p>The corpus declaration with <var>pCase</var>'s <code>rowGet</code> in place, as a new
/// object.</p>
ClassMethod DeclarationFor(pCorpus As %DynamicObject, pCase As %DynamicObject) As %DynamicObject
{
    Set tDeclaration = ##class(%DynamicObject).%FromJSON(pCorpus.declaration.%ToJSON())
    Set tSource = tDeclaration.read.source
    Set tType = pCase.%GetTypeOf("rowGet")
    If tType = "null" {
        Do tSource.%Set("rowGet", "", "null")
    } ElseIf (tType = "object") || (tType = "array") {
        Do tSource.%Set("rowGet", ##class(%DynamicAbstractObject).%FromJSON(pCase.rowGet.%ToJSON()))
    } Else {
        Do tSource.%Set("rowGet", pCase.%Get("rowGet"), tType)
    }
    Quit tDeclaration
}

}
