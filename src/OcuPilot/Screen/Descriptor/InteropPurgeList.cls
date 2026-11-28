/// <p>Interoperability's Purge management data: the six record counts of the namespace, one row each, which the classic Purge Management Data page shows beside its Purge button,
/// read through <class>OcuPilot.Port.InteropPort</class> (source kind <code>interop</code>, endpoint <code>Purge</code>) and rendered from the declared <code>table</code>
/// (AD-5, AD-29, AD-36, AD-62, Story 24.16).</p>
/// <p><b>Its row action</b> Purge is the screen's caller of <class>OcuPilot.Screen.Tool.InteropPurgeRun</class> (AD-53, AD-55): a dialog takes the days to keep and shows the
/// three settings the purge will use, and the confirm types the namespace's name. It runs in the request and is destructive. It purges the namespace whichever count row is
/// selected, and names the namespace as its target; the action route admits only a declared row action, so Purge is one. The agent's tool is the same operation.</p>
/// <p><b>Its pairs</b> are the classic page's: <code>%Ens_Portal:USE</code> and, as its own, <code>%Ens_Purge:USE</code>; the tool adds WRITE on the namespace's globals database
/// (AD-8, AD-62). Its scope is <code>namespace</code>. It does not refresh (AD-43).</p>
Class OcuPilot.Screen.Descriptor.InteropPurgeList Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "interoperability/purge",
  "area": "interoperability",
  "labelKey": "interopPurgeLabel",
  "sideBarPosition": 16,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Ens_Portal", "permission": "USE"}, {"resource": "%Ens_Purge", "permission": "USE"}],
  "ownPrivileges": [{"resource": "%Ens_Purge", "permission": "USE"}],
  "entityType": "interop-purge",
  "secondaryEntityTypes": [],
  "scope": "namespace",
  "parentScope": "",
  "id": {"kind": "single", "parts": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [{"id": "purge", "selfProtection": ""}],
  "context": {"fields": ["Type", "Count"], "secretFields": []},
  "emptyStateKey": "interopPurgeEmpty",
  "commandAliases": ["purge", "purge management data"],
  "suggestedPrompts": [
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopPurgePrompt1"},
    {"groupKey": "promptGroupTroubleshooting", "textKey": "interopPurgePrompt2"},
    {"groupKey": "promptGroupGettingStarted", "textKey": "interopPurgePrompt3"}
  ],
  "classicPage": "EnsPortal.PurgeAll",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "row": "record count",
    "source": {"port": "interop", "endpoint": "Purge", "type": "LIST"},
    "fields": ["Type", "Count"],
    "filter": ["Type"],
    "sort": {"fields": ["Type", "Count"], "default": "Count", "direction": "desc"},
    "paging": "cap"
  },
  "table": {
    "columns": [
      {"field": "Type", "labelKey": "tableColumnType", "kind": "name"},
      {"field": "Count", "labelKey": "interopColumnCount", "kind": "number"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "interopPurgeEmptyAgent"
  },
  "toolIdentifier": "interop.purge"
}
}

}
