/// <p>The one corpus both engines of the table-column <code>emptyKey</code> rule run (AD-5):
/// <method>OcuPilot.Screen.Registry.ReadProblem</method> in <class>OcuPilot.Test.ReadTool</class> and
/// <code>readProblem</code> in <file>ui/tools/screen-mirror.test.mjs</file>, which reads this block
/// off disk. Each case replaces the sound declaration's second table column with its own and names
/// the exact sentence both engines return, or <code>null</code> for a shape neither refuses.</p>
/// <p><b>The value in a refused case is never in the sentence</b>, because the two engines render a
/// JSON number, boolean or <code>null</code> into text differently; the sentence names the column's
/// entry instead.</p>
Class OcuPilot.Test.ColumnCorpus Extends %RegisteredObject
{

XData Cases
{
{
  "declaration": {
    "route": "permissions/column-corpus", "area": "permissions", "labelKey": "serviceListLabel", "sideBarPosition": 1,
    "archetype": "list", "built": false, "refreshes": false, "refreshRates": [],
    "privileges": [{"resource": "%Admin_Secure", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
    "entityType": "service", "secondaryEntityTypes": [],
    "scope": "instance", "parentScope": "", "id": {"kind": "single", "parts": []},
    "primaryAction": {"id": "", "selfProtection": ""}, "rowActions": [],
    "context": {"fields": ["Name", "AllowedConnections"], "secretFields": []},
    "emptyStateKey": "serviceListEmpty", "commandAliases": [], "classicPage": "",
    "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
    "read": {
      "source": {"port": "admin", "endpoint": "Security.Service", "type": "LIST"},
      "fields": ["Name", "AllowedConnections"],
      "filter": ["Name", "AllowedConnections"],
      "sort": {"fields": ["Name"], "default": "Name", "direction": "asc"},
      "paging": "cap"
    },
    "table": {
      "columns": [{"field": "Name", "labelKey": "tableColumnName", "kind": "name"}, {"field": "AllowedConnections", "labelKey": "serviceColumnAllowedAddresses", "kind": "identifier"}],
      "emptyNextKey": "tableReadOnlyEmptyNext", "emptyAgentKey": ""
    },
    "toolIdentifier": "permissions.columncorpus"
  },
  "cases": [
    {"name": "a column declaring no emptyKey is sound", "column": {"field": "AllowedConnections", "labelKey": "serviceColumnAllowedAddresses", "kind": "identifier"}, "expected": null},
    {"name": "a column declaring a string emptyKey is sound", "column": {"field": "AllowedConnections", "labelKey": "serviceColumnAllowedAddresses", "kind": "identifier", "emptyKey": "serviceAllowedUnrestricted"}, "expected": null},
    {"name": "an empty emptyKey is refused", "column": {"field": "AllowedConnections", "labelKey": "serviceColumnAllowedAddresses", "kind": "identifier", "emptyKey": ""}, "expected": "table.columns entry #2 emptyKey is not a non-empty string key, and an empty cell in that column reads the string it names"},
    {"name": "a number emptyKey is refused", "column": {"field": "AllowedConnections", "labelKey": "serviceColumnAllowedAddresses", "kind": "identifier", "emptyKey": 7}, "expected": "table.columns entry #2 emptyKey is not a non-empty string key, and an empty cell in that column reads the string it names"},
    {"name": "a boolean emptyKey is refused", "column": {"field": "AllowedConnections", "labelKey": "serviceColumnAllowedAddresses", "kind": "identifier", "emptyKey": true}, "expected": "table.columns entry #2 emptyKey is not a non-empty string key, and an empty cell in that column reads the string it names"},
    {"name": "a null emptyKey is refused rather than read as none declared", "column": {"field": "AllowedConnections", "labelKey": "serviceColumnAllowedAddresses", "kind": "identifier", "emptyKey": null}, "expected": "table.columns entry #2 emptyKey is not a non-empty string key, and an empty cell in that column reads the string it names"},
    {"name": "an array emptyKey is refused", "column": {"field": "AllowedConnections", "labelKey": "serviceColumnAllowedAddresses", "kind": "identifier", "emptyKey": ["serviceAllowedUnrestricted"]}, "expected": "table.columns entry #2 emptyKey is not a non-empty string key, and an empty cell in that column reads the string it names"},
    {"name": "a misspelt emptyKey is an unknown key, not an absent one", "column": {"field": "AllowedConnections", "labelKey": "serviceColumnAllowedAddresses", "kind": "identifier", "emptykey": "serviceAllowedUnrestricted"}, "expected": "table.columns entry #2 declares the unknown key 'emptykey'"},
    {"name": "an emptyKey on a text column is sound, whatever string key it names", "column": {"field": "AllowedConnections", "labelKey": "serviceColumnAllowedAddresses", "kind": "text", "emptyKey": "tableEmptyValue"}, "expected": null}
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

/// <p>The corpus declaration with its second table column replaced by <var>pCase</var>'s
/// <code>column</code>, as a new object.</p>
ClassMethod DeclarationFor(pCorpus As %DynamicObject, pCase As %DynamicObject) As %DynamicObject
{
    Set tDeclaration = ##class(%DynamicObject).%FromJSON(pCorpus.declaration.%ToJSON())
    Do tDeclaration.table.columns.%Set(1, ##class(%DynamicObject).%FromJSON(pCase.column.%ToJSON()))
    Quit tDeclaration
}

}
