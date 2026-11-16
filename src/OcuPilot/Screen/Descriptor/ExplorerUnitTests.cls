/// <p>System Explorer's Unit tests: the unit-test runs recorded in the route's namespace, newest first, read from the
/// <code>%UnitTest_Result</code> tables through the developer-tool port (<class>OcuPilot.Port.DevToolPort</class>, endpoint
/// <code>UnitTestRuns</code>) (AD-5, AD-23, AD-29, AD-36, Story 24.5). A row opens that run's methods
/// (<class>OcuPilot.Screen.Descriptor.ExplorerUnitTestRun</class>), which declares this screen as its <code>parentScope</code>, so the
/// row's name cell links to it.</p>
/// <p><b>Its two criteria are the Run form's</b>: <code>tests</code>, a package, a class or <code>Class:Method</code>, and
/// <code>level</code>, what the target names. The list read ignores them; the run takes them.</p>
/// <p><b>Its one row action is <code>run</code></b>, a person's alone and off by default: it runs the named tests in this
/// namespace as the signed-in person, behind a warning dialog, through
/// <class>OcuPilot.Screen.Tool.ExplorerUnitTestRun</class>, whose governance key ships disabled and which the agent can never
/// reach (AD-10's run-code exception, AD-53). Its id is the run's number, which a row opens the methods list with; the run's target is the literal
/// <code>unittests</code> under <code>class</code> in the route's namespace (AD-13).</p>
/// <p><b>Its privilege set is <code>%Development:USE</code></b>; the port also requires READ on each of the namespace's code
/// databases, and the run WRITE on its routines database (AD-29). No classic page runs a namespace's unit tests
/// (AD-44). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.ExplorerUnitTests Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "system-explorer/unit-tests",
  "area": "system-explorer",
  "labelKey": "explorerUnitTestsLabel",
  "sideBarPosition": 17,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "class",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "run", "selfProtection": ""}],
  "context": {"fields": ["Run", "Started", "Duration", "Methods", "Passed", "Failed", "Finished"], "secretFields": []},
  "emptyStateKey": "explorerUnitTestsEmpty",
  "commandAliases": ["unit tests", "run tests", "test runs"],
  "suggestedPrompts": [
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerUnitTestsPrompt1"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerUnitTestsPrompt2"},
    {"groupKey": "webAppPromptGroupCode", "textKey": "explorerUnitTestsPrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "recorded unit-test run",
    "source": {"port": "devtool", "endpoint": "UnitTestRuns", "type": "LIST"},
    "fields": ["Run", "Started", "Duration", "Methods", "Passed", "Failed", "Finished"],
    "filter": ["Run", "Started"],
    "sort": {"fields": ["Run", "Started", "Duration", "Failed"], "default": "Run", "direction": "desc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "tests", "labelKey": "explorerUnitTestsTestsLabel", "kind": "text", "maxLength": 256, "hint": "A package, a class, or Class:Method"},
        {"param": "level", "labelKey": "actionRun", "kind": "choice", "maxLength": 7, "options": ["package", "class", "method"], "default": "class"}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "Run", "labelKey": "actionRun", "kind": "name"},
      {"field": "Started", "labelKey": "taskHistoryColumnStarted", "kind": "text"},
      {"field": "Duration", "labelKey": "explorerUnitTestsColumnDuration", "kind": "number"},
      {"field": "Methods", "labelKey": "explorerUnitTestsColumnMethods", "kind": "number"},
      {"field": "Passed", "labelKey": "explorerUnitTestsPassed", "kind": "number"},
      {"field": "Failed", "labelKey": "explorerPromoteFailed", "kind": "number"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "explorerUnitTestsEmptyAgent"
  },
  "toolIdentifier": "explorer.unittests"
}
}

}
