/// <p>Analytics' Groups and elements: the groups one quality measure holds and the MDX elements of each, one row per element and one row for a group with none, read through
/// <class>OcuPilot.Port.AnalyticsPort</class> (source kind <code>analytics</code>, endpoint <code>QualityMeasureElements</code>) and rendered from the declared <code>table</code> (AD-5, AD-11, AD-29, AD-36, AD-44, AD-65,
/// Story 24.12). A linked measure shows its master's groups. An element's MDX is shown as text and never rendered.</p>
/// <p><b>It is a sub-resource of the Quality measures list and never listed</b> (<code>sideBarPosition</code> 0): it declares <code>parentScope</code> <code>analytics/quality-measures</code> and is reached from that
/// list's name cell. Its one declared criterion, <code>qualitymeasure</code>, is the route id, required as a single-object read's is (AD-36); a measure that does not exist reads no rows.</p>
/// <p><b>Its id is the composite <code>[QualityMeasure, Group, Name]</code></b>, each part kept exactly (AD-13), and its scope is <code>namespace</code>. Its pairs are the Quality measures list's; it offers no action and does
/// not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.AnalyticsQualityMeasureElementList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "analytics/quality-measures/elements",
  "area": "analytics",
  "labelKey": "analyticsQualityMeasureElementsLabel",
  "sideBarPosition": 0,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%DeepSee_Portal", "permission": "USE"}, {"resource": "%DeepSee_PortalEdit", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%DeepSee_PortalEdit", "permission": "USE"}],
  "entityType": "quality-measure-element",
  "secondaryEntityTypes": ["quality-measure"],
  "scope": "namespace",
  "parentScope": "analytics/quality-measures",
  "id": {"kind": "composite", "parts": ["QualityMeasure", "Group", "Name"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["QualityMeasure", "Group", "GroupCaption", "GroupDescription", "GroupDisabled", "Name", "Caption", "MDX", "Disabled"], "secretFields": []},
  "emptyStateKey": "analyticsQualityMeasureElementsEmpty",
  "commandAliases": [],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsQualityMeasureElementsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "analyticsQualityMeasureElementsPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "analyticsQualityMeasureElementsPrompt3"}
  ],
  "classicPage": "%DeepSee.UI.QualityMeasures",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "element",
    "source": {"port": "analytics", "endpoint": "QualityMeasureElements", "type": "LIST"},
    "fields": ["QualityMeasure", "Group", "GroupCaption", "GroupDescription", "GroupDisabled", "Name", "Caption", "MDX", "Disabled"],
    "filter": ["Group", "Name", "Caption", "MDX"],
    "sort": {"fields": ["Group", "Name", "Caption"], "default": "Group", "direction": "asc"},
    "paging": "cap",
    "criteria": {
      "fields": [{"param": "qualitymeasure", "labelKey": "analyticsQualityMeasureCriterion", "kind": "text", "maxLength": 752, "hint": "One quality measure, spelled as analytics.qualitymeasures.read answers its Name."}]
    }
  },
  "table": {
    "columns": [
      {"field": "Group", "labelKey": "analyticsColumnGroup", "kind": "name"},
      {"field": "Name", "labelKey": "tableColumnName", "kind": "text"},
      {"field": "Caption", "labelKey": "analyticsColumnCaption", "kind": "text"},
      {"field": "MDX", "labelKey": "analyticsColumnMdx", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "analytics.qualitymeasureelements"
}
}

}
