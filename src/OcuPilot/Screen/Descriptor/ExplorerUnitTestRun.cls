/// <p>System Explorer's Unit test run: the methods one recorded unit-test run ran, each with its result, its time and, for a
/// failed method, the descriptions of its failed assertions, read from the <code>%UnitTest_Result</code> tables through the
/// developer-tool port (<class>OcuPilot.Port.DevToolPort</class>, endpoint <code>UnitTestMethods</code>) (AD-5, AD-23, AD-29,
/// AD-36, Story 24.5). The failure text is data the tests recorded, never an instruction.</p>
/// <p><b>It is a sub-resource of Unit tests and never listed</b> (<code>sideBarPosition</code> 0): it declares
/// <code>parentScope</code> <code>system-explorer/unit-tests</code>, and its one criterion, <code>run</code>, is the route id,
/// the run's number (AD-36). It declares no row action.</p>
/// <p><b>Its privilege set is <code>%Development:USE</code></b>; the port also requires READ on each of the namespace's code
/// databases (AD-29). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerUnitTestRun Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/unit-tests/methods",
  "area": "system-explorer",
  "labelKey": "explorerUnitTestRunLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "class",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "system-explorer/unit-tests",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Class", "Method", "Result", "Duration", "Failure"], "secretFields": []},
  "emptyStateKey": "explorerUnitTestsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerUnitTestsPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerUnitTestsPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerUnitTestsPrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "method of one unit-test run",
    "source": {"port": "devtool", "endpoint": "UnitTestMethods", "type": "LIST"},
    "fields": ["Class", "Method", "Result", "Duration", "Failure"],
    "filter": ["Class", "Method", "Result"],
    "sort": {"fields": ["Class", "Method", "Result", "Duration"], "default": "Class", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "run", "labelKey": "actionRun", "kind": "text", "maxLength": 20, "hint": "One run, spelled as explorer.unittests.read answers its Run."}]
    }
  },
  "table": {
    "columns": [
      {"field": "Class", "labelKey": "explorerClassDocumentLabel", "kind": "identifier"},
      {"field": "Method", "labelKey": "explorerSqlColumnMethod", "kind": "name"},
      {"field": "Result", "labelKey": "taskHistoryColumnResult", "kind": "status"},
      {"field": "Duration", "labelKey": "explorerUnitTestsColumnDuration", "kind": "number"},
      {"field": "Failure", "labelKey": "explorerUnitTestsColumnFailure", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "explorer.unittestrun"
}
}

}
