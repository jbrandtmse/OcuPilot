/// <p>Analytics' Quality measures: the quality measures the namespace holds, each with its caption, subject area, whether it is published and whether its class is compiled,
/// read through <class>OcuPilot.Port.AnalyticsPort</class> (source kind <code>analytics</code>, endpoint <code>QualityMeasures</code>) and rendered by the <code>list</code> archetype's page from
/// the declared <code>table</code> (AD-5, AD-29, AD-36, AD-44, AD-65, Story 24.12). A measure the vendor lists with no name is absent, and so is a name the vendor's registry does not hold.</p>
/// <p><b>A measure's name opens its groups and elements</b> (<code>analytics/quality-measures/document/&lt;measure&gt;</code>), the first tab of a pair whose second is its documentation
/// (<code>analytics/quality-measures/documentation/&lt;measure&gt;</code>). Both declare this list's route as their <code>parentScope</code>. <b>Its id is the measure's name</b>, kept exactly (AD-13), and its scope is <code>namespace</code>.</p>
/// <p><b>Its pairs</b> are the classic Quality Measures Manager's: <code>%DeepSee_Portal:USE</code> and, as its own, <code>%DeepSee_PortalEdit:USE</code>; the port also checks READ on
/// the namespace's databases before any vendor call (AD-8, AD-65). <b>It writes</b> (Story 24.12): its primary action New quality measure and its row actions Edit, Copy and Delete are the tools
/// <code>analytics.qualitymeasures.add</code>, <code>.update</code>, <code>.copy</code> and <code>.delete</code>; the two screens under it write a measure's groups, elements and documentation. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.AnalyticsQualityMeasureList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/quality-measures",
  "area": "analytics",
  "labelKey": "analyticsQualityMeasuresLabel",
  "sideBarPosition": 10,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}, {"resource": "%DeepSee_PortalEdit", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%DeepSee_PortalEdit", "permission": "USE"}],
  "entityType": "quality-measure",
  "secondaryEntityTypes": ["quality-measure-element", "quality-measure-meta"],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "add", "selfProtection": ""},
  "rowActions": [{"id": "update", "selfProtection": ""}, {"id": "copy", "selfProtection": ""}, {"id": "delete", "selfProtection": ""}],
  "context": {"fields": ["Name", "Catalog", "Set", "Id", "Caption", "Description", "SubjectArea", "Expression", "LinkedTo", "Published", "Format", "Href", "Class", "Compiled", "Groups"], "secretFields": []},
  "emptyStateKey": "analyticsQualityMeasuresEmpty",
  "commandAliases": ["quality measures", "quality measure"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsQualityMeasuresPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsQualityMeasuresPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsQualityMeasuresPrompt3"}
  ],
  "classicPage": "%DeepSee.UI.QualityMeasures",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "quality measure",
    "source": {"port": "analytics", "endpoint": "QualityMeasures", "type": "LIST"},
    "fields": ["Name", "Catalog", "Set", "Id", "Caption", "Description", "SubjectArea", "Expression", "LinkedTo", "Published", "Format", "Href", "Class", "Compiled", "Groups"],
    "filter": ["Name", "Caption", "SubjectArea", "Class"],
    "sort": {"fields": ["Name", "Caption", "SubjectArea", "Published", "Compiled", "Groups"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Caption", "labelKey": "analyticsColumnCaption", "kind": "text"},
      {"field": "SubjectArea", "labelKey": "analyticsTermListSubjectArea", "kind": "text"},
      {"field": "Published", "labelKey": "analyticsColumnPublished", "kind": "status"},
      {"field": "Compiled", "labelKey": "analyticsColumnCompiled", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "analyticsQualityMeasuresEmptyAgent"
  },
  "toolIdentifier": "analytics.qualitymeasures"
}
}

}
