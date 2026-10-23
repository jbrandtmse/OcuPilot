/// <p>Prometheus metrics: every sample the instance's sensors answer, sorted by metric, read through
/// <class>OcuPilot.Port.MonitorPort</class> (AD-29, AD-36) and rendered by the <code>list</code>
/// archetype's page from the declared <code>table</code> (AD-5). OS management's twenty-first
/// side-bar entry.</p>
/// <p><b>Its scope is <code>instance</code></b> and its id is <code>none</code>: a sample is named by
/// its metric and labels together, and the screen opens no detail and takes no action.</p>
/// <p><b>Its pairs are the port's</b>, <code>%Admin_Operate:USE</code> and
/// <code>%DB_IRISSYS:READ</code>, which OS management's set covers, so it declares no own pair. The
/// monitoring API's anonymous reachability is not carried over (AD-29).</p>
/// <p><b>It never refreshes.</b> Each read takes a new sensor collection and rewrites the vendor's
/// sensor baseline, so the page's note says the read shortens an external scraper's per-second
/// intervals (AD-7, AD-43). It has no classic page: the classic portal shows no such table (AD-44).</p>
Class OcuPilot.Screen.Descriptor.MetricsList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "os-management/metrics",
  "area": "os-management",
  "labelKey": "metricsLabel",
  "sideBarPosition": 21,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Admin_Operate", "permission": "USE"}, {"resource": "%DB_IRISSYS", "permission": "READ"}],
  "entityType": "",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "none", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "context": {"fields": ["Metric", "Labels", "Value", "Help"], "secretFields": []},
  "emptyStateKey": "metricsEmpty",
  "commandAliases": ["prometheus metrics", "metrics", "sensors"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupCapacity", "textKey": "metricsPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "metricsPrompt2"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "metricsPrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "Prometheus metric sample",
    "source": {"port": "monitor", "endpoint": "Metrics", "type": "LIST"},
    "fields": ["Metric", "Labels", "Value", "Help"],
    "filter": ["Metric", "Labels", "Help"],
    "sort": {"fields": ["Metric", "Value"], "default": "Metric", "direction": "asc"},
    "paging": "cap",
    "note": {"key": "metricsNote", "text": "Each read takes a new sensor collection, which shortens the per-second intervals an external Prometheus scraper reports."}
  },
  "table": {
    "columns": [
      {"field": "Metric", "labelKey": "metricsColumnMetric", "kind": "name"},
      {"field": "Labels", "labelKey": "metricsColumnLabels", "kind": "identifier"},
      {"field": "Value", "labelKey": "errorLogColumnValue", "kind": "number"},
      {"field": "Help", "labelKey": "tableColumnDescription", "kind": "text"}
    ],
    "emptyNextKey": "tableReadOnlyEmptyNext",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "osmgmt.metrics"
}
}

}
