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
/// <p><b><code>OwnPrivilegeCases</code> is the second corpus</b>, for
/// <method>OcuPilot.Screen.Registry.OwnPrivilegesProblem</method> in
/// <class>OcuPilot.Test.Descriptor</class> and <code>ownPrivilegesProblem</code> in
/// <file>ui/tools/screen-mirror.test.mjs</file> (AD-8). Each case is a declaration holding the
/// block's <code>privileges</code> and, when the case carries one, its <code>ownPrivileges</code>,
/// with the exact sentence both engines return, or <code>null</code>.</p>
Class OcuPilot.Test.DeclarationCorpus Extends %RegisteredObject
{

XData OwnPrivilegeCases
{
{
  "privileges": [{"resource": "%Admin_Task", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "cases": [
    {"name": "no ownPrivileges is sound", "expected": null},
    {"name": "an empty ownPrivileges is sound", "ownPrivileges": [], "expected": null},
    {"name": "one declared pair owned is sound", "ownPrivileges": [{"resource": "%Admin_Task", "permission": "USE"}], "expected": null},
    {"name": "every declared pair owned is sound", "ownPrivileges": [{"resource": "%DB_IRISSYS", "permission": "READ"}, {"resource": "%Admin_Task", "permission": "USE"}], "expected": null},
    {"name": "a string is not an array of pairs", "ownPrivileges": "%Admin_Task:USE", "expected": "ownPrivileges is not an array of privilege pairs"},
    {"name": "nor is a single pair object", "ownPrivileges": {"resource": "%Admin_Task", "permission": "USE"}, "expected": "ownPrivileges is not an array of privilege pairs"},
    {"name": "a pair missing its permission", "ownPrivileges": [{"resource": "%Admin_Task"}], "expected": "declared own privilege pair #1 is missing its resource or its permission"},
    {"name": "a second pair missing its resource", "ownPrivileges": [{"resource": "%Admin_Task", "permission": "USE"}, {"permission": "USE"}], "expected": "declared own privilege pair #2 is missing its resource or its permission"},
    {"name": "an entry that is not a pair", "ownPrivileges": ["%Admin_Task:USE"], "expected": "declared own privilege pair #1 is missing its resource or its permission"},
    {"name": "a pair the screen does not declare", "ownPrivileges": [{"resource": "%Ens_EventLog", "permission": "USE"}], "expected": "own privilege pair %Ens_EventLog:USE is not one of the screen's declared privileges, and a screen owns only a pair it requires (AD-8)"},
    {"name": "a declared resource at another permission", "ownPrivileges": [{"resource": "%DB_IRISSYS", "permission": "WRITE"}], "expected": "own privilege pair %DB_IRISSYS:WRITE is not one of the screen's declared privileges, and a screen owns only a pair it requires (AD-8)"},
    {"name": "matched exactly, so a differently cased permission is not declared", "ownPrivileges": [{"resource": "%Admin_Task", "permission": "Use"}], "expected": "own privilege pair %Admin_Task:Use is not one of the screen's declared privileges, and a screen owns only a pair it requires (AD-8)"},
    {"name": "the first undeclared pair is named, past a declared one and ahead of a second", "ownPrivileges": [{"resource": "%Admin_Task", "permission": "USE"}, {"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%Admin_Manage", "permission": "USE"}], "expected": "own privilege pair %Admin_Operate:USE is not one of the screen's declared privileges, and a screen owns only a pair it requires (AD-8)"}
  ]
}
}

/// <p><code>OwnPrivilegeCases</code> as a <class>%DynamicObject</class>:
/// <code>{privileges, cases}</code>.</p>
ClassMethod OwnPrivilegeCorpus(Output pCorpus As %DynamicObject) As %Status
{
    Set tSC = $$$OK
    Set pCorpus = ""
    Try {
        Set tXData = ##class(%Dictionary.XDataDefinition).IDKEYOpen($ClassName(), "OwnPrivilegeCases", , .tOpenSC)
        If '$IsObject(tXData) {
            Set tSC = $$$ERROR($$$GeneralError, "the OwnPrivilegeCases XData block is missing")
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

/// <p>The declaration <var>pCase</var> of <code>OwnPrivilegeCases</code> describes, as a new
/// object: the corpus's <code>privileges</code> and, when the case carries one, its
/// <code>ownPrivileges</code>.</p>
ClassMethod OwnPrivilegeDeclarationFor(pCorpus As %DynamicObject, pCase As %DynamicObject) As %DynamicObject
{
    Set tDeclaration = {}
    Do tDeclaration.%Set("privileges", ##class(%DynamicArray).%FromJSON(pCorpus.privileges.%ToJSON()))
    If pCase.%IsDefined("ownPrivileges") {
        Set tOwn = pCase.%Get("ownPrivileges")
        If $IsObject(tOwn) Set tOwn = ##class(%DynamicAbstractObject).%FromJSON(tOwn.%ToJSON())
        Do tDeclaration.%Set("ownPrivileges", tOwn)
    }
    Quit tDeclaration
}

XData Cases
{
{
  "declaration": {
    "route": "tasks/declaration-corpus", "area": "tasks", "labelKey": "taskListLabel", "sideBarPosition": 1,
    "archetype": "list", "built": false, "refreshes": false, "refreshRates": [], "refreshDefault": 0,
    "privileges": [{"resource": "%Admin_Task", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
    "ownPrivileges": [],
    "entityType": "task", "entityLabelKey": "proposalEntityTask", "secondaryEntityTypes": [],
    "scope": "instance", "parentScope": "", "id": {"kind": "single", "parts": []},
    "primaryAction": {"id": "", "selfProtection": ""}, "rowActions": [],
    "context": {"fields": ["Name", "Namespace"], "secretFields": []},
    "secretArguments": [], "fingerprintExcludes": [],
    "emptyStateKey": "taskListEmpty", "commandAliases": [],
    "suggestedPrompts": [{"groupKey": "userPromptGroupAccess", "textKey": "userPromptSignIn"}, {"groupKey": "userPromptGroupAccess", "textKey": "userPromptPrivilege"}, {"groupKey": "userPromptGroupAccess", "textKey": "userPromptTwoFactor"}],
    "classicPage": "",
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
    "toolIdentifier": "tasks.declarationcorpus",
    "rowTarget": null,
    "multiSelect": null
  },
  "cases": [
    {"name": "the sound shape, all thirty-four keys", "addKey": "", "dropKey": "", "expected": null},
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
    {"name": "an absent optional refreshDefault is sound", "addKey": "", "dropKey": "refreshDefault", "expected": null},
    {"name": "an absent optional tab is sound", "addKey": "", "dropKey": "tab", "expected": null},
    {"name": "an absent optional rowTarget is sound", "addKey": "", "dropKey": "rowTarget", "expected": null},
    {"name": "an absent optional secretArguments is sound", "addKey": "", "dropKey": "secretArguments", "expected": null},
    {"name": "an absent optional fingerprintExcludes is sound", "addKey": "", "dropKey": "fingerprintExcludes", "expected": null},
    {"name": "an absent optional entityLabelKey is sound", "addKey": "", "dropKey": "entityLabelKey", "expected": null},
    {"name": "a pluralised entityLabelKey", "addKey": "entityLabelKeys", "dropKey": "", "expected": "the declaration declares the unknown key 'entityLabelKeys'"},
    {"name": "a singular secretArgument", "addKey": "secretArgument", "dropKey": "", "expected": "the declaration declares the unknown key 'secretArgument'"},
    {"name": "a singular fingerprintExclude", "addKey": "fingerprintExclude", "dropKey": "", "expected": "the declaration declares the unknown key 'fingerprintExclude'"},
    {"name": "a pluralised tab", "addKey": "tabs", "dropKey": "", "expected": "the declaration declares the unknown key 'tabs'"},
    {"name": "an absent optional suggestedPrompts is sound", "addKey": "", "dropKey": "suggestedPrompts", "expected": null},
    {"name": "an absent optional ownPrivileges is sound", "addKey": "", "dropKey": "ownPrivileges", "expected": null},
    {"name": "a singular ownPrivilege", "addKey": "ownPrivilege", "dropKey": "", "expected": "the declaration declares the unknown key 'ownPrivilege'"},
    {"name": "a singular suggestedPrompt", "addKey": "suggestedPrompt", "dropKey": "", "expected": "the declaration declares the unknown key 'suggestedPrompt'"},
    {"name": "an absent required route is sound here, because this rule is unknown-key only", "addKey": "", "dropKey": "route", "expected": null},
    {"name": "an absent required toolIdentifier is sound here, for the same reason", "addKey": "", "dropKey": "toolIdentifier", "expected": null},
    {"name": "an unknown key is still named when a required key is missing beside it", "addKey": "banners", "dropKey": "route", "expected": "the declaration declares the unknown key 'banners'"},
    {"name": "an absent optional multiSelect is sound", "addKey": "", "dropKey": "multiSelect", "expected": null},
    {"name": "a hyphenated multi-select", "addKey": "multi-select", "dropKey": "", "expected": "the declaration declares the unknown key 'multi-select'"}
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
