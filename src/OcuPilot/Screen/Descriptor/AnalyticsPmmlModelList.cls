/// <p>Analytics' PMML models: the predictive models the namespace's compiled <code>%DeepSee.PMML.Definition</code> classes define, one row for each model, read through
/// <class>OcuPilot.Port.AnalyticsPort</class> (source kind <code>analytics</code>, endpoint <code>PmmlModels</code>) and rendered by the <code>list</code> archetype's page from the declared <code>table</code>
/// (AD-5, AD-29, AD-36, AD-44, AD-65, Story 24.14). The vendor's own finder lists the definitions and <code>%GetModels</code> their models; every call reads and writes nothing (measured).</p>
/// <p><b>Its id is the composite <code>[Class, Model]</code></b>, the vendor's <code>Class||Model</code>, each part kept exactly (AD-13), and its scope is <code>namespace</code>. Its name cell opens the model's Test screen
/// (<code>analytics/pmml-models/test</code>). A row's <code>Type</code> is the vendor's model type, <code>Target</code> and <code>TargetType</code> the predicted field and its operational type
/// (<code>categorical</code>, <code>ordinal</code> or <code>continuous</code>), <code>DataSources</code> the definition's data sources, one per line, and <code>Verification</code> whether the model carries verification records.</p>
/// <p><b>Its pairs</b> are <code>%DeepSee_Portal:USE</code> and, as its own, <code>%Development:USE</code>: the classic Model Tester admits <code>%Development</code> alone, and a pair set is an AND (AD-8, AD-65). It
/// offers no action and does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.AnalyticsPmmlModelList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/pmml-models",
  "area": "analytics",
  "labelKey": "analyticsPmmlModelsLabel",
  "sideBarPosition": 12,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}, {"resource": "%Development", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "pmml-model",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Class", "Model"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Class", "Model", "Type", "Target", "TargetType", "DataSources", "Verification"], "secretFields": []},
  "emptyStateKey": "analyticsPmmlModelsEmpty",
  "commandAliases": ["pmml models", "pmml model"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsPmmlModelsPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsPmmlModelsPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsPmmlModelsPrompt3"}
  ],
  "classicPage": "%DeepSee.PMML.UI.ModelTester",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "PMML model",
    "source": {"port": "analytics", "endpoint": "PmmlModels", "type": "LIST"},
    "fields": ["Class", "Model", "Type", "Target", "TargetType", "DataSources", "Verification"],
    "filter": ["Class", "Model", "Type", "Target", "TargetType"],
    "sort": {"fields": ["Class", "Model", "Type", "Target", "TargetType", "Verification"], "default": "Model", "direction": "asc"},
    "paging": "cap"
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
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "analytics.pmmlmodels"
}
}

}
