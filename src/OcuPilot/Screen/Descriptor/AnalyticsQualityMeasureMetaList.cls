/// <p>Analytics' Documentation: the documentation items one quality measure holds, each with its name, caption, section and content, read through
/// <class>OcuPilot.Port.AnalyticsPort</class> (source kind <code>analytics</code>, endpoint <code>QualityMeasureMetas</code>) and rendered from the declared <code>table</code> (AD-5, AD-11, AD-29, AD-36, AD-44, AD-65,
/// Story 24.12). A linked measure shows its master's items. An item's content is stored markup and is shown as text, never rendered.</p>
/// <p><b>It is a sub-resource of the Quality measures list and never listed</b> (<code>sideBarPosition</code> 0): it declares <code>parentScope</code> <code>analytics/quality-measures</code> and is reached from that
/// list's name cell. Its one declared criterion, <code>qualitymeasure</code>, is the route id, required as a single-object read's is (AD-36); a measure that does not exist reads no rows.</p>
/// <p><b>Its id is the composite <code>[QualityMeasure, Name]</code></b>, each part kept exactly (AD-13), and its scope is <code>namespace</code>. Its pairs are the Quality measures list's; it offers no action and does
/// not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.AnalyticsQualityMeasureMetaList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/quality-measures/documentation",
  "area": "analytics",
  "labelKey": "linksDocumentation",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}, {"resource": "%DeepSee_PortalEdit", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%DeepSee_PortalEdit", "permission": "USE"}],
  "entityType": "quality-measure-meta",
  "secondaryEntityTypes": ["quality-measure"],
  "scope": "namespace",
  "parentScope": "analytics/quality-measures",
  "id": {"kind": "composite", "parts": ["QualityMeasure", "Name"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["QualityMeasure", "Name", "Caption", "Section", "Content", "Disabled"], "secretFields": []},
  "emptyStateKey": "analyticsQualityMeasureMetasEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsQualityMeasureMetasPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsQualityMeasureMetasPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsQualityMeasureMetasPrompt3"}
  ],
  "classicPage": "%DeepSee.UI.QualityMeasures",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "documentation item",
    "source": {"port": "analytics", "endpoint": "QualityMeasureMetas", "type": "LIST"},
    "fields": ["QualityMeasure", "Name", "Caption", "Section", "Content", "Disabled"],
    "filter": ["Name", "Caption", "Section", "Content"],
    "sort": {"fields": ["Name", "Caption", "Section"], "default": "Name", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "qualitymeasure", "labelKey": "analyticsQualityMeasureCriterion", "kind": "text", "maxLength": 752, "hint": "One quality measure, spelled as analytics.qualitymeasures.read answers its Name."}]
    }
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Caption", "labelKey": "analyticsColumnCaption", "kind": "text"},
      {"field": "Content", "labelKey": "analyticsColumnContent", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "analytics.qualitymeasuremetas"
}
}

}
