/// <p>Analytics' Test screen of a PMML model: the model's one row and the test the person runs against one of its data sources, read through <class>OcuPilot.Port.AnalyticsPort</class> (source kind
/// <code>analytics</code>, endpoint <code>PmmlModel</code>) and rendered by this screen's own page over the shared detail page (AD-5, AD-29, AD-36, AD-44, AD-65, Story 24.14).</p>
/// <p><b>It is a sub-resource of PMML models and never listed</b> (<code>sideBarPosition</code> 0, <code>parentScope</code> <code>analytics/pmml-models</code>), reached from that list's name cell at
/// <code>analytics/pmml-models/test/&lt;id&gt;</code>, the model's composite id <code>[Class, Model]</code> (AD-13). Its one declared criterion, <code>model</code>, is the route id, the model's composite id or the
/// vendor's <code>Class||Model</code>. Its row is the list's: a model that is gone, or a class that defines none, reads no row and the page says so. Its read executes nothing, so its agent read tool repeats
/// the list's row.</p>
/// <p><b>The test is <class>OcuPilot.Area.Analytics.PmmlTest</class>'s background run</b>, a person's read-kind run: the person picks one of the model's data sources, its verification records or one SQL query, and
/// the answer is the record count, the metrics and the per-value counts, or for a continuous target sigma, RSE and R squared, with each record's actual and predicted value. The agent gets no run (AD-60).
/// Its pairs are PMML models'; it does not refresh.</p>
/// <p><b>It writes</b> (Story 24.14, Batch 4): its primary action, Export to cube, is the tool <code>analytics.pmmlmodel.export</code>. It tests the model again in the request that confirms it, copies the test's rows into a new
/// persistent class and makes a new cube class that reads them; it never builds the cube, which the Cube manager's Build does. The page's own dialog sends it, and the agent proposes the same write.</p>
Class OcuPilot.Screen.Descriptor.AnalyticsPmmlModelTest Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/pmml-models/test",
  "area": "analytics",
  "labelKey": "serverFlagTest",
  "sideBarPosition": 0,
  "archetype": "detail",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}, {"resource": "%Development", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "pmml-model",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "analytics/pmml-models",
  "id": {"kind": "composite", "parts": ["Class", "Model"]},
  "primaryAction": {"id": "export", "selfProtection": ""},
  "rowActions": [{"id": "export", "selfProtection": ""}],
  "context": {"fields": ["Class", "Model", "Type", "Target", "TargetType", "DataSources", "Verification"], "secretFields": []},
  "emptyStateKey": "analyticsPmmlModelGone",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsPmmlModelTestPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsPmmlModelTestPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsPmmlModelTestPrompt3"}
  ],
  "classicPage": "%DeepSee.PMML.UI.ModelTester",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "PMML model",
    "source": {"port": "analytics", "endpoint": "PmmlModel", "type": "LIST"},
    "fields": ["Class", "Model", "Type", "Target", "TargetType", "DataSources", "Verification"],
    "filter": ["Class", "Model", "Type", "Target", "TargetType"],
    "sort": {"fields": ["Class", "Model", "Type", "Target", "TargetType", "Verification"], "default": "Model", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "model", "labelKey": "tableColumnModel", "kind": "text", "maxLength": 600, "hint": "One PMML model, spelled as analytics.pmmlmodels.read answers its Class, then two vertical bars and its Model."}]
    }
  },
  "table": {
    "columns": [
      {"field": "Model", "labelKey": "tableColumnModel", "kind": "name"},
      {"field": "Class", "labelKey": "explorerClassDocumentLabel", "kind": "identifier"},
      {"field": "Type", "labelKey": "tableColumnType", "kind": "text"},
      {"field": "Target", "labelKey": "agentLedgerColumnTarget", "kind": "text"},
      {"field": "TargetType", "labelKey": "analyticsPmmlTargetType", "kind": "text"},
      {"field": "DataSources", "labelKey": "analyticsPmmlDataSources", "kind": "text", "long": true},
      {"field": "Verification", "labelKey": "analyticsPmmlVerification", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "analyticsPmmlModelTestEmptyAgent"
  },
  "toolIdentifier": "analytics.pmmlmodel"
}
}

}
