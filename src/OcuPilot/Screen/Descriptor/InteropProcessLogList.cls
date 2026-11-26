/// <p>Interoperability's Business process log: the namespace's business process records, newest first, as the classic Business Process Instances page lists them, read through
/// <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint <code>ProcessLog</code>) and rendered from the declared <code>table</code> (AD-5, AD-29, AD-36,
/// AD-62, Story 24.17 Batch 2). Its one criterion, <code>completed</code>, lists the completed records or the ones still running; a longer list than the cap is reported as truncation,
/// never dropped silently (AD-36). It lists the base table <code>Ens.BusinessProcess</code> only; the classic page's table per business process class and its Context column are not offered.</p>
/// <p><b>Its row action</b> Purge is the screen's caller of <class>OcuPilot.Screen.Tool.InteropProcessLogPurge</class> (AD-53, AD-55): a dialog takes the days to keep and shows how many
/// records the log holds, and the confirm types the namespace's name. It runs in the request and is destructive; a business process still running is kept. It purges the namespace's log
/// whichever row is selected, and names the namespace as its target; the action route admits only a declared row action, so Purge is one. The agent's tool is the same operation.</p>
/// <p><b>Its pairs</b> are the classic page's: <code>%Ens_Portal:USE</code> and, as its own, <code>%Ens_Jobs:READ</code>; a read also needs the SQL SELECT privilege the classic page's own
/// query needs, and the tool adds <code>%Ens_Purge:USE</code>, the classic page's edit resource, and WRITE on the namespace's globals database (AD-8, AD-62). Its scope is
/// <code>namespace</code>. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropProcessLogList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/process-log",
  "area": "interoperability",
  "labelKey": "interopProcessLogLabel",
  "sideBarPosition": 24,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_Jobs", "permission": "READ"}],
  "ownPrivileges": [{"resource": "%Ens_Jobs", "permission": "READ"}],
  "entityType": "interop-process-log",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "purge", "selfProtection": ""}],
  "context": {"fields": ["ID", "TimeCreated", "TimeCompleted", "IsCompleted", "ConfigName"], "secretFields": []},
  "emptyStateKey": "interopProcessLogEmpty",
  "commandAliases": ["business process log", "business process instances"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopProcessLogPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopProcessLogPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopProcessLogPrompt3"}
  ],
  "classicPage": "EnsPortal.BPInstances",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "business process record",
    "source": {"port": "interop", "endpoint": "ProcessLog", "type": "LIST"},
    "fields": ["ID", "TimeCreated", "TimeCompleted", "IsCompleted", "ConfigName", "SessionId"],
    "filter": ["ConfigName"],
    "sort": {"fields": ["ID", "TimeCreated", "TimeCompleted", "IsCompleted", "ConfigName"], "default": "TimeCreated", "direction": "desc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "completed", "labelKey": "interopLogColumnCompleted", "kind": "choice", "maxLength": 3, "options": ["yes", "no"]}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "ID", "labelKey": "interopColumnId", "kind": "name"},
      {"field": "TimeCreated", "labelKey": "journalColumnCreated", "kind": "text"},
      {"field": "TimeCompleted", "labelKey": "taskHistoryColumnCompleted", "kind": "text"},
      {"field": "IsCompleted", "labelKey": "interopLogColumnCompleted", "kind": "status"},
      {"field": "ConfigName", "labelKey": "auditEventFieldSource", "kind": "text"},
      {"field": "SessionId", "labelKey": "webSessionColumnSession", "kind": "identifier"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopProcessLogEmptyAgent"
  },
  "toolIdentifier": "interop.processlog"
}
}

}
