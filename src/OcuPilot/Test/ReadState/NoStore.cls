/// <p>Fixture descriptor declaring a <code>state</code> read (AD-36) against a kernel store this
/// instance does not hold, so <method>OcuPilot.Screen.Read.StateRows</method>'s
/// "the class is not compiled" arm is reached by an executed read rather than asserted about.</p>
/// <p>It names <code>NoSuchStore</code>, which resolves to
/// <code>OcuPilot.Kernel.State.NoSuchStore</code> and is deliberately never created: the class
/// composed from the declaration is what confines a state source to the kernel's own package, and
/// a name inside that package that resolves to nothing is the refusal this fixture drives.</p>
/// <p>Unbuilt, and in a package of its own: it is outside the
/// <code>OcuPilot.Screen.Descriptor</code> package that
/// <method>OcuPilot.Screen.Registry.Descriptors</method> sweeps, so it reaches neither the route
/// table nor the shipped registry's validation -- and outside
/// <code>OcuPilot.Test.Read.</code>, whose descriptors
/// <class>OcuPilot.Test.Read.ToolRegistry</class> turns into read tools it counts.</p>
Class OcuPilot.Test.ReadState.NoStore Extends OcuPilot.Screen.Descriptor.Base
{

XData Declaration
{
{
  "route": "agent/definitions-probe",
  "area": "agent",
  "labelKey": "agentDefinitionListLabel",
  "sideBarPosition": 4,
  "archetype": "list",
  "built": false,
  "refreshes": false,
  "refreshRates": [],
  "privileges": [{"resource": "OcuPilotAdmin", "permission": "USE"}],
  "entityType": "agent-definition",
  "secondaryEntityTypes": [],
  "scope": "instance",
  "parentScope": "",
  "id": {"kind": "composite", "parts": ["id"]},
  "context": {"fields": ["id", "name"], "secretFields": []},
  "primaryAction": {"id": "", "selfProtection": ""},
  "rowActions": [],
  "emptyStateKey": "agentDefinitionListEmpty",
  "commandAliases": [],
  "classicPage": "",
  "classicLinkExemption": {"exempt": false, "reason": "", "label": "", "href": ""},
  "read": {
    "source": {"port": "state", "endpoint": "NoSuchStore", "type": "LIST"},
    "fields": ["id", "name"],
    "filter": ["name"],
    "sort": {"fields": ["name"], "default": "name", "direction": "asc"},
    "paging": "cap"
  },
  "table": {
    "columns": [{"field": "name", "labelKey": "tableColumnName", "kind": "name"}],
    "emptyNextKey": "classicLinkCardCaption",
    "emptyAgentKey": ""
  },
  "toolIdentifier": "agent.definitionsprobe"
}
}

}
