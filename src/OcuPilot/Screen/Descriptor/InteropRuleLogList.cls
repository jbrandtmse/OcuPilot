/// <p>Interoperability's Business rule log: the namespace's business rule log entries, newest first, as the classic Business Rule Log page lists them, read through
/// <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint <code>RuleLog</code>) and rendered from the declared <code>table</code> (AD-5, AD-29, AD-36,
/// AD-62, Story 24.17 Batch 2). Its one criterion, <code>errors</code>, lists the entries marked as an error or the others; a longer list than the cap is reported as truncation,
/// never dropped silently (AD-36).</p>
/// <p><b>Its row action</b> Purge is the screen's caller of <class>OcuPilot.Screen.Tool.InteropRuleLogPurge</class> (AD-53, AD-55): a dialog takes the days to keep and shows how many
/// entries the log holds, and the confirm types the namespace's name. It runs in the request and is destructive. It purges the namespace's log whichever row is selected, and names the
/// namespace as its target; the action route admits only a declared row action, so Purge is one. The agent's tool is the same operation.</p>
/// <p><b>Its pairs</b> are the classic page's: <code>%Ens_Portal:USE</code> and, as its own, <code>%Ens_RuleLog:USE</code>; a read also needs the SQL SELECT privilege the classic page's own
/// query needs, and the tool adds <code>%Ens_Purge:USE</code>, the classic page's edit resource, and WRITE on the namespace's globals database (AD-8, AD-62). Its scope is
/// <code>namespace</code>. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropRuleLogList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/rule-log",
  "area": "interoperability",
  "labelKey": "interopRuleLogLabel",
  "sideBarPosition": 23,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_RuleLog", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Ens_RuleLog", "permission": "USE"}],
  "entityType": "interop-rule-log",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "purge", "selfProtection": ""}],
  "context": {"fields": ["ID", "TimeExecuted", "RuleName", "ConfigName", "IsError", "ReturnValue"], "secretFields": []},
  "emptyStateKey": "interopRuleLogEmpty",
  "commandAliases": ["business rule log", "rule log"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopRuleLogPrompt1"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopRuleLogPrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopRuleLogPrompt3"}
  ],
  "classicPage": "EnsPortal.RuleLog",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "business rule log entry",
    "source": {"port": "interop", "endpoint": "RuleLog", "type": "LIST"},
    "fields": ["ID", "TimeExecuted", "SessionId", "RuleName", "ConfigName", "IsError", "ReturnValue", "Reason"],
    "filter": ["RuleName", "ConfigName", "ReturnValue", "Reason"],
    "sort": {"fields": ["ID", "TimeExecuted", "RuleName", "ConfigName", "IsError"], "default": "TimeExecuted", "direction": "desc"},
    "paging": "cap",
    "criteria": {
      "fields": [
        {"param": "errors", "labelKey": "interopMessagesCriterionErrors", "kind": "choice", "maxLength": 3, "options": ["yes", "no"]}
      ]
    }
  },
  "table": {
    "columns": [
      {"field": "ID", "labelKey": "interopColumnId", "kind": "name"},
      {"field": "TimeExecuted", "labelKey": "auditColumnTime", "kind": "text"},
      {"field": "SessionId", "labelKey": "webSessionColumnSession", "kind": "identifier"},
      {"field": "RuleName", "labelKey": "explorerSqlColumnRule", "kind": "text"},
      {"field": "ConfigName", "labelKey": "auditEventFieldSource", "kind": "text"},
      {"field": "IsError", "labelKey": "errorLogColumnText", "kind": "status"},
      {"field": "ReturnValue", "labelKey": "explorerSqlColumnReturnValue", "kind": "text"},
      {"field": "Reason", "labelKey": "agentSwitchesFieldReason", "kind": "text"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopRuleLogEmptyAgent"
  },
  "toolIdentifier": "interop.rulelog"
}
}

}
