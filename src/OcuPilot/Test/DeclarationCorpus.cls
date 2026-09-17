/// <p>The one corpus both engines of the <b>top-level</b> declaration grammar run (DW-271):
/// <method>OcuPilot.Screen.Registry.DeclarationProblem</method> in
/// <class>OcuPilot.Test.ReadTool</class> and <code>declarationProblem</code> in
/// <file>ui/tools/screen-mirror.test.mjs</file>, which reads this block off disk. Each case adds one
/// key to the sound declaration, or drops one from it, and names the exact sentence both engines
/// return -- or <code>null</code> for a shape neither refuses.</p>
/// <p><b>The dropping cases are the rule's other half.</b> The check is unknown-key only, never
/// presence: a declaration missing an optional key is sound, and so is one missing a required key,
/// because the rule that reads that key is what refuses it, with a sentence saying what it was
/// for. Without those cases a presence check would pass this corpus.</p>
/// <p><b>Every added value is a string.</b> The two engines render a JSON boolean into a sentence
/// differently (<code>%Get</code> answers <code>1</code> where <code>String</code> answers
/// <code>true</code>), and the sentence names the key rather than the value anyway.</p>
Class OcuPilot.Test.DeclarationCorpus Extends %RegisteredObject
{

XData Cases
{
{
  "declaration": {
    "route": "tasks/declaration-corpus", "area": "tasks", "labelKey": "taskListLabel", "sideBarPosition": 1,
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
    "banner": {"source": {"port": "admin", "endpoint": "Task.Manager", "type": "GET"}, "field": "Status", "cases": [{"equals": "Suspended", "messageKey": "taskManagerSuspendedBanner", "severity": "warning"}]},
    "tab": null,
    "toolIdentifier": "tasks.declarationcorpus"
  },
  "cases": [
    {"name": "the sound shape, all twenty-six keys", "addKey": "", "dropKey": "", "expected": null},
    {"name": "a pluralised banner, the misspelling that installed a screen whose strip never raises", "addKey": "banners", "dropKey": "", "expected": "the declaration declares the unknown key 'banners'"},
    {"name": "a capitalised banner", "addKey": "Banner", "dropKey": "", "expected": "the declaration declares the unknown key 'Banner'"},
    {"name": "a pluralised read", "addKey": "reads", "dropKey": "", "expected": "the declaration declares the unknown key 'reads'"},
    {"name": "a singular privilege", "addKey": "privilege", "dropKey": "", "expected": "the declaration declares the unknown key 'privilege'"},
    {"name": "criteria flattened to the top level, where no engine would look for it", "addKey": "criteria", "dropKey": "", "expected": "the declaration declares the unknown key 'criteria'"},
    {"name": "a plausible key no descriptor grammar has", "addKey": "refreshInterval", "dropKey": "", "expected": "the declaration declares the unknown key 'refreshInterval'"},
    {"name": "an absent optional banner is sound", "addKey": "", "dropKey": "banner", "expected": null},
    {"name": "an absent optional read is sound", "addKey": "", "dropKey": "read", "expected": null},
    {"name": "an absent optional table is sound", "addKey": "", "dropKey": "table", "expected": null},
    {"name": "an absent optional refreshes is sound", "addKey": "", "dropKey": "refreshes", "expected": null},
    {"name": "an absent optional refreshRates is sound", "addKey": "", "dropKey": "refreshRates", "expected": null},
    {"name": "an absent optional tab is sound", "addKey": "", "dropKey": "tab", "expected": null},
    {"name": "a pluralised tab", "addKey": "tabs", "dropKey": "", "expected": "the declaration declares the unknown key 'tabs'"},
    {"name": "an absent required route is sound here, because this rule is unknown-key only", "addKey": "", "dropKey": "route", "expected": null},
    {"name": "an absent required toolIdentifier is sound here, for the same reason", "addKey": "", "dropKey": "toolIdentifier", "expected": null},
    {"name": "an unknown key is still named when a required key is missing beside it", "addKey": "banners", "dropKey": "route", "expected": "the declaration declares the unknown key 'banners'"}
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

/// <p>The corpus declaration with <var>pCase</var>'s <code>addKey</code> added as a string and its
/// <code>dropKey</code> removed, as a new object. An empty name in either does nothing.</p>
ClassMethod DeclarationFor(pCorpus As %DynamicObject, pCase As %DynamicObject) As %DynamicObject
{
    Set tDeclaration = ##class(%DynamicObject).%FromJSON(pCorpus.declaration.%ToJSON())
    Set tDrop = pCase.%Get("dropKey")
    If tDrop '= "" Do tDeclaration.%Remove(tDrop)
    Set tAdd = pCase.%Get("addKey")
    If tAdd '= "" Do tDeclaration.%Set(tAdd, "a value no accessor reads")
    Quit tDeclaration
}

}
