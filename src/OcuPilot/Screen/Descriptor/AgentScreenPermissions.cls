/// <p>The Screen permissions list (AD-64, AD-36, Story 20.15): every built screen, with the pairs it
/// declares, the set an operator adjusted it to, the classic page's custom resource, the pairs it requires
/// now, and whether the signed-in account holds them. It is composed in the caller's process by
/// <class>OcuPilot.Screen.Access</class> (source kind <code>access</code>).</p>
/// <p><b>Its three row actions are the three write tools of one operation</b> (AD-53):
/// <code>add-pair</code> and <code>remove-pair</code> change one pair of the selected screen's set, and
/// <code>reset</code> returns it to its declared set. Its page draws the first two inside one Change
/// permissions dialog.</p>
/// <p><b>Its own gate is fixed</b>: it requires <code>%Development:USE</code> or <code>%Admin_Secure:USE</code>,
/// either one (<method>OcuPilot.Screen.Gate.AdjusterPairs</method>, <method>PrivilegePairs</method>), and no
/// adjustment reaches it, because the Agent co-pilot area declares no pair
/// (<method>OcuPilot.Screen.Gate.Adjustable</method>).
/// It has no classic equivalent, so <code>classicPage</code> is <code>""</code>.</p>
Class OcuPilot.Screen.Descriptor.AgentScreenPermissions Extends OcuPilot.Screen.Descriptor.Base
{

/// <p>The either-of set (AD-64 item 4), not the declaration's single <code>%Development:USE</code>, so every
/// gate that reads this screen's declared set, and its write tools' through
/// <class>OcuPilot.Screen.Tool.ScreenAccessAction</class>, admits either pair.</p>
ClassMethod PrivilegePairs() As %List
{
    Quit ##class(OcuPilot.Screen.Gate).AdjusterPairs()
}

XData Declaration
{
{
  "route": "agent/screenpermissions",
  "area": "agent",
  "labelKey": "agentScreenPermissionsLabel",
  "sideBarPosition": 7,
  "archetype": "list",
  "built": true,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "%Development", "permission": "USE"}],
  "entityType": "screen-permission",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["Screen"]},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [
    {"id": "add-pair", "selfProtection": ""},
    {"id": "remove-pair", "selfProtection": ""},
    {"id": "reset", "selfProtection": ""}
  ],
  "context": {"fields": ["Screen", "Area", "Declared", "Adjustment", "Effective", "Holds", "FailedPair", "Adjustable"], "secretFields": []},
  "emptyStateKey": "screenPermissionsEmpty",
  "commandAliases": ["screen permissions", "permissions per screen", "who can open"],
  "suggestedPrompts": [
    {"groupKey": "userPromptGroupAccess", "textKey": "screenPermissionsPrompt1"},
    {"groupKey": "userPromptGroupAccess", "textKey": "screenPermissionsPrompt2"},
    {"groupKey": "userPromptGroupAccess", "textKey": "screenPermissionsPrompt3"}
  ],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "access", "endpoint": "Screens", "type": "LIST"},
    "fields": ["Screen", "Area", "Declared", "Adjustment", "ClassicResource", "Effective", "Holds", "FailedPair", "Adjustable"],
    "filter": ["Screen", "Area"],
    "sort": {"fields": ["Area", "Screen"], "default": "Area", "direction": "asc"},
    "paging": "cap",
    "note": {"key": "screenPermissionsNote", "text": "Changing a screen's permissions changes who OcuPilot lets open it; the instance still checks every read and write."}
  },
  "table": {
    "columns": [
      {"field": "Screen", "labelKey": "agentLedgerColumnScreen", "kind": "name"},
      {"field": "Area", "labelKey": "screenPermissionsColumnArea", "kind": "text"},
      {"field": "Effective", "labelKey": "screenPermissionsColumnEffective", "kind": "text"},
      {"field": "Adjustment", "labelKey": "screenPermissionsColumnAdjustment", "kind": "text"},
      {"field": "Holds", "labelKey": "screenPermissionsColumnHolds", "kind": "status"}
    ],
    "emptyNextKey": "",
    "emptyAgentKey": "screenPermissionsEmptyAgent"
  },
  "toolIdentifier": "agent.screenpermissions"
}
}

}
