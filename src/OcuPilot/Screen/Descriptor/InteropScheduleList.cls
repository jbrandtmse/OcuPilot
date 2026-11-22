/// <p>Interoperability's Schedule specs: the named schedules that production items start and stop by, which the classic Schedule Specs page keeps,
/// read through <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint <code>Schedules</code>) and rendered from the
/// declared <code>table</code> (AD-5, AD-29, AD-36, AD-62, Story 24.15).</p>
/// <p><b>Its primary action</b> New schedule spec and <b>its row actions</b> Edit and Remove are the screen's callers of
/// <class>OcuPilot.Screen.Tool.InteropScheduleAdd</class>, <class>OcuPilot.Screen.Tool.InteropScheduleUpdate</class> and
/// <class>OcuPilot.Screen.Tool.InteropScheduleRemove</class> (AD-53, AD-55); each is stored at once. New schedule spec and Edit open one dialog; Edit
/// shows the name read-only, because a name cannot be changed. Remove types the schedule spec's name.</p>
/// <p><b>A spec is shown as text and never run.</b> A name, a description and a spec are untrusted content (AD-11, AD-60), and none is a credential, so
/// <code>secretFields</code> is empty.</p>
/// <p><b>Its id is the schedule spec's name</b>, kept exactly (AD-13), and its scope is <code>namespace</code>. Its pairs are the classic page's:
/// <code>%Ens_Portal:USE</code> and, as its own, <code>%Ens_ProductionConfig:READ</code>; the three tools add <code>%Ens_ProductionConfig:WRITE</code>
/// and WRITE on the namespace's globals database (AD-8, AD-62). It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropScheduleList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/schedules",
  "area": "interoperability",
  "labelKey": "interopSchedulesLabel",
  "sideBarPosition": 15,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_ProductionConfig", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_ProductionConfig", "permission": "READ"}],
  "entityType": "interop-schedule",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Name"]},
  "primaryAction": {"id": "add", "selfProtection": ""},
  "rowActions": [{"id": "edit", "selfProtection": ""}, {"id": "remove", "selfProtection": ""}],
  "context": {"fields": ["Name", "Description", "ScheduleSpec", "Deployable"], "secretFields": []},
  "emptyStateKey": "interopSchedulesEmpty",
  "commandAliases": ["schedules", "schedule specs"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopSchedulesPrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopSchedulesPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopSchedulesPrompt3"}
  ],
  "classicPage": "EnsPortal.ScheduleEditor",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "schedule spec",
    "source": {"port": "interop", "endpoint": "Schedules", "type": "LIST"},
    "fields": ["Name", "Description", "ScheduleSpec", "Deployable"],
    "filter": ["Name", "Description", "ScheduleSpec"],
    "sort": {"fields": ["Name", "Description", "ScheduleSpec"], "default": "Name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Name", "labelKey": "tableColumnName", "kind": "name"},
      {"field": "Description", "labelKey": "tableColumnDescription", "kind": "text"},
      {"field": "ScheduleSpec", "labelKey": "taskDetailsSchedule", "kind": "text"},
      {"field": "Deployable", "labelKey": "interopDefaultSettingColumnDeployable", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopSchedulesEmptyAgent"
  },
  "toolIdentifier": "interop.schedules"
}
}

}
